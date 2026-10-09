# Checkpoint proyek — 9 Oktober 2026

## Keadaan aplikasi

Training sudah dipensiunkan di frontend, API, database dan storage legacy.
Migrasi historis tetap tersedia untuk upgrade. News memiliki editor teks dan
kartu upload/hapus gambar serta video yang terpisah. Root hanya README.md;
enam dokumen aplikasi berada di docs. Folder stitch/proposal/models-ai/Images/
.kilo dan Markdown agent sudah dibersihkan. Jangan mengulang pekerjaan ini.

Baseline sebelum debug Next.js: main 9f520ea. Produksi sebelumnya 923bc86,
Next workflow 37833767080 dan Release 37833766927 sukses. Baseline Flutter
227 tes/analyze, Pi smoke 39, dan HTTPS publik sudah diterima.

## Debug Next.js terbaru

- Researcher mengunggah satu ZIP atau banyak TIFF bernomor. TIFF dirakit menjadi
  ZIP STORE tanpa mengubah data; identitas arsip stabil untuk resumable upload.
- Upload selesai membuka input preview otomatis. Start tetap eksplisit.
  Pending/processing dipoll setiap 3 detik; progress, queue position, preview
  hasil, slider/playback, download dan evidence tersedia. Tombol compare dihapus.
- Preview API menerima kind=input/output dan memakai cache terpisah untuk nama
  yang sama. Detail API menyertakan file_name. Kontrak lama tetap kompatibel.
- Admin Next.js tidak memiliki tab prediksi; URL langsung menuju queue monitor.
  Model management memakai registrasi manual tanpa UI impor katalog. API katalog
  lama tetap tersedia bagi klien lain.
- Disk cleanup menjelaskan scope, dataset/pemilik dan file yang dipertahankan;
  checkbox wajib sebelum penghapusan. Proteksi backend job aktif/mount/path tetap
  berlaku. Grid portal diperbaiki agar preview/form tidak melebar pada mobile.
- Request access memiliki contoh placeholder dan telepon wajib di Next.js;
  API menerima phone nullable demi Flutter lama, approval menyalinnya ke akun.
- Reset memakai email+telepon saja. Cocok pada akun aktif yang sama -> permintaan
  inbox admin; salah/tidak aktif/tanpa telepon -> User not found. Phone format
  08.../+628... dinormalisasi. Password/sesi tidak berubah dari request publik;
  admin memverifikasi pemilik sebelum reset. Tidak ada OTP/email provider baru.
- Migration tambahan: 2026_10_09_040000_add_phone_to_access_requests.

## Verifikasi sesi ini

Backend MySQL terisolasi: **338 tes / 1.427 asersi lulus**. Next.js lint,
TypeScript, **11 tes di Node 22**, production build dan production dependency
npm audit lulus (0 kerentanan). Browser Chromium dengan Laravel/MySQL terisolasi:
**15 skenario lulus**, termasuk TIFF/ZIP, automatic previews, explicit Start,
queue/status polling, kedua role, matching reset dan konfirmasi storage.
Ukuran portal diperiksa pada 1366/768/390/360 px termasuk overflow internal main.

Upload, preview, antrean, auth dan forms memakai API nyata di database test.
Perubahan processing/completed dan frame hasil memakai fixture; worker GPU tidak
menjalankan inferensi dalam browser test. **UAT ilmiah GPU nyata belum diterima**.
Flutter tidak diubah pada sesi ini. Tidak ada LLM/chatbox yang diimplementasikan.

## Publikasi dan pekerjaan terbuka

Implementasi **845912a sudah dipush main**. **Next 37876789863 sukses**, termasuk
verifikasi dan deployment Vercel. **Release 37876789839 sukses seluruhnya**:
backend, Flutter tests, Web/Linux/Android/iOS/macOS, deployment Pi/Vercel dan
publikasi artifact. Tidak ada pekerjaan deployment sesi ini yang tertunda.

Pi membuat backup `storage/backups/db-20261009-095559.sql.gz`, menerapkan
`2026_10_09_040000_add_phone_to_access_requests`, restart, dan **39 smoke check
API lulus**. HTTPS produksi mengonfirmasi form request access baru, reset hanya
email/telepon, link login dan validasi reset 422 melalui BFF Vercel ke Pi.
Akun lama tanpa telepon perlu dilengkapi administrator. Commit checkpoint
dengan [skip ci] tidak mengubah kode produksi 845912a.

Laptop Vivobook tidak disentuh; pengguna memilih git pull manual. Checkout
/workspace/DeepCT-Dev adalah workspace Codex, bukan bukti sinkronisasi laptop.
Lanjutkan pemeriksaan rilis terbaru atau UAT GPU, jangan mulai migrasi/pembersihan
repo dari awal lagi.
