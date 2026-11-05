extends SceneTree

## Kurogane Twin-Cross GP production gate, the repo equivalent of the approved sandbox's verify_build.gd
## (15 checks) plus the terrain/asset audit: the homologated 5.800 m clockwise figure-8 (20 turns, 13.5 m
## road, 40 m of climb), the grade-separated crossover at s 2752 x 3924, the truss bridge window
## s 3888-3957, the right-hand pit (signed sim lane, box 6 at s = 107), 0 floating road per metre,
## no terrain above the asphalt, the trench floor on the road bed, everything trackside carried by
## ground or deck, no landmark or pier in the way of a car, the autumn biome counts and the budgets.
## Run: godot --headless --path . -s res://tests/test_kurogane_circuit.gd

const SCENE := "res://scenes/race_world/circuits/kurogane/kurogane_circuit.tscn"
const Registry := preload("res://scripts/core/circuit_calendar_registry.gd")
const Weather := preload("res://scripts/gt/gt_weather.gd")
const Layout := preload("res://scripts/world/circuits/kurogane/kurogane_layout.gd")

## A road sample is "floating" when the ground is further under it than this (the 12 m grid cannot follow a
## 10 % side-slope exactly: the worst measured hover is 1.0 m).
const FLOAT_MAX_M: float = 1.5
## Nothing static may stand closer to the centreline than the road edge plus this.
const ROAD_CLEAR_M: float = 1.0
const ENVIRONMENT_TRIANGLE_BUDGET: int = 320000
const DRAW_CALL_BUDGET: int = 160

var failures: int = 0
var checks: int = 0


func check(ok: bool, description: String) -> void:
	checks += 1
	print("[%s] %s" % ["PASS" if ok else "FAIL", description])
	if not ok:
		failures += 1


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	check(ResourceLoader.exists(SCENE), "Kurogane production scene exists")
	if not ResourceLoader.exists(SCENE):
		quit(1)
		return
	var circuit = (load(SCENE) as PackedScene).instantiate()
	root.add_child(circuit)
	await process_frame
	var ribbon: TrackRibbon = circuit.get_node("TrackRibbon")
	var pit = circuit.get_node("PitLane")
	var env = circuit.get_node("Environment")
	var terrain = env.terrain
	var lap: float = ribbon.length_m
	_check_lap(circuit, ribbon)
	_check_crossover(ribbon, terrain)
	_check_pit(circuit, ribbon, pit, lap)
	_check_ground(ribbon, terrain, env)
	_check_trackside(ribbon, env, terrain)
	_check_landmarks(ribbon, env, terrain)
	_check_paddock(ribbon, env, pit)
	_check_biome_and_budget(circuit, env, terrain)
	_check_moods(circuit, env, pit)
	circuit.free()
	await process_frame
	print("%d checks, %d failure(s)" % [checks, failures])
	quit(1 if failures else 0)


# --- lap, turns, calendar ------------------------------------------------------------------

func _check_lap(circuit, ribbon: TrackRibbon) -> void:
	var lap: float = ribbon.length_m
	check(absf(lap - 5801.389) < 1.0 and is_equal_approx(ribbon.road_half_width_m, 6.75), "Homologated 5.800 m lap, 13.5 m GP road (baked %.3f m)" % lap)
	check(circuit.turns.size() == 20 and circuit.turns[0].name == "T01 First Turn Entry" and circuit.turns[19].name == "T20 Final Corner Out", "All 20 named turns exposed")
	var real_turns: int = 0
	var ordered: bool = true
	var previous: float = -1.0
	for turn: Dictionary in circuit.turns:
		real_turns += 1 if float(turn.radius_m) < 1000.0 and int(turn.direction) != 0 else 0
		ordered = ordered and float(turn.s) > previous
		previous = float(turn.s)
	check(real_turns == 20 and ordered, "Every turn station sits on its corner, in lap order (%d/20 with a real radius)" % real_turns)
	check(absf(circuit.min_turn_radius_m - 31.1) < 0.5, "Minimum radius 31.1 m (%.2f m)" % circuit.min_turn_radius_m)
	check(absf((circuit.max_elevation_m - circuit.min_elevation_m) - 40.0) < 0.5 and circuit.min_elevation_m < 0.5, "40 m of climb from the 0 m underpass to Spoon Summit (%.1f..%.1f m)" % [circuit.min_elevation_m, circuit.max_elevation_m])
	var signed_area: float = 0.0
	for i: int in range(ribbon.curve.point_count - 1):
		var a: Vector3 = ribbon.curve.get_point_position(i)
		var b: Vector3 = ribbon.curve.get_point_position(i + 1)
		signed_area += a.x * b.z - b.x * a.z
	var entry = Registry.get_circuit("kurogane")
	check(entry.scene_path == SCENE and entry.round_number == 10 and entry.direction_clockwise, "Calendar round 10 loads the production module")
	check(signed_area > 0.0, "The baked lap runs clockwise seen from above (signed area %.0f)" % signed_area)
	var preview := load(entry.preview_image_path) as Texture2D
	check(preview != null and preview.get_size() == Vector2(640, 360), "Race setup loads the 640x360 Kurogane poster")
	check(circuit.sectors.size() == 3, "Three timing sectors")


func _check_crossover(ribbon: TrackRibbon, terrain) -> void:
	var lower: Transform3D = ribbon.get_point_at_offset(Layout.CROSS_LOWER_S, 0.0)
	var upper: Transform3D = ribbon.get_point_at_offset(Layout.CROSS_UPPER_S, 0.0)
	var plan: float = Vector2(lower.origin.x - upper.origin.x, lower.origin.z - upper.origin.z).length()
	var clearance: float = upper.origin.y - lower.origin.y
	check(plan < 2.5, "The centreline crosses itself at s 2752 x 3924 (plan distance %.2f m)" % plan)
	check(clearance >= 5.0 and absf(clearance - 26.25) < 0.5, "Grade-separated crossover clearance %.2f m (>= 5 m, measured 26.25 m)" % clearance)
	check(terrain.bridge_span == Layout.BRIDGE_SPAN_S and absf((terrain.bridge_span.y - terrain.bridge_span.x) - 69.0) < 0.01, "Truss deck window s %.0f-%.0f (69 m)" % [terrain.bridge_span.x, terrain.bridge_span.y])
	# The window really covers the gap: where the rendered ground is more than 1.2 m under the road bed, the road is inside it.
	var uncovered: int = 0
	var s: float = Layout.CROSS_UPPER_RANGE.x
	while s <= Layout.CROSS_UPPER_RANGE.y:
		var frame: Transform3D = ribbon.get_point_at_offset(s, 0.0)
		var hovering: bool = frame.origin.y - terrain.height_at(frame.origin.x, frame.origin.z) > FLOAT_MAX_M
		if hovering and (s < terrain.bridge_span.x or s > terrain.bridge_span.y):
			uncovered += 1
		s += 1.0
	check(uncovered == 0, "Every metre of road over the trench is inside the bridge window (%d uncovered)" % uncovered)
	check(terrain.measured_bridge_span != Vector2.ZERO and absf(terrain.measured_bridge_span.x - terrain.bridge_span.x) <= 12.0 and absf(terrain.measured_bridge_span.y - terrain.bridge_span.y) <= 12.0, "The terrain's own measured gap (s %.0f-%.0f) agrees with the window" % [terrain.measured_bridge_span.x, terrain.measured_bridge_span.y])


# --- right-hand pit -----------------------------------------------------------------------------

func _check_pit(circuit, ribbon: TrackRibbon, pit, lap: float) -> void:
	var layout: Dictionary = pit.sim_layout()
	check(layout.stall_pitch_m == 14.0 and layout.queue_gap_m == 8.0, "Production pit keeps the approved 14 m pitch and 8 m queue gap")
	check(is_equal_approx(float(layout.fast_lane_m), 10.8) and is_equal_approx(float(layout.stall_lane_m), 16.5) and is_equal_approx(float(layout.edge_lateral_m), 5.2), "Sim lane on the right: fast lane 10.8 m, boxes 16.5 m, edge 5.2 m")
	check(absf(float(layout.entry_s) - 5600.0) < 0.01 and absf(float(layout.exit_s) - 210.0) < 0.01 and absf(float(layout.lane_length_m) - 410.0) < 0.01, "Pit entry s 5600, exit s 210, 410 m lane through the start line")
	check(absf(float(layout.stall_first_s) - (lap + 37.0)) < 0.01, "First box unwrapped at s = 37")
	var service_s := fposmod(float(layout.stall_first_s) + 5.0 * float(layout.stall_pitch_m), lap)
	check(absf(service_s - 107.0) < 0.01 and is_equal_approx(float(layout.speed_limit_mps), 80.0 / 3.6), "Service bay 6 at s = 107 (%.3f), limiter 80 km/h" % service_s)
	check(pit.stalls.size() == 10 and pit.garages.size() == 10, "Ten boxes and garage sockets")
	var frames_ok: bool = true
	for i: int in range(pit.stalls.size()):
		var stall: Dictionary = pit.stalls[i]
		var centre: Transform3D = ribbon.get_point_at_offset(float(stall.s), 0.0)
		frames_ok = frames_ok and (Transform3D(stall.pose).origin - centre.origin).dot(centre.basis.x) > 16.0
		frames_ok = frames_ok and (pit.garages[i].global_position - centre.origin).dot(centre.basis.x) > 20.0
	check(frames_ok, "Boxes stand 16.5 m and garages 20.6 m to the right of the centreline")
	var gantry = circuit.find_child("StartGantry", true, false)
	check(gantry != null and gantry.pit_side > 0.0 and gantry.lamps.size() == 10, "Start gantry on the line, built for the right-hand pit")
	var env = circuit.get_node("Environment")
	var furniture = env.furniture
	var rail_in_lane: int = 0
	for s: int in range(0, int(lap), 4):
		var u: float = fposmod(float(s) - Layout.PIT_ENTRY_S, lap)
		if u > 10.0 and u < Layout.PIT_LANE_LENGTH_M - 10.0:
			rail_in_lane += 1 if furniture.has_armco_at(1.0, float(s)) else 0
	check(rail_in_lane == 0 and furniture.has_armco_at(-1.0, 50.0) and furniture.has_armco_at(1.0, 2000.0), "Right rail open along the pit lane; the left rail runs past the boxes")
	var towers_ok: bool = true
	for record: Dictionary in furniture.tower_records:
		var u: float = fposmod(float(record.s) - Layout.PIT_ENTRY_S, lap)
		var in_lane: bool = u < Layout.PIT_LANE_LENGTH_M + 70.0 or u > lap - 70.0
		towers_ok = towers_ok and not (float(record.side) > 0.0 and in_lane and float(record.lateral) < 70.0)
	check(towers_ok, "No floodlight mast stands in the right pit lane or paddock")
	check(pit.get_meta("pit_wall_lateral_m") > 0.0 and absf(float(pit.get_meta("pit_wall_lateral_m")) - 8.25) < 0.01, "Pit wall on the right at 8.25 m (the lane's inner edge)")


# --- 0 floating road, trench ------------------------------------------------------------------

func _check_ground(ribbon: TrackRibbon, terrain, env) -> void:
	var lap: float = ribbon.length_m
	var span: Vector2 = terrain.bridge_span
	var floating: int = 0
	var worst: float = 0.0
	var poked: int = 0
	var worst_poke: float = -INF
	var s: float = 0.0
	while s < lap:
		var in_span: bool = s >= span.x and s <= span.y
		for lateral: float in [-6.75, -3.4, 0.0, 3.4, 6.75]:
			var frame: Transform3D = ribbon.get_point_at_offset(s, lateral)
			var gap: float = frame.origin.y - terrain.height_at(frame.origin.x, frame.origin.z)
			if not in_span and gap > FLOAT_MAX_M:
				floating += 1
				worst = maxf(worst, gap)
			if not in_span and gap < 0.03:
				poked += 1
				worst_poke = maxf(worst_poke, -gap)
		s += 1.0
	check(floating == 0, "0 floating road per metre outside the bridge window (%d samples over %.1f m, worst %.2f m)" % [floating, FLOAT_MAX_M, worst])
	check(poked == 0, "No terrain triangle stands within 3 cm of, or above, the asphalt (%d samples, worst %.3f m)" % [poked, worst_poke])
	# Trench floor = road bed - 0.16 m across the road and its Armco (+-12 m) on the lower branch.
	var floor_err: float = 0.0
	for station: float in [2650.0, 2700.0, 2752.0, 2800.0, 2850.0]:
		for lateral: float in [-12.0, -6.75, 0.0, 6.75, 12.0]:
			var frame: Transform3D = ribbon.get_point_at_offset(station, lateral)
			floor_err = maxf(floor_err, absf(terrain.height_at(frame.origin.x, frame.origin.z) - (frame.origin.y - Layout.ROADBED_DROP_M)))
	check(floor_err <= 0.8, "Trench floor follows the lower road bed within the road and its Armco (max %.2f m off bed - 0.16 m)" % floor_err)
	var under: Transform3D = ribbon.get_point_at_offset(Layout.CROSS_LOWER_S, 0.0)
	check(absf(env.ground_y_at(under.origin) - (under.origin.y - Layout.ROADBED_DROP_M)) < 0.5, "ground_y_at in the trench answers the floor (%.2f m)" % env.ground_y_at(under.origin))


# --- trackside, bridge, piers --------------------------------------------------------------------

func _check_trackside(ribbon: TrackRibbon, env, terrain) -> void:
	var furniture = env.furniture
	check(int(furniture.armco_post_count) == furniture.armco_transforms.size() and furniture.armco_transforms.size() > 2200, "Armco runs round the lap (%d posts, run table in step)" % furniture.armco_transforms.size())
	var runs_ok: bool = true
	for run: Dictionary in furniture.armco_runs:
		runs_ok = runs_ok and int(run["first"]) >= 0 and int(run["first"]) + int(run["count"]) <= furniture.armco_transforms.size()
	check(runs_ok, "Every Armco run indexes the posts that survived")
	var unsupported: int = 0
	var worst: float = 0.0
	for pose: Transform3D in furniture.armco_transforms:
		var d: float = pose.origin.y - terrain.height_at(pose.origin.x, pose.origin.z)
		if d > 1.0 or d < -1.5:
			if not env._post_supported(pose.origin):
				unsupported += 1
				worst = maxf(worst, absf(d))
	check(unsupported == 0, "Every Armco post stands on ground or on the bridge deck (%d unsupported, worst %.1f m)" % [unsupported, worst])
	var masts_ok: bool = furniture.tower_transforms.size() == furniture.tower_records.size() and furniture.tower_count == furniture.tower_transforms.size()
	for pose: Transform3D in furniture.tower_transforms:
		masts_ok = masts_ok and absf(pose.origin.y - terrain.height_at(pose.origin.x, pose.origin.z)) < 0.05
	check(masts_ok and furniture.tower_count >= 20, "Floodlight masts (%d) all stand on the ground" % furniture.tower_count)
	# Nothing the kit drew may hang over the trench: kerbs, run-off and gravel lie on ground.
	var hanging: int = 0
	for node_name: String in ["SawtoothKerbsKurogane", "TarmacRunoff", "GravelTraps"]:
		var node := env.get_node_or_null(node_name) as MeshInstance3D
		if node == null:
			continue
		for surface: int in range(node.mesh.get_surface_count()):
			for vertex: Vector3 in node.mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]:
				if vertex.y - terrain.height_at(vertex.x, vertex.z) > FLOAT_MAX_M + 1.0:
					hanging += 1
	check(hanging == 0, "Kerbs, tarmac run-off and gravel all lie on ground (%d hanging vertices)" % hanging)
	# Bridge piers: 3 m off the lower asphalt, and no rail, fence or mast inside them.
	var bridge: Node3D = env.get_node("HeroLandmarks/CrossoverTrussBridge")
	var concrete: MeshInstance3D = null
	for node: Node in bridge.find_children("*", "MeshInstance3D", true, false):
		if "concrete" in String(node.name).to_lower():
			concrete = node as MeshInstance3D
	var pier_gap: float = INF
	var in_pier: int = 0
	if concrete != null:
		var upper: float = ribbon.get_point_at_offset(Layout.CROSS_UPPER_S, 0.0).origin.y
		for vertex: Vector3 in concrete.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]:
			var world: Vector3 = concrete.global_transform * vertex
			if world.y > upper - 4.0:
				continue
			var s: float = Layout.CROSS_LOWER_RANGE.x
			while s <= Layout.CROSS_LOWER_RANGE.y:
				var frame: Transform3D = ribbon.get_point_at_offset(s, 0.0)
				pier_gap = minf(pier_gap, Vector2(frame.origin.x - world.x, frame.origin.z - world.z).length() - ribbon.road_half_width_m)
				s += 1.0
	for pose: Transform3D in furniture.armco_transforms:
		in_pier += 1 if env._in_pier(pose.origin) else 0
	check(pier_gap >= 2.5 and in_pier == 0, "Bridge piers stand %.1f m off the lower asphalt (>= 2.5 m) with no Armco inside (%d)" % [pier_gap, in_pier])


# --- landmarks -----------------------------------------------------------------------------------

func _check_landmarks(ribbon: TrackRibbon, env, terrain) -> void:
	var holder: Node3D = env.get_node("HeroLandmarks")
	var records: Array = env.stats()["landmarks"]
	check(holder.get_child_count() == 4 and records.size() == 4, "Four hero landmark GLBs instantiated (bridge, ferris wheel, reverse tower, shrine)")
	var expect := {"CrossoverTrussBridge": 3922.5, "TaiyouFerrisWheel": 1480.0, "GrandReverseTower": 4830.0, "SpoonRidgeShrine": 3800.0}
	var stations_ok: bool = true
	for record: Dictionary in records:
		var key: String = {"kurogane_crossover_truss_bridge": "CrossoverTrussBridge", "kurogane_giant_ferris_wheel": "TaiyouFerrisWheel", "kurogane_grand_reverse_tower": "GrandReverseTower", "kurogane_suzuka_ridge_shrine": "SpoonRidgeShrine"}.get(String(record["id"]), "")
		stations_ok = stations_ok and key != "" and absf(float(record["s"]) - float(expect[key])) < 0.01
	check(stations_ok, "Landmarks sit on the measured stations (bridge 3922.5, ferris 1480, tower 4830, shrine 3800)")
	var bridge: Node3D = holder.get_node("CrossoverTrussBridge")
	var centre: Transform3D = ribbon.get_point_at_offset(3922.5, 0.0)
	check(Vector2(bridge.global_position.x - centre.origin.x, bridge.global_position.z - centre.origin.z).length() < 1.0 and absf(bridge.global_position.y - (centre.origin.y - 0.10)) < 0.5, "Bridge deck top sits 0.10 m under the road (no wearing course, so nothing z-fights)")
	check(absf(bridge.scale.z - 69.0 / 100.0) < 0.01 or absf(bridge.transform.basis.z.length() - 0.69) < 0.01, "Bridge model scaled to the 69 m gap")
	for name: String in ["TaiyouFerrisWheel", "GrandReverseTower", "SpoonRidgeShrine"]:
		var model: Node3D = holder.get_node(name)
		var ground: float = terrain.height_at(model.global_position.x, model.global_position.z)
		check(absf(model.global_position.y - (ground - 0.05)) < 0.2, "%s stands on its pad (base %.2f m, ground %.2f m)" % [name, model.global_position.y, ground])
		# Footprint vs every stretch of road: the model's real vertices, not just its anchor.
		var nearest: float = INF
		for mesh_node: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
			for vertex: Vector3 in mesh_node.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]:
				var world: Vector3 = mesh_node.global_transform * vertex
				var q: Dictionary = terrain.track_query(world.x, world.z, 400.0)
				if not q.is_empty():
					nearest = minf(nearest, float(q["d"]) - ribbon.road_half_width_m)
		check(nearest >= 25.0, "%s clears every stretch of road by %.0f m" % [name, nearest])


# --- paddock -------------------------------------------------------------------------------------

func _check_paddock(ribbon: TrackRibbon, env, pit) -> void:
	var detail: MeshInstance3D = pit.get_node_or_null("PaddockDetail")
	check(detail != null and int(pit.get_meta("pit_detail_garage_bays", 0)) == 10 and int(pit.get_meta("pit_detail_garage_lights", 0)) == 10, "Garages are furnished: floor, walls, partitions, interior props and a working light in each of the 10 bays")
	var crews_ok: bool = true
	for garage: Node3D in pit.garages:
		var crew := garage.get_node_or_null("StandbyCrew") as MeshInstance3D
		crews_ok = crews_ok and crew != null and crew.mesh != null and crew.mesh.get_surface_count() > 0
	check(crews_ok, "Every bay has its 13-person standby crew")
	var foundation := env.get_node_or_null("RaceControlFoundation") as MeshInstance3D
	var lane_edge: float = Layout.PIT_LANE_OUTER_X
	var inside_lane: bool = true
	if foundation != null:
		var box: BoxMesh = foundation.mesh
		var frame: Transform3D = ribbon.get_point_at_offset(20.0, 0.0)
		var corner: Vector3 = foundation.global_transform * Vector3(-box.size.x * 0.5, 0.0, 0.0)
		inside_lane = (corner - frame.origin).dot(frame.basis.x) < lane_edge
	check(foundation != null and not inside_lane, "The race-control foundation stays off the fast lane (starts beyond %.1f m)" % lane_edge)
	# The painted boxes lie on the apron surface (road + 0.07 m), not under it.
	var paint := pit.get_node_or_null("PitBoxPaint") as MeshInstance3D
	var buried_paint: int = 0
	var painted: int = 0
	if paint != null and paint.mesh != null:
		var verts: PackedVector3Array = paint.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
		for stall: Dictionary in pit.stalls:
			var origin: Vector3 = Transform3D(stall.pose).origin
			var top: float = -INF
			for vertex: Vector3 in verts:
				var world: Vector3 = paint.global_transform * vertex
				if Vector2(world.x - origin.x, world.z - origin.z).length() < 4.0:
					top = maxf(top, world.y)
			painted += 1 if top > -INF else 0
			buried_paint += 1 if top < origin.y + Layout.PIT_APRON_LIFT_M + 0.02 else 0
	check(painted == 10 and buried_paint == 0, "Every team's painted box lies above the apron surface (%d of 10 painted, %d buried)" % [painted, buried_paint])
	var apron := env.get_node_or_null("PitApronBase") as MeshInstance3D
	check(apron != null and env.get_node_or_null("PaddockTerraceBase") != null and env.get_node_or_null("PaddockPark") != null, "Pit apron, terrace and car park have solid ground under them")
	var terrain = env.terrain
	var clear: int = 0
	var sites: PackedVector3Array = env.tree_sites()
	for site: Vector3 in sites:
		var q: Dictionary = terrain.track_query(site.x, site.z, 80.0)
		if not q.is_empty() and float(q["d"]) < 24.0:
			clear += 1
	check(clear == 0, "No tree within 24 m of the asphalt, pit lane or paddock (%d of %d)" % [clear, sites.size()])


# --- biome, budgets, moods ------------------------------------------------------------------------

func _check_biome_and_budget(circuit, env, terrain) -> void:
	var stats: Dictionary = env.stats()
	check(int(stats["momiji_count"]) == 1500 and int(stats["pine_count"]) == 950 and int(stats["rock_count"]) == 120 and int(stats["verge_tufts"]) <= 900, "Autumn biome: 1500 Momiji, 950 pine, 120 rock, verge grass (%d)" % int(stats["verge_tufts"]))
	var purple: int = 0
	for node: Node in circuit.find_children("*", "GeometryInstance3D", true, false):
		purple += 1 if "pending" in String(node.name).to_lower() else 0
	check(purple == 0, "0 placeholder volumes")
	check(int(stats["environment_triangles"]) <= ENVIRONMENT_TRIANGLE_BUDGET, "Environment triangles within %d (%d)" % [ENVIRONMENT_TRIANGLE_BUDGET, int(stats["environment_triangles"])])
	check(int(stats["draw_calls"]) <= DRAW_CALL_BUDGET and int(stats["multimeshes"]) >= 10, "Environment draw calls within %d (%d, %d MultiMeshes)" % [DRAW_CALL_BUDGET, int(stats["draw_calls"]), int(stats["multimeshes"])])
	var range_m: Vector2 = terrain.elevation_range()
	check(range_m.x > -6.0 and range_m.y > 40.0, "Heightfield spans the trench to the ridges (%.1f..%.1f m)" % [range_m.x, range_m.y])
	var skirts: int = 0
	for node: Node in env.get_children():
		skirts += 1 if node.name in ["Terrain", "TerrainSkirt", "TerrainBase", "DistantRidge", "TrenchWalls"] else 0
	check(skirts == 5, "Terrain, skirt, base plane, ridge ring and trench walls are all present")


func _check_moods(circuit, env, pit) -> void:
	var drew: bool = true
	for mode: int in range(3):
		env.apply_time_of_day({"mode": mode, "floodlights": [0.0, 0.5, 1.0][mode], "stars_opacity": [0.0, 0.0, 1.0][mode]}, 0.0)
		env.measure()
		drew = drew and env.draw_calls > 0 and env.draw_calls <= DRAW_CALL_BUDGET
	var lights: Node3D = pit.get_node("PitWorkingLights")
	check(drew and lights.visible, "DAY / SUNSET / NIGHT apply and the pit working lights come on at night")
	env.apply_time_of_day({"mode": 0, "floodlights": 0.0, "stars_opacity": 0.0}, 0.0)
	check(not lights.visible, "The pit working lights go off by day")
