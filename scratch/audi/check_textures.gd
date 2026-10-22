extends SceneTree
func _initialize() -> void:
	for path in ["res://assets/cars/audi_r8/audi_r8_body.glb", "res://assets/cars/audi_r8/audi_r8_full.glb", "res://assets/cars/audi_r8/raw/audi_r8_raw.glb"]:
		var scene := (load(path) as PackedScene).instantiate()
		for m: MeshInstance3D in scene.find_children("*", "MeshInstance3D", true, false):
			var mat := m.mesh.surface_get_material(0) as BaseMaterial3D
			if mat != null and mat.albedo_texture != null:
				print("TEXCHECK ", path.get_file(), " surface0 albedo ", mat.albedo_texture.get_size(), " normal ", mat.normal_texture != null)
				break
		scene.free()
	quit(0)
