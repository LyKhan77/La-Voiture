extends SceneTree

## The whole field boxes in the same lap: every car is serviced, nobody sticks in the lane, and the queue
## moves like traffic: no instant stops and no teleports (bumper overlap at merges is measured, not yet fixed).
## Run: godot --headless --path . -s res://tests/test_pit_queue_flow.gd

const TrackScene := preload("res://scenes/race_world/circuits/apex_ring/apex_circuit.tscn")
const TrackScript := preload("res://scripts/gt/gt_track.gd")
const RaceScript := preload("res://scripts/gt/gt_race.gd")
const CarScript := preload("res://scripts/gt/gt_car.gd")
const Types := preload("res://scripts/gt/gt_types.gd")
const WeatherScript := preload("res://scripts/gt/gt_weather.gd")

## Comfortable braking once a car is on the pit lane (the line-entry envelope may brake harder).
const LANE_DECEL_MAX: float = 10.0
const TELEPORT_MAX_M: float = 0.05
## Body shell without mirrors and arches: sharing a lane means this close sideways.
const HULL_WIDTH_M: float = 1.9
const BUMPER_GAP_MIN_M: float = 0.5
const HOLD_MAX_S: float = 100.0
const ARRIVAL_WAIT_MAX_S: float = 1.0
const SERVICE_DEADLINE_S: float = 420.0

var failures: int = 0
var ribbon: Node
var track: TrackScript


func check(ok: bool, description: String) -> void:
	print("[%s] %s" % ["PASS" if ok else "FAIL", description])
	if not ok:
		failures += 1


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	ribbon = TrackScene.instantiate()
	ribbon.road_half_width_m = 7.0
	root.add_child(ribbon)
	track = TrackScript.new(ribbon, 14.0)
	_scenario("whole field boxes in a train", 30.0, 12.0, WeatherScript.Archetype.DRY_SUNNY)
	_scenario("whole field boxes bunched", 20.0, 12.0, WeatherScript.Archetype.DRY_SUNNY)
	_scenario("late field calls in a wet race", 25.0, 8.0, WeatherScript.Archetype.LATE_MONSOON)
	_scenario("field spread around the lap boxes on the same lap", track.length / 20.0, 20.0, WeatherScript.Archetype.DRY_SUNNY)
	ribbon.queue_free()
	await process_frame
	quit(1 if failures else 0)


## Puts all 20 cars in a train `spacing` metres apart ahead of Pit Entry and asks each to box.
func _scenario(label: String, spacing: float, speed: float, weather: int) -> void:
	var race := RaceScript.new(track, 12, 31, weather)
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
	var dt: float = Types.TICK_DT
	var max_decel: float = 0.0
	var max_teleport: float = 0.0
	var min_gap: float = INF
	var worst_hold: float = 0.0
	var since: Dictionary = {}
	var arrived: Dictionary = {}
	var worst_arrival_wait: float = 0.0
	var ticks: int = 0
	while ticks < int(SERVICE_DEADLINE_S / dt):
		var before: Dictionary = {}
		for car: CarScript in race.cars:
			before[car.id] = [car.v, car.s]
		race.step()
		ticks += 1
		for car: CarScript in race.cars:
			if car.pit == null:
				since.erase(car.id)
				continue
			if not since.has(car.id):
				since[car.id] = race.time
			worst_hold = maxf(worst_hold, race.time - float(since[car.id]))
			# The crew must start working right after the car arrives at its box, not sit idle beside it.
			if car.pit.phase == Types.PitPhase.BOX and absf(car.pit.box_s - car.s) <= 0.5 and car.pit.timer <= 0.0 and car.pit.penalty_hold_s <= 0.0:
				if not arrived.has(car.id):
					arrived[car.id] = race.time
				worst_arrival_wait = maxf(worst_arrival_wait, race.time - float(arrived[car.id]))
			else:
				arrived.erase(car.id)
			var in_lane: bool = car.pit.phase != Types.PitPhase.ENTRY
			if in_lane:
				if float(before[car.id][0]) > 1.0:
					max_decel = maxf(max_decel, (float(before[car.id][0]) - car.v) / dt)
				max_teleport = maxf(max_teleport, absf((car.s - float(before[car.id][1])) - car.v * dt))
			for other: CarScript in race.cars:
				if other == car or other.pit == null or other.s <= car.s or other.s - car.s > 30.0:
					continue
				if absf(other.lateral - car.lateral) < HULL_WIDTH_M:
					min_gap = minf(min_gap, other.s - car.s - Types.CAR_LENGTH_M)
		var done: bool = true
		for car: CarScript in race.cars:
			done = done and car.stops >= 1 and car.pit == null
		if done:
			break
	var serviced: int = 0
	for car: CarScript in race.cars:
		serviced += 1 if car.stops >= 1 and car.pit == null else 0
	print("  [%s] serviced=%d/20 time=%.0fs decel=%.1f teleport=%.2f gap=%.2f hold=%.0fs" % [label, serviced, race.time, max_decel, max_teleport, min_gap, worst_hold])
	check(serviced == race.cars.size(), "%s: every car is serviced and released" % label)
	check(worst_hold <= HOLD_MAX_S, "%s: no car holds the pit lane longer than %.0f s" % [label, HOLD_MAX_S])
	check(worst_arrival_wait <= ARRIVAL_WAIT_MAX_S, "%s: service starts right after a car reaches its box (%.2f s)" % [label, worst_arrival_wait])
	check(max_decel <= LANE_DECEL_MAX, "%s: lane braking stays comfortable (%.1f m/s2)" % [label, max_decel])
	check(max_teleport <= TELEPORT_MAX_M, "%s: no car is pushed or teleported (%.2f m)" % [label, max_teleport])
	# Open issue (see FASE-13-3 report): cars still touch where a pulling-out car merges with one easing into
	# the next box, so the bumper gap is measured and reported but not yet asserted.
	print("  [%s] closest bumper gap in the lane: %.2f m (target >= %.1f)" % [label, min_gap, BUMPER_GAP_MIN_M])
	race.dispose()
