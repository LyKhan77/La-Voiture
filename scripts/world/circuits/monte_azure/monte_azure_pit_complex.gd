class_name MonteAzurePitComplex
extends "res://scripts/world/circuits/base/circuit_pit_complex.gd"

## The FIA pit connection of Monte Azure Marina (Round 04, FASE 15): a 320 m fast lane on the quay side of the start
## straight, ten 12 m team boxes, a concrete pit wall with an orange impact attenuator on its nose, and the paddock
## (pit building, race control tower, team transporters) behind it. The main grandstand stands across the road on the
## harbour side. It peels off 60 m before the line (s=2790) and rejoins 260 m after it, before Sainte Devote.
##
## Laterals are metres right of the racing line. The street road is 11 m wide, so the whole lane is the compact Neo-Wangan
## cross-section moved 0.25 m in; both circuits publish the same offsets between wall, fast lane, boxes and garages:
##   5.50           circuit asphalt edge
##   5.75           pit wall (0.5 thick, 1.2 high); its nose carries the crash cushion
##   6.25 .. 10.75  fast lane, 4.5 m, cars run down its middle at 8.5
##   10.75 .. 16.0  working lane, the box car stops at 13.0
##   16.0 .. 25.0   ten garages on the 12 m pitch; the pit building front stands at 15.5
## The lane ramps out and back inside its own 320 m (40 m in, 80 m out), as Brianza's does, so the exit mouth is
## already on the circuit's edge (lateral 5.2) at s=260.

const MeshBatchScript := preload("res://scripts/world/shared/mesh_batch.gd")
const ToonMaterials := preload("res://scripts/world/shared/toon_materials.gd")
const PitBuildingKit := preload("res://scripts/world/paddock/pit_building.gd")
const GrandstandKit := preload("res://scripts/world/paddock/main_grandstand.gd")
const ControlTowerKit := preload("res://scripts/world/paddock/race_control_tower.gd")
const Liveries := preload("res://scripts/car/team_liveries.gd")
const TransportersKit := preload("res://scripts/world/paddock/team_transporters.gd")
const FigureScript := preload("res://scripts/car/pit_crew_figure.gd")

const LAP_LENGTH_M: float = 2850.0
const ENTRY_S: float = 2790.0 # 60 m before the start/finish line
const EXIT_S: float = 260.0 # 260 m after it, 360 m before Sainte Devote
const LANE_LENGTH_M: float = 320.0
const SPEED_LIMIT_MPS: float = 80.0 / 3.6

const STALL_COUNT: int = 10
const STALL_PITCH_M: float = 12.0
## The first box stands at s=46 (lane middle s=100, the ten boxes span s 40..160).
const STALL_FIRST_S: float = 46.0
const STALL_FIRST_OFFSET_M: float = STALL_FIRST_S + LAP_LENGTH_M - ENTRY_S

const ROAD_EDGE_M: float = 5.5 # half of the circuit's 11 m road
const ENTRY_LATERAL_M: float = 5.2 # both mouths, on the right edge of the road
const PIT_WALL_M: float = 5.75
const FAST_LANE_M: float = 8.5
const FAST_LANE_HALF_M: float = 2.25
const BOX_LATERAL_M: float = 13.0
const GARAGE_FRONT_M: float = 16.0
const GARAGE_DEPTH_M: float = 9.0
const GARAGE_HEIGHT_M: float = 4.4
const GARAGE_WIDTH_M: float = 11.4
const ENTRY_BLEND_M: float = 40.0
const EXIT_BLEND_M: float = 80.0
const WALL_HALF_THICKNESS_M: float = 0.25
const WALL_HEIGHT_M: float = 1.2
## The wall stands only where the cars are on the fast lane: after the entry blend, before the exit blend.
const WALL_START_U: float = ENTRY_BLEND_M - 2.0
const WALL_END_U: float = LANE_LENGTH_M - EXIT_BLEND_M - 2.0
## Where the transporter row stands, measured from the circuit centre line: on the deck behind the pit building.
const TRANSPORTER_LATERAL_M: float = 40.0
## The main grandstand's front, on the harbour side of the road, and its length (centred on s=75).
const STAND_FRONT_M: float = 21.5
const STAND_LENGTH_M: float = 160.0
const STAND_CENTRE_S: float = 75.0
## The control tower stands 76 m beyond the building's middle, 14 m clear of the 124 m building's end.
const BUILDING_LENGTH_M: float = 124.0
const TOWER_OFFSET_M: float = 76.0

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
const ACCENT := Color("#1d5fd6")

var stall_markings: Array[Dictionary] = []
var crash_cushion: Node3D
var pit_entry_trigger: Area3D
var pit_exit_trigger: Area3D
var asphalt: MeshInstance3D
var lighting: Node3D
var _solid_footprints: Array[Dictionary] = []


func _init() -> void:
	team_count = STALL_COUNT
	garage_front_m = GARAGE_FRONT_M
	stall_lane_m = BOX_LATERAL_M


## Lateral of the cars' path at `u` metres from Pit Entry: off the road edge onto the fast lane, along it, then back.
static func lane_lateral_at(u: float) -> float:
	if u <= ENTRY_BLEND_M:
		return lerpf(ENTRY_LATERAL_M, FAST_LANE_M, smoothstep(0.0, ENTRY_BLEND_M, u))
	if u <= LANE_LENGTH_M - EXIT_BLEND_M:
		return FAST_LANE_M
	return lerpf(FAST_LANE_M, ENTRY_LATERAL_M, smoothstep(LANE_LENGTH_M - EXIT_BLEND_M, LANE_LENGTH_M, u))


func lane_lateral(u: float) -> float:
	return lane_lateral_at(u)


func s_from_u_local(u: float) -> float:
	return fposmod(ENTRY_S + u, ribbon.length_m)


func u_from_s(s: float) -> float:
	return fposmod(s - ENTRY_S, ribbon.length_m)


func get_pit_transform(u: float, lateral_m: float) -> Transform3D:
	return ribbon.get_point_at_offset(s_from_u_local(u), lateral_m)


## The lane the GT sim drives (the blueprint's entry, exit and ten boxes), see GtRace.default_pit_layout.
func sim_layout() -> Dictionary:
	return {
		"entry_s": ENTRY_S,
		"exit_s": EXIT_S,
		# The sim measures a box from the entry, so this is the first box's s on the entry's lap (2896 = s 46 next lap).
		"stall_first_s": ENTRY_S + STALL_FIRST_OFFSET_M,
		"stall_pitch_m": STALL_PITCH_M,
		"stall_lane_m": BOX_LATERAL_M,
		"fast_lane_m": FAST_LANE_M,
		"edge_lateral_m": ENTRY_LATERAL_M,
		"queue_gap_m": 8.0,
		"lane_ramp_in_m": ENTRY_BLEND_M,
		"lane_ramp_out_m": EXIT_BLEND_M,
		"lane_length_m": LANE_LENGTH_M,
		"stalls": STALL_COUNT,
		"speed_limit_mps": SPEED_LIMIT_MPS,
	}


## Where the wall stands, in metres from Pit Entry.
func wall_span_u() -> Vector2:
	return Vector2(WALL_START_U, WALL_END_U)


## Flat decks the terrain must leave alone: the lane, boxes and paddock on the right, the grandstand quay on the left.
func ground_platforms() -> Array[Dictionary]:
	return [
		{"s0": fposmod(ENTRY_S - 40.0, LAP_LENGTH_M), "s1": EXIT_S + 100.0, "side": 1.0, "lateral_from": ROAD_EDGE_M, "lateral_to": 52.0},
		{"s0": fposmod(STAND_CENTRE_S - STAND_LENGTH_M * 0.5 - 20.0, LAP_LENGTH_M), "s1": STAND_CENTRE_S + STAND_LENGTH_M * 0.5 + 20.0, "side": -1.0, "lateral_from": ROAD_EDGE_M, "lateral_to": 70.0},
	]


## Solid things beside the lane as {name, u0, u1, lat0, lat1}, for clearance checks.
func solid_footprints() -> Array[Dictionary]:
	return _solid_footprints


func build(p_ribbon: TrackRibbonScript, team_ids: Array[int] = []) -> void:
	if built:
		if not team_ids.is_empty():
			assign_teams(team_ids)
		return
	built = true
	ribbon = p_ribbon
	_build_stalls()
	_build_asphalt()
	_build_markings()
	_build_pit_wall()
	_build_crash_cushion()
	_build_garages()
	_build_team_transporters()
	_build_shared_paddock()
	_build_catch_fence()
	_build_pit_lighting()
	_build_entry_sign()
	_build_triggers()
	if not team_ids.is_empty():
		assign_teams(team_ids)


## Re-seating recolours the box paint, the garage crews and the transporters.
func _on_teams_assigned() -> void:
	_build_markings()
	if transporters != null:
		transporters.apply_teams(stalls)
	if not garages.is_empty():
		_build_standby_crews()


## The pit-lane floodlights and garage lights: on from sunset, off by day (the environment calls this with GtWeather's
## floodlight level).
func set_lights_on(on: bool) -> void:
	if lighting != null:
		lighting.visible = on


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
			"index": index, "team": index, "s": s, "u": u, "lateral": BOX_LATERAL_M,
			"pose": marker.transform, "node": marker,
		})


## The pit asphalt: entry mouth, 4.5 m fast lane, working lane in front of the garages and the exit mouth.
func _build_asphalt() -> void:
	asphalt = MeshInstance3D.new()
	asphalt.name = "PitAsphalt"
	var batch := MeshBatchScript.new()
	var material: Material = ToonMaterials.vertex_colored(false)
	var steps: int = ceili(LANE_LENGTH_M / STEP_M)
	for index: int in range(steps):
		var ua: float = LANE_LENGTH_M * float(index) / float(steps)
		var ub: float = LANE_LENGTH_M * float(index + 1) / float(steps)
		batch.quad(material, ASPHALT_COLOR,
			_at(ua, _surface_left(ua), SURFACE_Y), _at(ub, _surface_left(ub), SURFACE_Y),
			_at(ub, _surface_right(ub), SURFACE_Y), _at(ua, _surface_right(ua), SURFACE_Y), Vector3.UP)
	asphalt.mesh = batch.commit()
	asphalt.material_override = PitKit.asphalt_material()
	add_child(asphalt)


## The asphalt's circuit-side edge: on the road's edge at the mouths, the fast lane's inner edge between.
func _surface_left(u: float) -> float:
	var inner: float = FAST_LANE_M - FAST_LANE_HALF_M
	if u <= ENTRY_BLEND_M:
		return lerpf(ROAD_EDGE_M, inner, smoothstep(0.0, ENTRY_BLEND_M, u))
	return lerpf(inner, ROAD_EDGE_M, smoothstep(LANE_LENGTH_M - EXIT_BLEND_M, LANE_LENGTH_M, u))


## The asphalt's outer edge: the fast lane's, pushed out to the garage fronts along the ten boxes.
func _surface_right(u: float) -> float:
	var fast_edge: float = FAST_LANE_M + FAST_LANE_HALF_M
	var base: float = lerpf(ENTRY_LATERAL_M + FAST_LANE_HALF_M, fast_edge, smoothstep(0.0, ENTRY_BLEND_M, u))
	base = lerpf(base, ROAD_EDGE_M, smoothstep(LANE_LENGTH_M - EXIT_BLEND_M, LANE_LENGTH_M, u))
	var last_box: float = STALL_FIRST_OFFSET_M + STALL_PITCH_M * float(STALL_COUNT - 1)
	var apron: float = smoothstep(STALL_FIRST_OFFSET_M - 24.0, STALL_FIRST_OFFSET_M - 8.0, u) * (1.0 - smoothstep(last_box + 12.0, last_box + 32.0, u))
	return lerpf(base, GARAGE_FRONT_M, apron)


func _at(u: float, lateral_m: float, y: float) -> Vector3:
	return get_pit_transform(u, lateral_m).origin + Vector3.UP * y


func _build_markings() -> void:
	stall_markings.clear()
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
	add_band.call(WALL_START_U, WALL_END_U, func(u: float) -> float: return _surface_left(u) + 0.25, func(u: float) -> float: return _surface_left(u) + 0.55, PAINT_YELLOW, LINE_Y)
	add_band.call(ENTRY_BLEND_M, LANE_LENGTH_M - EXIT_BLEND_M, func(_u: float) -> float: return FAST_LANE_M + FAST_LANE_HALF_M - 0.55, func(_u: float) -> float: return FAST_LANE_M + FAST_LANE_HALF_M - 0.25, PAINT_WHITE, LINE_Y)
	# Yellow limiter lines across the lane at Pit Entry and Pit Exit.
	add_band.call(0.0, 1.2, func(u: float) -> float: return _surface_left(u), func(u: float) -> float: return _surface_right(u), PAINT_YELLOW, LINE_Y + 0.004)
	add_band.call(LANE_LENGTH_M - 1.2, LANE_LENGTH_M, func(u: float) -> float: return _surface_left(u), func(u: float) -> float: return _surface_right(u), PAINT_YELLOW, LINE_Y + 0.004)
	for u: float in [ENTRY_BLEND_M + 8.0, ENTRY_BLEND_M + 20.0]:
		batch.quad(paint, PAINT_WHITE, _at(u - 2.0, 8.3, LINE_Y), _at(u + 0.5, 8.3, LINE_Y), _at(u + 0.5, 8.7, LINE_Y), _at(u - 2.0, 8.7, LINE_Y), Vector3.UP)
		batch.triangle(paint, PAINT_WHITE, _at(u + 3.0, FAST_LANE_M, LINE_Y), _at(u, 7.6, LINE_Y), _at(u, 9.4, LINE_Y), Vector3.UP)
	for stall: Dictionary in stalls:
		PitKit.paint_box(batch, paint, stall, global_transform.affine_inverse() * (stall["pose"] as Transform3D), BOX_LATERAL_M, stall_markings)
	var mesh := get_node_or_null("PitMarkings") as MeshInstance3D
	if mesh == null:
		mesh = MeshInstance3D.new()
		mesh.name = "PitMarkings"
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mesh)
	mesh.mesh = batch.commit()


## The concrete pit wall between the circuit and the fast lane, on the 1.2 m regulation height, plus the hazard
## copings. One merged mesh, one draw call.
func _build_pit_wall() -> void:
	var batch := MeshBatchScript.new()
	var concrete: Material = ToonMaterials.vertex_colored(false)
	var steps: int = ceili((WALL_END_U - WALL_START_U) / STEP_M)
	for index: int in range(steps):
		var ua: float = WALL_START_U + (WALL_END_U - WALL_START_U) * float(index) / float(steps)
		var ub: float = WALL_START_U + (WALL_END_U - WALL_START_U) * float(index + 1) / float(steps)
		var a: Vector3 = _at(ua, PIT_WALL_M, WALL_HEIGHT_M * 0.5)
		var b: Vector3 = _at(ub, PIT_WALL_M, WALL_HEIGHT_M * 0.5)
		var half: Vector3 = Vector3.UP * WALL_HEIGHT_M * 0.5
		var side: Vector3 = (b - a).cross(Vector3.UP).normalized() * WALL_HALF_THICKNESS_M
		batch.quad(concrete, WALL_COLOR, a - side + half, b - side + half, b + side + half, a + side + half, Vector3.UP)
		batch.quad(concrete, WALL_COPING, a - side + half, b - side + half, b - side - half, a - side - half, -side)
		batch.quad(concrete, WALL_COPING, a + side - half, b + side - half, b + side + half, a + side + half, side)
		if index == 0:
			batch.quad(concrete, WALL_COLOR, a - side - half, a + side - half, a + side + half, a - side + half, (b - a).normalized() * -1.0)
		if index == steps - 1:
			batch.quad(concrete, WALL_COLOR, b - side - half, b + side - half, b + side + half, b - side + half, (b - a).normalized())
	var mesh := MeshInstance3D.new()
	mesh.name = "PitWall"
	mesh.mesh = batch.commit()
	add_child(mesh)
	_solid_footprints.append({"name": "wall", "u0": WALL_START_U, "u1": WALL_END_U, "lat0": PIT_WALL_M - WALL_HALF_THICKNESS_M, "lat1": PIT_WALL_M + WALL_HALF_THICKNESS_M})


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
	var cushion := MeshInstance3D.new()
	cushion.name = "CrashCushion"
	cushion.mesh = batch.commit()
	cushion.set_meta(&"attenuator_color", CUSHION_ORANGE)
	cushion.set_meta(&"fia_standard", true)
	add_child(cushion)
	crash_cushion = cushion
	_solid_footprints.append({"name": "cushion", "u0": WALL_START_U - 2.4, "u1": WALL_START_U, "lat0": PIT_WALL_M - 0.55, "lat1": PIT_WALL_M + 0.55})


## Ten team garages on the 12 m stall pitch, each an open-mouthed box with a glowing frontage.
func _build_garages() -> void:
	garages.clear()
	var batch := MeshBatchScript.new()
	var shell: Material = ToonMaterials.vertex_colored(false)
	for index: int in range(STALL_COUNT):
		var u: float = float(stalls[index]["u"])
		var pose: Transform3D = get_pit_transform(u, GARAGE_FRONT_M + GARAGE_DEPTH_M * 0.5)
		var basis: Basis = pose.basis
		var centre: Vector3 = pose.origin + Vector3.UP * GARAGE_HEIGHT_M * 0.5
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
	_build_standby_crews()
	var first_u: float = float(stalls[0]["u"]) - GARAGE_WIDTH_M * 0.5
	var last_u: float = float(stalls[STALL_COUNT - 1]["u"]) + GARAGE_WIDTH_M * 0.5
	_solid_footprints.append({"name": "garages", "u0": first_u, "u1": last_u, "lat0": GARAGE_FRONT_M, "lat1": GARAGE_FRONT_M + GARAGE_DEPTH_M})


## The crew waiting in each garage in its team's overalls, as on the other circuits; the choreographer hides it while
## the animated twin works in the lane.
func _build_standby_crews() -> void:
	var flat: Material = ToonMaterials.vertex_colored(false)
	var roles: Array = crew_roles()
	for index: int in range(garages.size()):
		var color: Color = Liveries.color_for(int(stalls[index]["team"]))
		var batch := MeshBatchScript.new()
		for slot: int in range(roles.size()):
			FigureScript.add(batch, flat, Transform3D(Basis(Vector3.UP, PI * 0.5), crew_spot(slot)), int(roles[slot]), color)
		var crew: MeshInstance3D = garages[index].get_node_or_null("StandbyCrew") as MeshInstance3D
		if crew == null:
			crew = MeshInstance3D.new()
			crew.name = "StandbyCrew"
			garages[index].add_child(crew)
		crew.mesh = batch.commit()


## One transporter per racing team on the deck behind the pit building (shared TeamTransporters kit).
func _build_team_transporters() -> void:
	transporters = TransportersKit.new()
	transporters.name = "TeamTransporters"
	add_child(transporters)
	transporters.build(ribbon, stalls, TRANSPORTER_LATERAL_M, true)


func _build_shared_paddock() -> void:
	var centre_u: float = STALL_FIRST_OFFSET_M + STALL_PITCH_M * float(STALL_COUNT - 1) * 0.5
	var pose: Transform3D = get_pit_transform(centre_u, 0.0)
	var building := PitBuildingKit.new()
	building.name = "PitBuilding"
	building.building_length_m = BUILDING_LENGTH_M
	building.bay_count = STALL_COUNT
	building.bay_stride_m = STALL_PITCH_M
	building.front_x = 15.5
	building.garage_top_y = 4.7
	building.accent_color = ACCENT
	# The building stands right in front of the garage fascias, so the names go on its doors.
	building.name_doors = true
	building.transform = pose
	add_child(building)
	var stand := GrandstandKit.new()
	stand.name = "MainGrandstand"
	stand.stand_length_m = STAND_LENGTH_M
	stand.accent_color = ACCENT
	# Across the road on the harbour side, centred on s=75; the kit's own front is at local -19 m.
	var stand_pose: Transform3D = get_pit_transform(u_from_s(STAND_CENTRE_S), 0.0)
	stand_pose.origin -= stand_pose.basis.x * (STAND_FRONT_M - 19.0)
	stand.transform = stand_pose
	add_child(stand)
	var tower := ControlTowerKit.new()
	tower.name = "RaceControlTower"
	tower.accent_color = ACCENT
	tower.transform = pose
	tower.position += pose.basis.z * -TOWER_OFFSET_M
	add_child(tower)
	var props := MeshBatchScript.new()
	PitKit.garage_props(props, ToonMaterials.vertex_colored(false), Liveries.color_for(0))
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


## The catch fence along the start/pit straight: behind the barrier on the grandstand side, and along the pit wall.
func _build_catch_fence() -> void:
	var fence := MeshBatchScript.new()
	var material: Material = ToonMaterials.vertex_colored(false)
	for side: float in [-1.0, 1.0]:
		var previous := Vector3.ZERO
		var connected: bool = false
		for index: int in range(ceili((LANE_LENGTH_M + 100.0) / 5.0) + 1):
			var u: float = -40.0 + float(index) * 5.0
			# The pit-side fence follows only the wall; the entry and exit mouths stay open.
			if side > 0.0 and (u < WALL_START_U or u > WALL_END_U):
				connected = false
				continue
			var lateral: float = PIT_WALL_M if side > 0.0 else -6.5
			var at: Vector3 = get_pit_transform(u, lateral).origin
			fence.box(material, Color("#626c83"), Transform3D(Basis.IDENTITY, at + Vector3.UP * 2.0), Vector3(0.08, 4.0, 0.08))
			if connected:
				for height: float in [1.5, 2.3, 3.1, 4.0]:
					fence.strut(material, Color("#626c83"), previous + Vector3.UP * height, at + Vector3.UP * height, 0.025)
			previous = at
			connected = true
	var catch_fence := MeshInstance3D.new()
	catch_fence.name = "CatchFence"
	catch_fence.mesh = fence.commit()
	catch_fence.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(catch_fence)


func _build_pit_lighting() -> void:
	lighting = Node3D.new()
	lighting.name = "PitLighting"
	lighting.visible = false
	add_child(lighting)
	var fixtures: Array[Transform3D] = []
	var strips: Array[Transform3D] = []
	var floors: Array[Transform3D] = []
	for stall: Dictionary in stalls:
		var u: float = float(stall["u"])
		var floor_pose: Transform3D = get_pit_transform(u, GARAGE_FRONT_M + GARAGE_DEPTH_M * 0.5)
		floor_pose.origin += Vector3.UP * -0.025
		floors.append(floor_pose)
		for lateral: float in [18.0, 22.0]:
			var pose: Transform3D = get_pit_transform(u, lateral)
			pose.origin += Vector3.UP * 4.1
			fixtures.append(pose)
			pose.origin -= Vector3.UP * 0.11
			strips.append(pose)
	_instanced_boxes(lighting, "CeilingHousings", Vector3(0.38, 0.18, 9.6), fixtures, ToonMaterials.make(Color("#222b3a")))
	var led: StandardMaterial3D = ToonMaterials.emissive(Color("#e6f2ff"), 2.4)
	led.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_instanced_boxes(lighting, "CeilingLEDs", Vector3(0.18, 0.04, 9.2), strips, led)
	_instanced_boxes(self, "GarageFloors", Vector3(GARAGE_DEPTH_M, 0.08, GARAGE_WIDTH_M), floors, ToonMaterials.make(Color("#515a69")))
	# One broad, shadowless fill serves two bays; the ceiling strips supply the visible light source.
	for pair: int in range(STALL_COUNT / 2):
		var fill := OmniLight3D.new()
		fill.name = "GarageFill%d" % pair
		fill.position = _at(STALL_FIRST_OFFSET_M + (float(pair) * 2.0 + 0.5) * STALL_PITCH_M, 18.0, 3.8)
		fill.light_color = Color("#d5e5ff")
		fill.light_energy = 8.0
		fill.omni_range = 17.0
		fill.omni_attenuation = 1.5
		fill.shadow_enabled = false
		fill.set_meta(&"no_shadow", true)
		lighting.add_child(fill)


func _instanced_boxes(parent: Node3D, node_name: String, size: Vector3, poses: Array[Transform3D], material: Material) -> void:
	var mesh := BoxMesh.new()
	mesh.size = size
	var batch := MultiMesh.new()
	batch.transform_format = MultiMesh.TRANSFORM_3D
	batch.mesh = mesh
	batch.instance_count = poses.size()
	for index: int in range(poses.size()):
		batch.set_instance_transform(index, poses[index])
	var instance := MultiMeshInstance3D.new()
	instance.name = node_name
	instance.multimesh = batch
	instance.material_override = material
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(instance)


func _build_entry_sign() -> void:
	var batch := MeshBatchScript.new()
	var material: Material = ToonMaterials.vertex_colored(false)
	var sign_pose: Transform3D = get_pit_transform(6.0, BOX_LATERAL_M)
	sign_pose.origin += Vector3.UP * 3.0
	batch.box(material, Color("#3d4a5e"), sign_pose, Vector3(0.22, 6.0, 0.22))
	var board: Transform3D = get_pit_transform(6.0, FAST_LANE_M)
	board.origin += Vector3.UP * 5.6
	batch.box(material, Color("#123b32"), board, Vector3(5.4, 1.4, 0.22))
	batch.strut(material, Color("#3d4a5e"), _at(6.0, BOX_LATERAL_M, 5.9), _at(6.0, FAST_LANE_M, 5.9), 0.16)
	var structure := MeshInstance3D.new()
	structure.name = "PitEntryFixtures"
	structure.mesh = batch.commit()
	add_child(structure)
	var sign := Label3D.new()
	sign.name = "PitEntrySign"
	sign.text = "PIT  //  80"
	sign.font = preload("res://assets/fonts/BarlowCondensed.ttf")
	sign.font_size = 64
	sign.outline_size = 6
	sign.pixel_size = 0.01
	sign.transform = board
	sign.position += board.basis.z * 0.13
	add_child(sign)


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
