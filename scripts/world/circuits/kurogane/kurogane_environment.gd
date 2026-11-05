class_name KuroganeEnvironment
extends "res://scripts/world/circuits/base/circuit_environment.gd"

## Kurogane Twin-Cross GP environment: production Tier A corridor (asphalt, kerbs,
## Armco, Tecpro, braking boards, flag panels, catch fence, rubber groove) with the
## pit-side rail opened on the right, the approved Mie-highland heightfield with the
## Degner trench under the Back Straight overflight, the autumn Momiji + pine MultiMesh
## biome, the four hero landmark GLBs (crossover truss bridge fitted to the measured
## gap, Taiyou ferris wheel, Grand Reverse Tower, Spoon Ridge shrine) and the paddock
## ground. DAY / SUNSET / NIGHT. Ported from the approved Route 2 build; the runtime
## never reads the mapgen repo.

const Layout := preload("res://scripts/world/circuits/kurogane/kurogane_layout.gd")
const TerrainField := preload("res://scripts/world/circuits/kurogane/kurogane_terrain.gd")
const Strip := preload("res://scripts/world/circuits/kurogane/kurogane_strip.gd")
const Toon := preload("res://scripts/world/shared/toon_materials.gd")
const TreeWindShader := preload("res://shaders/kurogane_tree_wind.gdshader")
const ToonLookScript := preload("res://scripts/world/circuits/kurogane/kurogane_toon.gd")
const MeshBatchScript := preload("res://scripts/world/shared/mesh_batch.gd")
const Line := preload("res://scripts/car/adaptive_racing_line.gd")
const Surface := preload("res://scripts/world/shared/enhanced_track_geometry.gd")
const PitZone := preload("res://scripts/world/shared/pit_zone.gd")
const SkyController := preload("res://scripts/world/shared/shared_cel_sky_controller.gd")
const Fence := preload("res://scripts/world/circuits/kurogane/kurogane_catch_fence.gd")

const ASSET_DIR := "res://assets/tracks/kurogane/models"
const ENVIRONMENT_TRIANGLE_BUDGET := 320000
const MOMIJI_TARGET := 1500
const PINE_TARGET := 950
const ROCK_TARGET := 120
## A floodlight mast stands on the ground within this tolerance (m); beyond it the mast is dropped.
const MAST_SNAP_M := 6.0
## Trackside pieces: hanging more than HANGING_M over the ground or buried more than BURIED_M are unsupported.
const HANGING_M := 1.0
const BURIED_M := 1.5
const PIER_MARGIN_M := 1.0
## Terrain stays this far under kerbs, run-off and gravel.
const SURFACE_FLOOR_M := 0.06

## Autumn Mie highlands (approved): clear cool sky, golden-hour warm sunset, moonlit night.
const PROFILES: Array[Dictionary] = [
	{"sun": Color("#fff3da"), "sun_energy": 1.05, "sun_pitch": 48.0, "sun_yaw": -32.0, "ambient": Color("#c3d8e0"), "ambient_energy": 0.30, "fog": Color("#cfe4ec"), "fog_density": 0.00016, "sky_top": Color("#5aa1d8"), "sky_horizon": Color("#cfe7ef"), "ground": Color("#31443f")},
	{"sun": Color("#ffae72"), "sun_energy": 0.78, "sun_pitch": 15.0, "sun_yaw": -65.0, "ambient": Color("#d8ab8f"), "ambient_energy": 0.27, "fog": Color("#e8bd97"), "fog_density": 0.00024, "sky_top": Color("#6f6694"), "sky_horizon": Color("#f3bd93"), "ground": Color("#5d4a33")},
	{"sun": Color("#a8c2ea"), "sun_energy": 0.38, "sun_pitch": 40.0, "sun_yaw": 90.0, "ambient": Color("#8fa7cf"), "ambient_energy": 0.24, "fog": Color("#1d2c48"), "fog_density": 0.00038, "sky_top": Color("#0e1b39"), "sky_horizon": Color("#365371"), "ground": Color("#05080f")},
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
var _bridge_model: Node3D
var _tree_sites := PackedVector3Array()


func _init() -> void:
	circuit_id = Layout.CIRCUIT_ID
	_sky_rig.aces_tonemap = false
	_sky_rig.fog_sky_affect = 0.35


func build(p_ribbon: TrackRibbonScript, source: Variant = null) -> void:
	if built:
		return
	ribbon = p_ribbon
	_rng.seed = 20261104
	_compiled = _compiled_from(source)
	if _compiled.is_empty():
		push_warning("kurogane-env: no compiled track data")
		built = true
		return
	var started := Time.get_ticks_msec()
	line = Line.new(ribbon)
	terrain = TerrainField.new(_compiled)
	_build_corridor()
	_slim_armco()
	_lower_terrain_under_surfaces()
	_add_terrain()
	_build_exclusions()
	_build_landmarks()
	_build_catch_fence()
	_prune_unsupported_trackside()
	_build_paddock_ground()
	_build_forest()
	_build_verge_tufts()
	_build_rocks()
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
	return {"points": points, "step_m": Layout.LENGTH_M / float(maxi(1, points.size())), "length_m": Layout.LENGTH_M}


## Tier A: shared corridor kit (asphalt, kerbs, runoff, groove, Armco, Tecpro,
## braking boards, flag panels); the FIA paddock pieces are built by the circuit's
## PitComplex and the catch fence reads the same furniture extents.
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
	_add_kerb_group("SawtoothKerbsKurogane", kerbs, ribbon.road_half_width_m - Surface.KERB_INSET_M, Surface.KERB_RED)
	var zone := PitZone.from_layout(_pit_layout(), ribbon.length_m, 70.0, 70.0)
	runoff_plans = Surface.plan_runoffs(ribbon, kerbs, float(zone.start_s), float(zone.length_m), PitZone.side_of(zone))
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
	shared_sky = SkyController.new()
	shared_sky.build(self, ribbon, 20261104)
	var pit := get_parent().get_node_or_null("PitLane")
	if pit != null:
		var stand := pit.get_node_or_null("MainGrandstand")
		if stand != null:
			var screen := stand.find_child("Jumbotron", true, false)
			if screen != null:
				_screens.append(screen)
	_collect_glow_materials(self)
	if pit != null:
		_collect_glow_materials(pit)


## The kit's triple-rib rail profile is ~36 triangles per 4 m post (98 k for this lap). The approved
## Route 2 build keeps the authored posts and the continuous rail but draws each section as a slim
## double-faced band plus post (16 triangles), which is what fits the 320 k environment budget.
func _slim_armco() -> void:
	var instance := furniture.get("armco_instance") as MultiMeshInstance3D
	if instance == null or instance.multimesh == null:
		return
	var source := instance.multimesh.mesh
	var source_material: Material = null
	if source != null and source.get_surface_count() > 0:
		source_material = source.surface_get_material(0)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rail_color := Color("#9aa1ae")
	var post_color := Color("#4a505c")
	var corners: Array[Vector3] = []
	for sx: float in [-0.05, 0.01]:
		for sy: float in [0.25, 0.9]:
			for sz: float in [-2.03, 2.03]:
				corners.append(Vector3(sx, sy, sz))
	var faces: Array = [[0, 1, 3, 2], [4, 6, 7, 5], [0, 4, 5, 1], [2, 3, 7, 6], [0, 2, 6, 4], [1, 5, 7, 3]]
	for face: Array in faces:
		for v: Vector3 in [corners[face[0]], corners[face[1]], corners[face[2]], corners[face[0]], corners[face[2]], corners[face[3]]]:
			st.set_color(rail_color)
			st.add_vertex(v)
	var px := 0.1
	for face in 2:
		var p0 := Vector3(px, 0.0, -0.06)
		var p1 := Vector3(px, 0.95, -0.06)
		var p2 := Vector3(px, 0.95, 0.06)
		var p3 := Vector3(px, 0.0, 0.06)
		var verts: Array = [p0, p1, p2, p0, p2, p3] if face == 0 else [p0, p2, p1, p0, p3, p2]
		for v: Vector3 in verts:
			st.set_color(post_color)
			st.add_vertex(v)
	st.generate_normals()
	var mesh := st.commit()
	if mesh != null:
		if source_material != null:
			mesh.surface_set_material(0, source_material)
		instance.multimesh.mesh = mesh


func _pit_layout() -> Dictionary:
	var pit := get_parent().get_node_or_null("PitLane") if get_parent() != null else null
	if pit != null and pit.has_method("sim_layout"):
		return pit.call("sim_layout")
	return {"entry_s": Layout.PIT_ENTRY_S, "exit_s": Layout.PIT_EXIT_S, "lane_length_m": Layout.PIT_LANE_LENGTH_M, "stall_pitch_m": Layout.PIT_STALL_PITCH_M, "stall_lane_m": Layout.PIT_SIDE * Layout.PIT_SERVICE_X}


## Hero zones push the floodlight masts back where one behind the rail would stand in
## something: the right-hand pit lane and paddock, the main grandstand on the left
## (s 100, roof to 58 m).
func _hero_zones() -> Array[Dictionary]:
	var lap: float = ribbon.length_m if ribbon != null else Layout.LENGTH_M
	return [
		{"side": Layout.PIT_SIDE, "s0": Layout.PIT_ENTRY_S - 70.0, "s1": lap + Layout.PIT_EXIT_S + 70.0, "lateral": 75.0},
		{"side": -1.0, "s0": lap + Layout.GRANDSTAND_ANCHOR_S - Layout.GRANDSTAND_LENGTH_M * 0.5 - 10.0, "s1": lap + Layout.GRANDSTAND_ANCHOR_S + Layout.GRANDSTAND_LENGTH_M * 0.5 + 10.0, "lateral": 64.0},
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
	_sky_rig.apply(_world_environment, _sun, PROFILES[mode], gloom, Color("#8d8f94"))
	if shared_sky != null:
		shared_sky.apply_time_of_day(tod, gloom)
	# The approved autumn look is FILMIC with a saturated grade; match the sandbox ToonLook.
	if _world_environment != null and _world_environment.environment != null:
		var env := _world_environment.environment
		env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
		env.tonemap_exposure = 0.95
		env.adjustment_enabled = true
		env.adjustment_saturation = 1.22
		env.adjustment_contrast = 1.08
		env.adjustment_brightness = 1.02
		if env.sky != null and env.sky.sky_material is ProceduralSkyMaterial:
			(env.sky.sky_material as ProceduralSkyMaterial).sun_angle_max = 0.0
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


## Top of the solid ground under a world point: the terrain, or the paddock slab where it covers it.
## Under the Back Straight bridge the ground is the trench floor (the heightfield already carries it).
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


# --- terrain / trench ------------------------------------------------------------------

func _add_terrain() -> void:
	var node := MeshInstance3D.new()
	node.name = "Terrain"
	node.mesh = terrain.terrain_mesh
	# The cel shader renders fully shadowed surfaces black; the heightfield does not
	# cast, so the trench and the paddock stay lit instead of turning into ink.
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.set_meta("heightgrid", terrain.heightgrid)
	add_child(node)
	var skirt := MeshInstance3D.new()
	skirt.name = "TerrainSkirt"
	skirt.mesh = terrain.skirt_mesh
	skirt.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(skirt)
	if terrain.trench_walls_mesh != null:
		var walls := MeshInstance3D.new()
		walls.name = "TrenchWalls"
		walls.mesh = terrain.trench_walls_mesh
		walls.material_override = Toon.make(TerrainField.CONCRETE)
		add_child(walls)
	var base := MeshInstance3D.new()
	base.name = "TerrainBase"
	var plane := PlaneMesh.new()
	plane.size = Vector2(8000.0, 8000.0)
	base.mesh = plane
	base.position.y = float(terrain.elevation_range().x) - 30.0
	base.material_override = Toon.make(Color("#3a4d31"))
	base.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(base)
	var ridge := MeshInstance3D.new()
	ridge.name = "DistantRidge"
	ridge.mesh = terrain.ridge_mesh
	ridge.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(ridge)


## Kit surfaces laid beside the asphalt (kerbs, tarmac run-off, gravel) sit at road height; the 12 m
## heightfield must never rise to cover them, so it is lowered under every one of their vertices.
func _lower_terrain_under_surfaces() -> void:
	var surface_points := PackedVector3Array()
	for node_name: String in ["SawtoothKerbsKurogane", "TarmacRunoff", "GravelTraps"]:
		var node := get_node_or_null(node_name) as MeshInstance3D
		if node == null or node.mesh == null:
			continue
		for surface: int in range(node.mesh.get_surface_count()):
			surface_points.append_array(node.mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX])
	_stats["terrain_lowered_cells"] = terrain.lower_under(surface_points, SURFACE_FLOOR_M)


func _build_catch_fence() -> void:
	_stats["catch_fence_panels"] = Fence.build(self, ribbon, furniture, kerbs, Callable(self, "_post_supported"))


## True where a trackside piece based at `p` stands on something: the ground, or the bridge deck. A
## piece hanging over the trench, buried in the hill, or inside a bridge pier is not supported.
func _post_supported(p: Vector3) -> bool:
	var d: float = p.y - terrain.height_at(p.x, p.z)
	if d < -BURIED_M or _in_pier(p):
		return false
	return d <= HANGING_M or _on_deck(p)


## Planar search along the Back Straight only (the lower branch passes right under the deck).
func _on_deck(p: Vector3) -> bool:
	if terrain.bridge_span == Vector2.ZERO:
		return false
	var s0: float = terrain.bridge_span.x - 6.0
	var s1: float = terrain.bridge_span.y + 6.0
	var centre: Vector3 = ribbon.call("get_point_at_offset", (s0 + s1) * 0.5, 0.0).origin
	if Vector2(p.x - centre.x, p.z - centre.z).length() > (s1 - s0) * 0.5 + 24.0:
		return false
	var best := INF
	var best_s := s0
	var s := s0
	while s <= s1:
		var frame: Transform3D = ribbon.call("get_point_at_offset", s, 0.0)
		var planar := Vector2(frame.origin.x - p.x, frame.origin.z - p.z).length()
		if planar < best:
			best = planar
			best_s = s
		s += 1.0
	if best_s < terrain.bridge_span.x or best_s > terrain.bridge_span.y:
		return false
	var at: Transform3D = ribbon.call("get_point_at_offset", best_s, 0.0)
	var lateral := (p - at.origin).dot(at.basis.x)
	return absf(lateral) <= Layout.BRIDGE_DECK_HALF_M and absf(p.y - at.origin.y) < 2.5


## Inside a bridge pier (with a margin): the piers stand on the trench floor 3 m off the lower road.
func _in_pier(p: Vector3) -> bool:
	if _bridge_model == null:
		return false
	var local := _bridge_model.global_transform.affine_inverse() * p
	var z_scale := maxf(0.1, _bridge_model.scale.z)
	if absf(local.x) > Layout.BRIDGE_PIER_HALF_WIDTH_M + PIER_MARGIN_M:
		return false
	if local.y > 2.0 or local.y < -Layout.BRIDGE_PIER_DEPTH_M - 2.0:
		return false
	var z := absf(local.z)
	return z >= Layout.BRIDGE_PIER_Z.x - PIER_MARGIN_M / z_scale and z <= Layout.BRIDGE_PIER_Z.y + PIER_MARGIN_M / z_scale


## Drops what nothing carries: floodlight masts (stood on the ground when it is within MAST_SNAP_M of
## the road's elevation, else removed) and Armco posts and fence pieces over the trench, in the hill
## or in a pier. The bridge carries its own parapet along the deck.
func _prune_unsupported_trackside() -> void:
	_prune_towers()
	_prune_armco()


func _prune_towers() -> void:
	var instance := furniture.get("tower_instance") as MultiMeshInstance3D
	if instance == null or instance.multimesh == null:
		return
	var old_transforms: Array[Transform3D] = furniture.get("tower_transforms")
	var old_records: Array[Dictionary] = furniture.get("tower_records")
	var kept_transforms: Array[Transform3D] = []
	var kept_records: Array[Dictionary] = []
	for index: int in range(old_transforms.size()):
		var pose: Transform3D = old_transforms[index]
		var ground: float = terrain.height_at(pose.origin.x, pose.origin.z)
		if absf(ground - pose.origin.y) > MAST_SNAP_M or _in_pier(pose.origin):
			continue
		pose.origin.y = ground
		kept_transforms.append(pose)
		var record: Dictionary = old_records[index].duplicate()
		record["position"] = pose.origin
		record["pose"] = pose
		kept_records.append(record)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = instance.multimesh.mesh
	mm.instance_count = kept_transforms.size()
	for slot: int in range(kept_transforms.size()):
		mm.set_instance_transform(slot, kept_transforms[slot])
	instance.multimesh = mm
	furniture.set("tower_records", kept_records)
	furniture.set("tower_transforms", kept_transforms)
	furniture.set("tower_count", kept_transforms.size())
	_stats["towers_pruned"] = old_transforms.size() - kept_transforms.size()


func _prune_armco() -> void:
	var instance: MultiMeshInstance3D = furniture.armco_instance
	if instance == null or instance.multimesh == null:
		return
	var poses: Array[Transform3D] = furniture.armco_transforms
	var arcs: PackedFloat32Array = furniture.armco_arcs
	var kept: Array[Transform3D] = []
	var kept_arcs := PackedFloat32Array()
	var new_index := PackedInt32Array()
	new_index.resize(poses.size())
	for index: int in range(poses.size()):
		if _post_supported(poses[index].origin):
			new_index[index] = kept.size()
			kept.append(poses[index])
			kept_arcs.append(arcs[index])
		else:
			new_index[index] = -1
	if kept.size() == poses.size():
		return
	# Runs index the post array: split each at the gaps so `first`/`count` stay true.
	var runs: Array[Dictionary] = []
	for run: Dictionary in furniture.armco_runs:
		var first := -1
		var last := -1
		for index: int in range(int(run["first"]), int(run["first"]) + int(run["count"])):
			if new_index[index] < 0:
				continue
			if first >= 0 and new_index[index] != last + 1:
				runs.append(_run_of(run, kept_arcs, first, last))
				first = -1
			if first < 0:
				first = new_index[index]
			last = new_index[index]
		if first >= 0:
			runs.append(_run_of(run, kept_arcs, first, last))
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = instance.multimesh.mesh
	mm.instance_count = kept.size()
	for slot: int in range(kept.size()):
		mm.set_instance_transform(slot, kept[slot])
	instance.multimesh = mm
	furniture.armco_transforms = kept
	furniture.armco_arcs = kept_arcs
	furniture.armco_runs = runs
	furniture.armco_post_count = kept.size()
	_stats["armco_pruned"] = poses.size() - kept.size()


func _run_of(run: Dictionary, arcs: PackedFloat32Array, first: int, last: int) -> Dictionary:
	var result: Dictionary = run.duplicate()
	result["first"] = first
	result["count"] = last - first + 1
	result["s0"] = arcs[first]
	result["s1"] = arcs[last]
	return result


# --- landmarks -------------------------------------------------------------------------

func _build_exclusions() -> void:
	_exclusion = []
	for entry: Dictionary in [
		{"s": Layout.LANDMARK_FERRIS_S, "side": Layout.LANDMARK_FERRIS_SIDE, "lat": Layout.LANDMARK_FERRIS_LATERAL_M, "r": 52.0},
		{"s": Layout.LANDMARK_TOWER_S, "side": Layout.LANDMARK_TOWER_SIDE, "lat": Layout.LANDMARK_TOWER_LATERAL_M, "r": 30.0},
		{"s": Layout.LANDMARK_SHRINE_S, "side": Layout.LANDMARK_SHRINE_SIDE, "lat": Layout.LANDMARK_SHRINE_LATERAL_M, "r": 40.0},
		{"s": Layout.LANDMARK_BRIDGE_S, "side": 0.0, "lat": 0.0, "r": 56.0},
		{"s": Layout.CROSS_LOWER_S, "side": 0.0, "lat": 0.0, "r": 46.0},
		{"s": Layout.PIT_BUILDING_CENTRE_S, "side": 1.0, "lat": 34.0, "r": 110.0},
		{"s": Layout.GRANDSTAND_ANCHOR_S, "side": -1.0, "lat": 46.0, "r": 130.0},
	]:
		var frame := Layout.side_frame(ribbon, float(entry["s"]), 1.0 if float(entry["side"]) >= 0.0 else -1.0, float(entry["lat"]))
		_exclusion.append([Vector2(frame.origin.x, frame.origin.z), float(entry["r"])])


func _build_landmarks() -> void:
	var holder := Node3D.new()
	holder.name = "HeroLandmarks"
	add_child(holder)
	_build_bridge(holder)
	_place_ground_model(holder, "kurogane_giant_ferris_wheel", "TaiyouFerrisWheel", Layout.LANDMARK_FERRIS_S, Layout.LANDMARK_FERRIS_SIDE, Layout.LANDMARK_FERRIS_LATERAL_M, "high ground east of the Esses", true)
	_place_ground_model(holder, "kurogane_grand_reverse_tower", "GrandReverseTower", Layout.LANDMARK_TOWER_S, Layout.LANDMARK_TOWER_SIDE, Layout.LANDMARK_TOWER_LATERAL_M, "Casio Triangle chicane apex (T17/T18, s 4764-4898)")
	_place_ground_model(holder, "kurogane_suzuka_ridge_shrine", "SpoonRidgeShrine", Layout.LANDMARK_SHRINE_S, Layout.LANDMARK_SHRINE_SIDE, Layout.LANDMARK_SHRINE_LATERAL_M, "Spoon summit terrace, +40 m")


## Crossover truss bridge: deck top flush under the road, span scaled to the
## measured gap the trench leaves under the Back Straight, pitched to the grade.
func _build_bridge(holder: Node3D) -> void:
	var span: Vector2 = terrain.bridge_span
	if span == Vector2.ZERO:
		push_warning("kurogane-env: bridge span not measured")
		return
	var centre_s := (span.x + span.y) * 0.5
	var frame: Transform3D = ribbon.call("get_point_at_offset", centre_s, 0.0)
	var forward := -frame.basis.z
	var model := _load_model("kurogane_crossover_truss_bridge")
	if model == null:
		return
	var length := span.y - span.x
	model.name = "CrossoverTrussBridge"
	_bridge_model = model
	var yaw := atan2(forward.x, forward.z)
	# The deck is a straight truss, so pitch it to the grade of the Back Straight
	# through the span: otherwise the flat slab pokes through the curved road.
	var start_y: float = ribbon.call("get_point_at_offset", span.x, 0.0).origin.y
	var end_y: float = ribbon.call("get_point_at_offset", span.y, 0.0).origin.y
	var pitch := asin(clampf((start_y - end_y) / length, -0.5, 0.5))
	model.transform = Transform3D(
		Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, pitch) * Basis.from_scale(Vector3(1.0, 1.0, length / Layout.BRIDGE_MODEL_SPAN_M)),
		Vector3(frame.origin.x, frame.origin.y - 0.10, frame.origin.z)
	)
	holder.add_child(model)
	_landmark_records.append({
		"id": "kurogane_crossover_truss_bridge",
		"glb": ASSET_DIR + "/kurogane_crossover_truss_bridge.glb",
		"s": centre_s, "side": "R", "offset_m": 0.0, "placed": true,
		"anchor": "Back Straight deck over the Degner trench",
		"span_m": snappedf(length, 0.1),
		"position": [snappedf(frame.origin.x, 0.01), snappedf(frame.origin.y - 0.08, 0.01), snappedf(frame.origin.z, 0.01)],
		"triangles": _mesh_triangles(model),
	})


## A landmark standing on its flat pad `lateral` metres off the road at station `s`,
## turned to face the track. `face_x` turns the model's local +X (not +Z) to the track: the ferris wheel's
## disc lies in its YZ plane, so its face looks along X (seen from the road it would otherwise be edge-on).
func _place_ground_model(holder: Node3D, stem: String, node_name: String, s: float, side: float, lateral: float, anchor: String, face_x: bool = false) -> void:
	var frame := Layout.side_frame(ribbon, s, side, lateral)
	var ground: float = terrain.height_at(frame.origin.x, frame.origin.z)
	# Both side frames keep local +X pointing away from the track.
	var to_track := Vector3(-frame.basis.x.x, 0.0, -frame.basis.x.z)
	var model := _load_model(stem)
	if model == null:
		return
	model.name = node_name
	model.transform = Transform3D(
		Basis(Vector3.UP, atan2(-to_track.z, to_track.x) if face_x else atan2(to_track.x, to_track.z)),
		Vector3(frame.origin.x, ground - 0.05, frame.origin.z)
	)
	holder.add_child(model)
	_landmark_records.append({
		"id": stem, "glb": "%s/%s.glb" % [ASSET_DIR, stem],
		"s": s, "side": "L" if side < 0.0 else "R", "offset_m": lateral, "placed": true,
		"anchor": anchor,
		"position": [snappedf(frame.origin.x, 0.01), snappedf(ground, 0.01), snappedf(frame.origin.z, 0.01)],
		"triangles": _mesh_triangles(model),
	})


func _load_model(stem: String) -> Node3D:
	var path := "%s/%s.glb" % [ASSET_DIR, stem]
	var packed := load(path) as PackedScene
	if packed == null:
		push_warning("kurogane-env: missing landmark %s" % path)
		return null
	return packed.instantiate() as Node3D


func _mesh_triangles(root: Node) -> int:
	var total := 0
	for child: Node in root.get_children():
		if child is MeshInstance3D and (child as MeshInstance3D).mesh != null:
			total += _mesh_surface_triangles((child as MeshInstance3D).mesh)
		total += _mesh_triangles(child)
	return total


func _mesh_surface_triangles(mesh: Mesh) -> int:
	var total := 0
	for surface: int in range(mesh.get_surface_count()):
		var arrays := mesh.surface_get_arrays(surface)
		var indices: Variant = arrays[Mesh.ARRAY_INDEX]
		total += (indices.size() if indices != null else (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()) / 3
	return total


# --- paddock ground ----------------------------------------------------------------------

func _add_platform_box(lateral_m: float, width_m: float, top_rel: float, s0: float, s1: float, node_name: String, color: Color) -> void:
	var center_s := (s0 + s1) * 0.5
	var frame := Layout.side_frame(ribbon, center_s, 1.0, lateral_m)
	var top: float = _road_y(center_s) + top_rel
	var length_m := s1 - s0
	var lowest := INF
	for sx: float in [-0.5, 0.5]:
		for sz: float in [-0.5, 0.5]:
			var corner := frame.origin + frame.basis.x * (sx * width_m) + frame.basis.z * (sz * length_m)
			lowest = minf(lowest, terrain.height_at(corner.x, corner.z))
	var bottom := lowest - 0.8
	var box := BoxMesh.new()
	box.size = Vector3(width_m, top - bottom, length_m)
	var instance := MeshInstance3D.new()
	instance.name = node_name
	instance.mesh = box
	instance.material_override = Toon.make(color)
	instance.transform = Transform3D(frame.basis, Vector3(frame.origin.x, (top + bottom) * 0.5, frame.origin.z))
	add_child(instance)


## Solid ground under the paddock: the pit apron base, the concrete terrace behind the
## pit building, the car park and the race-control foundation. The pit lane, boxes, garages,
## crews, transporters and lamps belong to the pit complex.
func _build_paddock_ground() -> void:
	var s0 := Layout.PIT_BUILDING_CENTRE_S - Layout.PIT_BUILDING_SPAN_M * 0.5 - 12.0
	var s1 := Layout.PIT_BUILDING_CENTRE_S + Layout.PIT_BUILDING_SPAN_M * 0.5 + 12.0
	_add_platform_box(16.85, 7.5, 0.06, s0, s1, "PitApronBase", Color("#3a3f47"))
	_add_platform_box(43.3, 45.4, -0.07, s0, s1, "PaddockTerraceBase", Color("#4b5058"))
	_add_platform_box(80.0, 28.0, -0.12, s0, s1, "PaddockPark", Color("#5c7f45"))
	_add_platform_box(93.6, 0.6, 0.12, s0, s1, "PaddockCurb", Color("#d7d9dd"))
	# The kit tower stands 25 m out and about 12 m wide: the foundation must stay off the fast lane
	# (outer edge 13.1 m), or the slab would raise a 7 cm kerb across the lane.
	var tower_lateral_from := Layout.PIT_LANE_OUTER_X + 0.5
	var tower_lateral_to := Layout.CONTROL_TOWER_X + 13.0
	_add_platform_box((tower_lateral_from + tower_lateral_to) * 0.5, tower_lateral_to - tower_lateral_from, 0.07, 6.0, 34.0, "RaceControlFoundation", Color("#7c818a"))
	var lawn_st := SurfaceTool.new()
	lawn_st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var lawn_prev := PackedVector3Array()
	var lawn_s := s0
	while lawn_s <= s1:
		var frame: Transform3D = ribbon.call("get_point_at_offset", fposmod(lawn_s, Layout.LENGTH_M), 0.0)
		var inner := frame.origin + frame.basis.x * 40.0 + Vector3.UP * -0.02
		var outer := frame.origin + frame.basis.x * 44.0 + Vector3.UP * -0.02
		if lawn_prev.size() == 2:
			_quad(lawn_st, lawn_prev[0], lawn_prev[1], outer, inner, Vector3.UP)
		lawn_prev = PackedVector3Array([inner, outer])
		lawn_s += 4.0
	var lawn_mesh := lawn_st.commit()
	if lawn_mesh != null:
		var lawn := MeshInstance3D.new()
		lawn.name = "PaddockLawn"
		lawn.mesh = lawn_mesh
		lawn.material_override = Toon.make(Color("#4c713f"))
		add_child(lawn)


# --- biome -------------------------------------------------------------------------------

func _build_forest() -> void:
	var momiji_a := _momiji_mesh(0.0)
	var momiji_b := _momiji_mesh(1.7)
	var pine_a := _pine_mesh(0.0)
	var pine_b := _pine_mesh(1.3)
	var momiji: Array[Transform3D] = []
	var pines: Array[Transform3D] = []
	_forest_candidates(momiji, pines)
	var group_a: Array[Transform3D] = []
	var group_b: Array[Transform3D] = []
	for index in range(momiji.size()):
		if index % 2 == 0:
			group_a.append(momiji[index])
		else:
			group_b.append(momiji[index])
	var holder := _foliage_holder()
	_add_multimesh(holder, "MomijiA", momiji_a, group_a)
	_add_multimesh(holder, "MomijiB", momiji_b, group_b)
	var pine_group_a: Array[Transform3D] = []
	var pine_group_b: Array[Transform3D] = []
	for index in range(pines.size()):
		if index % 2 == 0:
			pine_group_a.append(pines[index])
		else:
			pine_group_b.append(pines[index])
	_add_multimesh(holder, "ForestPineA", pine_a, pine_group_a)
	_add_multimesh(holder, "ForestPineB", pine_b, pine_group_b)
	_stats["momiji_count"] = momiji.size()
	_stats["pine_count"] = pines.size()
	_stats["tree_count"] = momiji.size() + pines.size()
	for transform: Transform3D in momiji + pines:
		_tree_sites.append(transform.origin)


func _forest_candidates(momiji: Array[Transform3D], pines: Array[Transform3D]) -> void:
	var spacing := 17.0
	for band: Dictionary in _segments:
		var zone := String(band.get("zone", ""))
		if zone != "forest" and zone != "rock":
			continue
		var side: float = 1.0 if String(band.get("side", "R")) != "L" else -1.0
		var s0: float = float(band["s0"])
		var s1: float = float(band["s1"])
		var offset: float = float(band.get("band_offset_m", 14.0))
		var depth: float = minf(float(band.get("band_depth_m", 300.0)), 150.0)
		var density: float = float(band.get("density", 0.8))
		var s := s0
		while s < s1 and (momiji.size() < MOMIJI_TARGET or pines.size() < PINE_TARGET):
			var lateral := offset + 12.0
			while lateral < offset + depth:
				if _rng.randf() < density:
					var jitter_s := _rng.randf_range(-spacing * 0.45, spacing * 0.45)
					var jitter_l := _rng.randf_range(-spacing * 0.45, spacing * 0.45)
					var frame: Transform3D = ribbon.call("get_point_at_offset", fposmod(s + jitter_s, Layout.LENGTH_M), side * (lateral + jitter_l))
					_try_tree(momiji, pines, frame.origin)
				lateral += spacing
			s += spacing
	# Paddock tree line just outside the concrete apron (Momiji avenue).
	var row_s := 8.0
	while row_s <= 200.0:
		var row_frame: Transform3D = ribbon.call("get_point_at_offset", row_s, -98.0)
		_try_tree(momiji, pines, row_frame.origin)
		row_s += 20.0
	# Hillside patches fill the horizon.
	var attempts := 0
	while momiji.size() + pines.size() < MOMIJI_TARGET + PINE_TARGET and attempts < 16000:
		attempts += 1
		var x := _rng.randf_range(terrain.bbox.position.x + 30.0, terrain.bbox.position.x + terrain.bbox.size.x - 30.0)
		var z := _rng.randf_range(terrain.bbox.position.y + 30.0, terrain.bbox.position.y + terrain.bbox.size.y - 30.0)
		var q: Dictionary = terrain.track_query(x, z, 80.0)
		if not q.is_empty() and float(q["d"]) < 30.0:
			continue
		var h: float = terrain.height_at(x, z)
		if _is_excluded(Vector2(x, z), 6.0) or _pad_at(x, z):
			continue
		if _slope_at(x, z) > 0.85:
			continue
		if _noise_patch(x, z) < 0.34:
			continue
		var target: Array[Transform3D] = momiji if momiji.size() < MOMIJI_TARGET else pines
		target.append(_tree_transform(Vector3(x, h, z)))


func _try_tree(momiji: Array[Transform3D], pines: Array[Transform3D], position: Vector3) -> void:
	if momiji.size() >= MOMIJI_TARGET and pines.size() >= PINE_TARGET:
		return
	var q: Dictionary = terrain.track_query(position.x, position.z, 70.0)
	if not q.is_empty() and float(q["d"]) < 24.0:
		return
	if _is_excluded(Vector2(position.x, position.z), 4.0):
		return
	if _pad_at(position.x, position.z):
		return
	if _slope_at(position.x, position.z) > 0.95:
		return
	var h: float = terrain.height_at(position.x, position.z)
	# Autumn Momiji dominates the verges; pines take the higher, cooler slopes.
	var pine := momiji.size() >= MOMIJI_TARGET or h > 34.0 or _rng.randf() < 0.25
	var target: Array[Transform3D] = pines if pine else momiji
	target.append(_tree_transform(Vector3(position.x, h, position.z)))


func _tree_transform(position: Vector3) -> Transform3D:
	var scale := _rng.randf_range(0.75, 1.35)
	var basis := Basis(Vector3.UP, _rng.randf() * TAU).scaled(Vector3(scale, _rng.randf_range(0.85, 1.25) * scale, scale))
	return Transform3D(basis, position)


func _noise_patch(x: float, z: float) -> float:
	var n := sin(x * 0.006 + 1.7) * cos(z * 0.005 - 0.4) + sin((x + z) * 0.0032) * 0.6
	return clampf(n * 0.5 + 0.5, 0.0, 1.0)


func _pad_at(x: float, z: float) -> bool:
	var grid: Dictionary = terrain.heightgrid
	if grid.is_empty():
		return false
	var step: float = float(grid.get("step", 12.0))
	var nx: int = int(grid.get("nx", 0))
	var nz: int = int(grid.get("nz", 0))
	var origin: Vector2 = grid.get("origin", Vector2.ZERO)
	var mask: PackedByteArray = grid.get("pad_mask", PackedByteArray())
	if mask.is_empty():
		return false
	var ix := int(round((x - origin.x) / step))
	var iz := int(round((z - origin.y) / step))
	if ix < 0 or iz < 0 or ix >= nx or iz >= nz:
		return false
	return mask[iz * nx + ix] == 1


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


## Autumn maple: a trunk and three faceted canopy lumps (about 80 triangles a tree; 1 500 of them
## are drawn, so the canopy is the largest share of the environment triangle budget).
func _momiji_mesh(phase: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	_cylinder(st, Vector3.ZERO, 0.28, 3.6, 5, Color("#4b3a2c"))
	var blobs: Array = [
		[Vector3(0.0, 5.4, 0.0), 3.6, Color("#c2452c")],
		[Vector3(1.9, 4.4, 0.8), 2.5, Color("#d86a2a")],
		[Vector3(-1.2, 6.5, -0.9), 2.4, Color("#e08a2f")],
	]
	for index in range(blobs.size()):
		var blob: Array = blobs[index]
		_sphere(st, blob[0], float(blob[1]), 6, blob[2], phase + float(index) * 0.7)
	st.generate_normals()
	return st.commit()


## Low-poly lump: three latitude bands; the pole quads collapse to one triangle each.
func _sphere(st: SurfaceTool, centre: Vector3, radius: float, segments: int, color: Color, phase: float) -> void:
	var rings := 3
	for ring in range(rings):
		var v0 := PI * float(ring) / float(rings) - PI * 0.5
		var v1 := PI * float(ring + 1) / float(rings) - PI * 0.5
		var r0 := cos(v0) * radius
		var r1 := cos(v1) * radius
		var y0 := sin(v0) * radius * 0.82
		var y1 := sin(v1) * radius * 0.82
		for index in range(segments):
			var a0 := TAU * float(index) / float(segments) + phase
			var a1 := TAU * float(index + 1) / float(segments) + phase
			var p0 := centre + Vector3(cos(a0) * r0, y0, sin(a0) * r0)
			var p1 := centre + Vector3(cos(a1) * r0, y0, sin(a1) * r0)
			var q0 := centre + Vector3(cos(a0) * r1, y1, sin(a0) * r1)
			var q1 := centre + Vector3(cos(a1) * r1, y1, sin(a1) * r1)
			var tint := color.lerp(color.lightened(0.22), float(ring) / float(rings))
			var triangles: Array = []
			if r0 > 0.001:
				triangles.append([p0, q0, q1])
			if r1 > 0.001:
				triangles.append([p0, q1, p1])
			for triangle: Array in triangles:
				for vertex: Vector3 in triangle:
					st.set_color(tint)
					st.add_vertex(vertex)


func _pine_mesh(phase: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var trunk_top := 4.4
	_cylinder(st, Vector3.ZERO, 0.24, trunk_top, 5, Color("#4a3a2b"))
	var layers := 3
	for layer in range(layers):
		var base_y := 3.0 + float(layer) * 4.0
		var radius := 3.4 - float(layer) * 0.72
		var height := 6.2 - float(layer) * 0.5
		var color: Color = [Color("#2f5b3a"), Color("#356844"), Color("#2b5236")][layer % 3]
		_cone(st, Vector3(0.0, base_y, 0.0), radius, height, 3, color, phase + float(layer))
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
			st.set_color(color)
			st.add_vertex(vertex)


func _cone(st: SurfaceTool, base: Vector3, radius: float, height: float, segments: int, color: Color, phase: float) -> void:
	var tip := base + Vector3(0.0, height, 0.0)
	for index in range(segments):
		var a0 := TAU * float(index) / float(segments) + phase
		var a1 := TAU * float(index + 1) / float(segments) + phase
		var p0 := base + Vector3(cos(a0) * radius, 0.0, sin(a0) * radius)
		var p1 := base + Vector3(cos(a1) * radius, 0.0, sin(a1) * radius)
		for vertex: Vector3 in [p0, p1, tip]:
			st.set_color(color)
			st.add_vertex(vertex)


func _foliage_holder() -> Node3D:
	var holder := get_node_or_null("Foliage") as Node3D
	if holder == null:
		holder = Node3D.new()
		holder.name = "Foliage"
		add_child(holder)
	return holder


func _add_multimesh(parent: Node3D, node_name: String, mesh: Mesh, transforms: Array[Transform3D]) -> void:
	if transforms.is_empty():
		return
	var material := ShaderMaterial.new()
	material.shader = TreeWindShader
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
	_wind_materials.append(material)


func _build_verge_tufts() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for blade in range(3):
		var angle := float(blade) * PI / 3.0
		var across := Vector3(cos(angle), 0.0, sin(angle)) * 0.2
		var p0 := -across
		var p1 := across
		var p2 := across + Vector3(0.0, 0.9, 0.0)
		var p3 := -across + Vector3(0.0, 0.9, 0.0)
		for v: Vector3 in [p0, p1, p2, p0, p2, p3]:
			st.set_color(Color("#4a7443") if v.y < 0.2 else Color("#6f9555"))
			st.add_vertex(v)
	st.generate_normals()
	var mesh := st.commit()
	if mesh == null:
		return
	var transforms: Array[Transform3D] = []
	var s := 0.0
	while s < Layout.LENGTH_M and transforms.size() < 900:
		var side := -1.0 if _rng.randf() < 0.5 else 1.0
		var lateral := side * _rng.randf_range(8.5, 20.0)
		var frame: Transform3D = ribbon.call("get_point_at_offset", s, lateral)
		var q: Dictionary = terrain.track_query(frame.origin.x, frame.origin.z, 60.0)
		if not q.is_empty() and float(q["d"]) < 8.0:
			s += 5.0
			continue
		if _pad_at(frame.origin.x, frame.origin.z) or _is_excluded(Vector2(frame.origin.x, frame.origin.z), 3.0):
			s += 5.0
			continue
		var h: float = terrain.height_at(frame.origin.x, frame.origin.z)
		var scale := _rng.randf_range(0.7, 1.5)
		var basis := Basis(Vector3.UP, _rng.randf() * TAU).scaled(Vector3(scale, _rng.randf_range(0.8, 1.4) * scale, scale))
		transforms.append(Transform3D(basis, Vector3(frame.origin.x, h, frame.origin.z)))
		s += _rng.randf_range(4.0, 7.0)
	_add_multimesh(_foliage_holder(), "VergeGrass", mesh, transforms)
	_stats["verge_tufts"] = transforms.size()


func _build_rocks() -> void:
	var mesh := _rock_mesh()
	var transforms: Array[Transform3D] = []
	var attempts := 0
	while transforms.size() < ROCK_TARGET and attempts < 12000:
		attempts += 1
		var x := _rng.randf_range(terrain.bbox.position.x + 40.0, terrain.bbox.position.x + terrain.bbox.size.x - 40.0)
		var z := _rng.randf_range(terrain.bbox.position.y + 40.0, terrain.bbox.position.y + terrain.bbox.size.y - 40.0)
		var q: Dictionary = terrain.track_query(x, z, 60.0)
		if not q.is_empty() and float(q["d"]) < 45.0:
			continue
		if _slope_at(x, z) < 0.30:
			continue
		var h: float = terrain.height_at(x, z)
		if _is_excluded(Vector2(x, z), 8.0) or _pad_at(x, z):
			continue
		var scale := _rng.randf_range(0.8, 2.8)
		var basis := Basis(Vector3.UP, _rng.randf() * TAU).scaled(Vector3(scale, scale * _rng.randf_range(0.5, 1.0), scale * _rng.randf_range(0.8, 1.2)))
		transforms.append(Transform3D(basis, Vector3(x, h - scale * 0.25, z)))
	if transforms.is_empty():
		return
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = transforms.size()
	for index in range(transforms.size()):
		mm.set_instance_transform(index, transforms[index])
	var instance := MultiMeshInstance3D.new()
	instance.name = "Rocks"
	instance.multimesh = mm
	instance.material_override = Toon.make(Color("#6a6256"))
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_foliage_holder().add_child(instance)
	_stats["rock_count"] = transforms.size()


func _rock_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var radii: Array[float] = [1.0, 0.82, 1.12, 0.9, 1.05, 0.78]
	var ring0: Array[Vector3] = []
	var ring1: Array[Vector3] = []
	for index in range(6):
		var angle := TAU * float(index) / 6.0
		var r := radii[index]
		ring0.append(Vector3(cos(angle) * r, 0.0, sin(angle) * r))
		ring1.append(Vector3(cos(angle + 0.35) * r * 0.68, 0.95 + (0.15 if index % 2 == 0 else -0.1), sin(angle + 0.35) * r * 0.68))
	var tip := Vector3(0.15, 1.55, -0.12)
	for index in range(6):
		var next := (index + 1) % 6
		for v: Vector3 in [ring0[index], ring1[index], ring1[next], ring0[index], ring1[next], ring0[next]]:
			st.add_vertex(v)
		for v: Vector3 in [ring1[index], tip, ring1[next]]:
			st.add_vertex(v)
		for v: Vector3 in [ring0[index], ring0[next], Vector3(0.0, -0.3, 0.0)]:
			st.add_vertex(v)
	st.generate_normals()
	return st.commit()


# --- finish / helpers --------------------------------------------------------------------

func _finish(started: int) -> void:
	var elapsed := Time.get_ticks_msec() - started
	_stats["build_ms"] = elapsed
	_stats["terrain_triangles"] = terrain.triangles()
	var range_m: Vector2 = terrain.elevation_range()
	_stats["terrain_min_y"] = snappedf(range_m.x, 0.01)
	_stats["terrain_max_y"] = snappedf(range_m.y, 0.01)
	_stats["bridge_span"] = [snappedf(terrain.bridge_span.x, 0.1), snappedf(terrain.bridge_span.y, 0.1)]
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
	print("[kurogane-env] built in %.2fs | terrain tris %d | trees %d | rocks %d | landmarks %d/%d | bridge %.0f..%.0f | env tris %d (budget %d)" % [
		float(elapsed) / 1000.0, int(_stats["terrain_triangles"]), int(_stats.get("tree_count", 0)),
		int(_stats.get("rock_count", 0)), placed, _landmark_records.size(),
		float(terrain.bridge_span.x), float(terrain.bridge_span.y),
		int(_stats["environment_triangles"]), ENVIRONMENT_TRIANGLE_BUDGET,
	])


func _toon() -> void:
	ToonLookScript.apply_visuals(get_parent())


## Draw-call gate: only the hero landmarks and the three FIA structures cast a
## shadow; the terrain, furniture, fences, paddock props, pit lane paint, signs, crews,
## transporters and garage detail would each add a shadow pass for no silhouette the cel look
## needs. The road (TrackRibbon) keeps its own shadow.
func _set_shadow_policy() -> void:
	var root := get_parent()
	if root == null:
		return
	for node: Node in root.find_children("*", "GeometryInstance3D", true, false):
		var geometry := node as GeometryInstance3D
		var path: String = String(root.get_path_to(geometry))
		if path.begins_with("TrackRibbon/"):
			continue
		var keep: bool = path.begins_with("Environment/HeroLandmarks/") \
			or path == "PitLane/PitBuilding/Structure" or path == "PitLane/MainGrandstand/Structure" \
			or path == "PitLane/RaceControlTower/Structure"
		geometry.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if keep else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _road_y(s: float) -> float:
	var points: PackedVector3Array = _compiled["points"]
	var index := posmod(roundi(fposmod(s, Layout.LENGTH_M) / float(_compiled["step_m"])), points.size())
	return points[index].y


func _quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, hint: Vector3) -> void:
	var normal := (b - a).cross(c - a)
	var order: Array = [a, b, c, a, c, d] if normal.dot(hint) < 0.0 else [a, c, b, a, d, c]
	for vertex: Vector3 in order:
		st.add_vertex(vertex)


func _count_triangles(root: Node) -> int:
	var total := 0
	if root is MeshInstance3D and (root as MeshInstance3D).mesh != null:
		total += _mesh_surface_triangles((root as MeshInstance3D).mesh)
	elif root is MultiMeshInstance3D and (root as MultiMeshInstance3D).multimesh != null:
		var multi := (root as MultiMeshInstance3D).multimesh
		if multi.mesh != null:
			total += _mesh_surface_triangles(multi.mesh) * multi.instance_count
	for child: Node in root.get_children():
		total += _count_triangles(child)
	return total


## Base of every Momiji and pine, for the placement gate (a headless run keeps no MultiMesh data).
func tree_sites() -> PackedVector3Array:
	return _tree_sites
