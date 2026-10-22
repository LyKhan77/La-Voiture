# FASE 2 — Pit Wall Command Center

## Hasil

Seluruh sembilan instruksi Fase 2 diimplementasikan sebagai berkas baru. `project.godot`, main scene lama, dan sumber simulasi Fase 1 tidak diubah.

- Token: `scripts/ui/ui_theme_tokens.gd` mencakup keenam warna wajib serta warna permukaan, tinta, teks, dan sektor ungu dari DESIGN.md.
- Shader: `shaders/halftone_screentone.gdshader` memakai dot radial 6px/radius1px/alpha7%; alpha tidak dikalikan dua kali. `shaders/chamfer_header.gdshader` memotong kanan atas14px pada45° dan men-skew latar−6°, tanpa memiringkan teks.
- Komponen: `scenes/pit_wall/driver_row.tscn`, `timing_tower.tscn`, `driver_strategy_deck.tscn`, `anime_radio_cutin.tscn`.
- Dashboard: `scenes/pit_wall/pit_wall_dashboard.tscn`; CanvasLayer10/20/30; ribbon56px, tower320px, workspace fleksibel, deck360px, ticker64px pada kanvas logis1920×1080.
- Skenario interaktif: `scenes/test_pit_wall.tscn`.
- Pemeriksaan regresi: `tests/test_pit_wall.gd`.

## Perilaku dan integrasi

`scripts/ui/pit_wall_session.gd` membungkus `RaceSimEngine` RefCounted yang sudah ada: simulasi60Hz, snapshot UI10Hz melalui `telemetry_updated(snapshot)`, radio melalui `radio_transmission(car_id,message,urgent)`. Pace/fuel hanya menerima mobil tim0/1 dan mode0..2. Kecepatan sesi1/2/4/8/16x.

Timing tower memakai20 mobil asli, interval, kompon, serta identitas mobil stabil saat klasemen berubah. Hover/fokus/seleksi membalik putih#F4F5F7/teks#050505 dan bergeser+6px dalam frame input yang sama; tanpa alokasi tween. Ini menggantikan tween110ms yang gagal mencapai target pada pemeriksaan transisi pertama. Seleksi bertahan saat mouse keluar; Escape melepas seleksi tower.

Deck memiliki empat kondisi/suhu ban dan bar bersegmen. `TireModel.wear` berarti kondisi tersisa, sehingga persentase=`wear*100`, bukan`(1-wear)*100`. Ambang60/30% diuji. Snapshot menggunakan `set_value_no_signal`, sehingga pergantian tab tidak mengirim ulang perintah. Persentase/suhu/waktu memakai JetBrains Mono lokal.

BOX mengubah `CarState.box_requested`, menampilkan acknowledgment, micro-shake workspace/tombol, flash80ms dan pulse crimson. Duplikasi request ditolak. Banner radio layer30 masuk220ms, memakai potret manga lokal, text wrap, lalu keluar; transmisi baru membatalkan tween lama. Seluruh banner transparan terhadap input.

Ribbon menampilkan lap aktif pemimpin dari `get_standings().lap_number`, bukan `engine.current_lap` yang menghitung lap selesai setelah lap pertama. Nama tim diambil dari engine, bukan teks tiruan.

Workspace berisi inspeksi mobil3D prosedural, radar2D dengan posisi mobil dari spline_distance, delta sektor asli, jejak lap dan kondisi ban. Radar diberi label SCHEMATIC: Fase1 belum menyediakan spline visual/lintasan3D. Grafik menunggu data nyata; tidak ada riwayat lap buatan.

## Aset lokal

- `assets/original-manga-racing-driver-portrait-he-cmvgxpt8.png`: potret radio manga hasil Genex; runtime tidak mengambil URL eksternal.
- `assets/fonts/`: Anton, Barlow Condensed Bold, JetBrains Mono, Chakra Petch Bold Italic; lisensi OFL masing-masing disertakan.
- Panel memakai sudut tajam, border tinta float2.5px pada permukaan modular, outline aksen, hard-offset shadow5px, dan tanpa blur/glass.

## Bukti verifikasi

Godot4.7.2 stable; acceptance runner keluar0: **26 PASS, 0 FAIL**, termasuk inversion instan/+6px≤120ms, hover cepat, ban empat sudut/ambang30–60%, pergantian strategi per mobil, penolakan perintah rival/invalid, BOX idempoten, radio re-entrant/auto-hide, lima time scale, dan reset micro-shake.

Input di game yang berjalan melalui MCP:
- Klik CAR#02 → deck dan viewer car_id1.
- Klik Attack/Eco → mobil0 tetap pace1/fuel1; mobil1 berubah pace2/fuel0.
- Tombol keyboard Right saat FuelSlider fokus → fuel mobil1 kembali1.
- Hover timing row → fill`f4f5f7ff`, tinta`050505ff`, shift`6.0`.
- Klik baris rival → fokus viewer/tower car_id2, target strategi tetapcar_id1.
- Klik BOX → request mobil target dan radio aktif; pulse crimson terukur alpha0.7875 pada120ms.

Render GUI standalone di GPU NVIDIA RTX3050/OpenGL Compatibility keluar0 pada dua ukuran aktual:
- [1920×1080](phase-2-dashboard-1920.png), fullscreen untuk menghindari pembatasan work-area Windows.
- [1280×720](phase-2-dashboard-1280.png), windowed.

Keduanya memakai kanvas logis1920×1080; semua zona tetap di dalam layar, portrait/dialog radio terlihat, BOX acknowledgment aktif. Klik ribbon4x melalui event mouse native juga diperiksa mencapai engine. Tidak ada runtime error pada capture akhir atau acceptance runner.

## Menjalankan

Buka `scenes/test_pit_wall.tscn` di Godot lalu **F6**. F5 tetap memakai main scene lama yang sengaja tidak diubah.

PowerShell:
```powershell
$Godot = 'C:/Users/Lee/Downloads/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64.exe'
& $Godot --path . --import
& $Godot --path . --rendering-method gl_compatibility res://scenes/test_pit_wall.tscn
& $Godot --headless --path . --script res://tests/test_pit_wall.gd
```

## Batas kontrak Fase1

BOX adalah perintah strategi yang nyata ke `CarState.box_requested`. Mesin Fase1 belum mengonsumsi flag ini untuk menjalankan pit lane, servis ban, atau refuel otomatis. Fase2 tidak menambahkan simulasi pit stop dan tidak mengaku sudah melakukannya. Suhu ribbon ditandai AIR karena engine menyediakan ambient, bukan suhu aspal. ERS ditampilkan dari state asli; model ERS dinamis bukan bagian pekerjaan ini.
