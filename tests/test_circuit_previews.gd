extends SceneTree

const Registry := preload("res://scripts/core/circuit_calendar_registry.gd")
const Config := preload("res://scripts/core/race_config_data.gd")
const MenuScene := preload("res://scenes/ui/race_setup_menu.tscn")
const MapView := preload("res://scripts/ui/track_map.gd")

var failures: int = 0
var scene_entries: int = 0

func _initialize() -> void:
	call_deferred("_run")

func check(ok: bool, description: String) -> void:
	if not ok:
		failures += 1
	print("[%s] %s" % ["PASS" if ok else "FAIL", description])

func _run() -> void:
	Config.reset()
	var menu: Control = MenuScene.instantiate()
	root.add_child(menu)
	await process_frame
	var radar: Control = menu.get("radar")
	radar.child_entered_tree.connect(func(_child: Node) -> void: scene_entries += 1)
	var textures: Dictionary = {}
	for circuit in Registry.get_all_circuits():
		var path: String = circuit.preview_image_path
		var imported: bool = path.begins_with("res://assets/ui/circuit_posters/") and ResourceLoader.exists(path)
		check(imported, "%s has an imported runtime poster" % circuit.circuit_id)
		check(bool(menu.call("select_circuit", circuit.circuit_id)), "%s can be selected" % circuit.circuit_id)
		var art: TextureRect = menu.get("venue_art")
		var texture: Texture2D = art.texture
		check(texture != null and texture.get_size() == Vector2(640, 360), "%s poster uses bounded 640x360 texture" % circuit.circuit_id)
		if texture != null:
			textures[circuit.circuit_id] = texture
			check(texture.resource_path == path, "%s uses imported texture rather than runtime image decode" % circuit.circuit_id)
		var stats: Dictionary = radar.call("stats")
		check((float(stats["length_m"]) > 100.0) == circuit.is_playable(), "%s preserves layout availability" % circuit.circuit_id)
		check((menu.get("continue_button") as Button).disabled == not circuit.is_playable(), "%s preserves garage availability" % circuit.circuit_id)
	check(scene_entries == 0, "first selections never instantiate circuit scenes (%d entries)" % scene_entries)
	check(textures.size() == Registry.TABLE.size(), "all ten rounds have posters")
	for circuit in Registry.get_all_circuits():
		menu.call("select_circuit", circuit.circuit_id)
		check((menu.get("venue_art") as TextureRect).texture == textures.get(circuit.circuit_id), "%s reuses prepared texture" % circuit.circuit_id)
	var selected: String = menu.get("config").selected_circuit_id
	check(not bool(menu.call("select_circuit", "unknown_circuit")) and menu.get("config").selected_circuit_id == selected, "invalid selection preserves current circuit")
	# A caller supplying no art must keep the existing fallback, without disk IO.
	var missing := Registry.get_circuit("apex_ring").duplicate()
	missing.preview_image_path = "res://assets/ui/circuit_posters/missing.png"
	menu.call("_show_venue", missing)
	check((menu.get("venue_art") as TextureRect).texture == null and (menu.get("venue_art_fallback") as Label).visible, "missing art shows fallback without stale poster")
	# Source edits must fail regression until the offline preview is rebaked.
	for circuit in Registry.get_all_circuits():
		radar.set("scene_path", circuit.scene_path)
		var live: Dictionary = radar.call("bake_track")
		var baked: Dictionary = MapView.MAP_DATA.get_meta("circuits", {}).get(circuit.scene_path, {})
		check(live == baked, "%s baked map matches current circuit source" % circuit.circuit_id)
	menu.queue_free()
	await process_frame
	await process_frame
	quit(0 if failures == 0 else 1)
