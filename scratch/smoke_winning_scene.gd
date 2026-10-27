extends SceneTree

## Native 1080p/High acceptance and captures. Add -- --race for the complete 3-lap game loop.
## godot --path . -s res://scratch/smoke_winning_scene.gd -- --race
const Studio := preload("res://scripts/ui/winning_scene.gd")
const Config := preload("res://scripts/core/race_config_data.gd")
const Settings := preload("res://scripts/core/presentation_settings.gd")
const World := preload("res://scenes/race_weekend_world.tscn")
const TrackScene := preload("res://scenes/race_world/track_circuit.tscn")
const Track := preload("res://scripts/gt/gt_track.gd")
const Race := preload("res://scripts/gt/gt_race.gd")
const OUT := "res://executor-report/screenshots/winning_scene/"
var failures: int = 0
var studio: Node3D

func _initialize() -> void:
	call_deferred("_run")

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
	print("[%s] %s" % ["PASS" if ok else "FAIL", message])

func _key(code: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.pressed = true
	root.push_input(event)
	event = InputEventKey.new()
	event.keycode = code
	event.pressed = false
	root.push_input(event)

func _save(file_name: String) -> void:
	await RenderingServer.frame_post_draw
	var image: Image = root.get_texture().get_image()
	check(image.get_size() == Vector2i(1920, 1080) and image.save_png(OUT + file_name + ".png") == OK,
		"Native 1080p capture: " + file_name)

func _fixture() -> Dictionary:
	var ribbon: Node3D = TrackScene.instantiate()
	root.add_child(ribbon)
	var race: GtRace = Race.new(Track.new(ribbon, 14.0), 3, 1, 0)
	for i: int in range(race.cars.size()):
		var car: GtCar = race.cars[i]
		car.finished_at = 310.0 + float(i) * 2.0
		car.s = race.track.length * 3.0
		car.best_lap = 92.0 + float(i) * 0.2
	for i: int in range(3):
		race.get_car([0, 2, 8][i]).finished_at = 300.0 + float(i) * 1.7
	var snapshot: Dictionary = Studio.capture_results(race)
	race.dispose()
	ribbon.queue_free()
	return snapshot

## Waits for `cut` to start, lets it settle `settle` seconds, then saves the frame.
func _capture_cut(cut: int, file_name: String, settle: float) -> void:
	var started: int = Time.get_ticks_msec()
	while studio.director.current_cut != cut and Time.get_ticks_msec() - started < 15000:
		await process_frame
	await create_timer(settle).timeout
	check(studio.director.current_cut == cut, "Cut %d is on screen when captured" % cut)
	await _save(file_name)


func _measure(label: String, seconds: float) -> void:
	# The screenshot just written stalls the process for ~300 ms while the OS flushes it (not a render cost); sample after it.
	await create_timer(1.5).timeout
	var samples: Array[float] = []
	var last: int = Time.get_ticks_usec()
	var start: int = last
	while Time.get_ticks_usec() - start < int(seconds * 1000000.0):
		await process_frame
		var now: int = Time.get_ticks_usec()
		samples.append(float(now - last) / 1000.0)
		last = now
	var total: float = 0.0
	for value: float in samples:
		total += value
	samples.sort()
	var avg: float = total / float(samples.size())
	var p95: float = samples[int(float(samples.size()) * 0.95)]
	print("METRIC %s: %d frames / avg %.4f ms / %.3f FPS / p95 %.4f ms / max %.4f ms / process %.4f ms / draw calls %.0f" % [
		label, samples.size(), avg, 1000.0 / avg, p95, samples[-1],
		Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0,
		Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)])
	# 60 Hz is mathematically 16.666... ms. Record exact pacing, do not round a slow run into a pass.
	check(1000.0 / avg >= 59.9 and p95 <= 16.8, label + ": 60 Hz pacing (>=59.9 FPS, p95<=16.8ms)")

func _run() -> void:
	if DisplayServer.get_name() == "headless":
		check(false, "Native renderer required for visual/performance evidence")
		quit(1)
		return
	root.content_scale_size = Vector2i(1920, 1080)
	DisplayServer.window_set_size(Vector2i(1920, 1080))
	Settings.set_quality(Settings.Quality.HIGH)
	Settings.reduce_motion = false
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	print("GPU: " + RenderingServer.get_video_adapter_name())
	studio = load(Studio.PATH).instantiate()
	studio.setup_celebration(_fixture())
	root.add_child(studio)
	current_scene = studio
	var Cut := WinningCutDirector.Cut
	await _capture_cut(Cut.P3_TAG, "hero-graffiti-cut-1", 0.8)
	await _capture_cut(Cut.HERO, "hero-graffiti-cut-2", 0.8)
	await _capture_cut(Cut.P2_TAG, "hero-graffiti-cut-3", 0.8)
	await _capture_cut(Cut.DETAIL, "hero-graffiti-cut-4", 0.85)
	await _capture_cut(Cut.FINAL, "hero-graffiti-cut-5", 1.2)
	check(AudioManager.of(studio).music_track == &"podium", "Native winning scene plays the podium anthem")
	if "--captures-only" not in OS.get_cmdline_user_args():
		await _measure("STUDIO CLEAN HIGH", 10.0)
	_key(KEY_TAB)
	await create_timer(0.4).timeout
	check(studio.is_leaderboard_open, "Native TAB opens the complete timing tower")
	await _save("hero-graffiti-final-tab")
	if "--captures-only" not in OS.get_cmdline_user_args():
		await _measure("STUDIO TIMING HIGH", 5.0)
	_key(KEY_TAB)
	await create_timer(0.4).timeout
	studio.set_process(false)
	studio.camera.position = Vector3(2.8, 2.5, 4.8)
	studio.camera.look_at(Vector3(0, 1.4, 0))
	studio.camera.fov = 44.0
	studio.get_node("VictoryHUD").hide()
	await _save("hero-graffiti-standee-closeup")
	var reference: WeakRef = weakref(studio)
	_key(KEY_ESCAPE)
	await scene_changed
	for i: int in range(10):
		await process_frame
	check(reference.get_ref() == null and current_scene.scene_file_path == "res://scenes/main.tscn", "Native ESC frees studio and returns to HQ")
	check(int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)) == 0, "Native studio exit: zero orphan nodes")
	current_scene.queue_free()
	await process_frame
	if "--race" in OS.get_cmdline_user_args():
		await _race()
	print("WINNING STUDIO NATIVE: %d FAIL" % failures)
	quit(0 if failures == 0 else 1)

func _race() -> void:
	# HQ reloads saved presentation choices; restore the actual acceptance conditions.
	Settings.set_quality(Settings.Quality.HIGH)
	Settings.reduce_motion = false
	root.content_scale_size = Vector2i(1920, 1080)
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(Vector2i(1920, 1080))
	root.scaling_3d_scale = 1.0
	var config: RaceConfigData = Config.reset()
	config.total_laps = 3
	config.weather_preset = 3
	config.time_of_day = 2
	config.race_seed = 42
	var world: RaceWeekendWorld = World.instantiate()
	world.pre_grid_hold = true
	root.add_child(world)
	current_scene = world
	check(world.race.cars.size() == 20, "Native game loop: 3 laps / 20 cars / night storm / High")
	var world_ref: WeakRef = weakref(world)
	await create_timer(6.0).timeout
	world.finish_grid_intro()
	var started: int = Time.get_ticks_msec()
	while not world.director.is_racing() and Time.get_ticks_msec() - started < 30000:
		await process_frame
	await _measure("RACE 1X HIGH", 8.0)
	world.set_time_scale(16.0)
	started = Time.get_ticks_msec()
	while (current_scene == null or current_scene.scene_file_path != Studio.PATH) and Time.get_ticks_msec() - started < 420000:
		await process_frame
	check(current_scene != null and current_scene.scene_file_path == Studio.PATH, "Real three-lap finish reaches the dedicated studio")
	check(world_ref.get_ref() == null, "Finished race world is freed before studio presentation")
	if current_scene != null and current_scene.scene_file_path == Studio.PATH:
		studio = current_scene
		var wipe: CanvasLayer = studio.get_node_or_null("DepartureWipe") as CanvasLayer
		check(wipe != null, "Actual race frame enters the native manga departure wipe")
		await create_timer(0.2).timeout
		if is_instance_valid(wipe):
			var wipe_material: ShaderMaterial = wipe.get_child(0).material
			var progress: float = float(wipe_material.get_shader_parameter("progress"))
			check(progress > 0.0 and progress < 1.0, "Manga wipe shader advances through a real intermediate frame")
		else:
			check(false, "Manga wipe must not snap closed without its 0.55 s slide")
		await create_timer(0.6).timeout
		check(studio.get_node_or_null("DepartureWipe") == null, "Departure wipe frees its snapshot overlay after revealing the studio")
		await create_timer(1.0).timeout
		check(studio.order.size() == 20, "All twenty actual results survive race teardown")
		await _save("actual-race-finish")
		_key(KEY_ESCAPE)
		await scene_changed
		for i: int in range(8):
			await process_frame
		check(current_scene.scene_file_path == "res://scenes/main.tscn", "Real race -> studio -> HQ completes")
	if current_scene != null:
		current_scene.queue_free()
	for i: int in range(8):
		await process_frame
	check(int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)) == 0, "Full race loop exits with zero orphan nodes")
