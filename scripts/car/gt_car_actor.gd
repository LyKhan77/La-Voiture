class_name GtCarActor
extends Node3D

## The 3D puppet of one GtCar (FASE 5.6). The sim owns where the car is; this node
## draws it: interpolated between ticks on the ribbon, yawed into lateral moves,
## rolled and pitched by the sim's chassis angles, front wheels steered, all wheels
## rolling, brake rotors glowing under hard braking. The Porsche body is the base chassis
## turned half a turn (the model faces +Z, the ribbon travels along -Z); bind() swaps in the
## team's own chassis (CHASSIS_BY_TEAM) before the wheels and livery go on.

const ModularCarAssembler := preload("res://scripts/car/modular_car_assembler.gd")
const WheelControllerScript := preload("res://scripts/car/wheel_controller.gd")
const Liveries := preload("res://scripts/car/team_liveries.gd")

## Wheel scene per GtTypes.Compound: soft, medium, hard, intermediate, wet.
const WHEEL_SCENES: Array[PackedScene] = [
	preload("res://scenes/car/parts/porsche_wheel_soft.tscn"),
	preload("res://scenes/car/parts/porsche_wheel_medium.tscn"),
	preload("res://scenes/car/parts/porsche_wheel_hard.tscn"),
	preload("res://scenes/car/parts/porsche_wheel_inter.tscn"),
	preload("res://scenes/car/parts/porsche_wheel_wet.tscn"),
]
## Chassis scene per team_id; any team not listed rides the Porsche base chassis the actor scene carries.
const BASE_CHASSIS: PackedScene = preload("res://scenes/car/base_chassis.tscn")
const CHASSIS_BY_TEAM: Dictionary = {
	1: preload("res://scenes/car/audi_r8_chassis.tscn"), # Neon Drift
	2: preload("res://scenes/car/nissan_gtr_chassis.tscn"), # Kurogane GT
	3: preload("res://scenes/car/bmw_m4_chassis.tscn"), # Vanta Motors
	4: preload("res://scenes/car/aston_vantage_chassis.tscn"), # Razorline
	5: preload("res://scenes/car/chevy_corvette_chassis.tscn"), # Zero Hour
	6: preload("res://scenes/car/honda_nsx_chassis.tscn"), # Oni Works
	7: preload("res://scenes/car/lexus_rcf_chassis.tscn"), # Static Speed
	8: preload("res://scenes/car/mclaren_720s_chassis.tscn"), # Chrome Syndicate
	9: preload("res://scenes/car/lambo_huracan_chassis.tscn"), # Night Shift
}
const GRAVITY: float = 9.81
const BRAKE_GLOW_G: float = 1.5
const BRAKE_GLOW_RISE: float = 8.0
const BRAKE_GLOW_FALL: float = 1.2
## Time constant of each of the two cascaded low-passes that turn the sim's 20 Hz steps into body motion.
const BODY_EASE_S: float = 0.07
const LIVERY_TINT: float = 0.6

var car: GtCar
var track: GtTrack
## Unused by the GT sim (it moves pit cars itself); kept so the pit crew can treat any actor alike.
var external_pose: bool = false
var brake_glow: float = 0.0
var steer_visual: float = 0.0

# Roll, pitch, yaw and steer as (first, second) stage of ease2().
var _roll: Vector2 = Vector2.ZERO
var _pitch: Vector2 = Vector2.ZERO
var _yaw: Vector2 = Vector2.ZERO
var _steer: Vector2 = Vector2.ZERO
var wheel_controllers: Array[WheelControllerScript] = []

var _wheel_compound: int = -1
var _livery_team: int = -1

@onready var chassis: ModularCarAssembler = $Chassis
@onready var body: AnimatableBody3D = $Body
@onready var audio: SpatialCarAudio = $SpatialCarAudio

static var _paint_cache: Dictionary = {} # team_id -> ShaderMaterial shared by that team's cars


func bind(p_car: GtCar, p_track: GtTrack) -> void:
	car = p_car
	track = p_track
	_use_chassis_for(car.team_id)
	if _livery_team != car.team_id:
		_livery_team = car.team_id
		_apply_livery(car.team_id)
	mount_wheels(car.compound)
	present(1.0, 0.0)


## Swaps the Chassis child for the one this team rides; the new one keeps the half-turn transform of the old.
func _use_chassis_for(team_id: int) -> void:
	var wanted: PackedScene = CHASSIS_BY_TEAM.get(team_id, BASE_CHASSIS)
	if chassis.scene_file_path == wanted.resource_path:
		return
	var old: ModularCarAssembler = chassis
	var fresh := wanted.instantiate() as ModularCarAssembler
	fresh.transform = old.transform
	old.name = &"ChassisReplaced"
	fresh.name = &"Chassis"
	add_child(fresh)
	move_child(fresh, old.get_index())
	remove_child(old)
	old.queue_free()
	chassis = fresh
	wheel_controllers.clear()


## Fits the four modular wheels for a compound and remembers them for spinning.
func mount_wheels(compound: int) -> void:
	_wheel_compound = clampi(compound, 0, WHEEL_SCENES.size() - 1)
	# Free the old wheels now: a queued free leaves them as extra socket children until the frame ends.
	for socket: Marker3D in _sockets():
		for old: Node in socket.get_children():
			socket.remove_child(old)
			old.queue_free()
	# The assembler only names four compounds; intermediate and wet share its WET name.
	chassis.perform_pitstop_tire_change(WHEEL_SCENES[_wheel_compound], mini(_wheel_compound, ModularCarAssembler.TireCompound.WET) as ModularCarAssembler.TireCompound)
	collect_wheels()


func collect_wheels() -> void:
	wheel_controllers.clear()
	for socket: Marker3D in _sockets():
		if socket != null and socket.get_child_count() > 0:
			var wheel := socket.get_child(0) as WheelControllerScript
			if wheel != null:
				wheel_controllers.append(wheel)


## Called by the pit crew after it swapped all four wheels by hand.
func wheels_swapped(compound: int) -> void:
	_wheel_compound = clampi(compound, 0, WHEEL_SCENES.size() - 1)
	collect_wheels()


func track_distance_m() -> float:
	return fposmod(car.s, track.length) if car != null else 0.0


## Draws the car `alpha` of the way from its previous tick to its current one.
## `spin_scale` keeps the wheels readable at high time scales; `audible` is false when the
## world runs too fast for the engine and tyre voices to make sense.
func present(alpha: float, dt: float, spin_scale: float = 1.0, audible: bool = true) -> void:
	var s: float = lerpf(car.prev_s, car.s, alpha)
	var lateral: float = lerpf(car.prev_lateral, car.lateral, alpha)
	var pose: Transform3D = track.point_at(s, lateral)
	var yaw: float = car.spin_angle
	if car.spin_timer > 0.0:
		_yaw = Vector2(car.yaw_offset, car.yaw_offset) # a spin is drawn raw, the heading resumes from the sim value
	else:
		_yaw = ease2(_yaw, car.yaw_offset, dt)
		yaw = _yaw.y
	pose.basis = pose.basis.rotated(pose.basis.y, -yaw)
	global_transform = pose
	if _wheel_compound != car.compound and car.pit == null:
		mount_wheels(car.compound)
	_tilt_chassis(dt)
	_animate_wheels(dt, spin_scale)
	if audio != null:
		audio.update_from_car(car, audible)


## Roll leans the body to the outside of the corner (+ = right turn), pitch dives the nose under braking.
func _tilt_chassis(dt: float) -> void:
	var spin_roll: float = sin(car.spin_angle * 2.0) * 0.12 if car.spin_timer > 0.0 else 0.0
	var puncture_roll: float = 0.0
	var puncture_pitch: float = 0.0
	if car.is_punctured and car.punctured_wheel >= 0:
		puncture_roll = (-1.0 if car.punctured_wheel == GtTypes.Wheel.FL or car.punctured_wheel == GtTypes.Wheel.RL else 1.0) * 0.065
		puncture_pitch = (1.0 if car.punctured_wheel == GtTypes.Wheel.FL or car.punctured_wheel == GtTypes.Wheel.FR else -1.0) * 0.045
	_roll = ease2(_roll, (0.08 if car.is_dnf else 0.0) + car.chassis_roll + spin_roll + puncture_roll, dt)
	_pitch = ease2(_pitch, (0.0 if car.is_dnf else car.chassis_pitch) + puncture_pitch, dt)
	var roll: float = _roll.y
	var pitch: float = _pitch.y
	var basis := Basis(Vector3(0.0, 0.0, 1.0), roll) * Basis(Vector3(1.0, 0.0, 0.0), -pitch) * Basis(Vector3.UP, PI)
	chassis.transform = Transform3D(basis, chassis.position)


func _animate_wheels(dt: float, spin_scale: float) -> void:
	_steer = ease2(_steer, -car.steer_angle, dt)
	steer_visual = _steer.y
	# The model's front is chassis +Z: FL / FR are the steering corners.
	chassis.socket_wheel_fl.rotation.y = steer_visual
	chassis.socket_wheel_fr.rotation.y = steer_visual
	brake_glow = brake_glow_for(-car.longitudinal_g, brake_glow, dt)
	var rolling: float = car.v * spin_scale
	for wheel: WheelControllerScript in wheel_controllers:
		wheel.set_rolling_speed(rolling)
		wheel.set_brake_glow(brake_glow)


## Two cascaded low-passes: a step becomes an S-curve with no jerk at its start, like a sprung body.
## `stage` is (first, second); the drawn value is the second. dt <= 0 snaps to the target.
static func ease2(stage: Vector2, target: float, dt: float) -> Vector2:
	if dt <= 0.0:
		return Vector2(target, target)
	var k: float = 1.0 - exp(-dt / BODY_EASE_S)
	var first: float = lerpf(stage.x, target, k)
	return Vector2(first, lerpf(stage.y, first, k))


## Rotor heat: appears once braking passes 1.5 G, eases out when the car coasts.
static func brake_glow_for(decel_g: float, current: float, dt: float) -> float:
	if decel_g > BRAKE_GLOW_G:
		var target: float = 0.35 + 0.65 * clampf((decel_g - BRAKE_GLOW_G) / 1.5, 0.0, 1.0)
		return move_toward(current, target, BRAKE_GLOW_RISE * maxf(dt, 0.02))
	return move_toward(current, 0.0, BRAKE_GLOW_FALL * dt)


func _sockets() -> Array[Marker3D]:
	return [chassis.socket_wheel_fl, chassis.socket_wheel_fr, chassis.socket_wheel_rl, chassis.socket_wheel_rr]


func _apply_livery(team_id: int) -> void:
	var body_mesh: MeshInstance3D = chassis.base_body_mesh
	if body_mesh == null or chassis.keeps_original_paint:
		return
	if not _paint_cache.has(team_id):
		var source := body_mesh.get_surface_override_material(0) as ShaderMaterial
		if source == null:
			return
		var paint := source.duplicate() as ShaderMaterial
		paint.set_shader_parameter("base_color", Color.WHITE.lerp(Liveries.color_for(team_id), LIVERY_TINT))
		_paint_cache[team_id] = paint
	body_mesh.set_surface_override_material(0, _paint_cache[team_id])
