# Fase 16 — Ardennes Valley Ring: audit paket mapgen dan spesifikasi produksi

Tanggal: 2026-10-31 · Peran penulis: Executor/Planner La_Voiture · Branch: `fase-16-ardennes-circuit` · Status: dieksekusi (angka akhir di §9).

Dokumen ini melengkapi `D:/Occupation/Porto/genex/mapgen-circuit/builds/ardennes/production-handoff.md` (handoff Route 2 yang disetujui developer 2026-10-31, "ok nice sudah OK semua") dan menggantikan bagian *pemetaan modul* dari `designs/ardennes/final/handoff-prompt.md` (Route 1, usang terhadap arsitektur repo) dan `procedural-spec.md` §2–§5. **Angka geometri blueprint tidak diubah** (geometry_hash `sha256:fea86645c41b985de3d0b7987a90785d62a319e0507796e98656275c3bed98d4`).

Urutan prioritas bila bertentangan: dokumen ini > `production-handoff.md` > `final/procedural-spec.md` > `final/handoff-prompt.md`. Geometri blueprint di atas semuanya.

## 1. Ringkasan

Paket mapgen utuh (4/4 SHA-256 cocok dengan `manifest.json`) dan geometrinya valid. Sandbox `builds/ardennes/` (41/41 QA, pit 25/25) adalah prototipe visual yang disetujui, bukan kode produksi: ia memakai salinan kit (`vendor/lavoiture/`), skrip pembangun lokal, LOD khusus review, dan layout pit 14 m yang gagal tes banjir pit yang menjadi standar semua sirkuit sejak Fase 15. Semua yang gagal bisa diperbaiki di sisi La_Voiture tanpa merevisi blueprint; satu keputusan (pitch pit) ditanyakan ke developer dan dijawab (§6).

## 2. Hasil audit

### 2.1 Yang sudah sesuai (diverifikasi independen, bukan dari laporan builder)

`python -I scratch/monte_azure_geometry_audit.py <blueprint>` (skrip Fase 15, dipakai ulang tanpa perubahan; keluaran T20 diperiksa dengan salinan di scratchpad):

| Aspek | Hasil terukur | Standar |
|---|---|---|
| Panjang plan sebelum skala | 5.385,64 m → `plan_scale` 1,002666 | 5.400 ±25 (regresi ±15) |
| Fillet ter-clamp | tidak ada (20 tikungan, radius minimum dunia 38,1 m di T1) | radius dunia ≥ 22 m |
| Jarak ruas jalan non-adjacent | min 106,6 m sumbu (celah tepi 92,6 m) di s=4046 vs 4200 | tidak ada persilangan |
| Lane pit | 420,0 m (entry 5220, exit 240) | blueprint 420 |
| Entry setelah busur T20 | 36 m (T20 berakhir s=5184) | cukup untuk limiter (preseden Monte 35 m) |
| Elevasi | 0,0 s.d. 104,0 m | blueprint 104,0 |
| Sim | `scripts/gt` tidak memakai landai | tidak ada risiko fisika |

### 2.2 Temuan

| # | Tingkat | Temuan | Bukti | Koreksi |
|---|---|---|---|---|
| A1 | BLOCKER | Pitch kotak 14 m gagal tes banjir pit. Handoff sandbox (kotak 14 m, bay 6 di s=107, gedung 160 m di s=100) mengulang cacat Monte/Brianza/Wangan/Apex. Diukur (`tests/test_ardennes_pit_flood.gd`, seluruh lapangan box bersamaan, batas Monte): tick tumpang tindih kereta 30 m **46** dan rapat 20 m **43** (batas 20), lane kosong **96 dan 94 dtk** (batas 90). Brianza 14 m (Fase 15.1): 21 dan 36 tick. | pengukuran 2026-10-31 pada `sim_layout()` 14 m dengan kotak pertama 217 m setelah entry (angka tercatat di komentar `ardennes_pit_complex.gd`) | Pitch 20 m. Blok kotak 200 m dipusatkan s=10 (kotak pertama s=5320, 100 m setelah entry, kotak terakhir s=100, 140 m sebelum exit); gedung 222 m; menara digeser ke s=150. Keputusan developer §6 butir 1. |
| A2 | TINGGI | Ribbon sandbox 5.408,16 m dan lane 428,16 m adalah artefak: tidak ada pemangkasan `plan_scale` terhadap pemanjangan tanjakan 104 m. Handoff menyuruh "memakai ruang ribbon" dan mempertahankan stasiun bay 6 s=107. | `placement-manifest.json`, `deviation_notes` | Builder produksi memangkas `plan_scale` (6 putaran) sampai ribbon 3D = 5.400,00 m (`plan_scale` 1,001172, plan datar 5.391,95 m); lane = 420 m; semua stasiun blueprint adalah jarak ribbon (#A11, #P5b). |
| A3 | TINGGI | Budget segitiga: 317.944 tri hanya karena LOD review (rel Armco 16 tri/post, floodlight dan penonton separuh, grid terrain 12 m); handoff bilang "produksi memakai kit penuh", yang melewati 320k. | `build-report.md` §6 | Dikirim dengan kit penuh (Armco 36 tri/post, 28 menara, penonton penuh) dan diukur: environment statis 303.276 tri (terrain 62.464); draw call native terburuk 70 (§9). Tidak ada LOD khusus. |
| A4 | TINGGI | Band strip bocor ke ruas jalan lain: `forest L 2750–3700` memuat jalan s=4022–4113 (22 titik) dan `forest L 3700–4800` memuat s=3444–3480 (7 titik). Kelas cacat yang sama dengan Monte F2. | audit | Zona dibaca per stasiun jalan terdekat (`ArdennesZones`, `ArdennesTerrain.zone_at_point`), bukan persegi per rentang s; pohon hanya di zona hutan milik ruasnya sendiri (#D2, #G13). |
| A5 | SEDANG | Landai maksimum 13,5 % di s≈3050 (smoothstep antar sampel elevasi, turunan 45 m dalam 500 m), bukan ≤ 12 % seperti tertulis di spec. | audit (1 m) dan #A24 (5 m: 13,4 %) | Geometri dibekukan dan sim tidak memakai landai: dicatat, tes menegaskan ≤ 14 %. |
| A6 | SEDANG | Empat dari 20 tikungan adalah kink di bawah 15°: T2 5,5°, T3 11,7°, T4 14,2°, T11 6,1°. "T1 Arena Gateway Hairpin" hanya 74,4°. | audit | Aturan Monte: kerb, papan rem, Tecpro, dan panel bendera hanya untuk 16 tikungan ≥ 15° (#A21, #D6, #D7). Nama blueprint dipertahankan tanpa awalan "Tn" (nomor dicetak terpisah oleh HUD). |
| A7 | SEDANG | Mulut exit pit hanya 122 m sebelum pengereman hairpin T1 (R 38 m, 74°); merge mobil keluar pit pada 80 km/j jatuh di zona pengereman lapangan. | audit | Geometri beku. Aspal ekor 65 m dan ramp keluar 90 m dipertahankan; aturan "tunggu lajur bebas" sim berlaku. Dicatat sebagai umpan balik untuk mapgen. |
| A8 | SEDANG | `final/handoff-prompt.md` (Route 1) usang: path `scripts/world/ardennes_*.gd` dan `scenes/race_world/ardennes_circuit.tscn` salah (standar: `circuits/ardennes/`), `cel_water.gdshader` tidak ada, tidak menyebut `CircuitEnvironment`, `CircuitPitComplex`, `FlagPanelSet`, `WorldSkyRig`, lima tes kontrak, `measure_env_draw_calls.gd`, `smoke_pit_race.gd`; "52+ suite" padahal 79. | Guide §2b, §3 | Dokumen ini jadi satu-satunya instruksi. |
| A9 | SEDANG | Skrip sandbox bergantung pada `vendor/lavoiture/*` (salinan kit), `core/compiler.gd`, `core/vendor_kit.gd`, dan shim; tidak boleh disalin. `steel_fence.gd` dan `catch_fence.gd` lokal ("belum dipindah ke kit produksi"). | `ardennes_environment.gd` preload | Dipetakan ulang ke kelas produksi (§3); pagar baja dan catch fence jadi modul `circuits/ardennes/` (bukan kit bersama; sirkuit tidak boleh meminjam dari sirkuit lain). |
| A10 | SEDANG | Registri menunjuk `res://scenes/race_world/ardennes_circuit.tscn` (datar). `CircuitData.is_playable()` = scene ada, jadi kartu playable begitu scene ada di path itu. Dua tes menegaskan "Ardennes belum dibangun". | `circuit_calendar_registry.gd`, `test_track_selector_ui` #S4c, `test_visual_polish_and_consistency` | Path → `circuits/ardennes/ardennes_circuit.tscn`; asersi "belum dibangun" pindah ke Ronde 06 Stoke Crown (#S4d). |
| A11 | SEDANG | Referensi gate tidak ada: `reference-assets/tracks/ardennes/` kosong; paket tidak membawa PNG konsep (hanya HTML). | listing | Render DAY sandbox yang disetujui (`builds/ardennes/review/day/Gate_Cam_1..4`) dipakai sebagai view1–4; tanpa kredit Genex. |
| A12 | TINGGI | Menara kontrol sandbox s=215 (pusat lateral 32) berdiri 26 m di luar gedung 140 m (ujung s=170). Pada layout 20 m dengan gedung tetap berpusat s=100 gedung 204–222 m berakhir di s=202–211 dan menyentuh menara (tapak ±14 m dari 215 mulai s=201). | hitungan | Gedung dipusatkan s=10 (ujung s=121); menara s=150, pusat lateral 32 (offset node 8 m, struktur kit 24 m lateral); jarak ke ujung gedung 21 m (#P15). |
| A13 | SEDANG | Prasyarat terowongan dan flyover yang belum terbukti untuk produksi: sinar bebas sepanjang jalan (pelajaran Monte #L8c), clearance deck. GLB terowongan baru ternyata terbuka (tanpa pelat `dark`) tetapi berbelok mengikuti T9 (s=2696) di dalam kanopi. | probe GLB | Sinar mengikuti jalan: 0/1.920 terblokir (#L4); deck flyover ≥ 9,7 m (#L5). |

## 3. Keputusan arsitektur

| Bagian | Template | Alasan |
|---|---|---|
| Builder (vertex + fillet + `plan_scale`) | `monte_azure_circuit_builder.gd` | pola identik; 20 tikungan, jalan 14 m, 6 putaran pemangkasan |
| Pit complex | `monte_azure_pit_complex.gd` (ekor, celah barrier, atenuator, pitch 20 m) dengan penampang GP `GtPitLayout` (dinding, kotak 17, garasi 20,6) | GP, jalan 14 m |
| Gedung pit | GLB hero `futuristic_pit_building.glb` disusun ulang ke pitch 20 m (`ArdennesPitBuilding`) | gedung yang disetujui developer; kit `PitBuilding` hanya fallback |
| Environment | `brianza_environment.gd` (kit Tier A: kerb, run-off, gravel, Armco, Tecpro, papan rem, menara lampu, panel bendera) + `monte_azure_environment.gd` (kontrak, sky, flag) | sirkuit GP berelevasi |
| Terrain | heightfield sandbox yang disetujui (winding, bed 0,16 m, potongan tribun, lembah sungai) di-port ke `ArdennesTerrain` | developer menyetujui terrain sandbox |
| Sky | `WorldSkyRig` + `SKY_PROFILES` | Guide §3 Tahap 3.3 |

Modul (`scripts/world/circuits/ardennes/`): `ardennes_circuit_builder`, `ardennes_pit_complex`, `ardennes_pit_building`, `ardennes_pit_separator`, `ardennes_environment` (orkestrasi + kontrak), `ardennes_terrain`, `ardennes_zones`, `ardennes_foliage`, `ardennes_landmarks`, `ardennes_paddock`, `ardennes_catch_fence`. Shader: `shaders/ardennes_{anime_glass,steel_mesh,terrain_mottle,tree_wind}.gdshader`. Aset: `assets/tracks/ardennes/models/` (5 GLB + `asset_manifest.json`). Scene: `scenes/race_world/circuits/ardennes/ardennes_circuit.tscn`.

## 4. Spesifikasi produksi (angka yang dikirim)

### 4.1 Builder

`LENGTH_M = 5400`, `ROAD_WIDTH_M = 14` (`road_half_width_m = 7,0`), 20 vertex tikungan + S/F, `plan_scale` dipangkas sampai ribbon 3D tepat 5.400,00 m. Elevasi smoothstep antar 13 titik blueprint (0,0–104,0 m). Sektor sepertiga 1.800 / 3.600 / 5.400. `KERB_MIN_ANGLE_DEG = 15`: 16 tikungan berkerb, 4 kink tanpa.

### 4.2 Pit complex (satu penampang, jarak dari garis tengah ke kanan)

| Lateral (m) | Isi |
|---|---|
| 7,00 | tepi aspal |
| 8,30 | pemisah pit: tembok beton 1,35 m + pagar mesh baja 1,65 m (total nominal 3 m); hidung dengan atenuator oranye |
| 8,60 – 13,00 | fast lane 4,4 m; mobil di tengah 10,8 |
| 13,00 – 20,60 | lajur kerja; mobil box berhenti di 17,0 |
| 20,60 – 40,1 | gedung pit (fasad 20,6; 222 m; sepuluh bay 20 m dengan bukaan 16,4 m) |
| 46 | baris transporter (satu per tim, kit bersama) |

Lane 420 m (entry 5220, exit 240), ramp 80 masuk dan 90 keluar, ekor aspal 65 m sebelum entry dan 65 m sesudah exit (tepi sisi sirkuit bersama dengan tepi jalan). Kotak i di s = 5320 + 20 i (membungkus garis). `sim_layout()`: `stall_first_s` 5320 (tanpa wrap), `stall_pitch_m` 20, `stall_lane_m` 17,0, `fast_lane_m` **10,8**, `edge_lateral_m` 5,2, `queue_gap_m` 8. Tribun utama kit s=125 (kiri, 240 m, jangan diputar lagi: mesh sudah ke −X), teras kaca s=5280 (kiri, 30 m), menara s=150 (pusat lateral 32, fondasi 24×28 m, akses 16×10 m ke apron parkir).

`fast_lane_m` 10,8, bukan 11,6 dari Brianza: pada 11,6 merge merayap mobil yang ditahan menabrak kedatangan kotak berikutnya (34 tick tumpang tindih di skenario menyebar, batas 20); pada 10,8 turun ke 4–16 tick. Hasil bergeser beberapa tick antar perubahan geometri kecil (ribbon 5399,99 m dibanding 5400,00 m): margin ke batas 20 tipis, dicatat di laporan §5.

### 4.3 Environment

`ArdennesEnvironment extends CircuitEnvironment`: terrain 62k tri (sel 12 m, bbox −700..1040 × −360..2210), sungai (`neo_wangan_water.gdshader`), punggung bukit yang mengikuti persegi heightfield, 2.000 pinus (dua batch MultiMesh, shader angin, tanpa bayangan), 575 rumput verge, 60 batu, kit Tier A (16 run kerb, run-off/gravel/groove, 2.538 post Armco, 39 Tecpro, 48 papan rem, 28 menara, 8 panel bendera), catch fence 307 panel, empat landmark (viaduk, flyover, terowongan kanopi 30 bay digabung, teras kaca), slab paddock padat, DAY/SUNSET/NIGHT lewat `WorldSkyRig`, jumbotron dari klasemen, 8 spotlight malam.

### 4.4 Aset dan lisensi

Lima GLB dari sandbox (digenerasi ulang dengan winding benar). Tidak ada aset pihak ketiga, tidak ada Meshy/Genex terpakai.

## 5. Gerbang penerimaan

1. Tes baru: `test_ardennes_circuit`, `test_ardennes_pit_layout`, `test_ardennes_pit_flood`, `test_ardennes_terrain_gate`, `test_ardennes_landmarks`, `test_ardennes_dressing`. `ardennes` masuk `CIRCUITS` lima tes kontrak, `test_flag_panels_contract`, dan skenario `test_pit_stop_in_world`.
2. Regresi penuh `tools/run_tests.ps1`: 100 % lulus.
3. Draw call environment native (`measure_env_draw_calls.gd -- ardennes 150 [tod=N]`) ≤ 180 (target p95 ≤ 160); segitiga environment ≤ 320.000.
4. Smoke native 3 lap 20 mobil (`smoke_race.gd -- ardennes 0|1|2`, `smoke_pit_race.gd -- ardennes`): 20/20 finis, ≤ 16,66 ms rata-rata, 0 orphan.
5. 6 kamera × 3 mode, flythrough chase 150 m dua arah, aerial pit/entry/exit di `executor-report/screenshots/phases/phase-16/`.

## 6. Keputusan developer (2026-10-31)

| # | Butir | Keputusan |
|---|---|---|
| 1 | Pitch pit 14 m (layout disetujui) vs 20 m (standar sejak Fase 15) | "Ukur 14 m dulu, 20 m bila merah" (rekomendasi). 14 m merah (A1), maka 20 m. |

Default Executor (tidak diminta developer): referensi gate dari render sandbox yang disetujui (tanpa kredit Genex); pagar baja dan catch fence tetap modul Ardennes; tidak ada commit sampai diminta.

## 7. Di luar cakupan

Ubah geometri blueprint; ubah entri kalender sirkuit lain; ubah gaya cel global atau shader bersama; menambah dependensi; menyalin `vendor/` atau `dummy_car.gd` sandbox; LOD khusus review; pass seni hero.

## 8. Self-review

Dibaca ulang sebagai builder tanpa konteks: path absolut dari root repo; angka pit dapat dihitung dari satu penampang; keputusan Executor ditandai; semua angka §9 berasal dari tes dan skrip native yang dijalankan.

## 9. Catatan implementasi

Diisi di `executor-report/reports/FASE-16-ARDENNES-CIRCUIT-REPORT.md` (tes, gerbang, deviasi).
