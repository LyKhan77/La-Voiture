extends SceneTree

## FASE 8.5 native smoke test: a 20-car night storm race at 1080p, frame times (vsync off) and the orphan-node
## count after the world is freed. Needs a GPU (not --headless):
##   godot --path . --resolution 1920x1080 --script res://scratch/smoke_fase85.gd -- [quality 0..3] [measure_seconds]

const WorldScene := preload("res://scenes/race_weekend_world.tscn")
const ConfigScript := preload("res://scripts/core/race_config_data.gd")
const PS := preload("res://scripts/core/presentation_settings.gd")

const WARMUP_S: float = 15.0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var quality: int = int(args[0]) if args.size() > 0 else PS.Quality.HIGH
	var measure_s: float = float(args[1]) if args.size() > 1 else 40.0
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	PS.set_quality(quality)
	var config: RefCounted = ConfigScript.reset()
	config.total_laps = 3
	config.weather_preset = 3 # the heaviest weather preset
	config.time_of_day = 2 # night: headlight beams and tail trails on
	var world: Node3D = WorldScene.instantiate()
	world.race_config = config
	root.add_child(world)
	PS.apply_to_tree(world)
	print("GPU: %s  quality=%s  cars=%d" % [RenderingServer.get_video_adapter_name(), PS.QUALITY_NAMES[quality], world.race.cars.size()])
	if args.size() > 2 and args[2] == "noaudio":
		for actor in world.actors:
			actor.audio.engine.set_process(false)
			actor.audio.engine.set_physics_process(false)
			actor.audio.tire.set_process(false)
	var started: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - started < int(WARMUP_S * 1000.0):
		await process_frame
	RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(), true)
	var frames: Array[float] = []
	var gpu_ms: float = 0.0
	var cpu_render_ms: float = 0.0
	var script_ms: float = 0.0
	var physics_ms: float = 0.0
	var draw_calls: Array[int] = []
	var last: int = Time.get_ticks_usec()
	started = Time.get_ticks_msec()
	while Time.get_ticks_msec() - started < int(measure_s * 1000.0):
		await process_frame
		var now: int = Time.get_ticks_usec()
		frames.append(float(now - last) / 1000.0)
		last = now
		gpu_ms += RenderingServer.viewport_get_measured_render_time_gpu(root.get_viewport_rid())
		cpu_render_ms += RenderingServer.viewport_get_measured_render_time_cpu(root.get_viewport_rid())
		script_ms += Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
		physics_ms += Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0
		draw_calls.append(int(RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)))
	frames.sort()
	var total: float = 0.0
	for ms: float in frames:
		total += ms
	var average: float = total / float(frames.size())
	var p95: float = frames[int(float(frames.size()) * 0.95)]
	var p99: float = frames[int(float(frames.size()) * 0.99)]
	var calls_max: int = 0
	for calls: int in draw_calls:
		calls_max = maxi(calls_max, calls)
	print("FRAMES %d  avg %.2f ms (%.0f fps)  p95 %.2f  p99 %.2f  max %.2f  draw calls max %d" % [frames.size(), average, 1000.0 / average, p95, p99, frames[frames.size() - 1], calls_max])
	print("COST per frame: GPU %.2f ms  render-CPU %.2f ms  _process %.2f ms  physics %.2f ms" % [gpu_ms / float(frames.size()), cpu_render_ms / float(frames.size()), script_ms / float(frames.size()), physics_ms / float(frames.size())])
	_component_costs(world)
	print("RACE time %.0f s, leader lap %d" % [world.race.time, world.race.standings()[0].lap])
	world.race.dispose()
	world.queue_free()
	for _i: int in range(10):
		await process_frame
	print("ORPHAN NODES after freeing the world: %d" % int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)))
	quit(0)


## Per-call cost (ms) of the pieces that run every frame, measured on the live race.
func _component_costs(world: Node3D) -> void:
	var timed: Dictionary = {
		"vfx.update": func() -> void: world.vfx.update(0.016),
		"hud.update": func() -> void: world.hud.update(0.016),
		"actors.present": func() -> void:
			for actor in world.actors:
				actor.present(1.0, 0.016),
		"race.step": func() -> void: world.race.step(),
		"car audio x20": func() -> void:
			for actor in world.actors:
				actor.audio.update_from_car(actor.car, true),
		"world.step": func() -> void: world.step(0.016),
	}
	for label: String in timed:
		var call: Callable = timed[label]
		var begin: int = Time.get_ticks_usec()
		for _i: int in range(120):
			call.call()
		print("  %-16s %.3f ms/call" % [label, float(Time.get_ticks_usec() - begin) / 1000.0 / 120.0])
