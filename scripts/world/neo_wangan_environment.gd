class_name NeoWanganEnvironment
extends Node3D

## Neo-Wangan six-layer environment (FASE 12.1). TrackRibbon owns the road spine; UrbanIslandRoot
## owns continuous civil ground and cut-and-cover roof mass. PitLane owns the shared FIA kit.
## MidgroundCorridorRoot owns district-batched GLB towers and neon panels; HeroLandmarksRoot owns
## spline-anchored bridge/tunnel/harbor architecture. This set owns the night sky and asphalt pools.
##
## Every element that repeats more than three times is one MultiMeshInstance3D, so the whole set
## costs a handful of draw calls (see stats()). No textures: flat cel colours and one shader.
##
## This is the city set of Neo-Wangan only; the Apex Ring keeps TrackEnvironmentBuilder.

const RibbonGeometry := preload("res://scripts/world/ribbon_geometry.gd")
const MeshBatchScript := preload("res://scripts/world/mesh_batch.gd")
const ToonMaterials := preload("res://scripts/world/toon_materials.gd")
const RibbonScript := preload("res://scripts/car/track_ribbon.gd")
const CircuitScript := preload("res://scripts/world/neo_wangan_circuit_builder.gd")
const SkylineShader := preload("res://shaders/neo_wangan_skyline.gdshader")
const PoolShader := preload("res://shaders/neo_wangan_light_pool.gdshader")
const SkylineOutlineShader := preload("res://shaders/neo_wangan_skyline_outline.gdshader")
const WaterShader := preload("res://shaders/neo_wangan_water.gdshader")
const BillboardShader := preload("res://shaders/neo_wangan_billboard.gdshader")
const CloudShader := preload("res://shaders/neo_wangan_clouds.gdshader")
const WindBannerShader := preload("res://shaders/neo_wangan_wind_banner.gdshader")
const MoonShader := preload("res://shaders/neo_wangan_moon.gdshader")
const StarShader := preload("res://shaders/neo_wangan_stars.gdshader")
const Liveries := preload("res://scripts/car/team_liveries.gd")
const TracksideKit := preload("res://scripts/world/trackside_furniture_builder.gd")
const PitKit := preload("res://scripts/world/neo_wangan_pit_complex.gd")
const MODEL_DIR := "res://assets/tracks/neo_wangan/models/"

const BARRIER_LATERAL_M: float = 6.35
const BARRIER_STEP_M: float = 3.0
const BARRIER_SIZE := Vector3(0.55, 1.05, 2.9)
const HAZARD_STEP_M: float = 6.0
const HAZARD_CURVATURE: float = 0.006

const LAMP_PITCH_M: float = 42.0
const LAMP_LATERAL_M: float = 6.9
const LAMP_HEIGHT_M: float = 9.0

const GANTRY_S: Array[float] = [300.0, 900.0, 1750.0, 2600.0]
const GANTRY_HALF_SPAN_M: float = 7.4
const GANTRY_HEIGHT_M: float = 6.2
const GANTRY_PANEL_WIDTH_M: float = 6.4
const GANTRY_PANEL_HEIGHT_M: float = 1.9

const TUNNEL_HALF_WIDTH_M: float = 6.7
const TUNNEL_CLEARANCE_M: float = 5.0
const TUNNEL_LAMP_PITCH_M: float = 9.0
const TUNNEL_STEP_M: float = 4.0

const DECK_STEP_M: float = 6.0
const DECK_SIZE := Vector3(14.4, 0.9, 6.2)
const PIER_PITCH_M: float = 60.0
const PIER_LATERAL_M: float = 4.2
const BASE_Y: float = -6.0

const CONTAINER_SIZE := Vector3(2.44, 2.59, 6.06)
const CONTAINER_COLORS: Array[Color] = [Color("#c2342c"), Color("#1f7f8c"), Color("#d9a21b")]
const CRANE_S: Array[float] = [1390.0, 1470.0]
const CRANE_LATERAL_M: float = -24.0

const SKYLINE_COUNT: int = 110
const SKYLINE_MIN_RADIUS_M: float = 250.0
const SKYLINE_MAX_RADIUS_M: float = 660.0
const SKYLINE_TRACK_CLEARANCE_M: float = 70.0
const SKYLINE_SEED: int = 20260227

## Skyline ink hull width in the world (see neo_wangan_skyline_outline.gdshader).
const SKYLINE_OUTLINE_M: float = 0.9

## Sky ambience (FASE 12.2): everything hangs off SkyAmbienceRoot, centred on the circuit.
const MOON_OFFSET := Vector3(-650.0, 780.0, -1100.0)
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
const BANNER_COUNT: int = 24
const BANNER_SIZE := Vector3(0.9, 2.4, 0.04)
const BANNER_HEIGHT_M: float = 6.2
const BANNER_COLORS: Array[Color] = [Color("#00f0ff"), Color("#ff2d78"), Color("#ccff00")]
const DEFAULT_WIND_KPH: float = 14.0
const DEFAULT_WIND_DIR_RAD: float = 0.6

const NIGHT_TOP := Color("#060a18")
const NIGHT_HORIZON := Color("#2a1a3e")
const NEON_CYAN := Color("#00f0ff")
const NEON_MAGENTA := Color("#ff2d78")
const ASPHALT_DARK := Color("#1a1c22")
const WATER_COLOR := Color("#07121e")
const METAL := Color("#3c4250")
const LAMP_HEAD := Color("#fff0c8")

var ribbon: RibbonScript
var circuit
## RaceWeekendWorld reads this for its digital flag panels; the street circuit has none.
var furniture: Node = null

## Render budget of the whole set, filled by measure().
var draw_calls: int = 0
var triangle_count: int = 0
var multimesh_count: int = 0

var barrier_instance: MultiMeshInstance3D
var streetlight_instance: MultiMeshInstance3D
var skyline_instance: MultiMeshInstance3D
var container_instances: Array[MultiMeshInstance3D] = []
var tunnel_neon_instance: MultiMeshInstance3D
var sky_ambience_root: Node3D
var moon_instance: MeshInstance3D
var star_instance: MultiMeshInstance3D
var cloud_instance: MultiMeshInstance3D
var wind_banner_instance: MultiMeshInstance3D
var skyline_buildings: Array[Dictionary] = [] # {position, size}
var barrier_count: int = 0
var streetlight_count: int = 0
var container_count: int = 0
var tunnel_lamp_count: int = 0

var _world_environment: WorldEnvironment
var _sun: DirectionalLight3D
var _camera: Camera3D
var _neon_material: StandardMaterial3D
var _lamp_material: StandardMaterial3D
var _window_material: ShaderMaterial
var _water_shader_mat: ShaderMaterial
var _banner_shader_mat: ShaderMaterial
var _cloud_base_poses: Array[Transform3D] = []
var _cloud_angle: float = 0.0
## Live wind from race.weather, in km/h; the ambience (clouds, water, banners) follows it.
var current_wind_kph: float = 12.0
var _clock_s: float = 0.0
var _leaderboard_clock: float = 0.0
var _jumbotron: Jumbotron
var urban_island_root: Node3D
var hero_landmarks_root: Node3D
var midground_corridor_root: Node3D
var near_track_buildings: Array[Dictionary] = []
var ground_spans: Array[Vector2] = []
var light_pool_poses: Array[Transform3D] = []
var crane_poses: Array[Transform3D] = []
var bridge_pier_poses: Array[Transform3D] = []


## Builds the whole set against the circuit's ribbon and its authored spans.
func build(p_ribbon: RibbonScript, p_circuit) -> void:
	ribbon = p_ribbon
	circuit = p_circuit
	_jumbotron = get_parent().get_node_or_null("PitLane/MainGrandstand/Jumbotron") as Jumbotron
	urban_island_root = _layer("UrbanIslandRoot")
	hero_landmarks_root = _layer("HeroLandmarksRoot")
	midground_corridor_root = _layer("MidgroundCorridorRoot")
	sky_ambience_root = _layer("SkyAmbienceRoot")
	_build_ground()
	_build_urban_island()
	_build_barriers()
	_build_kerbs()
	_build_streetlights()
	_build_gantry_signs()
	_build_braking_boards()
	_build_tunnel()
	_build_bridge()
	_build_harbor()
	_build_skyline()
	_build_hero_landmarks()
	_build_street_corridor()
	_build_sky_ambience()
	_build_wind_banners()
	_apply_night_sky()
	measure()


## The race world hands its own sky, sun and camera to the set.
func bind_world(world_environment: WorldEnvironment, sun: DirectionalLight3D, camera: Camera3D) -> void:
	_world_environment = world_environment
	_sun = sun
	_camera = camera
	_apply_night_sky()


## Neon and window glow breathe a little, like a city that never quite settles.
func update(delta: float, race) -> void:
	_clock_s += delta
	var pulse: float = 0.86 + 0.14 * sin(_clock_s * 2.1)
	if _neon_material != null:
		_neon_material.emission_energy_multiplier = 2.2 * pulse
	if _lamp_material != null:
		_lamp_material.emission_energy_multiplier = 2.6
	if _window_material != null:
		_window_material.set_shader_parameter("window_energy", 1.8 * pulse)
	var wind_kph: float = DEFAULT_WIND_KPH
	var wind_dir: float = DEFAULT_WIND_DIR_RAD
	if race != null and race.get("weather") != null:
		wind_kph = float(race.weather.wind_speed)
		wind_dir = float(race.weather.wind_direction)
	apply_wind_ambience(delta, wind_kph, wind_dir)
	_leaderboard_clock += delta
	if race != null and _jumbotron != null and _leaderboard_clock >= 0.5:
		_leaderboard_clock = 0.0
		var colors: Array[Color] = []
		var values: Array[float] = []
		var order: Array[GtCar] = race.standings()
		for row: int in range(mini(order.size(), _jumbotron.ROWS)):
			colors.append(Liveries.color_for(order[row].team_id))
			values.append(1.0 - 0.08 * float(row))
		_jumbotron.set_leaderboard(colors, values)


## Wind drives the whole ambience: bay ripples and banner flutter read the uniforms, the cloud ring
## spins faster the harder it blows. Called every frame from update() with race.weather's wind.
func apply_wind_ambience(delta: float, wind_kph: float, wind_dir: float) -> void:
	current_wind_kph = wind_kph
	if _water_shader_mat != null:
		_water_shader_mat.set_shader_parameter("time_s", _clock_s)
		_water_shader_mat.set_shader_parameter("wind_speed_kph", wind_kph)
		_water_shader_mat.set_shader_parameter("wind_dir", Vector2(cos(wind_dir), sin(wind_dir)))
	if _banner_shader_mat != null:
		_banner_shader_mat.set_shader_parameter("time_s", _clock_s)
		_banner_shader_mat.set_shader_parameter("wind_speed_kph", wind_kph)
	# Integrate the angle so a changing wind speeds the clouds up smoothly instead of teleporting them.
	_cloud_angle = fposmod(_cloud_angle + delta * (CLOUD_BASE_RATE + wind_kph * CLOUD_WIND_RATE), TAU)
	if cloud_instance != null:
		cloud_instance.rotation.y = _cloud_angle


func stats() -> Dictionary:
	measure()
	return {
		"draw_calls": draw_calls,
		"triangles": triangle_count,
		"multimeshes": multimesh_count,
		"barriers": barrier_count,
		"streetlights": streetlight_count,
		"containers": container_count,
		"tunnel_lamps": tunnel_lamp_count,
		"skyline": skyline_buildings.size(),
		"near_track_buildings": near_track_buildings.size(),
		"harbor_cranes": crane_poses.size(),
	}


## Counts what a frame would submit and how heavy it is. MultiMesh instances cost one draw call per
## surface and pay their triangles once per instance.
func measure() -> void:
	draw_calls = 0
	triangle_count = 0
	multimesh_count = 0
	_measure_node(self)


func _measure_node(node: Node) -> void:
	if node is Node3D and not (node as Node3D).visible:
		return
	if node is MultiMeshInstance3D:
		var instanced := node as MultiMeshInstance3D
		if instanced.multimesh != null and instanced.multimesh.mesh != null:
			multimesh_count += 1
			_measure_mesh(instanced.multimesh.mesh, instanced.multimesh.instance_count, instanced.material_override)
	elif node is MeshInstance3D:
		var mesh_instance := node as MeshInstance3D
		if mesh_instance.mesh != null:
			_measure_mesh(mesh_instance.mesh, 1, mesh_instance.material_override)
	for child: Node in node.get_children():
		_measure_node(child)


func _measure_mesh(mesh: Mesh, copies: int, override: Material) -> void:
	for surface: int in range(mesh.get_surface_count()):
		var material: Material = override if override != null else mesh.surface_get_material(surface)
		var passes: int = 1
		while material != null and material.next_pass != null:
			passes += 1
			material = material.next_pass
		var arrays: Array = mesh.surface_get_arrays(surface)
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] is PackedInt32Array else PackedInt32Array()
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var count: int = indices.size() / 3 if not indices.is_empty() else vertices.size() / 3
		draw_calls += passes
		triangle_count += count * copies * passes


static func _mesh_triangles(mesh: Mesh) -> int:
	var total: int = 0
	for surface: int in range(mesh.get_surface_count()):
		var arrays: Array = mesh.surface_get_arrays(surface)
		var raw: Variant = arrays[Mesh.ARRAY_INDEX]
		if raw is PackedInt32Array and (raw as PackedInt32Array).size() > 0:
			total += (raw as PackedInt32Array).size() / 3
		else:
			total += (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() / 3
	return total


# --- ground and water ---------------------------------------------------------------------------

func _build_ground() -> void:
	_base_plane("Base", BASE_Y, 6000.0, ToonMaterials.make(ASPHALT_DARK))
	var water := _base_plane("Water", BASE_Y + 0.35, 900.0, _water_material())
	var bridge_middle: Vector3 = ribbon.get_point_at_offset(475.0, 0.0).origin
	water.position = Vector3(bridge_middle.x, BASE_Y + 0.35, bridge_middle.z)


func _base_plane(node_name: String, y: float, size: float, material: Material) -> MeshInstance3D:
	var plane := MeshInstance3D.new()
	plane.name = node_name
	var mesh := PlaneMesh.new()
	mesh.size = Vector2(size, size)
	plane.mesh = mesh
	plane.material_override = material
	plane.position = Vector3(0.0, y, 0.0)
	plane.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(plane)
	return plane


## Stepped toon bay water; wind uniforms are pushed every frame by apply_wind_ambience().
func _water_material() -> ShaderMaterial:
	_water_shader_mat = ShaderMaterial.new()
	_water_shader_mat.shader = WaterShader
	_water_shader_mat.set_shader_parameter("wind_speed_kph", current_wind_kph)
	return _water_shader_mat


# --- barriers ------------------------------------------------------------------------------------

func _build_barriers() -> void:
	var mesh := BoxMesh.new()
	mesh.size = Vector3.ONE
	var transforms: Array[Transform3D] = []
	var hazard: Array[Transform3D] = []
	var length: float = ribbon.length_m
	var s: float = 0.0
	while s < length:
		for side: float in [-1.0, 1.0]:
			if side > 0.0 and _in_pit_gap(s):
				continue
			transforms.append(RibbonGeometry.box_transform(ribbon, s, side * BARRIER_LATERAL_M, BARRIER_SIZE, 0.0))
		s += BARRIER_STEP_M
	s = 0.0
	while s < length:
		if absf(ribbon.get_curvature_at(s)) >= HAZARD_CURVATURE:
			for side: float in [-1.0, 1.0]:
				if side > 0.0 and _in_pit_gap(s):
					continue
				hazard.append(RibbonGeometry.box_transform(ribbon, s, side * BARRIER_LATERAL_M, Vector3(0.6, 0.1, 2.2), BARRIER_SIZE.y))
		s += HAZARD_STEP_M
	barrier_count = transforms.size()
	barrier_instance = _multimesh("ConcreteBarriers", mesh, transforms, ToonMaterials.make(Color("#b9bdc7")))
	_multimesh("BarrierHazardCaps", mesh, hazard, ToonMaterials.make(Color("#ffd400")))
	barrier_instance.set_meta(&"fia_barrier", true)


## The right-hand barrier stops for the pit entry and starts again after the pit exit merge.
func _in_pit_gap(s: float) -> bool:
	var from: float = PitKit.ENTRY_S - 25.0
	var until: float = PitKit.BYPASS_MERGE_S + 5.0
	return fposmod(s - from, ribbon.length_m) <= fposmod(until - from, ribbon.length_m)


# --- kerbs -------------------------------------------------------------------------------------

## Low street-circuit kerbs on the inside of every numbered turn: 1.2 m red/white blocks standing
## 30 mm proud of the asphalt, one MultiMesh per colour for all twelve corners.
func _build_kerbs() -> void:
	var reds: Array[Transform3D] = []
	var whites: Array[Transform3D] = []
	if circuit == null or not ("turns" in circuit):
		return
	for turn: Dictionary in circuit.turns:
		var direction: int = int(turn["direction"])
		var lateral: float = -direction * (float(ribbon.road_half_width_m) - 0.65)
		var half_span: float = float(turn["span_m"]) * 0.5
		var apex: float = float(turn["apex_s"][0]) if not (turn["apex_s"] as Array).is_empty() else float(turn["s"])
		var count: int = maxi(4, int(half_span * 2.0 / 2.4))
		for index: int in range(count):
			var at: float = fposmod(apex - half_span + 2.4 * float(index), ribbon.length_m)
			var pose: Transform3D = RibbonGeometry.box_transform(ribbon, at, lateral, Vector3(1.25, 0.06, 2.2), 0.0)
			if index % 2 == 0:
				reds.append(pose)
			else:
				whites.append(pose)
	var mesh := BoxMesh.new()
	mesh.size = Vector3.ONE
	_multimesh("KerbsRed", mesh, reds, ToonMaterials.make(Color("#d9232e")))
	_multimesh("KerbsWhite", mesh, whites, ToonMaterials.make(Color("#f4f5f7")))


# --- streetlights --------------------------------------------------------------------------------

func _build_streetlights() -> void:
	var metal := ToonMaterials.vertex_colored(false)
	var batch := MeshBatchScript.new()
	batch.cylinder(metal, METAL, Transform3D.IDENTITY, 0.17, 0.12, LAMP_HEIGHT_M, 6, false, false)
	for direction: float in [-1.0, 1.0]:
		var tip := Vector3(direction * 1.9, LAMP_HEIGHT_M, 0.0)
		batch.strut(metal, METAL, Vector3(0.0, LAMP_HEIGHT_M - 0.35, 0.0), tip, 0.17)
	var heads := MeshBatchScript.new()
	for direction: float in [-1.0, 1.0]:
		heads.box(metal, LAMP_HEAD, Transform3D(Basis(), Vector3(direction * 2.1, LAMP_HEIGHT_M - 0.18, 0.0)), Vector3(0.75, 0.16, 0.42))
	var pole_mesh: ArrayMesh = batch.commit()
	var head_mesh: ArrayMesh = heads.commit()
	var transforms: Array[Transform3D] = []
	var s: float = 14.0
	while s < ribbon.length_m:
		for side: float in [-1.0, 1.0]:
			if side > 0.0 and _in_pit_gap(s):
				continue
			var pose: Transform3D = ribbon.get_point_at_offset(s, side * LAMP_LATERAL_M)
			transforms.append(pose)
		s += LAMP_PITCH_M
	streetlight_count = transforms.size()
	streetlight_instance = _multimesh("Streetlights", pole_mesh, transforms, ToonMaterials.make(METAL))
	_lamp_material = _emissive_material(LAMP_HEAD, 2.6)
	_multimesh("StreetlightHeads", head_mesh, transforms, _lamp_material)
	_build_light_pools(transforms)


## The warm pool each street lamp throws across the asphalt, as one additive quad per lamp: a night
## circuit has to stay readable at 60 FPS, so the light is painted rather than cast.
func _build_light_pools(lamp_transforms: Array[Transform3D]) -> void:
	var quad := QuadMesh.new()
	quad.size = Vector2(9.0, 5.5)
	var pools: Array[Transform3D] = []
	var laterals: Array[float] = []
	for pose: Transform3D in lamp_transforms:
		var s: float = ribbon.curve.get_closest_offset(pose.origin)
		var centre: Transform3D = ribbon.get_point_at_offset(s, 0.0)
		var side: float = signf((pose.origin - centre.origin).dot(centre.basis.x))
		var road: Transform3D = ribbon.get_point_at_offset(s, side * 3.2)
		var flat := Transform3D(road.basis * Basis(Vector3.UP, PI * 0.5) * Basis(Vector3.RIGHT, -PI * 0.5), road.origin + Vector3.UP * 0.04)
		pools.append(flat)
		laterals.append(side * 3.2)
	var material: ShaderMaterial = _pool_material(Color("#ffcf8a"), 0.5)
	material.set_shader_parameter("clip_to_road", true)
	light_pool_poses = pools
	_multimesh("StreetlightPools", quad, pools, material, laterals)


func _pool_material(color: Color, intensity: float) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = PoolShader
	material.set_shader_parameter("pool_color", color)
	material.set_shader_parameter("intensity", intensity)
	return material


func _emissive_material(color: Color, energy: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = energy
	return material


# --- overhead direction signs ---------------------------------------------------------------------

func _build_gantry_signs() -> void:
	var batch := MeshBatchScript.new()
	var metal: Material = ToonMaterials.vertex_colored(false)
	var green: Material = ToonMaterials.vertex_colored(false)
	var white: Material = ToonMaterials.vertex_colored(false)
	for s: float in GANTRY_S:
		for side: float in [-1.0, 1.0]:
			batch.box(metal, METAL, _box_at(s, side * GANTRY_HALF_SPAN_M, 0.0, GANTRY_HEIGHT_M * 0.5), Vector3(0.4, GANTRY_HEIGHT_M, 0.4))
		var left: Vector3 = _at(s, -GANTRY_HALF_SPAN_M, GANTRY_HEIGHT_M)
		var right: Vector3 = _at(s, GANTRY_HALF_SPAN_M, GANTRY_HEIGHT_M)
		batch.strut(metal, METAL, left, right, 0.34)
		var panel: Vector3 = _at(s, 0.0, GANTRY_HEIGHT_M - 1.1)
		var forward: Vector3 = ribbon.get_point_at_offset(s, 0.0).basis.z
		batch.box(green, Color("#117a4b"), Transform3D(Basis(), panel), Vector3(GANTRY_PANEL_WIDTH_M, GANTRY_PANEL_HEIGHT_M, 0.16))
		for row: int in range(2):
			var strip: Vector3 = panel + forward * 0.1 + Vector3.UP * (0.4 - float(row) * 0.5)
			batch.box(white, Color("#f4f5f7"), Transform3D(Basis(), strip), Vector3(GANTRY_PANEL_WIDTH_M * 0.62, 0.14, 0.04))
	var signs := MeshInstance3D.new()
	signs.name = "GantrySigns"
	signs.mesh = batch.commit()
	add_child(signs)


func _at(s: float, lateral_m: float, height_m: float) -> Vector3:
	return ribbon.get_point_at_offset(s, lateral_m).origin + Vector3.UP * height_m


func _build_braking_boards() -> void:
	var source := TracksideKit.new()
	var mesh: ArrayMesh = source._marker_mesh()
	source.free()
	var poses: Array[Transform3D] = []
	var distances: Array[float] = []
	for turn: Dictionary in circuit.turns:
		var apex: float = float(turn["apex_s"][0])
		var side: float = -float(turn["direction"])
		for distance: float in [150.0, 100.0, 50.0]:
			poses.append(ribbon.get_point_at_offset(apex - distance, side * 7.0))
			distances.append(distance)
	_multimesh("BrakingMarkers", mesh, poses, null, distances)


func _box_at(s: float, lateral_m: float, height_m: float, centre_height_m: float) -> Transform3D:
	var pose: Transform3D = ribbon.get_point_at_offset(s, lateral_m)
	pose.origin += Vector3.UP * (height_m + centre_height_m)
	return pose


# --- underpass -----------------------------------------------------------------------------------

func _build_tunnel() -> void:
	var start_s: float = CircuitScript.TUNNEL_START_M
	var end_s: float = CircuitScript.TUNNEL_END_M
	var batch := MeshBatchScript.new()
	var concrete: Material = ToonMaterials.vertex_colored(false)
	var length: float = end_s - start_s
	var steps: int = maxi(1, ceili(length / TUNNEL_STEP_M))
	for index: int in range(steps):
		var sa: float = lerpf(start_s, end_s, float(index) / float(steps))
		var sb: float = lerpf(start_s, end_s, float(index + 1) / float(steps))
		for side: float in [-1.0, 1.0]:
			var bottom_a: Vector3 = _at(sa, side * TUNNEL_HALF_WIDTH_M, -1.2)
			var bottom_b: Vector3 = _at(sb, side * TUNNEL_HALF_WIDTH_M, -1.2)
			var top_a: Vector3 = _at(sa, side * TUNNEL_HALF_WIDTH_M, TUNNEL_CLEARANCE_M)
			var top_b: Vector3 = _at(sb, side * TUNNEL_HALF_WIDTH_M, TUNNEL_CLEARANCE_M)
			batch.quad(concrete, Color("#585d68"), bottom_a, bottom_b, top_b, top_a, -Vector3(side, 0.0, 0.0))
		var left_a: Vector3 = _at(sa, -TUNNEL_HALF_WIDTH_M, TUNNEL_CLEARANCE_M)
		var left_b: Vector3 = _at(sb, -TUNNEL_HALF_WIDTH_M, TUNNEL_CLEARANCE_M)
		var right_a: Vector3 = _at(sa, TUNNEL_HALF_WIDTH_M, TUNNEL_CLEARANCE_M)
		var right_b: Vector3 = _at(sb, TUNNEL_HALF_WIDTH_M, TUNNEL_CLEARANCE_M)
		batch.quad(concrete, Color("#3d424c"), left_a, left_b, right_b, right_a, Vector3.DOWN)
	var shell := MeshInstance3D.new()
	shell.name = "TunnelShell"
	shell.mesh = batch.commit()
	add_child(shell)

	var transforms: Array[Transform3D] = []
	var s: float = start_s + 3.0
	while s < end_s - 3.0:
		var pose: Transform3D = ribbon.get_point_at_offset(s, 0.0)
		pose.origin += Vector3.UP * (TUNNEL_CLEARANCE_M - 0.28)
		transforms.append(pose)
		s += TUNNEL_LAMP_PITCH_M
	tunnel_lamp_count = transforms.size()
	var lamp_mesh := BoxMesh.new()
	lamp_mesh.size = Vector3(2.6, 0.14, 0.35)
	_neon_material = _emissive_material(NEON_CYAN, 2.2)
	tunnel_neon_instance = _multimesh("TunnelNeon", lamp_mesh, transforms, _neon_material)
	var neon_pools: Array[Transform3D] = []
	var pool_quad := QuadMesh.new()
	pool_quad.size = Vector2(9.0, 9.0)
	for pose: Transform3D in transforms:
		var floor_pose := Transform3D(pose.basis * Basis(Vector3.RIGHT, -PI * 0.5), pose.origin - Vector3.UP * (TUNNEL_CLEARANCE_M - 0.32))
		neon_pools.append(floor_pose)
	_multimesh("TunnelNeonPools", pool_quad, neon_pools, _pool_material(NEON_CYAN, 0.55))
	tunnel_neon_instance.set_meta(&"neon_color", NEON_CYAN)
	# A magenta service strip on each wall, so the underpass reads as two neon colours.
	var wall_transforms: Array[Transform3D] = []
	s = start_s + 6.0
	while s < end_s - 6.0:
		for side: float in [-1.0, 1.0]:
			var pose: Transform3D = ribbon.get_point_at_offset(s, side * (TUNNEL_HALF_WIDTH_M - 0.12))
			pose.origin += Vector3.UP * 1.4
			wall_transforms.append(pose)
		s += 18.0
	_multimesh("TunnelWallGlow", lamp_mesh, wall_transforms, _emissive_material(NEON_MAGENTA, 1.5))


# --- Shuto Bay Bridge ----------------------------------------------------------------------------

func _build_bridge() -> void:
	var deck_mesh := BoxMesh.new()
	deck_mesh.size = Vector3.ONE
	var decks: Array[Transform3D] = []
	var s: float = CircuitScript.BRIDGE_START_M
	while s <= CircuitScript.BRIDGE_END_M:
		decks.append(RibbonGeometry.box_transform(ribbon, s, 0.0, DECK_SIZE, -DECK_SIZE.y))
		s += DECK_STEP_M
	_multimesh("BridgeDeck", deck_mesh, decks, ToonMaterials.make(Color("#6b7280")))
	var piers: Array[Transform3D] = []
	s = CircuitScript.BRIDGE_START_M + 20.0
	while s <= CircuitScript.BRIDGE_END_M - 20.0:
		for side: float in [-1.0, 1.0]:
			var pose: Transform3D = ribbon.get_point_at_offset(s, side * PIER_LATERAL_M)
			var road_y: float = pose.origin.y
			var height: float = maxf(road_y - BASE_Y - DECK_SIZE.y, 2.0)
			pose.origin = Vector3(pose.origin.x, BASE_Y + height * 0.5, pose.origin.z)
			pose.basis = Basis.IDENTITY.scaled(Vector3(2.4, height, 2.4))
			piers.append(pose)
		s += PIER_PITCH_M
	bridge_pier_poses = piers
	_multimesh("BridgePillars", deck_mesh, piers, ToonMaterials.make(Color("#8b8f99")))


# --- harbor --------------------------------------------------------------------------------------

func _build_harbor() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = SKYLINE_SEED + 7
	var per_color: Array[Array] = [[], [], []]
	var container_mesh := BoxMesh.new()
	container_mesh.size = Vector3.ONE
	for stack: int in range(6):
		var s: float = 1330.0 + float(stack) * 18.0
		var lateral: float = CRANE_LATERAL_M + 2.0
		for level: int in range(3):
			for row: int in range(3):
				var pose: Transform3D = ribbon.get_point_at_offset(s + float(row) * 6.4, lateral - float(level) * 2.8)
				pose.origin += Vector3.UP * (CONTAINER_SIZE.y * 0.5 + float(level) * CONTAINER_SIZE.y)
				pose.basis = pose.basis.scaled(CONTAINER_SIZE)
				per_color[rng.randi_range(0, per_color.size() - 1)].append(pose)
				container_count += 1
	for index: int in range(per_color.size()):
		var instance := _multimesh("HarborContainers%d" % index, container_mesh, per_color[index], ToonMaterials.make(CONTAINER_COLORS[index]))
		container_instances.append(instance)
	# Harbor crane geometry comes from the Blender kit, instanced under HeroLandmarksRoot.


## Two container gantry cranes over the stacks: four legs, a top beam and a trolley.
func _build_cranes() -> void:
	var batch := MeshBatchScript.new()
	var steel: Material = ToonMaterials.vertex_colored(false)
	for s: float in CRANE_S:
		var pose: Transform3D = ribbon.get_point_at_offset(s, CRANE_LATERAL_M)
		var basis: Basis = pose.basis
		var height: float = 22.0
		for side: float in [-1.0, 1.0]:
			for along: float in [-1.0, 1.0]:
				var foot: Vector3 = pose.origin + basis.x * (side * 5.0) + basis.z * (along * 4.0) + Vector3.UP * (height * 0.5)
				batch.box(steel, Color("#e86a1f"), Transform3D(basis, foot), Vector3(1.1, height, 1.1))
		var beam: Vector3 = pose.origin + Vector3.UP * (height + 0.6)
		batch.box(steel, Color("#e86a1f"), Transform3D(basis, beam), Vector3(12.0, 1.1, 2.0))
		var trolley: Vector3 = pose.origin + Vector3.UP * (height - 1.4) + basis.x * 3.4
		batch.box(steel, Color("#2f3742"), Transform3D(basis, trolley), Vector3(2.6, 1.6, 2.4))
	var cranes := MeshInstance3D.new()
	cranes.name = "HarborCranes"
	cranes.mesh = batch.commit()
	add_child(cranes)


# --- skyline -------------------------------------------------------------------------------------

## A deterministic ring of towers around the loop, clear of the circuit itself.
func _build_skyline() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = SKYLINE_SEED
	var track_points: PackedVector2Array = PackedVector2Array()
	var step: float = 20.0
	var s: float = 0.0
	while s < ribbon.length_m:
		var at: Vector3 = ribbon.get_point_at_offset(s, 0.0).origin
		track_points.append(Vector2(at.x, at.z))
		s += step
	var centre: Vector2 = Vector2.ZERO
	for point: Vector2 in track_points:
		centre += point
	centre /= float(track_points.size())
	var transforms: Array[Transform3D] = []
	var attempts: int = 0
	while skyline_buildings.size() < SKYLINE_COUNT and attempts < SKYLINE_COUNT * 12:
		attempts += 1
		var angle: float = rng.randf_range(0.0, TAU)
		var radius: float = rng.randf_range(SKYLINE_MIN_RADIUS_M, SKYLINE_MAX_RADIUS_M)
		var at: Vector2 = centre + Vector2(cos(angle), sin(angle)) * radius
		var clear: bool = true
		for point: Vector2 in track_points:
			if point.distance_to(at) < SKYLINE_TRACK_CLEARANCE_M:
				clear = false
				break
		if not clear:
			continue
		var width: float = rng.randf_range(14.0, 34.0)
		var depth: float = rng.randf_range(14.0, 34.0)
		var height: float = rng.randf_range(28.0, 145.0) * (0.75 + 0.5 * (radius - SKYLINE_MIN_RADIUS_M) / (SKYLINE_MAX_RADIUS_M - SKYLINE_MIN_RADIUS_M))
		var pose := Transform3D(Basis(), Vector3(at.x, BASE_Y + height * 0.5, at.y))
		pose.basis = pose.basis.scaled(Vector3(width, height, depth))
		transforms.append(pose)
		skyline_buildings.append({"position": pose.origin, "size": Vector3(width, height, depth)})
	var towers := BoxMesh.new()
	towers.size = Vector3.ONE
	_window_material = ShaderMaterial.new()
	_window_material.shader = SkylineShader
	var ink := ShaderMaterial.new()
	ink.shader = SkylineOutlineShader
	ink.render_priority = 1
	ink.set_shader_parameter("outline_width_m", SKYLINE_OUTLINE_M)
	_window_material.next_pass = ink
	skyline_instance = _multimesh("Skyline", towers, transforms, _window_material)
	skyline_instance.set_meta(&"towers", skyline_buildings.size())
	skyline_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


# --- sky ambience --------------------------------------------------------------------------------

## Moon, 900 twinkling stars and a ring of 28 cel clouds, centred over the circuit. All unshaded
## and shadow-free, one draw call each.
func _build_sky_ambience() -> void:
	var centre := Vector3.ZERO
	var samples: int = 0
	var s: float = 0.0
	while s < ribbon.length_m:
		centre += ribbon.get_point_at_offset(s, 0.0).origin
		samples += 1
		s += 100.0
	centre /= float(maxi(samples, 1))
	centre.y = 0.0
	sky_ambience_root.position = centre
	var rng := RandomNumberGenerator.new()
	rng.seed = SKYLINE_SEED + 13
	_build_moon()
	_build_stars(rng)
	_build_clouds(rng)


func _build_moon() -> void:
	var quad := QuadMesh.new()
	quad.size = Vector2(MOON_QUAD_M, MOON_QUAD_M)
	var material := ShaderMaterial.new()
	material.shader = MoonShader
	moon_instance = MeshInstance3D.new()
	moon_instance.name = "AnimeMoon"
	moon_instance.mesh = quad
	moon_instance.material_override = material
	moon_instance.position = MOON_OFFSET
	moon_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# The shader turns the flat quad to face the camera, so its AABB must not cull it edge-on.
	moon_instance.extra_cull_margin = MOON_QUAD_M
	sky_ambience_root.add_child(moon_instance)


func _build_stars(rng: RandomNumberGenerator) -> void:
	var quad := QuadMesh.new()
	quad.size = Vector2(STAR_QUAD_M, STAR_QUAD_M)
	var material := ShaderMaterial.new()
	material.shader = StarShader
	var low: float = sin(deg_to_rad(STAR_MIN_ELEVATION_DEG))
	var high: float = sin(deg_to_rad(STAR_MAX_ELEVATION_DEG))
	var poses: Array[Transform3D] = []
	for index: int in range(STAR_COUNT):
		# Uniform in sin(elevation) spreads the stars evenly over the dome instead of piling them at the zenith.
		var up: float = rng.randf_range(low, high)
		var ring: float = sqrt(1.0 - up * up)
		var azimuth: float = rng.randf_range(0.0, TAU)
		var at := Vector3(cos(azimuth) * ring, up, sin(azimuth) * ring) * STAR_DOME_RADIUS_M
		var size_scale: float = rng.randf_range(0.6, 1.5)
		poses.append(Transform3D(Basis.from_scale(Vector3.ONE * size_scale), at))
	star_instance = _multimesh("NightStars", quad, poses, material, [], true)
	var tints: Array[Color] = [Color.WHITE, Color("#bfe6ff"), Color("#ffe2c4")]
	for index: int in range(poses.size()):
		star_instance.multimesh.set_instance_color(index, tints[index % tints.size()])
	star_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	star_instance.reparent(sky_ambience_root, false)


func _build_clouds(rng: RandomNumberGenerator) -> void:
	var poses: Array[Transform3D] = []
	for index: int in range(CLOUD_COUNT):
		var azimuth: float = (float(index) + rng.randf_range(-0.3, 0.3)) / float(CLOUD_COUNT) * TAU
		var radius: float = rng.randf_range(CLOUD_MIN_RADIUS_M, CLOUD_MAX_RADIUS_M)
		var at := Vector3(cos(azimuth) * radius, rng.randf_range(CLOUD_MIN_HEIGHT_M, CLOUD_MAX_HEIGHT_M), sin(azimuth) * radius)
		var orientation := Basis(Vector3.UP, rng.randf_range(0.0, TAU)).scaled(Vector3.ONE * rng.randf_range(0.8, 1.7))
		poses.append(Transform3D(orientation, at))
	_cloud_base_poses = poses
	var material := ShaderMaterial.new()
	material.shader = CloudShader
	cloud_instance = _multimesh("AnimeNightClouds", _cloud_mesh(), poses, material)
	cloud_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	cloud_instance.reparent(sky_ambience_root, false)


## One cloud = three overlapping flattened puffs merged into a single surface: a wide body with a
## hump on each side. Low segment counts keep 28 of them near 8 000 triangles.
func _cloud_mesh() -> ArrayMesh:
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


## Twenty-four vertical banners on the bridge and harbor lamp poles, spread evenly over both
## sides; their flutter comes entirely from neo_wangan_wind_banner.gdshader.
func _build_wind_banners() -> void:
	var stations: Array[Vector2] = [] # x = arc length of a lamp pole, y = its side
	var s: float = 14.0
	while s < ribbon.length_m:
		var on_bridge: bool = s >= CircuitScript.BRIDGE_START_M and s <= CircuitScript.BRIDGE_END_M
		var in_harbor: bool = s >= CircuitScript.TUNNEL_END_M and s <= CircuitScript.HARBOR_HAIRPIN_S + 300.0
		if on_bridge or in_harbor:
			for side: float in [-1.0, 1.0]:
				stations.append(Vector2(s, side))
		s += LAMP_PITCH_M
	if stations.is_empty():
		return
	var poses: Array[Transform3D] = []
	for index: int in range(BANNER_COUNT):
		var station: Vector2 = stations[index * stations.size() / BANNER_COUNT]
		var pole: Transform3D = ribbon.get_point_at_offset(station.x, station.y * LAMP_LATERAL_M)
		var outward: Vector3 = Vector3(pole.basis.x.x, 0.0, pole.basis.x.z).normalized() * station.y
		# The pennant hangs outboard of the pole with its left edge pinned to it.
		var at: Vector3 = pole.origin + outward * (BANNER_SIZE.x * 0.5 + 0.2) + Vector3.UP * BANNER_HEIGHT_M
		poses.append(Transform3D(Basis(outward, Vector3.UP, outward.cross(Vector3.UP)), at))
	var mesh := BoxMesh.new()
	mesh.size = BANNER_SIZE
	_banner_shader_mat = ShaderMaterial.new()
	_banner_shader_mat.shader = WindBannerShader
	_banner_shader_mat.set_shader_parameter("wind_speed_kph", current_wind_kph)
	wind_banner_instance = _multimesh("WindBannersMM", mesh, poses, _banner_shader_mat, [], true)
	for index: int in range(poses.size()):
		wind_banner_instance.multimesh.set_instance_color(index, BANNER_COLORS[index % BANNER_COLORS.size()])
	wind_banner_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	wind_banner_instance.reparent(hero_landmarks_root, false)


# --- shared --------------------------------------------------------------------------------------

func _layer(node_name: String) -> Node3D:
	var layer := Node3D.new()
	layer.name = node_name
	add_child(layer)
	return layer


func _merged(parent: Node3D, node_name: String, batch: MeshBatchScript) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.name = node_name
	instance.mesh = batch.commit()
	parent.add_child(instance)
	return instance


## Continuous land strips, seawalls and cut-and-cover excavation; only the bridge exposes water.
func _build_urban_island() -> void:
	ground_spans = [Vector2(0.0, CircuitScript.BRIDGE_START_M), Vector2(CircuitScript.BRIDGE_END_M, ribbon.length_m)]
	# Raster union prevents a broad slab on one chicane leg from burying an adjacent lower road.
	var grid: Dictionary = {}
	const CELL: float = 5.0
	const RADIUS: int = 15
	for span: Vector2 in ground_spans:
		for sample: int in range(ceili(span.x), ceili(span.y) + 1, 4):
			var road: Vector3 = ribbon.get_point_at_offset(float(sample), 0.0).origin
			var centre := Vector2i(roundi(road.x / CELL), roundi(road.z / CELL))
			for dx: int in range(-RADIUS, RADIUS + 1):
				for dz: int in range(-RADIUS, RADIUS + 1):
					var key := centre + Vector2i(dx, dz)
					var distance_sq: float = Vector2(float(key.x) * CELL - road.x, float(key.y) * CELL - road.z).length_squared()
					if distance_sq > 72.0 * 72.0:
						continue
					var height: float = road.y - 0.15 if distance_sq < 14.0 * 14.0 else maxf(-0.35, road.y - 0.35)
					if not grid.has(key):
						grid[key] = Vector2(distance_sq, height)
					else:
						var old: Vector2 = grid[key]
						if distance_sq < old.x:
							grid[key] = Vector2(distance_sq, height)
	var ground := MeshBatchScript.new()
	var walls := MeshBatchScript.new()
	var plaza := MeshBatchScript.new()
	var material: Material = ToonMaterials.vertex_colored(false)
	for key: Vector2i in grid:
		var corners: Array[Vector2i] = [key, key + Vector2i(1, 0), key + Vector2i(1, 1), key + Vector2i(0, 1)]
		var points: Array[Vector3] = []
		var complete: bool = true
		for corner: Vector2i in corners:
			if not grid.has(corner):
				complete = false
				break
			points.append(Vector3(float(corner.x) * CELL, (grid[corner] as Vector2).y, float(corner.y) * CELL))
		if not complete:
			continue
		ground.quad(material, Color("#30394a"), points[0], points[1], points[2], points[3], Vector3.UP)
		for index: int in range(4):
			var neighbour: Vector2i = key + [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)][index]
			if grid.has(neighbour) and grid.has(neighbour + Vector2i(1, 1)) and grid.has(neighbour + Vector2i(1, 0)) and grid.has(neighbour + Vector2i(0, 1)):
				continue
			var a: Vector3 = points[index]
			var b: Vector3 = points[(index + 1) % 4]
			walls.quad(material, Color("#59667b"), a, b, Vector3(b.x, BASE_Y - 1.0, b.z), Vector3(a.x, BASE_Y - 1.0, a.z), (b - a).cross(Vector3.UP).normalized())
	_merged(urban_island_root, "UrbanGroundSlab", ground)
	_merged(urban_island_root, "QuayWalls", walls)
	var s: float = CircuitScript.TUNNEL_START_M
	while s < CircuitScript.TUNNEL_END_M:
		var pose: Transform3D = ribbon.get_point_at_offset(s + 3.0, 0.0)
		var roof_y: float = pose.origin.y + TUNNEL_CLEARANCE_M
		var thickness: float = maxf(0.7, 5.3 - roof_y)
		pose.basis = Basis(Vector3.UP, pose.basis.get_euler().y)
		pose.origin.y = 5.3 - thickness * 0.5
		plaza.box(material, Color("#596479"), pose, Vector3(32.0, thickness, 6.3))
		s += 6.0
	_merged(urban_island_root, "TunnelOverpassPlaza", plaza)


func _land_height(s: float) -> float:
	return maxf(-0.35, ribbon.get_point_at_offset(s, 0.0).origin.y - 0.35)


func _model_parts(filename: String) -> Array[Dictionary]:
	var scene: PackedScene = load(MODEL_DIR + filename + ".glb") as PackedScene
	var model: Node3D = scene.instantiate() as Node3D
	var parts: Array[Dictionary] = []
	for child: Node in model.find_children("*", "MeshInstance3D", true, false):
		var instance := child as MeshInstance3D
		# Godot's GLB import keeps COLOR_0 but disables its albedo flag; use our shared cel shader.
		var shell: bool = not instance.name.begins_with("WindowsMat")
		instance.mesh = instance.mesh.duplicate() as Mesh
		for surface: int in range(instance.mesh.get_surface_count()):
			instance.mesh.surface_set_material(surface, ToonMaterials.vertex_colored(shell))
		parts.append({"mesh": instance.mesh, "pose": instance.transform, "casts_shadow": shell})
	model.free()
	return parts


func _model_at(filename: String, node_name: String, s: float, lateral: float) -> Node3D:
	var scene: PackedScene = load(MODEL_DIR + filename + ".glb") as PackedScene
	var model: Node3D = scene.instantiate() as Node3D
	model.name = node_name
	var pose: Transform3D = ribbon.get_point_at_offset(s, lateral)
	# Foundations stay plumb while the road follows its independent grade.
	pose.basis = Basis(Vector3.UP, pose.basis.get_euler().y)
	model.transform = pose
	for child: Node in model.find_children("*", "MeshInstance3D", true, false):
		(child as MeshInstance3D).material_override = ToonMaterials.vertex_colored(true)
	hero_landmarks_root.add_child(model)
	model.set_meta(&"arc_s", s)
	return model


func _instanced_model(filename: String, node_name: String, poses: Array[Transform3D], parent: Node3D) -> void:
	var parts: Array[Dictionary] = _model_parts(filename)
	for index: int in range(parts.size()):
		var transformed: Array[Transform3D] = []
		for pose: Transform3D in poses:
			transformed.append(pose * (parts[index]["pose"] as Transform3D))
		var instance: MultiMeshInstance3D = _multimesh(node_name if index == 0 else node_name + "Detail", parts[index]["mesh"], transformed, null)
		if not bool(parts[index]["casts_shadow"]):
			instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		instance.reparent(parent, false)


func _build_hero_landmarks() -> void:
	var bridge_length: float = CircuitScript.BRIDGE_END_M - CircuitScript.BRIDGE_START_M
	var cables := MeshBatchScript.new()
	var cable_material: Material = ToonMaterials.vertex_colored(false)
	for index: int in range(2):
		var s: float = CircuitScript.BRIDGE_START_M + bridge_length * (0.3 + float(index) * 0.4)
		var pylon: Node3D = _model_at("shuto_bridge_pylon", "BridgePylon%d" % index, s, 0.0)
		pylon.position.y = BASE_Y
		# The exported module has straight-span cables; replace them with spline-anchored steel.
		var straight_cables: MeshInstance3D = pylon.find_child("StayCablesMat", true, false) as MeshInstance3D
		if straight_cables != null:
			straight_cables.hide()
		for side: float in [-1.0, 1.0]:
			var tower_top: Vector3 = pylon.transform * Vector3(side * 20.0, 61.0, 0.0)
			for direction: float in [-1.0, 1.0]:
				for stay: int in range(4):
					var anchor_s: float = s + direction * (24.0 + float(stay) * 13.0)
					var anchor: Vector3 = _at(anchor_s, side * 7.1, 0.7)
					cables.strut(cable_material, Color("#839bb8"), tower_top - Vector3.UP * float(stay) * 5.0, anchor, 0.14)
			cables.strut(cable_material, Color(0.0, 0.94, 1.0, 0.15), pylon.transform * Vector3(side * 18.0, 5.0, 0.0), tower_top, 0.32)
	_merged(hero_landmarks_root, "BridgeStayCables", cables)
	var truss := MeshBatchScript.new()
	var material: Material = ToonMaterials.vertex_colored(false)
	truss.truss(material, METAL, Vector3(0.0, 0.0, -3.0), Vector3(0.0, 0.0, 3.0), Vector3.UP, 1.6, 2, 0.12)
	var transforms: Array[Transform3D] = []
	var s: float = CircuitScript.BRIDGE_START_M
	while s < CircuitScript.BRIDGE_END_M:
		for side: float in [-1.0, 1.0]:
			var pose: Transform3D = ribbon.get_point_at_offset(s + 3.0, side * 7.1)
			pose.origin.y += 0.4
			transforms.append(pose)
		s += 6.0
	_multimesh("BridgeSideTrussMM", truss.commit(), transforms, null).reparent(hero_landmarks_root, false)
	for index: int in range(2):
		var portal_s: float = CircuitScript.TUNNEL_START_M if index == 0 else CircuitScript.TUNNEL_END_M
		var portal: Node3D = _model_at("tunnel_portal_overpass", "TunnelPortal%d" % index, portal_s, 0.0)
		if index == 1:
			portal.rotate_y(PI)
	for index: int in range(4):
		var crane_s: float = CircuitScript.HARBOR_HAIRPIN_S - 100.0 + float(index) * 52.0
		for lateral: float in [-55.0, 55.0, -65.0, 65.0]:
			var pose: Transform3D = ribbon.get_point_at_offset(crane_s, lateral)
			pose.basis = Basis(Vector3.UP, pose.basis.get_euler().y)
			pose.origin.y = _land_height(crane_s)
			if _building_clear(pose, Vector2(8.0, 10.0)):
				crane_poses.append(pose)
				break
	_instanced_model("harbor_gantry_crane", "HarborCraneMM", crane_poses, hero_landmarks_root)


## Check every road section: adjacent chicane legs must also clear building footprints.
func _building_clear(pose: Transform3D, half_size: Vector2) -> bool:
	var inverse: Transform3D = pose.affine_inverse()
	for along: int in range(0, ceili(ribbon.length_m), 5):
		var point: Vector3 = inverse * ribbon.get_point_at_offset(float(along), 0.0).origin
		if absf(point.x) < half_size.x + 8.0 and absf(point.z) < half_size.y + 8.0:
			return false
	return true


func _build_street_corridor() -> void:
	var per_model: Array[Array] = [[], [], []]
	var billboards: Array[Transform3D] = []
	var counter: int = 0
	for sample: int in range(52):
		var s: float = 170.0 + float(sample) * 55.0
		if s > CircuitScript.BRIDGE_START_M - 45.0 and s < CircuitScript.BRIDGE_END_M + 45.0:
			continue
		for side: float in [-1.0, 1.0]:
			var lateral: float = side * (24.0 + float(sample % 3) * 8.0)
			var pose: Transform3D = ribbon.get_point_at_offset(s, lateral)
			pose.basis = Basis(Vector3.UP, pose.basis.get_euler().y)
			pose.origin.y = _land_height(s)
			if not _building_clear(pose, Vector2(10.0, 9.0)):
				continue
			var harbor_clear: bool = true
			for crane_pose: Transform3D in crane_poses:
				if Vector2(pose.origin.x - crane_pose.origin.x, pose.origin.z - crane_pose.origin.z).length() < 32.0:
					harbor_clear = false
			if not harbor_clear:
				continue
			var variant: int = counter % 3
			per_model[variant].append(pose)
			near_track_buildings.append({"s": s, "lateral_m": lateral, "pose": pose, "variant": variant})
			if billboards.size() < 24:
				var board: Transform3D = ribbon.get_point_at_offset(s, side * 13.5)
				board.basis = Basis(Vector3.UP, board.basis.get_euler().y + side * PI * 0.5)
				board.origin.y = _land_height(s) + 6.5
				billboards.append(board)
			counter += 1
	for variant: int in range(3):
		# City-wide MultiMeshes keep every tower in every shadow/frustum submission; district bounds cull them.
		var districts: Dictionary = {}
		for pose: Transform3D in per_model[variant]:
			var district := Vector2i(floori(pose.origin.x / 300.0), floori(pose.origin.z / 300.0))
			if not districts.has(district):
				districts[district] = []
			(districts[district] as Array).append(pose)
		for district: Vector2i in districts:
			var poses: Array[Transform3D] = []
			poses.assign(districts[district])
			_instanced_model("skyscraper_tower_" + ["a", "b", "c"][variant], "CorridorTower%d_%d_%d" % [variant, district.x, district.y], poses, midground_corridor_root)
	# One box per sign; neo_wangan_billboard.gdshader paints the halftone, Kanji blocks and frame.
	var panel := BoxMesh.new()
	panel.size = Vector3(10.0, 5.5, 0.45)
	var sign_material := ShaderMaterial.new()
	sign_material.shader = BillboardShader
	var billboard_mm: MultiMeshInstance3D = _multimesh("StreetBillboardMM", panel, billboards, sign_material, [], true)
	var colors: Array[Color] = [Color("#00f0ff"), Color("#ff1e56"), Color("#ccff00")]
	for index: int in range(billboards.size()):
		billboard_mm.multimesh.set_instance_color(index, colors[index % 3])
	billboard_mm.reparent(midground_corridor_root, false)


func _multimesh(node_name: String, mesh: Mesh, transforms: Array, material: Material, lateral_data: Array[float] = [], colored: bool = false) -> MultiMeshInstance3D:
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_custom_data = not lateral_data.is_empty()
	multimesh.use_colors = colored
	multimesh.mesh = mesh
	multimesh.instance_count = transforms.size()
	for index: int in range(transforms.size()):
		multimesh.set_instance_transform(index, transforms[index])
		if not lateral_data.is_empty():
			multimesh.set_instance_custom_data(index, Color(lateral_data[index], 0.0, 0.0, 0.0))
	var instance := MultiMeshInstance3D.new()
	instance.name = node_name
	instance.multimesh = multimesh
	instance.material_override = material
	add_child(instance)
	return instance


func _apply_night_sky() -> void:
	var owner_environment: WorldEnvironment = null
	if _world_environment != null and _world_environment.environment != null:
		owner_environment = _world_environment
	elif get_parent() != null and get_parent().get_node_or_null("WorldEnvironment") != null:
		owner_environment = get_parent().get_node("WorldEnvironment") as WorldEnvironment
	if owner_environment == null or owner_environment.environment == null:
		return
	# Like Apex's _build_sky(), keep runtime sky/lighting out of the shared PackedScene resource.
	var environment: Environment = owner_environment.environment.duplicate() as Environment
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = NIGHT_TOP
	sky_material.sky_horizon_color = NIGHT_HORIZON
	sky_material.ground_horizon_color = NIGHT_HORIZON
	sky_material.ground_bottom_color = Color("#05070d")
	sky_material.sun_angle_max = 0.0
	var sky := Sky.new()
	sky.sky_material = sky_material
	environment.background_mode = Environment.BG_SKY
	environment.sky = sky
	# The city itself is the light source at night: a cool ambient wash plus a low moon, enough to
	# read the asphalt and the barriers without a light per street lamp.
	environment.ambient_light_energy = 0.85
	environment.fog_enabled = true
	environment.glow_enabled = true
	environment.fog_light_color = Color("#232c4a")
	environment.fog_density = 0.00055
	owner_environment.environment = environment
	if _sun != null:
		_sun.light_energy = 0.5
		_sun.light_color = Color("#9db4ff")
