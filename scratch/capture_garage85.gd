extends SceneTree

## FASE 8.5: the 10-stall garage with race chassis (load time + two team close-ups). Needs a GPU:
##   godot --path . --resolution 1920x1080 --script res://scratch/capture_garage85.gd -- [out_dir]

const ConfigScript := preload("res://scripts/core/race_config_data.gd")


func _initialize() -> void:
	call_deferred("_run")


func _shot(path: String) -> void:
	for _i: int in range(40):
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path(path))
	print("saved ", path)


func _run() -> void:
	var out_dir: String = OS.get_cmdline_user_args()[0] if OS.get_cmdline_user_args().size() > 0 else "res://executor-report/screenshots/phases"
	ConfigScript.reset()
	var begin: int = Time.get_ticks_msec()
	var garage: Node = load("res://scenes/ui/garage_team_select.tscn").instantiate()
	root.add_child(garage)
	print("GARAGE build %d ms (10 stalls, %d cars)" % [Time.get_ticks_msec() - begin, garage.environment.cars.size()])
	await _shot(out_dir + "/fase-8.5-garage-team0.png")
	garage.select_team(2)
	await _shot(out_dir + "/fase-8.5-garage-team2.png")
	quit(0)
