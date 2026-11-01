extends SceneTree

## FASE 19 report screenshots (needs a GPU, not --headless):
##   Godot --path . --resolution 1920x1080 --script res://scratch/capture_phase19_strategy.gd
## The desk modes on a strategist call (MANUAL + COACH card, MANUAL facts only, AUTO executing with COACH locked),
## a drying race where the walls split on the slick crossover, and a punctured car limping home.

const WorldScene := preload("res://scenes/race_weekend_world.tscn")
const Config := preload("res://scripts/core/race_config_data.gd")
const DirectorScript := preload("res://scripts/world/weekend/race_weekend_director.gd")
const SHOTS := "res://executor-report/screenshots/phases/phase-19/"
const FRAME: float = 1.0 / 60.0

var world: Node3D
var race: GtRace
var hud: RaceHud
var car: GtCar


func _initialize() -> void:
	call_deferred("_run")


func _save(file_name: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	var image: Image = root.get_texture().get_image()
	print("CAPTURED ", file_name, " err=", image.save_png(ProjectSettings.globalize_path(SHOTS + file_name + ".png")))


func _frames(count: int) -> void:
	for _i: int in range(count):
		hud.refresh_all()
		await process_frame


func _load(seed_value: int, preset: int) -> void:
	var config := Config.get_config()
	config.selected_circuit_id = "apex_ring"
	config.total_laps = 8
	config.time_of_day = 0
	config.weather_preset = preset
	config.selected_team_id = 0
	config.race_seed = seed_value
	world = WorldScene.instantiate()
	root.add_child(world)
	world.set_process(false)
	await process_frame
	race = world.race
	race.incidents_enabled = false
	world.director._enter(DirectorScript.State.GREEN_RACING)
	hud = world.hud
	for candidate: GtCar in race.cars:
		if candidate.team_id == race.player_team_id:
			car = candidate
			break
	world.followed_id = car.id
	hud.deck.deck_car_id = car.id


func _unload() -> void:
	world.queue_free()
	world = null
	for _i: int in range(4):
		await process_frame


## The followed car on wets with the track drying to 28 %: the strategist calls inters.
func _desk_call(mode: int, coach: bool) -> void:
	race.set_tactic_mode(mode)
	race.coach_enabled = coach
	hud.deck.coach = coach
	race.latest_suggestion = {}
	race._suggestion_cooldowns.clear()
	car.pit_request = -1
	car.compound = GtTypes.Compound.WET
	car.wear = 0.2
	race.weather.track_water_pct = 28.0
	race.weather.rain_intensity = 0.03
	race._strategy_profiles[car.team_id] = {"forecast_trust": 1.0, "risk_bias": 0.0, "reaction_sectors": 0, "read_noise": 0.0, "herd": 0.0}
	race.decide_strategy(car)
	race.suggestion_changed.emit(race.latest_suggestion)


func _run() -> void:
	DisplayServer.window_set_size(Vector2i(1920, 1080))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SHOTS))

	await _load(19220903, 0)
	for _i: int in range(60 * 8):
		world.step(FRAME)
	await _desk_call(GtTypes.TacticMode.MANUAL, true)
	await _frames(20)
	await _save("phase-19-desk-manual-coach-card")
	await _desk_call(GtTypes.TacticMode.MANUAL, false)
	await _frames(20)
	await _save("phase-19-desk-manual-no-coach-facts")
	await _desk_call(GtTypes.TacticMode.AUTO, true)
	await _frames(20)
	await _save("phase-19-desk-auto-executes-coach-locked")
	race.set_tactic_mode(GtTypes.TacticMode.MANUAL)

	# A puncture: the car boxes itself and limps home at ~100 km/h.
	car.pit_request = -1
	car.compound = GtTypes.Compound.MEDIUM
	race.weather.track_water_pct = 0.0
	race.weather.rain_intensity = 0.0
	car.wear = 0.96
	for _i: int in range(60 * 6):
		world.step(FRAME)
	await _frames(10)
	print("PUNCTURE punctured=%s request=%d v=%.1f flag=%d" % [str(car.is_punctured), car.pit_request, car.v, int(race.race_control["flag"])])
	await _save("phase-19-puncture-limp-box-called")
	await _unload()

	# A drying race: the walls split on when to go to slicks.
	var config := Config.get_config()
	var drying_seed: int = 1
	config.weather_preset = 4
	for candidate: int in range(1, 400):
		if config.weather_archetype(candidate) == GtWeather.Archetype.WET_DRYING:
			drying_seed = candidate
			break
	await _load(drying_seed, 4)
	var split_shot: bool = false
	for _i: int in range(60 * 60 * 8):
		world.step(FRAME)
		if _i % 60 != 0:
			continue
		var slicks: int = 0
		var running: int = 0
		for other: GtCar in race.cars:
			if other.is_dnf:
				continue
			running += 1
			if GtTypes.is_slick(other.compound):
				slicks += 1
		if slicks >= 5 and running - slicks >= 5:
			print("DRYING split slicks=%d rain_tyres=%d water=%.0f time=%.0f" % [slicks, running - slicks, race.weather.track_water_pct, race.time])
			split_shot = true
			break
	await _frames(20)
	await _save("phase-19-drying-race-walls-split")
	print("DRYING split_found=%s" % str(split_shot))
	await _unload()
	quit(0)
