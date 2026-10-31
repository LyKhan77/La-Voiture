extends SceneTree

## The Ardennes set around the road (FASE 16): the pine forest keeps off the asphalt, the corridor kit (kerbs, Armco, Tecpro,
## braking boards, floodlights, flag panels) is the shared Tier A built to this circuit's turns (the four kinks get none of it), the
## pit asphalt's tails open the right-hand Armco, and the whole set stays inside the triangle budget.
## Run: godot --headless --path . -s res://tests/test_ardennes_dressing.gd

const ScenePath := "res://scenes/race_world/circuits/ardennes/ardennes_circuit.tscn"
## No tree within this far of the road's centre line, and no tuft or rock closer than theirs (ArdennesFoliage), plus the guardrail rule.
const TREE_CLEAR_M: float = 23.0
const TUFT_CLEAR_M: float = 8.0
const ROCK_CLEAR_M: float = 45.0
const RAIL_CLEAR_M: float = 9.0
const TRIANGLE_BUDGET: int = 320000

var failures: int = 0


func check(ok: bool, description: String) -> void:
	if not ok:
		failures += 1
		push_error(description)
	print("[%s] %s" % ["PASS" if ok else "FAIL", description])


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var scene := load(ScenePath) as PackedScene
	if scene == null:
		check(false, "#D0 the circuit scene loads")
		_finish()
		return
	var circuit := scene.instantiate() as Node3D
	root.add_child(circuit)
	await process_frame
	var ribbon = circuit.get("ribbon")
	var env = circuit.get_node("Environment")
	var foliage = env.foliage

	var trees: Array = foliage.poses.get("ForestPineA", []) + foliage.poses.get("ForestPineB", [])
	check(trees.size() >= 1800 and int(foliage.tree_count) == trees.size(), "#D1 a dense pine forest of 1800+ trees in two MultiMeshes (%d)" % trees.size())
	var road: PackedVector3Array = _road_samples(ribbon)
	var worst_tree: float = _nearest_road(trees, road)
	check(worst_tree >= TREE_CLEAR_M - 0.6, "#D2 every tree stands %.0f m or more from the road's centre line (nearest %.1f m)" % [TREE_CLEAR_M, worst_tree])
	check(_nearest_road(foliage.poses.get("VergeGrass", []), road) >= TUFT_CLEAR_M - 0.6 and _nearest_road(foliage.poses.get("Rocks", []), road) >= ROCK_CLEAR_M - 0.6,
		"#D3 verge tufts keep %.0f m and rocks %.0f m off the road's centre line" % [TUFT_CLEAR_M, ROCK_CLEAR_M])
	# Behind the guardrail and the trap in front of it: a tree never grows in a gravel trap or a tarmac run-off.
	var in_trap: int = 0
	var rail_extent: Object = env.furniture
	for pose: Transform3D in trees:
		var query: Dictionary = env.terrain.track_query(pose.origin.x, pose.origin.z, 80.0)
		if query.is_empty():
			continue
		var from_edge: float = float(query["d"]) - float(ribbon.road_half_width_m)
		in_trap += 1 if from_edge < float(rail_extent.extent_at(float(query["side"]), float(query["s"]))) + RAIL_CLEAR_M - 0.5 else 0
	check(in_trap == 0, "#D2b every tree stands %.0f m or more behind the guardrail, never in a run-off or gravel trap (%d inside)" % [RAIL_CLEAR_M, in_trap])
	var swaying: int = 0
	for instance: MultiMeshInstance3D in foliage.tree_multimeshes:
		swaying += 1 if instance.material_override is ShaderMaterial and instance.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF else 0
	check(swaying == 2, "#D4 both pine batches sway on the wind shader and cast no shadow (the batch spans the whole lap)")
	var in_forest: int = 0
	for pose: Transform3D in trees:
		in_forest += 1 if String(env.zone_at_point(pose.origin)) == "forest" or env.terrain.height_at(pose.origin.x, pose.origin.z) > 0.0 else 0
	check(in_forest == trees.size(), "#D5 every tree stands on dry ground")

	# Tier A corridor: kerbs on the 16 turns of 15 degrees or more and none on the kinks T2, T3, T4, T11.
	check(env.kerbs.size() == 16, "#D6 16 kerb runs, one per turn of 15 degrees or more (%d)" % env.kerbs.size())
	var on_kink: int = 0
	for kerb: Dictionary in env.kerbs:
		var mid: float = 0.5 * (float(kerb["s0"]) + float(kerb["s1"]))
		for turn: Dictionary in circuit.turns:
			if float(turn["angle_deg"]) < float(circuit.KERB_MIN_ANGLE_DEG) and absf(mid - float(turn["s"])) <= float(turn["span_m"]) * 0.5 + 12.0:
				on_kink += 1
	check(on_kink == 0, "#D7 no kerb stands on a kink (%d)" % on_kink)
	var furniture = env.furniture
	check(furniture != null and int(furniture.armco_post_count) >= 2200, "#D8 the FIA Armco runs round the lap (%d posts)" % (int(furniture.armco_post_count) if furniture != null else 0))
	check(int(furniture.tecpro_count) > 0 and furniture.marker_records.size() >= 16 * 3 - 12 and int(furniture.tower_count) >= 20,
		"#D9 Tecpro barriers (%d), braking boards (%d) and floodlight towers (%d) stand" % [int(furniture.tecpro_count), furniture.marker_records.size(), int(furniture.tower_count)])
	var panels: FlagPanelSet = env.flag_panels
	check(panels != null and panels.count == FlagPanelSet.COUNT, "#D10 eight digital flag panels")
	# The right-hand Armco is open along the pit asphalt and its tails.
	var inside_gap: int = 0
	var gap_from: float = 5220.0 - 65.0
	var gap_until: float = 240.0 + 65.0
	for transform: Transform3D in furniture.armco_transforms:
		var local: Vector3 = ribbon.get_point_at_offset(0.0, 0.0).affine_inverse() * transform.origin
		var s: float = ribbon.curve.get_closest_offset(ribbon.to_local(transform.origin))
		var lateral: float = (ribbon.get_point_at_offset(s, 0.0).affine_inverse() * transform.origin).x
		if lateral > 0.0 and fposmod(s - gap_from, ribbon.length_m) <= fposmod(gap_until - gap_from, ribbon.length_m) - 6.0 and fposmod(s - gap_from, ribbon.length_m) >= 6.0:
			inside_gap += 1
	check(inside_gap == 0, "#D11 no right-hand Armco stands along the pit asphalt and its 65 m tails (%d posts)" % inside_gap)

	# The catch fence stands on the outside of the sharp corners behind the guardrail, never along the pit asphalt or in the tunnel.
	var fence_panels: Array = env.catch_fence.get("panels", [])
	var fence_posts: Array = env.catch_fence.get("posts", [])
	check(fence_panels.size() >= 300 and fence_posts.size() >= fence_panels.size() / 3, "#D14 the catch fence has %d panels and %d posts behind the corner guardrails" % [fence_panels.size(), fence_posts.size()])
	var fence_misplaced: int = 0
	for pose: Transform3D in fence_panels:
		var fence_s: float = ribbon.curve.get_closest_offset(ribbon.to_local(pose.origin))
		var fence_lateral: float = (ribbon.get_point_at_offset(fence_s, 0.0).affine_inverse() * pose.origin).x
		var in_pit_asphalt: bool = fence_lateral > 0.0 and fposmod(fence_s - gap_from, ribbon.length_m) <= fposmod(gap_until - gap_from, ribbon.length_m)
		var in_tunnel: bool = fence_s >= 2660.0 and fence_s <= 2840.0 and absf(fence_lateral) < 14.0
		fence_misplaced += 1 if in_pit_asphalt or in_tunnel else 0
	check(fence_misplaced == 0, "#D15 no catch fence panel stands along the pit asphalt or inside the tunnel (%d)" % fence_misplaced)

	check(env.get_node_or_null("PaddockTrailers") is MeshInstance3D and env.get_node_or_null("PaddockSolids") is MeshInstance3D, "#D16 the parking apron holds the six support trailers on solid paddock slabs")

	# The set stays inside the triangle budget (static count of the environment; the native gate is measure_env_draw_calls.gd).
	var stats: Dictionary = env.stats()
	check(int(stats["triangles"]) <= TRIANGLE_BUDGET, "#D12 the environment costs %d triangles (budget %d)" % [int(stats["triangles"]), TRIANGLE_BUDGET])
	check(int(stats["draw_calls"]) <= 160, "#D13 the environment submits %d draw calls statically (budget 160 per camera)" % int(stats["draw_calls"]))

	circuit.queue_free()
	await process_frame
	_finish()


## The road's centre line every 4 m as flat points.
func _road_samples(ribbon) -> PackedVector3Array:
	var points := PackedVector3Array()
	var s: float = 0.0
	while s < ribbon.length_m:
		points.append(ribbon.get_point_at_offset(s, 0.0).origin)
		s += 4.0
	return points


## The smallest flat distance from any of `poses` to the road samples (a hash of the road keeps the search short).
func _nearest_road(poses: Array, road: PackedVector3Array) -> float:
	var cells: Dictionary = {}
	for index: int in range(road.size()):
		var key := Vector2i(floori(road[index].x / 48.0), floori(road[index].z / 48.0))
		if not cells.has(key):
			cells[key] = []
		(cells[key] as Array).append(index)
	var best: float = INF
	for pose: Transform3D in poses:
		var cell := Vector2i(floori(pose.origin.x / 48.0), floori(pose.origin.z / 48.0))
		for dx: int in range(-1, 2):
			for dz: int in range(-1, 2):
				var key := cell + Vector2i(dx, dz)
				if not cells.has(key):
					continue
				for index: int in cells[key]:
					best = minf(best, Vector2(road[index].x - pose.origin.x, road[index].z - pose.origin.z).length())
	return best


func _finish() -> void:
	print("ARDENNES DRESSING TEST SUITE: %s" % ("PASS" if failures == 0 else "%d FAILURES" % failures))
	quit(0 if failures == 0 else 1)
