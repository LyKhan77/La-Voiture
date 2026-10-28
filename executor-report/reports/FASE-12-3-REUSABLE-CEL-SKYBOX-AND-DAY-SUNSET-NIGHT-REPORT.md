# FASE 12.3 — Shared Reusable Cel-Skybox & Multi-Time-of-Day (`DAY / SUNSET / NIGHT`)

**Tanggal:** 28 Oktober 2026 · **Branch:** `fase-12-3-reusable-cel-skybox` · **Engine:** Godot 4.7.2 stable

## 1. Hasil

| Item | Status |
| :--- | :--- |
| `SharedCelSkyController` (`scripts/world/shared_cel_sky_controller.gd`) | Selesai |
| Uniform shader `star_opacity`, `roof_neon_energy`, `band_emission`, `crest_emission` | Selesai |
| `NeoWanganEnvironment.apply_time_of_day(tod, gloom)` | Selesai |
| `TrackEnvironmentBuilder` (Apex Ring) memasang `SharedCelSkyController` (`include_stars = false`) | Selesai |
| `tests/test_reusable_sky_and_time_of_day.gd` (18 assertion, 0 gagal) | Selesai |
| Seluruh test suite headless `tests/test_*.gd` (51 file) | **Parsial pasca-fix**: 51/51 sebelum fix `WorldEnvironment`; setelah fix baru 33/51 dijalankan ulang (lihat §4) |
| 4 screenshot native 1920×1080 | Selesai |
| Smoke native 3 lap 20 mobil + gate 60 FPS | **Belum dijalankan** |

## 2. Perubahan

- **`SharedCelSkyController`** membangun `SkyAmbienceRoot` (`AnimeMoon`, `NightStars`, `AnimeNightClouds`) dan menyediakan `apply_wind(delta, wind_kph)` serta `apply_time_of_day(tod, gloom)`. `mode_of(tod)` memetakan `mode` 0/1/2; mode lain (`TWILIGHT_TRANSITION`) diklasifikasi dari `floodlights`.
- **`NeoWanganEnvironment`** mendelegasikan langit ke controller. `apply_time_of_day` mengatur palet `Skyline`, `Water`, `StreetlightHeads`/`StreetlightPools` (mati saat `DAY` cerah, menyala saat `SUNSET`/`NIGHT` atau `gloom > 0.55`), serta langit, fog, dan matahari `WorldEnvironment`. `TunnelNeon` tetap menyala. Dipanggil tiap frame dari `update(delta, race)`.
- **`TrackEnvironmentBuilder`** memperbarui controller dari `update(delta, race)`.
- **`RaceWeekendWorld`** membuang `WorldEnvironment` bawaan scene sirkuit saat mengadopsinya (lihat Ruling 1).

## 3. Rulings

1. **`WorldEnvironment` ganda di dunia balap Neo-Wangan.** `neo_wangan_circuit.tscn` membawa `WorldEnvironment` malam sendiri; `RaceWeekendWorld` memindahkan node sirkuit ke indeks awal tree, sehingga yang malam menang dan langit DAY/SUNSET tidak pernah tampil (ditemukan lewat screenshot pertama, dikonfirmasi probe). Solusi: world men-`queue_free()` `WorldEnvironment` sirkuit saat adopsi. Regression test ditulis dan **dilihat gagal** tanpa fix (`got 2`, sky top `(0.02, 0.04, 0.09)`), lalu lulus dengan fix. Biaya jika salah: pemakaian standalone scene sirkuit tidak terpengaruh; hanya dunia balap yang kehilangan `WorldEnvironment` sirkuit.
2. **Environment di-duplikasi sekali, bukan tiap frame.** Rencana menyiratkan membuat ulang sky/environment di `_apply_sky_for_tod`; karena dipanggil tiap frame, objek di-cache (`_runtime_environment`, `_sky_material`) dan hanya nilainya yang diubah.
3. **`mode` 0/1/2 dipercaya langsung** (`mode_of`), tidak diuji ulang terhadap `floodlights`; kode rencana akan menjatuhkan `TWILIGHT_TRANSITION` ke cabang malam.
4. **Jumlah suite:** dokumen menyebut 51; jumlah `tests/test_*.gd` memang 51 (termasuk suite baru).

## 4. Verifikasi

- RED: `test_reusable_sky_and_time_of_day.gd` gagal sebelum implementasi (skrip controller + `apply_time_of_day` tidak ada); gagal 2 assertion tanpa fix `WorldEnvironment`.
- GREEN: `test_reusable_sky_and_time_of_day.gd` 18 assertion, 0 gagal. `test_neo_wangan_cel_ambience.gd` 12/0, `test_track_environment.gd` 40/0.
- Full suite pertama (sebelum fix `WorldEnvironment`): 51/51 exit 0, 0 FAIL.
- Full suite ulang setelah fix: **dihentikan sistem karena memori rendah** setelah 33 dari 51 suite (alfabetis, `test_aston_vantage_chassis` s.d. `test_race_setup_overhaul`), semuanya exit 0 / 0 FAIL (`temp/full_suite_12_3b.log`). **18 suite belum dijalankan ulang pasca-fix**, termasuk `test_race_world`, `test_race_weekend_and_physics`, `test_track_environment*`, `test_weather_*`. Satu-satunya perubahan sejak run penuh: `race_weekend_world.gd` (buang `WorldEnvironment` sirkuit) dan tambahan test di `test_reusable_sky_and_time_of_day.gd`.
- **Tindakan wajib sebelum merge:** jalankan 18 suite sisa (`test_race_weekend_and_physics` sampai `test_winning_cut_director`), idealnya satu per satu agar memori tidak habis.
- Screenshot di `executor-report/screenshots/phases/`: `phase-12-3-wangan-day-bridge.png`, `phase-12-3-wangan-sunset-skyline.png`, `phase-12-3-wangan-night-skyline.png`, `phase-12-3-apex-ring-cel-sky.png`. Draw call terlihat (cars+VFX tidak disembunyikan): 48 / 188 / 178 / 31.

## 5. Keterbatasan & hutang

- **`CorridorTower*`** (GLB gedung koridor) memakai material sendiri dan tetap berjendela neon saat `DAY`; hanya `Skyline` MultiMesh yang mengikuti palet siang (terlihat di screenshot siang, kanan). Di luar lingkup spec; kandidat Fase berikutnya.
- Langit `SUNSET` berupa gradien ungu datar dari `ProceduralSkyMaterial`, tanpa glow horizon.
- Cakram matahari `SUNSET` rendah dan bisa tertutup menara dari beberapa sudut.
- Gerbang 60 FPS dan smoke native 3 lap belum dijalankan (butuh sesi interaktif).
- Review akhir: self-review oleh penulis (tidak ada reviewer subagent), lebih lemah dari reviewer segar.
