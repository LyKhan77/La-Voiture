extends SceneTree

## One 1080p frame per flag panel, from the road 16 m before it, with the panels showing a sector yellow so the LED face is lit.
##   godot --path . --resolution 1920x1080 --script res://scratch/capture_flag_panels.gd -- <circuit_id> [max_panels]
## Files: executor-report/screenshots/phases/phase-14-2-flags-<circuit>-<n>.png

const WorldScene := preload("res://scenes/race_weekend_world.tscn")
const Config := preload("res://scripts/core/race_config_data.gd")
const Settings := preload("res://scripts/core/presentation_settings.gd")
const Types := preload("res://scripts/gt/gt_types.gd")
const OUT_DIR := "res://executor-report/screenshots/phases/"


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var circuit: String = args[0] if args.size() > 0 else "neo_wangan"
	var limit: int = int(args[1]) if args.size() > 1 else 8
	DisplayServer.window_set_size(Vector2i(1920, 1080))
	root.size = Vector2i(1920, 1080)
	Settings.set_quality(Settings.Quality.HIGH)
	var config := Config.get_config()
	config.selected_circuit_id = circuit
	config.selected_team_id = 4
	config.total_laps = 3
	config.time_of_day = 0
	config.weather_preset = 0
	config.race_seed = 19220903
	var world: Node3D = WorldScene.instantiate()
	root.add_child(world)
	world.hud.visible = false
	world.process_mode = Node.PROCESS_MODE_DISABLED
	var camera := Camera3D.new()
	camera.far = 3000.0
	camera.fov = 60.0
	root.add_child(camera)
	for _i: int in range(30):
		await process_frame
	var panels: FlagPanelSet = world.environment.flag_panels
	panels.apply_flag(Types.Flag.YELLOW, 1)
	panels.apply_flag(Types.Flag.YELLOW, int(panels.records[0]["sector"]))
	for index: int in range(mini(limit, panels.count)):
		var s: float = float(panels.records[index]["s"])
		var origin: Vector3 = world.ribbon.get_point_at_offset(s - 16.0, 0.0).origin + Vector3.UP * 2.2
		var target: Vector3 = panels.poses[index].origin + Vector3.UP * 2.2
		camera.transform = Transform3D(Basis.looking_at(target - origin, Vector3.UP), origin)
		camera.make_current()
		for _i: int in range(6):
			await process_frame
		var path: String = ProjectSettings.globalize_path(OUT_DIR) + "phase-14-2-flags-%s-%d.png" % [circuit, index]
		root.get_texture().get_image().save_png(path)
		print("CAPTURE s=%.0f side=%.0f sector=%d -> %s" % [s, float(panels.records[index]["side"]), int(panels.records[index]["sector"]), path])
	world.free()
	camera.free()
	quit(0)
