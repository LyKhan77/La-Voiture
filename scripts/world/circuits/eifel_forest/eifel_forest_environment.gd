class_name EifelForestEnvironment
extends "res://scripts/world/circuits/base/circuit_environment.gd"

## Eifel Forest Ring environment: production Tier A corridor (asphalt, kerbs,
## Armco, Tecpro, braking boards, flag panels, catch fence, rubber groove), the
## approved procedural Eifel heightfield/forest/paddock, four hero landmark GLBs,
## and the Moody Eifel Overcast sky with a wet 60%-rain track. Ported from the
## approved Route 2 build; the runtime never reads the mapgen repo.

const Layout := preload("res://scripts/world/circuits/eifel_forest/eifel_forest_layout.gd")
const TerrainField := preload("res://scripts/world/circuits/eifel_forest/eifel_forest_terrain.gd")
const Strip := preload("res://scripts/world/circuits/eifel_forest/eifel_forest_strip.gd")
const Toon := preload("res://scripts/world/shared/toon_materials.gd")
const TreeWindShader := preload("res://shaders/eifel_forest_tree_wind.gdshader")
const ToonLookScript := preload("res://scripts/world/circuits/eifel_forest/eifel_forest_toon.gd")
const Liveries := preload("res://scripts/car/team_liveries.gd")
const MeshBatchScript := preload("res://scripts/world/shared/mesh_batch.gd")
const PitKit := preload("res://scripts/world/shared/pit_kit.gd")
const PitCrewFigureScript := preload("res://scripts/car/pit_crew_figure.gd")
const Line := preload("res://scripts/car/adaptive_racing_line.gd")
const Surface := preload("res://scripts/world/shared/enhanced_track_geometry.gd")
const PitZone := preload("res://scripts/world/shared/pit_zone.gd")
const SkyController := preload("res://scripts/world/shared/shared_cel_sky_controller.gd")
const Fence := preload("res://scripts/world/circuits/eifel_forest/eifel_forest_catch_fence.gd")

const ASSET_DIR := "res://assets/tracks/eifel_forest/models"
const ENVIRONMENT_TRIANGLE_BUDGET := 430000
const TREE_TARGET := 1800
const GRASS_TARGET := 1000
const SHRUB_LIMIT := 1100
const TREE_SPACING_M := 13.0
const MAX_BAND_DEPTH_M := 260.0

## Moody Eifel Overcast & Misty Mountain Haze (approved): 52-degree sun under a
## low grey cloud deck, misty valley haze, wet asphalt. DAY / SUNSET / NIGHT.
const PROFILES: Array[Dictionary] = [
	{"sun": Color("#f2f4ee"), "sun_energy": 0.98, "sun_pitch": 52.0, "sun_yaw": -118.0, "ambient": Color("#ccd7da"), "ambient_energy": 0.22, "fog": Color("#c6d1d4"), "fog_density": 0.00012, "sky_top": Color("#7c9fb8"), "sky_horizon": Color("#dae1e2"), "ground": Color("#3f4c3a")},
	{"sun": Color("#ffb27a"), "sun_energy": 0.75, "sun_pitch": 14.0, "sun_yaw": -104.0, "ambient": Color("#dfb79d"), "ambient_energy": 0.32, "fog": Color("#e2c3a4"), "fog_density": 0.00016, "sky_top": Color("#8a7fa0"), "sky_horizon": Color("#f6c795"), "ground": Color("#5d4a33")},
	{"sun": Color("#9fb6d6"), "sun_energy": 0.38, "sun_pitch": 40.0, "sun_yaw": 92.0, "ambient": Color("#6f86a8"), "ambient_energy": 0.23, "fog": Color("#16232f"), "fog_density": 0.00035, "sky_top": Color("#0a1420"), "sky_horizon": Color("#26384a"), "ground": Color("#05080f")},
]

var terrain
var line: Line
var shared_sky: SkyController
var kerbs: Array[Dictionary] = []
var runoff_plans: Array[Dictionary] = []
var _stats: Dictionary = {}

var _compiled: Dictionary
var _segments: Array = Strip.SEGMENTS
var _rng := RandomNumberGenerator.new()
var _landmark_records: Array[Dictionary] = []
var _exclusion: Array = [] # [Vector2 centre, radius]
var _world_environment: WorldEnvironment
var _sun: DirectionalLight3D
var _camera: Camera3D
var _tod: Dictionary = {"mode": 0, "floodlights": 0.0, "stars_opacity": 0.0}
var _gloom: float = 0.0
var _screens: Array = []
var _wind_materials: Array[ShaderMaterial] = []
var _glow_materials: Array[ShaderMaterial] = []
var _light_level: float = -1.0
var _sky_rig := WorldSkyRig.new()


func _init() -> void:
	circuit_id = Layout.CIRCUIT_ID
	_sky_rig.aces_tonemap = false
	_sky_rig.fog_sky_affect = 0.35


func build(p_ribbon: TrackRibbonScript, source: Variant = null) -> void:
	if built:
		return
	ribbon = p_ribbon
	_rng.seed = 20261031
	_compiled = _compiled_from(source)
	if _compiled.is_empty():
		push_warning("eifel-env: no compiled track data")
		built = true
		return
	var started := Time.get_ticks_msec()
	line = Line.new(ribbon)
	_build_corridor()
	terrain = TerrainField.new(_compiled)
	_add_terrain()
	_build_exclusions()
	_build_landmarks()
	_build_paddock_dressing()
	_build_woodland()
	_build_meadow()
	_build_chaparral()
	_build_boulders()
	_build_valley_mist()
	_finish(started)


func _compiled_from(source: Variant) -> Dictionary:
	if source is Dictionary and (source as Dictionary).has("points"):
		return source as Dictionary
	if source != null:
		var embedded: Variant = source.get("compiled")
		if embedded is Dictionary and (embedded as Dictionary).has("points"):
			return embedded as Dictionary
	if ribbon == null or ribbon.curve == null:
		return {}
	var points := PackedVector3Array()
	for i: int in range(ribbon.curve.point_count - 1):
		points.append(ribbon.curve.get_point_position(i))
	return {"points": points, "step_m": ribbon.length_m / float(maxi(1, points.size())), "length_m": ribbon.length_m}


## Tier A: shared corridor kit (asphalt, kerbs, runoff, groove, Armco, Tecpro,
## braking boards, flag panels) and the shipped FIA paddock pieces are built by
## the circuit's PitComplex; the catch fence reads the same furniture extents.
func _build_corridor() -> void:
	for i: int in range(0, ceili(ribbon.length_m), 2):
		var s := float(i)
		var curvature := ribbon.get_curvature_at(s)
		if absf(curvature) >= 0.006:
			if not kerbs.is_empty() and is_equal_approx(signf(float(kerbs[-1].side)), signf(curvature)) and s - float(kerbs[-1].s1) < 6.0:
				kerbs[-1]["s1"] = s + 2.0
			elif kerbs.is_empty() or float(kerbs[-1].s1) - float(kerbs[-1].s0) >= 14.0 or s - float(kerbs[-1].s1) >= 6.0:
				kerbs.append({"s0": s, "s1": s + 2.0, "side": signf(curvature)})
	# Keep only real corner runs, at least 14 m long.
	var runs: Array[Dictionary] = []
	for run: Dictionary in kerbs:
		if float(run["s1"]) - float(run["s0"]) >= 14.0:
			runs.append(run)
	kerbs = runs
	_add_kerb_group("SawtoothKerbsEifel", kerbs, ribbon.road_half_width_m - Surface.KERB_INSET_M, Surface.KERB_RED)
	var zone := PitZone.from_layout(_pit_layout(), ribbon.length_m, 70.0, 70.0)
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
	furniture = FurnitureScript.new()
	furniture.name = "TracksideFurniture"
	add_child(furniture)
	furniture.build(ribbon, line, kerbs, runoff_plans, _hero_zones(), zone)
	flag_panels = furniture.flag_panels
	Fence.build(self, ribbon, furniture, kerbs)
	shared_sky = SkyController.new()
	shared_sky.build(self, ribbon, 20261031)
	var pit := get_parent().get_node_or_null("PitLane")
	if pit != null:
		var stand := pit.get_node_or_null("MainGrandstand")
		if stand != null:
			var screen := stand.find_child("Jumbotron", true, false)
			if screen != null:
				_screens.append(screen)
	for node: Node in find_children("*", "MultiMeshInstance3D", true, false):
		var instance := node as MultiMeshInstance3D
		if instance.material_override is ShaderMaterial and (instance.material_override as ShaderMaterial).shader == TreeWindShader:
			_wind_materials.append(instance.material_override)
	_collect_glow_materials(self)
	if pit != null:
		_collect_glow_materials(pit)


func _pit_layout() -> Dictionary:
	var pit := get_parent().get_node_or_null("PitLane") if get_parent() != null else null
	if pit != null and pit.has_method("sim_layout"):
		return pit.call("sim_layout")
	return {"entry_s": Layout.PIT_ENTRY_S, "exit_s": Layout.PIT_EXIT_S, "lane_length_m": Layout.PIT_LANE_LENGTH_M, "stall_pitch_m": Layout.PIT_STALL_PITCH_M}


## Hero zones keep Armco/runoff/Tecpro clear of the four landmark footprints.
func _hero_zones() -> Array[Dictionary]:
	return [
		{"side": -1.0, "s0": 2620.0, "s1": 2900.0, "lateral": 150.0},
		{"side": -1.0, "s0": 780.0, "s1": 920.0, "lateral": 60.0},
		{"side": -1.0, "s0": 1540.0, "s1": 1620.0, "lateral": 50.0},
		{"side": 1.0, "s0": 300.0, "s1": 400.0, "lateral": 60.0},
	]


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
	_sky_rig.apply(_world_environment, _sun, PROFILES[mode], gloom, Color("#8d8478"))
	if shared_sky != null:
		shared_sky.apply_time_of_day(tod, gloom)
		if shared_sky.cloud_material != null:
			shared_sky.cloud_material.set_shader_parameter("cloud_shadow", [Color("#b6c4ca"), Color("#a4889b"), Color("#1f2744")][mode])
			shared_sky.cloud_material.set_shader_parameter("cloud_mid", [Color("#e2eaec"), Color("#e8b08a"), Color("#404f74")][mode])
			shared_sky.cloud_material.set_shader_parameter("cloud_rim", [Color("#ffffff"), Color("#ffd9a8"), Color("#b8e4ff")][mode])
	# The approved Moody Eifel look is FILMIC, not ACES: a low grey overcast,
	# volumetric valley haze and a brighter sky dome; match the sandbox ToonLook.
	if _world_environment != null and _world_environment.environment != null:
		var env := _world_environment.environment
		env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
		env.tonemap_exposure = 1.0
		env.volumetric_fog_enabled = true
		env.volumetric_fog_density = [0.0008, 0.0014, 0.004][mode]
		env.volumetric_fog_albedo = Color("#c9d3d5")
		env.volumetric_fog_length = 2600.0
		env.adjustment_enabled = true
		env.adjustment_saturation = 1.02
		env.adjustment_contrast = 1.05
		env.adjustment_brightness = 1.0
		if env.sky != null and env.sky.sky_material is ProceduralSkyMaterial:
			var sky_material := env.sky.sky_material as ProceduralSkyMaterial
			sky_material.sun_angle_max = 0.0
			sky_material.sky_energy_multiplier = [1.15, 1.18, 1.0][mode]
	var floodlights := float(tod.get("floodlights", 0.0))
	if not is_equal_approx(_light_level, floodlights):
		_light_level = floodlights
		Toon.set_glow_energy(floodlights * 0.8)
		for material: ShaderMaterial in _glow_materials:
			material.set_shader_parameter("glow_energy", floodlights * 0.8)
	var pit := get_parent().get_node_or_null("PitLane") if get_parent() != null else null
	if pit != null and pit.has_method("set_lights_on"):
		pit.call("set_lights_on", floodlights > 0.1)


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
	return terrain.height_at(pos.x, pos.z) if terrain != null else pos.y


func _extra_stats() -> Dictionary:
	var result: Dictionary = _stats.duplicate()
	result["kerb_runs"] = kerbs.size()
	return result


func _collect_glow_materials(node: Node) -> void:
	if node is MeshInstance3D:
		var instance := node as MeshInstance3D
		if instance.mesh != null:
			for index: int in range(instance.mesh.get_surface_count()):
				var material := instance.get_active_material(index) as ShaderMaterial
				if material != null and material.shader != null and "glow_energy" in material.shader.code:
					_glow_materials.append(material)
	elif node is MultiMeshInstance3D:
		var multi := node as MultiMeshInstance3D
		if multi.material_override is ShaderMaterial:
			_glow_materials.append(multi.material_override)
	for child: Node in node.get_children():
		_collect_glow_materials(child)


# --- terrain ---------------------------------------------------------------------------

func _add_terrain() -> void:
	var node := MeshInstance3D.new()
	node.name = "Terrain"
	node.mesh = terrain.terrain_mesh
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	node.set_meta("heightgrid", terrain.heightgrid)
	add_child(node)
	var skirt := MeshInstance3D.new()
	skirt.name = "TerrainSkirt"
	skirt.mesh = terrain.skirt_mesh
	skirt.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(skirt)
	var base := MeshInstance3D.new()
	base.name = "TerrainBase"
	var plane := PlaneMesh.new()
	plane.size = Vector2(8000.0, 8000.0)
	base.mesh = plane
	base.position.y = float(terrain.heightgrid.get("base_y", -28.0))
	base.material_override = Toon.make(Color("#33402d"))
	base.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(base)
	var ridge := MeshInstance3D.new()
	ridge.name = "DistantRidge"
	ridge.mesh = terrain.ridge_mesh
	ridge.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(ridge)
	set_meta("heightgrid", terrain.heightgrid)


# --- hero landmarks --------------------------------------------------------------------

## Frozen Tier B stations (procedural-spec section 4). Asset convention (from the
## GLB author): ground at y=0, centred on the origin within its footprint. The
## flyover deck spans local X; the arena body extends into +X (away from track).
func _landmark_specs() -> Array:
	return [
		{"stem": "eifel_nurburg_castle", "s": Layout.LANDMARK_CASTLE_S, "side": -1.0,
			"offset": Layout.LANDMARK_CASTLE_OFFSET_M, "length": 64.0, "depth": 64.0, "local_z": 0.0,
			"anchor": "terrain", "pier_half": 0.0,
			"note": "Burg Nurburg castle on the volcanic crag above the T10 RTL-Kurve crest"},
		{"stem": "eifel_mercedes_arena_amphitheater", "s": Layout.LANDMARK_ARENA_S, "side": -1.0,
			"offset": Layout.LANDMARK_ARENA_OFFSET_M, "length": 160.0, "depth": 45.0, "local_z": 0.0,
			"anchor": "ground", "pier_half": 0.0,
			"note": "curved cantilever-canopy Mercedes-Arena grandstand around T2-T4"},
		{"stem": "eifel_warsteiner_flyover_bridge", "s": Layout.LANDMARK_BRIDGE_S, "side": -1.0,
			"offset": Layout.LANDMARK_BRIDGE_OFFSET_M, "length": 44.0, "depth": 8.0, "local_z": 0.0,
			"lat_override": 0.0, "anchor": "deck", "pier_half": 22.0,
			"note": "spec anchor L offset 0 m; the suspension deck spans the Fordkurve descent, piers outside the asphalt"},
		{"stem": "eifel_historic_paddock_archway", "s": Layout.LANDMARK_ARCHWAY_S, "side": 1.0,
			"offset": Layout.LANDMARK_ARCHWAY_OFFSET_M, "length": 20.0, "depth": 10.0, "local_z": 0.0,
			"anchor": "terrain", "pier_half": 0.0,
			"note": "1927 red-brick paddock gateway to the old Nordschleife, right of the main straight"},
	]


func _model_frame(spec: Dictionary) -> Transform3D:
	var s := float(spec["s"])
	var lateral := float(spec.get("lat_override", spec["offset"]))
	var frame := Layout.side_frame(ribbon, s, float(spec["side"]), lateral)
	# Architecture sits level: keep the frame heading but drop the road pitch, so a
	# 160 m stand is not tilted along the gradient and its base never lifts.
	var flat_forward := Vector3(-frame.basis.z.x, 0.0, -frame.basis.z.z)
	if flat_forward.length_squared() < 0.0001:
		flat_forward = Vector3.FORWARD
	flat_forward = flat_forward.normalized()
	var level_basis := Basis(flat_forward.cross(Vector3.UP).normalized(), Vector3.UP, -flat_forward)
	match String(spec["anchor"]):
		"deck":
			# Sit the deck on the lowest ground under either pier so no support floats.
			var g: float = terrain.height_at(frame.origin.x, frame.origin.z)
			var pier_half := float(spec.get("pier_half", 17.0))
			for sign: float in [-1.0, 1.0]:
				var pier := frame.origin + frame.basis.x * (sign * pier_half)
				g = minf(g, terrain.height_at(pier.x, pier.z))
			frame.origin.y = g + 0.02
		"terrain":
			frame.origin.y = terrain.height_at(frame.origin.x, frame.origin.z) - 0.05
		_:
			# Terraces are cut at road bed level; ground the slab exactly there.
			frame.origin.y = _road_y(s) - Layout.ROADBED_DROP_M + 0.02
	var shift := level_basis.z * float(spec.get("local_z", 0.0))
	return Transform3D(level_basis, frame.origin + shift)


func _build_exclusions() -> void:
	for spec: Dictionary in _landmark_specs():
		var lateral := float(spec.get("lat_override", spec["offset"]))
		var frame := Layout.side_frame(ribbon, float(spec["s"]), float(spec["side"]), lateral)
		var length_m := float(spec["length"])
		var depth_m := float(spec["depth"])
		# A long stand is cleared by a chain of small circles, not one huge disc, so
		# the forest can grow right up to the concourse.
		var count := maxi(1, ceili(length_m / 30.0))
		var radius := depth_m * 0.5 + 10.0
		var body_centre := frame.origin + frame.basis.x * (depth_m * 0.5)
		for index in range(count):
			var t := (float(index) + 0.5) / float(count) - 0.5
			var at := body_centre + frame.basis.z * (t * length_m)
			_exclusion.append([Vector2(at.x, at.z), radius])
	# Keep the sight line from the track to the castle and the arena clear of conifers.
	for view: Array in [[Layout.LANDMARK_CASTLE_S, -1.0, 62.0, 54.0], [Layout.LANDMARK_ARENA_S, -1.0, 18.0, 46.0]]:
		var mid := Layout.side_frame(ribbon, float(view[0]), float(view[1]), float(view[2]))
		_exclusion.append([Vector2(mid.origin.x, mid.origin.z), float(view[3])])


func _build_landmarks() -> void:
	var holder := Node3D.new()
	holder.name = "HeroLandmarks"
	add_child(holder)
	for spec: Dictionary in _landmark_specs():
		_place_model(holder, spec, _model_frame(spec))


func _place_model(parent: Node3D, spec: Dictionary, xform: Transform3D) -> void:
	var stem := String(spec["stem"])
	var path := "%s/%s.glb" % [ASSET_DIR, stem]
	var record := {
		"id": stem,
		"glb": path,
		"s": float(spec["s"]),
		"side": "R" if float(spec["side"]) > 0.0 else "L",
		"offset_m": float(spec["offset"]),
		"placed_lateral_m": float(spec.get("lat_override", spec["offset"])),
		"anchor": String(spec["anchor"]),
		"note": String(spec["note"]),
		"placed": false,
	}
	if not FileAccess.file_exists(path):
		push_warning("eifel-env: missing hero landmark %s (skipped, no proxy box)" % path)
		_landmark_records.append(record)
		return
	var model := _load_model(stem)
	if model == null:
		push_warning("eifel-env: cannot read %s" % path)
		_landmark_records.append(record)
		return
	model.name = stem
	model.transform = xform
	parent.add_child(model)
	record["placed"] = true
	record["triangles"] = _mesh_triangles(model)
	record["position"] = [snappedf(xform.origin.x, 0.01), snappedf(xform.origin.y, 0.01), snappedf(xform.origin.z, 0.01)]
	_landmark_records.append(record)


func _load_model(stem: String) -> Node3D:
	var path := "%s/%s.glb" % [ASSET_DIR, stem]
	var doc := GLTFDocument.new()
	var state := GLTFState.new()
	if doc.append_from_file(ProjectSettings.globalize_path(path), state) != OK:
		return null
	return doc.generate_scene(state) as Node3D


# --- paddock dressing ------------------------------------------------------------------

func _build_paddock_dressing() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var tents := 0
	var transporters := 0
	var vehicles := 0
	var motorhomes := 0
	var generators := 0
	# Solid team hospitality tents (walls + floor, not floating roofs) on the terrace.
	for station: float in [3935.0, 3983.0, 4031.0, 4079.0, 235.0, 283.0]:
		var frame := _paddock_frame(station, 40.0)
		var color: Color = Liveries.color_for(tents)
		_box(st, frame, Vector3(0.0, 0.05, 0.0), Vector3(12.0, 0.1, 8.0), Color("#d9d7cf"))
		_box(st, frame, Vector3(0.0, 1.45, -3.9), Vector3(12.0, 2.9, 0.16), Color("#e8e6de"))
		for side: float in [-1.0, 1.0]:
			_box(st, frame, Vector3(side * 5.9, 1.45, 0.0), Vector3(0.16, 2.9, 8.0), Color("#e8e6de"))
		_box(st, frame, Vector3(0.0, 3.0, 0.0), Vector3(12.4, 0.3, 8.4), color.lightened(0.2))
		for corner: Vector2 in [Vector2(-5.4, -3.4), Vector2(5.4, -3.4), Vector2(-5.4, 3.4), Vector2(5.4, 3.4)]:
			_box(st, frame, Vector3(corner.x, 1.5, corner.y), Vector3(0.18, 3.0, 0.18), Color("#d7dade"))
		_box(st, frame, Vector3(0.0, 0.75, -2.6), Vector3(5.2, 0.9, 1.0), Color("#3a3f4a"))
		_box(st, frame, Vector3(2.4, 1.35, -2.6), Vector3(1.8, 0.3, 0.8), color)
		_box(st, frame, Vector3(3.8, 3.7, 1.8), Vector3(1.4, 1.1, 1.0), Color("#9aa1ae"))
		tents += 1
	# One team transporter per garage, parked in the working lane behind the block.
	for index in range(10):
		var station := 48.0 + float(index) * 14.5
		var frame := _paddock_frame(station, 52.0)
		var color: Color = Liveries.color_for(index)
		_box(st, frame, Vector3(0.0, 1.75, 0.0), Vector3(4.6, 3.5, 12.0), Color("#e6e8ec"))
		_box(st, frame, Vector3(0.0, 2.45, 0.0), Vector3(4.65, 0.5, 12.0), color)
		_box(st, frame, Vector3(0.0, 3.3, 0.0), Vector3(4.8, 0.25, 12.4), Color("#9aa1ae"))
		_box(st, frame, Vector3(2.36, 1.55, 0.0), Vector3(0.08, 1.4, 10.8), Color("#b9c0cc"))
		transporters += 1
	# Motorhomes / hospitality units along the paddock boulevard.
	for index in range(8):
		var station: float = 228.0 + float(index % 4) * 19.0 if index < 4 else 3944.0 + float(index - 4) * 41.0
		var frame := _paddock_frame(station, 66.0)
		var color: Color = Liveries.color_for(index + 2)
		_box(st, frame, Vector3(0.0, 1.8, 0.0), Vector3(3.2, 3.6, 9.0), Color("#eceae2"))
		_box(st, frame, Vector3(0.0, 2.65, 0.0), Vector3(3.24, 0.45, 9.0), color)
		_box(st, frame, Vector3(1.62, 2.0, -1.2), Vector3(0.05, 1.1, 3.2), Color("#4f7fa8"))
		_box(st, frame, Vector3(-1.62, 2.0, 1.2), Vector3(0.05, 1.1, 3.2), Color("#4f7fa8"))
		motorhomes += 1
	# Parked support vehicles / golf carts along the post-garage apron.
	for index in range(6):
		var station := 224.0 + float(index) * 11.0
		var frame := _paddock_frame(station, 30.0)
		var color: Color = Liveries.color_for(index + 4)
		_box(st, frame, Vector3(0.0, 0.75, 0.0), Vector3(1.9, 1.2, 4.4), color)
		_box(st, frame, Vector3(0.0, 1.55, -0.4), Vector3(1.7, 0.9, 2.0), color.darkened(0.2))
		vehicles += 1
	# Generator / fuel units in the service lane behind the garages.
	for station: float in [62.0, 104.0, 146.0, 188.0]:
		var frame := _paddock_frame(station, 36.0)
		_box(st, frame, Vector3(0.0, 0.8, 0.0), Vector3(2.4, 1.6, 3.6), Color("#6f7680"))
		_box(st, frame, Vector3(0.0, 1.65, 0.0), Vector3(2.5, 0.12, 3.7), Color("#3a3f4a"))
		_box(st, frame, Vector3(1.22, 0.9, 0.0), Vector3(0.05, 0.9, 2.2), Color("#ffd400"))
		generators += 1
	# Helipad circle on the paddock apron.
	var pad_centre := _paddock_frame(270.0, 78.0).origin + Vector3.UP * 0.02
	_disc(st, pad_centre, 9.0, 24, Color("#3d4249"))
	_disc(st, pad_centre + Vector3.UP * 0.01, 8.0, 24, Color("#2f6b46"))
	var pad_frame := _paddock_frame(270.0, 78.0)
	for offset: Vector3 in [Vector3(-1.25, 0.0, 0.0), Vector3(1.25, 0.0, 0.0)]:
		_box(st, pad_frame, offset + Vector3.UP * 0.05, Vector3(0.7, 0.05, 5.0), Color("#f2f4f6"))
	_box(st, pad_frame, Vector3(0.0, 0.05, 0.0), Vector3(2.2, 0.05, 0.7), Color("#f2f4f6"))
	var grounds := _build_paddock_grounds(st)
	var mesh := st.commit()
	if mesh != null:
		var node := MeshInstance3D.new()
		node.name = "PaddockDressing"
		node.mesh = mesh
		node.material_override = Toon.vertex_colored(false)
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		add_child(node)
	# Paddock crowd: 120 figures on the apron and boulevard, never in the lane,
	# the garages or the helipad.
	var crowd := MeshBatchScript.new()
	var crowd_flat: ShaderMaterial = Toon.vertex_colored(false)
	var roles: Array = PitKit.standby_roles()
	var placed_people := 0
	var attempts := 0
	while placed_people < 120 and attempts < 900:
		attempts += 1
		var station := _rng.randf_range(4950.0, 5145.0) if placed_people % 2 == 0 else _rng.randf_range(215.0, 295.0)
		var lateral := _rng.randf_range(22.0, 92.0)
		var local_s := fposmod(station, Layout.LENGTH_M)
		if local_s >= 45.0 and local_s <= 195.0 and lateral < 34.0:
			continue
		if Vector2(station - 270.0, lateral - 78.0).length() < 11.0:
			continue
		var frame: Transform3D = ribbon.call("get_point_at_offset", station, lateral)
		var ground: float = float(terrain.height_at(frame.origin.x, frame.origin.z))
		var yaw := _rng.randf() * TAU
		PitCrewFigureScript.add(crowd, crowd_flat, Transform3D(Basis(Vector3.UP, yaw), Vector3(frame.origin.x, ground + 0.01, frame.origin.z)), int(roles[placed_people % roles.size()]), Liveries.color_for(placed_people % 10))
		placed_people += 1
	var crowd_node := MeshInstance3D.new()
	crowd_node.name = "PaddockCrowd"
	crowd_node.mesh = crowd.commit()
	crowd_node.material_override = crowd_flat
	crowd_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(crowd_node)
	_stats["paddock_tents"] = tents
	_stats["paddock_transporters"] = transporters
	_stats["paddock_motorhomes"] = motorhomes
	_stats["paddock_vehicles"] = vehicles
	_stats["paddock_generators"] = generators
	_stats["paddock_people"] = placed_people
	_stats["paddock_parking_cars"] = int(grounds["cars"])
	_stats["paddock_pines"] = int(grounds["palms"])
	_stats["paddock_umbrellas"] = int(grounds["umbrellas"])
	_stats["paddock_boards"] = int(grounds["boards"])
	_stats["helipad"] = true


## Paddock grounds: parked cars, palms, fan-zone umbrellas and sponsor boards so
## the wide apron around the pit block is not a bare slab.
func _build_paddock_grounds(st: SurfaceTool) -> Dictionary:
	var cars := 0
	var palms := 0
	var umbrellas := 0
	var boards := 0
	# Two parking rows on the outer apron (stations wrap across the start line).
	for index in range(12):
		_car(st, _paddock_frame(3850.0 + float(index) * 20.0, 74.0), Liveries.color_for(index))
		cars += 1
	for index in range(13):
		_car(st, _paddock_frame(18.0 + float(index) * 20.0, 86.0), Liveries.color_for(index + 3))
		cars += 1
	# White bay lines between the parked cars.
	for row: float in [74.0, 86.0]:
		for index in range(13):
			var line_s: float = 8.0 + float(index) * 20.0 if row > 80.0 else 3840.0 + float(index) * 20.0
			var line := _paddock_frame(line_s, row - 1.6)
			_box(st, line, Vector3(0.0, 0.02, 0.0), Vector3(4.0, 0.02, 0.16), Color("#e8e6dc"))
	# Eifel pine belt along the paddock boulevard.
	for station: float in [30.0, 78.0, 126.0, 174.0, 222.0, 270.0, 4980.0, 5040.0, 5090.0]:
		_pine(st, _paddock_frame(station, 82.0), 8.5 + float(palms % 3) * 1.1)
		palms += 1
	# Umbrellas + tables around the hospitality tents.
	for index in range(12):
		var station: float = 240.0 + float(index % 6) * 9.0 if index < 6 else 3970.0 + float(index - 6) * 17.0
		var frame := _paddock_frame(station, 50.0 + float(index % 3) * 5.0)
		_umbrella(st, frame, Liveries.color_for(index))
		umbrellas += 1
	# Sponsor boards on the apron, facing the track.
	for index in range(8):
		var station: float = 232.0 + float(index % 4) * 18.0 if index < 4 else 3945.0 + float(index - 4) * 34.0
		var frame := _paddock_frame(station, 44.0)
		var color: Color = Liveries.color_for(index + 1)
		_box(st, frame, Vector3(0.0, 1.0, 0.0), Vector3(0.10, 2.0, 0.10), Color("#5d6570"))
		_box(st, frame, Vector3(0.0, 2.4, 0.0), Vector3(0.16, 1.2, 4.2), color)
		_box(st, frame, Vector3(-0.10, 2.4, 0.0), Vector3(0.04, 0.35, 3.4), Color("#f4f5f7"))
		boards += 1
	return {"cars": cars, "palms": palms, "umbrellas": umbrellas, "boards": boards}


func _car(st: SurfaceTool, frame: Transform3D, color: Color) -> void:
	_box(st, frame, Vector3(0.0, 0.55, 0.0), Vector3(1.8, 0.7, 4.2), color)
	_box(st, frame, Vector3(0.0, 1.18, 0.2), Vector3(1.6, 0.6, 2.2), Color("#26333f"))
	_box(st, frame, Vector3(0.0, 1.19, 0.2), Vector3(1.62, 0.12, 2.24), color.lightened(0.15))


func _pine(st: SurfaceTool, frame: Transform3D, height: float) -> void:
	_box(st, frame, Vector3(0.0, height * 0.5, 0.0), Vector3(0.34, height, 0.34), Color("#6b4a33"))
	var top := frame * Vector3(0.0, height, 0.0)
	for tier in range(3):
		var base := top - Vector3.UP * (2.8 - float(tier) * 0.85)
		var radius := 2.4 - float(tier) * 0.62
		var apex := base + Vector3.UP * 2.1
		for index in range(6):
			var a0 := TAU * float(index) / 6.0
			var a1 := TAU * float(index + 1) / 6.0
			var p0 := base + Vector3(cos(a0) * radius, 0.0, sin(a0) * radius)
			var p1 := base + Vector3(cos(a1) * radius, 0.0, sin(a1) * radius)
			var color := Color("#2b4325") if tier < 2 else Color("#3b5a2f")
			_quad_color(st, p0, p1, apex, apex, Vector3.UP, color)


func _umbrella(st: SurfaceTool, frame: Transform3D, color: Color) -> void:
	_box(st, frame, Vector3(0.0, 1.2, 0.0), Vector3(0.08, 2.4, 0.08), Color("#6d7480"))
	_disc(st, frame * Vector3(0.0, 2.6, 0.0), 1.7, 10, color)
	var top := frame * Vector3(0.0, 0.0, 0.0)
	_box(st, frame, Vector3(0.0, 0.38, 0.0), Vector3(0.12, 0.76, 0.12), Color("#6d7480"))
	_disc(st, top + Vector3.UP * 0.8, 0.7, 8, Color("#e8e2d4"))


func _paddock_frame(station: float, lateral: float) -> Transform3D:
	var frame: Transform3D = ribbon.call("get_point_at_offset", fposmod(station, Layout.LENGTH_M), lateral)
	frame.origin.y = terrain.height_at(frame.origin.x, frame.origin.z) + 0.01
	return frame


# --- urban plazas ----------------------------------------------------------------------

## Paved spectator plazas under the kit stands / floodlights. The slab follows the
## terrain height so nothing floats: it is grounded by construction.
func _build_urban_plazas() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var quads := 0
	for band: Dictionary in _segments:
		if String(band.get("zone", "")) != "urban":
			continue
		var side: float = -1.0 if String(band.get("side", "R")) == "L" else 1.0
		var s0: float = float(band["s0"])
		var s1: float = float(band["s1"])
		var inner_lat: float = float(band.get("band_offset_m", 20.0))
		var outer_lat := inner_lat + 42.0
		var color := Color("#666a70").lerp(Color("#7c7f84"), 0.55 + s0 / Layout.LENGTH_M * 0.1)
		var previous := PackedVector3Array()
		var s := s0
		while s <= s1:
			var inner: Vector3 = _lateral_point(s, side, inner_lat)
			var outer: Vector3 = _lateral_point(s, side, outer_lat)
			inner.y = terrain.height_at(inner.x, inner.z) + 0.045
			outer.y = terrain.height_at(outer.x, outer.z) + 0.045
			if previous.size() == 2:
				_quad_color(st, previous[0], previous[1], outer, inner, Vector3.UP, color)
				quads += 1
			previous = PackedVector3Array([inner, outer])
			s += 8.0
	if quads == 0:
		return
	var mesh := st.commit()
	if mesh == null:
		return
	var node := MeshInstance3D.new()
	node.name = "UrbanPlazas"
	node.mesh = mesh
	node.material_override = Toon.vertex_colored(false)
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(node)
	_stats["plaza_quads"] = quads


# --- woodland --------------------------------------------------------------------------

func _build_woodland() -> void:
	var pine := _pine_mesh(0.0)
	var spruce := _spruce_mesh(1.7)
	var transforms := _forest_candidates()
	var pines: Array[Transform3D] = []
	var spruces: Array[Transform3D] = []
	for index in range(transforms.size()):
		if index % 5 < 3:
			pines.append(transforms[index])
		else:
			spruces.append(transforms[index])
	var foliage := _foliage_holder()
	_add_multimesh(foliage, "EifelScotsPine", pine, pines, 15.0, 0.16)
	_add_multimesh(foliage, "EifelNorwaySpruce", spruce, spruces, 11.0, 0.20)
	_stats["tree_count"] = transforms.size()
	_stats["pine_count"] = pines.size()
	_stats["spruce_count"] = spruces.size()
	_stats["tree_triangles"] = pines.size() * _surface_triangles(pine) + spruces.size() * _surface_triangles(spruce)


func _forest_candidates() -> Array[Transform3D]:
	var out: Array[Transform3D] = []
	for band: Dictionary in _segments:
		var zone := String(band.get("zone", ""))
		if zone != "forest" and zone != "cliff" and zone != "grass" and zone != "paddock":
			continue
		var side: float = -1.0 if String(band.get("side", "R")) == "L" else 1.0
		var s0: float = float(band["s0"])
		var s1: float = float(band["s1"])
		var offset: float = float(band.get("band_offset_m", 18.0))
		var depth: float = minf(float(band.get("band_depth_m", 220.0)), MAX_BAND_DEPTH_M)
		var density: float = float(band.get("density", 0.7)) * (0.45 if zone == "grass" else (0.7 if zone == "paddock" else 1.0))
		var s := s0
		while s < s1:
			var lateral := offset + (70.0 if zone == "paddock" else 10.0)
			while lateral < offset + depth:
				if out.size() >= TREE_TARGET:
					return out
				if _rng.randf() < density * 0.9:
					var station := fposmod(s + _rng.randf_range(-6.8, 6.8), Layout.LENGTH_M)
					var lat := lateral + _rng.randf_range(-6.8, 6.8)
					var frame: Transform3D = ribbon.call("get_point_at_offset", station, side * lat)
					_try_tree(out, frame.origin)
				lateral += TREE_SPACING_M
			s += TREE_SPACING_M
	# Copses filling the middle-distance fields so the horizon is not bare.
	var attempts := 0
	while out.size() < TREE_TARGET and attempts < 7000:
		attempts += 1
		var x := _rng.randf_range(terrain.bbox.position.x + 40.0, terrain.bbox.position.x + terrain.bbox.size.x - 40.0)
		var z := _rng.randf_range(terrain.bbox.position.y + 40.0, terrain.bbox.position.y + terrain.bbox.size.y - 40.0)
		var q: Dictionary = terrain.track_query(x, z, 90.0)
		if not q.is_empty() and float(q["d"]) < 90.0:
			continue
		if _noise_patch(x, z) < 0.26:
			continue
		_try_tree(out, Vector3(x, 0.0, z))
	return out


func _try_tree(out: Array[Transform3D], position: Vector3) -> void:
	var q: Dictionary = terrain.track_query(position.x, position.z, 80.0)
	if not q.is_empty() and float(q["d"]) < 27.0:
		return
	if terrain.is_flat(position.x, position.z):
		return
	if _is_excluded(Vector2(position.x, position.z), 5.0):
		return
	if _slope_at(position.x, position.z) > 0.72:
		return
	var height: float = terrain.height_at(position.x, position.z)
	var scale := _rng.randf_range(0.95, 1.45)
	var basis := Basis(Vector3.UP, _rng.randf() * TAU)
	basis = basis.scaled(Vector3(scale, scale * _rng.randf_range(0.9, 1.25), scale))
	out.append(Transform3D(basis, Vector3(position.x, height - 0.06, position.z)))


func _noise_patch(x: float, z: float) -> float:
	var n := sin(x * 0.006 + 1.7) * cos(z * 0.005 - 0.4) + sin((x + z) * 0.0032) * 0.6
	return clampf(n * 0.5 + 0.5, 0.0, 1.0)


## Pinus sylvestris (Eifel Scots pine): tall bare reddish trunk with a narrow,
## irregular crown of three cel tiers. Review LOD ~50 tris/tree.
func _pine_mesh(phase: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	_cylinder(st, Vector3.ZERO, 0.28, 9.4, 5, Color("#6b4a33"))
	var spokes := 6
	var tiers := 3
	var colors: Array[Color] = [Color("#2b4428"), Color("#33502c"), Color("#3d5c32")]
	for tier in range(tiers):
		var base_y: float = 7.2 + float(tier) * 2.3
		var radius: float = 2.6 - float(tier) * 0.68
		var apex_y: float = base_y + 3.4
		var ring: Array[Vector3] = []
		for index in range(spokes):
			var angle := TAU * float(index) / float(spokes)
			var r: float = radius + sin(angle * 2.0 + phase + float(tier) * 1.7) * 0.4
			ring.append(Vector3(cos(angle) * r, base_y + sin(angle * 3.0 + phase) * 0.22, sin(angle) * r))
		var apex := Vector3(0.12 * float(tier), apex_y, -0.08)
		var color: Color = colors[tier]
		for index in range(spokes):
			var next := (index + 1) % spokes
			for vertex: Vector3 in [ring[index], ring[next], apex]:
				st.set_color((color).srgb_to_linear())
				st.add_vertex(vertex)
		var heart := Vector3(0.0, base_y - 0.3, 0.0)
		for index in range(spokes):
			var next_face := (index + 1) % spokes
			for vertex: Vector3 in [ring[next_face], ring[index], heart]:
				st.set_color((color.darkened(0.24)).srgb_to_linear())
				st.add_vertex(vertex)
	st.generate_normals()
	return st.commit()


## Picea abies (Norway spruce): a narrow conical evergreen of four stepped cel
## tiers on a short trunk, the dense dark wall of the Eifel forest.
func _spruce_mesh(phase: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	_cylinder(st, Vector3.ZERO, 0.24, 2.2, 5, Color("#4a3527"))
	var spokes := 7
	var tiers := 4
	var colors: Array[Color] = [Color("#22371f"), Color("#2b4325"), Color("#33502a"), Color("#3b5a2f")]
	for tier in range(tiers):
		var base_y: float = 1.6 + float(tier) * 2.5
		var radius: float = 3.1 - float(tier) * 0.62
		var apex_y: float = base_y + 3.3
		var ring: Array[Vector3] = []
		for index in range(spokes):
			var angle := TAU * float(index) / float(spokes)
			var r: float = radius + sin(angle * 3.0 + phase + float(tier)) * 0.28
			ring.append(Vector3(cos(angle) * r, base_y + sin(angle * 2.0 + phase) * 0.18, sin(angle) * r))
		var apex := Vector3(0.0, apex_y, 0.0)
		var color: Color = colors[tier]
		for index in range(spokes):
			var next := (index + 1) % spokes
			for vertex: Vector3 in [ring[index], ring[next], apex]:
				st.set_color((color).srgb_to_linear())
				st.add_vertex(vertex)
		var heart := Vector3(0.0, base_y - 0.35, 0.0)
		for index in range(spokes):
			var next_face := (index + 1) % spokes
			for vertex: Vector3 in [ring[next_face], ring[index], heart]:
				st.set_color((color.darkened(0.28)).srgb_to_linear())
				st.add_vertex(vertex)
	st.generate_normals()
	return st.commit()


func _cylinder(st: SurfaceTool, base: Vector3, radius: float, height: float, segments: int, color: Color) -> void:
	for index in range(segments):
		var a0 := TAU * float(index) / float(segments)
		var a1 := TAU * float(index + 1) / float(segments)
		var p0 := base + Vector3(cos(a0) * radius, 0.0, sin(a0) * radius)
		var p1 := base + Vector3(cos(a1) * radius, 0.0, sin(a1) * radius)
		var q0 := p0 + Vector3(0.0, height, 0.0)
		var q1 := p1 + Vector3(0.0, height, 0.0)
		for vertex: Vector3 in [p0, q0, q1, p0, q1, p1]:
			st.set_color((color).srgb_to_linear())
			st.add_vertex(vertex)


# --- meadow ----------------------------------------------------------------------------

func _build_meadow() -> void:
	var mesh := _grass_tuft_mesh()
	if mesh == null:
		return
	var out: Array[Transform3D] = []
	for band: Dictionary in _segments:
		if String(band.get("zone", "")) != "grass":
			continue
		var side: float = -1.0 if String(band.get("side", "R")) == "L" else 1.0
		var s0: float = float(band["s0"])
		var s1: float = float(band["s1"])
		var offset: float = float(band.get("band_offset_m", 16.0))
		var depth: float = minf(float(band.get("band_depth_m", 250.0)), 140.0)
		var tries := int((s1 - s0) / 4.5)
		for index in range(tries):
			if out.size() >= GRASS_TARGET:
				break
			var station := _rng.randf_range(s0, s1)
			var lateral := offset + _rng.randf() * depth * 0.65
			var frame: Transform3D = ribbon.call("get_point_at_offset", fposmod(station, Layout.LENGTH_M), side * lateral)
			var q: Dictionary = terrain.track_query(frame.origin.x, frame.origin.z, 40.0)
			if not q.is_empty() and float(q["d"]) < 9.6:
				continue
			if terrain.is_flat(frame.origin.x, frame.origin.z):
				continue
			if _is_excluded(Vector2(frame.origin.x, frame.origin.z), 3.0):
				continue
			var height: float = terrain.height_at(frame.origin.x, frame.origin.z)
			var scale := _rng.randf_range(0.7, 1.5)
			var basis := Basis(Vector3.UP, _rng.randf() * TAU)
			basis = basis.scaled(Vector3(scale, scale * _rng.randf_range(0.8, 1.4), scale))
			out.append(Transform3D(basis, Vector3(frame.origin.x, height, frame.origin.z)))
	var foliage := _foliage_holder()
	_add_multimesh(foliage, "WetMeadowTufts", mesh, out, 1.1, 0.14)
	_stats["grass_count"] = out.size()
	_stats["grass_triangles"] = out.size() * _surface_triangles(mesh)


func _grass_tuft_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for blade in range(3):
		var angle := float(blade) * PI / 3.0
		var across := Vector3(cos(angle), 0.0, sin(angle)) * 0.22
		var p0 := -across
		var p1 := across
		var p2 := across + Vector3(0.0, 0.95, 0.0)
		var p3 := -across + Vector3(0.0, 0.95, 0.0)
		for vertex: Vector3 in [p0, p1, p2, p0, p2, p3]:
			st.set_color((Color("#3f5c33") if vertex.y < 0.2 else Color("#6f8f4a")).srgb_to_linear())
			st.add_vertex(vertex)
	st.generate_normals()
	return st.commit()


# --- undergrowth & basalt boulders -----------------------------------------------------

## Damp Eifel undergrowth: fern and bramble clumps on the grass/forest verges, plus
## low-poly basalt boulders on the volcanic rock bands. Three stacked cel rings
## (~36 tris) at 0.6-1.4 m read as a soft forest floor under the conifer wall.
func _build_chaparral() -> void:
	var mesh := _shrub_mesh()
	var out: Array[Transform3D] = []
	for band: Dictionary in _segments:
		var zone := String(band.get("zone", ""))
		if zone != "sand" and zone != "rock" and zone != "grass":
			continue
		var side: float = -1.0 if String(band.get("side", "R")) == "L" else 1.0
		var s0: float = float(band["s0"])
		var s1: float = float(band["s1"])
		var offset: float = float(band.get("band_offset_m", 16.0))
		var depth: float = minf(float(band.get("band_depth_m", 250.0)), 140.0)
		var density: float = float(band.get("density", 0.7))
		var s := s0 + 3.0
		while s < s1 and out.size() < SHRUB_LIMIT:
			for sample in 2:
				var lateral := offset + 4.0 + _rng.randf() * depth * 0.78
				var frame: Transform3D = ribbon.call("get_point_at_offset", fposmod(s, Layout.LENGTH_M), side * lateral)
				_chaparral_piece(out, frame, density)
			s += _rng.randf_range(4.5, 7.5)
	if out.is_empty():
		return
	_add_multimesh(_foliage_holder(), "EifelUndergrowth", mesh, out, 1.05, 0.08)
	_stats["shrub_count"] = out.size()
	_stats["shrub_triangles"] = out.size() * _surface_triangles(mesh)


func _chaparral_piece(out: Array[Transform3D], frame: Transform3D, density: float) -> void:
	if _rng.randf() > density * 0.8:
		return
	var position := frame.origin
	if terrain.is_flat(position.x, position.z):
		return
	if _is_excluded(Vector2(position.x, position.z), 3.0):
		return
	var q: Dictionary = terrain.track_query(position.x, position.z, 40.0)
	if not q.is_empty() and float(q["d"]) < 10.5:
		return
	if _slope_at(position.x, position.z) > 0.65:
		return
	var height: float = terrain.height_at(position.x, position.z)
	var scale := _rng.randf_range(0.8, 1.8)
	var basis := Basis(Vector3.UP, _rng.randf() * TAU).scaled(Vector3(scale, scale * _rng.randf_range(0.8, 1.3), scale))
	out.append(Transform3D(basis, Vector3(position.x, height - 0.06, position.z)))


func _shrub_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var spokes := 6
	var rings: Array = []
	var heights: Array[float] = [0.05, 0.55, 0.95]
	var radii: Array[float] = [0.62, 0.9, 0.5]
	var colors: Array[Color] = [Color("#2e4428"), Color("#3a5330"), Color("#4a6538")]
	for ring in 3:
		var points: Array[Vector3] = []
		for index in range(spokes):
			var angle := TAU * float(index) / float(spokes)
			points.append(Vector3(cos(angle) * radii[ring], heights[ring], sin(angle) * radii[ring]))
		rings.append(points)
	for ring in 2:
		var lower: Array[Vector3] = rings[ring]
		var upper: Array[Vector3] = rings[ring + 1]
		for index in range(spokes):
			var next := (index + 1) % spokes
			var color: Color = colors[ring].lerp(colors[ring + 1], 0.5)
			for vertex: Vector3 in [lower[index], lower[next], upper[next], lower[index], upper[next], upper[index]]:
				st.set_color((color).srgb_to_linear())
				st.add_vertex(vertex)
	var top: Array[Vector3] = rings[2]
	var apex := Vector3(0.06, 1.25, -0.05)
	for index in range(spokes):
		var next := (index + 1) % spokes
		for vertex: Vector3 in [top[index], top[next], apex]:
			st.set_color((colors[2]).srgb_to_linear())
			st.add_vertex(vertex)
	st.generate_normals()
	return st.commit()


# --- volcanic boulders & valley mist ----------------------------------------------------

## Basalt outcrops along the volcanic rock bands and the castle crag: 320 low-poly
## boulders (~14 tris) break the grass/rock transition without touching the corridor.
func _build_boulders() -> void:
	var mesh := _boulder_mesh()
	var out: Array[Transform3D] = []
	var attempts := 0
	while out.size() < 320 and attempts < 4000:
		attempts += 1
		var band: Dictionary = _segments[_rng.randi_range(0, _segments.size() - 1)]
		var zone := String(band.get("zone", ""))
		if zone != "cliff" and zone != "grass" and _rng.randf() > 0.35:
			continue
		var side: float = -1.0 if String(band.get("side", "R")) == "L" else 1.0
		var s0: float = float(band["s0"])
		var s1: float = float(band["s1"])
		var station := _rng.randf_range(s0, s1)
		var lateral: float = float(band.get("band_offset_m", 24.0)) + _rng.randf_range(2.0, 46.0)
		var frame: Transform3D = ribbon.call("get_point_at_offset", fposmod(station, Layout.LENGTH_M), side * lateral)
		var position := frame.origin
		if terrain.is_flat(position.x, position.z):
			continue
		if _is_excluded(Vector2(position.x, position.z), 4.0):
			continue
		var q: Dictionary = terrain.track_query(position.x, position.z, 40.0)
		if not q.is_empty() and float(q["d"]) < 12.0:
			continue
		var height: float = terrain.height_at(position.x, position.z)
		var scale := _rng.randf_range(0.7, 2.4)
		var basis := Basis(Vector3.UP, _rng.randf() * TAU).scaled(Vector3(scale * _rng.randf_range(0.8, 1.4), scale * _rng.randf_range(0.6, 1.1), scale * _rng.randf_range(0.8, 1.4)))
		out.append(Transform3D(basis, Vector3(position.x, height - 0.12, position.z)))
	if out.is_empty():
		return
	_add_multimesh(_foliage_holder(), "VolcanicBoulders", mesh, out, 0.0, 0.0)
	_stats["boulder_count"] = out.size()
	_stats["boulder_triangles"] = out.size() * _surface_triangles(mesh)


func _boulder_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var ring: Array[Vector3] = []
	for index in range(6):
		var angle := TAU * float(index) / 6.0
		ring.append(Vector3(cos(angle) * 0.85, 0.15 + sin(angle * 3.0) * 0.1, sin(angle) * 0.62))
	var top := Vector3(0.08, 1.0, -0.05)
	var bottom := Vector3(-0.05, -0.1, 0.04)
	for index in range(6):
		var next := (index + 1) % 6
		for vertex: Vector3 in [ring[index], ring[next], top]:
			st.set_color((Color("#5a5f5c") if index % 2 == 0 else Color("#4c514e")).srgb_to_linear())
			st.add_vertex(vertex)
		for vertex: Vector3 in [ring[next], ring[index], bottom]:
			st.set_color((Color("#3d423f")).srgb_to_linear())
			st.add_vertex(vertex)
	st.generate_normals()
	return st.commit()


## Valley fog: a bounded FogVolume pooling in the measured 0.0 m basin (s = 1850),
## driven by the same overcast/rain mood as the cel sky. Volumetric fog is enabled
## by ToonLook; density is low enough to keep the horizon readable.
func _build_valley_mist() -> void:
	var grid: Dictionary = terrain.heightgrid
	var centre: Vector2 = grid.get("valley_centre", Vector2.ZERO)
	var floor_y: float = terrain.height_at(centre.x, centre.y)
	var fog := FogVolume.new()
	fog.name = "ValleyMist"
	fog.size = Vector3(320.0, 26.0, 320.0)
	fog.position = Vector3(centre.x, floor_y + 10.0, centre.y)
	var material := FogMaterial.new()
	material.density = 0.022
	material.albedo = Color("#c8d2d4")
	material.height_falloff = 0.35
	material.edge_fade = 0.6
	fog.material = material
	add_child(fog)
	_stats["valley_mist"] = {"centre": [snappedf(centre.x, 0.1), snappedf(centre.y, 0.1)], "floor_y": snappedf(floor_y, 0.01), "size": [320.0, 26.0, 320.0]}


# --- completion ------------------------------------------------------------------------

func _finish(started: int) -> void:
	var elapsed := Time.get_ticks_msec() - started
	_stats["build_ms"] = elapsed
	_stats["terrain_triangles"] = terrain.triangles()
	var range_m: Vector2 = terrain.elevation_range()
	_stats["terrain_min_y"] = snappedf(range_m.x, 0.01)
	_stats["terrain_max_y"] = snappedf(range_m.y, 0.01)
	_stats["roadbed_drop_m"] = Layout.ROADBED_DROP_M
	_stats["landmarks"] = _landmark_records
	var placed := 0
	var landmark_triangles := 0
	for record: Dictionary in _landmark_records:
		if bool(record.get("placed", false)):
			placed += 1
			landmark_triangles += int(record.get("triangles", 0))
	_stats["landmarks_placed"] = placed
	_stats["landmark_triangles"] = landmark_triangles
	_stats["environment_triangles"] = _count_triangles(self)
	_stats["triangle_budget"] = ENVIRONMENT_TRIANGLE_BUDGET
	_toon()
	_set_shadow_policy()
	set_meta("env_stats", _stats)
	set_meta("heightgrid", terrain.heightgrid)
	set_meta("built", true)
	built = true
	apply_time_of_day(_tod, _gloom)
	print("[eifel-env] built in %.2fs | terrain tris %d | trees %d | grass %d | shrubs %d | boulders %d | landmarks %d/%d | env tris %d (budget %d)" % [
		float(elapsed) / 1000.0,
		int(_stats["terrain_triangles"]),
		int(_stats.get("tree_count", 0)),
		int(_stats.get("grass_count", 0)),
		int(_stats.get("shrub_count", 0)),
		int(_stats.get("boulder_count", 0)),
		placed,
		_landmark_records.size(),
		int(_stats["environment_triangles"]),
		ENVIRONMENT_TRIANGLE_BUDGET,
	])


func _toon() -> void:
	ToonLookScript.apply_visuals(get_parent())


## Draw-call gate: only the hero landmarks and the three FIA structures cast a
## shadow; the terrain, furniture, fences, paddock props, pit lane paint, signs,
## crews, transporters and garage detail would each add a shadow pass for no
## silhouette the cel look needs. The road (TrackRibbon) keeps its own shadow.
func _set_shadow_policy() -> void:
	var root := get_parent()
	if root == null:
		return
	for node: Node in root.find_children("*", "GeometryInstance3D", true, false):
		var geometry := node as GeometryInstance3D
		var path: String = String(root.get_path_to(geometry))
		if path.begins_with("TrackRibbon/"):
			continue
		var keep: bool = path.begins_with("Environment/HeroLandmarks/") 			or path == "PitLane/PitBuilding/Structure" 			or path == "PitLane/MainGrandstand/Structure" 			or path == "PitLane/RaceControlTower/Structure"
		geometry.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if keep else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


# --- helpers ---------------------------------------------------------------------------

func _road_y(s: float) -> float:
	var points: PackedVector3Array = _compiled["points"]
	var index := posmod(roundi(fposmod(s, Layout.LENGTH_M) / float(_compiled["step_m"])), points.size())
	return points[index].y


func _lateral_point(s: float, side: float, lateral: float) -> Vector3:
	var frame: Transform3D = ribbon.call("get_point_at_offset", fposmod(s, Layout.LENGTH_M), side * lateral)
	return frame.origin


func _foliage_holder() -> Node3D:
	var holder := get_node_or_null("Foliage") as Node3D
	if holder == null:
		holder = Node3D.new()
		holder.name = "Foliage"
		add_child(holder)
	return holder


func _add_multimesh(parent: Node3D, node_name: String, mesh: Mesh, transforms: Array[Transform3D], sway_height: float, wind_strength: float) -> void:
	if transforms.is_empty():
		return
	var material := ShaderMaterial.new()
	material.shader = TreeWindShader
	material.set_shader_parameter("sway_height_m", sway_height)
	material.set_shader_parameter("wind_strength", wind_strength)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = transforms.size()
	for index in range(transforms.size()):
		mm.set_instance_transform(index, transforms[index])
	var instance := MultiMeshInstance3D.new()
	instance.name = node_name
	instance.multimesh = mm
	instance.material_override = material
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(instance)


func _is_excluded(point: Vector2, margin: float) -> bool:
	for entry: Array in _exclusion:
		var centre: Vector2 = entry[0]
		if point.distance_to(centre) < float(entry[1]) + margin:
			return true
	return false


func _slope_at(x: float, z: float) -> float:
	var hx: float = terrain.height_at(x + 4.0, z) - terrain.height_at(x - 4.0, z)
	var hz: float = terrain.height_at(x, z + 4.0) - terrain.height_at(x, z - 4.0)
	return sqrt(hx * hx + hz * hz) / 8.0


func _quad_color(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, hint: Vector3, color: Color) -> void:
	var normal := (b - a).cross(c - a)
	var order: Array = [a, b, c, a, c, d] if normal.dot(hint) < 0.0 else [a, c, b, a, d, c]
	for vertex: Vector3 in order:
		st.set_color((color).srgb_to_linear())
		st.add_vertex(vertex)


## Double-sided box so no face can be missed at an oblique review angle.
func _box(st: SurfaceTool, frame: Transform3D, centre: Vector3, size: Vector3, color: Color) -> void:
	var corners: Array[Vector3] = []
	for x: float in [-1.0, 1.0]:
		for y: float in [-1.0, 1.0]:
			for z: float in [-1.0, 1.0]:
				corners.append(frame * (centre + Vector3(x * size.x * 0.5, y * size.y * 0.5, z * size.z * 0.5)))
	var faces: Array = [
		[0, 1, 3, 2, Vector3.LEFT], [4, 6, 7, 5, Vector3.RIGHT],
		[0, 4, 5, 1, Vector3.DOWN], [2, 3, 7, 6, Vector3.UP],
		[0, 2, 6, 4, Vector3.FORWARD], [1, 5, 7, 3, Vector3.BACK],
	]
	for face: Array in faces:
		var a := corners[face[0]]
		var b := corners[face[1]]
		var c := corners[face[2]]
		var d := corners[face[3]]
		var hint: Vector3 = (frame.basis * (face[4] as Vector3)).normalized()
		var order: Array = [a, b, c, a, c, d]
		if (c - a).cross(b - a).dot(hint) < 0.0:
			order = [a, c, b, a, d, c]
		for vertex: Vector3 in order:
			st.set_color((color).srgb_to_linear())
			st.set_normal(hint)
			st.add_vertex(vertex)


func _disc(st: SurfaceTool, centre: Vector3, radius: float, segments: int, color: Color) -> void:
	for index in range(segments):
		var a0 := TAU * float(index) / float(segments)
		var a1 := TAU * float(index + 1) / float(segments)
		var p0 := centre + Vector3(cos(a0) * radius, 0.0, sin(a0) * radius)
		var p1 := centre + Vector3(cos(a1) * radius, 0.0, sin(a1) * radius)
		for vertex: Vector3 in [centre, p0, p1, centre, p1, p0]:
			st.set_color((color).srgb_to_linear())
			st.add_vertex(vertex)


func _surface_triangles(mesh: Mesh) -> int:
	if mesh == null:
		return 0
	var total := 0
	for surface in mesh.get_surface_count():
		var arrays := mesh.surface_get_arrays(surface)
		var indices: Variant = arrays[Mesh.ARRAY_INDEX]
		total += (indices.size() if indices != null else (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()) / 3
	return total


func _mesh_triangles(root: Node) -> int:
	var total := 0
	if root is MeshInstance3D and (root as MeshInstance3D).mesh != null:
		total += _surface_triangles((root as MeshInstance3D).mesh)
	for child: Node in root.get_children():
		total += _mesh_triangles(child)
	return total


func _count_triangles(root: Node) -> int:
	var total := 0
	for child: Node in root.get_children():
		if child is MeshInstance3D and (child as MeshInstance3D).mesh != null:
			total += _surface_triangles((child as MeshInstance3D).mesh)
		elif child is MultiMeshInstance3D and (child as MultiMeshInstance3D).multimesh != null:
			var mm := (child as MultiMeshInstance3D).multimesh
			total += _surface_triangles(mm.mesh) * mm.instance_count
		total += _count_triangles(child)
	return total
