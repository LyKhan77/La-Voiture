extends SceneTree

## FASE 11 grid acceptance: the Ferrari 296 GT3 chassis is a clean, game-ready body that takes the master wheels.
## Run: godot --headless --path . -s res://tests/test_ferrari_296_chassis.gd

const ChassisScene := preload("res://scenes/car/ferrari_296_chassis.tscn")
const WheelScene := preload("res://scenes/car/parts/porsche_wheel_soft.tscn")
const WheelFit := preload("res://tests/wheel_fit_checks.gd")
const AXLE_Z: float = 1.300
const AXLE_Y: float = 0.330
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
	print("FASE 11 FERRARI 296 CHASSIS: %s" % ("PASS" if failures == 0 else "%d FAILURES" % failures))
	quit(0 if failures == 0 else 1)


func _test_sockets(chassis: ModularCarAssembler) -> void:
	check(WheelFit.sockets_consistent(chassis, AXLE_Y, AXLE_Z), "the four wheel sockets mirror left to right, sit at y %.2f and z +-%.3f, with a track half-width of 0.75 to 0.95 m" % [AXLE_Y, AXLE_Z])
	check(chassis.socket_cockpit != null, "the cockpit socket exists")
	check(chassis.base_body_mesh != null and chassis.base_body_mesh.get_surface_override_material(0) is ShaderMaterial, "the body paint is the toon ShaderMaterial (livery tint keeps working)")
	check(chassis.keeps_original_paint, "the chassis keeps the car's original livery colours")


func _test_body_mesh(body: MeshInstance3D) -> void:
	var box: AABB = body.get_aabb()
	check(absf(box.size.z - 4.56) < 0.05, "body is FIA GT3 length, ~4.56 m long (%s)" % box.size)
	check(box.size.x > 1.85 and box.size.x < 2.25, "body is about 2 m wide (%s)" % box.size)
	check(box.size.y > 1.0 and box.size.y < 1.55, "body is 1.0-1.4 m tall (%s)" % box.size)
	check(box.position.y >= 0.04, "the lowest body point stays at least 4 cm above the ground plane (y %.3f)" % box.position.y)
	check(absf(box.position.z + box.size.z * 0.5) < 0.4, "origin sits near mid-wheelbase (bumper offset %.3f m)" % (box.position.z + box.size.z * 0.5))
	var tris: int = 0
	for surface: int in body.mesh.get_surface_count():
		tris += (body.mesh.surface_get_arrays(surface)[Mesh.ARRAY_INDEX] as PackedInt32Array).size() / 3
	check(tris >= 80000 and tris <= 120000, "body is game-ready at 80k-120k triangles (%d)" % tris)
	check(body.mesh.get_surface_count() == 2 and body.mesh.surface_get_material(1).resource_name == "FenderLinerMat", "surface 1 is the FenderLinerMat of the inner fender tubs")


func _test_wheels_flush(chassis: ModularCarAssembler) -> void:
	for corner: String in ["fl", "fr", "rl", "rr"]:
		var sock: Marker3D = chassis.get("socket_wheel_%s" % corner)
		var fit: Dictionary = WheelFit.radial_gap(chassis, sock)
		check(fit["gap"] >= WheelFit.GAP_MIN and fit["gap"] <= WheelFit.GAP_MAX, "%s radial gap to body/tub is 2.5-5.0 cm (%.3f m)" % [corner.to_upper(), fit["gap"]])
		check(fit["pen"] == 0, "%s has zero body penetration inside master wheel (got %d vertices)" % [corner.to_upper(), fit["pen"]])
		var flush: float = WheelFit.flush_delta(chassis, sock)
		check(absf(flush) <= WheelFit.FLUSH_TOL, "%s tyre outer face is flush with the widest fender point within 1.5 cm (delta %+.3f m)" % [corner.to_upper(), flush])
		var skin: float = WheelFit.fender_skin_min(chassis, sock)
		check(skin >= WheelFit.SKIN_MIN, "%s fender skin clears the tyre top across the whole tread width (lowest skin %+.3f m)" % [corner.to_upper(), skin])
