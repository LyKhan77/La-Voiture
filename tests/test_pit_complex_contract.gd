extends SceneTree

## Every circuit's pit complex is a CircuitPitComplex and honours its contract: the boxes and garages match the
## sim's stall count, a team without a box has no box, garage or crew spot, re-seating moves the boxes (and puts them
## back), the crew line-up is the standard 13, and the lane the sim drives agrees with the complex about where cars park.
## Run: godot --headless --path . -s res://tests/test_pit_complex_contract.gd

const WorldScene := preload("res://scenes/race_weekend_world.tscn")
const Config := preload("res://scripts/core/race_config_data.gd")
const CIRCUITS: Array[String] = ["apex_ring", "neo_wangan", "brianza", "monte_azure", "ardennes"]
const LAYOUT_KEYS: Array[String] = ["entry_s", "exit_s", "stall_first_s", "stall_pitch_m", "stall_lane_m", "fast_lane_m", "edge_lateral_m", "queue_gap_m", "lane_ramp_in_m", "lane_ramp_out_m"]

var failures: int = 0


func check(ok: bool, description: String) -> void:
	print("[%s] %s" % ["PASS" if ok else "FAIL", description])
	if not ok:
		failures += 1


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	for circuit: String in CIRCUITS:
		await _audit(circuit)
	quit(1 if failures else 0)


func _audit(circuit: String) -> void:
	var config = Config.get_config()
	config.selected_circuit_id = circuit
	config.selected_team_id = 4
	config.race_seed = 19220903
	var world = WorldScene.instantiate()
	root.add_child(world)
	await process_frame
	var pit = world.pit_lane
	var race = world.race
	var label: String = circuit
	var is_complex: bool = pit is CircuitPitComplex
	check(is_complex, "%s: the pit lane is a CircuitPitComplex" % label)
	if not is_complex:
		world.queue_free()
		await process_frame
		return
	var active: Array[int] = []
	for team: int in race.active_teams:
		active.append(team)
	check(pit.built, "%s: the complex reports it is built" % label)
	check(pit.stalls.size() == pit.team_count and pit.garages.size() == pit.team_count and pit.team_count == active.size(), "%s: one box and one garage per racing team (%d)" % [label, pit.team_count])
	check(pit.stall_lane_m > 0.0 and pit.garage_front_m > pit.stall_lane_m, "%s: the garages stand behind the boxes (box %.1f m, garage front %.1f m)" % [label, pit.stall_lane_m, pit.garage_front_m])

	var absent: int = -1
	for team: int in range(13):
		if not active.has(team):
			absent = team
			break
	check(absent >= 0 and pit.stall_index_for_team(absent) == -1 and pit.garage_for_team(absent) == null and pit.stall_transform(absent) == Transform3D.IDENTITY, "%s: a team without a box has no box, garage or park point" % label)

	var roles: Array = pit.crew_roles()
	var spots_ok: bool = roles.size() == 13
	var previous_z: float = -INF
	for slot: int in range(roles.size()):
		var spot: Vector3 = pit.crew_spot(slot)
		spots_ok = spots_ok and spot.x > 0.0 and spot.z > previous_z
		previous_z = spot.z
	check(spots_ok, "%s: the crew is the standard 13, lined up across the garage mouth" % label)

	for key: String in LAYOUT_KEYS:
		check(race.pit_layout.has(key), "%s: the sim's pit layout has %s" % [label, key])
	check(is_equal_approx(float(race.pit_layout["stall_lane_m"]), pit.stall_lane_m), "%s: the sim parks cars where the complex draws the boxes (%.1f m)" % [label, pit.stall_lane_m])

	# Re-seating: reversed order moves every team's box, and the original order puts them back.
	var reversed: Array[int] = []
	for i: int in range(active.size() - 1, -1, -1):
		reversed.append(active[i])
	pit.seat_teams(world.ribbon, reversed)
	var moved: bool = pit.stall_index_for_team(active[active.size() - 1]) == 0 and pit.stall_index_for_team(active[0]) == active.size() - 1
	var garages_follow: bool = true
	for team: int in active:
		garages_follow = garages_follow and pit.garage_for_team(team) == pit.garages[pit.stall_index_for_team(team)]
	check(moved and garages_follow, "%s: seat_teams re-seats the boxes and the garages follow" % label)
	pit.seat_teams(world.ribbon, active)
	var restored: bool = true
	for i: int in range(active.size()):
		restored = restored and pit.stall_index_for_team(active[i]) == i
	check(restored, "%s: seating the original order puts every team back" % label)
	world.queue_free()
	await process_frame
