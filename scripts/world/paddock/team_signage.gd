extends RefCounted

## Team-name lettering shared by every circuit: garage fascias and paddock transporters read the same name from
## `GtData.TEAM_NAMES`, in the same letters. The lettering is real geometry (a TextMesh baked per team) merged into
## one MeshBatch surface, so a whole circuit's signs cost a single draw call instead of one Label3D each.

const Gt := preload("res://scripts/gt/gt_data.gd")
const MeshBatchScript := preload("res://scripts/world/mesh_batch.gd")

const FONT_SIZE: int = 96
const PIXEL_SIZE: float = 0.0052
## Coarse curve steps: ~400 triangles a name instead of ~2 500.
const CURVE_STEP: float = 4.0
const DARK_TEXT := Color("#14161c")
const LIGHT_TEXT := Color("#f4f7ff")
const SIGN_NODE_NAME := "TeamPlates"

static var _glyphs: Dictionary = {}


static func plate_text(team: int) -> String:
	return String(Gt.TEAM_NAMES[team]).to_upper() if team >= 0 and team < Gt.TEAM_NAMES.size() else ""


## Dark lettering on a light band, light lettering on a dark one.
static func text_color_for(band: Color) -> Color:
	return DARK_TEXT if band.get_luminance() > 0.4 else LIGHT_TEXT


## Frame of a sign that faces `normal`: +X runs along the text so it reads left to right seen from outside.
static func facing_basis(normal: Vector3) -> Basis:
	var n: Vector3 = normal.normalized()
	return Basis(Vector3.UP.cross(n).normalized(), Vector3.UP, n)


## Sign frame on a garage front: `front_x` metres along the garage's +X (away from the lane is positive, so the
## fascia is at a negative x), `y` metres up, facing the lane (-X).
static func fascia_pose(garage_xform: Transform3D, front_x: float, y: float) -> Transform3D:
	return garage_xform * Transform3D(facing_basis(Vector3(-1.0, 0.0, 0.0)), Vector3(front_x, y, 0.0))


## Adds `team`'s name to `batch` in the sign frame `pose` (+Z is the face), shrunk to fit `max_width_m`, lettered
## to stand out from `band_color`. Returns {team, text, origin, normal}, or {} for a team without a name.
static func add_plate(batch: RefCounted, material: Material, team: int, pose: Transform3D, max_width_m: float, band_color: Color) -> Dictionary:
	var text: String = plate_text(team)
	if text.is_empty():
		return {}
	var glyphs: Dictionary = _glyphs_for(text)
	var triangles: PackedVector3Array = glyphs["triangles"]
	var fit: float = minf(1.0, max_width_m / maxf(float(glyphs["width"]), 0.001))
	var color: Color = text_color_for(band_color)
	var face: Vector3 = pose.basis.z.normalized()
	for i: int in range(0, triangles.size() - 2, 3):
		batch.triangle(material, color, pose * (triangles[i] * fit), pose * (triangles[i + 1] * fit), pose * (triangles[i + 2] * fit), face)
	return {"team": team, "text": text, "origin": pose.origin, "normal": face}


## Commits `batch` as the sign mesh child `node_name` of `parent` (reusing the node when teams are re-seated) and
## keeps the plate list on it as metadata.
static func commit_node(parent: Node3D, batch: RefCounted, plates: Array, node_name: String = SIGN_NODE_NAME) -> MeshInstance3D:
	var holder: MeshInstance3D = parent.get_node_or_null(node_name) as MeshInstance3D
	if holder == null:
		holder = MeshInstance3D.new()
		holder.name = node_name
		parent.add_child(holder)
	holder.mesh = batch.commit()
	holder.set_meta(&"plates", plates.filter(func(entry: Dictionary) -> bool: return not entry.is_empty()))
	return holder


static func new_batch() -> RefCounted:
	return MeshBatchScript.new()


static func _glyphs_for(text: String) -> Dictionary:
	if _glyphs.has(text):
		return _glyphs[text]
	var mesh := TextMesh.new()
	mesh.text = text
	mesh.font_size = FONT_SIZE
	mesh.pixel_size = PIXEL_SIZE
	mesh.depth = 0.0
	mesh.curve_step = CURVE_STEP
	var arrays: Array = mesh.get_mesh_arrays()
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var triangles := PackedVector3Array()
	for index: int in indices:
		triangles.append(vertices[index])
	var entry: Dictionary = {"triangles": triangles, "width": mesh.get_aabb().size.x}
	_glyphs[text] = entry
	return entry
