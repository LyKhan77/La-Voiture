extends SceneTree

const Race := preload("res://scripts/gt/gt_race.gd")
var failures: int = 0

func check(ok: bool, description: String) -> void:
	print("[%s] %s" % ["PASS" if ok else "FAIL", description])
	if not ok:
		failures += 1

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var scene: PackedScene = load("res://scenes/race_world/brianza_circuit.tscn")
	var circuit: Node = scene.instantiate()
	root.add_child(circuit)
	await process_frame
	var pit: Node = circuit.get_node("PitLane")
	var layout: Dictionary = pit.sim_layout()
	check(layout.entry_s == 5530.0 and layout.exit_s == 150.0 and layout.lane_length_m == 410.0 and layout.lane_ramp_in_m == 80.0 and layout.lane_ramp_out_m == 90.0 and layout.edge_lateral_m == 5.2 and layout.stall_first_s == 5600.0, "pit simulation uses K1 layout")
	check(is_equal_approx(pit.lane_lateral(0.0), 5.2) and is_equal_approx(pit.lane_lateral(80.0), 11.6) and is_equal_approx(pit.lane_lateral(410.0), 5.2), "pit path uses 80/90 metre ramps")
	var minimum_radius: float = INF
	for s: int in range(5596, 5745, 4):
		minimum_radius = minf(minimum_radius, circuit.ribbon.get_radius_at(float(s)))
	check(minimum_radius >= 250.0, "pit building sits on the straight (minimum %.1f m)" % minimum_radius)
	var asphalt: MeshInstance3D = pit.get_node("PitAsphalt")
	check(asphalt.material_override is ShaderMaterial and (asphalt.material_override as ShaderMaterial).shader == load("res://shaders/road_asphalt.gdshader"), "pit uses road asphalt shader")
	var wall_ok: bool = pit.has_method("solid_footprints") and pit.has_method("wall_span_u")
	if wall_ok:
		wall_ok = pit.wall_end_cushions.size() == 2 and pit.wall_lateral(pit.wall_span_u().x) >= circuit.ribbon.road_half_width_m + 1.09
		for footprint: Dictionary in pit.solid_footprints():
			for u: int in range(int(footprint.u0), int(footprint.u1) + 1, 2):
				var path: float = pit.lane_lateral(float(u))
				wall_ok = wall_ok and (float(footprint.lat1) < path - 1.1 or float(footprint.lat0) > path + 1.1)
	check(wall_ok, "wall and cushions clear car path, with a cushion at each end")
	var cushions_ok: bool = true
	for i: int in range(pit.wall_end_cushions.size()):
		var cushion: Dictionary = pit.wall_end_cushions[i]
		if not cushion.has("blocks"):
			cushions_ok = false
			continue
		var poses: Array = cushion.blocks
		var expected: Vector3 = pit.get_pit_transform(float(cushion.u) + (-1.6 if i == 0 else 1.6), pit.wall_lateral(float(cushion.u))).origin
		cushions_ok = cushions_ok and (poses[-1] as Transform3D).origin.distance_to(expected + Vector3.UP * 0.45) < 0.01
	check(cushions_ok, "cushion blocks extend outside both wall ends")
	var matching: bool = true
	for u: float in [0.0, 20.0, 80.0, 200.0, 330.0, 410.0]:
		matching = matching and absf(Race.lane_lateral_at(u, 410.0, layout) - pit.lane_lateral(u)) < 0.001
	check(matching, "simulation and rendered lane use the same path")
	var reverse: Array[int] = [9,8,7,6,5,4,3,2,1,0]
	var identity: Array[int] = [0,1,2,3,4,5,6,7,8,9]
	pit.build(circuit.ribbon, reverse)
	var remapped: bool = pit.stall_index_for_team(9) == 0 and int(pit.stall_markings[0].team) == 9 and int(pit.stall_markings[0].number) == 10
	var garage_mesh: Mesh = (pit.garages[0].get_node("GarageShell") as MeshInstance3D).mesh if pit.garages[0].has_node("GarageShell") else null
	var color_found: bool = false
	if garage_mesh != null:
		for surface: int in range(garage_mesh.get_surface_count()):
			var colors: PackedColorArray = garage_mesh.surface_get_arrays(surface)[Mesh.ARRAY_COLOR]
			var expected: Color = preload("res://scripts/car/team_liveries.gd").color_for(9).srgb_to_linear()
			for color: Color in colors:
				color_found = color_found or (absf(color.r - expected.r) < 0.005 and absf(color.g - expected.g) < 0.005 and absf(color.b - expected.b) < 0.005)
	remapped = remapped and color_found
	var count: int = pit.get_child_count()
	pit.build(circuit.ribbon, identity)
	check(remapped and pit.stall_index_for_team(0) == 0 and pit.get_child_count() == count, "rebuild remaps teams without duplicate nodes")
	check("garage_equipment" in pit and pit.garage_equipment.size() == 10, "ten garages have pit equipment")
	var floor_found: bool = false
	var gear: MultiMeshInstance3D = pit.get_node("GarageEquipment")
	var faces: PackedVector3Array = gear.multimesh.mesh.get_faces()
	var probe := Vector2(4.5, 0.0)
	for i: int in range(0, faces.size(), 3):
		var a: Vector3 = faces[i]
		var b: Vector3 = faces[i + 1]
		var c: Vector3 = faces[i + 2]
		if absf(a.y - 0.02) > 0.001 or absf(b.y - 0.02) > 0.001 or absf(c.y - 0.02) > 0.001:
			continue
		var a2 := Vector2(a.x, a.z)
		var b2 := Vector2(b.x, b.z)
		var c2 := Vector2(c.x, c.z)
		var denominator: float = (b2 - a2).cross(c2 - a2)
		if absf(denominator) < 0.00001:
			continue
		var u: float = (probe - a2).cross(c2 - a2) / denominator
		var v: float = (b2 - a2).cross(probe - a2) / denominator
		floor_found = floor_found or (u >= 0.0 and v >= 0.0 and u + v <= 1.0)
	check(floor_found, "garage has solid floor beneath the crew")
	var apron_connected: bool = true
	for stall: Dictionary in pit.stalls:
		apron_connected = apron_connected and pit.lane_edges(float(stall.u)).y >= pit.GARAGE_FRONT_M
	check(apron_connected, "pit asphalt connects to every garage floor")
	check("speed_limit_lines_u" in pit and pit.speed_limit_lines_u.size() == 2 and "lane_separator_count" in pit and pit.lane_separator_count == 1 and "stall_markings" in pit and pit.stall_markings.size() == 10, "limiter, separator and ten numbered box markings exist")
	check(pit.get_node_or_null("LaneSigns") != null and pit.get_node_or_null("BoardPITLANE") != null and pit.get_node_or_null("BoardPITEXIT") != null, "pit lane and exit signs exist")
	for name: String in ["PitEntryChevrons", "PitEntryGantry", "PitWallFence", "PitWallSponsorStrip"]:
		check(pit.get_node_or_null(name) != null, "%s exists" % name)
	var chevron_clear: bool = true
	var chevrons: MeshInstance3D = pit.get_node("PitEntryChevrons")
	for vertex: Vector3 in chevrons.mesh.get_faces():
		var closest: float = INF
		for u: int in range(20, 65):
			var center: Vector3 = pit.get_pit_transform(float(u), 0.0).origin
			closest = minf(closest, Vector2(vertex.x - center.x, vertex.z - center.z).length())
		chevron_clear = chevron_clear and closest >= 7.0
	check(chevron_clear, "entry chevrons remain outside the race track")
	check("drum_poses" in pit and "fence_poses" in pit and pit.drum_poses.size() == 5 and pit.fence_poses.size() >= 80, "nose drums and continuous wall fence exist")
	check(pit.solid_footprints().any(func(fp: Dictionary) -> bool: return fp.name == "gantry_leg"), "gantry leg is included in clearance gate")
	circuit.free()
	quit(1 if failures else 0)
