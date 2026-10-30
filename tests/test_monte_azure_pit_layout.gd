extends SceneTree

## Monte Azure's pit lane is one consistent cross-section on an 11 m street road (SPEC 4.3): wall 0.25 m off the asphalt,
## 4.5 m fast lane centred at 8.5 m, working lane with the boxes at 13.0 m, garages from 16.0 m, ten boxes from s=46 on a
## 12 m pitch. The sim reads the same numbers through sim_layout().
## Run: godot --headless --path . -s res://tests/test_monte_azure_pit_layout.gd

const ScenePath := "res://scenes/race_world/circuits/monte_azure/monte_azure_circuit.tscn"
## The sim measures a box from the entry: stall_first_s is the first box's s on the entry's lap, so it runs past the lap's
## length (2790 + 106 = 2896 = s 46 on the next lap).
const LAYOUT: Dictionary = {
	"entry_s": 2790.0, "exit_s": 260.0, "lane_length_m": 320.0, "stall_first_s": 2896.0, "stall_pitch_m": 12.0, "stall_lane_m": 13.0,
	"fast_lane_m": 8.5, "edge_lateral_m": 5.2, "queue_gap_m": 8.0, "lane_ramp_in_m": 40.0, "lane_ramp_out_m": 80.0, "stalls": 10,
}

var failures: int = 0


func check(ok: bool, description: String) -> void:
	if not ok:
		failures += 1
		push_error(description)
	print("[%s] %s" % ["PASS" if ok else "FAIL", description])


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var scene := load(ScenePath) as PackedScene
	check(scene != null, "#P0 the circuit scene loads")
	if scene == null:
		_finish()
		return
	var circuit := scene.instantiate() as Node3D
	root.add_child(circuit)
	await process_frame
	var ribbon = circuit.get("ribbon")
	var pit = circuit.get_node_or_null("PitLane")
	check(pit is CircuitPitComplex and pit.built, "#P1 PitLane is a built CircuitPitComplex")
	if not (pit is CircuitPitComplex):
		circuit.queue_free()
		_finish()
		return

	var layout: Dictionary = pit.sim_layout()
	for key: String in LAYOUT:
		check(layout.has(key) and is_equal_approx(float(layout[key]), float(LAYOUT[key])), "#P2 sim_layout %s = %s (got %s)" % [key, LAYOUT[key], layout.get(key)])
	check(is_equal_approx(float(layout.get("speed_limit_mps", 0.0)), 80.0 / 3.6), "#P2 pit limiter is 80 km/h")
	check(pit.team_count == 10 and pit.stalls.size() == 10 and pit.garages.size() == 10, "#P3 ten boxes and ten garages")
	check(is_equal_approx(pit.stall_lane_m, 13.0) and is_equal_approx(pit.garage_front_m, 16.0), "#P4 boxes at 13.0 m and garage fronts at 16.0 m (setback 3.0 m, as Neo-Wangan)")

	var spacing_ok: bool = true
	for index: int in range(10):
		var s: float = float(pit.stalls[index]["s"])
		spacing_ok = spacing_ok and absf(s - (46.0 + 12.0 * float(index))) <= 0.6 and is_equal_approx(float(pit.stalls[index]["lateral"]), 13.0)
		spacing_ok = spacing_ok and pit.get_node_or_null("Stalls/Socket_PitStall_%d" % index) != null
	check(spacing_ok, "#P5 box i stands at s = 46 + 12 i, lateral 13.0, with its Socket_PitStall_i")
	# The sim parks box i at entry + (stall_first_s - entry_s) + pitch * i: that must be where the box is drawn.
	var parity_ok: bool = true
	for index: int in range(10):
		var sim_s: float = fposmod(float(layout["stall_first_s"]) + float(layout["stall_pitch_m"]) * float(index), ribbon.length_m)
		parity_ok = parity_ok and absf(sim_s - float(pit.stalls[index]["s"])) <= 0.05
	var lane_in_sim: float = fposmod(float(layout["exit_s"]) - float(layout["entry_s"]), ribbon.length_m)
	check(parity_ok and is_equal_approx(lane_in_sim, 320.0), "#P5b the sim's boxes (entry %.0f + offset) and its 320 m lane are the ones drawn" % layout["entry_s"])

	# The cross-section: asphalt edge < wall < fast lane < working lane < garage front.
	var edge: float = float(pit.ROAD_EDGE_M)
	var wall: float = float(pit.PIT_WALL_M)
	var fast_inner: float = float(pit.FAST_LANE_M) - float(pit.FAST_LANE_HALF_M)
	var fast_outer: float = float(pit.FAST_LANE_M) + float(pit.FAST_LANE_HALF_M)
	check(is_equal_approx(edge, 5.5) and wall - float(pit.WALL_HALF_THICKNESS_M) >= edge - 0.001, "#P6 the wall stands on the 11 m road's edge (edge %.2f, wall %.2f)" % [edge, wall])
	check(fast_inner >= wall + float(pit.WALL_HALF_THICKNESS_M) and fast_outer < pit.stall_lane_m - 1.65, "#P7 the 4.5 m fast lane (%.2f..%.2f) clears the wall and the box (box half width 1.65 m)" % [fast_inner, fast_outer])

	# The lane the cars drive: edge at both mouths, fast lane in between, blends inside the 320 m.
	check(is_equal_approx(pit.lane_lateral(0.0), 5.2) and is_equal_approx(pit.lane_lateral(320.0), 5.2), "#P8 both mouths meet the circuit at lateral 5.2 m")
	check(is_equal_approx(pit.lane_lateral(40.0), 8.5) and is_equal_approx(pit.lane_lateral(160.0), 8.5) and is_equal_approx(pit.lane_lateral(240.0), 8.5), "#P9 the fast lane runs at 8.5 m from u=40 to u=240")
	var span: Vector2 = pit.wall_span_u()
	check(span.x >= 38.0 and span.y <= 240.0 and span.y - span.x >= 150.0, "#P10 the wall stands only where the cars are on the fast lane (u %.0f..%.0f)" % [span.x, span.y])

	# Where things stand along the lap.
	var building = pit.get_node_or_null("PitBuilding")
	var stand = pit.get_node_or_null("MainGrandstand")
	var tower = pit.get_node_or_null("RaceControlTower")
	check(building != null and stand != null and tower != null, "#P11 PitBuilding, MainGrandstand and RaceControlTower stand in the complex")
	check(pit.get_node_or_null("PitAsphalt") is MeshInstance3D, "#P12 the pit asphalt is a PitAsphalt mesh (RaceVfx wets it with the road)")
	check(pit.get_node_or_null("TeamTransporters") != null and pit.transporters != null, "#P13 one transporter per team parks behind the pit building")
	if building != null and stand != null and tower != null:
		var building_s: float = _arc_of(ribbon, building.global_position)
		var tower_s: float = _arc_of(ribbon, tower.global_position)
		check(absf(building_s - 100.0) <= 4.0, "#P14 the pit building is centred on the lane's middle, s=100 (got %.1f)" % building_s)
		check(tower_s - building_s >= 62.0 + 8.0, "#P15 the control tower stands clear of the 124 m building's end (building s %.0f, tower s %.0f)" % [building_s, tower_s])
		# The kit's origin is 19 m behind its front face; the front must stand 21.5 m left of the racing line (harbour side).
		var stand_front: float = _lateral_of(ribbon, stand.global_position, 75.0) - float(stand.FRONT_X_M)
		check(absf(stand_front + 21.5) <= 0.5, "#P16 the main grandstand faces the pits from the harbour side, front at 21.5 m left (lateral %.1f m)" % stand_front)
		check(absf(_arc_of(ribbon, stand.global_position) - 75.0) <= 6.0, "#P17 the grandstand is centred on s=75 (got %.1f)" % _arc_of(ribbon, stand.global_position))

	await _check_lane_clearance(circuit, pit, ribbon)
	_check_barrier_gap(circuit, ribbon)

	circuit.queue_free()
	await process_frame
	_finish()


## A car (2 m wide, 3 m tall) driving the lane's path meets nothing solid: the real triangles of the wall, the cushion, the
## garages, the building, the signs and the transporters, probed every 2 m along all 320 m.
func _check_lane_clearance(circuit: Node3D, pit, ribbon) -> void:
	var body := StaticBody3D.new()
	root.add_child(body)
	for child: Node in pit.find_children("*", "MeshInstance3D", true, false):
		var instance := child as MeshInstance3D
		if instance.mesh == null or instance.name in ["PitAsphalt", "PitMarkings", "CatchFence", "GarageFloors"] or not instance.is_visible_in_tree():
			continue
		var shape := CollisionShape3D.new()
		shape.shape = instance.mesh.create_trimesh_shape()
		shape.transform = instance.global_transform
		body.add_child(shape)
	await physics_frame
	var space := root.world_3d.direct_space_state
	var hits: int = 0
	var u: float = 0.0
	while u <= 320.0:
		var lateral: float = pit.lane_lateral(u)
		for step: int in range(-4, 5):
			var point: Vector3 = pit.get_pit_transform(u, lateral + float(step) * 0.25).origin
			# Down from 3 m: a ray that starts inside a closed mesh meets only back faces, which a trimesh does not report.
			var query := PhysicsRayQueryParameters3D.create(point + Vector3.UP * 3.0, point + Vector3.UP * 0.1)
			hits += 0 if space.intersect_ray(query).is_empty() else 1
		u += 2.0
	check(hits == 0, "#P18 the car's lane (2 m wide, 3 m tall) is clear of every solid along the full 320 m (%d hits)" % hits)
	body.queue_free()


## The right-hand street barrier opens 25 m before the entry mouth and stays open until 40 m after the exit mouth.
func _check_barrier_gap(circuit: Node3D, ribbon) -> void:
	var env = circuit.get_node("Environment")
	var inside: int = 0
	var outside_open: int = 0
	for pose: Transform3D in env.barrier_poses:
		var local: Vector3 = ribbon.to_local(pose.origin)
		var s: float = ribbon.curve.get_closest_offset(local)
		var lateral: float = (ribbon.get_point_at_offset(s, 0.0).affine_inverse() * pose.origin).x
		if lateral > 0.0:
			var from_gap: float = fposmod(s - 2765.0, ribbon.length_m)
			inside += 1 if from_gap <= fposmod(300.0 - 2765.0, ribbon.length_m) else 0
		else:
			continue
	# Right-hand barrier blocks exist elsewhere on the lap (the gap is not the whole right side).
	var right_total: int = 0
	for pose: Transform3D in env.barrier_poses:
		var lateral_total: float = (ribbon.get_point_at_offset(ribbon.curve.get_closest_offset(ribbon.to_local(pose.origin)), 0.0).affine_inverse() * pose.origin).x
		right_total += 1 if lateral_total > 0.0 else 0
	outside_open = right_total
	check(inside == 0 and outside_open > 300, "#P19 no right-hand barrier between s=2765 and s=300 (%d inside the gap) while the rest of the lap keeps %d" % [inside, outside_open])


## The arc position (s may be negative: before the start line) on the ribbon nearest to a world point, searched every
## metre along the pit straight.
func _arc_of(ribbon, point: Vector3) -> float:
	var best: float = 0.0
	var best_distance: float = INF
	var s: float = -80.0
	while s < 360.0:
		var d: float = ribbon.get_point_at_offset(s, 0.0).origin.distance_to(point)
		if d < best_distance:
			best_distance = d
			best = s
		s += 1.0
	return best


## Metres to the right of the racing line at arc `s` (negative: left, the harbour side).
func _lateral_of(ribbon, point: Vector3, s: float) -> float:
	return (ribbon.get_point_at_offset(s, 0.0).affine_inverse() * point).x


func _finish() -> void:
	print("MONTE AZURE PIT LAYOUT TEST SUITE: %s" % ("PASS" if failures == 0 else "%d FAILURES" % failures))
	quit(0 if failures == 0 else 1)
