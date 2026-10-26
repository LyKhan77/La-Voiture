class_name StewardBanner
extends Control

## Manga wheatpaste strip for the stewards: INCIDENT UNDER INVESTIGATION in amber, then the verdict -
## a crimson hazard-striped time penalty, or a dim green no further action. Fed by GtRace.steward_event.

const UI := preload("res://scripts/ui/pit_wall_ui.gd")
const T := preload("res://scripts/ui/ui_theme_tokens.gd")
## The investigation stays up past its 10 s so a late verdict replaces it rather than the screen going blank.
const INVESTIGATION_HOLD_S: float = 12.0
const VERDICT_HOLD_S: float = 6.0
const NO_ACTION_COLOR := Color("#00E08A")
const STRIPE_W: float = 28.0

var header_label: Label
var accent: Color = T.ACCENT_CYBER_YELLOW
## True while the banner shows a time penalty (the crimson hazard style).
var penalty: bool = false
var remaining_s: float = 0.0
var stripe_offset: float = 0.0


func _init() -> void:
	custom_minimum_size = Vector2(760.0, 58.0)
	size = custom_minimum_size
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	header_label = UI.label("", 22, accent, UI.HEADER)
	header_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	header_label.position = Vector2(14.0, 6.0)
	header_label.size = Vector2(size.x - 28.0, 36.0)
	add_child(header_label)


## `event` is a GtRace.steward_event payload.
func show_event(event: Dictionary) -> void:
	var verdict: bool = String(event.get("phase", "")) == "verdict"
	penalty = verdict and int(event.get("verdict", 0)) == GtStewards.Verdict.PENALTY
	if not verdict:
		accent = T.ACCENT_CYBER_YELLOW
	elif penalty:
		accent = T.ACCENT_ANIME_CRIMSON
	else:
		accent = NO_ACTION_COLOR
	header_label.text = String(event.get("text", ""))
	header_label.add_theme_color_override("font_color", accent)
	remaining_s = VERDICT_HOLD_S if verdict else INVESTIGATION_HOLD_S
	visible = true
	queue_redraw()


func advance(delta: float) -> void:
	if not visible:
		return
	remaining_s = maxf(0.0, remaining_s - delta)
	visible = remaining_s > 0.0
	if not PresentationSettings.reduce_motion:
		stripe_offset = fposmod(stripe_offset + delta * 36.0, STRIPE_W * 2.0)
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2(6.0, 6.0), size), Color.BLACK) # hard shadow
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.06, 0.07, 0.09, 0.95))
	draw_rect(Rect2(Vector2.ZERO, size), accent, false, 3.0)
	var stripes_y: float = size.y - 12.0
	var x: float = -STRIPE_W * 2.0 + stripe_offset
	while x < size.x:
		var left: float = clampf(x, 3.0, size.x - 3.0)
		var right: float = clampf(x + STRIPE_W, 3.0, size.x - 3.0)
		if right > left:
			draw_rect(Rect2(left, stripes_y, right - left, 8.0), accent if penalty else Color(accent, 0.45))
		x += STRIPE_W * 2.0
