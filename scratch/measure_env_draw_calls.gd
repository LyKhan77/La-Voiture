extends SceneTree

## What does the circuit environment cost in draw calls per view? Native run (needs a GPU):
##   godot --path . --resolution 1920x1080 --script res://scratch/measure_env_draw_calls.gd -- <circuit_id> [step_m]
## A chase-height camera is placed every `step_m` along the lap (forward, like the flythrough gate). At each view the
## frame's draw calls are read with the environment visible and hidden (the difference is the environment's share,
## shadow passes included), with the sun's shadows on and off. Reports the worst, p95 and mean views and where the
## worst ones are, so a budget is a number that does not depend on where a sampling run happened to look.

const WorldScene := preload("res://scenes/race_weekend_world.tscn")
const Config := preload("res://scripts/core/race_config_data.gd")
const Settings := preload("res://scripts/core/presentation_settings.gd")


var world: Node3D
var camera: Camera3D


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var circuit: String = args[0] if args.size() > 0 else "brianza"
	var step_m: float = float(args[1]) if args.size() > 1 else 150.0
	DisplayServer.window_set_size(Vector2i(1920, 1080))
	root.size = Vector2i(1920, 1080)
	Settings.set_quality(Settings.Quality.HIGH)
	var config := Config.get_config()
	config.selected_circuit_id = circuit
	config.selected_team_id = 4
	config.total_laps = 3
	config.time_of_day = 0
	config.weather_preset = 0
	config.race_seed = 19220903
	world = WorldScene.instantiate()
	root.add_child(world)
	world.hud.visible = false
	world.process_mode = Node.PROCESS_MODE_DISABLED
	camera = Camera3D.new()
	camera.far = 5000.0
	camera.fov = 65.0
	root.add_child(camera)
	for _i: int in range(30):
		await process_frame
	var sun: DirectionalLight3D = world.get_node("Sun")
	if args.size() > 2 and args[2] == "ablate":
		await _ablate(float(args[3]) if args.size() > 3 else 0.0)
		world.free()
		camera.free()
		quit(0)
		return
	var rows: Array[Dictionary] = []
	var count: int = int(world.ribbon.length_m / step_m)
	for index: int in range(count):
		var s: float = float(index) * step_m
		var origin: Vector3 = world.ribbon.get_point_at_offset(s, 0.0).origin + Vector3.UP * 3.0
		var target: Vector3 = world.ribbon.get_point_at_offset(s + 60.0, 0.0).origin + Vector3.UP * 1.0
		camera.transform = Transform3D(Basis.looking_at(target - origin, Vector3.UP), origin)
		camera.make_current()
		var row: Dictionary = {"s": s}
		for shadows: bool in [true, false]:
			sun.shadow_enabled = shadows
			world.environment.visible = true
			var with_env: int = await _calls()
			world.environment.visible = false
			var without_env: int = await _calls()
			row["env_shadows" if shadows else "env_noshadow"] = with_env - without_env
			if shadows:
				row["frame_total"] = with_env
		world.environment.visible = true
		sun.shadow_enabled = true
		rows.append(row)
	_report(circuit, rows)
	world.free()
	camera.free()
	quit(0)


## Which part of the environment owns the draw calls at one view: every direct child hidden in turn (shadows on).
func _ablate(s: float) -> void:
	var origin: Vector3 = world.ribbon.get_point_at_offset(s, 0.0).origin + Vector3.UP * 3.0
	var target: Vector3 = world.ribbon.get_point_at_offset(s + 60.0, 0.0).origin + Vector3.UP * 1.0
	camera.transform = Transform3D(Basis.looking_at(target - origin, Vector3.UP), origin)
	camera.make_current()
	var env: Node3D = world.environment
	if OS.get_environment("NOSHADOW") != "":
		(world.get_node("Sun") as DirectionalLight3D).shadow_enabled = false
	var base: int = await _calls()
	env.visible = false
	var none: int = await _calls()
	env.visible = true
	print("ABLATE view s=%.0f: frame %d, environment share %d" % [s, base, base - none])
	var shares: Array[Dictionary] = []
	for child: Node in env.get_children():
		if not child is Node3D:
			continue
		(child as Node3D).visible = false
		var without: int = await _calls()
		(child as Node3D).visible = true
		shares.append({"name": "%s (%s)" % [child.name, child.get_class()], "calls": base - without})
	shares.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a["calls"]) > int(b["calls"]))
	for share: Dictionary in shares.slice(0, 12):
		print("ABLATE   %4d  %s" % [int(share["calls"]), String(share["name"])])
	# One level down inside the biggest owner, so a batch that costs more than its instance count suggests shows up.
	if shares.is_empty():
		return
	var top_name: String = String(shares[0]["name"]).split(" (")[0]
	var top: Node3D = env.get_node(top_name)
	top.visible = false
	var top_hidden: int = await _calls()
	var children_hidden: int = 0
	top.visible = true
	for grandchild: Node in top.get_children():
		if grandchild is Node3D:
			(grandchild as Node3D).visible = false
	children_hidden = await _calls()
	for grandchild: Node in top.get_children():
		if grandchild is Node3D:
			(grandchild as Node3D).visible = true
	print("ABLATE   %s hidden: frame %d (base %d); all its children hidden: frame %d" % [top_name, top_hidden, base, children_hidden])
	# Hidden cumulatively, one child more each step: where does the non-additive part appear?
	var cumulative: Array[Node3D] = []
	for grandchild: Node in top.get_children():
		if grandchild is Node3D:
			(grandchild as Node3D).visible = false
			cumulative.append(grandchild as Node3D)
			print("ABLATE   cumulative %d hidden (through %s): frame %d" % [cumulative.size(), grandchild.name, await _calls()])
	for node: Node3D in cumulative:
		node.visible = true
	# Each child alone, the others hidden.
	for only: Node in top.get_children():
		if not only is Node3D:
			continue
		for other: Node in top.get_children():
			if other is Node3D:
				(other as Node3D).visible = other == only
		var mm: MultiMesh = (only as MultiMeshInstance3D).multimesh if only is MultiMeshInstance3D else null
		print("ABLATE   only %s visible: frame %d (instances %d, surfaces %d)" % [only.name, await _calls(), mm.instance_count if mm else 0, mm.mesh.get_surface_count() if mm else 0])
	for other: Node in top.get_children():
		if other is Node3D:
			(other as Node3D).visible = true
	# The rest of the environment hidden: what do the trees cost with nothing else of the circuit around?
	for sibling: Node in env.get_children():
		if sibling is Node3D and sibling != top:
			(sibling as Node3D).visible = false
	for other: Node in top.get_children():
		if other is Node3D:
			(other as Node3D).visible = false
	var nothing: int = await _calls()
	for other: Node in top.get_children():
		if other is Node3D:
			(other as Node3D).visible = other.name == &"TreePines"
	print("ABLATE   rest of environment hidden: no trees %d, pines only %d" % [nothing, await _calls()])
	for sibling: Node in env.get_children():
		if sibling is Node3D:
			(sibling as Node3D).visible = true
	for other: Node in top.get_children():
		if other is Node3D:
			(other as Node3D).visible = true
	# Geometry-instance switches on the trees, one at a time and then together.
	var geometry: Array[GeometryInstance3D] = []
	for node: Node in top.get_children():
		if node is GeometryInstance3D:
			geometry.append(node as GeometryInstance3D)
	for gi: GeometryInstance3D in geometry:
		gi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	print("ABLATE   trees cast_shadow off: frame %d" % await _calls())
	for gi: GeometryInstance3D in geometry:
		gi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		gi.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	print("ABLATE   trees gi_mode disabled: frame %d" % await _calls())
	for gi: GeometryInstance3D in geometry:
		gi.gi_mode = GeometryInstance3D.GI_MODE_STATIC
	print("ABLATE   trees back to default: frame %d" % await _calls())
	# The same trees split into grid chunks, each with its own tight bounds, instead of one batch spanning the circuit.
	for cell_m: float in [50.0, 75.0, 100.0]:
		var chunks: Array[Node3D] = []
		for gi: GeometryInstance3D in geometry:
			var source: MultiMesh = (gi as MultiMeshInstance3D).multimesh
			var buckets: Dictionary = {}
			for index: int in range(source.instance_count):
				var pose: Transform3D = source.get_instance_transform(index)
				var key := Vector2i(floori(pose.origin.x / cell_m), floori(pose.origin.z / cell_m))
				if not buckets.has(key):
					buckets[key] = []
				(buckets[key] as Array).append(pose)
			for key: Vector2i in buckets:
				var poses: Array = buckets[key]
				var part := MultiMesh.new()
				part.transform_format = MultiMesh.TRANSFORM_3D
				part.mesh = source.mesh
				part.instance_count = poses.size()
				for index: int in range(poses.size()):
					part.set_instance_transform(index, poses[index])
				var chunk := MultiMeshInstance3D.new()
				chunk.multimesh = part
				top.add_child(chunk)
				chunks.append(chunk)
			gi.visible = false
		print("ABLATE   trees in %.0f m chunks (%d chunks): frame %d" % [cell_m, chunks.size(), await _calls()])
		for chunk: Node3D in chunks:
			chunk.queue_free()
		for gi: GeometryInstance3D in geometry:
			gi.visible = true
		await process_frame
	# Same trees drawn with a plain material: is it the geometry or the shader that costs the calls?
	var plain := StandardMaterial3D.new()
	for grandchild: Node in top.get_children():
		if grandchild is GeometryInstance3D:
			(grandchild as GeometryInstance3D).material_override = plain
	print("ABLATE   plain material on %s children: frame %d" % [top_name, await _calls()])
	for grandchild: Node in top.get_children():
		if grandchild is GeometryInstance3D:
			(grandchild as GeometryInstance3D).material_override = null
	for grandchild: Node in top.get_children():
		if not grandchild is Node3D:
			continue
		(grandchild as Node3D).visible = false
		var without_child: int = await _calls()
		(grandchild as Node3D).visible = true
		print("ABLATE     %4d  %s/%s (%s)" % [base - without_child, top_name, grandchild.name, grandchild.get_class()])


func _calls() -> int:
	for _i: int in range(3):
		await process_frame
	return int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))


func _report(circuit: String, rows: Array[Dictionary]) -> void:
	for key: String in ["env_shadows", "env_noshadow", "frame_total"]:
		var values: Array[int] = []
		var total: int = 0
		for row: Dictionary in rows:
			values.append(int(row[key]))
			total += int(row[key])
		values.sort()
		print("ENVCALLS %s %-13s views=%d mean %.0f p95 %d max %d" % [circuit, key, values.size(), float(total) / float(values.size()), values[clampi(int(float(values.size()) * 0.95), 0, values.size() - 1)], values[values.size() - 1]])
	var sorted: Array[Dictionary] = rows.duplicate()
	sorted.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a["env_shadows"]) > int(b["env_shadows"]))
	var worst: Array[String] = []
	for row: Dictionary in sorted.slice(0, 6):
		worst.append("s=%.0f %d (no shadows %d)" % [float(row["s"]), int(row["env_shadows"]), int(row["env_noshadow"])])
	print("ENVCALLS %s worst views: %s" % [circuit, ", ".join(worst)])
