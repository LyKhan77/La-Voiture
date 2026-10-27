extends RefCounted

## HUD layer of one driver spray-wall cut (P2 or P3): the team's wheatpaste poster, a giant stencil
## position, the driver's spray tag and a gap/points plate. The driver sticker itself is a 3D standee
## on the matching wall station; this layer is drawn over it in 1920x1080 stage space.

const Kit := preload("res://scripts/ui/graffiti_kit.gd")
const T := preload("res://scripts/ui/ui_theme_tokens.gd")

const TAG_MAX_WIDTH: float = 760.0
const TAG_FONT_PX: int = 170
## The standee is a 3D object under this HUD, so the numeral sits beside it, never across it.
const NUMERAL_FONT_PX: int = 500
const POSTER_SIZE := Vector2(520.0, 720.0)

## Per place (1 = P2, 2 = P3): colour, labels, and the mirrored layout (all positions in stage px).
const LOOKS: Dictionary = {
	1: {"color": Color("#00F0FF"), "numeral": "P2", "badge": "RUNNER-UP", "poster": Vector2(1310, 140), "poster_tilt": 4.0,
		"numeral_at": Vector2(90, 100), "numeral_tilt": 5.0, "tag": Vector2(130, 620), "tag_tilt": 4.0,
		"plate": Vector2(170, 850), "plate_tilt": 2.0, "badge_at": Vector2(640, 790), "badge_tilt": -3.0},
	2: {"color": Color("#FF6B00"), "numeral": "P3", "badge": "BRONZE LOCK", "poster": Vector2(90, 150), "poster_tilt": -4.0,
		"numeral_at": Vector2(1190, 100), "numeral_tilt": -5.0, "tag": Vector2(1100, 620), "tag_tilt": -4.0,
		"plate": Vector2(1080, 850), "plate_tilt": -2.0, "badge_at": Vector2(1480, 790), "badge_tilt": 3.0},
}


## `gap` is the finisher's already formatted gap text ("+3.400s", "DNF", ...).
static func build(place: int, entry: Dictionary, gap: String, animate: bool = true) -> Control:
	var look: Dictionary = LOOKS[place]
	var color: Color = look.color
	var root := Control.new()
	root.name = "WallCutP%d" % (place + 1)
	root.size = Vector2(1920.0, 1080.0)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var poster: Control = Kit.poster(POSTER_SIZE, float(look.poster_tilt))
	poster.name = "Poster"
	poster.position = look.poster
	root.add_child(poster)
	var caption := Label.new()
	caption.text = "#%02d / TEAM" % int(entry.number)
	caption.position = Vector2(26.0, 22.0)
	caption.add_theme_font_override("font", Kit.MONO)
	caption.add_theme_font_size_override("font_size", 22)
	caption.add_theme_color_override("font_color", Kit.INK)
	poster.add_child(caption)
	var team := Label.new()
	team.text = String(entry.team_name).to_upper()
	team.position = Vector2(26.0, 70.0)
	team.custom_minimum_size = Vector2(POSTER_SIZE.x - 52.0, 0.0)
	team.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	team.add_theme_font_override("font", Kit.STENCIL_FONT)
	team.add_theme_font_size_override("font_size", 84)
	team.add_theme_color_override("font_color", Kit.INK)
	poster.add_child(team)
	var number: Label = Kit.stencil_numeral("#%02d" % int(entry.number), color, 230)
	number.position = Vector2(26.0, POSTER_SIZE.y - 250.0)
	poster.add_child(number)

	var numeral: Label = Kit.stencil_numeral(look.numeral, color, NUMERAL_FONT_PX)
	numeral.name = "Numeral"
	_place(numeral, look.numeral_at, float(look.numeral_tilt))
	root.add_child(numeral)

	var tag: Label = Kit.spray_tag(String(entry.driver_name).to_upper(), color, TAG_MAX_WIDTH, TAG_FONT_PX, animate)
	tag.name = "Tag"
	_place(tag, look.tag, float(look.tag_tilt))
	root.add_child(tag)

	var plate: Label = Kit.plate("%s   //   %d PTS" % [gap, int(entry.points)], T.ACCENT_ACID_LIME, 44)
	plate.name = "GapPlate"
	plate.position = look.plate
	plate.rotation_degrees = float(look.plate_tilt)
	root.add_child(plate)
	var badge: Label = Kit.plate(look.badge, T.ACCENT_ANIME_CRIMSON, 28)
	badge.name = "Badge"
	badge.position = look.badge_at
	badge.rotation_degrees = float(look.badge_tilt)
	root.add_child(badge)
	return root


static func _place(label: Label, at: Vector2, tilt_deg: float) -> void:
	if label.size == Vector2.ZERO:
		label.size = label.get_minimum_size()
	label.pivot_offset = label.size * 0.5
	label.position = at
	label.rotation_degrees = tilt_deg
