extends SceneTree

## FASE 8.4 acceptance: driver portraits on the radio banner, the manga soundwave, the driver
## radio triggers with their per-car cooldown, and the 2D character standees on the podium.
## Run: Godot --headless --path . -s res://tests/test_radio_and_podium.gd

const WorldScene := preload("res://scenes/race_weekend_world.tscn")
const DirectorScript := preload("res://scripts/world/race_weekend_director.gd")
const CutInScene := preload("res://scenes/pit_wall/anime_radio_cutin.tscn")
const Types := preload("res://scripts/gt/gt_types.gd")
const FRAME: float = 1.0 / 60.0

var failures: int = 0
var assertions: int = 0
var world: Node3D
var race: GtRace
var mine: GtCar


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
	world.set_physics_process(false)
	race = world.race
	race.incidents_enabled = false
	for car: GtCar in race.cars:
		if car.team_id == race.player_team_id:
			mine = car
			break
	world.director._enter(DirectorScript.State.GREEN_RACING)
	for _i: int in range(40):
		world.step(FRAME)
	_test_driver_portraits_exist()
	await _test_soundwave()
	_test_radio_cooldown()
	_test_driver_triggers()
	_test_voice_casting()
	await _test_podium_standees()
	race.dispose()
	world.queue_free()
	await process_frame
	print("%d assertions, %d failure(s)" % [assertions, failures])
	print("FASE 8.4 RADIO AND PODIUM: %s" % ("PASS" if failures == 0 else "%d FAILURES" % failures))
	quit(0 if failures == 0 else 1)


# --- helpers -------------------------------------------------------------------------------

func _texts_since(count: int) -> Array[String]:
	var texts: Array[String] = []
	for index: int in range(count, race.radio_history.size()):
		texts.append(String(race.radio_history[index]["text"]))
	return texts


func _any_starts(texts: Array[String], prefix: String) -> bool:
	for text: String in texts:
		if text.begins_with(prefix):
			return true
	return false


# --- tests ---------------------------------------------------------------------------------

func _test_driver_portraits_exist() -> void:
	var missing: Array[int] = []
	for slot: int in range(20):
		if not ResourceLoader.exists(GarageRoster.portrait_path(slot)):
			missing.append(slot)
	check(missing.is_empty(), "#1 all 20 driver slots resolve a radio_portrait.png (missing: %s)" % str(missing))
	var distinct: Dictionary = {}
	for slot: int in range(20):
		distinct[GarageRoster.portrait_path(slot)] = true
	check(distinct.size() == 20, "#2 every slot has its own portrait path (%d distinct)" % distinct.size())
	# The HUD swaps the driver banner's portrait for the speaking car.
	var other: GtCar = race.cars[5]
	var before: Texture2D = world.hud.radio._portrait_texture
	world.hud._on_radio({"id": 999, "car_id": other.id, "code": other.code, "driver_name": other.driver_name,
		"team_color": other.color, "speaker": "driver", "text": "Radio check.", "time": race.time, "urgent": true})
	var expected: Texture2D = load(GarageRoster.portrait_path(other.id)) as Texture2D
	check(world.hud.radio._portrait_texture == expected and expected != before,
		"#3 a driver call shows that driver's own portrait on the driver banner")
	world.hud._on_radio({"id": 1000, "car_id": other.id, "code": other.code, "driver_name": other.driver_name,
		"team_color": other.color, "speaker": "engineer", "text": "Radio check.", "time": race.time, "urgent": true})
	check(world.hud.engineer_radio._portrait_texture == world.hud.ENGINEER_PORTRAIT,
		"#4 the engineer banner keeps the engineer portrait")


func _test_soundwave() -> void:
	var cut_in: CanvasLayer = CutInScene.instantiate()
	root.add_child(cut_in)
	await process_frame
	check(not cut_in.soundwave_active and cut_in.soundwave_energy() < 0.001, "#5 the soundwave is idle before a transmission")
	cut_in.play_radio(3, "Box, box.", false, 2.0)
	check(cut_in.soundwave_active, "#6 a transmission switches the soundwave on")
	for _i: int in range(20):
		cut_in._process(0.05)
	var live: float = cut_in.soundwave_energy()
	check(live > 0.15, "#7 the equalizer bars pulse while transmitting (energy %.2f)" % live)
	cut_in._hide_banner()
	check(not cut_in.soundwave_active, "#8 the banner leaving switches the soundwave off")
	for _i: int in range(60):
		cut_in._process(0.05)
	check(cut_in.soundwave_energy() < 0.02, "#9 the bars decay to a flat baseline when idle (energy %.3f)" % cut_in.soundwave_energy())
	cut_in.queue_free()
	await process_frame


func _test_radio_cooldown() -> void:
	race.driver_radio_cooldown.clear()
	check(race.can_push_driver_radio(mine.id), "#10 a quiet car may call the pit wall")
	var before: int = race.radio_history.size()
	race.push_radio(mine, "driver", "Radio check one.")
	check(race.radio_history.size() == before + 1 and not race.can_push_driver_radio(mine.id),
		"#11 a routine driver call starts a 15 s cooldown for that car")
	check(race.can_push_driver_radio((mine.id + 2) % race.cars.size()), "#12 the cooldown is per car")
	race.step_ticks(int(14.0 / Types.TICK_DT))
	check(not race.can_push_driver_radio(mine.id), "#13 still muted after 14 s")
	race.step_ticks(int(1.5 / Types.TICK_DT))
	check(race.can_push_driver_radio(mine.id), "#14 free again after 15 s")
	race.push_radio(mine, "driver", "Radio check two.", true)
	check(race.can_push_driver_radio(mine.id), "#15 an urgent call bypasses and does not start the cooldown")
	race.push_radio(mine, "engineer", "Engineer check.")
	check(race.can_push_driver_radio(mine.id), "#16 engineer calls do not mute the driver")


func _test_driver_triggers() -> void:
	# Tyre cliff: crossing 75 % wear fires once, and again only after a tyre change.
	race.driver_radio_cooldown.clear()
	mine.wear = 0.74
	mine.tyre_cliff_called = false
	var mark: int = race.radio_history.size()
	mine.wear = 0.80
	race._driving._wear_and_fuel(mine, 0.0, 1.0, 1.0, 85.0, false, 0.0, Types.TICK_DT)
	check(_texts_since(mark).has("Tyres are cooked! Rear is sliding everywhere!"), "#17 wear past 75 % reports the tyre cliff")
	mark = race.radio_history.size()
	race.driver_radio_cooldown.clear()
	race._driving._wear_and_fuel(mine, 0.0, 1.0, 1.0, 85.0, false, 0.0, Types.TICK_DT)
	check(_texts_since(mark).is_empty(), "#18 the tyre cliff is reported once per set of tyres")
	# Overtake: the passing car and the passed car both speak.
	race.driver_radio_cooldown.clear()
	var victim: GtCar = race.cars[(mine.id + 2) % race.cars.size()]
	victim.team_id = race.player_team_id # a second player-team car so both calls are audible
	mark = race.radio_history.size()
	race._driving.announce_pass(mine, victim)
	var texts: Array[String] = _texts_since(mark)
	check(_any_starts(texts, "Pass made on %s!" % victim.code) and _any_starts(texts, "Lost the spot to %s!" % mine.code),
		"#19 a completed pass reports on both cars (%s)" % str(texts))
	mark = race.radio_history.size()
	race._driving.announce_pass(mine, victim)
	check(_texts_since(mark).is_empty(), "#20 the cooldown keeps a second pass quiet")
	# A rival driver is heard when the pass involves the player's car; AI-only passes stay silent.
	victim.team_id = (race.player_team_id + 1) % 10
	race.driver_radio_cooldown.clear()
	mark = race.radio_history.size()
	race._driving.announce_pass(mine, victim)
	var rival_ok: bool = race.radio_history.size() == mark + 2 and bool(race.radio_history[mark + 1]["rival"]) and not bool(race.radio_history[mark + 1]["urgent"])
	check(rival_ok and _any_starts(_texts_since(mark), "Lost the spot to %s!" % mine.code),
		"#20b the AI driver who lost the place to the player's car answers on the radio as a rival (%s)" % str(_texts_since(mark)))
	var others: Array[GtCar] = []
	for car: GtCar in race.cars:
		if car.team_id != race.player_team_id and others.size() < 2:
			others.append(car)
	race.driver_radio_cooldown.clear()
	mark = race.radio_history.size()
	race._driving.announce_pass(others[0], others[1])
	check(race.radio_history.size() == mark, "#20c a pass between two AI cars stays off the radio")
	var hud_card: Dictionary = race.radio_history[mark - 1]
	world.hud.radio._hide_banner() # an urgent card still up would hold this routine call back
	world.hud._on_radio(hud_card)
	check(world.hud.radio._portrait_texture == (load(GarageRoster.portrait_path(int(hud_card["car_id"]))) as Texture2D),
		"#20d the HUD shows the rival driver's banner with that driver's portrait")
	victim.team_id = race.player_team_id
	# ERS: switching to OVERTAKE deployment calls the attack.
	race.driver_radio_cooldown.clear()
	mark = race.radio_history.size()
	race._driving.announce_ers_boost(mine)
	check(_texts_since(mark).has("Deploying ERS boost! Maximum attack!"), "#21 an ERS overtake deployment is called on the radio")
	# Contact: a rub reaches the player's driver as an urgent call.
	race.driver_radio_cooldown.clear()
	mark = race.radio_history.size()
	race.contacts.announce_rub(mine, victim)
	var rub_texts: Array[String] = _texts_since(mark)
	var urgent: bool = not race.radio_history.is_empty() and bool(race.radio_history[mark]["urgent"])
	check(_any_starts(rub_texts, "We touched with ") and rub_texts.size() > 0 and urgent,
		"#22 contact is an urgent driver call (%s)" % str(rub_texts))


func _test_voice_casting() -> void:
	var rows: Array[Dictionary] = RadioVoice.entries()
	var patterns: Dictionary = {}
	for row: Dictionary in rows:
		patterns[String(row["speaker"])] = true
	check(RadioVoice.is_female_driver(7) and not RadioVoice.is_female_driver(6),
		"#23 only Freja Berg's slot (7) is cast with the female voice")
	var male: Dictionary = RadioVoice.find("driver", "Tyres are cooked! Rear is sliding everywhere!", 6)
	var female: Dictionary = RadioVoice.find("driver", "Tyres are cooked! Rear is sliding everywhere!", 7)
	check(not male.is_empty() and not female.is_empty() and String(female["id"]).ends_with("_f") and not String(male["id"]).ends_with("_f"),
		"#24 a new driver call resolves a male clip and Freja's own female clip")
	for text: String in [
		"Pass made on REN! Clean move down the inside!", "Lost the spot to REN! Defending now!",
		"Deploying ERS boost! Maximum attack!", "We touched with REN! Check the telemetry!",
	]:
		if RadioVoice.find("driver", text, 6).is_empty():
			check(false, "#25 a voice clip exists for \"%s\"" % text)
			return
	check(true, "#25 every new driver line has a voice clip")


func _test_podium_standees() -> void:
	var finale: Node3D = WorldScene.instantiate()
	finale.total_laps = 2
	root.add_child(finale)
	finale.set_physics_process(false)
	finale.race.incidents_enabled = false
	finale.director._enter(DirectorScript.State.GREEN_RACING)
	var ticks: int = 0
	while not finale.race.is_finished() and ticks < 60000:
		finale.race.step()
		ticks += 1
	var frames: int = 0
	while finale.podium == null and frames < 600:
		finale.step(FRAME)
		frames += 1
	var podium: PodiumScreen = finale.podium
	check(podium != null, "#26 the podium comes up after the chequered flag")
	check(podium.standees.size() == 3, "#27 three character standees stand above the steps (%d)" % podium.standees.size())
	var order: Array[GtCar] = finale.race.standings()
	var ok: bool = true
	var detail: String = ""
	var tiers: Array[String] = ["P1 WINNER // 25 PTS", "P2 RUNNER-UP // 18 PTS", "P3 PODIUM // 15 PTS"]
	var colors: Array[Color] = [PodiumScreen.GOLD, PodiumScreen.SILVER, PodiumScreen.BRONZE]
	for place: int in range(3):
		var portrait: TextureRect = podium.portraits[place]
		var expected: Texture2D = load(GarageRoster.portrait_path(order[place].id)) as Texture2D
		ok = ok and portrait.texture != null and portrait.texture == expected
		ok = ok and podium.standees[place].size == PodiumScreen.STANDEE_SIZE
		ok = ok and podium.ribbons[place].text == tiers[place]
		ok = ok and podium.ribbon_fills[place].color == colors[place]
		ok = ok and podium.name_labels[place].text == order[place].driver_name.to_upper()
		if not ok and detail.is_empty():
			detail = "place %d" % (place + 1)
	check(ok, "#28 each standee has the finisher's portrait, a Gold/Silver/Bronze tier ribbon, name and 360 x 240 size %s" % detail)
	# Staggered entrance: P3 first, then P2, then P1; the trophy and confetti wait for P1.
	podium.step(0.0)
	podium.set_elapsed(0.1)
	var a3: float = podium.standees[2].modulate.a
	var a2: float = podium.standees[1].modulate.a
	var a1: float = podium.standees[0].modulate.a
	check(a3 > 0.0 and a2 == 0.0 and a1 == 0.0, "#29 at 0.1 s only P3 has started (%.2f, %.2f, %.2f)" % [a3, a2, a1])
	podium.set_elapsed(0.3)
	check(podium.standees[1].modulate.a > 0.0 and podium.standees[0].modulate.a == 0.0, "#30 at 0.3 s P2 follows, P1 still waits")
	podium.set_elapsed(0.55)
	check(podium.standees[0].modulate.a > 0.0 and podium.trophy.modulate.a > 0.0 and podium.confetti_visible(),
		"#31 at 0.55 s P1 is in and the trophy and confetti are out")
	podium.set_elapsed(PodiumScreen.REVEAL_S)
	var settled: bool = true
	for place: int in range(3):
		var rect: Rect2 = PodiumScreen.STEP_RECTS[place]
		settled = settled and is_equal_approx(podium.standees[place].modulate.a, 1.0)
		settled = settled and is_equal_approx(podium.standees[place].position.y, rect.position.y - PodiumScreen.CARD_H - PodiumScreen.CARD_GAP)
	check(settled, "#32 once revealed every standee rests fully visible on its step")
	finale.queue_free()
	await process_frame
