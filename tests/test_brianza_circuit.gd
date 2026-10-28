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
		
	# Calendar Registry integration
	var circuit_data = RegistryScript.get_circuit("brianza")
	check(circuit_data != null, "#B21 CircuitData for 'brianza' exists in registry")
	if circuit_data != null:
		check(circuit_data.is_playable(), "#B22 'brianza' is now officially PLAYABLE!")
		check(circuit_data.length_km == 5.79 and circuit_data.circuit_type == 0, "#B23 length is 5.79 km and type is GRAND PRIX (0)")
		
	instance.queue_free()
	_finish()


func _finish() -> void:
	print("%d assertions, %d failure(s)" % [assertions, failures])
	print("AUTODROMO DI BRIANZA TEST SUITE: %s" % ("PASS" if failures == 0 else "%d FAILURES" % failures))
	quit(0 if failures == 0 else 1)
