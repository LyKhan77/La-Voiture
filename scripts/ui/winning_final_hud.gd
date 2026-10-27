extends RefCounted

## HUD layer of the final cut: the spray headline naming the winning make, the P1 poster plate, the
## P2/P3 sticker chips and the P1 crown. It only builds the skeleton; WinningScene fills the texts
## (`name_labels`, `time_labels`, `headline`, `winner_label`) from the results snapshot.

const Kit := preload("res://scripts/ui/graffiti_kit.gd")
const UI := preload("res://scripts/ui/pit_wall_ui.gd")
const T := preload("res://scripts/ui/ui_theme_tokens.gd")

const STAGE := Vector2(1920.0, 1080.0)
const HEADLINE_PX: int = 130
const HEADLINE_MAX_WIDTH: float = 1000.0
const CHIP_SIZE := Vector2(430.0, 140.0)
const POSTER_SIZE := Vector2(600.0, 210.0)
const P2_COLOR := Color("#00F0FF")
const P3_COLOR := Color("#FF6B00")


## Returns {root, headline, winner_label, crown, name_labels, time_labels}; name/time labels are in P1, P2, P3 order.
static func build(animate: bool = true) -> Dictionary:
	var root := Control.new()
	root.name = "FinalHud"
	root.size = STAGE
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var names: Array[Label] = []
	var times: Array[Label] = []

	var headline: Label = Kit.spray_tag("MERCEDES-AMG\nTAKES IT", T.ACCENT_ACID_LIME, HEADLINE_MAX_WIDTH, HEADLINE_PX, animate)
	headline.name = "Headline"
	headline.label_settings.line_spacing = -50.0
	headline.size = headline.get_minimum_size()
	headline.pivot_offset = headline.size * 0.5
	headline.position = Vector2(64.0, 60.0)
	headline.rotation_degrees = -3.0
	root.add_child(headline)

	var winner_label: Label = UI.label("", 20, Color.WHITE, UI.MONO)
	winner_label.name = "WinnerLine"
	winner_label.position = Vector2(68.0, 372.0)
	winner_label.add_theme_color_override("font_outline_color", Kit.INK)
	winner_label.add_theme_constant_override("outline_size", 8)
	root.add_child(winner_label)

	var poster: Control = Kit.poster(POSTER_SIZE, -1.5)
	poster.name = "P1Poster"
	poster.position = Vector2(64.0, 770.0)
	root.add_child(poster)
	var caption: Label = UI.label("P1 / GRAND CHAMPION", 22, Kit.INK, UI.MONO)
	caption.position = Vector2(28.0, 16.0)
	poster.add_child(caption)
	var p1_name: Label = UI.label("—", 44, Kit.INK, UI.HEADER)
	p1_name.position = Vector2(28.0, 42.0)
	p1_name.custom_minimum_size = Vector2(POSTER_SIZE.x - 56.0, 118.0)
	p1_name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	p1_name.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	poster.add_child(p1_name)
	var p1_time: Label = UI.label("—", 22, Kit.INK, UI.MONO)
	p1_time.position = Vector2(28.0, 168.0)
	poster.add_child(p1_time)
	names.append(p1_name)
	times.append(p1_time)

	for place: int in [1, 2]:
		var chip := Panel.new()
		chip.name = "Chip%d" % (place + 1)
		chip.size = CHIP_SIZE
		chip.pivot_offset = CHIP_SIZE * 0.5
		chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var accent: Color = P2_COLOR if place == 1 else P3_COLOR
		var box := StyleBoxFlat.new()
		box.bg_color = Kit.PAPER
		box.set_border_width_all(4)
		box.border_color = Kit.INK
		box.shadow_color = accent
		box.shadow_size = 1
		box.shadow_offset = Vector2(9.0, 9.0)
		chip.add_theme_stylebox_override("panel", box)
		chip.position = Vector2(64.0, 420.0) if place == 1 else Vector2(104.0, 580.0)
		chip.rotation_degrees = -3.0 if place == 1 else 2.5
		root.add_child(chip)
		var numeral: Label = Kit.stencil_numeral("P%d" % (place + 1), accent, 54)
		numeral.position = Vector2(14.0, 6.0)
		chip.add_child(numeral)
		var chip_name: Label = UI.label("—", 30, Kit.INK, UI.HEADER)
		chip_name.position = Vector2(112.0, 8.0)
		chip_name.custom_minimum_size = Vector2(CHIP_SIZE.x - 124.0, 88.0)
		chip_name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		chip_name.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		chip.add_child(chip_name)
		var chip_time: Label = UI.label("—", 20, Kit.INK, UI.MONO)
		chip_time.position = Vector2(112.0, 100.0)
		chip.add_child(chip_time)
		names.append(chip_name)
		times.append(chip_time)

	var crown: Control = Kit.crown()
	crown.name = "Crown"
	root.add_child(crown)
	return {"root": root, "headline": headline, "winner_label": winner_label, "crown": crown,
		"name_labels": names, "time_labels": times}
