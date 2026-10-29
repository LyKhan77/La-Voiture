# TASK SPECIFICATION: 12-MONTH CIRCUIT CALENDAR & NEO-WANGAN SHUTO EXPRESS TRACK

**Task ID:** `TASK-12-CIRCUIT-CALENDAR-AND-NEO-WANGAN-TRACK`  
**Assignee:** Senior Godot 4 3D Track & Environment Technical Artist / Systems Engineer  
**Priority:** High (Next Major Core Milestone: Multi-Track Calendar & Career Mode Foundation)  
**Dokumen Desain (Spec):** [`docs/superpowers/specs/2026-10-27-circuit-calendar-and-neo-wangan-track-design.md`](file:///D:/Occupation/Porto/genex/La_Voiture/docs/superpowers/specs/2026-10-27-circuit-calendar-and-neo-wangan-track-design.md)  
**Rencana Implementasi (Plan):** [`docs/superpowers/plans/2026-10-27-neo-wangan-circuit-and-12-track-calendar.md`](file:///D:/Occupation/Porto/genex/La_Voiture/docs/superpowers/plans/2026-10-27-neo-wangan-circuit-and-12-track-calendar.md)  
**Aset Referensi Visual (Meshy AI 4-Views):** [`reference-assets/tracks/neo_wangan/`](file:///D:/Occupation/Porto/genex/La_Voiture/reference-assets/tracks/neo_wangan/)  
**Godot Console:** `C:\Users\Lee\Downloads\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe` (atau alias `godot`)  

---

## 1. Tujuan & Sasaran Pekerjaan

Implementasikan fondasi kalender kejuaraan resmi 12 sirkuit (7 GP + 5 Sprint) sebagai pilar Career Mode, serta bangun sirkuit 3D sprint pertama yang dapat dimainkan secara utuh: **Neo-Wangan Shuto Express (新湾岸高速, 3.150 m)** dengan visual anime cel-shaded streetwear perkotaan:

1. **Arsitektur Data Kalender 12 Sirkuit:**
   - Resource data `CircuitData.gd` dan registry `CircuitCalendarRegistry.gd` yang memuat ke-12 sirkuit resmi (Round 01 s.d. Round 12) dengan metadata lengkap (nama resmi, nama kanji, inspirasi nyata, panjang, jumlah tikungan, elevasi, dan peluang cuaca).
   - Integrasikan ke `RaceConfigData.gd` (`selected_circuit_id: String = "apex_ring"`).
2. **Geometri Ribbon 3D Neo-Wangan Shuto Express:**
   - Bangun spline loop `Curve3D` sepanjang $3.150\text{ m} \pm 25\text{ m}$ dengan 12 tikungan resmi di `scripts/world/circuits/neo_wangan/neo_wangan_circuit_builder.gd`.
   - Profil elevasi dinamis: dari $+6.5\text{ m}$ di atas jembatan tol layang (*Shuto Bay Bridge*) hingga $-3.2\text{ m}$ di dasar terowongan (*Underpass Tunnel*).
   - Lebar jalur balap 11.5 m dengan kerb jalan raya rendah (+0.03 m) dan shader aspal basah `road_asphalt.gdshader`.
3. **Rekayasa Sambungan Pitstop Aman (Standar FIA):**
   - **Pit Entry (Titik A):** Terletak di sisi kanan 75 m sebelum garis finis dengan lajur deselerasi 4.5 m dan bantalan peredam oranye (*crash cushion*) pada hidung pemisah pit wall.
   - **Pit Lane (Titik B):** Membentang 140 m sejajar main straight dengan 10 stall tim berjarak 12 m dan Fast Lane 4.5 m, terpisah oleh dinding beton setinggi 1.2 m.
   - **Pit Exit (Titik C):** Jalur keluar memanjang melewati Turn 1 (*bypass ramp* 65 m) dengan garis putih pembatas solid (*Solid FIA Blend Line*) sepanjang 80 m untuk mencegah tabrakan *T-bone* dengan mobil di lintasan utama.
4. **Lingkungan Perkotaan 3D (MultiMesh GPU Instancing):**
   - Bangun `scripts/world/street_furniture_builder.gd`: barrier beton jalan tol dengan grafiti anime, tiang lampu jalan Tokyo, gantry rambu tol hijau Shuto, terowongan underpass 180 m dengan lampu neon atap, dan skyline gedung pencakar langit low-poly.
5. **Widget Track Selector di Race Setup & Radar 2D:**
   - Tambahkan pemilih sirkuit interaktif di `scenes/ui/race_setup_menu.tscn` (thumbnail, badge tipe GP/Sprint, panjang trek, jumlah tikungan).
   - Pastikan minimap radar 2D di HUD in-game (`circuit_radar_2d.gd`) menggambar spline sirkuit aktif secara adaptif.
6. **Verifikasi Kinerja & Zero Regression:**
   - 20 mobil balap GT3 berjalan mulus di Neo-Wangan, AI overtake, pitstop dinamis, 45 test suite 100% PASS, frame time $\le 16.66\text{ ms}$ (60 FPS locked), dan 0 orphan node.

---

## 2. Batasan Kritis (Critical Constraints)

> [!CAUTION]
> 1. **PRESERVASI SIRKUIT APEX RING:** Jangan merusak atau memodifikasi spline koordinat `scenes/race_world/track_circuit.tscn`. Apex Ring tetap menjadi Round 01 (GP) default. Neo-Wangan adalah scene terpisah (`scenes/race_world/neo_wangan_circuit.tscn`) yang dimuat secara dinamis.
> 2. **ANGGARAN PERFORMA 60 FPS:** Gunakan `MultiMeshInstance3D` untuk semua elemen yang berulang lebih dari 3 kali (tiang lampu jalan, dinding barrier beton, pagar kawat, kontainer pelabuhan). Total draw calls sirkuit wajib $\le 160$ draw calls dan poligon lingkungan $\le 320.000$ tris.
> 3. **ZERO REGRESSION (100% PASS):** Seluruh 42 test suite headless yang ada saat ini wajib tetap **PASS 100% (0 FAIL)**. Tambahkan 3 test suite baru: `test_circuit_calendar_registry.gd`, `test_neo_wangan_circuit.gd`, dan `test_track_selector_ui.gd` (total 45 suite wajib PASS).
> 4. **INTEGRITAS ATURAN FITMENT & LIVERY:** Jangan menyentuh sasis mobil, socket roda, atau texture livery mobil yang sudah dikalibrasi.

---

## 3. Langkah Pengerjaan Detail (Plan Reference)

Silakan eksekusi langkah demi langkah sesuai urutan TDD pada rencana implementasi:
[`docs/superpowers/plans/2026-10-27-neo-wangan-circuit-and-12-track-calendar.md`](file:///D:/Occupation/Porto/genex/La_Voiture/docs/superpowers/plans/2026-10-27-neo-wangan-circuit-and-12-track-calendar.md)

### Checklist Eksekusi:
- [ ] **Task 1: Fondasi Arsitektur Data 12 Sirkuit**
  - Tulis test: `tests/test_circuit_calendar_registry.gd` (12 ronde, 7 GP, 5 Sprint).
  - Buat: `scripts/core/circuit_data.gd` dan `scripts/core/circuit_calendar_registry.gd`.
  - Integrasikan ke `scripts/core/race_config_data.gd`.
  - Verifikasi: Test PASS, commit.
- [ ] **Task 2: Geometri Spline 3D & Ribbon Neo-Wangan**
  - Tulis test: `tests/test_neo_wangan_circuit.gd` (spline 3.150 m, elevasi, radius $\ge 18$ m).
  - Buat: `scripts/world/circuits/neo_wangan/neo_wangan_circuit_builder.gd` & scene `scenes/race_world/neo_wangan_circuit.tscn`.
  - Verifikasi: Test PASS, commit.
- [ ] **Task 3: Sambungan Pitstop Geometri & Standar FIA**
  - Tambahkan asersi pitstop pada `test_neo_wangan_circuit.gd`.
  - Implementasi lajur deselerasi pit-in, crash cushion, 10 stall tim, dan bypass exit post-T1 dengan solid blend line.
  - Verifikasi: Test PASS, commit.
- [ ] **Task 4: Lingkungan 3D Streetwear Perkotaan (MultiMesh & Shaders)**
  - Buat: `scripts/world/street_furniture_builder.gd` (barriers, lampu jalan, rambu Shuto, kontainer).
  - Implementasi atap terowongan underpass dan audio reverb knalpot.
  - Verifikasi: Draw calls $\le 160$, tris $\le 320.000$, commit.
- [ ] **Task 5: UI Track Selector di Race Setup & Radar 2D**
  - Tulis test: `tests/test_track_selector_ui.gd`.
  - Modifikasi `scenes/ui/race_setup_menu.tscn` dan `scripts/ui/race_setup_menu.gd`.
  - Perbarui `scripts/ui/circuit_radar_2d.gd` agar membaca Curve3D sirkuit aktif.
  - Verifikasi: Test PASS, commit.
- [ ] **Task 6: Integrasi Balapan Penuh, Multi-Car AI & Smoke 60 FPS**
  - Hubungkan pemuatan sirkuit aktif di `scenes/race_weekend_world.tscn`.
  - Jalankan seluruh 45 test suite: `powershell -ExecutionPolicy Bypass -File scratch/run_all_tests.ps1` (Ekspektasi: 45/45 PASS).
  - Jalankan native smoke test: balapan 3 lap 20 mobil di Neo-Wangan hingga podium & kembali ke HQ.
  - Tulis laporan eksekutif di `executor-report/reports/FASE-12-NEO-WANGAN-CIRCUIT-REPORT.md` dan simpan screenshot di `executor-report/screenshots/phases/`.

---

## 4. Perintah Terminal Pembantu (CLI Reference)

```powershell
# Menjalankan 1 test headless baru
godot --headless --path . -s res://tests/test_circuit_calendar_registry.gd
godot --headless --path . -s res://tests/test_neo_wangan_circuit.gd
godot --headless --path . -s res://tests/test_track_selector_ui.gd

# Menjalankan seluruh test suite otomatis (45 suite)
powershell -ExecutionPolicy Bypass -File scratch/run_all_tests.ps1

# Menjalankan game native untuk smoke test balapan
godot --path . scenes/main.tscn
```
