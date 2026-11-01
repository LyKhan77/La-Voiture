extends SceneTree

## Run: godot --headless --path . -s res://tests/test_winning_cut_director.gd
const Cut := WinningCutDirector.Cut
var failures: int = 0
var assertions: int = 0
var emitted: Array[int] = []


func _initialize() -> void:
	call_deferred("_run")


func check(ok: bool, message: String) -> void:
	assertions += 1
	if not ok:
		failures += 1
		push_error(message)
	print("[%s] %s" % ["PASS" if ok else "FAIL", message])


func _on_cut(cut: int) -> void:
	emitted.append(cut)


func _make(finishers: int) -> WinningCutDirector:
	var director := WinningCutDirector.new(WinningCutDirector.playlist_for(finishers))
	director.cut_changed.connect(_on_cut)
	emitted.clear()
	return director


func _run() -> void:
	var full: Array[int] = [Cut.INTRO, Cut.FOCUS_P3, Cut.FOCUS_P2, Cut.FOCUS_P1, Cut.FINAL]
	check(WinningCutDirector.playlist_for(20) == full and WinningCutDirector.playlist_for(3) == full,
		"Three or more finishers get all five cuts")
	check(WinningCutDirector.playlist_for(2) == ([Cut.INTRO, Cut.FOCUS_P2, Cut.FOCUS_P1, Cut.FINAL] as Array[int]),
		"Two finishers skip the P3 focus")
	check(WinningCutDirector.playlist_for(1) == ([Cut.INTRO, Cut.FOCUS_P1, Cut.FINAL] as Array[int]),
		"One finisher gets intro, P1 focus and final")
	check(WinningCutDirector.playlist_for(0) == ([Cut.FINAL] as Array[int]), "No finisher goes straight to the final")

	var director: WinningCutDirector = _make(20)
	director.start(false)
	check(director.current_cut == Cut.INTRO and emitted == ([Cut.INTRO] as Array[int]), "start() announces the first cut once")
	director.tick(1.59)
	check(director.current_cut == Cut.INTRO and is_equal_approx(WinningCutDirector.CUT_SECONDS, 1.6), "A cut lasts 1.6 s (4 beats @ 150 BPM)")
	director.tick(0.02)
	check(director.current_cut == Cut.FOCUS_P3 and emitted == ([Cut.INTRO, Cut.FOCUS_P3] as Array[int]), "Crossing 1.6 s advances to the next cut")
	check(director.label() == "CUT 2/5 // FOCUS P3", "The label counts cuts in the playlist (%s)" % director.label())

	director = _make(20)
	director.start(false)
	for i: int in range(4):
		director.tick(WinningCutDirector.CUT_SECONDS + 0.001)
	check(director.is_final() and emitted.back() == Cut.FINAL, "The final lands after four bars, at 6.4 s")
	director = _make(20)
	director.start(false)
	director.tick(5.0)
	check(director.current_cut == Cut.FOCUS_P3, "One tick never skips over a cut")
	for i: int in range(6):
		director.tick(1.65)
	check(director.is_final() and emitted.back() == Cut.FINAL, "The timeline settles on the final cut")
	var count: int = emitted.size()
	director.tick(100.0)
	check(emitted.size() == count and director.is_final(), "The final cut never advances or re-announces")

	director = _make(20)
	director.start(false)
	director.tick(0.5)
	director.skip_to_final()
	director.skip_to_final()
	check(emitted.count(Cut.FINAL) == 1 and director.is_final(), "Skipping twice announces the final once")
	director = _make(20)
	director.start(true)
	check(director.is_final() and emitted == ([Cut.FINAL] as Array[int]), "start(true) lands on the final immediately")
	director = _make(3)
	director.start(false)
	director.tick(1.65)
	check(director.label() == "CUT 2/5 // FOCUS P3", "Label denominator is the playlist length")
	director = _make(1)
	director.start(false)
	check(director.label() == "CUT 1/3 // INTRO", "A shortened playlist renumbers its cuts")
	print("CUT DIRECTOR: %d assertions, %d FAIL" % [assertions, failures])
	quit(0 if failures == 0 else 1)
