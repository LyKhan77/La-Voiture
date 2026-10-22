class_name RaceSimEngine
extends RefCounted

## Deterministic 60 Hz race simulation. Rendering is intentionally absent:
## `process_frame()` converts wall-clock seconds into a fixed number of
## 1/60 s math ticks, so 1x and 16x execute the exact same tick sequence.

signal lap_completed(car_id: int, lap_number: int, lap_time: float)
signal race_finished(classifications: Array)

const CarStateScript := preload("res://scripts/core/car_state.gd")
const TireModelScript := preload("res://scripts/core/tire_model.gd")

const TICK_RATE: int = 60
const TICK_DT: float = 1.0 / 60.0
const TICK_FP_SCALE: int = 1_000_000_000
const TICK_FP_SCALE_F: float = 1_000_000_000.0
const MAX_TICKS_PER_FRAME: int = 120

const TRACK_LENGTH_M: float = 5807.0
const MINI_SECTOR_COUNT: int = 12
const SECTOR_COUNT: int = 3
const MINI_SECTORS_PER_SECTOR: int = 4
const GRID_GAP_M: float = 10.0

const GRAVITY: float = 9.81
const AIR_DENSITY: float = 1.225
const DOWNFORCE_COEFF: float = 0.5 * AIR_DENSITY * 3.2
const DRAG_COEFF: float = 0.5 * AIR_DENSITY * 1.35
const ENGINE_POWER_W: float = 485_000.0
const DRY_MASS_KG: float = 1280.0
const MAX_SPEED_MPS: float = 95.0
const MAX_BRAKE_MPS2: float = 40.0

const LANE_OFFSET_M: float = 2.5
const LANE_CHANGE_RATE: float = 1.4
const SLIPSTREAM_GAP_S: float = 0.8
const DIRTY_AIR_GAP_S: float = 1.0
const SLIPSTREAM_DRAG_MULT: float = 0.70
const DIRTY_AIR_DOWNFORCE_MULT: float = 0.82
const DIRTY_AIR_HEAT_MULT: float = 1.12

## The point-mass model deliberately extracts less than the tire's peak mu.
## A baseline chassis grip plus a compressed compound delta calibrates the
## Soft/Hard lap delta into the PRD's 0.8-1.4 s window without flattening
## absolute lap pace.
const CHASSIS_BASE_GRIP: float = 1.04
const CHASSIS_GRIP_COMPRESSION: float = 0.28

const PACE_THROTTLE: Array[float] = [0.80, 0.95, 1.05]
const PACE_BRAKE_MULT: Array[float] = [0.92, 1.00, 1.05]
const ENGINE_POWER_MULT: Array[float] = [0.92, 1.00, 1.04]

const TEAM_NAMES: Array[String] = [
	"Apex Racing", "Neon Drift", "Kurogane GT", "Vanta Motors", "Razorline",
	"Zero Hour", "Oni Works", "Static Speed", "Chrome Syndicate", "Night Shift",
]
const DRIVER_NAMES: Array[String] = [
	"K. Ryu", "S. Ren", "M. Ito", "A. Vale", "J. Cruz",
	"N. Sato", "L. Moreau", "R. Silva", "T. Kade", "E. Novak",
	"H. Mori", "D. Reyes", "V. Sokol", "P. Aoki", "G. Alves",
	"C. Weiss", "B. Tanaka", "F. Duval", "I. Petrov", "O. Mbeki",
]


class TrackSegment extends RefCounted:
	var start_m: float = 0.0
	var length_m: float = 0.0
	var radius_m: float = 0.0
	var direction: int = 0

	func _init(p_start_m: float, p_length_m: float, p_radius_m: float, p_direction: int) -> void:
		start_m = p_start_m
		length_m = p_length_m
		radius_m = p_radius_m
		direction = p_direction

	func end_m() -> float:
		return start_m + length_m

	func is_straight() -> bool:
		return radius_m <= 0.0


var total_laps: int = 30
var current_lap: int = 0
var time_scale: float = 1.0
var track_length_m: float = TRACK_LENGTH_M
var cars: Array[CarStateScript] = []
var race_time: float = 0.0
var tick_count: int = 0
var weather_wetness_mm: float = 0.0
var ambient_temp_c: float = 25.0
var session_best_lap: float = INF
var is_finished: bool = false
var finish_order: Array[int] = []

var _segments: Array[TrackSegment] = []
var _mini_sector_length_m: float = TRACK_LENGTH_M / float(MINI_SECTOR_COUNT)
var _session_best_mini: PackedFloat64Array = PackedFloat64Array()
var _pending_fp: int = 0
var _max_race_ticks: int = 0
var _order: Array[int] = []
var _finished_count: int = 0


func _init(p_total_laps: int = 30) -> void:
	total_laps = maxi(1, p_total_laps)
	track_length_m = TRACK_LENGTH_M
	_mini_sector_length_m = track_length_m / float(MINI_SECTOR_COUNT)
	_max_race_ticks = total_laps * TICK_RATE * 600
	_session_best_mini.resize(MINI_SECTOR_COUNT)
	_session_best_mini.fill(INF)
	_build_track()


## Creates the standard 10-team, 20-car, 30-lap grid.
func setup_standard_race(car_count: int = 20) -> void:
	if not cars.is_empty():
		return
	var count: int = clampi(car_count, 1, DRIVER_NAMES.size())
	for index: int in range(count):
		var compound: int = TireModelScript.Compound.SOFT
		if index >= 7 and index < 14:
			compound = TireModelScript.Compound.MEDIUM
		elif index >= 14:
			compound = TireModelScript.Compound.HARD
		var car: CarStateScript = CarStateScript.new(
			index, index / 2, DRIVER_NAMES[index], compound
		)
		car.total_distance = -GRID_GAP_M * float(index + 1)
		car.spline_distance = fposmod(car.total_distance, track_length_m)
		car.current_lane = 0 if index % 2 == 0 else 2
		car.lane_target = car.current_lane
		car.lane_position = float(car.current_lane)
		car.lane_offset_m = (car.lane_position - 1.0) * LANE_OFFSET_M
		car.driver_skill = 1.0 + 0.001 * float((index % 5) - 2)
		car.pace_mode = CarStateScript.PaceMode.STANDARD
		car.engine_mode = CarStateScript.EngineMode.STANDARD
		car.fuel.remaining_kg = car.fuel.max_fuel_kg
		car.tire.track_wetness_mm = weather_wetness_mm
		car.tire.ambient_temp_c = ambient_temp_c
		_locate_segment(car)
		cars.append(car)


func add_car(car: CarStateScript) -> void:
	car.spline_distance = fposmod(car.total_distance, track_length_m)
	car.tire.track_wetness_mm = weather_wetness_mm
	car.tire.ambient_temp_c = ambient_temp_c
	_locate_segment(car)
	if car.total_distance >= 0.0 and not car.has_started_lap:
		car.has_started_lap = true
		car.lap_number = 1
		car.begin_lap(race_time)
	cars.append(car)


func set_time_scale(scale: float) -> void:
	time_scale = clampf(scale, 1.0, 16.0)


func set_weather_wetness(wetness_mm: float) -> void:
	weather_wetness_mm = maxf(0.0, wetness_mm)
	for car: CarStateScript in cars:
		car.tire.track_wetness_mm = weather_wetness_mm


func set_ambient_temp(temp_c: float) -> void:
	ambient_temp_c = maxf(-20.0, temp_c)
	for car: CarStateScript in cars:
		car.tire.ambient_temp_c = ambient_temp_c


## Wall-clock frame input. Converts to an integer fixed-point number of ticks
## so speed changes cannot introduce accumulator drift.
func process_frame(delta: float) -> void:
	if is_finished or delta <= 0.0:
		return
	var ticks: float = delta * time_scale * float(TICK_RATE)
	_pending_fp += int(round(ticks * TICK_FP_SCALE_F))
	var stepped: int = 0
	while _pending_fp >= TICK_FP_SCALE:
		_pending_fp -= TICK_FP_SCALE
		_step_tick()
		stepped += 1
		if is_finished:
			_pending_fp = 0
			return
		if stepped >= MAX_TICKS_PER_FRAME:
			# Real-time hitch guard; the headless runner never reaches this.
			_pending_fp = 0
			return


func step_ticks(count: int) -> void:
	for _index: int in range(count):
		if is_finished:
			return
		_step_tick()


func is_race_finished() -> bool:
	return is_finished


func get_team_name(p_team_id: int) -> String:
	return TEAM_NAMES[clampi(p_team_id, 0, TEAM_NAMES.size() - 1)]


func get_session_best_mini() -> PackedFloat64Array:
	return _session_best_mini.duplicate()


func get_car(p_car_id: int) -> CarStateScript:
	for car: CarStateScript in cars:
		if car.car_id == p_car_id:
			return car
	return null


static func slipstream_drag_multiplier(gap_s: float, is_straight: bool) -> float:
	if is_straight and gap_s > 0.02 and gap_s < SLIPSTREAM_GAP_S:
		return SLIPSTREAM_DRAG_MULT
	return 1.0


static func dirty_air_downforce_multiplier(gap_s: float, in_corner: bool) -> float:
	if in_corner and gap_s > 0.02 and gap_s < DIRTY_AIR_GAP_S:
		return DIRTY_AIR_DOWNFORCE_MULT
	return 1.0


## Live timing tower sorted by laps completed then track distance.
func get_standings() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var count: int = cars.size()
	if count == 0:
		return result
	var order: Array[int] = []
	order.resize(count)
	for index: int in range(count):
		order[index] = index
	order.sort_custom(_compare_standings)
	var leader: CarStateScript = cars[order[0]]

	for position: int in range(count):
		var car: CarStateScript = cars[order[position]]
		var gap_s: float = 0.0
		if car.is_finished and leader.is_finished:
			gap_s = car.finish_time - leader.finish_time
		elif not leader.is_finished:
			gap_s = (leader.total_distance - car.total_distance) / maxf(car.speed_mps, 25.0)
		else:
			gap_s = car.finish_time - leader.finish_time

		var interval_s: float = 0.0
		if position > 0:
			var previous: CarStateScript = cars[order[position - 1]]
			if car.is_finished and previous.is_finished:
				interval_s = car.finish_time - previous.finish_time
			else:
				interval_s = (previous.total_distance - car.total_distance) / maxf(car.speed_mps, 25.0)

		var lap_delta: float = 0.0
		if car.last_lap_time > 0.0 and session_best_lap < INF:
			lap_delta = car.last_lap_time - session_best_lap

		var entry: Dictionary = {
			"position": position + 1,
			"car_id": car.car_id,
			"team_id": car.team_id,
			"team_name": get_team_name(car.team_id),
			"driver_name": car.driver_name,
			"compound": car.tire_compound,
			"compound_name": car.tire.get_compound_name(),
			"lap_number": car.lap_number,
			"laps_completed": car.laps_completed,
			"last_lap_time": car.last_lap_time,
			"best_lap_time": car.best_lap_time,
			"gap_s": gap_s,
			"interval_s": interval_s,
			"last_lap_delta_s": lap_delta,
			"fuel_kg": car.fuel.remaining_kg,
			"wear_avg": car.tire.get_average_wear(),
			"wear_min": car.tire.get_min_wear(),
			"temp_avg_c": car.tire.get_average_temp(),
			"pace_mode": car.pace_mode,
			"engine_mode": car.engine_mode,
			"lane": car.current_lane,
			"is_finished": car.is_finished,
			"finish_time": car.finish_time,
			"mini_sector_deltas": car.mini_sector_deltas.duplicate(),
		}
		result.append(entry)
	return result


func get_telemetry(p_car_id: int) -> Dictionary:
	var car: CarStateScript = get_car(p_car_id)
	if car == null:
		return {}
	var telemetry: Dictionary = car.get_telemetry()
	for entry: Dictionary in get_standings():
		if int(entry["car_id"]) == p_car_id:
			telemetry["position"] = int(entry["position"])
			break
	telemetry["session_best_lap"] = session_best_lap
	telemetry["session_best_mini"] = _session_best_mini.duplicate()
	telemetry["race_time"] = race_time
	return telemetry


func _step_tick() -> void:
	if is_finished:
		return
	tick_count += 1
	race_time += TICK_DT
	_update_traffic()
	var update_tires: bool = (tick_count % 3) == 0
	var tire_dt: float = TICK_DT * 3.0
	for car: CarStateScript in cars:
		if car.is_finished:
			continue
		_step_car(car, TICK_DT, update_tires, tire_dt)
	_check_race_finished()


func _update_traffic() -> void:
	var count: int = cars.size()
	if count == 0:
		return
	_order.resize(count)
	var active: int = 0
	for index: int in range(count):
		var car: CarStateScript = cars[index]
		car.gap_ahead_m = 9999.0
		car.gap_ahead_s = 9999.0
		car.ahead_index = -1
		car.ahead_speed_mps = 0.0
		car.ahead_lane_position = 1.0
		car.drag_multiplier = 1.0
		car.dirty_air_factor = 1.0
		if not car.is_finished:
			_order[active] = index
			active += 1
	if active < 2:
		return
	_order.resize(active)
	_sort_order_by_progress(active)

	for position: int in range(1, active):
		var index: int = _order[position]
		var ahead_index: int = _order[position - 1]
		var car: CarStateScript = cars[index]
		var ahead: CarStateScript = cars[ahead_index]
		var gap_m: float = ahead.total_distance - car.total_distance
		car.ahead_index = ahead_index
		car.gap_ahead_m = gap_m
		car.gap_ahead_s = gap_m / maxf(car.speed_mps, 5.0)
		car.ahead_speed_mps = ahead.speed_mps
		car.ahead_lane_position = ahead.lane_position
		var segment: TrackSegment = _segments[car.segment_index]
		car.drag_multiplier = slipstream_drag_multiplier(car.gap_ahead_s, segment.is_straight())
		car.dirty_air_factor = dirty_air_downforce_multiplier(car.gap_ahead_s, not segment.is_straight())


func _step_car(car: CarStateScript, dt: float, update_tires: bool, tire_dt: float) -> void:
	var segment: TrackSegment = _segments[car.segment_index]
	_update_lane(car, dt)

	var mass: float = DRY_MASS_KG + car.fuel.remaining_kg
	# Fuel mass enters the physics here; FuelModel exposes the PRD's calibrated
	# +0.15 s/10 kg lap-time penalty for strategy and UI prediction.
	var mu: float = _effective_mu(car)
	var downforce_coeff: float = DOWNFORCE_COEFF * car.dirty_air_factor
	var speed: float = car.speed_mps
	var downforce_n: float = downforce_coeff * speed * speed

	var throttle: float = PACE_THROTTLE[car.pace_mode]
	var power: float = (
		ENGINE_POWER_W
		* throttle
		* ENGINE_POWER_MULT[car.engine_mode]
		* car.driver_skill
	)
	var drag_coeff: float = DRAG_COEFF * car.drag_multiplier
	var top_speed: float = car.cached_top_speed
	if car.cached_power_w != power or car.cached_drag_coeff != drag_coeff:
		if drag_coeff > 0.0:
			top_speed = minf(MAX_SPEED_MPS, pow(power / drag_coeff, 1.0 / 3.0))
		else:
			top_speed = MAX_SPEED_MPS
		car.cached_top_speed = top_speed
		car.cached_power_w = power
		car.cached_drag_coeff = drag_coeff

	var target_speed: float = top_speed
	if segment.radius_m > 0.0:
		target_speed = minf(target_speed, _corner_speed(mu, downforce_coeff, mass, segment.radius_m))

	var brake_decel: float = minf(
		MAX_BRAKE_MPS2, mu * (GRAVITY + downforce_n / mass) * 1.30
	)
	brake_decel *= PACE_BRAKE_MULT[car.pace_mode]

	var base_distance: float = car.spline_distance
	for lookahead: int in range(1, 4):
		var next_index: int = (car.segment_index + lookahead) % _segments.size()
		var next_segment: TrackSegment = _segments[next_index]
		if next_segment.radius_m <= 0.0:
			continue
		var distance: float = next_segment.start_m - base_distance
		if distance <= 0.0:
			distance += track_length_m
		if distance > 500.0:
			continue
		var next_speed: float = _corner_speed(mu, downforce_coeff, mass, next_segment.radius_m)
		var allowed_speed: float = sqrt(next_speed * next_speed + 2.0 * brake_decel * distance)
		target_speed = minf(target_speed, allowed_speed)

	target_speed *= car.driver_skill
	var cliff_penalty: float = car.tire.get_cliff_time_penalty_seconds()
	if cliff_penalty > 0.0:
		target_speed *= maxf(0.90, 1.0 - cliff_penalty / TireModelScript.REFERENCE_LAP_TIME_S)

	if car.ahead_index >= 0 and car.gap_ahead_m < 15.0:
		var follow_cap: float = car.ahead_speed_mps + (8.0 if car.gap_ahead_m > 6.0 else 1.0)
		target_speed = minf(target_speed, follow_cap)
	if car.is_out_of_fuel:
		target_speed = 0.0

	var old_speed: float = car.speed_mps
	if old_speed < target_speed:
		var traction_limit: float = mu * GRAVITY * 0.85
		var power_accel: float = power / (mass * maxf(old_speed, 6.0))
		var drive_accel: float = minf(traction_limit, power_accel)
		var drag_decel: float = drag_coeff * old_speed * old_speed / mass
		var net_accel: float = drive_accel - drag_decel
		car.speed_mps = minf(target_speed, old_speed + maxf(net_accel, 0.0) * dt)
	else:
		var decel: float = brake_decel
		if target_speed <= 0.0:
			decel = maxf(decel, 4.0)
		car.speed_mps = maxf(target_speed, old_speed - decel * dt)
	car.speed_mps = clampf(car.speed_mps, 0.0, MAX_SPEED_MPS)

	var longitudinal_g: float = (car.speed_mps - old_speed) / dt / GRAVITY
	var lateral_g: float = 0.0
	if segment.radius_m > 0.0:
		lateral_g = minf(4.0, car.speed_mps * car.speed_mps / segment.radius_m / GRAVITY)
	var dirty_heat: float = DIRTY_AIR_HEAT_MULT if car.dirty_air_factor < 0.99 else 1.0
	if update_tires:
		car.tire.update_state(
			tire_dt, car.speed_mps, lateral_g, segment.direction, longitudinal_g, car.pace_mode, dirty_heat
		)

	car.fuel.burn(dt, throttle, car.engine_mode)
	if car.fuel.remaining_kg <= 0.0:
		car.is_out_of_fuel = true

	var previous_spline: float = car.spline_distance
	car.total_distance += car.speed_mps * dt
	car.spline_distance = fposmod(car.total_distance, track_length_m)
	_advance_segment(car)
	_handle_progress(car, previous_spline)


func _update_lane(car: CarStateScript, dt: float) -> void:
	if car.ahead_index >= 0 and car.gap_ahead_m < 12.0:
		var speed_delta: float = car.speed_mps - car.ahead_speed_mps
		if speed_delta > 5.0 / 3.6:
			var chosen_lane: int = _choose_overtake_lane(car)
			if chosen_lane >= 0:
				car.lane_target = chosen_lane
	elif car.gap_ahead_m > 30.0 and car.lane_target != 1:
		car.lane_target = 1
	car.lane_position = move_toward(
		car.lane_position, float(car.lane_target), LANE_CHANGE_RATE * dt
	)
	car.current_lane = car.lane_target
	car.lane_offset_m = (car.lane_position - 1.0) * LANE_OFFSET_M


func _choose_overtake_lane(car: CarStateScript) -> int:
	var candidates: Array[int] = []
	if car.lane_target != 0:
		candidates.append(0)
	else:
		candidates.append(2)
	if car.lane_target != 2:
		candidates.append(2)
	for lane: int in candidates:
		if _is_lane_clear(car, lane):
			return lane
	return -1


func _is_lane_clear(car: CarStateScript, lane: int) -> bool:
	for other: CarStateScript in cars:
		if other == car or other.is_finished:
			continue
		if absf(other.total_distance - car.total_distance) > 18.0:
			continue
		if absf(other.lane_position - float(lane)) < 0.8:
			return false
	return true


func _handle_progress(car: CarStateScript, previous_spline: float) -> void:
	var crossed_line: bool = car.spline_distance < previous_spline
	if crossed_line:
		if car.has_started_lap:
			_finish_mini_sector(
				car, car.mini_sector_index, race_time - car.mini_sector_start_time
			)
			var lap_time: float = car.finish_lap(race_time)
			current_lap = maxi(current_lap, car.laps_completed)
			if lap_time < session_best_lap:
				session_best_lap = lap_time
			lap_completed.emit(car.car_id, car.laps_completed, lap_time)
			if car.laps_completed >= total_laps:
				_finish_car(car)
				return
			car.lap_number += 1
			car.begin_lap(race_time)
		else:
			car.has_started_lap = true
			car.lap_number = 1
			current_lap = maxi(current_lap, 1)
			car.begin_lap(race_time)
		return

	if not car.has_started_lap:
		return
	var new_index: int = clampi(
		int(car.spline_distance / _mini_sector_length_m), 0, MINI_SECTOR_COUNT - 1
	)
	if new_index != car.mini_sector_index:
		_finish_mini_sector(car, car.mini_sector_index, race_time - car.mini_sector_start_time)
		car.mini_sector_index = new_index
		car.mini_sector_start_time = race_time


func _finish_mini_sector(car: CarStateScript, index: int, split_time: float) -> void:
	if split_time <= 0.0 or index < 0 or index >= MINI_SECTOR_COUNT:
		return
	var session_best_before: float = _session_best_mini[index]
	car.record_mini_sector(index, split_time, session_best_before)
	if split_time < session_best_before:
		_session_best_mini[index] = split_time


func _finish_car(car: CarStateScript) -> void:
	if car.is_finished:
		return
	car.is_finished = true
	car.finish_time = race_time
	finish_order.append(car.car_id)
	car.finish_position = finish_order.size()
	_finished_count += 1


func _check_race_finished() -> void:
	if is_finished:
		return
	if cars.is_empty():
		is_finished = true
		var empty: Array[Dictionary] = []
		race_finished.emit(empty)
		return
	if _finished_count >= cars.size():
		is_finished = true
		race_finished.emit(get_standings())
		return
	if tick_count > _max_race_ticks:
		_force_finish()


func _force_finish() -> void:
	var remaining: Array[int] = []
	for index: int in range(cars.size()):
		if not cars[index].is_finished:
			remaining.append(index)
	remaining.sort_custom(_compare_progress)
	for index: int in remaining:
		var car: CarStateScript = cars[index]
		car.is_finished = true
		car.finish_time = race_time
		finish_order.append(car.car_id)
		car.finish_position = finish_order.size()
		_finished_count += 1
	is_finished = true
	race_finished.emit(get_standings())


func _sort_order_by_progress(count: int) -> void:
	# Insertion sort, descending by total distance. The previous order is not
	# retained, but 20 near-grid-ordered cars sort in very few swaps.
	for i: int in range(1, count):
		var value: int = _order[i]
		var value_car: CarStateScript = cars[value]
		var value_distance: float = value_car.total_distance
		var value_id: int = value_car.car_id
		var j: int = i - 1
		while j >= 0:
			var other: CarStateScript = cars[_order[j]]
			var shift: bool = other.total_distance < value_distance
			if other.total_distance == value_distance:
				shift = other.car_id > value_id
			if not shift:
				break
			_order[j + 1] = _order[j]
			j -= 1
		_order[j + 1] = value


func _advance_segment(car: CarStateScript) -> void:
	while (
		car.segment_index < _segments.size() - 1
		and car.spline_distance >= _segments[car.segment_index].end_m()
	):
		car.segment_index += 1
	while (
		car.segment_index > 0
		and car.spline_distance < _segments[car.segment_index].start_m
	):
		car.segment_index -= 1


func _locate_segment(car: CarStateScript) -> void:
	for index: int in range(_segments.size()):
		if car.spline_distance < _segments[index].end_m():
			car.segment_index = index
			return
	car.segment_index = _segments.size() - 1


func _effective_mu(car: CarStateScript) -> float:
	var raw_grip: float = car.tire.get_average_grip()
	var compressed: float = CHASSIS_BASE_GRIP + (raw_grip - 1.0) * CHASSIS_GRIP_COMPRESSION
	return clampf(compressed, 0.35, 1.35)


func _corner_speed(mu: float, downforce_coeff: float, mass: float, radius_m: float) -> float:
	if radius_m <= 0.0 or mass <= 0.0:
		return MAX_SPEED_MPS
	var denominator: float = 1.0 - mu * downforce_coeff * radius_m / mass
	denominator = maxf(denominator, 0.25)
	return minf(MAX_SPEED_MPS, sqrt(mu * GRAVITY * radius_m / denominator))


func _compare_progress(a: int, b: int) -> bool:
	var distance_a: float = cars[a].total_distance
	var distance_b: float = cars[b].total_distance
	if distance_a == distance_b:
		return cars[a].car_id < cars[b].car_id
	return distance_a > distance_b


func _compare_standings(a: int, b: int) -> bool:
	var car_a: CarStateScript = cars[a]
	var car_b: CarStateScript = cars[b]
	if car_a.is_finished and car_b.is_finished:
		if car_a.finish_time == car_b.finish_time:
			return car_a.car_id < car_b.car_id
		return car_a.finish_time < car_b.finish_time
	if car_a.is_finished:
		return true
	if car_b.is_finished:
		return false
	if car_a.total_distance == car_b.total_distance:
		return car_a.car_id < car_b.car_id
	return car_a.total_distance > car_b.total_distance


func _build_track() -> void:
	_segments.clear()
	var lengths: PackedFloat64Array = PackedFloat64Array([
		1250.0, 70.0, 110.0, 80.0, 650.0, 180.0, 220.0, 120.0,
		240.0, 1300.0, 90.0, 80.0, 100.0, 350.0, 500.0, 300.0,
	])
	var radii: PackedFloat64Array = PackedFloat64Array([
		0.0, 40.0, 0.0, 45.0, 260.0, 0.0, 95.0, 0.0,
		115.0, 0.0, 55.0, 0.0, 65.0, 0.0, 170.0, 0.0,
	])
	var directions: PackedInt32Array = PackedInt32Array([
		0, 1, 0, -1, -1, 0, 1, 0,
		1, 0, -1, 0, 1, 0, -1, 0,
	])
	var total: float = 0.0
	for length: float in lengths:
		total += length
	lengths[9] += track_length_m - total
	var cursor: float = 0.0
	for index: int in range(lengths.size()):
		_segments.append(
			TrackSegment.new(cursor, lengths[index], radii[index], directions[index])
		)
		cursor += lengths[index]
