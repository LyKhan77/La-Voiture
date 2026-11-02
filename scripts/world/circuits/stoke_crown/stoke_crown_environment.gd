class_name StokeCrownEnvironment
extends "res://scripts/world/circuits/base/circuit_environment.gd"

const Biome := preload("res://scripts/world/circuits/stoke_crown/stoke_crown_biome.gd")
const Look := preload("res://scripts/world/circuits/stoke_crown/stoke_crown_toon.gd")
const Lod := preload("res://scripts/world/circuits/stoke_crown/stoke_crown_lod.gd")
const Fence := preload("res://scripts/world/circuits/stoke_crown/stoke_crown_catch_fence.gd")
const Line := preload("res://scripts/car/adaptive_racing_line.gd")
const Surface := preload("res://scripts/world/shared/enhanced_track_geometry.gd")
const PitZone := preload("res://scripts/world/shared/pit_zone.gd")
const Toon := preload("res://scripts/world/shared/toon_materials.gd")
const SkyController := preload("res://scripts/world/shared/shared_cel_sky_controller.gd")
const PROFILES: Array[Dictionary] = [
	{"sun": Color("#e8ecef"), "sun_energy": 0.55, "sun_pitch": 48.0, "sun_yaw": -32.0, "ambient": Color("#ccd2d5"), "ambient_energy": 0.55, "fog": Color("#d6dcdd"), "fog_density": 0.0002, "sky_top": Color("#7d97ab"), "sky_horizon": Color("#d3d9d9"), "ground": Color("#31443f")},
	{"sun": Color("#ffae72"), "sun_energy": 0.65, "sun_pitch": 15.0, "sun_yaw": -65.0, "ambient": Color("#d8ab8f"), "ambient_energy": 0.55, "fog": Color("#e8bd97"), "fog_density": 0.00024, "sky_top": Color("#6f6694"), "sky_horizon": Color("#f3bd93"), "ground": Color("#31443f")},
	{"sun": Color("#a8c2ea"), "sun_energy": 0.3, "sun_pitch": 40.0, "sun_yaw": 90.0, "ambient": Color("#8fa7cf"), "ambient_energy": 0.45, "fog": Color("#1d2c48"), "fog_density": 0.00038, "sky_top": Color("#0e1b39"), "sky_horizon": Color("#365371"), "ground": Color("#05080f")},
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
	circuit_id = "stoke_crown"
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
	_build_surface()
	var zone := PitZone.from_layout(_pit.sim_layout(), ribbon.length_m, 70.0, 70.0)
	var hero_zones: Array[Dictionary] = [
		{"side": 1.0, "s0": 4950.0, "s1": ribbon.length_m, "lateral": 64.0},
		{"side": 1.0, "s0": 0.0, "s1": 310.0, "lateral": 64.0},
		{"side": -1.0, "s0": 0.0, "s1": 240.0, "lateral": 70.0},
		{"side": -1.0, "s0": 2030.0, "s1": 2280.0, "lateral": 85.0},
		{"side": -1.0, "s0": 3610.0, "s1": 3690.0, "lateral": 40.0},
		{"side": 1.0, "s0": 3610.0, "s1": 3690.0, "lateral": 40.0},
	]
	furniture = FurnitureScript.new()
	furniture.name = "TracksideFurniture"
	add_child(furniture)
	furniture.build(ribbon, line, kerbs, runoff_plans, hero_zones, zone)
	flag_panels = furniture.flag_panels
	Fence.build(self, ribbon, furniture, kerbs)
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
	var mesh := Surface.kerb_mesh(ribbon, kerbs, ribbon.road_half_width_m - Surface.KERB_INSET_M)
	if mesh != null:
		mesh.surface_set_material(0, Toon.make(Color("#d9232e")))
		mesh.surface_set_material(1, Toon.make(Color("#f0f2f5")))
		_add_mesh("SawtoothKerbs", mesh)
	var zone := PitZone.from_layout(_pit.sim_layout(), ribbon.length_m, 70.0, 70.0)
	runoff_plans = Surface.plan_runoffs(ribbon, kerbs, float(zone.start_s), float(zone.length_m))
	mesh = Surface.runoff_mesh(ribbon, runoff_plans)
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
	_sky_rig.apply(_world_environment, _sun, PROFILES[mode], sky_gloom, Color("#68747b"))
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
	return biome.stats if biome != null else {}

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
