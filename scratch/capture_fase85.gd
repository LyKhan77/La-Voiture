extends SceneTree

## FASE 8.5 report screenshots: the street-tag main menu, the paddock showroom, brake lights at night,
## and speedlines + kerb sparks. Needs a GPU (not --headless):
##   godot --path . --resolution 1920x1080 --script res://scratch/capture_fase85.gd -- [out_dir]

const WorldScene := preload("res://scenes/race_weekend_world.tscn")
const DirectorScript := preload("res://scripts/world/weekend/race_weekend_director.gd")
const WeatherScript := preload("res://scripts/gt/gt_weather.gd")
const FRAME: float = 1.0 / 60.0

var out_dir: String = "res://executor-report/screenshots/phases"


func _initialize() -> void:
	call_deferred("_run")


func _shot(name: String) -> void:
	for _i: int in range(6):
		await process_frame
	await RenderingServer.frame_post_draw
	var image: Image = root.get_texture().get_image()
	var path: String = ProjectSettings.globalize_path("%s/fase-8.5-%s.png" % [out_dir, name])
	image.save_png(path)
	print("saved ", path)


func _run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() > 0:
		out_dir = args[0]
	var menu := load("res://scenes/ui/main_menu.tscn").instantiate() as Control
	root.add_child(menu)
	for _i: int in range(20):
		await process_frame
	await _shot("main-menu")
	menu.get("settings_button").mouse_entered.emit()
	await _shot("main-menu-hover")
	menu.queue_free()
	await process_frame

	var world: Node3D = WorldScene.instantiate()
	root.add_child(world)
	world.set_physics_process(false)
	world.race.incidents_enabled = false
	world.director._enter(DirectorScript.State.GREEN_RACING)
	for _i: int in range(240):
		world.step(FRAME)
	var car: GtCar = world.race.get_car(world.followed_id)
	var actor = world.actor_of(world.followed_id)
	world.race.weather.time_of_day = WeatherScript.compute_time_of_day(WeatherScript.TimeOfDay.NIGHT, 0.0)
	for each in world.actors:
		each.car.brake = 1.0
		each.car.v = 40.0
	for _i: int in range(40):
		for each in world.actors:
			each.car.s += 1.2
			each.car.prev_s = each.car.s - 1.2
			each.present(1.0, FRAME)
		world.vfx.update(FRAME)
		world.camera_director.update(FRAME)
	car.brake = 1.0
	world.camera_director.update(FRAME)
	await _shot("race-night-brake-lights")

	# Burnout: graffiti tyre smoke, plus a downshift for the exhaust and wing-tip bursts.
	for each in world.actors:
		each.car.brake = 1.0
		each.car.v = 60.0
		each.car.gear = 5
	for _i: int in range(14):
		for each in world.actors:
			each.car.s += 1.0
			each.car.prev_s = each.car.s - 1.0
			each.present(1.0, FRAME)
		world.vfx.update(FRAME)
		world.camera_director.update(FRAME)
	for each in world.actors:
		each.car.gear = 3
	world.vfx.update(FRAME)
	for _i: int in range(2):
		world.vfx.update(FRAME)
		world.camera_director.update(FRAME)
	await _shot("race-graffiti-smoke-flames")

	world.race.weather.time_of_day = WeatherScript.compute_time_of_day(WeatherScript.TimeOfDay.DAY, 0.0)
	car.brake = 0.0
	car.v = 80.0
	car.lateral = 6.0
	car.ers_mode = GtTypes.ErsMode.OVERTAKE
	for _i: int in range(20):
		world.vfx.update(FRAME)
		world.hud.update(FRAME)
		actor.present(1.0, FRAME)
		world.camera_director.update(FRAME)
		await process_frame
	await _shot("race-speedlines-kerb-sparks")
	world.queue_free()
	quit(0)
