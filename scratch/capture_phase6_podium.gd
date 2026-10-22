extends SceneTree

## Report screenshot of the FASE 6 podium. Needs a GPU (not --headless):
##   Godot --path . --resolution 1920x1080 --script res://scratch/capture_phase6_podium.gd -- [out_png]
## Runs a 2-lap race to the flag in the weekend world, lets the podium come up by itself and saves it.

const WorldScene := preload("res://scenes/race_weekend_world.tscn")
const DirectorScript := preload("res://scripts/world/race_weekend_director.gd")

const FRAME: float = 1.0 / 60.0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var out_path: String = args[0] if args.size() > 0 else "res://scratch/phase-6-podium.png"
	var world: Node3D = WorldScene.instantiate()
	world.total_laps = 2
	root.add_child(world)
	world.set_physics_process(false)
	world.race.incidents_enabled = false
	world.director._enter(DirectorScript.State.GREEN_RACING)
	var ticks: int = 0
	while not world.race.is_finished() and ticks < 12000:
		world.race.step()
		ticks += 1
	var frames: int = 0
	while world.podium == null and frames < 600:
		world.step(FRAME)
		frames += 1
	await process_frame
	# Let the steps rise, the cards drop in and the confetti settle into a mid-fall frame.
	for _i: int in range(150):
		world.podium.step(FRAME)
	await process_frame
	await RenderingServer.frame_post_draw
	var image: Image = root.get_texture().get_image()
	print("saved ", out_path, " err=", image.save_png(out_path), " size=", image.get_size(), " ticks=", ticks)
	world.race.dispose()
	quit()
