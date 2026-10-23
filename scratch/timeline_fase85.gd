extends SceneTree

## Frame time per second of a night-storm 20-car race from the lights: shows when the cost peaks. Needs a GPU:
##   godot --path . --resolution 1920x1080 --script res://scratch/timeline_fase85.gd -- [quality 0..3] [seconds]

const WorldScene := preload("res://scenes/race_weekend_world.tscn")
const ConfigScript := preload("res://scripts/core/race_config_data.gd")
const PS := preload("res://scripts/core/presentation_settings.gd")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var quality: int = int(args[0]) if args.size() > 0 else PS.Quality.HIGH
	var seconds: int = int(args[1]) if args.size() > 1 else 90
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	PS.set_quality(quality)
	var config: RefCounted = ConfigScript.reset()
	config.total_laps = 3
	config.weather_preset = 3
	config.time_of_day = 2
	var world: Node3D = WorldScene.instantiate()
	world.race_config = config
	root.add_child(world)
	PS.apply_to_tree(world)
	var variant: String = args[2] if args.size() > 2 else ""
	if variant == "noradio":
		world.race.radio_message.disconnect(world.hud._on_radio)
	elif variant == "nohud":
		world.hud.visible = false
	elif variant == "nolightning":
		world.race.weather.lightning_flash = 0.0
		world.vfx.set("lightning", 0.0)
	var second: int = 0
	var begin: int = Time.get_ticks_msec()
	var frames: float = 0.0
	var total: float = 0.0
	var process_ms: float = 0.0
	var physics_ms: float = 0.0
	var last: int = Time.get_ticks_usec()
	while second < seconds:
		await process_frame
		var now: int = Time.get_ticks_usec()
		total += float(now - last) / 1000.0
		last = now
		frames += 1.0
		process_ms += Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
		physics_ms += Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0
		if Time.get_ticks_msec() - begin >= (second + 1) * 1000:
			second += 1
			if second % 3 == 0:
				print("t=%3ds  frame %5.2f ms (%3.0f fps)  _process %5.2f  physics %5.2f  | race %5.1f s  state %s" % [second, total / frames, frames / 3.0, process_ms / frames, physics_ms / frames, world.race.time, world.director.state])
				frames = 0.0
				total = 0.0
				process_ms = 0.0
				physics_ms = 0.0
	quit(0)
