extends SceneTree

## Report screenshots of FASE 8.4 (driver portrait + soundwave on the radio banner, podium standees).
## Needs a GPU (not --headless):
##   Godot --path . --resolution 1920x1080 --script res://scratch/capture_fase84.gd -- radio|podium|podium_mid [out_png]

const WorldScene := preload("res://scenes/race_weekend_world.tscn")
const DirectorScript := preload("res://scripts/world/race_weekend_director.gd")

const FRAME: float = 1.0 / 60.0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var mode: String = args[0] if args.size() > 0 else "radio"
	var out_path: String = args[1] if args.size() > 1 else "res://temp/fase84-%s.png" % mode
	var world: Node3D = WorldScene.instantiate()
	if mode.begins_with("podium"):
		world.total_laps = 2
	root.add_child(world)
	world.set_physics_process(false)
	world.race.incidents_enabled = false
	world.director._enter(DirectorScript.State.GREEN_RACING)
	if mode == "radio":
		for _i: int in range(240):
			world.step(FRAME)
		var car: GtCar = world.race.get_car(7) # Freja Berg, Nordic Phantom
		world.race.push_radio(world.race.cars[0], "engineer", "Box this lap, confirm medium tyres.", true)
		world.race.push_radio(car, "driver", "We touched with REN! Check the telemetry!", true)
		for _i: int in range(50):
			await process_frame
			world.step(FRAME)
	else:
		var ticks: int = 0
		while not world.race.is_finished() and ticks < 60000:
			world.race.step()
			ticks += 1
		var frames: int = 0
		while world.podium == null and frames < 600:
			world.step(FRAME)
			frames += 1
		await process_frame
		world.podium.set_elapsed(0.3 if mode == "podium_mid" else 2.0)
		for _i: int in range(60 if mode == "podium" else 1):
			world.podium.step(FRAME)
		await process_frame
	await RenderingServer.frame_post_draw
	var image: Image = root.get_texture().get_image()
	print("saved ", out_path, " err=", image.save_png(out_path), " size=", image.get_size())
	world.race.dispose()
	quit()
