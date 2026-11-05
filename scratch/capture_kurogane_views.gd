extends SceneTree

## Native 6-camera production visual gate for Kurogane Twin-Cross GP (pit on the RIGHT).
##   godot --path . --resolution 1920x1080 -s res://scratch/capture_kurogane_views.gd -- --out=executor-report/screenshots/phases/phase-27-kurogane/day --tod=0 --set=main
## --tod: 0 DAY, 1 SUNSET, 2 NIGHT. --set: main (six gate cameras), pit (lane, garage, paddock, stands, tower).
## Requires a GPU (native renderer), not --headless.

const WorldScene := preload("res://scenes/race_weekend_world.tscn")
const Config := preload("res://scripts/core/race_config_data.gd")
const Settings := preload("res://scripts/core/presentation_settings.gd")

var world: Node3D
var camera: Camera3D
var out_dir: String = "res://temp/kurogane_shots"
var failures: int = 0
## Per shot: draw calls and primitives the renderer submitted for that camera (the 160 draw-call gate).
var shots: Dictionary = {}


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
	out_dir = "res://" + _arg("out", "temp/kurogane_shots")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out_dir))
	DisplayServer.window_set_size(Vector2i(1920, 1080))
	root.size = Vector2i(1920, 1080)
	Settings.set_quality(Settings.Quality.HIGH)
	var config := Config.get_config()
	config.selected_circuit_id = "kurogane"
	config.selected_team_id = 4
	config.total_laps = 3
	config.time_of_day = tod
	config.weather_preset = 0
	config.race_seed = 20261104
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
	if set_name == "boxes":
		await _boxes_set(suffix)
	elif set_name == "crossover":
		await _crossover_set(suffix)
	elif set_name == "landmarks":
		await _landmark_set(suffix)
	elif set_name == "explore":
		await _explore_set(suffix)
	elif set_name == "main":
		await _main_set(suffix)
	else:
		await _pit_set(suffix)
	var env: CircuitEnvironment = world.environment
	var metrics := {
		"set": set_name, "tod": tod, "failures": failures,
		"fps": Engine.get_frames_per_second(),
		"environment_stats": env.stats(),
		"shots": shots,
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


## [name, s, lateral, height, target s, target lateral, target height]; laterals are + right of travel.
func _main_set(suffix: String) -> void:
	for shot: Array in [
		["Gate_Cam_1_Start_Pit", 5775.0, 0.0, 22.0, 60.0, 12.0, 4.0],
		["Gate_Cam_2_S1_Ferris", 1400.0, 20.0, 14.0, 1480.0, -175.0, 30.0],
		["Gate_Cam_3_S2_Shrine", 3700.0, 12.0, 15.0, 3800.0, -120.0, 45.0],
		["Gate_Cam_4_S3_Tower", 4700.0, -12.0, 12.0, 4830.0, -62.0, 14.0],
		["Gate_Cam_6_Player_Chase", 3000.0, 2.4, 3.3, 3060.0, 0.0, 1.1],
	]:
		await _capture("%s-%s" % [shot[0], suffix], _look(shot))
	await _capture("Gate_Cam_5_Sky_Horizon-%s" % suffix, _from_to(Vector3(-260.0, 260.0, 1250.0), Vector3(-260.0, 20.0, 722.0)))


## The figure-8 crossover: lower road under the bridge, trench ends, deck, piers, side-slope.
func _crossover_set(suffix: String) -> void:
	var bridge: Node3D = world.environment.get_node("HeroLandmarks/CrossoverTrussBridge")
	var pier_a: Vector3 = bridge.global_transform * Vector3(0.0, -13.0, 26.0)
	var pier_b: Vector3 = bridge.global_transform * Vector3(0.0, -13.0, -26.0)
	for shot: Array in [
		["Crossover_Bridge", 2690.0, 0.0, 3.0, 2752.0, 0.0, 14.0],
		["Trench_Underpass", 2640.0, 0.0, 4.0, 2770.0, 0.0, 6.0],
		["Trench_Entrance", 2585.0, 0.0, 5.0, 2665.0, 0.0, 2.0],
		["Trench_Exit", 2830.0, 0.0, 4.0, 2900.0, 0.0, 3.0],
		["Bridge_Deck", 3840.0, 0.0, 3.2, 3960.0, 0.0, 2.0],
		["Bridge_Aerial", 3870.0, 70.0, 75.0, 3924.0, 0.0, 20.0],
		["Bridge_Side", 3924.0, 80.0, 16.0, 3924.0, 0.0, 22.0],
		["SideSlope_2940", 2900.0, 0.0, 3.0, 2960.0, 0.0, 1.0],
		["Abutment_Start", 3860.0, 14.0, 3.0, 3895.0, 4.0, 0.0],
		["Abutment_End", 3985.0, -14.0, 3.0, 3955.0, -4.0, 0.0],
	]:
		await _capture("%s-%s" % [shot[0], suffix], _look(shot))
	var lower: Vector3 = world.ribbon.get_point_at_offset(2735.0, 8.0).origin + Vector3.UP * 2.0
	await _capture("Pier_Close_A-%s" % suffix, _from_to(lower, pier_a))
	var lower_b: Vector3 = world.ribbon.get_point_at_offset(2770.0, -8.0).origin + Vector3.UP * 2.0
	await _capture("Pier_Close_B-%s" % suffix, _from_to(lower_b, pier_b))


## Landmark bases against the ground and the road, close and far.
func _landmark_set(suffix: String) -> void:
	for shot: Array in [
		["Ferris_Near", 1480.0, -80.0, 12.0, 1480.0, -175.0, 30.0],
		["Ferris_Base", 1440.0, -140.0, 4.0, 1480.0, -175.0, 8.0],
		["Tower_Near", 4830.0, -25.0, 6.0, 4830.0, -62.0, 12.0],
		["Tower_Base", 4800.0, -40.0, 3.0, 4830.0, -62.0, 4.0],
		["Shrine_Near", 3800.0, -62.0, 6.0, 3800.0, -120.0, 6.0],
		["Shrine_Base", 3770.0, -96.0, 2.5, 3800.0, -120.0, 3.0],
		["Esses_Chase", 1120.0, 2.4, 3.3, 1180.0, 0.0, 1.1],
		["Casio_Chase", 4740.0, 2.4, 3.3, 4800.0, 0.0, 1.1],
	]:
		await _capture("%s-%s" % [shot[0], suffix], _look(shot))


## Chase-height view every 200 m round the lap (obstruction sweep).
func _explore_set(suffix: String) -> void:
	var lap: float = world.ribbon.length_m
	var s := 0.0
	while s < lap:
		await _capture("Explore_%04d-%s" % [int(s), suffix], _look(["", s, 0.0, 3.5, s + 60.0, 0.0, 1.0]))
		s += 200.0


func _pit_set(suffix: String) -> void:
	for shot: Array in [
		["Pit_Entry", 5540.0, -4.0, 8.0, 5605.0, 12.0, 1.0],
		["Pit_Entry_Aerial", 5560.0, 30.0, 42.0, 5600.0, 8.0, 0.0],
		["Pit_Lane", 5705.0, 10.8, 3.0, 120.0, 10.8, 1.5],
		["Garage_Close", 107.0, 12.0, 2.2, 107.0, 22.0, 2.4],
		["Paddock_Aerial", 100.0, 45.0, 85.0, 100.0, 12.0, 0.0],
		["Paddock_Front", 60.0, -30.0, 20.0, 60.0, 35.0, 4.0],
		["Grandstand", 100.0, 25.0, 12.0, 100.0, -30.0, 8.0],
		["Race_Control", 60.0, 18.0, 10.0, 20.0, 32.0, 10.0],
		["Start_Gantry", 40.0, -4.0, 6.0, 0.0, 6.0, 6.0],
		["Pit_Exit", 150.0, 12.0, 4.0, 240.0, 4.0, 1.0],
		["Pit_Exit_Aerial", 185.0, 30.0, 42.0, 210.0, 4.0, 0.0],
	]:
		await _capture("%s-%s" % [shot[0], suffix], _look(shot))


func _look(shot: Array) -> Transform3D:
	var origin: Vector3 = world.ribbon.get_point_at_offset(fposmod(float(shot[1]), world.ribbon.length_m), float(shot[2])).origin + Vector3.UP * float(shot[3])
	var target: Vector3 = world.ribbon.get_point_at_offset(fposmod(float(shot[4]), world.ribbon.length_m), float(shot[5])).origin + Vector3.UP * float(shot[6])
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
	shots[name] = {
		"draw_calls": int(RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)),
		"primitives": int(RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME)),
	}
	# What the environment alone adds to this camera: the same frame with it hidden.
	var with_calls: int = int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	var with_tris: int = int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))
	world.environment.visible = false
	for _i: int in range(3):
		await process_frame
	shots[name]["environment_draw_calls"] = with_calls - int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	shots[name]["environment_primitives"] = with_tris - int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))
	world.environment.visible = true
	for _i: int in range(2):
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


## Painted pit boxes on the apron: top-down over the service bay, oblique along the row, near and far.
func _boxes_set(suffix: String) -> void:
	for shot: Array in [
		["Box_TopDown_Service", 107.0, 16.5, 14.0, 107.0, 16.5, 0.0],
		["Box_TopDown_Row", 100.0, 12.0, 40.0, 100.0, 17.0, 0.0],
		["Box_Oblique_Near", 60.0, 9.0, 3.0, 100.0, 17.0, 0.0],
		["Box_Oblique_Far", 5740.0, 9.0, 3.0, 100.0, 17.0, 0.0],
	]:
		await _capture("%s-%s" % [shot[0], suffix], _look(shot))
