extends SceneTree

## FASE 19 acceptance: the pit wall reads the forecast against the track. The real weather may stray from the
## forecast inside its confidence cone, every team decides with its own strategist, wet tyres are never run
## into a blow-out on a drying track, a puncture boxes the car and limps it home at a realistic pace (or breaks
## the suspension), and the player's desk follows AUTO / MANUAL + COACH / MANUAL without COACH.
## Run: Godot --headless --path . -s res://tests/test_adaptive_tyre_strategy.gd

const TrackScene := preload("res://scenes/race_world/circuits/apex_ring/apex_circuit.tscn")
const RibbonScript := preload("res://scripts/car/track_ribbon.gd")
const PitLaneScript := preload("res://scripts/world/circuits/apex_ring/apex_pit_complex.gd")
const ConfigScript := preload("res://scripts/core/race_config_data.gd")

const DRY: int = GtWeather.Archetype.DRY_SUNNY

var failures: int = 0
var assertions: int = 0
var ribbon: RibbonScript
var track: GtTrack


func _initialize() -> void:
	call_deferred("_run")


func check(ok: bool, description: String) -> void:
	assertions += 1
	if not ok:
		failures += 1
		push_error(description)
	print("[%s] %s" % ["PASS" if ok else "FAIL", description])


func _run() -> void:
	ribbon = TrackScene.instantiate()
	ribbon.road_half_width_m = 7.0
	root.add_child(ribbon)
	track = GtTrack.new(ribbon, 14.0)
	_test_forecast_cone()
	_test_strategist_profiles()
	_test_strategy_decisions()
	_test_drying_race_has_no_wet_blowouts()
	_test_puncture()
	_test_desk_modes()
	ribbon.queue_free()
	await process_frame
	print("%d assertions, %d failure(s)" % [assertions, failures])
	print("FASE 19 ADAPTIVE TYRE STRATEGY: %s" % ("PASS" if failures == 0 else "%d FAILURES" % failures))
	quit(0 if failures == 0 else 1)


# --- helpers ----------------------------------------------------------------------------------------------

func _quiet_race(laps: int = 10, seed_value: int = 5, weather: int = DRY) -> GtRace:
	var race := GtRace.new(track, laps, seed_value, weather)
	race.incidents_enabled = false
	return race


func _park_others(race: GtRace, keep: Array) -> void:
	for index: int in range(race.cars.size()):
		if not keep.has(race.cars[index]):
			race.cars[index].s = -400.0 - float(index) * 30.0
			race.cars[index].prev_s = race.cars[index].s


func _place(car: GtCar, s: float, v: float, lap: int = 1) -> void:
	car.s = s
	car.prev_s = s
	car.v = v
	car.lateral = track.ideal_lateral_at(s)
	car.prev_lateral = car.lateral
	car.target_lateral = car.lateral
	car.lap = lap


## A published forecast for the laps after `lead`: `water` and `rain` per lap ahead (index 0 = one lap ahead).
func _forecast(lead: int, water: Array, rain: Array) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	for k: int in range(water.size()):
		rows.append({"lap": lead + 1 + k, "rain_intensity": float(rain[k]), "water_pct": float(water[k]), "cloud_cover": 0.6, "wind_speed": 12.0})
	return rows


## A strategist that reads the forecast exactly and reacts at once.
func _sharp_profile() -> Dictionary:
	return {"forecast_trust": 1.0, "risk_bias": 0.0, "reaction_sectors": 0, "read_noise": 0.0, "herd": 0.0}


func _ai_car(race: GtRace) -> GtCar:
	for car: GtCar in race.cars:
		if car.team_id != race.player_team_id:
			return car
	return null


func _player_car(race: GtRace) -> GtCar:
	for car: GtCar in race.cars:
		if car.team_id == race.player_team_id:
			return car
	return null


# --- the forecast and the real weather ----------------------------------------------------------------------

func _test_forecast_cone() -> void:
	var same_a := GtWeather.new(12, 9, GtWeather.Archetype.PASSING_SHOWERS)
	var same_b := GtWeather.new(12, 9, GtWeather.Archetype.PASSING_SHOWERS)
	var identical: bool = same_a.truth.size() == same_b.truth.size() and same_a.forecast.size() == same_b.forecast.size()
	for index: int in range(mini(same_a.truth.size(), same_b.truth.size())):
		identical = identical and is_equal_approx(float(same_a.truth[index]["rain_intensity"]), float(same_b.truth[index]["rain_intensity"]))
		identical = identical and is_equal_approx(float(same_a.forecast[index]["rain_intensity"]), float(same_b.forecast[index]["rain_intensity"]))
	check(identical and same_a.truth.size() == same_a.forecast.size(), "forecast: the same seed builds the same real weather and the same forecast")

	# Somewhere across the rainy seeds the real weather strays from the race-start forecast, more far out than near.
	var strayed: int = 0
	var near_error: float = 0.0
	var far_error: float = 0.0
	for seed_value: int in range(1, 25):
		for archetype: int in [GtWeather.Archetype.PASSING_SHOWERS, GtWeather.Archetype.DRY_TO_STORM, GtWeather.Archetype.VARIABLE_CHAOS]:
			var weather := GtWeather.new(12, seed_value, archetype)
			var rain_near: float = absf(float(weather.forecast[1]["rain_intensity"]) - float(weather.truth[1]["rain_intensity"]))
			var rain_far: float = 0.0
			for lap_index: int in range(5, 9):
				rain_far += absf(float(weather.forecast[lap_index]["rain_intensity"]) - float(weather.truth[lap_index]["rain_intensity"]))
			near_error += rain_near
			far_error += rain_far / 4.0
			if rain_far > 0.2:
				strayed += 1
	check(strayed > 0 and far_error > near_error * 2.0,
		"forecast: the real weather strays from the forecast (%d races), the cone widens far out (near %.2f, far %.2f summed rain error)" % [strayed, near_error, far_error])

	# As the race reaches a lap, the radar update makes the next lap's forecast close to the real one.
	var storm := GtWeather.new(12, 4, GtWeather.Archetype.DRY_TO_STORM)
	var before: float = absf(float(storm.forecast[7]["rain_intensity"]) - float(storm.truth[7]["rain_intensity"]))
	storm.publish(7)
	var after: float = absf(float(storm.forecast[7]["rain_intensity"]) - float(storm.truth[7]["rain_intensity"]))
	check(after <= before and after <= 0.1 * maxf(before, 0.01) + 0.011,
		"forecast: on lap 7 the next lap's forecast is nearly the real weather (error %.3f -> %.3f)" % [before, after])

	# A setup preset that reshapes the forecast (WET: steady rain) reshapes the real weather too.
	var cfg: RefCounted = ConfigScript.reset()
	cfg.weather_preset = 2
	cfg.total_laps = 8
	cfg.race_seed = 7
	var wet_race := GtRace.new(track, 8, 7, cfg.weather_archetype(7))
	cfg.apply_weather(wet_race.weather)
	var real_rain: float = 0.0
	for index: int in range(1, 8):
		real_rain += float(wet_race.weather.truth[index]["rain_intensity"]) / 7.0
	wet_race.incidents_enabled = false
	wet_race.step_ticks(20 * 60)
	check(real_rain > 0.15 and wet_race.weather.rain_intensity > 0.1,
		"forecast: the WET preset's steady rain is the real weather the race runs (mean real rain %.2f, live %.2f)" % [real_rain, wet_race.weather.rain_intensity])
	wet_race.dispose()
	ConfigScript.reset()


# --- strategists --------------------------------------------------------------------------------------------

func _test_strategist_profiles() -> void:
	var trusts: Dictionary = {}
	var reactions: Dictionary = {}
	var deterministic: bool = true
	for team_id: int in range(10):
		var prof: Dictionary = GtStrategy.profile(11, team_id)
		deterministic = deterministic and prof == GtStrategy.profile(11, team_id)
		trusts[snappedf(float(prof["forecast_trust"]), 0.01)] = true
		reactions[int(prof["reaction_sectors"])] = true
	check(deterministic and trusts.size() >= 6 and reactions.size() >= 2,
		"strategist: every team has its own deterministic strategist (%d trust levels, %d reaction delays)" % [trusts.size(), reactions.size()])

	var race := _quiet_race(10, 5)
	var state_before: float = race.rng.next()
	var race_b := _quiet_race(10, 5)
	for team_id: int in range(10):
		GtStrategy.profile(race_b.race_seed, team_id)
	check(is_equal_approx(state_before, race_b.rng.next()),
		"strategist: building profiles never draws from the race rng (determinism of the rest of the race)")
	race.dispose()
	race_b.dispose()


func _strategy_case(compound: int, wear: float, water: float, rain: float, ahead_water: Array, ahead_rain: Array, laps: int = 10, lap: int = 3) -> Dictionary:
	var race := _quiet_race(laps, 31)
	var car: GtCar = _ai_car(race)
	_park_others(race, [car])
	_place(car, 400.0 + float(lap) * track.length, 50.0, lap)
	car.compound = compound
	car.wear = wear
	race.weather.track_water_pct = water
	race.weather.rain_intensity = rain
	race.weather.forecast = _forecast(lap + 1, ahead_water, ahead_rain)
	var plan: Dictionary = GtStrategy.plan(race, car, _sharp_profile())
	race.dispose()
	return plan


func _test_strategy_decisions() -> void:
	var dry_now: Dictionary = _strategy_case(GtTypes.Compound.WET, 0.2, 8.0, 0.0, [5.0, 2.0, 0.0], [0.0, 0.0, 0.0])
	check(int(dry_now["compound"]) >= 0 and GtTypes.is_slick(int(dry_now["compound"])),
		"strategy: wets on a drying track (8%% water, dry forecast) box for slicks (%s)" % str(dry_now))

	var damp: Dictionary = _strategy_case(GtTypes.Compound.WET, 0.2, 30.0, 0.05, [26.0, 22.0, 20.0], [0.05, 0.05, 0.0])
	check(int(damp["compound"]) == GtTypes.Compound.INTERMEDIATE,
		"strategy: wets on a damp track (30%% water, no more heavy rain) box for intermediates (%s)" % str(damp))

	var shower_coming: Dictionary = _strategy_case(GtTypes.Compound.INTERMEDIATE, 0.2, 10.0, 0.0, [45.0, 60.0, 55.0], [0.6, 0.7, 0.5])
	check(int(shower_coming["compound"]) < 0,
		"strategy: inters on a dry-ish track stay out when the forecast brings heavy rain next lap (%s)" % str(shower_coming))

	var stay_dry: Dictionary = _strategy_case(GtTypes.Compound.MEDIUM, 0.2, 3.0, 0.0, [2.0, 0.0, 0.0], [0.0, 0.0, 0.0])
	check(int(stay_dry["compound"]) < 0, "strategy: a fresh slick on a dry track stays out (%s)" % str(stay_dry))

	var flooded: Dictionary = _strategy_case(GtTypes.Compound.MEDIUM, 0.2, 60.0, 0.8, [70.0, 70.0, 65.0], [0.8, 0.8, 0.7])
	check(int(flooded["compound"]) == GtTypes.Compound.WET or int(flooded["compound"]) == GtTypes.Compound.INTERMEDIATE,
		"strategy: slicks on a flooded track box for rain tyres (%s)" % str(flooded))

	var cooked: Dictionary = _strategy_case(GtTypes.Compound.WET, 0.55, 6.0, 0.0, [4.0, 2.0, 0.0], [0.0, 0.0, 0.0])
	check(bool(cooked["urgent"]) and int(cooked["compound"]) >= 0,
		"strategy: wets that would blow out before the pit entry are boxed urgently (%s)" % str(cooked))

	var last_lap: Dictionary = _strategy_case(GtTypes.Compound.MEDIUM, 0.2, 30.0, 0.3, [30.0], [0.3], 4, 3)
	check(int(last_lap["compound"]) < 0, "strategy: nobody boxes for the weather on the final lap (%s)" % str(last_lap))

	# CREW PICK (garage start tyre) is the same wall's call, forecast included.
	var picks: Array[int] = []
	for case: Array in [[70.0, [70.0, 70.0]], [30.0, [30.0, 30.0]], [0.0, [0.0, 0.0]], [20.0, [0.0, 0.0]]]:
		var weather := GtWeather.new(5, 3, DRY)
		weather.track_water_pct = float(case[0])
		weather.forecast = _forecast(1, case[1], [0.0, 0.0])
		picks.append(GtStrategy.start_compound(weather, 5, GtCar.new(), GtStrategy.NEUTRAL_PROFILE))
	check(picks[0] == GtTypes.Compound.WET and picks[1] == GtTypes.Compound.INTERMEDIATE and GtTypes.is_slick(picks[2]) and GtTypes.is_slick(picks[3]),
		"strategy: CREW PICK is WET in standing water, INTER on a steady damp track, slicks when dry or drying next lap (%s)" % str(picks))

	# The AI's own lap line call: wets on a damp track (the band the old 45 / 18 / 12 thresholds left empty).
	var race := _quiet_race(10, 31)
	var car: GtCar = _ai_car(race)
	_park_others(race, [car])
	_place(car, 400.0 + 3.0 * track.length, 50.0, 3)
	car.compound = GtTypes.Compound.WET
	race.weather.track_water_pct = 28.0
	race.weather.rain_intensity = 0.04
	race.weather.forecast = _forecast(4, [24.0, 20.0, 18.0], [0.03, 0.0, 0.0])
	race._strategy_profiles[car.team_id] = _sharp_profile()
	race.decide_strategy(car)
	check(car.pit_request == GtTypes.Compound.INTERMEDIATE, "strategy: the AI wall boxes its wets for inters at 28%% water (request %d)" % car.pit_request)
	race.dispose()


# --- a drying race: no team cooks its wet tyres, and the teams do not all box together ---------------------

func _test_drying_race_has_no_wet_blowouts() -> void:
	var blowouts: int = 0
	var spread_ok: int = 0
	var races: int = 0
	for seed_value: int in [4, 11, 18]:
		var race := GtRace.new(track, 8, seed_value, GtWeather.Archetype.WET_DRYING, 20)
		race.incidents_enabled = false
		race.player_team_id = 99 # every car is run by an AI wall
		var call_water: Dictionary = {} # car id -> track water when it called the slick stop
		var call_slots: Dictionary = {} # "lap.sector" of each call
		var was_wet: Dictionary = {}
		for car: GtCar in race.cars:
			was_wet[car.id] = not GtTypes.is_slick(car.compound)
		var guard: int = 0
		while not race.is_finished() and guard < 20 * 60 * 20:
			race.step()
			guard += 1
			for car: GtCar in race.cars:
				if car.is_punctured and not GtTypes.is_slick(car.compound) and not was_wet.has(-car.id - 1):
					was_wet[-car.id - 1] = true
					blowouts += 1
				if car.pit_request >= 0 and GtTypes.is_slick(car.pit_request) and not call_water.has(car.id) and bool(was_wet[car.id]):
					call_water[car.id] = race.weather.track_water_pct
					call_slots["%d.%d" % [car.lap, car.current_sector]] = true
		var lowest: float = INF
		var highest: float = -INF
		for value: float in call_water.values():
			lowest = minf(lowest, value)
			highest = maxf(highest, value)
		races += 1
		if call_water.size() >= 6 and highest - lowest >= 5.0 and call_slots.size() >= 3:
			spread_ok += 1
		print("  seed %d: %d cars called slicks, track water at the call %.0f..%.0f %%, %d lap.sector slots" % [seed_value, call_water.size(), lowest, highest, call_slots.size()])
		race.dispose()
	check(blowouts == 0, "drying race: no car blows a wet or intermediate tyre on the drying track (%d blow-outs in %d races)" % [blowouts, races])
	check(spread_ok >= 2, "drying race: the walls call the slick crossover at different track conditions and moments (%d of %d races spread >= 5 %% water over >= 3 lap.sector slots)" % [spread_ok, races])


# --- puncture ----------------------------------------------------------------------------------------------

func _test_puncture() -> void:
	var entry: float = PitLaneScript.ENTRY_S
	# Half a lap from the pit: the car boxes itself, limps on a realistic pace and gets home.
	var race := _quiet_race(10, 202)
	var car: GtCar = _ai_car(race)
	_park_others(race, [car])
	_place(car, entry + track.length * 1.5, 50.0, 1)
	race.step_ticks(10)
	car.wear = 0.96
	race.step()
	var boxed: bool = car.is_punctured and car.pit_request >= 0
	var top_limp: float = 0.0
	var start_time: float = race.time
	var guard: int = 0
	while guard < 20 * 400 and car.stops == 0 and not car.is_dnf:
		race.step()
		guard += 1
		# Past the first 4 s the car has slowed from its racing speed to the limp.
		if car.is_punctured and car.pit == null and race.time - start_time > 4.0:
			top_limp = maxf(top_limp, car.v)
	check(boxed, "puncture: the car calls its own box stop the moment the tyre goes")
	check(top_limp > 22.0 and top_limp <= 28.5,
		"puncture: the car limps up to ~100 km/h on the straights, not a 55 km/h crawl (peak %.0f km/h)" % (top_limp * 3.6))
	check(car.stops == 1 and not car.is_punctured, "puncture: from half a lap out the car reaches its box and leaves on new tyres (%.0f s)" % (race.time - start_time))
	race.dispose()

	# A car kept out on the flat breaks its suspension from the damage, and the stopped car brings out the VSC.
	race = _quiet_race(10, 202)
	car = _ai_car(race)
	_park_others(race, [car])
	_place(car, 300.0 + track.length, 50.0, 1)
	race.step_ticks(10)
	car.wear = 0.96
	race.step()
	car.wear = 0.5
	var damage_grew: bool = false
	guard = 0
	while not car.is_dnf and guard < 20 * 900:
		car.pit_request = -1
		race.step()
		guard += 1
		damage_grew = damage_grew or car.damage > 20.0
	check(car.is_dnf and car.dnf_reason == "Suspension Failure" and damage_grew,
		"puncture: driving on the flat wrecks the suspension and retires the car (%s, damage %.0f)" % [car.dnf_reason, car.damage])
	check(int(race.race_control["flag"]) == GtTypes.Flag.VSC, "puncture: the car stopped on track brings out the VSC (flag %d)" % int(race.race_control["flag"]))
	race.dispose()

	# A blow-out at speed that spins the car leaves debris: VSC. On the final lap nobody boxes.
	race = _quiet_race(10, 202)
	car = _ai_car(race)
	_park_others(race, [car])
	_place(car, entry + track.length * 1.5, 60.0, 1)
	var spun_vsc: bool = false
	for seed_try: int in range(12):
		race.dispose()
		race = _quiet_race(10, 300 + seed_try)
		car = _ai_car(race)
		_park_others(race, [car])
		_place(car, entry + track.length * 1.5, 60.0, 1)
		race.step()
		car.v = 60.0
		car.wear = 0.96
		race.step()
		if car.spin_timer > 0.0:
			spun_vsc = int(race.race_control["flag"]) == GtTypes.Flag.VSC
			break
	check(spun_vsc, "puncture: a blow-out that spins the car leaves debris and brings out the VSC")
	race.dispose()

	race = _quiet_race(4, 202)
	car = _ai_car(race)
	_park_others(race, [car])
	_place(car, 300.0 + track.length * 3.0, 50.0, 3)
	race.step_ticks(10)
	car.wear = 0.96
	race.step()
	check(car.is_punctured and car.pit_request < 0, "puncture: on the final lap the car limps to the flag instead of boxing")
	race.dispose()


# --- the player's desk ------------------------------------------------------------------------------------

func _desk_case(mode: int, coach: bool) -> Array:
	var race := _quiet_race(10, 31)
	var car: GtCar = _player_car(race)
	_park_others(race, [car])
	_place(car, 400.0, 50.0, 1)
	race.set_tactic_mode(mode)
	race.coach_enabled = coach
	car.wear = 0.7
	car.ers_battery = 0.0
	return [race, car]


func _test_desk_modes() -> void:
	var setup: Array = _desk_case(GtTypes.TacticMode.AUTO, true)
	var race: GtRace = setup[0]
	var car: GtCar = setup[1]
	race.step()
	check(car.pit_request >= 0 and race.latest_suggestion.is_empty(),
		"desk: AUTO calls the stop itself at once, without a decision card (request %d)" % car.pit_request)
	race.dispose()

	setup = _desk_case(GtTypes.TacticMode.MANUAL, true)
	race = setup[0]
	car = setup[1]
	race.step()
	check(not race.latest_suggestion.is_empty() and int(race.latest_suggestion["type"]) == GtTypes.TacticType.PIT and car.pit_request < 0,
		"desk: MANUAL with COACH raises the BOX decision card and waits for the player")
	race.dispose()

	setup = _desk_case(GtTypes.TacticMode.MANUAL, false)
	race = setup[0]
	car = setup[1]
	var radio_before: int = race.radio_history.size()
	race.step()
	var info_lines: Array[String] = []
	for index: int in range(radio_before, race.radio_history.size()):
		info_lines.append(String(race.radio_history[index]["text"]))
	var advice: bool = false
	for line: String in info_lines:
		advice = advice or line.contains("Suggest") or line.contains("Box") or line.contains("BOX")
	check(race.latest_suggestion.is_empty() and car.pit_request < 0 and not info_lines.is_empty() and not advice,
		"desk: MANUAL without COACH gets the facts only, no card and no advice (%s)" % " | ".join(info_lines))

	race.weather.advisory.emit("Radar update: rain front approaching in about 1 lap.", "Prepare INTERMEDIATE tyres.")
	var last: String = String(race.radio_history[race.radio_history.size() - 1]["text"])
	check(not last.contains("Prepare"), "desk: without COACH the weather radar update is information only (%s)" % last)
	race.coach_enabled = true
	race.weather.advisory.emit("Radar update: rain front approaching in about 1 lap.", "Prepare INTERMEDIATE tyres.")
	last = String(race.radio_history[race.radio_history.size() - 1]["text"])
	check(last.contains("Prepare INTERMEDIATE"), "desk: with COACH the radar update carries the engineer's advice (%s)" % last)
	race.dispose()
