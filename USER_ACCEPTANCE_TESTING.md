# Skenario dan Hasil User Acceptance Testing

> Kontrak aplikasi diperbarui 9 Oktober 2026: khusus prediksi; managed training telah dihapus.
> Status dan langkah kelanjutan agen: [checkpoint](handoff.md).

## Pemeriksaan perubahan — 9 Oktober 2026

Pemeriksaan browser lokal menggunakan build produksi Next.js, Laravel berjalan
dan MySQL pengujian terisolasi. Skenario mencakup navigasi tanpa training, 404
halaman/endpoint yang dipensiunkan, editor artikel tanpa input media, upload
gambar/video independen, pemutaran video, penghapusan gambar yang mempertahankan
video, serta tata letak media mobile. **51 pemeriksaan lulus**, termasuk upload,
preview dan start prediksi, kedua role, form publik dan lima ukuran viewport.
Commit `49da8eb` sudah di-deploy ke `https://deepct-web.vercel.app` dan Pi.
**39 smoke check API Pi** memastikan skema lama hilang, route lama 404 bagi
kedua peran, API aktif berfungsi dan researcher tidak dapat melakukan cleanup
admin. **25 check HTTPS publik** lulus, termasuk route worker lama 404,
form login/request/reset, batas sesi/role, serta artikel penuh 2.560 karakter
dengan 13 paragraf. Backup/migrasi/cleanup sukses pada workflow Release
`37828069000`; Next.js `37828069039` selesai sukses. Uji ini tidak
menggantikan UAT ilmiah prediksi terhadap worker GPU nyata.

## Catatan historis — 1 Oktober 2026

Dokumen ini mencatat pengujian black box dari sudut pandang pemakai. Penguji
tidak membaca state database dan tidak memanggil class internal; hanya respons
HTTPS dan tampilan web produksi yang dinilai.

## Lingkungan

| Bagian | Alamat/versi |
|---|---|
| Web produksi | `https://deep-ct-ai-prod.vercel.app` |
| API produksi | `https://zestfully-usable-pledge.ngrok-free.dev/api` |
| Backend | Raspberry Pi, Laravel Octane/RoadRunner pada port 8000 |
| Tanggal | 1 Oktober 2026 |
| Commit | `c6f4f1f` |

Kredensial dan bearer token sengaja tidak ditulis dalam dokumen. Akun uji
adalah `admin@brin.go.id` dan `researcher@brin.go.id` yang dibuat melalui
workflow bootstrap manual.

## Black Box API

| ID | Skenario | Langkah ringkas | Hasil yang diharapkan | Hasil aktual | Status |
|---|---|---|---|---|---|
| BB-01 | Liveness publik | `GET /health` tanpa token | HTTP 200 dan `success=true` | HTTP 200, `success=true` | Lulus |
| BB-02 | Login admin | Kirim email dan password admin ke `POST /login` | HTTP 200, token ada, role `admin` | HTTP 200, role `admin` | Lulus |
| BB-03 | Login researcher | Kirim email dan password researcher ke `POST /login` | HTTP 200, token ada, role `user` | HTTP 200, role `user` | Lulus |
| BB-04 | Password salah | Login researcher dengan password salah | HTTP 422 dan error pada field email | HTTP 422, satu error email | Lulus |
| BB-05 | Profil admin | `GET /user` memakai token admin | HTTP 200, role `admin` | HTTP 200, role `admin` | Lulus |
| BB-06 | Hak admin | `GET /admin/users` memakai token admin | HTTP 200 | HTTP 200 | Lulus |
| BB-07 | Profil researcher | `GET /user` memakai token researcher | HTTP 200 dan email cocok | HTTP 200 dan email cocok | Lulus |
| BB-08 | Batas peran | `GET /admin/users` memakai token researcher | HTTP 403 | HTTP 403 | Lulus |
| BB-09 | Route terlindungi | `GET /user` tanpa token | HTTP 401 | HTTP 401 | Lulus |
| BB-10 | Logout admin | `POST /logout` memakai token admin | HTTP 200 | HTTP 200 | Lulus |
| BB-11 | Token admin dicabut | Ulangi `GET /user` memakai token yang telah logout | HTTP 401 | HTTP 401 | Lulus |
| BB-12 | Logout researcher | `POST /logout` memakai token researcher | HTTP 200 | HTTP 200 | Lulus |

Hasil eksekusi otomatis: **12 dari 12 skenario lulus**. Pengujian menggunakan
respons produksi yang nyata; token dibuat lalu dicabut selama skenario berjalan.

## UAT Antarmuka Web

| ID | Skenario pengguna | Langkah | Kriteria penerimaan | Hasil teramati | Status |
|---|---|---|---|---|---|
| UAT-01 | Membuka portal | Buka domain Vercel | Landing page BRIN tampil tanpa error, navigasi dan tombol Login terlihat | Landing page tampil pada deployment produksi terbaru | Diterima |
| UAT-02 | Membuka akses institusi | Tekan Login | Form email, password, Request Access, dan IT Support terlihat | Seluruh kontrol tampil dan dapat difokuskan | Diterima |
| UAT-03 | Masuk sebagai researcher | Isi kredensial researcher lalu tekan Authenticate | Berpindah ke dashboard researcher dan identitas akun tampil | Dashboard menampilkan `researcher@brin.go.id`, menu Research, dan aktivitas login | Diterima |
| UAT-04 | Pembatasan menu berdasarkan peran | Amati sidebar researcher | Menu administrasi pengguna/model tidak tersedia | Sidebar hanya memuat Dashboard, Analysis, History, Training, Activity, dan Messages | Diterima |
| UAT-05 | Keluar dari aplikasi | Tekan Sign out dan konfirmasi | Sesi berakhir dan pengguna kembali ke landing page | Dialog konfirmasi tampil; setelah konfirmasi landing page kembali | Diterima |
| UAT-06 | Login admin di produksi | Jalankan login admin melalui API produksi dan buka route admin | Role admin diterima serta route `/admin/users` dapat diakses | Login HTTP 200, role `admin`; route admin HTTP 200 | Diterima |

Catatan temuan: dashboard researcher menampilkan **“No model registered”**.
Ini bukan kegagalan autentikasi atau deployment web; database produksi memang
belum memiliki hasil sinkronisasi katalog dari worker model. Admin perlu
menjalankan **Model Management → Sync Models** ketika worker FastAPI aktif agar
model tersedia untuk prediksi.

## Kesimpulan Penerimaan

Migrasi akun dinyatakan diterima karena kedua peran dapat login, token dan
logout bekerja, route terlindungi menolak pemanggil anonim, serta pemisahan hak
admin/researcher terbukti dari luar aplikasi. Prediksi end-to-end belum menjadi
bagian hasil penerimaan ini karena katalog model produksi masih kosong.
