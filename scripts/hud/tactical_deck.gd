class_name TacticalDeck
extends Control

## Bottom command strip of the race HUD, the N2 "faders console": a card per car of the player team,
## three vertical faders (PACE / FUEL / ERS) each with a zoned gauge and an OK / WATCH / DANGER verdict
## from the sim's own formulas (GtForecast), the tyre wheel with its compound chips, the two-state BOX
## button, the BOX WINDOW card from the weather forecast, and a header with the forecast line, the COACH
## toggle, the desk mode (MANUAL / AUTO) and the last radio line. Every control writes straight into the
## GT sim and answers a click with a press, a pop of text and a pitched sound; refresh() mirrors the sim
## back so keys and the AI suggestions show up on the controls too. A verdict never locks an option.

signal car_picked(car_id: int)

const UI = preload("res://scripts/ui/pit_wall_ui.gd")
const T = preload("res://scripts/ui/ui_theme_tokens.gd")

const SIZE_OPEN := Vector2(1888.0, 140.0)
const SIZE_COLLAPSED := Vector2(1888.0, 44.0)
const BODY_Y: float = 38.0
const BODY_H: float = 96.0
const PACE_X: float = 284.0
const FUEL_X: float = 498.0
const ERS_X: float = 712.0
const BOX_DEBOUNCE_MS: int = 250
const PRESS_S: float = 0.12
const POP_S: float = 0.5
const TACTIC_NAME: Array[String] = ["MANUAL", "AUTO"]
const BOX_STYLE_STATES: Array[String] = ["normal", "hover", "pressed"]
const DESK_STATUS: Array[String] = ["MODE: MANUAL // 100% PLAYER DIRECTIVE", "MODE: AUTO // AI ENGINEER ASSISTED"]
const TYRE_LABELS: Array[String] = ["A", "S", "M", "H", "I", "W"]
const TYRE_WORDS: Array[String] = ["AUTO", "SOFT", "MED", "HARD", "INTER", "WET"]
const AUTO_COLOR := Color("#CFD8E8")
const PANEL_BAR := Color("#121722")
const SEVERITY_WORD: Array[String] = ["OK", "WATCH", "DANGER"]
const KIND_NAME: Dictionary = {"pace": "PACE", "fuel": "FUEL", "ers": "ERS"}
const WINDOW_LAPS: int = 5

var race: GtRace
var deck_car_id: int = -1
## Compound the next box call asks for, -1 = let the world pick from the track water.
var pit_compound: int = -1
var collapsed: bool = false
## Plain-language sentences in the tooltips.
var coach: bool = true
## How many press animations were started; stays put under reduce motion.
var feedback_tweens: int = 0
var tabs: Array[Button] = []
var pace_row: FaderLadder
var fuel_row: FaderLadder
var ers_row: FaderLadder
var tyre_row: ChipGrid
var tactic_row: ModeRow
var wheel: TyreWheel
var pace_gauge: ZonedGauge
var fuel_gauge: ZonedGauge
var ers_gauge: ZonedGauge
var pace_pill: Label
var fuel_pill: Label
var ers_pill: Label
var pace_mark: SeverityMark
var fuel_mark: SeverityMark
var ers_mark: SeverityMark
var tip: DeckTip
var box_button: Button
var coach_button: Button
var collapse_button: Button
var info_label: Label
var radio_label: Label
var desk_status: Label
var forecast_label: Label
var window_label: Label
## The chamfered header plate and its title, repainted when the team accent changes.
var header_shape: ColorRect
var header_title: Label

var _world: Node3D
var _body: Control
var _window_chips: Array[ColorRect] = []
## Every placed control with the extent it was given: before the deck is in the tree a control's minimum size is
## measured with the default theme and pushes the size up, so _ready() sets the extents again.
var _extents: Dictionary = {}
var _numbers: Dictionary = {}
var _verdicts: Dictionary = {}
var _tab_text: Array[String] = ["", ""]
## The BOX button's own styles, kept so the crimson CANCEL look can be undone.
var _box_styles: Dictionary = {}
var _box_cancel_look: bool = false
var _box_clicked_at: int = -100000
var _ers_before: int = GtTypes.ErsMode.NEUTRAL
var _hover_kind: String = ""
var _hover_index: int = -1


func _init() -> void:
	custom_minimum_size = SIZE_OPEN
	size = SIZE_OPEN
	UI.surface(self)
	var bar := ColorRect.new()
	bar.color = PANEL_BAR
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bar)
	bar.position = Vector2(6.0, 6.0)
	bar.size = Vector2(SIZE_OPEN.x - 12.0, 28.0)
	var header := UI.header("TACTICAL DECK  //  ENGINEER LINK", T.ACCENT_ACID_LIME)
	add_child(header)
	header.position = Vector2(6.0, 6.0)
	header.size = Vector2(264.0, 28.0)
	header_shape = header.get_child(0) as ColorRect
	header_title = header.get_child(1) as Label
	_body = Control.new()
	_body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_body)
	_body.position = Vector2.ZERO
	_body.size = SIZE_OPEN
	_build_header()
	_build_tabs()
	_build_faders()
	_build_pit()
	_build_window()
	tip = DeckTip.new()
	add_child(tip)


func _ready() -> void:
	for node: Control in _extents:
		node.size = _extents[node]


## The team accent skins the header plate; `on_accent` is the type colour that stays readable on it.
func set_accent(accent: Color, on_accent: Color) -> void:
	(header_shape.material as ShaderMaterial).set_shader_parameter("fill_color", accent)
	header_title.add_theme_color_override("font_color", on_accent)


func bind(p_world: Node3D) -> void:
	_world = p_world
	race = p_world.race
	for car: GtCar in player_cars():
		deck_car_id = car.id
		break
	refresh()


func player_cars() -> Array[GtCar]:
	var found: Array[GtCar] = []
	for car: GtCar in race.cars:
		if car.team_id == race.player_team_id:
			found.append(car)
	found.sort_custom(func(a: GtCar, b: GtCar) -> bool: return a.id < b.id)
	return found


## Thin content margins so a button fits a short row.
func _tighten(button: Button) -> void:
	for state: String in ["normal", "hover", "pressed", "focus", "disabled"]:
		var box := button.get_theme_stylebox(state) as StyleBoxFlat
		box.content_margin_left = 8.0
		box.content_margin_right = 8.0
		box.content_margin_top = 2.0
		box.content_margin_bottom = 2.0


func _place(node: Control, at: Vector2, extent: Vector2, parent: Control = null) -> void:
	(parent if parent != null else _body).add_child(node)
	node.position = at
	node.size = extent
	_extents[node] = extent


func _build_header() -> void:
	forecast_label = UI.label("", 12, T.TEXT_SECONDARY)
	forecast_label.clip_text = true
	_place(forecast_label, Vector2(282.0, 11.0), Vector2(650.0, 18.0), self)
	coach_button = UI.button("COACH ON")
	coach_button.add_theme_font_size_override("font_size", 12)
	coach_button.focus_mode = Control.FOCUS_NONE
	_tighten(coach_button)
	coach_button.pressed.connect(_on_coach)
	_place(coach_button, Vector2(944.0, 9.0), Vector2(86.0, 22.0), self)
	tactic_row = ModeRow.new(TACTIC_NAME, [T.ACCENT_ACID_LIME, T.ACCENT_CYBER_YELLOW], 12)
	tactic_row.selected.connect(_on_tactic)
	for button: Button in tactic_row.buttons:
		button.custom_minimum_size.y = 22.0
	_place(tactic_row, Vector2(1040.0, 8.0), Vector2(230.0, 24.0), self)
	radio_label = UI.label("", 12, T.ACCENT_ACID_LIME, UI.RADIO)
	radio_label.clip_text = true
	radio_label.max_lines_visible = 1
	_place(radio_label, Vector2(1284.0, 10.0), Vector2(440.0, 20.0), self)
	collapse_button = UI.button("FOLD DECK [M]")
	collapse_button.add_theme_font_size_override("font_size", 12)
	collapse_button.focus_mode = Control.FOCUS_NONE
	_tighten(collapse_button)
	collapse_button.pressed.connect(toggle_collapsed)
	_place(collapse_button, Vector2(1740.0, 8.0), Vector2(130.0, 24.0), self)


func _build_tabs() -> void:
	for index: int in range(2):
		var tab := UI.button("")
		tab.add_theme_font_size_override("font_size", 15)
		tab.focus_mode = Control.FOCUS_NONE
		_tighten(tab)
		tab.pressed.connect(_on_tab.bind(index))
		_place(tab, Vector2(14.0, BODY_Y + 48.0 * float(index)), Vector2(250.0, 44.0))
		tabs.append(tab)


func _build_faders() -> void:
	var pace_tints: Array[Color] = [T.ACCENT_ELECTRIC_CYAN, T.ACCENT_ELECTRIC_CYAN, T.ACCENT_ACID_LIME, T.ACCENT_CYBER_YELLOW, T.ACCENT_ANIME_CRIMSON]
	var fuel_tints: Array[Color] = [T.ACCENT_ELECTRIC_CYAN, T.ACCENT_ACID_LIME, T.ACCENT_ANIME_CRIMSON]
	var ers_tints: Array[Color] = [T.ACCENT_PURPLE_SECTOR, T.ACCENT_ACID_LIME, T.ACCENT_CYBER_YELLOW, T.ACCENT_ANIME_CRIMSON]
	var pace: Dictionary = _build_fader("pace", PACE_X, GtTypes.PACE_NAME, pace_tints, "TYRE LIFE", "RED = PAST\nTHE CLIFF")
	var fuel: Dictionary = _build_fader("fuel", FUEL_X, GtTypes.FUEL_NAME, fuel_tints, "FUEL SPARE", "LINE = LAPS\nTO FINISH")
	var ers: Dictionary = _build_fader("ers", ERS_X, GtTypes.ERS_NAME, ers_tints, "BATTERY", "RED = LOW\nBATTERY")
	pace_row = pace["ladder"]
	fuel_row = fuel["ladder"]
	ers_row = ers["ladder"]
	pace_gauge = pace["gauge"]
	fuel_gauge = fuel["gauge"]
	ers_gauge = ers["gauge"]
	pace_pill = pace["pill"]
	fuel_pill = fuel["pill"]
	ers_pill = ers["pill"]
	pace_mark = pace["mark"]
	fuel_mark = fuel["mark"]
	ers_mark = ers["mark"]
	pace_row.selected.connect(_on_pace)
	fuel_row.selected.connect(_on_fuel)
	ers_row.selected.connect(_on_ers)


## One fader group at column `x`: ladder, gauge and the text column (title, big number, verdict pill, legend).
func _build_fader(kind: String, x: float, labels: Array[String], tints: Array[Color], title: String, legend: String) -> Dictionary:
	var ladder := FaderLadder.new(labels, tints, BODY_H, 12)
	_place(ladder, Vector2(x, BODY_Y), Vector2(FaderLadder.WIDTH, BODY_H))
	ladder.hovered.connect(_show_hover.bind(kind))
	ladder.unhovered.connect(_clear_hover)
	var gauge := ZonedGauge.new()
	_place(gauge, Vector2(x + 112.0, BODY_Y), Vector2(22.0, BODY_H))
	var title_label := UI.label(title, 9, T.TEXT_MUTED)
	_place(title_label, Vector2(x + 142.0, BODY_Y), Vector2(60.0, 12.0))
	var number := UI.label("", 22, T.TEXT_PRIMARY, UI.DISPLAY)
	_place(number, Vector2(x + 142.0, BODY_Y + 12.0), Vector2(62.0, 30.0))
	var mark := SeverityMark.new()
	_place(mark, Vector2(x + 142.0, BODY_Y + 48.0), Vector2(14.0, 14.0))
	var pill := UI.label("", 11, T.TEXT_PRIMARY)
	_place(pill, Vector2(x + 160.0, BODY_Y + 46.0), Vector2(50.0, 16.0))
	var legend_label := UI.label(legend, 8, T.TEXT_MUTED)
	_place(legend_label, Vector2(x + 142.0, BODY_Y + 70.0), Vector2(66.0, 24.0))
	_numbers[kind] = number
	return {"ladder": ladder, "gauge": gauge, "pill": pill, "mark": mark}


func _build_pit() -> void:
	wheel = TyreWheel.new()
	_place(wheel, Vector2(944.0, BODY_Y), Vector2(96.0, 96.0))
	wheel.clicked.connect(_on_wheel_clicked)
	wheel.scrolled.connect(_on_wheel_scrolled)
	wheel.mouse_entered.connect(func() -> void: _show_hover(wheel.compound, "wheel"))
	wheel.mouse_exited.connect(_clear_hover)
	var colors: Array[Color] = [AUTO_COLOR]
	colors.append_array(GtTypes.COMPOUND_COLOR)
	tyre_row = ChipGrid.new(TYRE_LABELS, TYRE_WORDS, colors)
	_place(tyre_row, Vector2(1048.0, BODY_Y), Vector2(224.0, 96.0))
	tyre_row.selected.connect(_on_tyre)
	tyre_row.hovered.connect(_show_hover.bind("tyre"))
	tyre_row.unhovered.connect(_clear_hover)
	box_button = UI.button("REQUEST BOX [B]")
	box_button.add_theme_font_size_override("font_size", 28)
	box_button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box_button.focus_mode = Control.FOCUS_NONE
	box_button.pressed.connect(on_box_pressed)
	box_button.mouse_entered.connect(_show_hover.bind(0, "box"))
	box_button.mouse_exited.connect(_clear_hover)
	for state: String in BOX_STYLE_STATES:
		_box_styles[state] = box_button.get_theme_stylebox(state)
	_place(box_button, Vector2(1286.0, BODY_Y), Vector2(270.0, 78.0))
	info_label = UI.label("", 11, T.TEXT_SECONDARY)
	_place(info_label, Vector2(1286.0, BODY_Y + 80.0), Vector2(270.0, 16.0))
	tyre_row.set_active(0)


func _build_window() -> void:
	var card := Panel.new()
	card.add_theme_stylebox_override("panel", UI.style(T.SURFACE_PANEL_ELEVATED, T.TEXT_MUTED))
	_place(card, Vector2(1568.0, BODY_Y), Vector2(304.0, BODY_H))
	window_label = UI.label("", 14, T.TEXT_PRIMARY, UI.HEADER)
	window_label.clip_text = true
	_place(window_label, Vector2(10.0, 6.0), Vector2(284.0, 36.0), card)
	for index: int in range(WINDOW_LAPS):
		var chip := ColorRect.new()
		chip.color = PANEL_BAR
		chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_place(chip, Vector2(10.0 + 58.0 * float(index), 46.0), Vector2(54.0, 20.0), card)
		var lap := UI.label("L+%d" % (index + 1), 10, T.INK_BORDER_BLACK)
		lap.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_place(lap, Vector2.ZERO, Vector2(54.0, 20.0), chip)
		_window_chips.append(chip)
	desk_status = UI.label(DESK_STATUS[0], 11, T.TEXT_SECONDARY)
	_place(desk_status, Vector2(10.0, 74.0), Vector2(284.0, 16.0), card)


## Last radio line of the engineer, shown in the header.
func set_radio(text: String) -> void:
	radio_label.text = text


# --- click feedback ------------------------------------------------------------

## A click answers in three ways: the control presses in (scale 0.92 -> 1 in 0.12 s), `text` pops above it
## and fades, and a click sounds at `pitch`. Tyre and BOX actions also kick the wheel. Reduce motion drops
## the press, the pop and the kick, never the sound.
func apply_click_feedback(control: Control, text: String, pitch: float) -> void:
	AudioManager.click_pitched(self, pitch)
	if control == wheel or control == box_button or (control is Button and tyre_row.buttons.has(control as Button)):
		wheel.hit()
	if PresentationSettings.reduce_motion or not is_inside_tree():
		return
	control.pivot_offset = control.size * 0.5
	control.scale = Vector2(0.92, 0.92)
	control.create_tween().tween_property(control, "scale", Vector2.ONE, PRESS_S)
	feedback_tweens += 1
	if text == "":
		return
	var pop := UI.label(text, 16, T.ACCENT_ACID_LIME, UI.DISPLAY)
	pop.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(pop)
	pop.size = Vector2(120.0, 22.0)
	pop.position = control.global_position - global_position + Vector2(control.size.x * 0.5 - 60.0, -8.0)
	var rise := pop.create_tween().set_parallel(true)
	rise.tween_property(pop, "position:y", pop.position.y - 18.0, POP_S)
	rise.tween_property(pop, "modulate:a", 0.0, POP_S)
	rise.chain().tween_callback(pop.queue_free)
	feedback_tweens += 1


# --- actions -------------------------------------------------------------------

func _on_tab(index: int) -> void:
	apply_click_feedback(tabs[index], "", 1.0)
	var cars: Array[GtCar] = player_cars()
	if index < cars.size():
		deck_car_id = cars[index].id
		car_picked.emit(deck_car_id)
		refresh()


func _on_pace(index: int) -> void:
	race.set_pace_mode(deck_car_id, index)
	apply_click_feedback(pace_row.buttons[index], GtTypes.PACE_NAME[index], 0.9 + 0.06 * float(index))
	refresh()


func _on_fuel(index: int) -> void:
	race.set_fuel_mode(deck_car_id, index)
	apply_click_feedback(fuel_row.buttons[index], GtTypes.FUEL_NAME[index], 1.05 + 0.08 * float(index))
	refresh()


func _on_ers(index: int) -> void:
	race.set_ers_mode(deck_car_id, index)
	apply_click_feedback(ers_row.buttons[index], GtTypes.ERS_NAME[index], 1.2 + 0.07 * float(index))
	refresh()


func _on_tactic(index: int) -> void:
	race.set_tactic_mode(index)


func _on_coach() -> void:
	coach = not coach
	coach_button.text = "COACH ON" if coach else "COACH OFF"
	apply_click_feedback(coach_button, coach_button.text, 1.4)
	_refresh_hover()


func _on_tyre(index: int) -> void:
	pit_compound = index - 1
	tyre_row.set_active(index)
	wheel.set_compound(index, true)
	apply_click_feedback(tyre_row.buttons[index], TYRE_WORDS[index], 0.85 + 0.07 * float(index))
	_refresh_hover()


func _on_wheel_clicked() -> void:
	_on_tyre((wheel.compound + 1) % TYRE_WORDS.size())


func _on_wheel_scrolled(direction: int) -> void:
	_on_tyre(posmod(wheel.compound + direction, TYRE_WORDS.size()))


## Calls the deck car in at the next pit entry for the chosen tyres.
func press_box() -> bool:
	var called: bool = _world.request_pit(deck_car_id, pit_compound)
	apply_click_feedback(box_button, "BOX", 0.7)
	if called:
		wheel.armed = true
	return called


## Withdraws the deck car's box call while it has not reached the pit lane (no penalty).
func cancel_box() -> bool:
	var withdrawn: bool = _world.cancel_pit(deck_car_id)
	apply_click_feedback(box_button, "CANCEL", 0.6)
	if withdrawn:
		wheel.armed = false
	return withdrawn


## The BOX button is one control with two states: REQUEST BOX, and CANCEL BOX once a call is out. A second
## click within 0.25 s is ignored, so a double click cannot call the car and withdraw it at once.
func on_box_pressed() -> void:
	var now: int = Time.get_ticks_msec()
	if now - _box_clicked_at < BOX_DEBOUNCE_MS:
		return
	_box_clicked_at = now
	var car: GtCar = race.get_car(deck_car_id)
	if car != null and car.pit_request >= 0 and car.pit == null:
		cancel_box()
	else:
		press_box()


func step_pace(direction: int) -> void:
	var car: GtCar = race.get_car(deck_car_id)
	if car != null:
		race.set_pace_mode(deck_car_id, clampi(car.pace_mode + direction, 0, GtTypes.PaceMode.ATTACK))
		refresh()


## E: overtake button on and off, back to the mode the car was in.
func toggle_ers_overtake() -> void:
	var car: GtCar = race.get_car(deck_car_id)
	if car == null:
		return
	if car.ers_mode == GtTypes.ErsMode.OVERTAKE:
		race.set_ers_mode(deck_car_id, _ers_before)
	else:
		_ers_before = car.ers_mode
		race.set_ers_mode(deck_car_id, GtTypes.ErsMode.OVERTAKE)
	refresh()


func toggle_collapsed() -> void:
	AudioManager.click(self)
	set_collapsed(not collapsed)


func set_collapsed(value: bool) -> void:
	if value == collapsed:
		return
	collapsed = value
	var bottom: float = position.y + size.y
	var extent: Vector2 = SIZE_COLLAPSED if collapsed else SIZE_OPEN
	custom_minimum_size = extent
	size = extent
	position.y = bottom - extent.y
	_body.visible = not collapsed
	if collapsed:
		_clear_hover()


# --- verdicts and tooltips ------------------------------------------------------

## The verdict of option `index` of `kind` ("pace", "fuel" or "ers") for the deck car, as computed by the last
## refresh (or on the spot when the option has not been judged yet).
func verdict_for(kind: String, index: int) -> Dictionary:
	var cached: Array = _verdicts.get(kind, [])
	if index >= 0 and index < cached.size():
		return cached[index]
	var car: GtCar = race.get_car(deck_car_id)
	return GtForecast.verdict(kind, index, car, GtForecast.laps_left(race, car))


func _upcoming(car: GtCar) -> Array[Dictionary]:
	var found: Array[Dictionary] = []
	for entry: Dictionary in race.weather.forecast:
		if int(entry["lap"]) > car.lap:
			found.append(entry)
			if found.size() >= WINDOW_LAPS:
				break
	return found


func _show_hover(index: int, kind: String) -> void:
	_hover_kind = kind
	_hover_index = index
	_refresh_hover()


func _clear_hover() -> void:
	_hover_kind = ""
	_hover_index = -1
	tip.hide_tip()
	if race != null:
		refresh()


func _refresh_hover() -> void:
	var car: GtCar = race.get_car(deck_car_id) if race != null else null
	if _hover_kind == "" or car == null:
		return
	var index: int = _hover_index
	match _hover_kind:
		"pace", "fuel", "ers":
			var ladder: FaderLadder = {"pace": pace_row, "fuel": fuel_row, "ers": ers_row}[_hover_kind]
			var option: String = {"pace": GtTypes.PACE_NAME, "fuel": GtTypes.FUEL_NAME, "ers": GtTypes.ERS_NAME}[_hover_kind][index]
			var plain: String = {"pace": DeckCoach.PACE, "fuel": DeckCoach.FUEL, "ers": DeckCoach.ERS}[_hover_kind][index]
			var verdict: Dictionary = verdict_for(_hover_kind, index)
			var title: String = "%s: %s" % [KIND_NAME[_hover_kind], option]
			var numbers: String = _impact_numbers(_hover_kind, index, car)
			tip.show_for(ladder.buttons[index], int(verdict["severity"]), title, plain, numbers, String(verdict["text"]), coach)
			forecast_label.text = "%s -> %s" % [title, numbers]
		"tyre", "wheel":
			var target: Control = wheel if _hover_kind == "wheel" else tyre_row.buttons[index]
			var verdict: Dictionary = GtForecast.tyre_verdict(index, race.weather.track_water_pct, race.weather.rain_intensity, _upcoming(car))
			tip.show_for(target, int(verdict["severity"]), "TYRES: %s" % TYRE_WORDS[index], DeckCoach.TYRE[index], "", String(verdict["text"]), coach)
		"box":
			tip.show_for(box_button, 0, "BOX", DeckCoach.BOX, "", "Best lap to pit: %s" % window_label.text.get_slice("\n", 0), coach)
	_update_gauges(car)


## What choosing `index` changes against the option now active, in the sim's own units.
func _impact_numbers(kind: String, index: int, car: GtCar) -> String:
	match kind:
		"pace":
			var speed: float = (GtTypes.PACE_SPEED_MULT[index] / GtTypes.PACE_SPEED_MULT[car.pace_mode] - 1.0) * 100.0
			return "SPEED %+.1f%%  WEAR %.1f%%/lap  FUEL %.2f kg/lap" % [speed, GtForecast.wear_per_lap(car, index) * 100.0, GtForecast.burn_per_lap(car, index, car.fuel_mode)]
		"fuel":
			return "FUEL %.2f kg/lap  SPARE %+.1f laps" % [GtForecast.burn_per_lap(car, car.pace_mode, index), float(verdict_for("fuel", index)["projected"])]
	var seconds: float = GtForecast.ers_seconds(car.ers_battery, index)
	return "DEPLOY ~%.0f s" % seconds if seconds != INF else "NO DEPLOY"


# --- mirror of the sim ---------------------------------------------------------------

func refresh() -> void:
	if race == null:
		return
	var cars: Array[GtCar] = player_cars()
	for index: int in range(tabs.size()):
		tabs[index].visible = index < cars.size()
		if index < cars.size():
			_style_tab(index, cars[index])
	var car: GtCar = race.get_car(deck_car_id)
	if car == null:
		return
	pace_row.set_active(car.pace_mode)
	fuel_row.set_active(car.fuel_mode)
	ers_row.set_active(car.ers_mode)
	tactic_row.set_active(race.tactic_mode)
	tyre_row.set_active(pit_compound + 1)
	desk_status.text = DESK_STATUS[clampi(race.tactic_mode, 0, DESK_STATUS.size() - 1)]
	var locked: bool = car.pit != null or car.finished_at >= 0.0 or car.is_dnf
	box_button.disabled = locked
	var cancelling: bool = not locked and car.pit_request >= 0
	if car.is_dnf:
		box_button.text = "RETIRED"
	elif car.finished_at >= 0.0:
		box_button.text = "CHEQUERED"
	elif car.pit != null:
		box_button.text = "IN THE PIT LANE"
	elif cancelling:
		box_button.text = "CANCEL BOX [ESC]  //  %s" % GtTypes.COMPOUND_NAME[car.pit_request]
	else:
		box_button.text = "REQUEST BOX [B]"
	_style_box_button(cancelling)
	info_label.text = "%s %s   STOPS %d   AGE %d L" % [car.code, GtTypes.COMPOUND_NAME[car.compound], car.stops, car.tyre_age_laps]
	_judge(car)
	wheel.set_compound(pit_compound + 1, false)
	wheel.armed = cancelling
	wheel.speed_kmh = car.speed_kmh()
	wheel.auto_hint = GtForecast.recommended_compound(race.weather.track_water_pct, race.weather.rain_intensity)
	_update_gauges(car)
	_update_window(car)
	if _hover_kind == "":
		forecast_label.text = _forecast_text(car)


## One verdict per option of the three faders, kept for the tooltips; marks, pills and big numbers follow.
func _judge(car: GtCar) -> void:
	var laps: float = GtForecast.laps_left(race, car)
	var rows: Dictionary = {"pace": pace_row, "fuel": fuel_row, "ers": ers_row}
	var active: Dictionary = {"pace": car.pace_mode, "fuel": car.fuel_mode, "ers": car.ers_mode}
	var pills: Dictionary = {"pace": pace_pill, "fuel": fuel_pill, "ers": ers_pill}
	var marks: Dictionary = {"pace": pace_mark, "fuel": fuel_mark, "ers": ers_mark}
	for kind: String in rows:
		var ladder: FaderLadder = rows[kind]
		var judged: Array[Dictionary] = []
		var severities: Array[int] = []
		for index: int in range(ladder.buttons.size()):
			var verdict: Dictionary = GtForecast.verdict(kind, index, car, laps)
			judged.append(verdict)
			severities.append(int(verdict["severity"]))
		_verdicts[kind] = judged
		ladder.set_marks(severities)
		var now: int = severities[int(active[kind])]
		(pills[kind] as Label).text = SEVERITY_WORD[now]
		(pills[kind] as Label).add_theme_color_override("font_color", SeverityMark.color_of(now))
		(marks[kind] as SeverityMark).set_severity(now)
	(_numbers["pace"] as Label).text = "%d%%" % roundi((1.0 - car.wear) * 100.0)
	(_numbers["fuel"] as Label).text = "%+.1f" % GtForecast.fuel_margin_laps(car, car.pace_mode, car.fuel_mode, laps)
	(_numbers["ers"] as Label).text = "%d%%" % roundi(car.ers_battery)


## Gauges show the car now; the dashed ghost shows where the option under the cursor (or the active one)
## leaves it at the finish.
func _update_gauges(car: GtCar) -> void:
	var laps: float = GtForecast.laps_left(race, car)
	var total: float = maxf(float(race.laps), 1.0)
	var pace_pick: int = _hover_index if _hover_kind == "pace" else car.pace_mode
	var fuel_pick: int = _hover_index if _hover_kind == "fuel" else car.fuel_mode
	var ers_pick: int = _hover_index if _hover_kind == "ers" else car.ers_mode
	pace_gauge.set_state(1.0 - car.wear, 1.0 - GtTypes.TYRE_CLIFF_WEAR)
	_zones(pace_gauge, 3, 6, ZonedGauge.LIME)
	pace_gauge.set_ghost(float(verdict_for("pace", pace_pick)["projected"]), SeverityMark.color_of(int(verdict_for("pace", pace_pick)["severity"])))
	var burn: float = maxf(GtForecast.burn_per_lap(car, car.pace_mode, car.fuel_mode), 0.01)
	var flag: float = clampf(laps / total, 0.0, 1.0)
	fuel_gauge.set_state(clampf(car.fuel / burn / total, 0.0, 1.0), flag)
	_zones(fuel_gauge, floori(flag * float(ZonedGauge.BLOCKS)), 0, ZonedGauge.LIME)
	var fuel_margin: float = float(verdict_for("fuel", fuel_pick)["projected"])
	fuel_gauge.set_ghost(clampf((fuel_margin + laps) / total, 0.0, 1.0), SeverityMark.color_of(int(verdict_for("fuel", fuel_pick)["severity"])))
	ers_gauge.set_state(car.ers_battery / 100.0, 0.2)
	_zones(ers_gauge, 2, 0, T.ACCENT_PURPLE_SECTOR)
	ers_gauge.set_ghost(float(verdict_for("ers", ers_pick)["projected"]), SeverityMark.color_of(int(verdict_for("ers", ers_pick)["severity"])))


## Blocks below `red_to` are red, below `yellow_to` yellow, the rest `top`.
func _zones(gauge: ZonedGauge, red_to: int, yellow_to: int, top: Color) -> void:
	for index: int in range(ZonedGauge.BLOCKS):
		gauge.zone_colors[index] = SeverityMark.DANGER_COLOR if index < red_to else (SeverityMark.WATCH_COLOR if index < yellow_to else top)


func _forecast_text(car: GtCar) -> String:
	var rate: float = GtForecast.wear_per_lap(car, car.pace_mode)
	var laps: float = GtForecast.laps_left(race, car)
	var cliff: String = "--"
	if rate > 0.0 and car.wear < GtTypes.TYRE_CLIFF_WEAR:
		var to_cliff: float = (GtTypes.TYRE_CLIFF_WEAR - car.wear) / rate
		if to_cliff <= laps:
			cliff = "L%d" % (maxi(car.lap, 0) + roundi(to_cliff))
	return "NEXT LAP > LAP %s - WEAR %.1f%%/lap - CLIFF %s - FUEL %+.1f laps - BATT %d%%" % [
		RaceHud.lap_text(car.last_lap) if car.last_lap >= 0.0 else "--", rate * 100.0, cliff,
		GtForecast.fuel_margin_laps(car, car.pace_mode, car.fuel_mode, laps), roundi(car.ers_battery)]


## BOX WINDOW: the first lap the weather asks for different tyres than the track does now, with a chip per
## coming lap showing the tyre it asks for. 3d replaces this card with the full ladder.
func _update_window(car: GtCar) -> void:
	var weather: GtWeather = race.weather
	var upcoming: Array[Dictionary] = _upcoming(car)
	var now: int = GtForecast.recommended_compound(weather.track_water_pct, weather.rain_intensity)
	var change_at: int = -1
	var change_to: int = now
	for index: int in range(_window_chips.size()):
		var chip: ColorRect = _window_chips[index]
		chip.visible = index < upcoming.size()
		if index >= upcoming.size():
			continue
		var wanted: int = GtForecast.recommended_compound(float(upcoming[index]["water_pct"]), float(upcoming[index]["rain_intensity"]))
		chip.color = GtTypes.COMPOUND_COLOR[wanted]
		if wanted != now and change_at < 0:
			change_at = index
			change_to = wanted
	if change_at >= 0:
		window_label.text = "BOX WINDOW L+%d -> %s" % [maxi(1, change_at), GtTypes.COMPOUND_NAME[change_to]]
	else:
		window_label.text = "NO TYRE CHANGE" if not upcoming.is_empty() else "NO TYRE CHANGE\nweather stable"


## Crimson while the button cancels a call, its own look otherwise.
func _style_box_button(cancelling: bool) -> void:
	if cancelling == _box_cancel_look:
		return
	_box_cancel_look = cancelling
	for state: String in BOX_STYLE_STATES:
		box_button.add_theme_stylebox_override(state, UI.style(T.ACCENT_ANIME_CRIMSON) if cancelling else _box_styles[state])
	var hover_ink: Color = T.TEXT_PRIMARY if cancelling else T.INK_BORDER_BLACK
	box_button.add_theme_color_override("font_hover_color", hover_ink)
	box_button.add_theme_color_override("font_pressed_color", hover_ink)


func _style_tab(index: int, car: GtCar) -> void:
	var status: String = "PIT" if car.pit != null else ("BOX" if car.pit_request >= 0 else ("DNF" if car.is_dnf else GtTypes.COMPOUND_LABEL[car.compound]))
	var text: String = "P%d  #%02d %s   %s %d%%" % [car.position, car.number, car.code, status, roundi(car.wear * 100.0)]
	var active: bool = car.id == deck_car_id
	var key: String = "%s|%s" % [text, active]
	if _tab_text[index] == key:
		return
	_tab_text[index] = key
	var tab: Button = tabs[index]
	tab.text = text
	var box: StyleBoxFlat = UI.style(T.SURFACE_SNAP_INVERT, car.color) if active else UI.style(T.SURFACE_PANEL_ELEVATED, car.color.darkened(0.3))
	box.content_margin_left = 8.0
	box.content_margin_right = 8.0
	box.content_margin_top = 2.0
	box.content_margin_bottom = 2.0
	tab.add_theme_stylebox_override("normal", box)
	tab.add_theme_color_override("font_color", T.INK_BORDER_BLACK if active else T.TEXT_PRIMARY)
