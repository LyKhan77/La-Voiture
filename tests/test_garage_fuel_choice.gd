extends SceneTree

## Fase 32 Task 4: per-car start fuel presets (LIGHT, BALANCED, FULL) in the Team Garage with the crew pick star and the verdict, and the
## hand-off to the race grid (player cars carry the pick, rivals carry the crew pick).
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
	check(is_equal_approx(garage.get_crew_pick_fuel(0), 15.0 * burn * 1.08), "the crew recommends the full distance for this team")
	check(config.car1_fuel_preset == GtFuelPlan.Preset.FULL and config.car2_fuel_preset == GtFuelPlan.Preset.FULL, "both cars start on FULL")
	check(is_equal_approx(config.start_fuel_for(0, burn), 15.0 * burn * 1.08) and is_equal_approx(config.start_fuel_for(1, burn), 15.0 * burn * 1.08), "so a player who touches nothing starts with the whole distance")
	var label: Label = garage.fuel_controls[0]["label"]
	check(label.text.contains("★") and label.text.contains("OK") and label.text.contains("FULL"), "the default shows FULL, the star and an OK verdict (%s)" % label.text)
	var chips: Array = garage.fuel_controls[0]["chips"]
	check(chips.size() == 3 and chips[2].button_pressed and not chips[0].button_pressed and not chips[1].button_pressed, "three preset chips, FULL lit")

	chips[0].pressed.emit()
	check(config.car1_fuel_preset == GtFuelPlan.Preset.LIGHT and chips[0].button_pressed and not chips[1].button_pressed, "LIGHT chip selects LIGHT and lights alone")
	check(label.text.contains("LIGHT") and label.text.contains("WATCH") and not label.text.contains("★"), "LIGHT reads WATCH and carries no star (%s)" % label.text)
	check(is_equal_approx(config.start_fuel_for(0, burn), GtFuelPlan.preset_kg(GtFuelPlan.Preset.LIGHT, 15, burn)), "the config turns the preset into kg for the team")
	garage.fuel_controls[1]["chips"][2].pressed.emit()
	check(config.car2_fuel_preset == GtFuelPlan.Preset.FULL and config.car1_fuel_preset == GtFuelPlan.Preset.LIGHT, "the two cars choose independently")
	chips[0].pressed.emit()
	check(chips[0].button_pressed, "pressing the lit chip again keeps it lit")

	garage.select_team(2)
	await process_frame
	check(config.car1_fuel_preset == GtFuelPlan.Preset.LIGHT, "changing the team keeps the preset")
	check(is_equal_approx(config.start_fuel_for(0, GtData.FUEL_USE[2]), GtFuelPlan.preset_kg(GtFuelPlan.Preset.LIGHT, 15, GtData.FUEL_USE[2])), "and its kg follows the new team's fuel use")
	config.total_laps = 5
	garage._refresh_fuel()
	check(chips[0].disabled and chips[1].disabled and not chips[2].disabled and chips[2].button_pressed, "a 5 lap race disables LIGHT and BALANCED and lights FULL")
	check(label.text.contains("FULL") and label.text.contains("OK") and label.text.contains("★"), "FULL is the crew pick below 10 laps (%s)" % label.text)
	check(is_equal_approx(config.start_fuel_for(0, burn), 5.0 * burn * 1.08), "and the grid load is the full distance")
	config.total_laps = 15
	garage._refresh_fuel()
	check(not chips[0].disabled and chips[0].button_pressed, "back at 15 laps the chips are live again and the pick stands")
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
	config.car1_fuel_preset = GtFuelPlan.Preset.FULL
	config.car2_fuel_preset = GtFuelPlan.Preset.BALANCED
	var race := RaceScript.new(track, 15, 5, DRY, 20)
	config.apply_to_race(race)
	var car1: GtCar = race.get_car(0)
	var car2: GtCar = race.get_car(1)
	check(is_equal_approx(car1.fuel, GtFuelPlan.preset_kg(GtFuelPlan.Preset.FULL, 15, car1.fuel_use)), "car 1 carries its chosen preset on the grid")
	check(is_equal_approx(car2.fuel, GtFuelPlan.crew_pick_kg(15, car2.fuel_use)), "car 2 on BALANCED carries the crew pick")
	var rival: GtCar = null
	for car: GtCar in race.cars:
		if car.team_id != 0:
			rival = car
			break
	check(rival != null and is_equal_approx(rival.fuel, GtFuelPlan.crew_pick_kg(15, rival.fuel_use)), "rivals carry the crew pick")
	config.car1_fuel_preset = 99
	var race2 := RaceScript.new(track, 15, 5, DRY, 20)
	config.apply_to_race(race2)
	check(is_equal_approx(race2.get_car(0).fuel, GtFuelPlan.preset_kg(GtFuelPlan.Preset.FULL, 15, race2.get_car(0).fuel_use)), "an out-of-range preset clamps when it reaches the grid")
	race.dispose()
	race2.dispose()
	ribbon.queue_free()
