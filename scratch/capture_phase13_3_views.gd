extends SceneTree

const WorldScene := preload("res://scenes/race_weekend_world.tscn")
const Config := preload("res://scripts/core/race_config_data.gd")
const Settings := preload("res://scripts/core/presentation_settings.gd")
const SHOTS := "res://executor-report/screenshots/phases/"

var world: Node3D
var camera: Camera3D
var failures: int = 0
var detail_only: bool = false

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	detail_only = OS.get_cmdline_user_args().has("--detail-only")
	DisplayServer.window_set_size(Vector2i(1920, 1080))
	root.size = Vector2i(1920, 1080)
	Settings.set_quality(Settings.Quality.HIGH)
	var config := Config.get_config()
	config.selected_circuit_id = "brianza"
	config.total_laps = 3
	config.time_of_day = 0
	config.weather_preset = 0
	config.race_seed = 19220903
	world = WorldScene.instantiate()
	root.add_child(world)
	world.hud.visible = false
	_hide_canvas_layers(world.hud)
	world.process_mode = Node.PROCESS_MODE_DISABLED
	camera = Camera3D.new()
	camera.far = 5000.0
	root.add_child(camera)
	for _i: int in range(20):
		await process_frame
	var count: int = ceili(world.ribbon.length_m / 150.0)
	for direction: int in ([] if detail_only else [1, -1]):
		var sheet := Image.create(320 * 8, 180 * ceili(float(count) / 8.0), false, Image.FORMAT_RGB8)
		for index: int in range(count):
			var s: float = float(index) * 150.0
			var image: Image = await _capture("fly-%s-%02d" % ["forward" if direction == 1 else "reverse", index], s, 0.0, 3.0, s + 60.0 * direction, 0.0, 1.0)
			if image != null:
				image.resize(320, 180, Image.INTERPOLATE_LANCZOS)
				sheet.blit_rect(image, Rect2i(0, 0, 320, 180), Vector2i((index % 8) * 320, int(index / 8) * 180))
		_save(sheet, "fly-%s-contact" % ("forward" if direction == 1 else "reverse"))
	for shot: Array in [
		["aerial-pit", 5660.0, -20.0, 85.0, 5680.0, 15.0, 0.0],
		["aerial-paddock", 5665.0, 125.0, 100.0, 5670.0, 50.0, 0.0],
		["pit-entry", 5500.0, 8.0, 4.0, 5580.0, 11.0, 1.5],
		["pit-exit", 80.0, 12.0, 4.0, 175.0, 6.0, 1.0],
		["pit-lane", 5570.0, 9.0, 3.0, 5640.0, 11.6, 1.0],
		["day", 5620.0, 12.0, 5.0, 5690.0, 20.0, 2.0],
	]:
		await _capture(shot[0], shot[1], shot[2], shot[3], shot[4], shot[5], shot[6])
	for mode: int in [1, 2]:
		world.environment.apply_time_of_day({"mode": mode, "floodlights": 0.5 if mode == 1 else 1.0, "stars_opacity": 0.0 if mode == 1 else 1.0})
		await _capture("sunset" if mode == 1 else "night", 5620.0, 12.0, 5.0, 5690.0, 20.0, 2.0)
	world.free()
	camera.free()
	quit(1 if failures else 0)

func _capture(name: String, s: float, lateral: float, height: float, target_s: float, target_lateral: float, target_height: float) -> Image:
	var origin: Vector3 = world.ribbon.get_point_at_offset(s, lateral).origin + Vector3.UP * height
	var target: Vector3 = world.ribbon.get_point_at_offset(target_s, target_lateral).origin + Vector3.UP * target_height
	camera.transform = Transform3D(Basis.looking_at(target - origin, Vector3.UP), origin)
	camera.fov = 65.0
	camera.make_current()
	for _i: int in range(3):
		await process_frame
	var image: Image = root.get_texture().get_image()
	_save(image, name)
	return image

func _save(image: Image, name: String) -> void:
	var path: String = SHOTS + ("phase-13-3-final5-" if detail_only else "phase-13-3-clear-") + name + ".png"
	if FileAccess.file_exists(path):
		push_error("Refusing to overwrite " + path)
		failures += 1
		return
	var error: Error = image.save_png(ProjectSettings.globalize_path(path))
	print("CAPTURE %s status=%d" % [path, error])
	if error != OK:
		failures += 1

func _hide_canvas_layers(node: Node) -> void:
	if node is CanvasLayer:
		node.visible = false
	for child: Node in node.get_children():
		_hide_canvas_layers(child)
