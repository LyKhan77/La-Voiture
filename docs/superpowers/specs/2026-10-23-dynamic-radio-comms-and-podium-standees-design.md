# Design Specification: Fase 8.4 — Dynamic Radio Comms Overhaul & 2D Podium Character Showcase

**Status:** APPROVED FOR IMPLEMENTATION  
**Target Engine:** Godot Engine 4.7.2 stable  
**Author:** Antigravity Architect  
**Date:** 2026-10-23  

---

## 1. Executive Summary

Fase 8.4 focuses on elevating the high-drama emotional peaks of *La Voiture* during both active wheel-to-wheel combat and race finale celebrations. While the simulation core (Pacejka tire model, SAT multi-car collision resolver, strategy pit wall) is deterministic and functional, in-race storytelling requires authentic, immediate character presence.

This specification details two integrated systems:
1. **Dynamic Radio Comms Overhaul:**
   - Visual dual-dock layout (Driver on Left in Acid Lime/Crimson, Engineer on Right in Electric Cyan/Crimson).
   - Animated procedural **Manga Soundwave Equalizer** reacting dynamically while voice audio or transmissions are active.
   - Dynamic 2D driver portrait integration pulling canonical character assets (`reference-assets/characters/<team>/<driver>/radio_portrait.png`) via `GarageRoster`.
   - Expanded, high-frequency driver triggers: **Overtake Success**, **Defending Under Pressure / Lost Position**, **ERS Boost Discharge**, **Tire Cliff / Puncture**, and **Contact / Collision**.
   - Gender-matched Kokoro-82M TTS voice synthesis (female voice for Freja Berg of Nordic Phantom).
2. **2D Podium Character Standee Banners:**
   - Replacement of flat text cards with neo-brutalist **2D Character Standees** for P1, P2, and P3 finishers.
   - Distinctive championship laurel tiers: P1 Champion (Gold), P2 Runner-Up (Silver), P3 Podium (Bronze).
   - Staggered entrance animation with slide-up easing, confetti burst, and full stat badges (number, code, team, finishing gap, points haul).

---

## 2. Dynamic Radio Comms Architecture

### A. Dual Dock Topology & Manga Visuals
`scripts/ui/anime_radio_cutin.gd` provides the comic-styled radio cut-in banner rendered on Layer 3 (Z: 30):
* **Left Banner (Driver):** Slanted 10° leftward, Acid Lime accent (`#D8FF00`) or Anime Crimson (`#FF1A4B`) when urgent. Displays driver portrait, team badge, and speech text.
* **Right Banner (Engineer):** Slanted 10° rightward (mirrored), Electric Cyan accent (`#00F5D4`). Displays engineer portrait, pit wall strategy calls, and technical feedback.
* **Manga Soundwave Equalizer (`_draw_manga_soundwave`):**
  - An animated cluster of 14 vertical equalizer bars positioned alongside the speech container.
  - Rendered in procedural manga inking: `T.INK_BORDER_BLACK` outline, halftone dot interior, and accent-colored peak markers.
  - Active animation: Driven by elapsed time $\Delta t$ and randomized harmonic sines ($f_1 = 8\text{ Hz}, f_2 = 14\text{ Hz}, f_3 = 22\text{ Hz}$) when `_present` and transmitting.
  - Idle state: Smooth exponential decay down to a flat baseline line when transmission ends.

### B. Dynamic Driver Portrait Resolution
`scripts/hud/race_hud.gd` connects to `GtRace.radio_message`:
* Instead of preloading a single static driver portrait, `race_hud.gd` resolves the driver's portrait dynamically:
  ```gdscript
  if String(message["speaker"]) == "driver" and car != null:
      var portrait_path := GarageRoster.portrait_path(car.id)
      if ResourceLoader.exists(portrait_path):
          cut_in.set_portrait(load(portrait_path))
  ```
* For the pit engineer, `ENGINEER_PORTRAIT` (`res://assets/manga-race-engineer-portrait.png`) is preserved.

### C. Driver Comms Trigger Matrix & Cooldown Policy
Drivers now actively report high-drama wheel-to-wheel moments. To prevent radio clutter, each car maintains a 15-second radio cooldown for non-urgent driver calls, while urgent events (puncture, heavy contact) trigger immediately and bypass cooldown.

| Situation | Trigger Location | Speaker | Message Example | Priority |
| :--- | :--- | :--- | :--- | :--- |
| **Overtake Success** | `scripts/gt/gt_driving.gd` (after pass) | Driver | `"Pass made on %s! Clean move down the inside!"` | Standard |
| **Being Overtaken / Defending** | `scripts/gt/gt_driving.gd` (overtaken) | Driver | `"Lost the spot to %s into Turn %d! Defending now!"` | Standard |
| **ERS Boost Activation** | `scripts/gt/gt_driving.gd` (`deploy_ers`) | Driver | `"Deploying ERS boost! Maximum attack!"` | Standard |
| **Tire Cliff (Wear > 75%)** | `scripts/gt/gt_driving.gd` (per lap check) | Driver | `"Tyres are cooked! Rear is sliding everywhere!"` | Standard |
| **Tire Puncture (Wear > 96%)** | `scripts/gt/gt_driving.gd` (blowout) | Driver | `"Puncture! Left rear is shredded, limping to pits!"` | **URGENT** |
| **Contact / Collision** | `scripts/gt/gt_contacts.gd` (SAT collision) | Driver | `"We touched with %s! Check the telemetry!"` | **URGENT** |

### D. Kokoro-82M Voice Synthesis Configuration
Voice mapping rules in `tools/audio/radio_lines.mjs`:
* **Engineer:** `bm_lewis` (speed: 1.05)
* **Male Drivers (19 drivers):** `am_eric` / `am_fenrir` (speed: 1.05)
* **Female Driver (Freja Berg, Car #09, Slot 8):** `af_bella` or `af_nicole` (speed: 1.05)
* Lines are generated as 24 kHz mono WAV files with edge fading and loudness normalization (`loudnorm=I=-16:TP=-1.5:LRA=7`), registered in `assets/audio/radio/voice/manifest.json`.

---

## 3. 2D Podium Character Standee Architecture

### A. Stage Layout & Standee Composition
In `scripts/ui/podium_screen.gd`, the 3 podium steps (P1 Center, P2 Left, P3 Right) are enhanced with **Neo-Brutalist 2D Standee Cards**:

```
+-----------------------------------------------------------+
|                   CHEQUERED FLAG // PODIUM                |
+-----------------------------------------------------------+
|                                                           |
|             [ P1 GOLD STANDEE ]                           |
|             +-----------------+                           |
|   [ P2 ]    |  GOLD LAUREL    |       [ P3 ]              |
|   +----+    |  PORTRAIT 2D    |       +----+              |
|   |    |    |  #01 REN M.     |       |    |              |
|   |P2  |    |  APEX RACING    |       |P3  |              |
|   |    |    +-----------------+       |    |              |
|   +----+    |    STEP 1       |       +----+              |
|   |STEP|    |    (TALLEST)    |       |STEP|              |
|   | 2  |    |                 |       | 3  |              |
+---+----+----+-----------------+-------+----+--------------+
```

### B. Standee Card Visual Specification
* **Dimensions:** $360\text{px} \text{ (width)} \times 260\text{px} \text{ (height)}$.
* **Backdrop Panel:**
  - Ink border: 4px solid black (`T.INK_BORDER_BLACK`).
  - Drop shadow: $6\text{px} \times 6\text{px}$ solid black offset.
  - Background: Team livery primary color with manga diagonal hatching / halftone dots.
* **Driver Portrait Frame:**
  - $140\text{px} \times 140\text{px}$ square container with inner 2px ink border.
  - Displays `radio_portrait.png` loaded from `GarageRoster.portrait_path(car.id)`.
* **Championship Tier Ribbon:**
  - **P1 Champion:** Gold badge (`#FFD23F`) with `"P1 WINNER // 25 PTS"` in black heavy display font.
  - **P2 Runner-Up:** Silver badge (`#D8DCE6`) with `"P2 RUNNER-UP // 18 PTS"`.
  - **P3 Podium:** Bronze badge (`#D9803A`) with `"P3 PODIUM // 15 PTS"`.
* **Data Typography:**
  - Driver Name: 32pt uppercase display font (`car.driver_name.to_upper()`).
  - Team & Car Code: 16pt header font (`car.code // car.team_name.to_upper()`).
  - Finishing Time / Gap: 20pt mono font in Acid Lime (`format_time(car.finished_at)`).

### C. Staggered Entrance Animation
When `PodiumScreen.present(race)` is invoked:
1. $t = 0.0\text{s}$: P3 Standee card slides up from behind Step 3 ($\Delta y = +60\text{px} \rightarrow 0\text{px}$, fade in $0.35\text{s}$).
2. $t = 0.2\text{s}$: P2 Standee card slides up from behind Step 2 ($\Delta y = +60\text{px} \rightarrow 0\text{px}$, fade in $0.35\text{s}$).
3. $t = 0.4\text{s}$: P1 Champion Standee card bursts into view ($\Delta y = +80\text{px} \rightarrow 0\text{px}$, fade in $0.4\text{s}$, with golden trophy pop and 160-piece confetti storm).

---

## 4. Verification & Quality Gates

1. **Automated Headless Test Suite (`tests/test_radio_and_podium.gd`):**
   - Verify portrait file existence for all 20 canonical drivers in `GarageRoster`.
   - Verify `AnimeRadioCutin` spawns and animates the Manga Soundwave node.
   - Verify driver radio triggers fire on overtake, defending, ERS activation, and contact events.
   - Verify `PodiumScreen` instantiates 3 standee cards with valid textures, correct placement indices, and proper finishing badges.
2. **Zero Regression Gate:**
   - All 23 legacy test suites must continue to pass with 0 failures (`24/24` total suites passing).
3. **Performance Gate:**
   - Zero orphan nodes on podium exit back to Main Menu.
   - 60 FPS locked during simultaneous radio cut-ins (Driver + Engineer active together).
