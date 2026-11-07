extends SceneTree

## Fase 32 Task 2: a heavy crash first shows a VSC for 8 to 15 s (a window to gamble on a stop, the pit lane stays
## open) and then becomes the safety car; repeat calls never spawn a second safety car; debris VSC is untouched.
## Run: godot --headless --path . -s res://tests/test_vsc_escalation.gd

const TrackScene := preload("res://scenes/race_world/circuits/apex_ring/apex_circuit.tscn")
const TrackScript := preload("res://scripts/gt/gt_track.gd")
const RaceScript := preload("res://scripts/gt/gt_race.gd")
const WeatherScript := preload("res://scripts/gt/gt_weather.gd")
const Types := preload("res://scripts/gt/gt_types.gd")

const DRY: int = WeatherScript.Archetype.DRY_SUNNY
const DT: float = Types.TICK_DT

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
	_test_delay_function()
	_test_vsc_then_sc(track)
	_test_repeat_calls_spawn_one_sc(track)
	_test_debris_vsc_still_clears_to_green(track)
	_test_pit_lane_open_during_vsc_window(track)
	ribbon.queue_free()
	await process_frame
	quit(1 if failures else 0)


func _fresh_race(track: TrackScript) -> RaceScript:
	var race := RaceScript.new(track, 10, 5, DRY, 20)
	race.incidents_enabled = false
	race.step_ticks(200)
	return race


func _test_delay_function() -> void:
	var in_range: bool = true
	var distinct: Dictionary = {}
	for serial: int in range(10):
		var delay: float = GtRace.sc_escalation_delay_s(5, serial)
		in_range = in_range and delay >= 8.0 and delay <= 15.0
		distinct[snappedf(delay, 0.001)] = true
	check(in_range, "escalation delay is always between 8 and 15 s")
	check(distinct.size() > 1, "escalation delay varies with the serial")
	check(is_equal_approx(GtRace.sc_escalation_delay_s(5, 3), GtRace.sc_escalation_delay_s(5, 3)), "same seed and serial give the same delay")


func _test_vsc_then_sc(track: TrackScript) -> void:
	var race := _fresh_race(track)
	var delay: float = GtRace.sc_escalation_delay_s(race.race_seed, 0)
	race.raise_sc(2, "TEST CRASH", 32.0)
	check(int(race.race_control["flag"]) == Types.Flag.VSC, "a heavy crash starts as a VSC")
	check(not bool(race.safety_car["active"]), "no safety car is on track during the VSC window")
	var t0: float = race.time
	var ticks: int = 0
	while int(race.race_control["flag"]) != Types.Flag.SC and ticks < int(30.0 / DT):
		race.step()
		ticks += 1
	var elapsed: float = race.time - t0
	check(int(race.race_control["flag"]) == Types.Flag.SC, "the VSC becomes the safety car")
	check(absf(elapsed - delay) <= 2.0 * DT, "the safety car comes out after the escalation delay (%.2f s vs %.2f s)" % [elapsed, delay])
	check(bool(race.safety_car["active"]), "the safety car is on track after the escalation")
	race.dispose()


func _test_repeat_calls_spawn_one_sc(track: TrackScript) -> void:
	var race := _fresh_race(track)
	var sc_emissions: Array[int] = [0]
	race.flag_changed.connect(func(flag: int, _message: String) -> void:
		if flag == Types.Flag.SC:
			sc_emissions[0] += 1)
	race.raise_sc(2, "FIRST", 32.0)
	race.step_ticks(40)
	race.raise_sc(3, "SECOND WHILE PENDING", 32.0)
	race.step_ticks(int(20.0 / DT))
	check(sc_emissions[0] == 1, "a second heavy crash during the VSC window raises one safety car, not two (%d)" % sc_emissions[0])
	var spawn_s: float = float(race.safety_car["s"])
	var prev_s: float = float(race.safety_car["prev_s"])
	race.raise_sc(1, "THIRD WHILE ACTIVE", 32.0)
	check(is_equal_approx(float(race.safety_car["s"]), spawn_s) and is_equal_approx(float(race.safety_car["prev_s"]), prev_s), "a crash while the safety car is out does not respawn it")
	check(int(race.race_control["flag"]) == Types.Flag.SC, "the safety car stays out")
	race.dispose()


func _test_debris_vsc_still_clears_to_green(track: TrackScript) -> void:
	var race := _fresh_race(track)
	race.set_flag(Types.Flag.VSC, 1, "VIRTUAL SAFETY CAR - DEBRIS", 10.0)
	race.step_ticks(int(11.0 / DT))
	check(int(race.race_control["flag"]) == Types.Flag.GREEN, "a debris VSC still ends in green with no safety car")
	check(not bool(race.safety_car["active"]), "a debris VSC never brings the safety car out")
	race.dispose()


func _test_pit_lane_open_during_vsc_window(track: TrackScript) -> void:
	var race := _fresh_race(track)
	var caller: GtCar = race.cars[5]
	race.raise_sc(2, "TEST CRASH", 32.0)
	race.request_pit(caller.id, Types.Compound.MEDIUM)
	var entered: bool = false
	var ticks: int = 0
	while ticks < int(400.0 / DT) and not entered:
		race.step()
		ticks += 1
		entered = caller.pit != null
	check(entered, "a car called to box in the VSC window is allowed into the pit lane")
	race.dispose()
