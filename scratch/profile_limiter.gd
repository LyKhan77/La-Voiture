extends SceneTree

## How steady is the frame limiter on its own? An empty scene with a camera and one mesh, so any jitter around the
## target frame time comes from the limiter and the OS timer, not from the game. Native run:
##   godot --path . --resolution 1920x1080 --script res://scratch/profile_limiter.gd -- [max_fps] [frames]

func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var target: int = int(args[0]) if args.size() > 0 else 60
	var frames: int = int(args[1]) if args.size() > 1 else 1200
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = target
	var camera := Camera3D.new()
	root.add_child(camera)
	var mesh := MeshInstance3D.new()
	mesh.mesh = BoxMesh.new()
	root.add_child(mesh)
	camera.position = Vector3(0.0, 0.0, 4.0)
	for _i: int in range(120):
		await process_frame
	var times: Array[float] = []
	var last: int = Time.get_ticks_usec()
	for _i: int in range(frames):
		await process_frame
		var now: int = Time.get_ticks_usec()
		times.append(float(now - last) / 1000.0)
		last = now
	var sorted := times.duplicate()
	sorted.sort()
	var mean: float = 0.0
	for value: float in times:
		mean += value
	mean /= float(times.size())
	var over: int = 0
	for value: float in times:
		over += 1 if value > 1000.0 / float(target) * 1.25 else 0
	print("LIMITER max_fps=%d frames=%d mean %.2f p50 %.2f p95 %.2f p99 %.2f max %.2f  over 125%%: %d" % [target, times.size(), mean, sorted[times.size() / 2], sorted[int(times.size() * 0.95)], sorted[int(times.size() * 0.99)], sorted[times.size() - 1], over])
	quit(0)
