class_name TacticalDeck
extends Control

## Bottom command strip of the race HUD (the gt-manager tactical deck, drawn in the pit wall
## language), one full-width band under the tower and the telemetry drawer: a tab per car of
## the player team, pace / fuel mix / ERS rows, the next tyre and the box call, the tactic
## desk (manual, auto, hybrid) and the last radio line with the car's stop count. Every
## button writes straight into the GT sim; refresh() mirrors the sim back so keys and the
## AI suggestions show up on the buttons too.

signal car_picked(car_id: int)

const UI = preload("res://scripts/ui/pit_wall_ui.gd")
const T = preload("res://scripts/ui/ui_theme_tokens.gd")

const SIZE_OPEN := Vector2(1888.0, 140.0)
const SIZE_COLLAPSED := Vector2(1888.0, 44.0)
const ROW_1: float = 36.0
const ROW_2: float = 70.0
const ROW_H: float = 28.0
const LABEL_W: float = 44.0
const TACTIC_NAME: Array[String] = ["MANUAL", "AUTO", "HYBRID"]
const TYRE_LABELS: Array[String] = ["AUTO", "S", "M", "H", "I", "W"]

var race: GtRace
var deck_car_id: int = -1
## Compound the next box call asks for, -1 = let the world pick from the track water.
var pit_compound: int = -1
var collapsed: bool = false
var tabs: Array[Button] = []
var pace_row: ModeRow
var fuel_row: ModeRow
var ers_row: ModeRow
var tyre_row: ModeRow
var tactic_row: ModeRow
var box_button: Button
var collapse_button: Button
var info_label: Label
var radio_label: Label

var _world: Node3D
var _body: Control
var _tab_text: Array[String] = ["", ""]
var _ers_before: int = GtTypes.ErsMode.NEUTRAL


func _init() -> void:
	custom_minimum_size = SIZE_OPEN
	size = SIZE_OPEN
	UI.surface(self)
	var header := UI.header("TACTICAL DECK  //  ENGINEER LINK", T.ACCENT_ACID_LIME)
	add_child(header)
	header.position = Vector2(6.0, 6.0)
	header.size = Vector2(SIZE_OPEN.x - 12.0, 28.0)
	_body = Control.new()
	_body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_body)
	_body.position = Vector2.ZERO
	_body.size = SIZE_OPEN
	_build_tabs()
	_build_modes()
	_build_pit()
	_build_tactics()
	_build_radio()


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


func _caption(text: String, at: Vector2) -> void:
	var caption := UI.label(text, 11, T.TEXT_MUTED)
	_body.add_child(caption)
	caption.position = at


## Thin content margins so a button fits a 28 px row.
func _tighten(button: Button) -> void:
	for state: String in ["normal", "hover", "pressed", "focus", "disabled"]:
		var box := button.get_theme_stylebox(state) as StyleBoxFlat
		box.content_margin_left = 8.0
		box.content_margin_right = 8.0
		box.content_margin_top = 2.0
		box.content_margin_bottom = 2.0


func _place(node: Control, at: Vector2, extent: Vector2) -> void:
	_body.add_child(node)
	node.position = at
	node.size = extent


func _build_tabs() -> void:
	for index: int in range(2):
		var tab := UI.button("")
		tab.add_theme_font_size_override("font_size", 15)
		tab.focus_mode = Control.FOCUS_NONE
		_tighten(tab)
		tab.pressed.connect(_on_tab.bind(index))
		_place(tab, Vector2(16.0, ROW_1 + 34.0 * float(index)), Vector2(250.0, ROW_H))
		tabs.append(tab)


func _build_modes() -> void:
	_caption("PACE", Vector2(282.0, ROW_1 + 6.0))
	pace_row = ModeRow.new(GtTypes.PACE_NAME, [T.ACCENT_ELECTRIC_CYAN, T.ACCENT_ELECTRIC_CYAN, T.ACCENT_ACID_LIME, T.ACCENT_CYBER_YELLOW, T.ACCENT_ANIME_CRIMSON], 13)
	pace_row.selected.connect(_on_pace)
	_place(pace_row, Vector2(282.0 + LABEL_W, ROW_1), Vector2(596.0, ROW_H))
	_caption("FUEL", Vector2(282.0, ROW_2 + 6.0))
	fuel_row = ModeRow.new(GtTypes.FUEL_NAME, [T.ACCENT_ELECTRIC_CYAN, T.ACCENT_ACID_LIME, T.ACCENT_ANIME_CRIMSON], 13)
	fuel_row.selected.connect(_on_fuel)
	_place(fuel_row, Vector2(282.0 + LABEL_W, ROW_2), Vector2(220.0, ROW_H))
	_caption("ERS", Vector2(556.0, ROW_2 + 6.0))
	ers_row = ModeRow.new(GtTypes.ERS_NAME, [T.ACCENT_PURPLE_SECTOR, T.ACCENT_ACID_LIME, T.ACCENT_CYBER_YELLOW, T.ACCENT_ANIME_CRIMSON], 13)
	ers_row.selected.connect(_on_ers)
	_place(ers_row, Vector2(556.0 + 38.0, ROW_2), Vector2(328.0, ROW_H))


func _build_pit() -> void:
	_caption("TYRES", Vector2(938.0, ROW_1 + 6.0))
	var tints: Array[Color] = [T.ACCENT_ACID_LIME]
	tints.append_array(GtTypes.COMPOUND_COLOR)
	tyre_row = ModeRow.new(TYRE_LABELS, tints, 14)
	tyre_row.selected.connect(_on_tyre)
	_place(tyre_row, Vector2(938.0 + 50.0, ROW_1), Vector2(362.0, ROW_H))
	box_button = UI.button("BOX THIS LAP")
	box_button.add_theme_font_size_override("font_size", 24)
	box_button.focus_mode = Control.FOCUS_NONE
	box_button.pressed.connect(press_box)
	_place(box_button, Vector2(938.0, ROW_2), Vector2(412.0, 54.0))
	tyre_row.set_active(0)


func _build_tactics() -> void:
	_caption("DESK", Vector2(1366.0, ROW_1 + 6.0))
	tactic_row = ModeRow.new(TACTIC_NAME, [T.TEXT_SECONDARY, T.ACCENT_CYBER_YELLOW, T.ACCENT_ACID_LIME], 13)
	tactic_row.selected.connect(_on_tactic)
	_place(tactic_row, Vector2(1366.0 + 44.0, ROW_1), Vector2(214.0, ROW_H))
	collapse_button = UI.button("FOLD DECK [M]")
	collapse_button.add_theme_font_size_override("font_size", 14)
	collapse_button.focus_mode = Control.FOCUS_NONE
	_tighten(collapse_button)
	collapse_button.pressed.connect(toggle_collapsed)
	_place(collapse_button, Vector2(1366.0, ROW_2), Vector2(258.0, ROW_H))


func _build_radio() -> void:
	_caption("RADIO", Vector2(1640.0, ROW_1 + 2.0))
	radio_label = UI.label("", 12, T.ACCENT_ACID_LIME, UI.RADIO)
	radio_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	radio_label.max_lines_visible = 3
	_place(radio_label, Vector2(1640.0, ROW_1 + 18.0), Vector2(232.0, 50.0))
	info_label = UI.label("", 11, T.TEXT_SECONDARY)
	_place(info_label, Vector2(1640.0, ROW_2 + 32.0), Vector2(232.0, 18.0))


## Last radio line of the engineer, shown at the right end of the strip.
func set_radio(text: String) -> void:
	radio_label.text = text


# --- actions -------------------------------------------------------------------

func _on_tab(index: int) -> void:
	AudioManager.click(self)
	var cars: Array[GtCar] = player_cars()
	if index < cars.size():
		deck_car_id = cars[index].id
		car_picked.emit(deck_car_id)
		refresh()


func _on_pace(index: int) -> void:
	race.set_pace_mode(deck_car_id, index)


func _on_fuel(index: int) -> void:
	race.set_fuel_mode(deck_car_id, index)


func _on_ers(index: int) -> void:
	race.set_ers_mode(deck_car_id, index)


func _on_tactic(index: int) -> void:
	race.set_tactic_mode(index)


func _on_tyre(index: int) -> void:
	pit_compound = index - 1


## Calls the deck car in at the next pit entry for the chosen tyres.
func press_box() -> bool:
	AudioManager.click(self)
	return _world.request_pit(deck_car_id, pit_compound)


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
	var locked: bool = car.pit != null or car.pit_request >= 0 or car.finished_at >= 0.0 or car.is_dnf
	box_button.disabled = locked
	if car.is_dnf:
		box_button.text = "RETIRED"
	elif car.finished_at >= 0.0:
		box_button.text = "CHEQUERED"
	elif car.pit != null:
		box_button.text = "IN THE PIT LANE"
	elif car.pit_request >= 0:
		box_button.text = "BOX CALLED  //  %s" % GtTypes.COMPOUND_NAME[car.pit_request]
	else:
		box_button.text = "BOX THIS LAP"
	info_label.text = "%s %s   STOPS %d   AGE %d L" % [car.code, GtTypes.COMPOUND_NAME[car.compound], car.stops, car.tyre_age_laps]


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
