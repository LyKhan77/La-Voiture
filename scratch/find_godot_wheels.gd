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
	
	# Let's inspect vertices near the 4 wheel wells (Z around +1.2 and -1.2, Y around 0.35, X around +/- 0.94)
	# Check X min and max of wheel tubs:
	var fl_tub: Array[Vector3] = []
	var fr_tub: Array[Vector3] = []
	var rl_tub: Array[Vector3] = []
	var rr_tub: Array[Vector3] = []
	
	for v in verts:
		if v.z > 0.8 and v.z < 1.6 and v.y < 0.6:
			if v.x < -0.8:
				fl_tub.append(v)
			elif v.x > 0.8:
				fr_tub.append(v)
		elif v.z < -0.8 and v.z > -1.6 and v.y < 0.6:
			if v.x < -0.8:
				rl_tub.append(v)
			elif v.x > 0.8:
				rr_tub.append(v)
				
	func_print_avg("FL (-X, +Z)", fl_tub)
	func_print_avg("FR (+X, +Z)", fr_tub)
	func_print_avg("RL (-X, -Z)", rl_tub)
	func_print_avg("RR (+X, -Z)", rr_tub)
	quit(0)

func func_print_avg(name: String, arr: Array[Vector3]) -> void:
	if arr.is_empty():
		print("%s: EMPTY" % name)
		return
	var sum = Vector3.ZERO
	for v in arr:
		sum += v
	var avg = sum / float(arr.size())
	print("%s center: (%.3f, %.3f, %.3f) count: %d" % [name, avg.x, avg.y, avg.z, arr.size()])
