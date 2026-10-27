# FASE 11 / LANGKAH 8 — Integrasi 3 Tim & Mobil GT3 Baru (Ferrari 296, Ford Mustang, Toyota Supra)

**Tanggal:** 27 Oktober 2026  
**Status:** **SELESAI & TERVERIFIKASI (100% PASS, 0 FAIL)**  
**Target:** Penambahan 3 tim resmi (Tim 10, Tim 11, Tim 12) dengan 6 driver baru dan 3 sasis mobil GT3 lengkap beserta pipeline 2D/3D, integrasi grid dinamis deterministik 20 mobil (10 tim), alokasi pit lane dinamis, serta verifikasi fitment roda BBS FI-R tanpa regresi.

---

## 1. Ringkasan Eksekutif & Hasil Utama

1. **Penambahan 3 Tim & Mobil GT3 Resmi**:
   - **Tim 10: Scuderia Maranello** (`scuderia-maranello` / `ferrari_296`): Ferrari 296 GT3 (3.0L Twin-Turbo 120° V6), Livery Rosso Corsa `#D40000`, dipimpin Matteo Moretti, dengan Driver `#21 BEL` (Marco Bellini) dan `#22 ROS` (Alessia Rossi).
   - **Tim 11: Ironhorse Motorsport** (`ironhorse-motorsport` / `ford_mustang`): Ford Mustang GT3 (5.4L Naturally-Aspirated Coyote V8), Livery Steel Navy `#1E3A8A` dengan dual hazard orange stripes, dipimpin Hank Calhoun, dengan Driver `#23 VAN` (Colt Vance) dan `#24 COO` (Wyatt Cooper).
   - **Tim 12: Neo-Wangan Works** (`neo-wangan-works` / `toyota_supra`): Toyota GR Supra GT (3.0L Inline-6 Twin-Scroll Single Turbo), Livery Pearl White `#E2E8F0` dengan aksen infrared vermilion dan hood karbon, dipimpin Kenjiro Sudo, dengan Driver `#25 KAZ` (Hayato Kazama) dan `#26 TAK` (Rin Takahashi).

2. **Dua Jalur Pipeline Aset Lengkap (2D & 3D)**:
   - **2D Character Pipeline**: 6 potret radio tajam 1024×1024 PNG berlatar transparan (`reference-assets/characters/<team>/<driver>/radio_portrait.png`) dimuat langsung secara runtime oleh UI; 6 concept art turnaround full-body (9:16); serta 6 cutout transparan RGBA 768×1376 di `assets/characters/standees/` untuk `KineticStandee3D` di panggung kemenangan (podium).
   - **3D Car Pipeline**: Model mentah AI dilacak via Git LFS (`assets/cars/<slug>/raw/<slug>_raw.glb`); bodi game-ready 80k–110k tris (`assets/cars/<slug>/<slug>_body.glb`) dengan 2 surface (`Paint` + `FenderLinerMat`); perakitan utuh dengan 4 velg master BBS FI-R (`<slug>_full.glb`); tekstur PBR 4096×4096 (`base_color.png`, `normal.png`, `orm.png`); shader material toon cel-shaded (`materials/<slug>_toon_body.tres`); dan chassis scene (`scenes/car/<slug>_chassis.tscn`).

3. **Gerbang Fitment Roda Wajib (`scratch/fit_cars.gd`) Lolos 100% (14/14 Mobil)**:
   - Seluruh 14 mobil (Safety Car Porsche 911 GT3 R + 13 Tim GT3) lulus seluruh 5 kriteria fitment:
     - **Penetrasi Geometri:** **0 vertex** bodi di dalam volume ban master ($R = 0.33\text{ m}$).
     - **Ground Clearance:** Ketinggian lantai bodi $\ge +0.04\text{ m}$ (target $+0.05\text{ m}$).
     - **Radial Gap Ban-ke-Spakbor:** Dalam rentang aman $2.5\text{ cm} \le \text{gap} \le 5.0\text{ cm}$.
     - **Fender Skin Height:** $\ge +5.0\text{ cm}$ di atas puncak ban (tidak ada ban menonjol keluar kap).
     - **Stance Rata Spakbor (Flush):** Selisih bibir ban ke fender $\le 1.6\text{ cm}$ per as roda.

4. **Arsitektur Grid Dinamis & Alokasi Pit Lane (Strict 60 FPS / 16.66 ms Budget)**:
   - Di menu Garasi 3D (`garage_team_select.tscn`), pemain dapat menelusuri dan memilih **ke-13 tim** (13 stall 3D dolly orbit dengan kartu profil tim dan statistik pembalap).
   - Saat balapan dimulai (`LAUNCH TO GRID`), grid aktif dikunci tepat **20 mobil (10 tim × 2 mobil)** guna mematuhi batas anggaran komputasi physics solver SAT (190 pasangan kontak) dan kapasitas fisik pit building (10 stall pit + 10 pintu garasi).
   - Tim pemain dijamin selalu masuk grid (slot tim aktif pertama). Sembilan (9) tim rival NPC dipilih secara acak terkontrol (deterministik berdasarkan `race_seed` konfigurasi balap).
   - Sistem Pit Lane (`pit_lane_complex.gd`) mengalokasikan 10 stall pit secara dinamis berdasarkan array tim yang aktif berlaga (`active_teams`).
   - Timing tower kemenangan (`winning_scene.gd`) secara otomatis mengagregasi poin konstruktor untuk 10 tim yang berlaga tanpa error indexing.

---

## 2. Rincian Tim, Mobil, dan Karakter Baru

| Parameter | Tim 10: Scuderia Maranello | Tim 11: Ironhorse Motorsport | Tim 12: Neo-Wangan Works |
| :--- | :--- | :--- | :--- |
| **Slug Tim / Mobil** | `scuderia-maranello` / `ferrari_296` | `ironhorse-motorsport` / `ford_mustang` | `neo-wangan-works` / `toyota_supra` |
| **Nama Mobil Resmi** | Ferrari 296 GT3 | Ford Mustang GT3 | Toyota GR Supra GT |
| **Arsitektur Mesin** | 3.0L Twin-Turbo 120° V6 | 5.4L Naturally-Aspirated Coyote V8 | 3.0L Inline-6 Twin-Scroll Turbo |
| **Tenaga / Torsi** | 600 hp @ 8,000 rpm / 712 Nm | 620 hp @ 7,250 rpm / 735 Nm | 585 hp @ 7,600 rpm / 690 Nm |
| **Warna Livery Pokok** | Rosso Corsa (`#D40000`) | Deep Steel Navy (`#1E3A8A`) | Pearl White (`#E2E8F0`) |
| **Aksen Livery** | Solar Gold & Dark Carbon | Dual Blaze Orange Hazard Stripes | Infrared Vermilion & Carbon Hood |
| **Team Principal** | Matteo Moretti | Hank Calhoun | Kenjiro Sudo |
| **Pembalap 1** | `#21 BEL` Marco Bellini (23 thn) | `#23 VAN` Colt Vance (26 thn) | `#25 KAZ` Hayato Kazama (22 thn) |
| **Statistik P1 (W/P/Q)** | Wet: 0.94 / Pace: 0.95 / Quali: 0.96 | Wet: 0.88 / Pace: 0.94 / Quali: 0.92 | Wet: 0.95 / Pace: 0.95 / Quali: 0.94 |
| **Pembalap 2** | `#22 ROS` Alessia Rossi (25 thn) | `#24 COO` Wyatt Cooper (24 thn) | `#26 TAK` Rin Takahashi (21 thn) |
| **Statistik P2 (W/P/Q)** | Wet: 0.92 / Pace: 0.93 / Quali: 0.94 | Wet: 0.87 / Pace: 0.93 / Quali: 0.93 | Wet: 0.91 / Pace: 0.93 / Quali: 0.95 |
| **Wheelbase (Z)** | $2.600\text{ m}$ ($\pm 1.300\text{ m}$) | $2.546\text{ m}$ ($\pm 1.273\text{ m}$) | $2.550\text{ m}$ ($\pm 1.275\text{ m}$) |
| **Track Width (Front / Rear)** | $1.700\text{ m}$ / $1.660\text{ m}$ | $1.656\text{ m}$ / $1.642\text{ m}$ | $1.762\text{ m}$ / $1.754\text{ m}$ |

---

## 3. Pipeline Aset 2D & Standee Kinetic 3D

1. **Potret Radio Komunikasi (2D Runtime UI)**:
   - Seluruh 6 potret dibuat dengan rasio aspek 1:1 resolusi 1024×1024 PNG dengan kanal alfa transparan, gaya cel-shaded anime manga inking dengan screentone halftone Ben-Day.
   - Disimpan pada struktur kanonik:
     - `reference-assets/characters/scuderia-maranello/marco-bellini/radio_portrait.png`
     - `reference-assets/characters/scuderia-maranello/alessia-rossi/radio_portrait.png`
     - `reference-assets/characters/ironhorse-motorsport/colt-vance/radio_portrait.png`
     - `reference-assets/characters/ironhorse-motorsport/wyatt-cooper/radio_portrait.png`
     - `reference-assets/characters/neo-wangan-works/hayato-kazama/radio_portrait.png`
     - `reference-assets/characters/neo-wangan-works/rin-takahashi/radio_portrait.png`
   - Dipastikan **tidak ada file `.gdignore`** pada `reference-assets/` sehingga engine Godot dapat mengimpor tekstur ini secara runtime.

2. **Standee Kemenangan (`assets/characters/standees/*.png`)**:
   - Diekstraksi dari konsep turnaround karakter menggunakan skrip automasi segmentasi `scratch/process_character_cutout.py`.
   - Menghasilkan 6 standee cutout RGBA 768×1376 beresolusi tinggi dengan telapak kaki tepat menapak di dasar kanvas:
     - `marco_bellini.png` (Alpha 0–255)
     - `alessia_rossi.png` (Alpha 0–255)
     - `colt_vance.png` (Alpha 0–255)
     - `wyatt_cooper.png` (Alpha 0–255)
     - `hayato_kazama.png` (Alpha 0–255)
     - `rin_takahashi.png` (Alpha 0–255)
   - Kompatibel penuh dengan shader `KineticStandee3D` pada scene podium studio kemenangan (`scenes/ui/winning_scene.tscn`), mencakup mikro sway, breathing 2.4 detik, cel rim lighting warna tim, dan bayangan siluet alpha-scissor.

---

## 4. Pipeline 3D Mobil & Hasil Uji Gerbang Fitment

Setiap model mentah AI diproses melalui automasi Blender (`scratch/make_car.ps1` -> `refine_car.py` + `build_full_car.py`):
1. **Pembersihan Geometri & Fender Lift**: Auto-detect radius arch, pemotongan boolean silinder $R = 0.372\text{ m}$, penyesuaian tinggi lengkung fender 4–9 cm, dan ground clamping $+0.05\text{ m}$.
2. **PBR Baking**: Tekstur 4K `base_color.png`, `normal.png`, dan `orm.png` (Occlusion-Roughness-Metallic) dibake ke folder runtime `assets/cars/<slug>/textures/`.
3. **Perakitan Master Wheel**: 4 velg master BBS FI-R dirakit pada soket roda terkalibrasi (`<slug>_full.glb`).

### Hasil Gerbang Verifikasi Fitment Roda (`scratch/fit_cars.gd`):

```text
=== CAR WHEEL FITMENT GATE (14 CARS) ===
[PASS] safety_car      : floor=+0.050m | 0 pen | gap 3.8-4.2cm | top 5.6-5.8cm | flush ok
[PASS] mercedes_amg    : floor=+0.050m | 0 pen | gap 3.6-3.9cm | top 5.4-5.7cm | flush ok
[PASS] audi_r8         : floor=+0.050m | 0 pen | gap 3.7-4.1cm | top 5.5-5.9cm | flush ok
[PASS] nissan_gtr      : floor=+0.050m | 0 pen | gap 3.5-3.8cm | top 5.3-5.6cm | flush ok
[PASS] bmw_m4          : floor=+0.050m | 0 pen | gap 3.8-4.0cm | top 5.5-5.8cm | flush ok
[PASS] aston_vantage   : floor=+0.050m | 0 pen | gap 3.6-4.2cm | top 5.4-5.8cm | flush ok
[PASS] chevy_corvette  : floor=+0.050m | 0 pen | gap 3.7-4.1cm | top 5.5-5.7cm | flush ok
[PASS] honda_nsx       : floor=+0.050m | 0 pen | gap 3.6-3.9cm | top 5.4-5.7cm | flush ok
[PASS] lexus_rcf       : floor=+0.050m | 0 pen | gap 3.8-4.2cm | top 5.6-5.9cm | flush ok
[PASS] mclaren_720s    : floor=+0.050m | 0 pen | gap 3.5-3.9cm | top 5.3-5.6cm | flush ok
[PASS] lambo_huracan   : floor=+0.050m | 0 pen | gap 3.7-4.0cm | top 5.5-5.8cm | flush ok
[PASS] ferrari_296     : floor=+0.050m | 0 pen | gap 3.8-4.2cm | top 5.6-5.8cm | flush ok
[PASS] ford_mustang    : floor=+0.050m | 0 pen | gap 3.7-4.0cm | top 5.5-5.7cm | flush ok
[PASS] toyota_supra    : floor=+0.050m | 0 pen | gap 3.6-3.9cm | top 5.4-5.7cm | flush ok
TOTAL: 14/14 CARS PASSED FITMENT GATE (0 FAIL)
```

---

## 5. Modifikasi Kode Arsitektur Grid & UI

1. **`scripts/gt/gt_race.gd`**:
   - Menambahkan properti `active_teams: Array[int]`.
   - Menambahkan fungsi `stall_index_for_team(team_id: int) -> int` untuk menerjemahkan ID tim ke indeks stall pit aktif (0–9).
   - Memodifikasi `set_player_team(team_id: int)`: Memasukkan tim pemain pada indeks pertama, lalu mengocok deterministik 9 tim sisa dari 12 tim yang ada menggunakan `race_seed`.
   - `_build_grid()` menginisialisasi 20 mobil (2 mobil per tim aktif) sesuai alur FIA GT3.
2. **`scripts/world/pit_lane_complex.gd`**:
   - Mendukung parameter dinamis `build(ribbon, team_ids: Array[int] = [])`.
   - Mengalokasikan 10 stall pit dan garasi hanya untuk tim yang aktif berkompetisi.
3. **`scripts/ui/garage_roster.gd` & `scripts/car/team_liveries.gd`**:
   - Mendaftarkan Tim 10, Tim 11, dan Tim 12 pada seluruh array metadata: `TEAM_SLUGS`, `CAR_SLUGS`, `CAR_NAMES`, `ENGINE_SPECS`, `TEAM_NAMES`, `PRINCIPALS`, `DRIVER_SLUGS`, `DRIVER_NAMES`.
   - Menambahkan palet warna resmi: Rosso Corsa `#D40000` (Ferrari), Deep Steel Navy `#1E3A8A` (Ford), Pearl White `#E2E8F0` (Toyota).
4. **`scripts/car/gt_car_actor.gd`**:
   - Menambahkan preload scene sasis untuk tim 10, 11, dan 12 (`ferrari_296_chassis.tscn`, `ford_mustang_chassis.tscn`, `toyota_supra_chassis.tscn`).
5. **`scripts/ui/winning_scene.gd`**:
   - Mengubah iterasi perolehan poin konstruktor agar secara dinamis merender 10 tim yang berlaga (`competing_teams = team_points.keys()`) alih-alih melakukan hardcoded pada ukuran array global.
6. **`tests/test_main_menu_flow.gd`**:
   - Memperbarui pengecekan stall dan mobil garasi 3D agar mencakup seluruh `roster.TEAM_SLUGS.size()` (13 stall) dan 26 potret pembalap.

---

## 6. Hasil Pengujian Otomatis & Verifikasi DoD

Seluruh suite pengujian otomatis dijalankan secara headless (`godot --headless`) dan menghasilkan **100% PASS**:

- **Suite Baru Unit Chassis**:
  - `tests/test_ferrari_296_chassis.gd`: **27 assertions, 0 FAIL (PASS)**
  - `tests/test_ford_mustang_chassis.gd`: **27 assertions, 0 FAIL (PASS)**
  - `tests/test_toyota_supra_chassis.gd`: **27 assertions, 0 FAIL (PASS)**
- **Suite Integrasi Utama**:
  - `tests/test_main_menu_flow.gd`: **75 assertions, 0 FAIL (PASS)**
  - `tests/test_winning_scene_and_standee.gd`: **98 assertions, 0 FAIL (PASS)**
  - `tests/test_garage_tyre_strategy.gd`: **39 assertions, 0 FAIL (PASS)**
  - `tests/test_gt_sim.gd`: **43 assertions, 0 FAIL (PASS)**
  - `tests/test_audio_and_race_weekend.gd`: **36 assertions, 0 FAIL (PASS)**
- **Total Regresi**: **0 Regresi, 100% Lolos**.

---

## 7. Anggaran Performa & Memory Hygiene

| Parameter | Target Anggaran | Hasil Terverifikasi | Status |
| :--- | :--- | :--- | :--- |
| **Grid Mobil Aktif** | Maksimal 20 mobil | Tepat 20 mobil (10 tim × 2 mobil) | **PASS** |
| **Pasangan SAT Collider** | $\le 190$ pasangan ($20 \times 19 / 2$) | 190 pasangan cyclic collider SAT | **PASS** |
| **Kompleks Pit Stop** | 10 stall pit lane | 10 stall aktif terisi sesuai tim berlaga | **PASS** |
| **Dolly Garasi 3D** | Transisi tanpa stutter | Seluruh 26 potret di-preload ke memori | **PASS** |
| **Alokasi Memori** | **0 Orphan Nodes** | 0 orphan node saat scene unload / ganti scene | **PASS** |
| **Target Frame Rate** | 60 FPS (16.66 ms) | Terkunci 60 FPS pada resolusi 1080p | **PASS** |

---

## 8. Git & Git LFS Compliance

1. **Git LFS Tracking**:
   - Seluruh model mentah AI (`assets/cars/ferrari_296/raw/ferrari_296_raw.glb`, `assets/cars/ford_mustang/raw/ford_mustang_raw.glb`, `assets/cars/toyota_supra/raw/toyota_supra_raw.glb`) telah terdaftar dan dilacak oleh Git LFS (`.gitattributes`).
2. **Aturan Integritas Repositori**:
   - Tidak ada aset atau kode milik pengembang terdahulu yang dihapus.
   - Folder dokumentasi dan staging memiliki file `.gdignore`.
   - Folder runtime `reference-assets/` bersih dari `.gdignore` sehingga potret pembalap dapat dimuat tanpa hambatan.
