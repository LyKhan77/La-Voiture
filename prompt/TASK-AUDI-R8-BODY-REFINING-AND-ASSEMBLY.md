# TASK SPECIFICATION: AUDI R8 LMS GT3 BODY REFINING & MASTER ASSEMBLY

**Task ID:** `TASK-AUDI-R8-BODY-REFINING-AND-ASSEMBLY`  
**Assignee:** Executor Agent (Blender & Godot Technical Artist)  
**Priority:** High (First Multi-Manufacturer Expansion Prototype)  
**Blender MCP Status:** ACTIVE on port `9875` (`127.0.0.1:9875`)  
**Blender Executable:** `C:\Program Files\Blender Foundation\Blender 5.2\blender.exe`  
**Godot Console:** `C:\Users\Lee\Downloads\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe`

---

## 1. Konteks & Status Aset Awal (Input Assets)

Langkah 1 (Generasi 3D Multi-Image via Meshy AI) telah **SELESAI** dieksekusi dengan memanfaatkan 2 sudut pandang referensi ([`reference-assets/cars/audi-r8-gt3/front.png`](file:///D:/Occupation/Porto/genex/La_Voiture/reference-assets/cars/audi-r8-gt3/front.png) dan [`back.png`](file:///D:/Occupation/Porto/genex/La_Voiture/reference-assets/cars/audi-r8-gt3/back.png)).

File model mentah dan peta tekstur PBR telah tersimpan di direktori proyek:
- **Raw 3D Model:** [`assets/cars/audi_r8/raw/audi_r8_raw.glb`](file:///D:/Occupation/Porto/genex/La_Voiture/assets/cars/audi_r8/raw/audi_r8_raw.glb) ($89.5\text{ MB}$, Meshy Task ID `01a16196-f41a-74de-a99e-8057e39fcddf`)
- **PBR Textures:** [`assets/cars/audi_r8/raw/audi_r8_raw_textures/`](file:///D:/Occupation/Porto/genex/La_Voiture/assets/cars/audi_r8/raw/audi_r8_raw_textures/)
  - `base_color.png`
  - `metallic.png`
  - `roughness.png`
  - `normal.png`

> [!WARNING]
> Model mentah dari AI generatif **masih memuat roda 'baked' (ban dan pelek yang menempel mati)** di keempat sudut spakbor. Jangan langsung memasang model mentah ini ke Godot tanpa pembersihan spakbor di Blender!

---

## 2. Deliverables yang Harus Dihasilkan

| Deliverable | Target Path | Deskripsi & Kriteria |
| :--- | :--- | :--- |
| **Deliverable 1: Clean Body Shell** | `assets/cars/audi_r8/audi_r8_body.glb` | Bodi Audi R8 bersih: ban *baked* dibuang 100%, 4 *inner fender tubs* terpasang, bibir spakbor mulus, origin di $(0,0,0)$ ground level, wheelbase $2650\text{mm}$. |
| **Deliverable 2: Shaders & Materials** | `materials/audi_r8_toon_body.tres` | Material Cel-Shaded 2-step lighting + Inverted-Hull Ink Outline $2.5\text{px}$ menggunakan tekstur `base_color.png` dan `normal.png`. |
| **Deliverable 3: Modular Chassis Scene** | `scenes/car/audi_r8_chassis.tscn` | Scene berbasis `ModularCarAssembler` dengan `BodyShell` Audi R8 + 4 node `Marker3D` (`Socket_Wheel_FL`, `FR`, `RL`, `RR`) terkalibrasi presisi. |
| **Deliverable 4: Integrasi Aktor & Testing** | `scripts/car/gt_car_actor.gd` & Test Suite | Memungkinkan mobil tim Audi (Team 1 `Neon Drift` / `Ironclad`) memuat sasis Audi R8 di trek. Uji via headless runner. |
| **Deliverable 5: Visual Verification Capture** | `scratch/audi_r8_showroom.png` & close-up | Tangkapan layar resolusi tinggi yang membuktikan 4 roda modular pas sempurna (*flush stance*) tanpa clipping. |
| **Deliverable 6: Laporan Eksekutif** | `executor-report/FASE-7-AUDI-R8-PROTOTYPE-ASSEMBLY.md` | Laporan komprehensif berisi metrik dimensi, polycount, dan hasil verifikasi. |

---

## 3. Spesifikasi Teknis Pengerjaan

### 3.1 Pekerjaan di Blender (Deliverable 1)
Gunakan skrip Python otomatis (misal: `scratch/refine_audi_r8.py`) yang dijalankan via Blender 5.2 headless (`blender.exe --background --python scratch/refine_audi_r8.py`) atau interaktif via Blender MCP (port 9875). Pola pengerjaan mengikuti [`FASE-4-PORSCHE-BODY-AND-WHEEL-REFINING.md`](file:///D:/Occupation/Porto/genex/La_Voiture/executor-report/FASE-4-PORSCHE-BODY-AND-WHEEL-REFINING.md):

1. **Decimation / Reduksi Poligon (Wajib):**
   - Model mentah Meshy memiliki **2,77 juta faces (terlalu berat)**.
   - Terapkan modifier `Decimate` (rasio $\approx 0.04$ s.d. $0.05$) untuk menurunkan polycount menjadi **$\sim 80.000 - 120.000$ tris** (setara dengan Porsche 911 yang memiliki 115k tris) agar performa 60 FPS di Godot tetap terjaga.
2. **Normalisasi Skala & Dimensi FIA GT3:**
   - Model mentah Meshy berdimensi miniatur ($X=1.90\text{m}, Y=0.86\text{m}, Z=0.54\text{m}$).
   - Skalakan model agar memiliki proporsi GT3 riil: Panjang $\approx 4.55\text{m}$, Lebar $\approx 2.04\text{m}$, Tinggi $\approx 1.25\text{m}$.
   - Putar orientasi sumbu agar $+Z$ menghadap Depan, $+Y$ Atas, $+X$ Kanan.
3. **Deteksi Sumbu Roda (*Circle-Fit*):**
   - Cari pusat koordinat 4 lengkungan roda Audi R8:
     - Sumbu Depan: $Z \approx +1.20\text{m}$, tinggi as roda $Y \approx 0.33\text{m}$, lebar $|X| \approx 0.88\text{m}$.
     - Sumbu Belakang: $Z \approx -1.25\text{m}$, tinggi as roda $Y \approx 0.33\text{m}$, lebar $|X| \approx 0.88\text{m}$.
4. **Pembersihan Roda Baked:**
   - Seleksi dan hapus seluruh vertex/face roda dan pelek bawaan AI di keempat sudut (roda padat Meshy dibuang bersih).
5. **Konstruksi Inner Fender Tubs:**
   - Buat dinding setengah-pipa radius $R = 0.372\text{m}$ sepanjang busur $300^\circ$ di setiap sudut spakbor.
   - Sisi dalam tertutup pada $|X| \approx 0.65\text{m}$.
   - Berikan material slot `FenderLinerMat` (warna hitam doff `#0A0A0A`, roughness 0.95).
   - Pastikan dasar tub dijepit pada $Z \ge 0.10\text{m}$ agar tidak tembus ke bawah kolong mobil.
6. **Perapihan Bibir Spakbor (*Fender Lip Snapping*):**
   - Rapikan loop tepi spakbor luar dan snap ke busur lingkaran $R \approx 0.372\text{m}$.
   - **PENTING:** Jangan merusak permukaan cat livery luar dan flare bodi Audi R8.
7. **Standarisasi Dimensi & Pivot Origin:**
   - Pastikan origin $(0, 0, 0)$ berada persis di permukaan tanah ($Y = 0.0$) di titik tengah antara sumbu roda depan dan belakang.
   - Ekspor GLB bersih ke `assets/cars/audi_r8/audi_r8_body.glb`.

---

### 3.2 Pekerjaan di Godot 4 (Deliverable 2 & 3)

1. **Material Toon Manga (`materials/audi_r8_toon_body.tres`):**
   - Duplikasi atau adaptasi dari `materials/porsche_toon_body.tres`.
   - Gunakan shader `shaders/toon_car_paint.gdshader` dengan albedo tekstur `base_color.png` dan normal map `normal.png`.
   - Pastikan outline ink pass (`inverted_hull_outline.gdshader`) aktif dengan ketebalan $0.02\text{m}$ warna hitam `#050505`.
2. **Scene Sasis Modular (`scenes/car/audi_r8_chassis.tscn`):**
   - Root Node: `ModularCarAssembler` (`scripts/car/modular_car_assembler.gd`).
   - Node `BodyShell`: Memuat instance `assets/cars/audi_r8/audi_r8_body.glb`.
   - Node `Sockets`:
     ```text
     Sockets/
     ├── Socket_Wheel_FL   (Transform: X=-0.88, Y=0.33, Z=1.20)
     ├── Socket_Wheel_FR   (Transform: X=0.88, Y=0.33, Z=1.20)
     ├── Socket_Wheel_RL   (Transform: X=-0.88, Y=0.33, Z=-1.25)
     ├── Socket_Wheel_RR   (Transform: X=0.88, Y=0.33, Z=-1.25)
     └── Socket_Cockpit    (Transform: X=0.0, Y=0.72, Z=0.05)
     ```
   - Hubungkan ke modul roda master universal [`assets/cars/parts/gt3_wheel_master.glb`](file:///D:/Occupation/Porto/genex/La_Voiture/assets/cars/parts/gt3_wheel_master.glb).

---

### 3.3 Integrasi ke Balapan & Pengujian (Deliverable 4 & 5)

1. **Dukungan Multi-Chassis di `gt_car_actor.gd`:**
   - Modifikasi `gt_car_actor.gd` agar dapat memuat scene sasis yang sesuai dengan `team_id` mobil (misal: jika mobil tim Audi R8, load `audi_r8_chassis.tscn`; jika Porsche, load `base_chassis.tscn`).
2. **Eksekusi Pengujian Otomatis:**
   - Jalankan test modular:
     ```powershell
     & "C:\Users\Lee\Downloads\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe" --headless --path . -s tests/test_modular_car.gd
     ```
   - Jalankan seluruh 10 test suite:
     ```powershell
     & "C:\Users\Lee\Downloads\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe" --headless --path . -s tests/test_audio_and_race_weekend.gd
     ```
   - **Syarat Mutlak:** Seluruh asersi wajib berstatus **PASS (0 failures)** tanpa regresi.
3. **Capture Visual Showroom:**
   - Buat skrip tangkapan layar (misal `scratch/capture_audi_r8.gd`) dan ambil screenshot:
     - Tampak samping kiri (memperlihatkan ban sejajar dengan bibir spakbor tanpa clipping).
     - Tampak miring depan 3/4 (memperlihatkan grille Audi R8, lampu, pelek BBS FI-R, dan kaliper kuning).
     - Tampak belakang (memperlihatkan diffuser dan sayap belakang).
   - Simpan screenshot ke `scratch/audi_r8_showroom.png`.

---

## 4. Format Laporan Akhir Executor

Setelah seluruh deliverable selesai, buat laporan eksekutif di:
[`executor-report/FASE-7-AUDI-R8-PROTOTYPE-ASSEMBLY.md`](file:///D:/Occupation/Porto/genex/La_Voiture/executor-report/FASE-7-AUDI-R8-PROTOTYPE-ASSEMBLY.md)

Laporan wajib memuat:
1. Ringkasan dimensi akhir bodi Audi R8 dan perbandingan jumlah poligon sebelum/sesudah refining.
2. Koordinat pasti 4 socket roda (`Socket_Wheel_*`).
3. Screenshot visual hasil render di Godot Engine.
4. Log eksekusi unit test yang membuktikan 0 failures.
