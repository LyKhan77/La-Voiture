extends SceneTree

## Run: godot --headless --path . -s res://tests/test_podium_data.gd
const Roster := preload("res://scripts/ui/garage_roster.gd")
var failures: int = 0
var assertions: int = 0


func _initialize() -> void:
	call_deferred("_run")


func check(ok: bool, message: String) -> void:
	assertions += 1
	if not ok:
		failures += 1
		push_error(message)
	print("[%s] %s" % ["PASS" if ok else "FAIL", message])


func _run() -> void:
	var epithets: Array[String] = Roster.DRIVER_EPITHETS
	var every_filled: bool = true
	for epithet: String in epithets:
		every_filled = every_filled and epithet.strip_edges() != ""
	check(epithets.size() == GtData.DRIVER_NAMES.size() and epithets.size() == 26 and every_filled,
		"Every driver slot has an epithet")
	check(epithets[0] == "The High-Voltage Prodigy" and epithets[2] == "The Apex Drifter"
		and epithets[8] == "The Laser Meister" and epithets[25] == "The Touge Empress",
		"Epithets follow the roster order")
	check(Roster.RANK_KANJI == (["優勝", "準優勝", "第三位"] as Array[String]), "Rank kanji per place")
	check(Roster.RANK_SFX == (["ドォン!!", "ザッ!", "ゴゴゴ"] as Array[String]), "Rank SFX per place")
	check(Roster.epithet(8) == "The Laser Meister" and Roster.epithet(99) == "" and Roster.epithet(-1) == "",
		"epithet() answers empty outside the roster")
	check(Roster.podium_sprite_path(0) == "res://assets/cars/mercedes_amg/podium_sprite.png"
		and Roster.podium_sprite_path(12) == "res://assets/cars/toyota_supra/podium_sprite.png",
		"Sprite path follows the car slug")
	print("PODIUM DATA: %d assertions, %d FAIL" % [assertions, failures])
	quit(0 if failures == 0 else 1)
