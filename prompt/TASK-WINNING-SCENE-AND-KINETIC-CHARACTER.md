# TASK HANDOFF: Langkah 7 — Dedicated Winning Scene Studio & Pipeline Karakter 2.5D Kinetik

**Branch/Target:** `main`  
**Engine:** Godot Engine 4.7.2 stable (`godot --headless`)  
**Role:** Senior Gameplay Architect, Technical Artist & UI/UX Systems Designer  
**Dokumen Referensi:**
- Spesifikasi Desain: [`docs/superpowers/specs/2026-10-26-winning-scene-and-2.5d-character-pipeline-design.md`](file:///D:/Occupation/Porto/genex/La_Voiture/docs/superpowers/specs/2026-10-26-winning-scene-and-2.5d-character-pipeline-design.md)
- Rencana Implementasi: [`docs/superpowers/plans/2026-10-26-winning-scene-and-2.5d-character-pipeline-plan.md`](file:///D:/Occupation/Porto/genex/La_Voiture/docs/superpowers/plans/2026-10-26-winning-scene-and-2.5d-character-pipeline-plan.md)
- Pedoman Arsitektur: [`AGENTS.md`](file:///D:/Occupation/Porto/genex/La_Voiture/AGENTS.md)
- Roster Karakter Lengkap: [`reference-assets/characters/DRIVER-CHARACTERIZATION-ROSTER.md`](file:///D:/Occupation/Porto/genex/La_Voiture/reference-assets/characters/DRIVER-CHARACTERIZATION-ROSTER.md)
- Podium Lama: [`scripts/ui/podium_screen.gd`](file:///D:/Occupation/Porto/genex/La_Voiture/scripts/ui/podium_screen.gd)
- Turntable Orbit Reference: [`scripts/ui/garage_car_orbit.gd`](file:///D:/Occupation/Porto/genex/La_Voiture/scripts/ui/garage_car_orbit.gd)

---

## 1. Context & Objectives

Sebagai jembatan penutup siklus permainan balap (*Game Presentation Loop*) dan fondasi visual untuk **Career Mode**, Anda bertugas mengeksekusi **Langkah 7**:

1. **Otomasi Pemotongan Aset Karakter 2.5D (Background Removal):**
   * Menggunakan konsep seni resolusi tinggi yang sudah ada di [`reference-assets/characters/`](file:///D:/Occupation/Porto/genex/La_Voiture/reference-assets/characters/) (tidak perlu generate 3D via Meshy AI).
   * Memotong latar belakang studio abu-abu (`RGB 168 ± 6`) menjadi PNG transparan (`RGBA`) beresolusi tinggi dengan tepi garis tinta manga (*ink outline*) yang halus tanpa artefak halo.
   * Prototipe awal: **Kaze Ryu (#01 RYU - Apex Racing)** untuk juara P1, didampingi 2 rival untuk P2 dan P3.
2. **Implementasi Node `KineticStandee3D` & Shader Bayangan Nyata:**
   * Membuat komponen 2.5D `KineticStandee3D` berbasis `QuadMesh` 3D.
   * Mengaktifkan *shadow pass* (`cast_shadow = SHADOW_CASTING_SETTING_ON`) agar karakter menjatuhkan bayangan nyata ke lantai podium 3D.
   * Shader `kinetic_standee.gdshader` mendukung pencahayaan lampu sorot (*diffuse spotlight*) dan *rim lighting* neon sesuai warna tema tim.
   * Animasi pernapasan prosedural (*breathing loop*) dan partikel hologram AR kanji `勝者` (*WINNER*) melayang di belakang karakter.
3. **Membangun Scene Studio Panggung Podium 3D (`winning_scene.tscn`):**
   * Panggung podium 3 undak (P1 tengah $0.8\text{ m}$, P2 kiri $0.5\text{ m}$, P3 kanan $0.3\text{ m}$) berbahan marmer hitam mengilap dengan trim neon emas, perak, dan perunggu.
   * *Turntable* berputar lambat di belakang podium yang memuat sasis 3D mobil pemenang P1 secara dinamis (`assets/cars/<car_slug>/<car_slug>_full.glb`).
   * Trofi piala emas kejuaraan 3D di atas pedestal panggung P1.
   * Efek partikel confetti emas berjatuhan dan kabut panggung atmosferik.
4. **Fitur Toggle Leaderboard (`[TAB]`) & Photo Mode UX:**
   * Tampilan awal bersih dan sinematik (nama juara, tim, waktu, tombol navigasi).
   * Menekan tombol **`[TAB]`** memicu animasi *smooth manga slide-in* papan klasemen 20 pembalap lengkap dengan waktu, fastest lap (+1 PT bonus ungu), dan poin konstruktor.
   * Menutup leaderboard mengaktifkan pergerakan kamera *slow orbit dolly* yang estetik untuk tangkapan layar (*Photo Mode*).
5. **Integrasi Game Loop & Pengujian Headless:**
   * Menghubungkan akhir balapan di `race_weekend_world.gd` agar beralih ke `winning_scene.tscn`.
   * Memastikan tombol `EXIT TO HQ` kembali ke menu utama dengan **0 orphan nodes**.
   * Menulis test suite otomatis `tests/test_winning_scene_and_standee.gd` (100% PASS) dan memastikan seluruh 35 test suite lama tetap PASS.

---

## 2. Technical Constraints & Rules of Engagement

1. **ATURAN #1 (Anti-Kerusakan):** Dilarang menghapus atau mengubah file mentah di `reference-assets/characters/`. Seluruh hasil olahan standee disimpan di `assets/characters/standees/`.
2. **Karakter 2.5D, Bukan 3D Biped Rig:** Karakter pembalap diwujudkan dalam `KineticStandee3D` (QuadMesh + shader + tween kinetik), bukan skeletal animation 3D poligon tinggi.
3. **Dynamic Winner Car Loading:** Mobil di atas turntable wajib dimuat secara dinamis dari `assets/cars/<car_slug>/<car_slug>_full.glb` berdasarkan pemenang P1 balapan.
4. **Target Performa 60 FPS:** Scene studio harus ringan dan bebas dari lag (frame time $\le 16.66\text{ ms}$, locked 60 FPS pada 1080p High).
5. **Zero Memory Leak:** Seluruh node 3D, partikel confetti, dan tekstur wajib dibebaskan saat scene ditutup (`0 orphan nodes`).

---

## 3. Step-by-Step Implementation Guide

### Task 1: Otomasi Cutout Karakter (`scratch/process_character_cutout.py`)
1. Buat skrip Python `scratch/process_character_cutout.py` dengan dependensi Pillow & NumPy:
   - Baca gambar sumber: `reference-assets/characters/apex-racing/kaze-ryu/full_body_concept.png`.
   - Latar belakang studio abu-abu memiliki nilai piksel seragam di sekitar `(168, 168, 168)`.
   - Gunakan algoritma *flood-fill / color distance thresholding* dengan boundary anti-aliasing:
     ```python
     # Contoh logika thresholding:
     bg_color = np.array([168, 168, 168])
     dist = np.linalg.norm(arr[:, :, :3] - bg_color, axis=2)
     alpha = np.clip((dist - 8.0) * 15.0, 0, 255).astype(np.uint8)
     ```
   - Pastikan garis luar tinta manga hitam tetap tajam dan tidak pudar.
2. Simpan hasilnya ke direktori baru: `assets/characters/standees/kaze_ryu.png` (RGBA, ukuran asli 768×1376).
3. Buat juga cutout untuk 2 rival:
   - `assets/characters/standees/makoto_ito.png` (dari `reference-assets/characters/neon-drift/makoto-ito/full_body_concept.png`).
   - `assets/characters/standees/arthur_sterling.png` (dari `reference-assets/characters/zephyr-racing/arthur-sterling-jr/full_body_concept.png`).

---

### Task 2: Implementasi `KineticStandee3D` & Shader Bayangan
1. Buat shader `shaders/kinetic_standee.gdshader`:
   - `shader_type spatial; render_mode depth_draw_opaque, cull_disabled;`
   - Uniforms: `albedo_texture`, `team_color`, `rim_color`, `rim_intensity`.
   - Hitung alpha scissor atau alpha blend dengan *depth testing*.
   - Tambahkan *manga hard rim light* di tepi siluet karakter.
2. Buat skrip kelas `scripts/ui/kinetic_standee_3d.gd` (`class_name KineticStandee3D extends Node3D`):
   - Tambahkan child `MeshInstance3D` dengan `QuadMesh` ($1.85\text{ m} \times 1.05\text{ m}$).
   - Set `mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON`.
   - Pasang material `ShaderMaterial` dengan shader `kinetic_standee.gdshader`.
   - Buat tween animasi bernapas prosedural (`_setup_breathing()`):
     - Tween skala Y: $1.0 \to 1.015 \to 1.0$ (periode $2.4\text{ s}$, `TRANS_SINE`).
   - Tambahkan sistem partikel hologram kanji melayang di belakang karakter (`勝者` atau petir anime).

---

### Task 3: Scene Panggung Podium Studio 3D (`scenes/ui/winning_scene.tscn`)
1. Buat scene `scenes/ui/winning_scene.tscn` dengan root `Node3D` dan skrip `scripts/ui/winning_scene.gd`.
2. Struktur lingkungan 3D:
   - **Podium Platform 3D:**
     - P1 (tengah): Posisi `Vector3(0, 0.4, 0)`, ukuran `Vector3(1.6, 0.8, 1.4)`, marmer hitam + trim emas.
     - P2 (kiri): Posisi `Vector3(-1.8, 0.25, 0)`, ukuran `Vector3(1.4, 0.5, 1.3)`, trim perak.
     - P3 (kanan): Posisi `Vector3(1.8, 0.15, 0)`, ukuran `Vector3(1.4, 0.3, 1.3)`, trim perunggu.
   - **P1 Hero Car Turntable:**
     - Cylinder mesh $6.5\text{ m}$ di posisi `Vector3(0, 0.05, -4.5)`.
     - Skrip memutar turntable lambat: `rotation.y += 0.06 * delta`.
     - Slot node `CarSlot` untuk menampung instansiasi model mobil GT3 pemenang.
   - **Trofi 3D:**
     - Pedestal di depan tangga P1 dengan model piala emas 3D bersayap GT3.
   - **Lighting & VFX:**
     - Directional light lembut + 3 Spotlights volumetrik mengarah ke P1, P2, P3.
     - `GPUParticles3D` confetti emas berjatuhan dari atas.
3. Di `winning_scene.gd`, implementasikan fungsi `setup_celebration(results: Dictionary)`:
   - Ambil pemenang P1, P2, P3 dari `results["order"]`.
   - Tempatkan `KineticStandee3D` pada masing-masing tangga dengan tekstur standee dan warna tim yang tepat.
   - Ambil slug mobil pemenang P1 dan muat `res://assets/cars/<slug>/<slug>_full.glb` ke turntable.

---

### Task 4: UI Minimalis & Toggle Leaderboard (`[TAB]`)
1. Di `winning_scene.tscn`, tambahkan child `CanvasLayer` untuk lapisan antarmuka bergaya neo-brutalism:
   - **Elemen Tampilan Clean:**
     - Header atas: `/// LA VOITURE // CHAMPIONSHIP PODIUM`.
     - 3 Kartu nama pembalap di bagian bawah layar (posisi, nama, tim, waktu finis).
     - Tombol navigasi bawah:
       - `[TAB] /// SHOW LEADERBOARD`
       - `[R] /// RESTART RACE`
       - `[ESC] /// EXIT TO HQ`
   - **Panel Expanded (Timing Tower):**
     - Panel meluncur dari sisi kanan layar (`position.x: 1920 -> 1320`).
     - Berisi daftar 20 pembalap, gap waktu, lap tercepat (+1 PT ungu), dan poin tim.
2. Tambahkan logika toggle di `_unhandled_input(event)`:
   - Tombol `KEY_TAB` atau klik tombol toggle mengubah state `is_leaderboard_open`.
   - Jalankan tween transisi slide-in / slide-out halus (durasi $0.25\text{ s}$, `TRANS_QUAD`).
   - Saat leaderboard tertutup, kamera studio melakukan gerakan *slow cinematic orbit dolly* mengelilingi podium.

---

### Task 5: Integrasi Game Loop, Automated Test Suite & Verifikasi
1. Buka [`scripts/world/race_weekend_world.gd`](file:///D:/Occupation/Porto/genex/La_Voiture/scripts/world/race_weekend_world.gd):
   - Pada saat balapan finis dan selebrasi bendera finis selesai, ganti pemunculan podium lama dengan transisi menuju `scenes/ui/winning_scene.tscn`.
   - Operkan paket data hasil balapan (`order`, `winner_car`, `team_points`, `fastest_lap`).
2. Buat test suite baru `tests/test_winning_scene_and_standee.gd`:
   - Validasi keberadaan file standee RGBA transparan.
   - Validasi instansiasi `KineticStandee3D` dan aktivasi shadow casting.
   - Validasi panggung podium, turntable mobil P1, dan trofi 3D.
   - Validasi fungsi toggle leaderboard `[TAB]` (state show/hide).
   - Validasi alur `exit_requested` kembali ke menu utama dengan 0 orphan node.
3. Jalankan seluruh 36 test suite via `godot --headless`:
   ```powershell
   Get-ChildItem tests\test_*.gd | ForEach-Object { godot --headless --path . -s "res://tests/$($_.Name)" }
   ```
   **Target: 36/36 SUITES PASS (100% PASS, 0 FAIL).**
4. Jalankan smoke test native 1080p High Preset (`scratch/smoke_winning_scene.gd`):
   - Ukur frame rate (wajib terkunci 60 FPS, frame time $\le 16.66\text{ ms}$).
   - Ambil tangkapan layar verifikasi 1080p ke `executor-report/screenshots/winning_scene/`.
   - Terbitkan laporan resmi di `executor-report/reports/FASE-11-LANGKAH-7-WINNING-SCENE-REPORT.md`.

---

## 4. Definition of Done & Verification Criteria

Pekerjaan dinyatakan **SELESAI** jika dan hanya jika:
1. **Pipeline Standee 2.5D:** Minimal 3 file PNG transparan (`kaze_ryu.png`, `makoto_ito.png`, `arthur_sterling.png`) berhasil dibuat di `assets/characters/standees/` dengan tepi tinta bersih.
2. **Visual Panggung Studio:** Panggung podium 3 undak, sasis mobil P1 berputar di turntable, trofi emas 3D, dan confetti emas ter-render sempurna di `winning_scene.tscn`.
3. **Shadow & Kinetik:** Karakter menjatuhkan bayangan nyata ke lantai podium, bergerak bernapas halus, dan dikelilingi partikel kanji hologram.
4. **Fitur Toggle Leaderboard:** Tombol `[TAB]` menyembunyikan/menampilkan tabel waktu secara mulus tanpa menutupi pandangan sinematik utama secara permanen.
5. **Zero Regression:** 36/36 test suite berstatus **100% PASS (0 FAIL)** di Godot headless.
6. **Performa:** 60 FPS terkunci pada 1080p High, **0 orphan nodes** saat keluar ke HQ.
7. **Dokumentasi:** Laporan resmi `FASE-11-LANGKAH-7-WINNING-SCENE-REPORT.md` terbit beserta bukti tangkapan layar visual native 1080p.
