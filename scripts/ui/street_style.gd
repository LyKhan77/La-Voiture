extends RefCounted

## Concept 01 "Street Tag & Speed Stencil": the building blocks shared by the main menu, Settings and
## Race Setup. Everything leans -12 degrees (0.21 rad) like the title logo: skewed dark plates with an
## ink border and a hard offset shadow that flip to a lime face with a crimson shadow when hot.

const T := preload("res://scripts/ui/ui_theme_tokens.gd")
const HEADER := preload("res://assets/fonts/BarlowCondensed.ttf")

const SLANT_RAD: float = -0.21
const PLATE_FILL := Color("#141722")
const HOVER_FILL := Color("#252b3b")
const BORDER_PX: int = 4

static var _switch_cache: Dictionary = {} # bool (on) -> ImageTexture


## One skewed plate: ink border, solid offset shadow (a 1 px blur reads as a hard edge).
static func plate(fill: Color, shadow: Color, shadow_offset: Vector2, border_px: int = BORDER_PX, border: Color = T.INK_BORDER_BLACK) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.set_border_width_all(border_px)
	box.border_color = border
	box.skew = Vector2(SLANT_RAD, 0.0)
	box.shadow_color = shadow
	box.shadow_size = 1
	box.shadow_offset = shadow_offset
	box.content_margin_left = 22.0
	box.content_margin_right = 22.0
	return box


## Rest / hover / pressed / focus / disabled plates on any Button-like control (Button, OptionButton, ...).
static func skin(control: Control, border_px: int = 3, shadow: Vector2 = Vector2(4.0, 4.0), font_size: int = 20) -> void:
	var rest := plate(PLATE_FILL, Color.BLACK, shadow, border_px)
	var hover := plate(HOVER_FILL, Color.BLACK, shadow, border_px, T.ACCENT_ACID_LIME)
	var hot := plate(T.ACCENT_ACID_LIME, T.ACCENT_ANIME_CRIMSON, shadow + Vector2(1.0, 1.0), border_px)
	control.add_theme_stylebox_override("normal", rest)
	control.add_theme_stylebox_override("disabled", rest)
	control.add_theme_stylebox_override("hover", hover)
	control.add_theme_stylebox_override("pressed", hot)
	control.add_theme_stylebox_override("focus", hot)
	control.add_theme_font_override("font", HEADER)
	control.add_theme_font_size_override("font_size", font_size)
	control.add_theme_color_override("font_color", T.TEXT_PRIMARY)
	control.add_theme_color_override("font_hover_color", T.ACCENT_ACID_LIME)
	for state: String in ["pressed", "focus", "hover_pressed"]:
		control.add_theme_color_override("font_" + state + "_color", T.INK_BORDER_BLACK)
	control.add_theme_color_override("font_disabled_color", T.TEXT_MUTED)


## A tilted crimson tag with white type (the "SYS // CONFIG" badge, the circuit name tag).
static func badge(text: String, fill: Color = T.ACCENT_ANIME_CRIMSON, font_size: int = 22) -> Label:
	var label := Label.new()
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_override("font", HEADER)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", T.TEXT_PRIMARY if fill == T.ACCENT_ANIME_CRIMSON else T.INK_BORDER_BLACK)
	var box := plate(fill, Color.BLACK, Vector2(4.0, 4.0), 3)
	box.content_margin_left = 18.0
	box.content_margin_right = 18.0
	label.add_theme_stylebox_override("normal", box)
	label.rotation = SLANT_RAD * 0.25
	return label


## A flat section heading plate (lime or cyan face, ink type).
static func section(text: String, fill: Color = T.ACCENT_ACID_LIME) -> Label:
	var label := badge(text, fill, 20)
	label.rotation = 0.0
	return label


## A skewed on/off switch picture for CheckButton ("checked" / "unchecked" icons).
static func switch_icon(on: bool) -> Texture2D:
	if _switch_cache.has(on):
		return _switch_cache[on]
	var width: int = 76
	var height: int = 34
	var image := Image.create(width, height, false, Image.FORMAT_RGBA8)
	var body: Color = Color("#05060a")
	var knob: Color = T.ACCENT_ACID_LIME if on else Color("#3a4052")
	for y: int in range(height):
		var shift: float = (float(height) * 0.5 - float(y)) * 0.21
		for x: int in range(width):
			var local: float = float(x) - 8.0 - shift
			var inside: bool = local >= 0.0 and local < 60.0 and y >= 2 and y < height - 2
			if not inside:
				continue
			var border: bool = local < 3.0 or local >= 57.0 or y < 5 or y >= height - 5
			var on_knob: bool = (local >= 32.0 and local < 56.0) if on else (local >= 4.0 and local < 28.0)
			var color: Color = T.INK_BORDER_BLACK if border else (knob if on_knob else body)
			image.set_pixel(x, y, color)
	var texture := ImageTexture.create_from_image(image)
	_switch_cache[on] = texture
	return texture


## A skewed ink bar with a lime fill and a crimson slanted thumb (the volume sliders).
static func skin_slider(slider: HSlider) -> void:
	var track := plate(Color("#05060a"), Color.BLACK, Vector2(3.0, 3.0), 3)
	track.content_margin_top = 7.0
	track.content_margin_bottom = 7.0
	track.content_margin_left = 0.0
	track.content_margin_right = 0.0
	var fill := plate(T.ACCENT_ACID_LIME, Color(0.0, 0.0, 0.0, 0.0), Vector2.ZERO, 3)
	fill.content_margin_top = 7.0
	fill.content_margin_bottom = 7.0
	fill.content_margin_left = 0.0
	fill.content_margin_right = 0.0
	slider.add_theme_stylebox_override("slider", track)
	slider.add_theme_stylebox_override("grabber_area", fill)
	slider.add_theme_stylebox_override("grabber_area_highlight", fill)
	slider.add_theme_icon_override("grabber", thumb_icon())
	slider.add_theme_icon_override("grabber_highlight", thumb_icon())
	slider.add_theme_icon_override("grabber_disabled", thumb_icon())


static func thumb_icon() -> Texture2D:
	if _switch_cache.has("thumb"):
		return _switch_cache["thumb"]
	var width: int = 22
	var height: int = 36
	var image := Image.create(width, height, false, Image.FORMAT_RGBA8)
	for y: int in range(height):
		var shift: float = (float(height) * 0.5 - float(y)) * 0.21
		for x: int in range(width):
			var local: float = float(x) - 4.0 - shift
			if local < 0.0 or local >= 14.0 or y < 1 or y >= height - 1:
				continue
			var border: bool = local < 3.0 or local >= 11.0 or y < 4 or y >= height - 4
			image.set_pixel(x, y, T.INK_BORDER_BLACK if border else T.ACCENT_ANIME_CRIMSON)
	var texture := ImageTexture.create_from_image(image)
	_switch_cache["thumb"] = texture
	return texture
