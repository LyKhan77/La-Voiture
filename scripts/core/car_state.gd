class_name CarState
extends RefCounted

## Live telemetry state for one car. Pure data + timing; all integration is
## performed by RaceSimEngine.

const TireModelScript := preload("res://scripts/core/tire_model.gd")
const FuelModelScript := preload("res://scripts/core/fuel_model.gd")

enum PaceMode { CONSERVE, STANDARD, ATTACK }
enum EngineMode { ECO, STANDARD, PUSH }

const MINI_SECTOR_COUNT: int = 12
const SECTOR_COUNT: int = 3
const MINI_SECTORS_PER_SECTOR: int = 4
const PACE_MODE_NAMES: Array[String] = ["CONSERVE", "STANDARD", "ATTACK"]
const ENGINE_MODE_NAMES: Array[String] = ["ECO", "STANDARD", "PUSH"]

var car_id: int = 0
var team_id: int = 0
var driver_name: String = "Driver"
var driver_skill: float = 1.0

# Track position.
var spline_distance: float = 0.0
var total_distance: float = 0.0
var segment_index: int = 0

# Lanes: 0 = inside, 1 = racing line, 2 = outside.
var current_lane: int = 1
var lane_target: int = 1
var lane_position: float = 1.0
var lane_offset_m: float = 0.0

var speed_mps: float = 0.0
var lap_number: int = 0
var laps_completed: int = 0
var sector_index: int = 0
var mini_sector_index: int = 0

var last_lap_time: float = 0.0
var best_lap_time: float = 0.0
var lap_start_time: float = 0.0
var finish_time: float = 0.0
var finish_position: int = 0
var lap_times: Array[float] = []

var sector_times: PackedFloat64Array = PackedFloat64Array()
var mini_sector_times: PackedFloat64Array = PackedFloat64Array()
var mini_sector_best: PackedFloat64Array = PackedFloat64Array()
var mini_sector_deltas: PackedFloat64Array = PackedFloat64Array()
var last_lap_sector_times: PackedFloat64Array = PackedFloat64Array()
var last_lap_mini_sector_times: PackedFloat64Array = PackedFloat64Array()
var mini_sector_start_time: float = 0.0
var last_mini_sector_delta: float = 0.0
var last_mini_sector_status: String = "NONE"

var tire_compound: int = 0
var tire: TireModelScript
var fuel: FuelModelScript

# PRD data contract exposes these names directly; they proxy the sub-models.
var tire_wear: PackedFloat64Array:
	get:
		return tire.wear
var tire_temps: PackedFloat64Array:
	get:
		return tire.surface_temp_c
var fuel_remaining_kg: float:
	get:
		return fuel.remaining_kg
	set(value):
		fuel.remaining_kg = clampf(value, 0.0, fuel.max_fuel_kg)

var ers_battery_pct: float = 1.0
var pace_mode: int = PaceMode.STANDARD
var engine_mode: int = EngineMode.STANDARD
var is_in_pit: bool = false
var box_requested: bool = false

var has_started_lap: bool = false
var is_finished: bool = false
var is_out_of_fuel: bool = false

# Traffic snapshot, refreshed by RaceSimEngine every tick.
var gap_ahead_m: float = 9999.0
var gap_ahead_s: float = 9999.0
var ahead_index: int = -1
var ahead_speed_mps: float = 0.0
var ahead_lane_position: float = 1.0
var drag_multiplier: float = 1.0
var dirty_air_factor: float = 1.0
var cached_top_speed: float = 0.0
var cached_power_w: float = -1.0
var cached_drag_coeff: float = -1.0


func _init(
	p_car_id: int = 0,
	p_team_id: int = 0,
	p_driver_name: String = "Driver",
	p_compound: int = 0
) -> void:
	car_id = p_car_id
	team_id = p_team_id
	driver_name = p_driver_name
	tire_compound = p_compound
	tire = TireModelScript.new(p_compound)
	fuel = FuelModelScript.new()
	mini_sector_times.resize(MINI_SECTOR_COUNT)
	mini_sector_times.fill(-1.0)
	mini_sector_best.resize(MINI_SECTOR_COUNT)
	mini_sector_best.fill(INF)
	mini_sector_deltas.resize(MINI_SECTOR_COUNT)
	mini_sector_deltas.fill(0.0)
	sector_times.resize(SECTOR_COUNT)
	sector_times.fill(-1.0)
	last_lap_mini_sector_times.resize(MINI_SECTOR_COUNT)
	last_lap_mini_sector_times.fill(-1.0)
	last_lap_sector_times.resize(SECTOR_COUNT)
	last_lap_sector_times.fill(-1.0)


func begin_lap(p_race_time: float) -> void:
	lap_start_time = p_race_time
	mini_sector_start_time = p_race_time
	mini_sector_index = 0
	sector_index = 0
	mini_sector_times.fill(-1.0)
	mini_sector_deltas.fill(0.0)
	sector_times.fill(-1.0)


func finish_lap(p_race_time: float) -> float:
	var lap_time: float = p_race_time - lap_start_time
	last_lap_time = lap_time
	lap_times.append(lap_time)
	if best_lap_time <= 0.0 or lap_time < best_lap_time:
		best_lap_time = lap_time
	laps_completed += 1
	last_lap_mini_sector_times = mini_sector_times.duplicate()
	last_lap_sector_times = sector_times.duplicate()
	return lap_time


## Records a completed mini-sector. `session_best_before` is the class best
## for that mini-sector before this car's time was applied.
func record_mini_sector(index: int, time: float, session_best_before: float) -> void:
	if index < 0 or index >= MINI_SECTOR_COUNT:
		return
	var personal_best_before: float = mini_sector_best[index]
	var status: String = "WHITE"
	var delta: float = 0.0
	if session_best_before == INF or time < session_best_before:
		status = "PURPLE"
		delta = 0.0
	elif time < personal_best_before:
		status = "GREEN"
		delta = time - session_best_before
	else:
		status = "WHITE"
		delta = time - session_best_before

	mini_sector_times[index] = time
	mini_sector_deltas[index] = delta
	last_mini_sector_delta = delta
	last_mini_sector_status = status
	if personal_best_before == INF or time < personal_best_before:
		mini_sector_best[index] = time

	var sector: int = int(float(index) / float(MINI_SECTORS_PER_SECTOR))
	sector_index = sector
	if (index + 1) % MINI_SECTORS_PER_SECTOR == 0:
		var total: float = 0.0
		var first: int = sector * MINI_SECTORS_PER_SECTOR
		for offset: int in range(MINI_SECTORS_PER_SECTOR):
			var value: float = mini_sector_times[first + offset]
			if value >= 0.0:
				total += value
		sector_times[sector] = total


func get_compound_name() -> String:
	return tire.get_compound_name()


func get_pace_mode_name() -> String:
	return PACE_MODE_NAMES[clampi(pace_mode, 0, PACE_MODE_NAMES.size() - 1)]


func get_engine_mode_name() -> String:
	return ENGINE_MODE_NAMES[clampi(engine_mode, 0, ENGINE_MODE_NAMES.size() - 1)]


func get_speed_kmh() -> float:
	return speed_mps * 3.6


func get_telemetry() -> Dictionary:
	return {
		"car_id": car_id,
		"team_id": team_id,
		"driver_name": driver_name,
		"driver_skill": driver_skill,
		"spline_distance": spline_distance,
		"total_distance": total_distance,
		"segment_index": segment_index,
		"current_lane": current_lane,
		"lane_target": lane_target,
		"lane_position": lane_position,
		"lane_offset_m": lane_offset_m,
		"speed_mps": speed_mps,
		"speed_kmh": get_speed_kmh(),
		"lap_number": lap_number,
		"laps_completed": laps_completed,
		"sector_index": sector_index,
		"mini_sector_index": mini_sector_index,
		"last_lap_time": last_lap_time,
		"best_lap_time": best_lap_time,
		"lap_times": lap_times.duplicate(),
		"sector_times": sector_times.duplicate(),
		"mini_sector_times": mini_sector_times.duplicate(),
		"mini_sector_best": mini_sector_best.duplicate(),
		"mini_sector_deltas": mini_sector_deltas.duplicate(),
		"last_mini_sector_delta": last_mini_sector_delta,
		"last_mini_sector_status": last_mini_sector_status,
		"tire_compound": tire_compound,
		"tire_compound_name": tire.get_compound_name(),
		"tire_wear": tire.wear.duplicate(),
		"tire_temps": tire.surface_temp_c.duplicate(),
		"tire_inner_temps": tire.inner_temp_c.duplicate(),
		"fuel_remaining_kg": fuel.remaining_kg,
		"fuel_weight_penalty_s": fuel.get_weight_penalty_seconds(),
		"ers_battery_pct": ers_battery_pct,
		"pace_mode": pace_mode,
		"pace_mode_name": get_pace_mode_name(),
		"engine_mode": engine_mode,
		"engine_mode_name": get_engine_mode_name(),
		"is_in_pit": is_in_pit,
		"box_requested": box_requested,
		"has_started_lap": has_started_lap,
		"is_finished": is_finished,
		"is_out_of_fuel": is_out_of_fuel,
		"finish_time": finish_time,
		"finish_position": finish_position,
		"gap_ahead_m": gap_ahead_m,
		"gap_ahead_s": gap_ahead_s,
		"drag_multiplier": drag_multiplier,
		"dirty_air_factor": dirty_air_factor,
	}
