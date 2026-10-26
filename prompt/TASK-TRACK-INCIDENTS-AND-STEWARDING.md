# TASK HANDOFF: Langkah 6 — Authentic GT3 Incident Dynamics, Trackside Digital Flag Panels & Steward Penalties

**Branch/Target:** `main`  
**Engine:** Godot Engine 4.7.2 stable (`godot --headless`)  
**Role:** Senior Vehicle Dynamics Engineer, Trackside Systems Designer & Gameplay Architect  
**Dokumen Referensi:**
- Spesifikasi Desain: [`docs/superpowers/specs/2026-10-26-track-incidents-and-stewarding-design.md`](file:///D:/Occupation/Porto/genex/La_Voiture/docs/superpowers/specs/2026-10-26-track-incidents-and-stewarding-design.md)
- Rencana Implementasi: [`docs/superpowers/plans/2026-10-26-track-incidents-and-stewarding-plan.md`](file:///D:/Occupation/Porto/genex/La_Voiture/docs/superpowers/plans/2026-10-26-track-incidents-and-stewarding-plan.md)
- Pedoman Arsitektur: [`AGENTS.md`](file:///D:/Occupation/Porto/genex/La_Voiture/AGENTS.md)
- Core Match Collider: [`scripts/gt/gt_contacts.gd`](file:///D:/Occupation/Porto/genex/La_Voiture/scripts/gt/gt_contacts.gd)
- Driving & Physics Simulation: [`scripts/gt/gt_driving.gd`](file:///D:/Occupation/Porto/genex/La_Voiture/scripts/gt/gt_driving.gd)
- 3D Vehicle Actor Dynamics: [`scripts/car/gt_car_actor.gd`](file:///D:/Occupation/Porto/genex/La_Voiture/scripts/car/gt_car_actor.gd)

---

## 1. Context & Objectives

Sebagai kelanjutan dari keberhasilan implementasi Safety Car autentik di Langkah 5, tugas Anda di **Langkah 6** adalah mematangkan dan memoles pengalaman insiden sirkuit agar memiliki realisme dinamika GT3 yang tinggi tanpa mengorbankan tempo permainan:

1. **Menghilangkan Animasi Putaran 360° (Gasing):**
   * Mengganti putaran `spin_angle` tak terbatas dengan model fisika **Snap Oversteer & Damped Countersteer ("Tank-Slapper")**.
   * Membatasi sudut *slip angle* maksimal pada $20^\circ$–$30^\circ$ ($0.35$–$0.52\text{ rad}$) yang meredam kembali lurus.
   * Mengimplementasikan animasi visual roda depan **Opposite Lock Steering (Countersteer)** di `gt_car_actor.gd`.
   * Mobil yang kehilangan cengkeraman meluncur (*inertial drift*) ke arah *run-off / verge* luar, menjaga *racing line* utama di sisi dalam tetap terbuka.
2. **Menjaga Integritas Match Collider (`gt_contacts.gd`):**
   * Memastikan pemeriksaan 190 pasangan SAT tetap deterministik dan stabil tanpa lonjakan dimensi *bounding box*.
   * Menjamin tidak ada mobil yang mengalami *tunneling*, *clipping*, atau *infinite kick*.
3. **Memasang FIA Grade 1 Digital Flag Panels di Sirkuit:**
   * Menempatkan 8 unit panel display LED digital di pembatas sirkuit pada sektor-sektor krusial via `MultiMeshInstance3D` di [`scripts/world/trackside_furniture_builder.gd`](file:///D:/Occupation/Porto/genex/La_Voiture/scripts/world/trackside_furniture_builder.gd).
   * Menampilkan status dinamis: hijau redup (GREEN), kuning berkedip 4 Hz dengan panah (YELLOW SECTOR), dan oranye/kuning berkedip `SC` (SAFETY CAR).
4. **VFX Bangkai DNF & Evakuasi Mulus saat Safety Car In-Lap:**
   * Mobil DNF bersandar pada barrier luar dengan sudut benturan realistis ($15^\circ$–$20^\circ$).
   * Mengeluarkan partikel asap komik cel-shaded dari kap mesin depan dan lampu hazard berkedip sinkron.
   * Saat Safety Car mengumumkan `IN_THIS_LAP`, mobil DNF melakukan transisi *fade-out* bersih (evakuasi selesai) diiringi transmisi radio Race Control.
5. **Sistem Penalti Waktu Steward Lite (+5s Time Penalty):**
   * Mengklasifikasikan kontak agresif vs insiden balap (*racing incident*).
   * Notifikasi banner HUD: `/// STEWARDS: INCIDENT UNDER INVESTIGATION` $\to$ vonis `+5s TIME PENALTY // CAUSING A COLLISION`.
   * Penalti dieksekusi saat pitstop berikutnya (kru menahan mobil 5 detik sebelum dongkrak naik) atau ditambahkan ke total catatan waktu podium.

---

## 2. Technical Constraints & Rules of Engagement

1. **ATURAN #1 (Anti-Kerusakan):** Dilarang menghapus atau merombak kode yang tidak berhubungan dengan insiden. Pertahankan seluruh komentar dan arsitektur yang ada.
2. **Ukuran Array `race.cars` Wajib 20:** Jangan pernah menghapus elemen dari array `race.cars` saat mobil DNF dievakuasi (test suite memvalidasi `race.cars.size() == 20` dan `pairs_checked_last == 190`).
3. **Titik Spline Trek Sakral:** Dilarang menggeser koordinat kontrol atau pegangan tangent `Curve3D` di `scenes/race_world/track_circuit.tscn`.
4. **Anggaran Performa GPU & Draw Calls:** Seluruh digital panel sirkuit wajib menggunakan 1 node `MultiMeshInstance3D` tunggal. Jangan menambahkan node draw call individual per panel.
5. **Zero Memory Leak:** Semua material, partikel, dan tween wajib di-free dengan benar (`0 orphan nodes`).

---

## 3. Step-by-Step Implementation Guide

### Task 1: Refactor Dinamika Kehilangan Kendali (No 360° Spin)
1. Buka [`scripts/gt/gt_driving.gd`](file:///D:/Occupation/Porto/genex/La_Voiture/scripts/gt/gt_driving.gd) pada fungsi `_spin_recovery()`.
2. Hapus baris `car.spin_angle += (14.0 - ...) * dt`.
3. Ganti dengan osilasi harmonik teredam:
   ```gdscript
   var t_loss: float = 4.0 - car.spin_timer
   var slide_dir: float = 1.0 if car.lateral >= 0.0 else -1.0
   var max_slip: float = 0.45 # ~25.7 derajat
   var damping: float = 1.15
   var omega: float = 7.5
   car.yaw_offset = slide_dir * max_slip * exp(-damping * t_loss) * cos(omega * t_loss)
   car.chassis_roll = sin(car.yaw_offset * 1.8) * 0.12
   car.chassis_pitch = 0.04 # nose dive under hard braking
   ```
4. Buka [`scripts/car/gt_car_actor.gd`](file:///D:/Occupation/Porto/genex/La_Voiture/scripts/car/gt_car_actor.gd) dan perbarui perhitungan sudut roda depan:
   - Hubungkan sudut kemudi roda depan `_steer_angle` agar membanting ke arah berlawanan dari `car.yaw_offset` (*opposite lock / countersteer*).
5. Pastikan mobil meluncur menyamping ke arah luar tikungan ($v_{\text{lat}} = \text{slide\_dir} \cdot 2.8\text{ m/s}$) dan memotong kecepatan longitudinal ($v = \max(12.0, v - 16.0 \cdot dt)$).

### Task 2: Digital Trackside Flag Panels
1. Buat shader baru `shaders/digital_flag_panel.gdshader` yang merender dot-matrix LED emisi tinggi.
2. Buka [`scripts/world/trackside_furniture_builder.gd`](file:///D:/Occupation/Porto/genex/La_Voiture/scripts/world/trackside_furniture_builder.gd):
   - Tambahkan fungsi pembangun `_build_digital_flag_panels()` yang menempatkan 8 panel ($1.8\text{ m} \times 1.2\text{ m}$) di tiang pembatas sirkuit pada titik Turn 1, Hairpin, Chicane, dsb.
   - Gunakan `MultiMeshInstance3D` dengan custom buffer data untuk mengontrol status bendera per panel.
3. Sinkronkan pembaruan status panel di [`scripts/world/race_weekend_world.gd`](file:///D:/Occupation/Porto/genex/La_Voiture/scripts/world/race_weekend_world.gd) berdasarkan `race.race_control["flag"]` dan nomor sektor.

### Task 3: Visual DNF & Evakuasi Safety Car In-Lap
1. Di [`scripts/vfx/race_vfx.gd`](file:///D:/Occupation/Porto/genex/La_Voiture/scripts/vfx/race_vfx.gd):
   - Pasang partikel asap komik mengepul dari kap mesin depan mobil yang DNF.
   - Buat kedipan lampu hazard oranye di bodi mobil DNF.
2. Di [`scripts/gt/gt_race.gd`](file:///D:/Occupation/Porto/genex/La_Voiture/scripts/gt/gt_race.gd):
   - Saat status Safety Car berpindah ke `IN_THIS_LAP`, picu sinyal evakuasi mobil DNF (lakukan animasi *fade-out* alpha transparan selama 2 detik).
   - Kirimkan panggilan radio Race Control ke Pit Wall mengumumkan trek telah bersih.

### Task 4: Steward Penalty System Lite
1. Buat modul baru `scripts/gt/gt_stewards.gd`:
   - Hubungkan pendeteksi tabrakan agresif dari [`scripts/gt/gt_contacts.gd`](file:///D:/Occupation/Porto/genex/La_Voiture/scripts/gt/gt_contacts.gd).
   - Jika terjadi *nose-to-tail collision* dengan kecepatan mendekat $closing > 2.8\text{ m/s}$, catat mobil penabrak (*at-fault*).
2. Tampilkan banner investigasi di HUD [`scripts/hud/race_hud.gd`](file:///D:/Occupation/Porto/genex/La_Voiture/scripts/hud/race_hud.gd) bergaya manga:
   - Muncul peringatan `/// STEWARDS: INCIDENT UNDER INVESTIGATION`.
   - Setelah 10 detik, umumkan vonis `+5s TIME PENALTY // CAUSING A COLLISION`.
3. Terapkan penalti 5 detik:
   - Jika masuk pit: Pit crew menahan mobil 5 detik sebelum jack mengangkat mobil.
   - Jika tidak masuk pit: Tambahkan 5 detik ke catatan waktu di [`scripts/ui/podium_screen.gd`](file:///D:/Occupation/Porto/genex/La_Voiture/scripts/ui/podium_screen.gd).

---

## 4. Definition of Done & Quality Gates

Pekerjaan dinyatakan **SELESAI** jika dan hanya jika memenuhi seluruh kriteria berikut:

1. **Automated Unit & Integration Test:**
   * Buat test suite baru `tests/test_track_incidents_and_stewards.gd`.
   * Jalankan seluruh 35 test suite proyek:
     ```powershell
     Get-ChildItem tests\test_*.gd | ForEach-Object { godot --headless --path . -s "res://tests/$($_.Name)" }
     ```
   * **Target: 35/35 SUITES PASS (100% PASS, 0 FAIL).**
2. **Verifikasi Fisika & Match Collider:**
   * `yaw_offset` tidak pernah melebihi $0.55\text{ rad}$ ($31.5^\circ$) dan kembali stabil ke $0.0$.
   * 190 pasangan mobil diuji setiap tick dengan 0 error penetrasi atau clipping.
3. **Native Smoke Test (60 FPS Performance Gate):**
   * Jalankan balapan 20 mobil di preset High 1080p cuaca hujan badai (*Thunderstorm Night*) selama 3 lap dengan insiden aktif.
   * Frame rate rata-rata $\ge 50.0\text{ FPS}$, p95 frame time $\le 32.0\text{ ms}$, dan **0 orphan nodes** saat kembali ke HQ.
4. **Dokumentasi Resmi:**
   * Laporan eksekutif diterbitkan di `executor-report/reports/FASE-11-LANGKAH-6-INCIDENTS-AND-STEWARDING-REPORT.md`.
   * Bukti visual native disimpan di `executor-report/screenshots/phases/phase-11-step-6-*.png`.
