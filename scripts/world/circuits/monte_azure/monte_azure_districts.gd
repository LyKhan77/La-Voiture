class_name MonteAzureDistricts
extends Node3D

## The harbour town of Monte Azure (SPEC 4.4 item 5): Riviera apartment and hotel blocks in the strip's urban zones and low
## sheds and workshops in its paddock zones (the marina yards). Each block is a unit box scaled to its size, drawn by
## monte_azure_facade.gdshader (shuttered windows, cornice, roof; the wall colour and the roof style are the instance's
## custom data) with the shared ink hull as next_pass. The blocks are batched per 320 m district, so a MultiMesh's bounds are
## a district's, not the whole lap's, and the frustum culls what is behind.
##
## Placement follows the strip but never its rectangles: a block belongs to the road leg NEAREST to it, must keep
## ROAD_CLEAR_M from every leg, stand on dry ground that is level enough, off the decks and plazas, and clear of the others.

const Zones := preload("res://scripts/world/circuits/monte_azure/monte_azure_zones.gd")
const Terrain := preload("res://scripts/world/circuits/monte_azure/monte_azure_terrain.gd")
const FacadeShader := preload("res://shaders/monte_azure_facade.gdshader")
const OutlineShader := preload("res://shaders/neo_wangan_skyline_outline.gdshader")

const SEED: int = 20260419
const STATION_STEP: int = 2
const DISTRICT_M: float = 320.0
## 5.5 road half width + 1.0 barrier + 4.0 frontage (SPEC 4.4).
const ROAD_CLEAR_M: float = 10.5
## Per built-up zone: where the first row's near wall stands (urban: 26 m, so the TV cameras at 20 m from the road stand clear) and the next rows, the chance of each row, block width and
## depth, the lowest block (m), the roof style (0 tiles, 1 flat) and the wall colours.
const ZONES: Dictionary = {
	"urban": {
		"rows": [26.0, 52.0, 78.0, 104.0, 134.0], "chance": [0.95, 0.85, 0.75, 0.65, 0.5],
		"width": Vector2(14.0, 28.0), "depth": Vector2(14.0, 24.0), "min_height": 11.0, "flat_roof": 0.0,
		"walls": [Color("#e8d6ae"), Color("#dba96d"), Color("#e4b79d"), Color("#d9c8a0"), Color("#efe7d6"), Color("#f0da8f"), Color("#d99a7a")],
	},
	"paddock": {
		"rows": [62.0, 94.0, 128.0, 160.0], "chance": [0.7, 0.6, 0.5, 0.35],
		"width": Vector2(20.0, 38.0), "depth": Vector2(12.0, 20.0), "min_height": 4.5, "flat_roof": 1.0,
		"walls": [Color("#d9d6cc"), Color("#c9ced4"), Color("#e0dccf"), Color("#bfc7c2")],
	},
}
const MAX_SLOPE_M: float = 8.0
const OUTLINE_M: float = 0.5
## The cliff tunnel and the skybridge stand on the road; the town keeps well back from them.
const KEEP_OUT: Array[Vector3] = [Vector3(1215.0, 1445.0, 45.0), Vector3(2150.0, 2210.0, 45.0)] # s0, s1, lateral reach

## Per block: {pose (base centre, yaw), width_m, depth_m, height_m, tint, roof_style, zone, district}.
var buildings: Array[Dictionary] = []
var material: ShaderMaterial
## Why candidate blocks were turned down (reason -> count), for tuning and for the report.
var rejections: Dictionary = {}

var _terrain: Terrain
var _ribbon
var _occupied: Dictionary = {} # 30 m cell -> Array[Vector3] (x, z, radius)


func build(p_ribbon, p_terrain: Terrain) -> void:
	_ribbon = p_ribbon
	_terrain = p_terrain
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED
	for index: int in range(0, _terrain.station_pos.size(), STATION_STEP):
		for side: float in [-1.0, 1.0]:
			var s: float = _terrain.station_s[index]
			var segment: Dictionary = Zones.segment_at(s, side)
			if segment.is_empty() or not ZONES.has(String(segment["zone"])) or _kept_out(s):
				continue
			var zone: Dictionary = ZONES[String(segment["zone"])]
			var rows: Array = zone["rows"]
			for row: int in range(rows.size()):
				var depth_room: float = float(segment["offset_m"]) + float(segment["depth_m"])
				if float(rows[row]) > depth_room or rng.randf() > float((zone["chance"] as Array)[row]) * float(segment["density"]):
					continue
				# A second try with another size when the first block does not fit.
				if not _try_place(index, side, float(rows[row]), segment, zone, rng):
					_try_place(index, side, float(rows[row]), segment, zone, rng)
	_commit()


## Stations whose block would crowd the tunnel or the skybridge.
func _kept_out(s: float) -> bool:
	for zone: Vector3 in KEEP_OUT:
		if s >= zone.x and s <= zone.y:
			return true
	return false


func _try_place(index: int, side: float, near_m: float, segment: Dictionary, zone: Dictionary, rng: RandomNumberGenerator) -> bool:
	var width: float = rng.randf_range((zone["width"] as Vector2).x, (zone["width"] as Vector2).y)
	var depth: float = rng.randf_range((zone["depth"] as Vector2).x, (zone["depth"] as Vector2).y)
	var lateral: float = near_m + rng.randf_range(0.0, 8.0) + depth * 0.5
	var pose: Transform3D = _ribbon.get_point_at_offset(_terrain.station_s[index], side * lateral)
	var forward: Vector3 = -pose.basis.z
	var basis := Basis(Vector3.UP, atan2(-forward.z, forward.x))
	var centre := Vector3(pose.origin.x, 0.0, pose.origin.z)
	var half := Vector2(width, depth) * 0.5
	var low: float = INF
	var high: float = -INF
	for corner: Vector2 in [Vector2.ZERO, Vector2(-half.x, -half.y), Vector2(half.x, -half.y), Vector2(half.x, half.y), Vector2(-half.x, half.y)]:
		var point: Vector3 = centre + basis * Vector3(corner.x, 0.0, corner.y)
		var nearest: int = _terrain.nearest_station(point.x, point.z)
		if nearest < 0 or Vector2(point.x - _terrain.station_pos[nearest].x, point.z - _terrain.station_pos[nearest].z).length() < ROAD_CLEAR_M:
			return _reject("road")
		var ground: float = _terrain.height_at(point.x, point.z)
		if ground < 0.2:
			return _reject("water")
		if _terrain.is_deck_at(point.x, point.z):
			return _reject("deck")
		low = minf(low, ground)
		high = maxf(high, ground)
	if high - low > MAX_SLOPE_M:
		return _reject("slope")
	var zone_name: String = _terrain.zone_at_point(centre.x, centre.z)
	if zone_name != String(segment["zone"]):
		return _reject("zone")
	var radius: float = maxf(width, depth) * 0.5
	if _overlaps(centre, radius):
		return _reject("overlap")
	# The block stands plumb on its lowest corner and sinks into the uphill side; it rises by half that slope as well.
	var height: float = lerpf(float(zone["min_height"]), maxf(float(segment["height_m"]), float(zone["min_height"])), pow(rng.randf(), 1.6)) + (high - low) * 0.5
	var base := Vector3(centre.x, low - 0.3, centre.z)
	var walls: Array = zone["walls"]
	_remember(centre, radius)
	buildings.append({
		"pose": Transform3D(basis, base), "width_m": width, "depth_m": depth, "height_m": height,
		"tint": walls[rng.randi() % walls.size()], "roof_style": float(zone["flat_roof"]), "zone": zone_name,
		"district": Vector2i(floori(centre.x / DISTRICT_M), floori(centre.z / DISTRICT_M)),
	})
	return true


## Counts why a candidate failed; always false, so a placement returns it.
func _reject(reason: String) -> bool:
	rejections[reason] = int(rejections.get(reason, 0)) + 1
	return false


func _overlaps(centre: Vector3, radius: float) -> bool:
	var cell := Vector2i(floori(centre.x / 30.0), floori(centre.z / 30.0))
	for dx: int in range(-2, 3):
		for dz: int in range(-2, 3):
			var key := cell + Vector2i(dx, dz)
			if not _occupied.has(key):
				continue
			for other: Vector3 in _occupied[key]:
				if Vector2(centre.x - other.x, centre.z - other.y).length() < (radius + other.z) * 0.7:
					return true
	return false


func _remember(centre: Vector3, radius: float) -> void:
	var key := Vector2i(floori(centre.x / 30.0), floori(centre.z / 30.0))
	if not _occupied.has(key):
		_occupied[key] = []
	(_occupied[key] as Array).append(Vector3(centre.x, centre.z, radius))


## One MultiMesh per district, all sharing the facade material (so the ink pass and the night factor are shared too).
func _commit() -> void:
	material = ShaderMaterial.new()
	material.shader = FacadeShader
	var ink := ShaderMaterial.new()
	ink.shader = OutlineShader
	ink.render_priority = 1
	ink.set_shader_parameter("outline_width_m", OUTLINE_M)
	material.next_pass = ink
	var by_district: Dictionary = {}
	for building: Dictionary in buildings:
		var key: Vector2i = building["district"]
		if not by_district.has(key):
			by_district[key] = []
		(by_district[key] as Array).append(building)
	var mesh := BoxMesh.new()
	mesh.size = Vector3.ONE
	for key: Vector2i in by_district:
		var members: Array = by_district[key]
		var multimesh := MultiMesh.new()
		multimesh.transform_format = MultiMesh.TRANSFORM_3D
		multimesh.use_custom_data = true
		multimesh.mesh = mesh
		multimesh.instance_count = members.size()
		for member_index: int in range(members.size()):
			var building: Dictionary = members[member_index]
			var pose: Transform3D = building["pose"]
			var size := Vector3(float(building["width_m"]), float(building["height_m"]), float(building["depth_m"]))
			var placed := Transform3D(pose.basis.scaled(size), pose.origin + Vector3.UP * size.y * 0.5)
			multimesh.set_instance_transform(member_index, placed)
			var tint: Color = building["tint"]
			multimesh.set_instance_custom_data(member_index, Color(tint.r, tint.g, tint.b, float(building["roof_style"])))
		var instance := MultiMeshInstance3D.new()
		instance.name = "District_%d_%d" % [key.x, key.y]
		instance.multimesh = multimesh
		instance.material_override = material
		instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(instance)


## 0 by day, 1 at night: the windows light up.
func set_night(night: float) -> void:
	if material != null:
		material.set_shader_parameter("night", night)
