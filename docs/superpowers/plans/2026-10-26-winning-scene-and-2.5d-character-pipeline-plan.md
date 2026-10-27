# Implementation Plan: Dedicated Winning Scene Studio & 2.5D Kinetic Character Pipeline

> **For agentic workers:** REQUIRED SUB-SKILL: Use `superpowers:executing-plans` task-by-task. User already authorized execution in this workspace; no approval pause or commit is required.

**Goal:** Membangun panggung selebrasi kemenangan studio 3D mandiri (`winning_scene.tscn`), mengimplementasikan pipeline karakter 2.5D kinetik (`KineticStandee3D`), menampilkan mobil juara P1 di atas *turntable*, serta menambahkan fitur *Toggleable Leaderboard* (`[TAB]`) untuk sinematografi kemenangan yang bersih dan estetik.

**Architecture:** Godot Engine 4.7.2 stable, typed GDScript 2.0, Forward+ Desktop. Panggung studio 3D mandiri yang terpisah dari trek sirkuit untuk efisiensi render maksimal. Karakter dirender sebagai 2.5D QuadMesh ber-shader cel-shaded manga yang menjatuhkan bayangan nyata ke lantai podium 3D.

**Tech Stack:** Godot Engine 4.7.2, Python 3.10+ (Pillow/NumPy image tooling), Godot Shading Language (`.gdshader`).

**Spec:** [`docs/superpowers/specs/2026-10-26-winning-scene-and-2.5d-character-pipeline-design.md`](file:///D:/Occupation/Porto/genex/La_Voiture/docs/superpowers/specs/2026-10-26-winning-scene-and-2.5d-character-pipeline-design.md)

---

## Global Constraints & Safeguards
1. **Preserve Existing Assets:** Dilarang menimpa atau memodifikasi file mentah di `reference-assets/characters/`. Hasil olahan cut-out disimpan di direktori baru `assets/characters/standees/`.
2. **Deterministic & Isolated Scene:** `winning_scene.tscn` harus dapat dijalankan mandiri (via test runner maupun transisi dari balapan) dengan menerima data snapshot hasil balap `order`, `winner_car`, `team_points`.
3. **Zero Memory Leak:** Saat scene keluar menuju `main_menu.tscn`, seluruh node 3D, partikel confetti, dan tekstur wajib dibebaskan secara bersih (`0 orphan nodes`).
4. **Zero Regression:** Seluruh 35 test suite yang ada wajib tetap 100% PASS (0 FAIL).

---

## Task 1 — Otomasi Cutout Karakter & Direktori Standee
**Files:**
- Skrip Baru: `scratch/process_character_cutout.py`
- Output Aset: `assets/characters/standees/kaze_ryu.png`, `assets/characters/standees/makoto_ito.png`, `assets/characters/standees/arthur_sterling.png`

**Langkah Pengerjaan:**
- [ ] Buat skrip Python `scratch/process_character_cutout.py` menggunakan Pillow & NumPy untuk mengisolasi latar belakang studio abu-abu (`RGB 168 ± 6`) dari `full_body_concept.png`.
- [ ] Tambahkan algoritma *floodfill / alpha-matte boundary smoothing* untuk menghasilkan tepi garis tinta manga yang tajam tanpa artefak halo abu-abu.
- [ ] Proses karakter percontohan pertama: Kaze Ryu (#01 RYU - Apex Racing) dan simpan ke `assets/characters/standees/kaze_ryu.png`.
- [ ] Buat 2 standee tambahan untuk posisi P2 dan P3 (misal Makoto Ito - Neon Drift dan Arthur Sterling Jr - Zephyr Racing).

---

## Task 2 — Node `KineticStandee3D` & Shader Bayangan Nyata
**Files:**
- Skrip Baru: `scripts/ui/kinetic_standee_3d.gd`
- Shader Baru: `shaders/kinetic_standee.gdshader`

**Langkah Pengerjaan:**
- [ ] Buat shader `shaders/kinetic_standee.gdshader` yang mendukung:
  - Alpha scissor / transparency dengan outline manga.
  - Rim lighting neon sesuai warna tema tim pembalap (`team_color`).
  - Menerima diffuse lighting dari spotlight studio.
- [ ] Buat kelas `KineticStandee3D` (`Node3D`):
  - Memiliki `MeshInstance3D` dengan `QuadMesh` ($1.85\text{ m} \times 1.05\text{ m}$).
  - Mengaktifkan `cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON` agar karakter menjatuhkan bayangan nyata ke lantai panggung.
  - Menjalankan loop animasi pernapasan prosedural (`breathing loop`: skala Y $\pm 1.2\%$, durasi $2.4\text{ s}$).
  - Menambahkan partikel 3D hologram kanji melayang di belakang siluet karakter (`勝者` / `WINNER`).

---

## Task 3 — Scene Panggung Podium Studio 3D (`winning_scene.tscn`)
**Files:**
- Scene Baru: `scenes/ui/winning_scene.tscn`
- Skrip Baru: `scripts/ui/winning_scene.gd`
- Props 3D: Model piala emas 3D (procedural mesh / model piala).

**Langkah Pengerjaan:**
- [ ] Rancang arsitektur 3D panggung podium di `winning_scene.tscn`:
  - Panggung 3 undak (P1 tengah $0.8\text{ m}$, P2 kiri $0.5\text{ m}$, P3 kanan $0.3\text{ m}$) dengan marmer gelap dan trim neon beraksen emas, perak, dan perunggu.
  - Turntable mobil berputar lambat di belakang panggung podium ($6.5\text{ m}$ diameter, rotasi $0.06\text{ rad/s}$).
  - Trofi piala kejuaraan emas 3D di atas pedestal P1.
- [ ] Pasang sistem pencahayaan studio:
  - 3 Volumetric Spotlights menyorot P1, P2, P3.
  - Partikel confetti keemasan berjatuhan dari atas langit-langit panggung.
- [ ] Di `winning_scene.gd`, buat fungsi `setup_celebration(results: Dictionary)`:
  - Memuat standee karakter pemenang P1, P2, P3 ke tangga yang sesuai.
  - Memuat sasis mobil juara P1 secara dinamis dari `assets/cars/<car_slug>/<car_slug>_full.glb` ke atas turntable.

---

## Task 4 — UI Minimalis & Fitur Toggle Leaderboard (`[TAB]`)
**Files:**
- Modifikasi: `scenes/ui/winning_scene.tscn` & `scripts/ui/winning_scene.gd`

**Langkah Pengerjaan:**
- [ ] Rancang UI layer kemenangan:
  - **Tampilan Clean (Default):** Header street stencil, kartu nama P1-P3, tombol navigasi `[TAB] TOGGLE TIMING`, `[R] RESTART`, `[ESC] EXIT TO HQ`.
  - **Tampilan Expanded (Timing Tower):** Panel klasemen 20 pembalap lengkap dengan selisih waktu, fastest lap bonus point (+1 PT ungu), dan perolehan poin FIA GT3.
- [ ] Implementasikan animasi transisi slide-in / slide-out halus saat tombol `[TAB]` ditekan.
- [ ] Tambahkan kamera sinematik lambat (*slow orbit dolly*) saat leaderboard disembunyikan agar scene tampil estetik untuk tangkapan layar (*Photo Mode*).

---

## Task 5 — Integrasi Game Loop, Automated Test Suite & Verifikasi 60 FPS
**Files:**
- Modifikasi: [`scripts/world/race_weekend_world.gd`](file:///D:/Occupation/Porto/genex/La_Voiture/scripts/world/race_weekend_world.gd)
- Test Suite Baru: `tests/test_winning_scene_and_standee.gd`
- Skrip Probe: `scratch/smoke_winning_scene.gd`
- Laporan Resmi: `executor-report/reports/FASE-11-LANGKAH-7-WINNING-SCENE-REPORT.md`

**Langkah Pengerjaan:**
- [ ] Hubungkan akhir balapan di `race_weekend_world.gd`: saat chequered flag selesai, alihkan scene ke `winning_scene.tscn` dengan mengirimkan data snapshot balapan.
- [ ] Buat unit & integration test `tests/test_winning_scene_and_standee.gd`:
  - Memvalidasi pemuatan aset standee 2.5D dan bayangan di lantai 3D.
  - Memvalidasi mobil juara di turntable.
  - Memvalidasi toggle show/hide leaderboard `[TAB]`.
  - Memvalidasi transisi `EXIT TO HQ` kembali ke menu utama dengan 0 orphan node.
- [ ] Jalankan seluruh 36 test suite via `godot --headless`, pastikan **100% PASS, 0 FAIL**.
- [ ] Jalankan smoke test native 1080p High Preset, ukur FPS (target terkunci 60 FPS), simpan tangkapan layar verifikasi, dan susun laporan resmi.
