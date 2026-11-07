extends SceneTree

## Fase 32 Task 4: per-car start fuel in the Team Garage with a crew pick, the verdict, the clamp, and the hand-off to
## the race grid (player cars carry the pick, rivals carry the crew pick).
## Run: godot --headless --path . -s res://tests/test_garage_fuel_choice.gd

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
	await process_frame
	var config_script: Script = load("res://scripts/core/race_config_data.gd")
	var garage_scene: PackedScene = load("res://scenes/ui/garage_team_select.tscn")
	_test_verdict_function()
	var config = config_script.reset()
	config.total_laps = 15
	config.weather_preset = 0
	config.selected_team_id = 0
	var garage = garage_scene.instantiate()
	root.add_child(garage)
	await process_frame
	var burn: float = GtData.FUEL_USE[0]
	check(is_equal_approx(garage.get_crew_pick_fuel(0), GtFuelPlan.crew_pick_kg(15, burn)), "the garage crew pick is the fuel plan's pick for this team")
	check(config.car1_start_fuel_kg == -1.0 and config.car2_start_fuel_kg == -1.0, "both cars start on the crew pick")
	var label: Label = garage.fuel_controls[0]["label"]
	check(label.text.contains("★") and label.text.contains("OK"), "the crew pick shows the star and an OK verdict (%s)" % label.text)

	garage.select_fuel(0, -5.0)
	check(config.car1_start_fuel_kg == 0.0, "negative fuel clamps to empty")
	garage.select_fuel(0, 9999.0)
	check(config.car1_start_fuel_kg == Types.TANK_CAP_KG, "huge fuel clamps to the tank cap")
	garage.select_fuel(1, 6.0)
	check(config.car2_start_fuel_kg == 6.0 and config.car1_start_fuel_kg == Types.TANK_CAP_KG, "the two cars choose independently")
	var low_label: Label = garage.fuel_controls[1]["label"]
	check(low_label.text.contains("DANGER"), "a load too small to reach the stop window shows DANGER and is still allowed (%s)" % low_label.text)

	garage.select_fuel(0, garage.get_crew_pick_fuel(0))
	var before: float = config.car1_start_fuel_kg
	garage.fuel_controls[0]["up"].pressed.emit()
	check(is_equal_approx(config.car1_start_fuel_kg, before + 2.0), "the up button adds 2 kg")
	garage.fuel_controls[0]["down"].pressed.emit()
	garage.fuel_controls[0]["down"].pressed.emit()
	check(is_equal_approx(config.car1_start_fuel_kg, before - 2.0), "the down button takes 2 kg")

	garage.select_fuel(0, 77.0)
	garage.select_team(2)
	await process_frame
	check(config.car1_start_fuel_kg == 77.0, "changing the team leaves a manual pick alone")
	check(is_equal_approx(garage.get_crew_pick_fuel(0), GtFuelPlan.crew_pick_kg(15, GtData.FUEL_USE[2])), "the crew pick follows the new team's fuel use")
	garage.queue_free()
	await process_frame

	_test_hand_off_to_the_grid(config_script)
	quit(1 if failures else 0)


func _test_verdict_function() -> void:
	var burn: float = 3.0
	check(GtForecast.start_fuel_verdict(GtFuelPlan.crew_pick_kg(15, burn), 15, burn) == GtForecast.OK, "the crew pick on a 15 lap race is OK")
	check(GtForecast.start_fuel_verdict(2.0 * burn, 15, burn) == GtForecast.DANGER, "less than the window-open distance is DANGER")
	check(GtForecast.start_fuel_verdict(4.0 * burn, 15, burn) == GtForecast.WATCH, "an early forced stop is WATCH")
	check(GtForecast.start_fuel_verdict(GtFuelPlan.crew_pick_kg(5, burn), 5, burn) == GtForecast.OK, "the crew pick on a 5 lap race is OK")
	check(GtForecast.start_fuel_verdict(4.0 * burn, 5, burn) == GtForecast.DANGER, "short of the flag on a 5 lap race is DANGER")


func _test_hand_off_to_the_grid(config_script: Script) -> void:
	var ribbon: Node = TrackScene.instantiate()
	ribbon.road_half_width_m = 7.0
	root.add_child(ribbon)
	var track := TrackScript.new(ribbon, 14.0)
	var config = config_script.reset()
	config.total_laps = 15
	config.selected_team_id = 0
	config.car1_start_fuel_kg = 31.0
	config.car2_start_fuel_kg = -1.0
	var race := RaceScript.new(track, 15, 5, DRY, 20)
	config.apply_to_race(race)
	var car1: GtCar = race.get_car(0)
	var car2: GtCar = race.get_car(1)
	check(is_equal_approx(car1.fuel, 31.0), "car 1 carries its chosen fuel on the grid")
	check(is_equal_approx(car2.fuel, GtFuelPlan.crew_pick_kg(15, car2.fuel_use)), "car 2 on the crew pick carries the crew pick")
	var rival: GtCar = null
	for car: GtCar in race.cars:
		if car.team_id != 0:
			rival = car
			break
	check(rival != null and is_equal_approx(rival.fuel, GtFuelPlan.crew_pick_kg(15, rival.fuel_use)), "rivals carry the crew pick")
	config.car1_start_fuel_kg = 9999.0
	var race2 := RaceScript.new(track, 15, 5, DRY, 20)
	config.apply_to_race(race2)
	check(race2.get_car(0).fuel == Types.TANK_CAP_KG, "an out-of-range pick is clamped when it reaches the grid")
	race.dispose()
	race2.dispose()
	ribbon.queue_free()
