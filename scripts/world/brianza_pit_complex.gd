class_name BrianzaPitComplex
extends Node3D

## Standard GP Pit Complex for Autodromo di Brianza (Round 03, FASE 13): a 410 m FIA-standard pit lane
## running along the right side of the main straight. Peels off at s = 5 530 m (260 m before the line),
## serves 10 GT3 team garages (14 m pitch), and rejoins at s = 150 m.
##
## Includes the 10 team pit sockets (Socket_PitStall_0..9) for pitstop choreography, pit wall with
## safety debris fence and crash cushion, team garages with liveries, the 2-storey PitBuilding, the
## MainGrandstand with live Jumbotron standings, and RaceControlTower.

const TrackRibbonScript := preload("res://scripts/car/track_ribbon.gd")
const MeshBatchScript := preload("res://scripts/world/mesh_batch.gd")
const ApexPitScript := preload("res://scripts/world/pit_lane_complex.gd")
const FigureScript := preload("res://scripts/car/pit_crew_figure.gd")
const ToonMaterials := preload("res://scripts/world/toon_materials.gd")
const RoadShader := preload("res://shaders/road_asphalt.gdshader")
const PitBuildingKit := preload("res://scripts/world/paddock/pit_building.gd")
const GrandstandKit := preload("res://scripts/world/paddock/main_grandstand.gd")
const ControlTowerKit := preload("res://scripts/world/paddock/race_control_tower.gd")
const Liveries := preload("res://scripts/car/team_liveries.gd")
const TeamSignage := preload("res://scripts/world/paddock/team_signage.gd")
const PitDressing := preload("res://scripts/world/brianza_pit_dressing.gd")
const PaddockScript := preload("res://scripts/world/brianza_paddock.gd")

const LAP_LENGTH_M: float = 5790.0
const ENTRY_S: float = 5530.0 # 260 m before start/finish
const EXIT_S: float = 150.0  # 150 m after start/finish
const LANE_LENGTH_M: float = 410.0
const SPEED_LIMIT_MPS: float = 80.0 / 3.6

const STALL_COUNT: int = 10
const STALL_PITCH_M: float = 14.0
const STALL_FIRST_S: float = 5600.0
const GARAGE_ZONE_M: float = 140.0

const ROAD_EDGE_M: float = 7.0 # half of 14.0 m GP road
const ENTRY_LATERAL_M: float = 5.2
const FAST_LANE_M: float = 11.6
const FAST_LANE_HALF_M: float = 2.3
const PIT_WALL_M: float = 8.5
const WALL_HALF_THICKNESS_M: float = 0.25
const WALL_HEIGHT_M: float = 1.1
const WALL_START_U: float = 25.0
const BOX_LATERAL_M: float = 17.0
const GARAGE_FRONT_M: float = 20.6
const GARAGE_DEPTH_M: float = 9.0
const GARAGE_HEIGHT_M: float = 4.2
const GARAGE_WIDTH_M: float = 12.4
const ENTRY_BLEND_M: float = 80.0
const EXIT_BLEND_M: float = 90.0

const SURFACE_Y: float = 0.015
const LINE_Y: float = 0.03

const ASPHALT_COLOR := Color("#26282e")
const PAINT_WHITE := Color("#f4f5f7")
const PAINT_YELLOW := Color("#ffd400")
const WALL_COLOR := Color("#b9bdc7")
const WALL_COPING := Color("#e4e6ec")
const CUSHION_ORANGE := Color("#ff6a00")
const CUSHION_WHITE := Color("#f0f2f5")
const GARAGE_SHELL := Color("#232630")
const MONZA_RED := Color("#d9232e")

var ribbon: TrackRibbonScript
var team_count: int = STALL_COUNT
var garage_front_m: float = GARAGE_FRONT_M
var stall_lane_m: float = BOX_LATERAL_M
var stalls: Array[Dictionary] = []
var garages: Array[Node3D] = []
var paddock: PaddockScript
var garage_equipment: Array[Dictionary] = []
var stall_markings: Array[Dictionary] = []
var speed_limit_lines_u: Array[float] = []
var lane_separator_count: int = 0
var built: bool = false
var crash_cushion: Node3D
var wall_end_cushions: Array[Dictionary] = []
var fence_poses: Array[Transform3D] = []
var drum_poses: Array[Transform3D] = []
var _solid_footprints: Array[Dictionary] = []
var pit_entry_trigger: Area3D
var pit_exit_trigger: Area3D


static func lane_lateral_at(u: float) -> float:
	if u <= ENTRY_BLEND_M:
		return lerpf(ENTRY_LATERAL_M, FAST_LANE_M, smoothstep(0.0, ENTRY_BLEND_M, u))
	if u <= LANE_LENGTH_M - EXIT_BLEND_M:
		return FAST_LANE_M
	return lerpf(FAST_LANE_M, ENTRY_LATERAL_M, smoothstep(LANE_LENGTH_M - EXIT_BLEND_M, LANE_LENGTH_M, u))


static func s_from_u(u: float) -> float:
	return fposmod(ENTRY_S + u, LAP_LENGTH_M)


func s_from_u_local(u: float) -> float:
	return fposmod(ENTRY_S + u, LAP_LENGTH_M)


func u_from_s(s: float) -> float:
	return fposmod(s - ENTRY_S, LAP_LENGTH_M)


func sim_layout() -> Dictionary:
	return {
		"entry_s": ENTRY_S,
		"exit_s": EXIT_S,
		"lane_length_m": LANE_LENGTH_M,
		"fast_lane_lateral": FAST_LANE_M,
		"box_lateral": BOX_LATERAL_M,
		"stall_first_s": STALL_FIRST_S,
		"stall_pitch_m": STALL_PITCH_M,
		"stall_lane_m": BOX_LATERAL_M,
		"fast_lane_m": FAST_LANE_M,
		"edge_lateral_m": ENTRY_LATERAL_M,
		"queue_gap_m": 8.0,
		"lane_ramp_in_m": ENTRY_BLEND_M,
		"lane_ramp_out_m": EXIT_BLEND_M,
		"stalls": STALL_COUNT,
		"speed_limit_mps": SPEED_LIMIT_MPS,
	}


func ground_platforms() -> Array[Dictionary]:
	var result: Array[Dictionary] = [{"s0": STALL_FIRST_S - 30.0, "s1": STALL_FIRST_S + (STALL_COUNT - 1) * STALL_PITCH_M + 30.0, "side": 1.0, "lateral_from": 7.3, "lateral_to": 31.0, "y_offset": -0.03, "skirt_m": 6.0}]
	if paddock != null and not paddock.platform.is_empty():
		result.append(paddock.platform)
	return result


func get_pit_transform(u: float, lateral: float) -> Transform3D:
	if ribbon == null:
		return Transform3D(Basis.IDENTITY, Vector3(lateral, 0.0, u))
	return ribbon.get_point_at_offset(s_from_u_local(u), lateral)


func build(p_ribbon: TrackRibbonScript, team_ids: Array[int] = []) -> void:
	if built:
		if not team_ids.is_empty():
			for i: int in range(stalls.size()):
				stalls[i]["team"] = team_ids[i] if i < team_ids.size() else -1
			for i: int in range(garages.size()):
				_build_garage_visuals(garages[i], int(stalls[i]["team"]))
			_build_team_plates()
			_build_markings()
			if paddock != null:
				paddock.build(p_ribbon, self, team_ids)
		return
	built = true
	ribbon = p_ribbon
	_build_stalls(team_ids)
	_build_asphalt()
	_build_markings()
	_build_pit_wall()
	var dressing: Dictionary = PitDressing.build(self)
	fence_poses = dressing["fence_poses"]
	drum_poses = dressing["drum_poses"]
	_solid_footprints.append_array(dressing["footprints"])
	_build_lane_signs()
	_build_garages()
	_build_team_plates()
	_build_garage_equipment()
	_build_shared_paddock()
	paddock = PaddockScript.new()
	paddock.name = "BrianzaPaddock"
	add_child(paddock)
	paddock.build(ribbon, self, team_ids)
	_build_entry_sign()
	_build_triggers()


func lane_lateral(u: float) -> float:
	return lane_lateral_at(u)


func lane_edges(u: float) -> Vector2:
	var blend: float = minf(smoothstep(0.0, ENTRY_BLEND_M, u), smoothstep(LANE_LENGTH_M, LANE_LENGTH_M - EXIT_BLEND_M, u))
	var first: float = u_from_s(STALL_FIRST_S) - 14.0
	var last: float = u_from_s(STALL_FIRST_S + float(STALL_COUNT - 1) * STALL_PITCH_M) + 14.0
	var working: float = smoothstep(first - 12.0, first, u) * smoothstep(last + 12.0, last, u)
	return Vector2(lerpf(6.0, FAST_LANE_M - FAST_LANE_HALF_M, blend), lerpf(lerpf(7.2, FAST_LANE_M + FAST_LANE_HALF_M, blend), GARAGE_FRONT_M + 0.05, working))


func wall_lateral(u: float) -> float:
	return lane_edges(u).x - 0.8


func wall_span_u() -> Vector2:
	var start: float = 0.0
	while start < LANE_LENGTH_M and wall_lateral(start) < ROAD_EDGE_M + 1.1:
		start += 1.0
	var end: float = LANE_LENGTH_M
	while end > start and wall_lateral(end) < ROAD_EDGE_M + 1.1:
		end -= 1.0
	return Vector2(start, end)


func solid_footprints() -> Array[Dictionary]:
	return _solid_footprints


func stall_index_for_team(team: int) -> int:
	for i: int in range(stalls.size()):
		if int(stalls[i]["team"]) == team:
			return i
	return -1


func stall_transform(team: int) -> Transform3D:
	var index: int = stall_index_for_team(team)
	return stalls[index]["pose"] if index >= 0 else Transform3D.IDENTITY


func garage_for_team(team: int) -> Node3D:
	var index: int = stall_index_for_team(team)
	return garages[index] if index >= 0 and index < garages.size() else null


func crew_roles() -> Array:
	return ApexPitScript.standby_roles()


func crew_spot(slot: int) -> Vector3:
	return ApexPitScript.standby_spot(slot)


func _build_stalls(team_ids: Array[int] = []) -> void:
	stalls.clear()
	for index: int in range(STALL_COUNT):
		var s: float = STALL_FIRST_S + float(index) * STALL_PITCH_M
		var u: float = u_from_s(s)
		var pose: Transform3D = get_pit_transform(u, BOX_LATERAL_M)
		var socket := Node3D.new()
		socket.name = "Socket_PitStall_%d" % index
		socket.transform = pose
		socket.set_meta(&"stall_index", index)
		socket.set_meta(&"arc_s", s)
		socket.set_meta(&"u", u)
		socket.set_meta(&"lateral_m", BOX_LATERAL_M)
		add_child(socket)
		stalls.append({
			"index": index,
			"team": index if team_ids.is_empty() else (team_ids[index] if index < team_ids.size() else -1),
			"s": s,
			"u": u,
			"lateral": BOX_LATERAL_M,
			"pose": pose,
			"node": socket,
		})


func _build_asphalt() -> void:
	var batch := MeshBatchScript.new()
	var material: ShaderMaterial = ApexPitScript.asphalt_material()
	var steps: int = ceili(LANE_LENGTH_M / 3.0)
	for i: int in range(steps):
		var u0: float = float(i) * 3.0
		var u1: float = minf(float(i + 1) * 3.0, LANE_LENGTH_M)
		var edges0: Vector2 = lane_edges(u0)
		var edges1: Vector2 = lane_edges(u1)
		var t0_inner: Vector3 = get_pit_transform(u0, edges0.x).origin + Vector3.UP * SURFACE_Y
		var t0_outer: Vector3 = get_pit_transform(u0, edges0.y).origin + Vector3.UP * SURFACE_Y
		var t1_inner: Vector3 = get_pit_transform(u1, edges1.x).origin + Vector3.UP * SURFACE_Y
		var t1_outer: Vector3 = get_pit_transform(u1, edges1.y).origin + Vector3.UP * SURFACE_Y
		batch.quad(material, ASPHALT_COLOR, t0_inner, t0_outer, t1_outer, t1_inner, Vector3.UP)
	var mesh_inst := MeshInstance3D.new()
	mesh_inst.name = "PitAsphalt"
	mesh_inst.mesh = batch.commit()
	mesh_inst.material_override = material
	add_child(mesh_inst)


func _build_markings() -> void:
	stall_markings.clear()
	speed_limit_lines_u.clear()
	var batch := MeshBatchScript.new()
	var material: Material = ToonMaterials.vertex_colored(false)
	var left: Callable = func(u: float) -> float: return lane_edges(u).x
	var right: Callable = func(u: float) -> float: return lane_edges(u).y
	_marking_strip(batch, material, PAINT_YELLOW, 0.0, LANE_LENGTH_M, func(u: float) -> float: return left.call(u) + 0.25, func(u: float) -> float: return left.call(u) + 0.55)
	_marking_strip(batch, material, PAINT_WHITE, 0.0, LANE_LENGTH_M, func(u: float) -> float: return right.call(u) - 0.55, func(u: float) -> float: return right.call(u) - 0.25)
	_marking_strip(batch, material, PAINT_WHITE, float(stalls[0]["u"]) - 22.0, float(stalls[-1]["u"]) + 22.0, func(_u: float) -> float: return FAST_LANE_M + FAST_LANE_HALF_M - 0.1, func(_u: float) -> float: return FAST_LANE_M + FAST_LANE_HALF_M + 0.1)
	lane_separator_count = 1
	for u: float in [0.0, LANE_LENGTH_M - 1.5]:
		_marking_strip(batch, material, PAINT_YELLOW, u, u + 1.5, left, right)
		speed_limit_lines_u.append(u)
	var painter := ApexPitScript.new()
	add_child(painter)
	for stall: Dictionary in stalls:
		painter._paint_box(batch, material, stall)
	stall_markings = painter.stall_markings.duplicate(true)
	painter.free()
	var inst: MeshInstance3D = get_node_or_null("PitMarkings") as MeshInstance3D
	if inst == null:
		inst = MeshInstance3D.new()
		inst.name = "PitMarkings"
		add_child(inst)
	inst.mesh = batch.commit()


func _marking_strip(batch: MeshBatchScript, material: Material, color: Color, u0: float, u1: float, left: Callable, right: Callable) -> void:
	var count: int = maxi(1, ceili((u1 - u0) / 3.0))
	for i: int in range(count):
		var a: float = lerpf(u0, u1, float(i) / float(count))
		var b: float = lerpf(u0, u1, float(i + 1) / float(count))
		var p0: Vector3 = get_pit_transform(a, left.call(a)).origin + Vector3.UP * LINE_Y
		var p1: Vector3 = get_pit_transform(a, right.call(a)).origin + Vector3.UP * LINE_Y
		var p2: Vector3 = get_pit_transform(b, right.call(b)).origin + Vector3.UP * LINE_Y
		var p3: Vector3 = get_pit_transform(b, left.call(b)).origin + Vector3.UP * LINE_Y
		batch.quad(material, color, p0, p1, p2, p3, Vector3.UP)


func _build_pit_wall() -> void:
	var batch := MeshBatchScript.new()
	var material: Material = ToonMaterials.vertex_colored(false)
	var span: Vector2 = wall_span_u()
	var steps: int = ceili((span.y - span.x) / 4.0)
	for i: int in range(steps):
		var u0: float = lerpf(span.x, span.y, float(i) / float(steps))
		var u1: float = lerpf(span.x, span.y, float(i + 1) / float(steps))
		var p0: Transform3D = get_pit_transform(u0, wall_lateral(u0))
		var p1: Transform3D = get_pit_transform(u1, wall_lateral(u1))
		p0.origin += Vector3.UP * (WALL_HEIGHT_M * 0.5)
		p1.origin += Vector3.UP * (WALL_HEIGHT_M * 0.5)
		var mid: Transform3D = p0.interpolate_with(p1, 0.5)
		batch.box(material, WALL_COLOR, mid, Vector3(WALL_HALF_THICKNESS_M * 2.0, WALL_HEIGHT_M, p0.origin.distance_to(p1.origin)))
		_solid_footprints.append({"name": "wall", "u0": u0, "u1": u1, "lat0": minf(wall_lateral(u0), wall_lateral(u1)) - WALL_HALF_THICKNESS_M, "lat1": maxf(wall_lateral(u0), wall_lateral(u1)) + WALL_HALF_THICKNESS_M})
	for u: float in [span.x, span.y]:
		var pose: Transform3D = get_pit_transform(u, wall_lateral(u))
		var blocks: Array[Transform3D] = []
		for block: int in range(3):
			var offset: float = float(block) * 0.8 * (-1.0 if u == span.x else 1.0)
			var block_pose: Transform3D = get_pit_transform(u + offset, wall_lateral(u))
			block_pose.origin += Vector3.UP * 0.45
			blocks.append(block_pose)
			batch.box(material, CUSHION_ORANGE if block % 2 == 0 else CUSHION_WHITE, block_pose, Vector3(0.65, 0.9, 0.7))
		wall_end_cushions.append({"u": u, "pose": pose, "blocks": blocks})
		_solid_footprints.append({"name": "cushion", "u0": u - 2.0 if u == span.x else u, "u1": u if u == span.x else u + 2.0, "lat0": wall_lateral(u) - 0.325, "lat1": wall_lateral(u) + 0.325})
	var inst := MeshInstance3D.new()
	inst.name = "PitWall"
	inst.mesh = batch.commit()
	add_child(inst)


func _build_lane_signs() -> void:
	var batch := MeshBatchScript.new()
	var material: Material = ToonMaterials.vertex_colored(false)
	var span: Vector2 = wall_span_u()
	for spec: Array in [["PIT LANE", span.x + 14.0], ["PIT EXIT", span.y - 22.0], ["80", span.x + 6.0], ["80", span.y - 8.0]]:
		var pose: Transform3D = get_pit_transform(float(spec[1]), wall_lateral(float(spec[1])) - 0.9)
		batch.box(material, WALL_COLOR, Transform3D(pose.basis, pose * Vector3(0.0, 2.1, 0.0)), Vector3(0.12, 2.2, 0.12))
		batch.box(material, PAINT_YELLOW, Transform3D(pose.basis, pose * Vector3(0.0, 3.25, 0.0)), Vector3(2.4, 0.9, 0.12))
		var label := Label3D.new()
		label.name = "Board" + String(spec[0]).replace(" ", "")
		label.text = String(spec[0])
		label.font_size = 96
		label.pixel_size = 0.0065
		label.modulate = Color("#14161c")
		label.transform = pose
		label.position += pose.basis.y * 3.25 + pose.basis.z * 0.07
		add_child(label)
	var node := MeshInstance3D.new()
	node.name = "LaneSigns"
	node.mesh = batch.commit()
	add_child(node)


func _build_crash_cushion() -> void:
	var nose_pose: Transform3D = get_pit_transform(WALL_START_U, PIT_WALL_M)
	var cushion := Node3D.new()
	cushion.name = "CrashCushion"
	cushion.transform = nose_pose
	var batch := MeshBatchScript.new()
	var mat: Material = ToonMaterials.vertex_colored(false)
	for k: int in range(4):
		var offset: float = float(k) * 0.75
		var col: Color = CUSHION_ORANGE if (k % 2 == 0) else CUSHION_WHITE
		batch.box(mat, col, Transform3D(Basis.IDENTITY, Vector3(0.0, 0.45, -offset)), Vector3(0.65, 0.9, 0.7))
	var mesh_inst := MeshInstance3D.new()
	mesh_inst.mesh = batch.commit()
	cushion.add_child(mesh_inst)
	add_child(cushion)
	crash_cushion = cushion


func _build_garages() -> void:
	garages.clear()
	for index: int in range(STALL_COUNT):
		var stall: Dictionary = stalls[index]
		var u: float = float(stall["u"])
		var g_pose: Transform3D = get_pit_transform(u, GARAGE_FRONT_M)
		var garage_node := Node3D.new()
		garage_node.name = "Garage_%d" % index
		garage_node.transform = g_pose
		_build_garage_visuals(garage_node, int(stall["team"]))
		add_child(garage_node)
		garages.append(garage_node)


func _build_garage_visuals(garage_node: Node3D, team: int) -> void:
	var batch := MeshBatchScript.new()
	var mat: Material = ToonMaterials.vertex_colored(false)
	batch.box(mat, GARAGE_SHELL, Transform3D(Basis.IDENTITY, Vector3(GARAGE_DEPTH_M - 0.2, GARAGE_HEIGHT_M * 0.5, 0.0)), Vector3(0.4, GARAGE_HEIGHT_M, GARAGE_WIDTH_M))
	for side: float in [-1.0, 1.0]:
		batch.box(mat, GARAGE_SHELL, Transform3D(Basis.IDENTITY, Vector3(GARAGE_DEPTH_M * 0.5, GARAGE_HEIGHT_M * 0.5, side * GARAGE_WIDTH_M * 0.5)), Vector3(GARAGE_DEPTH_M, GARAGE_HEIGHT_M, 0.3))
	batch.box(mat, GARAGE_SHELL, Transform3D(Basis.IDENTITY, Vector3(GARAGE_DEPTH_M * 0.5, GARAGE_HEIGHT_M, 0.0)), Vector3(GARAGE_DEPTH_M, 0.3, GARAGE_WIDTH_M))
	var team_col: Color = Liveries.color_for(team)
	batch.box(mat, team_col, Transform3D(Basis.IDENTITY, Vector3(0.0, GARAGE_HEIGHT_M - 0.4, 0.0)), Vector3(0.3, 0.8, GARAGE_WIDTH_M))
	var shell: MeshInstance3D = garage_node.get_node_or_null("GarageShell") as MeshInstance3D
	if shell == null:
		shell = MeshInstance3D.new()
		shell.name = "GarageShell"
		garage_node.add_child(shell)
	shell.mesh = batch.commit()
	var standby := MeshBatchScript.new()
	var roles: Array = crew_roles()
	for slot: int in range(roles.size()):
		FigureScript.add(standby, mat, Transform3D(Basis(Vector3.UP, PI * 0.5), crew_spot(slot)), int(roles[slot]), team_col)
	var crew: MeshInstance3D = garage_node.get_node_or_null("StandbyCrew") as MeshInstance3D
	if crew == null:
		crew = MeshInstance3D.new()
		crew.name = "StandbyCrew"
		garage_node.add_child(crew)
	crew.mesh = standby.commit()


## Team names on the garage fascias: the shared TeamSignage kit, one mesh for the whole lane.
func _build_team_plates() -> void:
	var batch: RefCounted = TeamSignage.new_batch()
	var flat: Material = ToonMaterials.vertex_colored(false)
	var plates: Array = []
	for index: int in range(garages.size()):
		var team: int = int(stalls[index]["team"])
		var pose: Transform3D = TeamSignage.fascia_pose(garages[index].transform, -0.2, GARAGE_HEIGHT_M - 0.4)
		# The building's shutter hoods cover the ends of the fascia: keep the name in the middle ~7 m.
		plates.append(TeamSignage.add_plate(batch, flat, team, pose, 7.0, Liveries.color_for(team)))
	TeamSignage.commit_node(self, batch, plates)


func _build_garage_equipment() -> void:
	var source := ApexPitScript.new()
	var batch := MeshBatchScript.new()
	var material: Material = ToonMaterials.vertex_colored(false)
	batch.quad(material, Color("#30343b"), Vector3(0.0, 0.02, -GARAGE_WIDTH_M * 0.5), Vector3(GARAGE_DEPTH_M, 0.02, -GARAGE_WIDTH_M * 0.5), Vector3(GARAGE_DEPTH_M, 0.02, GARAGE_WIDTH_M * 0.5), Vector3(0.0, 0.02, GARAGE_WIDTH_M * 0.5), Vector3.UP)
	var equipment: Dictionary = source._garage_props(batch, material, Liveries.color_for(0))
	source.free()
	var instances := MultiMesh.new()
	instances.transform_format = MultiMesh.TRANSFORM_3D
	instances.mesh = batch.commit()
	instances.instance_count = garages.size()
	for index: int in range(garages.size()):
		instances.set_instance_transform(index, garages[index].transform)
		garage_equipment.append(equipment.duplicate())
	var node := MultiMeshInstance3D.new()
	node.name = "GarageEquipment"
	node.multimesh = instances
	add_child(node)


func _build_shared_paddock() -> void:
	var centre_u: float = u_from_s(STALL_FIRST_S + float(STALL_COUNT) * STALL_PITCH_M * 0.5)
	var pose: Transform3D = get_pit_transform(centre_u, 0.0)
	
	# PitBuilding
	var building := PitBuildingKit.new()
	building.name = "PitBuilding"
	building.building_length_m = 148.0
	building.bay_count = STALL_COUNT
	building.bay_stride_m = STALL_PITCH_M
	building.front_x = 18.0
	building.garage_top_y = 4.6
	building.accent_color = MONZA_RED
	building.transform = pose
	add_child(building)
	
	# MainGrandstand on the opposite side of the track
	var stand := GrandstandKit.new()
	stand.name = "MainGrandstand"
	stand.stand_length_m = 160.0
	stand.accent_color = MONZA_RED
	stand.transform = ribbon.get_point_at_offset(160.0, -(ROAD_EDGE_M + 12.0))
	add_child(stand)
	
	# RaceControlTower
	var tower := ControlTowerKit.new()
	tower.name = "RaceControlTower"
	tower.accent_color = MONZA_RED
	tower.transform = pose
	tower.position += pose.basis.z * -85.0
	add_child(tower)


func _build_entry_sign() -> void:
	var batch := MeshBatchScript.new()
	var mat: Material = ToonMaterials.vertex_colored(false)
	var board_pose: Transform3D = get_pit_transform(10.0, FAST_LANE_M)
	board_pose.origin += Vector3.UP * 5.4
	batch.box(mat, Color("#15202b"), board_pose, Vector3(5.0, 1.2, 0.2))
	var mi := MeshInstance3D.new()
	mi.name = "PitEntrySignMesh"
	mi.mesh = batch.commit()
	add_child(mi)


func _build_triggers() -> void:
	pit_entry_trigger = _trigger("PitEntryTrigger", 0.0, ENTRY_LATERAL_M, Vector3(4.5, 2.0, 8.0))
	pit_exit_trigger = _trigger("PitExitTrigger", LANE_LENGTH_M, ENTRY_LATERAL_M, Vector3(4.5, 2.0, 8.0))


func _trigger(node_name: String, u: float, lateral_m: float, size: Vector3) -> Area3D:
	var area := Area3D.new()
	area.name = node_name
	area.transform = get_pit_transform(u, lateral_m)
	area.monitoring = false
	area.set_meta(&"arc_s", s_from_u_local(u))
	area.set_meta(&"lateral_m", lateral_m)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	area.add_child(shape)
	add_child(area)
	return area
