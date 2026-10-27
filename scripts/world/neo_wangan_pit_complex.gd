class_name NeoWanganPitComplex
extends Node3D

## The FIA pit connection of the Neo-Wangan street circuit (FASE 12, Task 3): a 140 m fast lane
## hanging off the right-hand edge of the last straight, ten 12 m team boxes, a concrete pit wall
## with an orange impact attenuator on its nose, and a pit exit that runs on the inside of Turn 1
## behind an 80 m solid blend line — so a car leaving the pits can never meet a car on the racing
## line T-bone first.
##
## Arc distances are the circuit's own (`ENTRY_S` on the lap, the exit 65 m into the next one).
## Laterals are metres right of the racing line, and the fast lane is the 4.5 m between
## FAST_LANE_M -/+ H: 6.25 .. 10.75, clear of the 5.75 m road edge and of the pit wall at 6.0.
##
## Across the pit lane, from the circuit outward (metres):
##   5.75        circuit asphalt edge
##   6.00        pit wall (0.5 thick, 1.2 high); its nose carries the crash cushion
##   6.25 .. 10.75  fast lane, 4.5 m, cars run down its middle at 8.5
##   10.75 .. 16.0  working lane, the box car stops at 13.0
##   16.0 .. 25.0   ten garages, 12 m apart on the 12 m stall pitch

const TrackRibbonScript := preload("res://scripts/car/track_ribbon.gd")
const MeshBatchScript := preload("res://scripts/world/mesh_batch.gd")
const ApexPitScript := preload("res://scripts/world/pit_lane_complex.gd")
const ToonMaterials := preload("res://scripts/world/toon_materials.gd")
const RoadShader := preload("res://shaders/road_asphalt.gdshader")
const PitBuildingKit := preload("res://scripts/world/paddock/pit_building.gd")
const GrandstandKit := preload("res://scripts/world/paddock/main_grandstand.gd")
const ControlTowerKit := preload("res://scripts/world/paddock/race_control_tower.gd")
const Liveries := preload("res://scripts/car/team_liveries.gd")

## The circuit's homologated lap (see NeoWanganCircuitBuilder.LENGTH_M; repeated here so this
## script stays free of a circular preload with the builder).
const LAP_LENGTH_M: float = 3150.0
const ENTRY_S: float = 3075.0 # 75 m before the start/finish line
const EXIT_S: float = 65.0 # 65 m after the line, at the entry to Turn 1
const LANE_LENGTH_M: float = 140.0
const BYPASS_MERGE_S: float = 145.0 # rejoin past Turn 1 (apex at 120)
const BYPASS_RAMP_M: float = 65.0 # from 80 m to 145 m
const BLEND_LINE_M: float = 80.0 # from the pit exit to the merge
const SPEED_LIMIT_MPS: float = 80.0 / 3.6

const STALL_COUNT: int = 10
const STALL_PITCH_M: float = 12.0
const STALL_FIRST_OFFSET_M: float = 8.0 # from Pit Entry
const GARAGE_ZONE_M: float = 140.0

const ENTRY_LATERAL_M: float = 5.2 # the pit entry trigger, on the right edge of the road
const FAST_LANE_M: float = 8.5
const FAST_LANE_HALF_M: float = 2.25
const FAST_LANE_WIDTH_M: float = FAST_LANE_HALF_M * 2.0
const PIT_WALL_M: float = 6.0
const WALL_HALF_THICKNESS_M: float = 0.25
const WALL_HEIGHT_M: float = 1.2
const WALL_START_U: float = 18.0
const BOX_LATERAL_M: float = 13.0
const GARAGE_FRONT_M: float = 16.0
const GARAGE_DEPTH_M: float = 9.0
const GARAGE_HEIGHT_M: float = 4.4
const GARAGE_PITCH_M: float = STALL_PITCH_M
const GARAGE_WIDTH_M: float = 11.4
const ENTRY_BLEND_M: float = 20.0
const EXIT_BLEND_M: float = 80.0
const ROAD_EDGE_M: float = 5.75 # half of the circuit's 11.5 m road

const SURFACE_Y: float = 0.015
const LINE_Y: float = 0.03
const STEP_M: float = 2.0

const ASPHALT_COLOR := Color("#26282e")
const PAINT_WHITE := Color("#f4f5f7")
const PAINT_YELLOW := Color("#ffd400")
const WALL_COLOR := Color("#b9bdc7")
const WALL_COPING := Color("#e4e6ec")
const CUSHION_ORANGE := Color("#ff6a00")
const CUSHION_WHITE := Color("#f0f2f5")
const GARAGE_SHELL := Color("#232630")
## Vertex alpha is the cel shader's glow mask: 0 = fully self-lit (see anime_cel_vertex_color).
const GARAGE_GLASS := Color(0.0, 0.82, 1.0, 0.28)
const GARAGE_LED := Color(1.0, 0.12, 0.48, 0.0)

var ribbon: TrackRibbonScript
## What a crew (and the choreographer) needs to know about this lane's geometry.
var team_count: int = STALL_COUNT
var garage_front_m: float = GARAGE_FRONT_M
var stall_lane_m: float = BOX_LATERAL_M
var stalls: Array[Dictionary] = [] # {index, s, u, lateral, pose, node}
var garages: Array[Node3D] = []
var built: bool = false
## The pit wall's arc span and the crash cushion standing on its nose.
var wall_arcs: Array[float] = []
var crash_cushion: Node3D
var pit_entry_trigger: Area3D
var pit_exit_trigger: Area3D
var bypass_ramp: Node3D
var blend_line: MeshInstance3D
var asphalt: MeshInstance3D
var garage_zone_length_m: float = GARAGE_ZONE_M


## Lateral of the cars' path at `u` metres from Pit Entry: off the road edge onto the fast lane,
## along it, then back across the merge.
static func lane_lateral_at(u: float) -> float:
	if u <= ENTRY_BLEND_M:
		return lerpf(ENTRY_LATERAL_M, FAST_LANE_M, smoothstep(0.0, ENTRY_BLEND_M, u))
	if u <= LANE_LENGTH_M:
		return FAST_LANE_M
	return lerpf(FAST_LANE_M, ENTRY_LATERAL_M, smoothstep(LANE_LENGTH_M, merge_u(), u))


static func s_from_u(u: float) -> float:
	return fposmod(ENTRY_S + u, LAP_LENGTH_M)


## u of the pit exit trigger (the end of the 140 m lane).
static func exit_u() -> float:
	return LANE_LENGTH_M


## u where the exit lane has fully merged back onto the racing line, past Turn 1.
static func merge_u() -> float:
	return LANE_LENGTH_M + EXIT_BLEND_M


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
	_build_triggers()
	_build_bypass_ramp()
	# Garage glass and LED strips are glow-masked vertices: light them like the city around them.
	ToonMaterials.set_glow_energy(1.6)


func u_from_s(s: float) -> float:
	return fposmod(s - ENTRY_S, ribbon.length_m)


func s_from_u_local(u: float) -> float:
	return fposmod(ENTRY_S + u, ribbon.length_m)


func lane_lateral(u: float) -> float:
	return lane_lateral_at(u)


func get_pit_transform(u: float, lateral_m: float) -> Transform3D:
	return ribbon.get_point_at_offset(s_from_u_local(u), lateral_m)


func stall_transform(team: int) -> Transform3D:
	for stall: Dictionary in stalls:
		if int(stall["index"]) == team:
			return stall["pose"]
	return stalls[clampi(team, 0, stalls.size() - 1)]["pose"] if not stalls.is_empty() else Transform3D.IDENTITY


## The crew standing in a box: the Apex Ring's 13-person line-up, fitted to this lane's apron.
func crew_roles() -> Array:
	return ApexPitScript.standby_roles()


## Where crew member `slot` stands at the garage mouth (garage frame: +x away from the lane).
func crew_spot(slot: int) -> Vector3:
	var count: int = crew_roles().size()
	return Vector3(1.5, 0.0, (float(slot) - float(count - 1) * 0.5) * 0.88)


func stall_index_for_team(team: int) -> int:
	return clampi(team, 0, STALL_COUNT - 1)


func garage_for_team(team: int) -> Node3D:
	var index: int = stall_index_for_team(team)
	return garages[index] if index >= 0 and index < garages.size() else null


## The layout the GT sim drives this pit lane with (see GtRace.default_pit_layout for the Apex
## version): entry at Pit Entry, exit at the merge past Turn 1, ten 12 m boxes, and a 20 m / 80 m
## lateral blend. RaceWeekendWorld hands this to GtRace for a Neo-Wangan race.
func sim_layout() -> Dictionary:
	return {
		"entry_s": ENTRY_S,
		"exit_s": BYPASS_MERGE_S,
		"stall_first_s": s_from_u_local(STALL_FIRST_OFFSET_M),
		"stall_pitch_m": STALL_PITCH_M,
		"stall_lane_m": BOX_LATERAL_M,
		"fast_lane_m": FAST_LANE_M,
		"edge_lateral_m": ENTRY_LATERAL_M,
		"queue_gap_m": 8.0,
		"lane_ramp_in_m": ENTRY_BLEND_M,
		"lane_ramp_out_m": EXIT_BLEND_M,
		"lane_length_m": LANE_LENGTH_M,
		"speed_limit_mps": SPEED_LIMIT_MPS,
		"blend_line_m": BLEND_LINE_M,
		"merge_s": BYPASS_MERGE_S,
	}


static func asphalt_material() -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = RoadShader
	return material


# --- build -----------------------------------------------------------------------------------------

func _build_stalls() -> void:
	stalls.clear()
	var root := get_node_or_null("Stalls") as Node3D
	if root == null:
		root = Node3D.new()
		root.name = "Stalls"
		add_child(root)
	for index: int in range(STALL_COUNT):
		var u: float = STALL_FIRST_OFFSET_M + STALL_PITCH_M * float(index)
		var s: float = s_from_u_local(u)
		var marker := Marker3D.new()
		marker.name = "Socket_PitStall_%d" % index
		marker.transform = ribbon.get_point_at_offset(s, BOX_LATERAL_M)
		root.add_child(marker)
		stalls.append({
			"index": index, "s": s, "u": u, "lateral": BOX_LATERAL_M,
			"pose": marker.transform, "node": marker,
		})


## The pit asphalt: entry road, 4.5 m fast lane, working lane and the merge back onto the circuit.
func _build_asphalt() -> void:
	asphalt = MeshInstance3D.new()
	asphalt.name = "PitAsphalt"
	asphalt.mesh = _lane_surface(SURFACE_Y)
	asphalt.material_override = asphalt_material()
	add_child(asphalt)


## One asphalt band between two lateral functions of u, from the entry to the merge.
func _lane_surface(y: float) -> ArrayMesh:
	var batch := MeshBatchScript.new()
	var material: Material = ToonMaterials.vertex_colored(false)
	var steps: int = maxi(1, ceili(merge_u() / STEP_M))
	for index: int in range(steps):
		var ua: float = merge_u() * float(index) / float(steps)
		var ub: float = merge_u() * float(index + 1) / float(steps)
		var left_a: float = _surface_left(ua)
		var right_a: float = _surface_right(ua)
		var left_b: float = _surface_left(ub)
		var right_b: float = _surface_right(ub)
		batch.quad(material, ASPHALT_COLOR,
			_at(ua, left_a, y), _at(ub, left_b, y), _at(ub, right_b, y), _at(ua, right_a, y), Vector3.UP)
	return batch.commit()


## Working lane and the fast lane, on the road's edge at the entry mouth.
func _surface_left(u: float) -> float:
	return lerpf(ROAD_EDGE_M, FAST_LANE_M - FAST_LANE_HALF_M, smoothstep(0.0, ENTRY_BLEND_M, u)) if u <= LANE_LENGTH_M \
		else lerpf(FAST_LANE_M - FAST_LANE_HALF_M, ROAD_EDGE_M, smoothstep(LANE_LENGTH_M, merge_u(), u))


func _surface_right(u: float) -> float:
	return lerpf(GARAGE_FRONT_M, FAST_LANE_M + FAST_LANE_HALF_M, smoothstep(0.0, ENTRY_BLEND_M, u)) if u <= LANE_LENGTH_M \
		else FAST_LANE_M + FAST_LANE_HALF_M


func _at(u: float, lateral_m: float, y: float) -> Vector3:
	return get_pit_transform(u, lateral_m).origin + Vector3.UP * y


func _build_markings() -> void:
	var batch := MeshBatchScript.new()
	var paint: Material = ToonMaterials.vertex_colored(false)
	var add_band := func(u0: float, u1: float, left: Callable, right: Callable, color: Color, y: float) -> void:
		var steps: int = maxi(1, ceili((u1 - u0) / STEP_M))
		for index: int in range(steps):
			var ua: float = lerpf(u0, u1, float(index) / float(steps))
			var ub: float = lerpf(u0, u1, float(index + 1) / float(steps))
			batch.quad(paint, color,
				_at(ua, left.call(ua), y), _at(ub, left.call(ub), y),
				_at(ub, right.call(ub), y), _at(ua, right.call(ua), y), Vector3.UP)
	# The fast lane's two limits: yellow on the pit wall side, white on the working lane side.
	add_band.call(2.0, LANE_LENGTH_M, func(u: float) -> float: return _surface_left(u) + 0.25, func(u: float) -> float: return _surface_left(u) + 0.55, PAINT_YELLOW, LINE_Y)
	add_band.call(ENTRY_BLEND_M, LANE_LENGTH_M, func(_u: float) -> float: return FAST_LANE_M + FAST_LANE_HALF_M - 0.55, func(_u: float) -> float: return FAST_LANE_M + FAST_LANE_HALF_M - 0.25, PAINT_WHITE, LINE_Y)
	# Yellow limiter lines across the lane at Pit Entry and Pit Exit.
	add_band.call(0.0, 1.2, func(u: float) -> float: return _surface_left(u), func(u: float) -> float: return _surface_right(u), PAINT_YELLOW, LINE_Y + 0.004)
	add_band.call(LANE_LENGTH_M - 1.2, LANE_LENGTH_M, func(u: float) -> float: return _surface_left(u), func(u: float) -> float: return _surface_right(u), PAINT_YELLOW, LINE_Y + 0.004)
	var mesh := MeshInstance3D.new()
	mesh.name = "PitMarkings"
	mesh.mesh = batch.commit()
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mesh)
	blend_line = MeshInstance3D.new()
	blend_line.name = "BlendLine"
	var line_batch := MeshBatchScript.new()
	var line_steps: int = ceili(BLEND_LINE_M / STEP_M)
	for index: int in range(line_steps):
		var ua: float = LANE_LENGTH_M + BLEND_LINE_M * float(index) / float(line_steps)
		var ub: float = LANE_LENGTH_M + BLEND_LINE_M * float(index + 1) / float(line_steps)
		line_batch.quad(paint, PAINT_WHITE,
			_at(ua, ROAD_EDGE_M - 0.45, LINE_Y + 0.006), _at(ub, ROAD_EDGE_M - 0.45, LINE_Y + 0.006),
			_at(ub, ROAD_EDGE_M - 0.15, LINE_Y + 0.006), _at(ua, ROAD_EDGE_M - 0.15, LINE_Y + 0.006), Vector3.UP)
	blend_line.mesh = line_batch.commit()
	blend_line.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	blend_line.set_meta(&"blend_line_m", BLEND_LINE_M)
	add_child(blend_line)


## The concrete pit wall between the circuit and the fast lane, on the 1.2 m regulation height, plus
## the hazard copings. One merged mesh, one draw call.
func _build_pit_wall() -> void:
	var batch := MeshBatchScript.new()
	var concrete: Material = ToonMaterials.vertex_colored(false)
	var steps: int = ceili((LANE_LENGTH_M - WALL_START_U) / STEP_M)
	wall_arcs.clear()
	for index: int in range(steps):
		var ua: float = WALL_START_U + (LANE_LENGTH_M - WALL_START_U) * float(index) / float(steps)
		var ub: float = WALL_START_U + (LANE_LENGTH_M - WALL_START_U) * float(index + 1) / float(steps)
		var a: Vector3 = _at(ua, PIT_WALL_M, 0.0)
		var b: Vector3 = _at(ub, PIT_WALL_M, 0.0)
		var half: Vector3 = Vector3.UP * WALL_HEIGHT_M * 0.5
		var side: Vector3 = (b - a).cross(Vector3.UP).normalized() * WALL_HALF_THICKNESS_M
		batch.quad(concrete, WALL_COLOR, a - side + half, b - side + half, b + side + half, a + side + half, Vector3.UP)
		batch.quad(concrete, WALL_COPING, a - side + half, b - side + half, b - side - half, a - side - half, -side)
		batch.quad(concrete, WALL_COPING, a + side - half, b + side - half, b + side + half, a + side + half, side)
		if index == 0:
			batch.quad(concrete, WALL_COLOR, a - side, a + side, a + side + half, a - side + half, (b - a).normalized() * -1.0)
		if index == steps - 1:
			batch.quad(concrete, WALL_COLOR, b - side, b + side, b + side + half, b - half + side, (b - a).normalized())
		wall_arcs.append(s_from_u_local(ua))
	var mesh := MeshInstance3D.new()
	mesh.name = "PitWall"
	mesh.mesh = batch.commit()
	add_child(mesh)


## The orange impact attenuator on the pit wall's nose: an FIA-style crash cushion with white bands.
func _build_crash_cushion() -> void:
	var batch := MeshBatchScript.new()
	var orange: Material = ToonMaterials.vertex_colored(false)
	var pose: Transform3D = get_pit_transform(WALL_START_U - 1.2, PIT_WALL_M)
	pose.origin += Vector3.UP * 0.55
	batch.box(orange, CUSHION_ORANGE, Transform3D(pose.basis, pose.origin), Vector3(1.1, 1.1, 2.4))
	for band: int in range(3):
		var offset: Vector3 = pose.basis.z * (0.55 - float(band) * 0.55)
		batch.box(orange, CUSHION_WHITE, Transform3D(pose.basis, pose.origin + offset), Vector3(1.14, 1.16, 0.22))
	crash_cushion = MeshInstance3D.new()
	crash_cushion.name = "CrashCushion"
	(crash_cushion as MeshInstance3D).mesh = batch.commit()
	crash_cushion.set_meta(&"attenuator_color", CUSHION_ORANGE)
	crash_cushion.set_meta(&"fia_standard", true)
	add_child(crash_cushion)


## Ten team garages on the 12 m stall pitch, each a low box with a glowing frontage.
func _build_garages() -> void:
	garages.clear()
	var batch := MeshBatchScript.new()
	var shell: Material = ToonMaterials.vertex_colored(false)
	for index: int in range(STALL_COUNT):
		var u: float = STALL_FIRST_OFFSET_M + STALL_PITCH_M * float(index)
		var pose: Transform3D = get_pit_transform(u, GARAGE_FRONT_M + GARAGE_DEPTH_M * 0.5)
		var basis: Basis = pose.basis
		var centre: Vector3 = pose.origin + Vector3.UP * GARAGE_HEIGHT_M * 0.5
		# Open garage mouth; side walls, rear wall and roof leave equipment visible.
		for side: float in [-1.0, 1.0]:
			batch.box(shell, GARAGE_SHELL, Transform3D(basis, centre + basis.z * side * GARAGE_WIDTH_M * 0.5), Vector3(GARAGE_DEPTH_M, GARAGE_HEIGHT_M, 0.22))
		batch.box(shell, GARAGE_SHELL, Transform3D(basis, centre + basis.x * GARAGE_DEPTH_M * 0.5), Vector3(0.22, GARAGE_HEIGHT_M, GARAGE_WIDTH_M))
		batch.box(shell, GARAGE_SHELL, Transform3D(basis, centre + Vector3.UP * GARAGE_HEIGHT_M * 0.5), Vector3(GARAGE_DEPTH_M, 0.2, GARAGE_WIDTH_M))
		var front: Vector3 = get_pit_transform(u, GARAGE_FRONT_M - 0.06).origin + Vector3.UP * GARAGE_HEIGHT_M * 0.52
		batch.box(shell, GARAGE_GLASS, Transform3D(basis, front + Vector3.UP * 1.5), Vector3(0.12, 0.3, GARAGE_WIDTH_M - 1.6))
		var led: Vector3 = get_pit_transform(u, GARAGE_FRONT_M - 0.14).origin + Vector3.UP * (GARAGE_HEIGHT_M - 0.5)
		batch.box(shell, GARAGE_LED, Transform3D(basis, led), Vector3(0.1, 0.28, GARAGE_WIDTH_M - 2.0))
		var garage := Node3D.new()
		garage.name = "Garage_%d" % index
		garage.transform = get_pit_transform(u, GARAGE_FRONT_M)
		add_child(garage)
		garages.append(garage)
	var mesh := MeshInstance3D.new()
	mesh.name = "PitGarages"
	mesh.mesh = batch.commit()
	add_child(mesh)


func _build_shared_paddock() -> void:
	var centre_u: float = STALL_FIRST_OFFSET_M + STALL_PITCH_M * float(STALL_COUNT - 1) * 0.5
	var pose: Transform3D = get_pit_transform(centre_u, 0.0)
	var building := PitBuildingKit.new()
	building.name = "PitBuilding"
	building.building_length_m = 124.0
	building.bay_count = STALL_COUNT
	building.bay_stride_m = STALL_PITCH_M
	building.front_x = 15.5
	building.garage_top_y = 4.7
	building.accent_color = Color("#00f0ff")
	building.transform = pose
	add_child(building)
	var stand := GrandstandKit.new()
	stand.name = "MainGrandstand"
	stand.stand_length_m = 140.0
	stand.accent_color = building.accent_color
	stand.transform = pose
	# Shared stand front is local -19 m; shift to the street's opposite edge at -21.5 m.
	stand.position -= pose.basis.x * 2.5
	add_child(stand)
	var tower := ControlTowerKit.new()
	tower.name = "RaceControlTower"
	tower.accent_color = building.accent_color
	tower.transform = pose
	tower.position += pose.basis.z * -76.0
	add_child(tower)
	var props_source := ApexPitScript.new()
	var props := MeshBatchScript.new()
	props_source._garage_props(props, ToonMaterials.vertex_colored(false), Liveries.color_for(0))
	props_source.free()
	var equipment := MultiMesh.new()
	equipment.transform_format = MultiMesh.TRANSFORM_3D
	equipment.mesh = props.commit()
	equipment.instance_count = STALL_COUNT
	for index: int in range(STALL_COUNT):
		var garage_pose: Transform3D = garages[index].transform
		garage_pose.basis = garage_pose.basis.scaled(Vector3(1.0, 1.0, 0.9))
		equipment.set_instance_transform(index, garage_pose)
	var gear := MultiMeshInstance3D.new()
	gear.name = "GarageEquipment"
	gear.multimesh = equipment
	add_child(gear)
	var fence := MeshBatchScript.new()
	var material: Material = ToonMaterials.vertex_colored(false)
	for side: float in [-1.0, 1.0]:
		var previous := Vector3.ZERO
		for index: int in range(49):
			var at: Vector3 = get_pit_transform(-40.0 + float(index) * 5.0, side * 6.5).origin
			fence.box(material, Color("#626c83"), Transform3D(Basis.IDENTITY, at + Vector3.UP * 2.0), Vector3(0.08, 4.0, 0.08))
			if index > 0:
				for height: float in [1.5, 2.3, 3.1, 4.0]:
					fence.strut(material, Color("#626c83"), previous + Vector3.UP * height, at + Vector3.UP * height, 0.025)
			previous = at
	var catch_fence := MeshInstance3D.new()
	catch_fence.name = "CatchFence"
	catch_fence.mesh = fence.commit()
	add_child(catch_fence)


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


## The exit lane's last 65 m, from 80 m after the line to the merge at 145 m.
func _build_bypass_ramp() -> void:
	bypass_ramp = Node3D.new()
	bypass_ramp.name = "BypassRamp"
	bypass_ramp.transform = get_pit_transform(LANE_LENGTH_M + EXIT_BLEND_M - 65.0, FAST_LANE_M)
	bypass_ramp.set_meta(&"start_s", EXIT_S + EXIT_BLEND_M - BYPASS_RAMP_M)
	bypass_ramp.set_meta(&"length_m", BYPASS_RAMP_M)
	bypass_ramp.set_meta(&"merge_s", BYPASS_MERGE_S)
	add_child(bypass_ramp)
