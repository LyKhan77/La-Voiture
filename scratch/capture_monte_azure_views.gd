extends SceneTree

## Native stills of Monte Azure Marina for the visual gates (needs a GPU):
##   godot --path . --resolution 1920x1080 --script res://scratch/capture_monte_azure_views.gd -- --out=temp/monte_shots --tod=0 --set=main
## --tod: 0 DAY, 1 SUNSET, 2 NIGHT. --set: main (the six gate cameras + an overview), pit (lane and paddock), fly (chase-height
## stills every 150 m in both directions). --out is a folder under the project; existing files are overwritten.

const WorldScene := preload("res://scenes/race_weekend_world.tscn")
const Config := preload("res://scripts/core/race_config_data.gd")
const Settings := preload("res://scripts/core/presentation_settings.gd")

var world: Node3D
var camera: Camera3D
var out_dir: String = "res://temp/monte_shots"
var failures: int = 0


func _initialize() -> void:
	call_deferred("_run")


func _arg(name: String, fallback: String) -> String:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--%s=" % name):
			return arg.substr(name.length() + 3)
	return fallback


func _run() -> void:
	var tod: int = int(_arg("tod", "0"))
	var set_name: String = _arg("set", "main")
	var dir: String = _arg("out", "temp/monte_shots")
	out_dir = "res://" + dir
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out_dir))
	DisplayServer.window_set_size(Vector2i(1920, 1080))
	root.size = Vector2i(1920, 1080)
	Settings.set_quality(Settings.Quality.HIGH)
	var config := Config.get_config()
	config.selected_circuit_id = "monte_azure"
	config.selected_team_id = 4
	config.total_laps = 3
	config.time_of_day = tod
	config.weather_preset = 0
	config.race_seed = 19220903
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
	world.environment.apply_time_of_day(_tod_dictionary(tod), 0.0)
	# --hide=Sea,Terrain hides named children of the environment, to look at one layer alone.
	for hidden: String in _arg("hide", "").split(",", false):
		var node := world.environment.get_node_or_null(hidden) as Node3D
		if node != null:
			node.visible = false
	var suffix: String = ["day", "sunset", "night"][tod]
	match set_name:
		"main":
			await _main_set(suffix)
		"pit":
			await _pit_set(suffix)
		"fly":
			await _fly_set(suffix)
	world.free()
	camera.free()
	quit(1 if failures else 0)


func _tod_dictionary(mode: int) -> Dictionary:
	return {"mode": mode, "floodlights": [0.0, 0.5, 1.0][mode], "stars_opacity": [0.0, 0.0, 1.0][mode]}


## [name, s, lateral, height, target s, target lateral, target height]
func _main_set(suffix: String) -> void:
	for shot: Array in [
		["cam1-start-pit", 2700.0, 0.0, 3.4, 2900.0, 8.0, 2.0],
		["cam2-casino-approach", 800.0, 0.0, 3.4, 930.0, 0.0, 6.0],
		["cam3-tunnel-mouth", 1190.0, 0.0, 3.4, 1330.0, 0.0, 4.0],
		["cam4-yachts-pit-entry", 2640.0, 0.0, 3.6, 2790.0, 8.0, 2.0],
		["cam6-chase", 2000.0, 0.0, 4.2, 2060.0, 0.0, 1.0],
	]:
		await _capture("%s-%s" % [shot[0], suffix], _look(shot))
	var centre := Vector3(150.0, 0.0, 300.0)
	await _capture("cam5-overview-%s" % suffix, Transform3D(Basis.looking_at(centre - Vector3(150.0, 1150.0, 1000.0), Vector3.UP), Vector3(150.0, 1150.0, 1000.0)))
	await _capture("cam5-horizon-%s" % suffix, Transform3D(Basis.looking_at(Vector3(150.0, 200.0, 300.0) - Vector3(-500.0, 120.0, -900.0), Vector3.UP), Vector3(-500.0, 120.0, -900.0)))


func _pit_set(suffix: String) -> void:
	for shot: Array in [
		["pit-entry", 2740.0, 8.0, 3.0, 2830.0, 10.0, 1.5],
		["pit-lane", 2850.0, 9.0, 3.0, 40.0, 10.5, 1.5],
		["pit-exit", 200.0, 8.0, 3.0, 290.0, 6.0, 1.0],
		["pit-aerial", 60.0, 40.0, 70.0, 100.0, 12.0, 0.0],
		["paddock-aerial", 100.0, -30.0, 90.0, 100.0, 30.0, 0.0],
		["grandstand", 2800.0, 25.0, 12.0, 40.0, -22.0, 8.0],
	]:
		await _capture("%s-%s" % [shot[0], suffix], _look(shot))


func _fly_set(suffix: String) -> void:
	var count: int = ceili(world.ribbon.length_m / 150.0)
	for direction: int in [1, -1]:
		for index: int in range(count):
			var s: float = float(index) * 150.0
			await _capture("fly-%s-%02d-%s" % ["fwd" if direction == 1 else "rev", index, suffix], _look(["", s, 0.0, 3.0, s + 60.0 * direction, 0.0, 1.0]))


func _look(shot: Array) -> Transform3D:
	var origin: Vector3 = world.ribbon.get_point_at_offset(float(shot[1]), float(shot[2])).origin + Vector3.UP * float(shot[3])
	var target: Vector3 = world.ribbon.get_point_at_offset(float(shot[4]), float(shot[5])).origin + Vector3.UP * float(shot[6])
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
