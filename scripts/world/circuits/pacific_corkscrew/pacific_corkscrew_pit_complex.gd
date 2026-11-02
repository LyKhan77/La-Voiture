class_name PacificCorkscrewPitComplex
extends "res://scripts/world/circuits/base/circuit_pit_complex.gd"

## Pacific Coast Corkscrew pit lane: 420 m right-hand lane, entry s=3900, exit
## s=220, ten 20 m boxes (Fase 0 revision) s=30..210, service bay 5 at s=130,
## 2F/10-garage pit building at s=120, 240 m main grandstand on the left,
## race control s=222 past the building end, start gantry, team fascia/crew/
## transporters, and the proved interior detail.

const Layout := preload("res://scripts/world/circuits/pacific_corkscrew/pacific_corkscrew_layout.gd")
const Batch := preload("res://scripts/world/shared/mesh_batch.gd")
const Toon := preload("res://scripts/world/shared/toon_materials.gd")
const Figure := preload("res://scripts/car/pit_crew_figure.gd")
const Liveries := preload("res://scripts/car/team_liveries.gd")
const Signage := preload("res://scripts/world/paddock/team_signage.gd")
const Trucks := preload("res://scripts/world/paddock/team_transporters.gd")
const Building := preload("res://scripts/world/circuits/pacific_corkscrew/pacific_corkscrew_pit_building.gd")
const Stand := preload("res://scripts/world/paddock/main_grandstand.gd")
const Tower := preload("res://scripts/world/paddock/race_control_tower.gd")
const Gantry := preload("res://scripts/world/shared/start_gantry.gd")
const CatchFence := preload("res://scripts/world/circuits/pacific_corkscrew/pacific_corkscrew_catch_fence.gd")

const ENTRY_S: float = Layout.PIT_ENTRY_S
const EXIT_S: float = Layout.PIT_EXIT_S
const LANE_LENGTH_M: float = Layout.PIT_LANE_LENGTH_M
const STALL_PITCH_M: float = Layout.PIT_STALL_PITCH_M
const STALL_FIRST_S: float = Layout.PIT_STALL_FIRST_S
const FAST_LANE_M: float = Layout.PIT_FAST_LANE_M
const BOX_LATERAL_M: float = Layout.PIT_SERVICE_X
const GARAGE_FRONT_M: float = Layout.PIT_FACADE_X
const ENTRY_BLEND_M: float = Layout.PIT_ENTRY_BLEND_M
const EXIT_BLEND_M: float = Layout.PIT_EXIT_BLEND_M

var pit_building: PitBuilding
var stall_markings: Array[Dictionary] = []
var lighting: Node3D


func _init() -> void:
	team_count = Layout.PIT_STALL_COUNT
	garage_front_m = GARAGE_FRONT_M
	stall_lane_m = BOX_LATERAL_M


func sim_layout() -> Dictionary:
	# Sim boxes use the entry's unwrapped lap; the first visible bay is s=30 after the seam.
	var first := (ribbon.length_m if ribbon != null else 4101.365) + STALL_FIRST_S
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
	print("[pacific-pit] pavement")
	_build_signs_and_triggers()
	print("[pacific-pit] signs")
	_build_pit_building()
	print("[pacific-pit] building")
	transporters = Trucks.new()
	transporters.name = "TeamTransporters"
	add_child(transporters)
	transporters.build(ribbon, stalls, 49.0, true)
	print("[pacific-pit] transporters")
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
	var seats: Array[int] = team_ids.duplicate()
	if seats.is_empty():
		seats.assign(range(team_count))
	assign_teams(seats)


func _build_pit_building() -> void:
	lighting = Node3D.new()
	lighting.name = "PitWorkingLights"
	add_child(lighting)
	pit_building = PitBuilding.new()
	pit_building.name = "PitBuilding"
	pit_building.building_length_m = Layout.PIT_BUILDING_SPAN_M
	pit_building.bay_count = Layout.PIT_STALL_COUNT
	pit_building.bay_stride_m = Layout.PIT_STALL_PITCH_M
	pit_building.front_x = Layout.PIT_FACADE_X
	pit_building.transform = ribbon.get_point_at_offset(Layout.PIT_BUILDING_CENTRE_S, 0.0)
	pit_building.position.y += Layout.PIT_APRON_LIFT_M
	add_child(pit_building)
	var stats: Dictionary = Building.build(self, ribbon, lighting)
	# Working floodlights over the lane itself; the ten garage lights live inside.
	for station: float in [70.0, 110.0, 150.0, 190.0]:
		var lamp := OmniLight3D.new()
		lamp.name = "PitLaneLight_%d" % int(station)
		lamp.position = ribbon.get_point_at_offset(station, BOX_LATERAL_M).origin + Vector3.UP * 6.2
		lamp.omni_range = 30.0
		lamp.light_energy = 1.4
		lamp.light_color = Color("#fff0d6")
		lamp.shadow_enabled = false
		lighting.add_child(lamp)
	stats["pit_boxes"] = Layout.PIT_STALL_COUNT
	stats["crew_figures"] = Layout.PIT_STALL_COUNT * 13
	set_meta("pit_detail_stats", stats)


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
		var batch := Batch.new()
		var roles := PitKit.standby_roles()
		for slot: int in range(roles.size()):
			Figure.add(batch, material, Transform3D(Basis(Vector3.UP, PI * 0.5), PitKit.standby_spot(slot)), int(roles[slot]), Liveries.color_for(team))
		crew.mesh = batch.commit()
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


func _build_pavement() -> void:
	var lane := Batch.new()
	var apron := Batch.new()
	var marks := Batch.new()
	var wall := Batch.new()
	var material: Material = Toon.vertex_colored(false)
	var white := Color("#f4f5f7")
	var fence_frames: Array[Transform3D] = []
	# The asphalt overlaps the racing surface by 0.2 m and tapers out of / into
	# the track edge over 65 m, so the lane mouth reads as one piece of pavement.
	const LANE_INNER := 6.3
	const LANE_FAST_OUTER := 13.1
	for u: int in range(-65, 485, 2):
		var a := float(u)
		var b := a + 2.0
		var outer_a := _outer_edge(a)
		var outer_b := _outer_edge(b)
		var lane_outer_a := minf(outer_a, LANE_FAST_OUTER)
		var lane_outer_b := minf(outer_b, LANE_FAST_OUTER)
		lane.quad(material, Color("#26282e"), _at(a, LANE_INNER, 0.015), _at(b, LANE_INNER, 0.015), _at(b, lane_outer_b, 0.015), _at(a, lane_outer_a, 0.015), Vector3.UP)
		if outer_a > LANE_FAST_OUTER + 0.01 or outer_b > LANE_FAST_OUTER + 0.01:
			apron.quad(material, Color("#7a7e86"), _at(a, LANE_FAST_OUTER, 0.014), _at(b, LANE_FAST_OUTER, 0.014), _at(b, outer_b, 0.014), _at(a, outer_a, 0.014), Vector3.UP)
		# Continuous lane edge: the outer taper at the mouth, the 13.1 m divider
		# beside the boxes, and the 8.5 m inner line along the fast lane.
		var edge_a := lane_outer_a
		var edge_b := lane_outer_b
		marks.quad(material, white, _at(a, edge_a - 0.07, 0.034), _at(b, edge_b - 0.07, 0.034), _at(b, edge_b + 0.07, 0.034), _at(a, edge_a + 0.07, 0.034), Vector3.UP)
		var inner_a := _inner_edge(a)
		var inner_b := _inner_edge(b)
		if inner_a > 6.55 or inner_b > 6.55:
			marks.quad(material, white, _at(a, inner_a - 0.07, 0.034), _at(b, inner_b - 0.07, 0.034), _at(b, inner_b + 0.07, 0.034), _at(a, inner_a + 0.07, 0.034), Vector3.UP)
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
	# Transverse pit-in and pit-out bars across the fast lane.
	for bar: float in [0.0, LANE_LENGTH_M - 1.2]:
		marks.quad(material, white, _at(bar, 8.57, 0.035), _at(bar + 1.2, 8.57, 0.035), _at(bar + 1.2, 13.03, 0.035), _at(bar, 13.03, 0.035), Vector3.UP)
	# Hatched wedge where the lane peels off and rejoins the track, so the mouth
	# reads as a pit entry rather than a plain widening of the apron.
	for span: Array in [[-30.0, 0.0], [LANE_LENGTH_M, LANE_LENGTH_M + 30.0]]:
		var u: float = float(span[0]) + 1.0
		while u < float(span[1]) - 1.0:
			var inner_a := _inner_edge(u)
			var inner_b := _inner_edge(u + 0.9)
			if inner_a > 6.6:
				marks.quad(material, Color("#c8cbd0"),
					_at(u, 6.52, 0.033), _at(u + 0.9, inner_b - 0.05, 0.033),
					_at(u + 1.15, inner_b - 0.05, 0.033), _at(u + 0.25, 6.52, 0.033), Vector3.UP)
			u += 2.5
	_commit_surface("PitAsphalt", lane, PitKit.asphalt_material())
	_commit_surface("PitApron", apron, Toon.vertex_colored(false))
	_commit_surface("PitLaneMarkings", marks, Toon.vertex_colored(false))
	_commit_surface("PitWall", wall, null)
	_build_steel_fence(fence_frames)
	_paint_lane_text()


func _commit_surface(node_name: String, batch: Batch, override: Material) -> void:
	var node := MeshInstance3D.new()
	node.name = node_name
	node.mesh = batch.commit()
	if override != null:
		node.material_override = override
	if node_name == "PitLaneMarkings" or node_name == "PitApron":
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(node)


## Painted pit-in / limit / pit-out lettering lying flat on the lane.
func _paint_lane_text() -> void:
	var holder := Node3D.new()
	holder.name = "PitLaneText"
	add_child(holder)
	for spec: Array in [["PIT", 10.0, 10.8, 0.0140], ["IN", 21.0, 10.8, 0.0140], ["80", 36.0, 10.8, 0.0200], ["PIT", 386.0, 10.8, 0.0140], ["OUT", 398.0, 10.8, 0.0140]]:
		var label := Label3D.new()
		label.name = "Mark_%d_%s" % [holder.get_child_count(), String(spec[0])]
		label.text = spec[0]
		label.font_size = 96
		label.pixel_size = float(spec[3])
		label.modulate = Color("#f4f5f7")
		label.outline_modulate = Color("#141a21")
		label.outline_size = 10
		var frame := get_pit_transform(float(spec[1]), float(spec[2]))
		label.transform = Transform3D(frame.basis * Basis(Vector3.RIGHT, -PI * 0.5), frame.origin + Vector3.UP * 0.045)
		label.billboard = BaseMaterial3D.BILLBOARD_DISABLED
		label.double_sided = true
		label.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		holder.add_child(label)


func _build_steel_fence(frames: Array[Transform3D]) -> void:
	if frames.is_empty():
		return
	var panels: Array[Transform3D] = []
	var posts: Array[Transform3D] = []
	for frame in frames:
		panels.append(frame * Transform3D(Basis.IDENTITY.scaled(Vector3(0.025, 1.65, 4.02)), Vector3(0, 0.825, 0)))
		posts.append(frame * Transform3D(Basis.IDENTITY.scaled(Vector3(0.12, 1.73, 0.12)), Vector3(0, 0.825, 2.0)))
	posts.append(frames.back() * Transform3D(Basis.IDENTITY.scaled(Vector3(0.12, 1.73, 0.12)), Vector3(0, 0.825, -2.0)))
	var panel_material := StandardMaterial3D.new()
	panel_material.albedo_color = Color(0.12, 0.14, 0.2, 0.32)
	panel_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	panel_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	panel_material.roughness = 0.9
	CatchFence._add(self, "PitSteelPanels", panels, panel_material)
	var steel := StandardMaterial3D.new()
	steel.albedo_color = Color("#444e59")
	steel.roughness = 0.85
	CatchFence._add(self, "PitSteelPosts", posts, steel)


func _at(u: float, lateral: float, height: float) -> Vector3:
	return get_pit_transform(u, lateral).origin + Vector3.UP * height


func _outer_edge(u: float) -> float:
	if u < 0.0:
		return lerpf(7.0, 13.1, smoothstep(-65.0, 0.0, u))
	if u > LANE_LENGTH_M:
		return lerpf(13.1, 7.0, smoothstep(LANE_LENGTH_M, LANE_LENGTH_M + 65.0, u))
	var first := u_from_s(STALL_FIRST_S)
	var last := first + 9.0 * STALL_PITCH_M
	var apron := smoothstep(first - 35.0, first - 15.0, u) * (1.0 - smoothstep(last + 18.0, last + 40.0, u))
	return lerpf(13.1, GARAGE_FRONT_M, apron)


## Fast-lane inner edge: converges from the track edge at the mouth to 8.5 m
## through the lane, and back out at the merge.
func _inner_edge(u: float) -> float:
	if u < 0.0:
		return lerpf(6.5, 8.5, smoothstep(-30.0, 0.0, u))
	if u > LANE_LENGTH_M:
		return lerpf(8.5, 6.5, smoothstep(LANE_LENGTH_M, LANE_LENGTH_M + 30.0, u))
	return 8.5


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
