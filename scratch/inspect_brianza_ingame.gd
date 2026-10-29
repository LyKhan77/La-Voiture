extends SceneTree

const WorldScene := preload("res://scenes/race_weekend_world.tscn")
const Config := preload("res://scripts/core/race_config_data.gd")
const Settings := preload("res://scripts/core/presentation_settings.gd")

var world: Node3D

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	DisplayServer.window_set_size(Vector2i(1280, 720))
	root.size = Vector2i(1280, 720)
	Settings.set_quality(Settings.Quality.HIGH)

	var config := Config.get_config()
	config.selected_circuit_id = "brianza"
	config.total_laps = 5
	config.time_of_day = 0 # DAY
	config.weather_preset = 0 # DRY
	config.race_seed = 42

	world = WorldScene.instantiate()
	root.add_child(world)

	# Wait for world setup
	for _i: int in range(30):
		await process_frame

	# Take a screenshot at race start (Grid view from chase camera)
	await _snap("temp/brianza_start_grid.png")

	# Let cars drive for 200 ticks (approaching Turn 1 Rettifilo)
	world.set_time_scale(4.0)
	for _i: int in range(60):
		await process_frame

	await _snap("temp/brianza_t1_rettifilo_approach.png")

	# Let cars drive further to Curva Grande
	for _i: int in range(120):
		await process_frame
	await _snap("temp/brianza_curva_grande_drive.png")

	# Drive towards Serraglio / Sopraelevata
	for _i: int in range(200):
		await process_frame
	await _snap("temp/brianza_sopraelevata_drive.png")

	# Drive towards Ascari
	for _i: int in range(150):
		await process_frame
	await _snap("temp/brianza_ascari_drive.png")

	# Drive towards Parabolica
	for _i: int in range(150):
		await process_frame
	await _snap("temp/brianza_parabolica_drive.png")

	world.queue_free()
	await process_frame
	print("DONE CAPTURING IN-GAME SHOTS")
	quit(0)

func _snap(path: String) -> void:
	for _i: int in range(4):
		await process_frame
	var img: Image = root.get_texture().get_image()
	img.save_png(ProjectSettings.globalize_path(path))
	print("SAVED: " + path)
