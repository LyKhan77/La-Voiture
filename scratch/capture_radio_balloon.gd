extends SceneTree

## Native 1080p captures of the radio balloons docked in the lower corners, with the alerts up at the top.
## Run: Godot --path . -s res://scratch/capture_radio_balloon.gd
const WorldScene := preload("res://scenes/race_weekend_world.tscn")
const Config := preload("res://scripts/core/race_config_data.gd")
const Types := preload("res://scripts/gt/gt_types.gd")
const PS := preload("res://scripts/core/presentation_settings.gd")
const OUT := "res://executor-report/screenshots/phases/"
const SHOT := "phase-11-step-6-"
const FRAME: float = 1.0 / 60.0

var world: RaceWeekendWorld
var failures: int = 0


func _initialize() -> void:
	call_deferred("_run")


func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
	print("[%s] %s" % ["PASS" if ok else "FAIL", message])


func _save(file_name: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	var image: Image = root.get_texture().get_image()
	check(image.get_size() == Vector2i(1920, 1080), "Screenshot native 1920x1080")
	check(image.save_png(OUT + SHOT + file_name + ".png") == OK, "Saved " + file_name)


func _run() -> void:
	root.content_scale_size = Vector2i(1920, 1080)
	DisplayServer.window_set_size(Vector2i(1920, 1080))
	PS.set_quality(PS.Quality.HIGH)
	var config: RaceConfigData = Config.reset()
	config.total_laps = 3
	config.weather_preset = 0
	config.time_of_day = 2
	world = WorldScene.instantiate() as RaceWeekendWorld
	world.race_config = config
	root.add_child(world)
	current_scene = world
	root.scaling_3d_scale = 1.0
	world.set_physics_process(false)
	world.race.incidents_enabled = false
	world.director._enter(world.director.State.GREEN_RACING)
	for _i: int in range(60):
		await process_frame
	for _i: int in range(240):
		world.step(FRAME)
	var race: GtRace = world.race
	var car: GtCar = null
	for candidate: GtCar in race.cars:
		if candidate.team_id == race.player_team_id:
			car = candidate
			break
	# The alert stack at the top, the radio below it in the corners.
	race.set_flag(Types.Flag.SC, 1, "SAFETY CAR DEPLOYED", 30.0)
	race.steward_event.emit({"phase": "investigation", "case_id": 1, "kind": 0, "car_id": car.id, "text": "/// STEWARDS: INCIDENT INVOLVING CAR #9 UNDER INVESTIGATION", "time": race.time})
	race.driver_radio_cooldown.clear()
	race.push_radio(car, "driver", "Tyres are gone, I need to box this lap!", true)
	race.push_radio(car, "engineer", "DRS slipstream behind MBE (8.0 m)! Deploy OVERTAKE ERS to pass?", true, true)
	world.hud.radio._settle()
	world.hud.engineer_radio._settle()
	world.hud.radio.set_dimmed(false)
	world.hud.engineer_radio.set_dimmed(false)
	for _i: int in range(40):
		world.step(FRAME)
		await process_frame
	await _save("radio-balloons-urgent")
	world.hud.radio._hide_banner()
	world.hud.engineer_radio._hide_banner()
	race.driver_radio_cooldown.clear()
	race.push_radio(car, "driver", "Rears are going off. Can we box next lap?", false)
	race.push_radio(car, "engineer", "Copy. Box next lap, we have a set of mediums ready.", false)
	world.hud.radio._settle()
	world.hud.engineer_radio._settle()
	world.hud.radio.set_dimmed(false)
	world.hud.engineer_radio.set_dimmed(false)
	for _i: int in range(40):
		world.step(FRAME)
		await process_frame
	await _save("radio-balloons-routine")
	world.queue_free()
	world = null
	for _i: int in range(8):
		await process_frame
	check(int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)) == 0, "Capture cleanup: zero orphan nodes")
	quit(1 if failures > 0 else 0)
