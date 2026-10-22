extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var showroom_scene = load("res://scenes/test_modular_car.tscn")
	var showroom = showroom_scene.instantiate()
	root.add_child(showroom)
	
	# Wait 10 frames
	for i in range(10):
		await process_frame
		
	# 1. State 1: Soft compound (Default)
	_save_screenshot("res://scratch/pitstop_01_soft.png")
	
	# 2. State 2: Medium compound (Press 4)
	showroom.cycle_tire_compound()
	for i in range(5):
		await process_frame
	_save_screenshot("res://scratch/pitstop_02_medium.png")
	
	# 3. State 3: Hard compound (Press 4 again)
	showroom.cycle_tire_compound()
	for i in range(5):
		await process_frame
	_save_screenshot("res://scratch/pitstop_03_hard.png")
	
	# 4. State 4: Wet compound (Press 4 again)
	showroom.cycle_tire_compound()
	for i in range(5):
		await process_frame
	_save_screenshot("res://scratch/pitstop_04_wet.png")
	
	# 5. State 5: Wheels Detached (Pit Stop Service in progress! Press 5)
	showroom.toggle_pitstop_wheel_detach()
	for i in range(5):
		await process_frame
	_save_screenshot("res://scratch/pitstop_05_detached.png")
	
	print("ALL PIT STOP STATE SCREENSHOTS CAPTURED SUCCESSFULLY!")
	quit(0)

func _save_screenshot(res_path: String) -> void:
	var img = root.get_viewport().get_texture().get_image()
	if img:
		var abs_path = ProjectSettings.globalize_path(res_path)
		img.save_png(abs_path)
		print("Saved:", abs_path)
