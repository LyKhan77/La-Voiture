extends RefCounted

## Toon anime graffiti-brutalism building blocks for the winning scene: spray tags with drips, stencil
## numerals, torn wheatpaste posters, slanted plates, caution tape, the P1 crown and marker notes
## with scribbled arrows. Everything is a plain Control tree built in code (no scenes), sized for the
## 1920x1080 stage, so a cut can be assembled and freed as one subtree.

const T := preload("res://scripts/ui/ui_theme_tokens.gd")
const UI := preload("res://scripts/ui/pit_wall_ui.gd")
const Street := preload("res://scripts/ui/street_style.gd")
const TAG_FONT := preload("res://assets/fonts/PermanentMarker.ttf")
const STENCIL_FONT := preload("res://assets/fonts/SairaStencilOne-Regular.ttf")
const MONO := preload("res://assets/fonts/JetBrainsMono.ttf")
const TAPE_SHADER := preload("res://shaders/winning_caution_tape.gdshader")

const INK := Color("#050505")
const PAPER := Color("#E8E4D6")
const ORANGE := Color("#FF6B00")
const LIME := Color("#CCFF00")
const MIN_TAG_FONT: int = 60
## A wrapped tag must still clear the plate below it (wall cuts leave 230 px), so it keeps shrinking down to this.
const WRAPPED_TAG_MAX_HEIGHT: float = 230.0
const WRAPPED_TAG_FLOOR: int = 28
const TAG_OUTLINE_PX: int = 4
const TAG_SHADOW_PX: int = 9
const DRIP_WIDTH_PX: float = 12.0
const NOTE_FONT_PX: int = 58


## Marker-pen name with ink outline, hard shadow and paint drips. Shrinks to MIN_TAG_FONT to fit
## `max_width`; a name still too wide wraps at that size instead of leaving the screen.
static func spray_tag(text: String, color: Color, max_width: float, font_size: int = 170, animate: bool = true) -> Label:
	var label := Label.new()
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var settings := _settings(TAG_FONT, font_size, Color.WHITE, TAG_OUTLINE_PX, TAG_SHADOW_PX)
	label.label_settings = settings
	var size: int = font_size
	while label.get_minimum_size().x > max_width and size > MIN_TAG_FONT:
		size = maxi(MIN_TAG_FONT, int(float(size) * 0.92))
		settings.font_size = size
	var body: Vector2 = label.get_minimum_size()
	if body.x > max_width:
		# An autowrap Label reports a 1 px minimum width, so measure the wrapped text with the font instead.
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.custom_minimum_size = Vector2(max_width, 0.0)
		var wrapped_height: float = TAG_FONT.get_multiline_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, max_width, size).y
		while wrapped_height > WRAPPED_TAG_MAX_HEIGHT and size > WRAPPED_TAG_FLOOR:
			size -= 4
			settings.font_size = size
			wrapped_height = TAG_FONT.get_multiline_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, max_width, size).y
		body = Vector2(max_width, wrapped_height)
	label.size = body
	var count: int = clampi(int(body.x / 90.0), 4, 9)
	for i: int in range(count):
		var drip := ColorRect.new()
		drip.name = "Drip%d" % i
		drip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		drip.color = color
		drip.size = Vector2(DRIP_WIDTH_PX, 26.0 + float((i * 37) % 58))
		drip.position = Vector2(8.0 + float(i) * (body.x - 24.0) / float(count), body.y * 0.9)
		label.add_child(drip)
	if animate:
		label.tree_entered.connect(_animate_drips.bind(label), CONNECT_ONE_SHOT)
	return label


static func _animate_drips(label: Label) -> void:
	var index: int = 0
	for child: Node in label.get_children():
		var drip := child as ColorRect
		if drip == null:
			continue
		var seconds: float = 3.0 + float(index % 3)
		var tween: Tween = label.create_tween().set_loops()
		tween.tween_property(drip, "scale:y", 1.0, seconds).from(0.55).set_delay(float(index) * 0.35)
		tween.tween_property(drip, "scale:y", 0.55, seconds)
		index += 1


## LabelSettings rather than theme overrides: a Label outside the tree ignores overrides when it
## reports its minimum size, and the tag shrink loop measures before the label is ever added.
static func _settings(font: Font, size: int, color: Color, outline_px: int, shadow_px: int) -> LabelSettings:
	var settings := LabelSettings.new()
	settings.font = font
	settings.font_size = size
	settings.font_color = color
	settings.outline_size = outline_px
	settings.outline_color = INK
	settings.shadow_size = 0
	settings.shadow_color = INK
	settings.shadow_offset = Vector2(shadow_px, shadow_px)
	return settings


## Big stencil position numeral: ink outline plus a hard offset shadow, in the medal colour.
static func stencil_numeral(text: String, color: Color, font_size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Outline and shadow scale with the glyph, so a 54 px chip numeral is not drowned by a 560 px one's shadow.
	label.label_settings = _settings(STENCIL_FONT, font_size, color, clampi(font_size / 80, 3, 7), clampi(font_size / 46, 3, 12))
	return label


## Torn wheatpaste poster with a halftone overlay. Put content as children of the returned Control.
static func poster(size: Vector2, tilt_deg: float) -> Control:
	var root := Control.new()
	root.custom_minimum_size = size
	root.size = size
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.pivot_offset = size * 0.5
	root.rotation_degrees = tilt_deg
	var paper := Polygon2D.new()
	paper.name = "Paper"
	paper.color = PAPER
	paper.polygon = _torn_outline(size)
	root.add_child(paper)
	var dots := ColorRect.new()
	dots.name = "Halftone"
	dots.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dots.color = Color.WHITE
	dots.position = Vector2(8.0, 8.0)
	dots.size = size - Vector2(16.0, 16.0)
	var material := ShaderMaterial.new()
	material.shader = UI.DOTS
	material.set_shader_parameter("dot_color", Color(0.0, 0.0, 0.0, 0.2))
	material.set_shader_parameter("dot_spacing", 10.0)
	dots.material = material
	root.add_child(dots)
	return root


## Rectangle whose edges wobble by up to 10 px (deterministic, so every poster tears the same way).
static func _torn_outline(size: Vector2) -> PackedVector2Array:
	var points := PackedVector2Array()
	var steps: int = 8
	for i: int in range(steps):
		points.append(Vector2(size.x * float(i) / float(steps), float((i * 53) % 11)))
	for i: int in range(steps):
		points.append(Vector2(size.x - float((i * 29) % 11), size.y * float(i) / float(steps)))
	for i: int in range(steps):
		points.append(Vector2(size.x * float(steps - i) / float(steps), size.y - float((i * 41) % 11)))
	for i: int in range(steps):
		points.append(Vector2(float((i * 17) % 11), size.y * float(steps - i) / float(steps)))
	return points


static func plate(text: String, fill: Color, font_size: int = 28) -> Label:
	return Street.badge(text, fill, font_size)


static func caution_tape(width: float) -> Control:
	var strip := Control.new()
	strip.custom_minimum_size = Vector2(width, 60.0)
	strip.size = Vector2(width, 60.0)
	strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var fill := ColorRect.new()
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fill.size = strip.size
	var material := ShaderMaterial.new()
	material.shader = TAPE_SHADER
	fill.material = material
	strip.add_child(fill)
	return strip


## The P1 crown stamp: lime polygon with an ink contour. 150 x 110 px.
static func crown() -> Control:
	var root := Control.new()
	root.custom_minimum_size = Vector2(150.0, 110.0)
	root.size = Vector2(150.0, 110.0)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var points := PackedVector2Array([
		Vector2(10, 96), Vector2(4, 26), Vector2(42, 58), Vector2(75, 8), Vector2(108, 58), Vector2(146, 26), Vector2(140, 96),
	])
	var shape := Polygon2D.new()
	shape.name = "Crown"
	shape.color = LIME
	shape.polygon = points
	root.add_child(shape)
	var contour := Line2D.new()
	contour.name = "Ink"
	contour.points = points
	contour.closed = true
	contour.width = 8.0
	contour.default_color = INK
	contour.joint_mode = Line2D.LINE_JOINT_ROUND
	root.add_child(contour)
	return root


## White marker text with an optional mono sub-label on a black plate (a hand-written callout).
static func marker_note(text: String, sub: String = "") -> Control:
	var root := Control.new()
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var body := VBoxContainer.new()
	body.name = "Body"
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.add_theme_constant_override("separation", 4)
	root.add_child(body)
	var title := Label.new()
	title.name = "Text"
	title.text = text
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title.label_settings = _settings(TAG_FONT, NOTE_FONT_PX, Color.WHITE, 3, 5)
	body.add_child(title)
	if sub != "":
		var caption := Label.new()
		caption.name = "Sub"
		caption.text = sub
		caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
		caption.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		caption.add_theme_font_override("font", MONO)
		caption.add_theme_font_size_override("font_size", 22)
		caption.add_theme_color_override("font_color", LIME)
		var box := StyleBoxFlat.new()
		box.bg_color = INK
		box.content_margin_left = 8.0
		box.content_margin_right = 8.0
		caption.add_theme_stylebox_override("normal", box)
		body.add_child(caption)
	return root


## Points of a hand-drawn arrow: a gentle quadratic curve from `from` to `to`, then a three-point head.
static func arrow_points(from: Vector2, to: Vector2) -> PackedVector2Array:
	var points := PackedVector2Array()
	var direction: Vector2 = to - from
	var bend: Vector2 = from.lerp(to, 0.5) + direction.orthogonal() * 0.18
	var steps: int = 8
	for i: int in range(steps + 1):
		var t: float = float(i) / float(steps)
		points.append(from.lerp(bend, t).lerp(bend.lerp(to, t), t))
	var back: Vector2 = -direction.normalized() * 34.0
	points.append(to + back.rotated(0.5))
	points.append(to)
	points.append(to + back.rotated(-0.5))
	return points


static func scribble_arrow(from: Vector2, to: Vector2) -> Line2D:
	var line := Line2D.new()
	line.width = 7.0
	line.default_color = LIME
	line.joint_mode = Line2D.LINE_JOINT_ROUND
	line.begin_cap_mode = Line2D.LINE_CAP_ROUND
	line.end_cap_mode = Line2D.LINE_CAP_ROUND
	line.points = arrow_points(from, to)
	return line
