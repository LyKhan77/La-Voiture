extends SceneTree

## FASE 11 Langkah 3c acceptance: the N2 "faders console" tactical deck. The verdicts come from the sim's own
## formulas (GtForecast), the widgets are plain Controls, and the deck keeps the member API the older tests use.
## Run: Godot --headless --path . -s res://tests/test_deck_n2.gd

const WorldScene := preload("res://scenes/race_weekend_world.tscn")
const DirectorScript := preload("res://scripts/world/weekend/race_weekend_director.gd")
const ActorScript := preload("res://scripts/car/gt_car_actor.gd")
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
	_test_forecast()
	await _test_widgets()
	await _test_deck_layout_and_flow()
	await _test_review_fixes()
	race.dispose()
	world.queue_free()
	await process_frame
	ActorScript._paint_cache.clear()
	print("%d assertions, %d failure(s)" % [assertions, failures])
	print("FASE 11 LANGKAH 3C DECK N2: %s" % ("PASS" if failures == 0 else "%d FAILURES" % failures))
	quit(0 if failures == 0 else 1)


# --- the sim's own numbers ---------------------------------------------------------------------------------

## A car with known numbers: MEDIUM, 28 % worn, 13 laps of fuel, full battery.
func _known(car: GtCar) -> void:
	car.compound = GtTypes.Compound.MEDIUM
	car.tyre_wear_rate = 1.0
	car.wear = 0.28
	car.fuel_use = 3.0
	car.fuel = 39.0
	car.ers_battery = 100.0
	car.pace_mode = GtTypes.PaceMode.STANDARD
	car.fuel_mode = GtTypes.FuelMode.STANDARD
	car.is_dnf = false


func _test_forecast() -> void:
	var car: GtCar = mine[0]
	_known(car)
	check(GtTypes.PACE_WEAR_MULT == [0.45, 0.72, 1.0, 1.45, 2.1] and GtTypes.PACE_FUEL_MULT == [0.85, 0.93, 1.0, 1.12, 1.25]
			and GtTypes.FUEL_MODE_BURN_MULT == [0.8, 1.0, 1.25] and GtTypes.ERS_DRAIN_PER_S[GtTypes.ErsMode.OVERTAKE] == 24.0
			and GtTypes.ERS_DRAIN_PER_S[GtTypes.ErsMode.DEPLOY] == 12.0 and GtTypes.TYRE_CLIFF_WEAR == 0.75,
		"forecast: the multiplier tables carry the numbers gt_driving always used")
	check(is_equal_approx(GtForecast.wear_per_lap(car, GtTypes.PaceMode.ATTACK), 0.032 * 2.1)
			and is_equal_approx(GtForecast.burn_per_lap(car, GtTypes.PaceMode.STANDARD, GtTypes.FuelMode.PUSH), 3.75)
			and is_equal_approx(GtForecast.tyre_life_at_finish(car, GtTypes.PaceMode.STANDARD, 10.0), 0.40)
			and is_equal_approx(GtForecast.fuel_margin_laps(car, GtTypes.PaceMode.STANDARD, GtTypes.FuelMode.STANDARD, 10.0), 3.0)
			and absf(GtForecast.ers_seconds(100.0, GtTypes.ErsMode.OVERTAKE) - 100.0 / 24.0) < 0.001
			and absf(GtForecast.ers_seconds(100.0, GtTypes.ErsMode.DEPLOY) - 100.0 / 12.0) < 0.001
			and GtForecast.ers_seconds(100.0, GtTypes.ErsMode.NEUTRAL) == INF,
		"forecast: wear, burn, fuel margin and battery seconds come from the sim's own formulas")

	var standard: Dictionary = GtForecast.verdict("pace", GtTypes.PaceMode.STANDARD, car, 10.0)
	var attack: Dictionary = GtForecast.verdict("pace", GtTypes.PaceMode.ATTACK, car, 10.0)
	var aggressive: Dictionary = GtForecast.verdict("pace", GtTypes.PaceMode.AGGRESSIVE, car, 10.0)
	car.wear = 0.34
	var worn: Dictionary = GtForecast.verdict("pace", GtTypes.PaceMode.AGGRESSIVE, car, 10.0)
	check(int(standard["severity"]) == 0 and int(attack["severity"]) == 2 and String(attack["text"]).begins_with("Tyres pass the cliff")
			and int(aggressive["severity"]) == 0 and int(worn["severity"]) == 1 and String(worn["text"]).begins_with("Tyres end at ~20%"),
		"forecast: a pace option is judged against the cliff at the finish (%s | %s)" % [attack["text"], worn["text"]])
	_known(car)
	car.fuel = 30.0
	var tight: Dictionary = GtForecast.verdict("fuel", GtTypes.FuelMode.STANDARD, car, 10.0)
	var push: Dictionary = GtForecast.verdict("fuel", GtTypes.FuelMode.PUSH, car, 10.0)
	var lean: Dictionary = GtForecast.verdict("fuel", GtTypes.FuelMode.CONSERVE, car, 10.0)
	check(int(tight["severity"]) == 1 and int(push["severity"]) == 2 and String(push["text"]).begins_with("Short by 2.0 laps") and int(lean["severity"]) == 0,
		"forecast: a fuel mix is judged by the laps of fuel spare at the finish (%s)" % push["text"])
	_known(car)
	var overtake_full: Dictionary = GtForecast.verdict("ers", GtTypes.ErsMode.OVERTAKE, car, 10.0)
	var deploy_full: Dictionary = GtForecast.verdict("ers", GtTypes.ErsMode.DEPLOY, car, 10.0)
	car.ers_battery = 40.0
	var overtake_low: Dictionary = GtForecast.verdict("ers", GtTypes.ErsMode.OVERTAKE, car, 10.0)
	var harvest: Dictionary = GtForecast.verdict("ers", GtTypes.ErsMode.HARVEST, car, 10.0)
	var neutral: Dictionary = GtForecast.verdict("ers", GtTypes.ErsMode.NEUTRAL, car, 10.0)
	check(int(overtake_full["severity"]) == 1 and int(deploy_full["severity"]) == 0 and int(overtake_low["severity"]) == 2
			and int(harvest["severity"]) == 0 and int(neutral["severity"]) == 0,
		"forecast: ERS options are judged by the seconds of deploying the battery lasts, never locked")

	_known(car)
	car.fuel_use = 0.0
	car.is_dnf = true
	var empty: Dictionary = GtForecast.verdict("fuel", GtTypes.FuelMode.STANDARD, car, 0.0)
	var none: Dictionary = GtForecast.verdict("pace", GtTypes.PaceMode.ATTACK, car, 0.0)
	check(String(empty["text"]) != "" and int(empty["severity"]) >= 0 and int(empty["severity"]) <= 2 and String(none["text"]) != "" and GtForecast.laps_left(race, car) >= 0.0,
		"forecast: zero burn, zero laps left and a DNF car still give a valid verdict")
	_known(car)

	check(GtForecast.recommended_compound(50.0, 0.0) == GtTypes.Compound.WET and GtForecast.recommended_compound(10.0, 0.7) == GtTypes.Compound.WET
			and GtForecast.recommended_compound(25.0, 0.1) == GtTypes.Compound.INTERMEDIATE and GtForecast.recommended_compound(5.0, 0.0) == GtTypes.Compound.MEDIUM,
		"forecast: the tyre recommendation uses the strategy desk's own thresholds (45 % wet, 18 % inter)")
	var dry_soft: Dictionary = GtForecast.tyre_verdict(1, 5.0, 0.0, [])
	var slick_rain: Dictionary = GtForecast.tyre_verdict(1, 50.0, 0.8, [])
	var wet_dry: Dictionary = GtForecast.tyre_verdict(5, 5.0, 0.0, [])
	var auto: Dictionary = GtForecast.tyre_verdict(0, 5.0, 0.0, [])
	var coming: Dictionary = GtForecast.tyre_verdict(2, 5.0, 0.0, [{"rain_intensity": 0.0, "water_pct": 5.0}, {"rain_intensity": 0.9, "water_pct": 60.0}])
	check(int(dry_soft["severity"]) == 0 and int(slick_rain["severity"]) == 2 and String(slick_rain["text"]).contains("aquaplane")
			and int(wet_dry["severity"]) == 1 and String(wet_dry["text"]).contains("overheat") and int(auto["severity"]) == 0 and String(auto["text"]).begins_with("Auto will fit")
			and int(coming["severity"]) == 2 and String(coming["text"]).contains("2 laps"),
		"forecast: slicks in rain or before coming rain are DANGER, wets on a dry track WATCH, AUTO names its fit (%s)" % coming["text"])

	var inter_flood: Dictionary = GtForecast.tyre_verdict(4, 60.0, 0.9, [])
	check(int(inter_flood["severity"]) == 1 and String(inter_flood["text"]).contains("over 45%:") and not String(inter_flood["text"]).contains("%%"),
		"forecast: texts print a single percent sign (%s)" % inter_flood["text"])


# --- widgets ----------------------------------------------------------------------------------------------------------

func _total_clicks() -> int:
	var total: int = 0
	for count: Variant in AudioManager.of(root).play_counts.values():
		total += int(count)
	return total


func _test_widgets() -> void:
	var labels: Array[String] = ["CONSERVE", "LIGHT", "STANDARD", "AGGRESSIVE", "ATTACK"]
	var tints: Array[Color] = [Color.CYAN, Color.CYAN, Color.GREEN, Color.YELLOW, Color.RED]
	var ladder := FaderLadder.new(labels, tints)
	root.add_child(ladder)
	var picks: Array[int] = []
	ladder.selected.connect(func(index: int) -> void: picks.append(index))
	ladder.set_active(2)
	ladder.buttons[3].pressed.emit()
	ladder.set_marks([0, 0, 0, 1, 2])
	var shown: Array[int] = ladder.marks()
	check(ladder.buttons.size() == 5 and ladder.get_child(0) == ladder.buttons[4] and ladder.get_child(4) == ladder.buttons[0]
			and picks == [3] and ladder.active == 3 and shown == [0, 0, 0, 1, 2] and ladder.is_mark_visible(4) and not ladder.is_mark_visible(2),
		"widgets: the fader ladder keeps the option order (strongest on top), selects, and marks risky options")
	ladder.queue_free()

	var gauge := ZonedGauge.new()
	root.add_child(gauge)
	gauge.set_state(0.72, 0.25)
	var lit: int = gauge.lit_blocks()
	var hidden_ghost: bool = not gauge.ghost_visible()
	gauge.ghost = 0.24
	check(lit == 9 and hidden_ghost and gauge.ghost_visible() and is_equal_approx(gauge.tick, 0.25),
		"widgets: the gauge lights blocks by value and shows the finish ghost only when set")
	gauge.queue_free()

	var compound_labels: Array[String] = ["A", "S", "M", "H", "I", "W"]
	var compound_words: Array[String] = ["AUTO", "SOFT", "MED", "HARD", "INTER", "WET"]
	var compound_colors: Array[Color] = [Color.WHITE, Color.RED, Color.YELLOW, Color.GRAY, Color.GREEN, Color.BLUE]
	var chips := ChipGrid.new(compound_labels, compound_words, compound_colors)
	root.add_child(chips)
	var chosen: Array[int] = []
	chips.selected.connect(func(index: int) -> void: chosen.append(index))
	chips.set_active(4)
	chips.buttons[5].pressed.emit()
	check(chips.buttons.size() == 6 and chips.buttons[1].text == "S\nSOFT" and chosen == [5] and chips.active == 5,
		"widgets: the tyre chip grid selects a compound")
	chips.queue_free()

	var wheel := TyreWheel.new()
	root.add_child(wheel)
	var calm_spin: float = TyreWheel.spin_velocity(100.0, 0.0)
	var kicked_spin: float = TyreWheel.spin_velocity(100.0, 900.0)
	wheel.set_compound(3, true)
	var kicked: bool = wheel.compound == 3 and wheel.impulse >= 900.0
	var before: float = wheel.angle
	wheel._process(0.5)
	check(calm_spin == 160.0 and kicked_spin == 1060.0 and kicked and wheel.impulse < 900.0 * exp(-1.6) + 0.1 and wheel.angle != before,
		"widgets: the wheel spins with the car, takes a kick on a change and the kick dies away")
	PresentationSettings.reduce_motion = true
	var calm := TyreWheel.new()
	root.add_child(calm)
	calm.hit()
	calm.set_compound(2, true)
	var held: bool = calm.impulse == 0.0 and calm.shake == 0.0
	calm.speed_kmh = 100.0
	var turned: float = calm.angle
	calm._process(0.1)
	check(held and calm.angle != turned, "widgets: under reduce motion the wheel takes no kick or shake but still turns with the car")
	PresentationSettings.reduce_motion = false
	wheel.queue_free()
	calm.queue_free()

	var counted: int = _total_clicks()
	AudioManager.click_pitched(root, 1.2)
	check(_total_clicks() == counted + 1, "audio: click_pitched logs one click")

	var host := Control.new()
	host.size = Vector2(1888.0, 140.0)
	root.add_child(host)
	var tip := DeckTip.new()
	host.add_child(tip)
	var left_target := Control.new()
	left_target.size = Vector2(60.0, 20.0)
	left_target.position = Vector2(10.0, 40.0)
	host.add_child(left_target)
	var right_target := Control.new()
	right_target.size = Vector2(60.0, 20.0)
	right_target.position = Vector2(1860.0, 40.0)
	host.add_child(right_target)
	tip.show_for(left_target, 1, "PACE: ATTACK", "Maximum speed.", "LAP -0.7 s", "Tyres end at ~24%", true)
	var left_ok: bool = tip.position.x >= 0.0 and tip.visible and tip.plain_label.visible and tip.position.y < 0.0
	tip.show_for(right_target, 2, "PACE: ATTACK", "Maximum speed.", "LAP -0.7 s", "Tyres pass the cliff", false)
	check(left_ok and tip.position.x + tip.size.x <= host.size.x + 0.01 and not tip.plain_label.visible and tip.severity_mark.severity == 2,
		"widgets: the tooltip stays inside the deck width, sits above it and drops the plain sentence when COACH is off")
	tip.hide_tip()
	check(not tip.visible, "widgets: the tooltip hides")
	host.queue_free()


# --- the deck itself --------------------------------------------------------------------------------------------------

func _test_deck_layout_and_flow() -> void:
	var deck: TacticalDeck = hud.deck
	var car: GtCar = mine[0]
	var saved_laps: int = race.laps
	race.laps = 30
	race.latest_suggestion = {} # an open engineer card keeps the tooltip off
	_known(car)
	car.pit_request = -1
	deck.deck_car_id = car.id
	deck.pit_compound = -1
	deck.refresh()

	var frame := Rect2(Vector2.ZERO, deck.size)
	var inside: bool = true
	var parts: Array[Control] = [deck.pace_row, deck.fuel_row, deck.ers_row, deck.pace_gauge, deck.fuel_gauge, deck.ers_gauge,
		deck.wheel, deck.tyre_row, deck.box_button, deck.tabs[0], deck.tabs[1], deck.window_label.get_parent() as Control]
	for part: Control in parts:
		inside = inside and frame.encloses(Rect2(part.position, part.size))
	var header_ok: bool = true
	for part: Control in [deck.coach_button, deck.tactic_row, deck.radio_label, deck.collapse_button]:
		header_ok = header_ok and part.position.y + part.size.y <= 36.0
	check(deck.position == Vector2(16.0, 880.0) and deck.size == Vector2(1888.0, 140.0) and inside and header_ok,
		"deck N2: every control sits inside the unchanged 1888x140 box, the header holds COACH, desk, radio and fold")

	deck.pace_row.buttons[GtTypes.PaceMode.ATTACK].pressed.emit()
	deck.fuel_row.buttons[GtTypes.FuelMode.PUSH].pressed.emit()
	deck.ers_row.buttons[GtTypes.ErsMode.OVERTAKE].pressed.emit()
	check(car.pace_mode == GtTypes.PaceMode.ATTACK and deck.pace_row.active == GtTypes.PaceMode.ATTACK
			and car.fuel_mode == GtTypes.FuelMode.PUSH and deck.fuel_row.active == GtTypes.FuelMode.PUSH
			and car.ers_mode == GtTypes.ErsMode.OVERTAKE and deck.ers_row.active == GtTypes.ErsMode.OVERTAKE,
		"deck N2: faders write straight into the sim")

	_known(car)
	car.wear = 0.5
	deck.refresh()
	var active_severity: int = int(deck.verdict_for("pace", car.pace_mode)["severity"])
	check(deck.pace_row.marks()[GtTypes.PaceMode.ATTACK] >= 1 and deck.pace_pill.text == TacticalDeck.SEVERITY_WORD[active_severity]
			and is_equal_approx(deck.pace_gauge.value, 1.0 - car.wear) and deck.pace_gauge.lit_blocks() == 6
			and not deck.pace_row.buttons[GtTypes.PaceMode.ATTACK].disabled,
		"deck N2: option marks, pills and gauges follow the model and nothing is locked")

	deck.pace_row.hovered.emit(GtTypes.PaceMode.ATTACK)
	var hovered_ok: bool = deck.tip.visible and deck.forecast_label.text.contains("ATTACK") and deck.tip.plain_label.visible
	deck.pace_row.unhovered.emit()
	check(hovered_ok and deck.forecast_label.text.begins_with("NEXT LAP") and not deck.tip.visible,
		"deck N2: hovering an option shows its effect and the tooltip, leaving restores the forecast line")

	deck.coach_button.pressed.emit()
	deck.pace_row.hovered.emit(GtTypes.PaceMode.ATTACK)
	var coach_off: bool = not deck.coach and deck.tip.visible and not deck.tip.plain_label.visible and deck.coach_button.text == "COACH OFF"
	deck.coach_button.pressed.emit()
	var coach_on: bool = deck.coach and deck.tip.plain_label.visible
	deck.pace_row.unhovered.emit()
	check(coach_off and coach_on, "deck N2: COACH toggles the plain-language sentence")

	deck.tyre_row.buttons[1 + GtTypes.Compound.INTERMEDIATE].pressed.emit()
	var chip_ok: bool = deck.wheel.compound == 1 + GtTypes.Compound.INTERMEDIATE and deck.pit_compound == GtTypes.Compound.INTERMEDIATE and deck.wheel.impulse > 800.0
	deck.wheel.clicked.emit()
	var next_ok: bool = deck.wheel.compound == 1 + GtTypes.Compound.WET and deck.pit_compound == GtTypes.Compound.WET and deck.tyre_row.active == deck.wheel.compound
	deck.wheel.scrolled.emit(-1)
	check(chip_ok and next_ok and deck.wheel.compound == 1 + GtTypes.Compound.INTERMEDIATE,
		"deck N2: the wheel and the chips pick the next tyre and the wheel is kicked")

	deck.press_box()
	deck.refresh()
	var armed: bool = deck.wheel.armed and car.pit_request >= 0 and deck.box_button.text.begins_with("CANCEL BOX [ESC]  //  ")
	deck.cancel_box()
	deck.refresh()
	var released: bool = not deck.wheel.armed and car.pit_request == -1
	deck._box_clicked_at = -100000
	deck.on_box_pressed()
	deck.on_box_pressed()
	deck.refresh()
	var single: bool = car.pit_request >= 0 and deck.wheel.armed
	deck.cancel_box()
	deck.refresh()
	check(armed and released and single, "deck N2: BOX arms the wheel, cancel releases it, a double click does not call then cancel")

	deck.tabs[1].pressed.emit()
	var other_ok: bool = deck.deck_car_id == mine[1].id and is_equal_approx(deck.pace_gauge.value, 1.0 - mine[1].wear) and deck.tabs[1].text.contains(mine[1].code)
	deck.tabs[0].pressed.emit()
	check(other_ok and deck.deck_car_id == mine[0].id, "deck N2: switching car swaps verdicts, gauges and the active card")

	var clicks: int = _total_clicks()
	var started: int = deck.feedback_tweens
	deck.pace_row.buttons[GtTypes.PaceMode.LIGHT].pressed.emit()
	var animated: bool = deck.feedback_tweens > started and _total_clicks() == clicks + 1
	PresentationSettings.reduce_motion = true
	started = deck.feedback_tweens
	deck.apply_click_feedback(deck.box_button, "BOX", 1.0)
	var calm: bool = deck.feedback_tweens == started and _total_clicks() == clicks + 2
	PresentationSettings.reduce_motion = false
	check(animated and calm, "deck N2: every control gives audible and visible click feedback (no animation under reduce motion)")

	var weather: GtWeather = race.weather
	var saved_forecast: Array[Dictionary] = weather.forecast.duplicate()
	var saved_water: float = weather.track_water_pct
	var saved_rain: float = weather.rain_intensity
	weather.track_water_pct = 0.0
	weather.rain_intensity = 0.0
	var lead: int = GtWeatherOutlook.leader_lap(race, world.track.length)
	var coming: Array[Dictionary] = []
	for index: int in range(5):
		coming.append({"lap": lead + 1 + index, "rain_intensity": 0.0 if index < 3 else 0.9, "water_pct": 5.0 if index < 3 else 60.0})
	weather.forecast = coming
	deck.refresh()
	var rain_text: String = deck.window_label.text
	var dry: Array[Dictionary] = []
	for index: int in range(5):
		dry.append({"lap": lead + 1 + index, "rain_intensity": 0.0, "water_pct": 5.0})
	weather.forecast = dry
	deck.refresh()
	check(rain_text.contains("BOX WINDOW") and rain_text.contains("WET") and deck.window_label.text.contains("NO TYRE CHANGE"),
		"deck N2: the window card reads the weather forecast (%s)" % rain_text)
	weather.forecast = saved_forecast
	weather.track_water_pct = saved_water
	weather.rain_intensity = saved_rain
	race.laps = saved_laps
	_known(car)
	deck.refresh()


# --- final review fixes -------------------------------------------------------------------------------------------------

func _test_review_fixes() -> void:
	var deck: TacticalDeck = hud.deck
	var car: GtCar = mine[0]
	var saved_laps: int = race.laps
	race.laps = 30
	_known(car)
	car.pit_request = -1
	deck.deck_car_id = car.id
	deck.pit_compound = -1
	deck.refresh()

	deck.wheel.mouse_entered.emit()
	deck.wheel.clicked.emit()
	var wheel_tip: String = deck.tip.title_label.text
	deck.wheel.mouse_exited.emit()
	check(wheel_tip == "TYRES: SOFT", "review: the wheel tooltip follows the tyre the click picked (%s)" % wheel_tip)
	deck.tyre_row.buttons[0].pressed.emit()

	deck.pace_row.hovered.emit(GtTypes.PaceMode.ATTACK)
	var before_click: String = deck.tip.numbers_label.text
	deck.pace_row.buttons[GtTypes.PaceMode.ATTACK].pressed.emit()
	var after_click: String = deck.tip.numbers_label.text
	deck.pace_row.unhovered.emit()
	check(before_click.contains("SPEED +4.8%") and after_click.contains("SPEED +0.0%") and deck.tip.visible == false,
		"review: the tooltip and forecast line are recomputed after a fader click (%s -> %s)" % [before_click, after_click])
	_known(car)
	deck.refresh()

	car.wear = 0.8
	var past: String = String(GtForecast.verdict("pace", GtTypes.PaceMode.ATTACK, car, 10.0)["text"])
	var calm: String = String(GtForecast.verdict("pace", GtTypes.PaceMode.CONSERVE, car, 10.0)["text"])
	_known(car)
	car.wear = 0.5
	var later: String = String(GtForecast.verdict("pace", GtTypes.PaceMode.ATTACK, car, 30.0)["text"])
	_known(car)
	car.ers_battery = 10.0
	var empty: Dictionary = GtForecast.verdict("ers", GtTypes.ErsMode.OVERTAKE, car, 10.0)
	_known(car)
	check(past.begins_with("Tyres are already past the cliff") and calm.begins_with("Tyres are already past the cliff") and not later.contains("1 laps")
			and int(empty["severity"]) == 2 and String(empty["text"]).contains("nearly empty"),
		"review: verdict texts say when the tyres are past the cliff and the battery is nearly empty (%s | %s)" % [past, empty["text"]])

	race.latest_suggestion = {"deadline": race.time + 5.0}
	deck.fuel_row.hovered.emit(GtTypes.FuelMode.PUSH)
	var hidden: bool = not deck.tip.visible and deck.forecast_label.text.begins_with("FUEL: PUSH")
	deck.fuel_row.unhovered.emit()
	race.latest_suggestion = {}
	deck.fuel_row.hovered.emit(GtTypes.FuelMode.PUSH)
	var shown: bool = deck.tip.visible
	deck.fuel_row.unhovered.emit()
	check(hidden and shown, "review: the tooltip stays off while an engineer card is open, the forecast line still carries the impact")

	car.compound = GtTypes.Compound.HARD
	var fit: int = GtForecast.auto_compound(car, 5.0)
	deck.refresh()
	var hint_ok: bool = fit == GtTypes.Compound.SOFT and deck.wheel.auto_hint == fit and GtForecast.auto_compound(car, 30.0) == GtTypes.Compound.INTERMEDIATE
	var called: bool = deck.press_box()
	var asked: int = car.pit_request
	deck.cancel_box()
	check(hint_ok and called and asked == fit, "review: the AUTO wheel colour is the tyre the world fits for this car (%d)" % asked)
	_known(car)

	deck.pit_compound = GtTypes.Compound.WET
	deck.tabs[1].pressed.emit()
	var reset: bool = deck.pit_compound == -1 and deck.tyre_row.active == 0
	deck.tabs[0].pressed.emit()
	check(reset, "review: switching car drops the tyre picked for the other car")
	race.laps = saved_laps
	deck.refresh()
