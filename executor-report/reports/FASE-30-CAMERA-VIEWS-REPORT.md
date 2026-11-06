# FASE 30 — Kamera Hood, Side, Front-to-Rear

**Tanggal:** 2026-11-06 · **Branch:** `fase-30-camera-views` · **Agen:** Claude Code (Sonnet 5.5)

## Permintaan developer
- Cockpit Cam menjadi kamera depan dari hood, disesuaikan per mobil, tidak boleh menembus bodi (aset mobil tidak punya kokpit).
- Side Cam dari samping/fender. Keputusan Q&A: sisi dalam tikungan, berganti otomatis.
- Front-to-Rear Cam. Keputusan Q&A: kamera di depan hidung, menghadap mundur ke mobil.

## Hasil
| Mode | Perilaku |
| :--- | :--- |
| `HOOD` (ex `COCKPIT`) | Di garis tengah hood, 12 cm di atas titik bodi tertinggi di depan mata, miring 7° ke bawah supaya hood tampil di bawah frame. Posisi diukur per mobil dari vertex `base_body_mesh` (`CarCameraRig`), jadi hidung panjang atau hood tinggi tidak menembus bodi. |
| `SIDE` (baru) | 2,6 m di luar lebar bodi, sejajar as depan, setinggi 0,7 m, menyorot bodi. Sisi = bagian dalam tikungan, dari rata-rata kelengkungan lintasan 10-55 m di depan mobil; pergantian butuh tikungan jelas (radius < 400 m) yang bertahan 1,0 s (tikungan S tidak membuat kamera bolak-balik). Pergantian berputar mengitari hidung, tidak pernah melewati mobil. |
| `FRONT_TO_REAR` (baru) | 4,2 m di depan hidung, setinggi 0,9 m, menghadap mundur. Posisi menempel pada mobil; hanya arah (heading) yang di-ease, sehingga lensa sedikit mengayun di tikungan. |

- Urutan `C`: Chase, Hood, Side, Front-to-Rear, Heli, Trackside TV (Safety Car menyusul setelah Trackside TV bila aktif).
- Nilai enum lama tidak digeser (`SIDE = 6`, `FRONT_TO_REAR = 7` ditambahkan di belakang): tes lain memakai angka literal.
- Pengukuran pertama per mesh 12 ms (RTX 3050 Laptop, headless), selanjutnya cache.

## Verifikasi
- `tests/test_camera_views.gd`: 72 assertion. 13 mobil: eye hood di garis tengah, >= 10 cm di atas bodi di depannya, di antara as depan dan hidung (dihitung ulang dari vertex di tes); hood menghadap ke depan; front-to-rear di depan hidung dan menghadap mundur; side di luar kotak bodi. Lintasan melingkar dua arah: sisi dalam benar; S-bend menahan sisi 0,5 s lalu berganti setelah 1,0 s; orbit pergantian tidak menembus bodi (240 frame).
- `test_race_weekend_and_physics` #26 dan `test_safety_car_cinematic` disesuaikan ke 6 mode siklus.
- Regresi penuh `tools/run_tests.ps1`: **116/116 suite, 0 failing** (irisan 0-19, 20-34, 35-52, 53-72, 73-92, 93-115).
- Capture native (RTX 3050, 1280x720, apex_ring): `executor-report/screenshots/phases/phase-30-camera-views/` (`5_hood` GT-R, `6_hood` Mercedes, `6_side`, `5_f2r`).

## Belum / catatan
- Smoke native 3 lap 20 mobil dan pengukuran 60 FPS belum dijalankan untuk fase ini (hanya capture visual); perubahan hanya menyentuh kamera dan titik pusat speedlines, bukan sim.
- Hood cam memakai arah heading mobil, bukan roll/pitch sasis, supaya getar tergelincir tidak mengguncang layar; posisi mata tetap mengikuti sasis.
- Hood hanya dicek visual pada dua mobil; 11 mobil lain dicek oleh gerbang geometri, bukan mata.
- Tidak di-commit: `.uid` dari `godot --import` untuk file Kurogane/tes lama (bukan bagian tugas ini).

## Perbaikan lanjutan: speedlines "menempel" di layar (ERS overtake / kecepatan tinggi)
- Akar masalah: `RaceHud._update_speedlines` hanya memperbarui `center` bila titik mobil ada di depan lensa. Di Hood Cam origin mobil berada di belakang lensa, jadi `center` tidak pernah diperbarui dan sinar tetap di titik kamera sebelumnya (juga terjadi di Trackside TV setelah mobil melewati kamera).
- Perbaikan: bila mobil di belakang lensa, sinar memancar dari titik 60 m di depan arah mobil; bila titik itu pun di belakang, dari tengah layar. Mode lain tidak berubah.
- Tes merah dulu: `_test_speedlines_follow_when_the_car_is_behind_the_lens` gagal (pusat tetap `(0.5, 0.57)` dari Chase Cam), hijau setelah perbaikan. `test_visual_polish_and_consistency`, `test_race_hud`, `test_camera_views` lulus. Cek native (ERS OVERTAKE, Hood Cam): sinar memancar dari titik heading `(0.5, 0.43)`, bukan titik Chase Cam `(0.5, 0.57)`; bukti `screenshots/phases/phase-30-camera-views/ers_hood_speedlines.png`. Regresi penuh setelah perbaikan: **116/116 suite, 0 failing**.
- VFX ERS lain (semburan api sayap, asap) menempel pada aktor 3D, bukan layar; hanya speedlines dan FOV punch yang berada di ruang layar.
