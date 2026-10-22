extends SceneTree

## Run: Godot --headless --fixed-fps 60 --path . --script res://tests/test_race_world.gd
## --fixed-fps makes every physics frame exactly 1/60 s and removes real-time
## pacing, so each time scale advances the sim by a whole number of ticks/frame.

const WorldScene := preload("res://scenes/test_race_world.tscn")
const TrackScene := preload("res://scenes/race_world/track_circuit.tscn")
const ActorScript := preload("res://scripts/car/kinematic_car_actor.gd")
const RibbonScript := preload("res://scripts/car/track_ribbon.gd")

const SCALES: Array[float] = [1.0, 2.0, 4.0, 8.0, 16.0]
const SIM_TICKS: int = 60 * 300
const HALF_LENGTH_M: float = 2.3
const HALF_WIDTH_M: float = 1.0
## Boxes may touch; deeper than this counts as one car driving through another.
const MAX_PENETRATION_M: float = 0.05
const SWEEP_SAMPLES: int = 4

var failures: int = 0


func _initialize() -> void:
	call_deferred("_run")


func check(ok: bool, description: String) -> void:
	if not ok:
		failures += 1
		push_error(description)
	print("[%s] %s" % ["PASS" if ok else "FAIL", description])


func _run() -> void:
	check(Engine.physics_ticks_per_second == 60, "physics runs at 60 Hz")
	_test_ribbon()
	var reference: Array[float] = []
	for scale: float in SCALES:
		var result: Dictionary = await _run_race(scale)
		var label: String = "%dx" % int(scale)
		check(result.ticks == SIM_TICKS, "%s: stopped at exactly %d sim ticks" % [label, SIM_TICKS])
		check(result.overlap_frames == 0, "%s: no car box overlaps another (worst %.3f m, %d frames)" % [
			label, result.max_penetration, result.overlap_frames
		])
		check(result.overtakes >= 5, "%s: cars overtake each other (%d passes)" % [label, result.overtakes])
		check(result.front_contacts > 0, "%s: front sensors detect cars (%d sensor-frames)" % [label, result.front_contacts])
		print("    (%s: %d side-sensor vetoes)" % [label, result.vetoes])
		check(result.overtaking_frames > 0, "%s: front sensor flags a faster car closing on a slower one (%d car-frames)" % [label, result.overtaking_frames])
		check(result.shift_frames > 0, "%s: cars shift lanes (%d car-frames)" % [label, result.shift_frames])
		check(result.max_lane_rate <= ActorScript.LANE_MAX_RATE + 1e-4, "%s: lane shift rate <= %.1f lanes/s (peak %.3f)" % [
			label, ActorScript.LANE_MAX_RATE, result.max_lane_rate
		])
		check(result.max_speed_3d <= 100.0, "%s: no teleport, peak %.1f m/s of world motion" % [label, result.max_speed_3d])
		if scale == 1.0:
			reference = result.distances
		else:
			check(result.distances == reference, "%s: final car positions identical to 1x" % label)
	print("%s (%d failure(s))" % ["ALL PASS" if failures == 0 else "FAILED", failures])
	quit(1 if failures > 0 else 0)


func _test_ribbon() -> void:
	var track: RibbonScript = TrackScene.instantiate()
	root.add_child(track)
	var length: float = track.length_m
	check(length > 3500.0 and length < 4500.0, "circuit is a ~4 km loop (%.0f m)" % length)
	var start: Transform3D = track.get_point_on_ribbon(0.0, 1)
	var wrapped: Transform3D = track.get_point_on_ribbon(length, 1)
	check(start.origin.distance_to(wrapped.origin) < 0.05, "loop closes: distance 0 == distance length")
	check(is_equal_approx(track.get_point_on_ribbon(123.0, 1).origin.distance_to(track.get_point_on_ribbon(123.0 + length, 1).origin), 0.0), "distance wraps around the lap")
	var inside: Transform3D = track.get_point_on_ribbon(500.0, 0)
	var line: Transform3D = track.get_point_on_ribbon(500.0, 1)
	var outside: Transform3D = track.get_point_on_ribbon(500.0, 2)
	check(is_equal_approx(inside.origin.distance_to(line.origin), 2.5), "lane 0 is 2.5 m from the racing line")
	check(is_equal_approx(outside.origin.distance_to(line.origin), 2.5), "lane 2 is 2.5 m from the racing line")
	check(absf((inside.origin - line.origin).dot(line.basis.z)) < 1e-3, "lane offset is perpendicular to travel")
	check((outside.origin - line.origin).dot(line.basis.x) > 2.4, "lane 2 is right of travel, lane 0 left")
	var turn: float = 0.0
	var tightest: float = INF
	for i: int in range(int(length)):
		turn += track.get_curvature_at(float(i))
		tightest = minf(tightest, track.get_radius_at(float(i)))
	check(absf(turn - TAU) < 0.15, "integrated curvature is one full left turn (%.3f rad)" % turn)
	check(tightest > 30.0 and tightest < 42.0, "tightest corner radius ~35 m (%.1f m)" % tightest)
	check(track.get_radius_at(500.0) >= RibbonScript.STRAIGHT_RADIUS_M - 1.0, "start straight reports a straight")
	track.free()


func _run_race(scale: float) -> Dictionary:
	var world: Node3D = WorldScene.instantiate()
	root.add_child(world)
	world.set_time_scale(scale)
	var actors: Array = world.actors
	var count: int = actors.size()
	check(count == 20, "%dx: 20 car actors spawned" % int(scale))
	var sensors_ok: bool = true
	for actor in actors:
		sensors_ok = sensors_ok and actor.front_sensor.target_position.is_equal_approx(Vector3(0, 0, -14)) \
			and actor.left_sensor.target_position.is_equal_approx(Vector3(-3, 0, 0)) \
			and actor.right_sensor.target_position.is_equal_approx(Vector3(3, 0, 0))
	check(sensors_ok, "%dx: sensors are front 14 m, left 3 m, right 3 m" % int(scale))

	var result := {
		"ticks": 0, "overlap_frames": 0, "max_penetration": 0.0, "overtakes": 0,
		"front_contacts": 0, "overtaking_frames": 0, "shift_frames": 0, "vetoes": 0, "max_lane_rate": 0.0,
		"max_speed_3d": 0.0, "distances": [] as Array[float],
	}
	var delta: float = 1.0 / 60.0
	var sim_dt: float = delta * scale
	var previous: Array[Transform3D] = []
	var ahead: Dictionary = {}
	for actor in actors:
		previous.append(actor.global_transform)
	while world.engine.tick_count < SIM_TICKS:
		await physics_frame
		var overlapped: bool = false
		var poses: Array[Transform3D] = []
		for i: int in range(count):
			poses.append(actors[i].global_transform)
		for i: int in range(count):
			var actor = actors[i]
			result.front_contacts += 1 if actor._front_actor != null else 0
			result.max_lane_rate = maxf(result.max_lane_rate, absf(actor.lane_velocity))
			result.overtaking_frames += 1 if actor.is_overtaking else 0
			result.shift_frames += 1 if absf(actor.lane_velocity) > 0.1 else 0
			var moved: float = poses[i].origin.distance_to(previous[i].origin)
			result.max_speed_3d = maxf(result.max_speed_3d, moved / sim_dt)
			for j: int in range(i + 1, count):
				var depth: float = _swept_penetration(previous[i], poses[i], previous[j], poses[j])
				if depth > MAX_PENETRATION_M:
					overlapped = true
					result.max_penetration = maxf(result.max_penetration, depth)
		if overlapped:
			result.overlap_frames += 1
		result.overtakes += _count_overtakes(world.engine, ahead)
		previous = poses
	result.ticks = world.engine.tick_count
	for actor in actors:
		result.vetoes += actor.veto_count
	for car in world.engine.cars:
		result.distances.append(car.total_distance)
	world.queue_free()
	await process_frame
	return result


## Counts passes: a pair swaps order and ends up more than one car length apart.
## The hysteresis ignores cars drawing level and falling back.
func _count_overtakes(engine, ahead: Dictionary) -> int:
	var cars: Array = engine.cars
	var flips: int = 0
	for i: int in range(cars.size()):
		for j: int in range(i + 1, cars.size()):
			var gap: float = cars[i].total_distance - cars[j].total_distance
			if absf(gap) <= engine.contact_gap_m:
				continue
			var key: int = i * cars.size() + j
			if ahead.has(key) and ahead[key] != (gap > 0.0):
				flips += 1
			ahead[key] = gap > 0.0
	return flips


## Deepest box overlap between two cars at any of several poses between frames,
## so a fast pass cannot hide between two samples.
func _swept_penetration(a0: Transform3D, a1: Transform3D, b0: Transform3D, b1: Transform3D) -> float:
	var reach: float = 2.0 * HALF_LENGTH_M + a0.origin.distance_to(a1.origin) + b0.origin.distance_to(b1.origin)
	if a1.origin.distance_squared_to(b1.origin) > reach * reach:
		return 0.0
	var worst: float = 0.0
	for s: int in range(1, SWEEP_SAMPLES + 1):
		var t: float = float(s) / float(SWEEP_SAMPLES)
		worst = maxf(worst, _penetration(a0.interpolate_with(a1, t), b0.interpolate_with(b1, t)))
	return worst


## 2D separating-axis test on the ground plane; 0 when apart, else the depth.
func _penetration(a: Transform3D, b: Transform3D) -> float:
	var fa := Vector2(a.basis.z.x, a.basis.z.z).normalized()
	var ra := Vector2(a.basis.x.x, a.basis.x.z).normalized()
	var fb := Vector2(b.basis.z.x, b.basis.z.z).normalized()
	var rb := Vector2(b.basis.x.x, b.basis.x.z).normalized()
	var d := Vector2(b.origin.x - a.origin.x, b.origin.z - a.origin.z)
	var depth: float = INF
	for axis: Vector2 in [fa, ra, fb, rb]:
		var extent_a: float = absf(fa.dot(axis)) * HALF_LENGTH_M + absf(ra.dot(axis)) * HALF_WIDTH_M
		var extent_b: float = absf(fb.dot(axis)) * HALF_LENGTH_M + absf(rb.dot(axis)) * HALF_WIDTH_M
		var overlap: float = extent_a + extent_b - absf(d.dot(axis))
		if overlap <= 0.0:
			return 0.0
		depth = minf(depth, overlap)
	return depth
