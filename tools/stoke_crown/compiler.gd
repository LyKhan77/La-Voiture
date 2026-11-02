extends RefCounted

## Turns a blueprint's alignment and elevation into the sampled centerline the
## viewport, pit engine and exporter use. Mirrors TrackRibbon's sampling: one
## point per metre, curvature over a 6 m window.

const Alignment := preload("res://tools/stoke_crown/alignment.gd")
const ElevationProfile := preload("res://tools/stoke_crown/elevation.gd")

const SAMPLE_STEP_M := 1.0
const CURVATURE_HALF_WINDOW_M := 6.0
const STRAIGHT_RADIUS_M := 10000.0
const MIN_RADIUS_EPSILON := 0.0001


static func compile(blueprint: Dictionary) -> Dictionary:
	var alignment_data: Dictionary = blueprint.get("alignment", {})
	var vertices: Array = alignment_data.get("vertices", [])
	var radii: Array = alignment_data.get("radii", [])
	var start: Array = alignment_data.get("start", [0.0, 0.0])
	var target: float = float(alignment_data.get("length_target_m", 0.0))
	if vertices.size() < 3 or radii.size() != vertices.size() or target <= 0.0:
		return {"ok": false, "error": "alignment needs >= 3 vertices, matching radii, and a positive length target"}
	var plan: Dictionary = Alignment.build(vertices, radii, start)
	var plan_length: float = float(plan["plan_length"])
	if plan_length <= 0.0:
		return {"ok": false, "error": "alignment plan length is zero"}
	var scale: float = target / plan_length
	var count: int = maxi(8, roundi(target / SAMPLE_STEP_M))
	var step: float = target / float(count)
	var points := PackedVector3Array()
	points.resize(count)
	var elevation_data: Dictionary = blueprint.get("elevation", {})
	var samples: Array = elevation_data.get("samples", [])
	for index: int in range(count):
		var s: float = float(index) * step
		var flat: Vector2 = Alignment.position_at(plan, s / scale)
		var height: float = ElevationProfile.height_at(samples, target, s)
		points[index] = Vector3(flat.x * scale, height, flat.y * scale)
	var curvature := _curvature(points, step)
	var min_sampled_radius: float = STRAIGHT_RADIUS_M
	for value: float in curvature:
		var magnitude: float = absf(value)
		if magnitude > MIN_RADIUS_EPSILON:
			min_sampled_radius = minf(min_sampled_radius, 1.0 / magnitude)
	var elevation_min: float = INF
	var elevation_max: float = -INF
	for point: Vector3 in points:
		elevation_min = minf(elevation_min, point.y)
		elevation_max = maxf(elevation_max, point.y)
	return {
		"ok": true,
		"points": points,
		"count": count,
		"step_m": step,
		"length_m": target,
		"curvature": curvature,
		"min_radius_m": float(plan["min_radius"]) * scale,
		"min_sampled_radius_m": min_sampled_radius,
		"elevation_min_m": elevation_min,
		"elevation_max_m": elevation_max,
		"elevation_delta_m": elevation_max - elevation_min,
		"winding": "clockwise" if _signed_area(points) > 0.0 else "counter_clockwise",
		"signed_area_m2": _signed_area(points),
		"turns_total_deg": _turning_degrees(points),
		"closure_error_m": Alignment.end_point(plan).distance_to(plan["start"]) * scale,
		"scale": scale,
		"plan_length_m": plan_length,
		"fillet_clamps": int(plan.get("clamped", 0)),
		"sectors": _sectors(target),
	}


## Signed area in the x/z plane. The radar maps x right and z down, so a positive
## area is clockwise on screen — the convention the studio uses for `winding`.
static func _signed_area(points: PackedVector3Array) -> float:
	var area: float = 0.0
	var count: int = points.size()
	for index: int in range(count):
		var a: Vector3 = points[index]
		var b: Vector3 = points[(index + 1) % count]
		area += a.x * b.z - b.x * a.z
	return area * 0.5


static func _turning_degrees(points: PackedVector3Array) -> float:
	var total: float = 0.0
	var count: int = points.size()
	for index: int in range(count):
		var previous_point: Vector3 = points[posmod(index - 1, count)]
		var current_point: Vector3 = points[index]
		var next_point: Vector3 = points[posmod(index + 1, count)]
		var incoming := Vector3(current_point.x - previous_point.x, 0.0, current_point.z - previous_point.z)
		var outgoing := Vector3(next_point.x - current_point.x, 0.0, next_point.z - current_point.z)
		if incoming.length() < 1.0e-9 or outgoing.length() < 1.0e-9:
			continue
		incoming = incoming.normalized()
		outgoing = outgoing.normalized()
		total += atan2(incoming.x * outgoing.z - incoming.z * outgoing.x, incoming.x * outgoing.x + incoming.z * outgoing.z)
	return rad_to_deg(total)


static func _curvature(points: PackedVector3Array, step: float) -> PackedFloat32Array:
	var count: int = points.size()
	var forward := PackedVector3Array()
	forward.resize(count)
	for index: int in range(count):
		var next: Vector3 = points[posmod(index + 1, count)]
		var previous: Vector3 = points[posmod(index - 1, count)]
		forward[index] = (next - previous).normalized()
	var window: int = maxi(1, roundi(CURVATURE_HALF_WINDOW_M / step))
	var arc: float = 2.0 * float(window) * step
	var curvature := PackedFloat32Array()
	curvature.resize(count)
	for index: int in range(count):
		var a: Vector3 = _flat(forward[posmod(index - window, count)])
		var b: Vector3 = _flat(forward[posmod(index + window, count)])
		curvature[index] = atan2(a.cross(b).y, a.dot(b)) / arc
	return curvature


static func _flat(value: Vector3) -> Vector3:
	var flat := Vector3(value.x, 0.0, value.z)
	return flat.normalized()


static func _sectors(length: float) -> Array:
	var out: Array = []
	for index: int in range(3):
		out.append({
			"sector": index + 1,
			"start_s": length * float(index) / 3.0,
			"end_s": length * float(index + 1) / 3.0,
		})
	return out
