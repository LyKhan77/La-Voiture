# TASK — Fase 15: Sirkuit Monte Azure Marina (Ronde 04, SPRINT)

> **Initiate Prompt untuk Executor.** Status: keputusan developer 2026-10-30 sudah masuk (SPEC §6): geometri beku, deviasi diterima dengan syarat logis, nama tikungan diganti. Referensi gate sudah dibuat (langkah 6). Spesifikasi: `docs/superpowers/specs/2026-10-30-fase-15-monte-azure-audit-and-production-spec.md` (selanjutnya "SPEC"). Developer belum menyatakan "mulai eksekusi"; konfirmasi dulu sebelum langkah 0.

## Peran dan aturan

Kamu Executor La_Voiture. Baca dulu: `AGENTS.md`, `Circuit-Environment-Component-Guide.md` (§2b, §3), SPEC (penuh), dan memori `project_circuit_modules`, `feedback_layout_driven_environment_reuse`, `project_fase141_draw_call_gate`.

- Branch: `fase-15-monte-azure-circuit` dari `main`. Siklus TDD (tes merah dulu, lihat gagal, lalu hijau).
- Angka geometri dan pit blueprint **beku**: `D:/Occupation/Porto/genex/mapgen-circuit/designs/monte_azure/final/blueprint.track.json` (`geometry_hash sha256:f495332f4668c70d53272037c1b0ca939e7795adf6eee4d46cd1781981eda5f0`). Jangan mengedit paket mapgen. Deviasi dari paket boleh hanya yang tercatat di SPEC §2.2 dan §6, dengan alasan di laporan.
- Dokumen handoff yang benar: `D:/Occupation/Porto/genex/mapgen-circuit/builds/monte_azure/production-handoff.md` (dikoreksi developer). Urutan prioritas bila bertentangan: SPEC (termasuk §1b rekonsiliasi) > `production-handoff.md` > `final/procedural-spec.md` > `final/handoff-prompt.md` (usang; jangan diikuti untuk path atau nama kelas).
- Jangan menyentuh sirkuit lain, gaya cel global, atau file shader bersama kecuali regresi Apex/Wangan/Brianza tetap hijau. Jangan menyalin folder `vendor/`, shim, `dummy_car.gd`, atau HUD simulasi dari `builds/monte_azure/`.
- Satu-satunya perubahan pada sirkuit lain: menambahkan `"monte_azure"` ke daftar `CIRCUITS` tes kontrak (SPEC §5.1).
- Jangan menghapus atau menimpa berkas yang bukan kamu buat. Cadangan lokal ke `temp/`.
- Jangan commit `.godot/`, `temp/`, atau aset mentah. Commit `.import`/`.uid` bersama aset yang kamu tambah. Commit kecil per langkah.

## Langkah

### 0. Pra-syarat
1. Baca `reference-assets/tracks/monte_azure/` (key visual + view1–4).
2. Verifikasi paket: hitung SHA-256 empat file di `final/` dan cocokkan dengan `manifest.json`. Gagal = berhenti dan lapor.
3. Jalankan `python -I scratch/monte_azure_geometry_audit.py`; catat `plan_scale` 1,100552 dan radius dunia minimum 23,7 m sebagai garis dasar tes.
4. Jalankan `powershell -File tools/run_tests.ps1` di `main` dan simpan hasil dasar.

### 1. Builder, scene, registri (SPEC §4.1, §4.2)
- Tes merah: `tests/test_monte_azure_circuit.gd` (SPEC §5.1). Lihat gagal.
- Nama tikungan produksi (keputusan developer, SPEC §4.2): T7 "Tunnel In", T8 "Tunnel Out", T11 "Marina Sweep", T12 "Yacht Club"; selain itu nama blueprint. Tambahkan field `angle_deg` pada `turns`; tes menegaskan nama baru dan 16 tikungan ≥ 15°.
- Tulis `scripts/world/circuits/monte_azure/monte_azure_circuit_builder.gd` dan `scenes/race_world/circuits/monte_azure/monte_azure_circuit.tscn` (pola `brianza_circuit.tscn`: `TrackRibbon` dengan `road_half_width_m = 5.5`, `PitLane`, `Environment`, `WorldEnvironment`; jangan menulis `uid=` tangan).
- Ubah `scene_path` Monte Azure di `scripts/core/circuit_calendar_registry.gd` ke path baru. Perbarui `test_track_selector_ui.gd` #S4b (Round 05 Ardennes menjadi contoh "belum dibangun") dan `test_visual_polish_and_consistency.gd` (CarouselCard3 playable, CarouselCard4 "IN PREPARATION").
- Hijau: `test_monte_azure_circuit`, `test_circuit_calendar_registry`, `test_track_selector_ui`, `test_visual_polish_and_consistency`.

### 2. Pit complex (SPEC §4.3)
- Tes merah: `tests/test_monte_azure_pit_layout.gd`; tambahkan `"monte_azure"` ke lima tes kontrak, `test_flag_panels_contract`, dan skenario `test_pit_stop_in_world.gd`.
- `MonteAzurePitComplex extends CircuitPitComplex` dengan penampang Wangan-compact; `sim_layout()` lengkap; `PitBuilding`, `MainGrandstand` 160 m, `RaceControlTower` s≈176, `StartGantry`, transporter lateral 40, fascia lewat `TeamSignage`, kru standby 13 orang.
- Gerbang: `godot --headless --path . -s scratch/smoke_pit_race.gd -- monte_azure` (6 mobil ke box, 0 orphan); `test_pit_queue_flow`.

### 3. Environment inti (SPEC §4.4 poin 1–4, 6)
- Tes merah: `tests/test_monte_azure_terrain_gate.gd` (pola `test_brianza_terrain_gate.gd`: sampel jalan ≤ 6 m, lateral kiri/tengah/kanan, apron pit; tanah mesh di bawah jalan; koridor 10,5 m bebas objek acak; koridor pit bebas objek).
- `MonteAzureEnvironment extends CircuitEnvironment`: terrain LOD, laut `neo_wangan_water.gdshader`, tembok beton + kerb jalan hanya tikungan ≥ 15°, papan rem, lampu, `flag_panels` (`FlagPanelSet.plan`), `WorldSkyRig` + `SKY_PROFILES`, `apply_time_of_day`, `apply_wind`, `ground_y_at`, `_extra_stats`, jumbotron lewat `_feed_leaderboards`.
- Zona strip dibaca per stasiun jalan terdekat, bukan persegi per rentang s. Ini koreksi untuk F2 di SPEC; jangan memakai band mentah.
- Hijau: `test_circuit_environment_contract`, `test_flag_panels_contract`, `test_monte_azure_terrain_gate`. Ukur `scratch/measure_env_draw_calls.gd -- monte_azure 150` sebelum menambah Tier B; catat angka dasar.

### 4. Tier B (SPEC §4.4 poin 5, §4.5)
- Salin 5 GLB ke `assets/tracks/monte_azure/models/`, tulis `asset_manifest.json`, `godot --headless --path . --import`.
- Tes merah: `tests/test_monte_azure_landmarks.gd` (SPEC §5.1).
- Hero via `_model_at`, outline `inverted_hull_outline`. `offset_m` blueprint = jarak sisi dekat (pusat = offset + kedalaman/2) untuk kasino, hotel, yacht. **Terowongan dan skybridge berpusat di lateral 0** (jalan lewat di dalam/bawahnya); terowongan diskalakan 190 → 150 m, dipusatkan di s=1.330, di-pitch mengikuti landai jalan (≈ 2,2°); skybridge di s=2.180 dengan bentang ≥ 22 m, pilar ≥ 9 m dari garis tengah, clearance ≥ 6 m (SPEC §2.2 F15, §4.4).
- Yacht pack, distrik per sektor (`MultiMesh` ber-AABB akurat, `cast_shadow` off bila batasnya seluruh lap), `FoliageScatter`.
- Setelah tiap komponen besar, ukur ulang draw call. Berhenti dan lapor bila view terburuk > 180 sebelum menambah komponen berikutnya.

### 5. Gerbang akhir (SPEC §5.2–§5.4)
- `powershell -File tools/run_tests.ps1` → 100 % PASS.
- `measure_env_draw_calls.gd -- monte_azure 150` ≤ 180 (target p95 ≤ 160); `env.stats()["triangles"]` ≤ 320.000.
- Smoke 3 lap, 20 mobil, DAY / SUNSET / NIGHT, kembali ke menu, 0 orphan; frame time 1080p High ≤ 16,66 ms (`scratch/profile_frame_budget.gd` bila perlu).
- 6 kamera × 3 mode + flythrough chase 150 m dua arah + aerial pit/entry/exit ke `executor-report/screenshots/phases/phase-15/`.

### 6. Referensi gate (selesai, SPEC §6 butir 2)
- Sudah dibuat: `reference-assets/tracks/monte_azure/view1_main_straight_pitstop.png`, `view2_casino_approach.png`, `view3_cliff_tunnel_hotel.png`, `view4_yacht_skybridge_pit_entry.png`. Jangan dibuat ulang (batas aset Genex 186, sisa 0). Bandingkan Cam 1–4 dengan view1–4 di laporan.
- `anime-cel-shaded-key-visual-poster-…png` adalah duplikat byte-identik `concept_key_visual.png`; biarkan, milik developer.
- Bila perlu gambar tambahan, tanya developer dahulu (saldo Genex ≈ 165 kredit).

### 7. Laporan
- `executor-report/reports/FASE-15-MONTE-AZURE-CIRCUIT-REPORT.md`: hasil tes (PASS/FAIL), angka draw call dan triangle, deviasi (tower s, tribun 160 m, penampang pit, 16 kerb), temuan baru untuk agen mapgen.
- Perbarui `ROADMAP.md`. Jangan menyatakan selesai sebelum DoD AGENTS §8 terpenuhi; bila ada yang belum terukur (mis. FPS native), tulis apa adanya.

## Kriteria selesai
Semua gerbang SPEC §5 hijau, laporan ditulis, dan tidak ada regresi pada Apex Ring, Neo-Wangan, atau Brianza (tes kontrak + hash determinisme Apex).
