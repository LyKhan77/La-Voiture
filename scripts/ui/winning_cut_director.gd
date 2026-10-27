class_name WinningCutDirector
extends RefCounted

## Timeline of the winning scene: driver spray walls alternate with hero-car shots, then the final
## composition. Pure state (no nodes, no tweens) so it can be driven by tick() and tested headless;
## the scene listens to cut_changed and does the camera, HUD and impact frame.

signal cut_changed(cut: int)

enum Cut { P3_TAG, HERO, P2_TAG, DETAIL, FINAL }

## Beat-synced timing: The victory rock anthem is 150.0 BPM (1 beat = 0.40s).
## Each introductory cut lasts exactly 1 bar (4 beats = 1.60s), so the 5th (final) cut
## hits precisely on downbeat of Bar 5 (6.40s) where the full theme drops.
const BPM: float = 150.0
const BEATS_PER_BAR: int = 4
const CUT_SECONDS: float = (60.0 / BPM) * float(BEATS_PER_BAR) # 1.60 s
const NAMES: Dictionary = {
	Cut.P3_TAG: "P3 TAG", Cut.HERO: "HERO MACHINE", Cut.P2_TAG: "P2 TAG", Cut.DETAIL: "DETAIL", Cut.FINAL: "FINAL",
}

var current_cut: int = Cut.FINAL
var _playlist: Array[int]
var _index: int = 0
var _elapsed: float = 0.0


func _init(playlist: Array[int]) -> void:
	_playlist = playlist if not playlist.is_empty() else [Cut.FINAL] as Array[int]


## Wall cuts need that finisher to exist; the car cuts need at least one.
static func playlist_for(finishers: int) -> Array[int]:
	var cuts: Array[int] = []
	if finishers >= 3:
		cuts.append(Cut.P3_TAG)
	if finishers >= 1:
		cuts.append(Cut.HERO)
	if finishers >= 2:
		cuts.append(Cut.P2_TAG)
	if finishers >= 1:
		cuts.append(Cut.DETAIL)
	cuts.append(Cut.FINAL)
	return cuts


func start(instant: bool) -> void:
	_elapsed = 0.0
	_index = _playlist.size() - 1 if instant else 0
	_enter()


func tick(delta: float) -> void:
	if is_final():
		return
	_elapsed += delta
	if _elapsed >= CUT_SECONDS:
		_elapsed = 0.0
		_index += 1
		_enter()


func skip_to_final() -> void:
	if is_final():
		return
	_index = _playlist.size() - 1
	_enter()


func is_final() -> bool:
	return current_cut == Cut.FINAL


func label() -> String:
	return "CUT %d/%d // %s" % [_index + 1, _playlist.size(), NAMES[current_cut]]


func _enter() -> void:
	current_cut = _playlist[_index]
	cut_changed.emit(current_cut)
