extends SceneTree

## Fase 32 Task 3: the fuel plan (crew pick, clamp, refuel target), fuel on the grid, refuel time in the pit stop,
## and the projection-based fuel alarm that replaces the fixed 3 kg warning.
## Run: godot --headless --path . -s res://tests/test_fuel_plan.gd

const TrackScene := preload("res://scenes/race_world/circuits/apex_ring/apex_circuit.tscn")
const TrackScript := preload("res://scripts/gt/gt_track.gd")
const RaceScript := preload("res://scripts/gt/gt_race.gd")
const WeatherScript := preload("res://scripts/gt/gt_weather.gd")
const Types := preload("res://scripts/gt/gt_types.gd")

const DRY: int = WeatherScript.Archetype.DRY_SUNNY

var failures: int = 0


func check(ok: bool, description: String) -> void:
	print("[%s] %s" % ["PASS" if ok else "FAIL", description])
	if not ok:
		failures += 1


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var ribbon: Node = TrackScene.instantiate()
	ribbon.road_half_width_m = 7.0
	root.add_child(ribbon)
	var track := TrackScript.new(ribbon, 14.0)
	_test_plan_functions()
	_test_presets()
	_test_grid_fuel(track)
	_test_refuel_time_in_the_stop(track)
	_test_fuel_alarm(track)
	ribbon.queue_free()
	await process_frame
	quit(1 if failures else 0)


func _test_plan_functions() -> void:
	check(is_equal_approx(GtFuelPlan.crew_pick_kg(5, 3.0), 5.0 * 3.0 * 1.08), "crew pick below the mandatory-stop length is the full distance plus 8%")
	check(is_equal_approx(GtFuelPlan.crew_pick_kg(15, 3.0), 0.5 * 15.0 * 3.0 * 1.08), "crew pick from the mandatory-stop length is a light start for a mid-window stop")
	check(is_equal_approx(GtFuelPlan.crew_pick_kg(10, 3.0), 0.5 * 10.0 * 3.0 * 1.08), "and for 10 laps")
	check(GtFuelPlan.crew_pick_kg(15, 30.0) <= GtTypes.TANK_CAP_KG, "crew pick never exceeds the tank")
	check(GtFuelPlan.clamp_kg(-4.0) == 0.0, "negative fuel clamps to empty")
	check(GtFuelPlan.clamp_kg(500.0) == GtTypes.TANK_CAP_KG, "huge fuel clamps to the tank cap")
	check(GtFuelPlan.clamp_kg(INF) == 0.0 and GtFuelPlan.clamp_kg(NAN) == 0.0, "non-finite fuel clamps to empty")
	check(is_equal_approx(GtFuelPlan.refuel_target_kg(10.0, 3.0), 10.0 * 3.0 * 1.08), "refuel target is laps left times burn plus 8%")
	check(GtFuelPlan.refuel_target_kg(100.0, 3.0) == GtTypes.TANK_CAP_KG, "refuel target stops at the tank cap")


func _test_presets() -> void:
	var burn: float = 3.0
	var light: float = GtFuelPlan.preset_kg(GtFuelPlan.Preset.LIGHT, 15, burn)
	var balanced: float = GtFuelPlan.preset_kg(GtFuelPlan.Preset.BALANCED, 15, burn)
	var full: float = GtFuelPlan.preset_kg(GtFuelPlan.Preset.FULL, 15, burn)
	check(is_equal_approx(light, 0.30 * 15.0 * burn * 1.08), "LIGHT carries 30% of the distance plus 8%")
	check(is_equal_approx(balanced, GtFuelPlan.crew_pick_kg(15, burn)), "BALANCED is the pick the AI teams carry")
	check(is_equal_approx(full, 15.0 * burn * 1.08), "FULL carries the whole distance plus 8%")
	check(light < balanced and balanced < full, "the presets are ordered light < balanced < full")
	check(GtFuelPlan.preset_kg(GtFuelPlan.Preset.FULL, 15, 30.0) == GtTypes.TANK_CAP_KG, "a preset never exceeds the tank")
	for laps: int in [3, 5, 9]:
		var all_full: bool = true
		for preset: int in range(3):
			all_full = all_full and is_equal_approx(GtFuelPlan.preset_kg(preset, laps, burn), float(laps) * burn * 1.08)
		check(all_full, "every preset is the full distance in a %d lap race (no mandatory stop)" % laps)
		check(GtFuelPlan.effective_preset(GtFuelPlan.Preset.LIGHT, laps) == GtFuelPlan.Preset.FULL, "so LIGHT shows as FULL at %d laps" % laps)
	check(GtFuelPlan.effective_preset(GtFuelPlan.Preset.LIGHT, 10) == GtFuelPlan.Preset.LIGHT, "from 10 laps the preset stands")
	check(GtFuelPlan.crew_preset(15) == GtFuelPlan.Preset.FULL and GtFuelPlan.crew_preset(5) == GtFuelPlan.Preset.FULL, "the crew recommends FULL at every race length")
	check(GtFuelPlan.effective_preset(99, 15) == GtFuelPlan.Preset.FULL and GtFuelPlan.effective_preset(-3, 15) == GtFuelPlan.Preset.LIGHT, "an out-of-range preset clamps")
	check(GtForecast.start_fuel_verdict(light, 15, burn) == GtForecast.WATCH, "LIGHT reaches the window but must stop early: WATCH")
	check(GtForecast.start_fuel_verdict(balanced, 15, burn) == GtForecast.OK and GtForecast.start_fuel_verdict(full, 15, burn) == GtForecast.OK, "BALANCED and FULL are OK")


func _test_grid_fuel(track: TrackScript) -> void:
	var race := RaceScript.new(track, 15, 5, DRY, 20)
	var all_match: bool = true
	for car: GtCar in race.cars:
		all_match = all_match and is_equal_approx(car.fuel, GtFuelPlan.crew_pick_kg(15, car.fuel_use))
	check(all_match, "every car on a 15 lap grid carries the crew pick")
	race.dispose()


func _test_refuel_time_in_the_stop(track: TrackScript) -> void:
	var race := RaceScript.new(track, 15, 5, DRY, 20)
	race.incidents_enabled = false
	var car: GtCar = race.cars[0]
	car.lap = 3
	var needed: float = GtFuelPlan.refuel_target_kg(float(race.laps - car.lap + 1), car.fuel_use)
	# Fase 32: the base of a stop is the team's crew time
	var crew_s: float = GtTeamStats.pit_stop_time(car.team_id, race.race_seed, car.id * 16 + car.stops)
	car.fuel = 10.0
	race._driving.enter_pit_lane(car, Types.Compound.MEDIUM)
	var duration_low: float = car.pit.duration
	car.pit = null
	car.fuel = needed - 2.0
	race._driving.enter_pit_lane(car, Types.Compound.MEDIUM)
	var duration_high: float = car.pit.duration
	check(is_equal_approx(duration_low, crew_s + (needed - 10.0) * Types.REFUEL_S_PER_KG), "a 10 kg car adds refuel time for the fuel it takes (%.2f s)" % duration_low)
	check(is_equal_approx(duration_high, crew_s + 2.0 * Types.REFUEL_S_PER_KG), "a nearly full car adds almost no refuel time (%.2f s)" % duration_high)
	check(duration_low > duration_high, "the emptier car stands longer in the box")
	race.dispose()


func _test_fuel_alarm(track: TrackScript) -> void:
	var race := RaceScript.new(track, 15, 5, DRY, 20)
	race.incidents_enabled = false
	var car: GtCar = race.cars[0]
	var burn: float = car.fuel_use
	car.mandatory_stop_done = false
	car.lap = 4
	car.s = 0.30 * 15.0 * track.length
	car.fuel = 6.0 * burn
	check(not GtForecast.fuel_alarm(race, car), "a light start on its way to the mandatory stop does not raise the alarm")
	car.fuel = 1.0 * burn
	check(GtForecast.fuel_alarm(race, car), "a car that cannot reach its pending stop raises the alarm")
	car.lap = 13
	car.s = 0.90 * 15.0 * track.length
	car.fuel = 1.7 * burn
	check(GtForecast.fuel_alarm(race, car), "past the stop window a car short of the finish raises the alarm")
	car.fuel = 3.0 * burn
	check(not GtForecast.fuel_alarm(race, car), "a car with enough fuel to finish never raises it, however little is left")
	car.mandatory_stop_done = true
	car.lap = 4
	car.s = 0.30 * 15.0 * track.length
	car.fuel = 6.0 * burn
	check(GtForecast.fuel_alarm(race, car), "after the stop a car short of the finish raises the alarm")
	race.dispose()

	var short_race := RaceScript.new(track, 5, 5, DRY, 20)
	short_race.incidents_enabled = false
	var short_car: GtCar = short_race.cars[0]
	short_car.lap = 4
	short_car.s = 0.9 * 5.0 * track.length
	short_car.fuel = 1.08 * short_car.fuel_use
	check(not GtForecast.fuel_alarm(short_race, short_car), "the crew pick margin on a 5 lap race never rings the alarm on the last lap")
	short_car.fuel = 0.5 * short_car.fuel_use
	check(GtForecast.fuel_alarm(short_race, short_car), "a 5 lap car short of the flag raises the alarm")
	short_race.dispose()
