extends SceneTree

## Which part of RaceWeekendWorld.step() makes a frame slow? Native run (needs a GPU):
##   godot --path . --resolution 1920x1080 --script res://scratch/profile_world_step.gd -- <circuit_id> [seconds] [pits]
## Takes over the world's physics-process step, runs its sections by hand in step()'s own order with a microsecond
## timer around each (at the 60 Hz the real step runs at), and reports mean / p95 / max per section, split by frames
## that ran a sim tick and frames that did not. Keep the section list in sync with RaceWeekendWorld.step().

const WorldScene := preload("res://scenes/race_weekend_world.tscn")
const ConfigScript := preload("res://scripts/core/race_config_data.gd")
const Types := preload("res://scripts/gt/gt_types.gd")
const CarScript := preload("res://scripts/gt/gt_car.gd")

const SECTIONS: Array[String] = [
	"director", "run_ticks", "flag_panels", "actors.present (20)", "present_pit (20)", "pit_crews", "podium", "vfx.update",
	"cameras", "environment.update", "hud.update", "TOTAL",
]

var world: Node3D
var tick_rows: Array[Dictionary] = []
var idle_rows: Array[Dictionary] = []
var actor_times: Array[float] = []
var outliers: Array[String] = []
var radio_log: Array[String] = []
## A step this slow, in ms, is listed with the sections that took more than 3 ms.
const OUTLIER_MS: float = 9.0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var circuit: String = args[0] if args.size() > 0 else "brianza"
	var seconds: float = float(args[1]) if args.size() > 1 else 25.0
	var pits: bool = args.size() > 2 and args[2] == "pits"
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 60
	var config := ConfigScript.get_config()
	config.selected_circuit_id = circuit
	config.total_laps = 3
	config.time_of_day = 0
	config.weather_preset = 0
	config.selected_team_id = 0
	config.race_seed = 19220903
	world = WorldScene.instantiate()
	root.add_child(world)
	world.finish_grid_intro()
	await process_frame
	print("DEBUG hud.visible=%s radio.visible=%s ready=%s prewarm_frames=%d banner.visible=%s hud_is_in_tree=%s pre_grid_hold=%s" % [str(world.hud.visible), str(world.hud.radio.visible), str(world.hud.radio.is_node_ready()), world.hud.radio._prewarm_frames, str(world.hud.radio.banner.visible), str(world.hud.is_inside_tree()), str(world.pre_grid_hold)])
	world.set_process(false)
	# Time the HUD's radio handler (it runs synchronously inside GtRace.step) and log slow calls with their text.
	world.race.radio_message.disconnect(world.hud._on_radio)
	world.race.radio_message.connect(_timed_radio)
	if args.size() > 3 and args[3] == "wheelwarm":
		# Experiment: light every rotor once on the grid (creates and draws the glow overlay), then switch it off.
		for actor in world.actors:
			for wheel in actor.wheel_controllers:
				wheel.set_brake_glow(0.5)
		for _i: int in range(10):
			await process_frame
		for actor in world.actors:
			for wheel in actor.wheel_controllers:
				wheel.set_brake_glow(0.0)
		for _i: int in range(10):
			await process_frame
	if args.size() > 3 and args[3] == "matwarm":
		# Experiment: draw the brake-glow material variant once, in front of the camera, before the race starts.
		var glow := StandardMaterial3D.new()
		glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		glow.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		glow.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		glow.emission_enabled = true
		glow.emission = Color(1.0, 0.32, 0.04)
		glow.albedo_color = Color(1.0, 0.32, 0.04, 0.5)
		glow.emission_energy_multiplier = 3.0
		var dummy := MeshInstance3D.new()
		dummy.mesh = SphereMesh.new()
		dummy.scale = Vector3.ONE * 0.05
		dummy.material_overlay = glow
		var cam: Camera3D = world.get_viewport().get_camera_3d()
		print("MATWARM camera=%s" % str(cam))
		if cam != null:
			cam.add_child(dummy)
			dummy.position = Vector3(0.0, 0.0, -2.0)
			for _i: int in range(10):
				await process_frame
			dummy.queue_free()
	if args.size() > 3 and args[3] == "audiowarm":
		# Experiment: run only the audio side of a transmission once (squelch in and out, music duck).
		var source := Node.new()
		world.hud.radio_audio.start_transmission(source)
		for _i: int in range(30):
			await process_frame
		world.hud.radio_audio.end_transmission(source)
		for _i: int in range(120):
			await process_frame
		source.free()
	if args.size() > 3 and args[3] == "prewarm":
		# Experiment: show each radio card once with a full alphabet before the race, then let it hide again.
		for cut_in: CanvasLayer in [world.hud.radio, world.hud.engineer_radio]:
			cut_in.play_radio(0, "ABCDEFGHIJKLMNOPQRSTUVWXYZ 0123456789 !?:;.,#%/-() WE TOUCHED WITH MOR CHECK THE TELEMETRY", true, 0.1)
		for _i: int in range(240):
			await process_frame
	for _i: int in range(180):
		_timed_step(1.0 / 60.0, false)
		await process_frame
	if pits:
		for index: int in range(6):
			world.race.request_pit(world.race.cars[index * 3].id, 1)
		# Fast-forward until the lane is busy, then measure at 1x.
		world.set_time_scale(8.0)
		var guard: int = 0
		while _cars_in_lane() < 3 and guard < 6000:
			_timed_step(1.0 / 60.0, false)
			await process_frame
			guard += 1
		world.set_time_scale(1.0)
	var begin: int = Time.get_ticks_msec()
	while float(Time.get_ticks_msec() - begin) < seconds * 1000.0 and not world.race.is_finished():
		_timed_step(1.0 / 60.0, true)
		await process_frame
	_report(circuit, pits)
	world.queue_free()
	quit(0)


## A copy of RaceHud._on_radio with each step timed; keep in sync with it.
func _timed_radio(message: Dictionary) -> void:
	var hud = world.hud
	var parts: Array[String] = []
	var t: int = Time.get_ticks_usec()
	var begin: int = t
	hud.last_radio = message
	hud.deck.set_radio("%s: %s" % [String(message["code"]), String(message["text"])])
	t = _lap(parts, "deck", t)
	var car = world.race.get_car(int(message["car_id"]))
	var urgent: bool = bool(message["urgent"])
	var cut_in: CanvasLayer = hud.engineer_radio if String(message["speaker"]) == "engineer" else hud.radio
	var blocked: bool = not urgent and cut_in.is_urgent()
	if (urgent or bool(message.get("rival", false)) or (car != null and car.team_id == world.race.player_team_id)) and not blocked:
		var other: CanvasLayer = hud.radio if cut_in == hud.engineer_radio else hud.engineer_radio
		if other.is_present():
			other.set_dimmed(true)
		cut_in.set_dimmed(false)
		if String(message["speaker"]) == "driver":
			cut_in.set_base_color(message["team_color"])
			cut_in.set_portrait(hud._portrait_for(int(message["car_id"])))
		else:
			cut_in.set_portrait(hud.ENGINEER_PORTRAIT)
		t = _lap(parts, "portrait", t)
		var clip: Dictionary = preload("res://scripts/audio/radio_voice.gd").find(String(message["speaker"]), String(message["text"]), int(message["car_id"]))
		t = _lap(parts, "RadioVoice.find", t)
		var hold: float = 0.0
		if not clip.is_empty():
			hold = hud.radio_audio.queue_voice(cut_in, clip)
		t = _lap(parts, "queue_voice", t)
		# A copy of AnimeRadioCutin._play with each step timed; keep in sync with it.
		var car_id: int = int(message["car_id"])
		var text: String = String(message["text"])
		cut_in._message = text
		cut_in._urgent = urgent
		cut_in.sweating = urgent
		cut_in._hold = hold if hold > 0.0 else cut_in.HOLD_SEC
		cut_in._speaker.text = "CAR #%02d // %s" % [car_id + 1, cut_in.role_title]
		cut_in.speech.text = text
		t = _lap(parts, "texts", t)
		cut_in._speaker.add_theme_color_override("font_color", cut_in.INK)
		t = _lap(parts, "speaker override", t)
		cut_in.rich.add_theme_color_override("default_color", cut_in.INK)
		t = _lap(parts, "rich override", t)
		cut_in._sfx.text = cut_in.sfx_text()
		t = _lap(parts, "sfx text", t)
		cut_in._sfx.add_theme_color_override("font_color", cut_in._accent)
		t = _lap(parts, "sfx override", t)
		cut_in._update_accent()
		t = _lap(parts, "_update_accent", t)
		cut_in._refresh_layout()
		t = _lap(parts, "_refresh_layout", t)
		cut_in._show_banner()
		t = _lap(parts, "_show_banner", t)
		cut_in.soundwave_active = true
		t = _lap(parts, "soundwave", t)
		cut_in.transmission_shown.emit(car_id, text)
		t = _lap(parts, "emit(audio)", t)
	hud._set_ticker("%s %s: %s   //   %s" % [String(message["code"]), String(message["speaker"]).to_upper(), String(message["text"]), hud.ticker.text])
	t = _lap(parts, "ticker", t)
	radio_log.append("  RADIO race t=%.2fs %.2f ms [%s] (%s %s): %s" % [float(world.race.time), float(t - begin) / 1000.0, ", ".join(parts), String(message["speaker"]), String(message["code"]), String(message["text"]).left(40)])


## A copy of GtCarActor.present with each step timed; keep in sync with it.
func _timed_present(actor, alpha: float, dt: float, spin_scale: float, audible: bool) -> Array[String]:
	var parts: Array[String] = []
	var car = actor.car
	var t: int = Time.get_ticks_usec()
	var s: float = lerpf(car.prev_s, car.s, alpha)
	var lateral: float = lerpf(car.prev_lateral, car.lateral, alpha)
	var pose: Transform3D = actor.track.point_at(s, lateral)
	t = _lap(parts, "point_at", t)
	if car.spin_timer > 0.0:
		actor._yaw = Vector2(car.yaw_offset, car.yaw_offset)
	else:
		actor._yaw = actor.ease2(actor._yaw, actor.wreck_yaw(car) if car.is_dnf else car.yaw_offset, dt)
	pose.basis = pose.basis.rotated(pose.basis.y, -actor._yaw.y)
	actor.global_transform = pose
	t = _lap(parts, "pose", t)
	if actor._wheel_compound != car.compound and car.pit == null:
		actor.mount_wheels(car.compound)
	t = _lap(parts, "mount_wheels", t)
	actor._tilt_chassis(dt)
	t = _lap(parts, "tilt", t)
	actor._fade_wreck()
	t = _lap(parts, "fade", t)
	actor._animate_wheels(dt, spin_scale)
	t = _lap(parts, "wheels", t)
	actor._update_lamps(dt)
	t = _lap(parts, "lamps", t)
	if actor.audio != null:
		actor.audio.update_from_car(car, audible)
	t = _lap(parts, "audio", t)
	return parts


func _lap(parts: Array[String], key: String, start: int) -> int:
	var now: int = Time.get_ticks_usec()
	parts.append("%s %.2f" % [key, float(now - start) / 1000.0])
	return now


func _cars_in_lane() -> int:
	var count: int = 0
	for car in world.race.cars:
		count += 1 if car.pit != null else 0
	return count


func _timed_step(delta: float, record: bool) -> void:
	var race = world.race
	var row: Dictionary = {}
	var begin: int = Time.get_ticks_usec()
	var t: int = begin
	var time_before: float = float(race.time)
	world.director.advance(delta)
	world.director.update_race(int(race.race_control["flag"]) == Types.Flag.SC, race.is_finished())
	t = _mark(row, "director", t)
	if world.director.is_racing():
		_phased_ticks(delta)
	t = _mark(row, "run_ticks", t)
	world._update_flag_panels()
	t = _mark(row, "flag_panels", t)
	var alpha: float = clampf(world._tick_accumulator / Types.TICK_DT, 0.0, 1.0)
	var spin_scale: float = minf(world.time_scale, 2.0)
	var audible: bool = world.time_scale <= world.AUDIBLE_MAX_TIME_SCALE and not world._celebration_requested
	var present_us: int = 0
	var pit_us: int = 0
	for actor in world.actors:
		var one: int = Time.get_ticks_usec()
		var steps: Array[String] = _timed_present(actor, alpha, delta, spin_scale, audible)
		var two: int = Time.get_ticks_usec()
		world._present_pit(actor)
		present_us += two - one
		pit_us += Time.get_ticks_usec() - two
		if record:
			actor_times.append(float(two - one) / 1000.0)
			if float(two - one) / 1000.0 > 4.0:
				var slow_car = actor.car
				outliers.append("  PRESENT car %d (team %d) %.1f ms at race t=%.2fs: v=%.1f m/s s=%.0f [%s]" % [slow_car.id, slow_car.team_id, float(two - one) / 1000.0, float(world.race.time), slow_car.v, slow_car.s, ", ".join(steps)])
	row["actors.present (20)"] = float(present_us) / 1000.0
	row["present_pit (20)"] = float(pit_us) / 1000.0
	t = Time.get_ticks_usec()
	world._update_pit_crews(delta)
	t = _mark(row, "pit_crews", t)
	world._update_podium(delta)
	t = _mark(row, "podium", t)
	world.vfx.update(delta, alpha)
	t = _mark(row, "vfx.update", t)
	world._update_cameras(delta)
	t = _mark(row, "cameras", t)
	world.environment.update(delta, race)
	t = _mark(row, "environment.update", t)
	world.hud.update(delta)
	t = _mark(row, "hud.update", t)
	row["TOTAL"] = float(Time.get_ticks_usec() - begin) / 1000.0
	if record:
		if float(row["TOTAL"]) > OUTLIER_MS:
			var parts: Array[String] = []
			for key: String in SECTIONS:
				if float(row.get(key, 0.0)) > 3.0 and key != "TOTAL":
					parts.append("%s %.1f" % [key, float(row[key])])
			outliers.append("race t=%.1fs lap=%d total %.1f ms: %s" % [float(race.time), int(race.cars[0].lap), float(row["TOTAL"]), ", ".join(parts)])
		if float(race.time) > time_before:
			tick_rows.append(row)
		else:
			idle_rows.append(row)


## RaceWeekendWorld._run_ticks with GtRace.step()'s phases timed one by one; a tick over 8 ms is listed.
func _phased_ticks(delta: float) -> void:
	var race = world.race
	if race.is_finished():
		return
	world._tick_accumulator += delta * world.time_scale
	var ticks: int = 0
	while world._tick_accumulator >= Types.TICK_DT:
		world._tick_accumulator -= Types.TICK_DT
		var dt: float = Types.TICK_DT
		var t: int = Time.get_ticks_usec()
		var parts: Dictionary = {}
		race.tick_count += 1
		race._tick_driver_radio_cooldowns(dt)
		race._flush_replies()
		t = _mark(parts, "radio+replies", t)
		race._step_weather(dt)
		t = _mark(parts, "weather", t)
		race._update_race_control(dt)
		t = _mark(parts, "race_control", t)
		var racing: Array[CarScript] = []
		for car in race.cars:
			if car.is_racing():
				racing.append(car)
		var contexts: Dictionary = race._driving.build_contexts(racing)
		t = _mark(parts, "build_contexts", t)
		for car in race.cars:
			race._driving.update_car(car, contexts.get(car), dt)
		t = _mark(parts, "update_car", t)
		var active: Array[CarScript] = []
		for car in race.cars:
			if car.is_racing():
				active.append(car)
		race.contacts.resolve(active, dt)
		if race.contacts.contacts_last > 0:
			race._protect_caution_order(active, contexts)
		t = _mark(parts, "contacts", t)
		race.stewards.step()
		if race.is_finished():
			race.stewards.close_all()
		race._check_advisor_tactics()
		race._expire_suggestion()
		race._check_flood_radio()
		race.time += dt
		race._update_wreck_fade()
		t = _mark(parts, "stewards+advisor", t)
		var order: Array = race.standings()
		for index: int in range(order.size()):
			order[index].position = index + 1
		t = _mark(parts, "standings", t)
		var total: float = 0.0
		for key: String in parts:
			total += float(parts[key])
		if total > 8.0:
			var slow: Array[String] = []
			for key: String in parts:
				if float(parts[key]) > 2.0:
					slow.append("%s %.1f" % [key, float(parts[key])])
			outliers.append("  TICK race t=%.2fs total %.1f ms: %s" % [float(race.time), total, ", ".join(slow)])
		ticks += 1
		if race.is_finished() or ticks >= world.MAX_TICKS_PER_FRAME:
			world._tick_accumulator = 0.0
			break


func _mark(row: Dictionary, key: String, start: int) -> int:
	var now: int = Time.get_ticks_usec()
	row[key] = float(now - start) / 1000.0
	return now


func _report(circuit: String, pits: bool) -> void:
	print("WORLD STEP PROFILE %s %s (ms per 60 Hz step)" % [circuit, "6 cars pitting" if pits else "normal race"])
	for label: String in ["with a sim tick", "without a sim tick"]:
		var rows: Array[Dictionary] = tick_rows if label == "with a sim tick" else idle_rows
		print("  -- steps %s: %d" % [label, rows.size()])
		for key: String in SECTIONS:
			var values: Array[float] = []
			for row: Dictionary in rows:
				values.append(float(row.get(key, 0.0)))
			if values.is_empty():
				continue
			values.sort()
			var total: float = 0.0
			for value: float in values:
				total += value
			print("    %-22s mean %6.3f  p95 %6.3f  max %6.3f" % [key, total / float(values.size()), values[int(values.size() * 0.95)], values[values.size() - 1]])
	print("  radio handler calls: %d" % radio_log.size())
	for line: String in radio_log.slice(0, 14):
		print(line)
	print("  slow steps (> %.0f ms): %d" % [OUTLIER_MS, outliers.size()])
	for line: String in outliers.slice(0, 12):
		print("    " + line)
	actor_times.sort()
	if not actor_times.is_empty():
		print("  one car's present(): mean %.3f ms, p95 %.3f ms, max %.3f ms" % [_mean(actor_times), actor_times[int(actor_times.size() * 0.95)], actor_times[actor_times.size() - 1]])


func _mean(values: Array[float]) -> float:
	var total: float = 0.0
	for value: float in values:
		total += value
	return total / float(maxi(values.size(), 1))
