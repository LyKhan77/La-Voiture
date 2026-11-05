extends Node3D

## Cel-shaded review look for the Paulistano Speed Arena build: converts every imported/kit
## material to the two-tone toon pipeline (ink outlines on architecture, Ben-Day
## glass), binds the shared cel sky and drives DAY / SUNSET / NIGHT. Mirrors the
## Approved Route 2 look, ported into the production Paulistano module.

const Toon := preload("res://scripts/world/shared/toon_materials.gd")
const SkyController := preload("res://scripts/world/shared/shared_cel_sky_controller.gd")
const GlassShader := preload("res://shaders/paulistano_anime_glass.gdshader")
const RoadShader := preload("res://shaders/road_asphalt.gdshader")

const FLAT_NAMES := ["Terrain", "DistantRidge", "Road", "PitLane", "Apron", "Paint", "Terrace", "Quay", "River", "Water", "Ground", "Groove", "Kerb", "Runoff", "Gravel", "bush", "Scrub", "Fence", "Forest", "Rocks", "Plinth", "Armco", "Tecpro", "Braking", "Floodlight", "FlagPanels"]

var _sky: RefCounted
var _world: Node3D
var _water_material: ShaderMaterial
var _water_time := 0.0
var mode := 0


static func apply(root: Node3D) -> void:
	apply_materials(root)
	var look := root.get_node_or_null("ToonLook")
	if look == null:
		look = (load("res://scripts/world/circuits/paulistano/paulistano_toon.gd") as Script).new()
		look.name = "ToonLook"
		root.add_child(look)
	look.call("configure", root)


static func apply_materials(root: Node, ink_width: float = 0.06) -> void:
	_visit(root, {}, ink_width)


## Production pass: convert every material to the cel pipeline, add the cool fill
## light and wet the 60%-rain asphalt. The environment drives the shared cel sky
## and WorldSkyRig itself, so the review-only sky node is not created here.
static func apply_visuals(root: Node3D) -> void:
	apply_materials(root)
	if root.get_node_or_null("FillLight") == null:
		var fill := DirectionalLight3D.new()
		fill.name = "FillLight"
		fill.rotation_degrees = Vector3(-28.0, 142.0, 0.0)
		fill.light_color = Color("#c9dcec")
		fill.light_energy = 0.14
		fill.shadow_enabled = false
		root.add_child(fill)
	_apply_wet_track(root)


static func _visit(node: Node, cache: Dictionary, ink_width: float) -> void:
	if node is GeometryInstance3D:
		var geometry := node as GeometryInstance3D
		var outlined := true
		for flat: String in FLAT_NAMES:
			if flat.to_lower() in String(node.name).to_lower():
				outlined = false
				break
		if geometry.material_override:
			geometry.material_override = _convert(geometry.material_override, cache, outlined, ink_width)
		elif node is MeshInstance3D and node.mesh:
			for index in node.mesh.get_surface_count():
				var material: Material = node.get_active_material(index)
				node.set_surface_override_material(index, _convert(material, cache, outlined, ink_width))
		elif node is MultiMeshInstance3D and node.multimesh and node.multimesh.mesh:
			var mesh: Mesh = node.multimesh.mesh.duplicate()
			for index in mesh.get_surface_count():
				mesh.surface_set_material(index, _convert(mesh.surface_get_material(index), cache, outlined, ink_width))
			node.multimesh.mesh = mesh
	for child: Node in node.get_children():
		if child.is_inside_tree():
			_visit(child, cache, ink_width)


static func _convert(source: Material, cache: Dictionary, outlined: bool, width: float) -> Material:
	if source == null:
		return Toon.make(Color("#d8d2bd"), outlined)
	var key := "%s:%s:%s" % [source.get_instance_id(), outlined, width]
	if cache.has(key):
		return cache[key]
	var result: Material = source
	if source is ShaderMaterial:
		var shader: Shader = source.shader
		if shader == Toon.CelShader or shader == Toon.VertexColorShader:
			var cel := source.duplicate() as ShaderMaterial
			cel.set_shader_parameter("rim_color", Color("#cfe0d2"))
			cel.set_shader_parameter("rim_intensity", 0.07 if outlined else 0.0)
			cel.set_shader_parameter("shadow_tint", Color("#7f97a0") if outlined else Color("#aeb8bf"))
			result = cel
		elif shader == RoadShader:
			var road := source.duplicate() as ShaderMaterial
			var variant := Shader.new()
			variant.resource_name = "RoadAsphaltToon"
			variant.code = RoadShader.code.replace("render_mode cull_disabled;", "render_mode cull_disabled, diffuse_toon, specular_toon;")
			road.shader = variant
			result = road
	elif source is StandardMaterial3D:
		var base := source as StandardMaterial3D
		var glass := "glass" in source.resource_name.to_lower() or (base.transparency == BaseMaterial3D.TRANSPARENCY_ALPHA and base.albedo_texture == null and not base.vertex_color_use_as_albedo)
		if glass:
			var material := ShaderMaterial.new()
			material.shader = GlassShader
			material.set_shader_parameter("base_color", base.albedo_color)
			result = material
		elif base.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED or base.emission_enabled or (base.albedo_texture != null and base.vertex_color_use_as_albedo):
			var material := base
			material.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON
			material.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
			material.metallic = 0.0
			material.roughness = 1.0
			result = material
		else:
			var material := ShaderMaterial.new()
			if base.vertex_color_use_as_albedo:
				material.shader = Toon.VertexColorShader
				material.set_shader_parameter("tint", base.albedo_color)
			else:
				material.shader = Toon.CelShader
				material.set_shader_parameter("base_color", base.albedo_color)
				if base.albedo_texture:
					material.set_shader_parameter("albedo_texture", base.albedo_texture)
			material.set_shader_parameter("shadow_tint", Color("#7f97a0") if outlined else Color("#aeb8bf"))
			material.set_shader_parameter("rim_color", Color("#cfe0d2"))
			material.set_shader_parameter("rim_intensity", 0.07 if outlined else 0.0)
			result = material
	if result != source and outlined:
		var ink := ShaderMaterial.new()
		ink.shader = Toon.OutlineShader
		ink.set_shader_parameter("outline_width", width)
		ink.set_shader_parameter("outline_color", Color("#16221a"))
		result.next_pass = ink
	cache[key] = result
	return result


func configure(root: Node3D) -> void:
	_world = root
	if root.get_viewport() != null:
		root.get_viewport().msaa_3d = Viewport.MSAA_4X
	var ambience := root.get_node_or_null("CelSkyAmbience") as Node3D
	if ambience:
		_sky = SkyController.new()
		_sky.sky_ambience_root = ambience
		_sky.moon_instance = ambience.get_node("AnimeMoon")
		_sky.star_instance = ambience.get_node("NightStars")
		_sky.cloud_instance = ambience.get_node("AnimeNightClouds")
		_sky.moon_material = _sky.moon_instance.material_override
		_sky.star_material = _sky.star_instance.material_override
		_sky.cloud_material = _sky.cloud_instance.material_override
	if root.get_node_or_null("FillLight") == null:
		var fill := DirectionalLight3D.new()
		fill.name = "FillLight"
		fill.rotation_degrees = Vector3(-28.0, 142.0, 0.0)
		fill.light_color = Color("#c9dcec")
		fill.light_energy = 0.14
		fill.shadow_enabled = false
		root.add_child(fill)
	var river := root.find_child("River", true, false) as MeshInstance3D
	if river and river.material_override is ShaderMaterial:
		_water_material = river.material_override
	_apply_wet_track(root)
	apply_time_of_day(0)


## Paulistano weather sync: the calendar carries rain_probability 0.60, so the review
## build ships a damp track (banded puddles + ripple rings) on every asphalt
## surface. The shared road shader already exposes the uniforms; this only drives
## them from the circuit weather instead of the race VFX system.
static func _apply_wet_track(root: Node) -> void:
	for node in root.find_children("*", "GeometryInstance3D", true, false):
		var mesh: Mesh = null
		if node is MeshInstance3D:
			mesh = node.mesh
		elif node is MultiMeshInstance3D and node.multimesh:
			mesh = node.multimesh.mesh
		if mesh == null:
			continue
		for index in mesh.get_surface_count():
			var material: Material = node.get_active_material(index) if node is MeshInstance3D else (node.material_override if node.material_override else mesh.surface_get_material(index))
			if material is ShaderMaterial and (material as ShaderMaterial).shader != null and "track_wetness" in (material as ShaderMaterial).shader.code:
				material.set_shader_parameter("track_wetness", 0.55)
				material.set_shader_parameter("rain_intensity", 0.50)
				material.set_shader_parameter("puddle_scale", 0.13)
				material.set_shader_parameter("wet_roughness", 0.32)
				material.set_shader_parameter("paint_wear", 0.52)


func _process(delta: float) -> void:
	if _sky:
		_sky.apply_wind(delta, 14.0)
	if _water_material:
		_water_time += delta
		_water_material.set_shader_parameter("time_s", _water_time)


func apply_time_of_day(value: int) -> void:
	mode = clampi(value, 0, 2)
	var night := mode == 2
	# Tropical São Paulo sky: a tall bright cumulonimbus deck, hazy reservoir
	# horizon and the 70% storm probability (wet asphalt, lake humidity). Sunset
	# keeps the golden haze under the deck; night is a deep storm-blue sky.
	var gloom: float = 0.0
	if _sky:
		_sky.apply_time_of_day({"mode": mode, "floodlights": 1.0 if night else (0.4 if mode == 1 else 0.0), "stars_opacity": 1.0 if night else 0.0}, gloom)
		if _sky.cloud_material:
			_sky.cloud_material.set_shader_parameter("cloud_shadow", [Color("#8fa9b0"), Color("#9a7280"), Color("#141d33")][mode])
			_sky.cloud_material.set_shader_parameter("cloud_mid", [Color("#f2f7f6"), Color("#efae7c"), Color("#35486b")][mode])
			_sky.cloud_material.set_shader_parameter("cloud_rim", [Color("#ffffff"), Color("#ffd9a8"), Color("#b8e4ff")][mode])
	var world_environment := _world.get_node_or_null("WorldEnvironment") as WorldEnvironment
	if world_environment:
		var environment := world_environment.environment.duplicate() as Environment
		world_environment.environment = environment
		environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
		environment.tonemap_exposure = 1.02
		environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		environment.ambient_light_color = [Color("#d5e7e4"), Color("#e6b48f"), Color("#5f7ba4")][mode]
		environment.ambient_light_energy = [0.28, 0.32, 0.23][mode]
		environment.fog_enabled = true
		environment.fog_light_color = [Color("#cbe2e0"), Color("#e9c39a"), Color("#182639")][mode]
		environment.fog_density = [0.00008, 0.00016, 0.00035][mode]
		environment.fog_sky_affect = 0.35
		environment.adjustment_enabled = true
		environment.adjustment_saturation = 1.02
		environment.adjustment_contrast = 1.05
		environment.adjustment_brightness = 1.0
		environment.volumetric_fog_enabled = true
		environment.volumetric_fog_density = [0.0008, 0.0014, 0.004][mode]
		environment.volumetric_fog_albedo = Color("#c9d3d5")
		environment.volumetric_fog_length = 2600.0
		var sky := Sky.new()
		var sky_material := ProceduralSkyMaterial.new()
		sky_material.sky_top_color = [Color("#4f9fd8"), Color("#8a6f9e"), Color("#091426")][mode]
		sky_material.sky_horizon_color = [Color("#cfe8ee"), Color("#f8c28c"), Color("#243a50")][mode]
		sky_material.ground_bottom_color = Color("#3d5233")
		sky_material.ground_horizon_color = sky_material.sky_horizon_color
		sky_material.sun_angle_max = 0.0
		sky_material.sky_energy_multiplier = [1.35, 1.18, 1.0][mode]
		sky.sky_material = sky_material
		environment.sky = sky
	var sun := _world.get_node_or_null("Sun") as DirectionalLight3D
	if sun:
		sun.rotation_degrees = [Vector3(-52, -118, 0), Vector3(-14, -104, 0), Vector3(-40, 92, 0)][mode]
		sun.light_color = [Color("#fff6df"), Color("#ff9f63"), Color("#9cb6d9")][mode]
		sun.light_energy = [1.15, 0.75, 0.38][mode]
		sun.shadow_enabled = true
	Toon.set_glow_energy(0.8 if night else (0.22 if mode == 1 else 0.0))
	for node in _world.find_children("*", "GeometryInstance3D", true, false):
		if not node.is_inside_tree():
			continue
		var mesh: Mesh = node.mesh if node is MeshInstance3D else (node.multimesh.mesh if node is MultiMeshInstance3D and node.multimesh else null)
		if mesh == null:
			continue
		for index in mesh.get_surface_count():
			var material: Material = node.get_active_material(index) if node is MeshInstance3D else (node.material_override if node.material_override else mesh.surface_get_material(index))
			if material is ShaderMaterial and material.shader == GlassShader:
				material.set_shader_parameter("glow_energy", 0.22 if night else 0.0)
			elif material is ShaderMaterial and material.shader == Toon.VertexColorShader:
				material.set_shader_parameter("glow_energy", 0.8 if night else (0.22 if mode == 1 else 0.0))
	if _water_material:
		_water_material.set_shader_parameter("deep_color", [Color("#06384a"), Color("#3c2a40"), Color("#05182a")][mode])
		_water_material.set_shader_parameter("band_color", [Color("#0d6373"), Color("#6a4656"), Color("#0f3149")][mode])
		_water_material.set_shader_parameter("neon_ripple_cyan", [Color("#b7e6e6"), Color("#ffd0a3"), Color("#39a6b6")][mode])
		_water_material.set_shader_parameter("neon_ripple_magenta", [Color("#b7e6e6"), Color("#ffd0a3"), Color("#39a6b6")][mode])
		_water_material.set_shader_parameter("crest_emission", 0.2 if night else 0.08)
		_water_material.set_shader_parameter("band_length_m", 18.0)
		_water_material.set_shader_parameter("band_emission", 0.28)
	_apply_flood_spots(mode)


func _apply_flood_spots(value: int) -> void:
	var existing := _world.get_node_or_null("NightFloodSpots")
	if existing:
		existing.free()
	if value == 0:
		return
	var furniture := _world.find_child("TracksideFurniture", true, false)
	var ribbon := _world.find_child("TrackRibbon", true, false)
	if furniture == null or ribbon == null or not ("tower_records" in furniture):
		return
	var records: Array = furniture.get("tower_records")
	if records.is_empty():
		return
	var holder := Node3D.new()
	holder.name = "NightFloodSpots"
	_world.add_child(holder)
	var level := 1.0 if value == 2 else 0.45
	var stride := maxi(1, records.size() / 8)
	for index in range(0, mini(8 * stride, records.size()), stride):
		var record: Dictionary = records[index]
		var spot := SpotLight3D.new()
		spot.light_color = Color(1.0, 0.93, 0.8)
		spot.spot_range = 110.0
		spot.spot_angle = 46.0
		spot.light_energy = 5.2 * level
		spot.shadow_enabled = false
		holder.add_child(spot)
		spot.global_position = (record["position"] as Vector3) + Vector3.UP * 17.2
		spot.look_at(ribbon.call("get_point_at_offset", float(record["s"]), 0.0).origin, Vector3.UP)
