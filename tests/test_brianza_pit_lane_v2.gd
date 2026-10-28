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
	var matching: bool = true
	for u: float in [0.0, 20.0, 80.0, 200.0, 330.0, 410.0]:
		matching = matching and absf(Race.lane_lateral_at(u, 410.0, layout) - pit.lane_lateral(u)) < 0.001
	check(matching, "simulation and rendered lane use the same path")
	var reverse: Array[int] = [9,8,7,6,5,4,3,2,1,0]
	var identity: Array[int] = [0,1,2,3,4,5,6,7,8,9]
	pit.build(circuit.ribbon, reverse)
	var remapped: bool = pit.stall_index_for_team(9) == 0
	var count: int = pit.get_child_count()
	pit.build(circuit.ribbon, identity)
	check(remapped and pit.stall_index_for_team(0) == 0 and pit.get_child_count() == count, "rebuild remaps teams without duplicate nodes")
	check("garage_equipment" in pit and pit.garage_equipment.size() == 10, "ten garages have pit equipment")
	check("speed_limit_lines_u" in pit and pit.speed_limit_lines_u.size() == 2 and "lane_separator_count" in pit and pit.lane_separator_count == 1 and "stall_markings" in pit and pit.stall_markings.size() == 10, "limiter, separator and ten numbered box markings exist")
	check(pit.get_node_or_null("LaneSigns") != null and pit.get_node_or_null("BoardPITLANE") != null and pit.get_node_or_null("BoardPITEXIT") != null, "pit lane and exit signs exist")
	for name: String in ["PitEntryChevrons", "PitEntryGantry", "PitWallFence", "PitWallSponsorStrip"]:
		check(pit.get_node_or_null(name) != null, "%s exists" % name)
	check("drum_poses" in pit and "fence_poses" in pit and pit.drum_poses.size() == 5 and pit.fence_poses.size() >= 80, "nose drums and continuous wall fence exist")
	check(pit.solid_footprints().any(func(fp: Dictionary) -> bool: return fp.name == "gantry_leg"), "gantry leg is included in clearance gate")
	circuit.free()
	quit(1 if failures else 0)
