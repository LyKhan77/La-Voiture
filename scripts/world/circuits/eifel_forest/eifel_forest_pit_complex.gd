class_name EifelForestPitComplex
extends "res://scripts/world/circuits/base/circuit_pit_complex.gd"

## Eifel Forest Ring pit lane: 410 m right-hand lane, entry s=4950, exit s=210,
## ten 14 m boxes (bay i at s = 57 + 14 i), service bay 5 at s=127, the 140 m
## 2F/10-garage FIA pit building at s=120, 240 m main grandstand on the left,
## race control at s=25, start gantry, team fascia/crew/transporters, and the
## approved paddock detail. The sim drives the centre of the 4.6 m fast lane.

const Layout := preload("res://scripts/world/circuits/eifel_forest/eifel_forest_layout.gd")
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
const Corridor := preload("res://scripts/world/circuits/eifel_forest/eifel_forest_pit_corridor.gd")
const PaddockDetail := preload("res://scripts/world/circuits/eifel_forest/eifel_forest_paddock_detail.gd")

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

var pit_building: Building
var stall_markings: Array[Dictionary] = []
var lighting: Node3D


func _init() -> void:
	team_count = Layout.PIT_STALL_COUNT
	garage_front_m = GARAGE_FRONT_M
	stall_lane_m = BOX_LATERAL_M


func sim_layout() -> Dictionary:
	# The sim measures a box from the entry: first bay s=57 unwrapped on the entry lap.
	var first := (ribbon.length_m if ribbon != null else Layout.LENGTH_M) + STALL_FIRST_S
	return {
		"entry_s": ENTRY_S, "exit_s": EXIT_S, "lane_length_m": LANE_LENGTH_M,
		"stall_first_s": first, "stall_pitch_m": STALL_PITCH_M, "stall_lane_m": BOX_LATERAL_M,
		"fast_lane_m": FAST_LANE_M, "edge_lateral_m": Layout.PIT_EDGE_LATERAL_M,
		"queue_gap_m": Layout.PIT_QUEUE_GAP_M, "lane_ramp_in_m": ENTRY_BLEND_M,
		"lane_ramp_out_m": EXIT_BLEND_M, "speed_limit_mps": 80.0 / 3.6,
	}


func lane_lateral(u: float) -> float:
	var blend := minf(smoothstep(0.0, ENTRY_BLEND_M, u), smoothstep(LANE_LENGTH_M, LANE_LENGTH_M - EXIT_BLEND_M, u))
	return lerpf(Layout.PIT_EDGE_LATERAL_M, FAST_LANE_M, blend)


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
		var pose := ribbon.get_point_at_offset(s, BOX_LATERAL_M)
		var socket := Marker3D.new()
		socket.name = "Socket_PitStall_%d" % i
		socket.transform = pose
		add_child(socket)
		stalls.append({"team": i, "s": s, "u": u_from_s(s), "lateral": BOX_LATERAL_M, "pose": pose, "node": socket})
		var garage := Node3D.new()
		garage.name = "Garage%02d" % i
		garage.transform = ribbon.get_point_at_offset(s, GARAGE_FRONT_M)
		add_child(garage)
		garages.append(garage)
	_build_pavement()
	_build_signs_and_triggers()
	_build_pit_building()
	transporters = Trucks.new()
	transporters.name = "TeamTransporters"
	add_child(transporters)
	transporters.build(ribbon, stalls, 52.0, true)
	var stand := Stand.new()
	stand.name = "MainGrandstand"
	stand.stand_length_m = Layout.GRANDSTAND_LENGTH_M
	stand.transform = ribbon.get_point_at_offset(Layout.GRANDSTAND_ANCHOR_S, 0.0)
	add_child(stand)
	var tower := Tower.new()
	tower.name = "RaceControlTower"
	tower.transform = ribbon.get_point_at_offset(Layout.CONTROL_TOWER_S, Layout.CONTROL_TOWER_NODE_X)
	add_child(tower)
	var gantry := Gantry.new()
	gantry.name = "StartGantry"
	gantry.transform = ribbon.get_point_at_offset(0.0, 0.0)
	add_child(gantry)
	if gantry.has_method("set_lights"):
		gantry.call("set_lights", 5)
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
	pit_building.transform = ribbon.get_point_at_offset(Layout.PIT_BUILDING_CENTRE_S, 0.0)
	pit_building.position.y += Layout.PIT_APRON_LIFT_M
	add_child(pit_building)
	var detail: Dictionary = PaddockDetail.build(self, ribbon, null)
	for key: String in detail:
		set_meta("pit_detail_" + key, detail[key])
	for station: float in [70.0, 110.0, 150.0, 190.0]:
		var lamp := OmniLight3D.new()
		lamp.name = "PitLaneLight_%d" % int(station)
		lamp.position = ribbon.get_point_at_offset(station, BOX_LATERAL_M).origin + Vector3.UP * 6.2
		lamp.omni_range = 30.0
		lamp.light_energy = 0.9
		lamp.light_color = Color("#fff0d6")
		lamp.shadow_enabled = false
		lighting.add_child(lamp)


func _on_teams_assigned() -> void:
	if pit_building == null:
		return
	var ids: Array[int] = []
	var paint := Batch.new()
	var signs: RefCounted = Signage.new_batch()
	var plates: Array = []
	var material: Material = Toon.vertex_colored(false)
	stall_markings.clear()
	for i: int in range(stalls.size()):
		var team: int = int(stalls[i].team)
		if team < 0:
			continue
		ids.append(team)
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
		PitKit.paint_box(paint, material, stalls[i], stalls[i].pose, BOX_LATERAL_M, stall_markings)
		plates.append(Signage.add_plate(signs, material, team, Signage.fascia_pose(garage.transform, -0.2, 6.2), 15.5, Liveries.color_for(team)))
	pit_building.apply_teams(ids)
	Signage.commit_node(self, signs, plates)
	var markings := get_node_or_null("PitBoxPaint") as MeshInstance3D
	if markings == null:
		markings = MeshInstance3D.new()
		markings.name = "PitBoxPaint"
		add_child(markings)
	markings.mesh = paint.commit()
	markings.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	transporters.apply_teams(stalls)


func set_lights_on(on: bool) -> void:
	if lighting != null:
		lighting.visible = on


## Working apron under the boxes: concrete from the lane's outer edge to the
## garage front, only across the ten-bay span, lifted the approved 0.07 m.
func _build_pavement() -> void:
	var batch := Batch.new()
	var material: Material = Toon.vertex_colored(false)
	var first := Layout.bay_station(0) - STALL_PITCH_M * 0.5
	var last := Layout.bay_station(team_count - 1) + STALL_PITCH_M * 0.5
	var u := first
	while u < last:
		var a := u
		var b := minf(u + 2.0, last)
		var fa := get_pit_transform(a, 0.0)
		var fb := get_pit_transform(b, 0.0)
		var inner_a := fa.origin + fa.basis.x * Layout.PIT_LANE_OUTER_X + Vector3.UP * Layout.PIT_APRON_LIFT_M
		var inner_b := fb.origin + fb.basis.x * Layout.PIT_LANE_OUTER_X + Vector3.UP * Layout.PIT_APRON_LIFT_M
		var outer_a := fa.origin + fa.basis.x * Layout.PIT_FACADE_X + Vector3.UP * Layout.PIT_APRON_LIFT_M
		var outer_b := fb.origin + fb.basis.x * Layout.PIT_FACADE_X + Vector3.UP * Layout.PIT_APRON_LIFT_M
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
	Corridor.build(self, ribbon, {"entry_s": ENTRY_S, "exit_s": EXIT_S, "side": "right", "fast_lane_m": FAST_LANE_INNER_M}, sim_layout())


func _build_signs_and_triggers() -> void:
	for spec: Array in [["PitEntryTrigger", ENTRY_S], ["PitExitTrigger", EXIT_S]]:
		var trigger := Area3D.new()
		trigger.name = spec[0]
		trigger.transform = ribbon.get_point_at_offset(float(spec[1]), Layout.PIT_EDGE_LATERAL_M)
		trigger.monitoring = false
		trigger.set_meta("arc_s", float(spec[1]))
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(4.5, 2.0, 8.0)
		shape.shape = box
		trigger.add_child(shape)
		add_child(trigger)


## Outer edge of the paved apron for the terrain gate: the garage front across
## the boxes, the lane's outer edge at both mouths.
func _outer_edge(u: float) -> float:
	var first := Layout.bay_station(0) - STALL_PITCH_M * 0.5
	var last := Layout.bay_station(team_count - 1) + STALL_PITCH_M * 0.5
	var apron := smoothstep(first - 35.0, first - 15.0, u) * (1.0 - smoothstep(last + 18.0, last + 40.0, u))
	return lerpf(Layout.PIT_LANE_OUTER_X, Layout.PIT_FACADE_X, apron)


func _inner_edge(_u: float) -> float:
	return FAST_LANE_INNER_M
