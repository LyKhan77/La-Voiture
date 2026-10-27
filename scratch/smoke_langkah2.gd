extends SceneTree
## Langkah 2 native smoke test (GPU needed, not --headless): the redesigned Team Garage under team switches and
## tyre picks, then a 3-lap 20-car night storm race (40 s measured at 1x, the rest at 8x) to the winning studio, back
## to the HQ main menu through the studio's real exit path, and the orphan node count after each scene is freed.
##   godot --path . --resolution 1920x1080 --script res://scratch/smoke_langkah2.gd
const WorldScene := preload("res://scenes/race_weekend_world.tscn")
const GarageScene := preload("res://scenes/ui/garage_team_select.tscn")
const WinningStudio := preload("res://scripts/ui/winning_scene.gd")
const ConfigScript := preload("res://scripts/core/race_config_data.gd")
const PS := preload("res://scripts/core/presentation_settings.gd")
const GARAGE_MEASURE_S: float = 20.0
const GARAGE_SWITCH_EVERY_S: float = 2.0
const RACE_WARMUP_S: float = 15.0
const RACE_MEASURE_S: float = 40.0
const FAST_SCALE: float = 8.0
const TIMEOUT_WALL_S: float = 900.0
func _initialize() -> void:
	call_deferred("_run")
func _orphans() -> int:
	return int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))
func _studio() -> WinningStudio:
	if is_instance_valid(current_scene) and current_scene.scene_file_path == WinningStudio.PATH:
		return current_scene as WinningStudio
	return null
func _report(label: String, frames: Array[float]) -> void:
	var sorted: Array[float] = frames.duplicate()
	sorted.sort()
	var total: float = 0.0
	var over_18: int = 0
	var over_33: int = 0
	for ms: float in sorted:
		total += ms
		over_18 += 1 if ms > 18.5 else 0
		over_33 += 1 if ms > 33.4 else 0
	var count: int = sorted.size()
	print("%s: %d frames  avg %.2f ms (%.1f fps)  median %.2f  p95 %.2f  p99 %.2f  max %.2f  >18.5 ms: %d (%.2f%%)  >33.4 ms: %d" % [
		label, count, total / float(count), 1000.0 * float(count) / total, sorted[count / 2],
		sorted[int(float(count) * 0.95)], sorted[int(float(count) * 0.99)], sorted[count - 1],
		over_18, 100.0 * float(over_18) / float(count), over_33,
	])
func _run() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	PS.set_quality(PS.Quality.HIGH)
	print("GPU: %s  window %s  orphans at start: %d" % [RenderingServer.get_video_adapter_name(), DisplayServer.window_get_size(), _orphans()])
	# --- the garage ---
	var config: RefCounted = ConfigScript.reset()
	config.total_laps = 3
	config.weather_preset = 3
	config.time_of_day = 2
	var garage: Node = GarageScene.instantiate()
	root.add_child(garage)
	current_scene = garage
	for _i: int in range(90):
		await process_frame
	var frames: Array[float] = []
	var started: int = Time.get_ticks_msec()
	var last: int = Time.get_ticks_usec()
	var next_switch: float = GARAGE_SWITCH_EVERY_S
	var switches: int = 0
	while float(Time.get_ticks_msec() - started) / 1000.0 < GARAGE_MEASURE_S:
		await process_frame
		var now: int = Time.get_ticks_usec()
		frames.append(float(now - last) / 1000.0)
		last = now
		var wall: float = float(Time.get_ticks_msec() - started) / 1000.0
		if wall >= next_switch:
			next_switch += GARAGE_SWITCH_EVERY_S
			switches += 1
			garage.select_team(garage.selected_team + 1)
			garage.select_compound(switches % 2, switches % 5)
	_report("GARAGE (%d team switches + tyre picks)" % switches, frames)
	garage.queue_free()
	for _i: int in range(20):
		await process_frame
	print("ORPHAN NODES after freeing the garage: %d" % _orphans())
	# --- the race ---
	config = ConfigScript.reset()
	config.total_laps = 3
	config.weather_preset = 3
	config.time_of_day = 2
	var world: Node3D = WorldScene.instantiate()
	world.race_config = config
	root.add_child(world)
	current_scene = world
	PS.apply_to_tree(world)
	print("RACE: cars=%d laps=%d" % [world.race.cars.size(), config.total_laps])
	started = Time.get_ticks_msec()
	while float(Time.get_ticks_msec() - started) / 1000.0 < RACE_WARMUP_S:
		await process_frame
	frames = []
	last = Time.get_ticks_usec()
	started = Time.get_ticks_msec()
	while float(Time.get_ticks_msec() - started) / 1000.0 < RACE_MEASURE_S:
		await process_frame
		var now_race: int = Time.get_ticks_usec()
		frames.append(float(now_race - last) / 1000.0)
		last = now_race
	_report("RACE 1x (%.0f s measured, race time %.0f s, leader lap %d)" % [RACE_MEASURE_S, world.race.time, world.race.standings()[0].lap], frames)
	world.set_time_scale(FAST_SCALE)
	frames = []
	last = Time.get_ticks_usec()
	started = Time.get_ticks_msec()
	var studio: WinningStudio = null
	var race_time_s: float = 0.0
	var car_count: int = 0
	var finished_count: int = 0
	var winner_number: int = 0
	var winner_lap: int = 0
	while studio == null and float(Time.get_ticks_msec() - started) / 1000.0 < TIMEOUT_WALL_S:
		await process_frame
		var now_fast: int = Time.get_ticks_usec()
		frames.append(float(now_fast - last) / 1000.0)
		last = now_fast
		studio = _studio()
		if studio == null and is_instance_valid(world) and not world.is_queued_for_deletion():
			var live: Array = world.race.standings()
			race_time_s = world.race.time
			car_count = live.size()
			finished_count = 0
			for entry: GtCar in live:
				finished_count += 1 if entry.finished_at >= 0.0 else 0
			winner_number = live[0].number
			winner_lap = live[0].lap
	var finished: bool = studio != null
	print("RACE %s after %.0f s at %.0fx, race time %.0f s" % ["REACHED THE WINNING STUDIO" if finished else "TIMED OUT", float(Time.get_ticks_msec() - started) / 1000.0, FAST_SCALE, race_time_s])
	_report("RACE %.0fx to the winning studio" % FAST_SCALE, frames)
	print("FINISHED %d of %d, winner #%d lap %d" % [finished_count, car_count, winner_number, winner_lap])
	if finished:
		studio.exit_button.pressed.emit()
		for _i: int in range(60):
			await process_frame
		print("BACK AT: %s" % (current_scene.scene_file_path if current_scene != null else "<no scene>"))
		if current_scene != null:
			current_scene.queue_free()
		for _i: int in range(20):
			await process_frame
	print("ORPHAN NODES after returning to the menu and freeing it: %d" % _orphans())
	quit(0)
