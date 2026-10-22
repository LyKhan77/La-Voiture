extends SceneTree

var _frames: int = 0
var _target_scene: Node

func _initialize() -> void:
	call_deferred("_setup")

func _setup() -> void:
	var showroom_scene = load("res://scenes/test_modular_car.tscn")
	_target_scene = showroom_scene.instantiate()
	root.add_child(_target_scene)
	
	# Connect to process_frame
	for i in range(15):
		await process_frame
		
	var img = root.get_viewport().get_texture().get_image()
	if img:
		var path = "res://scratch/godot_showroom_screenshot.png"
		var abs_path = ProjectSettings.globalize_path(path)
		img.save_png(abs_path)
		print("SUCCESS: Showroom screenshot saved to:", abs_path)
	else:
		print("Failed to get viewport image")
	quit(0)
