extends Node3D

## One team transporter per racing team, parked behind the pit building level with its team's box: the same truck, the
## same livery colour and the same name lettering (TeamSignage) on every circuit. Each circuit hands in only where the
## row goes (`lateral_m` from the circuit centre line), so the layout still follows its own spline. All trucks are one
## MultiMesh, the lettering one more mesh, and an optional strip of asphalt keeps them off bare grass.

const Batch := preload("res://scripts/world/shared/mesh_batch.gd")
const Toon := preload("res://scripts/world/shared/toon_materials.gd")
const Liveries := preload("res://scripts/car/team_liveries.gd")
const TeamSignage := preload("res://scripts/world/paddock/team_signage.gd")

const PLATES_NODE_NAME := "TransporterPlates"
const TRUCK_LENGTH_M: float = 13.1
const TRUCK_WIDTH_M: float = 3.4
const APRON_COLOR := Color("#7d8088")
const APRON_MARGIN_M: float = 5.0

## {s, team, pose, color} per box, in stall order; the array object is shared with the circuit's paddock script.
var transporter_poses: Array[Dictionary] = []
## Ground the trucks occupy as Rect2(arc position, lateral position, length, width), for keeping props clear.
var footprints: Array[Rect2] = []

var _ribbon: Node3D
var _multimesh: MultiMesh


## Parks a truck at the arc position of every stall in `stalls` ({s, team}) on the line `lateral_m`.
func build(ribbon: Node3D, stalls: Array, lateral_m: float, with_apron: bool = false) -> void:
	_ribbon = ribbon
	# Truck poses are world transforms from the ribbon, whatever frame the circuit complex sits in.
	global_transform = Transform3D.IDENTITY
	var material: Material = Toon.vertex_colored(false)
	var truck := Batch.new()
	truck.box(material, Color.WHITE, Transform3D(Basis.IDENTITY, Vector3(0.0, 1.75, 0.0)), Vector3(3.0, 3.5, 10.0))
	truck.box(material, Color.WHITE, Transform3D(Basis.IDENTITY, Vector3(0.0, 1.45, -6.5)), Vector3(2.8, 2.9, 3.0))
	truck.box(material, Color("#313d4b"), Transform3D(Basis.IDENTITY, Vector3(0.0, 2.15, -8.02)), Vector3(2.5, 0.75, 0.08))
	for side: float in [-1.0, 1.0]:
		for along: float in [-6.4, 2.7, 4.2]:
			truck.cylinder(material, Color("#17191d"), Transform3D(Basis(Vector3.FORWARD, PI * 0.5), Vector3(side * 1.5, 0.45, along)), 0.45, 0.45, 0.2, 8)
	for stall: Dictionary in stalls:
		var arc: float = float(stall["s"])
		var team: int = int(stall["team"])
		transporter_poses.append({"s": arc, "team": team, "pose": ribbon.get_point_at_offset(arc, lateral_m), "color": Liveries.color_for(team)})
		footprints.append(Rect2(arc - 8.1, lateral_m - TRUCK_WIDTH_M * 0.5, TRUCK_LENGTH_M, TRUCK_WIDTH_M))
	_multimesh = MultiMesh.new()
	_multimesh.transform_format = MultiMesh.TRANSFORM_3D
	_multimesh.use_colors = true
	_multimesh.mesh = truck.commit()
	_multimesh.instance_count = transporter_poses.size()
	for i: int in range(transporter_poses.size()):
		_multimesh.set_instance_transform(i, transporter_poses[i]["pose"])
		_multimesh.set_instance_color(i, transporter_poses[i]["color"])
	var node := MultiMeshInstance3D.new()
	node.name = "PaddockTransporters"
	node.multimesh = _multimesh
	add_child(node)
	if with_apron and not stalls.is_empty():
		_build_apron(float(stalls[0]["s"]), float(stalls[-1]["s"]), lateral_m)
	_build_plates()


## Re-seats the trucks after the circuit's teams were assigned: livery colour, name and lettering follow the boxes.
func apply_teams(stalls: Array) -> void:
	for i: int in range(mini(stalls.size(), transporter_poses.size())):
		var team: int = int(stalls[i]["team"])
		transporter_poses[i]["team"] = team
		transporter_poses[i]["color"] = Liveries.color_for(team)
		_multimesh.set_instance_color(i, transporter_poses[i]["color"])
	_build_plates()


## Each team's name on the side of its truck that faces the circuit.
func _build_plates() -> void:
	var batch: RefCounted = TeamSignage.new_batch()
	var flat: Material = Toon.vertex_colored(false)
	var plates: Array = []
	for entry: Dictionary in transporter_poses:
		var team: int = int(entry["team"])
		var pose: Transform3D = entry["pose"]
		var to_track: Vector3 = _ribbon.get_point_at_offset(float(entry["s"]), 0.0).origin - pose.origin
		var side: float = 1.0 if pose.basis.x.dot(to_track) > 0.0 else -1.0
		var sign_pose: Transform3D = pose * Transform3D(TeamSignage.facing_basis(Vector3(side, 0.0, 0.0)), Vector3(side * 1.52, 2.0, 0.0))
		plates.append(TeamSignage.add_plate(batch, flat, team, sign_pose, 8.0, Liveries.color_for(team)))
	TeamSignage.commit_node(self, batch, plates, PLATES_NODE_NAME)


func _build_apron(first_s: float, last_s: float, lateral_m: float) -> void:
	var batch := Batch.new()
	var material: Material = Toon.vertex_colored(false)
	var from_s: float = first_s - TRUCK_LENGTH_M * 0.5 - APRON_MARGIN_M
	var to_s: float = last_s + TRUCK_LENGTH_M * 0.5 + APRON_MARGIN_M
	var steps: int = maxi(1, ceili((to_s - from_s) / 8.0))
	var near: float = lateral_m - TRUCK_WIDTH_M * 0.5 - APRON_MARGIN_M
	var far: float = lateral_m + TRUCK_WIDTH_M * 0.5 + APRON_MARGIN_M
	for i: int in range(steps):
		var a: float = lerpf(from_s, to_s, float(i) / float(steps))
		var b: float = lerpf(from_s, to_s, float(i + 1) / float(steps))
		var corners: Array[Vector3] = []
		for q: Vector2 in [Vector2(a, near), Vector2(a, far), Vector2(b, far), Vector2(b, near)]:
			corners.append(_ribbon.get_point_at_offset(q.x, q.y).origin + Vector3.UP * 0.03)
		batch.quad(material, APRON_COLOR, corners[0], corners[1], corners[2], corners[3], Vector3.UP)
	var node := MeshInstance3D.new()
	node.name = "TransporterApron"
	node.mesh = batch.commit()
	add_child(node)
