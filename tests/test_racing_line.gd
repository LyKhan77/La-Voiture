extends SceneTree

## FASE 18 acceptance: a real racing line (outside - apex - outside) on every playable circuit, the
## pace profile read from the line, per-driver line variation, the rain line, the tow tuck-in and the
## rubber groove on every circuit. Run: godot --headless --path . -s res://tests/test_racing_line.gd

const Registry := preload("res://scripts/core/circuit_calendar_registry.gd")
const LineScript := preload("res://scripts/car/adaptive_racing_line.gd")
const RibbonScript := preload("res://scripts/car/track_ribbon.gd")
const TrackScript := preload("res://scripts/gt/gt_track.gd")
const RaceScript := preload("res://scripts/gt/gt_race.gd")
const CarScript := preload("res://scripts/gt/gt_car.gd")
const DrivingScript := preload("res://scripts/gt/gt_driving.gd")
const WeatherScript := preload("res://scripts/gt/gt_weather.gd")
const Types := preload("res://scripts/gt/gt_types.gd")

## Profile lap times (s) of the centreline speed profile before FASE 18.
const BASELINE_PROFILE_LAP_S: Dictionary = {
	"apex_ring": 81.55, "neo_wangan": 81.45, "brianza": 113.74, "monte_azure": 70.78, "ardennes": 110.61,
}
## Calibration anchors: centrelines without kinks, so the line must keep their laps within the tolerance. The
## others braked for single-sample centreline kinks (Brianza's seam at s = 0 read as a 93 km/h corner) that the
## line straightens: they must get faster, but by less than PROFILE_KINK_GAIN_MAX.
const CALIBRATION_ANCHORS: Array[String] = ["apex_ring", "neo_wangan"]
const PROFILE_LAP_TOLERANCE: float = 0.04
const PROFILE_KINK_GAIN_MAX: float = 0.20
## A real line turns around about twice per corner (wide - apex - wide); allow some linked-corner slack.
const REVERSALS_PER_TURN_MAX: float = 3.0
const REVERSAL_SWING_M: float = 0.4
## Steepest the line may cross the road: tan of its heading off the centreline (0.4 = 22 degrees).
const LINE_SLOPE_MAX: float = 0.4
## Mean distance a lone car may run from the line it aims for, over a lap.
const TRACKING_MEAN_MAX_M: float = 0.5
const BUILD_BUDGET_MS: int = 250
const SPRINT_GROOVE_RATIO_MAX: float = 0.75

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
	var groove_alpha: Dictionary = {} # circuit id -> max groove alpha
	var apex_ribbon: RibbonScript = null
	var apex_node: Node = null
	for circuit in Registry.get_all_circuits():
		if not circuit.is_playable():
			continue
		var node: Node = (load(circuit.scene_path) as PackedScene).instantiate()
		root.add_child(node)
		await process_frame
		var ribbon: RibbonScript = _find_ribbon(node)
		_test_line_shape(circuit, ribbon)
		groove_alpha[circuit.circuit_id] = _groove_max_alpha(node)
		if circuit.circuit_id == "apex_ring":
			apex_ribbon = ribbon
			apex_node = node
		else:
			node.free()
	_test_groove_everywhere(groove_alpha)
	_test_driver_lines(apex_ribbon)
	apex_node.free()
	await process_frame
	print("%d assertions, %d failure(s)" % [assertions, failures])
	print("FASE 18 RACING LINE: %s" % ("PASS" if failures == 0 else "%d FAILURES" % failures))
	quit(0 if failures == 0 else 1)


func _find_ribbon(node: Node) -> RibbonScript:
	if node is RibbonScript:
		return node
	for child: Node in node.get_children():
		var hit: RibbonScript = _find_ribbon(child)
		if hit != null:
			return hit
	return null


# --- the line on every circuit ---------------------------------------------------------------

func _test_line_shape(circuit: Resource, ribbon: RibbonScript) -> void:
	var id: String = circuit.circuit_id
	# Arrange / act
	var t0: int = Time.get_ticks_msec()
	var track := TrackScript.new(ribbon, ribbon.road_half_width_m * 2.0)
	var build_ms: int = Time.get_ticks_msec() - t0
	var line: LineScript = track.line
	var again := LineScript.new(ribbon)
	var step: float = 2.0
	var n: int = int(ribbon.length_m / step)
	var offsets := PackedFloat32Array()
	var identical: bool = true
	for i: int in range(n):
		offsets.append(line.target_offset(i * step))
		identical = identical and line.target_offset(i * step) == again.target_offset(i * step)

	# zig-zag: direction reversals that swing more than REVERSAL_SWING_M
	var reversals: int = 0
	var last_extreme: float = offsets[0]
	var dir: int = 0
	var steepest: float = 0.0
	var widest: float = 0.0
	var inside_limit: bool = true
	for i: int in range(1, n):
		var d: float = offsets[i] - offsets[i - 1]
		steepest = maxf(steepest, absf(d) / step)
		widest = maxf(widest, absf(offsets[i]))
		inside_limit = inside_limit and absf(offsets[i]) <= line.line_limit_m + 1.0e-4
		var nd: int = int(signf(d))
		if nd != 0 and nd != dir:
			if dir == 0:
				dir = nd
			elif absf(offsets[i - 1] - last_extreme) > REVERSAL_SWING_M:
				reversals += 1
				last_extreme = offsets[i - 1]
				dir = nd

	# Assert
	var reversal_cap: float = REVERSALS_PER_TURN_MAX * float(circuit.turns_count)
	check(reversals <= reversal_cap,
		"%s: line is smooth, %d direction reversals over %d turns (cap %.0f)" % [id, reversals, circuit.turns_count, reversal_cap])
	check(steepest <= LINE_SLOPE_MAX,
		"%s: line crosses the road at most %.2f m per m (cap %.2f)" % [id, steepest, LINE_SLOPE_MAX])
	check(inside_limit and widest >= 0.9 * line.line_limit_m,
		"%s: line stays within +-%.2f m and uses the width (widest %.2f m)" % [id, line.line_limit_m, widest])
	check(identical, "%s: the line is deterministic (two builds identical)" % id)
	check(build_ms <= BUILD_BUDGET_MS, "%s: track + line build in %d ms (budget %d ms)" % [id, build_ms, BUILD_BUDGET_MS])
	_check_outside_apex_outside(id, line, ribbon.length_m)
	_check_pace(id, track, line)


## Every real corner (one-direction run of |kappa| > 0.008 turning more than 25 degrees; single-sample kinks in
## the centreline are straight-lined, rightly) clips the inside and, unless it follows a same-hand corner,
## comes in from the outside. Double-apex pairs fail the entry half, hence a share, not all.
func _check_outside_apex_outside(id: String, line: LineScript, length: float) -> void:
	var corners: Array[Vector3] = [] # (start_s, end_s, side)
	var start: float = -1.0
	var side: float = 0.0
	var turning: float = 0.0
	var s: float = 0.0
	while s <= length:
		var k: float = line.curvature_at(s)
		var in_corner: bool = absf(k) > 0.008 and (start < 0.0 or signf(k) == side)
		if in_corner:
			if start < 0.0:
				start = s
				side = signf(k)
				turning = 0.0
			turning += absf(k) * 2.0
		elif start >= 0.0:
			if turning > deg_to_rad(25.0):
				corners.append(Vector3(start, s, side))
			start = -1.0
			continue # re-read this sample: it may open a corner of the other hand
		s += 2.0
	var shaped: int = 0
	for corner: Vector3 in corners:
		var inside: float = -INF
		var x: float = corner.x - 10.0
		while x <= corner.y + 10.0:
			inside = maxf(inside, line.target_offset(x) * corner.z)
			x += 2.0
		var entry: float = INF
		x = corner.x - 160.0
		while x <= corner.x - 10.0:
			entry = minf(entry, line.target_offset(x) * corner.z)
			x += 2.0
		if inside > 0.4 * line.line_limit_m and entry < -0.25 * line.line_limit_m:
			shaped += 1
	var share: float = float(shaped) / maxf(1.0, float(corners.size()))
	check(corners.size() > 0 and share >= 0.6,
		"%s: %d of %d corners run wide on entry and clip the inside at the apex (%.0f%%)" % [id, shaped, corners.size(), share * 100.0])


## The speed profile reads the line (wider than the centreline) and stays calibrated to the old lap.
func _check_pace(id: String, track: TrackScript, line: LineScript) -> void:
	var centre_sum: float = 0.0
	var line_sum: float = 0.0
	var lap_s: float = 0.0
	var x: float = 0.0
	while x < track.length:
		var k: float = absf(line.curvature_at(x))
		if k > 0.004:
			centre_sum += k
			line_sum += absf(line.line_curvature_at(x))
		lap_s += 1.0 / maxf(1.0, track.speed_limit_at(x))
		x += 1.0
	check(line_sum < 0.9 * centre_sum,
		"%s: the line opens the corners (curvature %.0f%% of the centreline's)" % [id, 100.0 * line_sum / maxf(1.0e-6, centre_sum)])
	var baseline: float = BASELINE_PROFILE_LAP_S[id]
	if CALIBRATION_ANCHORS.has(id):
		check(absf(lap_s / baseline - 1.0) <= PROFILE_LAP_TOLERANCE,
			"%s: profile lap %.2f s within %.0f%% of the pre-FASE-18 %.2f s (calibration anchor)" % [id, lap_s, PROFILE_LAP_TOLERANCE * 100.0, baseline])
	else:
		check(lap_s < baseline and lap_s >= (1.0 - PROFILE_KINK_GAIN_MAX) * baseline,
			"%s: profile lap %.2f s, faster than the kinked pre-FASE-18 %.2f s by under %.0f%%" % [id, lap_s, baseline, PROFILE_KINK_GAIN_MAX * 100.0])


# --- groove ------------------------------------------------------------------------------

func _groove_max_alpha(node: Node) -> float:
	var groove := node.find_child("RubberGroove", true, false) as MeshInstance3D
	if groove == null or groove.mesh == null:
		return 0.0
	var colors: PackedColorArray = groove.mesh.surface_get_arrays(0)[Mesh.ARRAY_COLOR]
	var best: float = 0.0
	for color: Color in colors:
		best = maxf(best, color.a)
	return best


## The Apex Ring's set lives in race_weekend_world.tscn, not its circuit scene: test_track_environment #S9 covers it.
func _test_groove_everywhere(alpha: Dictionary) -> void:
	var all_have: bool = true
	for id: String in ["neo_wangan", "brianza", "monte_azure", "ardennes"]:
		all_have = all_have and float(alpha.get(id, 0.0)) > 0.0
	check(all_have, "groove: every circuit set lays rubber on its line %s" % str(alpha))
	var permanent: float = minf(float(alpha.get("brianza", 0.0)), float(alpha.get("ardennes", 0.0)))
	var street: float = maxf(float(alpha.get("neo_wangan", 0.0)), float(alpha.get("monte_azure", 0.0)))
	check(street > 0.0 and street <= SPRINT_GROOVE_RATIO_MAX * permanent,
		"groove: street (Sprint) rubber is fainter than a permanent circuit's (%.2f vs %.2f)" % [street, permanent])


# --- what a driver does with the line --------------------------------------------------------

func _test_driver_lines(ribbon: RibbonScript) -> void:
	var track := TrackScript.new(ribbon, ribbon.road_half_width_m * 2.0)
	var race := RaceScript.new(track, 5, 5, WeatherScript.Archetype.DRY_SUNNY)
	race.incidents_enabled = false
	var driving: DrivingScript = race._driving
	var a: CarScript = race.cars[0]
	var b: CarScript = race.cars[1]

	# per-driver variation: bounded, personal, pure (no rng draw)
	var rng_probe: float = RaceScript.new(track, 5, 5, WeatherScript.Archetype.DRY_SUNNY).rng.next()
	var differs: bool = false
	var bounded: bool = true
	var repeatable: bool = true
	var s: float = 0.0
	while s < track.length:
		var la: float = driving.race_line_for(a, s)
		var lb: float = driving.race_line_for(b, s)
		differs = differs or absf(la - lb) > 0.1
		bounded = bounded and absf(la - track.ideal_lateral_at(s)) <= DrivingScript.DRIVER_LINE_SPREAD_M + 1.0e-4
		repeatable = repeatable and la == driving.race_line_for(a, s)
		s += 7.0
	check(differs and bounded and repeatable and race.rng.next() == rng_probe,
		"driver line: each driver wanders up to %.2f m off the racing line, repeatably, without drawing from the race rng" % DrivingScript.DRIVER_LINE_SPREAD_M)

	# rain line: heavy rain moves the corners off the rubber, the straights stay put
	var corner_s: float = _tightest_corner(track)
	var straight_s: float = _straightest(track)
	var dry_corner: float = driving.race_line_for(a, corner_s)
	var dry_straight: float = driving.race_line_for(a, straight_s)
	race.weather.track_water_pct = 70.0
	race.weather.rain_intensity = 0.7
	race.weather.drying_line_pct = 0.0
	var wet_corner: float = driving.race_line_for(a, corner_s)
	var wet_straight: float = driving.race_line_for(a, straight_s)
	var outward: float = (wet_corner - dry_corner) * -signf(track.line.line_curvature_at(corner_s))
	check(outward > 0.8 and absf(wet_straight - dry_straight) < 0.2,
		"rain line: heavy rain takes the corner %.2f m off the rubber to the outside, the straight moves %.2f m" % [outward, absf(wet_straight - dry_straight)])
	a.compound = Types.Compound.WET
	a.s = corner_s
	a.lateral = track.ideal_lateral_at(corner_s)
	var on_rubber: float = driving.water_grip(a)
	a.lateral = track.ideal_lateral_at(corner_s) - signf(track.line.line_curvature_at(corner_s)) * DrivingScript.RAIN_LINE_SHIFT_M
	var off_rubber: float = driving.water_grip(a)
	check(on_rubber < off_rubber,
		"rain line: in heavy rain the rubbered line is the slippery one (grip %.3f on it, %.3f off it)" % [on_rubber, off_rubber])
	race.dispose()

	# a lone car rides the line it aims for, chicanes included
	var solo := RaceScript.new(track, 5, 9, WeatherScript.Archetype.DRY_SUNNY)
	solo.incidents_enabled = false
	var runner: CarScript = solo.cars[0]
	for index: int in range(1, solo.cars.size()):
		solo.cars[index].s = -400.0 - float(index) * 30.0
		solo.cars[index].prev_s = solo.cars[index].s
	_place(runner, 0.0, 40.0, track.ideal_lateral_at(0.0))
	var error_sum: float = 0.0
	var worst_error: float = 0.0
	var samples: int = 0
	while runner.s < track.length and samples < 4000:
		solo.step()
		var error: float = absf(runner.lateral - solo._driving.race_line_for(runner, runner.s))
		error_sum += error
		worst_error = maxf(worst_error, error)
		samples += 1
	check(runner.s >= track.length and error_sum / float(samples) <= TRACKING_MEAN_MAX_M,
		"tracking: a lone car laps on its line, mean %.2f m off it (cap %.2f), worst %.2f m" % [error_sum / float(maxi(1, samples)), TRACKING_MEAN_MAX_M, worst_error])
	solo.dispose()

	# tow: a follower on the straight tucks in behind the car ahead
	var tow_race := RaceScript.new(track, 5, 7, WeatherScript.Archetype.DRY_SUNNY)
	tow_race.incidents_enabled = false
	var lead_car: CarScript = tow_race.cars[0]
	var chaser: CarScript = tow_race.cars[1]
	for index: int in range(2, tow_race.cars.size()):
		tow_race.cars[index].s = -400.0 - float(index) * 30.0
		tow_race.cars[index].prev_s = tow_race.cars[index].s
	var tow_s: float = straight_s - 150.0
	# 21 m: inside the tow, outside FOLLOW_GAP so no pass is rolled and the follower only follows.
	var lead_lateral: float = track.ideal_lateral_at(tow_s + 21.0) + 2.0
	_place(lead_car, tow_s + 21.0, 60.0, lead_lateral)
	_place(chaser, tow_s, 60.0, track.ideal_lateral_at(tow_s))
	lead_car.defend_timer = 99.0 # holds its line
	lead_car.defend_target_lateral = lead_lateral
	var start_gap: float = absf(chaser.lateral - lead_car.lateral)
	for _tick: int in range(30):
		tow_race.step()
	var end_gap: float = absf(chaser.lateral - lead_car.lateral)
	# Without the tuck, 1.75 m off at 21 m the tow would be ~0.05.
	check(end_gap < 0.6 * start_gap and chaser.slipstream_factor > 0.12,
		"tow: a follower tucks in behind on the straight (lateral gap %.2f -> %.2f m, tow %.2f)" % [start_gap, end_gap, chaser.slipstream_factor])
	tow_race.dispose()


func _place(car: CarScript, s: float, v: float, lateral: float) -> void:
	car.s = s
	car.prev_s = s
	car.v = v
	car.lateral = lateral
	car.prev_lateral = lateral
	car.target_lateral = lateral
	car.lap = 1


func _tightest_corner(track: TrackScript) -> float:
	var best_s: float = 0.0
	var best: float = 0.0
	var s: float = 0.0
	while s < track.length:
		if absf(track.line.line_curvature_at(s)) > best:
			best = absf(track.line.line_curvature_at(s))
			best_s = s
		s += 2.0
	return best_s


## Middle of the longest run with the centreline nearly straight.
func _straightest(track: TrackScript) -> float:
	var best_len: float = 0.0
	var best_mid: float = 0.0
	var run_start: float = -1.0
	var s: float = 0.0
	while s < track.length:
		if absf(track.curvature_at(s)) < 0.002:
			if run_start < 0.0:
				run_start = s
			elif s - run_start > best_len:
				best_len = s - run_start
				best_mid = (s + run_start) * 0.5
		else:
			run_start = -1.0
		s += 5.0
	return best_mid
