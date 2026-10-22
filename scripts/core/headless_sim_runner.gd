extends SceneTree

## Headless Phase 1 acceptance runner: 30 laps, 20 cars, no viewport.
## Verifies Soft vs Hard pace and bit-exact 1x/16x determinism.

const EngineScript := preload("res://scripts/core/race_sim_engine.gd")
const CarStateScript := preload("res://scripts/core/car_state.gd")
const TireModelScript := preload("res://scripts/core/tire_model.gd")
const FuelModelScript := preload("res://scripts/core/fuel_model.gd")
const VerificationScript := preload("res://tests/test_simulation_verification.gd")

const TICK_DT: float = 1.0 / 60.0
const TOTAL_LAPS: int = 30
const CAR_COUNT: int = 20
const MINI_SECTOR_COUNT: int = 12

var _failures: int = 0


func _initialize() -> void:
	var wall_start: int = Time.get_ticks_msec()
	print("================================================================")
	print(" LA VOITURE - PHASE 1 CORE SIMULATION")
	print("================================================================")
	print(" Track: %.0f m | Laps: %d | Cars: %d | Tick: 60 Hz" % [
		EngineScript.TRACK_LENGTH_M, TOTAL_LAPS, CAR_COUNT
	])
	print("")

	_check_compound_pace()

	var sim_16x: EngineScript = EngineScript.new(TOTAL_LAPS)
	sim_16x.setup_standard_race(CAR_COUNT)
	var race_start_16x: int = Time.get_ticks_msec()
	_run_simulation(sim_16x, 16.0)
	var wall_16x: int = Time.get_ticks_msec() - race_start_16x
	_check(sim_16x.is_finished, "16x race should have finished")
	_check_race_integrity(sim_16x)

	var sim_1x: EngineScript = EngineScript.new(TOTAL_LAPS)
	sim_1x.setup_standard_race(CAR_COUNT)
	var race_start_1x: int = Time.get_ticks_msec()
	_run_simulation(sim_1x, 1.0)
	var wall_1x: int = Time.get_ticks_msec() - race_start_1x
	_check_determinism(sim_1x, sim_16x)

	_print_report(sim_16x)
	print("")
	print("---------------------------------------------------------------")
	print(" SIMULATION TIMING")
	print("---------------------------------------------------------------")
	print(" 16x wall time: %d ms" % wall_16x)
	print(" 1x  wall time: %d ms" % wall_1x)
	print(" Simulated race duration: %.3f s" % sim_16x.race_time)
	if wall_16x > 0:
		print(" 16x realtime factor: %.1fx" % (sim_16x.race_time / (float(wall_16x) / 1000.0)))
	print(" Base track length: %.1f m" % sim_16x.track_length_m)
	print(" Full run wall time: %d ms" % (Time.get_ticks_msec() - wall_start))
	print("---------------------------------------------------------------")
	if _failures == 0:
		print("[PASS] ALL SIMULATION ASSERTIONS VERIFIED")
	else:
		print("[FAIL] %d assertion(s) failed" % _failures)
	quit(0 if _failures == 0 else 1)


func _check_compound_pace() -> void:
	var soft_lap: float = VerificationScript.measure_compound_lap(
		TireModelScript.Compound.SOFT, 4
	)
	var hard_lap: float = VerificationScript.measure_compound_lap(
		TireModelScript.Compound.HARD, 4
	)
	var delta: float = hard_lap - soft_lap
	print(" Compound A/B (lap 2, identical car):")
	print("   Soft  %s" % _format_lap(soft_lap))
	print("   Hard  %s" % _format_lap(hard_lap))
	print("   Delta %+.3f s" % delta)
	_check(soft_lap > 0.0 and hard_lap > 0.0, "compound A/B completed its laps")
	if _check(soft_lap < hard_lap, "Soft is faster than Hard"):
		print("[PASS] Soft is faster than Hard")
	if _check(delta >= 0.8 and delta <= 1.4, "Soft/Hard delta matches the PRD 0.8-1.4 s window"):
		print("[PASS] Soft/Hard delta is inside the PRD 0.8-1.4 s window")
	print("")


func _check_race_integrity(sim: EngineScript) -> void:
	_check(sim.finish_order.size() == CAR_COUNT, "all 20 cars recorded a finish")
	_check(sim.cars.size() == CAR_COUNT, "20 car states created")
	var all_finished: bool = true
	var all_laps: bool = true
	var sane_times: bool = true
	var sane_tires: bool = true
	var sane_fuel: bool = true
	var mini_ok: bool = true
	var positions: Dictionary = {}

	for car: CarStateScript in sim.cars:
		if not car.is_finished:
			all_finished = false
		if car.lap_times.size() != TOTAL_LAPS:
			all_laps = false
		if car.finish_time <= 0.0 or car.finish_position < 1 or car.finish_position > CAR_COUNT:
			sane_times = false
		positions[car.finish_position] = true
		for lap_time: float in car.lap_times:
			if not is_finite(lap_time) or lap_time < 30.0 or lap_time > 400.0:
				sane_times = false
		if car.tire.get_average_wear() < 0.0 or car.tire.get_average_wear() > 1.0:
			sane_tires = false
		if car.tire.get_average_temp() < 0.0 or car.tire.get_average_temp() > 160.0:
			sane_tires = false
		if car.fuel.remaining_kg < 0.0 or car.fuel.remaining_kg > car.fuel.max_fuel_kg:
			sane_fuel = false
		var mini_sum: float = 0.0
		for index: int in range(MINI_SECTOR_COUNT):
			var split: float = car.last_lap_mini_sector_times[index]
			if split <= 0.0:
				mini_ok = false
			mini_sum += split
		if absf(mini_sum - car.last_lap_time) > 0.01:
			mini_ok = false

	_check(all_finished, "every car finished")
	_check(all_laps, "every car completed 30 timed laps")
	_check(sane_times, "lap and finish times are finite and plausible")
	_check(sane_tires, "tire wear and temperatures stay in bounds")
	_check(sane_fuel, "fuel stays within 0..65 kg")
	_check(positions.size() == CAR_COUNT, "finish positions are unique 1..20")
	_check(mini_ok, "12 mini-sectors per last lap sum to the lap time")
	if all_finished and all_laps:
		print("[PASS] 30-lap race: 20/20 cars finished with 30 timed laps")
	print("")


func _check_determinism(sim_1x: EngineScript, sim_16x: EngineScript) -> void:
	var failures_before: int = _failures
	_check(sim_1x.tick_count == sim_16x.tick_count, "1x and 16x ran the same tick count")
	_check(sim_1x.race_time == sim_16x.race_time, "1x and 16x ended at the same race time")
	_check(sim_1x.finish_order == sim_16x.finish_order, "1x and 16x finish order is identical")

	var lap_times_identical: bool = true
	var finish_times_identical: bool = true
	var tires_identical: bool = true
	var fuel_identical: bool = true
	var distances_identical: bool = true
	for index: int in range(mini(CAR_COUNT, sim_1x.cars.size())):
		var a: CarStateScript = sim_1x.cars[index]
		var b: CarStateScript = sim_16x.cars[index]
		if a.lap_times != b.lap_times:
			lap_times_identical = false
		if a.finish_time != b.finish_time:
			finish_times_identical = false
		if a.tire.wear != b.tire.wear:
			tires_identical = false
		if a.fuel.remaining_kg != b.fuel.remaining_kg:
			fuel_identical = false
		if a.total_distance != b.total_distance:
			distances_identical = false

	_check(lap_times_identical, "all 600 lap times are bit-identical at 1x vs 16x")
	_check(finish_times_identical, "finish times are bit-identical at 1x vs 16x")
	_check(tires_identical, "4-corner tire wear is bit-identical at 1x vs 16x")
	_check(fuel_identical, "fuel mass is bit-identical at 1x vs 16x")
	_check(distances_identical, "track distances are bit-identical at 1x vs 16x")
	if _failures == failures_before:
		print("[PASS] 1x vs 16x determinism: identical classification, lap times, tires and fuel")
	print("[INFO] determinism ticks: %d (1x), %d (16x)" % [
		sim_1x.tick_count, sim_16x.tick_count
	])
	print("")


func _print_report(sim: EngineScript) -> void:
	var standings: Array[Dictionary] = sim.get_standings()
	print("================================================================")
	print(" TIMING TOWER - RACE CLASSIFICATION")
	print("================================================================")
	print("POS CAR DRIVER       TEAM               CMP   BEST       LAST       GAP    FUEL  COND%  TEMP")
	for entry: Dictionary in standings:
		var best: String = _format_lap(float(entry["best_lap_time"]))
		var last: String = _format_lap(float(entry["last_lap_time"]))
		print("%2d  %02d  %-11s %-18s %-5s %-10s %-10s %7.2f %6.1f %5.1f %5.1f" % [
			int(entry["position"]),
			int(entry["car_id"]),
			String(entry["driver_name"]),
			String(entry["team_name"]),
			String(entry["compound_name"]),
			best,
			last,
			float(entry["gap_s"]),
			float(entry["fuel_kg"]),
			float(entry["wear_avg"]) * 100.0,
			float(entry["temp_avg_c"]),
		])

	var leader_id: int = int(standings[0]["car_id"])
	var leader: CarStateScript = sim.get_car(leader_id)
	print("")
	print(" SESSION BEST LAP: %s" % _format_lap(sim.session_best_lap))
	print(" Leader last-lap sectors: S1 %s | S2 %s | S3 %s" % [
		_format_lap(leader.last_lap_sector_times[0]),
		_format_lap(leader.last_lap_sector_times[1]),
		_format_lap(leader.last_lap_sector_times[2]),
	])
	var delta_line: String = " Leader mini-sector deltas:"
	for index: int in range(MINI_SECTOR_COUNT):
		delta_line += " %+.3f" % leader.mini_sector_deltas[index]
	print(delta_line)
	print(" Leader 4-corner condition: FL %.1f%% FR %.1f%% RL %.1f%% RR %.1f%%" % [
		leader.tire.wear[TireModelScript.Corner.FL] * 100.0,
		leader.tire.wear[TireModelScript.Corner.FR] * 100.0,
		leader.tire.wear[TireModelScript.Corner.RL] * 100.0,
		leader.tire.wear[TireModelScript.Corner.RR] * 100.0,
	])
	print(" Leader 4-corner temps: FL %.1fC FR %.1fC RL %.1fC RR %.1fC" % [
		leader.tire.surface_temp_c[TireModelScript.Corner.FL],
		leader.tire.surface_temp_c[TireModelScript.Corner.FR],
		leader.tire.surface_temp_c[TireModelScript.Corner.RL],
		leader.tire.surface_temp_c[TireModelScript.Corner.RR],
	])
	print(" Winner: %s (%s) - %s" % [
		leader.driver_name,
		sim.get_team_name(leader.team_id),
		_format_lap(leader.finish_time),
	])


func _run_simulation(sim: EngineScript, scale: float) -> void:
	sim.set_time_scale(scale)
	var guard: int = 0
	while not sim.is_finished and guard < 2_000_000:
		sim.process_frame(TICK_DT)
		guard += 1
	_check(sim.is_finished, "simulation at %.0fx finished" % scale)


func _format_lap(seconds: float) -> String:
	if seconds <= 0.0 or not is_finite(seconds):
		return "-"
	var minutes: int = int(seconds / 60.0)
	var remainder: float = seconds - float(minutes) * 60.0
	return "%d:%06.3f" % [minutes, remainder]


func _check(condition: bool, message: String) -> bool:
	if condition:
		return true
	_failures += 1
	print("[FAIL] ", message)
	return false
