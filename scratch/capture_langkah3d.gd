extends SceneTree

## FASE 11 Langkah 3d report screenshots: the ribbon weather chip with its 8 lap ladder and the weather deck, in
## a dry race, a coming-rain race, a race about to finish and a second team colour. Needs a GPU (not --headless):
##   Godot --path . --resolution 1920x1080 --script res://scratch/capture_langkah3d.gd -- [out_dir]

const WorldScene := preload("res://scenes/race_weekend_world.tscn")
const DirectorScript := preload("res://scripts/world/weekend/race_weekend_director.gd")

const FRAME: float = 1.0 / 60.0
const CROP := Rect2i(980, 0, 640, 350)

var world: Node3D
var hud: RaceHud
var race: GtRace
var out_dir: String = "res://executor-report/screenshots/phases"


func _initialize() -> void:
	call_deferred("_run")


func _save(file_name: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	var image: Image = root.get_texture().get_image().get_region(CROP)
	print("saved ", file_name, " err=", image.save_png("%s/%s.png" % [out_dir, file_name]))


func _frames(count: int) -> void:
	for _i: int in range(count):
		hud.refresh_all()
		await process_frame


## Rain on the way: dry for 3 laps, drizzle (water 30) at L+4, a downpour (water 70) from L+5.
func _rain_coming(lead: int) -> void:
	var rows: Array[Dictionary] = []
	for k: int in range(1, 13):
		var rain: float = 0.0 if k < 4 else (0.3 if k == 4 else 0.9)
		var water: float = 3.0 if k < 4 else (30.0 if k == 4 else 70.0)
		rows.append({"lap": lead + k, "rain_intensity": rain, "water_pct": water, "cloud_cover": 0.4, "wind_speed": 14.0})
	race.weather.forecast = rows
	race.weather.rain_intensity = 0.0
	race.weather.track_water_pct = 3.0


func _dry(lead: int) -> void:
	var rows: Array[Dictionary] = []
	for k: int in range(1, 13):
		rows.append({"lap": lead + k, "rain_intensity": 0.0, "water_pct": 3.0, "cloud_cover": 0.2, "wind_speed": 8.0})
	race.weather.forecast = rows
	race.weather.rain_intensity = 0.0
	race.weather.track_water_pct = 3.0


func _run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() > 0:
		out_dir = args[0]
	world = WorldScene.instantiate()
	root.add_child(world)
	world.set_process(false)
	await process_frame
	race = world.race
	race.incidents_enabled = false
	world.director._enter(DirectorScript.State.GREEN_RACING)
	for _i: int in range(60 * 6):
		world.step(FRAME)
	hud = world.hud
	var lead: int = hud.leader_lap()
	race.laps = lead + 30

	_dry(lead)
	await _frames(20)
	await _save("phase-11-langkah-3d-chip-dry")
	hud.weather_deck.set_open(true)
	await _frames(20)
	await _save("phase-11-langkah-3d-deck-dry")
	hud.weather_deck.set_open(false)

	_rain_coming(lead)
	await _frames(20)
	await _save("phase-11-langkah-3d-chip-rain-coming")
	hud.weather_deck.set_open(true)
	await _frames(20)
	await _save("phase-11-langkah-3d-deck-rain-coming")
	hud.weather_deck.set_open(false)

	race.laps = lead + 2
	await _frames(20)
	await _save("phase-11-langkah-3d-chip-last-laps")
	race.laps = lead + 30

	hud.set_team_accent(2)
	hud.weather_deck.set_open(true)
	await _frames(20)
	await _save("phase-11-langkah-3d-deck-team2")
	quit()
