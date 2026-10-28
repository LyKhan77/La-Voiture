# Fase 13.2 — Brianza pitstop dan clearance

- Branch: `fase-13-2-brianza-pitstop-and-clearance-polish`.
- Layout simulasi, antarmuka choreographer, pemetaan stall berdasarkan urutan tim aktif dan kru standby ditambahkan. Garage kini terbuka di sisi pit lane.
- MainGrandstand dipindah ke s=160 m; Rettifilo diberi setback 6 m.
- `test_brianza_circuit.gd`: 118 asersi lulus. Sampel s tiap 2 m dan lateral tiap 1 m memeriksa segitiga struktur tribun/pit wall pada tinggi 0,05–3 m dan jejak konservatif crowd. Kontrol posisi tribun lama terdeteksi. Ini sampling, bukan bukti geometri kontinu.
- Smoke native 20 mobil, 3 lap, tim 4: permintaan pit, masuk, box, servis kru dimulai dan selesai, keluar serta balapan selesai teramati.
- Smoke performa native tanpa tes regresi yang berjalan bersamaan: 20 mobil selesai, podium terbuka, 0 orphan; 259 frame, rata-rata 16,66 ms (60,0 FPS), p95 21,38 ms, terburuk 23,64 ms. Syarat tidak turun di bawah 60 FPS belum terpenuhi. Sampel draw call environment 155–169; primitif terlihat 1.359.948–1.384.654.
- Bukti 1080p: `executor-report/screenshots/phases/phase-13-2-*`, termasuk sudut khusus `clearance-rettifilo`, `clearance-back-straight`, dan `clearance-pit-garages`. Skrip lama disalin dengan nama output baru untuk melindungi tangkapan lama.
- Godot melaporkan kegagalan akses `user://logs` dan certificate store dalam sandbox.
- Semua 52 `tests/test_*.gd` lulus. Lima tes melewati timeout awal 90 detik dan lulus saat dijalankan ulang; dua suite dijalankan dengan `--skip-legacy`, karena suite legacy dijalankan terpisah. `test_race_world.gd` menggunakan `--fixed-fps 60` sesuai instruksi tesnya.
- Gate 60 FPS terkunci belum lulus; kembali dari podium ke menu utama belum diverifikasi. Pekerjaan tidak boleh dinyatakan selesai berdasarkan Definition of Done proyek.
