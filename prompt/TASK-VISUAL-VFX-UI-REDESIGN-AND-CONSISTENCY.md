# TASK HANDOFF: Fase 8.5 — Visual Polish, Brutal Graffiti VFX, Concept 01 UI Redesign, and Graphics Consistency

**Branch/Target:** `main`  
**Engine:** Godot Engine 4.7.2 stable  
**Role:** Senior Graphics, VFX & UI Engineer  
**Reference Documents:**
- Design Spec: [`docs/superpowers/specs/2026-10-23-visual-vfx-ui-redesign-and-graphics-consistency-design.md`](file:///D:/Occupation/Porto/genex/La_Voiture/docs/superpowers/specs/2026-10-23-visual-vfx-ui-redesign-and-graphics-consistency-design.md)
- Implementation Plan: [`docs/superpowers/plans/2026-10-23-visual-vfx-ui-redesign-and-graphics-consistency-plan.md`](file:///D:/Occupation/Porto/genex/La_Voiture/docs/superpowers/plans/2026-10-23-visual-vfx-ui-redesign-and-graphics-consistency-plan.md)
- UI Concept Preview: [`temp/brainstorm/content/ui-5-concepts.html`](file:///D:/Occupation/Porto/genex/La_Voiture/temp/brainstorm/content/ui-5-concepts.html)

---

## 1. Context & Objectives

In Fase 8.5, you will implement:
1. **Vehicle Lighting Realism:**
   - Purge primitive `SphereMesh` glowing orbs from [`scripts/vfx/race_vfx.gd:241-255`](file:///D:/Occupation/Porto/genex/La_Voiture/scripts/vfx/race_vfx.gd#L241-L255).
   - In [`scripts/car/gt_car_actor.gd`](file:///D:/Occupation/Porto/genex/La_Voiture/scripts/car/gt_car_actor.gd), activate real mesh emissive surfaces for headlights and taillights.
   - Implement dynamic reactive brake lights: when `car.brake > 0.05` or deceleration $>0.5\text{G}$, taillight emission pulses to energy `6.5` with snappy attack.
   - Natural environment lighting: forward `SpotLight3D` cones illuminate asphalt in night/monsoon without floating ball primitives.
2. **Brutal Toon Anime $\times$ Graffiti VFX Suite (Ref: *Need for Speed Unbound*):**
   - **Manga Speedlines:** Screen-space canvas overlay using [`shaders/manga_speedlines.gdshader`](file:///D:/Occupation/Porto/genex/La_Voiture/shaders/manga_speedlines.gdshader) on CanvasLayer 5. Triggers when speed $>240\text{ km/h}$ or when `ErsMode.OVERTAKE` is engaged.
   - **Boost Warp FOV Punch:** When ERS Overtake activates, kick camera FOV $+3.5^\circ$ in $0.08\text{ s}$ and ease back over $0.35\text{ s}$.
   - **Brake Rotor Thermal Glow:** Piringan rem menyala oranye-merah saat deselerasi $>1.5\text{G}$ dan mendingin eksponensial.
   - **Kerb Strike Sparks:** `GPUParticles3D` memancarkan semburan percikan api manga kuning/oranye saat ban menghantam kerb bergerigi di kecepatan $>126\text{ km/h}$.
   - **Downshift Graffiti Backfire:** Letupan lidah api knalpot 2-tone (inti crimson `#FF1A4B`, ujung acid yellow `#D8FF00`) selama $0.12\text{ s}$ saat pergantian gigi turun.
3. **Main Menu UI/UX Redesign (Concept 01: Street Tag & Speed Stencil):**
   - Title "LA VOITURE": Tipografi Anton tebal miring $-12^\circ$ (`rotation = -0.21`), didukung semprotan radial spray paint halo (Acid Lime `#D8FF00` $\rightarrow$ Anime Crimson `#FF1A4B`), dan subtag marker `"/// GT3 // RACING SYNDICATE"`.
   - Tombol Menu: Geometri jajar genjang miring $-12^\circ$, border tinta hitam 4px, bayangan solid 6px, prefiks stencil `"/// "`. Animasi hover snap: translasi $(+6\text{px}, -2\text{px})$, inversi instan latar ke Acid Lime, teks ke hitam pekat, dan bayangan ke Anime Crimson.
   - Topologi Modal: Panel miring $-4^\circ$ beraksen tag stiker inspeksi dan bayangan tebal.
4. **Visual Graphics Pipeline Consistency (Paddock vs Race):**
   - Di [`scripts/world/garage/garage_environment_builder.gd`](file:///D:/Occupation/Porto/genex/La_Voiture/scripts/world/garage/garage_environment_builder.gd), ganti pemuatan GLB mentah unshaded dengan scene sasis modular (`*_chassis.tscn`) atau terapkan `toon_car_paint.gdshader` + inverted-hull ink outline yang sama persis dengan in-game race.
   - Pastikan preset grafis (Low s.d. Ultra) mengontrol ketebalan outline manga (0.007m s.d. 0.020m) dan halftone screentone secara seragam di garasi dan balapan.
5. **Automated Verification:**
   - Buat test suite baru [`tests/test_visual_polish_and_consistency.gd`](file:///D:/Occupation/Porto/genex/La_Voiture/tests/test_visual_polish_and_consistency.gd).
   - Pastikan seluruh 25 test suite headless berjalan **100% PASS (0 FAIL)**.

---

## 2. Step-by-Step Execution Guide

### Step 1: Create Headless Test Suite
- Write `tests/test_visual_polish_and_consistency.gd` verifying:
  1. `race_vfx.gd` spawns zero `SphereMesh` headlight lenses.
  2. `gt_car_actor.gd` modulates taillight emission to $\ge 5.0$ upon braking.
  3. `race_hud.gd` speedlines intensity exceeds $0.5$ at $>240\text{ km/h}$ or during ERS Boost.
  4. `main_menu.gd` brand title has $-12^\circ$ slant and buttons have `"/// "` prefix with hover stylebox.
  5. `garage_environment_builder.gd` car instances use toon paint shader with inverted-hull ink outlines.
- Run: `godot --headless --path . -s res://tests/test_visual_polish_and_consistency.gd`

### Step 2: Purge SphereMesh Lamps & Wire Reactive Real Mesh Taillights
- In `scripts/vfx/race_vfx.gd`: Delete lines 241-255 creating `SphereMesh` headlight lenses.
- In `scripts/car/gt_car_actor.gd`:
  - Locate or attach rear taillight geometry with `_taillight_mat`.
  - In `_process_visuals(dt)`: If braking or decelerating $>0.5\text{G}$, ramp emission to `6.5`; in night/rain resting at `1.2`; otherwise `0.0`.
- Verify ground lighting in night/rain uses soft `SpotLight3D` cones without physical spheres.

### Step 3: Implement Speedlines Canvas Overlay & Boost Warp Punch
- In `scripts/hud/race_hud.gd`:
  - Add full-screen `ColorRect` on CanvasLayer 5 with `shaders/manga_speedlines.gdshader`.
  - Drive intensity dynamically: scales above $220\text{ km/h}$ up to $290\text{ km/h}$ and hits $1.0$ during `ErsMode.OVERTAKE`.
  - In camera controller: when ERS Boost activates, tween camera FOV $+3.5^\circ$ in $0.08\text{ s}$ and ease back to $42.0^\circ$ over $0.35\text{ s}$.

### Step 4: Implement Kerb Strike Sparks & Graffiti Backfire Flames
- In `scripts/vfx/race_vfx.gd`:
  - Add `GPUParticles3D` for kerb strike sparks: bursts 18 elongated yellow/acid-lime streaks when $|car.d| > 2.8\text{ m}$ at speed $>35\text{ m/s}$.
  - Replace cylinder exhaust flame with a 2-tone graffiti flame mesh (crimson core `#FF1A4B`, acid yellow tip `#D8FF00`) that pops for $0.12\text{ s}$ on downshifts.

### Step 5: Implement Main Menu Concept 01 (Street Tag & Speed Stencil)
- In `scripts/ui/main_menu.gd`:
  - Title: Slant -12° (`rotation = -0.21`), Anton font, 14px black outline, layered drop shadow, and behind it, a custom `SprayHalo` node drawing radial blurred gradient circles (Acid Lime $\rightarrow$ Anime Crimson).
  - Subtag: `"/// GT3 // RACING SYNDICATE // TOON MOTORSPORT"`.
  - Buttons: Skew -12° parallelogram cards, 4px black ink border, 6px drop shadow, speed prefix `"/// "`.
  - Hover animation: Snap translate $(+6\text{px}, -2\text{px})$, background flips to solid Acid Lime, text flips to black, shadow flips to Crimson.
  - Modals: Angled cards (-4° slant) with inspection badges and 4px borders.

### Step 6: Unify Visual Consistency Between Paddock Showroom & Race
- In `scripts/world/garage/garage_environment_builder.gd`:
  - In `_instantiate_car()`: Apply `shaders/toon_car_paint.gdshader` and inverted-hull ink outline to the car meshes, matching `gt_car_actor.gd` and `scenes/car/*_chassis.tscn`.
- In `scripts/core/presentation_settings.gd`:
  - Ensure `apply_to_tree()` propagates `OUTLINE_WIDTH[quality]` and `HALFTONE_ALPHA[quality]` across both showroom and race world scenes.

### Step 7: Full 25-Suite Test Verification & Completion Report
- Run all test suites:
  `powershell -Command "Get-ChildItem tests\test_*.gd | ForEach-Object { $out = godot --headless --path . -s ('res://tests/' + $_.Name) 2>&1; if ($LASTEXITCODE -ne 0) { Write-Host ('[FAIL] ' + $_.Name) } else { Write-Host ('[PASS] ' + $_.Name) } }"`
  Confirm: **25/25 PASS, 0 FAIL**.
- Write executive report: `executor-report/reports/FASE-8.5-VISUAL-POLISH-AND-UI-REDESIGN-REPORT.md`.
- Save screenshot proofs in `executor-report/screenshots/phases/fase-8.5-*.png`.
- Update `ROADMAP.md`.

---

## 3. Strict Quality & Architectural Boundaries
1. **Never delete or overwrite existing assets** not authored by you.
2. **Never place `.gdignore` in `reference-assets/`**.
3. **Never alter `Curve3D` spline points in `scenes/race_world/track_circuit.tscn`**.
4. **All 25 test suites must pass 100%**.
5. **Always preserve 0 orphan nodes** upon exiting to Main Menu.
