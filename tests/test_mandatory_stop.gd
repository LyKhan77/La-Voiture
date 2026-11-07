extends SceneTree

## Fase 32 Task 5: the mandatory pit stop of 10 and 15 lap races. Rules (spec 5a): any completed service counts once
## the race is 20% run; a puncture, damage or slick/rain-class stop counts at any time; nothing counts after 80%; a
## car without a counting stop is penalised at the flag; DNF cars, 3 lap and 5 lap races never are.
## Run: godot --headless --path . -s res://tests/test_mandatory_stop.gd

const TrackScene := preload("res://scenes/race_world/circuits/apex_ring/apex_circuit.tscn")
const TrackScript := preload("res://scripts/gt/gt_track.gd")
const RaceScript := preload("res://scripts/gt/gt_race.gd")
const WeatherScript := preload("res://scripts/gt/gt_weather.gd")
const Types := preload("res://scripts/gt/gt_types.gd")
const WorldScene := preload("res://scenes/race_weekend_world.tscn")
const DirectorScript := preload("res://scripts/world/weekend/race_weekend_director.gd")

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
	_test_rule_shape()
	_test_counting_rules()
	_test_penalty_at_the_flag()
	_test_forced_flag_on_pit_entry()
	_test_reminder_radio()
	_test_clips_exist()
	_test_in_sim_stop_and_no_stop()
	_test_the_label_matches_what_counts()
	_test_a_forgotten_stop_is_called_in_time()
	ribbon.queue_free()
	await process_frame
	await _test_deck_label()
	quit(1 if failures else 0)


func _race(laps: int) -> RaceScript:
	var race := RaceScript.new(track, laps, 5, DRY, 20)
	race.incidents_enabled = false
	return race


func _at_progress(race: RaceScript, car: GtCar, progress: float) -> void:
	car.s = progress * float(race.laps) * track.length
	car.lap = floori(car.s / track.length)


func _test_rule_shape() -> void:
	check(_race(15).mandatory_stop_required() and _race(10).mandatory_stop_required(), "10 and 15 lap races require a stop")
	check(not _race(5).mandatory_stop_required() and not _race(3).mandatory_stop_required(), "3 and 5 lap races do not")
	var status: Dictionary = _race(15).mandatory_stop_status(_race(15).cars[0])
	check(int(status["open_lap"]) == 4 and int(status["close_lap"]) == 12, "a 15 lap window runs from lap 4 to lap 12 (%d to %d)" % [int(status["open_lap"]), int(status["close_lap"])])
	status = _race(10).mandatory_stop_status(_race(10).cars[0])
	check(int(status["open_lap"]) == 3 and int(status["close_lap"]) == 8, "a 10 lap window runs from lap 3 to lap 8 (%d to %d)" % [int(status["open_lap"]), int(status["close_lap"])])
	var race: RaceScript = _race(15)
	check(race.mandatory_penalty_s() >= Types.MANDATORY_PENALTY_FLOOR_S, "the penalty is at least the floor (%.1f s)" % race.mandatory_penalty_s())
	check(race.mandatory_penalty_s() >= Types.MANDATORY_PENALTY_PIT_LOSS_MULT * GtStrategy.pit_loss_s(race, track.length / 45.0), "the penalty beats 1.5 times the pit loss")
	race.dispose()


func _test_counting_rules() -> void:
	var race: RaceScript = _race(15)
	var car: GtCar = race.cars[0]
	_at_progress(race, car, 0.50)
	race.note_stop_completed(car, false)
	check(car.mandatory_stop_done, "a stop at 50% counts")
	car.mandatory_stop_done = false
	_at_progress(race, car, 0.10)
	race.note_stop_completed(car, false)
	check(not car.mandatory_stop_done, "an early voluntary stop at 10% does not count")
	race.note_stop_completed(car, true)
	check(car.mandatory_stop_done, "a forced stop (puncture, damage, rain tyres) at 10% counts")
	car.mandatory_stop_done = false
	_at_progress(race, car, 0.85)
	race.note_stop_completed(car, false)
	race.note_stop_completed(car, true)
	check(not car.mandatory_stop_done, "nothing counts after 80%")
	_at_progress(race, car, 0.50)
	race.set_flag(Types.Flag.SC, 1, "TEST", 28.0)
	race.note_stop_completed(car, false)
	check(car.mandatory_stop_done, "a stop under the safety car counts")
	var short_race: RaceScript = _race(5)
	var short_car: GtCar = short_race.cars[0]
	_at_progress(short_race, short_car, 0.50)
	short_race.note_stop_completed(short_car, false)
	check(not short_car.mandatory_stop_done, "a 5 lap race keeps no mandatory-stop book")
	short_race.dispose()
	race.dispose()


func _test_penalty_at_the_flag() -> void:
	var race: RaceScript = _race(10)
	var runner: GtCar = race.cars[0]
	var clean: GtCar = race.cars[1]
	var retired: GtCar = race.cars[2]
	clean.mandatory_stop_done = true
	retired.is_dnf = true
	race.step_ticks(20)
	for car: GtCar in [runner, clean, retired]:
		race.mark_finished(car)
	check(is_equal_approx(runner.penalty_owed_s, race.mandatory_penalty_s()), "a car with no counting stop owes the penalty at the flag (%.1f s)" % runner.penalty_owed_s)
	check(is_equal_approx(race.classified_time(runner), runner.finished_at + race.mandatory_penalty_s()), "the penalty is part of its classified time")
	check(clean.penalty_owed_s == 0.0, "a car that stopped owes nothing")
	check(retired.penalty_owed_s == 0.0, "a retired car is never penalised")
	race.mark_finished(runner)
	check(is_equal_approx(runner.penalty_owed_s, race.mandatory_penalty_s()), "the penalty is applied once")
	race.dispose()
	var short_race: RaceScript = _race(5)
	short_race.step_ticks(20)
	short_race.mark_finished(short_race.cars[0])
	check(short_race.cars[0].penalty_owed_s == 0.0, "a 5 lap finisher without a stop owes nothing")
	short_race.dispose()


func _test_forced_flag_on_pit_entry() -> void:
	var race: RaceScript = _race(15)
	var car: GtCar = race.cars[0]
	car.compound = Types.Compound.SOFT
	race._driving.enter_pit_lane(car, Types.Compound.MEDIUM)
	check(not car.pit.forced, "a slick to slick stop is voluntary")
	car.pit = null
	race._driving.enter_pit_lane(car, Types.Compound.WET)
	check(car.pit.forced, "a slick to rain-tyre stop is forced")
	car.pit = null
	car.damage = 30.0
	race._driving.enter_pit_lane(car, Types.Compound.MEDIUM)
	check(car.pit.forced, "a stop with damage is forced")
	car.pit = null
	car.damage = 0.0
	car.is_punctured = true
	race._driving.enter_pit_lane(car, Types.Compound.MEDIUM)
	check(car.pit.forced, "a stop with a puncture is forced")
	car.pit = null
	car.is_punctured = false
	car.compound = Types.Compound.INTERMEDIATE
	race._driving.enter_pit_lane(car, Types.Compound.WET)
	check(car.pit.forced, "a weather stop from inters to wets is forced (rain tyre to rain tyre)")
	car.pit = null
	car.compound = Types.Compound.WET
	race._driving.enter_pit_lane(car, Types.Compound.INTERMEDIATE)
	check(car.pit.forced, "and from wets to inters")
	car.pit = null
	car.compound = Types.Compound.WET
	race._driving.enter_pit_lane(car, Types.Compound.WET)
	check(not car.pit.forced, "a fresh set of the same rain tyre is a voluntary stop")
	race.dispose()


func _test_reminder_radio() -> void:
	var race: RaceScript = _race(10)
	var mine: GtCar = null
	for car: GtCar in race.cars:
		if car.team_id == race.player_team_id:
			mine = car
			break
	race.step_ticks(5)
	_at_progress(race, mine, 0.70)
	race.step_ticks(3)
	race.step_ticks(3)
	var count: int = 0
	for message: Dictionary in race.radio_history:
		if int(message["car_id"]) == mine.id and String(message["text"]) == "Window closes in two laps. Box now.":
			count += 1
	check(count == 1, "the engineer warns once that the window closes in two laps (%d)" % count)
	race.dispose()


func _test_clips_exist() -> void:
	for clip: String in ["eng_mandatory_window", "eng_mandatory_closing"]:
		check(FileAccess.file_exists("res://assets/audio/radio/voice/%s.wav" % clip), "radio clip %s.wav exists" % clip)
	var manifest: String = FileAccess.get_file_as_string("res://assets/audio/radio/voice/manifest.json")
	check(manifest.contains("Window closes in two laps") and manifest.contains("Mandatory stop window is open"), "both mandatory-stop lines are in the radio manifest")


func _solo(laps: int, stop_at: float) -> Dictionary:
	var race: RaceScript = RaceScript.new(track, laps, 5, DRY, 1)
	race.incidents_enabled = false
	var car: GtCar = race.cars[0]
	if stop_at < 0.0:
		car.fuel = 60.0 # the light crew pick would run dry before the flag: a car that never stops needs the full distance
	var asked: bool = false
	var ticks: int = 0
	while car.finished_at < 0.0 and not car.is_dnf and ticks < 60000:
		if stop_at >= 0.0 and not asked and race.race_progress(car) >= stop_at:
			race.request_pit(car.id, Types.Compound.MEDIUM)
			asked = true
		race.step()
		ticks += 1
	var out: Dictionary = {"done": car.mandatory_stop_done, "penalty": car.penalty_owed_s, "stops": car.stops, "owed": race.mandatory_penalty_s(),
			"classified": race.classified_time(car), "finished_at": car.finished_at}
	race.dispose()
	return out


func _test_in_sim_stop_and_no_stop() -> void:
	var with_stop: Dictionary = _solo(10, 0.35)
	check(int(with_stop["stops"]) == 1 and bool(with_stop["done"]), "a solo car that boxes at 35% completes one stop and it counts")
	check(float(with_stop["penalty"]) == 0.0, "and owes nothing at the flag")
	var no_stop: Dictionary = _solo(10, -1.0)
	check(int(no_stop["stops"]) == 0 and not bool(no_stop["done"]), "a solo car that never boxes has no counting stop")
	check(is_equal_approx(float(no_stop["classified"]), float(no_stop["finished_at"]) + float(no_stop["owed"])), "its classified time carries the penalty")


## A stop called in lap L (1-based) enters the lane at the end of that lap, and that is when the window is read:
## the laps the deck shows are exactly the laps whose calls count.
func _call_in_lap(laps: int, lap_number: int) -> Dictionary:
	var race: RaceScript = RaceScript.new(track, laps, 5, DRY, 1)
	race.incidents_enabled = false
	var car: GtCar = race.cars[0]
	car.fuel = 80.0
	var asked: bool = false
	var ticks: int = 0
	while car.finished_at < 0.0 and not car.is_dnf and ticks < 60000:
		if not asked and car.lap + 1 >= lap_number:
			race.request_pit(car.id, Types.Compound.MEDIUM)
			asked = true
		race.step()
		ticks += 1
		if car.stops >= 1 and car.pit == null and not car.is_dnf and car.finished_at < 0.0 and car.lap + 1 > lap_number + 1:
			break
	var out: Dictionary = {"done": car.mandatory_stop_done, "stops": car.stops}
	race.dispose()
	return out


func _test_the_label_matches_what_counts() -> void:
	var laps: int = 10
	var window: Dictionary = _race(laps).mandatory_stop_status(_race(laps).cars[0])
	var open_lap: int = int(window["open_lap"])
	var close_lap: int = int(window["close_lap"])
	check(bool(_call_in_lap(laps, close_lap)["done"]), "a stop called in the last lap the deck shows (lap %d) counts" % close_lap)
	check(not bool(_call_in_lap(laps, close_lap + 1)["done"]), "a stop called one lap later does not")
	check(bool(_call_in_lap(laps, open_lap)["done"]), "a stop called in the first lap the deck shows (lap %d) counts" % open_lap)
	check(not bool(_call_in_lap(laps, open_lap - 1)["done"]), "a stop called one lap earlier does not")


## A player who forgets the stop on the light crew pick runs short of fuel long before the window closes: the engineer says
## so in time (while there is fuel to reach the box), with advice that works (box), not "switch to CONSERVE".
func _test_a_forgotten_stop_is_called_in_time() -> void:
	for laps: int in [10, 15]:
		var race: RaceScript = RaceScript.new(track, laps, 5, DRY, 20)
		race.incidents_enabled = false
		var mine: GtCar = race.get_car(race.player_team_id * 2)
		var called_at_fuel: float = -1.0
		var conserve_advice: bool = false
		var ticks: int = 0
		while not mine.is_dnf and mine.finished_at < 0.0 and ticks < 40000:
			race.step()
			ticks += 1
			for message: Dictionary in race.radio_history:
				if int(message["car_id"]) != mine.id:
					continue
				if String(message["text"]) == "Fuel is short. Box this lap for fuel." and called_at_fuel < 0.0:
					called_at_fuel = mine.fuel
				if String(message["text"]).begins_with("Fuel critical!"):
					conserve_advice = true
			if called_at_fuel >= 0.0 or mine.is_dnf:
				break
		check(called_at_fuel > 0.0, "%d laps: the engineer calls the forgotten stop while the car still has fuel (%.1f kg left)" % [laps, called_at_fuel])
		check(not conserve_advice, "%d laps: and does not tell a car with a stop ahead to switch to CONSERVE" % laps)
		race.dispose()


func _test_deck_label() -> void:
	var config_script: Script = load("res://scripts/core/race_config_data.gd")
	var config = config_script.reset()
	config.total_laps = 10
	var world: Node3D = WorldScene.instantiate()
	root.add_child(world)
	world.set_process(false)
	var hud: RaceHud = world.hud
	var race: GtRace = world.race
	race.incidents_enabled = false
	world.director._enter(DirectorScript.State.GREEN_RACING)
	for _i: int in range(40):
		world.step(1.0 / 60.0)
	hud.refresh_all()
	var deck: TacticalDeck = hud.deck
	var car: GtCar = race.get_car(deck.deck_car_id)
	car.mandatory_stop_done = false
	deck.refresh()
	check(deck.stop_label.visible and deck.stop_label.text.contains("REQUIRED"), "the deck shows the stop as REQUIRED (%s)" % deck.stop_label.text)
	car.mandatory_stop_done = true
	deck.refresh()
	check(deck.stop_label.text.contains("DONE"), "the deck shows DONE after the stop (%s)" % deck.stop_label.text)
	race.dispose()
	world.queue_free()
	await process_frame
	config = config_script.reset()
	config.total_laps = 5
	world = WorldScene.instantiate()
	root.add_child(world)
	world.set_process(false)
	world.race.incidents_enabled = false
	world.director._enter(DirectorScript.State.GREEN_RACING)
	for _i: int in range(20):
		world.step(1.0 / 60.0)
	world.hud.refresh_all()
	world.hud.deck.refresh()
	check(not world.hud.deck.stop_label.visible, "a 5 lap race hides the stop label")
	world.race.dispose()
	world.queue_free()
	await process_frame
