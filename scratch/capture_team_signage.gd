extends SceneTree

## Native capture of the team-name signs (needs a GPU, not --headless):
##   godot --path . --resolution 1920x1080 --script res://scratch/capture_team_signage.gd -- <circuit_id> <out_dir> [player_team]
## Garage fascias seen from the pit lane (three angles) and, on Brianza, a paddock transporter from the track side.

const WorldScene := preload("res://scenes/race_weekend_world.tscn")
const Config := preload("res://scripts/core/race_config_data.gd")
const Settings := preload("res://scripts/core/presentation_settings.gd")

var world: Node3D
var camera: Camera3D
var out_dir: String = "res://temp/signage/"


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var circuit: String = args[0] if args.size() > 0 else "brianza"
	if args.size() > 1:
		out_dir = args[1]
	var player_team: int = int(args[2]) if args.size() > 2 else 4
	DisplayServer.window_set_size(Vector2i(1920, 1080))
	root.size = Vector2i(1920, 1080)
	Settings.set_quality(Settings.Quality.HIGH)
	var config := Config.get_config()
	config.selected_circuit_id = circuit
	config.selected_team_id = player_team
	config.total_laps = 3
	config.time_of_day = 0
	config.weather_preset = 0
	config.race_seed = 19220903
	world = WorldScene.instantiate()
	root.add_child(world)
	world.hud.visible = false
	for layer: Node in world.hud.get_children():
		if layer is CanvasLayer:
			(layer as CanvasLayer).visible = false
	world.process_mode = Node.PROCESS_MODE_DISABLED
	camera = Camera3D.new()
	camera.far = 5000.0
	camera.fov = 60.0
	root.add_child(camera)
	for _i: int in range(20):
		await process_frame
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out_dir))
	var pit: Node3D = world.pit_lane
	var garages: Array = pit.garages
	# Garage frame: -X is toward the lane. Look at the fascia of garage 5 from garage 2/3/4.
	for shot: Array in [["wide", 2, Vector3(-16.0, 4.0, 0.0), 6], ["oblique", 4, Vector3(-9.0, 2.4, 7.0), 5], ["close", 5, Vector3(-7.0, 2.0, 0.0), 5]]:
		var from_garage: Node3D = garages[int(shot[1])]
		var origin: Vector3 = from_garage.global_transform * (shot[2] as Vector3)
		var target_garage: Node3D = garages[int(shot[3])]
		var target: Vector3 = target_garage.global_transform * Vector3(-0.4, 3.3, 0.0)
		await _shoot(circuit + "-garage-" + String(shot[0]), origin, target)
	if circuit == "brianza":
		var paddock: Node3D = pit.paddock
		var entry: Dictionary = paddock.transporter_poses[4]
		var pose: Transform3D = entry["pose"]
		var to_track: Vector3 = world.ribbon.get_point_at_offset(float(entry["s"]), 0.0).origin - pose.origin
		to_track.y = 0.0
		var origin: Vector3 = pose.origin + to_track.normalized() * 14.0 + Vector3.UP * 3.0
		await _shoot(circuit + "-transporter", origin, pose.origin + Vector3.UP * 2.0)
	world.free()
	camera.free()
	quit(0)


func _shoot(name: String, origin: Vector3, target: Vector3) -> void:
	camera.transform = Transform3D(Basis.looking_at(target - origin, Vector3.UP), origin)
	camera.make_current()
	for _i: int in range(4):
		await process_frame
	var image: Image = root.get_texture().get_image()
	var path: String = out_dir + name + ".png"
	image.save_png(path)
	print("CAPTURE ", path)
