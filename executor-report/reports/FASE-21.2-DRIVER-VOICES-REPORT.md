# FASE 21.2 — Driver Voices (suara radio per driver)

**Tanggal:** 2026-11-02 · **Agen:** Claude Code · **Branch:** `fase-21-2-driver-voices`

## Masalah

- `RadioVoice.FEMALE_DRIVER_SLOTS = [7]` berasal dari roster lama (Freja Berg). Di roster sekarang slot 7 adalah **R. Silva** (pria), jadi Silva berbicara dengan suara wanita dan kelima driver wanita (Novak 9, Aoki 13, Weiss 15, Rossi 21, Takahashi 25) berbicara dengan suara pria.
- Semua driver pria memakai satu voice (`am_eric`); radio hanya dari dua driver tim pemain, jadi dua rekan setim pria tidak bisa dibedakan.

## Perubahan

- `tools/audio/radio_lines.mjs`: `DRIVER_VOICES` — 8 voice Kokoro (pria `am_eric`, `am_michael`, `am_fenrir`, `am_puck`, `bm_george`; wanita `af_bella`, `af_heart`, `bf_emma`). Setiap baris driver dirender sekali per voice. Sufiks id mempertahankan klip lama: `am_eric` tanpa sufiks, `af_bella` = `_f`, lainnya `_<nama>`.
- `tools/audio/generate_radio_voices.mjs`: memakai voice per baris. 108 klip baru dirender lokal (Kokoro-82M, 0 kredit Genex); manifest 219 baris, setiap baris driver membawa `voice`.
- `scripts/audio/radio_voice.gd`: `DRIVER_VOICES` per slot (26, urutan `GtData.DRIVER_NAMES`), `voice_of(slot)`, `is_female_driver` diturunkan dari voice (`af_`/`bf_`). `find()` memilih klip dengan voice driver itu, jatuh ke `am_eric` bila tidak ada. `engineer` tetap `bm_lewis`.
- Casting: rekan setim selalu beda voice; wanita memakai `af_heart` (Novak, Rossi), `af_bella` (Aoki, Takahashi), `bf_emma` (Weiss). Daftar lengkap ada di komentar `DRIVER_VOICES`.

## Verifikasi

- RED: `test_radio_and_podium` dengan casting lama — #23 gagal (miscast: R. Silva, E. Novak, P. Aoki, C. Weiss, A. Rossi, R. Takahashi), #24 dan #24b gagal.
- GREEN: `test_radio_and_podium` 36/36, `test_audio_and_race_weekend` 36/36 (#31: 219 klip, semua 24 kHz, 0.4–12 s).
- Tes baru #23 (tepat lima wanita roster), #24 (rekan setim tidak berbagi voice), #24b (setiap driver terdengar dengan voice-nya sendiri; setiap voice punya semua baris driver).
- Regresi penuh via `tools/run_tests.ps1`: 0-19 19/20 (1042 s; `test_audio_and_race_weekend` TIMEOUT 600 s), 20-59 PASS 40/40 (779 s), 60-97 PASS 37/37 (450 s). Suite yang timeout dijalankan ulang sendirian via runner: PASS dalam 233 s. Timeout dinilai karena beban mesin (editor Godot lain terbuka), bukan regresi; total **97/97 PASS** setelah ulang.

## Belum dikerjakan / risiko

- Playtest dengar oleh developer (2026-11-02): sesuai. Kualitas Kokoro per voice berbeda (am_eric, am_fenrir, am_puck kelas C/D di daftar Kokoro); bila ada voice yang terdengar buruk lewat filter Radio, ganti di `DRIVER_VOICES` (kedua file) lalu render ulang.
- Tidak ada perubahan nama/karakter di `DRIVER-CHARACTERIZATION-ROSTER.md`.
