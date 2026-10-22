extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	print("--- INSPECTING PORSCHE 911 GLB IN GODOT ---")
	var glb: PackedScene = load("res://assets/cars/porsche_911/porsche_911_body.glb")
	if not glb:
		print("FAILED to load GLB")
		quit(1)
		return
	var inst = glb.instantiate()
	root.add_child(inst)
	print("Instantiated GLB node:", inst.name, "Class:", inst.get_class())
	_print_tree(inst, "")
	quit(0)

func _print_tree(node: Node, indent: String) -> void:
	var info = "%s- %s (%s)" % [indent, node.name, node.get_class()]
	if node is VisualInstance3D:
		var aabb = (node as VisualInstance3D).get_aabb()
		info += " AABB: pos=%s, size=%s" % [aabb.position, aabb.size]
	print(info)
	for child in node.get_children():
		_print_tree(child, indent + "  ")
