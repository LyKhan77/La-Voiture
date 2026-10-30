class_name MonteAzureEnvironment
extends "res://scripts/world/circuits/base/circuit_environment.gd"

## The set of Monte Azure Marina (Round 04, SPRINT, FASE 15): a Riviera harbour street circuit. A heightfield with the sea
## around it (MonteAzureTerrain), concrete street barriers and low street kerbs, streetlamps, braking boards and flag
## panels along the road; the pit complex (PitLane) owns the paddock kit. The set is the Neo-Wangan street corridor on
## Brianza's terrain: every element that repeats is one MultiMeshInstance3D, flat cel colours, one water shader.
##
## Tunnel and skybridge stand on the road (see MonteAzureLandmarks); the corridor leaves them clear.

const RibbonGeometry := preload("res://scripts/world/shared/ribbon_geometry.gd")
const MeshBatchScript := preload("res://scripts/world/shared/mesh_batch.gd")
const ToonMaterials := preload("res://scripts/world/shared/toon_materials.gd")
const RibbonScript := preload("res://scripts/car/track_ribbon.gd")
const SharedSkyScript := preload("res://scripts/world/shared/shared_cel_sky_controller.gd")
const WeatherScript := preload("res://scripts/gt/gt_weather.gd")
const TracksideKit := preload("res://scripts/world/shared/trackside_furniture_builder.gd")
const Terrain := preload("res://scripts/world/circuits/monte_azure/monte_azure_terrain.gd")
const Landmarks := preload("res://scripts/world/circuits/monte_azure/monte_azure_landmarks.gd")
const Districts := preload("res://scripts/world/circuits/monte_azure/monte_azure_districts.gd")
const Foliage := preload("res://scripts/world/circuits/monte_azure/monte_azure_foliage.gd")
const PitComplex := preload("res://scripts/world/circuits/monte_azure/monte_azure_pit_complex.gd")
const WaterShader := preload("res://shaders/neo_wangan_water.gdshader")
const PoolShader := preload("res://shaders/neo_wangan_light_pool.gdshader")

## Street barrier: concrete blocks behind the 0.3 m edge verge; the right-hand run opens for the pit lane.
const BARRIER_LATERAL_M: float = 6.2
const BARRIER_STEP_M: float = 3.0
const BARRIER_SIZE := Vector3(0.55, 1.05, 2.9)
const HAZARD_STEP_M: float = 6.0
const HAZARD_CURVATURE: float = 0.006

const KERB_SIZE := Vector3(1.25, 0.06, 2.2)
const KERB_STEP_M: float = 2.4
const KERB_RUN_IN_M: float = 8.0
const KERB_INSET_M: float = 0.65

const LAMP_PITCH_M: float = 42.0
const LAMP_LATERAL_M: float = 6.9
const LAMP_HEIGHT_M: float = 9.0
const LAMP_FIRST_S: float = 14.0
const BOARD_LATERAL_M: float = 7.0
const BOARD_DISTANCES_M: Array[float] = [150.0, 100.0, 50.0]

## Flag panel centre: behind the barrier's back face (6.2 + 0.275) with a post's width to spare.
const PANEL_LATERAL_M: float = 7.6
const PANEL_POLE_CLEAR_M: float = 2.0
const PANEL_BOARD_CLEAR_M: float = 8.0
const PANEL_SHIFT_M: float = 9.0
const PANEL_SHIFT_TRIES: int = 8

## The cliff tunnel (centred s=1330, 150 m) and the skybridge (s=2180) stand on the road: no barrier, lamp, board or panel in them.
const TUNNEL_S0: float = 1255.0
const TUNNEL_S1: float = 1405.0
const SKYBRIDGE_S: float = 2180.0
const ZONE_MARGIN_M: float = 25.0
const SKYBRIDGE_HALF_M: float = 14.0

const SKY_SEED: int = 20260404
const DEFAULT_WIND_KPH: float = 12.0
const DEFAULT_WIND_DIR_RAD: float = 0.8
const STORM_GREY := Color("#59606c")
const METAL := Color("#454c5a")
const LAMP_HEAD := Color("#fff0c8")

## Per time-of-day (DAY, SUNSET, NIGHT): sky, fog and sun for WorldSkyRig. Riviera blue by day, gold-to-violet at sunset.
const SKY_PROFILES: Array[Dictionary] = [
	{"sun": Color("#fff3db"), "sun_energy": 1.15, "sun_pitch": 40.0, "sun_yaw": 205.0,
		"ambient": Color("#a3c2f0"), "ambient_energy": 0.9, "fog": Color("#d4e6f5"), "fog_density": 0.00018,
		"sky_top": Color("#2f7fe0"), "sky_horizon": Color("#bfe0fa"), "ground": Color("#6f95ad")},
	{"sun": Color("#ff9a5c"), "sun_energy": 0.85, "sun_pitch": 13.0, "sun_yaw": 240.0,
		"ambient": Color("#b49ad0"), "ambient_energy": 0.75, "fog": Color("#e0a58f"), "fog_density": 0.00026,
		"sky_top": Color("#3b2a6b"), "sky_horizon": Color("#ff9a4d"), "ground": Color("#4a3040")},
	{"sun": Color("#9db4ff"), "sun_energy": 0.35, "sun_pitch": 38.0, "sun_yaw": 205.0,
		"ambient": Color("#3a4a80"), "ambient_energy": 0.6, "fog": Color("#18244a"), "fog_density": 0.00040,
		"sky_top": Color("#050b1e"), "sky_horizon": Color("#1c2a52"), "ground": Color("#06080f")},
]
const SUN_SHADOW_BLUR: float = 1.6
const VISTA_FAR_M: float = 4500.0
const FLOODLIGHT_GLOW: float = 4.0

var builder
var terrain: Terrain
var terrain_instance: MeshInstance3D
var landmarks: Landmarks
var districts: Districts
var foliage: Foliage
var water_instance: MeshInstance3D
var sky_controller: SharedSkyScript
var barrier_instance: MultiMeshInstance3D
var streetlight_instance: MultiMeshInstance3D
var streetlight_pools_instance: MultiMeshInstance3D
var barrier_count: int = 0
var streetlight_count: int = 0
var kerb_count: int = 0
var board_count: int = 0
## Poses kept for tests: a headless MultiMesh keeps no transforms.
var barrier_poses: Array[Transform3D] = []
var kerb_poses: Array[Transform3D] = []
var tunnel_lamp_poses: Array[Transform3D] = []
var lamp_arcs: Array[Vector2] = [] # x = arc, y = side
var board_arcs: Array[Vector3] = [] # x = arc, y = side, z = turn number

var current_wind_kph: float = DEFAULT_WIND_KPH
var _world_environment: WorldEnvironment
var _sun: DirectionalLight3D
var _camera: Camera3D
var _water_material: ShaderMaterial
var _lamp_material: StandardMaterial3D
var _tunnel_lamp_material: StandardMaterial3D
var _pool_material: ShaderMaterial
var _sky_rig := WorldSkyRig.new()
var _current_tod: Dictionary = {}
var _current_gloom: float = 0.0
var _clock_s: float = 0.0
var _jumbotron: Jumbotron
var _pit: Node


func _init() -> void:
	circuit_id = "monte_azure"
	_sky_rig.aces_tonemap = true
	_sky_rig.fog_sky_affect = 0.15


## Builds the whole set against the circuit's ribbon; `p_builder` is the MonteAzureCircuitBuilder (its turns).
func build(p_ribbon: TrackRibbonScript, p_builder: Variant = null) -> void:
	ribbon = p_ribbon
	builder = p_builder
	_pit = get_parent().get_node_or_null("PitLane")
	_jumbotron = get_parent().get_node_or_null("PitLane/MainGrandstand/Jumbotron") as Jumbotron
	_current_tod = WeatherScript.compute_time_of_day(WeatherScript.TimeOfDay.DAY, 0.0)
	_build_terrain()
	_build_landmarks()
	_build_dressing()
	_build_sea()
	_build_barriers()
	_build_kerbs()
	_build_streetlights()
	_build_tunnel_lamps()
	_build_braking_boards()
	_build_flag_panels()
	_build_sky_ambience()
	apply_time_of_day(_current_tod, _current_gloom)
	built = true
	measure()


func bind_world(world_environment: WorldEnvironment, sun: DirectionalLight3D, camera: Camera3D) -> void:
	_world_environment = world_environment
	_sun = sun
	_camera = camera
	if camera != null:
		camera.far = maxf(camera.far, VISTA_FAR_M)
	if sun != null:
		sun.shadow_enabled = true
		sun.shadow_blur = SUN_SHADOW_BLUR
	apply_time_of_day(_current_tod, _current_gloom)


## Lamps and the pit lights follow the live time of day; the flag panels and jumbotron are fed by the world.
func update(delta: float, race) -> void:
	_clock_s += delta
	var wind_kph: float = DEFAULT_WIND_KPH
	var wind_dir: float = DEFAULT_WIND_DIR_RAD
	var tod: Dictionary = _current_tod
	var gloom: float = _current_gloom
	if race != null and race.get("weather") != null:
		var weather: GtWeather = race.weather
		wind_kph = float(weather.wind_speed)
		wind_dir = float(weather.wind_direction)
		if not weather.time_of_day.is_empty():
			tod = weather.time_of_day
		gloom = maxf(clampf(sqrt(weather.rain_intensity), 0.0, 1.0), weather.track_water_pct / 100.0)
	apply_time_of_day(tod, gloom)
	apply_wind(delta, wind_kph, wind_dir)
	_feed_leaderboards(delta, race, [_jumbotron] if _jumbotron != null else [])


## DAY / SUNSET / NIGHT (GtWeather.time_of_day) and a storm gloom (0..1): sky, sea, lamps, pit lights.
func apply_time_of_day(tod: Dictionary, gloom: float = 0.0) -> void:
	_current_tod = tod
	_current_gloom = gloom
	if sky_controller != null:
		sky_controller.apply_time_of_day(tod, gloom)
	var mode: int = SharedSkyScript.mode_of(tod)
	var night_factor: float = clampf(float(tod.get("floodlights", 0.0)), 0.0, 1.0)
	# Glow-masked vertices (garage glass and LEDs) light up with the floodlights.
	ToonMaterials.set_glow_energy(night_factor * FLOODLIGHT_GLOW)
	if districts != null:
		districts.set_night(night_factor)
	if _water_material != null:
		match mode:
			0:
				_set_params(_water_material, {"deep_color": Color("#0f6f93"), "band_color": Color("#27a3c8"),
					"neon_ripple_cyan": Color("#e8fbff"), "neon_ripple_magenta": Color("#bdefff"),
					"band_emission": 0.06, "crest_emission": 0.2})
			1:
				_set_params(_water_material, {"deep_color": Color("#3a2c63"), "band_color": Color("#c4663f"),
					"neon_ripple_cyan": Color("#ffd29a"), "neon_ripple_magenta": Color("#ff8f6b"),
					"band_emission": 0.14, "crest_emission": 0.45})
			_:
				_set_params(_water_material, {"deep_color": Color("#06142a"), "band_color": Color("#0d3151"),
					"neon_ripple_cyan": Color("#7fd8ff"), "neon_ripple_magenta": Color("#ffb86b"),
					"band_emission": 0.2, "crest_emission": 0.6})
	# Off in clear daylight; on at dusk, at night, or under a heavy storm gloom.
	var lamp_level: float = maxf(night_factor, gloom * 0.7 if gloom > 0.55 else 0.0)
	if _lamp_material != null:
		_lamp_material.emission_energy_multiplier = 2.6 * lamp_level
	if _tunnel_lamp_material != null:
		_tunnel_lamp_material.emission_energy_multiplier = 1.8 + 1.4 * night_factor
	if streetlight_pools_instance != null:
		streetlight_pools_instance.visible = lamp_level > 0.05
	if _pool_material != null:
		_pool_material.set_shader_parameter("intensity", 0.5 * lamp_level)
	if _pit != null and _pit.has_method("set_lights_on"):
		_pit.call("set_lights_on", lamp_level > 0.05)
	_apply_sky_for_tod(mode, gloom)


func apply_wind(delta: float, wind_kph: float, wind_dir: float) -> void:
	current_wind_kph = wind_kph
	if _water_material != null:
		_water_material.set_shader_parameter("time_s", _clock_s)
		_water_material.set_shader_parameter("wind_speed_kph", wind_kph)
		_water_material.set_shader_parameter("wind_dir", Vector2(cos(wind_dir), sin(wind_dir)))
	if sky_controller != null:
		sky_controller.apply_wind(delta, wind_kph)
	if foliage != null:
		foliage.set_wind(clampf(wind_kph / 60.0, 0.03, 0.3), 1.2 + wind_kph / 25.0, Vector2(cos(wind_dir), sin(wind_dir)))


## Top of the solid ground under a world point: the heightfield (quay, hillside, seabed).
func ground_y_at(pos: Vector3) -> float:
	return terrain.height_at(pos.x, pos.z) if terrain != null else pos.y


## The strip zone at a world point, by the nearest road leg (MonteAzureZones).
func zone_at_point(pos: Vector3) -> String:
	return terrain.zone_at_point(pos.x, pos.z) if terrain != null else "paddock"


func _extra_stats() -> Dictionary:
	return {
		"terrain_triangles": terrain.triangle_count if terrain != null else 0,
		"barriers": barrier_count,
		"kerbs": kerb_count,
		"streetlights": streetlight_count,
		"braking_boards": board_count,
	}


# --- ground and sea -----------------------------------------------------------------------------

func _build_terrain() -> void:
	terrain = Terrain.new()
	var platforms: Array[Dictionary] = []
	if _pit != null and _pit.has_method("ground_platforms"):
		platforms.append_array(_pit.call("ground_platforms"))
	platforms.append_array(Landmarks.platforms())
	terrain.build(ribbon, platforms, [] as Array[Dictionary])
	terrain_instance = MeshInstance3D.new()
	terrain_instance.name = "Terrain"
	terrain_instance.mesh = terrain.make_mesh()
	add_child(terrain_instance)


## The five heroes: casino, hotel, cliff tunnel, yachts, skybridge.
func _build_landmarks() -> void:
	landmarks = Landmarks.new()
	landmarks.name = "HeroLandmarks"
	add_child(landmarks)
	landmarks.build(ribbon, terrain.height_at)


## The town and the vegetation, placed by the nearest road leg (see Districts and Foliage).
func _build_dressing() -> void:
	districts = Districts.new()
	districts.name = "Districts"
	add_child(districts)
	districts.build(ribbon, terrain)
	foliage = Foliage.new()
	foliage.name = "Foliage"
	add_child(foliage)
	foliage.build(ribbon, terrain)


## The harbour: one stepped-toon water plane at y=0 over the whole bay, driven by the wind.
func _build_sea() -> void:
	_water_material = ShaderMaterial.new()
	_water_material.shader = WaterShader
	_water_material.set_shader_parameter("band_length_m", 24.0)
	_water_material.set_shader_parameter("crest_share", 0.03)
	_water_material.set_shader_parameter("wind_speed_kph", current_wind_kph)
	water_instance = MeshInstance3D.new()
	water_instance.name = "Sea"
	var plane := PlaneMesh.new()
	plane.size = Vector2(6000.0, 6000.0)
	water_instance.mesh = plane
	water_instance.material_override = _water_material
	water_instance.position = Vector3(0.0, Terrain.SEA_Y, 0.0)
	water_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(water_instance)


# --- street corridor ----------------------------------------------------------------------------

func _in_tunnel(s: float, margin: float = 0.0) -> bool:
	return s >= TUNNEL_S0 - margin and s <= TUNNEL_S1 + margin


func _on_skybridge(s: float, margin: float = 0.0) -> bool:
	return absf(s - SKYBRIDGE_S) <= SKYBRIDGE_HALF_M + margin


## The right-hand run is open for the pit entry, the pit wall and the exit merge: a car leaving the lane is still on the
## road's edge at the exit mouth (lateral 5.2), so the barrier resumes 40 m after it.
func _in_pit_gap(s: float) -> bool:
	var from: float = PitComplex.ENTRY_S - 25.0
	var until: float = PitComplex.EXIT_S + 40.0
	return fposmod(s - from, ribbon.length_m) <= fposmod(until - from, ribbon.length_m)


func _build_barriers() -> void:
	var transforms: Array[Transform3D] = []
	var hazard: Array[Transform3D] = []
	var length: float = ribbon.length_m
	var s: float = 0.0
	while s < length:
		if not _in_tunnel(s) and not _on_skybridge(s):
			for side: float in [-1.0, 1.0]:
				if side > 0.0 and _in_pit_gap(s):
					continue
				transforms.append(RibbonGeometry.box_transform(ribbon, s, side * BARRIER_LATERAL_M, BARRIER_SIZE, 0.0))
		s += BARRIER_STEP_M
	s = 0.0
	while s < length:
		if absf(ribbon.get_curvature_at(s)) >= HAZARD_CURVATURE and not _in_tunnel(s):
			for side: float in [-1.0, 1.0]:
				if side > 0.0 and _in_pit_gap(s):
					continue
				hazard.append(RibbonGeometry.box_transform(ribbon, s, side * BARRIER_LATERAL_M, Vector3(0.6, 0.1, 2.2), BARRIER_SIZE.y))
		s += HAZARD_STEP_M
	barrier_poses = transforms
	barrier_count = transforms.size()
	var mesh := BoxMesh.new()
	mesh.size = Vector3.ONE
	barrier_instance = _multimesh("ConcreteBarriers", mesh, transforms, ToonMaterials.make(Color("#b9bdc7")))
	_multimesh("BarrierHazardCaps", mesh, hazard, ToonMaterials.make(Color("#ffd400")))
	barrier_instance.set_meta(&"fia_barrier", true)


## Low street kerbs on the inside of every turn that turns 15 degrees or more: red and white blocks 60 mm proud of the
## asphalt, a run-in before and after the arc, one MultiMesh per colour.
func _build_kerbs() -> void:
	var reds: Array[Transform3D] = []
	var whites: Array[Transform3D] = []
	for turn: Dictionary in _kerbed_turns():
		# direction is +1 for a right turn, whose inside is the right-hand (+) side.
		var lateral: float = float(turn["direction"]) * (float(ribbon.road_half_width_m) - KERB_INSET_M)
		var half_span: float = float(turn["span_m"]) * 0.5 + KERB_RUN_IN_M
		var apex: float = float(turn["apex_s"][0])
		var count: int = maxi(4, int(half_span * 2.0 / KERB_STEP_M))
		for index: int in range(count):
			var at: float = fposmod(apex - half_span + KERB_STEP_M * float(index), ribbon.length_m)
			if _in_tunnel(at) or _on_skybridge(at):
				continue
			var pose: Transform3D = RibbonGeometry.box_transform(ribbon, at, lateral, KERB_SIZE, 0.0)
			if index % 2 == 0:
				reds.append(pose)
			else:
				whites.append(pose)
	kerb_poses = reds + whites
	kerb_count = kerb_poses.size()
	var mesh := BoxMesh.new()
	mesh.size = Vector3.ONE
	_multimesh("KerbsRed", mesh, reds, ToonMaterials.make(Color("#d9232e")))
	_multimesh("KerbsWhite", mesh, whites, ToonMaterials.make(Color("#f4f5f7")))


func _kerbed_turns() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if builder == null:
		return result
	for turn: Dictionary in builder.turns:
		if float(turn["angle_deg"]) >= float(builder.KERB_MIN_ANGLE_DEG):
			result.append(turn)
	return result


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
	var transforms: Array[Transform3D] = []
	var s: float = LAMP_FIRST_S
	while s < ribbon.length_m:
		if not _in_tunnel(s, 6.0) and not _on_skybridge(s, 6.0):
			for side: float in [-1.0, 1.0]:
				if side > 0.0 and _in_pit_gap(s):
					continue
				transforms.append(ribbon.get_point_at_offset(s, side * LAMP_LATERAL_M))
				lamp_arcs.append(Vector2(s, side))
		s += LAMP_PITCH_M
	streetlight_count = transforms.size()
	streetlight_instance = _multimesh("Streetlights", batch.commit(), transforms, ToonMaterials.make(METAL))
	_lamp_material = StandardMaterial3D.new()
	_lamp_material.albedo_color = LAMP_HEAD
	_lamp_material.emission_enabled = true
	_lamp_material.emission = LAMP_HEAD
	_multimesh("StreetlightHeads", heads.commit(), transforms, _lamp_material)
	_build_light_pools(transforms)


## Two rows of lamp strips under the cliff tunnel's roof every 9 m; a tunnel is lit by day too, brighter at night.
func _build_tunnel_lamps() -> void:
	var poses: Array[Transform3D] = []
	var s: float = TUNNEL_S0 + 5.0
	while s <= TUNNEL_S1 - 5.0:
		for lateral: float in [-3.2, 3.2]:
			var pose: Transform3D = ribbon.get_point_at_offset(s, lateral)
			pose.origin += pose.basis.y * 6.7
			poses.append(pose)
		s += 9.0
	tunnel_lamp_poses = poses
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.45, 0.12, 1.6)
	_tunnel_lamp_material = StandardMaterial3D.new()
	_tunnel_lamp_material.albedo_color = LAMP_HEAD
	_tunnel_lamp_material.emission_enabled = true
	_tunnel_lamp_material.emission = LAMP_HEAD
	_tunnel_lamp_material.emission_energy_multiplier = 1.8
	var lamps: MultiMeshInstance3D = _multimesh("TunnelLamps", mesh, poses, _tunnel_lamp_material)
	lamps.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


## The warm pool each lamp throws across the asphalt: one additive quad per lamp, painted rather than cast.
func _build_light_pools(lamp_transforms: Array[Transform3D]) -> void:
	var quad := QuadMesh.new()
	quad.size = Vector2(9.0, 5.5)
	var pools: Array[Transform3D] = []
	var laterals: Array[float] = []
	for index: int in range(lamp_transforms.size()):
		var side: float = lamp_arcs[index].y
		var road: Transform3D = ribbon.get_point_at_offset(lamp_arcs[index].x, side * 3.2)
		pools.append(Transform3D(road.basis * Basis(Vector3.UP, PI * 0.5) * Basis(Vector3.RIGHT, -PI * 0.5), road.origin + Vector3.UP * 0.04))
		laterals.append(side * 3.2)
	_pool_material = ShaderMaterial.new()
	_pool_material.shader = PoolShader
	_pool_material.set_shader_parameter("pool_color", Color("#ffcf8a"))
	_pool_material.set_shader_parameter("intensity", 0.0)
	_pool_material.set_shader_parameter("clip_to_road", true)
	streetlight_pools_instance = _multimesh("StreetlightPools", quad, pools, _pool_material, laterals)
	streetlight_pools_instance.visible = false


## 150 / 100 / 50 m braking boards on the outside of every kerbed turn.
func _build_braking_boards() -> void:
	var source := TracksideKit.new()
	var mesh: ArrayMesh = source._marker_mesh()
	source.free()
	var poses: Array[Transform3D] = []
	var distances: Array[float] = []
	for turn: Dictionary in _kerbed_turns():
		var apex: float = float(turn["apex_s"][0])
		var side: float = -float(turn["direction"])
		for distance: float in BOARD_DISTANCES_M:
			var s: float = fposmod(apex - distance, ribbon.length_m)
			if _in_tunnel(s, 6.0) or _on_skybridge(s, 6.0) or (side > 0.0 and _in_pit_gap(s)):
				continue
			poses.append(ribbon.get_point_at_offset(s, side * BOARD_LATERAL_M))
			distances.append(distance)
			board_arcs.append(Vector3(s, side, float(turn["number"])))
	board_count = poses.size()
	_multimesh("BrakingMarkers", mesh, poses, null, distances)


## Digital flag panels behind the barrier on the outside of the tightest turns and before the finish line; never in the
## tunnel, on the skybridge, on the open pit side, on a lamp pole or a braking board.
func _build_flag_panels() -> void:
	var turns: Array[Dictionary] = _kerbed_turns()
	turns.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["radius_m"]) < float(b["radius_m"]))
	var preferred: Array[Dictionary] = []
	for turn: Dictionary in turns:
		preferred.append({"s": float(turn["apex_s"][0]) - FlagPanelSet.LEAD_M, "side": -float(turn["direction"])})
	var anchors: Array[Dictionary] = FlagPanelSet.plan(ribbon.length_m, preferred)
	var poses: Array[Transform3D] = []
	for anchor: Dictionary in anchors:
		var side: float = float(anchor["side"])
		var s: float = _panel_clear_arc(float(anchor["s"]), side)
		if side > 0.0 and _in_pit_gap(s):
			side = -1.0
			s = _panel_clear_arc(s, side)
		anchor["s"] = s
		anchor["side"] = side
		poses.append(ribbon.get_point_at_offset(s, side * PANEL_LATERAL_M))
	flag_panels = FlagPanelSet.new()
	flag_panels.name = "FlagPanels"
	flag_panels.build(ribbon.length_m, anchors, poses)
	add_child(flag_panels)


func _panel_clear_arc(s: float, side: float) -> float:
	var wrapped: float = fposmod(s, ribbon.length_m)
	for _attempt: int in range(PANEL_SHIFT_TRIES):
		wrapped = _panel_clear_of_zones(wrapped)
		if not _panel_blocked_by_boards(wrapped, side):
			break
		wrapped = fposmod(wrapped + PANEL_SHIFT_M, ribbon.length_m)
	return wrapped


func _panel_blocked_by_boards(s: float, side: float) -> bool:
	for board: Vector3 in board_arcs:
		if board.y == side and _arc_gap(s, board.x) < PANEL_BOARD_CLEAR_M:
			return true
	return false


func _arc_gap(a: float, b: float) -> float:
	return absf(fposmod(a - b + ribbon.length_m * 0.5, ribbon.length_m) - ribbon.length_m * 0.5)


## `s` moved out of the tunnel and off the skybridge, and off the lamp poles.
func _panel_clear_of_zones(s: float) -> float:
	var wrapped: float = fposmod(s, ribbon.length_m)
	if _in_tunnel(wrapped, ZONE_MARGIN_M):
		wrapped = TUNNEL_S0 - ZONE_MARGIN_M if wrapped < (TUNNEL_S0 + TUNNEL_S1) * 0.5 else TUNNEL_S1 + ZONE_MARGIN_M
	if _on_skybridge(wrapped, ZONE_MARGIN_M):
		wrapped = SKYBRIDGE_S - SKYBRIDGE_HALF_M - ZONE_MARGIN_M if wrapped < SKYBRIDGE_S else SKYBRIDGE_S + SKYBRIDGE_HALF_M + ZONE_MARGIN_M
	var from_pole: float = fposmod(wrapped - LAMP_FIRST_S, LAMP_PITCH_M)
	if from_pole < PANEL_POLE_CLEAR_M or from_pole > LAMP_PITCH_M - PANEL_POLE_CLEAR_M:
		wrapped += 2.0 * PANEL_POLE_CLEAR_M
	return fposmod(wrapped, ribbon.length_m)


# --- sky ----------------------------------------------------------------------------------------

## Sun, moon, 900 stars and the ring of 28 cel clouds, built and driven by the shared controller.
func _build_sky_ambience() -> void:
	sky_controller = SharedSkyScript.new()
	sky_controller.build(self, ribbon, SKY_SEED, true)


static func _set_params(material: ShaderMaterial, values: Dictionary) -> void:
	for key: String in values:
		material.set_shader_parameter(key, values[key])


## The WorldEnvironment's sky, fog and sun follow the time of day (see WorldSkyRig).
func _apply_sky_for_tod(mode: int, gloom: float) -> void:
	var owner_environment: WorldEnvironment = null
	if _world_environment != null and _world_environment.environment != null:
		owner_environment = _world_environment
	elif get_parent() != null and get_parent().get_node_or_null("WorldEnvironment") != null:
		owner_environment = get_parent().get_node("WorldEnvironment") as WorldEnvironment
	_sky_rig.apply(owner_environment, _sun, SKY_PROFILES[mode], gloom, STORM_GREY)


# --- shared -------------------------------------------------------------------------------------

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
