# Arsitektur aplikasi

Aplikasi BRIN untuk interpolasi frame Neutron CT. Admin dan researcher memakai
**prediksi saja**. Training bukan fitur aplikasi. LLM masih rancangan:
lihat [LLM_DESIGN.md](LLM_DESIGN.md).

## Komponen

| Komponen | Tanggung jawab |
|---|---|
| `fe_web/` | Next.js 16.4, landing page, artikel, login, portal admin/user |
| `fe/` | Flutter, web dan aplikasi perangkat |
| `be/` | Laravel 12, Sanctum, MySQL 8, Octane/RoadRunner, antrean dan storage |
| `script-api-deepct.py` | FastAPI inference worker di host GPU/Kaggle/Colab |
| `docs/` | Kontrak, pengoperasian, pengembangan dan checkpoint |

Produksi: website di Vercel; API/queue/database di Raspberry Pi. Worker GPU
terpisah. Pi tidak memuat bobot model. Next.js menghubungi API melalui BFF
`/api/backend/*`; token Sanctum disimpan dalam cookie HTTP-only di server.
Flutter menggunakan bearer token dan URL API yang diberikan saat build.

## Alur prediksi

1. Pengguna memilih model tersedia dan mengunggah ZIP berisi TIFF bernomor.
2. API memeriksa kepemilikan, ukuran, ruang disk, nama frame dan isi arsip.
3. Frame diekstrak untuk preview; upload selesai berstatus `uploaded`.
4. Pengguna menekan Start; job berubah `pending` lalu `processing`.
5. Queue memanggil worker, merekam provenance dan metrik validasi yang tersedia.
6. Job menjadi `completed` atau `failed`; hasil diunduh melalui URL bertanda tangan.

Interpolasi rekursif selalu t=0.5. Untuk frame 1 dan 7, frame 4 dihasilkan dahulu.
`frame_provenance` mencatat batas dan generasi frame; `rerun_of_id` menghubungkan
perbandingan model. Jangan menampilkan angka confidence sebagai probabilitas
akurasi jika model/API tidak menghasilkannya.

Validasi hold-out memakai frame tengah asli bila tersedia. Metrik otomatis
meliputi MAE/RMSE/PSNR; SSIM tidak boleh diklaim tersedia bila tidak tercatat.
Eksperimen terdahulu menunjukkan error meningkat bila batasnya juga sintetis;
generation/provenance harus ikut dibaca. Build dan smoke API tidak membuktikan
kelayakan ilmiah model: UAT terhadap worker GPU nyata masih diperlukan.

## Data dan akses

Data aplikasi meliputi akun, access request, registry inference, prediksi,
aktivitas, pesan dukungan, berita, notifikasi, token dan antrean Laravel.
Researcher hanya mengakses prediksinya; admin memiliki route pengelolaan.
Akun nonaktif ditolak. Akun dengan password terbitan wajib menggantinya sebelum
memakai portal; profil/password/logout tetap tersedia untuk menyelesaikan proses.

Worker token terenkripsi, tidak dikirim ke klien; worker memeriksa
`WORKER_TOKEN`. TLS mengikuti konfigurasi model. Katalog diimpor dari URL
eksplisit; sinkronisasi mempertahankan secret dan sakelar admin.

## Storage dan fitur yang dipensiunkan

Retensi menghapus file prediksi setelah masa berlakunya, mempertahankan rekaman
dan evidence. Disk management hanya membersihkan data aplikasi yang memenuhi
syarat; pekerjaan aktif dilindungi. StorageGuard memeriksa headroom dan sentinel
mount bila dikonfigurasi.

Migrasi `2026_10_09_010000_remove_managed_training` menghapus empat tabel
training, trainer models, kolom kind dan aktivitas lama. Migrasi historis
dipertahankan agar upgrade database lama bekerja. Pemulihan membutuhkan backup
sebelum migrasi dan kode rilis sebelumnya; perintah cleanup hanya menyasar
direktori/sesi upload fitur lama. Detail operasi: [OPERATIONS.md](OPERATIONS.md).

## Antarmuka

Section landing mengikuti tinggi viewport/header; portal memakai main area
yang dapat digulir. Web memiliki kontrol bersudut lembut, fokus terlihat dan
dukungan reduced motion. Flutter mempertahankan temanya.
Editor berita mengatur teks/publikasi; Manage media menyediakan kartu gambar
dan video terpisah dengan preview serta upload/hapus masing-masing.
Aset aktif tersimpan di `fe_web/public/assets/` dan `fe/assets/`.
