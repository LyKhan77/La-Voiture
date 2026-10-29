# FASE 13.3 — Brianza Civil, Pit Lane & Paddock

**Status: selesai dengan gate terbuka.** Regresi penuh 58/58 lulus; target draw call dan gate 60 FPS terkunci belum terpenuhi (lihat bagian akhir).

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

## Perbaikan tim–box pit (commit e20b6db)

- Bug: setiap balapan hanya 10 dari 13 tim yang berlomba (`GtRace.active_teams`). Choreographer memotong id tim ke 0–9, sehingga tim 10–12 dilayani kru tim 9 (berdiri hingga 112 m dari mobil). Neo Wangan memetakan box dengan `clamp(team)` dan mengabaikan urutan stall sim. Warna shutter `PitBuilding` selalu tim 0–9.
- Perbaikan: kru dan job memakai id tim asli, tim tanpa box tidak mendapat kru; semua kompleks pit memetakan lewat `stall_index_for_team`; Wangan mendapat `assign_teams()`; `RaceWeekendWorld` memasang `active_teams` ke semua sirkuit dan shutter.
- Verifikasi: `tests/test_pit_team_assignment_contract.gd` (3 sirkuit × pemain tim 4/11/12, 54 assertion) gagal sebelum perbaikan dan lulus sesudahnya; seluruh 57 suite lulus. Probe 9 balapan dengan permintaan pit acak: hold pit terlama 51 dtk, tidak ada mobil macet permanen. Laporan "mobil macet" belum bisa direproduksi; dugaan: antrean rekan satu tim 8 m di belakang box (disengaja).
- Belum ditangani: garasi Neo Wangan netral (tanpa warna tim atau kru standby).

## Antrean pit dan servis (commit 19b7496)

- Keluhan uji manual: antrean menuju pit kurang halus, dan kru kadang diam sejenak saat mobil sudah masuk box.
- Antrean: mobil di pit lane mengerem sepanjang kurva nyaman (`PIT_COMFORT_DECEL` 5 m/s², batas keras `PIT_BRAKE_MAX` 9 m/s²) alih-alih berhenti mendadak; mobil mengikuti mobil di depan pada jarak pengereman; rekan satu tim menumpuk 8 m di belakang box; pelepasan dari box dan penggabungan ke fast lane menunggu paling lama `PIT_RELEASE_WAIT_MAX_S` (5 dtk). Sebelumnya: deselerasi 38 m/s² dan lompatan posisi 0,40 m; sesudahnya ≤ 9 m/s² dan ≤ 0,05 m.
- Kru diam: akar masalahnya aturan "ikuti mobil di depan" menahan mobil kedua sebuah tim 0,3–0,5 m sebelum box-nya, karena mobil yang antre di box berikutnya berhenti sekitar 4–6 m di depannya; pengaman anti-stuck tidak aktif karena jarak 0,5 m dianggap sudah parkir. Mobil menunggu 4–19 dtk sebelum servis mulai. Perbaikan: mobil yang menuju box-nya sendiri mengabaikan mobil yang antre di luar box itu, titik tunggu mobil kedua dibatasi `stall_pitch_m − panjang mobil − 0,5 m` (Wangan: pitch 12 m), dan toleransi parkir pengaman 0,05 m. Setelah perbaikan jeda tiba-ke-servis 0,35–0,45 dtk (waktu mengerem), seluruh 20 mobil dalam satu putaran selesai dalam 70 dtk (sebelumnya 77).
- `tests/test_pit_queue_flow.gd`: 20 mobil masuk pit bersamaan dalam 4 skenario (kereta 30 m, rapat 20 m, hujan, tersebar). Menguji semua terlayani, hold terlama ≤ 100 dtk, deselerasi ≤ 10 m/s², tanpa lompatan > 0,05 m, dan servis mulai ≤ 1 dtk setelah tiba. Cek jeda servis gagal (14,1 dtk dan 5,9 dtk) saat perbaikan dimatikan, lulus saat dihidupkan.
- Keterbatasan yang diketahui: celah bumper di titik temu mobil yang keluar dengan mobil yang masuk ke box berikutnya tetap overlap 3–4 m pada skenario seluruh grid masuk bersamaan; hanya dicetak, tidak di-assert. Perbaikan penuh butuh rancangan ulang geometri temu keluar–masuk (fase tersendiri, menyentuh geometri sim dan 3D di tiga sirkuit).

## Regresi final dan smoke native

- Seluruh 58 `tests/test_*.gd` headless lulus (exit 0, 0 `[FAIL]`) setelah semua perubahan di atas, termasuk `test_pit_queue_flow.gd`.
- Smoke native `scratch/smoke_pit_race.gd` (1920×1080, vsync mati, 3 lap, 20 mobil, 6 mobil dipanggil ke box bersamaan, diukur saat 6 mobil berada di pit lane, 559 frame):

| Sirkuit | Pit stop | Mobil finis | Rata-rata | p95 | Terburuk | Orphan |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| Brianza | 6 | 20 | 16,75 ms (59,7 FPS) | 22,96 ms | 32,95 ms | 0 |
| Apex Ring | 6 | 20 | 16,69 ms (59,9 FPS) | 21,42 ms | 29,02 ms | 0 |
| Neo-Wangan | 6 | 20 | 16,75 ms (59,7 FPS) | 23,05 ms | 34,02 ms | 0 |

  Podium tampil di ketiganya. Draw call environment per sampel: Brianza maks 171, Apex maks 155, Wangan maks 146.

## Papan nama tim pada aset

- Permintaan: aset paddock dan garasi memiliki nama tim, dan komponen yang dipakai ulang konsisten di setiap sirkuit. Sebelumnya hanya garasi Apex yang punya `Label3D` `TeamPlate`.
- Komponen bersama `scripts/world/paddock/team_signage.gd`: nama diambil dari `GtData.TEAM_NAMES` (huruf besar), hurufnya geometri nyata (`TextMesh`, `curve_step` 4, ±390 segitiga per nama) yang digabung ke satu surface `MeshBatch`. Satu sirkuit membayar satu draw call untuk semua papan, bukan satu `Label3D` per garasi. Warna huruf gelap di atas pita terang dan terang di atas pita gelap; nama dikecilkan agar muat lebar papan.
- Penempatan: Apex dan Brianza di fascia garasi (mesh `TeamPlates` pada kompleks pit; Label3D Apex diganti). Wangan: gedung pit berdiri tepat di depan fascia garasi sehingga drum dan pintu shutter menutupnya; nama ditulis di pintu shutter lewat `PitBuilding.name_doors` (komponen gedung pit bersama). Paddock Brianza: nama tim pada sisi transporter yang menghadap trek (mesh `TransporterPlates`, sisi dipilih dari posisi lintasan).
- Aturan tim: papan hanya untuk tim yang punya box (`active_teams`), mengikuti urutan stall sim, diperbarui saat tim dipasang ulang (`assign_teams`/`apply_teams`).
- `tests/test_team_signage_contract.gd` (3 sirkuit × pemain tim 4/11/12, 57 assertion): satu papan per tim yang berlomba, ejaan sama dengan `TEAM_NAMES`, papan berada di depan garasi tim itu sendiri, tim tanpa box tanpa papan, semua papan garasi satu surface dengan lettering nyata, dan papan transporter Brianza berada di truk timnya sendiri menghadap trek. Test gagal (12 FAIL) sebelum implementasi.
- Bukti visual: `executor-report/screenshots/phases/phase-13-3-signage-*.png` (Apex, Brianza garasi dan transporter, Wangan pintu dan lane). Hasil capture awal Wangan memperlihatkan fascia di belakang pintu tidak terlihat, yang mendorong pemindahan nama ke pintu.
- Smoke native 3 lap dengan 6 pit stop setelah perubahan: tiga sirkuit finis 20 mobil, 0 orphan, rata-rata 16,67–16,71 ms (59,8–60,0 FPS), p95 22,8–24,5 ms (naik-turun 21–25 ms antar-run pada kode yang sama). Regresi penuh 59/59 lulus.
- Catatan: draw call environment per sampel bergantung posisi kamera (Brianza 171–218 antar-run), sehingga tidak cocok sebagai pembanding bersih untuk dua mesh tambahan (`TeamPlates`, `TransporterPlates`); papan garasi Apex justru turun dari 10 `Label3D` menjadi satu mesh.

## Gate terbuka

- Draw call environment Brianza: maksimum sampel 171 (sebelumnya 170) melewati batas plan <= 169 dan target <= 160, tetapi masih di bawah batas AGENTS.md (< 180). Apex dan Wangan di bawah 160. Tidak dioptimalkan pada fase ini.
- 60 FPS terkunci belum terbukti: p95 21–23 ms dan terburuk 29–34 ms di ketiga sirkuit, melewati 16,66 ms, sedangkan rata-rata 59,7–59,9 FPS. Pola sama di semua sirkuit termasuk Apex yang tidak disentuh fase ini, dan tidak berubah dengan pit lane penuh, jadi sumber lonjakan bukan environment Brianza. Perlu profiling sendiri; jangan mengklaim gate terpenuhi.
- Smoke 3 lap dengan pit stop sudah diukur native (tabel di atas) dan lulus tanpa error atau orphan.

## Belum dikerjakan (diusulkan untuk fase berikutnya)

- Garasi Neo Wangan masih netral di dalam (tanpa kru standby berwarna tim); namanya kini ada di pintu shutter. Apex dan Wangan belum punya transporter paddock; hanya Brianza yang memilikinya.
- Nilai `crew_skill` netral per tim di `GtData`; matriks performa kru lengkap ditunda ke mode karier.
- Rancang ulang titik temu keluar–masuk box (celah bumper 3–4 m), kebijakan pit AI, pelepasan tidak aman dan penalti, serta interaksi dengan Safety Car.
