class_name ApexPitComplex
extends Node3D

## Pit lane beside the start straight (FASE 5.5, refined after the FASE 10 feedback): a separate 410 m
## lane that peels off the right edge of the circuit at s = 3900 m, passes ten team garages and rejoins the
## same edge at s = 150 m after the line. Positions come from the ribbon, so the pit lane is described by
## `u`, the arc distance from the Pit Entry line, and a lateral offset (+ = right of travel).
## Across the lane, from the circuit outward (all lateral, metres; the circuit edge is at 7.0):
##   7.0 ..  8.25  verge        pit wall (concrete, between the circuit and the fast lane) at 8.5
##   9.3 .. 13.9   fast lane    4.6 m wide, cars run down its middle at 11.6
##  13.9           white line   separates the fast lane from the working lane
##  13.9 .. 20.05  working lane the box car stops on 17.0 (width 2.1 m): 2.05 m of crew room on the lane
##                 side, 2.0 m on the garage side, 3.3 m between a passing car and the box car
##  20.05          garage fascia (the garage front is at 20.6)
## The 80 km/h limiter applies from u = 0 to the Pit Exit line. The GT sim drives its cars along
## lane_lateral_at() and parks them on STALL_LANE_M, so the geometry here and the car paths agree.

const TrackRibbonScript := preload("res://scripts/car/track_ribbon.gd")
const ToonMaterials := preload("res://scripts/world/shared/toon_materials.gd")
const MeshBatchScript := preload("res://scripts/world/shared/mesh_batch.gd")
const FigureScript := preload("res://scripts/car/pit_crew_figure.gd")
const Liveries := preload("res://scripts/car/team_liveries.gd")
const PitKit := preload("res://scripts/world/shared/pit_kit.gd")
const TeamSignage := preload("res://scripts/world/paddock/team_signage.gd")
const TransportersKit := preload("res://scripts/world/paddock/team_transporters.gd")
const EngineScript := preload("res://scripts/core/race_sim_engine.gd")
const RoadShader := preload("res://shaders/road_asphalt.gdshader")

const ENTRY_S: float = 3900.0
const EXIT_S: float = 150.0 # on the lap after the start line
const NOMINAL_LENGTH_M: float = 410.0
const SPEED_LIMIT_MPS: float = 80.0 / 3.6
const TEAM_COUNT: int = 10
const STALL_FIRST_S: float = 3925.0
const STALL_PITCH_M: float = 14.0
const QUEUE_GAP_M: float = 8.0 # a teammate waits this far behind the stall

## Where cars leave and rejoin the circuit: the right half of the track, never the racing line.
const EDGE_LATERAL_M: float = 5.2
const PIT_WALL_M: float = 8.5
const WALL_HALF_THICKNESS_M: float = 0.25
const WALL_HEIGHT_M: float = 1.1
## Fast lane: centre of the cars' path and half the asphalt width.
const FAST_LANE_M: float = 11.6
const LANE_HALF_WIDTH_M: float = 2.3
## Pit box: where the car stops, and how far the garage front stands from the racing line.
const STALL_LANE_M: float = 17.0
const GARAGE_FRONT_M: float = 20.6
## The fascia face stands this far in front of the garage origin.
const FASCIA_SETBACK_M: float = 0.55
const RAMP_IN_M: float = 80.0
const RAMP_OUT_M: float = 90.0
## The asphalt strip starts under the circuit's own surface (left edge) and at its edge (right edge).
const STRIP_START_LEFT_M: float = 6.0
const STRIP_START_RIGHT_M: float = 7.2

const GARAGE_WIDTH_M: float = 12.4
const GARAGE_DEPTH_M: float = 9.0
const GARAGE_HEIGHT_M: float = 4.2
## Where the transporter row stands, measured from the circuit centre line: clear of the pit building and its terrace.
const TRANSPORTER_LATERAL_M: float = 47.0
const STEP_M: float = 2.0
const WALL_STEP_M: float = 3.0
## The wall starts once it can stand this far off the circuit edge.
const WALL_MIN_VERGE_M: float = 1.1
const SURFACE_Y: float = 0.015
const LINE_Y: float = 0.03

const ASPHALT_COLOR := Color("#2a2c33")
const PAINT_WHITE := PitKit.PAINT_WHITE
const PAINT_YELLOW := PitKit.PAINT_YELLOW
const WALL_COLOR := Color("#b9bdc7")
const WALL_COPING_COLOR := Color("#e4e6ec")
const GARAGE_SHELL_COLOR := Color("#2a2d36")
const GARAGE_FLOOR_COLOR := Color("#1c1e25")
const CUSHION_RED := Color("#d9232e")
const CUSHION_WHITE := Color("#f0f2f5")

var ribbon: TrackRibbonScript
## What a crew (and the choreographer) needs to know about this lane's geometry.
var team_count: int = TEAM_COUNT
var garage_front_m: float = GARAGE_FRONT_M
var stall_lane_m: float = STALL_LANE_M
## Arc length of the pit lane in meters, from Pit Entry to Pit Exit.
var length_m: float = NOMINAL_LENGTH_M
var stalls: Array[Dictionary] = [] # per team: {team, s, u, lateral, pose}
var garages: Array[Node3D] = []
var transporters: Node3D
var speed_limit_lines_u: Array[float] = []
## The pit wall pieces' poses and the arc distance each stands at, and the crash cushions at its ends.
var wall_poses: Array[Transform3D] = []
var wall_arcs: Array[float] = []
var wall_end_cushions: Array[Dictionary] = []
## One entry per pit box: {team, number, lateral, half_width, length}.
var stall_markings: Array[Dictionary] = []
var lane_separator_count: int = 0
## Per garage: counts of what it holds (see PitKit.garage_props).
var garage_equipment: Array[Dictionary] = []


## Lateral of the cars' path at `u` for a lane `length` long: from the circuit edge, across the entry road to the
## fast lane, along it, and back across the exit road. The GT sim drives this same curve.
static func lane_lateral_at(u: float, length: float) -> float:
	return lerpf(EDGE_LATERAL_M, FAST_LANE_M, lane_blend(u, length))


## 0 at Pit Entry and Pit Exit, 1 along the full fast lane.
static func lane_blend(u: float, length: float) -> float:
	return minf(smoothstep(0.0, RAMP_IN_M, u), smoothstep(length, length - RAMP_OUT_M, u))


## Builds the lane, garages and markings against `p_ribbon`.
func build(p_ribbon: TrackRibbonScript, team_ids: Array[int] = []) -> void:
	ribbon = p_ribbon
	length_m = fposmod(EXIT_S - ENTRY_S, ribbon.length_m)
	_build_stalls(team_ids)
	_build_asphalt()
	_build_markings()
	_build_pit_wall()
	for stall: Dictionary in stalls:
		garages.append(_build_garage(stall))
	_build_team_plates()
	_build_team_transporters()
	_build_signs()


## Arc distance from Pit Entry for a ribbon distance (wraps over the start line).
func u_from_s(s: float) -> float:
	return fposmod(s - ENTRY_S, ribbon.length_m)


func s_from_u(u: float) -> float:
	return fposmod(ENTRY_S + u, ribbon.length_m)


func lane_lateral(u: float) -> float:
	return lane_lateral_at(u, length_m)


## Left and right edge (lateral) of the pit asphalt at u: a wedge off the circuit edge on the entry road, the
## fast lane, and a wide working lane in front of the boxes.
func lane_edges(u: float) -> Vector2:
	var blend: float = lane_blend(u, length_m)
	var first_u: float = (float(stalls[0]["u"]) - 14.0) if not stalls.is_empty() else (stall_u(0) - 14.0)
	var last_u: float = (float(stalls[stalls.size() - 1]["u"]) + 14.0) if not stalls.is_empty() else (stall_u(TEAM_COUNT - 1) + 14.0)
	var working: float = smoothstep(first_u - 12.0, first_u, u) * smoothstep(last_u + 12.0, last_u, u)
	var fast_right: float = FAST_LANE_M + LANE_HALF_WIDTH_M
	var garage_edge: float = GARAGE_FRONT_M - FASCIA_SETBACK_M - 0.05
	# In front of the boxes the asphalt always reaches the garage, even where the entry road is still
	# ramping away from the circuit (the first boxes stand on the ramp).
	return Vector2(
		lerpf(STRIP_START_LEFT_M, FAST_LANE_M - LANE_HALF_WIDTH_M, blend),
		lerpf(lerpf(STRIP_START_RIGHT_M, fast_right, blend), garage_edge, working))


## World transform of a point in the pit lane: arc distance u, absolute lateral.
func get_pit_transform(u: float, lateral_m: float) -> Transform3D:
	return ribbon.get_point_at_offset(s_from_u(u), lateral_m)


func stall_u(team: int) -> float:
	for stall: Dictionary in stalls:
		if int(stall.get("team", -1)) == team:
			return float(stall["u"])
	return float(stalls[clampi(team, 0, stalls.size() - 1)]["u"]) if not stalls.is_empty() else 0.0


func stall_transform(team: int) -> Transform3D:
	for stall: Dictionary in stalls:
		if int(stall.get("team", -1)) == team:
			return stall["pose"]
	return stalls[clampi(team, 0, stalls.size() - 1)]["pose"] if not stalls.is_empty() else Transform3D.IDENTITY


func garage_for_team(team: int) -> Node3D:
	for i: int in range(stalls.size()):
		if int(stalls[i].get("team", -1)) == team:
			if i < garages.size():
				return garages[i]
	return null


## The crew standing in a box: 13 people, in the order they line up across the garage mouth.
func crew_roles() -> Array:
	return PitKit.standby_roles()


## Where crew member `slot` stands at the garage mouth (garage frame: +x away from the lane).
func crew_spot(slot: int) -> Vector3:
	return PitKit.standby_spot(slot)


func stall_index_for_team(team: int) -> int:
	for i: int in range(stalls.size()):
		if int(stalls[i].get("team", -1)) == team:
			return i
	return -1


## The wall centre's lateral at u (a fixed verge off the lane's left edge, PIT_WALL_M on the full lane).
func wall_lateral(u: float) -> float:
	return lane_edges(u).x - (FAST_LANE_M - LANE_HALF_WIDTH_M - PIT_WALL_M)


func _build_stalls(team_ids: Array[int] = []) -> void:
	stalls.clear()
	var teams: Array[int] = []
	if not team_ids.is_empty():
		for t: int in team_ids:
			teams.append(t)
	else:
		for t: int in range(TEAM_COUNT):
			teams.append(t)
	for i: int in range(mini(TEAM_COUNT, teams.size())):
		var team: int = teams[i]
		var s: float = STALL_FIRST_S + STALL_PITCH_M * float(i)
		stalls.append({
			"stall_index": i, "team": team, "s": s, "u": u_from_s(s), "lateral": STALL_LANE_M,
			"pose": ribbon.get_point_at_offset(s, STALL_LANE_M),
		})


# --- surfaces -----------------------------------------------------------------------------------------

## One asphalt with the circuit: same shader, same vertex colour, one merged surface.
func _build_asphalt() -> void:
	var batch := MeshBatchScript.new()
	var material: ShaderMaterial = PitKit.asphalt_material()
	var left: Callable = func(u: float) -> float: return lane_edges(u).x
	var right: Callable = func(u: float) -> float: return lane_edges(u).y
	_strip(batch, material, ASPHALT_COLOR, SURFACE_Y, 0.0, length_m, left, right)
	var instance := MeshInstance3D.new()
	instance.name = "PitAsphalt"
	instance.mesh = batch.commit()
	instance.material_override = material
	add_child(instance)


## A flat band between two lateral functions of u, from u0 to u1, in MeshBatch quads.
func _strip(batch: MeshBatchScript, material: Material, color: Color, y: float, u0: float, u1: float, left: Callable, right: Callable) -> void:
	var count: int = maxi(1, ceili((u1 - u0) / STEP_M))
	for index: int in range(count):
		var ua: float = lerpf(u0, u1, float(index) / float(count))
		var ub: float = lerpf(u0, u1, float(index + 1) / float(count))
		var left_a: Vector3 = _at(ua, left.call(ua), y)
		var right_a: Vector3 = _at(ua, right.call(ua), y)
		var left_b: Vector3 = _at(ub, left.call(ub), y)
		var right_b: Vector3 = _at(ub, right.call(ub), y)
		batch.quad(material, color, left_a, left_b, right_b, right_a, Vector3.UP)


func _at(u: float, lateral_m: float, y: float) -> Vector3:
	return get_pit_transform(u, lateral_m).origin + Vector3.UP * y


## Painted lines, boxes and numbers in one flat surface.
func _build_markings() -> void:
	var batch := MeshBatchScript.new()
	var paint: ShaderMaterial = ToonMaterials.vertex_colored(false)
	var left: Callable = func(u: float) -> float: return lane_edges(u).x
	var right: Callable = func(u: float) -> float: return lane_edges(u).y
	# Yellow limiter line on the circuit side of the lane, white line on the garage side.
	_strip(batch, paint, PAINT_YELLOW, LINE_Y, 0.0, length_m, func(u: float) -> float: return left.call(u) + 0.25, func(u: float) -> float: return left.call(u) + 0.55)
	_strip(batch, paint, PAINT_WHITE, LINE_Y, 0.0, length_m, func(u: float) -> float: return right.call(u) - 0.55, func(u: float) -> float: return right.call(u) - 0.25)
	# The fast lane / working lane separator runs in front of all ten boxes.
	var first_u: float = (float(stalls[0]["u"]) - 22.0) if not stalls.is_empty() else (stall_u(0) - 22.0)
	var last_u: float = (float(stalls[stalls.size() - 1]["u"]) + 22.0) if not stalls.is_empty() else (stall_u(TEAM_COUNT - 1) + 22.0)
	var separator: float = FAST_LANE_M + LANE_HALF_WIDTH_M
	_strip(batch, paint, PAINT_WHITE, LINE_Y, first_u, last_u, func(_u: float) -> float: return separator - 0.1, func(_u: float) -> float: return separator + 0.1)
	lane_separator_count = 1
	# Yellow stop lines across the lane at Pit Entry and Pit Exit.
	for cross_u: float in [0.0, length_m - 1.5]:
		_strip(batch, paint, PAINT_YELLOW, LINE_Y + 0.003, cross_u, cross_u + 1.5, left, right)
	speed_limit_lines_u = [0.0, length_m - 1.5]
	for stall: Dictionary in stalls:
		PitKit.paint_box(batch, paint, stall, global_transform.affine_inverse() * (stall["pose"] as Transform3D), STALL_LANE_M, stall_markings)
	var instance := MeshInstance3D.new()
	instance.name = "PitMarkings"
	instance.mesh = batch.commit()
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(instance)


# --- pit wall ----------------------------------------------------------------------------------------------

## Concrete wall in the verge between the circuit and the fast lane, ending in a crash cushion at each end.
## It exists only where the lane has drawn far enough away from the circuit to leave room for it.
func _build_pit_wall() -> void:
	var from_u: float = 0.0
	while from_u < length_m and wall_lateral(from_u) < ribbon.road_half_width_m + WALL_MIN_VERGE_M:
		from_u += 1.0
	var to_u: float = length_m
	while to_u > from_u and wall_lateral(to_u) < ribbon.road_half_width_m + WALL_MIN_VERGE_M:
		to_u -= 1.0
	var batch := MeshBatchScript.new()
	var concrete: ShaderMaterial = ToonMaterials.vertex_colored(false)
	var count: int = maxi(1, ceili((to_u - from_u) / WALL_STEP_M))
	var inverse: Transform3D = global_transform.affine_inverse()
	for index: int in range(count + 1):
		var u: float = lerpf(from_u, to_u, float(index) / float(count))
		var pose: Transform3D = get_pit_transform(u, wall_lateral(u))
		wall_poses.append(pose)
		wall_arcs.append(s_from_u(u))
		var local: Transform3D = inverse * pose
		batch.box(concrete, WALL_COLOR, Transform3D(local.basis, local * Vector3(0.0, WALL_HEIGHT_M * 0.5, 0.0)), Vector3(WALL_HALF_THICKNESS_M * 2.0, WALL_HEIGHT_M, WALL_STEP_M + 0.2))
		batch.box(concrete, WALL_COPING_COLOR, Transform3D(local.basis, local * Vector3(0.0, WALL_HEIGHT_M + 0.04, 0.0)), Vector3(WALL_HALF_THICKNESS_M * 2.0 + 0.1, 0.08, WALL_STEP_M + 0.2))
	# Crash cushions: three foam blocks stepping toward the wall, red and white.
	for end: float in [-1.0, 1.0]:
		var u_end: float = from_u - 2.0 if end < 0.0 else to_u + 2.0
		var pose: Transform3D = get_pit_transform(u_end, wall_lateral(clampf(u_end, from_u, to_u)))
		var cushion: Transform3D = inverse * pose
		for block: int in range(3):
			var width: float = 0.5 + 0.18 * float(2 - block)
			batch.box(concrete, CUSHION_RED if block % 2 == 0 else CUSHION_WHITE, Transform3D(cushion.basis, cushion * Vector3(0.0, 0.45, -end * float(block) * 1.1)), Vector3(width, 0.9, 1.0))
		wall_end_cushions.append({"u": u_end, "pose": pose})
	var instance := MeshInstance3D.new()
	instance.name = "PitWall"
	instance.mesh = batch.commit()
	add_child(instance)


# --- garages ---------------------------------------------------------------------------------------------

## One garage: shell (back and side walls, roof, team fascia, floor), its equipment, and the crew standing by,
## each its own merged mesh (the standing crew can be hidden while its animated twin works in the lane).
func _build_garage(stall: Dictionary) -> Node3D:
	var team: int = int(stall.get("team", 0))
	var color: Color = Liveries.color_for(team)
	var garage := Node3D.new()
	garage.name = "Garage%02d" % (team + 1)
	add_child(garage)
	var pose: Transform3D = ribbon.get_point_at_offset(float(stall["s"]), GARAGE_FRONT_M)
	garage.transform = global_transform.affine_inverse() * pose
	var batch := MeshBatchScript.new()
	var cel: ShaderMaterial = ToonMaterials.vertex_colored(true)
	var h: float = GARAGE_HEIGHT_M
	# +X is away from the lane, -Z is the direction of travel.
	batch.box(cel, GARAGE_SHELL_COLOR, Transform3D(Basis.IDENTITY, Vector3(GARAGE_DEPTH_M, h * 0.5, 0.0)), Vector3(0.3, h, GARAGE_WIDTH_M))
	for side: float in [-1.0, 1.0]:
		batch.box(cel, GARAGE_SHELL_COLOR, Transform3D(Basis.IDENTITY, Vector3(GARAGE_DEPTH_M * 0.5, h * 0.5, side * GARAGE_WIDTH_M * 0.5)), Vector3(GARAGE_DEPTH_M, h, 0.3))
	batch.box(cel, GARAGE_SHELL_COLOR, Transform3D(Basis.IDENTITY, Vector3(GARAGE_DEPTH_M * 0.5 - 0.2, h + 0.15, 0.0)), Vector3(GARAGE_DEPTH_M + 0.8, 0.3, GARAGE_WIDTH_M + 0.4))
	batch.box(cel, color, Transform3D(Basis.IDENTITY, Vector3(-0.35, h - 0.35, 0.0)), Vector3(0.4, 1.1, GARAGE_WIDTH_M + 0.4))
	batch.box(cel, GARAGE_FLOOR_COLOR, Transform3D(Basis.IDENTITY, Vector3(GARAGE_DEPTH_M * 0.5, 0.02, 0.0)), Vector3(GARAGE_DEPTH_M, 0.04, GARAGE_WIDTH_M - 0.3))
	garage.add_child(_mesh_node("Body", batch.commit()))
	var props := MeshBatchScript.new()
	var flat: ShaderMaterial = ToonMaterials.vertex_colored(false)
	garage_equipment.append(PitKit.garage_props(props, flat, color))
	garage.add_child(_mesh_node("Props", props.commit()))
	var standby := MeshBatchScript.new()
	var roles: Array = PitKit.standby_roles()
	for slot: int in range(roles.size()):
		FigureScript.add(standby, flat, Transform3D(Basis(Vector3.UP, PI * 0.5), PitKit.standby_spot(slot)), int(roles[slot]), color)
	garage.add_child(_mesh_node("StandbyCrew", standby.commit()))
	return garage


## One transporter per racing team in the open ground behind the pit building (shared TeamTransporters kit).
func _build_team_transporters() -> void:
	transporters = TransportersKit.new()
	transporters.name = "TeamTransporters"
	add_child(transporters)
	transporters.build(ribbon, stalls, TRANSPORTER_LATERAL_M, true)


## Team names on the garage fascias: the shared TeamSignage kit, one mesh for the whole lane.
func _build_team_plates() -> void:
	var batch: RefCounted = TeamSignage.new_batch()
	var flat: ShaderMaterial = ToonMaterials.vertex_colored(false)
	var plates: Array = []
	for index: int in range(garages.size()):
		var team: int = int(stalls[index]["team"])
		var pose: Transform3D = TeamSignage.fascia_pose(garages[index].transform, -0.58, GARAGE_HEIGHT_M - 0.35)
		plates.append(TeamSignage.add_plate(batch, flat, team, pose, GARAGE_WIDTH_M - 1.0, Liveries.color_for(team)))
	TeamSignage.commit_node(self, batch, plates)


func _mesh_node(node_name: String, mesh: ArrayMesh) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.name = node_name
	instance.mesh = mesh
	return instance

## 80 km/h limit signs on posts beside the wall, plus the PIT LANE and PIT EXIT boards.
func _build_signs() -> void:
	var batch := MeshBatchScript.new()
	var flat: ShaderMaterial = ToonMaterials.vertex_colored(false)
	var inverse: Transform3D = global_transform.affine_inverse()
	var wall_from: float = u_from_s(wall_arcs[0])
	var wall_to: float = u_from_s(wall_arcs[wall_arcs.size() - 1])
	for u: float in [wall_from + 6.0, wall_to - 8.0]:
		var pose: Transform3D = inverse * get_pit_transform(u, wall_lateral(u))
		batch.box(flat, WALL_COLOR, Transform3D(pose.basis, pose * Vector3(0.0, WALL_HEIGHT_M + 1.3, 0.0)), Vector3(0.12, 2.6, 0.12))
		# Disc facing the approaching cars (+Z of the pose), on top of the post.
		var disc_basis: Basis = pose.basis * Basis(Vector3.RIGHT, PI * 0.5)
		batch.cylinder(flat, Color("#e0212e"), Transform3D(disc_basis, pose * Vector3(0.0, WALL_HEIGHT_M + 2.7, 0.0) - pose.basis.z * 0.03), 0.55, 0.55, 0.06, 16)
		var text := Label3D.new()
		text.name = "LimitText"
		text.text = "80"
		text.font_size = 128
		text.pixel_size = 0.0065
		text.modulate = Color("#f4f5f7")
		text.transform = pose
		text.position += pose.basis.y * (WALL_HEIGHT_M + 2.7) + pose.basis.z * 0.05
		add_child(text)
	# A yellow board on a post beside the lane at each end of the wall.
	for entry: Array in [["PIT LANE", wall_from + 14.0], ["PIT EXIT", wall_to - 22.0]]:
		var board_u: float = entry[1]
		var board_pose: Transform3D = inverse * get_pit_transform(board_u, wall_lateral(board_u) - 0.9)
		batch.box(flat, Color("#14161c"), Transform3D(board_pose.basis, board_pose * Vector3(0.0, WALL_HEIGHT_M + 1.1, 0.0)), Vector3(0.1, 2.2, 0.1))
		batch.box(flat, Color("#ffd400"), Transform3D(board_pose.basis, board_pose * Vector3(0.0, WALL_HEIGHT_M + 2.5, 0.0)), Vector3(2.4, 0.9, 0.12))
		var board := Label3D.new()
		board.name = "Board%s" % str(entry[0]).replace(" ", "")
		board.text = entry[0]
		board.font_size = 96
		board.pixel_size = 0.0065
		board.modulate = Color("#14161c")
		board.transform = board_pose
		board.position += board_pose.basis.y * (WALL_HEIGHT_M + 2.5) + board_pose.basis.z * 0.07
		add_child(board)
	add_child(_mesh_node("LaneSigns", batch.commit()))
