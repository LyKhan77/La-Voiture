extends SceneTree

## Run: godot --headless --path . -s res://tests/test_winning_triptych.gd
## The triptych: three slanted panels in podium order (P2, P1, P3), a focus tween that widens one panel,
## the intro, manual focus cycling and the narrow layout that leaves room for the timing tower.
var failures: int = 0
var assertions: int = 0
var focus_log: Array[int] = []
var press_log: Array[int] = []


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


func _entry(slot: int, name: String, points: int) -> Dictionary:
	return {"id": slot, "team_id": slot / 2, "driver_name": name, "team_name": "TEAM", "number": slot + 1, "code": "XXX",
		"time": 300.0, "points": points, "is_dnf": false}


func _triptych(count: int) -> WinningTriptych:
	var all: Array[Dictionary] = [_entry(0, "K. Ryu", 25), _entry(2, "M. Ito", 18), _entry(8, "T. Kade", 15)]
	var gaps: Array[String] = ["5:00.000", "+1.700s", "+3.400s"]
	var entries: Array = []
	var picked_gaps: Array[String] = []
	var textures: Array[Dictionary] = []
	for place: int in range(count):
		entries.append(all[place])
		picked_gaps.append(gaps[place])
		textures.append({"standee": _texture(96, 172), "car": _texture(160, 96), "portrait": _texture(64, 64)})
	var triptych := WinningTriptych.new()
	var bonus_ids: Array[int] = []
	triptych.setup(entries, picked_gaps, bonus_ids, textures, false)
	root.add_child(triptych)
	return triptych


func _widths_equal(t: WinningTriptych) -> bool:
	for panel: WinningPanel in t.panels:
		if absf(panel.size.x - t.panels[0].size.x) > 1.0:
			return false
	return true


func _run() -> void:
	var t: WinningTriptych = _triptych(3)
	t.focus_changed.connect(func(place: int) -> void: focus_log.append(place))
	t.panel_pressed.connect(func(place: int) -> void: press_log.append(place))
	await process_frame

	check(t.panels.size() == 3 and _widths_equal(t), "Equal state gives three equal panels (%.0f px)" % t.panels[0].size.x)
	var p1: WinningPanel = t.panels[0]
	var p2: WinningPanel = t.panels[1]
	var p3: WinningPanel = t.panels[2]
	check(p2.position.x < p1.position.x and p1.position.x < p3.position.x, "Panels stand in podium order P2, P1, P3")
	check(is_equal_approx(p2.position.x + p2.size.x - p1.position.x, WinningTriptych.OVERLAP_PX)
		and is_equal_approx(p1.position.x + p1.size.x - p3.position.x, WinningTriptych.OVERLAP_PX), "Neighbouring panels overlap by exactly 90 px")
	check(is_equal_approx(t.panels[0].background.position.x, p1.position.x) and t.panels[0].background.get_parent() != p1.get_parent(),
		"The background sits on a lower layer at the panel's position")
	var screen_right: float = t.global_position.x + t.size.x - WinningTriptych.BLEED_PX
	check(p3.engine_plate.get_global_rect().end.x <= screen_right and p3.sfx_label.get_global_rect().end.x <= screen_right
		and p3.name_label.get_global_rect().end.x <= screen_right + 1.0,
		"The right-most panel keeps its right-anchored details on screen (screen edge %.0f)" % screen_right)
	check(t.name_labels.size() == 3 and t.name_labels[0].text.contains("K. RYU") and t.name_labels[1].text.contains("M. ITO")
		and t.name_labels[2].text.contains("#09") and t.time_labels[2].text.contains("+3.400s"), "name_labels and time_labels keep P1, P2, P3 order")

	t.play_intro()
	check(t.focus_place == -1 and p1.detail_amount == 0.0 and p2.detail_amount == 0.0 and p3.detail_amount == 0.0
		and p1.dim_amount == 0.0 and p3.dim_amount == 0.0, "Intro shows no details and dims nothing")
	await create_timer(1.3).timeout
	check(_widths_equal(t) and is_zero_approx(p1.position.y), "After the intro the panels rest in place at equal width")

	t.set_focus(2, true)
	var ratio: float = p3.size.x / p1.size.x
	check(absf(ratio - WinningTriptych.FOCUS_WEIGHT) < 0.02, "Focus gives the focused panel 1.55 times the others (%.3f)" % ratio)
	check(p3.dim_amount == 0.0 and p1.dim_amount == 1.0 and p2.dim_amount == 1.0, "Only the focused panel stays bright")
	check(p3.detail_amount == 1.0 and p1.detail_amount == 0.0 and p2.detail_amount == 0.0, "Only the focused panel shows its details")
	t.set_focus(-1, true)
	check(_widths_equal(t) and p1.detail_amount == 1.0 and p2.detail_amount == 1.0 and p3.detail_amount == 1.0 and p2.dim_amount == 0.0,
		"Equal focus shows every detail on every panel")
	check(focus_log == [2, -1], "Focus changes emit once each with the place (%s)" % str(focus_log))
	t.set_focus(-1, true)
	check(focus_log == [2, -1], "Setting the same focus again emits nothing")

	var walk: Array[int] = []
	for step: int in range(4):
		t.cycle_focus(1)
		walk.append(t.focus_place)
	check(walk == [1, 0, 2, -1], "Focus cycles equal, P2, P1, P3, equal (%s)" % str(walk))
	var back: Array[int] = []
	for step: int in range(4):
		t.cycle_focus(-1)
		back.append(t.focus_place)
	check(back == [2, 0, 1, -1], "Stepping back reverses the cycle (%s)" % str(back))

	t.set_focus(2)
	t.set_focus(1)
	t.set_focus(-1)
	await create_timer(1.1).timeout
	check(_widths_equal(t) and p1.dim_amount == 0.0 and p2.dim_amount == 0.0 and p1.detail_amount == 1.0,
		"Reversing focus before the tween ends converges to the last request")

	t.set_available_width(1230.0, true)
	check(t.panel_rect(2).end.x <= 1280.0 and t.panel_rect(1).position.x >= -46.0 and _widths_equal(t),
		"Narrow layout keeps every panel clear of the tower at x=1280 (right edge %.0f)" % t.panel_rect(2).end.x)
	t.set_available_width(1920.0, true)
	check(t.panel_rect(2).end.x > 1900.0, "Full width returns")

	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = Vector2(300.0, 500.0)
	p1.background.gui_input.emit(click)
	check(press_log == [0], "A click on a panel background reports that panel (%s)" % str(press_log))
	t.queue_free()

	var two: WinningTriptych = _triptych(2)
	check(two.panels.size() == 2 and _widths_equal(two) and two.panels[1].position.x < two.panels[0].position.x, "Two finishers make two equal panels, P2 left of P1")
	two.set_focus(2, true)
	check(two.focus_place == -1, "Focusing a finisher that does not exist is ignored")
	two.queue_free()
	var one: WinningTriptych = _triptych(1)
	check(one.panels.size() == 1 and is_equal_approx(one.panels[0].size.x, one.size.x), "One finisher fills the whole width")
	one.queue_free()
	var none: WinningTriptych = _triptych(0)
	none.set_focus(0, true)
	none.cycle_focus(1)
	none.play_intro()
	check(none.panels.is_empty() and none.focus_place == -1, "No finisher makes no panels and nothing fails")
	none.queue_free()
	await process_frame
	print("WINNING TRIPTYCH: %d assertions, %d FAIL" % [assertions, failures])
	quit(0 if failures == 0 else 1)
