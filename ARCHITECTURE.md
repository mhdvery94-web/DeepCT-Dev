# Arsitektur Sistem

Menggabungkan apa yang dulu tersebar di `ARCHITECTURE_FLOW.md`,
`FASE3_DECISIONS.md`, `DATABASE_STATUS.md` dan `be/DATABASE_CLEANUP.md`.
Semua yang tertulis di sini mencerminkan kode yang berjalan per 15 Agustus 2026.

---

## 1. Pembagian tanggung jawab

```
┌──────────────────────────┐
│  Flutter                 │  web (JS) + Android
│  admin & researcher      │
└────────────┬─────────────┘
             │ HTTPS, Bearer token (Sanctum)
             │ lewat tunnel ngrok berdomain tetap
┌────────────▼─────────────┐
│  Laravel 12 + Octane     │  RoadRunner, 4 worker, max 250 req/worker
│  ┌────────────────────┐  │
│  │ AnalysisController │  │  upload, daftar, unduh
│  │ PredictionUpload…  │  │  chunked upload
│  │ MeController       │  │  data milik sendiri
│  │ Admin controllers  │  │  user, model, activity
│  └────────────────────┘  │
│  queue: database         │──► ProcessDeepLearningImage (worker terpisah)
└──────┬──────────────┬────┘
       │              │ multipart POST
┌──────▼──────┐  ┌────▼──────────────────┐
│  MySQL 8    │  │  FastAPI @ Kaggle     │  bobot .h5, GPU
│  23 tabel   │  │  di balik ngrok       │  ~18–21 s / frame
└─────────────┘  └───────────────────────┘

storage/app/private/predictions/{user_id}/{job_id}/{input,output}/
```

**Mengapa dipisah begini.** Inferensi butuh GPU yang tidak dimiliki mesin
lokal, sementara data hasil penelitian tidak boleh menetap di layanan pihak
ketiga. Jadi orkestrasi dan penyimpanan tetap lokal, sementara satu-satunya
yang menyeberang adalah dua frame per panggilan — dan hasilnya langsung ditarik
kembali.

**Konsekuensinya yang harus diingat:** worker model bukan milik kita dan sesi
Kaggle berakhir sendiri. Sistem harus selalu memperlakukan model sebagai
sesuatu yang bisa hilang kapan saja, bukan dependensi yang pasti ada.

---

## 2. Alur prediksi

```
1. Peneliti memilih model + arsip .zip
       │
2. Upload ─── < 1 MB ──► POST /api/predictions              (satu request)
       └──── ≥ 1 MB ──► POST   /api/predictions/uploads     (buka sesi)
                        PATCH  …/{id}   × n                 (per potongan)
                        POST   …/{id}/finalize
       │
3. PredictionIntake: periksa ukuran ZIP setelah diekstrak, jumlah frame, nama
   duplikat, dan ruang disk; ekstrak .tif, validasi, buat AnalysisRecord
                                                            status: uploaded
        │
4. Peneliti melihat preview, lalu POST /api/predictions/{id}/start
   untuk mengantrekan pekerjaan                              status: pending
        │
5. queue:work mengambil job                                 status: processing
        │
6. ProcessDeepLearningImage:
      urutkan frame berdasarkan angka di nama berkas
      untuk tiap celah → interpolasi rekursif t=0.5
      simpan tiap hasil ke output/
       │
7. Selesai                        status: completed, expires_at = now + 24 jam
       │
8. Klien polling GET /api/predictions tiap 10 detik selama ada yang berjalan
       │
9. Unduh: results (hasil saja) atau complete (input + output + metadata.json)
   disertai header X-Checksum-MD5, diverifikasi ulang di klien
       │
10. predictions:cleanup (tiap jam) menghapus berkas lewat 24 jam,
   record tetap disimpan dan ditandai files_deleted_at
```

### Interpolasi rekursif

Diberikan frame 1 dan 7, sistem **tidak** menghasilkan 2–6 secara berurutan.
Ia menghasilkan titik tengahnya lebih dulu, lalu memakai hasil itu sebagai
batas baru:

```
1 ────────────────── 7        hasilkan 4
1 ──── 4             7        hasilkan 2  (dari 1 dan 4)
1   2  4 ──── 7               hasilkan 5  (dari 4 dan 7)
1   2  4   5  7               …dan seterusnya
```

Selalu t=0.5, tidak pernah ada input `time_scalar` manual di produk. Setiap
langkah adalah satu panggilan GPU, jadi celah sebesar n memakan n−1 panggilan —
karena itu ada batas 200 frame per job.

### Kontrak worker model

Satu domain ngrok menunjuk ke satu FastAPI multi-model server:

```text
GET  /
GET  /models
POST /predict/{model_name}
```

`GET /models` adalah katalog dinamis. Admin menjalankan **Sync Models**;
Laravel melakukan upsert berdasarkan `slug`, jadi menambah bobot di worker
tidak memerlukan perubahan source backend. Request inferensi tetap
`POST {full_endpoint_url}` **multipart**: `file_t0`, `file_t2`, `time_scalar`.

Balasan sukses adalah stream TIFF. **Kegagalan yang tertangani dibalas JSON
`{"error": ...}` dengan HTTP 200** — jadi status code saja tidak cukup untuk
menyimpulkan berhasil. Kode harus memeriksa `Content-Type`.

Sinkronisasi memeriksa `GET /` sebagai denyut server sebelum membaca katalog.
Health check per-model memakai `GET /models` dan memastikan slug/path model
masih tercantum; model yang hilang ditandai `model_missing`, tidak dihapus.
Tidak ada probe yang memanggil `/predict`, sehingga pemeriksaan kesehatan tidak
memicu inferensi GPU.

---

## 3. Skema database

23 tabel di `db_aict` — 15 milik aplikasi, 8 bawaan kerangka. Yang relevan:

### `users`
`name`, `email`, `phone`, `password`, `role` (enum admin/user), `is_active`,
`last_login_at`, `avatar_path`, `avatar_mime`. Tidak ada registrasi mandiri —
admin yang membuat akun, atau menyetujui permintaan di `access_requests`.

`phone` **opsional dan tidak unik**. Ia menggantikan `username`, yang dulu
`NOT NULL` dan `unique` sehingga setiap pembuatan akun harus mengarang satu —
padahal login memakai email dan setiap akun sudah punya `name`. Nomor telepon
menjawab pertanyaan yang benar-benar muncul, dan menyingkir saat belum ada
jawabannya.

`avatar_path` disembunyikan dari semua payload; klien hanya menerima
`avatar_url` (null kalau belum ada foto, yang jadi sinyal untuk menggambar
bingkai inisial).

### Unggah dan analisis adalah dua langkah

Sejak 23 Agustus 2026, mengunggah berkas **tidak** mengantrekan pekerjaan.
`PredictionIntake` menulis record berstatus `uploaded` dan berhenti; sebuah
permintaan kedua, `POST /predictions/{id}/start`, yang memindahkannya ke
`pending` dan memanggil `ProcessDeepLearningImage::dispatch()`.

Alasannya satu: preview harus berada di antara keduanya. Periset melihat dan
menggeser frame yang baru ia kirim sebelum memutuskan menghabiskan slot GPU
pada sesi Kaggle yang tidak selalu hidup.

Alternatifnya — merender TIFF di sisi klien sebelum berkas naik — ditolak
dengan sadar. Ia menuntut `TiffPreview.php` diporting ke Dart: 302 baris
parsing IFD, penurunan 16-bit ke 8-bit, dan encoder PNG tulis tangan, dengan
hasil dua dekoder yang bisa saling berbeda tanpa ada yang menyadarinya.

Posisi antrean menghitung record ber-status `pending`, jadi unggahan yang
belum dimulai memang tidak terlihat olehnya tanpa perubahan apa pun. Dan
`expires_at` sudah disetel saat record dibuat, sehingga unggahan yang
ditinggalkan tetap disapu `predictions:cleanup` seperti yang lain.

**Definisinya satu, di `QueueBoard`.** Angka itu muncul di tiga tempat —
riwayat periset, respons `POST /predictions/{id}/start`, dan papan antrean admin
— dan sempat dihitung ulang di masing-masing. Dua salinan dari aturan yang sama
akan menyimpang diam-diam, dan yang terlihat oleh periset pada job-nya sendiri
akan berbeda dari yang dilihat admin pada baris yang sama. `QueueBoard::positions()`
menyusun urutannya sekali, `positionOf()` mengambil satu baris darinya, dan
`board()` melayani panel admin dari urutan yang sama persis.

### `models` — registry model AI
`name`, `slug` (unik), `version`, `base_url`, `endpoint`,
`full_endpoint_url`, `endpoint_url` (alias kompatibilitas), `model_file`,
`worker_active`, `synced_at`, `auth_token`, `verify_tls`, `status` (enum
online/offline/trouble), `is_active`, `last_health_check`,
`health_check_error`, `health_check_reason`, `current_jobs_count`,
`total_predictions`, `accuracy`, `deployed_at`.

**`auth_token` adalah rahasia bersama yang diharapkan worker**, dikirim sebagai
`Authorization: Bearer`. Terenkripsi saat disimpan, dan `$hidden` pada
model-nya — bukan disaring di controller, karena model mencapai klien dari
setengah lusin tempat dan melewatkan satu berarti menerbitkan kredensialnya ke
setiap peneliti yang login. Yang dijawab API hanyalah `has_auth_token`.

**Sisi worker memeriksanya lewat `WORKER_TOKEN`.** Rahasia bersama butuh dua
pihak; sampai `1.29.2` hanya platform yang mengirim, dan tidak ada yang
memvalidasi. Kedua skrip Kaggle — `script-api-deepct.py` dan
`script-api-train-deepct.py` — kini membandingkannya dengan
`hmac.compare_digest`, bukan `==`, karena perbandingan string biasa berhenti
pada byte pertama yang berbeda dan selisih waktunya bisa dipakai memulihkan
rahasia satu karakter demi satu karakter. `WORKER_TOKEN` kosong berarti
terbuka, dan itu default-nya: menyalakannya diam-diam akan memutus sesi Kaggle
yang sedang berjalan. `GET /` sengaja tetap terbuka — ia tidak memulai apa pun,
dan melaporkan `protected` supaya satu lirikan menjawab apakah rahasianya sudah
berlaku.

**`verify_tls` default `false`**, persis perilaku sebelum kolom ini ada:
`withoutVerifying()` di-hardcode di setiap pemanggil worker untuk sertifikat
ngrok dan Colab. Default `true` akan menyalakan verifikasi pada endpoint hidup
yang belum pernah diuji dengannya. Form admin menawarkannya tercentang untuk
model **baru**, jadi keputusannya dibuat di tempat yang terlihat.

`health_check_error` menyimpan kata-kata pemeriksa apa adanya —
`"Tunnel is not running (ERR_NGROK_3200)"` — dan **hanya terlihat admin**,
karena dialah yang menyalakan ulang worker. `health_check_reason` adalah
kegagalan yang sama sebagai kode (`no_endpoint`, `tunnel_down`, `unreachable`,
`slow`, `model_missing`), dan itulah yang diterima periset: klien memetakannya jadi kalimat
yang bisa ditindaklanjuti, dan kodenya tidak membawa nama host.

`base_url`, `endpoint`, `full_endpoint_url`, dan alias `endpoint_url` **hanya
boleh terlihat admin**. Mengetahuinya berarti bisa
melewati platform dan menembak worker GPU langsung, jadi `/api/me/models`
sengaja mengembalikan bentuk yang lebih sempit.

### `analysis_records` — satu job interpolasi
`job_id` (uuid), `user_id`, `model_id`, `rerun_of_id`, `file_name`,
`input_folder`, `output_folder`, `interpolated_frames` (json),
`frame_provenance` (json), `validation` (json), `input_files_count`,
`output_files_count`, `processing_time_seconds`, `status`
(pending/processing/completed/failed), `error_message`, `expires_at`,
`files_deleted_at`.

**`validation` adalah satu-satunya angka kualitas yang bisa dimiliki platform
ini.** Frame yang ingin diisi seorang peneliti, menurut definisinya, tidak
dimiliki siapa pun — tidak ada ground truth untuknya. Yang bisa dilakukan
adalah menyembunyikan frame yang *memang ada*: di mana pun arsip memuat tiga
frame berurutan, yang tengah disisihkan, digambar ulang dari kedua tetangganya,
lalu diukur terhadap aslinya. Isinya `mae`, `rmse`, `psnr`, `pixels`,
`reference_min`, `reference_max`, `held_out_frame`, `index`, dan `from`.

`reference_min`/`reference_max` bukan hiasan: MAE 40 hitungan adalah galat
besar pada frame yang membentang 300 hitungan dan galat yang dapat diabaikan
pada frame yang membentang 60.000. `null` ketika arsipnya tidak memuat tiga
frame berurutan — kasus biasa, bukan kegagalan.

**`rerun_of_id`** menunjuk job yang di-run ulang dengan model lain. Frame
masukannya **disalin**, tidak dibagi: dua record yang menunjuk satu folder
berarti menghapus salah satunya ikut membawa masukan milik yang lain, dan
perbandingan yang separuhnya bisa lenyap sendiri-sendiri bukanlah perbandingan.
`nullOnDelete`, karena kehilangan job aslinya tidak boleh membawa serta
perbandingannya.

**`frame_provenance` mencatat dari mana tiap frame buatan berasal**, dan itu
bukan hal yang sama dengan `interpolated_frames`. Yang satu menyebut frame mana
saja yang dihasilkan; yang satunya menyebut frame 4 digambar di antara frame 1
dan 7 yang **keduanya hasil pindai**, sementara frame 2 digambar di antara
frame 1 dan frame 4 yang **baru saja dikarang model itu sendiri**. Keduanya
tidak sama-sama layak dipercaya, dan sebelum ini tidak ada apa pun di catatan
yang membedakannya.

Tiap entri: `frame`, `index`, `from` (dua indeks batasnya), `generation`, dan
`synthetic_parents`. `generation` bernilai 1 ketika kedua batasnya hasil
pindai, 2 ketika salah satunya sendiri frame buatan, dan naik terus seiring
galat menumpuk — angka itulah yang menjadikan metode rekursif bisa diperiksa
orang lain, bukan sekadar dipercaya.

Kolom baru, **bukan** perubahan bentuk `interpolated_frames`. Mengubah tipe
sebuah field yang sudah ada di payload persis yang mematikan setiap klien
terpasang di 1.25.1; pelajarannya cukup mahal untuk dipegang. Nilainya `null`
pada job yang selesai sebelum ini ada, jadi setiap pembaca wajib
memperlakukannya sebagai opsional.

> `t0_image_path`, `t2_image_path`, `t1_result_path` dan `time_scalar` adalah
> peninggalan desain lama yang berbasis sepasang gambar. Alur sekarang berbasis
> folder dan tidak mengisinya. Kolomnya dibiarkan nullable, bukan dihapus.

### `user_activities` — jejak audit
`user_id`, `model_id`, `activity_type` (varchar bebas), `description`,
`ip_address`, `user_agent`, `metadata` (json).

### `access_requests` — permintaan akun dari landing page
`first_name`, `last_name`, `email`, `institution`, `reason`, `status`
(pending/approved/rejected), `reviewed_by`, `reviewed_at`, `review_note`.
Menyetujui **membuat akun user-nya sekaligus**.

### `conversations` / `messages` — dukungan IT
Percakapan: `user_id` (**nullable dan unique** — satu percakapan per akun; null
untuk percakapan tamu dari halaman login, dengan `guest_name` + `guest_email`),
`last_message_at`, `is_archived`.

Pesan: `conversation_id`, `user_id` (nullable), `body`, `from_admin`, `read_at`.

`from_admin` dicap saat pesan ditulis, bukan diturunkan dari peran penulisnya
sekarang — mempromosikan seseorang jadi admin tidak boleh mengubah pesan
lamanya jadi balasan staf secara surut. `read_at` berarti "sudah dibaca pihak
seberang"; tiap pesan cuma punya satu pihak penerima, jadi satu kolom cukup
untuk dua arah.

> Ini dulunya `support_tickets` + `support_ticket_messages` dengan `subject`,
> `category`, `priority`, `status`, `awaiting_admin`, `resolved_at`,
> `resolved_by`, dan `analysis_record_id`. Semuanya dibuang — lihat §4.

### `notifications` — lonceng
Skema bawaan Laravel: `id` (uuid), `type`, `notifiable_type`/`notifiable_id`,
`data` (json), `read_at`. Dipakai apa adanya supaya `$user->notify()` dan
`$user->unreadNotifications` bekerja seperti dokumentasinya, dan supaya
mengirimkan event yang sama lewat email nanti cuma menambah `'mail'` di `via()`.

Tabelnya polimorfik, jadi **tidak punya foreign key** ke `users`. Karena itu
`User::booted()` menghapus notifikasi, token, avatar, berkas prediksi, bukti
hasil, dan berkas sementara saat akun dihapus. Penghapusan ditolak selama akun
masih memiliki prediksi atau training aktif, supaya pekerjaan yang sedang
berjalan tidak kehilangan berkasnya.

### `news_posts` — berita riset di landing page
`title`, `summary`, `body`, `image_path`, `image_mime`, `video_path`,
`video_mime`, `video_size_bytes`, `is_published`, `published_at`,
`sort_order`, `created_by`. `published_at` hanya diisi saat pertama kali
terbit.

Gambar dan video keduanya opsional dan berdiri sendiri: sebuah post boleh
punya keduanya, salah satu, atau tidak sama sekali. Gambar dibatasi 4 MB dan
tiba dalam satu permintaan; **video dibatasi 50 MB dan tidak bisa** —
`post_max_size` PHP adalah 8M, dan satu POST multipart 25 MB ditolak HTTP 413
oleh `ValidatePostSize` Laravel. Karena itu video menempuh mesin unggah
berpotongan di `PredictionUploadController` sebagai `purpose: news_video`,
tujuan ketiganya di samping `prediction` dan `training`.

`video_size_bytes` tidak punya pasangan di sisi gambar dengan sengaja: 4 MB
tidak perlu diumumkan, 50 MB perlu, dan angkanya ditampilkan di sebelah
tombol putar.

### `training_samples` — satu frame per epoch

`training_job_id`, `epoch`, `path`. Unik pada pasangan `(job, epoch)`: worker
yang mengulang sebuah epoch setelah sesi Kaggle-nya mati harus menimpa, bukan
menggandakan.

Dihapus bersama job-nya — tetapi **lewat Eloquent, bukan lewat foreign key**.
Cascade di database menghapus barisnya dengan sempurna dan tidak memicu event
model sama sekali, sehingga setiap PNG akan tertinggal di disk tanpa ada yang
menunjuknya. `TrainingJob::booted()` menghapusnya lebih dulu justru karena itu.

### Tabel lain
`personal_access_tokens` (Sanctum), `cache`, `cache_locks`, `jobs`,
`job_batches`, `failed_jobs`, `migrations`, `sessions`,
`password_reset_tokens`.

Dua yang terakhir tidak dipakai untuk autentikasi API. `sessions` tetap terisi
karena route `/` memakai session (`SESSION_DRIVER=database`); jangan
menghapusnya tanpa mengubah driver dulu.

---

## 4. Keputusan teknis dan alasannya

### Kenapa ZIP, bukan unggah banyak berkas
Satu sekuens bisa berisi ribuan frame. Satu request untuk seluruh arsip jauh
lebih murah daripada ribuan request, memberi operasi yang atomik, dan membuat
validasi terjadi di satu tempat.

### Kenapa ada chunked upload padahal upload langsung berhasil
Terukur: upload langsung 4 MB **berhasil** meski `upload_max_filesize` 2 MB,
karena di bawah Octane **RoadRunner mem-parsing multipart sendiri** dan batas
PHP SAPI tidak berlaku. Jadi chunked bukan untuk menembus batas PHP.

Ia tetap dipertahankan karena tiga alasan lain: sambungan yang putus bisa
dilanjutkan, progres bisa dilaporkan jujur, dan aplikasi tetap bekerja bila
suatu saat dideploy di belakang nginx + PHP-FPM yang batasnya memang berlaku.

Ukuran potongan dihitung server dari batasnya sendiri (80% dari yang terkecil
antara `upload_max_filesize` dan `post_max_size`), lalu diumumkan ke klien.
Klien tidak pernah menebak.

**Sisi klien menyimpan sesinya.** Yang disimpan cuma *keterangan* upload-nya —
`upload_id`, nama berkas, ukuran, dan MD5 — bukan byte-nya: arsipnya puluhan
megabyte, dan di web tidak ada path untuk membacanya ulang. Jadi melanjutkan
berarti meminta berkas yang sama sekali lagi, dan MD5 itulah yang membuktikan
memang berkas yang sama. Menyambung berkas berbeda ke sesi yang setengah jalan
menghasilkan ZIP rusak yang baru ketahuan jauh belakangan, di dalam worker.

Potongan yang gagal dicoba ulang tiga kali, dan **sebelum tiap percobaan offset
disinkronkan ulang dari server**: request yang timeout bisa saja sebenarnya
sampai, dan mengirim ulang dari offset basi justru dijawab 409. Sesi hanya
dihapus kalau server menolak secara tegas (mis. 422) — kalau kegagalannya
berbau jaringan, sesi sengaja ditinggalkan supaya masih bisa dilanjutkan.

**Pada target native, ZIP tidak pernah utuh di heap.** Sebelum alur ini klien memilih
berkas dengan `withData: true`, sehingga picker menyerahkan seluruh berkas ke
heap Dart dan loop potongan hanya mengiris `Uint8List` yang sudah tergeletak di
sana — yang dihemat chunking cuma *transport*-nya, dan itu bukan bagian yang
menjadi masalah. Sebuah dataset boleh 512 MB; sebuah tab peramban atau telepon
sudah hilang jauh sebelum angka itu.

`ArchiveSource` adalah sambungan yang memperbaikinya. Sebuah sumber tahu
panjangnya dan bisa menghasilkan rentang mana pun saat diminta — dan hanya itu
yang sebenarnya pernah dibutuhkan loop unggah. Di target native rentangnya
dibaca dari disk, jadi tidak ada yang menetap selain potongan yang sedang
berjalan (`file_archive_io.dart`). Di web tidak ada handle berkas untuk dibuka,
jadi byte-nya memang di memori, dan `BytesArchiveSource` menyatakan itu apa
adanya alih-alih berpura-pura (`file_archive_web.dart`).

### Kenapa piksel preview hidup di untai biner, bukan array PHP

`TiffPreview` dulu meletakkan tiap piksel sebagai satu entri array PHP — dan
dua kali, karena hasil `unpack()` disalin ke akumulator. Sebuah frame 2048×2048
berbiaya **196 MB**, dan sepasang frame, yang memang ditahan `FrameMetrics`
sekaligus, berbiaya **262 MB**.

Worker antrean berjalan pada batas bawaan 512 MB, jadi prosesnya mati di tengah
job dan membawa seluruh run bersamanya, sementara layar masih menulis `pending`
tanpa satu pun keterangan. `--memory` tidak menolong: ia hanya memutuskan kapan
worker mendaur diri, bukan menaikkan batas PHP.

Piksel sekarang tinggal di untai biner dan dibongkar satu blok pada satu waktu.
Frame yang sama berbiaya **11,7 MB**, sepasang **20 MB** — turun 94%. Plafon
`MAX_PIXELS` naik kembali dari 2048² ke **4096²**; tabel pengukurannya dan
alasan ia tidak kembali sampai 8192² ada di docblock konstanta itu. Yang
membatasi sekarang adalah *waktu* dekode, bukan memori.

### Kenapa tiket dukungan diganti jadi pesan biasa

Model tiket memaksa orang yang sedang bermasalah **mengklasifikasikan
masalahnya lebih dulu**: pilih subjek, kategori, prioritas, lalu pantau
statusnya. Itu bentuk helpdesk yang di belakangnya ada satu departemen dengan
SLA. Di sini adminnya satu orang, dan yang orang butuhkan cuma bilang "ini
rusak" lalu dijawab.

Yang dibuang: `subject`, `category`, `priority`, `status` (4 keadaan),
`awaiting_admin`, `resolved_at`, `resolved_by`, `analysis_record_id`. Yang
tersisa: siapa yang bicara, kapan terakhir, dan apakah admin sudah
mengarsipkannya.

**Satu percakapan per akun, dijamin unique index** — bukan sekadar diharapkan.
Efek sampingnya yang paling berharga bukan soal tampilan: route peneliti jadi
**tidak menerima id sama sekali**, karena "punya saya" satu-satunya arti yang
mungkin. Seluruh kelas bug "akun A membaca pesan akun B" hilang bukan karena
dijaga, tapi karena tidak ada id yang bisa diutak-atik.

Yang tetap dipertahankan dari desain lama: percakapan bolak-balik (masalah
teknis hampir selalu butuh pertanyaan balik) dan jalur tamu dari halaman login
(orang yang tidak bisa masuk justru yang paling butuh bantuan).

### Kenapa notifikasi memakai sistem bawaan Laravel

Menulis baris sendiri ke tabel buatan sendiri sama mudahnya — sampai suatu saat
notifikasinya harus dikirim lewat email juga. Dengan `Notification` bawaan,
perubahan itu adalah menambah `'mail'` di `via()`; dengan tabel sendiri, itu
sistem pengiriman kedua.

Yang tidak diikuti dari konvensinya: satu kelas per event. Itu akan jadi
selusin berkas yang bedanya cuma string. Yang berubah antar-event cuma
payload-nya, jadi payload itu yang jadi konstruktor
(`PlatformNotification`), dan **semantiknya dikumpulkan di satu berkas**
(`app/Services/Notifier.php`) yang bisa menjawab "aplikasi ini pernah
memberitahu orang soal apa saja?" dalam sekali baca.

Dua aturan yang menopang desainnya:

- **Notifikasi tidak boleh menjatuhkan pemanggilnya.** Prediksi yang sudah
  selesai tidak boleh ditandai gagal cuma karena menulis baris notifikasi
  gagal. Semua lewat `push()` yang menelan error dan mencatatnya di log.
- **Status model diberitahukan hanya saat berubah.** Health check jalan tiap 5
  menit; tanpa aturan ini, model yang mati semalaman menghasilkan 288
  notifikasi identik.

Notifikasi berbeda dari `user_activities`: yang satu jejak audit untuk
diperiksa admin belakangan, yang lain pemberitahuan ke satu orang tentang
sesuatu yang perlu ditindaklanjuti sekarang. Satu kejadian bisa menghasilkan
keduanya.

### Kenapa polling, bukan WebSocket
Job berjalan puluhan detik sampai menit, dan hanya ada satu klien yang peduli.
Polling 10 detik yang berhenti sendiri saat semua job selesai jauh lebih murah
daripada memelihara infrastruktur realtime.

Keputusan yang sama berlaku untuk lonceng dan pesan, dengan interval berbeda
sesuai apa yang ditunggu:

| Yang dipantau | Interval | Alasan |
|---|---|---|
| Job prediksi | 10 detik | Hanya selama ada job pending/processing |
| Percakapan yang sedang dibuka | 15 detik | Pembacanya sedang menatap layarnya |
| Lonceng | 45 detik | Satu query count ber-index, dan membawa dua angka sekaligus |

`GET /notifications/unread-count` sengaja mengembalikan jumlah notifikasi
**dan** pesan, supaya lonceng dan penanda menu Messages tidak jadi dua request
yang berjalan berdampingan selamanya.

### Kenapa retensi 24 jam
Satu job bisa menghasilkan ~1,5 GB. Berkas dihapus, **record tetap disimpan**
dan ditandai `files_deleted_at`, sehingga peneliti tetap melihat riwayatnya dan
mendapat pesan "kedaluwarsa" yang jelas, bukan unduhan yang rusak.

### Kenapa sesi paralel diizinkan
Peneliti wajar memakai laptop dan HP bergantian, dan membatasi ke satu sesi
berarti salah satunya selalu terputus. Pernah dicoba dua bentuk pembatasan —
menendang perangkat lama, lalu menolak login baru — keduanya lebih mengganggu
daripada melindungi: aplikasi yang tertutup paksa mengunci akun sampai
token kedaluwarsa.

Batas keamanannya sekarang ada di masa berlaku token (7 hari) dan pembersihan
harian, bukan di jumlah sesi.

### Kenapa `deleteFileAfterSend()` tidak dipakai
Symfony melakukan unlink-nya di dalam `BinaryFileResponse::sendContent()`, dan
**Octane tidak pernah memanggil method itu** — ia mengubah response jadi PSR-7
untuk RoadRunner. Mengandalkannya membocorkan satu ZIP berukuran penuh setiap
kali unduh. Sekarang dibersihkan lewat `app()->terminating()`, dengan sapuan
per jam sebagai jaring pengaman.

---

## 5. Keamanan

| Lapis | Penerapan |
|---|---|
| Autentikasi | Sanctum bearer token, kedaluwarsa 7 hari (`config/sanctum.php`) |
| Status akun | Middleware `account.access` menolak akun nonaktif pada setiap request dan membatasi akun yang belum mengganti password ke profil, ganti password, dan logout. Nonaktif/reset mencabut token yang ada |
| Sesi | Beberapa perangkat dapat masuk bersamaan; logout mencabut token saat ini, reset/nonaktif mencabut semua token akun |
| Otorisasi | Middleware `role:admin`; selain itu tiap query di-scope ke `$request->user()` |
| Rate limit | Login 5 percobaan/menit/IP |
| Password | bcrypt, 12 rounds |
| Kepemilikan upload | Dipaksa lewat path storage — `upload_id` akun lain menghasilkan 404 |
| Integritas unduhan | `X-Checksum-MD5` wajib dan diekspos lewat CORS; klien memverifikasi sebelum menyimpan arsip. Klien native menulis sementara lalu mengganti nama setelah checksum cocok |
| Ekstraksi ZIP | Batas 50 MB/frame, 1000 frame, 2 GB total hasil ekstraksi; nama frame yang sama setelah folder diratakan ditolak |
| Rahasia | `endpoint_url` model tidak pernah keluar ke non-admin |
| Autentikasi worker | `auth_token` per model, dikirim `Authorization: Bearer`, terenkripsi saat disimpan, tulis-saja lewat API |
| Ruang disk | Unggah prediksi langsung/chunked dan training langsung menolak dengan **507** ketika tidak ada tempat; lihat `StorageGuard` |
| Volume hasil | Berkas sentinel membuktikan NAS-nya ter-mount, karena share yang absen menerima tulisan tanpa mengeluh |
| TLS ke worker | `verify_tls` per model; satu-satunya tempat `withoutVerifying()` tersisa adalah `WorkerRequest` |

Semua panggilan keluar ke worker dibangun **satu tempat**, `WorkerRequest`.
Sebelumnya ada lima, masing-masing mengulang dua baris dengan tangan; menambah
kredensial ke lima titik panggil berarti lima tempat untuk lupa, dan yang
terlupa persis yang bocor.

Yang **belum** ada: HTTPS milik sendiri (masih menumpang ngrok), audit
dependensi, dan pembatasan ukuran storage per user.

---

## 6. Proses yang harus berjalan

Backend saja tidak cukup. Tiga proses terpisah:

| Proses | Tanpa itu |
|---|---|
| `npm run octane` | Tidak ada API sama sekali |
| `php artisan queue:work` | Upload dan preview berhasil, tetapi job tetap `pending` setelah START |
| `php artisan schedule:work` | Berkas kedaluwarsa tidak pernah dihapus; status model jadi basi |

Tidak satu pun berjalan otomatis di setup Laragon saat ini.

---

## 7. Sistem pelatihan model — rancangan, belum dibangun

Tidak ada satu baris kode pun untuk bagian ini. Yang ada di bawah adalah
rancangan yang sudah dipikirkan sampai bisa dieksekusi, ditulis di sini supaya
tidak perlu dipikirkan dari nol lagi.

### Kenapa ini penting

Model sekarang dilatih pada dataset yang biasnya hanya bisa dihilangkan lewat
retrain. **Metode rekursif di §2 ada justru untuk menyiasati bias itu** — kalau
model dilatih ulang dengan dataset t yang seimbang, interpolasi bisa langsung ke
t sembarang dan seluruh pohon rekursif tidak diperlukan lagi. Lihat
[AI_EXPERIMENTS.md](AI_EXPERIMENTS.md).

### Batas yang menentukan bentuknya

Tiga kenyataan, dan semuanya tidak bisa dinegosiasikan:

1. **Notebook di repo ini nol kode training.** Yang ada cuma inferensi. Generator
   GAN 25,6 juta parameter, dan discriminator-nya tidak ada di sini.
2. **Sesi Kaggle putus tiap ~9–12 jam.** Training butuh berhari-hari. Apa pun
   yang dirancang harus tahan proses eksekusinya mati di tengah jalan.
3. **Mesin ini tidak punya GPU**, dan backend-nya PHP. Training tidak akan
   pernah berjalan di dalam Laravel.

### Bentuknya: platform **mengelola** training, bukan menjalankannya

Pembagian yang sama persis dengan alur prediksi — dan itu bukan kebetulan,
melainkan alasan utama rancangan ini masuk akal: infrastrukturnya sudah ada.

| Pihak | Tanggung jawab |
|---|---|
| Platform | Menyimpan dataset, mencatat job, menerima bobot + metrik, mendaftarkan versi model baru |
| Worker (Kaggle/Colab) | Menarik dataset, melatih, checkpoint berkala, melapor balik |

Platform tidak pernah memegang GPU dan tidak pernah menunggu. Ia mencatat.

### Tabel yang dibutuhkan

**`training_datasets`** — `name`, `description`, `archive_path`, `frame_count`,
`size_bytes`, `checksum`, `uploaded_by`. Diunggah lewat chunked upload yang
**sudah ada** (§4): dataset training justru kasus yang paling membenarkan
keberadaan alur itu — puluhan GB, jelas butuh resume.

**`training_jobs`** — `dataset_id`, `base_model_id` (nullable, untuk fine-tune),
`hyperparameters` (json), `status`
(queued/claimed/running/checkpointed/completed/failed/abandoned),
`current_epoch`, `total_epochs`, `metrics` (json), `checkpoint_path`,
`claimed_at`, `heartbeat_at`, `resulting_model_id`.

Tabel `models` sudah punya `version`, `accuracy`, dan `deployed_at`, jadi hasil
training tinggal jadi baris baru di sana — separuh jalan sudah terpasang.

### Alurnya, dan bagian yang paling mudah salah

```
admin unggah dataset  →  buat training job  →  status: queued
                                                    │
worker Kaggle polling GET /training/next ───────────┘
   │  klaim job (status: claimed, claimed_at diisi)
   │  tarik dataset, latih
   ├── tiap N epoch: POST /training/{id}/checkpoint  (bobot + metrik)
   │                 status: checkpointed, heartbeat_at diperbarui
   │
   └── sesi Kaggle mati ─────────────────────────────┐
                                                     │
   scheduler: job dengan heartbeat_at > 30 menit ────┘
              dikembalikan ke queued, checkpoint_path dipertahankan
                                                     │
   worker berikutnya klaim job itu ──────────────────┘
              lanjut dari checkpoint, bukan dari nol
```

**Heartbeat plus checkpoint adalah inti rancangan ini, bukan hiasan.** Sesi
Kaggle yang putus tiap ~9–12 jam bukan kasus tepi — itu kejadian normal yang
akan terjadi berkali-kali dalam satu training. Tanpa checkpoint yang dipulihkan,
setiap putus berarti mengulang dari awal, dan training berhari-hari tidak akan
pernah selesai. Ini kebalikan dari alur prediksi, yang boleh gagal begitu saja
karena satu frame cuma ~20 detik.

Konsekuensinya: **job training tidak boleh `failed` hanya karena worker-nya
diam.** Yang menandai gagal adalah worker yang melapor gagal; worker yang hilang
menghasilkan job yang kembali `queued`.

### Endpoint yang dibutuhkan

Semua di bawah `/api/training`, dengan token khusus worker (bukan token user):

| Method | Path | Untuk |
|---|---|---|
| `GET` | `/training/next` | Worker mengklaim satu job |
| `GET` | `/training/{id}/dataset` | Unduh arsip dataset |
| `POST` | `/training/{id}/heartbeat` | "Masih hidup", plus epoch/metrik terbaru |
| `POST` | `/training/{id}/checkpoint` | Unggah bobot sementara |
| `POST` | `/training/{id}/complete` | Bobot final + metrik → jadi versi model baru |
| `POST` | `/training/{id}/fail` | Melapor gagal beserta alasannya |

Token worker harus terpisah dari token user: worker itu mesin, umurnya panjang,
dan haknya sempit — cuma boleh menyentuh job yang diklaimnya sendiri.

### Yang tidak dirancang di sini

Notebook training-nya sendiri. Itu pekerjaan riset (arsitektur discriminator,
loss, augmentasi), bukan pekerjaan platform, dan menulis kontrak API tanpa tahu
bentuk akhirnya justru menghasilkan kontrak yang salah.

### Dua cara memulai: ditarik worker, atau didorong platform

Rancangan awalnya *pull*: worker mem-polling `claim`. Itu tetap ada dan tetap
jadi jaring pengaman. Tapi ada cara kedua yang bentuknya persis seperti
prediksi, dan itu yang biasanya diharapkan orang:

```
Konsol admin ──POST /train──► notebook GPU ──heartbeat/checkpoint──► platform
```

Admin mendaftarkan **trainer URL** (`TRAINING_TRAINER_URL`, atau diisi saat
menekan tombolnya), lalu menekan **SEND TO TRAINER** pada job yang antre.
Platform mem-POST job itu — id, epoch, hyperparameter, sumber dataset,
**alamat callback dan worker token** — ke URL tersebut.
`scripts/training_server.py` adalah sisi notebook-nya: FastAPI dengan
`POST /train`, kembarannya server inferensi yang sudah ada.

Tiga hal yang membuat ini bekerja, dan versi naifnya tidak:

1. **Request-nya cuma minta "terima job ini"**, dengan timeout pendek.
   Notebook harus menjawab langsung dan melatih di thread latar. Koneksi yang
   ditahan selama training berhari-hari akan timeout di jaringan mana pun.
2. **Job tetap `queued` setelah dikirim.** Trainer bilang ia *menerima*; yang
   membuktikan ia *mulai* adalah heartbeat pertama. Kalau platform langsung
   menandainya `running`, job yang tidak pernah jalan akan terlihat sehat
   selamanya.
3. **Mendorong tidak melewati protokol pelaporan.** Justru itu yang membuat
   job hasil dorongan selamat saat sesinya mati: heartbeat, checkpoint, dan
   `training:reclaim` bekerja persis sama.

Kalau dorongannya gagal — trainer menolak atau tidak terjangkau — job tetap
`queued`. Push yang gagal tidak boleh membuat job terlantar; worker yang
mem-polling masih bisa mengambilnya.

**Alamat callback divalidasi sebelum dikirim.** `APP_URL` di hampir semua mesin
pengembangan masih `http://localhost`, dan GPU di internet jelas tidak bisa
menjangkaunya. Tanpa pemeriksaan itu dispatch-nya sukses, trainer menerima, lalu
setiap laporan baliknya gagal diam-diam — job duduk di `queued` selamanya tanpa
ada yang menjelaskan kenapa. Sekarang ditolak **422** dengan pesan yang
menyebutkan variabel mana yang harus diisi. Ini ketahuan dari uji langsung,
bukan dari membaca kode.

### Ukurannya

Setara seluruh FASE 3 — tabel, endpoint, worker protocol, layar admin, dan
notebook training yang belum ada. Karena itu ia dijadwalkan terakhir, dan
[ROADMAP.md](ROADMAP.md) mencatatnya sebagai sistem terpisah, bukan fitur.

---

## 8. Deployment: `brin.fajrianhost.my.id`

Rencana: frontend di Vercel, backend di tempat lain, keduanya di bawah
subdomain dari `fajrianhost.my.id`.

### Frontend di Vercel — bisa, dan memang cocok

`flutter build web` menghasilkan berkas statis. Itu persis yang Vercel jalankan
paling baik, dan gratis untuk ukuran proyek ini.

```
brin.fajrianhost.my.id   →  CNAME  →  cname.vercel-dns.com
```

Build command-nya harus menyuntikkan alamat API, karena baseUrl dibaca saat
kompilasi:

```bash
flutter build web --release \
  --dart-define=API_BASE_URL=https://api.brin.fajrianhost.my.id/api
```

Output ada di `fe/build/web`. Di Vercel: framework preset **Other**, output
directory `build/web`.

### Backend di Vercel — **tidak bisa**, dan bukan soal konfigurasi

Ini bukan hal yang selesai dengan `vercel.json`. Empat hal di aplikasi ini
saling bertabrakan dengan model serverless, dan tiga di antaranya adalah
fitur yang baru saja dibangun:

| Yang dibutuhkan aplikasi | Yang diberikan Vercel |
|---|---|
| **Octane/RoadRunner** — server yang hidup terus | Fungsi serverless yang mati setelah tiap request |
| **`queue:work`** — proses jaga untuk interpolasi | Tidak ada proses jaga sama sekali |
| ~~Health check tiap 10 detik~~ | ~~Vercel Cron minimum **1 menit**~~ — tidak berlaku lagi sejak health check turun jadi sekali semenit |
| **Job prediksi sampai 7200 detik** | Batas eksekusi fungsi jauh di bawah itu |
| **Berkas hasil sampai ~1,5 GB per job** | Filesystem sementara, hanya `/tmp`, hilang tiap invocation |

Runtime PHP pihak ketiga untuk Vercel memang ada, tapi ia menjalankan PHP
seperti CGI — satu request, satu proses. Justru itu yang ditinggalkan proyek
ini waktu pindah ke Octane, dan angkanya ada di README: health check turun dari
8–11 detik jadi 1,3–1,7 detik. Memaksa backend ke Vercel berarti membatalkan
seluruh perbaikan itu **dan** kehilangan queue worker, scheduler, serta
penyimpanan berkas.

### Yang benar untuk backend: satu VPS kecil

Semua yang dibutuhkan aplikasi ini sudah biasa di VPS termurah sekalipun:

```
api.brin.fajrianhost.my.id  →  A  →  <IP VPS>
```

Kebutuhannya: PHP 8.2+, MySQL 8, dan **satu proses supervisor** yang menjaga
tiga hal yang hari ini dijalankan tangan (`npm run serve:all`):

```ini
[program:brin-octane]
command=php artisan octane:start --server=roadrunner --host=127.0.0.1 --port=8000
autorestart=true

[program:brin-queue]
command=php artisan queue:work --tries=1 --timeout=7200
autorestart=true

[program:brin-schedule]
command=php artisan schedule:work
autorestart=true
```

nginx di depannya sebagai reverse proxy + TLS (Let's Encrypt). Perlu diingat:
di belakang nginx, **batas `php.ini` mulai berlaku lagi** — hal yang sekarang
tidak berlaku karena RoadRunner mem-parsing multipart sendiri (§4). Naikkan
`client_max_body_size` di nginx dan `upload_max_filesize`/`post_max_size` di
`php.ini`, atau unggahan besar akan tertolak di produksi padahal lolos di
pengembangan.

RAM 1 GB cukup: 4 worker Octane + queue worker + MySQL muat, karena kerja berat
tidak pernah ada di sini — ia di GPU Kaggle.

### Alternatif tanpa VPS: tetap di mesin lab

Backend tetap di mesin ini, tapi ganti ngrok gratis dengan **Cloudflare
Tunnel**: hostname tetap, tanpa halaman interstitial, dan bisa langsung
dipetakan ke `api.brin.fajrianhost.my.id`. Header
`ngrok-skip-browser-warning` yang ditaburkan di klien jadi tidak perlu lagi.

Konsekuensinya jujur saja: kalau mesin lab mati, platform mati. Itu wajar untuk
demo dan skripsi, tidak untuk layanan yang dipakai orang lain.

### Yang harus disiapkan sebelum deploy

1. **CORS — dan `config/cors.php` itu tidak ada.** Berkas itu belum pernah
   di-publish, jadi yang berlaku adalah bawaan framework: `allowed_origins`
   bernilai `*`, dan itulah yang benar-benar dijawab VPS hari ini
   (`Access-Control-Allow-Origin: *`, terverifikasi 18 Agustus 2026).

   Ini **bukan** lubang yang terdengar, dan alasannya penting: Sanctum di sini
   memakai bearer token, bukan cookie. `*` yang berbahaya adalah `*` di samping
   `Access-Control-Allow-Credentials: true`, karena browser lalu mengirimkan
   cookie sesi ke asal mana pun. Di sini tidak ada cookie yang dikirim; token
   ada di secure storage dan dipasang klien sendiri, jadi asal lain tetap tidak
   punya apa-apa untuk dipakai. Tidak ada urusan `SANCTUM_STATEFUL_DOMAINS`
   maupun domain cookie.

   Kalau tetap ingin dipersempit, publish dulu berkasnya —
   `php artisan config:publish cors` — lalu isi `allowed_origins` dengan asal
   klien web. Menyempitkannya sebelum ada satu asal yang tetap justru akan
   memutus preview Vercel, yang hostname-nya berubah tiap deployment.
2. **`APP_DEBUG=false`** dan `APP_ENV=production`. Sekarang debug menyala, dan
   stack trace Laravel membocorkan path serta konfigurasi.
3. **Isi `SEED_ADMIN_PASSWORD`** sebelum `db:seed`. Kalau kosong, seeder
   membuat password acak dan mencetaknya sekali — jangan sampai terlewat di
   log CI.
4. **`TRAINING_WORKER_TOKEN` baru** untuk produksi — token pengembangan sudah
   pernah lewat terminal dan log.
5. **`script-deepct.py` jangan di-commit.** Berkas itu memuat token otentikasi
   ngrok dalam teks polos. Saat ini belum ter-track; biarkan begitu, atau
   pindahkan tokennya ke variabel lingkungan lebih dulu.
6. **Backup database.** Tiap deploy otomatis sekarang menulis satu dump
   sebelum menjalankan migrasi (lihat di bawah), dan menyimpan tujuh yang
   terakhir. Itu menutup kasus "migrasi merusak sesuatu", **bukan** kasus
   "disknya mati": tujuh berkas itu ada di mesin yang sama dengan
   databasenya. Backup di luar mesin masih belum ada.

### Dua backend, dan klien hanya bisa menunjuk satu

Sejak VPS hidup, ada **dua** backend yang dua-duanya sah:

| | Di mana | Untuk apa |
|---|---|---|
| **Lokal** | mesin lab, port 8000, lewat ngrok | Pengembangan, dan satu-satunya yang pernah diuji ujung-ke-ujung terhadap worker GPU |
| **VPS** | `/var/www/deepct-ai`, di balik nginx | Layanan yang hidup terus, tidak ikut mati kalau mesin lab dimatikan |

Yang perlu diingat, dan gampang terlewat: **alamat API dikompilasi masuk ke
klien.** Sebuah build hanya bisa menunjuk satu backend, dan ia berlaku untuk
semua target sekaligus — web, APK, iOS, desktop.

Yang memilihkan, berurutan:

| Variabel | Menunjuk ke |
|---|---|
| **`NGROK_BE_VPS`** | VPS. Terisi, dan semuanya menunjuk ke sana. |
| `NGROK_BE` | Mesin lab. Dipakai kalau yang di atas kosong — jadi **mengosongkan satu variabel** mengembalikan semua klien tanpa menyentuh kode. |
| `API_BASE_URL` | Nama lama, masih dihormati. |

Keduanya alamat ngrok, dan di sisi VPS itu bukan tambal sulam. Lihat "TLS di
VPS" di bawah.

Jadi keduanya bisa hidup berdampingan, tapi klien yang di-deploy ke Vercel
berbicara ke salah satu saja.

**Dan satu variabel itu tidak bisa memuaskan semua target sekaligus selama VPS
masih HTTP.** Ini yang paling mudah menghabiskan sore:

| Klien | Ke `http://<ip>:8080/api` | Ke `https://…/api` |
|---|---|---|
| **APK Android** | Jalan. `usesCleartextTraffic="true"` ada di manifest | Jalan |
| **Web di Vercel** | **Diblokir.** Halaman Vercel selalu HTTPS, dan browser menolak permintaan `http://` dari halaman HTTPS sebagai mixed content | Jalan |

Kegagalannya tidak sopan: tidak ada error jaringan yang jelas, cuma request
yang tidak pernah berangkat dan sebuah pesan di console browser. Jadi selama
VPS belum punya TLS, mengarahkan `NGROK_BE` ke sana **memperbaiki APK dan
mematikan web**.

Jalan keluarnya satu: sertifikat untuk VPS-nya. Arahkan sebuah nama ke IP-nya,
lalu `sudo certbot --nginx -d <nama itu>`. Sesudah itu satu alamat HTTPS
melayani ketiga target sekaligus dan variabelnya cukup diubah sekali. Memindahkannya ke VPS berarti mengubah satu
variabel di Settings → Secrets and variables → Actions → Variables, lalu
menjalankan ulang workflow-nya; tidak ada kode yang berubah. Job `preflight`
memeriksa nilainya tidak kosong dan berakhiran `/api` — **bentuknya saja, bukan
apakah alamat itu menjawab**, jadi menunjuk ke backend yang mati tetap lolos.

### Menyiapkan VPS-nya sekali: `be/scripts/provision-vps.sh`

Job deploy sengaja tidak menyiapkan apa pun — ia tidak pernah menulis `.env`,
tidak menjalankan `db:seed`, dan tidak menyentuh nginx, karena deploy yang
memiliki ketiganya akan menimpa kredensial produksi pada push berikutnya.
Skrip ini yang mengerjakannya, sekali, di server:

```bash
cd /var/www/deepct-ai
DB_PASSWORD='...' SEED_ADMIN_PASSWORD='...' bash scripts/provision-vps.sh
```

Ia ada di bawah `be/` bukan tanpa sebab: deploy meng-`rsync` **`be/` saja**,
jadi skrip yang diletakkan di atas itu tidak akan pernah sampai ke server yang
membutuhkannya. Di server ia mendarat sebagai
`/var/www/deepct-ai/scripts/provision-vps.sh`, dibawa oleh deploy pertama —
yang justru merupakan langkah 1 dari urutan di bawah.

Ia membuat database dan usernya, menulis `.env` dengan `APP_DEBUG=false` plus
`TRAINING_WORKER_TOKEN` baru, mengunduh binari RoadRunner, menjalankan migrasi,
memasang ketiga program supervisor dan reverse proxy nginx, lalu **menanyakan
`GET /api/news` ke proses yang benar-benar berjalan** sebelum menyatakan
selesai.

Aman dijalankan ulang, dan satu hal yang tidak akan pernah ia timpa adalah
`.env` yang sudah ada — di situ `APP_KEY` tinggal, dan menggantinya membuat
setiap nilai terenkripsi dan setiap token yang pernah diterbitkan tidak terbaca
lagi.

nginx dan supervisor bukan urusannya; ia mendelegasikan keduanya ke
`be/deploy/apply.sh`.

### nginx dan supervisor: `be/deploy/apply.sh`

Terpisah dari provisioning karena sifatnya berbeda. Provisioning berjalan
sekali dan melakukan hal yang tak bisa dibatalkan; ini hanya menulis ulang dua
berkas konfigurasi, aman dijalankan kapan pun keduanya berubah, dan **ikut
terkirim di setiap deploy** — jadi perubahan timeout atau batas unggah sampai
ke server tanpa siapa pun mengingat skrip provisioning itu ada.

```bash
cd /var/www/deepct-ai
TLS_DOMAIN=contoh.org bash deploy/apply.sh
```

Sumbernya template di `be/deploy/`:

| Berkas | Jadi apa |
|---|---|
| `nginx/deepct-proxy.conf` | Snippet yang di-`include` **kedua** server block, supaya pintu HTTP dan pintu TLS tidak bisa berbeda |
| `nginx/deepct-http.conf.template` | Server block HTTP (`HTTP_PORT`, bawaan 8080) |
| `nginx/deepct-tls.conf.template` | Server block TLS (`TLS_PORT`, bawaan 8443); dilewati kalau `TLS_DOMAIN` kosong |
| `supervisor/deepct.conf.template` | Ketiga program, dengan `stopwaitsecs` |
| `supervisor/ngrok.conf.template` | Program tunnel; dipasang hanya kalau `NGROK_DOMAIN` diisi |

```bash
cd /var/www/deepct-ai
NGROK_DOMAIN=nama-anda.ngrok-free.dev bash deploy/apply.sh
```

**`environment=HOME=...` di program ngrok itu wajib, bukan kerapian.**
supervisord tidak mewariskan `HOME`, dan tanpanya ngrok tidak menemukan
`~/.config/ngrok/ngrok.yml` — ia tetap start, gagal otentikasi, lalu mengulang
selamanya dengan pesan yang terbaca seperti token salah, bukan seperti home
directory yang hilang.

Itu juga yang menjaga token tidak muncul di command line. `--authtoken` di
`command=` berarti kredensialnya terbaca lewat `ps` oleh setiap akun di mesin
itu.

**Ia mengganti, bukan menambah.** Ia mencari berkas yang *sudah* mem-proxy ke
`127.0.0.1:8000` dan yang *sudah* mendefinisikan `[program:brin-octane]`, lalu
menulis ke situ. Alasannya beda untuk masing-masing: server block nginx kedua
tidak gagal dengan berisik, ia cuma memecah suntingan berikutnya ke dua berkas;
sedangkan **dua berkas supervisor yang mendefinisikan program yang sama membuat
`supervisorctl reread` menolak memuat apa pun**, dan itu muncul belakangan
sebagai job deploy melaporkan supervisor tidak mengenali program yang jelas-
jelas ada.

**`stopwaitsecs` itu bukan hiasan.** Bawaannya 10 detik. `brin-queue` berjalan
dengan `--timeout=7200`, jadi pada nilai bawaan **setiap deploy yang me-restart
worker akan meng-SIGKILL prediksi yang sedang berjalan** — sampai dua jam waktu
GPU dan satu job milik peneliti, hilang sepuluh detik setelah restart yang tak
seorang pun mengira merusak. Template ini menyetelnya 7260.

### TLS di VPS: kenapa ngrok, bukan certbot

Klien web butuh HTTPS — halamannya disajikan Vercel lewat HTTPS, dan browser
menolak memanggil `http://` dari sana tanpa error jaringan apa pun. Jadi
backend VPS harus punya alamat HTTPS. Dua jalan yang biasa ditempuh dua-duanya
buntu di mesin ini, dan keduanya diverifikasi, bukan diduga:

1. **`certbot` untuk hostname sendiri — buntu di DNS.** Diuji lewat resolver
   publik: `api.brin.fajrianhost.my.id`, `api.palembangtaste.shop` dan
   `deepct.palembangtaste.shop` semuanya menjawab **NXDOMAIN**. certbot tidak
   bisa menerbitkan apa pun untuk nama yang belum menunjuk ke mesin ini, dan
   record itu dibuat di penyedia DNS, bukan di sini.

   (Hati-hati saat memeriksa: resolver ISP kerap membajak NXDOMAIN dan
   menjawab satu alamat yang sama untuk subdomain apa pun. Itu terlihat seperti
   DNS yang sudah jadi. Tanya resolver publik.)

2. **Sertifikat yang sudah ada, di port sendiri — buntu di firewall.**
   Sertifikat mengikat *hostname, bukan port*, jadi server block TLS di port
   8443 bisa memakai sertifikat yang mesin ini sudah pegang untuk situs lain,
   dan klien yang menyambung ke `https://<nama itu>:8443/api` tetap melihat
   hostname yang dicakup. Sah secara TLS — tapi **port 8443 tertutup di
   security group Tencent**. Diuji: 8080 tersambung, 8443 timeout.

**ngrok menembus keduanya.** Ia menerbitkan TLS-nya sendiri, jadi tidak butuh
sertifikat maupun record DNS; dan ia menjangkau keluar dari dalam, jadi
firewall masuk tidak punya suara. Itulah kenapa VPS memakai tunnel padahal ia
punya IP publik.

Tunnel-nya diarahkan ke **nginx**, bukan langsung ke Octane. Di nginx-lah batas
unggah, timeout dan setelan buffering tinggal; tunnel yang menembak 8000
langsung akan melewati ketiganya tanpa bilang-bilang.

Template TLS (`nginx/deepct-tls.conf.template`) tetap ada dan tetap berfungsi.
Begitu 8443 dibuka, atau API punya hostname sendiri, `TLS_DOMAIN` mengaktifkan
kembali jalur yang tidak bergantung pada layanan pihak ketiga.

**Tiga angka yang harus sejalan, dan ini yang paling sering salah.**
`PredictionUploadController::chunkSize()` menurunkan ukuran potongan yang ia
iklankan dari `upload_max_filesize` dan `post_max_size` PHP **saat runtime**.
nginx harus mengizinkan lebih besar dari potongan terbesar itu, dan bawaan
Ubuntu `client_max_body_size 1m` justru **lebih kecil** daripada yang PHP
iklankan di instalasi standar. Ketidakcocokan itu tidak terlihat sampai
unggahan pertama dari klien sungguhan menjawab 413. Skrip ini menyetel
ketiganya sekaligus.

Satu lagi yang halus: yang diedit adalah **php.ini milik CLI**, bukan FPM.
RoadRunner menjalankan aplikasi lewat SAPI CLI, dan tidak ada PHP-FPM di
tumpukan ini sama sekali — mengedit ini FPM tidak akan berpengaruh apa pun.

**Urutan deploy pertama**, dan ia memang bertelur-ayam:

1. Push ke `main`. Job `vps` men-`rsync` kodenya ke server, lalu **berhenti**
   dengan "`.env` does not exist" — itu perilaku yang benar, bukan kegagalan.
2. Jalankan `scripts/provision-vps.sh` di server. Sekarang kodenya sudah ada
   di sana untuk dikerjakan.
3. Jalankan ulang workflow-nya. Deploy penuh berjalan sampai selesai.

### Deploy otomatis dari GitHub Actions

Job `vps` di `.github/workflows/release.yml` mengirim `be/` ke VPS pada tiap
push ke `main` dan tiap tag. Klien web tidak ikut — ia pergi ke Vercel lewat
job `vercel`, sesuai pembagian di awal bagian ini.

Empat secret repository dibutuhkan, dan job-nya menyebut yang hilang satu per
satu alih-alih sekadar gagal:

| Secret | Isi |
|---|---|
| `VPS_HOST` | Alamat atau hostname server |
| `VPS_USERNAME` | Akun SSH-nya (`ubuntu` di mesin sekarang) |
| `VPS_PORT` | Port SSH; **opsional**, dianggap 22 kalau kosong |
| `VPS_SSH` | Private key OpenSSH, isi berkasnya, bukan path |
| `VPS_KNOWN_HOSTS` | **Opsional.** Kalau diisi, host key dipatok dari sini. Kalau tidak, ia dipelajari dari apa pun yang menjawab di alamat itu — cukup untuk menangkap host yang *berubah* antar run, tapi mempercayai yang pertama. |

Urutannya, dan alasan tiap langkah ada:

1. **`rsync --delete`**, dengan `.env`, `storage/`, `vendor/`, `node_modules/`
   dan `rr.exe` dikecualikan — dan karena dikecualikan, juga terlindung dari
   `--delete` itu. `storage/` adalah datanya; `.env` adalah konfigurasi milik
   server yang tidak pernah jadi urusan repo; `rr.exe` adalah RoadRunner versi
   Windows, dan mengirim berkas PE 30 MB ke mesin Linux lebih buruk daripada
   sia-sia.
2. **`composer install --no-dev`** di server, bukan `vendor/` yang dikirim dari
   CI, supaya dependensinya terpasang terhadap PHP milik server sendiri.
3. **`mysqldump` sebelum `migrate`.** Kredensialnya dibaca dari `.env` server.
   Kalau dump-nya gagal, deploy berhenti di situ — sebelum migrasi menyentuh
   apa pun.
4. **`migrate --force`**, lalu `config:cache`, `route:cache`, `view:cache`.
5. **`supervisorctl restart`** untuk `brin-octane`, `brin-queue` dan
   `brin-schedule`. Ketiga nama itu sekarang **mengikat**: job-nya memanggil
   mereka apa adanya, dan berhenti dengan pesan yang jelas kalau supervisor
   tidak mengenali salah satunya. Octane memegang aplikasi di memori — tanpa
   restart, kode baru ada di disk sementara proses lama terus melayani yang
   lama, persis jebakan yang diperingatkan CLAUDE.md.
6. **`GET /api/news` di `127.0.0.1:8000`**, sampai sepuluh kali dengan jeda 3
   detik. Restart yang melapor sukses bukan bukti aplikasinya kembali hidup;
   ini menanyakannya ke proses yang benar-benar berjalan. Endpoint itu dipakai
   karena publik, murah, dan tetap menjawab 200 walau feed-nya kosong.

Yang **tidak** dikerjakan job ini, dan disengaja: ia tidak pernah menulis
`.env`, tidak pernah menjalankan `db:seed`, dan tidak menyentuh konfigurasi
nginx. Ketiganya milik server, dan sebuah deploy yang menimpanya akan
menghapus kredensial produksi pada push berikutnya.


---

## 9. Rilis dan distribusi klien

`.github/workflows/release.yml` membangun target klien dan menerbitkannya. Ada
tiga pintu masuk, dan pekerjaannya tidak sama:

| Pemicu | Yang dibangun | Hasilnya ke mana |
|---|---|---|
| **Push ke cabang fitur** | dua job test + `web` | Artifact di run itu, plus preview Vercel |
| **Push ke `main`** | semuanya | Rilis `latest`, Vercel produksi, **dan deploy backend ke VPS** |
| **Tag `v*`** (`git tag v1.2.0 && git push origin v1.2.0`) | semuanya | GitHub Release + Google Drive + VPS |
| **Actions → Run workflow** | semuanya | Google Drive saja |

| Job | Runner | Hasil |
|---|---|---|
| `preflight` | ubuntu | Memeriksa alamat API sebelum sepuluh menit build terbuang |
| `test` | ubuntu | `flutter analyze` + `flutter test` |
| `test-backend` | ubuntu | `php artisan test` di atas MySQL 8 dan PHP 8.3 |
| `web` | ubuntu | `brin-neutron-ct-web.zip` + direktori untuk Vercel |
| `vercel` | ubuntu | Deploy klien web (produksi di `main`, preview di cabang) |
| `vps` | ubuntu | **Deploy backend ke VPS** — lihat §8 |
| `android` | ubuntu | `brin-neutron-ct.apk` |
| `linux` | ubuntu | Bundle x64, butuh GTK 3 di mesin tujuan |
| `apple` | **macos** | `.ipa` dan `.app`, dua-duanya tanpa tanda tangan |
| `publish` | ubuntu | GitHub Release + unggah ke Google Drive |

**Kenapa ada dua job test.** `test` menjalankan sisi Flutter, `test-backend`
menjalankan sisi Laravel. Pemisahannya bukan soal kerapian: `vps` bergantung
pada `test-backend` saja, karena job itu mengirim `be/` dan tidak ada
hubungannya dengan klien. Sebelum job VPS ada, suite backend memang tidak
pernah berjalan di CI sama sekali — itu bisa dimaklumi selama berkas ini cuma
membangun klien, dan berhenti bisa dimaklumi begitu ia mulai men-deploy.

**Kenapa cabang fitur tidak mendapat semuanya.** Runner macOS ditagih sepuluh
kali lipat menit ubuntu, dan APK maupun `.ipa` yang tidak diminta siapa pun
adalah menit runner yang terbuang tiap push. Cabang fitur mendapat kedua job
test dan sebuah preview URL; `android`, `linux`, `apple`, `vercel` produksi dan
`vps` menunggu sampai `main` atau sebuah tag.

Efek samping yang justru berharga: sebelumnya `flutter analyze` dan
`flutter test` hanya berjalan saat ada tag, jadi `main` bisa rusak berminggu-
minggu tanpa ketahuan. Sekarang tiap push mengujinya.

Alamat API dikompilasi masuk, jadi CI membacanya dari repository variable
**`NGROK_BE`**, dengan `API_BASE_URL` masih dihormati sebagai nama lama.
Job `preflight` memeriksa ia tidak kosong dan berakhiran `/api` — **bentuknya
saja, bukan apakah alamat itu benar-benar menjawab.**

### iOS tanpa punya Mac

iOS hanya bisa dibangun di macOS — itu batas Apple, bukan batas Flutter. Job
`apple` berjalan di runner macOS GitHub, jadi build iOS tetap dihasilkan tanpa
siapa pun memiliki Mac. Ia membangun iOS dan macOS sekaligus di satu runner:
toolchain-nya sama, pub cache-nya sudah panas, dan job macOS kedua akan
menggandakan baris paling mahal di tagihan demi menghemat beberapa menit.

**Targetnya sudah cocok untuk iPhone X.** `IPHONEOS_DEPLOYMENT_TARGET = 13.0`,
sementara iPhone X (2017) menjalankan iOS 11 sampai 16.7 — jadi ia masuk dengan
selisih yang lega. Menurunkannya lebih jauh tidak ada gunanya: Flutter modern
sendiri tidak mendukung di bawah iOS 13.

Yang **tidak** bisa diselesaikan CI: penandatanganan. Build-nya `--no-codesign`,
artinya lengkap tapi tidak bisa dipasang ke perangkat. Memasangnya ke iPhone X
sungguhan butuh akun Apple Developer (US$99/tahun) plus provisioning profile;
setelah itu sertifikatnya ditaruh sebagai secret dan flag itu dilepas.

Info.plist juga sudah diisi `NSPhotoLibraryUsageDescription` dan
`NSCameraUsageDescription`. Tanpa itu iOS **menghentikan aplikasi** saat pemilih
berkas pertama kali menyentuh galeri — yaitu saat mengganti foto profil. Itu
crash, bukan peringatan.

### Google Drive

Langkah unggahnya memakai **rclone dengan token OAuth akun pribadi**, bukan
service account. Ini disengaja: service account tidak punya kuota penyimpanan
Drive sendiri, jadi mengunggah ke folder di My Drive orang lain gagal dengan
pesan "Service Accounts do not have storage quota" — pesan yang terdengar
seperti masalah izin, padahal bukan.

Sekali saja, di mesin mana pun yang punya rclone:

```bash
rclone authorize "drive"
```

Login, salin JSON yang tercetak ke repository secret **`RCLONE_DRIVE_TOKEN`**,
dan id folder tujuan — segmen terakhir URL folder-nya — ke
**`GDRIVE_FOLDER_ID`**. Tiap rilis mendapat subfolder sendiri, supaya build
berikutnya tidak menimpa yang lama.

Tanpa kedua secret itu langkahnya **dilewati, bukan gagal**: rilisnya tetap
terbit, dan log menjelaskan apa yang kurang.
