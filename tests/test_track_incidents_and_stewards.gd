extends SceneTree

## FASE 11 Langkah 6 acceptance: authentic GT3 incident dynamics (snap oversteer + countersteer, no 360 spin),
## trackside digital flag panels, DNF wreckage and in-lap evacuation, and the steward time penalty.
## Run: Godot --headless --path . -s res://tests/test_track_incidents_and_stewards.gd

const TrackScene := preload("res://scenes/race_world/circuits/apex_ring/apex_circuit.tscn")
const RibbonScript := preload("res://scripts/car/track_ribbon.gd")
const TrackScript := preload("res://scripts/gt/gt_track.gd")
const RaceScript := preload("res://scripts/gt/gt_race.gd")
const CarScript := preload("res://scripts/gt/gt_car.gd")
const WeatherScript := preload("res://scripts/gt/gt_weather.gd")
const Types := preload("res://scripts/gt/gt_types.gd")
const WorldScene := preload("res://scenes/race_weekend_world.tscn")
const ActorScript := preload("res://scripts/car/gt_car_actor.gd")
const ToonMaterialsScript := preload("res://scripts/world/shared/toon_materials.gd")
const FRAME: float = 1.0 / 60.0

const DRY: int = WeatherScript.Archetype.DRY_SUNNY
const YAW_LIMIT: float = 0.55

var failures: int = 0
var assertions: int = 0
var ribbon: RibbonScript
var track: TrackScript
var world: Node3D


func _initialize() -> void:
	call_deferred("_run")


func check(ok: bool, description: String) -> void:
	assertions += 1
	if not ok:
		failures += 1
		push_error(description)
	print("[%s] %s" % ["PASS" if ok else "FAIL", description])


func _run() -> void:
	ribbon = TrackScene.instantiate()
	ribbon.road_half_width_m = 7.0
	root.add_child(ribbon)
	track = TrackScript.new(ribbon, 14.0)
	_test_snap_oversteer_is_bounded_and_settles()
	_test_slide_goes_to_the_outside_and_scrubs_speed()
	_test_match_collider_stays_intact_during_a_slide()
	_test_in_lap_evacuation_fades_the_wreck_and_calls_the_track_clear()
	_test_stewards_investigate_and_penalise_a_rear_end_hit()
	_test_light_touch_and_side_contact_are_not_penalised()
	_test_penalty_is_served_in_the_box_before_the_crew_works()
	_test_standing_start_and_repeat_offenders_are_not_flooded_with_cases()
	_test_review_fixes_in_the_sim()
	ribbon.queue_free()
	await process_frame
	world = WorldScene.instantiate()
	root.add_child(world)
	world.set_process(false)
	world.race.incidents_enabled = false
	await process_frame
	_test_flag_panels_follow_the_flag()
	_test_wreck_leans_on_the_barrier_and_smokes()
	_test_steward_banner_runs_investigation_then_verdict()
	_test_unserved_penalty_is_added_to_the_podium_time()
	_test_countersteer_is_drawn_from_the_car_state()
	world.race.dispose()
	world.queue_free()
	for _frame: int in range(3):
		await process_frame
	ToonMaterialsScript._cache.clear()
	ActorScript._paint_cache.clear()
	print("%d assertions, %d failure(s)" % [assertions, failures])
	print("FASE 11 LANGKAH 6 INCIDENTS + STEWARDS: %s" % ("PASS" if failures == 0 else "%d FAILURES" % failures))
	quit(0 if failures == 0 else 1)


# --- helpers -----------------------------------------------------------------------

## A field without random incidents, so a scenario only sees what it sets up.
func _quiet_race(laps: int = 10) -> RaceScript:
	var race := RaceScript.new(track, laps, 5, DRY)
	race.incidents_enabled = false
	return race


## Gets the field rolling, then isolates car 0 mid-straight at speed with a fresh spin.
func _spun_car(race: RaceScript, lateral: float) -> CarScript:
	race.step_ticks(600)
	var car: CarScript = race.cars[0]
	car.lateral = lateral
	car.v = 60.0
	car.spin_timer = 4.0
	return car


# --- Task 1: loss of control ---------------------------------------------------------

func _test_snap_oversteer_is_bounded_and_settles() -> void:
	var race: RaceScript = _quiet_race()
	var car: CarScript = _spun_car(race, 2.0)
	var max_yaw: float = 0.0
	var countersteered: int = 0
	var samples: int = 0
	while car.spin_timer > 0.0:
		race.step()
		max_yaw = maxf(max_yaw, absf(car.yaw_offset))
		if absf(car.yaw_offset) > 0.1:
			samples += 1
			countersteered += 1 if signf(car.steer_angle) == -signf(car.yaw_offset) else 0
	race.step_ticks(60)
	check(max_yaw > 0.3 and max_yaw <= YAW_LIMIT,
		"snap oversteer: the slip angle peaks at %.2f rad, past a visible slide but under %.2f rad (no 360 spin)" % [max_yaw, YAW_LIMIT])
	check(absf(car.yaw_offset) < 0.05,
		"snap oversteer: the heading settles back to straight (%.3f rad one second after the slide)" % car.yaw_offset)
	check(samples > 10 and countersteered == samples,
		"countersteer: the front wheels hold opposite lock to the body slip on %d of %d slide ticks" % [countersteered, samples])
	race.dispose()


func _test_slide_goes_to_the_outside_and_scrubs_speed() -> void:
	var race: RaceScript = _quiet_race()
	var car: CarScript = _spun_car(race, 2.0)
	var start_lateral: float = car.lateral
	race.step()
	var v_lat_out: float = car.v_lat
	var lowest_v: float = car.v
	while car.spin_timer > 0.0:
		race.step()
		lowest_v = minf(lowest_v, car.v)
	check(absf(v_lat_out - 2.8) < 0.01 and car.lateral > start_lateral,
		"slide: the car drifts toward the outer verge at 2.8 m/s (v_lat %.2f, lateral %.2f -> %.2f)" % [v_lat_out, start_lateral, car.lateral])
	check(lowest_v >= 12.0 and lowest_v < 60.0,
		"slide: heavy tyre scrub bleeds speed but never below the 12 m/s floor (lowest %.1f m/s)" % lowest_v)
	race.dispose()


# --- Task 2: digital flag panels -----------------------------------------------------

func _panel_sector(panels: FlagPanelSet, index: int) -> int:
	return int(panels.records[index]["sector"])


func _panel_states(panels: FlagPanelSet) -> Array:
	return panels.states


func _test_flag_panels_follow_the_flag() -> void:
	var furniture: Node3D = world.environment.furniture
	var panels: FlagPanelSet = world.environment.flag_panels
	var panel_nodes: Array[Node] = furniture.find_children("FlagPanels", "MultiMeshInstance3D", false, false)
	var count: int = panels.count
	check(count == 8 and panel_nodes.size() == 1 and (panel_nodes[0] as MultiMeshInstance3D).multimesh.instance_count == 8,
		"panels: eight digital flag panels share ONE MultiMeshInstance3D (%d panels, %d node)" % [count, panel_nodes.size()])
	if count != 8:
		return
	var sectors: Dictionary = {}
	for index: int in range(count):
		sectors[_panel_sector(panels, index)] = true
	check(sectors.size() == 3, "panels: every one of the three sectors carries at least one panel")
	world.step(FRAME)
	check(_panel_states(panels).count(0) == count, "panels: all eight glow a dim steady green under the green flag")

	world.race.set_flag(Types.Flag.YELLOW, 2, "YELLOW FLAG (SEC 2) - TEST", 14.0)
	world.step(FRAME)
	var in_sector_two: int = 0
	var yellow_ok: bool = true
	for index: int in range(count):
		var is_two: bool = _panel_sector(panels, index) == 2
		in_sector_two += 1 if is_two else 0
		yellow_ok = yellow_ok and int(_panel_states(panels)[index]) == (1 if is_two else 0)
	check(in_sector_two > 0 and yellow_ok,
		"panels: a sector 2 yellow blinks only the %d panels of sector 2" % in_sector_two)

	world.race.set_flag(Types.Flag.SC, 1, "SAFETY CAR DEPLOYED - TEST", 30.0)
	world.step(FRAME)
	check(_panel_states(panels).count(2) == count, "panels: the safety car puts SC on every panel of the circuit")

	world.race.set_flag(Types.Flag.GREEN, 1, "TRACK CLEAR - GREEN FLAG", 0.0)
	world.step(FRAME)
	check(_panel_states(panels).count(0) == count, "panels: the green flag returns every panel to dim green")


# --- Task 1: the match collider through a slide ---------------------------------------

func _test_match_collider_stays_intact_during_a_slide() -> void:
	var race: RaceScript = _quiet_race()
	var car: CarScript = _spun_car(race, 2.0)
	var pairs_ok: bool = true
	var overlaps: int = 0
	var finite: bool = true
	var guard: int = 0
	while car.spin_timer > 0.0 and guard < 400:
		guard += 1
		race.step()
		pairs_ok = pairs_ok and race.contacts.pairs_checked_last == 190 and race.cars.size() == 20
		for i: int in range(race.cars.size()):
			var a: CarScript = race.cars[i]
			finite = finite and not is_nan(a.yaw_offset) and not is_nan(a.s) and not is_nan(a.lateral)
			for j: int in range(i + 1, race.cars.size()):
				var b: CarScript = race.cars[j]
				var ds: float = GtContacts.signed_gap(a.s, b.s, track.length)
				# Bodies sharing a spot (one car's nose inside the other) is the failure the collider exists to prevent.
				overlaps += 1 if absf(ds) < 1.5 and absf(a.lateral - b.lateral) < 1.0 else 0
	check(pairs_ok, "collider: all 190 pairs are tested on every tick of the slide and the field stays at 20 cars")
	check(overlaps == 0 and finite, "collider: no two cars share a spot and nothing goes NaN through the slide (%d overlapping ticks)" % overlaps)
	race.dispose()


# --- Task 3: wreck and in-lap evacuation -----------------------------------------------

func _test_wreck_leans_on_the_barrier_and_smokes() -> void:
	var actor: ActorScript = world.actors[3]
	var car: CarScript = actor.car
	car.is_dnf = true
	car.dnf_reason = "Test crash"
	car.v = 0.0
	car.lateral = 7.4
	for _i: int in range(60):
		actor.present(1.0, FRAME)
	var lean: float = actor._yaw.y
	check(lean >= deg_to_rad(15.0) and lean <= deg_to_rad(20.0),
		"wreck: a car stopped at the outer barrier rests at %.1f deg, between 15 and 20" % rad_to_deg(lean))
	car.lateral = -7.4
	for _i: int in range(60):
		actor.present(1.0, FRAME)
	check(actor._yaw.y <= -deg_to_rad(15.0) and actor._yaw.y >= -deg_to_rad(20.0),
		"wreck: against the other barrier the lean flips (%.1f deg)" % rad_to_deg(actor._yaw.y))

	var vfx: RaceVfx = world.vfx
	vfx.update(FRAME)
	var smoke: GPUParticles3D = vfx.wreck_smokes.get(car.id)
	check(smoke != null and smoke.emitting and smoke.get_parent() == actor,
		"wreck: comic smoke pours from the bonnet of the retired car")
	var hazards: Array = vfx.wreck_hazards.get(car.id, [])
	var seen_on: bool = false
	var seen_off: bool = false
	for _i: int in range(40):
		vfx.update(0.05)
		var lit: bool = (hazards[0] as Node3D).visible if hazards.size() == 4 else false
		seen_on = seen_on or lit
		seen_off = seen_off or not lit
	check(hazards.size() == 4 and seen_on and seen_off,
		"wreck: four orange hazard lamps blink on the body (%d lamps, on %s, off %s)" % [hazards.size(), seen_on, seen_off])
	var quiet: Node3D = null
	for other: ActorScript in world.actors:
		if other != actor and other.car.id in vfx.wreck_smokes:
			quiet = other
	check(quiet == null, "wreck: only the retired car smokes, no healthy car gets the emitter")

	car.wreck_alpha = 0.5
	actor.present(1.0, FRAME)
	var dithered: bool = actor.visible and actor._fade_meshes.size() > 0 and absf(actor._fade_meshes[0].transparency - 0.5) < 0.001
	car.wreck_alpha = 0.0
	car.evac_started_at = 1.0
	actor.present(1.0, FRAME)
	vfx.update(FRAME)
	check(dithered and not actor.visible and not smoke.emitting,
		"wreck: halfway through the recovery the body is half transparent; when it ends the actor is hidden and the smoke has stopped")


## The marshals take the wreck away when the safety car comes in: it fades over 2 s and race control says so.
func _test_in_lap_evacuation_fades_the_wreck_and_calls_the_track_clear() -> void:
	var race: RaceScript = _quiet_race(5)
	race.set_flag(Types.Flag.SC, 1, "SC", 0.0)
	var sc_s: float = 1100.0
	race.safety_car["s"] = sc_s
	for index: int in range(race.cars.size()):
		var queued: CarScript = race.cars[index]
		queued.s = sc_s - 14.0 - float(index) * 14.0
		queued.prev_s = queued.s
		queued.v = 25.0
		queued.lap = floori(queued.s / track.length)
		queued.position = index + 1
		queued.pit = null
		queued.pit_request = -1
	race.safety_car["picked_up"] = true
	race.race_control["sc_laps_remaining"] = 0
	var wreck: CarScript = race.cars[2]
	wreck.is_dnf = true
	wreck.is_cleared = true
	wreck.current_sector = 1
	race._update_race_control(0.0)
	var in_lap: bool = int(race.safety_car["phase"]) == Types.SafetyCarPhase.IN_THIS_LAP
	check(in_lap and wreck.evac_started_at >= 0.0 and wreck.wreck_alpha == 1.0,
		"evacuation: the safety car's in-lap call starts the recovery with the wreck still fully visible")
	var told: String = String(race.latest_radio.get("text", ""))
	check(told == "Track clear in Sector 2. Recovery complete, Safety Car in this lap.",
		"evacuation: race control radios the pit wall (\"%s\")" % told)
	var clip: Dictionary = RadioVoice.find("engineer", told, 0)
	check(String(clip.get("id", "")) == "eng_track_clear_2" and float(clip.get("length", 0.0)) > 2.0,
		"evacuation: the race control call has a spoken clip (%s)" % String(clip.get("id", "none")))
	for _i: int in range(10):
		race.step()
	var halfway: float = wreck.wreck_alpha
	for _i: int in range(40):
		race.step()
	check(halfway > 0.2 and halfway < 0.8 and wreck.wreck_alpha == 0.0,
		"evacuation: the wreck fades out over 2 s (%.2f after 0.5 s, %.2f after 2.5 s)" % [halfway, wreck.wreck_alpha])
	check(race.cars.size() == 20 and race.cars.has(wreck),
		"evacuation: the retired car stays in race.cars, only its picture goes (%d cars)" % race.cars.size())
	race.dispose()


# --- Task 4: stewards ------------------------------------------------------------------

## Parks every car but `keep` far up the road, spaced out, so only the scenario's cars can touch.
func _isolate(race: RaceScript, keep: Array[CarScript]) -> void:
	var slot: int = 0
	for car: CarScript in race.cars:
		if keep.has(car):
			continue
		car.s = 2500.0 + float(slot) * 60.0
		car.prev_s = car.s
		car.lap = 0
		slot += 1


## `rear` closes on `front` on the same line, nose to tail, at `closing` m/s.
func _rear_end_setup(race: RaceScript, closing: float) -> Array[CarScript]:
	race.step_ticks(1000) # past the standing-start concertina the stewards ignore
	var rear: CarScript = race.cars[0]
	var front: CarScript = race.cars[1]
	_isolate(race, [rear, front])
	race.stewards = GtStewards.new(race) # the warm-up field made cases and penalties of its own
	rear.penalty_owed_s = 0.0
	front.penalty_owed_s = 0.0
	rear.s = 600.0
	front.s = 604.0
	rear.prev_s = rear.s
	front.prev_s = front.s
	rear.lateral = 0.0
	front.lateral = 0.0
	rear.target_lateral = 0.0
	front.target_lateral = 0.0
	front.v = 50.0
	rear.v = 50.0 + closing
	return [rear, front]


func _test_stewards_investigate_and_penalise_a_rear_end_hit() -> void:
	var race: RaceScript = _quiet_race()
	var pair: Array[CarScript] = _rear_end_setup(race, 9.0)
	var events: Array[Dictionary] = []
	if race.has_signal("steward_event"):
		race.connect("steward_event", func(event: Dictionary) -> void: events.append(event))
	var rear: CarScript = pair[0]
	race.step()
	var stewards: Variant = race.get("stewards")
	var cases: Array = stewards.get("cases") if stewards != null else []
	check(cases.size() == 1 and cases[0]["offender_id"] == rear.id and cases[0]["verdict"] == GtStewards.Verdict.PENDING,
		"stewards: a 9 m/s nose-to-tail hit opens a case against the car behind (%d cases)" % cases.size())
	check(events.size() == 1 and events[0]["text"] == "/// STEWARDS: INCIDENT INVOLVING CAR #%d UNDER INVESTIGATION" % rear.number,
		"stewards: the banner opens on the investigation (\"%s\")" % (events[0]["text"] if not events.is_empty() else "no event"))
	var opened_at: float = race.time
	race.step_ticks(int(9.0 / GtTypes.TICK_DT))
	check(rear.penalty_owed_s == 0.0 and events.size() == 1, "stewards: nine seconds in, the investigation is still open")
	race.step_ticks(int(2.0 / GtTypes.TICK_DT))
	check(rear.penalty_owed_s == 5.0 and events.size() == 2 and race.time - opened_at >= 10.0,
		"stewards: after 10 s the car behind owes 5 s (owes %.1f)" % rear.penalty_owed_s)
	check(events.size() == 2 and events[1]["text"] == "+5s TIME PENALTY // CAR #%d: CAUSING A COLLISION" % rear.number,
		"stewards: the verdict banner reads \"%s\"" % (events[1]["text"] if events.size() > 1 else "no verdict"))
	race.dispose()


func _test_light_touch_and_side_contact_are_not_penalised() -> void:
	var race: RaceScript = _quiet_race()
	var pair: Array[CarScript] = _rear_end_setup(race, 1.0)
	race.step()
	var stewards: Variant = race.get("stewards")
	var gentle: Array = stewards.get("cases") if stewards != null else [1]
	check(race.contacts.contacts_last > 0 and gentle.is_empty(), "stewards: a 1 m/s nose-to-tail touch is nothing for the stewards (%d contacts, %d cases)" % [race.contacts.contacts_last, gentle.size()])
	race.dispose()

	race = _quiet_race()
	pair = _rear_end_setup(race, 9.0)
	pair[1].lateral = 1.9 # door to door, not nose to tail
	pair[1].target_lateral = 1.9
	pair[1].s = pair[0].s + 0.5
	race.step()
	stewards = race.get("stewards")
	var side: Array = stewards.get("cases") if stewards != null else [1]
	var owed: float = pair[0].penalty_owed_s + pair[1].penalty_owed_s
	check(race.contacts.contacts_last > 0 and owed == 0.0 and side.filter(func(c: Dictionary) -> bool: return c["kind"] == GtStewards.Kind.AT_FAULT).is_empty(),
		"stewards: wheel-to-wheel contact is never an at-fault rear-end hit (%d contacts)" % race.contacts.contacts_last)
	race.dispose()


func _test_penalty_is_served_in_the_box_before_the_crew_works() -> void:
	var race: RaceScript = _quiet_race()
	race.step_ticks(10)
	var car: CarScript = race.cars[4]
	car.penalty_owed_s = 5.0
	var pit := GtPit.new()
	pit.phase = Types.PitPhase.BOX
	pit.box_s = 300.0
	car.pit = pit
	var driving: GtDriving = race._driving
	var hold_ticks: int = 0
	var guard: int = 0
	while pit.timer <= 0.0 and guard < 400:
		guard += 1
		driving._service_car(car, pit, GtTypes.TICK_DT)
		hold_ticks += 1 if pit.timer <= 0.0 else 0
	check(absf(float(hold_ticks) * GtTypes.TICK_DT - 5.0) < GtTypes.TICK_DT * 1.5,
		"penalty: the stopped car is held %.2f s before the crew starts work" % (float(hold_ticks) * GtTypes.TICK_DT))
	check(car.penalty_owed_s == 0.0 and car.penalty_served_s == 5.0 and pit.timer > 0.0,
		"penalty: served in the pit, nothing left to add at the finish (owed %.1f, served %.1f)" % [car.penalty_owed_s, car.penalty_served_s])
	var clean_pit := GtPit.new()
	clean_pit.phase = Types.PitPhase.BOX
	var other: CarScript = race.cars[5]
	other.pit = clean_pit
	driving._service_car(other, clean_pit, GtTypes.TICK_DT)
	check(clean_pit.timer > 0.0, "penalty: a car with no penalty is serviced at once")
	car.pit = null
	other.pit = null
	race.dispose()


# --- Task 4: podium ----------------------------------------------------------------------

func _test_unserved_penalty_is_added_to_the_podium_time() -> void:
	var race: RaceScript = world.race
	var finish_s: float = float(race.laps) * race.track.length
	for index: int in range(race.cars.size()):
		var entrant: CarScript = race.cars[index]
		entrant.is_dnf = false
		entrant.evac_started_at = -1.0
		entrant.wreck_alpha = 1.0
		entrant.s = finish_s
		entrant.finished_at = 100.0 + float(index) * 2.0
	var winner: CarScript = race.cars[0]
	winner.penalty_owed_s = 5.0
	var studio_script: Script = load("res://scripts/ui/winning_scene.gd")
	var podium: Node3D = load(studio_script.PATH).instantiate()
	podium.setup_celebration(studio_script.capture_results(race))
	root.add_child(podium)
	check(podium.order[0].id != winner.id and podium.order[2].id == winner.id,
		"podium: the 5 s penalty drops a 2 s winner to third (order %d, %d, %d)" % [podium.order[0].id, podium.order[1].id, podium.order[2].id])
	var shown: String = podium.time_labels[2].text if podium.time_labels.size() > 2 else ""
	check(shown.begins_with("+3.000s") and podium.order[2].time == 105.0,
		"podium: displayed gap and classified time both include the unserved penalty")
	podium.queue_free()


# --- Task 4: HUD banner --------------------------------------------------------------------

func _test_steward_banner_runs_investigation_then_verdict() -> void:
	var banner: Control = world.hud.get("steward_banner")
	check(banner != null and not banner.visible, "banner: the steward banner exists on the HUD and starts hidden")
	if banner == null:
		return
	var race: RaceScript = world.race
	var sounds: AudioManager = AudioManager.of(world)
	var open_text: String = "/// STEWARDS: INCIDENT INVOLVING CAR #7 UNDER INVESTIGATION"
	race.steward_event.emit({"phase": "investigation", "case_id": 1, "kind": 0, "car_id": 6, "text": open_text, "time": 1.0})
	check(banner.visible and banner.header_label.text == open_text and not banner.penalty,
		"banner: the investigation banner appears with the stewards' wording")
	check(sounds.count_of(&"steward_investigation") == 1 and sounds.count_of(&"steward_penalty") == 0,
		"banner: an investigation opens with a short notification beep")
	race.steward_event.emit({"phase": "verdict", "case_id": 1, "kind": 0, "verdict": 2, "car_id": 6, "text": "+5s TIME PENALTY // CAR #7: CAUSING A COLLISION", "time": 11.0})
	check(banner.visible and banner.penalty and banner.header_label.text == "+5s TIME PENALTY // CAR #7: CAUSING A COLLISION",
		"banner: the penalty verdict replaces it in the crimson hazard style")
	check(sounds.count_of(&"steward_penalty") == 1 and sounds.count_of(&"steward_investigation") == 1,
		"banner: a time penalty is struck with the gavel and buzzer")
	race.steward_event.emit({"phase": "verdict", "case_id": 2, "kind": 1, "verdict": 1, "car_id": 3, "text": "NO FURTHER ACTION - RACING INCIDENT", "time": 12.0})
	check(banner.visible and not banner.penalty and banner.header_label.text == "NO FURTHER ACTION - RACING INCIDENT",
		"banner: a racing incident ends in no further action, without the penalty style")
	check(sounds.count_of(&"steward_penalty") == 1 and sounds.count_of(&"steward_investigation") == 1,
		"banner: no further action is silent")
	for _i: int in range(40):
		banner.advance(0.25)
	check(not banner.visible, "banner: a verdict leaves the screen by itself")


func _test_standing_start_and_repeat_offenders_are_not_flooded_with_cases() -> void:
	# The concertina of a standing start is not an offence.
	var race: RaceScript = _quiet_race()
	var early: Array[CarScript] = _rear_end_setup_at(race, 9.0, 300)
	race.step()
	var before_grace: int = race.stewards.cases.size()
	var touched: bool = race.contacts.contacts_last > 0
	race.dispose()
	check(touched and before_grace == 0, "stewards: a hard hit in the first 45 s of the race is the standing-start concertina, not a case (%d cases)" % before_grace)
	# One offender is investigated once a minute, however often the pack bunches up behind it.
	race = _quiet_race()
	var pair: Array[CarScript] = _rear_end_setup(race, 9.0)
	race.step()
	var first: int = race.stewards.cases.size()
	race.step_ticks(int(25.0 / GtTypes.TICK_DT))
	var rear: CarScript = pair[0]
	var third: CarScript = race.cars[2]
	third.s = rear.s + 4.0
	third.prev_s = third.s
	third.lateral = rear.lateral
	third.v = 40.0
	rear.v = 52.0
	race.step()
	check(first == 1 and race.contacts.contacts_last > 0 and race.stewards.cases.size() == 1,
		"stewards: the same car hitting a second car 25 s later is not investigated again (%d cases)" % race.stewards.cases.size())
	race.dispose()


## Like _rear_end_setup, but starts the scenario after `warmup_ticks` instead of past the grace period.
func _rear_end_setup_at(race: RaceScript, closing: float, warmup_ticks: int) -> Array[CarScript]:
	race.step_ticks(warmup_ticks)
	var rear: CarScript = race.cars[0]
	var front: CarScript = race.cars[1]
	_isolate(race, [rear, front])
	race.stewards = GtStewards.new(race) # the warm-up field made cases and penalties of its own
	rear.penalty_owed_s = 0.0
	front.penalty_owed_s = 0.0
	rear.s = 600.0
	front.s = 604.0
	rear.prev_s = rear.s
	front.prev_s = front.s
	rear.lateral = 0.0
	front.lateral = 0.0
	rear.target_lateral = 0.0
	front.target_lateral = 0.0
	front.v = 50.0
	rear.v = 50.0 + closing
	return [rear, front]


# --- review fixes ------------------------------------------------------------------------------------------

func _sc_in_lap_race(wrecks: Array[CarScript]) -> RaceScript:
	var race: RaceScript = _quiet_race(5)
	race.set_flag(Types.Flag.SC, 1, "SC", 0.0)
	race.safety_car["s"] = 1100.0
	for index: int in range(race.cars.size()):
		var queued: CarScript = race.cars[index]
		queued.s = 1100.0 - 14.0 - float(index) * 14.0
		queued.prev_s = queued.s
		queued.v = 25.0
		queued.lap = floori(queued.s / track.length)
		queued.position = index + 1
		queued.pit = null
		queued.pit_request = -1
	race.safety_car["picked_up"] = true
	race.race_control["sc_laps_remaining"] = 0
	return race


func _test_review_fixes_in_the_sim() -> void:
	# A car that retires in the middle of a slide stops sliding (it stayed "spinning" for the rest of the race).
	var race: RaceScript = _quiet_race()
	var car: CarScript = _spun_car(race, 2.0)
	race.step()
	car.damage = 99.0
	race.step_ticks(5)
	check(car.is_dnf and car.spin_timer == 0.0 and car.slide_time == 0.0,
		"review: a car retired mid-slide stops spinning (spin_timer %.2f, slide_time %.2f)" % [car.spin_timer, car.slide_time])
	race.dispose()

	# A new spin starts a new slide envelope, even while an old slide is still running.
	race = _quiet_race()
	car = race.cars[3]
	car.slide_time = 1.05
	car.start_spin(4.0)
	check(car.spin_timer == 4.0 and car.slide_time == 0.0, "review: a new spin restarts the slide envelope instead of continuing the old one")
	race.dispose()

	# Nobody is blamed for hitting a car that is sliding, punctured, or running under a caution.
	for scenario: String in ["sliding", "punctured", "safety car", "virtual safety car"]:
		race = _quiet_race()
		var pair: Array[CarScript] = _rear_end_setup(race, 9.0)
		match scenario:
			"sliding":
				pair[1].spin_timer = 3.0
			"punctured":
				pair[1].is_punctured = true
			"safety car":
				race.set_flag(Types.Flag.SC, 1, "SC", 30.0)
			"virtual safety car":
				race.set_flag(Types.Flag.VSC, 1, "VSC", 30.0)
		pair[1].v = 50.0
		pair[0].v = 59.0
		if scenario.ends_with("safety car"):
			# Under a caution the field no longer touches in this fixture, so the hook is called as the collider would.
			race.stewards.report_nose_to_tail(pair[0], pair[1], 9.0)
			var judged: int = race.stewards.cases.size()
			race.set_flag(Types.Flag.GREEN, 1, "GREEN", 0.0)
			race.stewards.report_nose_to_tail(pair[0], pair[1], 9.0)
			check(judged == 0 and race.stewards.cases.size() == 1,
				"review: a hard hit under the %s is not judged, the same hit under green is (%d, then %d cases)" % [scenario, judged, race.stewards.cases.size()])
		else:
			race.step()
			check(race.contacts.contacts_last > 0 and race.stewards.cases.is_empty(),
				"review: a hard hit on a car that is %s is not a steward case (%d contacts, %d cases)" % [scenario, race.contacts.contacts_last, race.stewards.cases.size()])
		race.dispose()

	# An investigation still open when the race ends is closed at once, so the order and the banner are right.
	race = _quiet_race()
	var rear_end: Array[CarScript] = _rear_end_setup(race, 9.0)
	race.step()
	var opened: bool = race.stewards.cases.size() == 1 and int(race.stewards.cases[0]["verdict"]) == GtStewards.Verdict.PENDING
	for other: CarScript in race.cars:
		if not rear_end.has(other):
			other.is_dnf = true
			other.finished_at = race.time
	rear_end[0].finished_at = race.time
	rear_end[1].finished_at = race.time
	race.step()
	check(opened and race.is_finished() and rear_end[0].penalty_owed_s == 5.0 and int(race.stewards.cases[0]["verdict"]) == GtStewards.Verdict.PENALTY,
		"review: a case still open at the flag gets its verdict at once (owes %.1f s)" % rear_end[0].penalty_owed_s)
	race.dispose()

	# The evacuation call names the sector of the wreck that brought the safety car out, not an older retirement.
	race = _sc_in_lap_race([])
	var old_wreck: CarScript = race.cars[2]
	old_wreck.is_dnf = true
	old_wreck.is_cleared = true
	old_wreck.current_sector = 2
	old_wreck.finished_at = 5.0
	var new_wreck: CarScript = race.cars[7]
	new_wreck.is_dnf = true
	new_wreck.is_cleared = true
	new_wreck.current_sector = 0
	new_wreck.finished_at = 20.0
	race._update_race_control(0.0)
	var said: String = String(race.latest_radio.get("text", ""))
	check(said == "Track clear in Sector 1. Recovery complete, Safety Car in this lap.",
		"review: the evacuation call names the sector of the latest wreck (\"%s\")" % said)
	race.dispose()


## The wheels are drawn from the car state alone: a body slipping to the right with the sim's opposite lock in the
## steering input turns the front wheels the same way as the slip, and the snap is not eased.
func _test_countersteer_is_drawn_from_the_car_state() -> void:
	var actor: ActorScript = world.actors[5]
	var car: CarScript = actor.car
	car.is_dnf = false
	car.spin_timer = 1.0
	car.yaw_offset = 0.4
	car.steer_angle = -0.64
	actor.present(1.0, FRAME)
	var front_turn: float = actor.chassis.socket_wheel_fl.rotation.y
	var rear_turn: float = actor.chassis.socket_wheel_rl.rotation.y
	check(absf(front_turn - 0.64) < 0.001 and signf(front_turn) == signf(car.yaw_offset) and rear_turn == 0.0,
		"review: the front wheels turn %.2f rad on the first frame of a slide, rear wheels stay straight" % front_turn)
	car.spin_timer = 0.0
	car.yaw_offset = 0.0
	car.steer_angle = 0.0
	for _i: int in range(40):
		actor.present(1.0, FRAME)
