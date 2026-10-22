class_name RaceControl
extends RefCounted

## Ticks weather, safety car and pit-wall AI together with a RaceSimEngine. The
## engine has no per-tick hook and stays untouched, so this owns the stepping
## loop instead: `process_frame()` / `step_ticks()` replace the engine's own and
## advance it one tick at a time, running the directors after every tick. The
## integer tick accumulator is the engine's, so 1x and 16x run the same tick
## sequence.

signal radio(message: String, urgent: bool)

const WeatherScript := preload("res://scripts/core/weather_manager.gd")
const SafetyCarScript := preload("res://scripts/core/safety_car_director.gd")
const AIScript := preload("res://scripts/core/ai_race_director.gd")

## Demo front for the live race: dry start, drizzle, a downpour, then drying.
const DEMO_SCHEDULE: Array[Dictionary] = [
	{"t": 0.0, "state": WeatherScript.WeatherState.DRY},
	{"t": 420.0, "state": WeatherScript.WeatherState.LIGHT_DRIZZLE},
	{"t": 735.0, "state": WeatherScript.WeatherState.HEAVY_DOWNPOUR},
	{"t": 1155.0, "state": WeatherScript.WeatherState.DRYING},
]

var engine: RaceSimEngine
var weather: WeatherScript
var safety_car: SafetyCarScript
var ai: AIScript

var _pending_fp: int = 0
var _reported_incidents: Dictionary = {} # car_id -> true once its stranding was reported
var _lane_traffic: PackedInt32Array = PackedInt32Array([0, 0, 0])


func _init(p_engine: RaceSimEngine) -> void:
	engine = p_engine
	weather = WeatherScript.new()
	weather.ambient_temp_c = engine.ambient_temp_c
	safety_car = SafetyCarScript.new(engine, weather)
	ai = AIScript.new(engine, weather, safety_car)
	weather.radio_callout.connect(_on_callout)
	safety_car.deployed.connect(_on_sc_deployed)
	safety_car.withdrawn.connect(_on_sc_withdrawn)


## Wall-clock frame input, same fixed-point conversion as RaceSimEngine.process_frame.
func process_frame(delta: float) -> void:
	if engine.is_finished or delta <= 0.0:
		return
	_pending_fp += int(round(delta * engine.time_scale * float(engine.TICK_RATE) * engine.TICK_FP_SCALE_F))
	var stepped: int = 0
	while _pending_fp >= engine.TICK_FP_SCALE:
		_pending_fp -= engine.TICK_FP_SCALE
		_step_one()
		stepped += 1
		if engine.is_finished:
			_pending_fp = 0
			return
		if stepped >= engine.MAX_TICKS_PER_FRAME:
			_pending_fp = 0
			return


func step_ticks(count: int) -> void:
	for _index: int in range(count):
		if engine.is_finished:
			return
		_step_one()


func _step_one() -> void:
	engine.step_ticks(1)
	_tick_directors()


func _tick_directors() -> void:
	_lane_traffic.fill(0)
	for car: CarState in engine.cars:
		_lane_traffic[clampi(roundi(car.lane_position), 0, WeatherScript.LANE_COUNT - 1)] += 1
	weather.advance(engine.TICK_DT, _lane_traffic)
	engine.set_weather_wetness(weather.weather_wetness_mm)
	engine.set_ambient_temp(weather.ambient_temp_c)
	for car: CarState in engine.cars:
		car.tire.track_wetness_mm = weather.get_lane_wetness_mm(roundi(car.lane_position))
		# A car stranded on track (out of fuel) is a race incident.
		if car.is_out_of_fuel and not _reported_incidents.has(car.car_id):
			_reported_incidents[car.car_id] = true
			safety_car.report_incident(car.car_id)
	safety_car.on_tick()
	ai.on_tick()


# Method callables rather than lambdas: a lambda would hold `self` and leak the
# RaceControl <-> director reference cycle.
func _on_callout(message: String, urgent: bool) -> void:
	radio.emit(message, urgent)


func _on_sc_deployed(reason: String) -> void:
	radio.emit("SAFETY CAR DEPLOYED (%s) — PIT LANE OPEN, CHEAP STOP!" % reason, true)


func _on_sc_withdrawn() -> void:
	radio.emit("SAFETY CAR IN THIS LAP — GREEN FLAG RACING!", false)


## Snapshot for view layers (pit wall widget, HUD); plain data, no references.
func get_status() -> Dictionary:
	return {
		"state": weather.state,
		"state_name": weather.get_state_name(),
		"wetness_mm": weather.weather_wetness_mm,
		"wetness_pct": weather.get_wetness_pct(),
		"ambient_c": weather.ambient_temp_c,
		"forecast": weather.get_forecast(),
		"safety_car": safety_car.is_active,
		"safety_car_reason": safety_car.reason,
		"race_flag": safety_car.race_flag,
	}
