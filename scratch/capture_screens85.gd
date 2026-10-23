extends SceneTree

## FASE 8.5: the Concept 01 Race Setup (hero map) and Settings (inspection tag). Needs a GPU:
##   godot --path . --resolution 1920x1080 --script res://scratch/capture_screens85.gd -- [out_dir]

const ConfigScript := preload("res://scripts/core/race_config_data.gd")


func _initialize() -> void:
	call_deferred("_run")


func _shot(path: String) -> void:
	for _i: int in range(30):
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path(path))
	print("saved ", path)


func _run() -> void:
	var out_dir: String = OS.get_cmdline_user_args()[0] if OS.get_cmdline_user_args().size() > 0 else "res://executor-report/screenshots/phases"
	ConfigScript.reset()
	var setup: Node = load("res://scenes/ui/race_setup_menu.tscn").instantiate()
	root.add_child(setup)
	await _shot(out_dir + "/fase-8.5-race-setup.png")
	setup.select_weather(3)
	setup.select_time_of_day(2)
	await _shot(out_dir + "/fase-8.5-race-setup-monsoon-night.png")
	setup.queue_free()
	await process_frame
	var menu: Node = load("res://scenes/ui/main_menu.tscn").instantiate()
	root.add_child(menu)
	await process_frame
	menu.call("_on_settings_pressed")
	await _shot(out_dir + "/fase-8.5-settings.png")
	quit(0)
