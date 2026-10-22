extends SceneTree

## Run: Godot --headless --path . --script res://tests/test_pit_wall.gd
const Dashboard = preload("res://scenes/pit_wall/pit_wall_dashboard.tscn")
var failures := 0

func _initialize() -> void:
	call_deferred("_run")

func check(ok: bool, description: String) -> void:
	if not ok:
		failures += 1
		push_error(description)
	print("[%s] %s" % ["PASS" if ok else "FAIL", description])

func _run() -> void:
	var dashboard = Dashboard.instantiate()
	root.add_child(dashboard)
	await process_frame
	await process_frame
	var session = dashboard.session
	session.paused = true
	session.set_process(false)
	check(dashboard.tower.rows.size() == 20,"20 real simulation cars populate timing tower")
	var row = dashboard.tower.rows[4]
	row.set_selected(true)
	check(row.get_node("Shift/Fill").get_theme_stylebox("panel").bg_color == Color("#F4F5F7"),"row inversion is immediate, not color-tweened")
	await create_timer(.12).timeout
	check(is_equal_approx(row.get_node("Shift").position.x,6.0),"selected row reaches exact +6px within120ms")
	row.set_selected(false)
	row.mouse_entered.emit()
	row.mouse_exited.emit()
	row.set_selected(true)
	await create_timer(.12).timeout
	check(is_equal_approx(row.get_node("Shift").position.x,6.0),"rapid hover exit cannot cancel persistent selection")
	dashboard.tower.select_car(0)
	var initial_fuel: float = session.engine.get_car(0).fuel_remaining_kg
	session.engine.step_ticks(120)
	session.publish()
	check(session.engine.get_car(0).fuel_remaining_kg < initial_fuel,"simulator advances fuel telemetry")
	session.engine.step_ticks(7200)
	session.publish()
	check(dashboard._ribbon_lap.text == "LAP 02 / 50","session ribbon shows active lap after first finish-line crossing")
	var boundary_packet: Dictionary = session.engine.get_car(0).get_telemetry()
	boundary_packet["tire_wear"] = PackedFloat64Array([0.60,0.30,0.61,0.29])
	dashboard.deck.update_telemetry(boundary_packet)
	var cells: Array = dashboard.deck._tire_cells
	check(cells[0]["pct"].text == "60%" and cells[1]["pct"].text == "30%" and cells[2]["pct"].text == "61%" and cells[3]["pct"].text == "29%","four corners display remaining condition, not consumed wear")
	check(cells[0]["tint"] == Color("#FFE600") and cells[1]["tint"] == Color("#FF1E56") and cells[2]["tint"] == Color("#CCFF00") and cells[3]["critical"],"60/30 percent warning boundaries and critical blink")
	session.publish()
	check(not session.set_pace(2,2) and not session.set_pace(0,3),"commands reject rival car and invalid pace")
	check(not session.set_fuel(-1,0) and not session.set_fuel(1,-1),"commands reject invalid fuel targets")
	dashboard._select_team_car(0)
	dashboard.deck.pace_slider.value = 2
	dashboard.deck.fuel_slider.value = 0
	check(session.engine.get_car(0).pace_mode == 2 and session.engine.get_car(0).engine_mode == 0,"pace and fuel controls change selected car")
	dashboard._select_team_car(1)
	dashboard.deck.pace_slider.value = 0
	dashboard.deck.fuel_slider.value = 2
	dashboard._select_team_car(0)
	check(dashboard.deck.pace_slider.value == 2 and dashboard.deck.fuel_slider.value == 0,"car switch restores per-car strategy without feedback")
	check(session.engine.get_car(1).pace_mode == 0 and session.engine.get_car(1).engine_mode == 2,"second car retains independent strategy")
	dashboard._select_focus(8)
	check(dashboard.workspace.selected_car_id == 8 and dashboard.deck.selected_car_id == 0,"rival focus changes viewer but never command target")
	dashboard._select_team_car(1)
	dashboard.deck.box_button.pressed.emit()
	check(session.engine.get_car(1).box_requested and not session.engine.get_car(0).box_requested,"BOX applies only to active team car")
	check(not session.request_box(1),"repeated BOX cannot duplicate accepted request")
	dashboard.radio.play_radio(0,"OLD TRANSMISSION",false)
	dashboard.radio.play_radio(1,"NEW TRANSMISSION",true)
	await create_timer(.3).timeout
	check(dashboard.radio.speech.text.contains("NEW TRANSMISSION"),"rapid radio preserves newest transmission")
	check(dashboard.radio.layer == 30 and dashboard.radio.banner.visible,"radio enters reactive layer")
	for scale: float in [1.0,2.0,4.0,8.0,16.0]:
		session.set_speed(scale)
		check(session.engine.time_scale == scale,"session speed %dx" % int(scale))
	session.set_speed(3)
	check(session.engine.time_scale == 16.0,"invalid speed leaves last valid speed unchanged")
	await create_timer(.7).timeout
	check(dashboard._workspace_root.position.is_equal_approx(Vector2.ZERO),"micro-shake returns to exact base position")
	await create_timer(4.0).timeout
	check(not dashboard.radio.banner.visible,"radio hides after transmission without stale tween")
	dashboard.queue_free()
	await process_frame
	print("PIT WALL ACCEPTANCE: %s" % ("PASS" if failures == 0 else "%d FAILURES" % failures))
	quit(0 if failures == 0 else 1)
