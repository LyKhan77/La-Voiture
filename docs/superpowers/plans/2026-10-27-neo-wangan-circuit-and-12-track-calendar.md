# 12-Month Circuit Calendar & Neo-Wangan Shuto Express Track Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Membangun arsitektur data kalender kejuaraan 12 sirkuit resmi (7 GP + 5 Sprint) sebagai fondasi Career Mode, serta mengimplementasikan sirkuit 3D sprint pertama yang playable penuh: **Neo-Wangan Shuto Express (新湾岸高速, 3.150 m)** lengkap dengan jalan tol layang, terowongan underpass, 10 garasi pitstop FIA bypass, dan pemilih sirkuit (Track Selector UI).

**Architecture:** Mengadopsi arsitektur modular Godot 4.7.2: data lintasan diisolasi dalam resource data `CircuitData.gd` dan `CircuitCalendarRegistry.gd`; geometri sirkuit jalan raya dibangun secara prosedural via spline `Curve3D` di `neo_wangan_circuit_builder.gd`; furnitur jalanan (dinding pembatas beton, tiang lampu Tokyo, marka) menggunakan `MultiMeshInstance3D` untuk efisiensi draw call (< 160 draw calls); serta integrasi mulus dengan `RaceConfigData`, `circuit_radar_2d.gd`, dan scene balap utama `RaceWeekendWorld`.

**Tech Stack:** Godot Engine 4.7.2 stable (GDScript 2.0 static typing), Godot Shading Language (`.gdshader`), Git + Git LFS, Meshy AI Reference Assets.

---

## Peta File & Tanggung Jawab Modul

```
La_Voiture/
├── scripts/
│   ├── core/
│   │   ├── circuit_data.gd                     # [CREATE] Resource data sirkuit (nama, inspirasi, km, tipe, elevasi, cuaca)
│   │   ├── circuit_calendar_registry.gd         # [CREATE] Registry 12 ronde kejuaraan & fungsi filter GP/Sprint
│   │   └── race_config_data.gd                 # [MODIFY] Integrasi selected_circuit_id & get_selected_circuit()
│   ├── world/
│   │   ├── neo_wangan_circuit_builder.gd       # [CREATE] Generator prosedural spline 3.150 m, elevasi, dan pit ramp
│   │   ├── street_furniture_builder.gd         # [CREATE] MultiMesh builder: concrete barriers, streetlights, overhead signs
│   │   └── circuit_lighting_controller.gd      # [MODIFY] Dukungan pencahayaan lampu kota & terowongan neon
│   └── ui/
│       ├── race_setup_menu.gd                  # [MODIFY] Penambahan Track Selector widget & preview sirkuit
│       └── circuit_radar_2d.gd                 # [MODIFY] Adaptasi rendering spline Curve3D sirkuit aktif
│
├── scenes/
│   ├── race_world/
│   │   ├── neo_wangan_circuit.tscn             # [CREATE] Scene sirkuit 3D Neo-Wangan lengkap (spline, pit, props)
│   │   └── neo_wangan_paddock/                 # [CREATE] Gedung pit bertingkat kaca & 10 garasi Neo-Wangan
│   └── ui/
│       └── race_setup_menu.tscn                # [MODIFY] UI pemilihan sirkuit (thumbnail, turn count, length)
│
├── tests/
│   ├── test_circuit_calendar_registry.gd       # [CREATE] Unit test 12 ronde, metadata, dan filter tipe
│   ├── test_neo_wangan_circuit.gd              # [CREATE] Uji integritas geometri 3.150 m, elevasi, pit triggers, clearance
│   └── test_track_selector_ui.gd               # [CREATE] Uji alur pemilihan sirkuit dan propagasi ke RaceConfigData
│
└── reference-assets/tracks/neo_wangan/         # [EXISTING/COMMITTED] 4 Views Meshy AI & Concept Art
```

---

## Rincian Tugas Bertahap (Bite-Sized Tasks)

### Task 1: Fondasi Arsitektur Data 12 Sirkuit (`CircuitData` & `CircuitCalendarRegistry`)

**Files:**
- Create: `scripts/core/circuit_data.gd`
- Create: `scripts/core/circuit_calendar_registry.gd`
- Modify: `scripts/core/race_config_data.gd`
- Test: `tests/test_circuit_calendar_registry.gd`

- [ ] **Step 1: Tulis unit test untuk Circuit Data & 12-Month Calendar Registry**
  Buat `tests/test_circuit_calendar_registry.gd`:
  - Menguji ada 12 sirkuit terdaftar (Round 1 s.d. Round 12).
  - Menguji tepat 7 sirkuit bertipe `GRAND_PRIX` dan 5 sirkuit bertipe `SPRINT`.
  - Menguji sirkuit Round 1 adalah "Apex Ring International" (GP) dan Round 2 adalah "Neo-Wangan Shuto Express" (Sprint).
  - Menguji setiap sirkuit memiliki `length_km > 0.0`, `turns_count > 0`, `country_code`, dan `scene_path`.

- [ ] **Step 2: Jalankan test untuk memverifikasi kegagalan (Red)**
  Jalankan: `godot --headless --path . -s res://tests/test_circuit_calendar_registry.gd`
  Ekspektasi: FAIL (script belum ada).

- [ ] **Step 3: Implementasi `scripts/core/circuit_data.gd`**
  Definisikan class `CircuitData extends Resource`:
  - Enum `CircuitType { GRAND_PRIX, SPRINT }`
  - Field `@export`: `circuit_id: String`, `round_number: int`, `display_name: String`, `japanese_name: String`, `real_inspiration: String`, `country: String`, `circuit_type: CircuitType`, `length_km: float`, `turns_count: int`, `direction_clockwise: bool`, `scene_path: String`, `preview_image_path: String`, `rain_probability: float`.

- [ ] **Step 4: Implementasi `scripts/core/circuit_calendar_registry.gd`**
  Definisikan class `CircuitCalendarRegistry`:
  - Daftarkan ke-12 sirkuit sesuai spesifikasi desain resmi (Apex Ring, Neo-Wangan, Brianza, Monte Azure, Ardennes, Haruna, Stoke Crown, Pacific Corkscrew, Eifel Forest, Iron Mountain, Paulistano, Kurogane).
  - Metode helper: `get_circuit(circuit_id: String) -> CircuitData`, `get_all_circuits() -> Array[CircuitData]`, `get_circuits_by_type(type: CircuitType) -> Array[CircuitData]`.

- [ ] **Step 5: Integrasikan ke `scripts/core/race_config_data.gd`**
  Tambahkan field `selected_circuit_id: String = "apex_ring"` (default), setter, dan fungsi `get_active_circuit() -> CircuitData`.

- [ ] **Step 6: Jalankan test kembali untuk memverifikasi kelulusan (Green)**
  Jalankan: `godot --headless --path . -s res://tests/test_circuit_calendar_registry.gd`
  Ekspektasi: PASS (semua asersi kalender 12 sirkuit lulus 100%).

- [ ] **Step 7: Commit Task 1**
  Commit pesan: `feat(core): implement 12-month circuit calendar registry and CircuitData resource`

---

### Task 2: Geometri Spline 3D & Ribbon Lintasan Neo-Wangan (`neo_wangan_circuit_builder.gd`)

**Files:**
- Create: `scripts/world/circuits/neo_wangan/neo_wangan_circuit_builder.gd`
- Create: `scenes/race_world/neo_wangan_circuit.tscn`
- Test: `tests/test_neo_wangan_circuit.gd`

- [ ] **Step 1: Tulis unit test untuk verifikasi geometri fisik Neo-Wangan**
  Buat `tests/test_neo_wangan_circuit.gd`:
  - Memuat `scenes/race_world/neo_wangan_circuit.tscn`.
  - Menguji `Curve3D` terpasang dengan total panjang loop terukur $3,150\text{ m} \pm 25\text{ m}$.
  - Menguji 12 titik kontrol tikungan dengan radius kelengkungan minimum $R_{\min} \ge 18\text{ m}$.
  - Menguji elevasi kurva: memiliki titik tertinggi $\ge +6.0\text{ m}$ (Shuto Bridge) dan titik terendah $\le -2.5\text{ m}$ (Underpass Tunnel).
  - Menguji lebar jalan ribbon 11.5 meter dengan material `road_asphalt.gdshader`.

- [ ] **Step 2: Jalankan test untuk memverifikasi kegagalan (Red)**
  Jalankan: `godot --headless --path . -s res://tests/test_neo_wangan_circuit.gd`
  Ekspektasi: FAIL.

- [ ] **Step 3: Implementasi `scripts/world/circuits/neo_wangan/neo_wangan_circuit_builder.gd`**
  - Rancang 12 simpul koordinat spline `Curve3D` yang merefleksikan layout resmi (Shuto Bridge Straight 950 m, T1 90°, T2/T3 esses, T4/T5 underpass tunnel descent, T6/T7 Shibuya S-Chicane, T8/T9 Harbor Concrete Hairpin 180°, T10-T12 Main Straight).
  - Bangun ekstrusi ribbon mesh 3D: permukaan aspal jalan tol (lebar 11.5 m), kerb jalan raya rendah (+0.03 m), dan garis marka jalan tol.

- [ ] **Step 4: Buat scene `scenes/race_world/neo_wangan_circuit.tscn`**
  Rakit root node `NeoWanganCircuit (Node3D)`:
  - Node `TrackRibbon` (`Path3D` + `PathFollow3D` + `MeshInstance3D`)
  - Node `SurfaceGeometry`
  - Node `Lighting` (lampu jalan Tokyo, lampu terowongan)
  - Node `WorldEnvironment` (Sky malam Tokyo dengan kabut neon).

- [ ] **Step 5: Jalankan test verifikasi geometri (Green)**
  Jalankan: `godot --headless --path . -s res://tests/test_neo_wangan_circuit.gd`
  Ekspektasi: PASS (panjang lintasan, radius, dan elevasi sesuai target).

- [ ] **Step 6: Commit Task 2**
  Commit pesan: `feat(world): implement 3D spline corridor and road ribbon for Neo-Wangan circuit`

---

### Task 3: Rekayasa Sambungan Pitstop & Standar Keselamatan FIA

**Files:**
- Modify: `scripts/world/circuits/neo_wangan/neo_wangan_circuit_builder.gd`
- Create: `scenes/race_world/neo_wangan_paddock/pit_complex.tscn`
- Modify: `scenes/race_world/neo_wangan_circuit.tscn`
- Test: `tests/test_neo_wangan_circuit.gd` (ekspansi test suite)

- [ ] **Step 1: Tulis asersi uji sambungan pitstop pada test suite**
  Tambahkan asersi ke `tests/test_neo_wangan_circuit.gd`:
  - `PitEntryTrigger` berada pada jarak 75 m sebelum garis finis di lateral offset sisi kanan (+5.2 m).
  - Terdapat peredam benturan oranye (*Crash Cushion*) pada hidung pemisah pit wall.
  - Jalur Fast Lane memiliki lebar 4.5 m dan menampung tepat 10 marker stall tim (`Socket_PitStall_0` s.d. `9`) berjarak 12 m.
  - `PitExitTrigger` dan jalur keluar memanjang melewati Turn 1 (*bypass ramp* 65 m) dengan garis solid *FIA Blend Line*.

- [ ] **Step 2: Jalankan test untuk memverifikasi kegagalan (Red)**
  Jalankan: `godot --headless --path . -s res://tests/test_neo_wangan_circuit.gd`
  Ekspektasi: FAIL pada asersi pitstop.

- [ ] **Step 3: Implementasi Pit Path & 10 Stalls di `neo_wangan_circuit_builder.gd`**
  - Rancang spline `Curve3D` sekunder untuk jalur pit yang membelah halus dari main track sebelum garis finis dan bergabung kembali setelah Turn 1.
  - Alokasikan 10 Marker3D stall garasi berjarak 12 m dengan orientasi menghadap fast lane.
  - Buat geometri dinding beton pemisah (*Pit Wall*) setinggi 1.2 m dan gantry start truss melintang.

- [ ] **Step 4: Integrasikan scene `pit_complex.tscn`**
  Bangun bangunan pit 10 garasi bertingkat modern bergaya Shuto Metropolis dengan panel LED sponsor dan pintu garasi beranimasi.

- [ ] **Step 5: Jalankan test untuk memverifikasi kelulusan (Green)**
  Jalankan: `godot --headless --path . -s res://tests/test_neo_wangan_circuit.gd`
  Ekspektasi: PASS seluruh asersi pitstop dan sambungan track.

- [ ] **Step 6: Commit Task 3**
  Commit pesan: `feat(world): implement safe FIA pit entry, 10-stall fast lane, and bypass pit exit for Neo-Wangan`

---

### Task 4: Lingkungan 3D Streetwear Perkotaan (MultiMesh Props, Tunnel & Skyline)

**Files:**
- Create: `scripts/world/street_furniture_builder.gd`
- Modify: `scripts/world/shared/circuit_lighting_controller.gd`
- Modify: `scenes/race_world/neo_wangan_circuit.tscn`
- Test: `tests/test_neo_wangan_circuit.gd`

- [ ] **Step 1: Tulis asersi uji anggaran performa & props perkotaan**
  Tambahkan asersi ke `tests/test_neo_wangan_circuit.gd`:
  - Seluruh dinding pembatas beton (*concrete barriers*) menggunakan `MultiMeshInstance3D`.
  - Tiang lampu jalan tol Tokyo (*streetlights*) menggunakan `MultiMeshInstance3D`.
  - Kontainer pelabuhan di Harbor Hairpin menggunakan instancing GPU.
  - Jumlah draw call total sirkuit $\le 160$ dan poligon lingkungan $\le 320.000$ tris.

- [ ] **Step 2: Jalankan test untuk memverifikasi kegagalan (Red)**
  Jalankan: `godot --headless --path . -s res://tests/test_neo_wangan_circuit.gd`
  Ekspektasi: FAIL pada ketiadaan props MultiMesh.

- [ ] **Step 3: Implementasi `scripts/world/street_furniture_builder.gd`**
  - Buat instancing prosedural sepanjang spline lintasan untuk:
    1. Barrier beton jalan tol dengan garis hazard kuning-hitam di tikungan dan grafiti anime.
    2. Tiang lampu jalan tol ganda dengan cahaya spotlight terarah ke aspal.
    3. Papan penunjuk jalan hijau gantry tol Shuto khas Jepang.
    4. Struktur atap beton terowongan *Underpass Tunnel* 180 m dengan lampu strip neon atap.
    5. Tumpukan kontainer pelabuhan industri di sektor Harbor Hairpin.

- [ ] **Step 4: Implementasi Skyline Gedung Low-Poly & Lighting Controller**
  - Buat cincin gedung pencakar langit Tokyo low-poly dengan shader window emissive berdenyut dinamis.
  - Integrasikan audio reverb gema knalpot saat mobil berada di dalam bounding box terowongan.

- [ ] **Step 5: Jalankan test untuk memverifikasi kelulusan (Green)**
  Jalankan: `godot --headless --path . -s res://tests/test_neo_wangan_circuit.gd`
  Ekspektasi: PASS (MultiMesh terkonfigurasi, anggaran render terpenuhi).

- [ ] **Step 6: Commit Task 4**
  Commit pesan: `feat(world): implement GPU MultiMesh urban street furniture, underpass tunnel, and Tokyo skyline`

---

### Task 5: Integrasi UI Track Selector di Race Setup & Radar 2D

**Files:**
- Modify: `scripts/ui/race_setup_menu.gd`
- Modify: `scenes/ui/race_setup_menu.tscn`
- Modify: `scripts/ui/circuit_radar_2d.gd`
- Test: `tests/test_track_selector_ui.gd`

- [ ] **Step 1: Tulis unit test untuk UI Track Selector**
  Buat `tests/test_track_selector_ui.gd`:
  - Memuat `scenes/ui/race_setup_menu.tscn`.
  - Menguji tombol pemilih sirkuit (`TrackPrevButton` / `TrackNextButton` atau carousel).
  - Menguji saat sirkuit berganti ke `neo_wangan`:
    - Label nama sirkuit menjadi "Neo-Wangan Shuto Express".
    - Label tipe menjadi "SPRINT".
    - Label panjang menjadi "3.15 km".
    - `RaceConfigData.selected_circuit_id` ter-update menjadi `"neo_wangan"`.
  - Menguji minimap radar 2D di HUD merender Curve3D sirkuit aktif secara dinamis.

- [ ] **Step 2: Jalankan test untuk memverifikasi kegagalan (Red)**
  Jalankan: `godot --headless --path . -s res://tests/test_track_selector_ui.gd`
  Ekspektasi: FAIL.

- [ ] **Step 3: Tambahkan Widget Track Selector di `scenes/ui/race_setup_menu.tscn`**
  - Tambahkan kartu sirkuit dengan preview thumbnail, badge tipe (GP hijau / Sprint merah), panjang, dan jumlah tikungan.
  - Tambahkan tombol navigasi panah kiri/kanan (`<` / `>`) dengan suara klik UI.

- [ ] **Step 4: Update `scripts/ui/race_setup_menu.gd`**
  - Sinkronkan daftar sirkuit dari `CircuitCalendarRegistry.get_all_circuits()`.
  - Perbarui tampilan saat pengguna memilih sirkuit dan simpan pilihan ke `RaceConfigData`.

- [ ] **Step 5: Adaptasi `scripts/ui/circuit_radar_2d.gd`**
  - Ambil node `TrackRibbon` dari scene sirkuit yang sedang aktif (`RaceWeekendWorld.active_circuit`) agar radar 2D otomatis menggambar lintasan Neo-Wangan saat balapan dimuat.

- [ ] **Step 6: Jalankan test verifikasi UI (Green)**
  Jalankan: `godot --headless --path . -s res://tests/test_track_selector_ui.gd`
  Ekspektasi: PASS (pemilihan sirkuit bekerja 100%).

- [ ] **Step 7: Commit Task 5**
  Commit pesan: `feat(ui): implement dynamic Track Selector in Race Setup menu and adaptive 2D circuit radar`

---

### Task 6: Integrasi Balapan Penuh, Multi-Car AI Simulation & Verifikasi Akhir

**Files:**
- Modify: `scenes/race_weekend_world.tscn`
- Modify: `scripts/core/game_state.gd` (jika ada propagasi scene sirkuit)
- Run: Seluruh 42 test suites yang sudah ada + 3 test suite baru

- [ ] **Step 1: Hubungkan dynamic track loading di `scenes/race_weekend_world.tscn`**
  - Saat `RaceWeekendWorld` diinisialisasi, muat sirkuit sesuai `RaceConfigData.selected_circuit_id` (`apex_ring` atau `neo_wangan`).
  - Pastikan 20 mobil GT3 menempati grid start 2x2 yang sesuai dengan spline sirkuit baru.

- [ ] **Step 2: Jalankan full automated test suite headless**
  Jalankan seluruh test suite proyek:
  `powershell -ExecutionPolicy Bypass -File scratch/run_all_tests.ps1`
  Ekspektasi: **45/45 test suite PASS, 0 FAIL (100% PASS)** tanpa regresi sama sekali pada sirkuit lama maupun sirkuit baru.

- [ ] **Step 3: Jalankan Native Smoke Test (3 Lap 20 Mobil di Neo-Wangan)**
  - Luncurkan game: `godot --path . scenes/main.tscn`
  - Buka Race Setup -> Pilih "Neo-Wangan Shuto Express" -> Masuk Garasi -> Launch Race.
  - Verifikasi: 5 lampu start FIA, 20 mobil melintasi Shuto Bridge, masuk terowongan, pitstop 10 mobil lancar tanpa crash barrier, finis bendera chequered flag, masuk ke Winning Scene P1-P3, dan Exit to HQ dengan 0 orphan nodes.

- [ ] **Step 4: Pengukuran Performa Frame Time 60 FPS Locked**
  - Ukur frame time pada 1920x1080 High Preset: pastikan rata-rata frame time $\le 16.66\text{ ms}$ (60 FPS locked), p95 $\le 18.0\text{ ms}$.

- [ ] **Step 5: Dokumentasi Laporan Eksekutif & Bukti Visual**
  - Tulis laporan penyelesaian di `executor-report/reports/FASE-12-NEO-WANGAN-CIRCUIT-REPORT.md`.
  - Ambil tangkapan layar verifikasi in-game dan simpan di `executor-report/screenshots/phases/phase-12-*.png`.
  - Update `ROADMAP.md` dengan status centang lengkap.

- [ ] **Step 6: Final Commit & Push**
  Commit pesan: `feat(tracks): complete 12-circuit calendar and playable Neo-Wangan Shuto Express sprint circuit`
