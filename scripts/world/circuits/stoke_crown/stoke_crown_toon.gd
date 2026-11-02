extends RefCounted

## Approved cel/ink material conversion; the production environment owns sky and lighting.

const Toon := preload("res://scripts/world/shared/toon_materials.gd")
const GlassShader := preload("res://shaders/stoke_crown/anime_glass.gdshader")
const RoadShader := preload("res://shaders/road_asphalt.gdshader")

const FLAT_NAMES := ["Terrain", "DistantRidge", "Road", "PitLane", "Apron", "Paint", "Terrace", "Quay", "River", "Water", "Ground", "Groove", "Kerb", "Runoff", "Gravel", "bush", "Fence", "Forest", "Rocks", "Plinth", "Armco", "Tecpro", "Braking", "Floodlight", "FlagPanels"]

static func apply_materials(root: Node, ink_width: float = 0.06) -> void:
	_visit(root, {}, ink_width)


static func _visit(node: Node, cache: Dictionary, ink_width: float) -> void:
	if node is GeometryInstance3D:
		var geometry := node as GeometryInstance3D
		var outlined := true
		for flat: String in FLAT_NAMES:
			if flat.to_lower() in String(node.name).to_lower():
				outlined = false
				break
		if geometry.material_override:
			geometry.material_override = _convert(geometry.material_override, cache, outlined, ink_width)
		elif node is MeshInstance3D and node.mesh:
			for index in node.mesh.get_surface_count():
				var material: Material = node.get_active_material(index)
				node.set_surface_override_material(index, _convert(material, cache, outlined, ink_width))
		elif node is MultiMeshInstance3D and node.multimesh and node.multimesh.mesh:
			var mesh: Mesh = node.multimesh.mesh.duplicate()
			for index in mesh.get_surface_count():
				mesh.surface_set_material(index, _convert(mesh.surface_get_material(index), cache, outlined, ink_width))
			node.multimesh.mesh = mesh
	for child: Node in node.get_children():
		if child.is_inside_tree():
			_visit(child, cache, ink_width)


static func _convert(source: Material, cache: Dictionary, outlined: bool, width: float) -> Material:
	if source == null:
		return Toon.make(Color("#d8d2bd"), outlined)
	var key := "%s:%s:%s" % [source.get_instance_id(), outlined, width]
	if cache.has(key):
		return cache[key]
	var result: Material = source
	if source is ShaderMaterial:
		var shader: Shader = source.shader
		if shader == Toon.CelShader or shader == Toon.VertexColorShader:
			var cel := source.duplicate() as ShaderMaterial
			cel.set_shader_parameter("rim_color", Color("#cfe0d2"))
			cel.set_shader_parameter("rim_intensity", 0.07 if outlined else 0.0)
			cel.set_shader_parameter("shadow_tint", Color("#7f97a0") if outlined else Color("#4f6a55"))
			result = cel
		elif shader == RoadShader:
			var road := source.duplicate() as ShaderMaterial
			var variant := Shader.new()
			variant.resource_name = "RoadAsphaltToon"
			variant.code = RoadShader.code.replace("render_mode cull_disabled;", "render_mode cull_disabled, diffuse_toon, specular_toon;")
			road.shader = variant
			result = road
	elif source is StandardMaterial3D:
		var base := source as StandardMaterial3D
		var glass := "glass" in source.resource_name.to_lower() or (base.transparency == BaseMaterial3D.TRANSPARENCY_ALPHA and base.albedo_texture == null and not base.vertex_color_use_as_albedo)
		if glass:
			var material := ShaderMaterial.new()
			material.shader = GlassShader
			material.set_shader_parameter("base_color", base.albedo_color)
			result = material
		elif base.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED or base.emission_enabled or (base.albedo_texture != null and base.vertex_color_use_as_albedo):
			var material := base
			material.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON
			material.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
			material.metallic = 0.0
			material.roughness = 1.0
			result = material
		else:
			var material := ShaderMaterial.new()
			if base.vertex_color_use_as_albedo:
				material.shader = Toon.VertexColorShader
				material.set_shader_parameter("tint", base.albedo_color)
			else:
				material.shader = Toon.CelShader
				material.set_shader_parameter("base_color", base.albedo_color)
				if base.albedo_texture:
					material.set_shader_parameter("albedo_texture", base.albedo_texture)
			material.set_shader_parameter("shadow_tint", Color("#7f97a0") if outlined else Color("#4f6a55"))
			material.set_shader_parameter("rim_color", Color("#cfe0d2"))
			material.set_shader_parameter("rim_intensity", 0.07 if outlined else 0.0)
			result = material
	if result != source and outlined:
		var ink := ShaderMaterial.new()
		ink.shader = Toon.OutlineShader
		ink.set_shader_parameter("outline_width", width)
		ink.set_shader_parameter("outline_color", Color("#16221a"))
		result.next_pass = ink
	cache[key] = result
	return result
