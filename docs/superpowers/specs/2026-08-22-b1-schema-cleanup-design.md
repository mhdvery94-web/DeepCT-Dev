# Bagian B1 — Pembersihan skema

**Tanggal:** 22 Agustus 2026
**Status:** rancangan disetujui, belum dikerjakan

Bagian kedua dari sepuluh permintaan perubahan yang diajukan 22 Agustus 2026.
Bagian A (bersih-bersih UI) sudah mendarat di `main`. Lihat ROADMAP.md §12 untuk
seluruh pemecahannya.

Bagian B awalnya memuat empat hal; ia dipecah lagi jadi dua karena dua di
antaranya adalah penghapusan kolom yang **lebar tapi dangkal**, sementara dua
sisanya adalah fitur yang **sempit tapi dalam**. Menggabungkannya menghasilkan
satu rangkaian commit yang tidak bisa dibatalkan sebagian.

- **B1, dokumen ini:** `username` diganti nomor telepon, `max_concurrent_jobs`
  dihapus.
- **B2, menyusul:** unggah video di News, emoji dan status *pending* di Messages.

## B1.1 — `username` diganti `phone`

### Alasannya

Login memakai email, dan setiap akun sudah punya `name`. `username` adalah
kolom ketiga yang tidak mengidentifikasi apa pun yang belum teridentifikasi —
tetapi ia `NOT NULL` dan `unique`, jadi setiap pembuatan akun harus mengarang
satu. `AccessRequestController` bahkan punya dua metode yang tugasnya hanya itu.

Yang menggantikannya adalah nomor telepon: opsional, tidak unik. Ia menjawab
pertanyaan yang benar-benar muncul ("bagaimana saya menghubungi periset ini")
dan tidak menghalangi apa pun saat kosong.

### Perubahan skema

Satu migrasi, dua operasi:

```php
Schema::table('users', function (Blueprint $table) {
    $table->string('phone', 30)->nullable()->after('email');
    $table->dropUnique(['username']);
    $table->dropColumn('username');
});
```

`dropUnique` sebelum `dropColumn` disebut eksplisit karena MySQL menolak
menjatuhkan kolom yang masih menyangga indeks unik.

**Tidak ada backfill, dan tidak ada penyelamatan data.** Nilai `username` yang
ada hilang. Itu memang yang diminta, tetapi harus dikatakan terang-terangan:
`down()` bisa mengembalikan kolomnya, tidak bisa mengembalikan isinya. Ia
mengisi ulang dengan `user{id}` supaya batasan `unique` tetap terpenuhi, dan
rollback karenanya bersifat merusak.

`phone` bertipe `string(30)`, cukup untuk nomor internasional berikut spasi dan
tanda hubung. Tidak ada validasi format: nomor Indonesia ditulis dengan
`+62`, `62`, dan `0` semuanya, dan menolak salah satunya hanya akan membuat
admin bertengkar dengan formulir.

### Yang berubah di backend

Titik pusatnya adalah `User::toPublicArray()` di `app/Models/User.php:129` —
satu tempat yang disepakati lima controller sebagai bentuk sebuah user.
`'username' => $this->username` menjadi `'phone' => $this->phone`, dan sebagian
besar permukaan API ikut terbawa tanpa disentuh satu per satu.

Sisanya:

| Berkas | Yang terjadi |
|---|---|
| `app/Models/User.php` `$fillable` | `'username'` → `'phone'` |
| `UserController.php:35` | pencarian: `username` → `phone`, bersama `name` dan `email` yang sudah ada |
| `UserController.php:74,93` | validasi & pembuatan: `required\|unique` → `nullable\|string\|max:30` |
| `UserController.php:147,159,160,172` | pembaruan: `phone` menggantikan `username` di daftar field yang boleh disunting |
| `UserController.php:108,166,198,205,210,242,278` | deskripsi log aktivitas memakai `name` |
| `AccessRequestController.php:162` | tidak lagi mengarang username saat menyetujui |
| `AccessRequestController.php:270-278` | `uniqueUsername()` **dihapus** |
| `app/Models/AccessRequest.php:64-70` | `suggestedUsername()` **dihapus** |
| `Conversation.php:65`, `MessageController.php:37`, `NewsController.php:41`, `TrainingController.php:391,433` | fallback nama |
| `UserActivityController.php:22,67`, `TrainingController.php:131,165`, `AccessRequestController.php:91,92`, `MessageController.php:104,105`, `NewsController.php:108,168` | daftar kolom `with()` |

#### Fallback nama yang ternyata sudah mati

Empat tempat menulis `$user->name ?? $user->username`. Karena `users.name`
**tidak nullable**, cabang kedua tidak pernah dijalankan sekali pun. Jadi ia
tidak diganti dengan `?? $user->phone` — ia **dihapus**, menyisakan
`$user->name`. Mengganti satu fallback mati dengan fallback mati yang lain
hanya memindahkan kesalahpahamannya.

`Conversation.php:65` adalah pengecualian dan tetap punya fallback, karena di
sana `$this->user` sendiri bisa null: sebuah percakapan tamu tidak punya akun.
Bentuknya jadi `$this->user?->name ?? "User #{$this->user_id}"`.

### Yang berubah di frontend

`UserModel.username` bertipe `String` **non-nullable** dan `fromJson`
membacanya langsung lewat `json['username']`, yang akan melempar bila null.
`phone` menggantikannya sebagai `String?`.

| Berkas | Yang terjadi |
|---|---|
| `models/user_model.dart` | `username` → `phone`, `String` → `String?`, ikut di `toJson` dan `copyWith` |
| `services/admin_user_service.dart:51,60,79,83,89` | parameter `username` → `phone`, opsional |
| `screens/admin/user_management_screen.dart` | kolom formulir, kolom tabel, teks pencarian, dan tujuh string yang menyebut `user.username` jadi `user.name` |
| `models/access_request.dart`, `services/access_request_service.dart:9,15,108` | field `username` pada kredensial hasil persetujuan dihapus |
| `screens/admin/access_requests_screen.dart` | dialog kredensial tidak lagi menampilkan username |
| `widgets/user_avatar.dart:133` | `user?.name ?? user?.username ?? '?'` → `user?.name ?? '?'` |
| `models/activity_log.dart`, `screens/admin/activity_logs_screen.dart` | nama pelaku diambil dari `name` |
| `screens/admin/admin_shell.dart`, `screens/user/user_shell.dart` | penyebutan `username` di sidebar |

### Baris log lama dibiarkan apa adanya

`UserController.php:210` menulis `'username' => $username` ke dalam metadata
JSON sebuah baris `user_activities` ketika sebuah akun dihapus.

Baris-baris yang sudah tertulis **tidak disentuh**. Itu catatan sejarah tentang
apa yang benar dan tercatat pada saat kejadian; menulisnya ulang agar cocok
dengan skema hari ini akan jadi kebohongan yang lebih buruk daripada kolom yang
sudah tidak ada. Penulisan **baru** memakai `name`.

## B1.2 — `max_concurrent_jobs` dihapus

### Alasannya

Kolom itu tidak melakukan apa pun. Seluruh `be/app` sudah ditelusuri: ia hanya
muncul di aturan validasi (`ModelController.php:65,142`), daftar `$fillable`,
seeder, dan test. **Ia tidak pernah dibandingkan dengan apa pun.** Niat aslinya
jelas — jangan kirim lebih dari N pekerjaan serentak ke satu worker — tetapi
pembatasnya tidak pernah ditulis, jadi selama ini ia menjanjikan kendali yang
tidak ada.

### Yang tetap tinggal

`current_jobs_count` **tidak dihapus**, karena ia bekerja: dinaikkan di
`ProcessDeepLearningImage.php:69`, diturunkan di baris 142, dan dibaca oleh
`ModelController.php:190,227` untuk menolak penghapusan atau penonaktifan model
yang sedang mengerjakan sesuatu. Itu perilaku sungguhan dan tidak berubah.

### Perubahan

```php
Schema::table('models', function (Blueprint $table) {
    $table->dropColumn('max_concurrent_jobs');
});
```

| Berkas | Yang terjadi |
|---|---|
| `ModelController.php:65,142` | aturan validasi dihapus |
| `ModelController.php:82,152,153,166` | hilang dari pembuatan, pembaruan, dan potret log |
| `app/Models/Model.php` `$fillable` | dihapus |
| `database/seeders/DefaultModelSeeder.php:37` | dihapus |
| `fe/lib/models/model_info.dart` | `maxConcurrentJobs` dan getter `isAtCapacity` dihapus |
| `fe/lib/services/admin_model_service.dart:103,132` | parameter dihapus |
| `fe/lib/screens/admin/model_management_screen.dart:392` | `'${model.currentJobsCount} / ${model.maxConcurrentJobs}'` jadi hitungan tunggal |
| 6 berkas test backend | `'max_concurrent_jobs' => 1` dibuang dari pembuatan model |

`ARCHITECTURE.md:127` menyebut kolom ini dalam daftar kolom tabel `models`;
barisnya diperbarui.

## Cara menguji

**Backend** — `cd be && php artisan test`, butuh basis data `db_aict_test`.
Dasarnya 250 test setelah bagian A.

Sebagian besar pekerjaan test di sini bersifat **mekanis**: 13 berkas test
membuat User dengan `'username' => ...`, dan semuanya harus membuangnya. Itu
penyuntingan, bukan penulisan ulang perilaku, dan tidak boleh disamarkan jadi
seolah-olah pengujian baru.

Test yang benar-benar baru, tiga:

- Sebuah akun bisa dibuat **tanpa** nomor telepon, dan nomor yang sama boleh
  dipakai dua akun. Inilah yang membedakan `phone` dari `username`, dan tanpa
  test ini tidak ada yang menghentikan seseorang memasang `unique` lagi nanti.
- Pencarian pengguna menemukan lewat nomor telepon.
- Menyetujui permintaan akses membuat akun **tanpa** mengarang apa pun untuk
  kolom yang sudah tidak ada — jalur ini punya dua metode khusus yang dihapus,
  jadi ia layak diuji sekali lagi setelah keduanya pergi.

**Frontend** — `cd fe && flutter analyze` harus bersih, lalu `flutter test`
(dasarnya 144 setelah bagian A). `UserModel` berubah bentuk, jadi test apa pun
yang membangunnya ikut disunting.

**Yang tidak dijangkau test:** buat satu akun lewat layar admin dengan kolom
telepon dikosongkan, lalu buat satu lagi dengan nomor yang sama persis. Keduanya
harus berhasil. Itu keseluruhan maksud keputusan "opsional, tidak unik", dan
`flutter test` tidak menyentuh basis data sungguhan.

## Risiko

**Ini penghapusan data.** `username` hilang dari basis data pengembangan dan,
saat deploy, dari VPS. Tidak ada yang membacanya lagi setelah perubahan ini,
jadi tidak ada yang rusak — tetapi ia tidak bisa dikembalikan, dan `down()`
mengisi ulang dengan `user{id}` alih-alih nilai aslinya.

**Luasnya penyuntingan test adalah risikonya sendiri.** Menyunting 13 berkas
test secara mekanis adalah cara yang baik untuk tidak sengaja melemahkan sebuah
asersi. Aturannya: buang kunci `username`, jangan sentuh apa pun yang lain di
baris yang sama.

**Migrasi harus dijalankan di VPS saat deploy**, dan `php artisan config:cache`
harus dijalankan ulang sesudahnya — catatan yang sudah ada di CLAUDE.md dan
sudah pernah menggigit di proyek ini.

## Yang bukan bagian B1

- **B2** — unggah video di News lewat `PredictionUploadController` dengan
  `purpose` baru `news_video`, ditambah emoji dan status *pending* di Messages.
  Batasnya sudah diketahui: `post_max_size` PHP adalah 8M dan menolak
  unggahan 25 MB dengan HTTP 413 dari `ValidatePostSize`, yang diverifikasi
  langsung terhadap server yang berjalan pada 22 Agustus 2026. Itu sebabnya
  video memakai unggah berpotongan alih-alih satu POST.
- **C** — penelusur tumpukan frame ala ImageJ.
- **D** — training periset.

Satu hal yang ditemukan di bagian A dan sengaja ditunda ke sini: lencana status
di layar unggah menampilkan `model.status.toUpperCase()`, sehingga worker lambat
berlabel **"TROUBLE"** tepat di sebelah kalimat "answering slowly". Itu bentuk
jargon yang sama dengan yang baru saja dibuang. Ia ikut dibereskan di B1 karena
`model_management_screen.dart` dan `model_info.dart` memang sudah dibuka untuk
`max_concurrent_jobs`: lencana membaca label ramah — `ONLINE`, `SLOW`,
`OFFLINE` — alih-alih nama status mentah.
