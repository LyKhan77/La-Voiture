extends SceneTree

## Every circuit must seat the teams the sim races (GtRace.active_teams) in the box the sim parks them in,
## and the pit crew of a team must be that team's own crew standing at that box. Teams 10..12 only race
## when the player picks them, so the identity order 0..9 hides the bug.

const WorldScene := preload("res://scenes/race_weekend_world.tscn")
const Config := preload("res://scripts/core/race_config_data.gd")
const CIRCUITS: Array[String] = ["apex_ring", "neo_wangan", "brianza", "monte_azure", "ardennes"]
const PLAYER_TEAMS: Array[int] = [4, 11, 12]

var failures: int = 0


func check(ok: bool, description: String) -> void:
	print("[%s] %s" % ["PASS" if ok else "FAIL", description])
	if not ok:
		failures += 1


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	for circuit: String in CIRCUITS:
		for player_team: int in PLAYER_TEAMS:
			await _audit(circuit, player_team)
	quit(1 if failures else 0)


func _audit(circuit: String, player_team: int) -> void:
	var config = Config.get_config()
	config.selected_circuit_id = circuit
	config.selected_team_id = player_team
	config.race_seed = 19220903
	var world = WorldScene.instantiate()
	root.add_child(world)
	await process_frame
	var label: String = "%s player %d" % [circuit, player_team]
	var pit: Node = world.pit_lane
	var race = world.race
	var layout: Dictionary = race.pit_layout
	var lap: float = world.ribbon.length_m
	var seats_match: bool = true
	var boxes_match: bool = true
	var garages_found: bool = true
	for team: int in race.active_teams:
		var index: int = race.stall_index_for_team(team)
		seats_match = seats_match and pit.stall_index_for_team(team) == index
		var box_s: float = fposmod(float(layout["stall_first_s"]) + float(layout["stall_pitch_m"]) * float(index), lap)
		var parked: Vector3 = world.ribbon.get_point_at_offset(box_s, float(layout["stall_lane_m"])).origin
		boxes_match = boxes_match and pit.stall_transform(team).origin.distance_to(parked) < 0.5
		garages_found = garages_found and pit.garage_for_team(team) != null
	check(seats_match, "%s: pit seats follow the sim's stall order" % label)
	check(boxes_match, "%s: each team's box is where the sim parks it" % label)
	check(garages_found, "%s: every racing team has its garage" % label)

	var absent: int = -1
	for team: int in range(13):
		if not race.active_teams.has(team):
			absent = team
			break
	var racing: Array = race.active_teams.duplicate()
	if absent >= 0:
		racing.append(absent)
	world.choreographer.set_ready_teams(racing)
	world.choreographer.advance(0.05)
	var crews_ok: bool = true
	for team: int in race.active_teams:
		var nodes: Array = world.choreographer.crew_nodes(team)
		var crew = world.choreographer._crews.get(team)
		crews_ok = crews_ok and nodes.size() == 13 and crew != null and crew.team == team
		crews_ok = crews_ok and crew.root.name == "PitCrew%02d" % (team + 1)
		crews_ok = crews_ok and crew.root.global_position.distance_to(pit.stall_transform(team).origin) < 0.5
	check(crews_ok, "%s: each crew belongs to its team and stands at its own box" % label)
	if absent >= 0:
		check(world.choreographer.crew_nodes(absent).is_empty(), "%s: a team without a box gets no crew" % label)
	var building: Node = world.find_child("PitBuilding", true, false)
	var shutters_ok: bool = building != null and building.structure != null
	if shutters_ok:
		for team: int in range(13):
			shutters_ok = shutters_ok and _has_livery(building.structure.mesh, team) == race.active_teams.has(team)
	check(shutters_ok, "%s: pit building shutters wear the colours of the teams in the boxes" % label)
	world.queue_free()
	await process_frame


func _has_livery(mesh: Mesh, team: int) -> bool:
	var wanted: Color = preload("res://scripts/car/team_liveries.gd").color_for(team)
	for surface: int in range(mesh.get_surface_count()):
		for color: Color in mesh.surface_get_arrays(surface)[Mesh.ARRAY_COLOR]:
			if absf(color.r - wanted.r) < 0.01 and absf(color.g - wanted.g) < 0.01 and absf(color.b - wanted.b) < 0.01:
				return true
			var linear: Color = wanted.srgb_to_linear()
			if absf(color.r - linear.r) < 0.01 and absf(color.g - linear.g) < 0.01 and absf(color.b - linear.b) < 0.01:
				return true
	return false
