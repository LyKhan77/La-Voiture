extends SceneTree

## Generates scenes/race_world/circuits/apex_ring/apex_circuit.tscn: a closed ~4.2 km test circuit.
## Run: Godot --headless --path . --script res://tools/build_track_circuit.gd
##
## The layout is a turtle path (straights + constant-radius arcs, start heading
## east). Straights "A" and "B" are solved so the loop closes exactly. The path
## is written as a Catmull-Rom-equivalent Bezier through points sampled on it.

const OUTPUT_PATH := "res://scenes/race_world/circuits/apex_ring/apex_circuit.tscn"
const RibbonScript := preload("res://scripts/car/track_ribbon.gd")

## ["S", length_m] straight | ["L"/"R", radius_m, angle_deg] arc.
const SEGMENTS: Array = [
	["S", 1150.0],
	["L", 60.0, 90.0],
	["S", 400.0],
	["R", 45.0, 70.0],
	["L", 90.0, 100.0],
	["S", "A"],
	["L", 35.0, 160.0],
	["S", 400.0],
	["R", 70.0, 100.0],
	["S", 150.0],
	["L", 50.0, 40.0],
	["R", 50.0, 40.0],
	["S", "B"],
	["L", 80.0, 90.0],
	["S", 150.0],
	["L", 60.0, 90.0],
]
const STRAIGHT_POINT_SPACING_M := 20.0
const ARC_POINT_SPACING_DEG := 6.0


func _initialize() -> void:
	var a_idx: int = SEGMENTS.find(["S", "A"])
	var b_idx: int = SEGMENTS.find(["S", "B"])
	var open_walk: Dictionary = _walk(0.0, 0.0, a_idx, b_idx)
	var end: Vector2 = open_walk.end
	var ua: Vector2 = open_walk.dir_a
	var ub: Vector2 = open_walk.dir_b
	# end + A*ua + B*ub = 0 closes the loop.
	var det: float = ua.x * ub.y - ua.y * ub.x
	var a_len: float = (-end.x * ub.y + end.y * ub.x) / det
	var b_len: float = (-ua.x * end.y + ua.y * end.x) / det
	var walk: Dictionary = _walk(a_len, b_len, a_idx, b_idx)
	print("straight A=%.1f m, B=%.1f m, length=%.1f m, closure error=%.5f m" % [
		a_len, b_len, walk.length, (walk.end as Vector2).length()
	])
	_save_scene(walk.points)
	quit()


func _walk(a_len: float, b_len: float, a_idx: int, b_idx: int) -> Dictionary:
	var p := Vector2.ZERO
	var heading: float = 0.0
	var points: PackedVector2Array = PackedVector2Array([p])
	var length: float = 0.0
	var dir_a := Vector2.ZERO
	var dir_b := Vector2.ZERO
	for i: int in range(SEGMENTS.size()):
		var seg: Array = SEGMENTS[i]
		if seg[0] == "S":
			var l: float = a_len if i == a_idx else (b_len if i == b_idx else float(seg[1]))
			var dir := Vector2(cos(heading), sin(heading))
			if i == a_idx:
				dir_a = dir
			if i == b_idx:
				dir_b = dir
			var n: int = maxi(1, ceili(absf(l) / STRAIGHT_POINT_SPACING_M))
			for k: int in range(1, n + 1):
				points.append(p + dir * l * float(k) / float(n))
			p += dir * l
			length += absf(l)
		else:
			var radius: float = seg[1]
			var turn: float = deg_to_rad(float(seg[2])) * (1.0 if seg[0] == "L" else -1.0)
			var turn_sign: float = signf(turn)
			var center: Vector2 = p + Vector2(-sin(heading), cos(heading)) * radius * turn_sign
			var n: int = maxi(2, ceili(absf(rad_to_deg(turn)) / ARC_POINT_SPACING_DEG))
			for k: int in range(1, n + 1):
				var t: float = heading + turn * float(k) / float(n)
				points.append(center + Vector2(sin(t), -cos(t)) * radius * turn_sign)
			p = points[points.size() - 1]
			heading += turn
			length += absf(turn) * radius
	return {"end": p, "length": length, "points": points, "dir_a": dir_a, "dir_b": dir_b}


func _save_scene(points: PackedVector2Array) -> void:
	# Last point repeats the first: the ribbon needs a closed curve.
	var count: int = points.size() - 1
	var curve := Curve3D.new()
	for i: int in range(count + 1):
		var prev: Vector2 = points[posmod(i - 1, count)]
		var next: Vector2 = points[posmod(i + 1, count)]
		var handle: Vector2 = (next - prev) / 6.0
		# 2D (x, y) with y pointing north maps to 3D (x, 0, -y).
		curve.add_point(
			_to_3d(points[i % count]), -_to_3d(handle), _to_3d(handle)
		)

	var bounds := Rect2(points[0], Vector2.ZERO)
	for p: Vector2 in points:
		bounds = bounds.expand(p)
	var center: Vector2 = bounds.get_center()

	var root := Path3D.new()
	root.name = "TrackCircuit"
	root.curve = curve
	root.set_script(RibbonScript)

	var road := MeshInstance3D.new()
	road.name = "RoadMesh"
	root.add_child(road)
	road.owner = root

	var ground_mesh := PlaneMesh.new()
	ground_mesh.size = Vector2(3200.0, 3200.0)
	var ground_material := StandardMaterial3D.new()
	ground_material.albedo_color = Color("#0E1118")
	ground_material.roughness = 1.0
	ground_mesh.material = ground_material
	var ground := MeshInstance3D.new()
	ground.name = "Ground"
	ground.mesh = ground_mesh
	ground.position = _to_3d(center) + Vector3(0.0, -0.1, 0.0)
	root.add_child(ground)
	ground.owner = root

	var packed := PackedScene.new()
	var err: int = packed.pack(root)
	if err == OK:
		err = ResourceSaver.save(packed, OUTPUT_PATH)
	print("saved %s -> %s" % [OUTPUT_PATH, error_string(err)])


func _to_3d(v: Vector2) -> Vector3:
	return Vector3(v.x, 0.0, -v.y)
