# Serah terima sesi — 8 September 2026

Berkas ini untuk sesi berikutnya. Ia menjawab satu pertanyaan: **apa keadaannya
sekarang, dan apa yang harus dipegang sebelum menyentuh apa pun.**

Ia bukan dokumen status. Yang direncanakan ada di [ROADMAP.md](ROADMAP.md),
yang selesai ada di [CHANGELOG.md](CHANGELOG.md), keadaan sekarang ada di
[README.md](README.md). Yang ada di sini hanyalah konteks yang tidak muat di
ketiganya.

---

## 1. Keadaan repositori

**Seluruhnya sudah di-commit dan di-push.** Pada 8 September, 60 commit
dikirim ke `basiadyanna54-commits/deepCT-AI`, dan `main` lokal sinkron dengan
`origin/main`. Sebelum itu GitHub berhenti di 18 Agustus, jadi push tersebut
membawa tiga minggu pekerjaan sekaligus.

Catatan yang penting untuk sesi berikutnya: keadaan "tidak ada yang belum
di-commit" itu **baru**, dan sebelumnya 124 berkas menumpuk berminggu-minggu.
Jangan biarkan itu terulang.

Dua direktori sengaja tidak dilacak dan sudah masuk `.gitignore`:

| Direktori | Alasan |
|---|---|
| `Examples ZIP/` (93 MB) | Data penelitian BRIN yang belum terbit. Ukurannya alasan kedua; yang pertama, seluruh rancangan sistem ini bertumpu pada janji bahwa data itu tidak keluar dari kendali institusi. |
| `ImageJ/` (109 MB) | Aplikasi pihak ketiga, melewati batas 100 MB GitHub, dapat diunduh ulang. |

---

## 2. Di mana sistem ini benar-benar berjalan

**Penyiapan di BRIN belum dilakukan.** Arsitektur *hybrid cloud-NAS* yang
diuraikan pada naskah proposal adalah rancangan sasaran, bukan keadaan hari
ini. Yang berjalan sekarang:

| Bagian | Tempat |
|---|---|
| Orkestrasi, API, basis data, antrean | **VPS** (`brin.fajrianhost.my.id`) |
| Inferensi dan pelatihan model | **Kaggle** di balik ngrok |
| Klien web | **Vercel** (`deep-ct-ai.vercel.app`) |
| Bangun dan sebar | **GitHub Actions** (`.github/workflows/release.yml`) |

Volume NAS belum ada; `StorageGuard` sudah menanganinya tetapi belum pernah
diuji terhadap perangkat NAS yang sebenarnya.

**Satu hal yang sedang membingungkan, dan sebabnya bukan yang terlihat.**
Landing page di Vercel tampil tanpa berita dan tanpa video. Bundelnya mutakhir
— `main.dart.js` tertanggal 8 September 04:52 GMT, dua jam sesudah push — dan
ia menunjuk `cesspool-barricade-widget.ngrok-free.dev`, yaitu **VPS**, yang
memang sasaran yang benar.

Yang kosong adalah basis data VPS-nya: `/api/health` menjawab dengan benar,
tetapi `/api/news` mengembalikan nol baris. Jadi halaman itu bekerja
sebagaimana mestinya dan menampilkan apa adanya, yaitu tidak ada apa-apa.
Perbaikannya ada di sisi VPS — jalankan migrasi dan isi datanya — bukan
mengganti alamatnya.

Alamat API **tidak** diatur dari dasbor Vercel. Ia ditentukan variabel
repositori GitHub dengan urutan `NGROK_BE_VPS` → `NGROK_BE` → `API_BASE_URL` →
bawaan, dibaca `.github/workflows/release.yml`, lalu **dikompilasi ke dalam
bundel**. Mengubah variabelnya tidak berpengaruh sampai ada build baru.

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

**Untuk naskah** — dua dokumen ada di `proposal/`: seminar proposal tiga bab
(69 halaman) dan naskah skripsi lima bab. Yang menunggu pemiliknya: 21 gambar
(11 diagram digambar sendiri, 10 tangkapan layar BAB IV), tabulasi kuesioner
4.3.4 yang sengaja dibiarkan kosong, dan tebal halaman pada penutup abstrak.

**Untuk aplikasi** — tiga butir terbuka di ROADMAP, dan tidak satu pun berupa
kode yang belum ditulis. `ApiConfig.baseUrl` menunggu catatan DNS
`api.brin.fajrianhost.my.id` yang masih NXDOMAIN; `POST /admin/training/datasets`
menunggu jalur peneliti terbukti sekali di GPU sungguhan; penyempurnaan bobot
diserahkan ke BRIN.

**Untuk penyebaran** — `API_BASE_URL` di Vercel perlu diarahkan ke terowongan
yang benar, lalu di-*redeploy*. Di sisi VPS, 12 migrasi belum pernah
dijalankan; dua di antaranya membuang kolom (`username` dari `users`,
`max_concurrent_jobs` dari `models`), jadi cadangkan basis data lebih dulu.

---

## 6. Keadaan terverifikasi, 8 September 2026

```
php artisan test               368 lulus, 1.452 asersi
flutter analyze                bersih
flutter test                   274 lulus di 33 berkas
flutter build web --release    berhasil, 336 detik
flutter build apk --release    berhasil, 61,9 MB
git                            main sinkron dengan origin/main
```

Kedua penjaga encoding hijau. Butir C dan D sudah dicoba pemiliknya di
perangkat dan berfungsi. Sesi Kaggle berakhir sendiri, jadi terowongan yang
hidup hari ini belum tentu hidup besok.
