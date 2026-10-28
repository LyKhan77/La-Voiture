extends SceneTree

const World := preload("res://scenes/race_weekend_world.tscn")
const Config := preload("res://scripts/core/race_config_data.gd")
const Settings := preload("res://scripts/core/presentation_settings.gd")
const FRAME_BUDGET_MS: float = 1000.0 / 60.0
var world: Node3D
var times: Array[float] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	DisplayServer.window_set_size(Vector2i(1920, 1080))
	root.size = Vector2i(1920, 1080)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED)
	Engine.max_fps = 60
	Settings.set_quality(Settings.Quality.HIGH)
	var config := Config.get_config()
	config.selected_circuit_id = "neo_wangan"
	config.total_laps = 3
	config.time_of_day = 2
	config.weather_preset = 0
	config.race_seed = 12022026
	world = World.instantiate()
	root.add_child(world)
	world.race.incidents_enabled = false
	var pit_car: GtCar = world.race.cars[0]
	for car: GtCar in world.race.cars:
		if world.race.stall_index_for_team(car.team_id) == 0:
			pit_car = car
			break
	var pit_requested: bool = world.request_pit(pit_car.id)
	world.finish_grid_intro()
	while not world.director.is_racing():
		await process_frame
	for frame: int in range(300):
		await process_frame
	var last: int = Time.get_ticks_usec()
	for frame: int in range(600):
		await process_frame
		var now: int = Time.get_ticks_usec()
		times.append(float(now - last) / 1000.0)
		last = now
	var sum_ms: float = 0.0
	var late_frames: int = 0
	for ms: float in times:
		sum_ms += ms
		if ms > FRAME_BUDGET_MS:
			late_frames += 1
	times.sort()
	var mean: float = sum_ms / float(times.size())
	print("PHASE12_SMOKE frames=%d mean_ms=%.3f p95_ms=%.3f worst_ms=%.3f fps=%.2f draw_calls=%d tris=%d" % [times.size(), mean, times[int(times.size() * 0.95)], times.back(), 1000.0 / mean, int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)), int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))])
	print("PHASE12_SMOKE frame_budget_ms=%.6f late_frames=%d locked_60=%s" % [FRAME_BUDGET_MS, late_frames, late_frames == 0])
	world.set_time_scale(16.0)
	var guard: int = 0
	while not world.race.is_finished() and guard < 12000:
		await process_frame
		guard += 1
	var finishers: int = 0
	for car in world.race.cars:
		if car.finished_at >= 0.0:
			finishers += 1
	print("PHASE12_SMOKE finished=%s finishers=%d cars=%d laps=3 orphans_in_race=%d" % [world.race.is_finished(), finishers, world.actors.size(), int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))])
	print("PHASE12_PIT first_stall_car=%d requested=%s service_stops=%d" % [pit_car.id, pit_requested, pit_car.stops])
	var finished: bool = world.race.is_finished() and finishers == 20 and pit_requested and pit_car.stops > 0
	world.queue_free()
	for frame: int in range(6):
		await process_frame
	var error: Error = change_scene_to_file("res://scenes/ui/main_menu.tscn")
	for frame: int in range(60):
		await process_frame
	var orphans: int = int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))
	var menu_loaded: bool = current_scene != null and current_scene.scene_file_path.ends_with("main_menu.tscn")
	print("PHASE12_SMOKE menu=%s error=%d orphans_after_menu=%d" % [menu_loaded, error, orphans])
	if current_scene != null:
		current_scene.queue_free()
		current_scene = null
	for frame: int in range(10):
		await process_frame
	# Release shared procedural textures before RenderingDevice shuts down (same teardown as tests).
	load("res://scripts/vfx/race_vfx.gd")._textures.clear()
	load("res://scripts/ui/anime_radio_cutin.gd").halftone_tile = null
	load("res://scripts/ui/street_style.gd")._switch_cache.clear()
	load("res://scripts/ui/manga/manga_panel.gd")._dots = null
	load("res://scripts/ui/manga/wheatpaste_poster.gd")._grain = null
	for frame: int in range(3):
		await process_frame
	quit(0 if finished and error == OK and menu_loaded and orphans == 0 and late_frames == 0 else 1)

