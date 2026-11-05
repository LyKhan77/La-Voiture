extends SceneTree

## Paulistano Speed Arena production gate: homologated 4.310 m counter-clockwise lap,
## 15 named turns, the approved LEFT-hand pit (signed sim lane, mirrored box frames,
## turned building with its shutters in box order, gantry wing over the left lane),
## the pit-side rail/flag panels/floodlights cleared out of the lane, the static
## clearance gate the repo uses instead of physics colliders, terrain support, the
## approved biome/landmark counts and the triangle budget.
## Run: godot --headless --path . -s res://tests/test_paulistano_circuit.gd

const SCENE := "res://scenes/race_world/circuits/paulistano/paulistano_circuit.tscn"
const Registry := preload("res://scripts/core/circuit_calendar_registry.gd")
const Weather := preload("res://scripts/gt/gt_weather.gd")
const Layout := preload("res://scripts/world/circuits/paulistano/paulistano_layout.gd")

## Nothing static may stand closer to the centreline than the road edge plus this.
const ROAD_CLEAR_M: float = 1.0
## Pit signs stand outside the 4.6 m lane and its wall (approved 17.75 m, never 14.55 m).
const SIGN_LATERAL_M: float = 17.75
## The natural Paulistano relief (away from the lake) measures a 99.9th-percentile vertex spike of
## 3.03 m (max 6.97 m) on its steepest laterite slopes: the lake banks may be as rough, no rougher.
const SPIKE_MAX_M: float = 3.5

var failures: int = 0


func check(ok: bool, description: String) -> void:
	print("[%s] %s" % ["PASS" if ok else "FAIL", description])
	if not ok:
		failures += 1


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	check(ResourceLoader.exists(SCENE), "Paulistano production scene exists")
	if not ResourceLoader.exists(SCENE):
		quit(1)
		return
	var circuit = (load(SCENE) as PackedScene).instantiate()
	root.add_child(circuit)
	await process_frame
	var ribbon: TrackRibbon = circuit.get_node("TrackRibbon")
	var pit = circuit.get_node("PitLane")
	var env = circuit.get_node("Environment")
	var lap: float = ribbon.length_m
	var half: float = ribbon.road_half_width_m
	check(absf(lap - 4313.035) < 1.0 and is_equal_approx(half, 6.75), "Homologated 4.310 m lap, 13.5 m GP road (baked %.3f m)" % lap)
	check(circuit.turns.size() == 15 and circuit.turns[0].name == "T01 Drop Braking" and circuit.turns[14].name == "T15 Amphitheater", "All 15 named turns exposed")
	var real_turns: int = 0
	for turn: Dictionary in circuit.turns:
		real_turns += 1 if float(turn.radius_m) < 1000.0 and int(turn.direction) != 0 else 0
	check(real_turns == 15, "Every turn station sits on its corner (%d/15 with a real radius)" % real_turns)
	var signed_area: float = 0.0
	for i: int in range(ribbon.curve.point_count - 1):
		var a: Vector3 = ribbon.curve.get_point_position(i)
		var b: Vector3 = ribbon.curve.get_point_position(i + 1)
		signed_area += a.x * b.z - b.x * a.z
	var registry_entry = Registry.get_circuit("paulistano")
	check(registry_entry.scene_path == SCENE and registry_entry.round_number == 9 and not registry_entry.direction_clockwise, "Calendar round 9 loads the production module, counter-clockwise")
	check(signed_area < 0.0, "The baked lap runs counter-clockwise seen from above (signed area %.0f)" % signed_area)
	var preview := load(registry_entry.preview_image_path) as Texture2D
	check(preview != null and preview.get_size() == Vector2(640, 360), "Race setup loads the 640x360 Paulistano poster")

	# --- left-hand pit: the sim and the drawing agree -----------------------------------
	var layout: Dictionary = pit.sim_layout()
	check(layout.stall_pitch_m == 14.0 and layout.queue_gap_m == 8.0, "Production pit keeps the approved 14 m pitch and 8 m queue gap")
	check(is_equal_approx(float(layout.fast_lane_m), -10.8) and is_equal_approx(float(layout.stall_lane_m), -16.5) and is_equal_approx(float(layout.edge_lateral_m), -5.2), "Sim lane on the left: fast lane -10.8 m, boxes -16.5 m, edge -5.2 m")
	check(absf(float(layout.stall_first_s) - (lap + 27.0)) < 0.01, "First box unwrapped at the approved s = 27")
	var service_s := fposmod(float(layout.stall_first_s) + 5.0 * float(layout.stall_pitch_m), lap)
	check(absf(service_s - 97.0) < 0.01, "Service bay 5 stands at s = 97 (%.3f)" % service_s)
	check(pit.stalls.size() == 10 and pit.garages.size() == 10, "Ten boxes and garage sockets")
	var frames_ok: bool = true
	for i: int in range(pit.stalls.size()):
		var stall: Dictionary = pit.stalls[i]
		var centre: Transform3D = ribbon.get_point_at_offset(float(stall.s), 0.0)
		var pose: Transform3D = stall.pose
		var garage: Node3D = pit.garages[i]
		frames_ok = frames_ok and (pose.origin - centre.origin).dot(centre.basis.x) < -16.0
		frames_ok = frames_ok and pose.basis.x.dot(centre.basis.x) < -0.99 and pose.basis.z.dot(centre.basis.z) > 0.99
		frames_ok = frames_ok and garage.global_transform.basis.x.dot(centre.basis.x) < -0.99
		frames_ok = frames_ok and (garage.global_position - centre.origin).dot(centre.basis.x) < -20.0
	check(frames_ok, "Box frames keep -Z along travel with +X to the left garages; garages stand 20.6 m to the left")
	var expected_order: Array[int] = []
	for i: int in range(pit.stalls.size() - 1, -1, -1):
		expected_order.append(int(pit.stalls[i].team))
	check(pit.pit_building.team_ids == expected_order, "Turned pit building stripes its shutters in box order (bay 0 at the far end)")
	var bay0_world: Vector3 = pit.pit_building.global_transform * Vector3(Layout.PIT_FACADE_X, 0.0, Layout.PIT_STALL_PITCH_M * 4.5)
	var last_box: Vector3 = pit.garages[9].global_position
	check(bay0_world.distance_to(last_box) < 2.0, "Building bay 0 stands at box 9's garage (%.2f m)" % bay0_world.distance_to(last_box))
	# Re-seat a field without team 10 (terrace fans wear 0..9): the garage interiors follow the boxes (no baked bay index colours).
	var seats: Array[int] = [12, 11, 4, 0, 1, 2, 3, 5, 6, 7]
	pit.seat_teams(ribbon, seats)
	var detail: MeshInstance3D = pit.get_node_or_null("PaddockDetail")
	var interiors_ok: bool = detail != null and _has_livery(detail.mesh, 12) and _has_livery(detail.mesh, 11) and not _has_livery(detail.mesh, 10)
	check(interiors_ok and pit.find_children("PaddockDetail*", "", false, false).size() == 1, "Garage interiors wear the seated teams' liveries after a re-seat, built once")
	var original: Array[int] = []
	original.assign(range(10))
	pit.seat_teams(ribbon, original)
	# The painted boxes lie on the apron pavement (not under it): measured against the apron mesh itself.
	var paint := pit.get_node_or_null("PitBoxPaint") as MeshInstance3D
	var apron := pit.get_node_or_null("PitApron") as MeshInstance3D
	var painted: int = 0
	var buried_paint: int = 0
	if paint != null and paint.mesh != null and apron != null:
		var paint_verts: PackedVector3Array = paint.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
		var apron_verts: PackedVector3Array = apron.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
		for stall: Dictionary in pit.stalls:
			var origin: Vector3 = Transform3D(stall.pose).origin
			var top: float = -INF
			var floor_y: float = -INF
			for vertex: Vector3 in paint_verts:
				var world: Vector3 = paint.global_transform * vertex
				if Vector2(world.x - origin.x, world.z - origin.z).length() < 4.0:
					top = maxf(top, world.y)
			for vertex: Vector3 in apron_verts:
				var world: Vector3 = apron.global_transform * vertex
				if Vector2(world.x - origin.x, world.z - origin.z).length() < 4.0:
					floor_y = maxf(floor_y, world.y)
			painted += 1 if top > -INF else 0
			buried_paint += 1 if top < floor_y + 0.03 else 0
	check(painted == 10 and buried_paint == 0, "Every team's painted box lies above the apron pavement (%d of 10 painted, %d buried)" % [painted, buried_paint])
	var gantry = circuit.find_child("StartGantry", true, false)
	var gantry_ok: bool = gantry != null and gantry.pit_side < 0.0 and gantry.lamps.size() == 10
	if gantry_ok:
		var aabb: AABB = gantry.structure.get_aabb()
		gantry_ok = aabb.position.x <= -(Layout.PIT_LANE_OUTER_X + 1.0) and aabb.end.x <= 9.0
		for lamp: MeshInstance3D in gantry.lamps:
			gantry_ok = gantry_ok and lamp.position.z > 0.0
	check(gantry_ok, "Start gantry wing covers the left pit lane; the right pylon stays off the road; lamps face the grid")

	# --- pit-side furniture and the static clearance gate (no physics colliders) ----------
	var furniture = env.furniture
	var rail_in_lane: int = 0
	for s: int in range(0, int(lap), 4):
		var u: float = fposmod(float(s) - Layout.PIT_ENTRY_S, lap)
		if u > 10.0 and u < Layout.PIT_LANE_LENGTH_M - 10.0:
			rail_in_lane += 1 if furniture.has_armco_at(-1.0, float(s)) else 0
	check(rail_in_lane == 0 and furniture.has_armco_at(1.0, 50.0) and furniture.has_armco_at(-1.0, 2000.0), "Left rail open along the pit lane; the right rail runs past the boxes")
	var towers_ok: bool = true
	for record: Dictionary in furniture.tower_records:
		var lateral: float = float(record.lateral)
		towers_ok = towers_ok and lateral >= half + ROAD_CLEAR_M
		var u: float = fposmod(float(record.s) - Layout.PIT_ENTRY_S + 70.0, lap)
		if float(record.side) < 0.0 and u <= Layout.PIT_LANE_LENGTH_M + 140.0:
			towers_ok = towers_ok and lateral >= 60.0
	check(towers_ok, "Floodlight towers stand off the road and behind the left paddock along the pit")
	var panels_ok: bool = env.flag_panels != null and env.flag_panels.count == 8
	if panels_ok:
		for record: Dictionary in env.flag_panels.records:
			var u: float = fposmod(float(record.s) - Layout.PIT_ENTRY_S + 45.0, lap)
			panels_ok = panels_ok and not (float(record.side) < 0.0 and u <= Layout.PIT_LANE_LENGTH_M + 90.0)
	check(panels_ok, "Eight FIA flag panels, none on the left inside the pit corridor")
	var markers_ok: bool = true
	for record: Dictionary in furniture.marker_records:
		markers_ok = markers_ok and not (float(record.side) < 0.0 and fposmod(float(record.s) - Layout.PIT_ENTRY_S, lap) <= Layout.PIT_LANE_LENGTH_M)
	check(markers_ok, "No braking board stands in the left pit corridor")
	var signs_ok: bool = true
	var sign_count: int = 0
	for sign: Node in pit.find_children("PitSign_*", "Node3D", true, false):
		sign_count += 1
		var at: Vector3 = (sign as Node3D).global_position
		var nearest: float = ribbon.curve.get_closest_offset(ribbon.to_local(at))
		var centre: Transform3D = ribbon.get_point_at_offset(nearest, 0.0)
		var lateral: float = (at - centre.origin).dot(centre.basis.x)
		signs_ok = signs_ok and lateral < -SIGN_LATERAL_M + 0.5 and lateral > -SIGN_LATERAL_M - 0.5
	check(sign_count == 3 and signs_ok, "PIT IN / 80 / PIT OUT stand on the left at 17.75 m (%d signs)" % sign_count)
	var landmarks_clear: bool = true
	for record: Dictionary in env.stats().get("landmarks", []):
		landmarks_clear = landmarks_clear and bool(record.get("placed", false)) and float(record.get("placed_lateral_m", 0.0)) >= half + Layout.PIT_FACADE_X
	check(landmarks_clear, "Every hero landmark stands clear of the road and the pit apron")

	# --- environment, terrain, budgets ------------------------------------------------------
	check(env.built and circuit.find_child("RubberGroove", true, false) != null, "Environment built with the racing-line rubber groove")
	check(circuit.find_child("PitAsphalt", true, false) != null and circuit.find_child("PitApron", true, false) != null, "Pit asphalt and working apron exist")
	check(env.kerbs.size() >= 7, "Kerbs cover the sharp corners in at least seven runs (%d)" % env.kerbs.size())
	var stats: Dictionary = env.stats()
	check(int(stats.get("landmarks_placed", 0)) == 4, "All four approved hero landmarks placed (%d)" % int(stats.get("landmarks_placed", 0)))
	check(int(stats.get("tree_count", 0)) == 1400 and int(stats.get("ipe_count", 0)) == 784 and int(stats.get("palm_count", 0)) == 616, "1400 trees: 784 Ipe Amarelo and 616 royal palms")
	check(int(stats.get("grass_count", 0)) == 520 and int(stats.get("shrub_count", 0)) == 400 and int(stats.get("boulder_count", 0)) == 320, "520 grass tufts, 400 undergrowth clumps, 320 laterite boulders")
	check(int(stats.get("reservoir_quads", 0)) > 200 and is_equal_approx(float(stats.get("lake_water_y", 0.0)), -2.2), "Guarapiranga water at -2.20 m over the whole basin (%d quads)" % int(stats.get("reservoir_quads", 0)))
	_check_reservoir(circuit, env)
	check(is_equal_approx(float(stats.get("terrain_min_y", 0.0)), -6.22) and is_equal_approx(float(stats.get("terrain_max_y", 0.0)), 50.13), "Terrain envelope -6.22..+50.13 m (lake floor 3.8 m under the waterline)")
	var triangles: int = int(stats.triangles)
	check(triangles > 0 and triangles <= 430000, "Static environment fits the 430k class (%d)" % triangles)
	check(circuit.find_children("Pending_*", "", true, false).is_empty(), "No Pending_* proxy nodes in the production scene")
	var buried: int = 0
	var floating: int = 0
	for station: int in range(0, int(lap), 6):
		for lateral: float in [-half, 0.0, half]:
			var p := ribbon.get_point_at_offset(float(station), lateral).origin
			var bed: float = env.ground_y_at(p)
			buried += 1 if bed > p.y + 0.02 else 0
			floating += 1 if bed < p.y - 0.4 else 0
	check(buried == 0 and floating == 0, "Rendered terrain supports full asphalt every 6 m (%d buried, %d floating)" % [buried, floating])
	var pit_buried: int = 0
	var pit_floating: int = 0
	for u: int in range(0, int(Layout.PIT_LANE_LENGTH_M), 6):
		var centre_lateral: float = pit.lane_lateral(float(u))
		for lateral: float in [centre_lateral + Layout.PIT_LANE_HALF_M, centre_lateral, centre_lateral - Layout.PIT_LANE_HALF_M]:
			var p: Vector3 = pit.get_pit_transform(float(u), lateral).origin + Vector3.UP * 0.015
			var bed: float = env.ground_y_at(p)
			pit_buried += 1 if bed > p.y + 0.02 else 0
			pit_floating += 1 if bed < p.y - 0.4 else 0
	check(pit_buried == 0 and pit_floating == 0, "Rendered terrain supports the left pit lane (%d buried, %d floating)" % [pit_buried, pit_floating])
	# Paddock slab edges meet the ground. Rendered truth from the retaining wall mesh: its feet reach
	# the terrain everywhere, and no terrain rises over the top of a slab edge or its parapet.
	var wall_node: MeshInstance3D = env.get_node_or_null("PaddockRetainingWall")
	var wall_tops: PackedVector3Array = PackedVector3Array()
	var feet: int = 0
	var hanging: int = 0
	var worst_hang: float = 0.0
	if wall_node != null:
		for vertex: Vector3 in wall_node.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]:
			var w: Vector3 = wall_node.global_transform * vertex
			var s_near: float = ribbon.curve.get_closest_offset(ribbon.to_local(w))
			if w.y > ribbon.get_point_at_offset(s_near, 0.0).origin.y - 0.5:
				wall_tops.append(w)
				continue
			feet += 1
			var hang: float = w.y - env.terrain.height_at(w.x, w.z)
			if hang > 0.05:
				hanging += 1
				worst_hang = maxf(worst_hang, hang)
	check(feet > 100 and hanging == 0, "Every paddock retaining wall and slab end reaches the ground (%d feet, %d hanging, worst %.2f m)" % [feet, hanging, worst_hang])
	var hovering: int = 0
	var worst_reveal: float = 0.0
	var worst_at: String = ""
	for spec: Array in Layout.PADDOCK_APRON_SPECS:
		var edge_points: Array[Vector2] = []
		var s_at: float = float(spec[1])
		while s_at <= float(spec[2]):
			edge_points.append(Vector2(s_at, float(spec[4]) + 0.6))
			s_at += 4.0
		var lat_at: float = float(spec[3]) + 2.0
		while lat_at <= float(spec[4]):
			if not (float(spec[1]) == 0.0 or float(spec[2]) == Layout.LENGTH_M):
				edge_points.append(Vector2(float(spec[1]) - 0.6, lat_at))
				edge_points.append(Vector2(float(spec[2]) + 0.6, lat_at))
			elif float(spec[1]) != 0.0:
				edge_points.append(Vector2(float(spec[1]) - 0.6, lat_at))
			else:
				edge_points.append(Vector2(float(spec[2]) + 0.6, lat_at))
			lat_at += 4.0
		for q: Vector2 in edge_points:
			var slab_frame: Transform3D = ribbon.get_point_at_offset(fposmod(q.x, lap), 0.0)
			var slab_y: float = slab_frame.origin.y + Layout.PADDOCK_APRON_LIFT_M
			var outside: Vector3 = slab_frame.origin + slab_frame.basis.x * (float(spec[0]) * q.y)
			var edge_top: float = slab_y
			for top: Vector3 in wall_tops:
				if Vector2(top.x - outside.x, top.z - outside.z).length() < 2.5:
					edge_top = maxf(edge_top, top.y)
			var reveal: float = edge_top - env.terrain.height_at(outside.x, outside.z)
			if reveal < -0.15:
				hovering += 1
				if reveal < worst_reveal:
					worst_reveal = reveal
					worst_at = "s %.0f lat %.0f" % [q.x, float(spec[0]) * q.y]
	check(hovering == 0, "No paddock slab edge is buried by terrain (%d edge samples, worst %.2f m at %s)" % [hovering, worst_reveal, worst_at])
	for mode: int in [Weather.TimeOfDay.DAY, Weather.TimeOfDay.SUNSET, Weather.TimeOfDay.NIGHT, Weather.TimeOfDay.DAY]:
		env.apply_time_of_day(Weather.compute_time_of_day(mode, 0.0), 0.0)
	env.apply_time_of_day(Weather.compute_time_of_day(Weather.TimeOfDay.DAY, 0.0), 0.7)
	env.apply_wind(0.016, 24.0, 1.0)
	check(env.built and int(env.stats().draw_calls) > 0, "Environment survives DAY/SUNSET/NIGHT, storm gloom and wind")
	check(is_finite(env.ground_y_at(Vector3(3.0, 7.0, -4.0))), "ground_y_at answers with a number")
	circuit.free()
	await process_frame
	print("PAULISTANO: %s (%d failure(s))" % ["PASS" if failures == 0 else "FAIL", failures])
	quit(1 if failures else 0)


func _has_livery(mesh: Mesh, team: int) -> bool:
	if mesh == null:
		return false
	var wanted: Color = preload("res://scripts/car/team_liveries.gd").color_for(team)
	var linear: Color = wanted.srgb_to_linear()
	for surface: int in range(mesh.get_surface_count()):
		for color: Color in mesh.surface_get_arrays(surface)[Mesh.ARRAY_COLOR]:
			for target: Color in [wanted, linear]:
				if absf(color.r - target.r) < 0.01 and absf(color.g - target.g) < 0.01 and absf(color.b - target.b) < 0.01:
					return true
	return false


## The reservoir reads as a lake: the GLB hulls and pontoons float on the waterline, nothing grows in
## the water, the water lies only in the basin (under the waterline, inside the shape), and the
## basin and its banks are one smooth surface, with no lone vertex spiking out of its neighbours
## (the review build carved a strip and left the laterite ridge as rows of pyramids).
func _check_reservoir(circuit: Node, env) -> void:
	var grid: Dictionary = env.terrain.heightgrid
	var water_y: float = float(grid["lake_water_y"])
	var reservoir: Node3D = circuit.find_child("paulistano_guarapiranga_reservoir", true, false)
	var afloat: bool = reservoir != null and absf(reservoir.global_position.y - (water_y + Layout.RESERVOIR_WATERLINE_DEPTH_M)) < 0.01
	check(afloat, "Reservoir GLB rides its waterline: promenade %.2f m over the water" % ((reservoir.global_position.y - water_y) if reservoir else 0.0))
	var wet_plants: int = 0
	for node: Node in env.find_child("Foliage", true, false).find_children("*", "MultiMeshInstance3D", true, false):
		var mm: MultiMesh = (node as MultiMeshInstance3D).multimesh
		for i: int in range(mm.instance_count):
			var at: Vector3 = (node as MultiMeshInstance3D).global_transform * mm.get_instance_transform(i).origin
			wet_plants += 1 if env.terrain.lake_shore_distance(at.x, at.z) < 0.0 else 0
	check(wet_plants == 0, "No tree, shrub, tuft or boulder stands in the reservoir (%d)" % wet_plants)
	var water: MeshInstance3D = env.get_node("ReservoirWater")
	var stray: int = 0
	for v: Vector3 in water.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]:
		stray += 1 if env.terrain.lake_shape(v.x, v.z) > 1.35 else 0
	check(stray == 0, "Water lies only in the basin (%d vertices outside the shape)" % stray)
	var nx: int = int(grid["nx"])
	var nz: int = int(grid["nz"])
	var step: float = float(grid["step"])
	var origin: Vector2 = grid["origin"]
	var heights: PackedFloat32Array = grid["heights"]
	var spikes: int = 0
	var worst: float = 0.0
	for iz: int in range(1, nz - 1):
		for ix: int in range(1, nx - 1):
			var x: float = origin.x + float(ix) * step
			var z: float = origin.y + float(iz) * step
			var sd: float = env.terrain.lake_shore_distance(x, z)
			# Far shore, both ends and the banks; the seawall side is a built wall, not a bank.
			if sd > Layout.LAKE_BANK_M:
				continue
			var mean: float = (heights[(iz - 1) * nx + ix] + heights[(iz + 1) * nx + ix] + heights[iz * nx + ix - 1] + heights[iz * nx + ix + 1]) * 0.25
			var spike: float = absf(heights[iz * nx + ix] - mean)
			if spike > SPIKE_MAX_M and not _seawall_cell(env, x, z):
				spikes += 1
				worst = maxf(worst, spike)
	check(spikes == 0, "Reservoir basin and banks are smooth: no grid vertex spikes more than the natural relief (%.1f m) off its neighbours (%d, worst %.2f m)" % [SPIKE_MAX_M, spikes, worst])


## Cells beside the reservoir seawall (the near shore under the GLB) are a built drop, not a bank.
func _seawall_cell(env, x: float, z: float) -> bool:
	var q: Dictionary = env.terrain.track_query(x, z, 200.0)
	return not q.is_empty() and absf(float(q["s"]) - Layout.LAKE_STATION_S) < 200.0 and absf(float(q["lateral"])) < Layout.LAKE_NEAR_LATERAL_M + 16.0
