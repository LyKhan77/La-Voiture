extends SceneTree

const Geo := preload("res://scripts/world/enhanced_track_geometry.gd")
const Liveries := preload("res://scripts/car/team_liveries.gd")
var failures: int = 0

func world_mesh_bounds(node: Node, bounds: Array[AABB]) -> void:
	if node is MeshInstance3D and node.mesh != null:
		bounds.append(node.global_transform * node.get_aabb())
	for child: Node in node.get_children():
		world_mesh_bounds(child, bounds)

func check(ok: bool, description: String) -> void:
	print("[%s] %s" % ["PASS" if ok else "FAIL", description])
	if not ok:
		failures += 1

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var circuit: Node = load("res://scenes/race_world/brianza_circuit.tscn").instantiate()
	root.add_child(circuit)
	await process_frame
	var pit: Node = circuit.get_node("PitLane")
	var paddock: Node = pit.get_node_or_null("BrianzaPaddock")
	check(paddock != null, "Brianza paddock exists")
	if paddock != null:
		check(paddock.transporter_poses.size() == 10 and paddock.tent_poses.size() >= 6 and paddock.tent_poses.size() <= 8 and paddock.fence_poses.size() > 0 and paddock.parking_poses.size() >= 16, "paddock has transporters, tents, fencing and parking")
		for name: String in ["PaddockApron", "PaddockServiceRoad", "PaddockTransporters", "PaddockTents", "PaddockFence", "PaddockGate", "PaddockParking", "PaddockProps"]:
			check(paddock.get_node_or_null(name) != null, "%s exists" % name)
		var cells: Dictionary = Geo.hash_samples(circuit.ribbon)
		var safe: bool = true
		for rect: Rect2 in paddock.footprints():
			safe = safe and rect.position.y >= 32.0 and rect.end.y <= float(paddock.zone.lateral_to)
		for entry: Dictionary in paddock.transporter_poses:
			safe = safe and Geo.other_road_distance(cells, circuit.ribbon, float(entry.s), (entry.pose as Transform3D).origin) >= 14.0
		check(safe, "paddock footprints stay within their zone and away from other roads")
		var boxes: Array[AABB] = []
		world_mesh_bounds(pit.get_node("RaceControlTower"), boxes)
		var clear: bool = not boxes.is_empty()
		for entry: Dictionary in paddock.transporter_poses:
			for box: AABB in boxes:
				clear = clear and not box.grow(3.0).has_point((entry.pose as Transform3D).origin)
		check(clear, "transporters clear the race control tower")
		var surfaces: int = 0
		for child: Node in paddock.get_children():
			if child is MeshInstance3D and child.mesh != null:
				surfaces += child.mesh.get_surface_count()
			elif child is MultiMeshInstance3D and child.multimesh != null:
				surfaces += child.multimesh.mesh.get_surface_count()
		check(surfaces <= 10, "paddock mesh surfaces stay within 10 (%d)" % surfaces)
		var supported: bool = true
		var env: Node = circuit.get_node("Environment")
		for entry: Dictionary in paddock.transporter_poses:
			var pos: Vector3 = (entry.pose as Transform3D).origin
			supported = supported and absf(env.ground_y_at(pos) - pos.y) <= 0.05
		for pose: Transform3D in paddock.tent_poses:
			supported = supported and absf(env.ground_y_at(pose.origin) - pose.origin.y) <= 0.05
		check(supported, "transporters and tents stand on the ground platform")
		var before: int = paddock.get_child_count()
		var reverse: Array[int] = [9,8,7,6,5,4,3,2,1,0]
		pit.build(circuit.ribbon, reverse)
		paddock.build(circuit.ribbon, pit, reverse)
		var remapped: bool = paddock.get_child_count() == before
		for i: int in range(10):
			var entry: Dictionary = paddock.transporter_poses[i]
			remapped = remapped and int(entry.team) == int(pit.stalls[i].team) and (entry.color as Color).is_equal_approx(Liveries.color_for(int(pit.stalls[i].team)))
		check(remapped, "rebuild updates transporter teams without duplicating nodes")
		for mode: int in [0, 1, 2]:
			env.apply_time_of_day({"mode": mode, "floodlights": float(mode), "stars_opacity": 0.0})
			check(paddock.get_node("PaddockTents").visible and paddock.get_node("PaddockTransporters").visible, "paddock visible in time-of-day mode %d" % mode)
	circuit.free()
	await process_frame
	check(int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)) == 0, "paddock teardown leaves no orphan nodes")
	quit(1 if failures else 0)
