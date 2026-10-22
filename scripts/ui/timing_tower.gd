extends Control

## Live timing tower (Zone B). Rows are bound only to real session snapshots;
## no placeholder timing data is ever created.

signal driver_selected(car_id: int)

const UI = preload("res://scripts/ui/pit_wall_ui.gd")
const T = preload("res://scripts/ui/ui_theme_tokens.gd")
const ROW_SCENE = preload("res://scenes/pit_wall/driver_row.tscn")

const ROW_COUNT := 20

@onready var _chrome: Control = $Chrome
@onready var _header_slot: Control = $Body/HeaderSlot
@onready var _rows_box: VBoxContainer = $Body/RowsScroll/Rows
@onready var _col_pos: Label = $Body/ColHeader/Pos
@onready var _col_driver: Label = $Body/ColHeader/Driver
@onready var _col_int: Label = $Body/ColHeader/Int
@onready var _col_t: Label = $Body/ColHeader/Tyre
@onready var _footer_dot: ColorRect = $Body/Footer/Dot
@onready var _footer_status: Label = $Body/Footer/Status

var rows: Array = []
var selected_car_id: int = -1

var _connected := false
var _pending: Array = []

func _ready() -> void:
	UI.surface(_chrome)
	var header := UI.header("LIVE TIMING")
	_header_slot.add_child(header)
	header.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_style_chrome()
	for index: int in range(ROW_COUNT):
		var row = ROW_SCENE.instantiate()
		row.name = "Row%02d" % (index + 1)
		_rows_box.add_child(row)
		row.visible = false
		row.driver_selected.connect(_on_row_selected)
		rows.append(row)
	select_car(selected_car_id)
	if not _pending.is_empty():
		var queued := _pending
		_pending = []
		_apply_standings(queued)

func _style_chrome() -> void:
	for column: Label in [_col_pos, _col_driver, _col_int, _col_t]:
		column.add_theme_font_override("font", UI.MONO)
		column.add_theme_font_size_override("font_size", 10)
		column.add_theme_color_override("font_color", T.TEXT_MUTED)
	_footer_status.add_theme_font_override("font", UI.MONO)
	_footer_status.add_theme_font_size_override("font_size", 10)
	_footer_status.add_theme_color_override("font_color", T.TEXT_MUTED)

func _render_link(connected: bool) -> void:
	if _connected == connected:
		return
	_connected = connected
	_footer_dot.color = T.ACCENT_ACID_LIME if connected else T.TEXT_MUTED
	_footer_status.text = "LINK // LIVE" if connected else "LINK // STANDBY"
	_footer_status.add_theme_color_override("font_color", T.ACCENT_ACID_LIME if connected else T.TEXT_MUTED)

## Feed the tower straight from `RaceSimEngine.get_standings()`. Row slots are
## rebound by position each call, so car IDs always follow the driver.
func update_standings(entries: Array) -> void:
	if not is_node_ready():
		_pending = entries.duplicate()
		return
	_apply_standings(entries)

func _apply_standings(entries: Array) -> void:
	var count: int = mini(entries.size(), rows.size())
	for index: int in range(count):
		var row = rows[index]
		if not row.visible:
			row.visible = true
		row.update_entry(entries[index])
		row.set_selected(selected_car_id >= 0 and int(row.car_id) == selected_car_id)
	for index: int in range(count, rows.size()):
		var row = rows[index]
		if row.visible:
			row.visible = false
		row.set_selected(false)
	_render_link(count > 0)

## Programmatic selection is silent on purpose: the dashboard mirrors the tower
## selection back into select_car() from driver_selected, which would otherwise
## recurse.
func select_car(car_id: int) -> void:
	selected_car_id = car_id
	for row in rows:
		row.set_selected(car_id >= 0 and int(row.car_id) == car_id)

func clear_selection() -> void:
	selected_car_id = -1
	for row in rows:
		row.set_selected(false)

func _on_row_selected(car_id: int) -> void:
	AudioManager.click(self)
	select_car(car_id)
	driver_selected.emit(car_id)

func _unhandled_key_input(event: InputEvent) -> void:
	if not event.is_action_pressed("ui_cancel") or selected_car_id < 0:
		return
	var focus: Control = get_viewport().gui_get_focus_owner()
	if focus == null or not is_ancestor_of(focus):
		return
	clear_selection()
	if get_viewport().gui_get_focus_owner() == focus:
		get_viewport().gui_release_focus()
	get_viewport().set_input_as_handled()
