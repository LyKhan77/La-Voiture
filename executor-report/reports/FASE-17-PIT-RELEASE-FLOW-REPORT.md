# FASE 17 — Pit stop tanpa "stuck": rilis box dan pull-out

Tanggal: 2026-10-31 · Branch: `fase-17-pit-release-flow` (dari `main` 5b67121) · Keluhan developer: "saat pitstop scene terkadang stuck padahal mobil sudah masuk pitbox — terkadang sebelum crew melakukan pit, terkadang setelah". Diukur di kecepatan 1x (tick sim 20 Hz = waktu nyata), bukan fast-forward.

## 1. Diagnosa (diukur, bukan ditebak)

Probe: `temp/probe_pit_stuck.gd` (sim murni, 5 sirkuit, skenario `grid`/`stagger` = mobil box satu per satu 3–9 dtk, `pairs`, `flood`) dan `temp/probe_pit_flow_1x.gd` (world penuh: sim + choreographer + crew, `time_scale` 1.0).

### 1a. "Stuck sebelum crew bekerja"

World 1x: `parked->job = 0.00 s` di semua stop — begitu mobil parkir di marka, crew langsung bekerja. Jeda yang terlihat berasal dari tiga hal lain:

| Penyebab | Durasi | Status |
|---|---|---|
| Penalti steward stop-and-hold (+5 s dari kontak di lintasan): mobil diam di box, crew sengaja menunggu (`GtPit.penalty_hold_s`) | 5 s per penalti | sesuai regulasi, **tidak diubah** — lihat §5 |
| Double stack: mobil kedua menunggu rekan setim selesai servis **dan** tertahan rilis | 7–20 s | diperbaiki lewat 1b (tunggu rilis rekan turun drastis) |
| Pengereman normal dari 12 m ke marka (5 m/s²) | ~2,1 s | normal |

### 1b. "Stuck setelah pit" — akar masalah

Sebelum fix, mobil yang sudah selesai servis menunggu lollipop merah rata-rata 4,7–6,3 s per stop dan sampai 12–16,5 s (stagger), 18,9 s di tes; mobil yang keluar juga berhenti di tengah jalan 5–10 s. Penyebab, diurutkan dari pengaruh terbesar (akumulasi detik "blame" per rule):

1. **Jendela look-ahead rilis terlalu lebar.** `_pit_exit_blocked` menahan rilis untuk mobil di fast lane dalam 8 + (v+8)·3 s ≈ 74 m dan mobil menuju **box mana pun** di depan dalam 8 + (v+8)·5 s ≈ 118 m; `_pit_merge_unsafe` dalam 6 + v·2,5 s ≈ 61 m. Dengan arus mobil normal selalu ada satu mobil di jendela itu → mobil menunggu sampai timer cap 12/20 s habis.
2. **Bug pitch 20 m:** rule "mobil di depan dalam 20 m" ikut menghitung mobil yang **parkir** di box sebelah (tepat 20,0 m). Perbandingan `-behind < 20.0` dengan floating point → kadang tertahan, kadang tidak (inilah "terkadang"). Rule ini ditulis saat pitch masih 14 m.
3. **Deadlock saling-tahan saat merge.** Mobil keluar box berhenti di tengah pull-out (merge-wait) tepat di belakang box tetangga; mobil tetangga yang selesai servis tidak boleh rilis karena ada mobil "di belakang" → keduanya menunggu sampai cap.
4. **Gridlock double stack.** Mobil kedua antre 8 m di belakang box-nya = di jalur pull-out box sebelumnya; mobil yang keluar terhalang di stall lane, antrean fast lane di belakangnya ikut berhenti. Setelah itu ditemukan juga **osilasi** pada bypass-nya (lihat §2).

## 2. Perbaikan (`scripts/gt/gt_driving.gd`)

- `_pit_exit_blocked` + `_pit_merge_unsafe` → satu `_pit_release_conflict` berbasis *gap acceptance*:
  - mobil di belakang yang jalurnya melewati box ini (di fast lane, atau menuju box sesudahnya) menahan rilis hanya bila lebih dekat dari jarak yang ia tutup saat mengerem nyaman (5 m/s²) sementara mobil yang dirilis berakselerasi dari diam (6,8 m/s²): `v² / (2·(PIT_COMFORT_DECEL + ACCEL))` + panjang mobil + gap;
  - mobil yang akan masuk box dalam `PIT_CROSSING_M` (21 m: pull-out 16 m + panjang mobil, swing-in 18 m) jalan duluan selama dalam 3 s perjalanan (dulu 5 s, semua box);
  - mobil di depan hanya menahan bila masih bergerak pelan (< 8 m/s) dalam 21 m — mobil parkir tidak pernah menahan;
  - mobil yang menuju box sebelum/sama dengan box ini tidak dihitung (ia berhenti dulu).
- **Merge-wait dihapus** (`GtPit.merge_wait_s`, `PIT_MERGE_WAIT_MAX_S`, `PIT_RELEASE_WAIT_MAX_S` dihapus): rilis di box adalah satu-satunya gerbang. Penggantinya, yield **lateral saja**: selama ada mobil sejajar di fast lane (yang sejajar/di depan atau lebih cepat) mobil yang keluar tetap selebar satu lane darinya tapi terus menggelinding.
- **Bypass mobil antre:** mobil diam/merayap (< 8 m/s) di jalur pull-out dalam 21 m dilewati lewat fast lane (swing langsung). Keputusan diukur terhadap lateral jalur, bukan lateral mobil sendiri — versi pertama berosilasi 12,97 ↔ 13,26 m dan macet 8 s (terlihat di trace `temp/pstuck7_apex.log`).
- `PIT_RELEASE_HARD_CAP_S` (20 s) tetap sebagai failsafe.

## 3. Hasil

### 3a. Waktu tunggu rilis per stop (probe, kode lama → baru)

| Skenario | Kode lama: rata-rata / maks | Kode baru: rata-rata / maks |
|---|---|---|
| stagger/grid, 5 sirkuit | 4,65–6,34 s / 12,0–16,6 s | 0,35–1,00 s / 1,9–6,4 s |
| pairs (4 tim double stack) | 0,78–3,50 s / 5,0–11,4 s | 0,00–0,28 s / 0,0–1,8 s |
| flood (20 mobil sekaligus) | Apex 4,98 s / 13,8 s | 0,48–1,12 s / 6,3–7,6 s |

Mobil yang keluar box berhenti paling lama 0,1–0,3 s (dulu sampai 6,6 s, plus merayap 1,2 m/s sampai 12 s).

### 3b. Tes banjir pit (`tests/pit_flood_checks.gd`, 5 sirkuit)

- Lane kosong setelah 20 mobil box bersamaan: **51–58 s** (dulu 84–86 s).
- Tumpang tindih > 1 m: 0–7 car-pair tick (batas 20; dulu 0–17).
- Skenario baru "raced field, cars box 3-9 s apart": rata-rata tunggu rilis 0,37–0,99 s (gerbang ≤ 1,5 s), maks 2,0–6,4 s (gerbang ≤ 7 s), mobil keluar berhenti ≤ 0,1 s (gerbang ≤ 4 s). Di kode lama gagal: 18,9 s / 16,2 s tunggu rilis, 10,3 s / 5,7 s berhenti saat keluar (Apex/Brianza).

### 3c. Tes yang diubah

- `tests/pit_flood_checks.gd`: skenario `_staggered_scenario` + gerbang rilis (regression test; dilihat gagal di kode lama sebelum fix).
- `tests/test_pit_stop_in_world.gd`: fixture Monte Azure "six cars" → enam mobil berurutan di grid. Pilihan lama (tiap mobil ketiga) tidak lagi memaksa hold karena hold sekarang hanya terjadi bila memang ada mobil di jalur; tes tetap memverifikasi animasi HOLD (16 frame tertahan).

### 3d. Verifikasi

- Suite penuh `tools/run_tests.ps1`: **85/85 lulus, 0 gagal** (1929 s). Run pertama dengan kode antara gagal di `test_pit_queue_flow` (25 tick tumpang tindih saat hujan) dan `test_pit_stop_in_world` (fixture Monte); keduanya diperbaiki lalu suite diulang penuh.
- Smoke native `scratch/smoke_pit_race.gd` (1920×1080, 3 lap, 20 mobil, 6 mobil box bersamaan, frame diukur di 1x):
  - Monte Azure: 20/20 finis, 6 stop, frame rata-rata 16,66 ms (p95 17,35, terburuk 30,10), podium OK, 0 orphan.
  - Apex Ring: 20/20 finis, 6 stop, frame rata-rata 16,66 ms (p95 17,72, terburuk 28,95), podium OK, 0 orphan.
  - Brianza, Neo-Wangan dan Ardennes tidak diuji smoke native; ketiganya hanya tercakup tes headless.

## 4. Gotcha

- Probe dengan `order.shuffle()` memakai RNG global → tidak deterministik; untuk mereproduksi urutan tes pakai skenario `grid` dan jumlah lap 12 (jumlah lap mengubah aliran RNG race).
- Lateral pit car bergerak tanpa bergantung kecepatan (`_steer_laterally`), jadi aturan yang memutuskan lateral dari lateral mobil itu sendiri bisa berosilasi.
- `run_tests.ps1` menulis log per suite ke `%TEMP%\suite_<nama>.log`, bukan ke stdout.

## 5. Iterasi 2 — playtest developer: "crew tidak langsung bekerja, kadang ada jeda setelah servis"

Ukur ulang di world 1x, 20 mobil box bersamaan (Monte Azure, `temp/probe_world_pit_timing.gd`):

| Jeda | Terjadi | Durasi | Penyebab |
|---|---|---|---|
| mobil sudah < 2 m dari marka, crew belum bergerak | 20/20 stop | 0,75–0,80 s | crew baru melangkah saat sim mencatat parkir (≤ 5 cm, < 0,8 m/s) |
| mobil diam di box, crew diam | 2/20 | 5,1 s | penalti steward stop-and-hold, tanpa tanda visual |
| servis selesai, papan merah | 13/20 | 0,05–8,8 s | mobil di fast lane terlalu dekat (keselamatan vs waktu) |

Keputusan developer: penalti tetap hold + tanda, release lebih agresif, crew antisipasi.

- **Crew antisipasi** (`race_weekend_world._update_pit_crews` → `PitstopChoreographer.set_arriving_teams`): mobil fase BOX dalam `CREW_STEP_IN_M` 2,5 m dari marka, tanpa penalti → crew melangkah ke titik kerja selagi mobil merayap masuk. Hasil 1x: crew sudah di samping mobil (`work_blend` 1,00) tepat saat mobil berhenti, di 18/18 stop tanpa penalti. Timer servis sim tidak berubah. Yang titik kerjanya berada di jalur mobil masuk (jack belakang, 0/0/+3,1 m; `PitstopChoreographer._in_arrival_path`, lebar 1,45 m) baru melangkah setelah mobil berhenti — versi pertama membuat `test_pit_lane` #C4 gagal (jarak 0,00 m), kini 0,52 m.
- **Penalti terlihat**: job dibuka saat parkir dengan `hands_off` (fase HOLD, lollipop merah, crew tetap di titik tunggu); tower timing menampilkan `PEN 4.2` merah; tombol deck `PENALTY HOLD 4.2 s // CREW HANDS OFF`; radio engineer saat hold dimulai (`standings_entries` mendapat `penalty_hold_s`). Bug yang ditemukan saat implementasi: satu tick antara akhir hold dan mulai servis menutup lalu membuka ulang job (mobil tercatat dua kali selesai) — `in_box` kini memakai `penalty_taken`.
- **Release lebih agresif**: jarak tutup dihitung dengan `PIT_BRAKE_MAX` (9 m/s², sama seperti pengereman ke marka) alih-alih 5 m/s². Efeknya kecil (rata-rata tunggu 0,37–0,68 s, maks 2,0–6,4 s): sisa hold kini terutama dari mobil yang akan masuk box sebelah dan mobil lambat di depan.
- Tes: `test_pit_stop_in_world` mendapat cek "crew sudah melangkah ke mobil saat ia berhenti" (≥ 0,9; dilihat gagal 28× dengan antisipasi dimatikan) dan "penalti = papan merah, crew mundur" (75 frame per penalti, 0 salah).

## 5b. Polish — Brianza: race control tower menghalangi pit lane

- Gejala (playtest developer): gedung control tower Brianza berdiri di atas pit lane setelah pit building.
- Diukur (`temp/probe_brianza_tower.gd`): sisi depan tower di lateral 9,8–12,8 m, s 20–37; lane di sana 9,3–13,9 m. Penyebab: tower diletakkan dengan offset garis lurus 116 m dari tengah pit building (s 5700), padahal lurusan berbelok — tower meleset ke lane dan miring ±10° terhadap trek.
- Perbaikan (`brianza_pit_complex.gd`): tower didudukkan di ribbon seperti Ardennes, `TOWER_S` 30 m, `TOWER_CENTRE_LATERAL_M` 24 m. Sisi depan kini 16,1 m (2,2 m di luar lane), sejajar trek, 11 m dari ujung pit building.
- Tes: `test_brianza_paddock` mendapat cek "tower bebas dari pit lane" (setiap titik aspal lane, di frame tower, ≥ 1 m dari strukturnya); dilihat gagal sebelum perbaikan (145 titik di dalam tower), lulus setelahnya. `run_tests.ps1 -Filter brianza`: 5/5 suite lulus.

## 6. Perlu didiskusikan

1. ~~Penalti tanpa tanda visual~~ — selesai di §5.
2. **Matriks performa pit crew** (belum ada; semua `PIT_STOP_TIME` 3,2 s). Usul skema per tim: `stop_time_s` dasar, varian per stop (deterministik dari `race_seed`), peluang wheel-gun error (+1–3 s), kecepatan reaksi lollipop. Sim memakai `pit.duration`; choreographer sudah mengikuti `wheel_swap_progress`, jadi animasi ikut otomatis.
