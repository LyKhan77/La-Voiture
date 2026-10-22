# TASK SPECIFICATION: PERBAIKAN FITMENT RODA & FENDER CLIPPING (10 MOBIL GT3)

**Task ID:** `TASK-FIX-CAR-WHEEL-FIT-AND-FENDERS`  
**Assignee:** Senior 3D Vehicle Rigging & Simulation Technical Artist  
**Priority:** CRITICAL (Visual & Mechanical Quality Gate)  
**Status Masukan:** Seluruh 10 mobil telah memiliki model mentah di `assets/cars/<car_slug>/raw/` dan pipeline awal di `scratch/refine_car.py`.  
**Blender Executable:** `C:\Program Files\Blender Foundation\Blender 5.2\blender.exe`  
**Godot Console:** `C:\Users\Lee\Downloads\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe`  
**Skrip Diagnostik Utama:** [`scratch/diagnose_wheels.gd`](file:///D:/Occupation/Porto/genex/La_Voiture/scratch/diagnose_wheels.gd)

---

## 1. Analisis Masalah & Hasil Diagnosa Headless Godot

Setelah dilakukan pengujian geometris otomatis menggunakan [`scratch/diagnose_wheels.gd`](file:///D:/Occupation/Porto/genex/La_Voiture/scratch/diagnose_wheels.gd), ditemukan akar penyebab visual mengapa beberapa mobil mengalami **roda terlalu naik ke atas (memotong fender)** dan **roda menembus dinding fender luar**:

```text
DIAGNOSA KETINGGIAN & GROUND CLEARANCE PADA HASIL GENERASI SEBELUMNYA:
---------------------------------------------------------------------------------------
Mobil           | AABB Pos Y (Dasar Bodi) | Clearance Ban-Fender | Status Visual
---------------------------------------------------------------------------------------
porsche_911     | +0.086 m (Ground aman)  | +0.031 s/d +0.035 m  | PASS (Ideal & Sempurna)
audi_r8         | +0.076 m (Ground aman)  | +0.011 s/d +0.011 m  | PASS (Mulus)
nissan_gtr      | -0.078 m (AMBLES 7.8cm) | +0.011 s/d +0.013 m  | FAIL (Ambles, Roda Memotong)
aston_vantage   | -0.089 m (AMBLES 8.9cm) | +0.011 s/d +0.012 m  | FAIL (Ambles, Roda Memotong)
bmw_m4          | +0.064 m (Ground aman)  | +0.011 s/d +0.011 m  | FAIL (Sumbu Z Off-Center 6.4cm)
lambo_huracan   | -0.068 m (AMBLES 6.8cm) | +0.011 s/d +0.013 m  | FAIL (Ambles, Menembus Flare)
honda_nsx       | +0.024 m (Ground mepet) | +0.010 s/d +0.012 m  | FAIL (Mepet, Sumbu Belakang Mundur)
chevy_corvette  | -0.076 m (AMBLES 7.6cm) | +0.010 s/d +0.013 m  | FAIL (Ambles, Roda Terlalu Atas)
lexus_rcf       | -0.049 m (AMBLES 4.9cm) | +0.010 s/d +0.012 m  | FAIL (Ambles)
mclaren_720s    | -0.083 m (AMBLES 8.3cm) | +0.011 s/d +0.013 m  | FAIL (Ambles 8cm, Asimetri Z 9cm)
---------------------------------------------------------------------------------------
```

---

## 2. Empat Akar Masalah Teknis (Root Causes)

### Akar Masalah 1: Bug Penurunan Bodi Mobil (`Q[:, 2] -= RAW_Z - Z_AXLE`)
* Pada [`scratch/refine_car.py`](file:///D:/Occupation/Porto/genex/La_Voiture/scratch/refine_car.py#L93), script mendeteksi radius ban mentah AI Meshy (`RAW_Z \approx 0.40 - 0.42\text{m}`).
* Script kemudian menurunkan **seluruh bodi mobil** sebesar `RAW_Z - 0.33m` (turun $7 - 9\text{ cm}$).
* Akibatnya: **Bodi mobil ambles ke bawah tanah ($Y < 0$)**, sedangkan roda modular bertumpu di permukaan tanah ($Y = 0.0$, as roda di $Y = 0.33$). Secara relatif, roda terdorong masuk $8\text{ cm}$ terlalu dalam ke dalam spakbor bodi!

### Akar Masalah 2: Asimetri Overhang Depan vs Belakang (Sumbu Z)
* Script menetapkan `Socket Z = \pm (wheelbase / 2)` secara simetris dari titik tengah bodi.
* Mobil nyata (seperti BMW M4 dan McLaren 720S) memiliki panjang kap depan dan buritan yang berbeda (*asymmetrical overhang*). Contoh BMW M4: sumbu roda depan mentah ada di $Y = -1.362$, belakang di $Y = 1.234$. Memaksa titik tengah memundurkan roda depan $6.4\text{ cm}$ dan memajukan roda belakang $6.4\text{ cm}$, sehingga roda menabrak dinding lengkungan spakbor!

### Akar Masalah 3: Lebar Track Depan vs Belakang Berbeda (Staggered Track Width - Sumbu X)
* Mobil GT3 memiliki fender belakang yang lebih lebar ($2 - 6\text{ cm}$) dibanding fender depan.
* Menetapkan satu nilai `Socket X` yang sama untuk roda depan dan belakang menyebabkan ban depan terlalu keluar (menembus bibir fender luar) atau ban belakang terlalu mendalam ke sasis.

### Akar Masalah 4: Radius Potong Bukaan Spakbor Kurang Longgar
* Parameter `arch_radius = 0.372m` hanya memberikan celah $4.2\text{ cm}$ dari radius ban ($0.33\text{m}$). Untuk geometri AI yang bergelombang, radius potong spakbor sebaiknya dinaikkan menjadi $R \approx 0.380 - 0.385\text{m}$ agar tercipta *wheel arch clearance* yang estetik dan realistis seperti mobil GT3 sirkuit asli.

---

## 3. Instruksi Perbaikan Langkah-Demi-Langkah

Agent yang ditugaskan harus merevisi pipeline dan menghasilkan bodi yang bersih serta fitting sempurna:

### Langkah 3.1: Perbaiki Penempatan Ground Clearance di Blender Pipeline
Revisi formula pemosisian vertikal pada bodi mobil:
1. Titik terendah bodi mobil (kolong lantai / *flat floor*) **tidak boleh berada di bawah tanah** ($Y \ge +0.05\text{m}$ s.d. $+0.07\text{m}$).
2. Pertahankan ketinggian as roda modular standar GT3 pada **$Y = 0.33\text{m}$** di atas tanah ($0.0\text{m}$).
3. Lakukan pemotongan roda (*boolean cut*) berpusat tepat di koordinat as roda masing-masing sumur roda (depan dan belakang dihitung terpisah, bukan dipukul rata).

### Langkah 3.2: Kalibrasi Independen Socket Roda (Front Z, Rear Z, Front X, Rear X)
Untuk setiap mobil di `scratch/car_configs/<car_slug>.json` atau scene `.tscn`:
* `Socket_Wheel_FL` & `Socket_Wheel_FR`: Posisikan di `(-X_front, 0.33, Z_front)` dan `(X_front, 0.33, Z_front)`.
* `Socket_Wheel_RL` & `Socket_Wheel_RR`: Posisikan di `(-X_rear, 0.33, Z_rear)` dan `(X_rear, 0.33, Z_rear)`.
* Pastikan $Z_{front}$ dan $Z_{rear}$ berada tepat di pusat lengkungan spakbor hasil potongan silinder.
* Pastikan $X_{front}$ dan $X_{rear}$ membuat dinding luar ban rata (*flush*, toleransi celah $\le 1\text{ cm}$) dengan bibir spakbor terluar tanpa ada poligon bodi yang memotong ban.

### Langkah 3.3: Jalankan Ulang Refining & Ekspor
1. Jalankan `refine_car.py` untuk merekonstruksi bodi bersih `<car_slug>_body.glb` dan tekstur bake.
2. Perbarui `scenes/car/<car_slug>_chassis.tscn` dengan koordinat socket yang telah dikalibrasi.
3. Jalankan `scratch/build_full_car.py` untuk membangun kembali `<car_slug>_full.glb`.

---

## 4. Kriteria Kelulusan (Quality Gates & Verification)

Sebelum menyatakan tugas selesai, jalankan verifikasi berikut:

1. **Jalankan Diagnostik Geometris:**
   ```powershell
   & "C:\Users\Lee\Downloads\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe" --headless --path . -s scratch/diagnose_wheels.gd
   ```
   **Syarat Mutlak:**
   * `Clearance Ban-Fender`: Wajib $\ge +0.025\text{m}$ ($2.5\text{ cm}$) dan $\le +0.050\text{m}$ di seluruh 4 roda.
   * `Penetrating Verts`: Wajib **0 vertex** (Zero-Clipping).
   * `AABB Pos Y`: Wajib $\ge +0.040\text{m}$ (tidak ada bagian mobil yang tenggelam di bawah aspal).

2. **Jalankan Seluruh Suite Pengujian Godot:**
   ```powershell
   & "C:\Users\Lee\Downloads\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe" --headless --path . -s tests/test_modular_car.gd
   & "C:\Users\Lee\Downloads\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe" --headless --path . -s tests/test_audio_and_race_weekend.gd
   ```
   **Hasil:** Seluruh unit test wajib **100% PASS (0 FAIL)**.

3. **Tangkapan Layar Bukti Showroom:**
   * Ambil screenshot showroom tampak samping (`left_side`) dan tampak miring 3/4 (`showroom`) yang membuktikan celah roda rapi, proporsional, dan estetik.
   * Buat laporan eksekutif hasil perbaikan di `executor-report/FASE-7-WHEEL-FITMENT-REPAIR-REPORT.md`.
