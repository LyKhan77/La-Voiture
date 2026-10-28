# FASE 13.3 — Brianza Civil, Pit Lane & Paddock

**Status: selesai dengan gate terbuka.** Regresi penuh lulus; target draw call dan gate 60 FPS terkunci belum terpenuhi (lihat bagian akhir).

## Implementasi

- Zona pit diturunkan dari `pit_layout` untuk celah armco, runoff Brianza, zona floodlight, dan kamera TV. Layout Apex mempertahankan panjang nominal 410 m.
- Lantai luar diturunkan di bawah elevasi minimum jalan. Gate baru membaca segitiga ground yang dirender, mengambil sampel jalan setiap 6 m dan pit setiap 6 m; verge dibatasi terhadap ruas lain. Tone rumput memakai pola lebar dan platform pit/paddock menahan tanah serta vegetasi.
- Pit Brianza memakai entry 5530 m, exit 150 m, stall pertama 5600 m, ramp 80/90 m, dan aspal shader jalan. Dinding dan cushion mengikuti wedge; marking, rambu, perlengkapan, pagar, chevron, gantry, dan strip sponsor ditambahkan.
- Paddock memakai apron, jalan servis, 10 transporter berwarna tim, tujuh tenda, pagar, gerbang, 16 kendaraan parkir, dan prop instanced/tergabung.

## Temuan dan verifikasi awal

- Rentang test plan 5580–5760 m mencakup ujung tikungan: radius terukur 116,8 m pada 5580 m. Gate gedung memakai jejak gedung aktual 5596–5744 m; radius minimum sampelnya 10.000 m. Spline tidak diubah.
- Gate terrain mencatat selisih terburuk tanah terhadap jalan −0,100 m dan terhadap sampel pit −0,030 m; titik verge yang diuji tidak masuk koridor ruas lain.
- `test_brianza_circuit.gd`: 118 assertion lulus; gate pit v2, zona pit, terrain, dan paddock lulus. `test_shared_paddock_kit.gd` mempertahankan hash mesh Apex. Smoke pit headless: masuk, servis, keluar, dan finis dalam 1.976 frame.
- Hitungan mesh environment headless: sebelum 70 draw call / 317.824 segitiga; sesudah 71 / 318.224. Ini hitungan struktur environment, bukan pengukuran draw call GPU seluruh scene.
- Flythrough dua arah setiap 150 m, aerial pit/paddock, pit entry/exit, dan Day/Sunset/Night direkam di `executor-report/screenshots/phases/phase-13-3-*`. Rekaman `clear` menghilangkan overlay; `final2` memuat perbaikan lantai garasi.
- Godot melaporkan `Failed to read the root certificate store` pada proses sandbox; test lokal tetap berjalan.

## Regresi dan smoke

- Seluruh 56 `tests/test_*.gd` dijalankan ulang headless (`test_race_world.gd` dengan `--fixed-fps 60`): 56/56 exit 0, 0 `[FAIL]`. Termasuk `test_shared_paddock_kit.gd` (hash Apex tidak berubah), `test_track_environment.gd`, `test_pit_lane.gd`, `test_neo_wangan_circuit.gd`, dan empat suite baru Fase 13.3.
- Smoke native Brianza (sesi Codex sebelumnya): balapan selesai, 20 mobil finis, podium tampil, orphan setelah free = 0. Frame time rata-rata 16,69 ms, p95 22,36 ms, terburuk 26,20 ms, 259 frame, 59,9 FPS rata-rata.

## Gate terbuka

- Draw call environment pada smoke: 167, 170, 169, 166, 70 per sampel. Satu sampel (170) melewati batas plan <= 169 dan semuanya di atas target <= 160, tetapi masih di bawah batas AGENTS.md (< 180). Tidak dioptimalkan pada fase ini.
- 60 FPS terkunci belum terbukti: p95 22,36 ms dan terburuk 26,20 ms melewati 16,66 ms. Rata-rata 59,9 FPS dari satu sesi smoke pendek; jangan mengklaim gate terpenuhi.
- Smoke 3 lap penuh dengan pit stop di layout baru belum diukur ulang secara native; smoke headless pit (masuk, servis, keluar, finis) lulus.
