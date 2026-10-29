extends SceneTree

## FASE 11 Langkah 3a report screenshots: the BOX button states, the suggestion card burn bar and the desk modes.
## Needs a GPU (not --headless):
##   Godot --path . --resolution 1920x1080 --script res://scratch/capture_langkah3a.gd -- [out_dir]

const WorldScene := preload("res://scenes/race_weekend_world.tscn")
const DirectorScript := preload("res://scripts/world/weekend/race_weekend_director.gd")

const FRAME: float = 1.0 / 60.0

var world: Node3D
var out_dir: String = "res://executor-report/screenshots/phases"


func _initialize() -> void:
	call_deferred("_run")


func _save(file_name: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	var image: Image = root.get_texture().get_image()
	var path: String = "%s/%s" % [out_dir, file_name]
	print("saved ", path, " err=", image.save_png(path), " size=", image.get_size())


func _run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() > 0:
		out_dir = args[0]
	world = WorldScene.instantiate()
	root.add_child(world)
	world.set_process(false)
	await process_frame
	var race: GtRace = world.race
	race.incidents_enabled = false
	world.director._enter(DirectorScript.State.GREEN_RACING)
	for _i: int in range(60 * 6):
		world.step(FRAME)
	var hud: RaceHud = world.hud
	var car: GtCar = null
	for candidate: GtCar in race.cars:
		if candidate.team_id == race.player_team_id:
			car = candidate
			break
	world.followed_id = car.id
	hud.deck.deck_car_id = car.id
	race.latest_suggestion = {}
	race.suggestion_changed.emit({})
	car.pit_request = -1
	car.ers_battery = 0.0 # keeps the advisor from raising a card of its own
	car.tyre_temp = 90.0
	hud.refresh_all()
	await _save("phase-11-langkah-3a-deck-request-box.png")

	world.request_pit(car.id, GtTypes.Compound.WET)
	hud.refresh_all()
	await _save("phase-11-langkah-3a-deck-cancel-box.png")
	world.cancel_pit(car.id)

	race._suggestion_cooldowns.clear()
	race.suggest_tactic(car, GtTypes.TacticType.PIT, GtTypes.Compound.HARD, "BOX FOR HARD", "Tyre wear critical. Suggest box this lap for hard tyres.")
	hud.refresh_all()
	await _save("phase-11-langkah-3a-card-burn-full.png")
	race.time += 6.0
	hud.refresh_all()
	await _save("phase-11-langkah-3a-card-burn-low.png")
	race.time += 2.0
	for _i: int in range(8):
		hud.update(FRAME)
	await _save("phase-11-langkah-3a-card-burn-critical.png")

	race.latest_suggestion = {}
	race.suggestion_changed.emit({})
	race.set_tactic_mode(GtTypes.TacticMode.AUTO)
	hud.refresh_all()
	await _save("phase-11-langkah-3a-desk-auto.png")
	race.set_tactic_mode(GtTypes.TacticMode.MANUAL)
	quit()
