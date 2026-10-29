extends SceneTree

## The rotor glow overlay (a StandardMaterial3D with add blending) used to be created and first drawn on a car's first
## braking, 9-13 ms in one frame a few seconds after the start of every race. Every wheel now builds it on the grid at
## an invisible strength, and a cold rotor goes back to carrying no overlay (it costs nothing then).
## Run: godot --headless --path . -s res://tests/test_wheel_glow_warmup.gd

const WorldScene := preload("res://scenes/race_weekend_world.tscn")
const Config := preload("res://scripts/core/race_config_data.gd")

var failures: int = 0


func check(ok: bool, description: String) -> void:
	print("[%s] %s" % ["PASS" if ok else "FAIL", description])
	if not ok:
		failures += 1


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var config = Config.get_config()
	config.selected_circuit_id = "apex_ring"
	config.race_seed = 19220903
	var world = WorldScene.instantiate()
	root.add_child(world)
	for _i: int in range(3):
		await process_frame
	var built: bool = true
	var carrying: bool = false
	for actor in world.actors:
		for wheel in actor.wheel_controllers:
			built = built and wheel._glow_material != null
			carrying = carrying or (wheel.brake_disc != null and wheel.brake_disc.material_overlay != null)
	check(built, "every wheel has built its glow material on the grid")
	check(carrying, "a warming rotor carries the overlay at an invisible strength")
	var visible_glow: float = 0.0
	for actor in world.actors:
		for wheel in actor.wheel_controllers:
			if wheel._glow_material != null:
				visible_glow = maxf(visible_glow, (wheel._glow_material as StandardMaterial3D).albedo_color.a)
	check(visible_glow <= 0.05, "the warm-up glow is too faint to see (alpha %.2f)" % visible_glow)
	for _i: int in range(30):
		await process_frame
	var cold: bool = true
	for actor in world.actors:
		for wheel in actor.wheel_controllers:
			cold = cold and (wheel.brake_disc == null or wheel.brake_disc.material_overlay == null)
	check(cold, "cold rotors carry no overlay again once the warm-up is over")
	world.queue_free()
	await process_frame
	quit(1 if failures else 0)
