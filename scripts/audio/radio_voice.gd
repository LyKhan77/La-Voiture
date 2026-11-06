class_name RadioVoice
extends RefCounted

## Finds the recorded voice line for a team radio message (FASE 6). The clips are rendered by
## tools/audio/generate_radio_voices.mjs (Kokoro: bm_lewis for the engineer, one voice per driver
## from DRIVER_VOICES); manifest.json lists, per clip, the speaker, the Kokoro voice and a regex over
## the exact text the GT sim pushes. Numbers and car codes vary in that text, so the clip speaks the
## short form and the banner still shows the full line. A message with no clip stays text only.

const MANIFEST := "res://assets/audio/radio/voice/manifest.json"
const DEFAULT_DRIVER_VOICE := "am_eric"

## Kokoro voice per driver slot, in GtData.DRIVER_NAMES order. Teammates (slots 2t and 2t+1) never share a
## voice; the three women (Silva, Rossi, Takahashi, as in their portraits) take the af_/bf_ voices. Every voice
## here must be in DRIVER_VOICES of tools/audio/radio_lines.mjs (test_radio_and_podium #24b checks).
const DRIVER_VOICES: Array[String] = [
	"am_puck", "am_michael", # Ryu (prodigy), Ren (calculator)
	"am_eric", "bm_george", # Ito, Vale (Camden)
	"am_fenrir", "am_michael", # Cruz (matador), Sato (silent ronin)
	"am_eric", "bf_emma", # Moreau, Silva (storm)
	"am_michael", "bm_george", # Kade, Novak
	"am_fenrir", "am_puck", # Mori (brawler), Reyes (bull)
	"am_fenrir", "am_eric", # Sokol (frost), Aoki (kitsune)
	"am_eric", "am_puck", # Alves, Weiss
	"am_michael", "bm_george", # Tanaka, Duval (Riviera)
	"am_michael", "am_fenrir", # Petrov (ghost), Mbeki
	"am_eric", "af_heart", # Bellini, Rossi
	"am_fenrir", "am_puck", # Vance (brawler), Cooper (drifter)
	"am_michael", "af_bella", # Kazama (midnight ghost), Takahashi (touge empress)
]

static var _entries: Array[Dictionary] = [] # id, speaker, voice, regex, file
static var _loaded: bool = false


## The Kokoro voice a driver slot speaks with; the default for an unknown slot.
static func voice_of(car_id: int) -> String:
	return DRIVER_VOICES[car_id] if car_id >= 0 and car_id < DRIVER_VOICES.size() else DEFAULT_DRIVER_VOICE


static func is_female_driver(car_id: int) -> bool:
	var voice: String = voice_of(car_id)
	return voice.begins_with("af_") or voice.begins_with("bf_")


## {"id": String, "voice": String, "stream": AudioStream, "length": float}, or {} when nothing was recorded.
## A driver call plays in that driver's voice when one was recorded, else in the default driver voice.
static func find(speaker: String, text: String, car_id: int = -1) -> Dictionary:
	_load()
	var want: String = voice_of(car_id) if speaker == "driver" else ""
	var fallback: Dictionary = {}
	for entry: Dictionary in _entries:
		if String(entry["speaker"]) != speaker or (entry["regex"] as RegEx).search(text) == null:
			continue
		var voice: String = String(entry["voice"])
		if voice == want:
			return _clip(entry)
		if fallback.is_empty() and (voice == DEFAULT_DRIVER_VOICE or voice == ""):
			fallback = entry
	return _clip(fallback) if not fallback.is_empty() else {}


static func _clip(entry: Dictionary) -> Dictionary:
	var stream := load(String(entry["file"])) as AudioStream
	if stream == null:
		return {}
	return {"id": String(entry["id"]), "voice": String(entry["voice"]), "stream": stream, "length": stream.get_length()}


## The manifest rows as loaded: id, speaker, voice, regex and file of every clip.
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
		_entries.append({"id": String(row["id"]), "speaker": String(row["speaker"]), "voice": String(row.get("voice", "")), "regex": regex, "file": String(row["file"])})
