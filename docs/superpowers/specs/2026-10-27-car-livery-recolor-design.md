# Desain Teknis: Penyelarasan Livery Mobil GT3 ke Tema Tim (La Voiture)

**Tanggal:** 2026-10-27  
**Status:** Approved by User  
**Pendekatan Terpilih:** Opsi A — Direct PBR Texture Recoloring dengan Mekanisme Backup & Fallback Mandiri  

---

## 1. Latar Belakang & Tujuan
Saat ini beberapa mobil GT3 di dalam game masih mengenakan livery pabrikan/bawaan model mentah 3D yang warnanya tidak sesuai dengan identitas warna resmi tim dan karakter pembalap di *La Voiture*:
* **Aston Martin Vantage (Team 04: Razorline):** Hijau tua (*British Racing Green*) $\rightarrow$ seharusnya **Electric Magenta** (`#D946EF`) & Razor Silver.
* **Lamborghini Huracán (Team 09: Night Shift):** Hijau neon (*Verde Mantis*) $\rightarrow$ seharusnya **Ultra Violet / Deep Purple** (`#9B5CFF`) & Void Black.
* **McLaren 720S (Team 08: Chrome Syndicate):** Oranye (*Papaya Orange*) $\rightarrow$ seharusnya **Mint Emerald Green** (`#00E08A`) & Liquid Chrome.
* **Lexus RC F (Team 07: Static Speed):** Hitam karbon polos $\rightarrow$ seharusnya **Snow White** (`#F4F5F7`) & Pitch Ink.
* **BMW M4 (Team 03: Vanta Motors):** Decal M-Sport biru/merah $\rightarrow$ seharusnya **Cyber Yellow** (`#FFE600`) & Pitch Black Vanta.
* Serta penyesuaian aksen untuk mobil lainnya (Corvette Z06 ke Blaze Orange `#FF7A00`, Audi R8 ke Electric Cyan `#00F0FF`, Mercedes-AMG ke Acid Lime `#CCFF00`, Nissan GT-R ke Anime Crimson `#FF1E56`, Honda NSX ke Cobalt Blue `#3D7BFF`).

Target teknis adalah menyelaraskan warna bodi mobil ke tema tim resmi tanpa mengorbankan performa (tetap 60 FPS locked), dengan proteksi detail material (serat karbon, kaca, lampu, radiator grill), serta menyediakan **fitur fallback instan** bila pengguna ingin kembali ke livery original pabrikan.

---

## 2. Arsitektur & Mekanisme Backup & Fallback

Untuk menjamin kebebasan pemain/developer mengembalikan tampilan kapan saja tanpa risiko kehilangan file asli:

### A. Struktur File Aset Tekstur
Setiap folder mobil yang direcolor akan memiliki skema cadangan:
```
assets/cars/<slug>/textures/
├── base_color_original.png   # Backup permanen file asli pabrikan (read-only/arkip)
├── base_color_team.png       # Tekstur hasil recolor tema tim resmi
├── base_color.png            # Tekstur aktif yang dimuat oleh Godot Engine
├── normal.png                # Relief panel & normal map (tidak diubah)
└── orm.png                   # Occlusion, Roughness, Metallic (tidak diubah)
```

### B. Tool Pengendali Livery (`tools/manage_car_livery.py`)
Disediakan skrip CLI Python untuk beralih mode dengan mudah:
* **Menerapkan Livery Tim:**  
  `python tools/manage_car_livery.py --action apply --all`  
  (atau per mobil: `python tools/manage_car_livery.py --action apply --car aston_vantage`)
* **Mengembalikan ke Livery Asli (Fallback):**  
  `python tools/manage_car_livery.py --action restore --all`  
  (atau per mobil: `python tools/manage_car_livery.py --action restore --car aston_vantage`)

---

## 3. Algoritma Transformasi Warna & Proteksi Detail

Transformasi warna dijalankan menggunakan script image processing presisi berbasis ruang warna HSV/HSL:
1. **Hue & Saturation Isolation:**
   - Menghitung nilai *Hue* ($0^\circ - 360^\circ$) dan *Saturation* ($0.0 - 1.0$) per piksel.
   - Hanya piksel dalam rentang Hue sumber dan memiliki saturasi minimal ($S \ge 0.15$) yang ditransformasi.
2. **Detail & Material Preservation:**
   - **Serat Karbon, Kaca, Chrome, & Ban:** Memiliki saturasi sangat rendah ($S < 0.15$), sehingga bobot perubahan menjadi 0 dan tekstur material asli 100% terjaga.
   - **Lampu Depan & Belakang:** Masking koordinat UV atau rentang saturasi melindungi elemen lensa lampu dan emblem pabrikan.
   - **Luminansi Asli (Value/Lightness):** Nilai kecerahan dan bayangan permukaan dipertahankan ($V_{\text{new}} = V_{\text{orig}} \times \text{TargetColor}$), menjamin kontur bodi tetap memiliki kedalaman 3D yang realistis.
3. **PBR Compatibility:**
   - Peta `normal.png` dan `orm.png` tidak dimodifikasi sama sekali, sehingga efek cel-shading, specularity, dan inverted-hull outlines di Godot tetap berjalan 100% konsisten.

---

## 4. Roster Mapping & Penyesuaian Tim

| Tim ID | Nama Tim | Car Slug | Model Mobil | Warna Livery Target | Aksi Transformasi |
|:---:|:---|:---|:---|:---|:---|
| 00 | Apex Racing | `mercedes_amg` | Mercedes-AMG GT3 Evo | Acid Lime (`#CCFF00`) | Aksen lime pada splitter, aero, diffuser |
| 01 | Neon Drift | `audi_r8` | Audi R8 LMS GT3 | Electric Cyan (`#00F0FF`) | Shift strip merah ke Electric Cyan |
| 02 | Kurogane GT | `nissan_gtr` | Nissan GT-R NISMO | Anime Crimson (`#FF1E56`) | Aksen crimson bodi & striping |
| 03 | Vanta Motors | `bmw_m4` | BMW M4 GT3 | Cyber Yellow (`#FFE600`) | Shift aksen M-Sport ke Cyber Yellow |
| 04 | Razorline | `aston_vantage` | Aston Martin Vantage | Electric Magenta (`#D946EF`) | **Full Recolor** (Hijau $\rightarrow$ Magenta) |
| 05 | Zero Hour | `chevy_corvette` | Corvette Z06 GT3.R | Blaze Orange (`#FF7A00`) | Shift kuning ke Blaze Orange |
| 06 | Oni Works | `honda_nsx` | Honda NSX GT3 Evo22 | Cobalt Blue (`#3D7BFF`) | Aksen Cobalt Blue pada panel bodi |
| 07 | Static Speed | `lexus_rcf` | Lexus RC F GT3 | Snow White (`#F4F5F7`) | **Full Recolor** (Hitam $\rightarrow$ Putih Bersih) |
| 08 | Chrome Syndicate | `mclaren_720s` | McLaren 720S GT3 Evo | Mint Emerald (`#00E08A`) | **Full Recolor** (Oranye $\rightarrow$ Mint Green) |
| 09 | Night Shift | `lambo_huracan` | Huracán GT3 EVO2 | Ultra Violet (`#9B5CFF`) | **Full Recolor** (Hijau $\rightarrow$ Purple) |
| 10 | Scuderia Maranello | `ferrari_296` | Ferrari 296 GT3 | Rosso Corsa (`#D40000`) | Dipertahankan (Sudah akurat) |
| 11 | Ironhorse Motorsport | `ford_mustang` | Ford Mustang GT3 | Steel Navy (`#1E3A8A`) | Dipertahankan (Sudah akurat) |
| 12 | Neo-Wangan Works | `toyota_supra` | Toyota Supra GT | Pearl White (`#E2E8F0`) | Dipertahankan (Sudah akurat) |

---

## 5. Rencana Verifikasi & Uji Kualitas (DoD)
1. **Verifikasi Tekstur & Fallback:**
   - Menguji perintah `python tools/manage_car_livery.py --action apply` dan `python tools/manage_car_livery.py --action restore` untuk memastikan transisi bolak-balik berjalan sempurna.
2. **Zero Regression Test:**
   - Menjalankan 42 test suite headless Godot (`scratch/run_all_tests.ps1`) untuk memastikan **100% PASS, 0 FAIL**.
3. **In-Engine Smoke Test:**
   - Memastikan mobil di 3D Garage (`garage_team_select.tscn`) dan balapan 20 mobil (`race_weekend_world.tscn`) memuat tekstur baru tanpa hitch atau artefak visual.
