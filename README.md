# La Voiture — Stylized Anime GT3 Motorsport Simulator

[![Engine](https://img.shields.io/badge/Engine-Godot%204.7.2%20Forward%2B-blue.svg)](https://godotengine.org/)
[![Platform](https://img.shields.io/badge/Platform-Windows%20(D3D12%20%2F%20Vulkan)-green.svg)]()
[![Performance](https://img.shields.io/badge/Performance-60%20FPS%20Locked%20(200%2B%20Uncapped)-red.svg)]()
[![Tests](https://img.shields.io/badge/Headless%20Tests-23%2F23%20Passing-brightgreen.svg)]()
[![License](https://img.shields.io/badge/Version-v1.0--vertical--slice-orange.svg)]()

> **"Speed, Soul, and Screentone."**  
> *La Voiture* is a high-octane GT3 racing simulator combining deterministic vehicle physics, strategic team principal pit command systems, and a striking visual identity forged from Japanese cel-shaded anime, manga halftone screentone, inverted-hull ink line art, and streetwear neo-brutalism.

---

## Key Highlights & Features (v1.0 Vertical Slice)

### 1. Full Pre-Race Presentation & Game Loop
* **Neo-Brutalist Main Menu:** Ambient 3D garage showroom, stylized slanted menu typography, and dynamic synthwave audio.
* **Comprehensive Settings Modal:** Display modes (Fullscreen/Borderless/Windowed), resolution scale (720p/1080p/1440p), graphics presets (Low to Ultra), V-Sync cap, Inverted Hull Ink Outline, Manga Halftone Screentone toggles, and 5 independent audio bus sliders.
* **Exhibition Race Setup:** Circuit selection card, lap configuration (3-lap Quick Sprint, 5-lap Standard, 10-lap Endurance), weather presets (Sunny Dry, Threatening Rain 60%, Full Wet, Monsoon), time of day (Day, Sunset, Night), and live 2D GPS circuit radar.
* **3D Pitstop Garage 10-Stall Team Select:** Smooth camera dolly gliding across 10 custom pit stalls, 360° vehicle turntable orbit, canonical duo 2D driver cards with Pace, Tire Management, and Wet Skill stats, plus independent starting tire compound selectors (*Team Principal Mode*).
* **Manga Comic Race Transition:** 1-frame negative snap-invert flash $\rightarrow$ 3-panel dynamic action comic cut-in with speedlines $\rightarrow$ 1.2s halftone wipe sweeping into the starting grid as 5 red FIA lights illuminate sequentially.
* **Podium Celebration & Exit to HQ:** Animated 3-step podium with trophies, confetti, fastest lap purple bonus stamp, constructors' points haul, and clean memory disposal returning to HQ with 0 orphan nodes.

### 2. 10 Canonical GT3 Manufacturers & Grid
A fully refined 10-car GT3 grid (80k–110k tris per body, 4K baked PBR textures, custom BBS FI-R master wheels, calibrated sockets, zero fender collision, and verified $+0.05\text{m}$ ground clearance):
1. **Apex Racing** — Porsche 911 GT3 R (992)
2. **Neon Drift** — Audi R8 LMS GT3 Evo II
3. **Kurogane GT** — Nissan GT-R NISMO GT3
4. **Vanta Motorsport** — BMW M4 GT3
5. **Razorline Racing** — Aston Martin Vantage AMR GT3
6. **Zero Hour Scuderia** — Chevrolet Corvette Z06 GT3.R
7. **Oni Performance** — Honda NSX GT3 Evo22
8. **Static Velocity** — Lexus RC F GT3
9. **Chrome Syndicate** — McLaren 720S GT3 Evo
10. **Night Raid GT** — Lamborghini Huracán GT3 EVO2

### 3. Apex Ring International (Hybrid Procedural Circuit)
* **High-Fidelity Track Geometry:** Spline-driven 4.16 km circuit with micro-grit asphalt, rubberized racing groove, wet puddle reflections, and 3D sawtooth kerbs (FIA Type-A $+0.05\text{m}$ crest).
* **Trackside Safety & Furniture:** Continuous triple-rib Armco guardrails, modular Tecpro shock barriers at high-impact runoffs, 150m/100m/50m braking distance boards, and 28 steel floodlight towers for night races.
* **Hero Architecture:** 2-floor Pit Paddock building with tinted glass VIP lounge, 3-tier Main Grandstand with cantilevered canopy and live Jumbotron leaderboard, Race Control Tower, and dual truss start gantry.
* **Interactive 13-Person Pit Crews:** Dedicated pit lane with concrete wall and crash cushions, 4.6m fast lane, and a 13-person standby crew per team that walks out to service tires with wheel guns and sparks.
* **2D GPS Radar HUD:** Real-time mini-map showing car numbers on team-colored discs, S1/S2/S3 sector ribbons, sector split chips, and yellow flag caution warnings.

### 4. Deterministic Simulation & Soundscape
* **Empirical Vehicle Dynamics:** Pacejka '94 tire model (dry/intermediate/wet compounds), tire wear cliff past 75%, puncture risk, fuel mass decay, ERS boost discharge, and 190-pair SAT cyclic contact resolver with lateral repulsion.
* **Kokoro-82M TTS Team Radio:** Authentically filtered walkie-talkie radio comms (1850 Hz bandpass + analog distortion) with automatic music ducking (-8 dB) and squelch chirps.
* **Dynamic Synthesized Audio:** Procedural RPM-modulated engine sound synthesis, lateral-G tire screeches, serrated kerb rumbles, and 3D pneumatic pit gun sounds.

---

## Technical Specifications

| Parameter | Specification |
| :--- | :--- |
| **Engine** | Godot Engine 4.7.2 stable (Forward+ Renderer) |
| **Graphics API** | Direct3D 12 / Vulkan (Windows) |
| **Languages** | GDScript 2.0 (static typing), Godot Shading Language (`.gdshader`), Python 3.10+, PowerShell |
| **Frame Budget** | Locked 60 FPS (16.66 ms) / Unthrottled 200–320+ FPS on RTX 3050 Laptop |
| **Draw Calls** | $< 180$ draw calls circuit-wide via GPU MultiMesh instancing |
| **Triangle Budget** | $< 350.000$ triangles for environment geometry |
| **Automated Tests** | 23 headless test suites (100% PASS, 0 FAIL) |

---

## Getting Started

### Prerequisites
1. **Godot Engine 4.7.2 stable**: Download from [godotengine.org](https://godotengine.org/download/).
2. **Git & Git LFS**: Ensure Git LFS is installed (`git lfs install`).
3. *(Optional for asset pipeline)* **Blender 5.2.0**: For 3D car mesh refinement and texture baking.

### Running the Game

Launch the native game client directly into the Main Menu:
```bash
godot --path . scenes/main.tscn
```

### Running Automated Test Suites

Execute any headless test suite without opening the GUI:
```bash
# Main menu and presentation flow
godot --headless --path . -s tests/test_main_menu_flow.gd

# GT simulation math and AI racecraft (43 assertions)
godot --headless --path . -s tests/test_gt_sim.gd

# Track environment, 3D kerbs, and paddock geometry
godot --headless --path . -s tests/test_track_environment.gd

# Pit lane complex and 13-person pit crews
godot --headless --path . -s tests/test_pit_lane.gd

# Vehicle stance, fender clearance, and wheel fitment gate
godot --headless --path . -s scratch/fit_cars.gd
```

To run all 23 test suites sequentially in PowerShell:
```powershell
Get-ChildItem tests\test_*.gd | ForEach-Object {
    Write-Host "Running $($_.Name)..." -ForegroundColor Cyan
    godot --headless --path . -s "res://tests/$($_.Name)"
}
```

---

## Controls

### Driving & Camera
* **W / Up Arrow**: Throttle / Accelerate
* **S / Down Arrow**: Brake / Reverse
* **A / Left Arrow**: Steer Left
* **D / Right Arrow**: Steer Right
* **Space**: Handbrake
* **C**: Cycle Camera (Chase Cam, Cockpit View, Orbit, Broadcast TV Director)
* **V**: Look Back

### Tactical Pit Wall & HUD Controls
* **M**: Toggle Bottom Tactical Deck (Pace, Fuel Mix, ERS, Box Lap)
* **T**: Open/Close Telemetry Instrument Drawer (Tire temps, pressures, brake wear, G-meter)
* **Tab**: Cycle Live Timing Tower Mode (`INT` / `GAP` / `LAST`)
* **N**: Focus Next Rival Car in Telemetry & Chase Cam
* **E**: Trigger ERS Overtake Boost
* **H**: Hide/Unhide Entire HUD (Photo / Cinema Mode)
* **1 - 5**: Adjust Simulation Speed (1x, 2x, 4x, 8x, 16x Fast-Forward)

---

## Project Structure & Architecture

```
La_Voiture/
├── assets/                 # Runtime binary assets (3D GLB cars, textures, audio SFX, music)
├── reference-assets/       # Canonical 2D character portraits & turnaround model sheets
├── scenes/                 # Godot scene files (.tscn) organized by domain (ui, car, race_world, hud)
├── scripts/                # GDScript source code (core, car, world, ui, audio, gt, hud)
├── shaders/                # Visual shaders (toon_car_paint, road_asphalt, cel_shading, etc.)
├── materials/              # Shared Godot materials (.tres, .material)
├── tests/                  # 23 automated headless test suites (100% PASS)
├── tools/                  # Build utilities and track generators
├── scratch/                # Asset pipelines (make_car.ps1, refine_car.py, fit_cars.gd, car_configs/)
├── executor-report/        # Executive completion reports (reports/) and visual evidence (screenshots/)
├── docs/                   # Architecture specifications and implementation plans
└── prompt/                 # Task handoff specifications (TASK-*.md)
```

See [`AGENTS.md`](AGENTS.md) for detailed architectural conventions, asset pipeline gates, and developer rules.

---

## License & Credits

Developed with pair-programming assistance by **Antigravity AI**.  
Powered by **Godot Engine**, **Blender**, **Kokoro TTS**, and **Meshy AI**.
