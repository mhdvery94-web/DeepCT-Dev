# Bagian B2 — Video News dan Messages

**Tanggal:** 22 Agustus 2026
**Status:** rancangan disetujui, belum dikerjakan

Bagian ketiga dari sepuluh permintaan perubahan yang diajukan 22 Agustus 2026.
Bagian A (bersih-bersih UI) dan B1 (pembersihan skema) sudah mendarat di `main`.
Lihat ROADMAP.md §12 untuk seluruh pemecahannya.

## Tiga hal yang sudah diukur, bukan diduga

Ketiganya diverifikasi 22 Agustus 2026 dan menentukan bentuk rancangan ini.

**`post_max_size` PHP adalah 8M.** Satu POST multipart 25 MB ditolak
**HTTP 413** oleh `ValidatePostSize` Laravel — bukan oleh RoadRunner, dan bukan
oleh `upload_max_filesize`. Diuji langsung terhadap server yang berjalan. Video
50 MB karenanya tidak bisa dikirim dalam satu permintaan.

**Range request sudah bekerja.** `GET /api/news/1/image` menjawab
`Accept-Ranges: bytes`, dan `Range: bytes=0-99` dijawab **`206 Partial
Content`** dengan `Content-Range: bytes 0-99/594`. `response()->file()`
mengembalikan `BinaryFileResponse` Symfony, yang menangani Range sendiri —
proyek ini sudah mengandalkannya untuk unduhan ZIP yang bisa dilanjutkan
(`AnalysisController.php:394-396`). **Tidak ada kode Range yang perlu ditulis**;
menggeser video akan bekerja apa adanya.

**Kedua paket resolve bersih.** `flutter pub add --dry-run` untuk
`video_player` dan `emoji_picker_flutter` keduanya berhasil dengan `win32`
tetap di **5.15.0**, jadi tidak bentrok dengan `flutter_secure_storage` 9.x —
pertengkaran versi yang sudah dicatat CLAUDE.md. `video_player` menambah 7
paket, `emoji_picker_flutter` menambah 8 termasuk `shared_preferences`.

## B2.1 — Video di News

### Skema

```php
Schema::table('news_posts', function (Blueprint $table) {
    $table->string('video_path')->nullable()->after('image_mime');
    $table->string('video_mime', 60)->nullable()->after('video_path');
    $table->unsignedBigInteger('video_size_bytes')->nullable()->after('video_mime');
});
```

`video_size_bytes` tidak punya pasangan di sisi gambar, dan itu disengaja: 4 MB
tidak perlu diumumkan, 50 MB perlu. Angkanya ditampilkan di sebelah tombol
putar supaya orang di koneksi lambat tahu apa yang akan mereka mulai.

Konstanta di `NewsPost`, sejajar dengan `MAX_IMAGE_BYTES` dan `IMAGE_MIMES` yang
sudah ada di baris 35 dan 39:

```php
public const VIDEO_MIMES = ['video/mp4', 'video/webm'];
public const MAX_VIDEO_BYTES = 50 * 1024 * 1024;
```

Dua mime saja. `video/quicktime` sengaja tidak masuk: `.mov` tidak diputar oleh
Chrome di Android tanpa transcoding, dan mesin ini tidak punya apa pun untuk
melakukannya — persis alasan gambar disimpan byte-per-byte tanpa diubah
(`NewsController.php:276-280`).

### Unggah

`PredictionUploadController` mendapat tujuan **ketiga**. Ia sudah melayani dua,
dan komentarnya sendiri di `start()` baris 58-61 menuliskan alasannya:

> Both kinds are a ZIP arriving in pieces over an unreliable link, which is the
> entire problem this controller solves — a second copy of it for training
> datasets would drift from this one the first time either was touched.

Itu berlaku sama untuk salinan ketiga, jadi tidak ada mesin unggah baru.

- `start()`: `'purpose' => 'nullable|in:prediction,training,news_video'`, dengan
  `news_post_id` wajib bila purpose adalah `news_video`, dan `total_size`
  dibatasi `MAX_VIDEO_BYTES` untuk tujuan itu.
- `finalize()`: cabang ketiga ke `finalizeNewsVideo()`, mengikuti bentuk
  `finalizeTraining()` yang bercabang di baris 229-231.

**Pemeriksaan peran ada di dalam cabangnya.** Rute
`/api/predictions/uploads` terbuka untuk setiap pengguna terautentikasi, dan
mengunggah video berita adalah pekerjaan admin. Jadi `start()` dan
`finalize()` menolak `news_video` dari non-admin dengan 403, dan
`finalizeNewsVideo()` juga memastikan post-nya ada sebelum apa pun ditulis.

**Nama rutenya menyesatkan, dan itu diterima dengan sadar.**
`/api/predictions/uploads` untuk mengunggah video berita membaca aneh.
Menggantinya bisa dikerjakan kapan saja tanpa menyentuh logika apa pun, dan
menyalin mesinnya demi nama yang lebih rapi akan melanggar prinsip yang
tertulis di controller itu sendiri. Penggantian nama tidak termasuk B2.

Mime diperiksa **setelah** berkasnya utuh, dengan membaca tipe berkas yang
sebenarnya (`mime_content_type` pada berkas rakitan), bukan dari nama atau dari
apa yang diklaim klien. Ini mengikuti alasan yang sama dengan `mimetypes:`
alih-alih `mimes:` di `validatePayload()` baris 260.

### Penyajian

`GET /api/news/{id}/video`, meniru `image()` di baris 77-96: `response()->file()`
dengan `Content-Type` dari `video_mime`. Range gratis, sudah terbukti.

Payload post mendapat `has_video`, `video_url`, dan `video_size_bytes`,
sejajar dengan `has_image` dan `image_url` yang ada di baris 29-31.

### Penghapusan

Video hilang bersama post-nya dan saat diganti, meniru `deleteImage()`. Tidak
ada kedaluwarsa otomatis: berita dimaksudkan bertahan, tidak seperti hasil
prediksi yang disapu 24 jam. Admin yang mengendalikan, lewat menghapus post.

### Klien

`video_player`. Ia tidak punya implementasi Windows maupun Linux — hanya
Android, iOS/macOS, dan web. Proyek ini punya folder `windows/` dan `linux/`
dari scaffolding Flutter, tapi sasarannya web dan Android.

Di platform tanpa implementasi, pemutarnya **diganti tautan unduh**, bukan
dibiarkan melempar `MissingPluginException`. Deteksinya lewat
`defaultTargetPlatform`, bukan try/catch: sebuah pengecualian yang tertangkap
setelah layar dibangun sudah terlambat untuk mengubah apa yang digambar.

Gambar dan video keduanya opsional dan berdiri sendiri. Sebuah post boleh punya
keduanya, salah satu, atau tidak sama sekali.

## B2.2 — Tombol emoji

`emoji_picker_flutter`, satu tombol senyum di `MessageComposer`
(`fe/lib/widgets/message_bubbles.dart:211`). Widget itu dipakai bersama oleh
layar periset (`message_thread_screen.dart:160`) dan kotak masuk admin
(`admin_conversation_screen.dart:291`), jadi satu penyuntingan memberi keduanya.

Panel emoji muncul menggantikan papan ketik, bukan di atasnya, dan menutup saat
kolom teks difokuskan kembali. Emoji disisipkan pada posisi kursor, bukan
ditempel di akhir — orang menyisipkan emoji di tengah kalimat.

Tidak ada migrasi. `be/config/database.php:56-57` sudah `utf8mb4` /
`utf8mb4_unicode_ci`, jadi emoji tersimpan utuh. **Itu tetap diuji sekali dengan
emoji sungguhan yang dikirim lewat API dan dibaca kembali**, karena "seharusnya
bekerja" bukan bukti dan koleksi tabel bisa berbeda dari koleksi koneksi.

## B2.3 — Status pending

Tidak menyentuh database sama sekali. `MessageComposer.onSend` sudah bertipe
`Future<void> Function(String)`; yang belum ada adalah gelembung yang muncul
**sebelum** future itu selesai.

| Keadaan | Yang terlihat |
|---|---|
| sedang dikirim | gelembung muncul seketika, `Icons.schedule`, teks sedikit redup |
| terkirim | gelembung sungguhan dari server, `Icons.done` |
| terbaca | `Icons.done_all` — sudah bekerja hari ini |
| gagal | gelembung merah, `Icons.error_outline`, tombol coba lagi |

**Teks tidak boleh hilang saat gagal.** Kegagalan kirim yang memakan tulisan
seseorang adalah cara tercepat kehilangan kepercayaan pada sebuah kotak pesan.
`MessageComposer` sudah mengembalikan teks ke kolom saat `onSend` melempar
(`message_thread_screen.dart:117` — `rethrow; // The composer puts the text
back.`); perilaku itu dipertahankan, dan gelembung gagal memberi jalan kedua.

Menyentuh `message_bubbles.dart` dan kedua layar, karena daftar pesannya milik
layar.

## Cara menguji

**Backend** — `php artisan test`, dasar 256 setelah B1.

Test baru untuk unggah video:

- non-admin yang meminta `purpose: news_video` ditolak **403**, di `start()`
  maupun `finalize()`
- `total_size` di atas `MAX_VIDEO_BYTES` ditolak **422** di `start()`, sebelum
  satu byte pun dikirim
- berkas yang tipenya di luar `VIDEO_MIMES` ditolak saat finalize, dan
  potongannya dibuang
- menghapus post menghapus berkas videonya
- mengganti video menghapus yang lama
- emoji yang dikirim lewat `POST /api/messages` dibaca kembali utuh

**Frontend** — `flutter analyze` bersih, `flutter test` (dasar 147), lalu
**`flutter build apk --release`**. Yang terakhir wajib dan bukan formalitas: dua
paket baru, dan CLAUDE.md mencatat paket yang salah versi pernah mematahkan
build APK di kompilasi Java.

**Yang tidak dijangkau test:** memutar video sungguhan di aplikasi berjalan dan
menggesernya ke tengah. `curl` sudah membuktikan server menjawab `206`; itu
tidak membuktikan pemutarnya memintanya.

## Risiko

**Unggah 50 MB lewat ngrok akan lambat, dan bisa putus.** Mesin chunk-nya
memang dibuat untuk itu, tapi unggah dataset training belum punya kemampuan
melanjutkan sesi yang terputus (ROADMAP §10) — dan video akan mewarisi
keterbatasan yang sama. Sebuah unggahan yang putus harus diulang dari nol.
Ini disebutkan supaya tidak ditemukan sebagai kejutan.

**Seluruh berkas dimuat ke RAM sebelum sepotong pun dikirim.** ROADMAP §11
sudah mencatat ini untuk prediksi dan training: `withData: true` diikuti loop
yang memotong `Uint8List` yang sudah utuh di memori. Video 50 MB akan
menempuh jalur yang sama. Itu jauh lebih kecil daripada 2 GB yang jadi
kekhawatiran di sana, jadi B2 tidak memperbaikinya — tapi B2 juga tidak boleh
berpura-pura masalahnya tidak ada.

**Migrasi harus dijalankan di VPS saat deploy**, dengan `php artisan
config:cache` sesudahnya.

## Yang bukan bagian B2

- **C** — penelusur tumpukan frame ala ImageJ, dipakai di layar unggah dan di
  hasil/riwayat, ditambah unggah beberapa `.tif` sekaligus yang dibungkus ZIP di
  klien.
- **D** — tab Training admin dihapus, tab periset dikembangkan dengan unggah,
  viewer dari C, dan metrik PSNR/SSIM/MAE/MSE.
- **Mengganti nama `/api/predictions/uploads`.** Nama itu sudah menyesatkan
  untuk dataset training dan akan lebih menyesatkan lagi untuk video berita.
  Penggantiannya tidak menyentuh logika apa pun dan bisa dikerjakan kapan saja.
