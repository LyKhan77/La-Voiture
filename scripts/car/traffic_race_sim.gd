class_name TrafficRaceSim
extends "res://scripts/core/race_sim_engine.gd"

## RaceSimEngine with car bodies, for the 3D world. The base engine treats cars
## as points: a follower may close at +1 m/s relative speed at any gap, so by
## lap one the pack sits at 0 m gaps in the same lane, and lane moves ignore
## cars alongside. Nothing a view layer does can separate that. This subclass
## keeps all base maths and adds two rules:
##   1. lane-aware following: only a car in a conflicting lane blocks, and a
##      follower never closes faster than it can brake to min_gap_m;
##   2. a lane move that would put a car beside another is held.
## The base engine is untouched; the pit wall session still runs it as before.

const LANE_CLEARANCE: float = 0.95 # lane units (2.375 m): 2.0 m wide cars + margin for easing and yaw
const FOLLOW_RANGE_M: float = 15.0 # same range as the base follow cap in _step_car
const FOLLOW_DECEL: float = 6.0 # m/s^2 the closing speed is shaped by
const GAP_RECOVERY: float = 1.5 # 1/s: how fast an undersized gap is reopened

## Preferred center-to-center spacing in sim meters. The world sets this and
## contact_gap_m from the car length and the sim-to-ribbon distance scale.
var min_gap_m: float = 5.4

## Center-to-center distance (sim meters) at which the car bodies touch.
var contact_gap_m: float = 4.7

var _before_total: PackedFloat64Array = PackedFloat64Array()


## Base pass picks the nearest car ahead whatever its lane (kept for slipstream
## and dirty air); this re-points the follow fields at the nearest car that
## actually blocks the lane.
func _update_traffic() -> void:
	super()
	if _finished_count >= cars.size() - 1:
		return # base skips the sort when fewer than two cars are running
	for position: int in range(1, _order.size()):
		var car: CarStateScript = cars[_order[position]]
		if car.is_finished:
			continue
		var blocker_index: int = -1
		for ahead_position: int in range(position - 1, -1, -1):
			var ahead: CarStateScript = cars[_order[ahead_position]]
			if ahead.total_distance - car.total_distance >= FOLLOW_RANGE_M:
				break
			if absf(ahead.lane_position - car.lane_position) < LANE_CLEARANCE:
				blocker_index = _order[ahead_position]
				break
		if blocker_index < 0:
			car.ahead_index = -1
			car.gap_ahead_m = 9999.0
			car.ahead_speed_mps = 0.0
			car.ahead_lane_position = 1.0
		else:
			var blocker: CarStateScript = cars[blocker_index]
			car.ahead_index = blocker_index
			car.gap_ahead_m = blocker.total_distance - car.total_distance
			car.ahead_speed_mps = blocker.speed_mps
			car.ahead_lane_position = blocker.lane_position


func _step_car(car: CarStateScript, dt: float, update_tires: bool, tire_dt: float) -> void:
	if car.ahead_index < 0:
		super(car, dt, update_tires, tire_dt)
		return
	var old_speed: float = car.speed_mps
	var safe_speed: float = car.ahead_speed_mps + _allowed_closing_speed(car.gap_ahead_m)
	var floor_speed: float = old_speed - MAX_BRAKE_MPS2 * dt
	# Clamp before the base step so the position advances at the safe speed, and
	# after it so acceleration cannot push the car back over the limit.
	car.speed_mps = maxf(minf(old_speed, safe_speed), floor_speed)
	super(car, dt, update_tires, tire_dt)
	car.speed_mps = maxf(minf(car.speed_mps, safe_speed), floor_speed)


## Closing speed from which the car can still stop at min_gap_m with
## FOLLOW_DECEL; negative inside min_gap_m so the gap reopens.
func _allowed_closing_speed(gap_m: float) -> float:
	if gap_m <= min_gap_m:
		return (gap_m - min_gap_m) * GAP_RECOVERY
	return sqrt(2.0 * FOLLOW_DECEL * (gap_m - min_gap_m))


func _update_lane(car: CarStateScript, dt: float) -> void:
	var held: float = car.lane_position
	super(car, dt)
	if car.lane_position != held and _lane_blocked(car, held):
		car.lane_position = held
		car.lane_offset_m = (held - 1.0) * LANE_OFFSET_M


## True when moving `car` from `held` to its new lane_position brings it into a
## lane shared with a car it is too close to, or is closing on faster than the
## follower can shed.
func _lane_blocked(car: CarStateScript, held: float) -> bool:
	for other: CarStateScript in cars:
		if other == car or other.is_finished:
			continue
		var lateral: float = absf(other.lane_position - car.lane_position)
		# Moving apart is always allowed, so two cars in conflict can still separate.
		if lateral >= LANE_CLEARANCE or lateral >= absf(other.lane_position - held):
			continue
		var gap: float = other.total_distance - car.total_distance
		if absf(gap) >= 2.0 * FOLLOW_RANGE_M:
			continue
		var closing: float = (car.speed_mps - other.speed_mps) if gap > 0.0 else (other.speed_mps - car.speed_mps)
		if absf(gap) < min_gap_m or closing > _allowed_closing_speed(absf(gap)):
			return true
	return false


func _step_tick() -> void:
	_before_total.resize(cars.size())
	for i: int in range(cars.size()):
		_before_total[i] = cars[i].total_distance
	super()
	_enforce_contact_gap()


## Last resort behind the soft rules: a car whose body would overlap the car
## ahead in its lane is held where it was, never moved backward, and slowed to
## that car's speed. Skipped on a tick where the car crossed a lap line so a
## lap is never counted twice.
func _enforce_contact_gap() -> void:
	if _finished_count >= cars.size() - 1:
		return
	_sort_order_by_progress(_order.size())
	for position: int in range(1, _order.size()):
		var index: int = _order[position]
		var car: CarStateScript = cars[index]
		if car.is_finished:
			continue
		for ahead_position: int in range(position - 1, -1, -1):
			var ahead: CarStateScript = cars[_order[ahead_position]]
			var gap: float = ahead.total_distance - car.total_distance
			if gap >= contact_gap_m:
				break
			if ahead.is_finished or absf(ahead.lane_position - car.lane_position) >= LANE_CLEARANCE:
				continue
			var held: float = maxf(ahead.total_distance - contact_gap_m, _before_total[index])
			if held < car.total_distance and floorf(held / track_length_m) == floorf(car.total_distance / track_length_m):
				car.total_distance = held
				car.spline_distance = fposmod(held, track_length_m)
				_advance_segment(car)
				car.speed_mps = minf(car.speed_mps, ahead.speed_mps)
			break

