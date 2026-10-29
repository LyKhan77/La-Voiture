extends SceneTree

## Pit crew 3D rigging and visual integration (FASE 11 / Langkah 4).
## Proves the master rig and the five hard-surface props load at unit scale, the four biped clips and
## the 24-bone skeleton with its RightHand socket are there, the team uniform shader really takes its
## parameters on a ShaderMaterial, every one of the six roles walks out wearing its own equipment, and
## the crew cycles walk -> idle -> tire_service -> idle -> walk around a real job on a real car.
##
## The visual regressions are behavioural, not source scans: at runtime the node the crew is posed on
## stays upright on the asphalt (the animation carries the posture and the lean/bob), and the fresh
## tyre a handler carries rides at chest height (0.7-0.8 m over the ground) all the way to the box.
## Run: Godot --headless --path . -s res://tests/test_pitcrew_visual.gd

const WorldScene := preload("res://scenes/race_weekend_world.tscn")
const FigureScript := preload("res://scripts/car/pit_crew_figure.gd")
const Liveries := preload("res://scripts/car/team_liveries.gd")
const ToonMaterialsScript := preload("res://scripts/world/shared/toon_materials.gd")
const ActorScript := preload("res://scripts/car/gt_car_actor.gd")

const MASTER_SCENE_PATH := "res://assets/characters/pitcrew/pitcrew_master.glb"
const PROP_SCENE_PATHS: Array[String] = [
	"res://assets/props/wheel_gun.glb",
	"res://assets/props/quick_jack.glb",
	"res://assets/props/fuel_nozzle.glb",
	"res://assets/props/lollipop_board.glb",
	"res://assets/props/fire_extinguisher.glb",
]
const UNIFORM_SHADER_PATH := "res://shaders/pit_crew_uniform.gdshader"
const ALBEDO_TEXTURE_PATH := "res://assets/characters/pitcrew/textures/base_color.png"
const NORMAL_TEXTURE_PATH := "res://assets/characters/pitcrew/textures/normal.png"

const REQUIRED_CLIPS: Array[String] = ["idle", "walk", "run", "tire_service"]
const REQUIRED_ROLES: Array[String] = ["Gunner", "Handler", "Jack", "Fueler", "Fire", "Lollipop"]
const ROLE_COUNTS: Dictionary = {"Gunner": 4, "Handler": 4, "Jack": 2, "Fueler": 1, "Fire": 1, "Lollipop": 1}

const FRAME: float = 1.0 / 60.0
const CREW_TEAM: int = 4
## The crew node is the actor the animation plays on: it must not add posture of its own (half a degree
## and 5 mm are below anything a viewer can see; a 6-30 degree lean or a 5 cm bob is not).
const PITCH_LIMIT_RAD: float = 0.008726646
const GROUND_LIMIT_M: float = 0.005
const CARRIER_MIN_M: float = 0.7
const CARRIER_MAX_M: float = 0.8
const CARRIER_EPSILON_M: float = 0.001
const WALK_OUT_BUDGET: int = 1500
const IDLE_SAMPLES: int = 60
const SERVICE_SAMPLES: int = 10
const WALK_BACK_BUDGET: int = 1800

var failures: int = 0
var assertions: int = 0
var world: Node3D
var choreographer: PitstopChoreographer
var _ground_y: float = 0.0


func _initialize() -> void:
	call_deferred("_run")


func check(ok: bool, description: String) -> void:
	assertions += 1
	if not ok:
		failures += 1
		push_error(description)
	print("[%s] %s" % ["PASS" if ok else "FAIL", description])


func _run() -> void:
	_test_assets_and_rig()
	_test_uniform_shader_definition()
	world = WorldScene.instantiate() as Node3D
	root.add_child(world)
	world.set_process(false)
	await process_frame
	_test_crew_visual_runtime()
	await _test_animated_sole_contact()
	await _test_service_contacts()
	await _dispose_world()
	print("%d assertions, %d failure(s)" % [assertions, failures])
	print("PIT CREW VISUAL: %s" % ("PASS" if failures == 0 else "%d FAILURES" % failures))
	quit(0 if failures == 0 else 1)


# --- #P1..#P3: the assets themselves -------------------------------------------------------

func _instance_of(scene: PackedScene) -> Node3D:
	if scene == null or not scene.can_instantiate():
		return null
	return scene.instantiate() as Node3D


func _has_mesh(root: Node) -> bool:
	if root == null:
		return false
	if root is MeshInstance3D:
		return true
	return not root.find_children("*", "MeshInstance3D", true, false).is_empty()


func _skeleton_of(root: Node) -> Skeleton3D:
	if root == null:
		return null
	if root is Skeleton3D:
		return root as Skeleton3D
	for node: Node in root.find_children("*", "Skeleton3D", true, false):
		return node as Skeleton3D
	return null


func _test_assets_and_rig() -> void:
	var master_scene := load(MASTER_SCENE_PATH) as PackedScene
	var master := _instance_of(master_scene)
	check(master != null and master.scale.is_equal_approx(Vector3.ONE) and _has_mesh(master),
		"#P1 pitcrew_master.glb instantiates with unit scale and visible geometry (scale %s)" % str(master.scale if master != null else Vector3.ZERO))

	var animation_ok: bool = false
	var clip_names: Array = []
	if master != null:
		var player := master.find_child("AnimationPlayer", true, false) as AnimationPlayer
		if player != null:
			animation_ok = true
			for clip: String in REQUIRED_CLIPS:
				animation_ok = animation_ok and player.has_animation(clip) and player.get_animation(clip).get_track_count() > 0
			clip_names = Array(player.get_animation_list())
	check(animation_ok, "#P2 the master AnimationPlayer holds idle, walk, run and tire_service with tracks (found %s)" % str(clip_names))

	var bone_count: int = 0
	var right_hand: int = -1
	if master != null:
		var skeleton := _skeleton_of(master)
		if skeleton != null:
			bone_count = skeleton.get_bone_count()
			right_hand = skeleton.find_bone("RightHand")
	check(bone_count >= 24 and right_hand >= 0 and right_hand < bone_count,
		"#P3 the skeleton has at least 24 bones (%d) and a valid RightHand socket (index %d)" % [bone_count, right_hand])

	var props_load: bool = true
	var props_scale: bool = true
	var props_mesh: bool = true
	var notes: Array[String] = []
	for path: String in PROP_SCENE_PATHS:
		var scene := load(path) as PackedScene
		var prop := _instance_of(scene)
		if prop == null:
			props_load = false
			notes.append("%s missing" % path.get_file())
			continue
		if not prop.scale.is_equal_approx(Vector3.ONE):
			props_scale = false
			notes.append("%s scale %s" % [path.get_file(), str(prop.scale)])
		if not _has_mesh(prop):
			props_mesh = false
			notes.append("%s has no mesh" % path.get_file())
		prop.free()
	check(props_load and props_scale and props_mesh,
		"#P1 all five pit props instantiate at unit scale with geometry (%s)" % (str(notes) if not notes.is_empty() else "wheel gun, quick jack, fuel nozzle, lollipop board, extinguisher"))

	if master != null:
		master.free()


# --- #P4: the uniform shader -----------------------------------------------------------------

func _test_uniform_shader_definition() -> void:
	var shader := load(UNIFORM_SHADER_PATH) as Shader
	var albedo := load(ALBEDO_TEXTURE_PATH) as Texture2D
	var normal := load(NORMAL_TEXTURE_PATH) as Texture2D
	var uniform_names: Array[String] = []
	if shader != null:
		for uniform: Dictionary in shader.get_shader_uniform_list():
			uniform_names.append(String(uniform.get("name", "")))
	var uniforms_ok: bool = uniform_names.has("team_color") and uniform_names.has("albedo_texture") and uniform_names.has("normal_texture")
	check(shader != null and albedo != null and normal != null and uniforms_ok,
		"#P4 %s loads with team_color, albedo_texture and normal_texture uniforms" % UNIFORM_SHADER_PATH)

	var material := ShaderMaterial.new()
	if shader != null:
		material.shader = shader
	var colour := Color("#d9232e")
	material.set_shader_parameter("team_color", colour)
	material.set_shader_parameter("albedo_texture", albedo)
	material.set_shader_parameter("normal_texture", normal)
	var read_colour: Variant = material.get_shader_parameter("team_color")
	var colour_ok: bool = read_colour is Color and (read_colour as Color).is_equal_approx(colour)
	check(material.shader != null and colour_ok and material.get_shader_parameter("albedo_texture") == albedo and material.get_shader_parameter("normal_texture") == normal,
		"#P4 a real ShaderMaterial of the uniform shader takes and returns team_color, albedo_texture and normal_texture")


# --- #P5/#P6: the crew in the actual world -----------------------------------------------------

func _role_nodes(nodes: Array, prefix: String) -> Array[Node3D]:
	var found: Array[Node3D] = []
	for node: Node3D in nodes:
		if String(node.name).begins_with(prefix):
			found.append(node)
	return found


func _animation_player(node: Node) -> AnimationPlayer:
	if node == null:
		return null
	var model := node.get_node_or_null("PitCrewModel")
	if model == null:
		return null
	return model.find_child("AnimationPlayer", true, false) as AnimationPlayer


func _current_animation(node: Node) -> String:
	var player := _animation_player(node)
	return String(player.current_animation) if player != null else ""


func _all_animation(nodes: Array, clip: String) -> bool:
	if nodes.is_empty():
		return false
	for node: Node3D in nodes:
		if _current_animation(node) != clip:
			return false
	return true


func _uniform_material(root: Node) -> ShaderMaterial:
	if root == null:
		return null
	for node: Node in root.find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		var material := mesh.material_override as ShaderMaterial
		if _is_uniform_shader(material):
			return material
		if mesh.mesh != null:
			for surface: int in range(mesh.mesh.get_surface_count()):
				var surface_material: Material = mesh.get_surface_override_material(surface)
				if surface_material == null:
					surface_material = mesh.mesh.surface_get_material(surface)
				var shader_material := surface_material as ShaderMaterial
				if _is_uniform_shader(shader_material):
					return shader_material
	return null


func _is_uniform_shader(material: ShaderMaterial) -> bool:
	return material != null and material.shader != null and material.shader.resource_path == UNIFORM_SHADER_PATH


func _car_of_team(team: int) -> GtCar:
	var race: Variant = world.get("race")
	if race == null:
		return null
	var cars: Array = race.get("cars")
	for candidate: GtCar in cars:
		if candidate.team_id == team:
			return candidate
	return null


func _track_lean_and_lift(nodes: Array, worst_pitch: float, worst_lift: float) -> Vector2:
	# Kept as a small sampler so walk, idle and service states measure the same thing.
	for node: Node3D in nodes:
		worst_pitch = maxf(worst_pitch, absf(node.rotation.x))
		worst_lift = maxf(worst_lift, absf(node.position.y))
	return Vector2(worst_pitch, worst_lift)


func _test_crew_visual_runtime() -> void:
	if world == null:
		check(false, "#P5 the race weekend world instantiates with its pit lane and choreographer")
		return
	choreographer = world.get("choreographer") as PitstopChoreographer
	if choreographer == null:
		check(false, "#P5 the world exposes a PitstopChoreographer")
		return
	var pit_lane: Variant = world.get("pit_lane")
	if pit_lane == null:
		check(false, "#P5 the world builds its pit lane")
		return
	var stall: Transform3D = pit_lane.stall_transform(CREW_TEAM)
	_ground_y = stall.origin.y

	# Walk out. Sample the walking pose every frame: the walk clip, the handler's tyre and the crew
	# node's own lean/lift (which must stay zero so the animation is the only posture).
	choreographer.set_ready_teams([CREW_TEAM])
	var crew: Array = []
	var walk_seen: bool = false
	var walking_state_seen: bool = false
	var walk_frames: int = 0
	var arrived: bool = false
	var worst_walk_pitch: float = 0.0
	var worst_walk_lift: float = 0.0
	var carrier_min: float = INF
	var carrier_max: float = -INF
	var carrier_samples: int = 0
	for _step: int in range(WALK_OUT_BUDGET):
		choreographer.advance(FRAME)
		crew = choreographer.crew_nodes(CREW_TEAM)
		if crew.is_empty():
			continue
		if choreographer.crew_state(CREW_TEAM) == PitstopChoreographer.CrewState.WALKING_OUT:
			walking_state_seen = true
		for node: Node3D in crew:
			if _current_animation(node) != "walk":
				continue
			walk_frames += 1
			if String(node.name).begins_with("Gunner"):
				walk_seen = true
			var tracked: Vector2 = _track_lean_and_lift([node], worst_walk_pitch, worst_walk_lift)
			worst_walk_pitch = tracked.x
			worst_walk_lift = tracked.y
		for handler: Node3D in _role_nodes(crew, "Handler"):
			if _current_animation(handler) != "walk":
				continue
			var tyre := handler.find_child("FreshTyre", true, false) as MeshInstance3D
			if tyre == null or not tyre.visible:
				continue
			var height: float = tyre.global_position.y - _ground_y
			carrier_min = minf(carrier_min, height)
			carrier_max = maxf(carrier_max, height)
			carrier_samples += 1
		if choreographer.crew_state(CREW_TEAM) == PitstopChoreographer.CrewState.READY:
			arrived = true
			break
	check(arrived and walking_state_seen and walk_frames > 0 and walk_seen,
		"#P6 the team walks out of its garage in WALKING_OUT playing walk (%d node-frames walking, arrived %s)" % [walk_frames, str(arrived)])

	crew = choreographer.crew_nodes(CREW_TEAM)
	check(choreographer.crew_state(CREW_TEAM) == PitstopChoreographer.CrewState.READY and _all_animation(_role_nodes(crew, "Gunner"), "idle"),
		"#P6 the four gunners settle to idle on reaching their waiting spots")

	# Idle sway: the node should not carry its own breathing/pitch either.
	var worst_idle_pitch: float = 0.0
	var worst_idle_lift: float = 0.0
	for _sample: int in range(IDLE_SAMPLES):
		choreographer.advance(FRAME)
		var tracked: Vector2 = _track_lean_and_lift(choreographer.crew_nodes(CREW_TEAM), worst_idle_pitch, worst_idle_lift)
		worst_idle_pitch = tracked.x
		worst_idle_lift = tracked.y

	_test_roles_and_equipment(crew)
	_test_crew_uniform(crew)
	_check_carrier_and_idle_pose(carrier_min, carrier_max, carrier_samples, worst_walk_pitch, worst_walk_lift, worst_idle_pitch, worst_idle_lift)

	var car := _car_of_team(CREW_TEAM)
	if car == null:
		check(false, "#P6 a real car of the crew's team exists for the job")
		return
	var actor := world.actor_of(car.id) as Node3D
	if actor == null:
		check(false, "#P6 a real car actor exists for the crew's team")
		return

	# The car is on its box so the crew works the real wheel sockets.
	actor.global_transform = stall
	var gunners := _role_nodes(crew, "Gunner")
	var waiting_jacks: Array[Node3D] = _role_nodes(crew, "Jack")
	var waiting_jacks_empty: bool = waiting_jacks.size() == 2 and choreographer.jobs.is_empty()
	for jack: Node3D in waiting_jacks:
		waiting_jacks_empty = waiting_jacks_empty and jack.find_child("QuickJackModel", true, false) == null and jack.find_child("Prop_QuickJack", true, false) == null

	choreographer.present(car.id, CREW_TEAM, actor, 0, true, 0.0, 0.0)
	var job := choreographer.get_job(car.id)
	var jacks_ok: bool = job != null and job.jacks.size() == 2
	if job != null:
		for jack: MeshInstance3D in job.jacks:
			jacks_ok = jacks_ok and jack.find_child("QuickJackModel", true, false) != null
	check(job != null and job.phase == PitstopChoreographer.Phase.LIFTING and _all_animation(gunners, "idle"),
		"#P6 present() opens the stop with the gunners still idling while the car is lifted")
	check(waiting_jacks_empty and jacks_ok,
		"#P5 the two jack men wait empty-handed; the two quick-jack props exist only while the job is active")

	choreographer.present(car.id, CREW_TEAM, actor, 0, true, 0.5, 0.05)
	job = choreographer.get_job(car.id)
	check(job != null and job.phase == PitstopChoreographer.Phase.SERVICING and _all_animation(gunners, "tire_service"),
		"#P6 the gunners switch to tire_service while the car is being serviced")

	var worst_service_pitch: float = 0.0
	var worst_service_lift: float = 0.0
	for _sample: int in range(SERVICE_SAMPLES):
		choreographer.advance(FRAME)
		var tracked: Vector2 = _track_lean_and_lift(choreographer.crew_nodes(CREW_TEAM), worst_service_pitch, worst_service_lift)
		worst_service_pitch = tracked.x
		worst_service_lift = tracked.y

	choreographer.present(car.id, CREW_TEAM, actor, 0, true, 0.9, 0.05)
	job = choreographer.get_job(car.id)
	check(job != null and job.phase == PitstopChoreographer.Phase.LOWERING and _all_animation(gunners, "idle"),
		"#P6 the gunners return to idle as the car is lowered")

	var worst_after_pitch: float = 0.0
	var worst_after_lift: float = 0.0
	var tracked_after: Vector2 = _track_lean_and_lift(choreographer.crew_nodes(CREW_TEAM), worst_after_pitch, worst_after_lift)
	worst_after_pitch = tracked_after.x
	worst_after_lift = tracked_after.y
	check(worst_service_pitch <= PITCH_LIMIT_RAD and worst_service_lift <= GROUND_LIMIT_M,
		"#R2 the servicing crew node stays upright and on the ground instead of leaning %.1f deg / bobbing %.3f m (the animation poses the body)" % [rad_to_deg(worst_service_pitch), worst_service_lift])
	check(worst_after_pitch <= PITCH_LIMIT_RAD and worst_after_lift <= GROUND_LIMIT_M,
		"#R2 after the service the node still stands upright on the asphalt (max lean %.1f deg, lift %.3f m)" % [rad_to_deg(worst_after_pitch), worst_after_lift])

	choreographer.present(car.id, CREW_TEAM, actor, 0, false, 1.0, 0.0)
	check(choreographer.get_job(car.id) == null and choreographer.finished_ids.has(car.id),
		"#P6 present(in_service = false) closes the job and records the finished car")

	# Walk back: the same crew keeps its nodes and plays walk home, then the garage takes over again.
	choreographer.set_ready_teams([])
	var walk_back_seen: bool = false
	var dismissed: bool = false
	for _step: int in range(WALK_BACK_BUDGET):
		choreographer.advance(FRAME)
		var live: Array = choreographer.crew_nodes(CREW_TEAM)
		if live.is_empty():
			dismissed = true
			break
		if not walk_back_seen:
			for gunner: Node3D in gunners:
				if _current_animation(gunner) == "walk":
					walk_back_seen = true
	var garage := pit_lane.garages[CREW_TEAM] as Node3D
	var standby: MeshInstance3D = null
	if garage != null:
		standby = garage.get_node_or_null("StandbyCrew") as MeshInstance3D
	check(walk_back_seen and dismissed and choreographer.crew_state(CREW_TEAM) == PitstopChoreographer.CrewState.STANDBY and standby != null and standby.visible,
		"#P6 the crew walks back playing walk, is freed, and the garage shows its standing crew again (walk seen %s, dismissed %s)" % [str(walk_back_seen), str(dismissed)])


func _test_roles_and_equipment(crew: Array) -> void:
	var counts: Dictionary = {}
	var counts_ok: bool = crew.size() == 13
	for role: String in REQUIRED_ROLES:
		counts[role] = _role_nodes(crew, role).size()
		counts_ok = counts_ok and int(counts[role]) == int(ROLE_COUNTS[role])
	check(counts_ok, "#P5 the crew of six roles walks out in its full roster (4 gunners, 4 handlers, 2 jacks, fueler, fire, lollipop): %s" % str(counts))

	var models_ok: bool = not crew.is_empty()
	var players_ok: bool = not crew.is_empty()
	for node: Node3D in crew:
		models_ok = models_ok and node.get_node_or_null("PitCrewModel") != null
		players_ok = players_ok and _animation_player(node) != null
	check(models_ok and players_ok, "#P5 every crew member carries the instantiated master model and its AnimationPlayer")

	var gunners := _role_nodes(crew, "Gunner")
	var gun_ok: bool = gunners.size() == 4
	for gunner: Node3D in gunners:
		var gun := gunner.find_child("WheelGun", true, false)
		gun_ok = gun_ok and gun != null and _has_mesh(gun)
	check(gun_ok, "#P5 all four wheel-gun mechanics carry the wheel gun prop")

	var handlers := _role_nodes(crew, "Handler")
	var handler_ok: bool = handlers.size() == 4
	for handler: Node3D in handlers:
		var tyre := handler.find_child("FreshTyre", true, false) as MeshInstance3D
		handler_ok = handler_ok and tyre != null and tyre.visible and tyre.mesh != null
	check(handler_ok, "#P5 all four tyre handlers carry a visible fresh tyre")

	var fuelers := _role_nodes(crew, "Fueler")
	var fires := _role_nodes(crew, "Fire")
	var fueler_ok: bool = fuelers.size() == 1 and fuelers[0].find_child("FuelNozzle", true, false) != null
	var fire_ok: bool = fires.size() == 1 and fires[0].find_child("FireExtinguisher", true, false) != null
	check(fueler_ok and fire_ok, "#P5 the fueler carries the fuel nozzle and the fire marshal the extinguisher")

	var lollipops := _role_nodes(crew, "Lollipop")
	var lollipop_ok: bool = lollipops.size() == 1
	if lollipop_ok:
		var pole := lollipops[0].find_child("Pole", true, false)
		var pole_mesh: bool = pole != null and (pole is MeshInstance3D or not pole.find_children("*", "MeshInstance3D", true, false).is_empty())
		lollipop_ok = pole_mesh
	check(lollipop_ok, "#P5 the lollipop man carries his board on its pole")


func _test_crew_uniform(crew: Array) -> void:
	var team_colour: Color = Liveries.color_for(CREW_TEAM)
	var uniform_ok: bool = not crew.is_empty()
	var missing: int = 0
	for node: Node3D in crew:
		var material := _uniform_material(node.get_node_or_null("PitCrewModel"))
		if material == null:
			uniform_ok = false
			missing += 1
			continue
		var team_value: Variant = material.get_shader_parameter("team_color")
		if team_value is Color:
			uniform_ok = uniform_ok and (team_value as Color).is_equal_approx(team_colour)
		else:
			uniform_ok = false
		uniform_ok = uniform_ok and material.get_shader_parameter("albedo_texture") != null and material.get_shader_parameter("normal_texture") != null
	check(uniform_ok, "#P4 every crew member's master mesh wears the uniform shader with its team colour (team %d, %d without a uniform material)" % [CREW_TEAM, missing])


func _check_carrier_and_idle_pose(carrier_min: float, carrier_max: float, carrier_samples: int,
		worst_walk_pitch: float, worst_walk_lift: float, worst_idle_pitch: float, worst_idle_lift: float) -> void:
	check(carrier_samples > 20 and carrier_min >= CARRIER_MIN_M - CARRIER_EPSILON_M and carrier_max <= CARRIER_MAX_M + CARRIER_EPSILON_M,
		"#R1 the tyre a handler carries rides at chest height while walking out: %.3f-%.3f m over %d walking frames (required %.1f-%.1f)" % [carrier_min, carrier_max, carrier_samples, CARRIER_MIN_M, CARRIER_MAX_M])
	check(worst_walk_pitch <= PITCH_LIMIT_RAD and worst_walk_lift <= GROUND_LIMIT_M,
		"#R2 no artificial pitch/bob/float while walking: max lean %.1f deg, max lift %.3f m" % [rad_to_deg(worst_walk_pitch), worst_walk_lift])
	check(worst_idle_pitch <= PITCH_LIMIT_RAD and worst_idle_lift <= GROUND_LIMIT_M,
		"#R2 no artificial pitch/bob/float while waiting at idle: max lean %.1f deg, max lift %.3f m" % [rad_to_deg(worst_idle_pitch), worst_idle_lift])


## Measure all boot vertices, independently of the production sixteen-point support set.
func _test_animated_sole_contact() -> void:
	var crew: PitstopChoreographer.Crew = choreographer._ensure_ready(0)
	var mesh: MeshInstance3D = crew.members[0].character_model.find_child("char1", true, false)
	var arrays: Array = mesh.mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
	var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
	var worst: float = 0.0
	var samples: int = 0
	for clip: StringName in [&"idle", &"walk", &"run", &"tire_service"]:
		for member: PitstopChoreographer.Member in crew.members:
			member.anim_player.play(clip, 0.0)
		for fraction: float in [0.0, 0.25, 0.5, 0.75]:
			for member: PitstopChoreographer.Member in crew.members:
				member.anim_player.seek(member.anim_player.get_animation(clip).length * fraction, true)
			await process_frame
			await process_frame
			for member: PitstopChoreographer.Member in crew.members:
				var frame: Transform3D = member.node.global_transform.affine_inverse() * member.skeleton.global_transform
				var poses: Array[Transform3D] = []
				for bind: int in range(mesh.skin.get_bind_count()):
					var bone: int = member.skeleton.find_bone(mesh.skin.get_bind_name(bind))
					poses.append(frame * member.skeleton.get_bone_global_pose(bone) * mesh.skin.get_bind_pose(bind))
				var minimum: float = INF
				for vertex: int in range(vertices.size()):
					if vertices[vertex].y > 0.15:
						continue
					var height: float = 0.0
					for influence: int in range(4):
						var index: int = vertex * 4 + influence
						if weights[index] > 0.0:
							height += (poses[bones[index]] * vertices[vertex]).y * weights[index]
					minimum = minf(minimum, height)
				worst = maxf(worst, absf(minimum))
				samples += 1
	check(worst <= 0.01,
		"#R3 all 13 members' animated boot soles contact asphalt within 1 cm across all four clips (%d poses, worst %.6f m)" % [samples, worst])



func _record_grip_error(member: PitstopChoreographer.Member, errors: Dictionary) -> void:
	var worst: float = 0.0
	for hand: int in range(member.arm_ik.setting_count):
		var bone: int = member.skeleton.find_bone("RightHand" if hand == 0 else "LeftHand")
		var wrist: Vector3 = (member.skeleton.global_transform * member.skeleton.get_bone_global_pose(bone)).origin
		worst = maxf(worst, wrist.distance_to(member.grips[hand].global_position))
	errors[member.node.name] = worst


func _test_service_contacts() -> void:
	var crew: PitstopChoreographer.Crew = choreographer._crews[0]
	var actor: GtCarActor = world.actor_of(0)
	actor.global_transform = world.pit_lane.stall_transform(0)
	var grip_errors: Dictionary = {}
	for member: PitstopChoreographer.Member in crew.members:
		member.anim_player.play(&"idle", 0.0)
		member.arm_ik.modification_processed.connect(_record_grip_error.bind(member, grip_errors))
	choreographer.set_ready_teams([0])
	for frame: int in range(60):
		choreographer.advance(FRAME)
		choreographer.present(0, 0, actor, 0, true, 0.12, 0.15)
		await process_frame
	var job: PitstopChoreographer.Job = choreographer.get_job(0)
	var worst_grip: float = 0.0
	var worst_nozzle: float = 0.0
	for member: PitstopChoreographer.Member in crew.members:
		if member.role == FigureScript.Role.JACK:
			continue # lever is foot-pressed down while the jack men stand clear during service
		worst_grip = maxf(worst_grip, float(grip_errors.get(member.node.name, INF)))
		if member.role == FigureScript.Role.GUNNER:
			var tip: Vector3 = member.tool_prop.to_global(Vector3(0.0, 0.08, 0.205))
			worst_nozzle = maxf(worst_nozzle, tip.distance_to(job.chassis._wheel_sockets[member.corner].global_position))
	check(worst_grip <= 0.05, "#R4 settled tool/tyre grips stay inside the 5 cm glove envelope (worst %.6f m)" % worst_grip)
	check(worst_nozzle <= 0.01, "#R5 all four gun sockets meet the lifted wheel hubs within 1 cm (worst %.6f m)" % worst_nozzle)
	var jack_error: float = 0.0
	for jack: MeshInstance3D in job.jacks:
		var z: float = 0.32 if jack.position.z < 0.0 else -0.32
		var pad: Vector3 = crew.root.to_local(jack.to_global(Vector3(0.16, 0.01, z)))
		jack_error = maxf(jack_error, absf(pad.y - (0.06 + job.lift_m)))
	check(jack_error <= 0.01, "#R6 both jack cradles follow the 15 cm chassis lift without stretching their meshes (worst %.6f m)" % jack_error)
	choreographer.present(0, 0, actor, 0, true, 0.30, 0.15)
	var handlers_carry: bool = true
	for wheel: Node3D in job.carried:
		handlers_carry = handlers_carry and wheel != null and String(wheel.get_parent().get_parent().name).begins_with("Handler")
	check(handlers_carry, "#R7 all four removed wheels are carried by handlers, leaving gunner hands free")
	choreographer.present(0, 0, actor, 0, false, 1.0, 0.0)
	check(_all_animation(_role_nodes(choreographer.crew_nodes(0), "Gunner"), "idle"),
		"#R8 ending a stop releases the gunner service pose immediately")

# --- cleanup -----------------------------------------------------------------------------------

func _dispose_world() -> void:
	if choreographer != null:
		var open_jobs: Array = choreographer.jobs.duplicate()
		for job: PitstopChoreographer.Job in open_jobs:
			choreographer.present(job.car_id, job.team, job.actor, job.compound, false, 1.0, 0.0)
		choreographer.set_ready_teams([])
		for _step: int in range(300):
			choreographer.advance(FRAME * 2.0)
	if world != null:
		var race: Variant = world.get("race")
		if race != null and race.has_method("dispose"):
			race.call("dispose")
		world.queue_free()
		for _frame: int in range(3):
			await process_frame
	ToonMaterialsScript._cache.clear()
	ActorScript._paint_cache.clear()
	FigureScript.clear_cache()
