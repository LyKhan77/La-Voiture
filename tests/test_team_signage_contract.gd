extends SceneTree

## Every circuit letters the name of each racing team on its own garage, from one shared kit: on the garage fascia
## (all garage signs in one mesh surface, one draw call), or on the pit building door where the building stands
## right in front of the fascias. Brianza's paddock transporters wear the name of the team whose box they serve, on
## the side facing the track. Teams 10..12 only race when the player picks them, and a team without a box gets no sign.
## Run: godot --headless --path . -s res://tests/test_team_signage_contract.gd

const WorldScene := preload("res://scenes/race_weekend_world.tscn")
const Config := preload("res://scripts/core/race_config_data.gd")
const Gt := preload("res://scripts/gt/gt_data.gd")
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
	var pit: Node3D = world.pit_lane
	var race = world.race
	var plates: Array = _lane_plates(world, pit)
	check(plates.size() == race.active_teams.size(), "%s: one garage sign per racing team (%d)" % [label, plates.size()])
	var on_fascia: bool = true
	var named: bool = true
	for team: int in race.active_teams:
		var garage: Node3D = pit.garage_for_team(team)
		var found: Dictionary = _plate_of(plates, team)
		named = named and not found.is_empty() and found["text"] == String(Gt.TEAM_NAMES[team]).to_upper()
		if found.is_empty() or garage == null:
			on_fascia = false
			continue
		# In the garage's frame -X is the lane: the sign hangs just in front of the garage, above the cars.
		var local: Vector3 = garage.transform.affine_inverse() * (found["origin"] as Vector3)
		on_fascia = on_fascia and absf(local.z) < 0.5 and local.x < 0.0 and local.x > -1.2 and local.y > 2.0
	check(named, "%s: each sign spells its team's name" % label)
	check(on_fascia, "%s: each sign sits at the front of its own team's garage" % label)
	for team: int in range(Gt.TEAM_NAMES.size()):
		if not race.active_teams.has(team):
			check(_plate_of(plates, team).is_empty(), "%s: team %d has no box and no sign" % [label, team])
			break
	var plates_node: MeshInstance3D = pit.get_node_or_null("TeamPlates") as MeshInstance3D
	if plates_node != null:
		check(plates_node.mesh.get_surface_count() == 1, "%s: all garage signs share one mesh surface" % label)
		var verts: int = (plates_node.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
		check(verts > 300 * race.active_teams.size(), "%s: the sign mesh holds real lettering (%d vertices)" % [label, verts])

	var kit: Node3D = pit.find_child("TeamTransporters", true, false) as Node3D
	var holder: MeshInstance3D = kit.get_node_or_null("TransporterPlates") as MeshInstance3D if kit != null else null
	check(holder != null, "%s: the paddock carries a TransporterPlates sign mesh" % label)
	if holder != null:
		var signs: Array = holder.get_meta(&"plates", [])
		check(signs.size() == race.active_teams.size(), "%s: one transporter sign per racing team (%d)" % [label, signs.size()])
		var well_placed: bool = true
		for entry: Dictionary in kit.transporter_poses:
			var team: int = int(entry["team"])
			if team < 0:
				continue
			var found: Dictionary = _plate_of(signs, team)
			if found.is_empty():
				well_placed = false
				continue
			var pose: Transform3D = entry["pose"]
			well_placed = well_placed and (found["origin"] as Vector3).distance_to(pose.origin) < 3.5
			# The sign faces the circuit, not the paddock fence.
			var toward_track: Vector3 = world.ribbon.get_point_at_offset(float(entry["s"]), 0.0).origin - (found["origin"] as Vector3)
			well_placed = well_placed and (found["normal"] as Vector3).dot(toward_track.normalized()) > 0.3
		check(well_placed, "%s: transporter signs sit on their own truck, facing the track" % label)
	await process_frame


func _plate_of(plates: Array, team: int) -> Dictionary:
	for entry: Dictionary in plates:
		if int(entry["team"]) == team:
			return entry
	return {}


## Every team-name sign of the pit lane in the complex's frame: the TeamPlates mesh on garage fascias and the names
## lettered on the pit building's doors.
func _lane_plates(world: Node, pit: Node3D) -> Array:
	var result: Array = []
	var node: Node = pit.get_node_or_null("TeamPlates")
	if node != null:
		result.append_array(node.get_meta(&"plates", []))
	for building: Node in world.find_children("PitBuilding", "", true, false):
		for entry: Dictionary in building.name_plates:
			if entry.is_empty():
				continue
			var moved: Dictionary = entry.duplicate()
			moved["origin"] = pit.global_transform.affine_inverse() * (building.global_transform * (entry["origin"] as Vector3))
			result.append(moved)
	return result
