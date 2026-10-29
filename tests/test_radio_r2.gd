extends SceneTree

## FASE 11 Langkah 3e acceptance: the R2 "wheatpaste collage" radio cards. The headline keeps `speech.text` plain
## (older tests read it) and shows the highlighted, capitalised text in a separate RichTextLabel; the card is a torn
## paper with tape; two cards make a two-way conversation (talk / dim, slap entry, preloaded portraits).
## Run: Godot --headless --path . -s res://tests/test_radio_r2.gd

const CutInScene := preload("res://scenes/pit_wall/anime_radio_cutin.tscn")
const T := preload("res://scripts/ui/ui_theme_tokens.gd")
const WorldScene := preload("res://scenes/race_weekend_world.tscn")
const DirectorScript := preload("res://scripts/world/weekend/race_weekend_director.gd")
const ActorScript := preload("res://scripts/car/gt_car_actor.gd")
const FRAME: float = 1.0 / 60.0

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
	await _test_card()
	await _test_animation_runs()
	await _test_dim_and_resize_while_up()
	await _test_two_way_hud()
	print("%d assertions, %d failure(s)" % [assertions, failures])
	print("FASE 11 LANGKAH 3E RADIO R2: %s" % ("PASS" if failures == 0 else "%d FAILURES" % failures))
	quit(0 if failures == 0 else 1)


func _cut_in(role: int) -> CanvasLayer:
	var cut_in: CanvasLayer = CutInScene.instantiate()
	cut_in.role = role
	root.add_child(cut_in)
	await process_frame
	return cut_in


# --- the card -------------------------------------------------------------------------------------------------------

func _test_card() -> void:
	var marked: String = RadioMarkup.highlight("BOX THIS LAP, CONFIRM WET TYRES. BOXING IS NOT A CALL", Color.RED, Color("#050505"))
	check(marked.count("[bgcolor=") == 3 and marked.contains("[bgcolor=#050505][color=#ff0000]BOX[/color][/bgcolor] THIS LAP") and marked.contains(" BOXING IS NOT")
			and RadioMarkup.ink_for(Color("#101820")) == Color.WHITE and RadioMarkup.ink_for(Color("#CCFF00")) == Color("#050505"),
		"radio r2: keywords are highlighted whole-word and the ink follows the paper (%s)" % marked)

	var cut_in: CanvasLayer = await _cut_in(0)
	cut_in.play_radio(3, "Box this lap, confirm WET tyres.")
	await process_frame
	var size := Vector2(218.0, 80.0)
	var outer: PackedVector2Array = cut_in.balloon_polygon(size, 0.0)
	var inner: PackedVector2Array = cut_in.balloon_polygon(size, 4.0)
	var inside: bool = true
	for point: Vector2 in outer:
		inside = inside and Rect2(Vector2.ZERO, size).grow(0.01).has_point(point)
	var nested: bool = true
	for point: Vector2 in inner:
		nested = nested and Rect2(Vector2(4.0, 4.0), size - Vector2(8.0, 8.0)).grow(0.01).has_point(point)
	check(cut_in.speech.text == "Box this lap, confirm WET tyres." and cut_in.rich.text.contains("[bgcolor=") and cut_in.rich.text.contains(" THIS LAP, CONFIRM ")
			and cut_in.rich.get_theme_font_size("normal_font_size") == 16 and outer.size() >= 24 and inside and nested and inner.size() == outer.size(),
		"radio r2: the balloon has a jagged ink outline (%d points) with the paper inset inside it, and a highlighted headline" % outer.size())
	check(cut_in.BANNER_WIDTH <= 264.0 and cut_in.BANNER_MIN_HEIGHT <= 96.0 and cut_in.WAVE_BARS == 8,
		"radio r2: the banner is compact (%.0fx%.0f, was 470x190)" % [cut_in.BANNER_WIDTH, cut_in.BANNER_MIN_HEIGHT])
	check(cut_in.sfx_text() == "ザザッ" and cut_in._sfx.text == "ザザッ" and not cut_in.sweating,
		"radio r2: a routine call carries the static SFX and no sweat")

	cut_in.set_base_color(Color("#336699"))
	cut_in.play_radio(1, "Hold position.", false)
	var calm: bool = cut_in._accent == Color("#336699")
	cut_in.play_radio(1, "Box now!", true)
	check(calm and cut_in._accent == T.ACCENT_ANIME_CRIMSON, "radio r2: the accent takes the speaker's colour, urgent calls are crimson")
	check(cut_in.sweating and cut_in._sfx.text == "ガガッ!" and cut_in.paper_color() == Color("#FFE3EA"),
		"radio r2: an urgent call sweats, shouts a harder SFX and turns the paper pink")
	check(cut_in.jitter_for(0) == Vector2.ZERO and cut_in.jitter_for(1) != Vector2.ZERO and absf(cut_in.jitter_for(1).x) <= 2.0 and absf(cut_in.jitter_for(2).y) <= 2.0,
		"radio r2: the outline shivers on twos by at most 2 px")

	cut_in.set_dock(Rect2(352.0, 88.0, 1230.0, 790.0), 0.5)
	cut_in.play_radio(1, "Hold position.", false)
	cut_in.set_dimmed(true)
	cut_in._settle() # the pop-in is still running; jump to the rest pose before reading the alpha
	var dimmed: bool = is_equal_approx(cut_in.banner.modulate.a, 0.6) and cut_in.banner.scale.is_equal_approx(Vector2(0.475, 0.475)) and cut_in.dimmed
	cut_in.set_dimmed(false)
	check(dimmed and is_equal_approx(cut_in.banner.modulate.a, 1.0) and cut_in.banner.scale.is_equal_approx(Vector2(0.5, 0.5)) and not cut_in.dimmed,
		"radio r2: the listener dims and recovers")

	var viewport_h: float = cut_in.get_viewport().get_visible_rect().size.y
	cut_in.play_radio(2, "Suspension has snapped from the flat tyre! I can't continue, the car is destroyed, please send help to turn four.")
	var tall: float = cut_in._banner_h
	cut_in.play_radio(2, "Box now.")
	check(tall > cut_in.BANNER_MIN_HEIGHT and tall <= viewport_h and is_equal_approx(cut_in._banner_h, cut_in.BANNER_MIN_HEIGHT),
		"radio r2: long calls make the balloon taller (three lines at most), short ones keep the compact size (%.0f)" % tall)
	cut_in.queue_free()


# --- two cards, one conversation ---------------------------------------------------------------------------------------

func _dock_pixels(hud: RaceHud) -> Rect2:
	var factor: float = hud.stage.scale.x
	return Rect2(hud.stage.position + hud.RADIO_DOCK.position * factor, hud.RADIO_DOCK.size * factor)


func _banner_rect(cut_in: CanvasLayer) -> Rect2:
	return Rect2(cut_in.banner.position, Vector2(cut_in._banner_w, cut_in._banner_h) * cut_in._dock_scale)


func _test_two_way_hud() -> void:
	var world: Node3D = WorldScene.instantiate()
	root.add_child(world)
	world.set_physics_process(false)
	var hud: RaceHud = world.hud
	var race: GtRace = world.race
	race.incidents_enabled = false
	world.director._enter(DirectorScript.State.GREEN_RACING)
	for _i: int in range(40):
		world.step(FRAME)
	var car: GtCar = null
	for candidate: GtCar in race.cars:
		if candidate.team_id == race.player_team_id:
			car = candidate
			break
	race.driver_radio_cooldown.clear()
	hud.radio._hide_banner()
	hud.engineer_radio._hide_banner()
	hud.radio.set_dimmed(false)
	hud.engineer_radio.set_dimmed(false)

	race.push_radio(car, "driver", "Had a snap of oversteer! Lost some time.")
	var driver: CanvasLayer = hud.radio
	var engineer: CanvasLayer = hud.engineer_radio
	var slap: bool = is_equal_approx(driver.banner.rotation_degrees, -6.0) and driver.banner.scale.x > driver._dock_scale * 1.3
	driver._settle()
	check(driver.banner.visible and not driver.dimmed and driver._accent == car.color and slap
			and is_equal_approx(driver.banner.rotation_degrees, 0.0) and driver.banner.scale.is_equal_approx(Vector2.ONE * driver._dock_scale),
		"hud radio: the driver balloon pops in in the team colour and settles upright")

	race.push_radio(car, "engineer", "Copy, stay on it.", true)
	engineer._settle()
	check(engineer.banner.visible and not engineer.dimmed and driver.dimmed and engineer._accent == T.ACCENT_ANIME_CRIMSON
			and is_equal_approx(engineer.banner.rotation_degrees, 0.0) and is_equal_approx(driver.banner.modulate.a, 0.6),
		"hud radio: the speaker is lit and the other card dims")
	engineer._hide_banner() # the urgent card above would hold a routine call back
	race.push_radio(car, "engineer", "Copy, calm down.", false, true)
	check(engineer._accent == hud.style.engineer, "hud radio: a routine engineer call is in the complementary colour")

	# Review: a routine reply must not overwrite an urgent card that is still up.
	engineer._hide_banner()
	engineer.set_dimmed(false)
	race.push_radio(car, "engineer", "Box this lap, confirm WET tyres!", true)
	engineer._settle()
	race.push_radio(car, "engineer", "Copy, routine reply.")
	var urgent_kept: bool = engineer.speech.text.begins_with("Box this lap") and engineer._accent == T.ACCENT_ANIME_CRIMSON
	engineer._hide_banner()
	race.push_radio(car, "engineer", "Copy, routine reply.")
	check(urgent_kept and engineer.speech.text.begins_with("Copy, routine"), "hud radio: a routine reply waits for an urgent card instead of replacing it")

	# Review: the slap lands exactly on the dock position and turns around the card's centre.
	var half := Vector2(engineer._banner_w * 0.5, engineer._banner_h) # the pop grows around the bottom centre
	engineer._apply_slap(1.0, 6.0)
	var landed: bool = engineer.banner.position.is_equal_approx(engineer._dock_shown()) and is_equal_approx(engineer.banner.rotation_degrees, 0.0)
	var rest_centre: Vector2 = engineer.banner.position + (half * engineer.banner.scale.x).rotated(deg_to_rad(engineer.banner.rotation_degrees))
	engineer._apply_slap(0.0, 6.0)
	var start_centre: Vector2 = engineer.banner.position + (half * engineer.banner.scale.x).rotated(deg_to_rad(engineer.banner.rotation_degrees))
	check(landed and start_centre.is_equal_approx(rest_centre), "hud radio: the slap lands on the dock position and keeps the card's centre")
	engineer._settle()

	# Review: two cards with a long call each stay in the dock and apart.
	var long_call: String = "Suspension has snapped from the flat tyre! I can't continue, the car is destroyed, please send help now."
	driver.play_radio(car.id, long_call, false)
	engineer.play_radio(car.id, long_call, false)
	driver._settle()
	engineer._settle()
	var tall_driver: Rect2 = _banner_rect(driver)
	var tall_engineer: Rect2 = _banner_rect(engineer)
	var the_dock: Rect2 = _dock_pixels(hud)
	check(the_dock.grow(1.0).encloses(tall_driver) and the_dock.grow(1.0).encloses(tall_engineer) and not tall_driver.intersects(tall_engineer),
		"hud radio: two long calls stay inside the dock and apart")
	driver._hide_banner()
	engineer._hide_banner()

	var dock: Rect2 = _dock_pixels(hud)
	driver.banner.visible = true
	var driver_rect: Rect2 = _banner_rect(driver)
	var engineer_rect: Rect2 = _banner_rect(engineer)
	check(dock.grow(1.0).encloses(driver_rect) and dock.grow(1.0).encloses(engineer_rect) and not driver_rect.intersects(engineer_rect)
			and driver_rect.position.x < engineer_rect.position.x and is_equal_approx(engineer_rect.end.y, driver_rect.end.y)
			and driver_rect.position.y > dock.get_center().y and engineer_rect.position.y > dock.get_center().y,
		"hud radio: the balloons sit in the lower corners of the dock, level at the bottom, without overlapping")
	# Everything else the HUD can show in the free area, in stage pixels: the alerts, the weather deck, the card, the toast.
	var factor: float = hud.stage.scale.x
	var others: Dictionary = {
		"safety car banner": Rect2(570.0, 90.0, 780.0, 90.0), "steward banner": Rect2(580.0, 196.0, 760.0, 58.0),
		"caution tape": Rect2(650.0, 84.0, 620.0, 44.0), "weather deck": Rect2(1006.0, 76.0, 560.0, 264.0),
		"suggestion card": Rect2(656.0, 690.0, 608.0, 136.0), "tyre toast": Rect2(880.0, 800.0, 440.0, 73.0),
		"tower": Rect2(16.0, 88.0, 320.0, 780.0), "deck": Rect2(16.0, 880.0, 1574.0, 146.0),
	}
	var collisions: Array[String] = []
	for label: String in others:
		var window := Rect2(hud.stage.position + (others[label] as Rect2).position * factor, (others[label] as Rect2).size * factor)
		for rect: Rect2 in [driver_rect, engineer_rect]:
			if window.intersects(rect.grow(-1.0)):
				collisions.append(label)
	check(collisions.is_empty(), "hud radio: the balloons clear every other HUD element (%s)" % str(collisions))

	driver._hide_banner()
	var undimmed: bool = not engineer.dimmed
	engineer._hide_banner()
	check(undimmed and not hud.radio_audio.transmitting, "hud radio: the dim ends with the other card and the radio is released")

	check(hud._portraits.size() == race.cars.size() and driver._portrait_texture == hud._portraits[car.id] and hud._portrait_for(9999) == hud.PORTRAIT,
		"hud radio: portraits are preloaded and a missing one falls back")

	PresentationSettings.reduce_motion = true
	driver.play_radio(car.id, "Box now.", false)
	var still: bool = driver.banner.scale.is_equal_approx(Vector2.ONE * driver._dock_scale) and is_equal_approx(driver.banner.rotation_degrees, 0.0) and is_equal_approx(driver.banner.modulate.a, 1.0)
	driver._hide_banner()
	PresentationSettings.reduce_motion = false
	check(still, "hud radio: reduce motion skips the slap and the fade")

	var shown: Array[String] = []
	var record: Callable = func(_car_id: int, text: String) -> void: shown.append(text)
	driver.transmission_shown.connect(record)
	engineer.transmission_shown.connect(record)
	race._pending_replies.clear() # the replies queued by the earlier calls of this test
	race.driver_radio_cooldown.clear()
	race.push_radio(car, "driver", "Had a snap of oversteer! Lost some time.")
	race.step_ticks(ceili(2.6 / GtTypes.TICK_DT))
	var snaps: int = 0
	var copies: int = 0
	for text: String in shown:
		snaps += 1 if text.begins_with("Had a snap") else 0
		copies += 1 if text.begins_with("Copy ") else 0
	driver.play_radio(car.id, "First call.", false)
	driver.play_radio(car.id, "Second call.", false)
	driver._hide_banner()
	engineer._hide_banner()
	driver.transmission_shown.disconnect(record)
	engineer.transmission_shown.disconnect(record)
	check(snaps == 1 and copies == 1 and not hud.radio_audio.transmitting, "hud radio: a driver call and its reply each show once and the radio is not left keyed")

	race.dispose()
	world.queue_free()
	await process_frame
	ActorScript._paint_cache.clear()


# --- the animation really runs, frame by frame ----------------------------------------------------------------------------

## Samples `seconds` of real frames of a docked cut-in that is on the air.
func _sample(cut_in: CanvasLayer, seconds: float) -> Dictionary:
	var shiver: Dictionary = {}
	var phases: Dictionary = {}
	var start: int = Time.get_ticks_msec()
	var peak_energy: float = 0.0
	while float(Time.get_ticks_msec() - start) < seconds * 1000.0:
		await process_frame
		shiver[cut_in._backdrop.position] = true
		phases[cut_in._ray_phase] = true
		peak_energy = maxf(peak_energy, cut_in.soundwave_energy())
	return {"poses": shiver.size(), "phases": phases.size(), "energy": peak_energy}


func _test_animation_runs() -> void:
	PresentationSettings.reduce_motion = false
	var cut_in: CanvasLayer = await _cut_in(1)
	cut_in.set_dock(Rect2(352.0, 88.0, 1230.0, 790.0), 1.0)
	cut_in.play_radio(2, "Box now, box now!", false)
	var rest_scale: float = cut_in._dock_scale
	var popped_scale: float = cut_in.banner.scale.x
	var popped_turn: float = absf(cut_in.banner.rotation_degrees)
	var early_alpha: float = cut_in.banner.modulate.a
	var sampled: Dictionary = await _sample(cut_in, 0.7)
	check(popped_scale > rest_scale * 1.3 and popped_turn > 5.0 and early_alpha < 0.2,
		"animation: the balloon starts the pop big, turned and transparent (x%.2f, %.1f deg, alpha %.2f)" % [popped_scale / rest_scale, popped_turn, early_alpha])
	check(is_equal_approx(cut_in.banner.scale.x, rest_scale) and is_equal_approx(cut_in.banner.rotation_degrees, 0.0) and is_equal_approx(cut_in.banner.modulate.a, 1.0),
		"animation: 0.7 s later the pop has settled to rest on its own (x%.3f, %.2f deg, alpha %.2f)" % [cut_in.banner.scale.x / rest_scale, cut_in.banner.rotation_degrees, cut_in.banner.modulate.a])
	check(int(sampled["poses"]) >= 3 and int(sampled["phases"]) == 2 and float(sampled["energy"]) > 0.1,
		"animation: the outline shivered through %d poses, the lines flickered through %d phases and the teeth reached %.2f" % [int(sampled["poses"]), int(sampled["phases"]), float(sampled["energy"])])

	cut_in._hide_banner()
	PresentationSettings.reduce_motion = true
	cut_in.play_radio(2, "Box now, box now!", false)
	var calm: Dictionary = await _sample(cut_in, 0.5)
	PresentationSettings.reduce_motion = false
	check(int(calm["poses"]) == 1 and int(calm["phases"]) == 1 and cut_in._backdrop.position == Vector2.ZERO,
		"animation: reduce motion keeps the outline and the lines still (%d pose)" % int(calm["poses"]))
	cut_in._hide_banner()
	var idle: Dictionary = await _sample(cut_in, 0.8) # the teeth decay at 8 per second
	check(int(idle["poses"]) == 1 and cut_in._backdrop.position == Vector2.ZERO and cut_in.soundwave_energy() < 0.01,
		"animation: when the call ends the outline stops shivering and the teeth fall flat")
	cut_in.queue_free()

# --- review fixes: state changes while a balloon is up ----------------------------------------------------------------------

func _test_dim_and_resize_while_up() -> void:
	PresentationSettings.reduce_motion = false
	var cut_in: CanvasLayer = await _cut_in(0)
	cut_in.set_dock(Rect2(352.0, 88.0, 1230.0, 790.0), 1.0)
	cut_in.play_radio(1, "Box now, box now!", false)
	cut_in.set_dimmed(true) # the other balloon starts talking while this one is still popping in
	await _sample(cut_in, 0.7)
	check(is_equal_approx(cut_in.banner.modulate.a, 0.6) and is_equal_approx(cut_in.banner.modulate.r, 0.75),
		"review: a balloon dimmed during its pop ends dimmed (alpha %.2f, tint %.2f)" % [cut_in.banner.modulate.a, cut_in.banner.modulate.r])
	cut_in.set_dock(Rect2(0.0, 0.0, 1000.0, 600.0), 0.5)
	var moved: bool = cut_in.banner.position.is_equal_approx(cut_in._dock_shown()) and cut_in.banner.scale.is_equal_approx(Vector2.ONE * 0.5 * cut_in.DIM_SCALE)
	check(moved, "review: a balloon that is up follows a new dock rect at once (%s)" % str(cut_in.banner.position))
	cut_in._hide_banner()
	cut_in.queue_free()
