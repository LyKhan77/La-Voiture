extends SceneTree

## Static render budget of the Brianza environment (what earlier phases quote as "draw calls / triangles"):
## one draw call per surface of every visible MeshInstance3D and MultiMeshInstance3D (one per surface, however many
## instances), triangles = surface triangles x instances; shadow passes and outline next-passes not counted.
## Run: godot --headless --path . -s res://scratch/measure_brianza_budget.gd

func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var inst: Node3D = (load("res://scenes/race_world/circuits/brianza/brianza_circuit.tscn") as PackedScene).instantiate()
	root.add_child(inst)
	await process_frame
	var env: Node = inst.get_node("Environment")
	var calls: int = 0
	var tris: int = 0
	var rows: Array[String] = []
	_count(env, 1, rows)
	for r: String in rows:
		print(r)
	var total := _totals(env)
	print("BUDGET draw_calls=%d tris=%d" % [total.x, total.y])
	quit()


func _totals(node: Node) -> Vector2i:
	var total := Vector2i.ZERO
	if node is MeshInstance3D and (node as MeshInstance3D).mesh != null and (node as Node3D).visible:
		var mesh: Mesh = (node as MeshInstance3D).mesh
		total += Vector2i(mesh.get_surface_count(), _mesh_tris(mesh))
	elif node is MultiMeshInstance3D and (node as MultiMeshInstance3D).multimesh != null:
		var mm: MultiMesh = (node as MultiMeshInstance3D).multimesh
		if mm.mesh != null:
			total += Vector2i(mm.mesh.get_surface_count(), _mesh_tris(mm.mesh) * mm.instance_count)
	elif node is Label3D:
		total += Vector2i(1, 2)
	for child: Node in node.get_children():
		total += _totals(child)
	return total


func _mesh_tris(mesh: Mesh) -> int:
	var count: int = 0
	for s: int in range(mesh.get_surface_count()):
		var arrays: Array = mesh.surface_get_arrays(s)
		var indices = arrays[Mesh.ARRAY_INDEX]
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		count += (indices.size() if indices != null and indices.size() > 0 else verts.size()) / 3
	return count


func _count(node: Node, depth: int, rows: Array[String]) -> void:
	if depth > 2:
		return
	for child: Node in node.get_children():
		var t := _totals(child)
		if t.x > 0:
			rows.append("  %s%s: calls=%d tris=%d" % ["".lpad(depth * 2), child.name, t.x, t.y])
		_count(child, depth + 1, rows)
