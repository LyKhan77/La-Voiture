extends "res://scripts/car/test_race_world.gd"

## test_race_world plus FASE 5: dynamic weather, safety car and rival pit-wall AI
## driven after every sim tick, wet-asphalt shader on the ribbon, 3D manga rain and
## road spray behind the cars. The base world is untouched; it only supplies the 20-car
## traffic race, its camera and its HUD.

const RaceControlScript := preload("res://scripts/core/race_control.gd")
const TrackWetShader := preload("res://assets/shaders/track_ribbon.gdshader")
const RoadSpray := preload("res://scripts/vfx/manga_road_spray.gd")

const CLEAR_SKY_TOP := Color(0.25, 0.45, 0.80)
const CLEAR_SKY_HORIZON := Color(0.65, 0.75, 0.88)
const STORM_SKY_TOP := Color(0.14, 0.16, 0.20)
const STORM_SKY_HORIZON := Color(0.36, 0.40, 0.46)
const CLEAR_SUN_ENERGY: float = 1.0
const STORM_SUN_ENERGY: float = 0.45
const SSR_MIN_WETNESS: float = 0.1
## Rear of the car in actor space (+Z is the rear), where the spray leaves the road.
const SPRAY_OFFSET := Vector3(0.0, 0.4, 2.2)
## Car speed at which the spray is at full strength.
const SPRAY_FULL_SPEED_MPS: float = 70.0
const FOLLOWED_SPRAY_SHARE: float = 0.3

var control: RaceControlScript
var track_material: ShaderMaterial
var rain_intensity: float = 0.0

var _sky_material: ProceduralSkyMaterial
var _environment: Environment
var _sprays: Array[RoadSpray] = []

@onready var _rain: MangaRain3D = $MangaRain


func _ready() -> void:
	super()
	control = RaceControlScript.new(engine)
	control.weather.set_schedule(RaceControlScript.DEMO_SCHEDULE)
	_build_wet_road()
	_build_sky()
	_build_sprays()
	_update_weather_visuals()


## Base body without its own engine.process_frame(): the RaceControl steps the
## engine so the directors run between ticks.
func _physics_process(delta: float) -> void:
	control.process_frame(delta)
	var sim_dt: float = delta * engine.time_scale
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
	_update_weather_visuals()


func _update_hud() -> void:
	super()
	if control == null:
		return
	var weather := control.weather
	_info.text += "   %s WET %d%% %d C%s" % [
		weather.get_state_name(), roundi(weather.get_wetness_pct() * 100.0), roundi(weather.ambient_temp_c),
		"   SAFETY CAR" if control.safety_car.is_active else "",
	]


func _build_wet_road() -> void:
	var road := _track.get_node("RoadMesh") as MeshInstance3D
	track_material = ShaderMaterial.new()
	track_material.shader = TrackWetShader
	road.material_override = track_material


func _build_sprays() -> void:
	for actor in actors:
		var spray := RoadSpray.new()
		spray.position = SPRAY_OFFSET
		actor.add_child(spray)
		_sprays.append(spray)


## Procedural sky so a wet road has something to reflect; the shared scene
## environment is duplicated rather than edited.
func _build_sky() -> void:
	var world_environment := $WorldEnvironment as WorldEnvironment
	_environment = world_environment.environment.duplicate() as Environment
	_sky_material = ProceduralSkyMaterial.new()
	var sky := Sky.new()
	sky.sky_material = _sky_material
	_environment.background_mode = Environment.BG_SKY
	_environment.sky = sky
	_environment.ssr_max_steps = 96
	_environment.ssr_depth_tolerance = 0.5
	world_environment.environment = _environment


func _update_weather_visuals() -> void:
	var weather := control.weather
	rain_intensity = clampf(sqrt(weather.rain_rate_mm_per_sec / control.weather.RAIN_RATE_MM_PER_SEC[2]), 0.0, 1.0)
	track_material.set_shader_parameter("track_wetness", weather.get_wetness_pct())
	track_material.set_shader_parameter("rain_intensity", rain_intensity)
	_rain.set_intensity(rain_intensity)
	for index: int in range(_sprays.size()):
		# Spray needs water on the road and speed to throw it. The car the chase
		# camera sits behind throws less, or its tail would cover the view.
		var strength: float = weather.get_wetness_pct() * engine.cars[index].speed_mps / SPRAY_FULL_SPEED_MPS
		_sprays[index].set_strength(strength * (FOLLOWED_SPRAY_SHARE if index == followed_index else 1.0))
	# Screen-space reflections only pay off on a wet road: cars mirror in the water.
	_environment.ssr_enabled = weather.get_wetness_pct() > SSR_MIN_WETNESS
	# Overcast follows the water on the road, not only the rain rate, so the sky
	# clears gradually while the track dries.
	var gloom: float = maxf(rain_intensity, weather.get_wetness_pct())
	_sky_material.sky_top_color = CLEAR_SKY_TOP.lerp(STORM_SKY_TOP, gloom)
	_sky_material.sky_horizon_color = CLEAR_SKY_HORIZON.lerp(STORM_SKY_HORIZON, gloom)
	_sky_material.ground_horizon_color = _sky_material.sky_horizon_color
	_sky_material.ground_bottom_color = STORM_SKY_TOP
	$Sun.light_energy = lerpf(CLEAR_SUN_ENERGY, STORM_SUN_ENERGY, gloom)
