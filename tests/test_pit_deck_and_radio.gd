extends SceneTree

## FASE 11 Langkah 3a acceptance: the pit wall mechanics of the redesigned HUD (MANUAL / AUTO desk,
## the 10 s suggestion window, cancelling a box call, the two-state BOX button, the burn bar and the
## B / ESC / ENTER keys). Radio two-way flow is added in Langkah 3e.
## Run: Godot --headless --path . -s res://tests/test_pit_deck_and_radio.gd

const WorldScene := preload("res://scenes/race_weekend_world.tscn")
const DirectorScript := preload("res://scripts/world/weekend/race_weekend_director.gd")
const ActorScript := preload("res://scripts/car/gt_car_actor.gd")
const PitLaneScript := preload("res://scripts/world/circuits/apex_ring/apex_pit_complex.gd")
const T := preload("res://scripts/ui/ui_theme_tokens.gd")
const FRAME: float = 1.0 / 60.0

var failures: int = 0
var assertions: int = 0
var world: Node3D
var hud: RaceHud
var race: GtRace
var mine: Array[GtCar] = []


func _initialize() -> void:
	call_deferred("_run")


func check(ok: bool, description: String) -> void:
	assertions += 1
	if not ok:
		failures += 1
		push_error(description)
	print("[%s] %s" % ["PASS" if ok else "FAIL", description])


func _run() -> void:
	world = WorldScene.instantiate()
	root.add_child(world)
	world.set_process(false)
	hud = world.hud
	race = world.race
	race.incidents_enabled = false
	for car: GtCar in race.cars:
		if car.team_id == race.player_team_id:
			mine.append(car)
	world.director._enter(DirectorScript.State.GREEN_RACING)
	for _i: int in range(40):
		world.step(FRAME)
	race.step_ticks(200)
	hud.refresh_all()
	_test_desk_modes_and_suggestion_window()
	_test_cancel_pit()
	_test_cancel_closes_the_box_card()
	_test_deck_box_and_desk()
	_test_burn_bar_and_keys()
	_test_two_way_radio()
	race.dispose()
	world.queue_free()
	await process_frame
	ActorScript._paint_cache.clear()
	print("%d assertions, %d failure(s)" % [assertions, failures])
	print("FASE 11 LANGKAH 3A PIT MECHANICS: %s" % ("PASS" if failures == 0 else "%d FAILURES" % failures))
	quit(0 if failures == 0 else 1)


## Clean slate for one pit wall scenario: no card, no cooldowns, quiet cars (an empty battery and cool
## tyres keep the advisor from raising an ERS or pace card that would replace the one under test).
func _reset(mode: int) -> GtCar:
	race.latest_suggestion = {}
	race.suggestion_changed.emit({})
	race._suggestion_cooldowns.clear()
	race.set_tactic_mode(mode)
	for car: GtCar in mine:
		car.pit_request = -1
		car.ers_battery = 0.0
		car.tyre_temp = 90.0
	return mine[0]


func _suggest_box(car: GtCar) -> void:
	race.suggest_tactic(car, GtTypes.TacticType.PIT, GtTypes.Compound.HARD, "BOX FOR HARD", "Suggest box this lap.")


# --- desk modes and the 10 s suggestion window ------------------------------------------------------------

func _test_desk_modes_and_suggestion_window() -> void:
	check(GtTypes.TacticMode.size() == 2 and race.tactic_mode == GtTypes.TacticMode.MANUAL,
		"desk: only MANUAL and AUTO exist and MANUAL is the default")

	var car: GtCar = _reset(GtTypes.TacticMode.MANUAL)
	_suggest_box(car)
	var full: bool = is_equal_approx(race.suggestion_remaining(), GtRace.SUGGESTION_WINDOW_S)
	race.time += 5.0
	var half: bool = absf(race.suggestion_remaining() - 5.0) < 0.001
	race.time += 5.1
	race.step()
	check(full and half and race.latest_suggestion.is_empty() and car.pit_request < 0,
		"suggestion: in MANUAL the card closes at 0.0 s and nothing is executed")

	car = _reset(GtTypes.TacticMode.AUTO)
	_suggest_box(car)
	race.time += GtRace.SUGGESTION_WINDOW_S + 0.1
	race.step()
	check(car.pit_request == GtTypes.Compound.HARD and race.latest_suggestion.is_empty(),
		"suggestion: in AUTO the card locks and executes at 0.0 s")

	car = _reset(GtTypes.TacticMode.AUTO)
	car.pit_request = GtTypes.Compound.SOFT
	_suggest_box(car)
	race.time += GtRace.SUGGESTION_WINDOW_S + 0.1
	race.step()
	check(car.pit_request == GtTypes.Compound.SOFT and race.latest_suggestion.is_empty(),
		"suggestion: AUTO never double-calls a car that is already boxing")

	car = _reset(GtTypes.TacticMode.MANUAL)
	_suggest_box(car)
	race.time += 6.0
	race.suggest_tactic(car, GtTypes.TacticType.PACE, GtTypes.PaceMode.CONSERVE, "PACE: CONSERVE", "Save the tyres.")
	check(race.suggestion_remaining() > GtRace.SUGGESTION_WINDOW_S - 0.1,
		"suggestion: a replacement card restarts the 10 s window")

	car = _reset(GtTypes.TacticMode.AUTO)
	_suggest_box(car)
	race.time += 9.9
	var radio_before: int = race.radio_history.size()
	race.accept_suggestion()
	race.time += 0.3
	race.step()
	var box_calls: int = 0
	for index: int in range(radio_before, race.radio_history.size()):
		if String(race.radio_history[index]["text"]).begins_with("Box this lap"):
			box_calls += 1
	check(car.pit_request == GtTypes.Compound.HARD and race.latest_suggestion.is_empty() and box_calls == 1,
		"suggestion: accepting at 9.9 s calls the stop once, the window end does not call it again (box calls: %d)" % box_calls)


# --- cancelling a box call --------------------------------------------------------------------------------

func _test_cancel_pit() -> void:
	if not world.has_method("cancel_pit"):
		check(false, "pit: the world exposes cancel_pit(car_id)")
		return
	var car: GtCar = _reset(GtTypes.TacticMode.MANUAL)
	car.pit = null
	var called: bool = world.request_pit(car.id, GtTypes.Compound.WET) and car.pit_request == GtTypes.Compound.WET
	var cancelled_at: float = race.time
	var cancelled: bool = world.cancel_pit(car.id)
	var radio: Dictionary = race.latest_radio
	check(called and cancelled and car.pit_request == -1 and String(radio["text"]) == "Stay out, stay out! Box call cancelled." and String(radio["speaker"]) == "engineer",
		"pit: cancelling a box call clears the request and the engineer confirms it")
	var cooldown: float = float(race._suggestion_cooldowns["%d-%d" % [car.id, GtTypes.TacticType.PIT]])
	check(cooldown >= cancelled_at + 30.0 - 0.001,
		"pit: cancelling blocks an instant repeat BOX suggestion (cooldown until +%.0f s)" % (cooldown - cancelled_at))

	car.s = PitLaneScript.ENTRY_S - 290.0
	car.prev_s = car.s
	car.v = 45.0
	car.lap = maxi(car.lap, 1)
	world.request_pit(car.id, GtTypes.Compound.WET)
	race.step_ticks(20)
	var held: bool = car.v <= 38.5
	world.cancel_pit(car.id)
	var peak: float = 0.0
	for _step: int in range(8):
		race.step_ticks(10)
		peak = maxf(peak, car.v)
	# The 90 degree bend before the Apex pit entry (s 3790..3920) caps the speed near 41 m/s, so leaving the 38 m/s cap is the signal.
	check(held and peak > 40.0 and car.pit == null and car.pit_request == -1,
		"pit: after cancelling, the car leaves the 38 m/s pit approach pace (peak %.1f m/s) and drives past the pit entry with no penalty" % peak)

	var radio_count: int = race.radio_history.size()
	check(not world.cancel_pit(car.id) and race.radio_history.size() == radio_count,
		"pit: cancelling with no call is a no-op")

	car.pit_request = GtTypes.Compound.WET
	var committed := GtPit.new()
	committed.phase = GtTypes.PitPhase.ENTRY
	car.pit = committed
	check(not world.cancel_pit(car.id) and car.pit == committed and car.pit_request == GtTypes.Compound.WET,
		"pit: a car already committed to the pit lane cannot cancel")
	car.pit = null
	car.pit_request = -1


# --- deck: two-state BOX button and the MANUAL / AUTO desk --------------------------------------------------------

func _test_deck_box_and_desk() -> void:
	var deck: TacticalDeck = hud.deck
	var car: GtCar = _reset(GtTypes.TacticMode.MANUAL)
	car.pit = null
	car.is_dnf = false
	deck.deck_car_id = car.id
	deck.pit_compound = -1
	deck.tyre_row.set_active(0)
	deck.refresh()
	check(deck.tactic_row.buttons.size() == 2 and deck.tactic_row.buttons[0].text == "MANUAL" and deck.tactic_row.buttons[1].text == "AUTO",
		"deck: the desk row has MANUAL and AUTO only")
	check(deck.box_button.text == "REQUEST BOX [B]" and not deck.box_button.disabled,
		"deck: with no call the button reads REQUEST BOX [B] and is enabled")

	deck.tyre_row.buttons[1 + GtTypes.Compound.WET].pressed.emit()
	deck.box_button.pressed.emit()
	deck.refresh()
	check(car.pit_request == GtTypes.Compound.WET and deck.box_button.text == "CANCEL BOX [ESC]  //  WET" and not deck.box_button.disabled,
		"deck: after a box call the button becomes CANCEL BOX [ESC] // WET and stays enabled")
	deck._box_clicked_at = -100000 # the button ignores a second click inside 0.25 s
	deck.box_button.pressed.emit()
	deck.refresh()
	check(car.pit_request == -1 and deck.box_button.text == "REQUEST BOX [B]",
		"deck: clicking CANCEL BOX withdraws the call and the button reads REQUEST BOX again")

	var committed := GtPit.new()
	committed.phase = GtTypes.PitPhase.ENTRY
	car.pit = committed
	deck.refresh()
	var in_pit: bool = deck.box_button.text == "IN THE PIT LANE" and deck.box_button.disabled
	car.pit = null
	car.is_dnf = true
	deck.refresh()
	var retired: bool = deck.box_button.text == "RETIRED" and deck.box_button.disabled
	car.is_dnf = false
	car.finished_at = 100.0
	deck.refresh()
	var chequered: bool = deck.box_button.text == "CHEQUERED" and deck.box_button.disabled
	car.finished_at = -1.0
	deck.refresh()
	check(in_pit and retired and chequered and not deck.box_button.disabled,
		"deck: the button locks as IN THE PIT LANE, RETIRED or CHEQUERED and unlocks again afterwards")

	var status: Variant = deck.get("desk_status")
	if status == null:
		check(false, "deck: the desk status label exists")
		return
	deck.tactic_row.buttons[GtTypes.TacticMode.AUTO].pressed.emit()
	deck.refresh()
	var auto_ok: bool = race.tactic_mode == GtTypes.TacticMode.AUTO and (status as Label).text == "MODE: AUTO // AI ENGINEER ASSISTED"
	deck.tactic_row.buttons[GtTypes.TacticMode.MANUAL].pressed.emit()
	deck.refresh()
	check(auto_ok and race.tactic_mode == GtTypes.TacticMode.MANUAL and (status as Label).text == "MODE: MANUAL // 100% PLAYER DIRECTIVE",
		"deck: the desk status tag follows MANUAL and AUTO")


# --- burn bar and keys ---------------------------------------------------------------------------------------------

func _test_burn_bar_and_keys() -> void:
	check(RaceHud.burn_text(10.0) == "10.0s" and RaceHud.burn_text(3.24) == "03.2s" and RaceHud.burn_text(-1.0) == "00.0s" and RaceHud.burn_color(1.0) == T.ACCENT_CYBER_YELLOW and RaceHud.burn_color(0.5) == Color("#FF6D00") and RaceHud.burn_color(0.1) == T.ACCENT_ANIME_CRIMSON,
		"burn bar: label format and flame colour stages")
	var deck: TacticalDeck = hud.deck
	var car: GtCar = _reset(GtTypes.TacticMode.MANUAL)
	deck.deck_car_id = car.id
	_suggest_box(car)
	var full: float = hud.card.size.x - 8.0
	check(hud.card.visible and is_equal_approx(hud.burn_fill.size.x, full) and hud.card_timer.text == "10.0s" and not hud.card_critical,
		"burn bar: a new card starts with a full bar and 10.0s")
	race.time += 5.0
	hud.refresh_all()
	check(absf(hud.burn_fill.size.x / full - 0.5) < 0.01 and hud.card_timer.text == "05.0s" and not hud.card_critical,
		"burn bar: the fill and the label follow the 10 s window")
	race.time += 3.0
	hud.refresh_all()
	check(hud.card_critical and hud.card_timer.text == "02.0s",
		"burn bar: under 3 s the card enters its critical state")
	race.suggest_tactic(car, GtTypes.TacticType.PACE, GtTypes.PaceMode.CONSERVE, "PACE: CONSERVE", "Save the tyres.")
	check(hud.card_timer.text == "10.0s" and not hud.card_critical and is_equal_approx(hud.burn_fill.size.x, full),
		"burn bar: a replacement card restarts at 10.0s")

	car = _reset(GtTypes.TacticMode.MANUAL)
	deck.deck_car_id = car.id
	var idle_enter: bool = hud.handle_key(KEY_ENTER)
	_suggest_box(car)
	var enter_consumed: bool = hud.handle_key(KEY_ENTER)
	check(not idle_enter and enter_consumed and not hud.card.visible and car.pit_request == GtTypes.Compound.HARD,
		"keys: ENTER accepts the open card, and is left alone when there is no card")

	car = _reset(GtTypes.TacticMode.MANUAL)
	deck.deck_car_id = car.id
	_suggest_box(car)
	race.request_pit(car.id, GtTypes.Compound.HARD)
	var esc_card: bool = hud.handle_key(KEY_ESCAPE)
	var card_closed: bool = not hud.card.visible and car.pit_request >= 0
	var esc_box: bool = hud.handle_key(KEY_ESCAPE)
	var box_cancelled: bool = car.pit_request == -1
	var esc_idle: bool = hud.handle_key(KEY_ESCAPE)
	check(esc_card and card_closed and esc_box and box_cancelled and not esc_idle,
		"keys: ESC dismisses the card first, then cancels the box call, then is not consumed")

	car = _reset(GtTypes.TacticMode.MANUAL)
	deck.deck_car_id = car.id
	deck.pit_compound = -1
	var b_first: bool = hud.handle_key(KEY_B)
	var chosen: int = car.pit_request
	var b_again: bool = hud.handle_key(KEY_B)
	check(b_first and chosen >= 0 and b_again and car.pit_request == chosen,
		"keys: B requests the box once; pressing it again keeps the same call")
	car.pit_request = -1


# --- final review fix: an explicit cancel beats a still-open BOX card -----------------------------------------------

func _test_cancel_closes_the_box_card() -> void:
	var car: GtCar = _reset(GtTypes.TacticMode.AUTO)
	car.pit = null
	_suggest_box(car)
	race.time += 2.0
	world.request_pit(car.id, GtTypes.Compound.WET)
	race.time += 2.0
	var cancelled: bool = world.cancel_pit(car.id)
	var card_closed: bool = race.latest_suggestion.is_empty()
	race.time += GtRace.SUGGESTION_WINDOW_S
	race.step()
	check(cancelled and card_closed and car.pit_request == -1,
		"pit: in AUTO an explicit cancel closes the open BOX card, so the window end cannot re-box the car")


# --- Langkah 3e: the engineer answers the driver ----------------------------------------------------------

func _ticks_for(seconds: float) -> int:
	return ceili(seconds / GtTypes.TICK_DT)


## Replies to one driver message, in the order they were pushed.
func _replies_to(log: Array[Dictionary], ids: Array[int]) -> Array[Dictionary]:
	var found: Array[Dictionary] = []
	for message: Dictionary in log:
		if ids.has(int(message.get("reply_to", -1))) and String(message["speaker"]) == "engineer":
			found.append(message)
	return found


func _test_two_way_radio() -> void:
	var log: Array[Dictionary] = []
	var collect: Callable = func(message: Dictionary) -> void: log.append(message)
	race.radio_message.connect(collect)
	var car: GtCar = _reset(GtTypes.TacticMode.MANUAL)
	car.compound = GtTypes.Compound.MEDIUM
	car.wear = 0.62
	race.driver_radio_cooldown.clear()
	race._pending_replies.clear()
	race._flood_called.clear()
	race.weather.track_water_pct = 0.0

	race.push_radio(car, "driver", "Had a snap of oversteer! Lost some time.")
	var snap_id: int = int(race.latest_radio["id"])
	race.step_ticks(_ticks_for(2.4))
	var early: int = _replies_to(log, [snap_id]).size()
	race.step_ticks(_ticks_for(0.3))
	var replies: Array[Dictionary] = _replies_to(log, [snap_id])
	var reply_text: String = String(replies[0]["text"]) if replies.size() == 1 else ""
	var snap_time: float = 0.0
	for message: Dictionary in log:
		if int(message["id"]) == snap_id:
			snap_time = float(message["time"])
	check(early == 0 and replies.size() == 1 and reply_text.begins_with("Copy ") and reply_text.contains("%") and not bool(replies[0]["urgent"])
			and absf(float(replies[0]["time"]) - snap_time - GtRace.RADIO_REPLY_DELAY_S) <= GtTypes.TICK_DT * 1.01,
		"radio: a driver call gets one engineer reply exactly 2.5 s of sim time later (%s)" % reply_text)

	var rival: GtCar = null
	for candidate: GtCar in race.cars:
		if candidate.team_id != race.player_team_id:
			rival = candidate
			break
	race.push_radio(rival, "driver", "Had a snap of oversteer! Lost some time.", false, true)
	var rival_id: int = int(race.latest_radio["id"])
	race.step_ticks(_ticks_for(3.0))
	check(_replies_to(log, [rival_id]).is_empty(), "radio: a rival driver call gets no engineer reply")

	race.driver_radio_cooldown.clear()
	race.push_radio(car, "driver", "Had a snap of oversteer! Lost some time.")
	var first_id: int = int(race.latest_radio["id"])
	race.step_ticks(_ticks_for(1.0))
	race.push_radio(car, "driver", "Tyres are cooked! Rear is sliding everywhere!", true)
	var second_id: int = int(race.latest_radio["id"])
	race.step_ticks(_ticks_for(3.0))
	var pair: Array[Dictionary] = _replies_to(log, [first_id, second_id])
	check(pair.size() == 2 and int(pair[0]["reply_to"]) == first_id and int(pair[1]["reply_to"]) == second_id
			and absf(float(pair[1]["time"]) - float(pair[0]["time"]) - 1.0) < 0.1,
		"radio: two driver calls in a row keep both replies in order")

	race.push_radio(car, "driver", "Had a snap of oversteer! Lost some time.", true)
	var retired_id: int = int(race.latest_radio["id"])
	car.is_dnf = true
	race.step_ticks(_ticks_for(2.6))
	car.is_dnf = false
	var late: Array[Dictionary] = _replies_to(log, [retired_id])
	var late_text: String = String(late[0]["text"]) if late.size() == 1 else ""
	check(late.size() == 1 and late_text != "" and not late_text.contains("%s") and not late_text.contains("%d") and not late_text.contains("%%"),
		"radio: a reply for a car that retired meanwhile is still valid (%s)" % late_text)

	race.driver_radio_cooldown.clear()
	race.weather.track_water_pct = 60.0
	var before: int = log.size()
	race.step_ticks(1)
	var floods: Array[Dictionary] = []
	for message: Dictionary in log.slice(before):
		if int(message["car_id"]) == car.id and String(message["text"]).begins_with("Track is flooding"):
			floods.append(message)
	race.weather.track_water_pct = 60.0
	race.step_ticks(100)
	var again: int = 0
	for message: Dictionary in log.slice(before):
		if int(message["car_id"]) == car.id and String(message["text"]).begins_with("Track is flooding"):
			again += 1
	race.weather.track_water_pct = 60.0
	race.step_ticks(_ticks_for(2.6))
	var flood_replies: Array[Dictionary] = _replies_to(log, [int(floods[0]["id"])]) if floods.size() == 1 else []
	var flood_text: String = String(flood_replies[0]["text"]) if flood_replies.size() == 1 else ""
	race.weather.track_water_pct = 5.0
	race.step_ticks(2)
	race.driver_radio_cooldown.clear()
	race.weather.track_water_pct = 60.0
	var mark: int = log.size()
	race.step_ticks(1)
	var second_flood: int = 0
	for message: Dictionary in log.slice(mark):
		if int(message["car_id"]) == car.id and String(message["text"]).begins_with("Track is flooding"):
			second_flood += 1
	check(floods.size() == 1 and again == 1 and flood_text.contains("WETS") and flood_text.contains("water at ") and second_flood == 1,
		"radio: flooding is called once per episode and answered (%s)" % flood_text)

	# Review: two cars of the team on slicks make one flood call, not two in the same tick.
	race._flood_called.clear()
	race._pending_replies.clear()
	race.driver_radio_cooldown.clear()
	for teammate: GtCar in mine:
		teammate.compound = GtTypes.Compound.MEDIUM
		teammate.is_dnf = false
	race.weather.track_water_pct = 60.0
	var pair_mark: int = log.size()
	race.step_ticks(1)
	race.weather.track_water_pct = 60.0
	race.step_ticks(50)
	var pair_calls: int = 0
	for message: Dictionary in log.slice(pair_mark):
		if String(message["text"]).begins_with("Track is flooding"):
			pair_calls += 1
	check(pair_calls == 1, "radio: two cars on slicks make one flood call per episode (%d)" % pair_calls)

	car.compound = GtTypes.Compound.WET
	race._flood_called.clear()
	race.driver_radio_cooldown.clear()
	race.weather.track_water_pct = 60.0
	var wet_mark: int = log.size()
	race.step_ticks(1)
	var wet_calls: int = 0
	for message: Dictionary in log.slice(wet_mark):
		if int(message["car_id"]) == car.id and String(message["text"]).begins_with("Track is flooding"):
			wet_calls += 1
	check(wet_calls == 0, "radio: a car already on wets does not call the flood")

	var sample: GtCar = mine[0]
	check(GtRadioReplies.reply_for("Tyres are cooked! Rear is sliding everywhere!", sample, 5.0).begins_with("Copy ") and GtRadioReplies.reply_for("Puncture! The tyre has delaminated!", sample, 5.0).begins_with("Copy ")
			and GtRadioReplies.reply_for("Passing someone! Excellent drive.", sample, 5.0) == "",
		"radio: every answered call has a reply and an unrelated call has none")

	race.radio_message.disconnect(collect)
	car.compound = GtTypes.Compound.MEDIUM
	race.weather.track_water_pct = 0.0
