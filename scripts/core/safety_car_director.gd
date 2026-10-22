class_name SafetyCarDirector
extends RefCounted

## Safety Car / VSC (PRD 05). The safety car itself is virtual: the leader is
## paced under the 120 km/h limit and every follower closes up on the car ahead.
## It acts after each sim tick by capping `car.speed_mps`, so it works on the base
## point-mass engine and on TrafficRaceSim alike without touching either.

signal deployed(reason: String)
signal withdrawn

enum RaceFlag { GREEN, YELLOW_FLAG }

const WeatherScript := preload("res://scripts/core/weather_manager.gd")

const REASON_STORM: String = "EXTREME RAIN"
const REASON_INCIDENT: String = "INCIDENT"

const SPEED_LIMIT_KMH: float = 120.0
const SPEED_LIMIT_MPS: float = SPEED_LIMIT_KMH / 3.6
## Safety car pace: the leader crawls well under the limit so the pack behind can close
## up at up to the limit (120 km/h) minus this pace.
const LEADER_PACE_FRACTION: float = 0.75
## Center-to-center spacing the pack closes up to, and the floor it never goes under.
const TARGET_GAP_M: float = 14.0
const MIN_GAP_M: float = 7.0
const CLOSE_DECEL_MPS2: float = 3.0 # shapes the closing speed so the gap settles at TARGET_GAP_M
const REOPEN_RATE: float = 1.5 # 1/s: how fast an undersized gap is reopened
const SLOW_DECEL_MPS2: float = 30.0 # how fast a car may be forced down to its cap (< MAX_BRAKE_MPS2)
const MIN_DURATION_S: float = 120.0
const STORM_CLEAR_MM: float = 2.4

var engine: RaceSimEngine
var weather: WeatherScript
var is_active: bool = false
var race_flag: int = RaceFlag.GREEN
var reason: String = ""
var active_time_s: float = 0.0

var _limit: Dictionary = {} # car_id -> speed cap currently applied
var _order: Array[CarState] = []


func _init(p_engine: RaceSimEngine, p_weather: WeatherScript = null) -> void:
	engine = p_engine
	weather = p_weather


func is_overtaking_allowed() -> bool:
	return not is_active


func deploy(p_reason: String) -> void:
	if is_active:
		return
	is_active = true
	race_flag = RaceFlag.YELLOW_FLAG
	reason = p_reason
	active_time_s = 0.0
	_limit.clear()
	for car: CarState in engine.cars:
		_limit[car.car_id] = car.speed_mps
	deployed.emit(p_reason)


func withdraw() -> void:
	if not is_active:
		return
	is_active = false
	race_flag = RaceFlag.GREEN
	reason = ""
	withdrawn.emit()


## Race incident (crash, stranded car). Restarts the neutralization clock when
## the safety car is already out.
func report_incident(car_id: int) -> void:
	if is_active:
		active_time_s = 0.0
	else:
		deploy("%s CAR #%02d" % [REASON_INCIDENT, car_id + 1])


## Call once after every engine tick.
func on_tick() -> void:
	var storm: bool = weather != null and weather.weather_wetness_mm > WeatherScript.STORM_WETNESS_MM
	if not is_active:
		if storm:
			deploy(REASON_STORM)
		return
	active_time_s += engine.TICK_DT
	var storm_holding: bool = weather != null and weather.weather_wetness_mm > STORM_CLEAR_MM
	if active_time_s >= MIN_DURATION_S and not storm_holding:
		withdraw()
		return
	_enforce()


func _enforce() -> void:
	_order.clear()
	for car: CarState in engine.cars:
		# Pit lane is parallel to the track and has its own, lower limit.
		if not car.is_finished and not car.is_in_pit:
			_order.append(car)
	_order.sort_custom(_ahead_first)
	for index: int in range(_order.size()):
		var car: CarState = _order[index]
		var cap: float = SPEED_LIMIT_MPS * LEADER_PACE_FRACTION
		if index > 0:
			var ahead: CarState = _order[index - 1]
			cap = minf(_follow_cap(ahead.total_distance - car.total_distance, ahead.speed_mps), SPEED_LIMIT_MPS)
		cap = maxf(cap, 0.0)
		var applied: float = maxf(cap, float(_limit.get(car.car_id, car.speed_mps)) - SLOW_DECEL_MPS2 * engine.TICK_DT)
		_limit[car.car_id] = applied
		car.speed_mps = minf(car.speed_mps, applied)
		car.lane_target = 1 # single file: no lane for a pass


## Fastest speed that still lets the car stop at TARGET_GAP_M; negative-going
## inside MIN_GAP_M so the gap reopens.
func _follow_cap(gap_m: float, ahead_speed: float) -> float:
	if gap_m <= MIN_GAP_M:
		return ahead_speed - (MIN_GAP_M - gap_m) * REOPEN_RATE
	if gap_m <= TARGET_GAP_M:
		return ahead_speed
	return ahead_speed + sqrt(2.0 * CLOSE_DECEL_MPS2 * (gap_m - TARGET_GAP_M))


func _ahead_first(a: CarState, b: CarState) -> bool:
	if a.total_distance == b.total_distance:
		return a.car_id < b.car_id
	return a.total_distance > b.total_distance
