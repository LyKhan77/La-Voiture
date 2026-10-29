extends SceneTree

## FASE 11 Langkah 3d acceptance: the weather ladder. The rows, the first tyre change and the box lap come from
## GtWeatherOutlook (pure data over GtWeather.forecast and the live weather); the ribbon chip and the weather deck
## only draw them.
## Run: Godot --headless --path . -s res://tests/test_weather_ladder.gd

const WorldScene := preload("res://scenes/race_weekend_world.tscn")
const DirectorScript := preload("res://scripts/world/weekend/race_weekend_director.gd")
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
	_test_chip()
	_test_deck()
	_test_hud()
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

	# Review: a box call on the chequered lap is no use, so a change that only fits then is not offered.
	var last_rain: Array = [0, 0, 0, 0, 0, 0]
	var last_water: Array = [3, 3, 3, 70, 70, 70]
	var final_weather: GtWeather = _weather(0.0, 3.0, _forecast(last_rain, last_water))
	var final_rows: Array[Dictionary] = GtWeatherOutlook.ahead(final_weather, 3, 3, 4)
	var final_summary: Dictionary = GtWeatherOutlook.summary(final_rows)
	var roomy: Dictionary = GtWeatherOutlook.summary(GtWeatherOutlook.ahead(final_weather, 3, 3, 5))
	check(not bool(final_rows[1]["box_ok"]) and (final_summary["tyre_change"] as Dictionary).is_empty() and int(final_summary["box_k"]) == 0
				and int(final_summary["state_change"]["k"]) == 1 and int(roomy["box_k"]) == 1,
		"outlook: no tyre change is offered for a box call on the chequered lap")

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


# --- ribbon chip -----------------------------------------------------------------------------------------------------

func _test_chip() -> void:
	var chip := WeatherRadarWidget.new()
	root.add_child(chip)
	var rows: Array[Dictionary] = GtWeatherOutlook.ahead(_case_a(), 3, 7)
	chip.update_outlook(rows, GtWeatherOutlook.summary(rows), 24.0, 31.0)
	var cols: Array[Dictionary] = chip.columns
	check(cols.size() == 8 and cols[0]["tag"] == "NOW" and cols[3]["tag"] == "BOX" and bool(cols[4]["crossover"]) and not bool(cols[3]["crossover"])
			and int(cols[4]["tyre"]) == GtTypes.Compound.INTERMEDIATE and int(cols[5]["tyre"]) == GtTypes.Compound.WET
			and chip.forecast_label.text.contains("DRIZZLE L+4"),
		"chip: the ladder marks NOW, the box lap and the crossover column (%s)" % chip.forecast_label.text)
	var animated: bool = chip.is_processing()

	var quiet: Array = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
	var quiet_water: Array = [3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3]
	var calm_rows: Array[Dictionary] = GtWeatherOutlook.ahead(_weather(0.0, 3.0, _forecast(quiet, quiet_water)), 3, 7)
	chip.update_outlook(calm_rows, GtWeatherOutlook.summary(calm_rows), 24.0, 31.0)
	var tags: String = ""
	for column: Dictionary in chip.columns:
		tags += String(column["tag"])
	check(tags == "NOW" and chip.forecast_label.text.contains("STABLE"), "chip: a dry forecast shows no box tag")

	var short_rows: Array[Dictionary] = GtWeatherOutlook.ahead(_case_a(), 3, 7, 5)
	chip.update_outlook(short_rows, GtWeatherOutlook.summary(short_rows), 24.0, 31.0)
	check(bool(chip.columns[3]["dim"]) and chip.columns[3]["tag"] == "" and not bool(chip.columns[2]["dim"]) and not bool(chip.columns[3]["crossover"]),
		"chip: columns after the flag are dimmed and untagged")

	var clicks: Array[int] = []
	chip.clicked.connect(func() -> void: clicks.append(1))
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	chip._gui_input(press)
	check(clicks.size() == 1 and WeatherRadarWidget.format_forecast(0, [0, 0, 1, 1, 2]) == "L+3: DRIZZLE | L+5: HEAVY RAIN",
		"chip: a click emits clicked and the old forecast text format stays")

	PresentationSettings.reduce_motion = true
	chip.update_outlook(rows, GtWeatherOutlook.summary(rows), 24.0, 31.0)
	var still: bool = not chip.is_processing()
	PresentationSettings.reduce_motion = false
	chip.update_outlook(rows, GtWeatherOutlook.summary(rows), 24.0, 31.0)
	check(animated and still and chip.is_processing(), "chip: rain and pulses animate, and reduce motion stops them")
	chip.queue_free()


# --- weather deck ----------------------------------------------------------------------------------------------------

func _snapshot() -> Dictionary:
	return {"air": 24.0, "track": 31.0, "humidity": 52.0, "wind_kmh": 18.0, "wind_dir": 0.0, "water": 3.0, "drying_line": 0.0}


func _test_deck() -> void:
	var deck := WeatherDeck.new()
	root.add_child(deck)
	var opened: bool = false
	deck.set_open(true)
	opened = deck.visible and deck.is_open
	deck.toggle()
	check(opened and not deck.is_open and not deck.visible, "deck: the weather deck opens and toggles shut")

	var picks: Array[Vector2i] = []
	deck.tyres_chosen.connect(func(compound: int, box_k: int) -> void: picks.append(Vector2i(compound, box_k)))
	deck.set_open(true)
	var rows: Array[Dictionary] = GtWeatherOutlook.ahead(_case_a(), 3, 10)
	deck.update_outlook(rows, GtWeatherOutlook.summary(rows), _snapshot())
	var button_text: String = deck.action_button.text
	var offered: bool = deck.action_button.visible
	deck.action_button.pressed.emit()
	check(deck.next_label.text.contains("DRIZZLE IN ~4 LAPS") and deck.next_label.text.contains("confidence 66%") and deck.next_label.text.contains("INTERMEDIATE")
			and offered and button_text == "SET TYRES  L+3 > INTERMEDIATE" and picks == [Vector2i(GtTypes.Compound.INTERMEDIATE, 3)],
		"deck: the weather deck names the next change and offers the tyre for the box lap (%s)" % deck.next_label.text.replace("\n", " / "))
	var animated: bool = deck.is_processing()

	var quiet: Array = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
	var quiet_water: Array = [3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3]
	var calm_rows: Array[Dictionary] = GtWeatherOutlook.ahead(_weather(0.0, 3.0, _forecast(quiet, quiet_water)), 3, 10)
	deck.update_outlook(calm_rows, GtWeatherOutlook.summary(calm_rows), _snapshot())
	var calm_text: String = deck.next_label.text
	var calm_offered: bool = deck.action_button.visible
	var short_rows: Array[Dictionary] = GtWeatherOutlook.ahead(_case_a(), 3, 10, 6)
	deck.update_outlook(short_rows, GtWeatherOutlook.summary(short_rows), _snapshot())
	check(calm_text.contains("NO CHANGE IN 10 LAPS") and calm_text.contains("confidence 95%") and not calm_offered and not deck.action_button.visible
			and deck.next_label.text.contains("BEFORE THE FLAG"),
		"deck: a dry forecast, or a change after the flag, offers no tyre action")

	var snap: Dictionary = _snapshot()
	snap["wind_kmh"] = 18.0
	deck.update_outlook(rows, GtWeatherOutlook.summary(rows), snap)
	check(String(deck.info_labels["AIR"].text).contains("24") and String(deck.info_labels["TRACK"].text).contains("31")
			and String(deck.info_labels["WIND"].text).contains("18") and String(deck.info_labels["HUMIDITY"].text).contains("52"),
		"deck: the weather numbers show air, track, humidity and wind")

	var points := PackedVector2Array()
	for index: int in range(60):
		points.append(Vector2(85.0 + cos(float(index) / 60.0 * TAU) * 70.0, 52.0 + sin(float(index) / 60.0 * TAU) * 40.0))
	deck.map.set_points(points)
	var wet: Array[float] = [3.0, 13.0, 0.0]
	deck.map.set_wetness(wet, 0.0)
	var colors: Array[Color] = deck.map.sector_colors()
	check(colors.size() == 3 and colors[0] != colors[1], "deck: the track map tints each sector by its water")

	PresentationSettings.reduce_motion = true
	deck.update_outlook(rows, GtWeatherOutlook.summary(rows), _snapshot())
	var still: bool = not deck.is_processing()
	PresentationSettings.reduce_motion = false
	deck.update_outlook(rows, GtWeatherOutlook.summary(rows), _snapshot())
	var live: bool = deck.is_processing()
	deck.set_open(false)
	check(animated and still and live and not deck.is_processing(), "deck: the bracket blinks only while open, and reduce motion or closing stops it")
	deck.queue_free()


# --- HUD wiring ------------------------------------------------------------------------------------------------------

## The 12 coming laps relative to the leader: dry for 3, drizzle (water 30) at L+4, a downpour (water 70) from L+5.
func _hud_forecast(lead: int) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	for k: int in range(1, 13):
		var rain: float = 0.0 if k < 4 else (0.3 if k == 4 else 0.9)
		var water: float = 3.0 if k < 4 else (30.0 if k == 4 else 70.0)
		rows.append({"lap": lead + k, "rain_intensity": rain, "water_pct": water, "cloud_cover": 0.3, "wind_speed": 10.0})
	return rows


func _test_hud() -> void:
	var weather: GtWeather = race.weather
	var saved: Array[Dictionary] = weather.forecast.duplicate()
	var saved_rain: float = weather.rain_intensity
	var saved_water: float = weather.track_water_pct
	var saved_laps: int = race.laps
	race.latest_suggestion = {}
	race.laps = 40
	var lead: int = hud.leader_lap()
	weather.forecast = _hud_forecast(lead)
	weather.rain_intensity = 0.0
	weather.track_water_pct = 3.0
	var car: GtCar = mine[0]
	hud.deck.deck_car_id = car.id
	hud.deck.pit_compound = -1
	car.pit_request = -1
	hud.refresh_all()

	hud.weather_widget.clicked.emit()
	var opened: bool = hud.weather_deck.is_open
	var closed_by_key: bool = hud.handle_key(KEY_W) and not hud.weather_deck.is_open
	hud.handle_key(KEY_W)
	var reopened: bool = hud.weather_deck.is_open
	var esc: bool = hud.handle_key(KEY_ESCAPE) and not hud.weather_deck.is_open
	hud.handle_key(KEY_W)
	hud.set_shown(false)
	var hidden_closes: bool = not hud.weather_deck.is_open and not hud.handle_key(KEY_W) and not hud.weather_deck.is_open
	hud.set_shown(true)
	check(GtWeatherOutlook.leader_lap(race, world.track.length) == lead and opened and closed_by_key and reopened and esc and hidden_closes,
		"hud: the chip and W open the weather deck, ESC closes it first, hiding the HUD closes it")

	check(hud.weather_deck.get_parent() == hud.weather_layer and hud.weather_layer.layer > hud.radio.layer and hud.weather_layer.layer > hud.engineer_radio.layer,
		"hud: the weather deck draws above the radio banners")
	hud.weather_widget.clicked.emit()
	var offered: String = hud.weather_deck.action_button.text
	hud.weather_deck.action_button.pressed.emit()
	check(offered == "SET TYRES  L+3 > INTERMEDIATE" and hud.deck.pit_compound == GtTypes.Compound.INTERMEDIATE
			and hud.deck.wheel.compound == 1 + GtTypes.Compound.INTERMEDIATE and hud.deck.tyre_row.active == 1 + GtTypes.Compound.INTERMEDIATE and car.pit_request == -1,
		"hud: the weather deck picks the tyre for the next box call and does not call the car (%s)" % offered)
	hud.weather_deck.set_open(false)

	hud.deck.refresh()
	var rain_window: String = hud.deck.window_label.text
	var quiet: Array[Dictionary] = []
	for k: int in range(1, 13):
		quiet.append({"lap": lead + k, "rain_intensity": 0.0, "water_pct": 3.0, "cloud_cover": 0.3, "wind_speed": 10.0})
	weather.forecast = quiet
	hud.refresh_all()
	check(rain_window == "BOX WINDOW L+3 -> INTERMEDIATE" and hud.deck.window_label.text == "NO TYRE CHANGE" and (hud.weather_status()["forecast"] as Array).size() == 5,
		"hud: the deck's window card and the weather deck read the same outlook (%s)" % rain_window)

	var far: Array[Dictionary] = []
	for k: int in range(1, 13):
		far.append({"lap": lead + k, "rain_intensity": 0.0 if k < 7 else 0.9, "water_pct": 3.0 if k < 7 else 70.0, "cloud_cover": 0.3, "wind_speed": 10.0})
	weather.forecast = far
	hud.refresh_all()
	check(hud.deck.window_label.text == "BOX WINDOW L+6 -> WET" and bool(hud.weather_widget.columns[7]["crossover"]) and hud.weather_widget.columns[6]["tag"] == "BOX",
		"hud: the window card looks as far ahead as the chip and the weather deck do (%s)" % hud.deck.window_label.text)

	weather.forecast = saved
	weather.rain_intensity = saved_rain
	weather.track_water_pct = saved_water
	race.laps = saved_laps
	hud.deck.pit_compound = -1
	hud.refresh_all()
