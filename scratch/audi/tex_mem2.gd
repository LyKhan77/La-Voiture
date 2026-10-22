extends SceneTree
func _initialize() -> void:
	call_deferred("_run")
func _run() -> void:
	for i in 10:
		await process_frame
	var keep: Array = []
	for path: String in ["res://assets/cars/porsche_911/textures/normal.png", "res://assets/cars/audi_r8/textures/normal.png", "res://assets/cars/audi_r8/textures/base_color.png", "res://assets/cars/porsche_911/textures/base_color.jpg", "res://assets/cars/porsche_911/textures/orm.jpg"]:
		var before: float = RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_VIDEO_MEM_USED)
		var tex: Texture2D = load(path)
		keep.append(tex)
		for i in 5:
			await process_frame
		var after: float = RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_VIDEO_MEM_USED)
		print("TEX2 ", path.get_file(), " ", tex.get_size(), " ", tex.get_class(), " +%.1f MB" % ((after - before) / 1048576.0))
	quit(0)
