class_name ArdennesFoliage
extends Node3D

## The Ardennes biome (mapgen sandbox, approved 2026-10-31): a dense pine forest on the hillsides, grass tufts along the verges and
## rock outcrops on the steep faces. Every repeating element is one MultiMeshInstance3D, flat cel colours, no shadows (the
## batches span the whole lap, so a shadow pass would redraw the whole forest).
##
## Where a tree may stand is decided by the NEAREST road leg's strip zone (ArdennesZones), never by a band projected across the
## loop, and always at least ROAD_CLEAR_M from any asphalt. Landmarks, decks and the water keep it out.

const TreeWindShader := preload("res://shaders/ardennes_tree_wind.gdshader")
const ToonMaterials := preload("res://scripts/world/shared/toon_materials.gd")
const Zones := preload("res://scripts/world/circuits/ardennes/ardennes_zones.gd")

const SEED: int = 20261030
const TREE_TARGET: int = 2000
const ROCK_TARGET: int = 70
const TUFT_TARGET: int = 1000
const SPACING_M: float = 16.0
## A tree stands at least this far from the asphalt (the 11.5 m armco and its floodlights stand inside).
const ROAD_CLEAR_M: float = 23.0
const FOREST_DEPTH_M: float = 130.0
## A tree stands this far behind the guardrail (which stands behind the gravel trap).
const RAIL_CLEAR_M: float = 9.0
const MAX_SLOPE: float = 0.92
const WIND_BASE: float = 0.35
## The canopy and verge colours clip to pale mint under the shared sun: the same tint the terrain wears.
const CANOPY_TINT := Color(0.74, 0.8, 0.72, 1.0)

var tree_count: int = 0
var tree_triangles: int = 0
var rock_count: int = 0
var tuft_count: int = 0
var tree_multimeshes: Array[MultiMeshInstance3D] = []
## Instance poses of each batch by node name (a headless MultiMesh keeps none).
var poses: Dictionary = {}
var _rng := RandomNumberGenerator.new()
var _wind_materials: Array[ShaderMaterial] = []
## Circles (centre, radius) the vegetation keeps out of: the landmarks.
var _keepouts: Array = []
var _terrain
var _ribbon
var _furniture


## `keepouts` are [Vector2 centre, float radius] pairs (ArdennesLandmarks.keepouts); `furniture` (the Tier A kit, optional) tells how
## far behind the road its guardrail stands, so no tree grows inside a run-off or gravel trap.
func build(ribbon, terrain, keepouts: Array, furniture = null) -> void:
	_ribbon = ribbon
	_terrain = terrain
	_keepouts = keepouts
	_furniture = furniture
	_rng.seed = SEED
	_build_forest()
	_build_tufts()
	_build_rocks()


## Pushes the wind to the swaying canopy: `strength` metres of sway at the crown, `speed` radians per second.
func set_wind(strength: float, speed: float) -> void:
	for material: ShaderMaterial in _wind_materials:
		material.set_shader_parameter("wind_strength", strength)
		material.set_shader_parameter("wind_speed", speed)


func _build_forest() -> void:
	var transforms_a: Array[Transform3D] = []
	var transforms_b: Array[Transform3D] = []
	var candidates: Array[Transform3D] = _forest_candidates()
	for index: int in range(candidates.size()):
		if index % 2 == 0:
			transforms_a.append(candidates[index])
		else:
			transforms_b.append(candidates[index])
	var tree_a: ArrayMesh = _pine_mesh(0.0)
	var tree_b: ArrayMesh = _pine_mesh(1.3)
	tree_multimeshes.append(_add_multimesh("ForestPineA", tree_a, transforms_a, true))
	tree_multimeshes.append(_add_multimesh("ForestPineB", tree_b, transforms_b, true))
	tree_count = transforms_a.size() + transforms_b.size()
	tree_triangles = transforms_a.size() * _triangles(tree_a) + transforms_b.size() * _triangles(tree_b)


func _forest_candidates() -> Array[Transform3D]:
	var out: Array[Transform3D] = []
	for band: Dictionary in Zones.SEGMENTS:
		if String(band["zone"]) != "forest":
			continue
		var side: float = float(band["side"])
		var offset: float = float(band["offset_m"])
		var depth: float = minf(float(band["depth_m"]), FOREST_DEPTH_M)
		var density: float = float(band["density"])
		var s: float = float(band["s0"])
		while s < float(band["s1"]) and out.size() < TREE_TARGET:
			var lateral: float = offset + 12.0
			while lateral < offset + depth and out.size() < TREE_TARGET:
				if _rng.randf() < density:
					var jitter_s: float = _rng.randf_range(-SPACING_M * 0.45, SPACING_M * 0.45)
					var jitter_l: float = _rng.randf_range(-SPACING_M * 0.45, SPACING_M * 0.45)
					var frame: Transform3D = _ribbon.get_point_at_offset(fposmod(s + jitter_s, _ribbon.length_m), side * (lateral + jitter_l))
					_try_tree(out, frame.origin, true)
				lateral += SPACING_M
			s += SPACING_M
	# Additional patches on the outer hillsides fill the horizon.
	var bbox: Rect2 = _terrain.bbox
	var attempts: int = 0
	while out.size() < TREE_TARGET and attempts < 9000:
		attempts += 1
		var x: float = _rng.randf_range(bbox.position.x + 30.0, bbox.end.x - 30.0)
		var z: float = _rng.randf_range(bbox.position.y + 30.0, bbox.end.y - 30.0)
		var query: Dictionary = _terrain.track_query(x, z, 80.0)
		if not query.is_empty() and float(query["d"]) < 30.0:
			continue
		if not query.is_empty() and not _behind_rail(query):
			continue
		var h: float = _terrain.height_at(x, z)
		if h < _terrain.water_level + 2.0 or _excluded(Vector2(x, z), 6.0) or _terrain.is_deck_at(x, z):
			continue
		if _slope_at(x, z) > 0.85 or _patch(x, z) < 0.35:
			continue
		out.append(_tree_transform(Vector3(x, h, z)))
	return out


func _try_tree(out: Array[Transform3D], position: Vector3, in_band: bool) -> void:
	var query: Dictionary = _terrain.track_query(position.x, position.z, 70.0)
	if not query.is_empty():
		if float(query["d"]) < ROAD_CLEAR_M:
			return
		if not _behind_rail(query):
			return
		# A band belongs to its own road leg: a point nearer another leg takes that leg's zone.
		if in_band and Zones.zone_at(float(query["s"]), float(query["side"])) != "forest":
			return
	var h: float = _terrain.height_at(position.x, position.z)
	if h < _terrain.water_level + 1.6 or _excluded(Vector2(position.x, position.z), 4.0):
		return
	if _terrain.is_deck_at(position.x, position.z) or _slope_at(position.x, position.z) > MAX_SLOPE:
		return
	out.append(_tree_transform(Vector3(position.x, h, position.z)))


func _tree_transform(position: Vector3) -> Transform3D:
	var scale: float = _rng.randf_range(0.75, 1.35)
	var basis := Basis(Vector3.UP, _rng.randf() * TAU).scaled(Vector3(scale, _rng.randf_range(0.85, 1.25) * scale, scale))
	return Transform3D(basis, position)


func _patch(x: float, z: float) -> float:
	var n: float = sin(x * 0.006 + 1.7) * cos(z * 0.005 - 0.4) + sin((x + z) * 0.0032) * 0.6
	return clampf(n * 0.5 + 0.5, 0.0, 1.0)


func _excluded(point: Vector2, margin: float) -> bool:
	for entry: Array in _keepouts:
		if point.distance_to(entry[0] as Vector2) < float(entry[1]) + margin:
			return true
	return false


func _slope_at(x: float, z: float) -> float:
	var hx: float = _terrain.height_at(x + 4.0, z) - _terrain.height_at(x - 4.0, z)
	var hz: float = _terrain.height_at(x, z + 4.0) - _terrain.height_at(x, z - 4.0)
	return sqrt(hx * hx + hz * hz) / 8.0


## A three-tier pine: a short trunk and three triangular cones, the canopy leaning on the wind shader's height-weighted sway.
func _pine_mesh(phase: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	_cylinder(st, Vector3.ZERO, 0.24, 4.4, 5, Color("#4a3a2b"))
	var greens: Array[Color] = [Color("#2f5b3a"), Color("#356844"), Color("#2b5236")]
	for layer: int in range(3):
		var base_y: float = 3.0 + float(layer) * 4.0
		var radius: float = 3.4 - float(layer) * 0.72
		var height: float = 6.2 - float(layer) * 0.5
		_cone(st, Vector3(0.0, base_y, 0.0), radius, height, 3, greens[layer], phase + float(layer))
	st.generate_normals()
	return st.commit()


func _cylinder(st: SurfaceTool, base: Vector3, radius: float, height: float, segments: int, color: Color) -> void:
	for index: int in range(segments):
		var a0: float = TAU * float(index) / float(segments)
		var a1: float = TAU * float(index + 1) / float(segments)
		var p0: Vector3 = base + Vector3(cos(a0) * radius, 0.0, sin(a0) * radius)
		var p1: Vector3 = base + Vector3(cos(a1) * radius, 0.0, sin(a1) * radius)
		var q0: Vector3 = p0 + Vector3(0.0, height, 0.0)
		var q1: Vector3 = p1 + Vector3(0.0, height, 0.0)
		for vertex: Vector3 in [p0, q0, q1, p0, q1, p1]:
			st.set_color(color)
			st.add_vertex(vertex)


func _cone(st: SurfaceTool, base: Vector3, radius: float, height: float, segments: int, color: Color, phase: float) -> void:
	var tip: Vector3 = base + Vector3(0.0, height, 0.0)
	for index: int in range(segments):
		var a0: float = TAU * float(index) / float(segments) + phase
		var a1: float = TAU * float(index + 1) / float(segments) + phase
		var p0: Vector3 = base + Vector3(cos(a0) * radius, 0.0, sin(a0) * radius)
		var p1: Vector3 = base + Vector3(cos(a1) * radius, 0.0, sin(a1) * radius)
		for vertex: Vector3 in [p0, p1, tip]:
			st.set_color(color)
			st.add_vertex(vertex)


# --- verge tufts and rocks ----------------------------------------------------------------------------

func _build_tufts() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for blade: int in range(3):
		var angle: float = float(blade) * PI / 3.0
		var across: Vector3 = Vector3(cos(angle), 0.0, sin(angle)) * 0.2
		var vertices: Array[Vector3] = [-across, across, across + Vector3(0.0, 0.9, 0.0), -across, across + Vector3(0.0, 0.9, 0.0), -across + Vector3(0.0, 0.9, 0.0)]
		for vertex: Vector3 in vertices:
			st.set_color(Color("#4a7443") if vertex.y < 0.2 else Color("#6f9555"))
			st.add_vertex(vertex)
	st.generate_normals()
	var mesh: ArrayMesh = st.commit()
	var transforms: Array[Transform3D] = []
	var s: float = 0.0
	while s < _ribbon.length_m and transforms.size() < TUFT_TARGET:
		var side: float = -1.0 if _rng.randf() < 0.5 else 1.0
		var frame: Transform3D = _ribbon.get_point_at_offset(s, side * _rng.randf_range(8.5, 20.0))
		var query: Dictionary = _terrain.track_query(frame.origin.x, frame.origin.z, 60.0)
		var blocked: bool = (not query.is_empty() and float(query["d"]) < 8.0) or _terrain.is_deck_at(frame.origin.x, frame.origin.z) or _excluded(Vector2(frame.origin.x, frame.origin.z), 3.0)
		var h: float = _terrain.height_at(frame.origin.x, frame.origin.z)
		if blocked or h < _terrain.water_level + 1.0:
			s += 5.0
			continue
		var scale: float = _rng.randf_range(0.7, 1.5)
		var basis := Basis(Vector3.UP, _rng.randf() * TAU).scaled(Vector3(scale, _rng.randf_range(0.8, 1.4) * scale, scale))
		transforms.append(Transform3D(basis, Vector3(frame.origin.x, h, frame.origin.z)))
		s += _rng.randf_range(4.0, 7.0)
	tuft_count = transforms.size()
	_add_multimesh("VergeGrass", mesh, transforms, true)


func _build_rocks() -> void:
	var mesh: ArrayMesh = _rock_mesh()
	var transforms: Array[Transform3D] = []
	var bbox: Rect2 = _terrain.bbox
	var attempts: int = 0
	while transforms.size() < ROCK_TARGET and attempts < 5000:
		attempts += 1
		var x: float = _rng.randf_range(bbox.position.x + 40.0, bbox.end.x - 40.0)
		var z: float = _rng.randf_range(bbox.position.y + 40.0, bbox.end.y - 40.0)
		var query: Dictionary = _terrain.track_query(x, z, 60.0)
		if not query.is_empty() and float(query["d"]) < 45.0:
			continue
		if _slope_at(x, z) < 0.55:
			continue
		var h: float = _terrain.height_at(x, z)
		if h < _terrain.water_level + 4.0 or _excluded(Vector2(x, z), 8.0) or _terrain.is_deck_at(x, z):
			continue
		var scale: float = _rng.randf_range(0.8, 2.8)
		var basis := Basis(Vector3.UP, _rng.randf() * TAU).scaled(Vector3(scale, scale * _rng.randf_range(0.5, 1.0), scale * _rng.randf_range(0.8, 1.2)))
		transforms.append(Transform3D(basis, Vector3(x, h - scale * 0.25, z)))
	rock_count = transforms.size()
	var instance: MultiMeshInstance3D = _add_multimesh("Rocks", mesh, transforms, false)
	if instance != null:
		instance.material_override = ToonMaterials.make(Color("#6a6256"))


func _rock_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var radii: Array[float] = [1.0, 0.82, 1.12, 0.9, 1.05, 0.78]
	var ring0: Array[Vector3] = []
	var ring1: Array[Vector3] = []
	for index: int in range(6):
		var angle: float = TAU * float(index) / 6.0
		var r: float = radii[index]
		ring0.append(Vector3(cos(angle) * r, 0.0, sin(angle) * r))
		ring1.append(Vector3(cos(angle + 0.35) * r * 0.68, 0.95 + (0.15 if index % 2 == 0 else -0.1), sin(angle + 0.35) * r * 0.68))
	var tip := Vector3(0.15, 1.55, -0.12)
	for index: int in range(6):
		var next: int = (index + 1) % 6
		for vertex: Vector3 in [ring0[index], ring1[index], ring1[next], ring0[index], ring1[next], ring0[next]]:
			st.add_vertex(vertex)
		for vertex: Vector3 in [ring1[index], tip, ring1[next]]:
			st.add_vertex(vertex)
		for vertex: Vector3 in [ring0[index], ring0[next], Vector3(0.0, -0.3, 0.0)]:
			st.add_vertex(vertex)
	st.generate_normals()
	return st.commit()


func _add_multimesh(node_name: String, mesh: Mesh, transforms: Array[Transform3D], swaying: bool) -> MultiMeshInstance3D:
	if transforms.is_empty():
		return null
	poses[node_name] = transforms
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = mesh
	multimesh.instance_count = transforms.size()
	for index: int in range(transforms.size()):
		multimesh.set_instance_transform(index, transforms[index])
	var instance := MultiMeshInstance3D.new()
	instance.name = node_name
	instance.multimesh = multimesh
	if swaying:
		var material := ShaderMaterial.new()
		material.shader = TreeWindShader
		material.set_shader_parameter("wind_strength", WIND_BASE)
		material.set_shader_parameter("tint", CANOPY_TINT)
		_wind_materials.append(material)
		instance.material_override = material
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(instance)
	return instance


func _triangles(mesh: Mesh) -> int:
	var total: int = 0
	for surface: int in range(mesh.get_surface_count()):
		total += (mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() / 3
	return total


## True where a point is clear of the guardrail and the trap in front of it: `query` is a terrain.track_query result.
func _behind_rail(query: Dictionary) -> bool:
	if _furniture == null or query.is_empty():
		return true
	var edge_distance: float = float(query["d"]) - float(_ribbon.road_half_width_m)
	return edge_distance >= float(_furniture.extent_at(float(query["side"]), float(query["s"]))) + RAIL_CLEAR_M
