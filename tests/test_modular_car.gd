extends SceneTree

const ModularCarAssembler = preload("res://scripts/car/modular_car_assembler.gd")
const BaseChassisScene = preload("res://scenes/car/base_chassis.tscn")
const WHEEL_SOFT = preload("res://scenes/car/parts/porsche_wheel_soft.tscn")
const WHEEL_MEDIUM = preload("res://scenes/car/parts/porsche_wheel_medium.tscn")
const WHEEL_HARD = preload("res://scenes/car/parts/porsche_wheel_hard.tscn")
const WHEEL_WET = preload("res://scenes/car/parts/porsche_wheel_wet.tscn")

const WheelControllerScript = preload("res://scripts/car/wheel_controller.gd")

var failures: int = 0

func _initialize() -> void:
	call_deferred("_run")

func check(condition: bool, description: String) -> void:
	if not condition:
		failures += 1
		push_error("FAIL: " + description)
	print("[%s] %s" % ["PASS" if condition else "FAIL", description])

func _run() -> void:
	print("===============================================================")
	print(" RUNNING GT3 MASTER WHEEL & PIT STOP PIPELINE TESTS")
	print("===============================================================")
	
	var chassis: ModularCarAssembler = BaseChassisScene.instantiate()
	root.add_child(chassis)
	await process_frame
	
	# 1. Pastikan 4 socket roda universal dan cockpit tersedia
	check(chassis.socket_wheel_fl != null, "Socket_Wheel_FL must exist")
	check(chassis.socket_wheel_fr != null, "Socket_Wheel_FR must exist")
	check(chassis.socket_wheel_rl != null, "Socket_Wheel_RL must exist")
	check(chassis.socket_wheel_rr != null, "Socket_Wheel_RR must exist")
	check(chassis.socket_cockpit != null, "Socket_Cockpit must exist")
	
	# 2. Pasang 4 Roda Master GT3 Kompon Soft
	chassis.perform_pitstop_tire_change(WHEEL_SOFT, ModularCarAssembler.TireCompound.SOFT)
	check(chassis.socket_wheel_fl.get_child_count() == 1, "Wheel FL mounted")
	check(chassis.socket_wheel_fr.get_child_count() == 1, "Wheel FR mounted")
	check(chassis.socket_wheel_rl.get_child_count() == 1, "Wheel RL mounted")
	check(chassis.socket_wheel_rr.get_child_count() == 1, "Wheel RR mounted")
	check(chassis.get_current_tire_compound() == ModularCarAssembler.TireCompound.SOFT, "Initial compound is SOFT")
	
	# 3. Verifikasi WheelController script dan kemampuan rotasi (Zero-Wobble Rig)
	var fl_wheel = chassis.socket_wheel_fl.get_child(0)
	check(fl_wheel is WheelControllerScript, "Wheel FL has WheelController attached")
	if fl_wheel is WheelControllerScript:
		fl_wheel.set_rolling_speed(30.0) # 30 m/s ~ 108 km/h
		check(fl_wheel.angular_speed > 0.0, "Wheel angular speed set successfully for driving animation")
		fl_wheel.stop_rotation()
		check(fl_wheel.angular_speed == 0.0, "Wheel rotation stopped successfully")
		
	# 4. Simulasi Pit Stop: Kru melepas roda FL
	var detached = chassis.detach_wheel(ModularCarAssembler.WheelCorner.FRONT_LEFT)
	check(detached != null, "Wheel FL detached by pit crew")
	check(chassis.socket_wheel_fl.get_child_count() == 0, "Socket Wheel FL is empty during tire service")
	detached.queue_free()
	
	# 5. Pasang Roda Wet baru pada FL
	chassis.attach_wheel(ModularCarAssembler.WheelCorner.FRONT_LEFT, WHEEL_WET, ModularCarAssembler.TireCompound.WET)
	check(chassis.socket_wheel_fl.get_child_count() == 1, "New WET tire mounted to FL")
	
	# 6. Ganti ke Kompon Medium untuk 4 roda
	chassis.perform_pitstop_tire_change(WHEEL_MEDIUM, ModularCarAssembler.TireCompound.MEDIUM)
	check(chassis.get_current_tire_compound() == ModularCarAssembler.TireCompound.MEDIUM, "Full tire swap to MEDIUM completed")
	
	# 7. Ganti ke Kompon Hard untuk 4 roda
	chassis.perform_pitstop_tire_change(WHEEL_HARD, ModularCarAssembler.TireCompound.HARD)
	check(chassis.get_current_tire_compound() == ModularCarAssembler.TireCompound.HARD, "Full tire swap to HARD completed")
	
	print("---------------------------------------------------------------")
	if failures == 0:
		print("GT3 MASTER WHEELS & PIT STOP PIPELINE ACCEPTANCE: PASS")
		quit(0)
	else:
		print("FAILURES: %d" % failures)
		quit(1)
