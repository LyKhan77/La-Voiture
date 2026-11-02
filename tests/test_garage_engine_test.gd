extends SceneTree

const GarageScene := preload("res://scenes/ui/garage_team_select.tscn")
const Config := preload("res://scripts/core/race_config_data.gd")

var failures: int = 0
var assertions: int = 0

func _initialize() -> void:
	call_deferred("_run")

func check(ok: bool, message: String) -> void:
	assertions += 1
	if not ok:
		failures += 1
	print("[%s] %s" % ["PASS" if ok else "FAIL", message])

func key(garage: GarageTeamSelect, pressed: bool, echo: bool = false) -> void:
	var event := InputEventKey.new()
	event.keycode = KEY_W
	event.physical_keycode = KEY_W
	event.pressed = pressed
	event.echo = echo
	garage._input(event)

func advance(garage: GarageTeamSelect, seconds: float, fps: int = 120) -> void:
	for frame: int in range(roundi(seconds * fps)):
		garage.call("_process", 1.0 / fps)

func stopped(garage: GarageTeamSelect) -> bool:
	var player: AudioStreamPlayer = garage.get("_engine_player") as AudioStreamPlayer
	return not bool(garage.get("_rev_active")) and not player.playing and player.volume_db <= -79.0

func _run() -> void:
	await process_frame
	var config: Config = Config.get_config()
	var original_team: int = config.selected_team_id
	var original_compound: int = config.car1_starting_compound
	config.selected_team_id = 0
	var garage: GarageTeamSelect = GarageScene.instantiate() as GarageTeamSelect
	root.add_child(garage)
	garage.set_process(false)
	key(garage, true)
	var player: AudioStreamPlayer = garage.get("_engine_player") as AudioStreamPlayer
	check(player != null and player.stream == EngineProfile.for_team(0).on_stream, "W starts the selected car's engine, not a generic launch sound")
	if player != null:
		_test_rev_curve(garage, player)
		_test_release(garage, player)
		_test_families(garage, player)
		_test_cancellation(garage, player)
	garage.free()
	config.selected_team_id = original_team
	config.car1_starting_compound = original_compound
	await process_frame
	print("GARAGE ENGINE TEST: %d assertions, %d failure(s)" % [assertions, failures])
	call_deferred("quit", 0 if failures == 0 else 1)

func _test_rev_curve(garage: GarageTeamSelect, player: AudioStreamPlayer) -> void:
	var profile: EngineProfile = EngineProfile.for_team(0)
	var idle_pitch: float = player.pitch_scale
	advance(garage, 0.5)
	check(player.pitch_scale > idle_pitch and player.pitch_scale < profile.pitch_for(8500.0), "holding W ramps up rather than jumping straight to redline")
	var half_second: float = player.pitch_scale
	garage.select_team(0)
	key(garage, false)
	key(garage, true)
	advance(garage, 0.5, 60)
	check(is_equal_approx(player.pitch_scale, half_second), "rev acceleration follows elapsed time at 60 and 120 FPS")
	advance(garage, 1.5)
	var low: float = INF
	var high: float = 0.0
	for frame: int in range(24):
		advance(garage, 1.0 / 120.0)
		low = minf(low, player.pitch_scale)
		high = maxf(high, player.pitch_scale)
	check(high <= profile.pitch_for(8500.0) + 0.0001 and low >= profile.pitch_for(7800.0) and high - low > 0.001, "held redline has a bounded limiter pulse instead of climbing indefinitely")

func _test_release(garage: GarageTeamSelect, player: AudioStreamPlayer) -> void:
	var high_pitch: float = player.pitch_scale
	key(garage, false)
	var exhaust: AudioStreamPlayer = garage.get_node_or_null("EngineTestExhaust") as AudioStreamPlayer
	check(exhaust != null and exhaust.stream == EngineAudio3D.UPSHIFT_STREAM, "high-RPM NA release selects one exhaust crack")
	advance(garage, 0.4)
	check(player.pitch_scale < high_pitch and player.volume_db > -79.0, "release audibly descends toward idle before fading out")
	key(garage, false)
	advance(garage, 1.6)
	check(stopped(garage), "release finishes in silence even after a duplicate key-up")
	key(garage, true)
	advance(garage, 0.1)
	key(garage, false)
	exhaust = garage.get_node_or_null("EngineTestExhaust") as AudioStreamPlayer
	check(exhaust == null or exhaust.stream == null, "low-RPM tap does not fire an exhaust crack")
	advance(garage, 1.0)
	check(stopped(garage), "short tap also returns to silence")

func _test_families(garage: GarageTeamSelect, player: AudioStreamPlayer) -> void:
	for team: int in [0, 1, 2, 3, 4, 12]:
		garage.select_team(team)
		key(garage, true)
		advance(garage, 1.5)
		var profile: EngineProfile = EngineProfile.for_team(team)
		check(player.stream == profile.on_stream and player.pitch_scale <= profile.pitch_for(8500.0) + 0.0001, "team %d uses its engine family's loop and rev ceiling" % team)
		key(garage, false)
		var exhaust: AudioStreamPlayer = garage.get_node("EngineTestExhaust") as AudioStreamPlayer
		check(exhaust.stream == (EngineAudio3D.BLOW_OFF_STREAM if profile.turbo else EngineAudio3D.UPSHIFT_STREAM), "team %d releases with the correct NA/turbo one-shot" % team)
		advance(garage, 2.0)

func _test_cancellation(garage: GarageTeamSelect, player: AudioStreamPlayer) -> void:
	key(garage, true)
	advance(garage, 1.0)
	garage.select_team(1)
	key(garage, true, true)
	advance(garage, 0.5)
	check(stopped(garage), "team switch silences the old engine; held-key echoes cannot blip the new team")
	key(garage, false)
	key(garage, true)
	advance(garage, 0.5)
	garage.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	advance(garage, 0.5)
	check(stopped(garage), "focus loss stops the engine even if the key release is never delivered")
	key(garage, false)
	key(garage, true)
	advance(garage, 1.0)
	garage.select_compound(0, GtTypes.Compound.WET)
	garage.launch()
	check(garage._mismatch_modal != null and garage._mismatch_modal.visible and stopped(garage), "mismatch modal cancels the held rev immediately")
	key(garage, true)
	advance(garage, 0.5)
	check(stopped(garage), "W cannot restart the engine behind the mismatch modal")
	garage._hide_mismatch_modal()
	key(garage, false)
	key(garage, true)
	advance(garage, 1.0)
	garage._play_launch_rev()
	advance(garage, 1.0)
	check(not bool(garage.get("_rev_active")) and is_equal_approx(player.pitch_scale, EngineProfile.for_team(1).pitch_for(7500.0)) and is_equal_approx(player.volume_db, -3.0), "launch takes audio ownership; free-rev processing cannot fade or repitch launch audio")
	garage._launching = true
	key(garage, true)
	advance(garage, 0.5)
	check(not bool(garage.get("_rev_active")), "launching blocks fresh engine-test key presses")
