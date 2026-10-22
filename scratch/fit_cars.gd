extends SceneTree
# Wheel-fit gate for every GT3 chassis. Replaces the clearance metric of diagnose_wheels.gd, which compared the lowest lip vertex inside a
# +-0.15 m window with the tyre top and so read +0.011 for any concentric 0.372 m arch (the real radial gap is 0.042 m).
#   godot --headless --path . -s scratch/fit_cars.gd                         measure and gate all cars, exit 1 on a failure
#   godot --headless --path . -s scratch/fit_cars.gd -- <car> ...            only these cars (the others are skipped)
#   godot --headless --path . -s scratch/fit_cars.gd -- --apply <car> ...    also rewrite that car's four Socket_Wheel_* x to the proposal
# The measurements live in tests/wheel_fit_checks.gd, shared with the chassis tests: radial gap (tub included), vertices inside the tyre,
# tyre outer face versus the widest fender point of the same axle, fender skin above the tyre (a missing skin reads -1), lowest body point.
const WheelFit := preload("res://tests/wheel_fit_checks.gd")
const CARS = {
	"porsche_911": "base_chassis", "audi_r8": "audi_r8_chassis", "nissan_gtr": "nissan_gtr_chassis", "aston_vantage": "aston_vantage_chassis",
	"bmw_m4": "bmw_m4_chassis", "lambo_huracan": "lambo_huracan_chassis", "honda_nsx": "honda_nsx_chassis", "chevy_corvette": "chevy_corvette_chassis",
	"lexus_rcf": "lexus_rcf_chassis", "mclaren_720s": "mclaren_720s_chassis",
}
# Hand-made by older pipelines (refine_body.py, refine_audi_r8.py): measured and printed, never counted as a failure.
const REFERENCE = ["porsche_911", "audi_r8"]
const APPLY_MIN := 0.0025
const WheelScene := preload("res://scenes/car/parts/porsche_wheel_soft.tscn")

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var apply: bool = "--apply" in args
	var only: PackedStringArray = PackedStringArray(Array(args).filter(func(a: String) -> bool: return CARS.has(a)))
	var failures: int = 0
	for car: String in CARS:
		if not only.is_empty() and car not in only:
			continue
		var path: String = "res://scenes/car/%s.tscn" % CARS[car]
		var chassis: ModularCarAssembler = (load(path) as PackedScene).instantiate()
		root.add_child(chassis)
		await process_frame
		chassis.perform_pitstop_tire_change(WheelScene, ModularCarAssembler.TireCompound.SOFT)
		await process_frame
		var counts: bool = car not in REFERENCE
		var floor_y: float = WheelFit.floor_y(chassis)
		var line: String = "%-15s floor y %+.3f %s" % [car, floor_y, "ok" if floor_y >= WheelFit.FLOOR_MIN else "FAIL"]
		failures += int(floor_y < WheelFit.FLOOR_MIN and counts)
		var axle_x: Dictionary = {"F": [], "R": []}
		for corner: String in ["FL", "FR", "RL", "RR"]:
			var sock: Marker3D = chassis.get("socket_wheel_%s" % corner.to_lower())
			var fit: Dictionary = WheelFit.radial_gap(chassis, sock)
			var gap: float = fit["gap"]
			var pen: int = fit["pen"]
			var flush: float = WheelFit.flush_delta(chassis, sock)
			var skin: float = WheelFit.fender_skin_min(chassis, sock)
			var bad: bool = gap < WheelFit.GAP_MIN or gap > WheelFit.GAP_MAX or pen > 0 or absf(flush) > WheelFit.FLUSH_TOL or skin < WheelFit.SKIN_MIN
			failures += int(bad and counts)
			axle_x["F" if corner.begins_with("F") else "R"].append(absf(sock.position.x) - flush)
			line += "\n   %s gap %+.3f  pen %d  flush %+.3f  skin %+.3f  (sock x %.3f) %s" % [corner, gap, pen, flush, skin, absf(sock.position.x), "FAIL" if bad else "ok"]
		var want_f: float = snappedf((axle_x["F"][0] + axle_x["F"][1]) * 0.5, 0.001)
		var want_r: float = snappedf((axle_x["R"][0] + axle_x["R"][1]) * 0.5, 0.001)
		line += "\n   proposed socket x: front %.3f  rear %.3f" % [want_f, want_r]
		print(line)
		if apply and car in args:
			_rewrite_sockets(path, chassis, want_f, want_r)
		chassis.queue_free()
		await process_frame
	print("FIT GATE: %s" % ("PASS" if failures == 0 else "%d FAILURES" % failures))
	quit(0 if failures == 0 else 1)

func _rewrite_sockets(path: String, chassis: ModularCarAssembler, x_front: float, x_rear: float) -> void:
	var text: String = FileAccess.get_file_as_string(path)
	var changed: int = 0
	for corner: String in ["FL", "FR", "RL", "RR"]:
		var sock: Marker3D = chassis.get("socket_wheel_%s" % corner.to_lower())
		var old_x: float = sock.position.x
		var new_x: float = signf(old_x) * (x_front if corner.begins_with("F") else x_rear)
		if absf(new_x - old_x) < APPLY_MIN:
			continue
		var key: String = "Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, "
		var head: int = text.find('Socket_Wheel_%s"' % corner)
		var k: int = text.find(key, head)
		if head < 0 or k < 0:
			push_error("%s: cannot place the %s socket transform exactly" % [path, corner])
			continue
		var a: int = k + key.length()
		text = text.substr(0, a) + String.num(new_x, 3) + text.substr(text.find(",", a))
		changed += 1
	if changed > 0:
		var f := FileAccess.open(path, FileAccess.WRITE)
		f.store_string(text)
		f.close()
	print("   applied: %d socket(s) rewritten in %s" % [changed, path])
