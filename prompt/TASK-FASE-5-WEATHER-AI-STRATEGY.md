# TASK SPECIFICATION: FASE 5 — WEATHER DYNAMICS, AI RIVAL STRATEGIST & SAFETY CAR

**Task ID:** `TASK-FASE-5-WEATHER-AI-STRATEGY`  
**Assignee:** Executor Agent (Godot Gameplay AI & Simulation Systems)  
**Priority:** High (Completing Core Tactical Gameplay Loop)  
**Engine:** Godot Engine 4.7.2 (`C:\Users\Lee\Downloads\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe`)  
**Workspace:** `D:\Occupation\Porto\genex\La_Voiture`  
**Reference Docs:**
- `PRD/05-GAMEPLAY-SYSTEMS-CAREER.md` (Pohon Keputusan AI, Siklus Cuaca, Safety Car)
- `PRD/01-CORE-SIMULATION-ENGINE.md` (Model Ban & Rumus Grip Wetness)
- `DESIGN.md` (Pit Wall Topology, Manga VFX, Weather Widget)
- `docs/superpowers/handoffs/FASE-5-AI-RIVAL-WEATHER-HQ.md`

---

## 1. Ringkasan & Ruang Lingkup (Scope)

Fase 5 menghidupkan dinamika taktis balapan GT3 dengan mengimplementasikan simulasi cuaca dinamis, kecerdasan buatan tim rival (18 mobil / 9 tim), mobil pengaman (*Safety Car*), integrasi radar cuaca di Pit Wall, serta shader visual aspal basah.

### Deliverables:
1. **`scripts/core/weather_manager.gd`**: Engine cuaca dinamis (State Machine, akumulasi air hujan, *drying racing line*, ambient temperature drop).
2. **`scripts/core/ai_race_director.gd`**: Manajer strategi untuk 18 mobil rival (taktik *undercut*, manajemen keausan ban, reaksi cepat terhadap hujan/trek mengering).
3. **`scripts/core/safety_car_director.gd`**: Logika mobil pengaman (*Safety Car* / VSC), kompresi jarak antarmobil, pembatasan kecepatan maksimum 120 km/jam, dan peluang *cheap pit stop*.
4. **Visual Wet Track & Manga Rain:**
   - Update shader sirkuit [`assets/shaders/track_ribbon.gdshader`](file:///D:/Occupation/Porto/genex/La_Voiture/assets/shaders/track_ribbon.gdshader) untuk mendukung pantulan genangan air (*gloss/specular wet road*).
   - Efek garis hujan manga (*anime rain speed streaks*) di kamera balap 3D.
5. **Integrasi Pit Wall Dashboard:**
   - Widget mini-radar cuaca di ribbon Pit Wall ([`scripts/ui/pit_wall_dashboard.gd`](file:///D:/Occupation/Porto/genex/La_Voiture/scripts/ui/pit_wall_dashboard.gd)) dengan indikator status, grafik kebasahan, dan prediksi cuaca 5 lap ke depan.
   - Radio cut-in suara kru: *"TRACK WETNESS EXCEEDING 35% — BOX FOR WETS!"*.
6. **Automated Acceptance Suite:**
   - Script pengujian headless [`tests/test_weather_and_ai.gd`](file:///D:/Occupation/Porto/genex/La_Voiture/tests/test_weather_and_ai.gd) dengan minimal 20 assertions komprehensif (100% PASS).

---

## 2. Spesifikasi Teknis Komponen

### A. Dynamic Weather Manager (`scripts/core/weather_manager.gd`)

Weather Manager mengontrol kondisi lingkungan sirkuit secara deterministik:
- **Enum WeatherState:**
  ```gdscript
  enum WeatherState { DRY, LIGHT_DRIZZLE, HEAVY_DOWNPOUR, DRYING }
  ```
- **Parameter Fisika:**
  - `weather_wetness_mm`: Akumulasi genangan air global ($0.0\text{ mm} \dots 3.5\text{ mm}$).
  - `rain_rate_mm_per_sec`: Laju pertambahan air hujan ($0.0$ pada DRY, $0.005$ pada DRIZZLE, $0.025$ pada HEAVY_DOWNPOUR).
  - `evaporation_rate_mm_per_sec`: Laju penguapan alami trek ($0.003\text{ mm/s}$ saat DRYING).
  - `racing_line_dry_factor`: Mobil yang melintas di lajur optimal mendispersi air $2\times$ lebih cepat daripada lajur luar.
  - `ambient_temp_c`: Suhu udara turun dari $25^\circ\text{C}$ (DRY) hingga $17^\circ\text{C}$ (HEAVY_DOWNPOUR).
- **Integrasi ke `RaceSimEngine`:**
  - Mengalirkan nilai `weather_wetness_mm` ke `engine.set_weather_wetness(wetness_mm)` di setiap tick simulasi.

### B. AI Race Director (`scripts/core/ai_race_director.gd`)

Mengendalikan 9 tim rival (18 mobil) secara otonom:
- **Heuristik Pit Stop Cuaca (Weather Crossover Window):**
  - Jika `track_wetness_mm > 0.35` dan kompon mobil saat ini adalah Slick (`SOFT`, `MEDIUM`, `HARD`):
    $\rightarrow$ AI langsung memicu `car.box_requested = true` dengan `next_compound = TireCompound.WET`.
  - Jika `track_wetness_mm < 0.18` dan mobil sedang menggunakan `WET`:
    $\rightarrow$ AI memicu pit stop untuk mengganti ke Slick (`MEDIUM` atau `HARD`).
- **Heuristik Keausan Ban (Tire Cliff Window):**
  - Jika `average_wear < 0.22` (kondisi ban kritis di bawah 22%):
    $\rightarrow$ Panggil pit stop untuk mencegah hilangnya cengkeraman dramatis.
- **Taktik Undercut & Overcut:**
  - Jika jarak ke mobil di depan $< 1.8\text{ detik}$ dan ban lawan mulai terdegradasi ($< 45\%$):
    $\rightarrow$ Mobil rival dapat melakukan *undercut* (masuk pit 1-2 lap lebih awal dari jadwal) untuk memanfaatkan *clean air* dengan ban baru.
- **Manajemen Mode Mesin:**
  - Beralih ke `PaceMode.PUSH` saat mengejar lawan atau setelah keluar pit.
  - Beralih ke `PaceMode.ECO` jika suhu ban terlalu panas ($> 105^\circ\text{C}$) atau bahan bakar menipis.

### C. Safety Car Director (`scripts/core/safety_car_director.gd`)

- **Kondisi Pemicu:**
  - Hujan badai ekstrem (`track_wetness_mm > 2.8 mm`).
  - Insiden balap / mobil mogok (bisa ditrigger via sinyal simulasi).
- **Perilaku Balapan Saat Safety Car Aktif:**
  - Status race flag berubah menjadi `YELLOW_FLAG`.
  - Kecepatan pemimpin balapan dibatasi maksimum $120\text{ km/jam}$ ($33.3\text{ m/s}$).
  - Mobil di belakang mengompresi jarak (*pack compression*) dengan batas kecepatan aman.
  - Overtaking/penyalipan dilarang keras (*overtaking disabled*).
  - Pit lane tetap terbuka: Memberikan keuntungan taktis *Cheap Pit Stop* (kehilangan waktu saat pit stop berkurang drastis karena rombongan mobil melaju lambat).

### D. Visual Shaders (Wet Track & Manga Rain)

1. **Shader Aspal Basah ([`assets/shaders/track_ribbon.gdshader`](file:///D:/Occupation/Porto/genex/La_Voiture/assets/shaders/track_ribbon.gdshader)):**
   - Tambahkan uniform `uniform float track_wetness : hint_range(0.0, 1.0) = 0.0;`.
   - Modulasi `ROUGHNESS` aspal: turun dari $0.85$ (kering) ke $0.15$ (basah/cermin).
   - Efek genangan air *puddle noise* dengan specular reflection tinggi.
2. **Efek Hujan Manga (Anime Rain VFX):**
   - Garis-garis hujan putih transparan berkecepatan tinggi dengan gaya goresan kuas manga / cel-shaded (*speed streaks*).

### E. Integrasi Pit Wall Dashboard (`scripts/ui/pit_wall_dashboard.gd`)

- Perbarui widget cuaca di baris ribbon atas:
  - Tampilkan icon/status cuaca: `☀️ DRY`, `🌦️ DRIZZLE`, `🌧️ RAIN (WET 42%)`, `🌤️ DRYING`.
  - Prediksi cuaca 5 lap: Bar horizontal mini atau label forecast (`L+2: DRIZZLE | L+4: HEAVY RAIN`).
- Radio Callout Otomatis:
  - Ketika cuaca beralih ke hujan deras, radio banner anime memunculkan transmisi taktis:
    *"BOX THIS LAP — TRACK IS FLOODING!"*

---

## 3. Protokol Pengujian & Syarat Kelulusan (Acceptance Criteria)

Buat script test mandiri: [`tests/test_weather_and_ai.gd`](file:///D:/Occupation/Porto/genex/La_Voiture/tests/test_weather_and_ai.gd).

Jalankan pengujian via Godot Console CLI:
```powershell
& "C:\Users\Lee\Downloads\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe" --headless -s tests/test_weather_and_ai.gd
```

### Daftar Assertion Wajib (Minimal 20 PASS):
1. `[PASS]` WeatherManager inisialisasi pada status DRY ($0.0\text{ mm}$).
2. `[PASS]` Hujan ringan (DRIZZLE) mengakumulasi air trek secara bertahap.
3. `[PASS]` Hujan lebat (HEAVY_DOWNPOUR) menaikkan `weather_wetness_mm` melampaui $1.0\text{ mm}$.
4. `[PASS]` Status DRYING menurunkan air trek kembali ke $0.0\text{ mm}$.
5. `[PASS]` Jalur balap (racing line) mengering lebih cepat saat dilalui mobil.
6. `[PASS]` Suhu lingkungan (*ambient temp*) turun saat hujan lebat.
7. `[PASS]` AI Race Director mendeteksi 18 mobil rival.
8. `[PASS]` Mobil Slick mengalami drop grip saat `track_wetness_mm > 0.35`.
9. `[PASS]` AI memanggil pit stop darurat untuk kompon WET saat hujan lebat.
10. `[PASS]` Seluruh 18 mobil rival beralih ke ban WET saat trek tergenang.
11. `[PASS]` Ban WET memiliki cengkeraman lebih tinggi daripada Slick di atas aspal basah.
12. `[PASS]` AI memanggil pit stop kembali ke Slick saat trek mengering ($< 0.18\text{ mm}$).
13. `[PASS]` AI memicu taktik Undercut jika berada di belakang mobil lawan yang aus.
14. `[PASS]` AI memicu pit stop saat keausan ban jatuh di bawah 22%.
15. `[PASS]` Safety Car dapat diaktifkan saat hujan badai ekstrem.
16. `[PASS]` Seluruh mobil mematuhi batas kecepatan $120\text{ km/jam}$ saat Safety Car keluar.
17. `[PASS]` Tidak ada mobil yang menyalip selama periode Safety Car / Yellow Flag.
18. `[PASS]` Jarak antar mobil mengompresi di belakang Safety Car.
19. `[PASS]` Shader track ribbon merespons parameter `track_wetness`.
20. `[PASS]` Seluruh test suite sebelumnya (`test_modular_car.gd`, `test_simulation_verification.gd`, `test_pit_wall.gd`, `test_race_world.gd`) tetap 100% PASS tanpa regresi.

---

## 4. Laporan Hasil Eksekusi

Setelah menyelesaikan seluruh langkah di atas dan memastikan semua tes lulus 100%, buat laporan eksekutif di:
`executor-report/FASE-5-WEATHER-AI-SAFETY-CAR.md`

Sertakan:
- Rangkuman implementasi file dan logika.
- Hasil capture terminal pengujian `test_weather_and_ai.gd`.
- Screenshot visual efek aspal basah / hujan di sirkuit (`scratch/phase-5-wet-track.png`).
