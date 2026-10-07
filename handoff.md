# Serah terima sesi — 1 Oktober 2026

Berkas ini untuk sesi berikutnya. Ia menjawab satu pertanyaan: **apa keadaannya
sekarang, dan apa yang harus dipegang sebelum menyentuh apa pun.**

Ia bukan dokumen status. Yang direncanakan ada di [ROADMAP.md](ROADMAP.md),
yang selesai ada di [CHANGELOG.md](CHANGELOG.md), keadaan sekarang ada di
[README.md](README.md). Yang ada di sini hanyalah konteks yang tidak muat di
ketiganya.

---

## 1. Keadaan repositori

Repository aktif adalah `DeepCT-Dev/DeepCT-AI-PROD`. Commit produksi terakhir
yang diuji pada sesi ini adalah `c6f4f1f`; workflow dispatch
`36853332173` menjalankan dua suite test, seluruh build klien, deployment Pi,
deployment Vercel dan publikasi artifact. Dokumen pengujian dan revisi naskah
yang dikerjakan setelah commit itu harus diperiksa lewat `git status` sebelum
commit berikutnya.

Dua direktori sengaja tidak dilacak dan sudah masuk `.gitignore`:

| Direktori | Alasan |
|---|---|
| `Examples ZIP/` (93 MB) | Data penelitian BRIN yang belum terbit. Ukurannya alasan kedua; yang pertama, seluruh rancangan sistem ini bertumpu pada janji bahwa data itu tidak keluar dari kendali institusi. |
| `ImageJ/` (109 MB) | Aplikasi pihak ketiga, melewati batas 100 MB GitHub, dapat diunduh ulang. |

---

## 2. Di mana sistem ini benar-benar berjalan

Arsitektur *hybrid cloud-NAS* sudah memiliki deployment aplikasi publik, tetapi
NAS institusi dan worker GPU tetap komponen terpisah. Yang berjalan sekarang:

| Bagian | Tempat |
|---|---|
| Orkestrasi, API, basis data, antrean | **Raspberry Pi 5**, `/var/www/deepct-ai`, dipublikasikan lewat ngrok |
| Inferensi dan pelatihan model | **Kaggle** di balik ngrok |
| Klien web | **Vercel** (`deep-ct-ai-prod.vercel.app`) |
| Bangun dan sebar | **GitHub Actions** (`.github/workflows/release.yml`) |

Volume NAS belum ada; `StorageGuard` sudah menanganinya tetapi belum pernah
diuji terhadap perangkat NAS yang sebenarnya.

API publik adalah
`https://zestfully-usable-pledge.ngrok-free.dev/api`. PM2 menjaga
`deepct-app` (`npm run serve:all`) dan `deepct-ngrok`, sementara
`pm2-jihyo.service` memulihkannya setelah reboot. Akun admin dan researcher
sudah dibuat dari repository secrets dan dibuktikan login melalui API yang
berjalan. UAT web researcher juga sudah diterima.

Alamat API tetap merupakan konstanta waktu-build. Workflow hanya membaca
`RASPI_API_BASE_URL`; mengubah variable itu tidak berpengaruh sampai klien
dibangun dan diterbitkan ulang. Root `vercel.json` mematikan auto-build Git;
Vercel hanya menerima output Flutter yang sudah dibangun Actions.

Yang belum ikut pindah adalah database historis dan `storage/` VPS. Database Pi
bukan lagi kosong—ia memiliki dua akun bootstrap—tetapi katalog model masih
kosong. Karena itu autentikasi produksi sudah diterima, sedangkan prediksi
ujung-ke-ujung terhadap worker nyata belum boleh disebut selesai.

---

## 3. Yang harus dipegang sebelum menyentuh apa pun

### Model itu bukan milik proyek ini

Bobot `generator(Salinan 3 Ginet TC-D_Revisi).h5` adalah hasil kolaborasi
dengan BRIN. Naskah menyebutnya begitu — **tanpa menyebut institusi lain
maupun nama penulis**, atas permintaan pemiliknya. Jangan ubah bingkai itu
menjadi klaim kepengarangan.

### Perilakunya adalah batas rancangan, bukan cacat

Diperiksa 6 September dari tiga sumber yang sepakat: notebook evaluasi
kolaborasi memaku `time_scalar` pada 0,5, menamai keluarannya `2i + 1`, dan
menghasilkan satu frame per pasangan berurutan tanpa rekursi; `build_samples()`
pada skrip pelatihan runtuh ke titik tengah kecuali ragam `t` seimbang
dinyalakan; dan uji Sample Contrast berhasil pada frame yang kedua batasnya
hasil pindai. **Model dirancang untuk satu sisipan titik tengah.** Tanggapan
0,17% terhadap `t` bukan kerusakan — masukan itu tidak pernah dilatih di posisi
lain. Jangan sebut "cacat" di dokumen mana pun.

### Angka yang tidak boleh dikutip ulang tanpa membaca sumbernya

- Model punya **21.921.601 parameter**, bukan ~25,6 juta.
- Basis data punya **23 tabel**, 15 milik aplikasi. Angka 13, 18, dan 22 pernah
  beredar di dokumen dan semuanya salah.
- Metrik latih **job 18 dan job 19 tidak sebanding**: `max_gap=4` (40 contoh)
  lawan `max_gap=8` (112 contoh).
- Evaluasi sapuan tujuh frame pada HONDA memakai frame yang **ada di data
  latih**. Angka Sample Contrast yang layak dipercaya.

### MAE dan PSNR akan menyesatkan pada persoalan ini

Pencampuran linier mengalahkan model pada MAE (4 dari 5) dan PSNR (5 dari 5),
karena rata-rata meminimalkan galat kuadrat. Pada **SSIM** model unggul
**5 dari 5**. Frame proyeksi yang kabur merusak rekonstruksi; jangan pakai MAE
atau PSNR sendirian sebagai ukuran keberhasilan.

### Mesin ini tidak punya GPU, dan build APK memakan 13 menit

Satu forward pass di CPU memakan ~150 detik; TensorFlow 2.21 ada di
`Python312`, bukan di `python` bawaan PATH. `flutter build apk --release`
memakan ~13 menit dan **akan dihentikan** bila dijalankan sebagai proses latar
di lingkungan agen — jalankan sendiri, atau lewat latar depan yang boleh
meluber. Setelah build yang gagal, hentikan daemon Gradle
(`cd fe/android && ./gradlew --stop`) sebelum mencoba lagi: daemon yang
tertinggal mengunci `libflutter.so` dan build berikutnya gagal dengan galat
yang tampak seperti cacat kode.

---

## 4. Berkas kerja di luar repo

| Letak | Isi |
|---|---|
| `models-ai/generator(Salinan 3 Ginet TC-D_Revisi).h5` | Bobot dasar, dipakai sistem |
| `models-ai/generator(Revisi 4 STUNet balanced-t maxgap8).h5` | Hasil job 19, **tidak dipasang** |
| `Examples ZIP/Example/` | Data uji BRIN: HONDA 10 frame, AlCu 4, Contrast 3 |
| `Examples ZIP/Hasil generate/` | Keluaran uji visual |
| `proposal/PEDOMAN TUGAS AKHIR TI V5.pdf` | Pedoman UNPAM |

Skrip pembangun pratinjau dan dokumen Word ada di scratchpad sesi
(`bikin_preview.py`, `bikin_docx.py`). Keduanya membaca `.md` langsung,
sehingga pratinjau, Word, dan naskah tidak dapat menyimpang. Jumlah halaman
diukur dengan menjalankan Word lewat COM, bukan diperkirakan — dua perkiraan
sebelumnya meleset jauh di dua arah berlawanan.

---

## 5. Yang berikutnya

**Untuk naskah** — `proposal/Proposal Skripsi done.docx` sedang diselaraskan
dengan deployment Pi/Vercel, hasil pengujian terbaru dan pedoman UNPAM. Sumber
gambar eksternal yang pernah diekstrak ke `proposal/gambar/` sedang hilang dari
working tree; jangan memulihkannya atau memasukkannya ke commit tanpa memastikan
apakah penghapusan itu memang dikehendaki pemilik.

**Untuk aplikasi** — `ApiConfig.baseUrl` sumber masih memakai fallback worker,
walaupun build produksi aman karena mendapat `RASPI_API_BASE_URL`. Jalur
prediksi dan training masih perlu dibuktikan sekali terhadap worker GPU
sungguhan; penyempurnaan bobot tetap diserahkan ke BRIN.

**Untuk penyebaran** — sinkronkan katalog model saat worker FastAPI aktif,
jalankan satu prediksi nyata, tentukan apakah data historis VPS perlu dipindah,
salin backup ke luar Pi, amati deployment, lalu baru hentikan VPS. Jangan
menganggap bootstrap dua akun sama dengan migrasi data historis.

---

## 6. Keadaan terverifikasi, 1 Oktober 2026

```
php artisan test               385 lulus, 1.536 asersi (MySQL 8 CI)
flutter analyze                bersih
flutter test                   276 lulus di 33 berkas
flutter build web/apk/linux    berhasil di workflow 36853332173
flutter build iOS/macOS        berhasil tanpa signing
login produksi                admin + researcher lulus
black box API produksi         12 dari 12 lulus
web Vercel                     landing, login researcher, dashboard, logout diterima
```

Detail skenario ada di [WHITE_BOX_TESTING.md](WHITE_BOX_TESTING.md) dan
[USER_ACCEPTANCE_TESTING.md](USER_ACCEPTANCE_TESTING.md). Sesi Kaggle berakhir
sendiri, jadi terowongan worker yang hidup hari ini belum tentu hidup besok.
