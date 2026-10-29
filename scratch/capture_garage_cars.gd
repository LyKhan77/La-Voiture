extends SceneTree

const OUT_DIR: String = "res://temp/cars"
const RosterScript := preload("res://scripts/ui/garage_roster.gd")

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var dir := DirAccess.open("res://temp")
	if dir != null:
		dir.make_dir_recursive("cars")
	
	var garage_scene := load("res://scenes/ui/garage_team_select.tscn")
	var garage: Node = garage_scene.instantiate()
	root.add_child(garage)
	
	for _i in range(15):
		await process_frame
	
	var team_count: int = RosterScript.CAR_SLUGS.size()
	for team in range(team_count):
		garage.select_team(team)
		if garage.orbit != null and garage.environment != null and team < garage.environment.cars.size():
			garage.orbit.focus(garage.environment.cars[team], true)
		for _f in range(8):
			await process_frame
		await RenderingServer.frame_post_draw
		var img: Image = root.get_viewport().get_texture().get_image()
		var slug: String = RosterScript.CAR_SLUGS[team]
		var file_name: String = "team_%02d_%s.png" % [team, slug]
		var save_path: String = ProjectSettings.globalize_path("%s/%s" % [OUT_DIR, file_name])
		img.save_png(save_path)
		print("Captured: ", file_name)
	
	garage.queue_free()
	await process_frame
	print("ALL GARAGE CAR SHOTS CAPTURED")
	quit(0)
