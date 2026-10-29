# Implementation Plan: Authentic GT3 Incident Dynamics, Trackside Digital Flag Panels & Steward Penalties

> **For agentic workers:** REQUIRED SUB-SKILL: Use `superpowers:executing-plans` task-by-task. User already authorized execution in this workspace; no approval pause or commit is required.

**Goal:** Menghilangkan animasi putaran 360° yang tidak realistis dan menggantinya dengan dinamika *Snap Oversteer & Countersteer* GT3 otentik, menambahkan *FIA Digital Flag Panels* di sirkuit, asap dan evakuasi bangkai DNF, serta sistem penalti waktu *Steward Review* (+5s), dengan perlindungan penuh pada *Match Collider*.

**Architecture:** Godot 4.7.2, typed GDScript 2.0, Forward+ Desktop/Mobile. Simulasi berjalan deterministik pada sub-stepping 60 Hz. Match collider (190 pasangan SAT) dijaga ketat agar bebas *clipping* dan *ghosting*. Seluruh bendera dan status insiden disinkronkan antara `GtRace`, `GtContacts`, `RaceVfx`, dan `TracksideFurnitureBuilder`.

**Tech Stack:** Godot Engine 4.7.2 stable, GDScript, Godot Shading Language (`.gdshader`).

**Spec:** [`docs/superpowers/specs/2026-10-26-track-incidents-and-stewarding-design.md`](file:///D:/Occupation/Porto/genex/La_Voiture/docs/superpowers/specs/2026-10-26-track-incidents-and-stewarding-design.md)

---

## Global Constraints & Safeguards
1. **Preserve Match Collider Math:** Jangan pernah merusak relaksasi 2-pass di [`scripts/gt/gt_contacts.gd`](file:///D:/Occupation/Porto/genex/La_Voiture/scripts/gt/gt_contacts.gd). SAT distance and penetration scaling tetap menggunakan lebar $2.08\text{ m}$ dan panjang $4.45\text{ m}$.
2. **Never Remove DNF Cars from `race.cars`:** Array `race.cars` wajib tetap berukuran 20 elemen untuk menjamin pengecekan 190 pasangan pada test suite tidak pernah gagal. Evakuasi bangkai hanya dilakukan pada layer visual 3D (*fade-out* dan sembunyikan mesh).
3. **Preserve Asset & Geometry Rules:** DILARANG mengubah titik kontrol atau tangent `Curve3D` di `track_circuit.tscn`. Dilarang menimpa file mentah model mobil.
4. **Zero Regression:** Seluruh 34 test suite yang ada wajib tetap 100% PASS (0 FAIL).

---

## Review Focus & Critical Invariants
1. `car.yaw_offset` saat insiden tidak boleh berputar bebas $360^\circ$; wajib berada di dalam batas absolut $\le 0.55\text{ rad}$ ($31.5^\circ$) dan kembali melurus ke $0.0$.
2. Sudut roda depan `_steer_angle` di `GtCarActor` membelok berlawanan arah dengan sudut slip bodi (*opposite lock*).
3. Digital Flag Panels menampilkan warna dan pola yang sinkron dengan status `race.race_control["flag"]` dan nomor sektor tanpa menambah draw call (menggunakan `MultiMeshInstance3D`).
4. Penalti 5 detik tereksekusi dengan benar: jika mobil masuk pit, durasi servis bertambah 5 detik; jika tidak masuk pit, waktu 5 detik ditambahkan ke catatan podium.
5. Performa native balapan 20 mobil 1080p High tetap terkunci pada target budget $\ge 50.0\text{ FPS}$ (p95 $\le 32.0\text{ ms}$, 0 orphan node).

---

## Task 1 — Core Physics Refactor: Damped Loss-of-Control & Opposite Lock Steering
**Files:**
- Modifikasi: [`scripts/gt/gt_driving.gd`](file:///D:/Occupation/Porto/genex/La_Voiture/scripts/gt/gt_driving.gd)
- Modifikasi: [`scripts/car/gt_car_actor.gd`](file:///D:/Occupation/Porto/genex/La_Voiture/scripts/car/gt_car_actor.gd)
- Modifikasi: [`scripts/gt/gt_car.gd`](file:///D:/Occupation/Porto/genex/La_Voiture/scripts/gt/gt_car.gd)
- Test Focus: [`tests/test_car_dynamics_vfx.gd`](file:///D:/Occupation/Porto/genex/La_Voiture/tests/test_car_dynamics_vfx.gd)

**Langkah Pengerjaan:**
- [ ] Ubah variabel `spin_angle` dan fungsi `_spin_recovery()` di `gt_driving.gd`. Ganti integrasi sudut tak terbatas dengan osilasi teredam:
  `car.yaw_offset = car.slip_direction * max_slip_rad * exp(-damping * t) * cos(omega * t)`
- [ ] Batasi pergerakan lateral mobil yang hilang kendali agar meluncur ke arah *run-off / outer verge* ($v_{\text{lat}} = \text{slide\_dir} \cdot 2.8\text{ m/s}$) dan memotong kecepatan longitudinal ($v = \max(12.0, v - 16.0 \cdot dt)$).
- [ ] Di `gt_car_actor.gd`, hubungkan rotasi roda depan ke sudut slip: saat bodi mobil membuang ke satu sisi, roda depan membelok tajam ke sisi sebaliknya (*countersteer*).
- [ ] Berikan getaran suspensi (*chassis shudder & hard roll*) saat mobil terseret di atas aspal.
- [ ] Jalankan test `test_car_dynamics_vfx.gd` dan `test_gt_sim.gd` untuk memastikan emisi asap ban dan pemeriksaan 190 pasangan tetap PASS.

---

## Task 2 — Trackside Digital LED Flag Panels
**Files:**
- Modifikasi: [`scripts/world/shared/trackside_furniture_builder.gd`](file:///D:/Occupation/Porto/genex/La_Voiture/scripts/world/shared/trackside_furniture_builder.gd)
- Shader Baru: `shaders/digital_flag_panel.gdshader`
- Integrasi: [`scripts/world/weekend/race_weekend_world.gd`](file:///D:/Occupation/Porto/genex/La_Voiture/scripts/world/weekend/race_weekend_world.gd)

**Langkah Pengerjaan:**
- [ ] Buat shader emisi `digital_flag_panel.gdshader` dengan efek kisi dot-matrix LED yang mendukung status:
  - GREEN (hijau redup statis)
  - YELLOW (kuning terang berkedip 4 Hz dengan panah chevron)
  - SC (kuning/oranye berkedip dengan teks `SC`)
- [ ] Di `trackside_furniture_builder.gd`, tambahkan instancing 8 unit panel digital ($1.8\text{ m} \times 1.2\text{ m}$) di tiang pembatas sirkuit pada sektor-sektor kunci.
- [ ] Hubungkan pembaruan status panel di `race_weekend_world.gd` mengikuti perubahan bendera di `race.race_control["flag"]` dan sektor terkait.
- [ ] Pastikan seluruh panel hanya menggunakan 1 single `MultiMeshInstance3D` agar tidak membebani draw call sirkuit.

---

## Task 3 — DNF Wreckage VFX & Clean In-Lap Evacuation
**Files:**
- Modifikasi: [`scripts/vfx/race_vfx.gd`](file:///D:/Occupation/Porto/genex/La_Voiture/scripts/vfx/race_vfx.gd)
- Modifikasi: [`scripts/car/gt_car_actor.gd`](file:///D:/Occupation/Porto/genex/La_Voiture/scripts/car/gt_car_actor.gd)
- Modifikasi: [`scripts/gt/gt_race.gd`](file:///D:/Occupation/Porto/genex/La_Voiture/scripts/gt/gt_race.gd)

**Langkah Pengerjaan:**
- [ ] Saat `car.is_dnf` aktif, posisikan bodi mobil bersandar pada barrier luar dengan sudut kemiringan benturan realistis ($15^\circ$–$20^\circ$).
- [ ] Pasang pemancar partikel asap komik cel-shaded (`manga_smoke_emitter.tscn`) dari kap depan mobil yang rusak.
- [ ] Aktifkan lampu hazard 3D berkedip oranye sinkron di sekeliling bodi mobil DNF.
- [ ] Di `gt_race.gd`, saat Safety Car mengumumkan `IN_THIS_LAP`, picu sinyal evakuasi: mobil DNF melakukan transisi *fade-out* transparan (alpha $1.0 \to 0.0$ selama 2.0 detik) dan sembunyikan visualnya.
- [ ] Kirim transmisi radio Race Control ke Pit Wall: *"Track clear in Sector %d. Recovery complete, Safety Car in this lap."*

---

## Task 4 — Steward Penalty Lite & High-Stakes Tactical HUD
**Files:**
- Modul Baru: `scripts/gt/gt_stewards.gd`
- Modifikasi: [`scripts/gt/gt_contacts.gd`](file:///D:/Occupation/Porto/genex/La_Voiture/scripts/gt/gt_contacts.gd)
- Modifikasi: [`scripts/hud/race_hud.gd`](file:///D:/Occupation/Porto/genex/La_Voiture/scripts/hud/race_hud.gd)
- Modifikasi: [`scenes/ui/podium_screen.tscn`](file:///D:/Occupation/Porto/genex/La_Voiture/scenes/ui/podium_screen.tscn) & [`scripts/ui/podium_screen.gd`](file:///D:/Occupation/Porto/genex/La_Voiture/scripts/ui/podium_screen.gd)

**Langkah Pengerjaan:**
- [ ] Buat class `GtStewards` yang menerima event kontak dari `gt_contacts.gd`:
  - Jika kontak *nose-to-tail* keras di zona rem (`closing > 2.8 m/s`), catat mobil belakang sebagai penyeruduk (*at-fault*).
  - Mulai timer investigasi 10 detik.
- [ ] Tampilkan banner investigasi manga di HUD:
  `/// STEWARDS: INCIDENT UNDER INVESTIGATION`
- [ ] Setelah 10 detik, umumkan hasil putusan:
  - Racing incident: `NO FURTHER ACTION - RACING INCIDENT`
  - Pelanggaran: `+5s TIME PENALTY // CAR #%d: CAUSING A COLLISION`
- [ ] Terapkan penalti 5 detik:
  - Jika mobil masuk pit: Tambahkan *penalty hold* 5.0 detik sebelum kru mulai bekerja.
  - Jika tidak masuk pit: Akumulasikan +5.0 detik ke total waktu balap di `podium_screen.gd`.

---

## Task 5 — Automated Test Suite & Native Verification (DoD Gate)
**Files:**
- Test Suite Baru: `tests/test_track_incidents_and_stewards.gd`
- Skrip Probe Smoke: `scratch/smoke_incidents_stewards.gd`
- Laporan Resmi: `executor-report/reports/FASE-11-LANGKAH-6-INCIDENTS-AND-STEWARDING-REPORT.md`

**Langkah Pengerjaan:**
- [ ] Buat unit test `tests/test_track_incidents_and_stewards.gd` dengan asersi komprehensif:
  - Perilaku *Snap Oversteer* (sudut yaw tidak pernah melewati $0.55\text{ rad}$ dan meredam ke $0$).
  - Perilaku *Countersteer* roda depan.
  - Pengecekan 190 pasangan Match Collider tetap utuh dan valid.
  - Sinyal digital panel sinkron dengan status bendera.
  - Siklus penalti steward (investigasi $\to$ vonis +5s $\to$ eksekusi).
- [ ] Jalankan seluruh 35 test suite (34 lama + 1 baru) via `godot --headless`, pastikan **100% PASS, 0 FAIL**.
- [ ] Eksekusi balapan native smoke 20 mobil 1080p High cuaca hujan badai malam selama 3 lap, ukur FPS rata-rata dan pastikan **0 orphan node**.
- [ ] Ambil bukti visual native dan susun laporan eksekutif resmi di `executor-report/reports/FASE-11-LANGKAH-6-INCIDENTS-AND-STEWARDING-REPORT.md`.
