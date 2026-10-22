extends SceneTree

## Run (windowed, needs a GPU): Godot --path . --resolution 1920x1080 --script res://scratch/capture_phase5_wet_track.gd
## Optional user args after `--`: <out.png> <wetness_mm> <state_int> <frames> <time_scale> <followed_car_index>

const WorldScene := preload("res://scenes/test_weather_world.tscn")
const Weather := preload("res://scripts/core/weather_manager.gd")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var out: String = args[0] if args.size() > 0 else "res://scratch/phase-5-wet-track.png"
	var wetness: float = float(args[1]) if args.size() > 1 else 1.4
	var state: int = int(args[2]) if args.size() > 2 else Weather.WeatherState.HEAVY_DOWNPOUR
	var frames: int = int(args[3]) if args.size() > 3 else 420
	var scale: float = float(args[4]) if args.size() > 4 else 2.0
	var world: Node3D = WorldScene.instantiate()
	root.add_child(world)
	var none: Array[Dictionary] = []
	world.control.weather.set_schedule(none)
	world.control.weather.set_state(state)
	world.control.weather.set_wetness_mm(wetness)
	world.set_time_scale(scale)
	if args.size() > 5:
		world.followed_index = int(args[5])
	for _i: int in range(frames):
		await physics_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var image: Image = root.get_texture().get_image()
	var err: int = image.save_png(out)
	print("saved ", out, " err=", err, " size=", image.get_size(), " wet=", world.control.weather.weather_wetness_mm, " sc=", world.control.safety_car.is_active)
	quit()
