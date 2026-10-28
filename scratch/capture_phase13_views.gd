extends SceneTree

## FASE 13 native 1080p visual gates for Autodromo di Brianza:
##   godot --path . --resolution 1920x1080 --script res://scratch/capture_phase13_views.gd
## Captures Paddock, Curva Grande, Sopraelevata Overpass, and Parabolica across DAY, SUNSET, and NIGHT.

const WorldScene := preload("res://scenes/race_weekend_world.tscn")
const Config := preload("res://scripts/core/race_config_data.gd")
const Settings := preload("res://scripts/core/presentation_settings.gd")
const SHOTS := "res://executor-report/screenshots/phases/"

var world: Node3D
var camera: Camera3D
var failures: int = 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	DisplayServer.window_set_size(Vector2i(1920, 1080))
	root.size = Vector2i(1920, 1080)
	Settings.set_quality(Settings.Quality.HIGH)
	camera = Camera3D.new()
	camera.far = 4500.0
	root.add_child(camera)

	# Shot 1: DAY — Main Straight & Paddock Infrastructure
	await _load_world("brianza", 0)
	await _view_ribbon("phase-13-brianza-day-paddock", 5720.0, -18.0, 7.5, 5780.0, 12.0, 2.5, 65.0)
	_unload_world()

	# Shot 2: DAY — Curva Biassono (Curva Grande) & Royal Pine Canopy
	await _load_world("brianza", 0)
	await _view_ribbon("phase-13-brianza-curva-grande", 1120.0, -22.0, 12.0, 1380.0, 5.0, 2.0, 68.0)
	_unload_world()

	# Shot 3: SUNSET — Historic Sopraelevata Banked Oval Viaduct Overpass
	await _load_world("brianza", 1)
	await _view_ribbon("phase-13-brianza-sunset-sopraelevata", 3360.0, 18.0, 4.5, 3450.0, -2.0, 8.5, 62.0)
	_unload_world()

	# Shot 4: NIGHT — Curva Parabolica & Pit Entry
	await _load_world("brianza", 2)
	await _view_ribbon("phase-13-brianza-night-parabolica", 5220.0, -24.0, 8.0, 5380.0, 6.0, 1.5, 68.0)
	_unload_world()

	camera.queue_free()
	await process_frame
	quit(0 if failures == 0 else 1)


func _load_world(circuit_id: String, time_of_day: int) -> void:
	var config := Config.get_config()
	config.selected_circuit_id = circuit_id
	config.total_laps = 5
	config.time_of_day = time_of_day
	config.weather_preset = 0
	config.race_seed = 19220903
	world = WorldScene.instantiate()
	root.add_child(world)
	# Wait several frames for tree and mesh batches to settle
	for _i: int in range(12):
		await process_frame


func _unload_world() -> void:
	if world != null:
		world.queue_free()
		world = null


func _view_ribbon(label: String, cam_s: float, cam_lat: float, cam_y: float, look_s: float, look_lat: float, look_y: float, fov: float) -> void:
	var ribbon = world.get("ribbon")
	if ribbon == null:
		failures += 1
		return
	var cam_pose: Transform3D = ribbon.get_point_at_offset(cam_s, cam_lat)
	var cam_pos: Vector3 = cam_pose.origin + Vector3.UP * cam_y
	var look_pose: Transform3D = ribbon.get_point_at_offset(look_s, look_lat)
	var look_pos: Vector3 = look_pose.origin + Vector3.UP * look_y
	
	camera.fov = fov
	camera.transform = Transform3D(Basis.looking_at(look_pos - cam_pos, Vector3.UP), cam_pos)
	camera.make_current()
	
	for _i: int in range(6):
		await process_frame
		
	var img: Image = root.get_texture().get_image()
	var path: String = ProjectSettings.globalize_path(SHOTS + label + ".png")
	var err: Error = img.save_png(path)
	if err == OK:
		print("CAPTURED: %s (%dx%d)" % [label, img.get_width(), img.get_height()])
	else:
		failures += 1
		push_error("Failed to save " + label)
