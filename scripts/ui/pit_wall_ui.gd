class_name PitWallUI
extends RefCounted

const T = preload("res://scripts/ui/ui_theme_tokens.gd")
const MONO = preload("res://assets/fonts/JetBrainsMono.ttf")
const HEADER = preload("res://assets/fonts/BarlowCondensed.ttf")
const DISPLAY = preload("res://assets/fonts/Anton.ttf")
const RADIO = preload("res://assets/fonts/ChakraPetch.ttf")
const DOTS = preload("res://shaders/halftone_screentone.gdshader")
const CHAMFER = preload("res://shaders/chamfer_header.gdshader")

static func label(text: String, font_size: int = 14, color: Color = T.TEXT_PRIMARY, font: Font = MONO) -> Label:
	var node := Label.new()
	node.text = text
	node.add_theme_font_override("font", font)
	node.add_theme_font_size_override("font_size", font_size)
	node.add_theme_color_override("font_color", color)
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return node

static func style(fill: Color = T.SURFACE_PANEL_DARK, border: Color = T.INK_BORDER_BLACK, shadow: Color = Color.BLACK) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.set_border_width_all(3)
	box.border_color = border
	box.shadow_color = shadow
	box.shadow_size = 0
	box.shadow_offset = Vector2(5, 5)
	box.set_content_margin_all(12)
	return box

static func surface(target: Control, accent: Color = Color(1, 1, 1, 0.2)) -> void:
	var shadow := ColorRect.new()
	shadow.name = "HardOffsetShadow"
	shadow.color = T.INK_BORDER_BLACK
	shadow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	target.add_child(shadow)
	shadow.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shadow.offset_left = 5
	shadow.offset_top = 5
	shadow.offset_right = 5
	shadow.offset_bottom = 5
	var outer := StyleBoxFlat.new()
	outer.bg_color = accent
	outer.expand_margin_left = 1.0
	outer.expand_margin_top = 1.0
	outer.expand_margin_right = 1.0
	outer.expand_margin_bottom = 1.0
	var outline := Panel.new()
	outline.name = "InkOutline"
	outline.add_theme_stylebox_override("panel", outer)
	outline.mouse_filter = Control.MOUSE_FILTER_IGNORE
	target.add_child(outline)
	outline.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var panel := Panel.new()
	panel.name = "InkSurface"
	var fill := style()
	fill.set_border_width_all(0)
	panel.add_theme_stylebox_override("panel", fill)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	target.add_child(panel)
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var texture := ColorRect.new()
	texture.name = "MangaScreentone"
	texture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat := ShaderMaterial.new()
	mat.shader = DOTS
	texture.material = mat
	target.add_child(texture)
	texture.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	texture.offset_left = 3
	texture.offset_top = 3
	texture.offset_right = -3
	texture.offset_bottom = -3
	var ink := Control.new()
	ink.name = "InkBorder2_5px"
	ink.mouse_filter = Control.MOUSE_FILTER_IGNORE
	target.add_child(ink)
	ink.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ink.draw.connect(func():
		ink.draw_rect(Rect2(Vector2(1.25,1.25), ink.size - Vector2(2.5,2.5)), T.INK_BORDER_BLACK, false, 2.5)
	)
	ink.resized.connect(ink.queue_redraw)
	# Panel chrome is a backdrop; parent custom telemetry draws above it.
	for background: CanvasItem in [shadow, outline, panel, texture, ink]:
		background.show_behind_parent = true

static func header(text: String, accent: Color = T.ACCENT_ACID_LIME) -> Control:
	var root := Control.new()
	root.custom_minimum_size.y = 28
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var shape := ColorRect.new()
	shape.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat := ShaderMaterial.new()
	mat.shader = CHAMFER
	mat.set_shader_parameter("fill_color", accent)
	shape.material = mat
	root.add_child(shape)
	shape.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.resized.connect(func(): mat.set_shader_parameter("rect_size", root.size))
	var title := label(text, 18, T.INK_BORDER_BLACK, HEADER)
	root.add_child(title)
	title.position = Vector2(10, 0)
	return root

static func button(text: String, accent: Color = T.ACCENT_ACID_LIME) -> Button:
	var node := Button.new()
	node.text = text
	node.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	node.add_theme_font_override("font", HEADER)
	node.add_theme_font_size_override("font_size", 18)
	for state: String in ["normal", "disabled"]:
		node.add_theme_stylebox_override(state, style(T.SURFACE_PANEL_ELEVATED))
	for state: String in ["hover", "pressed", "focus"]:
		node.add_theme_stylebox_override(state, style(T.SURFACE_SNAP_INVERT, accent))
	for state: String in ["hover", "pressed", "focus"]:
		node.add_theme_color_override("font_" + state + "_color", T.INK_BORDER_BLACK)
	node.add_theme_color_override("font_color", T.TEXT_PRIMARY)
	return node

