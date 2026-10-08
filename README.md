# DeepCT

Platform BRIN untuk mengisi gap frame Neutron CT melalui model deep learning.
Admin dan researcher menggunakan **prediksi saja**: upload ZIP TIFF, preview,
mulai proses, bandingkan model, lalu unduh hasil. LLM masih rancangan.

## Komponen

| Folder/file | Fungsi |
|---|---|
| be/ | Laravel API, database, antrean dan storage di Raspberry Pi |
| fe_web/ | Website/portal Next.js di Vercel |
| fe/ | Flutter untuk web dan perangkat |
| script-api-deepct.py | Worker inference FastAPI pada host GPU terpisah |
| docs/ | Dokumentasi aplikasi yang aktif |

Aset yang diperlukan tersimpan di frontend masing-masing. Proposal, notebook
eksperimen, mockup Stitch, konfigurasi agent dan salinan Images root tidak
dibutuhkan dalam repository aplikasi. Riwayatnya tersedia di Git.

## Dokumentasi

| Dokumen | Isi |
|---|---|
| [Arsitektur](docs/ARCHITECTURE.md) | Komponen, alur prediksi, data dan batas ilmiah |
| [API](docs/API.md) | Auth, upload, resource pengguna/admin dan media |
| [Operasi](docs/OPERATIONS.md) | Deployment, backup/pemulihan dan diagnosis |
| [Pengembangan](docs/DEVELOPMENT.md) | Setup lokal, build, testing dan konvensi |
| [Rancangan LLM](docs/LLM_DESIGN.md) | Kesiapan frontend, pilihan model dan logika bisnis |
| [Checkpoint](docs/CHECKPOINT.md) | Commit/rilis terverifikasi serta pekerjaan terbuka |

## Menjalankan dan memverifikasi

Backend membutuhkan PHP 8.2+, Composer, MySQL 8 dan Node.
Website memakai Node 22; Flutter memakai SDK 3.44.9. Setup lengkap dan
perintah masing-masing komponen ada di docs/DEVELOPMENT.md.

```bash
cd fe_web
npm ci
cp .env.example .env.local
# Atur LARAVEL_API_BASE_URL ke backend, lalu:
npm run dev
```

Produksi: [website](https://deepct-web.vercel.app) dan
[API Raspberry Pi](https://zestfully-usable-pledge.ngrok-free.dev/api).
Deploy otomatis dikendalikan workflow GitHub main.
Git pull memakai --ff-only agar commit lokal tidak dibuang diam-diam.

Versi prediksi/media 49da8eb diterima oleh CI: backend 329 tes/1.381 asersi,
Flutter 227 tes, browser 51, API Pi 39 dan HTTPS publik 25 lulus.
Bukti rilis serta hasil pembersihan terbaru tercatat di checkpoint.

Training tidak tersedia. Migrasi historis tetap dipertahankan untuk upgrade
database lama. Pemulihan penghapusan data membutuhkan backup sebelum migrasi
dan kode rilis sebelumnya. UAT terhadap GPU nyata belum selesai.
