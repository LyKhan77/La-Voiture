class_name AdaptiveRacingLine
extends RefCounted

## Curvature-driven racing line for the 3D circuit (FASE 5.5, PRD 01 section 7).
## Pure maths over a TrackRibbon: signed curvature, the lateral apex-clipping
## target, a grip-adaptive corner speed limit and the braking envelope that
## starts earlier when the tires give less grip. Nothing here moves a car.
##
## Sign convention: kappa > 0 is a right turn and d > 0 is right of travel
## (+X in the ribbon basis), so a positive kappa pulls the line to the inside.

const TrackRibbonScript := preload("res://scripts/car/track_ribbon.gd")

const CURVATURE_STEP_M: float = 6.0 # delta-s between the two tangents
const TABLE_STEP_M: float = 2.0
const LOOKAHEAD_M: float = 25.0
const NOW_WEIGHT: float = 0.4
const AHEAD_WEIGHT: float = 0.6
const OFFSET_GAIN: float = 180.0
const MAX_OFFSET_M: float = 3.2
const MAX_LATERAL_SPEED_MPS: float = 1.8
const GRAVITY: float = 9.81
## Lateral grip of a GT3 on a fresh soft tire, aero included; scaled by tire mu.
const BASE_LATERAL_MU: float = 2.0
const BRAKE_MU_SHARE: float = 0.9
const MAX_BRAKE_MPS2: float = 30.0
const MIN_CURVATURE: float = 1.0e-4
const MAX_LIMIT_MPS: float = 100.0
const BRAKE_LOOKAHEAD_M: float = 450.0
const BRAKE_SCAN_STEP_M: float = 5.0

var ribbon: TrackRibbonScript
var length_m: float = 0.0

var _kappa: PackedFloat32Array = PackedFloat32Array()
var _count: int = 0
var _step_m: float = TABLE_STEP_M
var _envelopes: Dictionary = {} # mu bucket -> PackedFloat32Array


func _init(p_ribbon: TrackRibbonScript) -> void:
	ribbon = p_ribbon
	length_m = ribbon.length_m
	_count = maxi(8, roundi(length_m / TABLE_STEP_M))
	_step_m = length_m / float(_count)
	_kappa.resize(_count)
	var half: float = CURVATURE_STEP_M * 0.5
	for i: int in range(_count):
		var s: float = float(i) * _step_m
		_kappa[i] = signed_curvature(_tangent(s - half), _tangent(s + half), CURVATURE_STEP_M)


## (t1 x t0) . y / delta-s on the ground plane; t0 is the earlier tangent.
static func signed_curvature(t0: Vector3, t1: Vector3, delta_s: float) -> float:
	var a := Vector3(t0.x, 0.0, t0.z).normalized()
	var b := Vector3(t1.x, 0.0, t1.z).normalized()
	return b.cross(a).y / delta_s


## Lateral rate limit: where a car at `current` is after dt seconds heading for `target`.
static func step_offset(current: float, target: float, dt: float) -> float:
	return move_toward(current, target, MAX_LATERAL_SPEED_MPS * dt)


## Square-root law; mu_scale is the tire grip relative to a fresh soft (1.0).
static func corner_limit_for(kappa: float, mu_scale: float = 1.0) -> float:
	var k: float = maxf(absf(kappa), MIN_CURVATURE)
	return minf(sqrt(BASE_LATERAL_MU * mu_scale * GRAVITY / k), MAX_LIMIT_MPS)


## Distance before a corner at which braking from `speed` to `corner_speed` must start.
static func braking_distance(speed: float, corner_speed: float, mu_scale: float = 1.0) -> float:
	if speed <= corner_speed:
		return 0.0
	return (speed * speed - corner_speed * corner_speed) / (2.0 * brake_decel_for(mu_scale))


static func brake_decel_for(mu_scale: float) -> float:
	return minf(BASE_LATERAL_MU * BRAKE_MU_SHARE * mu_scale * GRAVITY, MAX_BRAKE_MPS2)


func curvature_at(s: float) -> float:
	var u: float = fposmod(s, length_m) / _step_m
	var i: int = posmod(int(u), _count)
	return lerpf(_kappa[i], _kappa[posmod(i + 1, _count)], u - floorf(u))


## d_target(s) in meters, clamped to +-3.2 m.
func target_offset(s: float) -> float:
	var blended: float = NOW_WEIGHT * curvature_at(s) + AHEAD_WEIGHT * curvature_at(s + LOOKAHEAD_M)
	return clampf(blended * OFFSET_GAIN, -MAX_OFFSET_M, MAX_OFFSET_M)


func corner_limit_at(s: float, mu_scale: float = 1.0) -> float:
	return corner_limit_for(curvature_at(s), mu_scale)


## Highest speed allowed at `s` so every corner ahead can still be taken: the
## braking envelope, min over x of sqrt(v_limit(s + x)^2 + 2 * a_brake * x).
func speed_cap_at(s: float, mu_scale: float = 1.0) -> float:
	var table: PackedFloat32Array = _envelope(mu_scale)
	var u: float = fposmod(s, length_m) / _step_m
	var i: int = posmod(int(u), _count)
	# Not lerped: limits are nonlinear in kappa, so the lower neighbour keeps the cap safe.
	return minf(table[i], table[posmod(i + 1, _count)])


## Distance ahead of `s` at which a car doing `speed` has to start braking so it
## never exceeds a corner limit within the lookahead (negative = already late);
## INF when no corner ahead is slower than `speed`.
func braking_point_ahead(s: float, speed: float, mu_scale: float = 1.0) -> float:
	var point: float = INF
	var x: float = 0.0
	while x <= BRAKE_LOOKAHEAD_M:
		var limit: float = corner_limit_at(s + x, mu_scale)
		if limit < speed:
			point = minf(point, x - braking_distance(speed, limit, mu_scale))
		x += BRAKE_SCAN_STEP_M
	return point


func _tangent(s: float) -> Vector3:
	return -ribbon.get_point_at_offset(s, 0.0).basis.z


## Envelope table for one grip level, built by sweeping backward from every
## corner (two passes close the loop at the start line).
func _envelope(mu_scale: float) -> PackedFloat32Array:
	var bucket: int = roundi(mu_scale * 20.0)
	if _envelopes.has(bucket):
		return _envelopes[bucket]
	var mu: float = float(bucket) / 20.0
	var decel: float = brake_decel_for(mu)
	var table := PackedFloat32Array()
	table.resize(_count)
	for i: int in range(_count):
		table[i] = corner_limit_for(_kappa[i], mu)
	for _pass: int in range(2):
		for i: int in range(_count - 1, -1, -1):
			var ahead: float = table[posmod(i + 1, _count)]
			table[i] = minf(table[i], sqrt(ahead * ahead + 2.0 * decel * _step_m))
	_envelopes[bucket] = table
	return table
