extends SceneTree

## FASE 7 acceptance: the Audi R8 LMS GT3 chassis is a clean, game-ready body that takes the master wheels,
## and a GT car actor picks its chassis from its team (the full 10-team grid: 8 new bodies + Audi + Porsche base).
## Run: Godot --headless --path . -s res://tests/test_audi_r8_chassis.gd

const AudiChassisScene := preload("res://scenes/car/audi_r8_chassis.tscn")
const WheelScene := preload("res://scenes/car/parts/porsche_wheel_soft.tscn")
const WorldScene := preload("res://scenes/race_weekend_world.tscn")
const ActorScript := preload("res://scripts/car/gt_car_actor.gd")
const WHEEL_X: float = 0.88
const AXLE_Z: float = 1.338
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
	var chassis: ModularCarAssembler = AudiChassisScene.instantiate()
	root.add_child(chassis)
	await process_frame
	_test_sockets(chassis)
	_test_body_mesh(chassis.base_body_mesh)
	chassis.perform_pitstop_tire_change(WheelScene, ModularCarAssembler.TireCompound.SOFT)
	_test_wheels_flush(chassis)
	chassis.queue_free()
	await _test_actor_picks_chassis_by_team()
	print("%d assertions, %d failure(s)" % [assertions, failures])
	print("FASE 7 AUDI R8 CHASSIS: %s" % ("PASS" if failures == 0 else "%d FAILURES" % failures))
	quit(0 if failures == 0 else 1)


func _test_sockets(chassis: ModularCarAssembler) -> void:
	var want: Dictionary = {
		chassis.socket_wheel_fl: Vector3(-WHEEL_X, AXLE_Y, AXLE_Z), chassis.socket_wheel_fr: Vector3(WHEEL_X, AXLE_Y, AXLE_Z),
		chassis.socket_wheel_rl: Vector3(-WHEEL_X, AXLE_Y, -AXLE_Z), chassis.socket_wheel_rr: Vector3(WHEEL_X, AXLE_Y, -AXLE_Z),
	}
	var exact: bool = true
	for socket: Marker3D in want:
		exact = exact and socket != null and socket.position.is_equal_approx(want[socket])
	check(exact, "the four wheel sockets sit at x +-0.88, y 0.33, z +-1.338 (axles centred on the wheelbase)")
	check(chassis.socket_cockpit != null and chassis.socket_cockpit.position.is_equal_approx(Vector3(0.0, 0.72, 0.05)), "the cockpit socket is at (0, 0.72, 0.05)")
	check(chassis.base_body_mesh != null and chassis.base_body_mesh.get_surface_override_material(0) is ShaderMaterial, "the body paint is the toon ShaderMaterial (livery tint keeps working)")


func _test_body_mesh(body: MeshInstance3D) -> void:
	var box: AABB = body.get_aabb()
	check(absf(box.size.z - 4.55) < 0.02 and absf(box.size.x - 2.04) < 0.05, "body is FIA GT3 size, 4.55 m long and about 2.04 m wide (%s)" % box.size)
	check(box.end.y > 1.2 and box.end.y < 1.3 and box.position.y > 0.03 and box.position.y < 0.12, "body is about 1.25 m tall and rides 3-12 cm off the ground (y %.3f .. %.3f)" % [box.position.y, box.end.y])
	check(absf(box.position.z + box.size.z * 0.5 - 0.12) < 0.05, "origin sits mid-wheelbase: the body is centred about 12 cm behind it (bumpers are not symmetric)")
	var tris: int = 0
	for surface: int in body.mesh.get_surface_count():
		tris += (body.mesh.surface_get_arrays(surface)[Mesh.ARRAY_INDEX] as PackedInt32Array).size() / 3
	check(tris >= 80000 and tris <= 120000, "body is game-ready at 80k-120k triangles (%d)" % tris)
	check(body.mesh.get_surface_count() == 2 and body.mesh.surface_get_material(1).resource_name == "FenderLinerMat", "surface 1 is the FenderLinerMat of the inner fender tubs")
	var in_wheel_well: int = 0
	var verts: PackedVector3Array = body.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	for v: Vector3 in verts:
		for sign_x: float in [-1.0, 1.0]:
			for sign_z: float in [-1.0, 1.0]:
				if v.x * sign_x > 0.55 and Vector2(v.y - AXLE_Y, v.z - sign_z * AXLE_Z).length() < ARCH_R - 0.01:
					in_wheel_well += 1
	check(in_wheel_well == 0, "no baked tyre, rim or brake geometry is left inside the four arches (%d vertices)" % in_wheel_well)


func _test_wheels_flush(chassis: ModularCarAssembler) -> void:
	var body_half_width: float = chassis.base_body_mesh.get_aabb().size.x * 0.5
	var flush: bool = true
	var grounded: bool = true
	var inside_arch: bool = true
	for socket: Marker3D in [chassis.socket_wheel_fl, chassis.socket_wheel_fr, chassis.socket_wheel_rl, chassis.socket_wheel_rr]:
		var tire: MeshInstance3D = socket.get_child(0).find_children("GT3_TireRubber", "MeshInstance3D", true, false)[0]
		var local_box: AABB = (chassis.global_transform.affine_inverse() * tire.global_transform) * tire.get_aabb()
		flush = flush and absf(absf(local_box.position.x if socket.position.x < 0.0 else local_box.end.x) - body_half_width) < 0.02
		grounded = grounded and absf(local_box.position.y) < 0.01
		inside_arch = inside_arch and local_box.size.y * 0.5 < ARCH_R
	check(flush, "each tyre's outer face is flush with the fender (within 2 cm of the body's widest point)")
	check(grounded, "all four tyres touch the ground plane")
	check(inside_arch, "the tyre radius clears the 0.372 m arch opening")


func _test_actor_picks_chassis_by_team() -> void:
	var world: Node3D = WorldScene.instantiate()
	root.add_child(world)
	world.set_physics_process(false)
	await process_frame
	var expected: Dictionary = {
		0: "res://scenes/car/base_chassis.tscn", # Apex Racing keeps the Porsche base
		1: "res://scenes/car/audi_r8_chassis.tscn", # Neon Drift
		2: "res://scenes/car/nissan_gtr_chassis.tscn", # Kurogane GT
		3: "res://scenes/car/bmw_m4_chassis.tscn", # Vanta Motors
		4: "res://scenes/car/aston_vantage_chassis.tscn", # Razorline
		5: "res://scenes/car/chevy_corvette_chassis.tscn", # Zero Hour
		6: "res://scenes/car/honda_nsx_chassis.tscn", # Oni Works
		7: "res://scenes/car/lexus_rcf_chassis.tscn", # Static Speed
		8: "res://scenes/car/mclaren_720s_chassis.tscn", # Chrome Syndicate
		9: "res://scenes/car/lambo_huracan_chassis.tscn", # Night Shift
	}
	var all_match: bool = true
	var all_wheeled: bool = true
	var paint_by_chassis: bool = true
	var per_team: Dictionary = {}
	for actor: ActorScript in world.actors:
		var want: String = expected[actor.car.team_id]
		all_match = all_match and actor.chassis.scene_file_path == want
		per_team[actor.car.team_id] = int(per_team.get(actor.car.team_id, 0)) + 1
		all_wheeled = all_wheeled and actor.wheel_controllers.size() == 4
		var body_paint := actor.chassis.base_body_mesh.get_surface_override_material(0) as ShaderMaterial
		var untinted: bool = (body_paint.get_shader_parameter("base_color") as Color).is_equal_approx(Color.WHITE)
		paint_by_chassis = paint_by_chassis and untinted and actor.chassis.keeps_original_paint
	check(all_match, "every actor rides its team's chassis (Audi + the eight new bodies + the Porsche base)")
	var even_grid: bool = per_team.size() == 10
	for count: int in per_team.values():
		even_grid = even_grid and count == 2
	check(even_grid, "each of the ten teams fields exactly two cars")
	check(all_wheeled, "every actor has its four spinning wheels after the chassis choice")
	check(paint_by_chassis, "every car keeps its original livery colours (white base_color, no team tint)")
	var tinted_car: ActorScript = world.actors[0]
	tinted_car.chassis.keeps_original_paint = false
	tinted_car._apply_livery(tinted_car.car.team_id)
	var tint: Color = (tinted_car.chassis.base_body_mesh.get_surface_override_material(0) as ShaderMaterial).get_shader_parameter("base_color")
	check(not tint.is_equal_approx(Color.WHITE), "a chassis that opts out of keeps_original_paint is still tinted with its team colour")
	world.race.dispose()
	world.queue_free()
	await process_frame
	ActorScript._paint_cache.clear()
