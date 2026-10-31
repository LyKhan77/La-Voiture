class_name ArdennesPitComplex
extends "res://scripts/world/circuits/base/circuit_pit_complex.gd"

## The FIA pit connection of Ardennes Valley Ring (Round 05, FASE 16): a 420 m fast lane on the right of the start straight,
## ten 20 m team boxes under the glass pit building, a 3 m separator (a 1.35 m concrete wall with a 1.65 m steel mesh fence on
## it) with an orange impact attenuator on its nose, and the paddock behind it. The main grandstand stands across the road and
## the race control tower beyond the building. The lane peels off 180 m before the line (s=5220) and rejoins 240 m after it.
##
## Laterals are metres right of the racing line. The road is 14 m wide (edge 7.0):
##    7.00           circuit asphalt edge
##    8.30           pit separator (wall 0.5 thick, its face 8.55); its nose carries the crash cushion
##    8.60 .. 13.00  fast lane, 4.4 m, cars run down its middle at 10.8
##   13.00 .. 20.60  working lane, the box car stops at 17.0
##   20.60 .. 38.60  ten garages on the 20 m pitch (the building's facade stands at the garage front)
## The mapgen blueprint draws the boxes on a 14 m pitch around s=100. Measured here (tests/test_ardennes_pit_flood.gd, whole field
## boxing at once) 14 m jams the lane the way it jammed Monte, Brianza and Neo-Wangan: a team's two cars double-stack (the second
## waits 8 m behind the first) and a car leaving its box needs room to swing out past the car queued for the next one. At 14 m
## the train and bunched scenarios overlapped 46 and 43 ticks (limit 20) and the lane needed 96 and 94 s to clear (limit 90).
## At 20 m they overlap 0 ticks and clear in 86 and 83 s. The ten boxes (s -80 .. 100) stand 100 m after the entry and 140 m
## before the exit so a late-called car stops in time and the exit ramp starts after the last box; the building grows to
## 222 m. The lane's own 420 m, entry and exit stations are the blueprint's.
## The fast lane centre is 10.8, the blueprint's 8.5 read as the lane's inner edge plus half its width (as the mapgen sandbox
## drew it): with 11.6 the field's merge crawl ran into the next box's arrival (34 overlap ticks in the spread scenario, 4 here).
## The lane ramps out and back inside its own 420 m (80 m in, 90 m out) and the asphalt runs on past both mouths (65 m before
## the entry, 65 m after the exit) sharing the road's edge, so it grows out of the road and fades back into it with no hard start.

const MeshBatchScript := preload("res://scripts/world/shared/mesh_batch.gd")
const ToonMaterials := preload("res://scripts/world/shared/toon_materials.gd")
const GrandstandKit := preload("res://scripts/world/paddock/main_grandstand.gd")
const ControlTowerKit := preload("res://scripts/world/paddock/race_control_tower.gd")
const Liveries := preload("res://scripts/car/team_liveries.gd")
const TeamSignage := preload("res://scripts/world/paddock/team_signage.gd")
const TransportersKit := preload("res://scripts/world/paddock/team_transporters.gd")
const FigureScript := preload("res://scripts/car/pit_crew_figure.gd")
const BuildingScript := preload("res://scripts/world/circuits/ardennes/ardennes_pit_building.gd")
const SeparatorScript := preload("res://scripts/world/circuits/ardennes/ardennes_pit_separator.gd")

const LAP_LENGTH_M: float = 5400.0
const ENTRY_S: float = 5220.0 # 180 m before the start/finish line
const LANE_LENGTH_M: float = 420.0
const EXIT_S: float = ENTRY_S + LANE_LENGTH_M - LAP_LENGTH_M # 240 m after the line
const SPEED_LIMIT_MPS: float = 80.0 / 3.6

const STALL_COUNT: int = 10
const STALL_PITCH_M: float = 20.0
## The first box stands 100 m after the entry (s=5320); the ten boxes span s -80 .. 100, the lane middle is s=10.
const STALL_FIRST_OFFSET_M: float = 100.0
const STALL_FIRST_S: float = ENTRY_S + STALL_FIRST_OFFSET_M

const ROAD_EDGE_M: float = 7.0 # half of the circuit's 14 m road
const ENTRY_LATERAL_M: float = 5.2 # both mouths: the cars' path along the road, inside its edge
## The asphalt runs on past the mouths so the lane grows out of the road and fades back into it; the barrier gap matches.
const TAIL_IN_M: float = 65.0
const TAIL_OUT_M: float = 65.0
const PIT_WALL_M: float = 8.3
const FAST_LANE_M: float = 10.8
const FAST_LANE_HALF_M: float = 2.2
const BOX_LATERAL_M: float = 17.0
const GARAGE_FRONT_M: float = 20.6
const GARAGE_OPENING_M: float = 16.4
const ENTRY_BLEND_M: float = 80.0
const EXIT_BLEND_M: float = 90.0
const WALL_HALF_THICKNESS_M: float = 0.25
const WALL_HEIGHT_M: float = 1.35
## The separator stands only where the cars are on the fast lane: after the entry blend, before the exit blend.
const WALL_START_U: float = ENTRY_BLEND_M - 2.0
const WALL_END_U: float = LANE_LENGTH_M - EXIT_BLEND_M - 2.0
const SEPARATOR_MARGIN_M: float = 4.0

## Where the transporter row stands, measured from the circuit centre line: on the deck behind the building's back (38.6).
const TRANSPORTER_LATERAL_M: float = 46.0
## The team canopies stand behind the transporter row (centre 55 m from the racing line): a flat livery roof on four poles per team.
const CANOPY_LATERAL_M: float = 55.0
const CANOPY_SIZE := Vector2(10.0, 7.0)
const CANOPY_HEIGHT_M: float = 3.1
const CANOPY_POLE := Color("#d7dade")
## The main grandstand (the kit's own centre, across the road on the left) and the race control tower beyond the building.
const STAND_CENTRE_S: float = 125.0
const BUILDING_LENGTH_M: float = 222.0
const BUILDING_DEPTH_M: float = 19.5
const TOWER_S: float = 150.0
## The tower kit builds its structure 24 m to the right of its node; its centre stands 32 m from the racing line.
const TOWER_CENTRE_LATERAL_M: float = 32.0

const SURFACE_Y: float = 0.015
const LINE_Y: float = 0.03
const STEP_M: float = 2.0

const ASPHALT_COLOR := Color("#26282e")
const PAINT_WHITE := Color("#f4f5f7")
const PAINT_YELLOW := Color("#ffd400")
const WALL_COLOR := Color("#c8cbd0")
const WALL_CAP_RED := Color("#e0212e")
const WALL_CAP_WHITE := Color("#f4f5f7")
const CUSHION_ORANGE := Color("#ff6a00")
const CUSHION_WHITE := Color("#f0f2f5")
const SIGN_PLATE := Color("#15202b")

var stall_markings: Array[Dictionary] = []
var crash_cushion: Node3D
var pit_entry_trigger: Area3D
var pit_exit_trigger: Area3D
var asphalt: MeshInstance3D
var building: ArdennesPitBuilding
var separator: Dictionary = {}
var lighting: Node3D
var _solid_footprints: Array[Dictionary] = []


func _init() -> void:
	team_count = STALL_COUNT
	garage_front_m = GARAGE_FRONT_M
	stall_lane_m = BOX_LATERAL_M


## Lateral of the cars' path at `u` metres from Pit Entry: off the road onto the fast lane, along it, then back.
static func lane_lateral_at(u: float) -> float:
	if u <= ENTRY_BLEND_M:
		return lerpf(ENTRY_LATERAL_M, FAST_LANE_M, smoothstep(0.0, ENTRY_BLEND_M, u))
	if u <= LANE_LENGTH_M - EXIT_BLEND_M:
		return FAST_LANE_M
	return lerpf(FAST_LANE_M, ENTRY_LATERAL_M, smoothstep(LANE_LENGTH_M - EXIT_BLEND_M, LANE_LENGTH_M, u))


func lane_lateral(u: float) -> float:
	return lane_lateral_at(u)


func s_from_u_local(u: float) -> float:
	return fposmod(ENTRY_S + u, ribbon.length_m if ribbon != null else LAP_LENGTH_M)


func u_from_s(s: float) -> float:
	return fposmod(s - ENTRY_S, ribbon.length_m if ribbon != null else LAP_LENGTH_M)


func get_pit_transform(u: float, lateral_m: float) -> Transform3D:
	return ribbon.get_point_at_offset(s_from_u_local(u), lateral_m)


## The lane the GT sim drives (the blueprint's entry, exit and lane length, the ten boxes on 20 m), see GtRace.default_pit_layout.
func sim_layout() -> Dictionary:
	return {
		"entry_s": ENTRY_S,
		"exit_s": EXIT_S,
		# The sim measures a box from the entry, so this is the first box's s on the entry's lap (5320 = s -80 before the line).
		"stall_first_s": STALL_FIRST_S,
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


## Where the separator stands, in metres from Pit Entry.
func wall_span_u() -> Vector2:
	return Vector2(WALL_START_U, WALL_END_U)


## Flat decks the terrain must leave alone: the lane, boxes and paddock on the right (the race control tower's forecourt
## included), the grandstand terrace on the left.
func ground_platforms() -> Array[Dictionary]:
	return [
		{"s0": fposmod(ENTRY_S - TAIL_IN_M - 20.0, LAP_LENGTH_M), "s1": EXIT_S + TAIL_OUT_M + 20.0, "side": 1.0, "lateral_from": ROAD_EDGE_M + 0.3, "lateral_to": 96.0},
		{"s0": STAND_CENTRE_S - 135.0, "s1": STAND_CENTRE_S + 135.0, "side": -1.0, "lateral_from": ROAD_EDGE_M + 0.3, "lateral_to": 96.0},
	]


## The main grandstand's footprint, cut flat into the hillside: {s, side, lateral (centre), width, length}.
func ground_rects() -> Array[Dictionary]:
	return [{"s": STAND_CENTRE_S, "side": -1.0, "lateral": 38.0, "width": 42.0, "length": 246.0}]


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
	_build_separator()
	_build_crash_cushion()
	_build_garages()
	_build_team_transporters()
	_build_canopies()
	_build_shared_paddock()
	_build_pit_lighting()
	_build_lane_signs()
	_build_triggers()
	if not team_ids.is_empty():
		assign_teams(team_ids)
	else:
		_on_teams_assigned()


## Re-seating recolours the box paint, the shutter strips and the crews and moves the name signs and the transporters.
func _on_teams_assigned() -> void:
	_build_markings()
	if building != null:
		var colors: Array = []
		for stall: Dictionary in stalls:
			colors.append(Liveries.color_for(int(stall["team"])))
		building.set_team_colors(colors)
	_build_team_plates()
	if transporters != null:
		transporters.apply_teams(stalls)
	_build_canopies()
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


## The pit asphalt: the tail that grows out of the road before the entry, the entry mouth, the 4.4 m fast lane, the working
## lane in front of the garages, the exit mouth and the tail that fades back into the road after it.
func _build_asphalt() -> void:
	asphalt = MeshInstance3D.new()
	asphalt.name = "PitAsphalt"
	var batch := MeshBatchScript.new()
	var material: Material = ToonMaterials.vertex_colored(false)
	var from_u: float = -TAIL_IN_M
	var span: float = LANE_LENGTH_M + TAIL_OUT_M - from_u
	var steps: int = ceili(span / STEP_M)
	for index: int in range(steps):
		var ua: float = from_u + span * float(index) / float(steps)
		var ub: float = from_u + span * float(index + 1) / float(steps)
		batch.quad(material, ASPHALT_COLOR,
			_at(ua, _surface_left(ua), SURFACE_Y), _at(ub, _surface_left(ub), SURFACE_Y),
			_at(ub, _surface_right(ub), SURFACE_Y), _at(ua, _surface_right(ua), SURFACE_Y), Vector3.UP)
	asphalt.mesh = batch.commit()
	asphalt.material_override = PitKit.asphalt_material()
	add_child(asphalt)


## The asphalt's circuit-side edge: shared with the road, 0.1 m under its edge so no seam shows, along the whole lane and
## both tails. The separator and the fast lane's yellow line stand on it; there is never a strip of bare deck between the
## road and the lane for a car's wheels to cross.
func _surface_left(_u: float) -> float:
	return ROAD_EDGE_M - 0.1


## The asphalt's outer edge: at each mouth it is as wide as a car's path needs, the fast lane's edge between, pushed out
## to the garage fronts along the ten boxes, and zero-width at the far ends of the tails (the road's own edge).
func _surface_right(u: float) -> float:
	var mouth: float = ENTRY_LATERAL_M + FAST_LANE_HALF_M
	if u < 0.0:
		return lerpf(ROAD_EDGE_M, mouth, smoothstep(-TAIL_IN_M, -TAIL_IN_M * 0.4, u))
	if u > LANE_LENGTH_M:
		return lerpf(mouth, ROAD_EDGE_M, smoothstep(LANE_LENGTH_M + TAIL_OUT_M * 0.6, LANE_LENGTH_M + TAIL_OUT_M, u))
	var fast_edge: float = FAST_LANE_M + FAST_LANE_HALF_M
	var base: float = lerpf(mouth, fast_edge, smoothstep(0.0, ENTRY_BLEND_M, u))
	base = lerpf(base, mouth, smoothstep(LANE_LENGTH_M - EXIT_BLEND_M, LANE_LENGTH_M, u))
	var last_box: float = STALL_FIRST_OFFSET_M + STALL_PITCH_M * float(STALL_COUNT - 1)
	var apron: float = smoothstep(STALL_FIRST_OFFSET_M - 24.0, STALL_FIRST_OFFSET_M - 8.0, u) * (1.0 - smoothstep(last_box + 12.0, last_box + 32.0, u))
	return lerpf(base, GARAGE_FRONT_M, apron)


## The pit asphalt's two edges (lateral, left then right) at `u` metres from Pit Entry; `u` runs from -TAIL_IN_M to
## LANE_LENGTH_M + TAIL_OUT_M.
func asphalt_edges(u: float) -> Vector2:
	return Vector2(_surface_left(u), _surface_right(u))


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
	# The fast lane's two limits: yellow on the separator side, white on the working lane side.
	add_band.call(WALL_START_U, WALL_END_U, func(_u: float) -> float: return FAST_LANE_M - FAST_LANE_HALF_M + 0.25, func(_u: float) -> float: return FAST_LANE_M - FAST_LANE_HALF_M + 0.55, PAINT_YELLOW, LINE_Y)
	add_band.call(ENTRY_BLEND_M, LANE_LENGTH_M - EXIT_BLEND_M, func(_u: float) -> float: return FAST_LANE_M + FAST_LANE_HALF_M - 0.55, func(_u: float) -> float: return FAST_LANE_M + FAST_LANE_HALF_M - 0.25, PAINT_WHITE, LINE_Y)
	# Yellow limiter lines across the lane at Pit Entry and Pit Exit.
	add_band.call(0.0, 1.2, func(u: float) -> float: return _surface_left(u), func(u: float) -> float: return _surface_right(u), PAINT_YELLOW, LINE_Y + 0.004)
	add_band.call(LANE_LENGTH_M - 1.2, LANE_LENGTH_M, func(u: float) -> float: return _surface_left(u), func(u: float) -> float: return _surface_right(u), PAINT_YELLOW, LINE_Y + 0.004)
	# Speed arrows on the fast lane after the entry blend.
	for u: float in [ENTRY_BLEND_M + 8.0, ENTRY_BLEND_M + 20.0]:
		batch.quad(paint, PAINT_WHITE, _at(u - 2.0, FAST_LANE_M - 0.2, LINE_Y), _at(u + 0.5, FAST_LANE_M - 0.2, LINE_Y), _at(u + 0.5, FAST_LANE_M + 0.2, LINE_Y), _at(u - 2.0, FAST_LANE_M + 0.2, LINE_Y), Vector3.UP)
		batch.triangle(paint, PAINT_WHITE, _at(u + 3.0, FAST_LANE_M, LINE_Y), _at(u, FAST_LANE_M - 0.9, LINE_Y), _at(u, FAST_LANE_M + 0.9, LINE_Y), Vector3.UP)
	for stall: Dictionary in stalls:
		PitKit.paint_box(batch, paint, stall, global_transform.affine_inverse() * (stall["pose"] as Transform3D), BOX_LATERAL_M, stall_markings)
	var mesh := get_node_or_null("PitMarkings") as MeshInstance3D
	if mesh == null:
		mesh = MeshInstance3D.new()
		mesh.name = "PitMarkings"
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mesh)
	mesh.mesh = batch.commit()


## The solid concrete pit wall (1.35 m) between the circuit and the fast lane, with a red and white cap in 4 m blocks.
## One merged mesh, one draw call; the steel mesh fence stands on it (`_build_separator`).
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
		var cap: Color = WALL_CAP_RED if (index / 2) % 2 == 0 else WALL_CAP_WHITE
		batch.quad(concrete, cap, a - side + half, b - side + half, b + side + half, a + side + half, Vector3.UP)
		batch.quad(concrete, WALL_COLOR, a - side + half, b - side + half, b - side - half, a - side - half, -side)
		batch.quad(concrete, WALL_COLOR, a + side - half, b + side - half, b + side + half, a + side + half, side)
		if index == 0:
			batch.quad(concrete, WALL_COLOR, a - side - half, a + side - half, a + side + half, a - side + half, (b - a).normalized() * -1.0)
		if index == steps - 1:
			batch.quad(concrete, WALL_COLOR, b - side - half, b + side - half, b + side + half, b - side + half, (b - a).normalized())
	var mesh := MeshInstance3D.new()
	mesh.name = "PitWall"
	mesh.mesh = batch.commit()
	add_child(mesh)
	_solid_footprints.append({"name": "wall", "u0": WALL_START_U, "u1": WALL_END_U, "lat0": PIT_WALL_M - WALL_HALF_THICKNESS_M, "lat1": PIT_WALL_M + WALL_HALF_THICKNESS_M})


## The steel mesh fence on the wall: one 4 m panel and post per module, none past the wall's ends (the pit mouths stay open).
func _build_separator() -> void:
	var frames: Array[Transform3D] = []
	var u: float = WALL_START_U + SEPARATOR_MARGIN_M + SeparatorScript.PANEL_LENGTH_M * 0.5
	while u + SeparatorScript.PANEL_LENGTH_M * 0.5 <= WALL_END_U - SEPARATOR_MARGIN_M:
		var pose: Transform3D = get_pit_transform(u, PIT_WALL_M)
		pose.origin += Vector3.UP * WALL_HEIGHT_M
		frames.append(pose)
		u += SeparatorScript.PANEL_LENGTH_M
	separator = SeparatorScript.build(self, frames)
	separator["frames"] = frames


## The orange impact attenuator on the wall's nose: an FIA-style crash cushion with white bands.
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


## The hero building holds the ten garages; here only the Garage_i anchors the crews, name signs and the choreography use.
func _build_garages() -> void:
	garages.clear()
	for index: int in range(STALL_COUNT):
		var garage := Node3D.new()
		garage.name = "Garage_%d" % index
		garage.transform = get_pit_transform(float(stalls[index]["u"]), GARAGE_FRONT_M)
		garage.position.y += SURFACE_Y
		add_child(garage)
		garages.append(garage)
	_build_standby_crews()
	var first_u: float = float(stalls[0]["u"]) - STALL_PITCH_M * 0.5
	var last_u: float = float(stalls[STALL_COUNT - 1]["u"]) + STALL_PITCH_M * 0.5
	_solid_footprints.append({"name": "garages", "u0": first_u, "u1": last_u, "lat0": GARAGE_FRONT_M, "lat1": GARAGE_FRONT_M + BUILDING_DEPTH_M})


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


## Team names on the shutter strips: the shared TeamSignage kit, one mesh for the whole lane.
func _build_team_plates() -> void:
	if garages.is_empty():
		return
	var batch: RefCounted = TeamSignage.new_batch()
	var flat: Material = ToonMaterials.vertex_colored(false)
	var plates: Array = []
	for index: int in range(garages.size()):
		var team: int = int(stalls[index]["team"])
		if team < 0:
			continue
		var pose: Transform3D = TeamSignage.fascia_pose(garages[index].transform, -0.3, 3.98)
		plates.append(TeamSignage.add_plate(batch, flat, team, pose, 8.0, Liveries.color_for(team)))
	TeamSignage.commit_node(self, batch, plates)


## One transporter per racing team on the deck behind the pit building (shared TeamTransporters kit).
func _build_team_transporters() -> void:
	transporters = TransportersKit.new()
	transporters.name = "TeamTransporters"
	add_child(transporters)
	transporters.build(ribbon, stalls, TRANSPORTER_LATERAL_M, true)


func _build_shared_paddock() -> void:
	var centre_u: float = STALL_FIRST_OFFSET_M + STALL_PITCH_M * float(STALL_COUNT - 1) * 0.5
	var pose: Transform3D = get_pit_transform(centre_u, GARAGE_FRONT_M)
	building = BuildingScript.new()
	building.name = "PitBuilding"
	building.transform = pose
	building.position.y += SURFACE_Y
	add_child(building)
	building.build(STALL_PITCH_M, GARAGE_OPENING_M)
	var stand := GrandstandKit.new()
	stand.name = "MainGrandstand"
	# The kit stands on the left of the road at its own centre (s=125): it faces the building across the straight.
	stand.transform = ribbon.get_point_at_offset(STAND_CENTRE_S, 0.0)
	add_child(stand)
	var tower := ControlTowerKit.new()
	tower.name = "RaceControlTower"
	tower.transform = ribbon.get_point_at_offset(TOWER_S, TOWER_CENTRE_LATERAL_M - ControlTowerKit.CENTRE_X_M)
	add_child(tower)


func _build_pit_lighting() -> void:
	lighting = Node3D.new()
	lighting.name = "PitLighting"
	lighting.visible = false
	add_child(lighting)
	# One broad, shadowless fill serves two bays; the building's LED bars supply the visible light source.
	for pair: int in range(STALL_COUNT / 2):
		var fill := OmniLight3D.new()
		fill.name = "GarageFill%d" % pair
		fill.position = _at(STALL_FIRST_OFFSET_M + (float(pair) * 2.0 + 0.5) * STALL_PITCH_M, GARAGE_FRONT_M + 6.0, 3.8)
		fill.light_color = Color("#d5e5ff")
		fill.light_energy = 8.0
		fill.omni_range = 24.0
		fill.omni_attenuation = 1.5
		fill.shadow_enabled = false
		fill.set_meta(&"no_shadow", true)
		lighting.add_child(fill)


## PIT IN and 80 before the entry, PIT OUT after the exit, on poles beside the lane's tails.
func _build_lane_signs() -> void:
	var batch := MeshBatchScript.new()
	var material: Material = ToonMaterials.vertex_colored(false)
	for spec: Array in [["PIT IN", -24.0, 2.6], ["80", -8.0, 2.2], ["PIT OUT", LANE_LENGTH_M + 16.0, 2.6]]:
		var u: float = float(spec[1])
		var height: float = float(spec[2])
		var pose: Transform3D = get_pit_transform(u, ROAD_EDGE_M + 7.8)
		batch.box(material, Color("#5d6570"), Transform3D(pose.basis, pose.origin + Vector3.UP * (height * 0.5)), Vector3(0.1, height + 0.4, 0.1))
		batch.box(material, SIGN_PLATE, Transform3D(pose.basis, pose.origin + Vector3.UP * height), Vector3(0.1, 1.05, 2.6))
		var label := Label3D.new()
		label.name = "Board" + String(spec[0]).replace(" ", "")
		label.text = String(spec[0])
		label.font = preload("res://assets/fonts/BarlowCondensed.ttf")
		label.font_size = 72
		label.pixel_size = 0.012
		label.outline_size = 6
		label.outline_modulate = Color("#0b1117")
		# The board's face looks at the road: the label's +Z turns to the pit's -X.
		label.transform = Transform3D(pose.basis * Basis(Vector3.UP, -PI * 0.5), pose.origin + Vector3.UP * height + pose.basis.x * -0.07)
		add_child(label)
	var node := MeshInstance3D.new()
	node.name = "LaneSigns"
	node.mesh = batch.commit()
	add_child(node)


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


## One flat canopy per racing team on the deck behind the transporters (mapgen sandbox paddock dressing): the roof wears the
## team's livery colour, so it is rebuilt when the boxes are re-seated.
func _build_canopies() -> void:
	if stalls.is_empty():
		return
	var batch := MeshBatchScript.new()
	var flat: Material = ToonMaterials.vertex_colored(false)
	for stall: Dictionary in stalls:
		var team: int = int(stall["team"])
		if team < 0:
			continue
		var pose: Transform3D = ribbon.get_point_at_offset(float(stall["s"]), CANOPY_LATERAL_M)
		var roof_color: Color = Liveries.color_for(team).lightened(0.15)
		batch.box(flat, roof_color, Transform3D(pose.basis, pose.origin + Vector3.UP * CANOPY_HEIGHT_M), Vector3(CANOPY_SIZE.y, 0.3, CANOPY_SIZE.x))
		for corner: Vector2 in [Vector2(-1.0, -1.0), Vector2(1.0, -1.0), Vector2(-1.0, 1.0), Vector2(1.0, 1.0)]:
			var offset: Vector3 = pose.basis.x * (corner.x * (CANOPY_SIZE.y * 0.5 - 0.3)) + pose.basis.z * (corner.y * (CANOPY_SIZE.x * 0.5 - 0.3))
			batch.box(flat, CANOPY_POLE, Transform3D(pose.basis, pose.origin + offset + Vector3.UP * (CANOPY_HEIGHT_M * 0.5)), Vector3(0.18, CANOPY_HEIGHT_M, 0.18))
	var mesh := get_node_or_null("TeamCanopies") as MeshInstance3D
	if mesh == null:
		mesh = MeshInstance3D.new()
		mesh.name = "TeamCanopies"
		add_child(mesh)
	mesh.mesh = batch.commit()
