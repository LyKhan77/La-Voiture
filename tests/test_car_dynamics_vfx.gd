extends SceneTree

## FASE 5.7 acceptance: the 3D car shows what the sim says (steering, roll, pitch, yaw,
## DRS flap, lights, brake glow) and the weekend world has its VFX assembled (weather,
## spray, tyre smoke, sparks, slipstream, exhaust pops, safety car).
## Run: Godot --headless --path . -s res://tests/test_car_dynamics_vfx.gd

const WorldScene := preload("res://scenes/race_weekend_world.tscn")
const DirectorScript := preload("res://scripts/world/weekend/race_weekend_director.gd")
const ActorScript := preload("res://scripts/car/gt_car_actor.gd")
const CarScript := preload("res://scripts/gt/gt_car.gd")
const Types := preload("res://scripts/gt/gt_types.gd")
const WeatherScript := preload("res://scripts/gt/gt_weather.gd")
const FRAME: float = 1.0 / 60.0

var failures: int = 0
var assertions: int = 0
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
	world = WorldScene.instantiate()
	root.add_child(world)
	world.set_physics_process(false)
	world.race.incidents_enabled = false
	world.director._enter(DirectorScript.State.GREEN_RACING)
	for _i: int in range(30):
		world.step(FRAME)
	_test_body_dynamics()
	_test_body_smoothness()
	_test_lights_and_aero()
	_test_weather()
	_test_smoke_sparks_pops()
	_test_safety_car()
	world.race.dispose()
	world.queue_free()
	await process_frame
	ActorScript._paint_cache.clear()
	print("%d assertions, %d failure(s)" % [assertions, failures])
	print("FASE 5.7 DYNAMICS + VFX: %s" % ("PASS" if failures == 0 else "%d FAILURES" % failures))
	quit(0 if failures == 0 else 1)


func _actor(index: int) -> ActorScript:
	return world.actors[index]


func _settle(actor: ActorScript, frames: int = 40) -> void:
	for _i: int in range(frames):
		actor.present(1.0, FRAME)


# --- steering, roll, pitch, yaw ----------------------------------------------------

func _test_body_dynamics() -> void:
	var actor: ActorScript = _actor(4)
	var car: CarScript = actor.car
	car.steer_angle = 0.3
	_settle(actor)
	var front_turn: float = actor.chassis.socket_wheel_fl.rotation.y
	var rear_turn: float = actor.chassis.socket_wheel_rl.rotation.y
	car.steer_angle = -0.3
	_settle(actor)
	var turned_back: float = actor.chassis.socket_wheel_fr.rotation.y
	check(front_turn < -0.25 and rear_turn == 0.0 and turned_back > 0.25 and actor.chassis.socket_wheel_rr.rotation.y == 0.0,
		"steering: a right steer angle turns the front wheels right (%.2f rad) and a left one left (%.2f rad), the rear wheels never turn" % [front_turn, turned_back])
	car.steer_angle = 0.0
	_settle(actor)

	# Right corner: the body leans to the outside (the left), the right side comes up.
	car.chassis_roll = 0.08
	car.chassis_pitch = 0.0
	_settle(actor, 30)
	var right_of_car: Vector3 = actor.global_transform.basis.x
	var up_in_corner: Vector3 = actor.chassis.global_transform.basis.y
	var leans_out: bool = up_in_corner.dot(right_of_car) < -0.05
	car.chassis_roll = -0.08
	_settle(actor, 30)
	var leans_other_way: bool = actor.chassis.global_transform.basis.y.dot(right_of_car) > 0.05
	car.chassis_roll = 0.0
	# Braking: the nose dives. Under power: the tail squats.
	car.chassis_pitch = 0.04
	_settle(actor, 30)
	# The model faces +Z in its own frame, so that axis (turned half a turn) is the nose.
	var nose_braking: Vector3 = actor.chassis.global_transform.basis.z
	var dives: bool = nose_braking.y < -0.02 and nose_braking.dot(-actor.global_transform.basis.z) > 0.9
	car.chassis_pitch = -0.03
	_settle(actor, 30)
	var squats: bool = actor.chassis.global_transform.basis.z.y > 0.01
	car.chassis_pitch = 0.0
	_settle(actor, 30)
	check(leans_out and leans_other_way and dives and squats,
		"body: it rolls to the outside of the corner both ways, dives its nose under braking and squats under power")

	car.yaw_offset = 0.12
	_settle(actor, 30)
	var heading_with_yaw: Vector3 = -actor.global_transform.basis.z
	car.yaw_offset = 0.0
	_settle(actor, 30)
	var heading_straight: Vector3 = -actor.global_transform.basis.z
	var turned: float = heading_straight.signed_angle_to(heading_with_yaw, Vector3.UP)
	check(absf(absf(turned) - 0.12) < 0.02 and turned < 0.0,
		"yaw: a lateral move points the car toward it (+0.12 rad turns right: %.3f rad)" % turned)


## The sim moves the body angles in 20 Hz steps; the drawn car must not twitch with them.
func _test_body_smoothness() -> void:
	var actor: ActorScript = _actor(8)
	var car: CarScript = actor.car
	car.steer_angle = 0.0
	car.chassis_roll = 0.0
	car.chassis_pitch = 0.0
	car.yaw_offset = 0.0
	_settle(actor)
	var right: Vector3 = actor.global_transform.basis.x
	var worst: Dictionary = {"lean": 0.0, "nose": 0.0, "heading": 0.0, "steer": 0.0}
	var last: Dictionary = {"lean": [0.0, 0.0], "nose": [0.0, 0.0], "heading": [0.0, 0.0], "steer": [0.0, 0.0]}
	var peak: Dictionary = {"lean": 0.0, "steer": 0.0}
	for frame: int in range(120):
		# Square wave stepped every 3rd frame, like the sim ticks at 60 fps.
		var high: bool = frame >= 90 or (frame >= 60 and (frame / 3) % 2 == 0)
		car.chassis_roll = 0.08 if high else -0.08
		car.chassis_pitch = 0.04 if high else -0.03
		car.yaw_offset = 0.1 if high else -0.1
		car.steer_angle = 0.3 if high else -0.3
		actor.present(1.0, FRAME)
		var sample: Dictionary = {
			"lean": actor.chassis.global_transform.basis.y.dot(right),
			"nose": actor.chassis.global_transform.basis.z.y,
			"heading": (-actor.global_transform.basis.z).dot(right),
			"steer": actor.chassis.socket_wheel_fl.rotation.y,
		}
		for key: String in sample:
			var pair: Array = last[key]
			if frame >= 4:
				worst[key] = maxf(worst[key], absf(float(sample[key]) - 2.0 * float(pair[1]) + float(pair[0])))
			pair[0] = pair[1]
			pair[1] = sample[key]
		if frame >= 90:
			peak["lean"] = maxf(peak["lean"], absf(float(sample["lean"])))
			peak["steer"] = maxf(peak["steer"], absf(float(sample["steer"])))
	car.chassis_roll = 0.0
	car.chassis_pitch = 0.0
	car.yaw_offset = 0.0
	car.steer_angle = 0.0
	_settle(actor)
	# Step sizes of the square wave: lean 0.16, nose 0.07, heading 0.2, steer 0.6. Unsmoothed, the jerk equals the step.
	var jerk: Dictionary = {"lean": worst["lean"] / 0.16, "nose": worst["nose"] / 0.07, "heading": worst["heading"] / 0.2, "steer": worst["steer"] / 0.6}
	check(jerk["lean"] < 0.1 and jerk["nose"] < 0.1 and jerk["heading"] < 0.1 and jerk["steer"] < 0.1,
		"smooth: 20 Hz steps of roll, pitch, yaw and steer reach the body as soft ramps (frame-to-frame jerk as a share of the step: lean %.2f, nose %.2f, heading %.2f, steer %.2f)" % [jerk["lean"], jerk["nose"], jerk["heading"], jerk["steer"]])
	check(peak["lean"] > 0.07 and peak["steer"] > 0.28,
		"smooth: a held roll and steer still arrive in full (lean %.3f, steer %.2f rad)" % [peak["lean"], peak["steer"]])


# --- lights, DRS --------------------------------------------------------------------

func _test_lights_and_aero() -> void:
	var actor: ActorScript = _actor(5)
	var car: CarScript = actor.car
	var id: int = car.id
	var vfx: RaceVfx = world.vfx
	var tip := vfx.tips[id] as Node3D
	var code := tip.get_node("Code") as Sprite3D
	var status := tip.get_node("Status") as Sprite3D
	var followed: CarScript = world.race.get_car(world.followed_id)
	world.camera.global_position = actor.global_position + Vector3(0.0, 8.0, 30.0)
	car.brake = 0.0
	car.drs_active = false
	_run_vfx(4.0) # let any pass or approach flash expire
	var quiet: bool = vfx.tip_alpha(id) == 0.0 and vfx.tip_status_text(id) == "" and not tip.visible

	# The name tag is a graffiti slab that flashes up for a moment, with its opacity turned down.
	vfx.ping_tip(id)
	vfx.update(0.2)
	var flashed: bool = vfx.tip_alpha(id) == 1.0 and tip.visible and code.modulate.a > 0.5 and code.modulate.a <= RaceVfx.TIP_NAME_OPACITY + 0.001 and code.texture != null
	_run_vfx(1.0)
	var still_up: bool = vfx.tip_alpha(id) == 1.0
	_run_vfx(3.0)
	var gone: bool = vfx.tip_alpha(id) == 0.0 and not tip.visible
	check(quiet and flashed and still_up and gone,
		"tip: the graffiti name tag is hidden at rest, flashes up at %.2f opacity for about %.1f s and fades out again" % [RaceVfx.TIP_NAME_OPACITY, RaceVfx.TIP_HOLD_S])

	# A pass, a new selection and a car coming close each flash it.
	car.position = car.position % 20 + 1
	vfx.update(0.2)
	var after_pass: bool = vfx.tip_alpha(id) > 0.0
	_run_vfx(4.0)
	var rival_id: int = car.id
	var chosen: int = world.followed_id
	world.followed_id = rival_id
	vfx.update(0.2)
	var after_select: bool = vfx.tip_alpha(id) > 0.0
	world.followed_id = chosen
	_run_vfx(4.0)
	world.camera.global_position = actor.global_position + Vector3(0.0, 8.0, 400.0)
	_run_vfx(0.2)
	world.camera.global_position = actor.global_position + Vector3(0.0, 8.0, 30.0)
	vfx.update(0.2)
	var after_approach: bool = vfx.tip_alpha(id) > 0.0
	_run_vfx(4.0)
	check(after_pass and after_select and after_approach, "tip: a position change, being selected and a rival coming within %d m each flash its name tag" % int(RaceVfx.TIP_RANGE_M))

	# The status sticker stays as long as its state does.
	car.drs_active = true
	vfx.update(FRAME)
	var drs_tip: bool = vfx.tip_status_text(id) == "DRS" and status.visible and status.texture != null and tip.visible
	car.drs_active = false
	car.brake = 0.8
	vfx.update(FRAME)
	var rival_quiet: bool = vfx.tip_status_text(id) == ""
	car.brake = 0.0
	followed.brake = 0.8
	vfx.update(FRAME)
	var brake_tip: bool = vfx.tip_status_text(followed.id) == "BRAKE"
	followed.brake = 0.0
	car.pit = GtPit.new()
	vfx.update(FRAME)
	var pit_tip: bool = vfx.tip_status_text(id) == "PIT"
	car.pit = null
	car.is_punctured = true
	var levels: Array[float] = []
	for _i: int in range(40):
		vfx.update(0.02)
		if vfx.tip_status_text(id) == "HAZARD" and not levels.has(status.modulate.a):
			levels.append(status.modulate.a)
	car.is_punctured = false
	_run_vfx(0.2)
	check(drs_tip and rival_quiet and brake_tip and pit_tip and levels.size() == 2 and vfx.tip_status_text(id) == "",
		"tip: a sticker shows DRS, PIT, a blinking HAZARD on a puncture, and BRAKE only on the followed car")

	vfx.ping_tip(id)
	world.camera.global_position = actor.global_position + Vector3(0.0, 1.0, 1.0)
	vfx.update(0.2)
	var hidden_near: bool = not tip.visible
	world.camera.global_position = actor.global_position + Vector3(0.0, 8.0, 400.0)
	vfx.update(0.2)
	var hidden_far: bool = not tip.visible
	world.camera.global_position = actor.global_position + Vector3(0.0, 8.0, 30.0)
	_run_vfx(4.0)
	check(hidden_near and hidden_far and tip.position.y > 2.0 and actor.get_node_or_null("TailLight") == null and actor.get_node_or_null("DrsFlap") == null,
		"tip: it hides when the camera is inside the car or far away, floats above the roof, and no tail bar or wing flap is left on the car")

	# The graffiti slab is laid out from a seed: one hand per car, drips and speckle included.
	var tag_a := GraffitiTag.new()
	var tag_b := GraffitiTag.new()
	var tag_c := GraffitiTag.new()
	var sticker := GraffitiTag.new()
	tag_a.rebuild("RYU", Color("#2ec4b6"), 5)
	tag_b.rebuild("RYU", Color("#2ec4b6"), 5)
	tag_c.rebuild("RYU", Color("#2ec4b6"), 6)
	sticker.rebuild("DRS", Color("#00f0ff"), 3, GraffitiTag.Kind.STATUS)
	check(tag_a.slab == tag_b.slab and tag_a.slab != tag_c.slab and tag_a.drips.size() >= 3 and not tag_a.specks.is_empty() and not tag_a.halftone.is_empty()
			and tag_a.size == GraffitiTag.SIZE_NAME and sticker.size == GraffitiTag.SIZE_STATUS and sticker.drips.is_empty(),
		"tip: the graffiti slab is the same for the same seed and different for another, with %d drips, %d speckles and a halftone band; the status sticker is smaller and drip free" % [tag_a.drips.size(), tag_a.specks.size()])
	for tag: GraffitiTag in [tag_a, tag_b, tag_c, sticker]:
		tag.free()

	var weather: GtWeather = world.race.weather
	weather.time_of_day = WeatherScript.compute_time_of_day(WeatherScript.TimeOfDay.NIGHT, 0.0)
	world.vfx.update(FRAME)
	var night_lamps: bool = world.vfx.head_lights[id][0].visible
	weather.time_of_day = WeatherScript.compute_time_of_day(WeatherScript.TimeOfDay.DAY, 0.0)
	world.vfx.update(FRAME)
	var day_lamps: bool = world.vfx.head_lights[id][0].visible
	check(night_lamps and not day_lamps, "lights: the headlights come on at night and are off by day")


func _run_vfx(seconds: float) -> void:
	var steps: int = ceili(seconds / 0.05)
	for _i: int in range(steps):
		world.vfx.update(0.05)


# --- weather ----------------------------------------------------------------------------

func _test_weather() -> void:
	var weather: GtWeather = world.race.weather
	var vfx: RaceVfx = world.vfx
	weather.rain_intensity = 0.0
	weather.track_water_pct = 0.0
	vfx.update(FRAME)
	var dry_rain: bool = vfx.rain.is_raining()
	var dry_wetness: float = vfx.track_material.get_shader_parameter("track_wetness")
	var dry_energy: float = world.get_node("Sun").light_energy
	var spray_id: int = _actor(3).car.id
	var dry_spray: float = vfx.sprays[spray_id].strength
	weather.rain_intensity = 0.9
	weather.track_water_pct = 85.0
	var car: CarScript = _actor(3).car
	car.v = 60.0
	vfx.update(FRAME)
	var wet_rain: bool = vfx.rain.is_raining()
	var wet_wetness: float = vfx.track_material.get_shader_parameter("track_wetness")
	var wet_energy: float = world.get_node("Sun").light_energy
	var wet_spray: float = vfx.sprays[spray_id].strength
	check(not dry_rain and dry_wetness == 0.0 and dry_spray == 0.0 and wet_rain and is_equal_approx(wet_wetness, 0.85) and wet_spray > 0.3,
		"weather: rain falls and the road mirrors only when the sim is wet (water %.2f), spray flies behind a car at speed (%.2f)" % [wet_wetness, wet_spray])
	check(wet_energy < dry_energy * 0.6,
		"weather: the sun dims under rain (%.2f -> %.2f)" % [dry_energy, wet_energy])
	weather.rain_intensity = 0.0
	weather.track_water_pct = 0.0
	vfx.update(FRAME)


# --- smoke, sparks, pops, slipstream ----------------------------------------------------------

func _test_smoke_sparks_pops() -> void:
	var vfx: RaceVfx = world.vfx
	var actor: ActorScript = _actor(6)
	var car: CarScript = actor.car
	var id: int = car.id
	car.spin_timer = 2.0
	vfx.update(FRAME)
	var smoking_spin: bool = vfx.smokes[id][0].emitting and vfx.smokes[id][1].emitting
	car.spin_timer = 0.0
	car.brake = 0.0
	car.error_timer = 0.0
	car.throttle = 0.5
	vfx.update(FRAME)
	var quiet: bool = not vfx.smokes[id][0].emitting
	check(smoking_spin and quiet, "smoke: both rear wheels smoke in a spin and stop when the car is straight again")

	var contact: Vector3 = world.track.point_at(500.0, 0.0).origin + Vector3.UP * 0.35
	world.race.collision_event.emit({"type": Types.CollisionKind.RUB, "car_a": "A", "car_b": "B", "s": 500.0, "lateral": 0.0, "time": 1.0})
	var at_contact: bool = false
	for burst: GPUParticles3D in vfx.sparks:
		at_contact = at_contact or (burst.emitting and burst.global_position.distance_to(contact) < 0.01)
	check(at_contact and vfx.sparks.size() == RaceVfx.SPARK_POOL, "sparks: a contact fires a burst from the pool of %d at the contact point" % RaceVfx.SPARK_POOL)

	car.gear = 3
	vfx.update(FRAME)
	car.gear = 4 # upshift
	vfx.update(FRAME)
	var popped: bool = vfx.flames[id][0].visible
	for _i: int in range(10):
		vfx.update(0.02)
	var settled: bool = not vfx.flames[id][0].visible
	check(popped and settled, "exhaust: an upshift pops a flame from both tailpipes that dies within a tenth of a second")

	car.slipstream_factor = 0.8
	car.v = 60.0
	vfx.update(FRAME)
	var wake_visible: bool = vfx.wakes[id][0].visible and vfx.wakes[id][1].visible
	car.slipstream_factor = 0.0
	vfx.update(FRAME)
	check(wake_visible and not vfx.wakes[id][0].visible, "slipstream: twin ribbons stream from a car in the tow and vanish when it leaves it")


# --- safety car ------------------------------------------------------------------------------

func _test_safety_car() -> void:
	var vfx: RaceVfx = world.vfx
	var race: GtRace = world.race
	vfx.update(FRAME)
	var hidden: bool = not vfx.safety_car_actor.visible
	race.set_flag(Types.Flag.SC, 1, "SAFETY CAR", 30.0)
	race.step()
	vfx.update(FRAME)
	var leader: CarScript = race.standings()[0]
	var shown: bool = vfx.safety_car_actor.visible
	var ahead: bool = float(race.safety_car["s"]) > leader.s
	var placed: bool = vfx.safety_car_actor.global_position.distance_to(world.track.point_at(float(race.safety_car["s"]), float(race.safety_car["lateral"])).origin) < 0.5
	var official := vfx.safety_car_actor.chassis as SafetyCarChassis
	check(official != null and official.scene_file_path == "res://scenes/car/safety_car_chassis.tscn",
		"safety car: it rides the dedicated FIA safety car chassis, not a borrowed team car")
	if official == null:
		return
	_test_safety_car_livery(official)
	_test_safety_car_deployed(official, race)
	_test_safety_car_in_this_lap(official, race, vfx)
	race.set_flag(Types.Flag.GREEN, 1, "GREEN", 1.0)
	vfx.update(FRAME)
	check(hidden and shown and ahead and placed and not vfx.safety_car_actor.visible,
		"safety car: it appears ahead of the leader while the flag is out and leaves with it")
	check(official.strobe_mode == SafetyCarChassis.StrobeMode.OFF, "safety car: the lightbar goes dark when the car leaves the track")


func _lit(leds: Array[MeshInstance3D]) -> Array[bool]:
	var states: Array[bool] = []
	for led: MeshInstance3D in leds:
		states.append(led.visible)
	return states


func _test_safety_car_livery(official: SafetyCarChassis) -> void:
	var paint := official.base_body_mesh.get_surface_override_material(0) as ShaderMaterial
	var tint: Color = paint.get_shader_parameter("base_color") if paint != null else Color.BLACK
	var lettered: int = 0
	for label: Node in official.find_children("*", "Label3D", true, false):
		lettered += int((label as Label3D).text == "SAFETY CAR")
	check(paint != null and tint.s < 0.15 and tint.v > 0.6, "safety car: the body paint is metallic silver (%s)" % tint)
	check(lettered == 3, "safety car: SAFETY CAR is lettered on both doors and the bonnet (%d labels)" % lettered)
	check(official.find_child("ChevronStripL", true, false) != null and official.find_child("ChevronStripR", true, false) != null,
		"safety car: hazard chevron strips run down both sides")


func _test_safety_car_deployed(official: SafetyCarChassis, race: GtRace) -> void:
	var first: Array[bool] = _lit(official.amber_leds)
	official.advance(0.5 / SafetyCarChassis.STROBE_HZ)
	var second: Array[bool] = _lit(official.amber_leds)
	var toggles: int = 0
	var previous: bool = official.amber_leds[0].visible
	for _i: int in range(480):
		official.advance(1.0 / 480.0)
		toggles += int(official.amber_leds[0].visible != previous)
		previous = official.amber_leds[0].visible
	check(int(race.safety_car["phase"]) == Types.SafetyCarPhase.DEPLOYED and official.strobe_mode == SafetyCarChassis.StrobeMode.AMBER,
		"safety car: while DEPLOYED the lightbar runs the amber strobe")
	check(first.count(true) == 2 and second == first.map(func(on: bool) -> bool: return not on),
		"safety car: the four amber LEDs flash in two alternating pairs (%s then %s)" % [first, second])
	check(absf(float(toggles) * 0.5 - SafetyCarChassis.STROBE_HZ) <= 1.0, "safety car: the amber strobe flashes at 12 Hz (%d toggles in one second)" % toggles)
	check(_lit(official.green_leds).count(true) == 0, "safety car: the green lights stay dark while DEPLOYED")


func _test_safety_car_in_this_lap(official: SafetyCarChassis, race: GtRace, vfx: RaceVfx) -> void:
	race.race_control["sc_laps_remaining"] = 0
	race.race_control["timer"] = 0.0
	race.safety_car["s"] = floorf(float(race.safety_car["s"]) / race.track.length) * race.track.length + 1000.0
	for index: int in range(race.cars.size()):
		var car: GtCar = race.cars[index]
		car.s = float(race.safety_car["s"]) - 14.0 - float(index) * 14.0
		car.is_cleared = car.is_dnf
		car.spin_timer = 0.0
	race._update_race_control(0.0)
	vfx.update(FRAME)
	official.advance(0.3)
	check(int(race.safety_car["phase"]) == Types.SafetyCarPhase.IN_THIS_LAP and official.strobe_mode == SafetyCarChassis.StrobeMode.OFF,
		"safety car: IN_THIS_LAP switches the lightbar off")
	check(_lit(official.amber_leds).count(true) == 0 and _lit(official.green_leds).count(true) == 0,
		"safety car: withdrawal extinguishes amber; green is not a restart signal")
