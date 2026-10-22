extends SceneTree

## Side-by-side of the shipped Audi body (left) and the retopo + bake experiment from temp/ (right), same camera and wheels.
## The experiment is loaded at runtime (GLTFDocument + Image.load_from_file), so nothing in res:// is imported or changed.
## Run: Godot --rendering-driver d3d12 --resolution 1920x1080 --path . -s scratch/compare_audi_retopo.gd -- <res:// dir> <glb> <colour png> <normal png> <out prefix>
## e.g. ... -- res://temp/audi_r8_retopo_v2/ audi_r8_body.glb base_color.png normal.png v2_

const CHASSIS := preload("res://scenes/car/audi_r8_chassis.tscn")
const WHEEL := preload("res://scenes/car/parts/porsche_wheel_soft.tscn")
# name: [camera position, look-at target, fov]
const VIEWS := {
	"3q": [Vector3(3.9, 1.25, 4.9), Vector3(0.0, 0.5, 0.2), 38.0],
	"left_side": [Vector3(-6.0, 0.8, 0.0), Vector3(0.0, 0.55, 0.0), 32.0],
	"rear": [Vector3(2.9, 1.5, -5.6), Vector3(0.0, 0.7, -0.9), 38.0],
	"front_right_close": [Vector3(3.0, 0.65, 2.9), Vector3(0.95, 0.45, 1.34), 40.0],
	"splitter": [Vector3(1.6, 0.35, 4.6), Vector3(0.0, 0.2, 2.2), 36.0],
	"arch_front_right": [Vector3(2.7, 0.55, 1.4), Vector3(1.0, 0.4, 1.34), 34.0],
	"arch_rear_left": [Vector3(-2.7, 0.55, -1.2), Vector3(-1.0, 0.4, -1.34), 34.0],
}

var DIR: String = ""
var OUT_PREFIX: String = ""

func _initialize() -> void:
	call_deferred("_run")

func _tex(file: String) -> ImageTexture:
	var img := Image.load_from_file(ProjectSettings.globalize_path(DIR + file))
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	DIR = args[0]
	var glb_name: String = args[1]
	var color_name: String = args[2]
	var normal_name: String = args[3]
	OUT_PREFIX = args[4]
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
	key.shadow_enabled = OS.get_environment("NOSHADOW").is_empty()
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

	var shipped: Node3D = chassis.get_node("BodyShell/AudiBody")
	var doc := GLTFDocument.new()
	var state := GLTFState.new()
	if doc.append_from_file(ProjectSettings.globalize_path(DIR + glb_name), state) != OK:
		push_error("cannot load the retopo glb")
		quit(1)
		return
	var retopo: Node3D = doc.generate_scene(state)
	chassis.get_node("BodyShell").add_child(retopo)
	var retopo_mesh: MeshInstance3D = retopo.find_children("*", "MeshInstance3D", true, false)[0]
	var paint := (load("res://materials/audi_r8_toon_body.tres") as ShaderMaterial).duplicate() as ShaderMaterial
	paint.set_shader_parameter("albedo_texture", _tex(color_name))
	paint.set_shader_parameter("normal_texture", _tex(normal_name))
	if args.size() > 5:
		paint.set_shader_parameter("orm_texture", _tex(args[5]))
	for param: String in ["ao_strength", "gloss_strength", "normal_strength", "spec_size", "spec_smoothness"]:
		var override_value := OS.get_environment("P_" + param)
		if not override_value.is_empty():
			paint.set_shader_parameter(param, float(override_value))
	retopo_mesh.set_surface_override_material(0, paint)
	retopo_mesh.set_surface_override_material(1, load("res://materials/toon_carbon_aero.tres"))
	for i in 8:
		await process_frame

	for view_name: String in VIEWS:
		var v: Array = VIEWS[view_name]
		cam.fov = v[2]
		cam.look_at_from_position(v[0], v[1])
		var shots: Array[Image] = []
		for variant in ["shipped", "retopo", "retopo_no_normal"]:
			shipped.visible = variant == "shipped"
			retopo.visible = variant != "shipped"
			paint.set_shader_parameter("use_normal_map", variant != "retopo_no_normal")
			for i in 5:
				await process_frame
			shots.append(root.get_viewport().get_texture().get_image())
		var size := shots[0].get_size()
		var combo := Image.create(size.x * 2, size.y, false, Image.FORMAT_RGB8)
		combo.blit_rect(shots[0], Rect2i(Vector2i.ZERO, size), Vector2i.ZERO)
		combo.blit_rect(shots[1], Rect2i(Vector2i.ZERO, size), Vector2i(size.x, 0))
		combo.save_png(ProjectSettings.globalize_path(DIR + "compare_" + OUT_PREFIX + "%s.png" % view_name))
		shots[2].save_png(ProjectSettings.globalize_path(DIR + "retopo_no_normal_" + OUT_PREFIX + "%s.png" % view_name))
		print("saved compare_", view_name)
	quit(0)
