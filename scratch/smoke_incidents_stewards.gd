extends SceneTree

## FASE 11 Langkah 6 native gate: 1080p captures of the incident dynamics, flag panels, wreck and steward banner,
## and with `-- --smoke` a real three-lap night-storm race (High, 20 cars) with incidents staged on the grid, measuring
## frame time and orphan nodes through the exit to HQ.
## Run: Godot --path . -s res://scratch/smoke_incidents_stewards.gd -- --smoke
const WorldScene := preload("res://scenes/race_weekend_world.tscn")
const Config := preload("res://scripts/core/race_config_data.gd")
const Types := preload("res://scripts/gt/gt_types.gd")
const PS := preload("res://scripts/core/presentation_settings.gd")
const OUT := "res://executor-report/screenshots/phases/"
const SHOT := "phase-11-step-6-"

var world: RaceWeekendWorld
var failures: int = 0


func _initialize() -> void:
	call_deferred("_run")


func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
	print("[%s] %s" % ["PASS" if ok else "FAIL", message])


func _save(file_name: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	var image: Image = root.get_texture().get_image()
	check(image.get_size() == Vector2i(1920, 1080), "Screenshot native 1920x1080")
	check(image.save_png(OUT + SHOT + file_name + ".png") == OK, "Saved " + file_name)


## Three frames a few ms apart (the LEDs blink at 4 Hz); keeps the one with the most LED yellow in it.
func _save_brightest(file_name: String) -> void:
	var best: Image = null
	var best_score: int = -1
	for _i: int in range(3):
		await process_frame
		await RenderingServer.frame_post_draw
		var image: Image = root.get_texture().get_image()
		var score: int = 0
		for y: int in range(300, 760, 4):
			for x: int in range(500, 1400, 4):
				var c: Color = image.get_pixel(x, y)
				score += 1 if c.r > 0.85 and c.g > 0.6 and c.b < 0.35 else 0
		if score > best_score:
			best_score = score
			best = image
		await create_timer(0.07).timeout
	check(best.get_size() == Vector2i(1920, 1080) and best.save_png(OUT + SHOT + file_name + ".png") == OK, "Saved %s (LED pixels %d)" % [file_name, best_score])


func _look(from: Vector3, at: Vector3, fov: float = 60.0) -> void:
	world.camera.global_position = from
	world.camera.fov = fov
	world.camera.look_at(at, Vector3.UP)


func _make_world(weather: int, time_of_day: int, laps: int, hold: bool) -> void:
	var config: RaceConfigData = Config.reset()
	config.total_laps = laps
	config.weather_preset = weather
	config.time_of_day = time_of_day
	world = WorldScene.instantiate() as RaceWeekendWorld
	world.race_config = config
	world.pre_grid_hold = hold
	root.add_child(world)
	current_scene = world
	root.scaling_3d_scale = 1.0


func _run() -> void:
	root.content_scale_size = Vector2i(1920, 1080)
	DisplayServer.window_set_size(Vector2i(1920, 1080))
	PS.set_quality(PS.Quality.HIGH)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	await _captures()
	if "--smoke" in OS.get_cmdline_user_args():
		await _smoke()
	quit(1 if failures > 0 else 0)


func _captures() -> void:
	_make_world(0, 2, 3, false) # dry, night: the LED panels and hazard lamps read best in the dark
	world.set_physics_process(false)
	world.race.incidents_enabled = false
	world.director._enter(world.director.State.GREEN_RACING)
	for _i: int in range(60):
		await process_frame
	for _i: int in range(240):
		world.step(1.0 / 60.0)
	var furniture: Node3D = world.environment.furniture
	var panel: Dictionary = furniture.flag_panel_records[1]
	var side: float = panel["side"]
	var panel_s: float = panel["s"]
	var panel_at: Vector3 = world.ribbon.get_point_at_offset(panel_s, furniture.armco_lateral(side, panel_s) + side * 0.6).origin + Vector3.UP * 2.2
	var camera_at: Vector3 = world.ribbon.get_point_at_offset(panel_s - 13.0, -side * 2.0).origin + Vector3.UP * 2.3
	# Yellow in the panel's own sector, then the safety car on every panel.
	world.race.set_flag(Types.Flag.YELLOW, int(panel["sector"]), "YELLOW FLAG - TEST", 30.0)
	world.step(1.0 / 60.0)
	_look(camera_at, panel_at, 42.0)
	await _save_brightest("flag-panel-yellow")
	world.race.set_flag(Types.Flag.SC, int(panel["sector"]), "SAFETY CAR DEPLOYED - TEST", 30.0)
	world.step(1.0 / 60.0)
	_look(camera_at, panel_at, 42.0)
	await _save_brightest("flag-panel-sc")
	world.race.set_flag(Types.Flag.GREEN, 1, "TRACK CLEAR - GREEN FLAG", 0.0)
	world.step(1.0 / 60.0)

	# Snap oversteer: the car at the top of its slide, front wheels on opposite lock.
	var spinner: GtCar = world.race.cars[3]
	spinner.lateral = 2.0
	spinner.v = 62.0
	spinner.spin_timer = 4.0
	world.race.step()
	world.race.step()
	var actor: GtCarActor = world.actor_of(spinner.id)
	actor.present(1.0, 1.0 / 60.0)
	world.vfx.update(1.0 / 60.0)
	# Front three-quarter view, so the opposite lock of the front wheels is in frame.
	_look(actor.global_position - actor.global_basis.z * 7.5 + actor.global_basis.x * 4.5 + Vector3.UP * 1.6, actor.global_position + Vector3.UP * 0.5, 55.0)
	check(absf(spinner.yaw_offset) > 0.3 and absf(spinner.yaw_offset) <= 0.55, "Capture: slide at %.2f rad, bounded" % spinner.yaw_offset)
	await _save("snap-oversteer-countersteer")

	# A retired car against the barrier: smoke, hazards, banner.
	var wreck: GtCar = world.race.cars[8]
	wreck.is_dnf = true
	wreck.dnf_reason = "Collision"
	wreck.v = 0.0
	wreck.lateral = 7.4
	wreck.damage = 100.0
	wreck.finished_at = world.race.time
	world.race.step()
	var wreck_actor: GtCarActor = world.actor_of(wreck.id)
	for _i: int in range(90):
		wreck_actor.present(1.0, 1.0 / 60.0)
		world.vfx.update(1.0 / 60.0)
		await process_frame
	var wreck_pose: Transform3D = world.track.point_at(wreck.s, 3.0)
	_look(wreck_pose.origin + wreck_pose.basis.z * 9.0 + wreck_pose.basis.x * -2.0 + Vector3.UP * 2.0, wreck_actor.global_position + Vector3.UP * 0.7, 55.0)
	world.race.steward_event.emit({"phase": "investigation", "case_id": 1, "kind": 0, "car_id": wreck.id, "text": "/// STEWARDS: INCIDENT INVOLVING CAR #%d UNDER INVESTIGATION" % wreck.number, "time": world.race.time})
	world.hud.update(0.0)
	await _save("dnf-wreck-smoke-hazard")
	# Halfway through the in-lap recovery: the wreck is half transparent, the smoke and hazards are off.
	wreck.evac_started_at = world.race.time - 1.0
	wreck.wreck_alpha = 0.5
	wreck_actor.present(1.0, 1.0 / 60.0)
	world.vfx.update(1.0 / 60.0)
	await _save("dnf-evacuation-fade")
	wreck.evac_started_at = -1.0
	wreck.wreck_alpha = 1.0
	wreck_actor.present(1.0, 1.0 / 60.0)
	world.race.steward_event.emit({"phase": "verdict", "case_id": 1, "kind": 0, "verdict": 2, "car_id": wreck.id, "text": "+5s TIME PENALTY // CAR #%d: CAUSING A COLLISION" % wreck.number, "time": world.race.time})
	world.camera_director.set_mode(world.camera_director.Mode.CHASE)
	world.camera_director.update(0.0)
	await _save("steward-penalty-banner")
	world.queue_free()
	world = null
	for _i: int in range(8):
		await process_frame
	check(int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)) == 0, "Capture cleanup: zero orphan nodes")


func _smoke() -> void:
	_make_world(3, 2, 3, true) # thunderstorm night
	world.race.incidents_enabled = true
	print("RENDER: viewport=%s scale=%.1f" % [root.size, root.scaling_3d_scale])
	check(world.race.cars.size() == 20, "Native smoke: 20 cars / three laps / night storm / High")
	print("GPU: %s" % RenderingServer.get_video_adapter_name())
	var start_ms: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - start_ms < 8000:
		await process_frame
	world.finish_grid_intro()
	start_ms = Time.get_ticks_msec()
	while not world.director.is_racing() and Time.get_ticks_msec() - start_ms < 30000:
		await process_frame
	# Incidents on the grid for the measured window: a slide, a retirement under yellow, a rear-end hit.
	var race: GtRace = world.race
	var verdicts: Array[String] = []
	race.steward_event.connect(func(event: Dictionary) -> void: verdicts.append(String(event["text"])))
	world.set_time_scale(16.0)
	while race.time < GtStewards.START_GRACE_S + 5.0 and not world.race.is_finished():
		await process_frame
	world.set_time_scale(1.0)
	await create_timer(2.0).timeout
	race.cars[5].lateral = 2.0
	race.cars[5].spin_timer = 4.0
	var retired: GtCar = race.cars[12]
	retired.is_dnf = true
	retired.dnf_reason = "Collision"
	retired.v = 0.0
	retired.lateral = 7.4
	retired.damage = 100.0
	retired.finished_at = race.time
	race.set_flag(Types.Flag.YELLOW, retired.current_sector + 1, "YELLOW FLAG - CAR STOPPED", 20.0)
	# Two cars that are really on the track (a storm start sends some of the field down the pit lane).
	var on_track: Array[GtCar] = []
	for car: GtCar in race.standings():
		if car.is_racing() and car != race.cars[5] and car != retired and car.lap >= 0:
			on_track.append(car)
	var rear: GtCar = on_track[2]
	var front: GtCar = on_track[3]
	front.s = rear.s + 4.0
	front.lateral = rear.lateral
	front.v = 40.0
	rear.v = 52.0
	var frames: Array[float] = []
	var last_us: int = Time.get_ticks_usec()
	start_ms = Time.get_ticks_msec()
	while Time.get_ticks_msec() - start_ms < 12000:
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
	print("NATIVE 1x INCIDENT SAMPLE: %d frames avg %.3f ms / %.2f FPS p95 %.3f ms max %.3f ms" % [frames.size(), total_ms / frames.size(), avg_fps, p95_ms, frames[-1]])
	check(avg_fps >= 50.0 and p95_ms <= 32.0, "Performance gate: avg FPS %.2f >=50.0, p95 %.2f <=32.0 ms" % [avg_fps, p95_ms])
	check(race.stewards.cases.size() >= 1, "Native smoke: the staged rear-end hit reached the stewards (%d cases, %s)" % [race.stewards.cases.size(), verdicts])
	world.set_time_scale(16.0)
	start_ms = Time.get_ticks_msec()
	while world.podium == null and Time.get_ticks_msec() - start_ms < 420000:
		await process_frame
	check(race.cars.size() == 20, "Native smoke: race.cars still holds 20 cars")
	check(world.podium != null, "Native smoke: three-lap race reaches podium")
	print("STEWARD LOG: %s" % [verdicts])
	if world.podium != null:
		world.podium.exit_requested.emit()
		for _i: int in range(30):
			await process_frame
		check(current_scene != null and current_scene.scene_file_path == "res://scenes/main.tscn", "Podium returns through real HQ exit")
	else:
		world.queue_free()
	if current_scene != null:
		current_scene.queue_free()
	for _i: int in range(8):
		await process_frame
	world = null
	check(int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)) == 0, "Native smoke cleanup: zero orphan nodes")
