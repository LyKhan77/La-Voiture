extends Control

## Live timing tower (Zone B). Rows are bound only to real session snapshots;
## no placeholder timing data is ever created.

signal driver_selected(car_id: int)

const UI = preload("res://scripts/ui/pit_wall_ui.gd")
const T = preload("res://scripts/ui/ui_theme_tokens.gd")
const ROW_SCENE = preload("res://scenes/pit_wall/driver_row.tscn")
const GarageStyleScript := preload("res://scripts/ui/manga/garage_style.gd")

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
## The team skin, assigned before the tower enters the tree. Null keeps the old pit wall look (lime header, ink shadow).
var style: GarageStyleScript

var _header_shape: ColorRect
var _header_note: Label
var _shadow: ColorRect

var _connected := false
var _pending: Array = []

func _ready() -> void:
	var themed: bool = style != null
	if not themed:
		style = GarageStyleScript.new()
	UI.surface(_chrome)
	var header := UI.header("LIVE TIMING", style.accent)
	_header_slot.add_child(header)
	header.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_header_shape = header.get_child(0) as ColorRect
	_header_note = UI.label("", 12, style.on_accent)
	header.add_child(_header_note)
	_header_note.anchor_left = 1.0
	_header_note.anchor_right = 1.0
	_header_note.offset_left = -120.0
	_header_note.offset_right = -14.0
	_header_note.offset_top = 5.0
	_header_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	if themed:
		_skin_chrome(header)
	_style_chrome()
	for index: int in range(ROW_COUNT):
		var row = ROW_SCENE.instantiate()
		row.style = style if themed else null
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



## The team skin: a 3 px accent frame, a hard shadow in the skin's shadow colour, the header in the accent with type
## that flips between ink and white. `style.changed` repaints it all in place.
func _skin_chrome(header: Control) -> void:
	var outline := _chrome.get_node("InkOutline") as Panel
	var frame := outline.get_theme_stylebox("panel") as StyleBoxFlat
	frame.set_expand_margin_all(3.0)
	style.face(frame)
	_shadow = _chrome.get_node("HardOffsetShadow") as ColorRect
	style.tint(header.get_child(1) as Label, "font_color", "on")
	style.tint(_header_note, "font_color", "on")
	style.changed.connect(_on_style_changed)
	_on_style_changed()


func _on_style_changed() -> void:
	_shadow.color = style.shadow
	# The Tab column label wears the accent unless that is too dark for the panel.
	var readable: bool = DriverRow.contrast_ratio(style.accent, T.SURFACE_PANEL_DARK) >= DriverRow.MIN_MARK_CONTRAST
	_col_int.add_theme_color_override("font_color", style.accent if readable else T.TEXT_PRIMARY)
	(_header_shape.material as ShaderMaterial).set_shader_parameter("fill_color", style.accent)


## The header's small note on the right (the race HUD writes the lap).
func set_header_note(text: String) -> void:
	_header_note.text = text


func _style_chrome() -> void:
	for column: Label in [_col_pos, _col_driver, _col_int, _col_t]:
		column.add_theme_font_override("font", UI.MONO)
		column.add_theme_font_size_override("font_size", 10)
		column.add_theme_color_override("font_color", T.TEXT_MUTED)
	if style != null and _shadow != null:
		_col_int.add_theme_font_size_override("font_size", 11)
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
