class_name DeckTip
extends Control

## The hover tooltip of the deck: verdict mark and title, an optional plain-language sentence (COACH),
## the numbers, and the verdict line. It sits just above the control it explains, clamped inside the
## deck's width so it never leaves the screen.

const UI = preload("res://scripts/ui/pit_wall_ui.gd")
const T = preload("res://scripts/ui/ui_theme_tokens.gd")

const WIDTH: float = 440.0
const PAD: float = 10.0
const GAP: float = 6.0

var severity_mark := SeverityMark.new()
var title_label: Label
var plain_label: Label
var numbers_label: Label
var verdict_label: Label

var _body := VBoxContainer.new()


func _init() -> void:
	size = Vector2(WIDTH, 60.0)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	z_index = 20
	_body.position = Vector2(PAD, PAD)
	_body.size = Vector2(WIDTH - PAD * 2.0, 0.0)
	_body.add_theme_constant_override("separation", 3)
	_body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_body)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 6)
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_body.add_child(head)
	head.add_child(severity_mark)
	title_label = UI.label("", 14, T.TEXT_PRIMARY, UI.HEADER)
	head.add_child(title_label)
	plain_label = UI.label("", 12, T.TEXT_SECONDARY, UI.RADIO)
	plain_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	plain_label.custom_minimum_size.x = WIDTH - PAD * 2.0
	_body.add_child(plain_label)
	numbers_label = UI.label("", 11, T.TEXT_PRIMARY)
	_body.add_child(numbers_label)
	verdict_label = UI.label("", 12, T.TEXT_PRIMARY, UI.HEADER)
	verdict_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	verdict_label.custom_minimum_size.x = WIDTH - PAD * 2.0
	_body.add_child(verdict_label)


func show_for(target: Control, severity: int, title: String, plain: String, numbers: String, verdict: String, coach: bool) -> void:
	severity_mark.set_severity(severity)
	title_label.text = title
	plain_label.text = plain
	plain_label.visible = coach and plain != ""
	numbers_label.text = numbers
	numbers_label.visible = numbers != ""
	verdict_label.text = verdict
	verdict_label.add_theme_color_override("font_color", SeverityMark.color_of(severity))
	_body.size = Vector2(WIDTH - PAD * 2.0, 0.0)
	size = Vector2(WIDTH, maxf(_body.get_combined_minimum_size().y + PAD * 2.0, 48.0))
	var host := get_parent() as Control
	var host_width: float = host.size.x if host != null else WIDTH
	var origin: Vector2 = target.global_position - (host.global_position if host != null else Vector2.ZERO)
	position = Vector2(clampf(origin.x + target.size.x * 0.5 - WIDTH * 0.5, 0.0, maxf(0.0, host_width - WIDTH)), -size.y - GAP)
	visible = true
	queue_redraw()


func hide_tip() -> void:
	visible = false


func _draw() -> void:
	draw_style_box(UI.style(T.SURFACE_PANEL_DARK, SeverityMark.color_of(severity_mark.severity)), Rect2(Vector2.ZERO, size))
