# Referensi API

104 route di bawah `/api`, **termasuk** `GET /api/health`. Dihitung dari
`php artisan route:list --path=api` per 28 September 2026 — jalankan perintah itu
kalau ragu, ia selalu lebih benar daripada dokumen.

**Base URL:** `http://127.0.0.1:8000/api` (atau domain ngrok yang mem-forward ke
sana).

**Autentikasi:** `Authorization: Bearer {token}` untuk route akun. `/login`,
`/health`, `/access-requests`, `/messages/public`, dan berita terbit adalah
publik; `/training/worker/*` memakai token worker tersendiri. Akun nonaktif
ditolak pada setiap request. Akun yang wajib mengganti password hanya dapat
mengakses `/user`, `/me/password`, dan `/logout` sampai password diubah.

**Bentuk balasan** selalu sama:

```json
{ "success": true, "message": "…", "data": {} }
```

Endpoint berpaginasi menambahkan blok `pagination` berisi `total`, `per_page`,
`current_page`, `last_page`, `from`, `to`.

**Kode status:** 200 sukses · 201 dibuat · 400 permintaan salah · 401 belum
login · 403 bukan haknya · 404 tidak ada · 409 konflik · 410 sudah kedaluwarsa ·
422 validasi gagal · 429 terlalu sering · 503 model tidak tersedia ·
507 ruang penyimpanan tidak cukup.

---

## Publik

| Method | Path | Keterangan |
|---|---|---|
| `GET` | `/health` | Liveness probe. Didefinisikan di `routes/web.php`, bukan `api.php`. |
| `POST` | `/login` | Dibatasi 5 percobaan/menit/IP. |
| `POST` | `/access-requests` | Formulir Join di landing page. 5/menit/IP. |
| `POST` | `/messages/public` | Pesan dari halaman login. 5/10 menit/IP. |
| `GET` | `/news` | Berita riset yang sudah terbit, urut slide. |
| `GET` | `/news/{id}/image` | Fotonya. **404 untuk draf**, kecuali pemanggilnya admin. |
| `GET` | `/news/{id}/video` | Videonya. Aturan yang sama. Menjawab Range, jadi bisa digeser. |

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
  "has_video": true, "video_url": "/news/1/video", "video_size_bytes": 12582912,
  "published_at": "2026-08-15T12:32:34+00:00", "sort_order": 1 }
```

`image_url` **relatif** terhadap root API; klien menambahkan base URL-nya
sendiri. API ini dijangkau lewat ngrok, localhost, dan alamat LAN — URL absolut
dari server akan salah di dua di antaranya.

Urutan slide: `sort_order` menaik, lalu `published_at` menurun.

**`GET /news/{id}/image`** — foto apa adanya beserta mime type aslinya.

### Training: melihat dataset sebelum melatihnya

| Metode | Rute | Untuk apa |
|---|---|---|
| `GET` | `/me/training/jobs/{id}/dataset/frames` | Nama entri `.tif` di dalam arsip, terurut |
| `GET` | `/me/training/jobs/{id}/dataset/frames/{name}/preview` | Entri itu, dirender jadi PNG |

**Arsipnya tidak pernah diekstrak.** Sebuah dataset adalah hal terbesar yang
disimpan platform ini, dan menggandakannya di disk hanya untuk dilihat akan
absurd. `ZipArchive` membaca direktori pusat di akhir berkas, jadi mendaftar
isinya berbiaya sebanyak jumlah entri dan bukan ukurannya; `getFromName()`
menarik satu entri saat sebuah frame benar-benar diminta.

**Nama entri divalidasi terhadap daftar isi arsip**, bukan sekadar
di-`basename()`. Sebuah nama yang lolos ke `getFromName()` tanpa diperiksa akan
membaca apa pun yang ditunjuknya.

**Placeholder `{name}` sengaja dilepas dari batas segmennya** dengan
`->where('name', '.*')`. Frame di dalam arsip lazimnya berada di dalam subfolder
— `Sample Contrast/0001.tif` — dan sebuah placeholder Laravel yang normal tidak
merentang garis miring, sehingga nama seperti itu **tidak cocok dengan rute mana
pun** dan dijawab 404 tanpa satu pun petunjuk bahwa yang bermasalah adalah
routing, bukan arsipnya. Daftar frame mengembalikan nama entri lengkap, jadi
klien cukup mengirim balik persis apa yang ia terima.

**Daftar kosong punya dua arti, dan respons ini membedakannya.** Arsip yang
sudah disapu `training:cleanup` membuat daftar frame mengembalikan koleksi
kosong — terbaca sama persis dengan arsip yang memang tidak berisi `.tif`.
Karena itu daftarnya membawa `meta`:

```json
{ "success": true, "data": [],
  "meta": { "archive_deleted": true,
            "archive_deleted_at": "2026-09-03T03:10:00+07:00" } }
```

Angka hasil latihnya masih ada; frame di baliknya tidak. Jendela retensinya
dijelaskan di [be/README.md](be/README.md).

Hasil render di-cache di samping dataset-nya, sama seperti preview frame
prediksi, sehingga menggeser bolak-balik tidak membuka ulang ZIP setiap kali.

### Training: sampel per epoch

| Metode | Rute | Untuk apa |
|---|---|---|
| `POST` | `/training/worker/jobs/{id}/sample` | Worker mengirim satu PNG untuk sebuah epoch |
| `GET` | `/me/training/jobs/{id}/samples` | Epoch mana saja yang punya gambar |
| `GET` | `/me/training/jobs/{id}/samples/{epoch}` | PNG-nya |

Yang pertama berada di grup `training.worker`, di luar `auth:sanctum`, dengan
header `X-Worker-Token`. Batasnya 4 MB per sampel. Mengirim ulang sebuah epoch
**menimpa** yang lama beserta berkasnya — worker yang mengulang setelah
kehilangan sesi Kaggle adalah keadaan normal di sini, bukan pengecualian.

Dua sisanya dibatasi pemilik job dan menjawab 404 untuk orang lain.

**`POST /admin/training/jobs/{id}/dispatch` sudah tidak ada.** Ia lahir ketika
admin yang memulai run; sekarang periset yang memulai, dan job antre diklaim
worker lewat `POST /training/worker/claim`. Dua jalur menuju hal yang sama yang
bedanya cuma siapa yang menekan bukanlah pengawasan.

**`GET /news/{id}/video`** — video apa adanya, MP4 atau WebM. Dilayani
`BinaryFileResponse`, yang menjawab `Range` sendiri: sebuah permintaan
`Range: bytes=0-99` dijawab `206` dengan `Content-Range`, dan itulah yang
membuat pemutar bisa menggeser tanpa mengunduh seluruh berkas.

Mengunggahnya **bukan** lewat endpoint ini melainkan lewat
`POST /predictions/uploads` dengan `purpose: news_video` dan
`news_post_id`. Rutenya terbuka untuk setiap pengguna terautentikasi —
mengunggah prediksi memang pekerjaan periset — tetapi tujuan `news_video`
khusus admin, dan ditolak 403 untuk yang lain baik saat `start` maupun
saat `finalize`. Batasnya 50 MB, diperiksa sebelum satu byte pun dikirim,
dan tipe berkasnya dibaca dari byte hasil rakitan, bukan dari namanya.
Draf **404** kecuali request-nya membawa token admin yang akunnya masih aktif
dan sudah mengganti password awal. Hasil riset yang belum diumumkan tidak bisa
ditemukan dengan menebak id atau memakai sesi akun yang dinonaktifkan.

---

## Terautentikasi — semua peran

| Method | Path | Keterangan |
|---|---|---|
| `POST` | `/logout` | Mencabut token yang sedang dipakai |
| `GET` | `/user` | Profil pemanggil |
| `GET` | `/me/stats` | Penghitung untuk dashboard peneliti |
| `GET` | `/me/activities` | Jejak audit milik sendiri, berpaginasi |
| `GET` | `/me/models` | Model yang boleh dipakai |
| `POST` | `/me/models/refresh` | Sama, tapi **memprobe endpoint-nya dulu**. Throttle 10/menit |
| `GET` | `/me/training/jobs` | Training run milik sendiri |
| `POST` | `/me/training/jobs` | Mulai training — multipart `archive` (ZIP), `name`, `total_epochs`. Untuk berkas besar pakai jalur chunked di bawah |
| `GET` | `/me/training/jobs/{id}` | Detail + **riwayat metrik per epoch** |
| `POST` | `/me/training/jobs/{id}/cancel` | Batalkan run sendiri |
| `POST` | `/me/avatar` | Pasang foto profil sendiri (multipart `avatar`) |
| `DELETE` | `/me/avatar` | Hapus foto profil sendiri |
| `GET` | `/users/{id}/avatar` | Foto profil siapa pun. **Butuh login.** |

Ketiganya di-scope server ke `$request->user()`. Tidak ada parameter id, jadi
tidak ada jalan membaca data akun lain.

**`GET /me/stats`**

```json
{ "activities_total": 25, "activities_today": 10,
  "analyses_total": 0,
  "analyses_by_status": { "uploaded":0, "pending":0, "processing":0, "completed":0, "failed":0 },
  "models_online": 1, "models_total": 1 }
```

**`GET /me/models`** mengembalikan `id`, `name`, `version`, `status`,
`description`, `accuracy`, `is_available`. **Tidak pernah `endpoint_url`** —
lihat ARCHITECTURE.md §3.

**Dataset besar naik lewat sesi chunked yang sama dengan unggahan prediksi**,
bukan lewat `POST /me/training/jobs`: `POST /predictions/uploads` dengan
`purpose: training`, `name`, dan `total_epochs`, lalu potongan-potongannya,
lalu `finalize` — yang mengembalikan run yang sudah diantrekan alih-alih
prediksi. Multipart sekali-kirim di atas hanya masuk akal untuk dataset kecil.

**`POST /me/models/refresh`** mengembalikan payload yang sama persis, tapi
memprobe endpoint-nya lebih dulu alih-alih membaca hasil terakhir scheduler.
Ini satu-satunya route di mana pengguna biasa memicu request keluar, jadi ada
tiga pagar: throttle 10/menit, kunci `models:probe` supaya dua penekanan
bersamaan tidak jadi dua probe, dan status yang lebih muda dari **10 detik**
dikembalikan apa adanya. Karena ia menunggu jaringan, responsnya bisa memakan
beberapa detik saat tunnel mati — itu jawaban jujur, bukan endpoint yang lambat.

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
| `POST` | `/predictions` | Unggah arsip dalam satu request. **Tidak mengantrekan apa pun** |
| `POST` | `/predictions/{id}/start` | Antrekan unggahan yang menunggu |

**Unggah dan analisis adalah dua permintaan.** Sejak 23 Agustus 2026, unggah —
lewat `POST /predictions` maupun lewat sesi berpotongan — meninggalkan record
berstatus **`uploaded`** dan tidak mengantrekan apa pun. Frame-nya sudah bisa
dibaca lewat `GET /predictions/{id}/frames`, sehingga periset dapat melihat dan
menggesernya sebelum sebuah slot GPU dipakai.

`POST /predictions/{id}/start` yang memindahkannya ke `pending` dan
mengantrekan pekerjaannya. Ia menjawab:

- **200** dengan `{id, status, queue_position}` bila berhasil;
- **409** bila statusnya sudah lewat `uploaded` — ketukan ganda di ponsel tidak
  boleh menempatkan dua worker pada satu job, yang akan saling menimpa folder
  output yang sama;
- **404** bila record itu milik akun lain, bentuk yang sama dengan seluruh rute
  prediksi lain: keberadaannya pun bukan urusan mereka;
- **410** bila berkasnya sudah kedaluwarsa dan dihapus.
| `GET` | `/predictions/{id}` | Detail; memuat posisi antrean saat masih pending |
| `DELETE` | `/predictions/{id}` | Hapus job beserta berkasnya |
| `GET` | `/predictions/{id}/frames` | Daftar frame di disk (input + output) |
| `GET` | `/predictions/{id}/frames/{name}/preview` | Frame itu sebagai PNG |
| `GET` | `/predictions/{id}/download/results` | ZIP berisi frame hasil saja |
| `GET` | `/predictions/{id}/download/complete` | ZIP berisi `input/`, `output/`, `metadata.json`, `manifest.csv` |

### Syarat arsip

Ditolak lebih awal kalau tidak memenuhi:

- Berformat `.zip`, isinya `.tif` / `.tiff`
- Minimal dua frame
- Nama berkas memuat nomor frame (`frame_001.tif`)
- **Ada celah di antara nomornya** — `001` dan `005` menghasilkan 002, 003, 004.
  Frame berurutan ditolak: tidak ada yang perlu diinterpolasi.
- Maksimal 50 MB per frame, 1000 frame input, 2 GB total TIFF setelah
  diekstrak, dan maksimal 200 frame yang dihasilkan per job
- Nama frame harus unik setelah folder di dalam ZIP diratakan, tanpa membedakan
  huruf besar/kecil

Entri di dalam subfolder tetap terbaca — ekstraksi meratakannya.

**`POST /predictions`** — multipart `file` + `model_id`. Balasan 201:

```json
{ "id": 6, "job_id": "6c07cb2a-…", "status": "uploaded",
  "input_files_count": 2, "queue_position": null,
  "estimated_wait_minutes": null, "expires_at": "2026-08-16T04:41:29+00:00" }
```

`status` adalah status rekaman yang sebenarnya, dan unggahan mendarat sebagai
`uploaded` — berkasnya ada, tetapi belum ada yang menekan START. Endpoint ini
sempat menuliskan `"pending"` secara harfiah beserta posisi antrean, yaitu
mengumumkan tempat dalam barisan yang belum dimasuki job tersebut.

`queue_position` dan `estimated_wait_minutes` karenanya `null` sampai
`POST /predictions/{id}/start` dijalankan; keduanya `int?` di setiap
pembacanya.

### Pratinjau frame

Frame di disk berupa **TIFF 16-bit**, yang tidak bisa dirender browser maupun
Flutter. `preview` mengubahnya jadi PNG grayscale 8-bit di server.

`GET /predictions/{id}/frames` mengembalikan `name`, `kind` (`input`/`output`),
dan `size`.

#### Asal-usul tiap frame buatan

`GET /predictions/{id}` menyertakan **`frame_provenance`**, yang menjawab
pertanyaan yang tidak bisa dijawab `interpolated_frames`: frame ini digambar di
antara frame yang mana, dan sudah berapa kali model diberi makan keluarannya
sendiri sebelum sampai ke sini.

```json
"frame_provenance": [
  { "frame": "frame_002.tif", "index": 2, "from": [1, 3],
    "generation": 2, "synthetic_parents": 1 },
  { "frame": "frame_003.tif", "index": 3, "from": [1, 5],
    "generation": 1, "synthetic_parents": 0 },
  { "frame": "frame_004.tif", "index": 4, "from": [3, 5],
    "generation": 2, "synthetic_parents": 1 }
]
```

Bacalah contoh itu dari celah antara frame 001 dan 005. Titik tengahnya, 003,
digambar lebih dulu dari dua frame yang **keduanya hasil pindai** —
`generation: 1`. Baru sesudahnya 002 dan 004 digambar, masing-masing memakai
003 sebagai salah satu batasnya: model sedang diberi keluarannya sendiri, jadi
`generation: 2` dengan `synthetic_parents: 1`.

- `generation` — 1 berarti kedua batasnya hasil pindai; lebih besar berarti
  galat sudah berpeluang menumpuk sebanyak itu kali.
- `synthetic_parents` — berapa dari dua batasnya yang dikarang model (0, 1 atau
  2). Sudah tersirat dari `generation`, tetapi pembaca tabel tidak seharusnya
  perlu menurunkannya sendiri.

**Bisa `null`.** Job yang selesai sebelum kolom ini ada tidak memilikinya, jadi
klien wajib memperlakukannya sebagai opsional alih-alih menganggapnya pasti ada
begitu job selesai.

Array yang sama ikut ditulis ke `metadata.json` di dalam
`GET /predictions/{id}/download/complete` — enam bulan lagi arsip itu mungkin
satu-satunya yang tersisa, dan satu folder berisi TIFF tidak bisa menyebut mana
yang keluar dari pemindai dan mana yang digambar model.

#### Seberapa bagus hasilnya

`GET /predictions/{id}` menyertakan **`validation`**, hasil pemeriksaan
*hold-out*. Frame yang ingin diisi seorang peneliti menurut definisinya tidak
dimiliki siapa pun, jadi yang diukur adalah frame yang **memang ada**: di mana
pun arsip memuat tiga frame berurutan, yang tengah disisihkan, digambar ulang
dari kedua tetangganya, lalu dibandingkan dengan aslinya.

```json
"validation": {
  "held_out_frame": "frame_002.tif", "index": 2, "from": [1, 3],
  "mae": 41.5, "rmse": 58.2, "psnr": 61.03,
  "pixels": 1048576, "reference_min": 1200, "reference_max": 5200
}
```

- `mae` dan `rmse` dalam hitungan 16-bit mentah.
- `psnr` dalam desibel terhadap rentang 16-bit penuh (65535), yang merupakan
  konvensinya. Hati-hati membacanya: frame CT jarang mengisi rentang itu, jadi
  angkanya cenderung terlihat bagus dibanding pengukuran yang memakai rentang
  sebenarnya. `null` ketika kedua frame identik — tidak ada galat untuk
  dinyatakan, dan log10(0) bukan bilangan.
- `reference_min`/`reference_max` **wajib dibaca bersama `mae`**: 40 hitungan
  adalah galat besar pada frame yang membentang 300 dan dapat diabaikan pada
  frame yang membentang 60.000.
- `{"error": "..."}` ketika pengukurannya gagal diambil. Job-nya tetap
  `completed`: sebuah pengukuran yang gagal tidak boleh merenggut interpolasi
  yang sudah selesai.

**Bisa `null`**, dan itu kasus biasa: unggahan berisi frame 1 dan 5 tidak
menyisakan apa pun untuk disembunyikan.

#### Membandingkan dua model

| Method | Endpoint | Fungsi |
|---|---|---|
| `POST` | `/predictions/{id}/rerun` | Jalankan frame yang sama lewat model lain |

Body: `{"model_id": 2}`. Menjawab **201** dengan `{id, job_id, status,
rerun_of_id}`, **410** bila frame aslinya sudah kedaluwarsa, **422** bila
modelnya tidak aktif.

Frame masukannya **disalin**, bukan dibagi — perbandingan yang separuhnya bisa
lenyap sendiri-sendiri bukanlah perbandingan.

`GET /predictions/{id}` lalu menyertakan **`comparison`**, seluruh run pada
frame yang sama, terurut dari yang terlama:

```json
"comparison": [
  { "id": 14, "is_current": true, "model": "deepCT Model",
    "status": "completed", "output_files_count": 3, "mae": 41.5, "psnr": 61.0 },
  { "id": 15, "is_current": false, "model": "Second opinion",
    "status": "completed", "output_files_count": 3, "mae": 38.2, "psnr": 62.4 }
]
```

Kosong ketika hanya ada satu run: tabel berisi satu baris bukan perbandingan,
dan terbaca seolah ada yang gagal dimuat.

#### Bukti yang hidup lebih lama dari berkasnya

| Method | Endpoint | Fungsi |
|---|---|---|
| `GET` | `/predictions/{id}/evidence/{name}` | Satu thumbnail tersimpan, sebagai PNG |

`GET /predictions/{id}` menyertakan **`evidence`**, daftar nama thumbnail yang
disimpan permanen. Enam gambar 256px per run, diambil menyebar sepanjang
sekuensnya, tersimpan di luar folder job supaya `predictions:cleanup` tidak
menyentuhnya.

Endpoint-nya **sengaja tidak memeriksa kedaluwarsa**. Thumbnail ini justru ada
untuk hidup lebih lama daripada frame asalnya; menolaknya begitu yang asli
kedaluwarsa akan meniadakan satu-satunya alasan ia disimpan. Menghapus job-nya
tetap menghapus thumbnail-nya.

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

Kedua endpoint membawa `X-Checksum-MD5`; server mendukung HTTP Range untuk
klien yang ingin melanjutkan unduhan. Klien Flutter saat ini mengunduh ulang
dari awal jika koneksi terputus. Klien wajib membaca checksum, menghitung ulang
MD5 selama menerima data, dan hanya menyimpan hasil setelah cocok. Di platform
native, hasil sementara ditulis ke berkas `.part`; di web, potongan ditahan
untuk dibuat menjadi Blob setelah verifikasi.

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
| `POST` | `/predictions/uploads/{uploadId}/finalize` | Rakit arsipnya. **Tidak mengantrekan** |
| `DELETE` | `/predictions/uploads/{uploadId}` | Batalkan |

**Buka sesi** — body `model_id`, `total_size`, `filename` (opsional):

```json
{ "upload_id": "ecda037c-…", "chunk_size": 1677721,
  "received": 0, "total_size": 4194750 }
```

`purpose` boleh dihilangkan dan artinya `prediction`. `model_id` **wajib
kecuali** `purpose: training` — menyebut `prediction` secara eksplisit tanpa
`model_id` menjawab **422** dengan `model_id` di daftar errornya, sama seperti
menghilangkan keduanya. (Sampai 18 Agustus 2026 kombinasi itu menjawab 500:
aturannya `required_without:purpose`, yang menanyakan apakah field-nya *dikirim*
alih-alih apa isinya.)

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
| `PUT` | `/admin/users/{id}` — name, phone, email, role |
| `DELETE` | `/admin/users/{id}` |
| `PATCH` | `/admin/users/{id}/toggle` |
| `POST` | `/admin/users/{id}/reset-password` |

Password default `user12345678` dikembalikan sebagai `default_password`.
Admin tidak bisa menghapus atau menonaktifkan akunnya sendiri (403).
Menonaktifkan atau mereset password mencabut token akun tersebut. Penghapusan
akun dengan prediksi/training aktif ditolak (409); penghapusan yang berhasil
membersihkan arsip prediksi, bukti, dan unggahan sementara miliknya.

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

#### Rahasia dan TLS worker

`POST` dan `PUT` menerima dua medan tambahan:

- **`auth_token`** — rahasia bersama yang dikirim ke worker sebagai
  `Authorization: Bearer`. **Tulis-saja**: tidak ada satu pun endpoint yang
  mengembalikannya, tersimpan terenkripsi, dan yang dijawab registry hanyalah
  `has_auth_token` (boolean).
- **`verify_tls`** — apakah sertifikat worker diperiksa. Default `false`,
  sama dengan perilaku sebelum medan ini ada.

Pada `PUT`, ketiga keadaan `auth_token` berbeda artinya:

| Yang dikirim | Artinya |
|---|---|
| medannya **tidak ada** | rahasianya dibiarkan apa adanya |
| `""` | rahasianya **dihapus** |
| sebuah string | rahasianya **diganti** |

Bedanya penting: form yang selalu mengirim setiap medan akan menghapus
kredensial setiap kali ada yang membetulkan salah ketik di deskripsi.

Diperlukan begitu worker berpindah dari terowongan bernama acak ke alamat tetap
di jaringan yang bisa dijangkau orang lain — di sana, mengetahui endpoint sudah
cukup untuk memakai GPU-nya.

Health check: `online` bila terjangkau, `trouble` bila > 5 detik, `offline`
bila gagal atau tunnel mati (`ERR_NGROK_3200`).

### Permintaan akses (4)

| Method | Path |
|---|---|
| `GET` | `/admin/access-requests` — filter `status` |
| `POST` | `/admin/access-requests/{id}/approve` |
| `POST` | `/admin/access-requests/{id}/reject` — body `note` opsional |
| `DELETE` | `/admin/access-requests/{id}` |

`approve` **langsung membuat akun user-nya** dan mengembalikan `name`/`email` +
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
| `POST` | `/admin/training/datasets` — **URL saja**, bukan unggahan |
| `DELETE` | `/admin/training/datasets/{id}` — **409** kalau masih dipakai job |
| `GET` | `/admin/training/jobs` — filter `status` |
| `GET` | `/admin/training/jobs/{id}` |
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

**`POST /admin/training/jobs/{id}/dispatch` telah dicabut** pada 23 Agustus
2026. Ia mendorong job ke GPU dengan bentuk yang persis seperti prediksi
didorong ke endpoint model, dan ia ada karena dulu admin yang memulai run.

Sekarang periset yang memulai, dan job antre diklaim worker sendiri lewat
`POST /training/worker/claim` — mekanisme yang memang dirancang untuk itu, dan
yang membuat sebuah run bertahan melewati sesi Kaggle yang mati. Dua jalur
menuju hal yang sama yang bedanya cuma siapa yang menekan bukanlah pengawasan.

Yang dikirim ke trainer tidak berubah: id job, epoch, hyperparameter, sumber
dataset, **dan `callback`** berisi `base_url` + `worker_token`. Tanpa dua yang
terakhir, trainer bisa melatih dengan sempurna lalu tidak punya tempat menaruh
hasilnya.


Job **tetap `queued`** setelah berhasil dikirim. Trainer bilang ia *menerima*;
yang membuktikan ia *mulai* adalah heartbeat pertama. Menandainya `running` di
sini membuat job yang tidak pernah jalan terlihat sehat selamanya.

**`register-model` sengaja langkah terpisah.** Bobot itu berkas; "model" di
platform ini adalah worker FastAPI yang hidup dan punya URL. Tidak ada apa pun
di sini yang bisa men-deploy `.h5` ke GPU, jadi model baru dibuat dengan
`is_active: false` dan tanpa endpoint sampai ada yang men-deploy-nya.

### Pekerja GPU — token khusus, bukan token user

Tujuh route di bawah `/api/training/worker/*`, di luar `auth:sanctum`. Autentikasi
lewat `Authorization: Bearer {TRAINING_WORKER_TOKEN}` — worker itu mesin, bukan
orang: kredensialnya tinggal berminggu-minggu di notebook, tidak butuh akun, dan
tidak boleh menyentuh apa pun selain tujuh route ini.

| Method | Path | Untuk |
|---|---|---|
| `POST` | `/training/worker/claim` | Ambil job antrean tertua |
| `GET` | `/training/worker/jobs/{id}/dataset` | Unduh arsip dataset |
| `POST` | `/training/worker/jobs/{id}/heartbeat` | "Masih hidup" + epoch/metrik |
| `POST` | `/training/worker/jobs/{id}/checkpoint` | Bobot sementara |
| `POST` | `/training/worker/jobs/{id}/sample` | Satu PNG sampel per epoch |
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

## Antrean langsung

| Method | Endpoint |
|---|---|
| `GET` | `/admin/queue` — siapa yang sedang dan akan memakai model |

**Bukan dari `user_activities`.** Jejak audit mencatat peristiwa yang *sudah
terjadi* — "memulai analisis" — tanpa mengatakan apakah run-nya masih berjalan,
jadi menjawabnya dari sana berarti mencari peristiwa yang belum ada pasangan
selesainya. Itu penyimpulan, dan ia salah begitu dua run bertumpang tindih.
`analysis_records` menyatakannya langsung: `processing` untuk yang sedang
dikerjakan, `pending` untuk yang menunggu.

Keadaan sekarang, bukan riwayat. "Siapa saja yang pernah memakai model"
dijawab riwayat prediksi dan jejak audit — pertanyaan berbeda, dan mencampur
keduanya dalam satu daftar justru mengubur yang mendesak.

`queue_position` di sini **angka yang sama** dengan yang dilihat pemilik job di
`/predictions`, karena keduanya dihitung `App\Services\QueueBoard` — sejak
1.35.0 benar-benar keduanya, termasuk pertanyaan satu-rekaman lewat
`positionOf()`. Sebelumnya tiga tempat menghitung sendiri dengan
`created_at <`, yang memberi angka sama kepada dua rekaman berdetik sama.
Urutannya dipecah dengan `id` supaya total, bukan diserahkan ke basis data.

Job yang sedang berjalan tidak diberi nomor: ia tidak sedang menunggu apa pun.
Begitu pula `uploaded` — ia menunggu tombol START, bukan GPU.

`meta` membawa keadaan `QueueHealth` beserta pesan versi administrator —
antrean panjang dan worker mati terlihat sama dari daftar job yang menunggu,
padahal keduanya menuntut tindakan berlawanan.

```json
{
  "success": true,
  "data": {
    "running": [
      {
        "id": 37,
        "job_id": "job-a1b2",
        "status": "processing",
        "user": { "id": 4, "name": "Alice", "email": "alice@brin.go.id" },
        "model": { "id": 1, "name": "deepCT", "version": "v1.0" },
        "input_files_count": 42,
        "elapsed_seconds": 96,
        "queue_position": null,
        "estimated_wait_minutes": null,
        "created_at": "2026-08-25T12:40:11+00:00"
      }
    ],
    "waiting": [
      {
        "id": 39,
        "status": "pending",
        "user": { "id": 7, "name": "Bob", "email": "bob@brin.go.id" },
        "model": { "id": 1, "name": "deepCT", "version": "v1.0" },
        "input_files_count": 18,
        "elapsed_seconds": 240,
        "queue_position": 1,
        "estimated_wait_minutes": 2,
        "created_at": "2026-08-25T12:38:02+00:00"
      }
    ],
    "minutes_per_job": 2,
    "busy": 1,
    "queued": 1
  },
  "meta": {
    "stalled": false,
    "waiting": 1,
    "oldest_wait_seconds": 240,
    "queue_message": null
  }
}
```

`user` bisa `null` hanya karena kolomnya mengizinkan; `analysis_records.user_id`
memakai `cascade`, jadi baris antrean tanpa pemilik tidak bisa terbentuk.
`model` **memang bisa** `null` — `model_id` memakai `set null`, sehingga model
yang dicabut sementara pekerjaannya masih mengantre meninggalkannya kosong.

---

## Penyimpanan

| Method | Endpoint |
|---|---|
| `GET` | `/admin/storage` — ruang kosong dan rinciannya |

```json
{
  "mounted": true,
  "sentinel_enforced": false,
  "free_bytes": 42949672960,
  "total_bytes": 107374182400,
  "used_bytes": 64424509440,
  "minimum_free_bytes": 2147483648,
  "headroom_multiplier": 3.0,
  "breakdown": {
    "predictions": 3221225472,
    "evidence": 1048576,
    "training_datasets": 2147483648,
    "temporary": 0
  }
}
```

Yang penting **bukan** totalnya. Volume di 90% yang sebagian besar berisi
`predictions` baik-baik saja — sapuan retensi mengembalikannya dalam sehari.
Volume di 90% berisi `training_datasets` tidak, karena tidak ada yang
mengambilnya kembali. Satu angka "terpakai" tidak bisa membedakan keduanya.

`mounted` bernilai false ketika volume hasil tidak ter-mount. Dalam keadaan itu
unggahan ditolak alih-alih ditulis ke apa pun yang ada di balik mount point —
lihat di bawah.

### Unggahan yang ditolak sebelum berjalan

Jalur unggah prediksi dan training langsung memeriksa ruang lebih dulu dan
menjawab **507 Insufficient Storage** ketika tidak ada tempat:

- **`POST /predictions/uploads`** memeriksa `total_size` yang dideklarasikan,
  sebelum satu byte pun bergerak.
- **`POST /predictions`** memeriksa ukuran arsip yang sudah di disk, sebelum
  ekstraksi — titik ketika satu berkas menjadi banyak.
- **`POST /me/training/jobs`** memeriksa ukuran arsip langsung sebelum disimpan.

Prediksi memeriksa direktori ZIP sebelum ekstraksi: maksimal 50 MB per frame,
1000 frame input, dan 2 GB total TIFF setelah diekstrak. Nama frame yang sama
setelah folder diratakan ditolak. Header `X-Checksum-MD5` wajib dibaca klien;
arsip unduhan yang tidak cocok tidak disimpan sebagai hasil berhasil.

507, bukan 400: tidak ada yang salah dengan permintaannya, dan berkas yang
lebih kecil tidak akan mendapat jawaban berbeda.

Sebuah arsip menghabiskan disk **tiga kali lipat** sebelum selesai: frame yang
diekstrak, frame yang dihasilkan darinya, dan arsip sementara untuk unduhannya.
Diatur lewat `STORAGE_HEADROOM_MULTIPLIER`, dengan lantai absolut
`STORAGE_MINIMUM_FREE_BYTES` (2 GB) supaya sebuah mesin tidak pernah berjalan
sampai nol — di titik itu basis data pun tidak bisa menulis.

### Membuktikan NAS-nya benar-benar ter-mount

Share yang tidak ter-mount bukan kesalahan; ia direktori kosong biasa, dan
tulisan ke dalamnya berhasil. Berkasnya mendarat di disk host dan tidak akan
ditemukan lagi.

Aktifkan dengan `STORAGE_REQUIRE_SENTINEL=true` **setelah** menjalankan:

```bash
php artisan storage:mark
```

**Mati secara default.** Instalasi satu disk tidak punya apa pun untuk absen,
dan menyalakannya tanpa sentinel akan menolak setiap unggahan.

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
