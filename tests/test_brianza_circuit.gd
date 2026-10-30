extends SceneTree

## Headless test suite for Autodromo di Brianza (Round 03, FASE 13).
## Verifies 5 790 m spline length, 11 corners, elevation delta 12.0 m, Tier A GP Pit Complex (410 m),
## 10 pit sockets, Sopraelevata overpass, and Parco Reale vegetation instancing.
## Run: godot --headless --path . -s res://tests/test_brianza_circuit.gd

const ScenePath := "res://scenes/race_world/circuits/brianza/brianza_circuit.tscn"
const RegistryScript := preload("res://scripts/core/circuit_calendar_registry.gd")
const BuilderScript := preload("res://scripts/world/circuits/brianza/brianza_circuit_builder.gd")
const PitScript := preload("res://scripts/world/circuits/brianza/brianza_pit_complex.gd")
const EnvScript := preload("res://scripts/world/circuits/brianza/brianza_environment.gd")
const ToonMaterials := preload("res://scripts/world/shared/toon_materials.gd")

var failures: int = 0
var assertions: int = 0


func _initialize() -> void:
	call_deferred("_run")


func check(ok: bool, description: String) -> void:
	assertions += 1
	if not ok:
		failures += 1
		push_error(description)
	print("[%s] %s" % ["PASS" if ok else "FAIL", description])


func _run() -> void:
	print("--- Running Autodromo di Brianza Circuit Test Suite ---")
	var scene := load(ScenePath) as PackedScene
	check(scene != null, "#B1 scene exists and loads from %s" % ScenePath)
	if scene == null:
		_finish()
		return
		
	var instance: Node3D = scene.instantiate() as Node3D
	root.add_child(instance)
	await process_frame
	
	var builder := instance as BuilderScript
	check(builder != null, "#B2 root node is BrianzaCircuitBuilder")
	if builder == null:
		instance.queue_free()
		_finish()
		return
		
	var ribbon = builder.ribbon_node()
	check(ribbon != null and ribbon.curve != null, "#B3 TrackRibbon and Curve3D exist and initialized")
	
	var baked_len: float = ribbon.curve.get_baked_length()
	check(absf(baked_len - 5790.0) <= 25.0, "#B4 baked spline length is 5790.0 m ± 25 m (actual: %.2f m)" % baked_len)
	check(ribbon.road_half_width_m == 7.0, "#B5 road half-width is 7.0 m (14.0 m GP corridor)")
	
	# Turns
	check(builder.turns.size() == 8, "#B6 turn specs define all key Monza corner complexes (got %d)" % builder.turns.size())
	check(builder.min_turn_radius_m >= 25.0, "#B7 minimum turn radius is >= 25.0 m (actual: %.1f m)" % builder.min_turn_radius_m)
	
	var corner_names: Array[String] = []
	for t: Dictionary in builder.turns:
		corner_names.append(String(t["name"]))
	var has_rettifilo: bool = corner_names.has("Variante del Rettifilo")
	var has_curva_grande: bool = corner_names.has("Curva Biassono (Curva Grande)")
	var has_roggia: bool = corner_names.has("Variante della Roggia")
	var has_lesmo1: bool = corner_names.has("Curva di Lesmo 1")
	var has_lesmo2: bool = corner_names.has("Curva di Lesmo 2")
	var has_ascari: bool = corner_names.has("Variante Ascari")
	var has_parabolica: bool = corner_names.has("Curva Parabolica (Alboreto)")
	check(has_rettifilo and has_curva_grande and has_roggia and has_lesmo1 and has_lesmo2 and has_ascari and has_parabolica,
		"#B8 contains all iconic Monza corners: Rettifilo, Curva Grande, Roggia, Lesmos, Ascari, and Parabolica")
		
	# Elevation
	var elev_delta: float = builder.max_elevation_m - builder.min_elevation_m
	check(absf(elev_delta - 12.0) <= 0.5, "#B9 elevation delta matches official 12.0 m spec (actual: %.2f m; min=%.1f, max=%.1f)" % [elev_delta, builder.min_elevation_m, builder.max_elevation_m])
	check(builder.max_elevation_m >= 4.5 and builder.min_elevation_m <= -6.8, "#B10 peak is at Lesmo (+4.8m) and lowest is at Sopraelevata (-7.2m)")
	
	# Pit Lane
	var pit: PitScript = instance.get_node_or_null("PitLane") as PitScript
	check(pit != null, "#B11 PitLane complex node exists")
	if pit != null:
		var layout: Dictionary = pit.sim_layout()
		for key: String in ["stall_lane_m", "fast_lane_m", "edge_lateral_m", "queue_gap_m", "lane_ramp_in_m", "lane_ramp_out_m"]:
			check(layout.has(key), "#B13 layout contains %s" % key)
		for method: String in ["stall_transform", "garage_for_team", "crew_roles", "crew_spot", "stall_index_for_team", "lane_lateral"]:
			check(pit.has_method(method), "#B13 pit implements %s" % method)
		if pit.has_method("stall_transform") and pit.has_method("garage_for_team"):
			for team: int in range(10):
				check(pit.stall_transform(team).is_equal_approx(pit.stalls[team]["pose"]) and pit.garage_for_team(team) == pit.garages[team], "#B13 team %d maps to its stall and garage" % team)
			var reordered: Array[int] = [4, 2, 0, 1, 3, 5, 6, 7, 8, 9]
			pit.build(ribbon, reordered)
			check(pit.stall_index_for_team(4) == 0 and pit.stall_index_for_team(2) == 1 and pit.garage_for_team(4) == pit.garages[0], "#B13 existing pit remaps active teams")
			check(pit.garages[0].get_node_or_null("StandbyCrew") != null, "#B13 garage contains standby crew")
		check(layout["entry_s"] == 5530.0 and layout["exit_s"] == 150.0 and layout["lane_length_m"] == 410.0,
			"#B12 sim_layout() defines 410 m GP lane (entry=5530m, exit=150m)")
		check(layout["stalls"] == 10 and layout["stall_pitch_m"] == 20.0, "#B13 10 stalls at 20.0 m pitch")
		
		var sockets_ok: bool = true
		for s_i: int in range(10):
			sockets_ok = sockets_ok and (pit.get_node_or_null("Socket_PitStall_%d" % s_i) != null)
		check(sockets_ok, "#B14 all 10 Socket_PitStall_0..9 exist for pitstop choreography")
		
		# Paddock buildings
		var p_bldg = pit.get_node_or_null("PitBuilding")
		var p_stand = pit.get_node_or_null("MainGrandstand")
		var p_tower = pit.get_node_or_null("RaceControlTower")
		check(p_bldg != null and p_stand != null and p_tower != null, "#B15 shared paddock buildings exist (PitBuilding, MainGrandstand, RaceControlTower)")
		
	# Environment
	var env: EnvScript = instance.get_node_or_null("Environment") as EnvScript
	check(env != null, "#B16 Environment controller node exists")
	if env != null:
		var stats: Dictionary = env.stats()
		check(stats["built"] and stats["sopraelevata_active"], "#B17 Environment builds successfully and activates Sopraelevata landmark")
		check(stats["tree_batches"] >= 2, "#B18 Parco Reale vegetation has at least 2 MultiMesh tree batches")
		
		var sopra: Node3D = env.get_node_or_null("HeroLandmark_Sopraelevata") as Node3D
		check(sopra != null and sopra.get_node_or_null("SopraelevataViaductMesh") != null, "#B19 HeroLandmark_Sopraelevata viaduct mesh is mounted")
		
		var heritage = env.get_node_or_null("HeroLandmarks_MonzaHeritage")
		check(heritage != null, "#B20 HeroLandmarks_MonzaHeritage exists (Villa Reale & Torre Ascari)")
		
		_check_layer1_ground(env, ribbon)
		_check_layer2_sopraelevata(env)
		_check_layer3_grandstands(env, ribbon)
		await _check_track_clearance(pit, env, ribbon)
		await _check_jumbotron_feed(env, instance)
		_check_layer4_foliage(env)
		_check_layer5_trackside(env)
		_check_layer6_vista_and_light(env)
		var budget: Vector2i = _render_budget(env)
		check(budget.x <= 160 and budget.y <= 320000, "#P1 environment budget: %d draw calls (<= 160), %d triangles (<= 320000)" % [budget.x, budget.y])

	# Calendar Registry integration
	var circuit_data = RegistryScript.get_circuit("brianza")
	check(circuit_data != null, "#B21 CircuitData for 'brianza' exists in registry")
	if circuit_data != null:
		check(circuit_data.is_playable(), "#B22 'brianza' is now officially PLAYABLE!")
		check(circuit_data.length_km == 5.79 and circuit_data.circuit_type == 0, "#B23 length is 5.79 km and type is GRAND PRIX (0)")
		
	instance.queue_free()
	_finish()


## Probe the car-height corridor against stand structures and pit wall, using their actual triangles.
func _check_track_clearance(pit: Node3D, env: Node3D, ribbon: Node) -> void:
	var body := StaticBody3D.new()
	root.add_child(body)
	var main_shape: CollisionShape3D
	for mesh_node: MeshInstance3D in [pit.get_node("MainGrandstand/Structure"), pit.get_node("PitWall"), env.get_node("RettifiloGrandstand/Structure"), env.get_node("AscariGrandstand/Structure")]:
		var shape := CollisionShape3D.new()
		shape.shape = mesh_node.mesh.create_trimesh_shape()
		shape.transform = mesh_node.global_transform
		body.add_child(shape)
		if main_shape == null:
			main_shape = shape
	await physics_frame
	var space := root.world_3d.direct_space_state
	var hits: int = 0
	var crowd_hits: int = 0
	var main_stand := pit.get_node("MainGrandstand") as Node3D
	var rettifilo := env.get_node("RettifiloGrandstand") as Node3D
	var ascari := env.get_node("AscariGrandstand") as Node3D
	for s: int in range(0, 5791, 2):
		for lateral: int in range(-7, 8):
			var point: Vector3 = ribbon.get_point_at_offset(float(s), float(lateral)).origin
			var main_local: Vector3 = main_stand.to_local(point)
			if main_local.x >= -58.0 and main_local.x <= -18.0 and absf(main_local.z) <= 81.0:
				crowd_hits += 1
			for stand: Node3D in [rettifilo, ascari]:
				var local: Vector3 = stand.to_local(point)
				var depth: float = 12.6 if stand == rettifilo else 16.8
				if local.x >= -1.0 and local.x <= depth + 1.0 and absf(local.z) <= float(stand.get_meta("length_m")) * 0.5 + 1.0:
					crowd_hits += 1
			var query := PhysicsRayQueryParameters3D.create(point + Vector3.UP * 0.05, point + Vector3.UP * 3.0)
			if not space.intersect_ray(query).is_empty():
				hits += 1
	check(hits == 0, "#B24 car-height track corridor clear of stand structures and pit wall (%d hits)" % hits)
	check(crowd_hits == 0, "#B24 track corridor clears conservative crowd footprints (%d hits)" % crowd_hits)
	var moved_pose: Transform3D = main_shape.transform
	main_shape.transform = ribbon.get_point_at_offset(5625.0, -19.0)
	await physics_frame
	var old_hits: int = 0
	for s: int in range(4700, 4801, 2):
		for lateral: int in range(-7, 8):
			var point: Vector3 = ribbon.get_point_at_offset(float(s), float(lateral)).origin
			if not space.intersect_ray(PhysicsRayQueryParameters3D.create(point + Vector3.UP * 0.05, point + Vector3.UP * 3.0)).is_empty():
				old_hits += 1
	check(old_hits > 0, "#B24 probe detects original back-straight obstruction (%d hits)" % old_hits)
	main_shape.transform = moved_pose
	body.queue_free()


## Static render cost of a subtree: one draw call per surface of every mesh / multimesh, triangles x instances
## (shadow passes and outline next-passes not counted; the same method the earlier phase reports use).
func _render_budget(node: Node) -> Vector2i:
	var total := Vector2i.ZERO
	var mesh: Mesh = null
	var instances: int = 1
	if node is MeshInstance3D and (node as MeshInstance3D).visible:
		mesh = (node as MeshInstance3D).mesh
	elif node is MultiMeshInstance3D and (node as MultiMeshInstance3D).multimesh != null:
		mesh = (node as MultiMeshInstance3D).multimesh.mesh
		instances = (node as MultiMeshInstance3D).multimesh.instance_count
	elif node is Label3D:
		total += Vector2i(1, 2)
	if mesh != null:
		var tris: int = 0
		for surface: int in range(mesh.get_surface_count()):
			var arrays: Array = mesh.surface_get_arrays(surface)
			var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
			tris += (indices.size() if indices.size() > 0 else (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()) / 3
		total += Vector2i(mesh.get_surface_count(), tris * instances)
	for child: Node in node.get_children():
		total += _render_budget(child)
	return total


## FASE 13.1 Layer 1: solid park ground under every road, grass tone, historic park wall.
func _check_layer1_ground(env: EnvScript, ribbon) -> void:
	var ground_root: Node3D = env.get_node_or_null("ParcoRealeGroundRoot") as Node3D
	check(ground_root != null, "#L1.1 ParcoRealeGroundRoot exists")
	if ground_root == null:
		return
	var ground := ground_root.get_node_or_null("ParcoRealeGroundMesh") as MeshInstance3D
	check(ground != null and ground.mesh != null, "#L1.2 ParcoRealeGroundMesh exists with a mesh")
	if ground != null and ground.mesh != null:
		var size: Vector3 = ground.mesh.get_aabb().size
		check(size.x >= 3500.0 and size.z >= 3000.0, "#L1.3 ground covers >= 3500 x 3000 m (got %.0f x %.0f)" % [size.x, size.z])
		var mat := ground.mesh.surface_get_material(0) as ShaderMaterial
		var tone: Color = mat.get_shader_parameter("base_color") if mat != null else Color.BLACK
		check(tone.is_equal_approx(Color("#3c7a38")), "#L1.4 first grass tone is #3c7a38 (got %s)" % tone.to_html(false))
		check(ground.mesh.get_surface_count() == 3, "#L1.5 stepped cel grass uses 3 tones (got %d surfaces)" % ground.mesh.get_surface_count())
	var paths := ground_root.get_node_or_null("ParkPathways") as MeshInstance3D
	check(paths != null and paths.mesh != null, "#L1.6 ParkPathways gravel apron exists")
	var wall := env.get_node_or_null("MuraDelParco") as MeshInstance3D
	check(wall != null and wall.mesh != null and wall.mesh.get_aabb().size.y >= 3.0, "#L1.7 MuraDelParco wall is >= 3.0 m tall")
	# 0 floating roads: ground sits 0.05..3.0 m under every road sample (and exists under both edges).
	var worst_gap: float = 0.0
	var best_gap: float = 99.0
	var s: float = 0.0
	while s < ribbon.length_m:
		for lateral: float in [-6.5, 0.0, 6.5]:
			var road: Vector3 = ribbon.get_point_at_offset(s, lateral).origin
			var gap: float = road.y - env.ground_y_at(road)
			worst_gap = maxf(worst_gap, gap)
			best_gap = minf(best_gap, gap)
		s += 50.0
	check(best_gap >= 0.05 and worst_gap <= 3.0, "#L1.8 road is supported: ground 0.05..3.0 m below every sample (got %.2f..%.2f)" % [best_gap, worst_gap])


## FASE 13.1 Layer 2: curved 480 m banked oval deck on four dual-pier portals, rusty rail.
func _check_layer2_sopraelevata(env: EnvScript) -> void:
	var sopra := env.get_node_or_null("HeroLandmark_Sopraelevata") as Node3D
	var deck := sopra.get_node_or_null("SopraelevataViaductMesh") as MeshInstance3D if sopra != null else null
	check(deck != null, "#L2.1 Sopraelevata deck mesh exists")
	if deck == null:
		return
	var span: Vector3 = deck.mesh.get_aabb().size
	check(maxf(span.x, span.z) >= 400.0, "#L2.2 deck chord spans >= 400 m (got %.0f m)" % maxf(span.x, span.z))
	check(float(sopra.get_meta("arc_length_m", 0.0)) >= 400.0 and is_equal_approx(float(sopra.get_meta("bank_deg", 0.0)), 28.0),
		"#L2.3 deck arc >= 400 m banked 28 deg")
	check(span.y >= 6.0, "#L2.4 banked deck rises >= 6 m edge to edge (got %.1f m)" % span.y)
	var arrays: Array = deck.mesh.surface_get_arrays(0)
	var min_over_track: float = INF
	for v: Vector3 in arrays[Mesh.ARRAY_VERTEX]:
		if absf(v.x) <= 7.0 and absf(v.z) <= 30.0:
			min_over_track = minf(min_over_track, v.y)
	check(min_over_track < INF and min_over_track >= 12.0,"#L2.5 deck clears the straight by >= 12 m (got %.1f m)" % min_over_track)
	var portals: Array[Node] = []
	var portal_root := sopra.get_node_or_null("SopraelevataPortals")
	if portal_root != null:
		portals = portal_root.get_children()
	check(portals.size() >= 4, "#L2.6 at least 4 dual-pier portals (got %d)" % portals.size())
	var tall: bool = not portals.is_empty()
	for portal: Node in portals:
		tall = tall and portal is MeshInstance3D and (portal as MeshInstance3D).mesh.get_aabb().size.y >= 12.0
	check(tall, "#L2.7 every portal stands >= 12 m")
	var rail := sopra.get_node_or_null("SopraelevataGuardrail") as MeshInstance3D
	check(rail != null and rail.mesh != null and rail.mesh.get_aabb().size.y >= 2.0, "#L2.8 rusty guardrail runs along the upper lip")


class FakeCar:
	extends RefCounted
	var team_id: int = 0


class FakeRace:
	extends RefCounted
	var weather = null
	var order: Array = []

	func standings() -> Array:
		return order


## FASE 13.1 Layer 3: Rettifilo + Ascari corner stands with crowd, heritage landmarks as own nodes.
func _check_layer3_grandstands(env: EnvScript, ribbon) -> void:
	# The spec's s ranges (1120-1240, 3960-4120) predate the final spline; Turn 1 really is at s~718 and
	# the Ascari complex spans s 4087-4340, so each stand must sit inside its corner's own span.
	var corner_of: Dictionary = {"RettifiloGrandstand": "Variante del Rettifilo", "AscariGrandstand": "Variante Ascari"}
	var stands: Dictionary = {}
	for stand_name: String in corner_of:
		for turn: Dictionary in env.builder.turns:
			if String(turn["name"]) == corner_of[stand_name]:
				stands[stand_name] = [float(turn["s"]) - float(turn["span_m"]) * 0.5, float(turn["s"]) + float(turn["span_m"]) * 0.5, 100.0 if stand_name.begins_with("Rett") else 120.0]
	for stand_name: String in stands:
		var stand := env.get_node_or_null(stand_name) as Node3D
		check(stand != null, "#L3.1 %s exists" % stand_name)
		if stand == null:
			continue
		var range_info: Array = stands[stand_name]
		var s_centre: float = float(stand.get_meta("s_centre", -1.0))
		check(s_centre >= range_info[0] and s_centre <= range_info[1], "#L3.2 %s sits in its corner (s=%.0f)" % [stand_name, s_centre])
		check(float(stand.get_meta("length_m", 0.0)) >= range_info[2], "#L3.3 %s is >= %.0f m long" % [stand_name, range_info[2]])
		var crowd := stand.get_node_or_null("Crowd") as MultiMeshInstance3D
		check(crowd != null and crowd.multimesh.instance_count >= 200, "#L3.4 %s has an instanced crowd (>= 200 spectators)" % stand_name)
		check(stand.get_node_or_null("Canopy") is MeshInstance3D, "#L3.5 %s has a roof canopy" % stand_name)
		var ground_gap: float = INF
		var base: Vector3 = (stand.get_node("Structure") as MeshInstance3D).global_position
		ground_gap = absf(base.y - env.ground_y_at(base))
		check(ground_gap < 6.0, "#L3.6 %s stands on the ground (gap %.1f m)" % [stand_name, ground_gap])
	var heritage := env.get_node_or_null("HeroLandmarks_MonzaHeritage")
	check(heritage != null and heritage.get_node_or_null("TorreAscari") != null and heritage.get_node_or_null("VillaRealeGatehouse") != null,
		"#L3.7 TorreAscari and VillaRealeGatehouse are separate landmark nodes")


## The two Jumbotrons (main stand + Ascari) repaint from live standings.
func _check_jumbotron_feed(env: EnvScript, instance: Node3D) -> void:
	var ascari_screen := env.get_node_or_null("AscariGrandstand/Jumbotron") as Jumbotron
	var main_screen := instance.get_node_or_null("PitLane/MainGrandstand/Jumbotron") as Jumbotron
	check(ascari_screen != null and main_screen != null, "#L3.8 Ascari and main-stand Jumbotrons exist")
	if ascari_screen == null or main_screen == null:
		return
	var race := FakeRace.new()
	for team: int in range(3):
		var car := FakeCar.new()
		car.team_id = team
		race.order.append(car)
	env.update(1.0, race)
	check(ascari_screen.last_row_colors.size() == 3 and main_screen.last_row_colors.size() == 3, "#L3.9 both Jumbotrons show the live standings")


## FASE 13.1 Layer 4: umbrella pines (3-tone canopy), cypresses, undergrowth; grounded, shadowless, clear of stands.
func _check_layer4_foliage(env: EnvScript) -> void:
	var root := env.get_node_or_null("ParcoRealeFoliage")
	var minimums: Dictionary = {"StonePines": 450, "ItalianCypresses": 250, "UndergrowthBushes": 300}
	var batches: Dictionary = {}
	for batch_name: String in minimums:
		var inst := root.get_node_or_null(batch_name) as MultiMeshInstance3D if root != null else null
		batches[batch_name] = inst
		var count: int = inst.multimesh.instance_count if inst != null else 0
		check(count >= int(minimums[batch_name]), "#L4.1 %s has >= %d instances (got %d)" % [batch_name, minimums[batch_name], count])
		check(inst != null and inst.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF, "#L4.2 %s casts no shadow" % batch_name)
	var pines := batches["StonePines"] as MultiMeshInstance3D
	if pines == null:
		return
	var colors: PackedColorArray = pines.multimesh.mesh.surface_get_arrays(0)[Mesh.ARRAY_COLOR]
	var tones_found: int = 0
	for tone: String in ["#2d5432", "#3f7345", "#528c5a"]:
		var want: Color = Color(tone).srgb_to_linear()
		for c: Color in colors:
			# Mesh vertex colours are stored 8-bit, so match to one quantisation step.
			if absf(c.r - want.r) < 0.01 and absf(c.g - want.g) < 0.01 and absf(c.b - want.b) < 0.01:
				tones_found += 1
				break
	check(tones_found == 3, "#L4.3 pine umbrella canopy has 3 cel tones (found %d)" % tones_found)
	var worst_gap: float = 0.0
	var inside_stand: int = 0
	var stands: Array[Node3D] = [env.get_node("RettifiloGrandstand") as Node3D, env.get_node("AscariGrandstand") as Node3D]
	# Headless MultiMeshes keep no transforms, so read the poses the environment kept.
	for batch_name: String in minimums:
		var poses: Array = env.foliage_poses.get(batch_name, [])
		var inst := batches[batch_name] as MultiMeshInstance3D
		check(inst != null and poses.size() == inst.multimesh.instance_count, "#L4.6 %s kept every pose (%d)" % [batch_name, poses.size()])
		for i: int in range(0, poses.size(), 7):
			var origin: Vector3 = (poses[i] as Transform3D).origin
			worst_gap = maxf(worst_gap, absf(origin.y - env.ground_y_at(origin)))
			for stand: Node3D in stands:
				var local: Vector3 = stand.to_local(origin)
				if local.x > -4.0 and local.x < 40.0 and absf(local.z) < float(stand.get_meta("length_m")) * 0.5 + 6.0:
					inside_stand += 1
	check(worst_gap <= 0.6, "#L4.4 every sampled tree/bush stands on the ground (worst gap %.2f m)" % worst_gap)
	check(inside_stand == 0, "#L4.5 no foliage inside the corner grandstands (%d found)" % inside_stand)


## FASE 13.1 Layer 5: catch fence over the armco, overhead brake gantries, retro sponsors, marshal posts.
func _check_layer5_trackside(env: EnvScript) -> void:
	var root := env.get_node_or_null("TracksideSafetyRoot")
	check(root != null, "#L5.1 TracksideSafetyRoot exists")
	if root == null:
		return
	var fence := root.get_node_or_null("CatchFence") as MultiMeshInstance3D
	check(fence != null and fence.multimesh.instance_count >= 150, "#L5.2 CatchFence is instanced (>= 150 panels, got %d)" % (fence.multimesh.instance_count if fence != null else 0))
	if fence != null:
		check(fence.multimesh.mesh.get_aabb().size.y >= 2.8, "#L5.3 catch fence stands >= 2.8 m")
		var wire := fence.multimesh.mesh.surface_get_material(1) as StandardMaterial3D
		check(wire != null and is_equal_approx(wire.albedo_color.a, 0.35), "#L5.4 fence mesh is semi-transparent wire (alpha 0.35)")
		check(fence.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF, "#L5.5 catch fence casts no shadow")
		var near_stand: int = 0
		var stand := env.get_node("RettifiloGrandstand") as Node3D
		for pose: Transform3D in env.catch_fence_poses:
			if stand.to_local(pose.origin).length() < 100.0:
				near_stand += 1
		check(near_stand >= 10, "#L5.6 fence runs along the Rettifilo stand (%d panels)" % near_stand)
	var gantries: Array[Node] = []
	var gantry_root := root.get_node_or_null("BrakingGantries")
	if gantry_root != null:
		gantries = gantry_root.get_children().filter(func(n: Node) -> bool: return n.has_meta("meters"))
	var meters: Dictionary = {}
	var corners: Dictionary = {}
	for g: Node in gantries:
		meters[int(g.get_meta("meters"))] = true
		corners[String(g.get_meta("corner"))] = true
	check(gantries.size() == 12 and meters.size() == 4 and meters.has(200) and meters.has(50) and corners.size() == 3,
		"#L5.7 12 overhead brake boards: 200/150/100/50 m at 3 corners (got %d boards, %d distances, %d corners)" % [gantries.size(), meters.size(), corners.size()])
	check(gantry_root != null and gantry_root.get_node_or_null("GantryFrames") is MeshInstance3D, "#L5.8 gantry frames are one merged mesh")
	var sponsors := root.get_node_or_null("SponsorBoards")
	var brands: Array[String] = ["Pirelli", "Brembo", "Agip", "MagnetiMarelli"]
	var brands_ok: bool = sponsors != null
	for brand: String in brands:
		var boards := sponsors.get_node_or_null(brand) as MultiMeshInstance3D if sponsors != null else null
		brands_ok = brands_ok and boards != null and boards.multimesh.instance_count >= 8
	check(brands_ok, "#L5.9 Pirelli, Brembo, Agip and Magneti Marelli boards (>= 8 each)")
	var labels: Array[String] = []
	if sponsors != null:
		for l: Node in sponsors.get_children():
			if l is Label3D:
				labels.append((l as Label3D).text)
	check(labels.has("PIRELLI") and labels.has("BREMBO") and labels.has("AGIP") and labels.has("MAGNETI MARELLI"), "#L5.10 hero boards carry the brand names")
	var marshals := root.get_node_or_null("MarshalPosts") as MeshInstance3D
	check(marshals != null and int(marshals.get_meta("count", 0)) >= 8, "#L5.11 marshal posts at the corner apexes (>= 8)")


## FASE 13.1 Layer 6: 4.5 km Alpine vista ring and a real bind_world() / time-of-day lighting rig.
func _check_layer6_vista_and_light(env: EnvScript) -> void:
	var ring := env.get_node_or_null("BrianzaVistaRing") as MeshInstance3D
	check(ring != null and ring.mesh != null, "#L6.1 BrianzaVistaRing exists")
	if ring != null and ring.mesh != null:
		var box: AABB = ring.mesh.get_aabb()
		check(box.size.x >= 8500.0 and box.size.z >= 8500.0, "#L6.2 ring spans ~4.5 km radius (got %.0f x %.0f m)" % [box.size.x, box.size.z])
		check(box.size.y >= 300.0 and ring.mesh.get_surface_count() >= 3, "#L6.3 forest line + foothills + Alps layers, peaks >= 300 m (%d layers, %.0f m)" % [ring.mesh.get_surface_count(), box.size.y])
	var world_env := WorldEnvironment.new()
	world_env.environment = Environment.new()
	var sun := DirectionalLight3D.new()
	var cam := Camera3D.new()
	cam.far = 3500.0
	root.add_child(world_env)
	root.add_child(sun)
	root.add_child(cam)
	env.bind_world(world_env, sun, cam)
	var e: Environment = world_env.environment
	check(sun.light_color.is_equal_approx(Color("#fff3db")), "#L6.4 DAY sun is warm gold #fff3db (got %s)" % sun.light_color.to_html(false))
	check(is_equal_approx(sun.rotation_degrees.x, -42.0) and is_equal_approx(sun.rotation_degrees.y, 215.0), "#L6.5 sun pitch 42, yaw 215 (got %s)" % sun.rotation_degrees)
	check(sun.shadow_enabled and sun.shadow_blur > 1.0, "#L6.6 sun casts soft shadows")
	check(e.ambient_light_color.is_equal_approx(Color("#a3c2f0")) and e.fog_light_color.is_equal_approx(Color("#dce8f5")), "#L6.7 ambient #a3c2f0 and Mediterranean fog #dce8f5")
	check(e.tonemap_mode == Environment.TONE_MAPPER_ACES and e.glow_enabled and e.fog_enabled, "#L6.8 ACES tonemap, glow and fog on")
	check(cam.far >= 5000.0, "#L6.9 camera far plane reaches the vista ring (got %.0f)" % cam.far)
	var glow := ToonMaterials.vertex_colored(false)
	env.apply_time_of_day({"mode": 1, "floodlights": 0.4, "stars_opacity": 0.0}, 0.0)
	check(sun.rotation_degrees.x > -25.0 and sun.light_color.r > sun.light_color.b + 0.3, "#L6.10 SUNSET sun drops low and turns orange")
	check(float(glow.get_shader_parameter("glow_energy")) > 0.5, "#L6.11 SUNSET floodlights start to glow")
	env.apply_time_of_day({"mode": 2, "floodlights": 1.0, "stars_opacity": 1.0}, 0.0)
	check(world_env.environment.fog_light_color.get_luminance() < 0.25 and float(glow.get_shader_parameter("glow_energy")) >= 3.0, "#L6.12 NIGHT is dark with floodlights fully lit")
	env.apply_time_of_day({"mode": 0, "floodlights": 0.0, "stars_opacity": 0.0}, 0.0)
	check(sun.light_color.is_equal_approx(Color("#fff3db")) and float(glow.get_shader_parameter("glow_energy")) == 0.0, "#L6.13 back to DAY restores light and switches floodlights off")
	for node: Node in [world_env, sun, cam]:
		node.queue_free()


func _finish() -> void:
	print("%d assertions, %d failure(s)" % [assertions, failures])
	print("AUTODROMO DI BRIANZA TEST SUITE: %s" % ("PASS" if failures == 0 else "%d FAILURES" % failures))
	quit(0 if failures == 0 else 1)
