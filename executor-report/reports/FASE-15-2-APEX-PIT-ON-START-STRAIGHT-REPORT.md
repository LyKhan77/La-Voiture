# FASE 15.2: pit Apex Ring pindah ke lurusan start/finish (pitch 20 m)

Lanjutan Fase 15.1 ([`FASE-15-1-PIT-PITCH-OTHER-CIRCUITS-REPORT.md`](FASE-15-1-PIT-PITCH-OTHER-CIRCUITS-REPORT.md)), yang meninggalkan Apex di 14 m. Branch `fase-15-2-apex-pit-relocation`, dari `fase-15-1-pit-pitch-other-circuits` (0192200). Belum di-commit.

## 1. Masalah

Lurusan tempat kotak Apex berdiri (s≈3920–4065) hanya ±145 m, di antara dua tikungan 90° (s≈3790–3920 dan s≈4070–4158). Sepuluh kotak 20 m butuh 180 m, gedung 200 m, dan kotak pertama butuh run-up ±100 m setelah garis entry. Sisa Apex di layout 14 m: lane kosong 93–95 dtk (target 90) dan satu lompatan 13,15 m di skenario balap (mobil yang dipanggil terlambat melewati kotak pertama, 25 m setelah garis entry).

Lurusan start/finish (s=0..700+) cukup panjang. Pit lane Apex sudah membentang sampai s=150 setelah garis, jadi yang dipindah adalah kotak, garasi, gedung, dan menara; entry dan exit hanya bergeser.

## 2. Pengukuran (sapuan `entry_s`/`exit_s` dengan kotak pertama di s=4190, pitch 20 m, seed 31)

| entry / exit | Lane (m) | Lane kosong (kereta / rapat) | Tumpang tindih (kereta / rapat / menyebar) |
|---|---|---|---|
| 3900 / 330 | 589 | 91 / 90 dtk | 21 / 15 / 3 |
| 4000 / 330 | 489 | 87 / 89 dtk | 0 / 12 / 0 |
| **4000 / 300** | **459** | **85 / 86 dtk** | **0 / 12 / 0** |

Lane yang lebih panjang menambah waktu mobil di lane (80 km/jam), jadi entry digeser ke s=4000 (awal lurusan lama, di luar tikungan masuk) dan exit ke s=300.

Skenario balap, lima seed (31, 7, 13, 21, 99), layout terpilih: lompatan 0,05 m di kelimanya (sebelumnya 13,15 m di seed 31), tumpang tindih 3 / 15 / 0 / 0 / 11 tick (batas 20), diam terlama 12,9 / 14,0 / 20,2 / 9,2 / 15,9 dtk. Seed 13 melewati batas 20 dtk sebesar 0,2 dtk (kelas yang sama dengan tutup lepas 12/20 dtk di 15.1); tes memakai seed 31.

## 3. Perubahan

| | Sebelum | Sesudah |
|---|---|---|
| Entry (`ENTRY_S`) | 3900 | **4000** |
| Exit (`EXIT_S`) | 150 | **300** |
| Lane | 410 m | **458,75 m** (`NOMINAL_LENGTH_M`) |
| Kotak pertama (`STALL_FIRST_S`, tanpa wrap) | 3925 (25 m setelah entry) | **4190** (s=31,25 setelah garis; 190 m setelah entry) |
| Pitch | 14 m | **20 m** (kotak s=31..211) |
| Gedung pit | 140 m | **200 m** (mengikuti pitch; lebar garasi 12,4 → **16,4 m**) |
| Menara kontrol (`RaceControlTower.CENTRE_S`) | s=195 | **s=345** (45 m setelah exit, seperti semula) |

Tribun utama (s=125, sisi kiri) tidak berubah; kini ia berhadapan dengan gedung pit.

## 4. Tes

- **Baru: `tests/test_pit_straightness.gd`** (empat sirkuit). Deret sepuluh kotak harus berdiri di lurusan (perubahan arah ≤ 1,5° sepanjang deret). Ini tes yang seharusnya sudah ada di 15.1: layout Apex 20 m / s=4000 lolos tes flood tetapi gagal di sini (**90,6°**, dilihat merah sebelum layout final), sedangkan Brianza, Neo-Wangan, Monte dan Apex baru lolos (0,0°).
- `test_apex_pit_flood`: kembali ke batas Monte (lane kosong 90 dtk, lompatan 0,05 m); pagar longgar dari 15.1 dibuang dari `tests/pit_flood_checks.gd`. Hasil seed 31: tumpang tindih 0 / 12 / 0 / 3, lane kosong 85 / 86 dtk, lompatan 0,05 m, diam terlama 12,9 dtk.
- Angka Apex yang disematkan tes lama diperbarui: `test_track_environment` (#H2 gedung, #H4 menara, #T2 zona pohon), `test_shared_paddock_kit` (pitch 20 m), `test_pit_zone_contract` (zona kamera 518,75 m), `test_environment_shared_kit` (entry 4000).
- `test_race_weekend_and_physics` (#24) dan `test_safety_car_cinematic` (fixture entry/exit SC): diperbarui ke entry 4000 / exit 300, lihat bagian 6.
- `test_pit_deck_and_radio`: syarat "kembali ke kecepatan balap" setelah membatalkan panggilan pit (puncak > 45 m/s) kini puncak > 40 m/s. Mobil diuji 290 m sebelum entry, yang sekarang jatuh tepat di tikungan 90° (s 3790–3920) yang membatasi kecepatan sekitar 41 m/s; yang diuji adalah lepas dari batas 38 m/s pace pit. Ini pelonggaran tes, bukan perubahan perilaku sim.

## 5. Visual

Tangkapan native 1080p di `executor-report/screenshots/fase-15-2/`: pit-hold (`phase-14-5-pit-hold-apex_ring-*`) dan tiga panorama (`phase-15-2-apex-pit-*`). Gedung pit membentang di sepanjang lurusan start, sejajar dengan lane, berhadapan dengan tribun utama; gantri start tetap membentang di atas lintasan dan lane seperti sebelumnya (#H5 lulus).

## 6. Hasil regresi

Suite penuh (`tools/run_tests.ps1`, 79 suite, 1952 dtk) sesudah semua perubahan layout: 76 lulus, 3 gagal. Ketiganya gagal karena angka Apex lama yang tertanam di tes, bukan karena perilaku sim:

- `test_race_weekend_and_physics` (#24): `ENTRY_S == 3900`, `EXIT_S == 150`, lane 410 m. Kini 4000, 300, 458,75 m.
- `test_safety_car_cinematic` (17 dari 108 assertion gagal): fixture spline hitung tangan dan posisi SC terpaku ke entry 3900 dan exit 150. Semua posisi digeser +100 (sisi entry) dan +150 (sisi exit); nilai lateral (11,6 / 8,4 / 5,2 / 2,6 / 0) tidak berubah karena `fast_lane_m` dan `edge_lateral_m` tetap. Satu tes perlu lebih dari geseran: "antrean menyeberangi garis kontrol" (`_test_review_regressions`). Exit kini berakhir di s=370, jadi antrean 20 mobil berjarak 14 m tidak lagi sampai ke belakang garis; jarak antrean untuk tes itu dilebarkan ke 22 m (masih di bawah `SC_QUEUE_GAP_M` 46 m) lewat parameter `gap_m` pada `_place_queue` dan `_prepare_withdrawal`. Maksud tes tetap sama; skenarionya yang dipindah.
- `test_audio_and_race_weekend`: gagal hanya lewat #20, yang menjalankan suite pertama sebagai sub-tes.

Sesudah perbaikan, ketiganya dijalankan sendiri-sendiri lewat runner: `test_race_weekend_and_physics` lulus (191 dtk), `test_safety_car_cinematic` lulus (108 assertion, 0 gagal), `test_audio_and_race_weekend` lulus (287 dtk). Suite penuh lalu diulang utuh sesudah perbaikan itu: **79 dari 79 suite lulus, 0 gagal** (1377 dtk, `tools/run_tests.ps1`).

## 7. Yang tersisa

- Tabrakan EXIT/EXIT dari lepas paksa 12 dtk (aturan sim, semua sirkuit; Apex 0–15 tick per seed pada layout ini).
- Frame terburuk smoke native 50,6 ms (satu hitch dari 259 frame); belum diselidiki dan belum dibandingkan dengan Apex sebelum 15.2.

## 8. Smoke test native

`scratch/smoke_race.gd -- apex_ring` (1920x1080, RTX 3050 Laptop, DAY, seed 19220903): 3 lap, 20 mobil, **20/20 finis**, podium muncul, **0 orphan node** setelah dunia dibebaskan. Frame rata-rata 16,70 ms (59,9 FPS), p95 16,85 ms, terburuk 50,60 ms. Draw call environment 124–132 (batas 180).
