extends SceneTree

## The Apex Racing Porsche 911 on track in the race weekend world (team 0). Needs a GPU (not --headless):
##   Godot --rendering-driver d3d12 --resolution 1920x1080 --path . -s scratch/capture_porsche_911_race.gd

const WorldScene := preload("res://scenes/race_weekend_world.tscn")
const DirectorScript := preload("res://scripts/world/weekend/race_weekend_director.gd")
const FRAME: float = 1.0 / 60.0
const CAR_ID: int = 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var world: Node3D = WorldScene.instantiate()
	root.add_child(world)
	world.set_physics_process(false)
	await process_frame
	var race = world.race
	race.incidents_enabled = false
	var kerb: Dictionary = world.environment.kerbs[0]
	var corner_s: float = float(kerb["s0"]) + (float(kerb["s1"]) - float(kerb["s0"])) * 0.35
	for car in race.cars:
		car.s = corner_s - 30.0 - 14.0 * float(car.id)
		car.prev_s = car.s
		car.v = 40.0
		car.lateral = [0.0, 2.4, -2.4][car.id % 3]
		car.prev_lateral = car.lateral
		car.target_lateral = car.lateral
		car.lap = 1
	world.director._enter(DirectorScript.State.GREEN_RACING)
	for _i in range(150):
		world.step(FRAME)
	world.camera_director.set_process(false)
	var car_actor = world.actor_of(CAR_ID)
	print("actor chassis: ", car_actor.chassis.scene_file_path, " team ", car_actor.car.team_id)
	var ribbon = world.ribbon
	var s: float = car_actor.track_distance_m()
	var views := {
		"porsche_911_race_rear": [s - 11.0, 4.0, 1.5, 3.0],
		"porsche_911_race_side": [s - 1.0, 8.5, 1.4, 0.0],
	}
	for view_name: String in views:
		var v: Array = views[view_name]
		var eye: Transform3D = ribbon.get_point_at_offset(float(v[0]), float(v[1]))
		world.camera.fov = 45.0
		world.camera.near = 0.1
		world.camera.global_position = eye.origin + Vector3.UP * float(v[2])
		world.camera.look_at(car_actor.global_position + Vector3.UP * 0.55, Vector3.UP)
		await process_frame
		await RenderingServer.frame_post_draw
		var image: Image = root.get_texture().get_image()
		print("saved ", view_name, " err=", image.save_png(ProjectSettings.globalize_path("res://scratch/%s.png" % view_name)))
	world.race.dispose()
	quit()
