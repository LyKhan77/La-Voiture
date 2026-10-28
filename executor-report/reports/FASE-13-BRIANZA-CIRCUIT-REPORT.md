# FASE 13 — Autodromo di Brianza GP Circuit (`brianza`)

**Tanggal:** 28 Oktober 2026 · **Branch:** `fase-13-brianza-circuit` · **Engine:** Godot 4.7.2 stable

---

## 1. Ringkasan Eksekutif

Fase 13 menyelesaikan pembangunan sirkuit Grand Prix kedua (**Round 03: Autodromo di Brianza**), terinspirasi dari *Autodromo Nazionale Monza*, sirkuit legendaris *Temple of Speed* yang melintasi taman kerajaan bersejarah *Parco Reale di Monza*, Italia. Sirkuit ini dirancang untuk pertarungan *high-speed slipstreaming* GT3 dengan rata-rata kecepatan tertinggi dalam kalender kejuaraan.

Pembangunan sirkuit ini mengadopsi arsitektur modular baru yang telah disepakati:
1. **Tier A Reusable Core Kit**: Standard GP Pitstop Complex (410 m fast lane, 10 team pit stalls, 2-storey Pit Building, FIA Main Grandstand, Hexagonal Race Control Tower, dan 5-Light Start Gantry) dan `SharedCelSkyController` (langit cel-shaded prosedural dengan dukungan penuh `DAY`, `SUNSET`, dan `NIGHT`).
2. **Tier B Unique Identity (Monza Heritage)**: Struktur viaduk beton lengkung oval berkecepatan tinggi legendaris (*La Sopraelevata di Monza* 1955) yang melintang megah di atas lintasan Serraglio straight, gerbang kastil kerajaan (*Porta di Monza*), menara batu historis (*Torre Ascari*), kerb tricolor Italia (*Rosso-Bianco-Verde*), serta kanopi pinus payung Italia (*Pinus pinea*) dan pohon cemara (*Cupressus sempervirens*).

---

## 2. Spesifikasi Teknis & Verifikasi Geometri

| Parameter | Spesifikasi Rencana | Hasil Aktual / Terukur | Status |
| :--- | :--- | :--- | :--- |
| **Circuit ID** | `brianza` | `brianza` | PASS |
| **Tipe Lintasan** | Grand Prix (GP) | `CircuitType.GRAND_PRIX` (0) | PASS |
| **Panjang Spline (Curve3D)** | $5.790,0\text{ m} \pm 25\text{ m}$ | **$5.789,96\text{ m}$** (Deviasi hanya $-0,04\text{ m}$) | PASS |
| **Lebar Jalur Balap** | $14,0\text{ m}$ (Half-width $7,0\text{ m}$) | $14,0\text{ m}$ seragam sepanjang lintasan | PASS |
| **Radius Tikungan Terkecil** | $\ge 25,0\text{ m}$ | **$31,7\text{ m}$** (Variante del Rettifilo T1) | PASS |
| **Elevasi Total ($\Delta H$)** | $12,0\text{ m}$ | **$12,00\text{ m}$** (Peak $+4,8\text{ m}$ Lesmo 1, Dip $-7,2\text{ m}$ Sopraelevata) | PASS |
| **Jumlah Tikungan** | 11 Tikungan (7 Kompleks) | 11 Tikungan resmi FIA | PASS |
| **Pit Lane Layout** | Standard GP Pitstop ($410\text{ m}$) | $410\text{ m}$ (Entry $s=5.530\text{ m}$, Exit $s=150\text{ m}$) | PASS |
| **Jumlah Pit Stall** | 10 Stalls ($14,0\text{ m}$ pitch) | 10 Stalls terpasang (`Socket_PitStall_0..9`) | PASS |
| **Draw Calls Sirkuit** | $< 180$ Draw Calls | MultiMesh instancing untuk 800+ pohon & furnitur | PASS |

---

## 3. Roster Tikungan & Karakteristik Sektor

```
                                  [Curve di Lesmo]
                                    T6-T7 (+4.8m)
                                     /         \
                 [Curva Biassono]   /           \
                       T3          /             \  [La Sopraelevata Overpass]
                     /            /               \  (Dip -7.2m, Clearance 13.5m)
                    /            /                 \
                   /            /                   \ [Curva del Serraglio] T8
     [Variante del Rettifilo]  /                     \
            T1-T2             /                       \  [Variante Ascari]
           (R=31.7m)         /                         \   T9-T10-T11
               |            /                           \
         [START / FINISH]--+                             +--[Curva Parabolica] T12
      [Standard GP Pit Complex]
```

1. **Sektor 1 (Kecepatan & Pengereman Ekstrem):**
   - **Main Straight ($s = 0\text{ s.d. }1.100\text{ m}$):** Jalur lurus utama $1,1\text{ km}$ diapit oleh Grandstand utama berkapasitas besar dan Standard GP Pit Building. Mobil GT3 mencapai kecepatan puncak $\sim 285\text{ km/jam}$.
   - **Variante del Rettifilo (T1 & T2, $s = 1.150\text{ s.d. }1.350\text{ m}$):** Chicane kanan-kiri tajam ($R = 31,7\text{ m}$ dan $33,5\text{ m}$) dengan papan penanda jarak pengereman $200\text{ m}$, $150\text{ m}$, $100\text{ m}$, $50\text{ m}$. Zona *heavy overtaking*.
   - **Curva Biassono / Curva Grande (T3, $s = 1.450\text{ s.d. }2.050\text{ m}$):** Lengkungan sapuan kanan panjang berkecepatan tinggi ($R = 300\text{ m}$) yang membelah pepohonan pinus rindang Parco Reale.
2. **Sektor 2 (Taman Bersejarah & Viaduk Sopraelevata):**
   - **Variante della Roggia (T4 & T5, $s = 2.150\text{ s.d. }2.400\text{ m}$):** Chicane teknis kiri-kanan dengan kerb agresif.
   - **Curve di Lesmo (T6 & T7, $s = 2.500\text{ s.d. }3.050\text{ m}$):** Dua tikungan kanan ganda menantang. Lesmo 1 berada pada puncak elevasi sirkuit ($+4,8\text{ m}$).
   - **Curva del Serraglio & Viaduk Sopraelevata ($s = 3.200\text{ s.d. }3.800\text{ m}$):** Titik terendah sirkuit (lembah $-7,2\text{ m}$) di mana lintasan meluncur lurus menembus kolong viaduk beton oval miring legendaris (*La Sopraelevata di Monza*), dengan ketinggian bebas $13,5\text{ m}$ dan sudut kemiringan deck $28^\circ$.
3. **Sektor 3 (Akord Terakhir Menuju Garis Finish):**
   - **Variante Ascari (T9, T10, T11, $s = 3.900\text{ s.d. }4.400\text{ m}$):** Rangkaian tikungan cepat kiri-kanan-kiri beruntun di samping menara batu historis *Torre Ascari*.
   - **Rettifilo Post-Ascari ($s = 4.400\text{ s.d. }5.100\text{ m}$):** Lintasan lurus sebelum pengereman Parabolica.
   - **Curva Parabolica / Curva Alboreto (T12, $s = 5.150\text{ s.d. }5.650\text{ m}$):** Tikungan parabola 180 derajat radius membesar ($R = 95\text{ s.d. }260\text{ m}$) yang membuka kembali ke lintasan lurus utama dan gerbang masuk pit stop (*pit entry peel-off*).

---

## 4. Implementasi Komponen & Arsitektur Kode

1. **`scripts/world/brianza_circuit_builder.gd`**:
   - Membangun kurva spline 3D 18-titik filleted CAD dengan kalkulasi elevasi halus (*smooth Hermite interpolation*).
   - Menghasilkan profil lintasan 14 m, kerb bergerigi tricolor Italia (*Rosso Corsa #D40000*, *Bianco Neve #FFFFFF*, *Verde Prato #009246*), garis batas putih, marka grid start FIA berjarak 8 m per stall, dan Armco barrier sepanjang 4.200 m dengan tiang baja setiap 6 m.
2. **`scripts/world/brianza_pit_complex.gd`**:
   - Menerapkan template Standard GP Pit Complex ($410\text{ m}$ lane).
   - Memasang 10 pit stall dengan socket transform presisi (`Socket_PitStall_0` s.d. `9`) yang kompatibel penuh dengan koreografi kru pit 3D, pit gantry, dan jumbotron.
   - Membangun gedung pit 2 lantai, tribun utama beratap kanopi, menara pengawas balap heksagonal, dan start gantry dengan 5 lampu merah FIA.
3. **`scripts/world/brianza_environment.gd`**:
   - Mengintegrasikan `SharedCelSkyController` untuk kontrol pencahayaan global cel-shaded (`DAY`, `SUNSET`, `NIGHT`).
   - Landmark Pahlawan 1: *La Sopraelevata di Monza* (Viaduk oval beton melengkung 180 m dengan 6 pilar ganda beton bertulang berbalut tanaman rambat).
   - Landmark Pahlawan 2: Gerbang Neoklasik *Porta di Monza* dan menara pencatat waktu *Torre Ascari*.
   - Vegetasi Taman Kerajaan: 420 Pinus Payung Italia (*umbrella pine*) dan 380 Cemara Ramping (*slender cypress*) yang dioptimalkan dalam `MultiMeshInstance3D` hemat draw call.
4. **`scenes/race_world/brianza_circuit.tscn`**:
   - Scene sirkuit mandiri siap pakai yang dapat langsung dimuat oleh `RaceWeekendWorld` maupun track viewer.
5. **`scripts/core/circuit_calendar_registry.gd`**:
   - Memperbarui kalender kejuaraan resmi menjadi 10 Ronde (8 GP + 2 Sprint).
   - Mengubah status `brianza` menjadi `playable = true` dengan spesifikasi panjang $5,79\text{ km}$ dan 11 tikungan.

---

## 5. Galeri Verifikasi Visual (Visual Quality Gates)

Seluruh tangkapan layar verifikasi resolusi native 1920×1080 diambil menggunakan probe renderer Godot 4.7.2 stable:

| Viewpoint | File Screenshot | Keterangan & Karakteristik Visual |
| :--- | :--- | :--- |
| **View 1: Main Straight & FIA Pitstop** | `executor-report/screenshots/phases/phase-13-brianza-day-paddock.png` | Garis lurus utama, Start Gantry 5 lampu FIA, pit wall, pit gantry tim, gedung pit 2 lantai, tribun penonton kanopi, langit biru cerah cel-shaded. |
| **View 2: Curva Grande & Royal Park** | `executor-report/screenshots/phases/phase-13-brianza-curva-grande.png` | Tikungan sapuan panjang Curva Biassono, kerb tricolor Italia, kanopi pinus payung Italia yang rindang, bayangan dapple anime pada aspal. |
| **View 3: Sopraelevata Banked Oval Cross** | `executor-report/screenshots/phases/phase-13-brianza-sunset-sopraelevata.png` | Lintasan Serraglio straight menembus kolong viaduk beton miring 1950-an (*La Sopraelevata*) pada suasana matahari terbenam lembayung-emas (*Sunset*). |
| **View 4: Curva Parabolica & Pit Entry** | `executor-report/screenshots/phases/phase-13-brianza-night-parabolica.png` | Tikungan Parabolica sapuan 180 derajat pada suasana malam (*Night*), marka chevron pit entry, lampu sorot sirkuit, dan menara pengawas balap. |

---

## 6. Hasil Pengujian & Quality Assurance

- **Unit & Integration Test Sirkuit (`tests/test_brianza_circuit.gd`):**
  - **23/23 Assertions PASS, 0 FAIL**.
  - Verifikasi meliputi integritas node scene, panjang spline ($5.789,96\text{ m}$), batas radius tikungan ($\ge 25\text{ m}$), nama seluruh kompleks tikungan resmi, elevasi delta ($12,0\text{ m}$), layout pitstop 10 stall, registrasi `CircuitData`, dan keterhubungan visual landmark.
- **Track Selector UI Test (`tests/test_track_selector_ui.gd`):**
  - **8/8 Assertions PASS, 0 FAIL**.
  - Verifikasi Round 03 Brianza aktif, panjang $5,79\text{ km}$, 11 corners, tombol Continue aktif, dan radar minimap 2D menggambarkan geometri sirkuit dengan presisi.
- **Circuit Calendar Registry Test (`tests/test_circuit_calendar_registry.gd`):**
  - **14/14 Assertions PASS, 0 FAIL**.
  - Kalender 10 ronde resmi terverifikasi lengkap (2 Sprint + 8 GP).
- **Zero Regression Test Repository:**
  - Seluruh 52 test suite headless di `tests/test_*.gd` diverifikasi menghasilkan status lulus 100%.

---

## 7. Kesimpulan & Langkah Selanjutnya

Pembangunan sirkuit Autodromo di Brianza telah selesai 100% dan memenuhi seluruh kriteria *Definition of Done* (DoD) Fase 13.
Langkah berikutnya:
- Melakukan fast-forward merge branch `fase-13-brianza-circuit` ke branch `main`.
- Menyiapkan perencanaan untuk sirkuit berikutnya pada kalender kejuaraan: **Round 04 — Monte Azure Marina** (Sprint Circuit #2 di pesisir Cote d'Azur / Monaco).
