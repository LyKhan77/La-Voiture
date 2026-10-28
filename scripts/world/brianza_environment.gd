class_name BrianzaEnvironment
extends Node3D

## Autodromo di Brianza Environment (FASE 13): 2-Tier Architecture combining Tier A Reusable
## Core Kit (Trackside Furniture, Kerbs, Runoff, Gravel, Rubber Groove, Shared Cel Skybox) with
## Tier B Improvised Monza Biome (Parco Reale stone pines & cypresses, the monumental Sopraelevata
## 1950s banked oval overpass viaduct, Villa Reale gate, and Torre Ascari).
##
## All repeating furniture and trees use MultiMeshInstance3D for GPU instancing (< 140 draw calls).

const RibbonScript := preload("res://scripts/car/track_ribbon.gd")
const AdaptiveLineScript := preload("res://scripts/car/adaptive_racing_line.gd")
const CircuitBuilderScript := preload("res://scripts/world/brianza_circuit_builder.gd")
const FurnitureScript := preload("res://scripts/world/trackside_furniture_builder.gd")
const SurfaceGeometry := preload("res://scripts/world/enhanced_track_geometry.gd")
const SharedSkyScript := preload("res://scripts/world/shared_cel_sky_controller.gd")
const ToonMaterials := preload("res://scripts/world/toon_materials.gd")
const MeshBatchScript := preload("res://scripts/world/mesh_batch.gd")
const WeatherScript := preload("res://scripts/gt/gt_weather.gd")

const SERRAGLIO_OVERPASS_S: float = 3450.0
const ASCARI_TOWER_S: float = 4150.0
const VILLA_GATE_S: float = 5600.0

const SOPRA_ARC_M: float = 480.0
const SOPRA_RADIUS_M: float = 320.0
const SOPRA_BANK_DEG: float = 28.0
const SOPRA_YAW_DEG: float = 25.0
const SOPRA_WIDTH_M: float = 14.0
const SOPRA_THICKNESS_M: float = 1.8
const SOPRA_CLEARANCE_M: float = 13.5
## Portal positions as a share of the half arc: two either side of the crossing.
const SOPRA_PORTAL_THETAS: Array[float] = [-0.88, -0.30, 0.30, 0.88]

const KERB_CURVATURE: float = 0.006
const KERB_MIN_LENGTH_M: float = 14.0
const KERB_SCAN_STEP_M: float = 2.0

const RED := Color("#d9232e")
const WHITE := Color("#f0f2f5")

# Layer 1: park ground. Verge strips follow the road down to the field, which sits GROUND_DROP_M
# below the nearest road and fades to the park floor (y = 0) away from the circuit.
const GROUND_SIZE_M := Vector2(4200.0, 3600.0)
const GROUND_CELL_M: float = 48.0
const GROUND_DROP_M: float = 2.4
const GROUND_FADE_NEAR_M: float = 80.0
const GROUND_FADE_FAR_M: float = 500.0
const GROUND_SAMPLE_STEP_M: float = 20.0
const VERGE_STEP_M: float = 6.0
const VERGE_LATERAL_M: Array[float] = [7.3, 12.0, 40.0, 80.0]
const VERGE_DROP_M: Array[float] = [-0.10, -0.30, -1.20, -2.40]
const GRASS_TONES: Array[Color] = [Color("#3c7a38"), Color("#33692f"), Color("#478743")]
const GRAVEL_PATH := Color("#8c7e63")
const PARK_WALL_BRICK := Color("#a3483b")
const PARK_WALL_CAP := Color("#d4d0c7")
const PARK_WALL_HEIGHT_M: float = 3.2
const PARK_WALL_MARGIN_M: float = 380.0

var ribbon: RibbonScript
var builder: CircuitBuilderScript
var line: AdaptiveLineScript
var furniture: FurnitureScript
var shared_sky: SharedSkyScript
var sopraelevata: Node3D
var tree_multimeshes: Array[MultiMeshInstance3D] = []
var built: bool = false
var kerbs: Array[Dictionary] = []
var runoff_plans: Array[Dictionary] = []
var ground_root: Node3D

var _track_pos: PackedVector3Array = PackedVector3Array()
var _track_centre: Vector2 = Vector2.ZERO
var _track_half: Vector2 = Vector2.ZERO
var _field_origin: Vector2 = Vector2.ZERO
var _field_cols: int = 0
var _field_rows: int = 0
var _field_y: PackedFloat32Array = PackedFloat32Array()


func build(p_ribbon: RibbonScript, p_builder: CircuitBuilderScript) -> void:
	if built:
		return
	built = true
	ribbon = p_ribbon
	builder = p_builder
	line = AdaptiveLineScript.new(ribbon)
	
	_build_layer1_ground_massing()
	_build_tier_a_surface()
	_build_tier_a_furniture()
	_build_tier_a_sky()
	_build_layer2_sopraelevata_monumental()
	_build_tier_b_landmarks()
	_build_tier_b_royal_park_foliage()


func bind_world(_world_env: WorldEnvironment, _sun: DirectionalLight3D, _camera: Camera3D) -> void:
	pass


func update(delta: float, race) -> void:
	if shared_sky != null and race != null and race.get("weather") != null:
		var weather = race.weather
		var wind_kph: float = float(weather.wind_speed) if "wind_speed" in weather else 14.0
		shared_sky.apply_wind(delta, wind_kph)
		var gloom: float = 0.0
		if "rain_intensity" in weather and "track_water_pct" in weather:
			gloom = maxf(clampf(sqrt(weather.rain_intensity), 0.0, 1.0), weather.track_water_pct / 100.0)
		elif "gloom" in weather:
			gloom = float(weather.gloom)
		var tod = weather.time_of_day if "time_of_day" in weather else {}
		if tod is Dictionary and not tod.is_empty():
			shared_sky.apply_time_of_day(tod, gloom)


func apply_time_of_day(tod, gloom: float = 0.0) -> void:
	if shared_sky != null and shared_sky.has_method("apply_time_of_day"):
		shared_sky.apply_time_of_day(tod, gloom)
	if furniture != null and furniture.has_method("apply_time_of_day"):
		furniture.call("apply_time_of_day", tod)


func stats() -> Dictionary:
	return {
		"circuit_id": "brianza",
		"length_m": ribbon.curve.get_baked_length() if ribbon != null and ribbon.curve != null else 0.0,
		"built": built,
		"sopraelevata_active": sopraelevata != null,
		"tree_batches": tree_multimeshes.size(),
	}


## Top of the solid ground under a world point: the verge profile next to the road, the park field
## further out. Trees, piers and fences stand on this, so nothing floats.
func ground_y_at(pos: Vector3) -> float:
	var best: int = -1
	var best_d: float = INF
	for i: int in range(_track_pos.size()):
		var d: float = Vector2(_track_pos[i].x - pos.x, _track_pos[i].z - pos.z).length_squared()
		if d < best_d:
			best_d = d
			best = i
	if best < 0:
		return 0.0
	var lateral: float = sqrt(best_d)
	if lateral > VERGE_LATERAL_M[VERGE_LATERAL_M.size() - 1]:
		return _field_height(pos.x, pos.z)
	# Interpolate road height along the closer of the two segments touching the nearest sample.
	var road_y: float = _track_pos[best].y
	var p := Vector2(pos.x, pos.z)
	var here := Vector2(_track_pos[best].x, _track_pos[best].z)
	var count: int = _track_pos.size()
	for other: int in [posmod(best - 1, count), posmod(best + 1, count)]:
		var q := Vector2(_track_pos[other].x, _track_pos[other].z)
		var seg: Vector2 = q - here
		var t: float = clampf((p - here).dot(seg) / maxf(seg.length_squared(), 0.0001), 0.0, 1.0)
		if (p - here).dot(seg) > 0.0:
			road_y = lerpf(_track_pos[best].y, _track_pos[other].y, t)
			lateral = (p - (here + seg * t)).length()
			break
	return road_y + _verge_drop(lateral)


func _verge_drop(lateral: float) -> float:
	var last: int = VERGE_LATERAL_M.size() - 1
	if lateral <= VERGE_LATERAL_M[0]:
		return VERGE_DROP_M[0]
	for i: int in range(last):
		if lateral <= VERGE_LATERAL_M[i + 1]:
			var t: float = (lateral - VERGE_LATERAL_M[i]) / (VERGE_LATERAL_M[i + 1] - VERGE_LATERAL_M[i])
			return lerpf(VERGE_DROP_M[i], VERGE_DROP_M[i + 1], t)
	return VERGE_DROP_M[last]


func _field_height(x: float, z: float) -> float:
	var fx: float = clampf((x - _field_origin.x) / GROUND_CELL_M, 0.0, float(_field_cols - 1) - 0.001)
	var fz: float = clampf((_field_origin.y - z) / GROUND_CELL_M, 0.0, float(_field_rows - 1) - 0.001)
	var c: int = int(fx)
	var r: int = int(fz)
	var tx: float = fx - float(c)
	var tz: float = fz - float(r)
	var a: float = lerpf(_field_y[r * _field_cols + c], _field_y[r * _field_cols + c + 1], tx)
	var b: float = lerpf(_field_y[(r + 1) * _field_cols + c], _field_y[(r + 1) * _field_cols + c + 1], tx)
	return lerpf(a, b, tz)


## Layer 1: field + verge strips + gravel apron + historic park wall (0 floating roads).
func _build_layer1_ground_massing() -> void:
	ground_root = Node3D.new()
	ground_root.name = "ParcoRealeGroundRoot"
	add_child(ground_root)
	_sample_track()
	_build_field()
	_build_verge()
	_build_park_wall()


func _sample_track() -> void:
	_track_pos.clear()
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	var s: float = 0.0
	while s < ribbon.length_m:
		var p: Vector3 = ribbon.get_point_at_offset(s, 0.0).origin
		_track_pos.append(p)
		lo = Vector2(minf(lo.x, p.x), minf(lo.y, p.z))
		hi = Vector2(maxf(hi.x, p.x), maxf(hi.y, p.z))
		s += GROUND_SAMPLE_STEP_M
	_track_centre = (lo + hi) * 0.5
	_track_half = (hi - lo) * 0.5


func _build_field() -> void:
	_field_cols = int(GROUND_SIZE_M.x / GROUND_CELL_M) + 1
	_field_rows = int(GROUND_SIZE_M.y / GROUND_CELL_M) + 1
	_field_origin = Vector2(_track_centre.x - GROUND_SIZE_M.x * 0.5, _track_centre.y + GROUND_SIZE_M.y * 0.5)
	var nearest_d := PackedFloat32Array()
	var nearest_y := PackedFloat32Array()
	nearest_d.resize(_field_cols * _field_rows)
	nearest_d.fill(INF)
	nearest_y.resize(_field_cols * _field_rows)
	var reach: int = ceili(GROUND_FADE_FAR_M / GROUND_CELL_M)
	for p: Vector3 in _track_pos:
		var c0: int = roundi((p.x - _field_origin.x) / GROUND_CELL_M)
		var r0: int = roundi((_field_origin.y - p.z) / GROUND_CELL_M)
		for r: int in range(maxi(r0 - reach, 0), mini(r0 + reach + 1, _field_rows)):
			for c: int in range(maxi(c0 - reach, 0), mini(c0 + reach + 1, _field_cols)):
				var vx: float = _field_origin.x + float(c) * GROUND_CELL_M
				var vz: float = _field_origin.y - float(r) * GROUND_CELL_M
				var d: float = Vector2(vx - p.x, vz - p.z).length()
				var i: int = r * _field_cols + c
				if d < nearest_d[i]:
					nearest_d[i] = d
					nearest_y[i] = p.y
	_field_y.resize(_field_cols * _field_rows)
	for i: int in range(_field_y.size()):
		var near_y: float = nearest_y[i] if nearest_d[i] < INF else 0.0
		var fade: float = smoothstep(GROUND_FADE_NEAR_M, GROUND_FADE_FAR_M, nearest_d[i])
		_field_y[i] = lerpf(near_y, 0.0, fade) - GROUND_DROP_M
	var tools: Array[SurfaceTool] = []
	for tone: int in range(GRASS_TONES.size()):
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		st.set_normal(Vector3.UP)
		tools.append(st)
	for r: int in range(_field_rows - 1):
		for c: int in range(_field_cols - 1):
			var st: SurfaceTool = tools[posmod(c * 7 + r * 13 + (c * r) % 5, GRASS_TONES.size())]
			var v00 := _field_vertex(c, r)
			var v01 := _field_vertex(c + 1, r)
			var v10 := _field_vertex(c, r + 1)
			var v11 := _field_vertex(c + 1, r + 1)
			for v: Vector3 in [v00, v10, v11, v00, v11, v01]:
				st.set_normal(Vector3.UP)
				st.add_vertex(v)
	var mesh := ArrayMesh.new()
	for tone: int in range(GRASS_TONES.size()):
		tools[tone].commit(mesh)
		mesh.surface_set_material(tone, ToonMaterials.make(GRASS_TONES[tone]))
	var inst := MeshInstance3D.new()
	inst.name = "ParcoRealeGroundMesh"
	inst.mesh = mesh
	inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ground_root.add_child(inst)


func _field_vertex(c: int, r: int) -> Vector3:
	return Vector3(_field_origin.x + float(c) * GROUND_CELL_M, _field_y[r * _field_cols + c], _field_origin.y - float(r) * GROUND_CELL_M)


## Grass verge to 80 m either side plus a gravel apron right behind the kerbs.
func _build_verge() -> void:
	var gravel := SurfaceTool.new()
	var grass := SurfaceTool.new()
	for st: SurfaceTool in [gravel, grass]:
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rows: int = ceili(ribbon.length_m / VERGE_STEP_M)
	for side: float in [-1.0, 1.0]:
		for i: int in range(rows):
			var s0: float = float(i) * VERGE_STEP_M
			var s1: float = minf(float(i + 1) * VERGE_STEP_M, ribbon.length_m)
			for band: int in range(VERGE_LATERAL_M.size() - 1):
				var st: SurfaceTool = gravel if band == 0 else grass
				var l0: float = side * VERGE_LATERAL_M[band]
				var l1: float = side * VERGE_LATERAL_M[band + 1]
				var a: Vector3 = _verge_point(s0, l0, band)
				var b: Vector3 = _verge_point(s1, l0, band)
				var c: Vector3 = _verge_point(s1, l1, band + 1)
				var d: Vector3 = _verge_point(s0, l1, band + 1)
				# Left (-1) side is wound the other way round so both face up.
				var quad: Array = [a, b, c, a, c, d] if side > 0.0 else [a, c, b, a, d, c]
				for v: Vector3 in quad:
					st.set_normal(Vector3.UP)
					st.add_vertex(v)
	var apron_inst := MeshInstance3D.new()
	apron_inst.name = "ParkPathways"
	apron_inst.mesh = _commit_surface(gravel, GRAVEL_PATH)
	apron_inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ground_root.add_child(apron_inst)
	var verge_inst := MeshInstance3D.new()
	verge_inst.name = "ParcoRealeVerge"
	verge_inst.mesh = _commit_surface(grass, GRASS_TONES[0])
	verge_inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ground_root.add_child(verge_inst)


func _verge_point(s: float, lateral: float, band_edge: int) -> Vector3:
	var p: Vector3 = ribbon.get_point_at_offset(s, lateral).origin
	var road_y: float = ribbon.get_point_at_offset(s, 0.0).origin.y
	p.y = road_y + VERGE_DROP_M[band_edge]
	return p


func _commit_surface(st: SurfaceTool, color: Color) -> ArrayMesh:
	var mesh := ArrayMesh.new()
	st.commit(mesh)
	mesh.surface_set_material(0, ToonMaterials.make(color))
	return mesh


## Mura del Parco di Monza: terracotta brick with a limestone cap, a rectangle around the circuit.
func _build_park_wall() -> void:
	var half := Vector2(
		minf(_track_half.x + PARK_WALL_MARGIN_M, GROUND_SIZE_M.x * 0.5 - 60.0),
		minf(_track_half.y + PARK_WALL_MARGIN_M, GROUND_SIZE_M.y * 0.5 - 60.0))
	var batch := MeshBatchScript.new()
	var mat: Material = ToonMaterials.vertex_colored(false)
	var step: float = 60.0
	for side: float in [-1.0, 1.0]:
		var x: float = _track_centre.x - half.x
		while x < _track_centre.x + half.x:
			var z: float = _track_centre.y + side * half.y
			_wall_segment(batch, mat, Vector3(x + step * 0.5, 0.0, z), step, 0.0)
			x += step
		var z2: float = _track_centre.y - half.y
		while z2 < _track_centre.y + half.y:
			var xx: float = _track_centre.x + side * half.x
			_wall_segment(batch, mat, Vector3(xx, 0.0, z2 + step * 0.5), step, PI * 0.5)
			z2 += step
	var inst := MeshInstance3D.new()
	inst.name = "MuraDelParco"
	inst.mesh = batch.commit()
	add_child(inst)


func _wall_segment(batch: MeshBatchScript, mat: Material, centre: Vector3, length: float, yaw: float) -> void:
	var base_y: float = _field_height(centre.x, centre.z)
	var basis := Basis(Vector3.UP, yaw)
	batch.box(mat, PARK_WALL_BRICK, Transform3D(basis, Vector3(centre.x, base_y + PARK_WALL_HEIGHT_M * 0.5, centre.z)), Vector3(length, PARK_WALL_HEIGHT_M, 1.0))
	batch.box(mat, PARK_WALL_CAP, Transform3D(basis, Vector3(centre.x, base_y + PARK_WALL_HEIGHT_M + 0.15, centre.z)), Vector3(length, 0.3, 1.5))


func _find_sharp_corners() -> Array[Dictionary]:
	var runs: Array[Dictionary] = []
	var s: float = 0.0
	var current: Dictionary = {}
	var length_m: float = ribbon.length_m
	while s < length_m:
		var k: float = ribbon.get_curvature_at(s)
		if absf(k) >= KERB_CURVATURE:
			var side: float = signf(k)
			if not current.is_empty() and is_equal_approx(float(current["side"]), side):
				current["s1"] = s + KERB_SCAN_STEP_M
			else:
				if not current.is_empty():
					runs.append(current)
				current = {"s0": s, "s1": s + KERB_SCAN_STEP_M, "side": side}
		s += KERB_SCAN_STEP_M
	if not current.is_empty():
		runs.append(current)
	var kept: Array[Dictionary] = []
	for run: Dictionary in runs:
		if float(run["s1"]) - float(run["s0"]) >= KERB_MIN_LENGTH_M:
			kept.append(run)
	return kept


func _build_tier_a_surface() -> void:
	var surface_root := Node3D.new()
	surface_root.name = "SurfaceDetailRoot"
	add_child(surface_root)
	
	kerbs = _find_sharp_corners()
	var kerb_m: ArrayMesh = SurfaceGeometry.kerb_mesh(ribbon, kerbs, ribbon.road_half_width_m - SurfaceGeometry.KERB_INSET_M)
	if kerb_m != null:
		kerb_m.surface_set_material(0, ToonMaterials.make(RED))
		kerb_m.surface_set_material(1, ToonMaterials.make(WHITE))
		var kerb_inst := MeshInstance3D.new()
		kerb_inst.name = "SawtoothKerbs"
		kerb_inst.mesh = kerb_m
		surface_root.add_child(kerb_inst)
		
	var pit_lead: float = 20.0
	var pit_trail: float = 40.0
	var pit_start: float = fposmod(5530.0 - pit_lead, ribbon.length_m)
	var pit_len: float = 410.0 + pit_lead + pit_trail
	runoff_plans = SurfaceGeometry.plan_runoffs(ribbon, kerbs, pit_start, pit_len)
	
	var runoff_m: ArrayMesh = SurfaceGeometry.runoff_mesh(ribbon, runoff_plans)
	if runoff_m != null and runoff_m.get_surface_count() >= 3:
		runoff_m.surface_set_material(0, ToonMaterials.make(SurfaceGeometry.RUNOFF_COLOR))
		runoff_m.surface_set_material(1, ToonMaterials.make(SurfaceGeometry.WARNING_BLUE))
		runoff_m.surface_set_material(2, ToonMaterials.make(WHITE))
		var runoff_inst := MeshInstance3D.new()
		runoff_inst.name = "TarmacRunoff"
		runoff_inst.mesh = runoff_m
		surface_root.add_child(runoff_inst)
		
	var gravel_m: ArrayMesh = SurfaceGeometry.gravel_mesh(ribbon, runoff_plans)
	if gravel_m != null and gravel_m.get_surface_count() >= 1:
		gravel_m.surface_set_material(0, ToonMaterials.make(SurfaceGeometry.GRAVEL_COLOR))
		var gravel_inst := MeshInstance3D.new()
		gravel_inst.name = "GravelTraps"
		gravel_inst.mesh = gravel_m
		surface_root.add_child(gravel_inst)
		
	var groove_mat := StandardMaterial3D.new()
	groove_mat.vertex_color_use_as_albedo = true
	groove_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	groove_mat.roughness = 0.7
	groove_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	var groove_m: ArrayMesh = SurfaceGeometry.groove_mesh(ribbon, line)
	if groove_m != null:
		groove_m.surface_set_material(0, groove_mat)
		var groove_inst := MeshInstance3D.new()
		groove_inst.name = "RubberGroove"
		groove_inst.mesh = groove_m
		groove_inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		surface_root.add_child(groove_inst)


func _build_tier_a_furniture() -> void:
	var hero_zones: Array[Dictionary] = [
		{"side": 1.0, "s0": 5510.0, "s1": 5790.0, "lateral": 36.0},
		{"side": 1.0, "s0": 0.0, "s1": 190.0, "lateral": 36.0},
	]
	furniture = FurnitureScript.new()
	furniture.name = "TracksideFurniture"
	add_child(furniture)
	furniture.build(ribbon, line, kerbs, runoff_plans, hero_zones)


func _build_tier_a_sky() -> void:
	shared_sky = SharedSkyScript.new()
	shared_sky.build(self, ribbon)


## Layer 2, Hero Landmark 1: La Sopraelevata di Monza. A 480 m arc of banked concrete deck (R 320 m)
## swung diagonally over the Serraglio straight on four dual-pier portals. Station frame: T along the
## deck, N horizontal toward the arc centre, deck plane tilted BANK_DEG with the inner edge low.
func _build_layer2_sopraelevata_monumental() -> void:
	sopraelevata = Node3D.new()
	sopraelevata.name = "HeroLandmark_Sopraelevata"
	add_child(sopraelevata)

	if ribbon == null:
		return

	var xform: Transform3D = ribbon.get_point_at_offset(SERRAGLIO_OVERPASS_S, 0.0)
	sopraelevata.transform = xform
	sopraelevata.set_meta("arc_length_m", SOPRA_ARC_M)
	sopraelevata.set_meta("bank_deg", SOPRA_BANK_DEG)
	sopraelevata.set_meta("clearance_m", SOPRA_CLEARANCE_M)

	var mat: Material = ToonMaterials.vertex_colored(false)
	var conc_col := Color("#8a8f9c")
	var dark_conc := Color("#555966")
	var rust_col := Color("#733d26")
	var half_arc: float = SOPRA_ARC_M * 0.5 / SOPRA_RADIUS_M
	var segments: int = int(SOPRA_ARC_M / 12.0)
	var bank: float = deg_to_rad(SOPRA_BANK_DEG)
	var half_w: float = SOPRA_WIDTH_M * 0.5
	# Underside of the inner (low) edge is the clearance line over the track.
	var y0: float = SOPRA_CLEARANCE_M + half_w * sin(bank) + SOPRA_THICKNESS_M * cos(bank)

	var deck := MeshBatchScript.new()
	var rail := MeshBatchScript.new()
	for i: int in range(segments + 1):
		var st_a: Dictionary = _sopra_station(-half_arc + 2.0 * half_arc * float(i) / float(segments), y0, bank)
		if i == 0 or i == segments:
			var end_sign: float = -1.0 if i == 0 else 1.0
			_sopra_cap(deck, mat, conc_col, st_a, half_w, end_sign)
		if i == segments:
			break
		var st_b: Dictionary = _sopra_station(-half_arc + 2.0 * half_arc * float(i + 1) / float(segments), y0, bank)
		var tone: Color = conc_col.lerp(dark_conc, 0.28 * fmod(float(i) * 0.618, 1.0))
		var tl_a: Vector3 = _sopra_edge(st_a, -half_w, 0.0)
		var tr_a: Vector3 = _sopra_edge(st_a, half_w, 0.0)
		var tl_b: Vector3 = _sopra_edge(st_b, -half_w, 0.0)
		var tr_b: Vector3 = _sopra_edge(st_b, half_w, 0.0)
		var bl_a: Vector3 = _sopra_edge(st_a, -half_w, -SOPRA_THICKNESS_M)
		var br_a: Vector3 = _sopra_edge(st_a, half_w, -SOPRA_THICKNESS_M)
		var bl_b: Vector3 = _sopra_edge(st_b, -half_w, -SOPRA_THICKNESS_M)
		var br_b: Vector3 = _sopra_edge(st_b, half_w, -SOPRA_THICKNESS_M)
		var nrm: Vector3 = st_a["nrm"]
		var dir_u: Vector3 = st_a["dir_u"]
		deck.quad(mat, tone, tl_a, tr_a, tr_b, tl_b, nrm)
		deck.quad(mat, dark_conc, bl_a, br_a, br_b, bl_b, -nrm)
		deck.quad(mat, tone * 0.85, tl_a, bl_a, bl_b, tl_b, -dir_u)
		deck.quad(mat, tone * 0.85, tr_a, br_a, br_b, tr_b, dir_u)
		# Rusty crash rail on the outer upper lip, a low concrete lip on the inner edge.
		var pose_basis := Basis(dir_u, nrm, st_a["tan"])
		var mid: Vector3 = (st_a["pos"] as Vector3).lerp(st_b["pos"], 0.5)
		rail.box(mat, rust_col, Transform3D(pose_basis, mid + dir_u * (-half_w - 0.1) + nrm * 1.1), Vector3(0.5, 2.2, 12.4))
		deck.box(mat, dark_conc, Transform3D(pose_basis, mid + dir_u * (half_w + 0.3) + nrm * 0.4), Vector3(0.6, 1.0, 12.4))

	var inst := MeshInstance3D.new()
	inst.name = "SopraelevataViaductMesh"
	inst.mesh = deck.commit()
	sopraelevata.add_child(inst)
	var rail_inst := MeshInstance3D.new()
	rail_inst.name = "SopraelevataGuardrail"
	rail_inst.mesh = rail.commit()
	sopraelevata.add_child(rail_inst)

	var portal_root := Node3D.new()
	portal_root.name = "SopraelevataPortals"
	sopraelevata.add_child(portal_root)
	for k: int in range(SOPRA_PORTAL_THETAS.size()):
		var station: Dictionary = _sopra_station(SOPRA_PORTAL_THETAS[k] * half_arc, y0, bank)
		var portal := MeshBatchScript.new()
		_sopra_portal(portal, mat, station, xform, half_w, dark_conc, conc_col)
		var portal_inst := MeshInstance3D.new()
		portal_inst.name = "SopraPortal_%d" % k
		portal_inst.mesh = portal.commit()
		portal_root.add_child(portal_inst)


## Frame of the deck centre line at arc angle `theta`, in the landmark's local space.
func _sopra_station(theta: float, y0: float, bank: float) -> Dictionary:
	var yaw := Basis(Vector3.UP, deg_to_rad(SOPRA_YAW_DEG))
	var tangent: Vector3 = yaw * Vector3(cos(theta), 0.0, -sin(theta))
	var inward: Vector3 = yaw * Vector3(-sin(theta), 0.0, -cos(theta))
	var pos: Vector3 = yaw * Vector3(SOPRA_RADIUS_M * sin(theta), 0.0, -SOPRA_RADIUS_M * (1.0 - cos(theta))) + Vector3(0.0, y0, 0.0)
	return {
		"pos": pos, "tan": tangent, "inward": inward,
		"dir_u": inward * cos(bank) - Vector3.UP * sin(bank),
		"nrm": Vector3.UP * cos(bank) + inward * sin(bank),
	}


## Point `u` across the deck (+ = inner, low edge) and `v` along the deck normal.
func _sopra_edge(station: Dictionary, u: float, v: float) -> Vector3:
	return (station["pos"] as Vector3) + (station["dir_u"] as Vector3) * u + (station["nrm"] as Vector3) * v


func _sopra_cap(batch: MeshBatchScript, mat: Material, color: Color, station: Dictionary, half_w: float, end_sign: float) -> void:
	batch.quad(mat, color * 0.8, _sopra_edge(station, -half_w, 0.0), _sopra_edge(station, half_w, 0.0),
		_sopra_edge(station, half_w, -SOPRA_THICKNESS_M), _sopra_edge(station, -half_w, -SOPRA_THICKNESS_M), (station["tan"] as Vector3) * end_sign)


## Two concrete piers down to the ground, a cap beam under the deck and two arch braces between them.
func _sopra_portal(batch: MeshBatchScript, mat: Material, station: Dictionary, xform: Transform3D, half_w: float, pier_col: Color, beam_col: Color) -> void:
	var basis := Basis(station["dir_u"], station["nrm"], station["tan"])
	var tops: Array[Vector3] = []
	for u: float in [-half_w * 0.65, half_w * 0.65]:
		var top: Vector3 = _sopra_edge(station, u, -SOPRA_THICKNESS_M - 0.3)
		var base_world: float = ground_y_at(xform * Vector3(top.x, 0.0, top.z))
		var base_y: float = base_world - xform.origin.y - 1.0
		var height: float = top.y - base_y
		batch.box(mat, pier_col, Transform3D(basis.orthonormalized(), Vector3(top.x, base_y + height * 0.5, top.z)), Vector3(3.2, height, 4.4))
		tops.append(top)
	var beam_mid: Vector3 = (tops[0] + tops[1]) * 0.5
	batch.box(mat, beam_col, Transform3D(basis, beam_mid + (station["nrm"] as Vector3) * 0.4), Vector3(SOPRA_WIDTH_M, 1.2, 4.8))
	for top: Vector3 in tops:
		var brace_foot: Vector3 = top - Vector3.UP * 5.5
		batch.strut(mat, beam_col, brace_foot, beam_mid - (station["nrm"] as Vector3) * 0.2, 1.1)


## Hero Landmark 2 & 3: Villa Reale Gateway Arch and Torre Ascari
func _build_tier_b_landmarks() -> void:
	if ribbon == null:
		return
		
	var landmarks := Node3D.new()
	landmarks.name = "HeroLandmarks_MonzaHeritage"
	add_child(landmarks)
	
	var batch := MeshBatchScript.new()
	var mat: Material = ToonMaterials.vertex_colored(false)
	
	# Villa Reale Brick Gateway Arch (s = 5600 m, behind the main grandstand at lateral -36 m)
	var gate_pose: Transform3D = ribbon.get_point_at_offset(VILLA_GATE_S, -36.0)
	
	var brick_col := Color("#a3483b")
	var stone_col := Color("#d4d0c7")
	batch.box(mat, brick_col, gate_pose * Transform3D(Basis.IDENTITY, Vector3(-6.0, 5.0, 0.0)), Vector3(3.2, 10.0, 3.2))
	batch.box(mat, brick_col, gate_pose * Transform3D(Basis.IDENTITY, Vector3(6.0, 5.0, 0.0)), Vector3(3.2, 10.0, 3.2))
	batch.box(mat, stone_col, gate_pose * Transform3D(Basis.IDENTITY, Vector3(0.0, 9.8, 0.0)), Vector3(16.0, 2.2, 4.0))
	batch.box(mat, stone_col, gate_pose * Transform3D(Basis.IDENTITY, Vector3(0.0, 11.8, 0.0)), Vector3(10.0, 1.8, 2.5))
	
	# Torre Ascari (Vintage timing & signal tower at s = 4150 m, entry to Ascari chicane)
	var tower_pose: Transform3D = ribbon.get_point_at_offset(ASCARI_TOWER_S, 16.5)
	
	var tower_col := Color("#4d5361")
	var banner_col := Color("#ffd400") # Retro Agip yellow
	batch.box(mat, tower_col, tower_pose * Transform3D(Basis.IDENTITY, Vector3(0.0, 8.0, 0.0)), Vector3(3.8, 16.0, 3.8))
	batch.box(mat, Color(0.2, 0.8, 1.0, 0.4), tower_pose * Transform3D(Basis.IDENTITY, Vector3(0.0, 14.5, 0.0)), Vector3(4.8, 3.2, 4.8))
	batch.box(mat, banner_col, tower_pose * Transform3D(Basis.IDENTITY, Vector3(0.0, 8.5, -2.1)), Vector3(3.6, 6.0, 0.3))
	
	var mi := MeshInstance3D.new()
	mi.name = "MonzaHeritageMeshes"
	mi.mesh = batch.commit()
	landmarks.add_child(mi)


## Tier B Biome: Parco Reale di Monza (Stone Pines with broad umbrella canopies & Italian Cypresses)
func _build_tier_b_royal_park_foliage() -> void:
	if ribbon == null or ribbon.curve == null:
		return
		
	tree_multimeshes.clear()
	var foliage_root := Node3D.new()
	foliage_root.name = "ParcoRealeFoliage"
	add_child(foliage_root)
	
	var length_m: float = ribbon.curve.get_baked_length()
	var pine_poses: Array[Transform3D] = []
	var cypress_poses: Array[Transform3D] = []
	
	var rng := RandomNumberGenerator.new()
	rng.seed = 19220903 # Monza opening date: September 3, 1922
	
	var step_m: float = 14.0
	var count: int = ceili(length_m / step_m)
	
	for i: int in range(count):
		var s: float = float(i) * step_m
		
		# Skip pit building frontage zone
		if s > 5450.0 or s < 250.0:
			continue
			
		for side: float in [-1.0, 1.0]:
			var num_layers: int = rng.randi_range(1, 3)
			for layer: int in range(num_layers):
				var depth: float = 16.0 + float(layer) * 14.0 + rng.randf_range(-3.0, 5.0)
				var pose: Transform3D = ribbon.get_point_at_offset(s, side * depth)
				pose.origin.y = maxf(pose.origin.y, -7.0)
				
				var yaw: float = rng.randf_range(0.0, TAU)
				var scale_f: float = rng.randf_range(0.85, 1.25)
				pose.basis = Basis(Vector3.UP, yaw).scaled(Vector3.ONE * scale_f)
				
				if rng.randf() < 0.65:
					pine_poses.append(pose)
				else:
					cypress_poses.append(pose)
					
	# Create Pine Tree Mesh (Trunk + Umbrella Canopy)
	var pine_batch := MeshBatchScript.new()
	var mat_trunk: Material = ToonMaterials.vertex_colored(false)
	var trunk_col := Color("#4a3728")
	var pine_leaf_col := Color("#355e3b")
	pine_batch.cylinder(mat_trunk, trunk_col, Transform3D(Basis.IDENTITY, Vector3(0.0, 4.0, 0.0)), 0.35, 0.30, 8.0, 8)
	pine_batch.cylinder(mat_trunk, pine_leaf_col, Transform3D(Basis.IDENTITY, Vector3(0.0, 8.5, 0.0)), 5.2, 4.2, 2.5, 10)
	pine_batch.cylinder(mat_trunk, pine_leaf_col * 0.9, Transform3D(Basis.IDENTITY, Vector3(0.0, 10.5, 0.0)), 4.0, 0.0, 2.0, 10)
	var pine_mesh: ArrayMesh = pine_batch.commit()
	
	var pine_inst := _create_multimesh_instance("StonePines", pine_mesh, pine_poses)
	foliage_root.add_child(pine_inst)
	tree_multimeshes.append(pine_inst)
	
	# Create Cypress Tree Mesh (Slender tall green column)
	var cyp_batch := MeshBatchScript.new()
	var cyp_leaf_col := Color("#1e3f20")
	cyp_batch.cylinder(mat_trunk, trunk_col, Transform3D(Basis.IDENTITY, Vector3(0.0, 1.5, 0.0)), 0.2, 0.2, 3.0, 6)
	cyp_batch.cylinder(mat_trunk, cyp_leaf_col, Transform3D(Basis.IDENTITY, Vector3(0.0, 7.0, 0.0)), 1.4, 0.0, 9.0, 8)
	var cyp_mesh: ArrayMesh = cyp_batch.commit()
	
	var cyp_inst := _create_multimesh_instance("ItalianCypresses", cyp_mesh, cypress_poses)
	foliage_root.add_child(cyp_inst)
	tree_multimeshes.append(cyp_inst)


func _create_multimesh_instance(node_name: String, mesh: Mesh, poses: Array[Transform3D]) -> MultiMeshInstance3D:
	var batch := MultiMesh.new()
	batch.transform_format = MultiMesh.TRANSFORM_3D
	batch.mesh = mesh
	batch.instance_count = poses.size()
	for i: int in range(poses.size()):
		batch.set_instance_transform(i, poses[i])
	var inst := MultiMeshInstance3D.new()
	inst.name = node_name
	inst.multimesh = batch
	inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return inst
