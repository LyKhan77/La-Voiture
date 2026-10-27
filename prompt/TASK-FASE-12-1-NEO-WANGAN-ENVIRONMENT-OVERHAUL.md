# HANDOFF TUGAS EKSEKUTOR — FASE 12.1: NEO-WANGAN ENVIRONMENT OVERHAUL & STANDARISASI MODULAR PADDOCK KIT

## 1. Konteks & Latar Belakang Masalah
Pada Fase 12, lintasan [`scenes/race_world/neo_wangan_circuit.tscn`](file:///D:/Occupation/Porto/genex/La_Voiture/scenes/race_world/neo_wangan_circuit.tscn) secara simulasi/fisika telah berjalan baik (45/45 test suite PASS), tetapi hasil audit visual pada screenshot [`executor-report/screenshots/phases/phase-12-smoke-03-night-city.png`](file:///D:/Occupation/Porto/genex/La_Voiture/executor-report/screenshots/phases/phase-12-smoke-03-night-city.png), [`phase-12-neo-wangan-start.png`](file:///D:/Occupation/Porto/genex/La_Voiture/executor-report/screenshots/phases/phase-12-neo-wangan-start.png), [`phase-12-neo-wangan-bridge.png`](file:///D:/Occupation/Porto/genex/La_Voiture/executor-report/screenshots/phases/phase-12-neo-wangan-bridge.png), dan [`phase-12-neo-wangan-tunnel.png`](file:///D:/Occupation/Porto/genex/La_Voiture/executor-report/screenshots/phases/phase-12-neo-wangan-tunnel.png) menunjukkan **4 cacat struktural fatal**:

1. **Jalan Melayang di Atas Laut Kosong (Void Gap 70–250 m):**
   - [`scripts/world/neo_wangan_environment.gd`](file:///D:/Occupation/Porto/genex/La_Voiture/scripts/world/neo_wangan_environment.gd) menaruh `WaterPlane` di `y = -6.0` dan membatasi gedung pada `SKYLINE_MIN_RADIUS_M = 250.0` dan `SKYLINE_TRACK_CLEARANCE_M = 70.0`. Akibatnya, di kiri-kanan jalan 0–250 m hanya ada air gelap kosong tanpa pulau daratan atau gedung koridor jalan.
2. **Aset Paddock & FIA Kit Fase 10 Tidak Di-reuse:**
   - Di Fase 10 (`Apex Ring`), kita sudah memiliki aset arsitektur 3D berkualitas tinggi: [`PitBuilding`](file:///D:/Occupation/Porto/genex/La_Voiture/scripts/world/paddock/pit_building.gd) (2 lantai kaca VIP + interior), [`MainGrandstand`](file:///D:/Occupation/Porto/genex/La_Voiture/scripts/world/paddock/main_grandstand.gd) (tribun bertingkat + kanopi + jumbotron), [`RaceControlTower`](file:///D:/Occupation/Porto/genex/La_Voiture/scripts/world/paddock/race_control_tower.gd) (menara observasi 26 m), dan [`StartGantry`](file:///D:/Occupation/Porto/genex/La_Voiture/scripts/world/start_gantry.gd).
   - Namun [`scripts/world/neo_wangan_pit_complex.gd`](file:///D:/Occupation/Porto/genex/La_Voiture/scripts/world/neo_wangan_pit_complex.gd) hanya membuat kotak hitam 1 lantai (`BoxMesh`) dengan 10 kotak cyan datar tanpa Grandstand, tanpa Race Control Tower, dan tanpa Catch Fence.
3. **Landmark Hanya Kotak `BoxMesh` Mentah Tanpa Konteks Sipil:**
   - Terowongan underpass (`_build_tunnel()`) tampak seperti kotak kardus tipis di jalan terbuka tanpa struktur jalan layang/plaza kota di atas atapnya.
   - Jembatan Shuto Bay (`_build_bridge()`) tidak memiliki menara kabel suspensi (pylons), kabel baja diagonal, maupun rangka baja samping.
   - Seluruh 110 gedung hanya `BoxMesh` polos.
4. **Light Pools Lampu Jalan Melayang di Luar Jalan:**
   - `_build_light_pools()` menaruh quad kuning `17m × 11m` tepat di posisi tiang (`lateral = ±6.9 m`), sehingga setengah lingkaran cahaya menggantung di udara kosong di luar tepi jembatan.

---

## 2. Dokumen Acuan Wajib (Baca Sebelum Menulis Kode)
1. **Pedoman Arsitektur 6-Lapis Sirkuit Resmi:** [`Circuit-Environment-Component-Guide.md`](file:///D:/Occupation/Porto/genex/La_Voiture/Circuit-Environment-Component-Guide.md)
2. **Rencana Implementasi TDD Detail (Step-by-Step):** [`docs/superpowers/plans/2026-10-27-fase-12-1-neo-wangan-environment-overhaul-plan.md`](file:///D:/Occupation/Porto/genex/La_Voiture/docs/superpowers/plans/2026-10-27-fase-12-1-neo-wangan-environment-overhaul-plan.md)
3. **Referensi Visual Kanon Neo-Wangan (`reference-assets/tracks/neo_wangan/`):**
   - `view1_main_straight_pitstop.png` (Start straight, gantry, pit building 2 lantai, grandstand, gedung padat di tepi jalan)
   - `view2_shuto_bay_bridge.png` (Jembatan kabel suspensi 2 pylon raksasa melintasi teluk Tokyo)
   - `view3_underpass_tunnel_chicane.png` (Portal terowongan beton di bawah plaza/overpass kota bertingkat)
   - `view4_harbor_hairpin_pit_entry.png` (Area dermaga kontainer pelabuhan dengan gantry crane merah-putih)

---

## 3. Daftar Pekerjaan Utama (4 Task Terstruktur)

### Task 1: Parameterisasi Shared FIA Paddock & Trackside Kit (Backward-Compatible dengan Apex Ring)
Ikuti instruksi di [`docs/superpowers/plans/2026-10-27-fase-12-1-neo-wangan-environment-overhaul-plan.md`](file:///D:/Occupation/Porto/genex/La_Voiture/docs/superpowers/plans/2026-10-27-fase-12-1-neo-wangan-environment-overhaul-plan.md) (Task 1):
- Tambahkan `@export` terparameterisasi pada:
  * [`scripts/world/paddock/pit_building.gd`](file:///D:/Occupation/Porto/genex/La_Voiture/scripts/world/paddock/pit_building.gd): `building_length_m` (default `164.0`), `bay_count` (default `10`), `bay_stride_m` (default `16.0`), `accent_color` (default `Color(0.86, 0.14, 0.18)`).
  * [`scripts/world/paddock/main_grandstand.gd`](file:///D:/Occupation/Porto/genex/La_Voiture/scripts/world/paddock/main_grandstand.gd): `stand_length_m` (default `220.0`), `accent_color`.
  * [`scripts/world/paddock/race_control_tower.gd`](file:///D:/Occupation/Porto/genex/La_Voiture/scripts/world/paddock/race_control_tower.gd): `accent_color`.
- Upgrade [`scripts/world/neo_wangan_pit_complex.gd`](file:///D:/Occupation/Porto/genex/La_Voiture/scripts/world/neo_wangan_pit_complex.gd) agar menginstansiasi `PitBuilding` (`building_length_m = 124.0`, `bay_stride_m = 12.0`, `accent_color = Color(0.0, 0.94, 1.0)`), `MainGrandstand` (`stand_length_m = 140.0` di seberang main straight `x = +21.5 m` menghadap barat), dan `RaceControlTower` di ujung utara pit building (`z = 76.0`).
- Verifikasi dengan unit test `tests/test_shared_paddock_kit.gd`.

### Task 2: Blender 5.2 Modular Architectural Asset Pipeline (`tools/build_neo_wangan_assets.py`)
Buat dan jalankan generator aset Blender 5.2 headless (`blender --background --python tools/build_neo_wangan_assets.py`) yang menghasilkan 6 model `.glb` di `assets/tracks/neo_wangan/models/`:
1. `shuto_bridge_pylon.glb`: Menara kembar H-frame jembatan gantung (`44m` lebar × `65m` tinggi) dengan portal crossbeams dan 16 kabel baja suspensi diagonal (`StayCablesMat`).
2. `tunnel_portal_overpass.glb`: Portal terowongan beton brutalist dengan retaining wall samping, ventilasi jet-fan, dan deck jembatan/plaza bangunan di atas atapnya.
3. `harbor_gantry_crane.glb`: Derek kontainer pelabuhan merah-putih (`28m` tinggi, boom `32m`) + tumpukan kontainer kargo (`HarborCraneMat`).
4. `skyscraper_tower_a.glb`: Gedung pencakar langit berjenjang (stepped cyberpunk tower) dengan menara antena & helipad.
5. `skyscraper_tower_b.glb`: Gedung perkantoran sudut miring (chamfered office tower) dengan crown neon & billboard frame.
6. `skyscraper_tower_c.glb`: Gedung komersial podium + menara kembar medium untuk koridor tepi jalan.
- Verifikasi dengan unit test `tests/test_neo_wangan_glb_assets.gd`.

### Task 3: Ground Massing (Urban Island Slab), Street-Canyon Corridor & Landmark Placement
Perombakan menyeluruh [`scripts/world/neo_wangan_environment.gd`](file:///D:/Occupation/Porto/genex/La_Voiture/scripts/world/neo_wangan_environment.gd):
1. **Layer 1 (`UrbanIslandRoot`)**: Buat `UrbanGroundSlab` (pulau reklamasi beton + seawall apron di elevasi `y = -0.35 m` di bawah Sektor 1 Start/Pit, Sektor 2 Chicane/Tunnel, dan Sektor 3 Harbor Hairpin) serta `TunnelOverpassPlaza` di atas atap terowongan (`s = 1480..1660 m`, `y = +5.3 m`) sehingga terowongan benar-benar menembus kolong kota, dan hanya segmen Shuto Bay Bridge (`s = 500..1120 m`) yang melintasi air teluk terbuka.
2. **Layer 4 (`HeroLandmarksRoot`)**:
   - Pasang 2 menara `shuto_bridge_pylon.glb` di `s = 640 m` dan `s = 980 m` lengkap dengan pagar rangka baja samping jembatan (`BridgeSideTrussMM`).
   - Pasang `tunnel_portal_overpass.glb` di portal masuk (`s = 1480 m`) dan keluar (`s = 1660 m`) terowongan.
   - Pasang 4 unit `harbor_gantry_crane.glb` di dermaga Harbor Hairpin (`s = 2250..2680 m`).
3. **Layer 5 (`MidgroundCorridorRoot` — Street Canyon 14–45 m)**:
   - Tempatkan minimal **48 gedung koridor tepi jalan** (menggunakan mesh `skyscraper_tower_a/b/c.glb` via `MultiMeshInstance3D`) tepat di belakang pagar pembatas pada jarak `14 m .. 45 m` dari garis tengah jalan di sepanjang daratan (`s = 0..460 m`, `s = 1150..2200 m`, `s = 2650..3150 m`).
   - Tambahkan **24 panel Neon Billboard** (`StreetBillboardMM`) dengan teks/grafis streetwear Jepang yang memancarkan warna Cyan `#00F0FF`, Magenta `#FF1E56`, dan Acid Lime `#CCFF00` menghadap kamera lintasan.
4. **Perbaikan Light Pools**:
   - Geser posisi quad cahaya `_build_light_pools()` ke `lateral = ±3.2 m` (di atas permukaan aspal di bawah lengan lampu) dengan ukuran `9.0 m × 5.5 m` agar **0% cahaya melayang di luar jalan**.

### Task 4: Verifikasi 6-Camera Visual Gate, Performa & Regresi Penuh
1. Update `scratch/capture_phase12_views.gd` untuk merender **6 Camera Gates wajib** pada resolusi 1920×1080 ke `executor-report/screenshots/phases/`:
   - `phase-12-1-cam1-start-paddock.png` (Start Straight, FIA Gantry, 2-Story Pit Building, Main Grandstand, Race Control Tower)
   - `phase-12-1-cam2-shuto-bridge.png` (Shuto Bay Bridge, Twin Suspension Pylons, Stay Cables, Bay Water)
   - `phase-12-1-cam3-tunnel-chicane.png` (Tunnel Portal Entrance, Overpass City Plaza Above Roof, Street Canyon)
   - `phase-12-1-cam4-harbor-hairpin.png` (Harbor Hairpin Turn 10, Gantry Cranes, Container Yard, Pit Entry)
   - `phase-12-1-cam5-aerial-overview.png` (Helicopter Bird's-Eye View — membuktikan jalan menapak di atas Urban Island Slab & tidak melayang di ruang hampa)
   - `phase-12-1-cam6-chase-cam-action.png` (Player Chase Cam 20 GT3 Cars — membuktikan koridor gedung kiri-kanan padat)
2. **Inspeksi Visual Wajib:** Buka dan periksa keenam file PNG tersebut. Jangan klaim selesai jika masih ada jalan melayang di udara kosong atau bangunan yang memotong aspal lintasan!
3. **Anggaran Performa & Zero Regression:**
   - Environment draw calls $\le 160$, triangles $\le 320.000$.
   - Seluruh **47 test suite headless** (`tests/test_*.gd`) wajib **100% PASS (0 FAIL)**.
   - Native smoke test 3 lap 20 mobil GT3 di Neo-Wangan (`60 FPS` target, `0 orphan nodes`).
   - Tulis laporan eksekutif di `executor-report/reports/FASE-12-1-NEO-WANGAN-ENVIRONMENT-OVERHAUL-REPORT.md`.
