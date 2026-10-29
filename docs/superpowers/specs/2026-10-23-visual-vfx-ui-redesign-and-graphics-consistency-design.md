# Comprehensive Design Specification: Fase 8.5 — Visual Polish, Brutal Graffiti VFX, Concept 01 UI Redesign, and Graphics Pipeline Consistency

**Status:** APPROVED FOR IMPLEMENTATION  
**Target Engine:** Godot Engine 4.7.2 stable  
**Author:** Antigravity Architect  
**Date:** 2026-10-23  

---

## 1. Executive Summary & Vision

This specification defines the comprehensive overhaul of *La Voiture*'s visual identity, lighting realism, in-race particle dynamics, and main menu presentation. While the deterministic simulation engine, AI strategy desk, and track geometry have achieved solid benchmarks (24/24 test suites passing), recent player evaluation identified four critical aesthetic and immersion deficits:

1. **Unrealistic Floating Light Artifacts:** In-race cars currently display floating, glowing `SphereMesh` spheres as headlights, breaking immersion.
2. **Underpowered Visual FX:** The racing experience lacks the brutal, high-impact comic energy characteristic of *Need for Speed Unbound*, *Spider-Verse*, and *Initial D*.
3. **Underwhelming Main Menu Presentation:** The title screen is composed of standard horizontal Anton text and generic grey buttons, failing to communicate the "Speed, Soul, and Screentone" neo-brutalist manga ethos.
4. **Visual Disconnect Between Paddock and Race:** Showroom cars in the 10-stall paddock appear metallic and photorealistic (standard PBR GLB), whereas in-race cars appear cel-shaded manga toon (custom shader + inverted-hull outline), creating an inconsistent visual language.

This specification details the mathematical models, shader configurations, scene topologies, and procedural generation scripts required to resolve all four issues cleanly.

---

## 2. Technical Architecture & Component Breakdown

```
+-------------------------------------------------------------------------------------------------------------+
|                                    LA VOITURE FASE 8.5 SYSTEM ARCHITECTURE                                  |
+-------------------------------------------------------------------------------------------------------------+
                                                       |
         +-----------------------------+---------------+-----------------------------+
         |                             |                                             |
         v                             v                                             v
+-----------------------------+ +-----------------------------+ +---------------------------------------------+
|  1. VEHICLE LIGHTING & ENV  | |  2. BRUTAL GRAFFITI VFX     | |  3. CONCEPT 01 UI & GRAPHICS CONSISTENCY    |
+-----------------------------+ +-----------------------------+ +---------------------------------------------+
| * Purge SphereMesh Lenses   | | * Manga Speedlines Canvas   | | * Main Menu Concept 01 (-12° Skew Stencil)  |
| * Real Emissive Mesh Lights | | * Boost Warp FOV Punch      | | * Spray Paint Halo & Triple Slash '///'     |
| * Reactive Brake Light Glow | | * Brake Rotor Thermal Glow  | | * Unified Toon Car Shader in Showroom       |
| * Natural Track Spotlights  | | * Kerb Strike GPU Sparks    | | * Synchronized Presets (Low -> Ultra)       |
|                             | | * Downshift Backfire Flames | | * Zero Regression 25-Suite Test Gate        |
+-----------------------------+ +-----------------------------+ +---------------------------------------------+
```

---

### Component 1: Vehicle Lighting Realism & Environment Integration

#### A. Root Cause Analysis
In `scripts/vfx/race_vfx.gd:241-255`, the current implementation spawns primitive sphere meshes for every car:
```gdscript
var lens := SphereMesh.new()
lens.radius = 0.1
lens.height = 0.2
lamp.mesh = lens
lamp.material_override = _head_on
lamp.position = offset
actor.add_child(lamp)
```
These floating spheres remain static in world space relative to the bumper, rendering as opaque glowing orbs that obscure car geometry and destroy visual realism.

#### B. Architectural Solution
1. **Purge SphereMesh Generation:**
   - In `scripts/vfx/race_vfx.gd`, remove the `SphereMesh` lens creation inside `_build_car_effects()`.
   - Deprecate `head_lights` dictionary references or repurpose them strictly for non-mesh `SpotLight3D` nodes.
2. **Actual Car Mesh Lighting (Headlights & Taillights):**
   - The car chassis meshes (`*_body.glb`) possess distinct surface slots for lights or forward lens geometry.
   - For headlights: In night or rain conditions, apply an emissive material property to the existing headlight surface polygon (`Color("#EAF2FF")` at energy `3.0`).
   - For forward ground illumination: Attach a pair of `SpotLight3D` nodes per car with:
     - `spot_range = 45.0` meters
     - `spot_angle = 32.0` degrees
     - `light_color = Color("#EAF2FF")`
     - `light_energy = 2.2` (night) / `1.4` (monsoon) / `0.0` (day)
     - `shadow_enabled = false` (to prevent draw call spikes)
3. **Reactive Taillights & Dynamic Brake Light Modulation:**
   - Tail clusters on `GtCarActor` are tracked via a dedicated material override (`taillight_mat`).
   - Baseline State: At night or during rain, taillight emits soft neon red (`Color("#FF1A4B")` at energy `1.2`).
   - Reactive Braking State: In `gt_car_actor.gd:_process_visuals(dt)`:
     ```gdscript
     var is_braking: bool = car.brake > 0.05 or car.longitudinal_g < -0.5
     var target_energy: float = 6.5 if is_braking else (1.2 if (race.is_night or race.weather.track_water_pct > 20.0) else 0.0)
     _taillight_energy = move_toward(_taillight_energy, target_energy, dt * 18.0)
     _taillight_mat.set_shader_parameter("emission_energy", _taillight_energy)
     ```
   - This produces an instantaneous, snappy brake light flash whenever the driver steps on the brakes into a corner.

---

### Component 2: Brutal Toon Anime $\times$ Graffiti VFX Suite (Ref: *Need for Speed Unbound*)

#### A. Screen-Space Manga Speedlines (`shaders/manga_speedlines.gdshader`)
* **Layer Topology:** Placed on a full-screen `ColorRect` on CanvasLayer 5 (Z: 40) inside `scripts/hud/race_hud.gd`.
* **Mathematical Model:**
  - Shader uniforms: `line_color = vec4(0.04, 0.04, 0.06, 0.75)`, `ray_count = 72.0`, `inner = 0.35`, `outer = 0.95`.
  - Driven dynamically by car velocity:
    ```gdscript
    var speed_kmh: float = car.v * 3.6
    var speed_factor: float = clampf((speed_kmh - 220.0) / 70.0, 0.0, 1.0)
    var boost_factor: float = 1.0 if car.ers_mode == GtTypes.ErsMode.OVERTAKE else 0.0
    var intensity: float = maxf(speed_factor, boost_factor)
    speedlines_rect.material.set_shader_parameter("line_color", Color(0.04, 0.04, 0.06, 0.8 * intensity))
    speedlines_rect.visible = intensity > 0.02
    ```
* **Boost Warp Camera Punch:**
  - When `car.ers_mode` switches to `OVERTAKE`, trigger a camera tween:
    - Kick Camera FOV: $42.0^\circ \rightarrow 45.5^\circ$ in $0.08\text{ s}$ (`TRANS_EXPO`, `EASE_OUT`).
    - Smoothly return to $42.0^\circ$ over $0.35\text{ s}$ (`TRANS_QUAD`, `EASE_IN_OUT`).

#### B. Incandescent Brake Rotor Thermal Glow
* In `scripts/car/gt_car_actor.gd` and `wheel_controller.gd`:
  - Rotors begin glowing at deceleration $> 1.5\text{ G}$ (`BRAKE_GLOW_G = 1.5`).
  - Target glow ramps up to $1.0$ at $> 3.0\text{ G}$.
  - Color gradient: Ramps from dark gunmetal (`#2B2D33`) $\rightarrow$ deep cherry red (`#D62828`) $\rightarrow$ incandescent thermal orange-yellow (`#FFD166`).
  - Cooling curve: Exponential decay at rate $1.2\text{ s}^{-1}$ (`BRAKE_GLOW_FALL = 1.2`).

#### C. Kerb Strike Manga Sparks (`scripts/vfx/race_vfx.gd`)
* Spawn a `GPUParticles3D` system attached to each car (`kerb_sparks[id]`):
  - Amount: 18 particles.
  - Lifetime: $0.25\text{ s}$.
  - Emission shape: Point near bottom outer tire lip ($y = 0.02\text{ m}, x = \pm 0.92\text{ m}$).
  - Particle Mesh: Elongated quad streak ($0.03\text{ m} \times 0.22\text{ m}$) aligned to velocity.
  - Material: Unshaded additive glow with `T.ACCENT_ACID_LIME` (`#D8FF00`) and intense spark orange (`#FFAA00`).
  - Trigger: Activated when `car.v > 35.0` ($> 126\text{ km/h}$) and lateral offset $|car.d| > 2.8\text{ m}$ across curve sectors.

#### D. Downshift Exhaust Backfire Graffiti Flames
* Replaces the primitive cone in `race_vfx.gd:224-240` with an animated 2-step anime graffiti flame:
  - Outer geometry: Asymmetric stylized starburst / flame shape.
  - Core: Saturated crimson `#FF1A4B`, outer shell: bright acid yellow `#D8FF00`.
  - Trigger: Activated on gear downshift (`car.gear < _last_gear[id]`) for exactly $0.12\text{ s}$, accompanied by the dynamic audio backfire crackle.

---

### Component 3: Main Menu UI/UX Redesign (Concept 01: Street Tag & Speed Stencil)

#### A. Design Language Specifications
* **Primary Color Scheme:**
  - Canvas Deep: `#080A0F` (Dark Asphalt)
  - Primary Accent: `#D8FF00` (Acid Lime)
  - Secondary Accent: `#FF1A4B` (Anime Crimson)
  - Tertiary Accent: `#00F5D4` (Punk Cyan)
  - Border Ink: `#06070A` (Black Manga Ink, 4px)
* **Global Slant Angle:** $-12.0^\circ$ ($0.21\text{ rad}$) applied via `Transform2D(Vector2(1.0, 0.0), Vector2(-0.21, 1.0), Vector2.ZERO)`.

#### B. Title Stencil & Spray Halo Topology
* In `scripts/ui/main_menu.gd:_build_stage()`:
  1. **Spray Paint Halo:**
     - Behind the title, instantiate a custom `Control` (`SprayHalo`) with `_draw()` rendering two concentric radial gradient circles with alpha blur:
       - Inner core: `Color("#D8FF00", 0.40)` with radius 140px.
       - Outer bleeding halo: `Color("#FF1A4B", 0.22)` with radius 280px.
  2. **Title "LA VOITURE":**
     - Font: `Anton.ttf`, size 156pt.
     - Slanted $-12^\circ$.
     - Outline size: 14px, outline color: `T.INK_BORDER_BLACK`.
     - Multi-layer drop shadow: $+6\text{px}, +6\text{px}$ offset in `Color.BLACK`, $-3\text{px}, -1\text{px}$ offset in `T.ACCENT_ACID_LIME`.
  3. **Subtag Badge:**
     - Slanted label in `BarlowCondensed.ttf`: `"/// GT3 // RACING SYNDICATE // TOON MOTORSPORT"`.
     - Colored in `T.ACCENT_ELECTRIC_CYAN` with a 2px ink border.

#### C. Parallelogram Menu Buttons
* Replaces `_menu_button()` in `main_menu.gd`:
  - Node: `Button` subclassed or wrapped in a custom `Control` drawing a skewed polygon.
  - Dimensions: $620\text{px} \times 74\text{px}$.
  - Geometry: Parallelogram with $-12^\circ$ horizontal skew.
  - Border: 4px solid black ink (`T.INK_BORDER_BLACK`).
  - Shadow: $+6\text{px}, +6\text{px}$ solid drop shadow.
  - Prefix: Triple speed slash `"/// "` in `T.ACCENT_ACID_LIME`.
  - Normal State: Dark panel background `#141722`, text in `T.TEXT_PRIMARY` (`#F4F5F7`).
  - **Hover / Focus Animation State:**
    - Snappy spring translate: $\Delta x = +6\text{px}, \Delta y = -2\text{px}$.
    - Background flips instantaneously to solid `T.ACCENT_ACID_LIME`.
    - Text color flips to pitch black `T.INK_BORDER_BLACK`.
    - Drop shadow pops to vivid `T.ACCENT_ANIME_CRIMSON` with $+8\text{px}, +8\text{px}$ offset.
    - Plays audio click chirp.

#### D. Modal Dialog Topology (`SettingsModal`, `RaceSetupMenu`, Confirmations)
* Modals are framed as angled inspection tags:
  - Skew: $-4^\circ$ slight tilt.
  - Border: 4px solid black ink with $+8\text{px}, +8\text{px}$ solid black offset.
  - Header Tag: Stamped badge in `T.ACCENT_ANIME_CRIMSON` with white bold text (e.g., `"SYS // CONFIG"`, `"RACE // SETUP"`).
  - Background: Deep matte asphalt `#11141E` with subtle 5% halftone dot pattern.

---

### Component 4: Paddock vs Race Visual Pipeline Consistency

#### A. Problem Definition
Currently:
* In `scripts/world/garage/garage_environment_builder.gd:346-362`:
  ```gdscript
  var path: String = Roster.car_path(team) # -> assets/cars/<slug>/<slug>_full.glb
  var packed: PackedScene = load(path) as PackedScene
  ```
  The car instances are loaded directly from the unshaded `*_full.glb` GLTF scene using default `StandardMaterial3D`.
* In `scripts/car/gt_car_actor.gd:25-35`:
  ```gdscript
  const CHASSIS_BY_TEAM: Dictionary = {
      1: preload("res://scenes/car/audi_r8_chassis.tscn"),
      ...
  }
  ```
  In-race cars use modular chassis scenes with `shaders/toon_car_paint.gdshader` and inverted-hull ink outline meshes.
* Result: Showroom cars appear glossy, dark, and realistic; in-race cars appear cel-shaded manga toon.

#### B. Architectural Solution
1. **Unified Chassis Loading in Showroom:**
   - Modify `garage_environment_builder.gd` to load the exact same `CHASSIS_BY_TEAM` scenes (with fallback to `base_chassis.tscn`) or apply `toon_car_paint.gdshader` to the full GLB meshes.
   - For every car mesh instantiated in the showroom:
     - Apply `shaders/toon_car_paint.gdshader` with team livery color tint.
     - Attach the inverted-hull outline pass (`shaders/inverted_hull_outline.gdshader`) with outline width matching `PresentationSettings.OUTLINE_WIDTH[quality]`.
2. **Preset Scaling Synchronization:**
   - In `scripts/core/presentation_settings.gd`:
     Ensure `apply_to_tree()` traverses both the active race world AND the showroom garage world, updating:
     - `OUTLINE_WIDTH`: Low (`0.007m`), Medium (`0.012m`), High (`0.020m`), Ultra (`0.020m`).
     - `SHADOW_DISTANCE`: Low (`0m`), Medium (`70m`), High (`150m`), Ultra (`260m`).
     - `HALFTONE_ALPHA`: Low (`0.05`), Medium (`0.06`), High (`0.07`), Ultra (`0.07`).
     - `VFX_RATIO`: Low (`0.4`), Medium (`0.7`), High (`1.0`), Ultra (`1.0`).

---

## 3. Implementation Plan & Quality Assurance Gates

### DoD (Definition of Done)
1. **Zero SphereMesh Lenses:** No primitive sphere mesh lamps remain in `race_vfx.gd` or any vehicle scenes.
2. **Active Taillights & Brake Flash:** Taillights illuminate in wet/night and flash bright crimson during braking.
3. **Speedlines & Boost Warp:** Speedlines trigger dynamically at $>240\text{ km/h}$ and during ERS Boost with camera FOV punch.
4. **Concept 01 Main Menu:** Main menu implements -12° slanted stencil title, spray paint halo, and parallelogram buttons with snap hover.
5. **Paddock-to-Race Consistency:** Showroom cars exhibit the identical cel-shaded toon shading and inverted-hull ink outlines as in-game race cars.
6. **Automated Test Gate:** New test suite `tests/test_visual_polish_and_consistency.gd` passes 100%, and all 24 existing suites continue to pass (**25/25 PASS, 0 FAIL**).
7. **Performance Budget:** Locked 60 FPS ($\le 16.66\text{ ms}$) preserved on RTX 3050 Laptop / GTX 1660 hardware at 1080p High.
