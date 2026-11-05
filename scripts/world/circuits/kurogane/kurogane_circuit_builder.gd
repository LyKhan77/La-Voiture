class_name KuroganeCircuitBuilder
extends Node3D

## Round 10 OCT JPN: the approved Kurogane Twin-Cross GP (5.800 m, 20 turns,
## clockwise figure-8, 13.5 m asphalt, 40 m elevation, right-hand 410 m pit lane,
## grade-separated crossover at s 2752 x 3924). The curve is compiled from the
## frozen package blueprint (geometry hash 051118ec...7cbe77cd); the layout is not
## redesigned here.

const Ribbon := preload("res://scripts/car/track_ribbon.gd")
const Layout := preload("res://scripts/world/circuits/kurogane/kurogane_layout.gd")
const CURVE := preload("res://assets/tracks/kurogane/data/kurogane_curve.tres")
const ROAD := preload("res://shaders/road_asphalt.gdshader")

var ribbon: Ribbon
var turns: Array[Dictionary] = []
var sectors: Array[Dictionary] = []
var curve_length_m: float = 0.0
var min_turn_radius_m: float = 0.0
var min_elevation_m: float = 0.0
var max_elevation_m: float = 40.0
## The compiled centreline the environment/terrain read (no mapgen repo at runtime).
var compiled: Dictionary = {}


func _enter_tree() -> void:
	ribbon = get_node("TrackRibbon") as Ribbon
	ribbon.curve = CURVE
	ribbon.road_half_width_m = Layout.ROAD_HALF_M
	var material := ShaderMaterial.new()
	material.shader = ROAD
	ribbon.road_material = material
	curve_length_m = CURVE.get_baked_length()


func _ready() -> void:
	var points := PackedVector3Array()
	for i: int in range(CURVE.point_count - 1):
		points.append(CURVE.get_point_position(i))
	# Station space is the compiled 1 m point index (the baked ribbon is 1.389 m longer from the closing fillet).
	compiled = {"points": points, "step_m": Layout.LENGTH_M / float(maxi(1, points.size())), "length_m": Layout.LENGTH_M}
	var stations: Array = Layout.TURN_STATIONS
	min_turn_radius_m = INF
	min_elevation_m = INF
	max_elevation_m = -INF
	for point: Vector3 in points:
		min_elevation_m = minf(min_elevation_m, point.y)
		max_elevation_m = maxf(max_elevation_m, point.y)
	for i: int in range(Layout.TURN_COUNT):
		# The plan vertex sits outside its fillet: the apex is the curvature peak near it.
		# Corners 100 m apart (the Ryu no Senkai S-bends) must not snap to the same curvature peak.
		var gap: float = 80.0
		if i > 0:
			gap = minf(gap, (float(stations[i]) - float(stations[i - 1])) * 0.45)
		if i < Layout.TURN_COUNT - 1:
			gap = minf(gap, (float(stations[i + 1]) - float(stations[i])) * 0.45)
		var station: float = _apex_near(float(stations[i]) / Layout.LENGTH_M * ribbon.length_m, gap)
		var radius: float = ribbon.get_radius_at(station)
		turns.append({
			"number": i + 1, "name": Layout.TURN_NAMES[i], "s": station, "apex_s": [station],
			"direction": int(signf(ribbon.get_curvature_at(station))), "radius_m": radius, "span_m": 30.0,
		})
		min_turn_radius_m = minf(min_turn_radius_m, radius)
	for i: int in range(3):
		sectors.append({"sector": i + 1, "start_s": ribbon.length_m * float(i) / 3.0, "end_s": ribbon.length_m * float(i + 1) / 3.0})
	get_node("PitLane").build(ribbon)
	get_node("Environment").build(ribbon, self)
	get_node("Environment").bind_world(get_node("WorldEnvironment"), get_node_or_null("Sun"), null)


func _apex_near(near_s: float, window: float) -> float:
	var best_s: float = near_s
	var best_k: float = -1.0
	for offset: int in range(-int(window), int(window) + 1, 2):
		var s: float = fposmod(near_s + float(offset), ribbon.length_m)
		var k: float = absf(ribbon.get_curvature_at(s))
		if k > best_k:
			best_k = k
			best_s = s
	return best_s


func ribbon_node() -> Ribbon:
	return ribbon
