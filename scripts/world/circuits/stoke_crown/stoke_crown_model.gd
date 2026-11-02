extends RefCounted

## The approved untextured GLBs batch paint colours into vertex colours; glass keeps its own pass.
const Toon := preload("res://scripts/world/shared/toon_materials.gd")
const Glass := preload("res://shaders/stoke_crown/anime_glass.gdshader")

static func load_batched(path: String, neutral_teams: bool = false) -> Node3D:
	var packed := load(path) as PackedScene
	if packed == null:
		push_error("Stoke Crown model load failed: " + path)
		return null
	var source := packed.instantiate() as Node3D
	var groups: Dictionary = {}
	var materials: Dictionary = {}
	for node: Node in source.find_children("*", "MeshInstance3D", true, false):
		var instance := node as MeshInstance3D
		var transform := _relative_transform(instance, source)
		var normal_basis := transform.basis.inverse().transposed()
		for surface: int in range(instance.mesh.get_surface_count()):
			var material := instance.get_active_material(surface) as StandardMaterial3D
			assert(material != null and material.albedo_texture == null, "Expected untextured approved landmark")
			var tint := material.albedo_color
			if neutral_teams and material.resource_name.begins_with("team"):
				tint = Color("#d8d2bd")
			var glass := "glass" in material.resource_name.to_lower() or material.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED
			var two_sided := material.cull_mode == BaseMaterial3D.CULL_DISABLED
			var key := "glass:" + tint.to_html() if glass else ("double" if two_sided else "paint")
			if not groups.has(key):
				var tool := SurfaceTool.new()
				tool.begin(Mesh.PRIMITIVE_TRIANGLES)
				groups[key] = tool
				var target: Material
				if glass:
					var window := ShaderMaterial.new()
					window.shader = Glass
					window.set_shader_parameter("base_color", tint)
					target = window
				else:
					target = Toon.vertex_colored(true).duplicate()
					if two_sided:
						var shader := Shader.new()
						shader.code = Toon.VertexColorShader.code.replace("render_mode diffuse_toon, specular_toon;", "render_mode cull_disabled, diffuse_toon, specular_toon;")
						(target as ShaderMaterial).shader = shader
				materials[key] = target
			var tool: SurfaceTool = groups[key]
			var arrays := instance.mesh.surface_get_arrays(surface)
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
			var colors: PackedColorArray = arrays[Mesh.ARRAY_COLOR] if arrays[Mesh.ARRAY_COLOR] is PackedColorArray else PackedColorArray()
			var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] is PackedInt32Array else PackedInt32Array()
			var count := indices.size() if not indices.is_empty() else vertices.size()
			for index: int in range(count):
				var vertex := indices[index] if not indices.is_empty() else index
				var color := tint.srgb_to_linear()
				if material.vertex_color_use_as_albedo and not colors.is_empty():
					color *= colors[vertex]
				color.a = 0.0 if material.emission_enabled else 1.0
				tool.set_color(color)
				tool.set_normal((normal_basis * normals[vertex]).normalized())
				tool.add_vertex(transform * vertices[vertex])
	var result := Node3D.new()
	result.name = path.get_file().get_basename()
	for key: String in groups:
		var mesh: ArrayMesh = groups[key].commit()
		mesh.surface_set_material(0, materials[key])
		var node := MeshInstance3D.new()
		node.name = key.replace(":", "_")
		node.mesh = mesh
		result.add_child(node)
	source.free()
	return result

static func _relative_transform(node: Node3D, root: Node3D) -> Transform3D:
	var result := node.transform
	var parent := node.get_parent() as Node3D
	while parent != null and parent != root:
		result = parent.transform * result
		parent = parent.get_parent() as Node3D
	return result
