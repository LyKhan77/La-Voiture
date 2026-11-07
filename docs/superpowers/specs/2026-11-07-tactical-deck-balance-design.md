# Desain: Keseimbangan Tactical Deck, Safety Car, dan Fondasi Stat Engineer/Pit Crew

Tanggal: 2026-11-07. Status: menunggu persetujuan developer. Penulis: Claude Code (Planner).
Probe pengukur: `temp/probe_balance.gd` (Gitignored, bisa dijalankan ulang). Lintasan ukur: Apex Ring, 4159 m, cuaca kering, seed 5.

## 1. Maksud dan alasan

Sebelum Career Mode dibangun, fondasi balapan harus punya keputusan yang nyata. Developer merasakan Tactical Deck "flat": balapan kering selesai dengan ban dan fuel STANDARD, dan satu-satunya tombol yang dipakai hanya ERS. Pengukuran membenarkan perasaan itu. Penyebabnya struktural, bukan soal angka kecil:

- Balapan kering tidak pernah butuh pit stop. Satu field 20 mobil, 15 lap, menghasilkan 0 stop. Soft tanpa stop menang 39 s atas Hard dalam 15 lap, dan wear Soft di akhir (0.66) masih di bawah cliff 0.75.
- Fuel awal selalu `fuel_use x laps x 1.05` (`scripts/gt/gt_race.gd:181`), jadi sisa selalu sekitar 0.25 lap (5 lap) atau 0.75 lap (15 lap). 15 dari 20 mobil masuk status `WARNING` di setiap balapan, sehingga peringatan "Fuel critical" selalu berbunyi tanpa bahaya nyata. Isi ulang di pit gratis dan tidak menambah waktu stop (`gt_driving.gd:1253`, `PIT_STOP_TIME` tetap 3.2 s).
- Rival tidak pernah mengganti `pace_mode`, `fuel_mode`, atau `ers_mode`. Satu-satunya pengecualian adalah ERS OVERTAKE acak 35% saat mulai menyalip (`gt_driving.gd:646`).
- Tiga dari sepuluh mode punya kurs tukar yang rusak (1 mobil, lap bersih, MEDIUM baru, baseline 80.50 s, wear 0.031 per lap, fuel 2.90 kg per lap):

| Mode | Waktu lap | Wear per lap | Fuel per lap |
|---|---|---|---|
| Fuel PUSH | 80.45 s (untung 0.05 s) | 0.031 | 3.62 kg |
| ERS DEPLOY atau OVERTAKE | 80.50 s (untung 0.00 s) | 0.031 | 2.90 kg |
| Pace ATTACK | 88.50 s (rugi 8 s) | 0.323 | 3.63 kg |
| Pace AGGRESSIVE | 79.55 s (untung 0.95 s) | 0.087 | 3.25 kg |
| Pace CONSERVE | 84.85 s | 0.014 | 2.46 kg |
| Fuel CONSERVE | 81.65 s | 0.031 | 2.32 kg |

  Hanya AGGRESSIVE yang punya trade-off sehat. PUSH tidak berguna, ATTACK jebakan, ERS tidak punya nilai di waktu lap.
- Safety Car muncul di pit exit pada 18 m/s, sedangkan leader dibatasi 27 m/s (`gt_race.gd:585`, `gt_driving.gd:549`), jadi kecepatan susul hanya 9 m/s. Waktu SC menjemput leader sampai 434 s (leader 5% lap melewati titik muncul, jarak 3990 m), 350 s di 25%, 230 s di 50%, 106 s di 75%, 22 s di 95%. Di balapan 10 lap (sekitar 13 menit) satu insiden buruk membuang lebih dari separuh balapan.

## 2. Keputusan yang sudah dibuat developer

1. Balapan 10 dan 15 lap mendapat satu pit stop wajib dengan jendela waktu. Sprint 3 lap dan Short GP 5 lap tetap tanpa pit wajib.
2. Fuel awal dipilih pemain di garasi. Layar Team Garage tetap memberi saran Crew (seperti `★ CREW PICK` untuk ban).
3. Pit lane tetap terbuka saat Safety Car (gaya F1 modern). Insiden berat memicu VSC dulu selama 8 sampai 15 detik sebelum naik ke SC, dan jeda itu menjadi jendela keputusan pemain.
4. Urutan kerja: (1) jemput SC cepat, (2) ekonomi mode, pit wajib, dan fuel pilihan, (3) rival memakai mode, (4) stat Engineer dan Pit Crew sebagai fondasi Career.

## 3. Tujuan, non-tujuan, anti-tujuan

Tujuan:
- Setiap opsi di deck punya konteks tempat ia menjadi pilihan terbaik. Tidak ada opsi yang selalu menang atau selalu kalah.
- Balapan kering 10 dan 15 lap punya variasi strategi nyata (kapan stop, fuel berapa, mode apa).
- AI memakai mode yang sama dengan pemain dan bereaksi terhadapnya, sehingga keputusan pemain memicu keputusan lawan.
- SC menjemput leader dalam batas wajar dan memberi pemain keputusan.
- Stat Engineer dan Pit Crew tersedia per tim sebagai pengungkit untuk Career, tanpa membangun Career itu sendiri.

Non-tujuan:
- Tidak membangun Career Mode, ekonomi, atau layar upgrade.
- Tidak mengubah model fisika ban Pacejka, model cuaca, atau pit lane (Fase 17, 26).
- Tidak mengubah kontrol titik `Curve3D` sirkuit.
- Tidak mengejar realisme 100% (ini game, keseimbangan lebih penting).

Anti-tujuan (dianggap gagal walau secara teknis jalan):
- SC dipicu berdasarkan posisi pit pemain (terasa curang).
- Rival jadi lebih pintar dari pemain mode AUTO, atau AUTO tidak memakai logika baru.
- Balapan hujan menjadi lebih buruk (hujan saat ini satu-satunya pemicu keputusan yang hidup).
- Seed yang sama tidak lagi menghasilkan balapan identik.
- Balapan 3 dan 5 lap jadi dipaksa pit.

## 4. Batasan

- Simulasi harus deterministik terhadap `race_seed`. Semua keputusan acak baru (arketipe rival, error pit crew, durasi VSC) memakai aliran hash sendiri seperti `GtStrategy.profile()` (`scripts/gt/gt_strategy.gd:45`), bukan `race.rng`, supaya urutan rng yang ada tidak bergeser.
- GDScript 2.0 dengan static typing. Kerja di branch `fase-*`. Tes headless baru dulu (Red lalu Green), regresi penuh via `tools/run_tests.ps1` dalam irisan di bawah 10 menit (lihat AGENTS.md bagian 10).
- Tes yang mengunci angka SC akan bergeser: `tests/test_safety_car_cinematic.gd` dan `tests/test_track_incidents_and_stewards.gd`. Mengubah kecepatan SC berarti memperbarui tes itu dengan alasan tertulis.
- Mode AUTO (`GtRace.suggest_tactic`, `decide_strategy`) harus memakai logika baru yang sama dengan MANUAL.
- Panjang balapan tersedia: 3, 5, 10, 15 lap (`scripts/ui/race_setup_menu.gd`, `LAPS`). Lap sekitar 80 s di Apex Ring.
- Frame budget 60 FPS dengan 20 mobil tidak boleh turun. Semua logika baru berjalan di tick sim 20 Hz yang sudah ada.

## 5. Rancangan per pekerjaan

### Pekerjaan 1: jemput SC cepat dan jeda VSC

- Ganti kecepatan SC yang belum menjemput leader dari 18 m/s ke sekitar 22 m/s. Beri leader batas kejar yang naik (sekitar 27 sampai 50 m/s) selama jaraknya ke SC masih jauh (kira-kira lebih dari 250 sampai 900 m), lalu turun ke 27 m/s mendekati SC. Pickup memakai logika `picked_up` yang sudah ada.
- Target terukur (keputusan saya, bisa diubah): waktu jemput terburuk di Apex Ring maksimal sekitar 170 s (dari 434 s), diukur ulang dengan `_sc_catchup()` di probe.
- Insiden berat (tiga tempat memanggil `set_flag(SC)`: `gt_driving.gd:272`, `gt_contacts.gd:217`, `gt_contacts.gd:260`) mulai dengan VSC selama 8 sampai 15 detik (durasi acak dari aliran hash sendiri), lalu naik ke SC. Selama VSC, pit lane terbuka dan saran Engineer "box under VSC" muncul. Rival yang aus ikut mempertimbangkan pit (pekerjaan 3).
- Pit lane terbuka saat SC dan VSC. Tidak ada penutupan otomatis.

### Pekerjaan 2: ekonomi mode, pit wajib, fuel pilihan

Pit wajib (balapan 10 dan 15 lap saja):
- Satu stop di jendela dari sekitar 20% sampai 80% jarak balapan (keputusan saya). Stop di bawah SC atau VSC tetap dihitung.
- Tanpa stop di akhir balapan, hukuman waktu ditambahkan ke waktu akhir lewat mekanisme `penalty_owed_s` yang sudah ada (besarnya keputusan saya: cukup besar sehingga tidak pernah menguntungkan, kira-kira 30 s, builder mengukurnya terhadap biaya pit). Jendela dan status wajib tampil di HUD dan Tactical Deck.
- Biaya pit stop (jalur pit pada 22 m/s, 3.2 s stop, slow in/out) belum terukur: probe 1-stop tidak terdaftar (`stops=0`). Builder harus mengukurnya sebelum menetapkan angka wear dan fuel apa pun.

Fuel pilihan:
- Fuel awal dipilih pemain di `scripts/ui/garage_team_select.gd` (area yang sama dengan pilihan ban). Saran Crew `★ CREW PICK` dihitung dari jumlah lap, `fuel_use` tim, dan rencana satu stop. Pemain boleh menyimpang.
- Waktu isi ulang proporsional dengan jumlah fuel yang ditambah (menggantikan stop tetap 3.2 s untuk bagian fuel). Besar konstanta diukur builder.
- Bobot fuel sudah ada di sim (`gt_driving.gd:354`, `fuel_factor = 1 - 0.0004 x fuel`), jadi start ringan lalu stop panjang lawan start berat tanpa isi ulang punya trade-off nyata. Builder memverifikasi lewat probe bahwa trade-off itu tidak didominasi satu sisi.
- Peringatan "Fuel critical" memakai `GtForecast.fuel_margin_laps` untuk mode aktif (margin negatif atau di bawah ambang), bukan batas tetap `fuel < 3.0` kg (`gt_driving.gd:792`). Sisa 5% tidak lagi diisi otomatis di start untuk pemain, tetapi rival memakai saran Crew yang sama.

Ekonomi mode:
- Fuel PUSH diberi untung nyata di waktu lap (target kira-kira 0.4 sampai 0.6 s per lap, keputusan saya) atau dihapus. Builder memilih lewat probe `_rate_table()`.
- Pace ATTACK diperbaiki menjadi dorongan singkat dengan untung jelas (kira-kira 1.5 s per lap) dan wear sangat tinggi, tanpa membuat ban meledak dalam 3 lap atau lebih lambat dari STANDARD.
- ERS memiliki nilai di waktu lap pada zona lurus dan anggaran per lap yang terbatas (regen lebih lambat dari `8.5` per detik saat rem, `gt_driving.gd:456`). Efek ERS pada peluang menyalip juga belum terukur dan harus diukur dulu.
- Kriteria penerimaan: di probe, untuk setiap mode ada konteks (panjang balapan, ban, posisi, fuel tersisa) tempat mode itu terbaik, dan tidak ada mode yang rugi di semua konteks.
- Wear dan cliff diubah hanya setelah biaya pit terukur. Target (keputusan saya): keseimbangan di antara rencana satu stop, bukan melawan rencana tanpa stop. Rencana satu stop yang masuk akal (Soft lalu Hard, Medium lalu Medium, stop awal lawan stop akhir, start ringan lawan start berat) masing-masing punya konteks tempat ia terbaik, dan selisih terbaik ke terburuk di antara mereka tidak lebih dari beberapa detik. Rencana tanpa stop bukan tujuan: hukuman pit wajib dipasang minimal 1.5 kali biaya pit terukur sehingga tidak pernah menguntungkan.

### Pekerjaan 3: rival memakai mode

- Beri tiap tim rival arketipe strategi dari aliran hash sendiri (misalnya undercut, overcut, hemat fuel) yang memilih `pace_mode`, `fuel_mode`, dan `ers_mode`.
- Rival menutup stop pemain (cover) bila gap di bawah ambang tertentu, dan mempertimbangkan pit saat SC atau VSC berdasarkan wear, supaya SC bukan keuntungan gratis khusus pemain.
- Rival memakai fuel awal sesuai saran Crew dan satu stop wajib di jendelanya.
- Hati-hati dengan antrean pit saat banyak rival masuk bersamaan (Fase 17 sudah menyelesaikan antrean pit; tes pit harus tetap lulus).

### Pekerjaan 4: fondasi stat Engineer dan Pit Crew

- Engineer: ubah `GtStrategy.profile()` yang kini acak per seed dan tersembunyi (`forecast_trust`, `read_noise`, `reaction_sectors`) menjadi satu stat per tim yang terlihat, ditetapkan di `scripts/gt/gt_data.gd` bersama tabel statistik tim lain. Stat itu mengatur akurasi prediksi cuaca dan kecepatan bereaksi. Garasi `NEUTRAL_PROFILE` tetap ada untuk saran Crew.
- Pit Crew: `PIT_STOP_TIME` menjadi rata-rata per tim (kira-kira 2.6 sampai 3.8 s) ditambah peluang error kecil (kira-kira +0.5 sampai +2 s). Konsistensi (varians) adalah stat kedua.
- Hanya data dan pemakaian di sim. Tidak ada UI upgrade dan tidak ada progres Career. Nilainya konstan per tim.
- Pekerjaan ini dikerjakan terakhir dan hanya setelah pekerjaan 2 berjalan, karena tanpa pit stop di balapan kering kedua stat tidak punya efek.

## 5a. Keputusan tambahan dari builder check (keputusan saya, bisa diubah)

1. **Aturan pit wajib.** Stop yang sudah selesai dengan jenis layanan apa pun (ban, fuel, atau keduanya) memenuhi syarat, ganti ban tidak diwajibkan. Stop dihitung bila selesai setelah 20% jarak balapan; stop sebelum itu tidak dihitung, kecuali stop karena puncture atau kerusakan. Stop harus selesai sebelum 80% jarak, jika tidak hukuman waktu dikenakan di bendera. Stop di bawah SC atau VSC dihitung. Mobil yang pensiun (DNF) tidak dikenai hukuman. Stop karena cuaca (hujan) dihitung, jadi di balapan hujan aturan ini hampir tidak terlihat dan perilaku hujan yang ada tidak berubah. Status dan hukuman memakai `penalty_owed_s`, dan rival mengikuti aturan yang sama (satu stop, di jendelanya).
2. **Cakupan sirkuit.** Kriteria penerimaan wajib lulus di Apex Ring. Sirkuit lain diperiksa dengan uji kewajaran di dua sirkuit: Paulistano (pit kiri) dan satu sirkuit panjang (Ardennes). Konstanta yang bergantung pada sirkuit dihitung saat berjalan dari panjang lintasan dan `pit_layout` (biaya pit, jendela dalam persen lap), bukan angka tetap per sirkuit. Kecepatan SC dan batas kejar dalam m/s boleh tetap global.
3. **Fuel.** Saran Crew = `laps x fuel_use x 1.08` ditambah kebutuhan rencana satu stop (marjin yang sama dengan isi ulang di pit sekarang). Rival memakai saran Crew sehingga tidak ada rival yang kehabisan fuel. Pemain boleh memilih lebih sedikit; garasi menampilkan verdict OK / WATCH / DANGER dengan gaya `GtForecast`, dan pilihan yang membuat rencana mustahil tetap diizinkan dan menjadi risiko pemain. Batas tangki tetap 110 kg (`gt_driving.gd:1253`) dan pilihan di-clamp ke batas itu. Kehabisan fuel memakai perilaku yang sudah ada (FLAMEOUT lalu DNF "Out of Fuel").
4. **AUTO dan rival memakai satu pengambil keputusan.** Perluas `GtStrategy` dengan satu fungsi pemilih mode. AUTO adalah arketipe netral dengan parameter tetap, rival adalah variasi parameter dari fungsi yang sama (hash per tim). Dengan begitu rival tidak bisa lebih pintar dari AUTO dalam logika, hanya berbeda dalam sikap, dan tes "tidak lebih pintar dari AUTO" cukup memeriksa bahwa keduanya memanggil fungsi yang sama.
5. **`risk_bias` dan `herd`.** Dilipat menjadi konstanta kepribadian per tim di `GtData` (tidak lagi acak per seed, tidak ditampilkan). Stat Engineer yang terlihat adalah satu peringkat per tim yang memetakan `forecast_trust`, `read_noise`, dan `reaction_sectors`. Builder memilih sebaran nilai untuk 13 tim (10 balapan per sesi) dan memeriksa ulang hasil balapan hujan setelahnya.
6. **VSC lalu SC.** Naik ke SC setelah jeda 8 sampai 15 detik berlaku tanpa syarat untuk tiga pemanggil SC (kecelakaan berat dan kerusakan terminal). VSC lama (debris ban, mobil berhenti) tidak berubah. Pit lane sudah terbuka di bawah bendera saat ini (saran "box under SC/VSC" ada di `_check_advisor_tactics`), builder memverifikasi lewat tes dan tidak mengubahnya. Tes VSC dan sinematik yang ada harus tetap lulus.

## 6. Diserahkan ke builder

- Angka tuning di dalam pita yang disebut di atas, asal kriteria penerimaan terpenuhi dan diukur dengan probe (`temp/probe_balance.gd`).
- Tata letak UI pemilih fuel di garasi dan penanda jendela pit wajib di HUD, mengikuti gaya StreetStyle yang sudah ada.
- Pemisahan commit per pekerjaan dan nama fase (`fase-*`), laporan di `executor-report/reports/FASE-*.md`, dan pembaruan `todo.md` sesuai AGENTS.md bagian 12.

## 7. Risiko dan hal yang belum diketahui

- Biaya pit stop belum terukur (lihat pekerjaan 2). Semua angka wear dan fuel bergantung padanya.
- Pengukuran hanya di Apex Ring, cuaca kering, seed 5, tanpa lalu lintas pada tabel kurs mode. Sirkuit lain punya panjang berbeda dan harus diperiksa ulang.
- Efek ERS pada peluang menyalip belum terukur.
- Rival yang memakai mode bisa menggeser keseimbangan yang kini bergantung pada kenyataan bahwa rival selalu STANDARD (misalnya urutan finis tes lama).
