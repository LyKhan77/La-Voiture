extends Control

## Pit wall timing row. Color and +6px shift snap in the same input frame.
## Every field comes from the engine's get_standings() entry dictionary.

signal driver_selected(car_id: int)

const UI = preload("res://scripts/ui/pit_wall_ui.gd")
const T = preload("res://scripts/ui/ui_theme_tokens.gd")

const SNAP_OFFSET := 6.0
const SECTORS := 3
const MINIS_PER_SECTOR := 4
const MINI_DELTAS := SECTORS * MINIS_PER_SECTOR
const COMPOUND_LETTERS: Array[String] = ["S", "M", "H", "W"]

@onready var _shift: Control = $Shift
@onready var _fill: Panel = $Shift/Fill
@onready var _hard_shadow: ColorRect = $Shift/HardShadow
@onready var _tick: ColorRect = $Shift/Tick
@onready var _ticker: Label = $Shift/Tick/Ticker
@onready var _divider: ColorRect = $Divider
@onready var _pos: Label = $Shift/Pos
@onready var _driver: Label = $Shift/Driver
@onready var _interval: Label = $Shift/Interval
@onready var _compound: Label = $Shift/Compound

var car_id: int = -1

var _selected := false
var _hovered := false
var _lit := false
var _compound_color: Color = T.TEXT_PRIMARY
var _right_color: Color = T.TEXT_SECONDARY
var _plain: StyleBoxEmpty = StyleBoxEmpty.new()
var _active: StyleBoxFlat

var _ticker_x := 0.0
func _ready() -> void:
	_active = UI.style(T.SURFACE_SNAP_INVERT, T.ACCENT_ACID_LIME, T.INK_BORDER_BLACK)
	_style_text()
	_shift.focus_entered.connect(_on_focus_changed)
	_shift.focus_exited.connect(_on_focus_changed)
	_shift.gui_input.connect(_on_shift_input)
	mouse_entered.connect(_on_hover_changed.bind(true))
	mouse_exited.connect(_on_hover_changed.bind(false))
	_apply_lit(false)

func _style_text() -> void:
	_pos.add_theme_font_override("font", UI.MONO)
	_pos.add_theme_font_size_override("font_size", 13)
	_driver.add_theme_font_override("font", UI.MONO)
	_driver.add_theme_font_size_override("font_size", 12)
	_interval.add_theme_font_override("font", UI.MONO)
	_interval.add_theme_font_size_override("font_size", 12)
	_compound.add_theme_font_override("font", UI.MONO)
	_compound.add_theme_font_size_override("font_size", 13)
	_ticker.add_theme_font_override("font", UI.MONO)
	_ticker.add_theme_font_size_override("font_size", 9)
	_ticker.add_theme_color_override("font_color", T.INK_BORDER_BLACK)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_activate()
		accept_event()

func _on_shift_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept"):
		_activate()
		_shift.accept_event()

func _activate() -> void:
	_shift.grab_focus()
	if car_id >= 0:
		driver_selected.emit(car_id)

func _on_hover_changed(hovered: bool) -> void:
	_hovered = hovered
	_refresh()

func _on_focus_changed() -> void:
	_refresh()

func _refresh() -> void:
	var lit: bool = _selected or _hovered or _shift.has_focus()
	if lit == _lit:
		return
	_lit = lit
	_apply_lit(lit)
	_slide(lit)

func _apply_lit(lit: bool) -> void:
	if lit:
		_fill.add_theme_stylebox_override("panel", _active)
	else:
		_fill.add_theme_stylebox_override("panel", _plain)
	_hard_shadow.visible = lit
	_tick.visible = lit
	_divider.visible = not lit
	var main: Color = T.INK_BORDER_BLACK if lit else T.TEXT_PRIMARY
	var dim: Color = T.INK_BORDER_BLACK if lit else T.TEXT_SECONDARY
	_pos.add_theme_color_override("font_color", dim)
	_driver.add_theme_color_override("font_color", main)
	_interval.add_theme_color_override("font_color", T.INK_BORDER_BLACK if lit else _right_color)
	_apply_compound_color()
	for field: Label in [_pos, _driver, _interval, _compound]:
		field.offset_top = 14.0 if lit else 0.0

func _process(delta: float) -> void:
	if not _lit:
		return
	_ticker_x -= delta * 24.0
	if _ticker_x < -_tick.size.x:
		_ticker_x = _tick.size.x
	_ticker.position.x = 8.0 + _ticker_x

func _apply_compound_color() -> void:
	_compound.add_theme_color_override("font_color", T.INK_BORDER_BLACK if _lit else _compound_color)

func _slide(lit: bool) -> void:
	_shift.position = Vector2(SNAP_OFFSET if lit else 0.0, 0.0)

func set_selected(active: bool) -> void:
	if _selected == active:
		return
	_selected = active
	_refresh()

func update_entry(entry: Dictionary) -> void:
	if entry.is_empty():
		return
	car_id = int(entry.get("car_id", car_id))
	var rank: int = int(entry.get("position", 0))
	_pos.text = "--" if rank <= 0 else "%02d" % rank
	_driver.text = String(entry.get("driver_name", "")).to_upper()
	var interval: float = float(entry.get("interval_s", 0.0))
	_interval.text = "LEAD" if rank <= 1 else "+%.2f" % maxf(interval, 0.0)
	# The race HUD feeds its own right-hand text (PIT, DNF, DRS, sector time) and tyre letter.
	_interval.text = String(entry.get("right_text", _interval.text))
	_right_color = entry.get("right_color", T.TEXT_SECONDARY)
	if not _lit:
		_interval.add_theme_color_override("font_color", _right_color)
	var compound: int = clampi(int(entry.get("compound", 0)), 0, COMPOUND_LETTERS.size() - 1)
	_compound.text = String(entry.get("compound_letter", COMPOUND_LETTERS[compound]))
	_compound_color = entry.get("compound_color", _compound_tint(compound))
	_apply_compound_color()
	_ticker.text = _sector_text(entry)

func _compound_tint(compound: int) -> Color:
	match compound:
		0:
			return T.ACCENT_ANIME_CRIMSON
		1:
			return T.ACCENT_CYBER_YELLOW
		2:
			return T.TEXT_PRIMARY
		_:
			return T.ACCENT_ELECTRIC_CYAN

## Aggregate the 12 mini-sector deltas into the three sector deltas the tower
## shows in the selected row's 14px micro ticker.
func _sector_text(entry: Dictionary) -> String:
	var raw: Variant = entry.get("mini_sector_deltas", null)
	if typeof(raw) != TYPE_PACKED_FLOAT64_ARRAY:
		return ""
	var mini_deltas: PackedFloat64Array = raw
	if mini_deltas.size() < MINI_DELTAS:
		return ""
	var parts := PackedStringArray()
	for sector: int in range(SECTORS):
		var total := 0.0
		for offset: int in range(MINIS_PER_SECTOR):
			total += mini_deltas[sector * MINIS_PER_SECTOR + offset]
		parts.append("S%d %s" % [sector + 1, _signed(total)])
	return "   ".join(parts)

static func _signed(value: float) -> String:
	if value >= 0.0:
		return "+%.2f" % value
	return "-%.2f" % absf(value)
