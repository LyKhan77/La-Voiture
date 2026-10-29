# FASE 13.4 — Profiling Performa (gate 60 FPS locked)

**Status: gate 60 FPS locked PASS di Apex Ring, Neo-Wangan, dan Brianza.** Gate draw call environment Brianza tetap terbuka (lihat akhir). Mesin ukur: i5-12450H, RTX 3050 Laptop (Vulkan, Forward+), 1920×1080 High, layar 144 Hz.

## Metode

Tiga profiler native baru di `scratch/` (semuanya memakai race tiga lap 20 mobil, seed `19220903`, cuaca cerah, siang):

- `profile_frame_budget.gd -- <sirkuit> <detik> <capped|uncapped|vsync> [varian]`: mencatat tiap frame (waktu dinding, script, fisika, CPU dan GPU render viewport, draw call, jumlah tick sim) ke CSV `temp/perf/`, dan melaporkan persentil, jarak antar frame lambat, serta rata-rata frame dengan dan tanpa tick. Varian eksperimen: `step_in_process`, `phys120`, `hud_off`, `cars_off`, `shadows_off`, `radio_off`, `pits`.
- `profile_world_step.gd`: menjalankan bagian-bagian `RaceWeekendWorld.step()` dan `GtRace.step()` satu per satu dengan timer mikrodetik, juga handler radio HUD dan `present()` per mobil; mencetak langkah lambat beserta bagian penyebabnya.
- `profile_sim_step.gd` (headless), `profile_frame_buckets.gd`, `profile_limiter.gd` (pembatas FPS pada scene kosong), `profile_ablation.gd`.

Protokol: GPU laptop mudah terkena throttle termal (87 °C, clock 1400 dari 2100 MHz) dan proses lain (instance Godot lain, editor) memakai GPU; keduanya membuat GPU render time yang sama melonjak dari 4 ms ke 9–12 ms. Semua angka di bawah diambil setelah tidak ada proses Godot lain, dan hasil di bawah 4,5 ms GPU dianggap bersih.

## Temuan

1. **Kemampuan nyata jauh di atas anggaran.** Tanpa batas FPS: rata-rata frame 6,8–8,4 ms (±120–145 FPS), p95 12,4–15,7 ms, GPU render 4 ms, CPU render 1,4 ms, hanya 0,1–0,6% frame di atas 20,8 ms. Pembatas `run/max_fps=60` sendiri akurat (scene kosong: p95 16,76–16,90 ms). Jadi p95 21–25 ms yang dilaporkan sejak Fase 12 bukan beban render.
2. **Penyebab p95 22 ms: `world.step()` di `_physics_process`.** Dengan batas 60 FPS, 18–22% frame lambat (±21 ms) muncul setiap 3 atau 6 frame (cocok dengan sim 20 Hz). `world.step()` menggerakkan 20 aktor, kamera, HUD, dan VFX dari `_physics_process` 60 Hz tetap; berdampingan dengan render yang dibatasi 60 FPS, sebagian frame render menjalankan dua langkah dan sebagian tidak sama sekali. Varian pada Brianza (capped 60): base 22,0% frame lambat / p95 22,9 ms; `world.step` dari `_process` 2,5% / 19,6 ms; fisika 120 Hz 14,9% / 24,4 ms; HUD mati 7,7% / 21,2 ms; mobil disembunyikan 11,4% / 22,2 ms; bayangan mati 19,7% / 22,6 ms.
3. **Dua hitch satu kali di awal balapan.** Pesan radio pertama ("Deploying ERS boost!", t≈1,2 s) memakan 13–48 ms di handler HUD, terurai: pembuatan cache tema font label SFX (`add_theme_color_override`) 11 ms, pembentukan glyph pertama, dan pemuatan manifest radio 5 ms. Lalu satu mobil memakan 9–13 ms di `_animate_wheels` pada pengereman pertama: pembuatan dan penggambaran pertama overlay glow rotor (`StandardMaterial3D` add blend).
4. Sim tick bukan penyebab: `GtRace.step()` rata-rata 1,9 ms (p95 2,9 ms), `world.step()` total ±3,5 ms.

## Perbaikan

- `scripts/world/race_weekend_world.gd`: `_physics_process` menjadi `_process`; `set_physics_process(false)` pada selebrasi menjadi `set_process(false)`. Sim tetap berjalan 20 Hz dari akumulator `_run_ticks`. `tests/test_world_frame_driver.gd` (gagal sebelum perubahan). Tes lain yang menghentikan world lewat `set_physics_process(false)` disesuaikan (`test_visual_polish_and_consistency.gd`).
- `scripts/ui/anime_radio_cutin.gd`: `prewarm()` membentuk glyph, tema, dan layout kartu dengan alfabet penuh selagi tersembunyi dan digambar di luar layar selama 2 frame, lalu mengembalikannya; panggilan radio asli yang masuk lebih dulu tidak diganggu. Dipanggil dari `RaceHud` bersama `RadioVoice.entries()`. `tests/test_radio_cutin_prewarm.gd` (gagal sebelum perubahan); `test_visual_polish_and_consistency.gd` menunggu prewarm selesai sebelum menguji gambar ulang banner.
- `scripts/car/gt_car_actor.gd`: pada 6 frame pertama di grid setiap rotor membawa overlay glow pada kekuatan 0,02 (tak terlihat) sehingga biaya pembuatannya dibayar di sana; rotor dingin kembali tanpa overlay. `tests/test_wheel_glow_warmup.gd` (gagal sebelum perubahan).

## Hasil (batas 60 FPS, konfigurasi sebenarnya)

| Sirkuit | p95 sebelum | p95 sesudah | Frame > 20,8 ms sebelum | sesudah |
| :--- | :--- | :--- | :--- | :--- |
| Brianza | 22,3–22,9 ms | 16,79–17,06 ms | 18–22% | 0,1–0,8% |
| Apex Ring | belum diukur | 16,77–16,83 ms | belum diukur | 0,1–0,3% |
| Neo-Wangan | belum diukur | 16,84–16,86 ms | belum diukur | 0,2–0,3% |

Dengan enam mobil dipanggil ke box bersamaan (`profile_frame_budget ... capped pits`): Brianza p95 16,82 ms (0,1%), Apex 16,76 ms (0,0%), Wangan 17,08 ms (1,0%). Smoke native `smoke_pit_race.gd` (3 lap, 6 pit stop): 20 mobil finis, podium, 0 orphan di ketiganya.

Sisa frame lambat (0,1–0,8%) naik-turun antar-run dan tidak berasal dari satu subsistem (kartu radio dimatikan: 14 dan 9 frame, dinyalakan: 5 dan 15 dari 2401). Satu lonjakan 99 ms pernah terlihat pada detik 2,8 satu run Brianza dan tidak muncul pada run lain. `hud.update` sesekali 3–5 ms.

Catatan ukur: p95 `smoke_pit_race.gd` (17,9–19,9 ms) lebih tinggi dari profiler karena skrip itu bergantian menyembunyikan environment untuk menghitung draw call; frame sesudah tiap sampel kini dikecualikan (8 frame), tetapi profiler khusus tetap acuan p95.

## Regresi

Seluruh `tests/test_*.gd` headless lulus (64 suite: 61 sebelumnya ditambah `test_world_frame_driver`, `test_radio_cutin_prewarm`, `test_wheel_glow_warmup`), termasuk `test_race_world` dengan `--fixed-fps 60`.

## Gate terbuka

- ~~Draw call environment Brianza: sampel 171–191~~ — ditutup di Fase 14.1: angka itu berasal dari kamera race yang berubah-ubah, bukan ukuran tetap (lihat bagian di bawah).

## Gate draw call environment (Fase 14.1)

`scratch/measure_env_draw_calls.gd -- <sirkuit> [langkah_m]` menaruh kamera tiap 150 m di sepanjang lap, membaca `RENDER_TOTAL_DRAW_CALLS_IN_FRAME` dengan environment tampil dan tersembunyi (selisihnya = bagian environment, termasuk shadow pass), dan lulus bila view terburuk ≤ 180 (exit code 1 bila lewat). Hasil (bayangan matahari menyala, 1080p High):

| Sirkuit | Mean | p95 | Max | Sebelum |
|---|---|---|---|---|
| Apex Ring | 55 | 65 | 67 | 125 / 267 / 270 |
| Neo-Wangan | 92 | 138 | 155 | tidak berubah |
| Brianza | 75 | 97 | 100 | tidak berubah |

- Apex terberat karena 3 MultiMesh pohon (±1.100 pohon) berbatas seluruh sirkuit: satu jenis pohon saja menambah ±190 call, tak peduli jumlah instance, dan `cast_shadow` off pada pohon memangkas ±209 di view terburuk. `FoliageScatter` sekarang tidak melempar bayangan (pohon ≥ 18 m dari aspal, jadi bayangannya jarang jatuh ke trek).
- Dicoba dan dibatalkan: memecah pohon jadi chunk MultiMesh 100 m. View terburuk turun ±160, tetapi mean Apex naik 125 → 187 dan max 270 → 349.
- Mekanisme pasti kenapa satu batch sebesar itu mahal belum dipahami; hitungan statis `env.stats()` dan estimasi `test_track_environment` (satu call per surface) tidak melihatnya, jadi gate sebenarnya adalah skrip ukur native ini.
- Mean 59,7–60,0 FPS karena batas 60 FPS; layar 144 Hz tidak dipakai untuk lock vsync (vsync di mode jendela tidak mengunci ke 60).
- Kebisingan sistem (throttle termal GPU, aplikasi lain) masih mengubah hasil per-run beberapa persen; ulangi pengukuran bila angkanya menyimpang.
