# Bagian C — Penelusur tumpukan frame, dan unggah dua langkah

**Tanggal:** 23 Agustus 2026
**Status:** rancangan disetujui, belum dikerjakan

Bagian keempat dari sepuluh permintaan perubahan yang diajukan 22 Agustus 2026.
Bagian A, B1 dan B2 sudah mendarat di `main`. Lihat ROADMAP.md §12.

## Yang sudah ada, dan itu mengubah ukuran pekerjaan ini

Diperiksa sebelum rancangan ini ditulis. Tiga hal membuat C jauh lebih kecil
daripada bunyi permintaannya:

**`GET /predictions/{id}/frames` sudah menggabungkan input dan output.**
`AnalysisController.php:235-236` menjelaskan kedua folder dan menyatukannya,
diurutkan menurut nama. Gabungan yang diminta di poin 9 tidak perlu dibangun.

**Galeri sudah menampilkan gabungan itu.** `frame_gallery_screen.dart:42` —
`_generatedOnly` **default `false`**. Filternya ada tapi mati. Pernyataan
sebelumnya dalam sesi ini bahwa galeri "sengaja memfilter hanya frame hasil"
salah.

**`_FrameViewer` sudah punya sebagian besar yang diminta.**
`frame_gallery_screen.dart:297` sudah punya `PageView` untuk berpindah frame,
`InteractiveViewer` untuk pan/zoom, pemuat per-frame, latar hitam, dan
keterangan yang membedakan frame hasil dari frame unggahan. Ia hanya privat,
tanpa slider, dan tanpa penanda di jalur slider.

**Endpoint preview sudah ada dan sudah bekerja.** `TiffPreview.php` — 302 baris
PHP polos yang mengurai IFD TIFF, menurunkan 16-bit ke 8-bit, dan menulis PNG
tanpa GD maupun Imagick. Ia dipakai `.../frames/{name}/preview`.

**`archive` resolve bersih** tanpa satu pun dependensi transitif baru, dan
`win32` tetap 5.15.0.

## C1 — Unggah dan analisis jadi dua langkah

### Alasannya

Poin 8 meminta preview muncul setelah berkas diunggah tetapi **sebelum**
analisis dimulai, supaya periset bisa melihat dan menggeser frame yang akan ia
kirim sebelum memutuskan menjalankannya.

Hari ini keduanya satu tombol. `PredictionIntake::fromZip()` membuat record
berstatus `pending` di baris 72 dan memanggil `ProcessDeepLearningImage::dispatch()`
di baris 77, dalam napas yang sama.

Alternatifnya — merender TIFF di sisi klien sebelum berkas naik — ditolak
dengan sadar: ia menuntut `TiffPreview.php` diporting ke Dart, sekitar 300
baris berisi parsing IFD, windowing, dan encoder PNG tulis tangan, menghasilkan
dua dekoder yang bisa saling berbeda tanpa ada yang menyadarinya.

### Perubahan

Enum `analysis_records.status` bertambah satu nilai **di depan**:

```
['uploaded', 'pending', 'processing', 'completed', 'failed']
```

`uploaded` berarti berkasnya di disk dan bisa dilihat, tetapi belum ada yang
mengantre. `pending` tetap berarti apa yang selama ini ia berarti: menunggu
worker.

`PredictionIntake::fromZip()` membuat record berstatus `uploaded` dan **tidak
lagi memanggil `dispatch()`**.

Endpoint baru:

```
POST /api/predictions/{id}/start
```

Memindahkan `uploaded` → `pending` dan mengantrikan pekerjaannya. Ia menolak:

- record milik akun lain — 404, bentuk yang sama dengan `findOwned()` yang ada,
  supaya keberadaan record orang lain tidak bocor lewat 403;
- record yang statusnya sudah lewat `uploaded` — 409. Menekan START dua kali
  tidak boleh mengantrikan dua pekerjaan, dan ini jalur yang mudah dipicu
  ketukan ganda di ponsel;
- record yang berkasnya sudah kedaluwarsa — 410, seperti `frames()`.

### Yang tidak perlu ditambahkan

`expires_at` sudah disetel saat record dibuat, jadi unggahan yang ditinggalkan
tanpa pernah dianalisis tetap disapu `predictions:cleanup` bersama yang lain.
Tidak ada kebocoran disk baru dan tidak ada retensi baru yang harus ditulis.

### Yang ikut terpengaruh

- `queuePosition()` di `PredictionUploadController.php` menghitung antrean;
  record `uploaded` tidak berada di antrean dan tidak boleh dihitung.
- Layar riwayat menampilkan status; `uploaded` butuh label dan warnanya
  sendiri — **"Ready to analyse"**, bukan "Uploaded", karena yang berguna bagi
  periset adalah apa yang bisa ia lakukan berikutnya.
- `respond()`/serialisasi prediksi mengembalikan `status`; klien harus tahu
  nilai barunya.

## C2 — Penelusur diangkat jadi widget bersama

`_FrameViewer` dicabut dari `frame_gallery_screen.dart` menjadi
`fe/lib/widgets/frame_stack_viewer.dart`, publik, dengan nama
`FrameStackViewer`.

Yang ditambahkan pada apa yang sudah ada:

**Slider kontinu** di bawah gambar, tersambung dua arah dengan `PageController`:
menggeser slider memindah halaman, dan menggeser halaman memindah slider. Dua
arah, karena satu arah menghasilkan slider yang berbohong begitu orang menyapu
gambarnya.

**Tick di jalur slider** menandai posisi frame hasil model. Ini yang membuatnya
berguna melebihi tombol panah: sebaran sisipan terlihat sekaligus, tanpa
menelusuri satu per satu.

**Badge di atas gambar**, di sudut — `HASIL MODEL` kuning, `INPUT` abu —
menggantikan keterangan yang sekarang berada di bawah gambar. Mata sedang di
gambar; keterangan yang jauh dari sana tidak terbaca.

Bagian D memakai widget ini apa adanya.

## C3 — Preview di dua tempat

Keduanya memakai `FrameStackViewer` dan endpoint yang sudah ada. **Tidak ada
endpoint preview baru.**

| Kapan | Isinya |
|---|---|
| Setelah unggah, sebelum analisis | Frame input saja — folder output masih kosong, dan `frames()` mengembalikan apa yang ada |
| Setelah prediksi selesai | Input dan hasil tergabung, dengan tick menunjukkan mana yang disisipkan model |

Yang kedua nyaris sudah jadi; yang kurang hanya slider dan tick dari C2.

## C4 — Beberapa `.tif` sekaligus

`FilePicker` dipanggil dengan `allowMultiple: true` dan `FileType.any` —
**tidak pernah `FileType.custom`**; alasannya panjang dan ada di CLAUDE.md,
dan intinya adalah pada web di ponsel sebuah berkas yang dilaporkan
`application/octet-stream` tidak bisa dipilih sama sekali.

Nama diperiksa dengan `hasExtension` di `lib/utils/file_extension.dart`:

- satu berkas `.zip` → dikirim apa adanya, seperti sekarang;
- satu atau lebih `.tif`/`.tiff` → dibungkus jadi ZIP di memori dengan paket
  `archive`, lalu dikirim lewat jalur yang sama;
- campuran, atau ekstensi lain → ditolak dengan kalimat yang menyebut apa yang
  diterima.

**Nama berkas tidak diubah sama sekali.** Penomoran di dalam nama itulah yang
memberi tahu backend di mana celah yang harus diisi; menormalkannya akan
menghancurkan persis informasi yang dibutuhkan.

Satu `.tif` tunggal tetap diterima dan dibungkus, meski interpolasi butuh dua
frame batas: penolakannya milik backend, yang sudah punya pesan untuk itu, dan
menduplikasi aturan itu di klien berarti dua tempat yang bisa berbeda.

## Cara menguji

**Backend** — `php artisan test`, dasar 270 setelah B2.

- unggah selesai meninggalkan record berstatus `uploaded` dan **tidak**
  mengantrikan apa pun;
- `POST /predictions/{id}/start` memindahkannya ke `pending` dan mengantrikan;
- menekannya dua kali dijawab 409 dan tetap satu pekerjaan;
- milik akun lain dijawab 404;
- berkas kedaluwarsa dijawab 410;
- `frames()` bekerja pada record `uploaded`, mengembalikan frame input saja.

**Frontend** — `flutter analyze` bersih, `flutter test` (dasar 153).

- slider dan halaman bergerak bersama di kedua arah;
- tick muncul pada indeks frame hasil, dan tidak muncul bila tidak ada;
- beberapa `.tif` dibungkus jadi satu ZIP yang berisi nama aslinya;
- satu `.zip` tidak dibungkus ulang.

**Di perangkat.** `SM A325F` sudah tersambung. Semua pemeriksaan mata yang
menumpuk sejak bagian A dikerjakan di sana — seleksi teks, kotak aktivitas,
kolom telepon, video, emoji, gelembung pending — bersama yang baru: menggeser
slider dengan jari, dan alur unggah → lihat → analisis.

**Satu prediksi nyata terhadap worker.** C1 menyentuh `PredictionIntake` dan
enum status, dan pipeline prediksi adalah satu-satunya jalur di proyek ini yang
pernah dibuktikan ujung-ke-ujung terhadap GPU sungguhan (ROADMAP, 18 Agustus).
Test yang lulus tidak membuktikan jalurnya masih utuh; satu run nyata iya.

## Risiko

**C1 mengubah pipeline yang sudah terbukti.** Ini risiko terbesar di seluruh
sepuluh permintaan. Mitigasinya bukan kehati-hatian melainkan run nyata di
atas.

**Membungkus ZIP di memori menambah salinan.** ROADMAP §11 sudah mencatat
seluruh arsip dimuat ke RAM sebelum sepotong pun dikirim; membungkus beberapa
`.tif` menambah satu salinan lagi di samping byte aslinya. Untuk beberapa frame
berukuran ~2 MB itu tidak berarti; untuk ratusan frame ia berarti. Batas praktis
disebut di antarmuka, bukan ditemukan sebagai kehabisan memori.

## Yang bukan bagian C

- **D** — tab Training admin dihapus; tab periset dikembangkan dengan unggah,
  `FrameStackViewer` dari C, dan metrik PSNR/SSIM/MAE/MSE.
- **§13** — navigasi swipe dan konfirmasi sebelum keluar.
- **Menyatukan tiga loop unggah berpotongan**, yang sudah dicatat di ROADMAP §10
  dan bertambah satu pemakai di B2.
