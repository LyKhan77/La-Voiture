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
	_test_hud_accent()
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
