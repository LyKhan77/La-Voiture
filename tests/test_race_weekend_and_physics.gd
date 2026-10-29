extends SceneTree

## FASE 5.5 acceptance (re-based on the GT sim in FASE 5.6): adaptive racing line, 190-pair
## match collider and FIA rules, the five red lights, the pit lane with its crew, the
## trackside set, the master car assembly and the weekend world.
## Numbers in the descriptions (#1..#25) are the TASK-FASE-5.5 acceptance list.
## Run: Godot --headless --path . -s res://tests/test_race_weekend_and_physics.gd
## Add `-- --skip-legacy` to skip the older suites in #25 (the race-world one alone
## takes about 70 seconds).

const WorldScene := preload("res://scenes/race_weekend_world.tscn")
const TrackScene := preload("res://scenes/race_world/track_circuit.tscn")
const RibbonScript := preload("res://scripts/car/track_ribbon.gd")
const ActorScript := preload("res://scripts/car/gt_car_actor.gd")
const LineScript := preload("res://scripts/car/adaptive_racing_line.gd")
const DirectorScript := preload("res://scripts/world/weekend/race_weekend_director.gd")
const ChoreographerScript := preload("res://scripts/car/pitstop_choreographer.gd")
const PitLaneScript := preload("res://scripts/world/circuits/apex_ring/apex_pit_complex.gd")
const CarScript := preload("res://scripts/gt/gt_car.gd")
const RaceScript := preload("res://scripts/gt/gt_race.gd")
const TrackScript := preload("res://scripts/gt/gt_track.gd")
const ContactsScript := preload("res://scripts/gt/gt_contacts.gd")
const WeatherScript := preload("res://scripts/gt/gt_weather.gd")
const Types := preload("res://scripts/gt/gt_types.gd")
const WheelScript := preload("res://scripts/car/wheel_controller.gd")
const ToonMaterialsScript := preload("res://scripts/world/shared/toon_materials.gd")

const FRAME: float = 1.0 / 60.0
const RACE_TICKS: int = 3600
## Car box used for the geometric overlap test: the collider envelope.
const HALF_LENGTH_M: float = 2.225
const HALF_WIDTH_M: float = 1.04
const OVERLAP_DEPTH_M: float = 0.05

const LEGACY_SUITES: Array[Dictionary] = [
	{"script": "test_modular_car", "args": []},
	{"script": "test_simulation_verification", "args": []},
	{"script": "test_pit_wall", "args": []},
	{"script": "test_weather_and_ai", "args": []},
	{"script": "test_race_world", "args": ["--fixed-fps", "60"]},
	{"script": "test_gt_sim", "args": []},
	{"script": "test_car_dynamics_vfx", "args": []},
	{"script": "test_race_hud", "args": []},
]

var failures: int = 0
var assertions: int = 0
var skip_legacy: bool = false
var ribbon: RibbonScript
var gt_track: TrackScript


func _initialize() -> void:
	skip_legacy = OS.get_cmdline_user_args().has("--skip-legacy")
	call_deferred("_run")


func check(ok: bool, description: String) -> void:
	assertions += 1
	if not ok:
		failures += 1
		push_error(description)
	print("[%s] %s" % ["PASS" if ok else "FAIL", description])


func _run() -> void:
	ribbon = TrackScene.instantiate()
	ribbon.road_half_width_m = 7.0
	root.add_child(ribbon)
	gt_track = TrackScript.new(ribbon, 14.0)
	_test_racing_line()
	_test_collider_and_rules()
	await _test_race_weekend_world()
	await _test_dense_race()
	await _test_pit_in_world()
	ribbon.queue_free()
	await process_frame
	# Static material caches would otherwise still be alive when the engine shuts down.
	ToonMaterialsScript._cache.clear()
	ActorScript._paint_cache.clear()
	_test_legacy_suites()
	print("%d assertions, %d failure(s)" % [assertions, failures])
	print("FASE 5.5 ACCEPTANCE: %s" % ("PASS" if failures == 0 else "%d FAILURES" % failures))
	quit(0 if failures == 0 else 1)


# --- #1..#4 adaptive racing line -------------------------------------------

func _test_racing_line() -> void:
	var line: LineScript = gt_track.line
	var corner_s: float = 0.0
	var corner_kappa: float = 0.0
	var s: float = 0.0
	while s < ribbon.length_m:
		var kappa: float = line.curvature_at(s)
		if absf(kappa) > absf(corner_kappa):
			corner_kappa = kappa
			corner_s = s
		s += 2.0
	var straight_s: float = 500.0
	check(absf(line.curvature_at(straight_s)) < 1.0e-4 and absf(corner_kappa) > 0.02,
		"#1 kappa is ~0 on the start straight (%.5f) and non-zero in the tightest corner (%.4f)" % [line.curvature_at(straight_s), corner_kappa])
	var left := Vector3(-0.2, 0.0, -1.0).normalized()
	var right := Vector3(0.2, 0.0, -1.0).normalized()
	var ahead := Vector3(0.0, 0.0, -1.0)
	check(LineScript.signed_curvature(ahead, right, 6.0) > 0.0 and LineScript.signed_curvature(ahead, left, 6.0) < 0.0
		and is_equal_approx(LineScript.signed_curvature(ahead, right, 6.0), -LineScript.signed_curvature(ahead, left, 6.0)),
		"#1 kappa = (t1 x t0).y / ds is signed: + for a right turn, - for a left turn")

	var inside_target: float = line.target_offset(corner_s)
	var expected: float = clampf((0.4 * line.curvature_at(corner_s) + 0.6 * line.curvature_at(corner_s + 25.0)) * 180.0, -3.2, 3.2)
	var entry_s: float = corner_s - 40.0
	var found_entry: bool = false
	while entry_s < corner_s:
		if absf(line.curvature_at(entry_s)) < 0.003 and absf(line.target_offset(entry_s)) > 0.5:
			found_entry = true
			break
		entry_s += 1.0
	check(is_equal_approx(inside_target, expected) and signf(inside_target) == signf(corner_kappa) and absf(inside_target) > 2.0 and absf(inside_target) <= 3.2
		and absf(line.target_offset(straight_s)) < 0.05 and found_entry and is_equal_approx(LineScript.step_offset(0.0, 3.2, 1.0), 1.8),
		"#2 d_target hugs the inside of the apex (%.2f m, clamp 3.2), starts 25 m early, is 0 on the straight, lateral rate 1.8 m/s" % inside_target)

	var worst_excess: float = -INF
	s = 0.0
	while s < ribbon.length_m:
		worst_excess = maxf(worst_excess, line.speed_cap_at(s, 1.0) - line.corner_limit_at(s, 1.0))
		s += 1.0
	var limit: float = LineScript.corner_limit_for(1.0 / 35.0, 1.0)
	check(worst_excess <= 1.0e-3 and is_equal_approx(limit, sqrt(LineScript.BASE_LATERAL_MU * LineScript.GRAVITY * 35.0)),
		"#3 the braking envelope never exceeds v_limit = sqrt(mu g / |kappa|) anywhere on the lap (worst %+.4f m/s; 35 m radius = %.1f m/s)" % [worst_excess, limit])

	var braking_start_for: Callable = func(mu_scale: float) -> float:
		var first: float = INF
		var t: float = 300.0
		while t < corner_s:
			if line.speed_cap_at(t, mu_scale) < 70.0:
				first = t
				break
			t += 1.0
		return first
	var start_dry: float = braking_start_for.call(1.0)
	var start_wet: float = braking_start_for.call(0.45)
	var distance_dry: float = line.braking_point_ahead(corner_s - 400.0, 70.0, 1.0)
	var distance_wet: float = line.braking_point_ahead(corner_s - 400.0, 70.0, 0.45)
	check(start_wet < start_dry and LineScript.braking_distance(70.0, 25.0, 0.45) > LineScript.braking_distance(70.0, 25.0, 1.0) and distance_wet < distance_dry,
		"#4 braking starts earlier on low grip: wet at s=%.0f vs dry at s=%.0f, %.0f m vs %.0f m after a fixed point" % [start_wet, start_dry, distance_wet, distance_dry])


# --- #5..#7, #9..#11 contacts and FIA rules on the GT sim ------------------------

func _quiet_race(seed_value: int = 5) -> RaceScript:
	var race := RaceScript.new(gt_track, 10, seed_value, WeatherScript.Archetype.DRY_SUNNY)
	race.incidents_enabled = false
	return race


func _park_others(race: RaceScript, keep: Array) -> void:
	for index: int in range(race.cars.size()):
		if not keep.has(race.cars[index]):
			race.cars[index].s = -400.0 - float(index) * 30.0
			race.cars[index].prev_s = race.cars[index].s


func _place(car: CarScript, s: float, v: float, lateral: float, lap: int = 1) -> void:
	car.s = s
	car.prev_s = s
	car.v = v
	car.lateral = lateral
	car.prev_lateral = lateral
	car.target_lateral = lateral
	car.lap = lap


func _test_collider_and_rules() -> void:
	var race := _quiet_race()
	for car: CarScript in race.cars:
		_place(car, 100.0 + float(car.position) * 30.0, 40.0, float(car.position % 3 - 1) * 2.5)
	race.step()
	check(race.cars.size() == 20 and race.contacts.pairs_checked_last == 190,
		"#5 all 20 x 19 / 2 = 190 pairs are checked by the match collider every tick (%d)" % race.contacts.pairs_checked_last)
	race.dispose()

	var length_m: float = gt_track.length
	var across: float = ContactsScript.signed_gap(length_m - 1.0, 2.0, length_m)
	race = _quiet_race()
	var a: CarScript = race.cars[0]
	var b: CarScript = race.cars[1]
	_park_others(race, [a, b])
	_place(a, length_m - 1.0, 45.0, 0.0)
	_place(b, 2.0 + length_m, 45.0, 0.05, 2)
	race.step()
	check(is_equal_approx(absf(across), 3.0) and is_equal_approx(ContactsScript.signed_gap(10.0, length_m - 10.0, length_m), 20.0)
		and race.contacts.contacts_last == 1,
		"#6 cyclic gap across the start/finish line: cars at L-1 and 2 are %.1f m apart and touch; 10 vs L-10 is 20 m" % absf(across))
	race.dispose()

	race = _quiet_race()
	a = race.cars[0]
	b = race.cars[1]
	_park_others(race, [a, b])
	_place(a, 300.0, 45.0, 0.5)
	_place(b, 301.0, 45.0, 0.6)
	var before: float = absf(a.lateral - b.lateral)
	race.step()
	var pushed: float = absf(a.lateral - b.lateral)
	var outside := _quiet_race()
	_park_others(outside, [outside.cars[0], outside.cars[1]])
	_place(outside.cars[0], 300.0, 45.0, 0.0)
	_place(outside.cars[1], 306.0, 45.0, 0.0)
	outside.step()
	check(pushed > before and pushed >= 2.0 and a.impact_jolt > 0.0 and outside.contacts.contacts_last == 0,
		"#7 lateral repulsion acts inside the 4.45 x 2.08 m envelope (%.2f -> %.2f m apart, jolt %.2f) and not outside it" % [before, pushed, a.impact_jolt])
	race.dispose()
	outside.dispose()

	# #9 one move: a faster car closing from behind gets ONE defensive line, held.
	race = _quiet_race(23)
	a = race.cars[0]
	b = race.cars[1]
	_park_others(race, [a, b])
	_place(a, 300.0, 50.0, 0.0)
	_place(b, 290.0, 56.0, 0.0)
	race.step()
	var first_target: float = a.defend_target_lateral
	var first_timer: float = a.defend_timer
	for _i: int in range(10):
		race.step()
	check(first_timer > 3.0 and a.overtake_phase == Types.Overtake.DEFENDING and is_equal_approx(a.defend_target_lateral, first_target),
		"#9 one-move defending: the car being caught commits to ONE line (%.2f m) and holds it" % first_target)
	race.dispose()

	# #10 racing room: alongside, the targets stay one car plus a margin apart.
	race = _quiet_race(22)
	a = race.cars[0]
	b = race.cars[1]
	_park_others(race, [a, b])
	_place(a, 420.0, 48.0, -1.2)
	_place(b, 419.2, 48.0, 1.2)
	race.step()
	var room: float = absf(a.target_lateral - b.target_lateral)
	check(room >= 2.1, "#10 racing room: a car alongside is left %.2f m between the lines (a car is 2.08 m wide)" % room)
	race.dispose()

	# #11 blue flag: the lapped car leaves the line and eases off.
	race = _quiet_race(24)
	a = race.cars[0]
	b = race.cars[1]
	_park_others(race, [a, b])
	_place(a, 800.0, 60.0, 0.0, 1)
	_place(b, 800.0 + length_m - 10.0, 62.0, 0.0, 2)
	for _i: int in range(40):
		race.step()
	# The same car with the leader far away keeps its pace: the flagged one is slower.
	var control := _quiet_race(24)
	_park_others(control, [control.cars[0]])
	_place(control.cars[0], 800.0, 60.0, 0.0, 1)
	for _i: int in range(40):
		control.step()
	check(a.overtake_phase == Types.Overtake.YIELDING and absf(a.target_lateral) > 2.0 and a.v < control.cars[0].v,
		"#11 blue flag: a lapped car with the leader 10 m behind leaves the racing line (target %.1f m) and is slower than its unflagged twin (%.0f vs %.0f km/h)" % [
			a.target_lateral, a.v * 3.6, control.cars[0].v * 3.6
		])
	race.dispose()
	control.dispose()


# --- #8, #12..#15, #21..#24, #26 the world ----------------------------------------

func _test_race_weekend_world() -> void:
	var world: Node3D = WorldScene.instantiate()
	root.add_child(world)
	world.set_process(false)
	_test_grid_and_set(world)
	await _test_start_sequence(world)
	await _test_race_run(world)
	_test_wheels_and_brakes(world)
	_test_broadcast_cameras(world)
	world.race.dispose()
	world.queue_free()
	await process_frame


func _test_grid_and_set(world: Node3D) -> void:
	var cars: Array = world.race.cars
	var alternating: bool = true
	var ordered: bool = true
	var overlap: bool = false
	for index: int in range(cars.size()):
		alternating = alternating and is_equal_approx(cars[index].lateral, -2.5 if index % 2 == 0 else 2.5)
		ordered = ordered and is_equal_approx(cars[index].s, -8.0 - 8.0 * float(index))
		for other: int in range(index + 1, cars.size()):
			overlap = overlap or _penetration(world.actors[index].global_transform, world.actors[other].global_transform) > OVERLAP_DEPTH_M
	check(cars.size() == 20 and alternating and ordered and not overlap,
		"#12 the 20-car grid is lined up in staggered columns (+-2.5 m, 8 m rows) with nobody overlapping")

	var kerb_ok: bool = world.environment.kerbs.size() >= 3
	var surfaces: int = world.environment.kerb_instance.mesh.get_surface_count()
	var red_ok: bool = false
	var white_ok: bool = false
	for index: int in range(surfaces):
		var material := world.environment.kerb_instance.mesh.surface_get_material(index) as ShaderMaterial
		var color: Color = material.get_shader_parameter("base_color")
		red_ok = red_ok or color.is_equal_approx(world.environment.RED)
		white_ok = white_ok or color.is_equal_approx(world.environment.WHITE)
	var inside_ok: bool = true
	var arrays: Array = world.environment.kerb_instance.mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	for kerb: Dictionary in world.environment.kerbs:
		var mid: float = (float(kerb["s0"]) + float(kerb["s1"])) * 0.5
		inside_ok = inside_ok and signf(world.track.curvature_at(mid)) == float(kerb["side"])
		var origin: Transform3D = world.ribbon.get_point_at_offset(mid, 0.0)
		var best: float = INF
		var lateral: float = 0.0
		for vertex: Vector3 in vertices:
			var offset: Vector3 = vertex - origin.origin
			if offset.length() < best and absf(offset.dot(origin.basis.z)) < 2.0:
				best = offset.length()
				lateral = offset.dot(origin.basis.x)
		inside_ok = inside_ok and signf(lateral) == float(kerb["side"]) and absf(lateral) > 5.5 and absf(lateral) < 8.5
	check(kerb_ok and surfaces == 2 and red_ok and white_ok and inside_ok and world.environment.armco_post_count > 400 and world.environment.tree_count > 500,
		"#23 %d red-white kerbs sit on the inside of sharp corners, with %d guardrail posts and %d trees" % [
			world.environment.kerbs.size(), world.environment.armco_post_count, world.environment.tree_count
		])

	var gantry: Node3D = world.gantry
	var start: Transform3D = world.ribbon.get_point_on_ribbon(0.0, 1)
	var garages: Array[Node3D] = world.pit_lane.garages
	var garages_ok: bool = garages.size() == 10
	var pitch_ok: bool = true
	for team: int in range(garages.size()):
		var stall: Dictionary = world.pit_lane.stalls[team]
		var expected: Vector3 = world.ribbon.get_point_at_offset(float(stall["s"]), PitLaneScript.GARAGE_FRONT_M).origin
		garages_ok = garages_ok and garages[team].global_position.distance_to(expected) < 0.01 and garages[team].name == "Garage%02d" % (team + 1)
		garages_ok = garages_ok and world.ribbon.get_point_at_offset(float(stall["s"]), 0.0).origin.distance_to(garages[team].global_position) > 15.0
		if team > 0:
			pitch_ok = pitch_ok and is_equal_approx(float(stall["s"]) - float(world.pit_lane.stalls[team - 1]["s"]), PitLaneScript.STALL_PITCH_M)
	var pit_length: float = world.pit_lane.length_m
	check(gantry.global_position.distance_to(start.origin) < 0.01 and gantry.lamps.size() == 10 and gantry.BEAM_HEIGHT_M > 6.0 and gantry.SPAN_M > 2.0 * world.ribbon.road_half_width_m
		and garages_ok and pitch_ok and PitLaneScript.ENTRY_S == 3900.0 and PitLaneScript.EXIT_S == 150.0 and absf(pit_length - 410.0) < 5.0,
		"#24 the gantry (5 pairs of lamps) stands on the start line and the 10 garages along the pit lane (%.1f m, entry 3900, exit 150)" % pit_length)


## #13..#15: lights come on one by one, go out together, nobody moves before.
func _test_start_sequence(world: Node3D) -> void:
	var director: DirectorScript = world.director
	var lit_at: Array[float] = []
	var lit_seen: Array[int] = []
	var on_lit: Callable = func(_count: int) -> void:
		lit_at.append(director.clock_s)
		lit_seen.append(world.gantry.lit_lamp_count())
	director.light_lit.connect(on_lit)
	# Lambdas copy plain locals, so the readings go through a dictionary.
	var out: Dictionary = {"at": -1.0, "lamps": -1}
	var on_out: Callable = func() -> void:
		out["at"] = director.clock_s
		out["lamps"] = world.gantry.lit_lamp_count()
	director.lights_out.connect(on_out)
	var moved_before_out: bool = false
	var frames: int = 0
	while float(out["at"]) < 0.0 and frames < 60 * 20:
		world.step(FRAME)
		frames += 1
		if float(out["at"]) < 0.0:
			for car: CarScript in world.race.cars:
				moved_before_out = moved_before_out or car.v != 0.0 or not is_equal_approx(car.s, car.prev_s)
	var ticks_before_out: int = world.race.tick_count
	var pole: CarScript = world.race.cars[0]
	var pole_start: float = pole.s
	for _frame: int in range(120):
		world.step(FRAME)
	var moved_after_out: bool = pole.s > pole_start + 2.0 and pole.v > 5.0
	director.light_lit.disconnect(on_lit)
	director.lights_out.disconnect(on_out)
	var interval_ok: bool = lit_at.size() == 5
	for index: int in range(lit_at.size()):
		interval_ok = interval_ok and lit_seen[index] == 2 * (index + 1)
		if index > 0:
			interval_ok = interval_ok and absf(lit_at[index] - lit_at[index - 1] - 1.0) < 0.02
	check(interval_ok, "#13 the five red lights come on one pair at a time, 1.0 s apart (%s s)" % [lit_at])
	var holds: Array[float] = []
	for seed_value: int in range(1, 26):
		var probe := DirectorScript.new(seed_value)
		probe.begin_countdown()
		while probe.state != DirectorScript.State.GREEN_RACING:
			probe.advance(0.01)
		holds.append(probe.hold_duration_s)
	var hold_ok: bool = true
	for value: float in holds:
		hold_ok = hold_ok and value >= DirectorScript.HOLD_MIN_S and value <= DirectorScript.HOLD_MAX_S
	var hold_min: float = holds.min()
	var hold_max: float = holds.max()
	check(float(out["at"]) > 0.0 and int(out["lamps"]) == 0 and world.gantry.lit_lamp_count() == 0 and director.state == DirectorScript.State.GREEN_RACING
		and director.lights_on() == 0 and hold_ok and hold_max - hold_min > 0.3 and moved_after_out,
		"#14 all lamps go out at once after a random hold (%.2f..%.2f s over 25 seeds), then the race is on" % [hold_min, hold_max])
	check(not moved_before_out and ticks_before_out == 0,
		"#15 no car moved before lights out: every grid car stayed put and the sim ran %d ticks before the lamps went out" % ticks_before_out)


func _test_race_run(world: Node3D) -> void:
	var race: RaceScript = world.race
	world.set_time_scale(3.0) # one 20 Hz tick per 60 Hz frame
	var worst_excess: float = -INF
	var overlap_frames: int = 0
	var worst_depth: float = 0.0
	var pair_checks: int = 0
	var start_tick: int = race.tick_count
	while race.tick_count - start_tick < RACE_TICKS:
		world.step(FRAME)
		pair_checks += race.contacts.pairs_checked_last
		for car: CarScript in race.cars:
			if car.is_racing():
				worst_excess = maxf(worst_excess, car.v - world.track.speed_limit_at(car.s) * 1.2)
		var frame_overlap: bool = false
		for a: int in range(world.actors.size()):
			if not race.cars[a].is_racing():
				continue
			for b: int in range(a + 1, world.actors.size()):
				if not race.cars[b].is_racing():
					continue
				var depth: float = _penetration(world.actors[a].global_transform, world.actors[b].global_transform)
				if depth > OVERLAP_DEPTH_M:
					frame_overlap = true
					worst_depth = maxf(worst_depth, depth)
		if frame_overlap:
			overlap_frames += 1
	world.set_time_scale(1.0)
	check(worst_excess <= 1.0,
		"#3 in the race every car stays within the grip-adaptive corner profile over %d ticks (worst %+.2f m/s over 1.2 x v_limit)" % [RACE_TICKS, worst_excess])
	check(overlap_frames == 0,
		"#8 zero overlapping boxes over %d ticks of racing: %d frames with a box overlap (worst %.3f m)" % [RACE_TICKS, overlap_frames, worst_depth])
	check(pair_checks >= 190 * RACE_TICKS,
		"#5 the world ran the 190-pair check on every tick (%d pair checks over %d ticks)" % [pair_checks, RACE_TICKS])


## #21 wheels roll with the car, front wheels steer, the caliper stays put; #22 the rotor glows past 1.5 G.
func _test_wheels_and_brakes(world: Node3D) -> void:
	var actor: ActorScript = world.actors[3]
	var car: CarScript = actor.car
	var forward: Vector3 = -actor.global_transform.basis.z
	var rolls_forward: bool = actor.wheel_controllers.size() == 4
	var caliper_still: bool = true
	var speed_matches: bool = true
	for wheel: WheelScript in actor.wheel_controllers:
		var top: Vector3 = wheel.wheel_rotating.global_transform * Vector3(0.0, 0.33, 0.0)
		var caliper_before: Transform3D = wheel.brake_caliper.global_transform
		wheel.set_rolling_speed(30.0)
		speed_matches = speed_matches and is_equal_approx(wheel.angular_speed, 30.0 / wheel.wheel_radius_m)
		wheel._process(0.01)
		var moved: Vector3 = wheel.wheel_rotating.global_transform * Vector3(0.0, 0.33, 0.0) - top
		rolls_forward = rolls_forward and moved.dot(forward) > 0.0
		caliper_still = caliper_still and wheel.brake_caliper.global_transform.is_equal_approx(caliper_before)
		wheel.stop_rotation()
	car.v = 60.0
	actor.present(1.0, FRAME)
	var synced: bool = true
	for wheel: WheelScript in actor.wheel_controllers:
		synced = synced and is_equal_approx(wheel.angular_speed, 60.0 / wheel.wheel_radius_m)
	# Only the front wheels steer: steer right and the front sockets turn, the rear ones do not.
	car.steer_angle = 0.3
	for _i: int in range(30):
		actor.present(1.0, FRAME)
	var steers: bool = absf(actor.chassis.socket_wheel_fl.rotation.y) > 0.2 and absf(actor.chassis.socket_wheel_fr.rotation.y) > 0.2 \
		and actor.chassis.socket_wheel_rl.rotation.y == 0.0 and actor.chassis.socket_wheel_rr.rotation.y == 0.0
	car.steer_angle = 0.0
	check(rolls_forward and caliper_still and speed_matches and synced and steers,
		"#21 all four wheels roll forward with the car (%.1f rad/s at %.0f m/s), only the front pair steers (%.2f rad), the brake caliper stays static" % [
			actor.wheel_controllers[0].angular_speed, 60.0, actor.chassis.socket_wheel_fl.rotation.y
		])

	car.longitudinal_g = 0.0
	for _tick: int in range(240):
		actor.present(1.0, FRAME)
	var cold: bool = actor.brake_glow == 0.0
	var gentle: bool = true
	car.longitudinal_g = -1.4
	for _tick: int in range(30):
		actor.present(1.0, FRAME)
		gentle = gentle and actor.brake_glow == 0.0
	car.longitudinal_g = -3.0
	for _tick: int in range(30):
		actor.present(1.0, FRAME)
	var disc: MeshInstance3D = actor.wheel_controllers[0].brake_disc
	var glowing: bool = actor.brake_glow > 0.5 and disc.material_overlay != null
	var overlay := disc.material_overlay as StandardMaterial3D
	glowing = glowing and overlay.emission_enabled and overlay.emission_energy_multiplier > 1.0
	var peak: float = actor.brake_glow
	car.longitudinal_g = 0.0
	for _tick: int in range(180):
		actor.present(1.0, FRAME)
	check(cold and gentle and glowing and actor.brake_glow == 0.0 and disc.material_overlay == null,
		"#22 the brake disc glows (%.2f) after 3 G braking, stays cold at 1.4 G and cools down again" % peak)


## #26 (beyond the 25): five cameras, C cycles them, the pit camera takes over by itself.
func _test_broadcast_cameras(world: Node3D) -> void:
	var cameras = world.camera_director
	var camera: Camera3D = world.camera
	cameras.set_mode(cameras.Mode.CHASE)
	var order: Array[int] = []
	var spots: Array[Vector3] = []
	for _press: int in range(4):
		var event := InputEventKey.new()
		event.keycode = KEY_C
		event.pressed = true
		cameras._unhandled_key_input(event)
		cameras.update(FRAME)
		order.append(cameras.mode)
		spots.append(camera.global_position)
	var followed: Node3D = world.actor_of(world.followed_id)
	var cockpit_inside: bool = spots[0].distance_to(followed.global_position) < 1.5
	var heli_high: bool = spots[1].y > 30.0
	var tv_beside: bool = absf(spots[2].y - cameras.TV_HEIGHT_M) < 0.01 and spots[2].distance_to(followed.global_position) > 5.0
	var distinct: bool = true
	for a: int in range(spots.size()):
		for b: int in range(a + 1, spots.size()):
			distinct = distinct and spots[a].distance_to(spots[b]) > 1.0
	var stall: Transform3D = world.pit_lane.stall_transform(4)
	cameras.pit_focus = stall
	cameras.update(FRAME)
	var pit_mode: int = cameras.active_mode()
	var pit_near: bool = camera.global_position.distance_to(stall.origin) < 6.0
	cameras.pit_focus = null
	cameras.set_mode(cameras.Mode.CHASE)
	check(order == [cameras.Mode.COCKPIT, cameras.Mode.HELI, cameras.Mode.TRACKSIDE_TV, cameras.Mode.CHASE] and cockpit_inside and heli_high and tv_beside and distinct
		and pit_mode == cameras.Mode.PITSTOP and pit_near and cameras.active_mode() == cameras.Mode.CHASE and cameras.MODE_NAMES.size() == 6,
		"#26 broadcast cameras: C cycles chase > cockpit > heli > trackside TV, the pit close-up cuts in on its own and hands back")

	# The pit close-up belongs to the selected car only: another team's stop must not steal the shot.
	var chosen: Object = world.race.cars[0]
	var other: Object = world.race.cars[1]
	world.followed_id = chosen.id
	world.choreographer.present(other.id, other.team_id, world.actor_of(other.id), other.compound, true, 0.5, 0.1)
	world._update_cameras(FRAME)
	var ignores_other: bool = cameras.pit_focus == null and cameras.active_mode() != cameras.Mode.PITSTOP
	world.followed_id = other.id
	world._update_cameras(FRAME)
	var follows_selected: bool = cameras.pit_focus != null and cameras.active_mode() == cameras.Mode.PITSTOP
	world.choreographer.present(other.id, other.team_id, world.actor_of(other.id), other.compound, false, 1.0, 0.0)
	world.followed_id = chosen.id
	world._update_cameras(FRAME)
	cameras.set_mode(cameras.Mode.CHASE)
	check(ignores_other and follows_selected and cameras.pit_focus == null,
		"#26b the pit close-up shows only the stop of the selected car: another car's stop leaves the chase camera alone")


## Dense field: 20 cars within 150 m, then 3600 ticks.
func _test_dense_race() -> void:
	var world: Node3D = WorldScene.instantiate()
	root.add_child(world)
	world.set_process(false)
	world.race.incidents_enabled = false
	var rng := RandomNumberGenerator.new()
	rng.seed = 55
	var cars: Array = world.race.cars
	for index: int in range(cars.size()):
		var car: CarScript = cars[index]
		_place(car, 900.0 - 7.6 * float(index), 40.0, rng.randf_range(-4.0, 4.0))
	world.director._enter(DirectorScript.State.GREEN_RACING)
	world.set_time_scale(3.0)
	var overlap_frames: int = 0
	var worst_depth: float = 0.0
	for _tick: int in range(RACE_TICKS):
		world.step(FRAME)
		var frame_overlap: bool = false
		for a: int in range(cars.size()):
			if not cars[a].is_racing():
				continue
			for b: int in range(a + 1, cars.size()):
				if not cars[b].is_racing():
					continue
				var depth: float = _penetration(world.actors[a].global_transform, world.actors[b].global_transform)
				if depth > OVERLAP_DEPTH_M:
					frame_overlap = true
					worst_depth = maxf(worst_depth, depth)
		if frame_overlap:
			overlap_frames += 1
	check(overlap_frames == 0 and cars[0].s > 1500.0,
		"#8 dense pack (20 cars within 150 m, random lateral lines): %d overlap frames over %d ticks (worst %.3f m)" % [overlap_frames, RACE_TICKS, worst_depth])
	world.race.dispose()
	world.queue_free()
	await process_frame


# --- #16..#20 the pit lane and its crew in the world --------------------------------

func _test_pit_in_world() -> void:
	var world: Node3D = WorldScene.instantiate()
	root.add_child(world)
	world.set_process(false)
	world.race.incidents_enabled = false
	world.director._enter(DirectorScript.State.GREEN_RACING)
	var race: RaceScript = world.race
	var entry: float = PitLaneScript.ENTRY_S
	var car_a: CarScript = race.cars[0]
	var car_b: CarScript = null
	for other: CarScript in race.cars:
		if other != car_a and other.team_id == car_a.team_id:
			car_b = other
	_park_others(race, [car_a, car_b])
	var swaps: Array = []
	var on_swap: Callable = func(car_id: int, corner: int, compound: int) -> void: swaps.append([car_id, corner, compound])
	world.choreographer.wheel_swapped.connect(on_swap)
	_place(car_a, entry - 250.0 + world.track.length, 45.0, 0.0)
	_place(car_b, entry - 275.0 + world.track.length, 45.0, 0.0)
	car_a.damage = 20.0
	var first_actor: ActorScript = world.actor_of(car_a.id)
	var second_actor: ActorScript = world.actor_of(car_b.id)
	var stall_origin: Vector3 = world.pit_lane.stall_transform(car_a.team_id).origin
	var target_a: int = Types.Compound.WET
	var target_b: int = Types.Compound.HARD
	world.request_pit(car_a.id, target_a)
	world.request_pit(car_b.id, target_b)
	world.set_time_scale(4.0)
	var max_lane_speed: float = 0.0
	var stopped_distance: float = INF
	var lift_peak: float = 0.0
	var lift_before: float = 0.0
	var saw_empty_socket: bool = false
	var min_gap: float = INF
	var queued: bool = false
	var a_done_at: float = -1.0
	# Wear when the stop ends: WETs on this dry track wear ~18x faster afterwards, which is the point of Langkah 2.
	var a_wear_at_exit: float = -1.0
	var b_done_at: float = -1.0
	var frames: int = 0
	while frames < 60 * 150 and not (car_a.stops >= 1 and car_b.stops >= 1 and car_a.pit == null and car_b.pit == null):
		world.step(FRAME)
		frames += 1
		for car: CarScript in [car_a, car_b]:
			if car.pit != null and car.s - car.pit.start_s >= 0.0:
				max_lane_speed = maxf(max_lane_speed, car.v)
		if car_a.pit != null and car_a.pit.phase == Types.PitPhase.BOX and car_a.v < 0.8 and car_a.pit.timer > 0.0:
			stopped_distance = minf(stopped_distance, first_actor.global_position.distance_to(stall_origin))
			lift_peak = maxf(lift_peak, first_actor.chassis.position.y)
			if car_a.pit.timer < 0.1:
				lift_before = maxf(lift_before, first_actor.chassis.position.y)
			for socket: Marker3D in [first_actor.chassis.socket_wheel_fl, first_actor.chassis.socket_wheel_fr, first_actor.chassis.socket_wheel_rl, first_actor.chassis.socket_wheel_rr]:
				saw_empty_socket = saw_empty_socket or socket.get_child_count() == 0
		if car_a.pit != null and car_b.pit != null:
			min_gap = minf(min_gap, first_actor.global_position.distance_to(second_actor.global_position))
			if car_b.v < 1.0 and car_a.pit.phase == Types.PitPhase.BOX and car_b.s < car_a.pit.box_s - 5.0:
				queued = true
		if car_a.stops >= 1 and a_done_at < 0.0:
			a_done_at = race.time
			a_wear_at_exit = car_a.wear
		if car_b.stops >= 1 and b_done_at < 0.0:
			b_done_at = race.time
	world.set_time_scale(1.0)
	world.choreographer.wheel_swapped.disconnect(on_swap)
	check(max_lane_speed <= Types.PIT_SPEED + 0.6 and is_equal_approx(PitLaneScript.SPEED_LIMIT_MPS, 22.2222),
		"#16 the pit lane limiter holds 80 km/h (22.22 m/s): a car arriving at 45 m/s runs at most %.2f m/s inside" % max_lane_speed)
	check(stopped_distance < 0.5,
		"#17 the car stops on the stall of its team's garage (%.3f m from the box centre)" % stopped_distance)
	check(is_equal_approx(lift_peak, 0.15) and lift_before < 0.1 and first_actor.chassis.position.y == 0.0,
		"#18 the hydraulic jacks lift the chassis %.0f cm during the stop and lower it again" % (lift_peak * 100.0))
	var corners: Array[int] = []
	for swap: Array in swaps:
		if int(swap[0]) == car_a.id and int(swap[2]) == target_a:
			corners.append(int(swap[1]))
	var wheel_ok: bool = corners.size() == 4 and saw_empty_socket
	for socket: Marker3D in [first_actor.chassis.socket_wheel_fl, first_actor.chassis.socket_wheel_fr, first_actor.chassis.socket_wheel_rl, first_actor.chassis.socket_wheel_rr]:
		var wheel := socket.get_child(0) as WheelScript
		var stripe := wheel.find_child("GT3_SidewallStripe", true, false) as MeshInstance3D
		wheel_ok = wheel_ok and stripe.get_surface_override_material(0).resource_path == "res://materials/tire_stripe_wet.tres"
	check(wheel_ok and first_actor.wheel_controllers.size() == 4 and car_a.compound == target_a and a_wear_at_exit < 0.05,
		"#19 the crew took the four old wheels off and fitted four WET wheels (%d swaps, sockets empty during service: %s), the sim car runs on fresh WETs" % [corners.size(), saw_empty_socket])
	check(queued and min_gap >= 4.45 and car_b.stops == 1 and b_done_at > a_done_at and world.choreographer.jobs.is_empty(),
		"#20 the second teammate queued behind the stall (closest %.1f m, car length 4.45 m) and was serviced after the first" % min_gap)
	world.race.dispose()
	world.queue_free()
	await process_frame


# --- #25 the earlier suites ------------------------------------------------

func _test_legacy_suites() -> void:
	if skip_legacy:
		print("[SKIP] #25 earlier suites not run (--skip-legacy)")
		return
	var project_dir: String = ProjectSettings.globalize_path("res://")
	var all_ok: bool = true
	var summary: Array[String] = []
	for suite: Dictionary in LEGACY_SUITES:
		var arguments: PackedStringArray = ["--headless"]
		arguments.append_array(PackedStringArray(suite["args"]))
		arguments.append_array(PackedStringArray(["--path", project_dir, "-s", "res://tests/%s.gd" % suite["script"]]))
		var output: Array = []
		var started: int = Time.get_ticks_msec()
		var code: int = OS.execute(OS.get_executable_path(), arguments, output, true)
		var text: String = "\n".join(PackedStringArray(output))
		var failed_lines: int = text.count("[FAIL]")
		var passed_lines: int = text.count("[PASS]")
		var ok: bool = code == 0 and failed_lines == 0
		all_ok = all_ok and ok
		summary.append("%s %s (%d PASS, %d FAIL, %.0f s)" % [suite["script"], "OK" if ok else "FAILED", passed_lines, failed_lines, float(Time.get_ticks_msec() - started) / 1000.0])
		print("    ", summary[-1])
	check(all_ok, "#25 the earlier suites still pass without regressions: %s" % ", ".join(PackedStringArray(summary)))


# --- geometry --------------------------------------------------------------

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
