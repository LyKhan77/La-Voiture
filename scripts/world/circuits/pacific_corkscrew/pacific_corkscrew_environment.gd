class_name PacificCorkscrewEnvironment
extends "res://scripts/world/circuits/base/circuit_environment.gd"

## Pacific Coast Corkscrew environment: track corridor (toon asphalt, blue-white
## and red-white kerbs, runoff, gravel, rubber groove, armco/tecpro/boards,
## catch fence), the shared FIA paddock lighting and sky, the California
## chaparral biome and the three hero landmarks. DAY is the approved Bright
## California Midday Sun; SUNSET and NIGHT stay alive through the shared sky.

const Biome := preload("res://scripts/world/circuits/pacific_corkscrew/pacific_corkscrew_biome.gd")
const Layout := preload("res://scripts/world/circuits/pacific_corkscrew/pacific_corkscrew_layout.gd")
const Lod := preload("res://scripts/world/circuits/pacific_corkscrew/pacific_corkscrew_lod.gd")
const Fence := preload("res://scripts/world/circuits/pacific_corkscrew/pacific_corkscrew_catch_fence.gd")
const Line := preload("res://scripts/car/adaptive_racing_line.gd")
const Surface := preload("res://scripts/world/shared/enhanced_track_geometry.gd")
const PitZone := preload("res://scripts/world/shared/pit_zone.gd")
const Toon := preload("res://scripts/world/shared/toon_materials.gd")
const SkyController := preload("res://scripts/world/shared/shared_cel_sky_controller.gd")

## Bright California Midday Sun (approved): sun 68 degrees, #fff8e7 light,
## #4f97dd sky, marine-layer haze #cfd9e2. Sunset warms the marine layer; night
## keeps the same palette under a halftone moon.
const PROFILES: Array[Dictionary] = [
	{"sun": Color("#fff8e7"), "sun_energy": 1.05, "sun_pitch": 68.0, "sun_yaw": -35.0, "ambient": Color("#cfd9e2"), "ambient_energy": 0.55, "fog": Color("#cfd9e2"), "fog_density": 0.00014, "sky_top": Color("#4f97dd"), "sky_horizon": Color("#cfd9e2"), "ground": Color("#6d5b3f")},
	{"sun": Color("#ffb26e"), "sun_energy": 0.8, "sun_pitch": 14.0, "sun_yaw": -72.0, "ambient": Color("#e0b18e"), "ambient_energy": 0.55, "fog": Color("#e8c19a"), "fog_density": 0.00022, "sky_top": Color("#6a6a9c"), "sky_horizon": Color("#f5c18f"), "ground": Color("#5d4a33")},
	{"sun": Color("#a8c2ea"), "sun_energy": 0.3, "sun_pitch": 42.0, "sun_yaw": 95.0, "ambient": Color("#8fa7cf"), "ambient_energy": 0.45, "fog": Color("#1d2c48"), "fog_density": 0.00036, "sky_top": Color("#0e1b39"), "sky_horizon": Color("#365371"), "ground": Color("#05080f")},
]

var biome: Biome
var line: Line
var shared_sky: SkyController
var kerbs: Array[Dictionary] = []
var runoff_plans: Array[Dictionary] = []
var _world_environment: WorldEnvironment
var _sun: DirectionalLight3D
var _camera: Camera3D
var _sky_rig := WorldSkyRig.new()
var _tod: Dictionary = {"mode": 0, "floodlights": 0.0, "stars_opacity": 0.0}
var _gloom: float = 0.0
var _pit: Node3D
var _screens: Array = []
var _wind_materials: Array[ShaderMaterial] = []
var _glow_materials: Array[ShaderMaterial] = []
var _light_level: float = -1.0


func _init() -> void:
	circuit_id = "pacific_corkscrew"
	_sky_rig.aces_tonemap = true
	_sky_rig.fog_sky_affect = 0.35


func build(p_ribbon: TrackRibbonScript, source: Variant = null) -> void:
	if built:
		return
	ribbon = p_ribbon
	_pit = get_parent().get_node("PitLane")
	line = Line.new(ribbon)
	biome = Biome.new()
	biome.name = "Biome"
	add_child(biome)
	biome.build(ribbon, source.compiled)
	print("[pacific-env] biome done")
	_build_surface()
	print("[pacific-env] surface done")
	var zone := PitZone.from_layout(_pit.sim_layout(), ribbon.length_m, 70.0, 70.0)
	var hero_zones: Array[Dictionary] = [
		{"side": 1.0, "s0": 0.0, "s1": 300.0, "lateral": 64.0},
		{"side": -1.0, "s0": 0.0, "s1": 240.0, "lateral": 70.0},
		{"side": -1.0, "s0": 280.0, "s1": 360.0, "lateral": 42.0},
		{"side": 1.0, "s0": 2720.0, "s1": 2790.0, "lateral": 40.0},
		{"side": -1.0, "s0": 2800.0, "s1": 2920.0, "lateral": 90.0},
	]
	furniture = FurnitureScript.new()
	furniture.name = "TracksideFurniture"
	add_child(furniture)
	furniture.build(ribbon, line, kerbs, runoff_plans, hero_zones, zone)
	print("[pacific-env] furniture done")
	flag_panels = furniture.flag_panels
	Fence.build(self, ribbon, furniture, kerbs)
	print("[pacific-env] fence done")
	Lod.optimize_armco(furniture)
	Lod.optimize_floodlights(furniture)
	Lod.optimize_crowd(_pit)
	shared_sky = SkyController.new()
	shared_sky.build(self, ribbon, 20261031)
	var stand := _pit.get_node("MainGrandstand")
	var screen := stand.find_child("Jumbotron", true, false)
	if screen != null:
		_screens.append(screen)
	for node: Node in biome.find_children("*", "MultiMeshInstance3D", true, false):
		var instance := node as MultiMeshInstance3D
		if instance.material_override is ShaderMaterial:
			_wind_materials.append(instance.material_override)
	_collect_glow_materials(self)
	_collect_glow_materials(_pit)
	built = true
	apply_time_of_day(_tod)


func _build_surface() -> void:
	var current: Dictionary = {}
	for i: int in range(0, ceili(ribbon.length_m), 2):
		var s := float(i)
		var curvature := ribbon.get_curvature_at(s)
		if absf(curvature) >= 0.006:
			if not current.is_empty() and is_equal_approx(float(current.side), signf(curvature)) and s - float(current.s1) < 6.0:
				current.s1 = s + 2.0
			else:
				if not current.is_empty() and float(current.s1) - float(current.s0) >= 14.0:
					kerbs.append(current)
				current = {"s0": s, "s1": s + 2.0, "side": signf(curvature)}
	if not current.is_empty() and float(current.s1) - float(current.s0) >= 14.0:
		kerbs.append(current)
	_build_kerbs()
	var zone := PitZone.from_layout(_pit.sim_layout(), ribbon.length_m, 70.0, 70.0)
	runoff_plans = Surface.plan_runoffs(ribbon, kerbs, float(zone.start_s), float(zone.length_m))
	var mesh := Surface.runoff_mesh(ribbon, runoff_plans)
	if mesh != null and mesh.get_surface_count() >= 3:
		mesh.surface_set_material(0, Toon.make(Surface.RUNOFF_COLOR))
		mesh.surface_set_material(1, Toon.make(Surface.WARNING_BLUE))
		mesh.surface_set_material(2, Toon.make(Color("#f0f2f5")))
		_add_mesh("TarmacRunoff", mesh)
	mesh = Surface.gravel_mesh(ribbon, runoff_plans)
	if mesh != null:
		mesh.surface_set_material(0, Toon.make(Surface.GRAVEL_COLOR))
		_add_mesh("GravelTraps", mesh)
	add_child(Surface.groove_instance(ribbon, line, 1.0))


## Four approved kerb runs; the Pacific Ridge / Corkscrew stretch (s 2100..3148)
## runs blue-white, every other run keeps FIA red-white.
func _build_kerbs() -> void:
	var blue: Array[Dictionary] = []
	var classic: Array[Dictionary] = []
	for run: Dictionary in kerbs:
		for piece: Dictionary in _split_kerb_run(run):
			var mid: float = (float(piece["s0"]) + float(piece["s1"])) * 0.5
			if mid >= Layout.KERB_BLUE_S0 and mid < Layout.KERB_BLUE_S1:
				blue.append(piece)
			else:
				classic.append(piece)
	var inset: float = ribbon.road_half_width_m - Surface.KERB_INSET_M
	_add_kerb_group("SawtoothKerbsPacific", blue, inset, Color("#1f5fbf"))
	_add_kerb_group("SawtoothKerbsClassic", classic, inset, Surface.KERB_RED)


func _split_kerb_run(run: Dictionary) -> Array[Dictionary]:
	var s0: float = float(run["s0"])
	var s1: float = float(run["s1"])
	var cuts: Array[float] = [s0, s1]
	for boundary: float in [Layout.KERB_BLUE_S0, Layout.KERB_BLUE_S1]:
		if boundary > s0 and boundary < s1:
			cuts.append(boundary)
	cuts.sort()
	var pieces: Array[Dictionary] = []
	for index in range(cuts.size() - 1):
		pieces.append({"s0": cuts[index], "s1": cuts[index + 1], "side": float(run["side"])})
	return pieces


func _add_kerb_group(node_name: String, runs: Array[Dictionary], inset: float, color: Color) -> void:
	if runs.is_empty():
		return
	var mesh: ArrayMesh = Surface.kerb_mesh(ribbon, runs, inset)
	if mesh == null:
		return
	mesh.surface_set_material(0, Toon.make(color))
	mesh.surface_set_material(1, Toon.make(Surface.KERB_WHITE))
	_add_mesh(node_name, mesh)


func _add_mesh(node_name: String, mesh: Mesh) -> void:
	var node := MeshInstance3D.new()
	node.name = node_name
	node.mesh = mesh
	add_child(node)


func bind_world(world_environment: WorldEnvironment, sun: DirectionalLight3D, camera: Camera3D) -> void:
	_world_environment = world_environment
	_sun = sun
	_camera = camera
	if camera != null:
		camera.far = maxf(camera.far, 5000.0)
	if sun != null:
		sun.shadow_enabled = true
		sun.shadow_blur = 1.6
	apply_time_of_day(_tod, _gloom)


func apply_time_of_day(tod: Dictionary, gloom: float = 0.0) -> void:
	_tod = tod
	_gloom = gloom
	var mode := SkyController.mode_of(tod)
	var sky_gloom := maxf(gloom, 0.5 if mode == 0 else 0.0)
	_sky_rig.apply(_world_environment, _sun, PROFILES[mode], sky_gloom, Color("#8d8478"))
	if shared_sky != null:
		shared_sky.apply_time_of_day(tod, sky_gloom)
	var floodlights := float(tod.get("floodlights", 0.0))
	if not is_equal_approx(_light_level, floodlights):
		_light_level = floodlights
		Toon.set_glow_energy(floodlights * 0.8)
		for material: ShaderMaterial in _glow_materials:
			material.set_shader_parameter("glow_energy", floodlights * 0.8)
	if _pit != null:
		_pit.set_lights_on(floodlights > 0.1)


func apply_wind(delta: float, wind_kph: float, wind_dir: float) -> void:
	if shared_sky != null:
		shared_sky.apply_wind(delta, wind_kph)
	for material: ShaderMaterial in _wind_materials:
		material.set_shader_parameter("wind_strength", clampf(wind_kph / 100.0, 0.04, 0.5))
		material.set_shader_parameter("wind_direction", Vector2(cos(wind_dir), sin(wind_dir)))


func update(delta: float, race) -> void:
	if race == null:
		return
	var weather = race.weather
	apply_time_of_day(weather.time_of_day, maxf(sqrt(weather.rain_intensity), weather.track_water_pct / 100.0))
	apply_wind(delta, weather.wind_speed, weather.wind_direction)
	_feed_leaderboards(delta, race, _screens)


func ground_y_at(pos: Vector3) -> float:
	return biome.terrain.height_at(pos.x, pos.z) if biome != null else pos.y


func _extra_stats() -> Dictionary:
	var result: Dictionary = biome.stats.duplicate() if biome != null else {}
	result["kerb_runs"] = kerbs.size()
	return result


func _collect_glow_materials(node: Node) -> void:
	if node is MeshInstance3D:
		var instance := node as MeshInstance3D
		if instance.mesh != null:
			for surface: int in range(instance.mesh.get_surface_count()):
				var material := instance.get_active_material(surface) as ShaderMaterial
				if material != null and material.shader != null and material.shader.code.contains("uniform float glow_energy") and not _glow_materials.has(material):
					_glow_materials.append(material)
	for child: Node in node.get_children():
		_collect_glow_materials(child)
