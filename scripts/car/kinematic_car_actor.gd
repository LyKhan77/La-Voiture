class_name KinematicCarActor
extends Node3D

## Interpolated puppet of one CarState (PRD 00, KinematicCarActor). The sim owns
## where the car is and which lane it takes; this node places the car on the
## ribbon, eases the sideways shift into an S-curve and uses its three rays as a
## safety veto. Nothing here feeds back into the sim, so the race stays
## deterministic at every time scale.
##
## Why the lane choice is not made here: a view layer that picks its own lane
## from ray hits disagrees with the sim's lane plan. Two cars then take the
## same lane and overlap, and the result depends on the render frame rate.
##
## Per physics frame the world calls sense() on every actor first (all rays read
## the same snapshot of the car bodies), then sync_with_sim() on every actor.

const CarStateScript := preload("res://scripts/core/car_state.gd")
const TrackRibbonScript := preload("res://scripts/car/track_ribbon.gd")
const Liveries := preload("res://scripts/car/team_liveries.gd")
const ModularCarAssembler := preload("res://scripts/car/modular_car_assembler.gd")
const WheelControllerScript := preload("res://scripts/car/wheel_controller.gd")

## Wheel scene per sim compound (TireModel.Compound: SOFT, MEDIUM, HARD, WET).
const WHEEL_SCENES: Array[PackedScene] = [
	preload("res://scenes/car/parts/porsche_wheel_soft.tscn"),
	preload("res://scenes/car/parts/porsche_wheel_medium.tscn"),
	preload("res://scenes/car/parts/porsche_wheel_hard.tscn"),
	preload("res://scenes/car/parts/porsche_wheel_wet.tscn"),
]
const GRAVITY: float = 9.81
## Rotors start to glow above this deceleration; the glow eases in and out.
const BRAKE_GLOW_G: float = 1.5
const BRAKE_GLOW_RISE: float = 8.0 # 1/s
const BRAKE_GLOW_FALL: float = 1.2 # 1/s
## Team colour blended into the Porsche paint texture so teams read at a distance.
const LIVERY_TINT: float = 0.6

## The S-curve peaks at 1.5x the sim's 1.4 lanes/s ramp, so a shift still takes
## the same 0.7 s but starts and stops with zero lateral speed.
const LANE_MAX_RATE: float = 2.1 # lanes/s
const OVERTAKE_MIN_SPEED_DELTA: float = 0.2 # m/s faster than the car ahead
## Yaw into a shift is kept small: a yawed 4.6 m car is wider than 2.0 m, and
## cars passing side by side have only ~0.3 m to spare.
const YAW_GAIN: float = 0.25
const MAX_YAW_RAD: float = 0.04
## A side ray only counts when the other car is this close to our centerline:
## half the car width plus 5 cm, i.e. about to touch.
const SIDE_VETO_DISTANCE_M: float = 1.05

var state: CarStateScript
var ribbon: TrackRibbonScript
var distance_scale: float = 1.0
## Visual lane position, 0..2 (see TrackRibbon for the side of each lane).
var lane: float = 1.0
var lane_velocity: float = 0.0 # lanes per sim second
## True while the front ray sees a slower car ahead: the car is on an overtake.
var is_overtaking: bool = false
## Frames in which a side ray stopped a shift toward a car alongside.
var veto_count: int = 0

## Sideways shift added to the lane position in meters (+ = right of travel):
## the racing line and the match collider live here, not in the sim lane.
var extra_lateral_m: float = 0.0
## While true the pit choreographer places the car; the sim lane and the wheel
## animation keep running but the transform is left alone.
var external_pose: bool = false
## 0..1 brake rotor heat; > 0 only after braking harder than 1.5 G.
var brake_glow: float = 0.0

var wheel_controllers: Array[WheelControllerScript] = []

var _front_actor: KinematicCarActor
var _left_blocked: bool = false
var _right_blocked: bool = false
var _livery_team: int = -1
var _wheel_compound: int = -1
var _last_speed_mps: float = -1.0

@onready var body: AnimatableBody3D = $Body
@onready var front_sensor: RayCast3D = $FrontSensor
@onready var left_sensor: RayCast3D = $LeftSensor
@onready var right_sensor: RayCast3D = $RightSensor
@onready var chassis: ModularCarAssembler = $Chassis

static var _paint_cache: Dictionary = {} # team_id -> ShaderMaterial shared by that team's cars


func _ready() -> void:
	for sensor: RayCast3D in [front_sensor, left_sensor, right_sensor]:
		sensor.add_exception(body)
	mount_wheels(0)


## Fits the four modular wheels for a sim tire compound and remembers them for spinning.
func mount_wheels(compound: int) -> void:
	_wheel_compound = clampi(compound, 0, WHEEL_SCENES.size() - 1)
	# Free the old wheels now: a queued free leaves them as extra socket children until the frame ends.
	for socket: Marker3D in [chassis.socket_wheel_fl, chassis.socket_wheel_fr, chassis.socket_wheel_rl, chassis.socket_wheel_rr]:
		for old: Node in socket.get_children():
			socket.remove_child(old)
			old.queue_free()
	chassis.perform_pitstop_tire_change(WHEEL_SCENES[_wheel_compound], _wheel_compound as ModularCarAssembler.TireCompound)
	collect_wheels()


## Re-reads the wheel controllers after the pit crew swapped wheels by hand.
func collect_wheels() -> void:
	wheel_controllers.clear()
	for socket: Marker3D in [chassis.socket_wheel_fl, chassis.socket_wheel_fr, chassis.socket_wheel_rl, chassis.socket_wheel_rr]:
		if socket != null and socket.get_child_count() > 0:
			var wheel := socket.get_child(0) as WheelControllerScript
			if wheel != null:
				wheel_controllers.append(wheel)


## Distance along the ribbon in meters, for cameras and the pit lane.
func track_distance_m() -> float:
	return state.spline_distance * distance_scale if state != null else 0.0


## `sim_track_length_m` is the sim's lap length; the ribbon may differ, so the
## sim's spline_distance is mapped proportionally and lap lines still coincide.
func setup(p_ribbon: TrackRibbonScript, sim_track_length_m: float) -> void:
	ribbon = p_ribbon
	distance_scale = ribbon.length_m / sim_track_length_m


## Reads the three rays. Call on every actor before any actor moves.
func sense() -> void:
	front_sensor.force_raycast_update()
	left_sensor.force_raycast_update()
	right_sensor.force_raycast_update()
	var hit: Object = front_sensor.get_collider()
	_front_actor = (hit.get_parent() as KinematicCarActor) if hit != null else null
	_left_blocked = _touching(left_sensor)
	_right_blocked = _touching(right_sensor)
	is_overtaking = (
		_front_actor != null
		and _front_actor.state != null
		and state != null
		and state.speed_mps - _front_actor.state.speed_mps > OVERTAKE_MIN_SPEED_DELTA
	)


func _touching(sensor: RayCast3D) -> bool:
	return sensor.is_colliding() and sensor.global_position.distance_to(sensor.get_collision_point()) < SIDE_VETO_DISTANCE_M


func sync_with_sim(p_state: CarStateScript, sim_dt: float) -> void:
	if state != p_state:
		state = p_state
		lane = _eased_lane(state.lane_position)
		lane_velocity = 0.0
	if _livery_team != state.team_id:
		_livery_team = state.team_id
		_apply_livery(_livery_team)
	if state.tire_compound != _wheel_compound and not external_pose:
		mount_wheels(state.tire_compound)
	_shift_lane(sim_dt)
	_animate_wheels(sim_dt)
	if not external_pose:
		place()


## Lateral position of the car in meters before the racing-line shift.
func lane_lateral_m() -> float:
	return (lane - 1.0) * TrackRibbonScript.LANE_SPACING_M


## Puts the car on the ribbon at its sim distance, lane and extra lateral shift.
func place() -> void:
	var lateral_m: float = lane_lateral_m() + extra_lateral_m
	var pose: Transform3D = ribbon.get_point_at_offset(state.spline_distance * distance_scale, lateral_m)
	# Yaw into the shift: heading follows lateral velocity over forward speed.
	var forward_mps: float = maxf(state.speed_mps * distance_scale, 10.0)
	var yaw: float = clampf(
		-atan2(lane_velocity * TrackRibbonScript.LANE_SPACING_M, forward_mps) * YAW_GAIN, -MAX_YAW_RAD, MAX_YAW_RAD
	)
	pose.basis = pose.basis.rotated(pose.basis.y, yaw)
	global_transform = pose


func _shift_lane(sim_dt: float) -> void:
	var wanted: float = _eased_lane(state.lane_position)
	# A car alongside on the side we are moving toward freezes the shift.
	if (wanted > lane and _right_blocked) or (wanted < lane and _left_blocked):
		veto_count += 1
		wanted = lane
	var before: float = lane
	lane = move_toward(lane, wanted, LANE_MAX_RATE * sim_dt)
	lane_velocity = (lane - before) / sim_dt if sim_dt > 0.0 else 0.0


## The sim moves lane_position linearly between lanes; smoothstep on the part
## between two lanes gives the same endpoints and a zero-speed start and stop.
func _eased_lane(sim_lane: float) -> float:
	var base: float = floorf(sim_lane)
	return base + smoothstep(0.0, 1.0, sim_lane - base)


## One painted copy of the body material per team, shared by that team's cars.
func _apply_livery(team_id: int) -> void:
	var body_mesh: MeshInstance3D = chassis.base_body_mesh
	if body_mesh == null:
		return
	if not _paint_cache.has(team_id):
		var source := body_mesh.get_surface_override_material(0) as ShaderMaterial
		if source == null:
			return
		var paint := source.duplicate() as ShaderMaterial
		paint.set_shader_parameter("base_color", Color.WHITE.lerp(Liveries.color_for(team_id), LIVERY_TINT))
		_paint_cache[team_id] = paint
	body_mesh.set_surface_override_material(0, _paint_cache[team_id])


## Wheels roll with the car; the rotors heat up when the sim brakes past 1.5 G.
func _animate_wheels(sim_dt: float) -> void:
	var world_speed: float = state.speed_mps * distance_scale
	var decel_g: float = 0.0
	if _last_speed_mps >= 0.0 and sim_dt > 0.0:
		decel_g = (_last_speed_mps - state.speed_mps) / sim_dt / GRAVITY
	_last_speed_mps = state.speed_mps
	brake_glow = brake_glow_for(decel_g, brake_glow, sim_dt)
	for wheel: WheelControllerScript in wheel_controllers:
		wheel.set_rolling_speed(world_speed)
		wheel.set_brake_glow(brake_glow)


## Next glow level: jumps to a visible heat once decel passes 1.5 G, grows with
## harder braking, and cools slowly.
static func brake_glow_for(decel_g: float, current: float, dt: float) -> float:
	if decel_g > BRAKE_GLOW_G:
		var target: float = 0.35 + 0.65 * clampf((decel_g - BRAKE_GLOW_G) / 1.5, 0.0, 1.0)
		return move_toward(current, target, BRAKE_GLOW_RISE * dt)
	return move_toward(current, 0.0, BRAKE_GLOW_FALL * dt)


## Called by the pit crew after it swapped all four wheels by hand.
func wheels_swapped(compound: int) -> void:
	_wheel_compound = clampi(compound, 0, WHEEL_SCENES.size() - 1)
	collect_wheels()
