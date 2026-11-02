class_name StokeCrownCircuitBuilder
extends Node3D

## Approved Route 2, Phase 0: dense tangential spline, 18 turns, 5200 m, June GBR GP.
const Ribbon := preload("res://scripts/car/track_ribbon.gd")
const Layout := preload("res://scripts/world/circuits/stoke_crown/stoke_crown_layout.gd")
const CURVE := preload("res://assets/tracks/stoke_crown/data/stoke_crown_curve.tres")
const ROAD := preload("res://shaders/road_asphalt.gdshader")
const LENGTH_M: float = 5200.0

var ribbon: Ribbon
var turns: Array[Dictionary] = []
var sectors: Array[Dictionary] = []
var curve_length_m: float = 0.0
var min_turn_radius_m: float = 0.0
var min_elevation_m: float = 0.0
var max_elevation_m: float = 12.0
var compiled: Dictionary = {}

func _enter_tree() -> void:
	ribbon = get_node("TrackRibbon") as Ribbon
	ribbon.curve = CURVE
	ribbon.road_half_width_m = 7.0
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
	for i: int in range(18):
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
