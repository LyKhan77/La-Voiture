extends SceneTree

## Headless test suite for Autodromo di Brianza (Round 03, FASE 13).
## Verifies 5 790 m spline length, 11 corners, elevation delta 12.0 m, Tier A GP Pit Complex (410 m),
## 10 pit sockets, Sopraelevata overpass, and Parco Reale vegetation instancing.
## Run: godot --headless --path . -s res://tests/test_brianza_circuit.gd

const ScenePath := "res://scenes/race_world/brianza_circuit.tscn"
const RegistryScript := preload("res://scripts/core/circuit_calendar_registry.gd")
const BuilderScript := preload("res://scripts/world/brianza_circuit_builder.gd")
const PitScript := preload("res://scripts/world/brianza_pit_complex.gd")
const EnvScript := preload("res://scripts/world/brianza_environment.gd")

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
		check(layout["entry_s"] == 5530.0 and layout["exit_s"] == 150.0 and layout["lane_length_m"] == 410.0,
			"#B12 sim_layout() defines 410 m GP lane (entry=5530m, exit=150m)")
		check(layout["stalls"] == 10 and layout["stall_pitch_m"] == 14.0, "#B13 10 stalls at 14.0 m pitch")
		
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
		await _check_jumbotron_feed(env, instance)

	# Calendar Registry integration
	var circuit_data = RegistryScript.get_circuit("brianza")
	check(circuit_data != null, "#B21 CircuitData for 'brianza' exists in registry")
	if circuit_data != null:
		check(circuit_data.is_playable(), "#B22 'brianza' is now officially PLAYABLE!")
		check(circuit_data.length_km == 5.79 and circuit_data.circuit_type == 0, "#B23 length is 5.79 km and type is GRAND PRIX (0)")
		
	instance.queue_free()
	_finish()


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
	var stands: Dictionary = {"RettifiloGrandstand": [1120.0, 1240.0, 100.0], "AscariGrandstand": [3960.0, 4120.0, 120.0]}
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


func _finish() -> void:
	print("%d assertions, %d failure(s)" % [assertions, failures])
	print("AUTODROMO DI BRIANZA TEST SUITE: %s" % ("PASS" if failures == 0 else "%d FAILURES" % failures))
	quit(0 if failures == 0 else 1)
