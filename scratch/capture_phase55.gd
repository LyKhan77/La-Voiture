extends SceneTree

## Report screenshots of the race weekend world. Needs a GPU (not --headless):
##   Godot --path . --resolution 1920x1080 --script res://scratch/capture_phase55.gd -- <track|lights|pit|all> [out_dir]

const WorldScene := preload("res://scenes/race_weekend_world.tscn")
const DirectorScript := preload("res://scripts/world/weekend/race_weekend_director.gd")
const Types := preload("res://scripts/gt/gt_types.gd")

const FRAME: float = 1.0 / 60.0

var world: Node3D
var out_dir: String = "res://scratch"


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var which: String = args[0] if args.size() > 0 else "all"
	if args.size() > 1:
		out_dir = args[1]
	world = WorldScene.instantiate()
	root.add_child(world)
	world.set_physics_process(false)
	await process_frame
	if which == "lights" or which == "all":
		await _lights()
	if which == "track" or which == "all":
		await _track()
	if which == "pit" or which == "all":
		await _pit()
	if which == "rain":
		await _rain()
	if which == "launch":
		await _launch()
	if which == "hud":
		await _hud()
	quit()


func _save(name: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	var image: Image = root.get_texture().get_image()
	var path: String = "%s/%s" % [out_dir, name]
	print("saved ", path, " err=", image.save_png(path), " size=", image.get_size())


func _lights() -> void:
	var director = world.director
	while director.lights_on() < 5:
		world.step(FRAME)
	var ribbon = world.ribbon
	var eye: Transform3D = ribbon.get_point_at_offset(-46.0, 1.0)
	world.camera_director.set_process(false)
	world.camera.fov = 52.0
	world.camera.global_position = eye.origin + Vector3.UP * 4.6
	world.camera.look_at(ribbon.get_point_at_offset(4.0, 0.0).origin + Vector3.UP * 5.6, Vector3.UP)
	await _save("phase-5.5-start-lights.png")


func _track() -> void:
	var race = world.race
	var env = world.environment
	var kerb: Dictionary = env.kerbs[0]
	var corner_s: float = float(kerb["s0"]) + (float(kerb["s1"]) - float(kerb["s0"])) * 0.35
	race.incidents_enabled = false
	for index in range(race.cars.size()):
		var car = race.cars[index]
		car.s = corner_s - 30.0 - 8.0 * float(index)
		car.prev_s = car.s
		car.v = 40.0
		car.lateral = [0.0, 2.4, -2.4][index % 3]
		car.prev_lateral = car.lateral
		car.target_lateral = car.lateral
		car.lap = 1
	world.director._enter(DirectorScript.State.GREEN_RACING)
	for _i in range(150):
		world.step(FRAME)
	world.camera_director.set_process(false)
	var lead = world.actors[0]
	var ribbon = world.ribbon
	var s: float = lead.track_distance_m()
	var side: float = float(kerb["side"])
	var eye: Transform3D = ribbon.get_point_at_offset(s - 22.0, side * 9.0)
	world.camera.fov = 58.0
	world.camera.near = 0.1
	world.camera.global_position = eye.origin + Vector3.UP * 1.3
	world.camera.look_at(ribbon.get_point_at_offset(s + 6.0, side * 0.5).origin + Vector3.UP * 0.6, Vector3.UP)
	await _save("phase-5.5-race-track.png")


func _pit() -> void:
	var race = world.race
	race.incidents_enabled = false
	var car = race.cars[0]
	for other in race.cars:
		if other != car:
			other.s = -600.0 - 20.0 * float(other.id)
			other.prev_s = other.s
	car.s = 3650.0
	car.prev_s = car.s
	car.v = 40.0
	car.lateral = 0.0
	car.prev_lateral = 0.0
	car.lap = 1
	world.director._enter(DirectorScript.State.GREEN_RACING)
	world.followed_id = car.id
	world.camera_director.set_process(false)
	world.camera_director.set_mode(world.camera_director.Mode.CHASE)
	world.request_pit(car.id, Types.Compound.WET)
	var guard: int = 0
	var shot: bool = false
	while guard < 60 * 120 and not shot:
		world.step(FRAME)
		guard += 1
		if car.pit != null and car.pit.phase == Types.PitPhase.BOX and car.v < 0.8 and car.pit.wheel_swap_progress > 0.35:
			shot = true
	await _save("phase-5.5-pitstop-action.png")


func _rain() -> void:
	var race = world.race
	race.incidents_enabled = false
	race.weather.rain_intensity = 0.85
	race.weather.track_water_pct = 80.0
	race.weather.cloud_cover = 1.0
	race.weather.base_air_temp = 16.0
	for car in race.cars:
		car.compound = Types.Compound.WET
	world.director._enter(DirectorScript.State.GREEN_RACING)
	world.set_time_scale(4.0)
	for _i in range(60 * 14):
		world.step(FRAME)
		race.weather.rain_intensity = 0.85
		race.weather.track_water_pct = 80.0
	world.set_time_scale(1.0)
	for _i in range(40):
		world.step(FRAME)
		race.weather.rain_intensity = 0.85
		race.weather.track_water_pct = 80.0
	await _save("phase-5.7-rain.png")


func _launch() -> void:
	var director = world.director
	while director.state != DirectorScript.State.GREEN_RACING:
		world.step(FRAME)
	for _i in range(50):
		world.step(FRAME)
	await _save("phase-5.7-launch.png")


func _hud() -> void:
	var race = world.race
	race.incidents_enabled = false
	world.director._enter(DirectorScript.State.GREEN_RACING)
	world.set_time_scale(4.0)
	for _i in range(60 * 22):
		world.step(FRAME)
	world.set_time_scale(1.0)
	var mine = race.cars.filter(func(c): return c.team_id == race.player_team_id)
	world.followed_id = mine[0].id
	world.camera_director.set_mode(world.camera_director.Mode.CHASE)
	race.suggest_tactic(mine[0], Types.TacticType.PIT, Types.Compound.HARD, "BOX FOR HARD", "Tyre wear rising. Suggest box this lap for hard tyres.")
	for _i in range(40):
		world.step(FRAME)
	world.hud.refresh_all()
	await _save("phase-5.8-hud.png")
	world.hud.handle_key(KEY_H)
	for car in race.cars:
		world.vfx.ping_tip(car.id)
	for _i in range(30):
		world.step(FRAME)
	await _save("phase-5.8-tips.png")
