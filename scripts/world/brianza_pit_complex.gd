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
const ToonMaterials := preload("res://scripts/world/toon_materials.gd")
const RoadShader := preload("res://shaders/road_asphalt.gdshader")
const PitBuildingKit := preload("res://scripts/world/paddock/pit_building.gd")
const GrandstandKit := preload("res://scripts/world/paddock/main_grandstand.gd")
const ControlTowerKit := preload("res://scripts/world/paddock/race_control_tower.gd")
const Liveries := preload("res://scripts/car/team_liveries.gd")

const LAP_LENGTH_M: float = 5790.0
const ENTRY_S: float = 5530.0 # 260 m before start/finish
const EXIT_S: float = 150.0  # 150 m after start/finish
const LANE_LENGTH_M: float = 410.0
const SPEED_LIMIT_MPS: float = 80.0 / 3.6

const STALL_COUNT: int = 10
const STALL_PITCH_M: float = 14.0
const STALL_FIRST_S: float = 5555.0
const GARAGE_ZONE_M: float = 140.0

const ROAD_EDGE_M: float = 7.0 # half of 14.0 m GP road
const ENTRY_LATERAL_M: float = 6.0
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
const ENTRY_BLEND_M: float = 35.0
const EXIT_BLEND_M: float = 45.0

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
var built: bool = false
var crash_cushion: Node3D
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
		"stalls": STALL_COUNT,
		"speed_limit_mps": SPEED_LIMIT_MPS,
	}


func get_pit_transform(u: float, lateral: float) -> Transform3D:
	if ribbon == null:
		return Transform3D(Basis.IDENTITY, Vector3(lateral, 0.0, u))
	return ribbon.get_point_at_offset(s_from_u_local(u), lateral)


func build(p_ribbon: TrackRibbonScript) -> void:
	if built:
		return
	built = true
	ribbon = p_ribbon
	_build_stalls()
	_build_asphalt()
	_build_markings()
	_build_pit_wall()
	_build_crash_cushion()
	_build_garages()
	_build_shared_paddock()
	_build_entry_sign()
	_build_triggers()


func _build_stalls() -> void:
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
			"s": s,
			"u": u,
			"lateral": BOX_LATERAL_M,
			"pose": pose,
			"node": socket,
		})


func _build_asphalt() -> void:
	var batch := MeshBatchScript.new()
	var material: Material = ToonMaterials.vertex_colored(false)
	var steps: int = ceili(LANE_LENGTH_M / 3.0)
	for i: int in range(steps):
		var u0: float = float(i) * 3.0
		var u1: float = minf(float(i + 1) * 3.0, LANE_LENGTH_M)
		var t0_inner: Vector3 = get_pit_transform(u0, ROAD_EDGE_M).origin + Vector3.UP * SURFACE_Y
		var t0_outer: Vector3 = get_pit_transform(u0, GARAGE_FRONT_M + 1.0).origin + Vector3.UP * SURFACE_Y
		var t1_inner: Vector3 = get_pit_transform(u1, ROAD_EDGE_M).origin + Vector3.UP * SURFACE_Y
		var t1_outer: Vector3 = get_pit_transform(u1, GARAGE_FRONT_M + 1.0).origin + Vector3.UP * SURFACE_Y
		batch.quad(material, ASPHALT_COLOR, t0_inner, t0_outer, t1_outer, t1_inner, Vector3.UP)
	var mesh_inst := MeshInstance3D.new()
	mesh_inst.name = "PitAsphalt"
	mesh_inst.mesh = batch.commit()
	add_child(mesh_inst)


func _build_markings() -> void:
	var batch := MeshBatchScript.new()
	var material: Material = ToonMaterials.vertex_colored(false)
	for stall: Dictionary in stalls:
		var u: float = float(stall["u"])
		var box_centre: Vector3 = get_pit_transform(u, BOX_LATERAL_M).origin + Vector3.UP * LINE_Y
		var t_fwd: Vector3 = get_pit_transform(u, BOX_LATERAL_M).basis.z
		var t_rgt: Vector3 = get_pit_transform(u, BOX_LATERAL_M).basis.x
		var half_l: float = 3.2
		var half_w: float = 1.6
		var p0: Vector3 = box_centre - t_fwd * half_l - t_rgt * half_w
		var p1: Vector3 = box_centre - t_fwd * half_l + t_rgt * half_w
		var p2: Vector3 = box_centre + t_fwd * half_l + t_rgt * half_w
		var p3: Vector3 = box_centre + t_fwd * half_l - t_rgt * half_w
		batch.quad(material, PAINT_YELLOW, p0, p1, p1 + t_fwd * 0.15, p0 + t_fwd * 0.15, Vector3.UP)
		batch.quad(material, PAINT_YELLOW, p3 - t_fwd * 0.15, p2 - t_fwd * 0.15, p2, p3, Vector3.UP)
		batch.quad(material, PAINT_YELLOW, p0, p0 + t_rgt * 0.15, p3 + t_rgt * 0.15, p3, Vector3.UP)
		batch.quad(material, PAINT_YELLOW, p1 - t_rgt * 0.15, p1, p2, p2 - t_rgt * 0.15, Vector3.UP)
	var inst := MeshInstance3D.new()
	inst.name = "PitMarkings"
	inst.mesh = batch.commit()
	add_child(inst)


func _build_pit_wall() -> void:
	var batch := MeshBatchScript.new()
	var material: Material = ToonMaterials.vertex_colored(false)
	var steps: int = ceili((LANE_LENGTH_M - WALL_START_U - 15.0) / 4.0)
	for i: int in range(steps):
		var u0: float = WALL_START_U + float(i) * 4.0
		var u1: float = minf(WALL_START_U + float(i + 1) * 4.0, LANE_LENGTH_M - 15.0)
		var p0: Transform3D = get_pit_transform(u0, PIT_WALL_M)
		var p1: Transform3D = get_pit_transform(u1, PIT_WALL_M)
		p0.origin += Vector3.UP * (WALL_HEIGHT_M * 0.5)
		p1.origin += Vector3.UP * (WALL_HEIGHT_M * 0.5)
		var mid: Transform3D = p0.interpolate_with(p1, 0.5)
		batch.box(material, WALL_COLOR, mid, Vector3(WALL_HALF_THICKNESS_M * 2.0, WALL_HEIGHT_M, p0.origin.distance_to(p1.origin)))
	var inst := MeshInstance3D.new()
	inst.name = "PitWall"
	inst.mesh = batch.commit()
	add_child(inst)


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
		var g_pose: Transform3D = get_pit_transform(u, GARAGE_FRONT_M + GARAGE_DEPTH_M * 0.5)
		var garage_node := Node3D.new()
		garage_node.name = "Garage_%d" % index
		garage_node.transform = g_pose
		
		var batch := MeshBatchScript.new()
		var mat: Material = ToonMaterials.vertex_colored(false)
		# Garage box shell
		batch.box(mat, GARAGE_SHELL, Transform3D(Basis.IDENTITY, Vector3(0.0, GARAGE_HEIGHT_M * 0.5, 0.0)), Vector3(GARAGE_DEPTH_M, GARAGE_HEIGHT_M, GARAGE_WIDTH_M))
		# Fascia header with team color
		var team_col: Color = Liveries.color_for(index)
		batch.box(mat, team_col, Transform3D(Basis.IDENTITY, Vector3(-GARAGE_DEPTH_M * 0.5, GARAGE_HEIGHT_M - 0.4, 0.0)), Vector3(0.3, 0.8, GARAGE_WIDTH_M))
		
		var mi := MeshInstance3D.new()
		mi.mesh = batch.commit()
		garage_node.add_child(mi)
		add_child(garage_node)
		garages.append(garage_node)


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
	stand.transform = pose
	stand.position -= pose.basis.x * (ROAD_EDGE_M + 12.0)
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
