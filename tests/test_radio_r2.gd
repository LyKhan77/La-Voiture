extends SceneTree

## FASE 11 Langkah 3e acceptance: the R2 "wheatpaste collage" radio cards. The headline keeps `speech.text` plain
## (older tests read it) and shows the highlighted, capitalised text in a separate RichTextLabel; the card is a torn
## paper with tape; two cards make a two-way conversation (talk / dim, slap entry, preloaded portraits).
## Run: Godot --headless --path . -s res://tests/test_radio_r2.gd

const CutInScene := preload("res://scenes/pit_wall/anime_radio_cutin.tscn")
const T := preload("res://scripts/ui/ui_theme_tokens.gd")
const WorldScene := preload("res://scenes/race_weekend_world.tscn")
const DirectorScript := preload("res://scripts/world/race_weekend_director.gd")
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
	var size := Vector2(470.0, 190.0)
	var inside: bool = true
	for point: Vector2 in cut_in.paper_polygon(size):
		inside = inside and Rect2(Vector2.ZERO, size).grow(0.01).has_point(point)
	check(cut_in.speech.text == "Box this lap, confirm WET tyres." and cut_in.rich.text.contains("[bgcolor=") and cut_in.rich.text.contains(" THIS LAP, CONFIRM ")
			and cut_in.rich.get_theme_font_size("normal_font_size") == 30 and cut_in.paper_polygon(size).size() >= 16 and inside
			and cut_in.tape_rects().size() == 2 and cut_in.WAVE_BARS == 12,
		"radio r2: the card is paper with tape and a highlighted headline")

	cut_in.set_base_color(Color("#336699"))
	cut_in.play_radio(1, "Hold position.", false)
	var calm: bool = cut_in._accent == Color("#336699")
	cut_in.play_radio(1, "Box now!", true)
	check(calm and cut_in._accent == T.ACCENT_ANIME_CRIMSON, "radio r2: the paper takes the speaker's colour, urgent calls are crimson")

	cut_in.set_dock(Rect2(352.0, 88.0, 1230.0, 790.0), 0.5)
	cut_in.play_radio(1, "Hold position.", false)
	cut_in.set_dimmed(true)
	var dimmed: bool = is_equal_approx(cut_in.banner.modulate.a, 0.6) and cut_in.banner.scale.is_equal_approx(Vector2(0.475, 0.475)) and cut_in.dimmed
	cut_in.set_dimmed(false)
	check(dimmed and is_equal_approx(cut_in.banner.modulate.a, 1.0) and cut_in.banner.scale.is_equal_approx(Vector2(0.5, 0.5)) and not cut_in.dimmed,
		"radio r2: the listener dims and recovers")

	var viewport_h: float = cut_in.get_viewport().get_visible_rect().size.y
	cut_in.play_radio(2, "Suspension has snapped from the flat tyre! I can't continue, the car is destroyed, please send help to turn four.")
	var tall: float = cut_in._banner_h
	cut_in.play_radio(2, "Box now.")
	check(tall > cut_in.BANNER_MIN_HEIGHT and tall <= viewport_h and is_equal_approx(cut_in._banner_h, cut_in.BANNER_MIN_HEIGHT),
		"radio r2: long calls make the card taller, short ones keep 470x190 (%.0f)" % tall)
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
	var slap: bool = is_equal_approx(driver.banner.rotation_degrees, -9.0) and driver.banner.scale.x > driver._dock_scale * 1.4
	driver._settle()
	check(driver.banner.visible and not driver.dimmed and driver._accent == car.color and slap
			and is_equal_approx(driver.banner.rotation_degrees, -2.0) and driver.banner.scale.is_equal_approx(Vector2.ONE * driver._dock_scale),
		"hud radio: the driver card slaps in in the team colour and settles at its tilt")

	race.push_radio(car, "engineer", "Copy, stay on it.", true)
	engineer._settle()
	check(engineer.banner.visible and not engineer.dimmed and driver.dimmed and engineer._accent == T.ACCENT_ANIME_CRIMSON
			and is_equal_approx(engineer.banner.rotation_degrees, 1.6) and is_equal_approx(driver.banner.modulate.a, 0.6),
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
	var half := Vector2(engineer._banner_w, engineer._banner_h) * 0.5
	engineer._apply_slap(1.0, 9.0)
	var landed: bool = engineer.banner.position.is_equal_approx(engineer._dock_shown()) and is_equal_approx(engineer.banner.rotation_degrees, 1.6)
	var rest_centre: Vector2 = engineer.banner.position + (half * engineer.banner.scale.x).rotated(deg_to_rad(engineer.banner.rotation_degrees))
	engineer._apply_slap(0.0, 9.0)
	var start_centre: Vector2 = engineer.banner.position + (half * engineer.banner.scale.x).rotated(deg_to_rad(engineer.banner.rotation_degrees))
	check(landed and start_centre.is_equal_approx(rest_centre) and engineer.banner.scale.x > engineer.banner.scale.x * 0.0, "hud radio: the slap lands on the dock position and keeps the card's centre")
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
			and driver_rect.position.x < engineer_rect.position.x and is_equal_approx(engineer_rect.position.y, driver_rect.position.y),
		"hud radio: the cards sit side by side at the top of the dock, clear of the track, without overlapping")

	driver._hide_banner()
	var undimmed: bool = not engineer.dimmed
	engineer._hide_banner()
	check(undimmed and not hud.radio_audio.transmitting, "hud radio: the dim ends with the other card and the radio is released")

	check(hud._portraits.size() == race.cars.size() and driver._portrait_texture == hud._portraits[car.id] and hud._portrait_for(9999) == hud.PORTRAIT,
		"hud radio: portraits are preloaded and a missing one falls back")

	PresentationSettings.reduce_motion = true
	driver.play_radio(car.id, "Box now.", false)
	var still: bool = driver.banner.scale.is_equal_approx(Vector2.ONE * driver._dock_scale) and is_equal_approx(driver.banner.rotation_degrees, -2.0) and is_equal_approx(driver.banner.modulate.a, 1.0)
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
