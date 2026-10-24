extends SceneTree

## FASE 11 Langkah 3e acceptance: the R2 "wheatpaste collage" radio cards. The headline keeps `speech.text` plain
## (older tests read it) and shows the highlighted, capitalised text in a separate RichTextLabel; the card is a torn
## paper with tape; two cards make a two-way conversation (talk / dim, slap entry, preloaded portraits).
## Run: Godot --headless --path . -s res://tests/test_radio_r2.gd

const CutInScene := preload("res://scenes/pit_wall/anime_radio_cutin.tscn")
const T := preload("res://scripts/ui/ui_theme_tokens.gd")

var failures: int = 0
var assertions: int = 0


func _initialize() -> void:
	call_deferred("_run")


func check(ok: bool, description: String) -> void:
	assertions += 1
	if not ok:
		failures += 1
		push_error(description)
	print("[%s] %s" % ["PASS" if ok else "FAIL", description])


func _run() -> void:
	await _test_card()
	print("%d assertions, %d failure(s)" % [assertions, failures])
	print("FASE 11 LANGKAH 3E RADIO R2: %s" % ("PASS" if failures == 0 else "%d FAILURES" % failures))
	quit(0 if failures == 0 else 1)


func _cut_in(role: int) -> CanvasLayer:
	var cut_in: CanvasLayer = CutInScene.instantiate()
	cut_in.role = role
	root.add_child(cut_in)
	await process_frame
	return cut_in


# --- the card -------------------------------------------------------------------------------------------------------

func _test_card() -> void:
	var marked: String = RadioMarkup.highlight("BOX THIS LAP, CONFIRM WET TYRES. BOXING IS NOT A CALL", Color.RED, Color("#050505"))
	check(marked.count("[bgcolor=") == 3 and marked.contains("[bgcolor=#050505][color=#ff0000]BOX[/color][/bgcolor] THIS LAP") and marked.contains(" BOXING IS NOT")
			and RadioMarkup.ink_for(Color("#101820")) == Color.WHITE and RadioMarkup.ink_for(Color("#CCFF00")) == Color("#050505"),
		"radio r2: keywords are highlighted whole-word and the ink follows the paper (%s)" % marked)

	var cut_in: CanvasLayer = await _cut_in(0)
	cut_in.play_radio(3, "Box this lap, confirm WET tyres.")
	await process_frame
	var size := Vector2(470.0, 190.0)
	var inside: bool = true
	for point: Vector2 in cut_in.paper_polygon(size):
		inside = inside and Rect2(Vector2.ZERO, size).grow(0.01).has_point(point)
	check(cut_in.speech.text == "Box this lap, confirm WET tyres." and cut_in.rich.text.contains("[bgcolor=") and cut_in.rich.text.contains(" THIS LAP, CONFIRM ")
			and cut_in.rich.get_theme_font_size("normal_font_size") == 30 and cut_in.paper_polygon(size).size() >= 16 and inside
			and cut_in.tape_rects().size() == 2 and cut_in.WAVE_BARS == 12,
		"radio r2: the card is paper with tape and a highlighted headline")

	cut_in.set_base_color(Color("#336699"))
	cut_in.play_radio(1, "Hold position.", false)
	var calm: bool = cut_in._accent == Color("#336699")
	cut_in.play_radio(1, "Box now!", true)
	check(calm and cut_in._accent == T.ACCENT_ANIME_CRIMSON, "radio r2: the paper takes the speaker's colour, urgent calls are crimson")

	cut_in.set_dock(Rect2(352.0, 88.0, 1230.0, 790.0), 0.5)
	cut_in.play_radio(1, "Hold position.", false)
	cut_in.set_dimmed(true)
	var dimmed: bool = is_equal_approx(cut_in.banner.modulate.a, 0.6) and cut_in.banner.scale.is_equal_approx(Vector2(0.475, 0.475)) and cut_in.dimmed
	cut_in.set_dimmed(false)
	check(dimmed and is_equal_approx(cut_in.banner.modulate.a, 1.0) and cut_in.banner.scale.is_equal_approx(Vector2(0.5, 0.5)) and not cut_in.dimmed,
		"radio r2: the listener dims and recovers")

	var viewport_h: float = cut_in.get_viewport().get_visible_rect().size.y
	cut_in.play_radio(2, "Suspension has snapped from the flat tyre! I can't continue, the car is destroyed, please send help to turn four.")
	var tall: float = cut_in._banner_h
	cut_in.play_radio(2, "Box now.")
	check(tall > cut_in.BANNER_MIN_HEIGHT and tall <= viewport_h and is_equal_approx(cut_in._banner_h, cut_in.BANNER_MIN_HEIGHT),
		"radio r2: long calls make the card taller, short ones keep 470x190 (%.0f)" % tall)
	cut_in.queue_free()
