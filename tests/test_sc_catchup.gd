extends SceneTree

## Fase 32 Task 1: the safety car reaches the leader in bounded time wherever the leader is on the lap, the field
## stays collision-free while it catches up and bunches soon after pickup, and an empty track does not break the
## caution logic. Run: godot --headless --path . -s res://tests/test_sc_catchup.gd

const TrackScene := preload("res://scenes/race_world/circuits/apex_ring/apex_circuit.tscn")
const TrackScript := preload("res://scripts/gt/gt_track.gd")
const RaceScript := preload("res://scripts/gt/gt_race.gd")
const WeatherScript := preload("res://scripts/gt/gt_weather.gd")
const Types := preload("res://scripts/gt/gt_types.gd")

const DRY: int = WeatherScript.Archetype.DRY_SUNNY
## Seconds the leader may take to reach the safety car, by how far past the spawn point it is (fraction of a lap).
const PICKUP_LIMITS: Dictionary = {0.05: 170.0, 0.5: 120.0, 0.95: 40.0}
const BUNCH_LIMIT_S: float = 90.0

var failures: int = 0
var collisions: int = 0


func check(ok: bool, description: String) -> void:
	print("[%s] %s" % ["PASS" if ok else "FAIL", description])
	if not ok:
		failures += 1


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_cap_function()
	var ribbon: Node = TrackScene.instantiate()
	ribbon.road_half_width_m = 7.0
	root.add_child(ribbon)
	var track := TrackScript.new(ribbon, 14.0)
	for frac: float in PICKUP_LIMITS:
		_test_pickup_time(track, frac, float(PICKUP_LIMITS[frac]))
	_test_empty_track(track)
	ribbon.queue_free()
	await process_frame
	quit(1 if failures else 0)


func _test_cap_function() -> void:
	check(is_equal_approx(GtRace.sc_catchup_cap(100.0), 27.0), "cap is 27 m/s close to the safety car")
	check(is_equal_approx(GtRace.sc_catchup_cap(GtRace.SC_CATCHUP_NEAR_M), 27.0), "cap is 27 m/s at the near distance")
	check(is_equal_approx(GtRace.sc_catchup_cap(1500.0), GtRace.SC_LEADER_CATCHUP_MAX_MPS), "cap reaches the maximum far away")
	var monotone: bool = true
	var previous: float = 0.0
	for index: int in range(21):
		var cap: float = GtRace.sc_catchup_cap(float(index) * 100.0)
		monotone = monotone and cap >= previous - 0.0001
		previous = cap
	check(monotone, "cap never falls as the gap to the safety car grows")


func _bunched(race: RaceScript) -> bool:
	var gaps: Array[float] = []
	for car: GtCar in race.cars:
		if not car.is_dnf and car.finished_at < 0.0 and car.pit == null:
			gaps.append(fposmod(float(race.safety_car["s"]) - car.s, race.track.length))
	gaps.sort()
	var previous: float = 0.0
	for gap: float in gaps:
		if gap - previous > RaceScript.SC_QUEUE_GAP_M:
			return false
		previous = gap
	return not gaps.is_empty()


func _test_pickup_time(track: TrackScript, frac: float, limit_s: float) -> void:
	var race := RaceScript.new(track, 10, 5, DRY, 20)
	race.incidents_enabled = false
	collisions = 0
	# Paint rubs (CollisionKind.RUB) happen in ordinary green-flag racing; only real contact counts.
	race.collision_event.connect(func(event: Dictionary) -> void:
		if int(event["type"]) != Types.CollisionKind.RUB:
			collisions += 1)
	race.step_ticks(1500)
	var guard: int = 0
	var spawn: float = float(race.pit_layout["exit_s"]) - 60.0
	while guard < 20000:
		var rel: float = fposmod(race.standings()[0].s - spawn, track.length) / track.length
		if absf(rel - frac) < 0.01:
			break
		race.step()
		guard += 1
	var t0: float = race.time
	collisions = 0
	race.set_flag(Types.Flag.SC, 1, "TEST SAFETY CAR", 28.0)
	var picked_at: float = -1.0
	var bunched_at: float = -1.0
	var ticks: int = 0
	while ticks < int(500.0 / Types.TICK_DT) and (picked_at < 0.0 or bunched_at < 0.0):
		race.step()
		ticks += 1
		if picked_at < 0.0 and bool(race.safety_car.get("picked_up", false)):
			picked_at = race.time - t0
		if picked_at >= 0.0 and bunched_at < 0.0 and _bunched(race):
			bunched_at = race.time - t0
	check(picked_at >= 0.0 and picked_at <= limit_s, "leader %.0f%% past the spawn: pickup within %.0f s (%.1f s)" % [frac * 100.0, limit_s, picked_at])
	check(collisions == 0, "leader %.0f%% past the spawn: no contact while catching up (%d)" % [frac * 100.0, collisions])
	check(bunched_at >= 0.0 and bunched_at - picked_at <= BUNCH_LIMIT_S, "leader %.0f%% past the spawn: field bunched within %.0f s of pickup (%.1f s)" % [frac * 100.0, BUNCH_LIMIT_S, bunched_at - picked_at])
	race.dispose()


func _test_empty_track(track: TrackScript) -> void:
	var race := RaceScript.new(track, 10, 5, DRY, 20)
	race.incidents_enabled = false
	race.step_ticks(200)
	for car: GtCar in race.cars:
		car.is_dnf = true
		car.finished_at = race.time
	race.set_flag(Types.Flag.SC, 1, "TEST SAFETY CAR", 28.0)
	race.step_ticks(100)
	check(int(race.race_control["flag"]) == Types.Flag.SC, "safety car stays out on an empty track and the sim keeps stepping")
	race.dispose()
