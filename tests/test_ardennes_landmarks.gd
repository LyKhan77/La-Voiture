extends SceneTree

## The hero landmarks of Ardennes Valley Ring (FASE 16): the four road-side heroes seated on the road by the blueprint's stations
## and the pit building in the pit complex, all from the five GLBs of the approved mapgen sandbox. What matters in play: the
## acoustic canopy tunnel is open (cars drive through its bore in both directions), the flyover's deck clears the road, the viaduct
## stands in the river and well off every road, the glass terrace stands clear of the road and of the main grandstand.
## Run: godot --headless --path . -s res://tests/test_ardennes_landmarks.gd

const ScenePath := "res://scenes/race_world/circuits/ardennes/ardennes_circuit.tscn"
const ModelDir := "res://assets/tracks/ardennes/models/"
const GLBS: Array[String] = ["valley_arch_viaduct", "kemmel_pedestrian_flyover", "acoustic_canopy_tunnel", "glass_terrace_grandstand", "futuristic_pit_building"]
const HEROES: Array[String] = ["ValleyArchViaduct", "KemmelFlyover", "AcousticCanopyTunnel", "GlassTerraceGrandstand"]

var failures: int = 0


func check(ok: bool, description: String) -> void:
	if not ok:
		failures += 1
		push_error(description)
	print("[%s] %s" % ["PASS" if ok else "FAIL", description])


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var present: bool = FileAccess.file_exists(ModelDir + "asset_manifest.json")
	for stem: String in GLBS:
		present = present and ResourceLoader.exists(ModelDir + stem + ".glb")
	check(present, "#L0 the five GLBs and asset_manifest.json are in assets/tracks/ardennes/models")
	var scene := load(ScenePath) as PackedScene
	if scene == null or not present:
		_finish()
		return
	var circuit := scene.instantiate() as Node3D
	root.add_child(circuit)
	await process_frame
	var ribbon = circuit.get("ribbon")
	var env = circuit.get_node("Environment")
	var heroes: Node3D = env.get_node_or_null("HeroLandmarks") as Node3D
	var pit = circuit.get_node("PitLane")
	check(heroes != null and HEROES.all(func(name: String) -> bool: return heroes.get_node_or_null(name) != null), "#L1 HeroLandmarks holds the viaduct, the flyover, the tunnel and the glass terrace")
	check(pit.get_node_or_null("PitBuilding") != null, "#L1b the fifth hero, the futuristic pit building, stands in the pit complex")
	if heroes == null:
		circuit.queue_free()
		_finish()
		return
	var records: Array = env.landmarks.records
	var budget_ok: bool = records.size() == 4
	for record: Dictionary in records:
		budget_ok = budget_ok and int(record["triangles"]) >= 500 and int(record["triangles"]) <= 30000
	check(budget_ok, "#L2 every landmark is real geometry within budget (%s)" % str(records.map(func(r: Dictionary) -> int: return int(r["triangles"]))))

	var tunnel := heroes.get_node("AcousticCanopyTunnel") as Node3D
	var meshes: Array[Node] = tunnel.find_children("*", "MeshInstance3D", true, false)
	check(meshes.size() >= 1 and meshes.size() <= 3, "#L3 the thirty tunnel bays merge into at most three meshes (%d)" % meshes.size())
	var span := AABB()
	var first: bool = true
	for node: Node in meshes:
		var box: AABB = (node as MeshInstance3D).global_transform * (node as MeshInstance3D).mesh.get_aabb()
		span = box if first else span.merge(box)
		first = false
	check(maxf(span.size.x, span.size.z) >= 175.0 and span.size.y >= 10.0, "#L3b the canopy covers about 180 m of road and rises over 10 m (%.0f m long, %.1f m high)" % [maxf(span.size.x, span.size.z), span.size.y])

	# The road is clear through the tunnel: rays along the road at car height meet no triangle in either direction.
	var body := StaticBody3D.new()
	root.add_child(body)
	for hero_name: String in HEROES:
		for node: Node in heroes.get_node(hero_name).find_children("*", "MeshInstance3D", true, false):
			var instance := node as MeshInstance3D
			if instance.name == "Glass" or instance.mesh == null:
				continue
			var shape := CollisionShape3D.new()
			shape.shape = instance.mesh.create_trimesh_shape()
			shape.transform = instance.global_transform
			body.add_child(shape)
	await physics_frame
	var space := root.world_3d.direct_space_state
	var blocked: int = 0
	var probes: int = 0
	for lateral: float in [-5.0, 0.0, 5.0]:
		for height: float in [0.6, 2.0, 3.5, 5.0]:
			# The road bends through the canopy (T9 at s~2696): the rays follow it in 3 m legs, forwards and backwards.
			for leg: int in range(80):
				var a: Vector3 = ribbon.get_point_at_offset(2630.0 + 3.0 * float(leg), lateral).origin + Vector3.UP * height
				var b: Vector3 = ribbon.get_point_at_offset(2630.0 + 3.0 * float(leg + 1), lateral).origin + Vector3.UP * height
				for pair: Array in [[a, b], [b, a]]:
					probes += 1
					blocked += 0 if space.intersect_ray(PhysicsRayQueryParameters3D.create(pair[0], pair[1])).is_empty() else 1
	check(blocked == 0, "#L4 the road is open through the acoustic tunnel in both directions: %d of %d car-height rays blocked" % [blocked, probes])

	# The flyover's deck clears the road: straight up from every metre across the carriageway.
	var lowest: float = INF
	var s_probe: float = 1400.0
	for step_s: int in range(-6, 7):
		for lateral: float in [-7.0, -3.5, 0.0, 3.5, 7.0]:
			var ground: Vector3 = ribbon.get_point_at_offset(s_probe + float(step_s), lateral).origin
			var hit: Dictionary = space.intersect_ray(PhysicsRayQueryParameters3D.create(ground + Vector3.UP * 0.3, ground + Vector3.UP * 30.0))
			if not hit.is_empty():
				lowest = minf(lowest, (hit["position"] as Vector3).y - ground.y)
	check(lowest >= 6.0, "#L5 the flyover's deck stands at least 6 m over the road (lowest %.2f m)" % (lowest if lowest < INF else 99.0))
	body.queue_free()

	var water_level: float = float(env.terrain.water_level)
	var viaduct := heroes.get_node("ValleyArchViaduct") as Node3D
	var viaduct_box: AABB = _bounds(viaduct)
	check(absf(viaduct_box.position.y - (water_level - 2.0)) <= 0.5 and viaduct_box.size.y >= 30.0, "#L6 the viaduct's feet stand 2 m under the river's surface and it rises over 30 m (base %.1f, %.1f m high)" % [viaduct_box.position.y, viaduct_box.size.y])
	check(_clearance(ribbon, viaduct_box, 680.0) >= 25.0, "#L6b the viaduct stands 25 m or more from every other stretch of road (%.0f m)" % _clearance(ribbon, viaduct_box, 680.0))
	var stand_box: AABB = _bounds(heroes.get_node("GlassTerraceGrandstand") as Node3D)
	var main_stand: Node3D = pit.get_node("MainGrandstand") as Node3D
	check(_clearance(ribbon, stand_box, 5280.0) >= 24.0 and absf(stand_box.size.z - 222.0) <= 3.0 or absf(stand_box.size.x - 222.0) <= 3.0, "#L7 the glass terrace is 222 m long and stands 24 m or more from the road (%.0f m)" % _clearance(ribbon, stand_box, 5280.0))
	var main_s: float = _arc_of(ribbon, main_stand.global_position)
	var glass_s: float = _arc_of(ribbon, stand_box.get_center())
	var gap: float = fposmod(main_s - glass_s, ribbon.length_m) - 120.0 - 111.0
	check(gap >= 10.0, "#L8 the two grandstands do not overlap: %.0f m of clear line between the glass terrace and the main stand" % gap)

	var before: float = float((env.landmarks.glass_materials[0] as ShaderMaterial).get_shader_parameter("glow_energy"))
	env.landmarks.set_night(1.0)
	var after: float = float((env.landmarks.glass_materials[0] as ShaderMaterial).get_shader_parameter("glow_energy"))
	env.landmarks.set_night(0.0)
	check(after > before, "#L9 the glass lights up at night (glow %.2f -> %.2f)" % [before, after])

	circuit.queue_free()
	await process_frame
	_finish()


func _bounds(node: Node3D) -> AABB:
	var merged := AABB()
	var first: bool = true
	for child: Node in node.find_children("*", "MeshInstance3D", true, false):
		var instance := child as MeshInstance3D
		if instance.mesh == null:
			continue
		var box: AABB = instance.global_transform * instance.mesh.get_aabb()
		merged = box if first else merged.merge(box)
		first = false
	return merged


## The shortest flat distance from the corners and the centre of `box` to the road, ignoring the road within 150 m of `own_s`.
func _clearance(ribbon, box: AABB, own_s: float) -> float:
	var points: Array[Vector2] = [Vector2(box.get_center().x, box.get_center().z)]
	for corner: int in range(8):
		var c: Vector3 = box.get_endpoint(corner)
		points.append(Vector2(c.x, c.z))
	var best: float = INF
	var s: float = 0.0
	while s < ribbon.length_m:
		var gap_s: float = absf(fposmod(s - own_s + ribbon.length_m * 0.5, ribbon.length_m) - ribbon.length_m * 0.5)
		var road: Vector3 = ribbon.get_point_at_offset(s, 0.0).origin
		for point: Vector2 in points:
			var d: float = point.distance_to(Vector2(road.x, road.z)) - ribbon.road_half_width_m
			best = minf(best, d if gap_s > 150.0 else INF)
		s += 8.0
	return best


func _arc_of(ribbon, point: Vector3) -> float:
	var best: float = 0.0
	var best_distance: float = INF
	var s: float = 0.0
	while s < ribbon.length_m:
		var d: float = ribbon.get_point_at_offset(s, 0.0).origin.distance_to(Vector3(point.x, ribbon.get_point_at_offset(s, 0.0).origin.y, point.z))
		if d < best_distance:
			best_distance = d
			best = s
		s += 2.0
	return best


func _finish() -> void:
	print("ARDENNES LANDMARKS TEST SUITE: %s" % ("PASS" if failures == 0 else "%d FAILURES" % failures))
	quit(0 if failures == 0 else 1)
