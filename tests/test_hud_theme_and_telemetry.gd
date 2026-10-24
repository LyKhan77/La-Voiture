extends SceneTree

## FASE 11 Langkah 3b acceptance: the team accent that skins the race HUD and the concept F telemetry drawer
## (state, onomatopoeia, caption, drawing). Data colours never follow the accent.
## Run: Godot --headless --path . -s res://tests/test_hud_theme_and_telemetry.gd

const WorldScene := preload("res://scenes/race_weekend_world.tscn")
const DirectorScript := preload("res://scripts/world/race_weekend_director.gd")
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
	_test_engineer_colour()
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
