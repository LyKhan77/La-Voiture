extends SceneTree

## Showroom captures of the eight new GT3 chassis with the four master wheels:
## executor-report/phase-7-<slug>-showroom.png (3/4 front) and -left-side.png (flush stance).
## Run: Godot --rendering-driver d3d12 --resolution 1920x1080 --path . -s scratch/capture_multi_car.gd

const WHEEL := preload("res://scenes/car/parts/porsche_wheel_soft.tscn")
const CHASSIS_PATHS: Array[String] = [
	"res://scenes/car/nissan_gtr_chassis.tscn",
	"res://scenes/car/aston_vantage_chassis.tscn",
	"res://scenes/car/bmw_m4_chassis.tscn",
	"res://scenes/car/lambo_huracan_chassis.tscn",
	"res://scenes/car/honda_nsx_chassis.tscn",
	"res://scenes/car/chevy_corvette_chassis.tscn",
	"res://scenes/car/lexus_rcf_chassis.tscn",
	"res://scenes/car/mclaren_720s_chassis.tscn",
]


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.04, 0.045, 0.065)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.45, 0.48, 0.55)
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	root.add_child(world_env)

	var key := DirectionalLight3D.new()
	key.light_energy = 1.4
	key.light_color = Color(1, 0.98, 0.95)
	key.shadow_enabled = true
	root.add_child(key)
	key.look_at_from_position(Vector3(5, 8, 5), Vector3.ZERO)
	var rim := DirectionalLight3D.new()
	rim.light_energy = 0.8
	rim.light_color = Color(0, 0.94, 1)
	root.add_child(rim)
	rim.look_at_from_position(Vector3(-5, 3, -5), Vector3.ZERO)

	var floor_mesh := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(40, 40)
	floor_mesh.mesh = plane
	var floor_mat := StandardMaterial3D.new()
	floor_mat.albedo_color = Color(0.08, 0.09, 0.12)
	floor_mat.roughness = 0.9
	floor_mesh.material_override = floor_mat
	root.add_child(floor_mesh)

	var cam := Camera3D.new()
	root.add_child(cam)
	cam.current = true
	for path: String in CHASSIS_PATHS:
		var chassis: ModularCarAssembler = load(path).instantiate()
		root.add_child(chassis)
		await process_frame
		chassis.perform_pitstop_tire_change(WHEEL, ModularCarAssembler.TireCompound.SOFT)
		for i in 6:
			await process_frame
		var slug: String = path.get_file().get_basename().trim_suffix("_chassis")
		for view: String in ["showroom", "left_side"]:
			if view == "showroom":
				cam.fov = 38.0
				cam.look_at_from_position(Vector3(3.9, 1.25, 4.9), Vector3(0.0, 0.5, 0.2))
			else:
				cam.fov = 32.0
				cam.look_at_from_position(Vector3(-6.0, 0.8, 0.0), Vector3(0.0, 0.55, 0.0))
			for i in 5:
				await process_frame
			var img := root.get_viewport().get_texture().get_image()
			img.save_png(ProjectSettings.globalize_path("res://executor-report/phase-7-%s-%s.png" % [slug, view]))
			print("saved ", slug, " ", view, " ", img.get_size())
		chassis.queue_free()
		await process_frame
	quit(0)
