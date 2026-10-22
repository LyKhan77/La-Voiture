extends Node3D

const T = preload("res://scripts/ui/ui_theme_tokens.gd")
const UI = preload("res://scripts/ui/pit_wall_ui.gd")
const ModularCarAssembler = preload("res://scripts/car/modular_car_assembler.gd")

const WHEEL_SOFT = preload("res://scenes/car/parts/porsche_wheel_soft.tscn")
const WHEEL_MEDIUM = preload("res://scenes/car/parts/porsche_wheel_medium.tscn")
const WHEEL_HARD = preload("res://scenes/car/parts/porsche_wheel_hard.tscn")
const WHEEL_WET = preload("res://scenes/car/parts/porsche_wheel_wet.tscn")

@onready var chassis: ModularCarAssembler = $BaseChassis
@onready var camera_pivot: Node3D = $CameraPivot
@onready var smoke_fl: GPUParticles3D = $SmokeRL
@onready var smoke_fr: GPUParticles3D = $SmokeRR

@onready var label_car_title: Label = $UI/Panel/VBox/Title
@onready var label_downforce: Label = $UI/Panel/VBox/DownforceLabel
@onready var label_drag: Label = $UI/Panel/VBox/DragLabel
@onready var label_weight: Label = $UI/Panel/VBox/WeightLabel
@onready var label_parts_status: Label = $UI/Panel/VBox/PartsStatus

var _curr_compound: ModularCarAssembler.TireCompound = ModularCarAssembler.TireCompound.SOFT
var _auto_rotate: bool = true
var _burnout_active: bool = false
var _wheels_detached: bool = false

func _ready() -> void:
	chassis.perform_pitstop_tire_change(WHEEL_SOFT, ModularCarAssembler.TireCompound.SOFT)
	chassis.stats_recalculated.connect(_on_stats_updated)
	_update_ui_labels()

func _process(delta: float) -> void:
	if _auto_rotate:
		camera_pivot.rotation.y += delta * 0.45

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.is_pressed() and not event.is_echo():
		match event.keycode:
			KEY_1:
				set_compound(ModularCarAssembler.TireCompound.SOFT)
			KEY_2:
				set_compound(ModularCarAssembler.TireCompound.MEDIUM)
			KEY_3:
				set_compound(ModularCarAssembler.TireCompound.HARD)
			KEY_4:
				set_compound(ModularCarAssembler.TireCompound.WET)
			KEY_5:
				toggle_pitstop_wheel_detach()
			KEY_SPACE:
				toggle_burnout()
			KEY_R:
				_auto_rotate = not _auto_rotate

func set_compound(compound: ModularCarAssembler.TireCompound) -> void:
	_wheels_detached = false
	_curr_compound = compound
	var wheel_scene: PackedScene = WHEEL_SOFT
	match compound:
		ModularCarAssembler.TireCompound.SOFT:
			wheel_scene = WHEEL_SOFT
		ModularCarAssembler.TireCompound.MEDIUM:
			wheel_scene = WHEEL_MEDIUM
		ModularCarAssembler.TireCompound.HARD:
			wheel_scene = WHEEL_HARD
		ModularCarAssembler.TireCompound.WET:
			wheel_scene = WHEEL_WET
			
	chassis.perform_pitstop_tire_change(wheel_scene, compound)
	_update_ui_labels()

## Cycle ke kompon berikutnya
func cycle_tire_compound() -> void:
	var next_idx = (_curr_compound + 1) % 4
	set_compound(next_idx as ModularCarAssembler.TireCompound)

## Simulasi kru pit stop melepas/memasang kembali 4 roda
func toggle_pitstop_wheel_detach() -> void:
	_wheels_detached = not _wheels_detached
	if _wheels_detached:
		for c in range(4):
			chassis.detach_wheel(c as ModularCarAssembler.WheelCorner)
	else:
		set_compound(_curr_compound)
	_update_ui_labels()

func toggle_burnout() -> void:
	_burnout_active = not _burnout_active
	smoke_fl.emitting = _burnout_active
	smoke_fr.emitting = _burnout_active
	
	# Putar roda saat burnout
	for sock in [chassis.socket_wheel_fl, chassis.socket_wheel_fr, chassis.socket_wheel_rl, chassis.socket_wheel_rr]:
		if sock and sock.get_child_count() > 0:
			var wheel = sock.get_child(0)
			if wheel.has_method("set_rolling_speed"):
				wheel.set_rolling_speed(40.0 if _burnout_active else 0.0)

func _on_stats_updated(downforce: float, drag: float, weight_delta: float) -> void:
	label_downforce.text = "AERO DOWNFORCE : GT3 WORKS SPEC"
	label_drag.text = "CD DRAG PROFILE : 0.38 Cd"
	label_weight.text = "TOTAL CURB MASS : 1260.0 KG"

func _update_ui_labels() -> void:
	var comp_name = ModularCarAssembler.TireCompound.keys()[_curr_compound]
	var tire_text = "STATUS: PIT CREW WHEEL REMOVAL IN PROGRESS" if _wheels_detached else "COMPOUND: %s (GT3 DRY/WET SPEC)" % comp_name
	label_parts_status.text = "[ %s ]" % tire_text
	
	match _curr_compound:
		ModularCarAssembler.TireCompound.SOFT:
			label_downforce.text = "GRIP LEVEL: 100% MAXIMUM | PEAK QUALI"
			label_drag.text = "WEAR RATE : 1.45x HIGH THERMAL DEG"
		ModularCarAssembler.TireCompound.MEDIUM:
			label_downforce.text = "GRIP LEVEL: 94% OPTIMAL | RACE STINT"
			label_drag.text = "WEAR RATE : 1.00x BALANCED RACE PACE"
		ModularCarAssembler.TireCompound.HARD:
			label_downforce.text = "GRIP LEVEL: 87% DURABLE | LONG STINT"
			label_drag.text = "WEAR RATE : 0.65x LOW DEG PROTECTED"
		ModularCarAssembler.TireCompound.WET:
			label_downforce.text = "GRIP LEVEL: 100% WET DISPLACEMENT | HYDRO"
			label_drag.text = "RAIN GROOVE: TREAD DISPERSION ACTIVE"
