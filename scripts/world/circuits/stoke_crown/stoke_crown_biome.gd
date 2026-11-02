extends Node3D

## Stoke Crown Tier B: procedural English-countryside heightfield, low distant downs, the
## environment-strip biome (broadleaf woodland, meadow tufts, hedgerows), paddock and
## urban dressing, and the five hero landmark GLBs placed on the frozen stations.
## Applies the cel-shaded look last so the whole scene is converted in one pass.
##
## Built synchronously by StokeCrownEnvironment after the ribbon and pit sockets.

const Layout := preload("res://scripts/world/circuits/stoke_crown/stoke_crown_layout.gd")
const TerrainField := preload("res://scripts/world/circuits/stoke_crown/stoke_crown_terrain.gd")
const Toon := preload("res://scripts/world/shared/toon_materials.gd")
const TreeWindShader := preload("res://shaders/stoke_crown/tree_wind.gdshader")
const ToonLookScript := preload("res://scripts/world/circuits/stoke_crown/stoke_crown_toon.gd")
const Liveries := preload("res://scripts/car/team_liveries.gd")
const Model := preload("res://scripts/world/circuits/stoke_crown/stoke_crown_model.gd")
const Strip := preload("res://scripts/world/circuits/stoke_crown/stoke_crown_strip.gd")

const ASSET_DIR := "res://assets/tracks/stoke_crown/models"
const STRIP_PATH := "res://assets/tracks/stoke_crown/data/environment_strip.json"
const ENVIRONMENT_TRIANGLE_BUDGET := 320000
const TREE_TARGET := 1600
const GRASS_TARGET := 600
const HEDGE_LIMIT := 900
const TREE_SPACING_M := 15.0
const MAX_BAND_DEPTH_M := 150.0

var ribbon: Node3D
var terrain: TerrainField
var stats: Dictionary = {}

var _compiled: Dictionary
var _segments: Array = []
var _rng := RandomNumberGenerator.new()
var _landmark_records: Array[Dictionary] = []
var _exclusion: Array = [] # [Vector2 centre, radius]


func build(p_ribbon: Node3D, compiled: Dictionary) -> void:
	var started := Time.get_ticks_msec()
	_rng.seed = 20261031
	ribbon = p_ribbon
	_compiled = compiled

	_segments = Strip.SEGMENTS
	if _segments.is_empty():
		push_warning("stoke-crown-env: environment strip missing %s" % STRIP_PATH)
	terrain = TerrainField.new(_compiled)
	_add_terrain()
	_build_exclusions()
	_build_landmarks()
	_build_paddock_dressing()
	_build_urban_plazas()
	_build_woodland()
	_build_meadow()
	_build_hedgerows()
	_finish(started)


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
	base.material_override = Toon.make(Color("#5d6d55"))
	base.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(base)
	var ridge := MeshInstance3D.new()
	ridge.name = "DistantRidge"
	ridge.mesh = terrain.ridge_mesh
	ridge.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(ridge)
	set_meta("heightgrid", terrain.heightgrid)


# --- hero landmarks --------------------------------------------------------------------

## Frozen Tier B stations (procedural-spec section 5). Asset convention (from the
## GLB author): front face at local x=0 with the body into +X, length centred on
## the origin along local Z, ground at y=0. `local_z` shifts models authored
## off-centre along the lap; the five hero models are origin-centred, so 0 keeps
## each footprint centred on its frozen station. `lat_override` moves a model
## whose placement deviates from its spec anchor.
func _landmark_specs() -> Array:
	return [
		{"stem": "crown_wing_paddock", "s": Layout.LANDMARK_WING_S, "side": 1.0,
			"offset": Layout.LANDMARK_WING_OFFSET_M, "length": 205.0, "depth": 22.0, "local_z": 0.0,
			"anchor": "ground", "note": "Crown Wing owned by CircuitPitComplex; active team fascias and crew"},
		{"stem": "runway_crossing_spitfire", "s": Layout.LANDMARK_SPITFIRE_S, "side": -1.0,
			"offset": Layout.LANDMARK_SPITFIRE_OFFSET_M, "length": 45.0, "depth": 30.0, "local_z": 0.0,
			"anchor": "ground", "note": "Wellington runway crossing + Spitfire prop monument"},
		{"stem": "luffield_arena_grandstand", "s": Layout.LANDMARK_ARENA_S, "side": -1.0,
			"offset": Layout.LANDMARK_ARENA_OFFSET_M, "length": 220.0, "depth": 38.0, "local_z": 0.0,
			"anchor": "ground", "note": "Luffield arena horseshoe grandstand"},
		{"stem": "becketts_pedestrian_flyover", "s": Layout.LANDMARK_FLYOVER_S, "side": -1.0,
			"offset": Layout.LANDMARK_FLYOVER_OFFSET_M, "length": 36.0, "depth": 28.0, "local_z": 0.0,
			"lat_override": 0.0, "anchor": "deck",
			"note": "spec anchor L offset 16 m; placed lateral 0, deck spans -16..+16 over the centreline at deck height, stairs/pylons off the pavement"},
		{"stem": "raf_hangar_tower", "s": Layout.LANDMARK_HANGAR_S, "side": 1.0,
			"offset": Layout.LANDMARK_HANGAR_OFFSET_M, "length": 90.0, "depth": 60.0, "local_z": 0.0,
			"anchor": "ground", "note": "historic RAF hangar + vintage control tower"},
	]


func _model_frame(spec: Dictionary) -> Transform3D:
	var s := float(spec["s"])
	var lateral := float(spec.get("lat_override", spec["offset"]))
	var frame := Layout.side_frame(ribbon, s, float(spec["side"]), lateral)
	# Architecture sits level: keep the frame heading but drop the road pitch, so a
	# 220 m stand is not tilted along the gradient and its base never lifts.
	var flat_forward := Vector3(-frame.basis.z.x, 0.0, -frame.basis.z.z)
	if flat_forward.length_squared() < 0.0001:
		flat_forward = Vector3.FORWARD
	flat_forward = flat_forward.normalized()
	var level_basis := Basis(flat_forward.cross(Vector3.UP).normalized(), Vector3.UP, -flat_forward)
	if String(spec["anchor"]) == "deck":
		# Sit the arch on the lowest ground under either pier so no support floats.
		var g: float = terrain.height_at(frame.origin.x, frame.origin.z)
		for sign: float in [-1.0, 1.0]:
			var pier := frame.origin + frame.basis.x * (sign * 18.0)
			g = minf(g, terrain.height_at(pier.x, pier.z))
		frame.origin.y = g + 0.02
	else:
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
		var radius := 0.5 * sqrt(length_m * length_m + depth_m * depth_m) + 8.0
		_exclusion.append([Vector2(frame.origin.x, frame.origin.z), radius])


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
	if not ResourceLoader.exists(path):
		push_warning("stoke-crown-env: missing hero landmark %s (skipped, no proxy box)" % path)
		_landmark_records.append(record)
		return
	var model: Node3D
	if stem == "crown_wing_paddock":
		model = get_parent().get_parent().get_node("PitLane/PitBuilding")
		record["placed"] = true
		record["triangles"] = _mesh_triangles(model)
		record["position"] = [model.position.x, model.position.y, model.position.z]
		_landmark_records.append(record)
		return
	model = _load_model(stem)
	if model == null:
		push_warning("stoke-crown-env: cannot read %s" % path)
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
	return Model.load_batched(path)


# --- pit boxes & crew -------------------------------------------------------------------

## Ten painted FIA pit boxes (seven-segment numbers) on the service apron, the
## 13-role standby crew line-up in each garage mouth of the Crown Wing, and the
## pit working lights (procedural-spec section 3: 10 stalls, pitch 14 m).
# --- paddock dressing ------------------------------------------------------------------

func _build_paddock_dressing() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var tents := 0
	var transporters := 0
	var vehicles := 0
	# Team tents on the paddock terrace before the pit entry, plus the post-garage end.
	for station: float in [4620.0, 4668.0, 4716.0, 4764.0, 4812.0, 250.0, 292.0]:
		var frame := _paddock_frame(station, 38.0)
		var color: Color = Liveries.color_for(tents)
		_box(st, frame, Vector3(0.0, 3.0, 0.0), Vector3(12.0, 0.3, 8.0), color.lightened(0.2))
		for corner: Vector2 in [Vector2(-5.4, -3.4), Vector2(5.4, -3.4), Vector2(-5.4, 3.4), Vector2(5.4, 3.4)]:
			_box(st, frame, Vector3(corner.x, 1.5, corner.y), Vector3(0.18, 3.0, 0.18), Color("#d7dade"))
		tents += 1
	# Team transporters parked in a row behind the tents.
	for index in range(8):
		var station := 4618.0 + float(index) * 26.0
		var frame := _paddock_frame(station, 64.0)
		var color: Color = Liveries.color_for(index + 2)
		_box(st, frame, Vector3(0.0, 1.75, 0.0), Vector3(4.6, 3.5, 12.0), Color("#e6e8ec"))
		_box(st, frame, Vector3(0.0, 2.45, 0.0), Vector3(4.65, 0.5, 12.0), color)
		_box(st, frame, Vector3(0.0, 3.3, 0.0), Vector3(4.8, 0.25, 12.4), Color("#9aa1ae"))
		transporters += 1
	# Parked support vehicles / golf carts along the working lane.
	for index in range(6):
		var station := 4632.0 + float(index) * 20.0
		var frame := _paddock_frame(station, 24.0)
		var color: Color = Liveries.color_for(index + 4)
		_box(st, frame, Vector3(0.0, 0.75, 0.0), Vector3(1.9, 1.2, 4.4), color)
		_box(st, frame, Vector3(0.0, 1.55, -0.4), Vector3(1.7, 0.9, 2.0), color.darkened(0.2))
		vehicles += 1
	# Helipad circle on the paddock apron.
	var pad_centre := _paddock_frame(4700.0, 80.0).origin + Vector3.UP * 0.02
	_disc(st, pad_centre, 9.0, 24, Color("#3d4249"))
	_disc(st, pad_centre + Vector3.UP * 0.01, 8.0, 24, Color("#2f6b46"))
	var pad_frame := _paddock_frame(4700.0, 80.0)
	for offset: Vector3 in [Vector3(-1.25, 0.0, 0.0), Vector3(1.25, 0.0, 0.0)]:
		_box(st, pad_frame, offset + Vector3.UP * 0.05, Vector3(0.7, 0.05, 5.0), Color("#f2f4f6"))
	_box(st, pad_frame, Vector3(0.0, 0.05, 0.0), Vector3(2.2, 0.05, 0.7), Color("#f2f4f6"))
	var mesh := st.commit()
	if mesh != null:
		var node := MeshInstance3D.new()
		node.name = "PaddockDressing"
		node.mesh = mesh
		node.material_override = Toon.vertex_colored(false)
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		add_child(node)
	stats["paddock_tents"] = tents
	stats["paddock_transporters"] = transporters
	stats["paddock_vehicles"] = vehicles
	stats["helipad"] = true


func _paddock_frame(station: float, lateral: float) -> Transform3D:
	var frame: Transform3D = ribbon.call("get_point_at_offset", fposmod(station, Layout.LENGTH_M), lateral)
	frame.origin.y = terrain.height_at(frame.origin.x, frame.origin.z) + 0.01
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
	stats["plaza_quads"] = quads


# --- woodland --------------------------------------------------------------------------

func _build_woodland() -> void:
	var tree_a := _broadleaf_mesh(0.0)
	var tree_b := _broadleaf_mesh(2.1)
	var transforms := _forest_candidates()
	var a: Array[Transform3D] = []
	var b: Array[Transform3D] = []
	for index in range(transforms.size()):
		if index % 2 == 0:
			a.append(transforms[index])
		else:
			b.append(transforms[index])
	var foliage := _foliage_holder()
	_add_multimesh(foliage, "BroadleafOakA", tree_a, a, 9.0, 0.22)
	_add_multimesh(foliage, "BroadleafOakB", tree_b, b, 9.0, 0.26)
	stats["tree_count"] = transforms.size()
	stats["tree_triangles"] = a.size() * _surface_triangles(tree_a) + b.size() * _surface_triangles(tree_b)


func _forest_candidates() -> Array[Transform3D]:
	var out: Array[Transform3D] = []
	for band: Dictionary in _segments:
		if String(band.get("zone", "")) != "forest":
			continue
		var side: float = -1.0 if String(band.get("side", "R")) == "L" else 1.0
		var s0: float = float(band["s0"])
		var s1: float = float(band["s1"])
		var offset: float = float(band.get("band_offset_m", 18.0))
		var depth: float = minf(float(band.get("band_depth_m", 220.0)), MAX_BAND_DEPTH_M)
		var density: float = float(band.get("density", 0.7))
		var s := s0
		while s < s1:
			var lateral := offset + 12.0
			while lateral < offset + depth:
				if out.size() >= TREE_TARGET:
					return out
				if _rng.randf() < density * 0.85:
					var station := fposmod(s + _rng.randf_range(-6.8, 6.8), Layout.LENGTH_M)
					var lat := lateral + _rng.randf_range(-6.8, 6.8)
					var frame: Transform3D = ribbon.call("get_point_at_offset", station, side * lat)
					_try_tree(out, frame.origin)
				lateral += TREE_SPACING_M
			s += TREE_SPACING_M
	# Copses filling the middle-distance fields so the horizon is not bare.
	var attempts := 0
	while out.size() < TREE_TARGET and attempts < 6000:
		attempts += 1
		var x := _rng.randf_range(terrain.bbox.position.x + 40.0, terrain.bbox.position.x + terrain.bbox.size.x - 40.0)
		var z := _rng.randf_range(terrain.bbox.position.y + 40.0, terrain.bbox.position.y + terrain.bbox.size.y - 40.0)
		var q: Dictionary = terrain.track_query(x, z, 90.0)
		if not q.is_empty() and float(q["d"]) < 90.0:
			continue
		if _noise_patch(x, z) < 0.42:
			continue
		_try_tree(out, Vector3(x, 0.0, z))
	return out


func _try_tree(out: Array[Transform3D], position: Vector3) -> void:
	var q: Dictionary = terrain.track_query(position.x, position.z, 80.0)
	if not q.is_empty() and float(q["d"]) < 24.0:
		return
	if terrain.is_flat(position.x, position.z):
		return
	if _is_excluded(Vector2(position.x, position.z), 5.0):
		return
	if _slope_at(position.x, position.z) > 0.6:
		return
	var height: float = terrain.height_at(position.x, position.z)
	var scale := _rng.randf_range(0.8, 1.35)
	var basis := Basis(Vector3.UP, _rng.randf() * TAU)
	basis = basis.scaled(Vector3(scale, scale * _rng.randf_range(0.9, 1.15), scale))
	out.append(Transform3D(basis, Vector3(position.x, height - 0.06, position.z)))


func _noise_patch(x: float, z: float) -> float:
	var n := sin(x * 0.006 + 1.7) * cos(z * 0.005 - 0.4) + sin((x + z) * 0.0032) * 0.6
	return clampf(n * 0.5 + 0.5, 0.0, 1.0)


## English broadleaf: short trunk, rounded lumpy canopy in two cel bands.
## Review LOD: 32 tris/tree (6 spokes x 2 rings) keeps 1 600 trees inside the
## 320k budget; production may restore the 3-ring 58-tri canopy.
func _broadleaf_mesh(phase: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	_cylinder(st, Vector3.ZERO, 0.26, 4.2, 4, Color("#4a3a2b"))
	var spokes := 6
	var ring_heights: Array[float] = [2.7, 5.9]
	var ring_radii: Array[float] = [3.4, 2.1]
	var ring_colors: Array[Color] = [Color("#4d7040"), Color("#5f8649")]
	var rings: Array = []
	for ring in range(2):
		var points: Array[Vector3] = []
		for index in range(spokes):
			var angle := TAU * float(index) / float(spokes)
			var radius: float = ring_radii[ring] + sin(angle * 3.0 + phase + float(ring) * 1.3) * 0.42
			points.append(Vector3(cos(angle) * radius, ring_heights[ring], sin(angle) * radius))
		rings.append(points)
	for ring in range(1):
		var lower: Array[Vector3] = rings[ring]
		var upper: Array[Vector3] = rings[ring + 1]
		for index in range(spokes):
			var next := (index + 1) % spokes
			var color: Color = ring_colors[ring].lerp(ring_colors[ring + 1], 0.5)
			for vertex: Vector3 in [lower[index], lower[next], upper[next], lower[index], upper[next], upper[index]]:
				st.set_color(color)
				st.add_vertex(vertex)
	var top: Array[Vector3] = rings[1]
	var apex := Vector3(0.15, 7.3, -0.1)
	for index in range(spokes):
		var next := (index + 1) % spokes
		for vertex: Vector3 in [top[index], top[next], apex]:
			st.set_color(ring_colors[1])
			st.add_vertex(vertex)
	var bottom: Array[Vector3] = rings[0]
	var heart := Vector3(0.0, 2.2, 0.0)
	for index in range(spokes):
		var next := (index + 1) % spokes
		for vertex: Vector3 in [bottom[next], bottom[index], heart]:
			st.set_color(ring_colors[0].darkened(0.2))
			st.add_vertex(vertex)
	st.generate_normals()
	return st.commit()


func _cylinder(st: SurfaceTool, base: Vector3, radius: float, height: float, segments: int, color: Color) -> void:
	for index in range(segments):
		var a0 := TAU * float(index) / float(segments)
		var a1 := TAU * float(index + 1) / float(segments)
		var p0 := base + Vector3(cos(a0) * radius, 0.0, sin(a0) * radius)
		var p1 := base + Vector3(cos(a1) * radius, 0.0, sin(a1) * radius)
		var q0 := p0 + Vector3(0.0, height, 0.0)
		var q1 := p1 + Vector3(0.0, height, 0.0)
		for vertex: Vector3 in [p0, q0, q1, p0, q1, p1]:
			st.set_color(color)
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
		var tries := int((s1 - s0) / 4.5)
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
	_add_multimesh(foliage, "MeadowGrass", mesh, out, 1.1, 0.12)
	stats["grass_count"] = out.size()
	stats["grass_triangles"] = out.size() * _surface_triangles(mesh)


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
			st.set_color(Color("#4a7443") if vertex.y < 0.2 else Color("#7a9c56"))
			st.add_vertex(vertex)
	st.generate_normals()
	return st.commit()


# --- hedgerows -------------------------------------------------------------------------

func _build_hedgerows() -> void:
	var out: Array[Transform3D] = []
	for band: Dictionary in _segments:
		if String(band.get("zone", "")) != "grass":
			continue
		var side: float = -1.0 if String(band.get("side", "R")) == "L" else 1.0
		var s0: float = float(band["s0"])
		var s1: float = float(band["s1"])
		var offset: float = float(band.get("band_offset_m", 16.0))
		var depth: float = minf(float(band.get("band_depth_m", 250.0)), 140.0)
		var line_lat := offset + depth * 0.42
		var s := s0 + 4.0
		while s < s1 and out.size() < HEDGE_LIMIT:
			var frame: Transform3D = ribbon.call("get_point_at_offset", fposmod(s, Layout.LENGTH_M), side * line_lat)
			_hedge_piece(out, frame, true)
			s += 7.0
		var cross := s0 + 120.0
		while cross < s1 and out.size() < HEDGE_LIMIT:
			var lateral := offset + 18.0
			while lateral < line_lat and out.size() < HEDGE_LIMIT:
				var frame: Transform3D = ribbon.call("get_point_at_offset", fposmod(cross, Layout.LENGTH_M), side * lateral)
				_hedge_piece(out, frame, false)
				lateral += 7.0
			cross += 210.0
	if out.is_empty():
		return
	var box := BoxMesh.new()
	box.size = Vector3.ONE
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = box
	mm.instance_count = out.size()
	for index in range(out.size()):
		mm.set_instance_transform(index, out[index])
	var instance := MultiMeshInstance3D.new()
	instance.name = "Hedgerows"
	instance.multimesh = mm
	instance.material_override = Toon.make(Color("#425c37"))
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_foliage_holder().add_child(instance)
	stats["hedge_count"] = out.size()
	stats["hedge_triangles"] = out.size() * 12


func _hedge_piece(out: Array[Transform3D], frame: Transform3D, along_track: bool) -> void:
	var position := frame.origin
	if terrain.is_flat(position.x, position.z):
		return
	if _is_excluded(Vector2(position.x, position.z), 4.0):
		return
	var q: Dictionary = terrain.track_query(position.x, position.z, 40.0)
	if not q.is_empty() and float(q["d"]) < 13.0:
		return
	if _slope_at(position.x, position.z) > 0.5:
		return
	var height: float = terrain.height_at(position.x, position.z)
	var basis := frame.basis
	if along_track:
		basis = basis * Basis(Vector3.UP, PI * 0.5)
	basis = basis * Basis(Vector3.UP, _rng.randf_range(-0.06, 0.06))
	basis = basis.scaled(Vector3(_rng.randf_range(7.0, 8.2), _rng.randf_range(1.2, 1.8), 1.15))
	out.append(Transform3D(basis, Vector3(position.x, height - 0.2, position.z)))


# --- completion ------------------------------------------------------------------------

func _finish(started: int) -> void:
	var elapsed := Time.get_ticks_msec() - started
	stats["build_ms"] = elapsed
	stats["terrain_triangles"] = terrain.triangles()
	var range_m: Vector2 = terrain.elevation_range()
	stats["terrain_min_y"] = snappedf(range_m.x, 0.01)
	stats["terrain_max_y"] = snappedf(range_m.y, 0.01)
	stats["roadbed_drop_m"] = Layout.ROADBED_DROP_M
	stats["landmarks"] = _landmark_records
	var placed := 0
	var landmark_triangles := 0
	for record: Dictionary in _landmark_records:
		if bool(record.get("placed", false)):
			placed += 1
			landmark_triangles += int(record.get("triangles", 0))
	stats["landmarks_placed"] = placed
	stats["landmark_triangles"] = landmark_triangles
	stats["environment_triangles"] = _count_triangles(self)
	stats["triangle_budget"] = ENVIRONMENT_TRIANGLE_BUDGET
	_toon()
	set_meta("env_stats", stats)
	set_meta("heightgrid", terrain.heightgrid)
	set_meta("built", true)
	print("[stoke-crown-env] built in %.2fs | terrain tris %d | trees %d | grass %d | hedges %d | landmarks %d/%d | env tris %d (budget %d)" % [
		float(elapsed) / 1000.0,
		int(stats["terrain_triangles"]),
		int(stats.get("tree_count", 0)),
		int(stats.get("grass_count", 0)),
		int(stats.get("hedge_count", 0)),
		placed,
		_landmark_records.size(),
		int(stats["environment_triangles"]),
		ENVIRONMENT_TRIANGLE_BUDGET,
	])


func _toon() -> void:
	ToonLookScript.apply_materials(self)


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
		st.set_color(color)
		st.add_vertex(vertex)


## Double-sided box so no face can be missed at an oblique review angle.
func _box(st: SurfaceTool, frame: Transform3D, centre: Vector3, size: Vector3, color: Color) -> void:
	var corners: Array[Vector3] = []
	for x: float in [-1.0, 1.0]:
		for y: float in [-1.0, 1.0]:
			for z: float in [-1.0, 1.0]:
				corners.append(frame * (centre + Vector3(x * size.x * 0.5, y * size.y * 0.5, z * size.z * 0.5)))
	var faces: Array = [
		[0, 1, 3, 2], [4, 6, 7, 5], [0, 4, 5, 1],
		[2, 3, 7, 6], [0, 2, 6, 4], [1, 5, 7, 3],
	]
	for face: Array in faces:
		var a := corners[face[0]]
		var b := corners[face[1]]
		var c := corners[face[2]]
		var d := corners[face[3]]
		for vertex: Vector3 in [a, b, c, a, c, d, a, c, b, a, d, c]:
			st.set_color(color)
			st.add_vertex(vertex)


func _disc(st: SurfaceTool, centre: Vector3, radius: float, segments: int, color: Color) -> void:
	for index in range(segments):
		var a0 := TAU * float(index) / float(segments)
		var a1 := TAU * float(index + 1) / float(segments)
		var p0 := centre + Vector3(cos(a0) * radius, 0.0, sin(a0) * radius)
		var p1 := centre + Vector3(cos(a1) * radius, 0.0, sin(a1) * radius)
		for vertex: Vector3 in [centre, p0, p1, centre, p1, p0]:
			st.set_color(color)
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
