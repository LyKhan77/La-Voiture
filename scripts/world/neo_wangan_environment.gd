class_name NeoWanganEnvironment
extends Node3D

## The night set of the Neo-Wangan street circuit (FASE 12, Task 4): concrete barrier walls down both
## sides, double-arm Shuto expressway lamps, green overhead direction gantries, the 180 m Cyber City
## underpass with its ceiling of neon strips, the Shuto Bay Bridge deck and piers, the harbor
## container stacks with their gantry cranes, and a 110-tower Tokyo skyline whose windows glow
## through a world-space shader.
##
## Every element that repeats more than three times is one MultiMeshInstance3D, so the whole set
## costs a handful of draw calls (see stats()). No textures: flat cel colours and one shader.
##
## This is the city set of Neo-Wangan only; the Apex Ring keeps TrackEnvironmentBuilder.

const RibbonGeometry := preload("res://scripts/world/ribbon_geometry.gd")
const MeshBatchScript := preload("res://scripts/world/mesh_batch.gd")
const ToonMaterials := preload("res://scripts/world/toon_materials.gd")
const RibbonScript := preload("res://scripts/car/track_ribbon.gd")
const CircuitScript := preload("res://scripts/world/neo_wangan_circuit_builder.gd")
const SkylineShader := preload("res://shaders/neo_wangan_skyline.gdshader")
const PoolShader := preload("res://shaders/neo_wangan_light_pool.gdshader")

const BARRIER_LATERAL_M: float = 6.35
const BARRIER_STEP_M: float = 3.0
const BARRIER_SIZE := Vector3(0.55, 1.05, 2.9)
const HAZARD_STEP_M: float = 6.0
const HAZARD_CURVATURE: float = 0.006

const LAMP_PITCH_M: float = 42.0
const LAMP_LATERAL_M: float = 6.9
const LAMP_HEIGHT_M: float = 9.0

const GANTRY_S: Array[float] = [300.0, 900.0, 1750.0, 2600.0]
const GANTRY_HALF_SPAN_M: float = 7.4
const GANTRY_HEIGHT_M: float = 6.2
const GANTRY_PANEL_WIDTH_M: float = 6.4
const GANTRY_PANEL_HEIGHT_M: float = 1.9

const TUNNEL_HALF_WIDTH_M: float = 6.7
const TUNNEL_CLEARANCE_M: float = 5.0
const TUNNEL_LAMP_PITCH_M: float = 9.0
const TUNNEL_STEP_M: float = 4.0

const DECK_STEP_M: float = 6.0
const DECK_SIZE := Vector3(14.4, 0.9, 6.2)
const PIER_PITCH_M: float = 60.0
const PIER_LATERAL_M: float = 4.2
const BASE_Y: float = -6.0

const CONTAINER_SIZE := Vector3(2.44, 2.59, 6.06)
const CONTAINER_COLORS: Array[Color] = [Color("#c2342c"), Color("#1f7f8c"), Color("#d9a21b")]
const CRANE_S: Array[float] = [1390.0, 1470.0]
const CRANE_LATERAL_M: float = -24.0

const SKYLINE_COUNT: int = 110
const SKYLINE_MIN_RADIUS_M: float = 250.0
const SKYLINE_MAX_RADIUS_M: float = 660.0
const SKYLINE_TRACK_CLEARANCE_M: float = 70.0
const SKYLINE_SEED: int = 20260227

const NIGHT_TOP := Color("#060a18")
const NIGHT_HORIZON := Color("#2a1a3e")
const NEON_CYAN := Color("#00f0ff")
const NEON_MAGENTA := Color("#ff2d78")
const ASPHALT_DARK := Color("#1a1c22")
const WATER_COLOR := Color("#07121e")
const METAL := Color("#3c4250")
const LAMP_HEAD := Color("#fff0c8")

var ribbon: RibbonScript
var circuit
## RaceWeekendWorld reads this for its digital flag panels; the street circuit has none.
var furniture: Node = null

## Render budget of the whole set, filled by measure().
var draw_calls: int = 0
var triangle_count: int = 0
var multimesh_count: int = 0

var barrier_instance: MultiMeshInstance3D
var streetlight_instance: MultiMeshInstance3D
var skyline_instance: MultiMeshInstance3D
var container_instances: Array[MultiMeshInstance3D] = []
var tunnel_neon_instance: MultiMeshInstance3D
var skyline_buildings: Array[Dictionary] = [] # {position, size}
var barrier_count: int = 0
var streetlight_count: int = 0
var container_count: int = 0
var tunnel_lamp_count: int = 0

var _world_environment: WorldEnvironment
var _sun: DirectionalLight3D
var _camera: Camera3D
var _neon_material: StandardMaterial3D
var _lamp_material: StandardMaterial3D
var _window_material: ShaderMaterial
var _clock_s: float = 0.0


## Builds the whole set against the circuit's ribbon and its authored spans.
func build(p_ribbon: RibbonScript, p_circuit) -> void:
	ribbon = p_ribbon
	circuit = p_circuit
	_build_ground()
	_build_barriers()
	_build_kerbs()
	_build_streetlights()
	_build_gantry_signs()
	_build_tunnel()
	_build_bridge()
	_build_harbor()
	_build_skyline()
	_apply_night_sky()
	measure()


## The race world hands its own sky, sun and camera to the set.
func bind_world(world_environment: WorldEnvironment, sun: DirectionalLight3D, camera: Camera3D) -> void:
	_world_environment = world_environment
	_sun = sun
	_camera = camera
	_apply_night_sky()


## Neon and window glow breathe a little, like a city that never quite settles.
func update(delta: float, _race) -> void:
	_clock_s += delta
	var pulse: float = 0.86 + 0.14 * sin(_clock_s * 2.1)
	if _neon_material != null:
		_neon_material.emission_energy_multiplier = 2.2 * pulse
	if _lamp_material != null:
		_lamp_material.emission_energy_multiplier = 2.6
	if _window_material != null:
		_window_material.set_shader_parameter("window_energy", 1.8 * pulse)


func stats() -> Dictionary:
	measure()
	return {
		"draw_calls": draw_calls,
		"triangles": triangle_count,
		"multimeshes": multimesh_count,
		"barriers": barrier_count,
		"streetlights": streetlight_count,
		"containers": container_count,
		"tunnel_lamps": tunnel_lamp_count,
		"skyline": skyline_buildings.size(),
	}


## Counts what a frame would submit and how heavy it is. MultiMesh instances cost one draw call per
## surface and pay their triangles once per instance.
func measure() -> void:
	draw_calls = 0
	triangle_count = 0
	multimesh_count = 0
	_measure_node(self)


func _measure_node(node: Node) -> void:
	if node is Node3D and not (node as Node3D).visible:
		return
	if node is MultiMeshInstance3D:
		var instanced := node as MultiMeshInstance3D
		if instanced.multimesh != null and instanced.multimesh.mesh != null:
			multimesh_count += 1
			draw_calls += instanced.multimesh.mesh.get_surface_count()
			triangle_count += _mesh_triangles(instanced.multimesh.mesh) * instanced.multimesh.instance_count
	elif node is MeshInstance3D:
		var mesh_instance := node as MeshInstance3D
		if mesh_instance.mesh != null:
			draw_calls += mesh_instance.mesh.get_surface_count()
			triangle_count += _mesh_triangles(mesh_instance.mesh)
	for child: Node in node.get_children():
		_measure_node(child)


static func _mesh_triangles(mesh: Mesh) -> int:
	var total: int = 0
	for surface: int in range(mesh.get_surface_count()):
		var arrays: Array = mesh.surface_get_arrays(surface)
		var raw: Variant = arrays[Mesh.ARRAY_INDEX]
		if raw is PackedInt32Array and (raw as PackedInt32Array).size() > 0:
			total += (raw as PackedInt32Array).size() / 3
		else:
			total += (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() / 3
	return total


# --- ground and water ---------------------------------------------------------------------------

func _build_ground() -> void:
	_base_plane("Base", BASE_Y, 6000.0, ToonMaterials.make(ASPHALT_DARK))
	var water := _base_plane("Water", BASE_Y + 0.35, 900.0, _water_material())
	var bridge_middle: Vector3 = ribbon.get_point_at_offset(475.0, 0.0).origin
	water.position = Vector3(bridge_middle.x, BASE_Y + 0.35, bridge_middle.z)


func _base_plane(node_name: String, y: float, size: float, material: Material) -> MeshInstance3D:
	var plane := MeshInstance3D.new()
	plane.name = node_name
	var mesh := PlaneMesh.new()
	mesh.size = Vector2(size, size)
	plane.mesh = mesh
	plane.material_override = material
	plane.position = Vector3(0.0, y, 0.0)
	plane.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(plane)
	return plane


func _water_material() -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = WATER_COLOR
	material.metallic = 0.75
	material.roughness = 0.08
	material.emission_enabled = true
	material.emission = Color(0.0, 0.35, 0.5)
	material.emission_energy_multiplier = 0.18
	return material


# --- barriers ------------------------------------------------------------------------------------

func _build_barriers() -> void:
	var mesh := BoxMesh.new()
	mesh.size = Vector3.ONE
	var transforms: Array[Transform3D] = []
	var hazard: Array[Transform3D] = []
	var length: float = ribbon.length_m
	var s: float = 0.0
	while s < length:
		for side: float in [-1.0, 1.0]:
			if side > 0.0 and _in_pit_gap(s):
				continue
			transforms.append(RibbonGeometry.box_transform(ribbon, s, side * BARRIER_LATERAL_M, BARRIER_SIZE, 0.0))
		s += BARRIER_STEP_M
	s = 0.0
	while s < length:
		if absf(ribbon.get_curvature_at(s)) >= HAZARD_CURVATURE:
			for side: float in [-1.0, 1.0]:
				if side > 0.0 and _in_pit_gap(s):
					continue
				hazard.append(RibbonGeometry.box_transform(ribbon, s, side * BARRIER_LATERAL_M, Vector3(0.6, 0.1, 2.2), BARRIER_SIZE.y))
		s += HAZARD_STEP_M
	barrier_count = transforms.size()
	barrier_instance = _multimesh("ConcreteBarriers", mesh, transforms, ToonMaterials.make(Color("#b9bdc7")))
	_multimesh("BarrierHazardCaps", mesh, hazard, ToonMaterials.make(Color("#ffd400")))
	barrier_instance.set_meta(&"fia_barrier", true)


## The right-hand barrier stops for the pit entry and starts again after the pit exit merge.
func _in_pit_gap(s: float) -> bool:
	var from: float = 3050.0
	var until: float = 150.0
	return fposmod(s - from, ribbon.length_m) <= fposmod(until - from, ribbon.length_m)


# --- kerbs -------------------------------------------------------------------------------------

## Low street-circuit kerbs on the inside of every numbered turn: 1.2 m red/white blocks standing
## 30 mm proud of the asphalt, one MultiMesh per colour for all twelve corners.
func _build_kerbs() -> void:
	var reds: Array[Transform3D] = []
	var whites: Array[Transform3D] = []
	if circuit == null or not ("turns" in circuit):
		return
	for turn: Dictionary in circuit.turns:
		var direction: int = int(turn["direction"])
		var lateral: float = -direction * (float(ribbon.road_half_width_m) - 0.65)
		var half_span: float = float(turn["span_m"]) * 0.5
		var apex: float = float(turn["apex_s"][0]) if not (turn["apex_s"] as Array).is_empty() else float(turn["s"])
		var count: int = maxi(4, int(half_span * 2.0 / 2.4))
		for index: int in range(count):
			var at: float = fposmod(apex - half_span + 2.4 * float(index), ribbon.length_m)
			var pose: Transform3D = RibbonGeometry.box_transform(ribbon, at, lateral, Vector3(1.25, 0.06, 2.2), 0.0)
			if index % 2 == 0:
				reds.append(pose)
			else:
				whites.append(pose)
	var mesh := BoxMesh.new()
	mesh.size = Vector3.ONE
	_multimesh("KerbsRed", mesh, reds, ToonMaterials.make(Color("#d9232e")))
	_multimesh("KerbsWhite", mesh, whites, ToonMaterials.make(Color("#f4f5f7")))


# --- streetlights --------------------------------------------------------------------------------

func _build_streetlights() -> void:
	var metal := ToonMaterials.vertex_colored(false)
	var batch := MeshBatchScript.new()
	batch.cylinder(metal, METAL, Transform3D.IDENTITY, 0.17, 0.12, LAMP_HEIGHT_M, 6, false, false)
	for direction: float in [-1.0, 1.0]:
		var tip := Vector3(direction * 1.9, LAMP_HEIGHT_M, 0.0)
		batch.strut(metal, METAL, Vector3(0.0, LAMP_HEIGHT_M - 0.35, 0.0), tip, 0.17)
	var heads := MeshBatchScript.new()
	for direction: float in [-1.0, 1.0]:
		heads.box(metal, LAMP_HEAD, Transform3D(Basis(), Vector3(direction * 2.1, LAMP_HEIGHT_M - 0.18, 0.0)), Vector3(0.75, 0.16, 0.42))
	var pole_mesh: ArrayMesh = batch.commit()
	var head_mesh: ArrayMesh = heads.commit()
	var transforms: Array[Transform3D] = []
	var s: float = 14.0
	while s < ribbon.length_m:
		for side: float in [-1.0, 1.0]:
			if side > 0.0 and _in_pit_gap(s):
				continue
			var pose: Transform3D = ribbon.get_point_at_offset(s, side * LAMP_LATERAL_M)
			transforms.append(pose)
		s += LAMP_PITCH_M
	streetlight_count = transforms.size()
	streetlight_instance = _multimesh("Streetlights", pole_mesh, transforms, ToonMaterials.make(METAL))
	_lamp_material = _emissive_material(LAMP_HEAD, 2.6)
	_multimesh("StreetlightHeads", head_mesh, transforms, _lamp_material)
	_build_light_pools(transforms)


## The warm pool each street lamp throws across the asphalt, as one additive quad per lamp: a night
## circuit has to stay readable at 60 FPS, so the light is painted rather than cast.
func _build_light_pools(lamp_transforms: Array[Transform3D]) -> void:
	var quad := QuadMesh.new()
	quad.size = Vector2(17.0, 11.0)
	var pools: Array[Transform3D] = []
	for pose: Transform3D in lamp_transforms:
		var flat := Transform3D(pose.basis * Basis(Vector3.RIGHT, -PI * 0.5), pose.origin + Vector3.UP * 0.04)
		pools.append(flat)
	_multimesh("StreetlightPools", quad, pools, _pool_material(Color("#ffcf8a"), 0.5))


func _pool_material(color: Color, intensity: float) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = PoolShader
	material.set_shader_parameter("pool_color", color)
	material.set_shader_parameter("intensity", intensity)
	return material


func _emissive_material(color: Color, energy: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = energy
	return material


# --- overhead direction signs ---------------------------------------------------------------------

func _build_gantry_signs() -> void:
	var batch := MeshBatchScript.new()
	var metal: Material = ToonMaterials.vertex_colored(false)
	var green: Material = ToonMaterials.vertex_colored(false)
	var white: Material = ToonMaterials.vertex_colored(false)
	for s: float in GANTRY_S:
		for side: float in [-1.0, 1.0]:
			batch.box(metal, METAL, _box_at(s, side * GANTRY_HALF_SPAN_M, 0.0, GANTRY_HEIGHT_M * 0.5), Vector3(0.4, GANTRY_HEIGHT_M, 0.4))
		var left: Vector3 = _at(s, -GANTRY_HALF_SPAN_M, GANTRY_HEIGHT_M)
		var right: Vector3 = _at(s, GANTRY_HALF_SPAN_M, GANTRY_HEIGHT_M)
		batch.strut(metal, METAL, left, right, 0.34)
		var panel: Vector3 = _at(s, 0.0, GANTRY_HEIGHT_M - 1.1)
		var forward: Vector3 = ribbon.get_point_at_offset(s, 0.0).basis.z
		batch.box(green, Color("#117a4b"), Transform3D(Basis(), panel), Vector3(GANTRY_PANEL_WIDTH_M, GANTRY_PANEL_HEIGHT_M, 0.16))
		for row: int in range(2):
			var strip: Vector3 = panel + forward * 0.1 + Vector3.UP * (0.4 - float(row) * 0.5)
			batch.box(white, Color("#f4f5f7"), Transform3D(Basis(), strip), Vector3(GANTRY_PANEL_WIDTH_M * 0.62, 0.14, 0.04))
	var signs := MeshInstance3D.new()
	signs.name = "GantrySigns"
	signs.mesh = batch.commit()
	add_child(signs)


func _at(s: float, lateral_m: float, height_m: float) -> Vector3:
	return ribbon.get_point_at_offset(s, lateral_m).origin + Vector3.UP * height_m


func _box_at(s: float, lateral_m: float, height_m: float, centre_height_m: float) -> Transform3D:
	var pose: Transform3D = ribbon.get_point_at_offset(s, lateral_m)
	pose.origin += Vector3.UP * (height_m + centre_height_m)
	return pose


# --- underpass -----------------------------------------------------------------------------------

func _build_tunnel() -> void:
	var start_s: float = CircuitScript.TUNNEL_START_M
	var end_s: float = CircuitScript.TUNNEL_END_M
	var batch := MeshBatchScript.new()
	var concrete: Material = ToonMaterials.vertex_colored(false)
	var length: float = end_s - start_s
	var steps: int = maxi(1, ceili(length / TUNNEL_STEP_M))
	for index: int in range(steps):
		var sa: float = lerpf(start_s, end_s, float(index) / float(steps))
		var sb: float = lerpf(start_s, end_s, float(index + 1) / float(steps))
		for side: float in [-1.0, 1.0]:
			var bottom_a: Vector3 = _at(sa, side * TUNNEL_HALF_WIDTH_M, -1.2)
			var bottom_b: Vector3 = _at(sb, side * TUNNEL_HALF_WIDTH_M, -1.2)
			var top_a: Vector3 = _at(sa, side * TUNNEL_HALF_WIDTH_M, TUNNEL_CLEARANCE_M)
			var top_b: Vector3 = _at(sb, side * TUNNEL_HALF_WIDTH_M, TUNNEL_CLEARANCE_M)
			batch.quad(concrete, Color("#585d68"), bottom_a, bottom_b, top_b, top_a, -Vector3(side, 0.0, 0.0))
		var left_a: Vector3 = _at(sa, -TUNNEL_HALF_WIDTH_M, TUNNEL_CLEARANCE_M)
		var left_b: Vector3 = _at(sb, -TUNNEL_HALF_WIDTH_M, TUNNEL_CLEARANCE_M)
		var right_a: Vector3 = _at(sa, TUNNEL_HALF_WIDTH_M, TUNNEL_CLEARANCE_M)
		var right_b: Vector3 = _at(sb, TUNNEL_HALF_WIDTH_M, TUNNEL_CLEARANCE_M)
		batch.quad(concrete, Color("#3d424c"), left_a, left_b, right_b, right_a, Vector3.DOWN)
	var shell := MeshInstance3D.new()
	shell.name = "TunnelShell"
	shell.mesh = batch.commit()
	add_child(shell)

	var transforms: Array[Transform3D] = []
	var s: float = start_s + 3.0
	while s < end_s - 3.0:
		var pose: Transform3D = ribbon.get_point_at_offset(s, 0.0)
		pose.origin += Vector3.UP * (TUNNEL_CLEARANCE_M - 0.28)
		transforms.append(pose)
		s += TUNNEL_LAMP_PITCH_M
	tunnel_lamp_count = transforms.size()
	var lamp_mesh := BoxMesh.new()
	lamp_mesh.size = Vector3(2.6, 0.14, 0.35)
	_neon_material = _emissive_material(NEON_CYAN, 2.2)
	tunnel_neon_instance = _multimesh("TunnelNeon", lamp_mesh, transforms, _neon_material)
	var neon_pools: Array[Transform3D] = []
	var pool_quad := QuadMesh.new()
	pool_quad.size = Vector2(9.0, 9.0)
	for pose: Transform3D in transforms:
		var floor_pose := Transform3D(pose.basis * Basis(Vector3.RIGHT, -PI * 0.5), pose.origin - Vector3.UP * (TUNNEL_CLEARANCE_M - 0.32))
		neon_pools.append(floor_pose)
	_multimesh("TunnelNeonPools", pool_quad, neon_pools, _pool_material(NEON_CYAN, 0.55))
	tunnel_neon_instance.set_meta(&"neon_color", NEON_CYAN)
	# A magenta service strip on each wall, so the underpass reads as two neon colours.
	var wall_transforms: Array[Transform3D] = []
	s = start_s + 6.0
	while s < end_s - 6.0:
		for side: float in [-1.0, 1.0]:
			var pose: Transform3D = ribbon.get_point_at_offset(s, side * (TUNNEL_HALF_WIDTH_M - 0.12))
			pose.origin += Vector3.UP * 1.4
			wall_transforms.append(pose)
		s += 18.0
	_multimesh("TunnelWallGlow", lamp_mesh, wall_transforms, _emissive_material(NEON_MAGENTA, 1.5))


# --- Shuto Bay Bridge ----------------------------------------------------------------------------

func _build_bridge() -> void:
	var deck_mesh := BoxMesh.new()
	deck_mesh.size = Vector3.ONE
	var decks: Array[Transform3D] = []
	var s: float = CircuitScript.BRIDGE_START_M
	while s <= CircuitScript.BRIDGE_END_M:
		decks.append(RibbonGeometry.box_transform(ribbon, s, 0.0, DECK_SIZE, -DECK_SIZE.y))
		s += DECK_STEP_M
	_multimesh("BridgeDeck", deck_mesh, decks, ToonMaterials.make(Color("#6b7280")))
	var piers: Array[Transform3D] = []
	s = CircuitScript.BRIDGE_START_M + 20.0
	while s <= CircuitScript.BRIDGE_END_M - 20.0:
		for side: float in [-1.0, 1.0]:
			var pose: Transform3D = ribbon.get_point_at_offset(s, side * PIER_LATERAL_M)
			var road_y: float = pose.origin.y
			var height: float = maxf(road_y - BASE_Y, 2.0)
			pose.origin = Vector3(pose.origin.x, BASE_Y, pose.origin.z)
			pose.basis = Basis.IDENTITY.scaled(Vector3(2.4, height, 2.4))
			piers.append(pose)
		s += PIER_PITCH_M
	_multimesh("BridgePillars", deck_mesh, piers, ToonMaterials.make(Color("#8b8f99")))


# --- harbor --------------------------------------------------------------------------------------

func _build_harbor() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = SKYLINE_SEED + 7
	var per_color: Array[Array] = [[], [], []]
	var container_mesh := BoxMesh.new()
	container_mesh.size = Vector3.ONE
	for stack: int in range(6):
		var s: float = 1330.0 + float(stack) * 18.0
		var lateral: float = CRANE_LATERAL_M + 2.0
		for level: int in range(3):
			for row: int in range(3):
				var pose: Transform3D = ribbon.get_point_at_offset(s + float(row) * 6.4, lateral - float(level) * 2.8)
				pose.origin += Vector3.UP * (CONTAINER_SIZE.y * 0.5 + float(level) * CONTAINER_SIZE.y)
				pose.basis = pose.basis.scaled(CONTAINER_SIZE)
				per_color[rng.randi_range(0, per_color.size() - 1)].append(pose)
				container_count += 1
	for index: int in range(per_color.size()):
		var instance := _multimesh("HarborContainers%d" % index, container_mesh, per_color[index], ToonMaterials.make(CONTAINER_COLORS[index]))
		container_instances.append(instance)
	_build_cranes()


## Two container gantry cranes over the stacks: four legs, a top beam and a trolley.
func _build_cranes() -> void:
	var batch := MeshBatchScript.new()
	var steel: Material = ToonMaterials.vertex_colored(false)
	for s: float in CRANE_S:
		var pose: Transform3D = ribbon.get_point_at_offset(s, CRANE_LATERAL_M)
		var basis: Basis = pose.basis
		var height: float = 22.0
		for side: float in [-1.0, 1.0]:
			for along: float in [-1.0, 1.0]:
				var foot: Vector3 = pose.origin + basis.x * (side * 5.0) + basis.z * (along * 4.0) + Vector3.UP * (height * 0.5)
				batch.box(steel, Color("#e86a1f"), Transform3D(basis, foot), Vector3(1.1, height, 1.1))
		var beam: Vector3 = pose.origin + Vector3.UP * (height + 0.6)
		batch.box(steel, Color("#e86a1f"), Transform3D(basis, beam), Vector3(12.0, 1.1, 2.0))
		var trolley: Vector3 = pose.origin + Vector3.UP * (height - 1.4) + basis.x * 3.4
		batch.box(steel, Color("#2f3742"), Transform3D(basis, trolley), Vector3(2.6, 1.6, 2.4))
	var cranes := MeshInstance3D.new()
	cranes.name = "HarborCranes"
	cranes.mesh = batch.commit()
	add_child(cranes)


# --- skyline -------------------------------------------------------------------------------------

## A deterministic ring of towers around the loop, clear of the circuit itself.
func _build_skyline() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = SKYLINE_SEED
	var track_points: PackedVector2Array = PackedVector2Array()
	var step: float = 20.0
	var s: float = 0.0
	while s < ribbon.length_m:
		var at: Vector3 = ribbon.get_point_at_offset(s, 0.0).origin
		track_points.append(Vector2(at.x, at.z))
		s += step
	var centre: Vector2 = Vector2.ZERO
	for point: Vector2 in track_points:
		centre += point
	centre /= float(track_points.size())
	var transforms: Array[Transform3D] = []
	var attempts: int = 0
	while skyline_buildings.size() < SKYLINE_COUNT and attempts < SKYLINE_COUNT * 12:
		attempts += 1
		var angle: float = rng.randf_range(0.0, TAU)
		var radius: float = rng.randf_range(SKYLINE_MIN_RADIUS_M, SKYLINE_MAX_RADIUS_M)
		var at: Vector2 = centre + Vector2(cos(angle), sin(angle)) * radius
		var clear: bool = true
		for point: Vector2 in track_points:
			if point.distance_to(at) < SKYLINE_TRACK_CLEARANCE_M:
				clear = false
				break
		if not clear:
			continue
		var width: float = rng.randf_range(14.0, 34.0)
		var depth: float = rng.randf_range(14.0, 34.0)
		var height: float = rng.randf_range(28.0, 145.0) * (0.75 + 0.5 * (radius - SKYLINE_MIN_RADIUS_M) / (SKYLINE_MAX_RADIUS_M - SKYLINE_MIN_RADIUS_M))
		var pose := Transform3D(Basis(), Vector3(at.x, BASE_Y + height * 0.5, at.y))
		pose.basis = pose.basis.scaled(Vector3(width, height, depth))
		transforms.append(pose)
		skyline_buildings.append({"position": pose.origin, "size": Vector3(width, height, depth)})
	var towers := BoxMesh.new()
	towers.size = Vector3.ONE
	_window_material = ShaderMaterial.new()
	_window_material.shader = SkylineShader
	skyline_instance = _multimesh("Skyline", towers, transforms, _window_material)
	skyline_instance.set_meta(&"towers", skyline_buildings.size())
	skyline_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


# --- shared --------------------------------------------------------------------------------------

func _multimesh(node_name: String, mesh: Mesh, transforms: Array, material: Material) -> MultiMeshInstance3D:
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = mesh
	multimesh.instance_count = transforms.size()
	for index: int in range(transforms.size()):
		multimesh.set_instance_transform(index, transforms[index])
	var instance := MultiMeshInstance3D.new()
	instance.name = node_name
	instance.multimesh = multimesh
	instance.material_override = material
	add_child(instance)
	return instance


func _apply_night_sky() -> void:
	var environment: Environment = null
	if _world_environment != null and _world_environment.environment != null:
		environment = _world_environment.environment
	elif get_parent() != null and get_parent().get_node_or_null("WorldEnvironment") != null:
		environment = (get_parent().get_node("WorldEnvironment") as WorldEnvironment).environment
	if environment == null:
		return
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = NIGHT_TOP
	sky_material.sky_horizon_color = NIGHT_HORIZON
	sky_material.ground_horizon_color = NIGHT_HORIZON
	sky_material.ground_bottom_color = Color("#05070d")
	sky_material.sun_angle_max = 0.0
	var sky := Sky.new()
	sky.sky_material = sky_material
	environment.background_mode = Environment.BG_SKY
	environment.sky = sky
	# The city itself is the light source at night: a cool ambient wash plus a low moon, enough to
	# read the asphalt and the barriers without a light per street lamp.
	environment.ambient_light_energy = 0.85
	environment.fog_enabled = true
	environment.fog_light_color = Color("#232c4a")
	environment.fog_density = 0.0009
	if _sun != null:
		_sun.light_energy = 0.5
		_sun.light_color = Color("#9db4ff")
