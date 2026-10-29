# TASK SPECIFICATION: FASE 13.1 — AUTODROMO DI BRIANZA ENVIRONMENT OVERHAUL & 6-LAYER ARCHITECTURE

**Task ID:** `TASK-FASE-13-1-BRIANZA-ENVIRONMENT-OVERHAUL`  
**Assignee:** Senior Godot 4 3D Environment Technical Artist / Track Architecture Engineer  
**Priority:** Critical (Visual Quality, Atmosphere & Architectural Realism Remediation for Round 03)  
**Pedoman Standar Sirkuit (6-Layer Guide):** [`Circuit-Environment-Component-Guide.md`](file:///D:/Occupation/Porto/genex/La_Voiture/Circuit-Environment-Component-Guide.md) v2.0  
**Spesifikasi Desain Resmi:** [`docs/superpowers/specs/2026-10-28-fase-13-1-brianza-environment-overhaul-design.md`](file:///D:/Occupation/Porto/genex/La_Voiture/docs/superpowers/specs/2026-10-28-fase-13-1-brianza-environment-overhaul-design.md)  
**Rencana Implementasi Detail (TDD Plan):** [`docs/superpowers/plans/2026-10-28-fase-13-1-brianza-environment-overhaul-plan.md`](file:///D:/Occupation/Porto/genex/La_Voiture/docs/superpowers/plans/2026-10-28-fase-13-1-brianza-environment-overhaul-plan.md)  
**Aset Referensi Visual (4 Concept Views):** [`reference-assets/tracks/brianza/`](file:///D:/Occupation/Porto/genex/La_Voiture/reference-assets/tracks/brianza/)  
**Godot Console:** `C:\Users\Lee\Downloads\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe` (atau alias `godot`)  

---

## 1. Latar Belakang & Akar Masalah (Root Cause Analysis Fase 13)

Pada pengujian in-game gameplay (kamera chase cam pemain dan balapan 20 mobil GT3) pada Fase 13, sirkuit **Autodromo di Brianza (`brianza`)** terbukti berjalan sempurna secara mekanis (spline $5.789,96\text{ m}$, 11 tikungan, pit lane 10 stall, fisika deterministik dan AI berfungsi penuh). Namun, dari segi visual lingkungan, sirkuit ini dinilai **prematur** karena mengalami 5 cacat struktural dan estetika:

1. **Ketiadaan Ground Plane / Terrain (Hukum Kontinuitas Sipil Dilanggar):**
   - Di luar permukaan aspal dan kerb, tidak ada ground mesh sama sekali. Di balik Armco barrier terbentang jurang hampa putih (*white void / empty sky*), sehingga pepohonan, tiang lampu, dan pagar terlihat melayang di udara tanpa pijakan tanah.
2. **Landmark *La Sopraelevata di Monza* Kurang Megah:**
   - Struktur viaduk lengkung miring legendaris 1950-an baru berupa 1 boks lurus tunggal di atas Serraglio straight ($s = 3.450\text{ m}$), belum memperlihatkan lengkungan oval beton miring (*banked oval deck*) $28^\circ$ multi-span yang meliuk megah di atas lanskap taman.
3. **Vegetasi Taman Kerajaan Primitif & Monoton:**
   - Pohon pinus payung Italia dan cemara hanya berupa tumpukan silinder low-poly sederhana tanpa kanopi payung bertingkat cel-shaded, tanpa semak belukar penutup celah tanah (*undergrowth*), dan tanpa dinding keliling historis (*Mura del Parco di Monza*).
4. **Minim Fasilitas Trackside & Tribun di Luar Main Straight:**
   - Kompleks tikungan pengereman ekstrem paling terkenal seperti **Variante del Rettifilo (T1-T2)** dan **Variante Ascari (T9-T11)** tidak memiliki tribun penonton berpenonton (*crowd grandstands*), pos marshal, ban pengaman Tecpro, dan pagar kawat pengaman (*FIA debris catch fence*).
5. **Ketiadaan Distant Vista Ring & `bind_world` Pasif:**
   - Pemandangan batas horizon kosong tanpa siluet bukit kaki Alpen Italia (*Montevecchia hills*) atau dinding pepohonan lebat. Fungsi `bind_world()` pada `brianza_environment.gd` bernilai kosong (`pass`), sehingga sudut matahari, bayangan panjang sore, dan kabut hangat Mediterania tidak tersambung ke `WorldEnvironment`.

---

## 2. Tujuan & Sasaran Pekerjaan (Arsitektur 6-Lapis Lingkungan)

Implementasikan arsitektur **6-Lapis Lingkungan Sirkuit** sesuai [`Circuit-Environment-Component-Guide.md`](file:///D:/Occupation/Porto/genex/La_Voiture/Circuit-Environment-Component-Guide.md) v2.0:

1. **Layer 1: Ground Massing & Park Terrain (`ParcoRealeGroundMesh`):**
   - Bangun grid terrain masif ($4200\text{ m} \times 3600\text{ m}$) ber-tone hijau stepped cel `#3c7a38`.
   - Strip kerikil/tanah inspeksi selebar $4\text{ s.d. }8\text{ m}$ di sepanjang tepi jalan dan runoff.
   - Dinding bata terakota perimeter taman (*Mura del Parco di Monza*) setinggi $3,2\text{ m}$ berpagar batu kapur.
   - **Hukum Kontinuitas Sipil: 0 floating roads.**
2. **Layer 2: Hero Landmark 1 — La Sopraelevata High-Banked Oval Deck:**
   - Viaduk lengkung beton bertulang multi-span sepanjang $480\text{ m}$ melintasi Sektor 2 ($s = 3200\text{ s.d. }3680\text{ m}$).
   - Kemiringan deck $28^\circ$ banking dengan penampang selebar $14\text{ m}$ dan tebal $1,8\text{ m}$.
   - 4 pasang portal pilar beton lengkung ganda dengan clearance bersih $13,5\text{ m}$ di atas lintasan.
   - Pagar baja berkarat historis di bibir atas perbankan.
3. **Layer 3: Corner Grandstands & Heritage Landmarks:**
   - Tribun Variante del Rettifilo (`RettifiloGrandstand`): panjang $120\text{ m}$ di T1-T2 dengan kanopi merah Italia dan MultiMesh penonton anime bersorak.
   - Tribun Variante Ascari (`AscariGrandstand`): panjang $160\text{ m}$ di T9-T11 menghadap kompleks chicane berkecepatan tinggi dengan Jumbotron penampil live standings.
   - Gerbang Taman Kerajaan (*Porta di Monza* / Villa Reale) neoklasik di $s = 5600\text{ m}$.
   - Menara Sinyal Batu (*Torre Ascari*) di $s = 4150\text{ m}$ dengan spanduk retro kuning cerah Agip.
4. **Layer 4: Dense Parco Reale Foliage Overhaul:**
   - Pinus payung Italia (*Pinus pinea*): batang meliuk organik, 3 kanopi payung bertingkat cel-shaded (`#2d5432`, `#3f7345`, `#528c5a`), $\ge 450$ instansi.
   - Cemara ramping Italia (*Cupressus sempervirens*): batang tegak dengan kerucut ramping lancip hijau pekat (`#1c3822`), $\ge 250$ instansi.
   - Semak belukar (*undergrowth shrubs*): rumpun semak rendah penutup tanah, $\ge 300$ instansi.
   - Seluruh vegetasi dioptimasi via `MultiMeshInstance3D` dengan `cast_shadow = OFF`.
5. **Layer 5: Trackside Safety, Catch Fence & Sponsor Culture:**
   - FIA Debris Catch Fencing: tiang baja bengkok $45^\circ$ dengan jaring kawat semi-transparan setinggi $2,8\text{ m}$ di atas Armco barrier di zona pengereman dan tribun.
   - Gantry Jarak Pengereman Overhead: papan rem $200\text{ m}$, $150\text{ m}$, $100\text{ m}$, $50\text{ m}$ di Rettifilo, Roggia, dan Ascari.
   - Papan Reklame Retro Sponsor Italia: *Pirelli* (merah/kuning), *Brembo* (merah/putih), *Agip* (kuning/hitam), *Magneti Marelli* (biru/putih).
   - Pos pantau marshal beratap kanopi di apex tikungan.
6. **Layer 6: Distant Vista Ring & Environmental Lighting:**
   - Cincin Vista (*BrianzaVistaRing*): panorama siluet perbukitan kaki Alpen Italia utara dan kanopi hutan lebat pada radius $4.500\text{ m}$.
   - Full `bind_world()` implementation: konfigurasi DirectionalLight3D `Sun` dengan sudut sore $42^\circ$ pitch, warna hangat keemasan `#fff3db`, bayangan lembut, ambient light `#a3c2f0`, dan kabut cel Mediterania `#dce8f5`.
   - Dukungan dinamis terhadap mode waktu `DAY`, `SUNSET`, dan `NIGHT` (lampu sorot tiang kisi di tikungan menyala otomatis).

---

## 3. Batasan Kritis (Critical Constraints)

> [!CAUTION]
> 1. **PRESERVASI SPLINE & FISIKA BRIANZA:** Jangan memodifikasi spline `TrackRibbon`, titik koordinat pusat, elevasi delta $12,0\text{ m}$, maupun layout pitstop 10-stall yang telah tervalidasi pada Fase 13.
> 2. **HUKUM KONTINUITAS SIPIL (0 FLOATING ROAD):** Seluruh permukaan jalan dan vegetasi wajib berpijak di atas permukaan tanah solid `ParcoRealeGroundMesh`. Tidak boleh ada ruang hampa atau jurang kosong di bawah pepohonan dan pagar.
> 3. **INSPEKSI VISUAL WAJIB SEBELUM KLAIM SELESAI:** Setelah merender 6 sudut kamera dengan `capture_phase13_1_views.gd`, eksekutor **wajib memeriksa keenam gambar PNG** di `executor-report/screenshots/phases/`. Pastikan tidak ada objek melayang, tidak ada clipping geometri, dan pencahayaan hangat Mediterania tampil konsisten.
> 4. **ANGGARAN PERFORMA 60 FPS:** Total draw calls sirkuit wajib $\le 160$ draw calls per kamera, segitiga lingkungan $\le 320.000$ tris, frametime $\le 16,66\text{ ms}$, dan **0 orphan nodes**. Gunakan `MultiMeshInstance3D` untuk pepohonan, tiang pagar, dan penonton.
> 5. **ZERO REGRESSION (100% PASS, 0 FAIL):** Seluruh 52 test suite headless di `tests/test_*.gd` wajib lulus tanpa error.

---

## 4. Checklist Eksekusi (Step-by-Step TDD)

Silakan ikuti kode lengkap dan langkah TDD di [`docs/superpowers/plans/2026-10-28-fase-13-1-brianza-environment-overhaul-plan.md`](file:///D:/Occupation/Porto/genex/La_Voiture/docs/superpowers/plans/2026-10-28-fase-13-1-brianza-environment-overhaul-plan.md):

- [ ] **Task 1: Ground Massing & Park Perimeter Wall (Layer 1)**
  - Tulis asersi Layer 1 di `tests/test_brianza_circuit.gd`.
  - Implementasikan `ParcoRealeGroundMesh`, jalur kerikil, dan `MuraDelParco` di `scripts/world/circuits/brianza/brianza_environment.gd`.
  - Jalankan `test_brianza_circuit.gd` $\rightarrow$ PASS, commit.
- [ ] **Task 2: Monumental Curved Sopraelevata High-Banked Oval Deck (Layer 2)**
  - Tulis asersi busur deck lengkung $480\text{ m}$, $28^\circ$ banking, dan 4 portal pilar di `tests/test_brianza_circuit.gd`.
  - Rombak `_build_tier_b_sopraelevata()` dengan geometri kurva bertingkat dan clearance $13,5\text{ m}$.
  - Jalankan `test_brianza_circuit.gd` $\rightarrow$ PASS, commit.
- [ ] **Task 3: Corner Grandstands & Heritage Landmarks (Layer 3)**
  - Tulis asersi tribun Rettifilo (T1-T2) dan Ascari (T9-T11) di `tests/test_brianza_circuit.gd`.
  - Bangun tribun Rettifilo berkanopi merah, tribun stadion Ascari, dan penonton `MultiMeshInstance3D`.
  - Jalankan `test_brianza_circuit.gd` $\rightarrow$ PASS, commit.
- [ ] **Task 4: Dense Royal Park Foliage Overhaul (Layer 4)**
  - Tulis asersi pinus payung bertingkat 3-tone, cemara Italia, dan semak belukar di `tests/test_brianza_circuit.gd`.
  - Rombak mesh dan distribusi `MultiMeshInstance3D` vegetasi Parco Reale.
  - Jalankan `test_brianza_circuit.gd` $\rightarrow$ PASS, commit.
- [ ] **Task 5: Trackside Safety, Catch Fence & Sponsor Culture (Layer 5)**
  - Tulis asersi FIA catch fence, overhead braking gantries, dan retro sponsor boards di `tests/test_brianza_circuit.gd`.
  - Pasang tiang catch fence $45^\circ$, papan rem 200/150/100/50m, papan sponsor Pirelli/Brembo/Agip, dan pos marshal.
  - Jalankan `test_brianza_circuit.gd` $\rightarrow$ PASS, commit.
- [ ] **Task 6: Distant Vista Ring & Environmental Lighting (Layer 6)**
  - Tulis asersi `BrianzaVistaRing` dan `bind_world()` di `tests/test_brianza_circuit.gd`.
  - Bangun siluet Alpen pada radius $4.500\text{ m}$, integrasikan DirectionalLight3D hangat, ambient sky, dan kabut Mediterania.
  - Jalankan `test_brianza_circuit.gd` $\rightarrow$ PASS, commit.
- [ ] **Task 7: Visual Verification, Multi-Time Gate, Smoke Test & Laporan Resmi**
  - Buat dan jalankan `scratch/capture_phase13_1_views.gd` (6 kamera 1080p + Day/Sunset/Night).
  - Inspeksi visual seluruh gambar tangkapan layar di `executor-report/screenshots/phases/`.
  - Jalankan seluruh 52 test suite headless (`100% PASS, 0 FAIL`).
  - Jalankan native smoke test balapan 3 lap 20 mobil di Brianza (`60 FPS locked`, `0 orphan nodes`).
  - Tulis laporan eksekutif di `executor-report/reports/FASE-13-1-BRIANZA-ENVIRONMENT-OVERHAUL-REPORT.md` dan update `ROADMAP.md`.

---

## 5. Perintah Terminal Pembantu (CLI Reference)

```powershell
# 1. Menjalankan unit test spesifik Autodromo di Brianza
godot --headless --path . -s res://tests/test_brianza_circuit.gd

# 2. Render 6 Camera Visual Verification Gates (1920x1080)
godot --headless --path . -s scratch/capture_phase13_1_views.gd

# 3. Menjalankan seluruh test suite headless (Zero Regression Gate)
Get-ChildItem tests\test_*.gd | ForEach-Object { godot --headless --path . -s "res://tests/$($_.Name)" }

# 4. Native Smoke Test balapan in-game
godot --path . scenes/race_world/brianza_circuit.tscn
```
