# FASE 15.1: pit lane Apex Ring, Brianza dan Neo-Wangan (pitch 20 m)

Lanjutan Fase 15 putaran kedua (Monte Azure). Branch `fase-15-1-pit-pitch-other-circuits`, dari `main` (33c8e68). Belum di-commit.

## 1. Pengukuran (tes merah lebih dulu)

Tes baru memakai `sim_layout()` tiap sirkuit dan metrik yang sama dengan `test_monte_azure_pit_flood.gd` (kereta 30 m, rapat 20 m, menyebar, lapangan yang dibalap; seed 31, dua lap): `tests/test_apex_pit_flood.gd`, `tests/test_brianza_pit_flood.gd`, `tests/test_neo_wangan_pit_flood.gd`. Pengukurnya satu, `tests/pit_flood_checks.gd` (bukan suite; runner hanya mengambil `test_*.gd`).

| Sirkuit (layout lama) | Tick tumpang tindih (kereta / rapat / menyebar / balap) | Lane kosong (kereta / rapat) | Lompat tertinggi (balap) | Diam terlama |
|---|---|---|---|---|
| Apex, 14 m | 0 / 17 / 0 / 0 | 95 / 93 dtk (batas 90) | 13,15 m | 15,5 dtk |
| Brianza, 14 m | 21 / 36 / 0 / 0 | 96 / 93 dtk | 0,05 m | 15,8 dtk |
| Neo-Wangan, 12 m | 21 / 21 / 21 / 0 | 92 / 91 dtk | 92,72 m | 33,8 dtk |

Angka mentah Apex di skenario balap adalah 57 tick, tetapi semuanya pasangan mobil yang sudah bertabrakan di peloton sebelum sempat masuk lane (lihat 3.2).

## 2. Akar masalah

1. **Pitch.** Sama dengan Monte: 12–14 m tidak memberi ruang bagi mobil antrean kotak berikutnya (satu mobil 4,5 m + jarak antrean), jadi antrean berdiri bumper ke bumper dengan mobil di kotak ini. Brianza dan Neo-Wangan merah di tes tumpang tindih; Apex merah di waktu lane dan lompatan.
2. **Jarak dari garis entry ke kotak pertama.** Mobil yang dipanggil terlambat tiba cepat dan hanya bisa mengerem 9 m/s² di lane (`PIT_BRAKE_MAX`). Kotak pertama di 25 m (Apex) dan 68 m (Neo-Wangan) membuatnya melewati kotaknya sejauh 13–145 m; `_service_car` lalu menarik mobil kembali ke kotak (lompat 13,15 dan 92,72 m). Di 200 m (Neo-Wangan) lompatan hilang di lima seed (31, 7, 13, 21, 99). Di Apex run-up 100 m juga menghilangkan lompatan, tetapi tidak muat di geometri (3.1). Brianza tidak terpengaruh: entry-nya di tepi keluaran Parabolica, jadi mobil sudah lambat.
3. **Bug sim bersama** (`GtDriving._pit_logic`): rekan satu tim yang berada satu lap di depan (s-nya satu lap lebih besar, 2.877 m di depan) dianggap "rekan di depan", sehingga mobil kedua tim itu memakai aturan antrean dan tidak pernah mengerem untuk kotaknya sendiri: melewati kotak 18 m pada 18 m/s, berdiri, lalu ditarik kembali (lompat 19,06 m di skenario menyebar Neo-Wangan). Sekarang rekan hanya dihitung bila `other.s - car.s <= pit_length() + 120`.

## 3. Perbaikan

### 3.1 Layout

| | Apex | Brianza | Neo-Wangan |
|---|---|---|---|
| Pitch | 14 m (**tetap**) | 14 → **20 m** | 12 → **20 m** |
| Kotak pertama setelah garis entry | 25 m (tetap) | 70 m (tetap) | 68 → **200 m** |
| Entry | s=3900 (tetap) | s=5530 (tetap) | 3015 → **2815** (335 m sebelum garis, di lurusan) |
| Lane (entry → exit) | 410 m (tetap) | 410 m (tetap) | 200 → **400 m** (merge tetap di s=145) |
| Kotak | s=3925..4051 (tetap) | 5600..5726 → **5600..5780** | 3083..3191 → **3015..3195** |
| Gedung pit | 140 m (tetap) | 148 → **200 m**, menara 85 → **116 m** | 124 → **204 m**, menara 76 → **116 m**, tribun 140 → **200 m** |
| Lebar garasi | 12,4 m (tetap) | 12,4 → **16,4 m** | 11,4 → **16,4 m** |

**Apex tidak diubah di 15.1 (kotak dipindah ke lurusan start di Fase 15.2).** Percobaan pertama memakai pitch 20 m dan kotak pertama di s=4000, dan hasil simulasinya bagus (lane kosong 83 dtk, lompatan 0,05 m). Suite penuh lalu menunjukkan lurusan pit Apex hanya sekitar 145 m (s≈3920–4065) dan setelah itu menikung 90° sampai penutup lap (s=4159): kotak 4000..4180 dan gedung 200 m jatuh ke tikungan. Tikungan itu tidak boleh diubah (titik kontrol `Curve3D` Apex butuh persetujuan), dan lurusan lain yang cukup panjang (s=0..700+) ditempati tribun utama dan menara kontrol. Atas keputusan pemilik proyek Apex kembali ke layout lama (14 m, kotak 3925..4051); hanya perbaikan sim bersama (bagian 2, butir 3) yang berlaku di sana. Memindahkan pit Apex ke lurusan start/finish adalah pekerjaan terpisah.

Batas Brianza: kotak terakhir di s=5780 karena penutup lap menikung mulai s≈5784 (radius 129 m di 5784). Karena itu kotak pertama tidak digeser dan pitch tidak lebih dari 20 m.

Ramp tidak diubah: di sapuan sim, `lane_ramp_in_m` dan `lane_ramp_out_m` tidak mengubah satu metrik pun.

### 3.2 Tes

`pit_flood_checks.gd` memakai batas Monte (diam 18 dtk, lane kosong 90 dtk, tumpang tindih 20 tick), dengan dua penyesuaian yang disengaja:

- **Peloton.** Dua mobil yang sama-sama masih di jalan ke kotak (fase ENTRY atau IN) dan sama-sama berjalan (>3 m/s) tidak dihitung bertabrakan di lane: mereka bertabrakan di peloton saat ber-brake ke limiter dan berayun ke tepi yang sama. Mobil yang berdiri dalam antrean atau di kotak tetap dihitung. Dilaporkan di keluaran (`left out N pack pair(s)`).
- **Diam terlama di lapangan yang dibalap**: batas `PIT_RELEASE_HARD_CAP_S` (20 dtk), bukan 18. Mobil kedua satu tim menunggu rekannya yang ditahan menunggu lajur cepat (aturan sim yang disengaja, tutup 12 dtk / 20 dtk). Skenario sintetis tetap 18 dtk.

Apex memakai batas sendiri (`flush_max_s` 100 dtk, `teleport_max_m` 14 m) karena layout 14 m tidak mencapai target Monte; itu pagar agar tidak memburuk, bukan target (alasan di komentar `test_apex_pit_flood.gd`).

Tes lama yang berubah karena angka layout: `test_brianza_circuit` (#B13 pitch), `test_brianza_pit_lane_v2` (rentang jalur lurus gedung sampai s=5782), `test_neo_wangan_circuit` (#W10, #W11, #W41, #W45, #W21), `test_shared_paddock_kit` (gedung Neo-Wangan 204 m dengan sepuluh kotak 20 m, tribun 200 m).

## 4. Hasil

Tiga tes flood baru hijau (seed 31). Filter `pit`: 16 dari 16 suite lulus (420 dtk), termasuk `test_pit_queue_flow` dan `test_monte_azure_pit_flood` (sim bersama berubah satu baris).

| Sirkuit | Tick tumpang tindih (kereta / rapat / menyebar / balap) | Lane kosong (kereta / rapat) | Lompat (balap) | Diam terlama (balap) |
|---|---|---|---|---|
| Apex, 14 m (tidak diubah) | 0 / 17 / 0 / 0 | 95 / 93 dtk | 13,15 m | 15,5 dtk |
| Brianza, 20 m | 0 / 17 / 10 / 3 | 86 / 84 dtk | 0,05 m | 14,8 dtk |
| Neo-Wangan, 20 m | 0 / 12 / 10 / 0 | 88 / 88 dtk | 0,05 m | 19,0 dtk |

Percobaan Apex 20 m (dibatalkan, tidak muat di lurusan), lima seed (31, 7, 13, 21, 99), skenario balap saja: diam terlama maksimum 24,6 → 19,3 dtk, lompat 13,15 → 0,05 m. Neo-Wangan dengan kotak pertama 200 m: lompat 0,05 m di kelima seed (140 m: 17–139 m di tiga seed). Tumpang tindih lepas-paksa (bagian 5) tetap 0–37 tick per seed di Brianza dan 0–12 di Apex.

**Suite penuh** (`tools/run_tests.ps1`, 78 suite):
- Putaran 1 (Apex masih 20 m): 75 lulus, 3 gagal karena angka layout yang disematkan tes: `test_shared_paddock_kit` (Neo-Wangan 124 m / 12 m / tribun 140 m), `test_track_environment` dan `test_track_environment_upgrade` (#H2, gedung pit Apex). #H2 ternyata bukan sekadar angka lama: ia menangkap bahwa gedung 200 m jatuh ke tikungan (3.1). Apex dikembalikan ke 14 m.
- Putaran 2 (sesudah itu, 1851 dtk): 77 lulus, 1 gagal: `test_pit_complex_contract` keluar dengan kode 1 tanpa satu pun `[FAIL]` (pass=38 fail=0). Dijalankan ulang sendiri dan lewat runner: lulus (17 dtk), dan di putaran 1 juga lulus. Penyebab belum terbukti; dugaan saya beban mesin (putaran 2 jauh lebih lambat dari putaran 1, 1851 vs 1176 dtk), tetapi itu dugaan.

**Belum dijalankan**: Tangkapan layar native layout baru (`scratch/capture_pit_hold.gd`) belum diambil.

## 5. Yang tersisa

- **Tabrakan EXIT/EXIT** (mobil yang baru dilepas dari kotak, merayap 3–5 m/s, ditabrak mobil yang dilepas dari kotak sebelumnya pada 19 m/s). Terjadi saat lepas dipaksa oleh tutup 12 dtk; mencapai 0–40 tick per seed di semua sirkuit termasuk Monte. Layout tidak mengubahnya: `_pit_exit_blocked` memakai jangkauan 8 m + v × `PIT_MERGE_LOOKAHEAD_S`, yang kurang dari waktu mobil yang dilepas keluar dari lajur kotak. Perbaikannya adalah aturan sim (jangkauan yang mengikuti waktu keluar), di luar tugas ini dan berisiko menambah waktu tunggu.
- **Apex belum selesai di 15.1.** Lane kosong 93–95 dtk (target 90) dan satu lompatan 13,15 m di skenario balap tetap ada. Layout hanya bisa membaik bila pit pindah ke lurusan yang cukup panjang (start/finish, s=0..700+; tribun utama di s=125 dan menara kontrol di s=195 perlu digeser, plus semua tes yang menyematkan angka pit Apex). Dikerjakan di Fase 15.2 ([`FASE-15-2-APEX-PIT-ON-START-STRAIGHT-REPORT.md`](FASE-15-2-APEX-PIT-ON-START-STRAIGHT-REPORT.md)).
