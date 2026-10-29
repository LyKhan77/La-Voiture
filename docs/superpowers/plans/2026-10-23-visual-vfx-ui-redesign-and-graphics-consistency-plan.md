# Visual Polish, Brutal Graffiti VFX, Concept 01 UI, and Graphics Consistency Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Overhaul vehicle lighting (purge floating sphere lamps, implement reactive brake lights), implement brutal NFS Unbound-style anime VFX (speedlines, boost warp, kerb strike sparks, backfire flames), redesign the Main Menu to Concept 01 (Street Tag & Speed Stencil), and unify visual consistency between the paddock garage and in-game race cars.

**Architecture:** 
1. In `scripts/vfx/race_vfx.gd`, remove primitive `SphereMesh` lenses, and in `scripts/car/gt_car_actor.gd`, wire real mesh emissive taillights and reactive brake lights.
2. In `scripts/hud/race_hud.gd` and `shaders/manga_speedlines.gdshader`, hook dynamic speedlines to $>240\text{ km/h}$ and ERS Boost with camera FOV kick.
3. In `scripts/vfx/race_vfx.gd`, add `GPUParticles3D` kerb strike sparks and 2-frame graffiti backfire flames.
4. In `scripts/ui/main_menu.gd`, redesign the title screen with a -12° slanted stencil title, spray paint halo, and parallelogram buttons with snap hover.
5. In `scripts/world/garage/garage_environment_builder.gd`, apply `toon_car_paint.gdshader` and inverted-hull ink outlines to showroom cars to match in-race rendering.

**Tech Stack:** Godot Engine 4.7.2 stable (GDScript 2.0, Forward+ Renderer, Shading Language `.gdshader`, GPU Particles 3D).

---

## File Structure & Responsibilities

| File Path | Responsibility |
| :--- | :--- |
| `scripts/vfx/race_vfx.gd` | Particle systems coordinator: kerb sparks, backfire flames, removal of primitive SphereMesh lamps. |
| `scripts/car/gt_car_actor.gd` | Vehicle 3D actor: reactive brake light emissive modulation, brake rotor glow. |
| `scripts/hud/race_hud.gd` | In-game HUD: canvas speedlines overlay and camera FOV punch during ERS Boost. |
| `shaders/manga_speedlines.gdshader` | Full-screen radial ink speedlines canvas item shader. |
| `scripts/ui/main_menu.gd` | Title screen: Concept 01 -12° stencil title, spray paint halo, parallelogram buttons. |
| `scripts/world/garage/garage_environment_builder.gd` | 10-stall paddock showroom: unified toon car paint shader and inverted-hull ink line art. |
| `scripts/core/presentation_settings.gd` | Graphics presets synchronization (outline width, shadow distance, halftone alpha, VFX ratio). |
| `tests/test_visual_polish_and_consistency.gd` | Headless test suite validating lighting, VFX, UI geometry, and visual pipeline consistency. |

---

## Tasks

### Task 1: Create Headless Test Suite for Visual Polish & Consistency

**Files:**
- Create: `tests/test_visual_polish_and_consistency.gd`

- [ ] **Step 1: Write test suite covering lighting, VFX triggers, UI slant, and showroom materials**
  Write tests in `tests/test_visual_polish_and_consistency.gd`:
  - `test_no_spheremesh_headlights()`: Instantiates `RaceVfx`, verifies that no `SphereMesh` lamps are spawned as children of cars.
  - `test_reactive_brake_lights()`: Instantiates `GtCarActor`, simulates braking (`car.brake = 1.0`), and verifies taillight emission energy rises to $\ge 5.0$.
  - `test_manga_speedlines_trigger()`: Verifies that speedlines intensity is $0.0$ at rest and rises to $>0.5$ when speed exceeds $66.7\text{ m/s}$ ($240\text{ km/h}$) or during `ErsMode.OVERTAKE`.
  - `test_main_menu_concept_01_styling()`: Instantiates `MainMenu`, asserts brand title has a $-12^\circ$ slant (`rotation = -0.21`), asserts menu buttons have parallelogram styling and speed prefix `"///"`.
  - `test_garage_showroom_toon_consistency()`: Instantiates `GarageEnvironmentBuilder`, builds 1 stall, verifies that the showroom car possesses a `ShaderMaterial` with toon shading and inverted-hull outline rather than unshaded `StandardMaterial3D`.

- [ ] **Step 2: Run test suite to verify current failures**
  Run: `godot --headless --path . -s res://tests/test_visual_polish_and_consistency.gd`
  Expected: FAIL on SphereMesh check (still present in `race_vfx.gd`), Main Menu styling, and showroom material checks.

- [ ] **Step 3: Commit initial test suite**
  ```bash
  git add tests/test_visual_polish_and_consistency.gd
  git commit -m "test: add test suite for visual polish, VFX, Concept 01 UI, and showroom consistency"
  ```

---

### Task 2: Purge SphereMesh Lamps & Implement Reactive Real Mesh Taillights

**Files:**
- Modify: `scripts/vfx/race_vfx.gd`
- Modify: `scripts/car/gt_car_actor.gd`

- [ ] **Step 1: Remove primitive `SphereMesh` lamps in `scripts/vfx/race_vfx.gd`**
  - Delete lines 241-255 in `race_vfx.gd` where `var lens := SphereMesh.new()` is created and added to `head_lights[id]`.
  - Update `_update_car_effects()` to remove logic referencing `head_lights[id]` mesh visibility.
  - If headlights forward ground lighting is needed in night/rain, create a pair of `SpotLight3D` nodes per car with `shadow_enabled = false`, `spot_range = 45.0`, `spot_angle = 32.0`, and energy `2.2` (night) / `0.0` (day).

- [ ] **Step 2: Implement reactive taillights and brake lighting in `scripts/car/gt_car_actor.gd`**
  - In `gt_car_actor.gd`, add:
    ```gdscript
    var _taillight_mat: StandardMaterial3D
    var _taillight_energy: float = 0.0
    ```
  - Locate taillight geometry on `chassis` or create a dynamic rear light ribbon/quad at the rear socket.
  - In `_process_visuals(dt)`:
    ```gdscript
    var is_braking: bool = car.brake > 0.05 or car.longitudinal_g < -0.5
    var target_energy: float = 6.5 if is_braking else (1.2 if (race != null and (race.is_night or race.weather.track_water_pct > 20.0)) else 0.0)
    _taillight_energy = move_toward(_taillight_energy, target_energy, dt * 18.0)
    if _taillight_mat != null:
        _taillight_mat.emission_energy_multiplier = _taillight_energy
    ```

- [ ] **Step 3: Run test to verify lighting changes**
  Run: `godot --headless --path . -s res://tests/test_visual_polish_and_consistency.gd`
  Expected: `test_no_spheremesh_headlights()` and `test_reactive_brake_lights()` PASS.

- [ ] **Step 4: Commit lighting changes**
  ```bash
  git add scripts/vfx/race_vfx.gd scripts/car/gt_car_actor.gd
  git commit -m "fix(vfx): purge primitive SphereMesh lamps and implement reactive real mesh taillights"
  ```

---

### Task 3: Implement Brutal Manga Speedlines & Boost Warp Camera Punch

**Files:**
- Modify: `scripts/hud/race_hud.gd`
- Reference: `shaders/manga_speedlines.gdshader`

- [ ] **Step 1: Wire Speedlines Canvas Overlay in `scripts/hud/race_hud.gd`**
  - In `_build_stage()` in `race_hud.gd`, create a full-screen `ColorRect` named `MangaSpeedlines` on CanvasLayer 5.
  - Assign a `ShaderMaterial` loading `res://shaders/manga_speedlines.gdshader`.
  - Set `mouse_filter = MOUSE_FILTER_IGNORE`.

- [ ] **Step 2: Drive speedlines intensity dynamically based on speed and ERS Boost**
  - In `_process_hud(delta)` in `race_hud.gd`:
    ```gdscript
    var followed: GtCar = race.get_car(followed_car_id)
    if followed != null:
        var speed_kmh: float = followed.v * 3.6
        var speed_factor: float = clampf((speed_kmh - 220.0) / 70.0, 0.0, 1.0)
        var boost_factor: float = 1.0 if followed.ers_mode == GtTypes.ErsMode.OVERTAKE else 0.0
        var intensity: float = maxf(speed_factor, boost_factor)
        speedlines_rect.visible = intensity > 0.02
        if speedlines_rect.visible:
            speedlines_mat.set_shader_parameter("line_color", Color(0.04, 0.04, 0.06, 0.75 * intensity))
    ```

- [ ] **Step 3: Implement Boost Warp Camera Punch**
  - In `_on_ers_mode_changed(car_id: int, new_mode: int)`:
    - If `car_id == followed_car_id` and `new_mode == GtTypes.ErsMode.OVERTAKE`:
      - Animate camera FOV: $+3.5^\circ$ kick in $0.08\text{ s}$ via `Tween.TRANS_EXPO`, easing back to default $42.0^\circ$ over $0.35\text{ s}$.

- [ ] **Step 4: Run test to verify speedlines**
  Run: `godot --headless --path . -s res://tests/test_visual_polish_and_consistency.gd`
  Expected: `test_manga_speedlines_trigger()` PASS.

- [ ] **Step 5: Commit speedlines & boost warp**
  ```bash
  git add scripts/hud/race_hud.gd
  git commit -m "feat(vfx): implement screen-space manga speedlines and boost warp camera punch"
  ```

---

### Task 4: Implement Kerb Strike Sparks & Graffiti Exhaust Backfire Flames

**Files:**
- Modify: `scripts/vfx/race_vfx.gd`

- [ ] **Step 1: Add Kerb Strike Spark Particles in `scripts/vfx/race_vfx.gd`**
  - For each car in `_build_car_effects()`, create a `GPUParticles3D` node named `KerbSparks`.
  - Configure particle material:
    - Particle amount: 18.
    - Initial velocity: $14.0\text{ m/s}$ spreading backward and outward.
    - Gravity: Vector3(0, -9.8, 0).
    - Lifetime: $0.22\text{ s}$.
    - Material: Additive unshaded quad with `T.ACCENT_ACID_LIME` and spark orange.
  - In `_update_car_effects()`:
    - Trigger emission when `car.v > 35.0` ($>126\text{ km/h}$) and lateral displacement $|car.d| > 2.8\text{ m}$ (clipping sawtooth kerbs).

- [ ] **Step 2: Upgrade Exhaust Backfire Flames to 2-Tone Comic Burst**
  - In `race_vfx.gd:223-240`:
    - Replace the simple monochrome cylinder with an anime graffiti flame burst mesh (crimson core `#FF1A4B`, acid yellow tip `#D8FF00`).
    - Modulate rotation and scale slightly on each downshift to create organic hand-drawn variation.

- [ ] **Step 3: Run test to verify kerb sparks and backfire**
  Run: `godot --headless --path . -s res://tests/test_visual_polish_and_consistency.gd`
  Expected: PASS.

- [ ] **Step 4: Commit kerb sparks & backfire upgrades**
  ```bash
  git add scripts/vfx/race_vfx.gd
  git commit -m "feat(vfx): add kerb strike sparks and 2-tone graffiti exhaust backfire flames"
  ```

---

### Task 5: Implement Main Menu Redesign (Concept 01: Street Tag & Speed Stencil)

**Files:**
- Modify: `scripts/ui/main_menu.gd`
- Modify: `scenes/ui/main_menu.tscn`

- [ ] **Step 1: Redesign Title Typography & Spray Paint Halo**
  - In `scripts/ui/main_menu.gd:_build_stage()`:
    - Replace the basic horizontal `BrandTitle` label with a multi-layered stencil layout slanted at $-12^\circ$ (`rotation = -0.21`).
    - Create a custom `SprayHalo` node behind the title rendering two blurred radial gradient circles:
      - Inner core: `Color("#D8FF00", 0.40)`.
      - Outer halo: `Color("#FF1A4B", 0.22)`.
    - Add hand-drawn street marker subtag: `"/// GT3 // RACING SYNDICATE // TOON MOTORSPORT"`.

- [ ] **Step 2: Redesign Parallelogram Buttons with Snap Hover Inversion**
  - In `_menu_button(text, accent, y)`:
    - Construct button with a $-12^\circ$ horizontal skew.
    - Add 4px solid black ink border (`T.INK_BORDER_BLACK`) and 6px solid offset drop shadow.
    - Prefix button label with triple speed slash `"/// "` in `T.ACCENT_ACID_LIME`.
    - Wire `mouse_entered` and `mouse_exited` signals:
      - On Hover: Translate $+6\text{px}, -2\text{px}$, flip background to solid `T.ACCENT_ACID_LIME`, text to pitch black, and drop shadow to `T.ACCENT_ANIME_CRIMSON`.
      - On Exit: Smoothly restore normal state.

- [ ] **Step 3: Redesign Modal Dialog Topology**
  - Update `_dialog` styling to use a $-4^\circ$ angled inspection tag geometry with 4px ink borders and crimson corner header badges (`"SYS // CONFIG"`).

- [ ] **Step 4: Run test to verify Concept 01 Main Menu styling**
  Run: `godot --headless --path . -s res://tests/test_visual_polish_and_consistency.gd`
  Expected: `test_main_menu_concept_01_styling()` PASS.

- [ ] **Step 5: Commit Main Menu redesign**
  ```bash
  git add scripts/ui/main_menu.gd scenes/ui/main_menu.tscn
  git commit -m "feat(ui): redesign main menu to Concept 01 Street Tag & Speed Stencil"
  ```

---

### Task 6: Unify Visual Consistency Between Paddock Showroom & In-Game Race Cars

**Files:**
- Modify: `scripts/world/garage/garage_environment_builder.gd`
- Modify: `scripts/core/presentation_settings.gd`

- [ ] **Step 1: Update `garage_environment_builder.gd` to load Toon Shaded Chassis**
  - In `_instantiate_car(team: int)`:
    - Stop loading raw `*_full.glb` with unshaded `StandardMaterial3D`.
    - Use `gt_car_actor.gd`'s `CHASSIS_BY_TEAM` mapping to load the modular chassis scenes (`*_chassis.tscn` or `base_chassis.tscn`).
    - For each car body mesh, apply `shaders/toon_car_paint.gdshader` with team livery color tint.
    - Attach the inverted-hull outline pass with width driven by `PresentationSettings.OUTLINE_WIDTH[quality]`.

- [ ] **Step 2: Synchronize Graphics Presets across both Showroom and Race**
  - In `PresentationSettings.apply_to_tree()`:
    - Ensure traversal updates outline width, halftone screentone alpha, and shadow parameters across both `ShowroomStall` and `RaceWeekendWorld`.

- [ ] **Step 3: Run test to verify showroom toon consistency**
  Run: `godot --headless --path . -s res://tests/test_visual_polish_and_consistency.gd`
  Expected: `test_garage_showroom_toon_consistency()` PASS.

- [ ] **Step 4: Commit showroom visual consistency**
  ```bash
  git add scripts/world/garage/garage_environment_builder.gd scripts/core/presentation_settings.gd
  git commit -m "feat(graphics): unify showroom cars with cel-shaded toon paint and inverted-hull ink outline"
  ```

---

### Task 7: Full 25-Suite Regression Verification & Executive Documentation

**Files:**
- Test: All 25 test suites in `tests/test_*.gd`
- Create: `executor-report/reports/FASE-8.5-VISUAL-POLISH-AND-UI-REDESIGN-REPORT.md`
- Update: `ROADMAP.md`

- [ ] **Step 1: Execute all 25 test suites headless**
  Run: `powershell -Command "Get-ChildItem tests\test_*.gd | ForEach-Object { $out = godot --headless --path . -s ('res://tests/' + $_.Name) 2>&1; if ($LASTEXITCODE -ne 0) { Write-Host ('[FAIL] ' + $_.Name) } else { Write-Host ('[PASS] ' + $_.Name) } }"`
  Expected: **25/25 PASS (0 FAIL)**.

- [ ] **Step 2: Author Executive Completion Report**
  Write `executor-report/reports/FASE-8.5-VISUAL-POLISH-AND-UI-REDESIGN-REPORT.md` documenting:
  - Removal of SphereMesh lamps and reactive brake light metrics.
  - Manga speedlines, boost warp, kerb sparks, and backfire flame benchmarks.
  - Main Menu Concept 01 visual topology and interactive hover parameters.
  - Showroom vs race car visual pipeline unification proof.
  - 25-suite headless test verification log.

- [ ] **Step 3: Update Roadmap**
  Mark Fase 8.5 as Complete in `ROADMAP.md`.

- [ ] **Step 4: Commit and push final release**
  ```bash
  git add .
  git commit -m "feat(release): complete Fase 8.5 visual polish, graffiti VFX, Concept 01 UI, and graphics consistency"
  git push
  ```
