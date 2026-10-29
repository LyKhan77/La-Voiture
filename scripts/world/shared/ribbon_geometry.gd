class_name RibbonGeometry
extends RefCounted

## Mesh helpers that follow a TrackRibbon for the trackside set (FASE 5.5): flat
## painted bands and runs of boxes. Positions come from ribbon.get_point_at_offset,
## so every builder node is expected to sit under an identity transform.

const TrackRibbonScript := preload("res://scripts/car/track_ribbon.gd")


## Flat band between two lateral offsets over arc distance s0..s1. `lat_a` and
## `lat_b` are Callables s -> meters (a is the left edge, lower lateral). Wound so
## the top faces front in Godot (clockwise seen from above).
static func strip_mesh(
	ribbon: TrackRibbonScript, s0: float, s1: float, lat_a: Callable, lat_b: Callable, dy: float, step_m: float = 2.0
) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_normal(Vector3.UP)
	var count: int = maxi(1, ceili((s1 - s0) / step_m))
	for n: int in range(count):
		var sa: float = lerpf(s0, s1, float(n) / float(count))
		var sb: float = lerpf(s0, s1, float(n + 1) / float(count))
		var left_a: Vector3 = _at(ribbon, sa, lat_a.call(sa), dy)
		var right_a: Vector3 = _at(ribbon, sa, lat_b.call(sa), dy)
		var left_b: Vector3 = _at(ribbon, sb, lat_a.call(sb), dy)
		var right_b: Vector3 = _at(ribbon, sb, lat_b.call(sb), dy)
		for v: Vector3 in [left_a, left_b, right_b, left_a, right_b, right_a]:
			st.add_vertex(v)
	return st.commit()


## One MultiMeshInstance3D of boxes laid end to end along the ribbon. `lateral` is
## a Callable s -> meters; size is (across, height, along) of each box.
static func box_run(
	ribbon: TrackRibbonScript, parent: Node3D, node_name: String, s0: float, s1: float, step_m: float,
	lateral: Callable, size: Vector3, y: float, material: Material
) -> MultiMeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = Vector3.ONE
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = mesh
	var count: int = maxi(1, ceili((s1 - s0) / step_m))
	multimesh.instance_count = count
	for n: int in range(count):
		var s: float = s0 + (float(n) + 0.5) * (s1 - s0) / float(count)
		multimesh.set_instance_transform(n, box_transform(ribbon, s, lateral.call(s), size, y))
	var instance := MultiMeshInstance3D.new()
	instance.name = node_name
	instance.multimesh = multimesh
	instance.material_override = material
	parent.add_child(instance)
	return instance


## Transform of a box of `size` standing on the ground at arc distance s and lateral offset.
static func box_transform(ribbon: TrackRibbonScript, s: float, lateral_m: float, size: Vector3, y: float) -> Transform3D:
	var pose: Transform3D = ribbon.get_point_at_offset(s, lateral_m)
	pose.origin += Vector3.UP * (y + size.y * 0.5)
	pose.basis = pose.basis.scaled_local(size)
	return pose


static func _at(ribbon: TrackRibbonScript, s: float, lateral_m: float, dy: float) -> Vector3:
	return ribbon.get_point_at_offset(s, lateral_m).origin + Vector3.UP * dy
