# TASK HANDOFF: Langkah 1 — Pipeline Mercedes-AMG GT3 Evo & Transisi Official FIA Safety Car

**Branch/Target:** `main`  
**Engine:** Godot Engine 4.7.2 stable  
**Role:** Senior 3D Pipeline, Vehicle Dynamics & VFX Engineer  
**Reference Documents:**
- Design Spec: [`docs/superpowers/specs/2026-10-23-langkah-1-mercedes-amg-gt3-and-safety-car-design.md`](file:///D:/Occupation/Porto/genex/La_Voiture/docs/superpowers/specs/2026-10-23-langkah-1-mercedes-amg-gt3-and-safety-car-design.md)
- Implementation Plan: [`docs/superpowers/plans/2026-10-23-langkah-1-mercedes-amg-gt3-and-safety-car-plan.md`](file:///D:/Occupation/Porto/genex/La_Voiture/docs/superpowers/plans/2026-10-23-langkah-1-mercedes-amg-gt3-and-safety-car-plan.md)
- Visual Reference Showcase: [`MERCEDES-AMG-GT3-REFERENCE-SHOWCASE.md`](file:///C:/Users/Lee/.gemini/antigravity-cli/brain/811c31b7-0204-457f-88fa-74a528b6c84e/MERCEDES-AMG-GT3-REFERENCE-SHOWCASE.md)
- Reference Images:
  - Front Isometric: [`reference-assets/cars/mercedes-amg-gt3/front.png`](file:///D:/Occupation/Porto/genex/La_Voiture/reference-assets/cars/mercedes-amg-gt3/front.png)
  - Rear Isometric: [`reference-assets/cars/mercedes-amg-gt3/back.png`](file:///D:/Occupation/Porto/genex/La_Voiture/reference-assets/cars/mercedes-amg-gt3/back.png)

---

## 1. Context & Objectives

Di **Langkah 1**, Anda bertugas mengeksekusi dua perombakan besar kendaraan:
1. **Membangun Sasis Baru Tim 0 (Apex Racing: Kaze Ryu & Sora Ren): Mercedes-AMG GT3 Evo**
   - Menggantikan mobil Porsche dasar yang sebelumnya digunakan oleh Tim 0.
   - Menggunakan referensi visual isometrik stylized yang sudah di-generate via Meshy AI.
   - Melewati gerbang fitment roda (`scratch/fit_cars.gd`) dengan standar: 0 penetrasi roda master ($R = 0.33\text{ m}$), ground clearance $\ge +0.04\text{ m}$, celah spakbor 2.5–5.0 cm, dan flush $\le 1.5\text{ cm}$.
2. **Mentransformasikan Porsche 911 GT3 Menjadi Official FIA Safety Car:**
   - Membangun `scenes/car/safety_car_chassis.tscn` dari geometri Porsche 911 GT3 dengan livery keselamatan resmi (perak/hitam metalik dengan chevron hazard kuning neon + teks tebal `SAFETY CAR`).
   - Membuat komponen 3D Rooftop Strobe Lightbar aerodinamis yang reaktif:
     - Fase `DEPLOYED`: 4 LED amber/oranye berkedip bergantian pada frekuensi tinggi 10–12 Hz.
     - Fase `IN_THIS_LAP`: Strobo amber mati, lampu hijau solid/berdenyut menyala menandakan Safety Car akan masuk pit di akhir lap.
   - Memasang sasis Safety Car resmi ini ke [`scripts/vfx/race_vfx.gd`](file:///D:/Occupation/Porto/genex/La_Voiture/scripts/vfx/race_vfx.gd) menggantikan sasis lama.

---

## 2. Step-by-Step Execution Guide

### Step 1: Meshy AI 3D Reconstruction (`meshy_multi_image_to_3d`)
* Gunakan tool MCP `meshy_multi_image_to_3d` dengan parameter:
  * `file_paths`: `["D:/Occupation/Porto/genex/La_Voiture/reference-assets/cars/mercedes-amg-gt3/front.png", "D:/Occupation/Porto/genex/La_Voiture/reference-assets/cars/mercedes-amg-gt3/back.png"]`
  * `ai_model`: `latest` (Meshy 7.1)
  * `enable_pbr`: `true`
  * `texture_resolution`: `4k`
* Pantau status via `meshy_get_task_status` sampai selesai (`SUCCEEDED`).
* Unduh model via `meshy_download_model`:
  * Format: `glb`
  * Save to: `D:/Occupation/Porto/genex/La_Voiture/assets/cars/mercedes_amg/raw/mercedes_amg_raw.glb`
* Pastikan file GLB mentah dilacak oleh Git LFS (`git lfs track "assets/cars/mercedes_amg/raw/*.glb"`).

### Step 2: Konfigurasi Parameter & Blender Headless Refining
* Buat file konfigurasi [`scratch/car_configs/mercedes_amg.json`](file:///D:/Occupation/Porto/genex/La_Voiture/scratch/car_configs/mercedes_amg.json) (ambil contoh dari `bmw_m4.json` atau `aston_vantage.json`):
  * Wheelbase $\approx 2.65\text{ m}$, axle $z \approx \pm 1.32\text{ m}$, height $y = 0.33\text{ m}$.
  * Target tris: $80.000 - 110.000$ tris.
  * Fender lift: `auto`, ground clamp: $+0.05\text{ m}$.
* Jalankan pipeline otomatis pembuatan mobil:
  ```powershell
  powershell -File scratch\make_car.ps1 -Car mercedes_amg
  ```
* Verifikasi gerbang fitment roda:
  ```powershell
  godot --headless --path . -s scratch/fit_cars.gd
  ```
  *(Wajib 100% PASS: 0 geometry penetration, ground clearance $\ge +0.04\text{ m}$, celah 2.5–5.0 cm).*

### Step 3: Scene Sasis Godot & Wiring Runtime
* Buat scene [`scenes/car/mercedes_amg_chassis.tscn`](file:///D:/Occupation/Porto/genex/La_Voiture/scenes/car/mercedes_amg_chassis.tscn) berbasis `ModularCarAssembler`:
  * Muat mesh `mercedes_amg_body.glb`.
  * Pasang material `shaders/toon_car_paint.gdshader` dengan `next_pass` inverted-hull outline.
  * Siapkan universal socket Marker3D (`Wheel_FL`, `FR`, `RL`, `RR`, `Cockpit`, `Exhaust_L`, `Exhaust_R`).
  * Pasang mesh lampu tipis emissive di `Chassis/Lamps` untuk lampu depan & lampu rem reaktif.
* Daftarkan ke [`scripts/car/gt_car_actor.gd`](file:///D:/Occupation/Porto/genex/La_Voiture/scripts/car/gt_car_actor.gd):
  * `CHASSIS_BY_TEAM[0] = preload("res://scenes/car/mercedes_amg_chassis.tscn")`
* Pastikan showroom garasi di [`scripts/world/garage_environment_builder.gd`](file:///D:/Occupation/Porto/genex/La_Voiture/scripts/world/garage_environment_builder.gd) memuat sasis Mercedes-AMG untuk Stall 0.

### Step 4: Rekayasa Official FIA Safety Car
* Buat scene [`scenes/car/safety_car_chassis.tscn`](file:///D:/Occupation/Porto/genex/La_Voiture/scenes/car/safety_car_chassis.tscn):
  * Sasis bodi memuat `assets/cars/porsche_911/porsche_911_body.glb`.
  * Beri material cat silver perak metalik dengan aksen kuning neon FIA.
  * Tambahkan node `RooftopLightbar` (`MeshInstance3D` aerodinamis) dengan material lampu LED strobo ganda:
    * `amber_strobe`: menyala kedip 10–12 Hz saat dipanggil `set_strobe_mode(AMBER)`.
    * `green_strobe`: menyala konstan saat `set_strobe_mode(GREEN)`.
* Di [`scripts/vfx/race_vfx.gd`](file:///D:/Occupation/Porto/genex/La_Voiture/scripts/vfx/race_vfx.gd):
  * Di `_build_safety_car()`, gunakan scene `safety_car_chassis.tscn`.
  * Di `_update_safety_car()`, sinkronkan animasi strobo dengan `race.safety_car.phase`:
    * `DEPLOYED` $\rightarrow$ Amber Strobe ON.
    * `IN_THIS_LAP` $\rightarrow$ Amber Strobe OFF, Green Light ON.
    * `HIDDEN` $\rightarrow$ Visible false.

### Step 5: Test Suite, DoD & Executive Report
* Buat test suite baru [`tests/test_mercedes_amg_chassis.gd`](file:///D:/Occupation/Porto/genex/La_Voiture/tests/test_mercedes_amg_chassis.gd) (18 asersi standar fitment, sockets, shader, dan dimensi).
* Perbarui [`tests/test_car_dynamics_vfx.gd`](file:///D:/Occupation/Porto/genex/La_Voiture/tests/test_car_dynamics_vfx.gd) agar menguji Safety Car resmi dengan lightbar dua fase.
* Jalankan seluruh 26 test suite:
  ```powershell
  Get-ChildItem tests\test_*.gd | ForEach-Object { godot --headless --fixed-fps 60 --path . -s "res://tests/$($_.Name)" }
  ```
  *(Wajib 26/26 PASS, 0 FAIL).*
* Tulis laporan resmi di [`executor-report/reports/FASE-11-LANGKAH-1-MERCEDES-AMG-AND-SAFETY-CAR-REPORT.md`](file:///D:/Occupation/Porto/genex/La_Voiture/executor-report/reports/FASE-11-LANGKAH-1-MERCEDES-AMG-AND-SAFETY-CAR-REPORT.md) dan simpan tangkapan layar verifikasi di `executor-report/screenshots/phases/`.

---

## 3. Batasan Penting (Boundaries)
- **Zero Asset Deletion:** DILARANG menghapus sasis Porsche 911 yang ada karena sasis tersebut dialihfungsikan menjadi Safety Car resmi.
- **Git LFS Safety:** Pastikan file GLB mentah baru di `assets/cars/mercedes_amg/raw/` terdaftar di Git LFS sebelum commit.
- **No Global Body Lifting:** Jangan mengangkat bodi mobil secara global untuk menyelesaikan fitment ban; gunakan *local fender lift* dan *ground clamp* di Blender.
