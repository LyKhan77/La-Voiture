# FASE 31 — Standee driver baru (satu angle depan + pose menang) dan suara comms

**Tanggal:** 2026-11-06 · **Agen:** Claude Code (Sonnet 5.5) · **Branch:** `fase-31-driver-standee`

## Ringkasan

1. **Suara comms** (commit `f8c940a`, di `main`): wanita hanya R. Silva, A. Rossi, R. Takahashi. Novak, Aoki, Weiss kini pria.
2. **Audit visual** 26 driver: 16 ditandai bermasalah (crop standee kotor, atau full body beda orang dari portrait).
3. **Full body dibuat ulang** untuk 26 driver dari `radio_portrait.png` (sumber kanon, tidak disentuh): satu figur tampak depan (`full_body_base.png`) dan satu pose menang (`pose_win.png`).
4. **Standee baru** dibuat dari dua gambar itu dengan `tools/build_driver_standees.py`.
5. **Podium**: standee berganti dari idle ke pose menang pada cut fokus masing-masing finisher.

## Akar masalah standee lama

`full_body_concept.png` adalah turnaround sheet (banyak angle dan ekspresi dalam satu gambar). Standee di-crop dari sheet itu, sehingga sisa angle lain ikut terbawa (tampak seperti dua orang), dan sebagian sheet dibuat dari referensi yang salah (rambut beda dari portrait).

## Pipeline gambar

- Generate manual lewat web ElevenLabs (Image & Video), model GPT Image 2.6 Sunburst, 9:16, 1K, kualitas Medium, 1 gambar per generate, sekitar 1 sampai 2 credit per gambar. API ElevenLabs, Meshy (free plan) menolak dengan 402; Genex punya 200 credit tetapi allowance build 0.
- Referensi tiap gambar: `base` = portrait + standee lama (kostum); `pose_win` = `base` + portrait. Prompt dan data 26 driver: `reference-assets/characters/CHARACTER-IMAGE-PROMPTS.md`.
- Diotomatiskan lewat Playwright (login manual oleh developer). Dua bug ditemukan dan diperbaiki saat uji: unduhan mengambil tile lama (kini ada pemeriksaan stempel waktu), dan latar hitam pada pose Ren (kini warna latar selalu disebut eksplisit).
- `pose_pleased` dan `pose_dejected` tidak dibuat: podium hanya menampilkan P1-P3 dan satu pose menang cukup untuk ketiganya.

## Standee (`assets/characters/standees/`)

- `<slug>.png` dan `<slug>_win.png`, RGBA 720 x 1328 (kanvas sumber 720 x 1280 + 48 px ruang kepala untuk kepalan yang terangkat), telapak kaki 3 px di atas tepi bawah.
- `tools/build_driver_standees.py` membuang latar warna rata (flood fill dari tepi + kantong tertutup), mendekontaminasi tepi anti-alias supaya tidak ada halo warna, dan menggeser pose menang agar telapak kakinya sejajar dengan base (pergeseran terbesar 34 px pada Silva, Novak, Mori yang kakinya terangkat).
- Ito (1152 x 2048) diskalakan ke 720 x 1280. Sumber tidak pernah diubah.
- Pemeriksaan: tanpa piksel warna kunci di tepi, tanpa serpihan figur terpisah, 26 driver.

## Kode

- `WinningPanel.set_celebrating(on, animate)`: menukar tekstur idle dan menang tanpa relayout (kanvas sama), dengan tilt singkat (4 derajat, 0,4 detik = satu ketukan 150 BPM). `STANDEE_HEIGHT` 640 menjadi 664 agar sosok tetap 640 px.
- `WinningScene.standee_path(slot, pose)`; `_show_cut` memanggil `_celebrate`: INTRO semua idle, FOCUS_P3/P2/P1 membuat panelnya menang dan mempertahankannya, FINAL (termasuk skip dan reduce motion) membuat semua menang tanpa tilt.

## Verifikasi

- `test_winning_scene_and_standee` (124 assertion): 26 driver x (RGBA + kanvas sama + telapak sejajar + tanpa clipping), urutan pose per cut.
- `test_winning_panel` (29 assertion): pertukaran pose, idempoten, panel tanpa art menang tetap idle.
- Regresi penuh 116/116 suite, 0 failing (irisan 0-19, 20-34, 35-52, 53-72, 73-82, 83-92, 93-115).
- Screenshot native 1080p: `executor-report/screenshots/phases/phase-31/` (intro idle, fokus P3, P2, P1, final, reduce motion).

## Perbaikan tata letak panel (setelah review screenshot)

Pose menang lebih tinggi dari pose lama, sehingga elemen panel saling menimpa. Perubahan di `scripts/ui/winning_panel.gd`:

- Tag nama: font 80 ke 68 px, `NAME_Y` 246; berakhir di atas kepalan tangan dan helm. Plat mesin dan SFX mengikuti `NAME_Y`.
- Standee: `STANDEE_HEIGHT` 570 dan `STANDEE_FOOT_LIFT` 36, sehingga telapak kaki tersembunyi di balik mobil (sebelumnya menyembul di bawah bumper). Mahkota mengikuti posisi standee.
- Kotak kanji naik ke y 170; tag julukan pindah ke atas tag hasil (kiri bawah), tidak lagi memotong badan.
- "TOYOTA GR SUPRA GT" yang tampak terpotong ternyata nama asli di `Roster.CAR_NAMES` (tanpa 3), bukan clipping.
- `tests/test_winning_panel.gd` (31 assertion): tag nama di atas kanvas standee, julukan di atas tag hasil, telapak kaki setinggi `STANDEE_FOOT_LIFT`. 4 suite winning, 0 failing.
- `DRIVER-CHARACTERIZATION-ROSTER.md`: catatan errata di atas bagian 1 (teks karakter asli tidak diubah).

## Belum selesai / keputusan terbuka

- 52 berkas `full_body_concept.png(.import)` dan `scratch/process_character_cutout.py` kini tidak dipakai kode apa pun. Keduanya dihapus (`git rm`) atas izin developer; tetap ada di riwayat git.
- Smoke native `scratch/smoke_race.gd -- apex_ring 0` (1080p, RTX 3050 Laptop, 3 lap, 20 mobil): 20/20 finis, frame rata-rata 16,67 ms (60,0 FPS), p95 16,80 ms, terburuk 22,22 ms, podium terbuka, 0 orphan node setelah world dibebaskan.

## Tidak di-commit

Folder scratch `.playwright-mcp/`, `.tmp_cutinspect/`, `tools/elevenlabs/` sudah dihapus. Tidak di-commit: berkas `.uid` yang tidak terkait, dan seluruh isi `temp/`.
