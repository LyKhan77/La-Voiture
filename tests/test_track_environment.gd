extends SceneTree

## FASE 10 acceptance: hybrid procedural track environment (Apex Ring International).
## Surface and kerb profile, runoff and gravel, trackside furniture, hero architecture,
## horizon vista, foliage and time-of-day lighting. Geometry is read back from the built
## world, so the checks hold for whatever the generators emit.
## Run: Godot --headless --path . -s res://tests/test_track_environment.gd

const WorldScene := preload("res://scenes/race_weekend_world.tscn")
const ToonMaterialsScript := preload("res://scripts/world/shared/toon_materials.gd")
const ActorScript := preload("res://scripts/car/gt_car_actor.gd")
const PitLaneScript := preload("res://scripts/world/circuits/apex_ring/apex_pit_complex.gd")
const EnhancedGeometry := preload("res://scripts/world/shared/enhanced_track_geometry.gd")
const LiveriesScript := preload("res://scripts/car/team_liveries.gd")

const ROAD_SHADER_PATH := "res://shaders/road_asphalt.gdshader"
const KERB_MAX_Y: float = 0.05
const HASH_CELL_M: float = 40.0

var failures: int = 0
var assertions: int = 0
var world: Node3D
var _centre_hash: Dictionary = {}


func _initialize() -> void:
	call_deferred("_run")


func check(ok: bool, description: String) -> void:
	assertions += 1
	if not ok:
		failures += 1
		push_error(description)
	print("[%s] %s" % ["PASS" if ok else "FAIL", description])


func _run() -> void:
	world = WorldScene.instantiate()
	root.add_child(world)
	world.set_physics_process(false)
	await process_frame
	_hash_centreline()
	_test_stage1_surface_and_kerbs()
	_test_stage1_runoff_and_groove()
	_test_mesh_batch()
	_test_stage2_furniture()
	_test_stage3_architecture()
	_test_feedback_barriers()
	_test_stage4_vista_and_foliage()
	_test_stage5_budget()
	await _test_stage4_lighting()
	world.race.dispose()
	world.queue_free()
	# Audio voices release a frame after their world; wait so nothing is still alive at shutdown.
	for _frame: int in range(3):
		await process_frame
	ToonMaterialsScript._cache.clear()
	ActorScript._paint_cache.clear()
	print("%d assertions, %d failure(s)" % [assertions, failures])
	print("FASE 10 TRACK ENVIRONMENT: %s" % ("PASS" if failures == 0 else "%d FAILURES" % failures))
	quit(0 if failures == 0 else 1)


const MESH_BATCH_PATH := "res://scripts/world/shared/mesh_batch.gd"
const PIT_CLOSED_FROM_S: float = PitLaneScript.ENTRY_S - 20.0
const PIT_CLOSED_TO_S: float = PitLaneScript.ENTRY_S + PitLaneScript.NOMINAL_LENGTH_M + 40.0


# --- helpers ---------------------------------------------------------------------

## Reads a property that may not exist yet, so a missing feature fails a check instead of aborting the run.
func prop(object: Object, name: String) -> Variant:
	return object.get(name) if object != null else null


func vertices_of(instance: MeshInstance3D, surface: int = -1) -> PackedVector3Array:
	var all := PackedVector3Array()
	if instance == null or instance.mesh == null:
		return all
	for index: int in range(instance.mesh.get_surface_count()):
		if surface >= 0 and index != surface:
			continue
		all.append_array(instance.mesh.surface_get_arrays(index)[Mesh.ARRAY_VERTEX])
	return all


func _hash_centreline() -> void:
	var s: float = 0.0
	while s < world.ribbon.length_m:
		var point: Vector3 = world.ribbon.get_point_at_offset(s, 0.0).origin
		var key := Vector2i(floori(point.x / HASH_CELL_M), floori(point.z / HASH_CELL_M))
		if not _centre_hash.has(key):
			_centre_hash[key] = PackedVector3Array()
		_centre_hash[key].append(Vector3(point.x, s, point.z)) # x, arc distance, z
		s += 3.0


## Distance on the ground plane to the closest centreline sample (3 m apart, so +-1.5 m of slack).
func centre_distance(point: Vector3) -> float:
	var cx: int = floori(point.x / HASH_CELL_M)
	var cz: int = floori(point.z / HASH_CELL_M)
	var best: float = INF
	for dx: int in range(-1, 2):
		for dz: int in range(-1, 2):
			var key := Vector2i(cx + dx, cz + dz)
			if _centre_hash.has(key):
				for sample: Vector3 in _centre_hash[key]:
					best = minf(best, Vector2(sample.x - point.x, sample.z - point.z).length())
	return best


## Arc distance and signed lateral (+ = right of travel) of a point against the nearest centreline
## sample; `reach` is how many 40 m grid cells around the point are searched (far points need more).
func ribbon_frame(point: Vector3, reach: int = 1) -> Vector2:
	var cx: int = floori(point.x / HASH_CELL_M)
	var cz: int = floori(point.z / HASH_CELL_M)
	var best: float = INF
	var best_s: float = 0.0
	for dx: int in range(-reach, reach + 1):
		for dz: int in range(-reach, reach + 1):
			var key := Vector2i(cx + dx, cz + dz)
			if _centre_hash.has(key):
				for sample: Vector3 in _centre_hash[key]:
					var distance: float = Vector2(sample.x - point.x, sample.z - point.z).length()
					if distance < best:
						best = distance
						best_s = sample.y
	var pose: Transform3D = world.ribbon.get_point_at_offset(best_s, 0.0)
	var offset: Vector3 = point - pose.origin
	return Vector2(fposmod(best_s - offset.dot(pose.basis.z), world.ribbon.length_m), offset.dot(pose.basis.x))


## Poses a builder handed to its MultiMesh (headless runs cannot read MultiMesh data back).
func poses_of(owner: Object, property: String) -> Array[Transform3D]:
	var list: Array[Transform3D] = []
	for pose: Transform3D in prop(owner, property) if owner != null and prop(owner, property) != null else []:
		list.append(pose)
	return list


## Largest and second largest straight-line gap between neighbours around the lap, ordered by arc
## distance; `entries` are [arc, position] pairs. The largest is the pit opening on the right.
func chain_gaps(entries: Array[Array]) -> Vector2:
	entries.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) < float(b[0]))
	var largest: float = 0.0
	var second: float = 0.0
	for index: int in range(entries.size()):
		var gap: float = (entries[index][1] as Vector3).distance_to(entries[(index + 1) % entries.size()][1])
		if gap > largest:
			second = largest
			largest = gap
		elif gap > second:
			second = gap
	return Vector2(largest, second)


func apex_of(kerb: Dictionary) -> float:
	var best: float = float(kerb["s0"])
	var peak: float = 0.0
	var s: float = float(kerb["s0"])
	while s <= float(kerb["s1"]):
		var kappa: float = absf(world.track.line.curvature_at(s))
		if kappa > peak:
			peak = kappa
			best = s
		s += 2.0
	return best


# --- stage 1: surface, kerbs ---------------------------------------------------------

func _test_stage1_surface_and_kerbs() -> void:
	var ribbon = world.ribbon
	var flat: bool = true
	var s: float = 0.0
	while s < ribbon.length_m:
		flat = flat and is_zero_approx(ribbon.get_point_at_offset(s, 0.0).origin.y) and is_zero_approx(ribbon.get_point_at_offset(s, 6.5).origin.y)
		s += 20.0
	var asphalt: PackedVector3Array = vertices_of(ribbon.get_node("RoadMesh") as MeshInstance3D, 0)
	var asphalt_min: float = INF
	var asphalt_max: float = -INF
	for vertex: Vector3 in asphalt:
		asphalt_min = minf(asphalt_min, vertex.y)
		asphalt_max = maxf(asphalt_max, vertex.y)
	# The road mesh is one surface: asphalt at 0.0 plus paint layers at 0.02 (lines) and 0.03 (start line).
	check(flat and asphalt_min == 0.0 and asphalt_max <= 0.031,
		"#S1 asphalt surface stays at Y = 0.0 m, paint at most 0.03 m (min %.3f, max %.3f over %d vertices)" % [asphalt_min, asphalt_max, asphalt.size()])

	# The physics spline is off limits: same 303 control points and the same 4 158.75 m lap as before this phase.
	check(ribbon.curve.point_count == 303 and absf(ribbon.length_m - 4158.7505) < 0.01,
		"#S0 the track spline is untouched (%d control points, %.2f m lap)" % [ribbon.curve.point_count, ribbon.length_m])

	var shader := world.vfx.track_material.shader as Shader
	var uniforms: Array[String] = []
	if shader != null:
		for entry: Dictionary in shader.get_shader_uniform_list():
			uniforms.append(String(entry["name"]))
	check(shader != null and shader.resource_path == ROAD_SHADER_PATH and uniforms.has("track_wetness") and uniforms.has("rain_intensity")
		and uniforms.has("grit_strength") and uniforms.has("paint_wear"),
		"#S2 the road wears shaders/road_asphalt.gdshader: weather uniforms plus grit and paint wear (%s)" % [shader.resource_path if shader != null else "none"])

	var kerb_vertices: PackedVector3Array = vertices_of(prop(world.environment, "kerb_instance"))
	var kerb_peak: float = -INF
	var kerb_floor: float = INF
	var levels: Dictionary = {}
	for vertex: Vector3 in kerb_vertices:
		kerb_peak = maxf(kerb_peak, vertex.y)
		kerb_floor = minf(kerb_floor, vertex.y)
		levels[snappedf(vertex.y, 0.005)] = true
	check(kerb_vertices.size() > 0 and kerb_peak >= 0.04 and kerb_peak <= KERB_MAX_Y + 1.0e-4 and kerb_floor >= 0.0 and levels.size() >= 2,
		"#S3 kerbs are a real 3D profile: peak %.3f m (0.04..0.05 allowed), floor %.3f m, %d height levels" % [kerb_peak, kerb_floor, levels.size()])

	var normals_up: bool = true
	var arrays: Array = world.environment.kerb_instance.mesh.surface_get_arrays(0)
	for normal: Vector3 in arrays[Mesh.ARRAY_NORMAL]:
		normals_up = normals_up and normal.y > 0.5
	check(normals_up, "#S4 kerb faces point upward so the cel shader lights them")


# --- stage 1: runoff, gravel, groove ---------------------------------------------------

func _test_stage1_runoff_and_groove() -> void:
	var environment = world.environment
	var half: float = world.ribbon.road_half_width_m
	var runoff: MeshInstance3D = prop(environment, "runoff_instance")
	var gravel: MeshInstance3D = prop(environment, "gravel_instance")
	var runoff_vertices: PackedVector3Array = vertices_of(runoff)
	var gravel_vertices: PackedVector3Array = vertices_of(gravel)
	check(runoff_vertices.size() > 0 and gravel_vertices.size() > 0, "#S5 sharp corners get a tarmac runoff strip and a gravel trap (%d / %d vertices)" % [runoff_vertices.size(), gravel_vertices.size()])

	var gravel_color := Color(0, 0, 0)
	if gravel != null and gravel.mesh != null and gravel.mesh.get_surface_count() > 0:
		var material := gravel.mesh.surface_get_material(0) as ShaderMaterial
		gravel_color = material.get_shader_parameter("base_color") if material != null else gravel_color
	check(gravel_color.is_equal_approx(Color("#A69477")), "#S6 gravel is coarse sand #A69477")

	# Nothing may creep onto asphalt: the nearest centreline sample must be clear of the road edge.
	var clear: bool = true
	var low: bool = true
	for vertex: Vector3 in runoff_vertices + gravel_vertices:
		clear = clear and centre_distance(vertex) >= half - 0.05
		low = low and vertex.y > 0.0 and vertex.y < 0.04
	check(clear and low and runoff_vertices.size() > 0 and gravel_vertices.size() > 0, "#S7 runoff and gravel never cover asphalt (>= %.2f m from every centreline sample) and stay below the kerb crest" % [half - 0.05])

	# The pit lane owns the right-hand side from Pit Entry to Pit Exit, so a corner whose outside is there gets no trap.
	var pit_start: float = PitLaneScript.ENTRY_S - 20.0
	var pit_end: float = PitLaneScript.ENTRY_S + PitLaneScript.NOMINAL_LENGTH_M + 40.0
	var outside_ok: bool = environment.kerbs.size() > 0
	var trapped: int = 0
	for kerb: Dictionary in environment.kerbs:
		var mid: float = (float(kerb["s0"]) + float(kerb["s1"])) * 0.5
		var pose: Transform3D = world.ribbon.get_point_at_offset(mid, 0.0)
		var found: bool = false
		for vertex: Vector3 in gravel_vertices:
			var offset: Vector3 = vertex - pose.origin
			if offset.length() < 40.0 and absf(offset.dot(pose.basis.z)) < 3.0 and signf(offset.dot(pose.basis.x)) == -float(kerb["side"]) and absf(offset.dot(pose.basis.x)) > half + 5.0:
				found = true
				break
		var pit_side: bool = float(kerb["side"]) < 0.0 and mid >= pit_start and mid <= pit_end
		outside_ok = outside_ok and (found != pit_side)
		trapped += 1 if found else 0
	check(outside_ok and trapped >= 6, "#S8 %d sharp corners have their gravel trap on the outside, opposite the kerb; none where the outside is the pit lane" % trapped)

	var groove: MeshInstance3D = prop(environment, "groove_instance")
	var groove_vertices: PackedVector3Array = vertices_of(groove)
	var follows: bool = groove_vertices.size() > 0
	var checked: int = 0
	for kerb: Dictionary in environment.kerbs:
		var mid: float = (float(kerb["s0"]) + float(kerb["s1"])) * 0.5
		var pose: Transform3D = world.ribbon.get_point_at_offset(mid, 0.0)
		# The two groove edge vertices of the slice closest to mid share an arc distance; compare their mean to the line there.
		var slice: Array[Vector2] = [] # (|along|, lateral), forward distance in y
		var forward_of: Dictionary = {}
		for vertex: Vector3 in groove_vertices:
			var offset: Vector3 = vertex - pose.origin
			if offset.length() < 6.0:
				slice.append(Vector2(absf(offset.dot(pose.basis.z)), offset.dot(pose.basis.x)))
				forward_of[slice.size() - 1] = -offset.dot(pose.basis.z)
		var order: Array = range(slice.size())
		if order.is_empty():
			follows = false
			continue
		order.sort_custom(func(a: int, b: int) -> bool: return slice[a].x < slice[b].x)
		# Group the vertices that share the nearest slice (same arc distance, within 0.3 m of "along").
		var lateral_sum: float = 0.0
		var forward_sum: float = 0.0
		var grouped: int = 0
		for index: int in order:
			if absf(slice[index].x - slice[order[0]].x) < 0.3 and signf(float(forward_of[index])) == signf(float(forward_of[order[0]])):
				lateral_sum += slice[index].y
				forward_sum += float(forward_of[index])
				grouped += 1
		var lateral: float = lateral_sum / float(grouped)
		var expected: float = world.track.line.target_offset(mid + forward_sum / float(grouped))
		follows = follows and grouped >= 2 and absf(lateral - expected) < 0.35
		checked += 1
	var groove_y: float = INF
	var groove_top: float = -INF
	for vertex: Vector3 in groove_vertices:
		groove_y = minf(groove_y, vertex.y)
		groove_top = maxf(groove_top, vertex.y)
	check(follows and checked > 0 and groove_y > 0.0 and groove_top < 0.02,
		"#S9 the rubber groove follows the adaptive racing line through %d corners, a hair above the asphalt (%.3f..%.3f m)" % [checked, groove_y, groove_top])

# --- stage 2: mesh batch and trackside furniture ------------------------------------------

func _test_mesh_batch() -> void:
	var script: Script = load(MESH_BATCH_PATH) if ResourceLoader.exists(MESH_BATCH_PATH) else null
	if script == null:
		check(false, "#M1 MeshBatch merges primitives into one surface per material")
		check(false, "#M2 MeshBatch faces wind clockwise and point away from the primitive")
		check(false, "#M3 MeshBatch extrusions are closed walls whatever the profile direction")
		return
	var steel := StandardMaterial3D.new()
	var glass := StandardMaterial3D.new()
	var batch = script.new()
	batch.box(steel, Color.RED, Transform3D(Basis.IDENTITY, Vector3(0, 1, 0)), Vector3(2, 2, 2))
	batch.box(glass, Color.WHITE, Transform3D(Basis.IDENTITY, Vector3(9, 1, 0)), Vector3(1, 1, 1))
	batch.box(steel, Color.BLUE, Transform3D(Basis(Vector3.UP, 0.7), Vector3(5, 1, 0)), Vector3(1, 1, 1))
	var mesh: ArrayMesh = batch.commit()
	check(mesh.get_surface_count() == 2 and mesh.surface_get_material(0) == steel and mesh.surface_get_material(1) == glass
		and mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX].size() == 72 and mesh.surface_get_arrays(1)[Mesh.ARRAY_VERTEX].size() == 36,
		"#M1 MeshBatch merges primitives into one surface per material (2 surfaces: 72 + 36 vertices)")

	var centres: Array[Vector3] = [Vector3(0, 1, 0), Vector3(5, 1, 0)]
	var wound: bool = true
	var outward: bool = true
	var vertices: PackedVector3Array = mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = mesh.surface_get_arrays(0)[Mesh.ARRAY_NORMAL]
	for index: int in range(0, vertices.size(), 3):
		var a: Vector3 = vertices[index]
		var b: Vector3 = vertices[index + 1]
		var c: Vector3 = vertices[index + 2]
		var face: Vector3 = (c - a).cross(b - a)
		wound = wound and face.dot(normals[index]) > 0.0
		var centroid: Vector3 = (a + b + c) / 3.0
		var near: Vector3 = centres[0] if centroid.distance_to(centres[0]) < centroid.distance_to(centres[1]) else centres[1]
		outward = outward and normals[index].dot(centroid - near) > 0.0
	check(wound and outward, "#M2 MeshBatch faces wind clockwise (Godot front face) and point away from their box")

	var closed: bool = true
	for reverse: bool in [false, true]:
		var profile := PackedVector2Array([Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)])
		if reverse:
			profile.reverse()
		var prism = script.new()
		prism.extrude(steel, Color.GREEN, Transform3D.IDENTITY, profile, 2.0)
		var walls: ArrayMesh = prism.commit()
		var wall_vertices: PackedVector3Array = walls.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
		var wall_normals: PackedVector3Array = walls.surface_get_arrays(0)[Mesh.ARRAY_NORMAL]
		closed = closed and wall_vertices.size() == 24
		for index: int in range(wall_vertices.size()):
			var from_axis: Vector3 = wall_vertices[index] - Vector3(0.5, 0.5, 0.0)
			from_axis.z = 0.0
			closed = closed and wall_normals[index].dot(from_axis) > 0.0
	check(closed, "#M3 MeshBatch extrusions are 4 outward walls (24 vertices) for a clockwise and a counter-clockwise profile")

	# End caps close the open ends (the grandstand wedges were see-through from the side without them).
	var square := PackedVector2Array([Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)])
	var open_batch = script.new()
	open_batch.extrude(steel, Color.GREEN, Transform3D.IDENTITY, square, 2.0)
	var capped_batch = script.new()
	capped_batch.extrude(steel, Color.GREEN, Transform3D.IDENTITY, square, 2.0, true)
	var capped_arrays: Array = capped_batch.commit().surface_get_arrays(0)
	var cap_vertices: PackedVector3Array = capped_arrays[Mesh.ARRAY_VERTEX]
	var cap_normals: PackedVector3Array = capped_arrays[Mesh.ARRAY_NORMAL]
	var caps_ok: bool = open_batch.commit().surface_get_arrays(0)[Mesh.ARRAY_VERTEX].size() == 24 and cap_vertices.size() == 36
	for index: int in range(cap_vertices.size()):
		var z: float = cap_vertices[index].z
		if absf(absf(z) - 1.0) < 0.001 and absf(cap_normals[index].z) > 0.99:
			caps_ok = caps_ok and cap_normals[index].z * z > 0.0 # cap normals point out of their end
	check(caps_ok, "#M4 a capped extrusion adds both end caps (36 vertices), each facing out of its end")


func _test_stage2_furniture() -> void:
	var environment = world.environment
	var furniture: Node3D = prop(environment, "furniture")
	var instances: Array[MultiMeshInstance3D] = []
	var surfaces: int = 0
	if furniture != null:
		for child: Node in furniture.get_children():
			if child is MultiMeshInstance3D:
				instances.append(child)
				surfaces += (child as MultiMeshInstance3D).multimesh.mesh.get_surface_count()
	check(furniture != null and instances.size() == 5 and surfaces <= 10,
		"#F1 furniture is five MultiMeshInstance3D (armco, tecpro, markers, floodlights, flag panels) with %d surfaces in total" % surfaces)

	var half: float = world.ribbon.road_half_width_m
	var armco_poses: Array[Transform3D] = poses_of(furniture, "armco_transforms")
	# Every unbroken run of rail: posts at most 4.8 m apart; the left runs the whole lap, the right leaves one pit opening.
	var runs: Array = prop(furniture, "armco_runs") if furniture != null else []
	var worst_gap: float = 0.0
	var left_closed: bool = false
	var opening: float = 0.0
	var right_runs: int = 0
	var ends_ok: bool = false
	for run: Dictionary in runs:
		var first: int = int(run["first"])
		var count: int = int(run["count"])
		for index: int in range(first, first + count - 1):
			worst_gap = maxf(worst_gap, armco_poses[index].origin.distance_to(armco_poses[index + 1].origin))
		if float(run["side"]) < 0.0:
			left_closed = armco_poses[first].origin.distance_to(armco_poses[first + count - 1].origin) <= 4.8
		else:
			right_runs += 1
			opening = world.ribbon.length_m - (float(run["s1"]) - float(run["s0"]))
			var start_frame: Vector2 = ribbon_frame(armco_poses[first].origin)
			var end_frame: Vector2 = ribbon_frame(armco_poses[first + count - 1].origin)
			ends_ok = absf(start_frame.x - fposmod(PIT_CLOSED_TO_S, world.ribbon.length_m)) < 8.0 and absf(end_frame.x - PIT_CLOSED_FROM_S) < 8.0
	check(armco_poses.size() > 1700 and runs.size() == 2 and right_runs == 1 and worst_gap <= 4.8 and left_closed and ends_ok
		and opening >= PitLaneScript.NOMINAL_LENGTH_M and opening <= PIT_CLOSED_TO_S - PIT_CLOSED_FROM_S + 12.0,
		"#F2 armco is continuous (posts at most %.1f m apart, left lap closed: %s) except one %.0f m opening for Pit Entry to Exit, %d posts" % [
			worst_gap, left_closed, opening, armco_poses.size()])

	# Where a gravel trap pushes the run-off wide, the armco stands behind it.
	var behind_trap: bool = true
	var trap_misses: Array[String] = []
	var traps: int = 0
	for plan: Dictionary in environment.runoff_plans:
		var mid: float = (float(plan["s0"]) + float(plan["s1"])) * 0.5
		var width: float = EnhancedGeometry.plan_width_at(plan, mid)
		if width < 8.0:
			continue
		traps += 1
		# Lateral of the post generated closest to mid on the plan's side, measured on the road it was generated for.
		var nearest: float = INF
		var lateral: float = 0.0
		var armco_arcs_list: PackedFloat32Array = arcs_of(furniture, "armco_arcs")
		for index: int in range(mini(armco_poses.size(), armco_arcs_list.size())):
			var own_pose: Transform3D = world.ribbon.get_point_at_offset(armco_arcs_list[index], 0.0)
			var offset: float = (armco_poses[index].origin - own_pose.origin).dot(own_pose.basis.x)
			var arc_gap: float = absf(fposmod(armco_arcs_list[index] - mid + world.ribbon.length_m * 0.5, world.ribbon.length_m) - world.ribbon.length_m * 0.5)
			if signf(offset) == float(plan["side"]) and arc_gap < nearest:
				nearest = arc_gap
				lateral = absf(offset)
		if lateral < half + width + 0.8:
			trap_misses.append("s=%.0f side=%d trap %.1f m, rail at %.1f m" % [mid, int(plan["side"]), width, lateral - half])
		behind_trap = behind_trap and lateral >= half + width + 0.8
	check(behind_trap and traps >= 6, "#F3 armco stands behind the gravel trap of all %d wide-runoff corners %s" % [traps, str(trap_misses)])

	var records: Array = prop(furniture, "marker_records") if furniture != null else []
	var marker_poses: Array[Transform3D] = poses_of(furniture, "marker_transforms")
	var markers_ok: bool = records.size() == environment.kerbs.size() * 3 and marker_poses.size() == records.size()
	for corner: int in range(environment.kerbs.size()):
		var kerb: Dictionary = environment.kerbs[corner]
		var apex: float = apex_of(kerb)
		for meters: int in [150, 100, 50]:
			var found: bool = false
			for index: int in range(mini(records.size(), marker_poses.size())):
				var record: Dictionary = records[index]
				if int(record["corner"]) != corner or int(record["meters"]) != meters:
					continue
				var frame: Vector2 = ribbon_frame(marker_poses[index].origin)
				found = absf(fposmod(frame.x - (apex - float(meters)) + world.ribbon.length_m * 0.5, world.ribbon.length_m) - world.ribbon.length_m * 0.5) < 2.0 \
					and signf(frame.y) == float(kerb["side"]) and absf(absf(frame.y) - (half + 2.5)) < 0.25
				if found:
					break
			markers_ok = markers_ok and found
	check(markers_ok, "#F4 150/100/50 m braking boards stand 2.5 m off the track edge before the apex of every one of the %d sharp corners" % environment.kerbs.size())

	var tower_poses: Array[Transform3D] = poses_of(furniture, "tower_transforms")
	var tower_mesh: Mesh = (prop(furniture, "tower_instance") as MultiMeshInstance3D).multimesh.mesh if furniture != null else null
	var towers_ok: bool = tower_poses.size() == 28 and tower_mesh != null and absf(tower_mesh.get_aabb().size.y - 18.0) < 0.6
	var close: float = INF
	var nearest_road: float = INF
	for index: int in range(tower_poses.size()):
		nearest_road = minf(nearest_road, centre_distance(tower_poses[index].origin))
		towers_ok = towers_ok and centre_distance(tower_poses[index].origin) >= half + 8.0
		for other: int in range(index + 1, tower_poses.size()):
			close = minf(close, tower_poses[index].origin.distance_to(tower_poses[other].origin))
	check(towers_ok and close > 40.0, "#F5 28 floodlight towers, 18 m tall (%.1f), clear of the road edge (%.1f m from a centreline) and >= 40 m apart (closest %.0f m), %d placed" % [tower_mesh.get_aabb().size.y if tower_mesh != null else 0.0, nearest_road, close, tower_poses.size()])

	var tecpro_poses: Array[Transform3D] = poses_of(furniture, "tecpro_transforms")
	var zones: Array[int] = [0]
	var hairpin: int = 0
	var hairpin_kappa: float = 0.0
	for corner: int in range(environment.kerbs.size()):
		var kappa: float = absf(world.track.line.curvature_at(apex_of(environment.kerbs[corner])))
		if kappa > hairpin_kappa:
			hairpin_kappa = kappa
			hairpin = corner
	zones.append(hairpin)
	for corner: int in range(environment.kerbs.size() - 1):
		var gap: float = float(environment.kerbs[corner + 1]["s0"]) - float(environment.kerbs[corner]["s1"])
		if gap < 20.0 and float(environment.kerbs[corner]["side"]) != float(environment.kerbs[corner + 1]["side"]):
			zones.append(corner)
			zones.append(corner + 1)
	var tecpro_ok: bool = tecpro_poses.size() >= 60
	for pose: Transform3D in tecpro_poses:
		tecpro_ok = tecpro_ok and absf(ribbon_frame(pose.origin).y) >= half + 1.5
	for corner: int in zones:
		var kerb: Dictionary = environment.kerbs[corner]
		var inside_zone: int = 0
		for pose: Transform3D in tecpro_poses:
			var frame: Vector2 = ribbon_frame(pose.origin)
			if frame.x >= float(kerb["s0"]) - 10.0 and frame.x <= float(kerb["s1"]) + 10.0 and signf(frame.y) == -float(kerb["side"]):
				inside_zone += 1
		tecpro_ok = tecpro_ok and inside_zone >= 8
	check(tecpro_ok, "#F6 %d Tecpro blocks line the outside of Turn 1, the hairpin and the chicane (zones %s), none on the asphalt" % [tecpro_poses.size(), zones])


# --- stage 3: hero architecture ---------------------------------------------------------------

const PADDOCK_SCENES: Dictionary = {
	"PitBuilding": "res://scenes/race_world/paddock/pit_building_structure.tscn",
	"MainGrandstand": "res://scenes/race_world/paddock/main_grandstand.tscn",
	"RaceControlTower": "res://scenes/race_world/paddock/race_control_tower.tscn",
}
const CAR_CORRIDOR_M: float = 17.5
const CORRIDOR_CLEARANCE_M: float = 6.0


## World-space vertices of every MeshInstance3D under `root` (stride keeps big buildings quick).
func world_vertices(node: Node, stride: int = 2) -> PackedVector3Array:
	var all := PackedVector3Array()
	if node == null:
		return all
	var stack: Array[Node] = [node]
	while not stack.is_empty():
		var current: Node = stack.pop_back()
		stack.append_array(current.get_children())
		var instance := current as MeshInstance3D
		if instance == null or instance.mesh == null:
			continue
		for surface: int in range(instance.mesh.get_surface_count()):
			var vertices: PackedVector3Array = instance.mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]
			for index: int in range(0, vertices.size(), stride):
				all.append(instance.global_transform * vertices[index])
	return all


## Arc range [min, max] (around `centre_s`), lateral range and lowest point of the vertices.
func footprint(vertices: PackedVector3Array, centre_s: float) -> Dictionary:
	var result: Dictionary = {"s_min": INF, "s_max": -INF, "lat_min": INF, "lat_max": -INF, "y_min": INF, "y_max": -INF, "low_in_corridor": INF}
	for vertex: Vector3 in vertices:
		var frame: Vector2 = ribbon_frame(vertex)
		var arc: float = fposmod(frame.x - centre_s + world.ribbon.length_m * 0.5, world.ribbon.length_m) - world.ribbon.length_m * 0.5 + centre_s
		result["s_min"] = minf(result["s_min"], arc)
		result["s_max"] = maxf(result["s_max"], arc)
		result["lat_min"] = minf(result["lat_min"], frame.y)
		result["lat_max"] = maxf(result["lat_max"], frame.y)
		result["y_min"] = minf(result["y_min"], vertex.y)
		result["y_max"] = maxf(result["y_max"], vertex.y)
		if absf(frame.y) < CAR_CORRIDOR_M:
			result["low_in_corridor"] = minf(result["low_in_corridor"], vertex.y)
	return result


func _test_stage3_architecture() -> void:
	var environment = world.environment
	var paddock: Node3D = prop(environment, "paddock")
	var instanced: bool = paddock != null
	for node_name: String in PADDOCK_SCENES:
		var child: Node = paddock.get_node_or_null(node_name) if paddock != null else null
		instanced = instanced and child != null and child.scene_file_path == PADDOCK_SCENES[node_name]
	check(instanced, "#H1 the paddock holds the pit building, main grandstand and race control tower, each instanced from its own scene")

	var pit: Node3D = paddock.get_node_or_null("PitBuilding") if paddock != null else null
	var pit_box: Dictionary = footprint(world_vertices(pit), 3988.0)
	var glass_ok: bool = false
	if pit != null:
		for instance: Node in pit.find_children("*", "MeshInstance3D", true, false):
			for surface: int in range((instance as MeshInstance3D).mesh.get_surface_count()):
				var material := (instance as MeshInstance3D).mesh.surface_get_material(surface) as StandardMaterial3D
				glass_ok = glass_ok or (material != null and material.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED)
	check(pit != null and pit_box["s_max"] - pit_box["s_min"] >= 136.0 and pit_box["s_min"] >= 3905.0 and pit_box["s_max"] <= 4070.0
		and pit_box["lat_min"] >= 16.0 and pit_box["lat_max"] <= 31.5 and pit_box["y_max"] >= 8.4 and glass_ok and pit_box["low_in_corridor"] >= CORRIDOR_CLEARANCE_M,
		"#H2 the two-storey pit building spans all ten stalls (%.0f m, lateral %.1f..%.1f, top %.1f m) with a tinted glass lounge, behind the working lane (nothing over the car corridor lower than %.1f m)" % [
			pit_box["s_max"] - pit_box["s_min"], pit_box["lat_min"], pit_box["lat_max"], pit_box["y_max"], pit_box["low_in_corridor"]])

	var stand: Node3D = paddock.get_node_or_null("MainGrandstand") if paddock != null else null
	var stand_box: Dictionary = footprint(world_vertices(stand), 125.0)
	var tiers: Array = prop(stand, "tier_heights") if stand != null else []
	var crowd: MultiMeshInstance3D = prop(stand, "crowd_instance")
	var screen: MeshInstance3D = prop(stand, "jumbotron")
	var screen_ok: bool = false
	if screen != null:
		var screen_box: AABB = screen.global_transform * screen.mesh.get_aabb()
		var screen_material := screen.mesh.surface_get_material(0) as ShaderMaterial if screen.mesh.get_surface_count() > 0 else null
		var normal: Vector3 = screen.global_transform.basis * (screen.mesh.surface_get_arrays(0)[Mesh.ARRAY_NORMAL] as PackedVector3Array)[0]
		var toward_track: Vector3 = world.ribbon.get_point_at_offset(125.0, 0.0).basis.x
		screen_ok = maxf(screen_box.size.x, screen_box.size.z) >= 20.0 and screen_box.size.y >= 7.0 and normal.normalized().dot(toward_track) > 0.9 and screen_material != null
	check(stand != null and stand_box["s_max"] - stand_box["s_min"] >= 236.0 and stand_box["lat_max"] <= -12.0 and stand_box["y_max"] >= 24.0 and tiers.size() == 3
		and stand_box["low_in_corridor"] >= 15.0 and crowd != null and crowd.multimesh.instance_count >= 800 and screen_ok,
		"#H3 the main grandstand: %.0f m long, %d tiers, cantilever roof to %.1f m (lowest %.1f m over the corridor), %d spectators, Jumbotron %s" % [
			stand_box["s_max"] - stand_box["s_min"], tiers.size(), stand_box["y_max"], stand_box["low_in_corridor"], crowd.multimesh.instance_count if crowd != null else 0, screen_ok])

	var tower: Node3D = paddock.get_node_or_null("RaceControlTower") if paddock != null else null
	var tower_box: Dictionary = footprint(world_vertices(tower), 195.0)
	check(tower != null and int(prop(tower, "floor_count")) == 4 and tower_box["y_max"] >= 16.0 and tower_box["s_min"] >= 120.0 and tower_box["s_max"] <= 290.0
		and tower_box["lat_min"] >= 15.0 and tower_box["low_in_corridor"] >= CORRIDOR_CLEARANCE_M,
		"#H4 the four-floor race control tower stands beyond Pit Exit (s %.0f..%.0f, lateral %.1f..%.1f, %.1f m tall) clear of the car corridor" % [
			tower_box["s_min"], tower_box["s_max"], tower_box["lat_min"], tower_box["lat_max"], tower_box["y_max"]])

	var gantry = world.gantry
	var gantry_box: AABB = AABB()
	var structure: MeshInstance3D = prop(gantry, "structure")
	var meshes: int = gantry.find_children("*", "MeshInstance3D", true, false).size()
	if structure != null:
		gantry_box = structure.mesh.get_aabb()
	var gantry_low_ok: bool = structure != null
	for vertex: Vector3 in world_vertices(gantry, 1):
		var frame: Vector2 = ribbon_frame(vertex)
		gantry_low_ok = gantry_low_ok and not (vertex.y < 5.0 and frame.y > 7.6 and frame.y < 16.8)
	check(structure != null and gantry_box.size.x >= 25.0 and gantry_box.size.z >= 1.6 and gantry_box.end.x >= 18.0 and gantry_box.position.x >= -8.7
		and gantry.lamps.size() == 10 and meshes <= 16 and gantry_low_ok,
		"#H5 the start gantry is a double truss %.1f m wide across the track and the pit lane (%.1f m deep), merged to %d meshes, lamps intact" % [gantry_box.size.x, gantry_box.size.z, meshes])
	gantry.set_lights(5)
	var all_lit: bool = gantry.lit_lamp_count() == 10
	gantry.set_lights(2)
	var some_lit: bool = gantry.lit_lamp_count() == 4
	gantry.set_lights(0)
	check(all_lit and some_lit and gantry.lit_lamp_count() == 0, "#H6 the five FIA red-light pairs still light pair by pair after the gantry upgrade")

	var leader = world.race.standings()[0]
	world.step(0.6)
	var colors: Array = prop(screen, "last_row_colors") if screen != null else []
	var expected: Color = LiveriesScript.color_for(leader.team_id)
	check(colors.size() == 10 and (colors[0] as Color).is_equal_approx(expected) and not expected.is_equal_approx(Color.BLACK),
		"#H7 the Jumbotron leaderboard follows the live standings (row 1 = the leader's team colour)")


# --- stage 4: horizon vista, foliage, time-of-day lighting ---------------------------------------

const VISTA_SCENE_PATH := "res://scenes/race_world/mountain_vista.tscn"
const RaceConfigScript := preload("res://scripts/core/race_config_data.gd")
const FOLIAGE_KINDS: Array[String] = ["cedar", "oak", "pine"]


func ribbon_centre() -> Vector2:
	var low := Vector2(INF, INF)
	var high := Vector2(-INF, -INF)
	var s: float = 0.0
	while s < world.ribbon.length_m:
		var point: Vector3 = world.ribbon.get_point_at_offset(s, 0.0).origin
		low = Vector2(minf(low.x, point.x), minf(low.y, point.z))
		high = Vector2(maxf(high.x, point.x), maxf(high.y, point.z))
		s += 6.0
	return (low + high) * 0.5


func _test_stage4_vista_and_foliage() -> void:
	var environment = world.environment
	var vista: Node3D = prop(environment, "vista")
	var ridge: MeshInstance3D = prop(vista, "ridge_instance")
	var centre: Vector2 = ribbon_centre()
	var near_radius: float = INF
	var far_radius: float = 0.0
	var peak: float = 0.0
	var base: float = INF
	for vertex: Vector3 in vertices_of(ridge):
		peak = maxf(peak, vertex.y)
		base = minf(base, vertex.y)
		if vertex.y > 40.0:
			var radius: float = Vector2(vertex.x, vertex.z).distance_to(centre)
			near_radius = minf(near_radius, radius)
			far_radius = maxf(far_radius, radius)
	var haze := ridge.mesh.surface_get_material(0) as ShaderMaterial if ridge != null and ridge.mesh != null else null
	var haze_uniforms: Array[String] = []
	if haze != null and haze.shader != null:
		for entry: Dictionary in haze.shader.get_shader_uniform_list():
			haze_uniforms.append(String(entry["name"]))
	check(vista != null and vista.scene_file_path == VISTA_SCENE_PATH and near_radius >= 1000.0 and far_radius >= 1450.0 and far_radius <= 1560.0
		and peak >= 250.0 and peak <= 700.0 and base <= 0.0 and haze_uniforms.has("haze_color") and haze_uniforms.has("haze_strength"),
		"#V1 the low-poly mountain ring stands %.0f..%.0f m from the circuit centre, peaks %.0f m, base buried (%.1f m), with an atmospheric haze shader" % [near_radius, far_radius, peak, base])

	var stars: MultiMeshInstance3D = prop(vista, "star_instance")
	var star_material := prop(vista, "star_material") as StandardMaterial3D
	check(stars != null and stars.multimesh.instance_count >= 600 and star_material != null and is_zero_approx(star_material.albedo_color.a),
		"#V2 a star field of %d points is part of the vista and invisible by day" % [stars.multimesh.instance_count if stars != null else 0])

	var foliage: Node3D = prop(environment, "foliage")
	var kinds: Dictionary = prop(foliage, "kind_instances") if foliage != null else {}
	var positions: PackedVector3Array = prop(foliage, "tree_positions") if foliage != null else PackedVector3Array()
	var heights: Dictionary = {}
	var weights_ok: bool = not kinds.is_empty()
	var shared_material: Material = null
	var kinds_ok: bool = kinds.size() == 3
	for kind: String in FOLIAGE_KINDS:
		var instance := kinds.get(kind) as MultiMeshInstance3D
		kinds_ok = kinds_ok and instance != null and instance.multimesh.instance_count > 80
		if instance == null:
			continue
		heights[kind] = instance.multimesh.mesh.get_aabb().size.y
		var colors: PackedColorArray = instance.multimesh.mesh.surface_get_arrays(0)[Mesh.ARRAY_COLOR]
		var low_weight: float = 1.0
		var high_weight: float = 0.0
		for color: Color in colors:
			low_weight = minf(low_weight, color.a)
			high_weight = maxf(high_weight, color.a)
		weights_ok = weights_ok and low_weight <= 0.01 and high_weight >= 0.99
		var material: Material = instance.multimesh.mesh.surface_get_material(0)
		shared_material = shared_material if shared_material != null else material
		kinds_ok = kinds_ok and material == shared_material
	var wind_uniform: bool = false
	if shared_material is ShaderMaterial and (shared_material as ShaderMaterial).shader != null:
		for entry: Dictionary in (shared_material as ShaderMaterial).shader.get_shader_uniform_list():
			wind_uniform = wind_uniform or String(entry["name"]) == "wind_amplitude"
	check(kinds_ok and weights_ok and wind_uniform and positions.size() > 500 and positions.size() <= 1600 and heights.get("cedar", 0.0) > heights.get("pine", 0.0) and heights.get("pine", 0.0) > heights.get("oak", 0.0),
		"#T1 %d anime trees in three kinds (cedar %.1f m > pine %.1f m > oak %.1f m) share one wind-sway material with per-vertex sway weights" % [
			positions.size(), heights.get("cedar", 0.0), heights.get("pine", 0.0), heights.get("oak", 0.0)])

	var half: float = world.ribbon.road_half_width_m
	var spacing: float = INF
	var nearest_road: float = INF
	var keep_out_hits: int = 0
	for index: int in range(positions.size()):
		nearest_road = minf(nearest_road, centre_distance(positions[index]))
		for other: int in range(index + 1, positions.size()):
			spacing = minf(spacing, Vector2(positions[index].x - positions[other].x, positions[index].z - positions[other].z).length())
		var frame: Vector2 = ribbon_frame(positions[index], 4)
		var in_stand: bool = frame.y < 0.0 and frame.y > -110.0 and frame.x > 0.0 and frame.x < 250.0
		var in_pit: bool = frame.y > 0.0 and frame.y < 60.0 and (frame.x > 3880.0 or frame.x < 250.0)
		keep_out_hits += 1 if (in_stand or in_pit) else 0
	check(positions.size() > 500 and nearest_road >= half + 18.0 and spacing >= 6.0 and keep_out_hits == 0,
		"#T2 trees are Poisson-disc spaced (closest pair %.1f m), >= 18 m off the asphalt edge (%.1f m from a centreline) and keep clear of the pit complex, grandstand and tower (%d inside)" % [spacing, nearest_road, keep_out_hits])


func _world_for(time_of_day: int, weather_preset: int = 0) -> Node3D:
	var config := RaceConfigScript.new()
	config.time_of_day = time_of_day
	config.weather_preset = weather_preset
	config.race_seed = 777
	RaceConfigScript.current = config
	var instance: Node3D = WorldScene.instantiate()
	root.add_child(instance)
	instance.set_physics_process(false)
	return instance


func _lighting_snapshot(instance: Node3D) -> Dictionary:
	var lighting = prop(instance.environment, "lighting")
	var sun := instance.get_node("Sun") as DirectionalLight3D
	var env: Environment = (instance.get_node("WorldEnvironment") as WorldEnvironment).environment
	var spots: Array = prop(lighting, "active_lights") if lighting != null else []
	var lit: int = 0
	var shadowed: int = 0
	for light: Light3D in spots:
		lit += 1 if light.light_energy > 0.1 and light.visible else 0
		shadowed += 1 if light.shadow_enabled else 0
	var glow_value: Variant = ToonMaterialsScript.vertex_colored(true).get_shader_parameter("glow_energy")
	var vista = prop(instance.environment, "vista")
	var star_material := prop(vista, "star_material") as StandardMaterial3D
	return {
		"has_lighting": lighting != null,
		"floodlights": float(prop(lighting, "floodlight_level")) if lighting != null else -1.0,
		"glow": float(glow_value) if glow_value != null else -1.0,
		"glass": ToonMaterialsScript.glass().emission_energy_multiplier,
		"sun_pitch": sun.rotation_degrees.x,
		"sun_color": sun.light_color,
		"sun_energy": sun.light_energy,
		"lit": lit,
		"shadowed": shadowed,
		"stars": star_material.albedo_color.a if star_material != null else -1.0,
		"fog": env.fog_enabled,
		"fog_color": env.fog_light_color,
	}


func _test_stage4_lighting() -> void:
	var results: Dictionary = {}
	for mode: Array in [["day", 0], ["sunset", 1], ["night", 2]]:
		var instance: Node3D = _world_for(int(mode[1]))
		await process_frame
		instance.step(1.0 / 60.0)
		instance.step(1.0 / 60.0)
		results[mode[0]] = _lighting_snapshot(instance)
		instance.race.dispose()
		instance.queue_free()
		for _frame: int in range(3):
			await process_frame
	RaceConfigScript.current = null
	var day: Dictionary = results["day"]
	var sunset: Dictionary = results["sunset"]
	var night: Dictionary = results["night"]
	check(day["has_lighting"] and is_zero_approx(day["floodlights"]) and is_zero_approx(day["glow"]) and is_zero_approx(day["glass"]) and day["lit"] == 0 and is_zero_approx(day["stars"])
		and day["sun_energy"] >= 1.0 and day["fog"],
		"#L1 Day: harsh sun (energy %.2f, pitch %.0f deg), floodlights and windows off, no stars, light haze" % [day["sun_energy"], day["sun_pitch"]])
	var sun_color: Color = sunset["sun_color"]
	check(sunset["sun_pitch"] > day["sun_pitch"] + 8.0 and sun_color.r > sun_color.b + 0.25 and sunset["floodlights"] >= 0.0 and sunset["floodlights"] <= 1.0
		and (sunset["fog_color"] as Color).r > (day["fog_color"] as Color).r - 0.2 and sunset["fog"],
		"#L2 Sunset: sun drops to %.0f deg (day %.0f) with golden light (%s), floodlights easing in (%.2f)" % [sunset["sun_pitch"], day["sun_pitch"], sun_color, sunset["floodlights"]])
	check(night["floodlights"] >= 0.99 and night["glow"] >= 3.0 and night["glass"] > 0.5 and night["lit"] >= 4 and night["shadowed"] == 0 and night["stars"] >= 0.8,
		"#L3 Night: 28 floodlight towers lit (glow %.1f, %d real spot lights, none casting shadows), windows warm (%.2f), stars %.2f" % [night["glow"], night["lit"], night["glass"], night["stars"]])


# --- stage 5: performance budget (static estimate; the native FPS numbers are in the phase report) ---

const DRAW_CALL_BUDGET: int = 180
const TRIANGLE_BUDGET: int = 350000


func _material_passes(material: Material) -> int:
	var count: int = 0
	var current: Material = material
	while current != null:
		count += 1
		current = current.next_pass
	return maxi(1, count)


func _surface_triangles(mesh: Mesh, surface: int) -> int:
	var arrays: Array = mesh.surface_get_arrays(surface)
	if arrays.is_empty():
		return 0
	var indices: Variant = arrays[Mesh.ARRAY_INDEX]
	if indices != null and (indices as PackedInt32Array).size() > 0:
		return (indices as PackedInt32Array).size() / 3
	return (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() / 3


## Main-pass draw calls (one per surface per material pass, one per label) and triangles of a subtree.
func estimate_budget(node: Node) -> Vector2i:
	var calls: int = 0
	var triangles: int = 0
	var stack: Array[Node] = [node]
	while not stack.is_empty():
		var current: Node = stack.pop_back()
		stack.append_array(current.get_children())
		if current is MeshInstance3D and (current as MeshInstance3D).mesh != null:
			var instance := current as MeshInstance3D
			for surface: int in range(instance.mesh.get_surface_count()):
				calls += _material_passes(instance.material_override if instance.material_override != null else instance.mesh.surface_get_material(surface))
				triangles += _surface_triangles(instance.mesh, surface)
		elif current is MultiMeshInstance3D and (current as MultiMeshInstance3D).multimesh != null:
			var multi := current as MultiMeshInstance3D
			for surface: int in range(multi.multimesh.mesh.get_surface_count()):
				calls += _material_passes(multi.material_override if multi.material_override != null else multi.multimesh.mesh.surface_get_material(surface))
				triangles += _surface_triangles(multi.multimesh.mesh, surface) * multi.multimesh.instance_count
		elif current is Label3D:
			calls += 1
			triangles += 2
	return Vector2i(calls, triangles)


func _test_stage5_budget() -> void:
	var total := Vector2i.ZERO
	for node: Node in [world.ribbon, world.environment, world.pit_lane, world.gantry]:
		var part: Vector2i = estimate_budget(node)
		total += part
	check(total.x < DRAW_CALL_BUDGET, "#P1 the full track scene (road, environment, pit lane, gantry) costs about %d main-pass draw calls (budget < %d)" % [total.x, DRAW_CALL_BUDGET])
	check(total.y < TRIANGLE_BUDGET, "#P2 the track environment is %d triangles (budget < %d)" % [total.y, TRIANGLE_BUDGET])
	# Repetitive furniture and trees are MultiMeshes, never one node per object.
	var singles: int = 0
	var multimeshes: int = 0
	for group: String in ["furniture", "foliage"]:
		var node: Node = prop(world.environment, group)
		singles += node.find_children("*", "MeshInstance3D", true, false).size() if node != null else 99
		multimeshes += node.find_children("*", "MultiMeshInstance3D", true, false).size() if node != null else 0
	check(singles == 0 and multimeshes == 8, "#P3 guardrail, Tecpro, braking boards, floodlights, flag panels and trees are %d MultiMeshInstance3D and %d single meshes" % [multimeshes, singles])

# --- feedback round: barriers, lane lines, pit lane ---------------------------------------------

## Distance to the nearest centreline sample on a different stretch of road than the one at arc `own_s`.
func other_road_distance(point: Vector3, own_s: float) -> float:
	var cx: int = floori(point.x / HASH_CELL_M)
	var cz: int = floori(point.z / HASH_CELL_M)
	var best: float = INF
	for dx: int in range(-2, 3):
		for dz: int in range(-2, 3):
			var key := Vector2i(cx + dx, cz + dz)
			if not _centre_hash.has(key):
				continue
			for sample: Vector3 in _centre_hash[key]:
				var arc: float = absf(fposmod(sample.y - own_s + world.ribbon.length_m * 0.5, world.ribbon.length_m) - world.ribbon.length_m * 0.5)
				if arc > 80.0:
					best = minf(best, Vector2(sample.x - point.x, sample.z - point.z).length())
	return best


func arcs_of(owner: Object, property: String) -> PackedFloat32Array:
	var value: Variant = prop(owner, property)
	return value if value is PackedFloat32Array else PackedFloat32Array()


func _test_feedback_barriers() -> void:
	var furniture: Node3D = prop(world.environment, "furniture")
	# Each barrier group hands over its poses and the arc distance each was generated at.
	var groups: Dictionary = {
		"armco": [poses_of(furniture, "armco_transforms"), arcs_of(furniture, "armco_arcs")],
		"tecpro": [poses_of(furniture, "tecpro_transforms"), arcs_of(furniture, "tecpro_arcs")],
		"catch fence": [poses_of(world.environment, "catch_fence_transforms"), arcs_of(world.environment, "catch_fence_arcs")],
		"fence posts": [poses_of(world.environment, "fence_post_transforms"), arcs_of(world.environment, "fence_post_arcs")],
	}
	var beyond: Array[String] = []
	var in_pit: Array[String] = []
	var empty: Array[String] = []
	var checked: int = 0
	for group: String in groups:
		var poses: Array = groups[group][0]
		var arcs: PackedFloat32Array = groups[group][1]
		if poses.is_empty() or arcs.size() != poses.size():
			empty.append(group)
			continue
		var worst: float = 0.0
		var worst_arc: float = 0.0
		var pit_hits: int = 0
		for index: int in range(poses.size()):
			var pose: Transform3D = poses[index]
			checked += 1
			# A barrier belongs to its own road: it may reach the middle of the gap to another stretch, never past it.
			var own: float = Vector2(pose.origin.x, pose.origin.z).distance_to(Vector2(world.ribbon.get_point_at_offset(arcs[index], 0.0).origin.x, world.ribbon.get_point_at_offset(arcs[index], 0.0).origin.z))
			var excess: float = own - other_road_distance(pose.origin, arcs[index])
			if excess > worst:
				worst = excess
				worst_arc = arcs[index]
			var u: float = fposmod(arcs[index] - PitLaneScript.ENTRY_S, world.ribbon.length_m)
			var lateral: float = (pose.origin - world.ribbon.get_point_at_offset(arcs[index], 0.0).origin).dot(world.ribbon.get_point_at_offset(arcs[index], 0.0).basis.x)
			if lateral > 7.5 and lateral < 21.0 and u <= PitLaneScript.NOMINAL_LENGTH_M:
				pit_hits += 1
		if worst > 0.3:
			beyond.append("%s +%.1f m at s=%.0f" % [group, worst, worst_arc])
		if pit_hits > 0:
			in_pit.append("%s x%d" % [group, pit_hits])
	check(checked > 2000 and empty.is_empty() and beyond.is_empty(),
		"#B1 no barrier line crosses the middle of the gap to another stretch of road (%d posts checked; past the middle: %s; missing: %s)" % [checked, str(beyond), str(empty)])
	check(in_pit.is_empty(), "#B2 no barrier stands inside the pit lane between Pit Entry and Pit Exit (%s)" % [str(in_pit)])

	# A GT circuit has no lane lines on the racing surface: only the edge lines and the start/finish line.
	var colors: PackedColorArray = (world.ribbon.get_node("RoadMesh") as MeshInstance3D).mesh.surface_get_arrays(0)[Mesh.ARRAY_COLOR]
	var lane_vertices: int = 0
	var edge_vertices: int = 0
	for color: Color in colors:
		lane_vertices += 1 if color.is_equal_approx(Color("#5A5E6B")) else 0
		edge_vertices += 1 if color.is_equal_approx(Color("#F4F5F7")) else 0
	check(lane_vertices == 0 and edge_vertices > 0,
		"#S10 the road shows only its edge lines and the start line, no painted lane lines (%d lane-line vertices, %d white-line vertices)" % [lane_vertices, edge_vertices])