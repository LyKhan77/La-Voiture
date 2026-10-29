class_name ApexEnvironment
extends "res://scripts/world/circuits/base/circuit_environment.gd"

## Hybrid procedural trackside set for the race weekend (FASE 5.5, upgraded in FASE 10), all
## generated from the ribbon without touching its spline: 3D sawtooth kerbs, tarmac runoff and
## gravel traps, the rubber groove, trackside furniture (Armco, Tecpro, braking boards,
## floodlight towers), catch fence, the hero paddock buildings, the mountain vista, wind-swept
## anime trees and the time-of-day lighting. Everything is flat-shaded with the cel shaders and
## instanced through MultiMeshes where it repeats.

const AdaptiveLineScript := preload("res://scripts/car/adaptive_racing_line.gd")
const PitLaneScript := preload("res://scripts/world/circuits/apex_ring/apex_pit_complex.gd")
const PitZoneScript := preload("res://scripts/world/shared/pit_zone.gd")
const ToonMaterials := preload("res://scripts/world/shared/toon_materials.gd")
const RibbonGeometry := preload("res://scripts/world/shared/ribbon_geometry.gd")
const SurfaceGeometry := preload("res://scripts/world/shared/enhanced_track_geometry.gd")
const PitBuildingScript := preload("res://scripts/world/paddock/pit_building.gd")
const GrandstandScript := preload("res://scripts/world/paddock/main_grandstand.gd")
const ControlTowerScript := preload("res://scripts/world/paddock/race_control_tower.gd")
const PitBuildingScene := preload("res://scenes/race_world/paddock/pit_building_structure.tscn")
const GrandstandScene := preload("res://scenes/race_world/paddock/main_grandstand.tscn")
const ControlTowerScene := preload("res://scenes/race_world/paddock/race_control_tower.tscn")
const FoliageScript := preload("res://scripts/world/shared/foliage_scatter.gd")
const VistaScript := preload("res://scripts/world/shared/mountain_vista.gd")
const VistaScene := preload("res://scenes/race_world/shared/mountain_vista.tscn")
const LightingScript := preload("res://scripts/world/shared/circuit_lighting_controller.gd")
const SharedSkyScript := preload("res://scripts/world/shared/shared_cel_sky_controller.gd")

## |kappa| above this (radius under 125 m) counts as a sharp corner.
const KERB_CURVATURE: float = 0.008
const KERB_MIN_LENGTH_M: float = 12.0
const KERB_SCAN_STEP_M: float = 2.0
## The right-hand runoff stays closed from just before Pit Entry to just after Pit Exit (like the guardrail).
const PIT_RUNOFF_LEAD_M: float = 20.0
const PIT_RUNOFF_TRAIL_M: float = 40.0
## The catch fence stands this far behind the guardrail.
const FENCE_BEHIND_RAIL_M: float = 1.0
const FENCE_STEP_M: float = 3.0
const FENCE_POST_STEP_M: float = 6.0
const FENCE_HEIGHT_M: float = 3.6
## Floodlights keep clear of the landmarks: behind the pit garages (right) and the main grandstand (left).
const PIT_TOWER_LATERAL_M: float = 36.0
const GRANDSTAND_TOWER_LATERAL_M: float = GrandstandScript.FRONT_X_M + GrandstandScript.DEPTH_M + 8.0
const CONTROL_TOWER_TOWER_LATERAL_M: float = 40.0
const CONTROL_TOWER_CLEAR_S_M: float = 16.0

## Trees keep this far clear (arc margin, then lateral depth) of the landmark buildings.
const FOLIAGE_PIT_MARGIN_M: float = 60.0
const FOLIAGE_PIT_DEPTH_M: float = 70.0
const FOLIAGE_STAND_DEPTH_M: float = 120.0

const RED := SurfaceGeometry.KERB_RED
const WHITE := SurfaceGeometry.KERB_WHITE
const POST_COLOR := Color("#5c6270")
const GRASS_COLOR := Color("#4f9a45")

var line: AdaptiveLineScript

## One entry per kerb: {s0, s1, side}. side is the lateral sign of the inside of the corner.
var kerbs: Array[Dictionary] = []
var kerb_instance: MeshInstance3D
var runoff_instance: MeshInstance3D
var gravel_instance: MeshInstance3D
var groove_instance: MeshInstance3D
## One plan per sharp corner, see EnhancedTrackGeometry.plan_runoffs.
var runoff_plans: Array[Dictionary] = []
var armco_post_count: int = 0
var fence_post_count: int = 0
## Poses of the catch fence panels and posts, and the arc distance each was generated at.
var catch_fence_transforms: Array[Transform3D] = []
var catch_fence_arcs: PackedFloat32Array = PackedFloat32Array()
var fence_post_transforms: Array[Transform3D] = []
var fence_post_arcs: PackedFloat32Array = PackedFloat32Array()
var tree_count: int = 0
var kerb_inner_m: float = 5.5
## Armco, Tecpro, braking boards and floodlight towers (see TracksideFurnitureBuilder).
## The pit building, main grandstand and race control tower, each instanced from its own scene.
var paddock: Node3D
var grandstand: GrandstandScript
## Mountain ring and stars, trees, and the time-of-day lighting that drives them (see CircuitLightingController).
var vista: VistaScript
var foliage: FoliageScript
var lighting: LightingScript
## Cel Sun/Moon disc and wind-driven clouds shared with every circuit; the vista keeps the only starfield.
var sky_controller: SharedSkyScript
var sky_ambience_root: Node3D
var _wind_kph: float = 0.0


func _init() -> void:
	circuit_id = "apex_ring"
	_leaderboard_clock = LEADERBOARD_PERIOD_S


func build(p_ribbon: TrackRibbonScript, p_line: Variant = null) -> void:
	ribbon = p_ribbon
	line = p_line as AdaptiveLineScript
	built = true
	kerb_inner_m = ribbon.road_half_width_m - SurfaceGeometry.KERB_INSET_M
	_paint_ground()
	_build_kerbs()
	_build_runoff()
	_build_groove()
	_build_furniture()
	_build_paddock()
	_build_catch_fence()
	_build_vista()
	sky_controller = SharedSkyScript.new()
	sky_ambience_root = sky_controller.build(self, ribbon, 20260240, false)
	_build_foliage()


func _paint_ground() -> void:
	var ground := ribbon.get_node_or_null("Ground") as MeshInstance3D
	if ground != null:
		ground.material_override = ToonMaterials.make(GRASS_COLOR)


# --- kerbs -----------------------------------------------------------------

## Runs of s where one-signed |kappa| stays above the sharp-corner threshold.
func find_sharp_corners() -> Array[Dictionary]:
	var runs: Array[Dictionary] = []
	var current: Dictionary = {}
	var s: float = 0.0
	while s < ribbon.length_m:
		var kappa: float = line.curvature_at(s)
		# kappa > 0 is a right turn, so the inside is the right (+) side.
		var side: float = signf(kappa) if absf(kappa) > KERB_CURVATURE else 0.0
		if side != 0.0 and not current.is_empty() and float(current["side"]) == side:
			current["s1"] = s + KERB_SCAN_STEP_M
		else:
			if not current.is_empty():
				runs.append(current)
				current = {}
			if side != 0.0:
				current = {"s0": s, "s1": s + KERB_SCAN_STEP_M, "side": side}
		s += KERB_SCAN_STEP_M
	if not current.is_empty():
		runs.append(current)
	var kept: Array[Dictionary] = []
	for run: Dictionary in runs:
		if float(run["s1"]) - float(run["s0"]) >= KERB_MIN_LENGTH_M:
			kept.append(run)
	return kept


func _build_kerbs() -> void:
	kerbs = find_sharp_corners()
	var mesh: ArrayMesh = SurfaceGeometry.kerb_mesh(ribbon, kerbs, kerb_inner_m)
	mesh.surface_set_material(0, ToonMaterials.make(RED))
	mesh.surface_set_material(1, ToonMaterials.make(WHITE))
	kerb_instance = _add_mesh("Kerbs", mesh)


## Tarmac runoff, its blue/white warning edge and the gravel trap on the outside of every sharp corner.
func _build_runoff() -> void:
	var pit_zone: Dictionary = _pit_zone()
	runoff_plans = SurfaceGeometry.plan_runoffs(ribbon, kerbs, float(pit_zone["start_s"]), float(pit_zone["length_m"]))
	var runoff: ArrayMesh = SurfaceGeometry.runoff_mesh(ribbon, runoff_plans)
	runoff.surface_set_material(0, ToonMaterials.make(SurfaceGeometry.RUNOFF_COLOR))
	runoff.surface_set_material(1, ToonMaterials.make(SurfaceGeometry.WARNING_BLUE))
	runoff.surface_set_material(2, ToonMaterials.make(WHITE))
	runoff_instance = _add_mesh("Runoff", runoff)
	var gravel: ArrayMesh = SurfaceGeometry.gravel_mesh(ribbon, runoff_plans)
	gravel.surface_set_material(0, ToonMaterials.make(SurfaceGeometry.GRAVEL_COLOR))
	gravel_instance = _add_mesh("GravelTraps", gravel)


## Rubber laid down along the adaptive racing line, darker through the corners.
func _build_groove() -> void:
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.roughness = 0.7
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	var mesh: ArrayMesh = SurfaceGeometry.groove_mesh(ribbon, line)
	mesh.surface_set_material(0, material)
	groove_instance = _add_mesh("RubberGroove", mesh)
	groove_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _add_mesh(node_name: String, mesh: Mesh) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.name = node_name
	instance.mesh = mesh
	add_child(instance)
	return instance


# --- trackside furniture and fence -------------------------------------------

## Armco, Tecpro, braking boards and floodlights; the guardrail stands behind every gravel trap.
func _build_furniture() -> void:
	var pit_zone: Dictionary = _pit_zone()
	var pit_zone_end: float = float(pit_zone["start_s"]) + float(pit_zone["length_m"])
	var hero_zones: Array[Dictionary] = [
		{"side": 1.0, "s0": float(pit_zone["start_s"]), "s1": pit_zone_end, "lateral": PIT_TOWER_LATERAL_M},
		{"side": -1.0, "s0": GrandstandScript.CENTRE_S - GrandstandScript.LENGTH_M * 0.5, "s1": GrandstandScript.CENTRE_S + GrandstandScript.LENGTH_M * 0.5, "lateral": GRANDSTAND_TOWER_LATERAL_M},
		{"side": 1.0, "s0": ControlTowerScript.CENTRE_S - CONTROL_TOWER_CLEAR_S_M, "s1": ControlTowerScript.CENTRE_S + CONTROL_TOWER_CLEAR_S_M, "lateral": CONTROL_TOWER_TOWER_LATERAL_M},
	]
	furniture = FurnitureScript.new()
	furniture.name = "Furniture"
	add_child(furniture)
	furniture.build(ribbon, line, kerbs, runoff_plans, hero_zones, pit_zone)
	armco_post_count = furniture.armco_post_count


func _pit_zone() -> Dictionary:
	return PitZoneScript.from_layout({"entry_s": PitLaneScript.ENTRY_S, "exit_s": PitLaneScript.EXIT_S, "lane_length_m": PitLaneScript.NOMINAL_LENGTH_M}, ribbon.length_m, PIT_RUNOFF_LEAD_M, PIT_RUNOFF_TRAIL_M)


## The three landmark buildings, each its own scene placed on the centreline at its anchor.
func _build_paddock() -> void:
	paddock = Node3D.new()
	paddock.name = "Paddock"
	add_child(paddock)
	var anchors: Array[Array] = [
		["PitBuilding", PitBuildingScene, PitBuildingScript.CENTRE_S],
		["MainGrandstand", GrandstandScene, GrandstandScript.CENTRE_S],
		["RaceControlTower", ControlTowerScene, ControlTowerScript.CENTRE_S],
	]
	for anchor: Array in anchors:
		var building := (anchor[1] as PackedScene).instantiate() as Node3D
		building.name = anchor[0]
		paddock.add_child(building)
		building.global_transform = ribbon.get_point_at_offset(float(anchor[2]), 0.0)
	grandstand = paddock.get_node("MainGrandstand") as GrandstandScript


## Per-frame upkeep: the Jumbotron leaderboard and the time-of-day lighting follow the race.
func update(delta: float, race) -> void:
	_feed_leaderboards(delta, race, [grandstand.jumbotron] if grandstand != null else [])
	var weather: GtWeather = race.weather
	var gloom: float = maxf(clampf(sqrt(weather.rain_intensity), 0.0, 1.0), weather.track_water_pct / 100.0)
	if lighting != null:
		_wind_kph = weather.wind_speed
		lighting.apply(weather.time_of_day, gloom, weather.wind_speed, delta)
	if sky_controller != null:
		sky_controller.apply_wind(delta, weather.wind_speed)
		sky_controller.apply_time_of_day(weather.time_of_day, gloom)


## DAY / SUNSET / NIGHT now, for the sky and the lighting rig (update() does the same every frame with the weather's time of day).
func apply_time_of_day(tod: Dictionary, gloom: float = 0.0) -> void:
	if sky_controller != null:
		sky_controller.apply_time_of_day(tod, gloom)
	if lighting != null:
		lighting.apply(tod, gloom, _wind_kph, 0.0)


func apply_wind(delta: float, wind_kph: float, _wind_dir: float) -> void:
	_wind_kph = wind_kph
	if sky_controller != null:
		sky_controller.apply_wind(delta, wind_kph)



## Tall translucent fence behind the guardrail on the outside of each sharp corner, as two MultiMeshes.
func _build_catch_fence() -> void:
	var panel := StandardMaterial3D.new()
	panel.albedo_color = Color(0.12, 0.14, 0.2, 0.32)
	panel.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	panel.cull_mode = BaseMaterial3D.CULL_DISABLED
	var panels: Array[Transform3D] = []
	var posts: Array[Transform3D] = []
	for kerb: Dictionary in kerbs:
		var outside: float = -float(kerb["side"])
		var s0: float = float(kerb["s0"]) - 10.0
		var s1: float = float(kerb["s1"]) + 10.0
		for run: Array in [[FENCE_STEP_M, Vector3(0.05, FENCE_HEIGHT_M, FENCE_STEP_M + 0.2), panels], [FENCE_POST_STEP_M, Vector3(0.16, FENCE_HEIGHT_M + 0.4, 0.16), posts]]:
			var count: int = maxi(1, ceili((s1 - s0) / float(run[0])))
			for index: int in range(count):
				var s: float = s0 + (float(index) + 0.5) * (s1 - s0) / float(count)
				# No fence where there is no room behind the rail (a narrow gap between roads) or no rail (the pit lane).
				if not furniture.has_barrier_row_at(outside, s, FENCE_BEHIND_RAIL_M):
					continue
				var lateral: float = furniture.armco_lateral(outside, s) + outside * FENCE_BEHIND_RAIL_M
				(run[2] as Array[Transform3D]).append(RibbonGeometry.box_transform(ribbon, s, lateral, run[1], 0.0))
				(catch_fence_arcs if run[2] == panels else fence_post_arcs).append(s)
	catch_fence_transforms = panels
	fence_post_transforms = posts
	fence_post_count = posts.size()
	_add_multimesh("CatchFence", _unit_box(), panels, panel)
	_add_multimesh("FencePosts", _unit_box(), posts, ToonMaterials.make(POST_COLOR))


func _unit_box() -> BoxMesh:
	var mesh := BoxMesh.new()
	mesh.size = Vector3.ONE
	return mesh


# --- vista, foliage, lighting ------------------------------------------------

## The mountain ring around the circuit, from its own scene.
func _build_vista() -> void:
	vista = (VistaScene.instantiate() as Node3D) as VistaScript
	vista.name = "MountainVista"
	add_child(vista)
	vista.build(ribbon)


## Trees keep clear of the pit complex, the main grandstand and the race control tower.
func _build_foliage() -> void:
	var keep_out: Array[Dictionary] = [
		{"side": 1.0, "s0": PitLaneScript.ENTRY_S - FOLIAGE_PIT_MARGIN_M, "s1": PitLaneScript.ENTRY_S + PitLaneScript.NOMINAL_LENGTH_M + FOLIAGE_PIT_MARGIN_M, "lateral_max": FOLIAGE_PIT_DEPTH_M},
		{"side": 1.0, "s0": ControlTowerScript.CENTRE_S - FOLIAGE_PIT_MARGIN_M, "s1": ControlTowerScript.CENTRE_S + 70.0, "lateral_max": FOLIAGE_PIT_DEPTH_M},
		{"side": -1.0, "s0": GrandstandScript.CENTRE_S - GrandstandScript.LENGTH_M * 0.5 - 20.0, "s1": GrandstandScript.CENTRE_S + GrandstandScript.LENGTH_M * 0.5 + 20.0, "lateral_max": FOLIAGE_STAND_DEPTH_M},
	]
	foliage = FoliageScript.new()
	foliage.name = "Foliage"
	add_child(foliage)
	foliage.build(ribbon, keep_out)
	tree_count = foliage.tree_count


## Hands the world's sun, sky and camera to the lighting controller; call once after build().
func bind_world(world_environment: WorldEnvironment, sun: DirectionalLight3D, camera: Camera3D) -> void:
	lighting = LightingScript.new()
	lighting.name = "Lighting"
	add_child(lighting)
	lighting.bind(ribbon, furniture, vista, foliage, grandstand, world_environment, sun, camera)

func _add_multimesh(node_name: String, mesh: Mesh, transforms: Array[Transform3D], material: Material) -> void:
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
