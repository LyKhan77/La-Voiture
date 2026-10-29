extends SceneTree

## Every circuit shows the race-control flag on eight digital panels (FlagPanelSet): all three sectors have one, they stand
## off the asphalt and apart from each other, a yellow lights only its sector, the safety car lights all, green clears them.
## Neo-Wangan's panels additionally keep out of the tunnel and off the bridge, off the open pit side and off the lamp poles.
## Run: godot --headless --path . -s res://tests/test_flag_panels_contract.gd

const WorldScene := preload("res://scenes/race_weekend_world.tscn")
const Config := preload("res://scripts/core/race_config_data.gd")
const Types := preload("res://scripts/gt/gt_types.gd")
const WanganCircuit := preload("res://scripts/world/circuits/neo_wangan/neo_wangan_circuit_builder.gd")
const WanganEnvironment := preload("res://scripts/world/circuits/neo_wangan/neo_wangan_environment.gd")
const CIRCUITS: Array[String] = ["apex_ring", "neo_wangan", "brianza"]
## Panels closer than this to each other along the lap read as one.
const MIN_PANEL_GAP_M: float = 60.0

var failures: int = 0


func check(ok: bool, description: String) -> void:
	print("[%s] %s" % ["PASS" if ok else "FAIL", description])
	if not ok:
		failures += 1


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_plan()
	for circuit: String in CIRCUITS:
		await _audit(circuit)
	quit(1 if failures else 0)


func _test_plan() -> void:
	var preferred: Array[Dictionary] = [{"s": 500.0, "side": 1.0}, {"s": 560.0, "side": 1.0}, {"s": 1900.0, "side": -1.0}]
	var anchors: Array[Dictionary] = FlagPanelSet.plan(3000.0, preferred)
	check(anchors.size() == FlagPanelSet.COUNT, "plan: eight panels (%d)" % anchors.size())
	check(is_equal_approx(float(anchors[0]["s"]), 2940.0), "plan: the first panel stands 60 m before the finish line")
	var arcs: Array[float] = []
	for anchor: Dictionary in anchors:
		arcs.append(float(anchor["s"]))
	check(arcs.has(500.0) and not arcs.has(560.0) and arcs.has(1900.0), "plan: a preferred anchor within 150 m of one already chosen is dropped")


func _audit(circuit: String) -> void:
	var config = Config.get_config()
	config.selected_circuit_id = circuit
	config.selected_team_id = 4
	config.race_seed = 19220903
	var world = WorldScene.instantiate()
	root.add_child(world)
	await process_frame
	var env = world.environment
	var panels: FlagPanelSet = env.flag_panels
	check(panels != null, "%s: the environment has flag panels" % circuit)
	if panels == null:
		world.queue_free()
		await process_frame
		return
	check(panels.count == FlagPanelSet.COUNT and panels.multimesh.instance_count == FlagPanelSet.COUNT and panels.get_parent() != null,
		"%s: eight panels share ONE MultiMeshInstance3D that is part of the scene" % circuit)
	var sectors: Dictionary = {}
	for record: Dictionary in panels.records:
		sectors[int(record["sector"])] = true
	check(sectors.size() == 3, "%s: every sector carries a panel" % circuit)

	var ribbon = world.ribbon
	var off_road: bool = true
	var apart: bool = true
	for index: int in range(panels.count):
		var s: float = float(panels.records[index]["s"])
		var centre: Vector3 = ribbon.get_point_at_offset(s, 0.0).origin
		var flat := Vector2(panels.poses[index].origin.x - centre.x, panels.poses[index].origin.z - centre.z)
		off_road = off_road and flat.length() >= ribbon.road_half_width_m + 1.5
		for other: int in range(index + 1, panels.count):
			var gap: float = absf(fposmod(s - float(panels.records[other]["s"]) + ribbon.length_m * 0.5, ribbon.length_m) - ribbon.length_m * 0.5)
			apart = apart and gap >= MIN_PANEL_GAP_M
	check(off_road, "%s: every panel stands at least 1.5 m off the asphalt edge" % circuit)
	check(apart, "%s: no two panels within %.0f m of each other" % [circuit, MIN_PANEL_GAP_M])

	var yellow_sector: int = int(panels.records[0]["sector"])
	var expected_yellow: int = 0
	for record: Dictionary in panels.records:
		expected_yellow += 1 if int(record["sector"]) == yellow_sector else 0
	panels.apply_flag(Types.Flag.YELLOW, yellow_sector)
	var yellow_ok: bool = true
	for index: int in range(panels.count):
		yellow_ok = yellow_ok and panels.states[index] == (FlagPanelSet.PanelState.YELLOW if int(panels.records[index]["sector"]) == yellow_sector else FlagPanelSet.PanelState.GREEN)
	check(yellow_ok and expected_yellow > 0, "%s: a sector %d yellow lights only its %d panels" % [circuit, yellow_sector, expected_yellow])
	panels.apply_flag(Types.Flag.SC, 1)
	check(panels.states.count(FlagPanelSet.PanelState.SC) == panels.count, "%s: the safety car lights every panel" % circuit)
	panels.apply_flag(Types.Flag.GREEN, 1)
	check(panels.states.count(FlagPanelSet.PanelState.GREEN) == panels.count, "%s: green clears every panel" % circuit)

	if circuit == "neo_wangan":
		_audit_wangan(world, env, panels)
	world.queue_free()
	await process_frame


func _arc_gap(world, a: float, b: float) -> float:
	var length: float = world.ribbon.length_m
	return absf(fposmod(a - b + length * 0.5, length) - length * 0.5)


func _audit_wangan(world, env, panels: FlagPanelSet) -> void:
	var circuit = env.circuit
	var in_zone: int = 0
	var open_pit_side: int = 0
	var on_pole: int = 0
	for record: Dictionary in panels.records:
		var s: float = float(record["s"])
		in_zone += 1 if (circuit.tunnel_contains(s) or circuit.on_bridge(s)) else 0
		open_pit_side += 1 if (float(record["side"]) > 0.0 and env._in_pit_gap(s)) else 0
		var from_pole: float = fposmod(s - WanganEnvironment.LAMP_FIRST_S, WanganEnvironment.LAMP_PITCH_M)
		on_pole += 1 if minf(from_pole, WanganEnvironment.LAMP_PITCH_M - from_pole) < WanganEnvironment.PANEL_POLE_CLEAR_M else 0
	check(in_zone == 0, "neo_wangan: no panel in the tunnel or on the bridge (%d)" % in_zone)
	check(open_pit_side == 0, "neo_wangan: no panel on the open pit side (%d)" % open_pit_side)
	check(on_pole == 0, "neo_wangan: no panel on a streetlight pole (%d)" % on_pole)
	var on_prop: int = 0
	for record: Dictionary in panels.records:
		var s: float = float(record["s"])
		for gantry_s: float in WanganEnvironment.GANTRY_S:
			on_prop += 1 if _arc_gap(world, s, gantry_s) < 6.0 else 0
		for turn: Dictionary in circuit.turns:
			if -float(turn["direction"]) != float(record["side"]):
				continue
			for distance: float in WanganEnvironment.BOARD_DISTANCES_M:
				on_prop += 1 if _arc_gap(world, s, float(turn["apex_s"][0]) - distance) < 3.0 else 0
	check(on_prop == 0, "neo_wangan: no panel on a gantry sign post or a braking board (%d)" % on_prop)
	# Behind the concrete barrier (back face 6.63 m), not in it.
	var behind_barrier: bool = true
	for index: int in range(panels.count):
		var s: float = float(panels.records[index]["s"])
		var centre: Vector3 = world.ribbon.get_point_at_offset(s, 0.0).origin
		var flat := Vector2(panels.poses[index].origin.x - centre.x, panels.poses[index].origin.z - centre.z)
		behind_barrier = behind_barrier and flat.length() >= WanganEnvironment.BARRIER_LATERAL_M + WanganEnvironment.BARRIER_SIZE.x * 0.5 + 0.7
	check(behind_barrier, "neo_wangan: every panel stands clear behind the concrete barrier")
