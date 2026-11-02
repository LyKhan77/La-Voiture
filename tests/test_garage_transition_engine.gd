extends SceneTree

const Garage := preload("res://scripts/ui/garage_team_select.gd")
const TransitionScene := preload("res://scenes/ui/manga_race_transition.tscn")
const Config := preload("res://scripts/core/race_config_data.gd")

var failures: int = 0

func _initialize() -> void:
	call_deferred("_run")

func check(ok: bool, description: String) -> void:
	if not ok:
		failures += 1
	print("[%s] %s" % ["PASS" if ok else "FAIL", description])

func _run() -> void:
	# Keep the world cached while the real intro requests it on its loader thread.
	var world_scene: PackedScene = load(MangaRaceTransition.WORLD_PATH) as PackedScene
	await process_frame
	var config: Config = Config.get_config()
	var previous_team: int = config.selected_team_id
	var garage: Garage = Garage.new()
	for team: int in [0, 1, 2]:
		var profile: EngineProfile = EngineProfile.for_team(team)
		garage.selected_team = team
		garage._play_launch_rev()
		var launch: AudioStreamPlayer = garage.get_node("LaunchRev") as AudioStreamPlayer
		check(launch.stream == profile.on_stream, "team %d launch uses %s loop" % [team, profile.id])
		check(is_equal_approx(launch.pitch_scale, profile.pitch_for(7500.0)) and is_equal_approx(launch.volume_db, -3.0 + profile.on_gain_db), "team %d launch pitch and gain follow profile" % team)
		config.selected_team_id = team
		var transition: MangaRaceTransition = TransitionScene.instantiate() as MangaRaceTransition
		root.add_child(transition)
		transition.set_process(false)
		var roar: AudioStreamPlayer = transition.get_node("EngineRoar") as AudioStreamPlayer
		check(roar.stream == profile.on_stream, "team %d transition uses %s loop" % [team, profile.id])
		var snap: AudioStreamPlayer = transition.get_node_or_null("SnapExhaust") as AudioStreamPlayer
		var expected: AudioStream = EngineAudio3D.BLOW_OFF_STREAM if profile.turbo else EngineAudio3D.UPSHIFT_STREAM
		check(snap != null and snap.stream == expected and transition._state == MangaRaceTransition.State.FLASH, "team %d snap selects %s at negative flash" % [team, "blow-off" if profile.turbo else "crack"])
		transition._process(0.05)
		var flash_pitch: float = roar.pitch_scale
		transition._process(0.06)
		transition._process(0.4)
		check(roar.pitch_scale < flash_pitch and roar.stream == profile.on_stream, "team %d roar decelerates without losing family" % team)
		transition.free()
		# Drain the real transition's threaded load before another intro or engine shutdown.
		while ResourceLoader.load_threaded_get_status(MangaRaceTransition.WORLD_PATH) == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			await process_frame
		if ResourceLoader.load_threaded_get_status(MangaRaceTransition.WORLD_PATH) == ResourceLoader.THREAD_LOAD_LOADED:
			var loaded_world: Resource = ResourceLoader.load_threaded_get(MangaRaceTransition.WORLD_PATH)
	garage.free()
	config.selected_team_id = previous_team
	await process_frame
	print("GARAGE TRANSITION ENGINE: %d failure(s)" % failures)
	quit(0 if failures == 0 else 1)
