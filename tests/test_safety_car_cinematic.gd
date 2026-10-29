extends SceneTree

const Circuit := preload("res://scenes/race_world/track_circuit.tscn")
const Race := preload("res://scripts/gt/gt_race.gd")
const Track := preload("res://scripts/gt/gt_track.gd")
const Types := preload("res://scripts/gt/gt_types.gd")
const WorldScene := preload("res://scenes/race_weekend_world.tscn")

var checks: int = 0
var failures: int = 0


func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
	print("[%s] %s" % ["PASS" if ok else "FAIL", message])


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var circuit := Circuit.instantiate()
	root.add_child(circuit)
	var track := Track.new(circuit, 14.0)
	var race := Race.new(track, 10, 42, 0)
	race.incidents_enabled = false
	race.set_flag(Types.Flag.SC, 1, "SAFETY CAR DEPLOYED", 30.0)
	check(float(race.safety_car["lateral"]) > 5.0, "SC deploys from pit exit, outside track")
	var previous: float = float(race.safety_car["lateral"])
	var monotonic: bool = true
	for tick: int in range(240):
		race.step()
		var lateral: float = float(race.safety_car["lateral"])
		monotonic = monotonic and lateral <= previous + 0.01
		previous = lateral
		if float(race.safety_car["s"]) >= 219.0:
			break
	check(monotonic, "Pit exit merge decreases monotonically")
	check(previous < 0.5, "SC reaches track center after merge")
	_prepare_withdrawal(race, 3700.0)
	race.safety_car["s"] = 3860.0
	race._update_race_control(0.0)
	check(float(race.safety_car["lateral"]) > 2.0, "SC peels toward pit on in-lap")
	_test_trajectory_boundaries(race, track)
	_test_renewed_caution(race, track)
	_test_baseline_rules(track)
	_test_caution_order(track)
	_test_review_regressions(track)
	_test_caution_coach(track)
	race.dispose()
	circuit.queue_free()
	await process_frame
	await _test_presentation()
	print("%d assertions, %d failure(s)" % [checks, failures])
	quit(1 if failures > 0 else 0)


func _test_trajectory_boundaries(race: GtRace, track: GtTrack) -> void:
	check(not bool(race.safety_car["lights_on"]), "In-lap disables amber strobes")
	race.safety_car["s"] = 3960.0
	race._update_race_control(0.0)
	check(is_equal_approx(float(race.safety_car["lateral"]), 11.6), "Peel-off reaches fast lane")
	race.race_control["timer"] = 0.0
	race._update_race_control(0.0)
	check(bool(race.safety_car["active"]), "Expired timer cannot hide SC before leader restart line")
	race.safety_car["s"] = track.length + 10.0
	race._update_race_control(0.0)
	check(is_equal_approx(float(race.safety_car["lateral"]), 11.6), "Pit lateral survives lap wrap")
	race.safety_car["s"] = track.length + 150.0
	race._update_race_control(0.0)
	check(float(race.safety_car["s"]) <= track.length + 90.0, "Withdrawn SC waits inside pit before exit ramp")
	check(is_zero_approx(float(race.safety_car["v"])), "Withdrawn SC stops while awaiting distant leader restart")
	race.set_flag(Types.Flag.YELLOW, 1, "YELLOW", 1.0)
	check(int(race.race_control["flag"]) == Types.Flag.SC, "SC retains flag priority throughout in-lap")
	for car: GtCar in race.cars:
		car.s = track.length + 1.0 - float(car.id) * 15.0
	race._update_race_control(1.01)
	check(int(race.race_control["flag"]) == Types.Flag.GREEN, "Restart goes green after leader crosses line")
	check(not bool(race.safety_car["active"]), "SC hidden only after peel-off and restart")
	race.set_flag(Types.Flag.SC)
	_prepare_withdrawal(race, 3700.0)
	race.safety_car["s"] = 3960.0
	race._update_race_control(0.0)
	race.race_control["timer"] = 0.0
	for index: int in range(race.cars.size()):
		race.cars[index].s = track.length - float(index) * 15.0 - 14.0
	race.cars[0].s = track.length + 1.0
	race.cars[0].finished_at = 100.0
	race._update_race_control(0.0)
	check(int(race.race_control["flag"]) == Types.Flag.GREEN, "Finishing leader still releases restart at the line")
	race.cars[0].finished_at = -1.0
	for leader_s: float in [0.0, 100.0, 219.0, 500.0, track.length + 500.0]:
		race.set_flag(Types.Flag.GREEN)
		for car: GtCar in race.cars:
			car.s = leader_s - float(car.id) * 15.0
		race.set_flag(Types.Flag.SC)
		check(float(race.safety_car["s"]) > leader_s, "Deployment stays ahead at leader s=%.1f" % leader_s)
		check(is_equal_approx(float(race.safety_car["lateral"]), 11.6), "Deployment always starts on pit ramp at leader s=%.1f" % leader_s)
	if not race.has_method("sc_pit_exit_lateral"):
		check(false, "Trajectory helpers available")
		return
	for fixture: Array in [[90.0, 11.6], [120.0, 8.4], [150.0, 5.2], [185.0, 2.6], [220.0, 0.0]]:
		check(absf(float(race.call("sc_pit_exit_lateral", fixture[0])) - float(fixture[1])) < 0.001, "Exit spline matches hand-calculated s=%.0f" % fixture[0])
	for fixture: Array in [[3820.0, 0.0], [3860.0, 2.6], [3900.0, 5.2], [3930.0, 8.4], [3960.0, 11.6]]:
		check(absf(float(race.call("sc_pit_entry_lateral", fixture[0])) - float(fixture[1])) < 0.001, "Entry spline matches hand-calculated s=%.0f" % fixture[0])


func _test_renewed_caution(race: GtRace, track: GtTrack) -> void:
	for entry_s: float in [3700.0, 3920.0]:
		race.set_flag(Types.Flag.GREEN)
		for index: int in range(race.cars.size()):
			race.cars[index].s = entry_s - 50.0 - float(index) * 15.0
		race.set_flag(Types.Flag.SC)
		_prepare_withdrawal(race, 3700.0)
		race.safety_car["s"] = entry_s
		race._update_race_control(0.0)
		race.set_flag(Types.Flag.SC, 1, "NEW INCIDENT", 10.0)
		check(int(race.safety_car["phase"]) == Types.SafetyCarPhase.DEPLOYED and bool(race.safety_car["lights_on"]), "Renewed caution restores amber at s=%.0f" % entry_s)
		if entry_s < 3820.0:
			race.safety_car["s"] = 3960.0
			race._update_race_control(0.0)
			check(float(race.safety_car["lateral"]) < 2.0, "Renewed caution before pit entry cancels withdrawal")
		else:
			race.safety_car["s"] = track.length + 30.0
			race.race_control["timer"] = 0.0
			race.cars[0].s = track.length + 1.0
			race._update_race_control(0.0)
			check(int(race.race_control["flag"]) == Types.Flag.SC, "Renewed caution after entry cannot release green")
			check(is_equal_approx(float(race.safety_car["lateral"]), 11.6), "Renewed caution remains in pit lane until exit")
			race.safety_car["s"] = track.length + 185.0
			race._update_race_control(0.0)
			check(absf(float(race.safety_car["lateral"]) - 2.6) < 0.001, "Renewed SC merges through upcoming pit exit")
	race.set_flag(Types.Flag.GREEN)
	for index: int in range(race.cars.size()):
		race.cars[index].s = 3800.0 - float(index) * 15.0
	race.set_flag(Types.Flag.SC)
	race.safety_car["s"] = 3930.0
	race.safety_car["lateral"] = 0.0
	race.race_control["sc_laps_remaining"] = 0
	race._update_race_control(0.0)
	check(absf(float(race.safety_car["lateral"])) < 1.5, "Late in-lap call cannot jump sideways midway through entry")
	check(int(race.safety_car["phase"]) == Types.SafetyCarPhase.DEPLOYED, "Late in-lap call waits without misleading IN THIS LAP announcement")


func _test_presentation() -> void:
	var world := WorldScene.instantiate()
	world.total_laps = 3
	root.add_child(world)
	world.set_process(false)
	world.race.incidents_enabled = false
	_test_smooth_motion(world)
	world.set_time_scale(16.0)
	world.step(1.0 / 60.0)
	var state: Dictionary = world.race.safety_car
	var previous_tick_s: float = float(state["prev_s"])
	check(float(state["s"]) - previous_tick_s < 2.0, "16x presentation keeps final two simulation ticks, not whole rendered-frame movement")
	world.vfx.update(0.001, 0.25)
	world.vfx.update(0.001, 0.75)
	check(is_equal_approx(float(state["prev_s"]), previous_tick_s), "Presentation never overwrites simulation snapshots")
	world.set_time_scale(1.0)
	world.race.set_flag(Types.Flag.GREEN)
	var director: BroadcastCameraDirector = world.camera_director
	check(director.has_method("trigger_safety_car_cut"), "Camera supports Safety Car cut-in")
	check(ResourceLoader.exists("res://scripts/hud/safety_car_banner.gd"), "Manga banner available")
	if not director.has_method("trigger_safety_car_cut") or not ResourceLoader.exists("res://scripts/hud/safety_car_banner.gd"):
		world.queue_free()
		await process_frame
		return
	world.race.set_flag(Types.Flag.SC)
	check(director.active_mode() == 5, "World flag signal starts SC camera")
	var banner: Control = world.hud.get("sc_banner")
	check(banner.visible, "World flag signal shows manga banner")
	check("SAFETY CAR" in String(banner.get("header_label").text), "Banner identifies Safety Car")
	world.step(0.1)
	var actor: Node3D = world.vfx.safety_car_actor
	check(world.camera.global_position.distance_to(actor.global_position) < 25.0, "First camera frame uses current SC pose")
	check(absf(world.camera.fov - 65.0) < 0.01, "SC tracking shot uses 65 degree lens")
	director.update(3.8)
	check(director.active_mode() == 5, "Cut-in remains active before four seconds")
	director.update(0.11)
	check(director.active_mode() == 0, "Cut-in restores CHASE after four seconds")
	director.set_mode(2)
	director.call("trigger_safety_car_cut", actor, 0.2)
	director.update(0.21)
	check(director.active_mode() == 2, "Cut-in preserves previous manual mode")
	director.pit_focus = Transform3D.IDENTITY
	director.call("trigger_safety_car_cut", actor, 0.2)
	check(director.active_mode() == 5, "SC cinematic takes priority over automatic pit camera")
	director.update(0.21)
	check(director.active_mode() == 4, "Pit camera resumes after cinematic")
	director.pit_focus = null
	for _i: int in range(5):
		director.cycle()
		if director.active_mode() == 5:
			break
	check(director.active_mode() == 5, "C cycles to SC camera while actor active")
	for index: int in range(world.race.cars.size()):
		world.race.cars[index].s = -500.0 - float(index) * 30.0
	world.race.cars[0].s = 500.0
	world.race.cars[1].s = 80.0
	world.race.safety_car["s"] = world.track.length + 90.0
	world.race.safety_car["picked_up"] = false
	world.race._update_race_control(0.0)
	world.vfx.update(0.01)
	var official: SafetyCarChassis = actor.chassis
	check(official.strobe_mode == SafetyCarChassis.StrobeMode.AMBER_GREEN, "Pickup permission illuminates green while preserving amber mode")
	check(official.amber_leds.any(func(led: MeshInstance3D) -> bool: return led.visible) and official.green_leds.all(func(led: MeshInstance3D) -> bool: return led.visible), "Pickup pass signal visibly combines amber and green LEDs")
	official.advance(0.03)
	var strobe_clock: float = official._clock
	world.vfx.update(0.01)
	check(is_equal_approx(official._clock, strobe_clock), "Repeated pickup presentation does not reset strobe animation")
	_prepare_withdrawal(world.race, 1000.0)
	world.step(0.01)
	check("IN THIS LAP" in String(banner.get("header_label").text), "HUD detects in-lap phase separately from flag")
	check(official.strobe_mode == SafetyCarChassis.StrobeMode.OFF, "In-lap is lights out; green is reserved for pickup permission")
	world.hud.update(3.81)
	check(not banner.visible, "Manga banner expires after 3.8 seconds")
	world.hud.update(0.01)
	check(not banner.visible, "In-lap banner does not retrigger each frame")
	world.race.set_flag(Types.Flag.GREEN)
	world.step(0.01)
	check(director.active_mode() != 5, "Hidden SC cannot retain manual camera")
	check(not actor.visible, "Green flag hides SC actor")
	world.queue_free()
	await process_frame
	await process_frame


func _test_smooth_motion(world: RaceWeekendWorld) -> void:
	world.director._enter(world.director.State.GREEN_RACING)
	for hz: int in [30, 60, 120]:
		world.race.set_flag(Types.Flag.GREEN)
		for index: int in range(world.race.cars.size()):
			world.race.cars[index].s = -8.0 - float(index) * 12.0
			world.race.cars[index].prev_s = world.race.cars[index].s
		world.race.set_flag(Types.Flag.SC)
		var spawn: Vector3 = world.track.point_at(float(world.race.safety_car["s"]), float(world.race.safety_car["lateral"])).origin
		world.step(1.0 / float(hz))
		check(world.vfx.safety_car_actor.global_position.distance_to(spawn) < 1.0, "First deployment frame snaps to pit ramp at %dHz" % hz)
		var position: Vector3 = world.vfx.safety_car_actor.global_position
		var frozen: int = 0
		var largest: float = 0.0
		for frame: int in range(hz * 2):
			world.step(1.0 / float(hz))
			var next: Vector3 = world.vfx.safety_car_actor.global_position
			var moved: float = position.distance_to(next)
			if frame > hz / 5:
				frozen += 1 if moved < 0.0001 else 0
				largest = maxf(largest, moved)
			position = next
		check(frozen == 0, "SC has no stationary-frame pattern at %dHz (%d frozen)" % [hz, frozen])
		check(largest < 35.0 / float(hz), "SC frame movement bounded at %dHz (%.3fm)" % [hz, largest])
		var forward: Vector3 = -world.vfx.safety_car_actor.global_basis.z
		var track_pose: Transform3D = world.track.point_at(float(world.race.safety_car["s"]))
		check(forward.dot(track_pose.basis.x) < -0.01, "SC heading follows leftward pit merge at %dHz" % hz)


func _place_queue(race: GtRace, sc_s: float) -> void:
	race.safety_car["s"] = sc_s
	for index: int in range(race.cars.size()):
		var car: GtCar = race.cars[index]
		car.s = sc_s - 14.0 - float(index) * 14.0
		car.prev_s = car.s
		car.v = 25.0
		car.lap = floori(car.s / race.track.length)
		car.position = index + 1
		car.pit = null
		car.pit_request = -1


func _prepare_withdrawal(race: GtRace, sc_s: float) -> void:
	_place_queue(race, sc_s)
	race.safety_car["exit_end_s"] = floorf(sc_s / race.track.length) * race.track.length + 220.0
	race.race_control["timer"] = 0.0
	race.race_control["sc_laps_remaining"] = 0
	race._update_race_control(0.0)


func _test_baseline_rules(track: GtTrack) -> void:
	var race := Race.new(track, 5, 41, 0, 3)
	check(race.cars.size() == 3, "Odd three-car grid allocates enough team entries")
	if race.cars.size() != 3:
		race.dispose()
		return
	race.incidents_enabled = false
	race.set_flag(Types.Flag.SC, 1, "SC", 0.0)
	_place_queue(race, 1000.0)
	race.race_control["sc_laps_remaining"] = 0
	race.cars[2].s -= 300.0
	race._update_race_control(0.0)
	check(int(race.safety_car["phase"]) == Types.SafetyCarPhase.DEPLOYED, "Incomplete field queue blocks withdrawal")
	_place_queue(race, 1100.0)
	race.cars[2].is_dnf = true
	race.cars[2].is_cleared = false
	race._update_race_control(0.0)
	check(int(race.safety_car["phase"]) == Types.SafetyCarPhase.DEPLOYED, "Uncleared retirement blocks withdrawal")
	race.cars[2].is_cleared = true
	race._update_race_control(0.0)
	check(int(race.safety_car["phase"]) == Types.SafetyCarPhase.IN_THIS_LAP, "Safe track and collected queue allow withdrawal")
	race.set_flag(Types.Flag.GREEN)
	race.set_flag(Types.Flag.SC, 1, "SC", 0.0)
	_place_queue(race, 3930.0)
	race.race_control["sc_laps_remaining"] = 0
	race._update_race_control(0.0)
	check(int(race.safety_car["phase"]) == Types.SafetyCarPhase.DEPLOYED, "Late call does not announce IN THIS LAP after approach passed")
	check(race.has_method("restart_pending") and race.has_method("sc_may_pass"), "Race exposes per-car restart and pickup permission")
	if not race.has_method("restart_pending") or not race.has_method("sc_may_pass"):
		race.dispose()
		return
	race.cars[2].is_dnf = false
	race.set_flag(Types.Flag.GREEN)
	for car: GtCar in race.cars:
		car.s = 500.0 - float(car.position) * 15.0
	race.set_flag(Types.Flag.SC, 1, "SC", 0.0)
	race.safety_car["s"] = track.length + 90.0
	race.cars[0].s = 500.0
	race.cars[1].s = 80.0
	race.cars[2].s = 60.0
	race._update_race_control(0.0)
	check(bool(race.call("sc_may_pass", race.cars[1])) and not bool(race.call("sc_may_pass", race.cars[0])), "Mid-pack pickup permits nonleader past SC, not leader")
	check(bool(race.safety_car.get("wave_by", false)), "Pickup pass permission drives green signal")
	_place_queue(race, track.length + 500.0)
	race.race_control["sc_laps_remaining"] = 0
	race._update_race_control(0.0)
	check(not bool(race.safety_car.get("wave_by", true)), "Green pickup signal goes off after leader collected")
	race.safety_car["s"] = track.length + 3960.0
	race._update_race_control(0.0)
	race.cars[0].s = track.length * 2.0 + 1.0
	race.cars[1].s = track.length * 2.0 - 15.0
	race._update_race_control(0.0)
	check(int(race.race_control["flag"]) == Types.Flag.GREEN, "Normal withdrawal releases global green at leader line")
	check(not bool(race.call("restart_pending", race.cars[0])) and bool(race.call("restart_pending", race.cars[1])), "Trailing car retains own control-line restriction after global green")
	race.cars[1].s = track.length * 2.0 + 1.0
	check(not bool(race.call("restart_pending", race.cars[1])), "Trailing car releases restart restriction at its own line")
	race.set_flag(Types.Flag.SC, 1, "SC", 0.0)
	_place_queue(race, track.length * 4.0 + 500.0)
	race.race_control["sc_laps_remaining"] = 0
	race._update_race_control(0.0)
	race.safety_car["s"] = track.length * 4.0 + 3960.0
	race._update_race_control(0.0)
	race.cars[0].s = track.length * 5.0 + 1.0
	race._update_race_control(0.0)
	check(int(race.race_control["flag"]) == Types.Flag.SC, "Caution on final lap finishes without artificial GREEN")
	race.dispose()


func _test_caution_order(track: GtTrack) -> void:
	var race := Race.new(track, 5, 51, 0, 2)
	race.incidents_enabled = false
	for flag: int in [Types.Flag.SC, Types.Flag.GREEN]:
		race.set_flag(Types.Flag.GREEN)
		if flag == Types.Flag.SC:
			race.set_flag(Types.Flag.SC, 1, "SC", 60.0)
		var front: GtCar = race.cars[0]
		var rear: GtCar = race.cars[1]
		front.s = 500.0
		front.v = 2.0
		rear.s = 490.0
		rear.v = 80.0
		for car: GtCar in race.cars:
			car.prev_s = car.s
			car.lap = 0
			car.lateral = 0.0
			car.prev_lateral = 0.0
			car.sc_restart_line_s = track.length
		var kept_order: bool = true
		var nonnegative: bool = true
		for tick: int in range(30):
			var previous: float = rear.s
			race.step()
			kept_order = kept_order and rear.s < front.s
			nonnegative = nonnegative and rear.s >= previous - 0.0001
		check(kept_order, "High closing speed cannot overtake before own restart line (flag %d)" % flag)
		check(nonnegative, "Caution order enforcement never rewinds car progress (flag %d)" % flag)
		race.set_flag(Types.Flag.GREEN)
	front_and_rear_release(race)
	race.dispose()


func front_and_rear_release(race: GtRace) -> void:
	for car: GtCar in race.cars:
		car.s = race.track.length + 10.0 + float(car.id) * 30.0
		car.sc_restart_line_s = race.track.length
	check(not race.is_under_caution(race.cars[0]) and not race.is_under_caution(race.cars[1]), "All cars resume racing after individual control-line crossings")


func _test_review_regressions(track: GtTrack) -> void:
	var race := Race.new(track, 5, 61, 0, 20)
	race.incidents_enabled = false
	race.set_flag(Types.Flag.SC, 1, "SC", 0.0)
	_prepare_withdrawal(race, track.length + 230.0)
	var tail: GtCar = race.cars[-1]
	check(absf(tail.sc_restart_line_s - track.length * 2.0) < 0.01, "Queue spanning control line retains actual withdrawal restart lap")
	tail.s = track.length + 1.0
	race.set_flag(Types.Flag.GREEN)
	check(race.restart_pending(tail), "Intermediate line crossing cannot release tail one lap early")
	race.dispose()

	race = Race.new(track, 5, 62, 0, 1)
	race.incidents_enabled = false
	race.set_flag(Types.Flag.SC, 1, "SC", 0.0)
	_prepare_withdrawal(race, 1000.0)
	race.cars[0].pace_mode = Types.PaceMode.ATTACK
	var stayed_behind: bool = true
	for tick: int in range(400):
		race.step()
		stayed_behind = stayed_behind and race.cars[0].s < float(race.safety_car["s"])
	check(stayed_behind, "ATTACK leader cannot pass in-lap SC before pit separation")
	race.dispose()
	race = Race.new(track, 5, 63, 0, 3)
	check(race.cars.size() == 3, "Three-car contact regression receives a complete grid")
	if race.cars.size() != 3:
		race.dispose()
		return
	race.incidents_enabled = false
	race.set_flag(Types.Flag.SC, 1, "SC", 0.0)
	for index: int in range(3):
		var car: GtCar = race.cars[index]
		car.s = [100.0, 96.0, 95.9][index]
		car.prev_s = car.s
		car.v = 0.0
		car.lateral = 4.5 if index == 2 else 0.0
		car.prev_lateral = car.lateral
		car.lap = 0
	race.step()
	check(race.cars[1].s > race.cars[2].s, "Contact correction cannot reverse three-car caution order")
	check(race.cars[1].s >= 96.0, "Contact correction preserves nonnegative caution progress")
	race.race_control["sc_laps_remaining"] = 1
	race.cars[0].s = track.length + 1.0
	race.cars[0].lap = 0
	race.track_laps(race.cars[0])
	check(not "IN THIS LAP" in String(race.race_control["message"]), "Minimum lap countdown cannot announce withdrawal without safety gates")
	race.dispose()
	race = Race.new(track, 5, 64, 0, 1)
	race.incidents_enabled = false
	race.set_flag(Types.Flag.SC, 1, "SC", 60.0)
	_place_queue(race, 1000.0)
	race.safety_car["v"] = 18.0
	race._update_race_control(0.05)
	check(float(race.safety_car["v"]) - 18.0 <= 3.0 * 0.05 + 0.0001, "Pickup acceleration stays within 3m/s² without velocity kick")
	_prepare_withdrawal(race, 3805.0)
	check(int(race.safety_car["phase"]) == Types.SafetyCarPhase.DEPLOYED, "Late withdrawal waits until complete racing-line alignment is available")
	race.dispose()


func _test_caution_coach(track: GtTrack) -> void:
	var race := Race.new(track, 5, 71, 0, 2)
	race.incidents_enabled = false
	race.weather.track_water_pct = 0.0
	race.weather.rain_intensity = 0.0
	for index: int in range(2):
		var car: GtCar = race.cars[index]
		car.s = 510.0 - float(index) * 10.0
		car.lap = 0
		car.compound = Types.Compound.MEDIUM
		car.wear = 0.0
		car.damage = 0.0
		car.tyre_temp = 90.0
	race.player_team_id = race.cars[1].team_id
	race.set_flag(Types.Flag.SC)
	race._check_advisor_tactics()
	check(race.latest_suggestion.is_empty(), "Coach cannot advise overtaking while Safety Car is deployed")
	race.latest_suggestion = {}
	race._suggestion_cooldowns.clear()
	race.set_flag(Types.Flag.GREEN)
	for car: GtCar in race.cars:
		car.sc_restart_line_s = track.length
	race._check_advisor_tactics()
	check(race.latest_suggestion.is_empty(), "Coach cannot advise overtaking before individual restart line")
	race.latest_suggestion = {}
	race._suggestion_cooldowns.clear()
	for car: GtCar in race.cars:
		car.sc_restart_line_s = -1.0
	race._check_advisor_tactics()
	check(not race.latest_suggestion.is_empty() and int(race.latest_suggestion["type"]) == Types.TacticType.ERS, "Coach resumes valid overtake advice after restart restrictions end")
	race.dispose()
