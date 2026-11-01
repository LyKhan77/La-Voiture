extends SceneTree

## FASE 19 polish: the Koma Strip radio cards in the race HUD (needs a GPU, not --headless):
##   Godot --path . --resolution 1920x1080 --script res://scratch/capture_phase19_radio_koma.gd

const WorldScene := preload("res://scenes/race_weekend_world.tscn")
const Config := preload("res://scripts/core/race_config_data.gd")
const DirectorScript := preload("res://scripts/world/weekend/race_weekend_director.gd")
const SHOTS := "res://executor-report/screenshots/phases/phase-19/"
const FRAME: float = 1.0 / 60.0


func _initialize() -> void:
	call_deferred("_run")


func _save(file_name: String, region: Rect2i = Rect2i()) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	var image: Image = root.get_texture().get_image()
	if region.size != Vector2i.ZERO:
		image = image.get_region(region)
	print("CAPTURED ", file_name, " err=", image.save_png(ProjectSettings.globalize_path(SHOTS + file_name + ".png")))


func _run() -> void:
	DisplayServer.window_set_size(Vector2i(1920, 1080))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SHOTS))
	var config := Config.get_config()
	config.selected_circuit_id = "apex_ring"
	config.total_laps = 8
	config.weather_preset = 0
	config.race_seed = 19220903
	var world: Node3D = WorldScene.instantiate()
	root.add_child(world)
	world.set_process(false)
	await process_frame
	var race: GtRace = world.race
	race.incidents_enabled = false
	world.director._enter(DirectorScript.State.GREEN_RACING)
	for _i: int in range(60 * 8):
		world.step(FRAME)
	var hud: RaceHud = world.hud
	var car: GtCar = null
	for candidate: GtCar in race.cars:
		if candidate.team_id == race.player_team_id:
			car = candidate
			break
	world.followed_id = car.id
	PresentationSettings.reduce_motion = true # rest pose, no shiver: a clean still
	hud.radio.play_radio(car.id, "Tyres are cooked! Rear is sliding everywhere!", false)
	hud.radio._settle()
	await process_frame
	await _save("phase-19-radio-koma-driver-routine", Rect2i(340, 640, 1280, 260))
	hud.engineer_radio.play_radio(car.id, "Rain easing (28% water). Suggest box this lap for INTERMEDIATE tyres.", true)
	hud.engineer_radio._settle()
	hud.radio.set_dimmed(true)
	await process_frame
	await _save("phase-19-radio-koma-two-way-urgent", Rect2i(340, 640, 1280, 260))
	await _save("phase-19-radio-koma-full-hud")
	PresentationSettings.reduce_motion = false
	world.queue_free()
	await process_frame
	quit(0)
