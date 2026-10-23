extends SceneTree

## FASE 8.5 lamp check: rear and front close-ups of several teams from a free camera. Needs a GPU:
##   godot --path . --resolution 1280x720 --script res://scratch/capture_lamps85.gd -- [out_dir]

const WorldScene := preload("res://scenes/race_weekend_world.tscn")
const DirectorScript := preload("res://scripts/world/race_weekend_director.gd")
const FRAME: float = 1.0 / 60.0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var out_dir: String = args[0] if args.size() > 0 else "res://executor-report/screenshots/phases"
	var world: Node3D = WorldScene.instantiate()
	root.add_child(world)
	world.set_physics_process(false)
	world.set_process(false)
	world.race.incidents_enabled = false
	world.director._enter(DirectorScript.State.GREEN_RACING)
	for _i: int in range(60):
		world.step(FRAME)
	world.hud.visible = false
	var cam := Camera3D.new()
	cam.fov = 40.0
	root.add_child(cam)
	cam.current = true
	for team: int in [0, 2, 5, 9]:
		var actor = null
		for candidate in world.actors:
			if candidate.car.team_id == team:
				actor = candidate
		actor.car.brake = 1.0
		actor.night_lights = 4.0
		for _i: int in range(30):
			actor.present(1.0, FRAME)
		var basis: Basis = actor.global_transform.basis
		for view: Array in [["rear", basis.z], ["front", -basis.z]]:
			cam.global_position = actor.global_position + (view[1] as Vector3) * 5.5 + basis.x * 1.6 + Vector3.UP * 1.1
			cam.look_at(actor.global_position + Vector3(0.0, 0.6, 0.0), Vector3.UP)
			for _i: int in range(6):
				await process_frame
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(ProjectSettings.globalize_path("%s/fase-8.5-lamps-t%d-%s.png" % [out_dir, team, view[0]]))
	quit(0)
