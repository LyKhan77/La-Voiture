extends SceneTree

## Run: godot --headless --path . -s res://tests/test_graffiti_kit.gd
const Kit := preload("res://scripts/ui/graffiti_kit.gd")
const Roster := preload("res://scripts/ui/garage_roster.gd")
var failures: int = 0
var assertions: int = 0


func _initialize() -> void:
	call_deferred("_run")


func check(ok: bool, message: String) -> void:
	assertions += 1
	if not ok:
		failures += 1
		push_error(message)
	print("[%s] %s" % ["PASS" if ok else "FAIL", message])


func _drips(node: Node) -> int:
	var count: int = 0
	for child: Node in node.get_children():
		if child.name.begins_with("Drip"):
			count += 1
	return count


func _run() -> void:
	check(Roster.CAR_ENGINES.size() == Roster.CAR_SLUGS.size() and Roster.CAR_ENGINES[0] == "6.2L V8 NA"
		and Roster.CAR_ENGINES[1] == "5.2L V10 NA", "Every car slug has an engine configuration, in slug order")
	var tag: Label = Kit.spray_tag("T. KADE", Color.ORANGE, 760.0)
	root.add_child(tag)
	check(_drips(tag) >= 4 and tag.get_minimum_size().x <= 760.0, "A spray tag drips and fits its width")
	var long_tag: Label = Kit.spray_tag("MAXIMILIAN-ALEXANDER FEATHERSTONEHAUGH", Color.CYAN, 760.0)
	root.add_child(long_tag)
	var wrapped: bool = long_tag.autowrap_mode != TextServer.AUTOWRAP_OFF
	check(long_tag.size.x > 100.0 and long_tag.size.x <= 760.0 and long_tag.size.y <= 230.0,
		"A very long driver name ends up inside a 760 x 230 box (wrapped: %s)" % wrapped)
	var drips_inside: bool = _drips(long_tag) >= 4
	for child: Node in long_tag.get_children():
		var drip := child as ColorRect
		if drip != null:
			drips_inside = drips_inside and drip.position.x >= 0.0 and drip.position.x <= long_tag.size.x
	check(drips_inside, "Every drip hangs from the tag, none off its left edge")
	check(long_tag.label_settings.font_size >= 40, "The shrunk tag stays readable")
	var numeral: Label = Kit.stencil_numeral("P3", Color.ORANGE, 560)
	check(numeral.label_settings.font != null and numeral.label_settings.font_size == 560,
		"A stencil numeral carries its font and size")
	var poster: Control = Kit.poster(Vector2(520, 720), -4.0)
	root.add_child(poster)
	check(poster.get_node("Paper").polygon.size() >= 12 and is_equal_approx(poster.rotation_degrees, -4.0),
		"A wheatpaste poster has a torn edge and its tilt")
	var plate: Label = Kit.plate("BRONZE LOCK", Kit.ORANGE)
	check(plate.text == "BRONZE LOCK", "A plate keeps its text")
	var tape: Control = Kit.caution_tape(1920.0)
	check(tape.size == Vector2(1920, 60) and (tape.get_child(0) as CanvasItem).material is ShaderMaterial,
		"Caution tape is a 60 px shader strip")
	var note: Control = Kit.marker_note("6.2L V8 NA", "MERCEDES-AMG GT3 EVO")
	root.add_child(note)
	check(note.get_child_count() >= 1, "A marker note has a body")
	var arrow: Line2D = Kit.scribble_arrow(Vector2(0, 0), Vector2(200, 120))
	check(arrow.points.size() >= 6 and arrow.points[arrow.points.size() - 1] != Vector2.ZERO,
		"A scribble arrow curves toward its target and has a head")
	for entry: Array in [["winning_concrete", Shader.MODE_SPATIAL], ["winning_impact_frame", Shader.MODE_CANVAS_ITEM], ["winning_caution_tape", Shader.MODE_CANVAS_ITEM]]:
		var shader := load("res://shaders/%s.gdshader" % entry[0]) as Shader
		check(shader != null and shader.get_mode() == entry[1], "%s compiles in the right mode" % entry[0])
	var crown: Control = Kit.crown()
	check(crown.get_node("Crown").polygon.size() >= 7, "The crown stamp is a real polygon")
	crown.free()
	for node: Node in [tag, long_tag, poster, note]:
		node.queue_free()
	numeral.free()
	plate.free()
	tape.free()
	arrow.free()
	for i: int in range(3):
		await process_frame
	check(int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)) == 0, "The kit leaves zero orphan nodes")
	print("GRAFFITI KIT: %d assertions, %d FAIL" % [assertions, failures])
	quit(0 if failures == 0 else 1)
