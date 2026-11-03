extends SceneTree

const SCENE := "res://scenes/race_world/circuits/eifel_forest/eifel_forest_circuit.tscn"
const Registry := preload("res://scripts/core/circuit_calendar_registry.gd")
const Weather := preload("res://scripts/gt/gt_weather.gd")
var failures: int = 0


func check(ok: bool, description: String) -> void:
	print("[%s] %s" % ["PASS" if ok else "FAIL", description])
	if not ok:
		failures += 1


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	check(ResourceLoader.exists(SCENE), "Eifel Forest production scene exists")
	if not ResourceLoader.exists(SCENE):
		quit(1)
		return
	var circuit = (load(SCENE) as PackedScene).instantiate()
	root.add_child(circuit)
	await process_frame
	var ribbon: TrackRibbon = circuit.get_node("TrackRibbon")
	var pit = circuit.get_node("PitLane")
	var env = circuit.get_node("Environment")
	check(absf(ribbon.length_m - 5150.73) < 50.0 and is_equal_approx(ribbon.road_half_width_m, 6.5), "Homologated 5.150 m, 13 m GP road (baked %.3f m)" % ribbon.length_m)
	check(circuit.turns.size() == 16 and circuit.turns[0].name == "T01 Castrol-S" and circuit.turns[15].name == "T16 Coca-Cola 2", "All 16 named turns exposed")
	check(Registry.get_circuit("eifel_forest").scene_path == SCENE, "Calendar round 8 loads the production module")
	var preview := load(Registry.get_circuit("eifel_forest").preview_image_path) as Texture2D
	check(preview != null and preview.get_size() == Vector2(640, 360), "Race setup loads the optimized 640x360 Eifel poster")
	var layout: Dictionary = pit.sim_layout()
	check(layout.stall_pitch_m == 14.0 and layout.queue_gap_m == 8.0, "Production pit keeps the approved 14 m pitch and 8 m queue gap")
	check(is_equal_approx(float(layout.fast_lane_m), 10.8) and is_equal_approx(float(layout.stall_lane_m), 16.5), "Fast lane centre 10.8 m and boxes 16.5 m")
	check(absf(float(layout.stall_first_s) - (ribbon.length_m + 57.0)) < 0.01, "First box unwrapped at the approved s = 57")
	var service_s := fposmod(float(layout.stall_first_s) + 5.0 * float(layout.stall_pitch_m), ribbon.length_m)
	check(absf(service_s - 127.0) < 0.01, "Service bay 5 stands at s = 127 (%.3f)" % service_s)
	check(pit.stalls.size() == 10 and pit.garages.size() == 10, "Ten boxes and garage sockets")
	check(env.built and env.flag_panels != null and env.flag_panels.count == 8, "Environment and eight FIA flag panels built")
	check(circuit.find_child("RubberGroove", true, false) != null, "Production racing-line rubber groove exists")
	check(circuit.find_child("PitAsphalt", true, false) != null and circuit.find_child("PitApron", true, false) != null, "Pit asphalt and working apron exist")
	check(env.kerbs.size() >= 7, "Kerbs cover the sharp corners in at least seven runs (%d)" % env.kerbs.size())
	var placed: int = int(env.stats().get("landmarks_placed", 0))
	check(placed == 4, "All four approved hero landmarks placed (%d)" % placed)
	check(int(env.stats().get("tree_count", 0)) == 1800, "1800 Eifel pines and spruces")
	check(int(env.stats().get("grass_count", 0)) >= 700 and int(env.stats().get("boulder_count", 0)) == 320, "Meadow tufts and basalt boulders scattered")
	var triangles: int = int(env.stats().triangles)
	# The approved Route 2 total is 423.450 tris; production includes the corridor kit in this measure.
	check(triangles > 0 and triangles <= 430000, "Static environment fits the approved 423k class (%d)" % triangles)
	var pending := circuit.find_children("Pending_*", "", true, false)
	check(pending.is_empty(), "No Pending_* proxy nodes in the production scene")
	var buried: int = 0
	var floating: int = 0
	for station: int in range(0, int(ribbon.length_m), 6):
		for lateral: float in [-6.5, 0.0, 6.5]:
			var p := ribbon.get_point_at_offset(float(station), lateral).origin
			var bed: float = env.ground_y_at(p)
			if bed > p.y + 0.02:
				buried += 1
			if bed < p.y - 0.4:
				floating += 1
	check(buried == 0 and floating == 0, "Rendered terrain supports full asphalt every 6 m (%d buried, %d floating)" % [buried, floating])
	var pit_buried: int = 0
	var pit_floating: int = 0
	for u: int in range(-65, 485, 6):
		var outer: float = pit._outer_edge(float(u))
		for lateral: float in [6.9, (6.9 + outer) * 0.5, outer]:
			var p: Vector3 = pit.get_pit_transform(float(u), lateral).origin + Vector3.UP * 0.015
			var bed: float = env.ground_y_at(p)
			pit_buried += 1 if bed > p.y + 0.02 else 0
			pit_floating += 1 if bed < p.y - 0.4 else 0
	check(pit_buried == 0 and pit_floating == 0, "Rendered terrain supports the pit and working apron (%d buried, %d floating)" % [pit_buried, pit_floating])
	for mode: int in [Weather.TimeOfDay.DAY, Weather.TimeOfDay.SUNSET, Weather.TimeOfDay.NIGHT, Weather.TimeOfDay.DAY]:
		env.apply_time_of_day(Weather.compute_time_of_day(mode, 0.0), 0.0)
	env.apply_time_of_day(Weather.compute_time_of_day(Weather.TimeOfDay.DAY, 0.0), 0.6)
	env.apply_wind(0.016, 24.0, 1.0)
	check(env.built and int(env.stats().draw_calls) > 0, "Environment survives DAY/SUNSET/NIGHT, gloom and wind")
	check(is_finite(env.ground_y_at(Vector3(3.0, 7.0, -4.0))), "ground_y_at answers with a number")
	circuit.free()
	await process_frame
	print("EIFEL FOREST: %s (%d failure(s))" % ["PASS" if failures == 0 else "FAIL", failures])
	quit(1 if failures else 0)
