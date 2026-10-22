extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var glb: PackedScene = load("res://assets/cars/porsche_911/porsche_911_body.glb")
	var inst = glb.instantiate()
	root.add_child(inst)
	var mesh_inst: MeshInstance3D = inst.get_child(0) as MeshInstance3D
	print("Surfaces count:", mesh_inst.mesh.get_surface_count())
	for i in range(mesh_inst.mesh.get_surface_count()):
		var mat = mesh_inst.get_active_material(i)
		print("Surface %d mat: %s (Type: %s)" % [i, mat.resource_name if mat else "null", mat.get_class() if mat else "none"])
		if mat is BaseMaterial3D:
			var bmat: BaseMaterial3D = mat as BaseMaterial3D
			print("  Albedo texture:", bmat.albedo_texture.resource_path if bmat.albedo_texture else "null")
			print("  Albedo color:", bmat.albedo_color)
	quit(0)
