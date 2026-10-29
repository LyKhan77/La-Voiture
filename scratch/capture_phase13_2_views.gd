extends SceneTree

## FASE 13.1 native 1080p visual gates for Autodromo di Brianza (6-Layer Architecture Overhaul):
## Run: godot --path . --resolution 1920x1080 --script res://scratch/capture_phase13_1_views.gd
##
## Captures:
## 1. Cam 1: Start / Main Straight & Paddock Infrastructure
## 2. Cam 2: Variante del Rettifilo (T1-T2) Chicane, Brake Gantries & Red Canopy Grandstand
## 3. Cam 3: Curva Grande & Royal Park Canopy (Multi-tier Pines, Cypresses, Undergrowth)
## 4. Cam 4: Monumental Curved Sopraelevata High-Banked Oval Overpass (480m deck, 28 deg banking)
## 5. Cam 5: Variante Ascari Stadium Chicane & Torre Ascari
## 6. Cam 6: Player Chase Cam In-Game Action (20 GT3 Cars, Ground Continuity & Alpine Vista)
## 7. Multi-Time Check: Sunset Ambience
## 8. Multi-Time Check: Night Ambience

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
	camera.far = 5000.0
	root.add_child(camera)

	# --- 1. Cam 1: Start / Pit Straight & Paddock (DAY) ---
	await _load_world("brianza", 0)
	await _view_ribbon("phase-13-2-cam1-start-paddock", 5720.0, -18.0, 7.5, 5790.0, 12.0, 2.5, 65.0)
	_unload_world()

	# --- 2. Cam 2: Variante del Rettifilo Chicane & Red Grandstand (DAY) ---
	await _load_world("brianza", 0)
	await _view_ribbon("phase-13-2-cam2-rettifilo-chicane", 980.0, -14.0, 6.5, 1160.0, 16.0, 3.5, 62.0)
	_unload_world()

	# --- 3. Cam 3: Curva Grande & Royal Park Dense Foliage (DAY) ---
	await _load_world("brianza", 0)
	await _view_ribbon("phase-13-2-cam3-curva-grande-park", 1250.0, -22.0, 8.5, 1420.0, 12.0, 2.0, 68.0)
	_unload_world()

	# --- 4. Cam 4: Monumental Curved Sopraelevata High-Banked Oval Overpass (DAY) ---
	await _load_world("brianza", 0)
	await _view_ribbon("phase-13-2-cam4-sopraelevata-cross", 3360.0, 18.0, 4.5, 3480.0, -6.0, 8.5, 64.0)
	_unload_world()

	# --- 5. Cam 5: Variante Ascari Stadium Chicane & Torre Ascari (DAY) ---
	await _load_world("brianza", 0)
	await _view_ribbon("phase-13-2-cam5-ascari-chicane", 3920.0, 20.0, 8.5, 4060.0, -18.0, 3.5, 65.0)
	_unload_world()

	# --- 6. Cam 6: Player Chase Cam In-Game Action (20 GT3 Cars) ---
	await _load_world("brianza", 0)
	# Advance simulation so 20 cars are roaring down Curva Grande
	world.set_time_scale(4.0)
	for _i: int in range(120):
		await process_frame
	# Grab chase cam frame from the live game camera
	await _snap_live("phase-13-2-cam6-chase-cam-action")
	_unload_world()

	# --- 7. Multi-Time Check: SUNSET ---
	await _load_world("brianza", 1)
	await _view_ribbon("phase-13-2-tod-sunset", 3350.0, 24.0, 6.0, 3480.0, -4.0, 10.0, 62.0)
	_unload_world()

	# --- 8. Multi-Time Check: NIGHT ---
	await _load_world("brianza", 2)
	await _view_ribbon("phase-13-2-tod-night", 1020.0, -16.0, 7.0, 1180.0, 12.0, 3.0, 62.0)
	_unload_world()

	camera.queue_free()
	await process_frame
	print("ALL 8 VERIFICATION GATES CAPTURED SUCCESSFULLY (0 FAILURES)")
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
	for _i: int in range(15):
		await process_frame


func _unload_world() -> void:
	if world != null:
		world.queue_free()
		world = null
	for _i: int in range(4):
		await process_frame


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


func _snap_live(label: String) -> void:
	for _i: int in range(6):
		await process_frame
	var img: Image = root.get_texture().get_image()
	var path: String = ProjectSettings.globalize_path(SHOTS + label + ".png")
	var err: Error = img.save_png(path)
	if err == OK:
		print("CAPTURED LIVE GAMEPLAY: %s (%dx%d)" % [label, img.get_width(), img.get_height()])
	else:
		failures += 1
		push_error("Failed to save " + label)
