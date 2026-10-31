class_name ArdennesPitBuilding
extends Node3D

## The hero pit building of Ardennes Valley Ring: `futuristic_pit_building.glb`, a glass-fronted two-storey block with ten open
## garage bays under a VIP terrace roof. The model is authored on a 14 m bay pitch; the circuit's boxes stand on 20 m (a team's
## two cars double-stack and a car leaving its box needs room to swing past the queued one, see ArdennesPitComplex), so each
## bay is re-spaced when the building is built: the opening grows from 11 m to the garage width, the piers between the bays
## stretch with it, the end blocks keep their size, and the bay furniture (tyre stacks, equipment, monitors) only moves.
##
## Local axes follow the ribbon at the building's middle with the origin on the garage front: +X away from the lane (the
## model's facade is at x = 0), +Z against the direction of travel. Bay k of the model (local z = -63 + 14 k) serves box 9 - k.
## Everything merges into two surfaces: the cel structure (ink outline, the team shutter strips recoloured per team inside it) and
## the glass. `structure` carries the strips' livery colours like the shared PitBuilding kit's.

const ToonMaterials := preload("res://scripts/world/shared/toon_materials.gd")
const MeshBatchScript := preload("res://scripts/world/shared/mesh_batch.gd")
const GlassShader := preload("res://shaders/ardennes_anime_glass.gdshader")

const MODEL_PATH := "res://assets/tracks/ardennes/models/futuristic_pit_building.glb"
const BAY_COUNT: int = 10
const MODEL_PITCH_M: float = 14.0
const MODEL_OPENING_M: float = 11.0
## Local z of bay 0's middle in the model.
const MODEL_FIRST_Z_M: float = -63.0
## Surfaces that keep their size and only move with their bay.
const BAY_FURNITURE: Array[String] = ["equipment", "tyre", "monitor"]
## Self-lit surfaces (vertex alpha 0 is the cel shader's glow mask).
const GLOW_SURFACES: Array[String] = ["led", "monitor"]
const GLASS_SURFACES: Array[String] = ["glass", "roof_glass"]
const STRIP_PREFIX := "team"
const STRIP_COLOR := Color("#8a8f99")
## The model's pale concrete clips to white under the shared sun and loses its terrace detail: the same architecture tint the stands wear.
const ARCH_TINT: float = 0.84

var pitch_m: float = 20.0
var opening_m: float = 16.4
var structure: MeshInstance3D
var glass: MeshInstance3D
## The shared kit's PitBuilding keeps its name plates here; Ardennes letters the names on the complex's own TeamPlates mesh.
var name_plates: Array[Dictionary] = []
## Total length along the lane, and the lateral depth behind the facade.
var length_m: float = 0.0
var depth_m: float = 0.0
var height_m: float = 0.0
var triangle_count: int = 0
var glass_materials: Array[ShaderMaterial] = []

var _solid_triangles: Array[Dictionary] = [] # {a, b, c, normal, color}
var _strip_triangles: Array = [] # per bay k: Array of {a, b, c, normal}


## Builds the building from the model for `pitch` metres between box middles and `opening` metres of garage mouth.
func build(pitch: float = 20.0, opening: float = 16.4) -> void:
	pitch_m = pitch
	opening_m = opening
	var scene := load(MODEL_PATH) as PackedScene
	if scene == null:
		push_error("ArdennesPitBuilding: cannot load %s" % MODEL_PATH)
		return
	var model := scene.instantiate() as Node3D
	var glass_batch := MeshBatchScript.new()
	var glass_by_name: Dictionary = {}
	_solid_triangles.clear()
	_strip_triangles.clear()
	for _bay: int in range(BAY_COUNT):
		_strip_triangles.append([])
	var low := Vector3(INF, INF, INF)
	var high := Vector3(-INF, -INF, -INF)
	triangle_count = 0
	for child: Node in model.find_children("*", "MeshInstance3D", true, false):
		var instance := child as MeshInstance3D
		var key: String = String(instance.name).trim_prefix("Surface_")
		var scaled: bool = not BAY_FURNITURE.has(key)
		for surface: int in range(instance.mesh.get_surface_count()):
			var source := instance.mesh.surface_get_material(surface) as BaseMaterial3D
			var color: Color = source.albedo_color if source != null else Color.WHITE
			var arrays: Array = instance.mesh.surface_get_arrays(surface)
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
			var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
			for index: int in range(0, indices.size(), 3):
				var corners: Array[Vector3] = []
				var normal := Vector3.ZERO
				for corner: int in range(3):
					var vertex: Vector3 = instance.transform * vertices[indices[index + corner]]
					vertex.z = _remap_z(vertex.z, scaled)
					corners.append(vertex)
					normal += normals[indices[index + corner]]
					low = low.min(vertex)
					high = high.max(vertex)
				triangle_count += 1
				if key.begins_with(STRIP_PREFIX):
					(_strip_triangles[int(key.trim_prefix(STRIP_PREFIX))] as Array).append({"a": corners[0], "b": corners[1], "c": corners[2], "normal": normal})
				elif GLASS_SURFACES.has(key):
					glass_batch.triangle(_glass_material(glass_by_name, key, color), Color.WHITE, corners[0], corners[1], corners[2], normal)
				else:
					var tint: Color = Color(color.r, color.g, color.b, 0.0) if GLOW_SURFACES.has(key) else Color(color.r * ARCH_TINT, color.g * ARCH_TINT, color.b * ARCH_TINT, color.a)
					_solid_triangles.append({"a": corners[0], "b": corners[1], "c": corners[2], "normal": normal, "color": tint})
	model.free()
	length_m = high.z - low.z
	depth_m = high.x
	height_m = high.y
	structure = MeshInstance3D.new()
	structure.name = "Structure"
	add_child(structure)
	glass = MeshInstance3D.new()
	glass.name = "Glass"
	glass.mesh = glass_batch.commit()
	glass.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(glass)
	set_team_colors([])


## Lights the glass for the night (the window glow of the anime glass shader).
func set_night(night: float) -> void:
	for material: ShaderMaterial in glass_materials:
		material.set_shader_parameter("glow_energy", 0.22 * night)


## Colours the shutter strip of box `i` (bay 9 - i) in `colors[i]`; missing entries stay neutral. Rebuilds the structure mesh
## (about 3 500 triangles).
func set_team_colors(colors: Array) -> void:
	var batch := MeshBatchScript.new()
	var material: Material = ToonMaterials.vertex_colored(true)
	for triangle: Dictionary in _solid_triangles:
		batch.triangle(material, triangle["color"], triangle["a"], triangle["b"], triangle["c"], triangle["normal"])
	for bay: int in range(BAY_COUNT):
		var box: int = BAY_COUNT - 1 - bay
		var color: Color = colors[box] if box < colors.size() else STRIP_COLOR
		for triangle: Dictionary in _strip_triangles[bay]:
			batch.triangle(material, color, triangle["a"], triangle["b"], triangle["c"], triangle["normal"])
	structure.mesh = batch.commit()


## Local z of box `i`'s middle.
func box_z(box: int) -> float:
	return -pitch_m * (float(BAY_COUNT - 1) * 0.5 - float(BAY_COUNT - 1 - box))


## Maps a model z onto the re-spaced building (see the class comment).
func _remap_z(z: float, scaled: bool) -> float:
	var bay: int = clampi(roundi((z - MODEL_FIRST_Z_M) / MODEL_PITCH_M), 0, BAY_COUNT - 1)
	var offset: float = z - (MODEL_FIRST_Z_M + MODEL_PITCH_M * float(bay))
	var middle: float = -pitch_m * float(BAY_COUNT - 1) * 0.5 + pitch_m * float(bay)
	if not scaled:
		return middle + offset
	var distance: float = absf(offset)
	var old_open: float = MODEL_OPENING_M * 0.5
	var old_half: float = MODEL_PITCH_M * 0.5
	var new_open: float = opening_m * 0.5
	var new_half: float = pitch_m * 0.5
	var mapped: float
	if distance <= old_open:
		mapped = distance * new_open / old_open
	elif distance <= old_half:
		mapped = new_open + (distance - old_open) * (new_half - new_open) / (old_half - old_open)
	else:
		mapped = new_half + (distance - old_half)
	return middle + signf(offset) * mapped


func _glass_material(cache: Dictionary, key: String, color: Color) -> ShaderMaterial:
	if not cache.has(key):
		var material := ShaderMaterial.new()
		material.shader = GlassShader
		material.set_shader_parameter("base_color", color)
		cache[key] = material
		glass_materials.append(material)
	return cache[key]
