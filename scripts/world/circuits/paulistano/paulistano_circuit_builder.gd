class_name PaulistanoCircuitBuilder
extends Node3D

## Round 09 SEP BRA: the approved Paulistano Speed Arena (4.310 m, 15 turns,
## counter-clockwise, 13.5 m asphalt, 40 m elevation, left-hand 410 m pit lane).
## The curve is compiled from the frozen package blueprint (geometry hash
## e7e318e7...90cb); the layout is not redesigned here.

const Ribbon := preload("res://scripts/car/track_ribbon.gd")
const Layout := preload("res://scripts/world/circuits/paulistano/paulistano_layout.gd")
const CURVE := preload("res://assets/tracks/paulistano/data/paulistano_curve.tres")
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
	compiled = {"points": points, "step_m": curve_length_m / float(maxi(1, points.size())), "length_m": curve_length_m}
	var stations := Layout.turn_stations(points)
	min_turn_radius_m = INF
	min_elevation_m = INF
	max_elevation_m = -INF
	for point: Vector3 in points:
		min_elevation_m = minf(min_elevation_m, point.y)
		max_elevation_m = maxf(max_elevation_m, point.y)
	for i: int in range(Layout.TURN_COUNT):
		# The plan vertex sits outside its fillet: the apex is the curvature peak near it.
		var station: float = _apex_near(stations[i] / Layout.LENGTH_M * ribbon.length_m)
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


func _apex_near(near_s: float) -> float:
	var best_s: float = near_s
	var best_k: float = -1.0
	for offset: int in range(-80, 81, 2):
		var s: float = fposmod(near_s + float(offset), ribbon.length_m)
		var k: float = absf(ribbon.get_curvature_at(s))
		if k > best_k:
			best_k = k
			best_s = s
	return best_s


func ribbon_node() -> Ribbon:
	return ribbon
