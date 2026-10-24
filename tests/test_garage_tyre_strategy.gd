extends SceneTree

## Headless test for the Team Garage tyre strategy (weather-adaptive crew pick, critical mismatch modal,
## team colour accent, wheel selector) and the realistic tyre penalties of the GT sim (straight vs corner,
## aquaplaning, snap oversteer, wets on a dry track).
## Run: godot --headless --path . -s tests/test_garage_tyre_strategy.gd

const TrackScene := preload("res://scenes/race_world/track_circuit.tscn")
const TrackScript := preload("res://scripts/gt/gt_track.gd")
const RaceScript := preload("res://scripts/gt/gt_race.gd")
const WeatherScript := preload("res://scripts/gt/gt_weather.gd")
const Types := preload("res://scripts/gt/gt_types.gd")
const Liveries := preload("res://scripts/car/team_liveries.gd")
const GarageStyle := preload("res://scripts/ui/manga/garage_style.gd")
const MONSOON_WATER: float = 75.0

var assertions: int = 0
var failures: int = 0
var track: TrackScript

func _initialize() -> void:
	_run.call_deferred()

func check(ok: bool, description: String) -> void:
	assertions += 1
	if not ok:
		failures += 1
	print("[%s] %s" % ["PASS" if ok else "FAIL", description])

func _finish() -> void:
	print("\n%d assertions, %d failure(s)" % [assertions, failures])
	if failures == 0:
		print("GARAGE TYRE STRATEGY & MISMATCH MODAL: PASS")
		quit(0)
	else:
		printerr("GARAGE TYRE STRATEGY & MISMATCH MODAL: FAIL")
		quit(1)

func _run() -> void:
	create_timer(240.0).timeout.connect(func():
		check(false, "Timeout: test did not finish in 240 seconds")
		_finish()
	)
	await process_frame

	var config_script: Script = load("res://scripts/core/race_config_data.gd")
	var garage_scene: PackedScene = load("res://scenes/ui/garage_team_select.tscn")

	# -------------------------------------------------------------
	# TEST 1: Monsoon Weather Auto-Defaults to WET and shows Crew Pick
	# -------------------------------------------------------------
	var config1 = config_script.reset()
	config1.weather_preset = 3 # FULL MONSOON
	config1.car1_starting_compound = 0 # Soft initially
	config1.car2_starting_compound = 1 # Medium initially

	var garage1 = garage_scene.instantiate()
	root.add_child(garage1)
	await process_frame

	check(garage1.get_optimal_compound() == Types.Compound.WET, "get_optimal_compound() returns WET for FULL MONSOON")
	check(config1.car1_starting_compound == Types.Compound.WET, "Monsoon auto-defaults car 1 starting compound from Soft to WET")
	check(config1.car2_starting_compound == Types.Compound.WET, "Monsoon auto-defaults car 2 starting compound from Medium to WET")

	var wet_btn_car1: Button = garage1.compound_buttons[0][Types.Compound.WET]
	check(wet_btn_car1.text == "WET ★", "Recommended compound button has star marker (WET ★)")
	check(garage1._compatibility_labels[0].text.contains("OPTIMAL"), "Compatibility label shows OPTIMAL when equipped with WET")

	# -------------------------------------------------------------
	# TEST 2: Changing Car 1 to SOFT triggers Critical Mismatch Warning in UI
	# -------------------------------------------------------------
	garage1.select_compound(0, Types.Compound.SOFT)
	check(config1.car1_starting_compound == Types.Compound.SOFT, "Player can manually choose SOFT in the tyre bay")
	check(garage1._compatibility_labels[0].text.contains("CRITICAL MISMATCH"), "Compatibility label switches to CRITICAL MISMATCH on slicks in monsoon")
	check(garage1._driver_compounds[0].text.contains("CRITICAL HAZARD"), "Driver 1 card starting tyre badge indicates CRITICAL HAZARD")

	var mismatch: Dictionary = garage1._check_critical_mismatch()
	check(mismatch.get("is_mismatch", false) == true, "_check_critical_mismatch() detects hazard when Car 1 has Soft in Monsoon")
	check(mismatch.get("hazard_type", "") == "SLICKS_ON_WET", "Hazard type is accurately flagged as SLICKS_ON_WET")
	check(mismatch.get("car1_mismatch", false) == true and mismatch.get("car2_mismatch", false) == false, "Car 1 flagged as bad while Car 2 remains safe")

	# -------------------------------------------------------------
	# TEST 3: launch() intercepts the launch and pops up Mismatch Modal
	# -------------------------------------------------------------
	garage1.launch()
	check(garage1._launching == false, "launch() intercepted: _launching remains false during critical mismatch")
	check(garage1._mismatch_modal != null and garage1._mismatch_modal.visible == true, "Critical Mismatch Modal is built and visible")
	check(garage1._mismatch_title.text.contains("SLICKS ON MONSOON RAIN"), "Modal displays bold Toon Manga hazard title: SLICKS ON MONSOON RAIN!")

	# Simulate CANCEL [ESC]
	garage1._mismatch_cancel_btn.pressed.emit()
	check(garage1._mismatch_modal.visible == false, "Cancel button successfully hides the modal and returns player to garage")

	# Re-trigger modal and test SLAP WETS ON [CREW REC]
	garage1.launch()
	check(garage1._mismatch_modal.visible == true, "Re-calling launch() displays the modal again")
	garage1._apply_recommended_compounds()
	check(config1.car1_starting_compound == Types.Compound.WET, "SLAP WETS ON automatically fixes Car 1 compound to WET")
	check(config1.car2_starting_compound == Types.Compound.WET, "Both cars fixed to WET")
	garage1._hide_mismatch_modal()
	check(garage1._mismatch_modal.visible == false, "Modal hidden after applying crew fix")

	garage1.queue_free()
	await process_frame

	# -------------------------------------------------------------
	# TEST 4: Sunny Dry Weather - Valid dry swaps do NOT trigger modal
	# -------------------------------------------------------------
	var config2 = config_script.reset()
	config2.weather_preset = 0 # SUNNY DRY
	config2.car1_starting_compound = 0 # Soft
	config2.car2_starting_compound = 1 # Medium

	var garage2 = garage_scene.instantiate()
	root.add_child(garage2)
	await process_frame

	check(garage2.get_optimal_compound() == Types.Compound.MEDIUM, "get_optimal_compound() returns MEDIUM for SUNNY DRY")
	var dry_mismatch: Dictionary = garage2._check_critical_mismatch()
	check(dry_mismatch.get("is_mismatch", false) == false, "Soft vs Medium compound on dry track is NOT a critical mismatch")

	# Test Wet on Dry triggers critical mismatch
	garage2.select_compound(0, Types.Compound.WET)
	var wet_on_dry_mismatch: Dictionary = garage2._check_critical_mismatch()
	check(wet_on_dry_mismatch.get("is_mismatch", false) == true, "WET on bone dry track is flagged as a critical mismatch")
	check(wet_on_dry_mismatch.get("hazard_type", "") == "WETS_ON_DRY", "Hazard type is flagged as WETS_ON_DRY")

	garage2.queue_free()
	await process_frame

	# -------------------------------------------------------------
	# TEST 5: team colour accent and the wheel selector
	# -------------------------------------------------------------
	var config3 = config_script.reset()
	config3.weather_preset = 3
	config3.selected_team_id = 0
	var garage3 = garage_scene.instantiate()
	root.add_child(garage3)
	await process_frame
	check(garage3.style.accent.is_equal_approx(Liveries.color_for(0)), "garage accent starts as the selected team's livery colour")
	garage3.select_team(2)
	await create_timer(0.5).timeout
	check(garage3.style.accent.is_equal_approx(Liveries.color_for(2)), "garage accent fades to the newly selected team's colour")
	check(garage3.style.shadow.is_equal_approx(GarageStyle.CYAN), "a crimson team swaps the hard shadow to cyan so it stays readable")
	garage3.select_team(7)
	await create_timer(0.5).timeout
	check(garage3.style.on_accent.is_equal_approx(Color("#050505")) and garage3.style.shadow.is_equal_approx(GarageStyle.CRIMSON),
			"a white team keeps the crimson shadow and takes ink-coloured type")
	check(garage3.compound_buttons[0].size() == 5 and garage3.compound_buttons[1].size() == 5
			and garage3.compound_buttons[0][4].tread == 2 and garage3.compound_buttons[0][0].tread == 0,
			"each car gets five wheel buttons; WET is grooved and SOFT is a slick")
	garage3.queue_free()
	await process_frame

	# -------------------------------------------------------------
	# TEST 6-9: realistic tyre physics of the GT sim
	# -------------------------------------------------------------
	var ribbon: Node3D = TrackScene.instantiate()
	ribbon.road_half_width_m = 7.0
	root.add_child(ribbon)
	track = TrackScript.new(ribbon, 14.0)
	_physics_checks()
	ribbon.queue_free()
	await process_frame

	_finish()

# --- GT sim helpers ----------------------------------------------------------------

## One race with the last car as the car under test (its target speed is the last one the driving
## model computes in a tick) and every other car parked far behind the grid.
func _scenario(compound: int) -> Array:
	var race := RaceScript.new(track, 10, 5, WeatherScript.Archetype.DRY_SUNNY)
	race.incidents_enabled = false
	var subject: GtCar = race.cars[race.cars.size() - 1]
	for index: int in range(race.cars.size() - 1):
		race.cars[index].s = -400.0 - float(index) * 30.0
		race.cars[index].prev_s = race.cars[index].s
	subject.compound = compound
	subject.lap = 1
	return [race, subject]

func _put(car: GtCar, s: float, v: float) -> void:
	car.s = s
	car.prev_s = s
	car.v = v
	car.lateral = track.ideal_lateral_at(s)
	car.prev_lateral = car.lateral
	car.target_lateral = car.lateral

## One sim tick with the track water held at `water` and no rain.
func _tick(race: RaceScript, water: float) -> void:
	race.weather.track_water_pct = water
	race.weather.rain_intensity = 0.0
	race.step()

## Start and length of the longest stretch of near-straight track.
func _longest_straight() -> Vector2:
	var best_start: float = 0.0
	var best_length: float = 0.0
	var run_start: float = -1.0
	var s: float = 0.0
	while s <= track.length:
		if absf(track.curvature_at(s)) < 0.0025:
			if run_start < 0.0:
				run_start = s
			if s - run_start > best_length:
				best_start = run_start
				best_length = s - run_start
		else:
			run_start = -1.0
		s += 5.0
	return Vector2(best_start, best_length)

func _tightest_corner() -> float:
	var tightest_s: float = 0.0
	var tightest: float = INF
	var s: float = 0.0
	while s < track.length:
		if track.speed_limit_at(s) < tightest:
			tightest = track.speed_limit_at(s)
			tightest_s = s
		s += 5.0
	return tightest_s

func _peak_straight_speed(compound: int, water: float) -> float:
	var straight: Vector2 = _longest_straight()
	var setup: Array = _scenario(compound)
	var race: RaceScript = setup[0]
	var car: GtCar = setup[1]
	_put(car, straight.x + 10.0, 45.0)
	var peak: float = 0.0
	var guard: int = 0
	while car.s < straight.x + straight.y - 30.0 and guard < 800:
		_tick(race, water)
		peak = maxf(peak, car.v)
		guard += 1
	race.dispose()
	return peak

## Target speed the driving model gives the subject at the tightest corner.
func _apex_target(compound: int, water: float) -> float:
	var apex: float = _tightest_corner()
	var setup: Array = _scenario(compound)
	var race: RaceScript = setup[0]
	var car: GtCar = setup[1]
	_put(car, apex, track.speed_limit_at(apex))
	_tick(race, water)
	var target: float = race._driving._target
	race.dispose()
	return target

## Speed shed in one second by a car that is far too fast for the corner it is in.
func _speed_shed_in_a_second(compound: int, water: float) -> float:
	var apex: float = _tightest_corner()
	var setup: Array = _scenario(compound)
	var race: RaceScript = setup[0]
	var car: GtCar = setup[1]
	_put(car, apex, 70.0)
	for _i: int in range(20):
		_tick(race, water)
	var shed: float = 70.0 - car.v
	race.dispose()
	return shed

## Drives the subject alone on a dry track; returns {peak_temp, wear_after_lap, punctured_at_lap}.
func _dry_laps(compound: int, max_laps: float) -> Dictionary:
	var setup: Array = _scenario(compound)
	var race: RaceScript = setup[0]
	var car: GtCar = setup[1]
	_put(car, 5.0, 40.0)
	var peak_temp: float = 0.0
	var wear_after_lap: float = -1.0
	var punctured_at: float = -1.0
	var guard: int = 0
	while car.s < max_laps * track.length and guard < 20 * 60 * 20:
		_tick(race, 0.0)
		peak_temp = maxf(peak_temp, car.tyre_temp)
		if wear_after_lap < 0.0 and car.s >= track.length:
			wear_after_lap = car.wear
		if punctured_at < 0.0 and car.is_punctured:
			punctured_at = car.s / track.length
		guard += 1
	race.dispose()
	return {"peak_temp": peak_temp, "wear_after_lap": wear_after_lap, "punctured_at_lap": punctured_at}

func _physics_checks() -> void:
	var slick_peak: float = _peak_straight_speed(Types.Compound.SOFT, MONSOON_WATER)
	var wet_peak: float = _peak_straight_speed(Types.Compound.WET, MONSOON_WATER)
	check(slick_peak > 240.0 / 3.6, "slicks on a flooded straight still reach > 240 km/h (peak %.0f km/h)" % (slick_peak * 3.6))
	check(slick_peak > wet_peak * 0.95, "a slick's straight-line speed is at least 95 percent of a wet tyre's (%.0f vs %.0f km/h)" % [slick_peak * 3.6, wet_peak * 3.6])

	var slick_wet_apex: float = _apex_target(Types.Compound.SOFT, MONSOON_WATER)
	var slick_dry_apex: float = _apex_target(Types.Compound.SOFT, 0.0)
	var apex_ratio: float = slick_wet_apex / slick_dry_apex
	check(apex_ratio > 0.52 and apex_ratio < 0.66, "slick apex speed in monsoon is 34-48 percent down on the dry (ratio %.2f)" % apex_ratio)

	var slick_shed: float = _speed_shed_in_a_second(Types.Compound.SOFT, MONSOON_WATER)
	var wet_shed: float = _speed_shed_in_a_second(Types.Compound.WET, MONSOON_WATER)
	check(wet_shed / slick_shed >= 2.5, "aquaplaning stretches a slick's braking distance to >= 2.5x a wet tyre's (decel ratio %.2f)" % (wet_shed / slick_shed))

	var apex: float = _tightest_corner()
	var snap_setup: Array = _scenario(Types.Compound.SOFT)
	var snap_race: RaceScript = snap_setup[0]
	var snap_car: GtCar = snap_setup[1]
	_put(snap_car, apex, 60.0)
	_tick(snap_race, MONSOON_WATER)
	check(snap_car.error_timer > 1.5, "a slick carrying far too much speed into a wet corner snaps (error timer %.2f s)" % snap_car.error_timer)
	snap_race.dispose()
	var steady_setup: Array = _scenario(Types.Compound.WET)
	var steady_race: RaceScript = steady_setup[0]
	var steady_car: GtCar = steady_setup[1]
	_put(steady_car, apex, 60.0)
	_tick(steady_race, MONSOON_WATER)
	check(steady_car.error_timer <= 0.0, "the same speed on wet tyres does not snap")
	steady_race.dispose()

	var dry_medium: Dictionary = _dry_laps(Types.Compound.MEDIUM, 3.0)
	var wets_on_dry: Dictionary = _dry_laps(Types.Compound.WET, 3.0)
	check(float(wets_on_dry["peak_temp"]) > 125.0, "wets on a dry track cook past 125 C (peak %.0f C)" % float(wets_on_dry["peak_temp"]))
	check(float(dry_medium["peak_temp"]) < 118.0, "the same laps on mediums stay below 118 C (peak %.0f C)" % float(dry_medium["peak_temp"]))
	var wear_ratio: float = float(wets_on_dry["wear_after_lap"]) / maxf(0.0001, float(dry_medium["wear_after_lap"]))
	check(wear_ratio >= 4.0, "wets on a dry track wear >= 4x faster than mediums over a lap (ratio %.1f)" % wear_ratio)
	check(float(wets_on_dry["punctured_at_lap"]) > 0.0 and float(wets_on_dry["punctured_at_lap"]) <= 3.0, "wets on a dry track puncture within three laps (lap %.1f)" % float(wets_on_dry["punctured_at_lap"]))
	check(float(dry_medium["punctured_at_lap"]) < 0.0, "mediums survive the same three dry laps without a puncture")
