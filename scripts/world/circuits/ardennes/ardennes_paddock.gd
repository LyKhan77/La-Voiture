class_name ArdennesPaddock
extends RefCounted

## The solid ground of Ardennes' paddock (mapgen sandbox, approved 2026-10-31): closed slabs that run from their top surface down
## below the terrain, so no sky or hillside void shows under the paddock deck behind the pit building, the race control tower's
## forecourt and service road, the parking apron or the two grandstands (a plinth under each). Every box is flat cel colour in one
## merged mesh, one draw call; a box stands on the road's own frame (the straight is flat here), its top a few cm off the road.

const MeshBatchScript := preload("res://scripts/world/shared/mesh_batch.gd")
const ToonMaterials := preload("res://scripts/world/shared/toon_materials.gd")
const Liveries := preload("res://scripts/car/team_liveries.gd")

## How far under the lowest terrain corner a slab reaches.
const SINK_M: float = 0.8
const TERRACE_COLOR := Color("#5f646d")
const CURB_COLOR := Color("#d7d9dd")
const PARKING_COLOR := Color("#6b7078")
const FORECOURT_COLOR := Color("#7c818a")
const ACCESS_COLOR := Color("#50555f")
const PLINTH_COLOR := Color("#8f939b")

## The building's block of ground behind the facade (lateral 20.6 to 94) from s -112 to s 122: the ten 20 m bays plus margins.
const TERRACE_S0: float = -112.0
const TERRACE_S1: float = 122.0
const TERRACE_LATERAL: Vector2 = Vector2(20.6, 94.0)
const PARKING_S: Vector2 = Vector2(190.0, 280.0)
const PARKING_LATERAL: Vector2 = Vector2(60.0, 85.0)
const TRAILER_COUNT: int = 6
## The race control tower's forecourt (24 x 28 m around its centre) and the 16 x 10 m service road joining it to the parking apron.
const TOWER_S: float = 150.0
const TOWER_LATERAL: float = 32.0
const FORECOURT_SIZE := Vector2(24.0, 28.0)
const ACCESS_SIZE := Vector2(16.0, 10.0)
const ACCESS_LATERAL: float = 52.0
const MAIN_STAND_S: float = 125.0
const MAIN_STAND_LATERAL: Vector2 = Vector2(18.0, 58.0)
const MAIN_STAND_LENGTH_M: float = 242.0
const GLASS_STAND_S: float = 5280.0
const GLASS_STAND_LATERAL: Vector2 = Vector2(30.0, 67.0)
const GLASS_STAND_LENGTH_M: float = 224.0

## The slabs built: {name, s, side, lateral0, lateral1, top (above the road), length}.
static func specs() -> Array[Dictionary]:
	return [
		{"name": "PaddockTerrace", "s": (TERRACE_S0 + TERRACE_S1) * 0.5, "side": 1.0, "lateral0": TERRACE_LATERAL.x, "lateral1": TERRACE_LATERAL.y, "top": -0.07, "length": TERRACE_S1 - TERRACE_S0, "color": TERRACE_COLOR},
		{"name": "PaddockCurb", "s": (TERRACE_S0 + TERRACE_S1) * 0.5, "side": 1.0, "lateral0": TERRACE_LATERAL.y - 0.6, "lateral1": TERRACE_LATERAL.y, "top": 0.12, "length": TERRACE_S1 - TERRACE_S0, "color": CURB_COLOR},
		{"name": "PaddockParking", "s": (PARKING_S.x + PARKING_S.y) * 0.5, "side": 1.0, "lateral0": PARKING_LATERAL.x, "lateral1": PARKING_LATERAL.y, "top": -0.05, "length": PARKING_S.y - PARKING_S.x, "color": PARKING_COLOR},
		{"name": "RaceControlForecourt", "s": TOWER_S, "side": 1.0, "lateral0": TOWER_LATERAL - FORECOURT_SIZE.x * 0.5, "lateral1": TOWER_LATERAL + FORECOURT_SIZE.x * 0.5, "top": 0.07, "length": FORECOURT_SIZE.y, "color": FORECOURT_COLOR},
		{"name": "RaceControlAccess", "s": TOWER_S, "side": 1.0, "lateral0": TOWER_LATERAL + FORECOURT_SIZE.x * 0.5, "lateral1": PARKING_LATERAL.x, "top": -0.05, "length": ACCESS_SIZE.y, "color": ACCESS_COLOR},
		{"name": "Plinth_MainGrandstand", "s": MAIN_STAND_S, "side": -1.0, "lateral0": MAIN_STAND_LATERAL.x, "lateral1": MAIN_STAND_LATERAL.y, "top": 0.04, "length": MAIN_STAND_LENGTH_M, "color": PLINTH_COLOR},
		{"name": "Plinth_GlassTerrace", "s": GLASS_STAND_S, "side": -1.0, "lateral0": GLASS_STAND_LATERAL.x, "lateral1": GLASS_STAND_LATERAL.y, "top": 0.04, "length": GLASS_STAND_LENGTH_M, "color": PLINTH_COLOR},
	]


## Builds the slabs under `parent`; returns the footprints {name, s0, s1, lat0, lat1} (signed lateral, + right) for clearance tests.
static func build(parent: Node3D, ribbon, terrain) -> Array[Dictionary]:
	var batch := MeshBatchScript.new()
	var material: Material = ToonMaterials.vertex_colored(false)
	var footprints: Array[Dictionary] = []
	for spec: Dictionary in specs():
		var side: float = float(spec["side"])
		var s: float = float(spec["s"])
		var length: float = float(spec["length"])
		var lateral0: float = float(spec["lateral0"])
		var lateral1: float = float(spec["lateral1"])
		var centre: Transform3D = ribbon.get_point_at_offset(s, side * (lateral0 + lateral1) * 0.5)
		var top: float = ribbon.get_point_at_offset(s, 0.0).origin.y + float(spec["top"])
		var width: float = lateral1 - lateral0
		var lowest: float = INF
		for sx: float in [-0.5, 0.5]:
			for sz: float in [-0.5, 0.5]:
				var corner: Vector3 = centre.origin + centre.basis.x * (sx * width) + centre.basis.z * (sz * length)
				lowest = minf(lowest, float(terrain.height_at(corner.x, corner.z)))
		var bottom: float = minf(lowest - SINK_M, top - 1.0)
		batch.box(material, spec["color"], Transform3D(centre.basis, Vector3(centre.origin.x, (top + bottom) * 0.5, centre.origin.z)), Vector3(width, top - bottom, length))
		footprints.append({"name": spec["name"], "s0": s - length * 0.5, "s1": s + length * 0.5, "lat0": side * lateral0, "lat1": side * lateral1})
	var mesh := MeshInstance3D.new()
	mesh.name = "PaddockSolids"
	mesh.mesh = batch.commit()
	parent.add_child(mesh)
	_build_trailers(parent, ribbon)
	return footprints


## Six white support trailers with team stripes on the parking apron, parked on white bay lines (sandbox paddock dressing).
static func _build_trailers(parent: Node3D, ribbon) -> void:
	var batch := MeshBatchScript.new()
	var flat: Material = ToonMaterials.vertex_colored(false)
	var lateral: float = (PARKING_LATERAL.x + PARKING_LATERAL.y) * 0.5
	for index: int in range(TRAILER_COUNT):
		var s: float = PARKING_S.x + 10.0 + float(index) * 14.0
		var pose: Transform3D = ribbon.get_point_at_offset(s, lateral)
		var base: Vector3 = pose.origin - Vector3.UP * 0.05
		batch.box(flat, Color("#e6e8ec"), Transform3D(pose.basis, base + Vector3.UP * 1.75), Vector3(4.2, 3.5, 11.0))
		batch.box(flat, Liveries.color_for(index + 2), Transform3D(pose.basis, base + Vector3.UP * 2.4), Vector3(4.25, 0.5, 11.0))
		batch.box(flat, Color("#9aa1ae"), Transform3D(pose.basis, base + Vector3.UP * 3.55), Vector3(4.4, 0.25, 11.4))
		var line: Transform3D = ribbon.get_point_at_offset(s - 7.0, lateral)
		batch.box(flat, Color("#f4f5f7"), Transform3D(line.basis, line.origin - Vector3.UP * 0.03), Vector3(20.0, 0.04, 0.16))
	var mesh := MeshInstance3D.new()
	mesh.name = "PaddockTrailers"
	mesh.mesh = batch.commit()
	parent.add_child(mesh)
