extends SceneTree

## FASE 11 Langkah 3e report screenshots: the R2 wheatpaste radio cards (driver in the team colour, engineer in the
## complementary colour), alone, as a two-way exchange, urgent, with a long call, and for a dark and a light team.
## Needs a GPU (not --headless):
##   Godot --path . --resolution 1920x1080 --script res://scratch/capture_langkah3e.gd -- [out_dir]

const WorldScene := preload("res://scenes/race_weekend_world.tscn")
const DirectorScript := preload("res://scripts/world/weekend/race_weekend_director.gd")

const FRAME: float = 1.0 / 60.0
const CROP := Rect2i(300, 60, 1360, 860)

var world: Node3D
var hud: RaceHud
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
		hud.refresh_all()
		hud.radio._process(FRAME)
		hud.engineer_radio._process(FRAME)
		await process_frame


func _clear() -> void:
	hud.radio._hide_banner()
	hud.engineer_radio._hide_banner()
	hud.radio.set_dimmed(false)
	hud.engineer_radio.set_dimmed(false)
	race._pending_replies.clear()
	race.driver_radio_cooldown.clear()


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
	for candidate: GtCar in race.cars:
		if candidate.team_id == race.player_team_id:
			car = candidate
			break
	car.wear = 0.62
	_clear() # the sim may have an urgent card up already

	race.push_radio(car, "driver", "Had a snap of oversteer! Lost some time.")
	hud.radio._settle()
	hud.radio.soundwave_active = true
	await _frames(24)
	await _save("phase-11-langkah-3e-driver")

	race.push_radio(car, "engineer", "Copy %s, stay on it. Rear tyres at 38%%, watch the exit." % car.code)
	hud.engineer_radio._settle()
	hud.engineer_radio.soundwave_active = true
	await _frames(24)
	await _save("phase-11-langkah-3e-two-way")
	_clear()

	race.push_radio(car, "engineer", "Box this lap, confirm WET tyres!", true)
	hud.engineer_radio._settle()
	hud.engineer_radio.soundwave_active = true
	await _frames(24)
	await _save("phase-11-langkah-3e-urgent")
	_clear()

	race.push_radio(car, "driver", "Suspension has snapped from the flat tyre! I can't continue, the car is destroyed, please send help to turn four.", true)
	hud.radio._settle()
	await _frames(12)
	await _save("phase-11-langkah-3e-long-call")
	_clear()

	for team: int in [2, 7]:
		hud.set_team_accent(team)
		race.push_radio(car, "driver", "Pass made on the rival! Clean move down the inside!", false, true)
		hud.radio._settle()
		race.push_radio(car, "engineer", "Copy, keep the gap and watch the DRS.", false, true)
		hud.engineer_radio._settle()
		await _frames(18)
		await _save("phase-11-langkah-3e-team%d" % team)
		_clear()
	quit()
