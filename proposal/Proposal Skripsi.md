# RANCANG BANGUN SISTEM MULTIPLATFORM TERINTEGRASI BERBASIS ARSITEKTUR HYBRID CLOUD-NAS UNTUK INTERPOLASI OTOMATIS CITRA PROYEKSI TOMOGRAFI KOMPUTER NEUTRON MENGGUNAKAN ALGORITMA SPATIO-TEMPORAL U-NET (STU-NET)

## (STUDI KASUS: BRIN PUSPIPTEK)

**SKRIPSI**

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

# HALAMAN PERSETUJUAN

Skripsi dengan judul:

**RANCANG BANGUN SISTEM MULTIPLATFORM TERINTEGRASI BERBASIS ARSITEKTUR HYBRID
CLOUD-NAS UNTUK INTERPOLASI OTOMATIS CITRA PROYEKSI TOMOGRAFI KOMPUTER NEUTRON
MENGGUNAKAN ALGORITMA SPATIO-TEMPORAL U-NET (STU-NET)
(STUDI KASUS: BRIN PUSPIPTEK)**

yang disusun oleh:

Nama : Muhammad Nur Fajriansyah

NIM : 231011401688

Program Studi : Teknik Informatika

telah diperiksa dan disetujui untuk diajukan pada sidang skripsi Program Studi
Teknik Informatika, Fakultas Ilmu Komputer, Universitas Pamulang.

Pamulang, ....................

Dosen Pembimbing,

&nbsp;

&nbsp;

( .................................... )

NIDN. ....................

---

# HALAMAN PENGESAHAN

Skripsi ini telah dipertahankan di hadapan Tim Penguji Sidang Skripsi Program
Studi Teknik Informatika, Fakultas Ilmu Komputer, Universitas Pamulang, dan
dinyatakan diterima sebagai salah satu syarat untuk memperoleh gelar Sarjana
Komputer.

Pamulang, ....................

Tim Penguji

Ketua Penguji : ( .................................... )

Anggota Penguji I : ( .................................... )

Anggota Penguji II : ( .................................... )

Mengetahui,

Ketua Program Studi Teknik Informatika

&nbsp;

&nbsp;

( .................................... )

NIDN. ....................

---

# HALAMAN PERNYATAAN BUKAN PLAGIAT

Yang bertanda tangan di bawah ini:

Nama : Muhammad Nur Fajriansyah

NIM : 231011401688

Program Studi : Teknik Informatika

menyatakan dengan sebenarnya bahwa skripsi yang berjudul **Rancang Bangun
Sistem Multiplatform Terintegrasi Berbasis Arsitektur Hybrid Cloud-NAS untuk
Interpolasi Otomatis Citra Proyeksi Tomografi Komputer Neutron Menggunakan
Algoritma Spatio-Temporal U-Net (STU-Net) (Studi Kasus: BRIN Puspiptek)**
merupakan hasil karya sendiri dan bukan merupakan hasil penjiplakan atas karya
orang lain.

Bobot model yang dipakai pada penelitian ini merupakan hasil kolaborasi dengan
Badan Riset dan Inovasi Nasional, dan kedudukan tersebut dinyatakan secara
terbuka pada batasan penelitian serta pada Bab III. Seluruh acuan yang dipakai
telah disebutkan sumbernya di dalam naskah dan dicantumkan pada daftar pustaka.

Apabila di kemudian hari pernyataan ini terbukti tidak benar, saya bersedia
menerima sanksi sesuai ketentuan yang berlaku.

Pamulang, ....................

Yang menyatakan,

&nbsp;

&nbsp;

( Muhammad Nur Fajriansyah )

---

# KATA PENGANTAR

Puji syukur penulis panjatkan ke hadirat Tuhan Yang Maha Esa atas rahmat-Nya
sehingga skripsi berjudul *Rancang Bangun Sistem Multiplatform Terintegrasi
Berbasis Arsitektur Hybrid Cloud-NAS untuk Interpolasi Otomatis Citra Proyeksi
Tomografi Komputer Neutron Menggunakan Algoritma Spatio-Temporal U-Net
(STU-Net)* ini dapat diselesaikan.

Penulis menyampaikan terima kasih kepada Ketua Program Studi Teknik Informatika
dan seluruh dosen Fakultas Ilmu Komputer Universitas Pamulang atas ilmu yang
diberikan, kepada dosen pembimbing atas arahan selama penyusunan skripsi ini,
serta kepada pembimbing dan rekan-rekan di Badan Riset dan Inovasi Nasional
Puspiptek yang telah membuka akses terhadap arsip citra proyeksi tomografi
neutron dan berbagi pengetahuan mengenai model interpolasi yang menjadi mesin
sistem ini. Ucapan terima kasih juga penulis sampaikan kepada keluarga atas
dukungan yang tidak pernah putus.

Penulis menyadari skripsi ini masih memiliki kekurangan. Beberapa di antaranya
telah dinyatakan secara terbuka pada batasan penelitian dan pada saran di Bab
V, dengan harapan pembaca dapat menilai hasilnya dengan takaran yang tepat.
Kritik dan saran yang membangun sangat penulis harapkan.

Pamulang, ....................

Penulis

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

Skripsi ini setebal ____ halaman, memuat 40 tabel dan 21 gambar tanpa
lampiran, serta menggunakan 20 acuan terbitan tahun 2001 sampai 2026.

---

# DAFTAR ISI

```
HALAMAN PERSETUJUAN ........................................................ i
HALAMAN PENGESAHAN ........................................................ ii
HALAMAN PERNYATAAN BUKAN PLAGIAT ......................................... iii
KATA PENGANTAR ............................................................ iv
ABSTRACT ................................................................... v
ABSTRAK ................................................................... vi
DAFTAR ISI ............................................................... vii
DAFTAR GAMBAR ............................................................. ix
DAFTAR TABEL ............................................................... x
BAB I PENDAHULUAN .......................................................... 1
    1.1  Latar Belakang .................................................... 1
    1.2  Identifikasi Masalah .............................................. 2
    1.3  Rumusan Masalah ................................................... 3
    1.4  Batasan Penelitian ................................................ 4
        1.4.1  Metode dan Algoritma ........................................ 4
        1.4.2  Data Penelitian ............................................. 5
        1.4.3  Proses Pengujian ............................................ 5
        1.4.4  Implementasi ................................................ 6
        1.4.5  Tools ....................................................... 6
    1.5  Tujuan Penelitian ................................................. 6
    1.6  Manfaat Penelitian ................................................ 7
    1.7  Metodologi Penelitian ............................................. 7
    1.8  Sistematika Penulisan ............................................. 8
BAB II LANDASAN TEORI ...................................................... 9
    2.1  Penelitian Relevan ................................................ 9
    2.2  Tinjauan Pustaka ................................................. 12
        2.2.1  Tomografi Komputer Neutron ................................. 12
        2.2.2  Citra Digital 16-bit dan Proyeksi TIFF ..................... 13
        2.2.3  Interpolasi Frame .......................................... 13
        2.2.4  Arsitektur U-Net ........................................... 14
        2.2.5  Spatio-Temporal U-Net (STU-Net) ............................ 15
        2.2.6  Fungsi Kerugian dan Optimasi ............................... 18
        2.2.7  Metrik Evaluasi Kualitas Citra ............................. 19
        2.2.8  Arsitektur Hybrid Cloud-NAS ................................ 20
        2.2.9  Sistem Multiplatform ....................................... 21
        2.2.10  Metode Prototyping ........................................ 21
    2.3  Alasan Pemilihan Algoritma Spatio-Temporal U-Net ................. 22
        2.3.1  Bentuk persoalannya menuntut dua masukan yang berbeda jenis ... 22
        2.3.2  Sumbu waktu diperlakukan sebagai barisan, bukan sebagai kanal ... 23
        2.3.3  Keluaran harus setajam masukan ............................. 23
        2.3.4  Alasan berbasis pengukuran, bukan dugaan ................... 23
        2.3.5  Mengapa bukan metode interpolasi frame video yang lain ..... 24
        2.3.6  Kesinambungan dengan jalur riset yang sedang berjalan ...... 24
    2.4  Kerangka Berpikir ................................................ 25
BAB III ANALISA DAN PERANCANGAN ........................................... 25
    3.1  Alur Penelitian .................................................. 25
    3.2  Metode Pengumpulan Data .......................................... 26
    3.3  Analisa Sistem yang Sedang Berjalan .............................. 27
        3.3.1  Prosedur Akuisisi dan Penanganan Celah Saat Ini ............ 27
        3.3.2  Permasalahan pada Sistem Berjalan .......................... 27
    3.4  Analisa Sistem yang Diusulkan .................................... 28
    3.5  Perancangan Sistem ............................................... 29
        3.5.1  Perancangan Arsitektur Perangkat Lunak ..................... 29
        3.5.2  Perancangan Use Case ....................................... 30
        3.5.3  Perancangan Aktivitas ...................................... 30
        3.5.4  Perancangan Basis Data ..................................... 31
        3.5.5  Perancangan Antarmuka Pemrograman Aplikasi ................. 32
        3.5.6  Perancangan Pratinjau Frame Berkedalaman 16 Bit ............ 33
        3.5.7  Perancangan Ketahanan Sistem dan Tata Kelola Berkas ........ 33
        3.5.8  Perancangan Antarmuka Pengguna ............................. 35
        3.5.9  Alasan Pemilihan Arsitektur dan Peranti .................... 35
    3.6  Analisa Model dan Rancangan Pemanfaatannya ....................... 37
        3.6.1  Rancangan Pengolahan Data Citra ............................ 38
        3.6.2  Rancangan Praproses ........................................ 38
        3.6.3  Rancangan Pelatihan Model .................................. 39
        3.6.4  Rancangan Interpolasi Rekursif ............................. 39
        3.6.5  Rancangan Validasi Hold-Out ................................ 40
        3.6.6  Analisa Perilaku Bobot Dasar ............................... 41
        3.6.7  Analisa Capaian Pelatihan Model ............................ 43
        3.6.8  Percobaan Penyempurnaan Bobot dan Keputusan Rancangan yang Diambil ... 45
    3.7  Rancangan Pengujian .............................................. 51
    3.8  Rancangan Iterasi Prototyping .................................... 51
    3.9  Kebutuhan Perangkat .............................................. 52
        3.9.1  Perangkat Keras ............................................ 52
        3.9.2  Perangkat Lunak ............................................ 53
BAB IV IMPLEMENTASI DAN PENGUJIAN ......................................... 53
    4.1  Spesifikasi ...................................................... 53
        4.1.1  Spesifikasi Perangkat Lunak ................................ 53
        4.1.2  Spesifikasi Perangkat Keras ................................ 54
    4.2  Implementasi Program ............................................. 54
        4.2.1  Implementasi Basis Data .................................... 54
        4.2.2  Implementasi Antarmuka Pemrograman Aplikasi ................ 55
        4.2.3  Implementasi Antrean dan Penjadwal ......................... 55
        4.2.4  Implementasi Layanan Inferensi ............................. 55
        4.2.5  Implementasi Antarmuka Pengguna ............................ 56
        4.2.6  Implementasi Pratinjau Frame Berkedalaman 16 Bit ........... 57
        4.2.7  Implementasi Interpolasi Rekursif dan Pencatatan Asal-Usul ... 58
    4.3  Pengujian Sistem ................................................. 58
        4.3.1  Pengujian Black Box ........................................ 58
        4.3.2  Pengujian White Box ........................................ 59
        4.3.3  Pengujian Mutu Keluaran Model .............................. 59
        4.3.4  User Response (Kuesioner) .................................. 60
BAB V PENUTUP ............................................................. 61
    5.1  Kesimpulan ....................................................... 61
    5.2  Saran ............................................................ 62
DAFTAR PUSTAKA ............................................................ 63
```

---

# DAFTAR GAMBAR

```
Gambar 2. 1   Arsitektur Spatio-Temporal U-Net ............................ 15
Gambar 2. 2   Kerangka Berpikir Penelitian ................................ 25
Gambar 3. 1   Alur Penelitian ............................................. 26
Gambar 3. 2   Alur Akuisisi Proyeksi Tomografi Neutron Saat Ini ........... 28
Gambar 3. 3   Arsitektur Sistem yang Diusulkan ............................ 29
Gambar 3. 4   Diagram Use Case Sistem ..................................... 30
Gambar 3. 5   Diagram Aktivitas Pengisian Celah Proyeksi .................. 31
Gambar 3. 6   Diagram Relasi Antar-Entitas ................................ 32
Gambar 3. 7   Rancangan Antarmuka Unggah dan Pratinjau Frame .............. 35
Gambar 3. 8   Rancangan Antarmuka Pemantauan Pelatihan Model .............. 36
Gambar 3. 9   Alur Interpolasi Rekursif ................................... 40
Gambar 4. 1   Halaman Masuk Aplikasi ...................................... 57
Gambar 4. 2   Beranda Peneliti ............................................ 57
Gambar 4. 3   Halaman Unggah dan Pratinjau Frame .......................... 57
Gambar 4. 4   Galeri Frame dan Penanda Asal-Usul .......................... 57
Gambar 4. 5   Riwayat Prediksi dan Posisi Antrean ......................... 57
Gambar 4. 6   Halaman Pelatihan Model ..................................... 58
Gambar 4. 7   Dasbor Administrator ........................................ 58
Gambar 4. 8   Pemantauan Antrean Seluruh Pengguna ......................... 58
Gambar 4. 9   Pengelolaan Model dan Alamat Layanan ........................ 58
Gambar 4. 10  Aplikasi pada Perangkat Android ............................. 58
```

---

# DAFTAR TABEL

```
Tabel 2. 1   Penelitian yang Relevan ....................................... 9
Tabel 2. 2   Operasi di Dalam Layer Kustom SkipFusion ..................... 16
Tabel 2. 3   Susunan Lapisan STUNet_2to1_TimeCond ......................... 16
Tabel 2. 4   Rangkuman Keunggulan Model terhadap Pencampuran Linier ....... 24
Tabel 3. 1   Format Pencatatan Kondisi Akuisisi Citra ..................... 27
Tabel 3. 2   Analisa Permasalahan Sistem Berjalan ......................... 28
Tabel 3. 3   Aktor dan Kewenangannya ...................................... 31
Tabel 3. 4   Rancangan Tabel Basis Data ................................... 32
Tabel 3. 5   Rancangan Antarmuka Pemrograman Aplikasi ..................... 33
Tabel 3. 6   Mekanisme Ketahanan Sistem ................................... 34
Tabel 3. 7   Waktu Satu Inferensi pada Lingkungan Lokal dan Awan .......... 37
Tabel 3. 8   Pembagian Data Citra ......................................... 39
Tabel 3. 9   Tahapan Praproses Citra ...................................... 39
Tabel 3. 10  Hiperparameter Pelatihan Model ............................... 39
Tabel 3. 11  Tanggapan Bobot Dasar terhadap Perubahan Skalar Waktu ........ 42
Tabel 3. 12  Bobot Dasar terhadap Pencampuran Linier pada Tiga Metrik ..... 43
Tabel 3. 13  Metrik Pelatihan per Epoch pada Sesi Penyempurnaan Awal ...... 44
Tabel 3. 14  Parameter Pelatihan Pembaruan Model .......................... 47
Tabel 3. 15  Metrik Pelatihan Pembaruan Model per Epoch ................... 48
Tabel 3. 16  Sapuan Tujuh Posisi dari Satu Pasangan Frame Pindai .......... 49
Tabel 3. 17  Hasil Pembaruan terhadap Kriteria Keberhasilan ............... 49
Tabel 3. 18  Keragaman Keluaran terhadap Gerak Frame Nyata ................ 49
Tabel 3. 19  Jarak Antar-Hasil pada Objek yang Tidak Dilatihkan ........... 50
Tabel 3. 20  Rancangan Skenario Pengujian ................................. 51
Tabel 3. 21  Format Penyajian Hasil Pengujian ............................. 52
Tabel 3. 22  Iterasi Prototyping dan Capaian Setiap Iterasi ............... 52
Tabel 3. 23  Kebutuhan Perangkat Keras .................................... 53
Tabel 3. 24  Kebutuhan Perangkat Lunak .................................... 54
Tabel 4. 1   Spesifikasi Perangkat Lunak yang Digunakan ................... 54
Tabel 4. 2   Spesifikasi Perangkat Keras yang Digunakan ................... 55
Tabel 4. 3   Tabel Basis Data pada Alur Utama ............................. 55
Tabel 4. 4   Pengelompokan Antarmuka Pemrograman Aplikasi ................. 56
Tabel 4. 5   Perintah Terjadwal dan Kegunaannya ........................... 56
Tabel 4. 6   Layar Utama pada Aplikasi Klien .............................. 57
Tabel 4. 7   Kebutuhan Memori Pratinjau Sebelum dan Sesudah Perbaikan ..... 58
Tabel 4. 8   Hasil Pengujian Black Box .................................... 59
Tabel 4. 9   Hasil Pengujian Otomatis ..................................... 60
Tabel 4. 10  Hasil Validasi Hold-Out terhadap Tiga Pekerjaan Nyata ........ 61
Tabel 4. 11  Model terhadap Pencampuran Linier pada Tiga Metrik ........... 61
Tabel 4. 12  Instrumen Kuesioner Tanggapan Pengguna ....................... 62
```

---

# BAB I
# PENDAHULUAN

## 1.1 Latar Belakang

Tomografi komputer neutron merupakan teknik pencitraan tak merusak yang
memanfaatkan daya tembus berkas neutron untuk mengungkap struktur internal
suatu objek. Berbeda dari sinar-X yang berinteraksi dengan awan elektron,
neutron berinteraksi dengan inti atom, sehingga teknik ini unggul dalam
membedakan unsur ringan seperti hidrogen di balik logam padat. Karakteristik
tersebut menjadikannya alat penting pada penelitian material, komponen
otomotif, dan cagar budaya di Badan Riset dan Inovasi Nasional (BRIN)
Puspiptek.

Rekonstruksi volumetrik pada tomografi komputer disusun dari sekumpulan citra
proyeksi yang diambil pada sudut yang berbeda-beda. Semakin rapat jarak sudut
antarproyeksi, semakin baik pula mutu volume yang dihasilkan. Persoalannya,
akuisisi citra neutron jauh lebih lambat daripada sinar-X. Fluks neutron pada
fasilitas reaktor riset terbatas, sehingga satu proyeksi menuntut waktu
paparan yang panjang, dan satu rangkaian pemindaian penuh dapat menghabiskan
waktu berjam-jam hingga berhari-hari. Waktu berkas neutron sendiri merupakan
sumber daya yang dijadwalkan ketat dan dibagi dengan penelitian lain.

Konsekuensi langsung dari keterbatasan tersebut adalah munculnya celah pada
barisan proyeksi. Celah terbentuk karena dua sebab. Pertama, peneliti sengaja
memperlebar jarak sudut untuk menghemat waktu berkas, dengan risiko mutu
rekonstruksi menurun. Kedua, sebagian proyeksi gagal terekam atau rusak akibat
gangguan teknis selama akuisisi, dan pengulangan pemindaian untuk sudut yang
hilang berarti mengantre waktu berkas dari awal. Pada arsip pemindaian yang
digunakan dalam penelitian ini, celah tersebut tampak jelas dari penomoran
berkas yang meloncat, misalnya dari `frame_051` langsung ke `frame_053`.

Pengisian celah tersebut selama ini dilakukan secara manual atau tidak
dilakukan sama sekali. Interpolasi linier sederhana antara dua proyeksi
tetangga menghasilkan citra kabur yang justru menambah artefak pada
rekonstruksi, sementara pengerjaan manual oleh operator tidak konsisten
antarpeneliti dan tidak dapat diulang dengan hasil yang sama. Padahal, sebuah
frame yang dipakai dalam rekonstruksi ilmiah menuntut kejelasan asal-usul:
peneliti perlu tahu mana frame yang benar-benar hasil pindai dan mana yang
merupakan keluaran model.

Perkembangan pembelajaran mendalam menawarkan jalan keluar. Arsitektur U-Net
yang semula dirancang untuk segmentasi citra biomedis terbukti sangat efektif
pada tugas pemetaan citra ke citra karena sambungan lompatnya mempertahankan
detail spasial yang hilang selama penyusutan resolusi (Ronneberger, Fischer, &
Brox, 2015). Pendekatan serupa telah terbukti pada persoalan yang berdekatan,
yaitu rekonstruksi tomografi dengan sudut proyeksi yang jarang, baik melalui
penuntun prior dua ranah (Wu dkk., 2025) maupun melalui varian U-Net untuk
koreksi artefak pada data sinkrotron (Zhang dkk., 2025). Pada ranah
interpolasi frame, pendekatan berbasis jaringan konvolusi telah menunjukkan
hasil yang jauh melampaui interpolasi linier (Niklaus, Mai, & Liu, 2017; Jiang
dkk., 2018). Namun sebagian besar penelitian tersebut menyasar video
sehari-hari beriringan gerak, bukan barisan proyeksi tomografi dengan citra
skala keabuan 16-bit yang perubahannya antarsudut bersifat geometris dan
halus.

Selain persoalan algoritma, terdapat persoalan sistem yang sama nyatanya.
Model interpolasi menuntut kartu grafis untuk berjalan pada kecepatan yang
masuk akal, sedangkan perangkat kerja di laboratorium tidak selalu
memilikinya. Di sisi lain, data hasil penelitian tidak boleh menetap di
layanan pihak ketiga. Kedua kebutuhan tersebut tampak bertentangan, dan
penyelesaiannya menuntut arsitektur yang memisahkan tempat data disimpan dari
tempat komputasi berat dikerjakan. Peneliti juga membutuhkan akses dari
perangkat yang berbeda-beda, baik komputer di laboratorium maupun telepon
genggam saat memantau proses yang berjalan lama.

Berdasarkan uraian tersebut, penelitian ini merancang dan membangun sebuah
sistem multiplatform terintegrasi yang mengisi celah proyeksi tomografi
komputer neutron secara otomatis menggunakan algoritma Spatio-Temporal U-Net,
di atas arsitektur *hybrid cloud-NAS* yang menempatkan orkestrasi dan
penyimpanan pada perangkat lokal beserta volume NAS, sementara inferensi model
dijalankan pada mesin berkartu grafis di lingkungan komputasi awan. Oleh
karena itu, penulis mengangkat penelitian dengan judul "Rancang Bangun Sistem
Multiplatform Terintegrasi Berbasis Arsitektur Hybrid Cloud-NAS untuk
Interpolasi Otomatis Citra Proyeksi Tomografi Komputer Neutron Menggunakan
Algoritma Spatio-Temporal U-Net (STU-Net) (Studi Kasus: BRIN Puspiptek)".

## 1.2 Identifikasi Masalah

Berdasarkan latar belakang di atas, permasalahan yang berhasil diidentifikasi
adalah sebagai berikut:

1. Akuisisi citra proyeksi tomografi komputer neutron memakan waktu lama dan
   bergantung pada waktu berkas neutron yang terbatas, sehingga peneliti
   terdorong memperlebar jarak sudut antarproyeksi dengan risiko menurunnya
   mutu rekonstruksi volumetrik. 2. Sebagian proyeksi hilang atau rusak selama
   akuisisi, dan pemindaian ulang untuk sudut yang hilang menuntut pengantrean
   waktu berkas dari awal. 3. Pengisian celah proyeksi secara manual maupun
   dengan interpolasi linier sederhana tidak konsisten antarpeneliti, tidak
   dapat diulang dengan hasil yang sama, dan berpotensi menambah artefak pada
   rekonstruksi. 4. Belum tersedia mekanisme yang mencatat asal-usul setiap
   frame, sehingga peneliti yang menerima hasil tidak dapat membedakan frame
   hasil pindai dari frame keluaran model, maupun mengetahui seberapa jauh
   sebuah frame dihasilkan dari keluaran model sebelumnya. 5. Model
   interpolasi menuntut kartu grafis, sedangkan perangkat kerja di
   laboratorium tidak selalu memilikinya, dan data hasil penelitian tidak
   boleh menetap di layanan komputasi awan pihak ketiga. 6. Belum tersedia
   antarmuka yang memungkinkan peneliti menjalankan proses interpolasi,
   memantau antrean, dan mengambil hasil dari perangkat yang berbeda-beda
   tanpa bergantung pada satu komputer tertentu.

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
penelitian, bukan sebagai sasaran perbaikan. Semuanya diukur pada subbab 3.6.6
terhadap arsip proyeksi BRIN. Pertama, masukan skalar waktunya praktis tidak
berpengaruh di luar titik tengah: mengubah nilai `t` di sepanjang rentang yang
sah hanya menggeser keluaran sebesar 0,17% dari perubahan yang seharusnya,
sehingga beberapa posisi waktu yang diminta dari sepasang frame yang sama
menghasilkan citra yang praktis serupa. Kedua, karena hal tersebut
pengisian harus dijalankan secara rekursif pada titik tengah, dan galatnya
berlipat setiap kali sebuah batas ternyata merupakan keluaran model sendiri,
yaitu 1,73 kali untuk satu batas dan 3,27 kali untuk dua. Ketiga, galat
meningkat tajam seiring melebarnya rentang yang diinterpolasi, yaitu dari
359,7 pada rentang dua langkah menjadi 1.039,3 pada rentang delapan langkah.
Keempat, celah dengan jumlah frame ganjil tidak memiliki titik tengah bilangan
bulat, sehingga frame yang dihasilkan bergeser setengah posisi.

Akibatnya, sistem hanya menyatakan layak frame yang kedua batasnya merupakan
hasil pindai. Celah yang lebih lebar tetap diisi, sebab menolak mengisinya
tidak menolong siapa pun. Hanya saja asal-usul dan kedalaman rekursi setiap
frame disampaikan kepada peneliti agar dapat dinilai sendiri. Interpolasi pada
tahap inferensi karena itu selalu dilakukan pada titik tengah, dan sistem
tidak menyediakan masukan skalar waktu manual bagi penggunanya.

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
   tomografi komputer neutron secara otomatis, dapat diakses melalui peramban
   maupun telepon genggam. 2. Menerapkan algoritma Spatio-Temporal U-Net
   beserta proses pelatihannya untuk mengisi celah pada barisan proyeksi,
   termasuk mekanisme interpolasi rekursif pada titik tengah. 3. Menyusun
   mekanisme pengukuran mutu berbasis validasi *hold-out* beserta pencatatan
   asal-usul setiap frame, sehingga hasil interpolasi dapat
   dipertanggungjawabkan angkanya oleh peneliti yang menerimanya. 4.
   Menghasilkan purwarupa yang telah diuji ujung ke ujung terhadap arsip citra
   neutron dan kartu grafis yang sebenarnya, bukan hanya terhadap data
   sintetis.

## 1.6 Manfaat Penelitian

**a. Bagi BRIN Puspiptek**

1. Mengurangi kebutuhan waktu berkas neutron, karena jarak sudut antarproyeksi
   dapat diperlebar sementara celahnya diisi oleh model. 2. Menyelamatkan
   rangkaian pemindaian yang sebagian proyeksinya hilang atau rusak, tanpa
   harus mengantre waktu berkas untuk pemindaian ulang. 3. Menyediakan hasil
   interpolasi yang konsisten dan dapat diulang, disertai catatan asal-usul
   dan angka mutu untuk setiap frame yang dihasilkan. 4. Menyediakan antarmuka
   yang dapat diakses dari perangkat yang berbeda-beda, sehingga proses yang
   berjalan lama dapat dipantau tanpa terikat pada satu komputer.

**b. Bagi Pengembangan dan Ilmu Pengetahuan**

1. Melengkapi kajian penerapan arsitektur berbasis U-Net pada interpolasi
   barisan proyeksi tomografi neutron, yang karakteristik citranya berbeda
   dari video sehari-hari yang selama ini menjadi objek penelitian interpolasi
   frame. 2. Menyajikan rancangan arsitektur *hybrid cloud-NAS* sebagai pola
   penyelesaian bagi laboratorium yang membutuhkan komputasi berkartu grafis
   namun terikat kewajiban menjaga data penelitian tetap berada di lingkungan
   sendiri.

**c. Bagi Penulis**

1. Menjadi sarana penerapan ilmu yang diperoleh selama perkuliahan, khususnya
   dalam bidang pembelajaran mesin, pengolahan citra digital, dan rekayasa
   perangkat lunak. 2. Memenuhi salah satu syarat untuk memperoleh gelar
   Sarjana Komputer pada Program Studi Teknik Informatika, Fakultas Ilmu
   Komputer, Universitas Pamulang.

## 1.7 Metodologi Penelitian

Penelitian ini menggunakan metode pengembangan perangkat lunak
**Prototyping**, yaitu pendekatan yang membangun purwarupa secara bertahap dan
menyempurnakannya berdasarkan umpan balik pengguna pada setiap iterasi
(Pressman & Maxim, 2020). Metode ini dipilih karena kebutuhan pada penelitian
ini tidak dapat dirumuskan lengkap di awal: perilaku model terhadap arsip
citra neutron yang sebenarnya baru diketahui setelah dicoba, dan bentuk
antarmuka yang berguna bagi peneliti baru terlihat setelah mereka mencobanya.

Metode pengumpulan data yang digunakan meliputi:

1. **Observasi**, yaitu pengamatan langsung terhadap alur kerja akuisisi citra
   proyeksi tomografi komputer neutron di BRIN Puspiptek, mencakup format
   berkas keluaran, pola penomoran proyeksi, letak celah pada barisan, serta
   perangkat yang digunakan peneliti untuk mengolah hasilnya. 2.
   **Wawancara**, yaitu tanya jawab dengan peneliti dan operator fasilitas
   pencitraan neutron untuk memperoleh gambaran mengenai keterbatasan waktu
   berkas, penyebab hilangnya proyeksi, cara penanganan celah yang berjalan
   saat ini, serta kebutuhan terhadap sistem yang akan dibangun. 3.
   **Dokumentasi**, yaitu pengumpulan arsip citra proyeksi beserta catatan
   kondisi akuisisinya, yang menjadi data pelatihan model sekaligus data
   pengujian sistem. 4. **Studi pustaka**, yaitu penelaahan buku, jurnal, dan
   prosiding yang berkaitan dengan tomografi komputer, pencitraan neutron,
   interpolasi frame, arsitektur U-Net, serta metrik evaluasi kualitas citra.

Tahapan penelitian mengikuti siklus Prototyping, yang diawali dengan
komunikasi dan penggalian kebutuhan bersama pihak BRIN Puspiptek, dilanjutkan
dengan perencanaan cepat dan pemodelan rancangan cepat, pembangunan purwarupa
yang mencakup layanan inferensi, antarmuka pemrograman aplikasi, dan aplikasi
klien, kemudian penyerahan purwarupa untuk dicoba beserta pengumpulan umpan
balik. Siklus tersebut diulang hingga purwarupa memenuhi kebutuhan yang
disepakati. Uraian rinci setiap tahapan dijelaskan pada Bab III.

## 1.8 Sistematika Penulisan

Skripsi ini disusun dengan sistematika sebagai berikut.

**BAB I PENDAHULUAN**

Bab ini menguraikan latar belakang yang mendasari penelitian, identifikasi
masalah, rumusan masalah, batasan penelitian, tujuan dan manfaat penelitian,
metodologi penelitian yang digunakan, serta sistematika penulisan.

**BAB II LANDASAN TEORI**

Bab ini memuat penelitian terdahulu yang relevan, tinjauan pustaka mengenai
tomografi komputer neutron, citra digital 16 bit, interpolasi frame, arsitektur
U-Net dan Spatio-Temporal U-Net, fungsi kerugian dan optimasi, metrik evaluasi
kualitas citra, arsitektur *hybrid cloud-NAS*, sistem multiplatform, serta
metode Prototyping, dan ditutup dengan alasan pemilihan algoritma dan kerangka
berpikir penelitian.

**BAB III ANALISA DAN PERANCANGAN**

Bab ini berisi alur penelitian, metode pengumpulan data, analisa terhadap alur
kerja akuisisi dan penanganan celah proyeksi yang sedang berjalan, serta analisa
sistem yang diusulkan. Sesudahnya diuraikan perancangan sistem perangkat lunak
beserta alasan pemilihan arsitektur dan perantinya, lalu analisa perilaku model
yang dipakai dan rancangan pemanfaatannya, dan ditutup dengan rancangan
pengujian, rancangan iterasi Prototyping, serta kebutuhan perangkat.

**BAB IV IMPLEMENTASI DAN PENGUJIAN**

Bab ini memaparkan spesifikasi perangkat lunak dan perangkat keras yang
dipakai, wujud implementasi program pada sisi basis data, antarmuka pemrograman
aplikasi, antrean, layanan inferensi, antarmuka pengguna, pratinjau frame 16
bit, dan interpolasi rekursif, kemudian hasil pengujian *black box*, pengujian
*white box*, pengujian mutu keluaran model, serta instrumen tanggapan pengguna.

**BAB V PENUTUP**

Bab ini memuat kesimpulan yang menjawab rumusan masalah beserta saran untuk
penelitian lanjutan.

**DAFTAR PUSTAKA**

Bagian ini memuat seluruh acuan yang disitasi di dalam naskah.

---

# BAB II
# LANDASAN TEORI

## 2.1 Penelitian Relevan

Penelitian yang relevan dengan penelitian ini datang dari tiga arah:
pengembangan algoritma interpolasi frame, penerapan pembelajaran mendalam pada
rekonstruksi tomografi bersudut jarang, dan rancang bangun sistem multiplatform dengan metode pengembangannya. Ketiganya diuraikan pada Tabel
2.1.

**Tabel 2. 1 Penelitian yang Relevan**

| No | Peneliti & Tahun | Judul | Metode | Data | Hasil | Perbedaan dengan Penelitian Ini |
|----|------------------|-------|--------|------|-------|--------------------------------|
| 1 | Ronneberger, Fischer, & Brox (2015) | U-Net: Convolutional Networks for Biomedical Image Segmentation | Jaringan konvolusi berbentuk encoder-decoder dengan sambungan lompat | Citra mikroskopi sel biomedis | Memenangi tantangan segmentasi ISBI dengan data latih yang sangat terbatas; sambungan lompat terbukti mempertahankan detail spasial | Penelitian ini memakai U-Net untuk memetakan pasangan frame menjadi frame antara, bukan untuk segmentasi, dan menambahkan pengondisian waktu pada arsitekturnya |
| 2 | Niklaus, Mai, & Liu (2017) | Video Frame Interpolation via Adaptive Convolution | Interpolasi frame dengan kernel konvolusi adaptif per piksel | Video sehari-hari | Menghasilkan frame antara yang lebih tajam dibanding pendekatan berbasis aliran optik | Objek penelitian ini adalah barisan proyeksi tomografi neutron 16-bit yang perubahannya bersifat geometris, bukan video RGB dengan gerak objek |
| 3 | Jiang dkk. (2018) | Super SloMo: High Quality Estimation of Multiple Intermediate Frames for Video Interpolation | Estimasi aliran optik dua arah untuk membangkitkan banyak frame antara sekaligus | Video berkecepatan tinggi | Mampu membangkitkan sejumlah frame antara pada posisi waktu sembarang dalam satu kali proses | Penelitian ini membangkitkan frame antara secara rekursif pada titik tengah, dan mencatat kedalaman rekursi sebagai penanda asal-usul frame |
| 4 | Isola dkk. (2017) | Image-to-Image Translation with Conditional Adversarial Networks | Generator berbasis U-Net dengan pelatihan adversarial berkondisi | Beragam pasangan citra | Menunjukkan U-Net sebagai generator yang efektif pada tugas pemetaan citra ke citra secara umum | Penelitian ini menggunakan generator berbasis U-Net tanpa komponen adversarial pada tahap penyempurnaan, dengan fungsi kerugian L1 sebagai satu-satunya sinyal |
| 5 | Huang dkk. (2022) | Real-Time Intermediate Flow Estimation for Video Frame Interpolation | Estimasi aliran antara secara langsung untuk interpolasi waktu nyata | Video umum | Mencapai kecepatan waktu nyata dengan mutu yang bersaing | Penelitian ini tidak menuntut waktu nyata; prioritasnya adalah kesetiaan numerik pada citra 16-bit dan kejelasan asal-usul frame |
| 6 | Tang dkk. (2024) | A Machine Learning Decision Criterion for Reducing Scan Time for Hyperspectral Neutron Computed Tomography Systems | Kriteria keputusan berbasis pembelajaran mesin untuk menghentikan akuisisi lebih awal | Data tomografi neutron hiperspektral pada Spallation Neutron Source | Waktu pindai dapat dipangkas tanpa mengorbankan mutu rekonstruksi secara berarti | Penelitian ini tidak memangkas akuisisi, melainkan mengisi proyeksi yang telanjur hilang, dan mengemasnya sebagai sistem yang dapat dipakai peneliti sehari-hari |
| 7 | Wu dkk. (2025) | Dual-Domain Deep Prior Guided Sparse-View CT Reconstruction with Multi-Scale Fusion Attention | Rekonstruksi dua ranah dengan penuntun prior dan perhatian gabungan lintas skala | Data CT sudut jarang | Artefak akibat sudut proyeksi yang jarang berkurang dibanding rekonstruksi konvensional | Penelitian ini bekerja pada ranah proyeksi, bukan ranah rekonstruksi; keluarannya barisan proyeksi lengkap, bukan volume |
| 8 | Zhang dkk. (2025) | Synchrotron Based Sparse-View CT Artifact Correction with STC-UNet | Koreksi artefak sudut jarang menggunakan varian U-Net bergabung Transformer | Data CT sinkrotron | Varian U-Net efektif menekan artefak pada data sudut jarang berintensitas tinggi | Penelitian ini memakai U-Net berpengondisian waktu untuk membangkitkan proyeksi yang hilang, bukan memperbaiki artefak pada hasil rekonstruksi |
| 9 | Rozi dkk. (2025) | Rancang Bangun Sistem Manajemen Akademik Mahasiswa Berbasis Mobile Multiplatform Menggunakan Flutter | Rancang bangun sistem multiplatform satu basis kode dengan Flutter | Kebutuhan pengguna sistem akademik | Satu basis kode terbukti melayani sasaran peramban dan Android sekaligus dengan konsistensi tampilan dan alur | Penelitian ini memakai pendekatan multiplatform yang sama, tetapi sistemnya harus mengorkestrasi komputasi GPU jarak jauh dan menjaga berkas penelitian tetap di penyimpanan lokal |
| 10 | Maharani & Kurniawan (2025) | Pengembangan Sistem Informasi Pengelolaan Sampah Sekolah Adiwiyata Menggunakan Metode Prototype | Pengembangan sistem informasi dengan metode prototype beserta evaluasi pengguna | Kebutuhan pengelolaan sampah sekolah | Metode prototype terbukti menyingkap kebutuhan yang tidak terungkap pada tahap analisis awal | Penelitian ini memakai metode prototype pada sistem yang salah satu komponennya adalah model pembelajaran mendalam, sehingga setiap iterasi harus diuji terhadap perangkat GPU yang sesungguhnya |

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

Tomografi komputer adalah teknik merekonstruksi struktur internal tiga dimensi
suatu objek dari sekumpulan citra proyeksi dua dimensi yang diambil pada
berbagai sudut pandang. Dasar matematisnya adalah transformasi Radon, dan
rekonstruksinya umumnya dikerjakan dengan algoritma proyeksi balik tersaring
(Kak & Slaney, 2001).

Pada tomografi komputer neutron, berkas penembus yang digunakan adalah neutron
termal atau dingin. Neutron berinteraksi dengan inti atom, bukan dengan awan
elektron sebagaimana sinar-X, sehingga koefisien atenuasinya tidak mengikuti
nomor atom secara monotonik. Akibatnya, unsur ringan seperti hidrogen justru
sangat menyerap neutron sementara logam berat relatif tembus. Sifat inilah
yang membuat pencitraan neutron unggul dalam mengungkap keberadaan air,
minyak, atau bahan organik di balik selubung logam (Anderson, McGreevy, &
Bilheux, 2009).

Konsekuensi praktisnya adalah keterbatasan fluks. Sumber neutron menuntut
reaktor riset atau sumber spalasi, dan fluks yang tersedia jauh lebih rendah
daripada tabung sinar-X. Waktu paparan per proyeksi menjadi panjang, sehingga
jumlah proyeksi yang dapat diambil dalam satu jadwal terbatas. Keterbatasan
ini yang mendasari kebutuhan interpolasi pada penelitian ini.

Keterbatasan yang sama telah mendorong penerapan pembelajaran mesin pada
tomografi neutron dari arah yang berbeda. Tang dkk. (2024) menyusun kriteria
keputusan berbasis pembelajaran mesin untuk menghentikan akuisisi
hiperspektral lebih awal tanpa mengorbankan mutu rekonstruksi, sehingga waktu
pindai dapat dipangkas. Penelitian ini bergerak dari sisi yang berlawanan:
bukan mencegah proyeksi diambil, melainkan memulihkan proyeksi yang telanjur
hilang.

### 2.2.2 Citra Digital 16-bit dan Proyeksi TIFF

Citra digital adalah fungsi diskret dua dimensi yang memetakan koordinat
piksel ke nilai intensitas. Pada pencitraan ilmiah, kedalaman bit yang umum
digunakan adalah 16 bit per piksel, sehingga rentang nilai intensitasnya
membentang dari 0 hingga 65.535. Rentang selebar ini diperlukan karena
perbedaan atenuasi yang bermakna secara ilmiah dapat sangat halus dan akan
hilang bila dipaksakan ke dalam 256 aras keabuan.

Kedalaman itu menimbulkan persoalan tersendiri pada sisi penyajian. Peramban
web maupun kerangka kerja aplikasi bergerak tidak dapat menampilkan TIFF
16-bit secara langsung, sehingga frame harus diterjemahkan lebih dahulu ke
format yang dapat dirender. Penerjemahan tersebut tidak boleh dilakukan dengan
sekadar membuang byte rendah, karena frame proyeksi neutron jarang mengisi
seluruh rentang 16 bit. Satu frame yang diamati pada penelitian ini hanya
menempati rentang 290 hingga 58.633, sehingga pemangkasan langsung akan
menghasilkan citra yang nyaris hitam seluruhnya. Yang diperlukan adalah
pemetaan berjendela terhadap nilai terkecil dan terbesar frame itu sendiri.
Rancangannya diuraikan pada subbab 3.5.6.

Berkas proyeksi disimpan dalam format TIFF tanpa kompresi. Sebagai gambaran,
satu frame proyeksi neutron pada penelitian ini berukuran 1024 × 1024 piksel
dengan rentang nilai nyata yang terukur antara 290 hingga 58.633, jauh dari
rentang 16-bit penuh. Kenyataan ini penting karena berarti setiap penampilan
citra tersebut kepada manusia menuntut pemetaan jendela terlebih dahulu;
pemotongan sederhana byte rendah akan menghasilkan citra yang tampak hampir
hitam seluruhnya.

### 2.2.3 Interpolasi Frame

Interpolasi frame adalah proses membangkitkan satu atau lebih citra antara di
antara dua citra yang diketahui. Bila dua citra batas dinyatakan sebagai `I₀`
dan `I₂`, dan posisi waktu relatif dinyatakan sebagai `t ∈ (0,1)`, maka
interpolasi menghasilkan `Î_t`.

Pendekatan paling sederhana adalah pencampuran linier:

```
Î_t = (1 − t) · I₀ + t · I₂
```

Perkembangan bidang ini selama satu dasawarsa terakhir dirangkum secara
menyeluruh oleh Kye dkk. (2026), yang mengelompokkan metode interpolasi frame
menjadi dua paradigma: interpolasi pada titik tengah tetap dan interpolasi
pada posisi waktu sembarang. Penelitian ini memakai paradigma pertama pada
tahap inferensi, dan paradigma kedua pada tahap penyempurnaan model.

Pendekatan ini murah namun menghasilkan citra kabur ketika terdapat
perpindahan struktur antara kedua citra batas, karena setiap piksel dicampur
tanpa memperhatikan ke mana struktur pada posisi tersebut berpindah. Pada
barisan proyeksi tomografi, perpindahan tersebut nyata: setiap proyeksi
diambil pada sudut yang berbeda, sehingga struktur bergeser secara geometris.

Pendekatan berbasis pembelajaran mendalam mengganti rumus tetap tersebut
dengan sebuah fungsi terlatih `G` yang memetakan pasangan citra dan posisi
waktu ke citra antara:

```
Î_t = G(I₀, I₂, t ; θ)
```

dengan `θ` adalah parameter model yang dipelajari dari data.

### 2.2.4 Arsitektur U-Net

U-Net adalah arsitektur jaringan konvolusi berbentuk huruf U yang terdiri atas
jalur penyusutan (*encoder*) dan jalur pemulihan (*decoder*) yang simetris
(Ronneberger, Fischer, & Brox, 2015). Jalur penyusutan menurunkan resolusi
spasial secara bertahap sambil menaikkan jumlah kanal ciri, sehingga jaringan
menangkap konteks yang semakin luas. Jalur pemulihan mengembalikan resolusi
secara bertahap hingga kembali ke ukuran masukan.

Unsur yang menentukan pada arsitektur ini adalah **sambungan lompat** (*skip
connection*), yaitu penyaluran peta ciri dari setiap tingkat jalur penyusutan
langsung ke tingkat yang bersesuaian pada jalur pemulihan. Tanpa sambungan
tersebut, detail spasial halus yang hilang selama penyusutan tidak dapat
dipulihkan, dan keluaran menjadi kabur. Sifat inilah yang membuat U-Net sesuai
untuk tugas yang keluarannya harus setajam masukannya, termasuk interpolasi
frame.

Arsitektur ini juga telah banyak diterapkan pada citra medis di Indonesia;
Ermatita dan Ningsih (2025), misalnya, memakainya untuk segmentasi nodul paru
pada citra CT dan melaporkan ketelitian 94%. Tujuan penerapannya di sini
berbeda, yaitu memetakan sepasang frame menjadi frame antara alih-alih
memisahkan wilayah pada satu citra, tetapi keduanya bertumpu pada sifat yang
sama.

### 2.2.5 Spatio-Temporal U-Net (STU-Net)

Spatio-Temporal U-Net adalah pengembangan U-Net yang menerima masukan bersumbu
waktu dan sebuah skalar waktu sebagai pengondisi. Masukan model berupa
tumpukan dua frame batas beserta skalar `t`, dan keluarannya berupa satu frame
antara.

Model yang dipakai pada penelitian ini merupakan hasil kolaborasi dengan BRIN
sebagai bagian dari jalur riset pencitraan neutron yang sedang berjalan di
sana. Berkas bobotnya menyimpan nama arsitektur **`STUNet_2to1_TimeCond`**,
yang berarti *Spatio-Temporal U-Net, dua frame menjadi satu, berpengondisian
waktu*.

Pembagian pekerjaannya dinyatakan terbuka agar dapat ditelusuri. Arsitektur
dan bobot dasar berasal dari jalur riset bersama tersebut. Yang dikerjakan
pada skripsi ini adalah **merancang dan membangun sistem yang membuat model
itu dapat dipakai peneliti sehari-hari**, **mengukur perilakunya terhadap
arsip proyeksi yang sebenarnya**, dan **mendokumentasikan batas
keberlakuannya** sebagai dasar pengembangan berikutnya.

```
G : (ℝ^(2 × 1024 × 1024), ℝ) → ℝ^(1024 × 1024)
```

**[GAMBAR 2. 1 — Arsitektur Spatio-Temporal U-Net]**
*Gambarkan jalur encoder-decoder berbentuk U dengan sambungan lompat pada
setiap tingkat, sumbu waktu pada blok masukan, penyisipan layer SkipFusion pada
setiap sambungan lompat, serta jalur masukan skalar waktu t yang menyatu ke
jalur pemulihan pada lapisan tersempit.*

Perbedaan STU-Net terhadap U-Net baku terletak pada satu layer kustom,
`SkipFusion`, yang disisipkan pada setiap sambungan lompat. Layer inilah yang
meruntuhkan sumbu waktu sebelum ciri dari jalur encoder disalurkan ke jalur
pemulihan, dan di dalamnya terdapat dua operasi reduksi waktu yang bekerja
berdampingan sebagaimana disajikan pada Tabel 2.2.

**Tabel 2. 2 Operasi di Dalam Layer Kustom SkipFusion**

| Unsur | Operasi | Peran |
|-------|---------|-------|
| Reduksi rerata | `m = (1/T) Σ_{i=1..T} x_i` | Merangkum seluruh frame masukan menjadi satu peta ciri; menangkap struktur yang sama pada kedua batas |
| Reduksi batas akhir | `l = x_T` | Mengambil frame terakhir pada sumbu waktu; mempertahankan ciri batas terdekat |
| Penggabungan | `y = ReLU(W ∗₁ₓ₁ [m ‖ l] + b)` | Menggabungkan keduanya melalui konvolusi berkernel 1 × 1 sebelum disalurkan ke jalur pemulihan |

Notasi `‖` menyatakan penggabungan pada sumbu kanal, dan `∗₁ₓ₁` menyatakan
konvolusi berkernel 1 × 1. Karena kedua reduksi digabungkan lebih dahulu,
kedalaman masukan konvolusi tersebut selalu dua kali kedalaman keluarannya,
dan hal itu dapat diperiksa langsung pada berkas bobot: keempat instans
`SkipFusion` menyimpan kernel berbentuk (1, 1, 512, 256), (1, 1, 256, 128),
(1, 1, 128, 64) dan (1, 1, 64, 32), yakni 256, 128, 64 dan 32 filter pada
tingkat encoder yang semakin dangkal, bukan satu nilai tetap.

`SkipFusion` harus didefinisikan identik pada saat pemuatan bobot, karena
berkas bobot menyimpan namanya sebagai `Custom>SkipFusion` dan sebuah definisi
ulang yang berbeda akan menghasilkan model yang berbeda pula. Skrip pemuat
pada penelitian ini turut mendaftarkan dua layer lain, `TimeMean` dan
`TimeLast`, yang mewujudkan kedua reduksi di atas sebagai layer tersendiri.
Keduanya tidak terpakai pada berkas bobot yang digunakan, sebab pemeriksaan
langsung tidak menemukan satu pun di antara ke-31 lapisannya, dan tetap
didaftarkan agar bobot dari varian arsitektur terdahulu masih dapat dimuat
oleh skrip yang sama.

**Susunan lapisan.** Pemeriksaan langsung terhadap berkas bobot menunjukkan
model terdiri atas **31 lapisan** dengan **21.921.601 parameter**, disimpan
dalam presisi 32 bit sehingga berkasnya berukuran 87.796.792 byte. Susunannya
disajikan pada Tabel 2.3.

**Tabel 2. 3 Susunan Lapisan STUNet_2to1_TimeCond**

| Bagian | Lapisan | Keluaran | Peran |
|--------|---------|----------|-------|
| Masukan | `InputLayer` `(2, 1024, 1024, 1)` | 2 frame batas | Pasangan frame pada sumbu waktu |
| Masukan | `InputLayer` `(1,)` | skalar `t` | Posisi waktu frame yang diminta |
| Penyusutan | `TimeDistributed(Conv2D 32, 3×3, ReLU)` | 1024 × 1024 × 32 | Ciri awal, dihitung terpisah untuk tiap frame |
| Penyusutan | `TimeDistributed(MaxPooling2D 2×2)` | 512 × 512 | Penurunan resolusi |
| Penyusutan | `TimeDistributed(Conv2D 64, 3×3, ReLU)` | 512 × 512 × 64 | Ciri tingkat kedua |
| Penyusutan | `TimeDistributed(MaxPooling2D 2×2)` | 256 × 256 | Penurunan resolusi |
| **Temporal** | `ConvLSTM2D 128, 3×3, ReLU` | 256 × 256 × 128 | Perekaman hubungan antarframe |
| Penyusutan | `TimeDistributed(MaxPooling2D 2×2)` | 128 × 128 | Penurunan resolusi |
| **Temporal** | `ConvLSTM2D 256, 3×3, ReLU` | 128 × 128 × 256 | Perekaman hubungan antarframe |
| Penyusutan | `TimeDistributed(MaxPooling2D 2×2)` | 64 × 64 | Penurunan resolusi |
| **Temporal** | `ConvLSTM2D 512, 3×3, ReLU` | 64 × 64 × 512 | Peleburan sumbu waktu pada lapisan tersempit |
| Pengondisi | `Dense 4096, ReLU` → `Reshape (64, 64, 1)` | 64 × 64 × 1 | Skalar `t` diubah menjadi peta spasial |
| Pengondisi | `Concatenate` | 64 × 64 × 513 | Penyisipan pengondisi waktu ke lapisan tersempit |
| Pemulihan | `Conv2DTranspose 256` → `SkipFusion 256` → `Concatenate` → `Conv2D 256` | 128 × 128 | Tingkat pemulihan pertama |
| Pemulihan | `Conv2DTranspose 128` → `SkipFusion 128` → `Concatenate` → `Conv2D 128` | 256 × 256 | Tingkat pemulihan kedua |
| Pemulihan | `Conv2DTranspose 64` → `SkipFusion 64` → `Concatenate` → `Conv2D 64` | 512 × 512 | Tingkat pemulihan ketiga |
| Pemulihan | `Conv2DTranspose 32` → `SkipFusion 32` → `Concatenate` → `Conv2D 32` | 1024 × 1024 | Tingkat pemulihan keempat |
| Keluaran | `Conv2D 1, 3×3, tanh` | 1024 × 1024 × 1 | Satu frame antara pada rentang `[−1, 1]` |

Tiga hal pada susunan tersebut menentukan sifat model ini.

**Pertama, lapisan `ConvLSTM2D` adalah unsur "spatio-temporal" yang
sebenarnya.** Lapisan konvolusi biasa memperlakukan kedua frame batas sebagai
dua kanal yang berdiri sendiri, sedangkan `ConvLSTM2D` memprosesnya sebagai
barisan sehingga hubungan antarframe ikut dipelajari, bukan disimpulkan dari
penjajaran kanal. Dua lapisan pertama mengembalikan seluruh barisan
(`return_sequences=True`) agar sumbu waktu tetap tersedia bagi `SkipFusion`
pada jalur lompatan, sedangkan lapisan ketiga pada bagian tersempit meleburnya
menjadi satu peta ciri.

**Kedua, pengondisian waktu disisipkan pada lapisan tersempit.** Skalar `t`
tidak dimasukkan bersama citra, melainkan diperluas oleh lapisan `Dense`
menjadi 4096 nilai, dibentuk ulang menjadi peta 64 × 64, lalu digabungkan
dengan peta ciri pada bagian tersempit. Dengan begitu posisi waktu memengaruhi
seluruh jalur pemulihan, bukan hanya satu lapisan.

**Ketiga, aktivasi keluarannya `tanh`.** Inilah alasan model bekerja pada
rentang `[−1, 1]`, dan alasan mengapa normalisasi masukan maupun pengembalian
keluaran harus mengikuti rentang tersebut. Ketentuan ini bukan konvensi yang
dapat diubah sesuka hati, melainkan konsekuensi arsitektur.

**Normalisasi masukan.** Nilai piksel 16-bit dipetakan ke rentang `[−1, 1]`
sebelum masuk ke model:

```
x' = 2 · (x − x_min) / (x_max − x_min) − 1
```

dengan `x_min = 0` dan `x_max = 65535` sebagai konstanta global, bukan nilai
per citra. Penggunaan konstanta global bersifat wajib: normalisasi per citra
akan membuat nilai keabuan yang sama pada dua frame berbeda dipetakan ke nilai
masukan yang berbeda, sehingga model kehilangan acuan intensitas absolut yang
justru bermakna secara fisika pada citra atenuasi.

**Pembentukan sampel pelatihan.** Setiap contoh pelatihan disusun dari tiga
frame nyata pada barisan yang lengkap. Untuk sebuah jarak `g` dan indeks awal
`i`, model diberi frame ke-`i` dan ke-`i+g`, diberi tahu posisi waktu `t =
m/g`, dan dituntut menghasilkan frame ke-`i+m`:

```
untuk g = 2 .. G_max
untuk i = 0 .. (N − g − 1)
untuk m = 1 .. (g − 1)
t = m / g
sampel ← (I_i, I_{i+m}, I_{i+g}, t)
```

dengan `N` adalah jumlah frame dan `G_max` adalah jarak maksimum yang
diizinkan. Karena frame ke-`i+m` adalah frame hasil pindai yang sebenarnya,
kebenaran acuan tersedia tanpa pelabelan manual apa pun.

Terdapat dua ragam pembentukan sampel. Pada ragam **titik tengah saja**, hanya
sampel dengan `t = 0,5` yang diambil. Distribusi inilah yang menjadi dasar
bobot awal, dan yang membuat sistem harus melakukan interpolasi secara
rekursif. Pada ragam **`t` seimbang**, seluruh nilai `t = m/g` diambil,
sehingga model belajar menangani posisi waktu sembarang. Ragam kedua inilah
yang menjadi tujuan penyempurnaan model pada penelitian ini.

### 2.2.6 Fungsi Kerugian dan Optimasi

Fungsi kerugian yang digunakan adalah galat absolut rerata (L1) antara
keluaran model dan frame acuan:

```
L(θ) = (1/N) Σ_{p=1..N} | G(I₀, I₂, t ; θ)_p − y_p |
```

dengan `N` adalah jumlah piksel dan `p` menyatakan indeks piksel. Fungsi
kerugian L1 dipilih dan bukan L2 karena L1 kurang menghukum galat besar yang
jarang terjadi, sehingga keluarannya cenderung lebih tajam; L2 mendorong model
merata-ratakan kemungkinan dan menghasilkan citra kabur (Isola dkk., 2017).

Pembaruan parameter dilakukan dengan pengoptimal Adam (Kingma & Ba, 2015).
Adam memelihara rerata bergerak momen pertama dan kedua dari gradien:

```
m_t = β₁ · m_{t−1} + (1 − β₁) · g_t
v_t = β₂ · v_{t−1} + (1 − β₂) · g_t²

m̂_t = m_t / (1 − β₁^t)
v̂_t = v_t / (1 − β₂^t)

θ_t = θ_{t−1} − α · m̂_t / (√v̂_t + ε)
```

Nilai `β₁` yang digunakan pada penelitian ini adalah 0,5, mengikuti konvensi
yang lazim pada keluarga model pembangkit citra, sedangkan `β₂` dan `ε`
menggunakan nilai bawaan. Laju pembelajaran `α` merupakan hiperparameter yang
dapat diatur pada setiap sesi pelatihan.

### 2.2.7 Metrik Evaluasi Kualitas Citra

Empat metrik digunakan untuk menilai frame hasil interpolasi terhadap frame
acuan.

**Mean Absolute Error (MAE)** menyatakan rerata selisih mutlak per piksel:

```
MAE = (1/N) Σ | ŷ_p − y_p |
```

**Root Mean Squared Error (RMSE)** menyatakan akar dari rerata kuadrat
selisih, sehingga lebih peka terhadap galat besar:

```
MSE  = (1/N) Σ ( ŷ_p − y_p )²
RMSE = √MSE
```

**Peak Signal-to-Noise Ratio (PSNR)** menyatakan nisbah antara daya sinyal
puncak dan daya derau, dinyatakan dalam desibel:

```
PSNR = 10 · log₁₀ ( MAX² / MSE )
```

dengan `MAX` adalah nilai intensitas maksimum. Nilai PSNR yang lebih tinggi
menandakan kemiripan yang lebih besar. Perlu diperhatikan bahwa PSNR tidak
terdefinisi ketika MSE bernilai nol, yaitu ketika kedua citra identik.

**Structural Similarity Index Measure (SSIM)** menilai kemiripan struktural
dengan membandingkan luminans, kontras, dan struktur secara terpisah (Wang,
Bovik, Sheikh, & Simoncelli, 2004):

```
SSIM(x,y) = [ (2 μ_x μ_y + C₁)(2 σ_xy + C₂) ] / [ (μ_x² + μ_y² + C₁)(σ_x² +
σ_y² + C₂) ]
```

dengan `μ` menyatakan rerata, `σ²` menyatakan varians, `σ_xy` menyatakan
kovarians, serta `C₁` dan `C₂` adalah konstanta penstabil. Nilai SSIM berkisar
antara −1 dan 1, dengan 1 menandakan citra yang identik secara struktural.

Perlu ditegaskan bahwa PSNR dan SSIM terdefinisi pada rentang `[0, 1]`,
sementara model bekerja pada rentang `[−1, 1]`. Oleh karena itu keluaran model
harus dipetakan kembali sebelum diukur:

```
a = (ŷ + 1) / 2 ,  b = (y + 1) / 2
```

Kelalaian pada langkah pemetaan ini menghasilkan angka PSNR dan SSIM yang
tampak wajar namun keliru, dan kekeliruannya tidak terlihat dari nilainya
saja.

Keempat metrik tersebut merupakan ukuran baku pada penelitian rekonstruksi
tomografi bersudut jarang; Lv dkk. (2025), misalnya, memakai PSNR dan SSIM
sebagai dasar pembandingan hasil rekonstruksi berbasis jaringan konvolusi.
Yang ditambahkan penelitian ini adalah pelaporan rentang nilai frame acuan di
samping setiap angka, karena galat yang sama memiliki arti berbeda pada
rentang intensitas yang berbeda.

### 2.2.8 Arsitektur Hybrid Cloud-NAS

Arsitektur *hybrid cloud* memadukan sumber daya komputasi lokal dengan sumber
daya komputasi awan dalam satu sistem, dengan pembagian tanggung jawab yang
ditentukan oleh sifat beban kerja dan batasan tata kelola data. *Network
Attached Storage* (NAS) adalah perangkat penyimpanan yang terhubung ke
jaringan lokal dan menyediakan berkas kepada beberapa klien melalui protokol
berbagi berkas.

Pada penelitian ini, pembagiannya ditentukan oleh dua batasan yang tampak
bertentangan. Inferensi model menuntut kartu grafis yang tidak dimiliki
perangkat lokal, sedangkan data hasil penelitian tidak boleh menetap di
layanan pihak ketiga. Penyelesaiannya adalah menempatkan orkestrasi, basis
data, dan seluruh penyimpanan berkas pada perangkat lokal beserta volume NAS,
sementara satu-satunya yang menyeberang ke lingkungan awan adalah dua frame
batas per panggilan, dan hasilnya langsung ditarik kembali tanpa disimpan di
sana.

Konsekuensi rancangan ini adalah bahwa layanan inferensi harus diperlakukan
sebagai sesuatu yang dapat hilang sewaktu-waktu, bukan sebagai kebergantungan
yang pasti tersedia. Demikian pula volume NAS: sebuah berbagi jaringan yang
tidak terpasang meninggalkan direktori kosong yang tampak sah, sehingga sistem
harus dapat membedakan "belum ada berkas" dari "volume tidak terpasang" dan
menolak bekerja secara jelas pada keadaan kedua.

### 2.2.9 Sistem Multiplatform

Sistem multiplatform adalah sistem yang dapat dijalankan pada beberapa
lingkungan sasaran dari satu basis kode. Pada penelitian ini, aplikasi klien
dibangun menggunakan kerangka kerja Flutter yang mengompilasi satu basis kode
Dart menjadi aplikasi peramban dan aplikasi Android.

Pendekatan ini dipilih karena kebutuhan pengguna bersifat berpindah-pindah:
peneliti mengunggah arsip dari komputer laboratorium melalui peramban, lalu
memantau proses yang berjalan puluhan menit dari telepon genggam. Dua basis
kode terpisah untuk kebutuhan yang sama akan menuntut setiap perubahan
dikerjakan dua kali, dan menimbulkan risiko kedua sisi menyimpang.

Pendekatan satu basis kode dengan Flutter telah dipakai pada sejumlah rancang
bangun sistem informasi di Indonesia, antara lain sistem manajemen akademik
yang melayani sasaran peramban dan Android sekaligus (Rozi dkk., 2025) serta
aplikasi presensi berbasis Android (Kurniawan dkk., 2025). Kedua penelitian
tersebut menunjukkan kelayakan pendekatan ini pada sistem informasi biasa;
yang belum ditunjukkan adalah kelayakannya ketika sistem harus mengorkestrasi
komputasi jarak jauh yang dapat berhenti sewaktu-waktu, dan itulah yang diuji
pada penelitian ini.

### 2.2.10 Metode Prototyping

Prototyping adalah model proses perangkat lunak yang membangun purwarupa
sebagai sarana untuk memperjelas kebutuhan yang belum dapat dirumuskan lengkap
di awal (Pressman & Maxim, 2020). Siklusnya terdiri atas lima tahap yang
berulang:

1. **Communication**, yaitu penggalian kebutuhan dan tujuan bersama pemangku
   kepentingan. 2. **Quick Plan**, yaitu perencanaan cepat mengenai apa yang
   akan dibangun pada iterasi tersebut. 3. **Modeling Quick Design**, yaitu
   pemodelan rancangan yang berfokus pada bagian yang akan dilihat dan dicoba
   pengguna. 4. **Construction of Prototype**, yaitu pembangunan purwarupa. 5.
   **Deployment, Delivery & Feedback**, yaitu penyerahan purwarupa untuk
   dicoba, dan pengumpulan umpan balik yang menjadi masukan bagi iterasi
   berikutnya.

Purwarupa yang dihasilkan sebuah siklus tidak selalu berlanjut menjadi bagian
produk akhir. Sebagian bersifat **berkembang**, yaitu tumbuh menjadi sistem
yang diserahkan; sebagian lagi **dibuang** setelah menjawab pertanyaan yang
melatarbelakangi pembuatannya, dan Pressman dan Maxim (2020) menempatkan
keduanya sebagai keluaran yang wajar dari model proses ini.

Kedua bentuk itu muncul pada penelitian ini. Sisi platform dibangun secara
berkembang: setiap iterasi menambah kemampuan pada sistem yang sama, dan tidak
ada yang dibuang. Sebaliknya, percobaan penyempurnaan bobot model pada subbab
3.6.8 adalah purwarupa yang dibuang. Ia dibangun untuk menguji satu dugaan,
diukur terhadap ambang yang ditetapkan sebelum percobaan dimulai, lalu tidak
dipasang karena hasilnya belum memenuhi ambang itu. Sebuah hasil negatif yang
terukur adalah keluaran yang sah dari satu iterasi, bukan kegagalan metode;
yang tidak sah adalah memasang purwarupa yang gagal memenuhi ambangnya
sendiri.

Metode ini sesuai untuk penelitian ini karena dua alasan. Pertama, perilaku
model terhadap arsip citra neutron yang sebenarnya tidak dapat diketahui dari
kajian pustaka dan hanya terungkap setelah dicoba. Kedua, bentuk antarmuka
yang benar-benar berguna bagi peneliti baru terlihat setelah mereka mencobanya
langsung, bukan dari daftar kebutuhan yang disusun di awal.

Kesesuaian tersebut sejalan dengan temuan penelitian lain yang memakai metode
ini. Maharani dan Kurniawan (2025) melaporkan bahwa siklus purwarupa
menyingkap kebutuhan yang tidak terungkap pada tahap analisis awal, sementara
Arwidiyarti dkk. (2026) memadukannya dengan evaluasi usability sehingga umpan
balik pengguna terukur, bukan sekadar terkumpul. Pola kedua itu diikuti pada
penelitian ini melalui penyerahan purwarupa pada setiap iterasi sebagaimana
diuraikan pada subbab 3.8.

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

**[GAMBAR 2. 2 — Kerangka Berpikir Penelitian]**
*Gambarkan diagram alir tiga kolom. Kolom masalah memuat: akuisisi lambat,
waktu berkas terbatas, celah proyeksi, penanganan manual tidak konsisten,
asal-usul frame tidak tercatat. Kolom pendekatan memuat: algoritma STU-Net,
arsitektur hybrid cloud-NAS, metode Prototyping, validasi hold-out. Kolom
hasil memuat: sistem multiplatform terintegrasi, model terlatih beserta
metriknya, frame hasil interpolasi yang tercatat asal-usul dan angka mutunya.*

Kerangka berpikir penelitian ini bertolak dari keterbatasan waktu berkas
neutron yang menyebabkan munculnya celah pada barisan proyeksi. Celah tersebut
tidak dapat diisi secara memuaskan dengan interpolasi linier maupun pengerjaan
manual, sementara pengisian dengan model pembelajaran mendalam menuntut kartu
grafis yang tidak tersedia secara lokal dan tidak boleh mengorbankan
kedaulatan data penelitian.

Penelitian ini menjawabnya dengan menggabungkan tiga hal. Algoritma
Spatio-Temporal U-Net menyediakan kemampuan membangkitkan frame antara dengan
kesetiaan yang terukur. Arsitektur *hybrid cloud-NAS* menyediakan akses ke
kartu grafis tanpa memindahkan penyimpanan data. Metode Prototyping memastikan
sistem yang dibangun sesuai dengan cara kerja peneliti yang sebenarnya, bukan
dengan bayangan yang disusun di awal.

Keluaran yang diharapkan adalah sistem yang dapat diakses dari peramban maupun
telepon genggam, model yang telah disempurnakan dan catatan metrik per epoch, dan yang terpenting, setiap frame hasil interpolasi yang disertai
catatan asal-usul dan angka mutunya, sehingga peneliti yang menerimanya
memiliki dasar untuk mempertahankan hasil tersebut.

---

# BAB III
# ANALISA DAN PERANCANGAN

## 3.1 Alur Penelitian

Penelitian ini menggunakan metode pengembangan Prototyping. Alur penelitian
disusun mengikuti siklus metode tersebut, dengan pengujian yang dilakukan
langsung terhadap arsip citra neutron dan kartu grafis yang sebenarnya pada
setiap iterasi.

**[GAMBAR 3. 1 — Alur Penelitian]**
*Gambarkan diagram alir vertikal dengan tahapan berikut: Studi Pendahuluan dan
Observasi → Pengumpulan Data Citra → Analisa Kebutuhan (Communication) →
Perencanaan Cepat (Quick Plan) → Pemodelan Rancangan Cepat (Modeling Quick
Design) → Pembangunan Purwarupa (Construction of Prototype) → Penyerahan dan
Umpan Balik (Deployment, Delivery & Feedback) → titik keputusan "Kebutuhan
terpenuhi?" dengan cabang "Tidak" kembali ke Perencanaan Cepat dan cabang "Ya"
menuju Pengujian dan Evaluasi → Penyusunan Laporan.*

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
*Gambarkan diagram alir: Pengajuan Jadwal Waktu Berkas → Pemindaian →
Penulisan Berkas TIFF Bernomor → Pemeriksaan Kelengkapan Manual → titik
keputusan "Ada celah?" dengan cabang "Tidak" menuju Rekonstruksi, dan cabang
"Ya" bercabang tiga menuju Lanjut dengan Barisan Tidak Lengkap, Pengisian
Manual, serta Pemindaian Ulang.*

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
*Gambarkan diagram arsitektur berlapis. Lapis klien memuat Aplikasi Peramban
dan Aplikasi Android dari satu basis kode Flutter. Lapis peladen lokal memuat
Laravel 12 dengan Octane dan RoadRunner, basis data MySQL 8, antrean pekerjaan,
serta volume NAS untuk penyimpanan berkas. Lapis komputasi awan memuat layanan
inferensi FastAPI berkartu grafis di balik terowongan HTTP. Hubungkan lapis
klien ke lapis peladen dengan panah HTTPS bertoken, dan lapis peladen ke lapis
awan dengan panah multipart berisi dua frame batas.*

Alur kerja sistem yang diusulkan adalah sebagai berikut:

1. Peneliti masuk melalui aplikasi peramban atau Android, lalu mengunggah
   arsip `.zip` berisi frame proyeksi bernomor. Arsip berukuran besar diunggah
   secara berpotongan agar sambungan yang terputus dapat dilanjutkan. 2.
   Peladen mengekstraksi frame, memvalidasi format dan penomorannya, kemudian
   menampilkan pratinjau agar peneliti dapat memeriksa arsipnya sebelum
   pekerjaan dijalankan. 3. Peneliti menekan tombol mulai. Pekerjaan masuk ke antrean dengan posisinya, dan perkiraan waktu tunggu dihitung dari lama
   pekerjaan yang benar-benar pernah terukur pada sistem ini. 4. Pekerja
   antrean mengisi celah secara rekursif dengan memanggil layanan inferensi
   untuk setiap pasangan batas, dan mencatat asal-usul setiap frame yang
   dihasilkan. 5. Apabila arsip mengandung frame yang merupakan titik tengah
   tepat dari dua frame lain, frame tersebut disembunyikan, dibangkitkan ulang
   oleh model, lalu dibandingkan terhadap aslinya sebagai validasi *hold-out*.
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

**[GAMBAR 3. 4 — Diagram Use Case Sistem]**
*Gambarkan diagram use case dengan tiga aktor. Aktor Peneliti di sisi kiri
terhubung ke use case Masuk, Mengunggah Arsip Proyeksi, Melihat Pratinjau
Frame, Menjalankan Pengisian Celah, Memantau Antrean, Menelusuri Frame Hasil,
Mengunduh Hasil, Memulai Sesi Pelatihan, dan Memantau Metrik Pelatihan. Aktor
Administrator di sisi kanan terhubung ke use case Mengelola Pengguna,
Mendaftarkan Model, Memantau Antrean Seluruh Pengguna, Memantau Volume
Penyimpanan, dan Mendaftarkan Bobot Hasil Pelatihan Menjadi Model. Aktor
Pekerja GPU di sisi bawah terhubung ke use case Mengambil Pekerjaan Pelatihan,
Melaporkan Denyut, dan Mengirimkan Titik Simpan serta Bobot Akhir. Tarik relasi
include dari Menjalankan Pengisian Celah ke Memantau Antrean.*

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

**[GAMBAR 3. 5 — Diagram Aktivitas Pengisian Celah Proyeksi]**
*Gambarkan diagram aktivitas dengan tiga kolom renang: Peneliti, Peladen Lokal,
dan Layanan Inferensi. Kolom Peneliti memuat aktivitas Mengunggah Arsip,
Memeriksa Pratinjau, dan Menekan Tombol Mulai. Kolom Peladen Lokal memuat
Memvalidasi Arsip, Membaca Penomoran Frame, Menentukan Celah, Menampilkan
Pratinjau, Memasukkan Pekerjaan ke Antrean, Menghitung Pasangan Batas, Menyusun
Ulang Barisan, dan Mengemas Hasil. Kolom Layanan Inferensi memuat Menerima Dua
Frame Batas dan Membangkitkan Frame Antara. Beri simpul keputusan setelah
Menghitung Pasangan Batas dengan cabang "masih ada celah" yang kembali ke
Layanan Inferensi dan cabang "selesai" yang menuju Menyusun Ulang Barisan. Beri
pula simpul keputusan setelah Memvalidasi Arsip dengan cabang "tidak sah" yang
menuju Menampilkan Pesan Penolakan dan mengakhiri alur.*

Simpul keputusan yang kembali ke layanan inferensi adalah tempat sifat
rekursif algoritma tampak pada tingkat sistem: satu pekerjaan dapat memanggil
layanan inferensi berkali-kali, dan jumlah panggilannya ditentukan oleh lebar
celah, bukan oleh jumlah frame yang diunggah.

### 3.5.4 Perancangan Basis Data

**[GAMBAR 3. 6 — Diagram Relasi Antar-Entitas]**
*Gambarkan diagram relasi antar-entitas dengan entitas users, models,
analysis_records, training_datasets, training_jobs, training_metrics,
training_samples, dan user_activities. Tarik relasi satu-ke-banyak dari users ke
analysis_records, training_datasets, training_jobs, dan user_activities; dari
models ke analysis_records; dari training_datasets ke training_jobs; serta dari
training_jobs ke training_metrics dan training_samples. Tandai kunci utama pada
setiap entitas dan kunci tamu pada setiap ujung relasi.*

**Tabel 3. 4 Rancangan Tabel Basis Data**

| Tabel | Isi | Kolom Penting |
|-------|-----|---------------|
| `users` | Akun peneliti dan administrator | `id`, `name`, `email`, `password`, `role`, `is_active` |
| `models` | Model terdaftar beserta alamat layanan inferensinya | `id`, `name`, `version`, `endpoint_url`, `auth_token`, `status`, `is_active` |
| `analysis_records` | Satu baris per pekerjaan pengisian celah | `id`, `user_id`, `model_id`, `job_id`, `status`, `input_files_count`, `processing_time_seconds`, `validation`, `expires_at`, `files_deleted_at` |
| `training_datasets` | Arsip data latih yang dititipkan peneliti | `id`, `name`, `source_type`, `archive_path`, `size_bytes`, `checksum`, `uploaded_by`, `archive_deleted_at` |
| `training_jobs` | Satu baris per sesi pelatihan | `id`, `name`, `training_dataset_id`, `total_epochs`, `current_epoch`, `status`, `hyperparameters`, `checkpoint_path`, `weights_path`, `heartbeat_at` |
| `training_metrics` | Metrik per epoch | `id`, `training_job_id`, `epoch`, `metrics`, `recorded_at` |
| `training_samples` | Gambar contoh keluaran model per epoch | `id`, `training_job_id`, `epoch`, `image_path` |
| `user_activities` | Jejak audit tindakan pengguna | `id`, `user_id`, `activity_type`, `description`, `ip_address`, `created_at` |

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

| Metode dan Alamat | Kegunaan | Pemanggil |
|-------------------|----------|-----------|
| `POST /api/login` | Menukar kredensial dengan token | Peneliti, Administrator |
| `GET /api/me/models` | Daftar model beserta keadaan ketersediaannya | Peneliti |
| `POST /api/predictions/uploads` | Membuka sesi unggah berpotongan | Peneliti |
| `PATCH /api/predictions/uploads/{id}` | Mengirim satu potongan arsip | Peneliti |
| `POST /api/predictions/uploads/{id}/finalize` | Menutup sesi unggah dan membentuk pekerjaan | Peneliti |
| `GET /api/predictions/{id}` | Keadaan satu pekerjaan beserta posisi antreannya | Peneliti |
| `POST /api/predictions/{id}/start` | Menjalankan pengisian celah | Peneliti |
| `GET /api/predictions/{id}/frames` | Daftar frame masukan dan keluaran beserta asal-usulnya | Peneliti |
| `GET /api/predictions/{id}/download/complete` | Mengunduh arsip hasil beserta metadata dan manifes | Peneliti |
| `POST /api/me/training/jobs` | Memulai sesi pelatihan | Peneliti |
| `GET /api/me/training/jobs/{id}` | Kemajuan sesi pelatihan beserta metrik per epoch | Peneliti |
| `POST /api/training/worker/claim` | Mengambil pekerjaan pelatihan dari antrean | Pekerja GPU |
| `POST /api/training/worker/jobs/{id}/checkpoint` | Mengirim titik simpan dan metrik satu epoch | Pekerja GPU |
| `POST /api/training/worker/jobs/{id}/complete` | Mengirim bobot akhir | Pekerja GPU |
| `GET /api/admin/queue` | Antrean seluruh pengguna beserta keadaan pekerja | Administrator |

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


**[GAMBAR 3. 7 — Rancangan Antarmuka Unggah dan Pratinjau Frame]**
*Gambarkan tata letak layar unggah: area pemilihan berkas dengan indikator
kemajuan unggah berpotongan, daftar frame yang terbaca beserta nomornya,
penanda celah pada barisan, penelusur tumpukan frame dengan penggeser dan
kemampuan perbesar, serta tombol mulai analisis.*

**[GAMBAR 3. 8 — Rancangan Antarmuka Pemantauan Pelatihan Model]**
*Gambarkan tata letak layar pelatihan: kartu memulai sesi pelatihan berisi nama
sesi dan jumlah epoch, daftar sesi berjalan beserta kemajuannya, tabel metrik
per epoch dengan kolom MAE, MSE, PSNR, dan SSIM, serta penelusur gambar contoh
keluaran model per epoch.*

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

**[GAMBAR 3. 9 — Alur Interpolasi Rekursif]**
*Gambarkan pohon rekursi untuk contoh frame 1 dan 7. Tingkat pertama
menghasilkan frame 4 dari pasangan (1, 7). Tingkat kedua menghasilkan frame
2 dan 3 dari pasangan (1, 4) serta frame 5 dan 6 dari pasangan (4, 7). Beri
warna berbeda untuk frame hasil pindai dan frame hasil model, serta cantumkan
nilai generation pada setiap simpul.*

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

Sebelum bobot dasar disempurnakan, perilakunya diukur lebih dahulu. Pengukuran ini diperlukan karena keterangan yang beredar mengenai model
tersebut, yaitu bahwa ia mengabaikan masukan skalar waktu, merupakan tafsiran
atas gejala dan bukan hasil pengukuran. Sebuah penyempurnaan yang berangkat
dari tafsiran yang salah akan memperbaiki hal yang tidak rusak.

Pengukuran dilakukan terhadap berkas bobot yang dipakai melalui layanan
inferensi yang berjalan, menggunakan arsip proyeksi nyata dari BRIN.

**Rancangan model perlu dinyatakan lebih dahulu**, sebab ia menentukan mana
yang merupakan batas rancangan dan mana yang benar-benar kekurangan. Dua
sumber menyatakannya tanpa ragu.

Notebook evaluasi yang menyertai bobot tersebut memanggil model dengan skalar
waktu yang dipaku pada satu nilai, yaitu `t = 0,5`, menamai keluarannya dengan
nomor ganjil `2i + 1`, dan menghasilkan tepat satu frame untuk setiap pasangan
frame masukan yang berurutan. Tidak ada rekursi di dalamnya.

Skrip pelatihan menyatakan hal yang sama dari sisi data. Fungsi pembentuk
sampel hanya menerima sampel yang nilai `t`-nya 0,5, kecuali ragam `t` seimbang
dinyalakan, dan keterangan pada fungsi itu menyebut distribusi tersebut sebagai
distribusi tempat bobot yang terkirim dilatih.

Kedua sumber itu menetapkan bahwa **model dirancang untuk menyisipkan satu
frame pada titik tengah di antara dua frame hasil pindai**. Masukan skalar
waktu memang tersedia pada arsitekturnya, tetapi tidak pernah dilatih maupun
dijalankan pada nilai selain 0,5. Karena itu pengukuran berikut tidak
memperlakukan tanggapan yang lemah terhadap `t` sebagai kerusakan, melainkan
sebagai batas rancangan yang besarnya selama ini belum pernah diukur.

**Bagian pertama: apakah jalur pengondisi waktu terlatih?** Pemeriksaan
langsung terhadap bobot menunjukkan jalur tersebut sama sekali tidak mati.
Lapisan `Dense` yang menerima skalar waktu tidak memiliki satu pun bobot yang
teredam, nol dari 4.096 neuron dengan `|w| < 10⁻⁶`, dan pada lapisan dekoder
pertama, kanal peta waktu justru **diberi bobot 2,35 kali lebih besar**
daripada rerata 512 kanal citra di sebelahnya. Seluruh 512 kanal citra
tersebut berbobot lebih kecil daripada kanal waktu.

**Bagian kedua: apakah keluarannya berubah ketika skalar waktu diubah?**
Sampel `Block Machine` berjarak dua derajat menyediakan kebenaran acuan pada
posisi yang bukan titik tengah. Dengan frame 0051 dan 0057 sebagai batas,
frame 0053 berada tepat pada `t = 1/3` dan frame 0055 pada `t = 2/3`; keduanya
disembunyikan dari model. Hasilnya disajikan pada Tabel 3.11.

**Tabel 3. 11 Tanggapan Bobot Dasar terhadap Perubahan Skalar Waktu**

| Perbandingan | MAE |
|--------------|----:|
| Keluaran `t = 0,25` terhadap keluaran `t = 0,75` | 2,20 |
| Keluaran `t = 1/3` terhadap keluaran `t = 2/3` | 1,45 |
| **Pembanding:** frame nyata 0053 terhadap frame nyata 0055 | **563,48** |
| **Pembanding:** frame batas 0051 terhadap frame batas 0057 | **1.258,22** |

Keluaran memang berubah, tetapi hanya sebesar **0,4%** dari perubahan yang
seharusnya terjadi. Ketika skalar waktu digeser dari `0,25` ke `0,75`,
keluaran bergerak sejauh MAE 2,20, sementara perubahan yang sebenarnya terjadi
di antara kedua posisi tersebut adalah MAE 563,48.

Akibatnya terlihat pada pencocokan terhadap acuan. Keluaran pada `t = 1/3`
seharusnya paling menyerupai frame 0053, dan keluaran pada `t = 2/3` paling
menyerupai frame 0055. Yang terjadi, seluruh nilai `t` menghasilkan galat yang
praktis sama: terhadap 0053 galatnya bergerak hanya dari 530,10 ke 529,64
sepanjang seluruh rentang `t` yang diuji.

**Kesimpulan pengukuran.** Batasnya bukan jalur waktu yang mati, melainkan
jalur waktu yang **tidak pernah dilatih untuk berpengaruh**. Kapasitasnya
sudah ada di dalam arsitektur, bahkan diberi bobot paling besar di antara
seluruh kanal masukan dekoder, tetapi distribusi data pelatihannya tidak
pernah menuntut kapasitas itu dipakai. Inilah batas yang menjadi sasaran penyempurnaan pada penelitian ini, dan inilah pula alasan mengapa
penyempurnaannya berbentuk pelatihan ulang dengan ragam `t` seimbang, bukan
perubahan arsitektur.

**Bagian ketiga: bagaimana mutu bobot dasar terhadap pembanding sederhana?**
Untuk menempatkan angka-angka di atas pada ukuran yang wajar, keluaran model
dibandingkan terhadap pencampuran linier, yaitu rata-rata berbobot kedua frame
batas pada posisi waktu yang benar. Hasilnya disajikan pada Tabel 3.12.

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

Hasil ini menuntut pembacaan yang hati-hati, dan menjadi salah satu temuan
penting penelitian ini. Pada MAE dan PSNR, pencampuran linier justru unggul.
Hal tersebut wajar dan sudah lama dikenal pada evaluasi citra: rata-rata dua
citra adalah tebakan yang meminimalkan galat kuadrat, sehingga ia hampir
selalu menang pada metrik berbasis selisih piksel, dengan harga berupa citra
yang lebih kabur.

Pada SSIM, yang membandingkan luminans, kontras, dan struktur secara lokal,
model unggul pada **seluruh lima kasus**. Selisihnya pun bergerak sesuai
dugaan: pada sampel berjarak dua derajat, tempat perubahan antarframe kecil
dan hampir linier, keunggulan model tipis (0,0002–0,0003); pada kasus yang
lebih sulit, yaitu Al Cu berjarak tiga derajat dan Contrast dengan rentang
enam frame, keunggulan model melebar menjadi 0,0064 dan 0,0091.

Dengan kata lain, semakin jauh persoalannya dari pencampuran linier, semakin
jelas model dibutuhkan. Konsekuensinya bagi rancangan pengujian pada subbab
3.7 bersifat mengikat: **MAE dan PSNR tidak boleh berdiri sendiri sebagai
ukuran keberhasilan**, karena keduanya akan memilih citra kabur, dan sebuah
frame proyeksi yang kabur justru merusak rekonstruksi yang menjadi tujuan
akhirnya.

### 3.6.7 Analisa Capaian Pelatihan Model

Metode prototyping menuntut setiap iterasi menghasilkan sesuatu yang dapat
dicoba, sehingga sebagian dari rancangan di atas telah dijalankan terhadap
perangkat keras yang sebenarnya sebelum proposal ini disusun. Angka-angka
berikut adalah capaian awal tersebut, bukan hasil akhir penelitian.

Sesi pelatihan pertama berjalan satu epoch dan selesai dalam 2 menit 29 detik,
yang membuktikan rantai pelatihan berfungsi dari pengambilan pekerjaan hingga
pengembalian bobot. Sesi kedua berjalan penuh sepanjang 20 epoch dengan 40
sampel per epoch, dan metriknya disajikan pada Tabel 3.13.

**Tabel 3. 13 Metrik Pelatihan per Epoch pada Sesi Penyempurnaan Awal**

| Epoch | MAE | MSE | PSNR (dB) | SSIM |
|------:|----:|----:|----------:|-----:|
| 1 | 0,014976 | 0,000678 | 38,2060 | 0,9860 |
| 3 | 0,014770 | 0,000619 | 38,7064 | 0,9861 |
| 4 | 0,014521 | 0,000597 | 38,9735 | 0,9863 |
| 5 | 0,014542 | 0,000592 | 39,0188 | 0,9863 |
| 7 | 0,014345 | 0,000581 | 39,1215 | 0,9865 |
| 9 | 0,014290 | 0,000573 | 39,1743 | 0,9866 |
| 10 | 0,014289 | 0,000567 | 39,2281 | 0,9867 |
| 12 | 0,014060 | 0,000552 | 39,2967 | 0,9868 |
| 13 | 0,014190 | 0,000559 | 39,2909 | 0,9868 |
| 15 | 0,014122 | 0,000554 | 39,3137 | 0,9869 |
| 16 | 0,013962 | 0,000547 | 39,4021 | 0,9869 |
| 18 | 0,013996 | 0,000544 | 39,4258 | 0,9870 |
| 20 | 0,013986 | 0,000538 | 39,4436 | 0,9871 |

Sepanjang dua puluh epoch tersebut MAE turun 6,6% dari 0,014976 menjadi
0,013986, MSE turun 20,6%, PSNR naik 1,24 dB, dan SSIM naik dari 0,9860
menjadi 0,9871. Arah keempatnya konsisten, dan penurunan MAE pada epoch 13 dan
18 yang sesaat berbalik naik merupakan riak yang lazim pada pelatihan
bertumpak kecil, bukan tanda pelatihan yang gagal.

Dua hal perlu ditegaskan dalam membaca tabel tersebut. Pertama, kenaikan SSIM
sebesar 0,0011 terlihat kecil karena nilai awalnya memang telah tinggi. Bobot
dasar sudah terlatih, dan yang dikerjakan sesi ini adalah penyempurnaan, bukan
pelatihan dari nol. Kedua, tidak setiap epoch tercatat pada tabel: metrik
dikirimkan pekerja pada setiap titik simpan, dan epoch yang tidak muncul
adalah epoch yang titik simpannya bertepatan dengan pergantian sesi komputasi.

**Capaian pada sisi inferensi.** Tiga pekerjaan pengisian celah telah
dijalankan terhadap layanan inferensi sungguhan, masing-masing
menghasilkan dua frame dari tiga frame masukan dalam 47, 42, dan 54 detik.
Validasi *hold-out* pada ketiganya menghasilkan MAE 359,747, RMSE 688,092, dan
PSNR 39,58 dB terhadap frame acuan yang rentangnya 108 hingga 56.487, atau
galat sekitar 0,6% dari rentang yang diukur.

**Batas keberlakuan angka-angka ini.** Seluruhnya diperoleh dari satu himpunan
data yang terbatas dan dari sesi pelatihan yang pendek. Angka tersebut cukup
untuk menunjukkan bahwa rantai pelatihan, inferensi, dan validasi telah
berfungsi ujung ke ujung, tetapi belum cukup untuk menyimpulkan mutu model
secara umum. Pengujian menyeluruh sebagaimana dirancang pada subbab 3.7 adalah
yang akan menjawab pertanyaan tersebut.

**Kriteria keberhasilan penyempurnaan.** Metrik pelatihan pada Tabel 3.13
hanya menyatakan bahwa model membaik pada distribusi yang dilatihkan; ia tidak menyatakan bahwa batas pada subbab 3.6.6 telah terlampaui. Penyempurnaan
dinyatakan berhasil apabila pengukuran yang sama persis dengan Tabel 3.11,
diulang terhadap bobot hasil penyempurnaan, memenuhi dua syarat berikut:

1. **Tanggapan terhadap skalar waktu meningkat berlipat.** Selisih keluaran
   antara `t = 0,25` dan `t = 0,75` harus naik dari 2,20 menjadi
   sekurang-kurangnya satu tingkat besaran yang sebanding dengan perubahan
   nyata antarframe (563,48 pada pasangan uji yang sama). 2. **Perubahannya
   menuju arah yang benar.** Keluaran pada `t = 1/3` harus menghasilkan galat
   yang lebih kecil terhadap frame 0053 dibandingkan keluaran pada `t = 2/3`,
   dan sebaliknya untuk frame 0055. Pada bobot dasar, kedua galat tersebut
   praktis tidak dapat dibedakan.

Syarat kedua yang menentukan, dan ia dirumuskan agar **dapat dipatahkan**:
apabila setelah penyempurnaan keluaran pada kedua nilai `t` tersebut masih
sama dekatnya terhadap kedua acuan, penyempurnaan ini gagal dan harus
dinyatakan gagal. Kriteria yang tidak dapat gagal bukanlah kriteria.

Sebagai akibat lanjutan, keberhasilan juga akan terbaca pada kolom
`generation` di manifes hasil. Selama model hanya dapat diandalkan pada titik
tengah, celah lebar harus diisi secara rekursif sehingga sebagian besar frame
keluaran bergenerasi dua ke atas. Apabila penyempurnaan berhasil, seluruh
frame pada satu celah dapat dibangkitkan langsung dari sepasang frame hasil
pindai, dan kolom tersebut seharusnya bernilai satu untuk seluruh baris.

Kedua syarat tersebut telah diukur, dan hasilnya diuraikan pada subbab 3.6.8.

### 3.6.8 Percobaan Penyempurnaan Bobot dan Keputusan Rancangan yang Diambil

Subbab 3.6.6 menunjukkan bahwa bobot dasar tidak memakai masukan skalar
waktunya. Subbab ini menguraikan percobaan penyempurnaan yang dirancang untuk
melampaui batas tersebut, perhitungan yang mendasarinya, hasil pengukurannya,
serta keputusan rancangan yang diambil sesudahnya karena hasil itu belum
memadai.

Percobaan ini dilaporkan meskipun belum berhasil. Sebuah percobaan yang
terukur dan gagal memberi dua hal yang tidak diberikan oleh percobaan yang
tidak pernah dijalankan: ia menyempitkan ruang penyebab, dan ia memberi angka
pembanding bagi percobaan berikutnya.

#### a. Yang diubah, dan yang sengaja tidak diubah

**Arsitekturnya tidak disentuh.** Pemeriksaan berkas bobot sebelum dan sesudah
pembaruan memberi hasil yang identik: nama arsitektur `STUNet_2to1_TimeCond`,
31 lapisan, dan 21.921.601 parameter pada keduanya, dengan cacah jenis lapisan
yang sama persis. Tidak ada lapisan yang ditambah, dihapus, maupun diubah
bentuknya.

Yang diubah adalah **distribusi data yang dilatihkan**. Kapasitas pengondisian
waktu sudah ada di dalam arsitektur sejak awal, dan subbab 3.6.6 menunjukkan
bobotnya bahkan paling besar di antara seluruh kanal masukan dekoder, tetapi
distribusi pelatihannya tidak pernah menuntut kapasitas itu dipakai.

**Tabel 3. 14 Parameter Pelatihan Pembaruan Model**

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

#### b. Perhitungan jumlah contoh pelatihan

Pembentukan contoh mengikuti rumus pada subbab 2.2.5. Untuk barisan berisi `N`
frame dan lebar celah maksimum `G`, banyaknya contoh adalah

```
S(N, G) = Σ[g = 2..G]  (N − g) · (g − 1)
```

Setiap suku menyatakan: untuk sebuah lebar celah `g`, terdapat `N − g` posisi
awal yang mungkin, dan pada setiap posisi terdapat `g − 1` frame antara yang
dapat dijadikan sasaran. Dengan `N = 10` frame:

```
G = 4 :  8·1 + 7·2 + 6·3                          =  40 contoh
G = 8 :  8·1 + 7·2 + 6·3 + 5·4 + 4·5 + 3·6 + 2·7  = 112 contoh
```

Kenaikan dari 40 menjadi 112 contoh bukan sekadar penambahan jumlah. Yang
ditambahkan adalah justru contoh yang menuntut model membedakan `t`: pada `g =
8`, satu pasangan frame yang sama muncul dengan **tujuh sasaran berbeda**,
sehingga satu-satunya cara menurunkan kerugian adalah dengan memakai skalar
waktu. Pada `G = 4` pasangan yang sama paling banyak muncul dengan tiga
sasaran, dan pada distribusi titik tengah saja hanya dengan satu.

#### c. Metrik pelatihan

**Tabel 3. 15 Metrik Pelatihan Pembaruan Model per Epoch**

| Epoch | MAE | PSNR (dB) | SSIM | Epoch | MAE | PSNR (dB) | SSIM |
|------:|----:|----------:|-----:|------:|----:|----------:|-----:|
| 1 | 0,022817 | 34,7151 | 0,9804 | 11 | 0,020426 | 35,8952 | 0,9829 |
| 2 | 0,022297 | 35,1465 | 0,9808 | 12 | 0,020067 | 35,9965 | 0,9831 |
| 3 | 0,022132 | 35,2299 | 0,9810 | 13 | 0,019863 | 36,1089 | 0,9832 |
| 4 | 0,021957 | 35,2773 | 0,9812 | 14 | 0,019653 | 36,1519 | 0,9833 |
| 5 | 0,021814 | 35,3432 | 0,9814 | 15 | 0,019467 | 36,2300 | 0,9834 |
| 6 | 0,021732 | 35,4262 | 0,9817 | 16 | 0,019074 | 36,3877 | 0,9836 |
| 7 | 0,021313 | 35,5472 | 0,9821 | 17 | 0,018784 | 36,5265 | 0,9837 |
| 8 | 0,021169 | 35,6399 | 0,9823 | 18 | 0,018593 | 36,6440 | 0,9840 |
| 9 | 0,020817 | 35,7518 | 0,9825 | 19 | 0,018376 | 36,7373 | 0,9842 |
| 10 | 0,020607 | 35,8205 | 0,9827 | 20 | 0,018316 | 36,8088 | 0,9843 |

Sepanjang dua puluh epoch, MAE turun 19,7%, PSNR naik 2,09 dB, dan SSIM naik
dari 0,9804 menjadi 0,9843, tanpa satu pun epoch yang berbalik memburuk.

**Angka pada tabel ini tidak boleh dibandingkan langsung dengan Tabel 3.13.**
Sesi pembanding sebelumnya dilatih pada 40 contoh dengan `max_gap = 4`,
sedangkan sesi ini pada 112 contoh dengan `max_gap = 8`; contoh tambahannya
justru yang paling sulit. MAE yang lebih besar di sini menyatakan soal yang
lebih berat, bukan model yang lebih buruk, sebagaimana dua nilai ujian dengan
tingkat kesukaran berbeda tidak dapat dijajarkan.

#### d. Prosedur pengukuran sesudah pembaruan

Pengukuran dilakukan dengan **memuat kedua bobot pada proses yang sama**,
memberinya masukan yang sama, dan mengukurnya dengan kode yang sama, sehingga
tidak ada perbedaan lingkungan yang dapat menjelaskan selisih hasilnya. Enam
belas inferensi dijalankan seluruhnya, delapan per bobot.

Ujinya adalah **sapuan tujuh posisi dari satu pasangan frame hasil pindai**:
frame 0051 dan 0069 sebagai batas, lalu model diminta membangkitkan frame pada
`t = 1/8` sampai `t = 7/8`. Ketujuh frame sasarannya, yaitu 0053 sampai 0065,
tersedia sebagai kebenaran acuan dan disembunyikan dari model. Inilah skenario
yang pada bobot dasar menghasilkan tujuh citra kembar.

**Tabel 3. 16 Sapuan Tujuh Posisi dari Satu Pasangan Frame Pindai**

| `t` yang diminta | 1/8 | 2/8 | 3/8 | 4/8 | 5/8 | 6/8 | 7/8 | Rerata |
|------------------|----:|----:|----:|----:|----:|----:|----:|-------:|
| Frame acuan | 0053 | 0055 | 0057 | 0059 | 0061 | 0063 | 0065 | |
| MAE bobot dasar | 1218,7 | 1110,1 | 1058,7 | 1039,3 | 1047,0 | 1037,9 | 1088,3 | **1085,7** |
| MAE revisi 4 | 914,4 | 812,4 | 769,1 | 756,9 | 774,8 | 766,4 | 808,9 | **800,4** |
| MAE campur linier | 501,7 | 762,5 | 925,2 | 989,4 | 955,5 | 787,4 | 510,2 | 776,0 |

#### e. Hasil terhadap kriteria yang ditetapkan lebih dahulu

**Tabel 3. 17 Hasil Pembaruan terhadap Kriteria Keberhasilan**

| Kriteria | Bobot dasar | Revisi 4 | Hasil |
|----------|------------:|---------:|:-----:|
| 1. Mutu pada rentang 2 tidak memburuk | 359,7 | **352,5** | **Terpenuhi** |
| 2. Mutu pada rentang 8 membaik | 1039,3 | **756,9** | **Terpenuhi** |
| 3. Tanggapan terhadap `t` meningkat | 3,3 | **562,9** | **Terpenuhi** |
| 4. Frame layak pada celah 8 bertambah | 0 dari 7 | 0 dari 7 | **Tidak terpenuhi** |

**Kriteria 3 adalah yang pokok.** Selisih antara keluaran pada `t = 1/8` dan
`t = 7/8`, dua posisi terjauh pada pasangan yang sama, naik dari **3,3 menjadi
562,9**, sementara selisih yang seharusnya, yaitu antara frame nyata 0053 dan
0065, adalah 2.020,2. Tanggapan model karena itu naik dari **0,17% menjadi
27,87%**.

Ukuran kedua yang menyatakan hal yang sama dari sudut berbeda adalah
**keragaman keluaran**: rata-rata jarak antar ketujuh frame yang dihasilkan,
dibandingkan rata-rata jarak antar ketujuh frame nyata yang bersesuaian.

**Tabel 3. 18 Keragaman Keluaran terhadap Gerak Frame Nyata**

| | Jarak antar-keluaran | Jarak antar-frame nyata | Rasio |
|---|---:|---:|---:|
| Bobot dasar | 1,5 | 1.107,9 | **0,001** |
| Revisi 4 | 261,1 | 1.107,9 | **0,236** |

Rasio 0,001 berarti ketujuh keluaran bobot dasar, untuk keperluan apa pun,
adalah satu citra yang sama, dan inilah pembuktian langsung atas gejala yang
selama ini dilaporkan sebagai "model menghasilkan gambar yang sama". Rasio
0,236 pada revisi 4 berarti keluarannya kini benar-benar bergerak mengikuti
posisi waktu yang diminta.

#### f. Penilaian: mekanisme terajarkan, hasilnya belum berguna

Tiga dari empat kriteria terpenuhi. Kriteria keempat tidak, dan kegagalannya
menentukan keputusan rancangan pada subbab berikutnya.

**Yang berhasil ditunjukkan.** Tanggapan model terhadap skalar waktu naik dari
0,17% menjadi 27,87%, dan keragaman keluarannya dari rasio 0,001 menjadi
0,236. Kedua angka itu membuktikan satu hal yang sebelumnya hanya dugaan:
**kapasitas pengondisian waktu pada arsitektur ini memang dapat diaktifkan
melalui distribusi data pelatihan, tanpa mengubah satu lapisan pun.**

**Yang belum berhasil.** Perubahan itu belum cukup besar untuk berguna. Uji
pada Sample Contrast, objek yang tidak pernah dilatihkan, memperlihatkannya
paling jelas. Ketika frame 0004, 0005, dan 0006 dibangkitkan dari pasangan
frame pindai yang sama, jarak antarketiganya adalah:

**Tabel 3. 19 Jarak Antar-Hasil pada Objek yang Tidak Dilatihkan**

| Sumber frame | Jarak antar-hasil | Rasio terhadap gerak yang benar |
|--------------|------------------:|-------------------------------:|
| Bobot dasar | 2,9 | 0,016 |
| Bobot hasil penyempurnaan | 37,4 | 0,210 |
| Pencampuran linier (acuan gerak) | 178,2 | 1,000 |

Jarak 37,4 pada citra berskala 0 sampai 57.000 setara **0,065% dari rentang**,
yaitu di bawah ambang yang dapat dibedakan mata. Pemeriksaan visual terhadap
ketiga frame keluaran memang tidak memperlihatkan perbedaan. Kenaikan tiga
belas kali lipat terhadap bobot dasar tetap kecil secara mutlak, karena titik
awalnya hampir nol.

**Satu catatan mengenai keberlakuan angka.** Sapuan tujuh frame pada Tabel
3.16 memakai frame yang termasuk dalam data pelatihan, sehingga sebagiannya
dapat berupa hafalan. Uji Sample Contrast tidak demikian, karena objek itu
tidak pernah dilatihkan, dan rasionya 0,210, sebanding dengan 0,236 pada uji
yang pertama. Kesesuaian keduanya menunjukkan efeknya nyata dan menyeberang ke
data baru, tetapi angka Contrast yang lebih layak dipercaya.

**Sebab yang paling mungkin: pelatihan terhenti terlalu dini, dan datanya
terlalu sedikit.** Penurunan MAE pada lima epoch terakhir masih berjalan pada
76% laju lima epoch pertama, yang berarti kurvanya belum mendatar ketika
pelatihan dihentikan. Di samping itu, sepuluh frame yang menghasilkan 112
contoh berhadapan dengan 21,9 juta parameter, perbandingan yang membuat
penghafalan jauh lebih mudah daripada penyimpulan.

#### g. Keputusan rancangan yang diambil

Berdasarkan penilaian di atas, **sistem yang dibangun pada penelitian ini
memakai bobot dasar**, bukan bobot hasil percobaan penyempurnaan. Bobot hasil
percobaan disimpan dan didokumentasikan, tetapi tidak dipasang sebagai model
yang melayani peneliti, karena perbaikan yang dihasilkannya belum dapat
dipertanggungjawabkan sebagai perbaikan yang berarti.

Keputusan tersebut membawa dua konsekuensi yang mengikat rancangan sistem:

1. **Interpolasi dijalankan secara rekursif pada titik tengah**, sebagaimana
   diuraikan pada subbab 3.6.4. Selama model belum dapat diandalkan pada
   posisi waktu sembarang, rekursi adalah satu-satunya cara memakainya di
   dalam zona yang dikuasainya. 2. **Asal-usul setiap frame dicatat dan
   disampaikan kepada peneliti.** Karena galat berlipat setiap kali sebuah
   batas merupakan keluaran model sendiri, yaitu 1,73 kali untuk satu batas
   dan 3,27 kali untuk dua sebagaimana diukur pada subbab 3.6.6, peneliti
   harus dapat membedakan frame bergenerasi satu dari yang lebih dalam. Angka
   mutu tanpa keterangan asal-usul akan menyesatkan.

Percobaan lanjutan beserta arah yang akan ditempuh diuraikan sebagai bagian
dari jadwal pada bab berikutnya: melanjutkan pelatihan melewati titik henti
sebelumnya, dan yang lebih menentukan, memperoleh barisan proyeksi yang lebih
panjang dari satu objek yang sama. Ambang lulus untuk percobaan berikutnya
ditetapkan sekarang agar tidak dapat disesuaikan belakangan: **rasio keragaman
pada objek yang tidak dilatihkan harus mencapai sekurang-kurangnya 0,6**, yang
pada uji Sample Contrast berarti jarak antar-hasil sekurang-kurangnya 107.

## 3.7 Rancangan Pengujian

Pengujian dilakukan pada tiga tingkat sebagaimana disajikan pada Tabel 3.20.

**Tabel 3. 20 Rancangan Skenario Pengujian**

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

**Tabel 3. 21 Format Penyajian Hasil Pengujian**

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

**Tabel 3. 22 Iterasi Prototyping dan Capaian Setiap Iterasi**

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

**Tabel 3. 23 Kebutuhan Perangkat Keras**

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

**Tabel 3. 24 Kebutuhan Perangkat Lunak**

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

# BAB IV
# IMPLEMENTASI DAN PENGUJIAN

## 4.1 Spesifikasi

Bab ini menguraikan wujud sistem yang telah dibangun beserta hasil
pengujiannya. Seluruh angka yang disajikan berasal dari pengukuran terhadap
sistem yang berjalan dan arsip proyeksi BRIN, bukan dari perkiraan.

### 4.1.1 Spesifikasi Perangkat Lunak

**Tabel 4. 1 Spesifikasi Perangkat Lunak yang Digunakan**

| Bagian | Perangkat Lunak | Peran |
|--------|-----------------|-------|
| Peladen aplikasi | PHP 8 dengan kerangka kerja Laravel 12 | Orkestrasi, autentikasi, dan antarmuka pemrograman aplikasi |
| Peladen proses | Laravel Octane di atas RoadRunner | Menjaga proses pekerja tetap hidup agar biaya penyalaan tidak dibayar berulang |
| Basis data | MySQL 8 | Metadata pekerjaan, pengguna, model, dan antrean |
| Antrean pekerjaan | Penggerak basis data dengan pekerja `queue:work` | Menjalankan interpolasi di luar daur permintaan HTTP |
| Aplikasi klien | Dart dengan kerangka kerja Flutter | Satu basis kode untuk peramban dan Android |
| Layanan inferensi | Python dengan FastAPI, TensorFlow/Keras, NumPy, Pillow | Memuat bobot dan membangkitkan frame antara |
| Terowongan | Terowongan HTTP berdomain tetap | Menghubungkan peladen lokal dengan layanan inferensi di awan |
| Sistem operasi pengembangan | Windows 11 | Lingkungan pengembangan dan pengujian |

### 4.1.2 Spesifikasi Perangkat Keras

Perangkat keras yang dipakai terbagi menjadi tiga tempat yang berbeda, dan
pembagian itu bukan pilihan gaya melainkan syarat yang dituntut persoalannya.

**Tabel 4. 2 Spesifikasi Perangkat Keras yang Digunakan**

| Tempat | Perangkat | Peran | Catatan terukur |
|--------|-----------|-------|-----------------|
| Lokal | Mesin peladen tanpa kartu grafis | Menjalankan API, basis data, antrean, dan penjadwal | Satu inferensi memakan ± 150 detik bila dipaksa berjalan di sini |
| Awan | Mesin berkartu grafis dengan sesi terbatas | Menjalankan layanan inferensi dan pelatihan | Satu inferensi memakan ± 18 detik |
| Lokal | Volume NAS | Menyimpan arsip proyeksi, hasil, dan arsip data latih | Sistem berhenti dengan pesan bila volume tidak terpasang |
| Klien | Telepon Android dan peramban desktop | Memakai sistem | Aplikasi Android dibangun dari basis kode yang sama |

Selisih delapan kali lipat antara 150 detik dan 18 detik itulah yang membuat
arsitektur *hybrid* dipertahankan. Sebuah celah selebar delapan langkah
menuntut tujuh panggilan inferensi, yang di mesin lokal berarti menunggu
sekitar tujuh belas menit untuk satu pekerjaan.

## 4.2 Implementasi Program

### 4.2.1 Implementasi Basis Data

Basis data terdiri atas 41 berkas migrasi yang membentuk 22 tabel di luar tabel
bawaan kerangka kerja. Tabel-tabel yang menopang alur utama disajikan berikut.

**Tabel 4. 3 Tabel Basis Data pada Alur Utama**

| Tabel | Isi |
|-------|-----|
| `users` | Akun peneliti dan administrator beserta perannya |
| `models` | Model terdaftar, alamat layanan inferensinya, dan keadaan ketersediaannya |
| `analysis_records` | Satu baris untuk setiap pekerjaan interpolasi beserta keadaan dan hasilnya |
| `training_datasets` | Arsip data latih yang diunggah peneliti beserta penanda pemakaian terakhirnya |
| `training_jobs` | Sesi pelatihan model beserta hiperparameter dan titik simpannya |
| `training_metrics` | Satu baris metrik untuk setiap epoch pelatihan |
| `training_samples` | Contoh keluaran model yang disimpan pada setiap epoch |
| `access_requests` | Permintaan akses yang menunggu persetujuan administrator |
| `user_activities` | Jejak aktivitas pengguna untuk keperluan penelusuran |
| `notifications` | Pemberitahuan yang ditujukan kepada pengguna tertentu |
| `conversations`, `messages` | Percakapan antara peneliti dan administrator |
| `news_posts` | Pengumuman yang tampil pada halaman muka |

### 4.2.2 Implementasi Antarmuka Pemrograman Aplikasi

Antarmuka pemrograman aplikasi terwujud dalam **104 rute** yang tersebar pada
17 kelas pengendali. Jumlah tersebut dihitung langsung dari daftar rute yang
dimuat peladen, bukan dari jumlah berkas.

**Tabel 4. 4 Pengelompokan Antarmuka Pemrograman Aplikasi**

| Kelompok | Kelas pengendali | Kegunaan |
|----------|------------------|----------|
| Autentikasi dan akun | `AuthController`, `MeController`, `AvatarController` | Masuk, keluar, penggantian sandi, dan berkas profil |
| Pekerjaan interpolasi | `PredictionUploadController`, `AnalysisController` | Unggah berpotongan, pembuatan pekerjaan, keadaan, frame, dan unduhan hasil |
| Pelatihan model | `MeTrainingController`, `TrainingController`, `TrainingWorkerController` | Pengunggahan data latih, pemulaian sesi, kemajuan per epoch, dan penerimaan titik simpan dari pekerja |
| Pengelolaan model | `ModelController` | Pendaftaran model, alamat layanan, dan pemeriksaan ketersediaan |
| Administrasi | `UserController`, `AccessRequestController`, `AdminQueueController`, `StorageController` | Pengelolaan pengguna, persetujuan akses, pemantauan antrean, dan keadaan penyimpanan |
| Komunikasi | `MessageController`, `NotificationController`, `NewsController` | Percakapan, pemberitahuan, dan pengumuman |
| Penelusuran | `UserActivityController` | Riwayat aktivitas pengguna |

### 4.2.3 Implementasi Antrean dan Penjadwal

Interpolasi tidak dijalankan di dalam daur permintaan HTTP karena satu
pekerjaan berumur menit. Permintaan hanya menitipkan pekerjaan ke antrean, lalu
pekerja latar mengambilnya.

Dua kelas pekerjaan diimplementasikan, yaitu `ProcessDeepLearningImage` yang
menjalankan interpolasi rekursif dan `CaptureResultEvidence` yang merekam bukti
hasil. Di sampingnya berjalan enam perintah terjadwal.

**Tabel 4. 5 Perintah Terjadwal dan Kegunaannya**

| Perintah | Kegunaan |
|----------|----------|
| `models:health-check` | Memeriksa ketersediaan layanan inferensi dan menandai model luring |
| `predictions:cleanup` | Menghapus berkas hasil yang telah melewati masa simpan 24 jam |
| `training:cleanup` | Menghapus arsip data latih yang tidak dipakai selama 30 hari |
| `training:dispatch-queued` | Mengirimkan sesi pelatihan yang menunggu ke pekerja |
| `training:reclaim` | Mengembalikan sesi pelatihan yang pekerjanya berhenti tanpa kabar |
| `tokens:cleanup` | Menyapu token yang telah kedaluwarsa |

### 4.2.4 Implementasi Layanan Inferensi

Layanan inferensi berjalan terpisah dari peladen aplikasi, berbentuk aplikasi
FastAPI yang memuat berkas bobot ke memori kartu grafis pada saat mulai.
Peladen memanggilnya sebagai *multipart* dengan dua frame batas dan satu skalar
waktu, lalu menerima satu frame TIFF sebagai balasan.

Satu hal yang menuntut penanganan khusus adalah kegagalan yang tertangani.
Layanan mengembalikan JSON berisi kunci galat dengan kode status HTTP 200,
sehingga kode status saja tidak dapat dipakai untuk menyimpulkan keberhasilan.
Peladen karena itu memeriksa isi balasan, bukan kode statusnya.

Ketersediaan layanan diperlakukan sebagai sesuatu yang tidak dijamin. Sesi
komputasi awan berakhir dengan sendirinya, dan ketika itu terjadi model
ditandai luring beserta sebabnya, sementara pekerjaan baru tidak diterima
sampai layanan kembali.

### 4.2.5 Implementasi Antarmuka Pengguna

Antarmuka terwujud dalam 23 layar yang dibangun dari satu basis kode Flutter
dan dikompilasi menjadi aplikasi peramban serta aplikasi Android.

**Tabel 4. 6 Layar Utama pada Aplikasi Klien**

| Kelompok | Layar | Kegunaan |
|----------|-------|----------|
| Umum | Halaman muka, Masuk, Gerbang sandi | Pengumuman, autentikasi, dan penggantian sandi bawaan sebelum konsol dapat dibuka |
| Peneliti | Beranda, Unggah, Galeri frame, Riwayat prediksi, Pelatihan, Aktivitas | Menjalankan dan memantau pekerjaan interpolasi serta sesi pelatihan |
| Administrator | Dasbor, Pengelolaan pengguna, Permintaan akses, Pemantauan antrean, Pengelolaan model, Pengelolaan pengumuman, Catatan aktivitas | Mengelola sistem dan memantau seluruh antrean |
| Percakapan | Kotak masuk, Percakapan, Utas pesan | Komunikasi antara peneliti dan administrator |

**[GAMBAR 4. 1 — Halaman Masuk Aplikasi]**
*Tangkapan layar halaman masuk pada peramban, memperlihatkan bidang surel dan
kata sandi serta tautan permintaan akses.*

**[GAMBAR 4. 2 — Beranda Peneliti]**
*Tangkapan layar beranda peneliti, memperlihatkan ringkasan pekerjaan terakhir,
keadaan ketersediaan model, dan pintasan menuju unggah.*

**[GAMBAR 4. 3 — Halaman Unggah dan Pratinjau Frame]**
*Tangkapan layar halaman unggah, memperlihatkan indikator kemajuan unggah
berpotongan, daftar frame yang terbaca beserta nomornya, dan penanda celah pada
barisan.*

**[GAMBAR 4. 4 — Galeri Frame dan Penanda Asal-Usul]**
*Tangkapan layar galeri frame hasil, memperlihatkan pembedaan antara frame
hasil pindai dan frame keluaran model beserta nilai generation setiap frame.*

**[GAMBAR 4. 5 — Riwayat Prediksi dan Posisi Antrean]**
*Tangkapan layar riwayat prediksi, memperlihatkan keadaan setiap pekerjaan,
posisinya dalam antrean, dan perkiraan waktu tunggu.*

**[GAMBAR 4. 6 — Halaman Pelatihan Model]**
*Tangkapan layar halaman pelatihan, memperlihatkan pengaturan hiperparameter,
daftar sesi berjalan, dan tabel metrik per epoch.*

**[GAMBAR 4. 7 — Dasbor Administrator]**
*Tangkapan layar dasbor administrator, memperlihatkan ringkasan pengguna,
pekerjaan, keadaan penyimpanan, dan aktivitas terakhir.*

**[GAMBAR 4. 8 — Pemantauan Antrean Seluruh Pengguna]**
*Tangkapan layar pemantauan antrean, memperlihatkan daftar pekerjaan menunggu
beserta keadaan pekerja antrean.*

**[GAMBAR 4. 9 — Pengelolaan Model dan Alamat Layanan]**
*Tangkapan layar pengelolaan model, memperlihatkan daftar model terdaftar,
alamat layanan inferensinya, dan penanda ketersediaan.*

**[GAMBAR 4. 10 — Aplikasi pada Perangkat Android]**
*Tangkapan layar aplikasi Android pada telepon genggam, memperlihatkan layar
yang sama dengan versi peramban dari basis kode yang sama.*

### 4.2.6 Implementasi Pratinjau Frame Berkedalaman 16 Bit

Peramban tidak dapat menampilkan TIFF 16 bit secara langsung, sehingga frame
harus diterjemahkan lebih dahulu menjadi PNG. Penerjemahan itu dikerjakan
langsung dari byte berkas karena peladen tidak memiliki ekstensi pengolah citra
bawaan.

Implementasi pertama memperlakukan piksel sebagai larik sebesar jumlah piksel,
dan itu menjadi persoalan yang nyata. Satu frame 2048 × 2048 menuntut sekitar
196 MB, sementara `FrameMetrics` menahan dua frame sekaligus. Pekerja antrean
mati di tengah pekerjaan tanpa meninggalkan keterangan, dan layar peneliti
tetap menampilkan keadaan menunggu.

Implementasi diperbaiki dengan memperlakukan piksel sebagai untai biner yang
dibuka per blok. Hasil pengukurannya disajikan berikut.

**Tabel 4. 7 Kebutuhan Memori Pratinjau Sebelum dan Sesudah Perbaikan**

| Ukuran frame | Pendekatan larik | Pendekatan untai biner |
|--------------|-----------------:|-----------------------:|
| 2048 × 2048, satu frame | 196 MB | 11,7 MB |
| 2048 × 2048, dua frame | 262 MB | 20 MB |

Batas ukuran frame yang dapat diproses naik kembali dari 2048 × 2048 menjadi
4096 × 4096. Yang membatasi sekarang adalah waktu penerjemahan, bukan lagi
memori.

Dua keputusan lain menyertainya. Nilai piksel dipetakan ke rentang 0 sampai 255
berdasarkan nilai terkecil dan terbesar frame itu sendiri, bukan berdasarkan
rentang 16 bit penuh, karena frame proyeksi neutron hanya menempati sebagian
kecil rentang tersebut. Penyusutan ukuran dikerjakan dengan merata-ratakan blok
piksel, bukan dengan membuang piksel, sebab pembuangan piksel membuat derau
pada citra neutron tampak seperti struktur.

### 4.2.7 Implementasi Interpolasi Rekursif dan Pencatatan Asal-Usul

Karena model tidak dapat diandalkan pada posisi waktu sembarang, pengisian
celah dijalankan secara rekursif pada titik tengah. Setiap frame yang
dihasilkan membawa nilai `generation` yang menyatakan seberapa jauh ia
dihasilkan dari frame hasil pindai.

Frame hasil pindai bernilai nol. Frame yang kedua batasnya merupakan hasil
pindai bernilai satu. Frame yang salah satu batasnya merupakan keluaran model
bernilai dua atau lebih, dan pada frame semacam itu galat model diumpankan
kembali sebagai masukan.

Nilai tersebut disertakan pada arsip hasil yang diterima peneliti bersama
manifes dan angka mutu. Tanpanya seluruh frame keluaran tampak setara, padahal
tingkat kepercayaannya berbeda.

## 4.3 Pengujian Sistem

### 4.3.1 Pengujian Black Box

Pengujian *black box* dilakukan terhadap alur yang dijalankan pengguna, tanpa
memandang isi kodenya. Hasilnya disajikan berikut.

**Tabel 4. 8 Hasil Pengujian Black Box**

| Kode | Skenario | Hasil yang diharapkan | Hasil |
|------|----------|-----------------------|-------|
| B-01 | Masuk dengan akun sah | Pengguna masuk ke konsol sesuai perannya | Sesuai |
| B-02 | Masuk dengan sandi bawaan | Pengguna dihadang gerbang sandi sampai menggantinya | Sesuai |
| B-03 | Unggah arsip `.zip` berisi frame bercelah | Frame terbaca, nomor terurut, celah terdeteksi | Sesuai |
| B-04 | Unggah berkas selain `.zip` | Ditolak dengan pesan yang menyebutkan sebabnya | Sesuai |
| B-05 | Unggah terputus lalu dilanjutkan | Unggahan dilanjutkan dari potongan terakhir, bukan dari awal | Sesuai |
| B-06 | Menjalankan pekerjaan interpolasi | Pekerjaan masuk antrean dengan posisinya, lalu menghasilkan arsip | Sesuai |
| B-07 | Melihat galeri frame hasil | Frame hasil pindai dan keluaran model dibedakan beserta nilai generation | Sesuai |
| B-08 | Mengunduh arsip hasil | Arsip berisi frame lengkap, manifes, dan angka mutu | Sesuai |
| B-09 | Layanan inferensi dimatikan | Model ditandai luring beserta sebabnya, pekerjaan baru tidak diterima | Sesuai |
| B-10 | Pekerja antrean dihentikan | Antarmuka menyatakan antrean tidak berjalan, bukan menampilkan keadaan menunggu biasa | Sesuai |
| B-11 | Volume NAS tidak terpasang | Sistem menolak bekerja dengan pesan yang menyebutkan sebabnya | Sesuai |
| B-12 | Memulai sesi pelatihan dari sisi peneliti | Sesi berjalan, metrik per epoch tercatat dan tampil | Sesuai |
| B-13 | Membuka pekerjaan yang berkasnya telah tersapu | Keterangan masa simpan tampil, bukan daftar kosong | Sesuai |
| B-14 | Memakai aplikasi Android | Alur yang sama berjalan dari basis kode yang sama | Sesuai |

### 4.3.2 Pengujian White Box

Pengujian *white box* dikerjakan melalui rangkaian uji otomatis yang membaca
kode dari dalam. Rangkaian ini dijalankan ulang setiap kali kode berubah,
sehingga kesalahan yang pernah diperbaiki tidak kembali tanpa diketahui.

**Tabel 4. 9 Hasil Pengujian Otomatis**

| Sasaran | Perintah | Hasil |
|---------|----------|-------|
| Sisi peladen | `php artisan test` | 368 uji lulus, 1.452 asersi |
| Analisa statis sisi klien | `flutter analyze` | Tanpa temuan (No issues found) |
| Sisi klien | `flutter test` | 269 uji lulus |

Dua di antara berkas uji tersebut berdiri untuk keperluan yang khusus.
`SourceEncodingTest` pada sisi peladen dan `source_encoding_test` pada sisi
klien memindai berkas sumber untuk mencari pola *mojibake*, yaitu kerusakan
UTF-8 yang menyebar melalui penyuntingan biasa dan tidak terlihat pada
peninjauan kode maupun pada rangkaian uji lain. Keduanya dipasang setelah
kerusakan semacam itu ditemukan pada delapan berkas, lima di antaranya berupa
teks yang dibaca pengguna.

Satu catatan mengenai uji memori pratinjau. Uji tersebut mula-mula lulus
terhadap implementasi yang sengaja dibuat salah, karena penyiapan datanya
sendiri sudah mengalokasikan memori besar sehingga selisihnya tenggelam.
Setelah penyiapan diperbaiki agar menulis berkas contoh sepotong demi sepotong,
implementasi yang salah menaikkan pemakaian memori sebesar 167 MB dan uji itu
gagal sebagaimana seharusnya.

### 4.3.3 Pengujian Mutu Keluaran Model

Mutu keluaran model tidak dapat diuji dengan cara yang sama, sebab frame yang
ingin diisi peneliti menurut definisinya tidak memiliki pembanding. Pengujian
karena itu memakai skema *hold-out*: sebuah frame yang merupakan titik tengah
tepat dari dua frame yang ada disembunyikan dari model, dibangkitkan kembali,
lalu dibandingkan terhadap frame asli yang disembunyikan itu.

**Tabel 4. 10 Hasil Validasi Hold-Out terhadap Tiga Pekerjaan Nyata**

| Besaran | Nilai | Keterangan |
|---------|------:|------------|
| MAE | 359,747 | Dalam satuan 16 bit mentah |
| RMSE | 688,092 | Dalam satuan 16 bit mentah |
| PSNR | 39,58 dB | Terhadap frame acuan |
| Rentang frame acuan | 108 – 56.487 | Galat setara sekitar 0,6% dari rentang |
| Waktu tiap pekerjaan | 47, 42, dan 54 detik | Dua frame dihasilkan dari tiga frame masukan |

Angka MAE dan PSNR saja tidak cukup untuk menyimpulkan mutu pada persoalan ini,
dan hal tersebut merupakan salah satu temuan penting penelitian. Keluaran model
dibandingkan terhadap pencampuran linier, yaitu rata-rata berbobot kedua frame
batas, pada lima kasus lintas tiga sampel berbeda.

**Tabel 4. 11 Model terhadap Pencampuran Linier pada Tiga Metrik**

| Metrik | Model unggul | Keterangan |
|--------|-------------:|------------|
| MAE | 1 dari 5 | Rata-rata dua citra meminimalkan galat kuadrat |
| PSNR | 0 dari 5 | Sifatnya sama dengan MAE |
| **SSIM** | **5 dari 5** | Membandingkan luminans, kontras, dan struktur secara lokal |

Pencampuran linier unggul pada MAE dan PSNR karena rata-rata adalah tebakan
yang meminimalkan galat kuadrat, dengan harga berupa citra yang kabur. Pada
SSIM model unggul pada seluruh kasus, dan keunggulannya melebar pada kasus yang
lebih sulit, yaitu dari 0,0002 pada sampel berjarak dua derajat menjadi 0,0064
dan 0,0091 pada Al Cu berjarak tiga derajat serta Contrast dengan rentang enam
frame. Frame proyeksi yang kabur merusak rekonstruksi, sehingga MAE dan PSNR
tidak dipakai sendirian sebagai ukuran keberhasilan.

Pengujian terhadap bobot dasar juga menyingkap empat batas perilaku yang
diuraikan pada subbab 3.6.6, dan percobaan penyempurnaan yang dilaporkan pada
subbab 3.6.8 belum memenuhi ambang yang ditetapkan sebelum percobaan dimulai
sehingga bobotnya tidak dipasang.

### 4.3.4 User Response (Kuesioner)

Metode Prototyping menuntut setiap iterasi diserahkan kepada pengguna untuk
dicoba, dan umpan balik yang diperoleh menjadi masukan bagi iterasi berikutnya.
Sepanjang pembangunan sistem ini, umpan balik tersebut diperoleh melalui
percobaan langsung bersama pihak BRIN Puspiptek dan diterjemahkan menjadi
perubahan pada iterasi berikutnya.

**Tabel 4. 12 Instrumen Kuesioner Tanggapan Pengguna**

| Kode | Pernyataan | Aspek |
|------|------------|-------|
| K-01 | Proses pengunggahan arsip proyeksi mudah dilakukan | Kegunaan |
| K-02 | Keadaan setiap pekerjaan mudah diketahui tanpa bertanya | Keterbacaan status |
| K-03 | Pembedaan frame hasil pindai dan frame keluaran model jelas | Kejelasan asal-usul |
| K-04 | Angka mutu yang disertakan membantu menilai hasil | Pertanggungjawaban hasil |
| K-05 | Pesan kesalahan menyebutkan sebab yang dapat dimengerti | Kejujuran pesan |
| K-06 | Aplikasi pada telepon genggam sama mudahnya dengan peramban | Kesetaraan antarperon |
| K-07 | Sistem ini mempercepat penanganan celah dibanding cara sebelumnya | Manfaat |

**Tabulasi tanggapan belum dikumpulkan pada saat naskah ini disusun.**
Instrumen di atas telah disusun beserta aspek yang diukurnya, tetapi
penyebarannya kepada responden di lingkungan BRIN Puspiptek belum dilaksanakan,
sehingga hasilnya tidak dilaporkan di sini. Menyajikan angka tanggapan tanpa
pengumpulan yang benar-benar dilakukan akan menyesatkan pembaca, dan hal itu
sengaja dihindari.

# BAB V
# PENUTUP

## 5.1 Kesimpulan

Penelitian ini merancang dan membangun sistem multiplatform terintegrasi
berbasis arsitektur *hybrid cloud-NAS* untuk mengisi celah pada barisan
proyeksi tomografi komputer neutron di BRIN Puspiptek. Berdasarkan implementasi
dan pengujian yang telah dilakukan, diperoleh kesimpulan berikut.

Pertama, sistem yang dibangun berhasil menjalankan pengisian celah secara
otomatis sekaligus menjaga arsip penelitian tetap berada di dalam institusi.
Wujudnya berupa 104 rute antarmuka pemrograman aplikasi pada 17 kelas
pengendali, 22 tabel basis data, antrean pekerjaan dengan dua kelas pekerjaan
latar dan enam perintah terjadwal, serta 23 layar aplikasi klien yang
dikompilasi dari satu basis kode menjadi aplikasi peramban dan aplikasi
Android. Seluruh berkas penelitian menetap pada perangkat lokal dan volume NAS,
sementara yang menyeberang ke lingkungan awan hanya dua frame batas dan satu
skalar waktu pada setiap panggilan.

Kedua, penerapan algoritma Spatio-Temporal U-Net pada persoalan ini berhasil
menghasilkan frame antara, tetapi perilakunya terhadap arsip yang sebenarnya
ikut menentukan bagaimana sistem harus dirancang. Model tersebut dirancang
untuk menyisipkan satu frame pada titik tengah di antara dua frame pindai, dan
hanya dilatih pada posisi itu; pengukuran menunjukkan tanggapannya terhadap
skalar waktu di luar titik tengah hanya 0,17% dari yang seharusnya, sehingga
pengisian celah yang lebih lebar harus dijalankan secara rekursif, dan galatnya berlipat 1,73 kali setiap kali sebuah batas merupakan
keluaran model sendiri. Akibatnya hanya frame yang kedua batasnya merupakan
hasil pindai yang layak dipercaya. Percobaan penyempurnaan bobot berhasil
menaikkan tanggapan tersebut menjadi 27,87% tanpa mengubah satu lapisan pun,
yang membuktikan mekanismenya dapat diajarkan melalui distribusi data
pelatihan, tetapi rasio keragaman keluarannya baru mencapai 0,210 sehingga
bobot itu tidak dipasang.

Ketiga, mutu setiap frame dapat diukur dan dipertanggungjawabkan melalui
validasi *hold-out* yang menghasilkan MAE 359,747, RMSE 688,092, dan PSNR
39,58 dB, atau sekitar 0,6% dari rentang citra acuan. Pengukuran tersebut juga
menunjukkan bahwa MAE dan PSNR menyesatkan bila dipakai sendirian: pencampuran
linier mengungguli model pada kedua metrik itu, sementara pada SSIM model
unggul pada seluruh lima kasus dengan keunggulan yang melebar pada kasus yang
lebih sulit. Pencatatan asal-usul frame melalui nilai `generation` melengkapi
angka tersebut, sehingga peneliti yang menerima hasil dapat menilai sendiri
tingkat kepercayaan setiap frame.

## 5.2 Saran

Beberapa hal masih terbuka untuk dikerjakan pada penelitian lanjutan.

Pertama, penyempurnaan bobot model perlu dilanjutkan. Kurva pelatihan pada
percobaan yang dilaporkan masih menurun pada 76% laju awal ketika pelatihan
dihentikan, yang berarti kurvanya belum mendatar. Dua arah yang paling layak
ditempuh, berurutan menurut biayanya, adalah melanjutkan pelatihan melewati
epoch kedua puluh dan memperoleh barisan proyeksi yang lebih panjang dari satu
objek yang sama. Sepuluh frame yang menghasilkan 112 contoh berhadapan dengan
21.921.601 parameter merupakan perbandingan yang membuat penghafalan jauh lebih
mudah daripada penyimpulan.

Kedua, ambang kelayakan sebaiknya disampaikan lebih tegas pada antarmuka.
Sistem saat ini telah mencatat dan menyampaikan nilai `generation` setiap
frame, tetapi belum menyatakan secara eksplisit bahwa frame bergenerasi dua ke
atas berada di bawah ambang kelayakan yang terukur.

Ketiga, tanggapan pengguna perlu dikumpulkan dan ditabulasikan dengan
instrumen yang telah disusun pada subbab 4.3.4, sehingga penilaian terhadap
kegunaan sistem tidak hanya bertumpu pada percobaan langsung yang tidak
terekam angkanya.

Keempat, ketergantungan pada sesi komputasi awan yang dapat berakhir
sewaktu-waktu masih menjadi kelemahan yang melekat. Apabila di kemudian hari
institusi memiliki kartu grafis sendiri, seluruh layanan inferensi dapat
dipindahkan ke dalam institusi tanpa mengubah rancangan sistemnya, sebab
antarmuka antara peladen dan layanan inferensi telah dipisahkan sejak awal.

Kelima, penelitian ini berhenti pada barisan proyeksi yang telah lengkap.
Pengaruh frame hasil interpolasi terhadap mutu rekonstruksi volumetrik belum
diukur, dan pengukuran tersebut merupakan kelanjutan yang paling langsung dari
pekerjaan ini.

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
