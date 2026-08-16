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
│  13 tabel   │  │  di balik ngrok       │  ~18–21 s / frame
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
3. PredictionIntake: ekstrak .tif (diratakan), validasi, buat AnalysisRecord,
   dispatch job                                            status: pending
       │
4. queue:work mengambil job                                status: processing
       │
5. ProcessDeepLearningImage:
      urutkan frame berdasarkan angka di nama berkas
      untuk tiap celah → interpolasi rekursif t=0.5
      simpan tiap hasil ke output/
       │
6. Selesai                        status: completed, expires_at = now + 24 jam
       │
7. Klien polling GET /api/predictions tiap 10 detik selama ada yang berjalan
       │
8. Unduh: results (hasil saja) atau complete (input + output + metadata.json)
   disertai header X-Checksum-MD5, diverifikasi ulang di klien
       │
9. predictions:cleanup (tiap jam) menghapus berkas lewat 24 jam,
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

`POST {endpoint_url}` **multipart**: `file_t0`, `file_t2`, `time_scalar`.

Balasan sukses adalah stream TIFF. **Kegagalan yang tertangani dibalas JSON
`{"error": ...}` dengan HTTP 200** — jadi status code saja tidak cukup untuk
menyimpulkan berhasil. Kode harus memeriksa `Content-Type`.

Health check sengaja memakai GET ke akar tunnel, bukan POST ke `/predict`:
pernah ada bug di mana probe POST tanpa berkas dibalas 422 dan model yang sehat
dilaporkan offline selamanya. GET juga menghindari memicu inferensi GPU
sungguhan hanya untuk mengecek denyut.

---

## 3. Skema database

18 tabel di `db_aict`. Yang relevan:

### `users`
`username`, `name`, `email`, `password`, `role` (enum admin/user), `is_active`,
`last_login_at`, `avatar_path`, `avatar_mime`. Tidak ada registrasi mandiri —
admin yang membuat akun, atau menyetujui permintaan di `access_requests`.

`avatar_path` disembunyikan dari semua payload; klien hanya menerima
`avatar_url` (null kalau belum ada foto, yang jadi sinyal untuk menggambar
bingkai inisial).

### `models` — registry model AI
`name`, `version`, `endpoint_url`, `status` (enum online/offline/trouble),
`is_active`, `last_health_check`, `health_check_error`, `max_concurrent_jobs`,
`current_jobs_count`, `total_predictions`, `accuracy`, `deployed_at`.

`endpoint_url` **hanya boleh terlihat admin**. Mengetahuinya berarti bisa
melewati platform dan menembak worker GPU langsung, jadi `/api/me/models`
sengaja mengembalikan bentuk yang lebih sempit.

### `analysis_records` — satu job interpolasi
`job_id` (uuid), `user_id`, `model_id`, `file_name`, `input_folder`,
`output_folder`, `interpolated_frames` (json), `input_files_count`,
`output_files_count`, `processing_time_seconds`, `status`
(pending/processing/completed/failed), `error_message`, `expires_at`,
`files_deleted_at`.

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
`User::booted()` menghapus notifikasi (dan token, dan berkas avatar) saat akun
dihapus — tanpa itu barisnya hidup selamanya tanpa ada yang bisa membacanya.

### `news_posts` — berita riset di landing page
`title`, `summary`, `body`, `image_path`, `image_mime`, `is_published`,
`published_at`, `sort_order`, `created_by`. `published_at` hanya diisi saat
pertama kali terbit.

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
| Sesi | Satu per akun; login mencabut token lain |
| Otorisasi | Middleware `role:admin`; selain itu tiap query di-scope ke `$request->user()` |
| Rate limit | Login 5 percobaan/menit/IP |
| Password | bcrypt, 12 rounds |
| Kepemilikan upload | Dipaksa lewat path storage — `upload_id` akun lain menghasilkan 404 |
| Integritas unduhan | `X-Checksum-MD5`, diverifikasi ulang di klien |
| Rahasia | `endpoint_url` model tidak pernah keluar ke non-admin |

Yang **belum** ada: HTTPS milik sendiri (masih menumpang ngrok), audit
dependensi, dan pembatasan ukuran storage per user.

---

## 6. Proses yang harus berjalan

Backend saja tidak cukup. Tiga proses terpisah:

| Proses | Tanpa itu |
|---|---|
| `npm run octane` | Tidak ada API sama sekali |
| `php artisan queue:work` | Upload berhasil tapi job selamanya `pending` |
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
| **Health check tiap 10 detik** | Vercel Cron minimum **1 menit** |
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

1. **CORS.** `config/cors.php` harus mengizinkan `https://brin.fajrianhost.my.id`.
   Sanctum di sini memakai bearer token, bukan cookie, jadi tidak ada urusan
   `SANCTUM_STATEFUL_DOMAINS` maupun domain cookie.
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
6. **Backup database.** Belum ada satu pun sekarang.


---

## 9. Rilis dan distribusi klien

`.github/workflows/release.yml` membangun ketiga target dan menerbitkannya.
Pemicunya tag versi:

```bash
git tag v1.2.0 && git push origin v1.2.0
```

| Job | Runner | Hasil |
|---|---|---|
| `test` | ubuntu | `flutter analyze` + `flutter test`; sisanya tidak jalan kalau ini merah |
| `web` | ubuntu | `brin-neutron-ct-web.zip` |
| `android` | ubuntu | `brin-neutron-ct.apk` |
| `ios` | **macos** | `brin-neutron-ct-ios-unsigned.ipa` |
| `publish` | ubuntu | GitHub Release + unggah ke Google Drive |

Alamat API dikompilasi masuk, jadi CI membacanya dari repository variable
`API_BASE_URL`.

### iOS tanpa punya Mac

iOS hanya bisa dibangun di macOS — itu batas Apple, bukan batas Flutter. Job
`ios` berjalan di runner macOS GitHub, jadi build iOS tetap dihasilkan tanpa
siapa pun memiliki Mac.

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
