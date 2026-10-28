# Fase 13.3: Brianza Civil, Pit Lane & Paddock Polish Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Hilangkan rumput yang menutupi track Brianza, bersihkan pit lane dari barrier dan bentuk yang buruk, dan isi paddock, dengan layout yang mengikuti spline Brianza.

**Architecture:** Zona pit menjadi satu kontrak (`PitZone`, dihitung dari dictionary `pit_layout` yang sudah ada) yang dibaca semua komponen bersama. Terrain Brianza dibatasi invarian "tanah selalu di bawah jalan" yang diuji pada mesh yang dirender. Pit Brianza memakai logika Apex v2 yang di-port, lalu paddock baru (`BrianzaPaddock`) berdiri di atas platform datar yang dihormati generator ground.

**Tech Stack:** Godot 4.7.2 GDScript 2.0 (static typing), test headless `extends SceneTree`, MultiMeshInstance3D/MeshBatch, Windows PowerShell.

**Spec:** `docs/superpowers/specs/2026-10-28-fase-13-3-brianza-civil-pit-paddock-polish-design.md` (wajib dibaca bersama plan ini). Keputusan K1 sampai K6 di spec bagian 7 sudah disetujui developer.

## Global Constraints

- GDScript 2.0 bertipe statis; ikuti gaya, penamaan dan kepadatan komentar file sekitar. LF, bukan CRLF.
- Spline tidak berubah: `VERTICES`, `RADII`, `ELEVATION` di `brianza_circuit_builder.gd` dan `scenes/race_world/track_circuit.tscn`.
- Apex Ring dan Neo Wangan tidak berubah perilakunya: `tests/test_shared_paddock_kit.gd` (hash mesh Apex), `test_track_environment.gd`, `test_pit_lane.gd`, `test_neo_wangan_circuit.gd` lulus tanpa diedit.
- Nama node dan antarmuka yang dipakai test, RaceVfx dan choreographer tetap: `PitAsphalt`, `PitMarkings`, `PitWall`, `Socket_PitStall_<n>`, `PitEntryTrigger`, `PitExitTrigger`, `StandbyCrew`; `sim_layout()`, `stall_transform(team)`, `garage_for_team(team)`, `crew_spot(slot)`, `crew_roles()`, `lane_lateral(u)`.
- Anggaran: draw call environment tidak melebihi 169 (angka terburuk 13.2), target <= 160; segitiga lingkungan <= 320.000; objek berulang > 3 wajib `MultiMeshInstance3D`/`MeshBatch`; 0 orphan node.
- `--headless` MultiMesh tidak menyimpan transform: simpan array pose di builder untuk dibaca test.
- Jangan menghapus, memindah, atau menimpa berkas yang bukan buatan Anda. Working tree memuat banyak berkas belum di-commit milik developer: **stage dengan nama berkas eksplisit, jangan `git add -A` / `git add .`**.
- Skrip probe dan tangkapan sementara masuk `temp/`. Tangkapan bukti memakai nama baru `phase-13-3-*` di `executor-report/screenshots/phases/` dan tidak menimpa berkas lama.
- Perintah Godot: `godot` (alias ke `C:\Users\Lee\Downloads\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe`). Kerangka test (`check()`, `_finish()`, `call_deferred("_run")`) disalin dari `tests/test_brianza_circuit.gd:1-40`.
- Definisi Selesai: semua `tests/test_*.gd` lulus 100% (52 suite pada 13.2; `test_race_world.gd` dengan `--fixed-fps 60`, suite berat boleh melewati timeout 90 dtk lalu dijalankan ulang), smoke native 3 lap 20 mobil, laporan jujur di `executor-report/reports/FASE-13-3-BRIANZA-CIVIL-PIT-PADDOCK-REPORT.md` (catat gate yang belum lulus, mis. 60 FPS terkunci, apa adanya).

## Review Focus

1. Zona pit melewati garis start/finish (Brianza: s 5510 sampai 190) dan zona yang dimulai di awal lap: `contains()` dan `outside_ranges()` harus benar di kedua sisi wrap. Test: Task 1 `#Z3`.
2. Verge dan paddock di sempitnya celah antara Parabolica dan back straight (66 m tengah ke tengah) tidak boleh masuk koridor jalan lain. Test: Task 2 `#T1.4`, Task 5 `#K2`.
3. `team_ids` bukan urutan identitas (mis. dibalik): stall, garasi dan warna transporter mengikuti tim yang benar. Test: Task 3 `#P8`, Task 5 `#K3`.
4. `build()` dipanggil dua kali dan world dibuang/dimuat ulang tidak menggandakan node atau menyisakan orphan. Test: Task 3 `#P8`, Task 5 `#K7`.
5. Mode DAY/SUNSET/NIGHT dengan node paddock baru: tidak ada error, node tetap terlihat. Test: Task 5 `#K8`.

---

## File Structure

- Create `scripts/world/pit_zone.gd`: hitung zona pit dari `pit_layout` (murni, tanpa preload sirkuit mana pun).
- Create `scripts/world/brianza_pit_dressing.gd`: dressing pit concept-art (chevron, drum, pagar, cantilever, strip sponsor) agar `brianza_pit_complex.gd` tetap fokus.
- Create `scripts/world/brianza_paddock.gd`: isi paddock (apron, jalan servis, transporter, tenda, pagar, gerbang, parkir).
- Modify `scripts/world/trackside_furniture_builder.gd`, `track_environment_builder.gd`, `broadcast_camera_director.gd`, `race_weekend_world.gd` (kontrak zona).
- Modify `scripts/world/brianza_environment.gd` (zona, terrain, platform, foliage keep-out) dan `brianza_pit_complex.gd` (layout v2, platform, paddock).
- Create tests: `tests/test_pit_zone_contract.gd`, `tests/test_brianza_terrain_gate.gd`, `tests/test_brianza_pit_lane_v2.gd`, `tests/test_brianza_paddock.gd`.
- Docs: `Circuit-Environment-Component-Guide.md`, `docs/AGENT-WORKFLOW.md`, `ROADMAP.md`, laporan fase.

---

### Task 1: Kontrak zona pit (`PitZone`) dan perbaikan armco, runoff, floodlight, kamera TV

**Files:**
- Create: `scripts/world/pit_zone.gd`
- Modify: `scripts/world/trackside_furniture_builder.gd:12,40-41,147,195-203`, `scripts/world/track_environment_builder.gd:198-208`, `scripts/world/brianza_environment.gd:614-618,654-661`, `scripts/world/broadcast_camera_director.gd:64,246`, `scripts/world/race_weekend_world.gd:131`
- Test: `tests/test_pit_zone_contract.gd`

**Interfaces:**
- Produces:
  - `PitZone.from_layout(layout: Dictionary, lap_length_m: float, lead_m: float = 20.0, trail_m: float = 40.0) -> Dictionary` mengembalikan `{"start_s": float, "length_m": float, "entry_s": float, "exit_s": float}`. Panjang lane = `layout["lane_length_m"]` jika ada, selain itu `fposmod(exit_s - entry_s, lap_length_m)`. `start_s = fposmod(entry_s - lead_m, lap)`, `length_m = lane + lead_m + trail_m`.
  - `PitZone.contains(zone: Dictionary, s: float, lap_length_m: float) -> bool` (wrap-aware; `{}` selalu false).
  - `PitZone.outside_ranges(zone: Dictionary, lap_length_m: float) -> Array[Vector2]`: rentang arc di luar zona sebagai pasangan tidak-wrap `[from, to]` (sama persis dengan yang dikembalikan `armco_ranges_for(+1)` lama); `{}` mengembalikan `[Vector2(0, lap)]`.
  - `TracksideFurnitureBuilder.build(p_ribbon, p_line, kerbs, plans, hero_zones, pit_zone: Dictionary = {})`. `{}` berarti tidak ada pit di sisi kanan (armco tanpa celah). Furniture tidak lagi mereferensikan `PitLaneScript`.
  - `BroadcastCameraDirector.setup(p_camera, p_ribbon, pit_zone: Dictionary = {})`: stasiun TV dilewati di dalam `pit_zone` (pemanggil memberi lead 30 m dan trail 30 m, setara kondisi lama `ENTRY_S - 30` sepanjang `NOMINAL + 60`).

- [ ] **Step 1: Buat branch dan rekam baseline**

`git switch -c fase-13-3-brianza-civil-pit-paddock-polish` (dari `main`; perubahan belum di-commit milik developer ikut terbawa dan jangan disentuh). Jalankan `godot --headless --path . -s res://scratch/measure_brianza_budget.gd` dan simpan keluarannya ke `temp/phase13-3-baseline/budget.txt` (cantumkan `BUDGET draw_calls=… tris=…`). Jalankan `test_brianza_circuit`, `test_pit_lane`, `test_track_environment`, `test_shared_paddock_kit`, `test_neo_wangan_circuit` dan catat jumlah PASS untuk pembanding.

- [ ] **Step 2: Tulis test yang gagal `tests/test_pit_zone_contract.gd`**

```gdscript
# Z1 Apex: zona dari layout default memberi celah armco yang sama dengan perilaku lama.
var apex_zone: Dictionary = PitZone.from_layout({"entry_s": 3900.0, "exit_s": 150.0, "lane_length_m": 410.0}, lap, 20.0, 40.0)
check(is_equal_approx(float(apex_zone["start_s"]), 3880.0) and is_equal_approx(float(apex_zone["length_m"]), 470.0), "#Z1 Apex zone = 3880 + 470")
check(apex_furniture.armco_ranges_for(1.0) == PitZone.outside_ranges(apex_zone, apex_lap), "#Z1b Apex armco ranges unchanged")
# Z2 Brianza: celah armco berada di pit Brianza, bukan di Serraglio.
check(not brianza_furniture.has_armco_at(1.0, 5600.0) and not brianza_furniture.has_armco_at(1.0, 100.0), "#Z2a no armco beside the real pit lane (incl. past the line)")
check(brianza_furniture.has_armco_at(1.0, 3900.0) and brianza_furniture.has_armco_at(1.0, 300.0), "#Z2b armco restored at the old Apex gap and after the zone")
# Z3 wrap: zona 5510 + 470 pada lap 5789.955 melewati garis start.
var wrap: Dictionary = {"start_s": 5510.0, "length_m": 470.0}
check(PitZone.contains(wrap, 5600.0, lap) and PitZone.contains(wrap, 100.0, lap) and not PitZone.contains(wrap, 300.0, lap) and not PitZone.contains(wrap, 5400.0, lap), "#Z3a contains() is wrap-aware")
check(PitZone.outside_ranges(wrap, lap).size() == 1 and is_equal_approx(PitZone.outside_ranges(wrap, lap)[0].y, 5510.0), "#Z3b outside_ranges() single span when zone wraps")
check(PitZone.outside_ranges({}, lap) == [Vector2(0.0, lap)] and not PitZone.contains({}, 5.0, lap), "#Z3c empty zone = no pit")
# Z4 kamera TV: tidak ada stasiun di zona (30/30) untuk Apex dan Brianza.
for s: float in director.tv_station_s: check(not PitZone.contains(zone30, s, lap), "#Z4 TV station %.0f outside pit zone" % s)
# Z5 Wangan (audit, tanpa perubahan kode): celah barrier kanan mengikuti layout-nya sendiri.
check(wangan_env._in_pit_gap(float(wangan_pit.sim_layout()["entry_s"]) - 10.0) and not wangan_env._in_pit_gap(float(wangan_pit.sim_layout()["entry_s"]) - 100.0), "#Z5 Wangan pit gap follows its own layout")
# Z6 kontrol: zona digeser memindahkan celah.
shifted.build(ribbon, line, [], [], [], {"start_s": 1000.0, "length_m": 470.0})
check(shifted.has_armco_at(1.0, 3900.0) and not shifted.has_armco_at(1.0, 1100.0), "#Z6 gap follows the zone parameter")
# Z7 lint: komponen bersama tidak membaca konstanta pit sirkuit tertentu.
for path: String in ["trackside_furniture_builder", "broadcast_camera_director", "foliage_scatter", "enhanced_track_geometry"]:
    check(not RegEx.create_from_string("PitLaneScript\\.(ENTRY_S|EXIT_S|NOMINAL_LENGTH_M|STALL_FIRST_S)").search(FileAccess.get_file_as_string("res://scripts/world/%s.gd" % path)), "#Z7 %s has no Apex pit constants" % path)
```

- [ ] **Step 3: Jalankan RED**

Run: `godot --headless --path . -s res://tests/test_pit_zone_contract.gd`
Expected: gagal (`PitZone` belum ada; setelah stub, `#Z2a` dan `#Z7` FAIL).

- [ ] **Step 4: Implement `scripts/world/pit_zone.gd`** (`class_name PitZone`, `extends RefCounted`, tiga fungsi statis di atas). `outside_ranges`: zona tidak-wrap (`end <= lap`) menghasilkan `[Vector2(0, start), Vector2(end, lap)]`; zona wrap menghasilkan `[Vector2(end - lap, start)]`.

- [ ] **Step 5: Hubungkan konsumen**
  - `trackside_furniture_builder.gd`: simpan `_pit_zone` dari parameter baru `build(...)`; `armco_ranges_for(side)` mengembalikan `[Vector2(0, length)]` untuk sisi kiri dan `PitZone.outside_ranges(_pit_zone, length)` untuk sisi kanan; hapus preload `PitLaneScript` serta konstanta `PIT_OPEN_LEAD_M` / `PIT_OPEN_TRAIL_M` (lead/trail kini dipilih pemanggil).
  - `track_environment_builder.gd` (Apex): bangun `PitZone.from_layout({"entry_s": PitLaneScript.ENTRY_S, "exit_s": PitLaneScript.EXIT_S, "lane_length_m": PitLaneScript.NOMINAL_LENGTH_M}, ribbon.length_m, PIT_RUNOFF_LEAD_M, PIT_RUNOFF_TRAIL_M)` dan teruskan ke `furniture.build`. Pastikan `armco_ranges_for(1.0)` identik dengan sebelumnya (`#Z1b`).
  - `brianza_environment.gd`: hitung `_pit_zone` sekali dari `p_builder.get_node("PitLane").call("sim_layout")` pada awal `build()`; `pit_start`/`pit_len` (baris 614-618) dan dua entri `hero_zones` literal (654-657) diturunkan dari `_pit_zone` (pecah di wrap lap untuk hero zone); teruskan `_pit_zone` ke `furniture.build`.
  - `broadcast_camera_director.gd`: `setup` menerima `pit_zone` dan `_build_tv_stations` melewati stasiun dengan `PitZone.contains(...)`. `race_weekend_world.gd:131` memanggil `camera_director.setup(camera, ribbon, PitZone.from_layout(_pit_layout(), ribbon.length_m, 30.0, 30.0))`.
  - Neo Wangan: hanya audit (`#Z5`). Jika `#Z5` gagal, laporkan sebelum mengubah kode Wangan.

- [ ] **Step 6: Jalankan GREEN dan regresi**

Run: `godot --headless --path . -s res://tests/test_pit_zone_contract.gd` lalu `test_track_environment`, `test_pit_lane`, `test_shared_paddock_kit`, `test_brianza_circuit`, `test_neo_wangan_circuit`, `test_reusable_sky_and_time_of_day`, `test_race_world` (`--fixed-fps 60`).
Expected: semua PASS; jumlah PASS suite lama sama dengan baseline.

- [ ] **Step 7: Commit**

```bash
git add scripts/world/pit_zone.gd scripts/world/trackside_furniture_builder.gd scripts/world/track_environment_builder.gd scripts/world/brianza_environment.gd scripts/world/broadcast_camera_director.gd scripts/world/race_weekend_world.gd tests/test_pit_zone_contract.gd
git commit -m "fix(brianza): drive armco, runoff, floodlight and TV-camera pit gaps from one PitZone contract"
```

---

### Task 2: Terrain: tanah selalu di bawah jalan, verge tidak melintasi jalan lain, platform pit

**Files:**
- Modify: `scripts/world/brianza_environment.gd:94-108` (konstanta), `:346-396` (`ground_y_at`, `_verge_drop`, `_field_height`), `:424-486` (`_build_field`: tone dan lantai luar), `:493-533` (`_build_verge`), `:1099` (`_foliage_blocked`); `scripts/world/brianza_pit_complex.gd` (tambah `ground_platforms()`)
- Test: `tests/test_brianza_terrain_gate.gd`

**Interfaces:**
- Produces:
  - `BrianzaPitComplex.ground_platforms() -> Array[Dictionary]`, tiap entri `{"s0": float, "s1": float, "side": float, "lateral_from": float, "lateral_to": float, "y_offset": float, "skirt_m": float}`. Sekarang berisi satu platform pit: dari `stalls[0].s - 30` sampai `stalls[-1].s + 30`, `side` +1, lateral 7,0 sampai 31,0, `y_offset` -0,03, `skirt_m` 6,0. Task 5 menambahkan platform paddock.
  - `BrianzaEnvironment.field_tone_index(c: int, r: int) -> int` (0..2): tone sel field ke-(c, r) yang dipakai generator (agar tone bisa diuji).
  - `ground_y_at(pos)` mengembalikan `road_y + y_offset` di dalam platform (jangan dilewati pohon, tribun, gedung).

- [ ] **Step 1: Tulis test yang gagal `tests/test_brianza_terrain_gate.gd`**

Kumpulkan segitiga dari **semua** `MeshInstance3D` di bawah `ParcoRealeGroundRoot` lewat `mesh.get_faces()` dikali transform node (tidak memakai `ground_y_at()`); bangun hash spasial sel 24 m agar kueri cepat (kueri naif O(sampel x segitiga) terlalu lambat).

```gdscript
# T1.1 Setiap sampel jalan: tanah tertinggi di titik itu berada di bawah jalan.
for s in range(0, int(ribbon.length_m), 6):
    for lat: float in [-7.0, 0.0, 7.0]:
        var road: Vector3 = ribbon.get_point_at_offset(float(s), lat).origin
        worst = maxf(worst, top_y_at(road.x, road.z) - road.y)
check(worst <= -0.05, "#T1.1 ground surface is below every road sample (worst %.2f m)" % worst)
# T1.2 Regresi s=3860 (jalan -4.35 m): lantai luar -3.0 m dulu menutupinya.
check(top_y_at(p3860.x, p3860.z) <= p3860.y - 0.05, "#T1.2 nothing covers the road at s=3860")
# T1.3 Lantai pit: tanah <= aspal pit - 0.02 pada seluruh lebar lane sepanjang zona stall.
for u: float in range(0, 410, 6): for lat: float in [8.0, 14.0, 20.0]:
    var pit_point: Vector3 = pit.get_pit_transform(float(u), lat).origin
    check(top_y_at(pit_point.x, pit_point.z) <= pit_point.y + 0.015 - 0.02, "#T1.3 ground below pit asphalt at u=%d lat=%.0f" % [u, lat])
# T1.4 Verge tidak melintasi koridor jalan lain (Parabolica vs back straight, 66 m): nol vertex verge dalam 8 m dari ruas jalan dengan jarak arc > 90 m.
check(verge_hits == 0, "#T1.4 verge never enters another road corridor (%d vertices)" % verge_hits)
# T1.5 Tone organik: sel bertetangga berbagi tone >= 70%; acak murni ~33%.
check(same_tone_ratio >= 0.70, "#T1.5 grass tones form patches (neighbour match %.2f)" % same_tone_ratio)
# T1.6 Platform: ground_y_at di dalam platform pit = road_y + y_offset (+- 0.01), lantai bagi pohon dan gedung.
var plat: Dictionary = pit.ground_platforms()[0]
var inside: Transform3D = ribbon.get_point_at_offset((float(plat["s0"]) + float(plat["s1"])) * 0.5, 14.0)
check(absf(env.ground_y_at(inside.origin) - (inside.origin.y + float(plat["y_offset"]))) <= 0.01, "#T1.6 ground_y_at follows the pit platform")
```

- [ ] **Step 2: Jalankan RED**

Run: `godot --headless --path . -s res://tests/test_brianza_terrain_gate.gd`
Expected: `#T1.1` dan `#T1.2` FAIL (lantai luar y = -3,0 di atas jalan), `#T1.4` FAIL (16 titik verge pada probe), `#T1.5` FAIL (tone acak), `#T1.3`/`#T1.6` FAIL (belum ada platform).

- [ ] **Step 3: Implement**
  - **Lantai luar:** ganti plane datar penuh (`ParcoRealeOuterFloor`, baris 471-480) dengan mesh bingkai di luar jejak field pada `y = -GROUND_DROP_M - 0.6` (tetap menutup celah langit sampai ring vista), atau turunkan di bawah `builder.min_elevation_m - GROUND_DROP_M - 1.0`. Pilih yang lolos `#T1.1` tanpa tebing yang terlihat di aerial.
  - **Tone:** `field_tone_index(c, r)` memakai noise halus berfrekuensi rendah (tambalan 150 sampai 300 m), tetap 3 tone; ganti rumus acak di baris 459.
  - **Verge:** batasi lebar `_build_verge` per `s` dan sisi dengan `SurfaceGeometry.other_road_distance` / `max_extent` (tabel `SurfaceGeometry.hash_samples(ribbon)`), sehingga tepi luar verge >= 10 m dari tengah ruas jalan lain; band yang melewati batas dikunci ke batas.
  - **Platform:** `_build_verge`, `ground_y_at` dan `_foliage_blocked` membaca `pit.ground_platforms()` (node `PitLane`, sudah dibangun sebelum environment); di dalam platform tinggi tanah = `road_y + y_offset` lalu turun halus ke profil verge sepanjang `skirt_m`.

- [ ] **Step 4: Jalankan GREEN dan regresi**

Run: `godot --headless --path . -s res://tests/test_brianza_terrain_gate.gd`, lalu `test_brianza_circuit` (termasuk `#L1.8`, `#L4.4`).
Expected: PASS. Jika `#L1.8`/`#L4.4` gagal karena platform, perbaiki generator (jangan melonggarkan test).

- [ ] **Step 5: Commit**

```bash
git add scripts/world/brianza_environment.gd scripts/world/brianza_pit_complex.gd tests/test_brianza_terrain_gate.gd
git commit -m "fix(brianza): keep every ground surface below the road, clip verge at neighbouring roads, add pit platform"
```

---

### Task 3: Pit lane v2: layout menurut spline, geometri Apex v2, aspal jalan

**Files:**
- Modify: `scripts/world/brianza_pit_complex.gd:23-51` (konstanta), `:75-112` (`lane_lateral_at`, `sim_layout`), `:194-270` (`_build_asphalt`, `_build_markings`, `_build_pit_wall`, `_build_crash_cushion`), `:273-306` (`_build_garages`), `:342-352` (`_build_entry_sign`)
- Test: `tests/test_brianza_pit_lane_v2.gd`

**Interfaces:**
- Consumes: `PitZone` (Task 1), `ground_platforms()` (Task 2, tinggi platform tidak berubah).
- Produces (pada `BrianzaPitComplex`):
  - Konstanta: `ENTRY_BLEND_M = 80.0`, `EXIT_BLEND_M = 90.0`, `EDGE_LATERAL_M = 5.2`, `STALL_FIRST_S = 5600.0`; `ENTRY_S` 5530, `EXIT_S` 150, `LANE_LENGTH_M` 410 tetap.
  - `lane_edges(u: float) -> Vector2`, `wall_lateral(u: float) -> float`, `wall_span_u() -> Vector2`.
  - `wall_end_cushions: Array[Dictionary]` (`{"u": float, "pose": Transform3D}`, dua entri).
  - `solid_footprints() -> Array[Dictionary]`, tiap entri `{"name": String, "u0": float, "u1": float, "lat0": float, "lat1": float}` untuk setiap benda padat di lane (dinding, cushion, dan dressing Task 4). Test lintasan membaca ini.

- [ ] **Step 1: Tulis test yang gagal `tests/test_brianza_pit_lane_v2.gd`**

```gdscript
var layout: Dictionary = pit.sim_layout()
check(layout["entry_s"] == 5530.0 and layout["exit_s"] == 150.0 and layout["lane_length_m"] == 410.0 and layout["lane_ramp_in_m"] == 80.0 and layout["lane_ramp_out_m"] == 90.0 and layout["edge_lateral_m"] == 5.2 and layout["stall_first_s"] == 5600.0, "#P1 sim_layout() carries the K1 values")
check(is_equal_approx(pit.lane_lateral(0.0), 5.2) and is_equal_approx(pit.lane_lateral(80.0), 11.6) and is_equal_approx(pit.lane_lateral(410.0), 5.2), "#P1b lane path ramps 5.2 -> 11.6 -> 5.2")
# P2 stall di segmen lurus.
var min_radius: float = INF
for s: float in range(5580, 5760, 4): min_radius = minf(min_radius, ribbon.get_radius_at(float(s)))
check(min_radius >= 250.0, "#P2 stall block and PitBuilding stand on a straight (min radius %.0f m)" % min_radius)
# P3 lintasan mobil +-1.1 m bebas dari setiap benda padat.
for fp: Dictionary in pit.solid_footprints():
    for u: float in range(int(fp["u0"]), int(fp["u1"]) + 1, 2):
        var path: float = pit.lane_lateral(float(u))
        check(float(fp["lat1"]) < path - 1.1 or float(fp["lat0"]) > path + 1.1, "#P3 %s clear of the car path at u=%d" % [fp["name"], u])
check(pit.wall_end_cushions.size() == 2, "#P3b crash cushion at both wall ends")
check(pit.wall_lateral(pit.wall_span_u().x) >= ribbon.road_half_width_m + 1.1 - 0.01, "#P3c wall starts once a 1.1 m verge exists")
# P4 aspal pit = shader aspal jalan yang sama.
check(((pit.get_node("PitAsphalt") as MeshInstance3D).material_override as ShaderMaterial).shader == RoadShader, "#P4 pit asphalt uses the road shader")
# P7 satu jalur untuk sim dan geometri.
for u: float in [0.0, 20.0, 80.0, 200.0, 330.0, 410.0]: check(absf(GtRace.lane_lateral_at(u, 410.0, layout) - pit.lane_lateral(u)) < 0.001, "#P7 sim path = geometry path at u=%.0f" % u)
# P8 team_ids dibalik + build dua kali: stall mengikuti tim, tidak ada node ganda.
pit.build(ribbon, [9,8,7,6,5,4,3,2,1,0]); var kids: int = pit.get_child_count(); pit.build(ribbon, [0,1,2,3,4,5,6,7,8,9])
check(pit.get_child_count() == kids and pit.stall_index_for_team(9) == 0, "#P8 second build() keeps the node count and remaps teams")
# P9 garasi membawa perlengkapan Apex.
check(pit.garage_equipment.size() == 10, "#P9 ten garages carry Apex equipment")
```

- [ ] **Step 2: Jalankan RED**

Run: `godot --headless --path . -s res://tests/test_brianza_pit_lane_v2.gd`
Expected: `#P1`, `#P2` (radius 88 m pada s 5555), `#P3b/c`, `#P4`, `#P7` FAIL.

- [ ] **Step 3: Implement**

Ubah konstanta (K1) dan port logika Apex v2 dari `scripts/world/pit_lane_complex.gd` ke `brianza_pit_complex.gd`, dengan konstanta Brianza: `lane_edges` (`:163-175`), `wall_lateral` (`:222-224`), `_build_pit_wall` termasuk cushion kedua ujung dan awal dinding saat verge >= 1,1 m (`:359-390`), `_build_markings` (`:278-353`: garis limiter kuning, garis putih, separator, stop line, kotak dan nomor box), rambu 80 / PIT LANE / PIT EXIT (`:491-527`); ganti `_build_asphalt` agar memakai `lane_edges` dan `PitLaneComplex.asphalt_material()`; buat `ApexPitScript.new()` sebagai `props_source` dan panggil `_garage_props` untuk tiap garasi (pola `neo_wangan_pit_complex.gd:435`), isi `garage_equipment`. Buang `_build_crash_cushion` lama. Isi `solid_footprints()` dari dinding dan cushion. Pertahankan guard `built` dan remap `team_ids`.

- [ ] **Step 4: Jalankan GREEN dan regresi**

Run: `godot --headless --path . -s res://tests/test_brianza_pit_lane_v2.gd`, lalu `test_brianza_circuit`, `test_pit_zone_contract`, `test_brianza_terrain_gate`, `test_pit_lane`, `test_pitcrew_visual`, dan `godot --headless --path . -s res://scratch/smoke_phase13_2_pit.gd`.
Expected: PASS. Jika test Brianza lama meng-hardcode `STALL_FIRST_S`/ramp lama, perbarui sadar (nilai baru dari K1), jangan longgarkan.

- [ ] **Step 5: Commit**

```bash
git add scripts/world/brianza_pit_complex.gd tests/test_brianza_pit_lane_v2.gd
git commit -m "feat(brianza): pit lane v2 layout on the straight, Apex v2 wall/cushions/markings, road asphalt, 80/90 m ramps"
```

---

### Task 4: Dressing pit sesuai concept art

**Files:**
- Create: `scripts/world/brianza_pit_dressing.gd`
- Modify: `scripts/world/brianza_pit_complex.gd` (panggil dressing dari `build()` setelah dinding)
- Test: `tests/test_brianza_pit_lane_v2.gd` (tambah)

**Interfaces:**
- Consumes: `wall_lateral(u)`, `wall_span_u()`, `solid_footprints()`, `get_pit_transform(u, lateral)` (Task 3).
- Produces: `BrianzaPitDressing.build(pit: Node3D) -> Dictionary` yang menambah node anak pit dan mengembalikan `{"footprints": Array[Dictionary], "fence_poses": Array[Transform3D], "drum_poses": Array[Transform3D]}`; pit menyalinnya ke `fence_poses`, `drum_poses` dan menambahkan footprints ke `solid_footprints()`. Node: `PitEntryChevrons`, `PitEntryGantry` (cantilever satu kaki di garis dinding, lengan 5,4 m di atas lane, papan "80 PIT ENTRY"), `PitWallFence` (MultiMesh tiang+panel kawat, tinggi 1,8 m di atas dinding), `PitWallSponsorStrip` (strip kuning sepanjang muka dinding sisi lane), 5 drum cushion oranye di nose dinding.

- [ ] **Step 1: Tulis test yang gagal** (tambahan di `test_brianza_pit_lane_v2.gd`)

```gdscript
for node_name: String in ["PitEntryChevrons", "PitEntryGantry", "PitWallFence", "PitWallSponsorStrip"]:
    check(pit.get_node_or_null(node_name) != null, "#D1 %s exists" % node_name)
check(pit.drum_poses.size() == 5 and pit.fence_poses.size() >= 80, "#D2 five nose drums and a continuous wire fence on the wall")
check(pit.solid_footprints().any(func(f: Dictionary) -> bool: return String(f["name"]) == "gantry_leg"), "#D3 gantry leg registered as a footprint")
# P3 (lintasan bebas benda padat) harus tetap lulus dengan semua footprint dressing.
```

- [ ] **Step 2: Jalankan RED**: `godot --headless --path . -s res://tests/test_brianza_pit_lane_v2.gd`. Expected: `#D1` sampai `#D3` FAIL.

- [ ] **Step 3: Implement `brianza_pit_dressing.gd`.** Semua benda berdiri di garis dinding (`lateral = wall_lateral(u)`), tidak ada kaki atau tiang di lintasan fast lane atau jalur masuk box; chevron putih V pada wedge entry u 0 sampai 60 sebagai paint datar dalam `PitMarkings`-style mesh; pagar dan drum via `MeshBatch`/MultiMesh (aturan > 3 pengulangan); bahan cel yang sama dengan pit (`ToonMaterials.vertex_colored(false)`). Bentuk dan warna mengikuti `reference-assets/tracks/brianza/view1_main_straight_pitstop.png` dan `view4_parabolica_pit_entry.png`.

- [ ] **Step 4: Jalankan GREEN**: `godot --headless --path . -s res://tests/test_brianza_pit_lane_v2.gd`, lalu `godot --headless --path . -s res://scratch/measure_brianza_budget.gd` (bandingkan dengan baseline; selisih draw call dicatat untuk Task 6). Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add scripts/world/brianza_pit_dressing.gd scripts/world/brianza_pit_complex.gd tests/test_brianza_pit_lane_v2.gd
git commit -m "feat(brianza): pit entry chevrons, cantilever gantry, wall fence, sponsor strip and nose drums from concept art"
```

---

### Task 5: Paddock: apron, jalan servis, transporter, tenda, pagar, gerbang, parkir

**Files:**
- Create: `scripts/world/brianza_paddock.gd`
- Modify: `scripts/world/brianza_pit_complex.gd` (`_build_shared_paddock` memanggil paddock; `ground_platforms()` menambah platform paddock), `scripts/world/brianza_environment.gd` (`_foliage_blocked` menghormati jejak paddock)
- Test: `tests/test_brianza_paddock.gd`

**Interfaces:**
- Consumes: `ground_platforms()` (Task 2), `stalls`/`stall_transform(team)` (Task 3), `SurfaceGeometry.hash_samples`, `SurfaceGeometry.other_road_distance`, `SurfaceGeometry.max_extent`, `Liveries.color_for(team)`.
- Produces: `BrianzaPaddock extends Node3D` dengan `build(p_ribbon: TrackRibbonScript, pit: Node3D, team_ids: Array[int]) -> void` (aman dipanggil dua kali), `zone: Dictionary` (`{"s0","s1","lateral_from","lateral_to"}`), array pose yang dibaca test: `transporter_poses: Array[Dictionary]` (`{"team": int, "pose": Transform3D, "color": Color}`), `tent_poses`, `fence_poses`, `parking_poses: Array[Transform3D]`, `gate_pose: Transform3D`, `platform: Dictionary`, `footprints() -> Array[Rect2]` (s x lateral). Node: `PaddockApron`, `PaddockServiceRoad`, `PaddockTransporters`, `PaddockTents`, `PaddockFence`, `PaddockGate`, `PaddockParking`, `PaddockProps`.
- Aturan layout (spec 4.4): `s` dari stall pertama - 30 m sampai stall terakhir + 30 m; `lateral_from` = 32 m; `lateral_to` = min(95 m, batas yang membuat jarak ke jalan lain >= 14 m, dihitung per `s` dengan `max_extent`). Jalan servis di lateral 34 sampai 40 sepanjang gedung dan penghubung ke gerbang di sisi hilir; transporter satu per stall, sejajar stall, lateral 44 sampai 52, warna tim; 6 sampai 8 tenda di lateral 58 sampai 70; pagar di `lateral_to`; parkir dua baris di ujung hulu. Semua repetitif via `MultiMeshInstance3D`/`MeshBatch`, tambahan draw call <= 10.

- [ ] **Step 1: Tulis test yang gagal `tests/test_brianza_paddock.gd`**

```gdscript
var paddock: BrianzaPaddock = pit.get_node("BrianzaPaddock")
check(paddock.transporter_poses.size() == 10 and paddock.tent_poses.size() >= 6 and paddock.tent_poses.size() <= 8 and paddock.fence_poses.size() > 0 and paddock.parking_poses.size() >= 16, "#K1 paddock is filled (10 transporters, 6-8 tents, fence, parking)")
# K2 semua elemen di dalam zona, di luar gedung (lateral >= 32), dan >= 14 m dari jalan lain.
for rect: Rect2 in paddock.footprints(): check(rect.position.y >= 32.0 and rect.end.y <= 95.0, "#K2a footprint inside the paddock lateral band")
for entry: Dictionary in paddock.transporter_poses: check(SurfaceGeometry.other_road_distance(cells, ribbon, float(entry["s"]), (entry["pose"] as Transform3D).origin) >= 14.0, "#K2b clear of other roads")
# K3 transporter i di belakang garasi i, warna tim; juga untuk team_ids dibalik.
for i in range(10): check(absf(float(paddock.transporter_poses[i]["s"]) - float(pit.stalls[i]["s"])) <= 4.0 and (paddock.transporter_poses[i]["color"] as Color).is_equal_approx(Liveries.color_for(int(pit.stalls[i]["team"]))), "#K3 transporter %d behind its garage in team colour" % i)
# K4 tidak menimpa RaceControlTower (AABB + 3 m) maupun PitBuilding (lateral < 30).
var tower_box: AABB = tower_world_aabb.grow(3.0)
for entry: Dictionary in paddock.transporter_poses: check(not tower_box.has_point((entry["pose"] as Transform3D).origin), "#K4 transporter clear of the control tower")
# K5 elemen berdiri di atas platform.
for entry: Dictionary in paddock.transporter_poses: check(absf(env.ground_y_at((entry["pose"] as Transform3D).origin) - (entry["pose"] as Transform3D).origin.y) <= 0.05, "#K5 transporter stands on the platform")
for pose: Transform3D in paddock.tent_poses: check(absf(env.ground_y_at(pose.origin) - pose.origin.y) <= 0.05, "#K5b tent stands on the platform")
# K6 anggaran: permukaan terlihat di bawah BrianzaPaddock.
check(count_visible_surfaces(paddock) <= 10, "#K6 paddock adds <= 10 draw calls (got %d)" % count_visible_surfaces(paddock))
# K7 build dua kali, lalu buang world: tidak ada node ganda dan tidak ada orphan.
var kids: int = paddock.get_child_count(); paddock.build(ribbon, pit, team_ids)
check(paddock.get_child_count() == kids, "#K7a second build() adds no nodes")
world.queue_free(); for _i in 4: await process_frame
check(int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)) == 0, "#K7b no orphan nodes after teardown")
# K8 DAY/SUNSET/NIGHT: tidak ada error dan node paddock tetap terlihat.
for mode: int in [0, 1, 2]:
    env.apply_time_of_day({"mode": mode, "floodlights": float(mode), "stars_opacity": 0.0})
    check(paddock.get_node("PaddockTents").visible and paddock.get_node("PaddockTransporters").visible, "#K8 paddock visible in time-of-day mode %d" % mode)
```

- [ ] **Step 2: Jalankan RED**: `godot --headless --path . -s res://tests/test_brianza_paddock.gd`. Expected: FAIL (`BrianzaPaddock` belum ada).

- [ ] **Step 3: Implement `brianza_paddock.gd`** sesuai aturan layout di atas dan hubungkan: `_build_shared_paddock()` membuat paddock setelah PitBuilding; `ground_platforms()` menambah platform paddock (`lateral_from` 7, `lateral_to` = `zone.lateral_to`, `y_offset` -0,03, `skirt_m` 6); `_foliage_blocked` di environment menolak pohon dan semak di jejak paddock (+ margin 6 m) dan cypress boleh menjadi tabir di luar pagar. Warna transporter lewat warna per instance (MultiMesh) agar satu draw call. Tenda putih dengan trim Monza red (`MONZA_RED`); apron beton cel terang; jalan servis aspal gelap.

- [ ] **Step 4: Jalankan GREEN dan regresi**

Run: `godot --headless --path . -s res://tests/test_brianza_paddock.gd`, lalu `test_brianza_terrain_gate`, `test_brianza_pit_lane_v2`, `test_brianza_circuit`, `test_reusable_sky_and_time_of_day`, `godot --headless --path . -s res://scratch/measure_brianza_budget.gd`.
Expected: PASS; `BUDGET draw_calls` tidak melebihi 169.

- [ ] **Step 5: Commit**

```bash
git add scripts/world/brianza_paddock.gd scripts/world/brianza_pit_complex.gd scripts/world/brianza_environment.gd tests/test_brianza_paddock.gd
git commit -m "feat(brianza): fill the paddock with apron, service road, transporters, hospitality tents, fence, gate and parking"
```

---

### Task 6: Anggaran, flythrough gate, dokumentasi alur kerja, regresi penuh dan laporan

**Files:**
- Create: `scratch/capture_phase13_3_views.gd`, `executor-report/reports/FASE-13-3-BRIANZA-CIVIL-PIT-PADDOCK-REPORT.md`
- Modify: `Circuit-Environment-Component-Guide.md` (Tahap 2 dan Tahap 5), `docs/AGENT-WORKFLOW.md` (bagian 4), `ROADMAP.md`
- Test: `tests/test_brianza_circuit.gd` (tambah `#T7` anggaran) atau pemeriksaan di `scratch/measure_brianza_budget.gd`

**Interfaces:** Consumes semua tugas sebelumnya. Produces bukti visual `phase-13-3-*` dan dokumen alur kerja.

- [ ] **Step 1: Tulis pemeriksaan anggaran yang gagal bila terlampaui.** `#T7`: jumlah draw call environment (logika `scratch/measure_brianza_budget.gd`) <= 169 dan segitiga <= 320.000; cetak angka aktual. Jalankan: `godot --headless --path . -s res://scratch/measure_brianza_budget.gd`. Jika > 160, gabungkan mesh (mis. marking dan sign pit, bagian paddock) sampai <= 160, atau lapor jujur angka akhirnya.

- [ ] **Step 2: Skrip flythrough `scratch/capture_phase13_3_views.gd`** (salin kerangka `scratch/capture_phase13_2_views.gd`, HUD disembunyikan seperti `capture_phase13_2_clearance.gd`; nama keluaran baru): kamera setinggi chase (jalan + 3 m, lateral 0) menghadap 60 m ke depan tiap 150 m di seluruh lap, ke dua arah, digabung menjadi contact sheet; ditambah aerial pit, aerial paddock, pit entry, pit exit, dan Day/Sunset/Night. Jalankan: `godot --path . --resolution 1920x1080 --script res://scratch/capture_phase13_3_views.gd`. Periksa setiap gambar: tidak ada rumput menutupi jalan (terutama s 3260 sampai 4030), tidak ada barrier di lane, paddock terisi, tidak ada kotak catur pada rumput.

- [ ] **Step 3: Dokumentasi alur kerja.** Tambahkan ke `Circuit-Environment-Component-Guide.md`: aturan Layout-Driven Reuse (R1 sampai R3 spec), gate terrain mesh-level untuk track berelevasi (Tahap 2), flythrough gate dan gate lintasan pit bebas barrier (Tahap 5). Tambahkan ke `docs/AGENT-WORKFLOW.md` bagian 4 baris yang sama secara singkat. Perbarui `ROADMAP.md` dengan Fase 13.3.

- [ ] **Step 4: Regresi penuh dan smoke**

Run: `Get-ChildItem tests\test_*.gd | ForEach-Object { godot --headless --path . -s "res://tests/$($_.Name)" }` (aturan khusus di Global Constraints), lalu `godot --headless --path . -s res://scratch/smoke_phase13_2_pit.gd` dan smoke native 3 lap 20 mobil (`scratch/smoke_brianza_race.gd`) dengan pengukuran frame, kembali ke menu, dan orphan node.
Expected: semua suite PASS; pit stop terlaksana di layout baru; angka FPS dan orphan dilaporkan apa adanya.

- [ ] **Step 5: Laporan** `FASE-13-3-BRIANZA-CIVIL-PIT-PADDOCK-REPORT.md` (Bahasa Indonesia, ringkas dan jujur): perubahan, nomor test, draw call sebelum dan sesudah, daftar tangkapan, gate yang belum lulus (mis. 60 FPS terkunci) tanpa pelunakan.

- [ ] **Step 6: Commit**

```bash
git add scratch/capture_phase13_3_views.gd executor-report/reports/FASE-13-3-BRIANZA-CIVIL-PIT-PADDOCK-REPORT.md executor-report/screenshots/phases Circuit-Environment-Component-Guide.md docs/AGENT-WORKFLOW.md ROADMAP.md tests/test_brianza_circuit.gd
git commit -m "docs(fase-13-3): flythrough gate, layout-driven reuse workflow rules, budget check and executive report"
```

---

## Self-Review

- **Spec coverage:** G1 → Task 2; G2 → Task 1 (armco/zona) dan Task 3, 4 (bentuk lane); G3 → Task 3 (stall di lurusan) dan Task 5 (paddock mengikuti pit dan ruang jalan lain); G4 → Task 5; G5 → Task 1 (`#Z7` lint, kontrak) dan Task 6 (docs, flythrough, anggaran). T1 sampai T7 spec → `#T1.x`, `#P3`, `#Z3/#Z7`, `#P2`, `#K1 sampai #K8`, `#Z7`, anggaran Task 6. K1 → Task 3; K2 → Task 1; K3 → Task 3; K4 → Task 5; K5 → Task 4; K6 → Task 1 (`#Z5` audit).
- **Konsistensi nama:** `PitZone.from_layout/contains/outside_ranges`, `ground_platforms()`, `solid_footprints()`, `wall_end_cushions`, `field_tone_index`, `transporter_poses` dipakai identik di semua tugas.
- **Catatan jujur:** metode tepat lantai luar, noise tone, dan bentuk mesh diserahkan ke executor (spec bagian 8); invarian dan test adalah kontraknya.
