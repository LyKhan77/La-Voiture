class_name TracksideFurnitureBuilder
extends Node3D

## Trackside safety furniture for the Apex Ring (FASE 10), built as four MultiMesh nodes so
## the whole set costs a handful of draw calls: FIA triple-rib Armco with a post every
## 4 m (open at the pit lane), Tecpro foam barriers on the outside of the critical corners,
## 150/100/50 m braking boards before every sharp corner and 28 stadium floodlight towers.
## Positions come from the ribbon; this node is expected to sit under an identity transform.

const TrackRibbonScript := preload("res://scripts/car/track_ribbon.gd")
const AdaptiveLineScript := preload("res://scripts/car/adaptive_racing_line.gd")
const PitLaneScript := preload("res://scripts/world/pit_lane_complex.gd")
const ToonMaterials := preload("res://scripts/world/toon_materials.gd")
const SurfaceGeometry := preload("res://scripts/world/enhanced_track_geometry.gd")
const MeshBatchScript := preload("res://scripts/world/mesh_batch.gd")
const MarkerShader := preload("res://shaders/braking_marker.gdshader")

# --- armco ---------------------------------------------------------------------
## Along-the-rail spacing of posts (and rail sections).
const ARMCO_STEP_M: float = 4.0
## Granularity of the walk that measures rail length.
const ARMCO_WALK_M: float = 0.5
## Distance from the road edge to the rail on a normal stretch; it moves out behind a gravel trap.
const ARMCO_GAP_M: float = 4.5
const ARMCO_BEHIND_TRAP_M: float = 1.5
## Radius, in table samples, of the filters that smooth the rail's outward swing.
const EXTENT_FILTER_SAMPLES: int = 5
## Catch fence and Tecpro only stand where the rail is pushed out behind a trap (at least this far).
const BARRIER_ROW_MIN_EXTENT_M: float = 6.0
const RAIL_BOTTOM_M: float = 0.25
const RAIL_HEIGHT_M: float = 0.65
const RAIL_DEPTH_M: float = 0.08
const RAIL_BACK_M: float = 0.03
const RAIL_RIBS: int = 3
const RAIL_LENGTH_M: float = 4.06
const POST_HEIGHT_M: float = 0.95
const POST_SETBACK_M: float = 0.13
const PIT_OPEN_LEAD_M: float = 20.0
const PIT_OPEN_TRAIL_M: float = 40.0
const RAIL_COLOR := Color("#9aa1ae")
const POST_COLOR := Color("#4a505c")

# --- tecpro --------------------------------------------------------------------
const TECPRO_STEP_M: float = 2.0
const TECPRO_HALF_RUN_M: float = 45.0
const TECPRO_DEPTH_M: float = 0.9
const TECPRO_HEIGHT_M: float = 0.95
## Stands this far in front of the armco (toward the track).
const TECPRO_FRONT_GAP_M: float = 0.9
const TECPRO_RED := Color("#d9232e")
const TECPRO_GREY := Color("#3a3f4a")
const TECPRO_STRAP := Color("#15171d")
## Two corners are a chicane when the next kerb starts this close after the previous one ends.
const CHICANE_GAP_M: float = 20.0

# --- braking markers -----------------------------------------------------------
const MARKER_DISTANCES_M: Array[int] = [150, 100, 50]
## Board stands this far off the road edge, on the inside of the corner.
const MARKER_OFFSET_M: float = 2.5
const MARKER_BOARD_W_M: float = 1.2
const MARKER_BOARD_H_M: float = 0.85
const MARKER_BOARD_BASE_M: float = 1.35
const HAZARD_YELLOW := Color("#ffd400")
const HAZARD_BLACK := Color("#14161c")

# --- floodlights -----------------------------------------------------------------
const TOWER_COUNT: int = 28
const TOWER_BASE_HALF_M: float = 0.95
const TOWER_TOP_HALF_M: float = 0.32
const TOWER_MAST_M: float = 15.9
const TOWER_BRACE_STEP_M: float = 3.0
const TOWER_BEHIND_M: float = 4.0
const TOWER_MIN_SPACING_M: float = 50.0
## A tower must be at least this far from every stretch of road (its own included).
const TOWER_MIN_ROAD_M: float = 15.0
const TOWER_SHIFTS_M: Array[float] = [0.0, 30.0, -30.0, 60.0, -60.0, 90.0, -90.0]
const LAMP_COLUMNS: int = 4
const LAMP_ROWS: int = 2
const LAMP_TILT: float = deg_to_rad(28.0)
const LAMP_GLOW_ALPHA: float = 0.0
const STEEL_COLOR := Color("#8a92a3")
const DARK_STEEL_COLOR := Color("#2d313b")
const LAMP_COLOR := Color(1.0, 0.95, 0.82, LAMP_GLOW_ALPHA)

var ribbon: TrackRibbonScript
var line: AdaptiveLineScript

var armco_instance: MultiMeshInstance3D
var tecpro_instance: MultiMeshInstance3D
var marker_instance: MultiMeshInstance3D
## The 7-segment board face; the lighting controller dims it at night.
var marker_face_material: ShaderMaterial
var tower_instance: MultiMeshInstance3D
## The poses handed to each MultiMesh, kept here as well: headless runs have no MultiMesh data to read back.
var armco_transforms: Array[Transform3D] = []
## Arc distance each pose was generated at (parallel to the transform arrays).
var armco_arcs: PackedFloat32Array = PackedFloat32Array()
var tecpro_arcs: PackedFloat32Array = PackedFloat32Array()
var tecpro_transforms: Array[Transform3D] = []
var marker_transforms: Array[Transform3D] = []
var tower_transforms: Array[Transform3D] = []
var armco_post_count: int = 0
var tecpro_count: int = 0
var tower_count: int = 0
## One record per braking board: {corner, meters, s, side}.
var marker_records: Array[Dictionary] = []
## One record per tower: {s, side, lateral, position}.
var tower_records: Array[Dictionary] = []
## One entry per unbroken stretch of rail: {side, first, count, s0, s1} indexing armco_transforms.
var armco_runs: Array[Dictionary] = []

var _centre_samples: Dictionary = {}
var _plans: Array[Dictionary] = []
var _hero_zones: Array[Dictionary] = []
var _extent_left: PackedFloat32Array = PackedFloat32Array()
var _extent_right: PackedFloat32Array = PackedFloat32Array()
var _extent_step: float = 4.0


## `kerbs` are the sharp-corner runs, `plans` the runoff plans (the armco stands behind the traps).
## `hero_zones` push the floodlights back behind landmarks: {side, s0, s1, lateral}.
func build(p_ribbon: TrackRibbonScript, p_line: AdaptiveLineScript, kerbs: Array[Dictionary], plans: Array[Dictionary], hero_zones: Array[Dictionary]) -> void:
	ribbon = p_ribbon
	line = p_line
	_plans = plans
	_hero_zones = hero_zones
	_centre_samples = SurfaceGeometry.hash_samples(ribbon)
	_build_extent_tables()
	_build_armco()
	_build_tecpro(kerbs)
	_build_markers(kerbs)
	_build_towers()


## Distance from the road edge to the rail at arc distance s: ARMCO_GAP_M, wider behind a gravel trap.
func extent_at(side: float, s: float) -> float:
	var table: PackedFloat32Array = _extent_left if side < 0.0 else _extent_right
	var position: float = fposmod(s, ribbon.length_m) / _extent_step
	var index: int = int(position)
	return lerpf(table[index % table.size()], table[(index + 1) % table.size()], position - float(index))


## Signed lateral of the rail's back plane (+ = right of travel).
func armco_lateral(side: float, s: float) -> float:
	return side * (ribbon.road_half_width_m + extent_at(side, s))


## True where guardrail stands on `side` at arc distance `s` (the right side is open at the pit lane).
func has_armco_at(side: float, s: float) -> bool:
	var wrapped: float = fposmod(s, ribbon.length_m)
	for range_s: Vector2 in armco_ranges_for(side):
		if wrapped >= range_s.x and wrapped <= range_s.y:
			return true
	return false


## True where a second row of barrier (Tecpro, catch fence) fits: the rail is pushed out behind a trap, the
## guardrail exists there, and a row `behind_m` further back (0 = at the rail) still stands on this
## road's side of the middle of any gap to another stretch of road.
func has_barrier_row_at(side: float, s: float, behind_m: float = 0.0) -> bool:
	var extent: float = extent_at(side, s)
	if not has_armco_at(side, s) or extent < BARRIER_ROW_MIN_EXTENT_M:
		return false
	return behind_m <= 0.0 or SurfaceGeometry.max_extent(_centre_samples, ribbon, s, side, extent + behind_m) >= extent + behind_m - 0.01


## Arc ranges that carry guardrail on `side`. The right side is the pit lane's, so it stays
## open from a little before Pit Entry to a little after Pit Exit.
func armco_ranges_for(side: float) -> Array[Vector2]:
	var length: float = ribbon.length_m
	if side < 0.0:
		return [Vector2(0.0, length)]
	var open_start: float = fposmod(PitLaneScript.ENTRY_S - PIT_OPEN_LEAD_M, length)
	var open_end: float = open_start + PitLaneScript.NOMINAL_LENGTH_M + PIT_OPEN_LEAD_M + PIT_OPEN_TRAIL_M
	if open_end <= length:
		return [Vector2(0.0, open_start), Vector2(open_end, length)]
	return [Vector2(open_end - length, open_start)]


# --- armco ---------------------------------------------------------------------------

func _build_extent_tables() -> void:
	var count: int = ceili(ribbon.length_m / ARMCO_STEP_M)
	_extent_step = ribbon.length_m / float(count)
	for side: float in [-1.0, 1.0]:
		var raw := PackedFloat32Array()
		raw.resize(count)
		for index: int in range(count):
			var width: float = SurfaceGeometry.outside_width_at(_plans, side, float(index) * _extent_step)
			raw[index] = maxf(ARMCO_GAP_M, width + ARMCO_BEHIND_TRAP_M) if width > 0.0 else ARMCO_GAP_M
		# Widest wins within the radius (so the rail never cuts into a trap), then blur so it swings out gently.
		var smooth: PackedFloat32Array = _filter(_filter(_filter(raw, true), false), false)
		# Beside another stretch of road the rail may reach the middle of the gap and no further, so two
		# close roads end up with one median barrier instead of two rails side by side or crossing. The
		# limit follows the geometry sample by sample (it is continuous), so it needs no smoothing of its own.
		for index: int in range(count):
			smooth[index] = SurfaceGeometry.max_extent(_centre_samples, ribbon, float(index) * _extent_step, side, smooth[index])
		if side < 0.0:
			_extent_left = smooth
		else:
			_extent_right = smooth

func _filter(source: PackedFloat32Array, widest: bool) -> PackedFloat32Array:
	var count: int = source.size()
	var result := PackedFloat32Array()
	result.resize(count)
	for index: int in range(count):
		var best: float = 0.0
		var sum: float = 0.0
		for offset: int in range(-EXTENT_FILTER_SAMPLES, EXTENT_FILTER_SAMPLES + 1):
			var value: float = source[posmod(index + offset, count)]
			best = maxf(best, value)
			sum += value
		result[index] = best if widest else sum / float(2 * EXTENT_FILTER_SAMPLES + 1)
	return result


func _build_armco() -> void:
	var transforms: Array[Transform3D] = []
	for side: float in [-1.0, 1.0]:
		for range_s: Vector2 in armco_ranges_for(side):
			var run: Dictionary = {"side": side, "first": transforms.size(), "s0": range_s.x, "s1": range_s.x}
			# Walk the rail itself in small steps and measure its length (the centreline is longer than the
			# rail inside a bend and shorter outside), then space the posts evenly along it so a run that
			# closes the lap meets itself without a gap.
			var walk_s: Array[float] = [range_s.x]
			var walk_length: Array[float] = [0.0]
			var walked: Vector3 = ribbon.get_point_at_offset(range_s.x, armco_lateral(side, range_s.x)).origin
			var s: float = range_s.x
			while s < range_s.y:
				s = minf(s + ARMCO_WALK_M, range_s.y)
				var point: Vector3 = ribbon.get_point_at_offset(s, armco_lateral(side, s)).origin
				walk_length.append(walk_length[-1] + point.distance_to(walked))
				walk_s.append(s)
				walked = point
			var posts: int = maxi(1, roundi(walk_length[-1] / ARMCO_STEP_M))
			var spacing: float = walk_length[-1] / float(posts)
			var cursor: int = 0
			for post: int in range(posts):
				var target: float = (float(post) + 0.5) * spacing
				while cursor < walk_length.size() - 1 and walk_length[cursor + 1] < target:
					cursor += 1
				var span: float = maxf(walk_length[mini(cursor + 1, walk_length.size() - 1)] - walk_length[cursor], 1.0e-6)
				var post_s: float = lerpf(walk_s[cursor], walk_s[mini(cursor + 1, walk_s.size() - 1)], clampf((target - walk_length[cursor]) / span, 0.0, 1.0))
				var pose: Transform3D = ribbon.get_point_at_offset(post_s, armco_lateral(side, post_s))
				if side < 0.0:
					pose.basis = pose.basis.rotated(pose.basis.y, PI)
				transforms.append(pose)
				armco_arcs.append(post_s)
				run["s1"] = post_s
			run["count"] = transforms.size() - int(run["first"])
			armco_runs.append(run)
	armco_transforms = transforms
	armco_post_count = transforms.size()
	armco_instance = _add_multimesh("Armco", _armco_mesh(), transforms)

## One 4 m rail section and its post, merged into a single surface.
func _armco_mesh() -> ArrayMesh:
	var batch := MeshBatchScript.new()
	var material: ShaderMaterial = ToonMaterials.vertex_colored()
	batch.extrude(material, RAIL_COLOR, Transform3D.IDENTITY, _rail_profile(), RAIL_LENGTH_M)
	# A plain box stands for the I-beam post: the part is repeated ~2 000 times, so it stays at 12 triangles.
	batch.box(material, POST_COLOR, Transform3D(Basis.IDENTITY, Vector3(RAIL_BACK_M + POST_SETBACK_M * 0.5, POST_HEIGHT_M * 0.5, 0.0)), Vector3(0.12, POST_HEIGHT_M, 0.1))
	return batch.commit()


## Cross-section (x toward the back of the rail, y up): three trapezoid ribs facing the track (-x).
func _rail_profile() -> PackedVector2Array:
	var points := PackedVector2Array()
	var top: float = RAIL_BOTTOM_M + RAIL_HEIGHT_M
	var pitch: float = RAIL_HEIGHT_M / float(RAIL_RIBS)
	for rib: int in range(RAIL_RIBS):
		var y0: float = top - pitch * float(rib)
		points.append(Vector2(0.0, y0))
		points.append(Vector2(-RAIL_DEPTH_M, y0 - pitch * 0.25))
		points.append(Vector2(-RAIL_DEPTH_M, y0 - pitch * 0.75))
	points.append(Vector2(0.0, RAIL_BOTTOM_M))
	points.append(Vector2(RAIL_BACK_M, RAIL_BOTTOM_M))
	points.append(Vector2(RAIL_BACK_M, top))
	return points


# --- tecpro --------------------------------------------------------------------------

func _build_tecpro(kerbs: Array[Dictionary]) -> void:
	var transforms: Array[Transform3D] = []
	for corner: int in _critical_corners(kerbs):
		var kerb: Dictionary = kerbs[corner]
		var outside: float = -float(kerb["side"])
		var apex: float = _apex(kerb)
		var s: float = maxf(apex - TECPRO_HALF_RUN_M, float(kerb["s0"]) - 10.0)
		var end: float = minf(apex + TECPRO_HALF_RUN_M, float(kerb["s1"]) + 10.0)
		while s <= end:
			if not has_barrier_row_at(outside, s):
				s += TECPRO_STEP_M
				continue
			var pose: Transform3D = ribbon.get_point_at_offset(s, armco_lateral(outside, s) - outside * TECPRO_FRONT_GAP_M)
			if outside < 0.0:
				pose.basis = pose.basis.rotated(pose.basis.y, PI)
			transforms.append(pose)
			tecpro_arcs.append(s)
			s += TECPRO_STEP_M
	tecpro_transforms = transforms
	tecpro_count = transforms.size()
	tecpro_instance = _add_multimesh("Tecpro", _tecpro_mesh(), transforms)


## Turn 1 (the first corner), the hairpin (tightest) and both halves of every chicane.
func _critical_corners(kerbs: Array[Dictionary]) -> Array[int]:
	var corners: Array[int] = []
	if kerbs.is_empty():
		return corners
	corners.append(0)
	var hairpin: int = 0
	var tightest: float = 0.0
	for corner: int in range(kerbs.size()):
		var kappa: float = absf(line.curvature_at(_apex(kerbs[corner])))
		if kappa > tightest:
			tightest = kappa
			hairpin = corner
	if not corners.has(hairpin):
		corners.append(hairpin)
	for corner: int in range(kerbs.size() - 1):
		var gap: float = float(kerbs[corner + 1]["s0"]) - float(kerbs[corner]["s1"])
		if gap < CHICANE_GAP_M and float(kerbs[corner]["side"]) != float(kerbs[corner + 1]["side"]):
			for member: int in [corner, corner + 1]:
				if not corners.has(member):
					corners.append(member)
	return corners


## Two 1 m polyethylene blocks (red, dark grey) bound with straps; the face looks toward -x.
func _tecpro_mesh() -> ArrayMesh:
	var batch := MeshBatchScript.new()
	var material: ShaderMaterial = ToonMaterials.vertex_colored()
	var block: float = TECPRO_STEP_M * 0.5
	for index: int in range(2):
		var z: float = (float(index) - 0.5) * block
		batch.box(material, TECPRO_RED if index == 0 else TECPRO_GREY, Transform3D(Basis.IDENTITY, Vector3(-TECPRO_DEPTH_M * 0.5, TECPRO_HEIGHT_M * 0.5, z)), Vector3(TECPRO_DEPTH_M, TECPRO_HEIGHT_M, block - 0.04))
		for strap: float in [-0.28, 0.28]:
			batch.box(material, TECPRO_STRAP, Transform3D(Basis.IDENTITY, Vector3(-TECPRO_DEPTH_M * 0.5, TECPRO_HEIGHT_M * 0.5, z + strap)), Vector3(TECPRO_DEPTH_M + 0.03, TECPRO_HEIGHT_M + 0.03, 0.05))
	return batch.commit()


# --- braking markers -------------------------------------------------------------------

func _build_markers(kerbs: Array[Dictionary]) -> void:
	var poses: Array[Transform3D] = []
	var meters: Array[int] = []
	for corner: int in range(kerbs.size()):
		var apex: float = _apex(kerbs[corner])
		var side: float = kerbs[corner]["side"]
		for distance: int in MARKER_DISTANCES_M:
			var s: float = apex - float(distance)
			poses.append(ribbon.get_point_at_offset(s, side * (ribbon.road_half_width_m + MARKER_OFFSET_M)))
			meters.append(distance)
			marker_records.append({"corner": corner, "meters": distance, "s": fposmod(s, ribbon.length_m), "side": side})
	marker_transforms = poses
	var multimesh := _multimesh(_marker_mesh(), poses, true)
	for index: int in range(poses.size()):
		multimesh.set_instance_custom_data(index, Color(float(meters[index]), 0.0, 0.0, 0.0))
	marker_instance = _wrap("BrakingMarkers", multimesh)


## Post, dark board backing and hazard stripes on the cel surface; the distance face on its own shader.
func _marker_mesh() -> ArrayMesh:
	var batch := MeshBatchScript.new()
	var material: ShaderMaterial = ToonMaterials.vertex_colored()
	var centre_y: float = MARKER_BOARD_BASE_M + MARKER_BOARD_H_M * 0.5
	batch.box(material, POST_COLOR, Transform3D(Basis.IDENTITY, Vector3(0.0, centre_y * 0.5, -0.03)), Vector3(0.08, centre_y, 0.06))
	batch.box(material, HAZARD_BLACK, Transform3D(Basis.IDENTITY, Vector3(0.0, centre_y, 0.0)), Vector3(MARKER_BOARD_W_M + 0.1, MARKER_BOARD_H_M + 0.1, 0.05))
	var stripes: int = 8
	var stripe_w: float = (MARKER_BOARD_W_M + 0.1) / float(stripes)
	for index: int in range(stripes):
		var x: float = -MARKER_BOARD_W_M * 0.5 - 0.05 + stripe_w * (float(index) + 0.5)
		batch.box(material, HAZARD_YELLOW if index % 2 == 0 else HAZARD_BLACK, Transform3D(Basis.IDENTITY, Vector3(x, MARKER_BOARD_BASE_M - 0.17, 0.0)), Vector3(stripe_w, 0.22, 0.055))
	var mesh: ArrayMesh = batch.commit()
	var face := SurfaceTool.new()
	face.begin(Mesh.PRIMITIVE_TRIANGLES)
	face.set_normal(Vector3.BACK)
	var half_w: float = MARKER_BOARD_W_M * 0.5
	var half_h: float = MARKER_BOARD_H_M * 0.5
	var corners: Array[Array] = [
		[Vector3(-half_w, centre_y + half_h, 0.03), Vector2(0.0, 0.0)], [Vector3(half_w, centre_y + half_h, 0.03), Vector2(1.0, 0.0)],
		[Vector3(half_w, centre_y - half_h, 0.03), Vector2(1.0, 1.0)], [Vector3(-half_w, centre_y - half_h, 0.03), Vector2(0.0, 1.0)],
	]
	for slot: int in [0, 1, 2, 0, 2, 3]:
		face.set_uv(corners[slot][1])
		face.add_vertex(corners[slot][0])
	face.commit(mesh)
	marker_face_material = ShaderMaterial.new()
	marker_face_material.shader = MarkerShader
	mesh.surface_set_material(mesh.get_surface_count() - 1, marker_face_material)
	return mesh


# --- floodlight towers -----------------------------------------------------------------

func _build_towers() -> void:
	var transforms: Array[Transform3D] = []
	var spacing: float = ribbon.length_m / float(TOWER_COUNT)
	for index: int in range(TOWER_COUNT):
		var side: float = -1.0 if index % 2 == 0 else 1.0
		var base_s: float = spacing * (float(index) + 0.5)
		# Slide along the lap until the tower is clear of its neighbours (two stretches of road can run close together).
		var site: Dictionary = _tower_site(side, base_s)
		for shift: float in TOWER_SHIFTS_M:
			var candidate: Dictionary = _tower_site(side, base_s + shift)
			if _clear_of_towers(candidate["position"]) and _road_distance(candidate["position"]) >= TOWER_MIN_ROAD_M:
				site = candidate
				break
		transforms.append(site["pose"])
		tower_records.append(site)
	tower_transforms = transforms
	tower_count = transforms.size()
	tower_instance = _add_multimesh("FloodlightTowers", _tower_mesh(), transforms)


## {s, side, lateral, position, pose} of a tower at arc distance s behind the rail (and behind any landmark zone).
func _tower_site(side: float, s: float) -> Dictionary:
	var lateral: float = ribbon.road_half_width_m + extent_at(side, s) + TOWER_BEHIND_M
	for zone: Dictionary in _hero_zones:
		if float(zone["side"]) == side and fposmod(s - float(zone["s0"]), ribbon.length_m) <= float(zone["s1"]) - float(zone["s0"]):
			lateral = maxf(lateral, float(zone["lateral"]))
	var pose: Transform3D = ribbon.get_point_at_offset(s, side * lateral)
	# The lamp heads look along local +Z; turn it toward the track.
	pose.basis = pose.basis.rotated(pose.basis.y, -side * PI * 0.5)
	return {"s": fposmod(s, ribbon.length_m), "side": side, "lateral": lateral, "position": pose.origin, "pose": pose}


## Planar distance from `position` to the closest centreline sample.
func _road_distance(position: Vector3) -> float:
	var best: float = INF
	var cx: int = floori(position.x / SurfaceGeometry.CLEARANCE_CELL_M)
	var cz: int = floori(position.z / SurfaceGeometry.CLEARANCE_CELL_M)
	for dx: int in range(-1, 2):
		for dz: int in range(-1, 2):
			var key := Vector2i(cx + dx, cz + dz)
			if _centre_samples.has(key):
				for sample: Vector3 in _centre_samples[key]:
					best = minf(best, Vector2(sample.x - position.x, sample.z - position.z).length())
	return best


func _clear_of_towers(position: Vector3) -> bool:
	for record: Dictionary in tower_records:
		if (record["position"] as Vector3).distance_to(position) < TOWER_MIN_SPACING_M:
			return false
	return true


## 18 m lattice mast: four tapered legs, ring and diagonal bracing every 3 m, a platform and a
## head frame with eight glow-masked LED panels tilted down toward the track.
func _tower_mesh() -> ArrayMesh:
	var batch := MeshBatchScript.new()
	var material: ShaderMaterial = ToonMaterials.vertex_colored()
	var corners: Array[Vector2] = [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]
	for corner: Vector2 in corners:
		batch.strut(material, STEEL_COLOR, _leg_point(corner, 0.0), _leg_point(corner, TOWER_MAST_M), 0.14)
	var levels: int = roundi(TOWER_MAST_M / TOWER_BRACE_STEP_M)
	for level: int in range(1, levels + 1):
		var h0: float = TOWER_MAST_M * float(level - 1) / float(levels)
		var h1: float = TOWER_MAST_M * float(level) / float(levels)
		for index: int in range(4):
			var a: Vector2 = corners[index]
			var b: Vector2 = corners[(index + 1) % 4]
			batch.strut(material, DARK_STEEL_COLOR, _leg_point(a, h1), _leg_point(b, h1), 0.07)
			batch.strut(material, DARK_STEEL_COLOR, _leg_point(a, h0), _leg_point(b, h1), 0.05)
			batch.strut(material, DARK_STEEL_COLOR, _leg_point(b, h0), _leg_point(a, h1), 0.05)
	batch.box(material, DARK_STEEL_COLOR, Transform3D(Basis.IDENTITY, Vector3(0.0, TOWER_MAST_M, 0.0)), Vector3(TOWER_TOP_HALF_M * 2.0 + 1.8, 0.14, TOWER_TOP_HALF_M * 2.0 + 1.8))
	var head_y: float = TOWER_MAST_M + 0.65
	batch.box(material, STEEL_COLOR, Transform3D(Basis.IDENTITY, Vector3(0.0, head_y, 0.0)), Vector3(5.6, 0.26, 0.26))
	var panel_w: float = 1.25
	var panel_h: float = 0.52
	for row: int in range(LAMP_ROWS):
		for column: int in range(LAMP_COLUMNS):
			var x: float = (float(column) - (LAMP_COLUMNS - 1) * 0.5) * (panel_w + 0.08)
			var y: float = head_y + 0.28 + panel_h * 0.5 + float(row) * (panel_h + 0.06)
			var tilt := Basis(Vector3.RIGHT, LAMP_TILT)
			batch.box(material, DARK_STEEL_COLOR, Transform3D(tilt, Vector3(x, y, 0.12)), Vector3(panel_w + 0.06, panel_h + 0.06, 0.16))
			batch.box(material, LAMP_COLOR, Transform3D(tilt, Vector3(x, y - 0.02, 0.22)), Vector3(panel_w, panel_h, 0.05))
	return batch.commit()


func _leg_point(corner: Vector2, height: float) -> Vector3:
	var half: float = lerpf(TOWER_BASE_HALF_M, TOWER_TOP_HALF_M, height / TOWER_MAST_M)
	return Vector3(corner.x * half, height, corner.y * half)


# --- shared ----------------------------------------------------------------------------

## Arc distance of the tightest point of a kerb run: where the braking boards count down to.
func _apex(kerb: Dictionary) -> float:
	var best: float = float(kerb["s0"])
	var peak: float = 0.0
	var s: float = float(kerb["s0"])
	while s <= float(kerb["s1"]):
		var kappa: float = absf(line.curvature_at(s))
		if kappa > peak:
			peak = kappa
			best = s
		s += 2.0
	return best


func _multimesh(mesh: Mesh, transforms: Array[Transform3D], custom_data: bool = false) -> MultiMesh:
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_custom_data = custom_data # must be set while the instance count is still 0
	multimesh.mesh = mesh
	multimesh.instance_count = transforms.size()
	for index: int in range(transforms.size()):
		multimesh.set_instance_transform(index, transforms[index])
	return multimesh


func _wrap(node_name: String, multimesh: MultiMesh) -> MultiMeshInstance3D:
	var instance := MultiMeshInstance3D.new()
	instance.name = node_name
	instance.multimesh = multimesh
	add_child(instance)
	return instance


func _add_multimesh(node_name: String, mesh: Mesh, transforms: Array[Transform3D]) -> MultiMeshInstance3D:
	return _wrap(node_name, _multimesh(mesh, transforms))
