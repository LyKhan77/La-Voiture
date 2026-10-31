class_name ArdennesLandmarks
extends Node3D

## The four road-side hero landmarks of Ardennes Valley Ring (the fifth, the pit building, belongs to the pit complex), seated on
## the ribbon by the blueprint's stations as the mapgen sandbox placed them (approved 2026-10-31):
##   ValleyArchViaduct       s=680, 55 m left: a 129 m arch bridge across the river valley, its feet on the river bed
##   KemmelFlyover           s=1400: the pedestrian flyover whose deck crosses the climb 9.6 m over the road
##   AcousticCanopyTunnel    s=2750: thirty 6 m canopy bays swept along the road, the sky slot open overhead
##   GlassTerraceGrandstand  s=5280, 30 m left: the 222 m glass-roofed terrace facing the final chicane and the line
## The GLBs are massing-and-detail models (1-12k triangles). Each one merges into three surfaces: the cel structure (ink outline),
## the detail that takes no outline (seats, LED bars, thin steel) and the glass, so a landmark costs a few draw calls; the tunnel's
## thirty bays share the same three. A left-hand building takes the kit's half turn so its local +X points away from the road.

const ToonMaterials := preload("res://scripts/world/shared/toon_materials.gd")
const MeshBatchScript := preload("res://scripts/world/shared/mesh_batch.gd")
const TrackRibbonScript := preload("res://scripts/car/track_ribbon.gd")
const GlassShader := preload("res://shaders/ardennes_anime_glass.gdshader")
const MODEL_DIR := "res://assets/tracks/ardennes/models/"

## How far under the road the decks lie (the terrain's own bed is the same 0.16 m).
const DECK_DROP_M: float = 0.16
const VIADUCT_S: float = 680.0
const VIADUCT_LATERAL_M: float = 55.0
## The viaduct's feet stand 2 m below the river's surface.
const VIADUCT_BASE_BELOW_WATER_M: float = 2.0
const FLYOVER_S: float = 1400.0
const TUNNEL_S: float = 2750.0
const TUNNEL_HALF_M: float = 90.0
const TUNNEL_BAY_M: float = 6.0
const STAND_S: float = 5280.0
const STAND_LATERAL_M: float = 30.0
## Surfaces that take no ink outline: seating, LED bars, thin steel and the small stuff.
const DETAIL_SURFACES: Array[String] = ["seat_a", "seat_b", "seat_c", "led", "monitor", "equipment", "tyre", "solar", "white", "gravel", "water_line", "sign", "rail", "steel"]
## Self-lit surfaces (vertex alpha 0 is the cel shader's glow mask).
const GLOW_SURFACES: Array[String] = ["led", "sign"]
const GLASS_SURFACES: Array[String] = ["glass", "roof_glass"]
## Thin canopy sheets the cars drive under: both faces are drawn (a hull of the face looking away would paint the ceiling black).
const DOUBLE_SIDED_SURFACES: Array[String] = ["roof"]
const ARCH_TINT: float = 0.84

var ribbon: TrackRibbonScript
var heroes: Dictionary = {}
## One record per landmark: {name, file, s, side, triangles, position}.
var records: Array[Dictionary] = []
var glass_materials: Array[ShaderMaterial] = []
var _terrain


## Flat decks the terrain must leave under the glass terrace.
static func platforms() -> Array[Dictionary]:
	return [
		{"s0": STAND_S - 130.0, "s1": 5400.0, "side": -1.0, "lateral_from": 24.0, "lateral_to": 96.0},
	]


## Stand footprints the terrain is cut to: {s, side, lateral (centre), width, length}.
static func stand_rects() -> Array[Dictionary]:
	return [
		{"s": STAND_S, "side": -1.0, "lateral": 48.5, "width": 41.0, "length": 228.0},
	]


## Circles (centre, radius) the vegetation keeps out of, in world metres.
static func keepouts(ribbon_node) -> Array:
	var circles: Array = [[Vector2(0.0, 0.0), 10.0]]
	for entry: Dictionary in [
		{"s": VIADUCT_S, "lateral": -110.0, "r": 95.0},
		{"s": FLYOVER_S, "lateral": 0.0, "r": 42.0},
		{"s": TUNNEL_S - 90.0, "lateral": 0.0, "r": 38.0},
		{"s": TUNNEL_S - 45.0, "lateral": 0.0, "r": 38.0},
		{"s": TUNNEL_S, "lateral": 0.0, "r": 38.0},
		{"s": TUNNEL_S + 45.0, "lateral": 0.0, "r": 38.0},
		{"s": TUNNEL_S + 90.0, "lateral": 0.0, "r": 38.0},
		{"s": STAND_S, "lateral": -45.0, "r": 120.0},
		{"s": 10.0, "lateral": 30.0, "r": 140.0},
		{"s": 150.0, "lateral": 32.0, "r": 40.0},
	]:
		var frame: Transform3D = ribbon_node.get_point_at_offset(float(entry["s"]), float(entry["lateral"]))
		circles.append([Vector2(frame.origin.x, frame.origin.z), float(entry["r"])])
	return circles


func build(p_ribbon: TrackRibbonScript, terrain) -> void:
	ribbon = p_ribbon
	_terrain = terrain
	var water_y: float = float(terrain.water_level)
	var viaduct: Transform3D = _left_frame(VIADUCT_S, VIADUCT_LATERAL_M)
	viaduct.origin.y = water_y - VIADUCT_BASE_BELOW_WATER_M
	_place("ValleyArchViaduct", "valley_arch_viaduct", [viaduct], VIADUCT_S, -1.0)
	var flyover: Transform3D = ribbon.get_point_at_offset(FLYOVER_S, 0.0)
	flyover.origin.y -= DECK_DROP_M
	_place("KemmelFlyover", "kemmel_pedestrian_flyover", [flyover], FLYOVER_S, -1.0)
	var bays: Array[Transform3D] = []
	for index: int in range(int(roundf(TUNNEL_HALF_M * 2.0 / TUNNEL_BAY_M))):
		var station: float = TUNNEL_S - TUNNEL_HALF_M + TUNNEL_BAY_M * 0.5 + TUNNEL_BAY_M * float(index)
		var frame: Transform3D = ribbon.get_point_at_offset(station, 0.0)
		frame.origin.y -= DECK_DROP_M
		bays.append(frame)
	_place("AcousticCanopyTunnel", "acoustic_canopy_tunnel", bays, TUNNEL_S, 0.0)
	var stand: Transform3D = _left_frame(STAND_S, STAND_LATERAL_M)
	stand.origin.y -= DECK_DROP_M
	_place("GlassTerraceGrandstand", "glass_terrace_grandstand", [stand], STAND_S, -1.0)


## Ribbon frame `lateral` metres to the left with the kit's half turn: local +X points away from the road.
func _left_frame(s: float, lateral: float) -> Transform3D:
	var frame: Transform3D = ribbon.get_point_at_offset(s, -lateral)
	frame.basis = frame.basis.rotated(Vector3.UP, PI)
	return frame


## Merges `file`'s GLB, once per frame, into the landmark's three surfaces and adds it as `node_name`.
func _place(node_name: String, file: String, frames: Array[Transform3D], s: float, side: float) -> void:
	var scene := load(MODEL_DIR + file + ".glb") as PackedScene
	if scene == null:
		push_error("ArdennesLandmarks: cannot load %s" % file)
		return
	var model := scene.instantiate() as Node3D
	var solid := MeshBatchScript.new()
	var detail := MeshBatchScript.new()
	var glass := MeshBatchScript.new()
	var solid_material: Material = ToonMaterials.vertex_colored(true)
	var detail_material: Material = ToonMaterials.vertex_colored(false)
	var glass_materials_by_name: Dictionary = {}
	var triangles: int = 0
	for frame: Transform3D in frames:
		for child: Node in model.find_children("*", "MeshInstance3D", true, false):
			var instance := child as MeshInstance3D
			var key: String = String(instance.name).trim_prefix("Surface_")
			for surface: int in range(instance.mesh.get_surface_count()):
				var source := instance.mesh.surface_get_material(surface) as BaseMaterial3D
				var color: Color = source.albedo_color if source != null else Color.WHITE
				var arrays: Array = instance.mesh.surface_get_arrays(surface)
				var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
				var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
				var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
				var world: Transform3D = frame * instance.transform
				for index: int in range(0, indices.size(), 3):
					var corners: Array[Vector3] = []
					var normal := Vector3.ZERO
					for corner: int in range(3):
						corners.append(world * vertices[indices[index + corner]])
						normal += normals[indices[index + corner]]
					normal = world.basis * normal
					triangles += 1
					if GLASS_SURFACES.has(key):
						glass.triangle(_glass_material(glass_materials_by_name, key, color), Color.WHITE, corners[0], corners[1], corners[2], normal)
					elif DOUBLE_SIDED_SURFACES.has(key):
						detail.triangle(detail_material, _arch(color), corners[0], corners[1], corners[2], normal)
						detail.triangle(detail_material, _arch(color), corners[0], corners[2], corners[1], -normal)
					elif DETAIL_SURFACES.has(key):
						var tint: Color = Color(color.r, color.g, color.b, 0.0) if GLOW_SURFACES.has(key) else _arch(color)
						detail.triangle(detail_material, tint, corners[0], corners[1], corners[2], normal)
					else:
						solid.triangle(solid_material, _arch(color), corners[0], corners[1], corners[2], normal)
	model.free()
	var holder := Node3D.new()
	holder.name = node_name
	add_child(holder)
	_add_mesh(holder, "Structure", solid.commit(), true)
	_add_mesh(holder, "Detail", detail.commit(), false)
	var glass_mesh: MeshInstance3D = _add_mesh(holder, "Glass", glass.commit(), false)
	if glass_mesh != null:
		glass_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	holder.set_meta(&"arc_s", s)
	heroes[node_name] = holder
	records.append({"name": node_name, "file": file, "s": s, "side": side, "triangles": triangles, "position": frames[0].origin, "instances": frames.size()})


func _add_mesh(parent: Node3D, node_name: String, mesh: ArrayMesh, shadows: bool) -> MeshInstance3D:
	if mesh == null or mesh.get_surface_count() == 0:
		return null
	var instance := MeshInstance3D.new()
	instance.name = node_name
	instance.mesh = mesh
	if not shadows:
		instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(instance)
	return instance


func _glass_material(cache: Dictionary, key: String, color: Color) -> ShaderMaterial:
	if not cache.has(key):
		var material := ShaderMaterial.new()
		material.shader = GlassShader
		material.set_shader_parameter("base_color", color)
		cache[key] = material
		glass_materials.append(material)
	return cache[key]


## Lights the glass for the night (the window glow of the anime glass shader).
func set_night(night: float) -> void:
	for material: ShaderMaterial in glass_materials:
		material.set_shader_parameter("glow_energy", 0.22 * night)


## The model's pale colours clip to white under the shared sun: every architecture colour is dimmed a little.
static func _arch(color: Color) -> Color:
	return Color(color.r * ARCH_TINT, color.g * ARCH_TINT, color.b * ARCH_TINT, color.a)
