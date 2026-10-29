extends SceneTree

## FASE 11 Langkah 3b report screenshots: the concept F telemetry drawer in several team colours and moments.
## Needs a GPU (not --headless):
##   Godot --path . --resolution 1920x1080 --script res://scratch/capture_langkah3b.gd -- [out_dir]

const WorldScene := preload("res://scenes/race_weekend_world.tscn")
const DirectorScript := preload("res://scripts/world/weekend/race_weekend_director.gd")

const FRAME: float = 1.0 / 60.0

var world: Node3D
var hud: RaceHud
var car: GtCar
var out_dir: String = "res://executor-report/screenshots/phases"


func _initialize() -> void:
	call_deferred("_run")


func _save(file_name: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	var image: Image = root.get_texture().get_image()
	print("saved ", file_name, " err=", image.save_png("%s/%s.png" % [out_dir, file_name]))


## A moving car, a few frames so the clock and the sweeps are alive.
func _cruise() -> void:
	car.v = 70.0
	car.gear = 5
	car.rpm = 7600.0
	car.throttle = 1.0
	car.brake = 0.0
	car.lateral_g = 1.2
	car.longitudinal_g = -0.4
	car.drs_active = true
	car.ers_mode = GtTypes.ErsMode.DEPLOY
	car.ers_battery = 72.0
	car.wheel_temp = PackedFloat64Array([96.0, 104.0, 112.0, 99.0])
	car.driver_stress = 35.0
	car.driver_confidence = 70.0


func _frames(count: int) -> void:
	for _i: int in range(count):
		car.lap = maxi(car.lap, 1)
		hud.refresh_all()
		hud.drawer._process(FRAME)
		await process_frame


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
	hud = world.hud
	for candidate: GtCar in race.cars:
		if candidate.team_id == race.player_team_id:
			car = candidate
			break
	world.followed_id = car.id
	hud.deck.deck_car_id = car.id
	_cruise()
	await _frames(40)
	await _save("phase-11-langkah-3b-drawer-team%d" % race.player_team_id)
	for team: int in [2, 7, 6]:
		hud.set_team_accent(team)
		await _frames(6)
		await _save("phase-11-langkah-3b-drawer-team%d" % team)
	hud.set_team_accent(race.player_team_id)
	# Hard braking, a critical rear tyre and a driver at the limit raise the onomatopoeia and the story.
	car.brake = 0.9
	car.throttle = 0.0
	car.longitudinal_g = 2.8
	car.wheel_temp = PackedFloat64Array([118.0, 121.0, 134.0, 126.0])
	car.driver_stress = 85.0
	car.driver_confidence = 25.0
	car.ers_mode = GtTypes.ErsMode.OVERTAKE
	await _frames(14)
	await _save("phase-11-langkah-3b-drawer-events")
	quit()
