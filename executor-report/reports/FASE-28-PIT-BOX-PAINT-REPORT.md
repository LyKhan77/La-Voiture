# FASE 28 — Cat kotak pit tim: Eifel Forest, Neo Wangan, Apex Ring

**Tanggal:** 2026-11-05
**Agen:** Claude Code (Sonnet 5.5) — Executor
**Branch:** `fase-28-pit-box-paint`
**Pemicu:** review developer menemukan kotak pit tim tidak terlihat di Kurogane (ronde 10) dan Paulistano (ronde 9), keduanya sudah diperbaiki dan di-merge ke `main` (`ecfe616`, `d8985f7`). Cek cepat semua sirkuit lalu menemukan tiga sirkuit lain yang mencurigakan; developer meminta ketiganya diperbaiki.

## 1. Cara pengukuran

Probe headless (`temp/all_paint.gd`, tidak di-commit) memuat setiap scene sirkuit, mendudukkan 10 tim, lalu untuk tiap box membandingkan puncak cat dengan permukaan datar tertinggi di bawah titik box (uji titik-dalam-segitiga pada semua mesh yang menghadap atas). Standar yang dipakai: cat berada 2 sampai 8 cm di atas permukaan di bawahnya (sirkuit lama: aspal pit +0,015 m, cat +0,025 sampai +0,037 m; sirkuit baru: apron diangkat 0,07 m, cat +0,035 m di atas frame yang diberikan).

## 2. Temuan per sirkuit

| Sirkuit | Temuan | Tindakan |
| :--- | :--- | :--- |
| Eifel Forest (R8) | Dua cacat. (a) Apron pit dibangun di tempat yang salah: `_build_pavement` dan `_outer_edge` memberi `get_pit_transform` sebuah stasiun lap (`bay_station`, s = 57 dst.), padahal fungsi itu menerima jarak sepanjang pit lane dari `ENTRY_S`; apron jatuh sekitar 200 m dari kotak, sehingga cat melayang kira-kira 20 cm di atas terrain kosong. (b) Setelah apron benar, cat masih terbenam karena frame kotak mengikuti kemiringan melintang jalan, sedangkan apron datar di tinggi garis tengah + 0,07 m (bug yang sama dengan Kurogane dan Paulistano). | Perbaikan keduanya di `eifel_forest_pit_complex.gd`: stasiun dikonversi dengan `u_from_s`, dan frame kotak diletakkan di permukaan apron. |
| Neo Wangan (R2) | Tidak ada kotak tim berwarna dan bernomor. Hanya ada `Marker3D` dan garis putih kosong 2,8 m x 6 m. Tidak sejalan dengan sirkuit lain, dan tim tidak bisa dikenali dari lantai pit. | Kotak standar `PitKit.paint_box` (pad warna tim, garis putih, bar kuning, nomor) dilukis setiap tim didudukkan (`PitBoxPaint`, `stall_markings` diisi). Garis putih lama per stall dihapus karena akan bertumpuk dengan kotak baru. |
| Apex Ring (R1) | Tidak ada cacat. Cat ada, 10 catatan `stall_markings`, puncak cat +0,022 m di atas `PitAsphalt` (dunia datar, y = 0). Probe pertama gagal menemukan node-nya karena pit Apex baru dibangun lewat `RaceWeekendWorld`. | Tidak ada perubahan kode. |
| Ardennes, Brianza, Monte Azure | Cat +0,022 m di atas aspal pit. Sesuai standar. | Tidak ada. |
| Pacific Corkscrew, Stoke Crown | Cat +0,037 m dan +0,029 m di atas permukaan. Sesuai standar. | Tidak ada. |

## 3. File yang diubah

- `scripts/world/circuits/eifel_forest/eifel_forest_pit_complex.gd`
- `scripts/world/circuits/neo_wangan/neo_wangan_pit_complex.gd`
- `tests/test_eifel_forest_circuit.gd` (cek baru: sepuluh kotak dicat di atas apron, 2 sampai 8 cm di atasnya)
- `tests/test_neo_wangan_circuit.gd` (cek baru `#W49`: sepuluh kotak bernomor di aspal, 1,5 sampai 8 cm di atasnya, dan sepuluh catatan `stall_markings`)
- Tangkapan layar: `executor-report/screenshots/phases/phase-28-pit-box-paint/{eifel-forest,neo-wangan}` (DAY, SUNSET, NIGHT; set `Boxes_Oblique`, `Boxes_Overhead`, `Boxes_Near`)

## 4. Verifikasi

- Tes baru Eifel diuji gagal dulu (10 dari 10 kotak di luar apron), lalu hijau setelah perbaikan.
- Tes baru Neo Wangan diuji gagal dulu (`stall_markings` tidak ada), lalu hijau (49 assertion, 0 gagal).
- `tools/run_tests.ps1 -Filter eifel`: 3 dari 3 suite lulus. `-Filter neo`: 4 dari 4 lulus.
- `tools/run_tests.ps1 -Filter pit`: lihat bagian 5.
- Tangkapan native 1080p menunjukkan kotak berwarna dan bernomor di atas apron pada Eifel dan Neo Wangan.

## 5. Hasil suite pit

`tools/run_tests.ps1 -Filter pit`: 30 dari 30 suite lulus, 0 gagal (763 detik), termasuk kontrak pit, penempatan tim, signage, dan pit flood semua sirkuit.

## 6. Catatan dan deviasi

1. Neo Wangan: garis putih kotak lama (2,8 m x 6 m, di +11,6 sampai +14,4 m) diganti kotak standar 3,3 m x 6,4 m. Ukuran pad sedikit lebih besar dari garis lama; pad tetap seluruhnya di atas aspal pit.
2. Tidak diubah: aturan offset cat 3,5 cm di `PitKit`. Praktik industri untuk marka lantai adalah decal terproyeksi atau depth bias, tetapi offset 2 sampai 3 cm cukup di jarak kamera game ini dan konsisten dengan seluruh sirkuit; mengubahnya menyentuh semua sirkuit.
3. Tidak di-commit: `temp/` (probe dan capture sementara), `todo.md` (di-ignore git).
