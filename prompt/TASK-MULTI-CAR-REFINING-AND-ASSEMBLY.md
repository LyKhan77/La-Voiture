# TASK SPECIFICATION: 8 GT3 CARS BATCH BODY REFINING & MASTER ASSEMBLY

**Task ID:** `TASK-MULTI-CAR-REFINING-AND-ASSEMBLY`  
**Assignee:** Executor Agent (Blender & Godot Technical Artist)  
**Priority:** High (Completing Full 10-Manufacturer GT3 Grid)  
**Status Masukan:** Langkah 1 (Batch Generasi Fondasi 3D Mentah Meshy AI) telah **SELESAI 100%**. Seluruh 8 file `<car_slug>_raw.glb` beserta 4 peta tekstur PBR (`base_color`, `metallic`, `roughness`, `normal`) telah tersedia lengkap di folder `assets/cars/<car_slug>/raw/`.  
**Blender Executable:** `C:\Program Files\Blender Foundation\Blender 5.2\blender.exe`  
**Godot Console:** `C:\Users\Lee\Downloads\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe`  
**Referensi Pipeline:** [`executor-report/FASE-7-AUDI-R8-PROTOTYPE-ASSEMBLY.md`](file:///D:/Occupation/Porto/genex/La_Voiture/executor-report/FASE-7-AUDI-R8-PROTOTYPE-ASSEMBLY.md), [`scratch/refine_car.py`](file:///D:/Occupation/Porto/genex/La_Voiture/scratch/refine_car.py), [`scratch/build_full_car.py`](file:///D:/Occupation/Porto/genex/La_Voiture/scratch/build_full_car.py)

---

## 1. Daftar 8 Mobil GT3 & Status Masukan Raw

Seluruh model mentah telah di-download dan siap diproses di Blender:

| # | Tim Balap | Slug Mobil | Model Mentah (Input) | Tekstur PBR (Input) |
| :-: | :--- | :--- | :--- | :--- |
| **1** | Kurogane GT | `nissan_gtr` | [`assets/cars/nissan_gtr/raw/nissan_gtr_raw.glb`](file:///D:/Occupation/Porto/genex/La_Voiture/assets/cars/nissan_gtr/raw/nissan_gtr_raw.glb) (81.4 MB) | `raw/nissan_gtr_raw_textures/` |
| **2** | Valkyrie Scuderia | `aston_vantage` | [`assets/cars/aston_vantage/raw/aston_vantage_raw.glb`](file:///D:/Occupation/Porto/genex/La_Voiture/assets/cars/aston_vantage/raw/aston_vantage_raw.glb) (132.5 MB) | `raw/aston_vantage_raw_textures/` |
| **3** | Nordic Phantom | `bmw_m4` | [`assets/cars/bmw_m4/raw/bmw_m4_raw.glb`](file:///D:/Occupation/Porto/genex/La_Voiture/assets/cars/bmw_m4/raw/bmw_m4_raw.glb) (39.5 MB) | `raw/bmw_m4_raw_textures/` |
| **4** | Cyberpunk Syndicate | `lambo_huracan` | [`assets/cars/lambo_huracan/raw/lambo_huracan_raw.glb`](file:///D:/Occupation/Porto/genex/La_Voiture/assets/cars/lambo_huracan/raw/lambo_huracan_raw.glb) (49.4 MB) | `raw/lambo_huracan_raw_textures/` |
| **5** | Tokyo Underground | `honda_nsx` | [`assets/cars/honda_nsx/raw/honda_nsx_raw.glb`](file:///D:/Occupation/Porto/genex/La_Voiture/assets/cars/honda_nsx/raw/honda_nsx_raw.glb) (94.5 MB) | `raw/honda_nsx_raw_textures/` |
| **6** | Zero Hour / Corsa | `chevy_corvette` | [`assets/cars/chevy_corvette/raw/chevy_corvette_raw.glb`](file:///D:/Occupation/Porto/genex/La_Voiture/assets/cars/chevy_corvette/raw/chevy_corvette_raw.glb) (48.0 MB) | `raw/chevy_corvette_raw_textures/` |
| **7** | Static Speed | `lexus_rcf` | [`assets/cars/lexus_rcf/raw/lexus_rcf_raw.glb`](file:///D:/Occupation/Porto/genex/La_Voiture/assets/cars/lexus_rcf/raw/lexus_rcf_raw.glb) (68.8 MB) | `raw/lexus_rcf_raw_textures/` |
| **8** | Chrome Syndicate | `mclaren_720s` | [`assets/cars/mclaren_720s/raw/mclaren_720s_raw.glb`](file:///D:/Occupation/Porto/genex/La_Voiture/assets/cars/mclaren_720s/raw/mclaren_720s_raw.glb) (86.0 MB) | `raw/mclaren_720s_raw_textures/` |

*(Tim 0 Porsche 911 GT3 R dan Tim 1 Audi R8 LMS GT3 telah 100% selesai dan terpasang di trek).*

---

## 2. Deliverables yang Harus Dihasilkan per Mobil

Untuk setiap mobil dari ke-8 mobil di atas, Executor harus menghasilkan:

1. **Config JSON**: `scratch/car_configs/<car_slug>.json` (menentukan nama mesh, material, panjang $4.55\text{m}$, deteksi sumbu roda otomatis, dan zona detail splitter/diffuser).
2. **Clean Body Shell**: `assets/cars/<car_slug>/<car_slug>_body.glb` ($\sim 80.000 - 120.000$ tris, ban AI baked dibuang 100%, 4 inner fender tubs terpasang, tekstur JPEG tertanam).
3. **Bake 4K Textures**: `assets/cars/<car_slug>/textures/` berisi `base_color.png`, `normal.png`, dan `orm.png` ($4096 \times 4096$).
4. **Full Car Model**: `assets/cars/<car_slug>/<car_slug>_full.glb` (bodi bersih + 4 roda master BBS FI-R di posisi socket) via `scratch/build_full_car.py`.
5. **Godot Toon Material**: `materials/<car_slug>_toon_body.tres` menggunakan `shaders/toon_car_paint.gdshader` (shine + emboss + AO + outline $0.02\text{m}$).
6. **Chassis Scene**: `scenes/car/<car_slug>_chassis.tscn` dengan `keeps_original_paint = true`, `ModularCarAssembler`, dan 4 socket roda `Marker3D`.
7. **Integrasi Tim**: Mendaftarkan `team_id` ke dictionary `CHASSIS_BY_TEAM` di `scripts/car/gt_car_actor.gd`.
8. **Unit Test Khusus**: `tests/test_<car_slug>_chassis.gd` (memvalidasi socket, wheelbase, tidak ada geometri roda di lengkung, ban flush, dan warna asli).
9. **Visual Verification**: Screenshot showroom 3/4 depan dan tampak samping kiri (flush stance).

---

## 3. Langkah Kerja Otomatis (Prosedur Eksekusi)

Ikuti alur kerja baku yang telah terbukti pada prototipe Audi R8:

### Langkah 3.1: Deteksi Sumbu & Buat Config JSON
Jalankan deteksi otomatis sumbu roda dari ban baked yang menyentuh tanah:
```powershell
& "C:\Program Files\Blender Foundation\Blender 5.2\blender.exe" --background --python scratch/refine_car.py -- scratch/car_configs/audi_r8.json --detect-only
```
Salin template dari `scratch/car_configs/audi_r8.json` menjadi `scratch/car_configs/<car_slug>.json`. Pastikan:
* `"car"`: `<car_slug>`
* `"raw_glb"`: `"assets/cars/<car_slug>/raw/<car_slug>_raw.glb"`
* `"body_glb"`: `"assets/cars/<car_slug>/<car_slug>_body.glb"`
* `"texture_dir"`: `"assets/cars/<car_slug>/textures"`
* `"mesh_name"`: `"<CarName>_Body"`
* `"paint_material"`: `"<CarName>_Paint"`
* `"front_axis_raw"`: `"auto"`
* `"raw_axle"`: `"auto"`
* `"length_m"`: `4.55`
* `"axle_z"`: `0.33`

### Langkah 3.2: Retopo + Bake via Headless Blender
Uji coba terlebih dahulu ke folder `temp/`:
```powershell
& "C:\Program Files\Blender Foundation\Blender 5.2\blender.exe" --background --python scratch/refine_car.py -- scratch/car_configs/<car_slug>.json --out-dir temp/<car_slug>_trial
```
Periksa kualitas mesh. Jika sudah mulus dan zona splitter/diffuser terjaga, jalankan perintah final langsung ke direktori aset:
```powershell
& "C:\Program Files\Blender Foundation\Blender 5.2\blender.exe" --background --python scratch/refine_car.py -- scratch/car_configs/<car_slug>.json
```

### Langkah 3.3: Rakit Sasis Godot & Material
1. Salin `materials/audi_r8_toon_body.tres` menjadi `materials/<car_slug>_toon_body.tres`. Kaitkan tekstur `base_color.png`, `normal.png`, dan `orm.png` dari folder `assets/cars/<car_slug>/textures/`.
2. Salin `scenes/car/audi_r8_chassis.tscn` menjadi `scenes/car/<car_slug>_chassis.tscn`.
3. Ganti node `BodyShell` untuk memuat `<car_slug>_body.glb`.
4. Sesuaikan posisi Z pada 4 node `Marker3D` (`Socket_Wheel_FL`, `FR`, `RL`, `RR`) dengan hasil deteksi sumbu roda (misal: $Z = \pm 1.338\text{m}$ atau sesuai wheelbase mobil).
5. Pastikan `@export var keeps_original_paint = true`.

### Langkah 3.4: Buat Aset Utuh (`build_full_car.py`)
Bangun file GLB bodi + roda lengkap:
```powershell
& "C:\Program Files\Blender Foundation\Blender 5.2\blender.exe" --background --python scratch/build_full_car.py -- scenes/car/<car_slug>_chassis.tscn assets/cars/<car_slug>/<car_slug>_full.glb
```

### Langkah 3.5: Integrasi & Pengujian Godot
1. Daftarkan mapping tim di `scripts/car/gt_car_actor.gd` pada `CHASSIS_BY_TEAM`:
   ```gdscript
   const CHASSIS_BY_TEAM: Dictionary = {
       1: preload("res://scenes/car/audi_r8_chassis.tscn"),
       2: preload("res://scenes/car/nissan_gtr_chassis.tscn"),
       # ... tambahkan mobil lainnya
   }
   ```
2. Buat `tests/test_<car_slug>_chassis.gd` (adaptasi dari `test_audi_r8_chassis.gd`).
3. Jalankan pengujian:
   ```powershell
   & "C:\Users\Lee\Downloads\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe" --headless --path . -s tests/test_<car_slug>_chassis.gd
   & "C:\Users\Lee\Downloads\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe" --headless --path . -s tests/test_modular_car.gd
   & "C:\Users\Lee\Downloads\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe" --headless --path . -s tests/test_audio_and_race_weekend.gd
   ```
   **Kriteria Penerimaan:** Seluruh pengujian wajib **0 FAIL / 100% PASS**.

4. Ambil screenshot showroom dan race world untuk verifikasi visual.

---

## 4. Prioritas Pengerjaan Disarankan (Batch per 2-3 Mobil)

Untuk menjaga stabilitas memori RAM dan kemudahan verifikasi:
* **Batch 1:** `nissan_gtr` (Tim 2 Kurogane GT) & `aston_vantage` (Tim 3 Valkyrie Scuderia)
* **Batch 2:** `bmw_m4` (Tim 5 Nordic Phantom) & `lambo_huracan` (Tim 6 Cyberpunk Syndicate)
* **Batch 3:** `honda_nsx` (Tim 8 Tokyo Underground) & `chevy_corvette` (Tim 4 Corsa / Zero Hour)
* **Batch 4:** `lexus_rcf` (Tim 7 Static Speed) & `mclaren_720s` (Tim 9 Chrome Syndicate)

Setelah selesai, buat laporan eksekutif di `executor-report/FASE-7-MULTI-CAR-ASSEMBLY-REPORT.md`.
