class_name MonteAzureTerrain
extends RefCounted

## The ground of Monte Azure Marina: one heightfield over the whole loop and its harbour (SPEC 4.4 item 1).
##
## Every road station is the tip of a cone: the ground is flat 0.16 m under the road out to FLAT_R_M, then falls away at
## SLOPE, so a climb to the casino terrace (42 m) becomes a hillside and a low quay stays a flat deck. The terrain is the
## highest of all the cones (a hill around one leg never buries another: each road then cuts its own bed back to 0.16 m
## under itself). Platforms (pit deck, grandstand quay) and pads (hero landmark footings) are more flat-topped sources.
## The land is the inside of the loop plus a quay of `shore_width_m` on the harbour side; beyond it the ground drops to a
## seabed under the toon water at y=0.

const MeshBatchScript := preload("res://scripts/world/shared/mesh_batch.gd")
const ToonMaterials := preload("res://scripts/world/shared/toon_materials.gd")
const Zones := preload("res://scripts/world/circuits/monte_azure/monte_azure_zones.gd")

const CELL_M: float = 8.0
const MARGIN_M: float = 260.0
const STATION_STEP_M: float = 6.0
const SEA_Y: float = 0.0
const LAND_FLOOR_Y: float = 0.3
const ROAD_DROP_M: float = 0.16
const DECK_DROP_M: float = 0.2
const FLAT_R_M: float = 8.0
const DECK_FLAT_R_M: float = 6.0
const SLOPE: float = 0.26
const PAD_SLOPE: float = 0.38
const BED_R_M: float = 14.0
const BANK_SLOPE: float = 0.55
const SEABED_Y: float = -8.0
const SEABED_SLOPE: float = 0.7
const SEABED_FIRST_Y: float = -0.8
const CLIFF_SLOPE: float = 0.55

enum Kind { ROAD, DECK, PAD }

const GROUND_TINT := Color(0.7, 0.7, 0.7, 1.0)
const COLOR_PAVED := Color("#777b82")
const COLOR_DECK := Color("#a29e94")
const COLOR_YARD := Color("#a99f86")
const COLOR_PAD := Color("#c2b48e")
const COLOR_URBAN := Color("#c9b48a")
const COLOR_FOREST := Color("#4f8a43")
const COLOR_QUAY := Color("#c4beb0")
const COLOR_SEAWALL := Color("#8a867c")
const COLOR_ROCK := Color("#7d7a70")
const COLOR_SEABED := Color("#2f6d82")

var x0: float = 0.0
var z0: float = 0.0
var nx: int = 0
var nz: int = 0
var heights: PackedFloat32Array = PackedFloat32Array()
var triangle_count: int = 0

## One entry per road station (every STATION_STEP_M): position on the road, arc distance, and the right-hand unit vector.
var station_pos: Array[Vector3] = []
var station_s: PackedFloat32Array = PackedFloat32Array()
var station_right: Array[Vector2] = []

var _land: PackedByteArray = PackedByteArray()
var _winner: PackedInt32Array = PackedInt32Array()
## Per source: [kind, station index (or -1)].
var _source_kind: PackedInt32Array = PackedInt32Array()
var _source_station: PackedInt32Array = PackedInt32Array()
var _hash: Dictionary = {}
var _length_m: float = 1.0


## Width of the quay on the harbour (left) side at arc `s`: wide before the grandstand, then the town and hill (land all
## the way), then a narrow working quay along the marina where the yachts moor.
static func shore_width_m(s: float, length_m: float = 2850.0) -> float:
	var wrapped: float = fposmod(s, length_m)
	if wrapped < 220.0 or wrapped > 2790.0:
		return 78.0
	if wrapped < 320.0:
		return lerpf(78.0, 28.0, smoothstep(220.0, 320.0, wrapped))
	if wrapped >= 480.0 and wrapped <= 1580.0:
		return 180.0
	return 28.0


## Builds the heightfield against `ribbon`. `platforms` are the pit complex's ground_platforms() ({s0, s1, side,
## lateral_from, lateral_to}); `pads` are landmark footings ({centre: Vector3 (y = base), half: Vector2, yaw: float}).
func build(ribbon, platforms: Array[Dictionary], pads: Array[Dictionary]) -> void:
	_length_m = ribbon.length_m
	_sample_stations(ribbon)
	var low := Vector2(INF, INF)
	var high := Vector2(-INF, -INF)
	var polygon := PackedVector2Array()
	for p: Vector3 in station_pos:
		polygon.append(Vector2(p.x, p.z))
		low = low.min(polygon[-1])
		high = high.max(polygon[-1])
	low -= Vector2.ONE * MARGIN_M
	high += Vector2.ONE * MARGIN_M
	x0 = floorf(low.x / CELL_M) * CELL_M
	z0 = floorf(low.y / CELL_M) * CELL_M
	nx = ceili((high.x - x0) / CELL_M) + 1
	nz = ceili((high.y - z0) / CELL_M) + 1
	var count: int = nx * nz
	heights.resize(count)
	heights.fill(SEABED_Y)
	_land.resize(count)
	_land.fill(0)
	_winner.resize(count)
	_winner.fill(-1)

	_mark_land(polygon)
	_seabed()
	var sources: Array[Vector4] = [] # x, z, top y, flat radius; slope by kind
	_add_road_sources(sources)
	_add_platform_sources(ribbon, platforms, sources)
	_add_pad_sources(pads, sources)
	_splat(sources)
	_cut_beds()


func height_at(x: float, z: float) -> float:
	var fx: float = (x - x0) / CELL_M
	var fz: float = (z - z0) / CELL_M
	if fx < 0.0 or fz < 0.0 or fx >= float(nx - 1) or fz >= float(nz - 1):
		return SEABED_Y
	var ix: int = int(fx)
	var iz: int = int(fz)
	var tx: float = fx - float(ix)
	var tz: float = fz - float(iz)
	# The mesh splits each cell into the triangles (a, b, c) and (a, c, d); the same split keeps this exact.
	var a: float = heights[iz * nx + ix]
	var b: float = heights[iz * nx + ix + 1]
	var c: float = heights[(iz + 1) * nx + ix + 1]
	var d: float = heights[(iz + 1) * nx + ix]
	if tx >= tz:
		return a + (b - a) * tx + (c - b) * tz
	return a + (c - d) * tx + (d - a) * tz


## True where the nearest grid cell belongs to a deck (pit, paddock, quay, a hero plaza or the tunnel's feet) or a pad.
func is_deck_at(x: float, z: float) -> bool:
	var ix: int = roundi((x - x0) / CELL_M)
	var iz: int = roundi((z - z0) / CELL_M)
	if ix < 0 or iz < 0 or ix >= nx or iz >= nz:
		return false
	var winner: int = _winner[iz * nx + ix]
	return winner >= 0 and _source_kind[winner] != Kind.ROAD


## The index of the road station nearest to a world point (flat distance), or -1 beyond 400 m of any road.
func nearest_station(x: float, z: float) -> int:
	var cell := Vector2i(floori(x / 48.0), floori(z / 48.0))
	var best: int = -1
	var best_sq: float = INF
	for ring: int in range(9):
		for dx: int in range(-ring, ring + 1):
			for dz: int in range(-ring, ring + 1):
				if maxi(absi(dx), absi(dz)) != ring:
					continue
				var key := cell + Vector2i(dx, dz)
				if not _hash.has(key):
					continue
				for index: int in _hash[key]:
					var sq: float = Vector2(station_pos[index].x - x, station_pos[index].z - z).length_squared()
					if sq < best_sq:
						best_sq = sq
						best = index
		# A hit in ring r is the nearest unless a closer one waits in ring r + 1 (cells are 48 m wide).
		if best >= 0 and sqrt(best_sq) <= float(ring) * 48.0:
			break
	return best


## The strip zone at a world point: the nearest road station's arc and the side of the road the point is on.
func zone_at_point(x: float, z: float) -> String:
	var index: int = nearest_station(x, z)
	if index < 0:
		return Zones.DEFAULT_ZONE
	var side: float = signf(Vector2(x - station_pos[index].x, z - station_pos[index].z).dot(station_right[index]))
	return Zones.zone_at(station_s[index], side if side != 0.0 else 1.0)


## Flat-shaded cel mesh of the whole field; deep open water is left out (the water plane covers it).
func make_mesh() -> ArrayMesh:
	var batch := MeshBatchScript.new()
	# The shared cel shader with its own tint: broad ground in the set's pale paints clips to white under the sun.
	var material: ShaderMaterial = ToonMaterials.vertex_colored(false).duplicate() as ShaderMaterial
	material.set_shader_parameter("tint", GROUND_TINT)
	triangle_count = 0
	for iz: int in range(nz - 1):
		for ix: int in range(nx - 1):
			var i: int = iz * nx + ix
			var ha: float = heights[i]
			var hb: float = heights[i + 1]
			var hc: float = heights[i + nx + 1]
			var hd: float = heights[i + nx]
			if maxf(maxf(ha, hb), maxf(hc, hd)) <= SEABED_Y + 0.5:
				continue
			var a := Vector3(x0 + float(ix) * CELL_M, ha, z0 + float(iz) * CELL_M)
			var b := Vector3(a.x + CELL_M, hb, a.z)
			var c := Vector3(b.x, hc, a.z + CELL_M)
			var d := Vector3(a.x, hd, c.z)
			# a, b, c, d run a -> +x -> +x+z -> +z, so (c - a) x (b - a) is the upward face normal.
			var normal: Vector3 = (c - a).cross(b - a).normalized() + (d - a).cross(c - a).normalized()
			batch.quad(material, _cell_color(i, ix, iz), a, b, c, d, normal.normalized())
			triangle_count += 2
	return batch.commit()


# --- build steps --------------------------------------------------------------------------------

func _sample_stations(ribbon) -> void:
	station_pos.clear()
	station_right.clear()
	var count: int = ceili(_length_m / STATION_STEP_M)
	station_s.resize(count)
	_hash.clear()
	for index: int in range(count):
		var s: float = _length_m * float(index) / float(count)
		var pose: Transform3D = ribbon.get_point_at_offset(s, 0.0)
		station_pos.append(pose.origin)
		station_s[index] = s
		var right := Vector2(pose.basis.x.x, pose.basis.x.z).normalized()
		station_right.append(right)
		var key := Vector2i(floori(pose.origin.x / 48.0), floori(pose.origin.z / 48.0))
		if not _hash.has(key):
			_hash[key] = []
		(_hash[key] as Array).append(index)


## Land = the inside of the loop, plus the harbour-side quay strip beside every station.
func _mark_land(polygon: PackedVector2Array) -> void:
	for iz: int in range(nz):
		for ix: int in range(nx):
			var p := Vector2(x0 + float(ix) * CELL_M, z0 + float(iz) * CELL_M)
			if Geometry2D.is_point_in_polygon(p, polygon):
				_land[iz * nx + ix] = 1
	# A half disc on the left of every station: a thin strip per station would leave gaps (a comb) where the road turns
	# sharply and the strips fan out.
	for index: int in range(station_pos.size()):
		var reach: float = shore_width_m(station_s[index], _length_m)
		var centre := Vector2(station_pos[index].x, station_pos[index].z)
		var cx: int = roundi((centre.x - x0) / CELL_M)
		var cz: int = roundi((centre.y - z0) / CELL_M)
		var span: int = ceili(reach / CELL_M) + 1
		for iz: int in range(maxi(0, cz - span), mini(nz, cz + span + 1)):
			for ix: int in range(maxi(0, cx - span), mini(nx, cx + span + 1)):
				var offset := Vector2(x0 + float(ix) * CELL_M, z0 + float(iz) * CELL_M) - centre
				if offset.length() <= reach and offset.dot(station_right[index]) <= 0.0:
					_land[iz * nx + ix] = 1


## The seabed deepens with distance from the quay: a chamfer distance transform over the grid, then a slope.
func _seabed() -> void:
	var distance := PackedFloat32Array()
	distance.resize(nx * nz)
	distance.fill(1.0e6)
	for i: int in range(nx * nz):
		if _land[i] == 1:
			distance[i] = 0.0
	var diagonal: float = 1.4142
	for iz: int in range(nz):
		for ix: int in range(nx):
			var i: int = iz * nx + ix
			var best: float = distance[i]
			if ix > 0:
				best = minf(best, distance[i - 1] + 1.0)
			if iz > 0:
				best = minf(best, distance[i - nx] + 1.0)
				if ix > 0:
					best = minf(best, distance[i - nx - 1] + diagonal)
				if ix < nx - 1:
					best = minf(best, distance[i - nx + 1] + diagonal)
			distance[i] = best
	for iz: int in range(nz - 1, -1, -1):
		for ix: int in range(nx - 1, -1, -1):
			var i: int = iz * nx + ix
			var best: float = distance[i]
			if ix < nx - 1:
				best = minf(best, distance[i + 1] + 1.0)
			if iz < nz - 1:
				best = minf(best, distance[i + nx] + 1.0)
				if ix < nx - 1:
					best = minf(best, distance[i + nx + 1] + diagonal)
				if ix > 0:
					best = minf(best, distance[i + nx - 1] + diagonal)
			distance[i] = best
	for i: int in range(nx * nz):
		if _land[i] == 1:
			heights[i] = LAND_FLOOR_Y
		else:
			heights[i] = maxf(SEABED_Y, SEABED_FIRST_Y - (distance[i] - 1.0) * CELL_M * SEABED_SLOPE)


func _add_road_sources(sources: Array[Vector4]) -> void:
	_source_kind.clear()
	_source_station.clear()
	for index: int in range(station_pos.size()):
		var p: Vector3 = station_pos[index]
		sources.append(Vector4(p.x, p.z, p.y - ROAD_DROP_M, FLAT_R_M))
		_source_kind.append(Kind.ROAD)
		_source_station.append(index)


## Flat decks beside the road: the sources sit every 6 m across and along the strip and stand DECK_DROP_M under the road;
## a platform with a "level_s" is dead level at the road's height there (the terrace of a building that stands plumb).
func _add_platform_sources(ribbon, platforms: Array[Dictionary], sources: Array[Vector4]) -> void:
	for platform: Dictionary in platforms:
		var side: float = float(platform["side"])
		var s0: float = float(platform["s0"])
		var span: float = fposmod(float(platform["s1"]) - s0, _length_m)
		var level_y: float = INF
		if platform.has("level_s"):
			level_y = ribbon.get_point_at_offset(float(platform["level_s"]), 0.0).origin.y
		var along: float = 0.0
		while along <= span:
			var s: float = fposmod(s0 + along, _length_m)
			var pose: Transform3D = ribbon.get_point_at_offset(s, 0.0)
			var top: float = (pose.origin.y if level_y == INF else level_y) - DECK_DROP_M
			var lateral: float = float(platform["lateral_from"])
			while lateral <= float(platform["lateral_to"]):
				var at: Vector3 = pose.origin + pose.basis.x * side * lateral
				sources.append(Vector4(at.x, at.z, top, DECK_FLAT_R_M))
				_source_kind.append(Kind.DECK)
				_source_station.append(clampi(roundi(s / STATION_STEP_M), 0, station_pos.size() - 1))
				lateral += 6.0
			along += 6.0


## Footings under hero landmarks: a flat-topped square (rotated by `yaw`) a little under the building's base.
func _add_pad_sources(pads: Array[Dictionary], sources: Array[Vector4]) -> void:
	for pad: Dictionary in pads:
		var centre: Vector3 = pad["centre"]
		var half: Vector2 = pad["half"]
		var rotation := Basis(Vector3.UP, float(pad["yaw"]))
		var x: float = -half.x
		while x <= half.x + 0.01:
			var z: float = -half.y
			while z <= half.y + 0.01:
				var at: Vector3 = centre + rotation * Vector3(x, 0.0, z)
				sources.append(Vector4(at.x, at.z, centre.y - 0.12, 4.0))
				_source_kind.append(Kind.PAD)
				_source_station.append(-1)
				z += 5.0
			x += 5.0


## The highest source wins every land cell within its reach.
func _splat(sources: Array[Vector4]) -> void:
	for index: int in range(sources.size()):
		var source: Vector4 = sources[index]
		var slope: float = PAD_SLOPE if _source_kind[index] == Kind.PAD else SLOPE
		var reach: float = source.w + maxf(0.0, source.z - LAND_FLOOR_Y) / slope
		var cx: int = roundi((source.x - x0) / CELL_M)
		var cz: int = roundi((source.y - z0) / CELL_M)
		var span: int = ceili(reach / CELL_M) + 1
		for iz: int in range(maxi(0, cz - span), mini(nz, cz + span + 1)):
			for ix: int in range(maxi(0, cx - span), mini(nx, cx + span + 1)):
				var i: int = iz * nx + ix
				if _land[i] == 0:
					continue
				var distance: float = Vector2(x0 + float(ix) * CELL_M - source.x, z0 + float(iz) * CELL_M - source.y).length()
				var top: float = source.z - maxf(0.0, distance - source.w) * slope
				if top > heights[i]:
					heights[i] = top
					_winner[i] = index


## Every road cuts its own bed: within BED_R_M of a station the ground is at most 0.16 m under that road, so a hill or a
## level terrace raised by another leg never buries it, and beyond the bed it may rise only BANK_SLOPE (a steep bank, not
## a wall). The bed is wider than road edge + one cell, so no triangle that holds a road point has a vertex above it.
func _cut_beds() -> void:
	var reach: float = BED_R_M + 24.0 / BANK_SLOPE
	var span: int = ceili(reach / CELL_M) + 1
	for index: int in range(station_pos.size()):
		var p: Vector3 = station_pos[index]
		var cx: int = roundi((p.x - x0) / CELL_M)
		var cz: int = roundi((p.z - z0) / CELL_M)
		for iz: int in range(maxi(0, cz - span), mini(nz, cz + span + 1)):
			for ix: int in range(maxi(0, cx - span), mini(nx, cx + span + 1)):
				var i: int = iz * nx + ix
				if _land[i] == 0:
					continue
				var distance: float = Vector2(x0 + float(ix) * CELL_M - p.x, z0 + float(iz) * CELL_M - p.z).length()
				var limit: float = p.y - ROAD_DROP_M + maxf(0.0, distance - BED_R_M) * BANK_SLOPE
				if heights[i] > limit:
					heights[i] = limit


# --- colour -------------------------------------------------------------------------------------

func _cell_color(i: int, ix: int, iz: int) -> Color:
	if _land[i] == 0:
		return COLOR_SEABED
	var winner: int = _winner[i]
	var kind: int = _source_kind[winner] if winner >= 0 else Kind.ROAD
	if kind == Kind.DECK:
		return COLOR_DECK
	if kind == Kind.PAD:
		return COLOR_PAD
	# The quay's edge cells, next to open water, read as a dark seawall.
	if (ix > 0 and _land[i - 1] == 0) or (ix < nx - 1 and _land[i + 1] == 0) or (iz > 0 and _land[i - nx] == 0) or (iz < nz - 1 and _land[i + nx] == 0):
		return COLOR_SEAWALL
	var slope: float = _slope_at(ix, iz)
	if slope > CLIFF_SLOPE:
		return COLOR_ROCK
	var station: int = _source_station[winner] if winner >= 0 else nearest_station(x0 + float(ix) * CELL_M, z0 + float(iz) * CELL_M)
	if station < 0:
		return COLOR_URBAN
	var offset := Vector2(x0 + float(ix) * CELL_M - station_pos[station].x, z0 + float(iz) * CELL_M - station_pos[station].z)
	if offset.length() <= 7.0:
		return COLOR_PAVED
	var side: float = signf(offset.dot(station_right[station]))
	match Zones.zone_at(station_s[station], side if side != 0.0 else 1.0):
		"forest":
			return COLOR_FOREST
		"water":
			return COLOR_QUAY
		"paddock":
			return COLOR_YARD
	return COLOR_URBAN


func _slope_at(ix: int, iz: int) -> float:
	var i: int = iz * nx + ix
	var steepest: float = 0.0
	if ix < nx - 1:
		steepest = maxf(steepest, absf(heights[i + 1] - heights[i]))
	if iz < nz - 1:
		steepest = maxf(steepest, absf(heights[i + nx] - heights[i]))
	return steepest / CELL_M
