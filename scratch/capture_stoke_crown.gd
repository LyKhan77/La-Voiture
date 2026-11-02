extends SceneTree

## Native 1080p release gate; approved camera stations plus two-way chase coverage.
const WorldScene := preload("res://scenes/race_weekend_world.tscn")
const Config := preload("res://scripts/core/race_config_data.gd")
const Settings := preload("res://scripts/core/presentation_settings.gd")
const Weather := preload("res://scripts/gt/gt_weather.gd")
const OUT := "res://executor-report/screenshots/phases/phase-21"
var world: Node3D
var camera: Camera3D
var shots: Array[Dictionary] = []
var failures: int = 0

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	root.size = Vector2i(1920, 1080)
	root.content_scale_size = Vector2i(1920, 1080)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
	Settings.set_quality(Settings.Quality.HIGH)
	var config := Config.get_config()
	config.selected_circuit_id = "stoke_crown"
	config.selected_team_id = 4
	config.total_laps = 3
	config.time_of_day = 0
	config.weather_preset = 0
	config.race_seed = 19220903
	world = WorldScene.instantiate()
	root.add_child(world)
	world.hud.visible = false
	_hide_canvases(world)
	world.process_mode = Node.PROCESS_MODE_DISABLED
	camera = Camera3D.new()
	camera.far = 5000.0
	root.add_child(camera)
	for i: int in range(30):
		await process_frame
	for mode: int in range(3):
		var folder := ["day", "sunset", "night"][mode] as String
		world.environment.apply_time_of_day(Weather.compute_time_of_day(mode, 0.0), 0.0)
		DirAccess.make_dir_recursive_absolute(OUT + "/" + folder)
		await _shot(folder + "/01_start_pit", _p(300.0, 0.0, 6.5), _p(0.0, 0.0, 5.0), 68.0)
		await _shot(folder + "/02_spitfire", _p(1385.0, 30.0, 13.0), _p(1450.0, -48.5, 5.0))
		await _shot(folder + "/03_luffield", _p(2265.0, 26.0, 13.0), _p(2150.0, -30.0, 11.0))
		await _shot(folder + "/04_pit_entry", _p(5130.0, -26.0, 22.0), _p(5010.0, 12.0, 3.0))
		await _shot(folder + "/05_horizon", Vector3(980.0, 290.0, 640.0), Vector3(0.0, 10.0, -60.0), 60.0)
		await _shot(folder + "/06_chase", _p(3040.0, 2.4, 3.3), _p(3150.0, 0.0, 1.1), 68.0)
		await _shot(folder + "/07_pit_lane", _p(225.0, 12.0, 4.0), _p(100.0, 18.0, 3.0))
		await _shot(folder + "/08_garage", _p(147.0, 12.0, 3.6), _p(130.0, 29.0, 3.2))
		await _shot(folder + "/09_flyover", _p(3585.0, 8.0, 8.0), _p(3650.0, 0.0, 9.0))
		await _shot(folder + "/10_hangar", _p(4190.0, -15.0, 15.0), _p(4250.0, 65.0, 12.0))
		await _shot(folder + "/11_pit_top", _p(120.0, 22.0, 145.0), _p(120.1, 22.0, 0.0))
	if OS.get_cmdline_user_args().has("--flythrough"):
		world.environment.apply_time_of_day(Weather.compute_time_of_day(0, 0.0))
		DirAccess.make_dir_recursive_absolute(OUT + "/flythrough")
		for station: int in range(0, 5200, 150):
			for direction: float in [-1.0, 1.0]:
				var label := "flythrough/s%04d_%s" % [station, "forward" if direction > 0.0 else "reverse"]
				await _shot(label, _p(float(station), 0.0, 3.0), _p(float(station) + direction * 60.0, 0.0, 1.0), 65.0)
	var stats: Dictionary = world.environment.stats()
	world.environment._measure_node(world.pit_lane)
	world.environment._measure_node(world.ribbon)
	var report := {"shots": shots, "failures": failures, "vram_mb": Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0, "environment_stats": stats, "complete_static_triangles": world.environment.triangle_count}
	var file := FileAccess.open(OUT + "/capture_metrics.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t"))
	file.close()
	world.free()
	camera.free()
	for i: int in range(10):
		await process_frame
	print("CAPTURE shots=%d failures=%d orphans=%d" % [shots.size(), failures, Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)])
	quit(1 if failures else 0)

func _shot(label: String, position: Vector3, target: Vector3, fov: float = 62.0) -> void:
	camera.fov = fov
	camera.look_at_from_position(position, target, Vector3.FORWARD if absf((target - position).normalized().dot(Vector3.UP)) > 0.99 else Vector3.UP)
	camera.make_current()
	for i: int in range(8):
		await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	if image.get_size() != Vector2i(1920, 1080):
		failures += 1
		push_error("Expected native 1920x1080: " + str(image.get_size()))
	image.save_png(OUT + "/" + label + ".png")
	var calls := int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	var static_calls: int = -1
	if not label.begins_with("flythrough/"):
		world.environment.visible = false
		world.pit_lane.visible = false
		world.ribbon.visible = false
		for i: int in range(12):
			await process_frame
		var without := int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
		world.environment.visible = true
		world.pit_lane.visible = true
		world.ribbon.visible = true
		for i: int in range(12):
			await process_frame
		static_calls = int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)) - without
	shots.append({"name": label, "size": [image.get_width(), image.get_height()], "frame_calls": calls, "complete_static_calls": static_calls})
	print("CAPTURE %s %s" % [label, image.get_size()])

func _p(s: float, lateral: float, height: float) -> Vector3:
	return world.ribbon.get_point_at_offset(s, lateral).origin + Vector3.UP * height

func _hide_canvases(node: Node) -> void:
	if node is CanvasLayer:
		(node as CanvasLayer).visible = false
	for child: Node in node.get_children():
		_hide_canvases(child)
