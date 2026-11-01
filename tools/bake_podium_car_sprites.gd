extends SceneTree

## Bakes one transparent 2D sprite per car for the winning podium: res://assets/cars/<slug>/podium_sprite.png.
## The sprite is a screenshot of <slug>_full.glb in the in-game toon look (livery material, ink outline, headlights),
## filmed from one low three-quarter front angle for every car, trimmed to the silhouette and scaled to 1600 px wide.
## The committed sprites are generated assets and this tool is their source: rerun it when a car model or livery changes.
##
## Needs a renderer, so it cannot run headless:
##   godot --rendering-driver d3d12 --resolution 1280x800 --path . -s tools/bake_podium_car_sprites.gd            (all cars)
##   godot --rendering-driver d3d12 --resolution 1280x800 --path . -s tools/bake_podium_car_sprites.gd -- audi_r8  (one car)
##   godot --rendering-driver d3d12 --resolution 1280x800 --path . -s tools/bake_podium_car_sprites.gd -- --sheet  (contact sheet
##   of the existing sprites, written to res://temp/podium_sprites_sheet.png)

const Toon := preload("res://scripts/world/shared/toon_materials.gd")
const Roster := preload("res://scripts/ui/garage_roster.gd")
const SPRITE_WIDTH: int = 1600
const RENDER_SIZE := Vector2i(2560, 1600)
const TRIM_MARGIN: int = 8
const CAMERA_POS := Vector3(3.0, 1.85, 5.9)
const CAMERA_TARGET := Vector3(0.0, 0.5, 0.0)
const SHEET_PATH := "res://temp/podium_sprites_sheet.png"
const SHEET_COLUMNS: int = 4
const SHEET_CELL := Vector2i(400, 280)


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if "--sheet" in args:
		_write_sheet()
		quit(0)
		return
	var failed: int = 0
	for team: int in range(Roster.CAR_SLUGS.size()):
		var slug: String = Roster.CAR_SLUGS[team]
		if not args.is_empty() and slug not in args:
			continue
		if not await _bake(slug, Roster.podium_sprite_path(team)):
			failed += 1
	quit(1 if failed > 0 else 0)


func _bake(slug: String, out_path: String) -> bool:
	var viewport := SubViewport.new()
	viewport.size = RENDER_SIZE
	viewport.transparent_bg = true
	viewport.own_world_3d = true
	viewport.msaa_3d = Viewport.MSAA_4X
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)

	var world := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("#DCE3F2")
	env.ambient_light_energy = 0.65
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	world.environment = env
	viewport.add_child(world)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-38.0, 38.0, 0.0)
	sun.light_energy = 0.85
	sun.shadow_enabled = true
	viewport.add_child(sun)
	var spot := SpotLight3D.new()
	spot.position = Vector3(0.0, 8.0, 1.0)
	spot.light_color = Color("#F2F6FF")
	spot.light_energy = 2.4
	spot.spot_range = 14.0
	spot.spot_angle = 24.0
	spot.shadow_enabled = true
	viewport.add_child(spot)
	spot.look_at(Vector3(0.0, 0.6, 0.0))
	var rim := OmniLight3D.new()
	rim.position = Vector3(-2.0, 3.2, -5.0)
	rim.light_color = Color("#55C9FF")
	rim.light_energy = 1.0
	rim.omni_range = 8.0
	viewport.add_child(rim)

	var camera := Camera3D.new()
	camera.fov = 32.0
	camera.current = true
	viewport.add_child(camera)
	camera.look_at_from_position(CAMERA_POS, CAMERA_TARGET)

	var scene := load("res://assets/cars/%s/%s_full.glb" % [slug, slug]) as PackedScene
	if scene == null:
		push_error("no full GLB for %s" % slug)
		viewport.queue_free()
		return false
	var model: Node3D = scene.instantiate()
	_apply_hero_toon(model, slug)
	viewport.add_child(model)
	_light_hero_car(model)

	for i: int in range(10):
		await process_frame
	await RenderingServer.frame_post_draw
	var image: Image = viewport.get_texture().get_image()
	var used: Rect2i = image.get_used_rect()
	# Margin on the top, left and right only: the last row is the tyre contact line, so every car sits on the same ground line.
	var padded := Rect2i(used.position - Vector2i(TRIM_MARGIN, TRIM_MARGIN), used.size + Vector2i(TRIM_MARGIN * 2, TRIM_MARGIN))
	var box: Rect2i = padded.intersection(Rect2i(Vector2i.ZERO, image.get_size()))
	var sprite: Image = image.get_region(box)
	sprite.convert(Image.FORMAT_RGBA8)
	sprite.resize(SPRITE_WIDTH, roundi(float(sprite.get_height()) * float(SPRITE_WIDTH) / float(sprite.get_width())), Image.INTERPOLATE_LANCZOS)
	var err: int = sprite.save_png(ProjectSettings.globalize_path(out_path))
	print("baked ", slug, " err=", err, " size=", sprite.get_size())
	viewport.queue_free()
	await process_frame
	await process_frame
	return err == OK


## Contact sheet of the sprites on disk, for eyeballing that every car shares angle, scale and ground line.
func _write_sheet() -> void:
	var rows: int = ceili(float(Roster.CAR_SLUGS.size()) / float(SHEET_COLUMNS))
	var sheet := Image.create_empty(SHEET_COLUMNS * SHEET_CELL.x, rows * SHEET_CELL.y, false, Image.FORMAT_RGBA8)
	sheet.fill(Color("#2B2D36"))
	for team: int in range(Roster.CAR_SLUGS.size()):
		var path: String = Roster.podium_sprite_path(team)
		if not FileAccess.file_exists(path):
			continue
		var sprite := Image.load_from_file(ProjectSettings.globalize_path(path))
		var fitted_width: int = SHEET_CELL.x - 20
		sprite.resize(fitted_width, roundi(float(sprite.get_height()) * float(fitted_width) / float(sprite.get_width())), Image.INTERPOLATE_LANCZOS)
		var cell := Vector2i((team % SHEET_COLUMNS) * SHEET_CELL.x, (team / SHEET_COLUMNS) * SHEET_CELL.y)
		# Cars share a ground line: bottoms sit on the same row of every cell.
		sheet.blend_rect(sprite, Rect2i(Vector2i.ZERO, sprite.get_size()), cell + Vector2i(10, SHEET_CELL.y - 10 - sprite.get_height()))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://temp"))
	print("sheet err=", sheet.save_png(ProjectSettings.globalize_path(SHEET_PATH)))


func _apply_hero_toon(model: Node3D, slug: String) -> void:
	var paint := load("res://materials/%s_toon_body.tres" % slug) as Material
	var carbon := preload("res://materials/toon_carbon_aero.tres")
	var wheel_materials: Dictionary = {}
	for node: Node in model.find_children("*", "MeshInstance3D", true, false):
		var instance := node as MeshInstance3D
		for surface: int in range(instance.mesh.get_surface_count()):
			var source := instance.mesh.surface_get_material(surface) as BaseMaterial3D
			if source == null:
				continue
			if source.resource_name.ends_with("_Paint"):
				instance.set_surface_override_material(surface, paint)
			elif source.resource_name == "FenderLinerMat":
				instance.set_surface_override_material(surface, carbon)
			else:
				if not wheel_materials.has(source):
					var cel := Toon.make(source.albedo_color).duplicate() as ShaderMaterial
					cel.set_shader_parameter("albedo_texture", source.albedo_texture)
					var outline := ShaderMaterial.new()
					outline.shader = Toon.OutlineShader
					outline.set_shader_parameter("outline_width", 0.006)
					cel.next_pass = outline
					wheel_materials[source] = cel
				instance.set_surface_override_material(surface, wheel_materials[source])


func _car_bounds(model: Node3D) -> AABB:
	var bounds := AABB()
	var first: bool = true
	for instance: Node in model.find_children("*", "MeshInstance3D", true, false):
		var mesh := instance as MeshInstance3D
		var local: Transform3D = model.global_transform.affine_inverse() * mesh.global_transform
		var box: AABB = local * mesh.get_aabb()
		bounds = box if first else bounds.merge(box)
		first = false
	return bounds


func _light_hero_car(model: Node3D) -> void:
	var bounds: AABB = _car_bounds(model)
	for side: float in [-1.0, 1.0]:
		var head := SpotLight3D.new()
		head.position = Vector3(side * bounds.size.x * 0.24, bounds.position.y + bounds.size.y * 0.3, bounds.end.z - 0.05)
		head.rotation.y = PI
		head.light_color = Color("#D7EEFF")
		head.light_energy = 3.0
		head.spot_range = 7.0
		head.spot_angle = 24.0
		model.add_child(head)
		var tail := OmniLight3D.new()
		tail.position = Vector3(side * bounds.size.x * 0.24, bounds.position.y + bounds.size.y * 0.42, bounds.position.z)
		tail.light_color = Color("#FF2244")
		tail.light_energy = 1.0
		tail.omni_range = 1.5
		model.add_child(tail)
