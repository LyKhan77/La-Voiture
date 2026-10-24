extends Button
## One starting-tyre pick of the Team Garage, drawn as a spinning wheel. The tread tells the
## compound apart (slicks are smooth, inters shallow, wets deeply grooved), the sidewall ring carries
## the compound colour, and the spin tells the state: idle crawl, fast while hovered or focused, a
## burst when clicked, a steady turn once chosen. A chosen wheel lifts and wears a team-coloured ring
## with a hard shadow; a hazardous one shakes with a crimson ring. `text` stays set ("WET ★") for
## tooltips and tests, but is never drawn by the Button itself.
const GarageStyle := preload("res://scripts/ui/manga/garage_style.gd")
const FONT_MONO := preload("res://assets/fonts/JetBrainsMono.ttf")
const FONT_MARKER := preload("res://assets/fonts/PermanentMarker.ttf")
const INK := Color("#050505")
const TYRE := Color("#0b0b0e")
const GROOVE := Color("#2c303a")
const RIM := Color("#1b2233")
const SPOKE := Color("#aeb6c8")
const HAZARD := Color("#FF1E56")
const BADGE_TEXT: String = "★ CREW PICK!"
const BOX := Vector2(100.0, 100.0)
const RADIUS: float = 38.0
const CENTER := Vector2(50.0, 44.0)
const SPOKE_COUNT: int = 5
const IDLE_SPEED: float = 0.6
const CHOSEN_SPEED: float = 4.5
const HOVER_SPEED: float = 9.0
const BURST_SPEED: float = 26.0
const BURST_TIME: float = 0.5
const SPEED_RAMP: float = 40.0
const LIFT_CHOSEN: float = 6.0
const LIFT_HOVER: float = 4.0
const LIFT_RAMP: float = 60.0
## 0 slick, 1 intermediate, 2 wet.
var tread: int = 0
var tyre_name: String = ""
var tyre_color: Color = Color.WHITE
var style: GarageStyle
var chosen: bool = false
var crew_pick: bool = false
var hazard: bool = false
var _angle: float = 0.0
var _speed: float = IDLE_SPEED
var _burst: float = 0.0
var _lift: float = 0.0
func _init() -> void:
	custom_minimum_size = BOX
	size = BOX
	focus_mode = Control.FOCUS_ALL
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var empty := StyleBoxEmpty.new()
	for state: String in ["normal", "hover", "pressed", "focus", "disabled", "hover_pressed"]:
		add_theme_stylebox_override(state, empty)
	for color_name: String in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color",
			"font_disabled_color", "font_hover_pressed_color"]:
		add_theme_color_override(color_name, Color(0.0, 0.0, 0.0, 0.0))
	pressed.connect(func() -> void: _burst = BURST_TIME)
func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	var hot: bool = is_hovered() or has_focus()
	var target: float = HOVER_SPEED if hot else (CHOSEN_SPEED if chosen else IDLE_SPEED)
	_speed = move_toward(_speed, target, SPEED_RAMP * delta)
	_burst = maxf(0.0, _burst - delta)
	_angle = fposmod(_angle + (_speed + BURST_SPEED * _burst / BURST_TIME) * delta, TAU)
	_lift = move_toward(_lift, LIFT_CHOSEN if chosen else (LIFT_HOVER if hot else 0.0), LIFT_RAMP * delta)
	queue_redraw()
func _draw() -> void:
	var shake: float = sin(float(Time.get_ticks_msec()) * 0.06) * 3.0 if (chosen and hazard) else 0.0
	var c: Vector2 = CENTER + Vector2(shake, -_lift)
	draw_circle(c + Vector2(5.0, 5.0), RADIUS, Color(0.0, 0.0, 0.0, 0.9))
	draw_circle(c, RADIUS, TYRE)
	draw_arc(c, RADIUS - 1.5, 0.0, TAU, 48, INK, 3.0, true)
	match tread:
		2:
			_dashed_ring(c, RADIUS * 0.86, 30, 0.6, 7.0)
			_dashed_ring(c, RADIUS * 0.68, 20, 0.62, 3.0)
		1:
			_dashed_ring(c, RADIUS * 0.86, 16, 0.5, 5.0)
	draw_arc(c, RADIUS * 0.62, 0.0, TAU, 40, tyre_color, 3.5, true)
	draw_circle(c, RADIUS * 0.52, RIM)
	draw_arc(c, RADIUS * 0.52, 0.0, TAU, 32, INK, 2.5, true)
	if _speed + BURST_SPEED * _burst / BURST_TIME > 12.0:
		_spokes(c, -0.18, Color(SPOKE, 0.28))
		_spokes(c, -0.36, Color(SPOKE, 0.14))
	_spokes(c, 0.0, SPOKE)
	draw_circle(c, RADIUS * 0.13, INK)
	draw_circle(c, RADIUS * 0.09, tyre_color)
	if chosen:
		var ring: Color = HAZARD if hazard else (style.accent if style != null else Color.WHITE)
		draw_arc(c + Vector2(4.0, 4.0), RADIUS + 4.0, 0.0, TAU, 48, style.shadow if style != null else HAZARD, 4.0, true)
		draw_arc(c, RADIUS + 4.0, 0.0, TAU, 48, ring, 4.0, true)
	if has_focus():
		draw_arc(c, RADIUS + 10.0, 0.0, TAU, 48, Color.WHITE, 2.0, true)
	draw_string(FONT_MONO, Vector2(0.0, 96.0), tyre_name, HORIZONTAL_ALIGNMENT_CENTER, size.x, 12, tyre_color)
	if crew_pick:
		_crew_badge()
## Blocks of tread around a ring that turn with the wheel; `fill` is the lit share of each pitch.
func _dashed_ring(c: Vector2, radius: float, count: int, fill: float, width: float) -> void:
	var step: float = TAU / float(count)
	for index: int in range(count):
		var start: float = _angle + float(index) * step
		draw_arc(c, radius, start, start + step * fill, 4, GROOVE, width, true)
func _spokes(c: Vector2, angle_offset: float, color: Color) -> void:
	for index: int in range(SPOKE_COUNT):
		var angle: float = _angle + angle_offset + float(index) * TAU / float(SPOKE_COUNT)
		draw_line(c, c + Vector2.from_angle(angle) * RADIUS * 0.44, color, 5.0, true)
func _crew_badge() -> void:
	var text_width: float = FONT_MARKER.get_string_size(BADGE_TEXT, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
	draw_set_transform(Vector2(size.x - 90.0, 12.0), deg_to_rad(12.0), Vector2.ONE)
	var rect := Rect2(0.0, -12.0, text_width + 14.0, 18.0)
	draw_rect(Rect2(rect.position + Vector2(2.0, 2.0), rect.size), INK)
	draw_rect(rect, HAZARD)
	draw_rect(rect, INK, false, 2.0)
	draw_string(FONT_MARKER, Vector2(7.0, 2.0), BADGE_TEXT, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color.WHITE)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
