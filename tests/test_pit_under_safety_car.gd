extends SceneTree

## Cars called to box while the safety car is out are still serviced and released, nothing sticks in the pit lane
## or on the queue, and the race gets back to green. Run:
##   godot --headless --path . -s res://tests/test_pit_under_safety_car.gd

const TrackScene := preload("res://scenes/race_world/circuits/apex_ring/apex_circuit.tscn")
const TrackScript := preload("res://scripts/gt/gt_track.gd")
const RaceScript := preload("res://scripts/gt/gt_race.gd")
const CarScript := preload("res://scripts/gt/gt_car.gd")
const Types := preload("res://scripts/gt/gt_types.gd")
const WeatherScript := preload("res://scripts/gt/gt_weather.gd")

const SPREAD_S: float = 70.0
const DEADLINE_S: float = 1500.0
const CALLERS: int = 6
## A pit car crawling or stopped outside its box for longer than this is stuck, not queueing.
const STUCK_MAX_S: float = 30.0
const HOLD_MAX_S: float = 120.0

var failures: int = 0


func check(ok: bool, description: String) -> void:
	print("[%s] %s" % ["PASS" if ok else "FAIL", description])
	if not ok:
		failures += 1


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var ribbon: Node = TrackScene.instantiate()
	ribbon.road_half_width_m = 7.0
	root.add_child(ribbon)
	var track := TrackScript.new(ribbon, 14.0)
	_scenario(track, "safety car before the calls", true)
	_scenario(track, "safety car after the calls", false)
	ribbon.queue_free()
	await process_frame
	quit(1 if failures else 0)


func _scenario(track: TrackScript, label: String, sc_first: bool) -> void:
	var race := RaceScript.new(track, 12, 31, WeatherScript.Archetype.DRY_SUNNY)
	race.incidents_enabled = false
	for _i: int in range(int(SPREAD_S / Types.TICK_DT)):
		race.step()
	var callers: Array[CarScript] = []
	for index: int in range(CALLERS):
		callers.append(race.cars[index * 3])
	if sc_first:
		race.set_flag(Types.Flag.SC, 1, "TEST SAFETY CAR", 32.0)
	for car: CarScript in callers:
		race.request_pit(car.id, Types.Compound.MEDIUM)
	if not sc_first:
		race.set_flag(Types.Flag.SC, 1, "TEST SAFETY CAR", 32.0)
	var since: Dictionary = {}
	var slow_s: Dictionary = {}
	var worst_hold: float = 0.0
	var worst_slow: float = 0.0
	var was_green_again: bool = false
	var dt: float = Types.TICK_DT
	var ticks: int = 0
	while ticks < int(DEADLINE_S / dt):
		race.step()
		ticks += 1
		for car: CarScript in callers:
			if car.pit == null:
				since.erase(car.id)
				slow_s.erase(car.id)
				continue
			if not since.has(car.id):
				since[car.id] = race.time
			worst_hold = maxf(worst_hold, race.time - float(since[car.id]))
			var parked: bool = car.pit.phase == Types.PitPhase.BOX
			if car.v < 0.3 and not parked:
				slow_s[car.id] = float(slow_s.get(car.id, 0.0)) + dt
				worst_slow = maxf(worst_slow, float(slow_s[car.id]))
			else:
				slow_s[car.id] = 0.0
		var serviced: bool = true
		for car: CarScript in callers:
			serviced = serviced and car.stops >= 1 and car.pit == null
		if serviced and int(race.race_control["flag"]) == Types.Flag.GREEN:
			was_green_again = true
			break
	var done: int = 0
	for car: CarScript in callers:
		done += 1 if car.stops >= 1 and car.pit == null else 0
	print("  [%s] serviced=%d/%d time=%.0fs hold=%.0fs slow=%.0fs flag=%d" % [label, done, CALLERS, race.time, worst_hold, worst_slow, int(race.race_control["flag"])])
	check(done == CALLERS, "%s: every car called under the safety car is serviced and released" % label)
	check(worst_hold <= HOLD_MAX_S, "%s: no car holds the pit lane longer than %.0f s (%.0f s)" % [label, HOLD_MAX_S, worst_hold])
	check(worst_slow <= STUCK_MAX_S, "%s: no pit car sits still outside its box for %.0f s (%.0f s)" % [label, STUCK_MAX_S, worst_slow])
	check(was_green_again, "%s: the race gets back to green with everyone serviced" % label)
	race.dispose()
