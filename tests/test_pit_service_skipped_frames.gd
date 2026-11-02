extends SceneTree

## A fast presentation frame can jump from wheels-off straight to departure, even on the same compound.
const World := preload("res://scenes/race_weekend_world.tscn")
const Config := preload("res://scripts/core/race_config_data.gd")
var failures: int = 0

func _initialize() -> void:
	_run.call_deferred()

func check(ok: bool, label: String) -> void:
	print("[%s] %s" % ["PASS" if ok else "FAIL", label])
	if not ok:
		failures += 1

func _run() -> void:
	for circuit: String in ["apex_ring", "stoke_crown"]:
		Config.get_config().selected_circuit_id = circuit
		var world := World.instantiate()
		root.add_child(world)
		world.process_mode = Node.PROCESS_MODE_DISABLED
		await process_frame
		var actor = world.actors[0]
		var original: Array = actor.wheel_controllers.duplicate()
		world.choreographer.present(actor.car.id, actor.car.team_id, actor, actor.car.compound, true, 0.35, 0.15)
		world.choreographer.present(actor.car.id, actor.car.team_id, actor, actor.car.compound, false, 1.0, 0.0)
		await process_frame
		var fitted: bool = actor.wheel_controllers.size() == 4
		for wheel in actor.wheel_controllers:
			fitted = fitted and is_instance_valid(wheel) and not wheel.is_queued_for_deletion() and not original.has(wheel)
		check(fitted, "%s: skipped service frames still fit four fresh same-compound wheels before freeing carried wheels" % circuit)
		check(world.choreographer.jobs.is_empty(), "%s: completed service closes its job" % circuit)
		if fitted:
			actor.present(1.0, 1.0 / 60.0)
		var before: Array = actor.wheel_controllers.duplicate()
		var guns: int = world.choreographer.gun_shots
		world.choreographer.present(actor.car.id, actor.car.team_id, actor, actor.car.compound, true, 0.0, 0.0, true, true)
		world.choreographer.present(actor.car.id, actor.car.team_id, actor, actor.car.compound, false, 1.0, 0.0)
		await process_frame
		check(actor.wheel_controllers == before and world.choreographer.gun_shots == guns, "%s: hands-off penalty closes without swapping wheels or firing guns" % circuit)
		world.free()
		await process_frame
	quit(1 if failures else 0)
