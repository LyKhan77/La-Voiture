extends Node3D

## Catch fence built from the same kerb runs the furniture uses: alpha-scissor
## steel panels every 4 m behind the armco rail on the outside of every kerbed
## corner. Ported from the approved Route 2 build.

const BEHIND_RAIL_M := 1.0
const PANEL_STEP_M := 4.0
const PANEL_HEIGHT_M := 3.6
const POST_HEIGHT_M := 4.0
const POST_EVERY := 2
const CORNER_LEAD_M := 10.0
const PANEL_COLOR := Color(0.12, 0.14, 0.2, 0.32)
const POST_COLOR := Color("#4a505c")


static func build(parent: Node3D, ribbon: Node3D, furniture: Node3D, kerbs: Array[Dictionary]) -> int:
	var panels: Array[Transform3D] = []
	var posts: Array[Transform3D] = []
	for kerb: Dictionary in kerbs:
		var side: float = -float(kerb["side"])
		var s0: float = float(kerb["s0"]) - CORNER_LEAD_M
		var s1: float = float(kerb["s1"]) + CORNER_LEAD_M
		var count: int = maxi(1, ceili((s1 - s0) / PANEL_STEP_M))
		var slot := 0
		for index in range(count):
			var s: float = fposmod(s0 + (float(index) + 0.5) * (s1 - s0) / float(count), float(ribbon.get("length_m")))
			if not bool(furniture.call("has_barrier_row_at", side, s, BEHIND_RAIL_M)):
				continue
			slot += 1
			var lateral: float = float(furniture.call("armco_lateral", side, s)) + side * BEHIND_RAIL_M
			var frame: Transform3D = ribbon.call("get_point_at_offset", s, lateral)
			if side < 0.0:
				frame.basis = frame.basis.rotated(Vector3.UP, PI)
			panels.append(frame * Transform3D(Basis.IDENTITY.scaled(Vector3(0.03, PANEL_HEIGHT_M, PANEL_STEP_M)), Vector3(0, PANEL_HEIGHT_M * 0.5, 0)))
			if slot % POST_EVERY == 0:
				posts.append(frame * Transform3D(Basis.IDENTITY.scaled(Vector3(0.12, POST_HEIGHT_M, 0.12)), Vector3(0, POST_HEIGHT_M * 0.5, 0)))
	var panel_material := StandardMaterial3D.new()
	panel_material.albedo_color = PANEL_COLOR
	panel_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	panel_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	panel_material.roughness = 1.0
	_add(parent, "CatchFencePanels", panels, panel_material)
	var post_material := StandardMaterial3D.new()
	post_material.albedo_color = POST_COLOR
	post_material.roughness = 0.9
	_add(parent, "CatchFencePosts", posts, post_material)
	return panels.size()


static func _add(parent: Node3D, node_name: String, poses: Array[Transform3D], material: Material) -> void:
	var box := BoxMesh.new()
	box.size = Vector3.ONE
	box.material = material
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = box
	multimesh.instance_count = poses.size()
	for index in range(poses.size()):
		multimesh.set_instance_transform(index, poses[index])
	var instance := MultiMeshInstance3D.new()
	instance.name = node_name
	instance.multimesh = multimesh
	parent.add_child(instance)
