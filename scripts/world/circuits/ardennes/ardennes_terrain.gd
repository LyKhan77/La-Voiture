class_name ArdennesTerrain
extends RefCounted

## The ground of Ardennes Valley Ring: one heightfield over the circuit and a wide hillside backdrop (mapgen sandbox terrain,
## approved 2026-10-31). A smooth valley/ridge field is fitted to the road's own profile (the 104 m climb), every metre of
## asphalt gets a bed 0.16 m under it with a 26 m flat corridor and a 38 m blend back to the hill (the Civil Continuity Law:
## 0 floating road), the pit deck and the grandstand terraces are flat decks, both stands stand in rectangular cuts with feathered
## slopes, a river valley is carved beside the climb, and a ridge ring closes the horizon.
##
## Every triangle is wound clockwise seen from above (Godot's front face): a terrain wound the other way is culled and shows the
## sky through the hills, and `get_faces()` does not see the difference (tests/test_ardennes_terrain_gate.gd #G14).
## Deterministic: the same ribbon always builds the same mesh. The field's heights are absolute: a deck's y is the road's own
## y minus the bed, applied once.

const ToonMaterials := preload("res://scripts/world/shared/toon_materials.gd")
const Zones := preload("res://scripts/world/circuits/ardennes/ardennes_zones.gd")
const TerrainShader := preload("res://shaders/ardennes_terrain_mottle.gdshader")
const WaterShader := preload("res://shaders/neo_wangan_water.gdshader")

const CELL_M: float = 12.0
## The loop spans x -328..641 and z 0..1840; the field reaches 370 m past it, the ridge ring and the skirt do the rest.
const MIN_X: float = -700.0
const MAX_X: float = 1040.0
const MIN_Z: float = -360.0
const MAX_Z: float = 2210.0
const COARSE_STEP_M: float = 16.0
const FIELD_STEP_M: float = 30.0
const STAMP_STEP_M: float = 2.0
const ROAD_DROP_M: float = 0.16
const CORRIDOR_FLAT_M: float = 26.0
const CORRIDOR_BLEND_END_M: float = 64.0
const NEAREST_STEP_M: float = 8.0
const HASH_CELL_M: float = 48.0
## The centre of the bowl the circuit sits in, for the outer massif and the ridge ring.
const BOWL_CENTRE := Vector2(170.0, 925.0)

const GROUND_TINT := Color(0.66, 0.7, 0.64, 1.0)
const GRASS_A := Color("#567f48")
const GRASS_B := Color("#3f6338")
const FOREST_FLOOR := Color("#2f4a2b")
const ROCK_A := Color("#6f675a")
const ROCK_B := Color("#565043")
const SAND := Color("#a99b78")
const PAD_COLOR := Color("#7c818a")
const RIDGE_A := Color("#516d61")
const RIDGE_B := Color("#6b877a")
const SKIRT_COLOR := Color("#3d5145")

## The river runs on the left of the climb between these stations, from WATER_INNER_M to WATER_OUTER_M off the racing line.
const WATER_LEVEL_M: float = 14.0
const WATER_S0: float = 450.0
const WATER_S1: float = 920.0
const WATER_INNER_M: float = 32.0
const WATER_OUTER_M: float = 228.0
## The acoustic canopy tunnel stands on the road here; the ridge it cuts through is a pine bank on both sides.
const TUNNEL_BANK_S0: float = 2660.0
const TUNNEL_BANK_S1: float = 2840.0

var ribbon
var heightgrid: Dictionary = {}
var terrain_mesh: ArrayMesh
var water_mesh: ArrayMesh
var ridge_mesh: ArrayMesh
var skirt_mesh: ArrayMesh
var water_level: float = WATER_LEVEL_M
var triangle_count: int = 0
var bbox := Rect2(Vector2(MIN_X, MIN_Z), Vector2(MAX_X - MIN_X, MAX_Z - MIN_Z))

var _length_m: float = 1.0
var _points := PackedVector3Array() # the centreline every metre
var _coarse := PackedVector3Array()
var _stations := PackedVector3Array() # every NEAREST_STEP_M
var _station_s := PackedFloat32Array()
var _hash: Dictionary = {}
var _field := PackedFloat32Array()
var _field_nx: int = 0
var _field_nz: int = 0
var _noise: FastNoiseLite
var _noise_fine: FastNoiseLite
var _platforms: Array[Dictionary] = []
var _rects: Array[Dictionary] = []


## Builds the field against `p_ribbon`. `platforms` are flat decks {s0, s1, side, lateral_from, lateral_to} (s0 > s1 wraps the
## start line); `rects` are stand footprints {s, side, lateral, width, length} (centre `lateral` off the racing line).
func build(p_ribbon, platforms: Array[Dictionary], rects: Array[Dictionary]) -> void:
	ribbon = p_ribbon
	_length_m = ribbon.length_m
	_platforms = platforms
	_rects = rects
	_noise = FastNoiseLite.new()
	_noise.seed = 20261030
	_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_noise.frequency = 0.0035
	_noise.fractal_octaves = 4
	_noise.fractal_gain = 0.48
	_noise_fine = FastNoiseLite.new()
	_noise_fine.seed = 20261031
	_noise_fine.noise_type = FastNoiseLite.TYPE_SIMPLEX
	_noise_fine.frequency = 0.018
	_noise_fine.fractal_octaves = 2
	_sample_road()
	_build_field()
	_build_heightgrid()


func _sample_road() -> void:
	_points.clear()
	_coarse.clear()
	_stations.clear()
	_station_s.clear()
	_hash.clear()
	var count: int = int(floorf(_length_m))
	for index: int in range(count):
		var point: Vector3 = ribbon.get_point_at_offset(float(index), 0.0).origin
		_points.append(point)
		if index % int(COARSE_STEP_M) == 0:
			_coarse.append(point)
		if index % int(NEAREST_STEP_M) == 0:
			var key := Vector2i(floori(point.x / HASH_CELL_M), floori(point.z / HASH_CELL_M))
			if not _hash.has(key):
				_hash[key] = []
			(_hash[key] as Array).append(_stations.size())
			_stations.append(point)
			_station_s.append(float(index))


# --- field -----------------------------------------------------------------------------------------

func _build_field() -> void:
	_field_nx = int(ceilf(bbox.size.x / FIELD_STEP_M)) + 1
	_field_nz = int(ceilf(bbox.size.y / FIELD_STEP_M)) + 1
	_field.resize(_field_nx * _field_nz)
	for iz: int in range(_field_nz):
		var z: float = bbox.position.y + float(iz) * FIELD_STEP_M
		for ix: int in range(_field_nx):
			var x: float = bbox.position.x + float(ix) * FIELD_STEP_M
			var sum: float = 0.0
			var weight: float = 0.0
			for sample: Vector3 in _coarse:
				var dx: float = sample.x - x
				var dz: float = sample.z - z
				var w: float = 1.0 / (dx * dx + dz * dz + 900.0)
				sum += sample.y * w
				weight += w
			var height: float = sum / weight
			# Outer massif: the circuit sits in a bowl, hills rise beyond the rim.
			height += 26.0 * _smooth((Vector2(x, z).distance_to(BOWL_CENTRE) - 520.0) / 620.0)
			_field[iz * _field_nx + ix] = height


func _field_height(x: float, z: float) -> float:
	var fx: float = (x - bbox.position.x) / FIELD_STEP_M
	var fz: float = (z - bbox.position.y) / FIELD_STEP_M
	var ix: int = clampi(int(floorf(fx)), 0, _field_nx - 2)
	var iz: int = clampi(int(floorf(fz)), 0, _field_nz - 2)
	var tx: float = clampf(fx - float(ix), 0.0, 1.0)
	var tz: float = clampf(fz - float(iz), 0.0, 1.0)
	var a: float = lerpf(_field[iz * _field_nx + ix], _field[iz * _field_nx + ix + 1], tx)
	var b: float = lerpf(_field[(iz + 1) * _field_nx + ix], _field[(iz + 1) * _field_nx + ix + 1], tx)
	return lerpf(a, b, tz)


func _natural_height(x: float, z: float) -> float:
	return _field_height(x, z) + _noise.get_noise_2d(x, z) * 20.0 + _noise_fine.get_noise_2d(x, z) * 2.6


# --- height grid -----------------------------------------------------------------------------------

func _build_heightgrid() -> void:
	var nx: int = int(roundf(bbox.size.x / CELL_M)) + 1
	var nz: int = int(roundf(bbox.size.y / CELL_M)) + 1
	var heights := PackedFloat32Array()
	heights.resize(nx * nz)
	var originals := PackedFloat32Array()
	originals.resize(nx * nz)
	var near_dist := PackedFloat32Array()
	near_dist.resize(nx * nz)
	near_dist.fill(INF)
	var near_index := PackedInt32Array()
	near_index.resize(nx * nz)
	near_index.fill(-1)
	var pad_mask := PackedByteArray()
	pad_mask.resize(nx * nz)
	var water_mask := PackedByteArray()
	water_mask.resize(nx * nz)
	for iz: int in range(nz):
		var z: float = bbox.position.y + float(iz) * CELL_M
		for ix: int in range(nx):
			var h: float = _natural_height(bbox.position.x + float(ix) * CELL_M, z)
			heights[iz * nx + ix] = h
			originals[iz * nx + ix] = h
	# 1) Nearest-centreline pass: the road bed owns a 26 m flat corridor and a 38 m blend back to the hill.
	var half_cells: int = int(ceilf(CORRIDOR_BLEND_END_M / CELL_M))
	var count: int = _points.size()
	for index: int in range(0, count, int(STAMP_STEP_M)):
		var p: Vector3 = _points[index]
		var cx: int = int(roundf((p.x - bbox.position.x) / CELL_M))
		var cz: int = int(roundf((p.z - bbox.position.y) / CELL_M))
		for iz: int in range(maxi(cz - half_cells, 0), mini(cz + half_cells, nz - 1) + 1):
			var dz: float = bbox.position.y + float(iz) * CELL_M - p.z
			for ix: int in range(maxi(cx - half_cells, 0), mini(cx + half_cells, nx - 1) + 1):
				var dx: float = bbox.position.x + float(ix) * CELL_M - p.x
				var d: float = sqrt(dx * dx + dz * dz)
				var vi: int = iz * nx + ix
				if d < near_dist[vi]:
					near_dist[vi] = d
					near_index[vi] = index
	# 1b) Refine the bed on the projected station: interpolating between the 1 m centreline points removes the sample-grid
	#     slope error so the road never floats or pokes through.
	for iz: int in range(nz):
		var z: float = bbox.position.y + float(iz) * CELL_M
		for ix: int in range(nx):
			var vi: int = iz * nx + ix
			if near_index[vi] < 0 or near_dist[vi] >= CORRIDOR_BLEND_END_M:
				continue
			var x: float = bbox.position.x + float(ix) * CELL_M
			var bed: float = _projected_y(x, z, near_index[vi]) - ROAD_DROP_M
			if near_dist[vi] <= CORRIDOR_FLAT_M:
				heights[vi] = bed
			else:
				var t: float = _smooth((near_dist[vi] - CORRIDOR_FLAT_M) / (CORRIDOR_BLEND_END_M - CORRIDOR_FLAT_M))
				heights[vi] = lerpf(bed, originals[vi], t)
	# 2) Flat decks: the pit apron and paddock, the grandstand terraces.
	for platform: Dictionary in _platforms:
		_stamp_platform(heights, pad_mask, nx, nz, platform)
	_stamp_tunnel_bank(heights, pad_mask, near_dist, nx, nz)
	# 3) River valley carve: only inside the left water strip, fading at both ends.
	_carve_river(heights, water_mask, near_dist, nx, nz)
	# Stands are rigid rectangles, not curved strips following each road station.
	for rect: Dictionary in _rects:
		_cut_rect(heights, pad_mask, nx, nz, rect)
	heightgrid = {
		"origin": bbox.position, "step": CELL_M, "nx": nx, "nz": nz,
		"heights": heights, "water_level": water_level, "pad_mask": pad_mask, "water_mask": water_mask,
	}
	terrain_mesh = _build_terrain_mesh(nx, nz, heights, pad_mask, water_mask)
	water_mesh = _build_water_mesh()
	ridge_mesh = _build_ridge_mesh()
	skirt_mesh = _build_skirt_mesh(nx, nz, heights)
	triangle_count = _count(terrain_mesh) + _count(water_mesh) + _count(ridge_mesh)


## The road's y at the point of the centreline nearest to (x, z), interpolated between the 1 m samples around `index`.
func _projected_y(x: float, z: float, index: int) -> float:
	var count: int = _points.size()
	var best: float = INF
	var y: float = _points[index].y
	for back: int in [0, 1]:
		var a: Vector3 = _points[posmod(index - back, count)]
		var b: Vector3 = _points[posmod(index - back + 1, count)]
		var abx: float = b.x - a.x
		var abz: float = b.z - a.z
		var length2: float = abx * abx + abz * abz
		if length2 < 0.0001:
			continue
		var t: float = clampf(((x - a.x) * abx + (z - a.z) * abz) / length2, 0.0, 1.0)
		var qx: float = a.x + abx * t
		var qz: float = a.z + abz * t
		var d2: float = (x - qx) * (x - qx) + (z - qz) * (z - qz)
		if d2 < best:
			best = d2
			y = lerpf(a.y, b.y, t)
	return y


func _frame(s: float) -> Transform3D:
	return ribbon.get_point_at_offset(fposmod(s, _length_m), 0.0)


func _stamp_platform(heights: PackedFloat32Array, pad_mask: PackedByteArray, nx: int, nz: int, platform: Dictionary) -> void:
	var s0: float = float(platform["s0"])
	var s1: float = float(platform["s1"])
	var side: float = float(platform["side"])
	if s1 < s0:
		s1 += _length_m
	var s: float = s0
	while s <= s1:
		var frame: Transform3D = _frame(s)
		var lateral: float = float(platform["lateral_from"])
		while lateral <= float(platform["lateral_to"]):
			var cell: Vector2i = _cell_of(frame.origin + frame.basis.x * (side * lateral), nx, nz)
			if cell.x >= 0:
				var vi: int = cell.y * nx + cell.x
				heights[vi] = frame.origin.y - ROAD_DROP_M
				pad_mask[vi] = 1
			lateral += 4.0
		s += 4.0


## Raise a pine bank on both sides of the acoustic canopy so the tunnel reads as a cutting through the Ardennes ridge
## instead of a canopy floating on a plateau.
func _stamp_tunnel_bank(heights: PackedFloat32Array, pad_mask: PackedByteArray, near_dist: PackedFloat32Array, nx: int, nz: int) -> void:
	var s: float = TUNNEL_BANK_S0
	while s <= TUNNEL_BANK_S1:
		var fade: float = minf(_smooth((s - TUNNEL_BANK_S0) / 35.0), _smooth((TUNNEL_BANK_S1 - s) / 35.0))
		var frame: Transform3D = _frame(s)
		for side: float in [-1.0, 1.0]:
			var lateral: float = 30.0
			while lateral <= (150.0 if side < 0.0 else 85.0):
				var cell: Vector2i = _cell_of(frame.origin + frame.basis.x * (side * lateral), nx, nz)
				if cell.x >= 0:
					var vi: int = cell.y * nx + cell.x
					if near_dist[vi] >= 28.0:
						var hill: float
						if side < 0.0:
							hill = 22.0 * _smooth((lateral - 30.0) / 35.0) * (1.0 - _smooth((lateral - 85.0) / 65.0))
						else:
							hill = 8.0 * _smooth((lateral - 30.0) / 25.0) * (1.0 - _smooth((lateral - 60.0) / 25.0))
						var target: float = frame.origin.y - ROAD_DROP_M + hill * fade
						if heights[vi] < target:
							heights[vi] = target
							pad_mask[vi] = 0
				lateral += 4.0
		s += 4.0


func _carve_river(heights: PackedFloat32Array, water_mask: PackedByteArray, near_dist: PackedFloat32Array, nx: int, nz: int) -> void:
	var s: float = WATER_S0
	while s <= WATER_S1:
		var end_fade: float = minf(_smooth((s - WATER_S0) / 35.0), _smooth((WATER_S1 - s) / 35.0))
		var frame: Transform3D = _frame(s)
		var lateral: float = WATER_INNER_M - 10.0
		while lateral <= WATER_OUTER_M + 10.0:
			var p: Vector3 = frame.origin - frame.basis.x * lateral
			var across_t: float = clampf((lateral - WATER_INNER_M) / 26.0, 0.0, 1.0) * clampf((WATER_OUTER_M - lateral) / 34.0, 0.0, 1.0)
			var depth: float = (water_level - 3.5) * end_fade
			var target: float = lerpf(_natural_height(p.x, p.z), depth, _smooth(across_t) * end_fade)
			var cell: Vector2i = _cell_of(p, nx, nz)
			if cell.x >= 0:
				var vi: int = cell.y * nx + cell.x
				if near_dist[vi] >= 30.0:
					if heights[vi] > target:
						heights[vi] = target
					water_mask[vi] = 1
			lateral += 5.0
		s += 5.0


## A stand's rectangle (`width` across, `length` along, centre `lateral` left or right of the road) is cut down to the road's
## bed, with a one-cell margin and a two-cell feathered slope around it.
func _cut_rect(heights: PackedFloat32Array, mask: PackedByteArray, nx: int, nz: int, rect: Dictionary) -> void:
	var frame: Transform3D = _frame(float(rect["s"]))
	var right: Vector3 = frame.basis.x
	var along := Vector3(-right.z, 0.0, right.x)
	var centre: Vector3 = frame.origin + right * (float(rect["side"]) * float(rect["lateral"]))
	var width: float = float(rect["width"])
	var length: float = float(rect["length"])
	var bed: float = frame.origin.y - ROAD_DROP_M
	for iz: int in range(nz):
		for ix: int in range(nx):
			var p := Vector3(bbox.position.x + float(ix) * CELL_M, 0.0, bbox.position.y + float(iz) * CELL_M) - Vector3(centre.x, 0.0, centre.z)
			var distance_m: float = maxf(absf(p.dot(right)) - width * 0.5, absf(p.dot(along)) - length * 0.5)
			if distance_m > CELL_M * 3.0:
				continue
			var index: int = iz * nx + ix
			var fade: float = _smooth((distance_m - CELL_M) / (CELL_M * 2.0))
			heights[index] = minf(heights[index], lerpf(bed, heights[index], fade))
			if distance_m <= CELL_M:
				mask[index] = 1


func _cell_of(p: Vector3, nx: int, nz: int) -> Vector2i:
	var ix: int = int(roundf((p.x - bbox.position.x) / CELL_M))
	var iz: int = int(roundf((p.z - bbox.position.y) / CELL_M))
	if ix < 0 or iz < 0 or ix >= nx or iz >= nz:
		return Vector2i(-1, -1)
	return Vector2i(ix, iz)


# --- meshes ----------------------------------------------------------------------------------------

func _build_terrain_mesh(nx: int, nz: int, heights: PackedFloat32Array, pad_mask: PackedByteArray, water_mask: PackedByteArray) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for iz: int in range(nz - 1):
		var z0: float = bbox.position.y + float(iz) * CELL_M
		for ix: int in range(nx - 1):
			var x0: float = bbox.position.x + float(ix) * CELL_M
			var v00 := Vector3(x0, heights[iz * nx + ix], z0)
			var v10 := Vector3(x0 + CELL_M, heights[iz * nx + ix + 1], z0)
			var v11 := Vector3(x0 + CELL_M, heights[(iz + 1) * nx + ix + 1], z0 + CELL_M)
			var v01 := Vector3(x0, heights[(iz + 1) * nx + ix], z0 + CELL_M)
			_add_terrain_triangle(st, v00, v10, v11, nx, nz, heights, pad_mask, water_mask)
			_add_terrain_triangle(st, v00, v11, v01, nx, nz, heights, pad_mask, water_mask)
	st.generate_normals()
	var mesh: ArrayMesh = st.commit()
	var material := ShaderMaterial.new()
	material.shader = TerrainShader
	# The set's pale paints clip to white under the sun (the shared ground is tinted the same way).
	material.set_shader_parameter("tint", GROUND_TINT)
	mesh.surface_set_material(0, material)
	return mesh


func _add_terrain_triangle(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, nx: int, nz: int, heights: PackedFloat32Array, pad_mask: PackedByteArray, water_mask: PackedByteArray) -> void:
	for vertex: Vector3 in [a, b, c]:
		var ix: int = clampi(int(roundf((vertex.x - bbox.position.x) / CELL_M)), 0, nx - 1)
		var iz: int = clampi(int(roundf((vertex.z - bbox.position.y) / CELL_M)), 0, nz - 1)
		var vi: int = iz * nx + ix
		var slope: float = _slope_at(vertex.x, vertex.z, nx, nz, heights)
		var n: float = _noise.get_noise_2d(vertex.x * 1.7, vertex.z * 1.7)
		var color: Color = GRASS_A.lerp(GRASS_B, 0.5 + n * 0.5)
		if vertex.y > 88.0:
			color = color.lerp(FOREST_FLOOR, clampf((vertex.y - 88.0) / 30.0, 0.0, 0.65))
		if slope > 0.78:
			color = ROCK_A.lerp(ROCK_B, 0.5 + n * 0.5).lerp(color, clampf(1.15 - slope, 0.0, 0.8))
		elif slope > 0.5:
			color = color.lerp(ROCK_B, (slope - 0.5) * 0.55)
		if water_mask[vi] == 1 and vertex.y < water_level + 2.2:
			color = SAND.lerp(color, clampf((vertex.y - water_level) / 2.2, 0.0, 1.0) * 0.55)
		if pad_mask[vi] == 1:
			color = PAD_COLOR
		st.set_color(color)
		st.add_vertex(vertex)


func _slope_at(x: float, z: float, nx: int, nz: int, heights: PackedFloat32Array) -> float:
	var ix: int = clampi(int(roundf((x - bbox.position.x) / CELL_M)), 1, nx - 2)
	var iz: int = clampi(int(roundf((z - bbox.position.y) / CELL_M)), 1, nz - 2)
	var hx: float = heights[iz * nx + ix + 1] - heights[iz * nx + ix - 1]
	var hz: float = heights[(iz + 1) * nx + ix] - heights[(iz - 1) * nx + ix]
	return sqrt(hx * hx + hz * hz) / (2.0 * CELL_M)


## One toon-water strip along the left of the climb, wobbling its banks so the river does not read as a ruled slab. Wound
## up (the water shader culls back faces).
func _build_water_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var s: float = WATER_S0
	var previous := PackedVector3Array()
	while s <= WATER_S1:
		var frame: Transform3D = _frame(s)
		var wobble: float = sin(s * 0.021) * 5.0 + cos(s * 0.013) * 3.0
		var inner: Vector3 = frame.origin - frame.basis.x * (WATER_INNER_M + 4.0 + wobble)
		var outer: Vector3 = frame.origin - frame.basis.x * (WATER_OUTER_M - 8.0 + wobble * 0.6)
		inner.y = water_level
		outer.y = water_level
		if previous.size() == 2:
			_add_up_quad(st, previous[0], previous[1], outer, inner)
		previous = PackedVector3Array([inner, outer])
		s += 8.0
	st.generate_normals()
	var mesh: ArrayMesh = st.commit()
	var material := ShaderMaterial.new()
	material.shader = WaterShader
	material.set_shader_parameter("band_length_m", 18.0)
	mesh.surface_set_material(0, material)
	return mesh


## A wall around the field's four edges down to -30 m, closed from both sides, so no sky shows under the rim.
func _build_skirt_mesh(nx: int, nz: int, heights: PackedFloat32Array) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var base_y: float = -30.0
	var edges: Array = []
	for iz: int in [0, nz - 1]:
		var strip: Array[Vector3] = []
		for ix: int in range(nx):
			strip.append(Vector3(bbox.position.x + float(ix) * CELL_M, heights[iz * nx + ix], bbox.position.y + float(iz) * CELL_M))
		edges.append(strip)
	for ix: int in [0, nx - 1]:
		var strip: Array[Vector3] = []
		for iz: int in range(nz):
			strip.append(Vector3(bbox.position.x + float(ix) * CELL_M, heights[iz * nx + ix], bbox.position.y + float(iz) * CELL_M))
		edges.append(strip)
	for strip: Array in edges:
		for index: int in range(strip.size() - 1):
			var a: Vector3 = strip[index]
			var b: Vector3 = strip[index + 1]
			var a0 := Vector3(a.x, base_y, a.z)
			var b0 := Vector3(b.x, base_y, b.z)
			for triangle: Array in [[a, a0, b0, a, b0, b], [a, b0, a0, a, b, b0]]:
				for vertex: Vector3 in triangle:
					st.set_color(SKIRT_COLOR)
					st.add_vertex(vertex)
	st.generate_normals()
	var mesh: ArrayMesh = st.commit()
	mesh.surface_set_material(0, ToonMaterials.vertex_colored(false))
	return mesh


## Three rings of ridge around the bowl (a dark inner wall, the crest, the far back) so the horizon is hills, not void.
func _build_ridge_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var segments: int = 96
	var inner_ring: Array[Vector3] = []
	var ridge_ring: Array[Vector3] = []
	var back_ring: Array[Vector3] = []
	for index: int in range(segments + 1):
		var angle: float = TAU * float(index) / float(segments)
		var noise: float = sin(float(index) * 0.37) * 0.5 + sin(float(index) * 0.155 + 1.1) * 0.35
		var ridge_h: float = 90.0 + (noise + 0.85) * 70.0
		var back_h: float = ridge_h * 0.72
		# The rings follow the field's own rectangle, so the hills rise right behind its rim on every side.
		var edge: float = _rim_distance(angle)
		var dir := Vector2(cos(angle), sin(angle))
		inner_ring.append(Vector3(BOWL_CENTRE.x + dir.x * (edge + 30.0), -40.0, BOWL_CENTRE.y + dir.y * (edge + 30.0)))
		ridge_ring.append(Vector3(BOWL_CENTRE.x + dir.x * (edge + 320.0), ridge_h, BOWL_CENTRE.y + dir.y * (edge + 320.0)))
		back_ring.append(Vector3(BOWL_CENTRE.x + dir.x * (edge + 760.0), back_h, BOWL_CENTRE.y + dir.y * (edge + 760.0)))
	for index: int in range(segments):
		var next: int = index + 1
		_ridge_quad(st, inner_ring[index], ridge_ring[index], ridge_ring[next], inner_ring[next], RIDGE_A.darkened(0.22), RIDGE_A)
		_ridge_quad(st, ridge_ring[index], back_ring[index], back_ring[next], ridge_ring[next], RIDGE_A, RIDGE_B)
		_ridge_quad(st, back_ring[index], Vector3(back_ring[index].x, -40.0, back_ring[index].z), Vector3(back_ring[next].x, -40.0, back_ring[next].z), back_ring[next], RIDGE_B.darkened(0.25), RIDGE_B)
	st.generate_normals()
	var mesh: ArrayMesh = st.commit()
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON
	material.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	material.roughness = 1.0
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	mesh.surface_set_material(0, material)
	return mesh


func _ridge_quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, color_a: Color, color_b: Color) -> void:
	var vertices: Array[Vector3] = [a, b, c, a, c, d]
	var colors: Array[Color] = [color_a, color_b, color_b, color_a, color_b, color_b]
	for index: int in range(6):
		st.set_color(colors[index])
		st.add_vertex(vertices[index])


func _add_up_quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3) -> void:
	var normal: Vector3 = (b - a).cross(c - a)
	var order: Array = [a, b, c, a, c, d] if normal.y < 0.0 else [a, c, b, a, d, c]
	for vertex: Vector3 in order:
		st.add_vertex(vertex)


# --- queries ---------------------------------------------------------------------------------------

## Top of the ground at (x, z): the same triangles the mesh draws (each cell splits into (a, b, c) and (a, c, d)).
func height_at(x: float, z: float) -> float:
	var nx: int = int(heightgrid.get("nx", 0))
	var nz: int = int(heightgrid.get("nz", 0))
	if nx < 2 or nz < 2:
		return 0.0
	var heights: PackedFloat32Array = heightgrid["heights"]
	var fx: float = (x - bbox.position.x) / CELL_M
	var fz: float = (z - bbox.position.y) / CELL_M
	var ix: int = clampi(int(floorf(fx)), 0, nx - 2)
	var iz: int = clampi(int(floorf(fz)), 0, nz - 2)
	var tx: float = clampf(fx - float(ix), 0.0, 1.0)
	var tz: float = clampf(fz - float(iz), 0.0, 1.0)
	var a: float = heights[iz * nx + ix]
	var b: float = heights[iz * nx + ix + 1]
	var c: float = heights[(iz + 1) * nx + ix + 1]
	var d: float = heights[(iz + 1) * nx + ix]
	if tx >= tz:
		return a + (b - a) * tx + (c - b) * tz
	return a + (c - d) * tx + (d - a) * tz


## True where the nearest grid cell belongs to a deck (pit, paddock, stand terrace).
func is_deck_at(x: float, z: float) -> bool:
	var nx: int = int(heightgrid.get("nx", 0))
	var nz: int = int(heightgrid.get("nz", 0))
	var ix: int = roundi((x - bbox.position.x) / CELL_M)
	var iz: int = roundi((z - bbox.position.y) / CELL_M)
	if ix < 0 or iz < 0 or ix >= nx or iz >= nz:
		return false
	return (heightgrid["pad_mask"] as PackedByteArray)[iz * nx + ix] == 1


## The road station nearest to a world point as {d, s, lateral (signed, + = right of travel), y}; empty beyond `max_d` of the
## asphalt. Stations are every 8 m; the lateral is measured against the leg's own direction.
func track_query(x: float, z: float, max_d: float = 130.0) -> Dictionary:
	var cell := Vector2i(floori(x / HASH_CELL_M), floori(z / HASH_CELL_M))
	var best: int = -1
	var best_sq: float = INF
	var rings: int = int(ceilf(max_d / HASH_CELL_M)) + 1
	for ring: int in range(rings + 1):
		for dx: int in range(-ring, ring + 1):
			for dz: int in range(-ring, ring + 1):
				if maxi(absi(dx), absi(dz)) != ring:
					continue
				var key: Vector2i = cell + Vector2i(dx, dz)
				if not _hash.has(key):
					continue
				for index: int in _hash[key]:
					var sq: float = Vector2(_stations[index].x - x, _stations[index].z - z).length_squared()
					if sq < best_sq:
						best_sq = sq
						best = index
		if best >= 0 and sqrt(best_sq) <= float(ring) * HASH_CELL_M:
			break
	if best < 0 or sqrt(best_sq) > max_d:
		return {}
	var previous: Vector3 = _stations[posmod(best - 1, _stations.size())]
	var following: Vector3 = _stations[posmod(best + 1, _stations.size())]
	var forward: Vector3 = (following - previous).normalized()
	var right: Vector3 = forward.cross(Vector3.UP).normalized()
	var lateral: float = Vector2(x - _stations[best].x, z - _stations[best].z).dot(Vector2(right.x, right.z))
	return {"d": sqrt(best_sq), "s": _station_s[best], "lateral": lateral, "y": _stations[best].y, "side": signf(lateral) if lateral != 0.0 else 1.0}


## The strip zone at a world point, by the nearest road leg (ArdennesZones).
func zone_at_point(x: float, z: float) -> String:
	var query: Dictionary = track_query(x, z, 400.0)
	if query.is_empty():
		return Zones.DEFAULT_ZONE
	return Zones.zone_at(float(query["s"]), float(query["side"]))


func elevation_range() -> Vector2:
	var low: float = INF
	var high: float = -INF
	for h: float in heightgrid.get("heights", PackedFloat32Array()):
		low = minf(low, h)
		high = maxf(high, h)
	return Vector2(low, high)


func _count(mesh: ArrayMesh) -> int:
	if mesh == null:
		return 0
	var total: int = 0
	for surface: int in range(mesh.get_surface_count()):
		var arrays: Array = mesh.surface_get_arrays(surface)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		total += vertices.size() / 3
	return total


static func _smooth(t: float) -> float:
	t = clampf(t, 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)


## Distance from the bowl's centre to the field's rectangle along `angle` (radians, x toward z).
func _rim_distance(angle: float) -> float:
	var half := bbox.size * 0.5
	return minf(half.x / maxf(absf(cos(angle)), 0.0001), half.y / maxf(absf(sin(angle)), 0.0001))
