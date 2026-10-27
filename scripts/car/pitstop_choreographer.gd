class_name PitstopChoreographer
extends Node3D

## 3D pit stop crew (FASE 5.5 look, FASE 5.6 driver, refined after the FASE 10 feedback). The GT sim runs
## the stop: it brakes the car to 80 km/h, parks it on its team's box, lifts it 15 cm on its stop timer,
## swaps the tyres and sends it out. This node acts that out with a full crew of 13 per team:
## four wheel-gun mechanics and four tyre handlers (one pair per corner), a jack man at the nose and one at
## the tail, the fueler, a fire marshal and the lollipop man.
## The crew lives in its garage (the garage's static StandbyCrew mesh). When the world reports that the
## team's car is on the way (set_ready_teams), the same people walk out into the working lane and wait,
## ready, beside the box; present() then acts out the stop; once the car has gone they walk back, their
## animated nodes are freed and the garage shows its standing crew again.

signal stop_started(car_id: int)
signal wheel_swapped(car_id: int, corner: int, compound: int)
signal job_finished(car_id: int)
## A mechanic's wheel gun runs: once as a wheel comes off, once as the new one goes on.
signal pit_gun_fired(car_id: int, corner: int, removing: bool)

enum Phase { LIFTING, SERVICING, LOWERING, RELEASE }
enum CrewState { STANDBY, WALKING_OUT, READY, WALKING_BACK }

const PitLaneScript := preload("res://scripts/world/pit_lane_complex.gd")
const ModularCarAssembler := preload("res://scripts/car/modular_car_assembler.gd")
const ToonMaterials := preload("res://scripts/world/toon_materials.gd")
const Liveries := preload("res://scripts/car/team_liveries.gd")
const FigureScript := preload("res://scripts/car/pit_crew_figure.gd")
const MeshBatchScript := preload("res://scripts/world/mesh_batch.gd")

const PitCrewMasterScene := preload("res://assets/characters/pitcrew/pitcrew_master.glb")
const PitCrewUniformShader := preload("res://shaders/pit_crew_uniform.gdshader")
const PitCrewAlbedoTex := preload("res://assets/characters/pitcrew/textures/base_color.png")
const PitCrewNormalTex := preload("res://assets/characters/pitcrew/textures/normal.png")

const WheelGunScene := preload("res://assets/props/wheel_gun.glb")
const QuickJackScene := preload("res://assets/props/quick_jack.glb")
const FuelNozzleScene := preload("res://assets/props/fuel_nozzle.glb")
const LollipopBoardScene := preload("res://assets/props/lollipop_board.glb")
const FireExtinguisherScene := preload("res://assets/props/fire_extinguisher.glb")

const PIT_GUN_STREAM := preload("res://assets/audio/sfx/pit_gun.wav")

## People per team by role; the garage's standing crew (PitLaneComplex.standby_roles) is the same set.
const ROSTER: Dictionary = {"gunner": 4, "handler": 4, "jack": 2, "fueler": 1, "fire": 1, "lollipop": 1}
## Where each role waits for the car, in the box frame (x across the lane toward the garage, z along it,
## - is the direction of travel); the car's centre is the origin. Corner order: FL, FR, RL, RR. Everyone
## waits inside the working lane (lateral 14.1 .. 19.95) and out of the way of the car pulling into its box
## (it swings in from the fast lane over its last 16 m): the rear-end crew keeps a metre further off.
const READY_SPOTS: Dictionary = {
	"gunner": [Vector3(-2.6, 0.0, -1.35), Vector3(2.6, 0.0, -1.35), Vector3(-2.6, 0.0, 1.35), Vector3(2.6, 0.0, 1.35)],
	"handler": [Vector3(-2.8, 0.0, -2.4), Vector3(2.8, 0.0, -2.4), Vector3(-2.8, 0.0, 2.4), Vector3(2.8, 0.0, 2.4)],
	"jack": [Vector3(0.0, 0.0, -3.1), Vector3(1.9, 0.0, 3.6)],
	"fueler": [Vector3(2.35, 0.0, 0.2)],
	"fire": [Vector3(-2.4, 0.0, 0.2)],
	"lollipop": [Vector3(-0.9, 0.0, -4.6)],
}
## Where they work once the car has stopped: beside each wheel, at the nose and the tail.
const WORK_SPOTS: Dictionary = {
	"gunner": [Vector3(-1.6, 0.0, -1.35), Vector3(1.6, 0.0, -1.35), Vector3(-1.6, 0.0, 1.35), Vector3(1.6, 0.0, 1.35)],
	"handler": [Vector3(-2.2, 0.0, -2.15), Vector3(2.2, 0.0, -2.15), Vector3(-2.2, 0.0, 2.15), Vector3(2.2, 0.0, 2.15)],
	"jack": [Vector3(0.0, 0.0, -3.1), Vector3(0.0, 0.0, 3.1)],
	"fueler": [Vector3(2.35, 0.0, 0.2)],
	"fire": [Vector3(-2.4, 0.0, 0.2)],
	"lollipop": [Vector3(-0.9, 0.0, -4.6)],
}
## Seconds-to-1 rate at which the crew steps from its waiting spot to its working spot (about 0.6 s).
const WORK_STEP_RATE: float = 1.6
## The crew walks around the nose or the tail of the box, never across it.
const FRONT_CORRIDOR_Z: float = -5.4
const REAR_CORRIDOR_Z: float = 4.9
const GARAGE_DOOR_X: float = 3.4

const LIFT_HEIGHT_M: float = 0.15
const SERVICE_TIME_S: float = 1.6
const CORNER_COUNT: int = 4
const GUN_VOICES: int = 4
const GUN_RANGE_M: float = 70.0
const WALK_SPEED_MPS: float = 2.3
const TURN_RATE: float = 9.0
const TYRE_RADIUS_M: float = 0.33
const TYRE_WIDTH_M: float = 0.3
const COMPOUND_COLORS: Array[Color] = [Color("#e0212e"), Color("#ffd400"), Color("#f4f5f7"), Color("#2f6fe0")]
const NEUTRAL_RIM := Color("#6b7080")
const JACK_REACH_M: float = 2.1
## Extremal boot vertices of the master mesh, sampled across all four clips at 30 Hz.
## ponytail: tied to this master topology; resample with scratch/calibrate_pitcrew_soles.gd if it changes.
const SOLE_VERTICES: Array[int] = [5416, 8760, 12883, 7711, 4978, 145, 8758, 2273, 4975, 4979, 7428, 8592, 4224, 4228, 8587, 8574]
const ANIMATION_BLEND_S: float = 0.18

## Bend the torso toward carried equipment before arm IK; feet keep their authored locomotion.
class CarryPose extends SkeletonModifier3D:
	var spine: int = -1
	var lean: float = 0.65

	func _process_modification_with_delta(_delta: float) -> void:
		var skeleton: Skeleton3D = get_skeleton()
		var pose: Transform3D = skeleton.get_bone_global_pose(spine)
		pose.basis = Basis(Vector3.RIGHT, lean) * pose.basis
		skeleton.set_bone_global_pose(spine, pose)

class Job extends RefCounted:
	var car_id: int = 0
	var team: int = 0
	var actor: Node3D
	var chassis: ModularCarAssembler
	var compound: int = 0
	var wheel_scene: PackedScene
	var phase: int = Phase.LIFTING
	var lift_m: float = 0.0
	var wheels_off: Array[bool] = [false, false, false, false]
	var wheels_on: Array[bool] = [false, false, false, false]
	var crew: Node3D
	## The four wheel-gun mechanics in corner order (FL, FR, RL, RR).
	var crew_members: Array[Node3D] = []
	var jacks: Array[MeshInstance3D] = []
	var lollipop: Node3D
	var lollipop_disc: MeshInstance3D
	var carried: Array[Node3D] = [null, null, null, null]

## One person of a team's crew: the animated node plus the way between the garage and the box.
class Member extends RefCounted:
	var node: Node3D
	var role: int = 0
	var corner: int = -1 # wheel corner of a gunner or handler
	var slot: int = 0
	var route: PackedVector3Array = PackedVector3Array() # box frame, garage spot first, ready spot last
	var route_length: float = 0.0
	var walked: float = 0.0 # 0 = in the garage, route_length = at the ready spot
	var ready: Vector3 = Vector3.ZERO # waiting spot (the end of the route)
	var work: Vector3 = Vector3.ZERO # working spot beside the stopped car
	var work_blend: float = 0.0 # 0 = waiting, 1 = working
	var service_blend: float = 0.0
	var facing: float = 0.0 # yaw at the ready and working spots (toward the car)
	var yaw: float = 0.0
	var speed: float = WALK_SPEED_MPS
	var tyre: MeshInstance3D # the fresh tyre a handler carries
	var pole: Node3D # the lollipop man's board
	var disc: MeshInstance3D
	var character_model: Node3D
	var anim_player: AnimationPlayer
	var tool_prop: Node3D
	var skeleton: Skeleton3D
	var arm_ik: TwoBoneIK3D
	var grips: Array[Node3D] = []
	var sole_poses: Array[Transform3D] = []
	var carry_pose: CarryPose

class Crew extends RefCounted:
	var team: int = 0
	var state: int = CrewState.STANDBY
	var root: Node3D
	var members: Array[Member] = []

var pit_lane: Node
var wheel_scenes: Array[PackedScene] = [] # index = tire compound
var jobs: Array[Job] = []
var finished_ids: Array[int] = []
var gun_shots: int = 0

var _crews: Dictionary = {} # team -> Crew; only teams whose crew is out of its garage
var _wanted: Dictionary = {} # team -> true
var _tyre_meshes: Dictionary = {}
var _clock: float = 0.0
var _gun_players: Array[AudioStreamPlayer3D] = []
var _next_gun: int = 0
var _uniforms: Dictionary = {}
var _sole_points: PackedVector3Array = PackedVector3Array()
var _sole_bones: PackedInt32Array = PackedInt32Array()
var _sole_weights: PackedFloat32Array = PackedFloat32Array()
var _bind_poses: Array[Transform3D] = []
var _bind_bones: Array[int] = []
var _clips_prepared: bool = false


func setup(p_pit_lane: Node, p_wheel_scenes: Array[PackedScene]) -> void:
	pit_lane = p_pit_lane
	wheel_scenes = p_wheel_scenes


func _exit_tree() -> void:
	FigureScript.clear_cache()


func get_job(car_id: int) -> Job:
	for job: Job in jobs:
		if job.car_id == car_id:
			return job
	return null


# --- crew life cycle -------------------------------------------------------

## The teams whose car is on the way to the box (or in it): their crew steps out and waits, every other
## crew is (or goes back) in its garage. Call every frame with the full list.
## How many teams the pit lane in use has a box for.
func _team_count() -> int:
	return int(pit_lane.get("team_count")) if pit_lane != null else PitLaneScript.TEAM_COUNT


func set_ready_teams(teams: Array) -> void:
	_wanted.clear()
	for team: Variant in teams:
		_wanted[clampi(int(team), 0, _team_count() - 1)] = true


## Walks the crews between their garages and the working lane; `delta` is game time.
func advance(delta: float) -> void:
	_clock += delta
	for team: int in _wanted:
		if not _crews.has(team):
			_begin_crew(team)
	for team: int in _crews.keys():
		var crew: Crew = _crews[team]
		var wanted: bool = _wanted.has(team) or _has_job_of_team(team)
		if wanted and crew.state == CrewState.WALKING_BACK:
			crew.state = CrewState.WALKING_OUT
		elif not wanted and (crew.state == CrewState.WALKING_OUT or crew.state == CrewState.READY):
			crew.state = CrewState.WALKING_BACK
		match crew.state:
			CrewState.WALKING_OUT:
				var arrived: bool = true
				for member: Member in crew.members:
					member.walked = minf(member.route_length, member.walked + member.speed * delta)
					_place(member, delta, true)
					arrived = arrived and member.walked >= member.route_length
				if arrived:
					crew.state = CrewState.READY
			CrewState.WALKING_BACK:
				if _stepping_out_of_work(crew):
					_wait_or_work(crew, delta, false)
					continue
				var home: bool = true
				for member: Member in crew.members:
					member.walked = maxf(0.0, member.walked - member.speed * delta)
					_place(member, delta, false)
					home = home and member.walked <= 0.0
				if home:
					_dismiss(crew)
			CrewState.READY:
				_wait_or_work(crew, delta, _has_job_of_team(team))


func crew_state(team: int) -> int:
	return (_crews[team] as Crew).state if _crews.has(team) else CrewState.STANDBY


## The animated people of a team's crew; empty while they are in their garage.
func crew_nodes(team: int) -> Array:
	var nodes: Array = []
	if _crews.has(team):
		for member: Member in (_crews[team] as Crew).members:
			nodes.append(member.node)
	return nodes


func _has_job_of_team(team: int) -> bool:
	for job: Job in jobs:
		if job.team == team:
			return true
	return false


## The crew leaves its garage: the standing crew is hidden and the same people start walking.
func _begin_crew(team: int) -> Crew:
	var crew := Crew.new()
	crew.team = team
	crew.root = Node3D.new()
	crew.root.name = "PitCrew%02d" % (team + 1)
	add_child(crew.root)
	crew.root.global_transform = pit_lane.stall_transform(team)
	var color: Color = Liveries.color_for(team)
	var roles: Array = pit_lane.crew_roles() if pit_lane != null else PitLaneScript.standby_roles()
	var counts: Dictionary = {}
	for slot: int in range(roles.size()):
		var role: int = roles[slot]
		var index: int = int(counts.get(role, 0))
		counts[role] = index + 1
		crew.members.append(_make_member(crew, role, index, slot, color))
	crew.state = CrewState.WALKING_OUT
	_crews[team] = crew
	_set_standby_visible(team, false)
	return crew


func _dismiss(crew: Crew) -> void:
	crew.state = CrewState.STANDBY
	crew.root.queue_free()
	_crews.erase(crew.team)
	_set_standby_visible(crew.team, true)


func _set_standby_visible(team: int, shown: bool) -> void:
	if pit_lane == null:
		return
	var garage: Node3D = pit_lane.garage_for_team(team) if pit_lane.has_method("garage_for_team") else null
	if garage == null and team < pit_lane.garages.size():
		garage = pit_lane.garages[team]
	if garage == null:
		return
	var standby := garage.get_node_or_null("StandbyCrew") as Node3D
	if standby != null:
		standby.visible = shown


## A job needs the crew in place now (the world did not send it out first): snap everyone to the box.
func _ensure_ready(team: int) -> Crew:
	var crew: Crew = _crews[team] if _crews.has(team) else _begin_crew(team)
	if crew.state != CrewState.READY:
		for member: Member in crew.members:
			member.walked = member.route_length
			member.yaw = member.facing
			_place(member, 0.0, true)
		crew.state = CrewState.READY
	return crew


func _make_member(crew: Crew, role: int, index: int, slot: int, color: Color) -> Member:
	var member := Member.new()
	member.role = role
	member.slot = slot
	var role_name: String = FigureScript.ROLE_NAMES[role]
	member.corner = index if role == FigureScript.Role.GUNNER or role == FigureScript.Role.HANDLER else -1
	member.speed = WALK_SPEED_MPS * (0.92 + 0.016 * float(slot))
	var node := Node3D.new()
	node.name = "%s%d" % [role_name.capitalize(), index]
	var body := MeshInstance3D.new()
	body.name = "Body"
	body.mesh = FigureScript.mesh_for(role, color)
	node.add_child(body)
	var hands := Node3D.new()
	hands.name = "Hands"
	hands.position = Vector3(0.0, 0.75, -0.55)
	node.add_child(hands)
	crew.root.add_child(node)
	member.node = node

	# Instantiate master anime rigged character model
	if PitCrewMasterScene != null:
		var model: Node3D = PitCrewMasterScene.instantiate() as Node3D
		model.name = "PitCrewModel"
		# Face towards -Z (Godot standard forward direction)
		model.rotation.y = PI
		node.add_child(model)
		member.character_model = model
		# Hide low-poly box fallback
		body.visible = false

		var mesh_inst: MeshInstance3D = model.find_child("char1", true, false) as MeshInstance3D
		if mesh_inst != null:
			if not _uniforms.has(color):
				var mat := ShaderMaterial.new()
				mat.shader = PitCrewUniformShader
				mat.set_shader_parameter("albedo_texture", PitCrewAlbedoTex)
				mat.set_shader_parameter("normal_texture", PitCrewNormalTex)
				mat.set_shader_parameter("team_color", color)
				mat.set_shader_parameter("accent_color", Color.WHITE)
				mat.set_shader_parameter("suit_color_strength", 1.0)
				mat.set_shader_parameter("rim_color", color)
				_uniforms[color] = mat
			mesh_inst.material_override = _uniforms[color]

		var ap: AnimationPlayer = model.find_child("AnimationPlayer", true, false) as AnimationPlayer
		if ap != null:
			member.anim_player = ap
			ap.playback_default_blend_time = ANIMATION_BLEND_S
			for clip: StringName in [&"idle", &"walk", &"run", &"tire_service"]:
				ap.get_animation(clip).loop_mode = Animation.LOOP_LINEAR
				if not _clips_prepared:
					var animation: Animation = ap.get_animation(clip)
					for track: int in range(animation.get_track_count()):
						if animation.track_get_type(track) != Animation.TYPE_ROTATION_3D or not String(animation.track_get_path(track)).ends_with(":Hips"):
							continue
						# Route yaw owns facing; the source idle turns its hips away from the tools.
						for key: int in range(animation.track_get_key_count(track)):
							var rotation: Quaternion = animation.track_get_key_value(track, key)
							var angles: Vector3 = rotation.get_euler()
							angles.y = 0.0
							animation.track_set_key_value(track, key, Quaternion.from_euler(angles))
			_clips_prepared = true
			ap.play("idle")

		# Role equipment attachment
		match role:
			FigureScript.Role.GUNNER:
				if WheelGunScene != null:
					var gun: Node3D = WheelGunScene.instantiate() as Node3D
					gun.name = "WheelGun"
					gun.position = Vector3(0.0, 0.85, -0.30)
					gun.rotation.y = PI
					node.add_child(gun)
					member.tool_prop = gun
			FigureScript.Role.FUELER:
				if FuelNozzleScene != null:
					var nozzle: Node3D = FuelNozzleScene.instantiate() as Node3D
					nozzle.name = "FuelNozzle"
					nozzle.position = Vector3(0.0, 1.0, -0.30)
					nozzle.rotation.y = PI
					node.add_child(nozzle)
					member.tool_prop = nozzle
			FigureScript.Role.FIRE:
				if FireExtinguisherScene != null:
					var ext: Node3D = FireExtinguisherScene.instantiate() as Node3D
					ext.name = "FireExtinguisher"
					ext.position = Vector3(0.30, 0.38, -0.12)
					node.add_child(ext)
					member.tool_prop = ext
	var spot: Vector3 = (READY_SPOTS[role_name] as Array)[index]
	member.ready = spot
	member.work = (WORK_SPOTS[role_name] as Array)[index]
	# The garage mouth is where the lane's own geometry puts it, so a street circuit's shallower
	# working lane walks the crew out over its own apron, not the Apex Ring's.
	var door_garage: Vector3 = pit_lane.crew_spot(slot) if pit_lane != null else PitLaneScript.standby_spot(slot)
	var setback: float = (float(pit_lane.garage_front_m) - float(pit_lane.stall_lane_m)) if pit_lane != null else (PitLaneScript.GARAGE_FRONT_M - PitLaneScript.STALL_LANE_M)
	var home := Vector3(door_garage.x + setback, 0.0, door_garage.z)
	member.route = _route(home, spot, role)
	for leg: int in range(member.route.size() - 1):
		member.route_length += member.route[leg].distance_to(member.route[leg + 1])
	member.facing = _yaw_for(Vector3.ZERO - member.work)
	member.yaw = _yaw_for(Vector3(-1.0, 0.0, 0.0)) # standing in the garage, looking at the lane
	if role == FigureScript.Role.HANDLER:
		member.tyre = MeshInstance3D.new()
		member.tyre.name = "FreshTyre"
		member.tyre.mesh = _tyre_mesh(-1)
		hands.add_child(member.tyre)
	elif role == FigureScript.Role.LOLLIPOP:
		_build_lollipop(member)
	if member.character_model != null:
		_prepare_rig(member)
	_place(member, 0.0, true)
	return member


func _play_member(member: Member, clip: StringName) -> void:
	if member.anim_player != null and member.anim_player.current_animation != clip:
		member.anim_player.speed_scale = 1.3 if clip == &"walk" else 1.0
		member.anim_player.play(clip, ANIMATION_BLEND_S)


func _prepare_rig(member: Member) -> void:
	member.skeleton = member.character_model.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	var mesh: MeshInstance3D = member.character_model.find_child("char1", true, false) as MeshInstance3D
	if _sole_points.is_empty():
		var arrays: Array = mesh.mesh.surface_get_arrays(0)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
		var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
		for vertex: int in SOLE_VERTICES:
			_sole_points.append(vertices[vertex])
			for influence: int in range(4):
				_sole_bones.append(bones[vertex * 4 + influence])
				_sole_weights.append(weights[vertex * 4 + influence])
		for bind: int in range(mesh.skin.get_bind_count()):
			_bind_poses.append(mesh.skin.get_bind_pose(bind))
			_bind_bones.append(member.skeleton.find_bone(mesh.skin.get_bind_name(bind)))
	member.sole_poses.resize(_bind_poses.size())
	member.skeleton.skeleton_updated.connect(_ground_member.bind(member))

	var grip_parent: Node3D = member.node
	var offsets: Array[Vector3] = [Vector3(0.25, 0.95, -0.25), Vector3(-0.25, 0.95, -0.25)]
	match member.role:
		FigureScript.Role.GUNNER:
			grip_parent = member.tool_prop
			offsets = [Vector3.ZERO, Vector3(0.04, 0.08, 0.10)]
		FigureScript.Role.HANDLER:
			grip_parent = member.node.get_node("Hands")
			offsets = [Vector3(0.22, 0.23, 0.22), Vector3(-0.22, 0.23, 0.22)]
		FigureScript.Role.FUELER:
			grip_parent = member.tool_prop
			offsets = [Vector3(0.0, 0.15, 0.03), Vector3(0.14, 0.0, 0.05)]
		FigureScript.Role.FIRE:
			grip_parent = member.tool_prop
			offsets = [Vector3(0.0, 0.51, -0.04), Vector3(-0.10, 0.30, 0.0)]
		FigureScript.Role.LOLLIPOP:
			grip_parent = member.pole
			offsets = [Vector3.ZERO, Vector3(0.0, -0.18, 0.0)]
	if member.role in [FigureScript.Role.HANDLER, FigureScript.Role.FUELER, FigureScript.Role.LOLLIPOP, FigureScript.Role.JACK]:
		member.carry_pose = CarryPose.new()
		member.carry_pose.spine = member.skeleton.find_bone("Spine02")
		member.skeleton.add_child(member.carry_pose)
		member.carry_pose.lean = 0.9 if member.role in [FigureScript.Role.HANDLER, FigureScript.Role.FUELER] else 0.65
		if member.role == FigureScript.Role.JACK:
			member.carry_pose.lean = 0.0
	var ik := TwoBoneIK3D.new()
	ik.name = "ToolGripIK"
	member.skeleton.add_child(ik)
	member.arm_ik = ik
	ik.setting_count = 1 if member.role == FigureScript.Role.FIRE else 2
	ik.active = member.role != FigureScript.Role.JACK
	for hand: int in range(ik.setting_count):
		var grip := Node3D.new()
		grip.name = "RightGrip" if hand == 0 else "LeftGrip"
		grip_parent.add_child(grip)
		grip.position = offsets[hand]
		member.grips.append(grip)
		var pole := Node3D.new()
		pole.name = "RightElbow" if hand == 0 else "LeftElbow"
		member.node.add_child(pole)
		pole.position = Vector3(0.65 if hand == 0 else -0.65, 0.85, 0.12)
		var side: String = "Right" if hand == 0 else "Left"
		ik.set_root_bone_name(hand, side + "Arm")
		ik.set_middle_bone_name(hand, side + "ForeArm")
		ik.set_end_bone_name(hand, side + "Hand")
		ik.set_target_node(hand, ik.get_path_to(grip))
		ik.set_pole_node(hand, ik.get_path_to(pole))
	member.anim_player.advance(0.0)
	_ground_member(member)


## Skin only sixteen measured support vertices; reuse pose storage instead of reading the mesh each frame.
func _ground_member(member: Member) -> void:
	var frame: Transform3D = member.node.global_transform.affine_inverse() * member.skeleton.global_transform
	for bind: int in range(_bind_poses.size()):
		member.sole_poses[bind] = frame * member.skeleton.get_bone_global_pose(_bind_bones[bind]) * _bind_poses[bind]
	var minimum: float = INF
	for vertex: int in range(_sole_points.size()):
		var height: float = 0.0
		for influence: int in range(4):
			var index: int = vertex * 4 + influence
			if _sole_weights[index] > 0.0:
				height += (member.sole_poses[_sole_bones[index]] * _sole_points[vertex]).y * _sole_weights[index]
		minimum = minf(minimum, height)
	member.character_model.position.y -= minimum


## Straight to the spot on the garage side; around the nose or the tail to the lane side.
func _route(home: Vector3, spot: Vector3, role: int) -> PackedVector3Array:
	if spot.x >= 0.0 or role == FigureScript.Role.JACK:
		return PackedVector3Array([home, spot])
	# Someone who works mid-car goes around the end of the box nearest to where he starts.
	var side: float = spot.z if absf(spot.z) >= 1.0 else home.z
	var corridor: float = FRONT_CORRIDOR_Z if side < 0.0 else REAR_CORRIDOR_Z
	return PackedVector3Array([home, Vector3(GARAGE_DOOR_X, 0.0, corridor), Vector3(spot.x, 0.0, corridor), spot])


## Yaw that turns a figure (it faces -Z) to look along `direction`.
static func _yaw_for(direction: Vector3) -> float:
	return atan2(-direction.x, -direction.z)


## Puts a member where `walked` says, facing along the way he walks; he turns to the car on arrival.
func _place(member: Member, delta: float, outbound: bool) -> void:
	var remaining: float = clampf(member.walked, 0.0, member.route_length)
	var position: Vector3 = member.route[member.route.size() - 1]
	var heading: float = member.facing
	var walking: bool = remaining > 0.0 and remaining < member.route_length
	for leg: int in range(member.route.size() - 1):
		var from: Vector3 = member.route[leg]
		var to: Vector3 = member.route[leg + 1]
		var length: float = from.distance_to(to)
		if remaining <= length:
			position = from.lerp(to, remaining / length) if length > 0.0 else to
			if walking:
				heading = _yaw_for((to - from) if outbound else (from - to))
			break
		remaining -= length
	if not walking:
		heading = member.facing if member.walked >= member.route_length else _yaw_for(Vector3(-1.0, 0.0, 0.0))
	position.y = 0.0
	member.node.position = position
	member.yaw = lerp_angle(member.yaw, heading, minf(1.0, delta * TURN_RATE)) if delta > 0.0 else heading
	member.node.rotation = Vector3(0.0, member.yaw, 0.0)
	if member.anim_player != null:
		if walking:
			if member.anim_player.current_animation != "walk":
				member.anim_player.play("walk")
				member.anim_player.speed_scale = 1.3
		else:
			if member.anim_player.current_animation != "idle":
				member.anim_player.play("idle")
				member.anim_player.speed_scale = 1.0


## True while someone still stands at his working spot: the crew steps back to its waiting spots before
## it walks to the garage.
func _stepping_out_of_work(crew: Crew) -> bool:
	for member: Member in crew.members:
		if member.work_blend > 0.0:
			return true
	return false


## A crew that is out turns to the car. While it waits it shifts its weight; once the car has stopped
## (a job runs) it steps in from its waiting spot to its working spot, and steps back when the car is gone.
func _wait_or_work(crew: Crew, delta: float, working: bool) -> void:
	var servicing: bool = false
	for job: Job in jobs:
		if job.team == crew.team:
			servicing = job.phase == Phase.SERVICING
	for member: Member in crew.members:
		member.work_blend = move_toward(member.work_blend, 1.0 if working else 0.0, delta * WORK_STEP_RATE)
		member.service_blend = move_toward(member.service_blend, 1.0 if servicing else 0.0, delta / ANIMATION_BLEND_S)
		var spot: Vector3 = member.ready.lerp(member.work, smoothstep(0.0, 1.0, member.work_blend))
		member.node.position.x = spot.x
		member.node.position.z = spot.z
		member.yaw = lerp_angle(member.yaw, member.facing, minf(1.0, delta * TURN_RATE))
		member.node.rotation.y = member.yaw
		if not working:
			member.node.rotation.x = 0.0
			member.node.position.y = 0.0
			_play_member(member, &"idle")


# --- sim-driven presentation -------------------------------------------------

## Sim-driven presentation (FASE 5.6): the GT sim runs the whole stop (it parks the car
## on the box, lifts it, swaps tyres on its stop timer), the crew only acts it out.
## `progress` is the sim's wheel_swap_progress 0..1, `lift_m` its jack height. Call every
## frame for a car in its box; call with in_service = false once it has left.
func present(car_id: int, team: int, actor: Node3D, compound: int, in_service: bool, progress: float, lift_m: float) -> void:
	var job: Job = get_job(car_id)
	if not in_service:
		if job != null:
			_close(job)
		return
	if job == null:
		job = _open_job(car_id, team, actor, compound)
	job.lift_m = lift_m
	if job.chassis != null:
		job.chassis.position.y = lift_m
	if progress < 0.09:
		job.phase = Phase.LIFTING
	elif progress < 0.86:
		job.phase = Phase.SERVICING
	elif progress < 0.94:
		job.phase = Phase.LOWERING
	else:
		job.phase = Phase.RELEASE
	if job.phase == Phase.SERVICING:
		_service_wheels_at(job, clampf((progress - 0.09) / 0.77, 0.0, 1.0))
	elif job.phase == Phase.RELEASE:
		_animate_lollipop(job, clampf((progress - 0.94) / 0.06, 0.0, 1.0))
	elif job.phase == Phase.LIFTING:
		_animate_lollipop(job, 1.0 - clampf(progress / 0.09, 0.0, 1.0))
	_animate_crew(job, progress)


func _open_job(car_id: int, team: int, actor: Node3D, compound: int) -> Job:
	var job := Job.new()
	job.car_id = car_id
	job.team = clampi(team, 0, _team_count() - 1)
	job.actor = actor
	job.chassis = actor.get("chassis") as ModularCarAssembler
	job.compound = clampi(compound, 0, wheel_scenes.size() - 1)
	job.wheel_scene = wheel_scenes[job.compound]
	jobs.append(job)
	var crew: Crew = _ensure_ready(job.team)
	job.crew = crew.root
	_assign_corners(job, crew)
	job.crew_members.resize(CORNER_COUNT)
	for member: Member in crew.members:
		if member.role == FigureScript.Role.GUNNER:
			job.crew_members[member.corner] = member.node
		elif member.role == FigureScript.Role.LOLLIPOP:
			job.lollipop = member.node
			job.lollipop_disc = member.disc
		elif member.role == FigureScript.Role.HANDLER:
			member.tyre.mesh = _tyre_mesh(job.compound)
			member.tyre.visible = true
	_spawn_jacks(job, crew)
	_animate_lollipop(job, 0.0)
	stop_started.emit(car_id)
	return job


## Gunners and handlers work at the wheel nearest to them: the car model's left and right sockets sit on
## whichever side its mesh put them, so the crew follows the real sockets, not the corner names.
func _assign_corners(job: Job, crew: Crew) -> void:
	if job.chassis == null:
		return
	var sockets: Array = [job.chassis.socket_wheel_fl, job.chassis.socket_wheel_fr, job.chassis.socket_wheel_rl, job.chassis.socket_wheel_rr]
	var wheels: Array[Vector3] = []
	for socket: Marker3D in sockets:
		var wheel: Vector3 = crew.root.to_local(socket.global_position)
		if wheel.length() > 8.0:
			return # the car is not at its box: keep the default corners
		wheels.append(wheel)
	for role: int in [FigureScript.Role.GUNNER, FigureScript.Role.HANDLER]:
		var taken: Array[Member] = []
		for corner: int in range(CORNER_COUNT):
			var best: Member = null
			var best_distance: float = INF
			for member: Member in crew.members:
				if member.role != role or taken.has(member):
					continue
				var distance: float = Vector2(member.work.x - wheels[corner].x, member.work.z - wheels[corner].z).length()
				if distance < best_distance:
					best = member
					best_distance = distance
			best.corner = corner
			taken.append(best)
			var side: float = signf(wheels[corner].x)
			best.work = Vector3(wheels[corner].x + side * (0.58 if role == FigureScript.Role.GUNNER else 1.12), 0.0,
				wheels[corner].z + (0.0 if role == FigureScript.Role.GUNNER else 0.72))
			best.facing = _yaw_for(Vector3(-side, 0.0, 0.0))


func _close(job: Job) -> void:
	if job.chassis != null:
		job.chassis.position.y = 0.0
	for jack: MeshInstance3D in job.jacks:
		jack.queue_free()
	for wheel: Node3D in job.carried:
		if wheel != null and is_instance_valid(wheel):
			wheel.queue_free()
	var crew: Crew = _crews.get(job.team) as Crew
	if crew != null:
		for member: Member in crew.members:
			member.node.rotation.x = 0.0
			member.node.position.y = 0.0
			member.service_blend = 0.0
			_play_member(member, &"idle")
			if member.role == FigureScript.Role.GUNNER:
				member.tool_prop.position = Vector3(0.0, 0.85, -0.30)
				member.tool_prop.rotation = Vector3(0.0, PI, 0.0)
			elif member.role == FigureScript.Role.JACK:
				member.arm_ik.active = false
				member.carry_pose.lean = 0.0
			elif member.pole != null:
				member.pole.rotation.x = 0.0
			if member.tyre != null:
				member.tyre.visible = false
	jobs.erase(job)
	finished_ids.append(job.car_id)
	job_finished.emit(job.car_id)


# --- wheel service ---------------------------------------------------------

func _service_wheels_at(job: Job, t: float) -> void:
	for corner: int in range(CORNER_COUNT):
		var offset: float = 0.04 * float(corner)
		if not job.wheels_off[corner] and t >= 0.12 + offset:
			job.wheels_off[corner] = true
			_fire_gun(job, corner, true)
			var old_wheel: Node3D = job.chassis.detach_wheel(corner as ModularCarAssembler.WheelCorner)
			if old_wheel != null:
				_carry_away(job, corner, old_wheel)
		if job.wheels_off[corner] and not job.wheels_on[corner] and t >= 0.58 + offset:
			job.wheels_on[corner] = true
			_fire_gun(job, corner, false)
			job.chassis.attach_wheel(corner as ModularCarAssembler.WheelCorner, job.wheel_scene, mini(job.compound, ModularCarAssembler.TireCompound.WET) as ModularCarAssembler.TireCompound)
			wheel_swapped.emit(job.car_id, corner, job.compound)
			if _all(job.wheels_on) and job.actor.has_method("wheels_swapped"):
				job.actor.call("wheels_swapped", job.compound)


## The pneumatic gun of the mechanic at `corner`, heard from his spot at the box.
func _fire_gun(job: Job, corner: int, removing: bool) -> void:
	gun_shots += 1
	pit_gun_fired.emit(job.car_id, corner, removing)
	if not is_inside_tree():
		return
	if _gun_players.is_empty():
		for voice: int in range(GUN_VOICES):
			var player := AudioStreamPlayer3D.new()
			player.name = "WheelGun%d" % voice
			player.bus = &"SFX"
			player.stream = PIT_GUN_STREAM
			player.max_distance = GUN_RANGE_M
			add_child(player)
			_gun_players.append(player)
	var gun: AudioStreamPlayer3D = _gun_players[_next_gun]
	_next_gun = (_next_gun + 1) % GUN_VOICES
	var member: Node3D = job.crew_members[corner] if corner < job.crew_members.size() else null
	if member != null:
		gun.global_position = member.global_position
	gun.pitch_scale = 0.94 if removing else 1.06
	gun.play()


func _all(flags: Array[bool]) -> bool:
	for flag: bool in flags:
		if not flag:
			return false
	return true


func _carry_away(job: Job, corner: int, wheel: Node3D) -> void:
	var crew: Crew = _crews.get(job.team) as Crew
	var member: Member = null
	if crew != null:
		for candidate: Member in crew.members:
			if candidate.role == FigureScript.Role.HANDLER and candidate.corner == corner:
				member = candidate
				break
	if member == null:
		wheel.queue_free()
		return
	var hold := member.node.get_node("Hands") as Node3D
	hold.add_child(wheel)
	wheel.transform = Transform3D.IDENTITY
	member.tyre.visible = false
	job.carried[corner] = wheel


# --- props and poses ---------------------------------------------------------

## Hydraulic jacks under the nose and the tail; they exist while the car is up.
func _spawn_jacks(job: Job, crew: Crew) -> void:
	var paint: ShaderMaterial = ToonMaterials.make(FigureScript.GUN_COLOR, true)
	for end: float in [-JACK_REACH_M, JACK_REACH_M]:
		var jack := MeshInstance3D.new()
		jack.name = "Jack"
		var piston := BoxMesh.new()
		piston.size = Vector3(0.16, 0.5, 0.16)
		jack.mesh = piston
		jack.material_override = paint
		crew.root.add_child(jack)
		jack.position = Vector3(0.0, 0.05, end)
		job.jacks.append(jack)
		if QuickJackScene != null:
			var qj: Node3D = QuickJackScene.instantiate() as Node3D
			qj.name = "QuickJackModel"
			qj.rotation.y = 0.0 if end < 0.0 else PI
			jack.add_child(qj)
			qj.position.y = -0.05
			jack.transparency = 1.0


## The board on a pole, lowered across the nose until the stop is done.
func _build_lollipop(member: Member) -> void:
	member.pole = Node3D.new()
	member.pole.name = "Pole"
	member.pole.position = Vector3(0.0, 1.0, -0.35)
	member.node.add_child(member.pole)
	if LollipopBoardScene != null:
		var lp: Node3D = LollipopBoardScene.instantiate() as Node3D
		lp.name = "LollipopModel"
		lp.position.y = -0.95
		member.pole.add_child(lp)
	else:
		ToonMaterials.box(member.pole, "Stick", Vector3(0.05, 1.7, 0.05), Vector3(0.0, 0.85, 0.0), ToonMaterials.make(Color("#d9d9df")))
	member.disc = MeshInstance3D.new()
	member.disc.name = "Disc"
	var disc := CylinderMesh.new()
	disc.top_radius = 0.32
	disc.bottom_radius = 0.32
	disc.height = 0.05
	disc.radial_segments = 14
	member.disc.mesh = disc
	member.disc.material_override = ToonMaterials.emissive(Color("#e0212e"), 1.5)
	member.disc.position = Vector3(0.0, 1.75, 0.0)
	member.disc.rotation.x = PI * 0.5
	if LollipopBoardScene != null:
		member.disc.transparency = 1.0
	member.pole.add_child(member.disc)
	member.pole.rotation.x = 0.0


## A fresh tyre of `compound` (-1: not known yet) as a handler holds it, axis across his body.
func _tyre_mesh(compound: int) -> ArrayMesh:
	if _tyre_meshes.has(compound):
		return _tyre_meshes[compound]
	var batch := MeshBatchScript.new()
	var material: ShaderMaterial = ToonMaterials.vertex_colored(false)
	var turned := Basis(Vector3.BACK, -PI * 0.5)
	batch.cylinder(material, Color("#17181c"), Transform3D(turned, turned * Vector3(0.0, -TYRE_WIDTH_M * 0.5, 0.0)), TYRE_RADIUS_M, TYRE_RADIUS_M, TYRE_WIDTH_M, 12)
	var rim: Color = COMPOUND_COLORS[compound] if compound >= 0 and compound < COMPOUND_COLORS.size() else NEUTRAL_RIM
	batch.cylinder(material, rim, Transform3D(turned, turned * Vector3(0.0, -TYRE_WIDTH_M * 0.5 - 0.01, 0.0)), TYRE_RADIUS_M * 0.62, TYRE_RADIUS_M * 0.62, TYRE_WIDTH_M + 0.02, 10)
	var mesh: ArrayMesh = batch.commit()
	_tyre_meshes[compound] = mesh
	return mesh


## Each role works its part of the stop; `t` is service progress 0..1.
func _animate_crew(job: Job, _t: float) -> void:
	var crew: Crew = _crews.get(job.team) as Crew
	if crew == null:
		return
	var servicing: bool = job.phase == Phase.SERVICING
	for member: Member in crew.members:
		member.node.rotation.x = 0.0
		member.node.position.y = 0.0
		if member.role == FigureScript.Role.GUNNER:
			_play_member(member, &"tire_service" if servicing else &"idle")
			if job.chassis != null:
				var socket: Marker3D = job.chassis._wheel_sockets[member.corner]
				var target: Vector3 = socket.global_position
				var forward: Vector3 = -member.node.global_basis.z
				var rest: Vector3 = member.node.to_global(Vector3(0.0, 0.85, -0.30))
				var grip: Vector3 = target - forward * 0.205 - Vector3.UP * 0.08
				member.tool_prop.global_position = rest.lerp(grip, member.service_blend)
				member.tool_prop.look_at(member.tool_prop.global_position + forward, Vector3.UP, true)
		elif member.role == FigureScript.Role.HANDLER:
			member.tyre.visible = not job.wheels_on[member.corner] and job.carried[member.corner] == null
		elif member.role == FigureScript.Role.FUELER:
			member.work = Vector3(1.6, 0.0, 0.8)
			member.facing = _yaw_for(Vector3.LEFT)
	for jack: MeshInstance3D in job.jacks:
		# The jack head follows the underside of the car: 25 cm up plus the lift.
		# The real low-profile lever pivots around its wheel axle, never scales the whole GLB.
		jack.rotation.x = -asin(clampf(job.lift_m / 0.32, 0.0, 0.8)) * (-1.0 if jack.position.z > 0.0 else 1.0)
	for member: Member in crew.members:
		if member.role != FigureScript.Role.JACK:
			continue
		var jacking: bool = job.phase == Phase.LIFTING or job.phase == Phase.LOWERING
		_play_member(member, &"tire_service" if jacking else &"idle")
		member.carry_pose.lean = 0.9 if jacking else 0.0
		member.arm_ik.active = jacking
		member.arm_ik.influence = clampf(1.0 - job.lift_m / 0.10, 0.0, 1.0)
		var jack: MeshInstance3D = job.jacks[0 if member.node.name == &"Jack0" else 1]
		for hand: int in range(member.grips.size()):
			member.grips[hand].global_position = jack.to_global(Vector3(0.14 if hand == 0 else -0.14, 0.58, -1.15 if jack.position.z < 0.0 else 1.15))


func _animate_lollipop(job: Job, amount: float) -> void:
	var pole := job.lollipop.get_node("Pole") as Node3D
	pole.rotation.x = lerpf(deg_to_rad(-80.0), 0.0, smoothstep(0.0, 1.0, amount))
	var release: float = amount if job.phase == Phase.RELEASE else 0.0
	var material: StandardMaterial3D = job.lollipop_disc.material_override as StandardMaterial3D
	material.albedo_color = Color("#26e07a") if release > 0.5 else Color("#e0212e")
	material.emission = material.albedo_color
	pole.get_node("LollipopModel").rotation.y = PI * smoothstep(0.0, 1.0, release)
