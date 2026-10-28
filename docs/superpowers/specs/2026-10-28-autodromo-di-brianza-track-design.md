# Spesifikasi Desain: Autodromo di Brianza (GP Round 03)

**Status Dokumen:** Proposed / In Review  
**Tanggal:** 28 Oktober 2026  
**Penulis:** AI Architecture & Engineering Team (La Voiture)  
**Terkait:** [`Circuit-Environment-Component-Guide.md`](../../Circuit-Environment-Component-Guide.md) · [`ROADMAP.md`](../../ROADMAP.md) · [`DESIGN.md`](../../DESIGN.md)

---

## 1. Ringkasan Eksekutif & Karakter Sirkuit

**Autodromo di Brianza** adalah sirkuit Ronde 03 pada kalender kejuaraan resmi *La Voiture*, yang mengambil inspirasi langsung dari sirkuit paling bersejarah di dunia: **Autodromo Nazionale Monza** di Italia (*"The Temple of Speed"*).

Sirkuit ini menghadirkan pertempuran kecepatan tertinggi (*high-speed slipstream wars*) di seluruh kalender, dipadukan dengan zona pengereman brutal (*heavy braking zones*) dari kecepatan hampir 300 km/jam menuju chicane sempit, di tengah suasana taman kerajaan Italia yang megah (**Parco Reale di Monza**) dengan pohon pinus payung (*umbrella pines*), cemara ramping (*cypress*), serta sisa reruntuhan sirkuit oval beton bertingkat legendaris tahun 1950-an (**La Sopraelevata di Monza**).

### Parameter Kunci Sirkuit:
* **Tipe Sirkuit:** Grand Prix (GP) — Mendukung opsi balapan 5, 10, dan 15 Lap (Endurance).
* **Panjang Spline Resmi:** **5,790 meter** (5.79 km).
* **Jumlah Tikungan:** 11 Tikungan (4 Kiri, 7 Kanan).
* **Arah Balapan:** *Clockwise* (Searah jarum jam).
* **Lebar Koridor Lintasan:** 14.0 meter (standar FIA GP dengan gravel trap luas dan runoff aspal bertingkat).
* **Elevasi Maksimal Delta:** 12.0 meter (kontur taman bergelombang lembut dengan turunan Serraglio dan tanjakan Parabolica).
* **Target Kecepatan Puncak (GT3):** **292 – 298 km/jam** di Main Straight dan Rettifilo Posteriore.

---

## 2. Tata Letak Sektor & Dinamika Balap (11 Corners)

```
                       [CURVA BIASSONO / GRANDE] (T3)
                              /              \
         [VARIANTE DEL RETTIFILO] (T1-T2)     \
                |                              \
         [MAIN STRAIGHT (1.1 km)]            [VARIANTE DELLA ROGGIA] (T4-T5)
                |                                      |
         [START / FINISH (s=0)]               [LESMO 1 & LESMO 2] (T6-T7)
                |                                      |
         [CURVA PARABOLICA] (T11)            [SERRAGLIO & SOPRAELEVATA BRIDGE]
                \                                      /
                 \--- [RETTIFILO POSTERIORE] --- [VARIANTE ASCARI] (T8-T10)
```

### Rincian Sektor Balapan:

#### Sektor 1: The Temple Straight & Variante del Rettifilo (`s = 0` s.d. `1,600 m`)
* **Main Straight (`s = 5,250 m` s.d. `580 m`):** Trek lurus utama selebar 14 meter sepanjang 1.1 km. Mobil GT3 berakselerasi penuh melewati grandstand utama, pit wall FIA, dan gantry start.
* **Turn 1 & 2 — Variante del Rettifilo (`s = 580 m` s.d. `760 m`):** Zona pengereman terkeras di kalender balap. Mobil melambat drastis dari 295 km/jam ke 72 km/jam dalam jarak 120 meter. Chicane sempit kanan-kiri dengan kerb berundak merah-putih-hijau Italia dan *sausage kerbs* kuning pencegah pemotongan lintasan.
* **Turn 3 — Curva Biassono / Curva Grande (`s = 980 m` s.d. `1,520 m`):** Tikungan kanan berkecepatan tinggi melengkung panjang di bawah kanopi rindang pohon pinus payung (*Pinus pinea*). Dilalui pada kecepatan 245–260 km/jam dengan gaya sentrifugal tinggi.

#### Sektor 2: Royal Woods & Historic Overpass (`s = 1,600 m` s.d. `3,650 m`)
* **Turn 4 & 5 — Variante della Roggia (`s = 1,880 m` s.d. `2,080 m`):** Pengereman keras dari 275 km/jam menuju chicane kiri-kanan teknikal di antara barisan pohon cemara tinggi.
* **Turn 6 & 7 — Curve di Lesmo 1 & 2 (`s = 2,320 m` s.d. `2,750 m`):** Dua tikungan kanan bersudut medium yang menuntut presisi aerodinamika tinggi. Lesmo 1 agak miring ke dalam (*camber positive*), sedangkan Lesmo 2 membuka ke arah jalur lurus Serraglio.
* **Serraglio Straight & Sopraelevata Overpass (`s = 2,750 m` s.d. `3,650 m`):** Jalur lurus menurun lembut yang melintas tepat di bawah lengkungan monumen beton bersejarah **La Sopraelevata di Monza** (oval banking tahun 1950-an), menghasilkan bayangan manga kontras tinggi saat siang hari.

#### Sektor 3: Ascari Chicane & The Legend of Parabolica (`s = 3,650 m` s.d. `5,790 m`)
* **Turn 8, 9 & 10 — Variante Ascari (`s = 3,650 m` s.d. `4,120 m`):** Kompleks chicane cepat kiri-kanan-kiri yang agresif. Mobil GT3 melompat di atas kerb datar pada kecepatan 175–205 km/jam.
* **Rettifilo Posteriore (`s = 4,120 m` s.d. `4,980 m`):** Trek lurus belakang sepanjang 860 meter, zona *slipstream* kedua untuk menyalip sebelum pengereman masuk ke tikungan terakhir.
* **Turn 11 — Curva Parabolica / Curva Alboreto (`s = 4,980 m` s.d. `5,480 m`):** Tikungan radius membesar 180° ke kanan. Mobil masuk pada 140 km/jam dan terus membuka gas secara bertahap hingga keluar di 220 km/jam langsung menuju garis finis dan percabangan pit entry.

---

## 3. Penerapan Arsitektur 2-Tier (`Circuit-Environment-Component-Guide` v2.0)

### A. TIER A: REUSABLE CORE KIT (100% Menggunakan Modul Bersama)

1. **Track Corridor Kit:**
   - Aspal: Menggunakan `road_asphalt.gdshader` dengan alur karet balap dinamis (*RubberGroove*) dan genangan air hujan procedural saat cuaca basah.
   - Kerbs: Sawtooth FIA Kerbs bergaris tricolor Italia (Hijau `#009246`, Putih `#F1F2F1`, Merah `#CE2B37`).
   - Runoff & Gravel: Gravel trap batu kerikil berpori (*gravel.gdshader*) di luar Lesmo, Roggia, dan Parabolica.
   - Papan Pengereman: Papan marka rem 150m, 100m, dan 50m di titik pengereman Rettifilo, Roggia, dan Ascari.
2. **Shared FIA Paddock & Infrastructure Kit:**
   - **Preset Pitstop:** Memanfaatkan **Standard GP Pit Complex** (`PitLaneComplex.gd`, panjang 410 meter, 10 garasi berjarak 14 meter per tim).
   - *Pit Entry:* Membelok ke kanan di `s = 5,530 m` (sepanjang 260 m sebelum `s = 0`).
   - *Pit Exit:* Menyatu kembali secara aman di `s = +150 m` (300 m sebelum zona rem Turn 1).
   - Bangunan Paddock: Memasang `PitBuilding` 2 lantai, `MainGrandstand` dengan Jumbotron live telemetry, dan `RaceControlTower`.
3. **Shared Cel-Skybox & Ambience (`SharedCelSkyController.gd`):**
   - Mendukung penuh 3 segmen waktu:
     - **DAY:** Langit biru Mediterania cerah, matahari anime terang, awan 3D cel-shaded berarak santai.
     - **SUNSET:** Langit tembaga keemasan hangat khas senja Lombardy, bayangan panjang di bawah pepohonan taman kerajaan.
     - **NIGHT:** Langit biru indigo malam dengan 900 bintang berkedip, bulan sabit halftone bersinar di atas reruntuhan Sopraelevata, serta lampu stadion menyala otomatis.

---

### B. TIER B: IMPROVISED BIOME & HERO LANDMARKS (Kustom Monza/Brianza)

1. **Biome Taman Kerajaan (Royal Park Vegetation):**
   - Menggunakan instancing `MultiMeshInstance3D` untuk 2 jenis pohon khas:
     - **Stone Pine (*Pinus pinea*):** Pohon pinus payung dengan kanopi daun mendatar lebar berwarna hijau zaitun toon.
     - **Italian Cypress (*Cupressus sempervirens*):** Pohon cemara tegak ramping berwarna hijau tua pekat.
   - Dilengkapi *wind sway* lembut yang bereaksi terhadap parameter `wind_speed`.
2. **Hero Landmark 1: Historic Concrete Banked Oval Overpass (*La Sopraelevata di Monza*)**
   - Struktur jembatan layang beton bertebing curam (kemiringan sudut $30^\circ$) yang melintang di atas lintasan Serraglio.
   - Shader: Beton usang bergaris tinta manga (*manga ink cracks*) dan tekstur lumut/patina 2-tone.
3. **Hero Landmark 2: Old Royal Park Villa & Paddock Archway (*Villa Reale Gate*)**
   - Gerbang bata merah neoklasik Italia abad ke-19 yang berdiri di pintu masuk paddock belakang grandstand.
4. **Hero Landmark 3: Torre Ascari & Historic Heritage Gantry**
   - Menara pengawas vintage di pintu masuk chicane Ascari dengan papan sponsor retro Agip/Pirelli berbayang halftone.

---

## 4. Anggaran Performa & Standar Visual Gate

| Parameter | Batas Anggaran | Target Brianza |
| :--- | :--- | :--- |
| **Draw Calls Sirkuit** | $\le 160\text{ Draw Calls}$ | 110 – 140 draw calls (GPU MultiMesh instancing untuk 1,800+ pohon & pembatas). |
| **Poligon Lingkungan** | $\le 320.000\text{ Triangles}$ | ~240,000 triangles total scene. |
| **Framerate Target** | **60 FPS locked (16.66 ms)** | 60 FPS pada resolusi 1080p High Preset dengan 20 mobil GT3. |
| **Gaya Visual** | Cel-Shaded Anime | 100% shader menggunakan stepped toon lighting, ink outline, dan halftone screentone. |
| **Verifikasi Kamera** | 6 Sudut Pandang Wajib | Cam 1 (Start/Pit), Cam 2 (Curva Grande), Cam 3 (Sopraelevata Overpass), Cam 4 (Parabolica Pit Entry), Cam 5 (Sky & Horizon Overview), Cam 6 (Chase Cam Action). |
