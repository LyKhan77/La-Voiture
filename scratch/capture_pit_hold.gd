extends SceneTree

## Native 1080p stills of a serviced car held in its box for the lane (PitstopChoreographer.Phase.HOLD): the real sim runs
## six cars into the lane, the first one that has to wait is frozen, and the crew and the red board are photographed.
## Run: godot --path . --resolution 1920x1080 -s scratch/capture_pit_hold.gd -- <circuit> [out dir]
## Refuses to overwrite an existing file.

const WorldScene := preload("res://scenes/race_weekend_world.tscn")
const Config := preload("res://scripts/core/race_config_data.gd")
const Settings := preload("res://scripts/core/presentation_settings.gd")
const Types := preload("res://scripts/gt/gt_types.gd")
const PIT_CALLERS: Array[int] = [0, 3, 6, 9, 12, 15]
const GUARD_FRAMES: int = 12000

var world: RaceWeekendWorld
var camera: Camera3D
var out_dir: String = "res://executor-report/screenshots/phases"
var circuit: String = "apex_ring"
var failures: int = 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() > 0:
		circuit = args[0]
	if args.size() > 1:
		out_dir = args[1]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out_dir))
	Settings.set_quality(Settings.Quality.HIGH)
	var config: RaceConfigData = Config.reset()
	config.selected_circuit_id = circuit
	config.total_laps = 6
	config.weather_preset = 0
	config.time_of_day = 0
	config.race_seed = 19220903
	world = WorldScene.instantiate()
	world.race_config = config
	root.add_child(world)
	world.finish_grid_intro()
	for _i: int in range(150):
		await process_frame
	for index: int in PIT_CALLERS:
		world.race.request_pit(world.race.cars[index].id, 1)
	world.set_time_scale(8.0)
	var held: GtCar = null
	var frames: int = 0
	while held == null and frames < GUARD_FRAMES:
		await process_frame
		frames += 1
		for car: GtCar in world.race.cars:
			var job: PitstopChoreographer.Job = world.choreographer.get_job(car.id)
			if car.pit != null and car.pit.holding_release and job != null and job.phase == PitstopChoreographer.Phase.HOLD and car.pit.release_wait_s > 0.5:
				held = car
				break
	if held == null:
		printerr("No car was ever held in its box")
		quit(1)
		return
	# Freeze the world on the held car: the crew keeps its pose, the animation players keep breathing.
	world.set_process(false)
	world.hud.set_shown(false)
	world.set_time_scale(1.0)
	var job: PitstopChoreographer.Job = world.choreographer.get_job(held.id)
	var disc := job.lollipop_disc.material_override as StandardMaterial3D
	print("HELD car=%d team=%d phase=%d wait=%.1fs board_rot_x=%.0fdeg board=%s" % [held.id, held.team_id, job.phase, held.pit.release_wait_s,
		rad_to_deg((job.lollipop.get_node("Pole") as Node3D).rotation.x), disc.albedo_color.to_html(false)])
	camera = Camera3D.new()
	camera.near = 0.05
	camera.fov = 52.0
	world.add_child(camera)
	camera.make_current()
	# The last gun sparks fade within a second; the held crew itself does not move.
	for _i: int in range(90):
		await process_frame
	var crew_root: Node3D = job.crew
	var focus: Vector3 = crew_root.global_position + Vector3.UP * 0.6
	camera.global_position = focus + crew_root.global_basis * Vector3(-6.5, 4.2, -3.0)
	camera.look_at(focus)
	await _save("phase-14-5-pit-hold-%s-wide" % circuit)
	var board: Vector3 = job.lollipop.global_position + Vector3.UP * 1.0
	camera.fov = 45.0
	camera.global_position = board + crew_root.global_basis * Vector3(-2.6, 0.6, -2.2)
	camera.look_at(board)
	await _save("phase-14-5-pit-hold-%s-board" % circuit)
	world.race.dispose()
	world.queue_free()
	for _i: int in range(3):
		await process_frame
	quit(1 if failures > 0 else 0)


func _save(shot: String) -> void:
	for _frame: int in range(20):
		await process_frame
	await RenderingServer.frame_post_draw
	var image: Image = root.get_texture().get_image()
	var path: String = "%s/%s.png" % [out_dir, shot]
	if image.get_size() != Vector2i(1920, 1080):
		printerr("Capture must be 1920x1080, got ", image.get_size())
		failures += 1
		return
	if FileAccess.file_exists(path):
		printerr("Refusing to overwrite existing evidence: ", path)
		failures += 1
		return
	var error: Error = image.save_png(ProjectSettings.globalize_path(path))
	if error != OK:
		failures += 1
	print("SHOT ", path, " error=", error)
