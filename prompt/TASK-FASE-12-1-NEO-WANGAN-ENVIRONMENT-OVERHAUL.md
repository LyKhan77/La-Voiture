# TASK SPECIFICATION: FASE 12.1 — NEO-WANGAN ENVIRONMENT OVERHAUL & SHARED FIA PADDOCK KIT

**Task ID:** `TASK-FASE-12-1-NEO-WANGAN-ENVIRONMENT-OVERHAUL`  
**Assignee:** Senior Godot 4 3D Environment Technical Artist / Blender 5.2 Pipeline Engineer  
**Priority:** Critical (Visual Quality & Architectural Realism Remediation for Phase 12)  
**Pedoman Standar Sirkuit (6-Layer Guide):** [`Circuit-Environment-Component-Guide.md`](file:///D:/Occupation/Porto/genex/La_Voiture/Circuit-Environment-Component-Guide.md)  
**Rencana Implementasi Detail (TDD Plan):** [`docs/superpowers/plans/2026-10-27-fase-12-1-neo-wangan-environment-overhaul-plan.md`](file:///D:/Occupation/Porto/genex/La_Voiture/docs/superpowers/plans/2026-10-27-fase-12-1-neo-wangan-environment-overhaul-plan.md)  
**Aset Referensi Visual (Meshy AI 4-Views):** [`reference-assets/tracks/neo_wangan/`](file:///D:/Occupation/Porto/genex/La_Voiture/reference-assets/tracks/neo_wangan/)  
**Blender 5.2 CLI:** `"C:\Program Files\Blender Foundation\Blender 5.2\blender.exe"`  
**Godot Console:** `C:\Users\Lee\Downloads\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe` (atau alias `godot`)  

---

## 1. Latar Belakang & Akar Masalah (Root Cause Analysis Fase 12)

Pada Fase 12, lintasan [`scenes/race_world/neo_wangan_circuit.tscn`](file:///D:/Occupation/Porto/genex/La_Voiture/scenes/race_world/neo_wangan_circuit.tscn) secara fisika/simulasi telah berjalan baik (45/45 test suite PASS), namun hasil audit visual pada [`executor-report/screenshots/phases/phase-12-smoke-03-night-city.png`](file:///D:/Occupation/Porto/genex/La_Voiture/executor-report/screenshots/phases/phase-12-smoke-03-night-city.png), [`phase-12-neo-wangan-start.png`](file:///D:/Occupation/Porto/genex/La_Voiture/executor-report/screenshots/phases/phase-12-neo-wangan-start.png), [`phase-12-neo-wangan-bridge.png`](file:///D:/Occupation/Porto/genex/La_Voiture/executor-report/screenshots/phases/phase-12-neo-wangan-bridge.png), dan [`phase-12-neo-wangan-tunnel.png`](file:///D:/Occupation/Porto/genex/La_Voiture/executor-report/screenshots/phases/phase-12-neo-wangan-tunnel.png) menunjukkan **4 cacat struktural fatal**:

1. **Jalan Melayang di Atas Laut Kosong (Void Gap 70–250 m):**
   - [`scripts/world/circuits/neo_wangan/neo_wangan_environment.gd`](file:///D:/Occupation/Porto/genex/La_Voiture/scripts/world/circuits/neo_wangan/neo_wangan_environment.gd) menaruh `WaterPlane` di `y = -6.0` dan membatasi gedung pada `SKYLINE_MIN_RADIUS_M = 250.0` dan `SKYLINE_TRACK_CLEARANCE_M = 70.0`. Akibatnya, di kiri-kanan jalan 0–250 m hanya ada air gelap kosong tanpa pulau daratan (*urban ground slab*) atau gedung koridor jalan (*street canyon*).
2. **Aset Paddock & FIA Kit Fase 10 Tidak Di-reuse:**
   - Di Fase 10 (`Apex Ring`), kita sudah memiliki aset arsitektur 3D berkualitas tinggi: [`PitBuilding`](file:///D:/Occupation/Porto/genex/La_Voiture/scripts/world/paddock/pit_building.gd) (2 lantai kaca VIP + interior), [`MainGrandstand`](file:///D:/Occupation/Porto/genex/La_Voiture/scripts/world/paddock/main_grandstand.gd) (tribun bertingkat + kanopi + jumbotron), [`RaceControlTower`](file:///D:/Occupation/Porto/genex/La_Voiture/scripts/world/paddock/race_control_tower.gd) (menara observasi 26 m), dan [`StartGantry`](file:///D:/Occupation/Porto/genex/La_Voiture/scripts/world/shared/start_gantry.gd).
   - Namun [`scripts/world/circuits/neo_wangan/neo_wangan_pit_complex.gd`](file:///D:/Occupation/Porto/genex/La_Voiture/scripts/world/circuits/neo_wangan/neo_wangan_pit_complex.gd) hanya membuat kotak hitam 1 lantai (`BoxMesh`) dengan 10 kotak cyan datar tanpa Grandstand, tanpa Race Control Tower, dan tanpa Catch Fence.
3. **Landmark Hanya Kotak `BoxMesh` Mentah Tanpa Konteks Sipil:**
   - Terowongan underpass (`_build_tunnel()`) tampak seperti kotak kardus tipis di jalan terbuka tanpa struktur jalan layang/plaza kota di atas atapnya.
   - Jembatan Shuto Bay (`_build_bridge()`) tidak memiliki menara kabel suspensi (*suspension pylons*), kabel baja diagonal (*stay cables*), maupun rangka baja samping.
   - Seluruh 110 gedung hanya `BoxMesh` polos.
4. **Light Pools Lampu Jalan Melayang di Luar Jalan:**
   - `_build_light_pools()` menaruh quad kuning `17m × 11m` tepat di posisi tiang (`lateral = ±6.9 m`), sehingga setengah lingkaran cahaya menggantung di udara kosong di luar tepi jembatan.

---

## 2. Tujuan & Sasaran Pekerjaan (4 Task Utama)

Implementasikan arsitektur **6-Lapis Lingkungan Sirkuit** sesuai [`Circuit-Environment-Component-Guide.md`](file:///D:/Occupation/Porto/genex/La_Voiture/Circuit-Environment-Component-Guide.md) dan [`docs/superpowers/plans/2026-10-27-fase-12-1-neo-wangan-environment-overhaul-plan.md`](file:///D:/Occupation/Porto/genex/La_Voiture/docs/superpowers/plans/2026-10-27-fase-12-1-neo-wangan-environment-overhaul-plan.md):

1. **Task 1 — Parameterisasi Shared FIA Paddock & Trackside Kit (Backward-Compatible dengan Apex Ring):**
   - Tambahkan `@export` terparameterisasi pada [`scripts/world/paddock/pit_building.gd`](file:///D:/Occupation/Porto/genex/La_Voiture/scripts/world/paddock/pit_building.gd) (`building_length_m = 164.0`, `bay_count = 10`, `bay_stride_m = 16.0`, `accent_color`), [`scripts/world/paddock/main_grandstand.gd`](file:///D:/Occupation/Porto/genex/La_Voiture/scripts/world/paddock/main_grandstand.gd) (`stand_length_m = 220.0`, `accent_color`), dan [`scripts/world/paddock/race_control_tower.gd`](file:///D:/Occupation/Porto/genex/La_Voiture/scripts/world/paddock/race_control_tower.gd) (`accent_color`).
   - Upgrade [`scripts/world/circuits/neo_wangan/neo_wangan_pit_complex.gd`](file:///D:/Occupation/Porto/genex/La_Voiture/scripts/world/circuits/neo_wangan/neo_wangan_pit_complex.gd) agar menginstansiasi `PitBuilding` (`building_length_m = 124.0`, `bay_stride_m = 12.0`, `accent_color = Color(0.0, 0.94, 1.0)`), `MainGrandstand` (`stand_length_m = 140.0` di seberang main straight `x = +21.5 m` menghadap barat), dan `RaceControlTower` di ujung utara pit building (`z = 76.0`).
   - Tulis & jalankan unit test `tests/test_shared_paddock_kit.gd`.

2. **Task 2 — Blender 5.2 Modular Architectural Asset Pipeline (`tools/build_neo_wangan_assets.py`):**
   - Buat skrip generator Blender 5.2 headless yang mengekspor 6 model `.glb` ke `assets/tracks/neo_wangan/models/`:
     1. `shuto_bridge_pylon.glb`: Menara kembar H-frame jembatan gantung (`44m` lebar × `65m` tinggi) dengan portal crossbeams & 16 kabel baja suspensi diagonal (`StayCablesMat`).
     2. `tunnel_portal_overpass.glb`: Portal terowongan beton brutalist dengan retaining wall samping, ventilasi jet-fan, dan deck jembatan/plaza bangunan di atas atapnya.
     3. `harbor_gantry_crane.glb`: Derek kontainer pelabuhan merah-putih (`28m` tinggi, boom `32m`) + tumpukan kontainer kargo (`HarborCraneMat`).
     4. `skyscraper_tower_a.glb`: Gedung pencakar langit berjenjang (*stepped cyberpunk tower*) dengan menara antena & helipad.
     5. `skyscraper_tower_b.glb`: Gedung perkantoran sudut miring (*chamfered office tower*) dengan crown neon & billboard frame.
     6. `skyscraper_tower_c.glb`: Gedung komersial podium + menara kembar medium untuk koridor tepi jalan.
   - Tulis & jalankan unit test `tests/test_neo_wangan_glb_assets.gd`.

3. **Task 3 — Ground Massing (Urban Island Slab), Street-Canyon Corridor & Landmark Placement:**
   - Perombakan menyeluruh [`scripts/world/circuits/neo_wangan/neo_wangan_environment.gd`](file:///D:/Occupation/Porto/genex/La_Voiture/scripts/world/circuits/neo_wangan/neo_wangan_environment.gd):
     * **Layer 1 (`UrbanIslandRoot`)**: Buat `UrbanGroundSlab` (pulau reklamasi beton + seawall apron di elevasi `y = -0.35 m` di bawah Sektor 1 Start/Pit, Sektor 2 Chicane/Tunnel, dan Sektor 3 Harbor Hairpin) serta `TunnelOverpassPlaza` di atas atap terowongan (`s = 1480..1660 m`, `y = +5.3 m`) sehingga terowongan benar-benar menembus kolong kota, dan hanya segmen Shuto Bay Bridge (`s = 500..1120 m`) yang melintasi air teluk terbuka.
     * **Layer 4 (`HeroLandmarksRoot`)**: Pasang 2 menara `shuto_bridge_pylon.glb` di `s = 640 m` dan `s = 980 m` lengkap dengan pagar rangka baja samping jembatan (`BridgeSideTrussMM`); pasang `tunnel_portal_overpass.glb` di portal masuk (`s = 1480 m`) dan keluar (`s = 1660 m`) terowongan; pasang 4 unit `harbor_gantry_crane.glb` di dermaga Harbor Hairpin (`s = 2250..2680 m`).
     * **Layer 5 (`MidgroundCorridorRoot` — Street Canyon 14–45 m)**: Tempatkan minimal **48 gedung koridor tepi jalan** (menggunakan mesh `skyscraper_tower_a/b/c.glb` via `MultiMeshInstance3D`) tepat di belakang pagar pembatas pada jarak `14 m .. 45 m` dari garis tengah jalan di sepanjang daratan (`s = 0..460 m`, `s = 1150..2200 m`, `s = 2650..3150 m`), ditambah **24 panel Neon Billboard** (`StreetBillboardMM`) dengan warna Cyan `#00F0FF`, Magenta `#FF1E56`, dan Acid Lime `#CCFF00` menghadap kamera lintasan.
     * **Perbaikan Light Pools**: Geser posisi quad cahaya `_build_light_pools()` ke `lateral = ±3.2 m` (di atas permukaan aspal di bawah lengan lampu) dengan ukuran `9.0 m × 5.5 m` agar **0% cahaya melayang di luar jalan**.

4. **Task 4 — Verifikasi 6-Camera Visual Gate, Performa & Regresi Penuh:**
   - Update `scratch/capture_phase12_views.gd` untuk merender **6 Camera Gates wajib** pada resolusi 1920×1080 ke `executor-report/screenshots/phases/`:
     * `phase-12-1-cam1-start-paddock.png` (Start Straight, FIA Gantry, 2-Story Pit Building, Main Grandstand, Race Control Tower)
     * `phase-12-1-cam2-shuto-bridge.png` (Shuto Bay Bridge, Twin Suspension Pylons, Stay Cables, Bay Water)
     * `phase-12-1-cam3-tunnel-chicane.png` (Tunnel Portal Entrance, Overpass City Plaza Above Roof, Street Canyon)
     * `phase-12-1-cam4-harbor-hairpin.png` (Harbor Hairpin Turn 10, Gantry Cranes, Container Yard, Pit Entry)
     * `phase-12-1-cam5-aerial-overview.png` (**WAJIB — Helicopter Bird's-Eye View** untuk membuktikan jalan menapak di atas Urban Island Slab & tidak melayang di ruang hampa)
     * `phase-12-1-cam6-chase-cam-action.png` (**WAJIB — Player Chase Cam 20 GT3 Cars** untuk membuktikan koridor gedung kiri-kanan padat)

---

## 3. Batasan Kritis (Critical Constraints)

> [!CAUTION]
> 1. **PRESERVASI APEX RING & SPLINE NEO-WANGAN:** Jangan memodifikasi spline `scenes/race_world/track_circuit.tscn` maupun koordinat titik tengah spline `NeoWanganCircuitBuilder`. Parameterisasi `PitBuilding`, `MainGrandstand`, dan `RaceControlTower` wajib memiliki nilai default yang 100% identik dengan Fase 10 (`test_track_environment_upgrade.gd` wajib tetap PASS).
> 2. **INSPEKSI VISUAL WAJIB SEBELUM KLAIM SELESAI:** Setelah menjalankan `capture_phase12_views.gd`, eksekutor **wajib membuka dan memeriksa keenam gambar PNG** (`phase-12-1-cam1..6-*.png`). Pastikan tidak ada gedung yang menembus jalan aspal, tidak ada jalan darat yang menggantung di atas air tanpa *UrbanGroundSlab*, dan *light pools* berada tepat di atas aspal.
> 3. **ANGGARAN PERFORMA 60 FPS:** Total draw calls environment Neo-Wangan wajib $\le 160$ draw calls dan poligon lingkungan $\le 320.000$ tris. Gunakan `MultiMeshInstance3D` untuk gedung koridor dan skyline.
> 4. **ZERO REGRESSION (47/47 TEST SUITES PASS):** Seluruh 45 test suite lama + 2 test suite baru (`test_shared_paddock_kit.gd`, `test_neo_wangan_glb_assets.gd`) wajib **100% PASS (0 FAIL)**.

---

## 4. Checklist Eksekusi (Step-by-Step)

Silakan ikuti kode lengkap dan langkah TDD di [`docs/superpowers/plans/2026-10-27-fase-12-1-neo-wangan-environment-overhaul-plan.md`](file:///D:/Occupation/Porto/genex/La_Voiture/docs/superpowers/plans/2026-10-27-fase-12-1-neo-wangan-environment-overhaul-plan.md):

- [ ] **Task 1: Parameterisasi Shared FIA Paddock & Trackside Kit**
  - Buat `tests/test_shared_paddock_kit.gd`.
  - Parameterisasi `scripts/world/paddock/pit_building.gd`, `main_grandstand.gd`, `race_control_tower.gd`.
  - Integrasikan ke `scripts/world/circuits/neo_wangan/neo_wangan_pit_complex.gd`.
  - Jalankan `test_shared_paddock_kit.gd` dan `test_track_environment_upgrade.gd` $\rightarrow$ PASS, commit.
- [ ] **Task 2: Blender 5.2 Modular Architectural Asset Pipeline**
  - Buat `tests/test_neo_wangan_glb_assets.gd`.
  - Buat `tools/build_neo_wangan_assets.py` dan jalankan via Blender 5.2 headless untuk menghasilkan 6 file `.glb` di `assets/tracks/neo_wangan/models/`.
  - Jalankan `godot --headless --path . --import` lalu `test_neo_wangan_glb_assets.gd` $\rightarrow$ PASS, commit.
- [ ] **Task 3: Ground Massing, Street-Canyon Corridor & Landmark Placement**
  - Perbarui `tests/test_neo_wangan_circuit.gd` dengan asersi 6-layer (`UrbanIslandRoot`, `HeroLandmarksRoot`, `MidgroundCorridorRoot` $\ge 48$ gedung, light pool bounds).
  - Rombak `scripts/world/circuits/neo_wangan/neo_wangan_environment.gd` untuk membangun pulau kota, jembatan pylon gantung, portal terowongan beratap plaza kota, derek pelabuhan, koridor gedung 14–45 m, dan 24 neon billboards.
  - Jalankan `test_neo_wangan_circuit.gd` $\rightarrow$ PASS, commit.
- [ ] **Task 4: Verifikasi 6-Camera Visual Gate, Smoke Test & Laporan Resmi**
  - Perbarui dan jalankan `scratch/capture_phase12_views.gd` (6 kamera 1920×1080).
  - Inspeksi visual keenam gambar `executor-report/screenshots/phases/phase-12-1-cam1..6-*.png`.
  - Jalankan seluruh 47 test suite headless (`100% PASS, 0 FAIL`).
  - Jalankan native smoke test 3 lap 20 mobil di Neo-Wangan (`60 FPS`, `0 orphan nodes`).
  - Tulis laporan eksekutif di `executor-report/reports/FASE-12-1-NEO-WANGAN-ENVIRONMENT-OVERHAUL-REPORT.md` dan update `ROADMAP.md`.

---

## 5. Perintah Terminal Pembantu (CLI Reference)

```powershell
# 1. Generate 6 model arsitektur .glb via Blender 5.2 Headless
& "C:\Program Files\Blender Foundation\Blender 5.2\blender.exe" --background --python tools/build_neo_wangan_assets.py

# 2. Import aset .glb baru ke Godot 4
godot --headless --path . --import

# 3. Menjalankan unit test spesifik Fase 12.1
godot --headless --path . -s res://tests/test_shared_paddock_kit.gd
godot --headless --path . -s res://tests/test_neo_wangan_glb_assets.gd
godot --headless --path . -s res://tests/test_neo_wangan_circuit.gd
godot --headless --path . -s res://tests/test_track_environment_upgrade.gd

# 4. Render 6 Camera Visual Verification Gates (1920x1080)
godot --path . -s res://scratch/capture_phase12_views.gd

# 5. Menjalankan seluruh 47 test suite otomatis
Get-ChildItem tests\test_*.gd | ForEach-Object { godot --headless --path . -s "res://tests/$($_.Name)" }
```
