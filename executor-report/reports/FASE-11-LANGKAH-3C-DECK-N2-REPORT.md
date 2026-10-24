# LAPORAN EKSEKUTIF FASE 11 / LANGKAH 3C: TACTICAL DECK N2 "FADERS CONSOLE"

Spec: `docs/superpowers/specs/2026-10-24-langkah-3-hud-redesign-v2-design.md` (§4.4, §5, §6). Rencana: `docs/superpowers/plans/2026-10-24-langkah-3c-deck-n2-plan.md`. Cabang `feat/langkah-3c-deck-n2` (bertumpuk di `feat/langkah-3b-team-theme-telemetry`). Godot 4.7.2 stable, Windows.

## 1. Ringkasan

| Hasil | Detail |
|---|---|
| Tabel sim bersama | `GtTypes` memuat `PACE_SPEED_MULT`, `PACE_WEAR_MULT`, `PACE_FUEL_MULT`, `PACE_TARGET_TEMP`, `FUEL_MODE_BURN_MULT`, `ERS_DRAIN_PER_S`, `ERS_HARVEST_PER_S`, `TYRE_CLIFF_WEAR`; `gt_driving.gd` membaca tabel yang sama (perilaku identik, suite determinisme hijau) |
| Verdict dari sim | `GtForecast` (`wear_per_lap`, `burn_per_lap`, `tyre_life_at_finish`, `fuel_margin_laps`, `ers_seconds`, `recommended_compound`, `verdict`, `tyre_verdict`): OK / WATCH / DANGER dari umur ban di garis finis terhadap cliff 75 % keausan, sisa bensin dalam lap, detik deploy baterai, dan kecocokan ban dengan cuaca (ambang 45 % basah, 18 % inter, seperti `decide_strategy`). Pilihan tidak pernah dikunci |
| Widget | `SeverityMark` (centang, segitiga, silang digambar sebagai bentuk), `FaderLadder`, `ZonedGauge` (12 blok berzona, garis batas, ghost proyeksi finis), `ChipGrid`, `TyreWheel` (berputar sesuai kecepatan, hentakan 900 yang meluruh, goyang saat klik, cincin merah saat BOX aktif), `DeckTip`, `DeckCoach` (semua kalimat bahasa biasa dalam satu tabel), `AudioManager.click_pitched` |
| Deck | `TacticalDeck` ditata ulang di kotak 1888×140 yang sama: dua kartu mobil, tiga fader PACE/FUEL/ERS dengan gauge, angka besar, pill verdict dan legenda, roda ban + 6 chip, tombol BOX dua-state, kartu BOX WINDOW dari `race.weather.forecast`, header berisi baris prakiraan, COACH, MANUAL/AUTO, radio, FOLD |
| Umpan balik klik | Setiap kontrol: tekan 0.92→1 dalam 0.12 s, teks pop di atas kontrol, klik berpitch berbeda per aksi, roda dihentak untuk aksi ban dan BOX. Reduce motion meniadakan tekan, pop, dan hentak tetapi tidak suara |
| BOX | Klik kedua dalam 0.25 s diabaikan (debounce hanya di `on_box_pressed`; `press_box`, `cancel_box`, tombol B/ESC tidak). Roda `armed` mengikuti `pit_request` |

## 2. File yang berubah

| File | Perubahan |
|---|---|
| `scripts/gt/gt_types.gd`, `scripts/gt/gt_driving.gd` | tabel pengali dipusatkan (perilaku sama) |
| `scripts/gt/gt_forecast.gd` (baru) | verdict dan rumus prakiraan |
| `scripts/hud/severity_mark.gd`, `fader_ladder.gd`, `zoned_gauge.gd`, `chip_grid.gd`, `tyre_wheel.gd`, `deck_tip.gd`, `deck_coach.gd` (baru) + `.uid` | widget N2 |
| `scripts/hud/tactical_deck.gd` | ditulis ulang ke tata letak N2; anggota lama dipertahankan (`pace_row`, `fuel_row`, `ers_row`, `tyre_row`, `tactic_row`, `tabs`, `box_button`, `desk_status`, `radio_label`, `info_label`, `collapse_button`, API `press_box/cancel_box/step_pace/...`) |
| `scripts/audio/audio_manager.gd` | `click_pitched`, `play_ui_click_pitched` |
| `tests/test_deck_n2.gd` (baru, 27 assertion), `tests/test_pit_deck_and_radio.gd` | satu baris: reset `deck._box_clicked_at` sebelum klik CANCEL kedua (debounce) |
| `scratch/capture_langkah3c.gd` | tangkapan layar native |

## 3. Verifikasi

- **30 suite headless (29 + `test_deck_n2`): semua OK** dengan pembungkus ketat (gagal bila exit ≠ 0, `[FAIL]`, atau `SCRIPT ERROR`).
- Tes deck dilihat gagal pada deck lama (parse error `SEVERITY_WORD`), widget dilihat gagal sebelum kelasnya ada, teks `%%` diperbaiki lewat RED→GREEN.
- Bukti visual native 1920×1080 (dipotong ke area deck dan tooltip) di `executor-report/screenshots/phases/`: `phase-11-langkah-3c-deck-clean.png`, `-tooltip-pace-attack.png` (DANGER ✖ dengan kalimat coach), `-coach-off.png`, `-tyre-critical.png` (ban 20 %, tooltip FUEL WATCH ▲), `-box-armed.png` (roda `armed`, tombol CANCEL BOX crimson, tooltip ban WET), `-deck-team2.png` (crimson), `-deck-team7.png` (putih).

**Tidak dilakukan:** pengukuran frame time 60 FPS, uji asap native 3 lap, dan perbandingan sampling refresh (`refresh()` menghitung 12 verdict tiap panggilan; belum diukur).

## 4. Temuan dan ruling

1. **Ukuran kontrol sebelum masuk tree salah.** Ukuran yang diset di `_init` terdongkrak ke minimum tema default (tombol 93×31, grid chip 224×112). `TacticalDeck._ready()` menyetel ulang semua ukuran dari `_extents`; test tata letak mengunci kotak.
2. **Tooltip raksasa.** Label autowrap mengukur tinggi dengan lebar 0 (tip setinggi 2162 px). Label diberi `custom_minimum_size.x`; ditemukan lewat tangkapan layar native, bukan test headless.
3. **Debounce BOX** hanya di `on_box_pressed`; tes 3a yang menekan tombol dua kali dalam satu frame diberi satu baris reset.
4. **Reduce motion** juga meniadakan teks pop (hanya suara dan perubahan keadaan tersisa).
5. Deck ditulis sebelum tes alurnya; RED ditunjukkan setelahnya lewat deck lama (stash). Bukti TDD task ini lebih lemah dari task lain.
6. Ditunda (3d): kartu BOX WINDOW versi penuh (ladder 8 lap) dan Weather Deck; border berkedip kartu strategi.
