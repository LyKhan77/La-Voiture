class_name MonteAzureLandmarks
extends Node3D

## The five hero landmarks of Monte Azure Marina (SPEC 4.4 item 5), seated on the ribbon by the blueprint's stations.
## The blueprint's `offset_m` is the near edge (the building's centre stands offset + depth / 2 from the road), which
## holds for the casino (90 + 30 m right) and the hotel (20 + 27.5 m left). The two structures that must work with the
## road are the exception and stand ON it: the cliff tunnel carries the road through its bore, the skybridge spans it.
## The yacht pack moors against the quay (29 m left of the road) instead of floating 60 m out.
##
## The GLBs are massing-level (700-1900 triangles) with glTF node offsets of a few metres, so each one is seated by its
## own bounds: lowest vertex on the ground (the tunnel: the bore's floor on the road), centred on its footprint.

const ToonMaterials := preload("res://scripts/world/shared/toon_materials.gd")
const TrackRibbonScript := preload("res://scripts/car/track_ribbon.gd")
const MODEL_DIR := "res://assets/tracks/monte_azure/models/"

## How far under the road the hero decks (plazas, terraces, pylon and tunnel footings) lie.
const DECK_DROP_M: float = 0.2
const TUNNEL_S: float = 1330.0
## The straight between Tunnel In and Tunnel Out is 166 m; the 190 m model is scaled to 150 m so it fits with 8 m to spare.
const TUNNEL_LENGTH_M: float = 150.0
const TUNNEL_MODEL_LENGTH_M: float = 190.0
const TUNNEL_SLOPE_HALF_SPAN_M: float = 75.0
const SKYBRIDGE_S: float = 2180.0
## The deck's underside stands 4.4 m over the pylon feet in the model; scaled so the road has 6 m of headroom.
const SKYBRIDGE_HEIGHT_SCALE: float = 1.6
## The 23 m span is stretched so the pylons stand outside the 6.2 m barrier line with room to spare (inner faces > 9 m).
const SKYBRIDGE_SPAN_SCALE: float = 1.3
const YACHT_WATER_Y: float = -0.8
## The tunnel GLB's surface standing in for the opening (see `_open_bore`).
const BORE_MATERIAL: String = "dark"
## The GLB surface holding the solid portal blocks, and how far from a mouth they reach.
const PORTAL_MATERIAL: String = "concrete"
const PORTAL_ZONE_M: float = 6.0
## What looks into the bore (the reveals, the side wall) is lined darker than the facade.
const LINER_COLOR := Color(0.36, 0.38, 0.45)
## Its surface goes without the ink hull: seen from inside the bore the hull of a face that looks away draws black.
const LINER_MATERIAL: String = "liner"

## name, file, blueprint station s, side (+1 right, -1 left, 0 on the road), near edge, depth (footprint along the lateral).
const HEROES: Array[Dictionary] = [
	{"name": "CasinoPalace", "file": "casino_palace", "s": 980.0, "side": 1.0, "near_m": 90.0, "depth_m": 60.0},
	{"name": "GrandHotelFairmont", "file": "fairmont_hairpin_hotel", "s": 1010.0, "side": -1.0, "near_m": 20.0, "depth_m": 55.0},
	{"name": "CliffTunnel", "file": "azure_cliff_tunnel", "s": TUNNEL_S, "side": 0.0, "near_m": 0.0, "depth_m": 0.0},
	{"name": "YachtPack", "file": "superyacht_luxury_pack", "s": 2050.0, "side": -1.0, "near_m": 29.0, "depth_m": 60.0},
	{"name": "HarborSkybridge", "file": "harbor_pedestrian_skybridge", "s": SKYBRIDGE_S, "side": 0.0, "near_m": 0.0, "depth_m": 0.0},
]

var ribbon: TrackRibbonScript
var heroes: Dictionary = {}
## Height of the ground at (x, z); the casino and the hotel are seated on the lowest ground under their footprint.
var _ground: Callable


## Flat decks the terrain must leave under the heroes: the casino plaza and the hotel terrace reach from the road to the
## building at the road's own level, the tunnel and the skybridge stand on a deck either side of the road.
static func platforms() -> Array[Dictionary]:
	return [
		{"s0": 925.0, "s1": 1035.0, "side": 1.0, "lateral_from": 8.0, "lateral_to": 155.0, "level_s": 980.0},
		{"s0": 960.0, "s1": 1060.0, "side": -1.0, "lateral_from": 8.0, "lateral_to": 80.0, "level_s": 1010.0},
		{"s0": TUNNEL_S - 90.0, "s1": TUNNEL_S + 90.0, "side": 1.0, "lateral_from": 8.0, "lateral_to": 26.0},
		{"s0": TUNNEL_S - 90.0, "s1": TUNNEL_S + 90.0, "side": -1.0, "lateral_from": 8.0, "lateral_to": 26.0},
		{"s0": SKYBRIDGE_S - 20.0, "s1": SKYBRIDGE_S + 20.0, "side": 1.0, "lateral_from": 8.0, "lateral_to": 18.0},
		{"s0": SKYBRIDGE_S - 20.0, "s1": SKYBRIDGE_S + 20.0, "side": -1.0, "lateral_from": 8.0, "lateral_to": 18.0},
	]


func build(p_ribbon: TrackRibbonScript, ground: Callable) -> void:
	ribbon = p_ribbon
	_ground = ground
	for spec: Dictionary in HEROES:
		var hero: Node3D = _place(spec)
		if hero != null:
			add_child(hero)
			heroes[String(spec["name"])] = hero


func _place(spec: Dictionary) -> Node3D:
	var scene := load(MODEL_DIR + String(spec["file"]) + ".glb") as PackedScene
	if scene == null:
		push_error("MonteAzureLandmarks: cannot load %s" % spec["file"])
		return null
	var model := scene.instantiate() as Node3D
	# Measured before the surfaces are restyled: the tunnel's bore is found by its material's name ("dark").
	var bounds: AABB = _bounds(model)
	var bore: AABB = _bounds(model, "dark")
	if String(spec["name"]) == "CliffTunnel":
		_open_bore(model)
	_cel_shade(model)
	var s: float = float(spec["s"])
	var side: float = float(spec["side"])
	var lateral: float = side * (float(spec["near_m"]) + float(spec["depth_m"]) * 0.5)
	var road: Transform3D = ribbon.get_point_at_offset(s, lateral)
	var centre: Transform3D = ribbon.get_point_at_offset(s, 0.0)
	var forward: Vector3 = -centre.basis.z
	var yaw: float = atan2(-forward.z, forward.x)
	var scale := Vector3.ONE
	var anchor := Vector3(bounds.get_center().x, bounds.position.y, bounds.get_center().z)
	var base_y: float = centre.origin.y - DECK_DROP_M
	var basis := Basis(Vector3.UP, yaw)
	var hero_name: String = String(spec["name"])
	match hero_name:
		"CasinoPalace":
			# The facade is local +z: turn it to the road on the left.
			basis = Basis(Vector3.UP, yaw + PI)
			base_y = _footing_y(road.origin, basis, bounds)
		"GrandHotelFairmont":
			base_y = _footing_y(road.origin, basis, bounds)
		"CliffTunnel":
			scale = Vector3(TUNNEL_LENGTH_M / TUNNEL_MODEL_LENGTH_M, 1.0, 1.0)
			anchor = Vector3(bore.get_center().x, bore.position.y, bore.get_center().z)
			# The bore's floor 0.1 m under the road, so the two do not fight for the same pixels.
			base_y = centre.origin.y - 0.1
			var slope: float = (ribbon.get_point_at_offset(s + TUNNEL_SLOPE_HALF_SPAN_M, 0.0).origin.y - ribbon.get_point_at_offset(s - TUNNEL_SLOPE_HALF_SPAN_M, 0.0).origin.y) / (2.0 * TUNNEL_SLOPE_HALF_SPAN_M)
			basis = basis * Basis(Vector3.BACK, atan(slope))
		"HarborSkybridge":
			# The span runs along the model's x: across the road, not along it.
			var right: Vector3 = centre.basis.x
			basis = Basis(Vector3.UP, atan2(-right.z, right.x))
			scale = Vector3(SKYBRIDGE_SPAN_SCALE, SKYBRIDGE_HEIGHT_SCALE, 1.0)
		"YachtPack":
			base_y = YACHT_WATER_Y
	model.scale = scale
	model.position = -Vector3(anchor.x * scale.x, anchor.y * scale.y, anchor.z * scale.z)
	var wrapper := Node3D.new()
	wrapper.name = hero_name
	wrapper.transform = Transform3D(basis, Vector3(road.origin.x, base_y, road.origin.z))
	wrapper.add_child(model)
	wrapper.set_meta(&"arc_s", s)
	wrapper.set_meta(&"lateral_m", lateral)
	wrapper.set_meta(&"length_m", TUNNEL_LENGTH_M if hero_name == "CliffTunnel" else bounds.size.x * scale.x)
	return wrapper


## A building stands plumb while its plaza follows the road's profile, so it is seated 0.25 m under the lowest ground
## beneath its footprint: no corner floats, the high side sinks into the plaza.
func _footing_y(centre: Vector3, basis: Basis, bounds: AABB) -> float:
	var lowest: float = INF
	var half := Vector2(bounds.size.x, bounds.size.z) * 0.5
	for x: float in [-half.x, 0.0, half.x]:
		for z: float in [-half.y, 0.0, half.y]:
			var point: Vector3 = centre + basis * Vector3(x, 0.0, z)
			lowest = minf(lowest, float(_ground.call(point.x, point.z)))
	return lowest - 0.25


## The package closes the bore twice: a "dark" surface (two 1.2 m slabs painted as the opening) and, behind it, solid
## concrete portal blocks 3.5 m long across the whole 23 m x 10 m face. Cars drive through the tunnel here, so the slabs go
## and each portal block becomes a frame (two piers and a lintel) around the 15 m x 7.4 m bore. The faces that look into
## the bore (the reveals and the side wall) take a darker liner, so the opening reads as a hole against the pale facade.
func _open_bore(model: Node3D) -> void:
	for child: Node in model.find_children("*", "MeshInstance3D", true, false):
		var instance := child as MeshInstance3D
		var bore := AABB()
		for surface: int in range(instance.mesh.get_surface_count()):
			var plug: Material = instance.mesh.surface_get_material(surface)
			if plug != null and plug.resource_name == BORE_MATERIAL:
				bore = _surface_bounds(instance.mesh, surface)
		if bore.size == Vector3.ZERO:
			continue
		var open := ArrayMesh.new()
		var liner := _FaceList.new()
		for surface: int in range(instance.mesh.get_surface_count()):
			var material: Material = instance.mesh.surface_get_material(surface)
			if material != null and material.resource_name == BORE_MATERIAL:
				continue
			var arrays: Array = instance.mesh.surface_get_arrays(surface)
			var shell := _FaceList.new()
			if material != null and material.resource_name == PORTAL_MATERIAL:
				_strip_portal_blocks(arrays, bore, shell, liner)
			open.add_surface_from_arrays(instance.mesh.surface_get_primitive_type(surface), arrays)
			open.surface_set_material(open.get_surface_count() - 1, material)
			if not shell.positions.is_empty():
				open.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, shell.arrays())
				open.surface_set_material(open.get_surface_count() - 1, material)
		if not liner.positions.is_empty():
			var dark := StandardMaterial3D.new()
			dark.resource_name = LINER_MATERIAL
			dark.albedo_color = LINER_COLOR
			open.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, liner.arrays())
			open.surface_set_material(open.get_surface_count() - 1, dark)
		instance.mesh = open


## Drops the solid portal blocks (every triangle wholly within PORTAL_ZONE_M of a mouth) and the side wall's face (a long
## plane inside the bore) from `arrays`' index list. Each block comes back as `shell` + `liner` faces of its frame, the
## wall's face as `liner`.
func _strip_portal_blocks(arrays: Array, bore: AABB, shell: _FaceList, liner: _FaceList) -> void:
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var zone_x: float = bore.end.x - PORTAL_ZONE_M
	var kept := PackedInt32Array()
	var low: Dictionary = {}
	var high: Dictionary = {}
	var wall_z: float = INF
	for index: int in range(0, indices.size(), 3):
		var corners: Array[Vector3] = [vertices[indices[index]], vertices[indices[index + 1]], vertices[indices[index + 2]]]
		var side: float = signf(corners[0].x)
		var in_block: bool = true
		var in_wall: bool = true
		for corner: Vector3 in corners:
			in_block = in_block and signf(corner.x) == side and absf(corner.x) >= zone_x
			in_wall = in_wall and is_equal_approx(corner.z, corners[0].z) and corner.z > bore.position.z and corner.z < bore.end.z and corner.y <= bore.end.y
		if in_wall:
			wall_z = minf(wall_z, corners[0].z)
			for corner: int in range(3):
				liner.positions.append(corners[corner])
				liner.normals.append(normals[indices[index + corner]])
			continue
		if not in_block:
			kept.append_array(PackedInt32Array([indices[index], indices[index + 1], indices[index + 2]]))
			continue
		for corner: Vector3 in corners:
			low[side] = (low[side] as Vector3).min(corner) if low.has(side) else corner
			high[side] = (high[side] as Vector3).max(corner) if high.has(side) else corner
	arrays[Mesh.ARRAY_INDEX] = kept
	# The side wall is a closed slab that reaches into the bore's first 1.3 m, so the frame's near pier meets the wall's face.
	wall_z = bore.position.z if is_inf(wall_z) else wall_z
	var opening := AABB(Vector3(bore.position.x, bore.position.y, wall_z), Vector3(bore.size.x, bore.size.y, bore.end.z - wall_z))
	for side: float in low.keys():
		_portal_frame(AABB(low[side], (high[side] as Vector3) - (low[side] as Vector3)), opening, side, shell, liner)


## Flat-shaded frame around `bore` in one portal `block`'s volume: a pier either side, a lintel over the top. No floor
## faces (the road runs through) and every face wound clockwise seen from outside (Godot's front face). `side` is the
## mouth's sign along the tunnel, so the faces looking into the tunnel (the reveals, the block's inner face) go to `liner`.
func _portal_frame(block: AABB, bore: AABB, side: float, shell: _FaceList, liner: _FaceList) -> void:
	var boxes: Array[AABB] = [
		AABB(block.position, Vector3(block.size.x, block.size.y, bore.position.z - block.position.z)),
		AABB(Vector3(block.position.x, block.position.y, bore.end.z), Vector3(block.size.x, block.size.y, block.end.z - bore.end.z)),
		AABB(Vector3(block.position.x, bore.end.y, bore.position.z), Vector3(block.size.x, block.end.y - bore.end.y, bore.size.z)),
	]
	for box: AABB in boxes:
		for axis: int in range(3):
			for direction: float in [-1.0, 1.0]:
				if axis == 1 and direction < 0.0 and box.position.y <= block.position.y + 0.001:
					continue
				var normal := Vector3.ZERO
				normal[axis] = direction
				var origin: Vector3 = box.position
				origin[axis] = box.end[axis] if direction > 0.0 else box.position[axis]
				var u := Vector3.ZERO
				u[(axis + 1) % 3] = box.size[(axis + 1) % 3]
				var v := Vector3.ZERO
				v[(axis + 2) % 3] = box.size[(axis + 2) % 3]
				var quad: Array[Vector3] = [origin, origin + u, origin + u + v, origin + v]
				if (quad[1] - quad[0]).cross(quad[2] - quad[0]).dot(normal) > 0.0:
					quad = [quad[0], quad[3], quad[2], quad[1]]
				# Looks into the bore: the reveals (a pier's face toward the bore, the lintel's underside) and the block's
				# face on the tunnel side.
				var inward: bool = (axis == 2 and (direction > 0.0) == (box.end.z <= bore.position.z + 0.001) and box.size.y == block.size.y) \
						or (axis == 1 and direction < 0.0) or (axis == 0 and direction * side < 0.0)
				var target: _FaceList = liner if inward else shell
				for corner: int in [0, 1, 2, 0, 2, 3]:
					target.positions.append(quad[corner])
					target.normals.append(normal)


## Triangle soup with flat normals, as `add_surface_from_arrays` takes it.
class _FaceList:
	var positions := PackedVector3Array()
	var normals := PackedVector3Array()

	func arrays() -> Array:
		var surface: Array = []
		surface.resize(Mesh.ARRAY_MAX)
		surface[Mesh.ARRAY_VERTEX] = positions
		surface[Mesh.ARRAY_NORMAL] = normals
		return surface


## Every surface becomes a cel shader in the GLB's own colour, with the ink outline pass.
func _cel_shade(model: Node3D) -> void:
	for child: Node in model.find_children("*", "MeshInstance3D", true, false):
		var instance := child as MeshInstance3D
		instance.mesh = instance.mesh.duplicate() as Mesh
		for surface: int in range(instance.mesh.get_surface_count()):
			var source := instance.mesh.surface_get_material(surface) as BaseMaterial3D
			var color: Color = source.albedo_color if source != null else Color.WHITE
			instance.mesh.surface_set_material(surface, ToonMaterials.make(color, source == null or source.resource_name != LINER_MATERIAL))


## Bounds in the model's own frame (the glTF node offsets included); with `material_name`, only that surface's.
func _bounds(model: Node3D, material_name: String = "") -> AABB:
	var merged := AABB()
	var first: bool = true
	for child: Node in model.find_children("*", "MeshInstance3D", true, false):
		var instance := child as MeshInstance3D
		for surface: int in range(instance.mesh.get_surface_count()):
			var material: Material = instance.mesh.surface_get_material(surface)
			if material_name != "" and (material == null or material.resource_name != material_name):
				continue
			var box: AABB = instance.transform * _surface_bounds(instance.mesh, surface)
			merged = box if first else merged.merge(box)
			first = false
	return merged


static func _surface_bounds(mesh: Mesh, surface: int) -> AABB:
	var vertices: PackedVector3Array = mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]
	var low := Vector3(INF, INF, INF)
	var high := Vector3(-INF, -INF, -INF)
	for vertex: Vector3 in vertices:
		low = low.min(vertex)
		high = high.max(vertex)
	return AABB(low, high - low)
