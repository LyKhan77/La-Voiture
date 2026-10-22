class_name WeatherManager
extends RefCounted

## Deterministic dynamic weather (PRD 05 weather cycle, PRD 01 wetness grip).
## Pure maths: `advance(dt)` is driven by the sim tick, never by the frame rate.
## Water is tracked per lane (0 inside, 1 racing line, 2 outside) so cars that
## run the racing line disperse it faster than the outer lanes.

signal state_changed(old_state: int, new_state: int)
signal radio_callout(message: String, urgent: bool)

enum WeatherState { DRY, LIGHT_DRIZZLE, HEAVY_DOWNPOUR, DRYING }

const STATE_NAMES: Array[String] = ["DRY", "DRIZZLE", "HEAVY RAIN", "DRYING"]
const LANE_COUNT: int = 3
const RACING_LINE_LANE: int = 1

const MAX_WETNESS_MM: float = 3.5
const RAIN_RATE_MM_PER_SEC: Array[float] = [0.0, 0.005, 0.025, 0.0]
## Natural drying. DRY keeps it so a hand-set puddle still disappears.
const EVAPORATION_MM_PER_SEC: Array[float] = [0.003, 0.0, 0.0, 0.003]
const TARGET_AMBIENT_C: Array[float] = [25.0, 21.0, 17.0, 21.0]
const AMBIENT_CHANGE_C_PER_SEC: float = 0.05

## Shared crossover thresholds: the AI pits on them, the dashboard calls them out.
const WET_CROSSOVER_MM: float = 0.35
const DRY_CROSSOVER_MM: float = 0.18
const STORM_WETNESS_MM: float = 2.8
## One lap in the PRD's reference pace, used to turn the schedule into a lap forecast.
const FORECAST_LAP_S: float = 105.0
const FORECAST_LAPS: int = 5

const MSG_WET_CROSSOVER: String = "TRACK WETNESS EXCEEDING 35% — BOX FOR WETS!"
const MSG_FLOODING: String = "BOX THIS LAP — TRACK IS FLOODING!"

var state: int = WeatherState.DRY
var weather_wetness_mm: float = 0.0
var rain_rate_mm_per_sec: float = 0.0
var evaporation_rate_mm_per_sec: float = EVAPORATION_MM_PER_SEC[WeatherState.DRY]
## Cars on the racing line disperse water this many times faster than the outer lanes.
var racing_line_dry_factor: float = 2.0
var ambient_temp_c: float = 25.0
var elapsed_s: float = 0.0
var lane_wetness_mm: PackedFloat64Array = PackedFloat64Array([0.0, 0.0, 0.0])

## Optional timeline: [{"t": seconds, "state": WeatherState}], sorted by "t".
var _schedule: Array[Dictionary] = []
var _wet_alert_armed: bool = true


func set_schedule(entries: Array[Dictionary]) -> void:
	_schedule = entries.duplicate()
	_schedule.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["t"]) < float(b["t"]))


func set_state(new_state: int) -> void:
	new_state = clampi(new_state, 0, WeatherState.size() - 1)
	rain_rate_mm_per_sec = RAIN_RATE_MM_PER_SEC[new_state]
	evaporation_rate_mm_per_sec = EVAPORATION_MM_PER_SEC[new_state]
	if new_state == state:
		return
	var old_state: int = state
	state = new_state
	state_changed.emit(old_state, new_state)
	if new_state == WeatherState.HEAVY_DOWNPOUR:
		radio_callout.emit(MSG_FLOODING, true)


## Hand-sets the water on every lane (scenarios, tests).
func set_wetness_mm(wetness_mm: float) -> void:
	lane_wetness_mm.fill(clampf(wetness_mm, 0.0, MAX_WETNESS_MM))
	weather_wetness_mm = lane_wetness_mm[0]


## `lane_traffic[lane]` > 0 means a car ran that lane this step.
func advance(dt: float, lane_traffic: PackedInt32Array = PackedInt32Array()) -> void:
	if dt <= 0.0:
		return
	elapsed_s += dt
	if not _schedule.is_empty():
		set_state(_scheduled_state_at(elapsed_s))
	var sum: float = 0.0
	for lane: int in range(LANE_COUNT):
		var loss: float = evaporation_rate_mm_per_sec
		if lane == RACING_LINE_LANE and lane < lane_traffic.size() and lane_traffic[lane] > 0:
			loss *= racing_line_dry_factor
		lane_wetness_mm[lane] = clampf(
			lane_wetness_mm[lane] + (rain_rate_mm_per_sec - loss) * dt, 0.0, MAX_WETNESS_MM
		)
		sum += lane_wetness_mm[lane]
	weather_wetness_mm = sum / float(LANE_COUNT)
	if state == WeatherState.DRYING and weather_wetness_mm <= 0.0:
		set_state(WeatherState.DRY)
	ambient_temp_c = move_toward(ambient_temp_c, TARGET_AMBIENT_C[state], AMBIENT_CHANGE_C_PER_SEC * dt)
	_check_wet_callout()


## Wetness a car actually feels in its lane.
func get_lane_wetness_mm(lane: int) -> float:
	return lane_wetness_mm[clampi(lane, 0, LANE_COUNT - 1)]


## 0..1; 1 mm is a fully wet surface for the tire model.
func get_wetness_pct() -> float:
	return clampf(weather_wetness_mm, 0.0, 1.0)


func get_state_name() -> String:
	return STATE_NAMES[state]


## States for the next `count` laps (index 0 = next lap). Without a schedule the
## current state is assumed to hold.
func get_forecast(count: int = FORECAST_LAPS) -> Array[int]:
	var result: Array[int] = []
	for lap_ahead: int in range(1, count + 1):
		if _schedule.is_empty():
			result.append(state)
		else:
			result.append(_scheduled_state_at(elapsed_s + float(lap_ahead) * FORECAST_LAP_S))
	return result


func _scheduled_state_at(time_s: float) -> int:
	var result: int = WeatherState.DRY
	for entry: Dictionary in _schedule:
		if float(entry["t"]) > time_s:
			break
		result = int(entry["state"])
	return result


func _check_wet_callout() -> void:
	if weather_wetness_mm > WET_CROSSOVER_MM and _wet_alert_armed:
		_wet_alert_armed = false
		radio_callout.emit(MSG_WET_CROSSOVER, true)
	elif weather_wetness_mm < DRY_CROSSOVER_MM:
		_wet_alert_armed = true
