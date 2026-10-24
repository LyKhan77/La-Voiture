# LAPORAN EKSEKUTIF FASE 11 / LANGKAH 3D: RIBBON CUACA LADDER 8 LAP + WEATHER DECK

Spec: `docs/superpowers/specs/2026-10-24-langkah-3-hud-redesign-v2-design.md` (§4.3). Rencana: `docs/superpowers/plans/2026-10-24-langkah-3d-weather-ladder-plan.md`. Cabang `feat/langkah-3d-weather-ladder` (bertumpuk di `feat/langkah-3c-deck-n2`). Godot 4.7.2 stable, Windows.

## 1. Ringkasan

| Hasil | Detail |
|---|---|
| Data cuaca | `GtWeatherOutlook` (tanpa node): baris per lap (hujan, air, ban rekomendasi, state), ringkasan perubahan ban dan state pertama, lap BOX ideal (`max(1, k perubahan - 1)`), confidence `max(0.3, 1 - 0.085k)`, sebaran kerucut. Ban memakai ambang sim lewat `GtForecast.recommended_compound` (wet > 45 % air atau hujan > 0.55, inter > 18 %). Forecast habis atau kosong: nilai terakhir/cuaca langsung dipakai tanpa error; lap setelah bendera finis ditandai `past_finish` dan tidak pernah menjadi crossover atau BOX |
| Chip ribbon 350×56 | Ladder 8 kolom (lap sekarang + 7): batang hujan, huruf ban W/I/M, tag NOW dan BOX (kotak merah), kolom crossover berdenyut, kolom setelah finis redup, tabung wet dengan tick 18 % dan 45 %, baris `> DRIZZLE L+4  TRK 41°C` atau `> STABLE 10L`. Klik chip memancarkan `clicked`. Tampilan lama (gauge + 5 batang) tetap untuk dashboard pit wall lama |
| Weather Deck | Dropdown 560×264 di stage (1006,76): grafik air 11 titik dengan batang hujan, kerucut ketidakpastian, garis `WET > 45%` dan `INTER > 18%`, bracket `BOX WINDOW` berkedip, baris ban per lap, peta lintasan 3 sektor (dari `TrackRibbon`) dengan dry line, angka AIR/TRACK/HUMIDITY/WIND, kotak NEXT CHANGE (confidence dan crossover), tombol `SET TYRES  L+n > compound` |
| HUD | Klik chip atau `[W]` membuka/menutup deck; `ESC` menutup deck lebih dulu; menyembunyikan HUD (`H`) menutupnya; deck berada di `CanvasLayer` 31 di atas banner radio (layer 30). Tombol aksi memilih ban untuk BOX berikutnya (chip, roda, `pit_compound`) dan **tidak** memanggil BOX. Kartu BOX WINDOW deck 3c kini membaca `GtWeatherOutlook` yang sama |
| Reduce motion | Tidak ada hujan jatuh, denyut crossover, kedip bracket atau denyut kerucut; `_process` mati; tag dan warna tetap |

## 2. File yang berubah

| File | Perubahan |
|---|---|
| `scripts/gt/gt_weather_outlook.gd` (baru) | data murni; `leader_lap`, `state_of`, `ahead`, `summary`, `confidence`, `cone_spread` |
| `scripts/ui/weather_radar_widget.gd` | ladder, tabung, `clicked`, `update_outlook` (statis `format_*` dan `update_status` utuh) |
| `scripts/ui/weather_deck.gd`, `scripts/ui/weather_track_map.gd` (baru) | dropdown, grafik (kelas dalam `WeatherChart`), peta lintasan |
| `scripts/hud/race_hud.gd` | `weather_deck`, `weather_layer`, `toggle_weather_deck`, `[W]`, `ESC`, `_on_weather_tyres`, `leader_lap`, `weather_state` mendelegasikan |
| `scripts/hud/tactical_deck.gd` | `_update_window` dan `_upcoming` memakai lap pemimpin dan `GtWeatherOutlook` |
| `tests/test_weather_ladder.gd` (baru, 21 assertion), `tests/test_deck_n2.gd` | forecast jendela BOX diindeks lap pemimpin |
| `scratch/capture_langkah3d.gd` | tangkapan layar native |

## 3. Verifikasi

- **31 suite headless (30 + `test_weather_ladder`): semua OK** dengan pembungkus ketat (gagal bila exit ≠ 0, `[FAIL]`, atau `SCRIPT ERROR`).
- Tiap bagian dilihat gagal lebih dulu (parse error kelas/fungsi belum ada) sebelum diimplementasi.
- Bukti visual native 1920×1080 (dipotong ke ribbon dan deck) di `executor-report/screenshots/phases/`: `phase-11-langkah-3d-chip-dry.png`, `-deck-dry.png`, `-chip-rain-coming.png`, `-deck-rain-coming.png` (BOX WINDOW, kerucut, tombol SET TYRES), `-chip-last-laps.png` (kolom setelah finis redup), `-deck-team2.png`.

**Tidak dilakukan:** pengukuran frame time 60 FPS dan uji asap native 3 lap; denyut dan hujan animasi hanya dilihat sebagai gambar diam.

## 4. Temuan dan ruling

1. **Ambang ban = sim, bukan mockup.** Mockup dan spec memakai wet 35 % dan slick 10 %; sim memakai 45 % dan 18 % (`GtForecast`, `decide_strategy`). Tick tabung dan garis grafik mengikuti sim.
2. **Ladder k = 0..7**, kolom pertama NOW (lap sekarang, data langsung); grafik k = 0..10.
3. **Tombol aksi hanya memilih ban**, tidak memanggil BOX: label "SET TYRES L+n > compound", karena BOX segera menyalahi arti "lap L+n".
4. **Air per sektor di peta adalah heuristik tampilan** (`water + [0, 10, -8]`); sim tidak punya data air per sektor. Dry line memakai `drying_line_pct` sim (kekuatan = pct/65), bukan rumus mockup.
5. **Forecast diindeks lap pemimpin** (seperti sim); `TacticalDeck._upcoming` dan test 3c disesuaikan (sebelumnya lap mobil deck).
6. **Weather Deck di `CanvasLayer` sendiri (31).** Tangkapan layar pertama menunjukkan kartu radio engineer (layer 30) menutupi deck di dalam stage; test baru mengunci urutan layer. Transform layer mengikuti `stage` di `fit()`.
7. Tangkapan layar juga menemukan label yang terpotong (teks NEXT CHANGE, WIND) dan label ambang grafik yang salah posisi; diperbaiki.
8. Belum ditangani: label ambang grafik berada di atas batang hujan sehingga kurang terbaca; kartu BOX WINDOW 3c versi kecil tetap ada (spec menyebut 3d menggantinya dengan ladder penuh; chip ladder dan deck sudah menampilkan seluruhnya, kartu deck dipertahankan agar kotak deck tidak berubah).
