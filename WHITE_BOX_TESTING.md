# Skenario dan Hasil Pengujian White Box

> Kontrak aplikasi diperbarui 9 Oktober 2026: khusus prediksi; managed training telah dihapus.
> Status dan langkah kelanjutan agen: [checkpoint](handoff.md).

## Verifikasi lokal — 9 Oktober 2026

MySQL 8 terisolasi dan PHP 8.2: **329 tes / 1.381 asersi** lulus. Suite
`PredictionOnlyTest` membuktikan database baru tanpa tabel training/kolom kind,
upgrade database lama mempertahankan inference dan prediksi, route lama 404 untuk
seluruh peran, cleanup hanya menghapus berkas fitur lama serta menolak mount/skema
yang belum siap. Uploader menolak tujuan yang telah dihapus dengan 422.

Next.js: lint/TypeScript, build produksi Docker, lima tes origin BFF dan audit
dependensi produksi (nol temuan) lulus. Validasi Flutter dan deployment terbaru
dicatat setelah output workflow GitHub benar-benar tersedia; SDK Flutter tidak
tersedia di host pengujian lokal ini.

## Hasil historis — 1 Oktober 2026

Dokumen ini adalah spesifikasi pengujian internal yang dapat diulang. Ia bukan
ringkasan status proyek. Hasil berikut diamati pada **1 Oktober 2026** terhadap
commit `c6f4f1f` melalui GitHub Actions
[Release #11](https://github.com/DeepCT-Dev/DeepCT-AI-PROD/actions/runs/36853332173).

## Lingkungan

| Komponen | Lingkungan uji |
|---|---|
| Backend | PHP 8.2, Laravel 12, MySQL 8 service pada runner GitHub |
| Frontend | Flutter 3.44.9 pada runner Ubuntu |
| Perintah backend | `cd be && php artisan test` |
| Perintah frontend | `cd fe && flutter analyze && flutter test` |

SQLite tidak dipakai sebagai pengganti MySQL. Sejumlah migration menggunakan
sintaks MySQL sehingga hasil SQLite tidak setara. Mesin pengembangan juga tidak
memiliki driver SQLite aktif; karena itu bukti otoritatif berasal dari job CI
yang menyediakan MySQL 8.

## Skenario

| ID | Unit/cabang internal | Kondisi yang diberikan | Hasil yang diharapkan | Bukti otomatis | Hasil |
|---|---|---|---|---|---|
| WB-01 | Sumber password administrator | Konfigurasi yang ter-cache bernilai null, tetapi environment proses berisi password | Seeder memakai environment proses dan bukan membuat password acak | `AdminSeederTest::test_the_supplied_password_wins_over_a_stale_config_cache` | Lulus |
| WB-02 | Idempotensi seeder | Seeder dijalankan dua kali dengan password berbeda | Tetap satu admin dan hash berubah ke password kedua | `AdminSeederTest::test_seeding_twice_updates_rather_than_duplicates` | Lulus |
| WB-03 | Cabang akun produksi | Environment production berisi pasangan email/password researcher | Akun role `user`, aktif, terverifikasi, dan dapat memakai password yang diberikan | `AdminSeederTest::test_production_can_explicitly_seed_a_researcher` | Lulus |
| WB-04 | Penjaga konfigurasi parsial | Hanya salah satu dari email/password researcher tersedia | Seeder berhenti dengan `LogicException`; tidak membuat akun setengah jadi | `AdminSeederTest::test_production_researcher_credentials_must_be_complete` | Lulus |
| WB-05 | Autentikasi dan token | Login benar, login salah, beberapa sesi, logout salah satu sesi | Token hanya terbit untuk kredensial benar; sesi lain tidak ikut dicabut | `AuthTest` | Lulus |
| WB-06 | Otorisasi berbasis peran | Token researcher memanggil route admin; token admin memanggil route yang sama | Researcher ditolak 403 dan admin diterima | `AuthorizationTest` | Lulus |
| WB-07 | Sinkronisasi katalog model | `/models` memuat model baru, model lama, dan model yang hilang | Upsert berdasarkan slug tanpa duplikasi; model hilang ditandai tanpa dihapus | `ModelCatalogSyncTest` | Lulus |
| WB-08 | Health model | Tunnel gagal, respons bukan aplikasi, lalu katalog kembali sehat | Status dan alasan berubah sesuai cabang serta pulih ketika server kembali | `ModelHealthCheckTest` | Lulus |
| WB-09 | Pipeline prediksi | ZIP valid/tidak valid, worker berhasil/gagal, rekursi dan metadata frame | Status, file hasil, error, dan provenance mengikuti setiap cabang | `PredictionPipelineTest` dan `PredictionStartTest` | Lulus |
| WB-10 | Dekoder TIFF | TIFF 8/16-bit, endian berbeda, terkompresi, terpotong, dan terlalu besar | Format yang didukung dirender; format rusak/berbahaya ditolak; memori tetap terbatas | `TiffPreviewTest` dan `FrameMetricsTest` | Lulus |
| WB-11 | Integritas encoding | Sumber backend/frontend dipindai terhadap pola mojibake | Tidak ada pola encoding rusak di direktori sumber yang dijaga | `SourceEncodingTest.php` dan `source_encoding_test.dart` | Lulus |
| WB-12 | Logika dan layout Flutter | Login error, password gate, picker model, navigasi, unggah resumable, serta layout telepon | State, pesan, navigasi, dan batas layout sesuai kontrak | 33 berkas pada `fe/test/` | Lulus |

## Hasil Eksekusi

| Pemeriksaan | Hasil teramati |
|---|---|
| Backend PHPUnit | **385 test lulus, 1.536 assertion**, durasi 27,62 detik |
| Flutter static analysis | **No issues found**, durasi 16,8 detik |
| Flutter unit/widget test | **276 test lulus** |
| Build web | Lulus |
| Build Android APK | Lulus |
| Build Linux | Lulus |
| Build iOS/macOS | Lulus |

Kriteria penerimaan white box adalah tidak ada test gagal, static analysis
bersih, dan seluruh build yang didukung workflow selesai. Semua kriteria
terpenuhi pada run di atas.

