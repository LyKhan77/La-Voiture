# FASE 15 — Sirkuit Monte Azure Marina (Ronde 04, SPRINT)

Tanggal: 2026-10-30 · Branch: `fase-15-monte-azure-circuit` · Spesifikasi: [`docs/superpowers/specs/2026-10-30-fase-15-monte-azure-audit-and-production-spec.md`](../../docs/superpowers/specs/2026-10-30-fase-15-monte-azure-audit-and-production-spec.md) · Prompt: [`prompt/TASK-MONTE-AZURE-CIRCUIT.md`](../../prompt/TASK-MONTE-AZURE-CIRCUIT.md)

## 1. Ringkasan

Monte Azure Marina (2,85 km, 19 tikungan, delta 41,9 m, searah jarum jam, pit di kanan) kini playable dari menu: kartu Ronde 04 aktif, balapan 3 lap Sprint berjalan dengan 20 mobil, pit stop dilayani 10 kotak, DAY/SUNSET/NIGHT dan hujan bekerja. Geometri mengikuti blueprint mapgen yang dibekukan (`geometry_hash sha256:f495332f…`) tanpa mengubah satu angka pun; semua deviasi ada di §5 dan di SPEC §9.

Putaran kedua (§9) menutup tiga temuan uji main developer: terowongan yang tertutup geometri, pit yang macet saat semua mobil masuk, dan sambungan lane pit ke jalan. Angka di §1–§8 sudah memakai hasil putaran itu.

Hasil singkat:

- Panjang ribbon 3D tepat 2.850,00 m; semua `s` blueprint adalah jarak ribbon. `scratch/monte_azure_geometry_audit.py` memverifikasi hash dan geometri paket.
- Lane pit 420 m (entry 2.790, exit 360), 10 kotak pitch 20 m. `sim_layout()` memakai `stall_first_s` tanpa wrap (2.896); 20 mobil dilayani di world nyata (`tests/test_pit_stop_in_world.gd`) dan tidak saling menembus saat seluruh lapangan masuk bersamaan (`tests/test_monte_azure_pit_flood.gd`).
- Tanah, laut, 5 hero GLB, 189 blok fasad (132 kota + 57 gudang paddock) dan 404 pohon berdiri di atas satu heightfield; jalan tidak pernah terkubur (gerbang terrain #G0–#G14).
- Terowongan terbuka di kedua mulut: sinar sepanjang jalan, dua arah, 40/40 lolos (#L8c).
- Smoke native 3 lap, 20 mobil: 20/20 finis, podium muncul, frame rata-rata 16,67 ms (p95 16,76), 0 orphan; diulang setelah putaran kedua.
- Seni hero masih tingkat massing (GLB paket mapgen); pass seni akhir belum dikerjakan (§8).

## 2. Yang dibangun

| Berkas | Isi |
|---|---|
| `scripts/world/circuits/monte_azure/monte_azure_circuit_builder.gd` | spline tertutup dari blueprint (fillet, `plan_scale` dipangkas sampai ribbon 3D = 2.850,00 m), elevasi smoothstep, 19 tikungan bernama, sektor sepertiga |
| `…/monte_azure_pit_complex.gd` | `MonteAzurePitComplex extends CircuitPitComplex`: lane 420 m (entry 2790, exit 360), 10 kotak pitch 20 m, aspal yang tumbuh dari tepi jalan (ekor 45 m sebelum entry, 55 m sesudah exit), tembok pit, crash cushion dan atenuator di dua ujung barrier, 10 garasi, transporter, `PitBuilding`/`MainGrandstand`/`RaceControlTower`, catch fence di lurusan start, lampu pit, `sim_layout()` |
| `…/monte_azure_environment.gd` | `MonteAzureEnvironment extends CircuitEnvironment`: terrain + laut, tembok beton jalan raya, kerb jalan (16 tikungan ≥ 15°), lampu jalan, lampu terowongan, papan rem, 8 panel bendera, langit via `WorldSkyRig` |
| `…/monte_azure_terrain.gd`, `monte_azure_zones.gd` | heightfield 8 m (27,6k tri): kerucut per stasiun jalan, dek, bed jalan, garis pantai; zona strip dibaca per stasiun jalan terdekat |
| `…/monte_azure_landmarks.gd` | 5 hero GLB: kasino, hotel, terowongan tebing (di atas jalan; mulut dibuka: pelat `dark` dan blok portal diganti rangka dengan liner gelap), yacht (di dermaga), skybridge (menyeberangi jalan) |
| `…/monte_azure_districts.gd`, `monte_azure_foliage.gd` | kota (blok fasad per distrik) dan vegetasi (palem, pinus, cypress, semak) |
| `shaders/monte_azure_facade.gdshader` | fasad Riviera: dinding, kerai, kornis, atap genteng/datar, jendela menyala malam |
| `scenes/race_world/circuits/monte_azure/monte_azure_circuit.tscn`, `assets/tracks/monte_azure/models/*` | scene dan 5 GLB + `asset_manifest.json` |
| `scripts/core/circuit_calendar_registry.gd` | path scene Ronde 04 → modul (satu-satunya perubahan non-Monte) |
| `reference-assets/tracks/monte_azure/view1..view4.png` | 4 view gate (Genex `image --edit`, 28 kredit) |

## 3. Tes

`powershell -NoProfile -File tools/run_tests.ps1` setelah semua perubahan kode (putaran kedua termasuk): **75 dari 75 suite lulus, 0 gagal, 1.406 detik** (sebelum Fase 15: 69/69). Enam suite baru:

| Suite | Cakupan |
|---|---|
| `tests/test_monte_azure_circuit.gd` | #M1–#M26: hash, panjang ribbon 2.850,00 m, 19 tikungan bernama, elevasi, sektor, registry/playable |
| `tests/test_monte_azure_pit_layout.gd` | #P0–#P23: penampang pit, `sim_layout` (paritas dengan sim #P5b), kotak, garasi, tembok, ruang bebas lajur (sinar dari atas tiap 0,25 m, #P18), celah barrier (#P19), sambungan lane–jalan (#P20 aspal bersama tepi jalan dan menutup lebar mobil, #P21 jalur ≤ 7° tanpa tekukan, #P22 ekor ≥ 30 m yang meruncing, #P23 mobil bebas dari barrier) |
| `tests/test_monte_azure_pit_flood.gd` | seluruh lapangan box bersamaan di lane Monte (kereta 30 m, rapat 20 m, menyebar, lapangan yang dibalap): 20/20 terlayani, tumpang tindih ≤ 20 tick, diam di luar kotak ≤ 18 dtk, lane kosong ≤ 90 dtk |
| `tests/test_monte_azure_terrain_gate.gd` | #G0–#G14: jalan tidak terkubur, bed 14 m, dek rata, garis pantai, normal terrain menghadap atas (#G14) |
| `tests/test_monte_azure_landmarks.gd` | #L0–#L16: 5 hero (kasino, hotel, terowongan, yacht, skybridge), clearance, lampu terowongan (#L8b), mulut terowongan terbuka (#L8c: 40 sinar sepanjang jalan, dua arah) |
| `tests/test_monte_azure_dressing.gd` | #D1–#D14: ≥ 120 blok (189), MultiMesh per distrik, jarak 10,5 m dari jalan, zona, tanpa tumpang tindih, pohon |

Tes yang ada diperluas: `monte_azure` masuk ke `CIRCUITS` di `test_circuit_environment_contract`, `test_pit_complex_contract`, `test_pit_team_assignment_contract`, `test_team_signage_contract`, `test_team_identity_consistency`, dan `test_flag_panels_contract`; skenario Monte di `test_pit_stop_in_world` (pit stop nyata); `test_track_selector_ui` (#S4b Monte playable, #S4c Ardennes "IN PREPARATION") dan `test_visual_polish_and_consistency` (carousel).

## 4. Gerbang

| Gerbang | Batas | Terukur |
|---|---|---|
| Draw call environment statis (`measure_env_draw_calls.gd -- monte_azure 150 tod=N`) | ≤ 180 (≤ 160 per target kamera) | terburuk 107 pada DAY, SUNSET, dan NIGHT (diukur ulang setelah putaran kedua) |
| Draw call environment saat balapan (smoke) | ≤ 180 | sampel 111–140; satu sampel kamera balap saat SUNSET 171 (di bawah 180, di atas 160; lihat §8) |
| Segitiga environment statis | < 320.000 | 110.458 (terrain 27.624) |
| Frame time smoke native 3 lap, 20 mobil (`scratch/smoke_race.gd -- monte_azure`) | ≤ 16,66 ms (60 FPS terkunci) | rata-rata 16,66–16,67 ms pada DAY/SUNSET/NIGHT, p95 16,7–16,8 ms, terburuk ≤ 17,6 ms; diulang setelah putaran kedua (DAY): 16,67 / 16,76 / 17,35 ms, 20/20 finis |
| Mobil finis, podium | 20/20 | 20/20, podium muncul |
| Node yatim setelah balapan dibebaskan | 0 | 0 |
| Panjang ribbon | 2.850 m | 2.850,00 m (#M11) |

Uji mutasi (membuktikan tes peka): `ROAD_DROP_M = -0,5` membuat #G4 dan #G6 gagal; `PIT_WALL_M = 8,0` membuat #P7 dan #P18 gagal.

## 5. Deviasi dari paket mapgen dan dari SPEC

Dari paket mapgen (dicatat juga untuk `build-feedback.md`):

1. `offset_m` blueprint adalah jarak sisi dekat; terowongan dan skybridge ditempatkan di atas garis tengah jalan (bukan di samping). Terowongan 190 → 150 m dan dipusatkan di s=1.330 karena lurusan T7→T8 hanya 166 m.
2. Menara kontrol s=130 → 252 (130 jatuh di dalam gedung pit 204 m; menara mengikuti ujung gedung); tribun 240 → 200 m berpusat di s=95; yacht di dermaga (29 m) bukan 60 m.
3. Nama tikungan T7/T8/T11/T12 diganti agar cocok dengan landmark (keputusan developer).
4. Penampang pit: `fast_lane_m` 8,5 dibaca sebagai pusat jalur (kontrak sim), kotak 13,0, garasi 16,0, gedung pit 15,5 (Neo-Wangan disesuaikan jalan 11 m), bukan garasi 20,1. Pitch kotak 20 m (bukan 12 m), lane 420 m, lateral mulut 4,6 m: lihat §9.
5. Strip band tidak dipakai sebagai persegi: zona ditentukan per stasiun jalan terdekat (band `urban R 240–680` memuat jalan s=809–1026).

Dari SPEC: lihat tabel §9 SPEC (13 butir) dan §9b (butir 14–18, putaran kedua).

## 6. Temuan untuk agen mapgen

Untuk `mapgen-circuit/builds/monte_azure/build-feedback.md` (paket mapgen tidak diubah):

1. `offset_m` landmark adalah jarak sisi dekat, bukan pusat. Terowongan dan skybridge diberi `offset_m` seolah di samping jalan padahal harus berdiri di atas jalan; sebutkan `offset_m: 0` dan `on_road: true` secara eksplisit.
2. Terowongan 190 m tidak muat di lurusan T7→T8 yang hanya 166 m. Panjang terowongan harus ≤ lurusan dikurangi tepi fillet.
3. Menara kontrol di s=130 jatuh di dalam gedung pit (124 m). Beri jarak menara dari gedung.
3b. GLB terowongan menutup bore dua kali: dua slab `dark` yang dicat sebagai bukaan, dan blok portal beton penuh di belakangnya. Mulut harus berlubang; sediakan rangka portal, bukan blok.
3c. Pit 10 kotak × 12 m dengan dua mobil per tim tidak bisa dilepas selain dari kotak terdepan; kotak butuh ≥ 18 m untuk dua mobil bertumpuk (mobil kedua menunggu 8 m di belakang yang pertama).
4. Band strip dibaca sebagai persegi tumpang-tindih dengan kaki jalan lain (band `urban R 240–680` memuat jalan s=809–1026). Berikan zona per segmen jalan, bukan per persegi.
5. `fast_lane_m` 8,5 tidak jelas: pusat jalur atau tepi. Kontrak sim memakai pusat; tuliskan satuan dan acuannya.
6. T7/T8/T11/T12 bernama tidak sesuai landmark terdekat; sudah diganti oleh developer (SPEC §1b), perbarui sumbernya.
7. Beberapa tikungan berlabel "hairpin" di paket adalah kink pendek pada polyline; kerb dan papan rem dipasang menurut sudut tikungan yang terukur (≥ 15°, 16 tikungan).
8. Prototipe paket terbaca seperti sirkuit GP; arah produksi (sirkuit jalan raya kota-pantai) ada di `production-handoff.md`, bukan di `handoff-prompt.md`. Satukan keduanya.

## 7. Bukti visual

`executor-report/screenshots/phases/phase-15/` (1920×1080, `scratch/capture_monte_azure_views.gd`):

- `cam1-start-pit`, `cam2-casino-approach`, `cam3-tunnel-mouth`, `cam4-yachts-pit-entry`, `cam5-overview`, `cam5-horizon`, `cam6-chase` × `-day`, `-sunset`, `-night` (21 gambar).
- Pit: `pit-lane`, `pit-entry`, `pit-exit`, `pit-aerial`, `paddock-aerial`, `grandstand` × `-day` (dan `-night` untuk set pit).
- Terowongan (putaran kedua): `tunnel-in-near`, `tunnel-in-side`, `tunnel-out-near`, `tunnel-out-side`, `tunnel-inside-out`, `tunnel-inside-in` × `-day`, `-night`.
- Sambungan lane ke jalan (putaran kedua): `join-entry-approach`, `join-entry-top`, `join-entry-lane`, `join-exit-lane`, `join-exit-top`, `join-exit-track` dan rencana atas `plan-entry`, `plan-exit`, `plan-exit-late` (`-day`).
- Terbang rendah sepanjang lap tiap 150 m, kedua arah: `fly-fwd-00…19-day`, `fly-rev-00…19-day` (`09` berada di dalam terowongan, bukaan tampak hanya di sisi kanan).
- View referensi gerbang (Genex `image --edit`, bukan tangkapan game): `reference-assets/tracks/monte_azure/view1…view4`.

Catatan visual: mulut terowongan kini berlubang; dinding samping dan reveal portal berwarna liner gelap sehingga bukaan terbaca sebagai lubang di muka putih, dan lampu langit-langit menyala; malam hari jendela blok menyala dan kolam cahaya lampu jalan terlukis di aspal. Seluruh tangkapan di folder ini diambil ulang setelah putaran kedua.

## 8. Belum / risiko

- Pass seni hero: 5 GLB paket mapgen masih tingkat massing (bentuk benar, detail polos). Meshy menolak tugas (HTTP 402, paket gratis), jadi tekstur dan detail baru belum dibuat.
- Terrain satu heightfield seragam sel 8 m (27,6k tri), bukan LOD; cukup dalam budget tetapi tidak mengecil di kejauhan.
- Jarak kamera TV: baris fasad kota mulai 26 m dari tepi jalan agar kamera generik (20 m, tinggi 2,4 m) bersih. Jika kamera Monte dipindah lebih jauh, baris itu bisa dirapatkan.
- Sampel draw call terburuk saat balapan SUNSET 171 (kamera balap) di bawah 180 tetapi di atas target 160 per kamera; DAY dan NIGHT ≤ 140.
- Bukti visual diambil lewat `scratch/capture_monte_azure_views.gd` dan dinilai dengan mata; tidak ada tes otomatis yang membandingkan gambar.
- Pit pada sirkuit lain (Apex 14 m, Brianza 14 m, Neo-Wangan 12 m) diukur dan diperbaiki di Fase 15.1 (`FASE-15-1-PIT-PITCH-OTHER-CIRCUITS-REPORT.md`): Brianza dan Neo-Wangan kini 20 m; Apex 20 m di lurusan start/finish (Fase 15.2, `FASE-15-2-APEX-PIT-ON-START-STRAIGHT-REPORT.md`).
- Sisa menunggu 10–16 dtk di lane Monte saat seluruh lapangan masuk bersamaan adalah gerbang rilis aman yang disengaja (mobil yang selesai menunggu lajur cepat bebas dari mobil melaju); pada aliran yang rapat tidak ada celah. Lane kosong 85–86 dtk (sebelumnya 101–122) pada skenario rapat.
- Tinjauan akhir dilakukan sendiri oleh executor (tanpa subagen), jadi bukan pemeriksa baru yang independen.

## 9. Putaran kedua: umpan balik uji main (2026-10-30)

Tiga temuan developer setelah mencoba map; masing-masing direproduksi dengan tes yang merah lebih dulu (SPEC §9b butir 14–18 memuat angka lengkap).

1. **Terowongan masih terhalang geometri di mulut masuk dan keluar.** Akar: GLB menutup bore dua kali (dua slab `dark` dan blok portal beton penuh). Perbaikan: keduanya dibuang, tiap mulut diganti rangka (dua pilar dan lintel), permukaan yang menghadap bore memakai liner gelap tanpa kontur tinta. #L8c: 40/40 sinar terblokir → 0/40; mutasi (pembuka dimatikan) merah di s=1.255 dan s=1.405.
2. **Semua mobil masuk pit lalu macet; apakah karena sempit?** Sebagian ya, tetapi yang sempit adalah pitch kotak (12 m), bukan lebar lajur. Dua mobil satu tim bertumpuk; pada 12 m mobil antrean untuk kotak berikutnya berdiri bumper ke bumper dengan mobil di kotak ini, sehingga kotak hanya bisa dilepas dari yang terdepan, dan mobil saling menembus (523 dan 465 tick tumpang tindih pada skenario kereta dan rapat). Perbaikan: pitch 20 m, lane 420 m, ramp 60/100 m, dan satu perubahan sim (`_queue_behind_teammate` berhenti di belakang mobil yang ditahan di merge, bukan masuk ke atasnya). Hasil lihat tabel di SPEC §9b: tumpang tindih 14/11/7/2 tick (batas 20), diam terlama 16,3/14,7/7,4/14,1 dtk, lane kosong 86/85 dtk. Percobaan lain (pull-out lebih pendek, melewati mobil parkir, batas tunggu 8 dtk, batas merayap) mempercepat lane tetapi menambah tumpang tindih di tes Apex; dibuang. `test_pit_queue_flow` (Apex): 0/17/0/12 → 0/17/0/0 tick; 13 suite `pit` lulus.
3. **Entry dan exit lane perlu disambung mulus ke trek utama.** Akar: aspal lane mulai mendadak di garis entry dan runcing di ujung exit; ada celah dek polos 0,3–0,4 m antara tepi jalan dan aspal lane sepanjang ramp; jalur mobil di lateral 5,2 menembus barrier 0,3 m. Perbaikan: aspal tumbuh dari tepi jalan 45 m sebelum entry dan memudar 55 m setelah exit, tepi sisi sirkuit selalu bersama dengan tepi jalan, lateral mulut 4,6, atenuator di dua ujung barrier, celah barrier mengikuti ekor. #P20–#P23.
