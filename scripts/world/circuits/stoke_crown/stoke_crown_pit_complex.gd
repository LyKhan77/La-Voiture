class_name StokeCrownPitComplex
extends "res://scripts/world/circuits/base/circuit_pit_complex.gd"

const Layout := preload("res://scripts/world/circuits/stoke_crown/stoke_crown_layout.gd")
const Batch := preload("res://scripts/world/shared/mesh_batch.gd")
const Toon := preload("res://scripts/world/shared/toon_materials.gd")
const Figure := preload("res://scripts/car/pit_crew_figure.gd")
const Liveries := preload("res://scripts/car/team_liveries.gd")
const Signage := preload("res://scripts/world/paddock/team_signage.gd")
const Trucks := preload("res://scripts/world/paddock/team_transporters.gd")
const Building := preload("res://scripts/world/circuits/stoke_crown/stoke_crown_pit_building.gd")
const Stand := preload("res://scripts/world/paddock/main_grandstand.gd")
const Tower := preload("res://scripts/world/paddock/race_control_tower.gd")
const Gantry := preload("res://scripts/world/shared/start_gantry.gd")
const SteelFence := preload("res://scripts/world/circuits/stoke_crown/stoke_crown_steel_fence.gd")
const ENTRY_S: float = 5020.0
const EXIT_S: float = 240.0
const LANE_LENGTH_M: float = 420.0
const STALL_PITCH_M: float = 20.0
const STALL_FIRST_S: float = 30.0
const FAST_LANE_M: float = 10.8
const BOX_LATERAL_M: float = 16.5
const GARAGE_FRONT_M: float = 25.0
const ENTRY_BLEND_M: float = 80.0
const EXIT_BLEND_M: float = 30.0
var building: Building
var stall_markings: Array[Dictionary] = []
var lighting: Node3D

func _init() -> void:
	team_count = 10
	garage_front_m = GARAGE_FRONT_M
	stall_lane_m = BOX_LATERAL_M

func sim_layout() -> Dictionary:
	# Sim boxes use the entry's unwrapped lap; the visible first bay is s=30 after the seam.
	var first := (ribbon.length_m if ribbon != null else 5200.13427734375) + STALL_FIRST_S
	return {"entry_s": ENTRY_S, "exit_s": EXIT_S, "lane_length_m": LANE_LENGTH_M, "stall_first_s": first,
		"stall_pitch_m": STALL_PITCH_M, "stall_lane_m": BOX_LATERAL_M, "fast_lane_m": FAST_LANE_M,
		"edge_lateral_m": 5.2, "queue_gap_m": 8.0, "lane_ramp_in_m": ENTRY_BLEND_M, "lane_ramp_out_m": EXIT_BLEND_M}

func lane_lateral(u: float) -> float:
	var blend := minf(smoothstep(0.0, ENTRY_BLEND_M, u), smoothstep(LANE_LENGTH_M, LANE_LENGTH_M - EXIT_BLEND_M, u))
	return lerpf(5.2, FAST_LANE_M, blend)

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
		var s := STALL_FIRST_S + float(i) * STALL_PITCH_M
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
	building = Building.new()
	building.name = "PitBuilding"
	building.transform = ribbon.get_point_at_offset(120.0, GARAGE_FRONT_M)
	building.position.y -= 0.14
	add_child(building)
	building.build()
	transporters = Trucks.new()
	transporters.name = "TeamTransporters"
	add_child(transporters)
	transporters.build(ribbon, stalls, 49.0, true)
	var stand := Stand.new()
	stand.name = "MainGrandstand"
	stand.stand_length_m = 240.0
	stand.transform = ribbon.get_point_at_offset(90.0, 0.0)
	add_child(stand)
	var tower := Tower.new()
	tower.name = "RaceControlTower"
	tower.transform = ribbon.get_point_at_offset(232.0, 32.0 - Tower.CENTRE_X_M)
	add_child(tower)
	var gantry := Gantry.new()
	gantry.name = "StartGantry"
	gantry.transform = ribbon.get_point_at_offset(0.0, 0.0)
	add_child(gantry)
	lighting = Node3D.new()
	lighting.name = "PitWorkingLights"
	add_child(lighting)
	for station: float in [50.0, 90.0, 130.0, 170.0]:
		var lamp := OmniLight3D.new()
		lamp.position = ribbon.get_point_at_offset(station, BOX_LATERAL_M).origin + Vector3.UP * 6.2
		lamp.omni_range = 24.0
		lamp.light_energy = 0.9
		lamp.light_color = Color("#fff0d6")
		lamp.shadow_enabled = false
		lighting.add_child(lamp)
	var seats: Array[int] = team_ids.duplicate()
	if seats.is_empty():
		seats.assign(range(10))
	assign_teams(seats)

func _on_teams_assigned() -> void:
	if building == null:
		return
	var ids: Array[int] = []
	var paint := Batch.new()
	var signs: RefCounted = Signage.new_batch()
	var plates: Array = []
	var material: Material = Toon.vertex_colored(false)
	stall_markings.clear()
	for i: int in range(stalls.size()):
		var team: int = int(stalls[i].team)
		ids.append(team)
		var garage := garages[i]
		var crew := garage.get_node_or_null("StandbyCrew") as MeshInstance3D
		if crew == null:
			crew = MeshInstance3D.new()
			crew.name = "StandbyCrew"
			garage.add_child(crew)
		var batch := Batch.new()
		var roles := PitKit.standby_roles()
		for slot: int in range(roles.size()):
			Figure.add(batch, material, Transform3D(Basis(Vector3.UP, PI * 0.5), PitKit.standby_spot(slot)), int(roles[slot]), Liveries.color_for(team))
		crew.mesh = batch.commit()
		crew.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		PitKit.paint_box(paint, material, stalls[i], stalls[i].pose, BOX_LATERAL_M, stall_markings)
		plates.append(Signage.add_plate(signs, material, team, Signage.fascia_pose(garage.transform, -0.2, 6.2), 15.5, Liveries.color_for(team)))
	building.apply_teams(ids)
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
	lighting.visible = on

func _build_pavement() -> void:
	var batch := Batch.new()
	var wall := Batch.new()
	var material: Material = Toon.vertex_colored(false)
	var fence_frames: Array[Transform3D] = []
	for u: int in range(-65, 485, 2):
		var a := float(u)
		var b := a + 2.0
		var outer_a := _outer_edge(a)
		var outer_b := _outer_edge(b)
		batch.quad(material, Color("#26282e"), _at(a, 6.9, 0.015), _at(b, 6.9, 0.015), _at(b, outer_b, 0.015), _at(a, outer_a, 0.015), Vector3.UP)
		if a >= ENTRY_BLEND_M + 4.0 and b <= LANE_LENGTH_M - EXIT_BLEND_M - 12.0:
			var pose := get_pit_transform((a + b) * 0.5, 8.3)
			pose.origin.y += 0.675
			wall.box(material, Color("#c8cbd0"), pose, Vector3(0.3, 1.35, 2.02))
			pose.origin.y += 0.69
			wall.box(material, Color("#e0212e") if u % 4 == 0 else Color("#f4f5f7"), pose, Vector3(0.36, 0.06, 2.02))
			if u % 4 == 0:
				var frame := get_pit_transform(a + 2.0, 8.3)
				frame.origin.y += 1.38
				fence_frames.append(frame)
	for entry: Array in [["PitAsphalt", batch.commit()], ["PitWall", wall.commit()]]:
		var node := MeshInstance3D.new()
		node.name = entry[0]
		node.mesh = entry[1]
		if node.name == "PitAsphalt":
			node.material_override = PitKit.asphalt_material()
		add_child(node)
	SteelFence.build(self, fence_frames)

func _at(u: float, lateral: float, height: float) -> Vector3:
	return get_pit_transform(u, lateral).origin + Vector3.UP * height

func _outer_edge(u: float) -> float:
	if u < 0.0:
		return lerpf(7.0, 13.1, smoothstep(-65.0, 0.0, u))
	if u > LANE_LENGTH_M:
		return lerpf(13.1, 7.0, smoothstep(LANE_LENGTH_M, LANE_LENGTH_M + 65.0, u))
	var first := u_from_s(STALL_FIRST_S)
	var last := first + 9.0 * STALL_PITCH_M
	var apron := smoothstep(first - 35.0, first - 15.0, u) * (1.0 - smoothstep(last + 8.0, last + 30.0, u))
	return lerpf(13.1, GARAGE_FRONT_M, apron)

func _build_signs_and_triggers() -> void:
	for spec: Array in [["PIT IN", ENTRY_S - 24.0], ["80", ENTRY_S - 8.0], ["PIT OUT", EXIT_S + 16.0]]:
		var holder := Node3D.new()
		holder.name = "Sign_" + String(spec[0]).replace(" ", "_")
		holder.transform = ribbon.get_point_at_offset(float(spec[1]), 14.8)
		add_child(holder)
		var batch := Batch.new()
		var material: Material = Toon.vertex_colored(false)
		batch.box(material, Color("#5d6570"), Transform3D(Basis.IDENTITY, Vector3(0.0, 1.5, 0.0)), Vector3(0.1, 3.0, 0.1))
		batch.box(material, Color("#15202b"), Transform3D(Basis.IDENTITY, Vector3(0.0, 2.7, 0.0)), Vector3(2.6, 1.05, 0.1))
		var mesh := MeshInstance3D.new()
		mesh.mesh = batch.commit()
		holder.add_child(mesh)
		var label := Label3D.new()
		label.text = spec[0]
		label.font_size = 72
		label.pixel_size = 0.012
		label.position = Vector3(0.0, 2.7, 0.06)
		label.outline_size = 6
		holder.add_child(label)
	for spec: Array in [["PitEntryTrigger", ENTRY_S], ["PitExitTrigger", EXIT_S]]:
		var trigger := Area3D.new()
		trigger.name = spec[0]
		trigger.transform = ribbon.get_point_at_offset(float(spec[1]), 5.2)
		trigger.monitoring = false
		trigger.set_meta("arc_s", float(spec[1]))
		trigger.set_meta("lateral_m", 5.2)
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(4.5, 2.0, 8.0)
		shape.shape = box
		trigger.add_child(shape)
		add_child(trigger)
