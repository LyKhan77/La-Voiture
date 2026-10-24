class_name TyreWheel
extends Control

## The tyre selector as a wheel: it turns with the car's speed, takes a kick when the compound changes or
## BOX is called (the kick dies away), shakes briefly on a click, and wears a red ring while a pit stop is
## armed. Index 0 is AUTO (engineer's choice); 1..5 are the sim's five compounds.

signal clicked
signal scrolled(direction: int)

const GtTypesScript = preload("res://scripts/gt/gt_types.gd")
const INK := Color("#050505")
const AUTO_COLOR := Color("#CFD8E8")
const ARMED_COLOR := Color("#FF1E56")
const KICK: float = 900.0
const KICK_DECAY_PER_S: float = 3.2
const SHAKE_DECAY_PER_S: float = 7.0
const SPOKES: int = 5

var compound: int = 0
var impulse: float = 0.0
var angle: float = 0.0
var shake: float = 0.0
var speed_kmh: float = 0.0
var armed: bool = false:
	set(value):
		armed = value
		queue_redraw()
## The compound the engineer would fit right now; shown as the rim colour while AUTO is selected.
var auto_hint: int = -1:
	set(value):
		auto_hint = value
		queue_redraw()


func _init() -> void:
	custom_minimum_size = Vector2(96.0, 96.0)
	size = custom_minimum_size
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND


## Degrees per second.
static func spin_velocity(p_speed_kmh: float, p_impulse: float) -> float:
	return p_speed_kmh * 1.6 + p_impulse


static func color_of(index: int, hint: int = -1) -> Color:
	if index <= 0:
		return GtTypesScript.COMPOUND_COLOR[hint] if hint >= 0 else AUTO_COLOR
	return GtTypesScript.COMPOUND_COLOR[index - 1]


func set_compound(index: int, kick: bool) -> void:
	compound = index
	if kick and not PresentationSettings.reduce_motion:
		impulse += KICK
	queue_redraw()


## A click: a short shake. Reduce motion removes it.
func hit() -> void:
	if not PresentationSettings.reduce_motion:
		shake = 1.0


func _process(delta: float) -> void:
	angle = fposmod(angle + deg_to_rad(spin_velocity(speed_kmh, impulse)) * delta, TAU)
	impulse *= exp(-KICK_DECAY_PER_S * delta)
	shake = maxf(0.0, shake - SHAKE_DECAY_PER_S * delta)
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	var mouse := event as InputEventMouseButton
	if mouse == null or not mouse.pressed:
		return
	match mouse.button_index:
		MOUSE_BUTTON_LEFT:
			clicked.emit()
		MOUSE_BUTTON_WHEEL_UP:
			scrolled.emit(1)
		MOUSE_BUTTON_WHEEL_DOWN:
			scrolled.emit(-1)


func _draw() -> void:
	var centre: Vector2 = size * 0.5 + Vector2(sin(shake * 40.0), 0.0) * 3.0 * shake
	var radius: float = minf(size.x, size.y) * 0.5 - 6.0
	var rim: Color = color_of(compound, auto_hint)
	draw_circle(centre, radius + 4.0, ARMED_COLOR if armed else INK)
	draw_circle(centre, radius + 1.0, INK)
	draw_circle(centre, radius, rim)
	for tread: int in range(16):
		var a: float = angle + float(tread) * TAU / 16.0
		draw_line(centre + Vector2.from_angle(a) * (radius - 7.0), centre + Vector2.from_angle(a) * radius, INK, 2.0)
	draw_circle(centre, radius * 0.62, INK)
	for spoke: int in range(SPOKES):
		var a: float = angle + float(spoke) * TAU / float(SPOKES)
		draw_line(centre, centre + Vector2.from_angle(a) * radius * 0.6, rim.darkened(0.15), 4.0)
	draw_circle(centre, radius * 0.16, rim)
	draw_circle(centre, radius * 0.06, INK)
