# FASE 3 — Lintasan 3D Ribbon & Kinematic Car Actor

## Hasil

Enam instruksi Fase 3 diimplementasikan sebagai berkas baru. Berkas Fase 1 dan Fase 2 (`race_sim_engine.gd`, `car_state.gd`, `pit_wall_*`, `project.godot`, `ROADMAP.md`) tidak diubah.

- Ribbon: `scripts/car/track_ribbon.gd` (`Path3D`). Tiga lajur paralel, offset lateral 2,5 m: lajur 0 kiri arah gerak (inside untuk sirkuit berlawanan jarum jam), lajur 1 garis balap, lajur 2 kanan. `get_point_on_ribbon(distance, lane) -> Transform3D`, `get_point_at_offset(distance, lateral_m)` untuk lajur kontinu, `get_curvature_at(distance)` (1/m, + = tikungan kiri), `get_radius_at(distance)`. Tabel sampel 1 m, semua query O(1). Mesh jalan (aspal, garis tepi, garis lajur, garis start) dibangun saat `_ready`.
- Sirkuit: `scenes/race_world/track_circuit.tscn`, loop tertutup 4159 m, bounding box 1359×830 m, satu hairpin radius ~35 m, straight 1150 m, chicane. Dibuat oleh `tools/build_track_circuit.gd` (turtle path; dua straight dipecahkan otomatis agar loop menutup, galat penutupan 0,00003 m).
- Aktor: `scenes/race_world/car_actor.tscn` + `scripts/car/kinematic_car_actor.gd`. Kotak 4,6 × 2,0 × 1,2 m, `AnimatableBody3D` (layer 2), tiga `RayCast3D`: depan 14 m (dari hidung), kiri 3 m, kanan 3 m. `sync_with_sim(state, sim_dt)` menaruh mobil di ribbon dari `CarState.spline_distance`.
- Radar: `scenes/pit_wall/circuit_radar_2d.tscn` + `scripts/ui/circuit_radar_2d.gd`. 300×200 px, `Line2D` dari garis balap ribbon, 20 titik diameter 8 px berwarna livery tim. Menerima `update_snapshot({"cars": [...]})` sama dengan komponen pit wall lain.
- Dunia uji: `scenes/test_race_world.tscn` + `scripts/car/test_race_world.gd`. 20 `car_actor.tscn`, kamera kejar (tombol 1–5 = 1×/2×/4×/8×/16×, panah = ganti mobil), radar di pojok kanan atas.
- Tambahan: `scripts/car/traffic_race_sim.gd` (lihat di bawah), `scripts/car/team_liveries.gd` (10 warna placeholder, dipakai aktor dan radar), `tests/test_race_world.gd`.

## Dua penyimpangan dari spesifikasi

**1. Sim Fase 1 memperlakukan mobil sebagai titik.** Pengikut boleh terus mendekat 1 m/s pada jarak berapa pun. Terukur: pada lap 1, 14 mobil menumpuk di jarak 0,0 m dalam satu lajur. Run pertama pada dunia 3D: 11.077 dari 12.000 frame ada mobil saling tembus (terdalam 2,1 m). Lapisan 3D tidak dapat memperbaikinya.

`AGENTS.md` melarang mengedit berkas yang bukan buatan agen, jadi inti tidak disentuh. `scripts/car/traffic_race_sim.gd` adalah subclass `RaceSimEngine` yang menambah:
- pengikutan sadar-lajur: hanya mobil di lajur yang bentrok yang menghalangi, pengikut tidak mendekat lebih cepat dari yang bisa direm sampai `min_gap_m`;
- penahan pindah lajur: perpindahan yang mendekatkan mobil ke mobil lain di lajur bersama (terlalu dekat atau mendekat terlalu cepat) ditahan; menjauh selalu boleh;
- penahan kontak: badan mobil tidak pernah tumpang tindih; mobil ditahan di tempat (tidak pernah mundur) dan disamakan kecepatannya; dilewati pada tick yang melintasi garis lap agar lap tidak terhitung dua kali.

`PitWallSession` masih memakai engine asli.

**2. Pemilihan lajur ada di sim, bukan di aktor.** Versi pertama aktor memilih lajur sendiri dari hit raycast depan. Hasilnya ~22% frame tembus, karena dua mobil memilih lajur yang sama dan keputusan berbeda dengan rencana lajur sim; hasil juga bergantung frame rate. Sekarang:
- sim memutuskan lajur (tetap deterministik, SIM-02);
- aktor menghaluskan perpindahan dengan kurva S (smoothstep antar-lajur; durasi geser sama 0,7 s, kecepatan lateral awal/akhir nol, puncak 2,1 lajur/s);
- sensor depan menandai `is_overtaking` (ada mobil di depan dan kecepatan sendiri lebih tinggi);
- sensor samping hanya menahan geser jika mobil lain hampir menyentuh (jarak hit < 1,05 m). Pada test ini 0 kali terpicu; jaring pengaman saja.

## Pemetaan jarak sim → ribbon

Lap sim 5807 m, ribbon 4159 m. `spline_distance` dipetakan proporsional (`distance_scale = ribbon.length_m / sim_track_length_m`), sehingga garis start/finish tetap bertemu. Konsekuensi: jarak antar mobil di 3D menyusut 28%. Dunia uji menurunkan `min_gap_m` dan `contact_gap_m` dari panjang mobil 4,6 m dibagi skala itu.

## Bukti verifikasi

Godot 4.7.2 stable, `--headless --fixed-fps 60`, keluar 0: **65 PASS, 0 FAIL**.

Ribbon:
- panjang 4159 m, loop menutup, jarak membungkus per lap;
- lajur 0/2 tepat 2,5 m dari garis balap, tegak lurus arah gerak, kiri/kanan benar;
- integral kelengkungan 6,276 rad (satu putaran penuh kiri);
- radius tikungan tersempit 32,9 m, straight start dilaporkan lurus.

Per skala waktu (1×, 2×, 4×, 8×, 16×; masing-masing 18.000 tick sim = 300 s):
- 20 aktor, sensor 14/3/3 m;
- **0 frame** kotak mobil saling tumpang tindih (uji SAT 2D, termasuk 4 sampel antar-frame agar tidak tersembunyi di antara dua frame);
- 25 aksi menyalip (hysteresis satu panjang mobil);
- sensor depan mendeteksi mobil, menandai overtake;
- laju geser lajur ≤ 2,1 lajur/s;
- gerak dunia ≤ 66,2 m/s (tidak ada teleport);
- posisi akhir 20 mobil identik bit-per-bit dengan 1×.

Render GUI asli (RTX 3050, Forward+): [1920×1080](phase-3-world-1920.png) dan [1280×720](phase-3-world-1280.png). Tiga lajur, mobil berdampingan tanpa tembus, radar terlihat. Tanpa error/warning pada log test.

## Menjalankan

```powershell
$Godot = 'C:/Users/Lee/Downloads/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64.exe'
& $Godot --path . --import
& $Godot --path . res://scenes/test_race_world.tscn
& $Godot --headless --fixed-fps 60 --path . --script res://tests/test_race_world.gd   # ~3 menit
& $Godot --headless --path . --script res://tools/build_track_circuit.gd             # buat ulang sirkuit
```

`--fixed-fps 60` wajib untuk test: tanpa itu jumlah tick per frame tidak pas dan perbandingan posisi akhir antar-skala tidak berlaku.

## Belum dikerjakan / batas

- Task 3.3 roadmap ("di layar Pit Wall"): radar belum dipasang ke `pit_wall_dashboard` / `circuit_workspace.gd` (radar skematik lama masih dipakai). `ROADMAP.md` tidak dicentang.
- `PitWallSession` belum memakai `TrafficRaceSim`; mobil di dashboard pit wall masih bisa menumpuk di sim. Ganti engine atau gabungkan aturan ke inti setelah persetujuan.
- `traffic_race_sim.gd` menyalin satu literal dari `_step_car` dasar: jangkauan ikut 15 m (`FOLLOW_RANGE_M`). Ia juga menimpa metode privat `_update_traffic`, `_step_car`, `_update_lane`, `_step_tick`. Jika inti diubah, periksa ulang.
- Test hanya 300 s sim (sekitar 2,5 lap), bukan 50 lap.
- Sirkuit 3D tidak meniru segmen tikungan sim; keduanya independen, hanya dihubungkan lewat skala jarak.
