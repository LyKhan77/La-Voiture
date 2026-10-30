extends SceneTree

## The whole field boxes at once on Monte Azure's own pit lane (its published sim layout): every car is serviced, none stands
## still in the lane for long, the lane clears in a reasonable time and the cars do not run into each other.
## Two causes made that lane jam when it had 12 m boxes: the car queued for the next box stood nose to tail against the
## box car, so a box could only release after the one ahead of it (the lane emptied last box first); and a car held at the
## merge, standing in the stall lane, was driven into by the next box's queue as it eased in (cars drove through each other:
## 523 ticks of overlap in the train scenario). The boxes are 20 m now, and the queue stops short of a car held ahead of it.
## Same overlap metric as tests/test_pit_queue_flow.gd, which runs the Apex lane.
## Run: godot --headless --path . -s res://tests/test_monte_azure_pit_flood.gd

const CircuitScene := preload("res://scenes/race_world/circuits/monte_azure/monte_azure_circuit.tscn")
const TrackScript := preload("res://scripts/gt/gt_track.gd")
const RaceScript := preload("res://scripts/gt/gt_race.gd")
const CarScript := preload("res://scripts/gt/gt_car.gd")
const Types := preload("res://scripts/gt/gt_types.gd")
const WeatherScript := preload("res://scripts/gt/gt_weather.gd")

## A car stands still outside its own box for at most this long in one go (queued behind its teammate, waiting for the lane,
## or held at the merge). Before the changes: 18.8 s in the first two scenarios, 20.1 s in the raced field.
const STILL_MAX_S: float = 18.0
## From the first call to the last car back on the circuit, in the two scenarios where the whole field is at the lane together.
## Before: 101 and 122 s.
const FLUSH_MAX_S: float = 90.0
const LANE_DECEL_MAX: float = 10.0
const TELEPORT_MAX_M: float = 0.05
const HULL_WIDTH_M: float = 1.9
const OVERLAP_MAX_M: float = 1.0
const DEEP_OVERLAP_TICKS_MAX: int = 20
const DEADLINE_S: float = 420.0

var failures: int = 0
var track: TrackScript
var layout: Dictionary = {}


func check(ok: bool, description: String) -> void:
	print("[%s] %s" % ["PASS" if ok else "FAIL", description])
	if not ok:
		failures += 1


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var circuit := CircuitScene.instantiate() as Node3D
	root.add_child(circuit)
	await process_frame
	var ribbon = circuit.get_node("TrackRibbon")
	layout = (circuit.get_node("PitLane") as Node).sim_layout()
	track = TrackScript.new(ribbon, ribbon.road_half_width_m * 2.0)
	print("--- Monte Azure pit lane flood: pitch %.0f m, lane %.0f m ---" % [float(layout["stall_pitch_m"]), float(layout["lane_length_m"])])
	_scenario("train of 20 cars 30 m apart", 30.0, 12.0)
	_scenario("bunched 20 m apart", 20.0, 12.0)
	_scenario("spread around the lap", track.length / 20.0, 20.0, false)
	_live_scenario("raced field, everyone boxes together", 2)
	circuit.queue_free()
	await process_frame
	quit(1 if failures else 0)


func _scenario(label: String, spacing: float, speed: float, bound_flush: bool = true) -> void:
	var race := RaceScript.new(track, 12, 31, WeatherScript.Archetype.DRY_SUNNY, 20, layout)
	race.incidents_enabled = false
	var entry: float = float(race.pit_layout["entry_s"])
	for index: int in range(race.cars.size()):
		var car: CarScript = race.cars[index]
		var s: float = fposmod(entry - 150.0 - float(index) * spacing, track.length) + track.length
		car.s = s
		car.prev_s = s
		car.v = speed + 20.0
		car.lateral = 0.0
		car.prev_lateral = 0.0
		car.target_lateral = 0.0
		car.lap = 1
		race.request_pit(car.id, Types.Compound.MEDIUM)
	_measure(label, race, bound_flush)
	race.dispose()


## The real field: raced from the grid, every car asked to box in the same tick once the leader has run `laps` laps.
func _live_scenario(label: String, laps: int) -> void:
	var race := RaceScript.new(track, 12, 31, WeatherScript.Archetype.DRY_SUNNY, 20, layout)
	race.incidents_enabled = false
	var guard: int = 0
	while guard < int(900.0 / Types.TICK_DT) and race.standings()[0].s < track.length * float(laps) + 300.0:
		race.step()
		guard += 1
	for car: CarScript in race.cars:
		race.request_pit(car.id, Types.Compound.MEDIUM)
	_measure(label, race, false)
	race.dispose()


func _measure(label: String, race: RaceScript, bound_flush: bool) -> void:
	var dt: float = Types.TICK_DT
	var asked: float = race.time
	var max_decel: float = 0.0
	var max_teleport: float = 0.0
	var deepest_overlap: float = 0.0
	var deep_overlap_ticks: int = 0
	var still_for: Dictionary = {}
	var longest_still: float = 0.0
	var still_total: Dictionary = {}
	var most_still_total: float = 0.0
	var flushed_at: float = -1.0
	var ticks: int = 0
	while ticks < int(DEADLINE_S / dt):
		var before: Dictionary = {}
		for car: CarScript in race.cars:
			before[car.id] = [car.v, car.s]
		race.step()
		ticks += 1
		for car: CarScript in race.cars:
			if car.pit == null:
				still_for.erase(car.id)
				continue
			var parked: bool = car.pit.phase == Types.PitPhase.BOX and absf(car.pit.box_s - car.s) <= 0.5
			if car.v < 0.3 and not parked:
				still_for[car.id] = float(still_for.get(car.id, 0.0)) + dt
				longest_still = maxf(longest_still, float(still_for[car.id]))
				still_total[car.id] = float(still_total.get(car.id, 0.0)) + dt
				most_still_total = maxf(most_still_total, float(still_total[car.id]))
			else:
				still_for.erase(car.id)
			if car.pit.phase != Types.PitPhase.ENTRY:
				if float(before[car.id][0]) > 1.0:
					max_decel = maxf(max_decel, (float(before[car.id][0]) - car.v) / dt)
				max_teleport = maxf(max_teleport, absf((car.s - float(before[car.id][1])) - car.v * dt))
			for other: CarScript in race.cars:
				if other == car or other.pit == null or other.s <= car.s or other.s - car.s > 30.0:
					continue
				if absf(other.lateral - car.lateral) < HULL_WIDTH_M:
					var bumper_gap: float = other.s - car.s - Types.CAR_LENGTH_M
					if bumper_gap < 0.0:
						var depth: float = minf(-bumper_gap, HULL_WIDTH_M - absf(other.lateral - car.lateral))
						deepest_overlap = maxf(deepest_overlap, depth)
						deep_overlap_ticks += 1 if depth > OVERLAP_MAX_M else 0
		var done: bool = true
		for car: CarScript in race.cars:
			done = done and car.stops >= 1 and car.pit == null
		if done:
			flushed_at = race.time - asked
			break
	var serviced: int = 0
	for car: CarScript in race.cars:
		serviced += 1 if car.stops >= 1 and car.pit == null else 0
	print("  [%s] serviced=%d/20 flushed in %.0f s, longest stand-still %.1f s (%.1f s over the stop), decel %.1f, teleport %.2f, overlap %d ticks (deepest %.2f m)" % [label, serviced, flushed_at, longest_still, most_still_total, max_decel, max_teleport, deep_overlap_ticks, deepest_overlap])
	check(serviced == race.cars.size(), "%s: every car is serviced and back on the circuit" % label)
	check(longest_still <= STILL_MAX_S, "%s: no car stands still outside its box for more than %.0f s at a time (%.1f s)" % [label, STILL_MAX_S, longest_still])
	if bound_flush:
		check(flushed_at > 0.0 and flushed_at <= FLUSH_MAX_S, "%s: the lane is clear within %.0f s of the first call (%.0f s)" % [label, FLUSH_MAX_S, flushed_at])
	check(max_decel <= LANE_DECEL_MAX, "%s: lane braking stays comfortable (%.1f m/s2)" % [label, max_decel])
	check(max_teleport <= TELEPORT_MAX_M, "%s: no car is pushed or teleported (%.2f m)" % [label, max_teleport])
	check(deep_overlap_ticks <= DEEP_OVERLAP_TICKS_MAX, "%s: no car drives into another: %d car-pair ticks overlap by more than %.1f m (deepest %.2f m)" % [label, deep_overlap_ticks, OVERLAP_MAX_M, deepest_overlap])
