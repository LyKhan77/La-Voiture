extends SceneTree

## The mesh-level terrain gate for Ardennes (Guide section 3, step 2.3): the ground that is actually rendered must lie under
## every road sample (0 floating road, 0 hill above the asphalt), under the pit lane, the paddock deck and both grandstands, the
## river must be water in a carved valley, and the strip zones must follow the nearest road leg instead of a band projected across
## another leg (the Brianza "grass over the track" defect).
## Run: godot --headless --path . -s res://tests/test_ardennes_terrain_gate.gd

const ScenePath := "res://scenes/race_world/circuits/ardennes/ardennes_circuit.tscn"
const ZonesPath := "res://scripts/world/circuits/ardennes/ardennes_zones.gd"
const CELL_M: float = 24.0

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
	check(zones != null, "#G0 ArdennesZones exists")
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
	check(triangles > 20000 and triangles <= 70000, "#G2 the terrain costs 20k..70k triangles (got %d)" % triangles)

	# The rendered side: back faces are culled, so a terrain wound clockwise from above would be invisible.
	var normals: PackedVector3Array = terrain.mesh.surface_get_arrays(0)[Mesh.ARRAY_NORMAL]
	var facing_up: int = 0
	for normal: Vector3 in normals:
		facing_up += 1 if normal.y > 0.0 else 0
	check(normals.size() > 0 and float(facing_up) / float(normals.size()) > 0.95, "#G14 the terrain faces up (%d of %d vertex normals)" % [facing_up, normals.size()])

	# Every road sample: left edge, centre, right edge, every 6 m, along the whole 104 m climb.
	var road_points: Array[Vector3] = []
	var s: float = 0.0
	while s < ribbon.length_m:
		for lateral: float in [-7.0, 0.0, 7.0]:
			road_points.append(ribbon.get_point_at_offset(s, lateral).origin)
		s += 6.0
	var tops: PackedFloat32Array = _ground_tops(terrain, road_points)
	var buried: int = 0
	var floating: int = 0
	var uncovered: int = 0
	var worst_gap: float = 0.0
	for index: int in range(road_points.size()):
		if tops[index] == -INF:
			uncovered += 1
			continue
		var gap: float = road_points[index].y - tops[index]
		worst_gap = maxf(worst_gap, gap)
		buried += 1 if gap < 0.04 else 0
		floating += 1 if gap > 1.0 else 0
	check(uncovered == 0, "#G3 terrain covers every road sample (%d uncovered of %d)" % [uncovered, road_points.size()])
	check(buried == 0, "#G4 the ground is under the road at every sample: no hill above the asphalt (%d buried)" % buried)
	check(floating == 0, "#G5 no road floats more than 1 m above the ground: the bed is 0.16 m under the asphalt (worst gap %.2f m, %d floating)" % [worst_gap, floating])

	# The pit lane, its apron and the paddock deck behind the boxes.
	var pit = circuit.get_node("PitLane")
	var pit_points: Array[Vector3] = []
	var u: float = 0.0
	while u < 420.0:
		for lateral: float in [8.6, 13.0, 17.0, 20.6, 30.0, 46.0, 60.0, 90.0]:
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
	check(pit_buried == 0 and pit_floating == 0, "#G6 the pit lane, boxes, garage floors and the paddock deck stand on ground 0.04..1.0 m below them (%d buried, %d floating)" % [pit_buried, pit_floating])

	# Both grandstands stand in a flat cut: the terrain under the main stand (s=125) and the glass terrace (s=5280).
	var stand_buried: int = 0
	var stand_floating: int = 0
	var stand_points: Array[Vector3] = []
	for stand_s: float in [125.0, 5280.0]:
		for along: float in [-90.0, -45.0, 0.0, 45.0, 90.0]:
			for lateral: float in [-25.0, -35.0, -45.0, -55.0]:
				stand_points.append(ribbon.get_point_at_offset(stand_s + along, lateral).origin)
	var stand_tops: PackedFloat32Array = _ground_tops(terrain, stand_points)
	for index: int in range(stand_points.size()):
		if stand_tops[index] == -INF:
			stand_floating += 1
			continue
		var gap: float = stand_points[index].y - stand_tops[index]
		stand_buried += 1 if gap < 0.04 else 0
		stand_floating += 1 if gap > 1.0 else 0
	check(stand_buried == 0 and stand_floating == 0, "#G6b the ground under both grandstands is cut flat to the road's bed (%d buried, %d floating)" % [stand_buried, stand_floating])

	# The river: carved below the water level beside the climb, dry land well outside it.
	var river: float = env.ground_y_at(ribbon.get_point_at_offset(690.0, -130.0).origin)
	var bank: float = env.ground_y_at(ribbon.get_point_at_offset(690.0, -30.0).origin)
	var water_level: float = float(env.terrain.water_level)
	check(river < water_level - 2.0 and bank > water_level, "#G7 the river valley is carved (bed %.1f m at 130 m left, water %.1f m, bank %.1f m at 30 m left)" % [river, water_level, bank])
	var summit: float = env.ground_y_at(ribbon.get_point_at_offset(1800.0, 0.0).origin)
	check(summit >= 103.0 and summit <= 104.5, "#G8 the summit road bed is at 104 m less the bed (%.2f m)" % summit)

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
	check(compared > 150 and mismatched == 0, "#G9 ground_y_at agrees with the rendered mesh within 0.35 m (%d of %d points differ)" % [mismatched, compared])

	# Zones follow the nearest road leg (the strip's bands are never read as rectangles across the loop).
	check(String(zones.call("zone_at", 100.0, 1.0)) == "paddock" and String(zones.call("zone_at", 100.0, -1.0)) == "urban", "#G10 the start straight: paddock on the pit side, urban on the stand side")
	check(String(zones.call("zone_at", 600.0, -1.0)) == "water" and String(zones.call("zone_at", 700.0, 1.0)) == "rock" and String(zones.call("zone_at", 1500.0, 1.0)) == "forest", "#G11 the climb: river left, rock face right at s=700, forest right at s=1500")
	check(String(zones.call("zone_at", 2000.0, 1.0)) == "rock" and String(zones.call("zone_at", 3000.0, 1.0)) == "forest" and String(zones.call("zone_at", 5100.0, 1.0)) == "paddock", "#G12 the descent: rock right at s=2000, forest right at s=3000, paddock right at s=5100")
	var nearest_ok: bool = true
	for probe_s: float in [4060.0, 3460.0]:
		var beside: Vector3 = ribbon.get_point_at_offset(probe_s, -40.0).origin
		nearest_ok = nearest_ok and String(env.zone_at_point(beside)) == "forest"
	var near_pit: Vector3 = ribbon.get_point_at_offset(60.0, 60.0).origin
	nearest_ok = nearest_ok and String(env.zone_at_point(near_pit)) == "paddock"
	check(nearest_ok, "#G13 points beside the western arm (s 3460, 4060) take their own leg's forest zone, and the pit side takes the paddock")

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
	print("ARDENNES TERRAIN GATE: %s" % ("PASS" if failures == 0 else "%d FAILURES" % failures))
	quit(0 if failures == 0 else 1)
