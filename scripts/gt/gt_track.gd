class_name GtTrack
extends RefCounted

## The circuit as the GT sim sees it (reference `track.ts`), built on the 3D ribbon
## so the sim and the picture share one length: no distance scale anywhere.
## Lateral + = right of travel. Curvature + = right turn (the spec's kappa).

const TrackRibbonScript := preload("res://scripts/car/track_ribbon.gd")
const LineScript := preload("res://scripts/car/adaptive_racing_line.gd")

const SAMPLE_SPACING_M: float = 5.0
const LATERAL_ACCEL: float = 19.5 # m/s2, a GT3 with downforce
const BRAKE_DECEL: float = 15.0
const ACCEL: float = 7.0
const V_MAX: float = 76.0
const DRS_MIN_STRAIGHT_M: float = 250.0
const DRS_STRAIGHT_KAPPA: float = 0.0025

var ribbon: TrackRibbonScript
var line: LineScript
var length: float = 0.0
var count: int = 0
var spacing: float = 5.0
var width: float = 14.0
## Zones {name, detection_s, start_s, end_s}; start_s > end_s wraps over the line.
var drs_zones: Array[Dictionary] = []

var _profile: PackedFloat32Array = PackedFloat32Array()


func _init(p_ribbon: TrackRibbonScript, p_width: float = 14.0) -> void:
	ribbon = p_ribbon
	width = p_width
	line = LineScript.new(ribbon)
	length = ribbon.length_m
	count = maxi(8, floori(length / SAMPLE_SPACING_M))
	spacing = length / float(count)
	_profile = _build_profile()
	drs_zones = _find_drs_zones()


## World transform of a point on the circuit; -Z is forward, +X is right of travel.
func point_at(s: float, lateral: float = 0.0) -> Transform3D:
	return ribbon.get_point_at_offset(s, lateral)


func wrap_s(s: float) -> float:
	return fposmod(s, length)


func curvature_at(s: float) -> float:
	return line.curvature_at(s)


## Racing line offset: hugs the inside of a corner, centred on straights, +-3.2 m.
func ideal_lateral_at(s: float) -> float:
	return line.target_offset(s)


## Keeps a car inside the usable asphalt.
func clamp_to_width(lateral: float, margin: float = 1.6) -> float:
	var half_usable: float = width * 0.5 - margin
	return clampf(lateral, -half_usable, half_usable)


## Reference speed (m/s) for the corner, braking and acceleration envelope.
func speed_limit_at(s: float) -> float:
	var x: float = wrap_s(s) / spacing
	var i: int = int(x) % count
	return lerpf(_profile[i], _profile[(i + 1) % count], x - floorf(x))


func average_speed() -> float:
	var sum: float = 0.0
	for value: float in _profile:
		sum += value
	return sum / float(count)


## The DRS zone containing `s`, or an empty Dictionary.
func drs_zone_at(s: float) -> Dictionary:
	var s_norm: float = wrap_s(s)
	for zone: Dictionary in drs_zones:
		var start_s: float = zone["start_s"]
		var end_s: float = zone["end_s"]
		if start_s > end_s:
			if s_norm >= start_s or s_norm <= end_s:
				return zone
		elif s_norm >= start_s and s_norm <= end_s:
			return zone
	return {}


func _build_profile() -> PackedFloat32Array:
	var profile := PackedFloat32Array()
	profile.resize(count)
	for i: int in range(count):
		var kappa: float = maxf(absf(curvature_at(float(i) * spacing)), 1.0e-4)
		profile[i] = minf(V_MAX, sqrt(LATERAL_ACCEL / kappa))
	# Braking: look ahead around the loop, two laps so the start line converges.
	for k: int in range(2 * count):
		var i: int = posmod(count - 1 - (k % count), count)
		var next: int = (i + 1) % count
		profile[i] = minf(profile[i], sqrt(profile[next] * profile[next] + 2.0 * BRAKE_DECEL * spacing))
	# Acceleration: how fast speed can build after a corner.
	for k: int in range(2 * count):
		var i: int = k % count
		var previous: int = posmod(i - 1, count)
		profile[i] = minf(profile[i], sqrt(profile[previous] * profile[previous] + 2.0 * ACCEL * spacing))
	return profile


## The two longest straights get a DRS zone: detection before the straight, activation
## from 40 m in to 60 m before the next braking zone.
func _find_drs_zones() -> Array[Dictionary]:
	var straights: Array[Dictionary] = []
	var run_start: float = -1.0
	var step: float = 5.0
	var s: float = 0.0
	# Start inside a corner so no straight is cut by the lap line.
	var origin: float = 0.0
	var best_kappa: float = 0.0
	while s < length:
		if absf(curvature_at(s)) > best_kappa:
			best_kappa = absf(curvature_at(s))
			origin = s
		s += step
	var offset: float = 0.0
	while offset <= length:
		var here: float = origin + offset
		var straight: bool = absf(curvature_at(here)) < DRS_STRAIGHT_KAPPA
		if straight and run_start < 0.0:
			run_start = here
		elif not straight and run_start >= 0.0:
			if here - run_start >= DRS_MIN_STRAIGHT_M:
				straights.append({"a": run_start, "b": here})
			run_start = -1.0
		offset += step
	straights.sort_custom(func(x: Dictionary, y: Dictionary) -> bool: return (x["b"] - x["a"]) > (y["b"] - y["a"]))
	var zones: Array[Dictionary] = []
	for index: int in range(mini(2, straights.size())):
		var a: float = straights[index]["a"]
		var b: float = straights[index]["b"]
		zones.append({
			"name": "Main Straight" if index == 0 else "Back Straight",
			"detection_s": wrap_s(a - 120.0),
			"start_s": wrap_s(a + 40.0),
			"end_s": wrap_s(b - 60.0),
		})
	return zones
