extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var glb: PackedScene = load("res://assets/cars/porsche_911/porsche_911_body.glb")
	var inst = glb.instantiate()
	root.add_child(inst)
	var mesh_inst: MeshInstance3D = inst.get_child(0) as MeshInstance3D
	var mesh: Mesh = mesh_inst.mesh
	var arrays = mesh.surface_get_arrays(0)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	
	var front_verts: Array[Vector3] = []
	var rear_verts: Array[Vector3] = []
	for v in verts:
		if v.z > 2.1:
			front_verts.append(v)
		elif v.z < -2.1:
			rear_verts.append(v)
	
	print("Verts at Z > 2.1 (count %d):" % front_verts.size())
	for i in range(mini(3, front_verts.size())):
		print("  ", front_verts[i])
		
	print("Verts at Z < -2.1 (count %d):" % rear_verts.size())
	for i in range(mini(3, rear_verts.size())):
		print("  ", rear_verts[i])
		
	quit(0)
