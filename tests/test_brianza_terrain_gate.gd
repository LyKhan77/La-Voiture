extends SceneTree

const CELL_M: float = 24.0
const Geometry := preload("res://scripts/world/shared/enhanced_track_geometry.gd")

func ground_clearance(circuit: Node, sample_kind: int = 0) -> float:
	var points: Array[Vector3] = []
	var cells: Dictionary = {}
	var lap: float = circuit.ribbon.length_m
	var pit: Node = circuit.get_node("PitLane")
	var start: int = int(pit.paddock.zone.s0) if sample_kind == 2 else 0
	var end: int = int(pit.paddock.zone.s1) if sample_kind == 2 else (410 if sample_kind == 1 else int(lap))
	var laterals: Array[float] = [-7.0, 0.0, 7.0]
	if sample_kind == 1:
		laterals = [8.0, 14.0, 20.0]
	elif sample_kind == 2:
		laterals = []
		for depth: int in range(32, int(pit.paddock.zone.lateral_to), 6):
			laterals.append(float(depth))
	for s: int in range(start, end, 6):
		for lateral: float in laterals:
			var p: Vector3 = pit.get_pit_transform(float(s), lateral).origin if sample_kind == 1 else circuit.ribbon.get_point_at_offset(float(s), lateral).origin
			var key := Vector2i(floori(p.x / CELL_M), floori(p.z / CELL_M))
			if not cells.has(key):
				cells[key] = []
			cells[key].append(points.size())
			points.append(p)
	var tops := PackedFloat32Array()
	tops.resize(points.size())
	tops.fill(-INF)
	for child: Node in circuit.get_node("Environment/ParcoRealeGroundRoot").get_children():
		if not child is MeshInstance3D:
			continue
		var instance: MeshInstance3D = child
		var faces: PackedVector3Array = instance.mesh.get_faces()
		for i: int in range(0, faces.size(), 3):
			var a: Vector3 = instance.transform * faces[i]
			var b: Vector3 = instance.transform * faces[i + 1]
			var c: Vector3 = instance.transform * faces[i + 2]
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
	var worst: float = -INF
	for index: int in range(points.size()):
		worst = maxf(worst, tops[index] - points[index].y)
	return worst

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var scene: PackedScene = load("res://scenes/race_world/brianza_circuit.tscn")
	var circuit: Node = scene.instantiate()
	root.add_child(circuit)
	await process_frame
	var point: Vector3 = circuit.ribbon.get_point_at_offset(3860.0, 0.0).origin
	var top: float = -INF
	var ground: Node = circuit.get_node("Environment/ParcoRealeGroundRoot")
	var surfaces: int = 0
	for child: Node in ground.get_children():
		if child is MeshInstance3D and child.mesh != null:
			surfaces += child.mesh.get_surface_count()
	var budget_ok: bool = surfaces <= 6
	print("[%s] ground platforms share the verge draw call (%d surfaces)" % ["PASS" if budget_ok else "FAIL", surfaces])
	for child: Node in ground.get_children():
		if not child is MeshInstance3D:
			continue
		var instance: MeshInstance3D = child
		var faces: PackedVector3Array = instance.mesh.get_faces()
		for i: int in range(0, faces.size(), 3):
			var a: Vector3 = instance.transform * faces[i]
			var b: Vector3 = instance.transform * faces[i + 1]
			var c: Vector3 = instance.transform * faces[i + 2]
			var p := Vector2(point.x, point.z)
			var a2 := Vector2(a.x, a.z)
			var b2 := Vector2(b.x, b.z)
			var c2 := Vector2(c.x, c.z)
			var denominator: float = (b2 - a2).cross(c2 - a2)
			if absf(denominator) < 0.00001:
				continue
			var u: float = (p - a2).cross(c2 - a2) / denominator
			var v: float = (b2 - a2).cross(p - a2) / denominator
			if u < -0.00001 or v < -0.00001 or u + v > 1.00001:
				continue
			top = maxf(top, a.y + u * (b.y - a.y) + v * (c.y - a.y))
	var road_point_ok: bool = top <= point.y - 0.05
	print("[%s] rendered ground below road at s=3860 (ground %.2f, road %.2f)" % ["PASS" if road_point_ok else "FAIL", top, point.y])
	var ok: bool = road_point_ok and budget_ok
	var worst: float = ground_clearance(circuit)
	var road_ok: bool = worst <= -0.05
	print("[%s] rendered ground below every road sample (worst %.3f m)" % ["PASS" if road_ok else "FAIL", worst])
	ok = ok and road_ok
	var pit_worst: float = ground_clearance(circuit, 1)
	var pit_ok: bool = pit_worst <= -0.005
	print("[%s] rendered ground below pit lane samples (worst %.3f m)" % ["PASS" if pit_ok else "FAIL", pit_worst])
	ok = ok and pit_ok
	var apron_worst: float = ground_clearance(circuit, 2)
	var apron_ok: bool = apron_worst <= -0.005
	print("[%s] rendered ground below paddock apron samples (worst %.3f m)" % ["PASS" if apron_ok else "FAIL", apron_worst])
	ok = ok and apron_ok
	var sample_cells: Dictionary = Geometry.hash_samples(circuit.ribbon)
	var hits: int = 0
	var verge_node: MeshInstance3D = circuit.get_node("Environment/ParcoRealeGroundRoot/ParcoRealeVerge")
	var verge_faces: PackedVector3Array = verge_node.mesh.get_faces()
	var rows: int = ceili(circuit.ribbon.length_m / 10.0)
	for index: int in range(mini(verge_faces.size(), rows * 24)):
		var row: int = int(index / 12) % rows
		var arc: float = float(row) * 10.0
		var verge_point: Vector3 = verge_node.transform * verge_faces[index]
		if Geometry.other_road_distance(sample_cells, circuit.ribbon, arc, verge_point) < 8.0:
			hits += 1
	var verge_ok: bool = hits == 0
	print("[%s] verge stays outside other road corridors (%d hits)" % ["PASS" if verge_ok else "FAIL", hits])
	ok = ok and verge_ok
	var env: Node = circuit.get_node("Environment")
	var tone_ok: bool = env.has_method("field_tone_index")
	if tone_ok:
		var equal: int = 0
		var total: int = 0
		for row: int in range(30):
			for col: int in range(30):
				equal += int(env.field_tone_index(col, row) == env.field_tone_index(col + 1, row))
				equal += int(env.field_tone_index(col, row) == env.field_tone_index(col, row + 1))
				total += 2
		tone_ok = float(equal) / float(total) >= 0.70
	print("[%s] grass forms broad tone patches" % ("PASS" if tone_ok else "FAIL"))
	ok = ok and tone_ok
	var pit: Node = circuit.get_node("PitLane")
	var platform_ok: bool = pit.has_method("ground_platforms")
	if platform_ok:
		var platform: Dictionary = pit.ground_platforms()[0]
		var middle: float = (float(platform.s0) + float(platform.s1)) * 0.5
		var inside: Vector3 = circuit.ribbon.get_point_at_offset(middle, 14.0).origin
		platform_ok = absf(env.ground_y_at(inside) - (inside.y + float(platform.y_offset))) <= 0.01
		var outer_platform: Dictionary = pit.ground_platforms()[-1]
		var skirt_depth: float = float(outer_platform.lateral_to) + float(outer_platform.skirt_m) * 0.5
		var skirt: Vector3 = circuit.ribbon.get_point_at_offset(middle, skirt_depth).origin
		var skirt_y: float = env.ground_y_at(skirt) - skirt.y
		platform_ok = platform_ok and skirt_y < float(platform.y_offset) and skirt_y > env._verge_drop(float(outer_platform.lateral_to) + float(outer_platform.skirt_m))
	print("[%s] pit ground supports the platform" % ("PASS" if platform_ok else "FAIL"))
	ok = ok and platform_ok
	circuit.free()
	quit(0 if ok else 1)
