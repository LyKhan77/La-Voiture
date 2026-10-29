extends SceneTree

## Pit lane refinement (feedback round after FASE 10): a lane that peels off the right edge of the
## circuit and rejoins it there (never through the racing line), one asphalt with the track, a pit
## wall that never stands in a lane, wide enough gaps between the fast lane, the pit boxes and the
## garages, complete equipment in every garage, and a full pit crew that waits in its garage, steps
## out when its car is on the way and goes back afterwards.
## Run: Godot --headless --path . -s res://tests/test_pit_lane.gd

const WorldScene := preload("res://scenes/race_weekend_world.tscn")
const PitLaneScript := preload("res://scripts/world/circuits/apex_ring/apex_pit_complex.gd")
const ToonMaterialsScript := preload("res://scripts/world/shared/toon_materials.gd")
const ActorScript := preload("res://scripts/car/gt_car_actor.gd")
const DirectorScript := preload("res://scripts/world/weekend/race_weekend_director.gd")
const Types := preload("res://scripts/gt/gt_types.gd")

const ROAD_SHADER_PATH := "res://shaders/road_asphalt.gdshader"
const CAR_HALF_WIDTH_M: float = 1.05
const CAR_HALF_LENGTH_M: float = 2.225
const FRAME: float = 1.0 / 60.0

var failures: int = 0
var assertions: int = 0
var world: Node3D


func _initialize() -> void:
	call_deferred("_run")


func check(ok: bool, description: String) -> void:
	assertions += 1
	if not ok:
		failures += 1
		push_error(description)
	print("[%s] %s" % ["PASS" if ok else "FAIL", description])


## A constant the refinement adds; NAN when it does not exist yet so a missing one fails a check instead of the parse.
func const_of(constant: String) -> float:
	var script: Script = load("res://scripts/world/circuits/apex_ring/apex_pit_complex.gd")
	return float(script.get_script_constant_map().get(constant, NAN))


func prop(object: Object, name: String) -> Variant:
	return object.get(name) if object != null else null


func array_of(object: Object, name: String) -> Array:
	var value: Variant = prop(object, name)
	return value if value is Array else []


func _run() -> void:
	world = WorldScene.instantiate()
	root.add_child(world)
	world.set_process(false)
	await process_frame
	_test_layout_gaps()
	_test_entry_and_exit()
	_test_asphalt_matches_track()
	_test_pit_wall()
	_test_markings()
	_test_garage_equipment()
	_test_standby_crew()
	await _test_crew_cycle()
	_test_stop_in_the_world()
	world.race.dispose()
	world.queue_free()
	for _frame: int in range(3):
		await process_frame
	ToonMaterialsScript._cache.clear()
	ActorScript._paint_cache.clear()
	print("%d assertions, %d failure(s)" % [assertions, failures])
	print("PIT LANE REFINEMENT: %s" % ("PASS" if failures == 0 else "%d FAILURES" % failures))
	quit(0 if failures == 0 else 1)


# --- layout across the lane -----------------------------------------------------------------

func _test_layout_gaps() -> void:
	var track_edge: float = world.ribbon.road_half_width_m
	var wall: float = const_of("PIT_WALL_M")
	var lane: float = const_of("FAST_LANE_M")
	var half: float = const_of("LANE_HALF_WIDTH_M")
	var box: float = const_of("STALL_LANE_M")
	var front: float = const_of("GARAGE_FRONT_M")
	var fascia: float = front - 0.55
	var lane_left: float = lane - half
	var lane_right: float = lane + half
	var box_left: float = box - CAR_HALF_WIDTH_M
	var box_right: float = box + CAR_HALF_WIDTH_M
	var passing_right: float = lane + CAR_HALF_WIDTH_M
	check(wall - 0.25 >= track_edge + 1.0 and lane_left - (wall + 0.25) >= 0.4 and lane_left - (wall + 0.25) <= 1.0,
		"#L1 the pit wall stands >= 1.0 m off the track edge (%.2f) with a %.2f m verge before the fast lane" % [wall - 0.25 - track_edge, lane_left - wall - 0.25])
	check(lane_right - lane_left >= 4.4 and box_left - passing_right >= 3.0,
		"#L2 the fast lane is %.1f m wide and a car running down its middle clears a car parked in its box by %.2f m (>= 3.0)" % [lane_right - lane_left, box_left - passing_right])
	check(box_left - lane_right >= 1.8 and fascia - box_right >= 1.8,
		"#L3 the crew has %.2f m between the fast lane and the box car and %.2f m between the box car and the garage fascia (>= 1.8 each)" % [box_left - lane_right, fascia - box_right])


func _test_entry_and_exit() -> void:
	var pit: Node3D = world.pit_lane
	var edge: float = const_of("EDGE_LATERAL_M")
	var length: float = pit.length_m
	var at_entry: float = pit.lane_lateral(0.0) if pit.has_method("lane_lateral") else NAN
	var at_exit: float = pit.lane_lateral(length) if pit.has_method("lane_lateral") else NAN
	var mid: float = pit.lane_lateral(length * 0.5) if pit.has_method("lane_lateral") else NAN
	check(is_equal_approx(at_entry, edge) and is_equal_approx(at_exit, edge) and is_equal_approx(mid, const_of("FAST_LANE_M")) and edge > 4.5 and edge < world.ribbon.road_half_width_m,
		"#L4 the lane peels off and rejoins at lateral %.1f (the right half of the track), not at the racing line: entry %.2f, exit %.2f, middle %.2f" % [edge, at_entry, at_exit, mid])
	# The merge is gentle: the lane's lateral never changes faster than 1 m per 8 m along the ramps.
	var steepest: float = 0.0
	if pit.has_method("lane_lateral"):
		var u: float = 0.0
		while u < length - 2.0:
			steepest = maxf(steepest, absf(pit.lane_lateral(u + 2.0) - pit.lane_lateral(u)) / 2.0)
			u += 2.0
	check(steepest > 0.0 and steepest <= 0.125, "#L5 the entry and exit roads change lateral by at most %.3f m per m (<= 0.125)" % steepest)


# --- asphalt ----------------------------------------------------------------------------------

func _test_asphalt_matches_track() -> void:
	var instance: MeshInstance3D = world.pit_lane.get_node_or_null("PitAsphalt") as MeshInstance3D
	var shader_ok: bool = false
	var inner_most: float = INF
	var vertices: int = 0
	if instance != null and instance.mesh != null:
		var material: Material = instance.material_override if instance.material_override != null else instance.mesh.surface_get_material(0)
		shader_ok = material is ShaderMaterial and (material as ShaderMaterial).shader != null and (material as ShaderMaterial).shader.resource_path == ROAD_SHADER_PATH
		for surface: int in range(instance.mesh.get_surface_count()):
			for vertex: Vector3 in instance.mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]:
				vertices += 1
				var pose: Transform3D = _nearest_pose(vertex)
				inner_most = minf(inner_most, (vertex - pose.origin).dot(pose.basis.x))
	check(shader_ok and vertices > 500 and inner_most >= 5.5,
		"#A1 the pit asphalt wears the track's own shader and never reaches past lateral %.1f toward the racing line (%d vertices)" % [inner_most, vertices])
	# After the first frame RaceVfx drives it with the same material as the road, so rain wets both alike.
	var vfx_material: Material = world.vfx.track_material
	var pit_material: Material = instance.material_override if instance != null else null
	check(pit_material == vfx_material and vfx_material != null, "#A2 the pit asphalt shares the road's weather material, so wetness and puddles match")
	# The working lane is paved in front of every box, including the first ones that stand on the entry ramp.
	var fascia: float = const_of("GARAGE_FRONT_M") - 0.55
	var short_of: Array[int] = []
	for team: int in range(PitLaneScript.TEAM_COUNT):
		var pose: Transform3D = world.ribbon.get_point_at_offset(float(world.pit_lane.stalls[team]["s"]), 0.0)
		var reach: float = 0.0
		if instance != null and instance.mesh != null:
			for vertex: Vector3 in instance.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]:
				var local: Vector3 = vertex - pose.origin
				if absf(local.dot(pose.basis.z)) < 3.0:
					reach = maxf(reach, local.dot(pose.basis.x))
		if reach < fascia - 0.2:
			short_of.append(team)
	check(short_of.is_empty(), "#A3 the pit asphalt reaches the garage fascia (lateral >= %.1f) in front of every one of the 10 boxes (short at boxes %s)" % [fascia - 0.2, str(short_of)])


## The ribbon pose closest to a ground point (coarse, only used for lateral signs near the pit lane).
func _nearest_pose(point: Vector3) -> Transform3D:
	var best: float = INF
	var best_pose := Transform3D.IDENTITY
	var s: float = 0.0
	# The pit lane lies on the last and first 600 m of the lap.
	var arcs: Array[float] = []
	var k: float = 3700.0
	while k < world.ribbon.length_m + 500.0:
		arcs.append(k)
		k += 3.0
	for arc: float in arcs:
		var pose: Transform3D = world.ribbon.get_point_at_offset(arc, 0.0)
		var d: float = Vector2(pose.origin.x - point.x, pose.origin.z - point.z).length()
		if d < best:
			best = d
			best_pose = pose
		s = arc
	return best_pose


# --- pit wall -----------------------------------------------------------------------------------

func _test_pit_wall() -> void:
	var pit: Node3D = world.pit_lane
	var poses: Array = array_of(pit, "wall_poses")
	var arcs: Array = array_of(pit, "wall_arcs")
	var inside_lane: int = 0
	var in_verge: int = 0
	var worst_gap: float = 0.0
	var previous: Vector3 = Vector3.ZERO
	var half: float = const_of("LANE_HALF_WIDTH_M")
	for index: int in range(mini(poses.size(), arcs.size())):
		var pose: Transform3D = poses[index]
		var u: float = fposmod(float(arcs[index]) - PitLaneScript.ENTRY_S, world.ribbon.length_m)
		var lateral: float = (pose.origin - world.ribbon.get_point_at_offset(float(arcs[index]), 0.0).origin).dot(world.ribbon.get_point_at_offset(float(arcs[index]), 0.0).basis.x)
		var lane_left: float = pit.lane_edges(u).x if pit.has_method("lane_edges") else INF
		if lateral > lane_left - 0.25:
			inside_lane += 1
		if lateral > world.ribbon.road_half_width_m + 0.9 and lateral < lane_left - 0.25:
			in_verge += 1
		if index > 0:
			worst_gap = maxf(worst_gap, pose.origin.distance_to(previous))
		previous = pose.origin
	check(poses.size() > 60 and inside_lane == 0 and in_verge == poses.size() and worst_gap <= 3.6,
		"#W1 the %d wall pieces all stand in the verge between track and fast lane (none in a lane: %d), end to end (largest gap %.1f m)" % [poses.size(), inside_lane, worst_gap])
	var ends: Array = array_of(pit, "wall_end_cushions")
	check(ends.size() == 2, "#W2 the wall starts and ends in a crash cushion so a car entering or leaving does not meet a blunt end (%d cushions)" % ends.size())


# --- markings ----------------------------------------------------------------------------------

func _test_markings() -> void:
	var pit: Node3D = world.pit_lane
	var boxes: Array = array_of(pit, "stall_markings")
	var ok: bool = boxes.size() == PitLaneScript.TEAM_COUNT
	for index: int in range(boxes.size()):
		var marking: Dictionary = boxes[index]
		ok = ok and int(marking["number"]) == index + 1 and is_equal_approx(float(marking["lateral"]), const_of("STALL_LANE_M")) \
			and float(marking["half_width"]) >= CAR_HALF_WIDTH_M + 0.45 and float(marking["length"]) >= 2.0 * CAR_HALF_LENGTH_M + 1.2
	check(ok, "#M1 every one of the 10 pit boxes is painted and numbered, wider and longer than a car (%d painted)" % boxes.size())
	var separators: int = int(prop(pit, "lane_separator_count")) if pit != null and prop(pit, "lane_separator_count") != null else 0
	check(separators >= 1 and pit.get_node_or_null("PitMarkings") != null, "#M2 a painted line separates the fast lane from the working lane in front of the boxes")


# --- equipment -----------------------------------------------------------------------------------

func _test_garage_equipment() -> void:
	var pit: Node3D = world.pit_lane
	var equipment: Array = array_of(pit, "garage_equipment")
	var ok: bool = equipment.size() == PitLaneScript.TEAM_COUNT
	var detail: String = ""
	for entry: Dictionary in equipment:
		ok = ok and int(entry.get("tyre_stacks", 0)) == 4 and int(entry.get("wheel_guns", 0)) >= 4 and int(entry.get("jacks", 0)) >= 2 \
			and int(entry.get("fuel_rigs", 0)) == 1 and int(entry.get("extinguishers", 0)) >= 1 and int(entry.get("monitors", 0)) >= 3 and int(entry.get("light_bars", 0)) >= 3
		detail = str(entry)
	check(ok, "#E1 every garage holds four tyre stacks, wheel guns, two jacks, a fuel rig, an extinguisher, a monitor desk and its lights (%s)" % detail)


# --- crew -----------------------------------------------------------------------------------------

func _test_standby_crew() -> void:
	var choreographer: PitstopChoreographer = world.choreographer
	var roster: Dictionary = {}
	if choreographer != null and choreographer.get_script().get_script_constant_map().has("ROSTER"):
		roster = choreographer.get_script().get_script_constant_map()["ROSTER"]
	var total: int = 0
	for role: String in roster:
		total += int(roster[role])
	var garages_ok: bool = world.pit_lane.garages.size() == PitLaneScript.TEAM_COUNT
	for garage: Node3D in world.pit_lane.garages:
		var standby := garage.get_node_or_null("StandbyCrew") as MeshInstance3D
		garages_ok = garages_ok and standby != null and standby.visible
	check(total == 13 and int(roster.get("gunner", 0)) == 4 and int(roster.get("handler", 0)) == 4 and int(roster.get("jack", 0)) == 2
		and int(roster.get("fueler", 0)) == 1 and int(roster.get("fire", 0)) == 1 and int(roster.get("lollipop", 0)) == 1 and garages_ok,
		"#C1 a full crew of %d (4 gunners, 4 tyre handlers, 2 jack men, fueler, fire marshal, lollipop) stands by in every garage" % total)


func _test_crew_cycle() -> void:
	var choreographer: PitstopChoreographer = world.choreographer
	if not choreographer.has_method("set_ready_teams"):
		check(false, "#C2 with its car on the way the team steps out of the garage and waits ready in the working lane")
		check(false, "#C3 once the car has gone the crew walks back into its garage")
		return
	var team: int = 4
	var stall: Transform3D = world.pit_lane.stall_transform(team)
	choreographer.call("set_ready_teams", [team])
	for _step: int in range(240):
		choreographer.call("advance", FRAME * 2.0)
	var state: int = int(choreographer.call("crew_state", team)) if choreographer.has_method("crew_state") else -1
	var members: Array = choreographer.call("crew_nodes", team) if choreographer.has_method("crew_nodes") else []
	var zones_ok: bool = members.size() == 13
	var closest_to_box: float = INF
	var lane_right: float = const_of("FAST_LANE_M") + const_of("LANE_HALF_WIDTH_M")
	var fascia: float = const_of("GARAGE_FRONT_M") - 0.55
	for member: Node3D in members:
		var local: Vector3 = stall.affine_inverse() * member.global_position
		var lateral: float = const_of("STALL_LANE_M") + local.x
		zones_ok = zones_ok and lateral >= lane_right + 0.2 and lateral <= fascia - 0.1
		# No one stands where the box car will be.
		var inside_box: bool = absf(local.x) < CAR_HALF_WIDTH_M + 0.1 and absf(local.z) < CAR_HALF_LENGTH_M + 0.1
		zones_ok = zones_ok and not inside_box
		closest_to_box = minf(closest_to_box, maxf(absf(local.x) - CAR_HALF_WIDTH_M, absf(local.z) - CAR_HALF_LENGTH_M))
	var garage: Node3D = world.pit_lane.garages[team]
	var standby := garage.get_node_or_null("StandbyCrew") as MeshInstance3D
	check(state == 2 and zones_ok and standby != null and not standby.visible,
		"#C2 with its car on the way the team steps out of the garage and waits ready in the working lane: state %d, 13 members clear of the fast lane (%.2f m from the box car at the closest), standby set hidden" % [state, closest_to_box])
	# Dismissed: everyone walks back, the animated crew is freed and the garage shows its standing crew again.
	choreographer.call("set_ready_teams", [])
	for _step: int in range(300):
		choreographer.call("advance", FRAME * 2.0)
	var after: int = int(choreographer.call("crew_state", team)) if choreographer.has_method("crew_state") else -1
	var left_over: Array = choreographer.call("crew_nodes", team) if choreographer.has_method("crew_nodes") else [null]
	check(after == 0 and left_over.is_empty() and standby != null and standby.visible,
		"#C3 once the car has gone the crew walks back into its garage (state %d, %d animated members left, standby set shown again)" % [after, left_over.size()])


## A real stop in the world: the crew waits out of the way of the car pulling into its box, then steps in to its
## wheels once the car has stopped.
func _test_stop_in_the_world() -> void:
	var race: GtRace = world.race
	race.incidents_enabled = false
	world.director._enter(DirectorScript.State.GREEN_RACING)
	var car: GtCar = null
	for candidate: GtCar in race.cars:
		if candidate.team_id == 6:
			car = candidate
			break
	for other: GtCar in race.cars:
		other.s = 600.0 + 30.0 * float(other.id)
		other.prev_s = other.s
		other.v = 40.0
		other.lap = 1
	car.s = PitLaneScript.ENTRY_S - 380.0
	car.prev_s = car.s
	car.v = 55.0
	car.lateral = 0.0
	car.prev_lateral = 0.0
	car.target_lateral = 0.0
	car.lap = 1
	world.request_pit(car.id)
	var choreographer: PitstopChoreographer = world.choreographer
	var actor: Node3D = world.actor_of(car.id)
	var closest: float = INF
	var sampled: int = 0
	var waiting_out: bool = false
	var near_wheels: int = 0
	var stepped_in: bool = false
	var work_seen_at: float = -1.0
	var distances: Array[float] = []
	var min_lane_lateral: float = INF
	var exit_lateral: float = NAN
	for frame: int in range(60 * 70):
		world.step(FRAME)
		var job: PitstopChoreographer.Job = choreographer.get_job(car.id)
		if car.pit != null and (car.pit.phase == Types.PitPhase.IN or car.pit.phase == Types.PitPhase.EXIT):
			min_lane_lateral = minf(min_lane_lateral, car.lateral)
		if car.pit == null and stepped_in:
			exit_lateral = car.lateral
		if job == null and car.pit != null and car.pit.phase != Types.PitPhase.OUT and car.pit.phase != Types.PitPhase.EXIT and choreographer.crew_state(6) == 2 and car.v > 0.5:
			waiting_out = true
			for member: Node3D in choreographer.crew_nodes(6):
				var local: Vector3 = actor.global_transform.affine_inverse() * member.global_position
				var gap: float = Vector2(maxf(absf(local.x) - CAR_HALF_WIDTH_M, 0.0), maxf(absf(local.z) - CAR_HALF_LENGTH_M, 0.0)).length()
				closest = minf(closest, gap)
			sampled += 1
		if job != null and job.phase == PitstopChoreographer.Phase.SERVICING:
			if work_seen_at < 0.0:
				work_seen_at = float(frame) * FRAME
			if float(frame) * FRAME - work_seen_at > 1.0 and not stepped_in:
				stepped_in = true
				var sockets: Array = [job.chassis.socket_wheel_fl, job.chassis.socket_wheel_fr, job.chassis.socket_wheel_rl, job.chassis.socket_wheel_rr]
				for corner: int in range(4):
					var wheel: Vector3 = (sockets[corner] as Node3D).global_position
					var gunner: Vector3 = job.crew_members[corner].global_position
					var apart: float = Vector2(wheel.x - gunner.x, wheel.z - gunner.z).length()
					distances.append(snappedf(apart, 0.01))
					if apart <= 1.9:
						near_wheels += 1
		if stepped_in and car.pit == null:
			break
	check(waiting_out and sampled > 20 and closest >= 0.15,
		"#C4 while the car pulls into its box the waiting crew keeps clear of it (%d frames sampled, closest gap %.2f m, body radius 0.25 m)" % [sampled, closest])
	check(stepped_in and near_wheels == 4,
		"#C5 once the car has stopped each wheel-gun mechanic has stepped in beside his wheel (%d of 4 within 1.9 m: %s)" % [near_wheels, str(distances)])
	check(min_lane_lateral >= 4.6 and absf(exit_lateral - PitLaneScript.EDGE_LATERAL_M) < 0.9,
		"#C6 the car drives the lane off the right half of the circuit and rejoins there, never across the racing line (lowest lateral in the lane %.2f m, %.2f m when it rejoins)" % [min_lane_lateral, exit_lateral])
