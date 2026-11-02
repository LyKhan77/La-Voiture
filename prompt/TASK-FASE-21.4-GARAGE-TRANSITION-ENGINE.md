# TASK — Fase 21.4 Suara mesin per tim di garasi & transisi manga

**Prasyarat:** branch `fase-21-3-engine-sfx` (Fase 21.3, belum di-commit, developer sudah dengar: "sudah sesuai"). Commit dulu 21.3 bila developer mengizinkan, lalu branch `fase-21-4-garage-transition-engine` dari situ.
**Biaya aset:** 0 kredit (pakai `assets/audio/engine/profiles/*`).

## Konteks

- `EngineProfile.for_team(team_id)` (scripts/audio/engine_profile.gd) → `on_stream`, `off_stream`, `pitch_for(sim_rpm)`, `turbo`, `on_gain_db`.
- One-shot: `EngineAudio3D.UPSHIFT_STREAM`, `OVERRUN_STREAM`, `BLOW_OFF_STREAM`.
- Masih pakai loop lama `gt3_engine_loop.wav`:
  - `scripts/ui/garage_team_select.gd:239` `_play_launch_rev()` (pitch tetap 1.55, `selected_team` tersedia).
  - `scripts/ui/manga_race_transition.gd:16,126` `ROAR` (tim di `_team`).
- `gt3_engine_loop.wav` JANGAN dihapus (masih di `ESSENTIAL_AUDIO` test #4).

## Langkah

1. Test RED dulu `tests/test_garage_transition_engine.gd`: garasi launch rev & transisi roar memakai `EngineProfile.for_team(tim).on_stream` untuk ≥2 tim berbeda family (team 0 v8_na, team 1 v10_na).
2. Garasi: `_engine_player.stream = profile.on_stream`, `pitch_scale = profile.pitch_for(7500.0)`, `volume_db = -3.0 + profile.on_gain_db`.
3. Transisi: ganti `ROAR` jadi loop tim; tambah `UPSHIFT_STREAM` (atau `BLOW_OFF_STREAM` bila `profile.turbo`) pada momen snap negatif.
4. Opsional, tanya developer dulu: blip ±0,6 dtk saat ganti tim di dolly (tween pitch 0.8 → 1.4 → 0.8 + crack).
5. `tools/run_tests.ps1` dalam irisan latar depan ≤10 suite (`-From 0 -To 9`, …): RAM laptop kritis bila irisan besar/latar belakang.
6. Laporan `executor-report/reports/FASE-21.4-*.md`, update `todo.md`.

## Gotcha

- Class baru → `godot --headless --path . --import` dulu (cache class global).
- File `.gd` campur LF/CRLF: pakai Edit tool, bukan regex perl multi-baris.
- Godot console: `C:\Users\Lee\Downloads\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe`.
