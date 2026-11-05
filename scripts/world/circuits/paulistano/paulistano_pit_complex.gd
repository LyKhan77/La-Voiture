class_name PaulistanoPitComplex
extends "res://scripts/world/circuits/base/circuit_pit_complex.gd"

## Paulistano Speed Arena pit lane: 410 m LEFT-hand lane (counter-clockwise lap),
## entry s=4060, exit s=160, ten 14 m boxes (bay i at s = 27 + 14 i), service bay 5
## at s=97, the 140 m 2F/10-garage FIA pit building at s=90, the 240 m main
## grandstand on the right at s=50, race control at s=20, the start gantry with its
## wing over the left lane, team fascia/crew/transporters and the approved paddock
## detail. The sim drives the centre of the 4.6 m fast lane at negative laterals.
##
## Left-side frames: buildings and anything carrying text get the kit's 180-degree
## turn (Layout.side_frame), so +X points away from the track and the text reads
## from the lane; the box frames the crew and the car use (Layout.box_frame) keep
## -Z as the direction of travel and mirror X instead, so the jack man still meets
## the nose. `stall_lane_m` and `garage_front_m` stay magnitudes in those frames.

const Layout := preload("res://scripts/world/circuits/paulistano/paulistano_layout.gd")
const Batch := preload("res://scripts/world/shared/mesh_batch.gd")
const Toon := preload("res://scripts/world/shared/toon_materials.gd")
const Figure := preload("res://scripts/car/pit_crew_figure.gd")
const Liveries := preload("res://scripts/car/team_liveries.gd")
const Signage := preload("res://scripts/world/paddock/team_signage.gd")
const Trucks := preload("res://scripts/world/paddock/team_transporters.gd")
const Building := preload("res://scripts/world/paddock/pit_building.gd")
const Stand := preload("res://scripts/world/paddock/main_grandstand.gd")
const Tower := preload("res://scripts/world/paddock/race_control_tower.gd")
const Gantry := preload("res://scripts/world/shared/start_gantry.gd")
const Corridor := preload("res://scripts/world/circuits/paulistano/paulistano_pit_corridor.gd")
const PaddockDetail := preload("res://scripts/world/circuits/paulistano/paulistano_paddock_detail.gd")

const SIDE: float = Layout.PIT_SIDE
const ENTRY_S: float = Layout.PIT_ENTRY_S
const EXIT_S: float = Layout.PIT_EXIT_S
const LANE_LENGTH_M: float = Layout.PIT_LANE_LENGTH_M
const STALL_PITCH_M: float = Layout.PIT_STALL_PITCH_M
const STALL_FIRST_S: float = Layout.PIT_STALL_FIRST_S
const FAST_LANE_M: float = Layout.PIT_FAST_LANE_M
const FAST_LANE_INNER_M: float = Layout.PIT_FAST_LANE_INNER_M
const BOX_LATERAL_M: float = Layout.PIT_SERVICE_X
const GARAGE_FRONT_M: float = Layout.PIT_FACADE_X
const ENTRY_BLEND_M: float = Layout.PIT_LANE_RAMP_IN_M
const EXIT_BLEND_M: float = Layout.PIT_LANE_RAMP_OUT_M
## Transporters park behind the pit building, on the paddock boulevard.
const TRANSPORTER_LATERAL_M: float = 52.0

var pit_building: Building
var stall_markings: Array[Dictionary] = []
var lighting: Node3D
var _detail_nodes: Array[Node] = []


func _init() -> void:
	team_count = Layout.PIT_STALL_COUNT
	garage_front_m = GARAGE_FRONT_M
	stall_lane_m = BOX_LATERAL_M


## Signed for the sim: the lane runs off the left, so every pit lateral is negative.
func sim_layout() -> Dictionary:
	# The sim measures a box from the entry: first bay s=27 unwrapped on the entry lap.
	var first := (ribbon.length_m if ribbon != null else Layout.LENGTH_M) + STALL_FIRST_S
	return {
		"entry_s": ENTRY_S, "exit_s": EXIT_S, "lane_length_m": LANE_LENGTH_M,
		"stall_first_s": first, "stall_pitch_m": STALL_PITCH_M, "stall_lane_m": SIDE * BOX_LATERAL_M,
		"fast_lane_m": SIDE * FAST_LANE_M, "edge_lateral_m": SIDE * Layout.PIT_EDGE_LATERAL_M,
		"queue_gap_m": Layout.PIT_QUEUE_GAP_M, "lane_ramp_in_m": ENTRY_BLEND_M,
		"lane_ramp_out_m": EXIT_BLEND_M, "speed_limit_mps": 80.0 / 3.6,
	}


## Signed lateral of the pit path `u` metres from the entry (same curve as GtRace.lane_lateral_at).
func lane_lateral(u: float) -> float:
	var blend := minf(smoothstep(0.0, ENTRY_BLEND_M, u), smoothstep(LANE_LENGTH_M, LANE_LENGTH_M - EXIT_BLEND_M, u))
	return SIDE * lerpf(Layout.PIT_EDGE_LATERAL_M, FAST_LANE_M, blend)


func s_from_u_local(u: float) -> float:
	return fposmod(ENTRY_S + u, ribbon.length_m)


func u_from_s(s: float) -> float:
	return fposmod(s - ENTRY_S, ribbon.length_m)


func get_pit_transform(u: float, lateral: float) -> Transform3D:
	return ribbon.get_point_at_offset(s_from_u_local(u), lateral)


func build(p_ribbon: TrackRibbonScript, team_ids: Array[int] = []) -> void:
	if built:
		if not team_ids.is_empty():
			assign_teams(team_ids)
		return
	ribbon = p_ribbon
	built = true
	for i: int in range(team_count):
		var s := Layout.bay_station(i)
		var pose := Layout.box_frame(ribbon, s, BOX_LATERAL_M)
		var socket := Marker3D.new()
		socket.name = "Socket_PitStall_%d" % i
		socket.transform = pose
		add_child(socket)
		stalls.append({"team": i, "s": s, "u": u_from_s(s), "lateral": SIDE * BOX_LATERAL_M, "pose": pose, "node": socket})
		var garage := Node3D.new()
		garage.name = "Garage%02d" % i
		garage.transform = Layout.side_frame(ribbon, s, SIDE, GARAGE_FRONT_M)
		add_child(garage)
		garages.append(garage)
	_build_pavement()
	_build_signs_and_triggers()
	_build_pit_building()
	transporters = Trucks.new()
	transporters.name = "TeamTransporters"
	add_child(transporters)
	transporters.build(ribbon, stalls, SIDE * TRANSPORTER_LATERAL_M, true)
	# The kit stand builds on its local -X; the turn puts it on the right, facing the pit.
	var stand := Stand.new()
	stand.name = "MainGrandstand"
	stand.stand_length_m = Layout.GRANDSTAND_LENGTH_M
	stand.transform = Layout.side_frame(ribbon, Layout.GRANDSTAND_ANCHOR_S, -1.0, 0.0)
	add_child(stand)
	# The kit tower centres itself 24 m along its local +X: turned, that is 25 m to the left.
	var tower := Tower.new()
	tower.name = "RaceControlTower"
	tower.transform = Layout.side_frame(ribbon, Layout.CONTROL_TOWER_S, SIDE, Layout.CONTROL_TOWER_NODE_X)
	tower.position.y += Layout.PIT_APRON_LIFT_M
	add_child(tower)
	# Authored for the left pit (no mirror): the lamps face the grid and the wing covers the lane.
	var gantry := Gantry.new()
	gantry.name = "StartGantry"
	gantry.pit_side = SIDE
	gantry.venue_name = "PAULISTANO SPEED ARENA"
	gantry.transform = ribbon.get_point_at_offset(0.0, 0.0)
	add_child(gantry)
	var seats: Array[int] = team_ids.duplicate()
	if seats.is_empty():
		seats.assign(range(team_count))
	assign_teams(seats)


func _build_pit_building() -> void:
	lighting = Node3D.new()
	lighting.name = "PitWorkingLights"
	add_child(lighting)
	pit_building = Building.new()
	pit_building.name = "PitBuilding"
	pit_building.building_length_m = Layout.PIT_BUILDING_SPAN_M
	pit_building.bay_count = Layout.PIT_STALL_COUNT
	pit_building.bay_stride_m = Layout.PIT_STALL_PITCH_M
	pit_building.front_x = Layout.PIT_FACADE_X
	pit_building.name_doors = false
	pit_building.transform = Layout.side_frame(ribbon, Layout.PIT_BUILDING_CENTRE_S, SIDE, 0.0)
	pit_building.position.y += Layout.PIT_APRON_LIFT_M
	add_child(pit_building)
	for station: float in [40.0, 70.0, 100.0, 130.0]:
		var lamp := OmniLight3D.new()
		lamp.name = "PitLaneLight_%d" % int(station)
		lamp.position = ribbon.get_point_at_offset(station, SIDE * BOX_LATERAL_M).origin + Vector3.UP * 6.2
		lamp.omni_range = 30.0
		lamp.light_energy = 0.9
		lamp.light_color = Color("#fff0d6")
		lamp.shadow_enabled = false
		lighting.add_child(lamp)


## The turned building lays its bays out backwards along the lap: shutter i stands at box (n - 1 - i).
func building_team_order() -> Array[int]:
	var ids: Array[int] = []
	for i: int in range(stalls.size() - 1, -1, -1):
		if int(stalls[i].team) >= 0:
			ids.append(int(stalls[i].team))
	return ids


func _on_teams_assigned() -> void:
	if pit_building == null:
		return
	var paint := Batch.new()
	var signs: RefCounted = Signage.new_batch()
	var plates: Array = []
	var material: Material = Toon.vertex_colored(false)
	stall_markings.clear()
	for i: int in range(stalls.size()):
		var team: int = int(stalls[i].team)
		if team < 0:
			continue
		var garage := garages[i]
		var crew := garage.get_node_or_null("StandbyCrew") as MeshInstance3D
		if crew == null:
			crew = MeshInstance3D.new()
			crew.name = "StandbyCrew"
			garage.add_child(crew)
		var crew_batch := Batch.new()
		var roles := PitKit.standby_roles()
		for slot: int in range(roles.size()):
			Figure.add(crew_batch, material, Transform3D(Basis(Vector3.UP, PI * 0.5), PitKit.standby_spot(slot)), int(roles[slot]), Liveries.color_for(team))
		crew.mesh = crew_batch.commit()
		crew.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		# Box paint carries the seven-segment number: turned frame, so it reads from the lane.
		PitKit.paint_box(paint, material, stalls[i], Layout.side_frame(ribbon, float(stalls[i].s), SIDE, BOX_LATERAL_M), BOX_LATERAL_M, stall_markings)
		plates.append(Signage.add_plate(signs, material, team, Signage.fascia_pose(garage.transform, -0.2, 6.2), 15.5, Liveries.color_for(team)))
	var ids: Array[int] = building_team_order()
	pit_building.apply_teams(ids)
	_rebuild_paddock_detail()
	Signage.commit_node(self, signs, plates)
	var markings := get_node_or_null("PitBoxPaint") as MeshInstance3D
	if markings == null:
		markings = MeshInstance3D.new()
		markings.name = "PitBoxPaint"
		add_child(markings)
	markings.mesh = paint.commit()
	markings.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	transporters.apply_teams(stalls)


## Garage interiors (stripes, carts, engineers) wear the livery of the team seated in each box, so the
## detail is rebuilt with the seats: a race seats its field once, so this runs once or twice per weekend.
func _rebuild_paddock_detail() -> void:
	for node: Node in _detail_nodes:
		if is_instance_valid(node):
			node.free()
	_detail_nodes.clear()
	var teams: Array = []
	for stall: Dictionary in stalls:
		teams.append(int(stall.team))
	var before: Array[Node] = get_children()
	var detail: Dictionary = PaddockDetail.build(self, ribbon, null, teams)
	for child: Node in get_children():
		if not before.has(child):
			_detail_nodes.append(child)
	for key: String in detail:
		set_meta("pit_detail_" + key, detail[key])


func set_lights_on(on: bool) -> void:
	if lighting != null:
		lighting.visible = on


## Working apron under the boxes: concrete from the lane's outer edge to the
## garage front, only across the ten-bay span, lifted the approved 0.07 m.
func _build_pavement() -> void:
	var batch := Batch.new()
	var material: Material = Toon.vertex_colored(false)
	var first := u_from_s(Layout.bay_station(0) - STALL_PITCH_M * 0.5)
	var last := first + STALL_PITCH_M * float(team_count)
	var u := first
	while u < last:
		var a := u
		var b := minf(u + 2.0, last)
		var fa := get_pit_transform(a, 0.0)
		var fb := get_pit_transform(b, 0.0)
		var lift := Vector3.UP * Layout.PIT_APRON_LIFT_M
		var inner_a := fa.origin + fa.basis.x * (SIDE * Layout.PIT_LANE_OUTER_X) + lift
		var inner_b := fb.origin + fb.basis.x * (SIDE * Layout.PIT_LANE_OUTER_X) + lift
		var outer_a := fa.origin + fa.basis.x * (SIDE * Layout.PIT_FACADE_X) + lift
		var outer_b := fb.origin + fb.basis.x * (SIDE * Layout.PIT_FACADE_X) + lift
		batch.quad(material, Color("#6d727c"), inner_a, inner_b, outer_b, outer_a, Vector3.UP)
		u += 2.0
	for lane_name: String in ["PitAsphalt", "PitLaneEdgeLeft", "PitLaneEdgeRight"]:
		var lane_mesh := MeshInstance3D.new()
		lane_mesh.name = lane_name
		add_child(lane_mesh)
	var apron := MeshInstance3D.new()
	apron.name = "PitApron"
	apron.mesh = batch.commit()
	apron.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(apron)
	Corridor.build(self, ribbon, {"entry_s": ENTRY_S, "exit_s": EXIT_S, "side": "left", "fast_lane_m": FAST_LANE_INNER_M}, sim_layout())


func _build_signs_and_triggers() -> void:
	for spec: Array in [["PitEntryTrigger", ENTRY_S], ["PitExitTrigger", EXIT_S]]:
		var trigger := Area3D.new()
		trigger.name = spec[0]
		trigger.transform = ribbon.get_point_at_offset(float(spec[1]), SIDE * Layout.PIT_EDGE_LATERAL_M)
		trigger.monitoring = false
		trigger.set_meta("arc_s", float(spec[1]))
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(4.5, 2.0, 8.0)
		shape.shape = box
		trigger.add_child(shape)
		add_child(trigger)
