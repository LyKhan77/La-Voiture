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

const SERRAGLIO_OVERPASS_S: float = 3450.0
const ASCARI_TOWER_S: float = 4150.0
const VILLA_GATE_S: float = 5600.0

const KERB_CURVATURE: float = 0.006
const KERB_MIN_LENGTH_M: float = 14.0
const KERB_SCAN_STEP_M: float = 2.0

const RED := Color("#d9232e")
const WHITE := Color("#f0f2f5")

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


func build(p_ribbon: RibbonScript, p_builder: CircuitBuilderScript) -> void:
	if built:
		return
	built = true
	ribbon = p_ribbon
	builder = p_builder
	line = AdaptiveLineScript.new(ribbon)
	
	_build_tier_a_surface()
	_build_tier_a_furniture()
	_build_tier_a_sky()
	_build_tier_b_sopraelevata()
	_build_tier_b_landmarks()
	_build_tier_b_royal_park_foliage()


func bind_world(_world_env: WorldEnvironment, _sun: DirectionalLight3D, _camera: Camera3D) -> void:
	pass


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
			shared_sky.apply_time_of_day(tod, gloom)


func apply_time_of_day(tod, gloom: float = 0.0) -> void:
	if shared_sky != null and shared_sky.has_method("apply_time_of_day"):
		shared_sky.apply_time_of_day(tod, gloom)
	if furniture != null and furniture.has_method("apply_time_of_day"):
		furniture.call("apply_time_of_day", tod)


func stats() -> Dictionary:
	return {
		"circuit_id": "brianza",
		"length_m": ribbon.curve.get_baked_length() if ribbon != null and ribbon.curve != null else 0.0,
		"built": built,
		"sopraelevata_active": sopraelevata != null,
		"tree_batches": tree_multimeshes.size(),
	}


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


## Hero Landmark 1: La Sopraelevata di Monza (1950s High-Banked Oval Concrete Overpass Viaduct)
func _build_tier_b_sopraelevata() -> void:
	sopraelevata = Node3D.new()
	sopraelevata.name = "HeroLandmark_Sopraelevata"
	add_child(sopraelevata)
	
	if ribbon == null:
		return
		
	var xform: Transform3D = ribbon.get_point_at_offset(SERRAGLIO_OVERPASS_S, 0.0)
	sopraelevata.transform = xform
	
	var batch := MeshBatchScript.new()
	var mat: Material = ToonMaterials.vertex_colored(false)
	var conc_col := Color("#8a8f9c")
	var dark_conc := Color("#555966")
	var rust_col := Color("#733d26")
	
	# Massive support piers on both sides of the 14 m GP track
	for side: float in [-1.0, 1.0]:
		var pier_x: float = side * 14.5
		# Concrete pillar base
		batch.box(mat, dark_conc, Transform3D(Basis.IDENTITY, Vector3(pier_x, 6.0, 0.0)), Vector3(4.5, 12.0, 5.0))
		# Concrete arch bracket
		batch.box(mat, conc_col, Transform3D(Basis.IDENTITY, Vector3(pier_x * 0.85, 11.5, 0.0)), Vector3(3.0, 2.5, 5.2))
		
	# High-banked oval deck crossing overhead (inclined 28 degrees)
	var deck_rot := Basis(Vector3.FORWARD, deg_to_rad(28.0))
	var deck_pose := Transform3D(deck_rot, Vector3(0.0, 13.5, 0.0))
	# Main banked roadbed
	batch.box(mat, conc_col, deck_pose, Vector3(42.0, 1.8, 14.0))
	# Historic safety crash rail on outer upper lip of the banking
	var rail_pose := deck_pose
	rail_pose.origin += deck_pose.basis.x * 20.0 + deck_pose.basis.y * 1.5
	batch.box(mat, rust_col, rail_pose, Vector3(1.2, 2.2, 14.2))
	# Inner lower lip
	var lip_pose := deck_pose
	lip_pose.origin -= deck_pose.basis.x * 20.0 - deck_pose.basis.y * 0.5
	batch.box(mat, dark_conc, lip_pose, Vector3(1.2, 1.2, 14.2))
	
	var inst := MeshInstance3D.new()
	inst.name = "SopraelevataViaductMesh"
	inst.mesh = batch.commit()
	sopraelevata.add_child(inst)


## Hero Landmark 2 & 3: Villa Reale Gateway Arch and Torre Ascari
func _build_tier_b_landmarks() -> void:
	if ribbon == null:
		return
		
	var landmarks := Node3D.new()
	landmarks.name = "HeroLandmarks_MonzaHeritage"
	add_child(landmarks)
	
	var batch := MeshBatchScript.new()
	var mat: Material = ToonMaterials.vertex_colored(false)
	
	# Villa Reale Brick Gateway Arch (s = 5600 m, behind the main grandstand at lateral -36 m)
	var gate_pose: Transform3D = ribbon.get_point_at_offset(VILLA_GATE_S, -36.0)
	
	var brick_col := Color("#a3483b")
	var stone_col := Color("#d4d0c7")
	batch.box(mat, brick_col, gate_pose * Transform3D(Basis.IDENTITY, Vector3(-6.0, 5.0, 0.0)), Vector3(3.2, 10.0, 3.2))
	batch.box(mat, brick_col, gate_pose * Transform3D(Basis.IDENTITY, Vector3(6.0, 5.0, 0.0)), Vector3(3.2, 10.0, 3.2))
	batch.box(mat, stone_col, gate_pose * Transform3D(Basis.IDENTITY, Vector3(0.0, 9.8, 0.0)), Vector3(16.0, 2.2, 4.0))
	batch.box(mat, stone_col, gate_pose * Transform3D(Basis.IDENTITY, Vector3(0.0, 11.8, 0.0)), Vector3(10.0, 1.8, 2.5))
	
	# Torre Ascari (Vintage timing & signal tower at s = 4150 m, entry to Ascari chicane)
	var tower_pose: Transform3D = ribbon.get_point_at_offset(ASCARI_TOWER_S, 16.5)
	
	var tower_col := Color("#4d5361")
	var banner_col := Color("#ffd400") # Retro Agip yellow
	batch.box(mat, tower_col, tower_pose * Transform3D(Basis.IDENTITY, Vector3(0.0, 8.0, 0.0)), Vector3(3.8, 16.0, 3.8))
	batch.box(mat, Color(0.2, 0.8, 1.0, 0.4), tower_pose * Transform3D(Basis.IDENTITY, Vector3(0.0, 14.5, 0.0)), Vector3(4.8, 3.2, 4.8))
	batch.box(mat, banner_col, tower_pose * Transform3D(Basis.IDENTITY, Vector3(0.0, 8.5, -2.1)), Vector3(3.6, 6.0, 0.3))
	
	var mi := MeshInstance3D.new()
	mi.name = "MonzaHeritageMeshes"
	mi.mesh = batch.commit()
	landmarks.add_child(mi)


## Tier B Biome: Parco Reale di Monza (Stone Pines with broad umbrella canopies & Italian Cypresses)
func _build_tier_b_royal_park_foliage() -> void:
	if ribbon == null or ribbon.curve == null:
		return
		
	tree_multimeshes.clear()
	var foliage_root := Node3D.new()
	foliage_root.name = "ParcoRealeFoliage"
	add_child(foliage_root)
	
	var length_m: float = ribbon.curve.get_baked_length()
	var pine_poses: Array[Transform3D] = []
	var cypress_poses: Array[Transform3D] = []
	
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
				var pose: Transform3D = ribbon.get_point_at_offset(s, side * depth)
				pose.origin.y = maxf(pose.origin.y, -7.0)
				
				var yaw: float = rng.randf_range(0.0, TAU)
				var scale_f: float = rng.randf_range(0.85, 1.25)
				pose.basis = Basis(Vector3.UP, yaw).scaled(Vector3.ONE * scale_f)
				
				if rng.randf() < 0.65:
					pine_poses.append(pose)
				else:
					cypress_poses.append(pose)
					
	# Create Pine Tree Mesh (Trunk + Umbrella Canopy)
	var pine_batch := MeshBatchScript.new()
	var mat_trunk: Material = ToonMaterials.vertex_colored(false)
	var trunk_col := Color("#4a3728")
	var pine_leaf_col := Color("#355e3b")
	pine_batch.cylinder(mat_trunk, trunk_col, Transform3D(Basis.IDENTITY, Vector3(0.0, 4.0, 0.0)), 0.35, 0.30, 8.0, 8)
	pine_batch.cylinder(mat_trunk, pine_leaf_col, Transform3D(Basis.IDENTITY, Vector3(0.0, 8.5, 0.0)), 5.2, 4.2, 2.5, 10)
	pine_batch.cylinder(mat_trunk, pine_leaf_col * 0.9, Transform3D(Basis.IDENTITY, Vector3(0.0, 10.5, 0.0)), 4.0, 0.0, 2.0, 10)
	var pine_mesh: ArrayMesh = pine_batch.commit()
	
	var pine_inst := _create_multimesh_instance("StonePines", pine_mesh, pine_poses)
	foliage_root.add_child(pine_inst)
	tree_multimeshes.append(pine_inst)
	
	# Create Cypress Tree Mesh (Slender tall green column)
	var cyp_batch := MeshBatchScript.new()
	var cyp_leaf_col := Color("#1e3f20")
	cyp_batch.cylinder(mat_trunk, trunk_col, Transform3D(Basis.IDENTITY, Vector3(0.0, 1.5, 0.0)), 0.2, 0.2, 3.0, 6)
	cyp_batch.cylinder(mat_trunk, cyp_leaf_col, Transform3D(Basis.IDENTITY, Vector3(0.0, 7.0, 0.0)), 1.4, 0.0, 9.0, 8)
	var cyp_mesh: ArrayMesh = cyp_batch.commit()
	
	var cyp_inst := _create_multimesh_instance("ItalianCypresses", cyp_mesh, cypress_poses)
	foliage_root.add_child(cyp_inst)
	tree_multimeshes.append(cyp_inst)


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
