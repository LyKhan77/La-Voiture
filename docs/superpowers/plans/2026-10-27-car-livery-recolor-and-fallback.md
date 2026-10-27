# GT3 Car Livery Recoloring & Fallback System Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Menyelaraskan warna livery seluruh mobil GT3 ke identitas tema tim resmi (*La Voiture*) menggunakan direct PBR texture recoloring dengan proteksi detail (carbon, kaca, lampu), serta menyediakan tool CLI fallback satu-perintah untuk mengembalikan ke livery original kapan saja.

**Architecture:** 
1. Tool CLI Python `tools/manage_car_livery.py` untuk mengelola backup (`base_color_original.png`), status livery aktif, dan fungsi switch `apply` / `restore` secara per-mobil maupun global.
2. Pipeline recoloring `tools/recolor_car_texture.py` berbasis transformasi HSV dengan seleksi saturasi & luminansi untuk menjaga detail material non-cat.
3. Penerapan bertahap untuk Priority 1 (5 mobil mismatched kontras) dan Priority 2 (5 mobil penyesuaian aksen), dengan 3 mobil baru (Ferrari, Mustang, Supra) tetap dipertahankan.

**Tech Stack:** Python 3.12 (Pillow, NumPy), Godot Engine 4.7.2 stable (GDScript, headless testing), PowerShell.

---

### Task 1: Livery Management & Fallback CLI Tool

**Files:**
- Create: `tools/manage_car_livery.py`
- Test: `tests/test_manage_car_livery.py`

- [ ] **Step 1: Write unit test for livery manager**
  Tulis `tests/test_manage_car_livery.py` untuk menguji:
  - Deteksi dan pembuatan backup `base_color_original.png` jika belum ada.
  - Pengalihan file `base_color.png` saat `apply` (memakai `base_color_team.png`) dan saat `restore` (memakai `base_color_original.png`).
  - Penanganan flag `--car <slug>` dan `--all`.

- [ ] **Step 2: Run test to verify it fails**
  Run: `python tests/test_manage_car_livery.py`
  Expected: FAIL (`manage_car_livery.py` not found).

- [ ] **Step 3: Implement `tools/manage_car_livery.py`**
  Implementasikan skrip CLI dengan fungsi:
  - `backup_original(car_slug: str)`
  - `apply_team_livery(car_slug: str)`
  - `restore_original_livery(car_slug: str)`
  - Argparse support: `--action [apply|restore|status]`, `--car [slug]`, `--all`.

- [ ] **Step 4: Run test to verify it passes**
  Run: `python tests/test_manage_car_livery.py`
  Expected: PASS.

- [ ] **Step 5: Commit**
  ```bash
  git add tools/manage_car_livery.py tests/test_manage_car_livery.py
  git commit -m "feat(tools): add car livery manager with backup and fallback support"
  ```

---

### Task 2: Precision Texture Recoloring Pipeline

**Files:**
- Create: `tools/recolor_car_texture.py`
- Test: `tests/test_recolor_car_texture.py`

- [ ] **Step 1: Write unit test for recolor pipeline**
  Tulis `tests/test_recolor_car_texture.py` untuk menguji:
  - Isolasi piksel warna berdasarkan rentang Hue ($0^\circ - 360^\circ$) dan threshold saturasi.
  - Proteksi area netral ($S < 0.15$) seperti serat karbon, kaca, dan chrome.
  - Preservasi luminansi asli (menjaga kontur bayangan 3D).

- [ ] **Step 2: Run test to verify it fails**
  Run: `python tests/test_recolor_car_texture.py`
  Expected: FAIL (`recolor_car_texture.py` not found).

- [ ] **Step 3: Implement `tools/recolor_car_texture.py`**
  Implementasikan algoritma transformasi ruang warna NumPy/Pillow:
  - Fungsi `recolor_texture(src_path, out_path, src_hue, hue_tol, target_hex, sat_mult=1.0, val_mult=1.0, preserve_dark=True)`
  - Konfigurasi parameter warna presisi per model mobil.

- [ ] **Step 4: Run test to verify it passes**
  Run: `python tests/test_recolor_car_texture.py`
  Expected: PASS.

- [ ] **Step 5: Commit**
  ```bash
  git add tools/recolor_car_texture.py tests/test_recolor_car_texture.py
  git commit -m "feat(tools): add precision HSV car texture recoloring pipeline"
  ```

---

### Task 3: Execute Recoloring on Priority 1 Cars (Mismatched)

**Files:**
- Modify/Create in `assets/cars/<slug>/textures/`:
  - `assets/cars/aston_vantage/textures/`: `base_color_original.png`, `base_color_team.png`, `base_color.png`
  - `assets/cars/lambo_huracan/textures/`: `base_color_original.png`, `base_color_team.png`, `base_color.png`
  - `assets/cars/mclaren_720s/textures/`: `base_color_original.png`, `base_color_team.png`, `base_color.png`
  - `assets/cars/lexus_rcf/textures/`: `base_color_original.png`, `base_color_team.png`, `base_color.png`
  - `assets/cars/bmw_m4/textures/`: `base_color_original.png`, `base_color_team.png`, `base_color.png`

- [ ] **Step 1: Backup original textures for 5 Priority 1 cars**
  Jalankan backup otomatis ke `base_color_original.png` untuk:
  - `aston_vantage`
  - `lambo_huracan`
  - `mclaren_720s`
  - `lexus_rcf`
  - `bmw_m4`

- [ ] **Step 2: Generate recolored textures (`base_color_team.png`)**
  Jalankan pipeline untuk:
  - Aston Martin $\rightarrow$ Electric Magenta (`#D946EF`)
  - Lamborghini $\rightarrow$ Ultra Violet (`#9B5CFF`)
  - McLaren $\rightarrow$ Mint Emerald Green (`#00E08A`)
  - Lexus RC F $\rightarrow$ Snow White (`#F4F5F7`)
  - BMW M4 $\rightarrow$ Cyber Yellow (`#FFE600`) & Vanta Black

- [ ] **Step 3: Apply team textures to `base_color.png`**
  Aktifkan `base_color_team.png` menjadi `base_color.png`.

- [ ] **Step 4: Verify Priority 1 cars in Godot headless**
  Jalankan chassis unit tests:
  - `godot --headless --path . -s res://tests/test_aston_vantage_chassis.gd`
  - `godot --headless --path . -s res://tests/test_lambo_huracan_chassis.gd`
  - `godot --headless --path . -s res://tests/test_mclaren_720s_chassis.gd`
  - `godot --headless --path . -s res://tests/test_lexus_rcf_chassis.gd`
  - `godot --headless --path . -s res://tests/test_bmw_m4_chassis.gd`
  Expected: 100% PASS.

- [ ] **Step 5: Commit**
  ```bash
  git add assets/cars/aston_vantage/ assets/cars/lambo_huracan/ assets/cars/mclaren_720s/ assets/cars/lexus_rcf/ assets/cars/bmw_m4/
  git commit -m "feat(cars): apply official team livery recolor for Priority 1 GT3 cars"
  ```

---

### Task 4: Execute Recoloring on Priority 2 Cars & Register All Cars

**Files:**
- Modify/Create in `assets/cars/<slug>/textures/`:
  - `assets/cars/chevy_corvette/textures/`
  - `assets/cars/audi_r8/textures/`
  - `assets/cars/mercedes_amg/textures/`
  - `assets/cars/nissan_gtr/textures/`
  - `assets/cars/honda_nsx/textures/`
  - `assets/cars/ferrari_296/textures/` (backup original only)
  - `assets/cars/ford_mustang/textures/` (backup original only)
  - `assets/cars/toyota_supra/textures/` (backup original only)

- [ ] **Step 1: Backup and generate team textures for Priority 2 cars**
  - Chevy Corvette $\rightarrow$ Blaze Orange (`#FF7A00`)
  - Audi R8 $\rightarrow$ Electric Cyan (`#00F0FF`) striping
  - Mercedes-AMG $\rightarrow$ Acid Lime (`#CCFF00`) accents
  - Nissan GT-R $\rightarrow$ Anime Crimson (`#FF1E56`) accents
  - Honda NSX $\rightarrow$ Cobalt Blue (`#3D7BFF`) accents

- [ ] **Step 2: Create original backups for 3 matching cars (Ferrari, Mustang, Supra)**
  Pastikan `base_color_original.png` dan `base_color_team.png` ada di seluruh 13 mobil agar command fallback `--all` bekerja 100% seragam.

- [ ] **Step 3: Verify all 13 chassis in Godot headless**
  Jalankan chassis tests untuk seluruh 13 mobil:
  - `Get-ChildItem tests/test_*_chassis.gd | ForEach-Object { godot --headless --path . -s "res://tests/$($_.Name)" }`
  Expected: 13/13 PASS.

- [ ] **Step 4: Commit**
  ```bash
  git add assets/cars/
  git commit -m "feat(cars): complete livery recoloring for all GT3 teams with full fallback registry"
  ```

---

### Task 5: End-to-End Verification & Quality Assurance (DoD)

**Files:**
- Run test runner: `scratch/run_all_tests.ps1`
- Run garage launch verification: `scratch/test_garage_launch.gd`

- [ ] **Step 1: Test fallback switch mechanism**
  Jalankan `python tools/manage_car_livery.py --action restore --all` $\rightarrow$ verifikasi semua mobil kembali ke original.  
  Jalankan `python tools/manage_car_livery.py --action apply --all` $\rightarrow$ verifikasi semua mobil kembali ke team livery.

- [ ] **Step 2: Zero Regression Test (Full 42 Test Suites)**
  Run: `powershell -ExecutionPolicy Bypass -File scratch/run_all_tests.ps1`
  Expected: **42 PASSED, 0 FAILED**.

- [ ] **Step 3: In-Engine Garage & Grid Launch Smoke Test**
  Run: `godot --headless --path . -s scratch/test_garage_launch.gd`
  Expected: PASS tanpa error dan 0 crash.

- [ ] **Step 4: Commit and update ROADMAP.md**
  Update status penyelarasan livery di `ROADMAP.md`.
  Commit:
  ```bash
  git add ROADMAP.md
  git commit -m "docs: update roadmap with completed team livery recoloring and fallback support"
  ```
