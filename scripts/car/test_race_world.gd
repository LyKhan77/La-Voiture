extends Node3D

## 20-car test race on the 3-lane ribbon: sim -> actors (3D) + radar (2D).
## Keys: 1-5 = 1x 2x 4x 8x 16x, Left/Right = follow another car.

const Sim := preload("res://scripts/car/traffic_race_sim.gd")
const CarActorScene := preload("res://scenes/race_world/car_actor.tscn")
const ActorScript := preload("res://scripts/car/kinematic_car_actor.gd")
const RibbonScript := preload("res://scripts/car/track_ribbon.gd")
const CarStateScript := preload("res://scripts/core/car_state.gd")

const TIME_SCALES: Array[float] = [1.0, 2.0, 4.0, 8.0, 16.0]
const CAMERA_BACK_M: float = 16.0
const CAMERA_UP_M: float = 6.0
const CAMERA_SMOOTH: float = 6.0
const CAR_LENGTH_M: float = 4.6
const CAR_GAP_M: float = 2.0
const CONTACT_MARGIN_M: float = 0.1

@export var total_laps: int = 50

var engine: Sim
var actors: Array[ActorScript] = []
var followed_index: int = 0

@onready var _track: RibbonScript = $TrackCircuit
@onready var _camera: Camera3D = $Camera3D
@onready var _radar: Control = $Hud/Radar
@onready var _info: Label = $Hud/Info


func _ready() -> void:
	$Sun.rotation_degrees = Vector3(-55.0, -30.0, 0.0)
	engine = Sim.new(total_laps)
	# Cars are 4.6 m long in the world; the ribbon may be shorter than the sim lap.
	var world_per_sim: float = _track.length_m / engine.track_length_m
	engine.min_gap_m = (CAR_LENGTH_M + CAR_GAP_M) / world_per_sim
	engine.contact_gap_m = (CAR_LENGTH_M + CONTACT_MARGIN_M) / world_per_sim
	engine.setup_standard_race(20)
	for car in engine.cars:
		var actor := CarActorScene.instantiate() as ActorScript
		$Actors.add_child(actor)
		actor.setup(_track, engine.track_length_m)
		actor.sync_with_sim(car, 0.0)
		actors.append(actor)
	_radar.set_ribbon(_track, engine.track_length_m)
	_update_camera(1.0)
	_update_hud()


func set_time_scale(scale: float) -> void:
	engine.set_time_scale(scale)


func _physics_process(delta: float) -> void:
	engine.process_frame(delta)
	var sim_dt: float = delta * engine.time_scale
	# Two passes: every ray reads the same snapshot before any car moves.
	for actor in actors:
		actor.sense()
	for i: int in range(actors.size()):
		actors[i].sync_with_sim(engine.cars[i], sim_dt)
	var radar_cars: Array = []
	for car in engine.cars:
		radar_cars.append({"car_id": car.car_id, "team_id": car.team_id, "spline_distance": car.spline_distance})
	_radar.update_snapshot({"cars": radar_cars})
	_update_camera(1.0 - exp(-CAMERA_SMOOTH * delta * engine.time_scale))
	_update_hud()


func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	if key.keycode >= KEY_1 and key.keycode <= KEY_5:
		set_time_scale(TIME_SCALES[key.keycode - KEY_1])
	elif key.keycode == KEY_RIGHT:
		followed_index = posmod(followed_index + 1, actors.size())
	elif key.keycode == KEY_LEFT:
		followed_index = posmod(followed_index - 1, actors.size())


func _update_camera(weight: float) -> void:
	var target: Transform3D = actors[followed_index].global_transform
	var wanted: Vector3 = target.origin + target.basis.z * CAMERA_BACK_M + Vector3.UP * CAMERA_UP_M
	_camera.global_position = _camera.global_position.lerp(wanted, weight)
	_camera.look_at(target.origin + Vector3.UP, Vector3.UP)


func _update_hud() -> void:
	var car: CarStateScript = engine.cars[followed_index]
	_info.text = "TIME x%d   CAR #%02d   LAP %d/%d   %3d KM/H   [1-5] SPEED  [</>] CAR" % [
		int(engine.time_scale), followed_index + 1, car.lap_number, total_laps, roundi(car.get_speed_kmh())
	]
