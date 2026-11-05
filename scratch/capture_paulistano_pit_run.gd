extends SceneTree

## Real race at 1x: the player car is called in on lap 1 and a chase camera (behind, a little to the
## track side, above) records the pit entry blend past the wall nose, the box stop and the exit.
##   godot --path . --resolution 1920x1080 -s res://scratch/capture_paulistano_pit_run.gd -- --out=temp/paul_pit_run
## The run fast-forwards (4x) only until the car is 350 m from Pit Entry; everything recorded is 1x.

const WorldScene := preload("res://scenes/race_weekend_world.tscn")
const Config := preload("res://scripts/core/race_config_data.gd")
const Types := preload("res://scripts/gt/gt_types.gd")

var out_dir := "res://temp/paul_pit_run"


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out_dir = "res://" + arg.substr(6)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out_dir))
	var config := Config.get_config()
	config.selected_circuit_id = "paulistano"
	config.selected_team_id = 4
	config.total_laps = 3
	config.time_of_day = 0
	config.weather_preset = 0
	config.race_seed = 19220903
	var world = WorldScene.instantiate()
	root.add_child(world)
	world.finish_grid_intro()
	world.hud.visible = false
	for node: Node in world.hud.find_children("*", "CanvasLayer", true, false):
		(node as CanvasLayer).visible = false
	var camera := Camera3D.new()
	camera.far = 6000.0
	camera.fov = 62.0
	root.add_child(camera)
	var car = null
	for candidate in world.race.cars:
		if candidate.team_id == config.selected_team_id:
			car = candidate
	var layout: Dictionary = world.race.pit_layout
	var entry: float = float(layout["entry_s"])
	var lap: float = world.ribbon.length_m
	world.set_time_scale(4.0)
	var called: bool = false
	var shots: int = 0
	var next_shot_ms: int = 0
	var done_after: float = -1.0
	var guard: int = 0
	while guard < 20000:
		await process_frame
		guard += 1
		var to_entry: float = fposmod(entry - fposmod(car.s, lap), lap)
		if not called and car.lap >= 0 and to_entry < 900.0 and to_entry > 400.0:
			world.race.request_pit(car.id, Types.Compound.MEDIUM)
			called = true
		if called and to_entry < 350.0 and world.time_scale > 1.0:
			world.set_time_scale(1.0)
		var actor: Node3D = world.actor_of(car.id)
		if actor == null:
			continue
		var basis: Basis = actor.global_transform.basis
		var origin: Vector3 = actor.global_transform.origin
		var track_side: float = -signf(float(layout["stall_lane_m"]))
		camera.global_position = origin + basis.z * 10.0 + basis.x * (track_side * 3.5) + Vector3.UP * 4.0
		camera.look_at(origin + Vector3.UP * 0.6 - basis.z * 6.0, Vector3.UP)
		camera.make_current()
		var in_window: bool = car.pit != null or (done_after >= 0.0 and world.race.time - done_after < 4.0)
		if car.pit != null:
			done_after = world.race.time
		if called and world.time_scale <= 1.0 and in_window and Time.get_ticks_msec() >= next_shot_ms:
			var u: float = car.s - car.pit.start_s if car.pit != null else -1.0
			await RenderingServer.frame_post_draw
			var image: Image = root.get_texture().get_image()
			var phase: int = car.pit.phase if car.pit != null else 9
			image.save_png(ProjectSettings.globalize_path("%s/run_%03d_p%d_u%04d.png" % [out_dir, shots, phase, int(maxf(u, 0.0))]))
			shots += 1
			next_shot_ms = Time.get_ticks_msec() + 450
		if done_after >= 0.0 and car.pit == null and world.race.time - done_after >= 4.0:
			break
	print("PITRUN shots=%d stops=%d" % [shots, car.stops])
	world.queue_free()
	camera.queue_free()
	for _i in 6:
		await process_frame
	quit(0)
