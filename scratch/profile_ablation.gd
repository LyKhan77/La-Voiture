extends SceneTree

## Where does the frame go? Counts every processing node by script, then switches each group off in turn
## and measures the frame again (ablation), plus the physics-server counters. Needs a GPU:
##   godot --path . --resolution 1920x1080 --script res://scratch/profile_fase85.gd -- [quality 0..3] [seconds per step]

const WorldScene := preload("res://scenes/race_weekend_world.tscn")
const ConfigScript := preload("res://scripts/core/race_config_data.gd")
const PS := preload("res://scripts/core/presentation_settings.gd")

var world: Node3D


func _initialize() -> void:
	call_deferred("_run")


func _measure(seconds: float) -> Dictionary:
	var frames: float = 0.0
	var total_ms: float = 0.0
	var process_ms: float = 0.0
	var physics_ms: float = 0.0
	var last: int = Time.get_ticks_usec()
	var begin: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - begin < int(seconds * 1000.0):
		await process_frame
		var now: int = Time.get_ticks_usec()
		total_ms += float(now - last) / 1000.0
		last = now
		frames += 1.0
		process_ms += Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
		physics_ms += Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0
	return {"frame": total_ms / frames, "process": process_ms / frames, "physics": physics_ms / frames}


func _walk(node: Node, groups: Dictionary) -> void:
	if node.is_processing() or node.is_physics_processing():
		var script: Script = node.get_script()
		var key: String = script.resource_path.get_file() if script != null else node.get_class()
		if not groups.has(key):
			groups[key] = []
		(groups[key] as Array).append(node)
	for child: Node in node.get_children():
		_walk(child, groups)


func _report(label: String, result: Dictionary, baseline: float) -> void:
	print("  %-34s frame %5.2f ms  (_process %5.2f, physics %5.2f)  delta %+.2f" % [label, result["frame"], result["process"], result["physics"], float(result["frame"]) - baseline])


func _run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var quality: int = int(args[0]) if args.size() > 0 else PS.Quality.HIGH
	var seconds: float = float(args[1]) if args.size() > 1 else 6.0
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	PS.set_quality(quality)
	var config: RefCounted = ConfigScript.reset()
	config.total_laps = 3
	config.selected_circuit_id = "brianza"
	config.weather_preset = 0
	config.time_of_day = 0
	world = WorldScene.instantiate()
	world.race_config = config
	root.add_child(world)
	PS.apply_to_tree(world)
	var started: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - started < 15000:
		await process_frame
	print("NODES %d  objects %d  draw calls %d  primitives %d" % [
		int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)), int(Performance.get_monitor(Performance.OBJECT_COUNT)),
		int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)), int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))])
	print("PHYSICS3D active %d  pairs %d  islands %d" % [
		int(Performance.get_monitor(Performance.PHYSICS_3D_ACTIVE_OBJECTS)), int(Performance.get_monitor(Performance.PHYSICS_3D_COLLISION_PAIRS)), int(Performance.get_monitor(Performance.PHYSICS_3D_ISLAND_COUNT))])
	var groups: Dictionary = {}
	_walk(world, groups)
	var order: Array = groups.keys()
	order.sort_custom(func(a: String, b: String) -> bool: return (groups[a] as Array).size() > (groups[b] as Array).size())
	print("PROCESSING NODES by script:")
	for key: String in order:
		print("  %4d  %s" % [(groups[key] as Array).size(), key])
	var base: Dictionary = await _measure(seconds)
	print("BASELINE")
	_report("all on", base, float(base["frame"]))
	print("ABLATION (group switched off, 'delta' = frame change; negative = that group costs time)")
	for key: String in order:
		var nodes: Array = groups[key]
		if key == "race_weekend_world.gd":
			continue # it drives the whole sim; measured separately below
		for node: Node in nodes:
			node.set_process(false)
			node.set_physics_process(false)
		var result: Dictionary = await _measure(seconds)
		_report("%s x%d" % [key, nodes.size()], result, float(base["frame"]))
		for node: Node in nodes:
			node.set_process(true)
			node.set_physics_process(true)
	# Visual toggles that cost CPU-side submission or GPU time.
	var environment: Environment = (world.get_node("WorldEnvironment") as WorldEnvironment).environment
	var sun: DirectionalLight3D = world.get_node("Sun")
	print("RENDER TOGGLES")
	sun.shadow_enabled = false
	_report("sun shadows off", await _measure(seconds), float(base["frame"]))
	sun.shadow_enabled = true
	var hud: Node = world.hud
	hud.visible = false
	_report("HUD hidden", await _measure(seconds), float(base["frame"]))
	hud.visible = true
	var actors: Array = world.actors
	for actor: Node3D in actors:
		actor.visible = false
	_report("all 20 cars hidden", await _measure(seconds), float(base["frame"]))
	for actor: Node3D in actors:
		actor.visible = true
	environment.glow_enabled = false
	environment.ssr_enabled = false
	environment.ssao_enabled = false
	_report("glow + ssr + ssao off", await _measure(seconds), float(base["frame"]))
	quit(0)
