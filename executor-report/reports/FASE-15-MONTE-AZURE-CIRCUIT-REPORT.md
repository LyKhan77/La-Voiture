# FASE 15 — Sirkuit Monte Azure Marina (Ronde 04, SPRINT)

Tanggal: 2026-10-30 · Branch: `fase-15-monte-azure-circuit` · Spesifikasi: [`docs/superpowers/specs/2026-10-30-fase-15-monte-azure-audit-and-production-spec.md`](../../docs/superpowers/specs/2026-10-30-fase-15-monte-azure-audit-and-production-spec.md) · Prompt: [`prompt/TASK-MONTE-AZURE-CIRCUIT.md`](../../prompt/TASK-MONTE-AZURE-CIRCUIT.md)

## 1. Ringkasan

Monte Azure Marina (2,85 km, 19 tikungan, delta 41,9 m, searah jarum jam, pit di kanan) kini playable dari menu: kartu Ronde 04 aktif, balapan 3 lap Sprint berjalan dengan 20 mobil, pit stop dilayani 10 kotak, DAY/SUNSET/NIGHT dan hujan bekerja. Geometri mengikuti blueprint mapgen yang dibekukan (`geometry_hash sha256:f495332f…`) tanpa mengubah satu angka pun; semua deviasi ada di §5 dan di SPEC §9.

Hasil singkat:

- Panjang ribbon 3D tepat 2.850,00 m; semua `s` blueprint adalah jarak ribbon. `scratch/monte_azure_geometry_audit.py` memverifikasi hash dan geometri paket.
- Lane pit 320 m (entry 2.790, exit 260), 10 kotak pitch 12 m. `sim_layout()` memakai `stall_first_s` tanpa wrap (2.896); 20 mobil dilayani di world nyata (`tests/test_pit_stop_in_world.gd`).
- Tanah, laut, 5 hero GLB, 189 blok fasad (132 kota + 57 gudang paddock) dan 404 pohon berdiri di atas satu heightfield; jalan tidak pernah terkubur (gerbang terrain #G0–#G14).
- Smoke native 3 lap, 20 mobil, DAY/SUNSET/NIGHT: 20/20 finis, podium muncul, frame rata-rata 16,66–16,67 ms, 0 orphan.
- Seni hero masih tingkat massing (GLB paket mapgen); pass seni akhir belum dikerjakan (§8).

## 2. Yang dibangun

| Berkas | Isi |
|---|---|
| `scripts/world/circuits/monte_azure/monte_azure_circuit_builder.gd` | spline tertutup dari blueprint (fillet, `plan_scale` dipangkas sampai ribbon 3D = 2.850,00 m), elevasi smoothstep, 19 tikungan bernama, sektor sepertiga |
| `…/monte_azure_pit_complex.gd` | `MonteAzurePitComplex extends CircuitPitComplex`: lane 320 m (entry 2790, exit 260), 10 kotak pitch 12 m, tembok pit, crash cushion, 10 garasi, transporter, `PitBuilding`/`MainGrandstand`/`RaceControlTower`, catch fence di lurusan start, lampu pit, `sim_layout()` |
| `…/monte_azure_environment.gd` | `MonteAzureEnvironment extends CircuitEnvironment`: terrain + laut, tembok beton jalan raya, kerb jalan (16 tikungan ≥ 15°), lampu jalan, lampu terowongan, papan rem, 8 panel bendera, langit via `WorldSkyRig` |
| `…/monte_azure_terrain.gd`, `monte_azure_zones.gd` | heightfield 8 m (27,6k tri): kerucut per stasiun jalan, dek, bed jalan, garis pantai; zona strip dibaca per stasiun jalan terdekat |
| `…/monte_azure_landmarks.gd` | 5 hero GLB: kasino, hotel, terowongan tebing (di atas jalan), yacht (di dermaga), skybridge (menyeberangi jalan) |
| `…/monte_azure_districts.gd`, `monte_azure_foliage.gd` | kota (blok fasad per distrik) dan vegetasi (palem, pinus, cypress, semak) |
| `shaders/monte_azure_facade.gdshader` | fasad Riviera: dinding, kerai, kornis, atap genteng/datar, jendela menyala malam |
| `scenes/race_world/circuits/monte_azure/monte_azure_circuit.tscn`, `assets/tracks/monte_azure/models/*` | scene dan 5 GLB + `asset_manifest.json` |
| `scripts/core/circuit_calendar_registry.gd` | path scene Ronde 04 → modul (satu-satunya perubahan non-Monte) |
| `reference-assets/tracks/monte_azure/view1..view4.png` | 4 view gate (Genex `image --edit`, 28 kredit) |

## 3. Tes

`powershell -NoProfile -File tools/run_tests.ps1` setelah semua perubahan kode dan `godot --headless --path . --import`: **74 dari 74 suite lulus, 0 gagal, 1.106 detik** (sebelum Fase 15: 69/69). Lima suite baru:

| Suite | Cakupan |
|---|---|
| `tests/test_monte_azure_circuit.gd` | #M1–#M26: hash, panjang ribbon 2.850,00 m, 19 tikungan bernama, elevasi, sektor, registry/playable |
| `tests/test_monte_azure_pit_layout.gd` | #P0–#P19: penampang pit, `sim_layout` (paritas dengan sim #P5b), kotak, garasi, tembok, ruang bebas lajur (sinar dari atas tiap 0,25 m, #P18), celah barrier (#P19) |
| `tests/test_monte_azure_terrain_gate.gd` | #G0–#G14: jalan tidak terkubur, bed 14 m, dek rata, garis pantai, normal terrain menghadap atas (#G14) |
| `tests/test_monte_azure_landmarks.gd` | #L0–#L16: 5 hero (kasino, hotel, terowongan, yacht, skybridge), clearance, lampu terowongan (#L8b) |
| `tests/test_monte_azure_dressing.gd` | #D1–#D14: ≥ 120 blok (189), MultiMesh per distrik, jarak 10,5 m dari jalan, zona, tanpa tumpang tindih, pohon |

Tes yang ada diperluas: `monte_azure` masuk ke `CIRCUITS` di `test_circuit_environment_contract`, `test_pit_complex_contract`, `test_pit_team_assignment_contract`, `test_team_signage_contract`, `test_team_identity_consistency`, dan `test_flag_panels_contract`; skenario Monte di `test_pit_stop_in_world` (pit stop nyata); `test_track_selector_ui` (#S4b Monte playable, #S4c Ardennes "IN PREPARATION") dan `test_visual_polish_and_consistency` (carousel).

## 4. Gerbang

| Gerbang | Batas | Terukur |
|---|---|---|
| Draw call environment statis (`measure_env_draw_calls.gd -- monte_azure 150 tod=N`) | ≤ 180 (≤ 160 per target kamera) | terburuk 106 pada DAY, SUNSET, dan NIGHT; probe statis 75 |
| Draw call environment saat balapan (smoke) | ≤ 180 | sampel 111–140; satu sampel kamera balap saat SUNSET 171 (di bawah 180, di atas 160; lihat §8) |
| Segitiga environment statis | < 320.000 | 110.458 (terrain 27.624) |
| Frame time smoke native 3 lap, 20 mobil (`scratch/smoke_race.gd -- monte_azure`) | ≤ 16,66 ms (60 FPS terkunci) | rata-rata 16,66–16,67 ms pada DAY/SUNSET/NIGHT, p95 16,7–16,8 ms, terburuk ≤ 17,6 ms |
| Mobil finis, podium | 20/20 | 20/20, podium muncul |
| Node yatim setelah balapan dibebaskan | 0 | 0 |
| Panjang ribbon | 2.850 m | 2.850,00 m (#M11) |

Uji mutasi (membuktikan tes peka): `ROAD_DROP_M = -0,5` membuat #G4 dan #G6 gagal; `PIT_WALL_M = 8,0` membuat #P7 dan #P18 gagal.

## 5. Deviasi dari paket mapgen dan dari SPEC

Dari paket mapgen (dicatat juga untuk `build-feedback.md`):

1. `offset_m` blueprint adalah jarak sisi dekat; terowongan dan skybridge ditempatkan di atas garis tengah jalan (bukan di samping). Terowongan 190 → 150 m dan dipusatkan di s=1.330 karena lurusan T7→T8 hanya 166 m.
2. Menara kontrol s=130 → 176 (130 jatuh di dalam gedung pit 124 m); tribun 240 → 160 m; yacht di dermaga (29 m) bukan 60 m.
3. Nama tikungan T7/T8/T11/T12 diganti agar cocok dengan landmark (keputusan developer).
4. Penampang pit: `fast_lane_m` 8,5 dibaca sebagai pusat jalur (kontrak sim), kotak 13,0, garasi 16,0, gedung pit 15,5 (Neo-Wangan disesuaikan jalan 11 m), bukan garasi 20,1.
5. Strip band tidak dipakai sebagai persegi: zona ditentukan per stasiun jalan terdekat (band `urban R 240–680` memuat jalan s=809–1026).

Dari SPEC: lihat tabel §9 SPEC (13 butir).

## 6. Temuan untuk agen mapgen

Untuk `mapgen-circuit/builds/monte_azure/build-feedback.md` (paket mapgen tidak diubah):

1. `offset_m` landmark adalah jarak sisi dekat, bukan pusat. Terowongan dan skybridge diberi `offset_m` seolah di samping jalan padahal harus berdiri di atas jalan; sebutkan `offset_m: 0` dan `on_road: true` secara eksplisit.
2. Terowongan 190 m tidak muat di lurusan T7→T8 yang hanya 166 m. Panjang terowongan harus ≤ lurusan dikurangi tepi fillet.
3. Menara kontrol di s=130 jatuh di dalam gedung pit (124 m). Beri jarak menara dari gedung.
4. Band strip dibaca sebagai persegi tumpang-tindih dengan kaki jalan lain (band `urban R 240–680` memuat jalan s=809–1026). Berikan zona per segmen jalan, bukan per persegi.
5. `fast_lane_m` 8,5 tidak jelas: pusat jalur atau tepi. Kontrak sim memakai pusat; tuliskan satuan dan acuannya.
6. T7/T8/T11/T12 bernama tidak sesuai landmark terdekat; sudah diganti oleh developer (SPEC §1b), perbarui sumbernya.
7. Beberapa tikungan berlabel "hairpin" di paket adalah kink pendek pada polyline; kerb dan papan rem dipasang menurut sudut tikungan yang terukur (≥ 15°, 16 tikungan).
8. Prototipe paket terbaca seperti sirkuit GP; arah produksi (sirkuit jalan raya kota-pantai) ada di `production-handoff.md`, bukan di `handoff-prompt.md`. Satukan keduanya.

## 7. Bukti visual

`executor-report/screenshots/phases/phase-15/` (1920×1080, `scratch/capture_monte_azure_views.gd`):

- `cam1-start-pit`, `cam2-casino-approach`, `cam3-tunnel-mouth`, `cam4-yachts-pit-entry`, `cam5-overview`, `cam5-horizon`, `cam6-chase` × `-day`, `-sunset`, `-night` (21 gambar).
- Pit: `pit-lane-day`, `pit-entry-day`, `pit-exit-day`, `pit-aerial-day`, `paddock-aerial-day`, `grandstand-day`.
- Terbang rendah sepanjang lap tiap 150 m, kedua arah: `fly-fwd-00…19-day`, `fly-rev-00…19-day` (`09` berada di dalam terowongan, bukaan tampak hanya di sisi kanan).
- View referensi gerbang (Genex `image --edit`, bukan tangkapan game): `reference-assets/tracks/monte_azure/view1…view4`.

Catatan visual: bagian dalam terowongan siang hari berwarna pucat (material GLB massing) dan lampu langit-langit menyala; malam hari jendela blok menyala, kolam cahaya lampu jalan terlukis di aspal.

## 8. Belum / risiko

- Pass seni hero: 5 GLB paket mapgen masih tingkat massing (bentuk benar, detail polos). Meshy menolak tugas (HTTP 402, paket gratis), jadi tekstur dan detail baru belum dibuat.
- Terrain satu heightfield seragam sel 8 m (27,6k tri), bukan LOD; cukup dalam budget tetapi tidak mengecil di kejauhan.
- Jarak kamera TV: baris fasad kota mulai 26 m dari tepi jalan agar kamera generik (20 m, tinggi 2,4 m) bersih. Jika kamera Monte dipindah lebih jauh, baris itu bisa dirapatkan.
- Sampel draw call terburuk saat balapan SUNSET 171 (kamera balap) di bawah 180 tetapi di atas target 160 per kamera; DAY dan NIGHT ≤ 140.
- Bukti visual diambil lewat `scratch/capture_monte_azure_views.gd` dan dinilai dengan mata; tidak ada tes otomatis yang membandingkan gambar.
- Tidak ada yang di-commit; semua masih di working tree branch `fase-15-monte-azure-circuit`. `.uid`/`.import` baru ikut di working tree.
- Tinjauan akhir dilakukan sendiri oleh executor (tanpa subagen), jadi bukan pemeriksa baru yang independen.
