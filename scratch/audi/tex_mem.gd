extends SceneTree
## Prints the GPU texture memory a chassis scene adds on top of an empty lit scene.
## Run non-headless: ... -s scratch/audi/tex_mem.gd -- <chassis scene path>
func _initialize() -> void:
	call_deferred("_run")
func _run() -> void:
	var cam := Camera3D.new()
	root.add_child(cam)
	cam.current = true
	cam.look_at_from_position(Vector3(3, 1.5, 4), Vector3(0, 0.5, 0))
	var light := DirectionalLight3D.new()
	light.shadow_enabled = true
	root.add_child(light)
	for i in 20:
		await process_frame
	var before: float = RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_VIDEO_MEM_USED)
	var chassis: Node = (load(OS.get_cmdline_user_args()[0]) as PackedScene).instantiate()
	root.add_child(chassis)
	for i in 30:
		await process_frame
	print("TEXMEM ", OS.get_cmdline_user_args()[0].get_file(), " +%.1f MB (base %.1f MB)" % [(RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_VIDEO_MEM_USED) - before) / 1048576.0, before / 1048576.0])
	quit(0)
