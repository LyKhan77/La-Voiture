extends SceneTree

## FASE 8.5 acceptance: real-mesh car lamps (no sphere orbs, brake lights that react), the manga
## speedlines + boost FOV punch, kerb sparks and the two-tone graffiti backfire, the Concept 01
## street-tag main menu, and a paddock showroom that wears the same cel paint + ink hull as the race.
## Run: Godot --headless --path . -s res://tests/test_visual_polish_and_consistency.gd

const WorldScene := preload("res://scenes/race_weekend_world.tscn")
const DirectorScript := preload("res://scripts/world/race_weekend_director.gd")
const ActorScript := preload("res://scripts/car/gt_car_actor.gd")
const CameraDirectorScript := preload("res://scripts/world/broadcast_camera_director.gd")
const GarageBuilder := preload("res://scripts/world/garage_environment_builder.gd")
const PS := preload("res://scripts/core/presentation_settings.gd")
const T := preload("res://scripts/ui/ui_theme_tokens.gd")
const FRAME: float = 1.0 / 60.0

var failures: int = 0
var assertions: int = 0
var world: Node3D


func _initialize() -> void:
	call_deferred("_run")


func check(ok: bool, description: String) -> void:
	assertions += 1
	if not ok:
		failures += 1
		push_error(description)
	print("[%s] %s" % ["PASS" if ok else "FAIL", description])


func _run() -> void:
	world = WorldScene.instantiate()
	root.add_child(world)
	world.set_physics_process(false)
	world.race.incidents_enabled = false
	world.director._enter(DirectorScript.State.GREEN_RACING)
	for _i: int in range(30):
		world.step(FRAME)
	_test_no_spheremesh_headlights()
	_test_reactive_brake_lights()
	_test_manga_speedlines_trigger()
	_test_boost_fov_punch()
	_test_kerb_strike_sparks()
	_test_graffiti_backfire()
	world.race.dispose()
	world.queue_free()
	await process_frame
	ActorScript._paint_cache.clear()
	await _test_main_menu_concept_01_styling()
	_test_garage_showroom_toon_consistency()
	print("%d assertions, %d failure(s)" % [assertions, failures])
	print("FASE 8.5 VISUAL POLISH: %s" % ("PASS" if failures == 0 else "%d FAILURES" % failures))
	quit(0 if failures == 0 else 1)


func _count_class(node: Node, mesh_class: String) -> int:
	var found: int = 0
	if node is MeshInstance3D and (node as MeshInstance3D).mesh != null and (node as MeshInstance3D).mesh.get_class() == mesh_class:
		found += 1
	for child: Node in node.get_children():
		found += _count_class(child, mesh_class)
	return found


func _settle(actor: ActorScript, frames: int) -> void:
	for _i: int in range(frames):
		actor.present(1.0, FRAME)


# --- lights ----------------------------------------------------------------------------------

func _test_no_spheremesh_headlights() -> void:
	var spheres: int = 0
	for actor: ActorScript in world.actors:
		spheres += _count_class(actor, "SphereMesh")
	check(spheres == 0, "lamps: no cars carry a SphereMesh orb (%d found)" % spheres)


func _test_reactive_brake_lights() -> void:
	var actor: ActorScript = world.actors[3]
	var car: GtCar = actor.car
	car.brake = 0.0
	car.longitudinal_g = 0.0
	_settle(actor, 40)
	var coasting: Variant = actor.get("taillight_energy")
	car.brake = 1.0
	_settle(actor, 40)
	var braking: Variant = actor.get("taillight_energy")
	check(coasting != null and braking != null and float(coasting) < 0.5 and float(braking) >= 5.0,
		"tail lights: dark by day when coasting (%s), >= 5.0 on the brakes (%s)" % [str(coasting), str(braking)])
	car.brake = 0.0
	_settle(actor, 60)
	check(actor.get("taillight_energy") != null and float(actor.get("taillight_energy")) < 0.5, "tail lights: they go dark again once the brake is released")
	actor.set("night_lights", 4.0)
	_settle(actor, 60)
	var resting: Variant = actor.get("taillight_energy")
	actor.set("night_lights", 0.0)
	check(resting != null and absf(float(resting) - 1.2) < 0.05, "tail lights: they glow softly at 1.2 at night without braking (%s)" % str(resting))


# --- speedlines + boost punch ------------------------------------------------------------------

func _test_manga_speedlines_trigger() -> void:
	var hud: RaceHud = world.hud
	var car: GtCar = world.race.get_car(world.followed_id)
	car.ers_mode = GtTypes.ErsMode.NEUTRAL
	car.v = 0.0
	hud.update(FRAME)
	var rest: float = hud.speedlines_intensity
	car.v = 70.0 # 252 km/h
	hud.update(FRAME)
	var fast: float = hud.speedlines_intensity
	var overlay_on: bool = hud.speedlines_rect != null and hud.speedlines_rect.visible
	car.v = 30.0
	car.ers_mode = GtTypes.ErsMode.OVERTAKE
	hud.update(FRAME)
	var boost: float = hud.speedlines_intensity
	car.ers_mode = GtTypes.ErsMode.NEUTRAL
	car.v = 0.0
	hud.update(FRAME)
	check(rest == 0.0 and fast > 0.5 and overlay_on and boost >= 1.0 and hud.speedlines_rect != null and not hud.speedlines_rect.visible,
		"speedlines: 0 at rest (%.2f), %.2f at 252 km/h, %.2f during ERS overtake, overlay hidden again at rest" % [rest, fast, boost])
	check(hud.speedlines_rect != null and hud.speedlines_rect.mouse_filter == Control.MOUSE_FILTER_IGNORE
		and (hud.speedlines_rect.material as ShaderMaterial).shader.resource_path.ends_with("manga_speedlines.gdshader"),
		"speedlines: the overlay is a click-through rect on the manga_speedlines shader")


func _test_boost_fov_punch() -> void:
	var director: CameraDirectorScript = world.camera_director
	director.set_mode(CameraDirectorScript.Mode.CHASE)
	director.update(1.0) # the overtake in the speedlines test already kicked the lens; let it settle
	director.update(FRAME)
	var base: float = world.camera.fov
	director.punch_fov()
	director.update(0.08)
	var kicked: float = world.camera.fov
	director.update(0.4)
	var settled: float = world.camera.fov
	check(absf(kicked - (base + 3.5)) < 0.1 and absf(settled - base) < 0.1,
		"boost punch: FOV kicks +3.5 deg in 0.08 s (%.1f -> %.1f) and eases back inside 0.35 s (%.1f)" % [base, kicked, settled])


# --- kerb sparks + backfire ---------------------------------------------------------------------

func _test_kerb_strike_sparks() -> void:
	var vfx: RaceVfx = world.vfx
	var actor: ActorScript = world.actors[5]
	var car: GtCar = actor.car
	var id: int = car.id
	var bursts: Variant = vfx.get("kerb_sparks")
	var emitter: GPUParticles3D = (bursts as Dictionary).get(id) as GPUParticles3D if bursts is Dictionary else null
	if emitter == null:
		check(false, "kerb sparks: every car owns a GPUParticles3D")
		return
	car.v = 20.0
	car.lateral = 6.0
	vfx.update(FRAME)
	var slow: bool = emitter.emitting
	car.v = 45.0
	car.lateral = 0.0
	vfx.update(FRAME)
	var mid_track: bool = emitter.emitting
	car.lateral = 6.0
	vfx.update(FRAME)
	var on_kerb: bool = emitter.emitting
	car.lateral = 0.0
	car.v = 60.0
	vfx.update(FRAME)
	check(emitter.amount == 18 and on_kerb and not slow and not mid_track and not emitter.emitting,
		"kerb sparks: 18 streaks fire only on the kerb above 35 m/s (slow=%s, mid=%s, kerb=%s)" % [slow, mid_track, on_kerb])


func _test_graffiti_backfire() -> void:
	var vfx: RaceVfx = world.vfx
	var actor: ActorScript = world.actors[6]
	var car: GtCar = actor.car
	var id: int = car.id
	car.v = 30.0
	car.gear = 4
	vfx.update(FRAME)
	car.gear = 3 # downshift
	vfx.update(FRAME)
	var flame := vfx.flames[id][0] as MeshInstance3D
	var popped: bool = flame.visible
	var core := flame.get_node_or_null("Core") as MeshInstance3D
	var shell_color: Color = ((flame.material_override as StandardMaterial3D).emission) if flame.material_override is StandardMaterial3D else Color.BLACK
	var core_color: Color = ((core.material_override as StandardMaterial3D).emission) if core != null and core.material_override is StandardMaterial3D else Color.BLACK
	vfx.update(0.1)
	var still_lit: bool = flame.visible
	vfx.update(0.1)
	var dead: bool = not flame.visible
	check(popped and still_lit and dead and core != null and core_color.is_equal_approx(Color("#FF1A4B")) and shell_color.is_equal_approx(Color("#D8FF00")),
		"backfire: a downshift lights a crimson-core / acid-yellow flame for 0.12 s")


# --- main menu ---------------------------------------------------------------------------------

func _test_main_menu_concept_01_styling() -> void:
	var menu := load("res://scenes/ui/main_menu.tscn").instantiate() as Control
	root.add_child(menu)
	await process_frame
	var stage := menu.get("stage") as Control
	var title := stage.get_node_or_null("BrandTitle") as Label
	check(title != null and absf(title.rotation - (-0.21)) < 0.005, "menu: the LA VOITURE title leans -12 deg (rotation -0.21)")
	check(stage.get_node_or_null("SprayHalo") != null, "menu: a spray paint halo sits behind the title")
	var tag_ok: bool = false
	for node: Node in stage.get_children():
		var label := node as Label
		tag_ok = tag_ok or (label != null and label.text == "/// GT3 // RACING SYNDICATE // TOON MOTORSPORT")
	check(tag_ok, "menu: the street-marker subtag is stamped under the title")
	var buttons: Array[Button] = [menu.get("exhibition_button"), menu.get("settings_button"), menu.get("credits_button"), menu.get("quit_button")]
	var styled: bool = true
	for button: Button in buttons:
		var normal := button.get_theme_stylebox("normal") as StyleBoxFlat
		var hover := button.get_theme_stylebox("hover") as StyleBoxFlat
		styled = styled and button.text.begins_with("/// ") and normal != null and hover != null \
			and absf(normal.skew.x) > 0.1 and normal.border_width_left == 4 and normal.shadow_offset == Vector2(6.0, 6.0) \
			and hover.bg_color.is_equal_approx(T.ACCENT_ACID_LIME) and hover.shadow_color.is_equal_approx(T.ACCENT_ANIME_CRIMSON) \
			and button.get_theme_color("font_hover_color").is_equal_approx(T.INK_BORDER_BLACK)
	check(styled, "menu: every button is a skewed parallelogram with a 4 px ink border, 6 px shadow, '/// ' prefix and an acid/crimson hover inversion")
	var button: Button = buttons[1]
	var home: Vector2 = button.position
	button.mouse_entered.emit()
	var snapped: Vector2 = button.position - home
	button.mouse_exited.emit()
	for _i: int in range(40):
		await process_frame
	check(snapped.is_equal_approx(Vector2(6.0, -2.0)) and button.position.is_equal_approx(home), "menu: hover snaps the button (+6, -2) and exit settles it back")
	menu.call("_on_credits_pressed")
	var dialog := stage.get_node_or_null("Dialog") as Control
	var panel := dialog.get_node_or_null("DialogPanel") as Control if dialog != null else null
	check(panel != null and absf(panel.rotation - deg_to_rad(-4.0)) < 0.005 and panel.get_node_or_null("SysBadge") != null,
		"menu: modals tilt -4 deg and carry a crimson 'SYS' badge")
	menu.queue_free()
	await process_frame


# --- paddock showroom ----------------------------------------------------------------------------

func _find_toon_body(node: Node) -> ShaderMaterial:
	if node is MeshInstance3D:
		var mesh_instance := node as MeshInstance3D
		if mesh_instance.mesh != null:
			for surface: int in range(mesh_instance.mesh.get_surface_count()):
				var material := (mesh_instance.get_surface_override_material(surface) if mesh_instance.get_surface_override_material(surface) != null else mesh_instance.mesh.surface_get_material(surface)) as ShaderMaterial
				# The Porsche base chassis races in anime_cel_shaded; the nine others in toon_car_paint.
				if material != null and material.shader != null and (material.shader.resource_path.ends_with("toon_car_paint.gdshader") or material.shader.resource_path.ends_with("anime_cel_shaded.gdshader")):
					return material
	for child: Node in node.get_children():
		var found: ShaderMaterial = _find_toon_body(child)
		if found != null:
			return found
	return null


func _test_garage_showroom_toon_consistency() -> void:
	var garage := GarageBuilder.new()
	root.add_child(garage)
	garage.build(2)
	var all_toon: bool = garage.cars.size() == 2
	var all_inked: bool = true
	for car: Node3D in garage.cars:
		var paint: ShaderMaterial = _find_toon_body(car)
		all_toon = all_toon and paint != null
		var hull := paint.next_pass as ShaderMaterial if paint != null else null
		all_inked = all_inked and hull != null and hull.shader.resource_path.ends_with("inverted_hull_outline.gdshader")
	check(all_toon and all_inked, "showroom: stall cars wear the race cel paint with an inverted-hull ink pass")
	var quality_before: int = PS.quality
	var widths: Array[float] = []
	for level: int in [PS.Quality.LOW, PS.Quality.ULTRA]:
		PS.quality = level
		PS.apply_to_tree(garage)
		var paint: ShaderMaterial = _find_toon_body(garage.cars[0])
		var hull := paint.next_pass as ShaderMaterial if paint != null else null
		widths.append(float(hull.get_shader_parameter("outline_width")) if hull != null else -1.0)
	PS.quality = quality_before
	check(widths.size() == 2 and is_equal_approx(widths[0], 0.007) and is_equal_approx(widths[1], 0.02),
		"showroom: the graphics preset drives the showroom ink width (LOW %.3f, ULTRA %.3f)" % [widths[0], widths[1]])
	garage.queue_free()
