extends SceneTree

## Fase 32 radio round: the engineer tells the player's cars what the rules do to them (the missed mandatory stop and
## its penalty, whether a stop counts, the window opening, the last lap, a low ERS battery, a steward penalty) and the
## driver answers with a spoken acknowledgement that varies per call. Every new line has a Kokoro clip for every driver
## voice. The missed stop also shows on the deck, in a stewards-style banner and in the classification.
## Run: godot --headless --path . -s res://tests/test_radio_calls.gd

const TrackScene := preload("res://scenes/race_world/circuits/apex_ring/apex_circuit.tscn")
const TrackScript := preload("res://scripts/gt/gt_track.gd")
const RaceScript := preload("res://scripts/gt/gt_race.gd")
const WeatherScript := preload("res://scripts/gt/gt_weather.gd")
const Types := preload("res://scripts/gt/gt_types.gd")
const WorldScene := preload("res://scenes/race_weekend_world.tscn")
const DirectorScript := preload("res://scripts/world/weekend/race_weekend_director.gd")

const DRY: int = WeatherScript.Archetype.DRY_SUNNY
## Long enough for any acknowledgement to fall due.
const ACK_WAIT_S: float = 4.0

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
	_test_window_missed_is_announced()
	_test_the_driver_answers_the_missed_window()
	_test_a_stop_that_counts_and_one_that_does_not()
	_test_last_lap_call()
	_test_low_battery_call()
	_test_steward_penalty_call()
	_test_window_open_info_for_a_manual_desk()
	_test_finish_with_a_missed_stop()
	_test_chequered_reactions()
	_test_acknowledgements_vary_and_are_deterministic()
	_test_every_line_has_a_clip_for_every_voice()
	_test_classification_rows()
	ribbon.queue_free()
	await process_frame
	await _test_deck_label()
	await _test_podium_note()
	quit(1 if failures else 0)


func _race(laps: int) -> RaceScript:
	var race := RaceScript.new(track, laps, 5, DRY, 20)
	race.incidents_enabled = false
	return race


## The player's two cars, in field order.
func _mine(race: RaceScript) -> Array[GtCar]:
	var found: Array[GtCar] = []
	for car: GtCar in race.cars:
		if car.team_id == race.player_team_id:
			found.append(car)
	return found


func _wait(race: RaceScript, seconds: float) -> void:
	race.step_ticks(ceili(seconds / Types.TICK_DT))


## The texts a car's radio sent since `mark`, from one speaker.
func _texts(race: RaceScript, car: GtCar, speaker: String, mark: int = 0) -> Array[String]:
	var found: Array[String] = []
	for index: int in range(mark, race.radio_history.size()):
		var message: Dictionary = race.radio_history[index]
		if int(message["car_id"]) == car.id and String(message["speaker"]) == speaker:
			found.append(String(message["text"]))
	return found


func _count_starting(texts: Array[String], prefix: String) -> int:
	var count: int = 0
	for text: String in texts:
		if text.begins_with(prefix):
			count += 1
	return count


func _test_window_missed_is_announced() -> void:
	var race: RaceScript = _race(10)
	var cars: Array[GtCar] = _mine(race)
	var mine: GtCar = cars[0]
	var events: Array[Dictionary] = []
	race.steward_event.connect(func(event: Dictionary) -> void: events.append(event))
	var window: Vector2i = race.stop_window_laps()
	mine.lap = window.y - 1
	race.step_ticks(2)
	check(_count_starting(_texts(race, mine, "engineer"), "Window missed.") == 0 and not mine.mandatory_missed, "inside the last window lap nothing is missed yet")
	mine.lap = window.y
	var mark: int = race.radio_history.size()
	race.step_ticks(2)
	var calls: Array[String] = _texts(race, mine, "engineer", mark)
	check(_count_starting(calls, "Window missed.") == 1 and calls[0].contains("+%d seconds" % roundi(race.mandatory_penalty_s())), "the engineer announces the missed window with the penalty (%s)" % str(calls))
	check(mine.mandatory_missed, "the car is marked as having missed the window")
	race.step_ticks(4)
	check(_count_starting(_texts(race, mine, "engineer"), "Window missed.") == 1, "and says it only once")
	check(_count_starting(calls, "Window closes") == 0, "and never also warns that the window is about to close")
	var banner: Dictionary = {}
	for event: Dictionary in events:
		if int(event.get("car_id", -1)) == mine.id:
			banner = event
	check(not banner.is_empty() and int(banner["verdict"]) == GtStewards.Verdict.PENALTY and String(banner["text"]).contains("MANDATORY STOP MISSED"), "a stewards-style penalty banner is raised (%s)" % str(banner.get("text", "")))
	var mate: GtCar = cars[1]
	check(_count_starting(_texts(race, mate, "engineer"), "Window missed.") == 0, "the teammate, still inside its window, hears nothing")
	mate.mandatory_stop_done = true
	mate.lap = window.y + 1
	race.step_ticks(2)
	check(not mate.mandatory_missed, "a car that made its stop is never marked")
	race.dispose()
	var short: RaceScript = _race(5)
	var short_car: GtCar = _mine(short)[0]
	short_car.lap = 4
	short.step_ticks(2)
	check(not short_car.mandatory_missed and _count_starting(_texts(short, short_car, "engineer"), "Window missed.") == 0, "a 5 lap race has no window to miss")
	short.dispose()


func _test_the_driver_answers_the_missed_window() -> void:
	var race: RaceScript = _race(10)
	var mine: GtCar = _mine(race)[0]
	mine.lap = race.stop_window_laps().y
	race.step_ticks(2)
	var engineer_id: int = -1
	for message: Dictionary in race.radio_history:
		if String(message["speaker"]) == "engineer" and String(message["text"]).begins_with("Window missed."):
			engineer_id = int(message["id"])
	var replied_early: bool = _texts(race, mine, "driver").size() > 0
	race.driver_radio_cooldown.clear()
	_wait(race, ACK_WAIT_S)
	var answers: Array[String] = _texts(race, mine, "driver")
	check(not replied_early, "the driver does not talk over the engineer")
	check(answers.has("Understood. We take the penalty."), "the driver answers the missed window (%s)" % str(answers))
	var linked: bool = false
	for message: Dictionary in race.radio_history:
		if String(message["speaker"]) == "driver" and int(message["reply_to"]) == engineer_id and engineer_id > 0:
			linked = true
	check(linked, "and the answer is linked to the engineer call")
	race.driver_radio_cooldown.clear()
	race.push_radio(mine, "driver", "Copy, box this lap.", false, false, 5)
	check(race.can_push_driver_radio(mine.id), "an acknowledgement does not mute the driver's routine calls")
	race.push_radio(mine, "driver", "Had a snap of oversteer! Lost some time.")
	check(not race.can_push_driver_radio(mine.id), "while a routine call still does")
	race.dispose()


func _test_a_stop_that_counts_and_one_that_does_not() -> void:
	var race: RaceScript = _race(10)
	var cars: Array[GtCar] = _mine(race)
	var first: GtCar = cars[0]
	var second: GtCar = cars[1]
	race.note_stop_completed(first, false, 0.5)
	_wait(race, 3.0)
	check(_texts(race, first, "engineer").has("Stop counts. Mandatory stop complete."), "a counting stop is confirmed by the engineer")
	var mark: int = race.radio_history.size()
	race.note_stop_completed(first, false, 0.6)
	_wait(race, 3.0)
	check(_count_starting(_texts(race, first, "engineer", mark), "Stop counts") + _count_starting(_texts(race, first, "engineer", mark), "That stop does not") == 0, "an extra stop after the mandatory one adds no call")
	race.note_stop_completed(second, false, 0.05)
	_wait(race, 3.0)
	check(_texts(race, second, "engineer").has("That stop does not count toward the mandatory stop."), "a stop made before the window opens is called out as not counting")
	check(not second.mandatory_stop_done, "and it indeed does not count")
	race.note_stop_completed(second, true, 0.05)
	_wait(race, 3.0)
	check(_texts(race, second, "engineer").has("Stop counts. Mandatory stop complete."), "a forced stop counts at any time and is confirmed")
	_wait(race, ACK_WAIT_S)
	check(_texts(race, first, "driver").has("Copy, the stop counts."), "the driver acknowledges a counting stop")
	race.dispose()
	var short: RaceScript = _race(5)
	var short_car: GtCar = _mine(short)[0]
	short.note_stop_completed(short_car, false, 0.05)
	_wait(short, 3.0)
	check(_texts(short, short_car, "engineer").is_empty(), "a 5 lap race has no mandatory stop to confirm")
	short.dispose()


func _test_last_lap_call() -> void:
	var race: RaceScript = _race(10)
	var mine: GtCar = _mine(race)[0]
	mine.lap = race.laps - 2
	race.step_ticks(2)
	check(_count_starting(_texts(race, mine, "engineer"), "Last lap.") == 0, "the call waits for the last lap")
	mine.lap = race.laps - 1
	race.step_ticks(2)
	race.step_ticks(2)
	check(_count_starting(_texts(race, mine, "engineer"), "Last lap. Bring it home.") == 1, "the engineer calls the last lap once")
	_wait(race, ACK_WAIT_S)
	var answers: Array[String] = _texts(race, mine, "driver")
	check(answers.has("Last lap, copy. Bringing it home.") or answers.has("Copy. Everything I have left."), "the driver answers the last lap call (%s)" % str(answers))
	race.dispose()


func _test_low_battery_call() -> void:
	var race: RaceScript = _race(10)
	var mine: GtCar = _mine(race)[0]
	mine.ers_mode = Types.ErsMode.DEPLOY
	mine.ers_battery = 60.0
	race.step_ticks(2)
	check(_count_starting(_texts(race, mine, "engineer"), "Battery is low.") == 0, "a healthy battery draws no call")
	mine.ers_battery = 10.0
	race.step_ticks(2)
	race.step_ticks(2)
	check(_count_starting(_texts(race, mine, "engineer"), "Battery is low. Switch ERS to HARVEST to recharge.") == 1, "a drained battery under deployment draws one call")
	mine.ers_battery = 80.0
	race.step_ticks(2)
	mine.ers_battery = 10.0
	race.step_ticks(2)
	check(_count_starting(_texts(race, mine, "engineer"), "Battery is low.") == 2, "after recharging the call is armed again")
	_wait(race, ACK_WAIT_S)
	check(_texts(race, mine, "driver").has("Copy, harvesting."), "the driver answers the battery call")
	mine.ers_mode = Types.ErsMode.HARVEST
	mine.ers_battery = 5.0
	var mark: int = race.radio_history.size()
	race.step_ticks(2)
	check(_count_starting(_texts(race, mine, "engineer", mark), "Battery is low.") == 0, "a car already harvesting is not told to harvest")
	race.dispose()


func _test_steward_penalty_call() -> void:
	var race: RaceScript = _race(10)
	var mine: GtCar = _mine(race)[0]
	var rival: GtCar = race.cars[race.cars.size() - 1]
	var case_file: Dictionary = {"id": 99, "kind": GtStewards.Kind.AT_FAULT, "verdict": GtStewards.Verdict.PENDING, "offender_id": mine.id, "other_id": rival.id, "text": ""}
	race.stewards.cases.append(case_file)
	race.stewards._decide(case_file)
	var calls: Array[String] = _texts(race, mine, "engineer")
	check(_count_starting(calls, "Steward penalty: +5 seconds.") == 1, "the engineer reports a steward penalty against the player's car (%s)" % str(calls))
	var rival_case: Dictionary = {"id": 100, "kind": GtStewards.Kind.AT_FAULT, "verdict": GtStewards.Verdict.PENDING, "offender_id": rival.id, "other_id": mine.id, "text": ""}
	race.stewards.cases.append(rival_case)
	var mark: int = race.radio_history.size()
	race.stewards._decide(rival_case)
	check(race.radio_history.size() == mark, "a penalty against a rival is no radio call for the player")
	var no_action: Dictionary = {"id": 101, "kind": GtStewards.Kind.RACING_INCIDENT, "verdict": GtStewards.Verdict.PENDING, "offender_id": mine.id, "other_id": rival.id, "text": ""}
	race.stewards.cases.append(no_action)
	race.stewards._decide(no_action)
	check(_count_starting(_texts(race, mine, "engineer"), "Steward penalty") == 1, "no further action is no penalty call")
	_wait(race, ACK_WAIT_S)
	check(_texts(race, mine, "driver").has("Copy. I will serve it in the pits."), "the driver answers the steward penalty")
	race.dispose()


func _test_window_open_info_for_a_manual_desk() -> void:
	var race: RaceScript = _race(10)
	race.coach_enabled = false
	race.tactic_mode = Types.TacticMode.MANUAL
	var mine: GtCar = _mine(race)[0]
	mine.s = 0.5 * float(race.laps) * track.length
	mine.lap = floori(mine.s / track.length)
	mine.fuel = 40.0
	race._decide_stop(mine)
	check(_texts(race, mine, "engineer").has("Mandatory stop window is open."), "a MANUAL desk without the coach is still told the window is open")
	race.time += 30.0
	race._decide_stop(mine)
	check(_count_starting(_texts(race, mine, "engineer"), "Mandatory stop window is open.") == 1, "and only once")
	race.dispose()


func _test_finish_with_a_missed_stop() -> void:
	var race: RaceScript = _race(10)
	var cars: Array[GtCar] = _mine(race)
	var mine: GtCar = cars[0]
	cars[1].mandatory_stop_done = true
	race.mark_finished(mine)
	check(is_equal_approx(mine.mandatory_penalty_s, race.mandatory_penalty_s()) and mine.penalty_owed_s >= mine.mandatory_penalty_s, "the penalty at the flag is kept on the car")
	check(_count_starting(_texts(race, mine, "engineer"), "Penalty added") == 0, "the penalty note does not talk over the chequered flag call")
	_wait(race, 5.0)
	var calls: Array[String] = _texts(race, mine, "engineer")
	check(_count_starting(calls, "Penalty added for the missed mandatory stop: +") == 1, "the engineer then explains the penalty (%s)" % str(calls))
	_wait(race, ACK_WAIT_S)
	check(_texts(race, mine, "driver").has("Understood. I should have boxed."), "the driver answers the penalty note")
	var done_car: GtCar = cars[1]
	done_car.mandatory_stop_done = true
	race.mark_finished(done_car)
	_wait(race, 8.0)
	check(done_car.mandatory_penalty_s == 0.0 and _count_starting(_texts(race, done_car, "engineer"), "Penalty added") == 0, "a car that made its stop gets no penalty note")
	var rival: GtCar = race.cars[race.cars.size() - 1]
	race.mark_finished(rival)
	_wait(race, 8.0)
	check(_texts(race, rival, "engineer").is_empty(), "a rival never gets the player's engineer")
	race.dispose()


func _test_chequered_reactions() -> void:
	var race: RaceScript = _race(10)
	var mine: GtCar = _mine(race)[0]
	var expectations: Dictionary = {
		"Chequered flag! P1. Solid job today.": "Yes! We did it! Thank you, team!",
		"Chequered flag! P2. Solid job today.": "Podium! Great job, everyone!",
		"Chequered flag! P3. Solid job today.": "Podium! Great job, everyone!",
		"Chequered flag! P9. Solid job today.": "Chequered flag. Good effort, team.",
	}
	for text: String in expectations:
		var mark: int = race.radio_history.size()
		race.push_radio(mine, "engineer", text)
		_wait(race, ACK_WAIT_S)
		check(_texts(race, mine, "driver", mark).has(String(expectations[text])), "the driver reacts to '%s' with '%s'" % [text, expectations[text]])
	mine.mandatory_penalty_s = 30.0
	var mark_penalty: int = race.radio_history.size()
	race.push_radio(mine, "engineer", "Chequered flag! P3. Solid job today.")
	_wait(race, ACK_WAIT_S)
	check(_texts(race, mine, "driver", mark_penalty).is_empty(), "a driver who owes a penalty does not celebrate before hearing it")
	race.dispose()


func _test_acknowledgements_vary_and_are_deterministic() -> void:
	var race: RaceScript = _race(10)
	var mine: GtCar = _mine(race)[0]
	var seen: Dictionary = {}
	for key: int in range(40):
		seen[GtRadioReplies.driver_ack("Box this lap, confirm SOFT tyres.", mine, race.race_seed, key)] = true
	check(seen.size() == 2 and not seen.has(""), "a box call is answered in two different ways (%s)" % str(seen.keys()))
	var same: bool = true
	for key: int in range(10):
		same = same and GtRadioReplies.driver_ack("Last lap. Bring it home.", mine, 123, key) == GtRadioReplies.driver_ack("Last lap. Bring it home.", mine, 123, key)
	check(same, "the same seed, car and call always give the same answer")
	check(GtRadioReplies.driver_ack("Good stop: 3.1s. Out now, watch pit exit.", mine, 1, 1) == "", "a routine pit report needs no answer")
	check(GtRadioReplies.driver_ack("Affirmative, executing BOX.", mine, 1, 1) == "", "nor does an executing confirmation")
	race.dispose()
	var first: RaceScript = _race(10)
	var second: RaceScript = _race(10)
	for run: RaceScript in [first, second]:
		_mine(run)[0].lap = run.stop_window_laps().y
		run.step_ticks(2)
		_wait(run, ACK_WAIT_S)
	var texts_first: Array[String] = _texts(first, _mine(first)[0], "driver")
	var texts_second: Array[String] = _texts(second, _mine(second)[0], "driver")
	check(not texts_first.is_empty() and texts_first == texts_second and first.rng.next() == second.rng.next(), "two runs of one seed say the same things and leave the race stream alone")
	first.dispose()
	second.dispose()


func _test_every_line_has_a_clip_for_every_voice() -> void:
	var engineer_samples: Array[String] = [
		"Window missed. +30 seconds will be added at the flag.",
		"Mandatory stop window is open.",
		"Stop counts. Mandatory stop complete.",
		"That stop does not count toward the mandatory stop.",
		"Last lap. Bring it home.",
		"Steward penalty: +5 seconds. Serve it in the pit box or it is added at the flag.",
		"Battery is low. Switch ERS to HARVEST to recharge.",
		"Penalty added for the missed mandatory stop: +30 seconds. The classification will change.",
	]
	var missing_engineer: Array[String] = []
	for text: String in engineer_samples:
		if RadioVoice.find("engineer", text).is_empty():
			missing_engineer.append(text)
	check(missing_engineer.is_empty(), "every new engineer line has a clip (%s)" % str(missing_engineer))
	var missing_driver: Array[String] = []
	var wrong_voice: int = 0
	for text: String in GtRadioReplies.ack_texts():
		for car_id: int in range(20):
			var clip: Dictionary = RadioVoice.find("driver", text, car_id)
			if clip.is_empty():
				missing_driver.append("%s/%d" % [text, car_id])
			elif String(clip["voice"]) != RadioVoice.voice_of(car_id):
				wrong_voice += 1
	check(missing_driver.is_empty(), "every acknowledgement has a clip for all 20 drivers (%d missing)" % missing_driver.size())
	check(wrong_voice == 0, "each driver answers in its own voice")
	check(GtRadioReplies.ack_texts().size() >= 12, "the acknowledgement set is rich enough (%d lines)" % GtRadioReplies.ack_texts().size())


func _test_classification_rows() -> void:
	var race: RaceScript = _race(10)
	var mine: GtCar = _mine(race)[0]
	race.mark_finished(mine)
	for car: GtCar in race.cars:
		if car != mine:
			car.is_dnf = true
	var results: Dictionary = WinningScene.capture_results(race)
	var row: Dictionary = {}
	for entry: Dictionary in results["order"]:
		if int(entry["id"]) == mine.id:
			row = entry
	check(not row.is_empty() and is_equal_approx(float(row["penalty_s"]), mine.penalty_owed_s) and float(row["penalty_s"]) > 0.0, "a classification row carries the penalty it was given")
	check(WinningScene.penalty_tag(row).contains("PEN") and WinningScene.penalty_tag(row).contains("+%d" % roundi(mine.penalty_owed_s)), "and shows it as a tag (%s)" % WinningScene.penalty_tag(row))
	var notes: Array = results.get("notes", [])
	check(notes.size() == 1 and String(notes[0]).contains("ROAD P1") and String(notes[0]).contains("-> P1") and String(notes[0]).contains(mine.code), "the results explain the move down the order to the player (%s)" % str(notes))
	check(WinningScene.penalty_tag({"penalty_s": 0.0}) == "", "a clean row has no tag")
	check(WinningScene.penalty_tag({"penalty_s": 30.0, "is_dnf": true}) == "", "a retired car shows DNF, not a penalty")
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
	car.mandatory_missed = false
	deck.refresh()
	check(not deck.stop_label.text.contains("PENALTY"), "before the window closes the label shows no penalty (%s)" % deck.stop_label.text)
	car.mandatory_missed = true
	deck.refresh()
	check(deck.stop_label.text.contains("PENALTY") and deck.stop_label.text.contains("+%d" % roundi(race.mandatory_penalty_s())), "after the window closes the label shows the penalty (%s)" % deck.stop_label.text)
	check(bool(race.mandatory_stop_status(car)["missed"]), "the stop status reports the miss")
	race.dispose()
	world.queue_free()
	await process_frame


func _test_podium_note() -> void:
	var race: RaceScript = _race(10)
	var cars: Array[GtCar] = _mine(race)
	var rivals: Array[GtCar] = []
	for car: GtCar in race.cars:
		if car.team_id != race.player_team_id:
			rivals.append(car)
	# On the road: the player's car first, then three rivals; its 30 s sends it to the back.
	race.mark_finished(cars[0])
	for index: int in range(3):
		race.time += 5.0
		rivals[index].mandatory_stop_done = true
		race.mark_finished(rivals[index])
	for car: GtCar in race.cars:
		if car.finished_at < 0.0:
			car.is_dnf = true
	var results: Dictionary = WinningScene.capture_results(race)
	var notes: Array = results.get("notes", [])
	check(notes.size() == 1 and String(notes[0]).contains("ROAD P1 -> P4"), "a winner on the road who drops to P4 is told so (%s)" % str(notes))
	var scene: Node3D = load("res://scenes/ui/winning_scene.tscn").instantiate()
	scene.setup_celebration(results)
	root.add_child(scene)
	await process_frame
	check(scene.note_label.visible and scene.note_label.text.contains("STOP MISSED") and scene.note_label.text.contains("ROAD P1 -> P4"), "the podium shows the note (%s)" % scene.note_label.text)
	scene.queue_free()
	await process_frame
	var clean: Dictionary = results.duplicate(true)
	clean["notes"] = []
	var other: Node3D = load("res://scenes/ui/winning_scene.tscn").instantiate()
	other.setup_celebration(clean)
	root.add_child(other)
	await process_frame
	check(not other.note_label.visible, "no note without a penalty")
	other.queue_free()
	await process_frame
	race.dispose()
