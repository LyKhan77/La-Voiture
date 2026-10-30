class_name WorldSkyRig
extends RefCounted

## Drives the race world's WorldEnvironment (procedural sky, ambient, fog) and its sun from a per-mood profile, so a
## circuit only supplies the DAY / SUNSET / NIGHT numbers. The first apply() duplicates the shared Environment once
## (runtime sky never leaks into the PackedScene resource); after that only its values change.
##
## A profile holds: sky_top, sky_horizon, ground, fog (Colors), fog_density, ambient_energy, sun (Color), sun_energy;
## optional: ambient (Color, switches the ambient light to that colour) and sun_pitch / sun_yaw (degrees, aims the sun).
## `gloom` (0..1) greys the sky and fog toward `storm_grey` and dims the sun.
## shortcut: the Apex Ring keeps CircuitLightingController (it also drives its floodlights, stars and foliage); fold it in
## here only if a fourth circuit wants the same rig.

const SKY_GLOOM_MIX: float = 0.6
const FOG_GLOOM_MIX: float = 0.5
const SUN_GLOOM_DIM: float = 0.4

## ACES tonemap and a fixed fog-to-sky blend are opt-in: a circuit whose scene already looks right leaves them alone.
var aces_tonemap: bool = false
var fog_sky_affect: float = -1.0

var _runtime_environment: Environment
var _sky_material: ProceduralSkyMaterial


func apply(world_environment: WorldEnvironment, sun: DirectionalLight3D, profile: Dictionary, gloom: float, storm_grey: Color) -> void:
	if world_environment == null or world_environment.environment == null:
		return
	if world_environment.environment != _runtime_environment:
		_adopt(world_environment)
	var sky_horizon: Color = (profile["sky_horizon"] as Color).lerp(storm_grey, gloom * SKY_GLOOM_MIX)
	_sky_material.sky_top_color = (profile["sky_top"] as Color).lerp(storm_grey.darkened(0.3), gloom * SKY_GLOOM_MIX)
	_sky_material.sky_horizon_color = sky_horizon
	_sky_material.ground_horizon_color = sky_horizon
	_sky_material.ground_bottom_color = profile["ground"]
	if profile.has("ambient"):
		_runtime_environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		_runtime_environment.ambient_light_color = profile["ambient"]
	_runtime_environment.ambient_light_energy = float(profile["ambient_energy"])
	_runtime_environment.fog_light_color = (profile["fog"] as Color).lerp(storm_grey, gloom * FOG_GLOOM_MIX)
	_runtime_environment.fog_density = float(profile["fog_density"]) * (1.0 + gloom)
	if sun == null:
		return
	if profile.has("sun_pitch"):
		sun.rotation_degrees = Vector3(-float(profile["sun_pitch"]), float(profile["sun_yaw"]), 0.0)
	sun.light_color = profile["sun"]
	sun.light_energy = float(profile["sun_energy"]) * (1.0 - gloom * SUN_GLOOM_DIM)


func _adopt(world_environment: WorldEnvironment) -> void:
	_runtime_environment = world_environment.environment.duplicate() as Environment
	_sky_material = ProceduralSkyMaterial.new()
	_sky_material.sun_angle_max = 0.0
	var sky := Sky.new()
	sky.sky_material = _sky_material
	_runtime_environment.background_mode = Environment.BG_SKY
	_runtime_environment.sky = sky
	_runtime_environment.fog_enabled = true
	_runtime_environment.glow_enabled = true
	if aces_tonemap:
		_runtime_environment.tonemap_mode = Environment.TONE_MAPPER_ACES
	if fog_sky_affect >= 0.0:
		_runtime_environment.fog_sky_affect = fog_sky_affect
	world_environment.environment = _runtime_environment
