class_name TyreLifeRing
extends Control

## A tyre life ring: the arc is the life left (from 12 o'clock) with the compound letter in the middle. The colour
## is crimson from the tyre cliff down, the same line as the deck's TYRE LIFE gauge, and never follows the team
## accent. The telemetry wheel reads the same rules through the statics below.

const T = preload("res://scripts/ui/ui_theme_tokens.gd")
const UI = preload("res://scripts/ui/pit_wall_ui.gd")
const TRACK := Color("#242a38")

var life: float = 1.0
var letter: String = ""
var letter_color: Color = T.TEXT_PRIMARY
## Times the ring asked for a redraw (the tests use it to see that an unchanged tyre stays quiet).
var change_count: int = 0


func _init(size_px: float = 22.0) -> void:
	custom_minimum_size = Vector2(size_px, size_px)
	size = custom_minimum_size
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## Tyre life left (0..1) from the car's wear.
static func life_of(wear: float) -> float:
	return clampf(1.0 - wear, 0.0, 1.0)


## Lime above the tyre cliff, crimson from it down.
static func tint_for(p_life: float) -> Color:
	return T.ACCENT_ANIME_CRIMSON if p_life <= 1.0 - GtTypes.TYRE_CLIFF_WEAR else T.ACCENT_ACID_LIME


## How many of `total` ticks light for this life: a sliver of life still lights one.
static func lit_ticks(p_life: float, total: int) -> int:
	return ceili(clampf(p_life, 0.0, 1.0) * float(total) - 0.0001)


func set_tyre(p_life: float, p_letter: String, p_letter_color: Color) -> void:
	if p_life == life and p_letter == letter and p_letter_color == letter_color:
		return
	life = p_life
	letter = p_letter
	letter_color = p_letter_color
	change_count += 1
	queue_redraw()


func _draw() -> void:
	var diameter: float = minf(size.x, size.y)
	var centre: Vector2 = size * 0.5
	var width: float = 3.0 if diameter <= 30.0 else 4.0
	var radius: float = diameter * 0.5 - width * 0.5 - 1.0
	draw_circle(centre, radius, T.SURFACE_PANEL_DARK)
	draw_arc(centre, radius, 0.0, TAU, 32, TRACK, width, true)
	var swept: float = clampf(life, 0.0, 1.0) * TAU
	if swept > 0.0:
		draw_arc(centre, radius, -PI * 0.5, -PI * 0.5 + swept, 32, tint_for(life), width, true)
	var font_size: int = roundi(diameter * 0.42)
	var glyph_size: Vector2 = UI.MONO.get_string_size(letter, HORIZONTAL_ALIGNMENT_CENTER, -1.0, font_size)
	draw_string(UI.MONO, Vector2(centre.x - glyph_size.x * 0.5, centre.y + glyph_size.y * 0.32), letter, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, letter_color)
