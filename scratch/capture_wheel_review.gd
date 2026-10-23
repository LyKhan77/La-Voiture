extends SceneTree

## Wheel-fit review renders: for every refine_car.py car, close-ups of the front-right and rear-right wheel from the side and from above,
## plus the full side view, as res://temp/wheel_review/<car>_<view>.png. A gate only measures what exists: a missing fender is caught by
## fit_cars.gd's skin metric and by looking at these images. Look at the "high" views, not only the side.
## Run: Godot --rendering-driver d3d12 --resolution 1280x800 --path . -s scratch/capture_wheel_review.gd [-- <car> ...]

const OUT := "res://temp/wheel_review/"
const WHEEL := preload("res://scenes/car/parts/porsche_wheel_soft.tscn")
const CARS := ["nissan_gtr", "aston_vantage", "bmw_m4", "lambo_huracan", "honda_nsx", "chevy_corvette", "lexus_rcf", "mclaren_720s", "mercedes_amg"]


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.04, 0.045, 0.065)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.55, 0.58, 0.65)
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	root.add_child(world_env)
	var key := DirectionalLight3D.new()
	key.light_energy = 1.3
	key.shadow_enabled = true
	root.add_child(key)
	key.look_at_from_position(Vector3(5, 8, 5), Vector3.ZERO)
	var floor_mesh := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(40, 40)
	floor_mesh.mesh = plane
	root.add_child(floor_mesh)
	var cam := Camera3D.new()
	root.add_child(cam)
	cam.current = true
	var only: PackedStringArray = OS.get_cmdline_user_args()
	for car: String in CARS:
		if not only.is_empty() and car not in only:
			continue
		var chassis: ModularCarAssembler = (load("res://scenes/car/%s_chassis.tscn" % car) as PackedScene).instantiate()
		root.add_child(chassis)
		await process_frame
		chassis.perform_pitstop_tire_change(WHEEL, ModularCarAssembler.TireCompound.SOFT)
		for i in 6:
			await process_frame
		var f: Vector3 = chassis.socket_wheel_fr.position
		var r: Vector3 = chassis.socket_wheel_rr.position
		var views := {
			"fr_side": [Vector3(3.4, f.y + 0.15, f.z), Vector3(f.x, f.y + 0.1, f.z)],
			"fr_high": [Vector3(2.2, 1.7, f.z + 0.6), Vector3(f.x, f.y + 0.3, f.z)],
			"rr_side": [Vector3(3.4, r.y + 0.15, r.z), Vector3(r.x, r.y + 0.1, r.z)],
			"rr_high": [Vector3(2.2, 1.7, r.z - 0.6), Vector3(r.x, r.y + 0.3, r.z)],
			"side": [Vector3(6.0, 0.8, 0.0), Vector3(0.0, 0.55, 0.0)],
		}
		for view: String in views:
			cam.fov = 30.0 if view == "side" else 35.0
			cam.look_at_from_position(views[view][0], views[view][1])
			for i in 5:
				await process_frame
			root.get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path(OUT + "%s_%s.png" % [car, view]))
		print("saved ", car)
		chassis.queue_free()
		await process_frame
	quit(0)
