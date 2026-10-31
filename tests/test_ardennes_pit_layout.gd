extends SceneTree

## Ardennes' pit lane is one consistent cross-section on a 14 m GP road (FASE 16): the separator 1.5 m off the asphalt, a 4.4 m
## fast lane centred at 10.8 m, the working lane with the boxes at 17.0 m, garages from 20.6 m, ten boxes from s=5320 (80 m
## before the line) on a 20 m pitch (a team's two cars double-stack: the box car needs room to leave past the car queued for the
## next box; at the blueprint's 14 m the lane jams, see tests/test_ardennes_pit_flood.gd). The lane is the blueprint's 420 m
## from s=5220 to s=240. The sim reads the same numbers through sim_layout().
## Run: godot --headless --path . -s res://tests/test_ardennes_pit_layout.gd

const ScenePath := "res://scenes/race_world/circuits/ardennes/ardennes_circuit.tscn"
## The sim measures a box from the entry: stall_first_s is the first box's s on the entry's lap (5220 + 100 = 5320).
const LAYOUT: Dictionary = {
	"entry_s": 5220.0, "exit_s": 240.0, "lane_length_m": 420.0, "stall_first_s": 5320.0, "stall_pitch_m": 20.0, "stall_lane_m": 17.0,
	"fast_lane_m": 10.8, "edge_lateral_m": 5.2, "queue_gap_m": 8.0, "lane_ramp_in_m": 80.0, "lane_ramp_out_m": 90.0, "stalls": 10,
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
	check(is_equal_approx(pit.stall_lane_m, 17.0) and is_equal_approx(pit.garage_front_m, 20.6), "#P4 boxes at 17.0 m and garage fronts at 20.6 m (setback 3.6 m, as Apex and Brianza)")

	var spacing_ok: bool = true
	for index: int in range(10):
		var s: float = float(pit.stalls[index]["s"])
		var wanted: float = fposmod(5320.0 + 20.0 * float(index), ribbon.length_m)
		spacing_ok = spacing_ok and absf(s - wanted) <= 0.6 and is_equal_approx(float(pit.stalls[index]["lateral"]), 17.0)
		spacing_ok = spacing_ok and pit.get_node_or_null("Stalls/Socket_PitStall_%d" % index) != null
	check(spacing_ok, "#P5 box i stands at s = 5320 + 20 i (wrapping the line), lateral 17.0, with its Socket_PitStall_i")
	# The sim parks box i at entry + (stall_first_s - entry_s) + pitch * i: that must be where the box is drawn.
	var parity_ok: bool = true
	for index: int in range(10):
		var sim_s: float = fposmod(float(layout["stall_first_s"]) + float(layout["stall_pitch_m"]) * float(index), ribbon.length_m)
		parity_ok = parity_ok and absf(sim_s - float(pit.stalls[index]["s"])) <= 0.05
	var lane_in_sim: float = fposmod(float(layout["exit_s"]) - float(layout["entry_s"]), ribbon.length_m)
	check(parity_ok and absf(lane_in_sim - 420.0) <= 0.05, "#P5b the sim's boxes (entry %.0f + offset) and its 420 m lane are the ones drawn (ribbon %.2f m)" % [layout["entry_s"], ribbon.length_m])

	# The cross-section: asphalt edge < wall < fast lane < working lane < garage front.
	var edge: float = float(pit.ROAD_EDGE_M)
	var wall: float = float(pit.PIT_WALL_M)
	var fast_inner: float = float(pit.FAST_LANE_M) - float(pit.FAST_LANE_HALF_M)
	var fast_outer: float = float(pit.FAST_LANE_M) + float(pit.FAST_LANE_HALF_M)
	check(is_equal_approx(edge, 7.0) and wall - float(pit.WALL_HALF_THICKNESS_M) >= edge + 1.0, "#P6 the separator stands 1 m or more off the 14 m road's edge (edge %.2f, wall %.2f)" % [edge, wall])
	check(fast_inner >= wall + float(pit.WALL_HALF_THICKNESS_M) and fast_outer < pit.stall_lane_m - 1.65, "#P7 the 4.4 m fast lane (%.2f..%.2f) clears the wall and the box (box half width 1.65 m)" % [fast_inner, fast_outer])

	# The lane the cars drive: the road at both mouths, the fast lane in between, blends inside the 420 m.
	check(is_equal_approx(pit.lane_lateral(0.0), 5.2) and is_equal_approx(pit.lane_lateral(420.0), 5.2), "#P8 both mouths meet the circuit at lateral 5.2 m")
	check(is_equal_approx(pit.lane_lateral(80.0), 10.8) and is_equal_approx(pit.lane_lateral(200.0), 10.8) and is_equal_approx(pit.lane_lateral(330.0), 10.8), "#P9 the fast lane runs at 10.8 m from u=80 to u=330")
	var span: Vector2 = pit.wall_span_u()
	check(span.x >= 70.0 and span.y <= 330.0 and span.y - span.x >= 240.0, "#P10 the separator stands only where the cars are on the fast lane (u %.0f..%.0f)" % [span.x, span.y])

	# Where things stand along the lap.
	var building = pit.get_node_or_null("PitBuilding")
	var stand = pit.get_node_or_null("MainGrandstand")
	var tower = pit.get_node_or_null("RaceControlTower")
	check(building != null and stand != null and tower != null, "#P11 the pit building, MainGrandstand and RaceControlTower stand in the complex")
	check(pit.get_node_or_null("PitAsphalt") is MeshInstance3D, "#P12 the pit asphalt is a PitAsphalt mesh (RaceVfx wets it with the road)")
	check(pit.get_node_or_null("TeamTransporters") != null and pit.transporters != null, "#P13 one transporter per team parks behind the pit building")
	var canopies := pit.get_node_or_null("TeamCanopies") as MeshInstance3D
	var canopy_gap: float = (float(pit.CANOPY_LATERAL_M) - float(pit.CANOPY_SIZE.y) * 0.5) - (float(pit.TRANSPORTER_LATERAL_M) + 1.7)
	check(canopies != null and canopies.mesh != null and canopies.mesh.get_surface_count() == 1 and canopy_gap >= 3.0,
		"#P13b one mesh holds the ten team canopies behind the transporters, 3 m or more clear of the trucks (gap %.1f m)" % canopy_gap)
	if building != null and stand != null and tower != null:
		var building_s: float = _arc_of(ribbon, building.global_position)
		var tower_s: float = _arc_of(ribbon, tower.global_position)
		check(absf(building_s - 10.0) <= 3.0, "#P14 the pit building is centred on the ten boxes, s=10 (got %.1f)" % building_s)
		check(absf(float(building.length_m) - 221.0) <= 3.0 and float(building.depth_m) >= 18.0, "#P14b the building is %.0f m long and %.1f m deep: ten 20 m bays and the model's end blocks" % [building.length_m, building.depth_m])
		check(tower_s - building_s >= float(building.length_m) * 0.5 + 8.5 + 10.0, "#P15 the control tower stands clear of the building's end by 10 m (building s %.0f, tower s %.0f)" % [building_s, tower_s])
		var tower_lateral: float = _lateral_of(ribbon, tower.global_position, tower_s) + float(tower.CENTRE_X_M)
		check(absf(tower_lateral - 32.0) <= 0.5, "#P15b the tower's centre stands 32 m from the racing line (got %.1f)" % tower_lateral)
		# The kit's origin is 19 m behind its front face: it is the kit's own placement, the front 19 m left of the racing line.
		var stand_front: float = _lateral_of(ribbon, stand.global_position, 125.0) - float(stand.FRONT_X_M)
		check(absf(stand_front + 19.0) <= 0.5, "#P16 the main grandstand faces the pits from the left of the straight, front at 19 m left (lateral %.1f m)" % stand_front)
		check(absf(_arc_of(ribbon, stand.global_position) - 125.0) <= 6.0, "#P17 the grandstand is centred on s=125, clear of the glass terrace at s=5280 (got %.1f)" % _arc_of(ribbon, stand.global_position))
		var bays_ok: bool = true
		for index: int in range(10):
			var bay: Vector3 = building.to_global(Vector3(0.0, 1.0, float(building.box_z(index))))
			var garage: Vector3 = (pit.garages[index] as Node3D).global_position
			bays_ok = bays_ok and Vector2(bay.x - garage.x, bay.z - garage.z).length() <= 0.5
		check(bays_ok, "#P17b garage i stands in bay i of the building (the model re-spaced from 14 m to 20 m)")

	_check_separator(pit)
	_check_connection(pit)
	await _check_lane_clearance(pit)

	circuit.queue_free()
	await process_frame
	_finish()


## The separator is 3 m in all: the 1.35 m concrete wall under a 1.65 m steel mesh fence, in 4 m modules, open at both mouths.
func _check_separator(pit) -> void:
	var total: float = float(pit.WALL_HEIGHT_M) + 1.65
	check(is_equal_approx(float(pit.WALL_HEIGHT_M), 1.35) and absf(total - 3.0) <= 0.001, "#P24 the separator is a 1.35 m wall under a 1.65 m fence, 3 m in all (%.2f m)" % total)
	var panels := pit.get_node_or_null("PitSteelMesh") as MultiMeshInstance3D
	var posts := pit.get_node_or_null("PitSteelPosts") as MultiMeshInstance3D
	check(panels != null and posts != null and panels.multimesh.instance_count >= 55 and posts.multimesh.instance_count == panels.multimesh.instance_count + 1,
		"#P25 the fence is two MultiMeshes of 4 m panels and posts (%d panels)" % (panels.multimesh.instance_count if panels != null else 0))
	var material: Material = panels.material_override if panels != null else null
	check(material is ShaderMaterial and (material as ShaderMaterial).shader.code.contains("ALPHA_SCISSOR_THRESHOLD"), "#P26 the fence mesh is an alpha-scissor wire grid")
	var frames: Array = pit.separator.get("frames", [])
	var first_u: float = 1e9
	var last_u: float = -1e9
	for frame: Transform3D in frames:
		var u: float = pit.u_from_s(_arc_of(pit.ribbon, frame.origin))
		first_u = minf(first_u, u)
		last_u = maxf(last_u, u)
	check(frames.size() >= 55 and first_u >= float(pit.WALL_START_U) and last_u <= float(pit.WALL_END_U), "#P27 no panel stands past the wall's ends: the pit mouths are open (panels at u %.0f..%.0f, wall %.0f..%.0f)" % [first_u, last_u, pit.WALL_START_U, pit.WALL_END_U])


## Where the lane meets the road. The asphalt grows out of the road's edge before the entry and fades back into it after the
## exit, always under the car's whole width, and the path is smooth (no kink, no steeper than 7 degrees).
func _check_connection(pit) -> void:
	var half_car: float = 1.04
	var tail_in: float = float(pit.TAIL_IN_M)
	var tail_out: float = float(pit.TAIL_OUT_M)
	var lane: float = float(pit.LANE_LENGTH_M)
	var covered: int = 0
	var worst_slope: float = 0.0
	var worst_kink: float = 0.0
	var previous: float = pit.lane_lateral(-tail_in)
	var previous_slope: float = 0.0
	var u: float = -tail_in + 1.0
	while u <= lane + tail_out:
		var path: float = pit.lane_lateral(u)
		var edges: Vector2 = pit.asphalt_edges(u)
		# The first 12 m of a tail are the taper out of a zero-width edge; past it the car is on pit asphalt.
		var tapering: bool = u < -tail_in + 12.0 or u > lane + tail_out - 12.0
		if not tapering and (edges.x > float(pit.ROAD_EDGE_M) or edges.y < path + half_car + 0.1):
			covered += 1
		var slope: float = path - previous
		worst_slope = maxf(worst_slope, absf(slope))
		worst_kink = maxf(worst_kink, absf(slope - previous_slope))
		previous_slope = slope
		previous = path
		u += 1.0
	check(covered == 0, "#P20 the pit asphalt is joined to the road's edge and reaches 0.1 m past the car's outer side along the lane and both tails (%d stations short)" % covered)
	check(worst_slope <= 0.12, "#P21 the path never turns more than 7 degrees (steepest %.3f m per m)" % worst_slope)
	check(worst_kink <= 0.007, "#P21b the path has no kink: its slope changes by at most 0.007 per metre (%.4f)" % worst_kink)
	var left_ends: Vector2 = Vector2(pit.asphalt_edges(-tail_in).x, pit.asphalt_edges(lane + tail_out).x)
	var right_ends: Vector2 = Vector2(pit.asphalt_edges(-tail_in).y, pit.asphalt_edges(lane + tail_out).y)
	check(right_ends.x - left_ends.x <= 0.15 and right_ends.y - left_ends.y <= 0.15, "#P22 the asphalt is a sliver on the road's edge at the far end of both tails (width %.2f and %.2f m): no hard start" % [right_ends.x - left_ends.x, right_ends.y - left_ends.y])
	check(is_equal_approx(tail_in, 65.0) and is_equal_approx(tail_out, 65.0), "#P22b the entry taper mirrors the exit's: 65 m of tail on both sides (%.0f before the entry, %.0f after the exit)" % [tail_in, tail_out])


## A car (2 m wide, 3 m tall) driving the lane's path meets nothing solid: the real triangles of the wall, the cushion, the
## building, the signs and the transporters, probed every 2 m along all 420 m. The steel mesh fence is a MultiMesh, so its
## 3 m line is probed separately: the path stays 1.0 m clear of the wall's face.
func _check_lane_clearance(pit) -> void:
	var body := StaticBody3D.new()
	root.add_child(body)
	for child: Node in pit.find_children("*", "MeshInstance3D", true, false):
		var instance := child as MeshInstance3D
		if instance.mesh == null or instance.name in ["PitAsphalt", "PitMarkings", "GarageFloors", "Glass"] or not instance.is_visible_in_tree():
			continue
		var shape := CollisionShape3D.new()
		shape.shape = instance.mesh.create_trimesh_shape()
		shape.transform = instance.global_transform
		body.add_child(shape)
	await physics_frame
	var space := root.world_3d.direct_space_state
	var hits: int = 0
	var u: float = 0.0
	while u <= 420.0:
		var lateral: float = pit.lane_lateral(u)
		for step: int in range(-4, 5):
			var point: Vector3 = pit.get_pit_transform(u, lateral + float(step) * 0.25).origin
			# Down from 3 m: a ray that starts inside a closed mesh meets only back faces, which a trimesh does not report.
			var query := PhysicsRayQueryParameters3D.create(point + Vector3.UP * 3.0, point + Vector3.UP * 0.1)
			hits += 0 if space.intersect_ray(query).is_empty() else 1
		u += 2.0
	check(hits == 0, "#P18 the car's lane (2 m wide, 3 m tall) is clear of every solid along the full 420 m (%d hits)" % hits)
	var wall_clear: bool = true
	var wall_face: float = float(pit.PIT_WALL_M) + float(pit.WALL_HALF_THICKNESS_M)
	var probe: float = float(pit.WALL_START_U)
	while probe <= float(pit.WALL_END_U):
		wall_clear = wall_clear and pit.lane_lateral(probe) - 1.0 >= wall_face + 0.9
		probe += 2.0
	check(wall_clear, "#P18b a car on the fast lane keeps at least 0.9 m between its side and the wall's face (%.2f m face, car 1.0 m half width)" % wall_face)
	body.queue_free()


## The arc position (s may be negative: before the start line) on the ribbon nearest to a world point, searched every
## metre along the pit straight.
func _arc_of(ribbon, point: Vector3) -> float:
	var best: float = 0.0
	var best_distance: float = INF
	var s: float = -200.0
	while s < 400.0:
		var d: float = ribbon.get_point_at_offset(s, 0.0).origin.distance_to(point)
		if d < best_distance:
			best_distance = d
			best = s
		s += 1.0
	return best


## Metres to the right of the racing line at arc `s` (negative: left).
func _lateral_of(ribbon, point: Vector3, s: float) -> float:
	return (ribbon.get_point_at_offset(s, 0.0).affine_inverse() * point).x


func _finish() -> void:
	print("ARDENNES PIT LAYOUT TEST SUITE: %s" % ("PASS" if failures == 0 else "%d FAILURES" % failures))
	quit(0 if failures == 0 else 1)
