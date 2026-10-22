class_name GraffitiTag
extends Control

## Brutalist graffiti slab drawn from code, used as the floating tip over a car (name tag)
## and its status sticker. A crooked paint slab in the team colour on a hard ink offset
## shadow, a heavy ink border, spray speckle, paint drips, a halftone band, a hazard tape
## strip and a pointer toward the car, with the text overprinted in Anton. rebuild() lays the
## shapes out from a seed (so every car has its own hand) and _draw() paints them; render it
## once into a SubViewport and use the texture on a billboard.

enum Kind { NAME, STATUS }

const UI = preload("res://scripts/ui/pit_wall_ui.gd")
const INK := Color("#050505")
const TAPE := Color("#FFE600")
const SIZE_NAME := Vector2(256.0, 128.0)
const SIZE_STATUS := Vector2(192.0, 64.0)
const SHADOW := Vector2(7.0, 7.0)

var kind: int = Kind.NAME
var text: String = ""
var paint: Color = Color.WHITE
var slab: PackedVector2Array = PackedVector2Array()
var drips: Array[Rect2] = []
var specks: Array[Vector3] = []
var halftone: Array[Vector2] = []


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## Lays the slab, drips, speckle and halftone out for `p_text` in `p_paint`; the same seed gives the same tag.
func rebuild(p_text: String, p_paint: Color, p_seed: int, p_kind: int = Kind.NAME) -> void:
	kind = p_kind
	text = p_text
	paint = p_paint
	size = SIZE_NAME if kind == Kind.NAME else SIZE_STATUS
	custom_minimum_size = size
	var rng := RandomNumberGenerator.new()
	rng.seed = p_seed
	drips.clear()
	specks.clear()
	halftone.clear()
	if kind == Kind.NAME:
		slab = PackedVector2Array([
			Vector2(26.0 + rng.randf_range(-6.0, 6.0), 20.0 + rng.randf_range(-5.0, 5.0)),
			Vector2(238.0 + rng.randf_range(-6.0, 6.0), 8.0 + rng.randf_range(-5.0, 5.0)),
			Vector2(230.0 + rng.randf_range(-6.0, 6.0), 88.0 + rng.randf_range(-5.0, 5.0)),
			Vector2(14.0 + rng.randf_range(-6.0, 6.0), 98.0 + rng.randf_range(-5.0, 5.0)),
		])
		for _drip: int in range(rng.randi_range(3, 4)):
			var x: float = rng.randf_range(34.0, 100.0) if rng.randf() < 0.5 else rng.randf_range(156.0, 214.0)
			var edge_y: float = lerpf(slab[3].y, slab[2].y, (x - slab[3].x) / (slab[2].x - slab[3].x))
			var width: float = rng.randf_range(5.0, 8.0)
			drips.append(Rect2(x, edge_y - 2.0, width, rng.randf_range(10.0, 26.0)))
	else:
		slab = PackedVector2Array([
			Vector2(10.0 + rng.randf_range(-3.0, 3.0), 10.0 + rng.randf_range(-3.0, 3.0)),
			Vector2(182.0 + rng.randf_range(-3.0, 3.0), 6.0 + rng.randf_range(-3.0, 3.0)),
			Vector2(178.0 + rng.randf_range(-3.0, 3.0), 50.0 + rng.randf_range(-3.0, 3.0)),
			Vector2(8.0 + rng.randf_range(-3.0, 3.0), 54.0 + rng.randf_range(-3.0, 3.0)),
		])
	var bounds := Rect2(slab[0], Vector2.ZERO)
	for point: Vector2 in slab:
		bounds = bounds.expand(point)
	for _speck: int in range(28 if kind == Kind.NAME else 10):
		var at := Vector2(rng.randf_range(bounds.position.x - 12.0, bounds.end.x + 12.0), rng.randf_range(bounds.position.y - 10.0, bounds.end.y + 10.0))
		if not Geometry2D.is_point_in_polygon(at, slab):
			specks.append(Vector3(at.x, at.y, rng.randf_range(1.0, 3.0)))
	var step: float = 9.0
	var y: float = bounds.position.y + bounds.size.y * 0.62
	while y < bounds.end.y:
		var x: float = bounds.position.x
		while x < bounds.end.x:
			if Geometry2D.is_point_in_polygon(Vector2(x, y), slab):
				halftone.append(Vector2(x, y))
			x += step
		y += step
	queue_redraw()


func _draw() -> void:
	if slab.is_empty():
		return
	var shadow := PackedVector2Array()
	for point: Vector2 in slab:
		shadow.append(point + SHADOW)
	draw_colored_polygon(shadow, INK)
	for speck: Vector3 in specks:
		draw_rect(Rect2(speck.x, speck.y, speck.z * 2.0, speck.z * 2.0), Color(paint, 0.75))
	for drip: Rect2 in drips:
		draw_rect(drip, paint)
		draw_circle(Vector2(drip.position.x + drip.size.x * 0.5, drip.end.y), drip.size.x * 0.5, paint)
		draw_rect(Rect2(drip.position.x - 1.5, drip.position.y, 1.5, drip.size.y), INK)
	draw_colored_polygon(slab, paint)
	for dot: Vector2 in halftone:
		draw_circle(dot, 2.2, Color(INK, 0.28))
	var outline := slab.duplicate()
	outline.append(slab[0])
	draw_polyline(outline, INK, 5.0 if kind == Kind.NAME else 4.0)
	_draw_text()
	if kind == Kind.NAME:
		_draw_tape()
		_draw_pointer()


func _draw_text() -> void:
	var font: Font = UI.DISPLAY
	var font_size: int = 76 if kind == Kind.NAME else 40
	var bounds := Rect2(slab[0], Vector2.ZERO)
	for point: Vector2 in slab:
		bounds = bounds.expand(point)
	var extent: Vector2 = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	var center: Vector2 = bounds.get_center()
	var light_text: bool = paint.get_luminance() < 0.38
	var face: Color = Color.WHITE if light_text else INK
	var under: Color = INK if light_text else Color.WHITE
	draw_set_transform(center, -0.05 if kind == Kind.NAME else 0.0, Vector2.ONE)
	var at := Vector2(-extent.x * 0.5, font.get_ascent(font_size) * 0.5 - font.get_descent(font_size) * 0.5)
	draw_string(font, at + Vector2(4.0, 4.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, under)
	draw_string(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, face)
	draw_set_transform_matrix(Transform2D.IDENTITY)


## Hazard tape wrapped round the top-left corner.
func _draw_tape() -> void:
	draw_set_transform(slab[0] + Vector2(2.0, 4.0), -0.62, Vector2.ONE)
	draw_rect(Rect2(-6.0, -8.0, 62.0, 16.0), TAPE)
	for stripe: int in range(4):
		var x: float = float(stripe) * 16.0
		draw_colored_polygon(PackedVector2Array([Vector2(x, -8.0), Vector2(x + 8.0, -8.0), Vector2(x + 2.0, 8.0), Vector2(x - 6.0, 8.0)]), INK)
	draw_rect(Rect2(-6.0, -8.0, 62.0, 16.0), INK, false, 2.0)
	draw_set_transform_matrix(Transform2D.IDENTITY)


## Down-pointing stencil arrow under the slab: the tip points at the car.
func _draw_pointer() -> void:
	var x: float = size.x * 0.5
	var top: float = (slab[2].y + slab[3].y) * 0.5
	var arrow := PackedVector2Array([Vector2(x - 18.0, top - 2.0), Vector2(x + 18.0, top - 2.0), Vector2(x, size.y - 3.0)])
	var cast := PackedVector2Array()
	for point: Vector2 in arrow:
		cast.append(point + Vector2(4.0, 3.0))
	draw_colored_polygon(cast, Color(INK, 0.55))
	draw_colored_polygon(arrow, INK)
	var core := PackedVector2Array([Vector2(x - 8.0, top + 2.0), Vector2(x + 8.0, top + 2.0), Vector2(x, size.y - 14.0)])
	draw_colored_polygon(core, paint)
