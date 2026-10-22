class_name TireModel
extends RefCounted

## Four-corner tire model (FL, FR, RL, RR).
## `wear` is remaining condition: 1.0 = new, 0.0 = fully worn.
## Compound data follows PRD 01 section 4.2.

enum Compound { SOFT, MEDIUM, HARD, WET }
enum Corner { FL, FR, RL, RR }

const CORNER_COUNT: int = 4
const COMPOUND_COUNT: int = 4
const REFERENCE_LAP_TIME_S: float = 105.0

const CORNER_NAMES: Array[String] = ["FL", "FR", "RL", "RR"]
const COMPOUND_NAMES: Array[String] = ["SOFT", "MEDIUM", "HARD", "WET"]

const BASE_GRIP_DRY: Array[float] = [1.25, 1.15, 1.05, 0.95]
const BASE_GRIP_WET_COMPOUND: float = 1.20
const WEAR_PER_LAP_DRY: Array[float] = [0.0425, 0.025, 0.014, 0.080]
const WEAR_PER_LAP_WET_COMPOUND: float = 0.015
const OPTIMAL_TEMP_CENTER: Array[float] = [102.5, 92.5, 87.5, 67.5]
const CLIFF_THRESHOLD: Array[float] = [0.25, 0.20, 0.15, 0.20]
const COMPOUND_HEAT_OFFSET_C: Array[float] = [0.0, -4.0, -8.0, -10.0]

const BASE_HEAT_C: float = 52.0
const LATERAL_HEAT_C: float = 22.0
const LONGITUDINAL_HEAT_C: float = 6.0
const SPEED_COOLING_C_PER_MPS: float = 0.05
const WET_COOLING_C_PER_MM: float = 25.0
const SURFACE_THERMAL_TAU_S: float = 6.0
const INNER_THERMAL_TAU_S: float = 20.0
const CLIFF_TIME_PENALTY_S: float = 2.5

var compound: int = Compound.SOFT
var wear: PackedFloat64Array = PackedFloat64Array()
var surface_temp_c: PackedFloat64Array = PackedFloat64Array()
var inner_temp_c: PackedFloat64Array = PackedFloat64Array()
var average_wear_cached: float = 1.0
var average_temp_cached: float = 90.0
var track_wetness_mm: float = 0.0
var ambient_temp_c: float = 25.0


func _init(p_compound: int = Compound.SOFT) -> void:
	compound = clampi(p_compound, 0, COMPOUND_COUNT - 1)
	wear.resize(CORNER_COUNT)
	wear.fill(1.0)
	surface_temp_c.resize(CORNER_COUNT)
	surface_temp_c.fill(90.0)
	inner_temp_c.resize(CORNER_COUNT)
	inner_temp_c.fill(82.0)


func calculate_grip(corner: int) -> float:
	if corner < 0 or corner >= CORNER_COUNT:
		return 0.0
	var grip: float = _base_grip()
	grip *= _wear_grip_factor(corner)
	grip *= _temperature_grip_factor(corner)
	grip *= _wet_grip_factor()
	return clampf(grip, 0.05, 1.60)


func get_average_grip() -> float:
	# Hot path (once per car-tick): use the cached corner averages instead of
	# recalculating four independent corner grips.
	var base: float = BASE_GRIP_DRY[compound]
	if compound == Compound.WET:
		base = lerpf(BASE_GRIP_DRY[Compound.WET], BASE_GRIP_WET_COMPOUND, clampf(track_wetness_mm, 0.0, 1.0))
	var wear_factor: float = 0.60 + 0.40 * average_wear_cached
	var threshold: float = CLIFF_THRESHOLD[compound]
	if average_wear_cached < threshold and threshold > 0.0:
		wear_factor -= ((threshold - average_wear_cached) / threshold) * 0.20
	wear_factor = clampf(wear_factor, 0.35, 1.0)
	var temp_deviation: float = absf(average_temp_cached - OPTIMAL_TEMP_CENTER[compound])
	var temp_factor: float = 1.0 - clampf(temp_deviation / 100.0, 0.0, 0.18)
	var wet_factor: float = 1.0
	if compound != Compound.WET:
		wet_factor = 1.0 - clampf(track_wetness_mm * 0.30, 0.0, 0.55)
	return clampf(base * wear_factor * temp_factor * wet_factor, 0.05, 1.60)


func get_axle_grip(front: bool) -> float:
	if front:
		return (calculate_grip(Corner.FL) + calculate_grip(Corner.FR)) * 0.5
	return (calculate_grip(Corner.RL) + calculate_grip(Corner.RR)) * 0.5


func get_average_wear() -> float:
	return average_wear_cached


func get_min_wear() -> float:
	return minf(minf(wear[Corner.FL], wear[Corner.FR]), minf(wear[Corner.RL], wear[Corner.RR]))


func get_average_temp() -> float:
	return average_temp_cached


func get_cliff_time_penalty_seconds() -> float:
	var threshold: float = CLIFF_THRESHOLD[compound]
	var average: float = get_average_wear()
	if threshold <= 0.0 or average >= threshold:
		return 0.0
	return CLIFF_TIME_PENALTY_S * (1.0 - average / threshold)


## dt in seconds, lateral_g in g, turn_dir: +1 right, -1 left, 0 straight.
## longitudinal_g is positive under acceleration and negative under braking.
## pace_mode matches CarState.PaceMode: 0 Conserve, 1 Standard, 2 Attack.
func update_state(
	dt: float,
	speed_mps: float,
	lateral_g: float,
	turn_dir: int,
	longitudinal_g: float,
	pace_mode: int,
	dirty_air_heat_multiplier: float = 1.0
) -> void:
	if dt <= 0.0:
		return

	var lateral: float = clampf(absf(lateral_g), 0.0, 4.0)
	var longitudinal: float = clampf(longitudinal_g, -4.0, 4.0)
	var brake_load: float = maxf(0.0, -longitudinal)
	var traction_load: float = maxf(0.0, longitudinal)

	var pace_wear: float = 1.0
	var pace_heat: float = 0.0
	match pace_mode:
		0:
			pace_wear = 0.60
			pace_heat = -6.0
		2:
			pace_wear = 1.60
			pace_heat = 10.0
		_:
			pace_wear = 1.0
			pace_heat = 0.0

	var wear_per_lap: float = WEAR_PER_LAP_DRY[compound]
	if compound == Compound.WET:
		wear_per_lap = lerpf(0.080, WEAR_PER_LAP_WET_COMPOUND, clampf(track_wetness_mm, 0.0, 1.0))
	else:
		wear_per_lap *= 1.0 + clampf(track_wetness_mm, 0.0, 3.0) * 0.50
	var base_wear_per_sec: float = wear_per_lap / REFERENCE_LAP_TIME_S

	var heat_multiplier: float = maxf(1.0, dirty_air_heat_multiplier)
	var wear_sum: float = 0.0
	var temp_sum: float = 0.0
	for corner: int in range(CORNER_COUNT):
		var is_left_side: bool = corner == Corner.FL or corner == Corner.RL
		var is_outer: bool = (turn_dir > 0 and is_left_side) or (turn_dir < 0 and not is_left_side)
		var lateral_share: float = 0.5
		if turn_dir != 0:
			lateral_share = 0.62 if is_outer else 0.38
		var corner_lateral: float = lateral * lateral_share
		var corner_longitudinal: float = brake_load if corner < 2 else traction_load

		var load_factor: float = 0.75 + 0.35 * corner_lateral + 0.10 * corner_longitudinal
		var temperature_wear: float = 1.0 + clampf(
			(surface_temp_c[corner] - OPTIMAL_TEMP_CENTER[compound]) / 120.0, -0.20, 0.30
		)
		var wear_rate: float = base_wear_per_sec * load_factor * pace_wear * temperature_wear
		wear[corner] = maxf(0.0, wear[corner] - wear_rate * dt)

		var heat_gain: float = BASE_HEAT_C + LATERAL_HEAT_C * corner_lateral + LONGITUDINAL_HEAT_C * corner_longitudinal
		heat_gain *= heat_multiplier
		var target_temp: float = (
			ambient_temp_c
			+ heat_gain
			+ COMPOUND_HEAT_OFFSET_C[compound]
			+ pace_heat
			- speed_mps * SPEED_COOLING_C_PER_MPS
			- track_wetness_mm * WET_COOLING_C_PER_MM
		)
		target_temp = clampf(target_temp, ambient_temp_c, 145.0)
		var surface_alpha: float = clampf(dt / SURFACE_THERMAL_TAU_S, 0.0, 1.0)
		surface_temp_c[corner] = lerpf(surface_temp_c[corner], target_temp, surface_alpha)
		var inner_alpha: float = clampf(dt / INNER_THERMAL_TAU_S, 0.0, 1.0)
		inner_temp_c[corner] = lerpf(inner_temp_c[corner], surface_temp_c[corner], inner_alpha)
		wear_sum += wear[corner]
		temp_sum += surface_temp_c[corner]
	average_wear_cached = wear_sum / float(CORNER_COUNT)
	average_temp_cached = temp_sum / float(CORNER_COUNT)


func get_compound_name() -> String:
	return COMPOUND_NAMES[compound]


func get_corner_name(corner: int) -> String:
	return CORNER_NAMES[clampi(corner, 0, CORNER_COUNT - 1)]


func get_telemetry() -> Dictionary:
	return {
		"compound": compound,
		"compound_name": get_compound_name(),
		"wear": wear.duplicate(),
		"surface_temp_c": surface_temp_c.duplicate(),
		"inner_temp_c": inner_temp_c.duplicate(),
		"average_wear": get_average_wear(),
		"average_temp_c": get_average_temp(),
		"cliff_penalty_s": get_cliff_time_penalty_seconds(),
		"track_wetness_mm": track_wetness_mm,
	}


func _base_grip() -> float:
	if compound == Compound.WET:
		return lerpf(BASE_GRIP_DRY[Compound.WET], BASE_GRIP_WET_COMPOUND, clampf(track_wetness_mm, 0.0, 1.0))
	return BASE_GRIP_DRY[compound]


func _wear_grip_factor(corner: int) -> float:
	var condition: float = wear[corner]
	var factor: float = 0.60 + 0.40 * condition
	var threshold: float = CLIFF_THRESHOLD[compound]
	if condition < threshold and threshold > 0.0:
		factor -= ((threshold - condition) / threshold) * 0.20
	return clampf(factor, 0.35, 1.0)


func _temperature_grip_factor(corner: int) -> float:
	var deviation: float = absf(surface_temp_c[corner] - OPTIMAL_TEMP_CENTER[compound])
	return 1.0 - clampf(deviation / 100.0, 0.0, 0.18)


func _wet_grip_factor() -> float:
	if compound == Compound.WET:
		return 1.0
	return 1.0 - clampf(track_wetness_mm * 0.30, 0.0, 0.55)
