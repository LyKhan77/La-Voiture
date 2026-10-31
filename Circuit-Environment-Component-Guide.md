# Panduan Resmi Arsitektur & Alur Kerja Sirkuit 3D (`Circuit-Environment-Component-Guide` v2.0)

> **Dokumen Pendamping:** [`Full-Car-Component-Guide.md`](file:///D:/Occupation/Porto/genex/La_Voiture/Full-Car-Component-Guide.md) · [`DESIGN.md`](file:///D:/Occupation/Porto/genex/La_Voiture/DESIGN.md) · [`ROADMAP.md`](file:///D:/Occupation/Porto/genex/La_Voiture/ROADMAP.md)

Dokumen ini adalah standar baku (*Single Source of Truth*) untuk perancangan, pemodelan aset 3D, perakitan scene, gaya visual **Cel-Shaded / Toon Anime**, dan verifikasi visual seluruh **12 Sirkuit Kejuaraan Resmi** di *La Voiture*.

---

## 1. Filosofi Utama: Arsitektur 2-Tier (**Reusable Core Kit** vs **Improvised Biome Decorator**)

Agar pembangunan 12 sirkuit berjalan cepat, konsisten, dan bebas duplikasi kode ribuan baris, setiap map sirkuit dibagi secara tegas menjadi **2 Tier**:

```mermaid
flowchart TD
    Spline["TrackRibbon (Curve3D Spline Unik + Evaluasi Elevasi per Sirkuit)"]
    Spline --> TierA
    Spline --> TierB

    subgraph TierA["TIER A: REUSABLE CORE KIT (100% Dipakai Ulang di Semua 12 Map)"]
        A1["1. Track Corridor Kit<br/>• RoadMesh (road_asphalt.gdshader + Wet Puddles)<br/>• RubberGroove & 3D Kerbs (Sawtooth GP / Street)<br/>• Runoff & Gravel / Concrete Barriers<br/>• Armco, Tecpro, CatchFence, Braking Boards (150/100/50m)"]
        A2["2. Shared FIA Paddock & Infrastructure Kit<br/>• StartGantry (5 Pasang Lampu Merah FIA)<br/>• ApexPitComplex (Entry, Fast Lane, 10 Pit Boxes, Exit)<br/>• PitBuilding 2F + MainGrandstand (Live Jumbotron) + RaceControlTower<br/>• Floodlight Towers / Streetlights (Otomatis ON saat Sunset/Night/Storm)"]
        A3["3. Shared Cel-Skybox & Multi-Time-of-Day Ambience<br/>• SharedCelSkyController (Mendukung DAY, SUNSET, NIGHT, RANDOM)<br/>• Anime Sun (Day/Sunset) ↔ Halftone Moon + Dual Halo (Night)<br/>• 900 Twinkling Manga Stars (Auto-hide saat Day)<br/>• 28 Gugus Awan 3D Cel-Shaded & Wind Banners (Bereaksi ke wind_speed)"]
    end

    subgraph TierB["TIER B: IMPROVISED BIOME & LANDMARK DECORATOR (Kustom Sesuai Concept Art Map)"]
        B1["4. Ground Massing, Water & Terrain<br/>• GP/Alpine/Forest: Kontur Bukit, Rumput Toon, MountainVista Ring<br/>• Urban/Harbor/Marina: Urban Island Slab, Seawall, Stepped Toon Bay Water<br/>• Desert: Sand Dunes & Oasis Rock Formations"]
        B2["5. Biome Vegetation & Near-Track Props<br/>• FoliageScatter (Cedar/Oak/Pine/Sakura/Palm/Cypress dengan Wind Sway)<br/>• Street Corridor Towers & Kanji/Sponsor Halftone Billboards"]
        B3["6. Hero Landmarks (2–4 Landmark Ikonik Blender 5.2 .glb)<br/>• Jembatan Gantung, Portal Terowongan, Kran Pelabuhan, Kastil, Casino Arch"]
    end
```

### Aturan Emas Pembagian Tier A vs Tier B:
1. **Jangan Pernah Menulis Ulang Tier A per Sirkuit:**
   - Area lintasan (`RoadMesh`, `Kerbs`, `Barriers`, `CatchFence`, `BrakingMarkers`), infrastruktur paddock FIA (`PitBuilding`, `MainGrandstand`, `RaceControlTower`, `StartGantry`), dan langit (`SharedCelSkyController`) **wajib menggunakan komponen bersama (reusable)** yang otomatis membentuk dirinya mengikuti bentuk spline `TrackRibbon` sirkuit tersebut.
2. **Improvisasi Kreatif Difokuskan 100% pada Tier B:**
   - Saat membangun map baru dari gambar referensi (`reference-assets/tracks/<slug>/concept_key_visual.png`), pembuat map cukup mengimprovisasi **Terrain/Air**, **Vegetasi Biome**, dan **2–4 Hero Landmarks** unik yang memberi jiwa pada sirkuit tersebut.
3. **Semua Sirkuit Wajib Mendukung 3 Segmen Waktu (`DAY`, `SUNSET`, `NIGHT`, + `RANDOM`):**
   - Melalui `SharedCelSkyController` dan parameter `time_of_day` dari `GtWeather`, setiap map wajib tampil hidup dan koheren baik saat Siang (`DAY`), Senja Keemasan (`SUNSET`), maupun Malam (`NIGHT`).

---

## 2. Standar Wajib Gaya Visual: **Cel-Shaded Anime × Manga Inking × Halftone**

Seluruh elemen lingkungan (baik Tier A maupun Tier B) **wajib lulus pemeriksaan gaya visual Cel-Shaded Anime** berikut dan dilarang menggunakan material PBR mentah yang menghasilkan kilap plastik/realistis:

| Aspek Visual | Aturan Teknis Wajib di Godot 4 | Larangan Keras (Anti-Patterns) |
| :--- | :--- | :--- |
| **Shading Permukaan** | Wajib menggunakan `render_mode diffuse_toon, specular_toon` atau pita warna bertingkat tegas (*stepped cel bands* 2–3 tone). | Dilarang memakai `StandardMaterial3D` PBR reflektif (`metallic > 0.5, roughness < 0.3`) pada air atau gedung yang memantulkan bola putih silau. |
| **Garis Tinta (*Manga Ink Outline*)** | Gedung koridor, menara skyline, dan landmark utama wajib memiliki `next_pass` outline tinta hitam (`inverted_hull_outline.gdshader` atau `neo_wangan_skyline_outline.gdshader` di ruang dunia). | Dilarang membiarkan massa bangunan jauh menyatu tanpa kontur siluet terhadap langit. |
| **Pola *Halftone Screentone*** | Jendela gedung menyala, papan reklame/billboard, dan bayangan kawah bulan wajib menyertakan pola titik *Ben-Day halftone* prosedural di shader. | Dilarang membuat papan reklame berupa kotak warna polos (`BoxMesh` rata tanpa grafis/tipografi/bingkai). |
| **Permukaan Air (*Toon Water*)** | Air teluk/marina/danau wajib menggunakan shader stepped-toon (`neo_wangan_water.gdshader`) dengan pita gelombang yang bergerak mengikuti `wind_dir` & `wind_speed_kph`, serta warna yang beradaptasi terhadap `DAY` (biru laut + buih putih-cyan), `SUNSET` (lembayung-emas), dan `NIGHT` (biru malam + garis puncak neon). | Dilarang menggunakan bidang air statis tanpa gerakan gelombang angin. |
| **Ambience Langit & Angin Hidup** | Langit wajib memiliki **Matahari Anime (Day/Sunset) ↔ Bulan Halftone (Night)**, **900 Bintang Berkedip** (otomatis tersembunyi saat Siang), **28 Awan 3D Cel-Shaded** yang berputar mengelilingi horizon sesuai `wind_speed`, serta **bendera/pohon** yang berkibar mengikuti angin cuaca. | Dilarang menampilkan bulan/bintang di siang hari atau menyalakan lampu jalan/jendela malam secara penuh pada mode `DAY`. |

---

## 2b. Struktur Modul Sirkuit (wajib untuk sirkuit baru)

Setiap sirkuit adalah modul sendiri; kode bersama tidak boleh dipinjam dari sirkuit lain.

```
scripts/world/
├── circuits/
│   ├── base/      circuit_pit_complex.gd (kontrak pit), circuit_environment.gd (kontrak environment)
│   ├── apex_ring/    apex_pit_complex.gd, apex_environment.gd
│   ├── neo_wangan/   neo_wangan_circuit_builder.gd, neo_wangan_environment.gd, neo_wangan_pit_complex.gd
│   └── brianza/      brianza_circuit_builder.gd, brianza_environment.gd, brianza_pit_complex.gd,
│                     brianza_pit_dressing.gd, brianza_paddock.gd
├── shared/       # kit bersama: pit_kit, mesh_batch, toon_materials, foliage_scatter, geometri, langit, lampu,
│                 # furnitur trackside, start_gantry, pit_zone, mountain_vista
├── paddock/      # kit paddock bersama: pit_building, main_grandstand, race_control_tower, jumbotron,
│                 # team_signage, team_transporters
├── weekend/      # race_weekend_world, race_weekend_director, broadcast_camera_director (orkestrasi, tidak tahu sirkuit)
└── garage/       # garage_environment_builder (garasi 3D pada layar pilih tim)
scenes/race_world/circuits/<id>/        # <id>_circuit.tscn dan scene pit sirkuit itu
```

Aturan:
1. Nama berkas `<id>_<peran>.gd` dan kelas `<Id><Peran>` (`BrianzaPitComplex`, `ApexEnvironment`); folder `<id>` sama dengan id di `CircuitCalendarRegistry`.
2. Kompleks pit **mewarisi `CircuitPitComplex`**: isi `stalls` dan `garages` saat `build(ribbon, team_ids)` (box i melayani `stalls[i]["team"]`, garasi i berdiri di box i), isi `team_count`, `garage_front_m`, `stall_lane_m` di `_init()`, dan override hanya `_on_teams_assigned()` (segarkan fascia, kru, papan nama, transporter), `crew_spot()` bila garasi tidak standar, serta `sim_layout()` bila lane berbeda dari default Apex. Pencarian box, garasi, dan titik parkir (`stall_index_for_team`, `garage_for_team`, `stall_transform`) sudah ada di kelas dasar dan tidak ditulis ulang.
2b. Environment sirkuit **mewarisi `CircuitEnvironment`**: override `build(ribbon, source)` (set `built`), `bind_world()`, `update(delta, race)`, `apply_time_of_day(tod, gloom)` (kamus waktu dari `GtWeather.compute_time_of_day`), `apply_wind()`, `ground_y_at()` bila ada medan, dan `_extra_stats()`; isi `circuit_id` di `_init()`. Kelas dasar menyediakan `stats()` (`circuit_id`, `built`, `draw_calls`, `triangles`, `multimeshes`; ukuran statis tanpa bergantung kamera), `measure()`, dan `_feed_leaderboards()` untuk jumbotron. `flag_panels` (`FlagPanelSet`, panel bendera LED) wajib diisi oleh `build()`: tempatkan dengan `FlagPanelSet.plan(length, preferred)` lalu `build(length, anchors, poses)`, jauh dari terowongan, jembatan, tiang, dan papan (`tests/test_flag_panels_contract.gd`). `furniture` (Armco, Tecpro, papan rem, menara lampu) boleh null bila sirkuit punya barrier sendiri.
3. Fungsi gambar yang identik di semua sirkuit (`PitKit`: aspal, susunan kru, cat dan nomor box, perlengkapan garasi) dipakai dari `scripts/world/shared/pit_kit.gd`, bukan dari Apex.
4. `RaceWeekendWorld` memasang tim lewat `pit_lane.seat_teams(ribbon, active_teams)` untuk semua sirkuit; jangan menambah cabang per sirkuit di orkestrator.
5. Sirkuit baru wajib lulus `tests/test_pit_complex_contract.gd`, `test_circuit_environment_contract.gd`, `test_pit_team_assignment_contract.gd`, `test_team_signage_contract.gd`, dan `test_team_identity_consistency.gd` (tambahkan id-nya ke daftar `CIRCUITS` tes-tes itu).

## 3. Alur Kerja Standar Pembuatan Map Sirkuit Baru (Step-by-Step Workflow)

Setiap kali menambahkan atau merombak sirkuit di kalender 12 ronde, ikuti 5 tahapan baku berikut:

### Tahap 1: Concept Art & 4-View Visual Reference
1. Pastikan tersedia `concept_key_visual.png` dan 4 *View Gate References* (`view1_main_straight_pitstop`, `view2_sector1_landmark`, `view3_sector2_landmark`, `view4_sector3_pit_entry`) di `reference-assets/tracks/<slug>/`.
2. Identifikasi daftar aset **Tier B (Improvised Biome)**: jenis terrain/air, jenis pohon, dan 2–4 *Hero Landmarks* ikonik.

### Tahap 2: Track Spine (`Curve3D`) & Civil Ground Envelope
1. Bangun kurva tertutup `TrackRibbon` beserta profil elevasi (`Y`) dan daftar tikungan (`turns`).
2. Bangun penopang sipil kontinu (**Hukum Kontinuitas Sipil — 0 Floating Road**):
   - Daratan/pulau beton berbingkai *seawall* atau kontur bukit,
   - Dek jembatan + pilar hingga dasar air (`BASE_Y`),
   - Dinding *cut-and-cover* + massa plaza/bukit di atas atap terowongan.
3. Pada track berelevasi, uji segitiga mesh terrain yang benar-benar dirender: sampel jalan tiap maksimum 6 m pada lateral kiri, tengah, dan kanan, serta lebar pit dan apron. Permukaan tanah harus berada di bawah jalan; uji juga jarak verge ke ruas jalan lain dan platform penopang pit.

### Tahap 3: Pemasangan Otomatis **Tier A (Reusable Core Kit)**
1. Pasang **Track Corridor Kit** di sepanjang `TrackRibbon`: aspal (`road_asphalt.gdshader`), `RubberGroove`, `Kerbs`, `Barriers` (dengan celah otomatis di Pit Entry–Exit), `CatchFence`, dan `BrakingMarkers` (`150/100/50m`).
2. Pasang **Shared FIA Paddock Kit**: kompleks pit sirkuit itu (turunan `CircuitPitComplex`), `StartGantry`, `PitBuilding`, `MainGrandstand` (terhubung ke live standings `Jumbotron`), dan `RaceControlTower`.
3. Pasang **Shared Cel-Skybox (`SharedCelSkyController`)**: otomatis menyediakan Matahari/Bulan, 900 bintang berkedip, 28 awan 3D cel-shaded yang terdorong angin, serta respons pencahayaan `DAY / SUNSET / NIGHT`. Langit dan mood `WorldEnvironment` (sky, ambient, fog, matahari) digerakkan oleh `WorldSkyRig` (`scripts/world/shared/world_sky_rig.gd`): sirkuit hanya memberi profil `SKY_PROFILES` untuk DAY/SUNSET/NIGHT (lihat `NeoWanganEnvironment`, `BrianzaEnvironment`).
4. **Layout-Driven Reuse:** kirim `pit_layout` milik sirkuit ke komponen bersama; hindari konstanta sirkuit lain. Bentuk dan posisi mengikuti spline, kelengkungan, elevasi, dan jarak ke ruas lain. Komponen bersama boleh diperbaiki dengan regresi Apex dan Neo Wangan tetap hijau.
5. **Kontrak Tim–Box:** setiap balapan hanya 10 dari 13 tim yang berlomba (`GtRace.active_teams`). Box, garasi, kru, dan shutter dipetakan lewat `stall_index_for_team(team)` (-1 bila tidak punya box) dan `assign_teams(active_teams)`, bukan lewat id tim. Kompleks pit sirkuit baru wajib lulus `tests/test_pit_team_assignment_contract.gd`.
6. **Kontrak Nama Tim:** nama tim di aset ditulis lewat `scripts/world/paddock/team_signage.gd` (`add_plate`, `fascia_pose`, `commit_node`), bukan `Label3D`, supaya semua papan satu sirkuit tergabung di satu surface (satu draw call). Letakkan nama di elemen pertama yang menghadap lane: fascia garasi (mesh `TeamPlates` pada kompleks pit) atau, bila gedung pit berdiri tepat di depan fascia, pada pintu shutter (`PitBuilding.name_doors = true`). Transporter paddock memakai `commit_node(..., "TransporterPlates")` pada sisi yang menghadap trek. Hanya tim yang punya box (`active_teams`) mendapat papan, dan papan dibangun ulang saat `assign_teams`/`apply_teams`. Sirkuit baru wajib lulus `tests/test_team_signage_contract.gd`.
7. **Kontrak Objek Unik Tim:** setiap sirkuit wajib memiliki himpunan objek unik tim yang sama untuk tiap tim yang berlomba: nama (item 6), warna livery pada fascia atau strip pintu, kru standby berseragam tim (mesh `StandbyCrew` pada tiap garasi), cat kotak box, dan satu transporter per tim lewat `scripts/world/paddock/team_transporters.gd` (`build(ribbon, stalls, lateral_m, with_apron)`, `apply_teams(stalls)`). Sirkuit hanya menentukan jarak lateral baris transporter menurut spline-nya sendiri. Objek baru yang dijadikan unik tim harus murah (mewarnai mesh gabungan atau satu surface), tersedia di ketiga sirkuit lewat komponen bersama, dan hanya bergantung pada `active_teams`. Wajib lulus `tests/test_team_identity_consistency.gd`.
8. **Kontrak Antrean Pit:** `sim_layout()` wajib memuat `stall_pitch_m`, `queue_gap_m`, `stall_lane_m`, dan `fast_lane_m`. Sim menumpuk mobil kedua sebuah tim di `min(queue_gap_m, stall_pitch_m − panjang mobil − 0,5)` di belakang box agar tidak menimpa mobil di box sebelumnya, dan mobil yang menuju box-nya tidak ditahan oleh antrean di luar box itu. `tests/test_pit_queue_flow.gd` menguji logika ini pada ribbon Apex; sirkuit baru diverifikasi dengan `scratch/smoke_pit_race.gd -- <circuit_id>` (6 mobil ke box bersamaan: semua terlayani, 0 orphan). Pitch kotak sirkuit baru **20 m**: pitch 12–14 m gagal tes banjir pit (seluruh lapangan box bersamaan) di Monte, Brianza, Neo-Wangan, Apex, dan Ardennes. Tiap sirkuit memiliki `tests/test_<id>_pit_flood.gd` (pengukur bersama `tests/pit_flood_checks.gd`); layout pit paket mapgen diukur dengan tes itu sebelum dibangun, dan `fast_lane_m` dibaca sebagai pusat jalur cepat (bukan tepi dalam).

### Tahap 4: Perakitan **Tier B (Improvised Biome & Hero Landmarks)** & Shaders Cel-Shaded
1. Cetak 2–4 model `.glb` landmark khusus map via skrip Blender 5.2 (`tools/build_<slug>_assets.py`) ke `assets/tracks/<slug>/models/`.
2. Tempatkan landmark, vegetasi (`FoliageScatter`), atau koridor gedung + billboard Kanji/sponsor menggunakan `MultiMeshInstance3D` (per-distrik untuk frustum culling).
3. Pastikan seluruh shader bangunan, air, dan lampu jalan merespons parameter waktu `tod` (`DAY`, `SUNSET`, `NIGHT`) dan kecepatan angin `race.weather.wind_speed`.

### Tahap 5: Verifikasi 6-Camera Visual Gate, Multi-Time Gate & Performance Gate
Tambahkan flythrough setinggi chase camera setiap 150 m sepanjang lap dalam kedua arah, ditambah aerial pit/paddock dan entry/exit. Uji jalur pit sepanjang lane dengan clearance mobil terhadap armco, dinding, dan benda padat; inspeksi hasil pada `DAY`, `SUNSET`, dan `NIGHT`.
Sebelum sirkuit dinyatakan selesai, jalankan:
1. **Headless Test Suite:** Seluruh test suite di `tests/test_*.gd` wajib **100% PASS (0 FAIL)**.
2. **6-Camera Visual Gate + Time-of-Day Check (`DAY`, `SUNSET`, `NIGHT`):**
   - **Cam 1 (Start / Pit Straight):** Paddock FIA lengkap (`MainGrandstand`, `StartGantry`, `PitBuilding`, `RaceControlTower`, `CatchFence`).
   - **Cam 2 (Sector 1 Landmark):** Landmark utama Sektor 1 + air/terrain cel-shaded.
   - **Cam 3 (Sector 2 Landmark):** Landmark utama Sektor 2 (terowongan/overpass/chicane).
   - **Cam 4 (Sector 3 Landmark & Pit Entry):** Landmark Sektor 3 + jalur pisah Pit Entry.
   - **Cam 5 (Sky & Horizon Overview):** Memperlihatkan langit hidup (Matahari/Bulan, Awan 3D Cel-Shaded, Bintang saat malam, 0 jalan melayang).
   - **Cam 6 (Player Chase Cam Action):** Koridor dekat (8 m – 45 m) padat, cel-shading & outline tegas.
   - **Day / Sunset / Night Verification:** Pastikan tangkapan layar pada mode `DAY`, `SUNSET`, dan `NIGHT` menampilkan transisi langit, awan, air, dan lampu bangunan yang akurat.
3. **Performance Budget Gate:**
   - **Draw Calls Sirkuit:** $\le 160$ draw calls per kamera (dan $< 180$ total scene). Ukur native dengan `scratch/measure_env_draw_calls.gd -- <sirkuit>` (kamera tiap 150 m, bagian environment di dalam frame, bayangan termasuk; gagal bila view terburuk > 180). Hitungan statis `env.stats()` tidak melihat biaya shadow pass. MultiMesh yang batasnya seluruh sirkuit (pohon) wajib `cast_shadow` off kecuali sudah diukur.
   - **Triangles Lingkungan:** $\le 320.000$ triangles.
   - **Frame Time:** $\le 16,66\text{ ms}$ (60 FPS locked pada 1080p High dengan 20 mobil GT3).
