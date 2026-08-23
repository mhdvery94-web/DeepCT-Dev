# Bagian D — Training milik periset

**Tanggal:** 23 Agustus 2026
**Status:** rancangan disetujui, belum dikerjakan

Bagian terakhir dari sepuluh permintaan perubahan yang diajukan 22 Agustus 2026.
A, B1, B2 dan C sudah mendarat di `main`. Lihat ROADMAP.md §12.

## Apa yang sudah ada, dan apa yang belum

Diperiksa sebelum rancangan ini ditulis.

**Mendaftarkan endpoint trainer sudah bisa hari ini.** `model_management_screen.dart:698`
punya `SegmentedButton` untuk memilih `kind` (`inference` / `trainer`) saat
membuat endpoint, dan `ModelController.php:62` menerimanya. Premis poin 6 —
"admin hanya menambahkan url endpoint untuk training model" — sudah terpenuhi.

**`metrics` sudah JSON bebas** di `training_jobs.metrics` dan
`training_metrics.metrics`. Komentar migrasinya menuliskan alasannya: *"loss,
psnr, ssim, whatever the notebook sends. Free-form on purpose — the training
code does not exist yet, and a fixed column set would be wrong before it is
written."* Menambah metrik tidak menuntut perubahan skema.

**Trainer hanya mengirim dua metrik.** `script-api-train-deepct.py:344-349`
mengirim `loss`, `psnr`, `batches`, `samples`, `balanced_t`. SSIM dan MSE tidak
dihitung sama sekali.

**MAE sudah dihitung, dengan nama lain.** Baris 294:
`loss = tf.reduce_mean(tf.abs(prediction - target))` adalah persis definisi
mean absolute error.

**Tidak ada apa pun untuk gambar contoh.** Tidak ada kolom, tabel, endpoint,
maupun kode di trainer.

**Jalur training belum pernah dijalankan sekali pun terhadap GPU sungguhan.**
ROADMAP §10, sejak 18 Agustus 2026.

## D1 — Tab Training admin dihapus, kemampuannya pindah

### Masalah dengan menghapusnya begitu saja

Layar Training admin bukan sekadar tampilan. `admin/training_screen.dart`
memegang tiga hal yang tidak ada di mana pun lain:

- **`_registerModel()`** (baris 227) — mengubah bobot hasil training menjadi
  versi model yang bisa dipakai periset. Tanpa ini, training yang selesai tidak
  punya jalan keluar sama sekali: bobotnya ada di disk dan tidak ada yang bisa
  memakainya.
- **`_dispatchJob()`** (baris 164) — mendorong job antre ke trainer.
- **`_deleteDataset()`** dan **`_deleteJob()`** (baris 133, 217) — satu-satunya
  penghapusan yang ada. ROADMAP §11 mencatat arsip dataset tidak punya retensi
  otomatis, sehingga ini juga satu-satunya rem terhadap disk yang terisi.

Menghapus tab tanpa memindahkan ketiganya akan membuat training jadi jalan
buntu.

### Yang hilang

Layarnya, dan entrinya di sidebar admin. Daftar job semua orang dan daftar
dataset memang mengulang apa yang sudah ada di tempat lain, dan itu yang
membuat poin 6 benar.

### Yang pindah ke Model Management

**Mendaftarkan bobot jadi versi model.** Di sanalah model hidup, jadi itu
tempatnya sejak awal. Layar mendapat satu bagian: job training berstatus
`completed` yang `resulting_model_id`-nya masih null, masing-masing dengan
tombol **REGISTER AS MODEL**. Endpoint
`POST /admin/training/jobs/{id}/register` tidak berubah.

**Menghapus dataset dan job.** Berdampingan dengan pendaftaran, karena keduanya
tentang membereskan sisa training. Endpoint tidak berubah.

### Yang dicabut

**`POST /admin/training/jobs/{id}/dispatch`.** Ia ada karena dulu admin yang
memulai run. Sekarang periset yang memulai, dan job antre diklaim worker lewat
`POST /training/worker/claim` — mekanisme yang memang dirancang untuk itu.
Tombol dorong manual adalah jalur kedua menuju hal yang sama, dan dua jalur
yang bedanya cuma siapa yang menekan bukanlah pengawasan. Rutenya, metode
controllernya, dan test-nya dihapus.

### Yang bertambah di layar periset

Tombol batal untuk job miliknya sendiri. Endpoint-nya sudah ada:
`POST /me/training/jobs/{id}/cancel`.

## D2 — Empat metrik

### Perubahan di `script-api-train-deepct.py`

Di fungsi `step` (baris 290-302), berdampingan dengan `psnr` yang sudah ada:

```python
ssim = tf.reduce_mean(
    tf.image.ssim((prediction + 1.0) / 2.0, (target + 1.0) / 2.0, max_val=1.0)
)
mse = tf.reduce_mean(tf.square(prediction - target))
return loss, psnr, ssim, mse
```

Pemanggilnya di `train_one_epoch` (baris 335) ikut menerima keempatnya, dan
dict metrik (baris 344) menjadi:

```python
metrics = {
    # `loss` here is L1 — mean absolute error by definition. It is reported
    # under both names: `mae` because that is what it is, and `loss` because
    # jobs recorded before this change are plotted under that key.
    "mae": round(float(np.mean(losses)), 6),
    "loss": round(float(np.mean(losses)), 6),
    "psnr": round(float(np.mean(psnrs)), 4),
    "ssim": round(float(np.mean(ssims)), 4),
    "mse": round(float(np.mean(mses)), 6),
    "batches": batches,
    "samples": len(samples),
    "balanced_t": balanced_t,
}
```

`loss` sengaja tetap dikirim dengan nilai yang sama. Job yang sudah tercatat
memakai kunci itu, dan membuangnya akan mengosongkan grafik mereka tanpa
alasan.

### Sisi platform

**Tidak berubah sama sekali.** `metrics` sudah JSON bebas, persis karena bentuk
ini belum diketahui saat kolomnya ditulis.

### Tampilan

Tabel per-epoch di layar training periset: epoch, MAE, MSE, PSNR, SSIM. Datanya
dari `training_metrics`, satu baris per epoch, terbaru di atas.

Metrik yang tidak ada di sebuah baris ditampilkan sebagai `—`, bukan `0`. Job
yang dijalankan sebelum skrip diperbarui hanya punya dua dari empat, dan nol
akan terbaca sebagai hasil pengukuran.

## D3 — Gambar contoh per epoch

Bagian terbesar, dan seluruhnya baru.

### Di trainer

Di akhir tiap epoch, generator dijalankan pada **satu triplet uji tetap** —
tetap, karena membandingkan epoch dengan triplet yang berbeda-beda tidak
mengatakan apa pun tentang modelnya. Tripletnya dipilih dari dataset dengan
indeks tetap dan dicatat sekali.

Hasilnya dikodekan jadi PNG dan diunggah ke endpoint baru.

### Skema

```php
Schema::create('training_samples', function (Blueprint $table) {
    $table->id();
    $table->foreignId('training_job_id')->constrained()->cascadeOnDelete();
    $table->unsignedInteger('epoch');
    $table->string('path');
    $table->timestamps();

    $table->unique(['training_job_id', 'epoch']);
});
```

`unique` pada pasangannya: sebuah epoch yang dikirim dua kali — worker yang
mengulang setelah kehilangan koneksi, yang di sini adalah keadaan normal —
harus menimpa, bukan menggandakan.

`cascadeOnDelete` menangani retensi: menghapus job menghapus sampelnya. Berkas
di disk dihapus oleh model event, mengikuti pola `User::booted()` yang sudah
ada.

### Endpoint

| Rute | Siapa | Untuk apa |
|---|---|---|
| `POST /training/worker/jobs/{id}/sample` | worker | Kirim PNG satu epoch |
| `GET /me/training/jobs/{id}/samples` | periset | Daftar epoch yang punya sampel |
| `GET /me/training/jobs/{id}/samples/{epoch}` | periset | PNG-nya |

Yang pertama berada di grup `training.worker` yang sudah ada — di luar
`auth:sanctum` dengan sengaja, karena worker bukan pengguna. Dua sisanya
dibatasi pemilik job, lewat `ownedJob()` yang sudah ada di
`MeTrainingController.php:209`.

Batas ukuran 4 MB per sampel, sejajar dengan `MAX_IMAGE_BYTES` di News: sebuah
PNG contoh tidak punya alasan lebih besar dari itu, dan tanpa batas sebuah
worker yang keliru bisa mengisi disk sepanjang training.

### Di klien

`FrameStackViewer` dari bagian C dipakai **apa adanya**, dengan satu perbedaan:
sumbunya adalah **epoch**, bukan nomor frame. Menggeser slider berarti melihat
model membaik dari epoch ke epoch, dan itulah satu-satunya alasan fitur ini
berguna.

Karena `FrameStackViewer` menerima `List<PredictionFrame>`, sampel dipetakan ke
bentuk itu dengan `name` berisi `'Epoch 3'` dan `kind` berisi `'output'`.
Memakai kembali tipe yang ada lebih baik daripada tipe kembar yang berbeda satu
field — tetapi ini disebut di sini karena ia satu-satunya tempat di seluruh
proyek yang memakai `PredictionFrame` untuk sesuatu yang bukan frame prediksi.

## D4 — Unggah dataset dengan preview

Layar training periset memakai `bundleFrames` dari bagian C, sehingga beberapa
`.tif` bisa dipilih sekaligus tanpa membungkusnya lebih dulu. Aturannya sama
persis dengan layar unggah prediksi: satu `.zip` dikirim apa adanya, beberapa
`.tif` dibungkus, campuran ditolak.

Preview dataset-nya memakai `FrameStackViewer` yang sama.

## Cara menguji

**Backend** — `php artisan test`, dasar 274 setelah C.

- sampel tiba dan tersimpan; epoch yang sama dikirim dua kali menimpa, bukan
  menggandakan;
- sampel di atas 4 MB ditolak;
- periset lain tidak bisa membaca sampel job orang;
- menghapus job menghapus sampel dan berkasnya;
- rute `dispatch` sudah tidak ada.

**Frontend** — `flutter analyze` bersih, `flutter test` (dasar 162).

- tabel metrik menampilkan `—` untuk metrik yang tidak ada, bukan `0`;
- sampel dipetakan ke `PredictionFrame` dengan label epoch yang benar.

**Yang tidak bisa diuji di sini.** Perubahan pada
`script-api-train-deepct.py` hanya bisa dibuktikan dengan menjalankannya di
Kaggle. Ia tidak punya test di repo ini dan tidak bisa dijalankan tanpa
TensorFlow dan GPU.

## Risiko

**D dibangun di atas jalur yang belum pernah dijalani.** ROADMAP §10 mencatat
sejak 18 Agustus bahwa training belum pernah berjalan sekali pun terhadap GPU
sungguhan. D menambahkan tiga hal baru di atasnya — metrik, endpoint sampel,
dan tabel baru — dan tidak satu pun bisa dibuktikan sampai sebuah training
benar-benar berjalan.

Berbeda dari prediksi, training memakan waktu berjam-jam dan menuntut sesi
Kaggle dengan skrip versi baru. **D akan ditandai belum terverifikasi di
ROADMAP sampai satu run nyata terjadi**, dengan cara yang sama seperti C.

**Mencabut `dispatch` mengandalkan mekanisme claim yang juga belum pernah
dijalani.** Bila claim ternyata tidak bekerja, mencabut dispatch menghapus
satu-satunya jalur cadangan. Itu diterima dengan sadar: dua jalur yang keduanya
belum terbukti tidak lebih aman daripada satu, dan yang dicabut adalah yang
menuntut admin menekan tombol untuk sesuatu yang seharusnya otomatis.

## Yang bukan bagian D

- **§13** — navigasi swipe dan konfirmasi sebelum keluar.
- **Menyatukan tiga loop unggah berpotongan** (ROADMAP §10).
- **Retensi otomatis arsip dataset** (ROADMAP §11). D menambah penghapusan
  manual di Model Management, tetapi tidak menjawab pertanyaan berapa lama
  sebuah dataset disimpan — itu keputusan yang belum diambil.
