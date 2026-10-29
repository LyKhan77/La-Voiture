# Rencana Implementasi: Langkah 1 — Pipeline Mercedes-AMG GT3 Evo & Transisi Official FIA Safety Car

**Status:** SIAP DIEKSEKUSI  
**Target Engine:** Godot Engine 4.7.2 stable  
**Spesifikasi Desain:** [2026-10-23-langkah-1-mercedes-amg-gt3-and-safety-car-design.md](file:///D:/Occupation/Porto/genex/La_Voiture/docs/superpowers/specs/2026-10-23-langkah-1-mercedes-amg-gt3-and-safety-car-design.md)  
**Tanggal:** 2026-10-23  

---

## 1. Rincian Tugas Bertahap (Task Breakdown)

### Task 1.1: Rekonstruksi 3D Mentah Mercedes-AMG GT3 via Meshy AI
* **Input:** [`reference-assets/cars/mercedes-amg-gt3/front.png`](file:///D:/Occupation/Porto/genex/La_Voiture/reference-assets/cars/mercedes-amg-gt3/front.png) dan [`back.png`](file:///D:/Occupation/Porto/genex/La_Voiture/reference-assets/cars/mercedes-amg-gt3/back.png)
* **Eksekusi:** Panggil MCP `meshy_multi_image_to_3d` dengan:
  * `ai_model`: `latest` (Meshy 7.1)
  * `file_paths`: path absolut ke `front.png` dan `back.png`
  * `enable_pbr`: `true` (menghasilkan metallic, roughness, normal map)
  * `texture_resolution`: `4k`
* **Output:** Unduh ke `assets/cars/mercedes_amg/raw/mercedes_amg_raw.glb` dan tekstur PBR ke `assets/cars/mercedes_amg/textures/`.
* **Verifikasi:** Daftarkan file raw GLB ke Git LFS (`git lfs track`).

---

### Task 1.2: Konfigurasi Parameter Fisik & Headless Blender Refining
* **File Konfigurasi:** Buat [`scratch/car_configs/mercedes_amg.json`](file:///D:/Occupation/Porto/genex/La_Voiture/scratch/car_configs/mercedes_amg.json) dengan parameter FIA GT3:
  * Dimensi: $L = 4.55\text{ m}$, $W \approx 2.06\text{ m}$, $H \approx 1.24\text{ m}$.
  * Target triangle: ~105.000 tris.
  * Fender lift: `auto` / manual offset untuk mencegah ban menyembul.
  * Wheel cut boolean: $R_{\text{arch}} = 0.372\text{ m}$, $R_{\text{tub}} = 0.369\text{ m}$.
* **Eksekusi Pipeline:** Jalankan perakitan bodi via `powershell -File scratch/make_car.ps1 -Car mercedes_amg`.
* **Output:**
  * Bodi biner: `assets/cars/mercedes_amg/mercedes_amg_body.glb` (2 surface: `Paint` + `FenderLinerMat`).
  * Full car assembled: `assets/cars/mercedes_amg/mercedes_amg_full.glb`.
* **Verifikasi Gate:** Jalankan headless fitment checker `godot --headless --path . -s scratch/fit_cars.gd` (wajib LOLOS 0 penetration, clearance 2.5–5.0 cm, flush outer).

---

### Task 1.3: Scene Sasis Godot & Universal Sockets
* **Scene Sasis:** Buat [`scenes/car/mercedes_amg_chassis.tscn`](file:///D:/Occupation/Porto/genex/La_Voiture/scenes/car/mercedes_amg_chassis.tscn) berbasis `ModularCarAssembler`:
  * Node `Body`: memuat `mercedes_amg_body.glb` dengan material `toon_car_paint.gdshader` + `inverted_hull_outline.gdshader`.
  * Node Universal Sockets: `Wheel_FL`, `Wheel_FR`, `Wheel_RL`, `Wheel_RR`, `Cockpit`, `Exhaust_L`, `Exhaust_R`.
  * Node `Lamps`: Headlight & Taillight reactive box slabs untuk pengereman & malam hari.
* **Integrasi Runtime:**
  * Daftarkan ke [`scripts/car/gt_car_actor.gd`](file:///D:/Occupation/Porto/genex/La_Voiture/scripts/car/gt_car_actor.gd):
    ```gdscript
    const CHASSIS_BY_TEAM: Dictionary = {
        0: preload("res://scenes/car/mercedes_amg_chassis.tscn"), # Apex Racing
        1: preload("res://scenes/car/audi_r8_chassis.tscn"),
        ...
    }
    ```
  * Selaraskan showroom garasi di [`scripts/world/garage/garage_environment_builder.gd`](file:///D:/Occupation/Porto/genex/La_Voiture/scripts/world/garage/garage_environment_builder.gd) agar Stall 0 memuat sasis Mercedes-AMG.

---

### Task 1.4: Rekayasa Official FIA Safety Car
* **Scene Safety Car:** Buat [`scenes/car/safety_car_chassis.tscn`](file:///D:/Occupation/Porto/genex/La_Voiture/scenes/car/safety_car_chassis.tscn) meminjam geometri bodi Porsche 911 GT3:
  * Cat bodi: Iridium Silver metallized toon paint dengan striping kuning neon FIA.
  * Rooftop LED Lightbar:
    * Komponen mesh aerodinamis dengan 4 lampu strobo amber (flashing 12 Hz saat fase `DEPLOYED`) dan 2 lampu hijau (menyala saat `IN_THIS_LAP`).
  * Lampu strobo depan pada grille.
* **Integrasi VFX & Sim:**
  * Perbarui [`scripts/vfx/race_vfx.gd`](file:///D:/Occupation/Porto/genex/La_Voiture/scripts/vfx/race_vfx.gd) fungsi `_build_safety_car()` agar menggunakan `safety_car_chassis.tscn` langsung.
  * Sinkronkan lampu lightbar dengan state `race.safety_car.phase`.

---

### Task 1.5: Automated Testing & Verifikasi Penuh
* **Unit Test Baru:** Buat [`tests/test_mercedes_amg_chassis.gd`](file:///D:/Occupation/Porto/genex/La_Voiture/tests/test_mercedes_amg_chassis.gd) (18 asersi validasi dimensi, geometri, material, wheel sockets, dan clearance).
* **Test Safety Car:** Pastikan [`tests/test_car_dynamics_vfx.gd`](file:///D:/Occupation/Porto/genex/La_Voiture/tests/test_car_dynamics_vfx.gd) memvalidasi Safety Car baru dengan status lightbar amber/hijau.
* **Zero Regression Test:** Jalankan seluruh 26 test suite (`tests/test_*.gd`) dan pastikan **100% PASS (0 FAIL)**.
* **Tangkapan Layar & Dokumentasi:** Simpan screenshot close-up sasis Mercedes-AMG dan Safety Car di `executor-report/screenshots/`.
