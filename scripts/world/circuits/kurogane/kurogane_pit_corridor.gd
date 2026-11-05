extends RefCounted

## Kurogane pit corridor, drawn from the lane the GT sim drives (GtRace.lane_lateral_at on the
## complex's sim layout) so the cars, the asphalt and the wall can never disagree: a solid
## asphalt lane that follows the car path through the 80 m entry and 30 m exit blends, white
## edge lines, closed skirts, a pit wall that starts and ends only where a car's flank clears
## it (WALL_CLEARANCE_M), an impact attenuator on each wall nose, entry/exit aprons and
## PIT IN / 80 / PIT OUT signage. The lane mouth overlaps the racing surface by 0.8 m.

const Layout := preload("res://scripts/world/circuits/kurogane/kurogane_layout.gd")
const Toon := preload("res://scripts/world/shared/toon_materials.gd")
const PitKit := preload("res://scripts/world/shared/pit_kit.gd")
const LANE_ASPHALT := Color("#26282e")
const WALL_HEIGHT_M := 1.35
## Half the wall's cap width plus air: a car's flank must clear the wall line by this much.
const WALL_CLEARANCE_M := 0.45
const CAR_HALF_WIDTH_M := 1.04
const SteelFence := preload("res://scripts/world/circuits/kurogane/kurogane_steel_fence.gd")
const MeshBatchScript := preload("res://scripts/world/shared/mesh_batch.gd")


## `sim` is the complex's sim_layout(): the lane is drawn where the cars drive it.
static func build(root: Node3D, ribbon: Node3D, pit: Dictionary, sim: Dictionary) -> void:
	var length: float = ribbon.length_m
	var entry: float = float(pit.get("entry_s", Layout.PIT_ENTRY_S))
	var span := fposmod(float(pit.get("exit_s", Layout.PIT_EXIT_S)) - entry, length)
	var side := 1.0 if String(pit.get("side", "right")) == "right" else -1.0
	var half := Layout.PIT_LANE_HALF_M
	var road_half: float = ribbon.road_half_width_m
	var wall_lat: float = road_half + 1.5
	var wall_span: Vector2 = wall_range(span, sim, wall_lat)
	var steps := ceili(span / 2.0)
	var fence_frames: Array[Transform3D] = []
	var fence_s := wall_span.x + 2.0
	while fence_s + 2.0 <= wall_span.y:
		var pose: Transform3D = ribbon.get_point_at_offset(fposmod(entry + fence_s, length), side * (road_half + 1.5))
		pose.origin += Vector3.UP * WALL_HEIGHT_M
		fence_frames.append(pose)
		fence_s += 4.0
	SteelFence.build(root, fence_frames)
	var surfaces: Array[SurfaceTool] = []
	for i in 3:
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		surfaces.append(st)
	var skirt := SurfaceTool.new()
	skirt.begin(Mesh.PRIMITIVE_TRIANGLES)
	var wall := SurfaceTool.new()
	wall.begin(Mesh.PRIMITIVE_TRIANGLES)
	var wall_cap := SurfaceTool.new()
	wall_cap.begin(Mesh.PRIMITIVE_TRIANGLES)
	var previous_wall := Vector3.INF
	var wall_segment := 0
	var last: Array = []
	for i in range(steps + 1):
		var u := span * float(i) / float(steps)
		var lane: float = absf(GtRace.lane_lateral_at(u, span, sim))
		var frame: Transform3D = ribbon.get_point_at_offset(fposmod(entry + u, length), 0.0)
		if u >= wall_span.x and u <= wall_span.y:
			var wall_base: Vector3 = frame.origin + frame.basis.x * side * (road_half + 1.5)
			if previous_wall != Vector3.INF:
				_double_quad(wall, previous_wall, wall_base, wall_base + Vector3.UP * WALL_HEIGHT_M, previous_wall + Vector3.UP * WALL_HEIGHT_M)
				var cap_color := Color("#e0212e") if wall_segment % 2 == 0 else Color("#f4f5f7")
				var p0 := previous_wall + frame.basis.x * 0.12 + Vector3.UP * WALL_HEIGHT_M
				var p1 := wall_base + frame.basis.x * 0.12 + Vector3.UP * WALL_HEIGHT_M
				var p2 := wall_base - frame.basis.x * 0.12 + Vector3.UP * WALL_HEIGHT_M
				var p3 := previous_wall - frame.basis.x * 0.12 + Vector3.UP * WALL_HEIGHT_M
				_color_quad(wall_cap, p0, p1, p2, p3, cap_color)
				wall_segment += 1
			previous_wall = wall_base
		var edges: Array = []
		for lateral in [maxf(lane - half, road_half - 0.8), maxf(lane + half, road_half + 0.75)]:
			edges.append(frame.origin + frame.basis.x * (side * lateral) + Vector3.UP * Layout.PIT_APRON_LIFT_M)
		if not last.is_empty():
			_color_quad_flat(surfaces[0], last[0], last[1], edges[1], edges[0], LANE_ASPHALT)
			for edge in 2:
				var a: Vector3 = last[edge]
				var b: Vector3 = edges[edge]
				var across: Vector3 = frame.basis.x * 0.09
				_quad_up(surfaces[edge + 1], a - across + Vector3.UP * 0.02, a + across + Vector3.UP * 0.02, b + across + Vector3.UP * 0.02, b - across + Vector3.UP * 0.02)
				_double_quad(skirt, a - Vector3.UP * 0.32, b - Vector3.UP * 0.32, b, a)
		last = edges
	# Entry mirrors the exit taper: continuous pavement from the racing edge.
	last = []
	for i in range(34):
		var u := 65.0 * float(i) / 33.0
		var t := smoothstep(0.0, 65.0, u)
		var frame: Transform3D = ribbon.get_point_at_offset(fposmod(entry - 65.0 + u, length), 0.0)
		var outer := lerpf(road_half - 0.3, absf(GtRace.lane_lateral_at(0.0, span, sim)) + half, t)
		var inner_point := frame.origin + frame.basis.x * side * (road_half - 0.3) + Vector3.UP * Layout.PIT_APRON_LIFT_M
		var outer_point := frame.origin + frame.basis.x * side * outer + Vector3.UP * Layout.PIT_APRON_LIFT_M
		if not last.is_empty():
			_color_quad_flat(surfaces[0], last[0], last[1], outer_point, inner_point, LANE_ASPHALT)
			var across := frame.basis.x * 0.09
			_quad_up(surfaces[2], last[1] - across + Vector3.UP * 0.02, last[1] + across + Vector3.UP * 0.02, outer_point + across + Vector3.UP * 0.02, outer_point - across + Vector3.UP * 0.02)
		last = [inner_point, outer_point]
	# Painted acceleration apron keeps the released car on pavement until it rejoins.
	last = []
	for i in range(34):
		var u := 65.0 * float(i) / 33.0
		var t := smoothstep(0.0, 65.0, u)
		var frame: Transform3D = ribbon.get_point_at_offset(float(entry) + span + u, 0.0)
		var outer := lerpf(absf(GtRace.lane_lateral_at(span, span, sim)) + half, road_half - 0.3, t)
		var inner_point := frame.origin + frame.basis.x * side * (road_half - 0.3) + Vector3.UP * Layout.PIT_APRON_LIFT_M
		var outer_point := frame.origin + frame.basis.x * side * outer + Vector3.UP * Layout.PIT_APRON_LIFT_M
		if not last.is_empty():
			_color_quad_flat(surfaces[0], last[0], last[1], outer_point, inner_point, LANE_ASPHALT)
			var across := frame.basis.x * 0.09
			_quad_up(surfaces[2], last[1] - across + Vector3.UP * 0.02, last[1] + across + Vector3.UP * 0.02, outer_point + across + Vector3.UP * 0.02, outer_point - across + Vector3.UP * 0.02)
		last = [inner_point, outer_point]
	var asphalt := Toon.make(Color("#50555f"))
	var white := Toon.make(Color("#f4f5f7"))
	var names := ["PitAsphalt", "PitLaneEdgeLeft", "PitLaneEdgeRight"]
	for i in 3:
		var node := root.get_node_or_null(names[i]) as MeshInstance3D
		if node == null:
			continue
		node.material_override = asphalt if i == 0 else white
		surfaces[i].generate_normals()
		node.mesh = surfaces[i].commit()
	var skirt_mesh := skirt.commit()
	if skirt_mesh != null:
		var skirt_node := MeshInstance3D.new()
		skirt_node.name = "PitLaneSkirt"
		skirt_node.mesh = skirt_mesh
		skirt_node.material_override = Toon.make(Color("#d7d9dd"))
		skirt_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(skirt_node)
	var old_wall := root.get_node_or_null("PitWall")
	if old_wall:
		old_wall.free()
	var wall_node := MeshInstance3D.new()
	wall_node.name = "PitWall"
	wall_node.mesh = wall.commit()
	wall_node.material_override = Toon.make(Color("#c8cbd0"))
	root.add_child(wall_node)
	var cap_mesh := wall_cap.commit()
	if cap_mesh != null:
		var cap := MeshInstance3D.new()
		cap.name = "PitWallCap"
		cap.mesh = cap_mesh
		cap.material_override = Toon.vertex_colored(false)
		cap.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(cap)
	for marker in [["PitEntryMarker", entry], ["PitExitMarker", fposmod(entry + span, length)]]:
		var frame: Transform3D = ribbon.get_point_at_offset(float(marker[1]), 0.0)
		var node := root.get_node_or_null(String(marker[0])) as Node3D
		if node == null:
			continue
		node.transform = Transform3D(frame.basis, frame.origin + frame.basis.x * side * (road_half + 2.0 * half) + Vector3.UP * 1.2)
	_sign(root, ribbon, entry - 24.0, side, "PIT IN", Color("#f4f5f7"), Color("#0c2b36"), 2.6)
	_sign(root, ribbon, entry - 8.0, side, "80", Color("#f4f5f7"), Color("#d9232e"), 2.2)
	_sign(root, ribbon, fposmod(entry + span + 16.0, length), side, "PIT OUT", Color("#f4f5f7"), Color("#1f8a4c"), 2.6)
	_attenuator(root, ribbon, fposmod(entry + wall_span.x, length), side, wall_lat)
	root.set_meta("pit_wall_span_u", wall_span)
	root.set_meta("pit_wall_lateral_m", side * wall_lat)


## The stretch of lane [u0, u1] where a car on the sim path keeps its flank WALL_CLEARANCE_M off
## the wall line: the wall (and its fence) may stand only there.
static func wall_range(span: float, sim: Dictionary, wall_lat: float) -> Vector2:
	var need: float = wall_lat + CAR_HALF_WIDTH_M + WALL_CLEARANCE_M
	var u0: float = span * 0.5
	var u := 0.0
	while u < span * 0.5:
		if absf(GtRace.lane_lateral_at(u, span, sim)) >= need:
			u0 = u
			break
		u += 0.5
	var u1: float = span * 0.5
	u = span
	while u > span * 0.5:
		if absf(GtRace.lane_lateral_at(u, span, sim)) >= need:
			u1 = u
			break
		u -= 0.5
	return Vector2(u0, u1)


## Yellow/black water-filled attenuator on the wall nose facing the cars that stay on track.
static func _attenuator(root: Node3D, ribbon: Node3D, s: float, side: float, wall_lat: float) -> void:
	var batch := MeshBatchScript.new()
	var material: Material = Toon.vertex_colored(false)
	for index in 4:
		var frame: Transform3D = ribbon.get_point_at_offset(fposmod(s + 0.4 + 0.75 * float(index), float(ribbon.get("length_m"))), side * wall_lat)
		var color := Color("#f2c200") if index % 2 == 0 else Color("#1b1c20")
		batch.box(material, color, Transform3D(frame.basis, frame.origin + frame.basis.y * 0.5), Vector3(0.7, 1.0, 0.72))
	var node := MeshInstance3D.new()
	node.name = "PitWallAttenuator"
	node.mesh = batch.commit()
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(node)


static func _sign(root: Node3D, ribbon: Node3D, s: float, side: float, text: String, board_color: Color, text_color: Color, height: float) -> void:
	var frame: Transform3D = ribbon.get_point_at_offset(fposmod(s, float(ribbon.get("length_m"))), 0.0)
	# Signs sit well outside the 4.6 m lane + 1.35 m wall (the old 7.8 m offset
	# put the PIT IN board 0.15 m from the lane edge, reading as a blocker).
	var base := frame.origin + frame.basis.x * side * (Layout.ROAD_HALF_M + 11.0)
	var holder := Node3D.new()
	holder.name = "PitSign_" + text.replace(" ", "_")
	holder.transform = Transform3D(frame.basis, base + Vector3.UP * height)
	root.add_child(holder)
	var pole := MeshInstance3D.new()
	var pole_mesh := BoxMesh.new()
	pole_mesh.size = Vector3(0.1, height + 0.4, 0.1)
	pole.mesh = pole_mesh
	pole.material_override = Toon.make(Color("#5d6570"))
	pole.position = Vector3(0.0, -height * 0.5, 0.0)
	holder.add_child(pole)
	var board := MeshInstance3D.new()
	var board_mesh := BoxMesh.new()
	board_mesh.size = Vector3(2.6, 1.05, 0.1)
	board.mesh = board_mesh
	var board_mat := StandardMaterial3D.new()
	board_mat.albedo_color = board_color
	board_mat.roughness = 0.9
	board.material_override = board_mat
	holder.add_child(board)
	var label := Label3D.new()
	label.text = text
	label.font_size = 72
	label.pixel_size = 0.012
	label.modulate = text_color
	label.outline_size = 6
	label.outline_modulate = Color("#0b1117")
	label.position = Vector3(0.0, 0.0, 0.06)
	holder.add_child(label)


static func _quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3) -> void:
	for p: Vector3 in [a, b, c, a, c, d]:
		st.add_vertex(p)


static func _color_quad_flat(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, color: Color) -> void:
	var normal := (b - a).cross(c - a)
	var order: Array = [a, b, c, a, c, d] if normal.dot(Vector3.UP) < 0.0 else [a, c, b, a, d, c]
	for p: Vector3 in order:
		st.set_color(color)
		st.add_vertex(p)


static func _quad_up(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3) -> void:
	var normal := (b - a).cross(c - a)
	var order: Array = [a, b, c, a, c, d] if normal.dot(Vector3.UP) < 0.0 else [a, c, b, a, d, c]
	for p: Vector3 in order:
		st.add_vertex(p)


static func _double_quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3) -> void:
	for p: Vector3 in [a, b, c, a, c, d, a, c, b, a, d, c]:
		st.add_vertex(p)


static func _color_quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, color: Color) -> void:
	for p: Vector3 in [a, b, c, a, c, d, a, c, b, a, d, c]:
		st.set_color(color)
		st.add_vertex(p)
