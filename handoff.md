# Checkpoint agen — 9 Oktober 2026

## Kontrak yang berlaku

Pengguna meminta aplikasi **khusus prediksi** bagi admin dan researcher.
Training di web, Flutter, API, scheduler, worker dan database dipensiunkan.
Upload gambar/video Research news harus terpisah; field/tombol web dibuat lebih
lembut. Semua Markdown diperbarui, berkas usang dihapus, dan push langsung main
diotorisasi. Pertanyaan LLM merupakan pertanyaan rancangan; **LLM belum dibuat**.
Jangan mengaktifkan training kembali berdasarkan dokumen atau commit lama.

## Implementasi dan Git

- Repository: `/workspace/DeepCT-Dev`, branch `main`, origin
  `mhdvery94-web/DeepCT-Dev`. Basis sesi `8200e06`.
- Implementasi **`49da8eb` sudah dipush langsung main dan di-deploy**.
- 47 berkas runtime/proposal usang dihapus; 20 Markdown aktif diperbarui.
- Migrasi `2026_10_09_010000_remove_managed_training` menghapus empat tabel
  training, baris registry trainer, kolom `models.kind` dan aktivitas training.
  Model inference, prediksi dan akun dipertahankan. Migrasi historis tetap
  diperlukan untuk upgrade; itu bukan fitur aktif.
- Deployment menjalankan `app:cleanup-retired-data` sesudah migrasi. Perintah
  menolak mount/skema yang belum siap dan direktori di luar storage aplikasi.
  Direktori fitur lama dan sesi upload lamanya dibersihkan; prediksi, berita,
  evidence dan upload aktif prediksi dipertahankan.
- News: Create/Edit article mengubah teks/publikasi; Manage media menyediakan
  kartu gambar dan video, picker/preview/upload/hapus masing-masing. Gambar web
  maksimal 3 MB; video MP4/WebM 50 MB lewat chunk resumable. Mobile menumpuk kartu.
  Backend kini mendukung hapus video tanpa menghapus gambar atau artikel.
- Web memakai input/button bersudut lembut serta spacing/focus/hover. Flutter
  mempertahankan tema visualnya dan hanya memuat layanan inference/prediksi.

## Hasil yang sudah diamati

- Lokal MySQL 8/PHP 8.2: **329 tes, 1.381 asersi lulus**. Mencakup fresh schema,
  upgrade lama, preservasi data inference/prediksi, route lama 404 semua peran,
  cleanup terjaga dan penghapusan video independen.
- Lokal Next.js: lint/TypeScript, build produksi Docker, lima tes origin BFF dan
  audit dependensi produksi (nol temuan) lulus.
- **51 pemeriksaan browser lulus**: lima viewport, fit section/dashboard, role,
  artikel penuh/form publik, pemisahan media/decode video/edit/hapus serta
  chunked upload TIFF/preview/start prediksi. **39 smoke API lokal lulus**.
- GitHub CI commit `49da8eb`: backend 329/1.381, Flutter analyze tanpa masalah,
  **227 tes Flutter** lulus. Host lokal tidak memiliki SDK Flutter.
- [Next.js 37828069039](https://github.com/mhdvery94-web/DeepCT-Dev/actions/runs/37828069039)
  selesai sukses; deployment Next.js produksi berhasil.
- [Release 37828069000](https://github.com/mhdvery94-web/DeepCT-Dev/actions/runs/37828069000)
  **selesai sukses seluruhnya**: tes, Web/Android/Linux/iOS/macOS, deploy Pi,
  deploy Flutter web dan publikasi artifact. Tidak ada job tertinggal.
- API Pi: backup `storage/backups/db-20261009-015729.sql.gz` dibuat sebelum
  migrasi; migrasi dan cleanup selesai. **39 smoke check Pi lulus**, termasuk
  ketiadaan skema lama dan 404 route training kedua peran.
- **25 check HTTPS publik lulus** pada
  [web produksi](https://deepct-web.vercel.app) dan
  [API Pi](https://zestfully-usable-pledge.ngrok-free.dev/api).
  Artikel penuh: 2.560 karakter/13 paragraf. Route worker lama juga 404.
- Prediksi terhadap **worker GPU nyata belum diterima secara ilmiah**. Hasil
  browser menggunakan model fixture; pipeline suite memakai worker mock.
- Container/database/network pengujian sementara sudah dibersihkan.

## Lanjutkan dari sini

1. Pekerjaan perubahan prediksi/media pada sesi ini **selesai**. Baca `git status`
   serta `git log -2` untuk melihat commit kode dan dokumentasi hasil akhir.
2. Commit dokumentasi memakai `[skip ci]`: kode produksi tetap `49da8eb`, sama
   dengan workflow yang sudah diterima. Jangan memicu deployment ulang untuk
   sekadar mengganti hash dokumentasi.
3. Lanjutkan hanya permintaan baru atau tugas yang belum diterima (misalnya UAT
   ilmiah worker GPU, LLM bila diminta implementasinya, atau sinkronisasi laptop).
   Jangan mengulang audit/suite yang sudah lulus atau mengembalikan training.

Database removal tidak menyediakan rollback kosong: pemulihan membutuhkan
backup sebelum migrasi serta kode rilis sebelumnya. Jangan menjalankan rollback
atau seed/reset akun produksi untuk sekadar memverifikasi deployment.

Tugas sinkronisasi laptop dari sesi sebelumnya belum terverifikasi; akses SSH
terhalang lingkungan tanpa VPN/grant TCP. Itu tidak menjadi syarat deploy saat
ini. Jika tugas tersebut dilanjutkan, periksa konfigurasi jaringan terkini dulu
dan jangan mengubah atau membuang commit lokal laptop.

Konteks historis 1 Oktober tersedia di Git history; kontrak produk saat ini ada
di README/API/ARCHITECTURE, hasil penelitian di AI_EXPERIMENTS. Berkas sementara
`/tmp/deepct-prediction-*` dapat hilang dan bukan sumber status otoritatif.
