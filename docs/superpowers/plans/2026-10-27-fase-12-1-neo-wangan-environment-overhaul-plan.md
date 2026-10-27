# Fase 12.1: Neo-Wangan Environment Overhaul & Universal Trackside Kit Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Merombak total lingkungan 3D sirkuit **Neo-Wangan Shuto Express** dari *whitebox/floating primitives* menjadi sirkuit jalan raya malam Tokyo berstandar siaran (*broadcast-grade*) sesuai [`Circuit-Environment-Component-Guide.md`](file:///D:/Occupation/Porto/genex/La_Voiture/Circuit-Environment-Component-Guide.md) dan 4 gambar konsep di [`reference-assets/tracks/neo_wangan/`](file:///D:/Occupation/Porto/genex/La_Voiture/reference-assets/tracks/neo_wangan/).

**Architecture:** Mengikuti standar **6-Layer Circuit Architecture**:
1. Memparameterisasi **Tier-1 Universal FIA Motorsport Kit** (`PitBuilding`, `MainGrandstand`, `RaceControlTower`, `StartGantry`, `CatchFence`, papan rem `150/100/50`) agar dapat dipakai ulang secara *plug-and-play* di Neo-Wangan maupun 10 sirkuit mendatang tanpa merusak Apex Ring.
2. Membangun **Tier-2 City Hero Assets** menggunakan Blender 5.2 Python generator (`tools/build_neo_wangan_assets.py` → `assets/world/circuits/neo_wangan/*.glb`): Pylon Jembatan Gantung berkabel (*Rainbow Bridge style*), Portal Terowongan Beton + Overpass Plaza, Crane Pelabuhan bertruss rangka, dan 4 arsitektur gedung Tokyo (Helipad Tower, Billboard Tower, Curtain-Wall Tower, Street Podium).
3. Membangun **Ground Massing & Near-Track Urban Corridor (12 m – 45 m)** sehingga jalan tidak lagi melayang di atas air kosong, terowongan benar-benar menembus massa plaza kota di atasnya, dan *light pools* lampu jalan terpotong rapi di atas aspal.

**Tech Stack:** Godot Engine 4.7.2 stable (GDScript 2.0 static typing), Blender 5.2.0 (`C:\Program Files\Blender Foundation\Blender 5.2\blender.exe`), Godot Shaders (`.gdshader`).

---

## Peta File & Tanggung Jawab Modul

```
La_Voiture/
├── Circuit-Environment-Component-Guide.md          # [CREATED] Standar baku 6-Layer & 6-Camera Gate
├── tools/
│   └── build_neo_wangan_assets.py                  # [CREATE] Blender 5.2 script: mengekspor GLB hero landmarks & towers
├── assets/world/circuits/neo_wangan/               # [CREATE] Output GLB modular dari Blender 5.2
│   ├── shuto_bridge_pylon.glb                      # Menara jembatan gantung ganda + kabel suspensi neon
│   ├── tunnel_portal_overpass.glb                  # Portal beton underpass + jembatan plaza di atasnya
│   ├── harbor_gantry_crane.glb                     # Crane kontainer rangka truss A-frame
│   └── tokyo_towers_kit.glb                        # 4 variasi menara gedung arsitektural (setbacks, spire, helipad, billboard)
├── scripts/world/
│   ├── paddock/
│   │   ├── pit_building.gd                         # [MODIFY] Parameterisasi @export length_m, front_x, stall_pitch_m, team_count
│   │   ├── main_grandstand.gd                      # [MODIFY] Parameterisasi @export length_m, front_x_m
│   │   └── race_control_tower.gd                   # [MODIFY] Dukungan penempatan modular di sirkuit mana pun
│   ├── neo_wangan_pit_complex.gd                   # [MODIFY] Integrasi PitBuilding 2 lantai, interior garasi, & CatchFence
│   └── neo_wangan_environment.gd                   # [MODIFY] Implementasi 6-Layer: Ground Island Slabs, Near-Track Corridor,
│                                                   #          Reusable Grandstand/ControlTower/Gantry, Blender Landmarks,
│                                                   #          Neon Billboards, & Clipped Asphalt Light Pools
└── tests/
    └── test_neo_wangan_circuit.gd                  # [MODIFY] Asersi 6-Layer: Reusable FIA Kit, Ground Slabs, Near-Track Corridor,
                                                    #          Bridge Pylons, Tunnel Overpass, & Clipped Light Pools
```

---

## Rincian Tugas Bertahap (Bite-Sized TDD Tasks)

### Task 1: Parameterisasi Tier-1 Universal FIA Motorsport Kit (`PitBuilding`, `MainGrandstand`, `RaceControlTower`)

**Files:**
- Modify: `scripts/world/paddock/pit_building.gd`
- Modify: `scripts/world/paddock/main_grandstand.gd`
- Modify: `scripts/world/paddock/race_control_tower.gd`
- Test: `tests/test_track_environment.gd` & `tests/test_neo_wangan_circuit.gd`

- [ ] **Step 1: Tulis asersi test reusable FIA kit pada `tests/test_neo_wangan_circuit.gd`**
  Tambahkan asersi bahwa Neo-Wangan memuat:
  - `PitBuilding` 2 lantai (`floor_count == 2`) di atas 10 garasi pit.
  - `MainGrandstand` dengan `Jumbotron` dan penonton `MultiMesh` di seberang main straight.
  - `RaceControlTower` di ujung pit exit.
  - `StartGantry` dengan 5 pasang lampu merah FIA dan `CatchFence` di sepanjang main straight.

- [ ] **Step 2: Jalankan test untuk memverifikasi kegagalan (Red)**
  Run: `godot --headless --path . -s res://tests/test_neo_wangan_circuit.gd`
  Expected: FAIL pada asersi FIA kit.

- [ ] **Step 3: Parameterisasi `PitBuilding`, `MainGrandstand`, dan `RaceControlTower`**
  - Ubah konstanta dimensi di `pit_building.gd` (`stall_pitch_m`, `team_count`, `front_x`, `garage_top_y`) menjadi variabel `@export` yang default-nya tetap bernilai konstanta `PitLaneComplex` (sehingga Apex Ring 100% tidak berubah), namun dapat dikonfigurasi untuk Neo-Wangan (`stall_pitch_m = 12.0`, `front_x = 15.5`, `garage_top_y = 4.7`).
  - Ubah `main_grandstand.gd` agar `@export var stand_length_m: float = LENGTH_M` dan `@export var stand_front_x_m: float = FRONT_X_M` dapat disesuaikan dengan lebar jalan 11,5 m Neo-Wangan (`stand_length_m = 160.0`, `stand_front_x_m = 14.0`).

- [ ] **Step 4: Pasang Tier-1 FIA Kit ke `NeoWanganPitComplex` & `NeoWanganEnvironment`**
  - Instansiasi `PitBuilding`, `MainGrandstand`, `RaceControlTower`, `StartGantry`, perlengkapan interior garasi (`_garage_props`), dan `CatchFence` di Neo-Wangan.

- [ ] **Step 5: Verifikasi test Apex Ring & Neo-Wangan (Green)**
  Run:
  - `godot --headless --path . -s res://tests/test_track_environment.gd`
  - `godot --headless --path . -s res://tests/test_pit_lane.gd`
  - `godot --headless --path . -s res://tests/test_neo_wangan_circuit.gd`
  Expected: PASS 100%.

- [ ] **Step 6: Commit Task 1**
  Commit: `feat(world): parameterize Tier-1 FIA paddock kit and mount on Neo-Wangan`

---

### Task 2: Pembuatan Aset Landmark 3D via Blender 5.2 (`tools/build_neo_wangan_assets.py`)

**Files:**
- Create: `tools/build_neo_wangan_assets.py`
- Create: `assets/world/circuits/neo_wangan/shuto_bridge_pylon.glb`
- Create: `assets/world/circuits/neo_wangan/tunnel_portal_overpass.glb`
- Create: `assets/world/circuits/neo_wangan/harbor_gantry_crane.glb`
- Create: `assets/world/circuits/neo_wangan/tokyo_towers_kit.glb`
- Test: `tests/test_neo_wangan_circuit.gd`

- [ ] **Step 1: Tulis asersi test keberadaan & geometri aset GLB Blender**
  Tambahkan asersi di `tests/test_neo_wangan_circuit.gd`:
  - Keempat file `.glb` di `res://assets/world/circuits/neo_wangan/` dapat dimuat oleh `ResourceLoader`.
  - `shuto_bridge_pylon.glb` memiliki tinggi $\ge 32\text{ m}$ (menara + kabel gantung).
  - `tunnel_portal_overpass.glb` memiliki bukaan portal selebar $\ge 13,0\text{ m}$ dan struktur overpass di atasnya.

- [ ] **Step 2: Jalankan test untuk memverifikasi kegagalan (Red)**
  Run: `godot --headless --path . -s res://tests/test_neo_wangan_circuit.gd`
  Expected: FAIL (file GLB belum ada).

- [ ] **Step 3: Tulis & jalankan `tools/build_neo_wangan_assets.py` dengan Blender 5.2**
  Run: `& "C:\Program Files\Blender Foundation\Blender 5.2\blender.exe" -b -P tools/build_neo_wangan_assets.py`
  Membangun:
  1. `shuto_bridge_pylon.glb`: Menara kembar A-frame/H-frame setinggi 38 m dengan balok silang bertruss dan 16 kabel suspensi miring (*stay cables*) bercahaya sian/magenta.
  2. `tunnel_portal_overpass.glb`: Portal dinding beton bertulang berprofil miring, lengkap dengan struktur jembatan jalan raya atas (*overpass deck*), parapet, dan blok bangunan di atas atap terowongan.
  3. `harbor_gantry_crane.glb`: Crane kontainer pelabuhan rangka baja bertruss lengkap dengan boom horisontal, kabin operator, dan lampu sorot.
  4. `tokyo_towers_kit.glb`: 4 variasi gedung pencakar langit berdetail arsitektur (Setback Helipad Tower dengan spire merah, Commercial Billboard Tower dengan bingkai LED neon, Curtain-Wall Fin Tower dengan garis cahaya vertikal, dan Street-Front Podium Block).

- [ ] **Step 4: Impor & verifikasi test (Green)**
  Run: `godot --headless --path . -s res://tests/test_neo_wangan_circuit.gd`
  Expected: PASS.

- [ ] **Step 5: Commit Task 2**
  Commit: `feat(assets): generate Blender 5.2 3D landmark and skyscraper kit for Neo-Wangan`

---

### Task 3: Ground Massing, Near-Track Urban Corridor (12 m – 45 m) & Neon Billboards

**Files:**
- Modify: `scripts/world/neo_wangan_environment.gd`
- Modify: `shaders/neo_wangan_skyline.gdshader`
- Test: `tests/test_neo_wangan_circuit.gd`

- [ ] **Step 1: Tulis asersi test untuk Ground Massing & Near-Track Corridor**
  Tambahkan asersi di `tests/test_neo_wangan_circuit.gd`:
  - Seluruh segmen jalan non-jembatan ditopang oleh pulau daratan/dermaga (`CityIslandSlabs` / `QuayWalls`), sehingga tidak ada jalan darat yang menggantung di atas air.
  - Terdapat ≥ 40 bangunan koridor dekat (`near_track_buildings`) pada jarak lateral 14 m – 48 m dari jalan (bukan hanya di radius 250 m+).
  - Terowongan underpass (`s = 1020..1200`) tertutup oleh struktur *Overpass Plaza & Buildings* di atas atapnya dan memiliki dinding *retaining wall* di ramp masuk/keluarnya.
  - Terdapat papan reklame neon (`NeonBillboards`) dan marka jalan tol / papan rem `150/100/50` m.
  - *Light pools* lampu jalan berada tepat di atas permukaan aspal jalan (`lateral` di dalam $\pm 4,5\text{ m}$), tidak bocor melayang di luar tepi jembatan.

- [ ] **Step 2: Jalankan test untuk memverifikasi kegagalan (Red)**
  Run: `godot --headless --path . -s res://tests/test_neo_wangan_circuit.gd`
  Expected: FAIL.

- [ ] **Step 3: Implementasi Ground Massing, Near-Track Corridor & Landmarks di `neo_wangan_environment.gd`**
  - **Layer 2 (Ground Massing):** Bangun sabuk pulau beton & dinding dermaga (*quay wall*) mengikuti seluruh segmen darat sirkuit (lateral $\pm 65\text{ m}$, turun dari $y = -0,05\text{ m}$ ke $y = -6,0\text{ m}$), menyisakan air teluk terbuka di bawah *Shuto Bay Bridge* dan di sisi luar *Harbor Docks*.
  - **Layer 2/5 (Bridge & Tunnel):** Pasang 2 `shuto_bridge_pylon.glb` beserta kabel suspensi dan parapet samping jembatan di Sektor 1; pasang `tunnel_portal_overpass.glb` di pintu masuk & keluar terowongan Sektor 2, dinding penahan tanah (*retaining walls*) di turunan/tanjakan terowongan, dan plaza gedung di atas atap terowongan.
  - **Layer 4 (Near-Track Corridor):** Tempatkan deretan gedung podium & menara dari `tokyo_towers_kit.glb` di sepanjang koridor luar pagar sirkuit (lateral 16 m – 45 m) lengkap dengan panel **Neon Billboards** (sian, magenta, kuning emas, hijau limau) yang menghadap kamera lintasan.
  - **Layer 6 (Lighting & Atmosphere):** Perbaiki posisi `StreetlightPools` agar jatuh di $\pm 2,6\text{ m}$ di atas aspal (di bawah kepala lampu, bukan di tiang luar), aktifkan `glow_enabled = true` dan `fog_enabled = true` pada `WorldEnvironment`.

- [ ] **Step 4: Jalankan test untuk memverifikasi kelulusan (Green)**
  Run: `godot --headless --path . -s res://tests/test_neo_wangan_circuit.gd`
  Expected: PASS (anggaran tetap $\le 160$ draw calls dan $\le 320.000$ tris).

- [ ] **Step 5: Commit Task 3**
  Commit: `feat(world): build Neo-Wangan civil ground massing, near-track urban corridor, and bridge/tunnel landmarks`

---

### Task 4: Verifikasi 6-Camera Visual Gate, Full Regression Suite & Laporan Revisi

**Files:**
- Modify: `scratch/capture_wangan_environment.gd`
- Modify: `executor-report/reports/FASE-12-NEO-WANGAN-CIRCUIT-REPORT.md`
- Modify: `ROADMAP.md`

- [ ] **Step 1: Tangkap 6 Screenshot Wajib sesuai `Circuit-Environment-Component-Guide.md`**
  Rekam 1920×1080 native screenshots ke `executor-report/screenshots/phases/`:
  1. `phase-12-v2-cam1-start-paddock.png` (Start/Pit Straight: Grandstand, Jumbotron, Gantry, PitBuilding 2 lantai, Control Tower, CatchFence).
  2. `phase-12-v2-cam2-shuto-bridge.png` (Shuto Bay Bridge: Menara Pylon kembar, kabel suspensi neon, parapet jembatan, teluk Tokyo).
  3. `phase-12-v2-cam3-tunnel-chicane.png` (Underpass Tunnel Portal: Overpass plaza & gedung di atas terowongan, retaining walls, koridor gedung & neon billboards).
  4. `phase-12-v2-cam4-harbor-hairpin.png` (Harbor Hairpin & Pit Entry: Dermaga beton, crane rangka truss, kontainer, kerb, jalur pisah Pit-In).
  5. `phase-12-v2-cam5-aerial-overview.png` (Helicopter Overview: Membuktikan daratan pulau, jembatan, dan kota menyatu tanpa jalan melayang).
  6. `phase-12-v2-cam6-chase-cam-race.png` (Player Chase Cam dengan 20 mobil GT3 di tengah koridor malam Tokyo).

- [ ] **Step 2: Inspeksi Visual Mandiri terhadap 6 Screenshot**
  Buka dan periksa keenam gambar untuk memastikan kualitas visual sudah padat, realistis, dan sesuai referensi.

- [ ] **Step 3: Jalankan Seluruh 45 Test Suite Headless**
  Run: `powershell -ExecutionPolicy Bypass -File scratch/run_all_tests.ps1`
  Expected: **45/45 PASS, 0 FAIL**.

- [ ] **Step 4: Update Laporan Eksekutif & `ROADMAP.md`, lalu Commit**
  Commit: `docs(report): update Fase 12 report and roadmap with 6-layer Neo-Wangan visual overhaul`
