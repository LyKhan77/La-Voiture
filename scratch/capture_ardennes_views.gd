extends SceneTree

## Native stills of Ardennes Valley Ring for the visual gates (needs a GPU):
##   godot --path . --resolution 1920x1080 --script res://scratch/capture_ardennes_views.gd -- --out=temp/ardennes_shots --tod=0 --set=main
## --tod: 0 DAY, 1 SUNSET, 2 NIGHT. --set: main (the six gate cameras + an overview), pit (lane, paddock, garages, stands, tower),
## fly (chase-height stills every 150 m in both directions), tunnel (both mouths and the bore), flyover, pitjoin (where the lane
## leaves and rejoins the road). --out is a folder under the project; existing files are overwritten.

const WorldScene := preload("res://scenes/race_weekend_world.tscn")
const Config := preload("res://scripts/core/race_config_data.gd")
const Settings := preload("res://scripts/core/presentation_settings.gd")

var world: Node3D
var camera: Camera3D
var out_dir: String = "res://temp/ardennes_shots"
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
	out_dir = "res://" + _arg("out", "temp/ardennes_shots")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out_dir))
	DisplayServer.window_set_size(Vector2i(1920, 1080))
	root.size = Vector2i(1920, 1080)
	Settings.set_quality(Settings.Quality.HIGH)
	var config := Config.get_config()
	config.selected_circuit_id = "ardennes"
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
	# --hide=Foliage,Terrain hides named children of the environment, to look at one layer alone.
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
		"tunnel":
			await _tunnel_set(suffix)
		"flyover":
			await _flyover_set(suffix)
		"pitjoin":
			await _pit_join_set(suffix)
	world.free()
	camera.free()
	quit(1 if failures else 0)


func _tod_dictionary(mode: int) -> Dictionary:
	return {"mode": mode, "floodlights": [0.0, 0.5, 1.0][mode], "stars_opacity": [0.0, 0.0, 1.0][mode]}


## [name, s, lateral, height, target s, target lateral, target height]
func _main_set(suffix: String) -> void:
	for shot: Array in [
		["cam1-start-pit", 5100.0, 0.0, 3.4, 60.0, 9.0, 2.5],
		["cam2-viaduct", 540.0, -22.0, 14.0, 680.0, -105.0, 24.0],
		["cam3-tunnel", 2575.0, 0.0, 3.4, 2700.0, 0.0, 5.0],
		["cam4-pit-entry-glass", 5060.0, 0.0, 3.6, 5260.0, -12.0, 7.0],
		["cam6-chase", 1560.0, 0.0, 4.2, 1620.0, 0.0, 1.5],
	]:
		await _capture("%s-%s" % [shot[0], suffix], _look(shot))
	await _capture("cam5-overview-%s" % suffix, _from_to(Vector3(170.0, 1700.0, -900.0), Vector3(170.0, 60.0, 900.0)))
	await _capture("cam5-horizon-%s" % suffix, _from_to(Vector3(-650.0, 210.0, -250.0), Vector3(170.0, 90.0, 925.0)))


func _pit_set(suffix: String) -> void:
	for shot: Array in [
		["pit-entry", 5120.0, 8.0, 3.0, 5300.0, 10.8, 1.5],
		["pit-lane", 5330.0, 9.0, 3.0, 60.0, 10.8, 1.5],
		["pit-exit", 150.0, 8.0, 3.0, 330.0, 6.0, 1.0],
		["pit-aerial", 10.0, 45.0, 75.0, 10.0, 12.0, 0.0],
		["paddock-aerial", 10.0, -30.0, 95.0, 10.0, 35.0, 0.0],
		["garage-close", 10.0, 15.0, 2.0, 10.0, 24.0, 2.5],
		["grandstand", 5200.0, 25.0, 12.0, 125.0, -22.0, 8.0],
		["race-control", 60.0, 18.0, 10.0, 150.0, 32.0, 10.0],
	]:
		await _capture("%s-%s" % [shot[0], suffix], _look(shot))
	await _plan("plan-paddock-%s" % suffix, 10.0, 30.0, 190.0)


## Both tunnel mouths from outside, from the side, and from inside looking out.
func _tunnel_set(suffix: String) -> void:
	for shot: Array in [
		["tunnel-in-near", 2640.0, 0.0, 2.0, 2740.0, 0.0, 3.5],
		["tunnel-in-side", 2630.0, 22.0, 5.0, 2700.0, -2.0, 4.0],
		["tunnel-out-near", 2870.0, 0.0, 2.0, 2790.0, 0.0, 3.5],
		["tunnel-out-side", 2880.0, -22.0, 5.0, 2800.0, 2.0, 4.0],
		["tunnel-inside-out", 2700.0, 0.0, 1.6, 2830.0, 0.0, 3.5],
		["tunnel-inside-in", 2800.0, 0.0, 1.6, 2680.0, 0.0, 3.5],
	]:
		await _capture("%s-%s" % [shot[0], suffix], _look(shot))


func _flyover_set(suffix: String) -> void:
	for shot: Array in [
		["flyover-approach", 1330.0, 0.0, 2.4, 1400.0, 0.0, 9.0],
		["flyover-side", 1400.0, 30.0, 6.0, 1400.0, -10.0, 8.0],
		["flyover-under", 1385.0, 0.0, 1.8, 1420.0, 0.0, 9.0],
	]:
		await _capture("%s-%s" % [shot[0], suffix], _look(shot))


## Where the pit lane leaves and rejoins the track: entry from the track (behind and beside), exit from the lane and from above.
func _pit_join_set(suffix: String) -> void:
	for shot: Array in [
		["join-entry-approach", 5120.0, 0.0, 3.2, 5240.0, 6.0, 1.0],
		["join-entry-top", 5180.0, 14.0, 45.0, 5240.0, 6.0, 0.0],
		["join-entry-lane", 5215.0, 5.0, 2.2, 5320.0, 10.8, 1.0],
		["join-exit-lane", 190.0, 10.0, 2.2, 330.0, 5.0, 1.0],
		["join-exit-top", 270.0, 14.0, 45.0, 300.0, 5.0, 0.0],
		["join-exit-track", 230.0, 0.0, 3.2, 340.0, 0.0, 1.0],
	]:
		await _capture("%s-%s" % [shot[0], suffix], _look(shot))
	await _plan("plan-entry-%s" % suffix, 5240.0, 8.0, 90.0)
	await _plan("plan-exit-%s" % suffix, 290.0, 8.0, 90.0)


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


func _from_to(origin: Vector3, target: Vector3) -> Transform3D:
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


## Straight down on a road station, the road's heading up the screen, to read a layout as a plan.
func _plan(name: String, s: float, lateral: float, height: float) -> void:
	var pose: Transform3D = world.ribbon.get_point_at_offset(s, lateral)
	var forward: Vector3 = -pose.basis.z
	var origin: Vector3 = pose.origin + Vector3.UP * height
	await _capture(name, Transform3D(Basis.looking_at(Vector3.DOWN, forward), origin))
