class_name MonteAzureFoliage
extends Node3D

## The vegetation of Monte Azure Marina (SPEC 4.4 item 5): palms along the quay and the town's streets, umbrella pines,
## cypresses and bushes on the hillsides (the strip's forest zones). Four cel-shaded kinds on the shared wind-sway
## material (vertex alpha = sway weight, see wind_foliage.gdshader), one MultiMesh each and none of them casting a shadow
## (circuit-wide MultiMeshes would land in every shadow split, Fase 14.1). Every tree stands on the heightfield, dry,
## off the decks and plazas and CLEAR_M from every road, whichever leg is nearest.

const MeshBatchScript := preload("res://scripts/world/shared/mesh_batch.gd")
const Zones := preload("res://scripts/world/circuits/monte_azure/monte_azure_zones.gd")
const Terrain := preload("res://scripts/world/circuits/monte_azure/monte_azure_terrain.gd")
const WindShader := preload("res://shaders/wind_foliage.gdshader")

const SEED: int = 20260404
const CLEAR_M: float = 10.5
const QUAY_PALM_LATERAL_M: float = 11.0
const QUAY_PALM_STEP_M: float = 22.0
const STREET_PALM_LATERAL_M: float = 12.0
const STREET_PALM_STEP_M: float = 26.0
const MAX_PINES: int = 220
const MAX_CYPRESSES: int = 170
const MAX_BUSHES: int = 220
const MAX_GARDEN_PALMS: int = 40
const HILL_SPACING_M: float = 6.5
const HILL_ATTEMPTS: int = 14000
const MAX_SLOPE_M: float = 3.0
## The cliff tunnel and the skybridge stand on the road: no tree near them.
const KEEP_OUT: Array[Vector3] = [Vector3(1215.0, 1445.0, 45.0), Vector3(2150.0, 2210.0, 45.0)] # s0, s1, lateral reach

const TRUNK_COLOR := Color("#8c6a48")
const PALM_FRONDS: Array[Color] = [Color("#3f9a52"), Color("#58b560")]
const PINE_CANOPY: Array[Color] = [Color("#3f7f4a"), Color("#4f9558")]
const CYPRESS_COLORS: Array[Color] = [Color("#2a6a43"), Color("#347a4d")]
const BUSH_COLORS: Array[Color] = [Color("#4e9a4a"), Color("#66b058")]

## Per tree: {kind ("palms" | "pines" | "cypresses" | "bushes"), pose}.
var poses: Array[Dictionary] = []
var wind_material: ShaderMaterial

var _terrain: Terrain
var _ribbon
var _grid: Dictionary = {} # 8 m cell -> Array[Vector2]
var _counts: Dictionary = {"palms": 0, "pines": 0, "cypresses": 0, "bushes": 0}


func build(p_ribbon, p_terrain: Terrain) -> void:
	_ribbon = p_ribbon
	_terrain = p_terrain
	wind_material = ShaderMaterial.new()
	wind_material.shader = WindShader
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED
	_line_palms(rng)
	_hillsides(rng)
	_gardens(rng)
	var kinds: Dictionary = {"palms": [], "pines": [], "cypresses": [], "bushes": []}
	for entry: Dictionary in poses:
		(kinds[entry["kind"]] as Array).append(entry["pose"])
	_add_kind("Palms", _palm_mesh(), kinds["palms"])
	_add_kind("Pines", _pine_mesh(), kinds["pines"])
	_add_kind("Cypresses", _cypress_mesh(), kinds["cypresses"])
	_add_kind("Bushes", _bush_mesh(), kinds["bushes"])


## Sway for the weather: amplitude (m at the crest), speed (rad/s) and the world direction of the wind.
func set_wind(amplitude: float, speed: float, direction: Vector2) -> void:
	wind_material.set_shader_parameter("wind_amplitude", amplitude)
	wind_material.set_shader_parameter("wind_speed", speed)
	wind_material.set_shader_parameter("wind_direction", direction)


# --- placement ----------------------------------------------------------------------------------

## Palms in a row along the quay (harbour side) and along the town's streets (right side), where the strip allows.
func _line_palms(rng: RandomNumberGenerator) -> void:
	var length: float = _ribbon.length_m
	var s: float = rng.randf_range(0.0, QUAY_PALM_STEP_M)
	while s < length:
		if String(Zones.zone_at(s, -1.0)) == "water" and not _kept_out(s):
			_try(s, -QUAY_PALM_LATERAL_M, "palms", rng, 4.0, "")
		s += QUAY_PALM_STEP_M
	s = rng.randf_range(0.0, STREET_PALM_STEP_M)
	while s < length:
		if String(Zones.zone_at(s, 1.0)) == "urban" and not _kept_out(s):
			_try(s, STREET_PALM_LATERAL_M, "palms", rng, 4.0, "")
		s += STREET_PALM_STEP_M


## Pines, cypresses and bushes on the forest-zone hillsides, spaced like a Poisson disc.
func _hillsides(rng: RandomNumberGenerator) -> void:
	for _attempt: int in range(HILL_ATTEMPTS):
		if _counts["pines"] >= MAX_PINES and _counts["cypresses"] >= MAX_CYPRESSES and _counts["bushes"] >= MAX_BUSHES:
			return
		var index: int = rng.randi() % _terrain.station_pos.size()
		var side: float = -1.0 if rng.randf() < 0.5 else 1.0
		var s: float = _terrain.station_s[index]
		var segment: Dictionary = Zones.segment_at(s, side)
		if segment.is_empty() or String(segment["zone"]) != "forest" or _kept_out(s) or rng.randf() > float(segment["density"]):
			continue
		var roll: float = rng.randf()
		var kind: String = "pines" if roll < 0.45 else ("cypresses" if roll < 0.78 else "bushes")
		var limit: int = MAX_PINES if kind == "pines" else (MAX_CYPRESSES if kind == "cypresses" else MAX_BUSHES)
		if int(_counts[kind]) >= limit:
			continue
		var lateral: float = side * rng.randf_range(CLEAR_M + 2.0, minf(float(segment["depth_m"]), 90.0))
		_try(s, lateral, kind, rng, HILL_SPACING_M, "forest")


## A few palms and cypresses in the gardens behind the town's first row.
func _gardens(rng: RandomNumberGenerator) -> void:
	var placed: int = 0
	for _attempt: int in range(HILL_ATTEMPTS):
		if placed >= MAX_GARDEN_PALMS:
			return
		var index: int = rng.randi() % _terrain.station_pos.size()
		var side: float = -1.0 if rng.randf() < 0.5 else 1.0
		var s: float = _terrain.station_s[index]
		var segment: Dictionary = Zones.segment_at(s, side)
		if segment.is_empty() or String(segment["zone"]) != "urban" or _kept_out(s):
			continue
		var kind: String = "palms" if rng.randf() < 0.6 else "cypresses"
		if _try(s, side * rng.randf_range(CLEAR_M + 4.0, 60.0), kind, rng, 9.0, "urban"):
			placed += 1


func _kept_out(s: float) -> bool:
	for zone: Vector3 in KEEP_OUT:
		if s >= zone.x and s <= zone.y:
			return true
	return false


## Places a tree at arc `s`, signed `lateral`, when the ground allows; true when it stood.
func _try(s: float, lateral: float, kind: String, rng: RandomNumberGenerator, spacing: float, zone: String) -> bool:
	var pose: Transform3D = _ribbon.get_point_at_offset(s, lateral)
	var p := Vector2(pose.origin.x, pose.origin.z)
	var nearest: int = _terrain.nearest_station(p.x, p.y)
	if nearest < 0 or Vector2(p.x - _terrain.station_pos[nearest].x, p.y - _terrain.station_pos[nearest].z).length() < CLEAR_M:
		return false
	var ground: float = _terrain.height_at(p.x, p.y)
	if ground < 0.25 or _terrain.is_deck_at(p.x, p.y):
		return false
	if absf(_terrain.height_at(p.x + 4.0, p.y) - ground) > MAX_SLOPE_M or absf(_terrain.height_at(p.x, p.y + 4.0) - ground) > MAX_SLOPE_M:
		return false
	if zone != "" and _terrain.zone_at_point(p.x, p.y) != zone:
		return false
	if not _spaced(p, spacing):
		return false
	var key := Vector2i(floori(p.x / 8.0), floori(p.y / 8.0))
	if not _grid.has(key):
		_grid[key] = []
	(_grid[key] as Array).append(p)
	var scale: float = rng.randf_range(0.85, 1.35)
	var lean := Basis(Vector3.RIGHT, rng.randf_range(-0.06, 0.06)) if kind == "palms" else Basis.IDENTITY
	var basis: Basis = Basis(Vector3.UP, rng.randf() * TAU) * lean
	poses.append({"kind": kind, "pose": Transform3D(basis.scaled(Vector3.ONE * scale), Vector3(p.x, ground, p.y))})
	_counts[kind] = int(_counts[kind]) + 1
	return true


func _spaced(p: Vector2, spacing: float) -> bool:
	var key := Vector2i(floori(p.x / 8.0), floori(p.y / 8.0))
	var reach: int = ceili(spacing / 8.0)
	for dx: int in range(-reach, reach + 1):
		for dz: int in range(-reach, reach + 1):
			var other_key := key + Vector2i(dx, dz)
			if not _grid.has(other_key):
				continue
			for other: Vector2 in _grid[other_key]:
				if other.distance_to(p) < spacing:
					return false
	return true


# --- meshes -------------------------------------------------------------------------------------

func _add_kind(node_name: String, mesh: ArrayMesh, transforms: Array) -> void:
	mesh.surface_set_material(0, wind_material)
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = mesh
	multimesh.instance_count = transforms.size()
	for index: int in range(transforms.size()):
		multimesh.set_instance_transform(index, transforms[index])
	var instance := MultiMeshInstance3D.new()
	instance.name = node_name
	instance.multimesh = multimesh
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(instance)


## A coconut palm: a curved trunk of three tilted segments and a crown of drooping fronds, ~8 m. Alpha is the sway weight.
func _palm_mesh() -> ArrayMesh:
	var batch := MeshBatchScript.new()
	var key := StandardMaterial3D.new() # key only: the wind material replaces it on the surface
	var top := Vector3.ZERO
	for segment: int in range(3):
		var tilt: float = 0.07 * float(segment)
		var base := Vector3(0.0, 2.4 * float(segment), top.z)
		batch.cylinder(key, Color(TRUNK_COLOR, 0.05 + 0.12 * float(segment)), Transform3D(Basis(Vector3.RIGHT, tilt), base), 0.30 - 0.05 * float(segment), 0.26 - 0.05 * float(segment), 2.5, 6, false, false)
		top = base + Vector3(0.0, 2.4, 0.2 * float(segment + 1))
	for frond: int in range(7):
		var angle: float = TAU * float(frond) / 7.0
		var out := Vector3(cos(angle), 0.0, sin(angle))
		var side := Vector3(-out.z, 0.0, out.x) * 0.42
		var root: Vector3 = top + Vector3.UP * 0.15
		var mid: Vector3 = root + out * 1.5 + Vector3.UP * 0.55
		var tip: Vector3 = root + out * 3.1 + Vector3.DOWN * 0.7
		var color: Color = Color(PALM_FRONDS[frond % PALM_FRONDS.size()], 0.9)
		for facing: float in [1.0, -1.0]:
			batch.triangle(key, color, root - side * 0.25, root + side * 0.25, mid + side, Vector3.UP * facing)
			batch.triangle(key, color, root - side * 0.25, mid + side, mid - side, Vector3.UP * facing)
			batch.triangle(key, color, mid - side, mid + side, tip, Vector3.UP * facing)
	return batch.commit()


## A stone pine: a bare trunk and a flat umbrella canopy of two stacked discs, ~7 m.
func _pine_mesh() -> ArrayMesh:
	var batch := MeshBatchScript.new()
	var key := StandardMaterial3D.new()
	batch.cylinder(key, Color(TRUNK_COLOR, 0.0), Transform3D.IDENTITY, 0.30, 0.20, 4.6, 6, false, false)
	batch.cylinder(key, Color(PINE_CANOPY[0], 0.7), Transform3D(Basis.IDENTITY, Vector3(0.0, 4.4, 0.0)), 1.9, 3.0, 1.0, 8, false, false)
	batch.cylinder(key, Color(PINE_CANOPY[1], 0.9), Transform3D(Basis.IDENTITY, Vector3(0.0, 5.4, 0.0)), 3.0, 1.6, 1.1, 8, true, false)
	return batch.commit()


## A cypress: a tall narrow flame of two stacked cones, ~8 m.
func _cypress_mesh() -> ArrayMesh:
	var batch := MeshBatchScript.new()
	var key := StandardMaterial3D.new()
	batch.cylinder(key, Color(TRUNK_COLOR, 0.0), Transform3D.IDENTITY, 0.18, 0.14, 1.0, 5, false, false)
	batch.cylinder(key, Color(CYPRESS_COLORS[0], 0.4), Transform3D(Basis.IDENTITY, Vector3(0.0, 0.8, 0.0)), 1.15, 0.7, 3.6, 6, false, false)
	batch.cylinder(key, Color(CYPRESS_COLORS[1], 0.8), Transform3D(Basis.IDENTITY, Vector3(0.0, 4.2, 0.0)), 0.8, 0.0, 3.8, 6, false, false)
	return batch.commit()


## A low round bush, ~1.4 m.
func _bush_mesh() -> ArrayMesh:
	var batch := MeshBatchScript.new()
	var key := StandardMaterial3D.new()
	batch.cylinder(key, Color(BUSH_COLORS[0], 0.5), Transform3D.IDENTITY, 1.2, 0.8, 0.9, 7, true, false)
	batch.cylinder(key, Color(BUSH_COLORS[1], 0.8), Transform3D(Basis.IDENTITY, Vector3(0.0, 0.8, 0.0)), 0.8, 0.0, 0.7, 7, false, false)
	return batch.commit()
