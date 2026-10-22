class_name FuelModel
extends RefCounted

## Fuel mass model. Consumption is expressed per nominal lap and converted to
## a per-second rate; the PRD mass penalty is +0.15 s per +10 kg.

enum EngineMode { ECO, STANDARD, PUSH }

const ENGINE_MODE_NAMES: Array[String] = ["ECO", "STANDARD", "PUSH"]
const WEIGHT_PENALTY_SECONDS_PER_10KG: float = 0.15
const DEFAULT_MAX_FUEL_KG: float = 65.0
const DEFAULT_CONSUMPTION_KG_PER_LAP: float = 2.0
const REFERENCE_LAP_TIME_S: float = 105.0

var remaining_kg: float = DEFAULT_MAX_FUEL_KG
var max_fuel_kg: float = DEFAULT_MAX_FUEL_KG
var base_consumption_kg_per_lap: float = DEFAULT_CONSUMPTION_KG_PER_LAP
var reference_lap_time_s: float = REFERENCE_LAP_TIME_S
var last_burn_kg: float = 0.0


func _init(p_max_fuel_kg: float = DEFAULT_MAX_FUEL_KG) -> void:
	max_fuel_kg = maxf(1.0, p_max_fuel_kg)
	remaining_kg = max_fuel_kg


## Returns kilograms consumed this step.
func burn(dt: float, throttle_input: float, engine_mode: int) -> float:
	if dt <= 0.0 or remaining_kg <= 0.0:
		last_burn_kg = 0.0
		return 0.0
	var power_factor: float = 0.55 + 0.45 * clampf(throttle_input, 0.0, 1.10)
	var engine_multiplier: float = 1.0
	match engine_mode:
		EngineMode.ECO:
			engine_multiplier = 0.85
		EngineMode.PUSH:
			engine_multiplier = 1.15
	var rate_kg_per_sec: float = (
		base_consumption_kg_per_lap / reference_lap_time_s * power_factor * engine_multiplier
	)
	var consumed: float = minf(rate_kg_per_sec * dt, remaining_kg)
	remaining_kg -= consumed
	last_burn_kg = consumed
	return consumed


static func weight_penalty_seconds_for_mass(mass_kg: float) -> float:
	return (maxf(0.0, mass_kg) / 10.0) * WEIGHT_PENALTY_SECONDS_PER_10KG


func get_weight_penalty_seconds() -> float:
	return weight_penalty_seconds_for_mass(remaining_kg)


## Estimated lap-time multiplier caused by the fuel mass penalty.
func get_lap_time_scale() -> float:
	return 1.0 / (1.0 + get_weight_penalty_seconds() / reference_lap_time_s)


func refuel(amount_kg: float) -> float:
	var before: float = remaining_kg
	remaining_kg = clampf(remaining_kg + amount_kg, 0.0, max_fuel_kg)
	return remaining_kg - before


func get_engine_mode_name(engine_mode: int) -> String:
	return ENGINE_MODE_NAMES[clampi(engine_mode, 0, ENGINE_MODE_NAMES.size() - 1)]


func get_telemetry() -> Dictionary:
	return {
		"remaining_kg": remaining_kg,
		"max_fuel_kg": max_fuel_kg,
		"weight_penalty_s": get_weight_penalty_seconds(),
		"last_burn_kg": last_burn_kg,
	}
