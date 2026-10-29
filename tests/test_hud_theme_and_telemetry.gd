extends SceneTree

## FASE 11 Langkah 3b acceptance: the team accent that skins the race HUD and the concept F telemetry drawer
## (state, onomatopoeia, caption, drawing). Data colours never follow the accent.
## Run: Godot --headless --path . -s res://tests/test_hud_theme_and_telemetry.gd

const WorldScene := preload("res://scenes/race_weekend_world.tscn")
const DirectorScript := preload("res://scripts/world/weekend/race_weekend_director.gd")
const ActorScript := preload("res://scripts/car/gt_car_actor.gd")
const Liveries := preload("res://scripts/car/team_liveries.gd")
const GarageStyle := preload("res://scripts/ui/manga/garage_style.gd")
const T := preload("res://scripts/ui/ui_theme_tokens.gd")
const FRAME: float = 1.0 / 60.0

var failures: int = 0
var assertions: int = 0
var world: Node3D
var hud: RaceHud
var race: GtRace
var mine: Array[GtCar] = []


## A bare canvas that paints the drawer for real, so draw-time errors surface in the log.
class PaintProbe extends Control:
	var state: TelemetryState
	var reduce: bool = false
	var draws: int = 0

	func _draw() -> void:
		draws += 1
		TelemetryPainter.paint(self, state, Color("#FF1E56"), Color.WHITE, reduce)



func _initialize() -> void:
	call_deferred("_run")


func check(ok: bool, description: String) -> void:
	assertions += 1
	if not ok:
		failures += 1
		push_error(description)
	print("[%s] %s" % ["PASS" if ok else "FAIL", description])


func _run() -> void:
	world = WorldScene.instantiate()
	root.add_child(world)
	world.set_process(false)
	hud = world.hud
	race = world.race
	race.incidents_enabled = false
	for car: GtCar in race.cars:
		if car.team_id == race.player_team_id:
			mine.append(car)
	world.director._enter(DirectorScript.State.GREEN_RACING)
	for _i: int in range(40):
		world.step(FRAME)
	race.step_ticks(200)
	hud.refresh_all()
	_test_engineer_colour()
	_test_hud_accent()
	_test_telemetry_state()
	_test_caption_typing()
	await _test_drawer_theme_and_draw()
	_test_clipping_and_reduce_motion()
	await _test_paint_rich_states()
	race.dispose()
	world.queue_free()
	await process_frame
	ActorScript._paint_cache.clear()
	print("%d assertions, %d failure(s)" % [assertions, failures])
	print("FASE 11 LANGKAH 3B TEAM THEME + TELEMETRY: %s" % ("PASS" if failures == 0 else "%d FAILURES" % failures))
	quit(0 if failures == 0 else 1)


# --- engineer colour ---------------------------------------------------------------------------------------------

func _test_engineer_colour() -> void:
	var cyan := Color("#00F0FF")
	var pink := Color("#FF007F")
	var expected: Dictionary = {
		"#CCFF00": cyan, "#00F0FF": pink, "#FF1E56": cyan, "#FFE600": cyan, "#D946EF": cyan,
		"#FF7A00": cyan, "#9B5CFF": cyan, "#3D7BFF": pink, "#00E08A": pink, "#F4F5F7": cyan,
	}
	var wrong: PackedStringArray = []
	for accent: String in expected:
		if GarageStyle.engineer_for(Color(accent)) != expected[accent]:
			wrong.append(accent)
	check(wrong.is_empty(),
		"style: the engineer colour is the first of cyan / pink / lime / yellow at least 55 degrees of hue from the team accent, grey accents get cyan (wrong: %s)" % [wrong])
	var style := GarageStyle.new()
	style.set_accent(Color("#3D7BFF"))
	var blue_engineer: Color = style.engineer
	style.set_accent(Color("#CCFF00"))
	check(blue_engineer == pink and style.engineer == cyan,
		"style: set_accent keeps the engineer colour in step with the accent")


# --- the team accent skins the HUD ---------------------------------------------------------------------------------

func _skin_matches(accent: Color, on_accent: Color) -> bool:
	var texts_ok: bool = true
	for label: Label in hud.marquee_texts:
		texts_ok = texts_ok and label.get_theme_color("font_color") == on_accent
	var fill: Color = (hud.deck.header_shape.material as ShaderMaterial).get_shader_parameter("fill_color")
	return hud.style.accent == accent and hud.logo_label.get_theme_color("font_color") == accent and hud.marquee_bar.color == accent 		and texts_ok and fill == accent and hud.deck.header_title.get_theme_color("font_color") == on_accent


func _test_hud_accent() -> void:
	var team: int = race.player_team_id
	var livery: Color = Liveries.color_for(team)
	check(_skin_matches(livery, hud.style.on_accent) and not hud.marquee_texts.is_empty(),
		"theme: the HUD skin starts in the player team's livery colour")
	hud.set_team_accent(2)
	check(_skin_matches(Color("#FF1E56"), Color.WHITE),
		"theme: switching to a crimson team repaints the skin and flips the type on it to white")
	hud.set_team_accent(7)
	check(_skin_matches(Color("#F4F5F7"), T.INK_BORDER_BLACK),
		"theme: a light team colour keeps ink type")
	hud.set_team_accent(2)
	check(RaceHud.burn_color(0.1) == T.ACCENT_ANIME_CRIMSON and RaceHud.burn_color(1.0) == T.ACCENT_CYBER_YELLOW and TelemetryDrawer.temp_tint(95.0) == T.ACCENT_ACID_LIME and TelemetryDrawer.temp_tint(60.0) == T.ACCENT_ELECTRIC_CYAN,
		"theme: data colours do not follow the team colour")
	hud.set_team_accent(team)


# --- telemetry state ---------------------------------------------------------------------------------------------

## A calm car: no pedal, no DRS, neutral ERS, healthy tyres and driver.
func _calm(car: GtCar) -> void:
	car.v = 60.0
	car.gear = 4
	car.rpm = 6000.0
	car.drs_active = false
	car.drs_eligible = false
	car.throttle = 0.5
	car.brake = 0.0
	car.lateral_g = 0.0
	car.longitudinal_g = 0.0
	car.is_punctured = false
	car.punctured_wheel = -1
	car.is_dnf = false
	car.wheel_temp = PackedFloat64Array([90.0, 90.0, 88.0, 88.0])
	car.wheel_blister_pct = PackedFloat64Array([0.0, 0.0, 0.0, 0.0])
	car.ers_mode = GtTypes.ErsMode.NEUTRAL
	car.ers_battery = 80.0
	car.driver_stress = 20.0
	car.driver_confidence = 85.0
	car.driver_heart_rate = 125.0


func _pop_kinds(state: TelemetryState) -> Array[String]:
	var kinds: Array[String] = []
	for pop: Dictionary in state.pops:
		kinds.append(String(pop["kind"]))
	return kinds


func _test_telemetry_state() -> void:
	var car: GtCar = mine[0]
	var rival: GtCar = race.cars[0] if race.cars[0] != car else race.cars[1]
	_calm(car)
	car.v = 70.0
	car.gear = 5
	car.rpm = 8800.0
	car.drs_active = true
	car.throttle = 1.0
	car.lateral_g = 2.4
	car.longitudinal_g = -1.5
	car.is_punctured = true
	car.punctured_wheel = GtTypes.Wheel.FL
	car.wheel_temp[1] = 140.0
	car.wheel_blister_pct = PackedFloat64Array([0.0, 40.0, 0.0, 0.0])
	car.ers_mode = GtTypes.ErsMode.OVERTAKE
	car.ers_battery = 55.0
	car.driver_stress = 80.0
	car.driver_confidence = 30.0
	var state := TelemetryState.new()
	state.update(car, race.laps)
	check(state.gear == 5 and roundi(state.speed_kmh) == 252 and is_equal_approx(state.rpm, 1.0) and state.limiter and state.drs == 2 and state.header_text.contains(car.code),
		"telemetry state: gear, speed, shift lights and DRS mirror the car (%s, %d km/h)" % [state.header_text, roundi(state.speed_kmh)])
	check(state.throttle[state.throttle.size() - 1] == 1.0 and state.brake[state.brake.size() - 1] == 0.0 and state.g_trail[state.g_trail.size() - 1] == Vector2(2.4, -1.5),
		"telemetry state: the pedal and G traces record the live sample")
	check(state.blown == GtTypes.Wheel.FL and state.heat_tint[0] == T.ACCENT_ANIME_CRIMSON and state.heat_tint[1] == T.ACCENT_ANIME_CRIMSON and state.heat_tint[3] == T.ACCENT_ACID_LIME and state.blister[1] == 40.0,
		"telemetry state: a blown and an overheated tyre are crimson, a healthy one lime, and the blister flag is carried")
	check(state.ers_mode == GtTypes.ErsMode.OVERTAKE and is_equal_approx(state.ers_charge, 0.55) and is_equal_approx(state.stress, 0.8) and is_equal_approx(state.confidence, 0.3),
		"telemetry state: ERS charge, stress and confidence are 0..1")
	car.fuel = 30.0
	car.fuel_burn_rate = 3.0
	state.update(car, 20)
	check(is_equal_approx(state.fuel, 0.5), "telemetry state: the tank level is the laps of fuel left over the race length (%.2f)" % state.fuel)
	car.fuel = 0.0
	state.update(car, 20)
	var empty_tank: bool = state.fuel == 0.0
	state.update(rival, race.laps)
	check(empty_tank and state.g_trail.size() == 1 and state.pops.is_empty() and state.car_id == rival.id,
		"telemetry state: another car starts with fresh traces and no onomatopoeia")

	_calm(car)
	var pops := TelemetryState.new()
	pops.update(car, race.laps)
	car.brake = 0.9
	pops.update(car, race.laps)
	var braked: bool = _pop_kinds(pops) == ["brake"] and String(pops.pops[0]["text"]) == "GUOOO!!"
	pops.update(car, race.laps)
	var held: bool = _pop_kinds(pops) == ["brake"]
	car.gear = 5
	pops.update(car, race.laps)
	var shifted: bool = _pop_kinds(pops) == ["brake", "shift"] and String(pops.pops[1]["text"]) == "KACHA!"
	car.drs_active = true
	pops.update(car, race.laps)
	var capped: bool = _pop_kinds(pops) == ["shift", "drs"] and String(pops.pops[1]["text"]) == "VWOOOM!"
	check(braked and held and shifted and capped,
		"telemetry state: onomatopoeia fire on rising edges only and at most two stay alive (brake %s, held %s, shift %s, cap %s)" % [braked, held, shifted, capped])
	pops.advance(1.0)
	var alive: bool = pops.pops.size() == 2
	pops.advance(1.0)
	check(alive and pops.pops.is_empty(), "telemetry state: onomatopoeia expire after 1.6 s")

	_calm(car)
	var edges := TelemetryState.new()
	edges.update(car, race.laps)
	car.ers_mode = GtTypes.ErsMode.OVERTAKE
	edges.update(car, race.laps)
	var ers_pop: bool = _pop_kinds(edges) == ["ers"] and String(edges.pops[0]["text"]) == "DON!!"
	car.wheel_temp[2] = 130.0
	edges.update(car, race.laps)
	check(ers_pop and _pop_kinds(edges) == ["ers", "tyre"] and String(edges.pops[1]["text"]) == "JIRI JIRI",
		"telemetry state: ERS overtake and a tyre passing 125 C raise their own onomatopoeia")

	_calm(car)
	var both := TelemetryState.new()
	both.update(car, race.laps)
	car.wheel_temp[2] = 130.0
	car.wheel_temp[3] = 128.0
	both.update(car, race.laps)
	check(_pop_kinds(both) == ["tyre"],
		"telemetry state: two tyres passing 125 C on the same sample raise one onomatopoeia, not two (%s)" % [_pop_kinds(both)])

	_calm(car)
	var calm_caption: String = TelemetryState.caption_for(car)
	car.drs_active = true
	var drs_caption: String = TelemetryState.caption_for(car)
	car.brake = 0.8
	var brake_caption: String = TelemetryState.caption_for(car)
	car.ers_mode = GtTypes.ErsMode.OVERTAKE
	var ers_caption: String = TelemetryState.caption_for(car)
	car.wheel_temp[2] = 134.0
	var tyre_caption: String = TelemetryState.caption_for(car)
	car.driver_stress = 90.0
	var stress_caption: String = TelemetryState.caption_for(car)
	car.driver_stress = 20.0
	car.wheel_temp[0] = 140.0
	var front_caption: String = TelemetryState.caption_for(car)
	check(calm_caption == "CLEAN LAP. PACE STEADY, TYRES IN THE WINDOW." and drs_caption == "DRS OPEN — FULL SEND DOWN THE STRAIGHT." and brake_caption == "HARD ON THE BRAKES — DISCS GLOWING…"
			and ers_caption == "OVERTAKE DEPLOYED — ALL ENERGY, ALL IN!" and tyre_caption == "RL TYRE 134°C — GRIP FADING AT THE REAR…" and stress_caption == "HEART RACING — DRIVER AT THE LIMIT…"
			and front_caption == "FL TYRE 140°C — GRIP FADING AT THE FRONT…",
		"telemetry state: the caption follows the situation by priority (%s | %s)" % [tyre_caption, front_caption])

	_calm(car)
	car.is_dnf = true
	car.driver_stress = 0.0
	car.driver_confidence = 100.0
	car.driver_heart_rate = 20.0
	var extreme := TelemetryState.new()
	extreme.update(car, race.laps)
	check(extreme.caption != "" and extreme.heart_rate >= 0.0 and extreme.stress == 0.0 and extreme.confidence == 1.0,
		"telemetry state: a DNF car and extreme driver values still give a valid view")
	_calm(car)


# --- the drawer ------------------------------------------------------------------------------------------------------

func _test_drawer_theme_and_draw() -> void:
	var drawer: TelemetryDrawer = hud.drawer
	check(drawer.size == Vector2(312.0, 496.0) and drawer.position == Vector2(1598.0, 372.0),
		"drawer: the layout box is unchanged")
	var car: GtCar = mine[0]
	_calm(car)
	world.followed_id = car.id
	hud.refresh_all()
	await process_frame
	var drawn: int = drawer.draw_count
	check(drawn > 0, "drawer: it paints from its state in _draw (%d draws)" % drawn)
	var samples: int = drawer.state.g_trail.size()
	hud.handle_key(KEY_T)
	hud.refresh_all()
	await process_frame
	await process_frame
	var asleep: bool = not drawer.visible and drawer.draw_count == drawn and drawer.state.g_trail.size() == samples
	hud.handle_key(KEY_T)
	hud.refresh_all()
	await process_frame
	check(asleep and drawer.visible and drawer.draw_count > drawn and drawer.state.g_trail.size() == samples + 1,
		"drawer: hidden it neither paints nor collects samples, shown again it resumes")
	var livery: Color = Liveries.color_for(race.player_team_id)
	var follows: bool = drawer.accent_color() == livery
	hud.set_team_accent(2)
	hud.refresh_all()
	check(follows and drawer.accent_color() == Color("#FF1E56"),
		"drawer: the skin follows the team accent")
	check(TelemetryDrawer.temp_tint(60.0) == T.ACCENT_ELECTRIC_CYAN and TelemetryDrawer.temp_tint(95.0) == T.ACCENT_ACID_LIME and TelemetryDrawer.temp_tint(118.0) == T.ACCENT_CYBER_YELLOW and TelemetryDrawer.temp_tint(130.0) == T.ACCENT_ANIME_CRIMSON and drawer.state.heat_tint[3] == T.ACCENT_ACID_LIME,
		"drawer: tyre heat colours stay fixed whatever the team colour")
	hud.set_team_accent(race.player_team_id)
	var rival: GtCar = race.cars[0] if race.cars[0] != car else race.cars[1]
	drawer.show_car(rival, race.laps)
	var fresh: bool = drawer.state.g_trail.size() == 1
	drawer.show_car(car, race.laps)
	check(fresh and drawer.state.car_id == car.id, "drawer: another car starts with fresh traces")
	check(TelemetryDrawer.heartbeat(0.35) > 0.9 and absf(TelemetryDrawer.heartbeat(0.0)) < 0.001 and TelemetryDrawer.heartbeat(0.66) > 0.2,
		"drawer: the heartbeat trace keeps its QRS spike and T wave")


func _test_caption_typing() -> void:
	var car: GtCar = mine[0]
	_calm(car)
	var state := TelemetryState.new()
	state.update(car, race.laps)
	var start: float = state.caption_chars
	state.advance(0.5)
	var half: bool = is_equal_approx(state.caption_chars, 21.0)
	state.advance(5.0)
	var full: bool = is_equal_approx(state.caption_chars, float(state.caption.length()))
	car.brake = 0.8
	state.update(car, race.laps)
	var retyped: bool = state.caption_chars == 0.0
	car.brake = 0.0
	car.gear += 1
	state.update(car, race.laps)
	check(start == 0.0 and half and full and retyped and is_equal_approx(state.shift_time, state.clock),
		"telemetry state: the caption types at 42 characters per second and restarts when the story changes, an upshift stamps shift_time")
	_calm(car)


# --- final review fixes: clipping, reduce motion, real painting ----------------------------------------------------

func _test_clipping_and_reduce_motion() -> void:
	var box := PackedVector2Array([Vector2(0.0, 0.0), Vector2(100.0, 0.0), Vector2(100.0, 100.0), Vector2(0.0, 100.0)])
	var crossing: Array[PackedVector2Array] = TelemetryPainter.inside_pieces(Vector2(50.0, 50.0), Vector2(200.0, 50.0), box)
	var kept: bool = crossing.size() == 1
	for piece: PackedVector2Array in crossing:
		for point: Vector2 in piece:
			kept = kept and point.x >= -0.01 and point.x <= 100.01 and point.y >= -0.01 and point.y <= 100.01
	var outside: Array[PackedVector2Array] = TelemetryPainter.inside_pieces(Vector2(150.0, 150.0), Vector2(250.0, 150.0), box)
	check(kept and outside.is_empty(),
		"painter: a panel line keeps only the part inside its polygon (the Geometry2D difference would keep the rest)")
	var steady: bool = TelemetryPainter.limiter_flash(true, 0.0, true) and TelemetryPainter.limiter_flash(true, 0.1, true)
	var flicker: bool = TelemetryPainter.limiter_flash(true, 0.0, false) != TelemetryPainter.limiter_flash(true, 0.1, false)
	var state := TelemetryState.new()
	state.clock = 5.0
	state.shift_time = 4.9
	check(steady and flicker and not TelemetryPainter.limiter_flash(false, 0.0, true),
		"painter: the limiter flashes, and under reduce motion it holds one steady purple")
	check(TelemetryPainter.kick_for(state, false) > 0.5 and TelemetryPainter.kick_for(state, true) == 0.0
			and TelemetryPainter.beat_scale(1.0, true) == 1.0 and is_equal_approx(TelemetryPainter.beat_scale(1.0, false), 1.35)
			and TelemetryPainter.pop_scale(0.05, true) == 1.0 and TelemetryPainter.pop_scale(0.05, false) > 1.2 and TelemetryPainter.pop_scale(1.0, true) == 1.0,
		"painter: gear kick, heart pulse and onomatopoeia scale are all still under reduce motion")


func _test_paint_rich_states() -> void:
	var car: GtCar = mine[0]
	_calm(car)
	car.is_punctured = true
	car.punctured_wheel = GtTypes.Wheel.FL
	car.wheel_blister_pct = PackedFloat64Array([40.0, 40.0, 0.0, 0.0])
	car.wheel_temp = PackedFloat64Array([140.0, 130.0, 118.0, 99.0])
	car.damage = 50.0
	car.brake = 0.9
	car.rpm = 8800.0
	car.drs_active = true
	car.ers_mode = GtTypes.ErsMode.HARVEST
	car.driver_stress = 100.0
	var state := TelemetryState.new()
	state.update(car, race.laps)
	var probe := PaintProbe.new()
	probe.state = state
	probe.size = Vector2(312.0, 496.0)
	root.add_child(probe)
	var painted: int = 0
	for reduce: bool in [false, true]:
		probe.reduce = reduce
		for kind: String in TelemetryState.POP_TEXT:
			state.pops = [{"text": String(TelemetryState.POP_TEXT[kind]), "kind": kind, "born": state.clock}]
			state.shift_time = state.clock
			state.advance(0.05)
			probe.queue_redraw()
			await process_frame
			painted += 1
		for mode: int in [GtTypes.ErsMode.NEUTRAL, GtTypes.ErsMode.DEPLOY, GtTypes.ErsMode.OVERTAKE]:
			car.ers_mode = mode
			state.update(car, race.laps)
			probe.queue_redraw()
			await process_frame
			painted += 1
	var batches: Array = probe.get_meta(&"telemetry_stress_batches", [])
	var instanced: bool = batches.size() == 9
	for entry: Dictionary in batches:
		var batch: MultiMesh = entry["batch"]
		instanced = instanced and batch.instance_count == 64 and batch.transform_format == MultiMesh.TRANSFORM_2D
	check(instanced, "painter: stress halftone reuses nine instanced columns instead of rebuilding 576 circles per frame")
	var first_batch: MultiMesh = batches[0]["batch"] if not batches.is_empty() else null
	state.stress = 0.3
	probe.queue_redraw()
	await process_frame
	var reused: Array = probe.get_meta(&"telemetry_stress_batches", [])
	check(first_batch != null and not reused.is_empty() and reused[0]["batch"] == first_batch and is_equal_approx(float(reused[0]["radius"]), 0.9), "painter: changing stress keeps canvas-owned batches and updates the original radius formula")
	probe.queue_free()
	_calm(car)
	car.damage = 0.0
	check(probe.draws >= painted,
		"painter: blown tyre, blisters, damage, limiter, kick, every onomatopoeia and every ERS mode paint with and without reduce motion (%d draws)" % probe.draws)
