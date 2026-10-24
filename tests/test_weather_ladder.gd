extends SceneTree

## FASE 11 Langkah 3d acceptance: the weather ladder. The rows, the first tyre change and the box lap come from
## GtWeatherOutlook (pure data over GtWeather.forecast and the live weather); the ribbon chip and the weather deck
## only draw them.
## Run: Godot --headless --path . -s res://tests/test_weather_ladder.gd

const WorldScene := preload("res://scenes/race_weekend_world.tscn")
const DirectorScript := preload("res://scripts/world/race_weekend_director.gd")
const ActorScript := preload("res://scripts/car/gt_car_actor.gd")
const FRAME: float = 1.0 / 60.0

var failures: int = 0
var assertions: int = 0
var world: Node3D
var hud: RaceHud
var race: GtRace
var mine: Array[GtCar] = []


func _initialize() -> void:
	call_deferred("_run")


func check(ok: bool, description: String) -> void:
	assertions += 1
	if not ok:
		failures += 1
		push_error(description)
	print("[%s] %s" % ["PASS" if ok else "FAIL", description])


func _run() -> void:
	world = WorldScene.instantiate()
	root.add_child(world)
	world.set_physics_process(false)
	hud = world.hud
	race = world.race
	race.incidents_enabled = false
	for car: GtCar in race.cars:
		if car.team_id == race.player_team_id:
			mine.append(car)
	world.director._enter(DirectorScript.State.GREEN_RACING)
	for _i: int in range(40):
		world.step(FRAME)
	race.step_ticks(200)
	hud.refresh_all()
	_test_outlook()
	race.dispose()
	world.queue_free()
	await process_frame
	ActorScript._paint_cache.clear()
	print("%d assertions, %d failure(s)" % [assertions, failures])
	print("FASE 11 LANGKAH 3D WEATHER LADDER: %s" % ("PASS" if failures == 0 else "%d FAILURES" % failures))
	quit(0 if failures == 0 else 1)


# --- helpers ---------------------------------------------------------------------------------------------------------

## One forecast entry per lap, lap = index + 1.
func _forecast(rain: Array, water: Array) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	for index: int in range(rain.size()):
		rows.append({"lap": index + 1, "rain_intensity": float(rain[index]), "water_pct": float(water[index]), "cloud_cover": 0.3, "wind_speed": 10.0})
	return rows


## A weather with the given live values and forecast; the archetype only seeds the constructor.
func _weather(live_rain: float, live_water: float, rows: Array[Dictionary]) -> GtWeather:
	var weather := GtWeather.new(10, 1, GtWeather.Archetype.DRY_SUNNY)
	weather.rain_intensity = live_rain
	weather.track_water_pct = live_water
	weather.forecast = rows
	return weather


## Dry until lap 6, drizzle on lap 7 (water 30), a downpour from lap 8 (water 70): the 14 lap case the tests share.
func _case_a() -> GtWeather:
	var rain: Array = [0, 0, 0, 0, 0, 0, 0.3, 0.9, 0.9, 0.9, 0.9, 0.9, 0.9, 0.9]
	var water: Array = [3, 3, 3, 3, 3, 3, 30, 70, 70, 70, 70, 70, 70, 70]
	return _weather(0.0, 3.0, _forecast(rain, water))


# --- GtWeatherOutlook ------------------------------------------------------------------------------------------------

func _test_outlook() -> void:
	var weather: GtWeather = _case_a()
	var rows: Array[Dictionary] = GtWeatherOutlook.ahead(weather, 3, 8)
	var summary: Dictionary = GtWeatherOutlook.summary(rows)
	check(rows.size() == 9 and int(rows[0]["k"]) == 0 and int(rows[0]["lap"]) == 3 and is_equal_approx(float(rows[0]["water"]), 3.0)
			and int(rows[4]["tyre"]) == GtTypes.Compound.INTERMEDIATE and int(rows[5]["tyre"]) == GtTypes.Compound.WET
			and int(summary["tyre_change"]["k"]) == 4 and int(summary["state_change"]["k"]) == 4 and int(summary["box_k"]) == 3
			and is_equal_approx(float(summary["confidence"]), 0.66)
			and absf(GtWeatherOutlook.cone_spread(4) - 12.92) < 0.001 and is_equal_approx(GtWeatherOutlook.confidence(12), 0.3),
		"outlook: the first tyre change, the box lap and the confidence come from the forecast")

	var dry: Array = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
	var dry_water: Array = [3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3]
	var calm: Dictionary = GtWeatherOutlook.summary(GtWeatherOutlook.ahead(_weather(0.0, 3.0, _forecast(dry, dry_water)), 3, 10))
	check((calm["tyre_change"] as Dictionary).is_empty() and (calm["state_change"] as Dictionary).is_empty() and int(calm["box_k"]) == 0
			and is_equal_approx(float(calm["confidence"]), 0.95),
		"outlook: a dry forecast has no tyre change and no box lap")

	var short_race: Array[Dictionary] = GtWeatherOutlook.ahead(weather, 3, 8, 6)
	check(bool(short_race[4]["past_finish"]) and not bool(short_race[3]["past_finish"])
			and (GtWeatherOutlook.summary(short_race)["tyre_change"] as Dictionary).is_empty() and int(GtWeatherOutlook.summary(short_race)["box_k"]) == 0,
		"outlook: laps after the chequered flag never ask for a tyre change")

	var late: Array[Dictionary] = GtWeatherOutlook.ahead(_case_a(), 12, 6)
	var nothing: Array[Dictionary] = []
	var bare: Array[Dictionary] = GtWeatherOutlook.ahead(_weather(0.0, 3.0, nothing), 4, 5)
	check(late.size() == 7 and int(late[5]["lap"]) == 17 and int(late[5]["tyre"]) == GtTypes.Compound.WET
			and bare.size() == 6 and int(bare[5]["tyre"]) == GtTypes.Compound.MEDIUM and is_equal_approx(float(bare[3]["water"]), 3.0),
		"outlook: a short or empty forecast repeats the last value without error")

	var drying_rain: Array = [0, 0, 0, 0, 0, 0, 0]
	var drying_water: Array = [60, 60, 60, 60, 60, 40, 10]
	var drying: Array[Dictionary] = GtWeatherOutlook.ahead(_weather(0.0, 60.0, _forecast(drying_rain, drying_water)), 5, 2)
	var drying_summary: Dictionary = GtWeatherOutlook.summary(drying)
	check(int(drying[0]["tyre"]) == GtTypes.Compound.WET and int(drying[1]["tyre"]) == GtTypes.Compound.INTERMEDIATE
			and int(drying[2]["tyre"]) == GtTypes.Compound.MEDIUM and int(drying_summary["box_k"]) == 1,
		"outlook: a drying track boxes no earlier than one lap ahead")

	check(GtWeatherOutlook.state_of(0.9, 85.0) == 2 and GtWeatherOutlook.state_of(0.2, 10.0) == 1 and GtWeatherOutlook.state_of(0.0, 30.0) == 3
			and GtWeatherOutlook.state_of(0.0, 2.0) == 0 and RaceHud.weather_state(0.9, 85.0) == 2 and GtWeatherOutlook.state_name(2) == "HEAVY RAIN",
		"outlook: weather states keep the HUD's meanings")
