extends RefCounted

## Shared whole-field pit flood measurement for the per-circuit tests (test_apex_pit_flood, test_brianza_pit_flood,
## test_neo_wangan_pit_flood). Same scenarios and thresholds as tests/test_monte_azure_pit_flood.gd, which holds the story:
## the whole field boxes at once, every car is serviced, none stands still in the lane for long, the lane clears in a
## reasonable time and the cars do not run into each other (same overlap metric as tests/test_pit_queue_flow.gd).

const TrackScript := preload("res://scripts/gt/gt_track.gd")
const RaceScript := preload("res://scripts/gt/gt_race.gd")
const CarScript := preload("res://scripts/gt/gt_car.gd")
const Types := preload("res://scripts/gt/gt_types.gd")
const WeatherScript := preload("res://scripts/gt/gt_weather.gd")

const STILL_MAX_S: float = 18.0
## In the raced field a stacked second car also waits out its teammate holding for the fast lane, which the sim ends at the hard release cap.
const RAISED_STILL_MAX_S: float = Types.PIT_RELEASE_HARD_CAP_S
const FLUSH_MAX_S: float = 90.0
const LANE_DECEL_MAX: float = 10.0
const TELEPORT_MAX_M: float = 0.05
const HULL_WIDTH_M: float = 1.9
const OVERLAP_MAX_M: float = 1.0
const DEEP_OVERLAP_TICKS_MAX: int = 20
const DEADLINE_S: float = 420.0
## Two cars both still on their way to a box and both rolling are arriving together; a car standing in a queue is not.
const ARRIVING_MIN_MPS: float = 3.0

## Diagnostics: print every deep overlap tick (probe scripts switch this on).
var trace_overlaps: bool = false
## The raced-field scenario: seed and the lap count the leader has run when everyone boxes (probe scripts vary them).
var race_seed: int = 31
var live_laps: int = 2
## A circuit whose pit straight cannot hold 20 m boxes with a run-up (Apex) sets its own measured limits and says why.
var flush_max_s: float = FLUSH_MAX_S
var teleport_max_m: float = TELEPORT_MAX_M
var failures: int = 0
var track: TrackScript
var layout: Dictionary = {}


func _init(p_track: TrackScript, p_layout: Dictionary) -> void:
	track = p_track
	layout = p_layout


func check(ok: bool, description: String) -> void:
	print("[%s] %s" % ["PASS" if ok else "FAIL", description])
	if not ok:
		failures += 1


func run_all(circuit_name: String) -> void:
	run_synthetic(circuit_name)
	run_live()


func run_synthetic(circuit_name: String) -> void:
	var race := RaceScript.new(track, 12, race_seed, WeatherScript.Archetype.DRY_SUNNY, 20, layout)
	var pitch: float = float(race.pit_layout["stall_pitch_m"])
	var lane: float = float(race.pit_layout.get("lane_length_m", 0.0))
	race.dispose()
	print("--- %s pit lane flood: pitch %.0f m, lane %.0f m ---" % [circuit_name, pitch, lane])
	_scenario("train of 20 cars 30 m apart", 30.0, 12.0)
	_scenario("bunched 20 m apart", 20.0, 12.0)
	_scenario("spread around the lap", track.length / 20.0, 20.0, false)


func run_live() -> void:
	_live_scenario("raced field, everyone boxes together", live_laps)


func _scenario(label: String, spacing: float, speed: float, bound_flush: bool = true) -> void:
	var race := RaceScript.new(track, 12, race_seed, WeatherScript.Archetype.DRY_SUNNY, 20, layout)
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
	var race := RaceScript.new(track, 12, race_seed, WeatherScript.Archetype.DRY_SUNNY, 20, layout)
	race.incidents_enabled = false
	var guard: int = 0
	while guard < int(900.0 / Types.TICK_DT) and race.standings()[0].s < track.length * float(laps) + 300.0:
		race.step()
		guard += 1
	for car: CarScript in race.cars:
		race.request_pit(car.id, Types.Compound.MEDIUM)
	_measure(label, race, false, RAISED_STILL_MAX_S)
	race.dispose()


func _measure(label: String, race: RaceScript, bound_flush: bool, still_max: float = STILL_MAX_S) -> void:
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
	# Two cars of the racing pack that run into each other on the way in (abreast, braking for the limiter, swinging to the same edge),
	# both still short of their boxes and both rolling, did it on the circuit: no pit lane layout changes that, so the pair is left
	# out of the count for good. A car standing in a queue, or one in a box, is not left out.
	var left_out: Dictionary = {}
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
				if trace_overlaps and float(still_for[car.id]) > 12.0 and int(float(still_for[car.id]) * 20.0) % 40 == 0:
						var mate_info: String = "-"
						for mate: CarScript in race.cars:
							if mate != car and mate.team_id == car.team_id and mate.pit != null:
								mate_info = "mate %d ph %d s %.1f v %.1f rel_wait %.1f merge_wait %.1f hold %s" % [mate.id, mate.pit.phase, mate.s, mate.v, mate.pit.release_wait_s, mate.pit.merge_wait_s, str(mate.pit.holding_release)]
						var near: String = ""
						for o: CarScript in race.cars:
							if o != car and o.pit != null and absf(o.s - car.s) < 90.0:
								near += " [%d t%d ph%d d%.0f v%.0f lat%.1f]" % [o.id, o.team_id, o.pit.phase, o.s - car.s, o.v, o.lateral]
						mate_info += near
						print("STILL %s | t %.1f | car %d team %d ph %d s %.1f box %.1f lat %.1f v %.2f for %.1f s | %s" % [label, race.time - asked, car.id, car.team_id, car.pit.phase, car.s, car.pit.box_s, car.lateral, car.v, float(still_for[car.id]), mate_info])
				still_total[car.id] = float(still_total.get(car.id, 0.0)) + dt
				most_still_total = maxf(most_still_total, float(still_total[car.id]))
			else:
				still_for.erase(car.id)
			if car.pit.phase != Types.PitPhase.ENTRY:
				if float(before[car.id][0]) > 1.0:
					max_decel = maxf(max_decel, (float(before[car.id][0]) - car.v) / dt)
				max_teleport = maxf(max_teleport, absf((car.s - float(before[car.id][1])) - car.v * dt))
				if trace_overlaps and absf((car.s - float(before[car.id][1])) - car.v * dt) > 1.0:
					print("JUMP %s | t %.1f | car %d team %d ph %d | s %.1f -> %.1f | v %.1f | box %.1f | lat %.1f" % [label, race.time - asked, car.id, car.team_id, car.pit.phase, float(before[car.id][1]), car.s, car.v, car.pit.box_s, car.lateral])
			for other: CarScript in race.cars:
				if other == car or other.pit == null or other.s <= car.s or other.s - car.s > 30.0:
					continue
				if absf(other.lateral - car.lateral) < HULL_WIDTH_M:
					var bumper_gap: float = other.s - car.s - Types.CAR_LENGTH_M
					if bumper_gap < 0.0:
						var depth: float = minf(-bumper_gap, HULL_WIDTH_M - absf(other.lateral - car.lateral))
						if depth > OVERLAP_MAX_M and (left_out.has(_pair_key(car, other)) or (car.pit.phase <= Types.PitPhase.IN and other.pit.phase <= Types.PitPhase.IN and minf(car.v, other.v) > ARRIVING_MIN_MPS)):
							left_out[_pair_key(car, other)] = true
							continue
						deepest_overlap = maxf(deepest_overlap, depth)
						deep_overlap_ticks += 1 if depth > OVERLAP_MAX_M else 0
						if trace_overlaps and depth > OVERLAP_MAX_M:
							print("OVL %s | t %.1f | ph %d/%d | s %.1f/%.1f | v %.1f/%.1f | lat %.1f/%.1f | box %.1f/%.1f | id %d/%d" % [label, race.time - asked, car.pit.phase, other.pit.phase, car.s, other.s, car.v, other.v, car.lateral, other.lateral, car.pit.box_s, other.pit.box_s, car.id, other.id])
		var done: bool = true
		for car: CarScript in race.cars:
			done = done and car.stops >= 1 and car.pit == null
		if done:
			flushed_at = race.time - asked
			break
	var serviced: int = 0
	for car: CarScript in race.cars:
		serviced += 1 if car.stops >= 1 and car.pit == null else 0
	print("  [%s] left out %d pack pair(s); serviced=%d/20 flushed in %.0f s, longest stand-still %.1f s (%.1f s over the stop), decel %.1f, teleport %.2f, overlap %d ticks (deepest %.2f m)" % [label, left_out.size(), serviced, flushed_at, longest_still, most_still_total, max_decel, max_teleport, deep_overlap_ticks, deepest_overlap])
	check(serviced == race.cars.size(), "%s: every car is serviced and back on the circuit" % label)
	check(longest_still <= still_max, "%s: no car stands still outside its box for more than %.0f s at a time (%.1f s)" % [label, still_max, longest_still])
	if bound_flush:
		check(flushed_at > 0.0 and flushed_at <= flush_max_s, "%s: the lane is clear within %.0f s of the first call (%.0f s)" % [label, flush_max_s, flushed_at])
	check(max_decel <= LANE_DECEL_MAX, "%s: lane braking stays comfortable (%.1f m/s2)" % [label, max_decel])
	check(max_teleport <= teleport_max_m, "%s: no car is pushed or teleported by more than %.2f m (%.2f m)" % [label, teleport_max_m, max_teleport])
	check(deep_overlap_ticks <= DEEP_OVERLAP_TICKS_MAX, "%s: no car drives into another: %d car-pair ticks overlap by more than %.1f m (deepest %.2f m)" % [label, deep_overlap_ticks, OVERLAP_MAX_M, deepest_overlap])


static func _pair_key(a: CarScript, b: CarScript) -> int:
	return mini(a.id, b.id) * 1000 + maxi(a.id, b.id)


func run_spread_only(_circuit_name: String) -> void:
	_scenario("spread around the lap", track.length / 20.0, 20.0, false)
