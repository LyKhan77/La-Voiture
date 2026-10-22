class_name AIRaceDirector
extends RefCounted

## Pit-wall brain for the rival cars (PRD 05 AI decision tree) plus the pit lane
## that serves every box request, the player's included. Strategy is evaluated on
## a fixed tick cadence; pit lane movement runs every tick. Neither touches
## the engine's maths: the director only sets `box_requested`, the pace/engine
## modes and, inside the pit lane, a speed cap.

signal pit_requested(car_id: int, compound: int, reason: String)
signal pit_completed(car_id: int, compound: int)

const WeatherScript := preload("res://scripts/core/weather_manager.gd")
const SafetyCarScript := preload("res://scripts/core/safety_car_director.gd")
const TireModelScript := preload("res://scripts/core/tire_model.gd")
const CarStateScript := preload("res://scripts/core/car_state.gd")

const REASON_WEATHER_WET: String = "WEATHER_WET"
const REASON_WEATHER_SLICK: String = "WEATHER_SLICK"
const REASON_TIRE_CLIFF: String = "TIRE_CLIFF"
const REASON_LOW_FUEL: String = "LOW_FUEL"
const REASON_SAFETY_CAR: String = "SAFETY_CAR_PIT"
const REASON_UNDERCUT: String = "UNDERCUT"

## Cars 0 and 1 are the player's team; everyone else is a rival.
const PLAYER_CAR_COUNT: int = 2
const EVAL_INTERVAL_TICKS: int = 30

const TIRE_CLIFF_WEAR: float = 0.22
const UNDERCUT_GAP_S: float = 1.8
const UNDERCUT_OPPONENT_WEAR: float = 0.45
## An undercut may pull a stop forward by up to this many laps of tire life.
const UNDERCUT_WINDOW_LAPS: float = 2.0
const CHEAP_PIT_WEAR: float = 0.60
const HARD_STINT_MIN_LAPS: int = 25
const NO_PIT_LAPS_LEFT: int = 1
const LOW_FUEL_KG: float = 5.0
## Optional stops (undercut, cheap safety car stop) wait until the right tire is settled:
## dry enough for slicks, or wet enough that wets will last. In between, the weather
## crossover is about to flip the choice and a stop would be wasted.
const OPTIONAL_STOP_MIN_WET_MM: float = 0.6
const HOT_TIRE_C: float = 105.0
const COOLED_TIRE_C: float = 98.0
const POST_PIT_PUSH_LAPS: int = 2

## Pit lane sits after the start/finish line. Pack speed matters: the slower the
## field is running, the less a stop costs (see estimate_pit_loss_s).
const PIT_LANE_M: float = 500.0
const PIT_LANE_SPEED_MPS: float = 80.0 / 3.6
const PIT_STOP_S: float = 2.8
const PIT_DECEL_MPS2: float = 25.0

var engine: RaceSimEngine
var weather: WeatherScript
var safety_car: SafetyCarScript
var pit_stops_completed: int = 0

var _rivals: Array[CarStateScript] = []
var _plan: Dictionary = {} # car_id -> compound chosen when the box was requested
var _pit: Dictionary = {} # car_id -> pit lane progress
var _push_until_lap: Dictionary = {} # car_id -> laps_completed that ends the post-pit push
var _overheated: Dictionary = {} # car_id -> bool, with hysteresis
var _prev_spline: PackedFloat64Array = PackedFloat64Array()


func _init(p_engine: RaceSimEngine, p_weather: WeatherScript = null, p_safety_car: SafetyCarScript = null) -> void:
	engine = p_engine
	weather = p_weather
	safety_car = p_safety_car


## Time lost by a stop relative to a field running at `pack_speed_mps`.
static func estimate_pit_loss_s(pack_speed_mps: float) -> float:
	return PIT_LANE_M * (1.0 / PIT_LANE_SPEED_MPS - 1.0 / maxf(pack_speed_mps, PIT_LANE_SPEED_MPS)) + PIT_STOP_S


func get_rival_cars() -> Array[CarStateScript]:
	if _rivals.size() + mini(PLAYER_CAR_COUNT, engine.cars.size()) != engine.cars.size():
		_rivals.clear()
		for car: CarStateScript in engine.cars:
			if car.car_id >= PLAYER_CAR_COUNT:
				_rivals.append(car)
	return _rivals


## Compound the car will take at its next stop.
func get_next_compound(car: CarStateScript) -> int:
	return int(_plan.get(car.car_id, _compound_for_conditions(car)))


## Call once after every engine tick.
func on_tick() -> void:
	_service_pits()
	if engine.tick_count % EVAL_INTERVAL_TICKS != 0:
		return
	for car: CarStateScript in get_rival_cars():
		evaluate_car_strategy(car)


## One pass of the decision tree. Returns the reason for a new box request, or
## "" when the car stays out (engine/pace modes may still change).
func evaluate_car_strategy(car: CarStateScript) -> String:
	if car.is_finished or car.is_in_pit or car.box_requested:
		return ""
	if engine.total_laps - car.laps_completed <= NO_PIT_LAPS_LEFT:
		return ""
	var wetness_mm: float = weather.weather_wetness_mm if weather != null else 0.0
	var on_wets: bool = car.tire.compound == TireModelScript.Compound.WET
	var wear: float = car.tire.get_average_wear()

	# Weather crossover window; the gap between the two thresholds is deliberate
	# hysteresis so a car never flips tires on a drizzle.
	if wetness_mm > WeatherScript.WET_CROSSOVER_MM and not on_wets:
		return _request_pit(car, TireModelScript.Compound.WET, REASON_WEATHER_WET)
	if wetness_mm < WeatherScript.DRY_CROSSOVER_MM and on_wets:
		return _request_pit(car, _pick_slick(car), REASON_WEATHER_SLICK)
	if wear < TIRE_CLIFF_WEAR:
		return _request_pit(car, _compound_for_conditions(car), REASON_TIRE_CLIFF)
	if car.fuel.remaining_kg < LOW_FUEL_KG:
		return _request_pit(car, _compound_for_conditions(car), REASON_LOW_FUEL)
	var settled: bool = wetness_mm < WeatherScript.DRY_CROSSOVER_MM or wetness_mm >= OPTIONAL_STOP_MIN_WET_MM
	# Neutralized field: the pit lane is cheap, so worn tires come in now.
	if settled and safety_car != null and safety_car.is_active and wear < CHEAP_PIT_WEAR:
		return _request_pit(car, _compound_for_conditions(car), REASON_SAFETY_CAR)
	if settled and _should_undercut(car):
		return _request_pit(car, _compound_for_conditions(car), REASON_UNDERCUT)

	_manage_modes(car)
	return ""


## Laps of tire life left before the cliff, at the compound's nominal wear rate.
func get_laps_to_cliff(car: CarStateScript) -> float:
	var rate: float = TireModelScript.WEAR_PER_LAP_DRY[car.tire.compound]
	return (car.tire.get_average_wear() - TIRE_CLIFF_WEAR) / rate


func _should_undercut(car: CarStateScript) -> bool:
	if car.ahead_index < 0 or car.gap_ahead_s >= UNDERCUT_GAP_S:
		return false
	var ahead: CarStateScript = engine.cars[car.ahead_index]
	return (
		ahead.tire.get_average_wear() < UNDERCUT_OPPONENT_WEAR
		and get_laps_to_cliff(car) <= UNDERCUT_WINDOW_LAPS
	)


## `PaceMode.PUSH` / `ECO` in the PRD map to EngineMode.PUSH / ECO here (PaceMode
## has no such members); a hot tire also drops to CONSERVE because only the pace
## mode cools the rubber, and a chase attacks.
func _manage_modes(car: CarStateScript) -> void:
	var temp_c: float = car.tire.get_average_temp()
	var hot: bool = bool(_overheated.get(car.car_id, false))
	if temp_c > HOT_TIRE_C:
		hot = true
	elif temp_c < COOLED_TIRE_C:
		hot = false
	_overheated[car.car_id] = hot
	if hot:
		car.engine_mode = CarStateScript.EngineMode.ECO
		car.pace_mode = CarStateScript.PaceMode.CONSERVE
	elif car.fuel.remaining_kg < LOW_FUEL_KG:
		car.engine_mode = CarStateScript.EngineMode.ECO
		car.pace_mode = CarStateScript.PaceMode.STANDARD
	elif (car.ahead_index >= 0 and car.gap_ahead_s < UNDERCUT_GAP_S) or car.laps_completed < int(_push_until_lap.get(car.car_id, -1)):
		car.engine_mode = CarStateScript.EngineMode.PUSH
		car.pace_mode = CarStateScript.PaceMode.ATTACK
	else:
		car.engine_mode = CarStateScript.EngineMode.STANDARD
		car.pace_mode = CarStateScript.PaceMode.STANDARD


func _request_pit(car: CarStateScript, compound: int, reason: String) -> String:
	car.box_requested = true
	_plan[car.car_id] = compound
	pit_requested.emit(car.car_id, compound, reason)
	return reason


func _compound_for_conditions(car: CarStateScript) -> int:
	var wetness_mm: float = weather.weather_wetness_mm if weather != null else 0.0
	var on_wets: bool = car.tire.compound == TireModelScript.Compound.WET
	if wetness_mm > WeatherScript.WET_CROSSOVER_MM or (on_wets and wetness_mm >= WeatherScript.DRY_CROSSOVER_MM):
		return TireModelScript.Compound.WET
	return _pick_slick(car)


func _pick_slick(car: CarStateScript) -> int:
	if engine.total_laps - car.laps_completed >= HARD_STINT_MIN_LAPS:
		return TireModelScript.Compound.HARD
	return TireModelScript.Compound.MEDIUM


# --- Pit lane -------------------------------------------------------------

func _service_pits() -> void:
	if _prev_spline.size() != engine.cars.size():
		_prev_spline.resize(engine.cars.size())
		for index: int in range(engine.cars.size()):
			_prev_spline[index] = engine.cars[index].spline_distance
	for index: int in range(engine.cars.size()):
		var car: CarStateScript = engine.cars[index]
		var crossed_line: bool = car.spline_distance < _prev_spline[index]
		_prev_spline[index] = car.spline_distance
		if car.is_finished:
			continue
		if car.is_in_pit:
			_step_pit(car, engine.TICK_DT)
		elif car.box_requested and crossed_line:
			car.is_in_pit = true
			_pit[car.car_id] = {"lane_left_m": PIT_LANE_M, "stop_left_s": PIT_STOP_S, "serviced": false, "limit": car.speed_mps}


func _step_pit(car: CarStateScript, dt: float) -> void:
	var lane: Dictionary = _pit[car.car_id]
	if not lane["serviced"] and float(lane["lane_left_m"]) <= PIT_LANE_M * 0.5:
		car.speed_mps = 0.0
		lane["stop_left_s"] = float(lane["stop_left_s"]) - dt
		if float(lane["stop_left_s"]) <= 0.0:
			_service_car(car)
			lane["serviced"] = true
		return
	lane["limit"] = maxf(PIT_LANE_SPEED_MPS, float(lane["limit"]) - PIT_DECEL_MPS2 * dt)
	car.speed_mps = minf(car.speed_mps, float(lane["limit"]))
	lane["lane_left_m"] = float(lane["lane_left_m"]) - car.speed_mps * dt
	if float(lane["lane_left_m"]) <= 0.0:
		car.is_in_pit = false
		car.box_requested = false
		_pit.erase(car.car_id)
		_plan.erase(car.car_id)
		_push_until_lap[car.car_id] = car.laps_completed + POST_PIT_PUSH_LAPS
		pit_stops_completed += 1
		pit_completed.emit(car.car_id, car.tire.compound)


func _service_car(car: CarStateScript) -> void:
	var compound: int = get_next_compound(car)
	car.tire = TireModelScript.new(compound)
	car.tire.track_wetness_mm = weather.get_lane_wetness_mm(roundi(car.lane_position)) if weather != null else 0.0
	car.tire.ambient_temp_c = engine.ambient_temp_c
	car.tire_compound = compound
	car.fuel.refuel(car.fuel.max_fuel_kg)
