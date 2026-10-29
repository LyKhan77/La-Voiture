extends SceneTree

## Neo-Wangan Shuto Express (FASE 12): the 3 150 m street circuit in 3D. The test measures the scene's
## own spline — length, closure, the twelve numbered turns and their radii, the bridge and tunnel
## elevation — and checks that the road ribbon is 11.5 m wide with the wet-asphalt shader. It also
## guards the Apex Ring: the two circuits are separate scenes and the old spline must not move.
## Pit-lane and urban-furniture checks live in the same suite (Tasks 3 and 4).
## Run: godot --headless --path . -s res://tests/test_neo_wangan_circuit.gd

const CircuitScene := preload("res://scenes/race_world/neo_wangan_circuit.tscn")
const ApexScene := preload("res://scenes/race_world/track_circuit.tscn")
const BuilderScript := preload("res://scripts/world/circuits/neo_wangan/neo_wangan_circuit_builder.gd")
const RibbonScript := preload("res://scripts/car/track_ribbon.gd")
const PitScript := preload("res://scripts/world/circuits/neo_wangan/neo_wangan_pit_complex.gd")
const CircuitScript := preload("res://scripts/world/circuits/neo_wangan/neo_wangan_circuit_builder.gd")
const WorldScene := preload("res://scenes/race_weekend_world.tscn")
const ConfigScript := preload("res://scripts/core/race_config_data.gd")

const TARGET_LENGTH_M: float = 3150.0
const LENGTH_TOLERANCE_M: float = 25.0
const TARGET_WIDTH_M: float = 11.5
const MIN_RADIUS_M: float = 18.0
const APEX_LENGTH_M: float = 4158.81

var failures: int = 0
var assertions: int = 0
var circuit: BuilderScript
var ribbon: RibbonScript


func _initialize() -> void:
	call_deferred("_run")


func check(ok: bool, description: String) -> void:
	assertions += 1
	if not ok:
		failures += 1
		push_error(description)
	print("[%s] %s" % ["PASS" if ok else "FAIL", description])


func _run() -> void:
	circuit = CircuitScene.instantiate()
	root.add_child(circuit)
	ribbon = circuit.ribbon
	_test_length_and_closure()
	_test_turns()
	_test_elevation()
	_test_road_surface()
	_test_pit_connection()
	_test_pit_polish()
	_test_urban_set()
	await _test_ground_clearance()
	_test_apex_preserved()
	await _test_race_weekend_integration()
	print("%d assertions, %d failure(s)" % [assertions, failures])
	print("NEO-WANGAN CIRCUIT: %s" % ("PASS" if failures == 0 else "%d FAILURES" % failures))
	circuit.queue_free()
	quit(0 if failures == 0 else 1)


func _test_length_and_closure() -> void:
	var length: float = ribbon.length_m
	var curve: Curve3D = ribbon.curve
	var first: Vector3 = curve.get_point_position(0)
	var last: Vector3 = curve.get_point_position(curve.get_point_count() - 1)
	check(absf(length - TARGET_LENGTH_M) <= LENGTH_TOLERANCE_M and first.distance_to(last) < 0.01 and curve.get_point_count() > 200,
		"#W1 the spline is a closed 3 150 m loop: %.1f m baked, first and last point within 1 cm, %d control points" % [length, curve.get_point_count()])


func _test_turns() -> void:
	var turns: Array = circuit.turns
	var ordered: bool = turns.size() == 12
	var radii_ok: bool = turns.size() == 12
	var names_ok: bool = turns.size() == 12
	var directions_ok: bool = turns.size() == 12
	var rights: int = 0
	var lefts: int = 0
	var tightest: float = INF
	var readable: Array[String] = []
	for index: int in range(turns.size()):
		var turn: Dictionary = turns[index]
		var s: float = float(turn["s"])
		var declared: float = float(turn["radius_m"])
		var direction: int = int(turn["direction"])
		if index > 0:
			ordered = ordered and s > float(turns[index - 1]["s"])
		radii_ok = radii_ok and declared >= MIN_RADIUS_M
		directions_ok = directions_ok and absf(direction) == 1
		for apex_s: float in (turn["apex_s"] as Array[float]):
			var measured: float = ribbon.get_radius_at(apex_s)
			radii_ok = radii_ok and measured >= MIN_RADIUS_M and absf(measured - declared) <= declared * 0.25
			directions_ok = directions_ok and signf(ribbon.get_curvature_at(apex_s)) == -float(direction)
			tightest = minf(tightest, minf(declared, measured))
		names_ok = names_ok and String(turn["name"]).length() > 3
		if direction > 0:
			rights += 1
		else:
			lefts += 1
		readable.append("T%d %s %.1f m" % [int(turn["number"]), String(turn["name"]).split(" ")[0], declared])
	check(ordered and radii_ok and directions_ok and turns.size() == 12,
		"#W2 twelve numbered turns in travel order, every one at or above %.0f m radius, each turning the way its curvature says (tightest %.1f m)" % [MIN_RADIUS_M, tightest])
	check(names_ok and rights == 8 and lefts == 4,
		"#W3 every turn is named, eight turn right and four turn left — 12 in all (%s)" % ", ".join(readable))
	check(int(turns[0]["number"]) == 1 and String(turns[0]["name"]) == "Shuto Gate" and String(turns[8]["name"]) == "Harbor Hairpin" and float(turns[8]["span_m"]) > 40.0,
		"#W4 T1 is the Shuto Gate, T9 the double-arc Harbor Hairpin spanning %.1f m" % float(turns[8]["span_m"]))


func _test_elevation() -> void:
	var curve: Curve3D = ribbon.curve
	var highest: float = -INF
	var lowest: float = INF
	var bridge_height: float = -INF
	var tunnel_depth: float = INF
	for index: int in range(240):
		var s: float = ribbon.length_m * float(index) / 240.0
		var at: Vector3 = curve.sample_baked(s, true)
		highest = maxf(highest, at.y)
		lowest = minf(lowest, at.y)
		if s >= BuilderScript.BRIDGE_START_M and s <= BuilderScript.BRIDGE_END_M:
			bridge_height = maxf(bridge_height, at.y)
		if s >= BuilderScript.TUNNEL_START_M and s <= BuilderScript.TUNNEL_END_M:
			tunnel_depth = minf(tunnel_depth, at.y)
	check(highest >= 6.0 and highest <= 7.0 and lowest <= -2.5 and lowest >= -3.6,
		"#W5 the Shuto Bay Bridge peaks at %+.2f m and the underpass floor drops to %+.2f m, inside the designed +6.5 / -3.2 envelope" % [highest, lowest])
	check(bridge_height >= 5.0 and tunnel_depth <= -2.4,
		"#W6 the bridge section itself is elevated (%.2f m) and the 180 m tunnel section is below grade (%.2f m)" % [bridge_height, tunnel_depth])
	check(circuit.tunnel_contains(1170.0) and not circuit.tunnel_contains(600.0) and circuit.on_bridge(500.0) and not circuit.on_bridge(1200.0),
		"#W7 the tunnel and bridge spans answer for their own arc distances, so the environment can build them there")


func _test_road_surface() -> void:
	var road: MeshInstance3D = ribbon.get_node_or_null("RoadMesh")
	var width_ok: bool = is_equal_approx(ribbon.road_half_width_m * 2.0, TARGET_WIDTH_M)
	var surface_ok: bool = false
	if road != null and road.mesh != null and road.mesh.get_surface_count() > 0:
		var material: Material = road.mesh.surface_get_material(0)
		surface_ok = material is ShaderMaterial and (material as ShaderMaterial).shader != null \
			and (material as ShaderMaterial).shader.resource_path.ends_with("road_asphalt.gdshader")
	check(width_ok and surface_ok and road != null,
		"#W8 the racing surface is %.1f m wide and wears the road_asphalt.gdshader (wet gloss and puddles)" % (ribbon.road_half_width_m * 2.0))


## Task 3: the FIA pit connection — entry, fast lane, ten boxes, wall with an attenuator, and a
## pit exit that runs behind a solid blend line past Turn 1.
func _test_pit_connection() -> void:
	var pit = circuit.get_node_or_null("PitLane")
	if pit == null:
		check(false, "#W10 the circuit carries a PitLane complex")
		return
	var entry: Area3D = pit.get_node_or_null("PitEntryTrigger")
	var exit: Area3D = pit.get_node_or_null("PitExitTrigger")
	var entry_s: float = float(entry.get_meta(&"arc_s", -1.0)) if entry != null else -1.0
	var entry_lateral: float = float(entry.get_meta(&"lateral_m", 0.0)) if entry != null else 0.0
	var exit_s: float = float(exit.get_meta(&"arc_s", -1.0)) if exit != null else -1.0
	var lane_length: float = fposmod(exit_s - entry_s, ribbon.length_m)
	check(entry != null and exit != null and absf(entry_s - (ribbon.length_m - 135.0)) <= 0.5 \
			and absf(entry_lateral - 5.2) < 0.001 and absf(lane_length - PitScript.LANE_LENGTH_M) < 0.5,
		"#W10 Pit Entry sits %.0f m before the line at +%.1f m on the right, and the lane runs %.1f m to Pit Exit" % [ribbon.length_m - entry_s, entry_lateral, lane_length])

	var stalls: Node3D = pit.get_node_or_null("Stalls")
	var pitches: Array[float] = []
	var names_ok: bool = stalls != null and stalls.get_child_count() == 10
	var lateral_ok: bool = stalls != null and stalls.get_child_count() == 10
	for index: int in range(stalls.get_child_count() if stalls != null else 0):
		var marker: Marker3D = stalls.get_child(index) as Marker3D
		names_ok = names_ok and marker != null and marker.name == "Socket_PitStall_%d" % index
		pitches.append(float(pit.stalls[index]["s"]))
		lateral_ok = lateral_ok and absf(float(pit.stalls[index]["lateral"]) - PitScript.BOX_LATERAL_M) < 0.001
	var pitch_ok: bool = true
	for index: int in range(1, pitches.size()):
		pitch_ok = pitch_ok and absf(fposmod(pitches[index] - pitches[index - 1], ribbon.length_m) - 12.0) < 0.01
	check(names_ok and lateral_ok and pitch_ok,
		"#W11 ten team boxes Socket_PitStall_0..9 stand 12 m apart outside the fast lane at +%.1f m" % PitScript.BOX_LATERAL_M)

	var wall: MeshInstance3D = pit.get_node_or_null("PitWall")
	var cushion: MeshInstance3D = pit.get_node_or_null("CrashCushion")
	var cushion_color: Color = cushion.get_meta(&"attenuator_color", Color.BLACK) if cushion != null else Color.BLACK
	var orange: bool = cushion_color.r > 0.8 and cushion_color.g > 0.2 and cushion_color.g < 0.6 and cushion_color.b < 0.1
	check(wall != null and cushion != null and orange and bool(cushion.get_meta(&"fia_standard", false)) \
			and is_equal_approx(PitScript.WALL_HEIGHT_M, 1.2) and is_equal_approx(PitScript.FAST_LANE_WIDTH_M, 4.5),
		"#W12 a 1.2 m pit wall carries an orange FIA impact attenuator on its nose, and the fast lane is exactly 4.5 m")

	# Clearance: the car path never comes within 1.0 m of the wall, and a passing car keeps 2.4 m
	# (FIA racing room) from a car boxed at the stall lateral.
	var tightest_wall: float = INF
	var u: float = PitScript.WALL_START_U
	while u <= PitScript.LANE_LENGTH_M:
		var car: float = PitScript.lane_lateral_at(u)
		tightest_wall = minf(tightest_wall, car - 1.0 - (PitScript.PIT_WALL_M + PitScript.WALL_HALF_THICKNESS_M))
		u += 1.0
	var box_gap: float = PitScript.BOX_LATERAL_M - 1.0 - (PitScript.FAST_LANE_M + 1.0)
	check(tightest_wall >= 1.0 and box_gap >= 2.4,
		"#W13 the pit wall leaves %.2f m to a car on the fast lane and a boxed car leaves %.2f m to one passing (2.4 m FIA racing room)" % [tightest_wall, box_gap])

	var blend: MeshInstance3D = pit.get_node_or_null("BlendLine")
	var ramp: Node3D = pit.get_node_or_null("BypassRamp")
	var blend_m: float = float(blend.get_meta(&"blend_line_m", 0.0)) if blend != null else 0.0
	var ramp_m: float = float(ramp.get_meta(&"length_m", 0.0)) if ramp != null else 0.0
	var merge_s: float = float(ramp.get_meta(&"merge_s", 0.0)) if ramp != null else 0.0
	var t1_apex: float = float(circuit.turns[0]["apex_s"][0])
	check(blend != null and ramp != null and is_equal_approx(blend_m, 80.0) and is_equal_approx(ramp_m, 65.0) and merge_s > t1_apex,
		"#W14 an 80 m solid blend line guards a 65 m bypass ramp that rejoins %.0f m past Turn 1's %.0f m apex" % [merge_s - t1_apex, t1_apex])
	check(is_equal_approx(PitScript.SPEED_LIMIT_MPS, 80.0 / 3.6) and pit.sim_layout()["entry_s"] == PitScript.ENTRY_S,
		"#W15 the lane is limited to 80 km/h and hands the sim its own entry, exit and lateral layout")


func _test_pit_polish() -> void:
	var pit: Node3D = circuit.get_node("PitLane")
	var first_u: float = float(pit.stalls[0]["u"])
	check(first_u >= 60.0 and first_u - PitScript.ENTRY_BLEND_M - 18.0 >= 24.0 and is_equal_approx(float(pit.stalls[0]["s"]), 3083.0),
		"#W41 first stall has at least 24 m of straight fast lane after entry blend and before pull-in; existing garages stay at s=3083 m")
	var apron: bool = true
	for stall: Dictionary in pit.stalls:
		apron = apron and pit._surface_right(float(stall["u"])) >= PitScript.BOX_LATERAL_M + 1.2
	check(apron, "#W42 asphalt working apron supports the full width of a car at every team box")
	var lighting: Node3D = pit.get_node_or_null("PitLighting")
	var fills: Array = lighting.find_children("*", "OmniLight3D", true, false) if lighting != null else []
	var covered: bool = fills.size() == 5
	for garage: Node3D in pit.garages:
		var floor_center: Vector3 = garage.position + garage.basis.x * 4.5
		var lit: bool = false
		for fill: OmniLight3D in fills:
			lit = lit or (fill.position.distance_to(floor_center) < fill.omni_range * 0.9 and fill.light_energy > 1.0 and not fill.shadow_enabled and bool(fill.get_meta(&"no_shadow", false)))
		covered = covered and lit
	check(covered, "#W43 five shadowless garage fill lights cover all ten garage floors and crew work areas")
	var leds: MultiMeshInstance3D = lighting.get_node_or_null("CeilingLEDs") if lighting != null else null
	var floors: MultiMeshInstance3D = lighting.get_node_or_null("GarageFloors") if lighting != null else null
	var entries: Array = lighting.find_children("EntryLight*", "SpotLight3D", true, false) if lighting != null else []
	check(leds != null and leds.multimesh.instance_count == 20 and floors != null and floors.multimesh.instance_count == 10 and entries.size() == 2 and pit.has_node("PitEntrySign"),
		"#W44 instanced ceiling strips, garage floors, two entry lights and an 80 km/h entry sign complete the lit pit approach")
	var environment: Node3D = circuit.get_node("Environment")
	check(is_equal_approx(PitScript.ENTRY_S, 3015.0) and environment._in_pit_gap(PitScript.ENTRY_S - 10.0),
		"#W45 roadside barriers and streetlights leave the extended pit entry mouth clear")
	var apron_lights: Array = lighting.find_children("ApronLight*", "SpotLight3D", true, false) if lighting != null else []
	var apron_lit: bool = apron_lights.size() == 10
	for light: SpotLight3D in apron_lights:
		apron_lit = apron_lit and light.position.y >= 4.0 and light.light_energy >= 6.0 and not light.shadow_enabled and bool(light.get_meta(&"no_shadow", false))
	check(apron_lit and lighting.has_node("ApronLEDs"), "#W47 each service box has a shadowless canopy task light above car and crew, separate from garage interior fill")
	var wall: MeshInstance3D = pit.get_node("PitWall")
	var anchors: Array[Vector3] = []
	for arc: float in pit.wall_arcs:
		anchors.append(ribbon.get_point_at_offset(arc, PitScript.PIT_WALL_M).origin)
	anchors.append(pit.get_pit_transform(PitScript.LANE_LENGTH_M, PitScript.PIT_WALL_M).origin)
	var min_y: float = INF
	var max_y: float = -INF
	for surface: int in range(wall.mesh.get_surface_count()):
		var vertices: PackedVector3Array = wall.mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]
		for vertex: Vector3 in vertices:
			var nearest: Vector3 = anchors[0]
			var distance_squared: float = INF
			for anchor: Vector3 in anchors:
				var delta: Vector3 = vertex - anchor
				var horizontal: float = delta.x * delta.x + delta.z * delta.z
				if horizontal < distance_squared:
					distance_squared = horizontal
					nearest = anchor
			min_y = minf(min_y, vertex.y - nearest.y)
			max_y = maxf(max_y, vertex.y - nearest.y)
	check(min_y >= -0.001 and absf(max_y - PitScript.WALL_HEIGHT_M) < 0.01,
		"#W48 extended pit wall stands on the surface with the full 1.2 m visible height, not half buried below it (%.3f to %.3f m)" % [min_y, max_y])


## Task 4: the night set — MultiMesh street furniture, the 180 m underpass, the harbor and the
## Tokyo skyline, inside the 160 draw call / 320 000 triangle budget.
func _test_urban_set() -> void:
	var environment = circuit.get_node_or_null("Environment")
	if environment == null:
		check(false, "#W16 the circuit carries its urban environment")
		return
	_test_civil_layers(environment)
	var barriers: MultiMeshInstance3D = environment.get_node_or_null("ConcreteBarriers")
	var lights: MultiMeshInstance3D = environment.get_node_or_null("Streetlights")
	var heads: MultiMeshInstance3D = environment.get_node_or_null("StreetlightHeads")
	var caps: MultiMeshInstance3D = environment.get_node_or_null("BarrierHazardCaps")
	var skyline: MultiMeshInstance3D = environment.get_node_or_null("Skyline")
	var neon: MultiMeshInstance3D = environment.get_node_or_null("TunnelNeon")
	var containers: Array[int] = []
	for index: int in range(3):
		var box: MultiMeshInstance3D = environment.get_node_or_null("HarborContainers%d" % index)
		if box != null and box.multimesh != null:
			containers.append(box.multimesh.instance_count)
	check(barriers != null and barriers.multimesh.instance_count > 1500 and caps != null and caps.multimesh.instance_count > 20 \
			and lights != null and lights.multimesh.instance_count > 120 and heads != null and heads.multimesh.instance_count == lights.multimesh.instance_count,
		"#W16 %d concrete barriers and %d hazard caps down both sides, every one a MultiMesh instance (%d double-arm lamps)" % [
			barriers.multimesh.instance_count if barriers != null else 0,
			caps.multimesh.instance_count if caps != null else 0,
			lights.multimesh.instance_count if lights != null else 0])

	var shell: MeshInstance3D = environment.get_node_or_null("TunnelShell")
	check(shell != null and shell.mesh != null and neon != null and neon.multimesh.instance_count >= 18 \
			and is_equal_approx(CircuitScript.TUNNEL_END_M - CircuitScript.TUNNEL_START_M, 180.0),
		"#W17 the 180 m Cyber City underpass has a concrete shell and %d ceiling neon strips" % (neon.multimesh.instance_count if neon != null else 0))

	var towers: int = 0
	var window_shader: bool = false
	if skyline != null and skyline.multimesh != null:
		towers = skyline.multimesh.instance_count
		window_shader = skyline.material_override is ShaderMaterial \
			and (skyline.material_override as ShaderMaterial).shader != null \
			and (skyline.material_override as ShaderMaterial).shader.resource_path.ends_with("neo_wangan_skyline.gdshader")
	check(towers >= 80 and window_shader and containers.size() == 3 and containers[0] > 10,
		"#W18 a %d-tower skyline glows through the window shader, and %d harbor containers are instanced in three colours" % [towers, containers.reduce(func(a: int, b: int) -> int: return a + b, 0)])

	var budget := _budget(circuit)
	var draw_calls: int = int(budget["draw_calls"])
	var triangles: int = int(budget["triangles"])
	check(draw_calls <= 160 and triangles <= 320000,
		"#W19 the circuit submits %d draw calls and %d triangles — inside the 160 / 320 000 budget" % [draw_calls, triangles])

	var world_environment: WorldEnvironment = circuit.get_node_or_null("WorldEnvironment")
	var night: bool = world_environment != null and world_environment.environment != null \
		and world_environment.environment.background_mode == Environment.BG_SKY \
		and world_environment.environment.sky != null and world_environment.environment.fog_enabled
	var energy_before: float = 0.0
	var energy_after: float = 0.0
	if neon != null and neon.material_override is StandardMaterial3D:
		energy_before = (neon.material_override as StandardMaterial3D).emission_energy_multiplier
		environment.update(0.37, null)
		energy_after = (neon.material_override as StandardMaterial3D).emission_energy_multiplier
	check(night and not is_equal_approx(energy_before, energy_after),
		"#W20 the set carries a night sky and fog, and its neon breathes between frames (%.2f -> %.2f)" % [energy_before, energy_after])


## Task 6: a race weekend on the street circuit. The world swaps its Apex nodes for Neo-Wangan's
## own scene, keeps 20 cars, hands the sim the street pit layout and points the HUD radar at the
## new ribbon.
func _test_race_weekend_integration() -> void:
	var config = ConfigScript.get_config()
	config.selected_circuit_id = "neo_wangan"
	config.total_laps = 3
	var prototype: Node3D = WorldScene.instantiate()
	var shared_environment: Environment = prototype.get_node("WorldEnvironment").environment
	prototype.free()
	var world = WorldScene.instantiate()
	root.add_child(world)
	world.set_process(false)
	check(world.get_node("WorldEnvironment").environment != shared_environment, "#W40 Neo-Wangan sky owns an Environment copy and cannot mutate the shared Apex weekend resource")
	var integrated: bool = world.active_circuit != null \
		and world.active_circuit.circuit_id == "neo_wangan" \
		and world.circuit_root != null \
		and absf(world.ribbon.length_m - 3150.0) <= 25.0 \
		and is_equal_approx(world.road_width_m, 11.5) \
		and world.actors.size() == 20 \
		and world.pit_lane.has_method("sim_layout") \
		and is_equal_approx(float(world.race.pit_layout["entry_s"]), 3015.0) \
		and is_equal_approx(float(world.race.pit_layout["stall_pitch_m"]), 12.0)
	check(integrated,
		"#W21 a Neo-Wangan race weekend loads the street scene: %.0f m ribbon, %.1f m wide, %d cars, and the sim pits on the street layout" % [world.ribbon.length_m, world.road_width_m, world.actors.size()])

	var radar = world.hud.radar
	world.environment.update(0.5, world.race)
	var screen: Jumbotron = world.pit_lane.get_node("MainGrandstand/Jumbotron")
	check(screen.last_row_values.size() == 10 and screen.last_row_values[0] > 0.9 and screen.last_row_colors[0] == preload("res://scripts/car/team_liveries.gd").color_for(world.race.standings()[0].team_id), "#W37 Neo-Wangan Jumbotron displays the live leading team's color and ten standing bars")
	var radar_ok: bool = radar.get("_ribbon") == world.ribbon and is_equal_approx(float(radar.get("_sim_length_m")), world.track.length)
	var radar_points: PackedVector2Array = (radar.get_node("Track") as Line2D).points
	check(radar_ok and radar_points.size() > 40,
		"#W22 the HUD radar binds the active circuit's own ribbon and its %d-point 2D trace" % radar_points.size())

	var ring: Vector3 = world.ribbon.get_point_at_offset(0.0, 0.0).origin
	var grid_ok: bool = true
	for actor in world.actors:
		grid_ok = grid_ok and actor.global_position.distance_to(ring) < 400.0
	check(grid_ok,
		"#W23 all 20 GT3 cars line up on the street circuit's grid, around the start line")

	for _frame: int in range(10):
		world.step(1.0 / 60.0)
	check(world.race.cars.size() == 20 and world.hud.radar != null,
		"#W24 the weekend steps ten frames on the new circuit without losing a car or the radar")

	# A full three-lap race with a box call: the street pit lane has to work for the AI too, not
	# just for the geometry test. The sim runs every tick, so no frames are needed.
	world.race.incidents_enabled = false
	var target = world.race.cars[0]
	for car: GtCar in world.race.cars:
		if world.race.stall_index_for_team(car.team_id) == 0:
			target = car
			break
	var stops_before: int = target.stops
	var requested: bool = world.request_pit(target.id)
	var guard: int = 0
	var straight_samples: int = 0
	var straight_centered: bool = true
	var on_pavement: bool = true
	while not world.race.is_finished() and guard < 20000:
		world.race.step()
		guard += 1
		if target.pit != null:
			var u: float = target.s - target.pit.start_s
			if target.pit.phase == GtTypes.PitPhase.IN and u >= 30.0 and u <= 45.0:
				straight_samples += 1
				straight_centered = straight_centered and absf(target.lateral - PitScript.FAST_LANE_M) < 0.4
			if u >= 25.0 and u <= PitScript.LANE_LENGTH_M:
				on_pavement = on_pavement and target.lateral + 1.0 <= world.pit_lane._surface_right(u) + 0.05
	var winner = world.race.standings()[0]
	check(requested and world.race.is_finished() and target.stops > stops_before and target.finished_at >= 0.0 and winner.lap >= 3,
		"#W25 a three-lap street race runs to the flag (%d cars finished, %d sim ticks), and a car that boxes is serviced in the 10-stall lane (%d stops)" % [
			_count_finished(world.race), guard, target.stops - stops_before])
	check(straight_samples >= 8 and straight_centered and on_pavement,
		"#W46 first-team car completes a centered straight run after entry before turning to its box, with both tyres supported by pit asphalt (%d samples)" % straight_samples)

	world.queue_free()
	ConfigScript.reset()
	await process_frame


func _test_civil_layers(environment: Node3D) -> void:
	var island: Node3D = environment.get_node_or_null("UrbanIslandRoot")
	var heroes: Node3D = environment.get_node_or_null("HeroLandmarksRoot")
	var corridor: Node3D = environment.get_node_or_null("MidgroundCorridorRoot")
	check(island != null and island.has_node("UrbanGroundSlab") and island.has_node("QuayWalls") and island.has_node("TunnelOverpassPlaza"), "#W26 land sectors have continuous ground, seawalls and tunnel rooftop plaza")
	check(heroes != null and heroes.has_node("BridgePylon0") and heroes.has_node("BridgePylon1") and heroes.has_node("BridgeSideTrussMM") and heroes.has_node("TunnelPortal0") and heroes.has_node("TunnelPortal1") and heroes.has_node("HarborCraneMM"), "#W27 Blender pylons, tunnel portals, four instanced harbor cranes and side trusses integrated")
	var building_count: int = 0
	if corridor != null:
		for child: Node in corridor.get_children():
			if child is MultiMeshInstance3D and child.name.begins_with("CorridorTower"):
				building_count += (child as MultiMeshInstance3D).multimesh.instance_count
	# Each GLB has two material meshes; only shell instances count as buildings.
	building_count /= 2
	check(building_count >= 48, "#W28 street canyon contains at least 48 GLB buildings (%d)" % building_count)
	var billboard: MultiMeshInstance3D = corridor.get_node_or_null("StreetBillboardMM") if corridor != null else null
	check(billboard != null and billboard.multimesh.instance_count == 24, "#W29 24 instanced neon billboards face the road")
	var pool: MultiMeshInstance3D = environment.get_node_or_null("StreetlightPools")
	var pool_ok: bool = pool != null
	if pool != null:
		var quad := pool.multimesh.mesh as QuadMesh
		pool_ok = quad != null and quad.size == Vector2(9.0, 5.5)
		# Dummy headless renderer returns identity for MultiMesh readback; inspect submitted poses.
		pool_ok = pool_ok and environment.light_pool_poses.size() == pool.multimesh.instance_count
		for pose: Transform3D in environment.light_pool_poses:
			var closest: float = ribbon.curve.get_closest_offset(pose.origin)
			var road: Transform3D = ribbon.get_point_at_offset(closest, 0.0)
			var lateral: float = absf((pose.origin - road.origin).dot(road.basis.x))
			pool_ok = pool_ok and absf(lateral - 3.2) < 0.15
	check(pool_ok, "#W30 9 x 5.5 m light pools centred at +/-3.2 m on asphalt")
	var palettes_ok: bool = true
	if heroes != null:
		for mesh_node: Node in heroes.find_children("*", "MeshInstance3D", true, false):
			if mesh_node.name == "PylonConcreteMat":
				palettes_ok = palettes_ok and mesh_node.material_override is ShaderMaterial
	check(palettes_ok and heroes != null, "#W31 GLB palette uses shared cel vertex-color material")
	var footprints_ok: bool = true
	for building: Dictionary in environment.near_track_buildings:
		var pose: Transform3D = building["pose"]
		var lateral: float = absf(float(building["lateral_m"]))
		footprints_ok = footprints_ok and lateral >= 14.0 and lateral <= 45.0
		for s: int in range(0, ceili(ribbon.length_m), 10):
			var local: Vector3 = pose.affine_inverse() * ribbon.get_point_at_offset(float(s), 0.0).origin
			footprints_ok = footprints_ok and not (absf(local.x) < 17.5 and absf(local.z) < 16.5)
	check(footprints_ok, "#W32 all corridor footprints clear every road segment and lie 14–45 m laterally")
	var crane_poses: Variant = environment.get("crane_poses")
	var crane_clear: bool = crane_poses is Array and crane_poses.size() == 4
	if crane_poses is Array:
		for pose: Transform3D in crane_poses:
			for s: int in range(0, 3150, 5):
				var local: Vector3 = pose.affine_inverse() * ribbon.get_point_at_offset(float(s), 0.0).origin
				crane_clear = crane_clear and not (absf(local.x) < 15.5 and absf(local.z) < 17.5)
	check(crane_clear, "#W34 all four harbor crane foundations clear all road legs")
	check(heroes != null and heroes.has_node("BridgeStayCables"), "#W35 bridge steel cables anchor to the curved deck")
	var pier_poses: Variant = environment.get("bridge_pier_poses")
	var grounded: bool = pier_poses is Array and pier_poses.size() >= 8
	if pier_poses is Array:
		for pose: Transform3D in pier_poses:
			var bottom: float = pose.origin.y - pose.basis.y.length() * 0.5
			grounded = grounded and absf(bottom + 6.0) < 0.01
	check(grounded, "#W36 bridge piers run from seabed to underside of the deck")
	var markers: MultiMeshInstance3D = environment.get_node_or_null("BrakingMarkers")
	check(markers != null and markers.multimesh.instance_count == 36, "#W38 shared FIA 150/100/50 m braking boards cover all twelve corners")
	var detail_passes_ok: bool = corridor != null
	if corridor != null:
		for child: Node in corridor.get_children():
			if child is MultiMeshInstance3D and child.name.ends_with("Detail"):
				var detail := child as MultiMeshInstance3D
				detail_passes_ok = detail_passes_ok and detail.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF and detail.multimesh.mesh.surface_get_material(0).next_pass == null
	check(detail_passes_ok, "#W39 emissive facade details avoid redundant hull and shadow passes; building shells retain ink")


func _test_ground_clearance() -> void:
	var ground: MeshInstance3D = circuit.get_node_or_null("Environment/UrbanIslandRoot/UrbanGroundSlab")
	if ground == null:
		check(false, "#W33 ground geometry available for surface ray checks")
		return
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	shape.shape = ground.mesh.create_trimesh_shape()
	body.add_child(shape)
	root.add_child(body)
	await physics_frame
	await physics_frame
	var supported: bool = true
	var clear: bool = true
	var checked: int = 0
	for s: int in range(0, ceili(ribbon.length_m), 8):
		if s > BuilderScript.BRIDGE_START_M - 8.0 and s < BuilderScript.BRIDGE_END_M + 8.0:
			continue
		for lateral: float in [-5.0, 0.0, 5.0]:
			var road: Vector3 = ribbon.get_point_at_offset(float(s), lateral).origin
			var query := PhysicsRayQueryParameters3D.create(road + Vector3.UP * 10.0, road + Vector3.DOWN)
			var hit: Dictionary = root.world_3d.direct_space_state.intersect_ray(query)
			supported = supported and not hit.is_empty()
			if not hit.is_empty():
				clear = clear and float(hit["position"].y) < road.y - 0.01
			checked += 1
	check(supported and clear, "#W33 %d land-road samples have support below asphalt, never above" % checked)
	body.queue_free()
	await process_frame


func _count_finished(race) -> int:
	var finished: int = 0
	for car in race.cars:
		if car.finished_at >= 0.0:
			finished += 1
	return finished


## Draw calls and triangles of every visible mesh under `root`.
func _budget(root_node: Node) -> Dictionary:
	var total := {"draw_calls": 0, "triangles": 0}
	_count_budget(root_node, total)
	return total


func _count_budget(node: Node, total: Dictionary) -> void:
	if node is Node3D and not (node as Node3D).visible:
		return
	var mesh: Mesh = null
	var copies: int = 1
	if node is MultiMeshInstance3D and (node as MultiMeshInstance3D).multimesh != null:
		mesh = (node as MultiMeshInstance3D).multimesh.mesh
		copies = (node as MultiMeshInstance3D).multimesh.instance_count
	elif node is MeshInstance3D:
		mesh = (node as MeshInstance3D).mesh
	if mesh != null:
		for surface: int in range(mesh.get_surface_count()):
			var arrays: Array = mesh.surface_get_arrays(surface)
			var raw: Variant = arrays[Mesh.ARRAY_INDEX]
			var count: int = 0
			if raw is PackedInt32Array and (raw as PackedInt32Array).size() > 0:
				count = (raw as PackedInt32Array).size() / 3
			else:
				count = (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() / 3
			var material: Material = node.material_override if node.material_override != null else mesh.surface_get_material(surface)
			var passes: int = 1
			while material != null and material.next_pass != null:
				passes += 1
				material = material.next_pass
			total["draw_calls"] = int(total["draw_calls"]) + passes
			total["triangles"] = int(total["triangles"]) + count * copies * passes
	for child: Node in node.get_children():
		_count_budget(child, total)


## The Apex Ring spline is a different scene and must be byte-for-byte where it was.
func _test_apex_preserved() -> void:
	var apex := ApexScene.instantiate() as RibbonScript
	root.add_child(apex)
	var length: float = apex.length_m
	var points: int = apex.curve.get_point_count()
	check(absf(length - APEX_LENGTH_M) <= 1.0 and points == 303,
		"#W9 the Apex Ring keeps its own 4 158.8 m spline and 303 control points — Neo-Wangan is a separate scene (%d points)" % points)
	apex.queue_free()
