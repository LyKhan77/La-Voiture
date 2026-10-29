extends SceneTree

## FASE 6 acceptance: the five-bus layout with the walkie-talkie chain on Radio, the sound set,
## the RPM / throttle / speed engine voice and its exhaust pop, the lateral-G tyre squeal,
## music ducking around radio transmissions, the tactile UI clicks, the start-light beeps and
## the green buzzer, the pit wheel guns, the podium with the FIA GT3 points table, and the
## earlier suites still passing.
## Numbers in the descriptions (#1..#20) are the TASK-FASE-6 acceptance list.
## Run: Godot --headless --path . -s res://tests/test_audio_and_race_weekend.gd
## Add `-- --skip-legacy` to skip the earlier suites in #20 (they take a few minutes).

const WorldScene := preload("res://scenes/race_weekend_world.tscn")
const Studio := preload("res://scripts/ui/winning_scene.gd")
const DirectorScript := preload("res://scripts/world/weekend/race_weekend_director.gd")
const ActorScript := preload("res://scripts/car/gt_car_actor.gd")
const Types := preload("res://scripts/gt/gt_types.gd")
const ToonMaterialsScript := preload("res://scripts/world/shared/toon_materials.gd")
const WeatherScript := preload("res://scripts/gt/gt_weather.gd")

const FRAME: float = 1.0 / 60.0
const MAX_RACE_TICKS: int = 12000
const ESSENTIAL_AUDIO: Array[String] = [
	"res://assets/audio/ui/click_snap.wav",
	"res://assets/audio/ui/warning_siren.wav",
	"res://assets/audio/ui/start_beep.wav",
	"res://assets/audio/ui/lights_out.wav",
	"res://assets/audio/engine/gt3_engine_loop.wav",
	"res://assets/audio/engine/gearshift_pop.wav",
	"res://assets/audio/sfx/tire_screech.wav",
	"res://assets/audio/sfx/pit_gun.wav",
	"res://assets/audio/sfx/kerb_rumble.wav",
	"res://assets/audio/radio/squelch_in.wav",
	"res://assets/audio/radio/squelch_out.wav",
	"res://assets/audio/music/streetwear_synth.ogg",
]
const LEGACY_SUITES: Array[Dictionary] = [
	{"script": "test_modular_car", "args": []},
	{"script": "test_simulation_verification", "args": []},
	{"script": "test_pit_wall", "args": []},
	{"script": "test_weather_and_ai", "args": []},
	{"script": "test_race_world", "args": ["--fixed-fps", "60"]},
	{"script": "test_gt_sim", "args": []},
	{"script": "test_car_dynamics_vfx", "args": []},
	{"script": "test_race_hud", "args": []},
	{"script": "test_race_weekend_and_physics", "args": [], "user_args": ["--skip-legacy"]},
]

var failures: int = 0
var assertions: int = 0
var skip_legacy: bool = false
var hub: AudioManager
var world: Node3D


func _initialize() -> void:
	skip_legacy = OS.get_cmdline_user_args().has("--skip-legacy")
	call_deferred("_run")


func check(ok: bool, description: String) -> void:
	assertions += 1
	if not ok:
		failures += 1
		push_error(description)
	print("[%s] %s" % ["PASS" if ok else "FAIL", description])


func _run() -> void:
	await process_frame
	hub = AudioManager.of(root)
	await process_frame
	_test_bus_layout()
	_test_audio_files()
	_test_voice_catalog()
	await _test_engine_voice()
	await _test_tire_voice()
	await _test_radio_ducking()
	await _test_world_audio()
	await _test_voice_coverage()
	await _test_podium()
	_test_legacy_suites()
	print("%d assertions, %d failure(s)" % [assertions, failures])
	print("FASE 6 ACCEPTANCE: %s" % ("PASS" if failures == 0 else "%d FAILURES" % failures))
	quit(0 if failures == 0 else 1)


# --- #1..#3 the bus layout -------------------------------------------------------------

func _test_bus_layout() -> void:
	AudioServer.set_bus_layout(load(AudioManager.LAYOUT) as AudioBusLayout)
	var names: Array[String] = []
	for index: int in range(AudioServer.bus_count):
		names.append(String(AudioServer.get_bus_name(index)))
	check(names == ["Master", "Music", "SFX", "UI", "Radio"], "#1 the bus layout holds the five buses Master, Music, SFX, UI and Radio: %s" % ", ".join(PackedStringArray(names)))
	var radio: int = AudioServer.get_bus_index(&"Radio")
	var band := AudioServer.get_bus_effect(radio, 0) as AudioEffectBandPassFilter
	check(band != null and is_equal_approx(band.cutoff_hz, 1850.0) and is_equal_approx(band.resonance, 0.85) and band.db == AudioEffectFilter.FILTER_24DB,
		"#2 the Radio bus carries a band-pass filter at the 1.85 kHz voice centre (resonance 0.85, 24 dB)")
	var distortion := AudioServer.get_bus_effect(radio, 1) as AudioEffectDistortion
	check(distortion != null and distortion.mode == AudioEffectDistortion.MODE_CLIP and is_equal_approx(distortion.drive, 0.28),
		"#3 the Radio bus carries a CLIP distortion with drive 0.28")


# --- #4 the sound set -----------------------------------------------------------------------

func _test_audio_files() -> void:
	var missing: Array[String] = []
	for path: String in ESSENTIAL_AUDIO:
		var stream := load(path) as AudioStream
		if stream == null or stream.get_length() <= 0.0:
			missing.append(path)
	check(missing.is_empty(), "#4 all %d essential audio files exist and load as non-empty streams%s" % [ESSENTIAL_AUDIO.size(), "" if missing.is_empty() else " (bad: %s)" % ", ".join(PackedStringArray(missing))])


# --- #5..#7 the engine ---------------------------------------------------------------------

func _test_engine_voice() -> void:
	var rising: bool = true
	var last: float = -1.0
	for rpm: int in range(1200, 8501, 100):
		var pitch: float = EngineAudio3D.pitch_for(float(rpm))
		rising = rising and pitch > last
		last = pitch
	check(rising and is_equal_approx(EngineAudio3D.pitch_for(1200.0), 0.65) and is_equal_approx(EngineAudio3D.pitch_for(8500.0), 1.85),
		"#5 engine pitch climbs monotonically from 0.65 at 1200 RPM to 1.85 at 8500 RPM")
	var idle_db: float = EngineAudio3D.volume_for(0.0, 0.0)
	var loud_db: float = EngineAudio3D.volume_for(1.0, 76.0)
	check(EngineAudio3D.volume_for(1.0, 40.0) > EngineAudio3D.volume_for(0.5, 40.0) and EngineAudio3D.volume_for(0.5, 40.0) > EngineAudio3D.volume_for(0.0, 40.0)
		and EngineAudio3D.volume_for(0.5, 70.0) > EngineAudio3D.volume_for(0.5, 10.0) and is_equal_approx(idle_db, -18.0) and is_equal_approx(loud_db, 0.0),
		"#6 engine volume rises with the throttle and with the speed (%.1f dB idle to %.1f dB flat out)" % [idle_db, loud_db])
	var engine := EngineAudio3D.new()
	root.add_child(engine)
	engine.update_engine_audio(8500.0, 1.0, 76.0)
	var pitch_ok: bool = is_equal_approx(engine.pitch_scale, 1.85) and is_equal_approx(engine.volume_db, 0.0)
	engine.on_gear_changed(3)
	engine.on_gear_changed(2) # a downshift is no pop
	var after_downshift: int = engine.pops_triggered
	engine.on_gear_changed(3)
	check(pitch_ok and after_downshift == 0 and engine.pops_triggered == 1, "#7 the exhaust pop fires on the upshift signal and not on a downshift (%d pop)" % engine.pops_triggered)
	engine.queue_free()


# --- #8..#9 the tyres ----------------------------------------------------------------------

func _test_tire_voice() -> void:
	var tire := TireAudio3D.new()
	root.add_child(tire)
	tire.update_tire_audio(2.4, false)
	var loud: bool = tire.playing and is_equal_approx(tire.volume_db, -16.8)
	tire.update_tire_audio(-2.4, false) # left-hand corners count the same
	var mirrored: bool = tire.playing
	tire.update_tire_audio(0.4, true) # a locked wheel squeals without lateral load
	var locked: bool = tire.playing
	check(loud and mirrored and locked, "#8 the tyre squeal starts above 1.8 G lateral (either side) or on a locked wheel, at the level %.1f dB" % TireAudio3D.volume_for(2.4))
	tire.update_tire_audio(1.0, false)
	var calm: bool = not tire.playing and not tire.screeching
	tire.update_tire_audio(2.4, false)
	tire.update_tire_audio(1.8, false) # the limit itself is still a calm drive
	check(calm and not tire.playing, "#9 the tyre squeal stays silent on a relaxed drive (1.0 G) and stops at the 1.8 G limit")
	tire.queue_free()


# --- #10..#12 the radio ---------------------------------------------------------------------

func _test_radio_ducking() -> void:
	var director := RadioAudioDirector.new()
	root.add_child(director)
	var music: int = AudioServer.get_bus_index(&"Music")
	var base_db: float = AudioServer.get_bus_volume_db(music)
	var squelches_before: int = hub.count_of(AudioManager.SQUELCH_IN)
	director.start_transmission()
	await create_timer(0.35).timeout
	var ducked_db: float = AudioServer.get_bus_volume_db(music)
	check(base_db - ducked_db >= 7.99, "#10 music ducking drops the Music bus %.1f dB while a radio transmission is live (%.1f to %.1f dB)" % [base_db - ducked_db, base_db, ducked_db])
	director.end_transmission()
	await create_timer(0.7).timeout
	var restored_db: float = AudioServer.get_bus_volume_db(music)
	check(absf(restored_db - base_db) < 0.05, "#11 the Music bus is back at its normal level after the transmission (%.2f dB)" % restored_db)
	var order_ok: bool = _same(director.events, [AudioManager.SQUELCH_IN, AudioManager.SQUELCH_OUT])
	var heard: int = hub.count_of(AudioManager.SQUELCH_IN) - squelches_before
	check(order_ok and heard == 1 and _same(hub.play_log.slice(-2), [AudioManager.SQUELCH_IN, AudioManager.SQUELCH_OUT]),
		"#12 squelch-in sounds when the transmission starts and squelch-out when it ends")
	director.queue_free()


# --- #13..#17 the world ---------------------------------------------------------------------

func _test_world_audio() -> void:
	world = WorldScene.instantiate()
	root.add_child(world)
	world.set_process(false)
	world.race.incidents_enabled = false
	var hud: RaceHud = world.hud
	hud.refresh_all()
	var clicks: int = hub.count_of(AudioManager.CLICK)
	hud.deck.tabs[0].pressed.emit()
	hud.deck.pace_row.buttons[1].pressed.emit()
	hud.deck.press_box()
	check(hub.count_of(AudioManager.CLICK) - clicks == 3, "#13 tab, mode-row and BOX clicks of the Tactical Deck each play the click snap (%d clicks)" % (hub.count_of(AudioManager.CLICK) - clicks))
	clicks = hub.count_of(AudioManager.CLICK)
	var mouse := InputEventMouseButton.new()
	mouse.button_index = MOUSE_BUTTON_LEFT
	mouse.pressed = true
	hud.tower.rows[2]._gui_input(mouse)
	var tower_clicks: int = hub.count_of(AudioManager.CLICK) - clicks
	clicks = hub.count_of(AudioManager.CLICK)
	hud.drawer._gui_input(mouse)
	hud.handle_key(KEY_T)
	check(tower_clicks == 1 and hub.count_of(AudioManager.CLICK) - clicks == 2, "#14 a click on a Timing Tower row (and on the Telemetry Drawer) plays the tactile snap")
	await _test_countdown()
	await _test_pit_guns()
	_test_cut_in_wiring(hud)
	await _test_engineer_overlay(hud)
	await _test_voiced_call(hud)
	_test_actor_wiring()
	world.race.dispose()
	world.queue_free()
	await process_frame


func _test_countdown() -> void:
	var beeps_before: int = hub.count_of(AudioManager.START_BEEP)
	var buzz_before: int = hub.count_of(AudioManager.LIGHTS_OUT)
	var director: DirectorScript = world.director
	director.begin_countdown()
	var beep_counts: Array[int] = []
	var buzz_early: bool = false
	var guard: int = 0
	while director.state != DirectorScript.State.GREEN_RACING and guard < 2000:
		world.step(0.05)
		guard += 1
		if director.lights_lit > beep_counts.size():
			beep_counts.append(hub.count_of(AudioManager.START_BEEP) - beeps_before)
		if director.state != DirectorScript.State.GREEN_RACING and hub.count_of(AudioManager.LIGHTS_OUT) > buzz_before:
			buzz_early = true
	check(beep_counts == [1, 2, 3, 4, 5] and is_equal_approx(hub.last_start_beep_pitch, 1.36),
		"#15 the countdown beeps once per red pair, a step higher each time: %s beeps, last pitch %.2f" % [str(beep_counts), hub.last_start_beep_pitch])
	check(not buzz_early and hub.count_of(AudioManager.LIGHTS_OUT) - buzz_before == 1,
		"#16 the green buzzer sounds once, exactly when the lights go out")


func _test_pit_guns() -> void:
	var choreographer: PitstopChoreographer = world.choreographer
	var car: GtCar = world.race.cars[5]
	var actor: ActorScript = world.actor_of(car.id)
	var shots_before: int = choreographer.gun_shots
	var counts: Array[int] = [0, 0] # wheels taken off, wheels fitted
	choreographer.pit_gun_fired.connect(func(_id: int, _corner: int, taking_off: bool) -> void:
		counts[0 if taking_off else 1] += 1)
	var progress: float = 0.0
	while progress <= 1.0:
		choreographer.present(car.id, car.team_id, actor, Types.Compound.HARD, true, progress, 0.15)
		progress += 0.02
	choreographer.present(car.id, car.team_id, actor, Types.Compound.HARD, false, 1.0, 0.0)
	check(choreographer.gun_shots - shots_before == 8 and counts == [4, 4],
		"#17 the wheel gun runs eight times in a four-wheel stop: four wheels off and four on (%d off, %d on)" % [counts[0], counts[1]])


func _test_cut_in_wiring(hud: RaceHud) -> void:
	# The sim has already put its own calls on screen (weather advisories go to the engineer).
	hud.radio._hide_banner()
	hud.engineer_radio._hide_banner()
	hud.radio.play_radio(3, "Box this lap, confirming pit entry!", true)
	var started: bool = hud.radio_audio.transmitting and hud.radio_audio.events.back() == AudioManager.SQUELCH_IN
	hud.radio._hide_banner()
	check(started and not hud.radio_audio.transmitting and hud.radio_audio.events.back() == AudioManager.SQUELCH_OUT,
		"#21 the HUD radio cut-in keys the radio director: squelch-in with the banner, squelch-out when it leaves")


# --- #31..#35 the radio voices ---------------------------------------------------------------

func _test_voice_catalog() -> void:
	var rows: Array[Dictionary] = RadioVoice.entries()
	var ids: Dictionary = {}
	var speakers: Dictionary = {}
	var bad: Array[String] = []
	for row: Dictionary in rows:
		ids[row["id"]] = true
		speakers[row["speaker"]] = true
		var clip := load(String(row["file"])) as AudioStreamWAV
		if clip == null or clip.get_length() < 0.4 or clip.get_length() > 12.0 or clip.mix_rate != 24000:
			bad.append(String(row["id"]))
	check(rows.size() >= 60 and ids.size() == rows.size() and speakers.size() == 2 and bad.is_empty(),
		"#31 the voice manifest lists %d unique clips for the engineer and the driver, all loading as 24 kHz speech of 0.4 to 12 s%s" % [rows.size(), "" if bad.is_empty() else " (bad: %s)" % ", ".join(PackedStringArray(bad))])
	var expected: Array[Array] = [
		["engineer", "Box this lap, confirm MEDIUM tyres.", "eng_box_medium"],
		["engineer", "Box this lap, confirm INTERMEDIATE tyres.", "eng_box_intermediate"],
		["engineer", "Chequered flag! P2. Solid job today.", "eng_chequered_p2"],
		["engineer", "Chequered flag! P11. Solid job today.", "eng_chequered"],
		["engineer", "Good stop: 2.4s. Wing replaced, Out now, watch pit exit.", "eng_good_stop_wing"],
		["engineer", "Good stop: 2.4s. Out now, watch pit exit.", "eng_good_stop"],
		["engineer", "Weather radar alert: Heavy Rain hitting the circuit! Track water 40%, track temp 31 C.", "eng_weather_alert"],
		["engineer", "Tyre wear critical (68%). Suggest box this lap for HARD tyres.", "eng_strat_wear_hard"],
		["engineer", "Yellow Flag Sector 2. Contact between SAT and CRU.", "eng_yellow_contact_2"],
		["driver", "I lost the rear at Turn 9! Spun out, tyres flat-spotted!", "drv_lost_rear_9"],
		["driver", "We touched with SAT! Front wing damage!", "drv_touched"],
		["driver", "Puncture! The tyre has delaminated!", "drv_puncture"],
	]
	var wrong: Array[String] = []
	for row: Array in expected:
		var clip: Dictionary = RadioVoice.find(row[0], row[1])
		if String(clip.get("id", "")) != String(row[2]):
			wrong.append("%s -> %s" % [row[2], clip.get("id", "none")])
	var no_clip: bool = RadioVoice.find("driver", "Box this lap, confirm MEDIUM tyres.").is_empty() and RadioVoice.find("engineer", "Nobody wrote this line.").is_empty()
	check(wrong.is_empty() and no_clip, "#32 a sim radio text finds its clip by speaker and pattern, and a speaker or text with no recording finds none%s" % ("" if wrong.is_empty() else " (wrong: %s)" % ", ".join(PackedStringArray(wrong))))


## Every radio call the sim sends in a few short races, dry and wet, has a recorded voice.
func _test_voice_coverage() -> void:
	var sent: int = 0
	var unvoiced: Dictionary = {}
	var spoken_ids: Dictionary = {}
	for archetype: int in [WeatherScript.Archetype.DRY_SUNNY, WeatherScript.Archetype.PASSING_SHOWERS, WeatherScript.Archetype.DRY_TO_STORM, WeatherScript.Archetype.WET_DRYING]:
		var short_race: Node3D = WorldScene.instantiate()
		short_race.total_laps = 4
		short_race.weather_archetype = archetype
		short_race.race_seed = 3 + archetype
		root.add_child(short_race)
		short_race.set_process(false)
		var messages: Array[Dictionary] = []
		short_race.race.radio_message.connect(func(message: Dictionary) -> void: messages.append(message))
		var ticks: int = 0
		while not short_race.race.is_finished() and ticks < MAX_RACE_TICKS:
			short_race.race.step()
			ticks += 1
		for message: Dictionary in messages:
			sent += 1
			# Engineer replies quote the car's live numbers and the flood call is new in 3e: text only, no recorded clip.
			if int(message.get("reply_to", -1)) >= 0 or String(message["text"]).begins_with("Track is flooding"):
				continue
			var clip: Dictionary = RadioVoice.find(String(message["speaker"]), String(message["text"]))
			if clip.is_empty():
				unvoiced["%s: %s" % [message["speaker"], message["text"]]] = true
			else:
				spoken_ids[clip["id"]] = true
		short_race.race.dispose()
		short_race.queue_free()
		await process_frame
	check(sent >= 20 and unvoiced.is_empty(), "#33 all %d radio calls of four short races (%d different clips used) have a voice line%s" % [sent, spoken_ids.size(), "" if unvoiced.is_empty() else "; none for: %s" % "; ".join(PackedStringArray(unvoiced.keys()))])


func _test_voiced_call(hud: RaceHud) -> void:
	hud.radio._hide_banner()
	hud.engineer_radio._hide_banner()
	var director: RadioAudioDirector = hud.radio_audio
	var warnings: int = hub.count_of(AudioManager.WARNING)
	var events_before: int = director.events.size()
	var car: GtCar = world.race.cars[0]
	world.race.push_radio(car, "engineer", "Box this lap, confirm MEDIUM tyres.", true)
	var clip: Dictionary = RadioVoice.find("engineer", "Box this lap, confirm MEDIUM tyres.")
	var hold: float = hud.engineer_radio._hold
	var holds: bool = not clip.is_empty() and hold >= float(clip["length"]) + RadioAudioDirector.VOICE_LEAD_S and hold >= RadioAudioDirector.VOICE_MIN_HOLD_S
	var silent_siren: bool = hub.count_of(AudioManager.WARNING) == warnings
	var before_voice: bool = director.events.size() == events_before + 1 and director.events.back() == AudioManager.SQUELCH_IN
	await create_timer(RadioAudioDirector.VOICE_LEAD_S + 0.2).timeout
	var spoken: bool = director.events.size() == events_before + 2 and director.events.back() == RadioAudioDirector.VOICE_EVENT and director.voice_log.back() == "eng_box_medium"
	hud.engineer_radio._hide_banner()
	var closed: bool = director.events.back() == AudioManager.SQUELCH_OUT and not director.transmitting
	check(holds and silent_siren and before_voice and spoken and closed,
		"#34 a voiced call keys the squelch, speaks its clip after the lead-in (%.1f s banner hold for a %.1f s clip), skips the siren, and ends with the key-down squelch" % [hold, float(clip.get("length", 0.0))])
	# A call with no recording keeps the text banner, its default hold and the siren.
	world.race.push_radio(car, "driver", "Tyres are gone, I need to box now!", true)
	var plain: bool = hud.radio._hold == hud.radio.HOLD_SEC and hub.count_of(AudioManager.WARNING) == warnings + 1
	var quiet: int = director.voice_log.size()
	await create_timer(RadioAudioDirector.VOICE_LEAD_S + 0.2).timeout
	hud.radio._hide_banner()
	check(plain and director.voice_log.size() == quiet, "#35 a call with no recorded line keeps the default banner hold and the warning siren, and speaks nothing")


# --- #27..#30 the engineer overlay ---------------------------------------------------------

## Both banners sit in the free viewport (stage pixels), clear of every readout.
func _test_overlay_placement(hud: RaceHud, driver_banner: Control, engineer_banner: Control) -> void:
	var f: float = hud.stage.scale.x
	var keep_clear: Array[Rect2] = []
	for panel: Control in [hud.tower, hud.drawer, hud.deck, hud.radar]:
		keep_clear.append(Rect2(panel.position, panel.size))
	keep_clear.append(Rect2(16.0, 12.0, 1888.0, 60.0)) # the Zone A ribbon
	var clear: bool = true
	var inside: bool = true
	var boxes: Array[Rect2] = []
	for banner: Control in [driver_banner, engineer_banner]:
		var box := Rect2((banner.global_position - hud.stage.position) / f, banner.size * banner.scale / f)
		boxes.append(box)
		inside = inside and RaceHud.RADIO_DOCK.encloses(box.grow(-1.0)) and banner.modulate.a >= 0.59 # visible: full, or dimmed to 0.6 while the other balloon speaks
		for blocked: Rect2 in keep_clear:
			clear = clear and not blocked.intersects(box.grow(-4.0))
	check(clear and inside and not boxes[0].intersects(boxes[1]),
		"#30 the driver and engineer balloons dock in the lower corners of the free viewport, clear of the tower, drawer, radar, ribbon and deck, and of each other (driver %s, engineer %s)" % [str(boxes[0]), str(boxes[1])])

func _test_engineer_overlay(hud: RaceHud) -> void:
	hud.radio._hide_banner()
	hud.engineer_radio._hide_banner()
	var car: GtCar = world.race.cars[0]
	world.race.push_radio(car, "engineer", "Box this lap, confirm medium tyres.", true)
	var engineer_only: bool = hud.engineer_radio.banner.visible and not hud.radio.banner.visible
	world.race.push_radio(car, "driver", "Tyres are gone, I need to box!", true)
	var routed: bool = engineer_only and hud.radio.banner.visible and hud.engineer_radio.banner.visible
	await create_timer(0.45).timeout
	var view_w: float = root.get_visible_rect().size.x
	var engineer_banner: Control = hud.engineer_radio.banner
	var driver_banner: Control = hud.radio.banner
	var sides: bool = engineer_banner.position.x + engineer_banner.size.x * 0.5 > view_w * 0.5 and driver_banner.position.x + driver_banner.size.x * 0.5 < view_w * 0.5
	check(routed and sides, "#27 an engineer call cuts in on the right and a driver call on the left, both at once (the engineer has an overlay of his own)")
	_test_overlay_placement(hud, driver_banner, engineer_banner)
	var texts: bool = hud.engineer_radio._speaker.text.contains("ENGINEER") and hud.radio._speaker.text.contains("DRIVER")
	var portraits: bool = hud.engineer_radio._portrait.texture != null and hud.radio._portrait.texture != null and hud.engineer_radio._portrait.texture != hud.radio._portrait.texture
	hud.engineer_radio.play_radio(1, "Fuel is fine, keep pushing.", false)
	var cyan: bool = hud.engineer_radio._accent == hud.style.engineer # the engineer card is in the colour that complements the team's
	hud.radio.play_radio(1, "Copy that.", false)
	var lime: bool = hud.radio._accent == hud.radio.base_color # the driver card is in the speaking team's colour
	check(texts and portraits and cyan and lime, "#28 the engineer overlay has its own portrait, ENGINEER title and the complementary colour; the driver card keeps the team colour")
	var both_live: bool = hud.radio_audio.transmitting
	hud.radio._hide_banner()
	var still_ducked: bool = hud.radio_audio.transmitting
	hud.engineer_radio._hide_banner()
	check(both_live and still_ducked and not hud.radio_audio.transmitting, "#29 the music stays ducked until the last of the two overlapping transmissions ends")


func _test_actor_wiring() -> void:
	world.director._enter(DirectorScript.State.GREEN_RACING)
	for _i: int in range(180):
		world.step(FRAME)
	var wired: bool = true
	var in_step: bool = true
	var moving: int = 0
	for actor: ActorScript in world.actors:
		wired = wired and actor.audio != null and actor.audio.engine != null and actor.audio.tire != null
		var car: GtCar = actor.car
		if car.v > 0.5:
			moving += 1
			in_step = in_step and is_equal_approx(actor.audio.engine.pitch_scale, EngineAudio3D.pitch_for(car.rpm))
			var squeal: bool = absf(car.lateral_g) > 1.8 or TireAudio3D.is_lockup(car)
			in_step = in_step and actor.audio.tire.screeching == squeal
	check(wired and moving > 10 and in_step, "#22 every GT car actor carries its spatial engine and tyre voices, driven by its RPM and lateral G (%d cars rolling)" % moving)
	var actor: ActorScript = world.actors[0]
	var pops: int = actor.audio.engine.pops_triggered
	actor.car.gear += 1
	actor.present(1.0, FRAME)
	var popped: bool = actor.audio.engine.pops_triggered == pops + 1
	world.set_time_scale(16.0)
	actor.present(1.0, FRAME, 2.0, false)
	check(popped and not actor.audio.engine.playing, "#23 a gear change on a car pops its exhaust, and the engine goes quiet at high time scale")
	world.set_time_scale(1.0)


# --- #18..#19 the podium --------------------------------------------------------------------

func _test_podium() -> void:
	var synthetic: Array[GtCar] = []
	for index: int in range(12):
		var car := GtCar.new()
		car.id = index
		car.team_id = index >> 1
		synthetic.append(car)
	var awards: Dictionary = Studio.award_points(synthetic, synthetic[4])
	var drivers: Dictionary = awards["drivers"]
	var teams: Dictionary = awards["teams"]
	check(drivers[0] == 25 and drivers[1] == 18 and drivers[2] == 15
		and drivers[4] == 11 and drivers[10] == 0 and teams[0] == 43
		and teams[1] == 27 and teams[2] == 19,
		"#19 FIA scoring includes exactly one eligible fastest-lap bonus and both constructor entries")
	var late_fastest: Dictionary = Studio.award_points(synthetic, synthetic[11])["drivers"]
	check(late_fastest[11] == 0, "Fastest lap outside the top ten earns no bonus")
	synthetic[0].is_dnf = true
	var retired: Dictionary = Studio.award_points(synthetic, synthetic[0])["drivers"]
	check(retired[0] == 0, "A retired entry never earns finishing or fastest-lap points")
	var finale: Node3D = WorldScene.instantiate()
	finale.total_laps = 2
	root.add_child(finale)
	finale.set_process(false)
	finale.race.incidents_enabled = false
	var ticks: int = 0
	while not finale.race.is_finished() and ticks < MAX_RACE_TICKS:
		finale.race.step()
		ticks += 1
	check(finale.race.is_finished(), "Two-lap race produces complete studio classification")
	var snapshot: Dictionary = Studio.capture_results(finale.race)
	var ordered: Array[GtCar] = finale.race.standings()
	check(snapshot.order[0].id == ordered[0].id and snapshot.order[2].id == ordered[2].id,
		"#18 studio snapshot preserves P1-P3 simulation finishing order")
	var source_ref: WeakRef = weakref(finale)
	finale.queue_free()
	await process_frame
	var studio: Node3D = load(Studio.PATH).instantiate()
	studio.setup_celebration(snapshot)
	root.add_child(studio)
	check(source_ref.get_ref() == null and studio.order.size() == 20
		and studio.name_labels[0].text.contains(String(snapshot.order[0].driver_name).to_upper()),
		"Studio renders the final results after the race world is freed")
	studio.queue_free()
	await process_frame


func _same(a: Array, b: Array) -> bool:
	if a.size() != b.size():
		return false
	for index: int in range(a.size()):
		if a[index] != b[index]:
			return false
	return true


# --- #20 the earlier suites ---------------------------------------------------------------

func _test_legacy_suites() -> void:
	if skip_legacy:
		print("[SKIP] #20 earlier suites not run (--skip-legacy)")
		return
	ToonMaterialsScript._cache.clear()
	ActorScript._paint_cache.clear()
	var project_dir: String = ProjectSettings.globalize_path("res://")
	var all_ok: bool = true
	var summary: Array[String] = []
	for suite: Dictionary in LEGACY_SUITES:
		var arguments: PackedStringArray = ["--headless"]
		arguments.append_array(PackedStringArray(suite["args"]))
		arguments.append_array(PackedStringArray(["--path", project_dir, "-s", "res://tests/%s.gd" % suite["script"]]))
		if suite.has("user_args"):
			arguments.append("--")
			arguments.append_array(PackedStringArray(suite["user_args"]))
		var output: Array = []
		var started: int = Time.get_ticks_msec()
		var code: int = OS.execute(OS.get_executable_path(), arguments, output, true)
		var text: String = "\n".join(PackedStringArray(output))
		var failed_lines: int = text.count("[FAIL]")
		var passed_lines: int = text.count("[PASS]")
		var ok: bool = code == 0 and failed_lines == 0 and passed_lines > 0
		all_ok = all_ok and ok
		summary.append("%s %s (%d PASS, %d FAIL, %.0f s)" % [suite["script"], "OK" if ok else "FAILED", passed_lines, failed_lines, float(Time.get_ticks_msec() - started) / 1000.0])
		print("    ", summary[-1])
	check(all_ok, "#20 the nine earlier suites still pass without regressions: %s" % ", ".join(PackedStringArray(summary)))
