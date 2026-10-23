class_name BroadcastCameraDirector
extends Node

## TV broadcast cut for the race weekend (FASE 5.5). Five cameras, `C` cycles
## them; while a pit stop is running the close-up pit camera takes over on its own
## and the previous camera comes back afterwards.

enum Mode { CHASE, COCKPIT, HELI, TRACKSIDE_TV, PITSTOP }

const MODE_NAMES: Array[String] = ["CHASE CAM", "COCKPIT CAM", "HELI CAM", "TRACKSIDE TV", "PIT CLOSE-UP"]
const TrackRibbonScript := preload("res://scripts/car/track_ribbon.gd")
const PitLaneScript := preload("res://scripts/world/pit_lane_complex.gd")

## The four cameras the C key cycles through; PITSTOP is automatic.
const CYCLE: Array[int] = [Mode.CHASE, Mode.COCKPIT, Mode.HELI, Mode.TRACKSIDE_TV]

const CHASE_BACK_M: float = 8.5
const CHASE_UP_M: float = 2.6
const CHASE_SMOOTH: float = 7.0
const CHASE_FOV: float = 70.0
const COCKPIT_EYE := Vector3(0.0, 1.05, -0.15) # in the car's frame, -Z forward
const COCKPIT_FOV: float = 88.0
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
var auto_pit_camera: bool = true

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


func setup(p_camera: Camera3D, p_ribbon: TrackRibbonScript) -> void:
	camera = p_camera
	ribbon = p_ribbon
	_build_tv_stations()
	set_mode(Mode.CHASE)


func set_target(p_target: Node3D) -> void:
	target = p_target
	_snap = true


## The mode actually on screen: the pit camera overrides while a stop runs.
func active_mode() -> int:
	if auto_pit_camera and pit_focus != null:
		return Mode.PITSTOP
	return mode


func set_mode(p_mode: int) -> void:
	mode = p_mode
	_manual_mode = p_mode
	_snap = true


func cycle() -> void:
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
		Mode.COCKPIT:
			_update_cockpit()
		Mode.HELI:
			_update_heli(dt)
		Mode.TRACKSIDE_TV:
			_update_trackside()
		Mode.PITSTOP:
			_update_pit()
	_snap = false


func _update_chase(dt: float) -> void:
	_set_lens(CHASE_FOV, 0.1)
	var pose: Transform3D = target.global_transform
	var wanted: Vector3 = pose.origin + pose.basis.z * CHASE_BACK_M + Vector3.UP * CHASE_UP_M
	camera.global_position = camera.global_position.lerp(wanted, 1.0 if _snap else 1.0 - exp(-CHASE_SMOOTH * dt))
	camera.look_at(pose.origin - pose.basis.z * 6.0 + Vector3.UP * 0.9, Vector3.UP)


func _update_cockpit() -> void:
	_set_lens(COCKPIT_FOV, 0.05)
	var pose: Transform3D = target.global_transform
	camera.global_position = pose * COCKPIT_EYE
	camera.look_at(camera.global_position - pose.basis.z * 30.0 + Vector3.UP * 0.2, Vector3.UP)


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
		if fposmod(s - (PitLaneScript.ENTRY_S - 30.0), ribbon.length_m) < PitLaneScript.NOMINAL_LENGTH_M + 60.0:
			continue
		# Outside of a corner so the camera never sits in the way of a line.
		# Ribbon curvature is + for a left turn, whose outside is the right (+) side.
		var side: float = signf(ribbon.get_curvature_at(s)) if absf(ribbon.get_curvature_at(s)) > 0.002 else 1.0
		var pose: Transform3D = ribbon.get_point_at_offset(s, side * TV_LATERAL_M)
		tv_stations.append(pose.origin + Vector3.UP * TV_HEIGHT_M)
		tv_station_s.append(s)
