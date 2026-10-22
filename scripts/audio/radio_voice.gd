class_name RadioVoice
extends RefCounted

## Finds the recorded voice line for a team radio message (FASE 6). The clips are rendered by
## tools/audio/generate_radio_voices.mjs (Kokoro: bm_lewis for the engineer, am_eric for the
## driver); manifest.json lists, per clip, the speaker and a regex over the exact text the GT
## sim pushes. Numbers and car codes vary in that text, so the clip speaks the short form and
## the banner still shows the full line. A message with no clip stays text only.

const MANIFEST := "res://assets/audio/radio/voice/manifest.json"

static var _entries: Array[Dictionary] = [] # id, speaker, regex, file
static var _loaded: bool = false


## {"id": String, "stream": AudioStream, "length": float}, or {} when nothing was recorded.
static func find(speaker: String, text: String) -> Dictionary:
	_load()
	for entry: Dictionary in _entries:
		if String(entry["speaker"]) != speaker or (entry["regex"] as RegEx).search(text) == null:
			continue
		var stream := load(String(entry["file"])) as AudioStream
		if stream == null:
			return {}
		return {"id": String(entry["id"]), "stream": stream, "length": stream.get_length()}
	return {}


## The manifest rows as loaded: id, speaker, regex and file of every clip.
static func entries() -> Array[Dictionary]:
	_load()
	return _entries


static func _load() -> void:
	if _loaded:
		return
	_loaded = true
	var manifest := load(MANIFEST) as JSON
	if manifest == null or not manifest.data is Array:
		push_warning("RadioVoice: no manifest at %s, radio calls stay text only" % MANIFEST)
		return
	for row: Variant in manifest.data:
		var regex := RegEx.create_from_string(String(row["pattern"]))
		if regex == null or not regex.is_valid():
			push_warning("RadioVoice: bad pattern for %s" % String(row["id"]))
			continue
		_entries.append({"id": String(row["id"]), "speaker": String(row["speaker"]), "regex": regex, "file": String(row["file"])})
