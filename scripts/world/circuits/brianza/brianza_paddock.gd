class_name BrianzaPaddock
extends Node3D

const Batch := preload("res://scripts/world/shared/mesh_batch.gd")
const Toon := preload("res://scripts/world/shared/toon_materials.gd")
const Geo := preload("res://scripts/world/shared/enhanced_track_geometry.gd")
const Liveries := preload("res://scripts/car/team_liveries.gd")
const TransportersKit := preload("res://scripts/world/paddock/team_transporters.gd")

var zone: Dictionary = {}
var platform: Dictionary = {}
var transporters: Node3D
var transporter_poses: Array[Dictionary] = []
var tent_poses: Array[Transform3D] = []
var fence_poses: Array[Transform3D] = []
var parking_poses: Array[Transform3D] = []
var gate_pose: Transform3D
var _footprints: Array[Rect2] = []
var _built: bool = false

func footprints() -> Array[Rect2]:
	return _footprints

func build(ribbon: Node3D, pit: Node3D, _team_ids: Array[int] = []) -> void:
	if _built:
		transporters.apply_teams(pit.stalls)
		return
	_built = true
	var start: float = float(pit.stalls[0]["s"]) - 30.0
	var end: float = float(pit.stalls[-1]["s"]) + 30.0
	var cells: Dictionary = Geo.hash_samples(ribbon)
	var outer: float = 95.0
	var sample: float = start
	while sample <= end:
		outer = minf(outer, ribbon.road_half_width_m + Geo.max_extent(cells, ribbon, sample, 1.0, 88.0))
		sample += 8.0
	zone = {"s0": start, "s1": end, "lateral_from": 32.0, "lateral_to": outer}
	platform = {"s0": start, "s1": end, "side": 1.0, "lateral_from": 31.0, "lateral_to": outer, "y_offset": -0.03, "skirt_m": 6.0}
	var mat: Material = Toon.vertex_colored(false)
	var apron := Batch.new()
	var road := Batch.new()
	var gate := Batch.new()
	var props := Batch.new()
	var fence_mesh := Batch.new()
	var tent_mesh := Batch.new()
	var car_mesh := Batch.new()
	var white := Color("#f1eee7")
	var red := Color("#d9232e")
	var dark := Color("#30363d")
	var step_count: int = ceili((end - start) / 8.0)
	for i: int in range(step_count):
		var a: float = lerpf(start, end, float(i) / step_count)
		var b: float = lerpf(start, end, float(i + 1) / step_count)
		for entry: Array in [[apron, 32.0, outer, Color("#aaa9a3"), -0.01], [road, 34.0, 40.0, dark, 0.01]]:
			var pts: Array[Vector3] = []
			for q: Vector2 in [Vector2(a, entry[1]), Vector2(a, entry[2]), Vector2(b, entry[2]), Vector2(b, entry[1])]:
				pts.append(ribbon.get_point_at_offset(q.x, q.y).origin + Vector3.UP * float(entry[4]))
			entry[0].quad(mat, entry[3], pts[0], pts[1], pts[2], pts[3], Vector3.UP)
	var connector: Array[Vector3] = []
	for q: Vector2 in [Vector2(end - 10.0, 40.0), Vector2(end - 10.0, outer), Vector2(end - 3.0, outer), Vector2(end - 3.0, 40.0)]:
		connector.append(ribbon.get_point_at_offset(q.x, q.y).origin + Vector3.UP * 0.01)
	road.quad(mat, dark, connector[0], connector[1], connector[2], connector[3], Vector3.UP)
	_add_mesh("PaddockApron", apron)
	_add_mesh("PaddockServiceRoad", road)
	transporters = TransportersKit.new()
	transporters.name = "TeamTransporters"
	add_child(transporters)
	transporters.build(ribbon, pit.stalls, 47.0)
	transporter_poses = transporters.transporter_poses
	_footprints.append_array(transporters.footprints)
	tent_mesh.box(mat, white, Transform3D(Basis.IDENTITY, Vector3(0.0, 1.6, 0.0)), Vector3(7.0, 3.2, 12.0))
	tent_mesh.box(mat, red, Transform3D(Basis.IDENTITY, Vector3(0.0, 3.3, 0.0)), Vector3(7.4, 0.25, 12.4))
	tent_mesh.quad(mat, white, Vector3(-3.7, 3.4, -6.2), Vector3(-3.7, 3.4, 6.2), Vector3(0.0, 5.0, 6.2), Vector3(0.0, 5.0, -6.2), Vector3.UP)
	tent_mesh.quad(mat, white, Vector3(0.0, 5.0, -6.2), Vector3(0.0, 5.0, 6.2), Vector3(3.7, 3.4, 6.2), Vector3(3.7, 3.4, -6.2), Vector3.UP)
	tent_mesh.triangle(mat, white, Vector3(-3.7, 3.4, -6.2), Vector3(0.0, 5.0, -6.2), Vector3(3.7, 3.4, -6.2), Vector3.BACK)
	tent_mesh.triangle(mat, white, Vector3(3.7, 3.4, 6.2), Vector3(0.0, 5.0, 6.2), Vector3(-3.7, 3.4, 6.2), Vector3.FORWARD)
	for i: int in range(7):
		var arc: float = start + 22.0 + float(i) * 22.0
		tent_poses.append(ribbon.get_point_at_offset(arc, 64.0))
		_footprints.append(Rect2(arc - 6.2, 60.3, 12.4, 7.4))
	_add_instances("PaddockTents", tent_mesh, tent_poses)
	fence_mesh.box(mat, dark, Transform3D(Basis.IDENTITY, Vector3(0.0, 1.1, 0.0)), Vector3(0.08, 2.2, 0.08))
	for height: float in [0.4, 0.9, 1.4, 1.9]:
		fence_mesh.box(mat, Color("#89919b"), Transform3D(Basis.IDENTITY, Vector3(0.0, height, 2.0)), Vector3(0.025, 0.025, 4.0))
	for along: float in [1.0, 2.0, 3.0]:
		fence_mesh.box(mat, Color("#89919b"), Transform3D(Basis.IDENTITY, Vector3(0.0, 1.15, along)), Vector3(0.025, 1.5, 0.025))
	for i: int in range(ceili((end - start) / 4.0)):
		var arc: float = start + float(i) * 4.0
		if arc < end - 10.0:
			fence_poses.append(ribbon.get_point_at_offset(arc, outer))
	_add_instances("PaddockFence", fence_mesh, fence_poses)
	car_mesh.box(mat, Color("#727b86"), Transform3D(Basis.IDENTITY, Vector3(0.0, 0.6, 0.0)), Vector3(2.0, 1.2, 4.0))
	car_mesh.box(mat, Color("#323d4b"), Transform3D(Basis.IDENTITY, Vector3(0.0, 1.25, 0.0)), Vector3(1.7, 0.35, 2.0))
	for side: float in [-1.0, 1.0]:
		for along: float in [-1.25, 1.25]:
			car_mesh.cylinder(mat, Color("#1b1d21"), Transform3D(Basis(Vector3.FORWARD, PI * 0.5), Vector3(side * 1.0, 0.3, along)), 0.3, 0.3, 0.15, 8)
	for row: int in range(2):
		for col: int in range(8):
			var arc: float = start + 4.0 + float(row) * 9.0
			var lateral: float = 42.0 + float(col) * 4.5
			parking_poses.append(ribbon.get_point_at_offset(arc, lateral))
			_footprints.append(Rect2(arc - 2.0, lateral - 1.0, 4.0, 2.0))
	_add_instances("PaddockParking", car_mesh, parking_poses)
	gate_pose = ribbon.get_point_at_offset(end - 4.0, outer)
	gate.box(mat, red, Transform3D(gate_pose.basis, gate_pose * Vector3(0.0, 2.2, 0.0)), Vector3(0.25, 4.4, 0.25))
	gate.box(mat, red, Transform3D(gate_pose.basis, gate_pose * Vector3(-3.0, 4.4, 0.0)), Vector3(6.0, 0.35, 0.25))
	_add_mesh("PaddockGate", gate)
	var label := Label3D.new()
	label.name = "PaddockGateText"
	label.text = "PADDOCK"
	label.font_size = 96
	label.pixel_size = 0.01
	label.transform = gate_pose
	label.position += gate_pose.basis.x * -3.0 + Vector3.UP * 4.4
	add_child(label)
	props.box(mat, dark, Transform3D(ribbon.get_point_at_offset(end - 16.0, 54.0).basis, ribbon.get_point_at_offset(end - 16.0, 54.0).origin + Vector3.UP), Vector3(3.0, 2.0, 3.0))
	var storage: Transform3D = ribbon.get_point_at_offset(end - 11.0, 54.0)
	props.box(mat, Color("#a6a59b"), Transform3D(storage.basis, storage.origin + Vector3.UP * 1.2), Vector3(3.0, 2.4, 4.0))
	var tyres: Transform3D = ribbon.get_point_at_offset(end - 20.0, 54.0)
	for i: int in range(3):
		props.cylinder(mat, Color("#1b1d21"), Transform3D(tyres.basis, tyres.origin + Vector3.UP * float(i) * 0.3), 0.35, 0.35, 0.3, 8)
	_add_mesh("PaddockProps", props)


func _add_mesh(node_name: String, batch: RefCounted) -> void:
	var node := MeshInstance3D.new()
	node.name = node_name
	node.mesh = batch.commit()
	add_child(node)

func _add_instances(node_name: String, batch: RefCounted, poses: Array, colors: Array = []) -> void:
	var instances := MultiMesh.new()
	instances.transform_format = MultiMesh.TRANSFORM_3D
	instances.use_colors = not colors.is_empty()
	instances.mesh = batch.commit()
	instances.instance_count = poses.size()
	for i: int in range(poses.size()):
		instances.set_instance_transform(i, poses[i])
		if not colors.is_empty():
			instances.set_instance_color(i, colors[i])
	var node := MultiMeshInstance3D.new()
	node.name = node_name
	node.multimesh = instances
	add_child(node)
