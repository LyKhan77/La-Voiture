extends SceneTree

## Loads the raw Meshy GLB at runtime (no import) and shows it under a sky env and under the dark showroom env.
## Run: Godot --rendering-driver d3d12 --resolution 1600x900 --path . -s scratch/audi/raw_in_godot.gd

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var doc := GLTFDocument.new()
	var state := GLTFState.new()
	var err := doc.append_from_file(ProjectSettings.globalize_path("res://assets/cars/audi_r8/raw/audi_r8_raw.glb"), state)
	print("append err ", err)
	var car: Node3D = doc.generate_scene(state)
	root.add_child(car)
	var mi: MeshInstance3D = car.find_children("*", "MeshInstance3D", true, false)[0]
	var mat := mi.mesh.surface_get_material(0) as BaseMaterial3D
	print("material ", mat, " albedo_tex ", mat.albedo_texture, " metallic ", mat.metallic, " roughness ", mat.roughness, " metallic_tex ", mat.metallic_texture, " normal ", mat.normal_texture)
	car.rotation.y = PI * 0.5     # raw front is -X: face the camera's +X side
	var sun := DirectionalLight3D.new()
	root.add_child(sun)
	sun.look_at_from_position(Vector3(3, 5, 4), Vector3.ZERO)
	var cam := Camera3D.new()
	root.add_child(cam)
	cam.current = true
	var env := Environment.new()
	var we := WorldEnvironment.new()
	we.environment = env
	root.add_child(we)
	var sky_mat := ProceduralSkyMaterial.new()
	var sky := Sky.new()
	sky.sky_material = sky_mat
	for variant in ["sky", "dark"]:
		if variant == "sky":
			env.background_mode = Environment.BG_SKY
			env.sky = sky
			env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
			env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
		else:
			env.background_mode = Environment.BG_COLOR
			env.background_color = Color(0.04, 0.045, 0.065)
			env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
			env.ambient_light_color = Color(0.45, 0.48, 0.55)
			env.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
		cam.fov = 40.0
		cam.look_at_from_position(Vector3(2.2, 1.2, 3.2), Vector3(0, 0.05, 0))
		for i in 6:
			await process_frame
		var img := root.get_viewport().get_texture().get_image()
		img.save_png(ProjectSettings.globalize_path("res://scratch/audi/views/raw_in_godot_%s.png" % variant))
		print("saved ", variant)
	quit(0)
