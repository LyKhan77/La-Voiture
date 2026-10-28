extends SceneTree

## FASE 12.2 Race Setup captures (needs a GPU, not --headless):
##   godot --path . --resolution 1920x1080 --script res://scratch/capture_phase12_2_setup.gd
## A Grand Prix round (Apex Ring: 5 / 10 / 15 laps open, DYNAMIC radar) and a Sprint round
## (Neo-Wangan: 3 laps locked, RANDOM time) side by side as phase-12-2-race-setup-{gp,sprint}.png.

const MenuScene := preload("res://scenes/ui/race_setup_menu.tscn")
const Config := preload("res://scripts/core/race_config_data.gd")
const SHOTS := "res://executor-report/screenshots/phases/"
var failures: int = 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	DisplayServer.window_set_size(Vector2i(1920, 1080))
	root.size = Vector2i(1920, 1080)
	var config := Config.reset()
	config.race_seed = 14 # a DYNAMIC forecast that turns wet on both Apex Ring and Neo-Wangan
	var menu: Control = MenuScene.instantiate()
	root.add_child(menu)
	await process_frame
	menu.call("select_circuit", "apex_ring")
	menu.call("select_laps", 10)
	menu.call("select_weather", 4)
	menu.call("select_time_of_day", 1)
	await _capture("race-setup-gp")
	menu.call("select_circuit", "neo_wangan")
	menu.call("select_weather", 4)
	menu.call("select_time_of_day", 3)
	menu.get("dynamics_select").call("press", 2)
	await _capture("race-setup-sprint")
	menu.queue_free()
	await process_frame
	quit(0 if failures == 0 else 1)


func _capture(label: String) -> void:
	for frame: int in range(10):
		await process_frame
	await RenderingServer.frame_post_draw
	var image: Image = root.get_texture().get_image()
	var path: String = SHOTS + "phase-12-2-" + label + ".png"
	var error: Error = image.save_png(path)
	if error != OK or image.get_size() != Vector2i(1920, 1080):
		failures += 1
	print("SETUP_SHOT %s size=%s error=%d" % [label, image.get_size(), error])
