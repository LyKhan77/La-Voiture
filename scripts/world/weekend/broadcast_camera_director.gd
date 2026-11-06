class_name BroadcastCameraDirector
extends Node

## TV broadcast cameras: C cycles normal views and the active Safety Car.
## HOOD, SIDE and FRONT_TO_REAR sit on the followed car; CarCameraRig measures each body so no lens ends up inside it.
## Automatic pit close-ups and the SC deployment cut restore the chosen view afterwards.

## New modes are appended: other code and tests address the older ones by number.
enum Mode { CHASE, HOOD, HELI, TRACKSIDE_TV, PITSTOP, SAFETY_CAR, SIDE, FRONT_TO_REAR }

const MODE_NAMES: Array[String] = ["CHASE CAM", "HOOD CAM", "HELI CAM", "TRACKSIDE TV", "PIT CLOSE-UP", "SAFETY CAR CAM", "SIDE CAM", "FRONT-TO-REAR CAM"]
const SC_CAM_FOV: float = 65.0
const TrackRibbonScript := preload("res://scripts/car/track_ribbon.gd")
const PitZoneScript := preload("res://scripts/world/shared/pit_zone.gd")

## Normal C cycle; active Safety Car follows TRACKSIDE_TV. PITSTOP is automatic.
const CYCLE: Array[int] = [Mode.CHASE, Mode.HOOD, Mode.SIDE, Mode.FRONT_TO_REAR, Mode.HELI, Mode.TRACKSIDE_TV]

const CHASE_BACK_M: float = 8.5
const CHASE_UP_M: float = 2.6
const CHASE_SMOOTH: float = 7.0
const CHASE_FOV: float = 70.0
const CarCameraRigScript := preload("res://scripts/world/weekend/car_camera_rig.gd")
const HOOD_FOV: float = 82.0
const HOOD_PITCH_DEG: float = 7.0 # looks this far below the horizon so the bonnet fills the bottom of the frame
const SIDE_FOV: float = 62.0
const SIDE_LATERAL_M: float = 2.6 # beyond the car's half width
const SIDE_HEIGHT_M: float = 0.7
const SIDE_ORBIT_RATE: float = 2.5 # the camera swings round the nose to the other side at this ease rate
const SIDE_CURVE_MIN: float = 0.0025 # 1/m; a bend tighter than 400 m radius picks the inside
const SIDE_HOLD_S: float = 1.0 # the new inside must hold this long before the camera swaps (S-bends)
const SIDE_LOOKAHEAD_M: Array[float] = [10.0, 25.0, 40.0, 55.0]
const REAR_FOV: float = 62.0
const REAR_AHEAD_M: float = 4.2 # in front of the nose
const REAR_HEIGHT_M: float = 0.9
const HEADING_EASE: float = 5.0 # side and front-to-rear cameras swing behind the car's heading at this rate
const HELI_RADIUS_M: float = 85.0
const HELI_HEIGHT_M: float = 60.0
const HELI_ORBIT_RAD_S: float = 0.12
const HELI_FOV: float = 55.0
const TV_STATION_SPACING_M: float = 260.0
const TV_LATERAL_M: float = 20.0
const TV_HEIGHT_M: float = 2.4
const TV_CUT_BEHIND_M: float = 35.0 # cut to the next camera once the car is this far past
const TV_FOV: float = 32.0
# From the stopped car, in the stall frame: high over the lane-side front corner of the box, so none of
# the 13 crew around the car (they stand 2-3 m from it) blocks the shot. Within 6 m of the stall (test #26).
const PIT_CAM_OFFSET := Vector3(-2.4, 3.3, -3.8)
const PIT_FOV: float = 55.0
## Boost warp: the lens opens this much in FOV_PUNCH_RISE_S, then eases back over FOV_PUNCH_FALL_S.
const FOV_PUNCH_DEG: float = 3.5
const FOV_PUNCH_RISE_S: float = 0.08
const FOV_PUNCH_FALL_S: float = 0.35

var mode: int = Mode.CHASE
var camera: Camera3D
var target: Node3D
var ribbon: TrackRibbonScript
var _pit_zone: Dictionary = {}
var auto_pit_camera: bool = true
var safety_car_actor: Node3D = null
var safety_car_cut_s: float = 0.0

## Set by the world while a stop runs: the stall's transform, or null when idle.
var pit_focus: Variant = null

var tv_stations: Array[Vector3] = []
var tv_station_s: Array[float] = []
var tv_index: int = 0
var heli_angle: float = 0.0
var clock_s: float = 0.0

var _punch_age_s: float = INF # seconds since punch_fov(); INF when the lens is at rest
var _fov_punch_deg: float = 0.0
var _manual_mode: int = Mode.CHASE
var _snap: bool = true # next update jumps instead of easing, after a cut
var _rig: CarCameraRig = null
var _rig_of: Node3D = null
var _cam_yaw: float = 0.0
var _side: float = 1.0 # +1 right of travel, -1 left
var _side_angle: float = PI * 0.5 # 0 = dead ahead of the nose, +-PI/2 = beside the car
var _side_flip_s: float = 0.0


func setup(p_camera: Camera3D, p_ribbon: TrackRibbonScript, pit_zone: Dictionary = {}) -> void:
	camera = p_camera
	ribbon = p_ribbon
	_pit_zone = pit_zone
	_build_tv_stations()
	set_mode(Mode.CHASE)


func set_target(p_target: Node3D) -> void:
	target = p_target
	_snap = true


## Deployment cut has priority, then the selected car's automatic pit close-up.
func active_mode() -> int:
	if is_instance_valid(safety_car_actor) and safety_car_cut_s > 0.0:
		return Mode.SAFETY_CAR
	if auto_pit_camera and pit_focus != null:
		return Mode.PITSTOP
	if mode == Mode.SAFETY_CAR and not _safety_car_available():
		return Mode.CHASE
	return mode


func _safety_car_available() -> bool:
	return is_instance_valid(safety_car_actor) and safety_car_actor.is_visible_in_tree()


func trigger_safety_car_cut(sc_actor: Node3D, duration_s: float = 4.0) -> void:
	safety_car_actor = sc_actor
	safety_car_cut_s = maxf(0.0, duration_s)
	_snap = true


func set_mode(p_mode: int) -> void:
	mode = p_mode
	_manual_mode = p_mode
	_snap = true


func cycle() -> void:
	if _safety_car_available() and _manual_mode == Mode.TRACKSIDE_TV:
		set_mode(Mode.SAFETY_CAR)
		return
	var index: int = CYCLE.find(_manual_mode)
	set_mode(CYCLE[(index + 1) % CYCLE.size()])


func get_mode_name() -> String:
	return MODE_NAMES[active_mode()]


func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key != null and key.pressed and not key.echo and key.keycode == KEY_C:
		cycle()


## Moves the camera for this frame; call after the cars have moved.
func update(dt: float) -> void:
	if camera == null or target == null:
		return
	clock_s += dt
	_advance_fov_punch(dt)
	match active_mode():
		Mode.CHASE:
			_update_chase(dt)
		Mode.HOOD:
			_update_hood()
		Mode.SIDE:
			_update_side(dt)
		Mode.FRONT_TO_REAR:
			_update_front_to_rear(dt)
		Mode.HELI:
			_update_heli(dt)
		Mode.TRACKSIDE_TV:
			_update_trackside()
		Mode.PITSTOP:
			_update_pit()
		Mode.SAFETY_CAR:
			_update_safety_car(dt)
	safety_car_cut_s = maxf(0.0, safety_car_cut_s - dt)
	_snap = false


func _update_safety_car(dt: float) -> void:
	_set_lens(SC_CAM_FOV, 0.1)
	var pose: Transform3D = safety_car_actor.global_transform
	var wanted: Vector3 = pose.origin - pose.basis.z * 7.2 + pose.basis.x * 2.6 + Vector3.UP * 1.3
	camera.global_position = camera.global_position.lerp(wanted, 1.0 if _snap else 1.0 - exp(-8.0 * dt))
	camera.look_at(pose.origin + Vector3.UP * 0.75, Vector3.UP)


func _update_chase(dt: float) -> void:
	_set_lens(CHASE_FOV, 0.1)
	var pose: Transform3D = target.global_transform
	var wanted: Vector3 = pose.origin + pose.basis.z * CHASE_BACK_M + Vector3.UP * CHASE_UP_M
	camera.global_position = camera.global_position.lerp(wanted, 1.0 if _snap else 1.0 - exp(-CHASE_SMOOTH * dt))
	camera.look_at(pose.origin - pose.basis.z * 6.0 + Vector3.UP * 0.9, Vector3.UP)


## On the bonnet's centre line, just above the highest body point ahead of the eye, so the hood stays in frame.
func _update_hood() -> void:
	_set_lens(HOOD_FOV, 0.05)
	var pose: Transform3D = target.global_transform
	var chassis := target.get("chassis") as Node3D
	var rig: CarCameraRig = _rig_for_target()
	var eye: Vector3 = chassis.to_global(rig.eye) if chassis != null else pose * Vector3(rig.eye.x, rig.eye.y, -rig.eye.z)
	camera.global_position = eye
	camera.look_at(eye - pose.basis.z * 30.0 - Vector3.UP * 30.0 * tan(deg_to_rad(HOOD_PITCH_DEG)), Vector3.UP)


## Low in front of the nose, looking back at the car. The position rides the car exactly; only its heading
## is eased, so the lens swings a little through corners instead of being bolted on.
func _update_front_to_rear(dt: float) -> void:
	_set_lens(REAR_FOV, 0.1)
	var pose: Transform3D = target.global_transform
	_ease_heading(pose, dt)
	var ahead := Vector3(sin(_cam_yaw), 0.0, cos(_cam_yaw))
	camera.global_position = pose.origin + ahead * (_rig_for_target().nose_z + REAR_AHEAD_M) + Vector3.UP * REAR_HEIGHT_M
	camera.look_at(pose.origin + Vector3.UP * 0.7, Vector3.UP)


## Beside the front fender, on the inside of the bend. A change of side orbits round the nose, never through the car.
func _update_side(dt: float) -> void:
	_set_lens(SIDE_FOV, 0.1)
	var pose: Transform3D = target.global_transform
	_ease_heading(pose, dt)
	_choose_side(dt)
	var wanted: float = _side * PI * 0.5
	_side_angle = wanted if _snap else _side_angle + (wanted - _side_angle) * (1.0 - exp(-SIDE_ORBIT_RATE * dt))
	var rig: CarCameraRig = _rig_for_target()
	var ahead := Vector3(sin(_cam_yaw), 0.0, cos(_cam_yaw))
	var right := Vector3(-ahead.z, 0.0, ahead.x)
	# x clears the body beside the car; z clears the nose while the camera is near the centre line.
	var x: float = sin(_side_angle) * (rig.half_width + SIDE_LATERAL_M)
	var z: float = rig.axle_z + (rig.nose_z + 3.0 - rig.axle_z) * pow(cos(_side_angle), 2.0)
	camera.global_position = pose.origin + ahead * z + right * x + Vector3.UP * SIDE_HEIGHT_M
	camera.look_at(pose.origin + ahead * rig.axle_z * 0.3 + Vector3.UP * 0.5, Vector3.UP)


func _ease_heading(pose: Transform3D, dt: float) -> void:
	var yaw: float = atan2(-pose.basis.z.x, -pose.basis.z.z)
	_cam_yaw = yaw if _snap else lerp_angle(_cam_yaw, yaw, 1.0 - exp(-HEADING_EASE * dt))


## Inside of the bend ahead: a left turn (curvature > 0) puts the camera on the left (-1). A swap needs a clear
## bend and SIDE_HOLD_S of it; straights keep the last side.
func _choose_side(dt: float) -> void:
	if ribbon == null:
		return
	var s: float = _target_s()
	var curvature: float = 0.0
	for ahead_m: float in SIDE_LOOKAHEAD_M:
		curvature += ribbon.get_curvature_at(s + ahead_m)
	curvature /= float(SIDE_LOOKAHEAD_M.size())
	if absf(curvature) < SIDE_CURVE_MIN:
		_side_flip_s = 0.0
		return
	var inside: float = -signf(curvature)
	if inside == _side:
		_side_flip_s = 0.0
	elif _snap:
		_side = inside
	else:
		_side_flip_s += dt
		if _side_flip_s >= SIDE_HOLD_S:
			_side = inside
			_side_flip_s = 0.0


func _rig_for_target() -> CarCameraRig:
	if _rig == null or _rig_of != target:
		var chassis := target.get("chassis") as Node3D
		_rig = CarCameraRigScript.measure(chassis) if chassis != null else CarCameraRigScript.new()
		_rig_of = target
	return _rig


func _update_heli(dt: float) -> void:
	_set_lens(HELI_FOV, 0.5)
	heli_angle += HELI_ORBIT_RAD_S * dt
	var around := Vector3(cos(heli_angle), 0.0, sin(heli_angle)) * HELI_RADIUS_M
	var hover: float = HELI_HEIGHT_M + sin(clock_s * 0.6) * 4.0
	var wanted: Vector3 = target.global_position + around + Vector3.UP * hover
	camera.global_position = camera.global_position.lerp(wanted, 1.0 if _snap else 1.0 - exp(-1.5 * dt))
	camera.look_at(target.global_position, Vector3.UP)


## Fixed camera beside the track: the nearest station the car has not yet left
## behind. Cutting happens when the car passes a station by TV_CUT_BEHIND_M.
func _update_trackside() -> void:
	_set_lens(TV_FOV, 0.5)
	tv_index = _station_for(_target_s())
	camera.global_position = tv_stations[tv_index]
	camera.look_at(target.global_position + Vector3.UP * 0.6, Vector3.UP)


func _update_pit() -> void:
	_set_lens(PIT_FOV, 0.05)
	var stall: Transform3D = pit_focus as Transform3D
	var sway: float = sin(clock_s * 0.9) * 0.35
	camera.global_position = stall * (PIT_CAM_OFFSET + Vector3(sway, 0.0, 0.0))
	camera.look_at(stall * Vector3(0.0, 0.45, 0.0), Vector3.UP)


## Kicks the lens wider for a moment (ERS overtake); whichever camera mode runs keeps its own base FOV.
func punch_fov() -> void:
	if PresentationSettings.reduce_motion:
		return
	_punch_age_s = 0.0


func _advance_fov_punch(dt: float) -> void:
	if _punch_age_s == INF:
		return
	_punch_age_s += dt
	if _punch_age_s < FOV_PUNCH_RISE_S:
		_fov_punch_deg = FOV_PUNCH_DEG * (1.0 - pow(2.0, -10.0 * _punch_age_s / FOV_PUNCH_RISE_S)) / (1.0 - pow(2.0, -10.0))
	elif _punch_age_s < FOV_PUNCH_RISE_S + FOV_PUNCH_FALL_S:
		_fov_punch_deg = FOV_PUNCH_DEG * (1.0 - smoothstep(0.0, 1.0, (_punch_age_s - FOV_PUNCH_RISE_S) / FOV_PUNCH_FALL_S))
	else:
		_fov_punch_deg = 0.0
		_punch_age_s = INF


func _set_lens(fov: float, near: float) -> void:
	camera.fov = fov + _fov_punch_deg
	camera.near = near


func _target_s() -> float:
	if target.has_method("track_distance_m"):
		return float(target.call("track_distance_m"))
	return 0.0


## Index of the station that frames a car at arc distance `s`.
func _station_for(s: float) -> int:
	var best: int = 0
	var best_gap: float = INF
	for index: int in range(tv_station_s.size()):
		# Distance from the car to the station along the lap; a car just past the
		# station by less than the cut distance still belongs to it.
		var gap: float = fposmod(tv_station_s[index] - s + TV_CUT_BEHIND_M, ribbon.length_m) - TV_CUT_BEHIND_M
		if gap < best_gap:
			best_gap = gap
			best = index
	return best


func _build_tv_stations() -> void:
	tv_stations.clear()
	tv_station_s.clear()
	var count: int = maxi(1, roundi(ribbon.length_m / TV_STATION_SPACING_M))
	for index: int in range(count):
		var s: float = ribbon.length_m * float(index) / float(count)
		# The garages stand where a camera on the right-hand side would go.
		if PitZoneScript.contains(_pit_zone, s, ribbon.length_m):
			continue
		# Outside of a corner so the camera never sits in the way of a line.
		# Ribbon curvature is + for a left turn, whose outside is the right (+) side.
		var side: float = signf(ribbon.get_curvature_at(s)) if absf(ribbon.get_curvature_at(s)) > 0.002 else 1.0
		var pose: Transform3D = ribbon.get_point_at_offset(s, side * TV_LATERAL_M)
		tv_stations.append(pose.origin + Vector3.UP * TV_HEIGHT_M)
		tv_station_s.append(s)
