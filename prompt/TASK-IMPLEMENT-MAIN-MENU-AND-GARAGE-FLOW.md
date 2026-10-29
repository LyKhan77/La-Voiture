# TASK SPECIFICATION: IMPLEMENTASI MAIN MENU, RACE SETUP, 3D GARAGE & MANGA TRANSITION FLOW

**Task ID:** `TASK-IMPLEMENT-MAIN-MENU-AND-GARAGE-FLOW`  
**Assignee:** Senior Godot 4 Gameplay & UI/UX Technical Artist  
**Priority:** High (Completing Game Presentation Loop & Pre-Race Flow)  
**Dokumen Desain (Spec):** [`docs/superpowers/specs/2026-10-22-main-menu-and-garage-flow-design.md`](file:///D:/Occupation/Porto/genex/La_Voiture/docs/superpowers/specs/2026-10-22-main-menu-and-garage-flow-design.md)  
**Rencana Implementasi (Plan):** [`docs/superpowers/plans/2026-10-22-main-menu-and-garage-flow-plan.md`](file:///D:/Occupation/Porto/genex/La_Voiture/docs/superpowers/plans/2026-10-22-main-menu-and-garage-flow-plan.md)  
**Godot Console:** `C:\Users\Lee\Downloads\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe`

---

## 1. Tujuan & Ringkasan Fitur

Tugas Anda adalah mengimplementasikan antarmuka lengkap sebelum balapan (*Pre-Race Flow*) pada proyek game **La Voiture** di Godot 4:
1. **Model Data (`RaceConfigData`):** Struktur data singleton/ref untuk membawa pilihan pemain dari menu ke simulasi trek.
2. **Main Menu (`scenes/ui/main_menu.tscn`):** Layar menu utama bergaya Neo-Brutalism Manga (`EXHIBITION RACE`, `CAREER MODE [Coming Soon]`, `SETTINGS`, `CREDITS`, `QUIT`).
3. **Modal Settings (`scenes/ui/settings_modal.tscn`):** Pengaturan Display, Graphics Presets (Low, Med, High, Ultra), V-Sync, dan 5 Bus Audio (`Master`, `Music`, `SFX`, `Radio`, `UI`).
4. **Race Setup (`scenes/ui/race_setup_menu.tscn`):** Pilihan Sirkuit (Apex Ring International + Coming Soon), jumlah Lap (3, 5, 10), Cuaca (Sunny, Threatening, Wet, Monsoon), dan Waktu Balapan (Day, Sunset, Night).
5. **3D Pitstop Garage (`scenes/ui/garage_team_select.tscn`):**
   - 10-stall pit lane berlantai dark epoxy mengilap dengan garis hazard dan nomor stall.
   - Kamera Dolly Track meluncur mulus antar-stall ($X$-lerp cubic ease-out) saat pemain berganti tim.
   - Panggung orbit mobil 360° menggunakan aset `assets/cars/<car_slug>/<car_slug>_full.glb`.
   - UI Overlay memuat **Kartu Duo Pembalap 2D** (`reference-assets/characters/<team>/<driver>/radio_portrait.png`), spesifikasi tim, dan pilihan kompon ban awal (*Team Principal Mode* — Mobil 1 & 2 independen).
6. **Manga Comic Transition (`scenes/ui/manga_race_transition.tscn`):**
   - Efek 1-frame *Negative Snap-Invert* + 3 bilah panel komik manga dengan garis aksi *speedlines* + *halftone wipe* membuka ke garis start sirkuit 3D.
7. **Integrasi Penuh:**
   - `scenes/main.tscn` memuat `main_menu.tscn` secara default.
   - `RaceWeekendWorld` membaca `RaceConfigData` untuk mengatur tim pemain, ban awal, cuaca, dan lap.
   - Tombol "Exit to HQ" di `podium_screen.tscn` kembali ke `main_menu.tscn`.

---

## 2. Aset yang Sudah Tersedia & Siap Pakai

Semua aset pendukung telah tersedia lengkap di proyek:
* **Aset Mobil Utuh (Bodi + 4 Roda Master):**
  - `assets/cars/porsche_911/porsche_911_full.glb`
  - `assets/cars/audi_r8/audi_r8_full.glb`
  - `assets/cars/nissan_gtr/nissan_gtr_full.glb`
  - `assets/cars/aston_vantage/aston_vantage_full.glb`
  - `assets/cars/bmw_m4/bmw_m4_full.glb`
  - `assets/cars/lambo_huracan/lambo_huracan_full.glb`
  - `assets/cars/honda_nsx/honda_nsx_full.glb`
  - `assets/cars/chevy_corvette/chevy_corvette_full.glb`
  - `assets/cars/lexus_rcf/lexus_rcf_full.glb`
  - `assets/cars/mclaren_720s/mclaren_720s_full.glb`
* **Potret 2D Duo Pembalap (1024x1024 Anime Radio):**
  - Seluruh 20 pembalap tersedia di `reference-assets/characters/<team-slug>/<driver-slug>/radio_portrait.png`.
* **Kanon Statistik Pembalap:**
  - Data atribut Pace, Tire Management, dan Wet Mastery tersedia di [`reference-assets/characters/DRIVER-CHARACTERIZATION-ROSTER.md`](file:///D:/Occupation/Porto/genex/La_Voiture/reference-assets/characters/DRIVER-CHARACTERIZATION-ROSTER.md).
* **Shader & Komponen Pendukung:**
  - Toon Shaders: `shaders/toon_car_paint.gdshader`, `shaders/anime_cel_shaded.gdshader`, `shaders/inverted_hull_outline.gdshader`.
  - Audio Manager: `scripts/audio/audio_manager.gd` (Autoload `Audio`).

---

## 3. Langkah Pengerjaan Detail

Silakan ikuti dan eksekusi tahapan pada rencana implementasi:
[`docs/superpowers/plans/2026-10-22-main-menu-and-garage-flow-plan.md`](file:///D:/Occupation/Porto/genex/La_Voiture/docs/superpowers/plans/2026-10-22-main-menu-and-garage-flow-plan.md)

1. **Tahap 1:** Buat `scripts/core/race_config_data.gd` dan `scenes/ui/settings_modal.tscn` (beserta skripnya).
2. **Tahap 2:** Bangun `scenes/ui/main_menu.tscn` dan `scenes/ui/race_setup_menu.tscn`.
3. **Tahap 3:** Bangun `scripts/world/garage/garage_environment_builder.gd`, `scripts/ui/garage_car_orbit.gd`, dan scene `scenes/ui/garage_team_select.tscn`.
4. **Tahap 4:** Bangun `scenes/ui/manga_race_transition.tscn`, hubungkan ke `scenes/main.tscn`, `scripts/world/weekend/race_weekend_world.gd`, dan `scenes/ui/podium_screen.tscn`.
5. **Tahap 5:** Buat unit test `tests/test_main_menu_flow.gd` dan jalankan verifikasi headless penuh.

---

## 4. Kriteria Kelulusan & Verifikasi

1. **Test Headless Mandiri:**
   ```powershell
   & "C:\Users\Lee\Downloads\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe" --headless --path . -s tests/test_main_menu_flow.gd
   ```
   **Syarat:** 100% PASS (0 FAIL).

2. **Test Bebas Regresi (Full Project Suite):**
   ```powershell
   & "C:\Users\Lee\Downloads\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe" --headless --path . -s tests/test_modular_car.gd
   & "C:\Users\Lee\Downloads\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe" --headless --path . -s tests/test_audio_and_race_weekend.gd
   ```
   **Syarat:** Seluruh test suite lama tetap 100% PASS (0 FAIL).

3. **Verifikasi Visual:**
   - Pastikan navigasi antar-layar mulus, perpindahan kamera garasi 10 stall bebas stutter di 60 FPS, kartu pembalap 2D tampil tajam, dan transisi komik manga berjalan dramatis saat menuju start balapan.
