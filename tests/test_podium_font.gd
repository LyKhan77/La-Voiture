extends SceneTree

## Run: godot --headless --path . -s res://tests/test_podium_font.gd
## The podium panel draws Japanese rank kanji and katakana sound effects with a font that ships in the project,
## so a machine without a system CJK font never shows empty boxes.
const Roster := preload("res://scripts/ui/garage_roster.gd")
const FONT_PATH := "res://assets/fonts/DelaGothicOne-Podium.ttf"
const LICENCE_PATH := "res://assets/fonts/DelaGothicOne-OFL.txt"
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
	var font: FontFile = load(FONT_PATH) as FontFile if ResourceLoader.exists(FONT_PATH) else null
	check(font != null, "The podium font loads as a FontFile")
	var missing: Array[String] = []
	var wanted: String = "".join(Roster.RANK_KANJI) + "".join(Roster.RANK_SFX)
	for index: int in range(wanted.length()):
		if font == null or not font.has_char(wanted.unicode_at(index)):
			missing.append(wanted[index])
	check(font != null and missing.is_empty(), "It covers every rank kanji and SFX character (missing: %s)" % "".join(missing))
	var bytes: int = FileAccess.get_file_as_bytes(FONT_PATH).size() if FileAccess.file_exists(FONT_PATH) else 0
	check(bytes > 0 and bytes < 150 * 1024, "The subset stays small (%d bytes)" % bytes)
	check(FileAccess.file_exists(LICENCE_PATH), "The OFL licence ships next to it")
	print("PODIUM FONT: %d assertions, %d FAIL" % [assertions, failures])
	quit(0 if failures == 0 else 1)
