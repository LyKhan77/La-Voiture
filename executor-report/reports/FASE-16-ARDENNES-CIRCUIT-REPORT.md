# FASE 16 — Sirkuit Ardennes Valley Ring (Ronde 05, GRAND PRIX)

Tanggal: 2026-10-31 · Branch: `fase-16-ardennes-circuit` (dari `main` c355dd5, belum di-commit) · Spesifikasi: [`docs/superpowers/specs/2026-10-31-fase-16-ardennes-audit-and-production-spec.md`](../../docs/superpowers/specs/2026-10-31-fase-16-ardennes-audit-and-production-spec.md) · Sumber: `mapgen-circuit/builds/ardennes/production-handoff.md` (disetujui developer 2026-10-31)

## 1. Ringkasan

Ardennes Valley Ring (5,40 km, 20 tikungan, delta 104 m, searah jarum jam, pit di kanan) playable dari menu: kartu Ronde 05 aktif, balapan 3 lap Grand Prix berjalan dengan 20 mobil, pit stop dilayani 10 kotak, DAY/SUNSET/NIGHT bekerja. Geometri mengikuti blueprint mapgen yang dibekukan (`geometry_hash sha256:fea86645…`) tanpa mengubah satu angka pun; deviasi ada di §5.

Yang diaudit dulu dan mengubah rencana (spesifikasi §2.2):

- **Pitch pit 14 m gagal tes banjir pit.** Handoff sandbox memakai kotak 14 m (bay 6 di s=107, gedung 160 m di s=100). Diukur lebih dulu sebagai tes merah (`tests/test_ardennes_pit_flood.gd`): tumpang tindih 46 dan 43 tick (batas 20), lane kosong 96 dan 94 dtk (batas 90). Developer memilih "ukur 14 m dulu, 20 m bila merah"; hasilnya merah, maka pitch **20 m**: blok kotak 200 m dipusatkan s=10, gedung 222 m, menara s=150.
- **Ribbon 5.408,16 m dan lane 428,16 m di sandbox adalah artefak** tanpa pemangkasan skala; produksi memangkas `plan_scale` sampai ribbon 3D tepat 5.400,00 m dan lane 420,0 m.
- **LOD review sandbox** (Armco 16 tri/post, floodlight dan penonton separuh) dibuang: kit penuh dikirim dan diukur di bawah budget (303.276 tri statis, draw call native terburuk 70).
- **Band strip bocor** ke ruas jalan lain (dua band hutan kiri): zona dibaca per stasiun jalan terdekat.

Hasil singkat:

- Ribbon 3D tepat 5.400,00 m, 20 tikungan, 16 berkerb (T2, T3, T4, T11 kink < 15°), landai maksimum 13,4 % (smoothstep antar titik elevasi blueprint; sim tidak memakai landai).
- Lane pit 420 m (entry 5220, exit 240), 10 kotak pitch 20 m (kotak i di s = 5320 + 20 i), gedung GLB hero 222 m dengan bay disusun ulang dari 14 ke 20 m. Seluruh lapangan box bersamaan: 20/20 terlayani, 0–16 tick tumpang tindih (batas 20), lane kosong 83–86 dtk (batas 90).
- Terrain sandbox yang disetujui di-port apa adanya (winding, bed 0,16 m, potongan tribun, lembah sungai); gerbang terrain #G0–#G14 lulus pada mesh yang dirender.
- Smoke native 3 lap, 20 mobil, DAY/SUNSET/NIGHT: 20/20 finis, 16,66–16,67 ms rata-rata (p95 16,71–16,77), 0 orphan.
- Seni hero tingkat model sandbox yang disetujui (GLB 700–12.000 tri); pass seni akhir belum dikerjakan (§8).

## 2. Yang dibangun

| Berkas | Isi |
|---|---|
| `scripts/world/circuits/ardennes/ardennes_circuit_builder.gd` | spline tertutup dari blueprint (20 vertex, fillet, `plan_scale` dipangkas 6 putaran sampai ribbon 3D = 5.400,00 m), elevasi smoothstep 13 titik, 20 tikungan bernama (tanpa awalan "Tn"), sektor sepertiga |
| `…/ardennes_pit_complex.gd` | `ArdennesPitComplex extends CircuitPitComplex`: lane 420 m, 10 kotak pitch 20 m, aspal yang tumbuh dari tepi jalan (ekor 65 m masuk dan keluar), pemisah 1,35 m + 1,65 m, atenuator, garasi dan kru standby 13, papan nama tim, transporter, `MainGrandstand`/`RaceControlTower` kit, lampu pit, rambu PIT IN / 80 / PIT OUT, `sim_layout()` |
| `…/ardennes_pit_building.gd` | gedung pit hero `futuristic_pit_building.glb`: bay 14 → 20 m (bukaan 11 → 16,4 m, pilar ikut membesar, ujung dan perlengkapan bay hanya bergeser), digabung jadi dua permukaan (struktur ber-outline dengan strip shutter berwarna tim, kaca halftone) |
| `…/ardennes_pit_separator.gd` | pagar mesh baja 4 m (alpha-scissor): dua MultiMesh |
| `…/ardennes_environment.gd` | `ArdennesEnvironment extends CircuitEnvironment`: terrain + sungai + punggung bukit, kit Tier A (kerb, run-off, gravel, groove, Armco, Tecpro, papan rem, menara lampu, panel bendera), catch fence, langit via `WorldSkyRig`, jumbotron, spotlight malam |
| `…/ardennes_terrain.gd`, `ardennes_zones.gd` | heightfield 12 m (62k tri): bed 0,16 m, koridor datar 26 m + blend 38 m, dek, potongan tribun, lembah sungai, bank terowongan; zona strip per stasiun jalan terdekat |
| `…/ardennes_foliage.gd` | 2.000 pinus (dua batch, shader angin), 575 rumput verge, 60 batu; di belakang rel dan jebakan kerikil |
| `…/ardennes_landmarks.gd` | viaduk lengkung (kaki di sungai), flyover (deck 9,7 m di atas jalan), terowongan kanopi (30 bay digabung, terbuka), teras kaca |
| `…/ardennes_paddock.gd`, `ardennes_catch_fence.gd` | slab paddock padat (teras, lahan parkir, fondasi menara, akses, plinth dua tribun); catch fence 307 panel di luar tikungan tajam |
| `shaders/ardennes_{anime_glass,steel_mesh,terrain_mottle,tree_wind}.gdshader` | kaca halftone, mesh baja, terrain berbintik, angin pinus |
| `scenes/race_world/circuits/ardennes/ardennes_circuit.tscn`, `assets/tracks/ardennes/models/*` | scene dan 5 GLB + `asset_manifest.json` |
| `scripts/core/circuit_calendar_registry.gd` | path scene Ronde 05 → modul (satu-satunya perubahan non-Ardennes di skrip) |
| `reference-assets/tracks/ardennes/` | key visual dan view1–4 dari render DAY sandbox yang disetujui (tanpa kredit Genex) |
| `scratch/capture_ardennes_views.gd` | tangkapan native: `main`, `pit`, `fly`, `tunnel`, `flyover`, `pitjoin` |

## 3. Tes

`powershell -File tools/run_tests.ps1`: **85 dari 85 suite lulus, 0 gagal, 1.716 detik** (sebelum Fase 16: 79/79); kanopi tim dan trailer ditambahkan setelah putaran itu, lalu enam suite Ardennes dan tujuh suite kontrak (`pit_complex_contract`, `pit_team_assignment`, `team_signage`, `team_identity`, `circuit_environment`, `flag_panels`, `pit_stop_in_world`) dijalankan ulang: semuanya lulus. Enam suite baru:

| Suite | Cakupan |
|---|---|
| `tests/test_ardennes_circuit.gd` | #A1–#A26: registry/playable, hash, ribbon 5.400,00 m, `plan_scale`, 20 tikungan bernama dan arah, 16 berkerb, elevasi 0–104 m, landai ≤ 14 %, sektor, 0 orphan |
| `tests/test_ardennes_pit_layout.gd` | #P0–#P27: `sim_layout` (paritas dengan sim), penampang pit, kotak/garasi/bay, tembok 1,35 m + pagar 1,65 m (#P24–#P27), sambungan lane–jalan dan ekor 65 m (#P20–#P22b), ruang bebas lajur 420 m (#P18), gedung 222 m dan menara 21 m dari ujungnya |
| `tests/test_ardennes_pit_flood.gd` | seluruh lapangan box bersamaan di lane Ardennes (kereta 30 m, rapat 20 m, menyebar, lapangan yang dibalap), batas Monte |
| `tests/test_ardennes_terrain_gate.gd` | #G0–#G14 pada mesh yang dirender: jalan tidak terkubur (0/2.703), bed ≤ 0,22 m, pit/paddock dan dua tribun di dek, sungai terukir, puncak 103,83 m, `ground_y_at` = mesh, zona per ruas terdekat |
| `tests/test_ardennes_landmarks.gd` | #L0–#L9: 5 GLB + manifest, 4 hero, terowongan terbuka (0/1.920 sinar sepanjang jalan yang berbelok, dua arah), deck flyover ≥ 9,7 m, viaduk di sungai dan 103 m dari ruas lain, teras kaca 44 m dari jalan, dua tribun tidak tumpang tindih, kaca menyala malam |
| `tests/test_ardennes_dressing.gd` | #D1–#D15: pinus ≥ 23 m dari garis tengah dan ≥ 9 m di belakang rel (tidak pernah di jebakan kerikil), 16 run kerb dan nol di kink, 2.538 post Armco, Tecpro, papan rem, menara, 8 panel bendera, nol Armco di sepanjang aspal pit, catch fence, ≤ 320k tri |

Tes yang ada diperluas: `ardennes` masuk `CIRCUITS` di `test_circuit_environment_contract`, `test_pit_complex_contract`, `test_pit_team_assignment_contract`, `test_team_signage_contract`, `test_team_identity_consistency`, `test_flag_panels_contract`; skenario Ardennes di `test_pit_stop_in_world`; `test_track_selector_ui` (#S4c Ardennes playable, #S4d Stoke Crown "IN PREPARATION") dan `test_visual_polish_and_consistency` (carousel).

Cacat yang ditemukan oleh tes yang gagal dahulu: hash zona kosong karena `PackedInt32Array` dalam Dictionary tidak ber-referensi (semua kueri `track_query` kosong, pohon tanpa pemeriksaan jarak; ditangkap #G13); rangkaian run kerb menyambung antar tikungan searah (16 run, bukan 3); kontrak `PitBuilding` (nama node, `structure` berisi warna livery) di `test_pit_team_assignment_contract`; sinar terowongan harus mengikuti tikungan T9 di dalam kanopi (#L4).

## 4. Gerbang

| Gerbang | Batas | Terukur |
|---|---|---|
| Draw call environment native (`measure_env_draw_calls.gd -- ardennes 150 tod=N`) | ≤ 180 (target p95 ≤ 160) | terburuk **70** pada DAY (69 pada SUNSET dan NIGHT sebelum kanopi dan trailer ditambahkan; p95 67; tanpa bayangan 41); terburuk di s=2700 (terowongan) |
| Segitiga environment statis (`env.stats()`) | ≤ 320.000 | 303.276: kit trackside 127.888 (Armco ±91k, Tecpro, menara), terrain 62.060, landmark 45.824 (termasuk pass outline), pinus dan vegetasi 42.704, langit 10.082, kerb/run-off 8.270. Kompleks pit (kit tribun utama 51.194, 10 kru standby 26.200, gedung 8.024, papan nama 3.218, transporter 5.500) menambah 99.438 di luar gerbang: environment + pit ≈ 402.700, di atas "< 350.000" AGENTS §6 bila dihitung bersama; gerbang resmi dan semua sirkuit mengukur `env.stats()` saja (pembanding, environment + pit statis: Brianza 318.232 + 114.598 = 432.830, Neo-Wangan 176.402 + 117.352 = 293.754, Monte Azure 109.644 + 115.980 = 225.624) |
| Frame time smoke native 3 lap, 20 mobil (`scratch/smoke_race.gd -- ardennes 0\|1\|2`) | ≤ 16,66 ms | DAY 16,66 / p95 16,72 / terburuk 17,33 ms (diulang setelah kanopi dan trailer); SUNSET 16,66 / 16,74 / 17,38; NIGHT 16,67 / 16,71 / 16,96; 60,0 FPS |
| Smoke pit native (`scratch/smoke_pit_race.gd -- ardennes`, 6 mobil box bersamaan) | semua terlayani | 20/20 finis, 6 stop, puncak 6 di lane, 16,67 ms rata-rata (p95 16,79), 0 orphan |
| Mobil finis, podium | 20/20 | 20/20, podium muncul |
| Node yatim setelah balapan dibebaskan | 0 | 0 |
| Waktu bangun environment | — | 1,1 detik |
| Panjang ribbon | 5.400 m | 5.400,00 m (#A11) |
| Pit flood (`test_ardennes_pit_flood`) | tumpang tindih ≤ 20 tick, lane kosong ≤ 90 dtk, diam di luar kotak ≤ 18 dtk | 0 / 0 / 16 / 1 tick (kereta / rapat / menyebar / balap), lane kosong 86 / 83 dtk, diam terlama 14,9 dtk (balap 17,9 dtk ≤ 20) |

Angka pengukuran 14 m (merah, kotak pertama 217 m setelah entry, `fast_lane_m` 11,6): tumpang tindih 46 / 43 / 12 / 0 tick, lane kosong 96 / 94 dtk. Pada 20 m dengan `fast_lane_m` 11,6 skenario menyebar 34 tick (merah); `fast_lane_m` 10,8 menurunkannya ke 4–16 tick. Hasil pit flood sensitif terhadap perubahan geometri kecil (ribbon 5399,99 → 5400,00 menggeser skenario menyebar dari 4 ke 16 tick) dan pada seed. Seed 7, 13, 21, 99 (skenario sintetis dan lapangan yang dibalap): tumpang tindih 0–24 tick; satu pelanggaran batas 20 (seed 7, rapat 20 m: 24 tick), 20–24 tick adalah tabrakan EXIT/EXIT dari lepas-paksa 12/20 dtk yang menurut Fase 15.1 menyisakan 0–37 tick per seed di Brianza dan 0–12 di Apex (aturan sim bersama, bukan layout).

Catatan pengukuran: sampel draw call di dalam smoke (`environment draw_calls=[145…]`, selisih dua frame dengan kamera balap berjalan) tidak sama dengan gerbang `measure_env_draw_calls.gd` (kamera tetap, lingkungan disembunyikan pada frame yang sama); gerbang resmi adalah yang kedua.

## 5. Deviasi dari paket mapgen dan production-handoff

1. Pitch kotak 14 → 20 m (A1). Blok kotak berpusat s=10 (bukan 100); bay 6 sandbox (s=107) tidak ada lagi: kotak 6 (indeks 5) di s=20. Gedung pit 160 → 222 m, GLB disusun ulang per bay (bukaan 16,4 m).
2. Menara kontrol s=215 → 150 (pusat lateral 32 dan fondasi 24×28 m dipertahankan); tribun utama s=125 dan teras kaca s=5280 dipertahankan (disetujui).
3. `fast_lane_m` 10,8 (pusat jalur cepat, seperti sandbox menggambarnya: tepi dalam 8,5 + setengah lebar 2,2 lalu dibulatkan), dinding pit di 8,3 (permukaan 8,55) agar tidak menimpa tepi dalam jalur.
4. Ribbon dipangkas ke 5.400,00 m (A2): lane 420,0 m, bukan 428,16.
5. Environment tanpa LOD review: kit penuh (A3).
6. Ekor aspal pit 65 m pada kedua mulut (taper entry 65 m mirror exit yang disetujui), diberi celah Armco yang mengikuti.
7. Paddock sandbox: 10 kanopi tim (atap berwarna livery, mengikuti `assign_teams`) dan 6 trailer parkir dibawa; transporter 10 buah dan lampu pit lewat kit bersama. Tidak dibawa: jalur rumput paddock, 50 kru "5 figur per bay" (diganti kru standby 13 orang standar kit per garasi), 4 lampu kerja OmniLight (diganti 5 lampu isi garasi kit + strip LED GLB), kamera gate sandbox.
8. Material GLB: digabung per landmark jadi tiga permukaan (struktur ber-outline, detail tanpa outline: kursi, LED, baja tipis; kaca halftone). Kanopi terowongan digambar dua sisi (atap) supaya langit-langit tidak hitam oleh hull outline.
9. Terrain: algoritma sandbox apa adanya; tambahan: tint terrain dan kanopi (cat pucat terpotong putih di bawah matahari bersama), punggung bukit mengikuti persegi heightfield (cincin bundar sandbox meninggalkan jurang gelap di tepi timur), 2.000 pinus / 575 rumput / 60 batu (sandbox 2.000 / 579 / 53).
10. Pagar baja dan catch fence tetap modul Ardennes, belum dipromosikan ke kit bersama (butuh regresi lintas sirkuit).

## 6. Temuan baru untuk agen mapgen

- Layout pit paket (pitch 14 m, `fast_lane_m` 8,5 dibaca sebagai tepi dalam, bay 6 di s=107) tidak lolos tes banjir pit. Standar sekarang pitch 20 m dan `fast_lane_m` = pusat jalur cepat (Guide §3 butir 8).
- Mulut exit pit hanya 122 m sebelum hairpin T1 dan entry 36 m setelah busur T20 (geometri beku, tidak diubah).
- Empat tikungan kink < 15° (T2, T3, T4, T11); "T1 Arena Gateway Hairpin" hanya 74°.
- Landai 13,5 % (spec menulis ≤ 12 %); smoothstep antar titik elevasi memberi 1,5 kali landai rata-rata. Interpolasi monoton (PCHIP) menurunkannya tanpa mengubah titik beku bila diinginkan.
- Dua band strip kiri menembus ruas jalan lain; selalu baca strip per ruas terdekat.
- Catatan ribbon 5.408,16 m dan lane 428,16 m di `production-handoff.md` adalah artefak sandbox, bukan syarat.

## 7. Bukti visual

`executor-report/screenshots/phases/phase-16/`: `cam1..6` × DAY/SUNSET/NIGHT, set `pit`, `tunnel`, `flyover`, `pitjoin`, dan lembar kontak flythrough chase 150 m dua arah (`flythrough-forward.png`, `flythrough-reverse.png`, masing-masing 37 stasiun; stilnya penuh dihasilkan ulang oleh `capture_ardennes_views.gd -- --set=fly`). Dibandingkan dengan `reference-assets/tracks/ardennes/view1–4` (render sandbox): terrain, viaduk, terowongan, teras kaca, dan lane pit konsisten; aspal produksi lebih terang (shader jalan bersama) daripada aspal review gelap sandbox.

## 8. Belum dikerjakan dan risiko

- Pass seni hero (GLB tingkat model sandbox) dan LOD terrain.
- Pit flood: tes resmi memakai seed 31 (0–16 tick); seed 7 melewati batas 20 di skenario rapat (24 tick), sama seperti sebaran 0–37 tick Brianza (§4).
- Moire mesh saat kamera bergerak (catatan sandbox) dan benturan fisik nyata di terowongan/flyover tidak diuji; hanya kliring lintasan.
- Malam hari: lampu hanya spotlight 8 menara dan LED GLB; tangkapan malam gelap di luar paddock.
- Pagar baja dan catch fence belum jadi kit bersama; jalur rumput paddock sandbox tidak dibawa (§5 butir 7).
- Belum di-commit (permintaan developer: commit hanya bila diminta).
