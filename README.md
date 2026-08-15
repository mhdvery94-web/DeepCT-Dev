# 🔬 Platform Analisis Citra Neutron CT

Platform BRIN untuk **interpolasi frame citra Neutron CT** menggunakan deep
learning. Peneliti mengunggah arsip berisi frame `.tif` bernomor dengan celah di
antaranya; platform mengisi celah itu dengan memanggil model, lalu mengembalikan
hasilnya sebagai arsip.

> Agent/AI yang bekerja di repo ini: baca **[CLAUDE.md](CLAUDE.md)** lebih dulu.

---

## Arsitektur singkat

```
Flutter (web + Android)  ──HTTPS──►  Laravel 12 + Octane/RoadRunner  ──►  MySQL
                                              │
                                              └──ngrok──►  FastAPI @ Kaggle
                                                           (bobot .h5, GPU)
```

Komputasi berat sengaja dipisah: penyimpanan dan orkestrasi lokal, inferensi di
GPU cloud. Detailnya di **[ARCHITECTURE.md](ARCHITECTURE.md)**.

---

## Menjalankan

Butuh PHP 8.2+, Composer, MySQL 8 (via Laragon), Flutter 3.44+, dan Node.js.

### 1. Backend

```bash
cd be
composer install && npm install
cp .env.example .env && php artisan key:generate
php artisan migrate --seed
npm run octane                    # http://127.0.0.1:8000
```

Backend butuh **tiga proses**. Satu perintah menjalankan semuanya:

```bash
npm run serve:all                 # API + queue worker + scheduler
```

Tanpa queue worker, upload berhasil tapi prediksi selamanya `pending`; tanpa
scheduler, berkas kedaluwarsa tidak pernah dihapus. Kalau Octane menolak start,
jalankan `npm run octane:reset` dulu (lihat CLAUDE.md soal `posix_kill`).

### 2. Frontend

```bash
cd fe
flutter pub get
flutter run -d chrome
```

Default `baseUrl` menunjuk ke domain ngrok cadangan yang mem-forward ke port
8000. Arahkan ke tempat lain tanpa mengedit file:

```bash
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000/api
```

### 3. Model AI

Jalankan notebook `models-ai/Evaluation_2_to_1_1kx1k_With_Logo.ipynb` di
Kaggle/Colab, lalu daftarkan URL-nya lewat **Admin → Model Management**. Jangan
lewat `.env` — `NGROK_API_URL` di sana peninggalan lama dan tidak dibaca kode
manapun.

Sesi Kaggle putus sendiri. Cek dengan `php artisan models:health-check`.

---

## Status per 15 Agustus 2026

Semua baris di bawah ini diverifikasi langsung terhadap aplikasi yang berjalan,
bukan disalin dari catatan lama.

### Berjalan

| Bagian | Status |
|---|---|
| Autentikasi (Sanctum, token 7 hari) | ✅ |
| Satu sesi per akun — login kedua ditolak 409, idle 15 menit bisa diambil alih | ✅ |
| Admin console — user, model, activity log, CSV export | ✅ |
| Researcher console — dashboard, upload, hasil, riwayat | ✅ |
| Pipeline prediksi — upload → interpolasi rekursif → download | ✅ |
| Chunked upload resumable | ✅ |
| Retensi 24 jam (`predictions:cleanup`) | ✅ |
| Pratinjau frame hasil di aplikasi (TIFF 16-bit → PNG) | ✅ |
| 35 endpoint API + `/api/health` | ✅ |
| `flutter analyze` 0 issue, 21 test Flutter lulus | ✅ |
| **89 test backend lulus** (295 assertion, ~20 detik) | ✅ |
| Build web & APK release | ✅ (APK ~52 MB) |

Terverifikasi end-to-end terhadap worker Kaggle sungguhan dengan dua frame
1024×1024: upload terpecah 3 potongan, menghasilkan 3 frame 2 MB, dan MD5
unduhan cocok dengan header.

### Belum ada

| Hal | Catatan |
|---|---|
| **Test untuk layar Flutter yang mengambil data** | Butuh mocking API; yang ada baru layout, parsing, dan navigasi |
| **Git remote** | Repo ini lokal saja — tidak ada cadangan di luar mesin ini |
| **Resume upload dari sisi klien** | Server sudah mendukung; klien belum menyimpan sesi yang terputus |
| **`applicationId`** | Masih `com.example.fe`, harus diganti sebelum distribusi |
| **Deployment** | Belum ada; masih development di Laragon + ngrok |

### Diketahui bermasalah

- **Octane tidak bisa restart sendiri di Windows** — `posix_kill()` tidak ada,
  jadi `octane:start`/`octane:stop` crash sebelum berbuat apa pun dan proses
  lama tetap hidup. Prosedur yang benar ada di [CLAUDE.md](CLAUDE.md) dan
  [be/README.md](be/README.md).
- **`flutter build web --wasm` gagal** — `flutter_secure_storage_web` masih
  memakai `dart:html`. Build JS biasa tidak terpengaruh.

---

## Performa

Diukur setelah migrasi ke Octane + RoadRunner:

| Operasi | Sebelum (`artisan serve`) | Sesudah (Octane) |
|---|---|---|
| Health check model | 8.000–11.000 ms | 1.300–1.700 ms |
| Test prediction (warm) | timeout | ~2.400 ms |
| CRUD | — | < 150 ms |

Inferensi sungguhan ~18–21 detik per frame yang dihasilkan; itu waktu GPU di
Kaggle, bukan backend.

---

## Dokumentasi

| File | Isi |
|---|---|
| [CLAUDE.md](CLAUDE.md) | Kontrak kerja untuk agent + jebakan yang memakan waktu |
| [ROADMAP.md](ROADMAP.md) | Rencana kerja berurutan, dan apa yang sengaja tidak dikerjakan |
| [ARCHITECTURE.md](ARCHITECTURE.md) | Komponen, alur data, skema database, keputusan teknis |
| [API.md](API.md) | Referensi 35 endpoint |
| [be/README.md](be/README.md) | Setup, troubleshooting, dan perintah backend |
| [fe/README.md](fe/README.md) | Struktur, breakpoint, dan konvensi frontend |
| [CHANGELOG.md](CHANGELOG.md) | Riwayat perubahan beserta alasannya |
| [PRD.md](PRD.md) | Kebutuhan produk |
| [DESIGN.md](DESIGN.md) | Design system & panduan UI/UX |
| [AI_EXPERIMENTS.md](AI_EXPERIMENTS.md) | Jurnal eksperimen model |

---

## Akun pengembangan

| Peran | Email | Password |
|---|---|---|
| Admin | admin@brin.go.id | admin123 |
| Peneliti | researcher@brin.go.id | user123 |

User baru dibuat admin dengan password `BrinResearch2026`. Tidak ada registrasi
mandiri dan tidak ada alur "lupa password".

⚠️ **Satu sesi per akun.** Login kedua saat akun sedang dipakai **ditolak
(HTTP 409)** dengan pesan yang menjelaskan, dan perangkat yang sudah login tidak
ditendang. Sesi yang menganggur lebih dari 15 menit dianggap ditinggalkan,
sehingga akun tidak terkunci kalau aplikasi tertutup paksa.

---

**Institusi:** Badan Riset dan Inovasi Nasional (BRIN)
