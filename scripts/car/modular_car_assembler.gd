class_name ModularCarAssembler extends Node3D

enum PartCategory {
	FRONT_SPLITTER,
	REAR_WING,
	REAR_DIFFUSER,
	WHEELS,
	COCKPIT,
	HOOD_LOUVERS
}

enum WheelCorner {
	FRONT_LEFT = 0,
	FRONT_RIGHT = 1,
	REAR_LEFT = 2,
	REAR_RIGHT = 3
}

enum TireCompound {
	SOFT = 0,
	MEDIUM = 1,
	HARD = 2,
	WET = 3
}

signal part_equipped(category: int, tier: int, part_name: String)
signal wheel_detached(corner: int)
signal wheel_attached(corner: int, compound: int)
signal pitstop_tires_changed(new_compound: int)
signal stats_recalculated(total_downforce: float, total_drag: float, weight_delta_kg: float)

@export var car_name: String = "Porsche 911 GT3 R"
@export var team_name: String = "Apex Racing"
@export var base_body_mesh: MeshInstance3D
## True when the body texture is the car's real livery (e.g. the Meshy Audi): the game then draws it as is,
## instead of tinting it with the team colour like the placeholder Porsche paint.
@export var keeps_original_paint: bool = false

# Referensi Socket Marker3D (Null-Safe)
@onready var socket_splitter: Marker3D = get_node_or_null("Sockets/Socket_FrontSplitter")
@onready var socket_wing: Marker3D = get_node_or_null("Sockets/Socket_RearWing")
@onready var socket_diffuser: Marker3D = get_node_or_null("Sockets/Socket_RearDiffuser")
@onready var socket_wheel_fl: Marker3D = get_node_or_null("Sockets/Socket_Wheel_FL")
@onready var socket_wheel_fr: Marker3D = get_node_or_null("Sockets/Socket_Wheel_FR")
@onready var socket_wheel_rl: Marker3D = get_node_or_null("Sockets/Socket_Wheel_RL")
@onready var socket_wheel_rr: Marker3D = get_node_or_null("Sockets/Socket_Wheel_RR")
@onready var socket_cockpit: Marker3D = get_node_or_null("Sockets/Socket_Cockpit")

# Track part yang terpasang
var _equipped_parts: Dictionary = {}
var _socket_map: Dictionary = {}
var _wheel_sockets: Array[Marker3D] = []
var _current_compound: TireCompound = TireCompound.SOFT

var total_downforce_mult: float = 1.0
var total_drag_mult: float = 1.0
var total_weight_delta_kg: float = 0.0

func _ready() -> void:
	_init_socket_map()

func _init_socket_map() -> void:
	if socket_splitter: _socket_map[PartCategory.FRONT_SPLITTER] = socket_splitter
	if socket_wing: _socket_map[PartCategory.REAR_WING] = socket_wing
	if socket_diffuser: _socket_map[PartCategory.REAR_DIFFUSER] = socket_diffuser
	if socket_cockpit: _socket_map[PartCategory.COCKPIT] = socket_cockpit
	_wheel_sockets = []
	for sock in [socket_wheel_fl, socket_wheel_fr, socket_wheel_rl, socket_wheel_rr]:
		if sock:
			_wheel_sockets.append(sock)

## Memasang part modular ke socket dengan jaminan zero-overlap
func equip_part(category: PartCategory, tier: int, part_scene: PackedScene, part_label: String = "") -> Node3D:
	if not _socket_map.has(category):
		push_warning("Socket category %d tidak terdaftar!" % category)
		return null
		
	var target_socket: Marker3D = _socket_map[category]
	
	# Bersihkan part lama pada socket ini (mencegah duplikasi / z-fighting)
	for child in target_socket.get_children():
		child.queue_free()
		
	var new_instance = part_scene.instantiate()
	target_socket.add_child(new_instance)
	new_instance.transform = Transform3D.IDENTITY
	
	_equipped_parts[category] = {
		"tier": tier,
		"instance": new_instance,
		"name": part_label if not part_label.is_empty() else "Tier %d" % tier
	}
	
	_recalculate_stats()
	part_equipped.emit(category, tier, _equipped_parts[category]["name"])
	return new_instance

# ==============================================================================
# SISTEM PIT STOP: PERGANTIAN BAN & MODULARITAS 4 SUDUT RODA
# ==============================================================================

## Melepas roda pada sudut tertentu (berguna untuk animasi kru pit stop mencopot roda)
func detach_wheel(corner: WheelCorner) -> Node3D:
	if corner < 0 or corner >= _wheel_sockets.size():
		return null
	var sock: Marker3D = _wheel_sockets[corner]
	if sock.get_child_count() > 0:
		var removed_wheel = sock.get_child(0)
		sock.remove_child(removed_wheel)
		wheel_detached.emit(corner)
		return removed_wheel
	return null

## Memasang roda individu pada sudut tertentu dengan scene kompon spesifik
func attach_wheel(corner: WheelCorner, wheel_scene: PackedScene, compound: TireCompound = TireCompound.SOFT) -> Node3D:
	if corner < 0 or corner >= _wheel_sockets.size():
		return null
	var sock: Marker3D = _wheel_sockets[corner]
	for child in sock.get_children():
		child.queue_free()
		
	var wheel_inst = wheel_scene.instantiate()
	sock.add_child(wheel_inst)
	wheel_inst.transform = Transform3D.IDENTITY
	
	# Balik rotasi sisi kiri (FL, RL) 180 derajat agar muka luar velg (+X) menghadap keluar (-X mobil)
	if corner == WheelCorner.FRONT_LEFT or corner == WheelCorner.REAR_LEFT:
		wheel_inst.rotation.y = PI
		
	wheel_attached.emit(corner, compound)
	return wheel_inst

## Pergantian 4 Roda Sekaligus saat Pit Stop (BOX Routine)
func perform_pitstop_tire_change(wheel_scene: PackedScene, new_compound: TireCompound) -> void:
	_current_compound = new_compound
	for c in range(4):
		attach_wheel(c as WheelCorner, wheel_scene, new_compound)
	
	_equipped_parts[PartCategory.WHEELS] = {
		"tier": 1,
		"compound": new_compound,
		"name": "Compound %s" % TireCompound.keys()[new_compound]
	}
	_recalculate_stats()
	pitstop_tires_changed.emit(new_compound)

func get_current_tire_compound() -> TireCompound:
	return _current_compound

func get_equipped_tier(category: PartCategory) -> int:
	if _equipped_parts.has(category):
		return _equipped_parts[category]["tier"]
	return 0

func _recalculate_stats() -> void:
	total_downforce_mult = 1.0
	total_drag_mult = 1.0
	total_weight_delta_kg = 0.0
	
	var wing_tier: int = get_equipped_tier(PartCategory.REAR_WING)
	var splitter_tier: int = get_equipped_tier(PartCategory.FRONT_SPLITTER)
	var diffuser_tier: int = get_equipped_tier(PartCategory.REAR_DIFFUSER)
	
	total_downforce_mult += (wing_tier * 0.12) + (splitter_tier * 0.08) + (diffuser_tier * 0.05)
	total_drag_mult += (wing_tier * 0.05) - (splitter_tier * 0.02) - (diffuser_tier * 0.03)
	total_weight_delta_kg -= (wing_tier + splitter_tier + diffuser_tier) * 4.5
	
	stats_recalculated.emit(total_downforce_mult, total_drag_mult, total_weight_delta_kg)
