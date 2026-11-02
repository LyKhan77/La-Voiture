class_name PacificCorkscrewCircuitBuilder
extends Node3D

## Approved Route 2: Pacific Coast Corkscrew, July USA Grand Prix. The curve is
## baked from the frozen package blueprint (4.100 m, 11 turns, 13 m asphalt,
## 0..30 m elevation, right-hand 420 m pit lane). Fase 0 raised the box pitch to
## 20 m through core/patch.gd; the track alignment is untouched.

const Ribbon := preload("res://scripts/car/track_ribbon.gd")
const Layout := preload("res://scripts/world/circuits/pacific_corkscrew/pacific_corkscrew_layout.gd")
const CURVE := preload("res://assets/tracks/pacific_corkscrew/data/pacific_corkscrew_curve.tres")
const ROAD := preload("res://shaders/road_asphalt.gdshader")
const LENGTH_M: float = 4100.0

var ribbon: Ribbon
var turns: Array[Dictionary] = []
var sectors: Array[Dictionary] = []
var curve_length_m: float = 0.0
var min_turn_radius_m: float = 0.0
var min_elevation_m: float = 0.0
var max_elevation_m: float = 30.0
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
	compiled = {"points": points, "step_m": 1.0, "length_m": LENGTH_M, "count": points.size()}
	var stations := Layout.turn_stations(points)
	min_turn_radius_m = INF
	for i: int in range(Layout.TURN_NAMES.size()):
		var radius := ribbon.get_radius_at(stations[i])
		turns.append({"number": i + 1, "name": Layout.TURN_NAMES[i], "s": stations[i], "apex_s": [stations[i]], "direction": int(signf(ribbon.get_curvature_at(stations[i]))), "radius_m": radius, "span_m": 30.0})
		min_turn_radius_m = minf(min_turn_radius_m, radius)
	for i: int in range(3):
		sectors.append({"sector": i + 1, "start_s": LENGTH_M * float(i) / 3.0, "end_s": LENGTH_M * float(i + 1) / 3.0})
	get_node("PitLane").build(ribbon)
	get_node("Environment").build(ribbon, self)
	get_node("Environment").bind_world(get_node("WorldEnvironment"), null, null)


func ribbon_node() -> Ribbon:
	return ribbon
