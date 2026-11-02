extends Node3D

## Pacific Coast Corkscrew Tier B: procedural Monterey golden-hills heightfield, a low
## distant ochre ridge, the California chaparral biome (1 500 Coast Live Oak, dry grass
## tufts, chaparral scrub), paddock dressing, and the three approved hero landmark GLBs
## on their frozen stations. Built synchronously by PacificCorkscrewEnvironment after
## the ribbon and pit sockets; the cel look is applied last.
##
## The approved sandbox builder is the visual source; this module translates it to the
## production contracts (baked strip, batched GLBs, terrain stats, production assets).

const Layout := preload("res://scripts/world/circuits/pacific_corkscrew/pacific_corkscrew_layout.gd")
const TerrainField := preload("res://scripts/world/circuits/pacific_corkscrew/pacific_corkscrew_terrain.gd")
const Toon := preload("res://scripts/world/shared/toon_materials.gd")
const TreeWindShader := preload("res://shaders/pacific_corkscrew/tree_wind.gdshader")
const ToonLookScript := preload("res://scripts/world/circuits/pacific_corkscrew/pacific_corkscrew_toon.gd")
const Liveries := preload("res://scripts/car/team_liveries.gd")
const Model := preload("res://scripts/world/circuits/pacific_corkscrew/pacific_corkscrew_model.gd")
const Strip := preload("res://scripts/world/circuits/pacific_corkscrew/pacific_corkscrew_strip.gd")
const MeshBatchScript := preload("res://scripts/world/shared/mesh_batch.gd")
const PitKit := preload("res://scripts/world/shared/pit_kit.gd")
const PitCrewFigureScript := preload("res://scripts/car/pit_crew_figure.gd")

const ASSET_DIR := "res://assets/tracks/pacific_corkscrew/models"
const ENVIRONMENT_TRIANGLE_BUDGET := 320000
const TREE_TARGET := 1500
const GRASS_TARGET := 900
const SHRUB_LIMIT := 900
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
		push_warning("pacific-env: environment strip missing")
	terrain = TerrainField.new(_compiled)
	print("[pacific-env] terrain %.2fs" % (float(Time.get_ticks_msec() - started) / 1000.0))
	_add_terrain()
	_build_exclusions()
	_build_landmarks()
	print("[pacific-env] landmarks %.2fs" % (float(Time.get_ticks_msec() - started) / 1000.0))
	_build_paddock_dressing()
	print("[pacific-env] paddock %.2fs" % (float(Time.get_ticks_msec() - started) / 1000.0))
	_build_woodland()
	print("[pacific-env] woodland %.2fs" % (float(Time.get_ticks_msec() - started) / 1000.0))
	_build_meadow()
	_build_chaparral()
	print("[pacific-env] foliage %.2fs" % (float(Time.get_ticks_msec() - started) / 1000.0))
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
	base.material_override = Toon.make(Color("#9a8250"))
	base.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(base)
	var ridge := MeshInstance3D.new()
	ridge.name = "DistantRidge"
	ridge.mesh = terrain.ridge_mesh
	ridge.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(ridge)
	set_meta("heightgrid", terrain.heightgrid)


# --- hero landmarks --------------------------------------------------------------------

## Frozen Tier B stations (procedural-spec section 4). Asset convention (from the
## GLB author): ground at y=0, centred on the origin within its footprint. The
## pedestrian arch deck spans local X; the amphitheatre body extends into +X.
func _landmark_specs() -> Array:
	return [
		{"stem": "lone_oak_tree", "s": Layout.LANDMARK_OAK_S, "side": 1.0,
			"offset": Layout.LANDMARK_OAK_OFFSET_M, "length": 16.0, "depth": 16.0, "local_z": 0.0,
			"anchor": "terrain", "note": "The Lone Oak Tree – landmark braking reference on the Corkscrew crest"},
		{"stem": "pedestrian_arch_bridge", "s": Layout.LANDMARK_ARCH_S, "side": -1.0,
			"offset": Layout.LANDMARK_ARCH_OFFSET_M, "length": 36.0, "depth": 8.0, "local_z": 0.0,
			"lat_override": 0.0, "anchor": "deck",
			"note": "spec anchor L offset 12 m; placed lateral 0 so the arch deck spans the main straight, piers off the asphalt"},
		{"stem": "corkscrew_amphitheater", "s": Layout.LANDMARK_AMPHITHEATRE_S, "side": -1.0,
			"offset": Layout.LANDMARK_AMPHITHEATRE_OFFSET_M, "length": 180.0, "depth": 57.0, "local_z": 0.0,
			"anchor": "ground", "note": "natural hill-terrace spectator amphitheatre overlooking The Corkscrew"},
	]


func _model_frame(spec: Dictionary) -> Transform3D:
	var s := float(spec["s"])
	var lateral := float(spec.get("lat_override", spec["offset"]))
	var frame := Layout.side_frame(ribbon, s, float(spec["side"]), lateral)
	# Architecture sits level: keep the frame heading but drop the road pitch, so a
	# 180 m terrace is not tilted along the gradient and its base never lifts.
	var flat_forward := Vector3(-frame.basis.z.x, 0.0, -frame.basis.z.z)
	if flat_forward.length_squared() < 0.0001:
		flat_forward = Vector3.FORWARD
	flat_forward = flat_forward.normalized()
	var level_basis := Basis(flat_forward.cross(Vector3.UP).normalized(), Vector3.UP, -flat_forward)
	match String(spec["anchor"]):
		"deck":
			# Sit the arch on the lowest ground under either pier so no support floats.
			var g: float = terrain.height_at(frame.origin.x, frame.origin.z)
			for sign: float in [-1.0, 1.0]:
				var pier := frame.origin + frame.basis.x * (sign * 17.0)
				g = minf(g, terrain.height_at(pier.x, pier.z))
			frame.origin.y = g + 0.02
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
	if not FileAccess.file_exists(path):
		push_warning("pacific-env: missing hero landmark %s (skipped, no proxy box)" % path)
		_landmark_records.append(record)
		return
	var model := _load_model(stem)
	if model == null:
		push_warning("pacific-env: cannot read %s" % path)
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
	return Model.load_batched("%s/%s.glb" % [ASSET_DIR, stem])


# --- paddock dressing ------------------------------------------------------------------

func _build_paddock_dressing() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var tents := 0
	var vehicles := 0
	var motorhomes := 0
	var generators := 0
	# Solid team hospitality tents (walls + floor, not floating roofs) on the terrace.
	for station: float in [3935.0, 3983.0, 4031.0, 4079.0, 235.0, 283.0]:
		var frame := _paddock_frame(station, 40.0)
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
	# One team transporter per garage is built by the shared TeamTransporters kit
	# in the pit complex; the biome does not duplicate it.
	# Motorhomes / hospitality units along the paddock boulevard.
	for index in range(8):
		var station: float = 228.0 + float(index % 4) * 19.0 if index < 4 else 3944.0 + float(index - 4) * 41.0
		var frame := _paddock_frame(station, 66.0)
		var color: Color = Liveries.color_for(index + 2)
		_box(st, frame, Vector3(0.0, 1.8, 0.0), Vector3(3.2, 3.6, 9.0), Color("#eceae2"))
		_box(st, frame, Vector3(0.0, 2.65, 0.0), Vector3(3.24, 0.45, 9.0), color)
		_box(st, frame, Vector3(1.62, 2.0, -1.2), Vector3(0.05, 1.1, 3.2), Color("#4f7fa8"))
		_box(st, frame, Vector3(-1.62, 2.0, 1.2), Vector3(0.05, 1.1, 3.2), Color("#4f7fa8"))
		motorhomes += 1
	# Parked support vehicles / golf carts along the post-garage apron.
	for index in range(6):
		var station := 224.0 + float(index) * 11.0
		var frame := _paddock_frame(station, 30.0)
		var color: Color = Liveries.color_for(index + 4)
		_box(st, frame, Vector3(0.0, 0.75, 0.0), Vector3(1.9, 1.2, 4.4), color)
		_box(st, frame, Vector3(0.0, 1.55, -0.4), Vector3(1.7, 0.9, 2.0), color.darkened(0.2))
		vehicles += 1
	# Generator / fuel units in the service lane behind the garages.
	for station: float in [62.0, 104.0, 146.0, 188.0]:
		var frame := _paddock_frame(station, 36.0)
		_box(st, frame, Vector3(0.0, 0.8, 0.0), Vector3(2.4, 1.6, 3.6), Color("#6f7680"))
		_box(st, frame, Vector3(0.0, 1.65, 0.0), Vector3(2.5, 0.12, 3.7), Color("#3a3f4a"))
		_box(st, frame, Vector3(1.22, 0.9, 0.0), Vector3(0.05, 0.9, 2.2), Color("#ffd400"))
		generators += 1
	# Helipad circle on the paddock apron.
	var pad_centre := _paddock_frame(270.0, 78.0).origin + Vector3.UP * 0.02
	_disc(st, pad_centre, 9.0, 24, Color("#3d4249"))
	_disc(st, pad_centre + Vector3.UP * 0.01, 8.0, 24, Color("#2f6b46"))
	var pad_frame := _paddock_frame(270.0, 78.0)
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
		var station := _rng.randf_range(3900.0, 4095.0) if placed_people % 2 == 0 else _rng.randf_range(220.0, 295.0)
		var lateral := _rng.randf_range(22.0, 92.0)
		var local_s := fposmod(station, Layout.LENGTH_M)
		if local_s >= 20.0 and local_s <= 220.0 and lateral < 34.0:
			continue
		if Vector2(station - 270.0, lateral - 78.0).length() < 11.0:
			continue
		var frame: Transform3D = ribbon.call("get_point_at_offset", station, lateral)
		var ground: float = float(terrain.height_at(frame.origin.x, frame.origin.z))
		var yaw := _rng.randf() * TAU
		PitCrewFigureScript.add(crowd, crowd_flat, Transform3D(Basis(Vector3.UP, yaw), Vector3(frame.origin.x, ground + 0.01, frame.origin.z)), int(roles[placed_people % roles.size()]), Liveries.color_for(placed_people % 10))
		placed_people += 1
	var crowd_node := MeshInstance3D.new()
	crowd_node.name = "PaddockCrowd"
	crowd_node.mesh = crowd.commit()
	crowd_node.material_override = crowd_flat
	crowd_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(crowd_node)
	stats["paddock_tents"] = tents
	var pit := ribbon.get_parent().get_node_or_null("PitLane")
	var transporters: Array = []
	if pit != null and pit.get("transporters") != null:
		transporters = pit.get("transporters").get("transporter_poses")
	stats["paddock_transporters"] = transporters.size()
	stats["paddock_motorhomes"] = motorhomes
	stats["paddock_vehicles"] = vehicles
	stats["paddock_generators"] = generators
	stats["paddock_people"] = placed_people
	stats["paddock_parking_cars"] = int(grounds["cars"])
	stats["paddock_palms"] = int(grounds["palms"])
	stats["paddock_umbrellas"] = int(grounds["umbrellas"])
	stats["paddock_boards"] = int(grounds["boards"])
	stats["helipad"] = true


## Paddock grounds: parked cars, palms, fan-zone umbrellas and sponsor boards so
## the wide apron around the pit block is not a bare slab.
func _build_paddock_grounds(st: SurfaceTool) -> Dictionary:
	var cars := 0
	var palms := 0
	var umbrellas := 0
	var boards := 0
	# Two parking rows on the outer apron (stations wrap across the start line).
	for index in range(12):
		_car(st, _paddock_frame(3850.0 + float(index) * 20.0, 74.0), Liveries.color_for(index))
		cars += 1
	for index in range(13):
		_car(st, _paddock_frame(18.0 + float(index) * 20.0, 86.0), Liveries.color_for(index + 3))
		cars += 1
	# White bay lines between the parked cars.
	for row: float in [74.0, 86.0]:
		for index in range(13):
			var line_s: float = 8.0 + float(index) * 20.0 if row > 80.0 else 3840.0 + float(index) * 20.0
			var line := _paddock_frame(line_s, row - 1.6)
			_box(st, line, Vector3(0.0, 0.02, 0.0), Vector3(4.0, 0.02, 0.16), Color("#e8e6dc"))
	# Californian fan-zone palms along the paddock boulevard.
	for station: float in [30.0, 78.0, 126.0, 174.0, 222.0, 270.0, 3980.0, 4040.0, 4090.0]:
		_palm(st, _paddock_frame(station, 82.0), 8.5 + float(palms % 3) * 1.1)
		palms += 1
	# Umbrellas + tables around the hospitality tents.
	for index in range(12):
		var station: float = 240.0 + float(index % 6) * 9.0 if index < 6 else 3970.0 + float(index - 6) * 17.0
		var frame := _paddock_frame(station, 50.0 + float(index % 3) * 5.0)
		_umbrella(st, frame, Liveries.color_for(index))
		umbrellas += 1
	# Sponsor boards on the apron, facing the track.
	for index in range(8):
		var station: float = 232.0 + float(index % 4) * 18.0 if index < 4 else 3945.0 + float(index - 4) * 34.0
		var frame := _paddock_frame(station, 44.0)
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


func _palm(st: SurfaceTool, frame: Transform3D, height: float) -> void:
	_box(st, frame, Vector3(0.0, height * 0.5, 0.0), Vector3(0.36, height, 0.36), Color("#8a6a45"))
	var top := frame * Vector3(0.0, height, 0.0)
	for frond in range(7):
		var angle := TAU * float(frond) / 7.0
		var dir := Vector3(cos(angle), 0.0, sin(angle))
		var side := Vector3(-dir.z, 0.0, dir.x) * 0.55
		var mid: Vector3 = top + dir * 1.6 + Vector3.UP * 0.15
		var tip: Vector3 = top + dir * 3.2 - Vector3.UP * 0.9
		_quad_color(st, mid + side, mid - side, tip - side * 0.5, tip + side * 0.5, Vector3.UP, Color("#3f6b3a"))
		_quad_color(st, mid - side, mid + side, tip + side * 0.5, tip - side * 0.5, Vector3.DOWN, Color("#355c32"))


func _umbrella(st: SurfaceTool, frame: Transform3D, color: Color) -> void:
	_box(st, frame, Vector3(0.0, 1.2, 0.0), Vector3(0.08, 2.4, 0.08), Color("#6d7480"))
	_disc(st, frame * Vector3(0.0, 2.6, 0.0), 1.7, 10, color)
	var top := frame * Vector3(0.0, 0.0, 0.0)
	_box(st, frame, Vector3(0.0, 0.38, 0.0), Vector3(0.12, 0.76, 0.12), Color("#6d7480"))
	_disc(st, top + Vector3.UP * 0.8, 0.7, 8, Color("#e8e2d4"))


func _paddock_frame(station: float, lateral: float) -> Transform3D:
	var frame: Transform3D = ribbon.call("get_point_at_offset", fposmod(station, Layout.LENGTH_M), lateral)
	frame.origin.y = terrain.height_at(frame.origin.x, frame.origin.z) + 0.01
	return frame


# --- woodland --------------------------------------------------------------------------

func _build_woodland() -> void:
	var tree_a := _oak_mesh(0.0)
	var tree_b := _oak_mesh(2.1)
	var transforms := _forest_candidates()
	var a: Array[Transform3D] = []
	var b: Array[Transform3D] = []
	for index in range(transforms.size()):
		if index % 2 == 0:
			a.append(transforms[index])
		else:
			b.append(transforms[index])
	var foliage := _foliage_holder()
	_add_multimesh(foliage, "LiveOakA", tree_a, a, 9.0, 0.20)
	_add_multimesh(foliage, "LiveOakB", tree_b, b, 9.0, 0.24)
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


## Coast Live Oak (Quercus agrifolia): short thick trunk and a broad, dense,
## dark-olive dome in two cel bands. Review LOD: ~56 tris/tree keeps 1 500 oaks
## inside the environment budget; production may restore the 3-ring canopy.
func _oak_mesh(phase: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	_cylinder(st, Vector3.ZERO, 0.34, 3.9, 5, Color("#4a3a2b"))
	var spokes := 6
	var ring_heights: Array[float] = [3.3, 6.5]
	var ring_radii: Array[float] = [4.3, 3.1]
	var ring_colors: Array[Color] = [Color("#3c5226"), Color("#4d6630")]
	var rings: Array = []
	for ring in range(2):
		var points: Array[Vector3] = []
		for index in range(spokes):
			var angle := TAU * float(index) / float(spokes)
			var radius: float = ring_radii[ring] + sin(angle * 3.0 + phase + float(ring) * 1.3) * 0.55
			points.append(Vector3(cos(angle) * radius, ring_heights[ring], sin(angle) * radius))
		rings.append(points)
	for ring in range(1):
		var lower: Array[Vector3] = rings[ring]
		var upper: Array[Vector3] = rings[ring + 1]
		for index in range(spokes):
			var next := (index + 1) % spokes
			var color: Color = ring_colors[ring].lerp(ring_colors[ring + 1], 0.5)
			for vertex: Vector3 in [lower[index], lower[next], upper[next], lower[index], upper[next], upper[index]]:
				st.set_color((color).srgb_to_linear())
				st.add_vertex(vertex)
	var top: Array[Vector3] = rings[1]
	var apex := Vector3(0.2, 7.9, -0.15)
	for index in range(spokes):
		var next := (index + 1) % spokes
		for vertex: Vector3 in [top[index], top[next], apex]:
			st.set_color((ring_colors[1]).srgb_to_linear())
			st.add_vertex(vertex)
	var bottom: Array[Vector3] = rings[0]
	var heart := Vector3(0.0, 2.6, 0.0)
	for index in range(spokes):
		var next := (index + 1) % spokes
		for vertex: Vector3 in [bottom[next], bottom[index], heart]:
			st.set_color((ring_colors[0].darkened(0.22)).srgb_to_linear())
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
	_add_multimesh(foliage, "DryGrassTufts", mesh, out, 1.1, 0.12)
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
			st.set_color((Color("#a88b46") if vertex.y < 0.2 else Color("#d9bd77")).srgb_to_linear())
			st.add_vertex(vertex)
	st.generate_normals()
	return st.commit()


# --- chaparral scrub -------------------------------------------------------------------

## Dry California chaparral & sagebrush clumps on the sand/rock/grass verges. Three
## stacked cel rings (~36 tris) at 0.8-1.8 m give the golden hills their scrub texture
## without competing with the oak woodland canopy.
func _build_chaparral() -> void:
	var mesh := _shrub_mesh()
	var out: Array[Transform3D] = []
	for band: Dictionary in _segments:
		var zone := String(band.get("zone", ""))
		if zone != "sand" and zone != "rock" and zone != "grass":
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
	_add_multimesh(_foliage_holder(), "ChaparralScrub", mesh, out, 1.25, 0.08)
	stats["shrub_count"] = out.size()
	stats["shrub_triangles"] = out.size() * _surface_triangles(mesh)


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
	var colors: Array[Color] = [Color("#6b6f3d"), Color("#7d8247"), Color("#9a9a58")]
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
	print("[pacific-env] built in %.2fs | terrain tris %d | trees %d | grass %d | shrubs %d | landmarks %d/%d | env tris %d (budget %d)" % [
		float(elapsed) / 1000.0,
		int(stats["terrain_triangles"]),
		int(stats.get("tree_count", 0)),
		int(stats.get("grass_count", 0)),
		int(stats.get("shrub_count", 0)),
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
