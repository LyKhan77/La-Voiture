extends SceneTree

## FASE 5 acceptance: weather, rival pit-wall AI, safety car, wet-track shader,
## pit wall weather widget. Numbers in the descriptions (#1..#20) are the
## TASK-FASE-5 acceptance list.
## Run: Godot --headless --path . -s res://tests/test_weather_and_ai.gd
## Add `-- --with-race-world` to also run the 3 minute test_race_world suite in
## #20 (it needs --fixed-fps 60, which the child process gets).

const SimScript := preload("res://scripts/core/race_sim_engine.gd")
const CarStateScript := preload("res://scripts/core/car_state.gd")
const TireModelScript := preload("res://scripts/core/tire_model.gd")
const WeatherScript := preload("res://scripts/core/weather_manager.gd")
const SafetyCarScript := preload("res://scripts/core/safety_car_director.gd")
const AIScript := preload("res://scripts/core/ai_race_director.gd")
const RaceControlScript := preload("res://scripts/core/race_control.gd")
const WidgetScript := preload("res://scripts/ui/weather_radar_widget.gd")
const WorldScene := preload("res://scenes/test_weather_world.tscn")
const DashboardScene := preload("res://scenes/pit_wall/pit_wall_dashboard.tscn")
const TrackShader := preload("res://assets/shaders/track_ribbon.gdshader")

const Compound := TireModelScript.Compound
const WeatherState := WeatherScript.WeatherState

const PREVIOUS_SUITES: Array[String] = [
	"test_simulation_verification", "test_modular_car", "test_pit_wall",
]

var failures: int = 0
var assertions: int = 0


func _initialize() -> void:
	call_deferred("_run")


func check(ok: bool, description: String) -> void:
	assertions += 1
	if not ok:
		failures += 1
		push_error(description)
	print("[%s] %s" % ["PASS" if ok else "FAIL", description])


func _run() -> void:
	_test_weather_manager()
	_test_grip_in_the_wet()
	_test_ai_decisions()
	_test_rivals_switch_to_wets()
	_test_safety_car_activation()
	_test_safety_car_pack()
	_test_cheap_pit_stop()
	_test_shader_contract()
	await _test_weather_world()
	await _test_pit_wall_widget()
	_test_previous_suites()
	print("%d assertions, %d failure(s)" % [assertions, failures])
	print("FASE 5 ACCEPTANCE: %s" % ("PASS" if failures == 0 else "%d FAILURES" % failures))
	quit(0 if failures == 0 else 1)


# --- helpers --------------------------------------------------------------

func _new_race(laps: int = 30) -> RaceControlScript:
	var engine := SimScript.new(laps)
	engine.setup_standard_race(20)
	return RaceControlScript.new(engine)


func _set_wear(car: CarStateScript, wear: float) -> void:
	car.tire.wear.fill(wear)
	car.tire.average_wear_cached = wear


## Moving field: `count` cars `spacing_m` apart, all at `speed_mps`.
func _new_spread_race(count: int, spacing_m: float, speed_mps: float) -> RaceControlScript:
	var engine := SimScript.new(30)
	for index: int in range(count):
		var car := CarStateScript.new(index, index / 2, "T%d" % index, Compound.SOFT)
		car.total_distance = 2000.0 - spacing_m * float(index)
		car.speed_mps = speed_mps
		car.current_lane = 1
		car.lane_target = 1
		car.lane_position = 1.0
		engine.add_car(car)
	return RaceControlScript.new(engine)


func _order_ids(engine: SimScript) -> Array[int]:
	var ids: Array[int] = []
	var sorted: Array[CarStateScript] = engine.cars.duplicate()
	sorted.sort_custom(func(a: CarStateScript, b: CarStateScript) -> bool:
		return a.total_distance > b.total_distance if a.total_distance != b.total_distance else a.car_id < b.car_id)
	for car: CarStateScript in sorted:
		ids.append(car.car_id)
	return ids


func _pack_length(engine: SimScript) -> float:
	var front: float = -INF
	var back: float = INF
	for car: CarStateScript in engine.cars:
		front = maxf(front, car.total_distance)
		back = minf(back, car.total_distance)
	return front - back


# --- weather manager (#1-#6) ----------------------------------------------

func _test_weather_manager() -> void:
	var weather := WeatherScript.new()
	check(
		weather.state == WeatherState.DRY and weather.weather_wetness_mm == 0.0 and weather.rain_rate_mm_per_sec == 0.0,
		"#1 WeatherManager starts DRY at 0.0 mm"
	)

	var messages: Array[String] = []
	weather.radio_callout.connect(func(message: String, _urgent: bool) -> void: messages.append(message))
	weather.set_state(WeatherState.LIGHT_DRIZZLE)
	var samples: Array[float] = []
	for _block: int in range(3):
		for _second: int in range(30):
			weather.advance(1.0)
		samples.append(weather.weather_wetness_mm)
	check(
		is_equal_approx(weather.rain_rate_mm_per_sec, 0.005) and samples[0] > 0.0
		and samples[0] < samples[1] and samples[1] < samples[2] and is_equal_approx(samples[2], 0.45),
		"#2 drizzle accumulates track water gradually at 0.005 mm/s (%s mm per 30 s)" % str(samples)
	)

	var heavy := WeatherScript.new()
	heavy.set_state(WeatherState.HEAVY_DOWNPOUR)
	for _second: int in range(60):
		heavy.advance(1.0)
	var after_minute: float = heavy.weather_wetness_mm
	for _second: int in range(600):
		heavy.advance(1.0)
	check(
		is_equal_approx(heavy.rain_rate_mm_per_sec, 0.025) and after_minute > 1.0
		and is_equal_approx(heavy.weather_wetness_mm, WeatherScript.MAX_WETNESS_MM),
		"#3 downpour passes 1.0 mm in a minute (%.2f mm) and saturates at 3.5 mm" % after_minute
	)

	heavy.set_state(WeatherState.DRYING)
	var seconds: int = 0
	while heavy.weather_wetness_mm > 0.0 and seconds < 2000:
		heavy.advance(1.0)
		seconds += 1
	check(
		heavy.weather_wetness_mm == 0.0 and heavy.state == WeatherState.DRY and is_equal_approx(heavy.evaporation_rate_mm_per_sec, 0.003),
		"#4 DRYING returns the track to 0.0 mm and the state to DRY (%d s)" % seconds
	)

	var line := WeatherScript.new()
	var outer := WeatherScript.new()
	for weather_case: WeatherScript in [line, outer]:
		weather_case.set_wetness_mm(1.0)
		weather_case.set_state(WeatherState.DRYING)
	var traffic := PackedInt32Array([0, 1, 0])
	for _second: int in range(100):
		line.advance(1.0, traffic)
		outer.advance(1.0)
	var loss_line: float = 1.0 - line.lane_wetness_mm[1]
	var loss_outer: float = 1.0 - line.lane_wetness_mm[0]
	check(
		is_equal_approx(loss_line / loss_outer, WeatherScript.new().racing_line_dry_factor)
		and line.lane_wetness_mm[1] < outer.lane_wetness_mm[1]
		and is_equal_approx(line.lane_wetness_mm[0], line.lane_wetness_mm[2]),
		"#5 racing line dries 2x faster with traffic (%.2f mm vs %.2f outer, %.2f untrafficked)" % [
			line.lane_wetness_mm[1], line.lane_wetness_mm[0], outer.lane_wetness_mm[1]]
	)

	var storm := WeatherScript.new()
	storm.set_state(WeatherState.HEAVY_DOWNPOUR)
	for _second: int in range(300):
		storm.advance(1.0)
	check(
		storm.ambient_temp_c < 25.0 and is_equal_approx(storm.ambient_temp_c, 17.0),
		"#6 ambient temperature falls 25 -> 17 C in a downpour (%.1f C)" % storm.ambient_temp_c
	)

	var once: int = messages.count(WeatherScript.MSG_WET_CROSSOVER)
	check(
		once == 1 and messages.count(WeatherScript.MSG_FLOODING) == 0,
		"radio: crossing 35%% wetness calls out exactly once ('%s')" % WeatherScript.MSG_WET_CROSSOVER
	)
	var flood_messages: Array[String] = []
	var flood := WeatherScript.new()
	flood.radio_callout.connect(func(message: String, _urgent: bool) -> void: flood_messages.append(message))
	flood.set_state(WeatherState.HEAVY_DOWNPOUR)
	check(flood_messages == [WeatherScript.MSG_FLOODING], "radio: entering HEAVY_DOWNPOUR calls 'BOX THIS LAP — TRACK IS FLOODING!'")

	var schedule: Array[Dictionary] = [
		{"t": 0.0, "state": WeatherState.DRY},
		{"t": 250.0, "state": WeatherState.LIGHT_DRIZZLE},
		{"t": 480.0, "state": WeatherState.HEAVY_DOWNPOUR},
	]
	var forecaster := WeatherScript.new()
	forecaster.set_schedule(schedule)
	var forecast: Array[int] = forecaster.get_forecast()
	check(
		forecast.size() == 5 and WidgetScript.format_forecast(forecaster.state, forecast) == "L+3: DRIZZLE | L+5: HEAVY RAIN",
		"5-lap forecast reads 'L+3: DRIZZLE | L+5: HEAVY RAIN' from the schedule"
	)


# --- tire grip in the wet (#8, #11) ---------------------------------------

func _test_grip_in_the_wet() -> void:
	var slick := TireModelScript.new(Compound.SOFT)
	slick.track_wetness_mm = 0.0
	var dry_grip: float = slick.get_average_grip()
	slick.track_wetness_mm = 0.36
	var wet_grip: float = slick.get_average_grip()
	check(
		wet_grip < dry_grip * 0.95,
		"#8 slick loses grip once wetness > 0.35 mm (%.3f -> %.3f)" % [dry_grip, wet_grip]
	)

	# Each compound at its own working temperature, so only the water differs.
	var wets := TireModelScript.new(Compound.WET)
	wets.average_temp_cached = TireModelScript.OPTIMAL_TEMP_CENTER[Compound.WET]
	slick.average_temp_cached = TireModelScript.OPTIMAL_TEMP_CENTER[Compound.SOFT]
	var better_everywhere: bool = true
	var margins: PackedStringArray = []
	for wetness: float in [0.6, 1.0, 2.0]:
		wets.track_wetness_mm = wetness
		slick.track_wetness_mm = wetness
		better_everywhere = better_everywhere and wets.get_average_grip() > slick.get_average_grip()
		margins.append("%.2f vs %.2f" % [wets.get_average_grip(), slick.get_average_grip()])
	check(better_everywhere, "#11 WET compound out-grips slick on wet asphalt at 0.6, 1.0 and 2.0 mm (%s)" % ", ".join(margins))


# --- AI decision tree (#7, #9, #12, #13, #14) -----------------------------

func _test_ai_decisions() -> void:
	var race := _new_race()
	var ai: AIScript = race.ai
	var rivals: Array[CarStateScript] = ai.get_rival_cars()
	var teams: Dictionary = {}
	var only_rivals: bool = true
	for car: CarStateScript in rivals:
		teams[car.team_id] = true
		only_rivals = only_rivals and car.car_id >= AIScript.PLAYER_CAR_COUNT
	check(
		rivals.size() == 18 and teams.size() == 9 and only_rivals,
		"#7 AI Race Director sees %d rival cars from %d teams, none of them the player's" % [rivals.size(), teams.size()]
	)

	var soft: CarStateScript = race.engine.cars[5]
	race.weather.set_wetness_mm(1.2)
	var reason: String = ai.evaluate_car_strategy(soft)
	check(
		reason == AIScript.REASON_WEATHER_WET and soft.box_requested and ai.get_next_compound(soft) == Compound.WET,
		"#9 slick car boxes for WET when wetness passes 0.35 mm (reason %s)" % reason
	)

	var wet_car: CarStateScript = race.engine.cars[6]
	wet_car.tire = TireModelScript.new(Compound.WET)
	wet_car.tire_compound = Compound.WET
	check(ai.evaluate_car_strategy(wet_car) == "" and not wet_car.box_requested, "wet car stays out while the track is still wet")
	race.weather.set_wetness_mm(0.25)
	var other_slick: CarStateScript = race.engine.cars[7]
	check(
		ai.evaluate_car_strategy(other_slick) == "" and ai.evaluate_car_strategy(wet_car) == "",
		"hysteresis: at 0.25 mm neither slicks nor wets pit (window is 0.18-0.35 mm)"
	)
	race.weather.set_wetness_mm(0.10)
	reason = ai.evaluate_car_strategy(wet_car)
	var next_compound: int = ai.get_next_compound(wet_car)
	check(
		reason == AIScript.REASON_WEATHER_SLICK and wet_car.box_requested
		and (next_compound == Compound.MEDIUM or next_compound == Compound.HARD),
		"#12 wet car boxes for MEDIUM/HARD once wetness < 0.18 mm (took %s)" % TireModelScript.COMPOUND_NAMES[next_compound]
	)

	race = _new_race()
	ai = race.ai
	var chaser: CarStateScript = race.engine.cars[4]
	var leader: CarStateScript = race.engine.cars[3]
	_set_wear(chaser, 0.27)
	_set_wear(leader, 0.40)
	chaser.ahead_index = 3
	chaser.gap_ahead_s = 2.5
	var far: String = ai.evaluate_car_strategy(chaser)
	chaser.gap_ahead_s = 1.2
	_set_wear(leader, 0.80)
	var fresh_ahead: String = ai.evaluate_car_strategy(chaser)
	var chasing_mode: bool = chaser.engine_mode == CarStateScript.EngineMode.PUSH and chaser.pace_mode == CarStateScript.PaceMode.ATTACK
	_set_wear(leader, 0.40)
	reason = ai.evaluate_car_strategy(chaser)
	check(
		far == "" and fresh_ahead == "" and reason == AIScript.REASON_UNDERCUT and chaser.box_requested and chasing_mode,
		"#13 AI undercuts only inside 1.8 s of a worn (<45%%) car, and pushes while it chases (far '%s', fresh '%s', now '%s')" % [far, fresh_ahead, reason]
	)

	var worn: CarStateScript = race.engine.cars[9]
	_set_wear(worn, 0.23)
	var before: String = ai.evaluate_car_strategy(worn)
	_set_wear(worn, 0.20)
	reason = ai.evaluate_car_strategy(worn)
	check(
		before == "" and reason == AIScript.REASON_TIRE_CLIFF and worn.box_requested,
		"#14 AI boxes when average tire wear drops under 22% (23% stays out, 20% boxes)"
	)

	var hot: CarStateScript = race.engine.cars[10]
	hot.tire.average_temp_cached = 110.0
	ai.evaluate_car_strategy(hot)
	var overheated: bool = hot.engine_mode == CarStateScript.EngineMode.ECO and hot.pace_mode == CarStateScript.PaceMode.CONSERVE
	hot.tire.average_temp_cached = 101.0
	ai.evaluate_car_strategy(hot)
	var held: bool = hot.engine_mode == CarStateScript.EngineMode.ECO
	hot.tire.average_temp_cached = 90.0
	ai.evaluate_car_strategy(hot)
	check(
		overheated and held and hot.engine_mode == CarStateScript.EngineMode.STANDARD,
		"engine mode: tires over 105 C drop to ECO, hold it until under 98 C, then return to STANDARD"
	)

	var thirsty: CarStateScript = race.engine.cars[11]
	thirsty.fuel.remaining_kg = 3.0
	check(
		ai.evaluate_car_strategy(thirsty) == AIScript.REASON_LOW_FUEL and thirsty.box_requested,
		"low fuel (< 5 kg) boxes the car"
	)

	# Optional stops (undercut) wait out the crossover window instead of buying tires
	# the weather is about to make wrong.
	var damp_chaser: CarStateScript = race.engine.cars[12]
	var damp_leader: CarStateScript = race.engine.cars[13]
	damp_chaser.tire = TireModelScript.new(Compound.WET)
	damp_chaser.tire_compound = Compound.WET
	_set_wear(damp_chaser, 0.27)
	_set_wear(damp_leader, 0.40)
	damp_chaser.ahead_index = 13
	damp_chaser.gap_ahead_s = 1.0
	race.weather.set_wetness_mm(0.4)
	var in_window: String = ai.evaluate_car_strategy(damp_chaser)
	race.weather.set_wetness_mm(0.8)
	var settled_wet: String = ai.evaluate_car_strategy(damp_chaser)
	race.weather.set_wetness_mm(0.0)
	check(
		in_window == "" and settled_wet == AIScript.REASON_UNDERCUT,
		"undercut waits out the weather crossover (0.4 mm -> '%s', 0.8 mm -> '%s')" % [in_window, settled_wet]
	)


# --- all 18 rivals actually change tires (#10) -----------------------------

func _test_rivals_switch_to_wets() -> void:
	var race := _new_race()
	race.weather.set_state(WeatherState.LIGHT_DRIZZLE)
	race.weather.set_wetness_mm(0.6)
	race.step_ticks(60 * 100)
	var wets: int = 0
	var clean_pit: bool = true
	for car: CarStateScript in race.ai.get_rival_cars():
		if car.tire.compound == Compound.WET and car.tire_compound == Compound.WET:
			wets += 1
		clean_pit = clean_pit and not car.is_in_pit and not car.box_requested
	var player_untouched: bool = true
	for index: int in range(AIScript.PLAYER_CAR_COUNT):
		player_untouched = player_untouched and race.engine.cars[index].tire.compound != Compound.WET and not race.engine.cars[index].box_requested
	check(
		wets == 18 and race.ai.pit_stops_completed == 18 and clean_pit and player_untouched,
		"#10 all %d rivals are on WET tires after a drizzle crossover, 18 stops served, player cars left alone" % wets
	)


# --- safety car (#15-#18) --------------------------------------------------

func _test_safety_car_activation() -> void:
	var race := _new_race()
	var director: SafetyCarScript = race.safety_car
	race.weather.set_wetness_mm(2.5)
	director.on_tick()
	var quiet: bool = not director.is_active and director.race_flag == SafetyCarScript.RaceFlag.GREEN
	race.weather.set_wetness_mm(3.0)
	director.on_tick()
	check(
		quiet and director.is_active and director.race_flag == SafetyCarScript.RaceFlag.YELLOW_FLAG
		and director.reason == SafetyCarScript.REASON_STORM and not director.is_overtaking_allowed(),
		"#15 safety car deploys in an extreme storm (> 2.8 mm): YELLOW_FLAG, overtaking disabled"
	)

	race.weather.set_wetness_mm(0.5)
	for _tick: int in range(int(SafetyCarScript.MIN_DURATION_S * 60.0) + 60):
		director.on_tick()
	check(
		not director.is_active and director.race_flag == SafetyCarScript.RaceFlag.GREEN and director.is_overtaking_allowed(),
		"safety car comes in after its minimum 120 s once the storm has cleared"
	)

	var incident := _new_race()
	incident.safety_car.report_incident(7)
	check(
		incident.safety_car.is_active and incident.safety_car.reason.begins_with(SafetyCarScript.REASON_INCIDENT),
		"a race incident deploys the safety car too"
	)

	var stranded := _new_race()
	stranded.engine.cars[3].is_out_of_fuel = true
	stranded.step_ticks(1)
	check(
		stranded.safety_car.is_active and stranded.safety_car.reason == "%s CAR #04" % SafetyCarScript.REASON_INCIDENT,
		"a car stranded out of fuel is reported and brings the safety car out"
	)


## 90 s of a moving field whose last car is faster than the rest, so a pass is
## what would happen without the safety car. Returns the measurements.
func _run_pack(deploy_safety_car: bool) -> Dictionary:
	var race := _new_spread_race(10, 80.0, 60.0)
	race.engine.cars[9].driver_skill = 1.04
	race.step_ticks(600)
	var engine: SimScript = race.engine
	var result: Dictionary = {"pace_before": 0.0, "spread_before": _pack_length(engine), "flips": 0, "peak_after_settle": 0.0, "closest_gap": INF}
	for car: CarStateScript in engine.cars:
		result.pace_before = maxf(result.pace_before, car.speed_mps)
	if deploy_safety_car:
		race.safety_car.deploy("TEST")
	var order_at_start: Array[int] = _order_ids(engine)
	for tick: int in range(60 * 90):
		race.step_ticks(1)
		if _order_ids(engine) != order_at_start:
			result.flips += 1
		if tick >= 60 * 8:
			for car: CarStateScript in engine.cars:
				result.peak_after_settle = maxf(result.peak_after_settle, car.speed_mps)
	var by_distance: Array[CarStateScript] = engine.cars.duplicate()
	by_distance.sort_custom(func(a: CarStateScript, b: CarStateScript) -> bool: return a.total_distance > b.total_distance)
	for index: int in range(1, by_distance.size()):
		result.closest_gap = minf(result.closest_gap, by_distance[index - 1].total_distance - by_distance[index].total_distance)
	result.spread_after = _pack_length(engine)
	return result


func _test_safety_car_pack() -> void:
	var green: Dictionary = _run_pack(false)
	var neutral: Dictionary = _run_pack(true)
	check(
		green.flips > 0 and green.peak_after_settle > SafetyCarScript.SPEED_LIMIT_MPS,
		"control: without the safety car the faster tail car passes (%d order changes) and tops %.0f km/h" % [
			green.flips, green.peak_after_settle * 3.6]
	)
	check(
		neutral.pace_before > 40.0 and neutral.peak_after_settle <= SafetyCarScript.SPEED_LIMIT_MPS + 1e-6,
		"#16 every car obeys 120 km/h under the safety car (%.1f km/h before, %.1f km/h peak after settling)" % [
			neutral.pace_before * 3.6, neutral.peak_after_settle * 3.6]
	)
	check(
		neutral.flips == 0,
		"#17 nobody overtakes under the yellow flag (%d order changes in 90 s)" % neutral.flips
	)
	check(
		neutral.spread_after < neutral.spread_before * 0.5 and neutral.closest_gap > 3.0,
		"#18 pack compresses behind the safety car (%.0f m -> %.0f m long, closest gap %.1f m)" % [
			neutral.spread_before, neutral.spread_after, neutral.closest_gap]
	)


func _test_cheap_pit_stop() -> void:
	var race := _new_race()
	race.step_ticks(60 * 60)
	var green_pace: float = _field_pace(race, 60 * 60)
	race.safety_car.deploy("TEST")
	race.step_ticks(60 * 20)
	var neutral_pace: float = _field_pace(race, 60 * 30)
	var green_loss: float = AIScript.estimate_pit_loss_s(green_pace)
	var neutral_loss: float = AIScript.estimate_pit_loss_s(neutral_pace)
	check(
		neutral_loss < green_loss * 0.6,
		"safety car pit stop is cheap: %.1f s lost vs %.1f s under green" % [neutral_loss, green_loss]
	)

	var worn: CarStateScript = race.engine.cars[8]
	_set_wear(worn, 0.5)
	check(
		race.ai.evaluate_car_strategy(worn) == AIScript.REASON_SAFETY_CAR,
		"AI takes the cheap stop for worn (<60%) tires while the safety car is out"
	)


## Mean distance the field covers per second over the next `ticks`.
func _field_pace(race: RaceControlScript, ticks: int) -> float:
	var start: float = 0.0
	for car: CarStateScript in race.engine.cars:
		start += car.total_distance
	race.step_ticks(ticks)
	var finish: float = 0.0
	for car: CarStateScript in race.engine.cars:
		finish += car.total_distance
	return (finish - start) / float(race.engine.cars.size()) / (float(ticks) / 60.0)


# --- shader (#19) ----------------------------------------------------------

func _test_shader_contract() -> void:
	var code: String = TrackShader.code
	var material := ShaderMaterial.new()
	material.shader = TrackShader
	material.set_shader_parameter("track_wetness", 0.7)
	check(
		code.contains("uniform float track_wetness : hint_range(0.0, 1.0) = 0.0;")
		and is_equal_approx(float(material.get_shader_parameter("track_wetness")), 0.7),
		"#19 track_ribbon shader exposes track_wetness (0..1) and the material accepts it"
	)
	check(
		code.contains("uniform float dry_roughness : hint_range(0.0, 1.0) = 0.85;")
		and code.contains("uniform float wet_roughness : hint_range(0.0, 1.0) = 0.15;")
		and code.contains("ROUGHNESS = mix(dry_roughness, wet_roughness, wet_amount);")
		and code.contains("puddle") and code.contains("uniform float rain_intensity : hint_range(0.0, 1.0) = 0.0;"),
		"#19 shader drives ROUGHNESS from 0.85 (dry) to 0.15 (wet) with puddle noise and rain ripples"
	)


# --- integration: 3D world and pit wall ------------------------------------

func _test_weather_world() -> void:
	var world: Node3D = WorldScene.instantiate()
	root.add_child(world)
	await physics_frame
	var road := world.get_node("TrackCircuit/RoadMesh") as MeshInstance3D
	check(
		road.material_override == world.track_material and world.track_material.shader == TrackShader,
		"3D world: the ribbon road uses the wet-track shader material"
	)
	var dry_wetness: float = float(world.track_material.get_shader_parameter("track_wetness"))
	var none: Array[Dictionary] = []
	world.control.weather.set_schedule(none)
	world.control.weather.set_state(WeatherState.HEAVY_DOWNPOUR)
	world.control.weather.set_wetness_mm(1.0)
	await physics_frame
	await physics_frame
	var wet: float = float(world.track_material.get_shader_parameter("track_wetness"))
	var rain: MangaRain3D = world.get_node("MangaRain")
	check(
		dry_wetness == 0.0 and is_equal_approx(wet, 1.0) and world.rain_intensity > 0.9 and rain.is_raining()
		and is_equal_approx(float(world.track_material.get_shader_parameter("rain_intensity")), world.rain_intensity),
		"3D world: heavy rain drives track_wetness (%.2f -> %.2f), road ripples and the rain particles" % [dry_wetness, wet]
	)
	var streaks: GPUParticles3D = rain.get_node("Streaks")
	check(
		streaks.local_coords == false and streaks.amount_ratio > 0.9 and rain.get_parent() == world and rain.get_children().all(func(node: Node) -> bool: return not node is CanvasItem),
		"3D rain is world-space GPUParticles3D (no 2D overlay): %d drops at ratio %.2f" % [streaks.amount, streaks.amount_ratio]
	)
	world.set_time_scale(8.0)
	for _frame: int in range(30):
		await physics_frame
	var sprayers: int = world._sprays.filter(func(spray: MangaRoadSpray) -> bool: return spray.emitting).size()
	check(
		rain.get_camera_velocity().length() > 5.0 and sprayers > 0,
		"3D rain tracks the camera velocity (%.0f m/s) and %d cars throw road spray" % [rain.get_camera_velocity().length(), sprayers]
	)
	world.control.weather.set_state(WeatherState.DRY)
	world.control.weather.set_wetness_mm(0.0)
	await physics_frame
	check(not rain.is_raining(), "3D world: rain stops when the weather clears")
	world.queue_free()
	await process_frame


func _test_pit_wall_widget() -> void:
	var dashboard: Control = DashboardScene.instantiate()
	root.add_child(dashboard)
	await process_frame
	await process_frame
	var session = dashboard.session
	session.paused = true
	session.set_process(false)
	var radio: Array[String] = []
	session.radio_transmission.connect(func(_car_id: int, message: String, _urgent: bool) -> void: radio.append(message))
	var none: Array[Dictionary] = []
	session.control.weather.set_schedule(none)
	session.control.weather.set_state(WeatherState.LIGHT_DRIZZLE)
	session.control.weather.set_wetness_mm(0.34)
	session.control.step_ticks(240)
	session.control.weather.set_state(WeatherState.HEAVY_DOWNPOUR)
	session.control.weather.set_wetness_mm(0.42)
	session.publish()
	var widget: Control = dashboard._weather_widget
	check(
		WidgetScript.format_status(WeatherState.DRY, 0.0, 25.0).contains("☀️ DRY")
		and WidgetScript.format_status(WeatherState.LIGHT_DRIZZLE, 0.2, 22.0).contains("🌦️ DRIZZLE")
		and WidgetScript.format_status(WeatherState.DRYING, 0.2, 21.0).contains("🌤️ DRYING")
		and widget.status_label.text.contains("🌧️ RAIN (WET 42%)"),
		"pit wall ribbon shows the weather status icons (now '%s')" % widget.status_label.text
	)
	check(
		radio.has(WeatherScript.MSG_WET_CROSSOVER) and radio.has(WeatherScript.MSG_FLOODING),
		"pit wall radio carries 'TRACK WETNESS EXCEEDING 35% — BOX FOR WETS!' and the flooding call"
	)
	session.control.safety_car.deploy("EXTREME RAIN")
	session.publish()
	check(
		dashboard._ribbon_flag.text == "■ YELLOW FLAG // SAFETY CAR" and radio.any(func(message: String) -> bool: return message.begins_with("SAFETY CAR DEPLOYED")),
		"pit wall flag turns YELLOW FLAG // SAFETY CAR and radio announces the deployment"
	)
	dashboard.queue_free()
	await process_frame


# --- regression (#20) ------------------------------------------------------

func _test_previous_suites() -> void:
	var project: String = ProjectSettings.globalize_path("res://")
	var suites: Array[String] = PREVIOUS_SUITES.duplicate()
	var with_world: bool = "--with-race-world" in OS.get_cmdline_user_args()
	if with_world:
		suites.append("test_race_world")
	var all_pass: bool = true
	var summary: PackedStringArray = []
	for suite: String in suites:
		var arguments: PackedStringArray = ["--headless"]
		if suite == "test_race_world":
			arguments.append_array(["--fixed-fps", "60"])
		arguments.append_array(["--path", project, "-s", "res://tests/%s.gd" % suite])
		var output: Array = []
		var code: int = OS.execute(OS.get_executable_path(), arguments, output)
		all_pass = all_pass and code == 0
		summary.append("%s=%s" % [suite, "PASS" if code == 0 else "FAIL(%d)" % code])
	check(
		all_pass,
		"#20 earlier suites still pass with no regression: %s%s" % [
			", ".join(summary), "" if with_world else " (test_race_world: run with -- --with-race-world)"]
	)
