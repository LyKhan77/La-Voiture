class_name MeshBatch
extends RefCounted

## Merges boxes, extrusions, cylinders and quads into one ArrayMesh with one surface per
## material (FASE 10), so a whole building, tower or barrier module costs a draw call per
## material instead of one per part. Faces are flat-shaded and wind clockwise seen from
## outside (Godot's front face); each primitive is told which way is "out" and the winding
## is corrected to match. Colours are stored linear so the vertex-colour cel shader can use
## COLOR as is; alpha rides along (glow mask / sway weight).

var _tools: Dictionary = {} # Material -> SurfaceTool
var _order: Array[Material] = []


## Box of `size` centred on xform.origin.
func box(material: Material, color: Color, xform: Transform3D, size: Vector3) -> void:
	var half: Vector3 = size * 0.5
	for axis: int in range(3):
		for direction: float in [-1.0, 1.0]:
			var normal := Vector3.ZERO
			normal[axis] = direction
			var u := Vector3.ZERO
			u[(axis + 1) % 3] = half[(axis + 1) % 3]
			var v := Vector3.ZERO
			v[(axis + 2) % 3] = half[(axis + 2) % 3]
			var centre: Vector3 = normal * half[axis]
			quad(material, color, xform * (centre - u - v), xform * (centre + u - v), xform * (centre + u + v), xform * (centre - u + v), xform.basis * normal)


## Closed polygon `profile` (x, y) extruded along local Z, centred on xform.origin: walls, and
## both end caps when `capped` (needs a simple polygon; triangulated by Geometry2D).
func extrude(material: Material, color: Color, xform: Transform3D, profile: PackedVector2Array, length: float, capped: bool = false) -> void:
	var area: float = 0.0
	for index: int in range(profile.size()):
		area += profile[index].cross(profile[(index + 1) % profile.size()])
	var counter_clockwise: bool = area > 0.0
	var z0: float = -length * 0.5
	var z1: float = length * 0.5
	for index: int in range(profile.size()):
		var p0: Vector2 = profile[index]
		var p1: Vector2 = profile[(index + 1) % profile.size()]
		var edge: Vector2 = p1 - p0
		var out2: Vector2 = Vector2(edge.y, -edge.x) if counter_clockwise else Vector2(-edge.y, edge.x)
		quad(material, color, xform * Vector3(p0.x, p0.y, z0), xform * Vector3(p1.x, p1.y, z0),
			xform * Vector3(p1.x, p1.y, z1), xform * Vector3(p0.x, p0.y, z1), xform.basis * Vector3(out2.x, out2.y, 0.0))
	if not capped:
		return
	var corners: PackedInt32Array = Geometry2D.triangulate_polygon(profile)
	for index: int in range(0, corners.size(), 3):
		for end: float in [-1.0, 1.0]:
			var z: float = length * 0.5 * end
			var a: Vector2 = profile[corners[index]]
			var b: Vector2 = profile[corners[index + 1]]
			var c: Vector2 = profile[corners[index + 2]]
			triangle(material, color, xform * Vector3(a.x, a.y, z), xform * Vector3(b.x, b.y, z), xform * Vector3(c.x, c.y, z), xform.basis * Vector3(0.0, 0.0, end))


## Upright (local Y) cylinder or cone, base at the origin; `radius_top` 0 makes a cone. `capped` adds
## the top cap and, unless `bottom_cap` is false (a base that sits on the ground), the bottom one.
func cylinder(material: Material, color: Color, xform: Transform3D, radius_bottom: float, radius_top: float, height: float, segments: int = 8, capped: bool = true, bottom_cap: bool = true) -> void:
	for index: int in range(segments):
		var a0: float = TAU * float(index) / float(segments)
		var a1: float = TAU * float(index + 1) / float(segments)
		var b0 := Vector3(cos(a0) * radius_bottom, 0.0, sin(a0) * radius_bottom)
		var b1 := Vector3(cos(a1) * radius_bottom, 0.0, sin(a1) * radius_bottom)
		var t0 := Vector3(cos(a0) * radius_top, height, sin(a0) * radius_top)
		var t1 := Vector3(cos(a1) * radius_top, height, sin(a1) * radius_top)
		var outward: Vector3 = xform.basis * Vector3(cos((a0 + a1) * 0.5), 0.0, sin((a0 + a1) * 0.5))
		if radius_top <= 0.0:
			triangle(material, color, xform * b0, xform * b1, xform * t0, outward)
		else:
			quad(material, color, xform * b0, xform * b1, xform * t1, xform * t0, outward)
			if capped:
				triangle(material, color, xform * Vector3(0.0, height, 0.0), xform * t0, xform * t1, xform.basis * Vector3.UP)
		if capped and bottom_cap:
			triangle(material, color, xform * Vector3.ZERO, xform * b0, xform * b1, xform.basis * Vector3.DOWN)


## Box between two points; `thickness` is its square section.
func strut(material: Material, color: Color, from: Vector3, to: Vector3, thickness: float) -> void:
	var direction: Vector3 = to - from
	if direction.length_squared() < 1.0e-8:
		return
	var up: Vector3 = Vector3.RIGHT if absf(direction.normalized().y) > 0.98 else Vector3.UP
	box(material, color, Transform3D(Basis.looking_at(direction, up), (from + to) * 0.5), Vector3(thickness, thickness, direction.length()))


## Planar truss from `from` to `to`: two chords `depth` apart along `up`, a vertical at every bay
## and a diagonal in every bay, alternating, so it reads as a lattice from the side.
func truss(material: Material, color: Color, from: Vector3, to: Vector3, up: Vector3, depth: float, bays: int, thickness: float) -> void:
	var half: Vector3 = up.normalized() * depth * 0.5
	strut(material, color, from + half, to + half, thickness)
	strut(material, color, from - half, to - half, thickness)
	var web: float = thickness * 0.7
	for bay: int in range(bays):
		var a: Vector3 = from.lerp(to, float(bay) / float(bays))
		var b: Vector3 = from.lerp(to, float(bay + 1) / float(bays))
		strut(material, color, a - half, a + half, web)
		if bay % 2 == 0:
			strut(material, color, a - half, b + half, web)
		else:
			strut(material, color, a + half, b - half, web)
	strut(material, color, to - half, to + half, web)


## Flat quad; `a`..`d` go around the face in either direction, `outward` picks the visible side.
func quad(material: Material, color: Color, a: Vector3, b: Vector3, c: Vector3, d: Vector3, outward: Vector3) -> void:
	if (c - a).cross(b - a).dot(outward) < 0.0:
		var swap: Vector3 = b
		b = d
		d = swap
	var normal: Vector3 = (c - a).cross(b - a)
	if normal.length_squared() < 1.0e-12:
		normal = (d - a).cross(c - a)
		if normal.length_squared() < 1.0e-12:
			return
	var st: SurfaceTool = _tool(material)
	var linear: Color = color.srgb_to_linear()
	normal = normal.normalized()
	for vertex: Vector3 in [a, b, c, a, c, d]:
		st.set_color(linear)
		st.set_normal(normal)
		st.add_vertex(vertex)


func triangle(material: Material, color: Color, a: Vector3, b: Vector3, c: Vector3, outward: Vector3) -> void:
	if (c - a).cross(b - a).dot(outward) < 0.0:
		var swap: Vector3 = b
		b = c
		c = swap
	var normal: Vector3 = (c - a).cross(b - a)
	if normal.length_squared() < 1.0e-12:
		return
	var st: SurfaceTool = _tool(material)
	var linear: Color = color.srgb_to_linear()
	normal = normal.normalized()
	for vertex: Vector3 in [a, b, c]:
		st.set_color(linear)
		st.set_normal(normal)
		st.add_vertex(vertex)


func commit() -> ArrayMesh:
	var mesh := ArrayMesh.new()
	for material: Material in _order:
		(_tools[material] as SurfaceTool).commit(mesh)
		mesh.surface_set_material(mesh.get_surface_count() - 1, material)
	return mesh


func _tool(material: Material) -> SurfaceTool:
	if not _tools.has(material):
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		_tools[material] = st
		_order.append(material)
	return _tools[material]
