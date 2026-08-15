# Referensi API

63 endpoint di bawah `/api`, plus `GET /api/health`. Daftar ini dibuat dari
`php artisan route:list --path=api` per 15 Agustus 2026 — jalankan perintah itu
kalau ragu, ia selalu lebih benar daripada dokumen.

**Base URL:** `http://127.0.0.1:8000/api` (atau domain ngrok yang mem-forward ke
sana).

**Autentikasi:** `Authorization: Bearer {token}` untuk semua kecuali `/login`
dan `/health`.

**Bentuk balasan** selalu sama:

```json
{ "success": true, "message": "…", "data": {} }
```

Endpoint berpaginasi menambahkan blok `pagination` berisi `total`, `per_page`,
`current_page`, `last_page`, `from`, `to`.

**Kode status:** 200 sukses · 201 dibuat · 400 permintaan salah · 401 belum
login · 403 bukan haknya · 404 tidak ada · 409 konflik · 410 sudah kedaluwarsa ·
422 validasi gagal · 429 terlalu sering · 503 model tidak tersedia.

---

## Publik

| Method | Path | Keterangan |
|---|---|---|
| `GET` | `/health` | Liveness probe. Didefinisikan di `routes/web.php`, bukan `api.php`. |
| `POST` | `/login` | Dibatasi 5 percobaan/menit/IP. |
| `POST` | `/access-requests` | Formulir Join di landing page. 5/menit/IP. |
| `POST` | `/support/tickets/public` | Tiket dari halaman login. 5/jam/IP. |
| `GET` | `/news` | Berita riset yang sudah terbit, urut slide. |
| `GET` | `/news/{id}/image` | Fotonya. **404 untuk draf**, kecuali pemanggilnya admin. |

**`POST /login`** — body `{ "email", "password" }`.

```json
{ "success": true, "data": { "user": { … }, "token": "64|abc…" } }
```

**Beberapa sesi sekaligus diizinkan.** Tiap login menerbitkan token sendiri dan
tidak mengganggu token lain, jadi satu akun bisa aktif di laptop dan HP
bersamaan. `POST /logout` hanya mencabut token yang dipakai request itu.

Token berlaku **7 hari** (`config/sanctum.php`), dan `tokens:cleanup`
membersihkan baris yang kedaluwarsa setiap hari.

Akun nonaktif ditolak dengan pesan tersendiri, bukan "kredensial salah", supaya
peneliti tahu harus menghubungi admin.

**`POST /access-requests`** — body `first_name`, `last_name`, `email`,
`institution`, `reason` (opsional). **409** kalau emailnya sudah punya akun atau
sudah ada permintaan yang menunggu; pesannya ditulis untuk pemohon, jadi
tampilkan apa adanya.

**`POST /support/tickets/public`** — body `name`, `email`, `subject`,
`message`, `category` (opsional). Untuk orang yang **tidak bisa login**, yaitu
alasan paling umum menekan tombol IT Support di halaman itu. Tiketnya masuk
antrean admin yang sama dengan `user_id` null; balasannya lewat email karena
tidak ada akun untuk menampilkannya.

Tiket tamu **tidak** ditempelkan ke akun yang emailnya kebetulan cocok — email
itu belum terverifikasi, jadi menempelkannya berarti siapa pun bisa menaruh
pesan di daftar tiket peneliti lain.

**`GET /news`** — parameter opsional `limit` (1–50, default 20). Tidak
berpaginasi: landing page menampilkan semuanya dalam satu carousel.

```json
{ "id": 1, "title": "…", "summary": "…", "body": "…",
  "has_image": true, "image_url": "/news/1/image",
  "published_at": "2026-08-15T12:32:34+00:00", "sort_order": 1 }
```

`image_url` **relatif** terhadap root API; klien menambahkan base URL-nya
sendiri. API ini dijangkau lewat ngrok, localhost, dan alamat LAN — URL absolut
dari server akan salah di dua di antaranya.

Urutan slide: `sort_order` menaik, lalu `published_at` menurun.

**`GET /news/{id}/image`** — foto apa adanya beserta mime type aslinya.
Draf **404** kecuali request-nya membawa token admin, jadi hasil riset yang
belum diumumkan tidak bisa ditemukan dengan menebak id.

---

## Terautentikasi — semua peran

| Method | Path | Keterangan |
|---|---|---|
| `POST` | `/logout` | Mencabut token yang sedang dipakai |
| `GET` | `/user` | Profil pemanggil |
| `GET` | `/me/stats` | Penghitung untuk dashboard peneliti |
| `GET` | `/me/activities` | Jejak audit milik sendiri, berpaginasi |
| `GET` | `/me/models` | Model yang boleh dipakai |
| `POST` | `/me/avatar` | Pasang foto profil sendiri (multipart `avatar`) |
| `DELETE` | `/me/avatar` | Hapus foto profil sendiri |
| `GET` | `/users/{id}/avatar` | Foto profil siapa pun. **Butuh login.** |

Ketiganya di-scope server ke `$request->user()`. Tidak ada parameter id, jadi
tidak ada jalan membaca data akun lain.

**`GET /me/stats`**

```json
{ "activities_total": 25, "activities_today": 10,
  "analyses_total": 0,
  "analyses_by_status": { "pending":0, "processing":0, "completed":0, "failed":0 },
  "models_online": 1, "models_total": 1 }
```

**`GET /me/models`** mengembalikan `id`, `name`, `version`, `status`,
`description`, `accuracy`, `is_available`. **Tidak pernah `endpoint_url`** —
lihat ARCHITECTURE.md §3.

### Foto profil

Setiap payload yang memuat user sekarang membawa `avatar_url` — relatif
terhadap root API, dan **null kalau belum ada foto**. Itulah yang memberi tahu
klien untuk menggambar bingkai inisial. `avatar_path` dan `avatar_mime`
disembunyikan; letak berkas di disk bukan urusan klien.

`POST /me/avatar` menerima JPEG/PNG/WebP maksimal **2 MB**, divalidasi dengan
`mimetypes:` (membaca isi berkas). Unggahan baru menghapus berkas lama.

`GET /users/{id}/avatar` **butuh login** (401 kalau anonim). Avatar muncul di
sebelah log aktivitas dan daftar user, jadi tiap akun yang sudah masuk perlu
bisa memuatnya — tapi pengunjung anonim tidak boleh memanen foto staf peneliti
dengan menelusuri id. Akun tanpa foto menjawab **404**, bukan gambar bawaan:
klien yang menggambar bingkainya, dan placeholder dari server cuma jadi
pendapat kedua soal seperti apa "tidak ada foto" itu.

Admin bisa mengubah/menghapus foto akun lain lewat
`/admin/users/{id}/avatar` — harus ada yang bisa menurunkan foto yang tidak
pantas dari akun orang lain.

---

## Tiket dukungan — semua peran

| Method | Path | Keterangan |
|---|---|---|
| `GET` | `/support/tickets` | Tiket milik pemanggil. Filter opsional `status`. |
| `POST` | `/support/tickets` | Buat tiket |
| `GET` | `/support/tickets/{id}` | Detail berikut percakapannya |
| `POST` | `/support/tickets/{id}/reply` | Balas — dipakai kedua pihak |

Dibuat sebagai **percakapan**, bukan satu pesan: masalah teknis hampir selalu
butuh pertanyaan balik.

**`POST /support/tickets`** — body `subject`, `message`, `category`
(`upload`/`prediction`/`download`/`account`/`other`), `priority`
(`low`/`normal`/`high`), dan `analysis_record_id` opsional. Job yang bukan milik
pemanggil **diabaikan diam-diam**, bukan ditolak — kalau ditolak, tiket bisa
dipakai menebak id job mana yang ada.

**`awaiting_admin`** mencatat giliran siapa sekarang, dan itulah yang menyalakan
penanda di sidebar admin. Pesan peneliti menyalakannya; balasan admin
memadamkannya sekaligus memindahkan tiket `open` → `in_progress`.

| Kondisi | Hasil |
|---|---|
| Balas tiket `resolved` | Terbuka lagi (`in_progress`) |
| Balas tiket `closed` | **409** — buat tiket baru |
| Tiket milik akun lain | **404**, bukan 403 (403 membocorkan bahwa id-nya ada) |

---

## Prediksi — semua peran

Tiap aksi di-scope ke pemanggil di dalam `AnalysisController`.

| Method | Path | Keterangan |
|---|---|---|
| `GET` | `/predictions` | Daftar job sendiri. Filter opsional `status`. |
| `POST` | `/predictions` | Unggah arsip dalam satu request |
| `GET` | `/predictions/{id}` | Detail; memuat posisi antrean saat masih pending |
| `DELETE` | `/predictions/{id}` | Hapus job beserta berkasnya |
| `GET` | `/predictions/{id}/frames` | Daftar frame di disk (input + output) |
| `GET` | `/predictions/{id}/frames/{name}/preview` | Frame itu sebagai PNG |
| `GET` | `/predictions/{id}/download/results` | ZIP berisi frame hasil saja |
| `GET` | `/predictions/{id}/download/complete` | ZIP berisi `input/`, `output/`, `metadata.json` |

### Syarat arsip

Ditolak lebih awal kalau tidak memenuhi:

- Berformat `.zip`, isinya `.tif` / `.tiff`
- Minimal dua frame
- Nama berkas memuat nomor frame (`frame_001.tif`)
- **Ada celah di antara nomornya** — `001` dan `005` menghasilkan 002, 003, 004.
  Frame berurutan ditolak: tidak ada yang perlu diinterpolasi.
- Maksimal 50 MB per frame, dan maksimal 200 frame yang dihasilkan per job

Entri di dalam subfolder tetap terbaca — ekstraksi meratakannya.

**`POST /predictions`** — multipart `file` + `model_id`. Balasan 201:

```json
{ "id": 6, "job_id": "6c07cb2a-…", "status": "pending",
  "input_files_count": 2, "queue_position": 1,
  "estimated_wait_minutes": 5, "expires_at": "2026-08-16T04:41:29+00:00" }
```

### Pratinjau frame

Frame di disk berupa **TIFF 16-bit**, yang tidak bisa dirender browser maupun
Flutter. `preview` mengubahnya jadi PNG grayscale 8-bit di server.

`GET /predictions/{id}/frames` mengembalikan `name`, `kind` (`input`/`output`),
dan `size`.

`GET /predictions/{id}/frames/{name}/preview?size=512` mengembalikan PNG.
`size` adalah sisi terpanjang (64–2048, default 512); aspek rasio dipertahankan
dan frame kecil tidak diperbesar.

- Hasil di-cache di samping job, jadi ikut terhapus oleh `predictions:cleanup`.
  Render pertama ~0,5 detik untuk frame 1024×1024; berikutnya ~0,07 detik.
- Konversi 16→8 bit **di-window ke min/max frame itu sendiri**, bukan sekadar
  membuang byte bawah — frame CT jarang memakai seluruh rentang 16-bit, dan
  pergeseran naif membuatnya tampak hitam pekat.
- Hanya menerima TIFF **tanpa kompresi, satu kanal**. Selain itu ditolak
  **422** dengan alasannya, bukan gambar rusak.
- Frame tidak ditemukan → **404**; berkas sudah kedaluwarsa → **410**.

### Unduhan

Keduanya membawa `X-Checksum-MD5` dan `Accept-Ranges: bytes`, jadi unduhan yang
terputus bisa dilanjutkan. Klien Flutter menghitung ulang MD5-nya dan
memperingatkan kalau tidak cocok.

- Job belum selesai → **400**
- Berkas sudah lewat 24 jam → **410**, dan `show()` melaporkan
  `files_available: false`

---

## Chunked upload — semua peran

Untuk arsip besar. Lihat ARCHITECTURE.md §4 soal alasannya.

| Method | Path | Keterangan |
|---|---|---|
| `POST` | `/predictions/uploads` | Buka sesi |
| `GET` | `/predictions/uploads/{uploadId}` | Berapa byte yang sudah masuk |
| `PATCH` | `/predictions/uploads/{uploadId}` | Kirim satu potongan |
| `POST` | `/predictions/uploads/{uploadId}/finalize` | Rakit dan antrekan job |
| `DELETE` | `/predictions/uploads/{uploadId}` | Batalkan |

**Buka sesi** — body `model_id`, `total_size`, `filename` (opsional):

```json
{ "upload_id": "ecda037c-…", "chunk_size": 1677721,
  "received": 0, "total_size": 4194750 }
```

`chunk_size` **dihitung server** dari batas PHP-nya sendiri. Pakai angka yang
diberikan, jangan hard-code.

**Kirim potongan** — multipart `offset` + `chunk`. Perilaku:

| Kondisi | Hasil |
|---|---|
| `offset` sesuai harapan | 200, melaporkan `received` |
| `offset` lebih kecil (kirim ulang) | 200, idempotent — tidak ditulis dua kali |
| `offset` melompat | **409** dengan offset yang seharusnya |
| Melebihi `total_size` | 422 |
| `upload_id` milik akun lain | **404** |

**Finalize** gagal dengan **409** kalau byte yang masuk belum lengkap.

---

## Admin — butuh `role:admin`

Peneliti yang memanggil salah satunya mendapat **403**.

### User (7)

| Method | Path |
|---|---|
| `GET` | `/admin/users` — filter `search`, `role`, `status` |
| `POST` | `/admin/users` |
| `GET` | `/admin/users/{id}` |
| `PUT` | `/admin/users/{id}` — hanya name, username, email, role |
| `DELETE` | `/admin/users/{id}` |
| `PATCH` | `/admin/users/{id}/toggle` |
| `POST` | `/admin/users/{id}/reset-password` |

Password default `BrinResearch2026` dikembalikan sebagai `default_password`.
Admin tidak bisa menghapus atau menonaktifkan akunnya sendiri (403).

Ditambah dua route foto: `POST` dan `DELETE /admin/users/{id}/avatar`.

### Model (8)

| Method | Path |
|---|---|
| `GET` | `/admin/models` — filter `status` |
| `POST` | `/admin/models` — langsung health check setelah dibuat |
| `GET` | `/admin/models/{id}` |
| `PUT` | `/admin/models/{id}` — partial |
| `DELETE` | `/admin/models/{id}` — 403 kalau masih ada job berjalan |
| `PATCH` | `/admin/models/{id}/toggle` |
| `POST` | `/admin/models/{id}/health-check` |
| `POST` | `/admin/models/{id}/test` |

`test` menjalankan **inferensi sungguhan** dengan frame contoh yang dibuat
sendiri. Nyata memakan waktu ~18–21 detik dan memakai kuota GPU.

Health check: `online` bila terjangkau, `trouble` bila > 5 detik, `offline`
bila gagal atau tunnel mati (`ERR_NGROK_3200`).

### Permintaan akses (4)

| Method | Path |
|---|---|
| `GET` | `/admin/access-requests` — filter `status` |
| `POST` | `/admin/access-requests/{id}/approve` |
| `POST` | `/admin/access-requests/{id}/reject` — body `note` opsional |
| `DELETE` | `/admin/access-requests/{id}` |

`approve` **langsung membuat akun user-nya** dan mengembalikan `username` +
`default_password` sekali. Kalau tidak, admin tetap harus membuat user manual
dan permintaan itu jadi catatan mati.

### Berita riset (6)

| Method | Path |
|---|---|
| `GET` | `/admin/news` — filter `status` (`published`/`draft`), `search` |
| `POST` | `/admin/news` — **multipart**, boleh membawa `image` |
| `GET` | `/admin/news/{id}` |
| `POST` | `/admin/news/{id}` — ubah; kirim `remove_image=1` untuk menghapus foto |
| `PATCH` | `/admin/news/{id}/toggle` — sakelar terbit |
| `DELETE` | `/admin/news/{id}` — beserta fotonya |

Field: `title` (≤200), `summary` (≤500), `body` (opsional, ≤20000),
`sort_order`, `is_published`, `image`.

**Ubah memakai POST, bukan PUT.** Foto datang sebagai multipart dan PHP tidak
mengisi `$_FILES` untuk body PUT, jadi route PUT tidak akan pernah menerimanya.

**Gambar disimpan apa adanya** — mesin ini tidak punya GD maupun Imagick, jadi
tidak ada yang bisa memperkecil atau menyandikan ulang unggahan. Pertahanannya
cuma batas 4 MB dan aturan `mimetypes:` (JPEG/PNG/WebP), yang membaca isi
berkas, bukan ekstensinya.

**Menyimpan bukan menerbitkan.** `published_at` hanya diisi saat pertama kali
terbit, jadi menyembunyikan lalu menampilkan lagi post lama tidak melemparkannya
ke depan slideshow yang diurut tanggal.

### Tiket dukungan (3)

| Method | Path |
|---|---|
| `GET` | `/admin/support/tickets` — filter `status`, `awaiting`, `search` |
| `PATCH` | `/admin/support/tickets/{id}` — `status` dan/atau `priority` |
| `DELETE` | `/admin/support/tickets/{id}` |

Daftar admin menyertakan `meta.open_count` dan `meta.awaiting_admin_count` untuk
penanda di sidebar. Tiket tamu ditandai `is_guest: true` dengan blok `guest`
berisi nama dan email pelapor, dan `user: null`.

Menandai `resolved`/`closed` mengisi `resolved_at` + `resolved_by` dan mematikan
`awaiting_admin`. Balasan admin dipakai `POST /support/tickets/{id}/reply` yang
sama — controller-nya yang menentukan sisi mana yang menulis.

### Activity log (3)

| Method | Path |
|---|---|
| `GET` | `/admin/activities` — filter `user_id`, `type`, `date_from`, `date_to` |
| `GET` | `/admin/activities/types` |
| `GET` | `/admin/users/{id}/activities` |

---

## Contoh

```bash
TOKEN=$(curl -s -X POST http://127.0.0.1:8000/api/login \
  -H "Content-Type: application/json" -H "Accept: application/json" \
  -d '{"email":"researcher@brin.go.id","password":"user123"}' \
  | python -c "import sys,json;print(json.load(sys.stdin)['data']['token'])")

curl -s http://127.0.0.1:8000/api/me/stats \
  -H "Accept: application/json" -H "Authorization: Bearer $TOKEN"

curl -s -X POST http://127.0.0.1:8000/api/predictions \
  -H "Accept: application/json" -H "Authorization: Bearer $TOKEN" \
  -F "file=@frames.zip;type=application/zip" -F "model_id=1"
```

> Lewat ngrok, tambahkan `-H "ngrok-skip-browser-warning: true"`. Klien Flutter
> sudah mengirimnya otomatis.
