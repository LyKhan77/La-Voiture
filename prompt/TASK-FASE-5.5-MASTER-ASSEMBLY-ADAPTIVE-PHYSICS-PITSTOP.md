# TASK SPECIFICATION: FASE 5.5 — 3D MASTER ASSEMBLY, ADAPTIVE TRACK PHYSICS & REALISTIC RACE WEEKEND

**Task ID:** `TASK-FASE-5.5-MASTER-ASSEMBLY-ADAPTIVE-PHYSICS-PITSTOP`  
**Assignee:** Executor Agent (Godot 3D Systems & Vehicle Physics Specialist)  
**Priority:** High (Final 3D Gameplay & Visual Integration Before Audio)  
**Engine:** Godot Engine 4.7.2 (`C:\Users\Lee\Downloads\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe`)  
**Workspace:** `D:\Occupation\Porto\genex\La_Voiture`  
**Reference Docs:**
- `PRD/01-CORE-SIMULATION-ENGINE.md` (Bagian 7: Adaptive Dynamics & Match Collider)
- `PRD/05-GAMEPLAY-SYSTEMS-CAREER.md` (Bagian 6: Race Weekend Flow & Pitstop 3D)
- `docs/superpowers/specs/2026-10-21-phase-5.5-adaptive-physics-and-world-assembly.md`
- `docs/superpowers/plans/2026-10-21-phase-5.5-implementation-plan.md`
- Referensi Benchmark: `D:\Occupation\Porto\universal-modder\game-1\gt-manager\` (`GAME_PHYSICS.md`, `GAME_FEATURE.md`, `src/render/world.ts`, `src/render/garage.ts`)

---

## 1. Scope & Deliverables

Executor Agent ditugaskan untuk menyelesaikan **Master Assembly 3D dan Fisika Balap Realistis** pada proyek *La Voiture*. Gaya visual tetap mengikuti identitas game (Toon Cel-Shaded $\times$ Inverted-Hull Ink Outline $\times$ Manga Halftone), dengan aset lingkungan berbasis **Stylized Low-Poly**.

### Deliverables:
1. **Master Car Assembly (`scenes/race_world/car_actor.tscn`):**
   - Hapus `BoxMesh` kotak sementara.
   - Pasang instance [`scenes/car/base_chassis.tscn`](file:///D:/Occupation/Porto/genex/La_Voiture/scenes/car/base_chassis.tscn) (Bodi Porsche 911 GT3 + 4 roda BBS FI-R modular).
   - Hubungkan animasi putar 4 roda dengan kecepatan mobil (`wheel_controller.gd`) dan pertahankan kaliper rem tetap statis.
   - Pijar piringan cakram rem (*glowing brake disc*) saat deselerasi pengereman keras $> 1.5G$.
2. **Adaptive Track Dynamics (`scripts/car/adaptive_racing_line.gd`):**
   - Perhitungan kelengkungan kurva spline 2D berarah (*signed 2D curvature* $\kappa$).
   - Garis balap kontinu yang adaptif memotong apex tikungan (*dynamic apex clipping*).
   - Titik pengereman adaptif berbasis grip ban $\mu$ dan kelengkungan $\kappa$.
3. **190-Pair Match Collider System (`scripts/car/match_collider_system.gd`):**
   - Pemeriksaan jarak longitudinal siklis modulo keliling sirkuit tertutup.
   - Bounding-box contact ($|\Delta s| < 4.6\text{m}$, $|\Delta d| < 1.9\text{m}$) dengan gaya tolak repulsi lateral elastis (100% *zero ghosting / anti-clipping*).
   - Regulasi FIA GT: One-move defending, kewajiban menyisakan ruang balap $1.8\text{m}$, dan penyerahan jalan bendera biru (*blue flags*).
4. **Race Weekend Flow & 5-Red-Lights Gantry:**
   - Script [`scripts/world/race_weekend_director.gd`](file:///D:/Occupation/Porto/genex/La_Voiture/scripts/world/race_weekend_director.gd) (Grid formation $\to$ 5 Red Lights countdown $\to$ Lights Out! $\to$ Racing $\to$ Finish).
   - Scene [`scenes/race_world/start_gantry.tscn`](file:///D:/Occupation/Porto/genex/La_Voiture/scenes/race_world/start_gantry.tscn) dengan jembatan rangka baja metal melintang dan 5 pasang lampu merah start resmi FIA.
5. **Pit Lane Complex & Koreografi Pitstop 3D:**
   - Scene [`scenes/race_world/pit_lane_complex.tscn`](file:///D:/Occupation/Porto/genex/La_Voiture/scenes/race_world/pit_lane_complex.tscn) (Jalur pit lane paralel terpisah, garis pembatas pit limiter 80 km/jam, dan 10 boks garasi tim).
   - Script [`scripts/car/pitstop_choreographer.gd`](file:///D:/Occupation/Porto/genex/La_Voiture/scripts/car/pitstop_choreographer.gd):
     * Mobil berhenti di pit box.
     * Sasis mobil terangkat hidrolik $+15\text{cm}$.
     * 4 mekanik melepas roda lama dan memasang 4 roda modular baru (Soft/Medium/Hard/Wet).
     * Rambu lollipop diangkat, mobil turun ke aspal, dan melesat keluar.
     * Antrean double-stacking jika 2 mobil satu tim masuk pit bersamaan.
6. **3D Trackside Environment Low-Poly:**
   - Script [`scripts/world/track_environment_builder.gd`](file:///D:/Occupation/Porto/genex/La_Voiture/scripts/world/track_environment_builder.gd):
     * Kerb tikungan merah-putih bergerigi di setiap apex tikungan tajam.
     * Guardrail Armco dan catch fence pembatas sirkuit.
     * MultiMesh pohon kartun low-poly di perimeter sirkuit.
7. **Broadcast Multi-Camera Director:**
   - Script [`scripts/world/broadcast_camera_director.gd`](file:///D:/Occupation/Porto/genex/La_Voiture/scripts/world/broadcast_camera_director.gd) dengan 5 mode kamera:
     * `Chase Cam` (aksi belakang mobil).
     * `Cockpit Cam` (sudut pandang helm dalam mobil).
     * `Heli Cam` (kamera udara helikopter melayang).
     * `Trackside TV Cam` (kamera siaran TV di pinggir sirkuit).
     * `Close-Up Pitstop Cam` (kamera otomatis menyorot aksi kru saat pitstop berlangsung).
     * Shortcut tombol `C` untuk siklus kamera.
8. **Scene Master Balap Terpadu:**
   - Buat scene [`scenes/race_weekend_world.tscn`](file:///D:/Occupation/Porto/genex/La_Voiture/scenes/race_weekend_world.tscn) yang menyatukan seluruh sistem di atas dengan UI Pit Wall terpadu.
9. **Automated Test Suite:**
   - Script [`tests/test_race_weekend_and_physics.gd`](file:///D:/Occupation/Porto/genex/La_Voiture/tests/test_race_weekend_and_physics.gd) dengan minimal 25 assertions wajib (100% PASS).

---

## 2. Spesifikasi Teknis & Matematika

### A. Adaptive Racing Line (`scripts/car/adaptive_racing_line.gd`)
Hitung signed curvature pada spline:
$$\kappa(s) = \frac{(\mathbf{t}_1 \times \mathbf{t}_0) \cdot \hat{\mathbf{y}}}{\Delta s}$$
Tentukan target offset lateral kontinu:
$$d_{\text{target}}(s) = \text{clamp}\Big((0.4 \cdot \kappa(s) + 0.6 \cdot \kappa(s + 25\text{m})) \times 180,\; -3.2\text{m},\; +3.2\text{m}\Big)$$
Mobil bergeser menuju $d_{\text{target}}$ secara halus dengan interpolasi berbasis kecepatan lateral maksimal $1.8\text{ m/s}$.

### B. 190-Pair Match Collider (`scripts/car/match_collider_system.gd`)
Setiap tick simulasi, periksa seluruh kombinasi unik 20 mobil ($20 \times 19 / 2 = 190$ pasang):
$$\Delta s_{\text{signed}} = \text{fposmod}(s_B - s_A + L/2, L) - L/2$$
Jika $|\Delta s_{\text{signed}}| < 4.6\text{m}$ dan $|\Delta d| < 1.9\text{m}$, berikan percepatan repulsi lateral:
$$a_{\text{repulse}} = \text{sign}(\Delta d) \times (1.9 - |\Delta d|) \times 12.0\text{ m/s}^2$$
Pastikan tidak ada dua mobil yang saling tumpang tindih (*zero overlapping boxes*).

### C. 5-Red-Lights Start Sequence (`scripts/world/race_weekend_director.gd`)
- `GRID_LINEUP`: Mobil berhenti di petak start masing-masing.
- `LIGHTS_COUNTDOWN`: Lampu 1, 2, 3, 4, 5 menyala bertahap setiap $1.0\text{s}$.
- `LIGHTS_HOLD`: Seluruh 5 lampu menyala penuh selama jeda acak $0.5\text{s} \dots 2.0\text{s}$.
- `GREEN_RACING`: Semua lampu padam seketika (*LIGHTS OUT!*), mobil serempak mulai berakselerasi.

### D. Pitstop Choreography (`scripts/car/pitstop_choreographer.gd`)
- Jalur masuk pitlane: batas kecepatan otomatis dibatasi $80\text{ km/jam}$ ($22.2\text{ m/s}$).
- Mobil masuk stall pitbox dan berhenti.
- Animasi sasis naik setinggi $+15\text{cm}$ dalam waktu $0.3\text{ detik}$.
- Panggil fungsi detach dan attach roda pada `modular_car_assembler.gd` untuk menukar kompon ban ke target baru (Soft/Medium/Hard/Wet).
- Animasi sasis turun kembali ke aspal dalam $0.2\text{ detik}$, rambu lollipop diangkat, dan mobil meluncur keluar menuju lintasan.

---

## 3. Protokol Pengujian & Syarat Kelulusan (Acceptance Criteria)

Jalankan pengujian headless:
```powershell
& "C:\Users\Lee\Downloads\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe" --headless -s tests/test_race_weekend_and_physics.gd
```

### 25 Assertions Wajib (100% PASS):
1. `[PASS]` Curvature $\kappa(s)$ bernilai non-zero pada tikungan dan mendekati nol pada trek lurus.
2. `[PASS]` Target garis balap $d_{\text{target}}$ menempel ke apex tikungan dalam ($|\kappa| > 0$).
3. `[PASS]` Mobil mematuhi batas kecepatan tikungan grip-adaptive $v_{\text{limit}}(s)$.
4. `[PASS]` Pengereman dimulai lebih awal saat koefisien gesek ban $\mu$ rendah (aus/hujan).
5. `[PASS]` 190 pasang mobil diperiksa match collider setiap tick.
6. `[PASS]` Selisih jarak longitudinal siklis menangani modulasi garis start/finish dengan benar.
7. `[PASS]` Gaya repulsi lateral aktif saat dua mobil berada di dalam kontak envelope ($4.6\text{m} \times 1.9\text{m}$).
8. `[PASS]` Nol tembus bodi (*zero overlapping bounding boxes*) selama 3600 tick balapan padat.
9. `[PASS]` Mobil bertahan mematuhi batas satu kali perubahan jalur defensif (*one-move defending*).
10. `[PASS]` Ruang balap minimal $1.8\text{m}$ tersisa saat mobil penyerang berada sejajar di samping.
11. `[PASS]` Mobil yang tertinggal lap (*blue flag*) memberi jalan secara halus.
12. `[PASS]` Formasi grid 20 mobil tersusun rapi dengan offset berselang-seling.
13. `[PASS]` Countdown 5 lampu merah menyala satu per satu setiap interval $1.0\text{ detik}$.
14. `[PASS]` Semua 5 lampu padam seketika (*LIGHTS OUT*) dan balapan resmi dimulai.
15. `[PASS]` Tidak ada mobil yang bergerak sebelum lampu padam (*zero false start*).
16. `[PASS]` Jalur pit lane membatasi kecepatan maksimum $80\text{ km/jam}$ ($22.2\text{ m/s}$).
17. `[PASS]` Mobil berhenti tepat di boks stall garasi timnya.
18. `[PASS]` Animasi hidrolik mengangkat sasis mobil $+15\text{cm}$.
19. `[PASS]` Penggantian 4 roda modular berhasil dilakukan dengan kompon yang diminta.
20. `[PASS]` Teammate double-stacking antre dengan benar tanpa menembus mobil rekan satu tim.
21. `[PASS]` Roda pada `car_actor.tscn` berputar sesuai kecepatan gerak dan kaliper rem tetap statis.
22. `[PASS]` Disc brake memancarkan efek glow menyala saat deselerasi pengereman keras $> 1.5G$.
23. `[PASS]` Kerb tikungan merah-putih terbentuk di sisi dalam tikungan tajam.
24. `[PASS]` Gantry start dan jajaran 10 garasi pit lane terpasang pada koordinat yang benar.
25. `[PASS]` Seluruh test suite lama (`test_modular_car.gd`, `test_simulation_verification.gd`, `test_pit_wall.gd`, `test_race_world.gd`, `test_weather_and_ai.gd`) tetap 100% PASS tanpa regresi.

---

## 4. Laporan Hasil Eksekusi

Setelah seluruh implementasi selesai dan diverifikasi lulus 100%, buat laporan eksekutif di:
`executor-report/FASE-5.5-MASTER-ASSEMBLY-ADAPTIVE-PHYSICS-PITSTOP.md`

Sertakan:
- Rangkuman implementasi script dan scene baru.
- Hasil capture terminal pengujian `test_race_weekend_and_physics.gd`.
- Screenshot visual dari scene `scenes/race_weekend_world.tscn`:
  1. Mobil 3D Porsche modular melaju di lintasan dengan kerb merah-putih dan guardrail (`scratch/phase-5.5-race-track.png`).
  2. Suasana start 5 lampu merah di gantry start/finish (`scratch/phase-5.5-start-lights.png`).
  3. Close-up aksi pitstop kru 3D saat mobil terangkat dongkrak hidrolik (`scratch/phase-5.5-pitstop-action.png`).
