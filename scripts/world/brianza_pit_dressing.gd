extends RefCounted

const Batch := preload("res://scripts/world/mesh_batch.gd")
const Toon := preload("res://scripts/world/toon_materials.gd")

static func build(pit: Node3D) -> Dictionary:
	var mat: Material = Toon.vertex_colored(false)
	var span: Vector2 = pit.wall_span_u()
	var footprints: Array[Dictionary] = []
	var fence_poses: Array[Transform3D] = []
	var drum_poses: Array[Transform3D] = []
	var stripe := Batch.new()
	var chevrons := Batch.new()
	var gantry := Batch.new()
	var drums := Batch.new()
	var white := Color("#f4f5f7")
	var yellow := Color("#ffd400")
	var dark := Color("#343945")
	for u: float in range(0, 60, 8):
		var pose: Transform3D = pit.get_pit_transform(u, 7.1)
		chevrons.box(mat, white, Transform3D(pose.basis * Basis(Vector3.UP, 0.6), pose * Vector3(0.0, 0.04, 0.0)), Vector3(0.18, 0.02, 3.2))
	for u: float in range(int(span.x), int(span.y), 3):
		var pose: Transform3D = pit.get_pit_transform(u, pit.wall_lateral(u))
		fence_poses.append(pose)
		stripe.box(mat, yellow, Transform3D(pose.basis, pose * Vector3(0.28, 0.65, 0.0)), Vector3(0.04, 0.35, 3.1))
	var panel := Batch.new()
	panel.box(mat, dark, Transform3D(Basis.IDENTITY, Vector3(0.0, 1.95, 0.0)), Vector3(0.08, 1.8, 0.08))
	for height: float in [1.3, 1.8, 2.3, 2.8]:
		panel.box(mat, Color("#8e99a6"), Transform3D(Basis.IDENTITY, Vector3(0.0, height, 1.5)), Vector3(0.025, 0.025, 3.0))
	for offset: float in [0.6, 1.2, 1.8, 2.4]:
		panel.box(mat, Color("#8e99a6"), Transform3D(Basis.IDENTITY, Vector3(0.0, 2.05, offset)), Vector3(0.025, 1.5, 0.025))
	var fence_mesh := MultiMesh.new()
	fence_mesh.transform_format = MultiMesh.TRANSFORM_3D
	fence_mesh.mesh = panel.commit()
	fence_mesh.instance_count = fence_poses.size()
	for i: int in range(fence_poses.size()):
		fence_mesh.set_instance_transform(i, fence_poses[i])
	var fence_node := MultiMeshInstance3D.new()
	fence_node.name = "PitWallFence"
	fence_node.multimesh = fence_mesh
	pit.add_child(fence_node)
	var u_gantry: float = span.x + 15.0
	var gp: Transform3D = pit.get_pit_transform(u_gantry, pit.wall_lateral(u_gantry))
	gantry.box(mat, dark, Transform3D(gp.basis, gp * Vector3(0.0, 2.7, 0.0)), Vector3(0.25, 5.4, 0.25))
	gantry.box(mat, dark, Transform3D(gp.basis, gp * Vector3(2.7, 5.4, 0.0)), Vector3(5.4, 0.9, 0.25))
	footprints.append({"name": "gantry_leg", "u0": u_gantry - 0.2, "u1": u_gantry + 0.2, "lat0": pit.wall_lateral(u_gantry) - 0.15, "lat1": pit.wall_lateral(u_gantry) + 0.15})
	for i: int in range(5):
		var u: float = span.x + float(i) * 1.0
		var pose: Transform3D = pit.get_pit_transform(u, pit.wall_lateral(u) - 0.1)
		drum_poses.append(pose)
		drums.cylinder(mat, Color("#ff6a00"), Transform3D(pose.basis, pose * Vector3(0.0, 0.0, 0.0)), 0.32, 0.32, 0.9, 8)
		footprints.append({"name": "drum", "u0": u - 0.4, "u1": u + 0.4, "lat0": pit.wall_lateral(u) - 0.42, "lat1": pit.wall_lateral(u) + 0.22})
	for item: Array in [["PitEntryChevrons", chevrons], ["PitEntryGantry", gantry], ["PitWallSponsorStrip", stripe], ["PitWallDrums", drums]]:
		var node := MeshInstance3D.new()
		node.name = item[0]
		node.mesh = item[1].commit()
		pit.add_child(node)
	var label := Label3D.new()
	label.name = "PitEntryGantryText"
	label.text = "80  PIT ENTRY"
	label.font_size = 96
	label.pixel_size = 0.008
	label.transform = gp
	label.position += gp.basis.x * 2.7 + Vector3.UP * 5.4 + gp.basis.z * 0.15
	pit.add_child(label)
	return {"footprints": footprints, "fence_poses": fence_poses, "drum_poses": drum_poses}
