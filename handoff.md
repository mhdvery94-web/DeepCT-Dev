# Serah terima sesi — 4 September 2026

Berkas ini untuk sesi berikutnya. Ia menjawab satu pertanyaan: **apa yang sudah
dikerjakan, apa keadaannya sekarang, dan apa yang harus dipegang sebelum
menyentuh apa pun.**

Ia bukan dokumen status. Yang direncanakan ada di [ROADMAP.md](ROADMAP.md),
yang selesai ada di [CHANGELOG.md](CHANGELOG.md), keadaan sekarang ada di
[README.md](README.md). Yang ada di sini hanyalah konteks yang tidak muat di
ketiganya.

---

## 1. Hal pertama yang harus diketahui

**Belum ada satu commit pun.** 122 berkas berubah, 54 di antaranya belum
terlacak sama sekali — termasuk `QueueBoard.php`, `FrameMetrics.php`,
`CleanupTrainingDatasets.php`, `AdminQueueController.php`, `ResultEvidence.php`,
`ArchiveSource`, dan seluruh berkas uji baru.

Ini **disengaja**. Pemiliknya ingin menunjukkan pekerjaan ini kepada pembimbing
lebih dulu. Jangan commit tanpa diminta.

---

## 2. Yang dikerjakan pada sesi ini

### 2.1 Perbaikan aplikasi (CHANGELOG 1.34.0 – 1.39.0)

| Versi | Isi |
|---|---|
| 1.34.0 | `find_base_model()` di kedua skrip Kaggle; panel training tidak lagi memakan ruang daftar model; dua notebook berebut satu domain ngrok |
| 1.35.0 | Ekstensi bobot `storeAs()`; `hyperparameters` sebagai objek di tiga tempat; posisi antrean disatukan ke `QueueBoard`; `script-api-deepct.py` tidak lagi diabaikan git |
| 1.36.0 | `TiffPreview` ditulis ulang di atas untai biner — **196 MB → 11,7 MB** per frame 2048²; `MAX_PIXELS` naik ke 4096² |
| 1.37.0 | Pratinjau dataset 404 untuk frame di dalam subfolder (`{name}` tidak bisa merentang garis miring) |
| 1.38.0 | Retensi arsip dataset (`training:cleanup`); `ArchiveSource` agar unggahan tidak memuat arsip ke RAM; resume unggah dataset |
| 1.39.0 | UTF-8 rusak di 8 berkas; empat cacat model diukur; percobaan penyempurnaan bobot dengan hasil negatif |

### 2.2 Penyelidikan model — inti sesi ini

Model `STUNet_2to1_TimeCond` dipakai sejak awal proyek berdasarkan keterangan
yang tidak pernah diverifikasi. Sesi ini mengukurnya.

**Empat cacat, semuanya terukur terhadap arsip BRIN yang sebenarnya:**

| | Cacat | Angka |
|---|---|---|
| A | Mengabaikan skalar waktu | tanggapan **0,17%** |
| B | Galat berlipat tiap batas sintetis | **1,73×** dan **3,27×** |
| C | Galat naik dengan lebar rentang | 359,7 / 586,1 / 1.039,3 |
| D | Celah ganjil bergeser ½ posisi | `intdiv` membulatkan |

Akibatnya: hanya frame yang **kedua batasnya hasil pindai** yang layak. Celah 8
memberi **0 dari 7** frame layak.

**Dua klaim lama terbantah** dan koreksinya sudah masuk `AI_EXPERIMENTS.md`:
model tidak "mengabaikan" `t` (ia merespons, tapi 0,17%), dan jalur pengondisi
waktunya sama sekali tidak lemah — bobotnya **2,35× lebih besar** daripada
rerata seluruh kanal citra di dekoder pertama.

**Percobaan penyempurnaan (job 19)** menaikkan tanggapan ke 27,87%, tetapi
masih di bawah ambang yang dapat dibedakan mata. Bobotnya disimpan di
`models-ai/` dan **tidak dipasang**.

### 2.3 Seminar proposal

`proposal/Seminar Proposal.md` — sekitar 18.300 kata, 24 tabel bernomor,
11 penanda gambar, 20 rujukan yang seluruhnya terverifikasi lewat Crossref dan
seluruhnya disitasi di dalam naskah.

**Keseimbangannya sengaja dijaga, dan masih condong.** Audit terakhir: sisi
rancang bangun 2.704 kata, sisi model 6.250 kata — rasio 2,31 : 1. Subbab
**3.5.9 Alasan Pemilihan Arsitektur dan Peranti** ditambahkan agar keputusan
rancang bangun dipertanggungjawabkan setara dengan cara subbab 2.3
mempertanggungjawabkan pemilihan algoritma. Rasionya belum 1 : 1 dan memang
tidak perlu — tetapi kalau pembimbing meminta lebih berimbang lagi, yang
paling layak ditambah adalah 3.5 (bukan memangkas 3.6, yang seluruhnya berisi
angka terukur).

---

## 3. Yang harus dipegang sebelum menyentuh apa pun

### Model itu bukan milik proyek ini

Bobot `generator(Salinan 3 Ginet TC-D_Revisi).h5` adalah hasil kolaborasi
dengan BRIN. Naskah proposal menyebutnya begitu — **tanpa menyebut institusi
lain maupun nama penulis**, atas permintaan pemiliknya, agar fokusnya tetap
pada studi kasus BRIN. Jangan ubah bingkai itu menjadi klaim kepengarangan.

### Angka yang tidak boleh dikutip ulang tanpa membaca sumbernya

- Model punya **21.921.601 parameter**, bukan ~25,6 juta. Angka lama beredar di
  beberapa dokumen dan tidak pernah diverifikasi. Yang benar dibaca langsung
  dari `.h5`.
- Metrik latih **job 18 dan job 19 tidak sebanding**. Job 18 memakai
  `max_gap=4` (40 contoh), job 19 `max_gap=8` (112 contoh). MAE job 19 lebih
  besar karena soalnya lebih berat, bukan karena modelnya lebih buruk.
- Evaluasi sapuan tujuh frame pada HONDA memakai frame yang **ada di data
  latih**. Angka Sample Contrast (objek yang tidak dilatihkan) yang layak
  dipercaya.

### MAE dan PSNR akan menyesatkan pada persoalan ini

Pencampuran linier — rata-rata dua frame batas — **mengalahkan model** pada MAE
(4 dari 5) dan PSNR (5 dari 5), karena rata-rata adalah tebakan yang
meminimalkan galat kuadrat. Pada **SSIM** model unggul **5 dari 5**, dan
keunggulannya melebar pada kasus yang lebih sulit.

Frame proyeksi yang kabur merusak rekonstruksi. Jangan pakai MAE atau PSNR
sendirian sebagai ukuran keberhasilan.

### Mesin ini tidak punya GPU

Satu forward pass di CPU memakan **~150 detik**. TensorFlow 2.21 sudah
terpasang di `Python312`, bukan di `python` bawaan PATH. Untuk pengujian model,
pakai:

```
"C:\\Users\\fajri\\AppData\\Local\\Programs\\Python\\Python312\\python.exe"
```

Proses latar di lingkungan ini berulang kali dihentikan sebelum rampung.
Skrip apa pun yang berjalan lama **harus menyimpan hasil bertahap ke disk**,
melewati yang sudah ada, dan bisa dijalankan berulang.

---

## 4. Berkas kerja di luar repo

| Letak | Isi |
|---|---|
| `models-ai/generator(Salinan 3 Ginet TC-D_Revisi).h5` | Bobot dasar, dipakai sistem |
| `models-ai/generator(Revisi 4 STUNet balanced-t maxgap8).h5` | Hasil job 19, **tidak dipasang** |
| `Examples ZIP/Example/` | Data uji BRIN: HONDA 10 frame, AlCu 4, Contrast 3 |
| `Examples ZIP/Hasil generate/` | Keluaran uji visual: `salinan/`, `revisi4/`, `linier/`, `0-frame asli/` |
| `proposal/Seminar Proposal.md` | Naskah seminar proposal |
| `proposal/PEDOMAN TUGAS AKHIR TI V5.pdf` | Pedoman UNPAM |
| `proposal/Proposal Skripsi.pdf` | Template yang diikuti |

Skrip pembuat pratinjau proposal ada di scratchpad sesi ini
(`bikin_preview.py`). Ia membangun HTML langsung dari naskah `.md`, sehingga
pratinjau dan naskah tidak dapat menyimpang. Kalau naskahnya berubah,
jalankan ulang.

---

## 5. Yang berikutnya

**Untuk proposal** — pemiliknya akan menunjukkannya ke pembimbing. Setelah itu
dipindahkan ke Word: TNR 12, spasi 1,5, margin 4/4/3/3, A4. Sebelas gambar
digambar sendiri; uraiannya sudah ada di setiap penanda. Dua puluh DOI perlu
diperiksa ulang.

**Untuk aplikasi** — enam butir terbuka di ROADMAP. Yang terbesar bukan kode:
**bagian C dan D menunggu pemeriksaan di perangkat**, dan gerbang GPU keduanya
sudah lewat.

**Untuk model** — dua arah, urut biaya: melanjutkan pelatihan melewati epoch 20,
dan memperoleh barisan proyeksi yang lebih panjang dari satu objek. Ambang lulus
sudah ditetapkan agar tidak bisa disesuaikan belakangan: rasio keragaman ≥ 0,6
pada objek yang tidak dilatihkan.

---

## 6. Keadaan terverifikasi, 4 September 2026

```
php artisan test     368 lulus, 1.452 asersi
flutter analyze      bersih
flutter test         269 lulus
```

Kedua penjaga encoding hijau. Dua worker Kaggle sempat hidup pada sesi ini dan
kemungkinan sudah mati sekarang — sesi Kaggle berakhir sendiri.
