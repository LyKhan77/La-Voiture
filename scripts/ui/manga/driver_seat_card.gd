extends Control
## One driver seat of the Team Garage: the portrait pops out of a jagged manga panel over
## speedlines, the broadcast code sits huge across its corner, and the three ratings are drawn as a
## stat constellation (a triangle whose corners are PACE, TIRE CARE and WET SKILL) instead of bars.
## The starting-tyre line of the seat is a real Label (`tyre_line`) in the plate at the bottom.
## Everything team-coloured follows the shared GarageStyle.
const GarageStyle := preload("res://scripts/ui/manga/garage_style.gd")
const T := preload("res://scripts/ui/ui_theme_tokens.gd")
const FONT_MONO := preload("res://assets/fonts/JetBrainsMono.ttf")
const FONT_DISPLAY := preload("res://assets/fonts/Anton.ttf")
const FONT_HEADER := preload("res://assets/fonts/BarlowCondensed.ttf")
const FONT_MARKER := preload("res://assets/fonts/PermanentMarker.ttf")
const INK := Color("#050505")
const FILL := Color(0.055, 0.066, 0.094, 0.96)
const RAY_COLOR := Color("#1b2133")
const PLATE_FILL := Color("#05060a")
const LEAN: float = 0.213 # tan of the -12 degree street lean shared with StreetStyle
const CARD_SIZE := Vector2(430.0, 324.0)
const BACKING_RECT := Rect2(10.0, -14.0, 210.0, 214.0)
const PORTRAIT_RECT := Rect2(16.0, -8.0, 198.0, 202.0)
const RAY_ORIGIN := Vector2(125.0, 151.0)
const RAY_COUNT: int = 45
const RAY_STEP: float = 0.1396 # 8 degrees
const RAY_WIDTH: float = 0.0524 # 3 degrees
const RAY_LENGTH: float = 700.0
const STAR_CENTER := Vector2(322.0, 146.0)
const STAR_RADIUS: float = 70.0
const STAR_ANGLES: Array[float] = [-1.5708, 0.5236, 2.6180]
const PLATE_RECT := Rect2(14.0, 266.0, 402.0, 44.0)
class StatAxis extends RefCounted:
	var short: String = ""
	var value: float = 0.0
	var text: String = ""
var style: GarageStyle
var portrait: Texture2D
var code: String = "---"
var seat_label: String = ""
var kanji: String = ""
var lead: bool = false
var active: bool = false
var axes: Array[StatAxis] = []
var tyre_line: Label
var _backdrop: Control
var _front: Control
func _init(p_style: GarageStyle = null) -> void:
	style = p_style
	custom_minimum_size = CARD_SIZE
	size = CARD_SIZE
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	for index: int in range(3):
		axes.append(StatAxis.new())
func _ready() -> void:
	_backdrop = Control.new()
	_backdrop.name = "Speedlines"
	_backdrop.position = Vector2(4.0, 4.0)
	_backdrop.size = CARD_SIZE - Vector2(8.0, 8.0)
	_backdrop.clip_contents = true
	_backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_backdrop.draw.connect(_draw_backdrop)
	add_child(_backdrop)
	var dots := ColorRect.new()
	dots.name = "Halftone"
	dots.size = Vector2(250.0, _backdrop.size.y)
	dots.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var material := ShaderMaterial.new()
	material.shader = preload("res://shaders/halftone_screentone.gdshader")
	material.set_shader_parameter("dot_spacing", 7.0)
	material.set_shader_parameter("dot_radius", 1.4)
	dots.material = material
	_backdrop.add_child(dots)
	_front = Control.new()
	_front.name = "Front"
	_front.size = CARD_SIZE
	_front.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_front.draw.connect(_draw_front)
	add_child(_front)
	tyre_line = Label.new()
	tyre_line.name = "TyreLine"
	tyre_line.position = PLATE_RECT.position + Vector2(18.0, 12.0)
	tyre_line.size = Vector2(PLATE_RECT.size.x - 40.0, 22.0)
	tyre_line.add_theme_font_override("font", FONT_MONO)
	tyre_line.add_theme_font_size_override("font_size", 13)
	tyre_line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(tyre_line)
	if style != null:
		style.changed.connect(_on_style_changed.bind(material))
		_on_style_changed(material)
func refresh() -> void:
	queue_redraw()
	if _backdrop != null:
		_backdrop.queue_redraw()
		_front.queue_redraw()
func _on_style_changed(material: ShaderMaterial) -> void:
	material.set_shader_parameter("dot_color", Color(style.accent, 0.2))
	refresh()
func _draw() -> void:
	var shadow_offset: Vector2 = Vector2(8.0, 8.0) if active else Vector2(6.0, 6.0)
	draw_rect(Rect2(shadow_offset, size), style.shadow if (active and style != null) else Color.BLACK)
	draw_rect(Rect2(Vector2.ZERO, size), FILL)
	draw_rect(Rect2(Vector2(2.0, 2.0), size - Vector2(4.0, 4.0)), INK, false, 4.0)
func _draw_backdrop() -> void:
	var origin: Vector2 = RAY_ORIGIN - _backdrop.position
	for index: int in range(RAY_COUNT):
		var angle: float = float(index) * RAY_STEP
		_backdrop.draw_colored_polygon(PackedVector2Array([
			origin, origin + Vector2.from_angle(angle) * RAY_LENGTH,
			origin + Vector2.from_angle(angle + RAY_WIDTH) * RAY_LENGTH,
		]), RAY_COLOR)
func _draw_front() -> void:
	var accent: Color = style.accent
	_front.draw_colored_polygon(_pop_polygon(BACKING_RECT), INK)
	var panel: PackedVector2Array = _pop_polygon(PORTRAIT_RECT)
	_front.draw_colored_polygon(panel, accent)
	if portrait != null:
		var uvs := PackedVector2Array()
		for point: Vector2 in panel:
			uvs.append((point - PORTRAIT_RECT.position) / PORTRAIT_RECT.size)
		_front.draw_polygon(panel, PackedColorArray([Color.WHITE, Color.WHITE, Color.WHITE, Color.WHITE]), uvs, portrait)
	if lead:
		_crown(Vector2(36.0, -2.0))
	_code_text()
	_seat_badge()
	if not kanji.is_empty():
		_front.draw_string_outline(FONT_MARKER, Vector2(size.x - 130.0, 36.0), kanji, HORIZONTAL_ALIGNMENT_RIGHT, 114.0, 20, 4, INK)
		_front.draw_string(FONT_MARKER, Vector2(size.x - 130.0, 36.0), kanji, HORIZONTAL_ALIGNMENT_RIGHT, 114.0, 20, T.ACCENT_CYBER_YELLOW)
	_constellation()
	_front.draw_colored_polygon(_skew_polygon(PLATE_RECT), PLATE_FILL)
	_front.draw_polyline(_closed(_skew_polygon(PLATE_RECT)), INK, 3.0, true)
## The jagged comic panel the portrait breaks out of (corners cut, top edge raised).
static func _pop_polygon(r: Rect2) -> PackedVector2Array:
	return PackedVector2Array([
		Vector2(r.position.x + r.size.x * 0.06, r.position.y),
		Vector2(r.end.x, r.position.y + r.size.y * 0.05),
		Vector2(r.position.x + r.size.x * 0.92, r.end.y),
		Vector2(r.position.x, r.position.y + r.size.y * 0.92),
	])
static func _skew_polygon(r: Rect2) -> PackedVector2Array:
	var lean: float = LEAN * r.size.y
	return PackedVector2Array([
		Vector2(r.position.x + lean, r.position.y), Vector2(r.end.x + lean, r.position.y),
		Vector2(r.end.x, r.end.y), Vector2(r.position.x, r.end.y),
	])
static func _closed(points: PackedVector2Array) -> PackedVector2Array:
	var loop := PackedVector2Array(points)
	loop.append(points[0])
	return loop
func _crown(at: Vector2) -> void:
	var points := PackedVector2Array([
		Vector2(3, 32), Vector2(1, 8), Vector2(12, 18), Vector2(22, 2),
		Vector2(32, 18), Vector2(43, 8), Vector2(41, 32),
	])
	_front.draw_set_transform(at, -0.2443, Vector2(1.0, 1.0))
	_front.draw_colored_polygon(points, T.ACCENT_CYBER_YELLOW)
	_front.draw_polyline(_closed(points), INK, 3.0, true)
	_front.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
func _code_text() -> void:
	_front.draw_set_transform(Vector2(44.0, 216.0), -0.0873, Vector2.ONE)
	_front.draw_string(FONT_DISPLAY, Vector2(6.0, 6.0), code, HORIZONTAL_ALIGNMENT_LEFT, -1, 74, style.shadow)
	_front.draw_string_outline(FONT_DISPLAY, Vector2.ZERO, code, HORIZONTAL_ALIGNMENT_LEFT, -1, 74, 10, INK)
	_front.draw_string(FONT_DISPLAY, Vector2.ZERO, code, HORIZONTAL_ALIGNMENT_LEFT, -1, 74, Color.WHITE)
	_front.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
func _seat_badge() -> void:
	var width: float = FONT_HEADER.get_string_size(seat_label, HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x + 32.0
	var rect := Rect2(236.0, 12.0, width, 28.0)
	var plate: PackedVector2Array = _skew_polygon(rect)
	var shadow := PackedVector2Array()
	for point: Vector2 in plate:
		shadow.append(point + Vector2(4.0, 4.0))
	_front.draw_colored_polygon(shadow, Color.BLACK)
	_front.draw_colored_polygon(plate, style.accent)
	_front.draw_polyline(_closed(plate), INK, 3.0, true)
	_front.draw_string(FONT_HEADER, Vector2(rect.position.x + 16.0 + LEAN * 14.0, rect.position.y + 20.0), seat_label,
		HORIZONTAL_ALIGNMENT_LEFT, -1, 18, style.on_accent)
## Triangle of the three ratings. A rating of 70..100 maps onto 30..100 % of the corner distance so
## drivers that are all "very good" still draw visibly different shapes.
func _constellation() -> void:
	var corners := PackedVector2Array()
	var points := PackedVector2Array()
	for index: int in range(3):
		var direction: Vector2 = Vector2.from_angle(STAR_ANGLES[index])
		corners.append(STAR_CENTER + direction * STAR_RADIUS)
		points.append(STAR_CENTER + direction * STAR_RADIUS * _reach(axes[index].value))
	for index: int in range(3):
		_front.draw_dashed_line(corners[index], corners[(index + 1) % 3], Color("#33405e"), 2.0, 6.0)
		_front.draw_line(STAR_CENTER, corners[index], Color("#33405e"), 2.0)
	var shadow := PackedVector2Array()
	for point: Vector2 in points:
		shadow.append(point + Vector2(6.0, 6.0))
	_front.draw_colored_polygon(shadow, style.shadow)
	_front.draw_colored_polygon(points, Color(style.accent, 0.9))
	_front.draw_polyline(_closed(points), INK, 5.0, true)
	for point: Vector2 in points:
		_front.draw_circle(point, 9.0, INK)
		_front.draw_circle(point, 5.5, Color.WHITE)
	var label_at: Array[Vector2] = [
		Vector2(corners[0].x, corners[0].y - 12.0), corners[1] + Vector2(6.0, 22.0), corners[2] + Vector2(-6.0, 22.0),
	]
	for index: int in range(3):
		var text: String = "%s %s" % [axes[index].short, axes[index].text]
		var origin := Vector2(label_at[index].x - 80.0, label_at[index].y)
		_front.draw_string_outline(FONT_MONO, origin, text, HORIZONTAL_ALIGNMENT_CENTER, 160.0, 13, 6, INK)
		_front.draw_string(FONT_MONO, origin, text, HORIZONTAL_ALIGNMENT_CENTER, 160.0, 13, Color.WHITE)
static func _reach(value: float) -> float:
	return clampf(0.3 + (value * 100.0 - 70.0) / 30.0 * 0.7, 0.2, 1.0)
