# Spesifikasi Desain: 12-Month Circuit Calendar & Neo-Wangan Shuto Express Track

**Status Dokumen:** Proposed / In Review  
**Tanggal:** 27 Oktober 2026  
**Penulis:** AI Architecture & Engineering Team (La Voiture)  
**Terkait:** [PRD/00-MASTER-OVERVIEW.md](../../PRD/00-MASTER-OVERVIEW.md) · [ROADMAP.md](../../ROADMAP.md) · [DESIGN.md](../../DESIGN.md)

---

## 1. Ringkasan Eksekutif & Tujuan

Sebagai fondasi utama ekspansi fitur **Career Mode (Championship Season)**, game memerlukan kalender sirkuit kejuaraan resmi yang seimbang dan prestisius. Berdasarkan arahan pengguna, kalender dirancang mencakup **12 Ronde (1 Ronde per bulan, Januari s.d. Desember)** yang terbagi secara proporsional menjadi:
* **7 Sirkuit Grand Prix (GP)**: Panjang 4.16 – 5.80 km, lintasan lebar permanen, strategi ban & bensin penuh, *pit stop* krusial.
* **5 Sirkuit Sprint**: Panjang 2.85 – 3.85 km, sirkuit jalan raya sempit (*street circuits*) dan pegunungan (*touge*), pertarungan bodi agresif tanpa kompromi.

Sirkuit pertama yang diimplementasikan dari kalender ini adalah **Ronde 02: Neo-Wangan Shuto Express (新湾岸高速)**, sirkuit jalan raya malam perkotaan di pesisir Teluk Tokyo yang menghadirkan kontras visual dan dinamika balap 180 derajat berbeda dari sirkuit permanen yang sudah ada (*Apex Ring International*).

---

## 2. Kalender Resmi 12 Bulan (12 Rounds Championship Calendar)

Seluruh sirkuit mengambil inspirasi dari sirkuit balap legendaris dunia (*real-life circuits*) dengan tata letak tikungan teruji, namun diberi penamaan kota dan identitas fiksional bergaya *Anime-Streetwear GT3*:

| Ronde | Bulan | Nama Sirkuit Fiksional | Tipe | Inspirasi Nyata | Negara | Pjg (km) | Karakter Utama |
| :---: | :---: | :--- | :---: | :--- | :---: | :---: | :--- |
| **01** | JAN | **Apex Ring International** | **GP** | Fuji Speedway / Motegi | 🇯🇵 JPN | 4.16 | Lurusan 1.2 km, hairpin elevasi, kabut gunung *(Existing)*. |
| **02** | FEB | **Neo-Wangan Shuto Express** | **SPRINT** | Tokyo Shuto C1 / Marina Bay | 🇯🇵 JPN | 3.15 | Jalan tol layang malam, terowongan underpass, dinding beton. |
| **03** | MAR | **Autodromo di Brianza** | **GP** | Autodromo Nazionale Monza | 🇮🇹 ITA | 5.79 | Kuil kecepatan, chicane Variante, slipstream war ekstrem. |
| **04** | APR | **Monte Azure Marina** | **SPRINT** | Circuit de Monaco / Macau | 🇲🇨 MCO | 2.85 | Jalanan pelabuhan yacht sempit, zero margin error. |
| **05** | MAY | **Ardennes Valley Ring** | **GP** | Spa-Francorchamps | 🇧🇪 BEL | 5.40 | Tanjakan kompresi Eau Rouge, hujan mikro dinamis. |
| **06** | JUN | **Haruna Mountain Touge** | **SPRINT** | Mount Haruna / Gunma Pass | 🇯🇵 JPN | 2.90 | Aspal gunung 5 hairpin beruntun, selokan beton (gutter). |
| **07** | JUL | **Stoke Crown Circuit** | **GP** | Silverstone Circuit | 🇬🇧 GBR | 5.20 | Tikungan berkecepatan tinggi Maggotts-Becketts, high-G aero. |
| **08** | AUG | **Pacific Coast Corkscrew** | **SPRINT** | WeatherTech Laguna Seca | 🇺🇸 USA | 3.60 | Blind drop Corkscrew curam, debu pesisir California. |
| **09** | SEP | **Eifel Forest Ring** | **GP** | Nürburgring GP | 🇩🇪 GER | 5.15 | Hutan pinus berkabut, tikungan teknikal Schumacher S. |
| **10** | OCT | **Iron Mountain Ridge** | **SPRINT** | Mount Panorama Bathurst | 🇦🇺 AUS | 3.85 | Turunan gunung curam diapit dinding beton vertikal. |
| **11** | NOV | **Paulistano Speed Arena** | **GP** | Interlagos (Carlos Pace) | 🇧🇷 BRA | 4.31 | Counter-clockwise, turunan Senna 'S', tanjakan bowl finis. |
| **12** | DEC | **Kurogane Twin-Cross** | **GP** | Suzuka International | 🇯🇵 JPN | 5.80 | Figure-8 crossover bridge, Esses berirama, grand finale. |

---

## 3. Arsitektur Teknis Sirkuit: *Neo-Wangan Shuto Express*

### A. Parameter Fisik & Geometri Lintasan
* **Total Panjang Spline:** 3,150 meter (Curve3D loop kontinu).
* **Jumlah Tikungan:** 12 Tikungan (7 Kanan, 5 Kiri).
* **Arah Balapan:** *Clockwise* (Searah jarum jam).
* **Lebar Koridor Lintasan:** 11.5 meter (lebih padat dibanding Apex Ring 14.0 m untuk sensasi *street racing*).
* **Profil Elevasi Dinamis:**
  - Puncak Tertinggi (+6.5 m): Tengah bentang jembatan tol layang Shuto Bay Bridge (Sektor 1).
  - Titik Terendah (-3.2 m): Dasar terowongan bawah tanah *Cyber City Underpass* (Sektor 2).
  - Elevasi Dasar (0.0 m): *Main Straight*, area pitstop, dan *Harbor Hairpin*.

### B. Pembagian Sektor & Zona Overtake
1. **Sektor 1 (Shuto Bridge Straight — 950 m):**
   - Karakter: Jalan tol layang lurus berkecepatan tinggi melintasi teluk pelabuhan.
   - Puncak Kecepatan: Mencapai **278 km/jam** pada mobil GT3 dengan slipstream.
   - Zona Overtake: Pengereman keras 100 m dari kecepatan puncak menuju Turn 1 (tikungan siku 90° kanan).
2. **Sektor 2 (Cyber City Underpass & Shibuya S-Chicane — 1,220 m):**
   - Karakter: Masuk ke terowongan beton bawah tanah 180 m berlampu neon strip atap, lalu melesat keluar ke chicane ganda Turn 6 & 7 di antara gedung pencakar langit beriklan LED raksasa.
   - Zona Overtake: *Switchback chicane* memanfaatkan kelincahan sasis dan stabilitas suspensi.
3. **Sektor 3 (Harbor Concrete Hairpin & Pit Straight — 980 m):**
   - Karakter: Putar balik 180° sempit Turn 9 di samping pelabuhan kontainer industri dengan derek gantry raksasa, dilanjutkan akselerasi keluar menuju jalur lurus finis.
   - Zona Overtake: *Late-apex dive bomb* sebelum masuk ke main straight.

---

## 4. Rekayasa Sambungan Pitstop & Standar Keselamatan FIA

Untuk menghindari benturan fatal pada sirkuit jalan raya sempit, sambungan pitstop dibagi menjadi 3 zona terisolasi:

```
[RACING LINE 275 km/h ➔➔➔➔➔➔➔➔➔➔➔➔➔➔➔➔➔➔➔➔➔➔➔➔➔➔➔➔➔➔➔➔➔➔➔➔➔➔➔➔➔➔➔➔➔➔➔➔➔➔➔➔➔➔➔➔➔➔➔]
                \                                             /
  [PIT ENTRY] ---\--- [CRASH CUSHION]                        /--- [SOLID BLEND LINE]
                  \==================== [PIT WALL] =========/
                   [FAST LANE 60 km/h: 10 GARASI TIM (140 m)]
```

1. **Zona Pit Entry (Titik A):**
   - Terletak di sisi kanan lintasan, 75 meter sebelum garis finis.
   - Memiliki lajur deselerasi terpisah selebar 4.5 m sehingga mobil yang melambat ke batas pit limiter (80 km/jam) tidak menghalangi mobil yang mengejar *lap time* di sisi kiri (*racing line*).
   - Hidung dinding pemisah (*pit nose*) dipasangi peredam benturan oranye (*impact attenuator*) standar FIA.
2. **Zona Pit Lane 10 Garasi (Titik B):**
   - Panjang total 140 m dengan 10 stall tim berjarak masing-masing 12 meter.
   - Lebar Fast Lane 4.5 m dengan ruang gerak bebas 3.3 m agar mobil dapat melintas aman tanpa menyerempet mobil yang sedang servis ban di stall.
   - Dinding beton pemisah (*Pit Wall*) setinggi 1.2 m melindungi kru dan gantry kontrol dari hempasan angin kencang lintasan utama.
   - Mengintegrasikan kru 13 orang dinamis yang melangkah keluar saat mobil mendekat.
3. **Zona Pit Exit & Anti T-Bone Merge (Titik C):**
   - Jalur keluar pit diperpanjang melewati Turn 1 (*bypass ramp* sepanjang 65 m di sisi dalam).
   - Dilindungi oleh garis putih solid (*Solid FIA Blend Line*) sepanjang 80 meter. Mobil dilarang memotong garis ini ke *racing line* sebelum kecepatannya mencapai minimal 160 km/jam di zona akselerasi lurus.
   - Dilengkapi sinyal lampu pit exit otomatis (merah menyala saat Safety Car melintas).

---

## 5. Visual Konsep 4 Sudut Pandang (4 Key Views)

Seluruh 4 sudut pandang visual konsep telah di-generate menggunakan model canggih Meshy AI (*nano-banana-pro*) dan tersimpan permanen di repositori:

1. **View 1: Main Straight & Pitstop Complex**  
   `reference-assets/tracks/neo_wangan/view1_main_straight_pitstop.png`  
   *Menampilkan garis finis, gantry start truss baja berlampu FIA, dinding beton pit wall, gedung pit modern bertingkat kaca dengan 10 garasi aktif, dan aspal basah berhias pantulan neon malam Tokyo.*
2. **View 2: Sector 1 Shuto Bay Bridge (High-Speed Expressway)**  
   `reference-assets/tracks/neo_wangan/view2_shuto_bay_bridge.png`  
   *Menampilkan jalan tol layang melintasi teluk pelabuhan berhias menara jembatan gantung neon cyan & magenta, marka jalan tol hijau khas Jepang, dan siluet cakrawala gedung Tokyo di kejauhan.*
3. **View 3: Sector 2 Underpass Tunnel & Cyber S-Chicane**  
   `reference-assets/tracks/neo_wangan/view3_underpass_tunnel_chicane.png`  
   *Menampilkan momen mobil melesat keluar dari terowongan beton bawah tanah berlampu neon atap langsung menuju chicane S yang dikelilingi gedung pencakar langit dan papan reklame LED raksasa.*
4. **View 4: Sector 3 Harbor Docks Hairpin & Pit Entry Ramp**  
   `reference-assets/tracks/neo_wangan/view4_harbor_hairpin_pit_entry.png`  
   *Menampilkan tikungan putar balik 180° sempit di pelabuhan kontainer industri dengan derek gantry raksasa, bekas karet rem pekat di aspal, dan lajur deselerasi pit-in yang membelah ke kanan dengan peredam benturan oranye.*

---

## 6. Anggaran Kinerja & Rendering (Performance Budget)

| Metrik | Batas Anggaran | Solusi Teknis |
| :--- | :--- | :--- |
| **Framerate Target** | **60 FPS locked (16.66 ms)** | Mengunci vsync Forward+, level of detail mesh jalan, occluder culling untuk terowongan. |
| **Draw Calls Sirkuit** | $\le 160\text{ Draw Calls}$ | Seluruh dinding beton, tiang lampu jalan Tokyo, pagar kawat, dan kontainer pelabuhan wajib menggunakan `MultiMeshInstance3D`. |
| **Poligon Lingkungan** | $\le 320.000\text{ Triangles}$ | Gedung pencakar langit menggunakan low-poly geometry dengan window emission shader. |
| **Shader & Efek Visual** | Cel-Shaded Streetwear | Menggunakan varian shader `road_asphalt.gdshader` (puddle gloss, skid marks) dan reverb audio khusus knalpot di terowongan underpass. |

---

## 7. Rencana Integrasi & Quality Assurance (Testing Gates)

1. **Verifikasi Kurva Spline 3D:**
   - Memastikan panjang total loop terukur $3,150\text{ m} \pm 10\text{ m}$.
   - Memastikan radius kelengkungan kurva tidak ada yang kurang dari $R_{\min} = 18\text{ m}$ (aman untuk radius putar GT3).
2. **Verifikasi Sambungan Pitstop:**
   - Menjalankan uji headless verifikasi trigger area `PitEntryTrigger`, `PitExitTrigger`, dan koordinat 10 stall garasi.
   - Memastikan AI bot dapat mengeksekusi pit in dan pit out tanpa menabrak hidung barrier (*zero clipping*).
3. **Zero Regression Test:**
   - Seluruh 42 test suite headless yang ada tetap berstatus **100% PASS (0 FAIL)**.
   - Penambahan test suite baru: `tests/test_neo_wangan_circuit.gd`.
