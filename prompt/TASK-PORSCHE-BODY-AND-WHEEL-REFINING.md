# TASK SPECIFICATION: PORSCHE 911 GT3 BODY MESH & GT3 RACING WHEEL REFINING

**Task ID:** `TASK-PORSCHE-BODY-AND-WHEEL-REFINING`  
**Assignee:** Executor Agent (Blender & 3D Asset Specialist)  
**Priority:** High (Final Quality Polish for Phase 4 Visual Pipeline)  
**Blender MCP Status:** ACTIVE on port `9875` (`127.0.0.1:9875`)  
**Blender Executable:** `C:\Program Files\Blender Foundation\Blender 5.2\blender.exe`  
**Godot Console:** `C:\Users\Lee\Downloads\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe`

---

## 1. Scope & Deliverables

Executor Agent ditugaskan untuk melakukan **refining visual tingkat tinggi** pada dua asset utama:

| Deliverable | Target Path | Fokus Pengerjaan |
| :--- | :--- | :--- |
| **Deliverable A: Body Mesh Polish** | `assets/cars/porsche_911/porsche_911_body.glb` | Menghaluskan lengkungan spakbor (*fender lips*), merapikan *inner fender liners*, dan memastikan bodi Porsche 911 GT3 tampil bersih tanpa tepi bergerigi. |
| **Deliverable B: High-End GT3 Wheel Refining** | `assets/cars/parts/gt3_wheel_master.glb` | Membuat ulang/merapikan asset velg dan ban agar memiliki kualitas visual balap profesional (velg concave BBS/OZ style, alur ban rapi, detail rem drilled disc + kaliper balap). |

---

## 2. Spesifikasi Teknis Deliverable A: Body Mesh Polish

### A. Smoothing Lengkungan Spakbor (*Wheel Arches*)
1. Buka `assets/cars/porsche_911/porsche_911_body.glb` di Blender.
2. Periksa 4 lengkungan spakbor:
   - **Front-Left (FL):** $X \approx -0.90\text{ m}, Y \approx 0.33\text{ m}, Z \approx 1.25\text{ m}$
   - **Front-Right (FR):** $X \approx +0.90\text{ m}, Y \approx 0.33\text{ m}, Z \approx 1.25\text{ m}$
   - **Rear-Left (RL):** $X \approx -0.90\text{ m}, Y \approx 0.33\text{ m}, Z \approx -1.18\text{ m}$
   - **Rear-Right (RR):** $X \approx +0.90\text{ m}, Y \approx 0.33\text{ m}, Z \approx -1.18\text{ m}$
3. **Perapihan Edge Loop:**
   - Hilangkan simpul/face bergerigi sisa operasi Boolean.
   - Buat bibir spakbor (*fender lip*) melengkung halus dan mulus dengan radius bukaan sekitar $R \approx 0.36\text{ m}$.
   - **JANGAN** merusak lekukan bodi luar (*fender flare curve*) yang memiliki cat livery Gulf.

### B. Inner Fender Tubs (*Ruang Roda Dalam*)
1. Pastikan di balik setiap lubang spakbor terdapat *inner tub* melengkung rapat yang menutup pandangan ke rongga kabin interior.
2. Material slot 1 harus menggunakan `FenderLinerMat` (karbon hitam doff gelap `#0A0A0A`, roughness 0.95).

### C. Invarian Sumbu & Dimensi
- Dimensi total mobil: Panjang $4.57\text{ m}$, Lebar $2.05\text{ m}$, Tinggi $1.34\text{ m}$.
- Origin $(0,0,0)$ tepat di permukaan tanah (*ground level*, $Y = 0.0$) di tengah wheelbase.
- Orientasi ekspor glTF ke Godot: $+Z$ Depan, $-Z$ Belakang, $+X$ Kanan, $-X$ Kiri, $+Y$ Atas.

---

## 3. Spesifikasi Teknis Deliverable B: High-End GT3 Wheel Refining

Asset roda saat ini dinilai kurang detail/bagus. Executor perlu memoles atau merekonstruksi `assets/cars/parts/gt3_wheel_master.glb` dengan detail balap GT3 otentik:

### A. Geometri Velg (*Alloy Rim*)
- **Desain Concave Racing:** Model velg balap GT3 (gaya BBS FI-R atau OZ Racing Ultraleggera HLT) dengan profil cekung (*deep concave*).
- **Spokes:** 10-spoke atau 5 Y-split twin-spoke dengan celah tembus pandang yang menampakkan piringan rem di belakangnya.
- **Center-Lock Mechanism:** Baut tengah balap *center-lock* hexagonal anodized red dengan klip pengunci.
- **Material Rim:** Dark satin gunmetal / carbon metallic (`#1E2024`, metallic 0.9, roughness 0.25).

### B. Geometri Ban (*Tire Rubber & Sidewall*)
- **Dimensi Standar GT3:** Radius luar $0.33\text{ m}$, lebar tapak $0.28\text{ m}$.
- **Shoulder & Tread:** Bahu ban melengkung realistis (*curved tire shoulder*), bukan silinder datar kaku.
- **Sidewall Groove & Stripe:** Alur melingkar (*groove*) pada sidewall luar pada radius $0.27\text{ m}$ untuk strip kompon ban yang menyala (Soft/Medium/Hard/Wet).
- **Tire Decal/Lettering:** Detail emboss teks ban melingkar (*GT3 RACING* atau *MICHELIN*) di dinding ban.

### C. Sistem Rem Balap (*Brake Assembly*)
- **Brake Disc Rotor:** Piringan cakram berventilasi cross-drilled / slotted carbon-ceramic (radius $0.185\text{ m}$, tebal $0.024\text{ m}$) dengan tromol tengah aluminium (*center hat*).
- **Brake Caliper:** Kaliper balap 6-piston monobloc bergaya Brembo Racing berwarna kuning balap (`#FFC200`) atau merah dengan detail baut dan logo.

### D. Hierarki Node yang Wajib Dipertahankan (Untuk Animasi Godot)
Hierarki node pada file `.glb` **harus persis** seperti ini agar kompatibel dengan script engine:
```
- gt3_wheel_master (Node3D)
  - GT3_Wheel_Assembly (Node3D)
    - GT3_BrakeCaliper (MeshInstance3D)      <-- STATIS (tidak ikut berputar saat mobil melaju)
    - WheelRotating (Node3D)                 <-- BERPUTAR pada sumbu X saat mobil melaju/burnout
      - GT3_AlloyRim (MeshInstance3D)
      - GT3_BrakeDisc (MeshInstance3D)
      - GT3_CenterNut (MeshInstance3D)
      - GT3_SidewallStripe (MeshInstance3D)  <-- Memiliki surface material override untuk warna kompon
      - GT3_TireRubber (MeshInstance3D)
```

---

## 4. Alur Kerja Eksekusi & Tools

Executor dapat memilih salah satu metode:
1. **Via Live Blender MCP Server (Port 9875):**
   - Tool: `blender` -> `execute_blender_code`.
   - Menjalankan Python script langsung di dalam sesi Blender aktif pengguna.
2. **Via Blender CLI Headless:**
   ```powershell
   & "C:\Program Files\Blender Foundation\Blender 5.2\blender.exe" --background --python <path_script.py>
   ```

---

## 5. Protokol Verifikasi Wajib (Zero-Defect Gate)

Setelah mengupdate file `assets/cars/porsche_911/porsche_911_body.glb` dan `assets/cars/parts/gt3_wheel_master.glb`:

1. **Re-import Assets ke Godot Engine:**
   ```powershell
   & "C:\Users\Lee\Downloads\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe" --headless --editor --quit
   ```
2. **Jalankan Unit Test Modularitas & Pit Stop:**
   ```powershell
   & "C:\Users\Lee\Downloads\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe" --headless -s tests/test_modular_car.gd
   ```
   *Wajib: 100% PASS (0 failure).*
3. **Capture & Inspeksi Visual Screenshot Showroom:**
   ```powershell
   & "C:\Users\Lee\Downloads\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe" --rendering-driver d3d12 -s scratch/capture_showroom.gd
   ```
   Buka file `scratch/godot_showroom_screenshot.png` untuk memastikan:
   - Lengkungan spakbor bodi Porsche halus dan rapat.
   - Velg dan ban GT3 tampak detail, realistis, dan duduk pas di dalam fender (*flush stance*).
