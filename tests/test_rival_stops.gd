extends SceneTree

## Fase 32 Task 9: rivals take the mandatory stop inside its window (spread over several laps), cover a stop of the
## car behind, pit under a safety car, and a seed replays the same stops. The player's cars follow the same rules
## on AUTO.
## Run: godot --headless --path . -s res://tests/test_rival_stops.gd

const TrackScene := preload("res://scenes/race_world/circuits/apex_ring/apex_circuit.tscn")
const TrackScript := preload("res://scripts/gt/gt_track.gd")
const RaceScript := preload("res://scripts/gt/gt_race.gd")
const WeatherScript := preload("res://scripts/gt/gt_weather.gd")
const Types := preload("res://scripts/gt/gt_types.gd")

const DRY: int = WeatherScript.Archetype.DRY_SUNNY

var failures: int = 0
var track: TrackScript


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
	track = TrackScript.new(ribbon, 14.0)
	_test_cover()
	_test_no_call_outside_the_window()
	_test_the_field_takes_one_stop_each()
	_test_pit_under_safety_car()
	_test_seed_replays_the_same_stops()
	ribbon.queue_free()
	await process_frame
	quit(1 if failures else 0)


func _race(laps: int, seed_value: int = 5) -> RaceScript:
	var race := RaceScript.new(track, laps, seed_value, DRY, 20)
	race.incidents_enabled = false
	race.set_tactic_mode(Types.TacticMode.AUTO)
	return race


func _a_rival(race: RaceScript) -> GtCar:
	for car: GtCar in race.cars:
		if car.team_id != race.player_team_id:
			return car
	return null


func _test_cover() -> void:
	var race: RaceScript = _race(15)
	var rival: GtCar = _a_rival(race)
	var chaser: GtCar = null
	for car: GtCar in race.cars:
		if car != rival and car.team_id != race.player_team_id and car.team_id != rival.team_id:
			chaser = car
			break
	for car: GtCar in race.cars:
		if car != rival and car != chaser:
			car.is_dnf = true
	rival.s = 0.40 * 15.0 * track.length
	rival.prev_s = rival.s
	rival.lap = floori(rival.s / track.length)
	rival.v = 50.0
	rival.tyre_age_laps = 4
	rival.fuel = 40.0
	chaser.s = rival.s - 1.5 * rival.v
	chaser.prev_s = chaser.s
	chaser.lap = rival.lap
	chaser.v = 22.0
	chaser.pit = GtPit.new()
	check(GtStrategy.should_cover(race, rival, GtStrategy.NEUTRAL_TACTIC), "a rival with 4 laps on its tyres covers a stop of the car 1.5 s behind")
	race.decide_strategy(rival)
	check(rival.pit_request >= 0, "the cover becomes a box call at the next sector line")
	rival.pit_request = -1
	rival.tyre_age_laps = 1
	check(not GtStrategy.should_cover(race, rival, GtStrategy.NEUTRAL_TACTIC), "fresh tyres do not cover")
	chaser.pit = null
	rival.tyre_age_laps = 4
	check(not GtStrategy.should_cover(race, rival, GtStrategy.NEUTRAL_TACTIC), "nobody pitting behind, nothing to cover")
	race.dispose()


func _test_no_call_outside_the_window() -> void:
	var race: RaceScript = _race(15)
	var car: GtCar = _a_rival(race)
	var window: Vector2i = race.stop_window_laps()
	car.fuel = 60.0
	car.mandatory_stop_done = false
	car.pit = null
	car.pit_request = -1
	car.lap = window.x - 2
	car.s = (float(car.lap) + 0.5) * track.length
	check(GtStrategy.mandatory_call(race, car, GtStrategy.NEUTRAL_TACTIC) == -1, "no call before the window opens (lap %d, the window opens at lap %d)" % [car.lap + 1, window.x])
	car.lap = window.y - 1
	car.s = (float(car.lap) + 0.5) * track.length
	check(GtStrategy.mandatory_call(race, car, GtStrategy.NEUTRAL_TACTIC) >= 0, "the failsafe calls a car in the last two laps of the window (lap %d)" % [car.lap + 1])
	car.lap = window.y
	car.s = (float(car.lap) + 0.5) * track.length
	check(GtStrategy.mandatory_call(race, car, GtStrategy.NEUTRAL_TACTIC) == -1, "no call once the window has closed (lap %d), a stop then would not count" % [car.lap + 1])
	race.dispose()


func _test_the_field_takes_one_stop_each() -> void:
	var race: RaceScript = _race(15)
	var stop_laps: Dictionary = {}
	var seen_stops: Dictionary = {}
	var ticks: int = 0
	while not race.is_finished() and ticks < 80000:
		race.step()
		ticks += 1
		for car: GtCar in race.cars:
			if car.stops > int(seen_stops.get(car.id, 0)):
				seen_stops[car.id] = car.stops
				stop_laps[car.lap] = true
	var ran_dry: int = 0
	for car: GtCar in race.cars:
		ran_dry += 1 if car.is_dnf and car.dnf_reason == "Out of Fuel" else 0
	check(ran_dry == 0, "no car runs out of fuel in a 15 lap race on the crew pick and the modes the walls chose (%d)" % ran_dry)
	var one_stop: int = 0
	var all_counted: bool = true
	var penalised: int = 0
	for car: GtCar in race.cars:
		if car.is_dnf:
			continue
		one_stop += 1 if car.stops == 1 else 0
		all_counted = all_counted and car.mandatory_stop_done
		penalised += 1 if car.mandatory_penalty_applied else 0
	check(all_counted, "every car that is still running took a counting stop")
	check(one_stop >= 16, "nearly the whole field stops exactly once in a dry 15 lap race (%d of 20)" % one_stop)
	check(penalised == 0, "nobody is given the mandatory-stop penalty (%d)" % penalised)
	check(stop_laps.size() >= 3, "the stops are spread over at least three laps (%d)" % stop_laps.size())
	race.dispose()


func _test_pit_under_safety_car() -> void:
	# Unit: the caution rule alone (a roll per team from its own hash stream, 70 % chance; worn cars always).
	var race: RaceScript = _race(10)
	for car: GtCar in race.cars:
		car.lap = 3
		car.s = 3.3 * track.length
		car.wear = 0.10
		car.mandatory_stop_done = false
	var green_calls: int = 0
	for car: GtCar in race.cars:
		green_calls += 1 if GtStrategy.caution_call(race, car) >= 0 else 0
	check(green_calls == 0, "no caution call under a green flag")
	race.set_flag(Types.Flag.SC, 1, "TEST SAFETY CAR", 28.0)
	var wants: int = 0
	var team_rolls: Dictionary = {}
	for car: GtCar in race.cars:
		var call: int = GtStrategy.caution_call(race, car)
		wants += 1 if call >= 0 else 0
		team_rolls[car.team_id] = call >= 0
	var same_per_team: bool = true
	for car: GtCar in race.cars:
		same_per_team = same_per_team and (GtStrategy.caution_call(race, car) >= 0) == bool(team_rolls[car.team_id])
	check(wants >= 6 and wants <= 18, "a safety car makes some teams use it and others not (%d of 20 cars call)" % wants)
	check(same_per_team, "both cars of a team make the same caution call (one roll per team)")
	race.cars[0].wear = 0.50
	race.cars[1].wear = 0.50
	check(GtStrategy.caution_call(race, race.cars[0]) >= 0 and GtStrategy.caution_call(race, race.cars[1]) >= 0, "a worn car always uses the caution")
	race.dispose()

	# Race: a safety car at 22% of the race, before any planned stop (25 % at the earliest): the box calls that
	# follow in the next 40 s can only be the caution rule's.
	race = _race(10)
	var ticks: int = 0
	while race.race_progress(race.standings()[0]) < 0.22 and ticks < 30000:
		race.step()
		ticks += 1
	var pitted_before: int = 0
	for car: GtCar in race.cars:
		pitted_before += 1 if car.stops > 0 or car.pit != null or car.pit_request >= 0 else 0
	race.set_flag(Types.Flag.SC, 1, "TEST SAFETY CAR", 28.0)
	race.safety_car["picked_up"] = true
	var called: Dictionary = {}
	ticks = 0
	while ticks < int(40.0 / Types.TICK_DT):
		race.step()
		ticks += 1
		for car: GtCar in race.cars:
			if car.pit_request >= 0 or car.pit != null:
				called[car.id] = true
	check(pitted_before == 0, "nobody had stopped or been called before the safety car (%d)" % pitted_before)
	check(called.size() >= 6, "within 40 s of the safety car, cars not yet due their stop are called in by the caution rule (%d of 20)" % called.size())
	race.dispose()


func _stops_log(seed_value: int) -> String:
	var race: RaceScript = _race(10, seed_value)
	var ticks: int = 0
	var log_parts: Array[String] = []
	var seen: Dictionary = {}
	while not race.is_finished() and ticks < 60000:
		race.step()
		ticks += 1
		for car: GtCar in race.cars:
			if car.stops > int(seen.get(car.id, 0)):
				seen[car.id] = car.stops
				log_parts.append("%d@%d" % [car.id, car.lap])
	var order: Array[String] = []
	for car: GtCar in race.standings():
		order.append(str(car.id))
	race.dispose()
	return "%s|%s" % [",".join(log_parts), ",".join(order)]


func _test_seed_replays_the_same_stops() -> void:
	var first: String = _stops_log(11)
	var second: String = _stops_log(11)
	check(first == second and first.length() > 20, "the same seed replays the same stops and finishing order")
