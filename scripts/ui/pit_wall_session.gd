class_name PitWallSession
extends Node

## UI adapter only. Core remains deterministic and contains no presentation nodes.
signal telemetry_updated(snapshot: Dictionary)
signal radio_transmission(car_id: int, message: String, urgent: bool)
signal command_applied(car_id: int, command: String)
const Sim = preload("res://scripts/core/race_sim_engine.gd")
var engine = Sim.new(50)
var snapshot: Dictionary = {}
var paused := false
var _elapsed := 0.0
var _warned: Dictionary = {}

func _ready() -> void:
	engine.setup_standard_race(20)
	engine.lap_completed.connect(_on_lap)
	publish()

func _process(delta: float) -> void:
	if not paused:
		engine.process_frame(delta)
	_elapsed += delta
	if _elapsed >= 0.1:
		_elapsed = 0.0
		publish()

func publish() -> void:
	var telemetry: Array[Dictionary] = []
	for car in engine.cars:
		var packet: Dictionary = car.get_telemetry()
		packet["team_name"] = engine.get_team_name(car.team_id)
		telemetry.append(packet)
		if car.car_id < 2 and car.tire.get_min_wear() <= 0.3 and not _warned.has(car.car_id):
			_warned[car.car_id] = true
			radio_transmission.emit(car.car_id, "TIRES ARE GONE! I NEED A NEW SET.", true)
	var standings: Array[Dictionary] = engine.get_standings()
	# Core current_lap counts completed laps after lap one; show leader's active lap.
	var active_lap: int = 1 if standings.is_empty() else int(standings[0]["lap_number"])
	snapshot = {
		"standings": standings, "cars": telemetry,
		"lap": clampi(active_lap, 1, engine.total_laps), "total_laps": engine.total_laps,
		"time_scale": engine.time_scale, "race_time": engine.race_time,
		"ambient_temp_c": engine.ambient_temp_c, "wetness_mm": engine.weather_wetness_mm,
		"finished": engine.is_finished,
	}
	telemetry_updated.emit(snapshot)

func set_pace(car_id: int, mode: int) -> bool:
	if not _valid_command(car_id, mode):
		return false
	engine.get_car(car_id).pace_mode = mode
	command_applied.emit(car_id, "pace")
	publish()
	return true

func set_fuel(car_id: int, mode: int) -> bool:
	if not _valid_command(car_id, mode):
		return false
	engine.get_car(car_id).engine_mode = mode
	command_applied.emit(car_id, "fuel")
	publish()
	return true

func request_box(car_id: int) -> bool:
	if not _valid_command(car_id, 0):
		return false
	var car = engine.get_car(car_id)
	if car.box_requested:
		return false
	car.box_requested = true
	command_applied.emit(car_id, "box")
	radio_transmission.emit(car_id, "BOX BOX BOX THIS LAP! // COPY, COMING IN.", true)
	publish()
	return true

func set_speed(scale: float) -> void:
	if scale in [1.0, 2.0, 4.0, 8.0, 16.0]:
		engine.set_time_scale(scale)
		publish()

func _valid_command(car_id: int, mode: int) -> bool:
	return car_id in [0, 1] and mode >= 0 and mode <= 2 and not engine.is_finished

func _on_lap(car_id: int, lap: int, lap_time: float) -> void:
	if car_id < 2:
		radio_transmission.emit(car_id, "LAP %02d // %.3fs. KEEP THE PRESSURE ON." % [lap, lap_time], false)
