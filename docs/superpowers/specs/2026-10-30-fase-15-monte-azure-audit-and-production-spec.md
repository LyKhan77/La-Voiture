# Fase 15 — Monte Azure Marina: audit kesesuaian standar & spesifikasi produksi terkoreksi

Tanggal: 2026-10-30 · Peran penulis: Planner / Lead Technical Game Architect · Status: DRAFT, menunggu persetujuan developer sebelum eksekusi.

Dokumen ini melengkapi `mapgen-circuit/builds/monte_azure/production-handoff.md` (handoff yang benar) dan menggantikan bagian *pemetaan modul* dari `final/handoff-prompt.md` dan `procedural-spec.md` §2–§5 untuk implementasi di La_Voiture; lihat §1b untuk rekonsiliasinya. **Angka geometri blueprint tidak diubah** (lihat §2.1).

## 1. Ringkasan

Paket mapgen (`designs/monte_azure/final/`) **utuh dan valid sebagai sumber geometri**, tetapi **belum sesuai standar La_Voiture sebagai instruksi implementasi**, dan prototype `builds/monte_azure/` adalah *blockout* yang tidak boleh dijadikan acuan visual atau budget.

- Integritas paket: SHA-256 keempat file di `manifest.json` cocok dengan file di disk (diperiksa 2026-10-30).
- Geometri: panjang, radius, elevasi, dan jarak antar-ruas jalan lolos (§2.1). Tidak ada tabrakan jalan-ke-jalan; ruas terdekat terpisah 120,5 m.
- Yang gagal: 4 blocker dan 5 temuan tinggi/menengah (§2.2). Semuanya bisa diperbaiki di sisi La_Voiture tanpa merevisi blueprint, kecuali dua keputusan opsional di §6.

## 1b. Rekonsiliasi dengan `production-handoff.md`

Sumber utama implementasi, urutan prioritas bila bertentangan: SPEC ini > `production-handoff.md` > `final/procedural-spec.md` > `final/handoff-prompt.md`. Angka geometri blueprint tetap di atas semuanya.

| Bagian `production-handoff.md` | Keputusan SPEC |
|---|---|
| §2 Track & corridor: kerb 7 run, Armco 1.305 post, Tecpro, papan rem, 28 tiang lampu, catch fence 617 panel / 1.851 m | Dipertahankan: papan rem 150/100/50 dan 28 tiang lampu. **Diubah (ruling Planner):** Armco GP diganti tembok beton jalan raya dan kerb jalan rendah (Guide §3: sirkuit jalan raya punya barrier sendiri; preseden Neo-Wangan; Cam 6 prototype terbaca sebagai GP). Catch fence dibatasi ke lurusan start/pit (±150 m dari S/F); keputusan terbuka #2 builder dijawab: tidak 1.851 m. |
| §2 Pit: entry 2.790 / exit 260 / lane 320, kanan, 10 bay × 12 m, blok garasi di tengah lane | Dipertahankan. **Diubah:** garasi depan 20,1 / kotak 16,5 → 16,0 / 13,0 (F3); apron merge 65 m setelah exit → blend exit 80 m di dalam lane (`lane_ramp_out_m`), setara fungsi: mobil kembali ke aspal sebelum garis balap. |
| §2 PitBuilding, MainGrandstand, RaceControlTower, StartGantry, Jumbotron, 10 kru standby | Dipertahankan dengan deviasi menara s 176 dan tribun 160 m (F9, §4.3). |
| §2 Terrain: heightfield 246×185, laut Y=0, dasar −8 m, fondasi per footprint, lambung yacht −0,35 m, distrik 30 bangunan + 21 semak | Dipertahankan; heightfield seragam diganti cincin LOD (§6 langkah 4 builder sendiri menyarankannya). Distrik per sektor, semak lewat `FoliageScatter`. |
| §2 Tampilan: cel dua-tone, outline tinta, kaca matte halftone, aspal shader game, DAY/SUNSET/NIGHT lengkap | Dipertahankan lewat kit game (`ToonMaterials`, `inverted_hull_outline`, `WorldSkyRig`). Kaca: pakai material kaca kit (`GARAGE_GLASS` vertex alpha) dahulu; `anime_glass.gdshader` diajukan sebagai shader bersama hanya bila kit tidak setara (sesuai §4 builder). |
| §3 Tabel kesenjangan (catch fence, floodlight, flag panel, jumbotron, tim, vegetasi, hero art, draw call, triangle, orphan) | Seluruhnya dicakup: §4.4 poin 4–6, §4.3, §5.3, F14. |
| §4 Pemetaan modul prototype → produksi | Dipakai, dengan perbedaan: environment dipecah menjadi 6 modul (§3), dan template utama `neo_wangan_environment.gd`, bukan `apex_environment.gd` (Apex hanya untuk pola catch fence). |
| §5 Keputusan terbuka #1 selisih panjang | Gugur: builder produksi memakai `plan_scale` (§2.1). |
| §5 #2 kepadatan catch fence | Dijawab di atas. |
| §5 #3 budget render | Alokasi per komponen di §5.3. |
| §5 #4 art pass hero | Setelah gerbang struktural hijau (§6 butir 5). |
| §5 #5 transporter dan urutan 10 tim | Transporter di baris lateral 40 di dek belakang gedung pit (pola Wangan), urutan tim dari `GtRace.active_teams` lewat `assign_teams` (kontrak kelas dasar). |
| §5 #6 path registri | `circuits/monte_azure/monte_azure_circuit.tscn` (§4.1). |
| §5 #7 format SPRINT 3 lap, tanpa pit wajib | Tidak ada pekerjaan: `race_setup_menu.SPRINT_LAPS = 3` mengunci 3 lap dan tidak ada aturan pit wajib di kode; pit tetap untuk ban/kerusakan. |
| §7 urutan implementasi, §8 gerbang | Dipakai dan dilengkapi: tes UI (F4), `test_flag_panels_contract`, `test_pit_stop_in_world`, `test_monte_azure_pit_layout`, `test_monte_azure_terrain_gate`, `test_monte_azure_landmarks` (§5.1). |
| §9 jangan sentuh | Dipatuhi. |

## 2. Hasil audit

### 2.1 Yang sudah sesuai (diverifikasi independen, bukan dari laporan builder)

Skrip pemeriksa `scratch/monte_azure_geometry_audit.py` mereplikasi pola `BrianzaCircuitBuilder._walk_plan` (fillet, clamp 0,48, `plan_scale`) atas `blueprint.track.json`; jalankan ulang dengan `python -I scratch/monte_azure_geometry_audit.py`.

| Aspek | Hasil terukur | Standar |
|---|---|---|
| Panjang plan sebelum skala | 2.589,6 m → `plan_scale` = 1,100552 → plan tepat 2.850,000 m; ribbon 3D 2.852,25 m (selisih 2,25 m = panjang vertikal tanjakan 41,9 m, terukur di `test_monte_azure_circuit` #M11) | 2.850 ±25 (regresi ±15) |
| Radius dunia minimum | 23,7 m (T18), 24,2 m (T7/T8/T16/T17) | ≥ 22 m, jalan 11 m |
| Fillet ter-clamp | T1 60→40,3 (dunia 44,3), T11 130→124,9, T18 36→21,5 (dunia 23,7) | validator WARN sudah tercatat |
| Landai maksimum | 9,6 % di s=780 | ≤ 12 % |
| Jarak ruas jalan non-adjacent | min 120,5 m (s=607 vs 759; s=2604 vs 2755) | tidak ada persilangan |
| Panjang lane pit | 320,0 m | blueprint 320 |
| T19 → mulut pit | 35,4 m setelah busur T19 berakhir | cukup untuk limiter 80 km/jam |
| Mulut exit → T1 | 360 m | cukup untuk merge |
| Elevasi dalam sim | `scripts/gt` tidak memakai grade/slope; elevasi hanya visual ribbon | tidak ada risiko fisika |

Catatan penting: radius di tabel spec §2 adalah radius *plan-space*. Radius dunia = ×1,1006. Tes harus menegaskan radius dunia ≥ 23,0 m, bukan 22.

Keputusan terbuka #1 builder ("selisih panjang 2.852,357 vs 2.850") **gugur**, tetapi bukan karena `plan_scale` (koreksi saat implementasi, 2026-10-30): panjang plan memang tepat 2.850,000 m, sedangkan ribbon (kurva 3D) lebih panjang 2,25 m karena tanjakan; prototype mapgen melaporkan efek yang sama (2.852,357). Keduanya dalam toleransi ±15 m, jadi tidak perlu patch geometri. Stasiun blueprint (pit, landmark, kunci elevasi) berada di sumbu plan; selisih ke jarak ribbon ≤ 2,3 m di akhir lap.

### 2.2 Temuan

| # | Tingkat | Temuan | Bukti | Koreksi |
|---|---|---|---|---|
| F1 | SEDANG | Dokumen handoff yang benar adalah `mapgen-circuit/builds/monte_azure/production-handoff.md` (koreksi developer 2026-10-30; sudah dibaca pada audit pertama dan dikutip di tabel ini). Dokumen itu memperbaiki sebagian cacat `final/handoff-prompt.md` (path modul, path registri, lima tes kontrak, gerbang draw call, kontrak tim) tetapi masih kurang: tes UI yang berubah (F4), `test_flag_panels_contract` dan skenario `test_pit_stop_in_world`, penampang pit (F3), strip band (F2), semantik landmark (F15), menara/tribun (F9/F10). Rekonsiliasi per bagian di §1b. Cacat `final/handoff-prompt.md` sendiri: usang terhadap arsitektur repo. Path `scripts/world/monte_azure_*.gd` dan `scenes/race_world/monte_azure_circuit.tscn` salah (standar: `scripts/world/circuits/monte_azure/`, `scenes/race_world/circuits/monte_azure/`). Menyebut `track_environment_builder.gd`, `pit_lane_complex.gd`, `furniture.start_gantry` (sudah diganti nama / tidak ada). "52+ suite" padahal ±68. Tidak menyebut `CircuitEnvironment`, `CircuitPitComplex`, `FlagPanelSet`, `WorldSkyRig`/`SKY_PROFILES`, lima tes kontrak, gate `measure_env_draw_calls.gd`, `smoke_pit_race.gd`. | Guide §2b, §3; `circuit_data.gd:51` | `production-handoff.md` builder memperbaiki sebagian; dokumen ini dan `prompt/TASK-MONTE-AZURE-CIRCUIT.md` jadi satu-satunya instruksi. |
| F2 | BLOCKER | Band strip menembus ruas jalan lain. Band `urban R 240–680` (offset 10, kedalaman 300) memuat jalan s=809–1026 (42 titik); `forest R 680–1200` memuat jalan s=455–468. Band `urban R` mulai s=240, tepat di mulut exit pit (260) dan merge-nya. Kelas cacat yang sama dengan rumput menutup trek di Brianza. | `python -I scratch/monte_azure_geometry_audit.py` | Zona ditentukan dari **stasiun jalan terdekat**, bukan persegi panjang per rentang s; semua penempatan Tier B wajib lewat clearance ke jalan mana pun; gerbang terrain mesh-level (§5.4). |
| F3 | BLOCKER | Layout pit tidak konsisten. Blueprint `fast_lane_m` = 8,5 (lateral pusat jalur cepat, gaya sirkuit jalan raya seperti Neo-Wangan), tetapi spec §3 dan prototype memakai angka GP (garasi depan 20,6 / 20,1, kotak 16,5). Kontrak sim `fast_lane_m`/`stall_lane_m`/`edge_lateral_m` dan `pitstop_choreographer` (setback = garage_front − stall_lane) mensyaratkan satu penampang konsisten. Dengan jalan 11 m, tepi aspal 5,5 m. Prototype juga membaca `fast_lane_m` sebagai **tepi dalam** (`pit_corridor.gd`: pusat = 8,5 + 2,3 = 10,8), sedangkan sim membacanya sebagai **pusat** jalur (Wangan: pusat 8,5, tepi 6,25 … 10,75). | `neo_wangan_pit_complex.gd` (jalan 11,5; jalur cepat 8,5; kotak 13,0; garasi 16,0) | Pakai penampang Neo-Wangan yang disesuaikan jalan 11 m (§4.3). |
| F4 | BLOCKER | Registri menunjuk `res://scenes/race_world/monte_azure_circuit.tscn` (datar). `CircuitData.is_playable()` = `ResourceLoader.exists(scene_path)`, jadi kartu menjadi playable begitu scene ada di path itu. Dua tes yang saat ini menegaskan "Monte Azure belum dibangun" akan merah: `test_track_selector_ui.gd` #S4b dan `test_visual_polish_and_consistency.gd` (CarouselCard3 = "IN PREPARATION"). Handoff tidak menyebutnya. | `circuit_calendar_registry.gd:29`, tes di atas | Ubah path ke `circuits/monte_azure/monte_azure_circuit.tscn`; pindahkan asersi "belum dibangun" ke Ronde 05 Ardennes. |
| F5 | TINGGI | Prototype berwajah GP, bukan jalan raya. Kerb sawtooth merah-putih, verge pasir/rumput lebar, armco GP, tanpa kota dan tanpa yacht yang terlihat dari trek (Cam 1, 3, 4, ikhtisar pantai). Tipe SPRINT dan catatan kalender "zero margin for error" menuntut tembok beton rapat, kerb jalan rendah 0,03 m (spec §2), dan kota. Catch fence 1.851 m tidak lazim di jalan raya (Neo-Wangan tidak memilikinya di environment). | Gate_Cam_1/3/4/6 day; `neo_wangan_environment.gd` `_build_barriers`, `_build_kerbs` | Template environment = `neo_wangan_environment.gd` (barrier beton, kerb jalan, harbor, skyline, hero), bukan `apex_environment.gd`. Catch fence hanya di lurusan start/pit. |
| F6 | TINGGI | Gate kamera: Cam 3 (landmark S2) dan Cam 4 (landmark S3 + entry pit) tidak menampilkan landmark apa pun pada render builder. | Gate_Cam_3, Gate_Cam_4 day | Lihat kamera gate di §5.5. |
| F7 | TINGGI | Budget: prototype 329 (DAY) / 353 (NIGHT) draw call dan 352.326 triangle statis, melampaui 180 / 320.000. Penyebab terbesar bukan kit bersama: terrain 127.008 tri (heightfield seragam 6 m), `PitGarages` 24 node, `StartGantry` 12 draw call, furnitur 84.598 tri. Referensi: Wangan 155 draw call terburuk, Brianza 100, Apex 67 (gate Fase 14.1). | `build-report.md`; memori Fase 14.1 | Alokasi budget per komponen (§5.3) dan terrain LOD per cincin. |
| F8 | SEDANG | Reference set tidak lengkap. Folder `reference-assets/tracks/monte_azure/` hanya punya `concept_key_visual.png` dan satu poster duplikat; Guide §3 Tahap 1 mensyaratkan 4 view gate (view1..view4) seperti Brianza/Wangan. Poster bertuliskan "3.337 km" padahal sirkuit 2,85 km. | listing folder | 4 view dibuat 2026-10-30 (§6, keputusan 2). |
| F9 | SEDANG | Tata letak menara kontrol: blueprint `control_tower_s` = 130 jatuh di dalam bentang gedung pit (s 38–162 untuk 10×12 m + margin). Kit `RaceControlTower` pada Brianza/Wangan berdiri 76–85 m di depan titik tengah gedung, bukan di dalamnya. | `neo_wangan_pit_complex.gd:446`, `brianza_pit_complex.gd:462` | Pindahkan ke s≈176 (deviasi tercatat, §4.3). Tribun 240 m → 160 m (Brianza); 240 m memakan 43.406 tri di prototype dan lebar quay. |
| F10 | SEDANG | Band `water L 0–480` offset 24 bertabrakan dengan tribun utama (sisi kiri, depan 19–21,5 m, kedalaman 38 m → hingga lateral ±60 m). Prototype memperbaikinya dengan `shore_width` 78 m. | spec §3 vs §4; `coastal_environment.gd` | Esplanade/quay ≥ 70 m pada s∈[2805, 200], menyempit ke 28 m antara s=220–320. |
| F11 | SEDANG | Nama tikungan vs landmark berbeda: hotel (s=1010) berada di T5, sementara "Fairmont In/Out" T7/T8 di s≈1243/1419; terowongan (s=1300) berada di T7/T8, sementara "Tunnel In/Out" T11/T12 di s≈1860–2029. Nama tikungan tampil di minimap/HUD. | tabel §2.1 skrip | **Diputuskan: ganti nama** (§4.2). Nama hidup di builder produksi; blueprint tidak diedit. |
| F15 | TINGGI | Dua hero tidak masuk akal secara fisik pada prototype. `offset_m` blueprint adalah jarak **sisi dekat** (cocok untuk kasino 90+30=120, hotel 20+27,5=47,5, yacht 60+30=90, terukur pada `placement-manifest.json`). Maka terowongan berdiri 27 m di samping jalan (jalan tidak melewatinya) dan skybridge berpusat 23 m di kiri jalan (tidak menyeberangi jalan 11 m), padahal spec §5 menulis "melintasi track". Selain itu GLB terowongan sepanjang 190 m, sedangkan lurusan T7→T8 hanya 166 m (s 1247–1413): ujungnya masuk ke tikungan. | `python -I scratch/monte_azure_geometry_audit.py <blueprint> <placement-manifest>`; GLB bounds | Terowongan dan skybridge diposisikan **di atas garis tengah jalan** (lateral 0); terowongan diskalakan ke 150 m dan dipusatkan di s=1.330 (§4.4). Deviasi dari `offset_m` dan `s` dicatat. |
| F12 | RENDAH | Karakter: dari 19 tikungan hanya T1 (98°) dan T18 (104°) di atas 90°. "Fairmont hairpin" T7/T8 hanyalah 17° + 29°; "Casino chicane" T3/T4 = 28° + 6°. Beberapa "tikungan" hanya kink 6–17° dengan bentang 5–7 m. | tabel §2.1 skrip | Geometri dibekukan dan telah disetujui; tidak diubah. Implementasi: kerb dan papan rem hanya untuk tikungan ≥ 15° (§4.2). Revisi karakter = urusan mapgen (opsional). |
| F13 | RENDAH | 5 hero landmark vs Guide 2–4. Neo-Wangan sudah punya 6 GLB, jadi ada preseden. GLB prototype adalah massing (120–1.880 tri). Distrik memakai 9 aset CC0 bergaya PBR (pine, bush, 6 gedung, boat; pine 2,1 MB). | `LICENSES.md`, `assets/tracks/neo_wangan/models/` | Terima 5; catat sebagai deviasi sah. Aset CC0 hanya boleh jadi bahan, wajib toon + outline; pine 2,1 MB tidak dipakai. |
| F14 | RENDAH | Builder melaporkan 2 texture GL bocor saat shutdown native; DoD menuntut 0 orphan. | `build-report.md` | Diukur ulang pada scene produksi; bukan blocker sampai terbukti berasal dari kode produksi. |

## 3. Keputusan arsitektur

Template per bagian (kode yang ditiru, bukan disalin):

| Bagian | Template | Alasan |
|---|---|---|
| Builder (vertex + fillet + `plan_scale`) | `brianza_circuit_builder.gd` | pola identik dengan blueprint mapgen |
| Pit complex | `neo_wangan_pit_complex.gd` (penampang), `brianza_pit_complex.gd` (lane ramp di dalam panjang lane, paddock, dressing) | jalan 11 m, sirkuit jalan raya |
| Environment | `neo_wangan_environment.gd` (barrier, kerb jalan, streetlight, harbor, skyline, hero via `_model_at`), `brianza_environment.gd` (terrain field, `ground_y_at`, gerbang terrain) | Sprint jalan raya + medan berelevasi 42 m |
| Sky | `WorldSkyRig` + `SKY_PROFILES` | Guide §3 Tahap 3.3 |
| Bendera | `FlagPanelSet.plan` + `build` | `test_flag_panels_contract` |

Pecah environment menjadi modul (Wangan sudah 1.100+ baris dalam satu file): `monte_azure_environment.gd` (orkestrasi + kontrak), `monte_azure_terrain.gd`, `monte_azure_harbor.gd`, `monte_azure_districts.gd`, `monte_azure_landmarks.gd`, `monte_azure_paddock.gd`. Pilihan ini adalah keputusan Planner, bukan permintaan developer.

## 4. Spesifikasi produksi

### 4.1 Struktur berkas

```
scripts/world/circuits/monte_azure/
  monte_azure_circuit_builder.gd   class MonteAzureCircuitBuilder
  monte_azure_pit_complex.gd       class MonteAzurePitComplex extends CircuitPitComplex
  monte_azure_environment.gd       class MonteAzureEnvironment extends CircuitEnvironment
  monte_azure_terrain.gd  monte_azure_harbor.gd  monte_azure_districts.gd
  monte_azure_landmarks.gd  monte_azure_paddock.gd
scenes/race_world/circuits/monte_azure/monte_azure_circuit.tscn   (TrackRibbon, PitLane, Environment, WorldEnvironment)
assets/tracks/monte_azure/models/   5 GLB + asset_manifest.json (format `neo_wangan/models/asset_manifest.json`)
tests/test_monte_azure_circuit.gd  test_monte_azure_pit_layout.gd  test_monte_azure_terrain_gate.gd
```

Registri: `scene_path` → `res://scenes/race_world/circuits/monte_azure/monte_azure_circuit.tscn`. Jangan membuat entri kedua.

### 4.2 Builder

- Salin tabel vertex/radius dan titik elevasi dari `blueprint.track.json` (urutan: 19 vertex tikungan + S/F). Tulis `geometry_hash sha256:f495332f…` di komentar atas file sebagai jejak asal.
- `LENGTH_M = 2850.0`, `ROAD_WIDTH_M = 11.0`, `plan_scale = LENGTH_M / plan_length` (≈1,1006), `ARC_STEP_RAD = 0.07`, `STRAIGHT_STEP_M = 6.0`. `TrackRibbon.road_half_width_m = 5.5`.
- Elevasi: smoothstep antar titik (pola `Brianza.elevation_at`), `LENGTH_M` sebagai pembungkus.
- `turns`: 19 entri bernama dari blueprint (field `number, name, s, apex_s, direction, radius_m, vertices, span_m`). Tambahkan field `angle_deg`. Kerb dan papan rem hanya untuk tikungan dengan `angle_deg ≥ 15` (T1, T2, T3, T5, T6, T7, T8, T10–T13, T15–T19 = 16 tikungan; T4 6°, T9 9,7°, T14 6,3° tanpa kerb). Ini keputusan Planner untuk mencegah kerb 5 m di kink.
- Sektor: sepertiga panjang (950 / 1.900), sama dengan Brianza.
- **Nama tikungan (keputusan developer 2026-10-30, F11).** Nama berikut menggantikan nama blueprint di tabel `turns` builder produksi; blueprint dan paket mapgen tidak diedit, dan perubahan dilaporkan ke mapgen sebagai umpan balik:

  | # | Nama blueprint | Nama produksi | Alasan |
  |---|---|---|---|
  | T7 | Fairmont In | **Tunnel In** | kink 17° di s≈1.243, 12 m sebelum mulut masuk (s≈1.255) |
  | T8 | Fairmont Out | **Tunnel Out** | tikungan 29° di s≈1.413, 8 m setelah mulut keluar (s≈1.405) |
  | T11 | Tunnel In | **Marina Sweep** | sapuan 52° memasuki sisi dermaga |
  | T12 | Tunnel Out | **Yacht Club** | berhadapan dengan deretan yacht (s 1.930–2.170) |

  Hotel (s=1010) tetap di samping T5 "Place du Casino", seperti hotel kasino pada lazimnya; tidak ada lagi nama "Fairmont" pada tikungan.

### 4.3 Pit complex

Satu penampang melintang, jarak dari garis tengah ke kanan (m):

| Lateral | Elemen |
|---|---|
| 5,50 | tepi aspal (jalan 11 m) |
| 5,75 | tembok pit, tebal 0,5, tinggi 1,2; hidung membawa crash cushion |
| 6,25 … 10,75 | jalur cepat 4,5 m (pusat 8,5) |
| 10,75 … 16,0 | jalur kerja; mobil kotak berhenti di 13,0 |
| 16,0 … 25,0 | 10 garasi, pitch 12 m |
| 40 | baris transporter di dek belakang gedung pit |

Konstanta (`const` di file): `ROAD_EDGE_M=5.5, PIT_WALL_M=5.75, FAST_LANE_M=8.5, FAST_LANE_HALF_M=2.25, BOX_LATERAL_M=13.0, GARAGE_FRONT_M=16.0, GARAGE_DEPTH_M=9.0, ENTRY_LATERAL_M=5.2, STALL_COUNT=10, STALL_PITCH_M=12.0, ENTRY_S=2790.0, EXIT_S=260.0, LANE_LENGTH_M=320.0, LAP_LENGTH_M=2850.0, ENTRY_BLEND_M=40.0, EXIT_BLEND_M=80.0`.

- Blok stall: pusat lane = s 100, kotak i berpusat di `s = 46 + 12·i` (46 … 154). Jarak entry→kotak pertama 100 m; kotak terakhir→exit 100 m; blend exit (u 240…320 = s 180…260) mulai setelah kotak terakhir.
- Pola ramp di dalam panjang lane (Brianza). `sim_layout()` mengikuti Brianza: `entry_s 2790`, `exit_s 260`, `lane_length_m 320`, `stall_first_s 2896` (koreksi implementasi: sim mengukur kotak dari entry tanpa wrap, jadi s kotak pertama pada lap entry = 2790 + 106 = 2896 = s 46 lap berikutnya; nilai 46 membuat tidak ada mobil terlayani, ditangkap `test_pit_stop_in_world`), `stall_pitch_m 12`, `stall_lane_m 13`, `fast_lane_m 8.5`, `edge_lateral_m 5.2`, `queue_gap_m 8`, `lane_ramp_in_m 40`, `lane_ramp_out_m 80`, `stalls 10`, `speed_limit_mps 22.22`.
- `PitBuilding`: `building_length_m=124, bay_count=10, bay_stride_m=12, front_x=15.5, garage_top_y=4.7, name_doors=true` (gedung tepat di depan fascia, seperti Wangan).
- `MainGrandstand`: sisi kiri (laut), `stand_length_m=160`, pusat s=75, depan −21,5 m seperti Wangan.
- `RaceControlTower`: s≈176 (deviasi dari blueprint 130, lihat F9), pose seperti Brianza/Wangan.
- `StartGantry` di s=0 lewat kit bersama.
- Kontrak tim: `stall_index_for_team`, `assign_teams` dari kelas dasar; override `_on_teams_assigned()` untuk fascia (`TeamSignage`), kru standby 13 orang, cat kotak (`PitKit.paint_box`), transporter (`team_transporters.build(ribbon, stalls, 40.0, true)`).
- Barrier kanan terputus antara `ENTRY_S − 25` dan `EXIT_S + 5` (pola `_in_pit_gap` Wangan).
- `ground_platforms()`: dek rata di bawah garasi dan paddock, mencakup lateral 7 … 70 pada s∈[2760, 360].

Pemeriksaan logika deviasi yang diterima (syarat developer: hasil harus logis). Angka kit dibaca dari `race_control_tower.gd`, `main_grandstand.gd`, `neo_wangan_pit_complex.gd`:

| Deviasi | Pemeriksaan | Hasil |
|---|---|---|
| Menara s=130 → 176 | Kit menara: kotak waktu 13,5 × 16 m, slab atap 14 × 17 m (≈ 17 m sepanjang jalan), muka ke arah trek di lateral ≈ 16,25 (pusat 24). Gedung pit 124 m berpusat s=100 → s 38–162. Di s=130 menara berada di dalam gedung; di s=176 menara menempati s 167,5–184,5 | Jarak ke gedung 5,5 m, tidak ada tumpang tindih |
| Menara vs mulut exit | Blend exit mulai s=180 dan jalur cepat berakhir di lateral 10,75; muka menara 16,25 | Jarak ≥ 5,5 m dari jalur |
| Menara vs baris transporter | Baris lateral 40 pada s≈38–162 (kotak 46–154 ± panjang truk) | Terpisah pada sumbu s, tidak tumpang tindih |
| Tribun 240 → 160 m, pusat s=75 | Membentang s −5 … 155; blok pit s 40–160; kit: depan 19–21,5 m, kedalaman 38 m, atap belakang 58 m | Menutup garis start dan seluruh blok pit di seberang trek; butuh quay ≥ 70 m (§2.2 F10) |
| Penampang pit Wangan-compact | Tembok 5,75 (0,25 m dari tepi aspal 5,5), jalur cepat 6,25–10,75, kotak 13,0, garasi 16,0–25,0; hubungan relatif identik dengan Wangan (5,75 / 6,0 / 6,25 / 13,0 / 16,0) | Konsisten dengan sim (`stall_lane_m − fast_lane_m` = 4,5 m, `garage_front − stall_lane` = 3,0 m, setback choreographer sama dengan Wangan) |
| Entry s=2790, blend 40 m | Busur T19 berakhir di s≈2755; mulut 35 m sesudahnya; kecepatan apex T19 ≈ 82 km/jam menurut simulasi dummy builder (bukan sim game), limiter 80 km/jam | Tidak perlu zona pengereman khusus; dibuktikan ulang oleh `smoke_pit_race.gd` |

### 4.4 Environment

Kontrak: `circuit_id = "monte_azure"`, `build(ribbon, builder)`, `bind_world`, `update` (jumbotron lewat `_feed_leaderboards`), `apply_time_of_day`, `apply_wind`, `ground_y_at`, `_extra_stats`, `flag_panels` wajib terisi (`FlagPanelSet.plan(2850.0, preferred)`).

1. **Terrain.** Medan satu heightfield dengan cincin LOD: sel 6 m dalam 90 m dari ruas jalan mana pun, 12 m sampai 220 m, 24 m di luar; lalu dipotong ke garis pantai. Target ≤ 60k tri total terrain. Permukaan tanah berada 0,16 m di bawah jalan dan di bawah apron pit; naik menuju kasino/hotel seperti `coastal_environment.gd` (logika `_nearest`, fondasi footprint landmark) tetapi tanpa grid seragam. `ground_y_at()` menjawab dari grid yang sama.
2. **Laut.** Bidang laut `neo_wangan_water.gdshader` pada y=0, dasar laut −8 m; parameter `wind_dir`, `wind_speed_kph`, `tod`; warna DAY/SUNSET/NIGHT lewat `SKY_PROFILES` dan material air bersama (pola `_water_material` Wangan).
3. **Zona strip.** `environment_strip.json` dibaca sebagai peta zona: untuk titik P, cari stasiun jalan terdekat `s*` dan sisi `side*` dari seluruh ruas, lalu ambil segmen strip yang memuat `(s*, side*)`. Band tidak pernah diproyeksikan melewati ruas lain. Jarak minimum bangunan/pohon ke garis tengah jalan mana pun: `5,5 + 1 (tembok) + 4 (frontage)` = 10,5 m untuk semua zona, dan zona pit/paddock: tidak ada objek acak antara s∈[2760, 360], lateral ≤ 70 sisi kanan.
4. **Koridor jalan raya.** Tembok beton `MultiMesh` (pola `_build_barriers`, lateral 6,2) kedua sisi dengan celah pit; tutup bahaya kuning di tikungan; kerb jalan merah-putih 1,25 × 0,06 × 2,2 hanya untuk tikungan ≥ 15°; papan rem 150/100/50; 28 tiang lampu (pola `_build_streetlights`, `CircuitLightingController` untuk lampu malam). Catch fence hanya pada lurusan start/pit (±150 m dari S/F, sisi kiri depan tribun dan kanan di luar gap pit).
5. **Tier B.**
   - 5 hero GLB di `assets/tracks/monte_azure/models/` dengan `_model_at` (pola Wangan `_build_hero_landmarks`), diposisikan lewat stasiun `s` blueprint dan yaw = tangen ribbon; semua surface berpola toon + `inverted_hull_outline` (`next_pass`).
   - `offset_m` blueprint = jarak sisi dekat (pusat = offset + kedalaman/2). Berlaku untuk kasino (pusat 120 m kanan), hotel (47,5 kiri), yacht (90 kiri). **Pengecualian: terowongan dan skybridge berpusat di lateral 0** (§2.2 F15).
   - **Terowongan.** Skala sumbu panjang 190 → 150 m dan pusat dipindah dari s=1.300 ke s=1.330 (tengah lurusan T7→T8 yang membentang s 1.247–1.413 = 166 m; mulut di s≈1.255 dan 1.405, margin 8 m). Di s=1.300 lurusan hanya menyisakan 53 m ke T7, sehingga terowongan 150 m di sana menabrak tikungan. Jalan 11 m lewat bukaan GLB; penampang bersih ≥ 13 m lebar × 5,0 m tinggi sepanjang 150 m. Landai jalan di sana ≈ 3,8 % (turun ±5,7 m sepanjang terowongan), jadi GLB di-pitch mengikuti jalan (≈ 2,2°) agar tinggi bukaan konstan. Sesuai Guide §3 Tahap 2: dinding cut-and-cover dan massa tebing/bukit di atas atap; terrain tidak dipotong oleh bukaan (dikecualikan dari tes "tanah di bawah jalan" hanya di bawah atap). Tinggi jalan ±21–23 m, jadi tebing naik di kedua sisi.
   - Yacht pack: `MultiMesh`, sejajar dermaga sisi kiri s 1.580–2.850, lambung 0,35 m di bawah air.
   - **Skybridge.** Berpusat di lateral 0, di s=2.180 (lurusan T13→T14 sepanjang 116 m, margin ≥ 18 m). Bentang ≥ 22 m, pilar berdiri ≥ 9 m dari garis tengah (di luar tembok 6,2 m), clearance bersih di atas aspal ≥ 6,0 m (kamera chase + helikopter TV).
   - Distrik/skyline: `MultiMesh` per sektor dengan batas AABB akurat (bukan satu `MultiMesh` seluruh lap), `cast_shadow` off untuk seluruh `MultiMesh` yang batasnya satu lap, kontur outline `neo_wangan_skyline_outline.gdshader`.
   - Vegetasi: `FoliageScatter` (palm, cypress) dengan `cast_shadow` off.
6. **Langit & waktu.** `SKY_PROFILES` untuk DAY/SUNSET/NIGHT; `WorldSkyRig`; lampu malam hanya saat `tod.floodlights`.

### 4.5 Aset dan lisensi

- Salin lima GLB dari `mapgen-circuit/builds/monte_azure/assets/` ke `assets/tracks/monte_azure/models/` dan tulis `asset_manifest.json`. Jalankan `godot --headless --path . --import`; commit `.import`/`.uid` bersama aset.
- GLB hero berfungsi sebagai massing; tiap aset ≤ 8.000 tri pada pass seni. Pass seni adalah item terpisah (§6, keputusan 3) dan tidak menghalangi gerbang struktural.
- Aset CC0 (Kenney/Quaternius/Kay Lousberg) boleh dipakai sebagai bahan, bukan dikirim apa adanya; semua material diganti `ToonMaterials`. `pine.glb` (2,1 MB) dilarang dipakai.
- Jangan salin folder `vendor/`, shim `apex_pit_complex.gd`/`gt_types.gd`/`gt_data.gd`, `dummy_car.gd`, atau HUD simulasi dari prototype.

## 5. Gerbang penerimaan

### 5.1 Tes baru dan tes yang diubah

| Tes | Isi minimal |
|---|---|
| `test_monte_azure_circuit.gd` (baru) | panjang 2.850 ±15; 19 tikungan bernama; radius dunia min ≥ 23,0; lebar jalan 11; elevasi min ≥ 0, puncak ≥ 41,5, delta ≥ 41,0; landai maks ≤ 12 %; ribbon tertutup; hash geometri di komentar cocok dengan tabel; 0 orphan setelah scene dibongkar |
| `test_monte_azure_pit_layout.gd` (baru) | penampang §4.3: tembok ≥ tepi aspal, jalur cepat bersih dari tembok, garasi depan 16,0, kotak i di `46 + 12i`, mulut entry/exit pada lateral 5,2, `sim_layout()` memuat semua kunci kontrak (`stall_pitch_m`, `queue_gap_m`, `stall_lane_m`, `fast_lane_m`) |
| `test_monte_azure_terrain_gate.gd` (baru) | pola `test_brianza_terrain_gate.gd`: tanam sampel jalan tiap ≤ 6 m pada lateral kiri/tengah/kanan, lebar pit dan apron; permukaan tanah mesh yang dirender harus di bawah jalan; tak ada objek acak dalam koridor 10,5 m ke jalan mana pun; nol bangunan/pohon dalam koridor pit |
| `test_monte_azure_landmarks.gd` (baru) | terowongan: panjang ≤ lurusan T7→T8 dikurangi margin; garis tengah dan tepi jalan (lateral ±5,5) bebas dari mesh GLB sepanjang bukaan; penampang bersih ≥ 13 × 5,0 m. Skybridge: pilar di luar lateral ±9, tinggi bersih ≥ 6,0 m di atas aspal, bentang menutup seluruh lebar jalan + tembok. Hero lain: tidak ada mesh dalam koridor jalan (lateral ±6,2) |
| 5 tes kontrak | tambahkan `"monte_azure"` ke `CIRCUITS` di `test_circuit_environment_contract`, `test_pit_complex_contract`, `test_pit_team_assignment_contract`, `test_team_signage_contract`, `test_team_identity_consistency`; juga `test_flag_panels_contract` |
| `test_pit_stop_in_world.gd` | tambah skenario `monte_azure` "six cars box at once" |
| `test_track_selector_ui.gd` #S4b | pindahkan "Round 04 belum dibangun" ke Round 05 Ardennes; Monte Azure menjadi playable |
| `test_visual_polish_and_consistency.gd` | CarouselCard3 (Monte Azure) playable; kartu "IN PREPARATION" pindah ke CarouselCard4 |
| `test_circuit_calendar_registry.gd` | tegaskan `scene_path` baru bila baris Monte Azure ditambah |

### 5.2 Suite dan smoke

- `powershell -File tools/run_tests.ps1` → 100 % PASS (stderr `SCRIPT ERROR` dihitung gagal).
- `godot --headless --path . -s scratch/smoke_pit_race.gd -- monte_azure`: 6 mobil ke box bersamaan, semua terlayani, 0 orphan.
- Smoke balapan 3 lap, 20 mobil, kembali ke menu: 0 orphan, tidak ada `SCRIPT ERROR`.

### 5.3 Budget (target Planner; ukur ulang dengan skrip, jangan percaya hitungan statis)

Gerbang resmi: `scratch/measure_env_draw_calls.gd -- monte_azure 150` → worst view ≤ 180 (target p95 ≤ 160). Triangle statis `env.stats()` ≤ 320.000.

| Komponen | Triangle | Draw call (view terburuk) |
|---|---|---|
| Terrain (cincin LOD) | ≤ 60k | ≤ 8 |
| Ribbon + kerb + runoff | ≤ 22k | ≤ 10 |
| Tembok/furnitur + lampu | ≤ 40k | ≤ 14 |
| Kit paddock (tribun, gedung, menara, gantry) | ≤ 55k | ≤ 30 |
| Pit lane + garasi (`MeshBatch`) | ≤ 25k | ≤ 12 |
| 5 hero + yacht | ≤ 35k | ≤ 20 |
| Distrik/skyline (per sektor) | ≤ 35k | ≤ 14 |
| Vegetasi | ≤ 10k | ≤ 4 |
| Langit bersama | ≤ 12k | ≤ 20 |
| Bendera + jumbotron | ≤ 5k | ≤ 6 |
| **Total** | **≈ 299k** | **≈ 138** |

Aturan pengukuran: `MultiMesh` yang batasnya seluruh lap wajib `cast_shadow` off (Apex 270 → 67); jangan memecah `MultiMesh` pohon per 100 m (memperburuk rata-rata, Fase 14.1); apron/tribun di bawah 43k tri.

### 5.4 Gerbang visual

Enam kamera × DAY/SUNSET/NIGHT. Pemetaan:

| Cam | Sasaran |
|---|---|
| 1 | lurusan start/pit: `MainGrandstand`, `StartGantry`, `PitBuilding`, `RaceControlTower`, catch fence |
| 2 | pendekatan kasino (s≈900): hero Casino + laut cel-shaded |
| 3 | mulut terowongan (s≈1.230–1.330): Cliff Tunnel dengan jalan masuk ke bukaan, hotel terlihat di kiri |
| 4 | yacht + skybridge (s≈2.150) dan mulut entry pit (s=2.790) |
| 5 | langit dan horizon, 0 jalan melayang |
| 6 | chase cam (8–45 m), tembok beton + kerb jalan + outline tegas |

Wajib: flythrough setinggi chase cam tiap 150 m dua arah, aerial pit dan entry/exit, clearance mobil terhadap tembok pada seluruh lane. Simpan di `executor-report/screenshots/phases/phase-15/`.

### 5.5 Dokumentasi

`executor-report/reports/FASE-15-MONTE-AZURE-CIRCUIT-REPORT.md` (hasil tes, angka draw call/tri, deviasi), pembaruan `ROADMAP.md`, dan daftar deviasi dari paket (tower s, tribun 160 m, penampang pit) sebagai bahan `build-feedback.md` untuk agen mapgen.

## 6. Keputusan developer (2026-10-30)

| # | Butir | Keputusan | Status |
|---|---|---|---|
| 1 | Karakter geometri (F12) | Ikuti rekomendasi: geometri tetap beku. | Final |
| 2 | Referensi gate (F8) | Developer meminta Meshy AI (GPT Image). Meshy menolak: `402 NoMorePendingTasks: Task creation on the free plan is no longer supported` (saldo 1.087 kredit terlihat, paket gratis tidak boleh membuat task); tidak ada kredit terpakai. Developer lalu menyetujui `npx genex image`. Empat view dibuat dengan `--edit concept_key_visual.png` (28 kredit; batas aset build dinaikkan 160 → 186 atas persetujuan itu). | Selesai: `reference-assets/tracks/monte_azure/view1..view4` (1024×768, `--size` diabaikan oleh mode edit). Poster di view1 membawa teks judul dari key visual ("GTS WORLD CHAMPIONSHIP", salah ketik); hanya acuan visual, bukan aset runtime |
| 3 | Deviasi paket | Diterima dengan syarat hasil logis. Syarat diperiksa di §4.3 (tabel pemeriksaan logika) dan §2.2 F15; dua deviasi tambahan muncul dari pemeriksaan itu (terowongan dan skybridge). | Final |
| 4 | Nama tikungan (F11) | Perlu refining: T7 "Tunnel In", T8 "Tunnel Out", T11 "Marina Sweep", T12 "Yacht Club" (§4.2). | Final |
| 5 | Pass seni hero | Massing GLB dipertahankan untuk gerbang struktural; art pass (≤ 8.000 tri per aset) setelah gerbang budget hijau. | Default Planner |

Empat view memetakan kamera gate §5.4: view1 = Cam 1 (lurusan start/pit), view2 = Cam 2 (kasino), view3 = Cam 3 (mulut terowongan + hotel; bukaan terlihat terbuka ke arah dermaga), view4 = Cam 4 (yacht + skybridge + papan PIT ENTRY).

## 7. Diluar cakupan

Ubah geometri blueprint; ubah entri kalender sirkuit lain; ubah gaya cel global; menambah dependensi baru; menyalin `vendor/` prototype; mem-bundel aset CC0 apa adanya.

## 8. Self-review (pengganti pemeriksaan builder oleh subagen)

Dibaca ulang sebagai builder tanpa konteks: (a) semua path sudah absolut dari root repo; (b) angka pit dapat dihitung dari satu penampang; (c) yang diputuskan Planner ditandai ("keputusan Planner", "target Planner", "deviasi"); (d) belum ada yang diverifikasi dengan menjalankan Godot — semua angka audit berasal dari replikasi aritmetika pola Brianza dan pembacaan kode; gerbang sebenarnya hanya bisa dibuktikan oleh tes headless dan pengukuran native di Fase 15.

## 9. Catatan implementasi (diisi saat eksekusi, 2026-10-30)

Perbedaan antara SPEC di atas dan kode yang dikirim, dengan alasannya. Setiap butir ditemukan oleh tes yang gagal dahulu (merah) atau oleh tangkapan native.

| # | SPEC | Dikirim | Alasan |
|---|---|---|---|
| 1 | §4.2: panjang ribbon 2.850 dari `plan_scale` = LENGTH / panjang plan (≈1,1006) | `plan_scale` dipangkas 3 kali sampai **ribbon 3D** = 2.850,00 m (≈1,0997); plan datar 2.847,75 m | Kurva 3D lebih panjang 2,25 m dari plan karena tanjakan; sim menghitung lane dari `fposmod(exit − entry, ribbon.length)`, jadi semua stasiun blueprint harus jarak ribbon |
| 2 | §4.3: `stall_first_s` 46 | **2896** (2790 + 106, tanpa wrap) | Sim mengukur kotak dari entry; dengan 46 tidak ada mobil terlayani (`test_pit_stop_in_world` merah: 0 roda diganti) |
| 3 | §4.4.1: terrain cincin LOD | satu heightfield seragam sel 8 m, 27,6k tri | Dalam budget (≤ 60k) dan tanpa sambungan antar-cincin; kerucut jalan + dek + bed (14 m + bank 0,55) menjamin tanah di bawah jalan |
| 4 | §4.4.5: `FoliageScatter` | `MonteAzureFoliage` (palem, pinus payung, cypress, semak) | `FoliageScatter` memuat kelas Apex (cedar/oak/pine) dan menempatkan pohon di y=0; Monte punya tanjakan 42 m dan tema Riviera |
| 5 | §4.4.4: `CircuitLightingController` | lampu emisif + kolam cahaya terlukis (pola Wangan) + lampu terowongan | Controller itu milik Apex (kolam spot mengikuti kamera); Wangan memakai pola yang sama dengan Monte |
| 6 | §4.4.4: gap barrier kanan s=ENTRY−25 … EXIT+5 | … **EXIT+40** | Mobil yang baru keluar mulut exit masih di lateral 5,2 (tepi jalan); barrier di 6,2 menimpa 0,3 m. Ditangkap `test_monte_azure_pit_layout` #P19 |
| 7 | §4.3: dek pit lateral 7…70 | 5,5…52 | Transporter di 40 dan apron cukup; 70 m membuat dataran beton kosong 65 m |
| 8 | §4.4.5: skybridge bentang ≥ 22 m, pilar ≥ 9 m | skala x1,3 / y1,6 (bentang 30 m, pilar dalam 9,6 m, bawah dek 7,0 m) | Model asli: pilar dalam di 7,4 m dan bawah dek 4,4 m (`test_monte_azure_landmarks` #L10, #L12) |
| 9 | §4.4.5: kasino/hotel di atas teras | teras datar (`level_s`) dan blok tenggelam ≤ 1,3 m di sisi tanjakan | Jalan menurun 5 %; gedung berdiri tegak |
| 10 | §5.1: ≥ 150 blok | 120 minimum, 189 terpasang (132 kota + 57 gudang paddock) | Lahan zona urban membatasi; baris urban kini mulai 26 m dari tepi jalan agar kamera TV (20 m, tinggi 2,4 m) tidak menembus fasad. Kandidat ditolak: 325 karena dek, 179 karena tumpang tindih, 26 zona, 2 kemiringan (probe `scratch/probe_monte_dressing.gd`) |
| 11 | §4.4.3: zona strip tidak punya objek paddock | gudang rata 4,5–8 m di zona paddock | Dataran kosong 1.100 m terbaca sebagai lahan parkir raksasa pada Cam 1 dan 6 |
| 12 | — | shader baru `shaders/monte_azure_facade.gdshader` | `neo_wangan_skyline` hanya menyalakan jendela malam; Monte butuh dinding, kerai, kornis, atap dan jendela siang |
| 13 | — | `tests/test_monte_azure_terrain_gate.gd` #G14: normal terrain menghadap atas | Terrain pertama terbungkus ke bawah (tidak tampak); tes mesh biasa tidak melihatnya karena `get_faces()` tidak peduli sisi |

### 9b. Putaran uji main developer (2026-10-30, setelah commit def3826)

Tiga temuan dari uji main; semuanya direproduksi dengan tes yang merah dahulu, lalu diperbaiki di akar masalah. Butir 14–18 mengubah angka §4.3 (lane 320 → 420 m, kotak 12 → 20 m, entry lateral 5,2 → 4,6).

| # | SPEC / paket | Dikirim | Alasan dan bukti |
|---|---|---|---|
| 14 | §4.4.5: GLB terowongan dipakai apa adanya | Dua slab `dark` yang menyumbat mulut dan dua blok portal beton (3,5 m × 23 m × 10 m) dibuang; tiap mulut diganti rangka (dua pilar dan lintel) di sekeliling bore 15 × 7,4 m; permukaan yang menghadap ke bore (reveal, dinding samping) memakai liner gelap tanpa kontur tinta | Paket memodelkan bukaan sebagai pelat gelap yang dicat, dan di belakangnya blok beton menutup seluruh muka. Tes `test_monte_azure_landmarks` #L8c (40 sinar sepanjang jalan, dua arah, tinggi 0,6–5 m): 40/40 terblokir sebelum, 0/40 sesudah; mutasi (pembuka dimatikan) membuatnya merah lagi di s=1.255 dan s=1.405 |
| 15 | §4.3: kotak pitch 12 m, lane 320 m, ramp 40/80 m | Kotak **20 m**, lane **420 m** (exit s=360, 260 m sebelum Sainte Devote), ramp 60 m masuk dan 100 m keluar; gedung pit 204 m, garasi 16,4 m, menara kontrol 116 m dari tengah gedung, tribun 200 m berpusat di s=95 | Pit macet bukan karena lebar lajur (jalur cepat 4,5 m + lajur kerja 5,3 m cukup) tetapi karena pitch: dua mobil satu tim ditumpuk (yang kedua menunggu 8 m di belakang yang pertama), dan pada 12 m mobil antrean untuk kotak berikutnya berdiri bumper ke bumper dengan mobil di kotak ini. Mobil hanya bisa keluar dari kotak terdepan lebih dulu (urutan terbalik) dan mobil saling menembus: `test_monte_azure_pit_flood` melaporkan 523 dan 465 tick tumpang tindih (batas 20) pada skenario kereta 30 m dan rapat 20 m |
| 16 | — | `GtDriving._queue_behind_teammate`: mobil antrean berhenti di belakang mobil yang ditahan di merge di lajur kotak, bukan masuk ke atasnya | Dengan pitch 20 m mobil yang ditahan merayap sampai tempat antrean kotak berikutnya, dan antrean masuk ke atasnya (skenario menyebar: 97 tick tumpang tindih). Satu-satunya perubahan sim bersama. `test_pit_queue_flow` (Apex) 0/17/0/12 → 0/17/0/0 tick; semua 13 suite `pit` lulus |
| 17 | §4.3: lateral mulut 5,2 | **4,6** | Pada 5,2 sisi luar mobil (6,24) menembus muka dalam barrier beton (5,925) sejauh 0,3 m di sepanjang pendekatan. Tes #P23 |
| 18 | §4.3: aspal lane mulai di u=0 dan berakhir di u=LANE, tepi sirkuit di 6,25 | Aspal tumbuh dari tepi jalan 45 m sebelum entry dan memudar 55 m setelah exit; tepi sisi sirkuit selalu bersama dengan tepi jalan (tidak ada jalur dek polos di antara jalan dan lane); celah barrier mengikuti ekor itu; atenuator oranye di dua ujung barrier | Tampilan sebelumnya: aspal lane mulai mendadak di garis entry dan runcing di ujung exit, dengan celah 0,3–0,4 m antara tepi jalan dan aspal lane sepanjang ramp. Tes #P20–#P23 (aspal membawa lebar mobil di seluruh lane dan ekor, jalur tanpa tekukan, mobil bebas dari barrier); mutasi: lateral 5,2 membuat #P2 #P8 #P20 #P23 merah |

Hasil `test_monte_azure_pit_flood` (kereta 30 m, rapat 20 m, menyebar, lapangan yang dibalap):

| Metrik | Sebelum (12 m) | Sesudah (20 m + perbaikan antrean) |
|---|---|---|
| Tick tumpang tindih > 1 m (batas 20) | 523 / 465 / 0 / 2 | 14 / 11 / 7 / 2 |
| Waktu diam terlama di luar kotak | 18,8 / 18,8 / 15,0 / 20,1 dtk | 16,3 / 14,7 / 7,4 / 14,1 dtk |
| Lane kosong setelah panggilan pertama | 101 / 122 dtk (kereta, rapat) | 86 / 85 dtk |

Sisa menunggu (10–16 dtk) adalah aturan yang disengaja: mobil yang selesai dilayani menunggu sampai lajur cepat di belakangnya bebas dari mobil yang melaju (§ rilis aman). Pada aliran 20 mobil yang rapat tidak ada celah, sehingga menunggu sampai aliran lewat. Sirkuit lain (Apex 14 m, Brianza 14 m, Neo-Wangan 12 m) memakai pitch sempit yang sama; angkanya belum diukur dengan tes tumpang tindih per sirkuit.
