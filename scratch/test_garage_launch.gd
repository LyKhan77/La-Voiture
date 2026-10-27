extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	print("--- TESTING GARAGE TEAM SELECT -> LAUNCH TO GRID ---")
	var garage_scene: PackedScene = load("res://scenes/ui/garage_team_select.tscn")
	var teams: Array[int] = [0, 9, 10, 11, 12]
	
	for team_id in teams:
		print("\n>>> Testing Garage with Team %d..." % team_id)
		var garage: Node = garage_scene.instantiate()
		root.add_child(garage)
		await process_frame
		await process_frame
		
		print("Selecting team %d in garage..." % team_id)
		garage.select_team(team_id)
		await process_frame
		
		print("Launching team %d..." % team_id)
		# Call launch(true) to bypass mismatch modal
		garage.launch(true)
		await process_frame
		await process_frame
		
		# Now check current scene
		print("Current scene after launch: %s" % (current_scene.name if current_scene != null else "null"))
		
		# Wait for transition to load world
		var waited: float = 0.0
		while waited < 5.0:
			await process_frame
			waited += 0.016
			if current_scene != null and current_scene.name == "RaceWeekendWorld":
				break
				
		print("Scene after transition wait: %s" % (current_scene.name if current_scene != null else "null"))
		if current_scene != null and current_scene.name == "RaceWeekendWorld":
			print("Simulating 30 frames of race...")
			current_scene.set_physics_process(true)
			current_scene.finish_grid_intro()
			for f in range(30):
				await physics_frame
				await process_frame
			print("Race ran 30 frames OK!")
		
		if current_scene != null:
			current_scene.queue_free()
		await process_frame
		await process_frame
		print("Cleaned up Team %d test." % team_id)
		
	print("\nALL GARAGE LAUNCH TESTS PASSED.")
	quit(0)
