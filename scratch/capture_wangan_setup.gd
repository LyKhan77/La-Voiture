extends SceneTree

## Race Setup with the Neo-Wangan round selected (needs a GPU, not --headless):
##   godot --path . --resolution 1920x1080 --script res://scratch/capture_wangan_setup.gd
## The Track Selector and the hero map tracing the street circuit's own spline.

const MenuScene := preload("res://scenes/ui/race_setup_menu.tscn")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var menu: Control = MenuScene.instantiate()
	root.add_child(menu)
	await process_frame
	menu.call("select_circuit", "neo_wangan")
	for _i: int in range(8):
		await process_frame
	var image: Image = root.get_texture().get_image()
	var path: String = "res://executor-report/screenshots/phases/phase-12-track-selector-neo-wangan.png"
	print("saved ", path, " err=", image.save_png(path))
	menu.queue_free()
	await process_frame
	quit(0)
