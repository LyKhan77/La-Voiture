extends SceneTree

## Report screenshot of the championship studio that follows the FASE 6 flag. Needs a GPU (not --headless):
##   Godot --path . --resolution 1920x1080 --script res://scratch/capture_phase6_podium.gd -- [out_png]
## Runs a 2-lap race to the flag in the weekend world, lets the world hand over to the standalone
## studio by itself and saves it once the departure wipe has cleared.

const WorldScene := preload("res://scenes/race_weekend_world.tscn")
const DirectorScript := preload("res://scripts/world/race_weekend_director.gd")
const WinningStudio := preload("res://scripts/ui/winning_scene.gd")

const FRAME: float = 1.0 / 60.0
## Frames for the 0.55 s departure wipe to clear and the confetti to settle into a mid-fall frame.
const SETTLE_FRAMES: int = 150


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
	# The flag falls, the world holds the countdown, then the standalone studio takes the screen
	# and frees this world: nothing past the hand-over may touch it again.
	var frames: int = 0
	while not (current_scene is WinningStudio) and frames < 600:
		if is_instance_valid(world):
			world.step(FRAME)
		await process_frame
		frames += 1
	if not (current_scene is WinningStudio):
		push_error("winning studio never opened")
		quit(1)
		return
	# Let the turntable turn and the confetti settle into a mid-fall frame.
	for _i: int in range(SETTLE_FRAMES):
		await process_frame
	await RenderingServer.frame_post_draw
	var image: Image = root.get_texture().get_image()
	print("saved ", out_path, " err=", image.save_png(out_path), " size=", image.get_size(), " ticks=", ticks)
	quit()
