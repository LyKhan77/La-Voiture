extends SceneTree

## Where do the slow frames come from? Native run (needs a GPU, not --headless):
##   godot --path . --resolution 1920x1080 --script res://scratch/profile_frame_budget.gd -- <circuit_id> [seconds] [capped|uncapped]
## Records every frame of a normal 1x race: wall time, script time, physics time, CPU and GPU render time of the
## viewport, draw calls, and how many sim ticks ran in that frame. Reports percentiles and what the frames over
## the 60 FPS budget have in common (sim ticks, frame spacing), and writes a CSV to temp/perf/.
## `uncapped` lifts run/max_fps so the numbers show what the frame costs instead of the 16.67 ms cap.

const WorldScene := preload("res://scenes/race_weekend_world.tscn")
const ConfigScript := preload("res://scripts/core/race_config_data.gd")
const Types := preload("res://scripts/gt/gt_types.gd")

const WARMUP_FRAMES: int = 240
const BUDGET_MS: float = 1000.0 / 60.0

var world: Node3D


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var circuit: String = args[0] if args.size() > 0 else "brianza"
	var seconds: float = float(args[1]) if args.size() > 1 else 25.0
	var capped: bool = args.size() > 2 and args[2] == "capped"
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 60 if capped else 0
	var config := ConfigScript.get_config()
	config.selected_circuit_id = circuit
	config.total_laps = 3
	config.time_of_day = 0
	config.weather_preset = 0
	config.selected_team_id = 0
	config.race_seed = 19220903
	world = WorldScene.instantiate()
	root.add_child(world)
	world.finish_grid_intro()
	var rid: RID = root.get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(rid, true)
	for _i: int in range(WARMUP_FRAMES):
		await process_frame
	var rows: Array[Dictionary] = []
	var last_usec: int = Time.get_ticks_usec()
	var last_time: float = float(world.race.time)
	var begin: int = Time.get_ticks_msec()
	while float(Time.get_ticks_msec() - begin) < seconds * 1000.0 and not world.race.is_finished():
		await process_frame
		var now: int = Time.get_ticks_usec()
		var race_time: float = float(world.race.time)
		rows.append({
			"frame": float(now - last_usec) / 1000.0,
			"process": Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0,
			"physics": Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0,
			"cpu": RenderingServer.viewport_get_measured_render_time_cpu(rid),
			"gpu": RenderingServer.viewport_get_measured_render_time_gpu(rid),
			"calls": Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
			"ticks": roundi((race_time - last_time) / Types.TICK_DT),
		})
		last_usec = now
		last_time = race_time
	_report(circuit, capped, rows)
	_write_csv(circuit, capped, rows)
	world.queue_free()
	quit(0)


func _report(circuit: String, capped: bool, rows: Array[Dictionary]) -> void:
	print("PROFILE %s %s frames=%d" % [circuit, "capped60" if capped else "uncapped", rows.size()])
	for key: String in ["frame", "process", "physics", "cpu", "gpu", "calls"]:
		var values: Array[float] = []
		for row: Dictionary in rows:
			values.append(float(row[key]))
		values.sort()
		var total: float = 0.0
		for value: float in values:
			total += value
		print("  %-8s mean %7.2f  p50 %7.2f  p95 %7.2f  p99 %7.2f  max %7.2f" % [key, total / float(values.size()), _pct(values, 0.5), _pct(values, 0.95), _pct(values, 0.99), values[values.size() - 1]])
	var slow: Array[int] = []
	for index: int in range(rows.size()):
		if float(rows[index]["frame"]) > BUDGET_MS * 1.25:
			slow.append(index)
	var with_ticks: int = 0
	var multi_tick: int = 0
	var gpu_bound: int = 0
	var cpu_bound: int = 0
	for index: int in slow:
		var row: Dictionary = rows[index]
		with_ticks += 1 if int(row["ticks"]) >= 1 else 0
		multi_tick += 1 if int(row["ticks"]) >= 2 else 0
		gpu_bound += 1 if float(row["gpu"]) >= float(row["cpu"]) and float(row["gpu"]) > BUDGET_MS else 0
		cpu_bound += 1 if float(row["cpu"]) > float(row["gpu"]) and float(row["cpu"]) > BUDGET_MS else 0
	print("  slow frames (> %.1f ms): %d of %d (%.1f%%)" % [BUDGET_MS * 1.25, slow.size(), rows.size(), 100.0 * float(slow.size()) / float(maxi(rows.size(), 1))])
	print("    with a sim tick in the frame: %d, with 2+ ticks: %d" % [with_ticks, multi_tick])
	print("    render GPU-bound (gpu > cpu and > budget): %d, render CPU-bound: %d" % [gpu_bound, cpu_bound])
	var gaps: Dictionary = {}
	for i: int in range(1, slow.size()):
		var gap: int = slow[i] - slow[i - 1]
		gaps[gap] = int(gaps.get(gap, 0)) + 1
	var gap_keys: Array = gaps.keys()
	gap_keys.sort_custom(func(a: int, b: int) -> bool: return int(gaps[a]) > int(gaps[b]))
	var top: Array[String] = []
	for key: int in gap_keys.slice(0, 5):
		top.append("%d frames x%d" % [key, int(gaps[key])])
	print("    most common spacing between slow frames: %s" % ", ".join(top))
	var by_ticks: Dictionary = {}
	for row: Dictionary in rows:
		var ticks: int = clampi(int(row["ticks"]), 0, 4)
		if not by_ticks.has(ticks):
			by_ticks[ticks] = []
		(by_ticks[ticks] as Array).append(float(row["frame"]))
	for ticks: int in range(5):
		if by_ticks.has(ticks):
			var list: Array = by_ticks[ticks]
			var sum: float = 0.0
			for value: float in list:
				sum += value
			print("    frames with %d%s tick(s): %d, mean frame %.2f ms" % [ticks, "+" if ticks == 4 else "", list.size(), sum / float(list.size())])


func _pct(sorted_values: Array[float], fraction: float) -> float:
	return sorted_values[clampi(int(float(sorted_values.size()) * fraction), 0, sorted_values.size() - 1)]


func _write_csv(circuit: String, capped: bool, rows: Array[Dictionary]) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://temp/perf/"))
	var file := FileAccess.open("res://temp/perf/%s-%s.csv" % [circuit, "capped" if capped else "uncapped"], FileAccess.WRITE)
	file.store_line("index,frame_ms,process_ms,physics_ms,render_cpu_ms,render_gpu_ms,draw_calls,ticks")
	for index: int in range(rows.size()):
		var row: Dictionary = rows[index]
		file.store_line("%d,%.3f,%.3f,%.3f,%.3f,%.3f,%d,%d" % [index, row["frame"], row["process"], row["physics"], row["cpu"], row["gpu"], int(row["calls"]), int(row["ticks"])])
