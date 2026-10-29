# TASK SPECIFICATION: UPGRADE LINGKUNGAN SIRKUIT & DRESSING PROSEDURAL HYBRID (APEX RING INTERNATIONAL)

**Task ID:** `TASK-TRACK-ENVIRONMENT-HYBRID-PROCEDURAL`  
**Assignee:** Senior Godot 4 3D Environment & Procedural Technical Artist  
**Priority:** High (Next Core Visual Milestone: Circuit Presentation & World Atmosphere)  
**Dokumen Desain (Spec):** [`docs/superpowers/specs/2026-10-22-track-environment-hybrid-procedural-design.md`](file:///D:/Occupation/Porto/genex/La_Voiture/docs/superpowers/specs/2026-10-22-track-environment-hybrid-procedural-design.md)  
**Rencana Implementasi (Plan):** [`docs/superpowers/plans/2026-10-22-track-environment-hybrid-procedural-plan.md`](file:///D:/Occupation/Porto/genex/La_Voiture/docs/superpowers/plans/2026-10-22-track-environment-hybrid-procedural-plan.md)  
**Godot Console:** `C:\Users\Lee\Downloads\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe`  
**Blender 5.2 Console:** `C:\Program Files\Blender Foundation\Blender 5.2\blender.exe`  

---

## 1. Tujuan & Sasaran Pekerjaan

Tingkatkan visual lingkungan trek sirkuit balap **Apex Ring International** dari tingkat *wireframe/placeholder box* menjadi sirkuit balap GT3 modern bertaraf internasional dengan visual anime cel-shaded spektakuler:

1. **Permukaan Asfal & Kerb 3D Berprofil:**
   - Implementasikan shader asfal cel-shaded (`shaders/road_asphalt.gdshader`) dengan alur karet balap (*rubberized racing groove*), garis tepi asfal tajam, dan efek pantulan basah (*wet puddles*) saat hujan.
   - Buat kerb 3D bermodel sawtooth (FIA Type-A/B) dengan ketinggian elevasi $+0.05\text{ m}$ dan chamfer miring $0.5\text{ m}$ berwarna merah/putih kontras.
   - Tambahkan zona *runoff* asfal dan hamparan *gravel trap* pasir di sisi luar tikungan tajam.
2. **Trackside Safety & Furniture (MultiMesh Instancing):**
   - Rel Armco W-beam berlapis 3 dengan tiang I-beam berjarak $4.0\text{ m}$, dengan lubang otomatis di Pit Entry dan Pit Exit.
   - Pembatas busa peredam Tecpro di zona runoff kritis.
   - Papan penanda jarak pengereman bertuliskan `150`, `100`, `50` sebelum apex tikungan.
   - 28 menara lampu sorot stadion kisi baja tinggi ($18\text{ m}$) untuk balapan malam.
3. **Hero Architecture di Pit Straight:**
   - Gedung Pit Paddock modern 2 lantai di belakang 10 stall pit stop yang sudah ada.
   - Tribun Utama (*Main Grandstand*) bertingkat 3 dengan atap kantilever melengkung dan layar Jumbotron LED raksasa di seberang pit straight.
   - Menara Pengawas Balap (*Race Control Tower*) berdesain neo-brutalistik di ujung pit exit.
   - Peningkatan visual *Start/Finish Gantry* dengan struktur baja kokoh dan 5 pasang lampu merah FIA digital.
4. **Lanskap Horizon & Vegetasi Anime:**
   - Cincin pegunungan low-poly di horizon kejauhan ($R \approx 1500\text{ m}$) dengan kedalaman kabut atmosfer anime.
   - Gugusan pohon anime bergaya cel-shading dengan shader goyangan angin lembut (*wind sway*).
   - Sinkronisasi pencahayaan lingkungan dengan preset waktu balap (`Day`, `Sunset`, `Night`).

---

## 2. Batasan Kritis (Critical Constraints)

> [!CAUTION]
> 1. **DILARANG MENGUBAH SPLINE FISIKA:** Koordinat titik dan handle tangent pada `Curve3D` di [`scenes/race_world/track_circuit.tscn`](file:///D:/Occupation/Porto/genex/La_Voiture/scenes/race_world/track_circuit.tscn) **tidak boleh disentuh atau diubah**. Sebanyak 20 test suite (AI driving, GT simulation, lap timer, pit strategy) bergantung secara eksak pada spline $4.16\text{ km}$ ini.
> 2. **BATAS KETINGGIAN ELEVASI:** Permukaan jalan asfal tetap pada $Y = 0.0\text{ m}$. Puncak kerb tidak boleh melebihi $+0.05\text{ m}$ agar tidak mengganggu suspensi mobil yang telah dikalibrasi ground clearance $+0.05\text{ m}$.
> 3. **ANGGARAN PERFORMA 60 FPS:** Gunakan `MultiMeshInstance3D` untuk semua elemen repetitif (tiang guardrail, pembatas Tecpro, marker rem, pohon, lampu stadion). Draw call scene trek penuh harus tetap di bawah 180 draw calls.
> 4. **INTEGRITAS TEST (NOL REGRESI):** Seluruh 20 test suite headless yang saat ini hijau (termasuk `test_main_menu_flow.gd`, `test_modular_car.gd`, `test_gt_sim.gd`, `test_weather_and_ai.gd`) wajib **100% PASS (0 failures)** setelah integrasi.

---

## 3. Langkah Pengerjaan Detail

Silakan ikuti dan eksekusi tahapan demi tahapan pada rencana implementasi:
[`docs/superpowers/plans/2026-10-22-track-environment-hybrid-procedural-plan.md`](file:///D:/Occupation/Porto/genex/La_Voiture/docs/superpowers/plans/2026-10-22-track-environment-hybrid-procedural-plan.md)

### Checklist Tahapan:
- [ ] **Tahap 1:** Buat `shaders/road_asphalt.gdshader`, bangun generator kerb 3D bermodel sawtooth $+0.05\text{ m}$ dan zona gravel trap di `scripts/world/shared/enhanced_track_geometry.gd`.
- [ ] **Tahap 2:** Buat `scripts/world/shared/trackside_furniture_builder.gd` untuk membangun MultiMesh Armco, Tecpro, marker 150/100/50m, dan 28 menara floodlight stadion.
- [ ] **Tahap 3:** Bangun hero assets pit straight di `scenes/race_world/paddock/` (gedung pit 2 lantai, tribun utama kantilever, menara kontrol balap, upgrade gantry start FIA).
- [ ] **Tahap 4:** Tambahkan cincin siluet pegunungan anime di `scenes/race_world/mountain_vista.tscn`, scatter vegetasi anime di `scripts/world/shared/foliage_scatter.gd`, dan sinkronkan pencahayaan `Day`, `Sunset`, `Night`.
- [ ] **Tahap 5:** Buat test suite headless `tests/test_track_environment.gd`, jalankan ke-20 test suite lama untuk menjamin 0 FAIL, dan lakukan verifikasi native smoke 60 FPS.

---

## 4. Kriteria Keberhasilan & Laporan Eksekutif

Setelah pekerjaan selesai:
1. Buat laporan eksekutif resmi di `executor-report/reports/FASE-10-TRACK-ENVIRONMENT-UPGRADE-REPORT.md`.
2. Simpan seluruh bukti visual/screenshot verifikasi di `executor-report/screenshots/phases/` (kondisi Day, Sunset, dan Monsoon Night).
3. Catat hasil pengukuran performa FPS (median, p95, draw calls).
4. Verifikasi headless: Bukti keluaran `tests/test_track_environment.gd` dan seluruh 20 test suite lama (100% PASS, 0 FAIL).
