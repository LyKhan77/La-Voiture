extends SceneTree

## The mesh-level terrain gate for Monte Azure (Guide section 3, step 2.3): the ground that is actually rendered must lie
## under every road sample, under the pit lane and its apron, the harbour must be water beyond the quay, and the strip zones
## must follow the nearest road leg instead of a band projected across another leg (the Brianza "grass over the track" defect).
## Run: godot --headless --path . -s res://tests/test_monte_azure_terrain_gate.gd

const ScenePath := "res://scenes/race_world/circuits/monte_azure/monte_azure_circuit.tscn"
const ZonesPath := "res://scripts/world/circuits/monte_azure/monte_azure_zones.gd"
const CELL_M: float = 24.0
## The road runs through the cliff tunnel here; the hill above it is the tunnel's roof, not a floating road.
const TUNNEL_S0: float = 1250.0
const TUNNEL_S1: float = 1410.0

var failures: int = 0


func check(ok: bool, description: String) -> void:
	if not ok:
		failures += 1
		push_error(description)
	print("[%s] %s" % ["PASS" if ok else "FAIL", description])


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var zones := load(ZonesPath) as Script
	check(zones != null, "#G0 MonteAzureZones exists")
	var scene := load(ScenePath) as PackedScene
	if zones == null or scene == null:
		_finish()
		return
	var circuit := scene.instantiate() as Node3D
	root.add_child(circuit)
	await process_frame
	var ribbon = circuit.get("ribbon")
	var env = circuit.get_node_or_null("Environment")
	var terrain := env.get_node_or_null("Terrain") as MeshInstance3D if env != null else null
	check(terrain != null and terrain.mesh != null, "#G1 the environment renders a Terrain mesh")
	if terrain == null or terrain.mesh == null:
		circuit.queue_free()
		_finish()
		return
	var triangles: int = terrain.mesh.get_faces().size() / 3
	check(triangles > 5000 and triangles <= 60000, "#G2 the terrain costs 5k..60k triangles (got %d)" % triangles)

	# The rendered side: back faces are culled, so a terrain wound clockwise from above would be invisible.
	var normals: PackedVector3Array = terrain.mesh.surface_get_arrays(0)[Mesh.ARRAY_NORMAL]
	var facing_up: int = 0
	for normal: Vector3 in normals:
		facing_up += 1 if normal.y > 0.0 else 0
	check(normals.size() > 0 and float(facing_up) / float(normals.size()) > 0.95, "#G14 the terrain faces up (%d of %d vertex normals)" % [facing_up, normals.size()])

	# Every road sample: left edge, centre, right edge, every 6 m.
	var road_points: Array[Vector3] = []
	var road_s: Array[float] = []
	var s: float = 0.0
	while s < ribbon.length_m:
		for lateral: float in [-5.5, 0.0, 5.5]:
			road_points.append(ribbon.get_point_at_offset(s, lateral).origin)
			road_s.append(s)
		s += 6.0
	var tops: PackedFloat32Array = _ground_tops(terrain, road_points)
	var buried: int = 0
	var floating: int = 0
	var uncovered: int = 0
	var worst_gap: float = 0.0
	for index: int in range(road_points.size()):
		if road_s[index] >= TUNNEL_S0 and road_s[index] <= TUNNEL_S1:
			continue
		if tops[index] == -INF:
			uncovered += 1
			continue
		var gap: float = road_points[index].y - tops[index]
		worst_gap = maxf(worst_gap, gap)
		buried += 1 if gap < 0.04 else 0
		floating += 1 if gap > 3.0 else 0
	check(uncovered == 0, "#G3 terrain covers every road sample (%d uncovered of %d)" % [uncovered, road_points.size()])
	check(buried == 0, "#G4 the ground is under the road at every sample (%d buried)" % buried)
	check(floating == 0, "#G5 no road floats more than 3 m above the ground (worst gap %.2f m, %d floating)" % [worst_gap, floating])

	# The pit lane, its apron and the paddock deck behind the boxes.
	var pit = circuit.get_node("PitLane")
	var pit_points: Array[Vector3] = []
	var u: float = 0.0
	while u < 320.0:
		for lateral: float in [8.5, 13.0, 16.0, 20.0, 25.0]:
			pit_points.append(pit.get_pit_transform(u, lateral).origin)
		u += 6.0
	var pit_tops: PackedFloat32Array = _ground_tops(terrain, pit_points)
	var pit_buried: int = 0
	var pit_floating: int = 0
	for index: int in range(pit_points.size()):
		if pit_tops[index] == -INF:
			pit_floating += 1
			continue
		var gap: float = pit_points[index].y - pit_tops[index]
		pit_buried += 1 if gap < 0.04 else 0
		pit_floating += 1 if gap > 1.0 else 0
	check(pit_buried == 0 and pit_floating == 0, "#G6 the pit lane, boxes and garage floors stand on a deck 0.04..1.0 m below them (%d buried, %d floating)" % [pit_buried, pit_floating])

	# The harbour: quay on the grandstand side, water beyond it.
	var quay: float = env.ground_y_at(ribbon.get_point_at_offset(100.0, -40.0).origin)
	var water: float = env.ground_y_at(ribbon.get_point_at_offset(100.0, -140.0).origin)
	var quay_road: float = ribbon.get_point_at_offset(100.0, 0.0).origin.y
	check(quay > 0.1 and quay < quay_road + 0.2 and water < -2.0, "#G7 40 m left of the start line is quay (%.2f m), 140 m left is open water (%.2f m)" % [quay, water])
	var land_right: float = env.ground_y_at(ribbon.get_point_at_offset(1500.0, 120.0).origin)
	check(land_right > 0.0, "#G8 the inside of the loop is land (%.2f m)" % land_right)

	# ground_y_at() answers from the rendered mesh.
	var sample_points: Array[Vector3] = []
	var probe: float = 20.0
	while probe < ribbon.length_m:
		for lateral: float in [-60.0, -25.0, 25.0, 60.0]:
			sample_points.append(ribbon.get_point_at_offset(probe, lateral).origin)
		probe += 97.0
	var sample_tops: PackedFloat32Array = _ground_tops(terrain, sample_points)
	var mismatched: int = 0
	var compared: int = 0
	for index: int in range(sample_points.size()):
		if sample_tops[index] == -INF:
			continue
		compared += 1
		mismatched += 1 if absf(float(env.ground_y_at(sample_points[index])) - sample_tops[index]) > 0.35 else 0
	check(compared > 40 and mismatched == 0, "#G9 ground_y_at agrees with the rendered mesh within 0.35 m (%d of %d points differ)" % [mismatched, compared])

	# Zones follow the nearest road leg. The strip's R band "urban 240-680, 300 m deep" reaches the climb past the casino
	# (road s 809-1026) when projected across the loop; here that stretch of road is forest, as the strip says for s=680..1200.
	check(String(zones.call("zone_at", 900.0, 1.0)) == "forest" and String(zones.call("zone_at", 500.0, 1.0)) == "urban", "#G10 R zones: s=500 urban, s=900 forest")
	check(String(zones.call("zone_at", 100.0, -1.0)) == "water" and String(zones.call("zone_at", 800.0, -1.0)) == "urban", "#G11 L zones: s=100 water, s=800 urban")
	check(String(zones.call("zone_at", 100.0, 1.0)) == "paddock", "#G12 the pit side before s=240 is paddock (no strip band covers it)")
	var nearest_ok: bool = true
	for probe_s: float in [850.0, 950.0, 1000.0]:
		var on_climb: Vector3 = ribbon.get_point_at_offset(probe_s, 40.0).origin
		nearest_ok = nearest_ok and String(env.zone_at_point(on_climb)) == "forest"
	check(nearest_ok, "#G13 points beside the casino climb take the climb's own zone, not the start straight's band")

	circuit.queue_free()
	await process_frame
	_finish()


## The highest triangle of `terrain` under each point, or -INF where the mesh does not cover it.
func _ground_tops(terrain: MeshInstance3D, points: Array[Vector3]) -> PackedFloat32Array:
	var cells: Dictionary = {}
	for index: int in range(points.size()):
		var key := Vector2i(floori(points[index].x / CELL_M), floori(points[index].z / CELL_M))
		if not cells.has(key):
			cells[key] = []
		(cells[key] as Array).append(index)
	var tops := PackedFloat32Array()
	tops.resize(points.size())
	tops.fill(-INF)
	var faces: PackedVector3Array = terrain.mesh.get_faces()
	for i: int in range(0, faces.size(), 3):
		var a: Vector3 = terrain.global_transform * faces[i]
		var b: Vector3 = terrain.global_transform * faces[i + 1]
		var c: Vector3 = terrain.global_transform * faces[i + 2]
		var a2 := Vector2(a.x, a.z)
		var b2 := Vector2(b.x, b.z)
		var c2 := Vector2(c.x, c.z)
		var denominator: float = (b2 - a2).cross(c2 - a2)
		if absf(denominator) < 0.00001:
			continue
		var min_x: int = floori(minf(a.x, minf(b.x, c.x)) / CELL_M)
		var max_x: int = floori(maxf(a.x, maxf(b.x, c.x)) / CELL_M)
		var min_z: int = floori(minf(a.z, minf(b.z, c.z)) / CELL_M)
		var max_z: int = floori(maxf(a.z, maxf(b.z, c.z)) / CELL_M)
		for x: int in range(min_x, max_x + 1):
			for z: int in range(min_z, max_z + 1):
				var key := Vector2i(x, z)
				if not cells.has(key):
					continue
				for index: int in cells[key]:
					var p := Vector2(points[index].x, points[index].z)
					var u: float = (p - a2).cross(c2 - a2) / denominator
					var v: float = (b2 - a2).cross(p - a2) / denominator
					if u >= -0.00001 and v >= -0.00001 and u + v <= 1.00001:
						tops[index] = maxf(tops[index], a.y + u * (b.y - a.y) + v * (c.y - a.y))
	return tops


func _finish() -> void:
	print("MONTE AZURE TERRAIN GATE: %s" % ("PASS" if failures == 0 else "%d FAILURES" % failures))
	quit(0 if failures == 0 else 1)
