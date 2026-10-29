class_name CircuitEnvironment
extends Node3D

## The contract every circuit's environment (kerbs, barriers, set dressing, sky, lighting) fulfils for
## RaceWeekendWorld, and what the three share. A circuit subclasses this (apex_ring, neo_wangan and brianza are the
## reference implementations) and overrides:
##   build()             builds the whole set against `ribbon`; `source` is whatever the circuit needs besides it
##                       (the adaptive racing line for Apex, the circuit builder for Brianza and Neo-Wangan); sets `built`
##   bind_world()        takes the world's sky, sun and camera; call once after build()
##   update()            per-frame upkeep: wind, DAY/SUNSET/NIGHT, jumbotron standings, anything that breathes
##   apply_time_of_day() sets the DAY / SUNSET / NIGHT mood now (`tod` is GtWeather's time-of-day dictionary)
##   apply_wind()        pushes the wind to whatever flutters (default: nothing)
##   ground_y_at()       top of the solid ground under a world point (default: the point itself, a flat circuit)
##   _extra_stats()      circuit-specific numbers added to stats()
## `furniture` (flag LED panels, trackside boards) may be null: a circuit without them simply has no panels.
## `tests/test_circuit_environment_contract.gd` holds every circuit to this.

const TrackRibbonScript := preload("res://scripts/car/track_ribbon.gd")
const FurnitureScript := preload("res://scripts/world/shared/trackside_furniture_builder.gd")
const _Liveries := preload("res://scripts/car/team_liveries.gd")

## How often the standings are repainted on the jumbotrons (s), and how much each place dims its bar.
const LEADERBOARD_PERIOD_S: float = 0.5
const LEADERBOARD_STEP: float = 0.08

## The circuit's id in CircuitCalendarRegistry; set by the subclass.
var circuit_id: String = ""
var ribbon: TrackRibbonScript
var furniture: FurnitureScript
var built: bool = false
## What a frame of this set submits (see measure()): draw calls, triangles and MultiMesh instances' surfaces.
var draw_calls: int = 0
var triangle_count: int = 0
var multimesh_count: int = 0

## Starts at 0: the first repaint comes LEADERBOARD_PERIOD_S after the set is built (Apex starts it full, to paint at once).
var _leaderboard_clock: float = 0.0


## Builds the whole set against `p_ribbon`. Override.
func build(_p_ribbon: TrackRibbonScript, _source: Variant = null) -> void:
	push_error("%s does not implement build()" % get_script().resource_path)


## The race world hands its own sky, sun and camera to the set. Override.
func bind_world(_world_environment: WorldEnvironment, _sun: DirectionalLight3D, _camera: Camera3D) -> void:
	pass


## Per-frame upkeep with the race's weather and standings. Override.
func update(_delta: float, _race) -> void:
	pass


## DAY / SUNSET / NIGHT now. `tod` is GtWeather.time_of_day: {mode, floodlights, stars_opacity, ...}. Override.
func apply_time_of_day(_tod: Dictionary, _gloom: float = 0.0) -> void:
	pass


## Wind speed (km/h) and direction (radians) for whatever flutters, ripples or drifts. Override.
func apply_wind(_delta: float, _wind_kph: float, _wind_dir: float) -> void:
	pass


## Top of the solid ground under a world point: what trees, piers and fences stand on. A flat circuit leaves it as is.
func ground_y_at(pos: Vector3) -> float:
	return pos.y


## How heavy the set is plus the circuit's own numbers. Always has circuit_id, built, draw_calls, triangles, multimeshes.
func stats() -> Dictionary:
	measure()
	var result: Dictionary = {
		"circuit_id": circuit_id, "built": built, "draw_calls": draw_calls, "triangles": triangle_count, "multimeshes": multimesh_count,
	}
	result.merge(_extra_stats())
	return result


func _extra_stats() -> Dictionary:
	return {}


## Counts what a frame would submit and how heavy it is. MultiMesh instances cost one draw call per
## surface and pay their triangles once per instance.
func measure() -> void:
	draw_calls = 0
	triangle_count = 0
	multimesh_count = 0
	_measure_node(self)


## Repaints the jumbotrons with the live order, leader first, a couple of times a second.
func _feed_leaderboards(delta: float, race, screens: Array) -> void:
	_leaderboard_clock += delta
	if race == null or screens.is_empty() or _leaderboard_clock < LEADERBOARD_PERIOD_S:
		return
	_leaderboard_clock = 0.0
	var colors: Array[Color] = []
	var values: Array[float] = []
	var order: Array = race.standings()
	for row: int in range(mini(order.size(), screens[0].ROWS)):
		colors.append(_Liveries.color_for(order[row].team_id))
		values.append(1.0 - LEADERBOARD_STEP * float(row))
	for screen in screens:
		screen.set_leaderboard(colors, values)


func _measure_node(node: Node) -> void:
	if node is Node3D and not (node as Node3D).visible:
		return
	if node is MultiMeshInstance3D:
		var instanced := node as MultiMeshInstance3D
		if instanced.multimesh != null and instanced.multimesh.mesh != null:
			multimesh_count += 1
			_measure_mesh(instanced.multimesh.mesh, instanced.multimesh.instance_count, instanced.material_override)
	elif node is MeshInstance3D:
		var mesh_instance := node as MeshInstance3D
		if mesh_instance.mesh != null:
			_measure_mesh(mesh_instance.mesh, 1, mesh_instance.material_override)
	for child: Node in node.get_children():
		_measure_node(child)


func _measure_mesh(mesh: Mesh, copies: int, override: Material) -> void:
	for surface: int in range(mesh.get_surface_count()):
		var material: Material = override if override != null else mesh.surface_get_material(surface)
		var passes: int = 1
		while material != null and material.next_pass != null:
			passes += 1
			material = material.next_pass
		var arrays: Array = mesh.surface_get_arrays(surface)
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] is PackedInt32Array else PackedInt32Array()
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var count: int = indices.size() / 3 if not indices.is_empty() else vertices.size() / 3
		draw_calls += passes
		triangle_count += count * copies * passes
