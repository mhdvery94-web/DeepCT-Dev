# Bagian A — Bersih-bersih UI

**Tanggal:** 22 Agustus 2026
**Status:** rancangan disetujui, belum dikerjakan

Bagian pertama dari empat, memecah sepuluh permintaan perubahan yang diajukan
22 Agustus 2026. Tiga bagian sisanya diringkas di bawah, di bagian
[Yang bukan bagian A](#yang-bukan-bagian-a).

Bagian A dipilih lebih dulu karena ia satu-satunya yang bisa diverifikasi
sepenuhnya dari mesin ini: tidak ada paket Flutter baru, tidak ada worker jarak
jauh yang harus hidup, dan hanya satu kolom database yang bertambah.

## Empat perubahan

### A1. Teks bisa disalin

**Keluhan:** teks di aplikasi tidak bisa ditekan untuk disalin.

`SelectableText` sudah dipakai di tiga tempat — `access_requests_screen.dart:390`,
`activity_logs_screen.dart:500`, `user_management_screen.dart:183` — semuanya
untuk nilai yang memang harus disalin, seperti kata sandi hasil reset. Pola itu
sudah ada; yang belum adalah keberlakuannya di seluruh aplikasi.

Menyalin pola itu ke setiap `Text` berarti menyentuh puluhan berkas, dan
hasilnya lebih buruk daripada kelihatannya: seleksi `SelectableText` berhenti di
batas widget-nya sendiri, jadi menyapu satu blok yang melintasi beberapa baris
tidak bisa dilakukan.

**Yang dipakai:** `SelectionArea`, satu widget yang membuat seluruh `Text`
keturunannya bisa diseleksi tanpa mengubah satu pun di antaranya, dan seleksinya
menyambung melintasi widget.

Ditempatkan di empat titik:

| Berkas | Alasan |
|---|---|
| `fe/lib/screens/user/user_shell.dart` | badan seluruh area periset |
| `fe/lib/screens/admin/admin_shell.dart` | badan seluruh area admin |
| `fe/lib/screens/landing/landing_page.dart` | halaman publik, di luar kedua shell |
| `fe/lib/widgets/app_dialog.dart` | **tidak tercakup shell** — `showDialog` membuat route sendiri di overlay |

Titik keempat itu yang paling mudah terlewat. `AppDialog` tidak berada di bawah
pohon widget shell, jadi `SelectionArea` di shell tidak menjangkaunya.

Tiga `SelectableText` yang sudah ada **dibiarkan**. Keduanya bisa hidup
berdampingan, dan mencabutnya hanya menambah risiko tanpa menambah apa pun.

**Yang sudah diperiksa:** tidak ada satu pun `onLongPress` di `fe/lib`, jadi
gestur tekan-lama yang dipakai `SelectionArea` di ponsel tidak akan merebut
gestur milik widget lain.

### A2. Recent activity punya area scroll sendiri

**Keluhan:** daftar aktivitas terbaru di dasbor admin maupun periset sebaiknya
bisa digulung sendiri.

`user_home_screen.dart:206` dan `dashboard_home_screen.dart:235` keduanya:

```dart
ListView.separated(
  shrinkWrap: true,
  physics: const NeverScrollableScrollPhysics(),
  ...
)
```

Artinya daftar itu membentang setinggi seluruh isinya dan ikut menggulung
bersama halaman. Sepuluh baris aktivitas mendorong segala yang ada di bawahnya
jauh keluar layar, dan tidak ada cara melihat aktivitas tanpa menggulung
melewati seluruh kartu statistik lebih dulu.

**Yang dipakai:** `ConstrainedBox(maxHeight: 320)` membungkus `ListView`, dengan
**`shrinkWrap: true` dipertahankan** dan hanya `NeverScrollableScrollPhysics`
yang dibuang:

```dart
ConstrainedBox(
  constraints: const BoxConstraints(maxHeight: 320),
  child: ListView.separated(
    shrinkWrap: true,   // dipertahankan, lihat catatan di bawah
    // physics dibuang → kembali ke default yang bisa digulung
    ...
  ),
)
```

Kombinasinya penting dan mudah salah. Membuang `shrinkWrap` bersama `physics`
akan membuat `ListView` mengisi **seluruh** 320px sekalipun isinya cuma dua
baris, karena `ListView` yang diberi batas tinggi akan memuainya sampai penuh.
Dengan `shrinkWrap: true` yang tetap ada, daftar menyusut mengikuti isinya
selama masih di bawah 320px, dan baru menggulung setelah melewatinya. Yang
membuatnya bisa digulung sekarang adalah dibuangnya
`NeverScrollableScrollPhysics`, bukan dibuangnya `shrinkWrap`.

320px kira-kira empat baris pada kerapatan sekarang — cukup untuk terlihat
sebagai daftar, cukup pendek agar halaman tetap satu layar di ponsel.

Keadaan kosong (`EmptyView`) tidak berubah.

### A3. Status model punya tiga keadaan, bukan dua

**Keluhan:** bar model berwarna merah padahal model online, jadi rancu.

Akarnya bukan pilihan warna melainkan `be/app/Http/Controllers/API/MeController.php:84`:

```php
'is_available' => $m->status === 'online',
```

`ModelHealthChecker` memasang tiga status, bukan dua. Yang ketiga, `trouble`,
dipasang di baris 194–200 ketika worker **menjawab tapi lebih lambat dari
`SLOW_THRESHOLD_MS` (5000 ms)**. Worker itu hidup dan bisa dipakai. Tetapi
karena `is_available` menuntut `status === 'online'` persis, ia dilaporkan tidak
tersedia, lalu:

- `fe/lib/widgets/model_status_strip.dart:133` menampilkannya merah dengan judul
  "Model offline"
- `fe/lib/screens/user/upload_screen.dart:488` **menonaktifkan pilihannya** —
  `onTap: model.isAvailable ? ... : null`

Jadi worker GPU yang lambat menjawab tampak mati dan tidak bisa dipilih sama
sekali. Untuk Kaggle di balik ngrok, lambat adalah keadaan normal, bukan
pengecualian — inilah yang membuat bar terlihat merah padahal modelnya jalan.

**Yang dipakai:** `trouble` diperlakukan sebagai tersedia.

| status | `is_available` | warna | bisa dipilih |
|---|---|---|---|
| `online` | `true` | hijau (`AppTheme.success`) | ya |
| `trouble` | `true` | kuning (`AppTheme.warning`) | ya |
| `offline` | `false` | merah (`AppTheme.error`) | tidak |

`MeController::models()` menjadi `in_array($m->status, ['online', 'trouble'], true)`.

`model_status_strip.dart` memilih warna dari status terbaik yang ada, bukan dari
`isAvailable` yang biner: hijau bila ada model `online`, kuning bila yang
tersedia hanya `trouble`, merah bila tidak ada yang tersedia.

**Satu efek samping yang harus ikut diperbaiki.** `MeController.php:69` memakai
`orderByDesc('status')` dengan komentar *"online sorts before offline"* — itu
bekerja secara kebetulan karena urutan abjad terbalik menempatkan `online` di
atas `offline`. Begitu `trouble` ikut dianggap tersedia, abjad terbalik
menempatkannya di **paling atas**, sehingga model lambat terpilih sebagai
default alih-alih model yang sehat. Urutannya diganti menjadi eksplisit:
`online`, lalu `trouble`, lalu `offline`.

### A4. Bahasa kegagalan dipisah menurut pembacanya

**Keluhan:** ganti `"Tunnel is not running"` dengan keterangan yang bisa
dipahami; tampilkan error dengan bahasa yang mudah dimengerti.

Antarmuka aplikasi ini seluruhnya berbahasa Inggris dan **tetap begitu**,
termasuk pesan kegagalannya. Yang diperbaiki adalah jargonnya, bukan bahasanya.

Niat teks yang sekarang benar, dan `fe/test/model_status_test.dart:53`
menuliskannya:

> "Tunnel is not running" tells a researcher to restart the Kaggle session.
> "Offline" alone does not.

Periset memang perlu tahu **apa yang harus dilakukan**. Tetapi "tunnel" dan
"ERR_NGROK_3200" tidak memberi tahu seorang periset apa pun — dan periset juga
bukan orang yang menyalakan ulang sesi Kaggle. Yang bisa melakukannya adalah
admin.

Maka pesan dipisah menurut siapa yang membacanya.

#### Kode alasan

`ModelHealthChecker` menyimpan kode alasan berdampingan dengan detail mentah
yang sudah ada. Kolom baru `health_check_reason` di tabel `models`, `string(20)`,
nullable. `health_check_error` **tidak berubah** — ia tetap menyimpan kalimat
diagnostik apa adanya.

Seluruh cabang kegagalan yang ada sekarang dipetakan:

| `ModelHealthChecker` | status | `health_check_error` (tetap) | `health_check_reason` (baru) |
|---|---|---|---|
| `:54`, `:98` | `offline` | `Endpoint URL is not set` | `no_endpoint` |
| `:72`, `:132` | `offline` | pesan pengecualian | `unreachable` |
| `:140` | `offline` | `No response from the probe` | `unreachable` |
| `:175` | `offline` | `Tunnel is not running (ERR_NGROK_3200)` | `tunnel_down` |
| `:186` | `offline` | `Endpoint unreachable (HTTP 502)` | `unreachable` |
| `:195` | `trouble` | `Slow response: 7213ms` | `slow` |
| `:203` | `online` | `null` | `null` |

`no_endpoint` sengaja dipisahkan dari `unreachable`: model tanpa alamat bukan
server yang mati, melainkan pendaftaran yang belum selesai. Menyuruh orang
"menyalakan ulang" sesuatu yang belum pernah dikonfigurasi adalah saran yang
salah.

#### Teks yang dilihat periset

Klien memetakan kode ke kalimat. Pemetaan tinggal di satu tempat,
`fe/lib/models/model_info.dart`, sebagai getter di samping `isOnline` /
`isTrouble` / `isOffline` yang sudah ada di baris 87–89, sehingga
`model_status_strip` dan `upload_screen` memakai kalimat yang sama.

| kode | teks untuk periset |
|---|---|
| `tunnel_down` | `The model server is disconnected. Ask an administrator to bring it back.` |
| `unreachable` | `The model server is not responding. Ask an administrator to bring it back.` |
| `no_endpoint` | `This model has no server address yet. Ask an administrator to finish setting it up.` |
| `slow` | `The model server is answering slowly. Your job may take longer than usual.` |
| kode tidak dikenal / `null` | `The model server is not responding. Ask an administrator to bring it back.` |

Baris terakhir itu bukan basa-basi. Baris rusak dari sebelum migrasi akan punya
`health_check_reason` bernilai `null` sementara statusnya `offline`, dan tampilan
harus tetap masuk akal sampai pemeriksaan kesehatan berikutnya mengisinya —
yang terjadi paling lama satu menit kemudian, karena penjadwal memeriksa tiap
menit.

#### Teks yang dilihat admin

`fe/lib/screens/admin/model_management_screen.dart:404-412` sekarang menampilkan
`health_check_error` mentah. Ia menjadi **dua baris**: kalimat ramah yang sama
seperti di atas, dengan diagnostik mentah di bawahnya dengan gaya yang lebih
kecil dan redup.

Admin tetap melihat `ERR_NGROK_3200` dan `HTTP 502` karena dialah yang
menyalakan ulang sesi Kaggle — membuang kode itu justru menghapus satu-satunya
petunjuk yang berguna.

`be/app/Services/Notifier.php:196` **tidak berubah**. Ia mengirim ke
`self::admins()`, jadi diagnostik mentah di sana sudah tepat sasaran.

## Perubahan skema

Satu migrasi, satu kolom:

```php
Schema::table('models', function (Blueprint $table) {
    $table->string('health_check_reason', 20)->nullable()->after('health_check_error');
});
```

Tanpa backfill. Baris yang ada akan bernilai `null` sampai pemeriksaan kesehatan
berikutnya menulisinya, dan tampilan sudah menangani `null` (lihat baris
terakhir tabel teks periset di atas). `down()` menjatuhkan kolomnya.

## Cara menguji

**Backend** — `cd be && php artisan test`, butuh basis data `db_aict_test`.

Yang baru dan diubah:

- `ModelHealthChecker` menulis `health_check_reason` yang benar untuk ketujuh
  cabang di tabel A4. Ini test baru; yang ada sekarang hanya memeriksa `status`
  dan `health_check_error`.
- `MeController::models()` melaporkan `is_available: true` untuk model
  `trouble`. Ini **membalik** harapan test yang ada — cari yang menegaskan
  sebaliknya dan tulis ulang, jangan tambahkan test baru di sampingnya.
- `MeController::models()` mengurutkan `online` sebelum `trouble` sebelum
  `offline`.

**Frontend** — `cd fe && flutter analyze` harus bersih, lalu `flutter test`.

- `fe/test/model_status_test.dart` **ditulis ulang**. Test di baris 50–70 sekarang
  menegaskan `ERR_NGROK_3200` tampil kepada periset; itu justru yang dibuang.
  Penggantinya menegaskan periset mendapat kalimat yang bisa ditindaklanjuti,
  dan bahwa model `trouble` tampil kuning serta tetap bisa dipilih.
- Test baru untuk pemetaan kode→kalimat di `model_info.dart`, termasuk jalur
  `null`.
- Test tata letak untuk A2, **dua kasus**, karena kesalahan yang mungkin
  terjadi berbeda arah: daftar dua puluh baris tidak boleh membuat dasbor
  melampaui tinggi yang diberikan kepadanya, dan daftar dua baris tidak boleh
  menyisakan ruang kosong sampai 320px. Kasus kedua itu yang menangkap
  `shrinkWrap` bila ia terbuang tanpa sengaja.

**Yang tidak bisa dijangkau test** — `flutter build apk --release`, lalu coba
langsung di APK: tekan-lama sebuah teks dan salin, dan gulung daftar aktivitas.
Perilaku seleksi di ponsel tidak terlihat dari test widget, dan inilah keluhan
yang memulai bagian A.

## Risiko

**`SelectionArea` di seluruh shell adalah perubahan yang luas.** Ia tidak
mengubah satu berkas layar pun, tapi ia mengubah cara setiap gestur di bawahnya
ditafsirkan. Tidak adanya `onLongPress` di mana pun membuat risikonya kecil,
tapi kecil bukan nol — inilah alasan uji APK di atas bukan pelengkap melainkan
syarat.

**A3 mengubah perilaku, bukan hanya tampilan.** Model `trouble` yang tadinya
tertolak kini bisa menerima pekerjaan. Itu memang yang diminta, dan model itu
memang hidup, tapi konsekuensinya nyata: pekerjaan yang dikirim ke worker lambat
akan lebih lama selesai. Kalimat `slow` di A4 ada justru untuk mengatakannya
sebelum orang menekan tombolnya.

## Yang bukan bagian A

Ditulis di sini supaya tidak ada yang mengira bagian A menutup sepuluh poin itu.

| Bagian | Isi |
|---|---|
| **B — Skema** | `username` diganti nomor telepon (opsional, tidak unik); unggah video di News; `max_concurrent_jobs` dihapus; status *pending* pada pesan |
| **C — Viewer** | penelusur tumpukan frame ala ImageJ, dipakai di layar unggah dan di hasil/riwayat, menggabungkan frame input dan hasil dengan penanda; unggah beberapa `.tif` sekaligus yang dibungkus ZIP di klien |
| **D — Training** | tab Training sisi admin dihapus; tab Training sisi periset dikembangkan dengan unggah, viewer dari C, dan metrik PSNR/SSIM/MAE/MSE |

Urutannya B → C → D. B lebih dulu karena migrasinya menyentuh banyak test dan
lebih baik mendarat saat pohon test masih stabil; C sebelum D karena D memakai
widget yang lahir di C.

Dua hal yang sudah diketahui akan bersinggungan:

- `model_management_screen.dart:392` menampilkan
  `'${model.currentJobsCount} / ${model.maxConcurrentJobs}'`. Bagian A menyentuh
  layar yang sama untuk A4; bagian B yang akan mencabut penyebutnya.
- Bagian D dibangun di atas jalur yang **belum pernah dijalankan sekali pun**
  terhadap GPU sungguhan (lihat ROADMAP.md §10). Sesuai kesepakatan, antarmukanya
  tetap dibangun tetapi ditandai belum terverifikasi di README dan ROADMAP —
  aturan 4 CLAUDE.md.
