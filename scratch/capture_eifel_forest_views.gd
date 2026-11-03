extends SceneTree

## Native 6-camera production visual gate for Eifel Forest Ring.
##   godot --path . --resolution 1920x1080 -s res://scratch/capture_eifel_forest_views.gd -- --out=executor-report/screenshots/phases/phase-25-eifel-forest/day --tod=0 --set=main
## --tod: 0 DAY, 1 SUNSET, 2 NIGHT. --set: main (six gate cameras), pit (lane, garage, paddock, stands, tower).
## Requires a GPU (native renderer), not --headless.

const WorldScene := preload("res://scenes/race_weekend_world.tscn")
const Config := preload("res://scripts/core/race_config_data.gd")
const Settings := preload("res://scripts/core/presentation_settings.gd")

var world: Node3D
var camera: Camera3D
var out_dir: String = "res://temp/eifel_shots"
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
	out_dir = "res://" + _arg("out", "temp/eifel_shots")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out_dir))
	DisplayServer.window_set_size(Vector2i(1920, 1080))
	root.size = Vector2i(1920, 1080)
	Settings.set_quality(Settings.Quality.HIGH)
	var config := Config.get_config()
	config.selected_circuit_id = "eifel_forest"
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
	var suffix: String = ["day", "sunset", "night"][tod]
	if set_name == "main":
		await _main_set(suffix)
	else:
		await _pit_set(suffix)
	var env: CircuitEnvironment = world.environment
	var metrics := {
		"set": set_name, "tod": tod, "failures": failures,
		"fps": Engine.get_frames_per_second(),
		"environment_stats": env.stats(),
		"complete_static_triangles": _total_triangles(world),
		"orphans": Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT),
	}
	var file := FileAccess.open("%s/capture_metrics.json" % out_dir, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(metrics, "\t"))
		file.close()
	print("CAPTURE metrics %s" % str(metrics))
	world.free()
	camera.free()
	for _i: int in range(10):
		await process_frame
	print("CAPTURE orphans after free %d" % int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)))
	quit(1 if failures else 0)


func _total_triangles(root: Node) -> int:
	var total := 0
	if root is MeshInstance3D and (root as MeshInstance3D).mesh != null:
		total += _mesh_triangles((root as MeshInstance3D).mesh)
	elif root is MultiMeshInstance3D and (root as MultiMeshInstance3D).multimesh != null:
		var mm := (root as MultiMeshInstance3D).multimesh
		total += _mesh_triangles(mm.mesh) * mm.instance_count
	for child: Node in root.get_children():
		total += _total_triangles(child)
	return total


func _mesh_triangles(mesh: Mesh) -> int:
	var total := 0
	if mesh == null:
		return 0
	for surface in mesh.get_surface_count():
		var arrays := mesh.surface_get_arrays(surface)
		var indices: Variant = arrays[Mesh.ARRAY_INDEX]
		total += (indices.size() if indices != null else (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()) / 3
	return total


func _tod_dictionary(mode: int) -> Dictionary:
	return {"mode": mode, "floodlights": [0.0, 0.5, 1.0][mode], "stars_opacity": [0.0, 0.0, 1.0][mode]}


## [name, s, lateral, height, target s, target lateral, target height]
func _main_set(suffix: String) -> void:
	for shot: Array in [
		["Gate_Cam_1_Start_Pit", 430.0, 0.0, 22.0, 0.0, 0.0, 4.0],
		["Gate_Cam_2_S1_Archway", 300.0, -20.0, 10.0, 350.0, 45.0, 6.0],
		["Gate_Cam_3_S2_Arena", 760.0, 30.0, 18.0, 850.0, -35.0, 10.0],
		["Gate_Cam_4_S3_Castle", 2850.0, 40.0, 30.0, 2750.0, -120.0, 45.0],
		["Gate_Cam_6_Player_Chase", 3500.0, 2.4, 3.3, 3560.0, 0.0, 1.1],
	]:
		await _capture("%s-%s" % [shot[0], suffix], _look(shot))
	await _capture("Gate_Cam_5_Flyover-%s" % suffix, _from_to(
		world.ribbon.get_point_at_offset(1490.0, 30.0).origin + Vector3.UP * 8.0,
		world.ribbon.get_point_at_offset(1580.0, 0.0).origin + Vector3.UP * 7.0))
	await _capture("Gate_Cam_5_Sky_Horizon-%s" % suffix, _from_to(Vector3(1050.0, 335.0, -520.0), Vector3(-480.0, 40.0, 520.0)))


func _pit_set(suffix: String) -> void:
	for shot: Array in [
		["Pit_Entry", 4900.0, -4.0, 8.0, 4955.0, 12.0, 1.0],
		["Pit_Entry_Aerial", 4920.0, 30.0, 42.0, 4930.0, 8.0, 0.0],
		["Pit_Lane", 4985.0, 10.8, 3.0, 50.0, 10.8, 1.5],
		["Garage_Close", 120.0, 12.0, 2.2, 120.0, 22.0, 2.4],
		["Paddock_Aerial", 10.0, 45.0, 75.0, 10.0, 12.0, 0.0],
		["Paddock_Front", 10.0, -30.0, 20.0, 10.0, 35.0, 4.0],
		["Grandstand", 90.0, 25.0, 12.0, 90.0, -25.0, 8.0],
		["Race_Control", 60.0, 18.0, 10.0, 25.0, 32.0, 10.0],
	]:
		await _capture("%s-%s" % [shot[0], suffix], _look(shot))
	await _capture("Pit_Exit-%s" % suffix, _look(["", 200.0, 12.0, 4.0, 290.0, 4.0, 1.0]))
	await _capture("Pit_Exit_Aerial-%s" % suffix, _look(["", 235.0, 30.0, 42.0, 208.0, 4.0, 0.0]))


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
	await RenderingServer.frame_post_draw
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
