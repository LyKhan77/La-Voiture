class_name ArdennesEnvironment
extends "res://scripts/world/circuits/base/circuit_environment.gd"

## The set of Ardennes Valley Ring (Round 05, GRAND_PRIX, FASE 16): a forest-and-stadium Grand Prix circuit climbing 104 m over a
## north summit and dropping into a stadium bowl. The ground is one heightfield (ArdennesTerrain) with a river valley beside the
## climb and a ridge ring on the horizon; the GP corridor is the shared Tier A kit (sawtooth kerbs, tarmac run-offs and gravel
## traps, FIA Armco, Tecpro, braking boards, floodlights and the digital flag panels); the pit complex (PitLane) owns the paddock
## kit. Tier B is the pine forest (ArdennesFoliage), the paddock's solid ground (ArdennesPaddock) and four hero landmarks
## (ArdennesLandmarks). Every element that repeats is one MultiMeshInstance3D, flat cel colours, one water shader.
##
## The acoustic canopy tunnel stands on the road and the flyover's deck crosses it (see ArdennesLandmarks); nothing of the corridor
## is built inside them.

const SharedSkyScript := preload("res://scripts/world/shared/shared_cel_sky_controller.gd")
const WeatherScript := preload("res://scripts/gt/gt_weather.gd")
const ToonMaterials := preload("res://scripts/world/shared/toon_materials.gd")
const SurfaceGeometry := preload("res://scripts/world/shared/enhanced_track_geometry.gd")
const PitZoneScript := preload("res://scripts/world/shared/pit_zone.gd")
const AdaptiveLineScript := preload("res://scripts/car/adaptive_racing_line.gd")
const Terrain := preload("res://scripts/world/circuits/ardennes/ardennes_terrain.gd")
const Landmarks := preload("res://scripts/world/circuits/ardennes/ardennes_landmarks.gd")
const Foliage := preload("res://scripts/world/circuits/ardennes/ardennes_foliage.gd")
const Paddock := preload("res://scripts/world/circuits/ardennes/ardennes_paddock.gd")
const PitComplex := preload("res://scripts/world/circuits/ardennes/ardennes_pit_complex.gd")
const CatchFence := preload("res://scripts/world/circuits/ardennes/ardennes_catch_fence.gd")

const KERB_CURVATURE: float = 0.006
const KERB_MIN_LENGTH_M: float = 14.0
const KERB_SCAN_STEP_M: float = 2.0
## A run ends where the curvature stays under KERB_CURVATURE for this long (a straight between two turns the same way).
const KERB_GAP_M: float = 6.0
const RED := Color("#d9232e")
const WHITE := Color("#f0f2f5")

## The pit asphalt's tails open the right-hand armco from before the first tail to after the last.
const PIT_ZONE_LEAD_M: float = PitComplex.TAIL_IN_M + 5.0
const PIT_ZONE_TRAIL_M: float = PitComplex.TAIL_OUT_M + 5.0
## Floodlight towers keep behind the paddock and the stands.
const PIT_SIDE_TOWER_LATERAL_M: float = 58.0
const STAND_SIDE_TOWER_LATERAL_M: float = 64.0
const FLYOVER_TOWER_LATERAL_M: float = 40.0
const NIGHT_SPOTS: int = 8

const SKY_SEED: int = 20261030
const DEFAULT_WIND_KPH: float = 12.0
const DEFAULT_WIND_DIR_RAD: float = 0.8
const STORM_GREY := Color("#59606c")
const FLOODLIGHT_GLOW: float = 4.0
const SUN_SHADOW_BLUR: float = 1.6
const VISTA_FAR_M: float = 4500.0
const BASE_PLANE_Y: float = -28.0

## Per time-of-day (DAY, SUNSET, NIGHT): sky, fog and sun for WorldSkyRig. Cool Ardennes blue-green by day, amber to violet
## at sunset, deep teal-blue at night.
const SKY_PROFILES: Array[Dictionary] = [
	{"sun": Color("#fff3da"), "sun_energy": 1.1, "sun_pitch": 48.0, "sun_yaw": 215.0,
		"ambient": Color("#b4cfe0"), "ambient_energy": 0.9, "fog": Color("#cfe4ec"), "fog_density": 0.00016,
		"sky_top": Color("#5aa1d8"), "sky_horizon": Color("#cfe7ef"), "ground": Color("#31443f")},
	{"sun": Color("#ffae72"), "sun_energy": 0.85, "sun_pitch": 15.0, "sun_yaw": 245.0,
		"ambient": Color("#c6a0b8"), "ambient_energy": 0.75, "fog": Color("#e8bd97"), "fog_density": 0.00024,
		"sky_top": Color("#6f6694"), "sky_horizon": Color("#f3bd93"), "ground": Color("#3a3038")},
	{"sun": Color("#a8c2ea"), "sun_energy": 0.35, "sun_pitch": 40.0, "sun_yaw": 215.0,
		"ambient": Color("#3a4a80"), "ambient_energy": 0.6, "fog": Color("#1d2c48"), "fog_density": 0.00038,
		"sky_top": Color("#0e1b39"), "sky_horizon": Color("#365371"), "ground": Color("#05080f")},
]
## River look per mode (deep, band, crest cyan and magenta, band and crest glow).
const RIVER_LOOKS: Array[Dictionary] = [
	{"deep_color": Color("#06384a"), "band_color": Color("#0d6373"), "neon_ripple_cyan": Color("#b7e6e6"), "neon_ripple_magenta": Color("#b7e6e6"), "band_emission": 0.28, "crest_emission": 0.08},
	{"deep_color": Color("#3c2a40"), "band_color": Color("#6a4656"), "neon_ripple_cyan": Color("#ffd0a3"), "neon_ripple_magenta": Color("#ffd0a3"), "band_emission": 0.28, "crest_emission": 0.08},
	{"deep_color": Color("#05182a"), "band_color": Color("#0f3149"), "neon_ripple_cyan": Color("#39a6b6"), "neon_ripple_magenta": Color("#39a6b6"), "band_emission": 0.28, "crest_emission": 0.2},
]

var builder
var terrain: Terrain
var terrain_instance: MeshInstance3D
var water_instance: MeshInstance3D
var landmarks: Landmarks
var foliage: Foliage
var line: AdaptiveLineScript
var sky_controller: SharedSkyScript
var kerbs: Array[Dictionary] = []
var runoff_plans: Array[Dictionary] = []
var paddock_footprints: Array[Dictionary] = []
## Catch fence panel and post poses (kept for tests; a headless MultiMesh keeps none).
var catch_fence: Dictionary = {}
var current_wind_kph: float = DEFAULT_WIND_KPH

var _pit: Node
var _pit_zone: Dictionary = {}
var _world_environment: WorldEnvironment
var _sun: DirectionalLight3D
var _camera: Camera3D
var _sky_rig := WorldSkyRig.new()
var _current_tod: Dictionary = {}
var _current_gloom: float = 0.0
var _clock_s: float = 0.0
var _jumbotron: Jumbotron
var _water_material: ShaderMaterial
var _night_spots: Node3D


func _init() -> void:
	circuit_id = "ardennes"
	_sky_rig.aces_tonemap = true
	_sky_rig.fog_sky_affect = 0.15


## Builds the whole set against the circuit's ribbon; `p_builder` is the ArdennesCircuitBuilder (its turns).
func build(p_ribbon: TrackRibbonScript, p_builder: Variant = null) -> void:
	if built:
		return
	built = true
	ribbon = p_ribbon
	builder = p_builder
	_pit = get_parent().get_node_or_null("PitLane")
	_jumbotron = get_parent().get_node_or_null("PitLane/MainGrandstand/Jumbotron") as Jumbotron
	_current_tod = WeatherScript.compute_time_of_day(WeatherScript.TimeOfDay.DAY, 0.0)
	var layout: Dictionary = _pit.call("sim_layout") if _pit != null else {}
	_pit_zone = PitZoneScript.from_layout(layout, ribbon.length_m, PIT_ZONE_LEAD_M, PIT_ZONE_TRAIL_M)
	line = AdaptiveLineScript.new(ribbon)
	_build_terrain()
	_build_paddock()
	_build_landmarks()
	_build_surface()
	_build_furniture()
	_build_foliage()
	_build_sky_ambience()
	apply_time_of_day(_current_tod, _current_gloom)
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


## The sky, the river and the pit lights follow the live time of day; the flag panels and jumbotron are fed by the world.
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


## DAY / SUNSET / NIGHT (GtWeather.time_of_day) and a storm gloom (0..1): sky, river, glass, floodlights, pit lights.
func apply_time_of_day(tod: Dictionary, gloom: float = 0.0) -> void:
	_current_tod = tod
	_current_gloom = gloom
	if sky_controller != null:
		sky_controller.apply_time_of_day(tod, gloom)
	var mode: int = SharedSkyScript.mode_of(tod)
	var night_factor: float = clampf(float(tod.get("floodlights", 0.0)), 0.0, 1.0)
	# Glow-masked vertices (floodlight lenses, LED bars, lit windows) light up with the floodlights.
	ToonMaterials.set_glow_energy(night_factor * FLOODLIGHT_GLOW)
	if landmarks != null:
		landmarks.set_night(night_factor)
	if _pit != null:
		if _pit.get("building") != null:
			(_pit.get("building") as ArdennesPitBuilding).set_night(night_factor)
		if _pit.has_method("set_lights_on"):
			_pit.call("set_lights_on", night_factor > 0.05 or gloom > 0.55)
	if _water_material != null:
		for key: String in RIVER_LOOKS[mode]:
			_water_material.set_shader_parameter(key, RIVER_LOOKS[mode][key])
	_apply_flood_spots(night_factor)
	_sky_rig.apply(_owner_environment(), _sun, SKY_PROFILES[mode], gloom, STORM_GREY)


func apply_wind(delta: float, wind_kph: float, wind_dir: float) -> void:
	current_wind_kph = wind_kph
	if _water_material != null:
		_water_material.set_shader_parameter("time_s", _clock_s)
		_water_material.set_shader_parameter("wind_speed_kph", wind_kph)
		_water_material.set_shader_parameter("wind_dir", Vector2(cos(wind_dir), sin(wind_dir)))
	if sky_controller != null:
		sky_controller.apply_wind(delta, wind_kph)
	if foliage != null:
		foliage.set_wind(clampf(wind_kph / 40.0, 0.1, 0.9), 1.0 + wind_kph / 25.0)


## Top of the solid ground under a world point: the heightfield (hillside, river bed, decks).
func ground_y_at(pos: Vector3) -> float:
	return terrain.height_at(pos.x, pos.z) if terrain != null else pos.y


## The strip zone at a world point, by the nearest road leg (ArdennesZones).
func zone_at_point(pos: Vector3) -> String:
	return terrain.zone_at_point(pos.x, pos.z) if terrain != null else "forest"


func _extra_stats() -> Dictionary:
	return {
		"terrain_triangles": terrain.triangle_count if terrain != null else 0,
		"trees": foliage.tree_count if foliage != null else 0,
		"rocks": foliage.rock_count if foliage != null else 0,
		"grass_tufts": foliage.tuft_count if foliage != null else 0,
		"landmarks": landmarks.records.size() if landmarks != null else 0,
		"armco_posts": furniture.armco_post_count if furniture != null else 0,
		"kerb_runs": kerbs.size(),
	}


# --- ground ---------------------------------------------------------------------------------------

func _build_terrain() -> void:
	terrain = Terrain.new()
	var platforms: Array[Dictionary] = []
	var rects: Array[Dictionary] = []
	if _pit != null and _pit.has_method("ground_platforms"):
		platforms.append_array(_pit.call("ground_platforms"))
	if _pit != null and _pit.has_method("ground_rects"):
		rects.append_array(_pit.call("ground_rects"))
	platforms.append_array(Landmarks.platforms())
	rects.append_array(Landmarks.stand_rects())
	terrain.build(ribbon, platforms, rects)
	terrain_instance = MeshInstance3D.new()
	terrain_instance.name = "Terrain"
	terrain_instance.mesh = terrain.terrain_mesh
	add_child(terrain_instance)
	water_instance = MeshInstance3D.new()
	water_instance.name = "River"
	water_instance.mesh = terrain.water_mesh
	water_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(water_instance)
	_water_material = terrain.water_mesh.surface_get_material(0) as ShaderMaterial
	_add_plain("TerrainSkirt", terrain.skirt_mesh)
	_add_plain("DistantRidge", terrain.ridge_mesh)
	var base := MeshInstance3D.new()
	base.name = "TerrainBase"
	var plane := PlaneMesh.new()
	plane.size = Vector2(8000.0, 8000.0)
	base.mesh = plane
	base.position.y = BASE_PLANE_Y
	base.material_override = ToonMaterials.make(Color("#3d5548"))
	base.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(base)


func _add_plain(node_name: String, mesh: ArrayMesh) -> void:
	var instance := MeshInstance3D.new()
	instance.name = node_name
	instance.mesh = mesh
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(instance)


func _build_paddock() -> void:
	paddock_footprints = Paddock.build(self, ribbon, terrain)


func _build_landmarks() -> void:
	landmarks = Landmarks.new()
	landmarks.name = "HeroLandmarks"
	add_child(landmarks)
	landmarks.build(ribbon, terrain)


func _build_foliage() -> void:
	foliage = Foliage.new()
	foliage.name = "Foliage"
	add_child(foliage)
	foliage.build(ribbon, terrain, Landmarks.keepouts(ribbon), furniture)


# --- Tier A corridor --------------------------------------------------------------------------------

## Sharp-corner runs: where the road's curvature passes KERB_CURVATURE for at least KERB_MIN_LENGTH_M. The corners that turn
## less than the builder's KERB_MIN_ANGLE_DEG (the kinks T2, T3, T4 and T11) get no kerbs, boards or Tecpro.
func _find_sharp_corners() -> Array[Dictionary]:
	var runs: Array[Dictionary] = []
	var current: Dictionary = {}
	var s: float = 0.0
	while s < ribbon.length_m:
		var k: float = ribbon.get_curvature_at(s)
		if absf(k) >= KERB_CURVATURE:
			var side: float = signf(k)
			if not current.is_empty() and is_equal_approx(float(current["side"]), side):
				current["s1"] = s + KERB_SCAN_STEP_M
			else:
				if not current.is_empty():
					runs.append(current)
				current = {"s0": s, "s1": s + KERB_SCAN_STEP_M, "side": side}
		elif not current.is_empty() and s - float(current["s1"]) > KERB_GAP_M:
			# The curvature dropped: the corner is over (a straight between two turns the same way is not kerbed).
			runs.append(current)
			current = {}
		s += KERB_SCAN_STEP_M
	if not current.is_empty():
		runs.append(current)
	var kept: Array[Dictionary] = []
	for run: Dictionary in runs:
		if float(run["s1"]) - float(run["s0"]) >= KERB_MIN_LENGTH_M and _turn_angle_at(0.5 * (float(run["s0"]) + float(run["s1"]))) >= _kerb_min_angle():
			kept.append(run)
	return kept


func _kerb_min_angle() -> float:
	return float(builder.KERB_MIN_ANGLE_DEG) if builder != null else 15.0


## The angle (degrees) of the turn whose span holds arc `s`; 0 on a straight.
func _turn_angle_at(s: float) -> float:
	if builder == null:
		return 90.0
	for turn: Dictionary in builder.turns:
		if absf(s - float(turn["s"])) <= float(turn["span_m"]) * 0.5 + 12.0:
			return float(turn["angle_deg"])
	return 0.0


func _build_surface() -> void:
	var surface_root := Node3D.new()
	surface_root.name = "SurfaceDetailRoot"
	add_child(surface_root)
	kerbs = _find_sharp_corners()
	var kerb_mesh: ArrayMesh = SurfaceGeometry.kerb_mesh(ribbon, kerbs, ribbon.road_half_width_m - SurfaceGeometry.KERB_INSET_M)
	if kerb_mesh != null:
		kerb_mesh.surface_set_material(0, ToonMaterials.make(RED))
		kerb_mesh.surface_set_material(1, ToonMaterials.make(WHITE))
		_add_mesh(surface_root, "SawtoothKerbs", kerb_mesh)
	runoff_plans = SurfaceGeometry.plan_runoffs(ribbon, kerbs, float(_pit_zone["start_s"]), float(_pit_zone["length_m"]))
	var runoff_mesh: ArrayMesh = SurfaceGeometry.runoff_mesh(ribbon, runoff_plans)
	if runoff_mesh != null and runoff_mesh.get_surface_count() >= 3:
		runoff_mesh.surface_set_material(0, ToonMaterials.make(SurfaceGeometry.RUNOFF_COLOR))
		runoff_mesh.surface_set_material(1, ToonMaterials.make(SurfaceGeometry.WARNING_BLUE))
		runoff_mesh.surface_set_material(2, ToonMaterials.make(WHITE))
		_add_mesh(surface_root, "TarmacRunoff", runoff_mesh)
	var gravel_mesh: ArrayMesh = SurfaceGeometry.gravel_mesh(ribbon, runoff_plans)
	if gravel_mesh != null and gravel_mesh.get_surface_count() >= 1:
		gravel_mesh.surface_set_material(0, ToonMaterials.make(SurfaceGeometry.GRAVEL_COLOR))
		_add_mesh(surface_root, "GravelTraps", gravel_mesh)
	var groove_material := StandardMaterial3D.new()
	groove_material.vertex_color_use_as_albedo = true
	groove_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	groove_material.roughness = 0.7
	groove_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	var groove_mesh: ArrayMesh = SurfaceGeometry.groove_mesh(ribbon, line)
	if groove_mesh != null:
		groove_mesh.surface_set_material(0, groove_material)
		var groove: MeshInstance3D = _add_mesh(surface_root, "RubberGroove", groove_mesh)
		groove.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _add_mesh(parent: Node3D, node_name: String, mesh: ArrayMesh) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.name = node_name
	instance.mesh = mesh
	parent.add_child(instance)
	return instance


## Armco, Tecpro, braking boards, floodlights and the digital flag panels (the shared kit), with the floodlights pushed behind
## the paddock, the stands and the flyover's stair tower.
func _build_furniture() -> void:
	var length: float = ribbon.length_m
	var pit_start: float = float(_pit_zone["start_s"])
	var pit_end: float = pit_start + float(_pit_zone["length_m"])
	var hero_zones: Array[Dictionary] = [
		{"side": 1.0, "s0": pit_start, "s1": minf(pit_end, length), "lateral": PIT_SIDE_TOWER_LATERAL_M},
		{"side": -1.0, "s0": 0.0, "s1": 260.0, "lateral": STAND_SIDE_TOWER_LATERAL_M},
		{"side": -1.0, "s0": Landmarks.STAND_S - 130.0, "s1": length, "lateral": STAND_SIDE_TOWER_LATERAL_M + 6.0},
		{"side": -1.0, "s0": Landmarks.FLYOVER_S - 30.0, "s1": Landmarks.FLYOVER_S + 30.0, "lateral": FLYOVER_TOWER_LATERAL_M},
	]
	if pit_end > length:
		hero_zones.append({"side": 1.0, "s0": 0.0, "s1": pit_end - length, "lateral": PIT_SIDE_TOWER_LATERAL_M})
	furniture = FurnitureScript.new()
	furniture.name = "TracksideFurniture"
	add_child(furniture)
	furniture.build(ribbon, line, kerbs, runoff_plans, hero_zones, _pit_zone)
	flag_panels = furniture.flag_panels
	catch_fence = CatchFence.build(self, ribbon, furniture, kerbs)


# --- sky --------------------------------------------------------------------------------------------

## Sun, moon, 900 stars and the ring of 28 cel clouds, built and driven by the shared controller.
func _build_sky_ambience() -> void:
	sky_controller = SharedSkyScript.new()
	sky_controller.build(self, ribbon, SKY_SEED, true)


func _owner_environment() -> WorldEnvironment:
	if _world_environment != null and _world_environment.environment != null:
		return _world_environment
	if get_parent() != null and get_parent().get_node_or_null("WorldEnvironment") != null:
		return get_parent().get_node("WorldEnvironment") as WorldEnvironment
	return null


## At sunset and at night eight of the floodlight towers throw a soft cone onto the track (no shadows: they are painted light).
func _apply_flood_spots(night_factor: float) -> void:
	if furniture == null:
		return
	if _night_spots == null:
		_night_spots = Node3D.new()
		_night_spots.name = "NightFloodSpots"
		add_child(_night_spots)
		var records: Array = furniture.tower_records
		var stride: int = maxi(1, records.size() / NIGHT_SPOTS)
		for index: int in range(0, mini(NIGHT_SPOTS * stride, records.size()), stride):
			var record: Dictionary = records[index]
			var spot := SpotLight3D.new()
			spot.light_color = Color(1.0, 0.93, 0.8)
			spot.spot_range = 110.0
			spot.spot_angle = 46.0
			spot.shadow_enabled = false
			_night_spots.add_child(spot)
			spot.position = (record["position"] as Vector3) + Vector3.UP * 17.2
			spot.look_at_from_position(spot.position, ribbon.get_point_at_offset(float(record["s"]), 0.0).origin, Vector3.UP)
	_night_spots.visible = night_factor > 0.05
	for spot: Node in _night_spots.get_children():
		(spot as SpotLight3D).light_energy = 5.2 * night_factor
