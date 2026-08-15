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

13 tabel di `db_aict`. Yang relevan:

### `users`
`username`, `name`, `email`, `password`, `role` (enum admin/user), `is_active`,
`last_login_at`. Tidak ada registrasi mandiri — admin yang membuat akun.

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

### Kenapa polling, bukan WebSocket
Job berjalan puluhan detik sampai menit, dan hanya ada satu klien yang peduli.
Polling 10 detik yang berhenti sendiri saat semua job selesai jauh lebih murah
daripada memelihara infrastruktur realtime.

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
