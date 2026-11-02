extends SceneTree

## Native final race -> podium -> HQ lifecycle, storm/night High, 20 cars, six simultaneous pit calls.
const World := preload("res://scenes/race_weekend_world.tscn")
const Config := preload("res://scripts/core/race_config_data.gd")
const Settings := preload("res://scripts/core/presentation_settings.gd")
const Studio := preload("res://scripts/ui/winning_scene.gd")
var failures: int = 0

func _initialize() -> void:
	_run.call_deferred()

func check(ok: bool, label: String) -> void:
	print("[%s] %s" % ["PASS" if ok else "FAIL", label])
	if not ok:
		failures += 1

func _run() -> void:
	root.size = Vector2i(1920, 1080)
	root.content_scale_size = Vector2i(1920, 1080)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
	Settings.set_quality(Settings.Quality.HIGH)
	var config := Config.get_config()
	config.selected_circuit_id = "stoke_crown"
	config.total_laps = 3
	config.selected_team_id = 4
	config.race_seed = 19220903
	config.weather_preset = 3
	config.time_of_day = 2
	var world := World.instantiate()
	root.add_child(world)
	current_scene = world
	world.finish_grid_intro()
	for i: int in range(150):
		await process_frame
	check(world.hud.rate_row.buttons.size() == 4, "HUD exposes four fast-forward buttons")
	for index: int in range(4):
		world.hud.rate_row.buttons[index].pressed.emit()
		check(world.time_scale == pow(2.0, index), "HUD selects %dx" % int(pow(2.0, index)))
	world.set_time_scale(16.0)
	check(world.time_scale == 8.0, "Native weekend API rejects speed above 8x")
	world.set_time_scale(2.0)
	var removed_key := InputEventKey.new()
	removed_key.keycode = KEY_5
	removed_key.pressed = true
	Input.parse_input_event(removed_key)
	await process_frame
	check(world.time_scale == 2.0, "Native key 5 leaves race speed unchanged")
	world.set_time_scale(8.0)
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://executor-report/screenshots/phases/phase-21/fast_forward_8x.png")
	for i: int in range(6):
		world.race.request_pit(world.race.cars[i * 3].id, 1)
	world.set_time_scale(8.0)
	var guard: int = 0
	while not world.race.is_finished() and guard < 9000:
		await process_frame
		guard += 1
	var finished: int = 0
	var stops: int = 0
	for car in world.race.cars:
		finished += 1 if car.finished_at >= 0.0 else 0
		stops += car.stops
	check(finished == 20 and world.race.is_finished(), "Stoke Crown storm/night High: 20/20 finish three laps")
	check(stops >= 6, "Six simultaneous pit callers serviced (%d stops)" % stops)
	world.set_time_scale(1.0)
	world.show_podium()
	guard = 0
	while not current_scene is Studio and guard < 600:
		await process_frame
		guard += 1
	check(current_scene is Studio, "Race opens podium")
	if current_scene is Studio:
		for i: int in range(30):
			await process_frame
		var closing: WeakRef = weakref(current_scene)
		current_scene._exit_to_hq()
		await scene_changed
		for i: int in range(20):
			await process_frame
		check(closing.get_ref() == null and current_scene.scene_file_path == "res://scenes/main.tscn", "Podium frees and returns to HQ")
		check(int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)) == 0, "HQ has zero orphan nodes")
		current_scene.queue_free()
		await process_frame
	check(int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)) == 0, "Full loop cleanup has zero orphan nodes")
	print("STOKE CROWN NATIVE LOOP: %d FAIL" % failures)
	quit(1 if failures else 0)
