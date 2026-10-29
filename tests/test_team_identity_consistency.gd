extends SceneTree

## The team-unique objects are the same set on every circuit: for each team that races, its garage holds a standby crew
## in the team's overalls, its shutter strip and transporter wear the team's livery colour, and a transporter of that
## team stands behind the pit building level with its box. The name signs have their own contract
## (test_team_signage_contract.gd).
## Run: godot --headless --path . -s res://tests/test_team_identity_consistency.gd

const WorldScene := preload("res://scenes/race_weekend_world.tscn")
const Config := preload("res://scripts/core/race_config_data.gd")
const Liveries := preload("res://scripts/car/team_liveries.gd")
const CIRCUITS: Array[String] = ["apex_ring", "neo_wangan", "brianza"]
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
	var pit: Node3D = world.pit_lane
	var race = world.race

	var crews_ok: bool = true
	for team: int in race.active_teams:
		var garage: Node3D = pit.garage_for_team(team)
		var crew: MeshInstance3D = garage.get_node_or_null("StandbyCrew") as MeshInstance3D if garage != null else null
		crews_ok = crews_ok and crew != null and _mesh_has_color(crew.mesh, Liveries.color_for(team))
	check(crews_ok, "%s: every racing team's garage holds a standby crew in its own overalls" % label)

	var kit: Node3D = pit.find_child("TeamTransporters", true, false) as Node3D
	check(kit != null, "%s: the circuit parks team transporters" % label)
	if kit != null:
		var poses: Array = kit.transporter_poses
		check(poses.size() == race.active_teams.size(), "%s: one transporter per racing team (%d)" % [label, poses.size()])
		var coloured: bool = true
		var level: bool = true
		var behind: bool = true
		for team: int in race.active_teams:
			var entry: Dictionary = _entry_of(poses, team)
			if entry.is_empty():
				coloured = false
				continue
			var color: Color = entry["color"]
			var wanted: Color = Liveries.color_for(team)
			coloured = coloured and absf(color.r - wanted.r) < 0.01 and absf(color.g - wanted.g) < 0.01 and absf(color.b - wanted.b) < 0.01
			var truck: Vector3 = (entry["pose"] as Transform3D).origin
			# Level with its own box along the lane, and well behind the garage row (not in the lane or the building).
			var along: float = absf(fposmod(float(entry["s"]) - float(race.stall_index_for_team(team)) * float(race.pit_layout["stall_pitch_m"]) - float(race.pit_layout["stall_first_s"]) + world.ribbon.length_m * 0.5, world.ribbon.length_m) - world.ribbon.length_m * 0.5)
			level = level and along < 1.0
			# Past the back wall of the garage (front + 9 m deep) plus a 3 m gap, and not out in the scenery.
			var off_line: float = truck.distance_to(world.ribbon.get_point_at_offset(float(entry["s"]), 0.0).origin)
			behind = behind and off_line > pit.garage_front_m + 12.0 and off_line < 80.0
		check(coloured, "%s: each transporter wears its team's livery colour" % label)
		check(level, "%s: each transporter stands level with its team's box" % label)
		check(behind, "%s: the transporters stand behind the garages, clear of the lane and the building" % label)
	world.queue_free()
	await process_frame


func _entry_of(poses: Array, team: int) -> Dictionary:
	for entry: Dictionary in poses:
		if int(entry["team"]) == team:
			return entry
	return {}


func _mesh_has_color(mesh: Mesh, wanted: Color) -> bool:
	if mesh == null:
		return false
	var linear: Color = wanted.srgb_to_linear()
	for surface: int in range(mesh.get_surface_count()):
		for color: Color in mesh.surface_get_arrays(surface)[Mesh.ARRAY_COLOR]:
			if absf(color.r - wanted.r) < 0.01 and absf(color.g - wanted.g) < 0.01 and absf(color.b - wanted.b) < 0.01:
				return true
			if absf(color.r - linear.r) < 0.01 and absf(color.g - linear.g) < 0.01 and absf(color.b - linear.b) < 0.01:
				return true
	return false
