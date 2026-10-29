class_name ToonMaterials
extends RefCounted

## Shared cel-shaded materials for the low-poly set dressing (FASE 5.5): the
## same two-tone shader as the car body, one cached material per colour.

const CelShader := preload("res://shaders/anime_cel_shaded.gdshader")
const OutlineShader := preload("res://shaders/inverted_hull_outline.gdshader")
const VertexColorShader := preload("res://shaders/anime_cel_vertex_color.gdshader")
## Ink line on merged landmarks; thicker than the 2 cm car outline because they are read from far away.
const ARCHITECTURE_OUTLINE_M: float = 0.06
const GLASS_TINT := Color(0.16, 0.34, 0.46, 0.42)
const GLASS_NIGHT_GLOW := Color(1.0, 0.72, 0.38)

static var _cache: Dictionary = {}


## Cel-shaded material; `outlined` adds the ink hull pass used on the hero props.
static func make(color: Color, outlined: bool = false) -> ShaderMaterial:
	var key: String = "%s_%s" % [color.to_html(), outlined]
	if _cache.has(key):
		return _cache[key]
	var material := ShaderMaterial.new()
	material.shader = CelShader
	material.set_shader_parameter("base_color", color)
	material.set_shader_parameter("rim_intensity", 0.15)
	if outlined:
		var outline := ShaderMaterial.new()
		outline.shader = OutlineShader
		outline.render_priority = 1
		outline.set_shader_parameter("outline_width", 0.02)
		outline.set_shader_parameter("outline_color", Color(0.02, 0.02, 0.02))
		material.next_pass = outline
	_cache[key] = material
	return material


## Cel material whose albedo is the mesh's vertex colour (see MeshBatch), one shared instance per
## outline setting so every merged building lights up together via `glow_energy`.
static func vertex_colored(outlined: bool = false) -> ShaderMaterial:
	var key: String = "vertex_colored_%s" % outlined
	if _cache.has(key):
		return _cache[key]
	var material := ShaderMaterial.new()
	material.shader = VertexColorShader
	if outlined:
		var outline := ShaderMaterial.new()
		outline.shader = OutlineShader
		outline.render_priority = 1
		outline.set_shader_parameter("outline_width", ARCHITECTURE_OUTLINE_M)
		outline.set_shader_parameter("outline_color", Color(0.02, 0.02, 0.02))
		material.next_pass = outline
	_cache[key] = material
	return material


## Sets how brightly every glow-masked vertex (floodlight lenses, lit windows, ad boards) shines.
static func set_glow_energy(energy: float) -> void:
	for outlined: bool in [false, true]:
		vertex_colored(outlined).set_shader_parameter("glow_energy", energy)


## Tinted lounge/tower glass; `emission_energy_multiplier` is raised at night for the lit windows.
static func glass() -> StandardMaterial3D:
	if _cache.has("glass"):
		return _cache["glass"]
	var material := StandardMaterial3D.new()
	material.albedo_color = GLASS_TINT
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.metallic = 0.25
	material.roughness = 0.08
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.emission_enabled = true
	material.emission = GLASS_NIGHT_GLOW
	material.emission_energy_multiplier = 0.0
	_cache["glass"] = material
	return material


## Self-lit material for lamps and signs; `energy` 0 leaves a dark lens.
static func emissive(color: Color, energy: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.emission_enabled = energy > 0.0
	material.emission = color
	material.emission_energy_multiplier = energy
	return material


static func box(parent: Node3D, node_name: String, size: Vector3, position: Vector3, material: Material) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var instance := MeshInstance3D.new()
	instance.name = node_name
	instance.mesh = mesh
	instance.position = position
	instance.material_override = material
	parent.add_child(instance)
	return instance
