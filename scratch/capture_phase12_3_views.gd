extends SceneTree

## FASE 12.3 native 1080p visual gates for the shared cel skybox (needs a GPU, not --headless):
##   godot --path . --resolution 1920x1080 --script res://scratch/capture_phase12_3_views.gd
## Neo-Wangan in DAY / SUNSET / NIGHT plus the Apex Ring with the same SharedCelSkyController, written to
## executor-report/screenshots/phases/phase-12-3-<label>.png. Earlier phases' captures stay untouched.
const WorldScene := preload("res://scenes/race_weekend_world.tscn")
const Config := preload("res://scripts/core/race_config_data.gd")
const Settings := preload("res://scripts/core/presentation_settings.gd")
const SHOTS := "res://executor-report/screenshots/phases/"
const WIND_KPH: float = 22.0
var world: Node3D
var camera: Camera3D
var failures: int = 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	DisplayServer.window_set_size(Vector2i(1920, 1080))
	root.size = Vector2i(1920, 1080)
	Settings.set_quality(Settings.Quality.HIGH)
	camera = Camera3D.new()
	camera.far = 4500.0
	root.add_child(camera)

	# Day: the Shuto Bay Bridge under a high sun.
	await _load_world("neo_wangan", 0)
	await _view("wangan-day-bridge", 290.0, -38.0, 23.0, 480.0, 0.0, 40.0, 68.0)
	_unload_world()

	# Sunset and night: from the bridge deck, skyline silhouetted under the sun / moon disc.
	await _load_world("neo_wangan", 1)
	await _sky_view("wangan-sunset-skyline", 120.0, -20.0)
	_unload_world()

	await _load_world("neo_wangan", 2)
	await _sky_view("wangan-night-skyline", 300.0)
	_unload_world()

	# Apex Ring: the same sky over the mountain vista, looking out from the start straight.
	await _load_world("apex_ring", 0)
	await _sky_view("apex-ring-cel-sky", 40.0)
	_unload_world()

	camera.queue_free()
	await process_frame
	quit(0 if failures == 0 else 1)


func _load_world(circuit_id: String, time_of_day: int) -> void:
	var config := Config.get_config()
	config.selected_circuit_id = circuit_id
	config.total_laps = 3
	config.time_of_day = time_of_day
	config.weather_preset = 0
	config.race_seed = 12032026
	world = WorldScene.instantiate()
	root.add_child(world)
	world.set_process(false)
	world.set_process(false)
	world.hud.hide()
	world.gantry.set_lights(5)
	world.race.weather.wind_speed = WIND_KPH
	camera.make_current()
	# Several seconds of simulated environment time so clouds, banners and water have moved.
	for step: int in range(40):
		world.environment.update(0.25, world.race)
	for index: int in range(60):
		await process_frame


func _unload_world() -> void:
	world.queue_free()
	world = null


## Looks from the track at the sun/moon disc, with the skyline or mountains and clouds around it.
func _sky_view(label: String, s: float, drop_m: float = 120.0) -> void:
	var disc: Vector3 = world.environment.sky_controller.moon_instance.global_position
	camera.fov = 70.0
	camera.global_position = world.ribbon.get_point_at_offset(s, 0.0).origin + Vector3.UP * 14.0
	camera.look_at(disc + Vector3(0.0, -drop_m, 0.0))
	await _capture(label)


func _view(label: String, s: float, lateral: float, height: float, target_s: float, target_lateral: float, target_height: float, fov: float) -> void:
	camera.fov = fov
	camera.global_position = world.ribbon.get_point_at_offset(s, lateral).origin + Vector3.UP * height
	camera.look_at(world.ribbon.get_point_at_offset(target_s, target_lateral).origin + Vector3.UP * target_height)
	await _capture(label)


func _capture(label: String) -> void:
	for frame: int in range(12):
		await process_frame
	await RenderingServer.frame_post_draw
	var screenshot: Image = root.get_texture().get_image()
	var path: String = SHOTS + "phase-12-3-" + label + ".png"
	var error: Error = screenshot.save_png(path)
	if error != OK or screenshot.get_size() != Vector2i(1920, 1080):
		failures += 1
	var viewport: RID = root.get_viewport_rid()
	var calls: int = RenderingServer.viewport_get_render_info(viewport, RenderingServer.VIEWPORT_RENDER_INFO_TYPE_VISIBLE, RenderingServer.VIEWPORT_RENDER_INFO_DRAW_CALLS_IN_FRAME)
	var triangles: int = RenderingServer.viewport_get_render_info(viewport, RenderingServer.VIEWPORT_RENDER_INFO_TYPE_VISIBLE, RenderingServer.VIEWPORT_RENDER_INFO_PRIMITIVES_IN_FRAME)
	print("CAMERA_GATE %s size=%s error=%d visible_3d_draw_calls=%d visible_3d_tris=%d" % [label, screenshot.get_size(), error, calls, triangles])
