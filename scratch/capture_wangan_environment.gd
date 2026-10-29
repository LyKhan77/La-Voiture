extends SceneTree

## Temp capture of the Neo-Wangan street circuit (needs a GPU, not --headless):
##   godot --path . --resolution 1600x900 --script res://temp/capture_wangan_env.gd

const CircuitScene := preload("res://scenes/race_world/circuits/neo_wangan/neo_wangan_circuit.tscn")

const VIEWS: Array[Dictionary] = [
	{"name": "start", "s": 3050.0, "lateral": -9.0, "height": 4.5, "look": 60.0, "look_lateral": 0.0, "look_height": 1.2},
	{"name": "bridge", "s": 330.0, "lateral": -12.0, "height": 6.0, "look": 80.0, "look_lateral": 0.0, "look_height": 2.0},
	{"name": "tunnel", "s": 1050.0, "lateral": 0.0, "height": 2.6, "look": 40.0, "look_lateral": 0.0, "look_height": 2.2},
	{"name": "harbor", "s": 1350.0, "lateral": -18.0, "height": 9.0, "look": 60.0, "look_lateral": 0.0, "look_height": 1.0},
	{"name": "skyline", "s": 2000.0, "lateral": 0.0, "height": 38.0, "look": 160.0, "look_lateral": 0.0, "look_height": 0.0},
]


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var circuit = CircuitScene.instantiate()
	root.add_child(circuit)
	var ribbon = circuit.ribbon
	var camera := Camera3D.new()
	camera.fov = 68.0
	camera.far = 4000.0
	root.add_child(camera)
	camera.current = true
	for view: Dictionary in VIEWS:
		var eye_pose: Transform3D = ribbon.get_point_at_offset(float(view["s"]), float(view["lateral"]))
		var at := eye_pose.origin + Vector3.UP * float(view["height"])
		var look_pose: Transform3D = ribbon.get_point_at_offset(float(view["s"]) + float(view["look"]), float(view["look_lateral"]))
		var target := look_pose.origin + Vector3.UP * float(view["look_height"])
		camera.global_position = at
		camera.look_at(target, Vector3.UP)
		for _i: int in range(6):
			await process_frame
		var image: Image = root.get_texture().get_image()
		var path: String = "res://executor-report/screenshots/phases/phase-12-neo-wangan-%s.png" % String(view["name"])
		print("saved ", path, " err=", image.save_png(path))
	circuit.queue_free()
	await process_frame
	quit(0)
