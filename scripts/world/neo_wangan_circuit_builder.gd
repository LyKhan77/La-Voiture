class_name NeoWanganCircuitBuilder
extends Node3D

## Neo-Wangan Shuto Express (新湾岸高速), Round 02 of the championship calendar (FASE 12): a 3 150 m
## night street circuit laid out as a Tokyo C1 loop — an elevated bay expressway, an underground
## underpass, the Shibuya switchback and the harbor hairpin.
##
## The centreline is designed as a closed rectilinear street plan (fourteen corners of 90 degrees,
## nine right and five left, so the loop turns +360 degrees clockwise), each corner filleted with its
## own radius, then the whole plan is scaled to the homologated length. Two corners are filed as one
## turn: the harbor hairpin is a left–left U (two 90 degree arcs around a short quay link), and the
## wide Bay Link bend at 51 m radius is driven flat and is not numbered. That gives the official
## twelve turns, the tightest of them 22.8 m — above the 18 m a GT3 needs.
##
## The elevation profile is authored against the finished arc length: it climbs onto the Shuto Bay
## Bridge (+6.5 m at s = 500 m) and drops into the Cyber City underpass (-3.2 m at s = 1 100 m), so
## the road holds its deck over the water and its tunnel floor below street level.
##
## This scene is a separate circuit from the Apex Ring (`track_circuit.tscn`), which is never touched.

const RibbonScript := preload("res://scripts/car/track_ribbon.gd")
const RoadShader := preload("res://shaders/road_asphalt.gdshader")

const LENGTH_M: float = 3150.0
const ROAD_WIDTH_M: float = 11.5
const ROAD_HALF_WIDTH_M: float = ROAD_WIDTH_M * 0.5

## Street plan vertices (x, z) in metres, walked clockwise from START and closed back onto it.
const VERTICES: Array[Vector2] = [
	Vector2(760.0, 0.0), Vector2(760.0, 560.0), Vector2(600.0, 560.0), Vector2(600.0, 420.0),
	Vector2(430.0, 420.0), Vector2(430.0, 560.0), Vector2(350.0, 560.0), Vector2(350.0, 300.0),
	Vector2(90.0, 300.0), Vector2(90.0, 364.0), Vector2(170.0, 364.0), Vector2(170.0, 560.0),
	Vector2(-330.0, 560.0), Vector2(-330.0, 0.0),
]
## Fillet radius of each vertex, before the plan is scaled to LENGTH_M.
const RADII: Array[float] = [35.0, 48.0, 65.0, 42.0, 38.0, 32.0, 32.0, 48.0, 29.0, 29.0, 32.0, 52.0, 65.0, 42.0]
## The start/finish line sits on the bottom straight, 160 m before Turn 1 (so the pit lane has room).
const START := Vector2(600.0, 0.0)

## The official twelve turns, in travel order. `vertices` names the street-plan corners one turn is
## made of: the harbor hairpin is a left-left U, and vertex 12 (the 51 m Bay Link bend) is flat out
## and unnumbered, exactly as a real circuit's turn list skips a kink.
const TURN_SPECS: Array[Dictionary] = [
	{"vertices": [0], "name": "Shuto Gate"},
	{"vertices": [1], "name": "Bay Bridge Link"},
	{"vertices": [2], "name": "Daiba Sweep"},
	{"vertices": [3], "name": "Underpass Entry"},
	{"vertices": [4], "name": "Tunnel Esses"},
	{"vertices": [5], "name": "Cyber Chicane In"},
	{"vertices": [6], "name": "Cyber Chicane Out"},
	{"vertices": [7], "name": "Shibuya Switchback"},
	{"vertices": [8, 9], "name": "Harbor Hairpin"},
	{"vertices": [10], "name": "Dock Link"},
	{"vertices": [11], "name": "Container Sweep"},
	{"vertices": [13], "name": "Pit Straight Entry"},
]

## Elevation keys (arc metres on the finished 3 150 m lap, height in metres); smoothstep between.
const ELEVATION: Array[Vector2] = [
	Vector2(0.0, 0.0), Vector2(150.0, 0.2), Vector2(250.0, 1.2), Vector2(400.0, 5.2),
	Vector2(500.0, 6.5), Vector2(650.0, 5.6), Vector2(800.0, 3.2), Vector2(900.0, 0.8),
	Vector2(1000.0, -1.6), Vector2(1100.0, -3.2), Vector2(1200.0, -2.6), Vector2(1300.0, -0.8),
	Vector2(1400.0, 0.0), Vector2(1500.0, 0.3), Vector2(1700.0, 0.6), Vector2(2000.0, 0.2),
	Vector2(2300.0, 0.0), Vector2(2600.0, 0.0), Vector2(2900.0, 0.0), Vector2(LENGTH_M, 0.0),
]

const BRIDGE_START_M: float = 250.0
const BRIDGE_END_M: float = 700.0
const TUNNEL_START_M: float = 1080.0
const TUNNEL_END_M: float = 1260.0
## Deck height of the elevated expressway above the water it crosses.
const BRIDGE_CLEARANCE_M: float = 9.0
## Tunnel roof above the road, and the lamp spacing along its ceiling.
const TUNNEL_HEIGHT_M: float = 5.2
const TUNNEL_LAMP_PITCH_M: float = 9.0
## Where the street plan's long top edge runs (the harbor dock frontage).
const HARBOR_HAIRPIN_S: float = 1418.0

const STRAIGHT_STEP_M: float = 6.0
const ARC_STEP_RAD: float = 0.07 # ~4 degrees

var ribbon: RibbonScript
## The twelve turns: {number, name, s, apex_s, direction (+1 right, -1 left), radius_m, vertices, span_m}.
var turns: Array[Dictionary] = []
var curve_length_m: float = 0.0
## Arc spans of the three sectors (thirds of the lap, the sim's own split).
var sectors: Array[Dictionary] = []
var min_turn_radius_m: float = 0.0
var max_elevation_m: float = 0.0
var min_elevation_m: float = 0.0
## The plan's scale factor from street-plan metres to homologated metres.
var plan_scale: float = 1.0

var _points: Array[Vector3] = []
var _arcs: Array[float] = []
var _plan_length: float = 1.0
var _apexes: Dictionary = {} # vertex index -> {s, direction, radius}
var _bounds: Dictionary = {} # vertex index -> {enter_s, exit_s}


func _enter_tree() -> void:
	_build_curve()


func _ready() -> void:
	# The ribbon's own _ready has already rebuilt the sample table; the pit lane reads it from here.
	var pit = get_node_or_null("PitLane")
	if pit != null:
		pit.build(ribbon)


## The circuit's road, as the sim and the radar read it.
func ribbon_node() -> RibbonScript:
	return ribbon


func tunnel_contains(s: float) -> bool:
	return s >= TUNNEL_START_M and s <= TUNNEL_END_M


func on_bridge(s: float) -> bool:
	return s >= BRIDGE_START_M and s <= BRIDGE_END_M


## Height of the road at an arc distance, from the authored keys.
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
	var material := ShaderMaterial.new()
	material.shader = RoadShader
	return material


func _build_curve() -> void:
	ribbon = get_node_or_null("TrackRibbon") as RibbonScript
	if ribbon == null:
		push_error("NeoWanganCircuitBuilder: the scene has no TrackRibbon child")
		return
	_walk_plan()
	plan_scale = LENGTH_M / maxf(_plan_length, 1.0)
	_fit_street_plan()
	var curve := Curve3D.new()
	curve.bake_interval = 1.0
	for index: int in range(_points.size()):
		var p: Vector3 = _points[index]
		var s: float = _arcs[index] * plan_scale
		curve.add_point(Vector3(p.x * plan_scale, elevation_at(s), p.z * plan_scale))
	# Close the loop exactly on its first point.
	curve.add_point(curve.get_point_position(0))
	ribbon.curve = curve
	ribbon.road_half_width_m = ROAD_HALF_WIDTH_M
	ribbon.road_material = asphalt_material()
	curve_length_m = curve.get_baked_length()
	_build_turns()
	sectors.clear()
	for sector: int in range(3):
		sectors.append({
			"sector": sector + 1,
			"start_s": LENGTH_M * float(sector) / 3.0,
			"end_s": LENGTH_M * float(sector + 1) / 3.0,
		})
	max_elevation_m = -INF
	min_elevation_m = INF
	for index: int in range(_points.size()):
		var y: float = elevation_at(_arcs[index] * plan_scale)
		max_elevation_m = maxf(max_elevation_m, y)
		min_elevation_m = minf(min_elevation_m, y)


## The twelve numbered turns, on the finished lap: every apex in arc metres, its radius and the way
## it turns. A turn made of two corners (the hairpin) spans from the entry of the first to the exit
## of the second and takes the tighter of their radii.
func _build_turns() -> void:
	turns.clear()
	min_turn_radius_m = INF
	for spec: Dictionary in TURN_SPECS:
		var vertices: Array = spec["vertices"]
		var first: Dictionary = _apexes[int(vertices[0])]
		var last: Dictionary = _apexes[int(vertices[vertices.size() - 1])]
		var radius: float = INF
		var apex_s: Array[float] = []
		for vertex: int in vertices:
			radius = minf(radius, float(_apexes[vertex]["radius"]))
			apex_s.append(float(_apexes[vertex]["s"]) * plan_scale)
		var enter_s: float = float(_bounds[int(vertices[0])]["enter_s"])
		var exit_s: float = float(_bounds[int(vertices[vertices.size() - 1])]["exit_s"])
		turns.append({
			"number": turns.size() + 1,
			"name": String(spec["name"]),
			"s": (enter_s + exit_s) * 0.5 * plan_scale,
			"apex_s": apex_s,
			"direction": int(signf(float(first["direction"]))),
			"radius_m": radius * plan_scale,
			"vertices": vertices,
			"span_m": (exit_s - enter_s) * plan_scale,
		})
		min_turn_radius_m = minf(min_turn_radius_m, radius * plan_scale)


## Walks the street plan: a straight into every corner, the fillet arc itself, and a final straight
## back onto the start/finish line.
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
		var next: Vector2 = VERTICES[(index + 1) % count]
		var in_dir: Vector2 = (vertex - previous).normalized()
		var out_dir: Vector2 = (next - vertex).normalized()
		var angle: float = atan2(in_dir.cross(out_dir), in_dir.dot(out_dir))
		var radius: float = RADII[index]
		var tangent: float = radius * tan(absf(angle) * 0.5)
		var entry: Vector2 = vertex - in_dir * tangent
		var exit: Vector2 = vertex + out_dir * tangent
		_emit_straight(previous_exit, entry, distance)
		distance += previous_exit.distance_to(entry)
		var enter_s: float = distance
		var arc_length: float = absf(angle) * radius
		var centre: Vector2 = entry + Vector2(-in_dir.y, in_dir.x) * radius * signf(angle)
		var offset: Vector2 = entry - centre
		var steps: int = maxi(2, ceili(absf(angle) / ARC_STEP_RAD))
		for step: int in range(steps + 1):
			var at: Vector2 = centre + offset.rotated(angle * float(step) / float(steps))
			_points.append(Vector3(at.x, 0.0, at.y))
			_arcs.append(enter_s + arc_length * float(step) / float(steps))
		distance += arc_length
		_apexes[index] = {"s": enter_s + arc_length * 0.5, "direction": signf(angle), "radius": radius}
		_bounds[index] = {"enter_s": enter_s, "exit_s": distance}
		previous_exit = exit
		previous = vertex
	_emit_straight(previous_exit, START, distance)
	distance += previous_exit.distance_to(START)
	_plan_length = distance


## Straight samples from `from` to `to`; the first point is skipped when it repeats the last one.
func _emit_straight(from: Vector2, to: Vector2, at_s: float) -> void:
	var length: float = from.distance_to(to)
	var steps: int = maxi(1, ceili(length / STRAIGHT_STEP_M))
	var first: int = 0 if _points.is_empty() else 1
	for step: int in range(first, steps + 1):
		var at: Vector2 = from.lerp(to, float(step) / float(steps))
		_points.append(Vector3(at.x, 0.0, at.y))
		_arcs.append(at_s + length * float(step) / float(steps))


## Recentres the plan on its bounding box so the circuit sits around the world origin.
func _fit_street_plan() -> void:
	var bounds := Rect2(Vector2(_points[0].x, _points[0].z), Vector2.ZERO)
	for point: Vector3 in _points:
		bounds = bounds.expand(Vector2(point.x, point.z))
	var centre: Vector2 = bounds.get_center()
	for index: int in range(_points.size()):
		_points[index] = Vector3(_points[index].x - centre.x, 0.0, _points[index].z - centre.y)
