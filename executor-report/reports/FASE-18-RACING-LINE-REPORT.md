# FASE 18 — Racing line nyata, realisme AI, dan groove di semua sirkuit

Tanggal: 2026-11-01 · Branch: `fase-18-racing-line` (dari `main` 36fbf37) · Keluhan developer: "aspal lebih gelap di tengah lintasan, mobil selalu mengikuti garis itu, garisnya zig-zag sehingga gerak mobil tidak realistis; kenapa sirkuit Sprint rata?" · Keputusan developer: opsi B+C, pace ikut line dan dikalibrasi global 14 m/s², groove di semua sirkuit (street lebih tipis).

## 1. Diagnosa (diukur)

Satu fungsi, `AdaptiveRacingLine.target_offset`, menentukan tiga hal sekaligus: jalur AI (`GtTrack.ideal_lateral_at`), penalti grip dan drying line (`GtDriving.water_grip`), dan pita karet gelap (`enhanced_track_geometry.groove_mesh`). Isinya `clamp((0.4·κ(s) + 0.6·κ(s+25)) · 180, ±3.2)`:

- κ diambil dari selisih dua tangen centreline yang hanya berjarak 6 m. Getaran titik spline ikut terbaca, lalu dikali 180 tanpa penghalusan.
- Bentuknya salah: garis selalu di sisi dalam sepanjang tikungan. Pola outside → apex → outside tidak ada, dan lebar trek tidak terpakai (maks 3.2 m dari setengah lebar 5.5–7 m).
- Garis itu kosmetik: profil kecepatan memakai κ centreline, jadi garis tidak memberi keuntungan pace.
- Sirkuit Sprint (Neo-Wangan, Monte Azure) "rata" karena environment-nya tidak pernah memanggil `groove_mesh`. AI di sana tetap mengikuti garis zig-zag yang sama, hanya tidak terlihat.

Probe `temp/probe_racing_line.gd`. "Pembalikan" = garis berbalik arah dengan ayunan > 0.4 m:

| Sirkuit | Belokan | Pembalikan lama | Baru | Geser maks lama → baru (m/m) | Lebar terpakai lama → baru |
|---|---|---|---|---|---|
| Apex Ring | 9 | 47 | 22 | 0.61 → 0.32 | 3.2 → 4.30 m |
| Neo-Wangan | 12 | 50 | 28 | 0.75 → 0.29 | 3.2 → 4.05 m |
| Brianza | 11 | 155 | 33 | 1.06 → 0.28 | 3.2 → 5.30 m |
| Monte Azure | 19 | 119 | 34 | 0.73 → 0.29 | 3.2 → 3.80 m |
| Ardennes | 20 | 117 | 40 | 0.47 → 0.26 | 3.2 → 5.30 m |

Line baru berbalik sekitar 2–3 kali per tikungan (masuk lebar, apex, keluar lebar).

## 2. Perubahan

### B — racing line (`scripts/car/adaptive_racing_line.gd`, `scripts/gt/gt_track.gd`)
- `target_offset` sekarang membaca tabel line minimum-kelengkungan yang dihitung sekali saat load. Metodenya Gauss-Seidel over-relaxed dengan stencil biharmonik `(4(P[i-1]+P[i+1]) − (P[i-2]+P[i+2]))/6` di grid 32 → 16 → 8 → 4 m, di-clamp ke `±(road_half_width − 1.7 m)`. Versi pertama memakai titik tengah tetangga, yang ternyata meminimalkan *panjang*: line menempel di sisi dalam loop (35–91 % lap di tepi). Biharmonik membetulkannya.
- `line_curvature_at(s)`: kelengkungan line itu sendiri (chord ±6 m + box filter 7 tap).
- `GtTrack._build_profile` memakai kelengkungan line. `LATERAL_ACCEL` 19.5 → **14.0** m/s² (keputusan developer).
- API tetap (`ideal_lateral_at`, `curvature_at` centreline, envelope pengereman), jadi logic overtake/defend/flag/pit tidak diubah.
- Build per sirkuit 37–117 ms saat load (budget test 250 ms). Runtime lebih murah dari sebelumnya: satu lookup tabel.

### Steering (`GtDriving._steer_laterally`)
- Feed-forward: mobil mengikuti laju perubahan target lateralnya sendiri, dibatasi besar drift line (`|dline/ds|·v`). `max_steer` 3.8 m/s kini hanya membatasi gerak menjauh dari target. Tanpa feed-forward, mobil tidak bisa mengikuti line di chicane cepat. Versi pertama (selalu drift line) membuat 2 frame overlap di dense pack, karena target diam (defend, tepi trek) tetap ikut terdorong. Versi berbasis laju target memberi 0 overlap.
- Tracking satu mobil satu lap Apex: rata-rata 0.04 m dari line-nya, terburuk 0.42 m.

### C — realisme (`scripts/gt/gt_driving.gd`)
- **Line per driver**: `driver_wander` ±0.30–0.45 m (makin konsisten makin kecil), turn-in baru tiap 80 m. Fungsi murni dari (id, s), tidak menarik `race.rng`, sehingga determinisme `race_seed` tetap.
- **Rain line**: `rain_line_weight` = smoothstep(30–55 % air) × (1 − drying line/25 %). Di tikungan, AI bergeser 1.4 m ke luar dari karet. Mobil yang tetap di groove (±1.0 m) kehilangan 6 % grip tikungan × bobot.
- **Tow**: di lurusan, mobil yang mengikuti 4–25 m di belakang bergerak 80 % ke wake mobil depan (`_tuck_into_tow`), lalu logic attack menariknya keluar.
- **Groove semua sirkuit** (`enhanced_track_geometry.groove_instance`, menggantikan tiga salinan kode material): alpha dari kelengkungan *line* 60 m ke depan, jadi pekat di zona rem/apex dan tipis di lurusan. Neo-Wangan dan Monte Azure memakai skala `GROOVE_STREET_SCALE` 0.55 (alpha maks 0.23 vs 0.42).

### Pace — hasil kalibrasi (profil lap, detik)

| Sirkuit | Lama (centreline 19.5) | Baru (line 14.0) | Δ |
|---|---|---|---|
| Apex Ring | 81.55 | 79.3 | −2.8 % |
| Neo-Wangan | 81.45 | 81.5 | 0 % |
| Brianza | 113.74 | 94.8 | −17 % |
| Monte Azure | 70.78 | 58.7 | −17 % |
| Ardennes | 110.61 | 95.2 | −14 % |

Selisih besar di tiga sirkuit terakhir bukan akibat konstanta, melainkan kink satu sampel di centreline mereka. Contoh: seam Brianza di s=0 terbaca sebagai tikungan 93 km/h. Profil lama mengerem untuk tikungan palsu itu; racing line meluruskannya. Apex dan Neo-Wangan (tanpa kink) menjadi jangkar kalibrasi. Lap record `apex_ring: 79.6` tidak diubah.

## 3. Regresi pit yang terekspos (deterministik, bukan flakiness)

Posisi field yang baru memicu dua defect laten di logic pit. Keduanya diperbaiki di root:

1. **Box call terlambat** (Neo-Wangan, flood "everyone boxes together"): car 1 dipanggil 12 m sebelum Pit Entry pada 70 m/s, tetap di-commit, melewati box sejauh 54 m, lalu di-snap mundur (`teleport 54.38`). Fix: commit hanya bila `v ≤ √(PIT_SPEED² + 2·BRAKE·jarak) + 2`. Kalau tidak, mobil box lap berikutnya. Regression test `late box call` di `tests/test_pit_queue_flow.gd` **dilihat gagal** tanpa fix (commit 3 m setelah call) dan lulus dengan fix (commit 4053 m kemudian, servis 1, tanpa snap).
2. **Dua mobil commit bersebelahan** (Monte Azure, 33 tick overlap > 1 m): keduanya membanting ke `edge_lateral_m` dengan `max_steer` 26 m/s, sementara contact solver mengabaikan mobil pit. Fix `_pit_entry_abreast`: keduanya menahan lateral sampai bersih 1.5 panjang mobil, dan yang di belakang mengangkat gas ke 85 % kecepatan mobil depan. Hasil: 33 → 1 tick (di exit, batas 20).

3. **Mobil tertutup oleh mobil di lajur sebelah** (`test_track_incidents_and_stewards`, case steward kedua): `lead` di context adalah mobil terdekat di depan tanpa melihat lajur. Car 8 berada 3.7 m di depan di lajur lain, sehingga car 1 (tow 6 m di belakang car 14) tidak pernah membatasi kecepatan terhadap car 14. Saat car 14 mengerem, car 1 berakselerasi 44 → 45 m/s dan menabrak dari belakang (at-fault). Fix: context `lane_lead` (mobil terdekat di depan dalam koridor < 2.05 m) dan `_hold_corridor`: `v ≤ √(v_depan² + 2·BRAKE·ruang)`. Suite steward yang gagal menjadi bukti merahnya. Fixture sintetis yang saya coba tidak mereproduksi kegagalan (racing room dan contact solver menutupinya), jadi tidak disimpan.

## 4. Test

- Baru: `tests/test_racing_line.gd`, 47 assertion. Mencakup smoothness per belokan, geser ≤ 0.4 m/m, batas lebar dan pemakaian lebar, determinisme, outside–apex–outside (tikungan > 25°; kink diabaikan), line membuka tikungan (57–82 % κ centreline), kalibrasi pace, driver wander (tanpa rng), rain line + grip groove, tracking, tow, dan groove di semua set sirkuit. Kondisi merah kode lama terbukti lewat probe (§1: pembalikan 47–155 melewati cap 3×belokan, lebar 3.2 m < 90 % limit).
- Diubah karena mengunci semantik line lama: `test_race_weekend_and_physics` #2, `test_gt_sim` (±3.2 → ±line_limit), `test_track_environment` #S9 (proyeksi cross-section per vertex; tepi luar groove di apex kini > 6 m dari centreline).
- Fixture `test_pit_stop_in_world` "six cars" (Apex: tiap mobil kedua; Neo-Wangan, Brianza, Ardennes: nose-to-tail). Pola sama dengan Fase 17 di Monte Azure: pick tiap mobil ketiga tidak lagi memaksa hold. Test world ini **tidak deterministik antar run** (frame timing): Brianza 64/54/62 frame, Monte 3/2/4, Ardennes 1/0 pada fixture lama. Karena itu dipilih fixture dengan margin (10–62 frame).
- **Full suite dengan kode final: 86/86 PASS** (`tools/run_tests.ps1`, dijalankan per slice 0–9, 10–34, 35–52, 53–62, 63–72, 73–85 karena RAM). Run penuh pertama dibunuh sistem karena RAM habis setelah 62 suite. Run kedua menemukan kegagalan steward (§3.3); setelah fix, seluruh 86 suite diulang dari awal.
- **Native smoke test** (`scratch/smoke_race.gd`, 1920×1080, 3 lap 20 mobil, podium, lalu world dibebaskan), 5 sirkuit:

| Sirkuit | Mobil finish | Frame mean / p95 / terburuk (ms) | Draw call environment | Orphan |
|---|---|---|---|---|
| Apex Ring | 20 | 16.67 / 16.74 / 17.30 | 122–130 | 0 |
| Neo-Wangan | 20 | 16.67 / 16.74 / 17.73 | 127–147 | 0 |
| Brianza | 20 | 16.67 / 16.73 / 17.48 | 136–169 | 0 |
| Monte Azure | 20 | 16.67 / 16.72 / 16.98 | 52–140 | 0 |
| Ardennes | 20 | 16.67 / 16.75 / 17.52 | 129–150 | 0 |

  60 FPS terkunci di semua sirkuit, tanpa SCRIPT ERROR. Segitiga environment (0.6–1.8 juta) sudah di atas batas 350k AGENTS.md sebelum fase ini; groove hanya menambah 2 segitiga per 3 m.

## 5. Bukti visual

`executor-report/screenshots/phases/phase-18/` (skrip `scratch/capture_phase18_racing_line.gd`), dua tikungan paling tajam per sirkuit:
- `<sirkuit>-cornerN-plan.png`: tampak atas groove.
- `<sirkuit>-cornerN-worker.png`: posisi marshal di luar tikungan, menghadap apex.
- `<sirkuit>-cornerN-lines.png`: plot 2D. Merah = line lama (bergelombang), biru = racing line, abu = centreline.

## 6. Catatan / risiko

- Load sirkuit non-Apex menghitung line dua kali (environment + `GtTrack`), +37–117 ms masing-masing. Bisa di-cache per ribbon bila perlu.
- `track_map.gd` (layar race setup) kini ikut menghitung line lewat `GtTrack.new(ribbon)` hanya untuk DRS. Biayanya kecil dibanding instansiasi scene sirkuit yang sudah ada.
- Kink centreline Brianza/Monte Azure/Ardennes masih ada di geometri (road mesh, `curvature_at`). Line menutupinya, tapi κ centreline masih dipakai untuk corner weight/keausan di `GtDriving`.
- Monte Azure "six cars" hold hanya 2–4 frame (fixture Fase 17, tidak diubah): margin tipis.
