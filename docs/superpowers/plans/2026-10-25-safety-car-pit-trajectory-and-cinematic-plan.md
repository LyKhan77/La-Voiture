# Safety Car Pit Trajectory, Cinematic Cut-In & Peel-Off Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a complete physical and cinematic Safety Car deployment and restart sequence: driving out from the pit exit ramp, blending onto the track ahead of the pack with a 4-second dynamic broadcast camera cut-in and manga banner, pacing the field, and peeling off into the pit entry lane on the in-lap.

**Architecture:** Extend `GtRace` with mathematically continuous spline trajectories for pit exit merge and pit entry peel-off. Add `Mode.SAFETY_CAR` and automated cut-in tracking to `BroadcastCameraDirector`, and integrate a high-contrast manga banner overlay into `RaceHud` triggered by race control flag changes.

**Tech Stack:** Godot Engine 4.7.2 stable, GDScript 2.0 (static typing), CanvasItem Custom Drawing, 3D Kinematics.

---

### Task 1: Trajectory Math & Dynamic Deployment in GtRace

**Files:**
- Modify: `scripts/gt/gt_race.gd:285-345`
- Create: `tests/test_safety_car_cinematic.gd`

- [ ] **Step 1: Write the failing unit test for Safety Car pit exit and peel-off trajectories**

Create `tests/test_safety_car_cinematic.gd`:
```gdscript
extends SceneTree

const TrackCircuitScene := preload("res://scenes/race_world/track_circuit.tscn")
const GtTrackScript := preload("res://scripts/gt/gt_track.gd")
const GtRaceScript := preload("res://scripts/gt/gt_race.gd")
const GtTypes := preload("res://scripts/gt/gt_types.gd")
const PitLaneScript := preload("res://scripts/world/circuits/apex_ring/apex_pit_complex.gd")

var _checks: int = 0
var _failures: int = 0


func check(condition: bool, message: String) -> void:
	_checks += 1
	if condition:
		print("[PASS] %s" % message)
	else:
		_failures += 1
		printerr("[FAIL] %s" % message)


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var circuit: Node3D = TrackCircuitScene.instantiate()
	root.add_child(circuit)
	var track := GtTrackScript.new(circuit, 14.0)
	var race := GtRaceScript.new(track, 10, 42, 0)
	
	_test_pit_exit_trajectory(race, track)
	_test_pit_entry_peeloff(race, track)
	
	circuit.queue_free()
	print("\n%d assertions, %d failure(s)" % [_checks, _failures])
	if _failures > 0:
		quit(1)
	else:
		quit(0)


func _test_pit_exit_trajectory(race: GtRace, track: GtTrack) -> void:
	race.set_flag(GtTypes.Flag.SC, 1, "SAFETY CAR DEPLOYED", 30.0)
	var sc: Dictionary = race.safety_car
	check(bool(sc["active"]), "SC becomes active on Flag.SC")
	check(float(sc["lateral"]) > 5.0, "SC starts in pit exit fast lane (lateral %.1f > 5.0m)" % float(sc["lateral"]))
	
	# Simulate movement through the pit exit blend
	var prev_lateral: float = float(sc["lateral"])
	var blended_to_track: bool = false
	for _step: int in range(120):
		race.step()
		var cur_lateral: float = float(race.safety_car["lateral"])
		if cur_lateral < 0.5:
			blended_to_track = true
			break
		check(cur_lateral <= prev_lateral + 0.05, "SC lateral decreases smoothly during pit exit merge (cur: %.2f, prev: %.2f)" % [cur_lateral, prev_lateral])
		prev_lateral = cur_lateral
	check(blended_to_track, "SC successfully merges across blend line onto track centerline")


func _test_pit_entry_peeloff(race: GtRace, track: GtTrack) -> void:
	race.race_control["sc_laps_remaining"] = 0
	race.step()
	check(int(race.safety_car["phase"]) == GtTypes.SafetyCarPhase.IN_THIS_LAP, "SC enters IN_THIS_LAP phase when laps remaining reach 0")
	check(not bool(race.safety_car["lights_on"]), "SC roof strobes turn off on IN_THIS_LAP")
	
	# Position SC near pit entry
	race.safety_car["s"] = PitLaneScript.ENTRY_S - 70.0
	race.step()
	var peel_lateral: float = float(race.safety_car["lateral"])
	check(peel_lateral > 1.0, "SC peels right towards pit entry lane (lateral %.2f > 1.0m)" % peel_lateral)
```

- [ ] **Step 2: Run test to verify it fails**

Run: `godot --headless --path . -s res://tests/test_safety_car_cinematic.gd`  
Expected: FAIL on `lateral > 5.0` because `gt_race.gd` currently sets `lateral = 0.0` and spawns SC directly on track centerline.

- [ ] **Step 3: Implement mathematical pit exit and entry trajectories in GtRace**

In `scripts/gt/gt_race.gd`:
Add trajectory helpers and update `set_flag` and `_update_race_control`:
```gdscript
const PitLaneScript := preload("res://scripts/world/circuits/apex_ring/apex_pit_complex.gd")

## Pit Exit trajectory: blends from FAST_LANE_M (11.6m) to EDGE_LATERAL_M (5.2m) at EXIT_S, then to 0.0m on track.
static func sc_pit_exit_lateral(s_lap: float) -> float:
	var s_rel: float = s_lap - PitLaneScript.EXIT_S
	if s_rel <= -60.0:
		return PitLaneScript.FAST_LANE_M
	elif s_rel <= 0.0:
		var t: float = smoothstep(-60.0, 0.0, s_rel)
		return lerpf(PitLaneScript.FAST_LANE_M, PitLaneScript.EDGE_LATERAL_M, t)
	elif s_rel <= 70.0:
		var t: float = smoothstep(0.0, 70.0, s_rel)
		return lerpf(PitLaneScript.EDGE_LATERAL_M, 0.0, t)
	return 0.0


## Pit Entry peel-off trajectory: blends from 0.0m to EDGE_LATERAL_M (5.2m) at ENTRY_S, then to FAST_LANE_M (11.6m).
static func sc_pit_entry_lateral(s_lap: float) -> float:
	var s_rel: float = s_lap - PitLaneScript.ENTRY_S
	if s_rel <= -80.0:
		return 0.0
	elif s_rel <= 0.0:
		var t: float = smoothstep(-80.0, 0.0, s_rel)
		return lerpf(0.0, PitLaneScript.EDGE_LATERAL_M, t)
	elif s_rel <= 60.0:
		var t: float = smoothstep(0.0, 60.0, s_rel)
		return lerpf(PitLaneScript.EDGE_LATERAL_M, PitLaneScript.FAST_LANE_M, t)
	return PitLaneScript.FAST_LANE_M
```

And update `set_flag` when `flag == GtTypes.Flag.SC`:
```gdscript
	if flag == GtTypes.Flag.SC and not was_sc:
		var leader: GtCar = null
		for car: GtCar in standings():
			if not car.is_dnf and car.finished_at < 0.0:
				leader = car
				break
		var leader_s: float = leader.s if leader != null else 0.0
		var lap_base: float = floorf(leader_s / track.length) * track.length
		var spawn_s: float = lap_base + PitLaneScript.EXIT_S - 60.0
		# If leader has already reached/passed pit exit ramp, spawn on upcoming lap or ahead
		if spawn_s <= leader_s:
			if leader_s < lap_base + PitLaneScript.EXIT_S + 70.0:
				spawn_s = leader_s + 18.0
			else:
				spawn_s = lap_base + track.length + PitLaneScript.EXIT_S - 60.0
		var s_lap: float = fposmod(spawn_s, track.length)
		safety_car = {
			"active": true,
			"phase": GtTypes.SafetyCarPhase.DEPLOYED,
			"s": spawn_s,
			"v": 20.0,
			"lateral": sc_pit_exit_lateral(s_lap),
			"lights_on": true,
			"just_deployed": true,
		}
```

And in `_update_race_control`:
Update lateral computation:
```gdscript
		var s_lap: float = fposmod(float(safety_car["s"]), track.length)
		var is_in_lap: bool = int(safety_car["phase"]) == GtTypes.SafetyCarPhase.IN_THIS_LAP
		if is_in_lap and (s_lap >= PitLaneScript.ENTRY_S - 80.0 or s_lap <= PitLaneScript.EXIT_S):
			safety_car["lateral"] = sc_pit_entry_lateral(s_lap)
		elif s_lap >= PitLaneScript.EXIT_S - 60.0 and s_lap <= PitLaneScript.EXIT_S + 70.0:
			safety_car["lateral"] = sc_pit_exit_lateral(s_lap)
		else:
			safety_car["lateral"] = track.ideal_lateral_at(float(safety_car["s"])) * 0.35
```

- [ ] **Step 4: Run test to verify it passes**

Run: `godot --headless --path . -s res://tests/test_safety_car_cinematic.gd`  
Expected: PASS with 6 assertions, 0 failure(s).

- [ ] **Step 5: Run existing test suites to check for regression**

Run: `godot --headless --path . -s res://tests/test_car_dynamics_vfx.gd`  
Expected: 29 assertions, 0 failure(s).

- [ ] **Step 6: Commit**

```bash
git add scripts/gt/gt_race.gd tests/test_safety_car_cinematic.gd
git commit -m "feat(sc): implement pit exit merge and entry peel-off trajectories"
```

---

### Task 2: Broadcast Camera Director Safety Car Mode & Cut-In

**Files:**
- Modify: `scripts/world/weekend/broadcast_camera_director.gd`
- Modify: `scripts/world/weekend/race_weekend_world.gd`
- Modify: `tests/test_safety_car_cinematic.gd`

- [ ] **Step 1: Write test assertions for BroadcastCameraDirector Safety Car Mode**

In `tests/test_safety_car_cinematic.gd`, add `_test_broadcast_camera_safety_car()`:
```gdscript
const CameraDirectorScript := preload("res://scripts/world/weekend/broadcast_camera_director.gd")

func _test_broadcast_camera_safety_car(circuit: Node3D, track: GtTrack) -> void:
	var director := CameraDirectorScript.new()
	var cam := Camera3D.new()
	circuit.add_child(cam)
	director.setup(cam, circuit)
	
	var dummy_car := Node3D.new()
	circuit.add_child(dummy_car)
	dummy_car.global_position = Vector3(10, 0, 10)
	director.set_target(dummy_car)
	
	var dummy_sc := Node3D.new()
	circuit.add_child(dummy_sc)
	dummy_sc.global_position = Vector3(50, 0, 50)
	
	director.trigger_safety_car_cut(dummy_sc, 4.0)
	check(director.active_mode() == CameraDirectorScript.Mode.SAFETY_CAR, "Camera switches to Mode.SAFETY_CAR on trigger_safety_car_cut")
	
	director.update(0.1)
	check(cam.global_position.distance_to(dummy_sc.global_position) < 25.0, "Camera tracks within 25m of Safety Car actor")
	
	director.update(4.5)
	check(director.active_mode() == CameraDirectorScript.Mode.CHASE, "Camera returns to Mode.CHASE after safety car cinematic duration")
	
	cam.queue_free()
	dummy_car.queue_free()
	dummy_sc.queue_free()
	director.queue_free()
```

- [ ] **Step 2: Run test to verify it fails**

Run: `godot --headless --path . -s res://tests/test_safety_car_cinematic.gd`  
Expected: FAIL ("Non-existent function 'trigger_safety_car_cut' in BroadcastCameraDirector").

- [ ] **Step 3: Implement Mode.SAFETY_CAR and trigger_safety_car_cut in BroadcastCameraDirector**

In `scripts/world/weekend/broadcast_camera_director.gd`:
1. Add `Mode.SAFETY_CAR` to `enum Mode { CHASE, COCKPIT, HELI, TRACKSIDE_TV, PITSTOP, SAFETY_CAR }`.
2. Add `"SAFETY CAR CAM"` to `MODE_NAMES`.
3. Add:
```gdscript
const SC_CAM_FOV: float = 65.0
var safety_car_actor: Node3D = null
var safety_car_cut_s: float = 0.0

func trigger_safety_car_cut(sc_actor: Node3D, duration_s: float = 4.0) -> void:
	safety_car_actor = sc_actor
	safety_car_cut_s = duration_s
	_snap = true


func active_mode() -> int:
	if safety_car_cut_s > 0.0 and safety_car_actor != null and is_instance_valid(safety_car_actor):
		return Mode.SAFETY_CAR
	if auto_pit_camera and pit_focus != null:
		return Mode.PITSTOP
	return mode
```
4. Implement `_update_safety_car(dt)`:
```gdscript
func _update_safety_car(dt: float) -> void:
	_set_lens(SC_CAM_FOV, 0.1)
	if safety_car_cut_s > 0.0:
		safety_car_cut_s = maxf(0.0, safety_car_cut_s - dt)
	var actor: Node3D = safety_car_actor if (safety_car_actor != null and is_instance_valid(safety_car_actor)) else target
	var pose: Transform3D = actor.global_transform
	# Dynamic low 3/4 front tracking shot
	var wanted: Vector3 = pose.origin - pose.basis.z * 7.2 + pose.basis.x * 2.6 + Vector3.UP * 1.3
	camera.global_position = camera.global_position.lerp(wanted, 1.0 if _snap else 1.0 - exp(-8.0 * dt))
	camera.look_at(pose.origin + Vector3.UP * 0.75, Vector3.UP)
```
5. In `scripts/world/weekend/race_weekend_world.gd`, listen to `race.flag_changed`:
When `flag == GtTypes.Flag.SC`, call:
```gdscript
if vfx != null and vfx.safety_car_actor != null:
	camera_director.trigger_safety_car_cut(vfx.safety_car_actor, 4.0)
```

- [ ] **Step 4: Run test to verify it passes**

Run: `godot --headless --path . -s res://tests/test_safety_car_cinematic.gd`  
Expected: PASS with all camera assertions passing.

- [ ] **Step 5: Commit**

```bash
git add scripts/world/weekend/broadcast_camera_director.gd scripts/world/weekend/race_weekend_world.gd tests/test_safety_car_cinematic.gd
git commit -m "feat(sc): add broadcast camera safety car cut-in and tracking mode"
```

---

### Task 3: Stylized Manga Safety Car Banner Overlay

**Files:**
- Create: `scripts/hud/safety_car_banner.gd`
- Modify: `scripts/hud/race_hud.gd`
- Modify: `tests/test_safety_car_cinematic.gd`

- [ ] **Step 1: Write test assertions for SafetyCarBanner**

In `tests/test_safety_car_cinematic.gd`, add `_test_safety_car_banner()`:
```gdscript
const BannerScript := preload("res://scripts/hud/safety_car_banner.gd")

func _test_safety_car_banner(circuit: Node3D) -> void:
	var banner := BannerScript.new()
	circuit.add_child(banner)
	
	banner.trigger(GtTypes.Flag.SC, "SAFETY CAR DEPLOYED")
	check(banner.visible, "Banner becomes visible on trigger")
	check(banner.is_deploying(), "Banner identifies DEPLOYED state")
	check(banner.header_label.text.find("SAFETY CAR") != -1, "Banner header displays SAFETY CAR")
	
	banner.advance(4.0)
	check(not banner.visible, "Banner hides after presentation duration")
	banner.queue_free()
```

- [ ] **Step 2: Run test to verify it fails**

Run: `godot --headless --path . -s res://tests/test_safety_car_cinematic.gd`  
Expected: FAIL ("Could not load script safety_car_banner.gd").

- [ ] **Step 3: Implement SafetyCarBanner**

Create `scripts/hud/safety_car_banner.gd`:
```gdscript
class_name SafetyCarBanner
extends Control

## High-impact manga banner overlay for Safety Car deployment and restart.
## Neo-brutalist styling: hazard stripes, Japanese kanji subtext, screentone dots,
## bold typography and 1-frame negative flash.

const UI = preload("res://scripts/ui/pit_wall_ui.gd")
const T = preload("res://scripts/ui/ui_theme_tokens.gd")
const GtTypes := preload("res://scripts/gt/gt_types.gd")

const BANNER_W: float = 780.0
const BANNER_H: float = 90.0
const CHEVRON_W: float = 18.0
const CHEVRON_H: float = 12.0
const DURATION_S: float = 3.8

var header_label: Label
var sub_label: Label
var clock_s: float = 0.0
var active_flag: int = GtTypes.Flag.GREEN
var _offset: float = 0.0
var _tint: Color = T.ACCENT_CYBER_YELLOW


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(BANNER_W, BANNER_H)
	size = custom_minimum_size
	visible = false
	
	header_label = UI.label("", 26, T.INK_BORDER_BLACK, UI.HEADER)
	header_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header_label.position = Vector2(0.0, 18.0)
	header_label.size = Vector2(BANNER_W, 36.0)
	add_child(header_label)
	
	sub_label = UI.label("", 12, T.INK_BORDER_BLACK, UI.SEMI)
	sub_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub_label.position = Vector2(0.0, 54.0)
	sub_label.size = Vector2(BANNER_W, 22.0)
	add_child(sub_label)


func trigger(flag: int, message: String) -> void:
	active_flag = flag
	clock_s = DURATION_S
	visible = true
	if flag == GtTypes.Flag.SC:
		_tint = T.ACCENT_CYBER_YELLOW
		header_label.text = "★ SAFETY CAR DEPLOYED ★"
		sub_label.text = "セーフティーカー出動 // REDUCE SPEED & MAINTAIN DELTA"
	else:
		_tint = Color("#38bdf8")
		header_label.text = "◆ SAFETY CAR IN THIS LAP ◆"
		sub_label.text = "リスタート準備 // LIGHTS OUT // PREPARE FOR RESTART"
	queue_redraw()


func is_deploying() -> bool:
	return active_flag == GtTypes.Flag.SC


func advance(delta: float) -> void:
	if clock_s > 0.0:
		clock_s -= delta
		_offset = fmod(_offset + delta * 50.0, CHEVRON_W * 2.0)
		if clock_s <= 0.0:
			visible = false
		queue_redraw()


func _draw() -> void:
	if not visible:
		return
	# Dark brutalist backdrop
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.06, 0.07, 0.09, 0.95))
	draw_rect(Rect2(Vector2.ZERO, size), _tint, false, 3.0)
	
	# Top and bottom hazard chevrons
	for edge_y: float in [0.0, size.y - CHEVRON_H]:
		draw_rect(Rect2(0.0, edge_y, size.x, CHEVRON_H), T.INK_BORDER_BLACK)
		var x: float = -CHEVRON_W * 2.0 + _offset
		while x < size.x + CHEVRON_W:
			var chevron := PackedVector2Array([
				Vector2(x, edge_y + CHEVRON_H), Vector2(x + CHEVRON_W, edge_y + CHEVRON_H),
				Vector2(x + CHEVRON_W + CHEVRON_H, edge_y), Vector2(x + CHEVRON_H, edge_y),
			])
			draw_colored_polygon(chevron, _tint)
			x += CHEVRON_W * 2.0
```

- [ ] **Step 4: Integrate SafetyCarBanner into RaceHud**

In `scripts/hud/race_hud.gd`:
Instantiate `SafetyCarBanner` under `stage`, center it at `Vector2((1920 - 780)/2, 90.0)`.
In `_on_flag_changed(flag: int, message: String)`:
If `flag == GtTypes.Flag.SC`:
`sc_banner.trigger(flag, message)`
In `update(delta: float)`:
`sc_banner.advance(delta)`
Also trigger banner if `race.safety_car["phase"] == GtTypes.SafetyCarPhase.IN_THIS_LAP` transitions.

- [ ] **Step 5: Run test to verify it passes**

Run: `godot --headless --path . -s res://tests/test_safety_car_cinematic.gd`  
Expected: PASS with 100% assertions green.

- [ ] **Step 6: Commit**

```bash
git add scripts/hud/safety_car_banner.gd scripts/hud/race_hud.gd tests/test_safety_car_cinematic.gd
git commit -m "feat(hud): add stylized manga Safety Car deployment and restart banner"
```

---

### Task 4: Full Matrix Verification & Quality Gate Assurance

**Files:**
- Run: all 34 test suites in `tests/test_*.gd`

- [ ] **Step 1: Run the full 34-suite test matrix**

Run:
```bash
powershell -Command "Get-ChildItem tests\test_*.gd | ForEach-Object { godot --headless --path . -s ('res://tests/' + \$_.Name); if (\$LASTEXITCODE -ne 0) { throw ('Failed: ' + \$_.Name) } }; Write-Host 'ALL 34 TESTS PASSED!'"
```
Expected: All 34 test suites output PASS with exit code 0.

- [ ] **Step 2: Verify zero memory leak and 0 orphan nodes on scene exit**

Run `tests/test_race_weekend_and_physics.gd` and verify scene cleanup:
```bash
godot --headless --path . -s res://tests/test_race_weekend_and_physics.gd
```
Expected: 0 orphan nodes, PASS.

- [ ] **Step 3: Update ROADMAP.md and commit**

Update `ROADMAP.md` tracking the Safety Car Physical & Cinematic Procedure upgrade.
```bash
git add ROADMAP.md
git commit -m "docs: update roadmap with Safety Car pit trajectory and cinematic cut-in"
```
