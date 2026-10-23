# Design Specification: Fase 8.5 — Visual Polish, NFS Unbound Graffiti VFX, UI Redesign, and Graphics Consistency

**Status:** PENDING USER REVIEW  
**Target Engine:** Godot Engine 4.7.2 stable  
**Author:** Antigravity Architect  
**Date:** 2026-10-23  

---

## 1. Executive Summary

Following player evaluation of the vertical slice, this specification establishes an extensive visual, VFX, and UI overhaul. The goals are fourfold:
1. **Realistic Vehicle Lighting & Environment:** Remove immersion-breaking floating `SphereMesh` headlight balls, replacing them with authentic emissive surface textures and dynamic reactive taillights.
2. **Brutal Toon Anime $\times$ Graffiti VFX (Ref: *Need for Speed Unbound*):** Implement an aggressive visual effects suite including screen-space speedlines, boost warp FOV punch, incandescent brake rotor heat glow, kerb strike sparks, and downshift exhaust backfire flames.
3. **Main Menu UI/UX Redesign (Concept 01: Street Tag & Speed Stencil):** Re-architect the title screen and modal dialog topology into a high-energy neo-brutalist street aesthetic featuring -12° skewed parallelogram buttons, spray paint halo backdrops, and ink stencil cuts.
4. **Visual Pipeline Consistency (Paddock vs In-Game Race):** Unify the car rendering pipeline so that the 3D paddock/garage showroom and in-game race cars share the exact same cel-shaded toon paint shaders, inverted-hull ink line art, and graphics preset scaling.

---

## 2. Component Specifications

### A. Lighting Realism & Headlight/Taillight Overhaul

#### Problem
In `scripts/vfx/race_vfx.gd:241-255`, the current implementation generates primitive `SphereMesh` instances (`lens.radius = 0.1`, `lens.height = 0.2`) as glowing balls attached to the front of cars. This creates an unnatural, floating spherical artifact that undermines track realism.

#### Technical Solution
1. **Remove Primitive Sphere Meshes:**
   - Delete the `SphereMesh` lens instantiation from `race_vfx.gd`.
2. **Real Car Mesh Lighting:**
   - Headlight and taillight geometry on the actual car body (`*_body.glb` and `*_full.glb`) will use dedicated emissive shader overrides or material slots.
3. **Dynamic Reactive Taillights & Brake Lights:**
   - **Taillights (Always-On in Wet / Night):** Subtle red emission (`Color("#FF1A4B")` at energy `1.5`).
   - **Brake Lights (Reactive):** When `car.brake > 0.05` or during strong longitudinal deceleration ($-\text{longitudinal\_g} > 0.5\text{G}$), taillight emission pulses to full intensity (`Color("#FF1A4B")` at energy `6.0`).
4. **Environment Lighting Realism:**
   - At night and in rain, cars illuminate the tarmac via forward angled `SpotLight3D` projector cones (without physical mesh balls) casting soft volumetric shadows on the wet asphalt.

---

### B. Brutal Toon Anime $\times$ Graffiti VFX Suite

Inspired by *Need for Speed Unbound*, the visual effects will emphasize stylized comic line art and high-contrast graffiti energy:

```
+---------------------------------------------------------------------------------------+
|                       BRUTAL ANIME x GRAFFITI VFX MATRIX                              |
+---------------------------------------------------------------------------------------+
|  EFFECT               | TRIGGER CONDITION           | VISUAL REPRESENTATION           |
+-----------------------+-----------------------------+---------------------------------+
|  Manga Speedlines     | v > 240 km/h OR ERS Boost   | Procedural screen-edge ink lines|
|                       |                             | radiating inward + FOV snap     |
+-----------------------+-----------------------------+---------------------------------+
|  Boost Warp FOV       | ERS Overtake engaged        | Quick +3.5° camera FOV expand   |
|                       |                             | with chromatic aberration drift |
+-----------------------+-----------------------------+---------------------------------+
|  Brake Rotor Glow     | Deceleration > 1.5G         | Incandescent orange-red thermal |
|                       |                             | glow on wheel brake discs       |
+-----------------------+-----------------------------+---------------------------------+
|  Kerb Strike Sparks   | High-speed kerb impact      | Directional shower of manga     |
|                       | (abs(d) > 2.8m, v > 140km/h)| yellow/orange spark particles   |
+-----------------------+-----------------------------+---------------------------------+
|  Downshift Backfire   | car.gear < _last_gear       | Stylized 2-frame graffiti flame |
|                       |                             | burst from exhaust tips         |
+-----------------------+-----------------------------+---------------------------------+
```

1. **Manga Speedlines & Boost Warp:**
   - Implemented as a dedicated canvas layer shader (`shaders/speedlines.gdshader` or procedural `_draw` on `race_hud.gd`).
   - Density and stroke width dynamically scale with vehicle velocity above $66.7\text{ m/s}$ ($240\text{ km/h}$) and peak during `ErsMode.OVERTAKE`.
2. **Brake Rotor Glow:**
   - In `gt_car_actor.gd` and `wheel_controller.gd`, the brake rotor material transitions from dark metallic to incandescent `#FF4500` based on `brake_glow_for()`, cooling with exponential decay (`BRAKE_GLOW_FALL = 1.2/s`).
3. **Kerb Strike Sparks:**
   - A `GPUParticles3D` system emitting 12-16 elongated line particles with `T.ACCENT_ACID_LIME` and `#FFAA00` coloration, triggered when cars hop the +0.05m sawtooth kerb crests.
4. **Downshift Exhaust Pop:**
   - Replaces the primitive cylinder mesh with a comic-style graffiti flame puff that rotates slightly and fades in 0.12s.

---

### C. Main Menu UI/UX Redesign (Concept 01: Street Tag & Speed Stencil)

Based on user selection from the interactive visual companion, the Main Menu will be redesigned with the **Street Tag & Speed Stencil** aesthetic:

```
+---------------------------------------------------------------------------------------+
|  [STAGE 1920x1080]                                                                    |
|                                                                                       |
|   +---------------------------------------+                                           |
|   |   (Radial Spray Paint Halo)           |                                           |
|   |   LA VOITURE                          |  <- -12° Skewed Stencil Typography       |
|   |   /// GT3 SYNDICATE                   |  <- Hand-drawn marker subtag              |
|   +---------------------------------------+                                           |
|                                                                                       |
|   [ /// EXHIBITION RACE              ]    <- -12° Parallelogram Button                |
|   [ /// TEAM PADDOCK GARAGE          ]       * 4px solid ink border                   |
|   [ /// SYSTEM SETTINGS              ]       * 6px solid offset drop shadow           |
|   [ /// CREDITS                      ]       * Hover: Instant Acid Lime inversion,    |
|   [ /// QUIT TO DESKTOP              ]         Crimson drop shadow pop                |
|                                                                                       |
|   [ MODAL TOPOLOGY ]                                                                  |
|   -4° Skewed asymmetric cards, graffiti inspection tags, heavy ink borders.          |
+---------------------------------------------------------------------------------------+
```

1. **Title Typography & Spray Halo:**
   - Brand title rendered in Anton heavy display font with a permanent -12° forward slant.
   - Backed by a procedural radial spray paint glow (`Color(T.ACCENT_ACID_LIME, 0.45)` transitioning into `Color(T.ACCENT_ANIME_CRIMSON, 0.25)`).
   - Secondary marker subtag: `"/// GT3 // SYNDICATE // NEO-BRUTALIST PADDOCK"`.
2. **Menu Buttons:**
   - Slanted parallelogram geometry with 4px ink black border and 6px solid black drop shadow.
   - Prefixed with triple stencil slash `///` in Acid Lime.
   - **Hover / Focus Animation:**
     - Snappy +4px X, -2px Y translation punch.
     - Background flips to solid `T.ACCENT_ACID_LIME`.
     - Text flips to pitch black `T.INK_BORDER_BLACK`.
     - Shadow pops to vivid `T.ACCENT_ANIME_CRIMSON`.
     - Tonal click audio feedback on enter/press.
3. **Modal Dialog Topology (`SettingsModal`, `RaceSetupMenu`, Dialogs):**
   - Redesigned into asymmetric, angled inspection cards (-4° slant).
   - Accented with bright graffiti corner tags (`CONFIG // SYS`, `SETUP // GRID`) and bold drop shadows.

---

### D. Paddock vs In-Game Race Graphics Consistency

#### Problem
In `garage_environment_builder.gd:346-362`, showroom cars are loaded directly from `res://assets/cars/<slug>/<slug>_full.glb` using default Godot `StandardMaterial3D`. In contrast, in-game race cars in `gt_car_actor.gd` use modular chassis scenes (`*_chassis.tscn`) with custom `toon_car_paint.gdshader` and inverted-hull ink outline meshes. This causes the showroom cars to look dull, metallic, and photorealistic, while race cars look cel-shaded anime.

#### Technical Solution
1. **Unified Chassis Loading:**
   - Update `garage_environment_builder.gd` to load cars via the exact same `CHASSIS_BY_TEAM` mapping or apply `toon_car_paint.gdshader` to the full GLB surface.
   - Attach the standard inverted-hull outline mesh with `PresentationSettings.OUTLINE_WIDTH[quality]` to all garage showroom cars.
2. **Graphics Preset Propagation:**
   - Ensure `PresentationSettings.apply_to_tree()` correctly propagates to both the garage showroom and in-game race environments:
     - **LOW:** Outline width `0.007m`, shadows disabled, halftone alpha `0.05`, VFX ratio `0.4`.
     - **MEDIUM:** Outline width `0.012m`, shadows `70m`, halftone alpha `0.06`, VFX ratio `0.7`.
     - **HIGH:** Outline width `0.020m`, shadows `150m`, halftone alpha `0.07`, VFX ratio `1.0`.
     - **ULTRA:** Outline width `0.020m`, shadows `260m` (soft blur 2.0), halftone alpha `0.07`, VFX ratio `1.0`.

---

## 3. Verification & Quality Gates

1. **Automated Headless Test Suite (`tests/test_visual_polish_and_consistency.gd`):**
   - Asserts `race_vfx.gd` does NOT instantiate `SphereMesh` headlight lenses.
   - Asserts taillights and brake lighting react dynamically to deceleration/braking.
   - Asserts showroom cars in `garage_environment_builder.gd` use toon shading and ink outlines.
   - Asserts Main Menu buttons apply the Concept 01 slant geometry and stencil styling.
2. **Zero Regression Gate:**
   - All 24 existing headless test suites must continue to pass with 0 failures (totaling 25/25 suites passing).
3. **Performance Gate:**
   - 60 FPS locked frame budget ($\le 16.66\text{ ms}$) preserved across all graphics presets.
   - Zero orphan nodes upon exiting to Main Menu.
