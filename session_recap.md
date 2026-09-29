# Ringkasan sesi — 28 September 2026

## Permintaan dan keputusan

- Proyek ditinjau dari sisi frontend, backend, dan kesesuaian dengan dokumen `.md`, lalu temuan utama ditindaklanjuti dengan perubahan kode dan dokumentasi.
- Pemisahan proses rilis/deploy GitHub dari proses lokal adalah keputusan yang disengaja. Versi yang akan dideploy berasal dari kode yang sudah siap dipush; proses lokal dijalankan manual melalui CMD. Workflow CI/deploy tidak diubah.

## Perbaikan yang dibuat

- Backend: middleware `account.access` memeriksa akun aktif dan kewajiban mengganti password pada setiap request terautentikasi. Menonaktifkan akun atau mereset password mencabut seluruh tokennya. Token admin untuk melihat media berita draf juga tunduk pada status akun.
- Backend: penghapusan akun ditolak saat prediksi atau training masih aktif. Penghapusan yang berhasil membersihkan file prediksi, bukti hasil, unggahan/unduhan sementara, token, notifikasi, dan avatar yang terkait.
- Backend: `PredictionIntake` memeriksa isi ZIP sebelum ekstraksi: maksimum 50 MB per frame, 1000 frame input, 2 GB total TIFF setelah ekstraksi, nama frame unik setelah folder diratakan, serta ruang disk yang cukup. Ekstraksi dibaca per stream dan ukuran aktual diperiksa. Unggahan training langsung juga memakai `StorageGuard`.
- Frontend: ZIP prediksi pada platform native dibaca per rentang untuk hashing, unggah, dan resume. Unduhan hasil diterima sebagai stream, MD5 wajib cocok sebelum hasil dipublikasikan; native memakai file `.part`, sedangkan web menahan potongan sampai Blob dapat dibuat. Header checksum diekspos lewat CORS.
- Dokumentasi utama (`README.md`, `ARCHITECTURE.md`, `API.md`, `be/README.md`, `fe/README.md`, `PRD.md`, `CHANGELOG.md`) diselaraskan dengan alur upload → preview → START → antrean, aturan akun, batas ZIP, unduhan, jumlah route, dan batasan platform. Server mendukung HTTP Range, tetapi klien Flutter saat ini mengulang unduhan dari awal bila terputus. Browser dan bundel TIFF lepas masih menahan byte sumber di memori. Build iOS di CI masih unsigned.

## Verifikasi yang sudah dilakukan

- Lint PHP pada file PHP yang diubah: tidak ada kesalahan sintaks.
- Uji unit backend: **21 lulus, 60 assertions**.
- Analisis statis enam file Dart yang diubah: **tidak ada issue**; file telah diformat.
- `php artisan route:list --path=api --json`: **104 route**, termasuk `/api/health`; middleware `account.access` terlihat pada route akun, sedangkan route worker tetap memakai autentikasi worker.
- `git diff --check`: bersih.

## Batas verifikasi dan keadaan workspace

- Uji fitur backend belum dapat dijalankan karena MySQL lokal di `127.0.0.1:3306` tidak tersedia. Uji Flutter untuk resume unggahan berhenti karena timeout. Alur penuh terhadap worker GPU belum diuji ulang setelah perubahan ini.
- Belum ada commit, push, atau deploy dalam sesi ini.
- Perubahan yang sudah ada pada folder `proposal/` dan `AGENTS.md` tidak diubah selama perbaikan ini. File ini dibuat atas permintaan pengguna sebagai satu-satunya perubahan pada giliran penyimpanan ringkasan.
