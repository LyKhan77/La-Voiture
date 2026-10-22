class_name GarageCarOrbit
extends Node

## Turntable orbit camera for the garage. `focus()` swings the pivot to another stall with a
## cubic ease-out dolly while the camera orbits the selected car; left-drag rotates it 360°
## with a clamped elevation, the wheel changes distance, and the camera resets to the hero
## three-quarter angle after a team change. Input is read in `_unhandled_input`, so the
## garage's Buttons and compound selectors always win the click.

const HERO_YAW: float = 0.62
const HERO_PITCH: float = 0.19
const HERO_RADIUS: float = 6.2
const FOCUS_HEIGHT: float = 0.85
const DOLLY_S: float = 0.8
const DRAG_YAW_RATE: float = 0.006
const DRAG_PITCH_RATE: float = 0.005
const ZOOM_STEP: float = 0.7
const MIN_RADIUS: float = 4.0
const MAX_RADIUS: float = 6.5

var camera: Camera3D
var target: Node3D
var drag_enabled: bool = true
var idle_spin_speed: float = 0.0
var min_pitch_deg: float = 2.0
var max_pitch_deg: float = 48.0
var radius: float = HERO_RADIUS

var yaw: float = HERO_YAW
var pitch: float = HERO_PITCH

var _pivot: Vector3 = Vector3.ZERO
var _dolly_from: Vector3 = Vector3.ZERO
var _dolly_to: Vector3 = Vector3.ZERO
var _dolly_from_yaw: float = HERO_YAW
var _dolly_from_pitch: float = HERO_PITCH
var _dolly_from_radius: float = HERO_RADIUS
var _prepare_fraction: float = 0.0
var _dolly_progress: float = 1.0
var _auto_hero_angle: bool = false
var _has_pose: bool = false
var _dragging: bool = false


func setup(p_camera: Camera3D) -> void:
	camera = p_camera


## Moves the turntable to `car`. `instant` skips the cubic-ease dolly.
func focus(car: Node3D, instant: bool = false) -> void:
	if car == null or not is_instance_valid(car) or not car.is_inside_tree():
		return
	target = car
	_dragging = false
	var destination: Vector3 = car.global_position + Vector3(0.0, FOCUS_HEIGHT, 0.0)
	if instant or not _has_pose:
		_pivot = destination
		_dolly_from = destination
		_dolly_to = destination
		_dolly_progress = 1.0
		yaw = HERO_YAW
		pitch = HERO_PITCH
		_auto_hero_angle = true
		_has_pose = true
	else:
		_dolly_from = _pivot
		_dolly_to = destination
		_dolly_from_yaw = yaw
		_dolly_from_pitch = pitch
		_dolly_from_radius = radius
		# Rotate/zoom inside the current stall before crossing any steel partition.
		_prepare_fraction = 0.3 if absf(angle_difference(yaw, HERO_YAW)) > 0.02 or absf(pitch - HERO_PITCH) > 0.02 or absf(radius - HERO_RADIUS) > 0.02 else 0.0
		_dolly_progress = 0.0
		_auto_hero_angle = true
	_update_camera()


## Back to the three-quarter hero angle without moving stalls.
func reset_hero() -> void:
	_auto_hero_angle = false
	yaw = HERO_YAW
	pitch = HERO_PITCH
	radius = HERO_RADIUS
	_update_camera()


func is_dollying() -> bool:
	return _dolly_progress < 1.0


func _process(delta: float) -> void:
	if camera == null or not _has_pose:
		return
	if not is_instance_valid(target):
		target = null
		return
	if _dolly_progress < 1.0:
		_dolly_progress = minf(1.0, _dolly_progress + delta / DOLLY_S)
		var travel: float = clampf((_dolly_progress - _prepare_fraction) / (1.0 - _prepare_fraction), 0.0, 1.0)
		var eased: float = 1.0 - pow(1.0 - travel, 3.0)
		_pivot = _dolly_from.lerp(_dolly_to, eased)
		if _auto_hero_angle:
			var turn: float = minf(1.0, _dolly_progress / maxf(0.001, _prepare_fraction))
			var turn_ease: float = 1.0 - pow(1.0 - turn, 3.0)
			yaw = lerp_angle(_dolly_from_yaw, HERO_YAW, turn_ease)
			pitch = lerpf(_dolly_from_pitch, HERO_PITCH, turn_ease)
			radius = lerpf(_dolly_from_radius, HERO_RADIUS, turn_ease)
	elif idle_spin_speed != 0.0 and not _dragging:
		yaw = wrapf(yaw + idle_spin_speed * delta, -PI, PI)
	_update_camera()


func _update_camera() -> void:
	if camera == null or not _has_pose:
		return
	pitch = clampf(pitch, deg_to_rad(min_pitch_deg), deg_to_rad(max_pitch_deg))
	var offset := Vector3(
		sin(yaw) * cos(pitch),
		sin(pitch),
		cos(yaw) * cos(pitch)
	) * radius
	camera.global_position = _pivot + offset
	camera.look_at(_pivot, Vector3.UP)


func _unhandled_input(event: InputEvent) -> void:
	if camera == null:
		return
	if is_dollying():
		return
	if event is InputEventMouseButton:
		var button := event as InputEventMouseButton
		if button.button_index == MOUSE_BUTTON_LEFT:
			_dragging = button.pressed and drag_enabled
			if _dragging:
				_auto_hero_angle = false
				get_viewport().set_input_as_handled()
		elif button.pressed and button.button_index == MOUSE_BUTTON_WHEEL_UP:
			radius = clampf(radius - ZOOM_STEP, MIN_RADIUS, MAX_RADIUS)
			get_viewport().set_input_as_handled()
		elif button.pressed and button.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			radius = clampf(radius + ZOOM_STEP, MIN_RADIUS, MAX_RADIUS)
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion and _dragging:
		var motion := event as InputEventMouseMotion
		yaw = wrapf(yaw - motion.relative.x * DRAG_YAW_RATE, -PI, PI)
		pitch = clampf(pitch + motion.relative.y * DRAG_PITCH_RATE, deg_to_rad(min_pitch_deg), deg_to_rad(max_pitch_deg))
		_auto_hero_angle = false
		get_viewport().set_input_as_handled()
