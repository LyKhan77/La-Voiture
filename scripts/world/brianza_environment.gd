class_name BrianzaEnvironment
extends Node3D

## Autodromo di Brianza Environment (FASE 13): 2-Tier Architecture combining Tier A Reusable
## Core Kit (Trackside Furniture, Kerbs, Runoff, Gravel, Rubber Groove, Shared Cel Skybox) with
## Tier B Improvised Monza Biome (Parco Reale stone pines & cypresses, the monumental Sopraelevata
## 1950s banked oval overpass viaduct, Villa Reale gate, and Torre Ascari).
##
## All repeating furniture and trees use MultiMeshInstance3D for GPU instancing (< 140 draw calls).

const RibbonScript := preload("res://scripts/car/track_ribbon.gd")
const AdaptiveLineScript := preload("res://scripts/car/adaptive_racing_line.gd")
const CircuitBuilderScript := preload("res://scripts/world/brianza_circuit_builder.gd")
const FurnitureScript := preload("res://scripts/world/trackside_furniture_builder.gd")
const SurfaceGeometry := preload("res://scripts/world/enhanced_track_geometry.gd")
const SharedSkyScript := preload("res://scripts/world/shared_cel_sky_controller.gd")
const ToonMaterials := preload("res://scripts/world/toon_materials.gd")
const MeshBatchScript := preload("res://scripts/world/mesh_batch.gd")
const WeatherScript := preload("res://scripts/gt/gt_weather.gd")
const JumbotronScript := preload("res://scripts/world/paddock/jumbotron.gd")
const Liveries := preload("res://scripts/car/team_liveries.gd")

const SERRAGLIO_OVERPASS_S: float = 3450.0
const ASCARI_TOWER_S: float = 4150.0
const VILLA_GATE_S: float = 5600.0

const SOPRA_ARC_M: float = 480.0
const SOPRA_RADIUS_M: float = 320.0
const SOPRA_BANK_DEG: float = 28.0
const SOPRA_YAW_DEG: float = 25.0
const SOPRA_WIDTH_M: float = 14.0
const SOPRA_THICKNESS_M: float = 1.8
const SOPRA_CLEARANCE_M: float = 13.5
## Portal positions as a share of the half arc: two either side of the crossing.
const BoardFont := preload("res://assets/fonts/BarlowCondensed.ttf")
const BRAKE_CORNERS: Array[String] = ["Variante del Rettifilo", "Variante della Roggia", "Variante Ascari"]
const BRAKE_DISTANCES_M: Array[int] = [200, 150, 100, 50]
const SPONSOR_STEP_M: float = 110.0
const SPONSORS: Array[Dictionary] = [
	{"node": "Pirelli", "text": "PIRELLI", "ground": Color("#ffd400"), "band": Color("#d9232e"), "ink": Color("#14161c")},
	{"node": "Brembo", "text": "BREMBO", "ground": Color("#d9232e"), "band": Color("#f0f2f5"), "ink": Color("#f0f2f5")},
	{"node": "Agip", "text": "AGIP", "ground": Color("#ffd400"), "band": Color("#14161c"), "ink": Color("#14161c")},
	{"node": "MagnetiMarelli", "text": "MAGNETI MARELLI", "ground": Color("#2b5fb8"), "band": Color("#f0f2f5"), "ink": Color("#f0f2f5")},
]
const HazeShader := preload("res://shaders/brianza_vista_haze.gdshader")
const VISTA_FAR_M: float = 6500.0
const VISTA_BASE_Y: float = -40.0
## A flank rises from this far inside the crest radius per metre of height; steep enough that the layers never overlap.
const VISTA_FLANK_RUN: float = 0.12

const SUN_SHADOW_BLUR: float = 1.6
const FLOODLIGHT_GLOW: float = 4.0
const STORM_GREY := Color("#4a5260")
## Forest line, Montevecchia hills, Alpine foothills: radius, crest height range, ridge noise, colour, haze.
const VISTA_LAYERS: Array[Dictionary] = [
	{"radius": 4300.0, "height": Vector2(50.0, 120.0), "freq": 11.0, "segments": 360, "color": Color("#1d4a2c"), "haze": 0.06, "snow": 0.0},
	{"radius": 4420.0, "height": Vector2(220.0, 480.0), "freq": 2.6, "segments": 180, "color": Color("#3f6f78"), "haze": 0.18, "snow": 0.0},
	{"radius": 4550.0, "height": Vector2(500.0, 1050.0), "freq": 1.7, "segments": 180, "color": Color("#6f8fb8"), "haze": 0.34, "snow": 0.85},
]
## Per time-of-day (DAY, SUNSET, NIGHT): sun, ambient, fog and sky colours; sun angles in degrees.
const SKY_PROFILES: Array[Dictionary] = [
	{"sun": Color("#fff3db"), "sun_energy": 1.15, "sun_pitch": 42.0, "sun_yaw": 215.0,
		"ambient": Color("#a3c2f0"), "ambient_energy": 0.9, "fog": Color("#dce8f5"), "fog_density": 0.00018,
		"sky_top": Color("#3f7fd0"), "sky_horizon": Color("#cfe3f5"), "ground": Color("#7fa06a")},
	{"sun": Color("#ff9a5c"), "sun_energy": 0.85, "sun_pitch": 14.0, "sun_yaw": 235.0,
		"ambient": Color("#b49ad0"), "ambient_energy": 0.75, "fog": Color("#e0a58f"), "fog_density": 0.00026,
		"sky_top": Color("#4a3a78"), "sky_horizon": Color("#ff9a5c"), "ground": Color("#3a2f3f")},
	{"sun": Color("#9db4ff"), "sun_energy": 0.35, "sun_pitch": 38.0, "sun_yaw": 215.0,
		"ambient": Color("#3a4a80"), "ambient_energy": 0.6, "fog": Color("#1b2540"), "fog_density": 0.00034,
		"sky_top": Color("#060a18"), "sky_horizon": Color("#1a2342"), "ground": Color("#05070d")},
]
const PINE_MIN_DEPTH_M: float = 18.5
const STAND_FOOTPRINT_DEPTH_M: float = 44.0
const SOPRA_FOLIAGE_CLEAR_M: float = 24.0
const SOPRA_PORTAL_THETAS: Array[float] = [-0.88, -0.30, 0.30, 0.88]

const CORNER_STAND_LATERAL_M: float = 50.0
const CORNER_TIER_DEPTH_M: float = 4.2
const CORNER_TIER_RISE_M: float = 2.4
const CORNER_CROWD_STEP_M: float = 1.8
const CROWD_SHIRTS: Array[Color] = [Color("#d9232e"), Color("#f0f2f5"), Color("#2f8f46"), Color("#ffd400"), Color("#2b5fb8"), Color("#22262e")]
## The Jumbotrons repaint from the live standings this often (seconds).
const JUMBOTRON_PERIOD_S: float = 0.5

const KERB_CURVATURE: float = 0.006
const KERB_MIN_LENGTH_M: float = 14.0
const KERB_SCAN_STEP_M: float = 2.0

const RED := Color("#d9232e")
const WHITE := Color("#f0f2f5")

# Layer 1: park ground. Verge strips follow the road down to the field, which sits GROUND_DROP_M
# below the nearest road and fades to the park floor (y = 0) away from the circuit.
const GROUND_SIZE_M := Vector2(4200.0, 3600.0)
const GROUND_CELL_M: float = 48.0
const GROUND_DROP_M: float = 2.4
const GROUND_FADE_NEAR_M: float = 80.0
const GROUND_FADE_FAR_M: float = 500.0
const GROUND_SAMPLE_STEP_M: float = 20.0
const VERGE_STEP_M: float = 8.0
const VERGE_LATERAL_M: Array[float] = [7.3, 12.0, 40.0, 80.0]
const VERGE_DROP_M: Array[float] = [-0.10, -0.30, -1.20, -2.40]
const GRASS_TONES: Array[Color] = [Color("#3c7a38"), Color("#33692f"), Color("#478743")]
const GRAVEL_PATH := Color("#8c7e63")
const PARK_WALL_BRICK := Color("#a3483b")
const PARK_WALL_CAP := Color("#d4d0c7")
const PARK_WALL_HEIGHT_M: float = 3.2
const PARK_WALL_MARGIN_M: float = 380.0

var ribbon: RibbonScript
var builder: CircuitBuilderScript
var line: AdaptiveLineScript
var furniture: FurnitureScript
var shared_sky: SharedSkyScript
var sopraelevata: Node3D
var tree_multimeshes: Array[MultiMeshInstance3D] = []
var built: bool = false
var kerbs: Array[Dictionary] = []
var runoff_plans: Array[Dictionary] = []
var ground_root: Node3D

## Instance poses of each foliage batch by node name (headless MultiMeshes keep none).
var foliage_poses: Dictionary = {}
## Catch fence panel poses (kept for tests; headless MultiMeshes keep none).
var catch_fence_poses: Array[Transform3D] = []

var _foliage_keepouts: Array[Dictionary] = []
var _stand_footprints: Array[Dictionary] = []
var _sopra_blockers: PackedVector3Array = PackedVector3Array()
var vista_ring: MeshInstance3D

var _world_environment: WorldEnvironment
var _sun: DirectionalLight3D
var _camera: Camera3D
var _runtime_environment: Environment
var _sky_material: ProceduralSkyMaterial
var _vista_materials: Array[ShaderMaterial] = []
var _current_tod: Dictionary = {"mode": 0, "floodlights": 0.0, "stars_opacity": 0.0}
var _current_gloom: float = 0.0
var _ascari_screen: Jumbotron
var _main_screen: Jumbotron
var _jumbotron_clock: float = 0.0

var _track_pos: PackedVector3Array = PackedVector3Array()
var _track_centre: Vector2 = Vector2.ZERO
var _track_half: Vector2 = Vector2.ZERO
var _field_origin: Vector2 = Vector2.ZERO
var _field_cols: int = 0
var _field_rows: int = 0
var _field_y: PackedFloat32Array = PackedFloat32Array()


func build(p_ribbon: RibbonScript, p_builder: CircuitBuilderScript) -> void:
	if built:
		return
	built = true
	ribbon = p_ribbon
	builder = p_builder
	line = AdaptiveLineScript.new(ribbon)
	
	_build_layer1_ground_massing()
	_build_tier_a_surface()
	_build_tier_a_furniture()
	_build_tier_a_sky()
	_build_layer2_sopraelevata_monumental()
	_build_tier_b_landmarks()
	_build_layer3_corner_grandstands()
	_build_layer4_dense_park_foliage()
	_build_layer5_trackside_safety_and_sponsors()
	_build_layer6_vista_ring()


## The race world hands its own sky, sun and camera to the set: golden Monza afternoon by default,
## then DAY / SUNSET / NIGHT through apply_time_of_day().
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


func update(delta: float, race) -> void:
	if shared_sky != null and race != null and race.get("weather") != null:
		var weather = race.weather
		var wind_kph: float = float(weather.wind_speed) if "wind_speed" in weather else 14.0
		shared_sky.apply_wind(delta, wind_kph)
		var gloom: float = 0.0
		if "rain_intensity" in weather and "track_water_pct" in weather:
			gloom = maxf(clampf(sqrt(weather.rain_intensity), 0.0, 1.0), weather.track_water_pct / 100.0)
		elif "gloom" in weather:
			gloom = float(weather.gloom)
		var tod = weather.time_of_day if "time_of_day" in weather else {}
		if tod is Dictionary and not tod.is_empty():
			apply_time_of_day(tod, gloom)
	_feed_jumbotrons(delta, race)


## The Ascari screen plus the pit complex's main-stand screen (looked up once, then cached).
func _screens() -> Array[Jumbotron]:
	if _main_screen == null and get_parent() != null:
		_main_screen = get_parent().get_node_or_null("PitLane/MainGrandstand/Jumbotron") as Jumbotron
	var screens: Array[Jumbotron] = []
	for screen: Jumbotron in [_main_screen, _ascari_screen]:
		if screen != null:
			screens.append(screen)
	return screens


## Both screens (main stand + Ascari) show the live order, leader first.
func _feed_jumbotrons(delta: float, race) -> void:
	_jumbotron_clock += delta
	if race == null or _jumbotron_clock < JUMBOTRON_PERIOD_S:
		return
	_jumbotron_clock = 0.0
	var screens: Array[Jumbotron] = _screens()
	if screens.is_empty():
		return
	var colors: Array[Color] = []
	var values: Array[float] = []
	var order: Array = race.standings()
	for row: int in range(mini(order.size(), Jumbotron.ROWS)):
		colors.append(Liveries.color_for(order[row].team_id))
		values.append(1.0 - 0.08 * float(row))
	for screen: Jumbotron in screens:
		screen.set_leaderboard(colors, values)


func apply_time_of_day(tod, gloom: float = 0.0) -> void:
	_current_tod = tod
	_current_gloom = gloom
	if shared_sky != null:
		shared_sky.apply_time_of_day(tod, gloom)
	var mode: int = SharedSkyScript.mode_of(tod)
	var night: float = clampf(float(tod.get("floodlights", 0.0)), 0.0, 1.0)
	ToonMaterials.set_glow_energy(night * FLOODLIGHT_GLOW)
	ToonMaterials.glass().emission_energy_multiplier = night * 1.1
	for screen: Jumbotron in _screens():
		screen.set_brightness(1.0 + 0.35 * night)
	var profile: Dictionary = SKY_PROFILES[mode]
	_apply_sky_and_sun(profile, gloom)
	for material: ShaderMaterial in _vista_materials:
		material.set_shader_parameter("haze_color", (profile["fog"] as Color).lerp(STORM_GREY, gloom * 0.5))
		material.set_shader_parameter("ridge_light", profile["sun"])
		material.set_shader_parameter("brightness", lerpf(1.0, 0.3, night) * lerpf(1.0, 0.7, gloom))
		material.set_shader_parameter("haze_strength", lerpf(1.0, 0.8, night))


## Sky, ambient, fog and sun for the mode. The shared Environment is duplicated once so the
## runtime sky never leaks into the PackedScene resource.
func _apply_sky_and_sun(profile: Dictionary, gloom: float) -> void:
	if _world_environment == null or _world_environment.environment == null:
		return
	if _world_environment.environment != _runtime_environment:
		_runtime_environment = _world_environment.environment.duplicate() as Environment
		_sky_material = ProceduralSkyMaterial.new()
		_sky_material.sun_angle_max = 0.0
		var sky := Sky.new()
		sky.sky_material = _sky_material
		_runtime_environment.background_mode = Environment.BG_SKY
		_runtime_environment.sky = sky
		_runtime_environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		_runtime_environment.tonemap_mode = Environment.TONE_MAPPER_ACES
		_runtime_environment.glow_enabled = true
		_runtime_environment.fog_enabled = true
		_runtime_environment.fog_sky_affect = 0.15
		_world_environment.environment = _runtime_environment
	_sky_material.sky_top_color = (profile["sky_top"] as Color).lerp(STORM_GREY.darkened(0.3), gloom * 0.6)
	_sky_material.sky_horizon_color = (profile["sky_horizon"] as Color).lerp(STORM_GREY, gloom * 0.6)
	_sky_material.ground_horizon_color = _sky_material.sky_horizon_color
	_sky_material.ground_bottom_color = profile["ground"]
	_runtime_environment.ambient_light_color = profile["ambient"]
	_runtime_environment.ambient_light_energy = profile["ambient_energy"]
	_runtime_environment.fog_light_color = (profile["fog"] as Color).lerp(STORM_GREY, gloom * 0.5)
	_runtime_environment.fog_density = float(profile["fog_density"]) * (1.0 + gloom)
	if _sun != null:
		_sun.rotation_degrees = Vector3(-float(profile["sun_pitch"]), float(profile["sun_yaw"]), 0.0)
		_sun.light_color = profile["sun"]
		_sun.light_energy = float(profile["sun_energy"]) * (1.0 - gloom * 0.4)


## Layer 6: three silhouette layers (forest line, Montevecchia hills, Alps) 4.3 - 4.55 km out,
## drawn with the Apex Ring's haze shader so they melt into the sky at every time of day.
func _build_layer6_vista_ring() -> void:
	var noise := FastNoiseLite.new()
	noise.seed = 19220903
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.fractal_octaves = 4
	noise.frequency = 1.0
	var centre := Vector3(_track_centre.x, 0.0, _track_centre.y)
	var mesh := ArrayMesh.new()
	for layer: int in range(VISTA_LAYERS.size()):
		var spec: Dictionary = VISTA_LAYERS[layer]
		var segments: int = int(spec["segments"])
		var crest := PackedVector3Array()
		var base := PackedVector3Array()
		for i: int in range(segments):
			var angle: float = TAU * float(i) / float(segments)
			var dir := Vector3(cos(angle), 0.0, sin(angle))
			var ridged: float = 1.0 - absf(noise.get_noise_2d(dir.x * float(spec["freq"]) + float(layer) * 17.0, dir.z * float(spec["freq"])))
			var h_range: Vector2 = spec["height"]
			var height: float = lerpf(h_range.x, h_range.y, pow(clampf(ridged, 0.0, 1.0), 1.5))
			crest.append(centre + dir * float(spec["radius"]) + Vector3.UP * height)
			base.append(centre + dir * (float(spec["radius"]) - height * VISTA_FLANK_RUN) + Vector3.UP * VISTA_BASE_Y)
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		for i: int in range(segments):
			var next: int = (i + 1) % segments
			var quad: Array[Vector3] = [base[i], base[next], crest[next], base[i], crest[next], crest[i]]
			var alphas: Array[float] = [0.0, 0.0, 1.0, 0.0, 1.0, 1.0]
			for k: int in range(6):
				st.set_color(Color(1.0, 1.0, 1.0, alphas[k]))
				st.set_normal(Vector3.UP)
				st.add_vertex(quad[k])
		st.commit(mesh)
		var material := ShaderMaterial.new()
		material.shader = HazeShader
		material.set_shader_parameter("layer_color", spec["color"])
		material.set_shader_parameter("layer_haze", spec["haze"])
		material.set_shader_parameter("snow_amount", spec["snow"])
		mesh.surface_set_material(mesh.get_surface_count() - 1, material)
		_vista_materials.append(material)
	vista_ring = MeshInstance3D.new()
	vista_ring.name = "BrianzaVistaRing"
	vista_ring.mesh = mesh
	vista_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(vista_ring)


func stats() -> Dictionary:
	return {
		"circuit_id": "brianza",
		"length_m": ribbon.curve.get_baked_length() if ribbon != null and ribbon.curve != null else 0.0,
		"built": built,
		"sopraelevata_active": sopraelevata != null,
		"tree_batches": tree_multimeshes.size(),
	}


## Top of the solid ground under a world point: the verge profile next to the road, the park field
## further out. Trees, piers and fences stand on this, so nothing floats.
func ground_y_at(pos: Vector3) -> float:
	var best: int = -1
	var best_d: float = INF
	for i: int in range(_track_pos.size()):
		var d: float = Vector2(_track_pos[i].x - pos.x, _track_pos[i].z - pos.z).length_squared()
		if d < best_d:
			best_d = d
			best = i
	if best < 0:
		return 0.0
	var lateral: float = sqrt(best_d)
	if lateral > VERGE_LATERAL_M[VERGE_LATERAL_M.size() - 1]:
		return _field_height(pos.x, pos.z)
	# Interpolate road height along the closer of the two segments touching the nearest sample.
	var road_y: float = _track_pos[best].y
	var p := Vector2(pos.x, pos.z)
	var here := Vector2(_track_pos[best].x, _track_pos[best].z)
	var count: int = _track_pos.size()
	for other: int in [posmod(best - 1, count), posmod(best + 1, count)]:
		var q := Vector2(_track_pos[other].x, _track_pos[other].z)
		var seg: Vector2 = q - here
		var t: float = clampf((p - here).dot(seg) / maxf(seg.length_squared(), 0.0001), 0.0, 1.0)
		if (p - here).dot(seg) > 0.0:
			road_y = lerpf(_track_pos[best].y, _track_pos[other].y, t)
			lateral = (p - (here + seg * t)).length()
			break
	return road_y + _verge_drop(lateral)


func _verge_drop(lateral: float) -> float:
	var last: int = VERGE_LATERAL_M.size() - 1
	if lateral <= VERGE_LATERAL_M[0]:
		return VERGE_DROP_M[0]
	for i: int in range(last):
		if lateral <= VERGE_LATERAL_M[i + 1]:
			var t: float = (lateral - VERGE_LATERAL_M[i]) / (VERGE_LATERAL_M[i + 1] - VERGE_LATERAL_M[i])
			return lerpf(VERGE_DROP_M[i], VERGE_DROP_M[i + 1], t)
	return VERGE_DROP_M[last]


func _field_height(x: float, z: float) -> float:
	var fx: float = clampf((x - _field_origin.x) / GROUND_CELL_M, 0.0, float(_field_cols - 1) - 0.001)
	var fz: float = clampf((_field_origin.y - z) / GROUND_CELL_M, 0.0, float(_field_rows - 1) - 0.001)
	var c: int = int(fx)
	var r: int = int(fz)
	var tx: float = fx - float(c)
	var tz: float = fz - float(r)
	var a: float = lerpf(_field_y[r * _field_cols + c], _field_y[r * _field_cols + c + 1], tx)
	var b: float = lerpf(_field_y[(r + 1) * _field_cols + c], _field_y[(r + 1) * _field_cols + c + 1], tx)
	return lerpf(a, b, tz)


## Layer 1: field + verge strips + gravel apron + historic park wall (0 floating roads).
func _build_layer1_ground_massing() -> void:
	ground_root = Node3D.new()
	ground_root.name = "ParcoRealeGroundRoot"
	add_child(ground_root)
	_sample_track()
	_build_field()
	_build_verge()
	_build_park_wall()


func _sample_track() -> void:
	_track_pos.clear()
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	var s: float = 0.0
	while s < ribbon.length_m:
		var p: Vector3 = ribbon.get_point_at_offset(s, 0.0).origin
		_track_pos.append(p)
		lo = Vector2(minf(lo.x, p.x), minf(lo.y, p.z))
		hi = Vector2(maxf(hi.x, p.x), maxf(hi.y, p.z))
		s += GROUND_SAMPLE_STEP_M
	_track_centre = (lo + hi) * 0.5
	_track_half = (hi - lo) * 0.5


func _build_field() -> void:
	_field_cols = int(GROUND_SIZE_M.x / GROUND_CELL_M) + 1
	_field_rows = int(GROUND_SIZE_M.y / GROUND_CELL_M) + 1
	_field_origin = Vector2(_track_centre.x - GROUND_SIZE_M.x * 0.5, _track_centre.y + GROUND_SIZE_M.y * 0.5)
	var nearest_d := PackedFloat32Array()
	var nearest_y := PackedFloat32Array()
	nearest_d.resize(_field_cols * _field_rows)
	nearest_d.fill(INF)
	nearest_y.resize(_field_cols * _field_rows)
	var reach: int = ceili(GROUND_FADE_FAR_M / GROUND_CELL_M)
	for p: Vector3 in _track_pos:
		var c0: int = roundi((p.x - _field_origin.x) / GROUND_CELL_M)
		var r0: int = roundi((_field_origin.y - p.z) / GROUND_CELL_M)
		for r: int in range(maxi(r0 - reach, 0), mini(r0 + reach + 1, _field_rows)):
			for c: int in range(maxi(c0 - reach, 0), mini(c0 + reach + 1, _field_cols)):
				var vx: float = _field_origin.x + float(c) * GROUND_CELL_M
				var vz: float = _field_origin.y - float(r) * GROUND_CELL_M
				var d: float = Vector2(vx - p.x, vz - p.z).length()
				var i: int = r * _field_cols + c
				if d < nearest_d[i]:
					nearest_d[i] = d
					nearest_y[i] = p.y
	_field_y.resize(_field_cols * _field_rows)
	for i: int in range(_field_y.size()):
		var near_y: float = nearest_y[i] if nearest_d[i] < INF else 0.0
		var fade: float = smoothstep(GROUND_FADE_NEAR_M, GROUND_FADE_FAR_M, nearest_d[i])
		_field_y[i] = lerpf(near_y, 0.0, fade) - GROUND_DROP_M
	var tools: Array[SurfaceTool] = []
	for tone: int in range(GRASS_TONES.size()):
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		st.set_normal(Vector3.UP)
		tools.append(st)
	for r: int in range(_field_rows - 1):
		for c: int in range(_field_cols - 1):
			var st: SurfaceTool = tools[posmod(c * 7 + r * 13 + (c * r) % 5, GRASS_TONES.size())]
			var v00 := _field_vertex(c, r)
			var v01 := _field_vertex(c + 1, r)
			var v10 := _field_vertex(c, r + 1)
			var v11 := _field_vertex(c + 1, r + 1)
			for v: Vector3 in [v00, v10, v11, v00, v11, v01]:
				st.set_normal(Vector3.UP)
				st.add_vertex(v)
	var mesh := ArrayMesh.new()
	for tone: int in range(GRASS_TONES.size()):
		tools[tone].commit(mesh)
		mesh.surface_set_material(tone, ToonMaterials.make(GRASS_TONES[tone]))
	# Flat park floor under the field and out to the vista ring, so no sky gap shows between them.
	var floor_mesh := PlaneMesh.new()
	floor_mesh.size = Vector2(VISTA_LAYERS[2]["radius"] * 2.2, VISTA_LAYERS[2]["radius"] * 2.2)
	floor_mesh.material = ToonMaterials.make(GRASS_TONES[1])
	var outer_floor := MeshInstance3D.new()
	outer_floor.name = "ParcoRealeOuterFloor"
	outer_floor.mesh = floor_mesh
	outer_floor.position = Vector3(_track_centre.x, -GROUND_DROP_M - 0.6, _track_centre.y)
	outer_floor.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ground_root.add_child(outer_floor)
	var inst := MeshInstance3D.new()
	inst.name = "ParcoRealeGroundMesh"
	inst.mesh = mesh
	inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ground_root.add_child(inst)


func _field_vertex(c: int, r: int) -> Vector3:
	return Vector3(_field_origin.x + float(c) * GROUND_CELL_M, _field_y[r * _field_cols + c], _field_origin.y - float(r) * GROUND_CELL_M)


## Grass verge to 80 m either side plus a gravel apron right behind the kerbs.
func _build_verge() -> void:
	var gravel := SurfaceTool.new()
	var grass := SurfaceTool.new()
	for st: SurfaceTool in [gravel, grass]:
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rows: int = ceili(ribbon.length_m / VERGE_STEP_M)
	for side: float in [-1.0, 1.0]:
		for i: int in range(rows):
			var s0: float = float(i) * VERGE_STEP_M
			var s1: float = minf(float(i + 1) * VERGE_STEP_M, ribbon.length_m)
			for band: int in range(VERGE_LATERAL_M.size() - 1):
				var st: SurfaceTool = gravel if band == 0 else grass
				var l0: float = side * VERGE_LATERAL_M[band]
				var l1: float = side * VERGE_LATERAL_M[band + 1]
				var a: Vector3 = _verge_point(s0, l0, band)
				var b: Vector3 = _verge_point(s1, l0, band)
				var c: Vector3 = _verge_point(s1, l1, band + 1)
				var d: Vector3 = _verge_point(s0, l1, band + 1)
				# Left (-1) side is wound the other way round so both face up.
				var quad: Array = [a, b, c, a, c, d] if side > 0.0 else [a, c, b, a, d, c]
				for v: Vector3 in quad:
					st.set_normal(Vector3.UP)
					st.add_vertex(v)
	var apron_inst := MeshInstance3D.new()
	apron_inst.name = "ParkPathways"
	apron_inst.mesh = _commit_surface(gravel, GRAVEL_PATH)
	apron_inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ground_root.add_child(apron_inst)
	var verge_inst := MeshInstance3D.new()
	verge_inst.name = "ParcoRealeVerge"
	verge_inst.mesh = _commit_surface(grass, GRASS_TONES[0])
	verge_inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ground_root.add_child(verge_inst)


func _verge_point(s: float, lateral: float, band_edge: int) -> Vector3:
	var p: Vector3 = ribbon.get_point_at_offset(s, lateral).origin
	var road_y: float = ribbon.get_point_at_offset(s, 0.0).origin.y
	p.y = road_y + VERGE_DROP_M[band_edge]
	return p


func _commit_surface(st: SurfaceTool, color: Color) -> ArrayMesh:
	var mesh := ArrayMesh.new()
	st.commit(mesh)
	mesh.surface_set_material(0, ToonMaterials.make(color))
	return mesh


## Mura del Parco di Monza: terracotta brick with a limestone cap, a rectangle around the circuit.
func _build_park_wall() -> void:
	var half := Vector2(
		minf(_track_half.x + PARK_WALL_MARGIN_M, GROUND_SIZE_M.x * 0.5 - 60.0),
		minf(_track_half.y + PARK_WALL_MARGIN_M, GROUND_SIZE_M.y * 0.5 - 60.0))
	var batch := MeshBatchScript.new()
	var mat: Material = ToonMaterials.vertex_colored(false)
	var step: float = 60.0
	for side: float in [-1.0, 1.0]:
		var x: float = _track_centre.x - half.x
		while x < _track_centre.x + half.x:
			var z: float = _track_centre.y + side * half.y
			_wall_segment(batch, mat, Vector3(x + step * 0.5, 0.0, z), step, 0.0)
			x += step
		var z2: float = _track_centre.y - half.y
		while z2 < _track_centre.y + half.y:
			var xx: float = _track_centre.x + side * half.x
			_wall_segment(batch, mat, Vector3(xx, 0.0, z2 + step * 0.5), step, PI * 0.5)
			z2 += step
	var inst := MeshInstance3D.new()
	inst.name = "MuraDelParco"
	inst.mesh = batch.commit()
	add_child(inst)


func _wall_segment(batch: MeshBatchScript, mat: Material, centre: Vector3, length: float, yaw: float) -> void:
	var base_y: float = _field_height(centre.x, centre.z)
	var basis := Basis(Vector3.UP, yaw)
	batch.box(mat, PARK_WALL_BRICK, Transform3D(basis, Vector3(centre.x, base_y + PARK_WALL_HEIGHT_M * 0.5, centre.z)), Vector3(length, PARK_WALL_HEIGHT_M, 1.0))
	batch.box(mat, PARK_WALL_CAP, Transform3D(basis, Vector3(centre.x, base_y + PARK_WALL_HEIGHT_M + 0.15, centre.z)), Vector3(length, 0.3, 1.5))


func _find_sharp_corners() -> Array[Dictionary]:
	var runs: Array[Dictionary] = []
	var s: float = 0.0
	var current: Dictionary = {}
	var length_m: float = ribbon.length_m
	while s < length_m:
		var k: float = ribbon.get_curvature_at(s)
		if absf(k) >= KERB_CURVATURE:
			var side: float = signf(k)
			if not current.is_empty() and is_equal_approx(float(current["side"]), side):
				current["s1"] = s + KERB_SCAN_STEP_M
			else:
				if not current.is_empty():
					runs.append(current)
				current = {"s0": s, "s1": s + KERB_SCAN_STEP_M, "side": side}
		s += KERB_SCAN_STEP_M
	if not current.is_empty():
		runs.append(current)
	var kept: Array[Dictionary] = []
	for run: Dictionary in runs:
		if float(run["s1"]) - float(run["s0"]) >= KERB_MIN_LENGTH_M:
			kept.append(run)
	return kept


func _build_tier_a_surface() -> void:
	var surface_root := Node3D.new()
	surface_root.name = "SurfaceDetailRoot"
	add_child(surface_root)
	
	kerbs = _find_sharp_corners()
	var kerb_m: ArrayMesh = SurfaceGeometry.kerb_mesh(ribbon, kerbs, ribbon.road_half_width_m - SurfaceGeometry.KERB_INSET_M)
	if kerb_m != null:
		kerb_m.surface_set_material(0, ToonMaterials.make(RED))
		kerb_m.surface_set_material(1, ToonMaterials.make(WHITE))
		var kerb_inst := MeshInstance3D.new()
		kerb_inst.name = "SawtoothKerbs"
		kerb_inst.mesh = kerb_m
		surface_root.add_child(kerb_inst)
		
	var pit_lead: float = 20.0
	var pit_trail: float = 40.0
	var pit_start: float = fposmod(5530.0 - pit_lead, ribbon.length_m)
	var pit_len: float = 410.0 + pit_lead + pit_trail
	runoff_plans = SurfaceGeometry.plan_runoffs(ribbon, kerbs, pit_start, pit_len)
	
	var runoff_m: ArrayMesh = SurfaceGeometry.runoff_mesh(ribbon, runoff_plans)
	if runoff_m != null and runoff_m.get_surface_count() >= 3:
		runoff_m.surface_set_material(0, ToonMaterials.make(SurfaceGeometry.RUNOFF_COLOR))
		runoff_m.surface_set_material(1, ToonMaterials.make(SurfaceGeometry.WARNING_BLUE))
		runoff_m.surface_set_material(2, ToonMaterials.make(WHITE))
		var runoff_inst := MeshInstance3D.new()
		runoff_inst.name = "TarmacRunoff"
		runoff_inst.mesh = runoff_m
		surface_root.add_child(runoff_inst)
		
	var gravel_m: ArrayMesh = SurfaceGeometry.gravel_mesh(ribbon, runoff_plans)
	if gravel_m != null and gravel_m.get_surface_count() >= 1:
		gravel_m.surface_set_material(0, ToonMaterials.make(SurfaceGeometry.GRAVEL_COLOR))
		var gravel_inst := MeshInstance3D.new()
		gravel_inst.name = "GravelTraps"
		gravel_inst.mesh = gravel_m
		surface_root.add_child(gravel_inst)
		
	var groove_mat := StandardMaterial3D.new()
	groove_mat.vertex_color_use_as_albedo = true
	groove_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	groove_mat.roughness = 0.7
	groove_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	var groove_m: ArrayMesh = SurfaceGeometry.groove_mesh(ribbon, line)
	if groove_m != null:
		groove_m.surface_set_material(0, groove_mat)
		var groove_inst := MeshInstance3D.new()
		groove_inst.name = "RubberGroove"
		groove_inst.mesh = groove_m
		groove_inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		surface_root.add_child(groove_inst)


func _build_tier_a_furniture() -> void:
	var hero_zones: Array[Dictionary] = [
		{"side": 1.0, "s0": 5510.0, "s1": 5790.0, "lateral": 36.0},
		{"side": 1.0, "s0": 0.0, "s1": 190.0, "lateral": 36.0},
	]
	furniture = FurnitureScript.new()
	furniture.name = "TracksideFurniture"
	add_child(furniture)
	furniture.build(ribbon, line, kerbs, runoff_plans, hero_zones)


func _build_tier_a_sky() -> void:
	shared_sky = SharedSkyScript.new()
	shared_sky.build(self, ribbon)


## Layer 2, Hero Landmark 1: La Sopraelevata di Monza. A 480 m arc of banked concrete deck (R 320 m)
## swung diagonally over the Serraglio straight on four dual-pier portals. Station frame: T along the
## deck, N horizontal toward the arc centre, deck plane tilted BANK_DEG with the inner edge low.
func _build_layer2_sopraelevata_monumental() -> void:
	sopraelevata = Node3D.new()
	sopraelevata.name = "HeroLandmark_Sopraelevata"
	add_child(sopraelevata)

	if ribbon == null:
		return

	var xform: Transform3D = ribbon.get_point_at_offset(SERRAGLIO_OVERPASS_S, 0.0)
	sopraelevata.transform = xform
	sopraelevata.set_meta("arc_length_m", SOPRA_ARC_M)
	sopraelevata.set_meta("bank_deg", SOPRA_BANK_DEG)
	sopraelevata.set_meta("clearance_m", SOPRA_CLEARANCE_M)

	var mat: Material = ToonMaterials.vertex_colored(false)
	var conc_col := Color("#8a8f9c")
	var dark_conc := Color("#555966")
	var rust_col := Color("#733d26")
	var half_arc: float = SOPRA_ARC_M * 0.5 / SOPRA_RADIUS_M
	var segments: int = int(SOPRA_ARC_M / 12.0)
	var bank: float = deg_to_rad(SOPRA_BANK_DEG)
	var half_w: float = SOPRA_WIDTH_M * 0.5
	# Underside of the inner (low) edge is the clearance line over the track.
	var y0: float = SOPRA_CLEARANCE_M + half_w * sin(bank) + SOPRA_THICKNESS_M * cos(bank)

	var deck := MeshBatchScript.new()
	var rail := MeshBatchScript.new()
	for i: int in range(segments + 1):
		var st_a: Dictionary = _sopra_station(-half_arc + 2.0 * half_arc * float(i) / float(segments), y0, bank)
		_sopra_blockers.append(xform * (st_a["pos"] as Vector3))
		if i == 0 or i == segments:
			var end_sign: float = -1.0 if i == 0 else 1.0
			_sopra_cap(deck, mat, conc_col, st_a, half_w, end_sign)
		if i == segments:
			break
		var st_b: Dictionary = _sopra_station(-half_arc + 2.0 * half_arc * float(i + 1) / float(segments), y0, bank)
		var tone: Color = conc_col.lerp(dark_conc, 0.28 * fmod(float(i) * 0.618, 1.0))
		var tl_a: Vector3 = _sopra_edge(st_a, -half_w, 0.0)
		var tr_a: Vector3 = _sopra_edge(st_a, half_w, 0.0)
		var tl_b: Vector3 = _sopra_edge(st_b, -half_w, 0.0)
		var tr_b: Vector3 = _sopra_edge(st_b, half_w, 0.0)
		var bl_a: Vector3 = _sopra_edge(st_a, -half_w, -SOPRA_THICKNESS_M)
		var br_a: Vector3 = _sopra_edge(st_a, half_w, -SOPRA_THICKNESS_M)
		var bl_b: Vector3 = _sopra_edge(st_b, -half_w, -SOPRA_THICKNESS_M)
		var br_b: Vector3 = _sopra_edge(st_b, half_w, -SOPRA_THICKNESS_M)
		var nrm: Vector3 = st_a["nrm"]
		var dir_u: Vector3 = st_a["dir_u"]
		deck.quad(mat, tone, tl_a, tr_a, tr_b, tl_b, nrm)
		deck.quad(mat, dark_conc, bl_a, br_a, br_b, bl_b, -nrm)
		deck.quad(mat, tone * 0.85, tl_a, bl_a, bl_b, tl_b, -dir_u)
		deck.quad(mat, tone * 0.85, tr_a, br_a, br_b, tr_b, dir_u)
		# Rusty crash rail on the outer upper lip, a low concrete lip on the inner edge.
		var pose_basis := Basis(dir_u, nrm, st_a["tan"])
		var mid: Vector3 = (st_a["pos"] as Vector3).lerp(st_b["pos"], 0.5)
		rail.box(mat, rust_col, Transform3D(pose_basis, mid + dir_u * (-half_w - 0.1) + nrm * 1.1), Vector3(0.5, 2.2, 12.4))
		deck.box(mat, dark_conc, Transform3D(pose_basis, mid + dir_u * (half_w + 0.3) + nrm * 0.4), Vector3(0.6, 1.0, 12.4))

	var inst := MeshInstance3D.new()
	inst.name = "SopraelevataViaductMesh"
	inst.mesh = deck.commit()
	sopraelevata.add_child(inst)
	var rail_inst := MeshInstance3D.new()
	rail_inst.name = "SopraelevataGuardrail"
	rail_inst.mesh = rail.commit()
	sopraelevata.add_child(rail_inst)

	var portal_root := Node3D.new()
	portal_root.name = "SopraelevataPortals"
	sopraelevata.add_child(portal_root)
	for k: int in range(SOPRA_PORTAL_THETAS.size()):
		var station: Dictionary = _sopra_station(SOPRA_PORTAL_THETAS[k] * half_arc, y0, bank)
		var portal := MeshBatchScript.new()
		_sopra_portal(portal, mat, station, xform, half_w, dark_conc, conc_col)
		var portal_inst := MeshInstance3D.new()
		portal_inst.name = "SopraPortal_%d" % k
		portal_inst.mesh = portal.commit()
		portal_root.add_child(portal_inst)


## Frame of the deck centre line at arc angle `theta`, in the landmark's local space.
func _sopra_station(theta: float, y0: float, bank: float) -> Dictionary:
	var yaw := Basis(Vector3.UP, deg_to_rad(SOPRA_YAW_DEG))
	var tangent: Vector3 = yaw * Vector3(cos(theta), 0.0, -sin(theta))
	var inward: Vector3 = yaw * Vector3(-sin(theta), 0.0, -cos(theta))
	var pos: Vector3 = yaw * Vector3(SOPRA_RADIUS_M * sin(theta), 0.0, -SOPRA_RADIUS_M * (1.0 - cos(theta))) + Vector3(0.0, y0, 0.0)
	return {
		"pos": pos, "tan": tangent, "inward": inward,
		"dir_u": inward * cos(bank) - Vector3.UP * sin(bank),
		"nrm": Vector3.UP * cos(bank) + inward * sin(bank),
	}


## Point `u` across the deck (+ = inner, low edge) and `v` along the deck normal.
func _sopra_edge(station: Dictionary, u: float, v: float) -> Vector3:
	return (station["pos"] as Vector3) + (station["dir_u"] as Vector3) * u + (station["nrm"] as Vector3) * v


func _sopra_cap(batch: MeshBatchScript, mat: Material, color: Color, station: Dictionary, half_w: float, end_sign: float) -> void:
	batch.quad(mat, color * 0.8, _sopra_edge(station, -half_w, 0.0), _sopra_edge(station, half_w, 0.0),
		_sopra_edge(station, half_w, -SOPRA_THICKNESS_M), _sopra_edge(station, -half_w, -SOPRA_THICKNESS_M), (station["tan"] as Vector3) * end_sign)


## Two concrete piers down to the ground, a cap beam under the deck and two arch braces between them.
func _sopra_portal(batch: MeshBatchScript, mat: Material, station: Dictionary, xform: Transform3D, half_w: float, pier_col: Color, beam_col: Color) -> void:
	var basis := Basis(station["dir_u"], station["nrm"], station["tan"])
	var tops: Array[Vector3] = []
	for u: float in [-half_w * 0.65, half_w * 0.65]:
		var top: Vector3 = _sopra_edge(station, u, -SOPRA_THICKNESS_M - 0.3)
		var base_world: float = ground_y_at(xform * Vector3(top.x, 0.0, top.z))
		var base_y: float = base_world - xform.origin.y - 1.0
		var height: float = top.y - base_y
		_sopra_blockers.append(xform * top)
		batch.box(mat, pier_col, Transform3D(basis.orthonormalized(), Vector3(top.x, base_y + height * 0.5, top.z)), Vector3(3.2, height, 4.4))
		tops.append(top)
	var beam_mid: Vector3 = (tops[0] + tops[1]) * 0.5
	batch.box(mat, beam_col, Transform3D(basis, beam_mid + (station["nrm"] as Vector3) * 0.4), Vector3(SOPRA_WIDTH_M, 1.2, 4.8))
	for top: Vector3 in tops:
		var brace_foot: Vector3 = top - Vector3.UP * 5.5
		batch.strut(mat, beam_col, brace_foot, beam_mid - (station["nrm"] as Vector3) * 0.2, 1.1)


## Layer 3: Rettifilo (T1-T2, red canopy) and Ascari (T9-T11, stadium + Jumbotron) corner stands.
func _build_layer3_corner_grandstands() -> void:
	if ribbon == null:
		return
	_build_corner_stand("RettifiloGrandstand", _turn_named("Variante del Rettifilo"), 120.0, 3, RED, false)
	_build_corner_stand("AscariGrandstand", _turn_named("Variante Ascari"), 160.0, 4, Color("#e4e6ec"), true)


## The stands follow the spline's real corner positions (the design spec's s ranges predate the final layout).
func _turn_named(turn_name: String) -> Dictionary:
	for turn: Dictionary in builder.turns:
		if String(turn["name"]) == turn_name:
			return turn
	return {}


func _build_corner_stand(stand_name: String, turn: Dictionary, length: float, tiers: int, canopy_color: Color, with_screen: bool) -> void:
	if turn.is_empty():
		return
	var s_centre: float = float(turn["s"])
	# Outside of the corner's first bend.
	var side: float = 1.0 if ribbon.get_curvature_at(float((turn["apex_s"] as Array)[0])) >= 0.0 else -1.0
	var frame: Transform3D = ribbon.get_point_at_offset(s_centre, side * CORNER_STAND_LATERAL_M)
	if side < 0.0:
		frame.basis = frame.basis * Basis(Vector3.UP, PI)
	frame.origin.y = ground_y_at(frame.origin)
	var stand := Node3D.new()
	stand.name = stand_name
	stand.transform = frame
	stand.set_meta("s_centre", s_centre)
	stand.set_meta("length_m", length)
	stand.set_meta("side", side)
	add_child(stand)
	_foliage_keepouts.append({"side": side, "s0": s_centre - length * 0.5 - 15.0, "s1": s_centre + length * 0.5 + 15.0, "depth": 100.0})
	# The stand is a straight block but the corner bends away from it: keep plants off its real footprint too.
	_stand_footprints.append({"inverse": frame.affine_inverse(), "half_length": length * 0.5 + 8.0})

	var mat: Material = ToonMaterials.vertex_colored(false)
	var concrete := Color("#b9bdc7")
	var seat_tones: Array[Color] = [RED, WHITE, Color("#2f8f46")]
	var structure := MeshBatchScript.new()
	var canopy := MeshBatchScript.new()
	var tier_depth: float = CORNER_TIER_DEPTH_M
	var tops: Array[float] = []
	for i: int in range(tiers):
		var top: float = 1.0 + CORNER_TIER_RISE_M * float(i + 1)
		tops.append(top)
		var x: float = tier_depth * (float(i) + 0.5)
		structure.box(mat, concrete, Transform3D(Basis.IDENTITY, Vector3(x, (top - 1.5) * 0.5, 0.0)), Vector3(tier_depth, top + 1.5, length))
		var sections: int = int(length / 20.0)
		for k: int in range(sections):
			var z: float = -length * 0.5 + 20.0 * (float(k) + 0.5)
			structure.box(mat, seat_tones[(k + i) % seat_tones.size()], Transform3D(Basis.IDENTITY, Vector3(x, top + 0.08, z)), Vector3(tier_depth - 0.6, 0.16, 19.0))
	var depth: float = tier_depth * float(tiers)
	structure.box(mat, canopy_color, Transform3D(Basis.IDENTITY, Vector3(-0.15, 0.7, 0.0)), Vector3(0.3, 1.6, length))
	# Cantilever roof rising toward the back, carried by posts every 20 m.
	var front_y: float = tops[tiers - 1] + 3.6
	var back_y: float = front_y + 2.6
	var roof_len: float = sqrt(pow(depth + 3.0, 2.0) + pow(back_y - front_y, 2.0))
	var roof_tilt := Basis(Vector3(0.0, 0.0, 1.0), atan2(back_y - front_y, depth + 3.0))
	canopy.box(mat, canopy_color, Transform3D(roof_tilt, Vector3((depth + 3.0) * 0.5 - 0.5, (front_y + back_y) * 0.5, 0.0)), Vector3(roof_len, 0.5, length))
	canopy.box(mat, WHITE, Transform3D(roof_tilt, Vector3(-0.5, front_y + 0.2, 0.0)), Vector3(0.4, 0.9, length))
	var posts: int = int(length / 20.0) + 1
	for k: int in range(posts):
		var z: float = -length * 0.5 + 20.0 * float(k)
		structure.box(mat, Color("#555966"), Transform3D(Basis.IDENTITY, Vector3(depth + 1.0, (back_y - 1.5) * 0.5, z)), Vector3(0.7, back_y + 1.5, 0.7))

	var structure_inst := MeshInstance3D.new()
	structure_inst.name = "Structure"
	structure_inst.mesh = structure.commit()
	stand.add_child(structure_inst)
	var canopy_inst := MeshInstance3D.new()
	canopy_inst.name = "Canopy"
	canopy_inst.mesh = canopy.commit()
	stand.add_child(canopy_inst)
	_build_stand_crowd(stand, length, tiers, tops, tier_depth, stand_name.hash())

	if with_screen:
		var screen := JumbotronScript.new()
		screen.name = "Jumbotron"
		screen.build(Vector2(16.0, 6.0))
		# The quad faces +Z; turn it toward the track (-X) and lift it clear of the roof.
		screen.transform = Transform3D(Basis(Vector3.UP, -PI * 0.5), Vector3(0.0, front_y + 5.2, 0.0))
		stand.add_child(screen)
		var legs := MeshBatchScript.new()
		for z: float in [-6.0, 6.0]:
			legs.box(mat, Color("#555966"), Transform3D(Basis.IDENTITY, Vector3(0.0, front_y + 1.5, z)), Vector3(0.6, 4.0, 0.6))
		var legs_inst := MeshInstance3D.new()
		legs_inst.name = "JumbotronLegs"
		legs_inst.mesh = legs.commit()
		stand.add_child(legs_inst)
		_ascari_screen = screen


func _build_stand_crowd(stand: Node3D, length: float, tiers: int, tops: Array[float], tier_depth: float, seed_value: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var poses: Array[Transform3D] = []
	var colors: Array[Color] = []
	var columns: int = int(length / CORNER_CROWD_STEP_M)
	for tier: int in range(tiers):
		for row: int in range(3):
			var x: float = tier_depth * (float(tier) + 0.25 + 0.25 * float(row))
			for column: int in range(columns):
				if rng.randf() > 0.5:
					continue
				var z: float = -length * 0.5 + CORNER_CROWD_STEP_M * (float(column) + 0.5) + rng.randf_range(-0.3, 0.3)
				var scale_f: float = rng.randf_range(0.9, 1.15)
				poses.append(Transform3D(Basis(Vector3.UP, -PI * 0.5).scaled(Vector3.ONE * scale_f), Vector3(x, tops[tier] + 0.16, z)))
				colors.append(CROWD_SHIRTS[rng.randi() % CROWD_SHIRTS.size()])
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_colors = true # must be set while the instance count is still 0
	multimesh.mesh = _spectator_mesh()
	multimesh.instance_count = poses.size()
	for index: int in range(poses.size()):
		multimesh.set_instance_transform(index, poses[index])
		multimesh.set_instance_color(index, colors[index])
	var crowd := MultiMeshInstance3D.new()
	crowd.name = "Crowd"
	crowd.multimesh = multimesh
	crowd.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	stand.add_child(crowd)


## A seated spectator: body block and head block; the instance colour tints the shirt.
func _spectator_mesh() -> ArrayMesh:
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.roughness = 0.9
	var batch := MeshBatchScript.new()
	batch.box(material, Color.WHITE, Transform3D(Basis.IDENTITY, Vector3(0.0, 0.32, 0.0)), Vector3(0.28, 0.62, 0.42))
	batch.box(material, Color("#f2cfae"), Transform3D(Basis.IDENTITY, Vector3(0.0, 0.8, 0.0)), Vector3(0.24, 0.26, 0.24))
	return batch.commit()


## Hero Landmark 2 & 3: Villa Reale neoclassical gatehouse and Torre Ascari, one node each.
func _build_tier_b_landmarks() -> void:
	if ribbon == null:
		return

	var landmarks := Node3D.new()
	landmarks.name = "HeroLandmarks_MonzaHeritage"
	add_child(landmarks)

	var mat: Material = ToonMaterials.vertex_colored(false)
	var brick_col := Color("#a3483b")
	var stone_col := Color("#d4d0c7")
	var marble := Color("#f2efe6")

	# Villa Reale gatehouse (s = 5600 m, behind the main grandstand at lateral -36 m)
	var gate_pose: Transform3D = ribbon.get_point_at_offset(VILLA_GATE_S, -36.0)
	gate_pose.origin.y = ground_y_at(gate_pose.origin)
	var gate := MeshBatchScript.new()
	gate.box(mat, stone_col, Transform3D(Basis.IDENTITY, Vector3(0.0, 0.3, 0.0)), Vector3(24.0, 0.6, 5.0))
	for side: float in [-1.0, 1.0]:
		gate.box(mat, brick_col, Transform3D(Basis.IDENTITY, Vector3(side * 6.0, 5.4, 0.0)), Vector3(3.4, 10.0, 3.4))
		gate.box(mat, stone_col, Transform3D(Basis.IDENTITY, Vector3(side * 6.0, 10.7, 0.0)), Vector3(4.2, 0.7, 4.2))
		gate.cylinder(mat, marble, Transform3D(Basis.IDENTITY, Vector3(side * 3.2, 0.6, 1.4)), 0.55, 0.45, 9.4, 10)
		gate.box(mat, brick_col, Transform3D(Basis.IDENTITY, Vector3(side * 13.6, 2.6, 0.0)), Vector3(11.0, 4.6, 1.6))
		gate.box(mat, stone_col, Transform3D(Basis.IDENTITY, Vector3(side * 13.6, 5.0, 0.0)), Vector3(11.4, 0.4, 2.0))
		gate.box(mat, Color("#22262e"), Transform3D(Basis.IDENTITY, Vector3(side * 1.9, 2.4, 0.0)), Vector3(3.2, 4.2, 0.2))
	gate.box(mat, stone_col, Transform3D(Basis.IDENTITY, Vector3(0.0, 11.4, 0.0)), Vector3(17.0, 1.4, 4.0))
	var pediment := PackedVector2Array([Vector2(-7.5, 0.0), Vector2(7.5, 0.0), Vector2(0.0, 3.4)])
	gate.extrude(mat, marble, Transform3D(Basis.IDENTITY, Vector3(0.0, 12.1, 0.0)), pediment, 3.6, true)
	var gate_inst := MeshInstance3D.new()
	gate_inst.name = "VillaRealeGatehouse"
	gate_inst.mesh = gate.commit()
	gate_inst.transform = gate_pose
	landmarks.add_child(gate_inst)

	# Torre Ascari (vintage timing & signal tower at s = 4150 m, entry to Ascari chicane)
	var tower_pose: Transform3D = ribbon.get_point_at_offset(ASCARI_TOWER_S, 16.5)
	tower_pose.origin.y = ground_y_at(tower_pose.origin)
	_foliage_keepouts.append({"side": 1.0, "s0": ASCARI_TOWER_S - 25.0, "s1": ASCARI_TOWER_S + 25.0, "depth": 35.0})
	var tower := MeshBatchScript.new()
	var tower_col := Color("#4d5361")
	var glass_col := Color("#2b4a66")
	for floor_i: int in range(4):
		var y: float = 2.2 + 4.0 * float(floor_i)
		tower.box(mat, tower_col, Transform3D(Basis.IDENTITY, Vector3(0.0, y, 0.0)), Vector3(3.8, 4.0, 3.8))
		tower.box(mat, stone_col, Transform3D(Basis.IDENTITY, Vector3(0.0, y + 2.0, 0.0)), Vector3(4.3, 0.4, 4.3))
		for face: float in [-1.0, 1.0]:
			tower.box(mat, glass_col, Transform3D(Basis.IDENTITY, Vector3(0.0, y, face * 1.92)), Vector3(1.4, 1.8, 0.1))
			tower.box(mat, glass_col, Transform3D(Basis.IDENTITY, Vector3(face * 1.92, y, 0.0)), Vector3(0.1, 1.8, 1.4))
	tower.box(mat, Color("#8cb8d9"), Transform3D(Basis.IDENTITY, Vector3(0.0, 17.8, 0.0)), Vector3(5.0, 3.0, 5.0))
	tower.cylinder(mat, Color("#a3483b"), Transform3D(Basis(Vector3.UP, PI * 0.25), Vector3(0.0, 19.3, 0.0)), 4.2, 0.0, 3.2, 4)
	tower.strut(mat, Color("#22262e"), Vector3(0.0, 22.4, 0.0), Vector3(0.0, 26.0, 0.0), 0.2)
	tower.box(mat, Color("#ffd400"), Transform3D(Basis.IDENTITY, Vector3(0.0, 8.5, -2.1)), Vector3(3.6, 6.0, 0.3))
	var tower_inst := MeshInstance3D.new()
	tower_inst.name = "TorreAscari"
	tower_inst.mesh = tower.commit()
	tower_inst.transform = tower_pose
	landmarks.add_child(tower_inst)


## Layer 4: Parco Reale di Monza. Umbrella stone pines (3 cel-toned canopy tiers), slender cypresses
## and low undergrowth, on the ground, 16..85 m off the centre line, clear of stands and the viaduct.
func _build_layer4_dense_park_foliage() -> void:
	if ribbon == null or ribbon.curve == null:
		return

	tree_multimeshes.clear()
	foliage_poses.clear()
	var foliage_root := Node3D.new()
	foliage_root.name = "ParcoRealeFoliage"
	add_child(foliage_root)

	var length_m: float = ribbon.curve.get_baked_length()
	var pine_poses: Array[Transform3D] = []
	var cypress_poses: Array[Transform3D] = []
	var bush_poses: Array[Transform3D] = []

	var rng := RandomNumberGenerator.new()
	rng.seed = 19220903 # Monza opening date: September 3, 1922

	var step_m: float = 14.0
	var count: int = ceili(length_m / step_m)

	for i: int in range(count):
		var s: float = float(i) * step_m

		# Skip pit building frontage zone
		if s > 5450.0 or s < 250.0:
			continue

		for side: float in [-1.0, 1.0]:
			var num_layers: int = rng.randi_range(1, 3)
			for layer: int in range(num_layers):
				var depth: float = 16.0 + float(layer) * 14.0 + rng.randf_range(-3.0, 5.0)
				var yaw: float = rng.randf_range(0.0, TAU)
				var scale_f: float = rng.randf_range(0.85, 1.25)
				var is_pine: bool = rng.randf() < 0.45
				if is_pine:
					depth = maxf(depth, PINE_MIN_DEPTH_M) # umbrella canopy (up to ~6.5 m) must not overhang the road
				if _foliage_blocked(s, side, depth):
					continue
				var pose: Transform3D = ribbon.get_point_at_offset(s, side * depth)
				pose.origin.y = ground_y_at(pose.origin)
				pose.basis = Basis(Vector3.UP, yaw).scaled(Vector3.ONE * scale_f)
				if is_pine:
					pine_poses.append(pose)
				else:
					cypress_poses.append(pose)
			# Shrubs fill the gap between the verge and the first trees (not on corner runoff).
			for _bush: int in range(rng.randi_range(0, 2)):
				var bush_depth: float = 14.0 + rng.randf_range(0.0, 34.0)
				var bush_s: float = s + rng.randf_range(-6.0, 6.0)
				if _foliage_blocked(bush_s, side, bush_depth) or (bush_depth < 40.0 and _near_corner(bush_s)):
					continue
				var bush: Transform3D = ribbon.get_point_at_offset(bush_s, side * bush_depth)
				bush.origin.y = ground_y_at(bush.origin)
				bush.basis = Basis(Vector3.UP, rng.randf_range(0.0, TAU)).scaled(Vector3.ONE * rng.randf_range(0.8, 1.5))
				bush_poses.append(bush)

	var mat: Material = ToonMaterials.vertex_colored(false)
	foliage_root.add_child(_foliage_batch("StonePines", _stone_pine_mesh(mat), pine_poses))
	foliage_root.add_child(_foliage_batch("ItalianCypresses", _cypress_mesh(mat), cypress_poses))
	foliage_root.add_child(_foliage_batch("UndergrowthBushes", _undergrowth_mesh(mat), bush_poses))


func _foliage_batch(node_name: String, mesh: Mesh, poses: Array[Transform3D]) -> MultiMeshInstance3D:
	var inst := _create_multimesh_instance(node_name, mesh, poses)
	tree_multimeshes.append(inst)
	foliage_poses[node_name] = poses
	return inst


## Stone pine: leaning trunk in three tilted sections under three stacked umbrella tiers.
func _stone_pine_mesh(mat: Material) -> ArrayMesh:
	var batch := MeshBatchScript.new()
	var trunk_col := Color("#4a3728")
	var leans: Array[Vector3] = [Vector3(0.08, 1.0, 0.0), Vector3(-0.10, 1.0, 0.05), Vector3(0.06, 1.0, -0.06)]
	var heights: Array[float] = [3.0, 3.0, 2.6]
	var radii: Array[float] = [0.40, 0.34, 0.28, 0.22]
	var at := Vector3.ZERO
	for i: int in range(leans.size()):
		var dir: Vector3 = leans[i].normalized()
		batch.cylinder(mat, trunk_col, Transform3D(Basis(Quaternion(Vector3.UP, dir)), at), radii[i], radii[i + 1], heights[i], 5, false)
		at += dir * heights[i]
	# 7-sided tiers; only the lowest keeps its caps (the upper tiers' caps are hidden by the tier above), ~80 tris a tree.
	batch.cylinder(mat, Color("#2d5432"), Transform3D(Basis.IDENTITY, at + Vector3(0.0, 0.2, 0.0)), 5.2, 3.8, 1.6, 7)
	batch.cylinder(mat, Color("#3f7345"), Transform3D(Basis.IDENTITY, at + Vector3(0.0, 1.5, 0.0)), 4.2, 2.8, 1.5, 7, false)
	batch.cylinder(mat, Color("#528c5a"), Transform3D(Basis.IDENTITY, at + Vector3(0.0, 2.8, 0.0)), 2.8, 0.0, 1.8, 7, false)
	return batch.commit()


## Italian cypress: dark column of two stacked tall cones on a short trunk.
func _cypress_mesh(mat: Material) -> ArrayMesh:
	var batch := MeshBatchScript.new()
	batch.cylinder(mat, Color("#4a3728"), Transform3D(Basis.IDENTITY, Vector3.ZERO), 0.22, 0.2, 2.0, 5, false)
	batch.cylinder(mat, Color("#1c3822"), Transform3D(Basis.IDENTITY, Vector3(0.0, 1.5, 0.0)), 1.5, 0.0, 11.0, 7, true, false)
	batch.cylinder(mat, Color("#234a2c"), Transform3D(Basis(Vector3.UP, 0.5), Vector3(0.0, 1.0, 0.0)), 1.1, 0.0, 8.0, 7, true, false)
	return batch.commit()


## Undergrowth: a pair of low shrub mounds, dark and light green.
func _undergrowth_mesh(mat: Material) -> ArrayMesh:
	var batch := MeshBatchScript.new()
	batch.cylinder(mat, Color("#2f6b3a"), Transform3D(Basis.IDENTITY, Vector3.ZERO), 1.3, 0.6, 0.9, 6, true, false)
	batch.cylinder(mat, Color("#3f8a47"), Transform3D(Basis.IDENTITY, Vector3(1.0, 0.0, 0.4)), 0.9, 0.4, 0.7, 6, true, false)
	return batch.commit()


## True when a plant at (s, side, depth) would sit inside a stand, the tower or under the viaduct.
func _foliage_blocked(s: float, side: float, depth: float) -> bool:
	for zone: Dictionary in _foliage_keepouts:
		if side == float(zone["side"]) and depth <= float(zone["depth"]) and s >= float(zone["s0"]) and s <= float(zone["s1"]):
			return true
	var at: Vector3 = ribbon.get_point_at_offset(s, side * depth).origin
	for footprint: Dictionary in _stand_footprints:
		var local: Vector3 = (footprint["inverse"] as Transform3D) * at
		if local.x > -6.0 and local.x < STAND_FOOTPRINT_DEPTH_M and absf(local.z) < float(footprint["half_length"]):
			return true
	for blocker: Vector3 in _sopra_blockers:
		if Vector2(at.x - blocker.x, at.z - blocker.z).length_squared() < SOPRA_FOLIAGE_CLEAR_M * SOPRA_FOLIAGE_CLEAR_M:
			return true
	return false


func _near_corner(s: float) -> bool:
	for run: Dictionary in kerbs:
		if s >= float(run["s0"]) - 40.0 and s <= float(run["s1"]) + 40.0:
			return true
	return false


## Layer 5: FIA catch fence over the armco, overhead brake gantries, retro Italian sponsor boards and
## marshal posts at the corner apexes.
func _build_layer5_trackside_safety_and_sponsors() -> void:
	if ribbon == null or furniture == null:
		return
	var safety := Node3D.new()
	safety.name = "TracksideSafetyRoot"
	add_child(safety)
	var heavy_brake: Array[Dictionary] = []
	for turn: Dictionary in builder.turns:
		if String(turn["name"]) in BRAKE_CORNERS:
			heavy_brake.append(turn)
	_build_catch_fence(safety, heavy_brake)
	_build_brake_gantries(safety, heavy_brake)
	_build_sponsor_boards(safety)
	_build_marshal_posts(safety)


## Fence panels ride the armco posts along both stands and the 200 m approach to each heavy-braking corner.
func _build_catch_fence(safety: Node3D, heavy_brake: Array[Dictionary]) -> void:
	var zones: Array[Dictionary] = []
	for stand_name: String in ["RettifiloGrandstand", "AscariGrandstand"]:
		var stand := get_node_or_null(stand_name) as Node3D
		if stand != null:
			var half: float = float(stand.get_meta("length_m")) * 0.5 + 30.0
			zones.append({"side": float(stand.get_meta("side")), "s0": float(stand.get_meta("s_centre")) - half, "s1": float(stand.get_meta("s_centre")) + half})
	for turn: Dictionary in heavy_brake:
		var enter_s: float = float(turn["s"]) - float(turn["span_m"]) * 0.5
		zones.append({"side": 0.0, "s0": enter_s - 220.0, "s1": enter_s + 40.0})
	catch_fence_poses.clear()
	for run: Dictionary in furniture.armco_runs:
		var side: float = float(run["side"])
		for index: int in range(int(run["first"]), int(run["first"]) + int(run["count"])):
			var s: float = furniture.armco_arcs[index]
			for zone: Dictionary in zones:
				if (float(zone["side"]) == 0.0 or float(zone["side"]) == side) and s >= float(zone["s0"]) and s <= float(zone["s1"]):
					catch_fence_poses.append(furniture.armco_transforms[index])
					break
	var fence := _create_multimesh_instance("CatchFence", _catch_fence_mesh(), catch_fence_poses)
	safety.add_child(fence)


## Steel post with a 45 degree inward arm, hung with a 35 % opaque wire panel (2.8 m up).
func _catch_fence_mesh() -> ArrayMesh:
	var batch := MeshBatchScript.new()
	var steel_mat: Material = ToonMaterials.vertex_colored(false)
	var steel := Color("#3a404c")
	batch.box(steel_mat, steel, Transform3D(Basis.IDENTITY, Vector3(0.35, 1.2, 0.0)), Vector3(0.1, 2.4, 0.1))
	batch.strut(steel_mat, steel, Vector3(0.35, 2.4, 0.0), Vector3(-0.1, 2.85, 0.0), 0.1)
	var wire := StandardMaterial3D.new()
	wire.albedo_color = Color(0.118, 0.137, 0.176, 0.35)
	wire.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	wire.cull_mode = BaseMaterial3D.CULL_DISABLED
	wire.roughness = 1.0
	for facing: float in [-1.0, 1.0]:
		batch.quad(wire, Color.WHITE, Vector3(0.3, 0.9, -2.0), Vector3(0.3, 0.9, 2.0), Vector3(0.3, 2.8, 2.0), Vector3(0.3, 2.8, -2.0), Vector3(facing, 0.0, 0.0))
	return batch.commit()


## 200/150/100/50 m boards on a truss gantry across the road, facing the cars braking for the corner.
func _build_brake_gantries(safety: Node3D, heavy_brake: Array[Dictionary]) -> void:
	var gantries := Node3D.new()
	gantries.name = "BrakingGantries"
	safety.add_child(gantries)
	var mat: Material = ToonMaterials.vertex_colored(false)
	var frames := MeshBatchScript.new()
	var steel := Color("#3a404c")
	var span: float = ribbon.road_half_width_m + 3.5
	for turn: Dictionary in heavy_brake:
		var enter_s: float = float(turn["s"]) - float(turn["span_m"]) * 0.5
		for distance: int in BRAKE_DISTANCES_M:
			var pose: Transform3D = ribbon.get_point_at_offset(enter_s - float(distance), 0.0)
			for side: float in [-1.0, 1.0]:
				frames.box(mat, steel, pose * Transform3D(Basis.IDENTITY, Vector3(side * span, 3.2, 0.0)), Vector3(0.5, 7.4, 0.5))
			frames.truss(mat, steel, pose * Vector3(-span, 6.4, 0.0), pose * Vector3(span, 6.4, 0.0), Vector3.UP, 0.9, 8, 0.16)
			frames.box(mat, Color("#14161c"), pose * Transform3D(Basis.IDENTITY, Vector3(0.0, 6.4, 0.2)), Vector3(3.6, 1.7, 0.2))
			frames.box(mat, Color("#ffd400"), pose * Transform3D(Basis.IDENTITY, Vector3(0.0, 5.5, 0.2)), Vector3(3.6, 0.12, 0.22))
			var label := Label3D.new()
			label.name = "Board_%d_%d" % [int(turn["number"]), distance]
			label.text = str(distance)
			label.font = BoardFont
			label.font_size = 96
			label.pixel_size = 0.014
			label.modulate = Color("#ffd400")
			label.outline_size = 0
			label.transform = pose * Transform3D(Basis.IDENTITY, Vector3(0.0, 6.4, 0.32))
			label.set_meta("meters", distance)
			label.set_meta("corner", String(turn["name"]))
			gantries.add_child(label)
	var frame_inst := MeshInstance3D.new()
	frame_inst.name = "GantryFrames"
	frame_inst.mesh = frames.commit()
	gantries.add_child(frame_inst)


## Retro boards behind the armco, one MultiMesh per brand; a few carry the name in real type.
func _build_sponsor_boards(safety: Node3D) -> void:
	var sponsors := Node3D.new()
	sponsors.name = "SponsorBoards"
	safety.add_child(sponsors)
	var poses: Array = []
	for _brand: int in range(SPONSORS.size()):
		poses.append([] as Array[Transform3D])
	var index: int = 0
	var s: float = 300.0
	while s < ribbon.length_m - 300.0:
		for side: float in [-1.0, 1.0]:
			if not furniture.has_armco_at(side, s) or _in_stand_zone(s, side):
				continue
			var pose: Transform3D = ribbon.get_point_at_offset(s, furniture.armco_lateral(side, s) + side * 1.4)
			if side < 0.0:
				pose.basis = pose.basis.rotated(pose.basis.y, PI)
			pose.origin.y = ground_y_at(pose.origin)
			(poses[index % SPONSORS.size()] as Array[Transform3D]).append(pose)
			index += 1
		s += SPONSOR_STEP_M
	for brand: int in range(SPONSORS.size()):
		var spec: Dictionary = SPONSORS[brand]
		var brand_poses: Array[Transform3D] = poses[brand]
		sponsors.add_child(_create_multimesh_instance(String(spec["node"]), _sponsor_mesh(spec), brand_poses))
		if not brand_poses.is_empty():
			var hero: Transform3D = brand_poses[0]
			var label := Label3D.new()
			label.name = "Label_%s" % spec["node"]
			label.text = String(spec["text"])
			label.font = BoardFont
			label.font_size = 72
			label.pixel_size = 0.016
			label.modulate = spec["ink"]
			label.outline_size = 0
			label.transform = hero * Transform3D(Basis(Vector3.UP, -PI * 0.5), Vector3(-0.12, 1.65, 0.0))
			sponsors.add_child(label)


func _sponsor_mesh(spec: Dictionary) -> ArrayMesh:
	var batch := MeshBatchScript.new()
	var mat: Material = ToonMaterials.vertex_colored(false)
	batch.box(mat, spec["ground"], Transform3D(Basis.IDENTITY, Vector3(0.0, 1.65, 0.0)), Vector3(0.12, 1.5, 6.0))
	for band: float in [-0.52, 0.52]:
		batch.box(mat, spec["band"], Transform3D(Basis.IDENTITY, Vector3(-0.03, 1.65 + band, 0.0)), Vector3(0.14, 0.3, 6.0))
	for z: float in [-2.6, 2.6]:
		batch.box(mat, Color("#3a404c"), Transform3D(Basis.IDENTITY, Vector3(0.1, 0.55, z)), Vector3(0.12, 1.1, 0.12))
	return batch.commit()


func _in_stand_zone(s: float, side: float) -> bool:
	for zone: Dictionary in _foliage_keepouts:
		if side == float(zone["side"]) and s >= float(zone["s0"]) and s <= float(zone["s1"]):
			return true
	return false


## A small marshal booth with a hazard-orange roof behind the armco at the outside of every turn.
func _build_marshal_posts(safety: Node3D) -> void:
	var batch := MeshBatchScript.new()
	var mat: Material = ToonMaterials.vertex_colored(false)
	var count: int = 0
	for turn: Dictionary in builder.turns:
		var apex_s: float = float((turn["apex_s"] as Array)[0])
		var side: float = 1.0 if ribbon.get_curvature_at(apex_s) >= 0.0 else -1.0
		var pose: Transform3D = ribbon.get_point_at_offset(apex_s, furniture.armco_lateral(side, apex_s) + side * 3.2)
		if side < 0.0:
			pose.basis = pose.basis.rotated(pose.basis.y, PI)
		pose.origin.y = ground_y_at(pose.origin)
		batch.box(mat, WHITE, pose * Transform3D(Basis.IDENTITY, Vector3(0.0, 1.3, 0.0)), Vector3(2.0, 2.6, 2.4))
		batch.box(mat, Color("#2b4a66"), pose * Transform3D(Basis.IDENTITY, Vector3(-1.02, 1.6, 0.0)), Vector3(0.05, 1.0, 1.6))
		batch.box(mat, Color("#ff6a00"), pose * Transform3D(Basis.IDENTITY, Vector3(-0.2, 2.75, 0.0)), Vector3(3.0, 0.22, 3.0))
		batch.strut(mat, Color("#3a404c"), pose.origin + Vector3(0.0, 2.8, 0.0), pose.origin + Vector3(0.0, 4.6, 0.0), 0.08)
		count += 1
	var inst := MeshInstance3D.new()
	inst.name = "MarshalPosts"
	inst.mesh = batch.commit()
	inst.set_meta("count", count)
	safety.add_child(inst)


func _create_multimesh_instance(node_name: String, mesh: Mesh, poses: Array[Transform3D]) -> MultiMeshInstance3D:
	var batch := MultiMesh.new()
	batch.transform_format = MultiMesh.TRANSFORM_3D
	batch.mesh = mesh
	batch.instance_count = poses.size()
	for i: int in range(poses.size()):
		batch.set_instance_transform(i, poses[i])
	var inst := MultiMeshInstance3D.new()
	inst.name = node_name
	inst.multimesh = batch
	inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return inst
