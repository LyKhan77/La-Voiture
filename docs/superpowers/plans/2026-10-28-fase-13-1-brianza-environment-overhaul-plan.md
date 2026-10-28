# Fase 13.1: Autodromo di Brianza Environment Overhaul & 6-Layer Architecture Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Merombak total lingkungan 3D sirkuit **Autodromo di Brianza (`brianza`)** dari status *whitebox/floating road* prematur menjadi representasi "Temple of Speed" (Monza Royal Park) berstandar siaran (*broadcast-grade*) cel-shaded anime sesuai [`Circuit-Environment-Component-Guide.md`](file:///D:/Occupation/Porto/genex/La_Voiture/Circuit-Environment-Component-Guide.md) v2.0 dan 4 gambar konsep di [`reference-assets/tracks/brianza/`](file:///D:/Occupation/Porto/genex/La_Voiture/reference-assets/tracks/brianza/).

**Architecture:** Menerapkan **6-Layer Circuit Architecture** sesuai panduan resmi:
1. **Layer 1: Ground Massing & Park Terrain:** `ParcoRealeGroundMesh` (4200 m × 3600 m rumput stepped cel `#3c7a38`), jalur kerikil inspeksi (`ParkPathways`), dan dinding bata terakota historis pembatas taman (`MuraDelParco`) setinggi 3.2 m. Menegakkan Hukum Kontinuitas Sipil: 0 floating roads.
2. **Layer 2: Hero Landmark 1 — La Sopraelevata High-Banked Oval Deck:** Viaduk lengkung beton bertulang multi-span 480 m dengan kemiringan $28^\circ$ banking, portal pilar lengkung ganda dengan clearance 13.5 m melintasi Serraglio straight.
3. **Layer 3: Hero Landmarks 2, 3 & Corner Grandstands:** Tribun Variante del Rettifilo (T1-T2, 120 m dengan kanopi merah Italia & penonton anime), Tribun Variante Ascari (T9-T11, 160 m + Jumbotron), Porta di Monza (Gerbang neoklasik s=5600m), dan Torre Ascari (Menara batu timing 4 lantai s=4150m + spanduk retro Agip kuning).
4. **Layer 4: Dense Parco Reale Foliage Overhaul:** Pinus payung Italia (*Pinus pinea*) dengan kanopi payung bertingkat 3-tone cel, cemara ramping Italia (*Cupressus sempervirens*), dan semak belukar (*undergrowth shrubs*) menggunakan `MultiMeshInstance3D` per distrik.
5. **Layer 5: Trackside Safety, Catch Fence & Sponsor Culture:** FIA debris catch fencing di atas Armco sepanjang area tribun & pengereman, gantry penanda jarak pengereman overhead (200m, 150m, 100m, 50m) di Rettifilo, Roggia, dan Ascari, papan reklame retro sponsor Italia (Pirelli, Brembo, Agip, Magneti Marelli), dan pos marshal.
6. **Layer 6: Distant Vista Ring & Environmental Lighting:** `BrianzaVistaRing` (siluet perbukitan kaki Alpen Italia & dinding kanopi hutan pada radius 4.500 m) dan implementasi penuh `bind_world()` (matahari hangat keemasan, bayangan tajam, ambient sky, cel depth fog, lampu sorot malam).

**Tech Stack:** Godot Engine 4.7.2 stable (GDScript 2.0 static typing), Godot Shaders (`.gdshader`), MeshBatch, MultiMeshInstance3D.

---

## Peta File & Tanggung Jawab Modul

```
La_Voiture/
├── Circuit-Environment-Component-Guide.md            # Standar baku 6-Layer & 6-Camera Gate v2.0
├── docs/superpowers/specs/
│   └── 2026-10-28-fase-13-1-brianza-environment-overhaul-design.md # Spesifikasi desain resmi
├── prompt/
│   └── TASK-FASE-13-1-BRIANZA-ENVIRONMENT-OVERHAUL.md # [CREATE] Prompt handoff eksekutor
├── scripts/world/
│   ├── brianza_environment.gd                        # [MODIFY] Implementasi penuh 6-Layer Architecture:
│   │                                                 #          - Layer 1: ParcoRealeGroundMesh, pathways, MuraDelParco
│   │                                                 #          - Layer 2: Monumental curved Sopraelevata 480m deck (28 deg banking)
│   │                                                 #          - Layer 3: Rettifilo & Ascari grandstands with crowd
│   │                                                 #          - Layer 4: Multi-tier umbrella pines, cypresses, shrubs
│   │                                                 #          - Layer 5: Catch fencing, brake gantries, retro sponsor boards
│   │                                                 #          - Layer 6: Alpine foothills vista ring + full bind_world()
│   └── brianza_pit_complex.gd                        # [MODIFY] Hubungkan Jumbotron ke timing standings
├── scenes/race_world/
│   └── brianza_circuit.tscn                          # [MODIFY] Update WorldEnvironment & node hooks jika diperlukan
├── tests/
│   └── test_brianza_circuit.gd                       # [MODIFY] Asersi komprehensif 6-Layer: Ground, Sopraelevata,
│                                                     #          Grandstands, Foliage, Catch Fences, Vista Ring, bind_world
└── scratch/
    └── capture_phase13_1_views.gd                    # [CREATE] Script perender 6 kamera 1080p visual gates (Day, Sunset, Night)
```

---

## Rincian Tugas Bertahap (Bite-Sized TDD Tasks)

### Task 1: Layer 1 — Parco Reale Ground Massing, Apron Gravel, & Historic Park Wall (`MuraDelParco`)

**Files:**
- Modify: `tests/test_brianza_circuit.gd`
- Modify: `scripts/world/brianza_environment.gd`

- [ ] **Step 1: Tulis asersi Layer 1 pada `tests/test_brianza_circuit.gd`**
  Tambahkan asersi bahwa `BrianzaEnvironment` memuat:
  - Node `ParcoRealeGroundRoot` dengan `ParcoRealeGroundMesh` (dimensi minimal $3500\text{ m} \times 3000\text{ m}$ menutupi seluruh loop sirkuit).
  - Material rumput ber-tone hijau stepped cel `#3c7a38`.
  - Node `MuraDelParco` (tembok keliling perimeter bata merah terakota selebar sirkuit dengan tinggi $\ge 3.0\text{ m}$).
  - Verifikasi bahwa elevasi dasar tanah mendukung kontur lintasan (0 floating roads).

- [ ] **Step 2: Jalankan test untuk memverifikasi kegagalan (Red)**
  Run: `godot --headless --path . -s res://tests/test_brianza_circuit.gd`
  Expected: FAIL pada asersi `ParcoRealeGroundRoot`.

- [ ] **Step 3: Implementasikan Layer 1 pada `brianza_environment.gd` (`_build_layer1_ground_massing()`)**
  - Buat sub-node `ParcoRealeGroundRoot`.
  - Bangun grid terrain bertingkat ($4200\text{ m} \times 3600\text{ m}$) berpusat di tengah bounding box spline sirkuit.
  - Tambahkan skirt apron kerikil di sepanjang tepi runoff/asphalt ribbon.
  - Bangun perimeter wall `MuraDelParco` menggunakan `MeshBatch` bertekstur bata terakota (`#a3483b`) dan topi batu kapur (`#d4d0c7`).

- [ ] **Step 4: Jalankan test untuk memverifikasi kelulusan (Green)**
  Run: `godot --headless --path . -s res://tests/test_brianza_circuit.gd`
  Expected: PASS pada Layer 1.

- [ ] **Step 5: Commit Task 1**
  Commit: `feat(brianza): implement Layer 1 ground massing and historic park perimeter wall`

---

### Task 2: Layer 2 — Hero Landmark 1: Monumental Curved Sopraelevata High-Banked Oval Deck

**Files:**
- Modify: `tests/test_brianza_circuit.gd`
- Modify: `scripts/world/brianza_environment.gd`

- [ ] **Step 1: Tulis asersi Layer 2 pada `tests/test_brianza_circuit.gd`**
  Tambahkan asersi bahwa `HeroLandmark_Sopraelevata` memiliki:
  - Busur deck lengkung sepanjang $\ge 400\text{ m}$ (rentang $s = 3200\text{ s.d. }3680\text{ m}$).
  - Kemiringan deck $28^\circ$ banking.
  - Minimal 4 pasang pilar lengkung beton ganda (*dual-arch concrete portals*) dengan vertical clearance $\ge 12.0\text{ m}$ di atas Serraglio straight.
  - Rel pengaman baja berkarat di tepi atas perbankan.

- [ ] **Step 2: Jalankan test untuk memverifikasi kegagalan (Red)**
  Run: `godot --headless --path . -s res://tests/test_brianza_circuit.gd`
  Expected: FAIL pada asersi busur deck multi-span Sopraelevata.

- [ ] **Step 3: Rombak `_build_tier_b_sopraelevata()` menjadi `_build_layer2_sopraelevata_monumental()`**
  - Bangun kurva busur oval miring ($R \approx 320\text{ m}$, panjang busur $480\text{ m}$) yang melintasi lintasan balap pada sudut miring diagonal.
  - Generate penampang jalan miring $28^\circ$ lebar $14\text{ m}$ menggunakan segmentasi `MeshBatch` bertahap (setiap $12\text{ m}$).
  - Letakkan 4 portal penyangga beton ganda dengan arch brackets yang membentang di atas aspal dengan clearance $13.5\text{ m}$.
  - Pasang railing berkarat (`#733d26`) dan curb pembatas ban luar.

- [ ] **Step 4: Jalankan test untuk memverifikasi kelulusan (Green)**
  Run: `godot --headless --path . -s res://tests/test_brianza_circuit.gd`
  Expected: PASS pada Layer 2.

- [ ] **Step 5: Commit Task 2**
  Commit: `feat(brianza): upgrade Sopraelevata into monumental 480m curved banked oval deck`

---

### Task 3: Layer 3 — Corner Grandstands (Rettifilo & Ascari) & Heritage Landmarks

**Files:**
- Modify: `tests/test_brianza_circuit.gd`
- Modify: `scripts/world/brianza_environment.gd`

- [ ] **Step 1: Tulis asersi Layer 3 pada `tests/test_brianza_circuit.gd`**
  Tambahkan asersi bahwa:
  - `RettifiloGrandstand` terpasang di sisi luar Turn 1 ($s = 1120 \dots 1240\text{ m}$) dengan panjang $\ge 100\text{ m}$ dan kanopi merah.
  - `AscariGrandstand` terpasang di sisi luar kompleks Ascari ($s = 3960 \dots 4120\text{ m}$) dengan panjang $\ge 120\text{ m}$.
  - `TorreAscari` dan `VillaRealeGatehouse` tetap terpasang dengan proporsi neoklasik.
  - Kedua tribun memiliki instanced crowd penonton anime bersorak.

- [ ] **Step 2: Jalankan test untuk memverifikasi kegagalan (Red)**
  Run: `godot --headless --path . -s res://tests/test_brianza_circuit.gd`
  Expected: FAIL pada asersi tribun sudut Rettifilo & Ascari.

- [ ] **Step 3: Implementasikan `_build_layer3_corner_grandstands()`**
  - Bangun modul tribun berkanopi melengkung merah khas Italia untuk Variante del Rettifilo.
  - Bangun tribun stadion masif untuk Variante Ascari lengkap dengan billboard dan posisi penonton.
  - Pasang `MultiMeshInstance3D` penonton bertopi/berbaju warna-warni pada baris bangku tribun.

- [ ] **Step 4: Jalankan test untuk memverifikasi kelulusan (Green)**
  Run: `godot --headless --path . -s res://tests/test_brianza_circuit.gd`
  Expected: PASS pada Layer 3.

- [ ] **Step 5: Commit Task 3**
  Commit: `feat(brianza): add Rettifilo and Ascari corner grandstands with animated crowd`

---

### Task 4: Layer 4 — Dense Royal Park Foliage (Umbrella Pines, Cypresses & Undergrowth Shrubs)

**Files:**
- Modify: `tests/test_brianza_circuit.gd`
- Modify: `scripts/world/brianza_environment.gd`

- [ ] **Step 1: Tulis asersi Layer 4 pada `tests/test_brianza_circuit.gd`**
  Tambahkan asersi bahwa:
  - Foliage memiliki 3 jenis vegetasi: `StonePines` ($\ge 450$ instansi), `ItalianCypresses` ($\ge 250$ instansi), dan `UndergrowthBushes` ($\ge 300$ instansi).
  - Mesh Pinus Payung memiliki kanopi payung lebar bertingkat 3-tone cel shading.
  - Menggunakan `MultiMeshInstance3D` dengan `cast_shadow = OFF` untuk efisiensi GPU.

- [ ] **Step 2: Jalankan test untuk memverifikasi kegagalan (Red)**
  Run: `godot --headless --path . -s res://tests/test_brianza_circuit.gd`
  Expected: FAIL pada asersi `UndergrowthBushes` dan jumlah pohon.

- [ ] **Step 3: Rombak `_build_tier_b_royal_park_foliage()` menjadi `_build_layer4_dense_park_foliage()`**
  - Perbarui geometri mesh Pinus Payung Italia: batang meliuk organik, 3 kanopi payung bertingkat (`#2d5432`, `#3f7345`, `#528c5a`).
  - Perbarui geometri cemara Italia: batang ramping tegak dengan puncak runcing lancip.
  - Buat mesh semak belukar rendah (*undergrowth bushes*) hijau tua-muda untuk menutupi transisi tanah ke pohon.
  - Atur distribusi penempatan MultiMesh dalam 3 zona kedalaman ($16\text{ m} \dots 85\text{ m}$) di sepanjang $5.790\text{ m}$ lintasan.

- [ ] **Step 4: Jalankan test untuk memverifikasi kelulusan (Green)**
  Run: `godot --headless --path . -s res://tests/test_brianza_circuit.gd`
  Expected: PASS pada Layer 4.

- [ ] **Step 5: Commit Task 4**
  Commit: `feat(brianza): overhaul Royal Park vegetation with multi-tier umbrella pines, cypresses, and undergrowth`

---

### Task 5: Layer 5 — Trackside Safety, Catch Fencing, Overhead Brake Gantries & Retro Italian Sponsor Boards

**Files:**
- Modify: `tests/test_brianza_circuit.gd`
- Modify: `scripts/world/brianza_environment.gd`

- [ ] **Step 1: Tulis asersi Layer 5 pada `tests/test_brianza_circuit.gd`**
  Tambahkan asersi bahwa:
  - Terdapat FIA Debris Catch Fencing (`CatchFenceMesh` atau MultiMesh tiang kawat) di atas Armco sepanjang area tribun & zona pengereman berat.
  - Terdapat Overhead Braking Gantries (papan rem 200m, 150m, 100m, 50m) pada pendekatan Rettifilo, Roggia, dan Ascari.
  - Terdapat retro Italian sponsor boards (Pirelli, Brembo, Agip, Magneti Marelli) di atas barrier.
  - Terdapat pos marshal di apex tikungan utama.

- [ ] **Step 2: Jalankan test untuk memverifikasi kegagalan (Red)**
  Run: `godot --headless --path . -s res://tests/test_brianza_circuit.gd`
  Expected: FAIL pada asersi FIA catch fencing & overhead brake gantries.

- [ ] **Step 3: Implementasikan `_build_layer5_trackside_safety_and_sponsors()`**
  - Pasang tiang bengkok $45^\circ$ dengan panel jaring kawat semi-transparan setinggi $2,8\text{ m}$ di atas Armco barrier.
  - Pasang rangka gantry overhead penanda rem (200m, 150m, 100m, 50m) dengan tipografi angka balap retro yang kontras.
  - Pasang papan sponsor balap klasik Italia (kuning-merah-biru) di atas barrier sepanjang lurusan dan tikungan.
  - Pasang pos pantau marshal beratap kanopi oranye/putih di apex tikungan.

- [ ] **Step 4: Jalankan test untuk memverifikasi kelulusan (Green)**
  Run: `godot --headless --path . -s res://tests/test_brianza_circuit.gd`
  Expected: PASS pada Layer 5.

- [ ] **Step 5: Commit Task 5**
  Commit: `feat(brianza): implement FIA catch fencing, overhead braking gantries, and retro sponsor billboards`

---

### Task 6: Layer 6 — Distant Vista Ring (Alpine Foothills) & Full `bind_world()` Lighting Integration

**Files:**
- Modify: `tests/test_brianza_circuit.gd`
- Modify: `scripts/world/brianza_environment.gd`

- [ ] **Step 1: Tulis asersi Layer 6 pada `tests/test_brianza_circuit.gd`**
  Tambahkan asersi bahwa:
  - Terdapat `BrianzaVistaRing` dengan siluet perbukitan Alpen pada radius $4.500\text{ m}$.
  - Fungsi `bind_world()` mengonfigurasi `WorldEnvironment` (glow, tonemap ACES, ambient light hangat, fog Mediterania) dan `DirectionalLight3D` `Sun` (sudut matahari $42^\circ$, warna hangat `#fff3db`, bayangan lembut).
  - Metode `apply_time_of_day()` merespons transisi `DAY`, `SUNSET`, dan `NIGHT`.

- [ ] **Step 2: Jalankan test untuk memverifikasi kegagalan (Red)**
  Run: `godot --headless --path . -s res://tests/test_brianza_circuit.gd`
  Expected: FAIL pada asersi `BrianzaVistaRing` dan `bind_world`.

- [ ] **Step 3: Implementasikan Layer 6 pada `brianza_environment.gd`**
  - Bangun mesh silinder panorama `BrianzaVistaRing` pada radius $4.500\text{ m}$ dengan siluet bertingkat hutan Monza dan bukit Alpen Montevecchia.
  - Implementasikan penuh `bind_world(world_environment, sun, camera)`:
    - Atur sun angle pitch $42^\circ$, yaw $215^\circ$ untuk bayangan panjang sore khas Italia.
    - Set warna cahaya matahari `#fff3db` (golden warm), ambient sky `#a3c2f0`, fog lembut `#dce8f5`.
    - Atur transisi `apply_time_of_day(tod, gloom)` agar saat `SUNSET` langit berwarna lembayung-emas dan saat `NIGHT` lampu sorot sirkuit menyala otomatis.

- [ ] **Step 4: Jalankan test untuk memverifikasi kelulusan (Green)**
  Run: `godot --headless --path . -s res://tests/test_brianza_circuit.gd`
  Expected: PASS pada Layer 6 dan seluruh asersi sirkuit Brianza.

- [ ] **Step 5: Commit Task 6**
  Commit: `feat(brianza): implement distant Alpine vista ring and full bind_world lighting controller`

---

### Task 7: 6-Camera Visual Gate Verification, Multi-Time Gate (Day/Sunset/Night), Smoke Test, & Official Executive Report

**Files:**
- Create: `scratch/capture_phase13_1_views.gd`
- Create: `executor-report/reports/FASE-13-1-BRIANZA-ENVIRONMENT-OVERHAUL-REPORT.md`
- Output Screenshots: `executor-report/screenshots/phases/phase-13-1-cam1..6-*.png`
- Modify: `ROADMAP.md`

- [ ] **Step 1: Buat skrip perender visual gates `scratch/capture_phase13_1_views.gd`**
  - Render 6 sudut kamera wajib beresolusi 1920×1080:
    - `phase-13-1-cam1-start-paddock.png` (Start / Pit Straight)
    - `phase-13-1-cam2-rettifilo-chicane.png` (Turn 1 Variante del Rettifilo)
    - `phase-13-1-cam3-curva-grande-park.png` (Curva Grande & Royal Park)
    - `phase-13-1-cam4-sopraelevata-cross.png` (Sopraelevata Banked Oval Cross)
    - `phase-13-1-cam5-ascari-chicane.png` (Variante Ascari Complex)
    - `phase-13-1-cam6-chase-cam-action.png` (Player Chase Cam Action 20 GT3 Cars)
  - Render variasi waktu: `phase-13-1-sunset.png` dan `phase-13-1-night.png`.

- [ ] **Step 2: Jalankan skrip perender dan inspeksi visual seluruh gambar**
  Run: `godot --headless --path . -s scratch/capture_phase13_1_views.gd`
  Periksa gambar: pastikan 0 floating road, ground rumput solid, viaduk Sopraelevata melengkung megah, pepohonan rimbun, dan pencahayaan hangat.

- [ ] **Step 3: Jalankan seluruh test suite headless (Zero Regression)**
  Run: `Get-ChildItem tests\test_*.gd | ForEach-Object { godot --headless --path . -s "res://tests/$($_.Name)" }`
  Expected: 100% PASS, 0 FAIL di seluruh 52 test suite.

- [ ] **Step 4: Jalankan native smoke test balapan 3 lap 20 mobil di Brianza**
  Verifikasi stabilitas framerate (60 FPS locked, frame time $\le 16.66\text{ ms}$) dan alokasi memori (0 orphan nodes).

- [ ] **Step 5: Tulis Laporan Eksekutif Resmi dan Update Roadmap**
  - Tulis `executor-report/reports/FASE-13-1-BRIANZA-ENVIRONMENT-OVERHAUL-REPORT.md`.
  - Update status `ROADMAP.md` untuk Fase 13.1.

- [ ] **Step 6: Commit Task 7**
  Commit: `docs(brianza): complete Phase 13.1 visual verification and executive report`
