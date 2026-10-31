class_name ArdennesCatchFence
extends RefCounted

## The tall translucent catch fence behind the guardrail (mapgen sandbox, approved 2026-10-31): panels and posts as two
## MultiMeshes. It stands only on the outside of each sharp corner (the kerb run plus CORNER_LEAD_M each side) and only where a
## second barrier row still fits behind the rail (`TracksideFurnitureBuilder.has_barrier_row_at`), so the pit lane, the tunnel
## and the narrow stretches between two roads stay open. A panel is a quad (the cheapest double-sided surface), a post a box.

const TrackRibbonScript := preload("res://scripts/car/track_ribbon.gd")
const FurnitureScript := preload("res://scripts/world/shared/trackside_furniture_builder.gd")

const BEHIND_RAIL_M: float = 1.0
const PANEL_STEP_M: float = 4.0
const PANEL_HEIGHT_M: float = 3.6
const POST_HEIGHT_M: float = 4.0
const POST_EVERY: int = 2
const CORNER_LEAD_M: float = 10.0
const PANEL_COLOR := Color(0.12, 0.14, 0.2, 0.32)
const POST_COLOR := Color("#4a505c")


## Builds the fence under `parent`; returns {panels, posts} (the poses, which a headless MultiMesh does not keep).
static func build(parent: Node3D, ribbon: TrackRibbonScript, furniture: FurnitureScript, kerbs: Array[Dictionary]) -> Dictionary:
	var panels: Array[Transform3D] = []
	var posts: Array[Transform3D] = []
	var quarter_turn := Basis(Vector3.UP, PI * 0.5)
	for kerb: Dictionary in kerbs:
		var side: float = -float(kerb["side"])
		var s0: float = float(kerb["s0"]) - CORNER_LEAD_M
		var s1: float = float(kerb["s1"]) + CORNER_LEAD_M
		var count: int = maxi(1, ceili((s1 - s0) / PANEL_STEP_M))
		var slot: int = 0
		for index: int in range(count):
			var s: float = fposmod(s0 + (float(index) + 0.5) * (s1 - s0) / float(count), ribbon.length_m)
			if not furniture.has_barrier_row_at(side, s, BEHIND_RAIL_M):
				continue
			var lateral: float = furniture.armco_lateral(side, s) + side * BEHIND_RAIL_M
			var frame: Transform3D = ribbon.get_point_at_offset(s, lateral)
			panels.append(frame * Transform3D(quarter_turn, Vector3(0.0, PANEL_HEIGHT_M * 0.5, 0.0)))
			if slot % POST_EVERY == 0:
				posts.append(frame * Transform3D(Basis.IDENTITY.scaled(Vector3(0.16, POST_HEIGHT_M, 0.16)), Vector3(0.0, POST_HEIGHT_M * 0.5, 0.0)))
			slot += 1
	if panels.is_empty():
		return {"panels": panels, "posts": posts}
	var panel_mesh := QuadMesh.new()
	panel_mesh.size = Vector2(PANEL_STEP_M + 0.2, PANEL_HEIGHT_M)
	var panel_material := StandardMaterial3D.new()
	panel_material.albedo_color = PANEL_COLOR
	panel_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	panel_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_add(parent, "CatchFence", panel_mesh, panels, panel_material)
	var post_mesh := BoxMesh.new()
	post_mesh.size = Vector3.ONE
	var post_material := StandardMaterial3D.new()
	post_material.albedo_color = POST_COLOR
	_add(parent, "FencePosts", post_mesh, posts, post_material)
	return {"panels": panels, "posts": posts}


static func _add(parent: Node3D, node_name: String, mesh: Mesh, poses: Array[Transform3D], material: Material) -> void:
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = mesh
	multimesh.instance_count = poses.size()
	for index: int in range(poses.size()):
		multimesh.set_instance_transform(index, poses[index])
	var instance := MultiMeshInstance3D.new()
	instance.name = node_name
	instance.multimesh = multimesh
	instance.material_override = material
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(instance)
