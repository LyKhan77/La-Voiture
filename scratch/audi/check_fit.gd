extends SceneTree

## Mounts the master wheels on the Audi chassis and prints each tire's extents in chassis space.
## Run: Godot --headless --path . -s scratch/audi/check_fit.gd

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var chassis: ModularCarAssembler = load("res://scenes/car/audi_r8_chassis.tscn").instantiate()
	root.add_child(chassis)
	await process_frame
	chassis.perform_pitstop_tire_change(load("res://scenes/car/parts/porsche_wheel_soft.tscn"), ModularCarAssembler.TireCompound.SOFT)
	await process_frame
	var body: MeshInstance3D = chassis.base_body_mesh
	print("base_body_mesh: ", body.name, " aabb ", body.get_aabb(), " surfaces ", body.mesh.get_surface_count())
	for s in body.mesh.get_surface_count():
		print("  surface ", s, " override: ", body.get_surface_override_material(s))
	var names := ["FL", "FR", "RL", "RR"]
	var sockets := [chassis.socket_wheel_fl, chassis.socket_wheel_fr, chassis.socket_wheel_rl, chassis.socket_wheel_rr]
	for i in 4:
		var sock: Marker3D = sockets[i]
		var wheel: Node = sock.get_child(0)
		var box := AABB()
		var first := true
		for m: MeshInstance3D in wheel.find_children("GT3_TireRubber", "MeshInstance3D", true, false):
			var xf: Transform3D = chassis.global_transform.affine_inverse() * m.global_transform
			var local := xf * m.get_aabb()
			box = local if first else box.merge(local)
			first = false
		print("%s socket %s tire x[%.3f, %.3f] y[%.3f, %.3f] z[%.3f, %.3f]" % [names[i], sock.position, box.position.x, box.end.x, box.position.y, box.end.y, box.position.z, box.end.z])
	quit(0)
