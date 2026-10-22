extends SceneTree

## Run (windowed): Godot --path . --resolution 1920x1080 --script res://scratch/capture_phase5_dashboard.gd -- <out.png> <elapsed_s> <wetness_mm> [sc]
const Dashboard := preload("res://scenes/pit_wall/pit_wall_dashboard.tscn")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var out: String = args[0] if args.size() > 0 else "res://scratch/phase-5-dashboard.png"
	var elapsed: float = float(args[1]) if args.size() > 1 else 650.0
	var wetness: float = float(args[2]) if args.size() > 2 else 0.42
	var dashboard: Control = Dashboard.instantiate()
	root.add_child(dashboard)
	await process_frame
	await process_frame
	var session = dashboard.session
	session.paused = true
	session.control.weather.elapsed_s = elapsed
	session.control.weather.advance(0.01)
	session.control.weather.set_wetness_mm(wetness)
	if args.size() > 3:
		session.control.safety_car.deploy("EXTREME RAIN")
	session.publish()
	session._on_control_radio("TRACK WETNESS EXCEEDING 35% — BOX FOR WETS!", true)
	for _i: int in range(30):
		await process_frame
	await RenderingServer.frame_post_draw
	var image: Image = root.get_texture().get_image()
	print("saved ", out, " err=", image.save_png(out), " ", image.get_size())
	quit()
