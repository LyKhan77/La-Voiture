# FASE 29 — Live Timing "Slab" + roda tyre-life: laporan eksekutor

**Tanggal:** 2026-11-05
**Agen:** Claude Code (Sonnet 5.5), Planner + Executor
**Branch:** `fase-29-live-timing-slab` (belum di-commit, belum di-merge)
**Spec:** [`2026-11-05-live-timing-slab-design.md`](../../docs/superpowers/specs/2026-11-05-live-timing-slab-design.md) · **Rencana:** [`2026-11-05-live-timing-slab.md`](../../docs/superpowers/plans/2026-11-05-live-timing-slab.md)

## Hasil

| Area | Sebelum | Sekarang |
|---|---|---|
| Live Timing | `POS / DRIVER / INT / huruf kompon`; sorotan terpilih lime tetap | Baris ringkas 30 px (posisi, kode, nilai Tab, penanda tim, ring tyre-life). Mobil yang di-follow menjadi baris berwarna tim 46 px (opsi B): baris 30 px dengan kolom Tab, plus strip 16 px berisi tiga bar sektor, umur ban, stop, GAP, LAST, dan tag DRS. Header, bingkai, bayangan, dan slab mengikuti `style.accent/on_accent/shadow`. |
| Elemen ban telemetri | Sumur panas 24×44 + enam blok tread | Roda tick: 16 tick = tyre-life, spoke dan hub warna suhu, kode roda + persen life + suhu di sisi luar. Brake disc, glow, blister, silang ban pecah dipertahankan. |
| Radar | Caption dan chip sektor mobil yang di-follow | Caption dan chip sektor mobil deck; titik besar tetap di mobil kamera |
| Sumber telemetri | Mobil yang di-follow (bisa rival) | `deck.deck_car_id`: hanya driver player yang aktif di Tactical Deck. |
| Ambang merah tyre-life | 0,3 (blok tread lama) | `1 - GtTypes.TYRE_CLIFF_WEAR` = 0,25, sama dengan gauge TYRE LIFE di deck (satu statik, `TyreLifeRing.tint_for`). |

Perubahan data: `GtRace.standings_entries()` +3 kunci (`tyre_life`, `tyre_age_laps`, `stops`). Tidak ada perubahan sim.

## Verifikasi

- **TDD:** `tests/test_live_timing_slab.gd` (26 assertion). Tiap kelompok tes dilihat **gagal** terhadap kode lama sebelum implementasi (telemetri rival, kunci entry, kelas ring belum ada, `wheel_ticks` belum ada, `DriverRow` belum punya `class_name`, tidak ada baris `expanded`, `slab_texts` belum ada, kontras label Tab 1,8).
- **Regresi penuh:** `tools/run_tests.ps1` per irisan, latar depan: `0-19`, `20-34`, `35-52`, `53-72`, `73-92`, `93-114` → **115 suite, 0 failing**. Setelah perbaikan terakhir (label Tab) suite terkait dijalankan ulang: `live_timing`, `race_hud`, `hud_theme`, `pit_wall`, `weather_and_ai`, `deck`, `circuit_minimap`, `visual_polish` → 0 failing.
- **Native 1080p** (`d3d12`, High, Apex Ring, seed 29): `temp/capture_live_timing.gd`, 11 capture di `executor-report/screenshots/phases/phase-29-live-timing-slab/` (`team_lime|light|near_crimson|dark|player`, `tab_gap|last|int`, `rival_clicked`, `deck_second_driver`, `worn_tyres_and_dnf`). Terbaca di capture: rival diklik → slab pindah, telemetri tetap `#09 KAD`; ban aus 82% → tick crimson, ring slab crimson, gauge deck 18% DANGER (konsisten); tim terang → slab terang, teks ink; tim gelap `#1E3A8A` → teks putih.
- **Frame time native** (`temp/probe_hud_frames.gd`, 900 frame, balapan 20 mobil 1x, 3 kali): avg 16,67 ms, p95 16,80 / 16,90 / 16,92 ms, p99 18,3 / 19,1 / 19,7 ms, max 23 sampai 25 ms; **0 orphan node** setelah dunia dibebaskan. Pembacaan Fase 20 adalah p95 16,839 ms (ambang 16,8). Pita yang sama; baseline `main` tidak diukur ulang di sesi ini.

## Keputusan builder (Ruling)

1. Tanpa commit per task: aturan repo (commit hanya bila developer meminta) mengalahkan langkah Checkpoint di rencana. Biaya bila salah: tidak ada rentang review per task.
2. `DriverRow` mempertahankan tampilan lama (baris terbalik + snap 6 px) bila tidak diberi `style` (`_legacy_lit`): `tests/test_pit_wall.gd` (PitWallDashboard, Fase 2) mengunci tampilan itu. HUD balapan memberi `style`, jadi mendapat tampilan baru. Biaya: dua tampilan lit di kode.
3. Nomor mobil tidak diwarnai terpisah (label `_driver` tetap satu teks `#09 KAD` karena tes membacanya); penanda tim dan `*` membawa identitas tim.
4. Ambang life 0,3 → 0,25 (spec diamandemen). Biaya: ring merah sedikit lebih lambat dari blok tread lama.
5. `TyreLifeRing.change_count` menggantikan `draw_count` di rencana (tes headless tanpa frame).
6. Baris `tower.style = style` dimajukan dari Task 7 ke Task 6 (tes slab butuh tower ber-style).
7. Header tower tetap tab chamfer berisi accent (seperti header deck), bukan header datar seperti preview HTML; catatan "LAP nn/nn" lewat `TimingTower.set_header_note`.
8. Label kolom Tab berwarna accent hanya bila kontras ≥ 3:1 terhadap panel; selain itu putih (ditemukan dari capture tim gelap, tes ditambahkan merah dulu).
9. Radar: semula dibiarkan, lalu diputuskan developer (opsi B) mengikuti mobil deck. `#R4` di `tests/test_circuit_minimap.gd` diubah karena menguji perilaku lama. Titik besar tetap di mobil kamera karena itu posisi, bukan status. Biaya: caption radar dan titik besar bisa menunjuk mobil berbeda saat rival diklik.
10. Slab berganti dengan snap tanpa animasi.
11. Setelah review, slab 100 px diganti opsi B (46 px, strip 16 px) dari tiga konsep compact di preview HTML; teks strip 9 px, hanya dinilai dari capture. Nomor mobil tidak lagi berplat sendiri (kode `#09 KAD` satu label). Biaya: teks strip kecil.

## Belum / catatan

- Smoke native (`scratch/smoke_race.gd -- apex_ring`, `d3d12` 1080p, HUD Fase 29 aktif): 3 lap 20 mobil, 20/20 finis, frame rata-rata 16,67 ms, p95 16,74 ms, terburuk 17,07 ms, podium terbuka, **0 orphan** setelah dunia dan podium dibebaskan. Skrip ini tidak menekan tombol EXIT TO HQ, jadi pindah ke menu utama tidak diuji ulang di fase ini (jalur itu tidak disentuh Fase 29).
- Wear per roda tidak ada di sim: keempat roda menampilkan tyre-life yang sama.
- Keterbacaan font 11/17 px roda tick dinilai dari capture saja; tidak ada pengguna yang menguji.
- Klik baris di bawah slab menggeser daftar 16 px (sebelumnya 70 px); tidak diuji dengan tangan.
- Peringatan ObjectDB leak muncul sekali pada satu run headless suite baru tepat setelah edit file (31–37 instance) dan tidak terulang pada run berikutnya maupun pada `test_race_hud`. Tidak ditemukan penyebabnya.
- `slab_texts` dihitung untuk 20 entry tiap 6 frame padahal hanya satu yang dipakai (minor, ditunda).

## File

Diubah: `scenes/pit_wall/driver_row.tscn`, `scenes/pit_wall/timing_tower.tscn`, `scripts/gt/gt_race.gd`, `scripts/hud/race_hud.gd`, `scripts/hud/telemetry_painter.gd`, `scripts/ui/driver_row.gd`, `scripts/ui/timing_tower.gd`, `tests/test_race_hud.gd`, `AGENTS.md` (irisan suite), `ROADMAP.md`.
Baru: `scripts/hud/tyre_life_ring.gd` (+ `.uid`), `tests/test_live_timing_slab.gd` (+ `.uid`), spec, rencana, laporan ini, capture di `executor-report/screenshots/phases/phase-29-live-timing-slab/`.

**Sengaja tidak di-commit:** `.uid` yang dibuat impor Godot untuk pekerjaan lain (`scratch/capture_kurogane_views.gd.uid`, `scratch/smoke_kurogane_race.gd.uid`, `scripts/world/circuits/kurogane/kurogane_environment.gd.uid`, `tests/test_garage_engine_test.gd.uid`, `tests/test_garage_transition_engine.gd.uid`, `tests/test_kurogane_circuit.gd.uid`, `tests/test_kurogane_pit_drive.gd.uid`, `tests/test_kurogane_pit_flood.gd.uid`, `tests/test_pit_mouth_pavement.gd.uid`), `temp/` (skrip capture dan probe, preview HTML), `.superpowers/` (ledger).
