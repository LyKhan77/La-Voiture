extends SceneTree

## Close-up captures of the modular car wheels: <view_name>.png into res://scratch/wheel_views/
## Run: Godot --rendering-driver d3d12 -s scratch/capture_wheel_closeups.gd

const OUT_DIR := "res://scratch/wheel_views/"
# name: [camera position, look-at target]
const VIEWS := {
	"right_side": [Vector3(5.2, 0.9, 0.0), Vector3(0.0, 0.5, 0.0)],
	"fr_close": [Vector3(2.6, 0.6, 2.3), Vector3(0.9, 0.35, 1.25)],
	"rr_close": [Vector3(2.6, 0.6, -2.2), Vector3(0.9, 0.35, -1.18)],
	"left_side": [Vector3(-5.2, 0.9, 0.0), Vector3(0.0, 0.5, 0.0)],
	"fl_close": [Vector3(-2.6, 0.6, 2.3), Vector3(-0.9, 0.35, 1.25)],
}

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var scene: Node = load("res://scenes/test_modular_car.tscn").instantiate()
	root.add_child(scene)
	scene._auto_rotate = false
	var cam: Camera3D = scene.get_node("CameraPivot/Camera3D")
	cam.top_level = true
	cam.fov = 40.0
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	for i in range(6):
		await process_frame
	for view_name in VIEWS:
		var v: Array = VIEWS[view_name]
		cam.global_position = v[0]
		cam.look_at(v[1], Vector3.UP)
		for i in range(4):
			await process_frame
		var img := root.get_viewport().get_texture().get_image()
		img.save_png(ProjectSettings.globalize_path(OUT_DIR + view_name + ".png"))
		print("saved ", view_name)
	quit(0)
