extends RefCounted

## Reusable 4 m steel panels; caller owns placement and base elevation.
const CatchFence := preload("res://scripts/world/circuits/eifel_forest/eifel_forest_catch_fence.gd")
const MeshShader := preload("res://shaders/eifel_forest_steel_mesh.gdshader")
const HEIGHT_M := 1.65

static func build(parent: Node3D, frames: Array[Transform3D]) -> void:
	var panels: Array[Transform3D] = []
	var posts: Array[Transform3D] = []
	for frame in frames:
		panels.append(frame * Transform3D(Basis.IDENTITY.scaled(Vector3(0.025, HEIGHT_M, 4.02)), Vector3(0, HEIGHT_M * 0.5, 0)))
		posts.append(frame * Transform3D(Basis.IDENTITY.scaled(Vector3(0.12, HEIGHT_M + 0.08, 0.12)), Vector3(0, HEIGHT_M * 0.5, 2.0)))
	if frames.is_empty():
		return
	posts.append(frames.back() * Transform3D(Basis.IDENTITY.scaled(Vector3(0.12, HEIGHT_M + 0.08, 0.12)), Vector3(0, HEIGHT_M * 0.5, -2.0)))
	var material := ShaderMaterial.new()
	material.shader = MeshShader
	CatchFence._add(parent, "PitSteelMesh", panels, material)
	var steel := StandardMaterial3D.new()
	steel.albedo_color = Color("#444e59")
	steel.roughness = 0.85
	CatchFence._add(parent, "PitSteelPosts", posts, steel)
