extends SceneTree

const WorldScene := preload("res://scenes/race_weekend_world.tscn")
const Config := preload("res://scripts/core/race_config_data.gd")

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	DisplayServer.window_set_size(Vector2i(1920, 1080))
	root.size = Vector2i(1920, 1080)
	var config = Config.get_config()
	config.selected_circuit_id = "brianza"
	var world = WorldScene.instantiate()
	root.add_child(world)
	world.hud.visible = false
	var camera := Camera3D.new()
	camera.far = 5000.0
	root.add_child(camera)
	for _i: int in range(20):
		await process_frame
	for shot: Array in [
		["rettifilo", 730.0, 0.0, 8.0, 840.0, 0.0, 1.0],
		["back-straight", 4710.0, 0.0, 7.0, 4800.0, 0.0, 1.0],
		["pit-garages", 5610.0, 11.0, 9.0, 5660.0, 23.0, 2.0],
	]:
		var from: Vector3 = world.ribbon.get_point_at_offset(shot[1], shot[2]).origin + Vector3.UP * shot[3]
		var target: Vector3 = world.ribbon.get_point_at_offset(shot[4], shot[5]).origin + Vector3.UP * shot[6]
		camera.transform = Transform3D(Basis.looking_at(target - from, Vector3.UP), from)
		camera.make_current()
		for _i: int in range(8):
			await process_frame
		var path: String = "res://executor-report/screenshots/phases/phase-13-2-clearance-%s.png" % shot[0]
		if FileAccess.file_exists(path):
			push_error("Refusing to overwrite " + path)
			quit(1)
			return
		var result: Error = root.get_texture().get_image().save_png(ProjectSettings.globalize_path(path))
		print("CAPTURE %s status=%d" % [path, result])
		if result != OK:
			quit(1)
			return
	world.queue_free()
	camera.queue_free()
	quit(0)
