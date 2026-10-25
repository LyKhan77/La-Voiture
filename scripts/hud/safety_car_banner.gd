class_name SafetyCarBanner
extends Control

const UI := preload("res://scripts/ui/pit_wall_ui.gd")
const Types := preload("res://scripts/gt/gt_types.gd")
const DURATION_S: float = 3.8
const DEPLOYED_COLOR := Color("#D8FF00")
const IN_LAP_COLOR := Color("#38BDF8")

var header_label: Label
var sub_label: Label
var accent: Color = DEPLOYED_COLOR
var remaining_s: float = 0.0
var marquee_offset: float = 0.0
var _halftone_tex: ImageTexture = null


func _init() -> void:
	custom_minimum_size = Vector2(780.0, 90.0)
	size = custom_minimum_size
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	
	var img := Image.create(8, 8, false, Image.FORMAT_RGBA8)
	img.fill(Color(1.0, 1.0, 1.0, 0.0))
	img.set_pixel(3, 3, Color.WHITE)
	_halftone_tex = ImageTexture.create_from_image(img)
	
	header_label = UI.label("", 26, accent, UI.DISPLAY)
	header_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header_label.position = Vector2(20.0, 13.0)
	header_label.size.x = 740.0
	add_child(header_label)
	sub_label = UI.label("", 12, Color.WHITE, UI.HEADER)
	sub_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub_label.position = Vector2(20.0, 48.0)
	sub_label.size.x = 740.0
	add_child(sub_label)


func _exit_tree() -> void:
	_halftone_tex = null


func trigger(flag: int, message: String) -> void:
	if flag != Types.Flag.SC:
		visible = false
		remaining_s = 0.0
		return
	var in_lap: bool = "IN THIS LAP" in message or "IN_THIS_LAP" in message
	accent = IN_LAP_COLOR if in_lap else DEPLOYED_COLOR
	header_label.text = "◆ SAFETY CAR IN THIS LAP ◆" if in_lap else "★ SAFETY CAR DEPLOYED ★"
	sub_label.text = "リスタート準備 // LIGHTS OUT // PREPARE FOR RESTART" if in_lap else "セーフティーカー出動 // REDUCE SPEED & MAINTAIN DELTA"
	header_label.add_theme_color_override("font_color", accent)
	remaining_s = DURATION_S
	marquee_offset = 0.0
	visible = true
	queue_redraw()


func advance(delta: float) -> void:
	if not visible:
		return
	remaining_s = maxf(0.0, remaining_s - delta)
	visible = remaining_s > 0.0
	if not PresentationSettings.reduce_motion:
		marquee_offset = fposmod(marquee_offset + delta * 48.0, 32.0)
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2(7.0, 7.0), size), Color.BLACK)
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.06, 0.07, 0.09, 0.95))
	draw_rect(Rect2(Vector2.ZERO, size), accent, false, 3.0)
	draw_rect(Rect2(Vector2(6.0, 6.0), size - Vector2(12.0, 12.0)), Color(accent, 0.55), false, 1.0)
	if _halftone_tex != null:
		draw_texture_rect(_halftone_tex, Rect2(16.0, 12.0, 754.0, 60.0), true, Color(accent, 0.08))
	for x: int in range(-32, 812, 32):
		var at: float = float(x) + marquee_offset
		var left: float = clampf(at, 9.0, size.x - 9.0)
		var right: float = clampf(at + 15.0, 9.0, size.x - 9.0)
		draw_line(Vector2(left, 80.0), Vector2(right, 70.0), accent, 6.0, true)
