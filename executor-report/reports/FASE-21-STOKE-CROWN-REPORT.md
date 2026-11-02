# Fase 21 — Stoke Crown production integration

**Tanggal:** 2026-11-01–02. **Branch:** `fase-21-stoke-crown`. **Pelaksana:** Codex (systems/gameplay/technical art/profiling), dengan reviewer terpisah untuk diff akhir.

**Status:** implementasi playable, seluruh96suite headlessPASS setelah pembaruan dua fixtureUI, dan gate map/visual/cleanup terverifikasi. Gate strict60FPS/totalframe180drawcalls belum dinyatakan lulus. Developer menyetujui penundaan dua gate global dan meminta commit–merge–push pada 2026-11-02; regresi final perubahan fast-forward96/96PASS. Commit–merge–push diizinkan; hasil integrasi dapat diperiksa pada riwayatGit dan main remote.

## Hasil implementasi

Stoke Crown tampil sebagai Ronde 6 / JUN / GBR / GRAND_PRIX pada kalender existing. Scene produksi berada di `scenes/race_world/circuits/stoke_crown/stoke_crown_circuit.tscn`; pit merupakan subscene terpisah. Modul mengikuti `CircuitEnvironment` dan `CircuitPitComplex`, tanpa cabang khusus Stoke Crown dalam orkestrator balapan.

- Ribbon homologasi **5200.134 m**, lebar **14 m**, 18 label tikungan dan tiga sektor; kurva dibake dari snapshot blueprint frozen. Generator: `godot --headless --path . -s tools/build_stoke_crown_curve.gd`. Strip lingkungan juga dibake ke konstanta GDScript sehingga export tidak memerlukan pembacaan JSON mentah.
- Tier A memakai kit produksi: aspal/weather shader, sawtooth kerbs, runoff, gravel, rubber groove GP mengikuti `AdaptiveRacingLine`, Armco/Tecpro, papan rem, floodlight, delapan panel bendera FIA, gantry, grandstand/jumbotron, tower, signage dan transporter tim.
- Tier B mempertahankan lima GLB lokal: Crown Wing, runway/Spitfire, Luffield Arena, Becketts flyover, RAF hangar/tower. Landmark di-load sebagai imported `PackedScene`, lalu dibatch menjadi vertex-colour paint dan glass; tidak memakai filesystem GLB mentah atau URL runtime.
- **1600** pohon broadleaf, **600** meadow tufts, **633** hedgerow pieces; seluruh foliage memakai MultiMesh dan shadow OFF. Wind hidup; DAY minimal gloom0.5, SUNSET/NIGHT mendukung cuaca produksi. Glass/LED landmark menerima perubahan glow pada material aktual.
- Pit10stall pitch20m, standar13 kru per tim, identitas kru/fascia/box/signage/transporter mengikuti field aktif termasuk tim11/12; empat lampu kerja, pemisah pit dengan steel mesh, PIT IN/80/PIT OUT, serta entry/exit trigger metadata.
- Preview kalender dan empat referensi view berada di `reference-assets/tracks/stoke_crown/`, berasal dari capture produksi asli; scene memiliki WorldEnvironment untuk penggunaan standalone sesuai pola sirkuit lain.

## Fase 0 pada repo sumber

Acuan: `D:/Occupation/Porto/genex/mapgen-circuit/builds/stoke_crown/production-handoff.md`. Developer mengizinkan perubahan sumber setelah penjelasan overwrite, lalu mengarahkan improvisasi sesuai standar game. Semua target lama dibackup ke `builds/stoke_crown/phase0_backup/` (di-ignore Godot). Tidak ada scaffold mentah yang diregenerasi.

1. `ConceptPatch.apply()` dari `core/patch.gd`: radius vertices12/15 menjadi100m; pitch pit menjadi20m. Probe awal mereproduksi kink3275/4322; revisi menghilangkan keduanya dengan pergeseran maksimum titik pada stasiun sama **0.092m**.
2. Crown Wing dibangun ulang pada pitch20m, panjang authored205m (**206m termasuk slab**); box30..210m, bay5 s130. Layout/spec dan hash manifest disinkronkan. Generator GLB juga membebaskan root hasil export; rerun tidak meninggalkan warning resource leak generator.
3. Scene sandbox existing hanya diperbarui ribbon/runtime/camera melalui assembler. `test_pit_drive`: **25/25PASS**, limiter80km/h, stop s130, service3.017s, merge240.13,0barrier contacts,0off-pavement,18/18turn labels berurutan. `smoke_env`: **SMOKE_OK**,0floating road,5/5landmark. Galeri36shot sandbox diperbarui sebelum produksi.

Hash geometry setelah Fase0: `sha256:5b8aaf2e6e71ad67ba7272cbe427db03146ebd510139e21f2f03e2c2e581dd1a`. Provenance dan checksum aset lokal: `assets/tracks/stoke_crown/data/provenance.json`. Dokumen sumber tetap berada di repo mapgen.

## Keputusan integrasi yang berbeda dari angka handoff

- `stall_lane_m=5.2` dalam handoff akan memarkir mobil pada permukaan balap. API sim membaca lateral pusat mobil. Produksi memakai **box16.5m**, **fast lane10.8m** (inner edge8.5 + halfwidth2.3), **edge5.2m**. Ini mengikuti sandbox yang disetujui dan pola produksi Ardennes. Field pertama sim memakai **lap unwrapped +30m**, sementara box visual tetap s30..210.
- Ramp masuk80m dan keluar30m: box terakhir berada di s210 sebelum exit240, sehingga ramp keluar90m akan dimulai sebelum box terakhir. Queue8m dan pitch20m dipertahankan; tidak ada perubahan logika `GtDriving` atau sistem antrean.
- Terrain grid **16m**, flat civil shelf **22m**, window-min satu sampel; query ground menggunakan interpolasi segitiga yang sama dengan mesh, bukan bilinear. Ini mengurangi geometri sambil mempertahankan grounding jalan dan apron. Fence panels memakai quad double-sided; posts tetap instanced. Tidak ada pengurangan jumlah pohon/landmark atau placeholder.
- Standby crew memakai standar game **13 per tim**, menggantikan50figure total dalam sandbox. Tower tetap s232/lateral32, Crown Wing s120/lateral25, grandstand s90 tanpa rotasiPI tambahan, flyover s3650/lateral0. Armco produksi **2549post**, tetap melampaui2500.

## Bug visual pit yang ditemukan native

Smoke six-car pit pada fast-forward dapat melompati pose SERVICING terakhir. `_close()` kemudian membebaskan roda lama yang masih dicache actor, terutama saat kompon lama dan baru sama. Error: `set_rolling_speed` pada `previously freed`.

Perbaikan tiga baris di `scripts/car/pitstop_choreographer.gd`: selesaikan `_service_wheels_at(job,1.0)` sebelum cleanup, kecuali `hands_off`. Operasi idempotent melalui flags wheels_off/on dan memperbarui cache actor sebelum roda lama dibebaskan. Test baru `test_pit_service_skipped_frames.gd` terbukti RED→GREEN pada Apex+Stoke; penalti hands-off mempertahankan identitas roda dan tidak menambah gun shots. Simulasi balapan dan RNG tidak diubah.

## Bukti QA

### Headless

| Gate | Hasil |
|---|---|
| Test Stoke Crown | Scene/calendar,18turns,10garage/box,8panel,5landmark,1600tree/600grass,GPgroove,actual NIGHT/DAY glow; PASS |
| Terrain | Sampling tiap6m pada kiri/tengah/kanan jalan:0buried/0floating; full pit+working apron:0buried/0floating |
| Racing line Fase18 | **61assertions,0FAIL** seluruh playable circuit; Stoke40reversals/cap54, cross-slope0.29/cap0.4, width5.3m, outside-apex8/8, mean211km/h,0kink |
| Pit flood | Lima skenario termasuk20mobil serentak dan raced field; semuaPASS. Train54s, bunched51s; release mean0.38s/max1.9s; merge still0.1s |
| Kontrak | Keenam daftar mencakup Stoke: pit, environment, assignment, signage, identity, flag panels. Kontrak tim/signage3/3suitePASS setelah fix |
| Regresi penuh0–19 | 20/20PASS,1066s; suite audio menjalankan sembilan legacy suite lagi |
| Regresi penuh20–39 | 20/20PASS,290s |
| Regresi penuh40–59 | 20/20PASS,629s |
| Regresi penuh60–74 | 15/15PASS,617s |
| Regresi penuh75–95 | 21suite,368s; dua fixture lama masih menyebut Stoke unbuilt; diperbarui untuk Round6playable dan Round7reserved, lalu kedua suite diulangPASS (track_selector33s,visual_polish9s). Totalakhir96/96suitePASS |

Log terakhir setiap suite beserta ringkasan96/96 tersimpan di [verification/headless_summary.json](../screenshots/phases/phase-21/verification/headless_summary.json). Runner menolak exit code nonzero, tanpaPASS, atau FAIL/Parse Error/SCRIPT ERROR. `git diff --check` juga bersih.

### Native / visual

GPU **RTX3050 Laptop**, Godot4.7.2, D3D12/Forward+, High,1920×1080.

- Dry race awal:20/20finish,3lap,podium,0orphan. Run terpisah rata-rata **16.66ms/60FPS**,p95 **16.82ms**,worst26.91ms.
- Six-car pit setelah fix:20/20finish,6stops,peak6cars in lane,0orphan,tanpa error roda; **59.4FPS**,p95 **20.37ms**. BaselineApex dengan helper sama: **58.9FPS**,p95 **22.67ms**. Hasil satu run bukan bukti statistik regresi; keduanya belum membuktikan60FPS terkunci setiap frame.
- Profil kontinu tanpa visibility toggle (`scratch/profile_stoke_crown.gd`), High1080pstorm/night20mobil danpeak6pit: run awal mean16.178ms/**61.81FPS**,p9522.223ms,VRAM2034.2MB. **Run final tanpa prosesGodot lain**: mean **15.449ms /64.73FPS**,p95 **20.175ms**,worst28.747ms,VRAM **2026.5MB**,0orphan. Gate kapasitasp95≤16.6667ms **FAIL**; rata-rataFPS cukup, tail latency belum memenuhi target. Helper keluar1 secara sengaja agar gate ini tidak dapat dibaca sebagaiPASS.
- Loop final storm/night High16x: **20/20finish**,10stops (enam pemanggil awal serta strategi cuaca),podium→HQ,0orphan,**0FAIL**,tanpa error roda. Finalizer engine mencetak warning7TextureRIDs; node orphan tetap0.
- **103shot1080p**:33view DAY/SUNSET/NIGHT (six-camera gate+pit/garage/flyover/hangar/top) dan70chase tiap150m dua arah. Inspeksi contact sheet tidak menemukan penghalang di aspal atau jalan melayang. Tambahan6gambar line plan/worker/plot Fase18.
- [Contact sheet](../screenshots/phases/phase-21/gate_contact_sheet.jpg), [metrics](../screenshots/phases/phase-21/capture_metrics.json). Bukti lengkap di `executor-report/screenshots/phases/phase-21/`.
- [Galeri lengkap](../screenshots/phases/phase-21/index.html) mencakup semua mode, flythrough dan racing-line capture.

### Budget terukur

| Metrik | Nilai | Cakupan |
|---|---:|---|
| Triangle statis | **317054 /320000** | Environment+seluruhpit+TrackRibbon; termasuk outline passes |
| Native draw calls | **141 /160 maksimum** | Seluruh set statis termasukpit/road;33view/3waktu,shadows included,world dibekukan saat differencing |
| Flythrough environment | **74 maksimum**,p9573 |34view tiap150m,shadows included; node Environment saja,sebelum terrain LOD final |
| VRAM | **1854.77MB /2048MB** | Scene20mobil,six-camera gateHigh |
| VRAM storm/busy pit | **2026.5MB /2048MB** | Run kontinu final,20mobil/6pit; headroom kecil |

Total frame termasuk mobil terukur hingga477drawcalls pada beberapa kamera, melampaui target agregat180 dalam panduan. Budget set sirkuit≤160 terpenuhi; target agregat180 dan strict60FPS setiapframe tidak dinyatakan terpenuhi dari bukti ini. Sampling difference dalam smoke existing dapat bernilai negatif karena race/camera tetap bergerak ketika environment ditoggle; gunakan measurement33view yang dibekukan untuk budget set.

## Batas dan status repository

- Belum membuat export Windows/Web; loader memakai imported resource dan strip tidak memerlukan raw JSON, tetapi export executable/PCK belum diuji.
- Tidak mengubah spline Apex, driver roster, semantik racing line, LATERAL_ACCEL, cap kink legacy, atau dependency.
- Dua UID scratch Fase19 yang sudah ada saat mulai dibiarkan. Metadata34`.import` yang dinormalisasi editor dikembalikan ke line endings sebelumnya setelah diverifikasi konten normalisasi identik; tidak ada edit aset lain.
- Commit–merge–push disetujui developer pada 2026-11-02; hanya berkas tugas ini akan disertakan. File temp dan cacheGodot tidak ditambahkan ke version control. Carry-over diskusi performa pit crew tetap ditunda atas izin developer.

## Gate yang belum ditutup

Implementasi map dan seluruh96suite regresi selesai diverifikasi, tetapi fase tidak ditandai lulusDoD secara penuh: p95busy-pit masih20.175ms dibanding16.6667ms, dan batas agregat180drawcalls dengan seluruh kendaraan belum tercapai. Angka budget map terpisah (317054triangle/141calls) lulus. Perlu pekerjaan lanjutan pada frame pacing/pipeline seluruh race untuk menutup gate global; hasil rata-rata64.73FPS tidak dipakai untuk menyamarkan tail latency.


## Perubahan fast-forward dan keputusan rilis — 2026-11-02

Developer menerima penundaan gate performa global dan meminta menghapus 16×. Pilihan pemain sekarang hanya **1× / 2× / 4× / 8×** pada HUD balapan, pit wall dashboard, dan scene race legacy. Tombol keyboard **1–4** memilih kecepatan; tombol **5** tidak lagi mengubah kecepatan. Setter RaceWeekendWorld dan RaceSimEngine membatasi maksimum8×; PitWallSession menolak16×. Nilai internal pecahan tetap didukung setter untuk kebutuhan pengujian tick deterministik; pilihan UI tetap empat nilai resmi.

Test pit wall dan HUD terbukti RED sebelum implementasi, lalu GREEN: jumlah tombol, pilihan kecepatan, capAPI, penolakan16×, key5 diabaikan, dan key1–4. Runner determinisme, fixture safety-car/audio, smoke helpers, README dan spesifikasi kontrol mengikuti batas8×. Tidak ada perubahan fisika atau data balapan tersimpan.

Gate p95≤16.6667ms dan totalframe≤180drawcalls tetap **ditunda dengan persetujuan developer**, bukan dinyatakanPASS. Hasil profil terdahulu tetap berlaku sebagai bukti batas yang belum terselesaikan; perubahan batas fast-forward tidak dianggap perbaikan performa tersebut.

Verifikasi final setelah perubahan speed: **96/96suitePASS**, seluruhnya dijalankan melalui `tools/run_tests.ps1`, exit0 dan tanpaFAIL/Parse Error/SCRIPT ERROR. Irisan60–74 awal dihentikan secara terkontrol karena RAM menipis ketika tiga irisan berat bertemu; seluruh irisan tersebut kemudian diulang penuh dengan concurrency lebih rendah. Hasil terhenti tidak dihitung.

| Irisan | Jumlah suite | Durasi | Hasil |
|---|---:|---:|---|
| 0–19 | 20 | 1009s | PASS,0gagal |
| 20–39 | 20 | 282s | PASS,0gagal |
| 40–59 | 20 | 679s | PASS,0gagal |
| 60–74 | 15 | 558s | PASS,0gagal |
| 75–95 | 21 | 372s | PASS,0gagal |

NativeD3D12/High1080p, storm/night, pada8×: **13assertionsPASS,0FAIL**,20/20mobil finis3lap,10pitstop, podium→HQ,0orphan. Finalizer masih mencetak warning7TextureRIDs seperti run sebelumnya. Kontrol HUD1/2/4/8, capAPI8× dan key5 diabaikan lulus. [Bukti empat tombol](../screenshots/phases/phase-21/fast_forward_8x.png); log `verification/stoke_8x_loop.log`. Review terpisah tidak menemukan masalah baru.

Commit–merge–push ke main disetujui developer; hanya sumber/aset map, perubahan speed, test, dokumentasi dan bukti QA tugas ini disertakan. Dua UID Fase19 lama serta temp/cache/kredensial dikecualikan. Gate performa global tetap ditunda sebagaimana keputusan di atas.
