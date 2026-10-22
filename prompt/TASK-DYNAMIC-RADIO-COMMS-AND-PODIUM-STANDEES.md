# TASK HANDOFF: Fase 8.4 — Dynamic Radio Comms Overhaul & 2D Podium Character Showcase

**Branch/Target:** `main`  
**Engine:** Godot Engine 4.7.2 stable  
**Role:** Senior Gameplay & Presentation Engineer  
**Reference Documents:**
- Design Spec: [`docs/superpowers/specs/2026-10-23-dynamic-radio-comms-and-podium-standees-design.md`](file:///D:/Occupation/Porto/genex/La_Voiture/docs/superpowers/specs/2026-10-23-dynamic-radio-comms-and-podium-standees-design.md)
- Implementation Plan: [`docs/superpowers/plans/2026-10-23-dynamic-radio-comms-and-podium-standees-plan.md`](file:///D:/Occupation/Porto/genex/La_Voiture/docs/superpowers/plans/2026-10-23-dynamic-radio-comms-and-podium-standees-plan.md)
- Character Roster: [`reference-assets/characters/DRIVER-CHARACTERIZATION-ROSTER.md`](file:///D:/Occupation/Porto/genex/La_Voiture/reference-assets/characters/DRIVER-CHARACTERIZATION-ROSTER.md)

---

## 1. Context & Objectives

In Fase 8.4, you will implement:
1. **Dynamic Radio Comms Overhaul:**
   - Keep the dual-dock comic banner architecture (`AnimeRadioCutin` on Layer 3).
   - Add procedural **Manga Soundwave Equalizer** animation (`_draw_manga_soundwave`) that pulses actively during transmission.
   - Dynamically load authentic driver 2D portraits from `reference-assets/characters/<team>/<driver>/radio_portrait.png` using `GarageRoster.portrait_path(car.id)` in `race_hud.gd`.
   - Implement frequent, high-drama driver comms triggers in `gt_driving.gd` / `gt_race.gd`:
     - Overtake made ("Pass made on %s! Clean move down the inside!")
     - Being overtaken / defending ("Lost the spot to %s! Defending now!")
     - ERS boost deployment ("Deploying ERS boost! Maximum attack!")
     - Tire cliff / cooked tires ("Tyres are cooked! Rear is sliding everywhere!")
     - Tire puncture ("Puncture! Tyre is shredded, limping to pits!")
     - Collision contact ("We touched with %s! Check the telemetry!")
   - Cooldown management: 15-second debounce cooldown per car for non-urgent driver calls to maintain high frequency without UI spam.
   - Update audio lines in `tools/audio/radio_lines.mjs` and `manifest.json`, including female voice for Freja Berg (`af_bella` / `af_nicole`).
2. **2D Podium Character Standee Banners:**
   - In `scripts/ui/podium_screen.gd`, replace flat text cards above the 3 steps with stylized **2D Character Standees**:
     - Neo-brutalist card standee ($360\text{px} \times 240\text{px}$) with 4px ink border, 6px offset shadow, and team livery styling.
     - 2D character portrait loaded from `GarageRoster.portrait_path(car.id)`.
     - Championship Laurel & Tier Badges: Gold for P1 Champion, Silver for P2 Runner-Up, Bronze for P3 Podium.
     - Staggered entrance animation: P3 slides up at $t = 0.0\text{s}$, P2 at $t = 0.2\text{s}$, P1 at $t = 0.4\text{s}$, followed by trophy and confetti storm.
3. **Automated Verification:**
   - Create `tests/test_radio_and_podium.gd` and ensure 100% PASS across all 24 test suites (`tests/test_*.gd`).

---

## 2. Step-by-Step Execution Guide

### Step 1: Create Headless Test Suite
- Write `tests/test_radio_and_podium.gd` verifying:
  1. `GarageRoster.portrait_path(i)` resolves valid files for all 20 driver slots.
  2. `AnimeRadioCutin` enables and disables `soundwave_active` state.
  3. `GtRace.can_push_driver_radio(car_id)` correctly enforces the 15-second debounce.
  4. `PodiumScreen` constructs 3 standee cards with valid portrait textures, placement numbers, and tier badges.
- Run: `godot --headless --path . -s tests/test_radio_and_podium.gd`

### Step 2: Implement Manga Soundwave in `scripts/ui/anime_radio_cutin.gd`
- Add `soundwave_active: bool = false` and `_soundwave_time: float = 0.0`.
- In `_process(delta)`: when active, advance time and call `_backdrop.queue_redraw()`.
- Implement `_draw_manga_soundwave(w: float, h: float)`:
  - 14 vertical bars drawn near the speech area.
  - Bar height modulated by multiple sine harmonics.
  - Black ink borders (`T.INK_BORDER_BLACK`) and accent color fill.
  - Exponential decay when idle.
- In `_play()`: activate soundwave.
- In `_hide_banner()`: deactivate soundwave.

### Step 3: Dynamic Driver Portrait in `scripts/hud/race_hud.gd`
- In `_on_radio(message: Dictionary)`:
  - If `message["speaker"] == "driver"` and `car != null`:
    - `var path := GarageRoster.portrait_path(car.id)`
    - `if ResourceLoader.exists(path): cut_in.set_portrait(load(path))`
  - If `message["speaker"] == "engineer"`:
    - `cut_in.set_portrait(ENGINEER_PORTRAIT)`

### Step 4: High-Drama Driver Event Triggers & Cooldown
- In `scripts/gt/gt_race.gd`:
  - Add `driver_radio_cooldown: Dictionary = {}`
  - Add `can_push_driver_radio(car_id: int) -> bool`
  - In `_process_tick(dt)`: decrement cooldowns.
  - In `push_radio(car, speaker, text, urgent)`: set cooldown to `15.0` for non-urgent driver calls.
- In `scripts/gt/gt_driving.gd`:
  - Hook overtakes (both passing car and passed car).
  - Hook ERS boost deployment.
  - Hook tire cliff (>75% wear) and blowout/puncture (>96% wear).
- In `scripts/gt/gt_contacts.gd`:
  - Hook contact messages with driver urgent calls.

### Step 5: Update Radio Voice Lines & Manifest
- In `tools/audio/radio_lines.mjs`:
  - Add regex patterns for new driver calls.
  - Support female voice selection (`af_bella` / `af_nicole`) for Freja Berg.
- In `assets/audio/radio/voice/manifest.json`:
  - Add entries mapping the new patterns to audio files.

### Step 6: 2D Character Standees on `PodiumScreen`
- In `scripts/ui/podium_screen.gd`:
  - Implement `_build_character_standee(place: int, car: GtCar) -> Control`.
  - Assemble neo-brutalist panel with driver portrait (`GarageRoster.portrait_path(car.id)`), team colors, driver name, car number, and Gold/Silver/Bronze championship tier ribbons.
  - Add staggered slide-up animation in `present(race)`.

### Step 7: Run Full Verification Suite & Write Executive Report
- Run all test suites:
  `Get-ChildItem tests\test_*.gd | ForEach-Object { godot --headless --path . -s ("res://tests/" + $_.Name) }`
  Confirm: **24/24 PASS, 0 FAIL**.
- Write completion report to `executor-report/reports/FASE-8.4-DYNAMIC-RADIO-AND-PODIUM-REPORT.md`.
- Update `ROADMAP.md`.

---

## 3. Strict Quality & Architectural Rules
1. **Never delete or overwrite existing assets** not authored by you.
2. **Never place `.gdignore` in `reference-assets/`**.
3. **Never alter `Curve3D` spline points in `scenes/race_world/track_circuit.tscn`**.
4. **All 24 test suites must pass 100%**.
5. **Always preserve 0 orphan nodes** upon exiting to Main Menu.
