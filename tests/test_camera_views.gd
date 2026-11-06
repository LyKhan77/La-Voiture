extends SceneTree

## Run: godot --headless --path . -s res://tests/test_camera_views.gd
## Fase 30: HOOD, SIDE and FRONT_TO_REAR cameras. The cars have no cockpit and every nose differs, so the
## hood eye is measured per body; the side camera sits on the inside of the bend and never crosses the car.
const Roster := preload("res://scripts/ui/garage_roster.gd")
const DirectorScript := preload("res://scripts/world/weekend/broadcast_camera_director.gd")
const RigScript := preload("res://scripts/world/weekend/car_camera_rig.gd")
const RibbonScript := preload("res://scripts/car/track_ribbon.gd")

const CIRCLE_R: float = 120.0
const FRAME: float = 1.0 / 60.0

var failures: int = 0
var assertions: int = 0


func _initialize() -> void:
	call_deferred("_run")


func check(ok: bool, message: String) -> void:
	assertions += 1
	if not ok:
		failures += 1
		push_error(message)
	print("[%s] %s" % ["PASS" if ok else "FAIL", message])


func _circle(counter_clockwise: bool) -> RibbonScript:
	var ribbon := RibbonScript.new()
	ribbon.curve = Curve3D.new()
	var steps: int = 72
	for i: int in range(steps + 1):
		var t: float = TAU * float(i % steps) / float(steps)
		var sign_z: float = -1.0 if counter_clockwise else 1.0
		ribbon.curve.add_point(Vector3(CIRCLE_R * cos(t), 0.0, sign_z * CIRCLE_R * sin(t)))
	root.add_child(ribbon) # _ready rebuilds the sample table
	return ribbon


## Stand-in for GtCarActor: the camera only reads `chassis` and track_distance_m().
func _car(slug: String) -> Node3D:
	var car := Node3D.new()
	var script := GDScript.new()
	script.source_code = "extends Node3D\nvar chassis: Node3D\nvar s: float = 0.0\nfunc track_distance_m() -> float:\n\treturn s\n"
	script.reload()
	car.set_script(script)
	var chassis: Node3D = (load("res://scenes/car/%s_chassis.tscn" % slug) as PackedScene).instantiate()
	chassis.rotation.y = PI # the model faces +Z, the ribbon travels along -Z
	car.add_child(chassis)
	car.set("chassis", chassis)
	root.add_child(car)
	return car


func _place(car: Node3D, ribbon: RibbonScript, s: float) -> void:
	car.set("s", s)
	car.global_transform = ribbon.get_point_at_offset(s, 0.0)


func _body_top_ahead(chassis: Node3D, from_z: float) -> float:
	var body: MeshInstance3D = chassis.get("base_body_mesh") as MeshInstance3D
	var to_chassis: Transform3D = chassis.global_transform.affine_inverse() * body.global_transform
	var top: float = -INF
	for surface: int in range(body.mesh.get_surface_count()):
		for local: Vector3 in body.mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]:
			var v: Vector3 = to_chassis * local
			if absf(v.x) < 0.35 and v.z >= from_z and v.y > top:
				top = v.y
	return top


func _run() -> void:
	var cars: Dictionary = {}
	var camera := Camera3D.new()
	root.add_child(camera)
	var ccw: RibbonScript = _circle(true)
	var cw: RibbonScript = _circle(false)
	var director := DirectorScript.new()
	root.add_child(director)
	director.setup(camera, ccw)

	var worst_ms: float = 0.0
	for slug: String in Roster.CAR_SLUGS:
		var car: Node3D = _car(slug)
		cars[slug] = car
		var chassis: Node3D = car.get("chassis")
		var t0: int = Time.get_ticks_usec()
		var rig: RigScript = RigScript.measure(chassis)
		worst_ms = maxf(worst_ms, float(Time.get_ticks_usec() - t0) / 1000.0)
		var top: float = _body_top_ahead(chassis, rig.eye.z - 0.05)
		check(rig.eye.x == 0.0 and rig.eye.y >= top + 0.1 and rig.eye.z > rig.axle_z and rig.eye.z < rig.nose_z,
			"%s hood eye (%.2f, %.2f) sits on the centre line, %.2f m above the body ahead of it, between axle %.2f and nose %.2f"
			% [slug, rig.eye.x, rig.eye.y, rig.eye.y - top, rig.axle_z, rig.nose_z])
		check(RigScript.measure(chassis) == rig, "%s measurement is cached" % slug)
	print("first measurement worst case: %.1f ms" % worst_ms)

	# HOOD / FRONT_TO_REAR on a straight-ish stretch for every car.
	for slug: String in Roster.CAR_SLUGS:
		var car: Node3D = cars[slug]
		_place(car, ccw, 100.0)
		director.set_target(car)
		var rig: RigScript = RigScript.measure(car.get("chassis"))
		var forward: Vector3 = -car.global_transform.basis.z
		director.set_mode(DirectorScript.Mode.HOOD)
		director.update(FRAME)
		var offset: Vector3 = camera.global_position - car.global_position
		check(offset.dot(forward) > rig.axle_z and (-camera.global_transform.basis.z).dot(forward) > 0.97,
			"%s hood cam rides %.2f m ahead of the car origin and looks forward" % [slug, offset.dot(forward)])
		director.set_mode(DirectorScript.Mode.FRONT_TO_REAR)
		director.update(FRAME)
		offset = camera.global_position - car.global_position
		check(offset.dot(forward) > rig.nose_z + 3.0 and (-camera.global_transform.basis.z).dot(forward) < -0.8,
			"%s front-to-rear cam sits %.2f m ahead of the nose and looks back at the car" % [slug, offset.dot(forward) - rig.nose_z])
		director.set_mode(DirectorScript.Mode.SIDE)
		director.update(FRAME)
		var local: Vector3 = car.to_local(camera.global_position)
		var inside_box: bool = absf(local.x) < rig.half_width + 0.2 and local.z > -rig.nose_z - 0.2 and local.z < -rig.tail_z + 0.2 and camera.global_position.y < rig.eye.y
		check(not inside_box, "%s side cam is outside the car body" % slug)

	# SIDE picks the inside of the bend, both ways round.
	var car: Node3D = cars["audi_r8"]
	var rig: RigScript = RigScript.measure(car.get("chassis"))
	for ribbon: RibbonScript in [ccw, cw]:
		director.ribbon = ribbon
		_place(car, ribbon, 100.0)
		director.set_target(car)
		director.set_mode(DirectorScript.Mode.SIDE)
		director.update(FRAME)
		var to_centre: float = Vector3.ZERO.distance_to(Vector3(camera.global_position.x, 0.0, camera.global_position.z))
		var car_to_centre: float = Vector3.ZERO.distance_to(Vector3(car.global_position.x, 0.0, car.global_position.z))
		check(to_centre < car_to_centre - 1.0,
			"side cam is on the inside of the bend (%.1f m from the centre, the car is at %.1f)" % [to_centre, car_to_centre])

	# Swap to the opposite bend: the side holds for SIDE_HOLD_S, then orbits round the nose without touching the car.
	director.ribbon = ccw
	_place(car, ccw, 100.0)
	director.set_target(car)
	director.set_mode(DirectorScript.Mode.SIDE)
	director.update(FRAME)
	var side_before: float = director._side
	director.ribbon = cw
	director.update(0.5)
	check(director._side == side_before, "side cam holds its side for a short opposite bend (S-bend)")
	var clear: bool = true
	var min_nose_gap: float = INF
	for _frame: int in range(240):
		director.update(FRAME)
		var local: Vector3 = car.to_local(camera.global_position)
		if absf(local.x) < rig.half_width + 0.2 and local.z > -rig.nose_z - 0.2 and local.z < -rig.tail_z + 0.2:
			clear = false
		min_nose_gap = minf(min_nose_gap, camera.global_position.distance_to(car.global_position))
	check(director._side == -side_before, "side cam swaps once the new bend has held for %.1f s" % director.SIDE_HOLD_S)
	check(clear, "the swap orbits round the nose and never passes through the car (closest %.1f m)" % min_nose_gap)

	check(director.CYCLE == [director.Mode.CHASE, director.Mode.HOOD, director.Mode.SIDE, director.Mode.FRONT_TO_REAR, director.Mode.HELI, director.Mode.TRACKSIDE_TV],
		"C cycles chase > hood > side > front-to-rear > heli > trackside TV")
	check(director.MODE_NAMES[director.Mode.HOOD] == "HOOD CAM" and director.MODE_NAMES[director.Mode.SIDE] == "SIDE CAM"
		and director.MODE_NAMES[director.Mode.FRONT_TO_REAR] == "FRONT-TO-REAR CAM", "HUD names for the new cameras")

	print("CAMERA VIEWS: %d assertions, %d FAIL" % [assertions, failures])
	quit(0 if failures == 0 else 1)
