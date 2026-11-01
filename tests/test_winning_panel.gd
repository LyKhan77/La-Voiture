extends SceneTree

## Run: godot --headless --path . -s res://tests/test_winning_panel.gd
## One triptych panel: standee, car sprite, close-up bubble, manga card elements, and how they react to
## detail, dim and panel width. Textures are synthetic here; the scene test uses the real files.
const Roster := preload("res://scripts/ui/garage_roster.gd")
var failures: int = 0
var assertions: int = 0
var shared: Dictionary = {}


func _initialize() -> void:
	call_deferred("_run")


func check(ok: bool, message: String) -> void:
	assertions += 1
	if not ok:
		failures += 1
		push_error(message)
	print("[%s] %s" % ["PASS" if ok else "FAIL", message])


func _texture(width: int, height: int) -> Texture2D:
	var image := Image.create_empty(width, height, false, Image.FORMAT_RGBA8)
	image.fill(Color(0.8, 0.3, 0.3, 1.0))
	return ImageTexture.create_from_image(image)


func _textures() -> Dictionary:
	return {"standee": _texture(96, 172), "car": _texture(160, 96), "portrait": _texture(64, 64)}


func _entry(slot: int, name: String, points: int) -> Dictionary:
	return {"id": slot, "team_id": slot / 2, "driver_name": name, "team_name": "TEAM", "number": slot + 1, "code": "XXX",
		"time": 300.0, "points": points, "is_dnf": false}


func _panel(place: int, entry: Dictionary, gap: String, bonus: bool = false, textures: Dictionary = {}) -> WinningPanel:
	var panel := WinningPanel.new()
	panel.setup(place, entry, gap, bonus, textures if not textures.is_empty() else shared, false)
	panel.relayout(Vector2(730.0, 940.0))
	root.add_child(panel)
	return panel


func _run() -> void:
	shared = _textures()
	var p1: WinningPanel = _panel(0, _entry(0, "K. Ryu", 25), "5:00.000")
	var p2: WinningPanel = _panel(1, _entry(2, "M. Ito", 18), "+1.700s")
	var p3: WinningPanel = _panel(2, _entry(8, "T. Kade", 15), "+3.400s")
	check(p1.rank_label.text == "P1" and p1.kanji_label.text.replace("\n", "") == "優勝" and p1.crown != null,
		"P1 panel shows its rank, kanji and crown")
	check(p2.crown == null and p3.crown == null and p3.kanji_label.text.replace("\n", "") == "第三位", "Only P1 wears the crown")
	check(p3.result_label.text == "+3.400s // 15 PTS", "Result plate carries gap and points")
	var bonus: WinningPanel = _panel(0, _entry(0, "K. Ryu", 26), "5:00.000", true)
	check(bonus.result_label.text == "5:00.000 // 26 PTS +1 FL", "The fastest-lap bonus is marked on the plate")
	var retired: Dictionary = _entry(8, "T. Kade", 0)
	retired.is_dnf = true
	check(_panel(2, retired, "DNF").result_label.text == "DNF // 0 PTS", "A retired finisher shows DNF and zero points")
	check(_panel(2, _entry(8, "T. Kade", 0), "RUNNING").result_label.text == "RUNNING // 0 PTS", "A running finisher shows RUNNING")
	check(p2.name_label.text == "#03 M. ITO", "Name tag carries the car number and the uppercased driver")
	var long_name: WinningPanel = _panel(1, _entry(2, "MAXIMILIAN-ALEXANDER FEATHERSTONEHAUGH", 18), "+1.700s")
	check(long_name.name_label.size.x <= WinningPanel.NAME_MAX_WIDTH, "A very long name still fits the tag (%.0f px)" % long_name.name_label.size.x)
	check(float(p1.standee.material.get_shader_parameter("outline_px")) > 0.0 and float(p1.car.material.get_shader_parameter("outline_px")) > 0.0,
		"Standee and car carry the die-cut outline")
	check(p1.bubble.texture == shared.portrait and p1.standee.texture == shared.standee and p1.car.texture == shared.car,
		"Bubble, standee and car show the textures they were given")

	p1.detail_amount = 0.0
	check(is_zero_approx(p1.epithet_box.modulate.a) and is_zero_approx(p1.engine_plate.modulate.a) and is_zero_approx(p1.sfx_label.modulate.a),
		"Detail amount 0 hides the three detail elements")
	p1.detail_amount = 1.0
	check(is_equal_approx(p1.epithet_box.modulate.a, 1.0) and is_equal_approx(p1.engine_plate.modulate.a, 1.0) and is_equal_approx(p1.sfx_label.modulate.a, 1.0),
		"Detail amount 1 shows them")
	check(p1.epithet_box.visible and p1.epithet_box.find_children("*", "Label", true, false).any(func(l: Node) -> bool: return (l as Label).text == "THE HIGH-VOLTAGE PRODIGY"),
		"The epithet box carries the driver's epithet")
	var unknown: WinningPanel = _panel(1, _entry(99, "X. Nobody", 0), "+9.000s")
	check(not unknown.epithet_box.visible, "An empty epithet hides its box")
	var textures: Dictionary = _textures()
	textures.car = null
	var carless: WinningPanel = _panel(1, _entry(2, "M. Ito", 18), "+1.700s", false, textures)
	check(not carless.car.visible, "A null car texture draws no car and does not fail")

	p1.relayout(Vector2(617.0, 940.0))
	check(is_equal_approx(p1.car.size.x, 0.76 * 617.0) and is_equal_approx(p1.car.position.x + p1.car.size.x * 0.5, 617.0 * 0.5),
		"The car is 76%% of the panel width and centred (%.1f px)" % p1.car.size.x)
	p1.relayout(Vector2(1200.0, 940.0))
	check(is_equal_approx(p1.car.size.x, WinningPanel.CAR_MAX_WIDTH), "The car width is capped at %d px in a wide panel" % int(WinningPanel.CAR_MAX_WIDTH))
	check(is_equal_approx(p1.standee.size.y, WinningPanel.STANDEE_HEIGHT) and is_equal_approx(p1.standee.position.y + p1.standee.size.y, 940.0),
		"The standee is 640 px tall and stands on the panel floor")

	p2.dim_amount = 1.0
	check(is_equal_approx(p2.modulate.r, 0.5) and is_equal_approx(p2.background.modulate.r, 0.5), "Dim darkens content and background to half brightness")
	p2.dim_amount = 0.0
	check(is_equal_approx(p2.modulate.r, 1.0) and is_equal_approx(p2.background.modulate.r, 1.0), "Dim 0 restores full brightness")
	p2.relayout(Vector2(617.0, 940.0))
	var polygon: PackedVector2Array = p2.background_polygon()
	check(polygon.size() == 4 and is_equal_approx(polygon[0].x, 90.0) and is_equal_approx(polygon[1].x, 617.0) and is_equal_approx(polygon[2].x, 527.0) and is_equal_approx(polygon[3].x, 0.0),
		"The background is a parallelogram slanted 90 px")

	for panel: WinningPanel in [p1, p2, p3, bonus, long_name, unknown, carless]:
		panel.queue_free()
	await process_frame
	print("WINNING PANEL: %d assertions, %d FAIL" % [assertions, failures])
	quit(0 if failures == 0 else 1)
