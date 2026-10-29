extends SceneTree

const Pit := preload("res://scripts/world/paddock/pit_building.gd")
const Stand := preload("res://scripts/world/paddock/main_grandstand.gd")
const Tower := preload("res://scripts/world/paddock/race_control_tower.gd")
const Circuit := preload("res://scenes/race_world/circuits/neo_wangan/neo_wangan_circuit.tscn")
var failures: int = 0

func check(ok: bool, label: String) -> void:
	print("[%s] %s" % ["PASS" if ok else "FAIL", label])
	if not ok:
		failures += 1

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var pit := Pit.new()
	var stand := Stand.new()
	var tower := Tower.new()
	check(pit.get("building_length_m") == Pit.LENGTH_M and pit.get("bay_stride_m") == 14.0, "Apex pit defaults preserved")
	check(stand.get("stand_length_m") == Stand.LENGTH_M, "Apex grandstand default preserved")
	check(tower.get("accent_color") == Color("#ffd400"), "Apex tower accent preserved")
	var defaults: Array[Node3D] = [pit, stand, tower]
	var hashes: Array[String] = ["3cc81bbf459b66856010f98c0043f4a902988a52acf2e8c193d40e09c74ace3e", "55c7660612630520a7e7c705c76cd792c3d995945bdf182ad12023d3438ab759", "0998c81f7c49faf7227e3586d7bbc2c9801570075177ec49240aeb2a046c810e"]
	for index: int in range(defaults.size()):
		defaults[index].build()
		var context := HashingContext.new()
		context.start(HashingContext.HASH_SHA256)
		for node: Node in defaults[index].find_children("*", "MeshInstance3D", true, false):
			for surface: int in range(node.mesh.get_surface_count()):
				context.update(var_to_bytes(node.mesh.surface_get_arrays(surface)))
		check(context.finish().hex_encode() == hashes[index], "Apex kit %d mesh arrays match pre-phase geometry byte for byte" % index)
	pit.free()
	stand.free()
	tower.free()
	var circuit: Node3D = Circuit.instantiate()
	root.add_child(circuit)
	var lane: Node3D = circuit.get_node("PitLane")
	var building: Node3D = lane.get_node_or_null("PitBuilding")
	var grandstand: Node3D = lane.get_node_or_null("MainGrandstand")
	check(building != null and building.get("floor_count") == 2 and building.get("building_length_m") == 124.0 and building.get("bay_count") == 10 and building.get("bay_stride_m") == 12.0, "Neo-Wangan reuses 124 m two-storey pit kit with ten 12 m bays")
	check(grandstand != null and grandstand.get("stand_length_m") == 140.0 and grandstand.has_node("Jumbotron") and grandstand.has_node("Crowd"), "Neo-Wangan shared grandstand has live screen and instanced crowd")
	check(lane.has_node("RaceControlTower") and lane.has_node("CatchFence"), "Neo-Wangan shared tower and catch fence integrated")
	check(lane.has_node("GarageEquipment") and lane.garages.size() == 10, "Ten usable garages retain crew sockets and shared equipment")
	circuit.queue_free()
	await process_frame
	print("SHARED PADDOCK KIT: %d failure(s)" % failures)
	quit(0 if failures == 0 else 1)
