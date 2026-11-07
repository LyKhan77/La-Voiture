# Fase 32: keseimbangan Tactical Deck, Safety Car, pit wajib, dan fondasi stat tim

Tanggal: 2026-11-07. Agen: Claude Code (Sonnet 5.5), peran Executor (native). Branch: `fase-32-tactical-balance`.
Spec: `docs/superpowers/specs/2026-11-07-tactical-deck-balance-design.md`. Rencana: `docs/superpowers/plans/2026-11-07-tactical-deck-balance.md`.
Probe pengukur (tidak di-commit): `temp/probe_balance.gd`, model `temp/model2.py`.

## Masalah dan hasil

Deck terasa flat karena STANDARD selalu menang: balapan kering 0 pit stop, fuel awal `fuel_use x laps x 1.05`, rival tidak pernah mengganti mode, PUSH dan ERS tidak punya nilai di waktu lap, ATTACK lebih lambat 8 s, dan Safety Car butuh sampai 434 s untuk menjemput leader.

| Ukuran (Apex Ring, kering) | Sebelum | Sesudah |
|---|---|---|
| SC menjemput leader, leader 5% lap lewat titik muncul | 434.3 s | 143.1 s |
| idem, leader 50% | 230.1 s | 89.0 s |
| idem, leader 95% | 22.0 s | 21.9 s |
| idem, Paulistano (4313 m) / Ardennes (5400 m), 5% | belum diukur | 154.8 s / 166.5 s |
| Fuel PUSH, selisih waktu lap vs STANDARD | -0.05 s | -0.8 s |
| ERS DEPLOY, selisih waktu lap | 0.00 s | -0.45 s |
| Pace AGGRESSIVE | -0.95 s | -0.8 s |
| Pace ATTACK | +8.0 s (ban pecah dalam 3 lap) | -2.4 s (wear 0.39 per 2 lap, tanpa pecah) |
| Pit stop di balapan kering 15 lap, 20 mobil | 0 | 20 dari 20 mobil tepat satu stop, tersebar di 3 lap berbeda |
| Selisih rencana satu stop terbaik ke terburuk (5 rencana), Apex 10 / 15 lap | 18.3 s / 42.8 s | 1.3 s / 3.7 s |
| idem, Paulistano 10 / 15 lap | | 1.4 s / 4.1 s |
| idem, Ardennes 10 / 15 lap | | 1.6 s / 4.6 s |
| Tanpa pit di 10 / 15 lap, tertinggal dari rencana terbaik (Apex) | tidak ada pit wajib | 27.7 s / 57.9 s (penalti 30 s) |
| Peringatan "Fuel critical" | berbunyi di 15 dari 20 mobil setiap balapan | hanya bila proyeksi ke finis negatif |

Biaya pit stop terukur di Apex Ring: 19.3 s (5 lap), 17.1 s (10 lap), 4.7 s (15 lap, ban baru menutup sebagian).

## Yang dibangun

1. **SC lebih cepat menjemput** (`gt_race.gd`, `gt_driving.gd`): SC yang belum menjemput leader menunggu pelan (12 m/s) saat leader jauh dan 18 m/s saat dekat; semua mobil boleh mengejar sampai 55 m/s sambil jarak ke SC menyusut (batas mengikuti jarak leader supaya rombongan tidak terulur), lalu rombongan boleh merapat sampai 55 m/s setelah pickup. `GtRace.sc_catchup_cap`.
2. **VSC sebelum SC**: `GtRace.raise_sc` memulai VSC 8-15 detik (aliran hash sendiri) lalu SC; kecelakaan kedua tidak memunculkan SC kedua; pit lane tetap terbuka.
3. **Fuel**: `GtFuelPlan` (Crew Pick, clamp, target isi ulang), waktu isi ulang 0.10 s/kg di stop, bobot fuel 0.0003 per kg, peringatan berdasar proyeksi (`GtForecast.fuel_alarm`), pilihan fuel per mobil di garasi dengan verdict dan bintang Crew Pick.
4. **Pit wajib** (balapan 10 dan 15 lap): satu stop yang garis Pit Entry-nya dilewati di 20-80% jarak (stop paksa karena puncture, kerusakan, atau pergantian yang melibatkan ban hujan boleh lebih awal), hukuman `max(30 s, 1.5 x kerugian pit kru terlambat)` di bendera, DNF dan balapan 3/5 lap bebas. Jendela dibaca di garis Pit Entry (bukan posisi box), sehingga label deck memuat tepat lap yang terhitung (Apex: lap 3-8 di 10 lap, lap 4-12 di 15 lap) dan dipakai juga oleh pengingat dan panggilan AI. Peringatan engineer dua lap sebelum jendela tutup dan "Fuel is short. Box this lap for fuel." bila bahan bakar tidak cukup sampai stop yang masih terutang (tiga klip Kokoro baru).
5. **Ekonomi mode**: PUSH +0.7% pace, ERS DEPLOY +1.4% dan OVERTAKE +2.2% selama menyala, ATTACK dorongan singkat, tabel `ERS_REGEN_BRAKE_PER_S`.
6. **Keseimbangan ban**: grip slick 1.0/0.995/0.99, wear per lap 0.060/0.045/0.020 (inter/wet tidak diubah), AGGRESSIVE 1.031.
7. **Pemilih mode bersama** (`GtStrategy.choose_modes`): rival dan AUTO memakai fungsi yang sama; profil rival dari hash per tim (`tactic_profile`), AUTO memakai `NEUTRAL_TACTIC`.
8. **Rival**: stop wajib terencana (25-45% jarak, dibatasi fuel), cover stop mobil di belakang, pit saat SC/VSC (70% untuk yang stop-nya belum diambil, selalu untuk wear > 0.45).
9. **Stat tim** (`GtTeamStats`): peringkat Engineer, kecepatan dan konsistensi pit crew, konstanta kepribadian strategis; `GtStrategy.profile` kini tetap per tim (tidak lagi acak per seed); waktu stop per tim dengan kemungkinan error.

Nilai stat tim (urutan `GtData.TEAM_NAMES`): Engineer 0.55 0.40 0.70 0.50 0.45 0.80 0.30 0.60 0.75 0.35 0.90 0.25 0.65; kecepatan kru 0.60 0.50 0.45 0.70 0.85 0.35 0.65 0.55 0.40 0.80 0.15 0.75 0.95; konsistensi kru 0.55 0.60 0.70 0.45 0.50 0.65 0.40 0.85 0.75 0.55 0.60 0.35 0.80.

## Review akhir

Reviewer segar (model terkuat) memberi **With fixes**, tanpa temuan Critical. Tujuh temuan Important diperbaiki dalam satu putaran dengan test RED lalu GREEN (detail di ledger): label jendela yang melebih-lebihkan lap terakhir yang terhitung (jendela kini dibaca di garis Pit Entry), panggilan stop setelah jendela tutup, saran "CONSERVE" yang keliru untuk mobil yang masih punya stop (diganti panggilan "box untuk fuel" lebih awal), pengaman ATTACK memakai forecast tanpa panas (faktor 1.5), test pit-saat-SC yang tidak menguji caution (ditulis ulang: unit dan jendela 40 s), tidak ada pengecekan rival kehabisan fuel di 15 lap, dan stop antar-ban hujan sebelum 20% yang tidak terhitung. Sembilan temuan Minor ditunda (daftar di ledger dan di bawah).

## Verifikasi

- Suite baru: `test_sc_catchup`, `test_vsc_escalation`, `test_fuel_plan`, `test_garage_fuel_choice`, `test_mandatory_stop`, `test_mode_economy`, `test_one_stop_balance`, `test_rival_tactics`, `test_rival_stops`, `test_team_stats`, `test_pit_crew_stats`.
- Suite lama yang diubah (pin angka lama atau skenario yang bergantung urutan tick; alasan di ledger): `test_gt_sim` (SC ditandai sudah menjemput di dua skenario caution, jeda 5 tick untuk DRS, batas side-by-side 8 s), `test_deck_n2` (baris ATTACK, mobil uji 3,2%/lap), `test_pit_stop_in_world` (Monte Azure tanpa ekspektasi hold, taktik rival dan waktu kru dimatikan), `test_track_incidents_and_stewards` (taktik rival dimatikan di skenario satu mobil), `test_fuel_plan`.
- Regresi penuh **127/127 suite, 0 gagal**, dijalankan dua kali (sebelum dan sesudah putaran perbaikan review) di latar depan dalam irisan (0-9, 11-30, 31-53, 54-79, 80-86, 87-100, 101-105, 106-118, 119-126, dan suite meta indeks 10 sendiri, 462 s karena menjalankan belasan suite lain). Suite flood pit (10 suite) lulus pada kode akhir.
- Smoke native `temp/smoke_fase32.gd` (1080p, RTX 3050 Laptop): balapan 10 lap 20 mobil Apex Ring, rata-rata 16,67 ms (60,0 FPS), p95 16,89 ms, terburuk 22,28 ms; podium terbuka; 0 orphan node. Balapan dengan kecelakaan paksa di 30%: VSC di detik 236, SC di detik 250, hijau di detik 639; 18 stop, 18 terhitung, 0 penalti wajib. Dua mobil tidak finis: mobil pemain sendiri (tim 0, MANUAL, tidak pernah pit) kehabisan fuel di lap 5 dengan Crew Pick ringan (lihat bagian keputusan terbuka).
- Screenshot: `executor-report/screenshots/phases/phase-32/` (garasi dengan baris fuel, deck dengan label jendela stop, jendela VSC, SC keluar).

## Keputusan yang saya ambil (ringkas; daftar lengkap bagian `Ruling:` di ledger)

- SC unpicked tetap 18 m/s (rencana 22): 22 m/s memperlambat kasus dekat dari 22 s ke 39 s. Cap kejar 55 m/s (spec 45-55), bukan 70.
- Stop wajib dihitung bila selesai antara 20% dan 80%; rencana stop rival 25-45% (rencana 30-55%) karena Crew Pick ringan hanya cukup sampai ±54%; failsafe 66% (rencana 72%).
- Konstanta ban/fuel/isi ulang dicari dengan model terkalibrasi lalu diverifikasi di sim; rencana "late" adalah HARD>SOFT @65, bukan SOFT>MEDIUM @70 (stop di 70% dari 10 lap selesai setelah 80% dan tidak terhitung).
- Saklar uji: `GtRace.rival_tactics_enabled`, `GtRace.crew_times_enabled` (default menyala).
- Peringatan fuel untuk mobil yang masih punya stop di depan berbunyi di bawah 2.5 lap bahan bakar.

## Keputusan terbuka untuk developer

- **Crew Pick ringan + lupa pit = DNF.** Di balapan 10 dan 15 lap Crew Pick hanya setengah jarak, jadi pemain MANUAL yang mengabaikan semua peringatan kehabisan fuel sekitar lap 5 (terlihat di smoke, sebelum peringatan fuel-pendek ditambahkan). Itu sesuai spec (kehabisan fuel tetap DNF dan tangki dipilih pemain). Mitigasi yang dibangun: label deck, saran Engineer, pengingat jendela, dan panggilan "Fuel is short. Box this lap for fuel." di bawah 2.5 lap bahan bakar. Alternatif yang saya coba: Crew Pick yang menjangkau penutupan jendela plus satu lap (reviewer condong ke sini). Ditolak sementara: stop menjadi pendek dan mobil dilepas berkelompok, sehingga `test_kurogane_pit_flood` naik dari 4,6 s ke 11,5 s menunggu di box (batas 7 s). Keputusan tetap di developer: Crew Pick penuh (aman, tetapi perlu menyetel ulang batas flood Kurogane), atau penalti alih-alih DNF.
- Mobil yang tidak pit di 10/15 lap dengan tangki penuh kalah 27-69 s; angka penalti 30 s mengikuti 1.5x kerugian pit terukur dan perlu dicek ulang bila waktu pit berubah.
- Deck belum menampilkan wear ATTACK yang sebenarnya (tabel 3.0 vs sekitar 6x terukur karena pengganda panas tidak dimodelkan `GtForecast`).

## Temuan Minor yang ditunda

Cover stop ikut menyapu rekan setim dan mobil lapped (batasi ke mobil tepat di belakang); waktu isi ulang dihitung untuk satu lap bahan bakar lebih banyak dari yang ditambahkan (sama untuk semua tim); kerusakan sekecil apa pun membuat stop "forced"; AUTO lebih lambat dari rival (cooldown 25 s, tanpa aturan cover); penalti wajib tanpa radio atau banner dan label deck tetap abu-abu setelah jendela tutup; determinisme hanya diuji dengan insiden mati; `_test_rule_shape` tidak membuang race yang dibuatnya; smoke native memakai 10 lap (bukan 15), pemain tidak pit, dan tanpa screenshot podium.

## Tidak di-commit sengaja

`.uid` berkas yang tidak terkait tugas ini (scratch/, kurogane, beberapa tes lama), `temp/` (probe, model, keluaran), `.superpowers/` (ledger). `todo.md` ada di `.gitignore`.
