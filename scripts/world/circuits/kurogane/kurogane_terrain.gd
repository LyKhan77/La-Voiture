class_name KuroganeTerrain
extends RefCounted

## Kurogane Tier B heightfield. The circuit crosses itself: the Back Straight
## (s ~3924, y 37.8) flies over the climbing 200R/Spoon approach (s ~2752,
## y 11.6). The terrain therefore carries the upper branch as the master hill,
## cuts a concrete trench for the lower branch, and leaves the bridge to carry
## the upper road across that trench — 0 floating road, every metre supported
## either by ground or by the truss bridge.

const Layout := preload("res://scripts/world/circuits/kurogane/kurogane_layout.gd")
const Toon := preload("res://scripts/world/shared/toon_materials.gd")
const TreeWindShader := preload("res://shaders/kurogane_tree_wind.gdshader")
const TerrainShader := preload("res://shaders/kurogane_terrain_mottle.gdshader")

const STAMP_STEP_M := 2.0
## Terrain stays at least this far under every surface laid on it (asphalt 8 cm; the bed itself is 16 cm).
const ASPHALT_FLOOR_M := 0.08
## The most lower_under will lower a triangle to clear one point: more is a surface buried in a hill.
const MAX_LOWER_M := 0.8
## Concrete lining of the trench cut: how high above the floor it climbs, how far from the road it looks
## for the slope, and the cross-section sampling step.
const LINING_HEIGHT_M := 9.0
const LINING_REACH_M := 48.0
const LINING_STEP_M := 1.5

const GRASS_A := Color("#5c7f45")
const GRASS_B := Color("#44653a")
const AUTUMN_A := Color("#8a6a34")
const AUTUMN_B := Color("#6d5a2f")
const FOREST_FLOOR := Color("#3a4d31")
const ROCK_A := Color("#75695a")
const ROCK_B := Color("#5b5346")
const PAD_COLOR := Color("#6a6f78")
const CONCRETE := Color("#9a9d9f")
const RIDGE_A := Color("#5c7466")
const RIDGE_B := Color("#728b7c")

var compiled: Dictionary
var points: PackedVector3Array
var bbox := Rect2(
	Vector2(Layout.TERRAIN_MIN_X, Layout.TERRAIN_MIN_Z),
	Vector2(Layout.TERRAIN_MAX_X - Layout.TERRAIN_MIN_X, Layout.TERRAIN_MAX_Z - Layout.TERRAIN_MIN_Z)
)
var heightgrid: Dictionary = {}
var terrain_mesh: ArrayMesh
var ridge_mesh: ArrayMesh
var skirt_mesh: ArrayMesh
var trench_walls_mesh: ArrayMesh
var pads: Array = [] # [Vector2 centre, radius, height]

## Arc-length window on the upper branch where the terrain sits below the road
## bed, i.e. where the truss bridge has to carry the deck.
var bridge_span := Vector2.ZERO
## What the rendered heightfield leaves without ground at the crossing (the frozen window, give or take
## the cell edge), kept for the gate that the window really covers the gap.
var measured_bridge_span := Vector2.ZERO

var _coarse: Array[Vector3] = []
var _samples8: Array[Vector3] = []
var _field_values := PackedFloat32Array()
var _field_nx := 0
var _field_nz := 0
var _noise: FastNoiseLite
var _noise_fine: FastNoiseLite
## The Back Straight rides a plateau at the crossover; the hill is pulled up to
## that deck level so the lower branch is a real cut, not a shallow valley.
var _cross_centre := Vector2.ZERO
var _cross_bed := 0.0


func _init(p_compiled: Dictionary) -> void:
	compiled = p_compiled
	points = compiled["points"]
	var cross_index := posmod(roundi(Layout.CROSS_UPPER_S / float(compiled["step_m"])), points.size())
	_cross_centre = Vector2(points[cross_index].x, points[cross_index].z)
	_cross_bed = points[cross_index].y
	_noise = FastNoiseLite.new()
	_noise.seed = 20261104
	_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_noise.frequency = 0.0032
	_noise.fractal_octaves = 4
	_noise.fractal_gain = 0.48
	_noise_fine = FastNoiseLite.new()
	_noise_fine.seed = 20261105
	_noise_fine.noise_type = FastNoiseLite.TYPE_SIMPLEX
	_noise_fine.frequency = 0.016
	_noise_fine.fractal_octaves = 2
	var stride := maxi(1, roundi(Layout.COARSE_STEP_M / float(compiled["step_m"])))
	for index in range(0, points.size(), stride):
		_coarse.append(points[index])
	stride = maxi(1, roundi(8.0 / float(compiled["step_m"])))
	for index in range(0, points.size(), stride):
		_samples8.append(points[index])
	_build_field()
	_build_landmark_pads()
	_build_heightgrid()


# --- field -----------------------------------------------------------------------------

func _build_field() -> void:
	var origin := bbox.position
	_field_nx = int(ceil(bbox.size.x / Layout.FIELD_STEP_M)) + 1
	_field_nz = int(ceil(bbox.size.y / Layout.FIELD_STEP_M)) + 1
	_field_values.resize(_field_nx * _field_nz)
	var centre := Vector2.ZERO
	for point: Vector3 in points:
		centre += Vector2(point.x, point.z)
	centre /= float(points.size())
	for iz in range(_field_nz):
		var z := origin.y + float(iz) * Layout.FIELD_STEP_M
		for ix in range(_field_nx):
			var x := origin.x + float(ix) * Layout.FIELD_STEP_M
			var sum := 0.0
			var weight := 0.0
			for sample: Vector3 in _coarse:
				var dx := sample.x - x
				var dz := sample.z - z
				var w := 1.0 / (dx * dx + dz * dz + 900.0)
				sum += sample.y * w
				weight += w
			var height := sum / weight
			# Mie highlands: the circuit sits in a valley, ridges rise beyond the rim.
			height += 52.0 * _smoothstep((Vector2(x, z).distance_to(centre) - 720.0) / 620.0)
			_field_values[iz * _field_nx + ix] = height


func _field_height(x: float, z: float) -> float:
	var fx := (x - bbox.position.x) / Layout.FIELD_STEP_M
	var fz := (z - bbox.position.y) / Layout.FIELD_STEP_M
	var ix := clampi(int(floor(fx)), 0, _field_nx - 2)
	var iz := clampi(int(floor(fz)), 0, _field_nz - 2)
	var tx := clampf(fx - float(ix), 0.0, 1.0)
	var tz := clampf(fz - float(iz), 0.0, 1.0)
	var a := lerpf(_field_values[iz * _field_nx + ix], _field_values[iz * _field_nx + ix + 1], tx)
	var b := lerpf(_field_values[(iz + 1) * _field_nx + ix], _field_values[(iz + 1) * _field_nx + ix + 1], tx)
	return lerpf(a, b, tz)


func _natural_height(x: float, z: float) -> float:
	var base := _field_height(x, z)
	var broad := _noise.get_noise_2d(x, z) * 18.0
	var fine := _noise_fine.get_noise_2d(x, z) * 2.2
	var height := base + broad + fine
	# Plateau: the hillside at the crossover is lifted to the Back Straight deck so
	# the lower branch cuts a genuine trench through it.
	var distance := Vector2(x, z).distance_to(_cross_centre)
	var lift := _smoothstep(clampf((300.0 - distance) / 240.0, 0.0, 1.0))
	return lerpf(height, _cross_bed + 1.5, lift * 0.94)


# --- landmark pads ---------------------------------------------------------------------

func _build_landmark_pads() -> void:
	for spec: Array in [
		[Layout.LANDMARK_FERRIS_S, Layout.LANDMARK_FERRIS_SIDE, Layout.LANDMARK_FERRIS_LATERAL_M, 46.0],
		[Layout.LANDMARK_TOWER_S, Layout.LANDMARK_TOWER_SIDE, Layout.LANDMARK_TOWER_LATERAL_M, 26.0],
		[Layout.LANDMARK_SHRINE_S, Layout.LANDMARK_SHRINE_SIDE, Layout.LANDMARK_SHRINE_LATERAL_M, 34.0],
	]:
		var frame := _frame(float(spec[0]))
		var centre := frame.origin + frame.basis.x * (float(spec[1]) * float(spec[2]))
		pads.append([Vector2(centre.x, centre.z), float(spec[3]), centre.y])


func _pad_target(x: float, z: float) -> float:
	for entry: Array in pads:
		var centre: Vector2 = entry[0]
		var radius := float(entry[1])
		var d := Vector2(x, z).distance_to(centre)
		if d <= radius:
			return float(entry[2])
	return NAN


# --- height field ----------------------------------------------------------------------

func _build_heightgrid() -> void:
	var step := Layout.TERRAIN_STEP_M
	var nx := int(round(bbox.size.x / step)) + 1
	var nz := int(round(bbox.size.y / step)) + 1
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
	pad_mask.fill(0)
	var trench_mask := PackedByteArray()
	trench_mask.resize(nx * nz)
	trench_mask.fill(0)
	for iz in range(nz):
		var z := bbox.position.y + float(iz) * step
		for ix in range(nx):
			var x := bbox.position.x + float(ix) * step
			var h := _natural_height(x, z)
			heights[iz * nx + ix] = h
			originals[iz * nx + ix] = h
	# 1) Nearest-centreline corridor: flat bed + blend back to the hill.
	_stamp_corridor(heights, originals, near_dist, near_index, nx, nz, step)
	# 2) Paddock terraces on the start straight.
	_stamp_pad(heights, pad_mask, nx, nz, step, 0.0, 215.0, 1.0, 12.0, 84.0)
	_stamp_pad(heights, pad_mask, nx, nz, step, 5560.0, Layout.LENGTH_M, 1.0, 12.0, 84.0)
	_stamp_pad(heights, pad_mask, nx, nz, step, 0.0, 215.0, -1.0, 12.0, 78.0)
	_stamp_pad(heights, pad_mask, nx, nz, step, 5540.0, Layout.LENGTH_M, -1.0, 12.0, 78.0)
	# 3) Hero landmark platforms.
	for entry: Array in pads:
		_stamp_disc(heights, pad_mask, nx, nz, step, entry[0], float(entry[1]), float(entry[2]) - Layout.ROADBED_DROP_M)
	# 4) The trench wins last: the lower branch is cut through the hill and the
	#    upper branch has to bridge it.
	_carve_trench(heights, originals, trench_mask, nx, nz, step)
	heightgrid = {
		"origin": bbox.position, "step": step, "nx": nx, "nz": nz,
		"heights": heights, "pad_mask": pad_mask, "trench_mask": trench_mask,
	}
	ridge_mesh = _build_ridge_mesh()
	# 5) A 12 m cell cannot follow a road that climbs and curves inside it: wherever the rendered
	#    triangle would stand above the asphalt, lower it (see lower_under).
	lower_under(_asphalt_samples(), ASPHALT_FLOOR_M)


## Asphalt sample points every metre along the centreline: the centre and both edges plus a margin.
func _asphalt_samples() -> PackedVector3Array:
	var samples := PackedVector3Array()
	var step_c: float = float(compiled["step_m"])
	var count := points.size()
	for index in range(0, count, 1):
		var p := points[index]
		var forward := (points[posmod(index + 1, count)] - points[posmod(index - 1, count)]).normalized()
		var right := forward.cross(Vector3.UP).normalized()
		for lateral: float in [-Layout.ROAD_HALF_M - 0.4, -3.4, 0.0, 3.4, Layout.ROAD_HALF_M + 0.4]:
			samples.append(p + right * lateral)
	return samples


## Lowers the heightfield under surfaces laid on it (asphalt, kerbs, run-off, gravel): wherever the
## rendered terrain triangle would stand within `margin` of a surface point (or above it), the three
## corners drop by the least movement that clears the point (shortfall x weight / sum of weights squared),
## so neighbouring road does not hang over a pit. A shortfall over MAX_LOWER_M is a surface buried in a
## hill, not a cell the grid could not follow: it is left alone (the caller removes or tolerates it).
## Only lowers, so nothing it fixes can be undone by a later sample. Rebuilds the meshes; returns the
## number of samples it moved.
func lower_under(surface_points: PackedVector3Array, margin: float) -> int:
	var step: float = float(heightgrid["step"])
	var nx: int = int(heightgrid["nx"])
	var nz: int = int(heightgrid["nz"])
	var heights: PackedFloat32Array = heightgrid["heights"]
	var moved := 0
	for p: Vector3 in surface_points:
		var fx := (p.x - bbox.position.x) / step
		var fz := (p.z - bbox.position.y) / step
		if fx < 0.0 or fz < 0.0 or fx > float(nx - 1) or fz > float(nz - 1):
			continue
		var ix := clampi(int(floor(fx)), 0, nx - 2)
		var iz := clampi(int(floor(fz)), 0, nz - 2)
		var tx := clampf(fx - float(ix), 0.0, 1.0)
		var tz := clampf(fz - float(iz), 0.0, 1.0)
		var i00 := iz * nx + ix
		var i10 := i00 + 1
		var i01 := i00 + nx
		var i11 := i01 + 1
		var h: float = height_in_cell(heights, i00, i10, i01, i11, tx, tz)
		var shortfall := h - (p.y - margin)
		if shortfall <= 0.0 or shortfall > MAX_LOWER_M:
			continue
		# Barycentric weights of the point in its triangle: (v00, v10, v11) where tx >= tz, else (v00, v11, v01).
		var corners: Array[int] = []
		var weights: Array[float] = []
		if tx >= tz:
			corners.assign([i00, i10, i11])
			weights.assign([1.0 - tx, tx - tz, tz])
		else:
			corners.assign([i00, i11, i01])
			weights.assign([1.0 - tz, tx, tz - tx])
		var norm := 0.0
		for w: float in weights:
			norm += w * w
		for k: int in range(3):
			heights[corners[k]] -= shortfall * weights[k] / norm
		moved += 1
	heightgrid["heights"] = heights
	_build_meshes()
	return moved


func _build_meshes() -> void:
	var nx: int = int(heightgrid["nx"])
	var nz: int = int(heightgrid["nz"])
	var step: float = float(heightgrid["step"])
	var heights: PackedFloat32Array = heightgrid["heights"]
	terrain_mesh = _build_terrain_mesh(nx, nz, step, heights, heightgrid["pad_mask"], heightgrid["trench_mask"])
	skirt_mesh = _build_skirt_mesh(nx, nz, step, heights)
	measured_bridge_span = _measure_bridge_span()
	bridge_span = Layout.BRIDGE_SPAN_S if measured_bridge_span != Vector2.ZERO else Vector2.ZERO
	trench_walls_mesh = _build_trench_walls()


## The rendered mesh splits every cell along its v00-v11 diagonal: triangle (v00, v10, v11) where tx >= tz,
## else (v00, v11, v01).
static func height_in_cell(heights: PackedFloat32Array, i00: int, i10: int, i01: int, i11: int, tx: float, tz: float) -> float:
	var h00 := heights[i00]
	if tx >= tz:
		return h00 + (heights[i10] - h00) * tx + (heights[i11] - heights[i10]) * tz
	return h00 + (heights[i11] - heights[i01]) * tx + (heights[i01] - h00) * tz


func _stamp_corridor(heights: PackedFloat32Array, originals: PackedFloat32Array, near_dist: PackedFloat32Array, near_index: PackedInt32Array, nx: int, nz: int, step: float) -> void:
	var half := Layout.CORRIDOR_BLEND_END_M
	var stride := maxi(1, roundi(STAMP_STEP_M / float(compiled["step_m"])))
	for index in range(0, points.size(), stride):
		var p := points[index]
		var ix0 := int(clampf(floor((p.x - half - bbox.position.x) / step), 0.0, float(nx - 1)))
		var ix1 := int(clampf(ceil((p.x + half - bbox.position.x) / step), 0.0, float(nx - 1)))
		var iz0 := int(clampf(floor((p.z - half - bbox.position.y) / step), 0.0, float(nz - 1)))
		var iz1 := int(clampf(ceil((p.z + half - bbox.position.y) / step), 0.0, float(nz - 1)))
		for iz in range(iz0, iz1 + 1):
			var z := bbox.position.y + float(iz) * step
			var dz := z - p.z
			for ix in range(ix0, ix1 + 1):
				var x := bbox.position.x + float(ix) * step
				var dx := x - p.x
				var d := sqrt(dx * dx + dz * dz)
				var vi := iz * nx + ix
				if d >= near_dist[vi]:
					continue
				near_dist[vi] = d
				near_index[vi] = index
	var step_c: float = float(compiled["step_m"])
	var point_count := points.size()
	for iz in range(nz):
		var z := bbox.position.y + float(iz) * step
		for ix in range(nx):
			var vi := iz * nx + ix
			if near_index[vi] < 0 or near_dist[vi] >= Layout.CORRIDOR_BLEND_END_M:
				continue
			var x := bbox.position.x + float(ix) * step
			var idx := near_index[vi]
			var best_d2 := INF
			var bed_y := points[idx].y
			for back in [0, 1]:
				var ia := posmod(idx - back, point_count)
				var ib := posmod(idx - back + 1, point_count)
				var a := points[ia]
				var b := points[ib]
				var abx := b.x - a.x
				var abz := b.z - a.z
				var length2 := abx * abx + abz * abz
				if length2 < 0.0001:
					continue
				var t := clampf(((x - a.x) * abx + (z - a.z) * abz) / length2, 0.0, 1.0)
				var qx := a.x + abx * t
				var qz := a.z + abz * t
				var d2 := (x - qx) * (x - qx) + (z - qz) * (z - qz)
				if d2 < best_d2:
					best_d2 = d2
					bed_y = lerpf(a.y, b.y, t)
			var bed := bed_y - Layout.ROADBED_DROP_M
			if near_dist[vi] <= Layout.CORRIDOR_FLAT_M:
				heights[vi] = bed
			else:
				var t := _smoothstep((near_dist[vi] - Layout.CORRIDOR_FLAT_M) / (Layout.CORRIDOR_BLEND_END_M - Layout.CORRIDOR_FLAT_M))
				heights[vi] = lerpf(bed, originals[vi], t)


func _stamp_pad(heights: PackedFloat32Array, pad_mask: PackedByteArray, nx: int, nz: int, step: float, s0: float, s1: float, side: float, lat0: float, lat1: float) -> void:
	var s := s0
	while s <= s1:
		var frame := _frame(fposmod(s, Layout.LENGTH_M))
		var lateral := lat0
		while lateral <= lat1:
			var p := frame.origin + frame.basis.x * (side * lateral)
			var cell := _cell_of(p, nx, nz, step)
			if cell.x >= 0:
				var vi: int = cell.y * nx + cell.x
				heights[vi] = frame.origin.y - Layout.ROADBED_DROP_M
				pad_mask[vi] = 1
			lateral += 4.0
		s += 4.0


func _stamp_disc(heights: PackedFloat32Array, pad_mask: PackedByteArray, nx: int, nz: int, step: float, centre: Vector2, radius: float, target: float) -> void:
	var ix0 := int(clampf(floor((centre.x - radius - bbox.position.x) / step), 0.0, float(nx - 1)))
	var ix1 := int(clampf(ceil((centre.x + radius - bbox.position.x) / step), 0.0, float(nx - 1)))
	var iz0 := int(clampf(floor((centre.y - radius - bbox.position.y) / step), 0.0, float(nz - 1)))
	var iz1 := int(clampf(ceil((centre.y + radius - bbox.position.y) / step), 0.0, float(nz - 1)))
	for iz in range(iz0, iz1 + 1):
		var z := bbox.position.y + float(iz) * step
		for ix in range(ix0, ix1 + 1):
			var x := bbox.position.x + float(ix) * step
			var d := Vector2(x, z).distance_to(centre)
			if d > radius + step:
				continue
			var vi := iz * nx + ix
			var t := _smoothstep(clampf((d - radius) / step, 0.0, 1.0))
			heights[vi] = lerpf(target, heights[vi], t)
			if d <= radius:
				pad_mask[vi] = 1


## Concrete trench for the lower branch: a flat floor at the road bed for
## TRENCH_HALF_FLAT_M either side, then a near-vertical cut back to the hill.
## The floor comes from the cell's NEAREST station on the lower branch (a stamp
## station's own floor would dip the road by the elevation gained along the
## spacing), and the upper branch keeps its own bed outside the trench so the
## bridge abutments stay supported.
func _carve_trench(heights: PackedFloat32Array, originals: PackedFloat32Array, trench_mask: PackedByteArray, nx: int, nz: int, step: float) -> void:
	var step_c: float = float(compiled["step_m"])
	var s0 := float(Layout.CROSS_LOWER_RANGE.x)
	var s1 := float(Layout.CROSS_LOWER_RANGE.y)
	var half := Layout.TRENCH_HALF_FLAT_M
	var blend := Layout.TRENCH_BLEND_M
	var stride := maxi(1, roundi(STAMP_STEP_M / step_c))
	var reach := Layout.CORRIDOR_BLEND_END_M
	var stations: Array = []
	for index in range(int(s0 / step_c), int(s1 / step_c) + 1, stride):
		stations.append(index)
	var upper: Array = []
	for index in range(int(float(Layout.CROSS_UPPER_RANGE.x) / step_c), int(float(Layout.CROSS_UPPER_RANGE.y) / step_c) + 1, stride):
		upper.append(index)
	var low_min := Vector2(INF, INF)
	var low_max := Vector2(-INF, -INF)
	for index: int in stations:
		var p := points[index]
		low_min = Vector2(minf(low_min.x, p.x), minf(low_min.y, p.z))
		low_max = Vector2(maxf(low_max.x, p.x), maxf(low_max.y, p.z))
	var ix0 := int(clampf(floor((low_min.x - reach - bbox.position.x) / step), 0.0, float(nx - 1)))
	var ix1 := int(clampf(ceil((low_max.x + reach - bbox.position.x) / step), 0.0, float(nx - 1)))
	var iz0 := int(clampf(floor((low_min.y - reach - bbox.position.y) / step), 0.0, float(nz - 1)))
	var iz1 := int(clampf(ceil((low_max.y + reach - bbox.position.y) / step), 0.0, float(nz - 1)))
	for iz in range(iz0, iz1 + 1):
		var z := bbox.position.y + float(iz) * step
		for ix in range(ix0, ix1 + 1):
			var x := bbox.position.x + float(ix) * step
			var best := INF
			var best_index := -1
			for index: int in stations:
				var p := points[index]
				var dx := p.x - x
				var dz := p.z - z
				var d2 := dx * dx + dz * dz
				if d2 < best:
					best = d2
					best_index = index
			if best_index < 0:
				continue
			var d := sqrt(best)
			if d > reach:
				continue
			var station := float(best_index) * step_c
			var fade := minf(_smoothstep((station - s0) / 26.0), _smoothstep((s1 - station) / 26.0))
			if fade <= 0.0:
				continue
			var vi := iz * nx + ix
			var floor_y := points[best_index].y - Layout.ROADBED_DROP_M
			if d <= half:
				var target := floor_y
				if fade < 1.0:
					target = lerpf(heights[vi], target, fade)
				heights[vi] = target
				if fade > 0.5:
					trench_mask[vi] = 1
				continue
			# Outside the floor the upper branch owns its own abutment ground.
			if _nearest_station_distance(upper, x, z) < 26.0:
				continue
			var top := maxf(originals[vi], heights[vi])
			var t := _smoothstep(clampf((d - half) / blend, 0.0, 1.0))
			var wall_target := lerpf(floor_y, top, t)
			if fade < 1.0:
				wall_target = lerpf(heights[vi], wall_target, fade)
			heights[vi] = wall_target


func _nearest_station_distance(indices: Array, x: float, z: float) -> float:
	var best := INF
	for index: int in indices:
		var p := points[index]
		var dx := p.x - x
		var dz := p.z - z
		best = minf(best, dx * dx + dz * dz)
	return sqrt(best)


## Walk the upper branch and return [first_s, last_s] where the terrain sits more
## than 0.5 m below the road bed: the truss bridge has to carry that window.
func _measure_bridge_span() -> Vector2:
	var step_c: float = float(compiled["step_m"])
	var first := -1.0
	var last := -1.0
	var s := float(Layout.CROSS_UPPER_RANGE.x)
	while s <= float(Layout.CROSS_UPPER_RANGE.y):
		var index := posmod(roundi(s / step_c), points.size())
		var p := points[index]
		var ground := height_at(p.x, p.z)
		if ground < p.y - Layout.ROADBED_DROP_M - 0.5:
			if first < 0.0:
				first = s
			last = s
		s += 1.0
	if first < 0.0:
		return Vector2.ZERO
	return Vector2(first - 4.0, last + 4.0)


func _build_trench_walls() -> ArrayMesh:
	if bridge_span == Vector2.ZERO:
		return null
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var step_c: float = float(compiled["step_m"])
	var s0 := float(Layout.CROSS_LOWER_RANGE.x) + 6.0
	var s1 := float(Layout.CROSS_LOWER_RANGE.y) - 6.0
	for side: float in [-1.0, 1.0]:
		var previous: Array = []
		var s := s0
		while s <= s1:
			var index := posmod(roundi(s / step_c), points.size())
			var p := points[index]
			var forward: Vector3 = (points[posmod(index + 1, points.size())] - points[posmod(index - 1, points.size())]).normalized()
			var right := forward.cross(Vector3.UP).normalized()
			var row := _lining_row(p, right * side, p.y - Layout.ROADBED_DROP_M)
			if not previous.is_empty():
				for k: int in range(row.size() - 1):
					if previous[k] != null and previous[k + 1] != null and row[k] != null and row[k + 1] != null:
						_face(st, previous[k], row[k], row[k + 1], previous[k + 1], Vector3.UP)
			previous = row
			s += 3.0
	var mesh := st.commit()
	if mesh != null:
		mesh.surface_set_material(0, Toon.make(CONCRETE))
	return mesh


## One cross-section of the concrete lining, on a fixed lateral grid so neighbouring sections pair up:
## a point on the rendered terrain (lifted a hand's width, so the lining never z-fights it) wherever the
## cut stands more than 0.15 m above the floor, up to LINING_HEIGHT_M, null elsewhere. The lining follows
## the cut exactly, so it can neither float in front of the slope nor poke out of it.
func _lining_row(centre: Vector3, outward: Vector3, floor_y: float) -> Array:
	var row: Array = []
	var capped := false
	var lateral := Layout.ROAD_HALF_M
	while lateral <= LINING_REACH_M:
		var x := centre.x + outward.x * lateral
		var z := centre.z + outward.z * lateral
		var rise := height_at(x, z) - floor_y
		if capped or rise < 0.15:
			row.append(null)
		else:
			row.append(Vector3(x, floor_y + minf(rise, LINING_HEIGHT_M) + 0.12, z))
			capped = rise >= LINING_HEIGHT_M
		lateral += LINING_STEP_M
	return row


## Quad with an explicit face normal so the material never sees a degenerate one.
func _face(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, hint: Vector3) -> void:
	var n := (b - a).cross(c - a)
	if n.length() < 0.0001:
		return
	var order: Array = [a, b, c, a, c, d] if n.dot(hint) >= 0.0 else [a, c, b, a, d, c]
	var normal := hint.normalized()
	for v: Vector3 in order:
		st.set_normal(normal)
		st.add_vertex(v)


func _wall_quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, hint: Vector3) -> void:
	var n := (b - a).cross(c - a)
	var order: Array = [a, b, c, a, c, d] if n.dot(hint) >= 0.0 else [a, c, b, a, d, c]
	for v: Vector3 in order:
		st.add_vertex(v)


func _cell_of(p: Vector3, nx: int, nz: int, step: float) -> Vector2i:
	var ix := int(round((p.x - bbox.position.x) / step))
	var iz := int(round((p.z - bbox.position.y) / step))
	if ix < 0 or iz < 0 or ix >= nx or iz >= nz:
		return Vector2i(-1, -1)
	return Vector2i(ix, iz)


# --- meshes ----------------------------------------------------------------------------

func _build_terrain_mesh(nx: int, nz: int, step: float, heights: PackedFloat32Array, pad_mask: PackedByteArray, trench_mask: PackedByteArray) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for iz in range(nz - 1):
		var z0 := bbox.position.y + float(iz) * step
		var z1 := z0 + step
		for ix in range(nx - 1):
			var x0 := bbox.position.x + float(ix) * step
			var x1 := x0 + step
			var v00 := Vector3(x0, heights[iz * nx + ix], z0)
			var v10 := Vector3(x1, heights[iz * nx + ix + 1], z0)
			var v11 := Vector3(x1, heights[(iz + 1) * nx + ix + 1], z1)
			var v01 := Vector3(x0, heights[(iz + 1) * nx + ix], z1)
			_add_terrain_tri(st, v00, v10, v11, nx, nz, step, heights, pad_mask, trench_mask)
			_add_terrain_tri(st, v00, v11, v01, nx, nz, step, heights, pad_mask, trench_mask)
	st.generate_normals()
	var mesh := st.commit()
	if mesh != null:
		var material := ShaderMaterial.new()
		material.shader = TerrainShader
		mesh.surface_set_material(0, material)
	return mesh


func _add_terrain_tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, nx: int, nz: int, step: float, heights: PackedFloat32Array, pad_mask: PackedByteArray, trench_mask: PackedByteArray) -> void:
	for vertex: Vector3 in [a, b, c]:
		var x := vertex.x
		var z := vertex.z
		var ix := clampi(int(round((x - bbox.position.x) / step)), 0, nx - 1)
		var iz := clampi(int(round((z - bbox.position.y) / step)), 0, nz - 1)
		var vi := iz * nx + ix
		var slope := _slope_at(x, z, nx, nz, step, heights)
		var n := _noise.get_noise_2d(x * 1.7, z * 1.7)
		# Mie autumn: grass on the flats, rust maple litter on the mid slopes.
		var color := GRASS_A.lerp(GRASS_B, 0.5 + n * 0.5)
		color = color.lerp(AUTUMN_A.lerp(AUTUMN_B, 0.5 + n * 0.5), clampf((vertex.y - 14.0) / 26.0, 0.0, 0.75))
		if vertex.y > 34.0:
			color = color.lerp(FOREST_FLOOR, clampf((vertex.y - 34.0) / 16.0, 0.0, 0.5))
		if slope > 0.72:
			color = ROCK_A.lerp(ROCK_B, 0.5 + n * 0.5).lerp(color, clampf((1.1 - slope), 0.0, 0.75))
		elif slope > 0.48:
			color = color.lerp(ROCK_B, (slope - 0.48) * 0.6)
		if trench_mask[vi] == 1:
			color = CONCRETE.lerp(color, 0.25)
		if pad_mask[vi] == 1:
			color = PAD_COLOR
		st.set_color(color)
		st.add_vertex(vertex)


func _slope_at(x: float, z: float, nx: int, nz: int, step: float, heights: PackedFloat32Array) -> float:
	var ix := clampi(int(round((x - bbox.position.x) / step)), 1, nx - 2)
	var iz := clampi(int(round((z - bbox.position.y) / step)), 1, nz - 2)
	var hx := heights[iz * nx + ix + 1] - heights[iz * nx + ix - 1]
	var hz := heights[(iz + 1) * nx + ix] - heights[(iz - 1) * nx + ix]
	return sqrt(hx * hx + hz * hz) / (2.0 * step)


func _build_skirt_mesh(nx: int, nz: int, step: float, heights: PackedFloat32Array) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var base_y := 6.0
	var centre := bbox.position + bbox.size * 0.5
	var top_color := GRASS_A
	var bottom_color := GRASS_B
	var edges: Array = []
	for iz: int in [0, nz - 1]:
		var z := bbox.position.y + float(iz) * step
		var strip: Array[Vector3] = []
		for ix in range(nx):
			var x := bbox.position.x + float(ix) * step
			strip.append(Vector3(x, heights[iz * nx + ix], z))
		edges.append(strip)
	for ix: int in [0, nx - 1]:
		var x := bbox.position.x + float(ix) * step
		var strip: Array[Vector3] = []
		for iz in range(nz):
			var z := bbox.position.y + float(iz) * step
			strip.append(Vector3(x, heights[iz * nx + ix], z))
		edges.append(strip)
	for strip: Array in edges:
		for index in range((strip as Array).size() - 1):
			var a: Vector3 = strip[index]
			var b: Vector3 = strip[index + 1]
			var da := Vector2(a.x - centre.x, a.z - centre.y).normalized() * 560.0
			var db := Vector2(b.x - centre.x, b.z - centre.y).normalized() * 560.0
			var a0 := Vector3(a.x + da.x, base_y, a.z + da.y)
			var b0 := Vector3(b.x + db.x, base_y, b.z + db.y)
			# Foothills: the heightfield edge falls away to the forested plain the
			# distant ridge ring stands on, so the horizon never shows a void.
			var quads: Array = [[a, a0, b0, a, b0, b], [a, b0, a0, a, b, b0]]
			for tri: Array in quads:
				for vertex: Vector3 in tri:
					var t := clampf((vertex.y - base_y) / 120.0, 0.0, 1.0)
					st.set_color(bottom_color.lerp(top_color, t))
					st.add_vertex(vertex)
	st.generate_normals()
	var mesh := st.commit()
	if mesh != null:
		var material := Toon.vertex_colored(false)
		material.set_shader_parameter("rim_intensity", 0.0)
		mesh.surface_set_material(0, material)
	return mesh


func _build_ridge_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var centre := Vector2(20.0, 540.0)
	var segments := 56
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON
	material.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	material.roughness = 1.0
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	var inner_ring: Array[Vector3] = []
	var ridge_ring: Array[Vector3] = []
	var back_ring: Array[Vector3] = []
	for index in range(segments + 1):
		var angle := TAU * float(index) / float(segments)
		var noise := sin(float(index) * 0.73) * 0.5 + sin(float(index) * 0.31 + 1.1) * 0.35
		var ridge_h := 120.0 + (noise + 0.85) * 85.0
		var back_h := ridge_h * 0.72
		inner_ring.append(Vector3(centre.x + cos(angle) * 1520.0, 6.0, centre.y + sin(angle) * 1520.0))
		ridge_ring.append(Vector3(centre.x + cos(angle) * 1880.0, ridge_h, centre.y + sin(angle) * 1880.0))
		back_ring.append(Vector3(centre.x + cos(angle) * 2320.0, back_h, centre.y + sin(angle) * 2320.0))
	for index in range(segments):
		var next := index + 1
		_ridge_quad(st, inner_ring[index], ridge_ring[index], ridge_ring[next], inner_ring[next], GRASS_B, RIDGE_A)
		_ridge_quad(st, ridge_ring[index], back_ring[index], back_ring[next], ridge_ring[next], RIDGE_A, RIDGE_B)
		_ridge_quad(st, back_ring[index], Vector3(back_ring[index].x, -40.0, back_ring[index].z), Vector3(back_ring[next].x, -40.0, back_ring[next].z), back_ring[next], RIDGE_B.darkened(0.25), RIDGE_B)
	st.generate_normals()
	var mesh := st.commit()
	if mesh != null:
		mesh.surface_set_material(0, material)
	return mesh


func _ridge_quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, color_a: Color, color_b: Color) -> void:
	var verts: Array = [a, b, c, a, c, d]
	var colors: Array = [color_a, color_b, color_b, color_a, color_b, color_b]
	for index in range(6):
		st.set_color(colors[index])
		st.add_vertex(verts[index])


# --- queries ---------------------------------------------------------------------------

## Height of the rendered terrain mesh at a world point (two triangles per cell, see height_in_cell), so
## trees, masts and landmarks stand on exactly what is drawn.
func height_at(x: float, z: float) -> float:
	var step: float = float(heightgrid.get("step", Layout.TERRAIN_STEP_M))
	var nx: int = int(heightgrid.get("nx", 0))
	var nz: int = int(heightgrid.get("nz", 0))
	var heights: PackedFloat32Array = heightgrid.get("heights", PackedFloat32Array())
	if nx < 2 or nz < 2:
		return 0.0
	var fx := (x - bbox.position.x) / step
	var fz := (z - bbox.position.y) / step
	var ix := clampi(int(floor(fx)), 0, nx - 2)
	var iz := clampi(int(floor(fz)), 0, nz - 2)
	var tx := clampf(fx - float(ix), 0.0, 1.0)
	var tz := clampf(fz - float(iz), 0.0, 1.0)
	var i00 := iz * nx + ix
	return height_in_cell(heights, i00, i00 + 1, i00 + nx, i00 + nx + 1, tx, tz)


func elevation_range() -> Vector2:
	var heights: PackedFloat32Array = heightgrid.get("heights", PackedFloat32Array())
	var low := INF
	var high := -INF
	for h: float in heights:
		low = minf(low, h)
		high = maxf(high, h)
	return Vector2(low, high)


func triangles() -> int:
	var total := 0
	for mesh: ArrayMesh in [terrain_mesh, ridge_mesh]:
		if mesh == null:
			continue
		for surface in mesh.get_surface_count():
			var arrays := mesh.surface_get_arrays(surface)
			var indices: Variant = arrays[Mesh.ARRAY_INDEX]
			total += (indices.size() if indices != null else (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()) / 3
	return total


## Brute-force nearest track query on the 8 m sample set, refined on the fine line.
## Returns {} when the point sits further than `max_d` from the asphalt, else
## {d, s, lateral (signed, + = right of travel), y}.
func track_query(x: float, z: float, max_d := 130.0) -> Dictionary:
	var best := INF
	var best_index := -1
	for index in range(_samples8.size()):
		var p: Vector3 = _samples8[index]
		var dx := p.x - x
		var dz := p.z - z
		var d2 := dx * dx + dz * dz
		if d2 < best:
			best = d2
			best_index = index
	if best_index < 0:
		return {}
	var approx_d := sqrt(best)
	var step: float = float(compiled["step_m"])
	var centre_index := best_index * 8
	# The coarse hit is a fine index too (the 8 m samples are every 8th point): start the refine from it,
	# or a point whose nearest fine sample IS the coarse one would report the coarse index as a station.
	best_index = posmod(centre_index, points.size())
	for offset in range(-18, 19):
		var index := posmod(centre_index + offset, points.size())
		var p := points[index]
		var dx := p.x - x
		var dz := p.z - z
		var d2 := dx * dx + dz * dz
		if d2 < best:
			best = d2
			best_index = index
	var p := points[posmod(best_index, points.size())]
	var previous := points[posmod(best_index - 1, points.size())]
	var following := points[posmod(best_index + 1, points.size())]
	var fwd := (following - previous).normalized()
	var right := fwd.cross(Vector3.UP).normalized()
	var lateral := Vector2(x - p.x, z - p.z).dot(Vector2(right.x, right.z))
	var d := sqrt(best)
	if d > max_d and approx_d > max_d:
		return {}
	return {"d": d, "s": float(best_index) * step, "lateral": lateral, "y": p.y, "side": signf(lateral)}


func _frame(s: float) -> Transform3D:
	var step: float = float(compiled["step_m"])
	var count := points.size()
	var index := posmod(roundi(fposmod(s, Layout.LENGTH_M) / step), count)
	var fwd := (points[posmod(index + 1, count)] - points[posmod(index - 1, count)]).normalized()
	var right := fwd.cross(Vector3.UP).normalized()
	var up := right.cross(fwd)
	return Transform3D(Basis(right, up, -fwd), points[index])


static func _smoothstep(t: float) -> float:
	t = clampf(t, 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)
