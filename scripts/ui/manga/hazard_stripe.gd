extends Control
## A diagonal two-colour caution stripe (the "COMING SOON" strip of the menus, the poster rule).
const SLANT: float = 0.466 # tan(25 deg) lean of the stripes
var base_color: Color = Color("#050505")
var stripe_color: Color = Color("#FFE600")
var period: float = 28.0
func _init(p_base: Color = Color("#050505"), p_stripe: Color = Color("#FFE600")) -> void:
	base_color = p_base
	stripe_color = p_stripe
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)
func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), base_color)
	var lean: float = size.y * SLANT
	var x: float = -lean
	while x < size.x:
		draw_colored_polygon(PackedVector2Array([
			Vector2(x + lean, 0.0), Vector2(x + lean + period * 0.5, 0.0),
			Vector2(x + period * 0.5, size.y), Vector2(x, size.y),
		]), stripe_color)
		x += period
