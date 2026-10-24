extends SceneTree

## FASE 11 Langkah 3a acceptance: the pit wall mechanics of the redesigned HUD (MANUAL / AUTO desk,
## the 10 s suggestion window, cancelling a box call, the two-state BOX button, the burn bar and the
## B / ESC / ENTER keys). Radio two-way flow is added in Langkah 3e.
## Run: Godot --headless --path . -s res://tests/test_pit_deck_and_radio.gd

const WorldScene := preload("res://scenes/race_weekend_world.tscn")
const DirectorScript := preload("res://scripts/world/race_weekend_director.gd")
const ActorScript := preload("res://scripts/car/gt_car_actor.gd")
const FRAME: float = 1.0 / 60.0

var failures: int = 0
var assertions: int = 0
var world: Node3D
var hud: RaceHud
var race: GtRace
var mine: Array[GtCar] = []


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
	_test_desk_modes_and_suggestion_window()
	race.dispose()
	world.queue_free()
	await process_frame
	ActorScript._paint_cache.clear()
	print("%d assertions, %d failure(s)" % [assertions, failures])
	print("FASE 11 LANGKAH 3A PIT MECHANICS: %s" % ("PASS" if failures == 0 else "%d FAILURES" % failures))
	quit(0 if failures == 0 else 1)


## Clean slate for one pit wall scenario: no card, no cooldowns, quiet cars (an empty battery and cool
## tyres keep the advisor from raising an ERS or pace card that would replace the one under test).
func _reset(mode: int) -> GtCar:
	race.latest_suggestion = {}
	race._suggestion_cooldowns.clear()
	race.set_tactic_mode(mode)
	for car: GtCar in mine:
		car.pit_request = -1
		car.ers_battery = 0.0
		car.tyre_temp = 90.0
	return mine[0]


func _suggest_box(car: GtCar) -> void:
	race.suggest_tactic(car, GtTypes.TacticType.PIT, GtTypes.Compound.HARD, "BOX FOR HARD", "Suggest box this lap.")


# --- desk modes and the 10 s suggestion window ------------------------------------------------------------

func _test_desk_modes_and_suggestion_window() -> void:
	check(GtTypes.TacticMode.size() == 2 and race.tactic_mode == GtTypes.TacticMode.MANUAL,
		"desk: only MANUAL and AUTO exist and MANUAL is the default")

	var car: GtCar = _reset(GtTypes.TacticMode.MANUAL)
	_suggest_box(car)
	var full: bool = is_equal_approx(race.suggestion_remaining(), GtRace.SUGGESTION_WINDOW_S)
	race.time += 5.0
	var half: bool = absf(race.suggestion_remaining() - 5.0) < 0.001
	race.time += 5.1
	race.step()
	check(full and half and race.latest_suggestion.is_empty() and car.pit_request < 0,
		"suggestion: in MANUAL the card closes at 0.0 s and nothing is executed")

	car = _reset(GtTypes.TacticMode.AUTO)
	_suggest_box(car)
	race.time += GtRace.SUGGESTION_WINDOW_S + 0.1
	race.step()
	check(car.pit_request == GtTypes.Compound.HARD and race.latest_suggestion.is_empty(),
		"suggestion: in AUTO the card locks and executes at 0.0 s")

	car = _reset(GtTypes.TacticMode.AUTO)
	car.pit_request = GtTypes.Compound.SOFT
	_suggest_box(car)
	race.time += GtRace.SUGGESTION_WINDOW_S + 0.1
	race.step()
	check(car.pit_request == GtTypes.Compound.SOFT and race.latest_suggestion.is_empty(),
		"suggestion: AUTO never double-calls a car that is already boxing")

	car = _reset(GtTypes.TacticMode.MANUAL)
	_suggest_box(car)
	race.time += 6.0
	race.suggest_tactic(car, GtTypes.TacticType.PACE, GtTypes.PaceMode.CONSERVE, "PACE: CONSERVE", "Save the tyres.")
	check(race.suggestion_remaining() > GtRace.SUGGESTION_WINDOW_S - 0.1,
		"suggestion: a replacement card restarts the 10 s window")

	car = _reset(GtTypes.TacticMode.AUTO)
	_suggest_box(car)
	race.time += 9.9
	var radio_before: int = race.radio_history.size()
	race.accept_suggestion()
	race.time += 0.3
	race.step()
	var box_calls: int = 0
	for index: int in range(radio_before, race.radio_history.size()):
		if String(race.radio_history[index]["text"]).begins_with("Box this lap"):
			box_calls += 1
	check(car.pit_request == GtTypes.Compound.HARD and race.latest_suggestion.is_empty() and box_calls == 1,
		"suggestion: accepting at 9.9 s calls the stop once, the window end does not call it again (box calls: %d)" % box_calls)
