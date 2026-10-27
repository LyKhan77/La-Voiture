extends SceneTree

## Run: Godot --headless --path . -s tests/test_main_menu_flow.gd
var assertions: int = 0
var failures: int = 0

func _initialize() -> void:
	_run.call_deferred()

func check(ok: bool, description: String) -> void:
	assertions += 1
	if not ok:
		failures += 1
	print("[%s] %s" % ["PASS" if ok else "FAIL", description])

func _run() -> void:
	create_timer(90.0).timeout.connect(func():
		check(false, "Menu acceptance completes within 90 seconds")
		_finish()
	)
	await process_frame
	if not ResourceLoader.exists("res://scripts/core/race_config_data.gd"):
		check(false, "Race configuration survives setup, garage and race scene ownership changes")
		_finish()
		return
	var config_script: Script = load("res://scripts/core/race_config_data.gd")
	var config: RefCounted = config_script.reset()
	config.race_seed = 12345
	config.selected_team_id = 8
	config.total_laps = 3
	config.weather_preset = 3
	config.time_of_day = 2
	config.car1_starting_compound = 3
	config.car2_starting_compound = 4
	var world: Node3D = load("res://scenes/race_weekend_world.tscn").instantiate()
	world.race_config = config
	world.pre_grid_hold = true
	root.add_child(world)
	world.set_physics_process(false)
	check(world.race.laps == 3 and world.race.player_team_id == 8, "Configured laps and selected team reach the real race")
	check(world.race.get_car(16).compound == 3 and world.race.get_car(17).compound == 4, "Independent teammate starting tires survive qualifying grid order")
	check(world.followed_id == 16, "Initial chase camera follows the selected team's first driver")
	check(world.race.weather.rain_intensity > 0.68 and world.race.weather.track_water_pct > 50.0, "Full monsoon starts wet, not as a late-race dry preset")
	check(int(world.race.weather.time_of_day["mode"]) == 2, "Configured night overrides weather seed")
	var rival_tires_match: bool = true
	for car: GtCar in world.race.cars:
		if car.team_id != 8:
			rival_tires_match = rival_tires_match and car.compound == 4
	check(rival_tires_match, "Monsoon rivals start on wet tires rather than inherited dry-grid slicks")
	check(world.race_seed == config.get("race_seed"), "Race restart and weather use the exhibition draft's own seed")
	world.step(20.0)
	check(world.director.clock_s == 0.0 and world.race.tick_count == 0, "Comic fly-through cannot consume the starting lights or simulate hidden racing")
	world.grid_intro_progress = 1.0
	world.finish_grid_intro()
	world.step(1.0)
	check(world.director.lights_on() == 1 and world.race.tick_count == 0, "Fly-through releases exactly the existing FIA countdown")
	var settings: Script = load("res://scripts/core/presentation_settings.gd")
	var rain_particles: GPUParticles3D = world.vfx.rain.find_children("*", "GPUParticles3D", true, false)[0]
	var rain_budget: int = rain_particles.amount
	var spray: GPUParticles3D = world.vfx.sprays[16]
	var spray_budget: int = spray.amount
	settings.set_quality(0)
	settings.apply_to_tree(world)
	world.vfx.update(0.1)
	check(rain_particles.amount < rain_budget and spray.amount < spray_budget, "Low VFX density survives dynamic rain and spray updates")
	check(not world.get_node("Sun").shadow_enabled, "Low quality disables actual race shadows")
	settings.set_quality(2)
	settings.apply_to_tree(world)
	world.queue_free()
	await process_frame
	config_script.current = null
	await _test_menu_scenes(config_script)
	_finish()

func _button(node: Node, fragment: String) -> Button:
	for child: Node in node.find_children("*", "Button", true, false):
		if fragment in (child as Button).text:
			return child as Button
	return null

func _test_menu_scenes(config_script: Script) -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	await process_frame
	var career: Button = _button(main, "CAREER")
	check(career != null and career.disabled, "Unavailable career mode cannot enter an unfinished race path")
	_button(main, "SETTINGS").pressed.emit()
	var modal: Node = main.find_child("SettingsModal", true, false)
	if modal == null:
		check(false, "Settings opens a functional modal above the menu")
	else:
		for bus: StringName in [&"Master", &"Music", &"SFX", &"Radio", &"UI"]:
			var slider: HSlider = modal.sliders[bus]
			var old_value: float = slider.value
			slider.value = 0.37
			var bus_index: int = AudioServer.get_bus_index(bus)
			check(is_equal_approx(AudioServer.get_bus_volume_linear(bus_index), 0.37), "%s slider applies its gain to the actual audio bus" % bus)
			slider.value = 0.0
			check(AudioServer.is_bus_mute(bus_index), "%s slider reaches genuine silence" % bus)
			slider.value = old_value
		modal.close()
	var exhibition: Button = _button(main, "EXHIBITION")
	if exhibition == null:
		check(false, "Entry point displays the playable exhibition menu")
		return
	var presentation: Script = load("res://scripts/core/presentation_settings.gd")
	presentation.halftone = false
	exhibition.pressed.emit()
	await scene_changed
	var setup: Node = current_scene
	var draft: RefCounted = config_script.get_config()
	check(_halftone_is_off(setup), "Halftone Off survives construction of fresh setup panels")
	setup.select_laps(3)
	check(draft.total_laps == 3 and setup.lap_select.selected == 0, "Quick Sprint remains selectable through setup's public action")
	setup.select_laps(10)
	setup.select_weather(2)
	setup.select_time_of_day(1)
	var continue_button: Button = _button(setup, "CONTINUE")
	if continue_button == null:
		check(false, "Race setup offers the team garage")
		return
	continue_button.pressed.emit()
	await scene_changed
	var garage: Node = current_scene
	check(garage.config.total_laps == 10 and garage.config.weather_preset == 2 and garage.config.time_of_day == 1, "Setup selections survive replacement by the 3D garage")
	check(garage.environment.stalls.size() == 10 and garage.environment.cars.size() == 10, "All ten occupied stalls exist before team switching")
	garage.orbit.focus(garage.environment.cars[0], true)
	garage.orbit.yaw = PI
	garage.orbit._process(0.0)
	garage.select_team(1)
	var avoids_partition: bool = true
	for frame: int in range(240):
		garage.orbit._process(1.0 / 240.0)
		var p: Vector3 = garage.camera.global_position
		if absf(p.x - 7.0) < 0.18 and p.z < 3.5 and p.z > -8.0 and p.y < 4.6:
			avoids_partition = false
	check(avoids_partition, "Rear-view orbit can dolly to the next stall without crossing its steel partition")
	garage.select_team(0)
	garage.launch_button.grab_focus()
	var right := InputEventKey.new()
	right.keycode = KEY_RIGHT
	right.pressed = true
	root.push_input(right)
	await process_frame
	check(garage.config.selected_team_id == 1, "Team-switch arrows work even while Launch owns keyboard focus")
	var expected_slugs: Array[String] = ["mercedes_amg", "audi_r8", "nissan_gtr", "bmw_m4", "aston_vantage", "chevy_corvette", "honda_nsx", "lexus_rcf", "mclaren_720s", "lambo_huracan"]
	for index: int in range(10):
		var model: Node3D = garage.environment.cars[index]
		var slug: String = expected_slugs[index]
		check(model.scene_file_path == "res://scenes/car/%s_chassis.tscn" % slug and is_equal_approx(garage.environment.stalls[index].position.x, float(index) * 14.0), "Stall %02d rides its race chassis at its dolly stop" % index)
	var roster: Script = load("res://scripts/ui/garage_roster.gd")
	check(GarageRoster.CAR_NAMES[0].begins_with("Mercedes-AMG") and ResourceLoader.exists(roster.car_path(0)) and roster.car_path(0).ends_with("mercedes_amg/mercedes_amg_full.glb"), "Team 0 garage card names the Mercedes-AMG and points at its full GLB")
	for slot: int in range(20):
		var texture: Texture2D = load(roster.portrait_path(slot))
		check(texture != null and texture.get_width() == 1024 and texture.get_height() == 1024, "Driver %02d has the original sharp radio portrait" % (slot + 1))
	garage.select_team(8)
	check(is_equal_approx(garage._driver_bars[0][2].value, 0.96), "Bento Tanaka's wet mastery retains its canonical 96 percent rating")
	garage.select_compound(0, 0)
	garage.select_compound(1, 4)
	check(draft.selected_team_id == 8 and draft.car1_starting_compound == 0 and draft.car2_starting_compound == 4, "Team Principal tire selectors never overwrite the other teammate")
	garage.select_compound(0, 3)
	check(draft.car2_starting_compound == 4, "Changing car one again preserves car two's wet strategy")
	garage.launch()
	await scene_changed
	var started: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - started < 30000:
		await process_frame
		if current_scene != null and current_scene.name == "RaceWeekendWorld" and not current_scene.pre_grid_hold:
			break
	var world: Node = current_scene
	if world == null or world.name != "RaceWeekendWorld":
		check(false, "Manga transition transfers current-scene ownership to the race")
		return
	check(not world.pre_grid_hold and world.race.player_team_id == 8 and world.race.laps == 10, "Animated launch reaches the selected team's configured live race")
	check(world.race.get_car(16).compound == 3 and world.race.get_car(17).compound == 4, "Transition preserves independent tires into actual race actors")
	var race_ref: WeakRef = weakref(world)
	world.show_podium()
	await scene_changed
	await process_frame
	check(race_ref.get_ref() == null and current_scene.scene_file_path == "res://scenes/ui/winning_scene.tscn",
		"Dedicated winning scene owns the viewport after freeing the race world")
	current_scene.exit_button.pressed.emit()
	await scene_changed
	await process_frame
	check(_button(current_scene, "EXHIBITION") != null and config_script.current == null,
		"Studio Exit to HQ returns to a clean main menu")
	presentation.halftone = true
	current_scene.queue_free()
	await process_frame


func _halftone_is_off(node: Node) -> bool:
	var found: bool = false
	for control: Node in node.find_children("*", "ColorRect", true, false):
		var material := (control as ColorRect).material as ShaderMaterial
		if material != null and material.shader.resource_path.ends_with("halftone_screentone.gdshader"):
			found = true
			var color: Variant = material.get_shader_parameter("dot_color")
			if not color is Color or color.a != 0.0:
				return false
	return found

func _finish() -> void:
	print("MAIN MENU FLOW: %d assertions, %d FAIL" % [assertions, failures])
	quit(0 if failures == 0 else 1)
