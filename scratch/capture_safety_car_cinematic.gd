extends SceneTree

## Native 1080p captures; -- --smoke also runs a real three-lap night-storm race to HQ.
const WorldScene := preload("res://scenes/race_weekend_world.tscn")
const WinningStudio := preload("res://scripts/ui/winning_scene.gd")
const Config := preload("res://scripts/core/race_config_data.gd")
const Types := preload("res://scripts/gt/gt_types.gd")
const PS := preload("res://scripts/core/presentation_settings.gd")
const OUT := "res://executor-report/screenshots/safety_car/"

var world: RaceWeekendWorld
var failures: int = 0


func _initialize() -> void:
	call_deferred("_run")


func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
	print("[%s] %s" % ["PASS" if ok else "FAIL", message])


func _studio() -> WinningStudio:
	if is_instance_valid(current_scene) and current_scene.scene_file_path == WinningStudio.PATH:
		return current_scene as WinningStudio
	return null


func _save(file_name: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	var image: Image = root.get_texture().get_image()
	check(image.get_size() == Vector2i(1920, 1080), "Screenshot native 1920x1080")
	check(image.save_png(OUT + file_name + ".png") == OK, "Saved " + file_name)


func _run() -> void:
	root.content_scale_size = Vector2i(1920, 1080)
	DisplayServer.window_set_size(Vector2i(1920, 1080))
	PS.set_quality(PS.Quality.HIGH)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	var config: RaceConfigData = Config.reset()
	config.total_laps = 3
	config.weather_preset = 0
	config.time_of_day = 0
	world = WorldScene.instantiate() as RaceWeekendWorld
	world.race_config = config
	root.add_child(world)
	current_scene = world
	root.scaling_3d_scale = 1.0
	world.set_physics_process(false)
	world.race.incidents_enabled = false
	world.director._enter(world.director.State.GREEN_RACING)
	for _i: int in range(30):
		await process_frame
	world.race.set_flag(Types.Flag.SC, 1, "SAFETY CAR DEPLOYED", 30.0)
	for _i: int in range(150):
		world.step(1.0 / 60.0)
		await process_frame
	print("EXIT capture: s=%.2f lateral=%.2f camera=%s" % [world.race.safety_car["s"], world.race.safety_car["lateral"], world.camera_director.get_mode_name()])
	var official := world.vfx.safety_car_actor.chassis as SafetyCarChassis
	official.set_process(false)
	official.advance(0.0)
	await _save("safety_car_pit_exit_cinematic_corrected")
	# Staged deterministic entry fixture; all poses still use production sim/VFX/HUD.
	world.race.safety_car["s"] = 3700.0
	world.race.safety_car["exit_end_s"] = 220.0
	world.race.race_control["timer"] = 0.0
	world.race.race_control["sc_laps_remaining"] = 0
	for index: int in range(world.race.cars.size()):
		world.race.cars[index].s = 3686.0 - float(index) * 14.0
	world.race._update_race_control(0.0)
	for index: int in range(world.race.cars.size()):
		var car: GtCar = world.race.cars[index]
		car.s = 3898.0 - float(index) * 15.0
		car.prev_s = car.s
		car.lateral = 0.0
		car.prev_lateral = 0.0
		car.v = 25.0
		world.actors[index].present(1.0, 0.0, 0.0, false)
	world.race.safety_car["s"] = 3928.0
	world.race._update_race_control(0.0)
	world.race.safety_car["prev_s"] = 3927.5
	world.race.safety_car["prev_lateral"] = GtRace.sc_pit_entry_lateral(3927.5)
	world.vfx.update(0.0)
	world.hud.update(0.0)
	world.hud.refresh_all()
	var pose: Transform3D = world.vfx.safety_car_actor.global_transform
	world.camera.global_position = pose.origin - pose.basis.z * 18.0 - pose.basis.x * 17.0 + Vector3.UP * 9.0
	world.camera.fov = 65.0
	world.camera.look_at(pose.origin + pose.basis.z * 12.0 - pose.basis.x * 4.0)
	print("ENTRY capture: s=%.2f lateral=%.2f leader lateral=%.2f" % [world.race.safety_car["s"], world.race.safety_car["lateral"], world.race.cars[0].lateral])
	await _save("safety_car_pit_entry_peeloff_corrected")
	world.queue_free()
	world = null
	for _i: int in range(8):
		await process_frame
	check(int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)) == 0, "Capture cleanup: zero orphan nodes")
	if "--smoke" in OS.get_cmdline_user_args():
		await _smoke()
	quit(1 if failures > 0 else 0)


func _smoke() -> void:
	var config: RaceConfigData = Config.reset()
	config.total_laps = 3
	config.weather_preset = 3
	config.time_of_day = 2
	world = WorldScene.instantiate() as RaceWeekendWorld
	world.race_config = config
	world.pre_grid_hold = true
	root.add_child(world)
	current_scene = world
	root.scaling_3d_scale = 1.0
	world.race.incidents_enabled = false
	print("RENDER: viewport=%s scale=%.1f" % [root.size, root.scaling_3d_scale])
	check(world.race.cars.size() == 20, "Native smoke: 20 cars / three laps / night storm / High")
	print("GPU: %s" % RenderingServer.get_video_adapter_name())
	var start_ms: int = Time.get_ticks_msec()
	# Warm up while the grid is held so the real SC deployment still starts near pit exit.
	while Time.get_ticks_msec() - start_ms < 10000:
		await process_frame
	world.finish_grid_intro()
	start_ms = Time.get_ticks_msec()
	while not world.director.is_racing() and Time.get_ticks_msec() - start_ms < 30000:
		await process_frame
	world.race.set_flag(Types.Flag.SC, 1, "SAFETY CAR DEPLOYED", 30.0)
	var frames: Array[float] = []
	var last_us: int = Time.get_ticks_usec()
	start_ms = Time.get_ticks_msec()
	while Time.get_ticks_msec() - start_ms < 10000:
		await process_frame
		var now_us: int = Time.get_ticks_usec()
		frames.append(float(now_us - last_us) / 1000.0)
		last_us = now_us
	frames.sort()
	var total_ms: float = 0.0
	for ms: float in frames:
		total_ms += ms
	var avg_fps: float = 1000.0 * frames.size() / total_ms
	var p95_ms: float = frames[int(frames.size() * 0.95)]
	print("NATIVE 1x SC SAMPLE: %d frames avg %.3f ms / %.2f FPS p95 %.3f ms max %.3f ms" % [frames.size(), total_ms / frames.size(), avg_fps, p95_ms, frames[-1]])
	check(avg_fps >= 50.0 and p95_ms <= 32.0, "Performance gate: avg FPS %.2f >=50.0, p95 %.2f <=32.0 ms" % [avg_fps, p95_ms])
	world.set_time_scale(16.0)
	start_ms = Time.get_ticks_msec()
	var saw_in_lap: bool = false
	var saw_peeloff: bool = false
	var saw_restart: bool = false
	var saw_pickup: bool = false
	var saw_caution_finish: bool = false
	var stayed_in_pit: bool = true
	var last_phase: int = -1
	var studio: WinningStudio = null
	while studio == null and Time.get_ticks_msec() - start_ms < 300000:
		await process_frame
		studio = _studio()
		if studio == null and is_instance_valid(world) and not world.is_queued_for_deletion():
			var phase: int = int(world.race.safety_car["phase"])
			saw_pickup = saw_pickup or bool(world.race.safety_car.get("picked_up", false))
			saw_caution_finish = saw_caution_finish or (world.race.flag_time >= 0.0 and int(world.race.race_control["flag"]) == Types.Flag.SC)
			if phase == Types.SafetyCarPhase.IN_THIS_LAP:
				stayed_in_pit = stayed_in_pit and float(world.race.safety_car["s"]) <= float(world.race.safety_car["restart_s"]) + 90.0
			if phase != last_phase:
				print("SMOKE PHASE %d: leader s=%.1f SC=%s" % [phase, world.race.standings()[0].s, world.race.safety_car])
				last_phase = phase
			saw_in_lap = saw_in_lap or int(world.race.safety_car["phase"]) == Types.SafetyCarPhase.IN_THIS_LAP
			saw_peeloff = saw_peeloff or (saw_in_lap and float(world.race.safety_car["lateral"]) > 10.0)
			saw_restart = saw_restart or (saw_peeloff and int(world.race.race_control["flag"]) == Types.Flag.GREEN)
	check(saw_pickup, "Native smoke: Safety Car physically collects leader")
	check((saw_in_lap and saw_peeloff and saw_restart) or saw_caution_finish, "Native smoke: natural withdrawal/restart or legal caution finish")
	check(stayed_in_pit, "Withdrawn SC stays inside pit until green restart")
	check(studio != null, "Native smoke: three-lap race reaches winning studio")
	if studio != null:
		studio.exit_button.pressed.emit()
		for _i: int in range(30):
			await process_frame
		check(current_scene != null and current_scene.scene_file_path == "res://scenes/main.tscn", "Winning studio returns through real HQ exit")
	elif is_instance_valid(world) and not world.is_queued_for_deletion():
		world.queue_free()
	if current_scene != null:
		current_scene.queue_free()
	for _i: int in range(8):
		await process_frame
	world = null
	check(int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)) == 0, "Native smoke cleanup: zero orphan nodes")
