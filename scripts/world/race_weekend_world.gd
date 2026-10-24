class_name RaceWeekendWorld
extends Node3D

## The race weekend in 3D (FASE 5.5 assembly, FASE 5.6 sim): the GT sim (GtRace, a port
## of gt-manager's race.ts) runs the 20-car race on the 3D circuit with continuous
## lateral positions, the director holds it until the five red lights go out, GtCarActors
## draw the cars between ticks, the pit crew acts out the sim's pit stops, and the
## broadcast cameras, trackside set and the La Voiture race HUD (RaceHud) frame it.
##
## Keys: 1-5 time scale, Left/Right follow a car, C camera, P pit the followed car; the HUD
## adds M deck, T telemetry, Tab tower columns, H hide, E ERS overtake, [ ] pace, N next car.
## Per frame: director -> fixed 20 Hz sim ticks -> actors (interpolated) -> pit crew ->
## cameras and HUD.

const TrackScript := preload("res://scripts/gt/gt_track.gd")
const RaceScript := preload("res://scripts/gt/gt_race.gd")
const CarScript := preload("res://scripts/gt/gt_car.gd")
const WeatherScript := preload("res://scripts/gt/gt_weather.gd")
const Types := preload("res://scripts/gt/gt_types.gd")
const ActorScene := preload("res://scenes/race_world/gt_car_actor.tscn")
const ActorScript := preload("res://scripts/car/gt_car_actor.gd")
const RibbonScript := preload("res://scripts/car/track_ribbon.gd")
const DirectorScript := preload("res://scripts/world/race_weekend_director.gd")
const PitLaneScript := preload("res://scripts/world/pit_lane_complex.gd")
const ChoreographerScript := preload("res://scripts/car/pitstop_choreographer.gd")
const CameraDirectorScript := preload("res://scripts/world/broadcast_camera_director.gd")
const EnvironmentScript := preload("res://scripts/world/track_environment_builder.gd")
const GantryScript := preload("res://scripts/world/start_gantry.gd")
const PodiumScene := preload("res://scenes/ui/podium_screen.tscn")
const ConfigScript := preload("res://scripts/core/race_config_data.gd")
const SettingsScript := preload("res://scripts/core/presentation_settings.gd")

const TIME_SCALES: Array[float] = [1.0, 2.0, 4.0, 8.0, 16.0]
## Engine and tyre voices stay on up to this time scale; faster than that they are just noise.
const AUDIBLE_MAX_TIME_SCALE: float = 2.0
## The podium comes up this long after the chequered flag falls, so the cars get over the line first.
const PODIUM_REVEAL_S: float = 2.5
const HQ_SCENE := "res://scenes/main.tscn"
const MAX_TICKS_PER_FRAME: int = 40
const ROAD_WIDTH_M: float = 14.0
const SKY_TOP := Color(0.36, 0.58, 0.9)
const SKY_HORIZON := Color(0.78, 0.86, 0.95)

@export var total_laps: int = 50
@export var director_seed: int = 0
@export var race_seed: int = 1
## GtWeather.Archetype, or -1 to let the seed choose.
@export var weather_archetype: int = WeatherScript.Archetype.DRY_SUNNY

var track: TrackScript
var race: RaceScript
var director: DirectorScript
var actors: Array[ActorScript] = [] # same order as race.cars
var followed_id: int = 0
var time_scale: float = 1.0
var podium: PodiumScreen

var race_config: ConfigScript
var pre_grid_hold: bool = false
var grid_intro_progress: float = 0.0

var _tick_accumulator: float = 0.0
var _chequered_clock_s: float = -1.0 # seconds since the flag fell, -1 until it does

@onready var ribbon: RibbonScript = $TrackCircuit
@onready var environment: EnvironmentScript = $Environment
@onready var gantry: GantryScript = $StartGantry
@onready var pit_lane: PitLaneScript = $PitLane
@onready var choreographer: ChoreographerScript = $Choreographer
@onready var camera_director: CameraDirectorScript = $CameraDirector
@onready var vfx: RaceVfx = $Vfx
@onready var camera: Camera3D = $Camera3D
@onready var hud: RaceHud = $Hud


func _ready() -> void:
	if race_config == null:
		race_config = ConfigScript.current
	if race_config != null:
		total_laps = race_config.total_laps
		race_seed = race_config.race_seed
		weather_archetype = race_config.weather_archetype(race_seed)
	$Sun.rotation_degrees = Vector3(-52.0, -35.0, 0.0)
	_build_sky()
	track = TrackScript.new(ribbon, ROAD_WIDTH_M)
	race = RaceScript.new(track, total_laps, race_seed, weather_archetype)
	if race_config != null:
		race_config.apply_to_race(race)
	director = DirectorScript.new(director_seed)
	director.lights_out.connect(_on_lights_out)
	director.light_lit.connect(_on_light_lit)
	director.state_changed.connect(_on_director_state)
	gantry.global_transform = ribbon.get_point_on_ribbon(0.0, 1)
	pit_lane.build(ribbon)
	environment.build(ribbon, track.line)
	environment.bind_world($WorldEnvironment, $Sun, camera)
	choreographer.setup(pit_lane, ActorScript.WHEEL_SCENES)
	for car: CarScript in race.cars:
		var actor := ActorScene.instantiate() as ActorScript
		$Actors.add_child(actor)
		actor.bind(car, track)
		actors.append(actor)
	followed_id = race.cars[0].id
	if race_config != null:
		followed_id = race_config.selected_team_id * 2
	camera_director.setup(camera, ribbon)
	camera_director.set_target(actor_of(followed_id))
	vfx.setup(self)
	vfx.update(0.0)
	hud.bind(self)
	if race_config != null:
		SettingsScript.apply_to_tree(self)
	camera_director.update(0.0)
	AudioManager.of(self).start_music()


func _exit_tree() -> void:
	if race != null:
		race.dispose()


## The comic reveal owns the camera and holds the entire start sequence.
func finish_grid_intro() -> void:
	pre_grid_hold = false
	camera_director.set_mode(CameraDirectorScript.Mode.CHASE)
	camera_director.update(0.0)
	director.begin_countdown()


func _update_grid_intro() -> void:
	var actor: ActorScript = actor_of(followed_id)
	var progress: float = clampf(grid_intro_progress, 0.0, 1.0)
	var pose: Transform3D = actor.global_transform
	var above_grandstand: Vector3 = ribbon.get_point_on_ribbon(-190.0, 1).origin + Vector3(35.0, 48.0, 0.0)
	var chase: Vector3 = pose.origin + pose.basis.z * CameraDirectorScript.CHASE_BACK_M + Vector3.UP * CameraDirectorScript.CHASE_UP_M
	camera.global_position = above_grandstand.lerp(chase, progress)
	camera.fov = lerpf(52.0, CameraDirectorScript.CHASE_FOV, progress)
	camera.look_at(pose.origin - pose.basis.z * 6.0 + Vector3.UP * 0.9, Vector3.UP)

func actor_of(car_id: int) -> ActorScript:
	for actor: ActorScript in actors:
		if actor.car.id == car_id:
			return actor
	return null


func set_time_scale(scale: float) -> void:
	time_scale = clampf(scale, 1.0, 16.0)


## Asks a car to box at the next pit entry; the tyre follows the track water.
func request_pit(car_id: int, compound: int = -1) -> bool:
	var car: CarScript = race.get_car(car_id)
	if car == null or car.pit != null or car.pit_request >= 0 or car.finished_at >= 0.0:
		return false
	if compound < 0:
		compound = GtForecast.auto_compound(car, race.weather.track_water_pct)
	race.request_pit(car_id, compound)
	return true


## Withdraws a box call that has not reached the pit lane yet.
func cancel_pit(car_id: int) -> bool:
	return race.cancel_pit(car_id)


func _physics_process(delta: float) -> void:
	step(delta)


## One frame. Public so a test can run the world without waiting for physics frames.
func step(delta: float) -> void:
	if pre_grid_hold:
		for actor: ActorScript in actors:
			actor.present(0.0, delta, 0.0, false)
		_update_grid_intro()
		vfx.update(delta)
		environment.update(delta, race)
		return
	director.advance(delta)
	director.update_race(int(race.race_control["flag"]) == Types.Flag.SC, race.is_finished())
	if director.is_racing():
		_run_ticks(delta)
	var alpha: float = clampf(_tick_accumulator / Types.TICK_DT, 0.0, 1.0)
	var spin_scale: float = minf(time_scale, 2.0)
	var audible: bool = time_scale <= AUDIBLE_MAX_TIME_SCALE and podium == null
	for actor: ActorScript in actors:
		actor.present(alpha, delta, spin_scale, audible)
		_present_pit(actor)
	_update_pit_crews(delta)
	_update_cameras(delta)
	_update_podium(delta)
	vfx.update(delta)
	# After RaceVfx: the set lighting scales the sun, ambient and sky values it just wrote.
	environment.update(delta, race)
	hud.update(delta)


## Fixed 20 Hz ticks, so 1x and 16x run the same sequence.
func _run_ticks(delta: float) -> void:
	if race.is_finished():
		return
	_tick_accumulator += delta * time_scale
	var ticks: int = 0
	while _tick_accumulator >= Types.TICK_DT:
		_tick_accumulator -= Types.TICK_DT
		race.step()
		ticks += 1
		if race.is_finished() or ticks >= MAX_TICKS_PER_FRAME:
			_tick_accumulator = 0.0
			break


## A team's crew steps out of its garage once its car is on the way (a stop is requested and the car is
## within 300 m of Pit Entry, or it is on the approach, in the lane or in its box) and walks back once the
## car has left the box. Cheap: one pass over the cars.
func _update_pit_crews(delta: float) -> void:
	var teams: Array[int] = []
	for car: CarScript in race.cars:
		var coming: bool = false
		if car.pit != null:
			coming = car.pit.phase == Types.PitPhase.ENTRY or car.pit.phase == Types.PitPhase.IN or car.pit.phase == Types.PitPhase.BOX
		elif car.pit_request >= 0 and car.finished_at < 0.0:
			var u: float = fposmod(car.s - PitLaneScript.ENTRY_S + 300.0, ribbon.length_m) - 300.0
			coming = u >= -300.0 and u < 0.0
		if coming and not teams.has(car.team_id):
			teams.append(car.team_id)
	choreographer.set_ready_teams(teams)
	choreographer.advance(delta * clampf(time_scale, 1.0, 8.0))


## The sim runs the stop; the crew acts out its timer, jack height and tyre swap.
func _present_pit(actor: ActorScript) -> void:
	var car: CarScript = actor.car
	var in_box: bool = car.pit != null and car.pit.phase == Types.PitPhase.BOX and car.v < 0.8 and car.pit.timer > 0.0
	if in_box:
		choreographer.present(car.id, car.team_id, actor, car.pit.compound, true, car.pit.wheel_swap_progress, car.pit.lift_y)
	elif choreographer.get_job(car.id) != null:
		choreographer.present(car.id, car.team_id, actor, car.compound, false, 1.0, 0.0)


# --- start lights ----------------------------------------------------------------

func _on_light_lit(count: int) -> void:
	gantry.set_lights(count)


func _on_lights_out() -> void:
	gantry.set_lights(0)


# --- podium ------------------------------------------------------------------------

func _on_director_state(state: int) -> void:
	if state == DirectorScript.State.CHEQUERED_FLAG:
		_chequered_clock_s = 0.0


## Counts down from the chequered flag, then raises the podium once.
func _update_podium(delta: float) -> void:
	if _chequered_clock_s < 0.0 or podium != null:
		return
	_chequered_clock_s += delta
	if _chequered_clock_s >= PODIUM_REVEAL_S:
		show_podium()


func show_podium() -> PodiumScreen:
	if podium == null:
		podium = PodiumScene.instantiate() as PodiumScreen
		add_child(podium)
		podium.restart_requested.connect(_on_restart_requested)
		podium.exit_requested.connect(_on_exit_requested)
	podium.present(race)
	hud.set_shown(false)
	return podium


func _on_restart_requested() -> void:
	get_tree().reload_current_scene()


func _on_exit_requested() -> void:
	ConfigScript.current = null
	get_tree().change_scene_to_file(HQ_SCENE)


# --- cameras -----------------------------------------------------------------------

func _update_cameras(delta: float) -> void:
	var followed: ActorScript = actor_of(followed_id)
	if camera_director.target != followed:
		camera_director.set_target(followed)
	# The pit close-up belongs to the selected car; another car's stop never steals the shot.
	var focus: Variant = null
	for job: ChoreographerScript.Job in choreographer.jobs:
		if job.car_id == followed_id:
			focus = pit_lane.stall_transform(job.team)
			break
	camera_director.pit_focus = focus
	camera_director.update(delta)


func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	if key.keycode >= KEY_1 and key.keycode <= KEY_5:
		set_time_scale(TIME_SCALES[key.keycode - KEY_1])
	elif key.keycode == KEY_RIGHT:
		_follow_offset(1)
	elif key.keycode == KEY_LEFT:
		_follow_offset(-1)
	elif key.keycode == KEY_P:
		request_pit(followed_id)


func _follow_offset(step_size: int) -> void:
	var order: Array[CarScript] = race.standings()
	for index: int in range(order.size()):
		if order[index].id == followed_id:
			followed_id = order[posmod(index + step_size, order.size())].id
			return


# --- environment ---------------------------------------------------------------------

func _build_sky() -> void:
	var world_environment := $WorldEnvironment as WorldEnvironment
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = SKY_TOP
	sky_material.sky_horizon_color = SKY_HORIZON
	sky_material.ground_horizon_color = SKY_HORIZON
	sky_material.ground_bottom_color = Color(0.3, 0.45, 0.3)
	var sky := Sky.new()
	sky.sky_material = sky_material
	var env: Environment = world_environment.environment.duplicate() as Environment
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	world_environment.environment = env

