class_name PaulistanoTerrain
extends RefCounted

## Procedural Paulistano Speed Arena heightfield (São Paulo laterite plateau,
## Mata Atlântica green, Guarapiranga reservoir): a smoothed track profile with
## rolling relief, a guaranteed road bed 0.16 m under every metre of asphalt
## (0 floating road), the reservoir basin outside T5-T6, the kartodromo plateau
## in the infield, the Senna amphitheatre terrace outside T1, drainage ditches
## on the outer verge, flat paddock/stand terraces, skirt walls down to -30 m, a
## backdrop base and a distant ridge ring so the scene never shows sky through
## the ground.
##
## Deterministic: the same compiled track always builds the same mesh.

const Layout := preload("res://scripts/world/circuits/paulistano/paulistano_layout.gd")
const Toon := preload("res://scripts/world/shared/toon_materials.gd")
const TerrainShader := preload("res://shaders/paulistano_terrain_mottle.gdshader")

const COARSE_STEP_M := 20.0
const FIELD_STEP_M := 30.0
const STAMP_STEP_M := 2.0
## Flat road-bed shelf either side of the centreline, then the grass bank.
const CORRIDOR_FLAT_M := 15.0
const CORRIDOR_BLEND_END_M := 34.0
## Drainage ditch: a shallow V starting at the outer verge.
const DITCH_START_M := CORRIDOR_FLAT_M
const DITCH_WIDTH_M := 11.0
const DITCH_DEPTH_M := 0.4
## +-1 m: on the 12% Drop Braking descent a +-2 m window left the bed 0.41 m under the asphalt.
const BED_WINDOW_SAMPLES := 1
const SKIRT_BASE_Y := -30.0
const BASE_Y := -28.0

const GRASS_A := Color("#4f6b34")
const GRASS_B := Color("#38512a")
const GRASS_DAMP := Color("#5d7a3c")
const LATERITE := Color("#a9502d")
const LATERITE_DARK := Color("#7d3a22")
const FOREST_FLOOR := Color("#2f4224")
const ROCK := Color("#8a5638")
const PAD_COLOR := Color("#848b86")
const RIDGE_A := Color("#6f7f5c")
const RIDGE_B := Color("#8a9873")

var compiled: Dictionary
var points: PackedVector3Array
var heightgrid: Dictionary = {}
var terrain_mesh: ArrayMesh
var skirt_mesh: ArrayMesh
var ridge_mesh: ArrayMesh
var bbox := Rect2(
	Vector2(Layout.TERRAIN_MIN_X, Layout.TERRAIN_MIN_Z),
	Vector2(Layout.TERRAIN_MAX_X - Layout.TERRAIN_MIN_X, Layout.TERRAIN_MAX_Z - Layout.TERRAIN_MIN_Z)
)

var _coarse: Array[Vector3] = []
var _samples8: Array[Vector3] = []
var _stride8 := 8
var _field_values := PackedFloat32Array()
var _field_nx := 0
var _field_nz := 0
var _noise: FastNoiseLite
var _noise_mid: FastNoiseLite
var _noise_fine: FastNoiseLite
var _noise_tint: FastNoiseLite
var _lake_centre := Vector2.ZERO
## Lake frame (world XZ): along the reservoir GLB heading, and across it away from the track.
var _lake_along := Vector2.RIGHT
var _lake_across := Vector2.DOWN
var _promenade_y := 0.0
var _kart_centre := Vector2.ZERO
var _senna_centre := Vector2.ZERO
var _senna_level := 0.0
var _kart_level := 0.0
var _tower_level := 0.0
var _lake_water_y := 0.0
var _lake_floor_y := 0.0


func _init(p_compiled: Dictionary) -> void:
	compiled = p_compiled
	points = compiled["points"]
	_noise = FastNoiseLite.new()
	_noise.seed = 20261109
	_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_noise.frequency = 0.0042
	_noise.fractal_octaves = 3
	_noise.fractal_gain = 0.45
	_noise_mid = FastNoiseLite.new()
	_noise_mid.seed = 20261110
	_noise_mid.noise_type = FastNoiseLite.TYPE_SIMPLEX
	_noise_mid.frequency = 0.012
	_noise_mid.fractal_octaves = 2
	_noise_mid.fractal_gain = 0.5
	_noise_fine = FastNoiseLite.new()
	_noise_fine.seed = 20261111
	_noise_fine.noise_type = FastNoiseLite.TYPE_SIMPLEX
	_noise_fine.frequency = 0.021
	_noise_fine.fractal_octaves = 2
	_noise_tint = FastNoiseLite.new()
	_noise_tint.seed = 20261112
	_noise_tint.noise_type = FastNoiseLite.TYPE_VALUE_CUBIC
	_noise_tint.frequency = 0.0048
	var stride := maxi(1, roundi(COARSE_STEP_M / float(compiled["step_m"])))
	for index in range(0, points.size(), stride):
		_coarse.append(points[index])
	_stride8 = maxi(1, roundi(8.0 / float(compiled["step_m"])))
	for index in range(0, points.size(), _stride8):
		_samples8.append(points[index])
	# Massing anchors derived from the frozen centreline, never hand-typed.
	var lake := _frame(Layout.LAKE_STATION_S)
	_lake_across = Vector2(lake.basis.x.x, lake.basis.x.z).normalized()
	_lake_along = Vector2(-lake.basis.z.x, -lake.basis.z.z).normalized()
	_lake_centre = Vector2(lake.origin.x, lake.origin.z) + _lake_across * (Layout.LAKE_NEAR_LATERAL_M + Layout.LAKE_HALF_WIDTH_M)
	var kart := _frame(Layout.KART_STATION_S)
	_kart_centre = Vector2(kart.origin.x, kart.origin.z) - Vector2(kart.basis.x.x, kart.basis.x.z) * Layout.KART_INSET_M
	var senna := _frame(Layout.SENNA_HILL_STATION_S)
	_senna_centre = Vector2(senna.origin.x, senna.origin.z) + Vector2(senna.basis.x.x, senna.basis.x.z) * Layout.SENNA_HILL_OFFSET_M
	_senna_level = _frame(Layout.LANDMARK_SENNA_S).origin.y - Layout.ROADBED_DROP_M
	_kart_level = _frame(Layout.KART_STATION_S).origin.y - Layout.ROADBED_DROP_M
	_tower_level = _frame(Layout.LANDMARK_TOWER_S).origin.y - Layout.ROADBED_DROP_M
	var min_road := INF
	var s := 1500.0
	while s <= 2100.0:
		min_road = minf(min_road, _frame(s).origin.y)
		s += 10.0
	_lake_water_y = min_road - Layout.LAKE_WATER_DROP_M
	_lake_floor_y = _lake_water_y - Layout.LAKE_DEPTH_M
	_promenade_y = _lake_water_y + Layout.RESERVOIR_WATERLINE_DEPTH_M
	_build_field()
	_build_heightgrid()


# --- natural field ---------------------------------------------------------------------

func _build_field() -> void:
	var origin := bbox.position
	_field_nx = int(ceil(bbox.size.x / FIELD_STEP_M)) + 1
	_field_nz = int(ceil(bbox.size.y / FIELD_STEP_M)) + 1
	_field_values.resize(_field_nx * _field_nz)
	for iz in range(_field_nz):
		var z := origin.y + float(iz) * FIELD_STEP_M
		for ix in range(_field_nx):
			var x := origin.x + float(ix) * FIELD_STEP_M
			var sum := 0.0
			var weight := 0.0
			for sample: Vector3 in _coarse:
				var dx := sample.x - x
				var dz := sample.z - z
				var w := 1.0 / (dx * dx + dz * dz + 3600.0)
				sum += sample.y * w
				weight += w
			_field_values[iz * _field_nx + ix] = sum / weight


func _field_height(x: float, z: float) -> float:
	var fx := (x - bbox.position.x) / FIELD_STEP_M
	var fz := (z - bbox.position.y) / FIELD_STEP_M
	var ix := clampi(int(floor(fx)), 0, _field_nx - 2)
	var iz := clampi(int(floor(fz)), 0, _field_nz - 2)
	var tx := clampf(fx - float(ix), 0.0, 1.0)
	var tz := clampf(fz - float(iz), 0.0, 1.0)
	var a := lerpf(_field_values[iz * _field_nx + ix], _field_values[iz * _field_nx + ix + 1], tx)
	var b := lerpf(_field_values[(iz + 1) * _field_nx + ix], _field_values[(iz + 1) * _field_nx + ix + 1], tx)
	return lerpf(a, b, tz)


## Rolling Paulistano relief and the authored massing: the Guarapiranga basin
## (low point of the frozen profile), the Senna amphitheatre hill outside T1 and
## the laterite ridges that close the horizon.
func _natural_height(x: float, z: float) -> float:
	var h := _field_height(x, z) + _noise.get_noise_2d(x, z) * 5.0 + _noise_mid.get_noise_2d(x, z) * 1.8 + _noise_fine.get_noise_2d(x, z) * 0.6
	var senna_d := Vector2(x, z).distance_to(_senna_centre)
	if senna_d < Layout.SENNA_HILL_RADIUS_M:
		var t := senna_d / Layout.SENNA_HILL_RADIUS_M
		h += Layout.SENNA_HILL_HEIGHT_M * pow(cos(t * PI * 0.5), 2.0)
	var kart_d := Vector2(x, z).distance_to(_kart_centre)
	if kart_d < Layout.KART_RADIUS_M:
		var t := kart_d / Layout.KART_RADIUS_M
		h += Layout.KART_PLATEAU_M * pow(cos(t * PI * 0.5), 2.0)
	# Laterite ridge masses outside the playable lap give the horizon depth.
	for mass: Array in [
		[Vector2(-900.0, -1080.0), 520.0, 34.0],
		[Vector2(950.0, -260.0), 480.0, 32.0],
		[Vector2(140.0, -1120.0), 500.0, 26.0],
	]:
		var centre: Vector2 = mass[0]
		var radius: float = mass[1]
		var d := Vector2(x, z).distance_to(centre)
		if d < radius:
			var t := d / radius
			h += float(mass[2]) * pow(cos(t * PI * 0.5), 2.0)
	return h


# --- height field ----------------------------------------------------------------------

func _build_heightgrid() -> void:
	var step := Layout.TERRAIN_STEP_M
	var nx := int(ceil(bbox.size.x / step)) + 1
	var nz := int(ceil(bbox.size.y / step)) + 1
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
	var bed_limit := PackedFloat32Array()
	bed_limit.resize(nx * nz)
	bed_limit.fill(INF)
	for iz in range(nz):
		var z := bbox.position.y + float(iz) * step
		for ix in range(nx):
			var h := _natural_height(bbox.position.x + float(ix) * step, z)
			heights[iz * nx + ix] = h
			originals[iz * nx + ix] = h
	# 1) Nearest-centreline stamp: every cell inside the blend radius remembers its
	#    nearest compiled sample so the bed can be cut per station below.
	var half := CORRIDOR_BLEND_END_M + 20.0
	var stamp_stride := maxi(1, roundi(STAMP_STEP_M / float(compiled["step_m"])))
	for index in range(0, points.size(), stamp_stride):
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
				if d >= half:
					continue
				var vi := iz * nx + ix
				if d >= near_dist[vi]:
					continue
				near_dist[vi] = d
				near_index[vi] = index
	# 2) Road bed: 0.16 m under the local *lowest* asphalt sample within +-1 m of the
	#    projection. Using the window minimum keeps every interpolated cell edge below
	#    the road on the 12 m grid (HUKUM 0 FLOATING ROAD).
	var count := points.size()
	for iz in range(nz):
		var z := bbox.position.y + float(iz) * step
		for ix in range(nx):
			var vi := iz * nx + ix
			if near_index[vi] < 0 or near_dist[vi] >= CORRIDOR_BLEND_END_M:
				continue
			var idx := near_index[vi]
			var bed_y := points[idx].y
			for offset in range(-BED_WINDOW_SAMPLES, BED_WINDOW_SAMPLES + 1):
				bed_y = minf(bed_y, points[posmod(idx + offset, count)].y)
			var bed := bed_y - Layout.ROADBED_DROP_M
			if near_dist[vi] <= CORRIDOR_FLAT_M:
				heights[vi] = bed
				bed_limit[vi] = bed
			else:
				var t := _smoothstep((near_dist[vi] - CORRIDOR_FLAT_M) / (CORRIDOR_BLEND_END_M - CORRIDOR_FLAT_M))
				heights[vi] = lerpf(bed, originals[vi], t)
	# 3) Drainage ditch on the outer verge: a shallow V just past the flat shelf.
	for iz in range(nz):
		for ix in range(nx):
			var vi := iz * nx + ix
			var d := near_dist[vi]
			if d < DITCH_START_M or d > DITCH_START_M + DITCH_WIDTH_M:
				continue
			var t := (d - DITCH_START_M) / DITCH_WIDTH_M
			heights[vi] -= DITCH_DEPTH_M * sin(PI * t)
	# 4) Guarapiranga reservoir basin: carve the strip water band outside T5-T6
	#    below the water line, leaving laterite banks at both ends.
	_stamp_reservoir(heights, bed_limit, near_dist, nx, nz, step)
	# 5) Solid level terraces under the stands, the paddock platform and the hero
	#    landmark footprints. Stamped after the ditch/lake so they overwrite them.
	# The paddock pads are the environment's apron slabs (one spec, Layout.PADDOCK_APRON_SPECS),
	# stamped just under the slab so no slab edge hovers over a lower terrace, then a berm
	# falls from every pad edge (both sides and both ends) to the natural laterite slope.
	var pad_level := PackedFloat32Array()
	pad_level.resize(nx * nz)
	pad_level.fill(INF)
	for spec: Array in Layout.PADDOCK_APRON_SPECS:
		_stamp_apron_pad(heights, pad_mask, pad_level, near_index, nx, nz, step, spec)
	_stamp_pad_berms(heights, pad_level, bed_limit, near_index, near_dist, nx, nz, step)
	# Rigid hero landmarks need a dead-level terrace: a constant bed elevation, not a
	# ramp along the gradient.
	var drop := Layout.ROADBED_DROP_M
	_stamp_level_pad(heights, pad_mask, near_dist, nx, nz, step, 260.0, 340.0, 1.0, 40.0, 112.0, 2, _senna_level)
	_stamp_level_pad(heights, pad_mask, near_dist, nx, nz, step, 4180.0, 4260.0, -1.0, 20.0, 82.0, 1, _tower_level)
	# Seawall terrace behind the reservoir promenade: level with the GLB promenade top, so the
	# promenade neither floats over nor sinks into the bank between the track and the water.
	_stamp_level_pad(heights, pad_mask, near_dist, nx, nz, step, Layout.LAKE_STATION_S - 175.0, Layout.LAKE_STATION_S + 175.0, 1.0, 15.0, Layout.LAKE_NEAR_LATERAL_M, 2, _promenade_y - 0.04)
	_stamp_circle_pad(heights, pad_mask, nx, nz, step, _kart_centre, Layout.KART_RADIUS_M, 2, _kart_level)
	# A terrace may never rise into the asphalt: clamp every corridor cell back to
	# its own bed so the pads cannot lift the road edge on a gradient.
	for vi in range(nx * nz):
		if bed_limit[vi] < INF and heights[vi] > bed_limit[vi]:
			heights[vi] = bed_limit[vi]
	heightgrid = {
		"origin": bbox.position, "step": step, "nx": nx, "nz": nz,
		"heights": heights, "pad_mask": pad_mask, "base_y": BASE_Y,
		"lake_centre": _lake_centre, "kart_centre": _kart_centre, "senna_centre": _senna_centre,
		"lake_water_y": _lake_water_y, "lake_floor_y": _lake_floor_y, "promenade_y": _promenade_y,
		"kart_level": _kart_level, "senna_level": _senna_level, "tower_level": _tower_level,
	}
	terrain_mesh = _build_terrain_mesh(nx, nz, step, heights, pad_mask)
	skirt_mesh = _build_skirt_mesh(nx, nz, step, heights)
	ridge_mesh = _build_ridge_mesh()


## Guarapiranga basin shape: < 1 inside the water, 1 on the shoreline, > 1 outside. A superellipse
## in the lake frame: square-ish (n = 6) on the near side so the shore runs straight under the
## seawall, rounder (n = 2.4) and noise-wobbled on the far side and at both ends.
func lake_shape(x: float, z: float) -> float:
	var d := Vector2(x, z) - _lake_centre
	var u := d.dot(_lake_along)
	var v := d.dot(_lake_across)
	var wobble := 1.0 + 0.16 * _noise.get_noise_2d(x * 1.7, z * 1.7)
	var a := Layout.LAKE_HALF_LENGTH_M * (wobble if v > 0.0 else 1.0)
	var b := Layout.LAKE_HALF_WIDTH_M * (wobble if v > 0.0 else 1.0)
	var n := 6.0 if v < 0.0 else 2.4
	return pow(pow(absf(u) / a, n) + pow(absf(v) / b, n), 1.0 / n)


## Metres from the shoreline (negative in the water), from the shape value.
func lake_shore_distance(x: float, z: float) -> float:
	return (lake_shape(x, z) - 1.0) * Layout.LAKE_HALF_WIDTH_M


## Basin and banks as one continuous field per grid vertex: a 0.4 m shelf at the waterline
## deepening to the floor over 45 m (straight down under the seawall), and an 80 m bank that
## rises from just over the waterline into the natural relief, never back under it. The road
## corridor keeps its bed; the seawall terrace (level pad) is stamped afterwards.
func _stamp_reservoir(heights: PackedFloat32Array, bed_limit: PackedFloat32Array, near_dist: PackedFloat32Array, nx: int, nz: int, step: float) -> void:
	var shore_y := _lake_water_y + 0.35
	for iz in range(nz):
		var z := bbox.position.y + float(iz) * step
		for ix in range(nx):
			var vi := iz * nx + ix
			# The road shelf keeps its bed; across the shelf blend the lake fades in, so the bank meets
			# the road cut as one slope instead of a hill left standing beside a lowered shore.
			if bed_limit[vi] < INF:
				continue
			var x := bbox.position.x + float(ix) * step
			var sd := lake_shore_distance(x, z)
			if sd >= Layout.LAKE_BANK_M:
				continue
			var keep := heights[vi]
			if sd < 0.0:
				var near_side := (Vector2(x, z) - _lake_centre).dot(_lake_across) < 0.0
				var shelf := 18.0 if near_side else 45.0
				heights[vi] = _lake_water_y - 0.4 - (Layout.LAKE_DEPTH_M - 0.4) * _smoothstep(-sd / shelf) + _noise_fine.get_noise_2d(x, z) * 0.25
			else:
				var t := _smoothstep(sd / Layout.LAKE_BANK_M)
				heights[vi] = maxf(lerpf(shore_y, heights[vi], t), shore_y + sd * 0.04)
			if near_dist[vi] < CORRIDOR_BLEND_END_M:
				var w := _smoothstep((near_dist[vi] - CORRIDOR_FLAT_M) / (CORRIDOR_BLEND_END_M - CORRIDOR_FLAT_M))
				heights[vi] = lerpf(keep, heights[vi], w)


## One paddock apron slab as a terrain pad: every cell under the slab footprint (and one
## cell beyond, so the 12 m grid cannot dip under an edge) sits PADDOCK_PAD_UNDER_M under
## the slab, which rides the road grade and is level across. A cell whose nearest track
## point lies on another stretch of road (the infield hairpins) is left to that road.
func _stamp_apron_pad(heights: PackedFloat32Array, pad_mask: PackedByteArray, pad_level: PackedFloat32Array, near_index: PackedInt32Array, nx: int, nz: int, step: float, spec: Array) -> void:
	var side: float = float(spec[0])
	var s0: float = float(spec[1])
	var s1: float = float(spec[2])
	var lat0: float = float(spec[3])
	var lat1: float = float(spec[4]) + step
	var s := s0 - step
	while s <= s1 + step:
		var frame := _frame(fposmod(s, Layout.LENGTH_M))
		var level := frame.origin.y + Layout.PADDOCK_APRON_LIFT_M - Layout.PADDOCK_PAD_UNDER_M
		var lateral := lat0
		while lateral <= lat1:
			var cell := _cell_of(frame.origin + frame.basis.x * (side * lateral), nx, nz, step)
			lateral += 2.0
			if cell.x < 0:
				continue
			var vi: int = cell.y * nx + cell.x
			if not _on_stretch(near_index[vi], s, lateral + 30.0):
				continue
			heights[vi] = level
			pad_level[vi] = level if is_inf(pad_level[vi]) else maxf(pad_level[vi], level)
			pad_mask[vi] = 1
		s += 2.0


## True when the track point a cell is nearest to is this stretch (within `reach` metres of
## arc from station s), or when no track is near at all.
func _on_stretch(index: int, s: float, reach: float) -> bool:
	if index < 0:
		return true
	var near_s: float = float(index) * float(compiled["step_m"])
	var gap: float = absf(fposmod(near_s - s + Layout.LENGTH_M * 0.5, Layout.LENGTH_M) - Layout.LENGTH_M * 0.5)
	return gap <= reach


## Laterite berm round the whole pad perimeter, ends included: each cell within
## PADDOCK_BERM_M of a pad takes the nearest pad's level and eases back to its own ground,
## so no slab edge or stand corner hangs over a slope. The road corridor and cells that
## belong to another stretch of road keep their own heights.
func _stamp_pad_berms(heights: PackedFloat32Array, pad_level: PackedFloat32Array, bed_limit: PackedFloat32Array, near_index: PackedInt32Array, near_dist: PackedFloat32Array, nx: int, nz: int, step: float) -> void:
	var reach := ceili(Layout.PADDOCK_BERM_M / step)
	var best_d := PackedFloat32Array()
	best_d.resize(nx * nz)
	best_d.fill(INF)
	var best_level := PackedFloat32Array()
	best_level.resize(nx * nz)
	for iz in range(nz):
		for ix in range(nx):
			var level: float = pad_level[iz * nx + ix]
			if is_inf(level):
				continue
			for dz in range(-reach, reach + 1):
				for dx in range(-reach, reach + 1):
					var jx := ix + dx
					var jz := iz + dz
					if jx < 0 or jz < 0 or jx >= nx or jz >= nz:
						continue
					var vj := jz * nx + jx
					var d := step * sqrt(float(dx * dx + dz * dz))
					if d < best_d[vj]:
						best_d[vj] = d
						best_level[vj] = level
	for vi in range(nx * nz):
		var d: float = best_d[vi]
		if not is_inf(pad_level[vi]) or d > Layout.PADDOCK_BERM_M or bed_limit[vi] < INF:
			continue
		# Another road's own banks are not the paddock's to reshape.
		if near_index[vi] >= 0 and near_dist[vi] < CORRIDOR_BLEND_END_M and not _paddock_stretch(near_index[vi]):
			continue
		heights[vi] = lerpf(best_level[vi], heights[vi], _smoothstep(d / Layout.PADDOCK_BERM_M))


func _paddock_stretch(index: int) -> bool:
	for spec: Array in Layout.PADDOCK_APRON_SPECS:
		var s0: float = float(spec[1])
		var s1: float = float(spec[2])
		if _on_stretch(index, (s0 + s1) * 0.5, (s1 - s0) * 0.5 + 40.0):
			return true
	return false

## Dead-level terrace at a constant elevation for the rigid hero landmark slabs.
## Inside the road corridor it fades into the road shelf instead of cutting a trench.
func _stamp_level_pad(heights: PackedFloat32Array, pad_mask: PackedByteArray, near_dist: PackedFloat32Array, nx: int, nz: int, step: float, s0: float, s1: float, side: float, lat0: float, lat1: float, kind: int, level_y: float) -> void:
	var s := s0
	while s <= s1:
		var frame := _frame(s)
		var right := frame.basis.x
		var lateral := lat0
		while lateral <= lat1:
			var cell := _cell_of(frame.origin + right * (side * lateral), nx, nz, step)
			if cell.x >= 0:
				var vi: int = cell.y * nx + cell.x
				var d := near_dist[vi]
				# The paddock apron keeps its graded pad; the landmark terrace steps down beside it.
				if d > CORRIDOR_FLAT_M and pad_mask[vi] != 1:
					if d < CORRIDOR_BLEND_END_M:
						var t := _smoothstep((d - CORRIDOR_FLAT_M) / (CORRIDOR_BLEND_END_M - CORRIDOR_FLAT_M))
						heights[vi] = lerpf(heights[vi], level_y, t)
					else:
						heights[vi] = level_y
					pad_mask[vi] = kind
			lateral += 4.0
		s += 4.0


## Circular level plateau (kartodromo infield): a constant elevation disc blended
## into the natural hill over a 12 m rim.
func _stamp_circle_pad(heights: PackedFloat32Array, pad_mask: PackedByteArray, nx: int, nz: int, step: float, centre: Vector2, radius: float, kind: int, level_y: float) -> void:
	var cell_radius := int(ceil((radius + 12.0) / step))
	var centre_cell := _cell_of(Vector3(centre.x, 0.0, centre.y), nx, nz, step)
	for dz in range(-cell_radius, cell_radius + 1):
		for dx in range(-cell_radius, cell_radius + 1):
			var ix := centre_cell.x + dx
			var iz := centre_cell.y + dz
			if ix < 0 or iz < 0 or ix >= nx or iz >= nz:
				continue
			var x := bbox.position.x + float(ix) * step
			var z := bbox.position.y + float(iz) * step
			var d := Vector2(x, z).distance_to(centre)
			if d > radius + 12.0:
				continue
			var vi := iz * nx + ix
			if d <= radius:
				heights[vi] = level_y
			else:
				heights[vi] = lerpf(level_y, heights[vi], _smoothstep((d - radius) / 12.0))
			pad_mask[vi] = kind


func _cell_of(p: Vector3, nx: int, nz: int, step: float) -> Vector2i:
	var ix := int(round((p.x - bbox.position.x) / step))
	var iz := int(round((p.z - bbox.position.y) / step))
	if ix < 0 or iz < 0 or ix >= nx or iz >= nz:
		return Vector2i(-1, -1)
	return Vector2i(ix, iz)


# --- meshes ----------------------------------------------------------------------------

func _build_terrain_mesh(nx: int, nz: int, step: float, heights: PackedFloat32Array, pad_mask: PackedByteArray) -> ArrayMesh:
	var colors := PackedColorArray()
	colors.resize(nx * nz)
	for iz in range(nz):
		var z := bbox.position.y + float(iz) * step
		for ix in range(nx):
			var x := bbox.position.x + float(ix) * step
			colors[iz * nx + ix] = _ground_color(x, z, heights[iz * nx + ix], pad_mask[iz * nx + ix], nx, nz, step, heights)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for iz in range(nz - 1):
		var z0 := bbox.position.y + float(iz) * step
		var z1 := z0 + step
		for ix in range(nx - 1):
			var x0 := bbox.position.x + float(ix) * step
			var x1 := x0 + step
			var i00 := iz * nx + ix
			var i10 := i00 + 1
			var i01 := i00 + nx
			var i11 := i01 + 1
			var v00 := Vector3(x0, heights[i00], z0)
			var v10 := Vector3(x1, heights[i10], z0)
			var v11 := Vector3(x1, heights[i11], z1)
			var v01 := Vector3(x0, heights[i01], z1)
			_tri(st, v00, v10, v11, colors[i00], colors[i10], colors[i11])
			_tri(st, v00, v11, v01, colors[i00], colors[i11], colors[i01])
	st.generate_normals()
	var mesh := st.commit()
	if mesh != null:
		var material := ShaderMaterial.new()
		material.shader = TerrainShader
		mesh.surface_set_material(0, material)
	return mesh


func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, ca: Color, cb: Color, cc: Color) -> void:
	st.set_color((ca).srgb_to_linear())
	st.add_vertex(a)
	st.set_color((cb).srgb_to_linear())
	st.add_vertex(b)
	st.set_color((cc).srgb_to_linear())
	st.add_vertex(c)


func _ground_color(x: float, z: float, height: float, pad: int, nx: int, nz: int, step: float, heights: PackedFloat32Array) -> Color:
	var n := _noise.get_noise_2d(x * 1.7, z * 1.7)
	var color := GRASS_A.lerp(GRASS_B, 0.5 + n * 0.5)
	# Laterite (red São Paulo soil) shows through on the dry banks and the high ground.
	var damp := _noise_tint.get_noise_2d(x, z)
	if damp > 0.05:
		color = color.lerp(LATERITE, clampf((damp - 0.05) * 0.9, 0.0, 0.7))
	if height > 22.0:
		color = color.lerp(FOREST_FLOOR, clampf((height - 22.0) / 18.0, 0.0, 0.55))
	var slope := _slope_at(x, z, nx, nz, step, heights)
	if slope > 0.62:
		color = ROCK.lerp(color, clampf(1.35 - slope, 0.0, 0.65))
	elif slope > 0.4:
		color = color.lerp(LATERITE_DARK, (slope - 0.4) * 0.9)
	# Wet reservoir shoreline reads as dark mud/sand.
	if height < _lake_water_y + 0.6:
		color = color.lerp(Color("#6b5a41"), 0.55)
	if pad == 1:
		color = PAD_COLOR
	elif pad == 2:
		color = GRASS_A.lerp(LATERITE, 0.18)
	elif pad == 3:
		color = ROCK.lerp(LATERITE_DARK, 0.4)
	return color


func _slope_at(x: float, z: float, nx: int, nz: int, step: float, heights: PackedFloat32Array) -> float:
	var ix := clampi(int(round((x - bbox.position.x) / step)), 1, nx - 2)
	var iz := clampi(int(round((z - bbox.position.y) / step)), 1, nz - 2)
	var hx := heights[iz * nx + ix + 1] - heights[iz * nx + ix - 1]
	var hz := heights[(iz + 1) * nx + ix] - heights[(iz - 1) * nx + ix]
	return sqrt(hx * hx + hz * hz) / (2.0 * step)


func _build_skirt_mesh(nx: int, nz: int, step: float, heights: PackedFloat32Array) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var color := Color("#3b4530")
	var edges: Array = []
	for iz: int in [0, nz - 1]:
		var z := bbox.position.y + float(iz) * step
		var strip: Array[Vector3] = []
		for ix in range(nx):
			strip.append(Vector3(bbox.position.x + float(ix) * step, heights[iz * nx + ix], z))
		edges.append(strip)
	for ix: int in [0, nx - 1]:
		var x := bbox.position.x + float(ix) * step
		var strip: Array[Vector3] = []
		for iz in range(nz):
			strip.append(Vector3(x, heights[iz * nx + ix], bbox.position.y + float(iz) * step))
		edges.append(strip)
	for strip: Array in edges:
		for index in range((strip as Array).size() - 1):
			var a: Vector3 = strip[index]
			var b: Vector3 = strip[index + 1]
			var a0 := Vector3(a.x, SKIRT_BASE_Y, a.z)
			var b0 := Vector3(b.x, SKIRT_BASE_Y, b.z)
			# Both windings keep the wall closed seen from either side.
			for tri: Array in [[a, a0, b0, a, b0, b], [a, b0, a0, a, b, b0]]:
				for vertex: Vector3 in tri:
					st.set_color((color).srgb_to_linear())
					st.add_vertex(vertex)
	st.generate_normals()
	var mesh := st.commit()
	if mesh != null:
		var material := Toon.vertex_colored(false)
		material.set_shader_parameter("rim_intensity", 0.0)
		mesh.surface_set_material(0, material)
	return mesh


## Low laterite ridge line on the horizon: a three-ring skirt of green-brown
## hills well outside the playable bbox, so gaps between terrain edge and sky are filled.
func _build_ridge_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var centre := Vector2((bbox.position.x + bbox.end.x) * 0.5, (bbox.position.y + bbox.end.y) * 0.5)
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
		var noise := sin(float(index) * 0.81) * 0.5 + sin(float(index) * 0.29 + 1.1) * 0.35
		var ridge_h := 30.0 + (noise + 0.85) * 30.0
		var back_h := ridge_h * 0.72
		inner_ring.append(Vector3(centre.x + cos(angle) * 2500.0, -40.0, centre.y + sin(angle) * 2500.0))
		ridge_ring.append(Vector3(centre.x + cos(angle) * 3000.0, ridge_h, centre.y + sin(angle) * 3000.0))
		back_ring.append(Vector3(centre.x + cos(angle) * 3500.0, back_h, centre.y + sin(angle) * 3500.0))
	for index in range(segments):
		var next := index + 1
		_ridge_quad(st, inner_ring[index], ridge_ring[index], ridge_ring[next], inner_ring[next], RIDGE_A.darkened(0.2), RIDGE_A)
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
		st.set_color((colors[index]).srgb_to_linear())
		st.add_vertex(verts[index])


# --- queries ---------------------------------------------------------------------------

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
	var a := lerpf(heights[iz * nx + ix], heights[iz * nx + ix + 1], tx)
	var b := lerpf(heights[(iz + 1) * nx + ix], heights[(iz + 1) * nx + ix + 1], tx)
	return lerpf(a, b, tz)


## True where the paddock / stand terraces are paved-hard and vegetation must not spawn.
func is_flat(x: float, z: float) -> bool:
	var grid := heightgrid
	if grid.is_empty():
		return false
	var step: float = float(grid.get("step", Layout.TERRAIN_STEP_M))
	var nx: int = int(grid.get("nx", 0))
	var nz: int = int(grid.get("nz", 0))
	var origin: Vector2 = grid.get("origin", Vector2.ZERO)
	var mask: PackedByteArray = grid.get("pad_mask", PackedByteArray())
	if mask.is_empty():
		return false
	var ix := int(round((x - origin.x) / step))
	var iz := int(round((z - origin.y) / step))
	if ix < 0 or iz < 0 or ix >= nx or iz >= nz:
		return false
	return mask[iz * nx + ix] != 0


## Brute-force nearest track query on the 8 m sample set, refined on the fine line.
## Returns {} when the point sits further than `max_d` from the asphalt, else
## {d, s, lateral (signed, + = right of travel), y, side}.
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
	var centre_index := best_index * _stride8
	best_index = centre_index
	var origin_point := points[best_index]
	var ox := origin_point.x - x
	var oz := origin_point.z - z
	best = ox * ox + oz * oz
	for offset in range(-24, 25):
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
	var lateral := Vector2(p.x - x, p.z - z).dot(Vector2(right.x, right.z))
	var d := sqrt(best)
	if d > max_d and approx_d > max_d:
		return {}
	return {"d": d, "s": float(best_index) * float(compiled["step_m"]), "lateral": lateral, "y": p.y, "side": signf(lateral)}


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
	for mesh: ArrayMesh in [terrain_mesh, skirt_mesh, ridge_mesh]:
		if mesh == null:
			continue
		for surface in mesh.get_surface_count():
			var arrays := mesh.surface_get_arrays(surface)
			var indices: Variant = arrays[Mesh.ARRAY_INDEX]
			total += (indices.size() if indices != null else (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()) / 3
	return total


# --- helpers ---------------------------------------------------------------------------

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
