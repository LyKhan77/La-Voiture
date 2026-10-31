class_name ArdennesPitSeparator
extends RefCounted

## The steel mesh fence that stands on Ardennes' concrete pit wall (the wall is 1.35 m, the fence 1.65 m: 3 m between the
## fast lane and the circuit). Modular like the catch fence: one 4 m panel (alpha-scissor wire mesh) and one post per module,
## each a single MultiMesh, so the whole separator costs two draw calls. The caller owns placement: a frame per panel, on top
## of the wall, with +Z along the lane. The pit mouths stay open because the caller simply places no panels there.

const MeshShader := preload("res://shaders/ardennes_steel_mesh.gdshader")
const ToonMaterials := preload("res://scripts/world/shared/toon_materials.gd")

const HEIGHT_M: float = 1.65
const PANEL_LENGTH_M: float = 4.0
const POST_COLOR := Color("#444e59")


## Builds the panels and their posts under `parent`; returns the MultiMeshInstance3D pair {panels, posts}.
static func build(parent: Node3D, frames: Array[Transform3D]) -> Dictionary:
	if frames.is_empty():
		return {}
	var panels: Array[Transform3D] = []
	var posts: Array[Transform3D] = []
	var quarter_turn := Basis(Vector3.UP, PI * 0.5)
	for frame: Transform3D in frames:
		panels.append(frame * Transform3D(quarter_turn, Vector3(0.0, HEIGHT_M * 0.5, 0.0)))
		posts.append(frame * Transform3D(Basis.IDENTITY.scaled(Vector3(0.12, HEIGHT_M + 0.08, 0.12)), Vector3(0.0, HEIGHT_M * 0.5, PANEL_LENGTH_M * 0.5)))
	posts.append(frames.back() * Transform3D(Basis.IDENTITY.scaled(Vector3(0.12, HEIGHT_M + 0.08, 0.12)), Vector3(0.0, HEIGHT_M * 0.5, -PANEL_LENGTH_M * 0.5)))
	var panel_mesh := QuadMesh.new()
	panel_mesh.size = Vector2(PANEL_LENGTH_M + 0.02, HEIGHT_M)
	var mesh_material := ShaderMaterial.new()
	mesh_material.shader = MeshShader
	var post_mesh := BoxMesh.new()
	post_mesh.size = Vector3.ONE
	return {
		"panels": _instances(parent, "PitSteelMesh", panel_mesh, panels, mesh_material),
		"posts": _instances(parent, "PitSteelPosts", post_mesh, posts, ToonMaterials.make(POST_COLOR)),
	}


static func _instances(parent: Node3D, node_name: String, mesh: Mesh, poses: Array[Transform3D], material: Material) -> MultiMeshInstance3D:
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
	return instance
