extends SceneTree

const Zone := preload("res://scripts/world/shared/pit_zone.gd")
const Furniture := preload("res://scripts/world/shared/trackside_furniture_builder.gd")
const Director := preload("res://scripts/world/weekend/broadcast_camera_director.gd")
const World := preload("res://scripts/world/weekend/race_weekend_world.gd")
var failures: int = 0

func check(ok: bool, description: String) -> void:
	print("[%s] %s" % ["PASS" if ok else "FAIL", description])
	if not ok:
		failures += 1

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var scene: PackedScene = load("res://scenes/race_world/circuits/brianza/brianza_circuit.tscn")
	var circuit: Node = scene.instantiate()
	root.add_child(circuit)
	await process_frame
	var furniture: Node = circuit.get_node("Environment/TracksideFurniture")
	var clear: bool = not furniture.has_armco_at(1.0, 5600.0) and not furniture.has_armco_at(1.0, 100.0)
	var restored: bool = furniture.has_armco_at(1.0, 3900.0) and furniture.has_armco_at(1.0, 300.0)
	check(clear and restored, "Brianza armco follows its pit lane across the start line")
	var lap: float = circuit.ribbon.length_m
	var zone: Dictionary = Zone.from_layout({"entry_s": 5530.0, "exit_s": 150.0, "lane_length_m": 410.0}, lap)
	check(is_equal_approx(zone.start_s, 5510.0) and is_equal_approx(zone.length_m, 470.0), "pit layout defines zone and margins")
	check(Zone.contains(zone, 5600.0, lap) and Zone.contains(zone, 100.0, lap) and not Zone.contains(zone, 300.0, lap), "wrapped zone contains both sides of start line")
	var ranges: Array[Vector2] = Zone.outside_ranges(zone, lap)
	check(ranges.size() == 1 and is_equal_approx(ranges[0].y, 5510.0), "wrapped zone has one outside range")
	check(Zone.outside_ranges({}, lap) == [Vector2(0.0, lap)] and not Zone.contains({}, 5.0, lap), "empty zone leaves whole lap open")
	check(Zone.outside_ranges({"start_s": 0.0, "length_m": lap}, lap).is_empty(), "full-lap zone leaves no outside range")
	var shifted := Furniture.new()
	circuit.add_child(shifted)
	shifted.build(circuit.ribbon, circuit.get_node("Environment").line, [], [], [], {"start_s": 1000.0, "length_m": 470.0})
	check(shifted.has_armco_at(1.0, 3900.0) and not shifted.has_armco_at(1.0, 1100.0), "moving the zone moves the guardrail gap")
	var camera := Camera3D.new()
	var director := Director.new()
	circuit.add_child(camera)
	circuit.add_child(director)
	var camera_zone: Dictionary = Zone.from_layout(circuit.get_node("PitLane").sim_layout(), lap, 30.0, 30.0)
	director.setup(camera, circuit.ribbon, camera_zone)
	var stations_clear: bool = true
	for s: float in director.tv_station_s:
		stations_clear = stations_clear and not Zone.contains(camera_zone, s, lap)
	check(stations_clear, "TV stations avoid the circuit pit zone")
	var apex: Dictionary = Zone.from_layout({"entry_s": 3900.0, "exit_s": 150.0, "lane_length_m": 410.0}, 4158.75)
	check(is_equal_approx(apex.start_s, 3880.0) and is_equal_approx(apex.length_m, 470.0), "Apex pit gap preserves its original margins")
	var world := World.new()
	var camera_default: Dictionary = world._camera_pit_zone(4158.75)
	check(is_equal_approx(float(camera_default.get("length_m", 0.0)), 470.0), "Apex camera exclusion preserves nominal lane length")
	world.free()
	for script_name: String in ["trackside_furniture_builder", "broadcast_camera_director", "foliage_scatter", "enhanced_track_geometry"]:
		var source: String = FileAccess.get_file_as_string("res://scripts/world/%s.gd" % script_name)
		var matcher := RegEx.create_from_string("PitLaneScript\\.(ENTRY_S|EXIT_S|NOMINAL_LENGTH_M|STALL_FIRST_S)")
		check(matcher.search(source) == null, "%s does not embed Apex pit constants" % script_name)
	circuit.free()
	quit(1 if failures else 0)
