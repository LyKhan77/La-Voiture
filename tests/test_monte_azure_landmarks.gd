extends SceneTree

## The five hero landmarks of Monte Azure (SPEC 4.4 item 5): placed by the blueprint's stations, standing on the ground,
## cel-shaded with an ink outline, and above all LOGICAL: the cliff tunnel carries the road through its bore (it is
## shorter than the straight it stands on), the skybridge spans the whole road on pylons outside the barrier, the
## casino, hotel and yachts keep clear of every road.
## Run: godot --headless --path . -s res://tests/test_monte_azure_landmarks.gd

const ScenePath := "res://scenes/race_world/circuits/monte_azure/monte_azure_circuit.tscn"
const ModelDir := "res://assets/tracks/monte_azure/models/"
const FILES: Array[String] = ["casino_palace", "fairmont_hairpin_hotel", "azure_cliff_tunnel", "superyacht_luxury_pack", "harbor_pedestrian_skybridge"]
const NODES: Array[String] = ["CasinoPalace", "GrandHotelFairmont", "CliffTunnel", "YachtPack", "HarborSkybridge"]
## The straight between Tunnel In (T7) and Tunnel Out (T8): the tunnel must fit inside it.
const STRAIGHT_S0: float = 1247.0
const STRAIGHT_S1: float = 1413.0

var failures: int = 0


func check(ok: bool, description: String) -> void:
	if not ok:
		failures += 1
		push_error(description)
	print("[%s] %s" % ["PASS" if ok else "FAIL", description])


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var files_ok: bool = true
	for file: String in FILES:
		files_ok = files_ok and ResourceLoader.exists(ModelDir + file + ".glb")
	var manifest: Variant = JSON.parse_string(FileAccess.get_file_as_string(ModelDir + "asset_manifest.json"))
	check(files_ok and manifest is Array and (manifest as Array).size() == 5, "#L0 five GLBs and an asset_manifest.json with five entries")
	var scene := load(ScenePath) as PackedScene
	var circuit := scene.instantiate() as Node3D
	root.add_child(circuit)
	await process_frame
	var ribbon = circuit.get("ribbon")
	var env = circuit.get_node("Environment")
	var layer := env.get_node_or_null("HeroLandmarks")
	check(layer != null, "#L1 the environment has a HeroLandmarks layer")
	if layer == null:
		circuit.queue_free()
		_finish()
		return
	var heroes: Dictionary = {}
	for node_name: String in NODES:
		var node := layer.get_node_or_null(node_name) as Node3D
		heroes[node_name] = node
		check(node != null, "#L2 %s stands in the layer" % node_name)
	if heroes.values().has(null):
		circuit.queue_free()
		_finish()
		return

	# Placement: blueprint stations; offset_m is the near edge, so the centre is offset + depth / 2.
	var casino: Node3D = heroes["CasinoPalace"]
	var hotel: Node3D = heroes["GrandHotelFairmont"]
	var tunnel: Node3D = heroes["CliffTunnel"]
	var yachts: Node3D = heroes["YachtPack"]
	var bridge: Node3D = heroes["HarborSkybridge"]
	check(absf(float(casino.get_meta("arc_s")) - 980.0) <= 3.0 and absf(float(casino.get_meta("lateral_m")) - 120.0) <= 1.0, "#L3 the casino stands at s=980, 90 m off the road on the right (centre 120 m)")
	check(absf(float(hotel.get_meta("arc_s")) - 1010.0) <= 3.0 and absf(float(hotel.get_meta("lateral_m")) + 47.5) <= 1.0, "#L3 the hotel stands at s=1010, 20 m off the road on the left (centre 47.5 m)")
	check(absf(float(tunnel.get_meta("arc_s")) - 1330.0) <= 3.0 and absf(float(tunnel.get_meta("lateral_m"))) <= 0.1, "#L4 the tunnel is centred on the road at s=1330 (the middle of its straight)")
	check(absf(float(bridge.get_meta("arc_s")) - 2180.0) <= 3.0 and absf(float(bridge.get_meta("lateral_m"))) <= 0.1, "#L5 the skybridge is centred on the road at s=2180")
	check(float(yachts.get_meta("lateral_m")) < -50.0 and absf(float(yachts.get_meta("arc_s")) - 2050.0) <= 30.0, "#L6 the yachts are moored off the left quay around s=2050")

	# The tunnel fits its straight and carries the road.
	var tunnel_length: float = float(tunnel.get_meta("length_m"))
	var mouth_in: float = float(tunnel.get_meta("arc_s")) - tunnel_length * 0.5
	var mouth_out: float = float(tunnel.get_meta("arc_s")) + tunnel_length * 0.5
	check(tunnel_length <= 150.5 and mouth_in >= STRAIGHT_S0 + 6.0 and mouth_out <= STRAIGHT_S1 - 6.0, "#L7 the %.0f m tunnel (s %.0f..%.0f) stands inside the straight s %.0f..%.0f with 6 m to spare" % [tunnel_length, mouth_in, mouth_out, STRAIGHT_S0, STRAIGHT_S1])

	var body := StaticBody3D.new()
	root.add_child(body)
	var shapes: Dictionary = {}
	for node_name: String in NODES:
		var node: Node3D = heroes[node_name]
		for child: Node in node.find_children("*", "MeshInstance3D", true, false):
			var instance := child as MeshInstance3D
			var shape := CollisionShape3D.new()
			shape.shape = instance.mesh.create_trimesh_shape()
			shape.transform = instance.global_transform
			shape.set_meta(&"hero", node_name)
			body.add_child(shape)
	await physics_frame
	var space := root.world_3d.direct_space_state

	var tunnel_hits: int = 0
	var s: float = mouth_in + 4.0
	while s <= mouth_out - 4.0:
		for lateral: float in [-5.5, -2.75, 0.0, 2.75, 5.5]:
			var point: Vector3 = ribbon.get_point_at_offset(s, lateral).origin
			var query := PhysicsRayQueryParameters3D.create(point + Vector3.UP * 0.25, point + Vector3.UP * 5.0)
			tunnel_hits += 0 if space.intersect_ray(query).is_empty() else 1
		s += 3.0
	check(tunnel_hits == 0, "#L8 the bore is clear: 11 m of road, 5 m of headroom along the tunnel (%d hits)" % tunnel_hits)
	var roof_hits: int = 0
	for lateral: float in [-4.0, 0.0, 4.0]:
		var point: Vector3 = ribbon.get_point_at_offset(float(tunnel.get_meta("arc_s")), lateral).origin
		var query := PhysicsRayQueryParameters3D.create(point + Vector3.UP * 5.0, point + Vector3.UP * 30.0)
		roof_hits += 0 if space.intersect_ray(query).is_empty() else 1
	check(roof_hits == 3, "#L9 a roof closes the bore: the mid-tunnel road is covered at all three probe lines (%d of 3)" % roof_hits)

	# The bore is lit: two rows of lamp strips under the roof, every 9 m, inside the 7.4 m bore and above the 5 m headroom.
	var lamps: Array[Transform3D] = env.tunnel_lamp_poses
	var lamps_ok: bool = lamps.size() >= 30
	for pose: Transform3D in lamps:
		var along: float = ribbon.curve.get_closest_offset(ribbon.to_local(pose.origin))
		var local: Vector3 = ribbon.get_point_at_offset(along, 0.0).affine_inverse() * pose.origin
		lamps_ok = lamps_ok and along >= mouth_in and along <= mouth_out and absf(local.x) <= 5.0 and local.y > 5.0 and local.y < 7.4
	check(lamps_ok, "#L8b the bore carries >= 30 lamp strips under its roof (got %d)" % lamps.size())

	# The skybridge: nothing under 6 m over the road, a deck above it, pylons outside the barrier.
	var bridge_s: float = float(bridge.get_meta("arc_s"))
	var under_hits: int = 0
	var deck_hits: int = 0
	for along: float in range(-10, 11, 2):
		for lateral: float in [-5.5, -2.75, 0.0, 2.75, 5.5]:
			var point: Vector3 = ribbon.get_point_at_offset(bridge_s + along, lateral).origin
			var low := PhysicsRayQueryParameters3D.create(point + Vector3.UP * 0.25, point + Vector3.UP * 6.0)
			under_hits += 0 if space.intersect_ray(low).is_empty() else 1
			var high := PhysicsRayQueryParameters3D.create(point + Vector3.UP * 6.0, point + Vector3.UP * 14.0)
			deck_hits += 0 if space.intersect_ray(high).is_empty() else 1
	check(under_hits == 0, "#L10 the road has 6 m of clearance under the skybridge (%d hits)" % under_hits)
	check(deck_hits > 0, "#L11 the skybridge deck spans the road (%d probes hit it)" % deck_hits)
	var bridge_frame: Transform3D = ribbon.get_point_at_offset(bridge_s, 0.0)
	var inner_feet: int = 0
	for child: Node in bridge.find_children("*", "MeshInstance3D", true, false):
		var instance := child as MeshInstance3D
		for vertex: Vector3 in instance.mesh.get_faces():
			var local: Vector3 = bridge_frame.affine_inverse() * (instance.global_transform * vertex)
			if local.y < 5.9 and absf(local.x) < 9.0:
				inner_feet += 1
	check(inner_feet == 0, "#L12 no part of the skybridge below 6 m stands within 9 m of the racing line (%d vertices)" % inner_feet)

	# The others keep clear of every road, whichever leg is near.
	var near_road: float = INF
	for node_name: String in ["CasinoPalace", "GrandHotelFairmont", "YachtPack"]:
		var node: Node3D = heroes[node_name]
		var bounds: AABB = _global_bounds(node)
		for corner: int in range(8):
			var p: Vector3 = bounds.get_endpoint(corner)
			var index: int = env.terrain.nearest_station(p.x, p.z)
			near_road = minf(near_road, Vector2(p.x - env.terrain.station_pos[index].x, p.z - env.terrain.station_pos[index].z).length())
	check(near_road >= 10.5, "#L13 casino, hotel and yachts keep 10.5 m from every road (nearest corner %.1f m)" % near_road)

	# On the ground: the base of every mesh part, at its real (rotated) footprint corners.
	var floating: float = -INF
	var buried: float = -INF
	for node_name: String in ["CasinoPalace", "GrandHotelFairmont"]:
		var node: Node3D = heroes[node_name]
		var base_y: float = _global_bounds(node).position.y
		for corner: Vector3 in _footprint_corners(node):
			var ground: float = env.ground_y_at(corner)
			floating = maxf(floating, base_y - ground)
			buried = maxf(buried, ground - base_y)
	check(floating <= 0.05 and buried <= 3.0, "#L14 the casino and the hotel never float: at every footprint corner the base is at or under the ground and at most 3 m into it (floating %.2f m, buried %.2f m)" % [floating, buried])
	var yacht_bounds: AABB = _global_bounds(yachts)
	check(yacht_bounds.position.y < 0.0 and yacht_bounds.position.y > -1.5, "#L15 the yacht hulls sit in the water, 0..1.5 m below the surface (lowest %.2f m)" % yacht_bounds.position.y)

	# Toon look: every surface is a cel shader with an ink outline pass.
	var plain: int = 0
	var surfaces: int = 0
	for node_name: String in NODES:
		var node: Node3D = heroes[node_name]
		for child: Node in node.find_children("*", "MeshInstance3D", true, false):
			var instance := child as MeshInstance3D
			for surface: int in range(instance.mesh.get_surface_count()):
				surfaces += 1
				var material: Material = instance.get_active_material(surface)
				plain += 0 if material is ShaderMaterial and material.next_pass != null else 1
	check(surfaces >= 20 and plain == 0, "#L16 all %d landmark surfaces are cel-shaded with an ink outline (%d without)" % [surfaces, plain])

	body.queue_free()
	circuit.queue_free()
	await process_frame
	_finish()


## The four bottom corners of every mesh part's own (rotated) bounding box.
func _footprint_corners(node: Node3D) -> Array[Vector3]:
	var corners: Array[Vector3] = []
	for child: Node in node.find_children("*", "MeshInstance3D", true, false):
		var instance := child as MeshInstance3D
		var box: AABB = instance.mesh.get_aabb()
		for x: float in [box.position.x, box.end.x]:
			for z: float in [box.position.z, box.end.z]:
				corners.append(instance.global_transform * Vector3(x, box.position.y, z))
	return corners


func _global_bounds(node: Node3D) -> AABB:
	var merged := AABB()
	var first: bool = true
	for child: Node in node.find_children("*", "MeshInstance3D", true, false):
		var instance := child as MeshInstance3D
		var box: AABB = instance.global_transform * instance.mesh.get_aabb()
		merged = box if first else merged.merge(box)
		first = false
	return merged


func _finish() -> void:
	print("MONTE AZURE LANDMARKS TEST SUITE: %s" % ("PASS" if failures == 0 else "%d FAILURES" % failures))
	quit(0 if failures == 0 else 1)
