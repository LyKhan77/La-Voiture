class_name DriverRow
extends Control

## Pit wall timing row. A compact row (30 px): position, number and code, the column value, the team mark and the
## tyre life ring. Every field comes from the standings entry dictionary; an entry without `tyre_life` or `team_id`
## (the old pit wall dashboard) draws a full ring and a neutral mark. Chrome follows the team `style`.

signal driver_selected(car_id: int)

const UI = preload("res://scripts/ui/pit_wall_ui.gd")
const T = preload("res://scripts/ui/ui_theme_tokens.gd")
const Liveries := preload("res://scripts/car/team_liveries.gd")
const GarageStyleScript := preload("res://scripts/ui/manga/garage_style.gd")

const ROW_H_COMPACT: float = 30.0
## The selected row: the 30 px row plus a 16 px strip (sectors, tyre age, stops, gap, last lap, DRS).
const STRIP_H: float = 16.0
const ROW_H_SLAB: float = ROW_H_COMPACT + STRIP_H
const SECTORS := 3
const MINIS_PER_SECTOR := 4
const MINI_DELTAS := SECTORS * MINIS_PER_SECTOR
const COMPOUND_LETTERS: Array[String] = ["S", "M", "H", "W"]
## A team mark under this contrast against the panel gets a light outline.
const MIN_MARK_CONTRAST: float = 3.0
const MARK_SIZE := Vector2(14.0, 6.0)
const LIT_WASH := Color(1.0, 1.0, 1.0, 0.06)
## The old pit wall look (inverted row, 6 px snap) kept for a tower that is given no team style.
const SNAP_OFFSET := 6.0


## Three bars for the three sectors: the height says the colour as well (purple tallest), so colour is not the only cue.
class SectorBars extends Control:
	## Height share by GtTypes.SectorColor (NONE, PURPLE, GREEN, YELLOW).
	const HEIGHTS: Array[float] = [0.15, 1.0, 0.7, 0.4]
	const GAP: float = 2.0

	var colors: Array[int] = [0, 0, 0]
	var edge: Color = T.INK_BORDER_BLACK
	var bar_w: float = 10.0

	func _init(p_height: float = 10.0, p_bar_w: float = 10.0) -> void:
		bar_w = p_bar_w
		custom_minimum_size = Vector2(bar_w * 3.0 + GAP * 2.0, p_height)
		size = custom_minimum_size
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	static func height_of(sector_color: int) -> float:
		return HEIGHTS[clampi(sector_color, 0, HEIGHTS.size() - 1)]

	static func color_of(sector_color: int) -> Color:
		match sector_color:
			GtTypes.SectorColor.PURPLE:
				return T.ACCENT_PURPLE_SECTOR
			GtTypes.SectorColor.GREEN:
				return T.ACCENT_ACID_LIME
			GtTypes.SectorColor.YELLOW:
				return T.ACCENT_CYBER_YELLOW
		return T.TEXT_MUTED

	func set_colors(raw: Array) -> void:
		var next: Array[int] = [0, 0, 0]
		for index: int in range(mini(raw.size(), 3)):
			next[index] = int(raw[index])
		if next == colors:
			return
		colors = next
		queue_redraw()

	func _draw() -> void:
		for index: int in range(3):
			var height: float = size.y * height_of(colors[index])
			var rect := Rect2(float(index) * (bar_w + GAP), size.y - height, bar_w, height)
			draw_rect(rect, color_of(colors[index]))
			draw_rect(rect, edge, false, 1.0)


@onready var _shift: Control = $Shift
@onready var _fill: Panel = $Shift/Fill
@onready var _divider: ColorRect = $Divider
@onready var _pos: Label = $Shift/Pos
@onready var _driver: Label = $Shift/Driver
@onready var _interval: Label = $Shift/Interval

var car_id: int = -1
## The team skin; assign before the row enters the tree. Null = the default lime skin.
var style: GarageStyleScript
## True while the row is the followed car's slab (set by `set_selected`).
var expanded: bool = false

var _ring: TyreLifeRing
var _mark: ColorRect
var _mark_outline: ColorRect
var _selected := false
var _hovered := false
var _lit := false
var _right_color: Color = T.TEXT_SECONDARY
var _plain: StyleBoxEmpty = StyleBoxEmpty.new()
var _lit_box: StyleBoxFlat
var _legacy_lit: bool = false
var _active: StyleBoxFlat
var _sector_line: String = ""
var _entry: Dictionary = {}

## The selected row (the "slab"): the row on the team accent with a strip under it. Hidden until `set_expanded(true)`.
var slab_style: StyleBoxFlat
var _slab: Panel
var _slab_pos: Label
var _slab_code: Label
var _slab_value: Label
var _slab_note: Label
var _slab_drs: Label
var _slab_mark: ColorRect
var _slab_ring: TyreLifeRing
var _slab_bars: SectorBars
var _drs_box: StyleBoxFlat


func _ready() -> void:
	if style == null:
		_legacy_lit = true
		style = GarageStyleScript.new()
	_active = UI.style(T.SURFACE_SNAP_INVERT, T.ACCENT_ACID_LIME, T.INK_BORDER_BLACK)
	_lit_box = StyleBoxFlat.new()
	_lit_box.bg_color = LIT_WASH
	_lit_box.border_width_left = 3
	style.border(_lit_box)
	_build_compact_extras()
	_build_slab()
	_style_text()
	_shift.focus_entered.connect(_on_focus_changed)
	_shift.focus_exited.connect(_on_focus_changed)
	_shift.gui_input.connect(_on_shift_input)
	mouse_entered.connect(_on_hover_changed.bind(true))
	mouse_exited.connect(_on_hover_changed.bind(false))
	_apply_lit(false)


func _build_compact_extras() -> void:
	_mark_outline = ColorRect.new()
	_mark_outline.color = Color(T.TEXT_PRIMARY, 0.85)
	_mark_outline.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_shift.add_child(_mark_outline)
	_anchor_right_middle(_mark_outline, -49.0, -33.0, -4.0, 4.0)
	_mark = ColorRect.new()
	_mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mark_outline.add_child(_mark)
	_mark.position = Vector2(1.0, 1.0)
	_mark.size = MARK_SIZE
	_ring = TyreLifeRing.new(22.0)
	_shift.add_child(_ring)
	_anchor_right_middle(_ring, -30.0, -8.0, -11.0, 11.0)


func _slab_label(parent: Control, at: Vector2, font_size: int, font: Font = UI.MONO, kind: String = "on") -> Label:
	var label: Label = UI.label("", font_size, T.TEXT_PRIMARY, font)
	parent.add_child(label)
	label.position = at
	style.tint(label, "font_color", kind)
	return label


## The slab mirrors the compact row on the accent (position, number and code, column value, team mark, ring) and adds a
## darker strip under it: sector bars, then "S 8L . 2 STOPS . G +1.6 . L 1:26.118" and the DRS tag on the right.
func _build_slab() -> void:
	_slab = Panel.new()
	_slab.name = "Slab"
	_slab.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_slab.visible = false
	slab_style = StyleBoxFlat.new()
	slab_style.shadow_size = 1
	slab_style.shadow_offset = Vector2(4.0, 0.0)
	style.face(slab_style)
	style.shade(slab_style)
	_slab.add_theme_stylebox_override("panel", slab_style)
	add_child(_slab)
	_slab.anchor_right = 1.0
	_slab.anchor_bottom = 1.0
	_slab.offset_right = -6.0
	_slab_pos = _slab_label(_slab, Vector2(8.0, 4.0), 16, UI.DISPLAY)
	_slab_code = _slab_label(_slab, Vector2(40.0, 6.0), 13)
	_slab_value = _slab_label(_slab, Vector2(0.0, 6.0), 13)
	_slab_value.anchor_left = 1.0
	_slab_value.anchor_right = 1.0
	_slab_value.offset_left = -126.0
	_slab_value.offset_right = -58.0
	_slab_value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	var outline := ColorRect.new()
	outline.color = Color(T.INK_BORDER_BLACK, 0.7)
	outline.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_slab.add_child(outline)
	outline.anchor_left = 1.0
	outline.anchor_right = 1.0
	outline.offset_left = -55.0
	outline.offset_right = -39.0
	outline.offset_top = 12.0
	outline.offset_bottom = 20.0
	_slab_mark = ColorRect.new()
	_slab_mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	outline.add_child(_slab_mark)
	_slab_mark.position = Vector2(1.0, 1.0)
	_slab_mark.size = MARK_SIZE
	_slab_ring = TyreLifeRing.new(22.0)
	_slab.add_child(_slab_ring)
	_slab_ring.anchor_left = 1.0
	_slab_ring.anchor_right = 1.0
	_slab_ring.offset_left = -34.0
	_slab_ring.offset_right = -12.0
	_slab_ring.offset_top = 4.0
	_slab_ring.offset_bottom = 26.0
	var strip := ColorRect.new()
	strip.color = Color(0.0, 0.0, 0.0, 0.15)
	strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_slab.add_child(strip)
	strip.anchor_right = 1.0
	strip.offset_top = ROW_H_COMPACT
	strip.offset_bottom = ROW_H_COMPACT + STRIP_H
	_slab_bars = SectorBars.new(10.0, 10.0)
	strip.add_child(_slab_bars)
	_slab_bars.position = Vector2(42.0, 3.0)
	_slab_note = _slab_label(strip, Vector2(86.0, 2.0), 9)
	_slab_note.clip_text = true
	_slab_note.anchor_right = 1.0
	_slab_note.offset_left = 80.0
	_slab_note.offset_right = -44.0
	_slab_drs = UI.label("DRS", 9, T.ACCENT_ACID_LIME, UI.MONO)
	_drs_box = StyleBoxFlat.new()
	_drs_box.bg_color = T.INK_BORDER_BLACK
	_drs_box.content_margin_left = 4.0
	_drs_box.content_margin_right = 4.0
	_slab_drs.add_theme_stylebox_override("normal", _drs_box)
	strip.add_child(_slab_drs)
	_slab_drs.anchor_left = 1.0
	_slab_drs.anchor_right = 1.0
	_slab_drs.offset_left = -40.0
	_slab_drs.offset_right = -12.0
	_slab_drs.position.y = 2.0
	style.changed.connect(_repaint_slab)
	_repaint_slab()


## The sector bars are edged in the type colour of the accent (ink on a light team, white on a dark one).
func _repaint_slab() -> void:
	_slab_bars.edge = style.on_accent
	_slab_bars.queue_redraw()


func _anchor_right_middle(node: Control, left: float, right: float, top: float, bottom: float) -> void:
	node.anchor_left = 1.0
	node.anchor_right = 1.0
	node.anchor_top = 0.5
	node.anchor_bottom = 0.5
	node.offset_left = left
	node.offset_right = right
	node.offset_top = top
	node.offset_bottom = bottom


func _style_text() -> void:
	_pos.add_theme_font_override("font", UI.MONO)
	_pos.add_theme_font_size_override("font_size", 13)
	_driver.add_theme_font_override("font", UI.MONO)
	_driver.add_theme_font_size_override("font_size", 12)
	_interval.add_theme_font_override("font", UI.MONO)
	_interval.add_theme_font_size_override("font_size", 12)


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


## A lit compact row (selected, hovered or focused) gets a soft wash and a team-coloured edge, no colour swap.
func _apply_lit(lit: bool) -> void:
	_divider.visible = not lit
	if _legacy_lit:
		_fill.add_theme_stylebox_override("panel", _active if lit else _plain)
		_shift.position = Vector2(SNAP_OFFSET if lit else 0.0, 0.0)
		_pos.add_theme_color_override("font_color", T.INK_BORDER_BLACK if lit else T.TEXT_SECONDARY)
		_driver.add_theme_color_override("font_color", T.INK_BORDER_BLACK if lit else T.TEXT_PRIMARY)
		_interval.add_theme_color_override("font_color", T.INK_BORDER_BLACK if lit else _right_color)
		return
	_fill.add_theme_stylebox_override("panel", _lit_box if lit else _plain)
	_pos.add_theme_color_override("font_color", T.TEXT_SECONDARY)
	_driver.add_theme_color_override("font_color", T.TEXT_PRIMARY)
	_interval.add_theme_color_override("font_color", _right_color)


func set_selected(active: bool) -> void:
	if _selected == active:
		return
	_selected = active
	if not _legacy_lit:
		set_expanded(active)
	_refresh()


## The followed car's row opens into the slab (and closes back to the compact row). Snaps, no animation.
func set_expanded(on: bool) -> void:
	if expanded == on:
		return
	expanded = on
	custom_minimum_size.y = ROW_H_SLAB if on else ROW_H_COMPACT
	_shift.visible = not on
	_slab.visible = on
	if on:
		_update_slab(_entry)


func _update_slab(entry: Dictionary) -> void:
	if entry.is_empty():
		return
	_slab_pos.text = _pos.text
	_slab_code.text = _driver.text
	_slab_value.text = _interval.text
	var stops: int = int(entry.get("stops", 0))
	_slab_note.text = "%s %dL · %d STOP%s · G %s · L %s" % [_ring.letter, int(entry.get("tyre_age_laps", 0)), stops, "" if stops == 1 else "S",
		String(entry.get("slab_gap", "--")), String(entry.get("slab_last", "--"))]
	_slab_drs.visible = bool(entry.get("drs", false))
	_slab_mark.color = _mark.color
	_slab_ring.set_tyre(_ring.life, _ring.letter, _ring.letter_color)
	_slab_bars.set_colors(entry.get("sector_colors", []))


func update_entry(entry: Dictionary) -> void:
	if entry.is_empty():
		return
	car_id = int(entry.get("car_id", car_id))
	var rank: int = int(entry.get("position", 0))
	_pos.text = "--" if rank <= 0 else "%02d" % rank
	_driver.text = String(entry.get("driver_name", "")).to_upper()
	var interval: float = float(entry.get("interval_s", 0.0))
	_interval.text = "LEAD" if rank <= 1 else "+%.2f" % maxf(interval, 0.0)
	# The race HUD feeds its own right-hand text (PIT, DNF, DRS, lap time) and tyre letter.
	_interval.text = String(entry.get("right_text", _interval.text))
	_right_color = entry.get("right_color", T.TEXT_SECONDARY)
	if not (_legacy_lit and _lit):
		_interval.add_theme_color_override("font_color", _right_color)
	var compound: int = clampi(int(entry.get("compound", 0)), 0, COMPOUND_LETTERS.size() - 1)
	_ring.set_tyre(float(entry.get("tyre_life", 1.0)), String(entry.get("compound_letter", COMPOUND_LETTERS[compound])),
		entry.get("compound_color", _compound_tint(compound)))
	var team: int = int(entry.get("team_id", -1))
	var team_color: Color = Liveries.color_for(team) if team >= 0 else T.TEXT_MUTED
	_mark.color = team_color
	_mark_outline.visible = true
	_mark_outline.color = Color(T.TEXT_PRIMARY, 0.85) if team_mark_needs_outline(team_color) else Color(0.0, 0.0, 0.0, 0.0)
	_sector_line = _sector_text(entry)
	_entry = entry
	if expanded:
		_update_slab(entry)


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


## Aggregate the 12 mini-sector deltas into the three sector deltas (the old pit wall dashboard feeds them).
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


## WCAG relative luminance of an sRGB colour.
static func luminance(color: Color) -> float:
	var linear: Color = color.srgb_to_linear()
	return 0.2126 * linear.r + 0.7152 * linear.g + 0.0722 * linear.b


## WCAG contrast ratio between two colours (1..21).
static func contrast_ratio(a: Color, b: Color) -> float:
	var high: float = maxf(luminance(a), luminance(b))
	var low: float = minf(luminance(a), luminance(b))
	return (high + 0.05) / (low + 0.05)


static func team_mark_needs_outline(team_color: Color) -> bool:
	return contrast_ratio(team_color, T.SURFACE_PANEL_DARK) < MIN_MARK_CONTRAST
