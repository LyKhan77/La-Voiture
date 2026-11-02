# FASE 21.3 — Engine SFX per Keluarga Mesin

**Tanggal:** 2026-11-02 · **Branch:** `fase-21-3-engine-sfx` · **Agen:** Claude Code (Executor)

## Masalah

Semua 20 mobil (13 model) memakai satu loop `gt3_engine_loop.wav` (1 dtk, mono) dengan satu kurva pitch. Dalam rombongan, loop identik berfase sama dan menyatu jadi satu dengung. Tidak ada beda antara gas diinjak dan gas dilepas, tidak ada turbo, dan tidak ada Doppler.

## Solusi

| Tahap | Isi |
| :--- | :--- |
| T1 | Detune ±3 % dan offset loop per mobil (deterministik dari `car.id`, golden-ratio step), Doppler (`DOPPLER_TRACKING_IDLE_STEP`) pada player dan kamera race, mobil yang diikuti kamera +3 dB, *voice budget*: mobil > 45 m dari kamera hanya memutar loop utama. |
| T2 | `EngineProfile` (scripts/audio/engine_profile.gd): 5 keluarga dari `GarageRoster.CAR_ENGINES` (V8 NA, V10 NA, V6 TT, I6 TT, V8 TT), masing-masing dengan loop on/off-throttle, RPM rekaman, rentang idle–redline, dan gain level. RPM sim **tidak diubah**: rentang 1200–8500 dipetakan ke rentang keluarga, pitch di-clamp 0,5–2,0. |
| T3 | Crossfade equal-power on/off throttle, upshift crack, overrun crackle (NA) atau blow-off (turbo) sekali per angkatan gas di atas 25 m/s, siulan turbo yang mengikuti RPM dan throttle. |

## Aset (ElevenLabs Sound Effects, akun developer)

- 14 klip WAV 44,1 kHz di `assets/audio/engine/profiles/`, dibuat dengan `tools/audio/gen_engine_sfx.mjs` (key dari `.env.local`, tidak di-commit).
- Total biaya 960 kredit ElevenLabs dari kuota 40.000 (angka dari dashboard API), termasuk generate ulang.
- Loop turbo (V6 TT on, V8 TT on/off) dari model selalu "berakselerasi". `tools/audio/trim_steady_loop.mjs` mengambil potongan 1,75 dtk yang paling stabil, lalu menyambung tail ke head dengan crossfade. Drift sisa 4–9 %, disamarkan oleh detune. Klip mentahnya disimpan di `temp/engine_raw/`.
- Genex tidak dipakai: batas belanja aset 294/294 sudah habis.

## Verifikasi

- `tests/test_engine_audio_profiles.gd`: 12/12 PASS. RED terlihat lebih dulu (Parse Error, `EngineProfile` belum ada).
- `tests/test_audio_and_race_weekend.gd` (`--skip-legacy`): 35/35 PASS. #5, #7, dan #22 disesuaikan ke kontrak profil; #22 juga memeriksa Doppler kamera dan tepat satu mobil fokus.
- Suite penuh `tools/run_tests.ps1`: lihat bagian Hasil Suite.

## Hasil Suite

- Irisan 0–19, 20–39, 40–59: 60/60 PASS, 0 FAIL.
- Irisan 60–79 sempat dihentikan sistem (RAM kritis), lalu diulang di latar depan: 60–69, 70–79, 80–89, 90–97 semuanya PASS. Total 98/98 PASS, 0 FAIL.

## Belum dikerjakan / risiko

- Playtest dengar oleh developer belum dilakukan. Tuning gain, `TURBO_DB`, dan `OFF_LAYER_DB` kemungkinan masih perlu disetel di telinga.
- Garasi dan transisi manga masih memakai `gt3_engine_loop.wav` lama.
- Throttle smoothing bergantung pada frame rate (disetel untuk 60 FPS), ditandai `shortcut:` di kode.
- Smoke test native 3 lap dan pengukuran FPS dengan 20 mobil × 4 player belum dijalankan.
