# Handoff Blueprint: Fase 5 — AI Rival Strategist, Cuaca Dinamis, & Markas Tim (HQ)
**Target Executor:** Gameplay AI & Systems Designer Agent  
**Spesifikasi Acuan:** [PRD/05-GAMEPLAY-SYSTEMS-CAREER.md](file:///D:/Occupation/Porto/genex/La_Voiture/PRD/05-GAMEPLAY-SYSTEMS-CAREER.md) & [DESIGN.md (Layar 2)](file:///D:/Occupation/Porto/genex/La_Voiture/DESIGN.md#L148-L178)  
**Tujuan Akhir:** Membangun pohon keputusan kecerdasan buatan (*AI Strategist Decision Tree*) untuk 18 mobil rival (taktik *undercut/overcut*), sistem cuaca hujan dinamis dengan mobil pengaman (*Safety Car*), serta menu Bento Grid markas tim (HQ) dengan fitur *Visual Mesh Swap*.

---

## 1. Copy-Paste Prompt untuk Executor Agent

Salin prompt di bawah ini ke agent eksekutor:

```text
Anda adalah Godot 4 Gameplay AI & Systems Designer. Tugas Anda adalah mengeksekusi FASE 5 proyek game "La Voiture": Membangun AI Strategi Tim Rival, Sistem Cuaca Dinamis & Safety Car, serta Menu Markas Tim (HQ Engineering Bento Grid).

Dokumen Acuan Wajib:
- PRD 05: D:/Occupation/Porto/genex/La_Voiture/PRD/05-GAMEPLAY-SYSTEMS-CAREER.md (Pohon Keputusan AI, Regulasi BoP, Cuaca)
- DESIGN.md: D:/Occupation/Porto/genex/La_Voiture/DESIGN.md (Topologi Layar 2: HQ Car Development Bento Grid)
- PRD 01: D:/Occupation/Porto/genex/La_Voiture/PRD/01-CORE-SIMULATION-ENGINE.md

Lingkungan Eksekusi:
- Godot Engine Path: "C:/Users/Lee/Downloads/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64.exe"
- Shell: PowerShell di Windows

Instruksi Eksekusi:
1. Buat scripts/core/ai_race_director.gd:
   - Mengendalikan 9 tim rival (18 mobil).
   - Pohon keputusan heuristik untuk pit stop: memicu Undercut jika jarak ke mobil depan < 1.8 detik dan ban lawan mulai aus.
   - Reaksi cuaca instan: memanggil pit untuk mengganti ban Wet jika intensitas hujan > 1.0mm atau wetness > 30%.
2. Buat scripts/core/weather_manager.gd:
   - State machine cuaca: KERING -> GERIMIS -> HUJAN DERAS -> LINTASAN MENGERING.
   - Menghitung track_wetness_pct dan memberikan penalti cengkeraman ke ban slick.
3. Buat scripts/core/safety_car_director.gd:
   - Menangani insiden tabrakan atau kerusakan mesin yang memicu Safety Car.
   - Membatasi kecepatan maksimum seluruh mobil dan memadatkan gap jarak di belakang Safety Car.
4. Buat scenes/hq/hq_engineering.tscn dan scripts/ui/hq_engineering_controller.gd sesuai DESIGN.md Bab 3.2:
   - Navigasi Kiri (lebar 300px): Menu [01 AERO SETUP], [02 SUSPENSION], [03 POWERTRAIN], [04 PIT CREW].
   - Bento Grid Kanan: Kartu-kartu modul R&D part modular dengan teks penyeimbang counter-skew (-6° / +6°).
   - Viewport 3D mobil di tengah: ketika tombol 'Upgrade Splitter' ditekan, part 3D mobil langsung berganti secara visual (Visual Swap).
5. Buat scenes/test_career_systems.tscn dan verifikasi bahwa AI bereaksi logis terhadap perubahan cuaca dan upgrade di HQ terpasang ke sasis mobil.
```

---

## 2. Rincian File yang Harus Dibuat

```text
D:/Occupation/Porto/genex/La_Voiture/
├── scripts/
│   ├── core/
│   │   ├── ai_race_director.gd
│   │   ├── weather_manager.gd
│   │   └── safety_car_director.gd
│   └── ui/
│       └── hq_engineering_controller.gd
└── scenes/
    ├── hq/
    │   ├── hq_engineering.tscn
    │   ├── bento_module_card.tscn
    │   └── car_setup_bay.tscn
    └── test_career_systems.tscn
```

---

## 3. Langkah Implementasi Terinci (Step-by-Step Plan)

### Step 1: AI Race Director & Logika Undercut
- Evaluasi setiap mobil di awal lap:
  ```gdscript
  func evaluate_car_strategy(car: CarState, race_state: RaceSimEngine) -> void:
      if weather.track_wetness_pct > 0.30 and car.tire_compound != TireCompound.WET:
          car.box_requested = true
          car.next_tire_compound = TireCompound.WET
          return
          
      if car.tire_wear_pct < 0.25: # Tire cliff
          car.box_requested = true
          return
          
      # Logika Undercut
      var car_ahead: CarState = race_state.get_car_ahead(car)
      if car_ahead and (car_ahead.spline_distance - car.spline_distance) < 25.0: # ~1.5 detik
          if car.lap_number >= target_pit_window and randf() < risk_tolerance:
              car.box_requested = true # Pit 1 lap lebih awal!
  ```

### Step 2: Weather & Safety Car Manager
- Siklus akumulasi air: jika hujan turun, nilai `track_wetness_pct` bertambah bertahap.
- Ketika Safety Car aktif, flag status balapan berubah menjadi `YELLOW_FLAG`, kecepatan dibatasi pada $120\text{ km/jam}$, dan seluruh mobil dilarang menyalip.

### Step 3: Layar HQ Engineering (Bento Grid)
- Buat layout `hq_engineering.tscn`:
  - Latar belakang LED matrix dengan teks raksasa hollow stroke `"E N G I N E E R I N G"`.
  - Terapkan shader `unskew_panel.gdshader` pada kartu bento R&D.
  - Hubungkan tombol "Install Upgrade" ke `ModularCarAssembler.equip_part()`.

---

## 4. Perintah Verifikasi & Acceptance Test

```powershell
& "C:/Users/Lee/Downloads/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64.exe" scenes/test_career_systems.tscn
```
* **Kriteria Keberhasilan:** Window Godot menampilkan menu HQ Bento Grid neo-brutalisme, menekan tombol R&D secara instan menukar part visual mobil 3D di tengah garasi, dan simulasi cuaca memicu mobil AI masuk pit saat hujan deras.
