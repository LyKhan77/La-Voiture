# TASK SPECIFICATION: FASE 13.3 — BRIANZA: KONTINUITAS TERRAIN, PIT LANE & ISI PADDOCK

**Task ID:** `TASK-FASE-13-3-BRIANZA-CIVIL-PIT-PADDOCK-POLISH`
**Assignee:** Senior Godot 4 Track Environment Engineer (peran Executor)
**Priority:** High (bug visual yang terlihat pemain di Round 03)
**Branch:** `fase-13-3-brianza-civil-pit-paddock-polish` (dari `main`)
**Spesifikasi Desain:** [`docs/superpowers/specs/2026-10-28-fase-13-3-brianza-civil-pit-paddock-polish-design.md`](file:///D:/Occupation/Porto/genex/La_Voiture/docs/superpowers/specs/2026-10-28-fase-13-3-brianza-civil-pit-paddock-polish-design.md)
**Rencana Implementasi (TDD):** [`docs/superpowers/plans/2026-10-28-fase-13-3-brianza-civil-pit-paddock-polish-plan.md`](file:///D:/Occupation/Porto/genex/La_Voiture/docs/superpowers/plans/2026-10-28-fase-13-3-brianza-civil-pit-paddock-polish-plan.md)
**Pedoman Sirkuit:** [`Circuit-Environment-Component-Guide.md`](file:///D:/Occupation/Porto/genex/La_Voiture/Circuit-Environment-Component-Guide.md) · **Alur Kerja:** [`docs/AGENT-WORKFLOW.md`](file:///D:/Occupation/Porto/genex/La_Voiture/docs/AGENT-WORKFLOW.md)
**Referensi Visual:** `reference-assets/tracks/brianza/` (terutama `view1_main_straight_pitstop.png`, `view4_parabolica_pit_entry.png`)

---

## 1. Latar belakang singkat

Developer melaporkan tiga masalah pada Autodromo di Brianza dan meminta review alur kerja. Planner mengukurnya (probe headless dan 10 screenshot diagnosis di `temp/diag/`; probe `temp/probe_brianza_overlap.gd`, `temp/probe_pit_armco.gd`, `temp/capture_polish_diag.gd`):

1. **Rumput menutupi track di akhir Sektor 2 menuju Sektor 3.** `ParcoRealeOuterFloor` adalah plane datar di y = -3,0 m, sedangkan jalan turun sampai -7,2 m (s = 3860 di y = -4,35 m). Plane menutup jalan dan mobil dari kamera di atasnya. Test `#L1.8` hanya menguji fungsi `ground_y_at()`, jadi tidak menangkapnya.
2. **Pit lane buruk.** Guardrail berdiri di lateral 11,5 m, di tengah fast lane (11,6 m), karena `TracksideFurnitureBuilder` membuka celah armco di zona pit **Apex** (s 3880 sampai 4350). Bentuk lane adalah salinan Apex v1 (ramp 35/45 m, aspal toon biru, tanpa cushion), dan garasi 0 sampai 2 berdiri di tikungan Parabolica.
3. **Paddock kosong** (bukan overlap): hanya PitBuilding dan RaceControlTower di atas ladang rumput.

Prinsip developer yang mengikat: komponen boleh reusable, tetapi **layout mengikuti spline track dan diimprovisasi agar logis**; komponen yang kurang baik (termasuk yang bersama) **diperbaiki**, dengan Apex Ring dan Neo Wangan tetap tidak berubah perilakunya.

## 2. Yang harus dikerjakan

Kerjakan enam tugas pada plan secara berurutan, masing-masing dengan siklus Red → Green → commit:

1. Kontrak zona pit `PitZone` (armco, runoff, floodlight, kamera TV memakai satu sumber).
2. Terrain: tanah selalu di bawah jalan, verge tidak melintasi jalan lain, tone rumput organik, platform pit.
3. Pit lane v2: stall di segmen lurus (`STALL_FIRST_S` = 5600), ramp 80/90 m, tepi 5,2 m, geometri Apex v2, aspal jalan.
4. Dressing pit sesuai concept art (chevron, cantilever "80 PIT ENTRY", pagar kawat, strip sponsor, drum).
5. Paddock terisi (apron, jalan servis, 10 transporter, tenda, pagar, gerbang, parkir).
6. Anggaran, flythrough gate, dokumentasi alur kerja, regresi penuh, laporan.

## 3. Aturan yang tidak boleh dilanggar

- **Jangan mengubah** `VERTICES`, `RADII`, `ELEVATION` Brianza maupun spline Apex. Butuh perubahan semacam itu: berhenti dan tanyakan.
- Apex Ring dan Neo Wangan harus identik: `test_shared_paddock_kit.gd` (hash), `test_track_environment.gd`, `test_pit_lane.gd`, `test_neo_wangan_circuit.gd` lulus tanpa diedit. Jika perubahan komponen bersama memecahkannya, perbaiki komponennya, bukan testnya.
- Test Brianza yang meng-hardcode layout lama boleh diperbarui hanya dengan alasan eksplisit (nilai K1). Jangan melonggarkan ambang.
- Working tree memuat banyak berkas developer yang belum di-commit. **Stage dengan nama berkas eksplisit**; jangan `git add -A`. Jangan menghapus atau menimpa berkas yang bukan buatan Anda (AGENTS.md aturan 1).
- Tangkapan baru memakai nama `phase-13-3-*`; jangan menimpa tangkapan lama.
- Anggaran: draw call environment <= 169 (target <= 160), segitiga <= 320.000, 0 orphan node. Objek berulang > 3 wajib MultiMesh/MeshBatch.

## 4. Definisi Selesai

1. Semua `tests/test_*.gd` lulus 100% (52 suite pada Fase 13.2; `test_race_world.gd` dengan `--fixed-fps 60`; suite berat yang melewati timeout 90 dtk dijalankan ulang), termasuk empat suite baru.
2. Flythrough chase-height ke dua arah, aerial pit dan paddock, pit entry/exit, dan Day/Sunset/Night diperiksa dan disimpan di `executor-report/screenshots/phases/phase-13-3-*`. Tidak ada rumput menutupi jalan (terutama s 3260 sampai 4030), tidak ada barrier di lane, paddock terisi.
3. Smoke native 3 lap 20 mobil termasuk pit stop di layout baru; frame time, kembali ke menu, dan orphan node dilaporkan apa adanya.
4. Laporan `executor-report/reports/FASE-13-3-BRIANZA-CIVIL-PIT-PADDOCK-REPORT.md` jujur, termasuk gate yang belum lulus (60 FPS terkunci belum pernah terverifikasi pada 13.2; jangan mengklaimnya tanpa pengukuran).
5. `Circuit-Environment-Component-Guide.md`, `docs/AGENT-WORKFLOW.md` dan `ROADMAP.md` diperbarui sesuai Task 6.

## 5. Bila ragu

Spec bagian 8 menyerahkan kepada Anda metode lantai luar, pola noise tone, bentuk mesh transporter/tenda/gerbang, dan jarak paddock yang tepat, selama invarian dan test plan terpenuhi. Hal yang mengubah apa yang dibangun (mis. perlu mengubah spline, atau anggaran draw call tidak mungkin dipenuhi) ditanyakan ke developer sebelum diputuskan sendiri.
