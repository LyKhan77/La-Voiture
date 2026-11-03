extends SceneTree

const SCENE := "res://scenes/race_world/circuits/stoke_crown/stoke_crown_circuit.tscn"
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
	check(ResourceLoader.exists(SCENE), "Stoke Crown production scene exists")
	if not ResourceLoader.exists(SCENE):
		quit(1)
		return
	var circuit := (load(SCENE) as PackedScene).instantiate() as Node3D
	root.add_child(circuit)
	await process_frame
	var ribbon: TrackRibbon = circuit.get_node("TrackRibbon")
	var pit: CircuitPitComplex = circuit.get_node("PitLane")
	var env: CircuitEnvironment = circuit.get_node("Environment")
	check(absf(ribbon.length_m - 5200.0) < 1.0 and is_equal_approx(ribbon.road_half_width_m, 7.0), "Homologated 5200 m, 14 m GP road")
	check(circuit.turns.size() == 18, "All 18 named turns exposed")
	check(Registry.get_circuit("stoke_crown").scene_path == SCENE, "Calendar round 6 loads production module")
	var preview := load(Registry.get_circuit("stoke_crown").preview_image_path) as Texture2D
	check(preview != null and preview.get_size() == Vector2(640, 360), "Race setup loads the optimized 640x360 Stoke Crown poster")
	var layout: Dictionary = pit.sim_layout()
	check(layout.stall_pitch_m == 20.0 and layout.queue_gap_m == 8.0, "Production pit uses 20 m pitch and 8 m queue gap")
	check(layout.stall_lane_m > layout.fast_lane_m and layout.fast_lane_m > 7.0, "Service boxes stand beyond fast lane and racing road")
	check(pit.stalls.size() == 10 and pit.garages.size() == 10, "Ten boxes and garage sockets")
	check(env.built and env.flag_panels != null and env.flag_panels.count == 8, "Environment and eight FIA flag panels built")
	check(circuit.find_child("RubberGroove", true, false) != null, "Production racing-line rubber groove exists")
	var biome: Node = env.get_node("Biome")
	check(biome.get("stats").get("landmarks_placed", 0) == 5, "All five approved hero landmarks placed")
	check(biome.get("stats").get("tree_count", 0) == 1600 and biome.get("stats").get("grass_count", 0) == 600, "1600 trees and 600 meadow tufts")
	var triangles: int = int(env.stats().triangles)
	check(triangles <= 320000, "Static environment fits 320k triangles (%d)" % triangles)
	env._measure_node(pit)
	env._measure_node(ribbon)
	check(env.triangle_count <= 320000, "Complete static circuit including pit and road fits 320k triangles (%d)" % env.triangle_count)
	var hero_calls: int = 0
	for node: Node in biome.get_node("HeroLandmarks").find_children("*", "MeshInstance3D", true, false):
		hero_calls += (node as MeshInstance3D).mesh.get_surface_count()
	check(hero_calls <= 16, "Four outfield landmarks batch to at most sixteen surfaces (%d)" % hero_calls)
	var night_materials: Array[ShaderMaterial] = []
	for node: Node in biome.get_node("HeroLandmarks").find_children("*", "MeshInstance3D", true, false):
		var instance := node as MeshInstance3D
		for surface: int in range(instance.mesh.get_surface_count()):
			var material := instance.get_active_material(surface) as ShaderMaterial
			if material != null and material.shader.code.contains("uniform float glow_energy"):
				night_materials.append(material)
	env.apply_time_of_day(Weather.compute_time_of_day(Weather.TimeOfDay.NIGHT, 0.0))
	var glowing: bool = night_materials.size() >= 4
	for material: ShaderMaterial in night_materials:
		var energy: Variant = material.get_shader_parameter("glow_energy")
		glowing = glowing and energy != null and float(energy) > 0.0
	check(glowing, "Actual landmark paint/glass materials receive NIGHT glow")
	env.apply_time_of_day(Weather.compute_time_of_day(Weather.TimeOfDay.DAY, 0.0))
	var dark: bool = true
	for material: ShaderMaterial in night_materials:
		var energy: Variant = material.get_shader_parameter("glow_energy")
		dark = dark and energy != null and is_zero_approx(float(energy))
	check(dark, "Actual landmark materials return to DAY without glow")
	var buried: int = 0
	var floating: int = 0
	for station: int in range(0, 5200, 6):
		for lateral: float in [-7.0, 0.0, 7.0]:
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
	circuit.free()
	await process_frame
	quit(1 if failures else 0)
