class_name FoliageScatter
extends Node3D

## Anime trees around the Apex Ring (FASE 10): three cel-shaded kinds (pointed Japanese cedar,
## layered round broadleaf oak, leaning slope pine), each one MultiMesh, scattered with
## Poisson-disc spacing outside the safety fence and away from the landmark buildings. All
## kinds share one wind-sway material (vertex alpha = sway weight), driven by the weather.

const TrackRibbonScript := preload("res://scripts/car/track_ribbon.gd")
const MeshBatchScript := preload("res://scripts/world/shared/mesh_batch.gd")
const WindShader := preload("res://shaders/wind_foliage.gdshader")

const SEED: int = 5505
const MAX_TREES: int = 1100
const ATTEMPTS: int = 30000
## Clusters: trees only grow where this low-frequency noise is above CLUSTER_FLOOR (so they form groves).
const CLUSTER_FREQUENCY: float = 0.011
const CLUSTER_FLOOR: float = -0.12
## Minimum spacing between any two trunks (Poisson-disc radius).
const SPACING_M: float = 6.0
## Distance band from the asphalt edge: trees start 18 m out (beyond the armco and fence) and thin out by 130 m.
const MIN_FROM_EDGE_M: float = 18.0
const MAX_FROM_CENTRE_M: float = 140.0
## The centreline is sampled every SAMPLE_M, so the measured distance over-estimates by up to this much.
const SAMPLE_M: float = 6.0
const SAMPLE_SLACK_M: float = 3.0
const CELL_M: float = 40.0
## Share of each kind (cedar, oak, pine); the remainder is pine.
const CEDAR_SHARE: float = 0.45
const OAK_SHARE: float = 0.35
const SCALE_RANGE: Vector2 = Vector2(0.8, 1.5)
const PINE_LEAN_RAD: float = deg_to_rad(6.0)

const TRUNK_COLOR := Color("#7b4a2d")
const CEDAR_COLORS: Array[Color] = [Color("#2c7a4b"), Color("#33895a"), Color("#3c9a68")]
const OAK_COLORS: Array[Color] = [Color("#4fae45"), Color("#63c254"), Color("#7ad66a")]
const PINE_COLORS: Array[Color] = [Color("#3f8f78"), Color("#4aa08a")]

var kind_instances: Dictionary = {} # "cedar" | "oak" | "pine" -> MultiMeshInstance3D
var tree_positions: PackedVector3Array = PackedVector3Array()
var tree_count: int = 0
var wind_material: ShaderMaterial

var _ribbon: TrackRibbonScript
var _samples: Dictionary = {} # grid cell -> PackedVector3Array(x, arc distance, z)


## `keep_out` zones are {side, s0, s1, lateral_max}: no tree on that side of the road within
## that arc range and that far out.
func build(p_ribbon: TrackRibbonScript, keep_out: Array[Dictionary]) -> void:
	_ribbon = p_ribbon
	_hash_centreline()
	wind_material = ShaderMaterial.new()
	wind_material.shader = WindShader
	var kinds: Dictionary = {"cedar": [], "oak": [], "pine": []}
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED
	var cells: Dictionary = {} # Poisson grid: cell -> Vector2 positions
	var cell: float = SPACING_M / sqrt(2.0)
	var groves := FastNoiseLite.new()
	groves.seed = SEED
	groves.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	groves.frequency = CLUSTER_FREQUENCY
	var near: float = _ribbon.road_half_width_m + MIN_FROM_EDGE_M + SAMPLE_SLACK_M
	for _attempt: int in range(ATTEMPTS):
		if tree_positions.size() >= MAX_TREES:
			break
		# Candidates hug the track: a random arc distance and a lateral offset in the allowed band.
		var s: float = rng.randf() * _ribbon.length_m
		var lateral: float = (-1.0 if rng.randf() < 0.5 else 1.0) * rng.randf_range(near, MAX_FROM_CENTRE_M)
		var origin: Vector3 = _ribbon.get_point_at_offset(s, lateral).origin
		var candidate := Vector2(origin.x, origin.z)
		if groves.get_noise_2d(candidate.x, candidate.y) < CLUSTER_FLOOR:
			continue
		if not _accepts(candidate, s, lateral, keep_out, cells, cell):
			continue
		var key := Vector2i(floori(candidate.x / cell), floori(candidate.y / cell))
		if not cells.has(key):
			cells[key] = []
		(cells[key] as Array).append(candidate)
		var position := Vector3(candidate.x, 0.0, candidate.y)
		tree_positions.append(position)
		var roll: float = rng.randf()
		var kind: String = "cedar" if roll < CEDAR_SHARE else ("oak" if roll < CEDAR_SHARE + OAK_SHARE else "pine")
		var scale: float = rng.randf_range(SCALE_RANGE.x, SCALE_RANGE.y)
		var basis := Basis(Vector3.UP, rng.randf() * TAU)
		if kind == "pine":
			basis = basis * Basis(Vector3.FORWARD, rng.randf_range(-PINE_LEAN_RAD, PINE_LEAN_RAD))
		(kinds[kind] as Array).append(Transform3D(basis.scaled(Vector3.ONE * scale), position))
	tree_count = tree_positions.size()
	kind_instances["cedar"] = _add_kind("TreeCedars", _cedar_mesh(), kinds["cedar"])
	kind_instances["oak"] = _add_kind("TreeOaks", _oak_mesh(), kinds["oak"])
	kind_instances["pine"] = _add_kind("TreePines", _pine_mesh(), kinds["pine"])


## Sway for the weather: amplitude in meters at the crest, gust speed in rad/s.
func set_wind(amplitude: float, speed: float) -> void:
	wind_material.set_shader_parameter("wind_amplitude", amplitude)
	wind_material.set_shader_parameter("wind_speed", speed)


# --- placement ------------------------------------------------------------------

func _hash_centreline() -> void:
	var s: float = 0.0
	while s < _ribbon.length_m:
		var point: Vector3 = _ribbon.get_point_at_offset(s, 0.0).origin
		var key := Vector2i(floori(point.x / CELL_M), floori(point.z / CELL_M))
		if not _samples.has(key):
			_samples[key] = PackedVector3Array()
		_samples[key].append(Vector3(point.x, s, point.z))
		s += SAMPLE_M


## Nearest centreline sample within `reach` grid cells: {distance, s} on the ground plane (distance INF if none).
func _nearest_sample(position: Vector2, reach: int) -> Dictionary:
	var best: float = INF
	var best_s: float = 0.0
	var cx: int = floori(position.x / CELL_M)
	var cz: int = floori(position.y / CELL_M)
	for dx: int in range(-reach, reach + 1):
		for dz: int in range(-reach, reach + 1):
			var key := Vector2i(cx + dx, cz + dz)
			if not _samples.has(key):
				continue
			for sample: Vector3 in _samples[key]:
				var distance: float = Vector2(sample.x, sample.z).distance_to(position)
				if distance < best:
					best = distance
					best_s = sample.y
	return {"distance": best, "s": best_s}


## True when a tree may stand at `candidate` (generated at arc `s`, signed `lateral`): clear of every
## stretch of road, outside the keep-out zones (judged from its own and from its nearest road) and
## Poisson-spaced from the trees already placed.
func _accepts(candidate: Vector2, s: float, lateral: float, keep_out: Array[Dictionary], cells: Dictionary, cell: float) -> bool:
	var near: float = _ribbon.road_half_width_m + MIN_FROM_EDGE_M + SAMPLE_SLACK_M
	var closest: Dictionary = _nearest_sample(candidate, 1)
	if float(closest["distance"]) < near:
		return false
	if _in_keep_out(keep_out, s, lateral):
		return false
	# Its nearest road may be another stretch than the one it was generated from.
	var nearest: Dictionary = _nearest_sample(candidate, 3)
	var pose: Transform3D = _ribbon.get_point_at_offset(float(nearest["s"]), 0.0)
	var nearest_lateral: float = (Vector3(candidate.x, 0.0, candidate.y) - pose.origin).dot(pose.basis.x)
	if _in_keep_out(keep_out, float(nearest["s"]), nearest_lateral):
		return false
	var cx: int = floori(candidate.x / cell)
	var cz: int = floori(candidate.y / cell)
	for dx: int in range(-2, 3):
		for dz: int in range(-2, 3):
			var key := Vector2i(cx + dx, cz + dz)
			if cells.has(key):
				for other: Vector2 in cells[key]:
					if other.distance_to(candidate) < SPACING_M:
						return false
	return true


func _in_keep_out(keep_out: Array[Dictionary], s: float, lateral: float) -> bool:
	for zone: Dictionary in keep_out:
		var span: float = float(zone["s1"]) - float(zone["s0"])
		if signf(lateral) == float(zone["side"]) and absf(lateral) < float(zone["lateral_max"]) and fposmod(s - float(zone["s0"]), _ribbon.length_m) <= span:
			return true
	return false

# --- meshes -----------------------------------------------------------------------

func _add_kind(node_name: String, mesh: ArrayMesh, transforms: Array) -> MultiMeshInstance3D:
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
	# Circuit-wide batches land in every shadow split: casting cost ~200 draw calls at the worst Apex view.
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(instance)
	return instance


## Tall pointed cedar: trunk and three stacked cones, ~9 m. Alpha is the sway weight.
func _cedar_mesh() -> ArrayMesh:
	var batch := MeshBatchScript.new()
	var material := StandardMaterial3D.new() # key only: the wind material replaces it on the surface
	batch.cylinder(material, _weighted(TRUNK_COLOR, 0.0), Transform3D.IDENTITY, 0.3, 0.2, 2.2, 6, false)
	var tiers: Array[Vector3] = [Vector3(1.9, 2.0, 3.6), Vector3(1.5, 4.2, 3.2), Vector3(1.0, 6.2, 2.9)] # radius, base height, tier height
	for index: int in range(tiers.size()):
		var weight: float = 0.4 + 0.3 * float(index)
		batch.cylinder(material, _weighted(CEDAR_COLORS[index], weight), Transform3D(Basis.IDENTITY, Vector3(0.0, tiers[index].y, 0.0)), tiers[index].x, 0.0, tiers[index].z, 7, false)
	return batch.commit()


## Layered round oak: short trunk and three stacked, tapering lumps, ~6.4 m.
func _oak_mesh() -> ArrayMesh:
	var batch := MeshBatchScript.new()
	var material := StandardMaterial3D.new() # key only: the wind material replaces it on the surface
	batch.cylinder(material, _weighted(TRUNK_COLOR, 0.0), Transform3D.IDENTITY, 0.34, 0.24, 2.0, 6, false)
	var lumps: Array[Vector3] = [Vector3(2.3, 1.7, 1.6), Vector3(1.9, 3.0, 1.5), Vector3(1.2, 4.2, 1.2)] # radius, base height, lump height
	for index: int in range(lumps.size()):
		var weight: float = 0.4 + 0.3 * float(index)
		var base := Transform3D(Basis.IDENTITY, Vector3(0.0, lumps[index].y, 0.0))
		batch.cylinder(material, _weighted(OAK_COLORS[index], weight), base, lumps[index].x, lumps[index].x * 0.55, lumps[index].z, 8, true, false)
	return batch.commit()


## Slender slope pine: bare trunk and four thin cones, ~8.5 m.
func _pine_mesh() -> ArrayMesh:
	var batch := MeshBatchScript.new()
	var material := StandardMaterial3D.new() # key only: the wind material replaces it on the surface
	batch.cylinder(material, _weighted(TRUNK_COLOR, 0.0), Transform3D.IDENTITY, 0.22, 0.14, 3.4, 6, false)
	for index: int in range(4):
		var radius: float = 1.5 - 0.28 * float(index)
		var base_y: float = 2.4 + 1.3 * float(index)
		var color: Color = PINE_COLORS[index % PINE_COLORS.size()]
		batch.cylinder(material, _weighted(color, 0.4 + 0.2 * float(index)), Transform3D(Basis.IDENTITY, Vector3(0.0, base_y, 0.0)), radius, 0.0, 2.2, 6, false)
	return batch.commit()


func _weighted(color: Color, weight: float) -> Color:
	return Color(color, weight)
