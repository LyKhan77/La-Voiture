extends SceneTree

## Catches missing approach/departure pavement, gaps beside the track, and a
## rectangular exit instead of a tapered merge. Inspect actual mesh triangles.
const CIRCUITS: Array[String] = ["apex_ring", "neo_wangan", "brianza"]
const WorldScene := preload("res://scenes/race_weekend_world.tscn")
const Config := preload("res://scripts/core/race_config_data.gd")
var failures: int = 0

func _initialize() -> void:
	_run.call_deferred()

func check(ok: bool, description: String) -> void:
	print("[%s] %s" % ["PASS" if ok else "FAIL", description])
	if not ok:
		failures += 1

func covered(faces: PackedVector3Array, p: Vector3) -> bool:
	var q := Vector2(p.x, p.z)
	for i: int in range(0, faces.size(), 3):
		var a := Vector2(faces[i].x, faces[i].z)
		var b := Vector2(faces[i + 1].x, faces[i + 1].z)
		var c := Vector2(faces[i + 2].x, faces[i + 2].z)
		var d: float = (b - a).cross(c - a)
		if absf(d) < 0.000001:
			continue
		var u: float = (q - a).cross(c - a) / d
		var v: float = (b - a).cross(q - a) / d
		if u >= -0.0001 and v >= -0.0001 and u + v <= 1.0001:
			return true
	return false

func _run() -> void:
	for id: String in CIRCUITS:
		Config.get_config().selected_circuit_id = id
		var circuit: Node3D = WorldScene.instantiate()
		root.add_child(circuit)
		await process_frame
		var pit: Node3D = circuit.pit_lane
		var road: float = circuit.ribbon.road_half_width_m
		var end: float = pit.merge_u() if id == "neo_wangan" else (pit.length_m if id == "apex_ring" else pit.LANE_LENGTH_M)
		var mesh: MeshInstance3D = pit.get_node("PitAsphalt")
		var faces: PackedVector3Array = mesh.mesh.get_faces()
		for label: String in ["entry", "exit"]:
			var u: float = -32.0 if label == "entry" else end + 32.0
			var point: Vector3 = mesh.to_local(pit.get_pit_transform(u, road + 0.05).origin)
			check(covered(faces, point), "%s %s has a connected tapered tail" % [id, label])
			var tip: float = -64.0 if label == "entry" else end + 64.0
			point = mesh.to_local(pit.get_pit_transform(tip, road + 0.3).origin)
			check(not covered(faces, point), "%s %s tail narrows to the road edge" % [id, label])
		var connected: bool = true
		for u: int in range(2, int(end), 5):
			var point: Vector3 = mesh.to_local(pit.get_pit_transform(float(u), road + 0.03).origin)
			connected = connected and covered(faces, point)
		check(connected, "%s has no bare strip between track and pit pavement" % id)
		circuit.free()
		await process_frame
	quit(1 if failures else 0)
