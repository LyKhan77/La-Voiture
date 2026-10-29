extends SceneTree

## Native 1080p visual gates. Uses the real twenty-car weekend and authored circuit spans.
const WorldScene := preload("res://scenes/race_weekend_world.tscn")
const Config := preload("res://scripts/core/race_config_data.gd")
const PitKit := preload("res://scripts/world/circuits/neo_wangan/neo_wangan_pit_complex.gd")
const Settings := preload("res://scripts/core/presentation_settings.gd")
const SHOTS := "res://executor-report/screenshots/phases/"
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
	world.environment.update(0.5, world.race)
	camera = Camera3D.new()
	camera.fov = 68.0
	camera.far = 4500.0
	root.add_child(camera)
	camera.make_current()
	for index: int in range(60):
		await process_frame
	await _view("cam1-start-paddock", 3060.0, 8.0, 12.0, 3190.0, -5.0, 7.0)
	await _view("cam2-shuto-bridge", 290.0, -38.0, 23.0, 480.0, 0.0, 23.0)
	await _view("cam3-tunnel-chicane", 1038.0, -2.0, 7.5, 1110.0, 0.0, 7.0)
	await _view("cam4-harbor-hairpin", 1340.0, -65.0, 32.0, 1425.0, -10.0, 5.0)
	var bounds := AABB()
	for s: int in range(0, 3150, 10):
		bounds = bounds.expand(world.ribbon.get_point_at_offset(float(s), 0.0).origin)
	var centre: Vector3 = bounds.get_center()
	camera.fov = 55.0
	camera.global_position = centre + Vector3(100.0, 720.0, 340.0)
	camera.look_at(centre)
	await _capture("cam5-aerial-overview")
	camera.fov = 68.0
	# Advance simulation and presentation together to a live street-canyon pack.
	world.race.incidents_enabled = false
	world.finish_grid_intro()
	for tick: int in range(2400):
		world.step(1.0 / 60.0)
	var actor: Node3D = world.actor_of(world.followed_id)
	camera.global_position = actor.global_position + actor.global_basis.z * 9.0 + Vector3.UP * 3.6
	camera.look_at(actor.global_position - actor.global_basis.z * 18.0 + Vector3.UP)
	camera.make_current()
	await _capture("cam6-chase-cam-action")
	root.canvas_cull_mask = 0
	await _view("pit-entry-runup", PitKit.ENTRY_S - 18.0, 14.0, 8.5, PitKit.ENTRY_S + 90.0, 11.0, 1.2)
	var first_car: GtCar = world.race.cars[0]
	for car: GtCar in world.race.cars:
		if world.race.stall_index_for_team(car.team_id) == 0:
			first_car = car
			break
	var requested: bool = world.request_pit(first_car.id)
	var service: bool = false
	for frame: int in range(9000):
		world.step(1.0 / 60.0)
		if first_car.pit != null and first_car.pit.phase == GtTypes.PitPhase.BOX and first_car.v < 0.8 and first_car.pit.timer > 0.0:
			service = true
			break
	print("PIT_POLISH_SERVICE requested=%s servicing=%s team=%d stall=%d car=%d" % [requested, service, first_car.team_id, world.race.stall_index_for_team(first_car.team_id), first_car.id])
	if not requested or not service:
		failures += 1
	camera.make_current()
	await _view("pit-garage-lighting", PitKit.s_from_u(PitKit.STALL_FIRST_OFFSET_M - 9.0), 9.8, 3.0, PitKit.s_from_u(PitKit.STALL_FIRST_OFFSET_M + 18.0), 19.0, 2.1)
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
	var path: String = SHOTS + "phase-12-1-" + label + ".png"
	var error: Error = screenshot.save_png(path)
	if error != OK or screenshot.get_size() != Vector2i(1920, 1080):
		failures += 1
	print("CAMERA_GATE %s size=%s error=%d draw_calls=%d tris=%d" % [label, screenshot.get_size(), error, int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)), int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))])
	world.get_node("Actors").hide()
	world.choreographer.hide()
	world.vfx.hide()
	for frame: int in range(6):
		await process_frame
	var viewport: RID = root.get_viewport_rid()
	var calls: int = RenderingServer.viewport_get_render_info(viewport, RenderingServer.VIEWPORT_RENDER_INFO_TYPE_VISIBLE, RenderingServer.VIEWPORT_RENDER_INFO_DRAW_CALLS_IN_FRAME)
	var triangles: int = RenderingServer.viewport_get_render_info(viewport, RenderingServer.VIEWPORT_RENDER_INFO_TYPE_VISIBLE, RenderingServer.VIEWPORT_RENDER_INFO_PRIMITIVES_IN_FRAME)
	print("CAMERA_ENVIRONMENT %s visible_3d_draw_calls=%d visible_3d_tris=%d shadow_draw_calls=%d canvas_draw_calls=%d" % [label, calls, triangles, RenderingServer.viewport_get_render_info(viewport, RenderingServer.VIEWPORT_RENDER_INFO_TYPE_SHADOW, RenderingServer.VIEWPORT_RENDER_INFO_DRAW_CALLS_IN_FRAME), RenderingServer.viewport_get_render_info(viewport, RenderingServer.VIEWPORT_RENDER_INFO_TYPE_CANVAS, RenderingServer.VIEWPORT_RENDER_INFO_DRAW_CALLS_IN_FRAME)])
	if calls > 160 or triangles > 320000:
		failures += 1
	world.get_node("Actors").show()
	world.choreographer.show()
	world.vfx.show()
