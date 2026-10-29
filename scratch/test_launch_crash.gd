extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	print("--- TESTING LAUNCH FOR TEAMS 0, 10, 11, 12 ---")
	var config_script: Script = load("res://scripts/core/race_config_data.gd")
	var teams_to_test: Array[int] = [0, 10, 11, 12]
	
	for team_id in teams_to_test:
		print("\n>>> Testing launch with Team %d..." % team_id)
		var config: RefCounted = config_script.reset()
		config.race_seed = 42
		config.selected_team_id = team_id
		config.total_laps = 3
		config.weather_preset = 0
		config.time_of_day = 0
		config.car1_starting_compound = 0
		config.car2_starting_compound = 0
		
		print("Instantiating RaceWeekendWorld...")
		var world_scene: PackedScene = load("res://scenes/race_weekend_world.tscn")
		var world: Node3D = world_scene.instantiate()
		world.race_config = config
		world.pre_grid_hold = true
		root.add_child(world)
		
		await process_frame
		await process_frame
		print("RaceWeekendWorld added to tree successfully.")
		
		print("Active teams: %s" % str(world.race.active_teams if "active_teams" in world.race else "N/A"))
		print("Player team ID: %d" % world.race.player_team_id)
		print("Followed ID: %d" % world.followed_id)
		
		# Test one frame of physics process
		world.set_process(true)
		await physics_frame
		await process_frame
		print("Physics frame processed successfully for Team %d." % team_id)
		
		# Test transition / finish_grid_intro
		world.finish_grid_intro()
		for f in range(10):
			await physics_frame
			await process_frame
		print("Grid intro finished and 10 frames simulated for Team %d." % team_id)
		
		world.queue_free()
		await process_frame
		await process_frame
		print("Cleaned up Team %d." % team_id)
		
	print("\nALL TEAMS LAUNCH TEST COMPLETED.")
	quit(0)
