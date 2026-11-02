extends RefCounted

## Builds the closed alignment the same way La_Voiture's circuit builders do:
## a start point on the loop, polygon vertices with a fillet radius each, straights
## between fillet exits and entries, and a closing straight back to the start.
## Nothing here is scaled; `compiler.gd` scales the plan to the homologated length.

const EPSILON := 1.0e-9
## The builders keep a fillet tangent inside 48% of each adjacent edge.
const TANGENT_CLAMP := 0.48


static func build(vertices: Array, radii: Array, start: Array) -> Dictionary:
	var start_point: Vector2 = _vec(start)
	var segments: Array = []
	var previous_exit: Vector2 = start_point
	var previous: Vector2 = start_point
	var plan_length: float = 0.0
	var min_radius: float = INF
	var clamped := 0
	var count: int = vertices.size()
	for index: int in range(count):
		var vertex: Vector2 = _vec(vertices[index])
		var next: Vector2 = _vec(vertices[(index + 1) % count])
		var in_dir: Vector2 = (vertex - previous).normalized()
		var out_dir: Vector2 = (next - vertex).normalized()
		var in_length: float = vertex.distance_to(previous)
		var out_length: float = next.distance_to(vertex)
		var angle: float = atan2(in_dir.cross(out_dir), in_dir.dot(out_dir))
		var radius: float = float(radii[index])
		var tan_half: float = tan(absf(angle) * 0.5)
		var tangent: float = radius * tan_half
		var max_tangent: float = minf(in_length, out_length) * TANGENT_CLAMP
		if tangent > max_tangent and tan_half > EPSILON:
			radius = max_tangent / tan_half
			tangent = max_tangent
			clamped += 1
		var entry: Vector2 = vertex - in_dir * tangent
		var exit_point: Vector2 = vertex + out_dir * tangent
		var straight_length: float = previous_exit.distance_to(entry)
		if straight_length > EPSILON:
			segments.append({
				"kind": "straight",
				"from": previous_exit,
				"to": entry,
				"length": straight_length,
				"s0": plan_length,
			})
			plan_length += straight_length
		var arc_length: float = absf(angle) * radius
		if arc_length > EPSILON:
			var turn_sign: float = 1.0 if angle > 0.0 else -1.0
			var perpendicular := Vector2(-in_dir.y * turn_sign, in_dir.x * turn_sign)
			segments.append({
				"kind": "arc",
				"centre": entry + perpendicular * radius,
				"entry": entry,
				"angle": angle,
				"radius": radius,
				"length": arc_length,
				"s0": plan_length,
			})
			plan_length += arc_length
			min_radius = minf(min_radius, radius)
		previous_exit = exit_point
		previous = vertex
	var closing: float = previous_exit.distance_to(start_point)
	if closing > EPSILON:
		segments.append({
			"kind": "straight",
			"from": previous_exit,
			"to": start_point,
			"length": closing,
			"s0": plan_length,
		})
		plan_length += closing
	return {
		"segments": segments,
		"plan_length": plan_length,
		"min_radius": min_radius if min_radius < INF else 0.0,
		"clamped": clamped,
		"start": start_point,
	}


## Position on the unscaled plan at an arc distance.
static func position_at(alignment: Dictionary, distance: float) -> Vector2:
	var segments: Array = alignment["segments"]
	if segments.is_empty():
		return alignment["start"]
	var plan_length: float = float(alignment["plan_length"])
	var s: float = fposmod(distance, maxf(plan_length, EPSILON))
	for segment: Dictionary in segments:
		var s0: float = float(segment["s0"])
		var length: float = float(segment["length"])
		if s <= s0 + length + EPSILON:
			var t: float = clampf((s - s0) / maxf(length, EPSILON), 0.0, 1.0)
			if String(segment["kind"]) == "straight":
				var from_point: Vector2 = segment["from"]
				var to_point: Vector2 = segment["to"]
				return from_point.lerp(to_point, t)
			var centre: Vector2 = segment["centre"]
			var entry: Vector2 = segment["entry"]
			return centre + (entry - centre).rotated(float(segment["angle"]) * t)
	return alignment["start"]


## End point of the last segment, used to prove the loop closes.
static func end_point(alignment: Dictionary) -> Vector2:
	var segments: Array = alignment["segments"]
	if segments.is_empty():
		return alignment["start"]
	var last: Dictionary = segments[segments.size() - 1]
	if String(last["kind"]) == "straight":
		return last["to"]
	var centre: Vector2 = last["centre"]
	var entry: Vector2 = last["entry"]
	return centre + (entry - centre).rotated(float(last["angle"]))


static func _vec(value: Variant) -> Vector2:
	if value is Vector2:
		return value
	var pair: Array = value
	return Vector2(float(pair[0]), float(pair[1]))
