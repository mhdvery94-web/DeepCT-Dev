# Referensi API

35 endpoint di bawah `/api`, plus `GET /api/health`. Daftar ini dibuat dari
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

**`POST /login`** — body `{ "email", "password" }`.

```json
{ "success": true, "data": { "user": { … }, "token": "64|abc…" } }
```

⚠️ **Satu sesi per akun.** Kalau akun sedang dipakai, login dijawab **409**:

```json
{ "success": false,
  "message": "This account is already signed in on another device. Sign out there first, or try again in a few minutes." }
```

Perangkat yang sudah memegang sesi **tidak** ditendang. "Sedang dipakai"
berarti token-nya terpakai dalam 15 menit terakhir; lewat dari itu dianggap
ditinggalkan dan login baru mengambil alih. Berlaku sama untuk admin maupun
peneliti.

Akun nonaktif ditolak dengan pesan tersendiri, bukan "kredensial salah", supaya
peneliti tahu harus menghubungi admin.

---

## Terautentikasi — semua peran

| Method | Path | Keterangan |
|---|---|---|
| `POST` | `/logout` | Mencabut token yang sedang dipakai |
| `GET` | `/user` | Profil pemanggil |
| `GET` | `/me/stats` | Penghitung untuk dashboard peneliti |
| `GET` | `/me/activities` | Jejak audit milik sendiri, berpaginasi |
| `GET` | `/me/models` | Model yang boleh dipakai |

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

---

## Prediksi — semua peran

Tiap aksi di-scope ke pemanggil di dalam `AnalysisController`.

| Method | Path | Keterangan |
|---|---|---|
| `GET` | `/predictions` | Daftar job sendiri. Filter opsional `status`. |
| `POST` | `/predictions` | Unggah arsip dalam satu request |
| `GET` | `/predictions/{id}` | Detail; memuat posisi antrean saat masih pending |
| `DELETE` | `/predictions/{id}` | Hapus job beserta berkasnya |
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
