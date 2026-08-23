# Bagian E — Preview dataset training

**Tanggal:** 23 Agustus 2026
**Status:** rancangan disetujui, belum dikerjakan

Bagian ini menutup separuh poin 10 yang terlewat saat bagian D dirancang.
Bukan permintaan baru: kalimat aslinya berbunyi *"upload berupa .zip maupun
.tif juga **kemudian ada preview juga** berupa slider mirip imagej, **hasil
dari training** nanti berupa gambar yang bisa di slider"* — dua preview. Yang
kedua dibangun di D; yang pertama tidak.

Audit 23 Agustus 2026 menemukan tiga dari empat tempat preview sudah ada:

| Tempat | Status |
|---|---|
| Unggahan prediksi, sebelum analisis | ada (bagian C) |
| Hasil prediksi, di Results & History | ada (bagian C) |
| **Dataset training, sebelum training** | **tidak ada** |
| Hasil training, per epoch | ada (bagian D) |

## Kenapa ini jauh lebih kecil dari bagian C

Bagian C harus memecah unggah dari analisis karena `PredictionIntake`
mengantrikan pekerjaan pada detik berkasnya selesai naik — tidak ada jendela di
antaranya.

Training tidak begitu. `finalizeTraining()` di
`PredictionUploadController.php` membuat `TrainingJob` berstatus `queued`, dan
job itu duduk di sana sampai ada worker yang mengklaimnya lewat
`POST /training/worker/claim`. Itu bisa berjam-jam, atau tidak pernah kalau
tidak ada notebook yang hidup.

Jendela untuk melihat dataset sebelum apa pun berjalan **sudah ada**, dan
`POST /me/training/jobs/{id}/cancel` sudah ada untuk membatalkannya. Karena itu
E **tidak menambah status baru dan tidak memecah alur apa pun**.

## Membaca dari dalam ZIP

Dataset disimpan sebagai arsip utuh di `training/datasets/{uuid}.zip`. Ia
sengaja tidak diekstrak — tidak seperti prediksi, yang membongkar arsipnya ke
`input/`.

Itu justru menguntungkan di sini. `ZipArchive::getFromName()` mengembalikan byte
satu entri tanpa mengekstrak apa pun, dan `TiffPreview::toPng(string $tiff)`
sudah menerima byte mentah. **Nol byte disk tambahan**: sebuah dataset 2 GB
tidak digandakan hanya untuk dilihat.

`ZipArchive` sudah dipakai di `AnalysisController`, jadi ekstensinya ada.

### Endpoint

| Rute | Isinya |
|---|---|
| `GET /me/training/jobs/{id}/dataset/frames` | Nama entri `.tif`/`.tiff` di dalam arsip, terurut menurut nama |
| `GET /me/training/jobs/{id}/dataset/frames/{name}/preview` | Entri itu, dirender jadi PNG |

Keduanya dibatasi pemilik job lewat `ownedJob()` yang sudah ada di
`MeTrainingController.php` — 404 untuk orang lain, bentuk yang sama dengan
seluruh rute `me/`.

**Nama entri divalidasi terhadap daftar isi arsip**, bukan dipakai apa adanya.
Sebuah nama seperti `../../.env` yang lolos ke `getFromName()` akan membaca
berkas di luar arsip; memeriksanya ada di daftar yang sudah dikembalikan
endpoint pertama menutup itu tanpa pengurai jalur tersendiri.

### Cache

Hasil render disimpan di samping arsipnya, sama seperti `framePreview` prediksi
melakukannya: `training/datasets/previews/{dataset_id}/{name}.png`. Menggeser
bolak-balik tidak boleh mengurai ulang ZIP setiap kali, dan sebuah entri di
dalam arsip tidak pernah berubah.

Cache-nya ikut terhapus bersama dataset-nya.

## Di klien

Tombol **PREVIEW DATASET** di entri job, berdampingan dengan
**VIEW EPOCH FRAMES** yang sudah ada dari bagian D. Membuka `FrameStackViewer`
yang sama.

Semua frame bertanda `INPUT`: tidak ada yang dihasilkan model di sini, dan tick
di jalur slider akan kosong — yang memang benar dan bukan bug.

Frame dipetakan ke `PredictionFrame` dengan `kind: 'input'`, cara yang sama
dengan sampel epoch di bagian D. Itu tempat kedua di proyek ini yang memakai
`PredictionFrame` untuk sesuatu yang bukan frame prediksi, dan tetap lebih baik
daripada tipe kembar yang berbeda satu field.

## Cara menguji

**Backend** — dasar 272 test.

- daftar frame membaca entri `.tif` dari dalam ZIP tanpa mengekstraknya;
- entri yang bukan `.tif` tidak masuk daftar;
- preview merender sebuah entri jadi PNG;
- nama yang tidak ada di arsip dijawab 404, termasuk `../../.env`;
- job milik orang lain dijawab 404;
- render kedua dilayani dari cache, bukan dari ZIP.

**Frontend** — dasar 168 test. Frame dataset dipetakan dengan `kind: 'input'`
sehingga tidak ada tick yang muncul.

## Risiko

**Mengurai ZIP 2 GB untuk mendaftar isinya butuh waktu.** `ZipArchive::open()`
membaca direktori pusat di akhir berkas, bukan seluruh isinya, jadi biayanya
sebanding dengan jumlah entri dan bukan ukuran arsip. Untuk beberapa ratus
frame itu tidak terasa; kalau nanti sebuah dataset berisi puluhan ribu, daftar
itu layak dibatasi. Disebut di sini supaya ditemukan sebagai keputusan, bukan
sebagai kelambatan.

## Yang bukan bagian E

- **F** — navigasi swipe dan konfirmasi sebelum keluar.
- **Retensi arsip dataset** (ROADMAP §11). E menambah direktori cache yang ikut
  terhapus bersama dataset, tetapi tidak menjawab berapa lama sebuah dataset
  disimpan.
