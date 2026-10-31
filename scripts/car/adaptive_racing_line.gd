class_name AdaptiveRacingLine
extends RefCounted

## Racing line for the 3D circuit (FASE 5.5, PRD 01 section 7; rebuilt in FASE 18).
## Pure maths over a TrackRibbon: signed centreline curvature, the racing line
## itself (outside - apex - outside, from a minimum-curvature solve inside the
## asphalt, computed once), the line's own curvature, a grip-adaptive corner speed
## limit and the braking envelope that starts earlier when the tires give less grip.
## Nothing here moves a car.
##
## Sign convention: kappa > 0 is a right turn and d > 0 is right of travel
## (+X in the ribbon basis), so a positive kappa pulls the line to the inside.

const TrackRibbonScript := preload("res://scripts/car/track_ribbon.gd")

const CURVATURE_STEP_M: float = 6.0 # delta-s between the two tangents
const TABLE_STEP_M: float = 2.0
const MAX_LATERAL_SPEED_MPS: float = 1.8
## The line's centre stays this far inside the asphalt edge: half a car plus the kerb a driver clips.
const LINE_EDGE_MARGIN_M: float = 1.7
## Coarse-to-fine grids of the minimum-curvature solve and the sweeps at each one. A coarse grid
## spreads a corner's influence over hundreds of metres in few sweeps; the fine ones settle the apex.
const LINE_LEVELS_M: Array[float] = [32.0, 16.0, 8.0, 4.0]
const LINE_SWEEPS: Array[int] = [300, 150, 80, 40]
const LINE_OVER_RELAXATION: float = 1.6
## Half-window of the line curvature (chord angle over 2 x this) and its smoothing taps.
const LINE_CURVATURE_HALF_M: float = 6.0
const LINE_CURVATURE_SMOOTH_TAPS: int = 3
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

## Largest |offset| the line may take: the asphalt half-width less LINE_EDGE_MARGIN_M.
var line_limit_m: float = 0.0

var _kappa: PackedFloat32Array = PackedFloat32Array()
var _offset: PackedFloat32Array = PackedFloat32Array() # racing line lateral per table step
var _line_kappa: PackedFloat32Array = PackedFloat32Array()
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
	line_limit_m = maxf(0.5, ribbon.road_half_width_m - LINE_EDGE_MARGIN_M)
	_solve_line()
	_build_line_curvature()


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


## d_target(s) in meters: the racing line, within +-line_limit_m.
func target_offset(s: float) -> float:
	return _sample(_offset, s)


## Signed curvature of the racing line itself (1/m, + = right turn): what the car really drives.
func line_curvature_at(s: float) -> float:
	return _sample(_line_kappa, s)


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


func _sample(table: PackedFloat32Array, s: float) -> float:
	var u: float = fposmod(s, length_m) / _step_m
	var i: int = posmod(int(u), _count)
	return lerpf(table[i], table[posmod(i + 1, _count)], u - floorf(u))


## Minimum-curvature line: every point slides along its cross-section to where the squared second
## difference of the line is least, (4 (P[i-1] + P[i+1]) - (P[i-2] + P[i+2])) / 6 (over-relaxed
## Gauss-Seidel), clamped to the asphalt. The plain neighbour midpoint would minimise length instead
## and glue the line to the inside of the whole loop. A corner pulls the line wide on entry, onto the
## apex and wide on exit; centreline noise is smoothed away for free.
func _solve_line() -> void:
	var d := PackedFloat32Array()
	var coarse_step: float = 0.0
	for level: int in range(LINE_LEVELS_M.size()):
		var n: int = maxi(8, roundi(length_m / LINE_LEVELS_M[level]))
		var step: float = length_m / float(n)
		var centre := PackedVector2Array()
		var right := PackedVector2Array()
		centre.resize(n)
		right.resize(n)
		var next := PackedFloat32Array()
		next.resize(n)
		for i: int in range(n):
			var pose: Transform3D = ribbon.get_point_at_offset(float(i) * step, 0.0)
			centre[i] = Vector2(pose.origin.x, pose.origin.z)
			right[i] = Vector2(pose.basis.x.x, pose.basis.x.z).normalized()
			next[i] = 0.0 if d.is_empty() else _lerp_ring(d, float(i) * step / coarse_step)
		d = next
		for _sweep: int in range(LINE_SWEEPS[level]):
			for i: int in range(n):
				var a: int = posmod(i - 1, n)
				var b: int = (i + 1) % n
				var aa: int = posmod(i - 2, n)
				var bb: int = (i + 2) % n
				var best: Vector2 = ((centre[a] + right[a] * d[a] + centre[b] + right[b] * d[b]) * 4.0
					- (centre[aa] + right[aa] * d[aa] + centre[bb] + right[bb] * d[bb])) / 6.0
				var goal: float = (best - centre[i]).dot(right[i])
				d[i] = clampf(d[i] + (goal - d[i]) * LINE_OVER_RELAXATION, -line_limit_m, line_limit_m)
		coarse_step = step
	_offset.resize(_count)
	for i: int in range(_count):
		_offset[i] = _lerp_ring(d, float(i) * _step_m / coarse_step)


static func _lerp_ring(values: PackedFloat32Array, u: float) -> float:
	var n: int = values.size()
	var i: int = posmod(int(floorf(u)), n)
	return lerpf(values[i], values[(i + 1) % n], u - floorf(u))


## Chord-angle curvature of the line points, then a small box filter so the speed profile reads
## the shape of the corner, not the solver's grid.
func _build_line_curvature() -> void:
	var points := PackedVector3Array()
	points.resize(_count)
	for i: int in range(_count):
		points[i] = ribbon.get_point_at_offset(float(i) * _step_m, _offset[i]).origin
	var k: int = maxi(1, roundi(LINE_CURVATURE_HALF_M / _step_m))
	var raw := PackedFloat32Array()
	raw.resize(_count)
	for i: int in range(_count):
		var t0: Vector3 = points[i] - points[posmod(i - k, _count)]
		var t1: Vector3 = points[(i + k) % _count] - points[i]
		raw[i] = signed_curvature(t0, t1, (Vector3(t0.x, 0.0, t0.z).length() + Vector3(t1.x, 0.0, t1.z).length()) * 0.5)
	_line_kappa.resize(_count)
	for i: int in range(_count):
		var sum: float = 0.0
		for j: int in range(-LINE_CURVATURE_SMOOTH_TAPS, LINE_CURVATURE_SMOOTH_TAPS + 1):
			sum += raw[posmod(i + j, _count)]
		_line_kappa[i] = sum / float(2 * LINE_CURVATURE_SMOOTH_TAPS + 1)


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
