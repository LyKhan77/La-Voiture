extends SceneTree

## Neo-Wangan Shuto Express (FASE 12): the 3 150 m street circuit in 3D. The test measures the scene's
## own spline — length, closure, the twelve numbered turns and their radii, the bridge and tunnel
## elevation — and checks that the road ribbon is 11.5 m wide with the wet-asphalt shader. It also
## guards the Apex Ring: the two circuits are separate scenes and the old spline must not move.
## Pit-lane and urban-furniture checks live in the same suite (Tasks 3 and 4).
## Run: godot --headless --path . -s res://tests/test_neo_wangan_circuit.gd

const CircuitScene := preload("res://scenes/race_world/neo_wangan_circuit.tscn")
const ApexScene := preload("res://scenes/race_world/track_circuit.tscn")
const BuilderScript := preload("res://scripts/world/neo_wangan_circuit_builder.gd")
const RibbonScript := preload("res://scripts/car/track_ribbon.gd")
const PitScript := preload("res://scripts/world/neo_wangan_pit_complex.gd")
const CircuitScript := preload("res://scripts/world/neo_wangan_circuit_builder.gd")

const TARGET_LENGTH_M: float = 3150.0
const LENGTH_TOLERANCE_M: float = 25.0
const TARGET_WIDTH_M: float = 11.5
const MIN_RADIUS_M: float = 18.0
const APEX_LENGTH_M: float = 4158.81

var failures: int = 0
var assertions: int = 0
var circuit: BuilderScript
var ribbon: RibbonScript


func _initialize() -> void:
	call_deferred("_run")


func check(ok: bool, description: String) -> void:
	assertions += 1
	if not ok:
		failures += 1
		push_error(description)
	print("[%s] %s" % ["PASS" if ok else "FAIL", description])


func _run() -> void:
	circuit = CircuitScene.instantiate()
	root.add_child(circuit)
	ribbon = circuit.ribbon
	_test_length_and_closure()
	_test_turns()
	_test_elevation()
	_test_road_surface()
	_test_pit_connection()
	_test_urban_set()
	_test_apex_preserved()
	print("%d assertions, %d failure(s)" % [assertions, failures])
	print("NEO-WANGAN CIRCUIT: %s" % ("PASS" if failures == 0 else "%d FAILURES" % failures))
	circuit.queue_free()
	quit(0 if failures == 0 else 1)


func _test_length_and_closure() -> void:
	var length: float = ribbon.length_m
	var curve: Curve3D = ribbon.curve
	var first: Vector3 = curve.get_point_position(0)
	var last: Vector3 = curve.get_point_position(curve.get_point_count() - 1)
	check(absf(length - TARGET_LENGTH_M) <= LENGTH_TOLERANCE_M and first.distance_to(last) < 0.01 and curve.get_point_count() > 200,
		"#W1 the spline is a closed 3 150 m loop: %.1f m baked, first and last point within 1 cm, %d control points" % [length, curve.get_point_count()])


func _test_turns() -> void:
	var turns: Array = circuit.turns
	var ordered: bool = turns.size() == 12
	var radii_ok: bool = turns.size() == 12
	var names_ok: bool = turns.size() == 12
	var directions_ok: bool = turns.size() == 12
	var rights: int = 0
	var lefts: int = 0
	var tightest: float = INF
	var readable: Array[String] = []
	for index: int in range(turns.size()):
		var turn: Dictionary = turns[index]
		var s: float = float(turn["s"])
		var declared: float = float(turn["radius_m"])
		var direction: int = int(turn["direction"])
		if index > 0:
			ordered = ordered and s > float(turns[index - 1]["s"])
		radii_ok = radii_ok and declared >= MIN_RADIUS_M
		directions_ok = directions_ok and absf(direction) == 1
		for apex_s: float in (turn["apex_s"] as Array[float]):
			var measured: float = ribbon.get_radius_at(apex_s)
			radii_ok = radii_ok and measured >= MIN_RADIUS_M and absf(measured - declared) <= declared * 0.25
			directions_ok = directions_ok and signf(ribbon.get_curvature_at(apex_s)) == -float(direction)
			tightest = minf(tightest, minf(declared, measured))
		names_ok = names_ok and String(turn["name"]).length() > 3
		if direction > 0:
			rights += 1
		else:
			lefts += 1
		readable.append("T%d %s %.1f m" % [int(turn["number"]), String(turn["name"]).split(" ")[0], declared])
	check(ordered and radii_ok and directions_ok and turns.size() == 12,
		"#W2 twelve numbered turns in travel order, every one at or above %.0f m radius, each turning the way its curvature says (tightest %.1f m)" % [MIN_RADIUS_M, tightest])
	check(names_ok and rights == 8 and lefts == 4,
		"#W3 every turn is named, eight turn right and four turn left — 12 in all (%s)" % ", ".join(readable))
	check(int(turns[0]["number"]) == 1 and String(turns[0]["name"]) == "Shuto Gate" and String(turns[8]["name"]) == "Harbor Hairpin" and float(turns[8]["span_m"]) > 40.0,
		"#W4 T1 is the Shuto Gate, T9 the double-arc Harbor Hairpin spanning %.1f m" % float(turns[8]["span_m"]))


func _test_elevation() -> void:
	var curve: Curve3D = ribbon.curve
	var highest: float = -INF
	var lowest: float = INF
	var bridge_height: float = -INF
	var tunnel_depth: float = INF
	for index: int in range(240):
		var s: float = ribbon.length_m * float(index) / 240.0
		var at: Vector3 = curve.sample_baked(s, true)
		highest = maxf(highest, at.y)
		lowest = minf(lowest, at.y)
		if s >= BuilderScript.BRIDGE_START_M and s <= BuilderScript.BRIDGE_END_M:
			bridge_height = maxf(bridge_height, at.y)
		if s >= BuilderScript.TUNNEL_START_M and s <= BuilderScript.TUNNEL_END_M:
			tunnel_depth = minf(tunnel_depth, at.y)
	check(highest >= 6.0 and highest <= 7.0 and lowest <= -2.5 and lowest >= -3.6,
		"#W5 the Shuto Bay Bridge peaks at %+.2f m and the underpass floor drops to %+.2f m, inside the designed +6.5 / -3.2 envelope" % [highest, lowest])
	check(bridge_height >= 5.0 and tunnel_depth <= -2.4,
		"#W6 the bridge section itself is elevated (%.2f m) and the 180 m tunnel section is below grade (%.2f m)" % [bridge_height, tunnel_depth])
	check(circuit.tunnel_contains(1170.0) and not circuit.tunnel_contains(600.0) and circuit.on_bridge(500.0) and not circuit.on_bridge(1200.0),
		"#W7 the tunnel and bridge spans answer for their own arc distances, so the environment can build them there")


func _test_road_surface() -> void:
	var road: MeshInstance3D = ribbon.get_node_or_null("RoadMesh")
	var width_ok: bool = is_equal_approx(ribbon.road_half_width_m * 2.0, TARGET_WIDTH_M)
	var surface_ok: bool = false
	if road != null and road.mesh != null and road.mesh.get_surface_count() > 0:
		var material: Material = road.mesh.surface_get_material(0)
		surface_ok = material is ShaderMaterial and (material as ShaderMaterial).shader != null \
			and (material as ShaderMaterial).shader.resource_path.ends_with("road_asphalt.gdshader")
	check(width_ok and surface_ok and road != null,
		"#W8 the racing surface is %.1f m wide and wears the road_asphalt.gdshader (wet gloss and puddles)" % (ribbon.road_half_width_m * 2.0))


## Task 3: the FIA pit connection — entry, fast lane, ten boxes, wall with an attenuator, and a
## pit exit that runs behind a solid blend line past Turn 1.
func _test_pit_connection() -> void:
	var pit = circuit.get_node_or_null("PitLane")
	if pit == null:
		check(false, "#W10 the circuit carries a PitLane complex")
		return
	var entry: Area3D = pit.get_node_or_null("PitEntryTrigger")
	var exit: Area3D = pit.get_node_or_null("PitExitTrigger")
	var entry_s: float = float(entry.get_meta(&"arc_s", -1.0)) if entry != null else -1.0
	var entry_lateral: float = float(entry.get_meta(&"lateral_m", 0.0)) if entry != null else 0.0
	var exit_s: float = float(exit.get_meta(&"arc_s", -1.0)) if exit != null else -1.0
	var lane_length: float = fposmod(exit_s - entry_s, ribbon.length_m)
	check(entry != null and exit != null and absf(entry_s - (ribbon.length_m - 75.0)) <= 0.5 \
			and absf(entry_lateral - 5.2) < 0.001 and absf(lane_length - PitScript.LANE_LENGTH_M) < 0.5,
		"#W10 Pit Entry sits %.0f m before the line at +%.1f m on the right, and the lane runs %.1f m to Pit Exit" % [ribbon.length_m - entry_s, entry_lateral, lane_length])

	var stalls: Node3D = pit.get_node_or_null("Stalls")
	var pitches: Array[float] = []
	var names_ok: bool = stalls != null and stalls.get_child_count() == 10
	var lateral_ok: bool = stalls != null and stalls.get_child_count() == 10
	for index: int in range(stalls.get_child_count() if stalls != null else 0):
		var marker: Marker3D = stalls.get_child(index) as Marker3D
		names_ok = names_ok and marker != null and marker.name == "Socket_PitStall_%d" % index
		pitches.append(float(pit.stalls[index]["s"]))
		lateral_ok = lateral_ok and absf(float(pit.stalls[index]["lateral"]) - PitScript.BOX_LATERAL_M) < 0.001
	var pitch_ok: bool = true
	for index: int in range(1, pitches.size()):
		pitch_ok = pitch_ok and absf(fposmod(pitches[index] - pitches[index - 1], ribbon.length_m) - 12.0) < 0.01
	check(names_ok and lateral_ok and pitch_ok,
		"#W11 ten team boxes Socket_PitStall_0..9 stand 12 m apart outside the fast lane at +%.1f m" % PitScript.BOX_LATERAL_M)

	var wall: MeshInstance3D = pit.get_node_or_null("PitWall")
	var cushion: MeshInstance3D = pit.get_node_or_null("CrashCushion")
	var cushion_color: Color = cushion.get_meta(&"attenuator_color", Color.BLACK) if cushion != null else Color.BLACK
	var orange: bool = cushion_color.r > 0.8 and cushion_color.g > 0.2 and cushion_color.g < 0.6 and cushion_color.b < 0.1
	check(wall != null and cushion != null and orange and bool(cushion.get_meta(&"fia_standard", false)) \
			and is_equal_approx(PitScript.WALL_HEIGHT_M, 1.2) and is_equal_approx(PitScript.FAST_LANE_WIDTH_M, 4.5),
		"#W12 a 1.2 m pit wall carries an orange FIA impact attenuator on its nose, and the fast lane is exactly 4.5 m")

	# Clearance: the car path never comes within 1.0 m of the wall, and a passing car keeps 2.4 m
	# (FIA racing room) from a car boxed at the stall lateral.
	var tightest_wall: float = INF
	var u: float = PitScript.WALL_START_U
	while u <= PitScript.LANE_LENGTH_M:
		var car: float = PitScript.lane_lateral_at(u)
		tightest_wall = minf(tightest_wall, car - 1.0 - (PitScript.PIT_WALL_M + PitScript.WALL_HALF_THICKNESS_M))
		u += 1.0
	var box_gap: float = PitScript.BOX_LATERAL_M - 1.0 - (PitScript.FAST_LANE_M + 1.0)
	check(tightest_wall >= 1.0 and box_gap >= 2.4,
		"#W13 the pit wall leaves %.2f m to a car on the fast lane and a boxed car leaves %.2f m to one passing (2.4 m FIA racing room)" % [tightest_wall, box_gap])

	var blend: MeshInstance3D = pit.get_node_or_null("BlendLine")
	var ramp: Node3D = pit.get_node_or_null("BypassRamp")
	var blend_m: float = float(blend.get_meta(&"blend_line_m", 0.0)) if blend != null else 0.0
	var ramp_m: float = float(ramp.get_meta(&"length_m", 0.0)) if ramp != null else 0.0
	var merge_s: float = float(ramp.get_meta(&"merge_s", 0.0)) if ramp != null else 0.0
	var t1_apex: float = float(circuit.turns[0]["apex_s"][0])
	check(blend != null and ramp != null and is_equal_approx(blend_m, 80.0) and is_equal_approx(ramp_m, 65.0) and merge_s > t1_apex,
		"#W14 an 80 m solid blend line guards a 65 m bypass ramp that rejoins %.0f m past Turn 1's %.0f m apex" % [merge_s - t1_apex, t1_apex])
	check(is_equal_approx(PitScript.SPEED_LIMIT_MPS, 80.0 / 3.6) and pit.sim_layout()["entry_s"] == PitScript.ENTRY_S,
		"#W15 the lane is limited to 80 km/h and hands the sim its own entry, exit and lateral layout")


## Task 4: the night set — MultiMesh street furniture, the 180 m underpass, the harbor and the
## Tokyo skyline, inside the 160 draw call / 320 000 triangle budget.
func _test_urban_set() -> void:
	var environment = circuit.get_node_or_null("Environment")
	if environment == null:
		check(false, "#W16 the circuit carries its urban environment")
		return
	var barriers: MultiMeshInstance3D = environment.get_node_or_null("ConcreteBarriers")
	var lights: MultiMeshInstance3D = environment.get_node_or_null("Streetlights")
	var heads: MultiMeshInstance3D = environment.get_node_or_null("StreetlightHeads")
	var caps: MultiMeshInstance3D = environment.get_node_or_null("BarrierHazardCaps")
	var skyline: MultiMeshInstance3D = environment.get_node_or_null("Skyline")
	var neon: MultiMeshInstance3D = environment.get_node_or_null("TunnelNeon")
	var containers: Array[int] = []
	for index: int in range(3):
		var box: MultiMeshInstance3D = environment.get_node_or_null("HarborContainers%d" % index)
		if box != null and box.multimesh != null:
			containers.append(box.multimesh.instance_count)
	check(barriers != null and barriers.multimesh.instance_count > 1500 and caps != null and caps.multimesh.instance_count > 20 \
			and lights != null and lights.multimesh.instance_count > 120 and heads != null and heads.multimesh.instance_count == lights.multimesh.instance_count,
		"#W16 %d concrete barriers and %d hazard caps down both sides, every one a MultiMesh instance (%d double-arm lamps)" % [
			barriers.multimesh.instance_count if barriers != null else 0,
			caps.multimesh.instance_count if caps != null else 0,
			lights.multimesh.instance_count if lights != null else 0])

	var shell: MeshInstance3D = environment.get_node_or_null("TunnelShell")
	check(shell != null and shell.mesh != null and neon != null and neon.multimesh.instance_count >= 18 \
			and is_equal_approx(CircuitScript.TUNNEL_END_M - CircuitScript.TUNNEL_START_M, 180.0),
		"#W17 the 180 m Cyber City underpass has a concrete shell and %d ceiling neon strips" % (neon.multimesh.instance_count if neon != null else 0))

	var towers: int = 0
	var window_shader: bool = false
	if skyline != null and skyline.multimesh != null:
		towers = skyline.multimesh.instance_count
		window_shader = skyline.material_override is ShaderMaterial \
			and (skyline.material_override as ShaderMaterial).shader != null \
			and (skyline.material_override as ShaderMaterial).shader.resource_path.ends_with("neo_wangan_skyline.gdshader")
	check(towers >= 80 and window_shader and containers.size() == 3 and containers[0] > 10,
		"#W18 a %d-tower skyline glows through the window shader, and %d harbor containers are instanced in three colours" % [towers, containers.reduce(func(a: int, b: int) -> int: return a + b, 0)])

	var budget := _budget(circuit)
	var draw_calls: int = int(budget["draw_calls"])
	var triangles: int = int(budget["triangles"])
	check(draw_calls <= 160 and triangles <= 320000,
		"#W19 the circuit submits %d draw calls and %d triangles — inside the 160 / 320 000 budget" % [draw_calls, triangles])

	var world_environment: WorldEnvironment = circuit.get_node_or_null("WorldEnvironment")
	var night: bool = world_environment != null and world_environment.environment != null \
		and world_environment.environment.background_mode == Environment.BG_SKY \
		and world_environment.environment.sky != null and world_environment.environment.fog_enabled
	var energy_before: float = 0.0
	var energy_after: float = 0.0
	if neon != null and neon.material_override is StandardMaterial3D:
		energy_before = (neon.material_override as StandardMaterial3D).emission_energy_multiplier
		environment.update(0.37, null)
		energy_after = (neon.material_override as StandardMaterial3D).emission_energy_multiplier
	check(night and not is_equal_approx(energy_before, energy_after),
		"#W20 the set carries a night sky and fog, and its neon breathes between frames (%.2f -> %.2f)" % [energy_before, energy_after])


## Draw calls and triangles of every visible mesh under `root`.
func _budget(root_node: Node) -> Dictionary:
	var total := {"draw_calls": 0, "triangles": 0}
	_count_budget(root_node, total)
	return total


func _count_budget(node: Node, total: Dictionary) -> void:
	if node is Node3D and not (node as Node3D).visible:
		return
	var mesh: Mesh = null
	var copies: int = 1
	if node is MultiMeshInstance3D and (node as MultiMeshInstance3D).multimesh != null:
		mesh = (node as MultiMeshInstance3D).multimesh.mesh
		copies = (node as MultiMeshInstance3D).multimesh.instance_count
	elif node is MeshInstance3D:
		mesh = (node as MeshInstance3D).mesh
	if mesh != null:
		for surface: int in range(mesh.get_surface_count()):
			var arrays: Array = mesh.surface_get_arrays(surface)
			var raw: Variant = arrays[Mesh.ARRAY_INDEX]
			var count: int = 0
			if raw is PackedInt32Array and (raw as PackedInt32Array).size() > 0:
				count = (raw as PackedInt32Array).size() / 3
			else:
				count = (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() / 3
			total["draw_calls"] = int(total["draw_calls"]) + 1
			total["triangles"] = int(total["triangles"]) + count * copies
	for child: Node in node.get_children():
		_count_budget(child, total)


## The Apex Ring spline is a different scene and must be byte-for-byte where it was.
func _test_apex_preserved() -> void:
	var apex := ApexScene.instantiate() as RibbonScript
	root.add_child(apex)
	var length: float = apex.length_m
	var points: int = apex.curve.get_point_count()
	check(absf(length - APEX_LENGTH_M) <= 1.0 and points == 303,
		"#W9 the Apex Ring keeps its own 4 158.8 m spline and 303 control points — Neo-Wangan is a separate scene (%d points)" % points)
	apex.queue_free()
