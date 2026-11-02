# FASE 21.4 — Garage & Manga Transition Engine

**Tanggal:** 2026-11-02  
**Agen:** OpenAI Codex — Executor  
**Branch pengembangan:** `fase-21-4-garage-transition-engine`; terintegrasi fast-forward ke `main` sebagai `328385e`.  
**Status:** implementasi fungsional, Engine Test W dan 100/100 suite PASS setelah merge; gate native performa/no-warning tetap terbuka dengan pengecualian developer.  
**Biaya aset:** 0 kredit; tidak ada generation atau dependensi baru.

## Izin dan prasyarat

- Developer mengizinkan commit Fase 21.3, penggantian checklist aktif, dan mempertahankan carry-over musik/pit crew dalam keadaan tertunda.
- Fase 21.3 di-commit sebagai `9c043a5` (`feat(audio): add per-family GT3 engine voices`), lalu dibuat branch 21.4.
- Commit 21.3 hanya mencakup kode/audio profil/generator/test/laporan terkait serta prompt 21.4. Perubahan `AGENTS.md` dan `.import` lain yang sudah ada tidak ikut di-stage atau ditimpa.
- Developer memilih **tanpa blip** saat ganti tim.
- Commit 21.4 awalnya ditunda karena izin pertama khusus untuk 21.3; developer kemudian menyetujui commit → merge → push setelah playtest OK. Hasil integrasi dicatat di bagian akhir.

## Implementasi

- `scripts/ui/garage_team_select.gd`: `_play_launch_rev()` mengambil `EngineProfile.for_team(selected_team)`; stream `on_stream`, pitch `pitch_for(7500.0)`, gain `-3.0 + on_gain_db`; tetap memakai player `LaunchRev` dan bus `SFX`.
- `scripts/ui/manga_race_transition.gd`: ROAR mengambil profil `_team`. Kurva rev memakai RPM 7500 → 6000 pada flash dan 6000 → 3500 pada panel, semuanya melalui `profile.pitch_for()`. Fade wipe dimulai dari `on_gain_db`, bukan mereset gain keluarga.
- Pada frame masuk snap negatif, `SnapExhaust` memutar `UPSHIFT_STREAM` untuk NA atau `BLOW_OFF_STREAM` untuk turbo, gain `EngineAudio3D.ONE_SHOT_DB`, bus `SFX`. Node dimiliki transisi dan ikut dibebaskan saat transisi selesai.
- Guard `AudioManager.has_output()` dipertahankan, termasuk perilaku headless.
- `scripts/audio/engine_audio_3d.gd`: konstanta `ENGINE_STREAM` dan komentar konsumen lamanya dihapus setelah pencarian memastikan tidak ada pemakai tersisa. File `assets/audio/engine/gt3_engine_loop.wav` **tetap ada**, termasuk penggunaan essential-audio test-nya.
- Tidak mengubah simulasi RPM, roster, kurva sirkuit, layout UI, atau aset audio.

## TDD

`tests/test_garage_transition_engine.gd` menjalankan tim 0 (V8 NA), 1 (V10 NA), dan 2 (V6 twin-turbo):

- launch menggunakan stream keluarga, pitch dan gain profil;
- scene transisi asli menggunakan stream tim terpilih;
- snap NA/turbo dipilih saat state FLASH;
- pitch turun sepanjang flash/panel tanpa mengganti keluarga.

RED bersih: **15 assertion gagal**, exit 1, tidak ada parse/script error. GREEN: **15 assertion PASS**, exit 0 via `tools/run_tests.ps1 -Filter garage_transition_engine`.

Percobaan test awal keluar saat threaded world load belum selesai dan menghasilkan error preload/shutdown; percobaan berikutnya sempat timeout saat menunggu load. Fixture final menahan resource dunia di cache secara sinkron sebelum intro meminta threaded load, lalu menguras request sebelum intro berikutnya/shutdown. Tidak ada perubahan loader produksi atau fallback untuk menyembunyikan masalah.

## Suite penuh — latar depan, serial

Perintah tiap baris: `powershell -NoProfile -File tools/run_tests.ps1 -From <awal> -To <akhir>`; tidak ada irisan lebih dari 10 suite dan tidak ada suite paralel/latar belakang.

| Irisan | Suite | Durasi runner (detik) | Gagal |
| --- | ---: | ---: | ---: |
| 0–9 | 10 | 171 | 0 |
| 10–19 | 10 | 306 | 0 |
| 20–29 | 10 | 71 | 0 |
| 30–39 | 10 | 59 | 0 |
| 40–49 | 10 | 43 | 0 |
| 50–59 | 10 | 370 | 0 |
| 60–69 | 10 | 52 | 0 |
| 70–79 | 10 | 280 | 0 |
| 80–89 | 10 | 147 | 0 |
| 90–98 | 9 | 61 | 0 |
| **Total** | **99** | **1560** | **0** |

Tambahan setelah pembersihan konstanta lama: `-Filter audio_and_race_weekend` PASS (1 suite, 255 detik). Runner memeriksa exit 0, minimal satu `[PASS]`, tanpa `[FAIL]`, `SCRIPT ERROR`, atau `Parse Error`.

## Smoke native dan bukti visual

Godot 4.7.2, D3D12 Forward+, NVIDIA RTX 3050 Laptop GPU, viewport 1920×1080. Probe sementara dijalankan dari `temp/`, tidak menjadi kode runtime permanen.

- Jalur scene asli: garasi → `launch(true)` → manga → race → HQ, diulang untuk tim 0/1/2.
- Runtime membuktikan `LaunchRev.playing`, `EngineRoar.playing`, dan `SnapExhaust.playing`, dengan loop yang sesuai tim.
- Ketiga intro dilepas setelah handover/wipe; kembali HQ menghasilkan **0 orphan node**, baseline 0, untuk ketiga tim.
- Balapan native Apex Ring, cuaca dry, 3 lap, 20 mobil mencapai finis. Bagian panjang balapan dipercepat melalui `world.step(1.0 / 60.0)` berkelompok, bukan observasi seluruh lap pada kecepatan real-time.
- Capture panel memakai stepping metode animasi asli untuk mendapatkan frame konsisten terlepas dari hitch load; bukan klaim pengukuran timing visual real-time.

- Pemeriksaan akhir `-Filter engine`: **2/2 suite PASS**, mencakup profil mesin dan regression garasi/transisi setelah seluruh perubahan kode.
- Verifikasi playback berasal dari state player runtime, **bukan persetujuan dengar subjektif developer untuk 21.4**.

Enam capture telah dibuka dan dimensi PNG diperiksa, semuanya 1920×1080; tiga view garasi dan tiga view manga, bukan enam sudut kamera balapan:

- `executor-report/screenshots/phase-21.4/team_0_garage.png`
- `executor-report/screenshots/phase-21.4/team_0_manga.png`
- `executor-report/screenshots/phase-21.4/team_1_garage.png`
- `executor-report/screenshots/phase-21.4/team_1_manga.png`
- `executor-report/screenshots/phase-21.4/team_2_garage.png`
- `executor-report/screenshots/phase-21.4/team_2_manga.png`

## Batas verifikasi / gate belum lulus

- Run native terakhir: mean **16,67 ms**, worst **19,27 ms**, 120 sampel frame setelah warmup. Run sebelumnya: mean 16,67 ms, worst 17,31 ms. Ini **tidak membuktikan locked 60 FPS tanpa drop**; gate performa penuh AGENTS.md belum terpenuhi. Tidak memperluas tugas audio ini menjadi tuning renderer.
- Pada exit native muncul warning **7 Texture RID** dan **44 ObjectDB instances** bocor, meskipun orphan node saat kembali HQ = 0. Warning masih muncul setelah probe membebaskan scene menu dan menunggu 10 frame sebelum quit. Asal warning belum diisolasi; tidak diklaim sebagai bug lama atau akibat perubahan 21.4.
- Native smoke tidak mencakup badai hujan atau semua kamera/preset. Enam bukti visual adalah state garasi/manga yang berubah dalam tugas ini, bukan verifikasi enam kamera 3D penuh.
- Karena batas tersebut, laporan ini menyatakan kelulusan implementasi fungsional/test, **bukan sign-off DoD global tanpa pengecualian**.

## Carry-over tetap tertunda

Musik gelombang 2 setelah refill 4 Nov dan diskusi matriks performa pit crew Fase 17 tetap di luar tugas, tidak ditandai selesai.

## Investigasi gate native lanjutan — atas permintaan developer

### Texture RID: terisolasi ke reflection atlas engine

Baseline native memuat scene secara dinamis, membebaskannya, menunggu frame cleanup, dan mencatat output verbose:

| Eksperimen | Orphan node | Warning Texture RID saat exit |
| --- | ---: | ---: |
| Root kosong + autoload, D3D12 | 0 | 0 |
| Menu saja, D3D12 | 0 | 7 |
| Garasi saja, D3D12 | 0 | 7 |
| Race saja, D3D12 | 0 | 0 |
| Menu saja, Vulkan | 0 | 7 |
| Menu tanpa ReflectionProbe, eksperimen diagnostik saja | 0 | 0 |
| Menu, World3D diganti setelah cleanup | 0 | 7 |

`GarageEnvironmentBuilder._build_reflection_probe()` membuat `EpoxyReflections`; menu dan garasi memakai builder ini, race tidak. Pola lokal cocok dengan bug upstream [godotengine/godot#122498](https://github.com/godotengine/godot/issues/122498), **Reflection atlas leaks 7 texture RIDs: color_views and color_buffer**. Issue menjelaskan enam color views + satu color buffer tidak dilepas oleh `LightStorage::_reflection_atlas_clear`; patch engine dirujuk sebagai [#124743](https://github.com/godotengine/godot/pull/124743).

Tidak menghapus reflection probe produksi, tidak mematikan refleksi, tidak mengganti renderer/preset untuk menutupi warning, dan tidak memanggil `free_rid()` terhadap RID internal milik engine. D3D12/Vulkan sama-sama terpengaruh pada binary yang diuji. Menghilangkan warning secara benar memerlukan binary engine yang memuat patch tersebut; versi proyek tetap dipin 4.7.2 sampai ada izin eksplisit untuk evaluasi/perubahan engine.

Eksperimen penggantian World3D pertama juga menghasilkan `scenario is null`; menahan referensi World3D lama sampai setter selesai menghilangkan error eksperimen itu, tetapi tidak menghilangkan tujuh RID. Tidak ada workaround World3D yang diterapkan pada game.

### ObjectDB: tidak muncul pada flow terinstrumentasi terakhir

- Flow asli garasi → ROAR/snap → race → HQ terinstrumentasi: player aktif dan 0 orphan, tanpa warning ObjectDB.
- Flow satu tim sampai finis 3 lap dengan `quit()` langsung pernah melaporkan **2 RefCounted** ber-reference-count 0. Flow dengan coroutine selesai sebelum deferred `quit()` melaporkan **0 ObjectDB leak**.
- Flow typed tiga tim yang mendekati probe awal, termasuk balapan 3 lap dan kembali HQ tiap tim, juga melaporkan **0 orphan dan 0 ObjectDB leak**, bahkan dengan direct `quit()`.
- **44 ObjectDB pada probe capture awal belum direproduksi secara identik dan identitasnya tidak tersedia dari run awal non-verbose.** Tidak mengklaim menemukan atau memperbaiki kebocoran game 44 objek. [INFERENCE] Lifetime coroutine/probe capture memengaruhi diagnostik shutdown; bukti terkini tidak mendukung penambahan cleanup spekulatif ke game.

### Profil frame pacing: bedakan biaya kerja dari limiter

Perintah existing profiler: `scratch/profile_frame_budget.gd -- apex_ring 10 uncapped` dan `... capped`, D3D12 1080p, RTX 3050 Laptop, layar 144 Hz. Tidak ada perubahan produksi untuk profil ini.

| Metrik | Uncapped | Capped 60 |
| --- | ---: | ---: |
| Sampel frame | 1150 | 601 |
| Wall frame mean (ms) | 8,70 | 16,67 |
| Wall frame p95 (ms) | 13,01 | 16,84 |
| Wall frame p99 (ms) | 15,66 | 17,57 |
| Wall frame max (ms) | 27,79 | 27,75 |
| Render CPU max (ms) | 2,78 | 2,64 |
| Render GPU max (ms) | 4,28 | 5,25 |
| Frame >20,83 ms | 1 | 2 |

`scratch/profile_world_step.gd -- apex_ring 10`: langkah CPU dengan sim tick mean 3,750 ms, p95 4,146 ms, max 8,167 ms; tanpa sim tick mean 2,367 ms, max 4,561 ms. Tidak ada langkah >9 ms. Profiler section ini menjalankan urutan bagian world secara manual, sehingga bukan profil sampling seluruh proses.

Baseline **root kosong**, tanpa garasi/race, `Engine.max_fps = 60`, vsync off: 300 frame, mean 16,666 ms, p95 16,693 ms, p99 16,773 ms, max 17,367 ms; **146/300** interval melewati 16,6667 ms. Jadi kriteria absolut setiap interval <=16,66 ms gagal bahkan tanpa workload game. [INFERENCE] Sebagian overshoot berasal dari pacing/penjadwalan, bukan beban audio. Asal setiap outlier race 27 ms belum terisolasi dengan profiler OS; tidak diklaim seluruh spike terselesaikan.

Keputusan teknis: tidak mengoptimalkan renderer, menurunkan kualitas, mengubah fisika, atau mengganti limiter tanpa bottleneck yang terbukti. Biaya GPU/section CPU memiliki headroom dalam sampel ini; locked-60 tanpa satu pun interval terlambat tetap **belum terbukti**.

Log diagnostik berada di `temp/phase214_*`; laporan ini menyimpan temuan penting karena `temp/` gitignored. Tidak ada kode game tambahan yang diubah selama investigasi ini.

## Keputusan penerimaan developer setelah investigasi

Developer memilih **“Pertahankan engine; catat gate terbuka”**: menerima deliverable fungsional Fase 21.4 dan 99/99 PASS dengan pengecualian native eksplisit, tanpa mengubah pin Godot 4.7.2. Evaluasi engine berpatch dan investigasi outlier performa dilanjutkan sebagai tugas terpisah, bukan pekerjaan terselubung di fase audio ini.

Status checkpoint penerimaan: **Fase 21.4 diterima secara fungsional dengan pengecualian native yang disetujui developer**. Gate locked-60/no-warning global tetap terbuka; tidak disamakan dengan sign-off DoD global. Carry-over musik/pit crew tetap tertunda. Pada checkpoint ini integrasi belum dilakukan; hasil integrasi berikutnya tercatat di bagian akhir.

## Tambahan yang disetujui — Engine Test / Free Rev dengan W

### Perilaku dan cakupan

Developer menyetujui Engine Test, bukan tuning statistik:

- **Tahan W:** mulai loop mobil tim terpilih dari idle; RPM audio naik halus menuju batas profil, lalu berdenyut dalam rentang limiter yang terbatas.
- **Lepas W:** RPM turun ke idle, lalu fade sampai berhenti. Release dari RPM simulasi >=6000 memutar satu exhaust crack untuk NA atau blow-off untuk turbo. Tap pendek tidak memicu exhaust; key-up duplikat tidak memutar ulang one-shot.
- **Ganti tim, modal mismatch, kehilangan fokus, atau launch:** batalkan preview. Echo tombol yang masih ditahan tidak menyalakan mesin tim berikutnya. W diblokir selama modal/launch.
- Launch mengambil alih player loop yang sama; proses free-rev tidak lagi mengubah pitch/gain launch. Exhaust preview dimiliki scene garasi dan ikut dilepas saat scene berganti.
- Hint **`HOLD W // REV ENGINE`** ditambahkan di bawah kontrol panel tim. Tidak menutupi tombol atau panel yang ada pada enam capture yang diperiksa.
- Hanya suara presentasi mobil terpilih. Tidak mengubah statistik, RPM simulasi balapan, handling, atau posisi mobil. Tidak menambahkan blip otomatis saat ganti tim.
- **0 kredit aset**, tanpa dependensi/generation baru.

### File implementasi

- `project.godot`: action `garage_rev_engine`, terikat ke physical W.
- `scripts/ui/garage_team_select.gd`: handler press/release, state rev lokal, update berbasis delta, limiter, exhaust release, fade, pembatalan, dan hint. Memakai `EngineProfile.for_team()` serta loop/one-shot yang sudah tersedia; tidak mengalokasikan player tiap frame.
- `tests/test_garage_engine_test.gd`: regression perilaku menggunakan scene garasi asli. Mencakup kurva rise, kesetaraan 60/120 FPS, batas/pulse limiter, release RPM tinggi/rendah, fade, lima keluarga mesin dan tim terakhir, serta pembatalan dan handover launch.

### TDD dan suite penuh setelah tambahan

RED: W belum memulai engine preview, **1 assertion gagal**, exit 1, tanpa parse/script error. Jalur test yang membutuhkan player baru dilanjutkan setelah implementasi tersedia. GREEN: **27/27 assertion PASS**, exit 0.

Seluruh suite dijalankan ulang setelah tambahan ini, bukan memakai hasil 99 suite sebelum fitur. Perintah tiap irisan: `powershell -NoProfile -File tools/run_tests.ps1 -From <awal> -To <akhir>`, **serial di latar depan**, maksimal 10 suite.

| Irisan | Suite | Durasi runner (detik) | Gagal |
| --- | ---: | ---: | ---: |
| 0–9 | 10 | 177 | 0 |
| 10–19 | 10 | 312 | 0 |
| 20–29 | 10 | 44 | 0 |
| 30–39 | 10 | 91 | 0 |
| 40–49 | 10 | 44 | 0 |
| 50–59 | 10 | 345 | 0 |
| 60–69 | 10 | 83 | 0 |
| 70–79 | 10 | 285 | 0 |
| 80–89 | 10 | 135 | 0 |
| 90–99 | 10 | 79 | 0 |
| **Total** | **100** | **1595** | **0** |

### Smoke native tambahan

Godot 4.7.2, D3D12 Forward+, RTX 3050 Laptop, viewport 1920×1080. Probe sementara menginjeksikan event W melalui `Input.parse_input_event()`, bukan memanggil handler garasi langsung. Hasil: **82 PASS, 0 FAIL**, exit 0.

- Seluruh **13 mobil/tim**: loop terpilih benar dan player aktif, held RPM berada dalam rentang limiter, release memutar exhaust keluarga yang tepat, duplicate key-up tidak mereset playback exhaust, dan kedua player berhenti setelah fade.
- Ganti tim saat W masih ditahan, echo W, modal mismatch nyata, serta launch nyata tidak menyisakan atau mengaktifkan ulang engine preview.
- Kehilangan fokus diuji dengan dispatch notifikasi focus-out native; bukan pengujian Alt-Tab oleh operator.
- Launch → manga → race 3 lap/20 mobil → HQ berhasil. Balapan mencapai finis setelah **16457** langkah tetap 1/60 s yang dijalankan berkelompok untuk mempercepat smoke; bukan seluruh balapan pada waktu nyata.
- Kembali HQ: **0 orphan node**.
- Enam screenshot baru telah dibuka dan header PNG diperiksa, semuanya **1920×1080**:
  - `executor-report/screenshots/phase-21.4/engine_test_team_0.png`
  - `executor-report/screenshots/phase-21.4/engine_test_team_1.png`
  - `executor-report/screenshots/phase-21.4/engine_test_team_2.png`
  - `executor-report/screenshots/phase-21.4/engine_test_team_3.png`
  - `executor-report/screenshots/phase-21.4/engine_test_team_4.png`
  - `executor-report/screenshots/phase-21.4/engine_test_team_12.png`

Log smoke: `temp/phase214_engine_test_native.out` dan `.err` (gitignored). Probe `.gd` sementara dibersihkan setelah verifikasi; regression permanen tetap ada di `tests/`.

### Gate terbuka tetap berlaku

Run capture native tambahan ini kembali mencetak **7 Texture RID** dan **44 ObjectDB instances** pada shutdown, meskipun kembali HQ 0 orphan dan exit 0. Jadi warning 44 objek yang tidak terulang pada beberapa probe investigasi sebelumnya **muncul lagi pada probe capture tambahan ini**; tidak diklaim sudah diperbaiki atau seluruhnya terisolasi. Tidak ada klaim performa locked-60 baru atau persetujuan dengar subjektif.

Keputusan developer sebelumnya tetap dipertahankan: Godot dipin 4.7.2, gate native global terbuka secara eksplisit, tanpa menghapus refleksi/menurunkan kualitas. Fitur W terverifikasi secara fungsional; bukan sign-off DoD global tanpa pengecualian. Integrasi Git dilakukan setelah persetujuan developer yang dirinci di bawah.

## Integrasi Git — persetujuan developer

Developer menyetujui commit → merge → push setelah playtest dinyatakan OK. Target integrasi `main`, basis `c4bacf5`; saat preflight, `main` dan `origin/main` tidak divergen. Commit hanya memuat kode/test/laporan/bukti Fase 21.4 dan Engine Test; Fase 21.3 (`9c043a5`) ikut sebagai ancestor saat merge.

`todo.md` merupakan task board lokal yang sengaja di-ignore oleh `.gitignore:51`, sehingga tidak dipaksa masuk Git. Perubahan lokal `AGENTS.md` dan `.import` lain di luar lingkup fase dipertahankan tanpa ikut di-stage. Gate native yang diterima dengan pengecualian tetap berlaku.

### Hasil merge dan verifikasi

- Commit implementasi Fase 21.4 dan Engine Test: **`328385e`** — `feat(audio): add garage rev and team transitions` (19 file).
- Merge ke `main`: **fast-forward `c4bacf5` → `328385e`**, tanpa konflik, termasuk commit Fase 21.3 **`9c043a5`**. Tidak melakukan reset, stash, force checkout, atau menghapus perubahan lokal lain.
- Pemeriksaan tepat sebelum commit: `tools/run_tests.ps1 -Filter engine`, **3/3 suite PASS**.
- Suite penuh dijalankan **ulang pada `main` setelah merge**, serial di latar depan, maksimal 10 suite per irisan:

| Irisan | Suite | Durasi runner (detik) | Gagal |
| --- | ---: | ---: | ---: |
| 0–9 | 10 | 195 | 0 |
| 10–19 | 10 | 355 | 0 |
| 20–29 | 10 | 50 | 0 |
| 30–39 | 10 | 107 | 0 |
| 40–49 | 10 | 51 | 0 |
| 50–59 | 10 | 361 | 0 |
| 60–69 | 10 | 104 | 0 |
| 70–79 | 10 | 370 | 0 |
| 80–89 | 10 | 134 | 0 |
| 90–99 | 10 | 79 | 0 |
| **Total** | **100** | **1806** | **0** |

Setelah verifikasi ini hanya laporan integrasi yang diperbarui, tanpa perubahan kode runtime/test. Target push adalah `origin/main` (`https://github.com/LyKhan77/La-Voiture.git`); hasil ack push dicatat pada task board lokal setelah perintah Git selesai.
