extends SceneTree

const SCENE := "res://scenes/race_world/circuits/pacific_corkscrew/pacific_corkscrew_circuit.tscn"
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
	check(ResourceLoader.exists(SCENE), "Pacific Corkscrew production scene exists")
	if not ResourceLoader.exists(SCENE):
		quit(1)
		return
	var circuit := (load(SCENE) as PackedScene).instantiate() as Node3D
	root.add_child(circuit)
	await process_frame
	var ribbon: TrackRibbon = circuit.get_node("TrackRibbon")
	var pit: CircuitPitComplex = circuit.get_node("PitLane")
	var env: CircuitEnvironment = circuit.get_node("Environment")
	check(absf(ribbon.length_m - 4100.0) < 50.0 and is_equal_approx(ribbon.road_half_width_m, 6.5), "Homologated 4.100 m, 13 m GP road (baked %.3f m)" % ribbon.length_m)
	check(circuit.turns.size() == 11, "All 11 named turns exposed")
	check(Registry.get_circuit("pacific_corkscrew").scene_path == SCENE, "Calendar round 7 loads the production module")
	check(Registry.get_circuit("pacific_corkscrew").turns_count == 11 and Registry.get_circuit("pacific_corkscrew").length_km == 4.1, "Calendar identity stays 4.10 km / 11 turns")
	var preview := load(Registry.get_circuit("pacific_corkscrew").preview_image_path) as Texture2D
	check(preview != null and preview.get_width() == 1920, "Race setup loads the native 1920px Pacific preview image")
	var layout: Dictionary = pit.sim_layout()
	check(layout.stall_pitch_m == 20.0 and layout.queue_gap_m == 8.0, "Production pit uses the Fase 0 20 m pitch and 8 m queue gap")
	check(layout.stall_lane_m > layout.fast_lane_m and layout.fast_lane_m > 6.5, "Service boxes stand beyond the fast lane and racing road")
	check(absf(float(layout.stall_first_s) - (ribbon.length_m + 30.0)) < 0.01, "First box unwrapped at the approved s = 30")
	check(pit.stalls.size() == 10 and pit.garages.size() == 10, "Ten boxes and garage sockets")
	var service_s := fposmod(float(layout.stall_first_s) + 5.0 * float(layout.stall_pitch_m), ribbon.length_m)
	check(absf(service_s - 130.0) < 0.01, "Service bay 5 stands at s = 130 (%.3f)" % service_s)
	check(env.built and env.flag_panels != null and env.flag_panels.count == 8, "Environment and eight FIA flag panels built")
	check(circuit.find_child("RubberGroove", true, false) != null, "Production racing-line rubber groove exists")
	check(env.kerbs.size() >= 4, "Kerbs cover every sharp corner in at least four runs (%d)" % env.kerbs.size())
	check(circuit.find_child("SawtoothKerbsPacific", true, false) != null and circuit.find_child("SawtoothKerbsClassic", true, false) != null,
		"Blue-white Pacific Ridge kerbs and red-white kerbs both present")
	var biome: Node = env.get_node("Biome")
	var bio_stats: Dictionary = biome.get("stats")
	check(int(bio_stats.get("landmarks_placed", 0)) == 3, "All three approved hero landmarks placed")
	check(int(bio_stats.get("tree_count", 0)) == 1500, "1500 Coast Live Oaks")
	check(int(bio_stats.get("grass_count", 0)) >= 600 and int(bio_stats.get("shrub_count", 0)) >= 600, "Dry grass and chaparral scrub scattered")
	var triangles: int = int(env.stats().triangles)
	check(triangles <= 320000, "Static environment fits 320k triangles (%d)" % triangles)
	var raw_total: int = _raw_triangles(circuit)
	check(raw_total <= 370000, "Complete static circuit stays in the approved 359.684k class (%d raw triangles)" % raw_total)
	var buried: int = 0
	var floating: int = 0
	for station: int in range(0, 4100, 6):
		for lateral: float in [-6.5, 0.0, 6.5]:
			var p := ribbon.get_point_at_offset(float(station), lateral).origin
			var bed := env.ground_y_at(p)
			if bed > p.y + 0.02:
				buried += 1
			if bed < p.y - 0.4:
				floating += 1
				print("Terrain gap s=%d lateral=%.1f road=%.3f bed=%.3f" % [station, lateral, p.y, bed])
	check(buried == 0 and floating == 0, "Rendered terrain supports full asphalt every 6 m (%d buried, %d floating)" % [buried, floating])
	var pit_buried: int = 0
	var pit_floating: int = 0
	for u: int in range(-65, 485, 6):
		var outer: float = pit._outer_edge(float(u))
		for lateral: float in [6.9, (6.9 + outer) * 0.5, outer]:
			var p: Vector3 = pit.get_pit_transform(float(u), lateral).origin + Vector3.UP * 0.015
			var bed := env.ground_y_at(p)
			pit_buried += 1 if bed > p.y + 0.02 else 0
			pit_floating += 1 if bed < p.y - 0.4 else 0
	check(pit_buried == 0 and pit_floating == 0, "Rendered terrain supports pit and full working apron (%d buried, %d floating)" % [pit_buried, pit_floating])
	# DAY / SUNSET / NIGHT run on the shared sky and leave the set measurable.
	for mode: int in [Weather.TimeOfDay.DAY, Weather.TimeOfDay.SUNSET, Weather.TimeOfDay.NIGHT, Weather.TimeOfDay.DAY]:
		env.apply_time_of_day(Weather.compute_time_of_day(mode, 0.0), 0.0)
	env.apply_wind(0.016, 24.0, 1.0)
	check(int(env.stats()["draw_calls"]) > 0 and int(env.stats()["triangles"]) > 0, "Environment measures after mood, gloom and wind changes")
	circuit.free()
	await process_frame
	quit(1 if failures else 0)


func _raw_triangles(root: Node) -> int:
	var total := 0
	if root is MeshInstance3D and (root as MeshInstance3D).mesh != null:
		total += _mesh_triangles((root as MeshInstance3D).mesh)
	elif root is MultiMeshInstance3D and (root as MultiMeshInstance3D).multimesh != null:
		var mm := (root as MultiMeshInstance3D).multimesh
		total += _mesh_triangles(mm.mesh) * mm.instance_count
	for child: Node in root.get_children():
		total += _raw_triangles(child)
	return total


func _mesh_triangles(mesh: Mesh) -> int:
	var total := 0
	for surface in mesh.get_surface_count():
		var arrays := mesh.surface_get_arrays(surface)
		var indices: Variant = arrays[Mesh.ARRAY_INDEX]
		total += (indices.size() if indices != null else (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()) / 3
	return total
