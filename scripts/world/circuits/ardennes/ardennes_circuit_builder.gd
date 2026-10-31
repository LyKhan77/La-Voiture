class_name ArdennesCircuitBuilder
extends Node3D

## Ardennes Valley Ring (Round 05, GRAND_PRIX, FASE 16): a 5 400 m forest-and-stadium circuit laid out from the frozen
## mapgen blueprint `designs/ardennes/final/blueprint.track.json` (geometry_hash below). The centreline is a closed
## tangent alignment (straights joined by circular fillets), walked clockwise from the start line, then scaled by
## `plan_scale` so the 3D lap is exactly LENGTH_M: the 104 m climb lengthens the curve by ~8 m, so the flat plan ends
## ~8 m short of LENGTH_M and every blueprint station (pit 5220 / 240, landmarks, turns) is a ribbon distance.
##
## The road climbs from the start straight (18 m) over the north summit (104 m, s~1800) and drops into the stadium
## bowl (0 m, s~3300) before it rises back to the start line. Four of the 20 turns are kinks under 15 degrees (T2, T3,
## T4, T11); those get no kerbs or braking boards (KERB_MIN_ANGLE_DEG).

const RibbonScript := preload("res://scripts/car/track_ribbon.gd")
const RoadShader := preload("res://shaders/road_asphalt.gdshader")

const GEOMETRY_HASH := "sha256:fea86645c41b985de3d0b7987a90785d62a319e0507796e98656275c3bed98d4"
const LENGTH_M: float = 5400.0
const ROAD_WIDTH_M: float = 14.0
const ROAD_HALF_WIDTH_M: float = ROAD_WIDTH_M * 0.5
## Turns that turn less than this stay in `turns` (the minimap numbers them) but get no kerbs or braking boards.
const KERB_MIN_ANGLE_DEG: float = 15.0

## Blueprint vertices (x, z) in plan metres: the 20 turns, then the start line (radius 5000 = a straight, which keeps
## the closing leg collinear with the start/finish straight).
const VERTICES: Array[Vector2] = [
	Vector2(390.0, 0.0), Vector2(460.0, 250.0), Vector2(580.0, 560.0), Vector2(640.0, 920.0), Vector2(610.0, 1280.0),
	Vector2(500.0, 1580.0), Vector2(320.0, 1780.0), Vector2(120.0, 1850.0), Vector2(-20.0, 1700.0), Vector2(-70.0, 1460.0),
	Vector2(80.0, 1280.0), Vector2(200.0, 1100.0), Vector2(210.0, 880.0), Vector2(60.0, 730.0), Vector2(-80.0, 850.0),
	Vector2(-170.0, 1020.0), Vector2(-270.0, 820.0), Vector2(-240.0, 520.0), Vector2(-330.0, 180.0), Vector2(-240.0, 0.0),
	Vector2(0.0, 0.0),
]
## Plan fillet radius of each vertex (the blueprint's `alignment.radii`).
const RADII: Array[float] = [
	38.0, 120.0, 130.0, 140.0, 120.0, 100.0, 95.0, 95.0, 85.0, 80.0, 75.0, 80.0, 75.0, 80.0, 75.0, 46.0, 95.0, 120.0,
	40.0, 40.0, 5000.0,
]
const START := Vector2(0.0, 0.0)

## Turn names as in the blueprint, without the "Tn " prefix (the HUD and the minimap print the number separately).
const TURN_NAMES: Array[String] = [
	"Arena Gateway Hairpin", "Outer Crescent Arc 1", "Outer Crescent Arc 2", "Ridge Panorama Sweeper",
	"North Summit Climb Arc", "North Summit Crest Turn", "Mountain Crest Carousel 1", "Mountain Crest Carousel 2",
	"Infield Stadium Drop", "Amphitheater Chute", "Infield Bowl Entry", "Stadium Inner Carousel Apex 1",
	"Stadium Inner Carousel Apex 2", "Stadium Lower Bowl Sweeper", "Grandstand S-Transition", "Arena West Hook In",
	"Arena West Hook Out", "West Ridge High-Speed Exit", "Stadium Chicane In", "Stadium Chicane Out",
]

## Height of the road at an arc distance (blueprint `elevation.samples`), smoothstep between keys: 104 m of climb.
const ELEVATION: Array[Vector2] = [
	Vector2(0.0, 18.0), Vector2(390.0, 18.0), Vector2(700.0, 35.0), Vector2(1300.0, 65.0), Vector2(1800.0, 104.0),
	Vector2(2300.0, 85.0), Vector2(2800.0, 45.0), Vector2(3300.0, 0.0), Vector2(3800.0, 10.0), Vector2(4300.0, 15.0),
	Vector2(4800.0, 16.0), Vector2(5180.0, 18.0), Vector2(LENGTH_M, 18.0),
]

const STRAIGHT_STEP_M: float = 6.0
const ARC_STEP_RAD: float = 0.07 # ~4 degrees
const MIN_POINT_GAP_M: float = 0.01
## Trims of `plan_scale` that bring the 3D ribbon to LENGTH_M.
const SCALE_PASSES: int = 6

var ribbon: RibbonScript
## The 20 turns: {number, name, s, apex_s, direction (+1 right, -1 left), radius_m, vertices, span_m, angle_deg}.
var turns: Array[Dictionary] = []
## Length of the baked 3D curve, the ribbon's lap: LENGTH_M.
var curve_length_m: float = 0.0
## Length of the scaled flat plan: ~8 m under LENGTH_M, the climb and fall make up the rest.
var plan_length_m: float = 0.0
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


## Height of the road at an arc distance, smoothstep between the authored keys.
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
		push_error("ArdennesCircuitBuilder: scene has no TrackRibbon child")
		return
	_walk_plan()
	# The flat plan scales to LENGTH_M first; the climb then makes the 3D curve ~8 m longer, so the scale is trimmed until
	# the ribbon itself is LENGTH_M. Every blueprint station (pit, landmarks, turns) is then a ribbon distance.
	plan_scale = LENGTH_M / maxf(_plan_length, 1.0)
	var curve: Curve3D = _make_curve()
	for _pass: int in range(SCALE_PASSES):
		plan_scale *= LENGTH_M / curve.get_baked_length()
		curve = _make_curve()
	plan_length_m = _plan_length * plan_scale

	ribbon.curve = curve
	ribbon.road_half_width_m = ROAD_HALF_WIDTH_M
	ribbon.road_material = asphalt_material()
	curve_length_m = curve.get_baked_length()

	_build_turns()
	sectors.clear()
	for index: int in range(3):
		sectors.append({
			"sector": index + 1,
			"start_s": LENGTH_M * float(index) / 3.0,
			"end_s": LENGTH_M * float(index + 1) / 3.0,
		})


## The closed 3D curve for the current `plan_scale`; also records the elevation extremes.
func _make_curve() -> Curve3D:
	var curve := Curve3D.new()
	curve.bake_interval = 1.0
	var previous := Vector3.INF
	max_elevation_m = -INF
	min_elevation_m = INF
	for index: int in range(_points.size()):
		var s: float = _arcs[index] * plan_scale
		var point := Vector3(_points[index].x * plan_scale, elevation_at(s), _points[index].z * plan_scale)
		if previous != Vector3.INF and point.distance_to(previous) < MIN_POINT_GAP_M:
			continue
		curve.add_point(point)
		previous = point
		max_elevation_m = maxf(max_elevation_m, point.y)
		min_elevation_m = minf(min_elevation_m, point.y)
	# Close the loop on the first point.
	curve.add_point(curve.get_point_position(0))
	return curve


func _build_turns() -> void:
	turns.clear()
	min_turn_radius_m = INF
	for index: int in range(TURN_NAMES.size()):
		var apex: Dictionary = _apexes[index]
		var bounds: Dictionary = _bounds[index]
		var radius: float = float(apex["radius"]) * plan_scale
		var apex_s: Array[float] = [float(apex["s"]) * plan_scale]
		turns.append({
			"number": index + 1,
			"name": TURN_NAMES[index],
			"s": (float(bounds["enter_s"]) + float(bounds["exit_s"])) * 0.5 * plan_scale,
			"apex_s": apex_s,
			"direction": int(signf(float(apex["direction"]))),
			"radius_m": radius,
			"vertices": [index],
			"span_m": (float(bounds["exit_s"]) - float(bounds["enter_s"])) * plan_scale,
			"angle_deg": absf(rad_to_deg(float(apex["angle"]))),
		})
		min_turn_radius_m = minf(min_turn_radius_m, radius)


## Walks the plan polygon with a fillet at every vertex: straight, arc, straight, arc... back to the start line.
## A fillet is clamped to 48 % of its shorter edge (none of the Ardennes fillets needs it).
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
		if arc_length > 0.001:
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

		_apexes[index] = {"s": enter_s + arc_length * 0.5, "direction": sgn, "radius": radius, "angle": angle}
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
