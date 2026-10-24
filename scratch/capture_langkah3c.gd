extends SceneTree

## FASE 11 Langkah 3c report screenshots: the N2 faders console in several states (clean, tooltip, BOX
## armed, other team colours, COACH off, a critical tyre). Needs a GPU (not --headless):
##   Godot --path . --resolution 1920x1080 --script res://scratch/capture_langkah3c.gd -- [out_dir]

const WorldScene := preload("res://scenes/race_weekend_world.tscn")
const DirectorScript := preload("res://scripts/world/race_weekend_director.gd")

const FRAME: float = 1.0 / 60.0
const CROP := Rect2i(0, 740, 1920, 340)

var world: Node3D
var hud: RaceHud
var deck: TacticalDeck
var race: GtRace
var car: GtCar
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
		car.lap = maxi(car.lap, 1)
		car.v = 70.0
		hud.refresh_all()
		await process_frame


## A mid-race car with known numbers: MEDIUM, `wear` worn, 30 laps to go, a healthy tank and battery.
func _setup_car(wear: float) -> void:
	race.laps = 30
	car.compound = GtTypes.Compound.MEDIUM
	car.tyre_wear_rate = 1.0
	car.wear = wear
	car.fuel_use = 3.0
	car.fuel = 110.0
	car.ers_battery = 72.0
	car.pace_mode = GtTypes.PaceMode.STANDARD
	car.fuel_mode = GtTypes.FuelMode.STANDARD
	car.ers_mode = GtTypes.ErsMode.NEUTRAL
	car.pit_request = -1


func _run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() > 0:
		out_dir = args[0]
	world = WorldScene.instantiate()
	root.add_child(world)
	world.set_physics_process(false)
	await process_frame
	race = world.race
	race.incidents_enabled = false
	world.director._enter(DirectorScript.State.GREEN_RACING)
	for _i: int in range(60 * 6):
		world.step(FRAME)
	hud = world.hud
	deck = hud.deck
	for candidate: GtCar in race.cars:
		if candidate.team_id == race.player_team_id:
			car = candidate
			break
	world.followed_id = car.id
	deck.deck_car_id = car.id

	_setup_car(0.36)
	await _frames(30)
	await _save("phase-11-langkah-3c-deck-clean")

	_setup_car(0.5)
	deck.refresh()
	deck.pace_row.hovered.emit(GtTypes.PaceMode.ATTACK)
	await _frames(6)
	await _save("phase-11-langkah-3c-tooltip-pace-attack")
	deck.coach_button.pressed.emit()
	await _frames(6)
	await _save("phase-11-langkah-3c-coach-off")
	deck.coach_button.pressed.emit()
	deck.pace_row.unhovered.emit()

	_setup_car(0.8)
	deck.fuel_row.hovered.emit(GtTypes.FuelMode.PUSH)
	await _frames(6)
	await _save("phase-11-langkah-3c-tyre-critical")
	deck.fuel_row.unhovered.emit()

	_setup_car(0.36)
	deck.pit_compound = GtTypes.Compound.WET
	deck.press_box()
	await _frames(8)
	deck.tyre_row.hovered.emit(1 + GtTypes.Compound.WET)
	await _frames(6)
	await _save("phase-11-langkah-3c-box-armed")
	deck.tyre_row.unhovered.emit()
	deck.cancel_box()

	for team: int in [2, 7]:
		hud.set_team_accent(team)
		deck.refresh()
		await _frames(6)
		await _save("phase-11-langkah-3c-deck-team%d" % team)
	quit()
