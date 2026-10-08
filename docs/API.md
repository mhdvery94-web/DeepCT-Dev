# Kontrak API

Base URL berakhiran `/api`. Sumber route otoritatif:
[`be/routes/api.php`](../be/routes/api.php). Endpoint LLM belum tersedia.

## Autentikasi dan respons

Login menghasilkan bearer token Sanctum, berlaku tujuh hari. Logout mencabut
token sesi tersebut. Route privat membutuhkan akun aktif dan password yang
sudah diganti; admin route juga memeriksa role. Next.js BFF menambahkan token
cookie di server dan menolak origin asing untuk mutation.

Respons umum: `{success, message?, data, pagination?}`.
Validasi menjawab 422 dengan `errors`; autentikasi 401; role/account 403;
resource tidak ditemukan 404; konflik pekerjaan aktif 409.
Collection umumnya menerima `page`, `per_page`, `search` dan filter status
sesuai controller. Jangan menyamakan semua collection/filter.

## Publik

| Metode | Path | Fungsi |
|---|---|---|
| GET | `/health` | Liveness API |
| POST | `/login` | Email/password, throttle 5/menit/IP |
| POST | `/access-requests` | first_name, last_name, email, institution, reason opsional |
| POST | `/messages/public` | Dukungan/reset request; throttle 5/10 menit |
| GET | `/news`, `/news/{id}` | Berita terbit dan isi artikel |
| GET | `/news/{id}/image`, `/news/{id}/video` | Media; draft hanya dapat diakses admin |
| GET | `/downloads/predictions/{id}/{kind}` | Unduhan signed results/complete |

Reset publik mengirim permintaan ke inbox administrator; penggantian password
tetap melalui verifikasi/admin dan kewajiban mengganti password terbitan.

## Akun yang login

| Metode | Path | Fungsi |
|---|---|---|
| GET/POST | `/user` (GET), `/logout` (POST) | Profil/sesi |
| GET | `/me/stats`, `/me/activities`, `/me/models` | Dashboard, audit dan model tersedia |
| POST | `/me/models/refresh` | Probe model; throttle 10/menit |
| POST | `/me/password` | Ganti password sendiri |
| POST/DELETE | `/me/avatar` | Foto sendiri |
| GET | `/users/{id}/avatar` | Foto akun, membutuhkan autentikasi |
| GET/POST | `/messages` | Thread dukungan milik sendiri |
| POST | `/messages/read` | Tandai balasan dibaca |
| GET | `/notifications`, `/notifications/unread-count` | Notifikasi sendiri |
| POST | `/notifications/read-all`, `/notifications/{id}/read` | Tandai dibaca |
| DELETE | `/notifications`, `/notifications/{id}` | Hapus notifikasi |

Model yang dilihat researcher tidak memuat worker URL atau kredensial.

## Prediksi

| Metode | Path | Fungsi |
|---|---|---|
| GET/POST | `/predictions` | Daftar sendiri/upload multipart |
| GET/DELETE | `/predictions/{id}` | Detail/hapus sesuai aturan lifecycle |
| POST | `/predictions/{id}/start` | Mulai setelah preview |
| POST | `/predictions/{id}/rerun` | Perbandingan menggunakan model_id lain |
| GET | `/predictions/{id}/frames` | Daftar frame |
| GET | `/predictions/{id}/frames/{name}/preview` | Preview aman |
| GET | `/predictions/{id}/evidence/{name}` | Evidence yang tetap tersimpan |
| GET | `/predictions/{id}/download-link` | Signed link, kind=results/complete |
| GET | `/predictions/{id}/download/results`, `/download/complete` dengan prefix ID yang sama | ZIP hasil/sequence lengkap |

Download besar di web diarahkan ke signed API URL lima menit untuk menghindari
batas respons Vercel. API memeriksa kepemilikan, status akun, expiry dan checksum.
Pending/processing dilindungi dari cleanup.

### Upload chunked

| Metode | Path | Fungsi |
|---|---|---|
| POST | `/predictions/uploads` | Buka sesi |
| GET/PATCH/DELETE | `/predictions/uploads/{uploadId}` | Offset/kirim chunk/batalkan |
| POST | `/predictions/uploads/{uploadId}/finalize` | Rakit dan validasi |

Body awal: `total_size`, `filename`, `purpose`.
Purpose default `prediction` wajib `model_id`; `news_video` hanya admin dan
wajib `news_post_id`. Purpose lain ditolak 422. Prediction maksimal 2 GiB;
video maksimal 50 MiB. PATCH multipart memuat `offset` dan `chunk`.
Server mengembalikan `upload_id`, `chunk_size`, `received`, `total_size`.
Gunakan chunk_size server; BFF web membatasi setiap potongan ke 3 MiB.
Client dapat melanjutkan dari offset server. Finalize prediksi tidak langsung
mengantrekan job; Start merupakan aksi tersendiri.

## Administrator: prefix /admin

| Resource | Metode/path relatif |
|---|---|
| Statistik | GET `/stats` |
| Akun | GET/POST `/users`; GET/PUT/DELETE `/users/{id}`; PATCH `/users/{id}/toggle`; POST `/users/{id}/reset-password` |
| Avatar akun | POST/DELETE `/users/{id}/avatar` |
| Model inference | GET/POST `/models`; GET/PUT/DELETE `/models/{id}`; PATCH `/models/{id}/toggle` |
| Katalog/probe | POST `/models/sync`, `/models/{id}/health-check`, `/models/{id}/test` |
| Access request | GET `/access-requests`; POST `/{id}/approve` atau `/{id}/reject` dengan prefix resource; DELETE `/{id}` |
| Berita | GET/POST `/news`; GET/POST/DELETE `/news/{id}`; PATCH `/news/{id}/toggle` |
| Dukungan | GET `/conversations`, `/conversations/{id}`; POST `/{id}/reply`, `/{id}/read`; PATCH/DELETE `/{id}` |
| Aktivitas | GET `/activities`, `/activities/types`, `/users/{id}/activities` |
| Antrean | GET `/queue` |
| Storage | GET `/storage`; POST `/storage/cleanup`; POST `/storage/predictions/{id}/cleanup` |

Model: name, version, endpoint_url, description, auth_token opsional,
verify_tls dan availability. Token write-only; menghilangkannya saat edit
mempertahankan secret. Tidak ada trainer registration.

Berita: title <=200, summary <=500, body <=20000, sort_order, is_published.
Gambar multipart JPEG/PNG/WebP, backend maksimal 4 MiB; picker web membatasi
3 MiB. POST update dipakai agar PHP membaca multipart. `remove_image=1` dan
`remove_video=1` menghapus media masing-masing tanpa mengubah media lain.
Video masuk lewat sesi chunked. Create/Edit article dan Manage media terpisah.

Route training/jobs/datasets/worker/signed weights tidak terdaftar dan
menjawab 404. Struktur database akhir tidak memiliki training tables/kind.
