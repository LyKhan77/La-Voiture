extends SceneTree

## Fase 21.3 acceptance: every car sounds like its own engine family. One EngineProfile per
## layout in GarageRoster.CAR_ENGINES (V8 NA, V10 NA, V6 / I6 / V8 twin-turbo) with its own
## on- and off-throttle loops and RPM range; per-car detune and loop offset so a pack of cars
## does not phase into one drone; Doppler; a throttle crossfade; an upshift crack, an overrun
## crackle (NA) or blow-off (turbo) on a lift; a turbo whistle; far cars drop their extra layers.
## Run: Godot --headless --path . -s res://tests/test_engine_audio_profiles.gd

const FAMILIES: Array[StringName] = [&"v8_na", &"v10_na", &"v6_tt", &"i6_tt", &"v8_tt"]
const SPEED_MPS: float = 60.0

var failures: int = 0
var assertions: int = 0


func _initialize() -> void:
	call_deferred("_run")


func check(ok: bool, description: String) -> void:
	assertions += 1
	if not ok:
		failures += 1
		push_error(description)
	print("[%s] %s" % ["PASS" if ok else "FAIL", description])


func _run() -> void:
	await process_frame
	_test_profiles()
	_test_pitch()
	_test_detune()
	_test_crossfade()
	_test_turbo_layer()
	_test_lift_and_shift()
	_test_voice_budget()
	print("%d assertions, %d failure(s)" % [assertions, failures])
	print("FASE 21.3 ENGINE SFX: %s" % ("PASS" if failures == 0 else "%d FAILURES" % failures))
	quit(0 if failures == 0 else 1)


func _engine(family: StringName, voice_id: int = 0) -> EngineAudio3D:
	var engine := EngineAudio3D.new()
	root.add_child(engine)
	engine.set_voice(EngineProfile.for_family(family), voice_id)
	return engine


## Runs enough frames for the throttle smoothing to settle.
func _hold(engine: EngineAudio3D, rpm: float, throttle: float, near: bool = true, frames: int = 40) -> void:
	for _i: int in range(frames):
		engine.update_engine_audio(rpm, throttle, SPEED_MPS, near)


func _test_profiles() -> void:
	var families: Array[StringName] = []
	var unmapped: Array[String] = []
	for layout: String in GarageRoster.CAR_ENGINES:
		var family: StringName = EngineProfile.family_for_layout(layout)
		if family == &"":
			unmapped.append(layout)
		elif not families.has(family):
			families.append(family)
	check(unmapped.is_empty() and families.size() == 5, "#1 every roster engine layout maps to one of 5 families (%s)%s" % [", ".join(PackedStringArray(families)), "" if unmapped.is_empty() else " unmapped: %s" % unmapped])
	var streams_ok: bool = true
	var on_streams: Array[AudioStream] = []
	for family: StringName in FAMILIES:
		var profile: EngineProfile = EngineProfile.for_family(family)
		streams_ok = streams_ok and profile.on_stream != null and profile.off_stream != null and profile.on_stream.get_length() >= 1.0 and profile.off_stream.get_length() >= 1.0
		if not on_streams.has(profile.on_stream):
			on_streams.append(profile.on_stream)
	check(streams_ok and on_streams.size() == 5, "#2 each family carries its own on- and off-throttle loop (%d distinct on-throttle loops)" % on_streams.size())
	var v10: EngineProfile = EngineProfile.for_team(1) # Audi R8, 5.2L V10
	var v8: EngineProfile = EngineProfile.for_team(0) # Mercedes-AMG, 6.2L V8
	var turbo: EngineProfile = EngineProfile.for_team(2) # Nissan GT-R, V6 twin-turbo
	check(v10.id == &"v10_na" and v8.id == &"v8_na" and turbo.id == &"v6_tt" and turbo.turbo and not v8.turbo and EngineProfile.for_team(-1) != null,
		"#3 a team rides its car's engine family (team 0 %s, team 1 %s, team 2 %s turbo)" % [v8.id, v10.id, turbo.id])


func _test_pitch() -> void:
	var v8: EngineProfile = EngineProfile.for_family(&"v8_na")
	var v10: EngineProfile = EngineProfile.for_family(&"v10_na")
	var rising: bool = true
	var last: float = -1.0
	for rpm: int in range(1200, 9001, 100):
		var pitch: float = v8.pitch_for(float(rpm))
		rising = rising and pitch >= last
		last = pitch
	var in_range: bool = v8.pitch_for(0.0) >= EngineProfile.PITCH_MIN and v8.pitch_for(20000.0) <= EngineProfile.PITCH_MAX
	check(rising and in_range and not is_equal_approx(v8.pitch_for(7000.0), v10.pitch_for(7000.0)),
		"#4 pitch climbs with RPM inside [%.2f, %.2f] and differs per family at one RPM (V8 %.2f, V10 %.2f at 7000)" % [EngineProfile.PITCH_MIN, EngineProfile.PITCH_MAX, v8.pitch_for(7000.0), v10.pitch_for(7000.0)])


func _test_detune() -> void:
	var a: EngineAudio3D = _engine(&"v8_na", 3)
	var b: EngineAudio3D = _engine(&"v8_na", 4)
	var a_again: EngineAudio3D = _engine(&"v8_na", 3)
	_hold(a, 7000.0, 1.0, true, 1)
	_hold(b, 7000.0, 1.0, true, 1)
	_hold(a_again, 7000.0, 1.0, true, 1)
	var base: float = a.profile.pitch_for(7000.0)
	var spread_ok: bool = absf(a.pitch_scale / base - 1.0) <= EngineAudio3D.DETUNE + 0.0001 and absf(b.pitch_scale / base - 1.0) <= EngineAudio3D.DETUNE + 0.0001
	check(not is_equal_approx(a.pitch_scale, b.pitch_scale) and is_equal_approx(a.pitch_scale, a_again.pitch_scale) and spread_ok,
		"#5 two cars on one engine at one RPM are detuned apart (%.3f vs %.3f), within ±%d%%, the same car always the same" % [a.pitch_scale, b.pitch_scale, int(EngineAudio3D.DETUNE * 100.0)])
	check(a.doppler_tracking != AudioStreamPlayer3D.DOPPLER_TRACKING_DISABLED, "#6 the engine voice tracks Doppler")
	for engine: EngineAudio3D in [a, b, a_again]:
		engine.free()


func _test_crossfade() -> void:
	var engine: EngineAudio3D = _engine(&"v8_na")
	_hold(engine, 7000.0, 1.0)
	var on_loud: bool = engine.on_weight() > 0.9 and engine.volume_db > engine.off_layer.volume_db
	_hold(engine, 5000.0, 0.0)
	var off_loud: bool = engine.on_weight() < 0.1 and engine.off_layer.playing and engine.off_layer.volume_db > engine.volume_db
	check(on_loud and off_loud, "#7 the throttle crossfades the on-throttle loop into the overrun loop and back")
	engine.focused = false
	var plain_db: float = engine.volume_db
	engine.focused = true
	_hold(engine, 5000.0, 0.0, true, 1)
	check(is_equal_approx(engine.volume_db - plain_db, EngineAudio3D.FOCUS_DB), "#8 the followed car sits %.0f dB above the pack" % EngineAudio3D.FOCUS_DB)
	engine.free()


func _test_turbo_layer() -> void:
	var turbo: EngineAudio3D = _engine(&"v8_tt")
	var na: EngineAudio3D = _engine(&"v10_na")
	_hold(turbo, 7000.0, 1.0)
	_hold(na, 7000.0, 1.0)
	check(turbo.turbo_layer != null and turbo.turbo_layer.playing and (na.turbo_layer == null or not na.turbo_layer.playing),
		"#9 a twin-turbo engine whistles under load, a naturally aspirated one does not")
	turbo.free()
	na.free()


func _test_lift_and_shift() -> void:
	var na: EngineAudio3D = _engine(&"v8_na")
	_hold(na, 7000.0, 1.0)
	_hold(na, 6000.0, 0.0)
	var na_lift: bool = na.lifts_triggered == 1 and na.one_shot.stream == EngineAudio3D.OVERRUN_STREAM
	_hold(na, 6000.0, 0.0) # still off: no second crackle until the driver is back on the throttle
	var held: bool = na.lifts_triggered == 1
	var turbo: EngineAudio3D = _engine(&"i6_tt")
	_hold(turbo, 7000.0, 1.0)
	_hold(turbo, 6000.0, 0.0)
	check(na_lift and held and turbo.lifts_triggered == 1 and turbo.one_shot.stream == EngineAudio3D.BLOW_OFF_STREAM,
		"#10 a lift at speed crackles the exhaust (NA) or vents the blow-off valve (turbo), once per lift")
	na.on_gear_changed(3)
	na.on_gear_changed(2)
	var after_downshift: int = na.pops_triggered
	na.on_gear_changed(3)
	check(after_downshift == 0 and na.pops_triggered == 1 and na.one_shot.stream == EngineAudio3D.UPSHIFT_STREAM,
		"#11 an upshift cracks the exhaust, a downshift does not")
	na.free()
	turbo.free()


func _test_voice_budget() -> void:
	var engine: EngineAudio3D = _engine(&"v6_tt")
	_hold(engine, 7000.0, 0.5, false)
	_hold(engine, 6000.0, 0.0, false)
	check(engine.playing and not engine.off_layer.playing and not engine.turbo_layer.playing and engine.lifts_triggered == 0,
		"#12 a far car keeps only its main loop: no overrun layer, whistle or one-shots")
	engine.free()
