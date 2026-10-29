extends SceneTree

## FASE 12.2 native 1080p visual gates for the cel-shaded Neo-Wangan ambience (needs a GPU, not --headless):
##   godot --path . --resolution 1920x1080 --script res://scratch/capture_phase12_2_views.gd
## Six camera angles, each a gate for part of the sky/wind/toon upgrade, written to
## executor-report/screenshots/phases/phase-12-2-<label>.png. Phase 12.1's captures stay untouched.
const WorldScene := preload("res://scenes/race_weekend_world.tscn")
const Config := preload("res://scripts/core/race_config_data.gd")
const Settings := preload("res://scripts/core/presentation_settings.gd")
const SHOTS := "res://executor-report/screenshots/phases/"
const WIND_KPH: float = 30.0
var world: Node3D
var camera: Camera3D
var failures: int = 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	DisplayServer.window_set_size(Vector2i(1920, 1080))
	root.size = Vector2i(1920, 1080)
	Settings.set_quality(Settings.Quality.HIGH)
	var config := Config.get_config()
	config.selected_circuit_id = "neo_wangan"
	config.total_laps = 3
	config.time_of_day = 2
	config.weather_preset = 0
	config.race_seed = 12022026
	world = WorldScene.instantiate()
	root.add_child(world)
	world.set_process(false)
	world.set_process(false)
	world.hud.hide()
	world.gantry.set_lights(5)
	world.race.weather.wind_speed = WIND_KPH
	camera = Camera3D.new()
	camera.fov = 68.0
	camera.far = 4500.0
	root.add_child(camera)
	camera.make_current()
	# Several seconds of simulated environment time so clouds, banners and water have moved.
	for step: int in range(40):
		world.environment.update(0.25, world.race)
	for index: int in range(60):
		await process_frame
	var moon: Vector3 = world.environment.moon_instance.global_position
	await _view("cam1-start-paddock", 3060.0, 8.0, 12.0, 3190.0, -5.0, 38.0)
	await _view("cam2-shuto-bridge", 290.0, -38.0, 23.0, 480.0, 0.0, 40.0)
	await _view("cam3-tunnel-chicane", 1038.0, -2.0, 7.5, 1110.0, 0.0, 7.0)
	await _view("cam4-harbor-hairpin", 1340.0, -65.0, 32.0, 1425.0, -10.0, 30.0)
	# Extra: a lamp-pole banner from a three-quarter angle, to see the free edge flutter.
	var banner_pose: Transform3D = world.environment.wind_banner_instance.multimesh.get_instance_transform(3)
	camera.global_position = banner_pose.origin + banner_pose.basis.z * 9.0 + banner_pose.basis.x * 7.0 + Vector3.UP * 1.0
	camera.look_at(banner_pose.origin)
	await _capture("extra-wind-banners")
	# Sky gate: from the bridge deck, skyline silhouetted under the moon, the star dome and the clouds.
	camera.fov = 70.0
	camera.global_position = world.ribbon.get_point_at_offset(300.0, 0.0).origin + Vector3.UP * 14.0
	camera.look_at(moon + Vector3(0.0, -120.0, 0.0))
	await _capture("cam5-sky-moon-skyline")
	camera.fov = 68.0
	world.race.incidents_enabled = false
	world.finish_grid_intro()
	for tick: int in range(2400):
		world.step(1.0 / 60.0)
	var actor: Node3D = world.actor_of(world.followed_id)
	camera.global_position = actor.global_position + actor.global_basis.z * 9.0 + Vector3.UP * 3.6
	camera.look_at(actor.global_position - actor.global_basis.z * 18.0 + Vector3.UP * 3.0)
	camera.make_current()
	await _capture("cam6-chase-cam-action")
	print("CAMERA_GATES cars=%d environment=%s" % [world.actors.size(), world.environment.stats()])
	world.queue_free()
	camera.queue_free()
	await process_frame
	await process_frame
	quit(0 if failures == 0 else 1)


func _view(label: String, s: float, lateral: float, height: float, target_s: float, target_lateral: float, target_height: float) -> void:
	camera.global_position = world.ribbon.get_point_at_offset(s, lateral).origin + Vector3.UP * height
	camera.look_at(world.ribbon.get_point_at_offset(target_s, target_lateral).origin + Vector3.UP * target_height)
	await _capture(label)


func _capture(label: String) -> void:
	for frame: int in range(12):
		await process_frame
	await RenderingServer.frame_post_draw
	var screenshot: Image = root.get_texture().get_image()
	var path: String = SHOTS + "phase-12-2-" + label + ".png"
	var error: Error = screenshot.save_png(path)
	if error != OK or screenshot.get_size() != Vector2i(1920, 1080):
		failures += 1
	# The 160 draw call / 320 000 triangle budget is the environment's: measure with cars and VFX hidden.
	world.get_node("Actors").hide()
	world.choreographer.hide()
	world.vfx.hide()
	for frame: int in range(6):
		await process_frame
	var viewport: RID = root.get_viewport_rid()
	var calls: int = RenderingServer.viewport_get_render_info(viewport, RenderingServer.VIEWPORT_RENDER_INFO_TYPE_VISIBLE, RenderingServer.VIEWPORT_RENDER_INFO_DRAW_CALLS_IN_FRAME)
	var triangles: int = RenderingServer.viewport_get_render_info(viewport, RenderingServer.VIEWPORT_RENDER_INFO_TYPE_VISIBLE, RenderingServer.VIEWPORT_RENDER_INFO_PRIMITIVES_IN_FRAME)
	print("CAMERA_GATE %s size=%s error=%d visible_3d_draw_calls=%d visible_3d_tris=%d" % [label, screenshot.get_size(), error, calls, triangles])
	if calls > 160 or triangles > 320000:
		failures += 1
	world.get_node("Actors").show()
	world.choreographer.show()
	world.vfx.show()
