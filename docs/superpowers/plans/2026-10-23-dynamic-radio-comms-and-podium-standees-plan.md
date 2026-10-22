# Dynamic Radio Comms Overhaul & 2D Podium Character Showcase Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Overhaul the team radio cut-in system with dynamic driver portraits, procedural manga soundwave animations, high-drama driver wheel-to-wheel radio triggers, and enhance the podium screen with 2D character standee banners for P1, P2, and P3 finishers.

**Architecture:** 
1. In `scripts/ui/anime_radio_cutin.gd`, add procedural manga soundwave drawing with dynamic audio bar pulsing during active transmission.
2. In `scripts/hud/race_hud.gd`, resolve canonical driver portraits via `GarageRoster.portrait_path(car.id)` instead of a single static portrait.
3. In `scripts/gt/gt_driving.gd` and `scripts/gt/gt_race.gd`, implement high-frequency driver radio calls (overtakes, defending, ERS boost, tire cliff, contact) with a per-car cooldown mechanism.
4. In `tools/audio/radio_lines.mjs` and `assets/audio/radio/voice/manifest.json`, map the new driver lines, including female voice configuration for Freja Berg.
5. In `scripts/ui/podium_screen.gd`, build 2D neo-brutalist character standee cards for the top 3 finishers, with staggered entrance animations and tier ribbons.

**Tech Stack:** Godot Engine 4.7.2 stable (GDScript 2.0, CanvasLayer, 2D Drawing/Tweens), Kokoro-82M TTS Audio pipeline.

---

## File Structure & Responsibilities

| File Path | Responsibility |
| :--- | :--- |
| `scripts/ui/anime_radio_cutin.gd` | Comic radio cut-in banner with manga soundwave animation (`_draw_manga_soundwave`). |
| `scripts/hud/race_hud.gd` | In-game HUD coordinator, dynamic driver portrait resolution via `GarageRoster`. |
| `scripts/gt/gt_driving.gd` | Vehicle simulation loop: triggers driver radio calls on overtakes, defending, ERS, and wear. |
| `scripts/gt/gt_race.gd` | Race coordinator: cooldown tracking for driver radio messages (`can_push_driver_radio`). |
| `scripts/ui/podium_screen.gd` | Podium celebration screen: 2D character standees, gold/silver/bronze tiers, staggered slide-up animation. |
| `tools/audio/radio_lines.mjs` | Audio line database and voice actor assignments (including female voice for Freja Berg). |
| `assets/audio/radio/voice/manifest.json` | Voice clip manifest mapping regex patterns to audio files. |
| `tests/test_radio_and_podium.gd` | Headless test suite validating portraits, soundwave, triggers, and podium standees. |

---

## Tasks

### Task 1: Create Headless Test Suite for Radio & Podium

**Files:**
- Create: `tests/test_radio_and_podium.gd`

- [ ] **Step 1: Write test suite covering portraits, soundwave, triggers, and podium standees**
  Write tests in `tests/test_radio_and_podium.gd`:
  - `test_driver_portraits_exist()`: Iterates all 20 cars/slots in `GarageRoster` and asserts `ResourceLoader.exists(GarageRoster.portrait_path(i))`.
  - `test_anime_radio_cutin_soundwave()`: Instantiates `AnimeRadioCutIn`, checks that soundwave is enabled and state updates when radio plays.
  - `test_driver_radio_cooldown_and_triggers()`: Sets up a headless `GtRace`, tests `can_push_driver_radio(car_id)` cooldown.
  - `test_podium_standees_generation()`: Instantiates `PodiumScreen`, calls `present(race)`, asserts 3 standee cards exist above steps with valid portrait textures.

- [ ] **Step 2: Run test suite to verify current failure**
  Run: `godot --headless --path . -s tests/test_radio_and_podium.gd`
  Expected: FAIL or errors on unimplemented features (soundwave properties or standee card nodes).

---

### Task 2: Implement Procedural Manga Soundwave in `AnimeRadioCutin`

**Files:**
- Modify: `scripts/ui/anime_radio_cutin.gd`

- [ ] **Step 1: Add soundwave state variables and update loop**
  In `scripts/ui/anime_radio_cutin.gd`:
  - Add `var soundwave_active: bool = false`
  - Add `var _soundwave_time: float = 0.0`
  - In `_process(delta: float)`: When `_present` is true and transmitting, increment `_soundwave_time += delta` and call `_backdrop.queue_redraw()`.

- [ ] **Step 2: Implement `_draw_manga_soundwave(w: float, h: float)`**
  In `_draw_backdrop()`:
  - Call `_draw_manga_soundwave(w, h)`:
    - Draw 12–16 vertical ink bars in a dedicated soundwave cluster adjacent to the speech label.
    - Bar heights calculated from harmonic pseudo-frequencies: $A_i = \text{base} + \text{amplitude} \times |\sin(\omega_i t + \phi_i)|$.
    - Fill bars with `_accent` color with a 2px `T.INK_BORDER_BLACK` outline and interior vertical hatching.
    - When `not soundwave_active`, smoothly decay bar heights to a flat 2px baseline.

- [ ] **Step 3: Toggle soundwave state on radio play and finish**
  In `_play()`: Set `soundwave_active = true`.
  In `_hide_banner()`: Set `soundwave_active = false`.

- [ ] **Step 4: Run test to verify soundwave functionality**
  Run: `godot --headless --path . -s tests/test_radio_and_podium.gd`
  Expected: `test_anime_radio_cutin_soundwave()` passes.

---

### Task 3: Implement Dynamic Driver Portrait Resolution in `RaceHUD`

**Files:**
- Modify: `scripts/hud/race_hud.gd`

- [ ] **Step 1: Update `_on_radio(message: Dictionary)`**
  In `scripts/hud/race_hud.gd`:
  - When `String(message["speaker"]) == "driver"` and `car != null`:
    - Lookup portrait using `GarageRoster.portrait_path(car.id)`.
    - If `ResourceLoader.exists(portrait_path)`, load and call `cut_in.set_portrait(load(portrait_path))`.
    - Fallback to `PORTRAIT` if path is missing.
  - For engineer messages, ensure `ENGINEER_PORTRAIT` remains set.

- [ ] **Step 2: Verify `GarageRoster` coverage for all 20 driver slots**
  Verify that `GarageRoster.portrait_path(i)` maps correctly to `reference-assets/characters/<team>/<driver>/radio_portrait.png`.

- [ ] **Step 3: Run test to verify portrait resolution**
  Run: `godot --headless --path . -s tests/test_radio_and_podium.gd`
  Expected: `test_driver_portraits_exist()` passes.

---

### Task 4: Implement High-Drama Driver Radio Comms & Cooldown in `GtRace` / `GtDriving`

**Files:**
- Modify: `scripts/gt/gt_race.gd`
- Modify: `scripts/gt/gt_driving.gd`
- Modify: `scripts/gt/gt_contacts.gd`

- [ ] **Step 1: Add driver cooldown logic in `gt_race.gd`**
  - Add `var driver_radio_cooldown: Dictionary = {} # car_id -> float (seconds left)`
  - Add `func can_push_driver_radio(car_id: int) -> bool`:
    - Returns `true` if cooldown $\le 0.0$.
  - In `_process_tick(dt)`: Decrease cooldown timers by `dt`.
  - In `push_radio(car, speaker, text, urgent)`: If `speaker == "driver"` and not `urgent`, set cooldown to `15.0`.

- [ ] **Step 2: Trigger overtake and defending calls in `gt_driving.gd`**
  - In pass logic (when `car` successfully overtakes `ahead`):
    - If `race.can_push_driver_radio(car.id)`:
      - `race.push_radio(car, "driver", "Pass made on %s! Clean move down the inside!" % ahead.code)`
    - If `race.can_push_driver_radio(ahead.id)`:
      - `race.push_radio(ahead, "driver", "Lost the spot to %s! Defending now!" % car.code)`

- [ ] **Step 3: Trigger ERS boost and tire cliff calls**
  - When ERS boost is engaged in `deploy_ers()`:
    - If `race.can_push_driver_radio(car.id)`:
      - `race.push_radio(car, "driver", "Deploying ERS boost! Maximum attack!")`
  - In tire wear calculation:
    - When `car.tyre_wear > 0.75` for the first time:
      - If `race.can_push_driver_radio(car.id)`:
        - `race.push_radio(car, "driver", "Tyres are cooked! Rear is sliding everywhere!")`
    - On puncture (`car.tyre_wear > 0.96`):
      - `race.push_radio(car, "driver", "Puncture! Tyre is shredded, limping to pits!", true)`

- [ ] **Step 4: Run test to verify driver event triggers**
  Run: `godot --headless --path . -s tests/test_radio_and_podium.gd`
  Expected: `test_driver_radio_cooldown_and_triggers()` passes.

---

### Task 5: Expand Voice Lines & Manifest for Kokoro Audio

**Files:**
- Modify: `tools/audio/radio_lines.mjs`
- Modify: `assets/audio/radio/voice/manifest.json`

- [ ] **Step 1: Add new driver lines to `radio_lines.mjs`**
  Add lines matching:
  - `drv_pass_made`: `^Pass made on \\w+! Clean move down the inside!$` -> "Pass made! Clean move down the inside!"
  - `drv_lost_spot`: `^Lost the spot to \\w+! Defending now!$` -> "Lost the spot, defending now!"
  - `drv_ers_boost`: `^Deploying ERS boost! Maximum attack!$` -> "Deploying E R S boost! Maximum attack!"
  - `drv_tyres_cooked`: `^Tyres are cooked! Rear is sliding everywhere!$` -> "Tyres are cooked! Rear is sliding everywhere!"
  - `drv_puncture_urgent`: `^Puncture! Tyre is shredded, limping to pits!$` -> "Puncture! Tyre shredded, limping to pits!"

- [ ] **Step 2: Update Voice Roster Configuration**
  - Support female voice selection (`af_bella` / `af_nicole`) for Freja Berg lines.
  - Update `assets/audio/radio/voice/manifest.json` so `RadioVoice.find()` immediately resolves pattern matches.

---

### Task 6: Implement 2D Character Standees on `PodiumScreen`

**Files:**
- Modify: `scripts/ui/podium_screen.gd`

- [ ] **Step 1: Create `_build_character_standee(place: int, car: GtCar) -> Control`**
  In `scripts/ui/podium_screen.gd`:
  - Construct a Neo-Brutalist standee card ($360\text{px} \times 240\text{px}$) sitting directly above each step:
    - 4px black ink border with 6px offset shadow.
    - Background tinted with `Liveries.color_for(car.team_id)` and manga hatching.
    - TextureRect displaying `radio_portrait.png` loaded via `GarageRoster.portrait_path(car.id)`.
    - Championship Ribbon:
      - P1: Gold (`#FFD23F`) with `"P1 WINNER // 25 PTS"`.
      - P2: Silver (`#D8DCE6`) with `"P2 RUNNER-UP // 18 PTS"`.
      - P3: Bronze (`#D9803A`) with `"P3 PODIUM // 15 PTS"`.
    - Driver name in bold display font, car number badge, and finishing time.
  - Add to `standees` array.

- [ ] **Step 2: Implement Staggered Entrance Animation**
  - In `present(race)`:
    - Animate standees with create_tween():
      - P3 (index 2): $t = 0.0\text{s}$, slide up $\Delta y = +60\text{px} \rightarrow 0\text{px}$, fade in $0.35\text{s}$.
      - P2 (index 1): $t = 0.2\text{s}$, slide up $\Delta y = +60\text{px} \rightarrow 0\text{px}$, fade in $0.35\text{s}$.
      - P1 (index 0): $t = 0.4\text{s}$, slide up $\Delta y = +80\text{px} \rightarrow 0\text{px}$, fade in $0.4\text{s}$.
      - Trigger trophy reveal and confetti at $t = 0.5\text{s}$.

- [ ] **Step 3: Run test to verify podium standee generation**
  Run: `godot --headless --path . -s tests/test_radio_and_podium.gd`
  Expected: `test_podium_standees_generation()` passes with all assertions green.

---

### Task 7: Full Regression Verification & Documentation

**Files:**
- Test: All 24 test suites in `tests/test_*.gd`
- Create: `executor-report/reports/FASE-8.4-DYNAMIC-RADIO-AND-PODIUM-REPORT.md`
- Update: `ROADMAP.md`

- [ ] **Step 1: Execute all test suites**
  Run: `powershell -Command "Get-ChildItem tests\test_*.gd | ForEach-Object { godot --headless --path . -s ('res://tests/' + $_.Name) }"`
  Expected: 24/24 PASS (0 FAIL).

- [ ] **Step 2: Author Executive Completion Report**
  Write `executor-report/reports/FASE-8.4-DYNAMIC-RADIO-AND-PODIUM-REPORT.md` documenting:
  - Soundwave implementation and manga visual parameters.
  - Driver comms trigger matrix and cooldown benchmark.
  - Podium 2D character standees visual structure and animation timings.
  - Headless test verification log.

- [ ] **Step 3: Update Roadmap**
  Mark Fase 8.4 as Complete in `ROADMAP.md`.
