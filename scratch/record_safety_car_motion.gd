extends SceneTree

## Native proof only: Godot --write-movie temp/sc_motion_corrected.avi --fixed-fps 60 --path . -s res://scratch/record_safety_car_motion.gd
## Eight seconds pit exit, then a labeled-in-report staged eight-second pit entry. Not a frame-time benchmark.
const WorldScene := preload("res://scenes/race_weekend_world.tscn")
const Config := preload("res://scripts/core/race_config_data.gd")
const PS := preload("res://scripts/core/presentation_settings.gd")
const FRAME: float = 1.0 / 60.0
var world: RaceWeekendWorld

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	DisplayServer.window_set_size(Vector2i(1920, 1080))
	PS.set_quality(PS.Quality.HIGH)
	var config: RaceConfigData = Config.reset()
	config.total_laps = 3
	config.weather_preset = 0
	config.time_of_day = 0
	world = WorldScene.instantiate() as RaceWeekendWorld
	world.race_config = config
	root.add_child(world)
	world.set_process(false)
	root.scaling_3d_scale = 1.0
	world.race.incidents_enabled = false
	world.director._enter(world.director.State.GREEN_RACING)
	world.race.set_flag(GtTypes.Flag.SC, 1, "SAFETY CAR DEPLOYED", 30.0)
	world.camera_director.set_mode(BroadcastCameraDirector.Mode.SAFETY_CAR)
	for frame: int in range(480):
		world.step(FRAME)
		await process_frame
	world.race.safety_car["s"] = 3700.0
	world.race.safety_car["exit_end_s"] = 220.0
	world.race.race_control["sc_laps_remaining"] = 0
	world.race.race_control["timer"] = 0.0
	_place_field(3700.0)
	world.race._update_race_control(0.0)
	var entered: bool = int(world.race.safety_car["phase"]) == GtTypes.SafetyCarPhase.IN_THIS_LAP
	world.race.safety_car["s"] = 3780.0
	_place_field(3780.0)
	world.race._update_race_control(0.0)
	world.race.safety_car["prev_s"] = world.race.safety_car["s"]
	world.race.safety_car["prev_lateral"] = world.race.safety_car["lateral"]
	for frame: int in range(480):
		world.step(FRAME)
		var pose: Transform3D = world.vfx.safety_car_actor.global_transform
		world.camera.global_position = pose.origin - pose.basis.z * 18.0 - pose.basis.x * 17.0 + Vector3.UP * 9.0
		world.camera.look_at(pose.origin + pose.basis.z * 12.0 - pose.basis.x * 4.0)
		await process_frame
	var peeled: bool = float(world.race.safety_car["lateral"]) > 10.0
	print("MOTION VIDEO: exit480 frames; entry480 frames; in-lap=%s peeled=%s, viewport=%s" % [entered, peeled, root.size])
	world.queue_free()
	await process_frame
	quit(0 if entered and peeled else 1)

func _place_field(sc_s: float) -> void:
	for index: int in range(world.race.cars.size()):
		var car: GtCar = world.race.cars[index]
		car.s = sc_s - 14.0 - float(index) * 14.0
		car.prev_s = car.s
		car.lap = 0
		car.v = 25.0
		car.lateral = 0.0
		car.prev_lateral = 0.0
