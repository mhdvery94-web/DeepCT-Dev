# RANCANG BANGUN SISTEM MULTIPLATFORM TERINTEGRASI BERBASIS ARSITEKTUR HYBRID CLOUD-NAS UNTUK INTERPOLASI OTOMATIS CITRA PROYEKSI TOMOGRAFI KOMPUTER NEUTRON MENGGUNAKAN ALGORITMA SPATIO-TEMPORAL U-NET (STU-NET)

## (STUDI KASUS: BRIN PUSPIPTEK)

**PROPOSAL SKRIPSI**

[GAMBAR — Logo Universitas Pamulang, diletakkan di tengah halaman sampul]

Oleh :

**MUHAMMAD NUR FAJRIANSYAH**

**231011401688**

PROGRAM STUDI TEKNIK INFORMATIKA

FAKULTAS ILMU KOMPUTER

UNIVERSITAS PAMULANG

PAMULANG

2026

---

# ABSTRACT

Neutron computed tomography at BRIN Puspiptek frequently produces projection
sequences with missing angles, caused by limited beam time and acquisition
faults, degrading volumetric reconstruction while manual gap filling cannot
be repeated. This research designs and builds an integrated
multiplatform system on a hybrid cloud-NAS architecture that fills those gaps
automatically using the Spatio-Temporal U-Net algorithm, developed with the
Prototyping method. Orchestration and file storage remain on local
infrastructure with a NAS volume, while model inference runs on a
graphics card in a cloud environment. The model, obtained through collaboration
with BRIN and built from 31 layers with 21,921,601 parameters, was measured
against genuine projection archives beforehand. Its response to the time scalar
reached only 0.17%, so gap filling must proceed recursively, and the error
compounds 1.73 times at every synthetic boundary. Hold-out validation produced
MAE 359.747, RMSE 688.092, and PSNR 39.58 dB, roughly 0.6% of the image range,
while on SSIM it beat linear blending in five of five cases.
Retraining raised the time response to 27.87%, yet output diversity reached only
0.210, so those weights were not deployed. The system therefore certifies only
frames whose two boundaries are both scanned, and reports each frame’s provenance
to the researcher.

**Keywords :** Frame Interpolation, Neutron Computed Tomography, U-Net, Hybrid
Cloud, Prototyping

---

# ABSTRAK

Tomografi komputer neutron di BRIN Puspiptek kerap menghasilkan barisan
proyeksi bercelah akibat keterbatasan waktu berkas neutron dan kendala
akuisisi, sehingga mutu rekonstruksi volumetrik menurun sedangkan pengisian
celah secara manual tidak dapat diulang. Penelitian ini merancang dan
membangun sistem multiplatform terintegrasi berbasis arsitektur *hybrid
cloud-NAS* yang mengisi celah tersebut secara otomatis menggunakan algoritma
Spatio-Temporal U-Net, dengan metode Prototyping. Orkestrasi dan seluruh
penyimpanan berkas berada pada perangkat lokal dan volume NAS, sedangkan
inferensi model dijalankan pada kartu grafis di lingkungan komputasi awan.
Model hasil kolaborasi dengan BRIN, tersusun atas 31 lapisan dengan 21.921.601
parameter, diukur lebih dahulu terhadap arsip proyeksi asli. Tanggapannya
terhadap skalar waktu hanya 0,17%, sehingga pengisian celah harus dijalankan
secara rekursif, dan galatnya berlipat 1,73 kali pada setiap batas sintetis.
Validasi *hold-out* menghasilkan MAE 359,747, RMSE 688,092, dan PSNR 39,58 dB
atau sekitar 0,6% dari rentang citra, sedangkan pada SSIM model unggul atas
pencampuran linier pada lima dari lima kasus. Pelatihan ulang menaikkan
tanggapan skalar waktu menjadi 27,87%, namun rasio keragaman keluarannya baru
0,210 sehingga bobot tersebut tidak dipasang. Sistem karena itu menyatakan
layak hanya frame yang kedua batasnya merupakan hasil pindai, dan melaporkan
asal-usul setiap frame kepada peneliti yang menerimanya.

**Kata Kunci :** Interpolasi Frame, Tomografi Komputer Neutron, U-Net, Hybrid
Cloud, Prototyping

---

# DAFTAR ISI

```
ABSTRACT ................................................................... i
ABSTRAK ................................................................... ii
DAFTAR ISI ............................................................... iii
DAFTAR GAMBAR .............................................................. v
DAFTAR TABEL .............................................................. vi
BAB I PENDAHULUAN .......................................................... 1
1.1  Latar Belakang .................................................... 1
1.2  Identifikasi Masalah .............................................. 3
1.3  Rumusan Masalah ................................................... 4
1.4  Batasan Penelitian ................................................ 4
1.5  Tujuan Penelitian ................................................. 7
1.6  Manfaat Penelitian ................................................ 7
1.7  Metodologi Penelitian ............................................. 8
1.8  Sistematika Penulisan ............................................. 9
BAB II LANDASAN TEORI ..................................................... 11
2.1  Penelitian Relevan ............................................... 11
2.2  Tinjauan Pustaka ................................................. 13
2.3  Alasan Pemilihan Algoritma Spatio-Temporal U-Net ................. 21
2.4  Kerangka Berpikir ................................................ 24
BAB III ANALISA DAN PERANCANGAN ........................................... 23
3.1  Alur Penelitian .................................................. 23
3.2  Metode Pengumpulan Data .......................................... 24
3.3  Analisa Sistem yang Sedang Berjalan .............................. 25
3.4  Analisa Sistem yang Diusulkan .................................... 27
3.5  Perancangan Sistem ............................................... 28
3.6  Analisa Model dan Rancangan Pemanfaatannya ....................... 37
3.7  Rancangan Pengujian .............................................. 56
3.8  Rancangan Iterasi Prototyping .................................... 57
3.9  Kebutuhan Perangkat .............................................. 58
JADWAL PENYUSUNAN SKRIPSI ................................................. 60
DAFTAR PUSTAKA ............................................................ 62
```

---

# DAFTAR GAMBAR

```
Gambar 2. 1   Arsitektur Spatio-Temporal U-Net ........................... 14
Gambar 2. 2   Kerangka Berpikir Penelitian ............................... 21
Gambar 3. 1   Alur Penelitian ............................................ 23
Gambar 3. 2   Alur Akuisisi Proyeksi Tomografi Neutron Saat Ini .......... 26
Gambar 3. 3   Arsitektur Sistem yang Diusulkan ........................... 28
Gambar 3. 4   Alur Kerja Sistem yang Diusulkan ........................... 29
Gambar 3. 5   Diagram Use Case Sistem .................................... 31
Gambar 3. 6   Diagram Aktivitas Pengisian Celah Proyeksi ................. 33
Gambar 3. 7   Diagram Relasi Antar-Entitas ............................... 34
Gambar 3. 8   Rancangan Antarmuka Unggah dan Pratinjau Frame ............. 38
Gambar 3. 9   Rancangan Antarmuka Pemantauan Pelatihan Model ............. 39
Gambar 3. 10  Alur Interpolasi Rekursif .................................. 45
```

---

# DAFTAR TABEL

```
Tabel 2. 1   Penelitian yang Relevan ..................................... 11
Tabel 2. 2   Operasi di Dalam Layer Kustom SkipFusion .................... 12
Tabel 2. 3   Susunan Lapisan STUNet_2to1_TimeCond (ringkas) .............. 13
Tabel 2. 4   Rangkuman Keunggulan Model terhadap Pencampuran Linier ...... 14
Tabel 3. 1   Format Pencatatan Kondisi Akuisisi Citra .................... 15
Tabel 3. 2   Analisa Permasalahan Sistem Berjalan ........................ 16
Tabel 3. 3   Aktor dan Kewenangannya ..................................... 17
Tabel 3. 4   Rancangan Tabel Basis Data .................................. 18
Tabel 3. 5   Rancangan Antarmuka Pemrograman Aplikasi .................... 19
Tabel 3. 6   Mekanisme Ketahanan Sistem .................................. 20
Tabel 3. 7   Waktu Satu Inferensi pada Lingkungan Lokal dan Awan ......... 21
Tabel 3. 8   Pembagian Data Citra ........................................ 22
Tabel 3. 9   Tahapan Praproses Citra ..................................... 23
Tabel 3. 10  Hiperparameter Pelatihan Model .............................. 24
Tabel 3. 11  Tanggapan Bobot Dasar terhadap Perubahan Skalar Waktu ....... 25
Tabel 3. 12  Bobot Dasar terhadap Pencampuran Linier pada Tiga Metrik .... 26
Tabel 3. 13  Parameter Pelatihan Pembaruan Model ......................... 27
Tabel 3. 14  Sapuan Tujuh Posisi dari Satu Pasangan Frame Pindai ......... 28
Tabel 3. 15  Hasil Pembaruan terhadap Kriteria Keberhasilan .............. 29
Tabel 3. 16  Keragaman Keluaran terhadap Gerak Frame Nyata ............... 30
Tabel 3. 17  Jarak Antar-Hasil pada Objek yang Tidak Dilatihkan .......... 31
Tabel 3. 18  Rancangan Skenario Pengujian ................................ 32
Tabel 3. 19  Format Penyajian Hasil Pengujian ............................ 33
Tabel 3. 20  Iterasi Prototyping dan Capaian Setiap Iterasi .............. 34
Tabel 3. 21  Kebutuhan Perangkat Keras ................................... 35
Tabel 3. 22  Kebutuhan Perangkat Lunak ................................... 36
Tabel 3. 23  Jadwal Penyusunan Skripsi ................................... 37
```

---

# BAB I
# PENDAHULUAN

## 1.1 Latar Belakang

Tomografi komputer neutron adalah teknik pencitraan tak merusak yang
memanfaatkan daya tembus berkas neutron. Berbeda dari sinar-X yang berinteraksi
dengan awan elektron, neutron berinteraksi dengan inti atom, sehingga teknik
ini unggul membedakan unsur ringan seperti hidrogen di balik logam padat.
Sifat itu menjadikannya alat penting pada penelitian material, komponen
otomotif, dan cagar budaya di BRIN Puspiptek.

Rekonstruksi volumetrik disusun dari sekumpulan citra proyeksi pada sudut yang
berbeda-beda, dan semakin rapat jarak sudutnya semakin baik mutu volumenya.
Persoalannya, akuisisi neutron jauh lebih lambat daripada sinar-X: fluks pada
reaktor riset terbatas sehingga satu proyeksi menuntut paparan panjang, dan
satu rangkaian penuh dapat menghabiskan berjam-jam hingga berhari-hari,
sementara waktu berkas dijadwalkan ketat dan dibagi dengan penelitian lain.

Akibatnya muncul celah pada barisan proyeksi, karena dua sebab. Peneliti
sengaja memperlebar jarak sudut untuk menghemat waktu berkas, atau sebagian
proyeksi gagal terekam akibat gangguan teknis — dan mengulang pemindaian
berarti mengantre waktu berkas dari awal. Pada arsip yang dipakai penelitian
ini celah itu terbaca dari penomoran yang meloncat, misalnya `frame_051`
langsung ke `frame_053`.

Pengisiannya selama ini manual atau tidak dilakukan sama sekali. Interpolasi
linier sederhana menghasilkan citra kabur yang justru menambah artefak,
sedangkan pengerjaan manual tidak konsisten antarpeneliti dan tidak dapat
diulang. Padahal frame yang dipakai dalam rekonstruksi ilmiah menuntut
kejelasan asal-usul: peneliti perlu tahu mana hasil pindai dan mana keluaran
model.

Pembelajaran mendalam menawarkan jalan keluar. U-Net terbukti efektif pada
pemetaan citra ke citra karena sambungan lompatnya mempertahankan detail
spasial (Ronneberger, Fischer, & Brox, 2015), dan pendekatan serupa telah
terbukti pada rekonstruksi bersudut jarang (Wu dkk., 2025; Zhang dkk., 2025)
maupun pada interpolasi frame berbasis konvolusi (Niklaus, Mai, & Liu, 2017;
Jiang dkk., 2018). Namun sebagian besar penelitian itu menyasar video
sehari-hari beriringan gerak, bukan barisan proyeksi tomografi berskala
keabuan 16-bit yang perubahannya bersifat geometris dan halus.

Di samping persoalan algoritma ada persoalan sistem yang sama nyatanya. Model
menuntut kartu grafis yang tidak selalu dimiliki perangkat laboratorium,
sedangkan data penelitian tidak boleh menetap di layanan pihak ketiga. Kedua
kebutuhan itu tampak bertentangan dan menuntut arsitektur yang memisahkan
tempat data disimpan dari tempat komputasi berat dikerjakan. Peneliti juga
membutuhkan akses dari perangkat berbeda-beda, baik komputer laboratorium
maupun telepon genggam saat memantau proses yang berjalan lama.

Berdasarkan uraian tersebut penulis mengangkat penelitian berjudul "Rancang
Bangun Sistem Multiplatform Terintegrasi Berbasis Arsitektur Hybrid Cloud-NAS
untuk Interpolasi Otomatis Citra Proyeksi Tomografi Komputer Neutron
Menggunakan Algoritma Spatio-Temporal U-Net (STU-Net) (Studi Kasus: BRIN
Puspiptek)".

## 1.2 Identifikasi Masalah

Berdasarkan latar belakang di atas, permasalahan yang berhasil diidentifikasi
adalah sebagai berikut:

1. Akuisisi citra proyeksi tomografi komputer neutron memakan waktu lama dan
   bergantung pada waktu berkas neutron yang terbatas, sehingga peneliti
   terdorong memperlebar jarak sudut antarproyeksi dengan risiko menurunnya
   mutu rekonstruksi volumetrik.

2. Sebagian proyeksi hilang atau rusak selama akuisisi, dan pemindaian ulang
   untuk sudut yang hilang menuntut pengantrean waktu berkas dari awal.

3. Pengisian celah proyeksi secara manual maupun dengan interpolasi linier
   sederhana tidak konsisten antarpeneliti, tidak dapat diulang dengan hasil
   yang sama, dan berpotensi menambah artefak pada rekonstruksi.

4. Belum tersedia mekanisme yang mencatat asal-usul setiap frame, sehingga
   peneliti yang menerima hasil tidak dapat membedakan frame hasil pindai
   dari frame keluaran model, maupun mengetahui seberapa jauh sebuah frame
   dihasilkan dari keluaran model sebelumnya.

5. Model interpolasi menuntut kartu grafis, sedangkan perangkat kerja di
   laboratorium tidak selalu memilikinya, dan data hasil penelitian tidak
   boleh menetap di layanan komputasi awan pihak ketiga.

6. Belum tersedia antarmuka yang memungkinkan peneliti menjalankan proses
   interpolasi, memantau antrean, dan mengambil hasil dari perangkat yang
   berbeda-beda tanpa bergantung pada satu komputer tertentu.

## 1.3 Rumusan Masalah

Persoalan yang diuraikan di atas bermuara pada tiga pertanyaan yang saling
bergantung. Yang pertama menyangkut sistem yang mewadahi pekerjaan, yang kedua
menyangkut model yang mengerjakannya, dan yang ketiga menyangkut apa yang
boleh dipercaya dari hasilnya.

1. Bagaimana membangun sistem multiplatform di atas arsitektur *hybrid
   cloud-NAS* yang mengisi celah pada barisan proyeksi tomografi komputer
   neutron secara otomatis, sementara arsip penelitiannya harus tetap berada
   di dalam institusi dan kartu grafis yang dibutuhkannya berada di luar
   kendali institusi?

2. Bagaimana algoritma Spatio-Temporal U-Net beserta proses pelatihannya
   bekerja pada persoalan ini, dan sejauh mana perilakunya terhadap arsip
   proyeksi yang sebenarnya ikut menentukan bagaimana sistemnya harus
   dirancang?

3. Bagaimana mutu setiap frame yang dihasilkan dapat diukur dan disampaikan
   kepada peneliti yang menerimanya, padahal frame yang justru ingin diisi
   menurut definisinya tidak memiliki pembanding?

## 1.4 Batasan Penelitian

Penelitian ini dibatasi pada beberapa hal, dan sebagian batasnya tidak dipilih
melainkan diterima: model yang dipakai bukan buatan penelitian ini, dan
perangkat yang menjalankannya bukan milik institusi. Batasan-batasan berikut
menyatakan keduanya secara terbuka, berikut konsekuensinya terhadap rancangan
sistem.

### 1.4.1 Metode dan Algoritma

Metode pengembangan perangkat lunak yang dipakai adalah Prototyping, bukan
Waterfall maupun Scrum, dan algoritma interpolasinya terbatas pada
Spatio-Temporal U-Net. Penelitian ini tidak membandingkan STU-Net dengan
arsitektur interpolasi lain; alasan pemilihannya diuraikan pada subbab 2.3 dan
bertumpu pada bentuk persoalannya sendiri, bukan pada perbandingan menyeluruh
antararsitektur.

Model dipakai sebagaimana adanya. Bobot yang melayani peneliti merupakan hasil
kolaborasi dengan BRIN dan tidak mengalami perubahan arsitektur. Sebuah
percobaan penyempurnaan bobot memang dijalankan dan dilaporkan apa adanya pada
subbab 3.6.8, tetapi hasilnya belum memenuhi ambang yang ditetapkan sebelum
percobaan dimulai, sehingga bobot tersebut tidak dipasang.

Model tersebut dirancang untuk menyisipkan satu frame pada titik tengah di
antara dua frame hasil pindai, dan hanya dilatih pada posisi itu. Rancangan
tersebut membawa serta empat batas perilaku yang diperlakukan sebagai batasan
penelitian, bukan sasaran perbaikan, dan seluruhnya diukur pada subbab 3.6.6
terhadap arsip proyeksi BRIN. Pertama, masukan skalar waktunya praktis tidak
berpengaruh di luar titik tengah, yaitu hanya 0,17% dari perubahan yang
seharusnya. Kedua, pengisian karena itu harus rekursif dan galatnya berlipat
1,73 kali untuk satu batas sintetis serta 3,27 kali untuk dua. Ketiga, galat
meningkat dari 359,7 pada rentang dua langkah menjadi 1.039,3 pada rentang
delapan langkah. Keempat, celah berjumlah frame ganjil tidak memiliki titik
tengah bilangan bulat sehingga frame yang dihasilkan bergeser setengah posisi.

Akibatnya sistem hanya menyatakan layak frame yang kedua batasnya merupakan
hasil pindai. Celah yang lebih lebar tetap diisi, tetapi asal-usul dan
kedalaman rekursi setiap frame disampaikan melalui nilai `generation` agar
dapat dinilai sendiri. Interpolasi pada tahap inferensi karena itu selalu
dilakukan pada titik tengah, dan sistem tidak menyediakan masukan skalar waktu
manual.

### 1.4.2 Data Penelitian

Data penelitian berupa arsip citra proyeksi tomografi komputer neutron dari
fasilitas BRIN Puspiptek, berformat TIFF skala keabuan 16 bit tanpa kompresi
pada resolusi 1024 × 1024 piksel. Nama setiap berkas wajib memuat nomor
proyeksi, misalnya `frame_051.tif`, karena nomor itulah yang menentukan urutan
frame sekaligus letak celahnya; tanpa penomoran yang terbaca, sistem tidak
memiliki dasar untuk mengetahui apa yang hilang.

Arsip diunggah dalam bentuk berkas `.zip` dengan batas 512 MB untuk satu arsip
dataset pelatihan dan 50 MB untuk satu frame, sementara satu pekerjaan
interpolasi menghasilkan paling banyak 200 frame. Penelitian ini tidak
mencakup rekonstruksi volumetrik dari kumpulan proyeksi: keluaran sistem
berhenti pada barisan proyeksi yang telah lengkap, dan pengolahan sesudahnya
tetap berada pada perangkat lunak yang selama ini dipakai peneliti.

### 1.4.3 Proses Pengujian

Mutu frame hasil interpolasi diukur dengan empat besaran, yaitu Mean Absolute
Error (MAE), Root Mean Squared Error (RMSE), Peak Signal-to-Noise Ratio
(PSNR), dan Structural Similarity Index Measure (SSIM). Keempatnya dilaporkan
bersama-sama, karena pada persoalan ini masing-masing dapat menyesatkan
apabila berdiri sendiri.

Pengukurannya memakai skema *hold-out*: sebuah frame yang merupakan titik
tengah tepat dari dua frame yang diunggah disembunyikan dari model,
dibangkitkan kembali, lalu dibandingkan terhadap frame asli yang disembunyikan
tersebut. Skema ini dipilih justru karena frame yang sesungguhnya ingin diisi
peneliti tidak memiliki pembanding, sehingga satu-satunya angka yang dapat
dipertanggungjawabkan adalah angka yang berasal dari frame yang memang ada.

Pada sisi perangkat lunaknya, pengujian dilakukan secara otomatis baik di sisi
peladen maupun di sisi klien, serta diuji ujung ke ujung terhadap kartu grafis
sungguhan, sebab pengujian yang seluruhnya memakai tiruan tidak dapat
membuktikan interpolasinya berjalan. Keamanan jaringan tingkat lanjut, audit
keamanan menyeluruh, dan penyimpanan data biometrik berada di luar lingkup
penelitian ini.

### 1.4.4 Implementasi

Sistem diwujudkan sebagai purwarupa yang berfungsi, bukan sistem siap
produksi, dan perbedaan itu perlu dinyatakan dengan terang. Yang dibangun
mencakup autentikasi dan pembagian peran, unggah berpotongan yang dapat
dilanjutkan, antrean pekerjaan beserta posisinya, interpolasi rekursif dengan
pencatatan asal-usul frame, validasi *hold-out*, pratinjau frame 16 bit,
pemantauan pelatihan model, serta tata kelola retensi berkas. Semuanya
berbentuk aplikasi peramban dan aplikasi Android dari satu basis kode, sebuah
antarmuka pemrograman aplikasi, antrean pekerjaan, dan layanan inferensi
model. Yang tidak dibangun mencakup penyeimbangan beban, replikasi basis data,
pencadangan otomatis, dan penyebaran pada peladen publik. Aplikasi iOS juga
berada di luar lingkup penelitian ini.

Dua keadaan di luar kendali penelitian ikut membentuk rancangannya. Peladen
inferensi berjalan pada lingkungan komputasi awan berkartu grafis yang sesinya
terbatas dan dapat berakhir sewaktu-waktu, karena perangkat tersebut bukan
milik institusi; sistem karena itu dirancang dengan asumsi layanan inferensi
dapat hilang kapan saja, bukan dengan asumsi ia selalu tersedia. Sebaliknya,
seluruh berkas hasil penelitian menetap pada volume NAS lokal, dan sistem
harus berhenti secara terang-terangan apabila volume tersebut tidak terpasang.
Pekerjaan yang berjalan tanpa tempat menyimpan hasilnya lebih merugikan
daripada pekerjaan yang menolak dimulai.

### 1.4.5 Tools

Perangkat lunak yang dipakai ditetapkan sejak awal dan tidak menjadi variabel
yang diteliti. Sisi peladen ditulis dalam bahasa PHP dengan kerangka kerja
Laravel 12 beserta Octane dan peladen aplikasi RoadRunner, dengan MySQL 8
sebagai penyimpan metadata sekaligus antrean pekerjaan. Sisi klien ditulis
dalam bahasa Dart dengan kerangka kerja Flutter, satu basis kode untuk
peramban dan Android sekaligus. Layanan inferensi dan pelatihan model ditulis
dalam bahasa Python dengan pustaka TensorFlow/Keras, FastAPI, NumPy, dan
Pillow. Keduanya dihubungkan melalui terowongan HTTP yang menjembatani peladen
lokal dengan lingkungan komputasi awan.

## 1.5 Tujuan Penelitian

Berdasarkan rumusan masalah di atas, tujuan yang ingin dicapai dalam
penelitian ini adalah :

1. Merancang dan membangun sistem multiplatform terintegrasi berbasis
   arsitektur *hybrid cloud-NAS* yang menjalankan interpolasi citra proyeksi
   tomografi komputer neutron secara otomatis, dapat diakses melalui
   peramban maupun telepon genggam.

2. Menerapkan algoritma Spatio-Temporal U-Net beserta proses pelatihannya
   untuk mengisi celah pada barisan proyeksi, termasuk mekanisme interpolasi
   rekursif pada titik tengah.

3. Menyusun mekanisme pengukuran mutu berbasis validasi *hold-out* beserta
   pencatatan asal-usul setiap frame, sehingga hasil interpolasi dapat
   dipertanggungjawabkan angkanya oleh peneliti yang menerimanya.

4. Menghasilkan purwarupa yang telah diuji ujung ke ujung terhadap arsip
   citra neutron dan kartu grafis yang sebenarnya, bukan hanya terhadap data
   sintetis.

## 1.6 Manfaat Penelitian

**Bagi BRIN Puspiptek**, sistem ini mengurangi kebutuhan waktu berkas neutron
karena jarak sudut dapat diperlebar sementara celahnya diisi model,
menyelamatkan rangkaian pemindaian yang sebagian proyeksinya hilang tanpa
mengantre pemindaian ulang, menyediakan hasil yang konsisten dan dapat diulang
beserta catatan asal-usul dan angka mutu setiap frame, serta memberi antarmuka
yang dapat diakses dari perangkat berbeda-beda sehingga proses panjang dapat
dipantau tanpa terikat satu komputer.

**Bagi pengembangan ilmu**, penelitian ini melengkapi kajian penerapan
arsitektur berbasis U-Net pada interpolasi barisan proyeksi neutron, yang
karakteristik citranya berbeda dari video sehari-hari, dan menyajikan
rancangan *hybrid cloud-NAS* sebagai pola penyelesaian bagi laboratorium yang
membutuhkan komputasi berkartu grafis namun terikat kewajiban menjaga data
penelitian tetap di lingkungan sendiri.

**Bagi penulis**, penelitian ini menjadi sarana penerapan ilmu pembelajaran
mesin, pengolahan citra digital, dan rekayasa perangkat lunak, sekaligus
memenuhi salah satu syarat memperoleh gelar Sarjana Komputer pada Program Studi
Teknik Informatika Universitas Pamulang.

## 1.7 Metodologi Penelitian

Penelitian ini memakai metode pengembangan perangkat lunak **Prototyping**,
yang membangun purwarupa bertahap dan menyempurnakannya berdasarkan umpan
balik pengguna pada setiap iterasi (Pressman & Maxim, 2020). Metode itu
dipilih karena kebutuhannya tidak dapat dirumuskan lengkap di awal: perilaku
model terhadap arsip yang sebenarnya baru diketahui setelah dicoba, dan bentuk
antarmuka yang berguna baru terlihat setelah peneliti mencobanya.

Pengumpulan datanya menempuh empat cara. **Observasi** terhadap alur kerja
akuisisi di BRIN Puspiptek, mencakup format berkas, pola penomoran, letak
celah, dan perangkat yang dipakai. **Wawancara** dengan peneliti dan operator
mengenai keterbatasan waktu berkas, penyebab hilangnya proyeksi, serta
penanganan celah yang berjalan saat ini. **Dokumentasi** berupa pengumpulan
arsip citra beserta catatan kondisi akuisisinya, yang menjadi data pelatihan
sekaligus data pengujian. **Studi pustaka** atas buku, jurnal, dan prosiding
yang berkaitan.

Tahapannya mengikuti siklus Prototyping, dari komunikasi dan penggalian
kebutuhan bersama BRIN Puspiptek, perencanaan dan pemodelan cepat, pembangunan
purwarupa yang mencakup layanan inferensi, antarmuka pemrograman aplikasi, dan
aplikasi klien, hingga penyerahan purwarupa beserta pengumpulan umpan balik.
Siklus itu diulang sampai purwarupa memenuhi kebutuhan yang disepakati, dan
rinciannya diuraikan pada Bab III.

## 1.8 Sistematika Penulisan

Proposal skripsi ini disusun dengan sistematika sebagai berikut.

**BAB I PENDAHULUAN** menguraikan latar belakang, identifikasi masalah,
rumusan masalah, batasan penelitian, tujuan dan manfaat penelitian, metodologi,
serta sistematika penulisan.

**BAB II LANDASAN TEORI** memuat penelitian terdahulu yang relevan, tinjauan
pustaka mengenai tomografi komputer neutron, citra 16-bit, interpolasi frame,
U-Net dan Spatio-Temporal U-Net, fungsi kerugian dan optimasi, metrik evaluasi,
arsitektur *hybrid cloud-NAS*, sistem multiplatform, serta metode Prototyping,
dan ditutup dengan alasan pemilihan algoritma dan kerangka berpikir.

**BAB III ANALISA DAN PERANCANGAN** berisi alur penelitian, metode pengumpulan
data, analisa sistem berjalan dan sistem yang diusulkan, perancangan sistem
perangkat lunak beserta alasan pemilihan arsitektur dan perantinya, analisa
perilaku model dan rancangan pemanfaatannya, serta rancangan pengujian,
iterasi Prototyping, dan kebutuhan perangkat.

**JADWAL PENYUSUNAN SKRIPSI** memuat tahapan aktivitas dan target waktunya
beserta antisipasi kendala, dan **DAFTAR PUSTAKA** memuat seluruh acuan yang
disitasi.

---

# BAB II
# LANDASAN TEORI

## 2.1 Penelitian Relevan

Penelitian yang relevan dengan penelitian ini datang dari tiga arah:
pengembangan algoritma interpolasi frame, penerapan pembelajaran mendalam pada
rekonstruksi tomografi bersudut jarang, dan rancang bangun sistem multiplatform dengan metode pengembangannya. Ketiganya diuraikan pada Tabel
2.1.

**Tabel 2. 1 Penelitian yang Relevan**

| No | Peneliti & Tahun | Judul dan Metode | Perbedaan dengan Penelitian Ini |
|----|------------------|------------------|---------------------------------|
| 1 | Ronneberger dkk. (2015) | U-Net untuk segmentasi citra biomedis | Sumber arsitektur; di sini dipakai untuk interpolasi, bukan segmentasi |
| 2 | Niklaus dkk. (2017) | Interpolasi frame lewat konvolusi adaptif | Menyasar video bergerak; di sini rotasi berkas terhadap objek diam |
| 3 | Isola dkk. (2017) | Pemetaan citra-ke-citra dengan GAN bersyarat | Dasar pemilihan kerugian L1; di sini tanpa diskriminator |
| 4 | Jiang dkk. (2018) | Super SloMo, aliran optik dua arah | Bertumpu pada aliran optik yang tidak bermakna pada proyeksi |
| 5 | Huang dkk. (2022) | Estimasi aliran perantara waktu nyata | Citra tiga kanal delapan bit; di sini satu kanal enam belas bit |
| 6 | Tang dkk. (2024) | Kriteria henti akuisisi neutron berbasis ML | Mencegah proyeksi diambil; di sini memulihkan yang telanjur hilang |
| 7 | Wu dkk. (2025) | Rekonstruksi bersudut jarang, prior dua ranah | Bekerja pada ranah rekonstruksi; di sini pada ranah proyeksi |
| 8 | Zhang dkk. (2025) | STC-UNet untuk koreksi artefak sinkrotron | Memperbaiki artefak volume; di sini melengkapi barisan proyeksi |
| 9 | Rozi dkk. (2025) | Sistem akademik multiplatform dengan Flutter | Tanpa model pembelajaran mendalam dan perangkat keras terpisah |
| 10 | Maharani & Kurniawan (2025) | Sistem informasi dengan metode prototype | Prototype pada sistem informasi biasa, bukan yang bermesin model |

Kesepuluh penelitian tersebut terbagi menjadi dua kelompok yang selama ini
berjalan terpisah. Kelompok pertama, yaitu Ronneberger dkk. (2015), Niklaus
dkk. (2017), Isola dkk. (2017), Jiang dkk. (2018), Huang dkk. (2022), Wu dkk.
(2025), dan Zhang dkk. (2025), menyempurnakan algoritmanya, tetapi berhenti
pada tingkat model dan tidak membahas bagaimana model tersebut sampai ke
tangan peneliti. Kelompok kedua, yaitu Rozi dkk. (2025) serta Maharani dan
Kurniawan (2025), membangun sistemnya, tetapi tidak melibatkan model
pembelajaran mendalam yang harus dilatih dan dijalankan pada perangkat keras
yang terpisah dari peladen. Tang dkk. (2024) berdiri paling dekat dengan
penelitian ini karena bekerja pada tomografi neutron, tetapi sasarannya
memangkas waktu akuisisi, bukan memulihkan proyeksi yang telanjur hilang.

Penelitian ini menempati ruang di antara keduanya. Ia **merancang dan
membangun** sistem multiplatform yang dapat dipakai peneliti, **sekaligus**
menyempurnakan dan mengevaluasi model prediksi yang menjadi mesinnya. Bobot
dasarnya berasal dari penelitian terdahulu di lingkungan BRIN, sebagaimana
diuraikan pada subbab 2.2.5. Konsekuensinya, mutu penelitian ini tidak diukur
dengan membandingkan dua algoritma sebagaimana lazim pada penelitian
komparatif, melainkan melalui dua jenis pembuktian yang berbeda: sistemnya
dibuktikan berfungsi melalui pengujian fungsional dan penyerahan purwarupa
yang benar-benar dicoba pengguna, sedangkan modelnya dibuktikan bermutu
melalui validasi terhadap frame yang disembunyikan.

## 2.2 Tinjauan Pustaka

### 2.2.1 Tomografi Komputer Neutron

Tomografi komputer merekonstruksi struktur internal tiga dimensi suatu objek
dari sekumpulan citra proyeksi dua dimensi yang diambil pada berbagai sudut.
Dasar matematisnya transformasi Radon, dan rekonstruksinya umumnya dikerjakan
dengan proyeksi balik tersaring (Kak & Slaney, 2001).

Pada tomografi neutron, berkas penembusnya neutron termal atau dingin. Neutron
berinteraksi dengan inti atom, bukan awan elektron sebagaimana sinar-X,
sehingga koefisien atenuasinya tidak mengikuti nomor atom secara monotonik:
unsur ringan seperti hidrogen justru sangat menyerap sementara logam berat
relatif tembus. Sifat itulah yang membuatnya unggul mengungkap air, minyak,
atau bahan organik di balik selubung logam (Anderson, McGreevy, & Bilheux,
2009).

Konsekuensi praktisnya keterbatasan fluks. Sumber neutron menuntut reaktor
riset atau sumber spalasi dengan fluks jauh di bawah tabung sinar-X, sehingga
waktu paparan per proyeksi panjang dan jumlah proyeksi dalam satu jadwal
terbatas. Keterbatasan inilah yang mendasari kebutuhan interpolasi pada
penelitian ini. Tang dkk. (2024) menghadapi keterbatasan yang sama dari arah
berlawanan, yaitu menghentikan akuisisi lebih awal tanpa mengorbankan mutu
rekonstruksi; penelitian ini memulihkan proyeksi yang telanjur hilang.

### 2.2.2 Citra Digital 16-bit dan Proyeksi TIFF

Citra digital adalah fungsi diskret dua dimensi yang memetakan koordinat piksel
ke nilai intensitas. Pada pencitraan ilmiah kedalaman yang umum adalah 16 bit
per piksel, dengan rentang 0 hingga 65.535, karena perbedaan atenuasi yang
bermakna dapat sangat halus dan akan hilang bila dipaksakan ke 256 aras
keabuan. Berkasnya disimpan sebagai TIFF tanpa kompresi.

Kedalaman itu menimbulkan persoalan pada sisi penyajian. Peramban maupun
kerangka kerja aplikasi bergerak tidak dapat menampilkan TIFF 16-bit secara
langsung, sehingga frame harus diterjemahkan lebih dahulu. Penerjemahan itu
tidak boleh sekadar membuang byte rendah: satu frame 1024 × 1024 yang diamati
pada penelitian ini hanya menempati rentang 290 hingga 58.633, jauh dari
rentang penuh, sehingga pemangkasan langsung menghasilkan citra yang nyaris
hitam seluruhnya. Yang diperlukan adalah pemetaan berjendela terhadap nilai
terkecil dan terbesar frame itu sendiri, sebagaimana dirancang pada subbab
3.5.6.

### 2.2.3 Interpolasi Frame

Interpolasi frame membangkitkan citra antara di antara dua citra yang
diketahui. Bila kedua citra batas dinyatakan `I₀` dan `I₂` dan posisi waktu
relatif `t ∈ (0,1)`, interpolasi menghasilkan `Î_t`. Pendekatan paling
sederhana adalah pencampuran linier:

```
Î_t = (1 − t) · I₀ + t · I₂
```

Pendekatan itu murah tetapi menghasilkan citra kabur ketika struktur berpindah
antara kedua batas, sebab setiap piksel dicampur tanpa memperhatikan ke mana
struktur berpindah. Pada barisan proyeksi tomografi perpindahan tersebut nyata,
karena setiap proyeksi diambil pada sudut berbeda sehingga struktur bergeser
secara geometris.

Pendekatan berbasis pembelajaran mendalam menggantinya dengan fungsi terlatih
`G` yang memetakan pasangan citra dan posisi waktu ke citra antara:

```
Î_t = G(I₀, I₂, t ; θ)
```

dengan `θ` parameter yang dipelajari dari data. Kye dkk. (2026) merangkum
perkembangan bidang ini dan mengelompokkannya menjadi dua paradigma, yaitu
interpolasi pada titik tengah tetap dan pada posisi waktu sembarang.
Penelitian ini memakai paradigma pertama pada tahap inferensi dan paradigma
kedua pada tahap penyempurnaan model.

### 2.2.4 Arsitektur U-Net

U-Net adalah jaringan konvolusi berbentuk huruf U yang terdiri atas jalur
penyusutan dan jalur pemulihan yang simetris (Ronneberger, Fischer, & Brox,
2015). Jalur penyusutan menurunkan resolusi sambil menaikkan jumlah kanal ciri
sehingga jaringan menangkap konteks yang semakin luas, dan jalur pemulihan
mengembalikannya ke ukuran masukan.

Unsur yang menentukan adalah **sambungan lompat**, yaitu penyaluran peta ciri
dari setiap tingkat jalur penyusutan langsung ke tingkat yang bersesuaian pada
jalur pemulihan. Tanpanya, detail spasial halus yang hilang selama penyusutan
tidak dapat dipulihkan dan keluaran menjadi kabur. Sifat itulah yang membuat
U-Net sesuai bagi tugas yang keluarannya harus setajam masukannya, termasuk
interpolasi frame. Arsitektur ini telah banyak diterapkan pada citra medis di
Indonesia; Ermatita dan Ningsih (2025) memakainya untuk segmentasi nodul paru
dan melaporkan ketelitian 94%, dengan tujuan berbeda tetapi bertumpu pada sifat
yang sama.

### 2.2.5 Spatio-Temporal U-Net (STU-Net)

Spatio-Temporal U-Net adalah pengembangan U-Net yang menerima masukan bersumbu
waktu beserta sebuah skalar waktu sebagai pengondisi: tumpukan dua frame batas
dan skalar `t`, dengan keluaran satu frame antara.

```
G : (ℝ^(2 × 1024 × 1024), ℝ) → ℝ^(1024 × 1024)
```

Model yang dipakai merupakan hasil kolaborasi dengan BRIN sebagai bagian dari
jalur riset pencitraan neutron di sana, dan berkas bobotnya menyimpan nama
arsitektur **`STUNet_2to1_TimeCond`**. Pembagian pekerjaannya dinyatakan
terbuka: arsitektur dan bobot dasar berasal dari jalur riset bersama tersebut,
sedangkan yang dikerjakan pada skripsi ini adalah **merancang dan membangun
sistem yang membuat model itu dapat dipakai peneliti sehari-hari**, **mengukur
perilakunya terhadap arsip proyeksi yang sebenarnya**, dan
**mendokumentasikan batas keberlakuannya**.

**[GAMBAR 2. 1 — Arsitektur Spatio-Temporal U-Net]**
*Gambarkan jalur encoder-decoder berbentuk U dengan sambungan lompat pada setiap tingkat, sumbu waktu pada blok masukan, penyisipan layer SkipFusion pada setiap sambungan lompat, serta jalur masukan skalar waktu t yang menyatu ke jalur pemulihan pada lapisan tersempit.*

Perbedaannya terhadap U-Net baku terletak pada satu layer kustom, `SkipFusion`,
yang disisipkan pada setiap sambungan lompat dan meruntuhkan sumbu waktu
sebelum ciri encoder disalurkan ke jalur pemulihan.

**Tabel 2. 2 Operasi di Dalam Layer Kustom SkipFusion**

| Unsur | Operasi | Peran |
|-------|---------|-------|
| Reduksi rerata | `m = (1/T) Σ_{i=1..T} x_i` | Merangkum seluruh frame masukan menjadi satu peta ciri; menangkap struktur yang sama pada kedua batas |
| Reduksi batas akhir | `l = x_T` | Mengambil frame terakhir pada sumbu waktu; mempertahankan ciri batas terdekat |
| Penggabungan | `y = ReLU(W ∗₁ₓ₁ [m ‖ l] + b)` | Menggabungkan keduanya melalui konvolusi berkernel 1 × 1 sebelum disalurkan ke jalur pemulihan |

Notasi `‖` menyatakan penggabungan pada sumbu kanal dan `∗₁ₓ₁` konvolusi
berkernel 1 × 1. Karena kedua reduksi digabungkan lebih dahulu, kedalaman
masukan konvolusi itu selalu dua kali kedalaman keluarannya, dan keempat
instansnya menyimpan kernel (1, 1, 512, 256) sampai (1, 1, 64, 32). Layer itu
harus didefinisikan identik saat pemuatan, sebab berkas bobot menyimpan namanya
sebagai `Custom>SkipFusion`.

Pemeriksaan langsung menunjukkan model terdiri atas **31 lapisan** dengan
**21.921.601 parameter**, berukuran 87.796.792 byte.

**Tabel 2. 3 Susunan Lapisan STUNet_2to1_TimeCond (ringkas)**

| # | Nama | Kelas | Catatan |
|---|------|-------|---------|
| 0 | `input_layer` | InputLayer | (None, 2, 1024, 1024, 1) |
| 1–4 | `time_distributed_42…45` | TimeDistributed | Conv2D dan MaxPooling2D per frame |
| 5, 7 | `conv_lstm2d_21, 22` | ConvLSTM2D | 128 dan 256 filter, `return_sequences=True` |
| 8 | `time_scalar` | InputLayer | (None, 1) |
| 10 | `dense_7` | Dense | 4096 unit |
| 11 | `conv_lstm2d_23` | ConvLSTM2D | 512 filter, `return_sequences=False` |
| 12–13 | `reshape_7`, `concatenate_11` | Reshape, Concatenate | Peta 64 × 64 disisipkan di lapisan tersempit |
| 15–27 | `skip_fusion_28…31` | Custom>SkipFusion | 256, 128, 64, 32 filter |
| 14–30 | `conv2d_transpose_4…7`, `conv2d_48…52` | Conv2DTranspose, Conv2D | Jalur pemulihan, ditutup aktivasi `tanh` |

Susunan lengkap ke-31 lapisan dapat dibaca langsung dari berkas bobot; yang
disajikan di sini adalah lapisan yang menentukan sifat model.

Tiga hal menentukan sifat model ini. Ketiga `ConvLSTM2D` adalah unsur
*spatio-temporal* yang sebenarnya, sebab ia memproses kedua frame sebagai
barisan sehingga hubungan antarframe ikut dipelajari, dan lapisan ketiga
meleburnya menjadi satu peta ciri. Pengondisian waktu disisipkan pada lapisan
tersempit melalui `Dense 4096` dan `Reshape 64 × 64`, sehingga posisi waktu
memengaruhi seluruh jalur pemulihan. Aktivasi keluarannya `tanh`, dan itulah
sebabnya normalisasi masukan wajib mengikuti rentang `[−1, 1]`.

```
x' = 2 · (x − x_min) / (x_max − x_min) − 1
```

dengan `x_min = 0` dan `x_max = 65535` sebagai konstanta global, bukan nilai
per citra, sebab normalisasi per citra akan membuat model kehilangan acuan
intensitas absolut yang bermakna secara fisika pada citra atenuasi.

Setiap contoh pelatihan disusun dari tiga frame nyata: model diberi frame ke-`i`
dan ke-`i+g`, diberi tahu `t = m/g`, lalu dituntut menghasilkan frame ke-`i+m`.

```
untuk g = 2 .. G_max
untuk i = 0 .. (N − g − 1)
untuk m = 1 .. (g − 1)
t = m / g
sampel ← (I_i, I_{i+m}, I_{i+g}, t)
```

Karena frame sasaran adalah hasil pindai yang sebenarnya, kebenaran acuan
tersedia tanpa pelabelan manual. Pada ragam **titik tengah saja** hanya
`t = 0,5` yang diambil, dan distribusi itulah dasar bobot awal sekaligus alasan
sistem harus berinterpolasi secara rekursif; pada ragam **`t` seimbang**
seluruh nilai `t = m/g` diambil, dan ragam kedua itulah tujuan penyempurnaan.

### 2.2.6 Fungsi Kerugian dan Optimasi

Fungsi kerugiannya galat absolut rerata, `L1 = (1/N) Σ |ŷ_p − y_p|`, dihitung
antara keluaran model dan frame acuan. L1 dipilih dan bukan L2 karena L1 kurang
menghukum galat besar yang jarang terjadi sehingga keluarannya lebih tajam,
sedangkan L2 mendorong model merata-ratakan kemungkinan dan menghasilkan citra
kabur (Isola dkk., 2017).

Pembaruan parameter memakai Adam (Kingma & Ba, 2015), yang memelihara rerata
bergerak momen pertama dan kedua dari gradien. Nilai `β₁` yang dipakai 0,5
mengikuti konvensi keluarga model pembangkit citra, sedangkan `β₂` dan `ε`
memakai nilai bawaan, dan laju pembelajaran `α` dapat diatur per sesi.

### 2.2.7 Metrik Evaluasi Kualitas Citra

Empat metrik dipakai. **MAE** `= (1/N) Σ |ŷ_p − y_p|` menyatakan rerata selisih
mutlak per piksel, **RMSE** `= √((1/N) Σ (ŷ_p − y_p)²)` lebih peka terhadap
galat besar, dan **PSNR** `= 10 log₁₀(MAX² / MSE)` menyatakan nisbah daya
sinyal puncak terhadap daya derau dalam desibel; nilai PSNR yang lebih tinggi
menandakan kemiripan lebih besar, dan ia tidak terdefinisi ketika kedua citra
identik.

**SSIM** menilai kemiripan struktural dengan membandingkan luminans, kontras,
dan struktur secara terpisah (Wang, Bovik, Sheikh, & Simoncelli, 2004).

```
PSNR = 10 · log₁₀ ( MAX² / MSE )
```

Nilai SSIM berkisar antara −1 dan 1. PSNR dan SSIM terdefinisi pada rentang
`[0, 1]` sementara model bekerja pada `[−1, 1]`, sehingga keluaran harus
dipetakan kembali sebelum diukur.

```
SSIM(x,y) = [ (2 μ_x μ_y + C₁)(2 σ_xy + C₂) ] / [ (μ_x² + μ_y² + C₁)(σ_x² +
σ_y² + C₂) ]
```

Kelalaian pada pemetaan itu menghasilkan angka yang tampak wajar namun keliru,
dan kekeliruannya tidak terlihat dari nilainya saja. Keempat metrik tersebut
baku pada penelitian rekonstruksi bersudut jarang; Lv dkk. (2025) memakai PSNR
dan SSIM sebagai dasar pembandingan. Yang ditambahkan penelitian ini adalah
pelaporan rentang nilai frame acuan di samping setiap angka, sebab galat yang
sama berarti berbeda pada rentang intensitas yang berbeda.

### 2.2.8 Arsitektur Hybrid Cloud-NAS

Arsitektur *hybrid cloud* memadukan komputasi lokal dan komputasi awan dalam
satu sistem, dengan pembagian tanggung jawab yang ditentukan sifat beban kerja
dan batasan tata kelola data; *Network Attached Storage* (NAS) adalah
penyimpanan yang terhubung ke jaringan lokal.

Pada penelitian ini pembagiannya ditentukan dua batasan yang tampak
bertentangan: inferensi menuntut kartu grafis yang tidak dimiliki perangkat
lokal, sedangkan data penelitian tidak boleh menetap di layanan pihak ketiga.
Penyelesaiannya menempatkan orkestrasi, basis data, dan seluruh penyimpanan
pada perangkat lokal beserta volume NAS, sementara yang menyeberang ke awan
hanya dua frame batas per panggilan dan hasilnya langsung ditarik kembali.

Konsekuensinya, layanan inferensi diperlakukan sebagai sesuatu yang dapat
hilang sewaktu-waktu. Demikian pula volume NAS: berbagi jaringan yang tidak
terpasang meninggalkan direktori kosong yang tampak sah, sehingga sistem harus
membedakan "belum ada berkas" dari "volume tidak terpasang".

### 2.2.9 Sistem Multiplatform

Sistem multiplatform dapat dijalankan pada beberapa lingkungan sasaran dari
satu basis kode. Aplikasi klien di sini dibangun dengan Flutter, yang
mengompilasi satu basis kode Dart menjadi aplikasi peramban dan Android.

Pendekatan itu dipilih karena kebutuhan penggunanya berpindah tempat: peneliti
mengunggah arsip dari komputer laboratorium melalui peramban, lalu memantau
proses yang berjalan puluhan menit dari telepon genggam. Dua basis kode
terpisah akan menuntut setiap perubahan dikerjakan dua kali. Pendekatan ini
telah dipakai pada rancang bangun sistem informasi di Indonesia (Rozi dkk.,
2025; Kurniawan dkk., 2025); yang belum ditunjukkan adalah kelayakannya ketika
sistem harus mengorkestrasi komputasi jarak jauh yang dapat berhenti
sewaktu-waktu, dan itulah yang diuji di sini.

### 2.2.10 Metode Prototyping

Prototyping membangun purwarupa sebagai sarana memperjelas kebutuhan yang
belum dapat dirumuskan lengkap di awal (Pressman & Maxim, 2020). Siklusnya
berulang melalui lima tahap: *communication*, *quick plan*, *modeling quick
design*, *construction of prototype*, serta *deployment, delivery & feedback*
yang mengumpulkan umpan balik bagi iterasi berikutnya.

Purwarupa sebuah siklus tidak selalu berlanjut menjadi produk akhir. Sebagian
**berkembang** menjadi sistem yang diserahkan, sebagian lagi **dibuang**
setelah menjawab pertanyaannya, dan Pressman dan Maxim (2020) menempatkan
keduanya sebagai keluaran yang wajar. Keduanya muncul di sini: sisi platform
dibangun secara berkembang, sedangkan percobaan penyempurnaan bobot pada
subbab 3.6.8 adalah purwarupa yang dibuang — diukur terhadap ambang yang
ditetapkan sebelum percobaan, lalu tidak dipasang karena tidak memenuhinya.
Hasil negatif yang terukur adalah keluaran yang sah dari satu iterasi.

Metode ini sesuai karena perilaku model terhadap arsip yang sebenarnya hanya
terungkap setelah dicoba, dan bentuk antarmuka yang berguna baru terlihat
setelah peneliti mencobanya langsung. Maharani dan Kurniawan (2025) melaporkan
siklus purwarupa menyingkap kebutuhan yang tidak terungkap pada analisis awal,
sementara Arwidiyarti dkk. (2026) memadukannya dengan evaluasi usability
sehingga umpan balik terukur — pola yang diikuti di sini melalui penyerahan
purwarupa pada setiap iterasi sebagaimana subbab 3.8.

## 2.3 Alasan Pemilihan Algoritma Spatio-Temporal U-Net

Pemilihan sebuah algoritma pada penelitian rancang bangun perlu dipertanggung-
jawabkan, bukan diwarisi. Subbab ini menguraikan mengapa Spatio-Temporal U-Net
yang dipakai, dengan alasan yang bertumpu pada bentuk persoalannya dan pada
pengukuran, bukan pada ketersediaan semata.

### 2.3.1 Bentuk persoalannya menuntut dua masukan yang berbeda jenis

Persoalan yang dihadapi bukan "ubah satu citra menjadi citra lain", melainkan
"diberi dua frame batas dan sebuah posisi waktu, hasilkan frame pada posisi
itu". Masukannya karena itu terdiri atas dua hal yang berbeda jenis: sebuah
tumpukan citra bersumbu waktu, dan sebuah bilangan.

Sebagian besar arsitektur pemetaan citra-ke-citra hanya menyediakan satu jalur
masukan. Spatio-Temporal U-Net menyediakan keduanya secara terpisah, yaitu
`InputLayer (2, 1024, 1024, 1)` untuk pasangan frame dan `InputLayer (1,)`
untuk skalar waktu, sebagaimana tercantum pada Tabel 2.3. Kesesuaian bentuk
ini yang menjadi alasan pertama, dan alasan yang paling menentukan.

### 2.3.2 Sumbu waktu diperlakukan sebagai barisan, bukan sebagai kanal

Cara paling sederhana memasukkan dua frame ke sebuah jaringan konvolusi adalah
menumpuknya sebagai dua kanal. Cara itu bekerja, tetapi memperlakukan kedua
frame sebagai dua lembar yang berdiri sendiri; hubungan antarkeduanya harus
disimpulkan jaringan dari penjajaran kanal.

Ketiga lapisan `ConvLSTM2D` pada arsitektur ini memprosesnya sebagai barisan
sehingga hubungan antarframe ikut dipelajari. Pada persoalan interpolasi
proyeksi, yang berubah antarframe adalah rotasi berkas terhadap objek yang
diam, dan hubungan itulah yang menjadi isi persoalannya.

### 2.3.3 Keluaran harus setajam masukan

Frame hasil interpolasi akan ikut direkonstruksi menjadi volume tiga dimensi.
Frame yang kabur karena itu bukan sekadar kurang enak dipandang; ia merusak
hasil rekonstruksi yang menjadi tujuan akhir seluruh proses.

Sambungan lompat pada U-Net menyalurkan peta ciri beresolusi tinggi langsung
dari jalur penyusutan ke jalur pemulihan, sehingga detail spasial halus tidak
hilang pada bagian tersempit jaringan (Ronneberger dkk., 2015). Sifat inilah
yang membuat U-Net menjadi tulang punggung pada hampir seluruh penelitian
pemetaan citra-ke-citra, termasuk yang berbasis pelatihan adversarial (Isola
dkk., 2017).

### 2.3.4 Alasan berbasis pengukuran, bukan dugaan

Alasan-alasan di atas bersifat struktural. Untuk mengujinya, keluaran model
dibandingkan terhadap pencampuran linier, yaitu rata-rata berbobot kedua frame
batas pada posisi waktu yang benar, pada lima kasus lintas tiga sampel
berbeda. Hasilnya telah disajikan pada Tabel 3.12 dan dirangkum di sini:

**Tabel 2. 4 Rangkuman Keunggulan Model terhadap Pencampuran Linier**

| Metrik | Model unggul |
|--------|-------------:|
| MAE | 1 dari 5 |
| PSNR | 0 dari 5 |
| **SSIM** | **5 dari 5** |

Pembacaannya menuntut kehati-hatian, dan justru di sinilah letak alasan
pemilihannya. Pada MAE dan PSNR, pencampuran linier unggul, dan itu memang
seharusnya terjadi. Rata-rata dua citra adalah tebakan yang meminimalkan galat
kuadrat, sehingga ia hampir selalu menang pada metrik berbasis selisih piksel,
dengan harga berupa citra yang kabur.

Pada SSIM, yang membandingkan luminans, kontras, dan struktur secara lokal
(Wang dkk., 2004), model unggul pada seluruh lima kasus. Selisihnya pun
bergerak sesuai dugaan: pada sampel berjarak dua derajat, tempat perubahan
antarframe kecil dan hampir linier, keunggulan model tipis, yaitu 0,0002
sampai 0,0003; pada kasus yang lebih sulit, yaitu Al Cu berjarak tiga derajat
dan Contrast dengan rentang enam frame, keunggulannya melebar menjadi 0,0064
dan 0,0091.

**Semakin jauh persoalannya dari pencampuran linier, semakin jelas model
dibutuhkan.** Kalimat itu adalah alasan pemilihan algoritma ini, dan ia
berasal dari pengukuran terhadap arsip BRIN yang sebenarnya.

### 2.3.5 Mengapa bukan metode interpolasi frame video yang lain

Metode interpolasi frame yang mapan pada ranah video, yaitu estimasi kernel
adaptif (Niklaus dkk., 2017), aliran optik dua arah (Jiang dkk., 2018), dan
estimasi aliran perantara (Huang dkk., 2022), seluruhnya bertumpu pada asumsi
**gerak objek** di dalam bidang citra, dan dirancang untuk citra tiga kanal
berkedalaman delapan bit.

Dua asumsi tersebut tidak berlaku di sini. Perubahan antarproyeksi bukan gerak
objek melainkan rotasi berkas terhadap objek yang diam, sehingga tidak ada
aliran optik yang bermakna untuk diperkirakan. Citranya pun satu kanal
berkedalaman enam belas bit, dengan perbedaan bermakna yang dapat terletak
pada selisih beberapa puluh satuan, dan perbedaan sekecil itu hilang
seluruhnya pada representasi delapan bit yang menjadi asumsi metode-metode
tersebut.

Pendekatan pada ranah tomografi bersudut jarang (Wu dkk., 2025; Zhang dkk.,
2025) lebih dekat karakteristik datanya, tetapi bekerja pada ranah
rekonstruksi, yaitu memperbaiki artefak pada volume hasil, sedangkan
penelitian ini bekerja satu langkah sebelumnya pada ranah proyeksi.

### 2.3.6 Kesinambungan dengan jalur riset yang sedang berjalan

Alasan terakhir bersifat praktis dan tidak kalah penting. Arsitektur ini sudah
memiliki bobot yang terlatih pada citra proyeksi neutron BRIN, sehingga
penelitian tidak dimulai dari keadaan kosong. Memilih arsitektur lain berarti
melatih dari nol pada domain yang datanya terbatas dan mahal diperoleh, dengan
hasil yang hampir pasti lebih buruk dan tanpa kesinambungan dengan jalur riset
yang sedang berjalan di BRIN.

## 2.4 Kerangka Berpikir

Kerangka berpikir penelitian ini menghubungkan tiga hal: keterbatasan yang
melahirkan celah pada barisan proyeksi, proses yang dikerjakan untuk
mengatasinya, dan keluaran yang diharapkan.

**[GAMBAR 2. 2 — Kerangka Berpikir Penelitian]**
*Gambarkan diagram alir tiga kolom.*

Masalahnya berpangkal pada waktu berkas neutron yang terbatas dan dijadwalkan
ketat, yang melahirkan celah baik karena jarak sudut sengaja diperlebar maupun
karena proyeksi gagal terekam. Pengisian manual tidak konsisten dan tidak dapat
diulang, sementara inferensi model menuntut kartu grafis yang tidak dimiliki
laboratorium dan data penelitian tidak boleh berpindah ke pihak ketiga.

Prosesnya menempuh analisa sistem berjalan dan sistem usulan, perancangan
sistem multiplatform di atas arsitektur *hybrid cloud-NAS*, analisa perilaku
model terhadap arsip BRIN yang sebenarnya, perancangan interpolasi rekursif
beserta pencatatan asal-usul frame, dan validasi *hold-out* pada setiap iterasi
Prototyping.

Keluaran yang diharapkan adalah sistem multiplatform terintegrasi yang mengisi
celah secara otomatis, batas keberlakuan model yang terukur alih-alih
ditafsirkan, dan frame hasil yang disertai asal-usul serta angka mutu sehingga
peneliti yang menerimanya memiliki dasar untuk mempertahankan hasil tersebut.

# BAB III
# ANALISA DAN PERANCANGAN

## 3.1 Alur Penelitian

Penelitian ini menggunakan metode pengembangan Prototyping. Alur penelitian
disusun mengikuti siklus metode tersebut, dengan pengujian yang dilakukan
langsung terhadap arsip citra neutron dan kartu grafis yang sebenarnya pada
setiap iterasi.

**[GAMBAR 3. 1 — Alur Penelitian]**
*Gambarkan diagram alir vertikal dengan tahapan berikut: Studi Pendahuluan dan Observasi → Pengumpulan Data Citra → Analisa Kebutuhan (Communication) → Perencanaan Cepat (Quick Plan) → Pemodelan Rancangan Cepat (Modeling Quick Design) → Pembangunan Purwarupa (Construction of Prototype) → Penyerahan dan Umpan Balik (Deployment, Delivery & Feedback) → titik keputusan "Kebutuhan terpenuhi?" dengan cabang "Tidak" kembali ke Perencanaan Cepat dan cabang "Ya" menuju Pengujian dan Evaluasi → Penyusunan Laporan.*

Alur ini bersifat berulang pada bagian tengahnya. Setiap kali purwarupa
diserahkan dan dicoba, umpan balik yang diperoleh menjadi masukan bagi iterasi
berikutnya. Perulangan berhenti ketika kebutuhan yang disepakati telah
terpenuhi dan hasil pengujian mutu telah memadai.

## 3.2 Metode Pengumpulan Data

Data yang digunakan dalam penelitian ini dikumpulkan melalui empat metode
sebagai berikut:

**1. Observasi**

Observasi dilakukan terhadap alur kerja akuisisi citra proyeksi di fasilitas
pencitraan neutron BRIN Puspiptek. Pengamatan mencakup format berkas keluaran
perangkat akuisisi, pola penomoran proyeksi, letak dan lebar celah pada
barisan yang tersedia, ukuran berkas per frame, serta perangkat dan perangkat
lunak yang digunakan peneliti untuk mengolah hasil pemindaian. Hasil observasi
menjadi dasar penentuan format masukan yang diterima sistem dan aturan
validasi arsip.

**2. Wawancara**

Wawancara dilakukan kepada peneliti dan operator fasilitas untuk memperoleh
informasi mengenai penjadwalan waktu berkas neutron, penyebab hilangnya
proyeksi selama akuisisi, cara penanganan celah yang berjalan saat ini, serta
kebutuhan terhadap sistem yang akan dibangun. Wawancara juga menjadi sarana
pengumpulan umpan balik pada setiap iterasi Prototyping.

**3. Dokumentasi**

Dokumentasi merupakan metode pengumpulan data utama, berupa arsip citra
proyeksi tomografi komputer neutron dari pemindaian yang telah dilakukan.
Setiap arsip disertai pencatatan kondisi akuisisi menggunakan format pada
Tabel 3.1.

**Tabel 3. 1 Format Pencatatan Kondisi Akuisisi Citra**

| Kode Arsip | Objek | Jumlah Frame | Resolusi | Kedalaman Bit | Rentang Nilai | Jarak Sudut | Letak Celah |
|------------|-------|--------------|----------|---------------|---------------|-------------|-------------|
| A-01 | – | – | 1024 × 1024 | 16 bit | – | – | – |
| A-02 | – | – | 1024 × 1024 | 16 bit | – | – | – |
| … | … | … | … | … | … | … | … |

Pencatatan ini wajib dilakukan karena rentang nilai dan letak celah menentukan
pembentukan sampel pelatihan maupun skenario pengujian, dan keduanya tidak
dapat ditelusuri kembali dengan mudah setelah arsip tercampur.

**4. Studi Pustaka**

Studi pustaka dilakukan dengan menelaah buku, jurnal, dan prosiding yang
berkaitan dengan tomografi komputer, pencitraan neutron, interpolasi frame,
arsitektur U-Net, serta metrik evaluasi kualitas citra. Sumber acuan
diutamakan yang terbit lima tahun terakhir dan memiliki ISSN atau DOI, kecuali
publikasi asli arsitektur dan metrik yang menjadi dasar penelitian.

## 3.3 Analisa Sistem yang Sedang Berjalan

### 3.3.1 Prosedur Akuisisi dan Penanganan Celah Saat Ini

Peneliti mengajukan jadwal penggunaan waktu berkas neutron, kemudian
melaksanakan pemindaian dengan jarak sudut yang telah ditetapkan. Perangkat
akuisisi menuliskan setiap proyeksi sebagai berkas TIFF 16-bit dengan
penomoran berurutan. Setelah pemindaian selesai, peneliti memeriksa
kelengkapan barisan secara manual dengan menelusuri penomoran berkas.

Apabila ditemukan celah, terdapat tiga pilihan yang selama ini ditempuh, dan
ketiganya memiliki kelemahan. Pilihan pertama adalah melanjutkan rekonstruksi
dengan barisan yang tidak lengkap, dengan konsekuensi munculnya artefak.
Pilihan kedua adalah mengisi celah dengan penggandaan atau pencampuran linier
frame tetangga menggunakan perangkat lunak pengolah citra umum, yang hasilnya
kabur dan tidak konsisten antarpeneliti. Pilihan ketiga adalah mengulang
pemindaian, yang berarti mengantre waktu berkas dari awal.

**[GAMBAR 3. 2 — Alur Akuisisi Proyeksi Tomografi Neutron Saat Ini]**
*Gambarkan diagram alir: Pengajuan Jadwal Waktu Berkas → Pemindaian → Penulisan Berkas TIFF Bernomor → Pemeriksaan Kelengkapan Manual → titik keputusan "Ada celah?" dengan cabang "Tidak" menuju Rekonstruksi, dan cabang "Ya" bercabang tiga menuju Lanjut dengan Barisan Tidak Lengkap, Pengisian Manual, serta Pemindaian Ulang.*

### 3.3.2 Permasalahan pada Sistem Berjalan

**Tabel 3. 2 Analisa Permasalahan Sistem Berjalan**

| Permasalahan | Dampak |
|--------------|--------|
| Waktu paparan per proyeksi panjang dan waktu berkas terbatas | Jarak sudut terpaksa diperlebar, mutu rekonstruksi menurun |
| Sebagian proyeksi hilang atau rusak saat akuisisi | Barisan tidak lengkap, dan pengulangan menuntut antrean waktu berkas dari awal |
| Pemeriksaan kelengkapan barisan dilakukan manual | Menyita waktu peneliti dan rawan terlewat pada arsip berjumlah ratusan frame |
| Pengisian celah dengan pencampuran linier | Menghasilkan citra kabur yang justru menambah artefak pada rekonstruksi |
| Pengisian celah dikerjakan tiap peneliti dengan caranya sendiri | Hasil tidak konsisten antarpeneliti dan tidak dapat diulang |
| Tidak ada catatan asal-usul frame | Peneliti penerima tidak dapat membedakan frame hasil pindai dari frame buatan |
| Tidak ada angka mutu yang menyertai hasil | Hasil interpolasi tidak memiliki dasar untuk dipertahankan secara ilmiah |
| Pengolahan terikat pada satu komputer tertentu | Proses berjalan lama tidak dapat dipantau dari perangkat lain |

## 3.4 Analisa Sistem yang Diusulkan

Sistem yang diusulkan menerima arsip berisi frame proyeksi bernomor, mengenali
celah dari penomorannya, mengisi celah tersebut dengan model Spatio-Temporal
U-Net, lalu mengembalikan barisan yang telah lengkap beserta catatan asal-usul
dan angka mutu setiap frame yang dihasilkan.

**[GAMBAR 3. 3 — Arsitektur Sistem yang Diusulkan]**
*Gambarkan diagram arsitektur berlapis.*

**[GAMBAR 3. 4 — Alur Kerja Sistem yang Diusulkan]**
*Bagan alir alur kerja sesudah sistem dan model tersedia, sebagai pasangan Gambar 3.2 yang menggambarkan alur manual.*

Alur kerja sistem yang diusulkan adalah sebagai berikut:

1. Peneliti masuk melalui aplikasi peramban atau Android, lalu mengunggah
   arsip `.zip` berisi frame proyeksi bernomor. Arsip berukuran besar
   diunggah secara berpotongan agar sambungan yang terputus dapat
   dilanjutkan.

2. Peladen mengekstraksi frame, memvalidasi format dan penomorannya,
   kemudian menampilkan pratinjau agar peneliti dapat memeriksa arsipnya
   sebelum pekerjaan dijalankan.

3. Peneliti menekan tombol mulai. Pekerjaan masuk ke antrean dengan
   posisinya, dan perkiraan waktu tunggu dihitung dari lama pekerjaan yang
   benar-benar pernah terukur pada sistem ini.

4. Pekerja antrean mengisi celah secara rekursif dengan memanggil layanan
   inferensi untuk setiap pasangan batas, dan mencatat asal-usul setiap
   frame yang dihasilkan.

5. Apabila arsip mengandung frame yang merupakan titik tengah tepat dari dua
   frame lain, frame tersebut disembunyikan, dibangkitkan ulang oleh model,
   lalu dibandingkan terhadap aslinya sebagai validasi *hold-out*.

6. Hasil dikemas kembali menjadi arsip yang dapat diunduh, disertai berkas
   metadata dan manifes yang memuat asal-usul serta angka mutu.

## 3.5 Perancangan Sistem

Penelitian ini adalah rancang bangun, sehingga rancangan sistemnya merupakan
hasil utama yang sejajar dengan modelnya, bukan lampiran yang menyertai.
Subbab ini menguraikan rancangan tersebut dari lapisan terluar ke dalam:
susunan perangkat lunak, kewenangan setiap aktor, alur kerja yang dijalankan,
penyimpanan datanya, kontrak antarmuka pemrogramannya, dan tampilan yang
dilihat pengguna.

### 3.5.1 Perancangan Arsitektur Perangkat Lunak

Sistem disusun atas tiga lapisan yang berjalan pada mesin berbeda sebagaimana
digambarkan pada Gambar 3.3. Pembagiannya ditentukan oleh satu batasan yang
tidak dapat ditawar: berkas penelitian harus tetap berada pada penyimpanan
milik institusi, sementara kartu grafis yang dibutuhkan untuk inferensi tidak
dimiliki mesin lokal.

1. **Lapisan klien**, berupa aplikasi Flutter yang dikompilasi menjadi
   aplikasi peramban dan aplikasi Android dari satu basis kode. Lapisan ini
   tidak menyimpan berkas penelitian dan tidak memuat logika pengolahan citra;
   ia hanya menampilkan keadaan dan mengirimkan perintah. 2. **Lapisan peladen
   lokal**, berupa Laravel 12 di atas Octane dan RoadRunner, basis data MySQL
   8, antrean pekerjaan, serta volume NAS. Seluruh berkas proyeksi, hasil
   interpolasi, dan arsip data latih hanya ada di sini. 3. **Lapisan komputasi
   awan**, berupa layanan inferensi dan pelatihan berbasis FastAPI yang
   berjalan di atas kartu grafis, dijangkau melalui terowongan berdomain
   tetap.

Yang menyeberang ke lapisan awan hanyalah dua frame batas beserta satu skalar
waktu pada setiap panggilan inferensi, dan hasilnya langsung ditarik kembali.
Karena lapisan awan bukan milik institusi dan sesinya dapat berakhir sendiri,
seluruh rancangan di bawah ini memperlakukan layanan model sebagai sumber daya
yang boleh hilang sewaktu-waktu, bukan sebagai dependensi yang pasti tersedia.

### 3.5.2 Perancangan Use Case

Sistem melayani dua peran manusia dan satu pelaku bukan manusia. Kewenangan
masing-masing disajikan pada Tabel 3.3.

**[GAMBAR 3. 5 — Diagram Use Case Sistem]**
*Gambarkan diagram use case dengan tiga aktor.*

**Tabel 3. 3 Aktor dan Kewenangannya**

| Aktor | Kewenangan | Batasan |
|-------|-----------|---------|
| Peneliti | Mengunggah arsip proyeksi, menjalankan pengisian celah, menelusuri dan mengunduh hasil, memulai serta memantau sesi pelatihan | Hanya dapat melihat dan mengunduh berkas miliknya sendiri |
| Administrator | Mengelola akun pengguna, mendaftarkan dan menyunting model beserta alamat layanannya, memantau antrean seluruh pengguna dan keadaan volume penyimpanan, mendaftarkan bobot hasil pelatihan menjadi model yang dapat dipakai | Tidak dapat menjalankan pekerjaan atas nama peneliti lain |
| Pekerja GPU | Mengambil pekerjaan pelatihan dari antrean, melaporkan denyut, mengirimkan titik simpan, metrik, dan bobot akhir | Diautentikasi dengan kunci bersama, bukan token pengguna; tidak memiliki akses ke berkas pengguna mana pun |

Pemisahan kewenangan ini bukan formalitas. Arsip proyeksi adalah data
penelitian yang belum diterbitkan, sehingga kemampuan membaca berkas milik
akun lain harus tertutup bahkan bagi administrator.

### 3.5.3 Perancangan Aktivitas

**[GAMBAR 3. 6 — Diagram Aktivitas Pengisian Celah Proyeksi]**
*Gambarkan diagram aktivitas dengan tiga kolom renang: Peneliti, Peladen Lokal, dan Layanan Inferensi.*

Simpul keputusan yang kembali ke layanan inferensi adalah tempat sifat
rekursif algoritma tampak pada tingkat sistem: satu pekerjaan dapat memanggil
layanan inferensi berkali-kali, dan jumlah panggilannya ditentukan oleh lebar
celah, bukan oleh jumlah frame yang diunggah.

### 3.5.4 Perancangan Basis Data

**[GAMBAR 3. 7 — Diagram Relasi Antar-Entitas]**
*Gambarkan diagram relasi antar-entitas dengan entitas users, models, analysis_records, training_datasets, training_jobs, training_metrics, training_samples, dan user_activities.*

**Tabel 3. 4 Rancangan Tabel Basis Data**

| Tabel | Isi |
|-------|-----|
| `users`, `access_requests` | Akun beserta perannya, dan permintaan yang menunggu persetujuan |
| `models` | Model terdaftar, alamat layanan inferensinya, keadaan ketersediaannya |
| `analysis_records` | Satu baris per pekerjaan interpolasi beserta keadaan dan asal-usul hasilnya |
| `training_datasets`, `training_jobs` | Arsip data latih dan sesi pelatihan beserta titik simpannya |
| `training_metrics`, `training_samples` | Metrik dan contoh keluaran per epoch |
| `user_activities`, `notifications`, `conversations`, `messages`, `news_posts` | Penelusuran, pemberitahuan, percakapan, dan pengumuman |

Dua rancangan pada tabel di atas menjawab keadaan yang khas pada sistem ini.
Pertama, `analysis_records` dan `training_datasets` menyimpan penanda waktu
penghapusan berkas (`files_deleted_at` dan `archive_deleted_at`) alih-alih
menghapus barisnya, sehingga riwayat pekerjaan tetap dapat ditelusuri setelah
berkasnya dibersihkan menurut kebijakan retensi. Kedua, `training_jobs`
menyimpan `checkpoint_path`, `current_epoch`, dan `heartbeat_at`, yang
bersama-sama memungkinkan sebuah sesi pelatihan dilanjutkan oleh pekerja lain
setelah sesi awan sebelumnya berakhir.

### 3.5.5 Perancangan Antarmuka Pemrograman Aplikasi

Seluruh komunikasi antara lapisan klien dan lapisan peladen berlangsung
melalui antarmuka pemrograman aplikasi bergaya REST dengan autentikasi token.
Kontrak utamanya disajikan pada Tabel 3.5.

**Tabel 3. 5 Rancangan Antarmuka Pemrograman Aplikasi**

| Kelompok | Kegunaan | Pemanggil |
|----------|----------|-----------|
| Autentikasi dan akun | Masuk, keluar, ganti sandi, berkas profil | Semua |
| Unggah dan pekerjaan | Unggah berpotongan, buat pekerjaan, keadaan, frame, unduh hasil | Peneliti |
| Pelatihan model | Unggah data latih, mulai sesi, kemajuan per epoch, titik simpan | Peneliti dan pekerja |
| Pengelolaan model | Daftar model, alamat layanan, pemeriksaan ketersediaan | Administrator |
| Administrasi | Pengguna, permintaan akses, antrean seluruh pengguna, penyimpanan | Administrator |
| Komunikasi | Percakapan, pemberitahuan, pengumuman | Semua |

Unggahan dirancang berpotongan sejak awal karena arsip proyeksi merupakan
berkas terbesar yang diterima sistem ini, dan sambungan yang terputus di
tengah unggahan berukuran ratusan megabita tidak boleh memaksa peneliti
mengulang dari nol.

### 3.5.6 Perancangan Pratinjau Frame Berkedalaman 16 Bit

Peneliti harus dapat memeriksa frame sebelum menjalankan pekerjaan dan
sesudahnya, sementara TIFF 16-bit tidak dapat ditampilkan langsung oleh
peramban maupun aplikasi bergerak sebagaimana diuraikan pada subbab 2.2.2.
Peladen karena itu menyediakan layanan pratinjau yang mengubah satu frame
menjadi PNG delapan bit atas permintaan.

Peladen pada penelitian ini tidak memiliki ekstensi pengolah citra bawaan,
sehingga pembacaan TIFF dan penulisan PNG dikerjakan langsung dari byte-nya.
Keputusan ini dapat diambil karena berkas masukannya sempit dan dapat
diramalkan, yaitu TIFF satu kanal tanpa pemampatan, sehingga bentuk di luar
itu ditolak dengan pesan, bukan ditebak.

Tiga keputusan rancangan menentukan mutu keluarannya:

1. **Pemetaan berjendela.** Nilai piksel dipetakan ke rentang 0–255
   berdasarkan nilai terkecil dan terbesar frame itu sendiri, bukan
   berdasarkan rentang penuh 16 bit. Tanpa itu sebagian besar frame terlihat
   nyaris hitam. 2. **Penyusutan dengan perataan kotak.** Frame diperkecil
   dengan merata-ratakan blok piksel, bukan dengan membuang piksel. Pembuangan
   piksel membuat derau pada citra neutron tampak seperti struktur, yang
   justru menyesatkan pembacaan. 3. **Pembacaan per blok.** Piksel
   diperlakukan sebagai untai byte dan dibuka per blok, bukan dijadikan larik
   sebesar jumlah piksel. Pada frame 2048 × 2048, pendekatan larik menuntut
   sekitar 196 MB sedangkan pembacaan per blok menuntut sekitar 11,7 MB.
   Selisih itu yang menentukan apakah pekerja antrean bertahan atau berhenti
   di tengah jalan.

Batas ukuran frame yang dapat dipratinjau ditetapkan 4096 × 4096 piksel. Frame
yang melampauinya ditolak **hanya pratinjaunya**; berkas frame itu sendiri
tetap dapat diunduh utuh.

### 3.5.7 Perancangan Ketahanan Sistem dan Tata Kelola Berkas

Layanan komputasi berada pada infrastruktur yang bukan milik institusi dan
sesinya berakhir dengan sendirinya. Sistem karena itu tidak dirancang dengan
asumsi bahwa layanan model selalu tersedia, melainkan dengan asumsi
sebaliknya. Mekanisme yang menanganinya disajikan pada Tabel 3.6.

**Tabel 3. 6 Mekanisme Ketahanan Sistem**

| Keadaan | Cara Mengenali | Tindakan Sistem | Yang Dilihat Pengguna |
|---------|----------------|-----------------|------------------------|
| Layanan model tidak tersedia | Pemeriksaan ketersediaan berkala terhadap alamat layanan; terowongan yang mati dikenali dari kepala galat pada jawabannya | Model ditandai luring beserta sebabnya, dan pekerjaan baru tidak diterima | Penanda ketersediaan pada pemilih model, disertai kalimat yang menyebutkan sebabnya |
| Sesi pelatihan berakhir di tengah jalan | Denyut dari pekerja berhenti melewati tenggang waktu yang ditetapkan | Pekerjaan dikembalikan ke antrean beserta titik simpan dan nomor epoch terakhirnya | Sesi pelatihan tampak menunggu pekerja, bukan gagal |
| Unggahan terputus | Sesi unggah tercatat di perangkat beserta sidik jari arsipnya | Unggahan dilanjutkan dari potongan terakhir yang diterima peladen | Tawaran melanjutkan unggahan, bukan permintaan mengulang dari nol |
| Arsip yang dipilih bukan arsip semula | Sidik jari arsip tidak cocok dengan yang tercatat pada sesi | Sesi ditolak dilanjutkan | Pesan bahwa berkas yang dipilih berbeda, disertai pilihan membuang sesi lama |
| Pekerja antrean tidak berjalan | Pekerjaan tersedia lebih dari satu menit tanpa pernah diambil | Keadaan antrean ditandai tersendat | Kalimat yang menyebutkan antrean tersendat, bukan penanda menunggu yang tak berubah |
| Volume penyimpanan tidak terpasang | Berkas penanda pada volume tidak ditemukan | Sistem menolak menerima maupun menjalankan pekerjaan | Pesan bahwa penyimpanan tidak tersedia, bukan kegagalan yang tidak dijelaskan |

Perbedaan antara kolom terakhir dan kolom sebelumnya adalah inti rancangan
ini. Setiap keadaan yang menghambat dinyatakan dengan kalimat yang menyebutkan
sebabnya. Antrean yang tersendat karena pekerja mati dan antrean yang panjang
karena banyak pekerjaan terlihat sama persis dari daftar pekerjaan yang
menunggu, padahal keduanya menuntut tindakan yang berlawanan.

**Tata kelola berkas.** Berkas penelitian menumpuk jauh lebih cepat daripada
yang diperkirakan, sehingga retensinya dirancang sejak awal:

1. **Hasil prediksi disimpan 24 jam.** Hasil adalah berkas yang diunduh
   sekali, dan menyimpannya lebih lama hanya memenuhi volume. Barisnya tetap
   ada beserta penanda waktu penghapusan berkasnya, sehingga riwayat pekerjaan
   tidak hilang. 2. **Arsip data latih disimpan 30 hari, dihitung dari
   pemakaian terakhir.** Pilihan ini disengaja: data latih diunggah ke
   platform justru agar dapat dipakai ulang antar sesi pelatihan, sehingga jam
   yang berjalan sejak pengunggahan akan menghapus arsip yang justru sedang
   sering dilatih. Arsip yang masih terikat sesi pelatihan menunggu atau
   berjalan tidak pernah disapu, seberapa lama pun umurnya. 3. **Penghapusan
   tidak menghapus catatan.** Yang dihapus adalah berkasnya; baris basis
   datanya tetap dan distempel waktu penghapusan, sehingga peneliti yang
   membuka pekerjaan lama memperoleh keterangan bahwa berkasnya telah melewati
   masa simpan, bukan daftar kosong yang tidak dapat dibedakan dari arsip yang
   memang tidak berisi.

### 3.5.8 Perancangan Antarmuka Pengguna


**[GAMBAR 3. 8 — Rancangan Antarmuka Unggah dan Pratinjau Frame]**
*Gambarkan tata letak layar unggah: area pemilihan berkas dengan indikator kemajuan unggah berpotongan, daftar frame yang terbaca beserta nomornya, penanda celah pada barisan, penelusur tumpukan frame dengan penggeser dan kemampuan perbesar, serta tombol mulai analisis.*

**[GAMBAR 3. 9 — Rancangan Antarmuka Pemantauan Pelatihan Model]**
*Gambarkan tata letak layar pelatihan: kartu memulai sesi pelatihan berisi nama sesi dan jumlah epoch, daftar sesi berjalan beserta kemajuannya, tabel metrik per epoch dengan kolom MAE, MSE, PSNR, dan SSIM, serta penelusur gambar contoh keluaran model per epoch.*

Antarmuka dibangun dari satu basis kode Flutter yang dikompilasi menjadi
aplikasi peramban dan aplikasi Android. Dua pertimbangan rancangan yang
menentukan adalah keterbacaan status dan kejujuran pesan. Setiap pekerjaan
yang menunggu menampilkan posisinya dalam antrean dan perkiraan waktu tunggu yang dihitung dari lama pekerjaan yang benar-benar pernah terukur; dan
setiap keadaan yang menghambat, seperti layanan inferensi yang tidak tersedia,
pekerja antrean yang tidak berjalan, atau volume penyimpanan yang tidak
terpasang, dinyatakan dengan kalimat yang menyebutkan sebabnya, bukan
dibiarkan tampak sebagai antrean yang sedang berjalan.

### 3.5.9 Alasan Pemilihan Arsitektur dan Peranti

Sebagaimana pemilihan algoritma dipertanggungjawabkan pada subbab 2.3,
keputusan rancang bangun pada subbab ini juga perlu dipertanggungjawabkan.
Empat keputusan yang paling menentukan diuraikan berikut, masing-masing dengan alternatif yang ditolak dan alasan penolakannya.

#### a. Mengapa hybrid cloud-NAS, bukan seluruhnya awan

Menempatkan seluruh sistem di layanan awan adalah pilihan yang paling
sederhana secara teknis: satu lingkungan, satu penyebaran, tidak ada
terowongan. Pilihan itu ditolak karena satu alasan yang tidak dapat ditawar.
Arsip proyeksi adalah data penelitian yang belum diterbitkan, dan
menempatkannya pada penyimpanan pihak ketiga berarti memindahkan kendali
atasnya ke luar institusi.

Rancangan yang diambil memisahkan keduanya: seluruh berkas, basis data, dan
antrean berada pada infrastruktur lokal beserta volume NAS, sedangkan yang
menyeberang ke awan hanya dua frame batas beserta satu skalar waktu pada
setiap panggilan, dan hasilnya langsung ditarik kembali.

#### b. Mengapa tidak seluruhnya lokal

Kebalikannya, yaitu menjalankan segalanya di mesin lokal, akan menghapus
seluruh kerumitan terowongan dan ketergantungan pada sesi awan. Pilihan itu
ditolak karena mesin yang tersedia tidak memiliki kartu grafis, dan selisihnya
terukur.

**Tabel 3. 7 Waktu Satu Inferensi pada Lingkungan Lokal dan Awan**

| Lingkungan | Waktu satu inferensi |
|------------|---------------------:|
| Prosesor mesin lokal | ± 150 detik |
| Kartu grafis pada layanan awan | ± 18 detik |

Selisih delapan kali lipat itu menentukan apakah sistem dapat dipakai. Sebuah
celah selebar delapan langkah menuntut tujuh panggilan; pada mesin lokal itu
berarti menunggu tujuh belas menit untuk satu pekerjaan, dan sebuah barisan
proyeksi utuh berisi ratusan celah.

#### c. Mengapa satu basis kode untuk dua peron

Kebutuhan penggunanya berpindah tempat: peneliti mengunggah arsip dari
komputer laboratorium melalui peramban, lalu memantau pekerjaan yang berjalan
puluhan menit dari telepon genggam. Dua basis kode terpisah untuk alur kerja
yang sama akan menuntut setiap perubahan dikerjakan dua kali, dengan risiko
kedua sisi menyimpang.

Pendekatan satu basis kode dengan Flutter telah dipakai pada rancang bangun
sistem informasi lain di Indonesia (Rozi dkk., 2025; Kurniawan dkk., 2025).
Yang berbeda pada penelitian ini adalah sistemnya harus mengorkestrasi
komputasi jarak jauh yang dapat berhenti sewaktu-waktu, dan itulah yang diuji
di sini.

Perbedaan perilaku antarperon dibatasi pada hal yang memang berbeda secara
mendasar, yaitu cara berkas dipilih dan cara berkas diunduh, dan diselesaikan
melalui pemisahan implementasi pada berkas terpisah.

#### d. Mengapa peladen dengan proses pekerja yang tetap hidup

Layanan API dijalankan di atas Octane dan RoadRunner, bukan model satu proses
per permintaan yang lazim pada PHP. Alasannya adalah beban kerja yang
ditangani sistem ini: pembacaan TIFF 16-bit, penyusunan ulang barisan frame,
dan pengemasan arsip hasil. Proses yang dimuat ulang pada setiap permintaan
akan membayar biaya penyalaan berulang kali untuk pekerjaan yang berumur
menit.

Konsekuensinya diterima dan didokumentasikan: proses pekerja yang tetap hidup
memuat kelas satu kali pada saat mulai, sehingga berkas yang disunting tidak
terlihat sampai pekerjanya didaur ulang. Ini bukan kelemahan yang tersembunyi,
melainkan syarat operasional yang harus diketahui siapa pun yang mengembangkan
sistem ini.

#### e. Mengapa prototyping, bukan model proses berurutan

Model proses berurutan menuntut kebutuhan dirumuskan lengkap sebelum
pembangunan dimulai. Pada penelitian ini kebutuhan itu tidak dapat dirumuskan
lengkap di awal, dan bukti paling jelasnya muncul dari pelaksanaannya sendiri:
keempat batas perilaku model pada subbab 3.6.6 baru terungkap setelah sistem berjalan
dan diukur terhadap arsip sungguhan, bukan dari kajian pustaka.

Batas-batas itu kemudian mengubah rancangan, dan dari situlah lahir pencatatan
asal-usul frame serta batas kelayakan pada subbab 3.6.8. Sebuah rancangan yang
dibekukan di awal tidak akan memiliki jalan untuk menyerap temuan semacam itu.
Metode prototyping menyediakan jalan tersebut, dan penerapannya beserta
evaluasi pengguna telah ditunjukkan pada penelitian sejenis (Maharani &
Kurniawan, 2025; Arwidiyarti dkk., 2026).

## 3.6 Analisa Model dan Rancangan Pemanfaatannya

Subbab sebelumnya merancang sistem yang mewadahi pekerjaan; subbab ini
berurusan dengan mesin yang mengerjakannya. Keduanya perlu dibedakan dengan
tegas, sebab kedudukan penelitian ini terhadap keduanya tidak sama.

Bobot model bukan hasil penelitian ini. Bobot tersebut diperoleh melalui
kolaborasi dengan BRIN dan arsitekturnya tidak diubah. Yang dirancang pada
penelitian ini adalah cara sistem memakainya: bagaimana data citra disiapkan,
bagaimana sesi pelatihan dijalankan dari sisi peneliti, bagaimana celah diisi
secara rekursif, dan bagaimana mutu keluarannya diukur. Keempatnya diuraikan
pada subbab 3.6.1 sampai 3.6.5.

Selebihnya bersifat analisa. Sebuah komponen yang tidak dibuat sendiri harus
diketahui lebih dahulu perilakunya sebelum sistem dapat dirancang di
sekelilingnya, dan kedudukannya sama dengan analisa terhadap sistem berjalan
pada subbab 3.3. Subbab 3.6.6 sampai 3.6.8 memuat pengukuran perilaku tersebut dan keputusan rancangan yang lahir darinya, dan keputusan itulah yang
menjadikannya bagian dari perancangan, bukan sekadar laporan hasil.

### 3.6.1 Rancangan Pengolahan Data Citra

Data citra dibagi menjadi tiga bagian dengan fungsi yang berbeda sebagaimana
disajikan pada Tabel 3.8.

**Tabel 3. 8 Pembagian Data Citra**

| Jenis Data | Fungsi | Keterangan |
|------------|--------|------------|
| Data latih | Penyempurnaan bobot model | Barisan proyeksi lengkap tanpa celah, sehingga setiap frame antara tersedia sebagai kebenaran acuan |
| Data validasi | Pemantauan mutu per epoch | Terpisah dari data latih; menghasilkan metrik MAE, MSE, PSNR, dan SSIM yang dicatat setiap epoch |
| Data uji | Pengujian sistem ujung ke ujung | Arsip bercelah yang menyerupai keadaan nyata, beserta arsip lengkap untuk validasi *hold-out* |

Pemisahan data validasi dari data latih bersifat wajib. Metrik yang dihitung
pada data yang sama dengan data pelatihan akan menyatakan seberapa baik model
menghafal, bukan seberapa baik model bekerja.

Setiap frame yang masuk diverifikasi format dan penomorannya. Frame yang bukan
TIFF 16-bit satu kanal, tidak memuat nomor pada namanya, atau melebihi batas
ukuran akan dikeluarkan dari kumpulan data dan jumlahnya dicatat sebagai
bagian dari hasil penelitian.

### 3.6.2 Rancangan Praproses

**Tabel 3. 9 Tahapan Praproses Citra**

| Tahap | Proses | Keluaran |
|-------|--------|----------|
| 1 | Ekstraksi arsip `.zip` dan perataan struktur folder | Kumpulan berkas `.tif` pada satu direktori |
| 2 | Penyaringan berkas bukan TIFF dan berkas tersembunyi | Hanya frame proyeksi yang tersisa |
| 3 | Pembacaan nomor proyeksi dari nama berkas | Barisan terurut beserta letak celahnya |
| 4 | Pemuatan citra sebagai skala keabuan 16-bit | Larik `1024 × 1024` bertipe bilangan riil |
| 5 | Pengubahan ukuran ke `1024 × 1024` bila perlu | Ukuran masukan yang seragam |
| 6 | Normalisasi global ke rentang `[−1, 1]` | Citra siap dimasukkan ke model |

Perataan struktur folder pada tahap 1 diperlukan karena arsip yang disusun
peneliti kerap menempatkan frame di dalam subfolder, sementara penomoran
proyeksi berlaku lintas folder.

### 3.6.3 Rancangan Pelatihan Model

Pelatihan bersifat penyempurnaan dari bobot dasar yang telah ada, bukan
pelatihan dari inisialisasi acak. Hiperparameter yang digunakan disajikan pada
Tabel 3.10.

**Tabel 3. 10 Hiperparameter Pelatihan Model**

| Parameter | Nilai | Keterangan |
|-----------|-------|------------|
| Arsitektur | Spatio-Temporal U-Net | ± 21,9 juta parameter terlatih |
| Ukuran masukan | 2 × 1024 × 1024 + skalar `t` | Dua frame batas dan posisi waktu |
| Normalisasi | `[−1, 1]` dengan konstanta global 0 dan 65535 | Bukan normalisasi per citra |
| Fungsi kerugian | L1 (galat absolut rerata) | Menghasilkan keluaran lebih tajam dibanding L2 |
| Pengoptimal | Adam, `β₁ = 0,5` | Konvensi keluarga model pembangkit citra |
| Laju pembelajaran | Dapat diatur per sesi | Dicatat pada setiap sesi pelatihan |
| Jarak maksimum sampel | Dapat diatur per sesi | Menentukan lebar celah yang dipelajari |
| Ragam sampel | Titik tengah saja atau `t` seimbang | Ragam kedua menjadi tujuan penyempurnaan |
| Metrik per epoch | MAE, MSE, PSNR, SSIM | PSNR dan SSIM dihitung pada jendela `[0, 1]` |

Setiap epoch menghasilkan satu baris metrik yang disimpan, dan satu gambar contoh keluaran model. Keduanya diperlukan agar kemajuan pelatihan dapat
ditelusuri, bukan hanya disimpulkan dari angka akhir. Bobot hasil pelatihan
dikembalikan ke peladen lokal dan disimpan bersama identitas sesi
pelatihannya.

Sebagai gambaran capaian yang telah terukur pada penyempurnaan awal, sebuah
sesi pelatihan sepanjang 20 epoch menunjukkan penurunan MAE dari 0,014976
menjadi 0,013986, penurunan MSE dari 0,000678 menjadi 0,000538, kenaikan PSNR
dari 38,206 dB menjadi 39,4436 dB, dan kenaikan SSIM dari 0,986 menjadi
0,9871. Angka-angka tersebut menjadi acuan pembanding bagi sesi pelatihan
berikutnya.

### 3.6.4 Rancangan Interpolasi Rekursif

Model dilatih pada distribusi titik tengah, sehingga interpolasi pada tahap
inferensi selalu dilakukan pada `t = 0,5` dan dijalankan secara rekursif.
Diberikan dua frame batas dengan indeks `a` dan `b`, algoritmanya adalah:

```
prosedur ISI(a, b)
jika (b − a) ≤ 1 maka
selesai
jika (b − a) ganjil maka
selesai                       // tidak ada titik tengah yang tepat
m ← (a + b) / 2
I_m ← G(I_a, I_b, t = 0,5)
generation(m) ← max(generation(a), generation(b)) + 1
ISI(a, m)
ISI(m, b)
```

**[GAMBAR 3. 10 — Alur Interpolasi Rekursif]**
*Gambarkan pohon rekursi untuk contoh frame 1 dan 7.*

Nilai `generation` adalah unsur yang menentukan pada rancangan ini. Frame
hasil pindai bernilai 0. Frame yang kedua batasnya merupakan hasil pindai
bernilai 1, dan merupakan hasil yang paling dapat dipercaya. Frame yang salah
satu batasnya merupakan keluaran model bernilai 2 atau lebih; pada frame
semacam ini, galat model diumpankan kembali sebagai masukan, sehingga semakin
dalam rekursi semakin besar pula galat yang menumpuk.

Nilai tersebut disertakan pada hasil yang diterima peneliti. Tanpanya, seluruh
frame keluaran tampak setara, padahal tingkat kepercayaannya berbeda.

### 3.6.5 Rancangan Validasi Hold-Out

Angka mutu yang dihasilkan pada tahap pelatihan menyatakan kinerja model pada
data pelatihannya, bukan pada arsip yang sedang dikerjakan peneliti. Oleh
karena itu diperlukan pengukuran yang dilakukan pada arsip itu sendiri.

Mekanismenya adalah sebagai berikut. Apabila arsip yang diunggah mengandung
sebuah frame yang merupakan titik tengah tepat dari dua frame lain yang juga
ada di dalamnya, maka frame tersebut disembunyikan dari model. Model diminta
membangkitkan frame pada posisi itu dari kedua frame batasnya, lalu hasilnya
dibandingkan terhadap frame asli yang disembunyikan. Karena frame asli
tersebut merupakan hasil pindai yang sebenarnya, perbandingan ini menghasilkan
angka yang benar-benar berlaku untuk arsip yang bersangkutan.

Metrik yang dilaporkan adalah MAE, RMSE, dan PSNR, disertai rentang nilai
frame acuan. Pelaporan rentang bersifat wajib: sebuah MAE sebesar 359,747
tidak bermakna apa pun tanpa mengetahui bahwa rentang frame acuannya adalah
108 hingga 56.487, karena galat tersebut hanya sekitar 0,6% dari rentang yang
diukur. Angka-angka tersebut merupakan hasil pengukuran nyata pada penelitian
ini, dengan PSNR terukur sebesar 39,58 dB.

Perlu ditegaskan bahwa tidak semua arsip menyediakan titik tengah yang tepat.
Arsip yang tidak menyediakannya tidak menghasilkan validasi, dan ketiadaan
angka tersebut tidak boleh diperlakukan sebagai kegagalan.

### 3.6.6 Analisa Perilaku Bobot Dasar

Perilaku bobot dasar diukur lebih dahulu, sebab keterangan yang beredar
mengenai model tersebut merupakan tafsiran atas gejala dan bukan hasil
pengukuran. Pengukuran dilakukan terhadap berkas bobot yang dipakai melalui
layanan inferensi yang berjalan, memakai arsip proyeksi BRIN.

**Rancangan model perlu dinyatakan lebih dahulu**, sebab ia menentukan mana
yang batas rancangan dan mana yang kekurangan. Notebook evaluasi yang menyertai
bobot memanggil model dengan `t` yang dipaku pada 0,5, menamai keluarannya
`2i + 1`, dan menghasilkan satu frame untuk setiap pasangan berurutan tanpa
rekursi. Fungsi pembentuk sampel pada skrip pelatihan pun hanya menerima
`t = 0,5` kecuali ragam `t` seimbang dinyalakan. Keduanya menetapkan bahwa
**model dirancang untuk menyisipkan satu frame pada titik tengah di antara dua
frame pindai**; masukan skalar waktu tersedia pada arsitekturnya tetapi tidak
pernah dilatih pada nilai lain.

**Jalur pengondisi waktunya tidak mati.** Lapisan `Dense` yang menerimanya
tidak memiliki satu pun bobot teredam, nol dari 4.096 neuron dengan
`|w| < 10⁻⁶`, dan pada dekoder pertama kanal peta waktu justru diberi bobot
**2,35 kali** lebih besar daripada rerata 512 kanal citra di sebelahnya.

**Tetapi keluarannya nyaris tidak bergerak ketika `t` diubah.** Sampel Block
Machine berjarak dua derajat menyediakan acuan di luar titik tengah: dengan
frame 0051 dan 0057 sebagai batas, frame 0053 berada pada `t = 1/3` dan 0055
pada `t = 2/3`, keduanya disembunyikan dari model.

**Tabel 3. 11 Tanggapan Bobot Dasar terhadap Perubahan Skalar Waktu**

| Perbandingan | MAE |
|--------------|----:|
| Keluaran `t = 0,25` terhadap keluaran `t = 0,75` | 2,20 |
| Keluaran `t = 1/3` terhadap keluaran `t = 2/3` | 1,45 |
| **Pembanding:** frame nyata 0053 terhadap frame nyata 0055 | **563,48** |
| **Pembanding:** frame batas 0051 terhadap frame batas 0057 | **1.258,22** |

Keluaran bergerak hanya **0,4%** dari yang seharusnya, dan seluruh nilai `t`
menghasilkan galat yang praktis sama terhadap acuan, yaitu 530,10 sampai 529,64
terhadap frame 0053 di sepanjang rentang yang diuji.

**Kesimpulan pengukuran.** Batasnya bukan jalur waktu yang mati, melainkan
jalur waktu yang **tidak pernah dilatih untuk berpengaruh**. Itulah sebabnya
penyempurnaan pada penelitian ini berbentuk pelatihan ulang dengan ragam `t`
seimbang, bukan perubahan arsitektur.

**Mutu terhadap pembanding sederhana.** Keluaran model dibandingkan terhadap
pencampuran linier, yaitu rata-rata berbobot kedua frame batas.

**Tabel 3. 12 Bobot Dasar terhadap Pencampuran Linier pada Tiga Metrik**

| Sampel | Kasus | MAE model | MAE linier | PSNR model | PSNR linier | SSIM model | SSIM linier |
|--------|-------|----------:|-----------:|-----------:|------------:|-----------:|------------:|
| Block Machine 2° | 51+55 → 53 | 359,7 | **298,4** | 39,58 | **43,00** | **0,9847** | 0,9844 |
| Block Machine 2° | 53+57 → 55 | 352,5 | **296,2** | 39,71 | **43,15** | **0,9846** | 0,9843 |
| Block Machine 2° | 61+65 → 63 | 345,3 | **293,7** | 39,93 | **43,59** | **0,9855** | 0,9853 |
| Al Cu 3° | 0+6 → 3 | 651,5 | **641,8** | 36,14 | **36,45** | **0,9495** | 0,9404 |
| Contrast | 1+7 → 3 | **372,1** | 373,5 | 39,26 | **39,83** | **0,9711** | 0,9647 |
| **Rerata** | | 416,2 | **380,7** | 38,92 | **41,20** | **0,9751** | 0,9718 |
| **Model unggul** | | 1 dari 5 | | 0 dari 5 | | **5 dari 5** | |

Pembacaannya menuntut kehati-hatian dan menjadi salah satu temuan penting
penelitian ini. Pada MAE dan PSNR pencampuran linier unggul, dan itu memang
seharusnya terjadi: rata-rata dua citra meminimalkan galat kuadrat, dengan
harga berupa citra yang kabur. Pada SSIM, yang membandingkan struktur secara
lokal, model unggul pada **seluruh lima kasus**, dan keunggulannya melebar pada
kasus yang lebih sulit, yaitu dari 0,0002 pada sampel dua derajat menjadi
0,0064 dan 0,0091 pada Al Cu dan Contrast.

Konsekuensinya bagi subbab 3.7 mengikat: **MAE dan PSNR tidak boleh berdiri
sendiri sebagai ukuran keberhasilan**, sebab keduanya memilih citra kabur, dan
frame proyeksi yang kabur merusak rekonstruksi yang menjadi tujuan akhirnya.

### 3.6.7 Analisa Capaian Pelatihan Model

Metode prototyping menuntut setiap iterasi menghasilkan sesuatu yang dapat
dicoba, sehingga sebagian rancangan di atas telah dijalankan terhadap perangkat
keras sungguhan sebelum proposal ini disusun. Angka berikut adalah capaian
awal, bukan hasil akhir penelitian.

Sesi pertama berjalan satu epoch dan selesai dalam 2 menit 29 detik, yang
membuktikan rantai pelatihan berfungsi dari pengambilan pekerjaan hingga
pengembalian bobot. Sesi kedua berjalan penuh sepanjang 20 epoch dengan 40
sampel per epoch.


MAE turun 6,6%, MSE turun 20,6%, PSNR naik 1,24 dB, dan SSIM naik dari 0,9860
menjadi 0,9871. Kenaikan SSIM tampak kecil karena nilai awalnya sudah tinggi:
bobot dasar telah terlatih, dan yang dikerjakan adalah penyempurnaan, bukan
pelatihan dari nol.

**Pada sisi inferensi**, tiga pekerjaan pengisian celah dijalankan terhadap
layanan sungguhan, masing-masing menghasilkan dua frame dari tiga frame masukan
dalam 47, 42, dan 54 detik. Validasi *hold-out* menghasilkan MAE 359,747, RMSE
688,092, dan PSNR 39,58 dB terhadap frame acuan berentang 108 hingga 56.487,
atau sekitar 0,6% dari rentang yang diukur.

Seluruh angka tersebut berasal dari himpunan data terbatas dan sesi pelatihan
yang pendek. Ia cukup menunjukkan rantai pelatihan, inferensi, dan validasi
berfungsi ujung ke ujung, tetapi belum cukup menyimpulkan mutu model secara
umum.

**Kriteria keberhasilan penyempurnaan** ditetapkan sebelum percobaan dimulai,
dan sengaja dirumuskan agar dapat dipatahkan. Pertama, selisih keluaran antara
`t = 0,25` dan `t = 0,75` harus naik dari 2,20 menuju besaran yang sebanding
dengan perubahan nyata antarframe, yaitu 563,48 pada pasangan yang sama.
Kedua, perubahannya harus menuju arah yang benar: keluaran pada `t = 1/3` harus
lebih dekat ke frame 0053 daripada keluaran pada `t = 2/3`, dan sebaliknya
untuk 0055. Apabila keduanya masih sama dekatnya, penyempurnaan gagal dan harus
dinyatakan gagal; kriteria yang tidak dapat gagal bukanlah kriteria.

### 3.6.8 Percobaan Penyempurnaan Bobot dan Keputusan Rancangan yang Diambil

Percobaan ini dilaporkan meskipun belum berhasil. Sebuah percobaan yang terukur
dan gagal memberi dua hal yang tidak diberikan oleh percobaan yang tidak pernah
dijalankan: ia menyempitkan ruang penyebab, dan ia memberi angka pembanding
bagi percobaan berikutnya.

**Arsitekturnya tidak disentuh.** Pemeriksaan berkas bobot sebelum dan sesudah
memberi hasil identik: `STUNet_2to1_TimeCond`, 31 lapisan, 21.921.601 parameter,
dengan cacah jenis lapisan yang sama persis. Yang diubah adalah **distribusi
data yang dilatihkan** — ragam `t` seimbang dinyalakan dan jarak maksimum sampel
dinaikkan menjadi delapan, sehingga jumlah contoh per epoch naik dari 40
menjadi 112 mengikuti `S(N,G) = Σ (N−g)(g−1)` untuk `g = 2..G`.

**Tabel 3. 13 Parameter Pelatihan Pembaruan Model**

| Parameter | Nilai | Alasan |
|-----------|-------|--------|
| `balanced_t` | `true` | Menyertakan seluruh nilai `t = m/g`, bukan hanya titik tengah |
| `max_gap` | `8` | Menyertakan rentang 2 sampai 8; sebelumnya hanya sampai 4 |
| `learning_rate` | `1 × 10⁻⁴` | Nilai bawaan; penyempurnaan, bukan pelatihan dari nol |
| `batch_size` | `1` | Satu contoh per langkah; citra 1024 × 1024 membatasi memori |
| Pengoptimal | Adam, `β₁ = 0,5` | Tidak diubah dari bobot dasar |
| Fungsi kerugian | L1 | Tidak diubah dari bobot dasar |
| Jumlah epoch | 20 | Sama dengan sesi pembanding sebelumnya |
| Bobot awal | `generator(Salinan 3 Ginet TC-D_Revisi).h5` | Bobot dasar hasil penelitian terdahulu |


**Tabel 3. 14 Sapuan Tujuh Posisi dari Satu Pasangan Frame Pindai**

| `t` yang diminta | 1/8 | 2/8 | 3/8 | 4/8 | 5/8 | 6/8 | 7/8 | Rerata |
|------------------|----:|----:|----:|----:|----:|----:|----:|-------:|
| Frame acuan | 0053 | 0055 | 0057 | 0059 | 0061 | 0063 | 0065 | |
| MAE bobot dasar | 1218,7 | 1110,1 | 1058,7 | 1039,3 | 1047,0 | 1037,9 | 1088,3 | **1085,7** |
| MAE revisi 4 | 914,4 | 812,4 | 769,1 | 756,9 | 774,8 | 766,4 | 808,9 | **800,4** |
| MAE campur linier | 501,7 | 762,5 | 925,2 | 989,4 | 955,5 | 787,4 | 510,2 | 776,0 |

**Tabel 3. 15 Hasil Pembaruan terhadap Kriteria Keberhasilan**

| Kriteria | Bobot dasar | Revisi 4 | Hasil |
|----------|------------:|---------:|:-----:|
| 1. Mutu pada rentang 2 tidak memburuk | 359,7 | **352,5** | **Terpenuhi** |
| 2. Mutu pada rentang 8 membaik | 1039,3 | **756,9** | **Terpenuhi** |
| 3. Tanggapan terhadap `t` meningkat | 3,3 | **562,9** | **Terpenuhi** |
| 4. Frame layak pada celah 8 bertambah | 0 dari 7 | 0 dari 7 | **Tidak terpenuhi** |

**Tabel 3. 16 Keragaman Keluaran terhadap Gerak Frame Nyata**

| | Jarak antar-keluaran | Jarak antar-frame nyata | Rasio |
|---|---:|---:|---:|
| Bobot dasar | 1,5 | 1.107,9 | **0,001** |
| Revisi 4 | 261,1 | 1.107,9 | **0,236** |

**Tabel 3. 17 Jarak Antar-Hasil pada Objek yang Tidak Dilatihkan**

| Sumber frame | Jarak antar-hasil | Rasio terhadap gerak yang benar |
|--------------|------------------:|-------------------------------:|
| Bobot dasar | 2,9 | 0,016 |
| Bobot hasil penyempurnaan | 37,4 | 0,210 |
| Pencampuran linier (acuan gerak) | 178,2 | 1,000 |

**Yang berhasil.** Tanggapan terhadap skalar waktu naik dari **0,17% menjadi
27,87%**, dan keragaman keluaran dari rasio 0,001 menjadi 0,236. Mekanisme
pengondisian waktu pada arsitektur ini karena itu **terbukti dapat diaktifkan
melalui distribusi data pelatihan, tanpa mengubah satu lapisan pun**.

**Yang belum berhasil.** Perubahan itu belum cukup besar untuk berguna. Pada
Sample Contrast, objek yang tidak pernah dilatihkan, jarak antara tiga frame
yang dibangkitkan dari pasangan yang sama hanya 37,4 pada citra berskala 0
sampai 57.000, yaitu **0,065% dari rentang** dan di bawah ambang yang dapat
dibedakan mata. Pemeriksaan visual memang tidak memperlihatkan perbedaan.

Sebab yang paling mungkin adalah pelatihan yang terhenti terlalu dini dan data
yang terlalu sedikit: penurunan MAE pada lima epoch terakhir masih berjalan
pada 76% laju lima epoch pertama, dan sepuluh frame yang menghasilkan 112
contoh berhadapan dengan 21,9 juta parameter.

**Keputusan rancangan yang diambil.** Bobot hasil penyempurnaan **tidak
dipasang**; sistem tetap memakai bobot dasar. Dua keputusan mengikutinya.
Pertama, interpolasi dijalankan secara rekursif pada titik tengah sebagaimana
subbab 3.6.4, sebab selama model hanya andal di titik tengah, rekursi adalah
satu-satunya cara memakainya di dalam zona yang dikuasainya. Kedua, asal-usul
setiap frame dicatat dan disampaikan kepada peneliti melalui nilai
`generation`, sebab galat berlipat 1,73 kali pada setiap batas sintetis
sehingga frame bergenerasi satu dan frame yang lebih dalam tidak boleh tampak
setara. Angka mutu tanpa keterangan asal-usul akan menyesatkan.

## 3.7 Rancangan Pengujian

Pengujian dilakukan pada tiga tingkat sebagaimana disajikan pada Tabel 3.18.

**Tabel 3. 18 Rancangan Skenario Pengujian**

| Kode | Tingkat | Yang Diuji | Kriteria Berhasil |
|------|---------|-----------|-------------------|
| U-01 | Unit dan integrasi sisi peladen | Validasi arsip, pembentukan pekerjaan, antrean, retensi berkas, otorisasi | Seluruh pengujian otomatis lulus |
| U-02 | Unit dan widget sisi klien | Penyusunan tampilan, penanganan galat, unggah berpotongan, pemulihan sesi terputus | Seluruh pengujian otomatis lulus |
| U-03 | Pembacaan citra 16-bit | Pemetaan jendela TIFF ke PNG, penolakan berkas rusak | Keluaran PNG sah dan galat ditolak dengan pesan |
| F-01 | Fungsional ujung ke ujung | Unggah arsip bercelah, jalankan, unduh hasil | Barisan keluaran lengkap dan dapat dibuka |
| F-02 | Fungsional ujung ke ujung | Sesi layanan inferensi berakhir di tengah pekerjaan | Pekerjaan ditandai gagal disertai sebabnya, bukan menggantung |
| F-03 | Fungsional ujung ke ujung | Volume NAS tidak terpasang | Sistem menolak bekerja disertai pesan yang jelas |
| M-01 | Mutu keluaran | Validasi *hold-out* pada arsip berjarak tetap | MAE, RMSE, dan PSNR tercatat beserta rentang acuan |
| M-02 | Mutu keluaran | Perbandingan antargenerasi frame | Frame `generation` 1 menunjukkan galat lebih kecil daripada `generation` 2 ke atas |
| P-01 | Kinerja | Waktu proses per pekerjaan | Tercatat dan konsisten dengan pengukuran sebelumnya |

**Tabel 3. 19 Format Penyajian Hasil Pengujian**

| Kode | Arsip | Jumlah Frame Masuk | Jumlah Frame Dihasilkan | Waktu Proses | MAE | RMSE | PSNR | Rentang Acuan |
|------|-------|--------------------|-------------------------|--------------|-----|------|------|---------------|
| M-01a | – | – | – | – | – | – | – | – |
| M-01b | – | – | – | – | – | – | – | – |
| … | … | … | … | … | … | … | … | … |

Sebagai acuan awal, tiga pekerjaan yang telah dijalankan terhadap layanan
inferensi yang sebenarnya menghasilkan dua frame dari tiga frame masukan
dengan waktu proses 47 detik, 42 detik, dan 54 detik, serta angka validasi
*hold-out* yang identik pada ketiganya.

## 3.8 Rancangan Iterasi Prototyping

**Tabel 3. 20 Iterasi Prototyping dan Capaian Setiap Iterasi**

| Iterasi | Fokus | Capaian yang Ditargetkan |
|---------|-------|--------------------------|
| 1 | Layanan inferensi dan kontrak antarmuka | Layanan menerima dua frame batas dan skalar waktu, mengembalikan satu frame TIFF |
| 2 | Antarmuka pemrograman aplikasi dan antrean | Unggah, validasi, antrean pekerjaan, dan unduh hasil berjalan |
| 3 | Aplikasi klien multiplatform | Aplikasi peramban dan Android dari satu basis kode |
| 4 | Interpolasi rekursif dan asal-usul frame | Celah lebar terisi, `generation` tercatat pada setiap frame |
| 5 | Validasi *hold-out* dan pelaporan mutu | Angka mutu menyertai hasil beserta rentang acuannya |
| 6 | Pelatihan model dari sisi peneliti | Peneliti dapat memulai dan memantau sesi pelatihan sendiri |
| 7 | Ketahanan dan tata kelola penyimpanan | Penanganan sesi awan yang berakhir, retensi berkas, penjagaan volume NAS |
| 8 | Pengukuran bobot dasar dan percobaan penyempurnaan | Perilaku model terukur terhadap arsip yang sebenarnya; keputusan memakai bobot dasar atau menggantinya diambil berdasarkan angka |

Tujuh iterasi pertama diakhiri dengan penyerahan purwarupa kepada pihak BRIN
Puspiptek untuk dicoba, dan umpan balik yang diperoleh menjadi masukan bagi
iterasi berikutnya.

Iterasi kedelapan berbeda bentuknya, dan perbedaan itu disengaja. Keluarannya
bukan purwarupa yang diserahkan, melainkan angka dan keputusan rancangan
yang diturunkan darinya, yaitu bentuk purwarupa yang dibuang setelah menjawab
pertanyaannya sebagaimana diuraikan pada subbab 2.2.10. Iterasi inilah yang mengukur keempat batas pada subbab 3.6.6 dan melahirkan pencatatan asal-usul
frame pada subbab 3.6.8; keduanya tidak dapat dirumuskan pada tahap analisis
awal karena keduanya baru terlihat setelah sistem berjalan dan diukur.

## 3.9 Kebutuhan Perangkat

### 3.9.1 Perangkat Keras

**Tabel 3. 21 Kebutuhan Perangkat Keras**

| Komponen | Spesifikasi | Peran |
|----------|-------------|-------|
| Peladen lokal | Prosesor kelas desktop, RAM minimal 16 GB | Menjalankan peladen aplikasi, basis data, dan pekerja antrean |
| Penyimpanan NAS | Kapasitas minimal 2 TB, terhubung jaringan lokal | Menyimpan arsip masukan, keluaran, dan dataset pelatihan |
| Mesin inferensi | Kartu grafis dengan memori minimal 16 GB pada lingkungan komputasi awan | Menjalankan inferensi dan pelatihan model |
| Perangkat klien | Komputer berperamban modern dan telepon genggam Android | Mengakses sistem |
| Jaringan | Koneksi internet untuk terowongan menuju mesin inferensi | Menghubungkan peladen lokal dengan mesin inferensi |

Pengukuran waktu proses dilakukan pada konfigurasi perangkat yang sama untuk
seluruh skenario pengujian, karena waktu proses merupakan salah satu hal yang
dilaporkan dan angkanya hanya bermakna bila dibandingkan pada perangkat yang
setara.

### 3.9.2 Perangkat Lunak

**Tabel 3. 22 Kebutuhan Perangkat Lunak**

| Perangkat Lunak | Fungsi |
|-----------------|--------|
| PHP 8.2 dan Laravel 12 | Kerangka kerja antarmuka pemrograman aplikasi sisi peladen |
| Laravel Octane dan RoadRunner | Peladen aplikasi berkinerja tinggi dengan proses pekerja yang tetap hidup |
| MySQL 8 | Basis data metadata, pengguna, dan antrean pekerjaan |
| Dart dan Flutter | Aplikasi peramban dan Android dari satu basis kode |
| Python 3 | Bahasa pemrograman layanan inferensi dan pelatihan |
| TensorFlow / Keras | Kerangka kerja pemuatan model, inferensi, dan pelatihan |
| FastAPI | Kerangka kerja layanan inferensi dan pelatihan |
| NumPy | Operasi larik dan normalisasi citra |
| Pillow | Pembacaan dan penulisan berkas TIFF 16-bit |
| Terowongan HTTP | Menghubungkan peladen lokal dengan layanan inferensi di lingkungan awan |

Versi setiap pustaka dicatat setelah proses pemasangan dan dicantumkan pada
laporan akhir agar hasil penelitian dapat direproduksi.

---

# JADWAL PENYUSUNAN SKRIPSI

Jadwal berikut disusun berdasarkan aktivitas dan capaian, bukan berdasarkan
bab penulisan. Rentang waktu dinyatakan dalam minggu terhitung sejak proposal
disetujui.

**Tabel 3. 23 Jadwal Penyusunan Skripsi**

| No | Aktivitas | Minggu 1–2 | Minggu 3–4 | Minggu 5–6 | Minggu 7–8 | Minggu 9–10 | Minggu 11–12 | Minggu 13–14 | Minggu 15–16 |
|----|-----------|:----------:|:----------:|:----------:|:----------:|:-----------:|:------------:|:------------:|:------------:|
| 1 | Studi pendahuluan, observasi, dan wawancara | ■ | | | | | | | |
| 2 | Pengumpulan arsip citra proyeksi | ■ | ■ | | | | | | |
| 3 | Analisa kebutuhan dan perancangan | | ■ | ■ | | | | | |
| 4 | Iterasi 1–2: layanan inferensi dan API | | | ■ | ■ | | | | |
| 5 | Iterasi 3–4: aplikasi klien dan interpolasi rekursif | | | | ■ | ■ | | | |
| 6 | Iterasi 5–6: validasi mutu dan pelatihan model | | | | | ■ | ■ | | |
| 7 | Iterasi 7: ketahanan dan tata kelola penyimpanan | | | | | | ■ | | |
| 8 | Pengujian ujung ke ujung dan pengumpulan metrik | | | | | | ■ | ■ | |
| 9 | Analisa hasil dan penyusunan pembahasan | | | | | | | ■ | ■ |
| 10 | Penyusunan laporan dan sidang | | | | | | | | ■ |

**Capaian per tahapan.** Tahapan 1–3 menghasilkan dokumen kebutuhan dan
rancangan yang disepakati bersama pihak BRIN Puspiptek. Tahapan 4–7
menghasilkan purwarupa fungsional yang bertambah kemampuannya pada setiap
iterasi, masing-masing disertai umpan balik tertulis. Tahapan 8–9 menghasilkan
tabel hasil pengujian beserta analisanya. Tahapan 10 menghasilkan laporan
skripsi.

**Antisipasi kendala.** Tiga kendala diperkirakan dapat terjadi berikut antisipasinya. Pertama, sesi mesin inferensi pada lingkungan komputasi awan
berakhir sendiri sebelum sebuah pekerjaan selesai; sistem dirancang menyimpan
titik pemeriksaan sehingga pekerjaan dapat dilanjutkan pekerja berikutnya, dan
jadwal menyediakan kelonggaran pada tahapan 8. Kedua, ketersediaan arsip citra
proyeksi bergantung pada jadwal pemindaian di fasilitas; pengumpulan data
karenanya ditempatkan sejak minggu pertama. Ketiga, umpan balik pada suatu
iterasi dapat menuntut perubahan rancangan yang cukup besar; metode
Prototyping memang mengakomodasi hal ini, namun jadwal iterasi disusun
berpasangan agar perubahan pada satu iterasi masih dapat diserap oleh
pasangannya.

---

# DAFTAR PUSTAKA

Anderson, I. S., McGreevy, R. L., & Bilheux, H. Z. (Eds.). (2009). *Neutron
imaging and applications: A reference for the imaging community*. Springer.
https://doi.org/10.1007/978-0-387-78693-3

Arwidiyarti, D., Nurkholis, L. M., & Juhartini. (2026). Pengembangan sistem
informasi manajemen skripsi terintegrasi berbasis web menggunakan metode
prototype dan evaluasi usability. *JUSIM (Jurnal Sistem Informasi Musirawas)*,
11(2), 321–330. https://doi.org/10.32767/jusim.v11i2.2969

Ermatita, E., & Ningsih, W. (2025). Arsitektur U-Net pada segmentasi citra
paru untuk mendeteksi nodul paru. *Jurnal Pendidikan dan Teknologi Indonesia*,
5(1), 123–130. https://doi.org/10.52436/1.jpti.600

Huang, Z., Zhang, T., Heng, W., Shi, B., & Zhou, S. (2022). Real-time
intermediate flow estimation for video frame interpolation. In *Computer
Vision – ECCV 2022* (Lecture Notes in Computer Science, Vol. 13674, pp.
624–642). Springer. https://doi.org/10.1007/978-3-031-19781-9_36

Isola, P., Zhu, J.-Y., Zhou, T., & Efros, A. A. (2017). Image-to-image
translation with conditional adversarial networks. In *2017 IEEE Conference on
Computer Vision and Pattern Recognition (CVPR)* (pp. 5967–5976). IEEE.
https://doi.org/10.1109/CVPR.2017.632

Jiang, H., Sun, D., Jampani, V., Yang, M.-H., Learned-Miller, E., & Kautz, J.
(2018). Super SloMo: High quality estimation of multiple intermediate frames
for video interpolation. In *2018 IEEE/CVF Conference on Computer Vision and
Pattern Recognition* (pp. 9000–9008). IEEE.
https://doi.org/10.1109/CVPR.2018.00938

Kak, A. C., & Slaney, M. (2001). *Principles of computerized tomographic
imaging*. Society for Industrial and Applied Mathematics.
https://doi.org/10.1137/1.9780898719277

Kingma, D. P., & Ba, J. (2015). Adam: A method for stochastic optimization. In
*3rd International Conference on Learning Representations (ICLR 2015)*.
https://doi.org/10.48550/arXiv.1412.6980

Kurniawan, R., Rosiyadi, D., & Hardi, N. (2025). Rancang bangun aplikasi
presensi instruktur berbasis Android menggunakan framework Flutter pada LKP
Bright School Lampung Timur. *Reputasi: Jurnal Rekayasa Perangkat Lunak*,
5(2), 111–120. https://doi.org/10.31294/reputasi.v5i2.5871

Kye, D., Roh, C., Ko, S., Eom, C., & Oh, J. (2026). AceVFI: A comprehensive
survey of advances in video frame interpolation. *IEEE Transactions on
Circuits and Systems for Video Technology*, 36(7), 9477–9501.
https://doi.org/10.1109/TCSVT.2026.3672288

Lv, L., Li, C., Wei, W., Sun, S., Ren, X., Pan, X., & Li, G. (2025).
Optimization of sparse-view CT reconstruction based on convolutional neural
network. *Medical Physics*, 52(4), 2089–2105. https://doi.org/10.1002/mp.17636

Maharani, Y. S., & Kurniawan, R. (2025). Pengembangan sistem informasi
pengelolaan sampah sekolah adiwiyata menggunakan metode prototype. *INFORMASI
(Jurnal Informatika dan Sistem Informasi)*, 17(2), 162–176.
https://doi.org/10.37424/informasi.v17i2.401

Niklaus, S., Mai, L., & Liu, F. (2017). Video frame interpolation via adaptive
convolution. In *2017 IEEE Conference on Computer Vision and Pattern
Recognition (CVPR)* (pp. 2270–2279). IEEE.
https://doi.org/10.1109/CVPR.2017.244

Pressman, R. S., & Maxim, B. R. (2020). *Software engineering: A
practitioner's approach* (9th ed.). McGraw-Hill Education.

Ronneberger, O., Fischer, P., & Brox, T. (2015). U-Net: Convolutional networks
for biomedical image segmentation. In *Medical Image Computing and
Computer-Assisted Intervention – MICCAI 2015* (Lecture Notes in Computer
Science, Vol. 9351, pp. 234–241). Springer.
https://doi.org/10.1007/978-3-319-24574-4_28

Rozi, M. F., Siregar, H., Hambali, Y. A., & Rasim, R. (2025). Rancang bangun
sistem manajemen akademik mahasiswa berbasis mobile multiplatform menggunakan
Flutter. *Jurnal Komputer Teknologi Informasi Sistem Komputer (JUKTISI)*,
4(2), 459–468. https://doi.org/10.62712/juktisi.v4i2.436

Tang, S., Venkatakrishnan, S. V., Chowdhury, M. S. N., Yang, D., Gober, M.,
Nelson, G. J., Cekanova, M., Biris, A. S., Buzzard, G. T., Bouman, C. A.,
Skorpenske, H. D., & Bilheux, H. Z. (2024). A machine learning decision
criterion for reducing scan time for hyperspectral neutron computed tomography
systems. *Scientific Reports*, 14(1), 15171.
https://doi.org/10.1038/s41598-024-63931-x

Wang, Z., Bovik, A. C., Sheikh, H. R., & Simoncelli, E. P. (2004). Image
quality assessment: From error visibility to structural similarity. *IEEE
Transactions on Image Processing*, 13(4), 600–612.
https://doi.org/10.1109/TIP.2003.819861

Wu, J., Lin, J., Jiang, X., Zheng, W., Zhong, L., Pang, Y., Meng, H., & Li, Z.
(2025). Dual-domain deep prior guided sparse-view CT reconstruction with
multi-scale fusion attention. *Scientific Reports*, 15(1), 16894.
https://doi.org/10.1038/s41598-025-02133-5

Zhang, R., Wang, J., Wang, L., Deng, B., & Hu, J. (2025). Synchrotron based
sparse-view CT artifact correction with STC-UNet. *Nuclear Instruments and
Methods in Physics Research Section A*, 1073, 170306.
https://doi.org/10.1016/j.nima.2025.170306
