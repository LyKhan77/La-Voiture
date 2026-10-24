extends RefCounted
## Team-colour state of the Team Garage. The selected team's livery colour is the accent of every
## garage widget; the hard shadow is crimson (the other pages' language) unless the accent already
## sits near crimson, and the type on an accent face flips between ink and white by luminance.
## Widgets register what follows the accent once and `set_accent()` repaints all of it in place.
signal changed
const T := preload("res://scripts/ui/ui_theme_tokens.gd")
const CRIMSON := Color("#FF1E56")
const CYAN := Color("#00F0FF")
const PINK := Color("#FF007F")
## Hue distance (0..0.5) under which a team colour counts as "near crimson" and swaps its shadow.
const NEAR_CRIMSON_HUE: float = 0.11
const MIN_SATURATION_FOR_HUE: float = 0.3
const DARK_TYPE_LUMINANCE: float = 0.35
## The engineer card colour must sit at least this far (0..0.5 of the hue wheel, 55 degrees) from the accent.
const ENGINEER_MIN_HUE_GAP: float = 55.0 / 360.0
var accent: Color = T.ACCENT_ACID_LIME
var shadow: Color = CRIMSON
var on_accent: Color = T.INK_BORDER_BLACK
## The pit wall engineer's colour: complementary to the accent (see engineer_for).
var engineer: Color = CYAN
var _faces: Array = [] # [StyleBoxFlat, lighten]
var _shadows: Array[StyleBoxFlat] = []
var _borders: Array[StyleBoxFlat] = []
var _colors: Array = [] # [Control, theme colour name, kind]
func set_accent(color: Color) -> void:
	blend_accent(color, color)
## Paints `color` now but derives shadow/ink from `goal`, so a tween toward a new team does not
## flip the shadow colour half way through.
func blend_accent(color: Color, goal: Color) -> void:
	accent = color
	var hue_gap: float = absf(fposmod(goal.h - CRIMSON.h + 0.5, 1.0) - 0.5)
	shadow = CYAN if hue_gap < NEAR_CRIMSON_HUE and goal.s > MIN_SATURATION_FOR_HUE else CRIMSON
	var lin: Color = goal.srgb_to_linear()
	var luminance: float = 0.2126 * lin.r + 0.7152 * lin.g + 0.0722 * lin.b
	on_accent = T.INK_BORDER_BLACK if luminance > DARK_TYPE_LUMINANCE else Color.WHITE
	engineer = engineer_for(goal)
	_apply()
	changed.emit()
## First of cyan, pink, lime, yellow whose hue is at least ENGINEER_MIN_HUE_GAP from `accent`; a grey accent gets cyan.
static func engineer_for(accent: Color) -> Color:
	if accent.s < MIN_SATURATION_FOR_HUE:
		return CYAN
	for candidate: Color in [CYAN, PINK, T.ACCENT_ACID_LIME, T.ACCENT_CYBER_YELLOW]:
		var gap: float = absf(accent.h - candidate.h)
		if minf(gap, 1.0 - gap) > ENGINEER_MIN_HUE_GAP:
			return candidate
	return CYAN


## `box.bg_color` follows the accent (optionally lightened for hover faces).
func face(box: StyleBoxFlat, lighten: float = 0.0) -> StyleBoxFlat:
	_faces.append([box, lighten])
	box.bg_color = accent.lightened(lighten)
	return box
func shade(box: StyleBoxFlat) -> StyleBoxFlat:
	_shadows.append(box)
	box.shadow_color = shadow
	return box
func border(box: StyleBoxFlat) -> StyleBoxFlat:
	_borders.append(box)
	box.border_color = accent
	return box
## A theme colour of `node` follows "accent", "on" (ink on the accent face) or "shadow".
func tint(node: Control, theme_color: String, kind: String = "accent") -> void:
	_colors.append([node, theme_color, kind])
	node.add_theme_color_override(theme_color, _color_of(kind))
func _color_of(kind: String) -> Color:
	match kind:
		"on":
			return on_accent
		"shadow":
			return shadow
	return accent
func _apply() -> void:
	for entry: Array in _faces:
		(entry[0] as StyleBoxFlat).bg_color = accent.lightened(float(entry[1]))
	for box: StyleBoxFlat in _shadows:
		box.shadow_color = shadow
	for box: StyleBoxFlat in _borders:
		box.border_color = accent
	for entry: Array in _colors:
		var node: Control = entry[0]
		if is_instance_valid(node):
			node.add_theme_color_override(entry[1], _color_of(entry[2]))
