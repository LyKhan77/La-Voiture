extends SceneTree

## Report screenshots of FASE 8.4 (driver portrait + soundwave on the radio banner) and of the
## standalone championship studio. Needs a GPU (not --headless):
##   Godot --path . --resolution 1920x1080 --script res://scratch/capture_fase84.gd -- radio|podium|podium_mid [out_png]
## podium captures the clean studio; podium_mid captures it with the timing tower expanded.

const WorldScene := preload("res://scenes/race_weekend_world.tscn")
const DirectorScript := preload("res://scripts/world/weekend/race_weekend_director.gd")
const WinningStudio := preload("res://scripts/ui/winning_scene.gd")

const FRAME: float = 1.0 / 60.0
## The studio opens under a 0.55 s departure wipe; let it clear before capturing.
const SETTLE_FRAMES: int = 60
## Opening the timing tower is a 0.25 s tween.
const TOWER_FRAMES: int = 20


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
	world.set_process(false)
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
		# The flag falls, the world holds the countdown, then the standalone studio takes the screen
		# and frees this world: nothing past the hand-over may touch it again.
		var frames: int = 0
		while not (current_scene is WinningStudio) and frames < 600:
			if is_instance_valid(world):
				world.step(FRAME)
			await process_frame
			frames += 1
		var studio: WinningStudio = current_scene as WinningStudio
		if studio == null:
			push_error("winning studio never opened")
			quit(1)
			return
		for _i: int in range(SETTLE_FRAMES):
			await process_frame
		if mode == "podium_mid":
			studio.toggle_leaderboard()
			for _i: int in range(TOWER_FRAMES):
				await process_frame
	await RenderingServer.frame_post_draw
	var image: Image = root.get_texture().get_image()
	print("saved ", out_path, " err=", image.save_png(out_path), " size=", image.get_size())
	if mode == "radio":
		world.race.dispose() # the podium modes left their world to the studio transition, which disposed it.
	quit()
