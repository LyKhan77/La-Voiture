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


## Every surface becomes a cel shader in the GLB's own colour, with the ink outline pass.
func _cel_shade(model: Node3D) -> void:
	for child: Node in model.find_children("*", "MeshInstance3D", true, false):
		var instance := child as MeshInstance3D
		instance.mesh = instance.mesh.duplicate() as Mesh
		for surface: int in range(instance.mesh.get_surface_count()):
			var source := instance.mesh.surface_get_material(surface) as BaseMaterial3D
			var color: Color = source.albedo_color if source != null else Color.WHITE
			instance.mesh.surface_set_material(surface, ToonMaterials.make(color, true))


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
