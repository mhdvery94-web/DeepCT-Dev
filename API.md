# Referensi API

89 endpoint di bawah `/api`, plus `GET /api/health`. Daftar ini dibuat dari
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
| `POST` | `/messages/public` | Pesan dari halaman login. 5/jam/IP. |
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

**`POST /messages/public`** — body `name`, `email`, `body`. Untuk orang yang
**tidak bisa login**, yaitu alasan paling umum menekan tombol IT Support di
halaman itu. Pesannya masuk ke inbox admin yang sama dengan `user_id` null;
balasannya lewat email karena tidak ada akun untuk menampilkannya.

Percakapan tamu **tidak** ditempelkan ke akun yang emailnya kebetulan cocok —
email itu belum terverifikasi, jadi menempelkannya berarti siapa pun bisa
menaruh pesan di percakapan peneliti lain.

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

## Pesan ke admin — semua peran

| Method | Path | Keterangan |
|---|---|---|
| `GET` | `/messages` | Percakapan milik pemanggil, beserta isinya |
| `POST` | `/messages` | Kirim pesan; percakapan dibuat saat pertama kali |
| `POST` | `/messages/read` | Tandai balasan admin sudah dibaca |

**Ini menggantikan sistem tiket.** Tiket memaksa orang yang sedang bermasalah
mengklasifikasikan masalahnya dulu — pilih subjek, kategori, prioritas, lalu
pantau status — itu bentuk helpdesk yang di belakangnya ada satu departemen. Di
sini adminnya satu orang, dan yang orang butuhkan cuma bilang "ini rusak" lalu
dijawab. Jadi seremoninya dibuang; sisanya percakapan, satu per akun.

**Route peneliti tidak menerima id sama sekali.** Mereka cuma punya satu
percakapan, jadi "punya saya" adalah satu-satunya arti yang mungkin — dan itu
menghapus seluruh kelas bug "akun A membaca pesan akun B", karena tidak ada id
yang bisa diutak-atik.

**`POST /messages`** — body `body` (maks 5000 karakter). Balasannya pesan yang
baru dibuat.

```json
{ "id": 12, "body": "Frame preview kosong untuk job 12.",
  "from_admin": false, "author": "Dr. Sample Researcher",
  "author_avatar_url": "/users/2/avatar",
  "read_at": null, "created_at": "2026-08-15T14:02:00+00:00" }
```

`read_at` berarti "sudah dibaca pihak seberang". Tiap pesan cuma punya satu
pihak penerima, jadi satu kolom cukup untuk dua arah. **Membalas berarti
membaca**: begitu admin menjawab, tidak ada lagi yang menunggu dia di percakapan
itu.

Menulis lagi setelah percakapannya diarsipkan admin mengembalikannya ke inbox —
yang diarsipkan itu percakapan, bukan orangnya.

---

## Notifikasi — semua peran

| Method | Path | Keterangan |
|---|---|---|
| `GET` | `/notifications` | Milik pemanggil. `?unread=1` untuk yang belum dibaca. |
| `GET` | `/notifications/unread-count` | **Yang di-poll klien.** |
| `POST` | `/notifications/{id}/read` | Tandai satu |
| `POST` | `/notifications/read-all` | Tandai semua |
| `DELETE` | `/notifications/{id}` | Buang satu |
| `DELETE` | `/notifications` | Kosongkan daftar |

**`GET /notifications/unread-count`** mengembalikan **dua** angka sekaligus:

```json
{ "notifications": 3, "messages": 1 }
```

`messages` berarti balasan yang belum dibaca (untuk peneliti) atau percakapan
yang menunggu jawaban (untuk admin). Satu request memberi makan lonceng **dan**
penanda menu Messages; klien mem-poll ini tiap 45 detik. Soal kenapa polling,
bukan WebSocket, lihat ARCHITECTURE.md §4.

Isi satu notifikasi:

```json
{ "id": "9f1c-…", "type": "prediction.completed",
  "title": "Interpolation finished",
  "body": "3 frame(s) generated for frames.zip…",
  "link": "predictions/12", "meta": { "analysis_record_id": 12 },
  "read": false, "created_at": "2026-08-15T14:02:00+00:00" }
```

`link` ditulis dalam kosakata klien (`messages`, `predictions/12`,
`access-requests`, `models`, `dashboard`); shell yang menerjemahkannya jadi
navigasi. Klien juga harus tahan `type` yang belum dikenalnya — server boleh
menambah event tanpa menunggu rilis klien, jadi ikon dan warnanya punya
fallback.

**Apa yang dikirim, ke siapa** — semuanya di `app/Services/Notifier.php`:

| Event | Tujuan |
|---|---|
| `message.received` / `message.guest` | Semua admin aktif |
| `message.reply` | Peneliti yang bertanya |
| `prediction.completed` / `prediction.failed` | Pemilik job |
| `prediction.expiring` | Pemilik, ~3 jam sebelum berkasnya dihapus |
| `access_request.submitted` | Semua admin aktif |
| `account.approved` | Akun yang baru dibuat |
| `model.offline` / `model.online` | Semua admin aktif |

Semua di-scope lewat relasi `$request->user()->notifications()`, jadi **relasi
itulah otorisasinya** — id milik akun lain menjawab 404, bukan 403.

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

### Percakapan (6)

| Method | Path |
|---|---|
| `GET` | `/admin/conversations` — filter `archived`, `unread`, `search` |
| `GET` | `/admin/conversations/{id}` — satu percakapan berikut isinya |
| `POST` | `/admin/conversations/{id}/reply` — jawab |
| `POST` | `/admin/conversations/{id}/read` — tandai dibaca tanpa menjawab |
| `PATCH` | `/admin/conversations/{id}` — `is_archived` |
| `DELETE` | `/admin/conversations/{id}` — hapus beserta pesannya |

Daftarnya menyertakan `meta.unread_conversations` dan `meta.unread_messages`,
plus `preview` (baris pertama pesan terakhir) dan `last_from_admin` supaya
sekilas terlihat mana yang masih menunggu jawaban.

Percakapan tamu ditandai `is_guest: true` dengan `guest_email` terisi dan
`user: null`. Arsip **bukan** hapus: percakapan yang diarsipkan keluar dari
inbox tapi tetap ada, dan pesan baru dari orangnya menariknya kembali.

### Pelatihan model (11)

| Method | Path |
|---|---|
| `GET` | `/admin/training/datasets` |
| `POST` | `/admin/training/datasets` — multipart kalau ada arsipnya |
| `DELETE` | `/admin/training/datasets/{id}` — **409** kalau masih dipakai job |
| `GET` | `/admin/training/jobs` — filter `status` |
| `POST` | `/admin/training/jobs` |
| `GET` | `/admin/training/jobs/{id}` |
| `POST` | `/admin/training/jobs/{id}/dispatch` — dorong ke trainer |
| `POST` | `/admin/training/jobs/{id}/cancel` |
| `DELETE` | `/admin/training/jobs/{id}` |
| `GET` | `/admin/training/jobs/{id}/weights` |
| `POST` | `/admin/training/jobs/{id}/register-model` |

`meta.worker_configured` di daftar job memberitahu apakah `TRAINING_WORKER_TOKEN`
sudah diisi. Kalau `false`, tidak akan ada yang berjalan — itu hal pertama yang
perlu dicek saat job "diam saja".

**Dataset punya dua bentuk.** `source_type: upload` mengirim arsip lewat server
ini; `source_type: url` cuma mencatat alamat yang nanti diambil sendiri oleh
worker. Yang kedua itulah yang benar untuk dataset besar — mengirim 20 GB naik
ke server lalu turun lagi ke Kaggle memboroskan dua-duanya.

**`POST /admin/training/jobs/{id}/dispatch`** — mendorong job ke GPU, bentuknya
persis seperti prediksi didorong ke endpoint model. Body opsional
`trainer_url`; kalau kosong dipakai `TRAINING_TRAINER_URL`. URL yang terpakai
disimpan di baris job-nya.

Yang dikirim ke trainer: id job, epoch, hyperparameter, sumber dataset, **dan
`callback`** berisi `base_url` + `worker_token`. Tanpa dua yang terakhir,
trainer bisa melatih dengan sempurna lalu tidak punya tempat menaruh hasilnya.

| Kondisi | Hasil |
|---|---|
| Job bukan `queued` | **409** |
| Tidak ada trainer URL / worker token | **422** |
| Trainer menolak atau tidak terjangkau | **502**, job **tetap `queued`** |

Job **tetap `queued`** setelah berhasil dikirim. Trainer bilang ia *menerima*;
yang membuktikan ia *mulai* adalah heartbeat pertama. Menandainya `running` di
sini membuat job yang tidak pernah jalan terlihat sehat selamanya.

**`register-model` sengaja langkah terpisah.** Bobot itu berkas; "model" di
platform ini adalah worker FastAPI yang hidup dan punya URL. Tidak ada apa pun
di sini yang bisa men-deploy `.h5` ke GPU, jadi model baru dibuat dengan
`is_active: false` dan tanpa endpoint sampai ada yang men-deploy-nya.

### Pekerja GPU — token khusus, bukan token user

Enam route di bawah `/api/training/worker/*`, di luar `auth:sanctum`. Autentikasi
lewat `Authorization: Bearer {TRAINING_WORKER_TOKEN}` — worker itu mesin, bukan
orang: kredensialnya tinggal berminggu-minggu di notebook, tidak butuh akun, dan
tidak boleh menyentuh apa pun selain enam route ini.

| Method | Path | Untuk |
|---|---|---|
| `POST` | `/training/worker/claim` | Ambil job antrean tertua |
| `GET` | `/training/worker/jobs/{id}/dataset` | Unduh arsip dataset |
| `POST` | `/training/worker/jobs/{id}/heartbeat` | "Masih hidup" + epoch/metrik |
| `POST` | `/training/worker/jobs/{id}/checkpoint` | Bobot sementara |
| `POST` | `/training/worker/jobs/{id}/complete` | Bobot final |
| `POST` | `/training/worker/jobs/{id}/fail` | Melapor gagal |

Token kosong → **503** di semua route itu, bukan 401: deployment yang setengah
jadi harus menolak, bukan menerima siapa saja.

**Balasan heartbeat memuat `continue`.** Kalau admin membatalkan job,
`continue: false` — worker berhenti alih-alih membakar berjam-jam GPU untuk
pekerjaan yang tidak diinginkan siapa pun.

**Worker yang diam bukan worker yang gagal.** `training:reclaim` mengembalikan
job yang heartbeat-nya lewat 15 menit ke `queued` **beserta checkpoint-nya**, dan
`claim` berikutnya menerima `resume_from_epoch`. Sesi Kaggle mati tiap 9–12 jam
sementara training butuh berhari-hari; kalau tiap sesi mati berarti job gagal,
tidak akan pernah ada training yang selesai.

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
  -d "{\"email\":\"$EMAIL\",\"password\":\"$PASSWORD\"}" \
  | python -c "import sys,json;print(json.load(sys.stdin)['data']['token'])")

curl -s http://127.0.0.1:8000/api/me/stats \
  -H "Accept: application/json" -H "Authorization: Bearer $TOKEN"

curl -s -X POST http://127.0.0.1:8000/api/predictions \
  -H "Accept: application/json" -H "Authorization: Bearer $TOKEN" \
  -F "file=@frames.zip;type=application/zip" -F "model_id=1"
```

> Lewat ngrok, tambahkan `-H "ngrok-skip-browser-warning: true"`. Klien Flutter
> sudah mengirimnya otomatis.
