extends SceneTree

## FASE 5.8 acceptance: the fused La Voiture race HUD (tactical deck + telemetry drawer
## in the pit wall language) reads the GT sim and writes only through its tactic calls.
## Run: Godot --headless --path . -s res://tests/test_race_hud.gd

const WorldScene := preload("res://scenes/race_weekend_world.tscn")
const DirectorScript := preload("res://scripts/world/race_weekend_director.gd")
const ActorScript := preload("res://scripts/car/gt_car_actor.gd")
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
	world.set_physics_process(false)
	hud = world.hud
	race = world.race
	race.incidents_enabled = false
	for car: GtCar in race.cars:
		if car.team_id == race.player_team_id:
			mine.append(car)
	_test_ribbon_before_start()
	world.director._enter(DirectorScript.State.GREEN_RACING)
	for _i: int in range(40):
		world.step(FRAME)
	race.step_ticks(200)
	hud.refresh_all()
	_test_strip_layout()
	_test_step_bar()
	_test_tower()
	_test_single_tower_highlight()
	_test_deck_writes_to_sim()
	_test_deck_fold_and_keys()
	_test_drawer()
	_test_suggestion_card()
	_test_radio_and_flags()
	_test_weather_and_rate()
	race.dispose()
	world.queue_free()
	await process_frame
	ActorScript._paint_cache.clear()
	print("%d assertions, %d failure(s)" % [assertions, failures])
	print("FASE 5.8 FUSED HUD: %s" % ("PASS" if failures == 0 else "%d FAILURES" % failures))
	quit(0 if failures == 0 else 1)


# --- ribbon --------------------------------------------------------------------------------

func _test_ribbon_before_start() -> void:
	hud.refresh_all()
	var scale_x: float = hud.stage.scale.x
	check(hud.lap_label.text == "LAP 01/%d" % race.laps and hud.flag_label.text.begins_with("GRID") and scale_x > 0.0 and is_equal_approx(scale_x, hud.stage.scale.y),
		"ribbon: before the start it reads LAP 01/%d and GRID, on a stage scaled evenly (%.2f)" % [race.laps, scale_x])


## Layout A: the deck is one strip under everything, so no bottom corner is left empty.
func _test_strip_layout() -> void:
	var deck_rect := Rect2(hud.deck.position, hud.deck.size)
	var tower_rect := Rect2(hud.tower.position, hud.tower.size)
	var drawer_rect := Rect2(hud.drawer.position, hud.drawer.size)
	var stage_rect := Rect2(Vector2.ZERO, RaceHud.STAGE)
	var clear: bool = not deck_rect.intersects(tower_rect) and not deck_rect.intersects(drawer_rect) and not tower_rect.intersects(drawer_rect)
	var spans: bool = is_equal_approx(deck_rect.position.x, tower_rect.position.x) and is_equal_approx(deck_rect.end.x, 1904.0)
	var corners: bool = deck_rect.position.x <= tower_rect.position.x + 1.0 and deck_rect.end.x >= 1900.0 and deck_rect.position.y >= tower_rect.end.y and deck_rect.position.y >= drawer_rect.end.y
	var inside: bool = stage_rect.encloses(deck_rect) and stage_rect.encloses(tower_rect) and stage_rect.encloses(drawer_rect) and deck_rect.end.y <= 1032.0
	check(clear and spans and corners and inside,
		"layout: the tactical deck is one full-width strip (%s) under the tower (%s) and the telemetry drawer (%s), with no overlap and no empty bottom corner" % [deck_rect, tower_rect, drawer_rect])


# --- bars ------------------------------------------------------------------------------------

func _test_step_bar() -> void:
	var bar := StepBar.new(10)
	bar.set_value(0.8)
	var healthy: Color = bar.tint_for(0.8)
	var middling: Color = bar.tint_for(0.45)
	var critical: Color = bar.tint_for(0.1)
	bar.set_value(0.55)
	var lit: int = bar.lit_blocks()
	bar.invert_scale = true
	var hot: Color = bar.tint_for(0.9)
	bar.free()
	check(healthy == T.ACCENT_ACID_LIME and middling == T.ACCENT_CYBER_YELLOW and critical == T.ACCENT_ANIME_CRIMSON and lit == 6 and hot == T.ACCENT_ANIME_CRIMSON,
		"bars: stepped blocks go lime, yellow, crimson as the value drops (0.55 lights %d of 10), and an inverted bar turns crimson when high" % lit)


# --- timing tower ---------------------------------------------------------------------------------

func _row_of(car_id: int) -> Control:
	for row: Control in hud.tower.rows:
		if row.car_id == car_id:
			return row
	return null


func _test_tower() -> void:
	var visible_rows: int = 0
	for row: Control in hud.tower.rows:
		if row.visible:
			visible_rows += 1
	var leader: GtCar = race.standings()[0]
	var leader_row: Control = _row_of(leader.id)
	var int_text: String = hud.tower.rows[2]._interval.text
	hud.handle_key(KEY_TAB)
	var gap_text: String = hud.tower.rows[2]._interval.text
	var gap_header: String = hud._tower_column.text
	hud.handle_key(KEY_TAB)
	hud.handle_key(KEY_TAB)
	check(visible_rows == 20 and leader_row != null and leader_row._driver.text.contains(leader.code) and leader_row._compound.text == GtTypes.COMPOUND_LABEL[leader.compound],
		"tower: 20 rows in race order, each with number, code and the S/M/H/I/W tyre letter (leader %s)" % leader_row._driver.text)
	check(int_text.begins_with("+") and gap_text.begins_with("+") and gap_text.to_float() > int_text.to_float() and gap_header == "GAP" and hud._tower_column.text == "INT",
		"tower: Tab cycles the column INT -> GAP -> LAST -> INT (%s, %s)" % [int_text, gap_text])
	var retired: GtCar = race.cars[7]
	retired.is_dnf = true
	hud.refresh_all()
	var retired_text: String = _row_of(retired.id)._interval.text
	retired.is_dnf = false
	hud.refresh_all()
	check(retired_text == "DNF", "tower: a retired car shows DNF")
	var picked: int = race.cars[5].id
	hud.tower.rows[3].driver_selected.emit(picked)
	check(world.followed_id == picked, "tower: clicking a row makes that car the followed car")
	world.followed_id = mine[0].id


## Clicking a row focuses it; picking another car by key or deck tab must not leave that row lit.
func _test_single_tower_highlight() -> void:
	var clicked: GtCar = race.cars[9]
	var row: Control = _row_of(clicked.id)
	row._activate()
	hud.refresh_all()
	var after_click: int = world.followed_id
	hud.handle_key(KEY_N)
	hud.refresh_all()
	var lit: Array[int] = []
	for other: Control in hud.tower.rows:
		if other.visible and other._lit:
			lit.append(other.car_id)
	check(after_click == clicked.id and world.followed_id == mine[0].id and lit == [mine[0].id],
		"tower: clicking a row then pressing N moves the highlight to the new car, exactly one row stays lit (lit rows: %s)" % [lit])
	world.followed_id = mine[0].id


# --- deck writes to the sim -------------------------------------------------------------------------------

func _test_deck_writes_to_sim() -> void:
	var deck: TacticalDeck = hud.deck
	var car: GtCar = mine[0]
	deck.deck_car_id = car.id
	deck.pace_row.buttons[GtTypes.PaceMode.ATTACK].pressed.emit()
	deck.fuel_row.buttons[GtTypes.FuelMode.PUSH].pressed.emit()
	deck.ers_row.buttons[GtTypes.ErsMode.DEPLOY].pressed.emit()
	deck.tactic_row.buttons[GtTypes.TacticMode.AUTO].pressed.emit()
	check(car.pace_mode == GtTypes.PaceMode.ATTACK and car.fuel_mode == GtTypes.FuelMode.PUSH and car.ers_mode == GtTypes.ErsMode.DEPLOY and race.tactic_mode == GtTypes.TacticMode.AUTO,
		"deck: pace, fuel mix, ERS and tactic desk buttons write straight into the sim")
	deck.refresh()
	check(deck.pace_row.active == GtTypes.PaceMode.ATTACK and deck.ers_row.active == GtTypes.ErsMode.DEPLOY and deck.tactic_row.active == GtTypes.TacticMode.AUTO,
		"deck: the active button follows the sim state")
	race.set_tactic_mode(GtTypes.TacticMode.MANUAL)

	var other: GtCar = mine[1]
	deck.tabs[1].pressed.emit()
	check(deck.deck_car_id == other.id and world.followed_id == other.id and deck.tabs[1].text.contains(other.code),
		"deck: the second driver tab selects that car and the camera follows it")
	deck.tabs[0].pressed.emit()

	deck.tyre_row.buttons[1 + GtTypes.Compound.WET].pressed.emit()
	var accepted: bool = deck.press_box()
	deck.refresh()
	check(accepted and car.pit_request == GtTypes.Compound.WET and deck.box_button.disabled and deck.box_button.text.contains("BOX CALLED") and deck.box_button.text.contains("WET"),
		"deck: choosing W and BOX THIS LAP calls the car in for wets and locks the button")
	car.pit_request = -1
	deck.pit_compound = -1
	deck.tyre_row.set_active(0)
	deck.refresh()


# --- fold, keys --------------------------------------------------------------------------------------------

func _test_deck_fold_and_keys() -> void:
	var deck: TacticalDeck = hud.deck
	var bottom: float = deck.position.y + deck.size.y
	var folded_key: bool = hud.handle_key(KEY_M)
	var folded_ok: bool = deck.collapsed and is_equal_approx(deck.size.y, TacticalDeck.SIZE_COLLAPSED.y) and is_equal_approx(deck.position.y + deck.size.y, bottom)
	hud.handle_key(KEY_M)
	check(folded_key and folded_ok and not deck.collapsed and is_equal_approx(deck.size.y, TacticalDeck.SIZE_OPEN.y),
		"deck: M folds the deck to its header with the bottom edge fixed, and M opens it again")

	var car: GtCar = mine[0]
	deck.deck_car_id = car.id
	car.ers_mode = GtTypes.ErsMode.NEUTRAL
	car.pace_mode = GtTypes.PaceMode.STANDARD
	hud.handle_key(KEY_E)
	var overtaking: bool = car.ers_mode == GtTypes.ErsMode.OVERTAKE
	hud.handle_key(KEY_E)
	var restored: bool = car.ers_mode == GtTypes.ErsMode.NEUTRAL
	hud.handle_key(KEY_BRACKETRIGHT)
	var up: int = car.pace_mode
	hud.handle_key(KEY_BRACKETLEFT)
	hud.handle_key(KEY_BRACKETLEFT)
	var down: int = car.pace_mode
	check(overtaking and restored and up == GtTypes.PaceMode.AGGRESSIVE and down == GtTypes.PaceMode.LIGHT,
		"keys: E toggles ERS overtake and restores the old mode, ] and [ step the pace")
	car.pace_mode = GtTypes.PaceMode.STANDARD

	world.followed_id = mine[0].id
	hud.handle_key(KEY_N)
	var first: int = world.followed_id
	hud.handle_key(KEY_N)
	var second: int = world.followed_id
	check(first == mine[1].id and second == mine[0].id, "keys: N cycles through the cars of the player team")

	hud.handle_key(KEY_H)
	var hidden: bool = not hud.stage.visible and not hud.handle_key(KEY_M)
	hud.handle_key(KEY_H)
	check(hidden and hud.stage.visible, "keys: H hides the whole HUD (other keys sleep) and brings it back")


# --- telemetry drawer ----------------------------------------------------------------------------------------

func _test_drawer() -> void:
	var car: GtCar = mine[0]
	world.followed_id = car.id
	car.v = 70.0
	car.gear = 5
	car.rpm = 8800.0
	car.drs_active = true
	car.throttle = 1.0
	car.brake = 0.0
	car.lateral_g = 2.4
	car.longitudinal_g = -1.5
	car.is_punctured = true
	car.punctured_wheel = GtTypes.Wheel.FL
	car.fuel_stage = GtTypes.FuelStage.LIMP
	car.wheel_temp[1] = 140.0
	car.wheel_blister_pct = PackedFloat64Array([0.0, 40.0, 0.0, 0.0])
	car.ers_mode = GtTypes.ErsMode.OVERTAKE
	car.ers_battery = 55.0
	car.driver_stress = 80.0
	car.driver_confidence = 30.0
	hud.refresh_all()
	var drawer: TelemetryDrawer = hud.drawer
	check(drawer.gear_label.text == "5" and drawer.speed_label.text == "252 KM/H" and drawer.title.text.contains(car.code) and drawer.rpm.lit_blocks() == drawer.rpm.count and drawer.speed_bar.lit_blocks() == 16,
		"telemetry: gear box %s, speed bar %d of 20 blocks (%s), shift lights full at the limiter" % [drawer.gear_label.text, drawer.speed_bar.lit_blocks(), drawer.speed_label.text])
	check(drawer.drs_label.get_theme_color("font_color") == T.INK_BORDER_BLACK and (drawer.drs_label.get_theme_stylebox("normal") as StyleBoxFlat).bg_color == T.ACCENT_ELECTRIC_CYAN,
		"telemetry: the DRS chip lights cyan while the wing is open")
	check(drawer.pedals.throttle[TelemetryWidgets.PedalTrace.SAMPLES - 1] == 1.0 and drawer.pedals.brake[TelemetryWidgets.PedalTrace.SAMPLES - 1] == 0.0
			and drawer.gball.trail.size() >= 1 and drawer.gball.trail[drawer.gball.trail.size() - 1] == Vector2(2.4, -1.5),
		"telemetry: the pedal trace and the G box record the live throttle, brake and G samples")
	check(drawer.tyres.blown == GtTypes.Wheel.FL and drawer.tyres.heat_of(0) == T.ACCENT_ANIME_CRIMSON and drawer.tyres.heat_of(1) == T.ACCENT_ANIME_CRIMSON
			and drawer.tyres.heat_of(3) == T.ACCENT_ACID_LIME and drawer.tyres.blisters[1] == 40.0,
		"telemetry: the tyre matrix paints a blown tyre and an overheated one crimson, a healthy one lime, and carries the blister flag")
	check(drawer.fuel_stage_label.text.contains("LIMP") and drawer.fuel_delta_label.text.ends_with(" L") and drawer.fuel_bar.marker >= 0.0
			and drawer.ers.chevron_count() == 3 and drawer.ers.charge == 0.55 and drawer.mood.stress == 0.8 and drawer.mood.confidence == 0.3 and drawer.damage_bar.invert_scale,
		"telemetry: fuel stage with the margin to the flag, ERS charge with three overtake chevrons, stress and confidence on one diverging bar")
	var rival: GtCar = race.cars[0] if race.cars[0] != car else race.cars[1]
	drawer.show_car(rival, race.laps)
	var cleared: bool = drawer.gball.trail.size() == 1
	drawer.show_car(car, race.laps)
	car.is_punctured = false
	car.punctured_wheel = -1
	car.fuel_stage = GtTypes.FuelStage.OPTIMAL
	car.wheel_temp[1] = 90.0
	car.wheel_blister_pct = PackedFloat64Array([0.0, 0.0, 0.0, 0.0])
	car.drs_active = false
	car.ers_mode = GtTypes.ErsMode.NEUTRAL
	car.lateral_g = 0.0
	car.longitudinal_g = 0.0
	car.v = 60.0
	var shown: bool = drawer.visible
	hud.handle_key(KEY_T)
	var folded: bool = not drawer.visible
	hud.handle_key(KEY_T)
	check(cleared and shown and folded and drawer.visible, "telemetry: another car starts with fresh traces, T hides and shows the drawer")
	check(TelemetryDrawer.temp_tint(60.0) == T.ACCENT_ELECTRIC_CYAN and TelemetryDrawer.temp_tint(95.0) == T.ACCENT_ACID_LIME and TelemetryDrawer.temp_tint(118.0) == T.ACCENT_CYBER_YELLOW and TelemetryDrawer.temp_tint(130.0) == T.ACCENT_ANIME_CRIMSON,
		"telemetry: tyre temperature colour is cold cyan, ideal lime, hot yellow, critical crimson")
	check(TelemetryWidgets.PulseTrace.beat(0.35) > 0.9 and absf(TelemetryWidgets.PulseTrace.beat(0.0)) < 0.001 and TelemetryWidgets.PulseTrace.beat(0.66) > 0.2,
		"telemetry: the heartbeat trace has its QRS spike and T wave")


# --- suggestion card ------------------------------------------------------------------------------------------

func _test_suggestion_card() -> void:
	var car: GtCar = mine[0]
	car.pit_request = -1
	race.suggest_tactic(car, GtTypes.TacticType.PIT, GtTypes.Compound.HARD, "BOX FOR HARD", "Tyre wear critical. Suggest box this lap.")
	var shown: bool = hud.card.visible and hud.card_title.text.contains("BOX FOR HARD") and hud.card_text.text.contains("wear")
	hud.accept_button.pressed.emit()
	check(shown and not hud.card.visible and car.pit_request == GtTypes.Compound.HARD,
		"suggestion: the hybrid desk shows a card, ACCEPT executes the box call and hides it")
	car.pit_request = -1
	race.suggest_tactic(car, GtTypes.TacticType.PACE, GtTypes.PaceMode.CONSERVE, "PACE: CONSERVE", "Save the tyres.")
	var again: bool = hud.card.visible
	hud.dismiss_button.pressed.emit()
	check(again and not hud.card.visible and car.pace_mode != GtTypes.PaceMode.CONSERVE,
		"suggestion: DISMISS hides the card and leaves the car alone")


# --- radio, flags -----------------------------------------------------------------------------------------------

func _test_radio_and_flags() -> void:
	var car: GtCar = mine[1]
	race.push_radio(car, "engineer", "Box box box, rain in sector two.", true)
	check(hud.engineer_radio.banner.visible and hud.ticker.text.contains("rain in sector two") and hud.deck.radio_label.text.contains("rain in sector two") and hud.engineer_radio.banner.position.y + hud.engineer_radio.banner.size.y * hud.engineer_radio.banner.scale.y < hud.stage.position.y + hud.deck.position.y * hud.stage.scale.y and not hud.last_radio.is_empty(),
		"radio: an engineer call cuts in with the anime banner and runs through the race control marquee")

	race.set_flag(GtTypes.Flag.SC, 1, "SAFETY CAR DEPLOYED", 30.0)
	hud.refresh_all()
	var flagged: bool = hud.tape.visible and hud.tape.label.text.contains("SAFETY CAR") and hud.flag_label.text == "SC FLAG"
	race.set_flag(GtTypes.Flag.GREEN, 1, "GREEN", 1.0)
	hud.refresh_all()
	check(flagged and not hud.tape.visible and hud.flag_label.text == "GREEN FLAG",
		"flags: the caution tape runs under the ribbon during the safety car and clears on green")


# --- weather, sim rate ------------------------------------------------------------------------------------------------

func _test_weather_and_rate() -> void:
	race.weather.rain_intensity = 0.9
	race.weather.track_water_pct = 85.0
	hud.refresh_all()
	var status: Dictionary = hud.weather_status()
	var rain_text: String = hud.weather_widget.status_label.text
	race.weather.rain_intensity = 0.0
	race.weather.track_water_pct = 0.0
	check(int(status["state"]) == 2 and (status["forecast"] as Array).size() == 5 and rain_text.contains("RAIN"),
		"weather: the ribbon radar reads heavy rain with a five lap forecast (%s)" % rain_text)
	check(RaceHud.weather_state(0.0, 30.0) == 3 and RaceHud.weather_state(0.2, 10.0) == 1 and RaceHud.weather_state(0.0, 2.0) == 0,
		"weather: drying, drizzle and dry map onto the pit wall radar states")

	hud.rate_row.buttons[3].pressed.emit()
	var rate: float = world.time_scale
	world.set_time_scale(1.0)
	check(is_equal_approx(rate, 8.0) and RaceHud.lap_text(83.456) == "1:23.456" and RaceHud.lap_text(-1.0) == "--",
		"ribbon: the sim rate buttons set the world time scale, lap times read m:ss.mmm")
