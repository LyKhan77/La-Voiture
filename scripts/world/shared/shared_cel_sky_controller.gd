class_name SharedCelSkyController
extends RefCounted

## Reusable Cel-Shaded Skybox & Wind Ambience controller (FASE 12.3).
## Builds and drives SkyAmbienceRoot (AnimeMoon/Sun disc, 900 twinkling NightStars, and 28
## wind-drifting 3D cel-shaded cloud clusters) across DAY, SUNSET, and NIGHT for any circuit.

const TrackRibbonScript := preload("res://scripts/car/track_ribbon.gd")
const MoonShader := preload("res://shaders/neo_wangan_moon.gdshader")
const StarShader := preload("res://shaders/neo_wangan_stars.gdshader")
const CloudShader := preload("res://shaders/neo_wangan_clouds.gdshader")

const DAY_SUN_OFFSET := Vector3(-520.0, 960.0, -980.0)
const SUNSET_SUN_OFFSET := Vector3(-720.0, 340.0, -1100.0)
const NIGHT_MOON_OFFSET := Vector3(-650.0, 780.0, -1100.0)
const MOON_QUAD_M: float = 285.0

const STAR_COUNT: int = 900
const STAR_DOME_RADIUS_M: float = 2400.0
const STAR_MIN_ELEVATION_DEG: float = 5.0
const STAR_MAX_ELEVATION_DEG: float = 88.0
const STAR_QUAD_M: float = 9.0

const CLOUD_COUNT: int = 28
const CLOUD_MIN_RADIUS_M: float = 450.0
const CLOUD_MAX_RADIUS_M: float = 1200.0
const CLOUD_MIN_HEIGHT_M: float = 260.0
const CLOUD_MAX_HEIGHT_M: float = 420.0
## Ring spin in rad/s: a base drift plus a share per km/h of wind, so a gale visibly shoves the clouds.
const CLOUD_BASE_RATE: float = 0.004
const CLOUD_WIND_RATE: float = 0.00035

## Below DAY_MAX_NIGHT_FACTOR the sky is day; from NIGHT_MIN_NIGHT_FACTOR it is night.
const DAY_MAX_NIGHT_FACTOR: float = 0.15
const NIGHT_MIN_NIGHT_FACTOR: float = 0.7

var sky_ambience_root: Node3D
var moon_instance: MeshInstance3D
var star_instance: MultiMeshInstance3D
var cloud_instance: MultiMeshInstance3D
var moon_material: ShaderMaterial
var star_material: ShaderMaterial
var cloud_material: ShaderMaterial
var cloud_angle: float = 0.0
var current_wind_kph: float = 14.0


func build(parent: Node3D, ribbon: TrackRibbonScript, seed_value: int = 20260240, include_stars: bool = true) -> Node3D:
	sky_ambience_root = parent.get_node_or_null("SkyAmbienceRoot") as Node3D
	if sky_ambience_root == null:
		sky_ambience_root = Node3D.new()
		sky_ambience_root.name = "SkyAmbienceRoot"
		parent.add_child(sky_ambience_root)
	sky_ambience_root.position = _circuit_centre(ribbon)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	_build_moon()
	if include_stars:
		_build_stars(rng)
	_build_clouds(rng)
	return sky_ambience_root


## Integrates the cloud ring angle so a changing wind speeds the clouds up smoothly instead of teleporting them.
func apply_wind(delta: float, wind_kph: float) -> void:
	current_wind_kph = wind_kph
	cloud_angle = fposmod(cloud_angle + delta * (CLOUD_BASE_RATE + wind_kph * CLOUD_WIND_RATE), TAU)
	if cloud_instance != null:
		cloud_instance.rotation.y = cloud_angle


## 0 = DAY, 1 = SUNSET, 2 = NIGHT, from the GtWeather time_of_day dictionary. Any other mode
## (TWILIGHT_TRANSITION) is classified by its floodlight level.
static func mode_of(tod: Dictionary) -> int:
	var mode: int = int(tod.get("mode", -1))
	if mode >= 0 and mode <= 2:
		return mode
	var night_factor: float = clampf(float(tod.get("floodlights", 1.0)), 0.0, 1.0)
	return 2 if night_factor >= NIGHT_MIN_NIGHT_FACTOR else (1 if night_factor >= DAY_MAX_NIGHT_FACTOR else 0)


func apply_time_of_day(tod: Dictionary, gloom: float = 0.0) -> void:
	var night_factor: float = clampf(float(tod.get("floodlights", 1.0)), 0.0, 1.0)
	var stars_opacity: float = clampf(float(tod.get("stars_opacity", night_factor)) * (1.0 - gloom * 0.85), 0.0, 1.0)
	var mode: int = mode_of(tod)

	if star_instance != null and star_material != null:
		star_instance.visible = stars_opacity > 0.02
		star_material.set_shader_parameter("star_opacity", stars_opacity)

	if moon_instance != null and moon_material != null:
		if mode == 0:
			moon_instance.position = DAY_SUN_OFFSET
			moon_material.set_shader_parameter("moon_color", Color("#fffef5"))
			moon_material.set_shader_parameter("moon_shade", Color("#ffe885"))
			moon_material.set_shader_parameter("halo_color", Color("#b3ecff"))
			moon_material.set_shader_parameter("crater_density", 0.0)
			moon_material.set_shader_parameter("halo_inner_alpha", 0.42 * (1.0 - gloom * 0.7))
			moon_material.set_shader_parameter("halo_outer_alpha", 0.18 * (1.0 - gloom * 0.7))
		elif mode == 1:
			moon_instance.position = SUNSET_SUN_OFFSET
			moon_material.set_shader_parameter("moon_color", Color("#ffb838"))
			moon_material.set_shader_parameter("moon_shade", Color("#ff3d1f"))
			moon_material.set_shader_parameter("halo_color", Color("#ff7043"))
			moon_material.set_shader_parameter("crater_density", 0.0)
			moon_material.set_shader_parameter("halo_inner_alpha", 0.46 * (1.0 - gloom * 0.6))
			moon_material.set_shader_parameter("halo_outer_alpha", 0.22 * (1.0 - gloom * 0.6))
		else:
			moon_instance.position = NIGHT_MOON_OFFSET
			moon_material.set_shader_parameter("moon_color", Color("#fff8d6"))
			moon_material.set_shader_parameter("moon_shade", Color("#c7d1bd"))
			moon_material.set_shader_parameter("halo_color", Color("#9edbff"))
			moon_material.set_shader_parameter("crater_density", 0.34)
			moon_material.set_shader_parameter("halo_inner_alpha", 0.38 * (1.0 - gloom * 0.5))
			moon_material.set_shader_parameter("halo_outer_alpha", 0.16 * (1.0 - gloom * 0.5))

	if cloud_material != null:
		if mode == 0:
			cloud_material.set_shader_parameter("cloud_rim", Color("#ffffff").lerp(Color("#aeb8c7"), gloom * 0.65))
			cloud_material.set_shader_parameter("cloud_mid", Color("#dcebfa").lerp(Color("#6c788c"), gloom * 0.70))
			cloud_material.set_shader_parameter("cloud_shadow", Color("#93b4db").lerp(Color("#3d4657"), gloom * 0.75))
			cloud_material.set_shader_parameter("moon_dir", DAY_SUN_OFFSET.normalized())
		elif mode == 1:
			cloud_material.set_shader_parameter("cloud_rim", Color("#ffb057").lerp(Color("#8c6b7a"), gloom * 0.65))
			cloud_material.set_shader_parameter("cloud_mid", Color("#bd5e7a").lerp(Color("#52435c"), gloom * 0.70))
			cloud_material.set_shader_parameter("cloud_shadow", Color("#4a2c56").lerp(Color("#2a2438"), gloom * 0.75))
			cloud_material.set_shader_parameter("moon_dir", SUNSET_SUN_OFFSET.normalized())
		else:
			cloud_material.set_shader_parameter("cloud_rim", Color("#b8e0ff").lerp(Color("#546885"), gloom * 0.60))
			cloud_material.set_shader_parameter("cloud_mid", Color("#405285").lerp(Color("#25304d"), gloom * 0.60))
			cloud_material.set_shader_parameter("cloud_shadow", Color("#1f2645").lerp(Color("#12172b"), gloom * 0.60))
			cloud_material.set_shader_parameter("moon_dir", NIGHT_MOON_OFFSET.normalized())


static func _circuit_centre(ribbon: TrackRibbonScript) -> Vector3:
	if ribbon == null:
		return Vector3.ZERO
	var centre := Vector3.ZERO
	var samples: int = 0
	var s: float = 0.0
	while s < ribbon.length_m:
		centre += ribbon.get_point_at_offset(s, 0.0).origin
		samples += 1
		s += 100.0
	centre /= float(maxi(samples, 1))
	centre.y = 0.0
	return centre


func _build_moon() -> void:
	var quad := QuadMesh.new()
	quad.size = Vector2(MOON_QUAD_M, MOON_QUAD_M)
	moon_material = ShaderMaterial.new()
	moon_material.shader = MoonShader
	moon_instance = MeshInstance3D.new()
	moon_instance.name = "AnimeMoon"
	moon_instance.mesh = quad
	moon_instance.material_override = moon_material
	moon_instance.position = NIGHT_MOON_OFFSET
	moon_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# The shader turns the flat quad to face the camera, so its AABB must not cull it edge-on.
	moon_instance.extra_cull_margin = MOON_QUAD_M
	sky_ambience_root.add_child(moon_instance)


func _build_stars(rng: RandomNumberGenerator) -> void:
	var quad := QuadMesh.new()
	quad.size = Vector2(STAR_QUAD_M, STAR_QUAD_M)
	star_material = ShaderMaterial.new()
	star_material.shader = StarShader
	var low: float = sin(deg_to_rad(STAR_MIN_ELEVATION_DEG))
	var high: float = sin(deg_to_rad(STAR_MAX_ELEVATION_DEG))
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_colors = true
	multimesh.mesh = quad
	multimesh.instance_count = STAR_COUNT
	var tints: Array[Color] = [Color.WHITE, Color("#bfe6ff"), Color("#ffe2c4")]
	for index: int in range(STAR_COUNT):
		# Uniform in sin(elevation) spreads the stars evenly over the dome instead of piling them at the zenith.
		var up: float = rng.randf_range(low, high)
		var ring: float = sqrt(1.0 - up * up)
		var azimuth: float = rng.randf_range(0.0, TAU)
		var at := Vector3(cos(azimuth) * ring, up, sin(azimuth) * ring) * STAR_DOME_RADIUS_M
		var size_scale: float = rng.randf_range(0.6, 1.5)
		multimesh.set_instance_transform(index, Transform3D(Basis.from_scale(Vector3.ONE * size_scale), at))
		multimesh.set_instance_color(index, tints[index % tints.size()])
	star_instance = MultiMeshInstance3D.new()
	star_instance.name = "NightStars"
	star_instance.multimesh = multimesh
	star_instance.material_override = star_material
	star_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	sky_ambience_root.add_child(star_instance)


func _build_clouds(rng: RandomNumberGenerator) -> void:
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = _cloud_mesh()
	multimesh.instance_count = CLOUD_COUNT
	for index: int in range(CLOUD_COUNT):
		var azimuth: float = (float(index) + rng.randf_range(-0.3, 0.3)) / float(CLOUD_COUNT) * TAU
		var radius: float = rng.randf_range(CLOUD_MIN_RADIUS_M, CLOUD_MAX_RADIUS_M)
		var at := Vector3(cos(azimuth) * radius, rng.randf_range(CLOUD_MIN_HEIGHT_M, CLOUD_MAX_HEIGHT_M), sin(azimuth) * radius)
		var orientation := Basis(Vector3.UP, rng.randf_range(0.0, TAU)).scaled(Vector3.ONE * rng.randf_range(0.8, 1.7))
		multimesh.set_instance_transform(index, Transform3D(orientation, at))
	cloud_material = ShaderMaterial.new()
	cloud_material.shader = CloudShader
	cloud_instance = MultiMeshInstance3D.new()
	cloud_instance.name = "AnimeNightClouds"
	cloud_instance.multimesh = multimesh
	cloud_instance.material_override = cloud_material
	cloud_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	sky_ambience_root.add_child(cloud_instance)


## One cloud = three overlapping flattened puffs merged into a single surface: a wide body with a
## hump on each side. Low segment counts keep 28 of them near 8 000 triangles.
static func _cloud_mesh() -> ArrayMesh:
	var puff := SphereMesh.new()
	puff.radius = 1.0
	puff.height = 2.0
	puff.radial_segments = 10
	puff.rings = 5
	var puffs: Array[Transform3D] = [
		Transform3D(Basis.from_scale(Vector3(62.0, 20.0, 34.0)), Vector3.ZERO),
		Transform3D(Basis.from_scale(Vector3(36.0, 17.0, 26.0)), Vector3(-44.0, 5.0, 4.0)),
		Transform3D(Basis.from_scale(Vector3(30.0, 14.0, 22.0)), Vector3(48.0, 2.0, -6.0)),
	]
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for pose: Transform3D in puffs:
		tool.append_from(puff, 0, pose)
	return tool.commit()
