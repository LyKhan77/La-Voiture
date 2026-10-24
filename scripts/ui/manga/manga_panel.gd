extends Control
## The Team Garage's panel chrome: ink border, hard black offset shadow, an optional team-coloured
## spine, and the halftone "chamfer" header tag the Race Setup and HUD panels use (here it follows
## the garage accent). Children are positioned in this control's own coordinates (border included).
const GarageStyle := preload("res://scripts/ui/manga/garage_style.gd")
const FONT_HEADER := preload("res://assets/fonts/BarlowCondensed.ttf")
const INK := Color("#050505")
const FILL := Color(0.055, 0.066, 0.094, 0.95)
const BORDER_PX: float = 4.0
const CHAMFER_PX: float = 22.0
const TAG_PAD_LEFT: float = 14.0
const TAG_PAD_RIGHT: float = 40.0
static var _dots: ImageTexture
var style: GarageStyle
var header: String = ""
var header_height: float = 38.0
var header_font_size: int = 20
## Width of the accent spine on the left edge; 0 draws none.
var spine_width: float = 0.0
var shadow_offset: Vector2 = Vector2(6.0, 6.0)
func _init(p_style: GarageStyle = null) -> void:
	style = p_style
	mouse_filter = Control.MOUSE_FILTER_IGNORE
func _ready() -> void:
	if style != null:
		style.changed.connect(queue_redraw)
func _draw() -> void:
	var accent: Color = style.accent if style != null else Color.WHITE
	var on_accent: Color = style.on_accent if style != null else INK
	draw_rect(Rect2(shadow_offset, size), Color.BLACK)
	draw_rect(Rect2(Vector2.ZERO, size), FILL)
	draw_rect(Rect2(Vector2.ONE * BORDER_PX * 0.5, size - Vector2.ONE * BORDER_PX), INK, false, BORDER_PX)
	if spine_width > 0.0:
		draw_rect(Rect2(BORDER_PX, BORDER_PX, spine_width, size.y - BORDER_PX * 2.0), accent)
	if header.is_empty():
		return
	var text_width: float = FONT_HEADER.get_string_size(header, HORIZONTAL_ALIGNMENT_LEFT, -1, header_font_size).x
	var tag_width: float = TAG_PAD_LEFT + text_width + TAG_PAD_RIGHT
	var tag := PackedVector2Array([
		Vector2(0.0, 0.0), Vector2(tag_width, 0.0),
		Vector2(tag_width - CHAMFER_PX, header_height), Vector2(0.0, header_height),
	])
	draw_colored_polygon(tag, accent)
	draw_texture_rect(_dot_texture(), Rect2(0.0, 0.0, tag_width - CHAMFER_PX, header_height), true)
	draw_string(FONT_HEADER, Vector2(TAG_PAD_LEFT, header_height * 0.5 + float(header_font_size) * 0.34),
		header, HORIZONTAL_ALIGNMENT_LEFT, -1, header_font_size, on_accent)
## One 5 px halftone cell (a soft dark dot) tiled over the header like `chamfer_header.gdshader`.
static func _dot_texture() -> ImageTexture:
	if _dots == null:
		var image := Image.create(5, 5, false, Image.FORMAT_RGBA8)
		for y: int in range(2, 4):
			for x: int in range(2, 4):
				image.set_pixel(x, y, Color(0.0, 0.0, 0.0, 0.24))
		_dots = ImageTexture.create_from_image(image)
	return _dots
