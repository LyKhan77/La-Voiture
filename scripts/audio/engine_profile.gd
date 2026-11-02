class_name EngineProfile
extends RefCounted

## The sound of one engine family (Fase 21.3): its on- and off-throttle loops, the RPM each loop
## was recorded at, and the family's own idle-to-redline range. The sim RPM is never changed:
## its 1200..8500 range is mapped onto the family's range, so a V10 screams higher than a V8 at
## the same sim RPM while the HUD and the deterministic race stay as they are.
## Loops: ElevenLabs Sound Effects via tools/audio/gen_engine_sfx.mjs (the three turbo loops
## trimmed to their steadiest stretch with tools/audio/trim_steady_loop.mjs).

const SIM_IDLE_RPM: float = 1200.0
const SIM_REDLINE_RPM: float = 8500.0
const PITCH_MIN: float = 0.5
const PITCH_MAX: float = 2.0

## Family -> [on loop, off loop, recorded rpm, idle rpm, redline rpm, turbo, on gain dB, off gain dB].
## Gains level every loop to about -10 dB RMS (on) and -12 dB RMS (off) as measured on the files.
const SPECS: Dictionary = {
	&"v8_na": [preload("res://assets/audio/engine/profiles/v8_na_on.wav"), preload("res://assets/audio/engine/profiles/v8_na_off.wav"), 5000.0, 1500.0, 7500.0, false, 0.0, -1.0],
	&"v10_na": [preload("res://assets/audio/engine/profiles/v10_na_on.wav"), preload("res://assets/audio/engine/profiles/v10_na_off.wav"), 6000.0, 1500.0, 8700.0, false, 0.0, -1.0],
	&"v6_tt": [preload("res://assets/audio/engine/profiles/v6_tt_on.wav"), preload("res://assets/audio/engine/profiles/v6_tt_off.wav"), 5500.0, 1500.0, 8000.0, true, -2.5, 1.0],
	&"i6_tt": [preload("res://assets/audio/engine/profiles/i6_tt_on.wav"), preload("res://assets/audio/engine/profiles/i6_tt_off.wav"), 5500.0, 1500.0, 7400.0, true, 0.0, 22.0],
	&"v8_tt": [preload("res://assets/audio/engine/profiles/v8_tt_on.wav"), preload("res://assets/audio/engine/profiles/v8_tt_off.wav"), 5500.0, 1500.0, 7800.0, true, -4.5, -7.5],
}
## Roster layout ("6.2L V8 NA" without its displacement) -> family.
const FAMILY_BY_LAYOUT: Dictionary = {
	"V8 NA": &"v8_na", "V10 NA": &"v10_na", "V6 TWIN-TURBO": &"v6_tt", "I6 TWIN-TURBO": &"i6_tt", "V8 TWIN-TURBO": &"v8_tt",
}
const DEFAULT_FAMILY: StringName = &"v8_na"

var id: StringName
var on_stream: AudioStreamWAV
var off_stream: AudioStreamWAV
var ref_rpm: float
var idle_rpm: float
var redline_rpm: float
var turbo: bool
var on_gain_db: float
var off_gain_db: float

static var _cache: Dictionary = {}


static func for_family(family: StringName) -> EngineProfile:
	if not SPECS.has(family):
		family = DEFAULT_FAMILY
	if not _cache.has(family):
		var spec: Array = SPECS[family]
		var profile := EngineProfile.new()
		profile.id = family
		profile.on_stream = EngineAudio3D.looped(spec[0])
		profile.off_stream = EngineAudio3D.looped(spec[1])
		profile.ref_rpm = spec[2]
		profile.idle_rpm = spec[3]
		profile.redline_rpm = spec[4]
		profile.turbo = spec[5]
		profile.on_gain_db = spec[6]
		profile.off_gain_db = spec[7]
		_cache[family] = profile
	return _cache[family]


## "5.2L V10 NA" -> &"v10_na"; &"" for a layout no family covers.
static func family_for_layout(layout: String) -> StringName:
	var parts: PackedStringArray = layout.split(" ", false, 1)
	return FAMILY_BY_LAYOUT.get(parts[1] if parts.size() == 2 else layout, &"")


## The family of the car a team rides (GarageRoster order); any other id (the safety car) wraps.
static func for_team(team_id: int) -> EngineProfile:
	return for_family(family_for_layout(GarageRoster.CAR_ENGINES[posmod(team_id, GarageRoster.CAR_ENGINES.size())]))


## Playback pitch of the loops for a sim RPM.
func pitch_for(sim_rpm: float) -> float:
	var normalized: float = clampf((sim_rpm - SIM_IDLE_RPM) / (SIM_REDLINE_RPM - SIM_IDLE_RPM), 0.0, 1.0)
	return clampf(lerpf(idle_rpm, redline_rpm, normalized) / ref_rpm, PITCH_MIN, PITCH_MAX)
