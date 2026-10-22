class_name CircuitLightingController
extends Node

## Ties the circuit's own lights to the race's time of day (FASE 10). RaceVfx already moves
## the sun, ambient light and sky from GtWeather's time-of-day table (and PresentationSettings owns
## shadow quality and softness); this adds what belongs to the set: depth fog tuned to the sky, the 28 floodlight towers (emissive lenses on every
## merged mesh plus a pool of real spot lights that follow the camera), warm lounge windows,
## the Jumbotron and braking boards at night, the mountain haze and stars, and foliage sway
## from the weather's wind.

const ToonMaterials := preload("res://scripts/world/toon_materials.gd")
const TracksideFurnitureScript := preload("res://scripts/world/trackside_furniture_builder.gd")
const MountainVistaScript := preload("res://scripts/world/mountain_vista.gd")
const FoliageScript := preload("res://scripts/world/foliage_scatter.gd")
const GrandstandScript := preload("res://scripts/world/paddock/main_grandstand.gd")

## Emission multiplier of a fully lit (alpha 0) floodlight lens at night.
const GLOW_NIGHT: float = 4.0
const GLASS_NIGHT: float = 1.1
const SCREEN_NIGHT_BOOST: float = 0.35
const MARKER_NIGHT_BRIGHTNESS: float = 0.55
## Real spot lights: the nearest towers to the camera carry them.
const SPOT_POOL: int = 6
const SPOT_RANGE_M: float = 100.0
const SPOT_ANGLE_DEG: float = 62.0
const SPOT_ENERGY: float = 5.0
const SPOT_HEAD_HEIGHT_M: float = 17.2
const SPOT_COLOR := Color(1.0, 0.93, 0.8)
const SPOT_REFRESH_S: float = 0.25
## Depth fog: density per mode (day, sunset, night) and the extra thickness of a storm.
const FOG_DENSITY_DAY: float = 0.00018
const FOG_DENSITY_SUNSET: float = 0.00026
const FOG_DENSITY_NIGHT: float = 0.00032
const FOG_STORM_EXTRA: float = 0.00045
const FOG_SKY_AFFECT: float = 0.15
## Foliage sway (meters at the crest) at a calm 3 km/h and a 45 km/h gale; gust speed in rad/s.
const WIND_CALM_KPH: float = 3.0
const WIND_GALE_KPH: float = 45.0
const SWAY_CALM_M: float = 0.05
const SWAY_GALE_M: float = 0.34
const SWAY_SPEED_CALM: float = 1.2
const SWAY_SPEED_GALE: float = 3.4
## Night is darker than the weather table alone makes it: RaceVfx writes ambient, moon and sky
## values every frame, and this controller scales them right after, so the floodlights read as the main light.
const NIGHT_AMBIENT_SCALE: float = 0.5
const NIGHT_MOON_SCALE: float = 0.6
const NIGHT_HORIZON_DARKEN: float = 0.6
const CHANGE_EPSILON: float = 0.002

## 0..1 floodlight level from the time-of-day table (0 day, 1 night).
var floodlight_level: float = 0.0
var active_lights: Array[SpotLight3D] = []

var _furniture: TracksideFurnitureScript
var _vista: MountainVistaScript
var _foliage: FoliageScript
var _grandstand: GrandstandScript
var _world_environment: WorldEnvironment
var _sun: DirectionalLight3D
var _camera: Camera3D
var _ribbon: TrackRibbon
var _spot_clock_s: float = SPOT_REFRESH_S
var _last_level: float = -1.0
var _last_wind: float = -1.0


func bind(
	ribbon: TrackRibbon, furniture: TracksideFurnitureScript, vista: MountainVistaScript, foliage: FoliageScript,
	grandstand: GrandstandScript, world_environment: WorldEnvironment, sun: DirectionalLight3D, camera: Camera3D
) -> void:
	_ribbon = ribbon
	_furniture = furniture
	_vista = vista
	_foliage = foliage
	_grandstand = grandstand
	_world_environment = world_environment
	_sun = sun
	_camera = camera
	for index: int in range(SPOT_POOL):
		var spot := SpotLight3D.new()
		spot.name = "FloodSpot%d" % index
		spot.light_color = SPOT_COLOR
		spot.spot_range = SPOT_RANGE_M
		spot.spot_angle = SPOT_ANGLE_DEG
		spot.spot_attenuation = 0.8
		# PresentationSettings switches shadows on for every light; these must stay shadowless (6 spot shadow maps are too dear).
		spot.shadow_enabled = false
		spot.set_meta(&"no_shadow", true)
		spot.light_energy = 0.0
		spot.visible = false
		add_child(spot)
		active_lights.append(spot)


## `tod` is GtWeather.time_of_day; `gloom` (0..1) the rain and wetness gloom RaceVfx uses; `wind_kph` the live wind.
func apply(tod: Dictionary, gloom: float, wind_kph: float, delta: float) -> void:
	floodlight_level = clampf(float(tod["floodlights"]), 0.0, 1.0)
	if absf(floodlight_level - _last_level) > CHANGE_EPSILON:
		_last_level = floodlight_level
		_apply_floodlit_set()
	var env: Environment = _world_environment.environment
	var horizon: Color = _darken_night(env)
	_apply_fog(env, tod, gloom, horizon)
	_vista.set_time_of_day(tod, horizon, _sun.light_color, gloom)
	if absf(wind_kph - _last_wind) > 0.5:
		_last_wind = wind_kph
		var gale: float = inverse_lerp(WIND_CALM_KPH, WIND_GALE_KPH, wind_kph)
		_foliage.set_wind(lerpf(SWAY_CALM_M, SWAY_GALE_M, clampf(gale, 0.0, 1.0)), lerpf(SWAY_SPEED_CALM, SWAY_SPEED_GALE, clampf(gale, 0.0, 1.0)))
	_spot_clock_s += delta
	if _spot_clock_s >= SPOT_REFRESH_S:
		_spot_clock_s = 0.0
		_place_spot_lights()


## Everything that follows the floodlight level: lenses, windows, boards, the screen.
func _apply_floodlit_set() -> void:
	ToonMaterials.set_glow_energy(floodlight_level * GLOW_NIGHT)
	ToonMaterials.glass().emission_energy_multiplier = floodlight_level * GLASS_NIGHT
	if _grandstand != null:
		_grandstand.jumbotron.set_brightness(1.0 + SCREEN_NIGHT_BOOST * floodlight_level)
	if _furniture.marker_face_material != null:
		_furniture.marker_face_material.set_shader_parameter("board_brightness", lerpf(1.0, MARKER_NIGHT_BRIGHTNESS, floodlight_level))


## Dims ambient light, moon and sky horizon with the floodlight level (they were just rewritten by
## RaceVfx this frame, so this never compounds) and returns the resulting horizon colour.
func _darken_night(env: Environment) -> Color:
	var horizon: Color = _horizon_color(env).darkened(NIGHT_HORIZON_DARKEN * floodlight_level)
	if env.sky != null and env.sky.sky_material is ProceduralSkyMaterial:
		var sky := env.sky.sky_material as ProceduralSkyMaterial
		sky.sky_horizon_color = horizon
		sky.ground_horizon_color = horizon
	env.ambient_light_energy *= lerpf(1.0, NIGHT_AMBIENT_SCALE, floodlight_level)
	_sun.light_energy *= lerpf(1.0, NIGHT_MOON_SCALE, floodlight_level)
	return horizon


## Sky horizon colour as RaceVfx last set it (falls back to the background colour without a sky).
func _horizon_color(env: Environment) -> Color:
	if env.sky != null and env.sky.sky_material is ProceduralSkyMaterial:
		return (env.sky.sky_material as ProceduralSkyMaterial).sky_horizon_color
	return env.background_color


func _apply_fog(env: Environment, tod: Dictionary, gloom: float, horizon: Color) -> void:
	var altitude: float = float(tod["sun_altitude"])
	var base: float = FOG_DENSITY_DAY
	if floodlight_level >= 0.99:
		base = FOG_DENSITY_NIGHT
	elif altitude < 0.45:
		base = lerpf(FOG_DENSITY_SUNSET, FOG_DENSITY_DAY, clampf(inverse_lerp(0.28, 0.65, altitude), 0.0, 1.0))
	env.fog_enabled = true
	env.fog_light_color = horizon
	env.fog_density = base + FOG_STORM_EXTRA * gloom
	env.fog_sky_affect = FOG_SKY_AFFECT


## Hands the spot lights to the towers nearest the camera; off when the floodlights are off.
func _place_spot_lights() -> void:
	var on: bool = floodlight_level > 0.02
	for spot: SpotLight3D in active_lights:
		spot.visible = on
		spot.light_energy = SPOT_ENERGY * floodlight_level if on else 0.0
	if not on or _camera == null:
		return
	var records: Array[Dictionary] = _furniture.tower_records.duplicate()
	var eye: Vector3 = _camera.global_position
	records.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return (a["position"] as Vector3).distance_squared_to(eye) < (b["position"] as Vector3).distance_squared_to(eye))
	for index: int in range(mini(SPOT_POOL, records.size())):
		var record: Dictionary = records[index]
		var head: Vector3 = (record["position"] as Vector3) + Vector3.UP * SPOT_HEAD_HEIGHT_M
		var spot: SpotLight3D = active_lights[index]
		spot.global_position = head
		spot.look_at(_ribbon.get_point_at_offset(float(record["s"]), 0.0).origin, Vector3.UP)
