extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var glb: PackedScene = load("res://assets/cars/parts/gt3_wheel_master.glb")
	var inst = glb.instantiate()
	root.add_child(inst)
	print("--- INSPECTING GT3 WHEEL MASTER GLB IN GODOT ---")
	_print_tree(inst, "")
	quit(0)

func _print_tree(node: Node, indent: String) -> void:
	print("%s- %s (%s)" % [indent, node.name, node.get_class()])
	for child in node.get_children():
		_print_tree(child, indent + "  ")
