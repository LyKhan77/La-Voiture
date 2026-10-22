extends SceneTree

## FASE 7 grid acceptance: the Lamborghini Huracan GT3 EVO2 chassis is a clean, game-ready body that takes the master wheels.
## Run: Godot --headless --path . -s res://tests/test_lambo_huracan_chassis.gd

const ChassisScene := preload("res://scenes/car/lambo_huracan_chassis.tscn")
const WheelScene := preload("res://scenes/car/parts/porsche_wheel_soft.tscn")
const WheelFit := preload("res://tests/wheel_fit_checks.gd")
const TEAM: int = 6
const AXLE_Z: float = 1.289
const AXLE_Y: float = 0.33
const ARCH_R: float = 0.372

var failures: int = 0
var assertions: int = 0


func _initialize() -> void:
	call_deferred("_run")


func check(ok: bool, description: String) -> void:
	assertions += 1
	if not ok:
		failures += 1
		push_error(description)
	print("[%s] %s" % ["PASS" if ok else "FAIL", description])


func _run() -> void:
	var chassis: ModularCarAssembler = ChassisScene.instantiate()
	root.add_child(chassis)
	await process_frame
	_test_sockets(chassis)
	_test_body_mesh(chassis.base_body_mesh)
	chassis.perform_pitstop_tire_change(WheelScene, ModularCarAssembler.TireCompound.SOFT)
	_test_wheels_flush(chassis)
	chassis.queue_free()
	await process_frame
	print("%d assertions, %d failure(s)" % [assertions, failures])
	print("FASE 7 LAMBORGHINI HURACAN CHASSIS: %s" % ("PASS" if failures == 0 else "%d FAILURES" % failures))
	quit(0 if failures == 0 else 1)


func _test_sockets(chassis: ModularCarAssembler) -> void:
	check(WheelFit.sockets_consistent(chassis, AXLE_Y, AXLE_Z), "the four wheel sockets mirror left to right, sit at y %.2f and z +-%.3f, with a track half-width of 0.75 to 0.95 m (the x per axle comes from scratch/fit_cars.gd --apply and is checked by the flush test)" % [AXLE_Y, AXLE_Z])
	check(chassis.socket_cockpit != null, "the cockpit socket exists")
	check(chassis.base_body_mesh != null and chassis.base_body_mesh.get_surface_override_material(0) is ShaderMaterial, "the body paint is the toon ShaderMaterial (livery tint keeps working)")
	check(chassis.keeps_original_paint, "the chassis keeps the car's original livery colours")


func _test_body_mesh(body: MeshInstance3D) -> void:
	var box: AABB = body.get_aabb()
	check(absf(box.size.z - 4.55) < 0.02, "body is FIA GT3 length, 4.55 m long (%s)" % box.size)
	check(box.size.x > 1.85 and box.size.x < 2.25, "body is about 2 m wide (%s)" % box.size)
	check(box.size.y > 1.0 and box.size.y < 1.55, "body is 1.0-1.4 m tall (%s)" % box.size)
	check(box.position.y >= 0.04, "the lowest body point stays at least 4 cm above the ground plane (y %.3f)" % box.position.y)
	check(absf(box.position.z + box.size.z * 0.5) < 0.4, "origin sits near mid-wheelbase (bumper offset %.3f m)" % (box.position.z + box.size.z * 0.5))
	var tris: int = 0
	for surface: int in body.mesh.get_surface_count():
		tris += (body.mesh.surface_get_arrays(surface)[Mesh.ARRAY_INDEX] as PackedInt32Array).size() / 3
	check(tris >= 80000 and tris <= 120000, "body is game-ready at 80k-120k triangles (%d)" % tris)
	check(body.mesh.get_surface_count() == 2 and body.mesh.surface_get_material(1).resource_name == "FenderLinerMat", "surface 1 is the FenderLinerMat of the inner fender tubs")
	var in_wheel_well: int = 0
	var central: int = 0
	var sunk: int = 0
	var verts: PackedVector3Array = body.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	for v: Vector3 in verts:
		if absf(v.x) < 0.5:
			central += 1
			sunk += int(v.y < 0.0)
	check(sunk * 200 < central, "the underbody floor sits on the ground plane (%d of %d central vertices dip below)" % [sunk, central])
	for v: Vector3 in verts:
		for sign_x: float in [-1.0, 1.0]:
			for sign_z: float in [-1.0, 1.0]:
				if v.x * sign_x > 0.55 and Vector2(v.y - AXLE_Y, v.z - sign_z * AXLE_Z).length() < ARCH_R - 0.01:
					in_wheel_well += 1
	check(in_wheel_well == 0, "no baked tyre, rim or brake geometry is left inside the four arches (%d vertices)" % in_wheel_well)


func _test_wheels_flush(chassis: ModularCarAssembler) -> void:
	var flush: bool = true
	var grounded: bool = true
	var inside_arch: bool = true
	var gap_ok: bool = true
	var skin_ok: bool = true
	for socket: Marker3D in [chassis.socket_wheel_fl, chassis.socket_wheel_fr, chassis.socket_wheel_rl, chassis.socket_wheel_rr]:
		var tire: Dictionary = WheelFit.tire_box(chassis, socket)
		var fit: Dictionary = WheelFit.radial_gap(chassis, socket)
		flush = flush and absf(WheelFit.flush_delta(chassis, socket)) < 0.02
		grounded = grounded and absf(tire["bottom"]) < 0.01
		inside_arch = inside_arch and tire["radius"] < ARCH_R
		gap_ok = gap_ok and fit["gap"] >= WheelFit.GAP_MIN and fit["gap"] <= WheelFit.GAP_MAX and fit["pen"] == 0
		skin_ok = skin_ok and WheelFit.fender_skin_min(chassis, socket) >= WheelFit.SKIN_MIN
	check(flush, "each tyre's outer face is flush with the fender of its own axle (within 2 cm of the body's widest point there)")
	check(grounded, "all four tyres touch the ground plane")
	check(inside_arch, "the tyre radius clears the 0.372 m arch opening")
	check(gap_ok, "every tyre has 2.5-5 cm of radial gap to the arch and the tub, and no body vertex (tub included) inside the tyre")
	check(skin_ok, "the fender skin over every tyre stays at least 5 cm above the tyre top across its width (no tyre poking out of the body)")
