class_name TrackRibbon
extends Path3D

## Three parallel lane corridors over a closed Path3D (PRD 01, SIM-01).
## Lane 0 = left of travel (inside for a counter-clockwise circuit), lane 1 =
## racing line (the path itself), lane 2 = right of travel. Positions come from
## a table sampled once at SAMPLE_STEP_M, so every query is O(1) and cheap
## enough for 20 cars at 16x. The curve must be closed by repeating its first
## point as its last point.

const LANE_COUNT: int = 3
const LANE_SPACING_M: float = 2.5
const SAMPLE_STEP_M: float = 1.0
const CURVATURE_HALF_WINDOW_M: float = 6.0
const MESH_STEP_M: float = 3.0
const STRAIGHT_RADIUS_M: float = 10000.0

const ASPHALT_COLOR := Color("#2A2C33")
const EDGE_LINE_COLOR := Color("#F4F5F7")
const START_LINE_COLOR := Color("#F4F5F7")

@export var road_half_width_m: float = 6.0

var length_m: float = 0.0

var _step_m: float = 1.0
var _count: int = 0
var _pos: PackedVector3Array = PackedVector3Array()
var _fwd: PackedVector3Array = PackedVector3Array()
var _curvature: PackedFloat32Array = PackedFloat32Array()


func _ready() -> void:
	rebuild()
	_build_road_mesh()


## Re-bakes the sample table after the curve changes.
func rebuild() -> void:
	curve.bake_interval = SAMPLE_STEP_M
	length_m = curve.get_baked_length()
	_count = maxi(8, roundi(length_m / SAMPLE_STEP_M))
	_step_m = length_m / float(_count)
	_pos.resize(_count)
	_fwd.resize(_count)
	_curvature.resize(_count)
	for i: int in range(_count):
		_pos[i] = curve.sample_baked(float(i) * _step_m, true)
	for i: int in range(_count):
		_fwd[i] = (_pos[posmod(i + 1, _count)] - _pos[posmod(i - 1, _count)]).normalized()
	var k: int = maxi(1, roundi(CURVATURE_HALF_WINDOW_M / _step_m))
	var arc: float = 2.0 * float(k) * _step_m
	for i: int in range(_count):
		var a: Vector3 = _flat(_fwd[posmod(i - k, _count)])
		var b: Vector3 = _flat(_fwd[posmod(i + k, _count)])
		# Positive = left turn (counter-clockwise seen from above).
		_curvature[i] = atan2(a.cross(b).y, a.dot(b)) / arc


## World transform on a lane. Basis follows Godot's convention: -Z is the
## direction of travel, +X is right of travel.
func get_point_on_ribbon(distance: float, lane: int) -> Transform3D:
	return get_point_at_offset(distance, float(clampi(lane, 0, LANE_COUNT - 1) - 1) * LANE_SPACING_M)


## Same as get_point_on_ribbon() for any lateral offset in meters (+ = right of
## travel), so a car can glide between lanes.
func get_point_at_offset(distance: float, lateral_m: float) -> Transform3D:
	var u: float = fposmod(distance, length_m) / _step_m
	var i: int = int(u)
	var f: float = u - float(i)
	i = posmod(i, _count)
	var j: int = posmod(i + 1, _count)
	var fwd: Vector3 = _fwd[i].lerp(_fwd[j], f).normalized()
	var right: Vector3 = fwd.cross(Vector3.UP).normalized()
	var up: Vector3 = right.cross(fwd)
	var origin: Vector3 = _pos[i].lerp(_pos[j], f) + right * lateral_m
	return global_transform * Transform3D(Basis(right, up, -fwd), origin)


## Signed curvature in 1/m: > 0 left turn, < 0 right turn, 0 straight.
func get_curvature_at(distance: float) -> float:
	var u: float = fposmod(distance, length_m) / _step_m
	var i: int = posmod(int(u), _count)
	return lerpf(_curvature[i], _curvature[posmod(i + 1, _count)], u - floorf(u))


## Corner radius in meters, STRAIGHT_RADIUS_M on straights.
func get_radius_at(distance: float) -> float:
	var k: float = absf(get_curvature_at(distance))
	return minf(1.0 / maxf(k, 1.0 / STRAIGHT_RADIUS_M), STRAIGHT_RADIUS_M)


func _flat(v: Vector3) -> Vector3:
	return Vector3(v.x, 0.0, v.z).normalized()


func _build_road_mesh() -> void:
	var road: MeshInstance3D = get_node_or_null("RoadMesh")
	if road == null:
		road = MeshInstance3D.new()
		road.name = "RoadMesh"
		add_child(road)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var stride: int = maxi(1, roundi(MESH_STEP_M / _step_m))
	_strip(st, -road_half_width_m, road_half_width_m, 0.0, ASPHALT_COLOR, 0, _count, stride)
	var edge: float = road_half_width_m - 0.3
	for side: float in [-1.0, 1.0]:
		# Only the white edge lines: a GT circuit is one open surface, the three lanes below are sim corridors, not paint.
		_strip(st, side * edge - 0.1, side * edge + 0.1, 0.02, EDGE_LINE_COLOR, 0, _count, stride)
	_strip(st, -road_half_width_m, road_half_width_m, 0.03, START_LINE_COLOR, -1, 1, 1)
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.roughness = 0.9
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	var mesh: ArrayMesh = st.commit()
	mesh.surface_set_material(0, material)
	road.mesh = mesh


## Appends a flat band between two lateral offsets over table indices i0..i1.
func _strip(
	st: SurfaceTool, lat_a: float, lat_b: float, dy: float, color: Color,
	i0: int, i1: int, stride: int
) -> void:
	var indices: Array[int] = []
	for i: int in range(i0, i1, stride):
		indices.append(i)
	indices.append(i1)
	st.set_color(color)
	st.set_normal(Vector3.UP)
	for n: int in range(indices.size() - 1):
		var ia: int = posmod(indices[n], _count)
		var ib: int = posmod(indices[n + 1], _count)
		var left_a: Vector3 = _edge(ia, lat_a, dy)
		var right_a: Vector3 = _edge(ia, lat_b, dy)
		var left_b: Vector3 = _edge(ib, lat_a, dy)
		var right_b: Vector3 = _edge(ib, lat_b, dy)
		for v: Vector3 in [left_a, left_b, right_b, left_a, right_b, right_a]:
			st.add_vertex(v)


func _edge(i: int, lateral_m: float, dy: float) -> Vector3:
	var right: Vector3 = _fwd[i].cross(Vector3.UP).normalized()
	return _pos[i] + right * lateral_m + Vector3.UP * dy
