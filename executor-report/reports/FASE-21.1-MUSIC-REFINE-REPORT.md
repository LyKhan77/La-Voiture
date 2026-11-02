# FASE 21.1 — Music Refine (playlist menu + musik race adaptif)

**Tanggal:** 2026-11-02 · **Agen:** Claude Code · **Branch:** `fase-21-music-refine`

## Keputusan desain

- Musik tetap diputar saat balapan, tetapi sebagai latar: AMBIENT (default) memutarnya 8 dB di bawah trim trek. Pilihan di Settings: `RACE MUSIC: OFF / AMBIENT / FULL`.
- Menu dan race dibedakan: menu memakai playlist berurutan (lagu utuh, tampil "NOW PLAYING"), race memakai loop instrumental tanpa vokal supaya tidak bentrok dengan radio TTS.
- Hanya aset yang dimiliki sendiri (Genex). Lagu komersial tidak dipakai karena butuh lisensi sync + master.

## Aset (Genex `music`, 4 × 27 cr = 108 cr; allowance build 186→294 disetujui developer)

| Konteks | File | LUFS | Trim |
|---|---|---|---|
| Menu #1 | `streetwear_synth.ogg` (lama) | -11.9 | 0.0 |
| Menu #2 | `menu_acid_jazz.mp3` | -13.5 | +1.6 |
| Garage | `garage_lofi.mp3` | -14.3 | +2.4 |
| Race kering | `race_dnb.mp3` | -12.3 | +0.4 |
| Race hujan | `race_rain.mp3` | -13.3 | +1.4 |
| Podium | `podium_rock_anthem.mp3` (lama) | -9.7 | -2.2 |

Nama pendek adalah salinan file unduhan Genex (nama panjang `instrumental-*-cmvyod*.mp3`, disimpan sebagai provenance).

## Perilaku

- `AudioManager.PLAYLISTS`: konteks → `[path, trim_db]`. Konteks dengan >1 trek tidak loop dan maju ke trek berikutnya pada `finished`; konteks satu trek loop. Fade-in 0.8 s saat trek baru mulai.
- `start_music()` = kembali ke playlist menu (dipakai main menu dan race setup); garage memakai `play_context(TRACK_GARAGE)`; trek yang sudah berjalan tidak di-restart.
- Race: `play_race_music(wet)` saat world dibangun. Lampu start pertama → musik senyap (beep di atas hening); lights out → trek race masuk.
- `RaceWeekendWorld._update_music_mood` melapor tiap 0.5 s: hujan (drizzle/heavy dari `GtWeatherOutlook.state_of`) menukar ke trek hujan setelah bertahan 12 s; SC/VSC menyalakan low-pass 700 Hz di bus Music; lap terakhir pemimpin menaikkan +4 dB (AMBIENT).
- Low-pass hanya aktif selama konteks race; podium/menu tidak pernah teredam.
- Toast `NOW PLAYING // <judul>` 3 s di kanan bawah main menu, juga saat playlist berganti trek.

## File berubah

`scripts/audio/audio_manager.gd`, `scripts/core/presentation_settings.gd`, `scripts/ui/settings_modal.gd`, `scripts/ui/main_menu.gd`, `scripts/ui/garage_team_select.gd`, `scripts/world/weekend/race_weekend_world.gd`, test baru `tests/test_race_music.gd`.

## Verifikasi

- `tests/test_race_music.gd`: 21/21 PASS. `test_podium_music` 7/7, `test_music_single_config` 10/10 PASS.
- Regresi penuh via `tools/run_tests.ps1` dalam irisan: 0-19 PASS 20/20 (427 s), 20-59 PASS 40/40 (705 s), 60-96 PASS 37/37 (547 s). Total **97/97 PASS, 0 FAIL**.

## Belum dikerjakan / risiko

- Playtest native oleh developer (2026-11-02): menu, garage dan race music dinyatakan sesuai. Smoke formal 3 lap 20 mobil + FPS tidak dijalankan ulang untuk perubahan audio ini.
- Gelombang 2 (eurobeat lap terakhir, trek tambahan) menunggu refill kredit 4 Nov.
- `npx genex wait --all` sempat mengunduh ulang 25 aset lama ke `assets/audio/music/`; developer sudah menghapusnya. Pakai `npx genex wait <id>` per job, bukan `--all` dengan `--out-dir`.
- `godot --headless --import` menulis ulang ~44 file `.import` lama (radio voice, Mercedes, Ardennes, Stoke Crown); bukan bagian perubahan ini, jangan di-commit.
- Update Genex CLI 1.36.9 → 1.36.17 ditolak classifier.
