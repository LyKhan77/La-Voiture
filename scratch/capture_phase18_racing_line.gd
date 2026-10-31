extends SceneTree

## FASE 18 stills (needs a GPU): the rubber groove on the racing line through the two tightest corners of a circuit,
## from above (plan) and from a corner-worker's height, plus a 2D plot of the old and new line through those corners.
##   godot --path . --resolution 1920x1080 --script res://scratch/capture_phase18_racing_line.gd -- --circuit=brianza --out=executor-report/screenshots/phases/phase-18

const WorldScene := preload("res://scenes/race_weekend_world.tscn")
const Config := preload("res://scripts/core/race_config_data.gd")
const Settings := preload("res://scripts/core/presentation_settings.gd")

var world: Node3D
var camera: Camera3D
var out_dir: String = "res://executor-report/screenshots/phases/phase-18"
var failures: int = 0


func _initialize() -> void:
	call_deferred("_run")


func _arg(name: String, fallback: String) -> String:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--%s=" % name):
			return arg.substr(name.length() + 3)
	return fallback


func _run() -> void:
	var circuit: String = _arg("circuit", "apex_ring")
	out_dir = "res://" + _arg("out", "executor-report/screenshots/phases/phase-18")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out_dir))
	DisplayServer.window_set_size(Vector2i(1920, 1080))
	root.size = Vector2i(1920, 1080)
	Settings.set_quality(Settings.Quality.HIGH)
	var config := Config.get_config()
	config.selected_circuit_id = circuit
	config.selected_team_id = 4
	config.total_laps = 3
	config.time_of_day = 0
	config.weather_preset = 0
	config.race_seed = 18
	world = WorldScene.instantiate()
	root.add_child(world)
	world.hud.visible = false
	_hide_canvas_layers(world.hud)
	world.process_mode = Node.PROCESS_MODE_DISABLED
	camera = Camera3D.new()
	camera.far = 6000.0
	root.add_child(camera)
	for _i: int in range(30):
		await process_frame
	var line = world.track.line
	var corners: Array[float] = _tightest_corners(line, 2)
	for index: int in range(corners.size()):
		var apex: float = corners[index]
		var side: float = signf(line.line_curvature_at(apex))
		await _plan("%s-corner%d-plan" % [circuit, index + 1], apex, 0.0, 85.0)
		# Corner worker: on the outside, behind the entry, looking at the apex.
		var worker: Transform3D = _look([apex - 70.0, -side * (world.ribbon.road_half_width_m + 6.0), 7.0, apex + 10.0, line.target_offset(apex), 0.0])
		await _capture("%s-corner%d-worker" % [circuit, index + 1], worker)
		_plot("%s-corner%d-lines" % [circuit, index + 1], line, apex)
	world.free()
	camera.free()
	quit(1 if failures else 0)


## Apexes of the n tightest corners on the line, at least 300 m apart.
func _tightest_corners(line, n: int) -> Array[float]:
	var picks: Array[float] = []
	var length: float = world.ribbon.length_m
	for _pick: int in range(n):
		var best_s: float = -1.0
		var best: float = 0.0
		var s: float = 0.0
		while s < length:
			var k: float = absf(line.line_curvature_at(s))
			var clear: bool = true
			for taken: float in picks:
				clear = clear and absf(fposmod(s - taken + length * 0.5, length) - length * 0.5) > 300.0
			if clear and k > best:
				best = k
				best_s = s
			s += 2.0
		if best_s >= 0.0:
			picks.append(best_s)
	return picks


## Top-down plot (heading up) of the road edges, the centreline, the pre-FASE-18 line and the new line, 240 m around s.
func _plot(name: String, line, apex: float) -> void:
	var size := Vector2i(1200, 1200)
	var image := Image.create(size.x, size.y, false, Image.FORMAT_RGBA8)
	image.fill(Color("#f4f1ea"))
	var pose: Transform3D = world.ribbon.get_point_at_offset(apex, 0.0)
	var forward: Vector3 = -pose.basis.z
	var right: Vector3 = pose.basis.x
	var scale: float = float(size.x) / 260.0 # px per m
	var half: float = world.ribbon.road_half_width_m
	var to_px := func(p: Vector3) -> Vector2:
		var d: Vector3 = p - pose.origin
		return Vector2(size.x * 0.5 + d.dot(right) * scale, size.y * 0.5 - d.dot(forward) * scale)
	var s: float = apex - 140.0
	while s < apex + 140.0:
		for lateral: float in [-half, half]:
			_dot(image, to_px.call(world.ribbon.get_point_at_offset(s, lateral).origin), Color("#202020"), 2)
		_dot(image, to_px.call(world.ribbon.get_point_at_offset(s, 0.0).origin), Color("#9a9a9a"), 1)
		var old: float = clampf((0.4 * line.curvature_at(s) + 0.6 * line.curvature_at(s + 25.0)) * 180.0, -3.2, 3.2)
		_dot(image, to_px.call(world.ribbon.get_point_at_offset(s, old).origin), Color("#d23c3c"), 3)
		_dot(image, to_px.call(world.ribbon.get_point_at_offset(s, line.target_offset(s)).origin), Color("#1f6fd1"), 4)
		s += 0.5
	var path: String = "%s/%s.png" % [out_dir, name]
	var error: Error = image.save_png(ProjectSettings.globalize_path(path))
	print("CAPTURE %s status=%d (red = pre-FASE-18 line, blue = racing line, grey = centreline)" % [path, error])
	if error != OK:
		failures += 1


func _dot(image: Image, p: Vector2, color: Color, radius: int) -> void:
	for dx: int in range(-radius, radius + 1):
		for dy: int in range(-radius, radius + 1):
			var x: int = roundi(p.x) + dx
			var y: int = roundi(p.y) + dy
			if x >= 0 and y >= 0 and x < image.get_width() and y < image.get_height():
				image.set_pixel(x, y, color)


func _look(shot: Array) -> Transform3D:
	var origin: Vector3 = world.ribbon.get_point_at_offset(float(shot[0]), float(shot[1])).origin + Vector3.UP * float(shot[2])
	var target: Vector3 = world.ribbon.get_point_at_offset(float(shot[3]), float(shot[4])).origin + Vector3.UP * float(shot[5])
	return Transform3D(Basis.looking_at(target - origin, Vector3.UP), origin)


func _capture(name: String, pose: Transform3D) -> void:
	camera.transform = pose
	camera.fov = 65.0
	camera.make_current()
	for _i: int in range(4):
		await process_frame
	var image: Image = root.get_texture().get_image()
	var path: String = "%s/%s.png" % [out_dir, name]
	var error: Error = image.save_png(ProjectSettings.globalize_path(path))
	print("CAPTURE %s status=%d" % [path, error])
	if error != OK:
		failures += 1


func _hide_canvas_layers(node: Node) -> void:
	if node is CanvasLayer:
		node.visible = false
	for child: Node in node.get_children():
		_hide_canvas_layers(child)


## Straight down on a road station, the road's heading up the screen.
func _plan(name: String, s: float, lateral: float, height: float) -> void:
	var pose: Transform3D = world.ribbon.get_point_at_offset(s, lateral)
	var forward: Vector3 = -pose.basis.z
	var origin: Vector3 = pose.origin + Vector3.UP * height
	await _capture(name, Transform3D(Basis.looking_at(Vector3.DOWN, forward), origin))
