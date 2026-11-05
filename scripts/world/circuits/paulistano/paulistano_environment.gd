class_name PaulistanoEnvironment
extends "res://scripts/world/circuits/base/circuit_environment.gd"

## Paulistano Speed Arena environment: production Tier A corridor (asphalt, kerbs,
## Armco, Tecpro, braking boards, flag panels, catch fence, rubber groove) with the
## pit-side rail opened on the LEFT, the approved procedural laterite heightfield,
## Guarapiranga reservoir, Mata Atlantica biome and paddock, four hero landmark GLBs,
## and the Tropical Storm sky with a wet 70%-rain track. Ported from the approved
## Route 2 build; the runtime never reads the mapgen repo.

const Layout := preload("res://scripts/world/circuits/paulistano/paulistano_layout.gd")
const TerrainField := preload("res://scripts/world/circuits/paulistano/paulistano_terrain.gd")
const Strip := preload("res://scripts/world/circuits/paulistano/paulistano_strip.gd")
const Toon := preload("res://scripts/world/shared/toon_materials.gd")
const TreeWindShader := preload("res://shaders/paulistano_tree_wind.gdshader")
const WaterShader := preload("res://shaders/paulistano_water.gdshader")
const ToonLookScript := preload("res://scripts/world/circuits/paulistano/paulistano_toon.gd")
const Liveries := preload("res://scripts/car/team_liveries.gd")
const MeshBatchScript := preload("res://scripts/world/shared/mesh_batch.gd")
const PitKit := preload("res://scripts/world/shared/pit_kit.gd")
const PitCrewFigureScript := preload("res://scripts/car/pit_crew_figure.gd")
const Line := preload("res://scripts/car/adaptive_racing_line.gd")
const Surface := preload("res://scripts/world/shared/enhanced_track_geometry.gd")
const PitZone := preload("res://scripts/world/shared/pit_zone.gd")
const SkyController := preload("res://scripts/world/shared/shared_cel_sky_controller.gd")
const Fence := preload("res://scripts/world/circuits/paulistano/paulistano_catch_fence.gd")

const ASSET_DIR := "res://assets/tracks/paulistano/models"
const ENVIRONMENT_TRIANGLE_BUDGET := 430000
const TREE_TARGET := 1400
const GRASS_TARGET := 520
const SHRUB_LIMIT := 400
const TREE_SPACING_M := 14.0
const MAX_BAND_DEPTH_M := 260.0
const IPO_SHARE := 0.55

## Tropical Sao Paulo storm (approved): a tall bright cumulonimbus deck, hazy
## reservoir horizon and 70% storm probability (wet asphalt, lake humidity).
## DAY / SUNSET / NIGHT; colours match the approved ToonLook.
const PROFILES: Array[Dictionary] = [
	{"sun": Color("#fff6df"), "sun_energy": 1.15, "sun_pitch": 52.0, "sun_yaw": -118.0, "ambient": Color("#d5e7e4"), "ambient_energy": 0.28, "fog": Color("#cbe2e0"), "fog_density": 0.00008, "sky_top": Color("#4f9fd8"), "sky_horizon": Color("#cfe8ee"), "ground": Color("#3d5233")},
	{"sun": Color("#ff9f63"), "sun_energy": 0.75, "sun_pitch": 14.0, "sun_yaw": -104.0, "ambient": Color("#e6b48f"), "ambient_energy": 0.32, "fog": Color("#e9c39a"), "fog_density": 0.00016, "sky_top": Color("#8a6f9e"), "sky_horizon": Color("#f8c28c"), "ground": Color("#5d4a33")},
	{"sun": Color("#9cb6d9"), "sun_energy": 0.38, "sun_pitch": 40.0, "sun_yaw": 92.0, "ambient": Color("#5f7ba4"), "ambient_energy": 0.23, "fog": Color("#182639"), "fog_density": 0.00035, "sky_top": Color("#091426"), "sky_horizon": Color("#243a50"), "ground": Color("#05080f")},
]

var terrain
var line: Line
var shared_sky: SkyController
var kerbs: Array[Dictionary] = []
var runoff_plans: Array[Dictionary] = []
var _stats: Dictionary = {}

var _compiled: Dictionary
var _segments: Array = Strip.SEGMENTS
var _rng := RandomNumberGenerator.new()
var _landmark_records: Array[Dictionary] = []
var _exclusion: Array = [] # [Vector2 centre, radius]
var _world_environment: WorldEnvironment
var _sun: DirectionalLight3D
var _camera: Camera3D
var _tod: Dictionary = {"mode": 0, "floodlights": 0.0, "stars_opacity": 0.0}
var _gloom: float = 0.0
var _screens: Array = []
var _wind_materials: Array[ShaderMaterial] = []
var _glow_materials: Array[ShaderMaterial] = []
var _light_level: float = -1.0
var _water_material: ShaderMaterial
var _water_time: float = 0.0
var _sky_rig := WorldSkyRig.new()


func _init() -> void:
	circuit_id = Layout.CIRCUIT_ID
	_sky_rig.aces_tonemap = false
	_sky_rig.fog_sky_affect = 0.35


func build(p_ribbon: TrackRibbonScript, source: Variant = null) -> void:
	if built:
		return
	ribbon = p_ribbon
	_rng.seed = 20261031
	_compiled = _compiled_from(source)
	if _compiled.is_empty():
		push_warning("paulistano-env: no compiled track data")
		built = true
		return
	var started := Time.get_ticks_msec()
	line = Line.new(ribbon)
	_build_corridor()
	terrain = TerrainField.new(_compiled)
	_add_terrain()
	_build_reservoir()
	_build_paddock_apron()
	_build_exclusions()
	_build_landmarks()
	_build_paddock_dressing()
	_build_woodland()
	_build_meadow()
	_build_chaparral()
	_build_boulders()
	_build_lake_mist()
	_finish(started)


func _compiled_from(source: Variant) -> Dictionary:
	if source is Dictionary and (source as Dictionary).has("points"):
		return source as Dictionary
	if source != null:
		var embedded: Variant = source.get("compiled")
		if embedded is Dictionary and (embedded as Dictionary).has("points"):
			return embedded as Dictionary
	if ribbon == null or ribbon.curve == null:
		return {}
	var points := PackedVector3Array()
	for i: int in range(ribbon.curve.point_count - 1):
		points.append(ribbon.curve.get_point_position(i))
	return {"points": points, "step_m": ribbon.length_m / float(maxi(1, points.size())), "length_m": ribbon.length_m}


## Tier A: shared corridor kit (asphalt, kerbs, runoff, groove, Armco, Tecpro,
## braking boards, flag panels) and the shipped FIA paddock pieces are built by
## the circuit's PitComplex; the catch fence reads the same furniture extents.
func _build_corridor() -> void:
	for i: int in range(0, ceili(ribbon.length_m), 2):
		var s := float(i)
		var curvature := ribbon.get_curvature_at(s)
		if absf(curvature) >= 0.006:
			if not kerbs.is_empty() and is_equal_approx(signf(float(kerbs[-1].side)), signf(curvature)) and s - float(kerbs[-1].s1) < 6.0:
				kerbs[-1]["s1"] = s + 2.0
			elif kerbs.is_empty() or float(kerbs[-1].s1) - float(kerbs[-1].s0) >= 14.0 or s - float(kerbs[-1].s1) >= 6.0:
				kerbs.append({"s0": s, "s1": s + 2.0, "side": signf(curvature)})
	# Keep only real corner runs, at least 14 m long.
	var runs: Array[Dictionary] = []
	for run: Dictionary in kerbs:
		if float(run["s1"]) - float(run["s0"]) >= 14.0:
			runs.append(run)
	kerbs = runs
	_add_kerb_group("SawtoothKerbsPaulistano", kerbs, ribbon.road_half_width_m - Surface.KERB_INSET_M, Surface.KERB_RED)
	var zone := PitZone.from_layout(_pit_layout(), ribbon.length_m, 70.0, 70.0)
	runoff_plans = Surface.plan_runoffs(ribbon, kerbs, float(zone.start_s), float(zone.length_m), PitZone.side_of(zone))
	var mesh := Surface.runoff_mesh(ribbon, runoff_plans)
	if mesh != null and mesh.get_surface_count() >= 3:
		mesh.surface_set_material(0, Toon.make(Surface.RUNOFF_COLOR))
		mesh.surface_set_material(1, Toon.make(Surface.WARNING_BLUE))
		mesh.surface_set_material(2, Toon.make(Color("#f0f2f5")))
		_add_mesh("TarmacRunoff", mesh)
	mesh = Surface.gravel_mesh(ribbon, runoff_plans)
	if mesh != null:
		mesh.surface_set_material(0, Toon.make(Surface.GRAVEL_COLOR))
		_add_mesh("GravelTraps", mesh)
	add_child(Surface.groove_instance(ribbon, line, 1.0))
	furniture = FurnitureScript.new()
	furniture.name = "TracksideFurniture"
	add_child(furniture)
	furniture.build(ribbon, line, kerbs, runoff_plans, _hero_zones(), zone)
	flag_panels = furniture.flag_panels
	Fence.build(self, ribbon, furniture, kerbs)
	shared_sky = SkyController.new()
	shared_sky.build(self, ribbon, 20261031)
	var pit := get_parent().get_node_or_null("PitLane")
	if pit != null:
		var stand := pit.get_node_or_null("MainGrandstand")
		if stand != null:
			var screen := stand.find_child("Jumbotron", true, false)
			if screen != null:
				_screens.append(screen)
	for node: Node in find_children("*", "MultiMeshInstance3D", true, false):
		var instance := node as MultiMeshInstance3D
		if instance.material_override is ShaderMaterial and (instance.material_override as ShaderMaterial).shader == TreeWindShader:
			_wind_materials.append(instance.material_override)
	_collect_glow_materials(self)
	if pit != null:
		_collect_glow_materials(pit)


func _pit_layout() -> Dictionary:
	var pit := get_parent().get_node_or_null("PitLane") if get_parent() != null else null
	if pit != null and pit.has_method("sim_layout"):
		return pit.call("sim_layout")
	return {"entry_s": Layout.PIT_ENTRY_S, "exit_s": Layout.PIT_EXIT_S, "lane_length_m": Layout.PIT_LANE_LENGTH_M, "stall_pitch_m": Layout.PIT_STALL_PITCH_M, "stall_lane_m": Layout.PIT_SIDE * Layout.PIT_SERVICE_X}


## Hero zones push the floodlight towers back where a tower behind the rail would
## stand in something: the left pit lane and paddock (rail open, towers at 15 m
## would land in the lane), the main grandstand on the right (s -70..170, roof to
## 58 m), and the Senna terrace outside T1 (78..134 m).
func _hero_zones() -> Array[Dictionary]:
	var lap: float = ribbon.length_m if ribbon != null else Layout.LENGTH_M
	return [
		{"side": Layout.PIT_SIDE, "s0": Layout.PIT_ENTRY_S - 70.0, "s1": lap + Layout.PIT_EXIT_S + 70.0, "lateral": 75.0},
		{"side": 1.0, "s0": lap + Layout.GRANDSTAND_ANCHOR_S - Layout.GRANDSTAND_LENGTH_M * 0.5 - 10.0, "s1": lap + Layout.GRANDSTAND_ANCHOR_S + Layout.GRANDSTAND_LENGTH_M * 0.5 + 10.0, "lateral": 64.0},
		{"side": 1.0, "s0": Layout.LANDMARK_SENNA_S - 72.0, "s1": Layout.LANDMARK_SENNA_S + 72.0, "lateral": 140.0},
	]


func _add_kerb_group(node_name: String, runs: Array[Dictionary], inset: float, color: Color) -> void:
	if runs.is_empty():
		return
	var mesh: ArrayMesh = Surface.kerb_mesh(ribbon, runs, inset)
	if mesh == null:
		return
	mesh.surface_set_material(0, Toon.make(color))
	mesh.surface_set_material(1, Toon.make(Surface.KERB_WHITE))
	_add_mesh(node_name, mesh)


func _add_mesh(node_name: String, mesh: Mesh) -> void:
	var node := MeshInstance3D.new()
	node.name = node_name
	node.mesh = mesh
	add_child(node)


func bind_world(world_environment: WorldEnvironment, sun: DirectionalLight3D, camera: Camera3D) -> void:
	_world_environment = world_environment
	_sun = sun
	_camera = camera
	if camera != null:
		camera.far = maxf(camera.far, 5000.0)
	if sun != null:
		sun.shadow_enabled = true
		sun.shadow_blur = 1.6
	apply_time_of_day(_tod, _gloom)


func apply_time_of_day(tod: Dictionary, gloom: float = 0.0) -> void:
	_tod = tod
	_gloom = gloom
	var mode := SkyController.mode_of(tod)
	_sky_rig.apply(_world_environment, _sun, PROFILES[mode], gloom, Color("#8d8478"))
	if shared_sky != null:
		shared_sky.apply_time_of_day(tod, gloom)
		if shared_sky.cloud_material != null:
			shared_sky.cloud_material.set_shader_parameter("cloud_shadow", [Color("#8fa9b0"), Color("#9a7280"), Color("#141d33")][mode])
			shared_sky.cloud_material.set_shader_parameter("cloud_mid", [Color("#f2f7f6"), Color("#efae7c"), Color("#35486b")][mode])
			shared_sky.cloud_material.set_shader_parameter("cloud_rim", [Color("#ffffff"), Color("#ffd9a8"), Color("#b8e4ff")][mode])
	# The approved tropical storm look is FILMIC, not ACES: a bright cumulonimbus deck,
	# volumetric reservoir haze and a brighter sky dome; match the sandbox ToonLook.
	if _world_environment != null and _world_environment.environment != null:
		var env := _world_environment.environment
		env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
		env.tonemap_exposure = 1.02
		env.volumetric_fog_enabled = true
		env.volumetric_fog_density = [0.0008, 0.0014, 0.004][mode]
		env.volumetric_fog_albedo = Color("#c9d3d5")
		env.volumetric_fog_length = 2600.0
		env.adjustment_enabled = true
		env.adjustment_saturation = 1.02
		env.adjustment_contrast = 1.05
		env.adjustment_brightness = 1.0
		if env.sky != null and env.sky.sky_material is ProceduralSkyMaterial:
			var sky_material := env.sky.sky_material as ProceduralSkyMaterial
			sky_material.sun_angle_max = 0.0
			sky_material.sky_energy_multiplier = [1.35, 1.18, 1.0][mode]
	if _water_material != null:
		_water_material.set_shader_parameter("deep_color", [Color("#0b3d4c"), Color("#2f2c48"), Color("#061a2b")][mode])
		_water_material.set_shader_parameter("shallow_color", [Color("#3f7c6b"), Color("#8a6a5c"), Color("#13334a")][mode])
		_water_material.set_shader_parameter("band_color", [Color("#1b5f6c"), Color("#5a4566"), Color("#0e2b42")][mode])
		_water_material.set_shader_parameter("foam_color", [Color("#eef4f0"), Color("#ffd9b8"), Color("#9fc4d8")][mode])
		_water_material.set_shader_parameter("glow", [0.0, 0.15, 0.35][mode])
	var floodlights := float(tod.get("floodlights", 0.0))
	if not is_equal_approx(_light_level, floodlights):
		_light_level = floodlights
		Toon.set_glow_energy(floodlights * 0.8)
		for material: ShaderMaterial in _glow_materials:
			material.set_shader_parameter("glow_energy", floodlights * 0.8)
	var pit := get_parent().get_node_or_null("PitLane") if get_parent() != null else null
	if pit != null and pit.has_method("set_lights_on"):
		pit.call("set_lights_on", floodlights > 0.1)


func apply_wind(delta: float, wind_kph: float, wind_dir: float) -> void:
	if shared_sky != null:
		shared_sky.apply_wind(delta, wind_kph)
	for material: ShaderMaterial in _wind_materials:
		material.set_shader_parameter("wind_strength", clampf(wind_kph / 100.0, 0.04, 0.5))
		material.set_shader_parameter("wind_direction", Vector2(cos(wind_dir), sin(wind_dir)))


func update(delta: float, race) -> void:
	if race == null:
		return
	var weather = race.weather
	apply_time_of_day(weather.time_of_day, maxf(sqrt(weather.rain_intensity), weather.track_water_pct / 100.0))
	apply_wind(delta, weather.wind_speed, weather.wind_direction)
	if _water_material != null:
		_water_time += delta
		_water_material.set_shader_parameter("time_s", _water_time)
		_water_material.set_shader_parameter("wind_speed_kph", float(weather.wind_speed))
	_feed_leaderboards(delta, race, _screens)


## Top of the solid ground: the terrain, or the paddock apron slab where it covers it
## (the terrain under the paddock is lowered to the -0.58 m building pad on purpose).
func ground_y_at(pos: Vector3) -> float:
	if terrain == null:
		return pos.y
	var ground: float = terrain.height_at(pos.x, pos.z)
	var hit: Dictionary = terrain.track_query(pos.x, pos.z, 80.0)
	if hit.is_empty():
		return ground
	var s: float = fposmod(float(hit["s"]), Layout.LENGTH_M)
	var frame: Transform3D = ribbon.call("get_point_at_offset", s, 0.0)
	var lateral: float = (pos - frame.origin).dot(frame.basis.x)
	for spec: Array in Layout.PADDOCK_APRON_SPECS:
		var along: float = lateral * float(spec[0])
		if s >= float(spec[1]) and s <= float(spec[2]) and along >= float(spec[3]) and along <= float(spec[4]):
			ground = maxf(ground, frame.origin.y + Layout.PADDOCK_APRON_LIFT_M)
	return ground


func _extra_stats() -> Dictionary:
	var result: Dictionary = _stats.duplicate()
	result["kerb_runs"] = kerbs.size()
	return result


func _collect_glow_materials(node: Node) -> void:
	if node is MeshInstance3D:
		var instance := node as MeshInstance3D
		if instance.mesh != null:
			for index: int in range(instance.mesh.get_surface_count()):
				var material := instance.get_active_material(index) as ShaderMaterial
				if material != null and material.shader != null and "glow_energy" in material.shader.code:
					_glow_materials.append(material)
	elif node is MultiMeshInstance3D:
		var multi := node as MultiMeshInstance3D
		if multi.material_override is ShaderMaterial:
			_glow_materials.append(multi.material_override)
	for child: Node in node.get_children():
		_collect_glow_materials(child)


# --- terrain ---------------------------------------------------------------------------

func _add_terrain() -> void:
	var node := MeshInstance3D.new()
	node.name = "Terrain"
	node.mesh = terrain.terrain_mesh
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	node.set_meta("heightgrid", terrain.heightgrid)
	add_child(node)
	var skirt := MeshInstance3D.new()
	skirt.name = "TerrainSkirt"
	skirt.mesh = terrain.skirt_mesh
	skirt.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(skirt)
	var base := MeshInstance3D.new()
	base.name = "TerrainBase"
	var plane := PlaneMesh.new()
	plane.size = Vector2(8000.0, 8000.0)
	base.mesh = plane
	base.position.y = float(terrain.heightgrid.get("base_y", -28.0))
	base.material_override = Toon.make(Color("#33402d"))
	base.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(base)
	var ridge := MeshInstance3D.new()
	ridge.name = "DistantRidge"
	ridge.mesh = terrain.ridge_mesh
	ridge.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(ridge)
	set_meta("heightgrid", terrain.heightgrid)


# --- paddock apron -----------------------------------------------------------------------

## Graded concrete apron over the paddock terraces. The terrain below is deliberately
## lowered (the 12 m grid can then never poke through a garage or the stand); this
## slab follows the road grade at 2 m steps so the working surface is perfectly
## smooth, and a retaining wall closes the outer edge into the laterite slope.
func _build_paddock_apron() -> void:
	var specs: Array = Layout.PADDOCK_APRON_SPECS
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var walls := SurfaceTool.new()
	walls.begin(Mesh.PRIMITIVE_TRIANGLES)
	var quads := 0
	var wall_quads := 0
	for spec: Array in specs:
		var side: float = float(spec[0])
		var s: float = float(spec[1])
		var finish: float = float(spec[2])
		var lat0: float = float(spec[3])
		var lat1: float = float(spec[4])
		var previous_inner := Vector3.INF
		var previous_outer := Vector3.INF
		var previous_top := Vector3.INF
		var previous_bottom := Vector3.INF
		var previous_inner_top := Vector3.INF
		var previous_inner_bottom := Vector3.INF
		while s <= finish:
			var frame: Transform3D = ribbon.call("get_point_at_offset", fposmod(s, Layout.LENGTH_M), 0.0)
			var right := frame.basis.x
			var inner := frame.origin + right * (side * lat0)
			var outer := frame.origin + right * (side * lat1)
			inner.y = frame.origin.y + 0.02
			outer.y = frame.origin.y + 0.02
			if previous_inner != Vector3.INF:
				_quad_color(surface, previous_inner, previous_outer, outer, inner, Vector3.UP, Color("#8f9390"))
				quads += 1
			# Retaining edge: top kerb at the apron edge, face down to the natural ground.
			var edge := frame.origin + right * (side * lat1)
			var top := edge
			# Where a level terrace beside the slab stands higher than the graded apron, the wall rises
			# into a low parapet that holds the bank back instead of letting grass spill over the edge.
			var beyond: Vector3 = frame.origin + right * (side * (lat1 + 0.6))
			top.y = maxf(frame.origin.y + Layout.PADDOCK_APRON_LIFT_M, terrain.height_at(beyond.x, beyond.z) + 0.05)
			var bottom := Vector3(edge.x, _wall_foot(frame.origin.y + Layout.PADDOCK_APRON_LIFT_M, frame, side, lat1), edge.z)
			if previous_top != Vector3.INF:
				_face_quad(walls, previous_top, top, bottom, previous_bottom, Color("#6e726d"))
				wall_quads += 1
			# The grandstand apron stands 0.6 m above the lowered terrace; close its
			# track-side edge with a low wall so the slab never reads as floating.
			if side > 0.0:
				var inner_edge := frame.origin + right * (side * lat0)
				var inner_top := inner_edge
				inner_top.y = frame.origin.y + 0.02
				var inner_bottom := Vector3(inner_edge.x, inner_top.y - 0.9, inner_edge.z)
				if previous_inner_top != Vector3.INF:
					_face_quad(walls, previous_inner_top, inner_top, inner_bottom, previous_inner_bottom, Color("#6e726d"))
					wall_quads += 1
				previous_inner_top = inner_top
				previous_inner_bottom = inner_bottom
			previous_top = top
			previous_bottom = bottom
			previous_inner = inner
			previous_outer = outer
			s += 4.0
		# End caps where the slab really ends (not at the lap seam a slab continues across), cut in
		# 4 m panels whose feet reach the ground just beyond the end, so the end never hovers.
		for end: Array in [[float(spec[1]), -1.0], [float(spec[2]), 1.0]]:
			if (float(end[1]) < 0.0 and float(spec[1]) <= 0.0) or (float(end[1]) > 0.0 and float(spec[2]) >= Layout.LENGTH_M):
				continue
			var end_frame: Transform3D = ribbon.call("get_point_at_offset", fposmod(float(end[0]), Layout.LENGTH_M), 0.0)
			var top_y: float = end_frame.origin.y + Layout.PADDOCK_APRON_LIFT_M
			var along: Vector3 = -end_frame.basis.z * float(end[1])
			var lat: float = lat0
			while lat < lat1:
				var next_lat: float = minf(lat + 4.0, lat1)
				var a: Vector3 = end_frame.origin + end_frame.basis.x * (side * lat)
				var b: Vector3 = end_frame.origin + end_frame.basis.x * (side * next_lat)
				a.y = _cap_top(top_y, a + along * 0.6)
				b.y = _cap_top(top_y, b + along * 0.6)
				var a_low := Vector3(a.x, _cap_foot(top_y, a + along * 0.6), a.z)
				var b_low := Vector3(b.x, _cap_foot(top_y, b + along * 0.6), b.z)
				_face_quad(walls, a, b, b_low, a_low, Color("#6e726d"))
				wall_quads += 1
				lat = next_lat
	var mesh: ArrayMesh = surface.commit()
	if mesh != null:
		var node := MeshInstance3D.new()
		node.name = "PaddockApron"
		node.mesh = mesh
		node.material_override = Toon.vertex_colored(false)
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(node)
	var wall_mesh: ArrayMesh = walls.commit()
	if wall_mesh != null:
		var wall := MeshInstance3D.new()
		wall.name = "PaddockRetainingWall"
		wall.mesh = wall_mesh
		wall.material_override = Toon.vertex_colored(false)
		wall.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		add_child(wall)
	_stats["paddock_apron_quads"] = quads
	_stats["paddock_wall_quads"] = wall_quads


## One outward-facing retaining wall quad (previous top, top, bottom, previous bottom).
func _face_quad(st: SurfaceTool, top_a: Vector3, top_b: Vector3, bottom_b: Vector3, bottom_a: Vector3, color: Color) -> void:
	for vertex: Vector3 in [top_a, top_b, bottom_b, top_a, bottom_b, bottom_a, top_a, bottom_b, top_b, top_a, bottom_a, bottom_b]:
		st.set_color((color).srgb_to_linear())
		st.add_vertex(vertex)


# --- hero landmarks --------------------------------------------------------------------

## Frozen Tier B stations (procedural-spec section 4). Asset convention (from the
## GLB author): ground at y=0, centred on the origin within its footprint; the
## body extends into +X (away from the track) and the long axis is local Z.
func _landmark_specs() -> Array:
	return [
		{"stem": "paulistano_senna_monument_terrace", "s": Layout.LANDMARK_SENNA_S, "side": 1.0,
			"offset": Layout.LANDMARK_SENNA_OFFSET_M, "length": 140.0, "depth": 45.0, "local_z": 0.0,
			"anchor": "ground", "pier_half": 0.0,
			"note": "terraced Senna S amphitheatre outside T1 with the yellow-green Brazilian canopy"},
		{"stem": "paulistano_kartodromo_overlook", "s": Layout.LANDMARK_KARTODROMO_S, "side": -1.0,
			"offset": Layout.LANDMARK_KARTODROMO_OFFSET_M, "length": 180.0, "depth": 110.0, "local_z": 0.0,
			"anchor": "terrain", "pier_half": 0.0,
			"note": "Ayrton Senna kartodromo complex on the infield plateau, paddock tents and karts"},
		{"stem": "paulistano_guarapiranga_reservoir", "s": Layout.LANDMARK_RESERVOIR_S, "side": 1.0,
			"offset": Layout.LANDMARK_RESERVOIR_OFFSET_M, "length": 450.0, "depth": 280.0, "local_z": 0.0,
			"anchor": "waterline", "pier_half": 0.0,
			"note": "Represa de Guarapiranga seawall promenade, sailing pontoons and moored boats"},
		{"stem": "paulistano_historic_paddock_tower", "s": Layout.LANDMARK_TOWER_S, "side": -1.0,
			"offset": Layout.LANDMARK_TOWER_OFFSET_M, "length": 25.0, "depth": 22.0, "local_z": 0.0,
			"anchor": "ground", "pier_half": 0.0,
			"note": "1970s Brutalist concrete race-control tower on the Subida dos Boxes climb"},
	]


func _model_frame(spec: Dictionary) -> Transform3D:
	var s := float(spec["s"])
	var lateral := float(spec.get("lat_override", spec["offset"]))
	var frame := Layout.side_frame(ribbon, s, float(spec["side"]), lateral)
	# Architecture sits level: keep the frame heading but drop the road pitch, so a
	# 160 m stand is not tilted along the gradient and its base never lifts.
	var flat_forward := Vector3(-frame.basis.z.x, 0.0, -frame.basis.z.z)
	if flat_forward.length_squared() < 0.0001:
		flat_forward = Vector3.FORWARD
	flat_forward = flat_forward.normalized()
	var level_basis := Basis(flat_forward.cross(Vector3.UP).normalized(), Vector3.UP, -flat_forward)
	match String(spec["anchor"]):
		"deck":
			# Sit the deck on the lowest ground under either pier so no support floats.
			var g: float = terrain.height_at(frame.origin.x, frame.origin.z)
			var pier_half := float(spec.get("pier_half", 17.0))
			for sign: float in [-1.0, 1.0]:
				var pier := frame.origin + frame.basis.x * (sign * pier_half)
				g = minf(g, terrain.height_at(pier.x, pier.z))
			frame.origin.y = g + 0.02
		"waterline":
			# The reservoir GLB is authored around its waterline (hulls and pontoons at local y -7.25).
			frame.origin.y = float(terrain.heightgrid.get("promenade_y", frame.origin.y))
		"terrain":
			frame.origin.y = terrain.height_at(frame.origin.x, frame.origin.z) - 0.05
		_:
			# Terraces are cut at road bed level; ground the slab exactly there.
			frame.origin.y = _road_y(s) - Layout.ROADBED_DROP_M + 0.02
	var shift := level_basis.z * float(spec.get("local_z", 0.0))
	return Transform3D(level_basis, frame.origin + shift)


func _build_exclusions() -> void:
	for spec: Dictionary in _landmark_specs():
		var lateral := float(spec.get("lat_override", spec["offset"]))
		var frame := Layout.side_frame(ribbon, float(spec["s"]), float(spec["side"]), lateral)
		var length_m := float(spec["length"])
		var depth_m := float(spec["depth"])
		# A long stand is cleared by a chain of small circles, not one huge disc, so
		# the forest can grow right up to the concourse.
		var count := maxi(1, ceili(length_m / 30.0))
		var radius := depth_m * 0.5 + 10.0
		var body_centre := frame.origin + frame.basis.x * (depth_m * 0.5)
		for index in range(count):
			var t := (float(index) + 0.5) / float(count) - 0.5
			var at := body_centre + frame.basis.z * (t * length_m)
			_exclusion.append([Vector2(at.x, at.z), radius])
	# Keep the sight lines from the track to the hero landmarks clear of trees.
	for view: Array in [
		[Layout.LANDMARK_SENNA_S, 1.0, 100.0, 62.0],
		[Layout.LANDMARK_KARTODROMO_S, -1.0, 150.0, 74.0],
		[Layout.LANDMARK_RESERVOIR_S, 1.0, 90.0, 82.0],
		[Layout.LANDMARK_TOWER_S, -1.0, 34.0, 40.0],
	]:
		var mid := Layout.side_frame(ribbon, float(view[0]), float(view[1]), float(view[2]))
		_exclusion.append([Vector2(mid.origin.x, mid.origin.z), float(view[3])])


func _build_landmarks() -> void:
	var holder := Node3D.new()
	holder.name = "HeroLandmarks"
	add_child(holder)
	for spec: Dictionary in _landmark_specs():
		_place_model(holder, spec, _model_frame(spec))


func _place_model(parent: Node3D, spec: Dictionary, xform: Transform3D) -> void:
	var stem := String(spec["stem"])
	var path := "%s/%s.glb" % [ASSET_DIR, stem]
	var record := {
		"id": stem,
		"glb": path,
		"s": float(spec["s"]),
		"side": "R" if float(spec["side"]) > 0.0 else "L",
		"offset_m": float(spec["offset"]),
		"placed_lateral_m": float(spec.get("lat_override", spec["offset"])),
		"anchor": String(spec["anchor"]),
		"note": String(spec["note"]),
		"placed": false,
	}
	if not FileAccess.file_exists(path):
		push_warning("paulistano-env: missing hero landmark %s (skipped, no proxy box)" % path)
		_landmark_records.append(record)
		return
	var model := _load_model(stem)
	if model == null:
		push_warning("paulistano-env: cannot read %s" % path)
		_landmark_records.append(record)
		return
	model.name = stem
	model.transform = xform
	parent.add_child(model)
	record["placed"] = true
	record["triangles"] = _mesh_triangles(model)
	record["position"] = [snappedf(xform.origin.x, 0.01), snappedf(xform.origin.y, 0.01), snappedf(xform.origin.z, 0.01)]
	_landmark_records.append(record)


func _load_model(stem: String) -> Node3D:
	var path := "%s/%s.glb" % [ASSET_DIR, stem]
	var doc := GLTFDocument.new()
	var state := GLTFState.new()
	if doc.append_from_file(ProjectSettings.globalize_path(path), state) != OK:
		return null
	return doc.generate_scene(state) as Node3D


# --- paddock dressing ------------------------------------------------------------------

func _build_paddock_dressing() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var tents := 0
	var transporters := 0
	var vehicles := 0
	var motorhomes := 0
	var generators := 0
	# Solid team hospitality tents (walls + floor, not floating roofs) on the terrace
	# along the main straight and the Subida dos Boxes apron.
	for station: float in [40.0, 90.0, 140.0, 190.0, 240.0, 290.0]:
		var frame := _paddock_frame(station, 38.0)
		var color: Color = Liveries.color_for(tents)
		_box(st, frame, Vector3(0.0, 0.05, 0.0), Vector3(12.0, 0.1, 8.0), Color("#d9d7cf"))
		_box(st, frame, Vector3(0.0, 1.45, -3.9), Vector3(12.0, 2.9, 0.16), Color("#e8e6de"))
		for side: float in [-1.0, 1.0]:
			_box(st, frame, Vector3(side * 5.9, 1.45, 0.0), Vector3(0.16, 2.9, 8.0), Color("#e8e6de"))
		_box(st, frame, Vector3(0.0, 3.0, 0.0), Vector3(12.4, 0.3, 8.4), color.lightened(0.2))
		for corner: Vector2 in [Vector2(-5.4, -3.4), Vector2(5.4, -3.4), Vector2(-5.4, 3.4), Vector2(5.4, 3.4)]:
			_box(st, frame, Vector3(corner.x, 1.5, corner.y), Vector3(0.18, 3.0, 0.18), Color("#d7dade"))
		_box(st, frame, Vector3(0.0, 0.75, -2.6), Vector3(5.2, 0.9, 1.0), Color("#3a3f4a"))
		_box(st, frame, Vector3(2.4, 1.35, -2.6), Vector3(1.8, 0.3, 0.8), color)
		_box(st, frame, Vector3(3.8, 3.7, 1.8), Vector3(1.4, 1.1, 1.0), Color("#9aa1ae"))
		tents += 1
	# One team transporter per garage, parked in the working lane behind the block.
	for index in range(10):
		var station := 20.0 + float(index) * 14.0
		var frame := _paddock_frame(station, 40.0)
		var color: Color = Liveries.color_for(index)
		_box(st, frame, Vector3(0.0, 1.75, 0.0), Vector3(4.6, 3.5, 12.0), Color("#e6e8ec"))
		_box(st, frame, Vector3(0.0, 2.45, 0.0), Vector3(4.65, 0.5, 12.0), color)
		_box(st, frame, Vector3(0.0, 3.3, 0.0), Vector3(4.8, 0.25, 12.4), Color("#9aa1ae"))
		_box(st, frame, Vector3(2.36, 1.55, 0.0), Vector3(0.08, 1.4, 10.8), Color("#b9c0cc"))
		transporters += 1
	# Motorhomes / hospitality units along the paddock boulevard.
	for index in range(8):
		var station: float = 205.0 + float(index % 4) * 19.0 if index < 4 else 25.0 + float(index - 4) * 34.0
		var frame := _paddock_frame(station, 40.0)
		var color: Color = Liveries.color_for(index + 2)
		_box(st, frame, Vector3(0.0, 1.8, 0.0), Vector3(3.2, 3.6, 9.0), Color("#eceae2"))
		_box(st, frame, Vector3(0.0, 2.65, 0.0), Vector3(3.24, 0.45, 9.0), color)
		_box(st, frame, Vector3(1.62, 2.0, -1.2), Vector3(0.05, 1.1, 3.2), Color("#4f7fa8"))
		_box(st, frame, Vector3(-1.62, 2.0, 1.2), Vector3(0.05, 1.1, 3.2), Color("#4f7fa8"))
		motorhomes += 1
	# Parked support vehicles / golf carts along the post-garage apron.
	for index in range(6):
		var station := 190.0 + float(index) * 11.0
		var frame := _paddock_frame(station, 30.0)
		var color: Color = Liveries.color_for(index + 4)
		_box(st, frame, Vector3(0.0, 0.75, 0.0), Vector3(1.9, 1.2, 4.4), color)
		_box(st, frame, Vector3(0.0, 1.55, -0.4), Vector3(1.7, 0.9, 2.0), color.darkened(0.2))
		vehicles += 1
	# Generator / fuel units in the service lane behind the garages.
	for station: float in [40.0, 75.0, 110.0, 145.0]:
		var frame := _paddock_frame(station, 36.0)
		_box(st, frame, Vector3(0.0, 0.8, 0.0), Vector3(2.4, 1.6, 3.6), Color("#6f7680"))
		_box(st, frame, Vector3(0.0, 1.65, 0.0), Vector3(2.5, 0.12, 3.7), Color("#3a3f4a"))
		_box(st, frame, Vector3(1.22, 0.9, 0.0), Vector3(0.05, 0.9, 2.2), Color("#ffd400"))
		generators += 1
	# Helipad circle on the paddock apron.
	var pad_centre := _paddock_frame(262.0, 33.0).origin + Vector3.UP * 0.02
	_disc(st, pad_centre, 9.0, 24, Color("#3d4249"))
	_disc(st, pad_centre + Vector3.UP * 0.01, 8.0, 24, Color("#2f6b46"))
	var pad_frame := _paddock_frame(262.0, 33.0)
	for offset: Vector3 in [Vector3(-1.25, 0.0, 0.0), Vector3(1.25, 0.0, 0.0)]:
		_box(st, pad_frame, offset + Vector3.UP * 0.05, Vector3(0.7, 0.05, 5.0), Color("#f2f4f6"))
	_box(st, pad_frame, Vector3(0.0, 0.05, 0.0), Vector3(2.2, 0.05, 0.7), Color("#f2f4f6"))
	var grounds := _build_paddock_grounds(st)
	var mesh := st.commit()
	if mesh != null:
		var node := MeshInstance3D.new()
		node.name = "PaddockDressing"
		node.mesh = mesh
		node.material_override = Toon.vertex_colored(false)
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		add_child(node)
	# Paddock crowd: 120 figures on the apron and boulevard, never in the lane,
	# the garages or the helipad.
	var crowd := MeshBatchScript.new()
	var crowd_flat: ShaderMaterial = Toon.vertex_colored(false)
	var roles: Array = PitKit.standby_roles()
	var placed_people := 0
	var attempts := 0
	while placed_people < 120 and attempts < 900:
		attempts += 1
		var station := _rng.randf_range(5.0, 295.0)
		var lateral := _rng.randf_range(22.0, 40.0)
		var local_s := fposmod(station, Layout.LENGTH_M)
		if local_s >= 20.0 and local_s <= 160.0 and lateral < 34.0:
			continue
		if local_s >= 4180.0 and local_s <= 4260.0 and lateral < 60.0:
			continue
		if Vector2(station - 262.0, lateral - 33.0).length() < 11.0:
			continue
		var frame: Transform3D = ribbon.call("get_point_at_offset", station, Layout.PIT_SIDE * lateral)
		# Feet stand on the graded apron; the terrain below it is deliberately 0.58 m lower.
		var ground := frame.origin.y + 0.03
		var yaw := _rng.randf() * TAU
		PitCrewFigureScript.add(crowd, crowd_flat, Transform3D(Basis(Vector3.UP, yaw), Vector3(frame.origin.x, ground, frame.origin.z)), int(roles[placed_people % roles.size()]), Liveries.color_for(placed_people % 10))
		placed_people += 1
	var crowd_node := MeshInstance3D.new()
	crowd_node.name = "PaddockCrowd"
	crowd_node.mesh = crowd.commit()
	crowd_node.material_override = crowd_flat
	crowd_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(crowd_node)
	_stats["paddock_tents"] = tents
	_stats["paddock_transporters"] = transporters
	_stats["paddock_motorhomes"] = motorhomes
	_stats["paddock_vehicles"] = vehicles
	_stats["paddock_generators"] = generators
	_stats["paddock_people"] = placed_people
	_stats["paddock_parking_cars"] = int(grounds["cars"])
	_stats["paddock_palms"] = int(grounds["palms"])
	_stats["paddock_umbrellas"] = int(grounds["umbrellas"])
	_stats["paddock_boards"] = int(grounds["boards"])
	_stats["helipad"] = true


## Paddock grounds: parked cars, palms, fan-zone umbrellas and sponsor boards so
## the wide apron around the pit block is not a bare slab.
func _build_paddock_grounds(st: SurfaceTool) -> Dictionary:
	var cars := 0
	var palms := 0
	var umbrellas := 0
	var boards := 0
	# Two parking rows on the outer apron (stations wrap across the start line).
	for index in range(12):
		_car(st, _paddock_frame(20.0 + float(index) * 20.0, 30.0), Liveries.color_for(index))
		cars += 1
	for index in range(13):
		_car(st, _paddock_frame(18.0 + float(index) * 20.0, 36.0), Liveries.color_for(index + 3))
		cars += 1
	# White bay lines between the parked cars.
	for row: float in [30.0, 36.0]:
		for index in range(13):
			var line_s: float = 12.0 + float(index) * 20.0
			var line := _paddock_frame(line_s, row - 1.6)
			_box(st, line, Vector3(0.0, 0.02, 0.0), Vector3(4.0, 0.02, 0.16), Color("#e8e6dc"))
	# Royal palm belt along the paddock boulevard (Mata Atlântica gateway).
	for station: float in [30.0, 78.0, 126.0, 174.0, 222.0, 270.0, 10.0, 54.0, 98.0]:
		_palm(st, _paddock_frame(station, 40.0), 8.5 + float(palms % 3) * 1.1)
		palms += 1
	# Umbrellas + tables around the hospitality tents.
	for index in range(12):
		var station: float = 210.0 + float(index % 6) * 9.0
		var frame := _paddock_frame(station, 33.0 + float(index % 3) * 3.5)
		_umbrella(st, frame, Liveries.color_for(index))
		umbrellas += 1
	# Sponsor boards on the apron, facing the track.
	for index in range(8):
		var station: float = 20.0 + float(index) * 18.0
		var frame := _paddock_frame(station, 38.0)
		var color: Color = Liveries.color_for(index + 1)
		_box(st, frame, Vector3(0.0, 1.0, 0.0), Vector3(0.10, 2.0, 0.10), Color("#5d6570"))
		_box(st, frame, Vector3(0.0, 2.4, 0.0), Vector3(0.16, 1.2, 4.2), color)
		_box(st, frame, Vector3(-0.10, 2.4, 0.0), Vector3(0.04, 0.35, 3.4), Color("#f4f5f7"))
		boards += 1
	return {"cars": cars, "palms": palms, "umbrellas": umbrellas, "boards": boards}


func _car(st: SurfaceTool, frame: Transform3D, color: Color) -> void:
	_box(st, frame, Vector3(0.0, 0.55, 0.0), Vector3(1.8, 0.7, 4.2), color)
	_box(st, frame, Vector3(0.0, 1.18, 0.2), Vector3(1.6, 0.6, 2.2), Color("#26333f"))
	_box(st, frame, Vector3(0.0, 1.19, 0.2), Vector3(1.62, 0.12, 2.24), color.lightened(0.15))


## Royal palm (Roystonea oleracea): a tall pale ringed trunk with a crown of
## eight drooping fronds, the landmark tree of the Guarapiranga shoreline.
func _palm(st: SurfaceTool, frame: Transform3D, height: float) -> void:
	_box(st, frame, Vector3(0.0, height * 0.5, 0.0), Vector3(0.42, height, 0.42), Color("#b9ab90"))
	_box(st, frame, Vector3(0.0, height * 0.72, 0.0), Vector3(0.5, 0.6, 0.5), Color("#8f7f63"))
	var top := frame * Vector3(0.0, height, 0.0)
	for index in range(8):
		var angle := TAU * float(index) / 8.0
		var mid := top + Vector3(cos(angle) * 2.1, 0.55, sin(angle) * 2.1)
		var tip := top + Vector3(cos(angle) * 3.5, -0.55, sin(angle) * 3.5)
		var side := Vector3(-sin(angle), 0.0, cos(angle)) * 0.42
		_quad_color(st, mid - side, mid + side, tip, tip, Vector3.UP, Color("#2f7a3b") if index % 2 == 0 else Color("#3a8f45"))
		_quad_color(st, top + Vector3(0.0, 0.15, 0.0), mid - side, mid + side, mid + side, Vector3.UP, Color("#245f2f"))
	_disc(st, top + Vector3.UP * 0.18, 0.5, 6, Color("#4c3f2a"))


func _umbrella(st: SurfaceTool, frame: Transform3D, color: Color) -> void:
	_box(st, frame, Vector3(0.0, 1.2, 0.0), Vector3(0.08, 2.4, 0.08), Color("#6d7480"))
	_disc(st, frame * Vector3(0.0, 2.6, 0.0), 1.7, 10, color)
	var top := frame * Vector3(0.0, 0.0, 0.0)
	_box(st, frame, Vector3(0.0, 0.38, 0.0), Vector3(0.12, 0.76, 0.12), Color("#6d7480"))
	_disc(st, top + Vector3.UP * 0.8, 0.7, 8, Color("#e8e2d4"))


func _paddock_frame(station: float, lateral: float) -> Transform3D:
	var frame: Transform3D = ribbon.call("get_point_at_offset", fposmod(station, Layout.LENGTH_M), Layout.PIT_SIDE * lateral)
	frame.origin.y = frame.origin.y + 0.03
	return frame


# --- urban plazas ----------------------------------------------------------------------

## Paved spectator plazas under the kit stands / floodlights. The slab follows the
## terrain height so nothing floats: it is grounded by construction.
func _build_urban_plazas() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var quads := 0
	for band: Dictionary in _segments:
		if String(band.get("zone", "")) != "urban":
			continue
		var side: float = -1.0 if String(band.get("side", "R")) == "L" else 1.0
		var s0: float = float(band["s0"])
		var s1: float = float(band["s1"])
		var inner_lat: float = float(band.get("band_offset_m", 20.0))
		var outer_lat := inner_lat + 42.0
		var color := Color("#666a70").lerp(Color("#7c7f84"), 0.55 + s0 / Layout.LENGTH_M * 0.1)
		var previous := PackedVector3Array()
		var s := s0
		while s <= s1:
			var inner: Vector3 = _lateral_point(s, side, inner_lat)
			var outer: Vector3 = _lateral_point(s, side, outer_lat)
			inner.y = terrain.height_at(inner.x, inner.z) + 0.045
			outer.y = terrain.height_at(outer.x, outer.z) + 0.045
			if previous.size() == 2:
				_quad_color(st, previous[0], previous[1], outer, inner, Vector3.UP, color)
				quads += 1
			previous = PackedVector3Array([inner, outer])
			s += 8.0
	if quads == 0:
		return
	var mesh := st.commit()
	if mesh == null:
		return
	var node := MeshInstance3D.new()
	node.name = "UrbanPlazas"
	node.mesh = mesh
	node.material_override = Toon.vertex_colored(false)
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(node)
	_stats["plaza_quads"] = quads


# --- woodland --------------------------------------------------------------------------

func _build_woodland() -> void:
	var ipe := _ipe_mesh(0.0)
	var palm := _royal_palm_mesh(1.7)
	var transforms := _forest_candidates()
	var ipes: Array[Transform3D] = []
	var palms: Array[Transform3D] = []
	for index in range(transforms.size()):
		if float(index % 100) < IPO_SHARE * 100.0:
			ipes.append(transforms[index])
		else:
			palms.append(transforms[index])
	var foliage := _foliage_holder()
	_add_multimesh(foliage, "MataAtlanticaIpeAmarelo", ipe, ipes, 14.0, 0.20)
	_add_multimesh(foliage, "MataAtlanticaRoyalPalm", palm, palms, 13.0, 0.24)
	_stats["tree_count"] = transforms.size()
	_stats["ipe_count"] = ipes.size()
	_stats["palm_count"] = palms.size()
	_stats["tree_triangles"] = ipes.size() * _surface_triangles(ipe) + palms.size() * _surface_triangles(palm)


func _forest_candidates() -> Array[Transform3D]:
	var out: Array[Transform3D] = []
	for band: Dictionary in _segments:
		var zone := String(band.get("zone", ""))
		if zone != "forest" and zone != "cliff" and zone != "grass" and zone != "paddock":
			continue
		var side: float = -1.0 if String(band.get("side", "R")) == "L" else 1.0
		var s0: float = float(band["s0"])
		var s1: float = float(band["s1"])
		var offset: float = float(band.get("band_offset_m", 18.0))
		var depth: float = minf(float(band.get("band_depth_m", 220.0)), MAX_BAND_DEPTH_M)
		var density: float = float(band.get("density", 0.7)) * (0.45 if zone == "grass" else (0.7 if zone == "paddock" else 1.0))
		var s := s0
		while s < s1:
			var lateral := offset + (70.0 if zone == "paddock" else 10.0)
			while lateral < offset + depth:
				if out.size() >= TREE_TARGET:
					return out
				if _rng.randf() < density * 0.9:
					var station := fposmod(s + _rng.randf_range(-6.8, 6.8), Layout.LENGTH_M)
					var lat := lateral + _rng.randf_range(-6.8, 6.8)
					var frame: Transform3D = ribbon.call("get_point_at_offset", station, side * lat)
					_try_tree(out, frame.origin)
				lateral += TREE_SPACING_M
			s += TREE_SPACING_M
	# Copses filling the middle-distance fields so the horizon is not bare.
	var attempts := 0
	while out.size() < TREE_TARGET and attempts < 7000:
		attempts += 1
		var x := _rng.randf_range(terrain.bbox.position.x + 40.0, terrain.bbox.position.x + terrain.bbox.size.x - 40.0)
		var z := _rng.randf_range(terrain.bbox.position.y + 40.0, terrain.bbox.position.y + terrain.bbox.size.y - 40.0)
		var q: Dictionary = terrain.track_query(x, z, 90.0)
		if not q.is_empty() and float(q["d"]) < 90.0:
			continue
		if _noise_patch(x, z) < 0.26:
			continue
		_try_tree(out, Vector3(x, 0.0, z))
	return out


func _try_tree(out: Array[Transform3D], position: Vector3) -> void:
	var q: Dictionary = terrain.track_query(position.x, position.z, 80.0)
	if not q.is_empty() and float(q["d"]) < 27.0:
		return
	if terrain.is_flat(position.x, position.z):
		return
	if _is_excluded(Vector2(position.x, position.z), 5.0):
		return
	if _slope_at(position.x, position.z) > 0.72:
		return
	var height: float = terrain.height_at(position.x, position.z)
	var scale := _rng.randf_range(0.95, 1.45)
	var basis := Basis(Vector3.UP, _rng.randf() * TAU)
	basis = basis.scaled(Vector3(scale, scale * _rng.randf_range(0.9, 1.25), scale))
	out.append(Transform3D(basis, Vector3(position.x, height - 0.06, position.z)))


func _noise_patch(x: float, z: float) -> float:
	var n := sin(x * 0.006 + 1.7) * cos(z * 0.005 - 0.4) + sin((x + z) * 0.0032) * 0.6
	return clampf(n * 0.5 + 0.5, 0.0, 1.0)


## Handroanthus chrysotrichus (Ipê Amarelo): the Brazilian national tree, a bare
## grey trunk carrying three tiers of bright yellow trumpet clusters. It is the
## signature silhouette of the Mata Atlântica ridge in September.
func _ipe_mesh(phase: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	_cylinder(st, Vector3.ZERO, 0.36, 8.2, 6, Color("#7d6a52"))
	# Two leaning boughs so the crown is not a lollipop.
	for branch: int in range(2):
		var angle := phase + float(branch) * PI
		var base := Vector3(cos(angle) * 0.3, 5.4 + float(branch) * 1.2, sin(angle) * 0.3)
		var tip := Vector3(cos(angle) * 2.4, 8.6 + float(branch) * 0.8, sin(angle) * 2.4)
		_beam(st, base, tip, 0.26, Color("#7d6a52"))
	var spokes := 7
	var tiers := 3
	var colors: Array[Color] = [Color("#e8a91c"), Color("#f2c11e"), Color("#ffd84a")]
	for tier in range(tiers):
		var base_y: float = 8.4 + float(tier) * 1.35
		var radius: float = 3.4 - float(tier) * 0.85
		var apex_y: float = base_y + 2.2
		var ring: Array[Vector3] = []
		for index in range(spokes):
			var angle := TAU * float(index) / float(spokes)
			var r: float = radius + sin(angle * 2.0 + phase + float(tier) * 1.7) * 0.55
			ring.append(Vector3(cos(angle) * r, base_y + sin(angle * 3.0 + phase) * 0.3, sin(angle) * r))
		var apex := Vector3(0.16 * float(tier), apex_y, -0.1)
		var color: Color = colors[tier]
		for index in range(spokes):
			var next := (index + 1) % spokes
			for vertex: Vector3 in [ring[index], ring[next], apex]:
				st.set_color((color).srgb_to_linear())
				st.add_vertex(vertex)
		var heart := Vector3(0.0, base_y - 0.35, 0.0)
		for index in range(spokes):
			var next_face := (index + 1) % spokes
			for vertex: Vector3 in [ring[next_face], ring[index], heart]:
				st.set_color((color.darkened(0.26)).srgb_to_linear())
				st.add_vertex(vertex)
	st.generate_normals()
	return st.commit()


## Roystonea oleracea (royal palm): a tall pale ringed trunk and a fountain of
## eight arched green fronds, the second signature of the Paulistano biome.
func _royal_palm_mesh(phase: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	_cylinder(st, Vector3.ZERO, 0.34, 13.2, 6, Color("#b9ab90"))
	# Three leaf-scar rings (the review build had seven 0.16 m bands, 84 tris no camera reads).
	for ring in range(3):
		var y := 2.4 + float(ring) * 3.6
		_cylinder(st, Vector3(0.0, y, 0.0), 0.38, 0.16, 6, Color("#8f7f63"))
	var top := Vector3(0.0, 13.2, 0.0)
	for index in range(9):
		var angle := TAU * float(index) / 9.0 + phase
		var mid := top + Vector3(cos(angle) * 2.6, 0.7, sin(angle) * 2.6)
		var tip := top + Vector3(cos(angle) * 4.4, -1.0, sin(angle) * 4.4)
		var side := Vector3(-sin(angle), 0.0, cos(angle)) * 0.55
		var color := Color("#2f7a3b") if index % 2 == 0 else Color("#3a8f45")
		for vertex: Vector3 in [mid - side, mid + side, tip]:
			st.set_color((color).srgb_to_linear())
			st.add_vertex(vertex)
		for vertex: Vector3 in [top + Vector3(0.0, 0.2, 0.0), mid - side, mid + side, top + Vector3(0.0, 0.2, 0.0), mid + side, mid - side]:
			st.set_color((color.darkened(0.2)).srgb_to_linear())
			st.add_vertex(vertex)
	st.generate_normals()
	return st.commit()


func _beam(st: SurfaceTool, a: Vector3, b: Vector3, thickness: float, color: Color) -> void:
	var delta := b - a
	var length := delta.length()
	if length < 0.001:
		return
	var forward := delta / length
	var up := Vector3.UP
	if absf(forward.dot(Vector3.UP)) > 0.98:
		up = Vector3.RIGHT
	var right := forward.cross(up).normalized()
	up = right.cross(forward).normalized()
	var corners: Array[Vector3] = []
	for x: float in [-1.0, 1.0]:
		for y: float in [-1.0, 1.0]:
			for z: float in [-1.0, 1.0]:
				corners.append((a + b) * 0.5 + right * (x * thickness * 0.5) + up * (y * thickness * 0.5) + forward * (z * length * 0.5))
	var faces: Array = [
		[0, 1, 3, 2], [4, 6, 7, 5], [0, 4, 5, 1], [2, 3, 7, 6], [0, 2, 6, 4], [1, 5, 7, 3],
	]
	for face: Array in faces:
		for vertex: Vector3 in [corners[face[0]], corners[face[1]], corners[face[2]], corners[face[0]], corners[face[2]], corners[face[3]]]:
			st.set_color((color).srgb_to_linear())
			st.add_vertex(vertex)


func _cylinder(st: SurfaceTool, base: Vector3, radius: float, height: float, segments: int, color: Color) -> void:
	for index in range(segments):
		var a0 := TAU * float(index) / float(segments)
		var a1 := TAU * float(index + 1) / float(segments)
		var p0 := base + Vector3(cos(a0) * radius, 0.0, sin(a0) * radius)
		var p1 := base + Vector3(cos(a1) * radius, 0.0, sin(a1) * radius)
		var q0 := p0 + Vector3(0.0, height, 0.0)
		var q1 := p1 + Vector3(0.0, height, 0.0)
		for vertex: Vector3 in [p0, q0, q1, p0, q1, p1]:
			st.set_color((color).srgb_to_linear())
			st.add_vertex(vertex)


# --- meadow ----------------------------------------------------------------------------

func _build_meadow() -> void:
	var mesh := _grass_tuft_mesh()
	if mesh == null:
		return
	var out: Array[Transform3D] = []
	for band: Dictionary in _segments:
		if String(band.get("zone", "")) != "grass":
			continue
		var side: float = -1.0 if String(band.get("side", "R")) == "L" else 1.0
		var s0: float = float(band["s0"])
		var s1: float = float(band["s1"])
		var offset: float = float(band.get("band_offset_m", 16.0))
		var depth: float = minf(float(band.get("band_depth_m", 250.0)), 140.0)
		var tries := int((s1 - s0) / 2.2)
		for index in range(tries):
			if out.size() >= GRASS_TARGET:
				break
			var station := _rng.randf_range(s0, s1)
			var lateral := offset + _rng.randf() * depth * 0.65
			var frame: Transform3D = ribbon.call("get_point_at_offset", fposmod(station, Layout.LENGTH_M), side * lateral)
			var q: Dictionary = terrain.track_query(frame.origin.x, frame.origin.z, 40.0)
			if not q.is_empty() and float(q["d"]) < 9.6:
				continue
			if terrain.is_flat(frame.origin.x, frame.origin.z):
				continue
			if _is_excluded(Vector2(frame.origin.x, frame.origin.z), 3.0):
				continue
			var height: float = terrain.height_at(frame.origin.x, frame.origin.z)
			var scale := _rng.randf_range(0.7, 1.5)
			var basis := Basis(Vector3.UP, _rng.randf() * TAU)
			basis = basis.scaled(Vector3(scale, scale * _rng.randf_range(0.8, 1.4), scale))
			out.append(Transform3D(basis, Vector3(frame.origin.x, height, frame.origin.z)))
	var foliage := _foliage_holder()
	_add_multimesh(foliage, "WetMeadowTufts", mesh, out, 1.1, 0.14)
	_stats["grass_count"] = out.size()
	_stats["grass_triangles"] = out.size() * _surface_triangles(mesh)


func _grass_tuft_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for blade in range(3):
		var angle := float(blade) * PI / 3.0
		var across := Vector3(cos(angle), 0.0, sin(angle)) * 0.22
		var p0 := -across
		var p1 := across
		var p2 := across + Vector3(0.0, 0.95, 0.0)
		var p3 := -across + Vector3(0.0, 0.95, 0.0)
		for vertex: Vector3 in [p0, p1, p2, p0, p2, p3]:
			st.set_color((Color("#3f5c33") if vertex.y < 0.2 else Color("#6f8f4a")).srgb_to_linear())
			st.add_vertex(vertex)
	st.generate_normals()
	return st.commit()


# --- undergrowth & basalt boulders -----------------------------------------------------

## Damp Paulistano undergrowth: fern and bramble clumps on the grass/forest verges, plus
## low-poly basalt boulders on the volcanic rock bands. Three stacked cel rings
## (~36 tris) at 0.6-1.4 m read as a soft forest floor under the conifer wall.
func _build_chaparral() -> void:
	var mesh := _shrub_mesh()
	var out: Array[Transform3D] = []
	for band: Dictionary in _segments:
		var zone := String(band.get("zone", ""))
		if zone != "sand" and zone != "rock" and zone != "grass" and zone != "forest" and zone != "cliff":
			continue
		var side: float = -1.0 if String(band.get("side", "R")) == "L" else 1.0
		var s0: float = float(band["s0"])
		var s1: float = float(band["s1"])
		var offset: float = float(band.get("band_offset_m", 16.0))
		var depth: float = minf(float(band.get("band_depth_m", 250.0)), 140.0)
		var density: float = float(band.get("density", 0.7))
		var s := s0 + 3.0
		while s < s1 and out.size() < SHRUB_LIMIT:
			for sample in 2:
				var lateral := offset + 4.0 + _rng.randf() * depth * 0.78
				var frame: Transform3D = ribbon.call("get_point_at_offset", fposmod(s, Layout.LENGTH_M), side * lateral)
				_chaparral_piece(out, frame, density)
			s += _rng.randf_range(4.5, 7.5)
	if out.is_empty():
		return
	_add_multimesh(_foliage_holder(), "PaulistanoUndergrowth", mesh, out, 1.05, 0.08)
	_stats["shrub_count"] = out.size()
	_stats["shrub_triangles"] = out.size() * _surface_triangles(mesh)


func _chaparral_piece(out: Array[Transform3D], frame: Transform3D, density: float) -> void:
	if _rng.randf() > density * 0.8:
		return
	var position := frame.origin
	if terrain.is_flat(position.x, position.z):
		return
	if _is_excluded(Vector2(position.x, position.z), 3.0):
		return
	var q: Dictionary = terrain.track_query(position.x, position.z, 40.0)
	if not q.is_empty() and float(q["d"]) < 10.5:
		return
	if _slope_at(position.x, position.z) > 0.65:
		return
	var height: float = terrain.height_at(position.x, position.z)
	var scale := _rng.randf_range(0.8, 1.8)
	var basis := Basis(Vector3.UP, _rng.randf() * TAU).scaled(Vector3(scale, scale * _rng.randf_range(0.8, 1.3), scale))
	out.append(Transform3D(basis, Vector3(position.x, height - 0.06, position.z)))


func _shrub_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var spokes := 6
	var rings: Array = []
	var heights: Array[float] = [0.05, 0.55, 0.95]
	var radii: Array[float] = [0.62, 0.9, 0.5]
	var colors: Array[Color] = [Color("#2e4428"), Color("#3a5330"), Color("#4a6538")]
	for ring in 3:
		var points: Array[Vector3] = []
		for index in range(spokes):
			var angle := TAU * float(index) / float(spokes)
			points.append(Vector3(cos(angle) * radii[ring], heights[ring], sin(angle) * radii[ring]))
		rings.append(points)
	for ring in 2:
		var lower: Array[Vector3] = rings[ring]
		var upper: Array[Vector3] = rings[ring + 1]
		for index in range(spokes):
			var next := (index + 1) % spokes
			var color: Color = colors[ring].lerp(colors[ring + 1], 0.5)
			for vertex: Vector3 in [lower[index], lower[next], upper[next], lower[index], upper[next], upper[index]]:
				st.set_color((color).srgb_to_linear())
				st.add_vertex(vertex)
	var top: Array[Vector3] = rings[2]
	var apex := Vector3(0.06, 1.25, -0.05)
	for index in range(spokes):
		var next := (index + 1) % spokes
		for vertex: Vector3 in [top[index], top[next], apex]:
			st.set_color((colors[2]).srgb_to_linear())
			st.add_vertex(vertex)
	st.generate_normals()
	return st.commit()


# --- volcanic boulders & valley mist ----------------------------------------------------

## Basalt outcrops along the volcanic rock bands and the castle crag: 320 low-poly
## boulders (~14 tris) break the grass/rock transition without touching the corridor.
func _build_boulders() -> void:
	var mesh := _boulder_mesh()
	var out: Array[Transform3D] = []
	var attempts := 0
	while out.size() < 320 and attempts < 4000:
		attempts += 1
		var band: Dictionary = _segments[_rng.randi_range(0, _segments.size() - 1)]
		var zone := String(band.get("zone", ""))
		if zone != "cliff" and zone != "grass" and _rng.randf() > 0.35:
			continue
		var side: float = -1.0 if String(band.get("side", "R")) == "L" else 1.0
		var s0: float = float(band["s0"])
		var s1: float = float(band["s1"])
		var station := _rng.randf_range(s0, s1)
		var lateral: float = float(band.get("band_offset_m", 24.0)) + _rng.randf_range(2.0, 46.0)
		var frame: Transform3D = ribbon.call("get_point_at_offset", fposmod(station, Layout.LENGTH_M), side * lateral)
		var position := frame.origin
		if terrain.is_flat(position.x, position.z):
			continue
		if _is_excluded(Vector2(position.x, position.z), 4.0):
			continue
		var q: Dictionary = terrain.track_query(position.x, position.z, 40.0)
		if not q.is_empty() and float(q["d"]) < 12.0:
			continue
		var height: float = terrain.height_at(position.x, position.z)
		var scale := _rng.randf_range(0.7, 2.4)
		var basis := Basis(Vector3.UP, _rng.randf() * TAU).scaled(Vector3(scale * _rng.randf_range(0.8, 1.4), scale * _rng.randf_range(0.6, 1.1), scale * _rng.randf_range(0.8, 1.4)))
		out.append(Transform3D(basis, Vector3(position.x, height - 0.12, position.z)))
	if out.is_empty():
		return
	_add_multimesh(_foliage_holder(), "LateriteBoulders", mesh, out, 0.0, 0.0)
	_stats["boulder_count"] = out.size()
	_stats["boulder_triangles"] = out.size() * _surface_triangles(mesh)


func _boulder_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var ring: Array[Vector3] = []
	for index in range(6):
		var angle := TAU * float(index) / 6.0
		ring.append(Vector3(cos(angle) * 0.85, 0.15 + sin(angle * 3.0) * 0.1, sin(angle) * 0.62))
	var top := Vector3(0.08, 1.0, -0.05)
	var bottom := Vector3(-0.05, -0.1, 0.04)
	for index in range(6):
		var next := (index + 1) % 6
		for vertex: Vector3 in [ring[index], ring[next], top]:
			st.set_color((Color("#a1512e") if index % 2 == 0 else Color("#8a4326")).srgb_to_linear())
			st.add_vertex(vertex)
		for vertex: Vector3 in [ring[next], ring[index], bottom]:
			st.set_color((Color("#6f371f")).srgb_to_linear())
			st.add_vertex(vertex)
	st.generate_normals()
	return st.commit()


## Tropical humidity: a bounded FogVolume over the Guarapiranga reservoir,
## driven by the same 70% storm mood as the cel sky. Volumetric fog is enabled
## by ToonLook; density is low enough to keep the horizon readable.
func _build_lake_mist() -> void:
	var grid: Dictionary = terrain.heightgrid
	var centre: Vector2 = grid.get("lake_centre", Vector2.ZERO)
	var floor_y: float = float(grid.get("lake_water_y", 0.0))
	var fog := FogVolume.new()
	fog.name = "ReservoirMist"
	fog.size = Vector3(460.0, 30.0, 460.0)
	fog.position = Vector3(centre.x, floor_y + 11.0, centre.y)
	var material := FogMaterial.new()
	material.density = 0.028
	material.albedo = Color("#d7e4e2")
	material.height_falloff = 0.4
	material.edge_fade = 0.6
	fog.material = material
	add_child(fog)
	_stats["lake_mist"] = {"centre": [snappedf(centre.x, 0.1), snappedf(centre.y, 0.1)], "water_y": snappedf(floor_y, 0.01), "size": [460.0, 30.0, 460.0]}


## Guarapiranga water surface, one quad per terrain grid cell that dips under the waterline
## inside the basin shape: the shoreline is wherever the terrain rises through the water, so
## it follows the bank contour instead of a hand-drawn strip. Each vertex carries the water
## depth under it (COLOR.r, 0..1 of 4 m) for the shelf colours and the shore foam.
func _build_reservoir() -> void:
	var grid: Dictionary = terrain.heightgrid
	var water_y: float = float(grid.get("lake_water_y", 0.0))
	var origin: Vector2 = grid["origin"]
	var step: float = float(grid["step"])
	var nx: int = int(grid["nx"])
	var nz: int = int(grid["nz"])
	var heights: PackedFloat32Array = grid["heights"]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var quads := 0
	for iz in range(nz - 1):
		for ix in range(nx - 1):
			var corners: Array[Vector2i] = [Vector2i(ix, iz), Vector2i(ix + 1, iz), Vector2i(ix + 1, iz + 1), Vector2i(ix, iz + 1)]
			var wet := false
			for c: Vector2i in corners:
				wet = wet or heights[c.y * nx + c.x] < water_y
			var mid := origin + Vector2(float(ix) + 0.5, float(iz) + 0.5) * step
			if not wet or terrain.lake_shape(mid.x, mid.y) > 1.2:
				continue
			var verts: Array[Vector3] = []
			var colors: Array[Color] = []
			for c: Vector2i in corners:
				verts.append(Vector3(origin.x + float(c.x) * step, water_y, origin.y + float(c.y) * step))
				colors.append(Color(clampf((water_y - heights[c.y * nx + c.x]) / 4.0, 0.0, 1.0), 0.0, 0.0))
			# Clockwise seen from above: the front face (cull_back) looks up, as in _quad_color.
			for index: int in [0, 1, 2, 0, 2, 3]:
				st.set_normal(Vector3.UP)
				st.set_color(colors[index])
				st.add_vertex(verts[index])
			quads += 1
	var mesh := st.commit()
	if mesh != null:
		_water_material = ShaderMaterial.new()
		_water_material.shader = WaterShader
		var node := MeshInstance3D.new()
		node.name = "ReservoirWater"
		node.mesh = mesh
		node.material_override = _water_material
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(node)
	_stats["reservoir_quads"] = quads
	_stats["lake_water_y"] = snappedf(water_y, 0.01)


# --- completion ------------------------------------------------------------------------

func _finish(started: int) -> void:
	var elapsed := Time.get_ticks_msec() - started
	_stats["build_ms"] = elapsed
	_stats["terrain_triangles"] = terrain.triangles()
	var range_m: Vector2 = terrain.elevation_range()
	_stats["terrain_min_y"] = snappedf(range_m.x, 0.01)
	_stats["terrain_max_y"] = snappedf(range_m.y, 0.01)
	_stats["roadbed_drop_m"] = Layout.ROADBED_DROP_M
	_stats["landmarks"] = _landmark_records
	var placed := 0
	var landmark_triangles := 0
	for record: Dictionary in _landmark_records:
		if bool(record.get("placed", false)):
			placed += 1
			landmark_triangles += int(record.get("triangles", 0))
	_stats["landmarks_placed"] = placed
	_stats["landmark_triangles"] = landmark_triangles
	_stats["environment_triangles"] = _count_triangles(self)
	_stats["triangle_budget"] = ENVIRONMENT_TRIANGLE_BUDGET
	_toon()
	_set_shadow_policy()
	set_meta("env_stats", _stats)
	set_meta("heightgrid", terrain.heightgrid)
	set_meta("built", true)
	built = true
	apply_time_of_day(_tod, _gloom)
	print("[paulistano-env] built in %.2fs | terrain tris %d | trees %d | grass %d | shrubs %d | boulders %d | landmarks %d/%d | env tris %d (budget %d)" % [
		float(elapsed) / 1000.0,
		int(_stats["terrain_triangles"]),
		int(_stats.get("tree_count", 0)),
		int(_stats.get("grass_count", 0)),
		int(_stats.get("shrub_count", 0)),
		int(_stats.get("boulder_count", 0)),
		placed,
		_landmark_records.size(),
		int(_stats["environment_triangles"]),
		ENVIRONMENT_TRIANGLE_BUDGET,
	])


func _toon() -> void:
	ToonLookScript.apply_visuals(get_parent())


## Draw-call gate: only the hero landmarks and the three FIA structures cast a
## shadow; the terrain, furniture, fences, paddock props, pit lane paint, signs,
## crews, transporters and garage detail would each add a shadow pass for no
## silhouette the cel look needs. The road (TrackRibbon) keeps its own shadow.
func _set_shadow_policy() -> void:
	var root := get_parent()
	if root == null:
		return
	for node: Node in root.find_children("*", "GeometryInstance3D", true, false):
		var geometry := node as GeometryInstance3D
		var path: String = String(root.get_path_to(geometry))
		if path.begins_with("TrackRibbon/"):
			continue
		var keep: bool = path.begins_with("Environment/HeroLandmarks/") \
			or path == "PitLane/PitBuilding/Structure" \
			or path == "PitLane/MainGrandstand/Structure" \
			or path == "PitLane/RaceControlTower/Structure"
		geometry.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if keep else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


# --- helpers ---------------------------------------------------------------------------

func _road_y(s: float) -> float:
	var points: PackedVector3Array = _compiled["points"]
	var index := posmod(roundi(fposmod(s, Layout.LENGTH_M) / float(_compiled["step_m"])), points.size())
	return points[index].y


func _lateral_point(s: float, side: float, lateral: float) -> Vector3:
	var frame: Transform3D = ribbon.call("get_point_at_offset", fposmod(s, Layout.LENGTH_M), side * lateral)
	return frame.origin


func _foliage_holder() -> Node3D:
	var holder := get_node_or_null("Foliage") as Node3D
	if holder == null:
		holder = Node3D.new()
		holder.name = "Foliage"
		add_child(holder)
	return holder


func _add_multimesh(parent: Node3D, node_name: String, mesh: Mesh, transforms: Array[Transform3D], sway_height: float, wind_strength: float) -> void:
	if transforms.is_empty():
		return
	var material := ShaderMaterial.new()
	material.shader = TreeWindShader
	material.set_shader_parameter("sway_height_m", sway_height)
	material.set_shader_parameter("wind_strength", wind_strength)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = transforms.size()
	for index in range(transforms.size()):
		mm.set_instance_transform(index, transforms[index])
	var instance := MultiMeshInstance3D.new()
	instance.name = node_name
	instance.multimesh = mm
	instance.material_override = material
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(instance)


func _is_excluded(point: Vector2, margin: float) -> bool:
	# Nothing grows in the reservoir or on its wet margin.
	if terrain != null and terrain.lake_shore_distance(point.x, point.y) < 4.0 + margin:
		return true
	for entry: Array in _exclusion:
		var centre: Vector2 = entry[0]
		if point.distance_to(centre) < float(entry[1]) + margin:
			return true
	return false


func _slope_at(x: float, z: float) -> float:
	var hx: float = terrain.height_at(x + 4.0, z) - terrain.height_at(x - 4.0, z)
	var hz: float = terrain.height_at(x, z + 4.0) - terrain.height_at(x, z - 4.0)
	return sqrt(hx * hx + hz * hz) / 8.0


func _quad_color(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, hint: Vector3, color: Color) -> void:
	var normal := (b - a).cross(c - a)
	var order: Array = [a, b, c, a, c, d] if normal.dot(hint) < 0.0 else [a, c, b, a, d, c]
	for vertex: Vector3 in order:
		st.set_color((color).srgb_to_linear())
		st.add_vertex(vertex)


## Double-sided box so no face can be missed at an oblique review angle.
func _box(st: SurfaceTool, frame: Transform3D, centre: Vector3, size: Vector3, color: Color) -> void:
	var corners: Array[Vector3] = []
	for x: float in [-1.0, 1.0]:
		for y: float in [-1.0, 1.0]:
			for z: float in [-1.0, 1.0]:
				corners.append(frame * (centre + Vector3(x * size.x * 0.5, y * size.y * 0.5, z * size.z * 0.5)))
	var faces: Array = [
		[0, 1, 3, 2, Vector3.LEFT], [4, 6, 7, 5, Vector3.RIGHT],
		[0, 4, 5, 1, Vector3.DOWN], [2, 3, 7, 6, Vector3.UP],
		[0, 2, 6, 4, Vector3.FORWARD], [1, 5, 7, 3, Vector3.BACK],
	]
	for face: Array in faces:
		var a := corners[face[0]]
		var b := corners[face[1]]
		var c := corners[face[2]]
		var d := corners[face[3]]
		var hint: Vector3 = (frame.basis * (face[4] as Vector3)).normalized()
		var order: Array = [a, b, c, a, c, d]
		if (c - a).cross(b - a).dot(hint) < 0.0:
			order = [a, c, b, a, d, c]
		for vertex: Vector3 in order:
			st.set_color((color).srgb_to_linear())
			st.set_normal(hint)
			st.add_vertex(vertex)


func _disc(st: SurfaceTool, centre: Vector3, radius: float, segments: int, color: Color) -> void:
	for index in range(segments):
		var a0 := TAU * float(index) / float(segments)
		var a1 := TAU * float(index + 1) / float(segments)
		var p0 := centre + Vector3(cos(a0) * radius, 0.0, sin(a0) * radius)
		var p1 := centre + Vector3(cos(a1) * radius, 0.0, sin(a1) * radius)
		for vertex: Vector3 in [centre, p0, p1, centre, p1, p0]:
			st.set_color((color).srgb_to_linear())
			st.add_vertex(vertex)


func _surface_triangles(mesh: Mesh) -> int:
	if mesh == null:
		return 0
	var total := 0
	for surface in mesh.get_surface_count():
		var arrays := mesh.surface_get_arrays(surface)
		var indices: Variant = arrays[Mesh.ARRAY_INDEX]
		total += (indices.size() if indices != null else (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()) / 3
	return total


func _mesh_triangles(root: Node) -> int:
	var total := 0
	if root is MeshInstance3D and (root as MeshInstance3D).mesh != null:
		total += _surface_triangles((root as MeshInstance3D).mesh)
	for child: Node in root.get_children():
		total += _mesh_triangles(child)
	return total


func _count_triangles(root: Node) -> int:
	var total := 0
	for child: Node in root.get_children():
		if child is MeshInstance3D and (child as MeshInstance3D).mesh != null:
			total += _surface_triangles((child as MeshInstance3D).mesh)
		elif child is MultiMeshInstance3D and (child as MultiMeshInstance3D).multimesh != null:
			var mm := (child as MultiMeshInstance3D).multimesh
			total += _surface_triangles(mm.mesh) * mm.instance_count
		total += _count_triangles(child)
	return total


## Foot of the outer retaining wall: 0.85 m under the slab, deeper wherever the ground just beyond
## the edge (or 5 m out, on a falling berm) is lower, so the wall always meets the terrain.
func _wall_foot(top_y: float, frame: Transform3D, side: float, lat1: float) -> float:
	var near: Vector3 = frame.origin + frame.basis.x * (side * (lat1 + 0.6))
	var far: Vector3 = frame.origin + frame.basis.x * (side * (lat1 + 5.0))
	return minf(top_y - 0.85, minf(terrain.height_at(near.x, near.z), terrain.height_at(far.x, far.z)) - 0.3)


func _cap_foot(top_y: float, outside: Vector3) -> float:
	return minf(top_y - 0.9, terrain.height_at(outside.x, outside.z) - 0.3)


func _cap_top(top_y: float, outside: Vector3) -> float:
	return maxf(top_y, terrain.height_at(outside.x, outside.z) + 0.05)
