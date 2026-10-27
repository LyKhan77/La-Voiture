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


## The Apex Ring spline is a different scene and must be byte-for-byte where it was.
func _test_apex_preserved() -> void:
	var apex := ApexScene.instantiate() as RibbonScript
	root.add_child(apex)
	var length: float = apex.length_m
	var points: int = apex.curve.get_point_count()
	check(absf(length - APEX_LENGTH_M) <= 1.0 and points == 303,
		"#W9 the Apex Ring keeps its own 4 158.8 m spline and 303 control points — Neo-Wangan is a separate scene (%d points)" % points)
	apex.queue_free()
