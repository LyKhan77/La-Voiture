extends SceneTree

## Native 1080p evidence staging of the real world, actors and choreographer (not a race replay).
## Run: godot --path . --fullscreen --resolution 1920x1080 -s scratch/capture_pitcrew_visual.gd
## Optional first user argument redirects previews to temp/. No HUD layout or asset is modified.
const WorldScene := preload("res://scenes/race_weekend_world.tscn")
const Config := preload("res://scripts/core/race_config_data.gd")
const Settings := preload("res://scripts/core/presentation_settings.gd")
const FRAME: float = 1.0 / 60.0
var world: RaceWeekendWorld
var camera: Camera3D
var out_dir: String = "res://executor-report/screenshots/pitcrew"
var actor: GtCarActor
var failures: int = 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if not args.is_empty():
		out_dir = args[0]
	var directory_error: Error = DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out_dir))
	if directory_error != OK and directory_error != ERR_ALREADY_EXISTS:
		printerr("Cannot create capture directory: ", directory_error)
		quit(1)
		return
	Settings.set_quality(Settings.Quality.HIGH)
	var config: RaceConfigData = Config.reset()
	config.total_laps = 3
	config.weather_preset = 0
	config.time_of_day = 0
	world = WorldScene.instantiate()
	world.race_config = config
	root.add_child(world)
	world.set_process(false)
	world.hud.set_shown(false)
	actor = world.actor_of(0)
	actor.global_transform = world.pit_lane.stall_transform(0)
	camera = Camera3D.new()
	camera.near = 0.05
	camera.fov = 48.0
	world.add_child(camera)
	camera.make_current()
	await process_frame
	print("GPU: ", RenderingServer.get_video_adapter_name(), " viewport: ", root.size)

	# Two representative gunners retain the real per-team materials and idle animation.
	world.choreographer._ensure_ready(0)
	world.choreographer._ensure_ready(2)
	var a: PitstopChoreographer.Crew = world.choreographer._crews[0]
	var b: PitstopChoreographer.Crew = world.choreographer._crews[2]
	var representative_a: Node3D = a.root.get_node("Gunner0")
	var representative_b: Node3D = b.root.get_node("Gunner0")
	b.root.global_transform = a.root.global_transform * Transform3D(Basis.IDENTITY, Vector3(0.0, 0.0, 2.0))
	for crew: PitstopChoreographer.Crew in [a, b]:
		for member: PitstopChoreographer.Member in crew.members:
			member.node.visible = member.node.name == &"Gunner0"
	var focus: Vector3 = (representative_a.global_position + representative_b.global_position) * 0.5 + Vector3.UP * 0.85
	actor.visible = false
	camera.global_position = focus + a.root.global_basis * Vector3(3.5, 0.3, 0.2)
	camera.look_at(focus)
	await _save("pitcrew_team_uniform_variations")
	actor.visible = true
	for crew: PitstopChoreographer.Crew in [a, b]:
		for member: PitstopChoreographer.Member in crew.members:
			member.node.visible = true
	b.root.global_transform = world.pit_lane.stall_transform(2)
	world.choreographer.set_ready_teams([0])

	# Wheel-on service for the close-up; the actual presentation API owns every pose/prop.
	await _settle(0.12)
	var job: PitstopChoreographer.Job = world.choreographer.get_job(0)
	var corner: int = 0
	var best: float = INF
	for i: int in range(4):
		var local: Vector3 = job.crew.to_local(job.chassis._wheel_sockets[i].global_position)
		var score: float = local.x + local.z
		if score < best:
			best = score
			corner = i
	var socket: Marker3D = job.chassis._wheel_sockets[corner]
	focus = (socket.global_position + job.crew_members[corner].global_position) * 0.5 + Vector3.UP * 0.30
	camera.global_position = focus + job.crew.global_basis * Vector3(-1.9, 0.9, -1.9)
	camera.look_at(focus)
	await _save("pitstop_gunner_wheel_service")

	await _settle(0.30)
	focus = job.crew.global_position + Vector3.UP * 0.6 + job.crew.global_basis * Vector3(0.0, 0.0, -0.7)
	camera.fov = 52.0
	camera.global_position = focus + job.crew.global_basis * Vector3(-6.5, 4.2, -3.0)
	camera.look_at(focus)
	print("SERVICE: phase=", job.phase, " lift=", job.chassis.position.y, " crew=", a.members.size(), " carried=", job.carried)
	await _save("pitstop_full_crew_action")
	world.choreographer.present(0, 0, actor, 0, false, 1.0, 0.0)
	world.race.dispose()
	world.queue_free()
	for i: int in range(3):
		await process_frame
	quit(1 if failures > 0 else 0)

func _settle(progress: float) -> void:
	for frame: int in range(45):
		world.choreographer.advance(FRAME)
		world.choreographer.present(0, 0, actor, 0, true, progress, 0.15)
		await process_frame

func _save(name: String) -> void:
	for frame: int in range(15):
		await process_frame
	await RenderingServer.frame_post_draw
	var image: Image = root.get_texture().get_image()
	var path: String = "%s/%s.png" % [out_dir, name]
	if image.get_size() != Vector2i(1920, 1080):
		printerr("Capture must be 1920x1080, got ", image.get_size())
		failures += 1
		return
	if OS.get_cmdline_user_args().is_empty() and FileAccess.file_exists(path):
		printerr("Refusing to overwrite existing evidence: ", path)
		failures += 1
		return
	var error: Error = image.save_png(ProjectSettings.globalize_path(path))
	if error != OK:
		failures += 1
	print("SHOT ", path, " 1920x1080 error=", error)
