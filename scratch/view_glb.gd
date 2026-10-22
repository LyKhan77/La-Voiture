extends SceneTree

## Loads any GLB at runtime (no import needed) and shoots it under a sky environment, from several sides.
## Run: Godot --rendering-driver d3d12 --resolution 1600x900 --path . -s scratch/view_glb.gd -- <glb path> <out prefix>

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var doc := GLTFDocument.new()
	var state := GLTFState.new()
	if doc.append_from_file(ProjectSettings.globalize_path(args[0]), state) != OK:
		push_error("cannot load " + args[0])
		quit(1)
		return
	var car: Node3D = doc.generate_scene(state)
	root.add_child(car)
	var sun := DirectionalLight3D.new()
	root.add_child(sun)
	sun.look_at_from_position(Vector3(3, 5, 4), Vector3.ZERO)
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = Sky.new()
	env.sky.sky_material = ProceduralSkyMaterial.new()
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	var we := WorldEnvironment.new()
	we.environment = env
	root.add_child(we)
	var floor_mesh := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(30, 30)
	floor_mesh.mesh = plane
	root.add_child(floor_mesh)
	var cam := Camera3D.new()
	root.add_child(cam)
	cam.current = true
	cam.fov = 38.0
	var views := {"3q": Vector3(3.6, 1.4, 4.6), "side": Vector3(6.0, 0.7, 0.0), "rear": Vector3(-3.2, 1.5, -5.0)}
	for view_name: String in views:
		cam.look_at_from_position(views[view_name], Vector3(0, 0.55, 0))
		for i in 6:
			await process_frame
		root.get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path("%s_%s.png" % [args[1], view_name]))
		print("saved ", view_name)
	quit(0)
