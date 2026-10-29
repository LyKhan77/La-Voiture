extends SceneTree

## Report screenshot of the driver and engineer radio overlays side by side. Needs a GPU:
##   Godot --path . --resolution 1920x1080 --script res://scratch/capture_phase6_radio.gd -- [out_png]

const WorldScene := preload("res://scenes/race_weekend_world.tscn")
const DirectorScript := preload("res://scripts/world/weekend/race_weekend_director.gd")

const FRAME: float = 1.0 / 60.0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var out_path: String = args[0] if args.size() > 0 else "res://scratch/phase-6-radio-overlays.png"
	var world: Node3D = WorldScene.instantiate()
	root.add_child(world)
	world.set_process(false)
	world.race.incidents_enabled = false
	world.director._enter(DirectorScript.State.GREEN_RACING)
	for _i: int in range(240):
		world.step(FRAME)
	var car: GtCar = world.race.cars[0]
	world.race.push_radio(car, "engineer", "Box this lap, confirm medium tyres.", true)
	world.race.push_radio(car, "driver", "Tyres are gone, I need to box now!", true)
	for _i: int in range(40):
		await process_frame
		world.step(FRAME)
	await RenderingServer.frame_post_draw
	var image: Image = root.get_texture().get_image()
	print("saved ", out_path, " err=", image.save_png(out_path), " size=", image.get_size())
	world.race.dispose()
	quit()
