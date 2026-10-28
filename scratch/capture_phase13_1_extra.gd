extends SceneTree

## FASE 13.1 supplementary 1080p gates for Autodromo di Brianza: unobstructed views of the landmarks the
## six-camera set only brushes past (cams 4 and 5 stand among the pines).
## Run: godot --path . --resolution 1920x1080 --script res://scratch/capture_phase13_1_extra.gd
##
## Corners follow the spline: Turn 1 at s~718, Ascari complex s 4087-4340.
## 1. Sopraelevata aerial        2. Rettifilo approach (brake gantries, red canopy stand)
## 3. Ascari stand + Jumbotron   4. Villa Reale gatehouse + main stand   5. Sunset over the Sopraelevata

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
	camera.far = 7000.0
	root.add_child(camera)

	await _load_world(0)
	await _view("phase-13-1-extra-sopraelevata-aerial", 3250.0, 70.0, 42.0, 3450.0, 0.0, 14.0, 68.0)
	await _view("phase-13-1-extra-rettifilo-gantries", 440.0, 0.0, 5.5, 690.0, 0.0, 5.0, 60.0)
	var ascari_side: float = float(world.get("environment").get_node("AscariGrandstand").get_meta("side"))
	await _view("phase-13-1-extra-ascari-stand", 4060.0, -ascari_side * 20.0, 22.0, 4213.0, ascari_side * 60.0, 9.0, 62.0)
	await _view("phase-13-1-extra-villa-gatehouse", 5420.0, 12.0, 14.0, 5600.0, -36.0, 6.0, 60.0)
	_unload_world()

	await _load_world(1)
	await _view("phase-13-1-extra-sunset-sopraelevata", 3250.0, 70.0, 42.0, 3450.0, 0.0, 14.0, 68.0)
	_unload_world()

	camera.queue_free()
	await process_frame
	print("ALL EXTRA GATES CAPTURED (%d failures)" % failures)
	quit(0 if failures == 0 else 1)


func _load_world(time_of_day: int) -> void:
	var config := Config.get_config()
	config.selected_circuit_id = "brianza"
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


func _view(label: String, cam_s: float, cam_lat: float, cam_y: float, look_s: float, look_lat: float, look_y: float, fov: float) -> void:
	var ribbon = world.get("ribbon")
	var cam_pos: Vector3 = ribbon.get_point_at_offset(cam_s, cam_lat).origin + Vector3.UP * cam_y
	var look_pos: Vector3 = ribbon.get_point_at_offset(look_s, look_lat).origin + Vector3.UP * look_y
	camera.fov = fov
	camera.transform = Transform3D(Basis.looking_at(look_pos - cam_pos, Vector3.UP), cam_pos)
	camera.make_current()
	for _i: int in range(6):
		await process_frame
	var img: Image = root.get_texture().get_image()
	var err: Error = img.save_png(ProjectSettings.globalize_path(SHOTS + label + ".png"))
	if err == OK:
		print("CAPTURED: %s" % label)
	else:
		failures += 1
		push_error("Failed to save " + label)
