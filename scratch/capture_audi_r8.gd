extends SceneTree

## Showroom captures of the Audi R8 chassis with the four master wheels: res://scratch/audi_r8_*.png
## Run: Godot --rendering-driver d3d12 --resolution 1920x1080 --path . -s scratch/capture_audi_r8.gd

const CHASSIS := preload("res://scenes/car/audi_r8_chassis.tscn")
const WHEEL := preload("res://scenes/car/parts/porsche_wheel_soft.tscn")
const OUT := "res://scratch/"
# file name: [camera position, look-at target, fov]
const VIEWS := {
	"audi_r8_showroom": [Vector3(3.9, 1.25, 4.9), Vector3(0.0, 0.5, 0.2), 38.0],       # front 3/4: grille, lights, rims, calipers
	"audi_r8_left_side": [Vector3(-6.0, 0.8, 0.0), Vector3(0.0, 0.55, 0.0), 32.0],     # flush stance
	"audi_r8_rear": [Vector3(2.9, 1.5, -5.6), Vector3(0.0, 0.7, -0.9), 38.0],          # diffuser + wing
	"audi_r8_fl_close": [Vector3(-3.0, 0.65, 2.9), Vector3(-0.95, 0.35, 1.34), 40.0],
	"audi_r8_fr_close": [Vector3(3.0, 0.65, 2.9), Vector3(0.95, 0.35, 1.34), 40.0],
	"audi_r8_rl_close": [Vector3(-3.0, 0.65, -2.9), Vector3(-0.95, 0.35, -1.34), 40.0],
	"audi_r8_rr_close": [Vector3(3.0, 0.65, -2.9), Vector3(0.95, 0.35, -1.34), 40.0],
}

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

	var chassis: ModularCarAssembler = CHASSIS.instantiate()
	root.add_child(chassis)
	var cam := Camera3D.new()
	root.add_child(cam)
	cam.current = true
	await process_frame
	chassis.perform_pitstop_tire_change(WHEEL, ModularCarAssembler.TireCompound.SOFT)
	# debug overrides: AUDI_NS = normal_strength, AUDI_ONLY = one view, AUDI_SUFFIX = file name suffix
	var ns := OS.get_environment("AUDI_NS")
	if not ns.is_empty():
		var paint := chassis.base_body_mesh.get_surface_override_material(0).duplicate() as ShaderMaterial
		paint.set_shader_parameter("normal_strength", float(ns))
		paint.set_shader_parameter("use_normal_map", float(ns) > 0.0)
		chassis.base_body_mesh.set_surface_override_material(0, paint)
	var ow := OS.get_environment("AUDI_OUTLINE")   # outline width override; 0 removes the pass
	if not ow.is_empty():
		var paint2 := chassis.base_body_mesh.get_surface_override_material(0).duplicate() as ShaderMaterial
		if float(ow) <= 0.0:
			paint2.next_pass = null
		else:
			var hull := paint2.next_pass.duplicate() as ShaderMaterial
			hull.set_shader_parameter("outline_width", float(ow))
			paint2.next_pass = hull
		chassis.base_body_mesh.set_surface_override_material(0, paint2)
	for i in 8:
		await process_frame
	for view_name: String in VIEWS:
		if not OS.get_environment("AUDI_ONLY").is_empty() and view_name != OS.get_environment("AUDI_ONLY"):
			continue
		var v: Array = VIEWS[view_name]
		cam.fov = v[2]
		cam.look_at_from_position(v[0], v[1])
		for i in 5:
			await process_frame
		var img := root.get_viewport().get_texture().get_image()
		img.save_png(ProjectSettings.globalize_path(OUT + view_name + OS.get_environment("AUDI_SUFFIX") + ".png"))
		print("saved ", view_name, " ", img.get_size())
	quit(0)
