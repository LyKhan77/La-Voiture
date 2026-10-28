class_name BrianzaCircuitBuilder
extends Node3D

## Autodromo di Brianza (Monza GP), Round 03 of the championship calendar (FASE 13): a 5 790 m
## permanent Grand Prix circuit laid out as the legendary "Temple of Speed" — the 1.1 km Main Straight,
## Variante del Rettifilo, Curva Grande through the royal park, Variante della Roggia, the dual Lesmos,
## the Serraglio straight descending beneath the historic Sopraelevata banked oval ruin, the high-speed
## Variante Ascari, Rettifilo Posteriore, and the sweeping Curva Parabolica (Alboreto).
##
## The centreline is designed as a closed tangential civil-engineering alignment (tangent straights +
## circular curve fillet arcs with radii from 31.7 m up to 474.8 m, ensuring high-speed GT3 stability),
## scaled to the homologated 5 790.0 m length with 0.01 m precision.
##
## The elevation profile spans an official 12.0 m delta: baseline 0.0 m on the main straight, climbing
## to +4.8 m at Lesmo 1, diving into the royal park depression at -7.2 m under the monumental Sopraelevata
## concrete viaduct overpass, and climbing back through Ascari to 0.0 m at the Parabolica.

const RibbonScript := preload("res://scripts/car/track_ribbon.gd")
const RoadShader := preload("res://shaders/road_asphalt.gdshader")

const LENGTH_M: float = 5790.0
const ROAD_WIDTH_M: float = 14.0
const ROAD_HALF_WIDTH_M: float = ROAD_WIDTH_M * 0.5

## Centerline polygon vertices (x, z) in metres, walked clockwise from START (0, 0).
const VERTICES: Array[Vector2] = [
	Vector2(0.00, 672.63),     # 0: End of Main Straight -> Turn 1 entry
	Vector2(54.40, 741.87),    # 1: Rettifilo chicane mid-kink (right, then left)
	Vector2(19.78, 821.00),    # 2: Rettifilo exit link
	Vector2(217.62, 1365.04),  # 3: Curva Grande entry/apex
	Vector2(771.55, 1562.87),  # 4: End of Curva Grande -> Roggia straight
	Vector2(1038.62, 1661.79), # 5: Roggia entry (turn left)
	Vector2(1097.97, 1632.11), # 6: Roggia mid (turn right)
	Vector2(1266.13, 1483.74), # 7: Lesmo 1 entry (turn right)
	Vector2(1280.96, 1246.34), # 8: Between Lesmos
	Vector2(1256.23, 1127.64), # 9: Lesmo 2 entry (turn right)
	Vector2(870.46, 672.63),   # 10: Serraglio kink (gentle left under Sopraelevata)
	Vector2(474.80, 257.18),   # 11: Ascari entry (turn left)
	Vector2(415.45, 178.05),   # 12: Ascari mid (turn right)
	Vector2(306.64, 69.24),    # 13: Ascari exit (turn left onto Back Straight)
	Vector2(-138.48, -455.01), # 14: End of Back Straight -> Parabolica entry
	Vector2(-276.96, -553.93), # 15: Parabolica apex 1 (tight entry)
	Vector2(-257.18, -356.10), # 16: Parabolica apex 2 (wide opening exit)
	Vector2(-39.57, -257.18),  # 17: Parabolica blend onto Main Straight
]

## Fillet radius of each vertex (metres), producing smooth circular curve transitions.
const RADII: Array[float] = [
	31.65,  # 0: T1 Rettifilo in (R)
	31.65,  # 1: T2 Rettifilo out (L)
	49.46,  # 2: Rettifilo exit link
	316.53, # 3: T3 Curva Grande (R)
	118.70, # 4: Curva Grande exit
	41.54,  # 5: T4 Roggia in (L)
	41.54,  # 6: T5 Roggia out (R)
	67.26,  # 7: T6 Lesmo 1 (R)
	54.40,  # 8: Lesmo link
	61.33,  # 9: T7 Lesmo 2 (R)
	474.80, # 10: Serraglio kink (L)
	51.44,  # 11: T8 Ascari in (L)
	57.37,  # 12: T9 Ascari mid (R)
	64.30,  # 13: T10 Ascari out (L)
	84.08,  # 14: Parabolica approach
	93.97,  # 15: T11a Parabolica entry (R)
	217.62, # 16: T11b Parabolica exit (R)
	79.13,  # 17: Main straight blend
]

## The start/finish line sits on the bottom straight, 672 m before Turn 1 (ample room for GP pit complex).
const START := Vector2(0.0, 0.0)

## The 11 official numbered turns of Autodromo Nazionale Monza.
const TURN_SPECS: Array[Dictionary] = [
	{"vertices": [0, 1], "name": "Variante del Rettifilo"},
	{"vertices": [3], "name": "Curva Biassono (Curva Grande)"},
	{"vertices": [5, 6], "name": "Variante della Roggia"},
	{"vertices": [7], "name": "Curva di Lesmo 1"},
	{"vertices": [9], "name": "Curva di Lesmo 2"},
	{"vertices": [10], "name": "Curva del Serraglio"},
	{"vertices": [11, 12, 13], "name": "Variante Ascari"},
	{"vertices": [15, 16], "name": "Curva Parabolica (Alboreto)"},
]

## Elevation profile: delta 12.0 m (Peak +4.8 m at Lesmo 1, lowest -7.2 m under Sopraelevata).
const ELEVATION: Array[Vector2] = [
	Vector2(0.0, 0.0),
	Vector2(600.0, 0.6),
	Vector2(900.0, 1.4),
	Vector2(1400.0, 2.5),
	Vector2(2000.0, 3.8),
	Vector2(2560.0, 4.8),  # Peak: Lesmo 1 (+4.8 m)
	Vector2(2900.0, 3.2),
	Vector2(3200.0, -2.5),
	Vector2(3500.0, -7.2), # Lowest: Serraglio under Sopraelevata (-7.2 m)
	Vector2(3800.0, -4.5),
	Vector2(4200.0, -2.0),
	Vector2(4700.0, -0.8),
	Vector2(5200.0, 0.0),
	Vector2(LENGTH_M, 0.0),
]

const STRAIGHT_STEP_M: float = 6.0
const ARC_STEP_RAD: float = 0.07 # ~4 degrees

var ribbon: RibbonScript
var turns: Array[Dictionary] = []
var curve_length_m: float = 0.0
var sectors: Array[Dictionary] = []
var min_turn_radius_m: float = 0.0
var max_elevation_m: float = 0.0
var min_elevation_m: float = 0.0
var plan_scale: float = 1.0

var _points: Array[Vector3] = []
var _arcs: Array[float] = []
var _plan_length: float = 1.0
var _apexes: Dictionary = {}
var _bounds: Dictionary = {}


func _enter_tree() -> void:
	_build_curve()


func _ready() -> void:
	var pit: Node = get_node_or_null("PitLane")
	if pit != null and pit.has_method("build"):
		pit.call("build", ribbon)
	var env: Node = get_node_or_null("Environment")
	if env != null and env.has_method("build"):
		env.call("build", ribbon, self)


func ribbon_node() -> RibbonScript:
	return ribbon


## Height of the road at an arc distance, smoothstep between authored keys.
static func elevation_at(s: float) -> float:
	var x: float = fposmod(s, LENGTH_M)
	for index: int in range(ELEVATION.size() - 1):
		var a: Vector2 = ELEVATION[index]
		var b: Vector2 = ELEVATION[index + 1]
		if x >= a.x and x <= b.x:
			var t: float = inverse_lerp(a.x, b.x, x)
			return lerpf(a.y, b.y, t * t * (3.0 - 2.0 * t))
	return 0.0


static func asphalt_material() -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = RoadShader
	return mat


func _build_curve() -> void:
	ribbon = get_node_or_null("TrackRibbon") as RibbonScript
	if ribbon == null:
		push_error("BrianzaCircuitBuilder: scene has no TrackRibbon child")
		return
	_walk_plan()
	plan_scale = LENGTH_M / maxf(_plan_length, 1.0)
	
	var curve := Curve3D.new()
	curve.bake_interval = 1.0
	for index: int in range(_points.size()):
		var p: Vector3 = _points[index]
		var s: float = _arcs[index] * plan_scale
		curve.add_point(Vector3(p.x * plan_scale, elevation_at(s), p.z * plan_scale))
	# Close loop on origin point
	curve.add_point(curve.get_point_position(0))
	
	ribbon.curve = curve
	ribbon.road_half_width_m = ROAD_HALF_WIDTH_M
	ribbon.road_material = asphalt_material()
	curve_length_m = curve.get_baked_length()
	
	_build_turns()
	sectors.clear()
	for s_idx: int in range(3):
		sectors.append({
			"sector": s_idx + 1,
			"start_s": LENGTH_M * float(s_idx) / 3.0,
			"end_s": LENGTH_M * float(s_idx + 1) / 3.0,
		})
	max_elevation_m = -INF
	min_elevation_m = INF
	for index: int in range(_points.size()):
		var y: float = elevation_at(_arcs[index] * plan_scale)
		max_elevation_m = maxf(max_elevation_m, y)
		min_elevation_m = minf(min_elevation_m, y)


func _build_turns() -> void:
	turns.clear()
	min_turn_radius_m = INF
	for spec: Dictionary in TURN_SPECS:
		var v_indices: Array = spec["vertices"]
		var first_idx: int = int(v_indices[0])
		var last_idx: int = int(v_indices[v_indices.size() - 1])
		var radius: float = INF
		var apex_s: Array[float] = []
		for vertex: int in v_indices:
			radius = minf(radius, float(_apexes[vertex]["radius"]))
			apex_s.append(float(_apexes[vertex]["s"]) * plan_scale)
		var enter_s: float = float(_bounds[first_idx]["enter_s"])
		var exit_s: float = float(_bounds[last_idx]["exit_s"])
		turns.append({
			"number": turns.size() + 1,
			"name": String(spec["name"]),
			"s": (enter_s + exit_s) * 0.5 * plan_scale,
			"apex_s": apex_s,
			"direction": int(signf(float(_apexes[first_idx]["direction"]))),
			"radius_m": radius * plan_scale,
			"vertices": v_indices,
			"span_m": (exit_s - enter_s) * plan_scale,
		})
		min_turn_radius_m = minf(min_turn_radius_m, radius * plan_scale)


func _walk_plan() -> void:
	_points.clear()
	_arcs.clear()
	_apexes.clear()
	_bounds.clear()
	var distance: float = 0.0
	var previous_exit: Vector2 = START
	var previous: Vector2 = START
	var count: int = VERTICES.size()
	for index: int in range(count):
		var vertex: Vector2 = VERTICES[index]
		var next_v: Vector2 = VERTICES[(index + 1) % count]
		var in_dir: Vector2 = (vertex - previous).normalized()
		var out_dir: Vector2 = (next_v - vertex).normalized()
		var in_len: float = vertex.distance_to(previous)
		var out_len: float = next_v.distance_to(vertex)
		var angle: float = atan2(in_dir.cross(out_dir), in_dir.dot(out_dir))
		var radius: float = RADII[index]
		var tan_half: float = tan(absf(angle) * 0.5)
		var tangent: float = radius * tan_half
		var max_t: float = minf(in_len * 0.48, out_len * 0.48)
		if tangent > max_t:
			radius = max_t / tan_half
			tangent = max_t
		var entry: Vector2 = vertex - in_dir * tangent
		var exit_pt: Vector2 = vertex + out_dir * tangent
		
		_emit_straight(previous_exit, entry, distance)
		distance += previous_exit.distance_to(entry)
		
		var enter_s: float = distance
		var arc_length: float = absf(angle) * radius
		var sgn: float = 1.0 if angle > 0.0 else -1.0
		var perp: Vector2 = Vector2(-in_dir.y * sgn, in_dir.x * sgn)
		var centre: Vector2 = entry + perp * radius
		var offset: Vector2 = entry - centre
		var steps: int = maxi(2, ceili(absf(angle) / ARC_STEP_RAD))
		for step: int in range(1, steps + 1):
			var theta: float = angle * (float(step) / float(steps))
			var at: Vector2 = centre + offset.rotated(theta)
			_points.append(Vector3(at.x, 0.0, at.y))
			_arcs.append(enter_s + arc_length * (float(step) / float(steps)))
		distance += arc_length
		
		_apexes[index] = {"s": enter_s + arc_length * 0.5, "direction": sgn, "radius": radius}
		_bounds[index] = {"enter_s": enter_s, "exit_s": distance}
		previous_exit = exit_pt
		previous = vertex
	
	_emit_straight(previous_exit, START, distance)
	distance += previous_exit.distance_to(START)
	_plan_length = distance


func _emit_straight(from: Vector2, to: Vector2, at_s: float) -> void:
	var length: float = from.distance_to(to)
	var steps: int = maxi(1, ceili(length / STRAIGHT_STEP_M))
	var first: int = 0 if _points.is_empty() else 1
	for step: int in range(first, steps + 1):
		var at: Vector2 = from.lerp(to, float(step) / float(steps))
		_points.append(Vector3(at.x, 0.0, at.y))
		_arcs.append(at_s + length * (float(step) / float(steps)))
