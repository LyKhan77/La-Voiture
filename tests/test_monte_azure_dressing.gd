extends SceneTree

## The street dressing of Monte Azure (SPEC 4.4 items 3 and 5): the town (facade blocks as per-district MultiMeshes) and the
## vegetation (palms along the quay, pines and cypresses on the hills), placed by the NEAREST road leg with a clearance from
## every road, on the ground, off the pit deck and the hero plazas, never in the water.
## Run: godot --headless --path . -s res://tests/test_monte_azure_dressing.gd

const ScenePath := "res://scenes/race_world/circuits/monte_azure/monte_azure_circuit.tscn"
## SPEC 4.4: 5.5 road half width + 1.0 barrier + 4.0 frontage.
const ROAD_CLEAR_M: float = 10.5
const MIN_BUILDINGS: int = 120
const MIN_TREES: Dictionary = {"palms": 100, "pines": 120, "cypresses": 80}

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
	var circuit := scene.instantiate() as Node3D
	root.add_child(circuit)
	await process_frame
	var ribbon = circuit.get("ribbon")
	var env = circuit.get_node("Environment")
	var terrain = env.terrain
	var districts = env.get_node_or_null("Districts")
	var foliage = env.get_node_or_null("Foliage")
	check(districts != null and foliage != null, "#D1 the environment has Districts and Foliage layers")
	if districts == null or foliage == null:
		circuit.queue_free()
		_finish()
		return

	# --- the town ------------------------------------------------------------------------------------
	var buildings: Array = districts.buildings
	check(buildings.size() >= MIN_BUILDINGS, "#D2 at least %d facade blocks stand in the urban zones (got %d)" % [MIN_BUILDINGS, buildings.size()])
	var chunks: Array[Node] = districts.get_children().filter(func(n: Node) -> bool: return n is MultiMeshInstance3D)
	var in_chunks: int = 0
	var shadowless: bool = true
	for chunk: Node in chunks:
		in_chunks += (chunk as MultiMeshInstance3D).multimesh.instance_count
		shadowless = shadowless and (chunk as MultiMeshInstance3D).cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	check(chunks.size() >= 3 and in_chunks == buildings.size(), "#D3 the blocks are batched per district: %d MultiMeshes hold all %d (not one for the whole lap, so the frustum can cull them)" % [chunks.size(), buildings.size()])
	var too_close: int = 0
	var wrong_zone: int = 0
	var underwater: int = 0
	var on_deck: int = 0
	var floating: int = 0
	var overlapping: int = 0
	for index: int in range(buildings.size()):
		var building: Dictionary = buildings[index]
		var pose: Transform3D = building["pose"]
		var half := Vector2(float(building["width_m"]), float(building["depth_m"])) * 0.5
		var low: float = INF
		var high: float = -INF
		for corner: Vector2 in [Vector2(-half.x, -half.y), Vector2(half.x, -half.y), Vector2(half.x, half.y), Vector2(-half.x, half.y), Vector2.ZERO]:
			var p: Vector3 = pose * Vector3(corner.x, 0.0, corner.y)
			var station: int = terrain.nearest_station(p.x, p.z)
			var distance: float = Vector2(p.x - terrain.station_pos[station].x, p.z - terrain.station_pos[station].z).length()
			too_close += 1 if distance < ROAD_CLEAR_M else 0
			var ground: float = terrain.height_at(p.x, p.z)
			low = minf(low, ground)
			high = maxf(high, ground)
			underwater += 1 if ground < 0.15 else 0
			on_deck += 1 if terrain.is_deck_at(p.x, p.z) else 0
		var centre: Vector3 = pose.origin
		wrong_zone += 1 if String(terrain.zone_at_point(centre.x, centre.z)) != String(building["zone"]) or not String(building["zone"]) in ["urban", "paddock"] else 0
		floating += 1 if pose.origin.y > low + 0.05 else 0
		for other_index: int in range(index + 1, buildings.size()):
			var other: Dictionary = buildings[other_index]
			var gap: float = Vector2(centre.x - (other["pose"] as Transform3D).origin.x, centre.z - (other["pose"] as Transform3D).origin.z).length()
			overlapping += 1 if gap < (maxf(float(building["width_m"]), float(building["depth_m"])) + maxf(float(other["width_m"]), float(other["depth_m"]))) * 0.5 * 0.7 else 0
	check(too_close == 0, "#D4 every block corner keeps %.1f m from every road leg, not just its own (%d too close)" % [ROAD_CLEAR_M, too_close])
	check(wrong_zone == 0, "#D5 every block stands in the urban or paddock zone of its NEAREST leg, the one it was built for (%d elsewhere)" % wrong_zone)
	var sheds: int = 0
	var flats: bool = true
	for building: Dictionary in buildings:
		if String(building["zone"]) == "paddock":
			sheds += 1
			flats = flats and float(building["height_m"]) <= 14.0 and float(building["roof_style"]) == 1.0
	check(sheds >= 15 and flats, "#D5b the marina yards (paddock zone) carry low sheds with flat roofs (%d sheds)" % sheds)
	check(underwater == 0 and on_deck == 0, "#D6 no block stands in the water or on the pit deck / hero plazas (%d underwater, %d on deck)" % [underwater, on_deck])
	check(floating == 0, "#D7 every block is seated at or under the lowest ground of its footprint (%d floating)" % floating)
	check(overlapping == 0, "#D8 blocks do not overlap (%d pairs)" % overlapping)
	var plain: int = 0
	for chunk: Node in chunks:
		var material: Material = (chunk as MultiMeshInstance3D).material_override
		plain += 0 if material is ShaderMaterial and material.next_pass != null else 1
	check(plain == 0 and shadowless, "#D9 every district is cel-shaded with an ink outline pass and casts no shadow (%d plain)" % plain)
	# Time of day: the facade shader gets the night factor.
	var material: ShaderMaterial = (chunks[0] as MultiMeshInstance3D).material_override
	env.apply_time_of_day({"mode": 2, "floodlights": 1.0, "stars_opacity": 1.0}, 0.0)
	var night: float = float(material.get_shader_parameter("night"))
	env.apply_time_of_day({"mode": 0, "floodlights": 0.0, "stars_opacity": 0.0}, 0.0)
	check(night > 0.9 and float(material.get_shader_parameter("night")) < 0.1, "#D10 the facade windows light up at night and go dark by day (night %.2f)" % night)

	# --- the vegetation ------------------------------------------------------------------------------
	for kind: String in MIN_TREES:
		var instance := foliage.get_node_or_null(kind.capitalize()) as MultiMeshInstance3D
		var count: int = instance.multimesh.instance_count if instance != null else 0
		check(instance != null and count >= int(MIN_TREES[kind]) and instance.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF,
			"#D11 %s: >= %d instances, shadowless (got %d)" % [kind, int(MIN_TREES[kind]), count])
	var poses: Array = foliage.poses
	var bad_clear: int = 0
	var bad_ground: int = 0
	var bad_water: int = 0
	var bad_deck: int = 0
	for entry: Dictionary in poses:
		var p: Vector3 = (entry["pose"] as Transform3D).origin
		var station: int = terrain.nearest_station(p.x, p.z)
		bad_clear += 1 if Vector2(p.x - terrain.station_pos[station].x, p.z - terrain.station_pos[station].z).length() < ROAD_CLEAR_M else 0
		var ground: float = terrain.height_at(p.x, p.z)
		bad_ground += 1 if absf(p.y - ground) > 0.6 else 0
		bad_water += 1 if ground < 0.15 else 0
		bad_deck += 1 if terrain.is_deck_at(p.x, p.z) else 0
	check(poses.size() >= 300, "#D12 the foliage keeps every pose (%d)" % poses.size())
	check(bad_clear == 0 and bad_ground == 0 and bad_water == 0 and bad_deck == 0,
		"#D13 every tree stands on dry, undecked ground %.1f m from every road (%d near a road, %d off the ground, %d in the water, %d on a deck)" % [ROAD_CLEAR_M, bad_clear, bad_ground, bad_water, bad_deck])
	var palms_on_quay: int = 0
	for entry: Dictionary in poses:
		if String(entry["kind"]) == "palms":
			var p: Vector3 = (entry["pose"] as Transform3D).origin
			palms_on_quay += 1 if String(terrain.zone_at_point(p.x, p.z)) in ["water", "urban"] else 0
	check(palms_on_quay >= 60, "#D14 palms line the quay and the town streets (%d)" % palms_on_quay)

	circuit.queue_free()
	await process_frame
	_finish()


func _finish() -> void:
	print("MONTE AZURE DRESSING TEST SUITE: %s" % ("PASS" if failures == 0 else "%d FAILURES" % failures))
	quit(0 if failures == 0 else 1)
