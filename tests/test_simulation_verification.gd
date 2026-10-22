extends SceneTree

## Focused verification for the Phase 1 core math models.
## Run standalone:
##   godot --headless --script tests/test_simulation_verification.gd

const EngineScript := preload("res://scripts/core/race_sim_engine.gd")
const CarStateScript := preload("res://scripts/core/car_state.gd")
const TireModelScript := preload("res://scripts/core/tire_model.gd")
const FuelModelScript := preload("res://scripts/core/fuel_model.gd")

const MINI_SECTOR_COUNT: int = 12
const SECTOR_COUNT: int = 3

var _failures: int = 0


func _initialize() -> void:
	print("============================================================")
	print(" LA VOITURE - CORE MODEL VERIFICATION")
	print("============================================================")
	_check_tire_model()
	_check_fuel_model()
	_check_aero_helpers()
	_check_soft_vs_hard()
	_check_mini_sectors()
	_check_determinism_short()
	print("------------------------------------------------------------")
	if _failures == 0:
		print("[PASS] ALL CORE MODEL ASSERTIONS VERIFIED")
	else:
		print("[FAIL] %d core model assertion(s) failed" % _failures)
	quit(0 if _failures == 0 else 1)


static func run_single_car(compound: int, laps: int) -> CarStateScript:
	var sim: EngineScript = EngineScript.new(laps)
	var car: CarStateScript = CarStateScript.new(99, 0, "Test Driver", compound)
	car.total_distance = -5.0
	car.current_lane = 1
	car.lane_target = 1
	car.lane_position = 1.0
	sim.add_car(car)
	sim.set_time_scale(16.0)
	var guard: int = 0
	while not sim.is_finished and guard < 500_000:
		sim.process_frame(1.0 / 60.0)
		guard += 1
	return car


static func measure_compound_lap(compound: int, laps: int = 4) -> float:
	var car: CarStateScript = run_single_car(compound, laps)
	if car.lap_times.size() < 2:
		return -1.0
	return car.lap_times[1]


func _check_tire_model() -> void:
	var tire: TireModelScript = TireModelScript.new(TireModelScript.Compound.SOFT)
	var initial_wear: float = tire.get_average_wear()
	_require(is_equal_approx(initial_wear, 1.0), "tire starts at 100% condition")
	for _i: int in range(3600):
		tire.update_state(1.0 / 60.0, 50.0, 1.6, 1, 0.0, CarStateScript.PaceMode.STANDARD)
	_require(tire.wear[TireModelScript.Corner.FL] < initial_wear, "FL wears")
	_require(tire.wear[TireModelScript.Corner.RL] < initial_wear, "RL wears")
	_require(
		tire.wear[TireModelScript.Corner.FL] < tire.wear[TireModelScript.Corner.FR],
		"right-hand corner loads FL more than FR"
	)
	_require(
		tire.wear[TireModelScript.Corner.RL] < tire.wear[TireModelScript.Corner.RR],
		"right-hand corner loads RL more than RR"
	)
	var hot_temp: float = tire.get_average_temp()
	_require(hot_temp > 80.0, "cornering heats the tires (%.1f C)" % hot_temp)
	for _i: int in range(600):
		tire.update_state(1.0 / 60.0, 70.0, 0.0, 0, 0.0, CarStateScript.PaceMode.STANDARD)
	_require(tire.get_average_temp() < hot_temp, "straight-line cooling lowers tire temperature")

	var soft: TireModelScript = TireModelScript.new(TireModelScript.Compound.SOFT)
	var hard: TireModelScript = TireModelScript.new(TireModelScript.Compound.HARD)
	_require(soft.get_average_grip() > hard.get_average_grip(), "Soft grip > Hard grip")

	var wet: TireModelScript = TireModelScript.new(TireModelScript.Compound.WET)
	wet.track_wetness_mm = 1.5
	var slick_in_wet: TireModelScript = TireModelScript.new(TireModelScript.Compound.HARD)
	slick_in_wet.track_wetness_mm = 1.5
	_require(wet.get_average_grip() > slick_in_wet.get_average_grip(), "Wet compound beats slicks in rain")


func _check_fuel_model() -> void:
	var fuel: FuelModelScript = FuelModelScript.new()
	_require(is_equal_approx(fuel.remaining_kg, 65.0), "fuel starts at 65 kg")
	_require(is_equal_approx(fuel.get_weight_penalty_seconds(), 0.975), "65 kg penalty = 0.975 s")
	var penalty_before: float = fuel.get_weight_penalty_seconds()
	fuel.remaining_kg += 10.0
	var delta: float = fuel.get_weight_penalty_seconds() - penalty_before
	_require(is_equal_approx(delta, 0.15), "+10 kg penalty delta = 0.15 s")

	var eco: FuelModelScript = FuelModelScript.new()
	var standard: FuelModelScript = FuelModelScript.new()
	var push: FuelModelScript = FuelModelScript.new()
	for _i: int in range(600):
		eco.burn(1.0 / 60.0, 0.95, FuelModelScript.EngineMode.ECO)
		standard.burn(1.0 / 60.0, 0.95, FuelModelScript.EngineMode.STANDARD)
		push.burn(1.0 / 60.0, 0.95, FuelModelScript.EngineMode.PUSH)
	_require(eco.remaining_kg > standard.remaining_kg, "ECO burns less than STANDARD")
	_require(standard.remaining_kg > push.remaining_kg, "STANDARD burns less than PUSH")


func _check_aero_helpers() -> void:
	_require(
		is_equal_approx(EngineScript.slipstream_drag_multiplier(0.5, true), 0.70),
		"slipstream cuts drag to 70% inside 0.8 s on a straight"
	)
	_require(
		is_equal_approx(EngineScript.slipstream_drag_multiplier(1.0, true), 1.0),
		"no slipstream outside 0.8 s"
	)
	_require(
		is_equal_approx(EngineScript.dirty_air_downforce_multiplier(0.9, true), 0.82),
		"dirty air cuts downforce to 82% inside 1.0 s in a corner"
	)
	_require(
		is_equal_approx(EngineScript.dirty_air_downforce_multiplier(0.9, false), 1.0),
		"no dirty-air downforce loss on a straight"
	)


func _check_soft_vs_hard() -> void:
	var soft_lap: float = measure_compound_lap(TireModelScript.Compound.SOFT)
	var hard_lap: float = measure_compound_lap(TireModelScript.Compound.HARD)
	print("[INFO] Soft lap 2 = %.3f s, Hard lap 2 = %.3f s" % [soft_lap, hard_lap])
	_require(soft_lap > 0.0 and hard_lap > 0.0, "compound A/B completed its laps")
	_require(soft_lap < hard_lap, "Soft is faster than Hard")
	var delta: float = hard_lap - soft_lap
	print("[INFO] Soft vs Hard delta = %.3f s/lap" % delta)
	_require(delta >= 0.8 and delta <= 1.4, "Soft/Hard delta matches the PRD 0.8-1.4 s window")


func _check_mini_sectors() -> void:
	var car: CarStateScript = run_single_car(TireModelScript.Compound.MEDIUM, 2)
	_require(car.lap_times.size() == 2, "single-car run completed two timed laps")
	var mini_sum: float = 0.0
	for index: int in range(MINI_SECTOR_COUNT):
		var split: float = car.last_lap_mini_sector_times[index]
		mini_sum += split
		_require(split > 0.0, "mini-sector %d recorded" % index)
	var sector_sum: float = 0.0
	for index: int in range(SECTOR_COUNT):
		sector_sum += car.last_lap_sector_times[index]
		_require(car.last_lap_sector_times[index] > 0.0, "sector %d recorded" % index)
	_require(
		absf(mini_sum - car.last_lap_time) < 0.01,
		"12 mini-sectors sum to the lap time"
	)
	_require(
		absf(sector_sum - car.last_lap_time) < 0.01,
		"3 sectors sum to the lap time"
	)


func _check_determinism_short() -> void:
	var sim_1x: EngineScript = EngineScript.new(3)
	sim_1x.setup_standard_race(6)
	var sim_16x: EngineScript = EngineScript.new(3)
	sim_16x.setup_standard_race(6)
	_run(sim_1x, 1.0)
	_run(sim_16x, 16.0)
	_require(sim_1x.tick_count == sim_16x.tick_count, "short determinism: identical tick count")
	_require(sim_1x.finish_order == sim_16x.finish_order, "short determinism: identical finish order")
	var identical: bool = true
	for index: int in range(sim_1x.cars.size()):
		var a: CarStateScript = sim_1x.cars[index]
		var b: CarStateScript = sim_16x.cars[index]
		if a.lap_times != b.lap_times or a.finish_time != b.finish_time:
			identical = false
		if a.tire.wear != b.tire.wear or a.fuel.remaining_kg != b.fuel.remaining_kg:
			identical = false
	_require(identical, "short determinism: identical lap times, wear and fuel")
	print("[INFO] short determinism ticks: %d" % sim_1x.tick_count)


func _run(sim: EngineScript, scale: float) -> void:
	sim.set_time_scale(scale)
	var guard: int = 0
	while not sim.is_finished and guard < 500_000:
		sim.process_frame(1.0 / 60.0)
		guard += 1


func _require(condition: bool, message: String) -> void:
	if condition:
		print("[PASS] ", message)
	else:
		_failures += 1
		print("[FAIL] ", message)
