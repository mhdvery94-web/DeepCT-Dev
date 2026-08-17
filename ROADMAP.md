# Roadmap

Satu-satunya daftar pekerjaan yang direncanakan. Diperbarui saat pekerjaan
berjalan — centang diisi hanya setelah **diverifikasi**, bukan setelah ditulis.

Ini bukan dokumen status. Jangan buat `*_PLAN.md` atau `*_SUMMARY.md` baru;
perbarui berkas ini, lalu catat hasilnya di [CHANGELOG.md](CHANGELOG.md).

**Terakhir diperbarui:** 15 Agustus 2026

---

## Sudah dikerjakan pada putaran ini

Tujuh item di bawah semuanya selesai dan terverifikasi. Catatan keputusannya
sengaja dipertahankan: alasan sebuah pilihan diambil jauh lebih mahal untuk
ditemukan ulang daripada kodenya.

### 1. ✅ Formulir Join yang benar-benar bekerja — SELESAI

Bagian "Join Research" di landing page saat ini hanya placeholder — tombolnya
memunculkan snackbar dan tidak ada apa pun yang tersimpan. Peneliti yang ingin
akses tidak punya jalur sama sekali, dan fitur ini juga tidak bisa dipakai untuk
testing.

- [x] Tabel `access_requests` — nama, email, institusi, status, catatan reviewer
- [x] `POST /api/access-requests` — publik, dibatasi rate limit 5/menit
- [x] Admin: daftar (dengan filter status), setujui, tolak, hapus
- [x] Menyetujui permintaan **langsung membuat akun user** dengan password default
- [x] Landing page: form tersambung, validasi, dan umpan balik yang jelas
- [x] Layar admin `AccessRequestsScreen` dengan dialog kredensial sekali-tampil
- [x] Test: 14 test — pengiriman, duplikat, akun sudah ada, alur persetujuan

**Keputusan:** menyetujui membuat akun sekaligus, bukan sekadar menandai
"approved". Kalau tidak, admin tetap harus membuat user manual dan permintaan
itu jadi catatan mati.

### 2. ✅ Dukungan IT — SELESAI (dibangun ulang jadi pesan, lihat no. 8)

Tombol IT Support harus sampai ke admin **di dalam aplikasi**, bukan membuka
email.

Awalnya dibangun sebagai sistem tiket (subjek, kategori, prioritas, status).
**Model itu diganti jadi pesan biasa di putaran berikutnya — lihat no. 8.**
Yang bertahan dari desain ini, karena alasannya masih berlaku:

- [x] Percakapan bolak-balik, bukan satu pesan sekali kirim
- [x] User: kirim, lihat miliknya, balas
- [x] Admin: lihat semua, balas, hapus
- [x] Penanda jumlah yang menunggu balasan di sidebar admin
- [x] Jalur tamu dari halaman login — untuk yang **tidak bisa masuk**

**Keputusan 1 — percakapan, bukan satu pesan.** Masalah teknis hampir selalu
butuh pertanyaan balik ("frame-nya berapa?", "pesan errornya apa?"), dan tanpa
balasan admin harus keluar aplikasi untuk bertanya.

**Keputusan 2 — tombol IT Support ada di halaman login, dan alasan paling umum
menekannya adalah tidak bisa login.** Endpoint yang butuh token jadi tidak
berguna persis di saat paling dibutuhkan, jadi ada `POST /api/messages/public`
(throttle 5/jam): pesannya masuk inbox admin yang sama, hanya `user_id`-nya null
dan diganti nama + email pengirim. Balasannya lewat email, karena tidak ada akun
untuk menampilkannya — layar percakapan memberitahu admin hal ini alih-alih
membiarkannya membalas ke ruang kosong.

**Keputusan 3 — percakapan tamu tidak ditempelkan ke akun yang emailnya cocok.**
Email itu belum terverifikasi, jadi menempelkannya berarti siapa pun bisa
menaruh pesan di percakapan peneliti lain.

### 3. ✅ Berita riset dengan foto — SELESAI

- [x] Tabel `news_posts` — judul, ringkasan, isi, gambar, terbit, urutan
- [x] Admin: CRUD, unggah gambar, **toggle terbit/tidak**
- [x] `GET /api/news` — publik, hanya yang terbit
- [x] Landing page: slideshow di bagian Research, auto-advance 7 detik
- [x] Test: 17 backend + 15 Flutter

**Kendala nyata:** mesin ini tidak punya GD maupun Imagick, jadi **gambar tidak
bisa diubah ukurannya di server**. Unggahan disimpan apa adanya dengan batas 4
MB dan validasi `mimetypes:` (membaca isi berkas, bukan ekstensinya). Kalau
nanti butuh thumbnail, ekstensi harus dipasang lebih dulu.

**Keputusan 1 — gambar dialirkan lewat API, bukan `public/`.** Tidak ada
`storage:link` di mesin ini dan aplikasi diakses lewat ngrok; jalur simbolik
cuma satu hal lagi yang bisa salah. `GET /api/news/{id}/image` publik untuk
post yang terbit, dan **404 untuk draf** kecuali pemanggilnya admin — draf yang
bisa dibaca dengan menebak id berarti hasil riset bocor sebelum diumumkan.

**Keputusan 2 — menyimpan tidak sama dengan menerbitkan.** Tombol terbit
terpisah dari tombol simpan, jadi draf bisa disiapkan tanpa risiko tak sengaja
muncul di situs. `published_at` hanya diisi saat pertama kali terbit, supaya
menyembunyikan lalu menampilkan lagi post lama tidak melemparkannya ke depan
slideshow.

**Keputusan 3 — carousel diam kalau gagal.** Kalau feed-nya kosong atau
request-nya gagal, widget-nya tidak merender apa pun. Pengunjung tidak boleh
disuguhi kotak error di halaman depan gara-gara hal opsional.

### 4. ✅ Foto profil pengguna — SELESAI

- [x] Kolom `users.avatar_path` + `avatar_mime`
- [x] Unggah foto sendiri; admin boleh mengubah milik siapa pun
- [x] Endpoint penyajian yang ter-otorisasi
- [x] **Bingkai inisial** kalau belum ada foto
- [x] Tampil di sidebar (dua-duanya), manajemen user, dan log aktivitas
- [x] Test: 15 backend + 11 Flutter

**Keputusan 1 — bingkai inisial itu desain, bukan placeholder.** Sebagian besar
akun tidak akan pernah mengunggah foto. Kotak abu-abu atau ikon gambar rusak
terbaca sebagai error; inisial di atas warna khas akun itu terbaca sebagai
disengaja, dan tetap jelas di ukuran 22px. Warnanya diturunkan dari nama, jadi
wajah yang sama selalu dapat warna yang sama antar sesi.

**Keputusan 2 — akun tanpa foto menjawab 404, bukan gambar bawaan.** Klien yang
menggambar bingkainya; placeholder dari server cuma jadi pendapat kedua soal
seperti apa "tidak ada foto" itu.

**Keputusan 3 — penyajian butuh login.** Avatar muncul di daftar user dan log
aktivitas, jadi tiap akun yang sudah masuk perlu memuatnya, tapi pengunjung
anonim tidak boleh memanen foto staf peneliti dengan menelusuri id.

**Konsekuensi teknis:** karena endpoint-nya ter-otorisasi, `Image.network`
tidak bisa dipakai — token-nya ada di secure storage dan dibaca async oleh
interceptor Dio. Byte-nya diambil lewat `ApiClient` dan di-cache di memori
(`AvatarCache`), termasuk cache untuk yang *tidak ada* fotonya, supaya daftar
20 baris tidak menembak 20 request tiap rebuild.

---

### 8. ✅ Tiket dibangun ulang jadi pesan — SELESAI

**Umpan balik dari pemilik produk:** "model tiketnya itu berupa pesan saja di
dalam aplikasi, jadi user bisa kirim pesan ke admin jika ada kendala melalui IT
support."

Betul, dan alasannya lebih dalam daripada soal tampilan. Model tiket memaksa
orang yang sedang bermasalah **mengklasifikasikan masalahnya lebih dulu** —
subjek, kategori, prioritas — lalu memantau status. Itu bentuk helpdesk dengan
satu departemen dan SLA di belakangnya. Di sini adminnya satu orang.

- [x] Tabel `conversations` + `messages` menggantikan `support_tickets` +
      `support_ticket_messages`; data lama **dipindahkan**, subjek tiket
      dilipat jadi baris pertama pesannya supaya tidak ada tulisan yang hilang
- [x] Dibuang: `subject`, `category`, `priority`, `status`, `awaiting_admin`,
      `resolved_at`, `resolved_by`, `analysis_record_id`
- [x] Satu percakapan per akun (unique index), tanda dibaca dua arah, arsip
- [x] Layar: satu percakapan untuk peneliti, inbox untuk admin
- [x] Test: 22 backend + 19 Flutter

**Keputusan — route peneliti tidak menerima id sama sekali.** Karena percakapan
per akun cuma satu, "punya saya" satu-satunya arti yang mungkin. Efeknya bukan
sekadar rapi: seluruh kelas bug "akun A membaca pesan akun B" hilang bukan
karena dijaga, tapi karena **tidak ada id yang bisa diutak-atik**.

**Keputusan — arsip, bukan status.** Admin tetap butuh cara merapikan inbox,
tapi empat keadaan (`open`/`in_progress`/`resolved`/`closed`) untuk satu orang
itu berlebihan. Satu flag cukup, dan pesan baru menariknya kembali ke inbox:
yang diarsipkan itu percakapan, bukan orangnya.

### 9. ✅ Notifikasi untuk admin dan peneliti — SELESAI

- [x] Tabel `notifications` (skema bawaan Laravel) + `PlatformNotification`
- [x] `app/Services/Notifier.php` — semua event di satu berkas
- [x] Lonceng dengan penanda di kedua konsol, panel isinya, tandai dibaca
- [x] `GET /notifications/unread-count` memberi **dua** angka sekaligus
- [x] Test: 20 backend + 12 Flutter

Yang diberitahukan:

| Event | Ke siapa |
|---|---|
| Pesan masuk / pesan tamu | Semua admin aktif |
| Balasan admin | Peneliti yang bertanya |
| Prediksi selesai / gagal | Pemilik job |
| **Hasil akan kedaluwarsa** (~3 jam lagi) | Pemilik job |
| Permintaan akses baru | Semua admin aktif |
| Akun disetujui | Akun barunya |
| Model mati / hidup lagi | Semua admin aktif |

**Keputusan — notifikasi tidak boleh menjatuhkan pemanggilnya.** Prediksi yang
sudah selesai tidak boleh ditandai gagal cuma karena menulis baris notifikasi
gagal. Semua lewat `push()` yang menelan error dan mencatatnya di log.

**Keputusan — status model diberitahukan hanya saat berubah.** Health check
jalan tiap 5 menit; tanpa itu, model yang mati semalaman menghasilkan 288
notifikasi identik.

**Keputusan — peringatan kedaluwarsa dititipkan ke sweep yang sudah ada.**
`predictions:cleanup` sudah jalan tiap jam; ia sekarang juga memperingatkan
pemilik hasil yang akan dihapus ~3 jam lagi, sekali saja
(`analysis_records.expiry_notified_at`). Menghapus 1,5 GB hasil riset tanpa
pernah memberitahu pemiliknya adalah hal paling mahal yang bisa dilakukan
platform ini kepada seseorang.

**Temuan sampingan:** tabel `notifications` dan `personal_access_tokens`
polimorfik, jadi **tidak punya foreign key** ke `users`. Menghapus akun
meninggalkan keduanya hidup selamanya — token pun, yang artinya kredensial tanpa
pemilik. `User::booted()` sekarang membersihkan keduanya beserta berkas
avatarnya.

---

## Berikutnya

### 10. Training dijalankan peneliti, bukan admin — BELUM DIKERJAKAN

**Permintaan pemilik produk:** "alurnya mirip dengan prediksi. Admin hanya
on/off dan menyetel endpoint training lewat URL, persis seperti model.
Kemudian user mengunggah dataset untuk dilatih sesuai model yang ada, persis
seperti ketika user melakukan prediksi. Jadi yang melatih itu user, bukan
admin. Pembedanya di output: prediksi menghasilkan gambar, training
menghasilkan data untuk melihat kepintaran sebuah model."

Bentuk sekarang **kebalikannya**: training seluruhnya milik admin. Dataset
didaftarkan admin (`POST /admin/training/datasets`), job diantrekan admin, dan
tidak ada satu pun route training di bawah `me/`. Peneliti tidak bisa
menyentuhnya.

Yang perlu berubah, dan besarnya jujur saja setara satu fase:

- [ ] **Registry trainer, kembaran registry model.** Tabel sendiri dengan
      `endpoint_url`, `is_active`, `status`, health check — supaya admin cukup
      on/off dan menempel URL, sama seperti model. Hari ini URL trainer hidup
      sebagai kolom di `training_jobs` plus satu variabel env.
- [ ] **`training_jobs.user_id`** dan seluruh query di-scope ke pemiliknya,
      sebagaimana `analysis_records` sudah begitu.
- [ ] **Unggah dataset lewat jalur peneliti**, memakai kembali chunked upload
      yang sudah ada — bukan pendaftaran URL oleh admin.
- [ ] **Layar peneliti**: pilih model, unggah dataset, antre, pantau, lihat
      hasil. Cerminan `upload_screen` + `prediction_history_screen`.
- [ ] **Hasil sebagai angka, bukan berkas.** Prediksi mengembalikan TIFF;
      training mengembalikan metrik per epoch. Perlu tabel metrik dan layar
      yang membacanya sebagai kurva, bukan sekadar `.h5` untuk diunduh.
- [ ] Admin tetap memegang: menyetujui/menolak, membatalkan, dan mendaftarkan
      bobot hasil jadi versi model baru.

**Tiga hal yang harus diputuskan sebelum satu baris ditulis**, karena
jawabannya mengubah skemanya, bukan cuma tampilannya:

1. **Apa isi "data kepintaran" itu?** Loss + PSNR + SSIM per epoch sudah bisa
   dihasilkan `script-api-train-deepct.py` hari ini. Kalau yang dimaksud
   perbandingan antar model atau contoh gambar sebelum/sesudah, itu tabel dan
   layar yang berbeda.
2. **Hasil training jadi model baru, atau catatan eksperimen?** Kalau tiap
   peneliti bisa menerbitkan versi model, registry model butuh kepemilikan dan
   persetujuan. Kalau hanya catatan, bobotnya tidak pernah meninggalkan job-nya.
3. **Sistem admin yang sekarang dibuang atau ditumpuk?** Delapan route admin,
   dua tabel, dan enam route worker sudah jalan dan tertutup test. Membuangnya
   membuang yang berfungsi; menumpuk membuat dua jalur ke hal yang sama.

Sampai ketiganya dijawab, ini **belum dimulai** — dan itu disengaja. Menulis
skema atas tebakan pada fitur sebesar ini persis kesalahan yang membuat
dokumen "COMPLETE & PRODUCTION READY" itu ada.

---

## Sudah selesai

- [x] Pipeline prediksi FASE 3 (upload, interpolasi rekursif, unduh, retensi)
- [x] Chunked upload resumable di sisi server
- [x] Konsol peneliti (dashboard, unggah, hasil, riwayat, aktivitas)
- [x] Pratinjau frame — TIFF 16-bit dirender jadi PNG di server
- [x] Sesi paralel — satu akun bisa aktif di beberapa perangkat
- [x] Suite test backend (177 test) dan Flutter (89 test)
- [x] Konsolidasi dokumentasi, 28 berkas jadi 10
- [x] Git remote + cadangan lokal
- [x] **5.** `applicationId` diganti dari `com.example.fe` jadi
      `id.go.brin.neutronct` — reverse-DNS institusi pemiliknya. Mengubahnya
      setelah rilis berarti aplikasi terpasang jadi dua, jadi harus beres
      sebelum APK dibagikan. iOS/macOS/Linux/Windows ikut diganti sekalian
      supaya tidak jadi ranjau nanti.
- [x] **6.** Resume upload dari sisi klien — sesi disimpan di perangkat,
      potongan yang gagal dicoba ulang 3× setelah menyinkronkan ulang offset
      ke server, dan upload yang terputus ditawarkan untuk dilanjutkan.
- [x] **7.** Sistem pelatihan model — **dibangun**, bukan lagi cuma rancangan.
      Tabel dataset + job, enam route worker berautentikasi token khusus, layar
      admin di web dan mobile, dan `scripts/training_worker.py` sebagai klien
      protokolnya. Yang masih kosong satu fungsi: `train_one_epoch()`, dan itu
      memang pekerjaan riset (lihat "Belum dibangun" di bawah).

---

## Belum dibangun, dan alasannya

**Kode training-nya sendiri.** Seluruh sistem di sekelilingnya sudah jalan dan
terverifikasi: admin mendaftarkan dataset, mengantrekan job, worker mengklaim,
melapor, checkpoint, dan job yang worker-nya mati kembali ke antrean lalu
dilanjutkan worker berikutnya dari epoch terakhir.

Yang belum ada cuma `train_one_epoch()` di `scripts/training_worker.py`, dan
itu memang disengaja.

Alasannya: notebook di repo ini nol kode training — modelnya generator GAN 25,6
juta parameter yang **discriminator-nya tidak ada di sini**, dan loss,
augmentasi, serta sampling t yang seimbang justru inti dari latihan ulangnya.
Menuliskannya dari tebakan menghasilkan angka yang tidak bisa dipertanggung-
jawabkan siapa pun.

Nilainya besar: kalau model dilatih ulang dengan dataset t seimbang,
**metode rekursif tidak lagi diperlukan** — ia ada justru untuk menyiasati bias
yang hanya bisa dihilangkan lewat retrain. Lihat
[AI_EXPERIMENTS.md](AI_EXPERIMENTS.md).

Sisanya satu fungsi, bukan satu sistem.

**Notifikasi email — diputuskan tidak dikerjakan.** Aplikasi tidak mengirim satu
email pun, dan itu sekarang pilihan, bukan pekerjaan yang tertunda: pesan
in-app (no. 8) dan lonceng notifikasi (no. 9) sudah menjadi kanalnya, dan
menambah kanal kedua berarti menambah SMTP, deliverability, dan satu sistem
lagi yang bisa diam-diam berhenti bekerja.

Satu hal yang tetap tidak tercakup, dan sengaja dibiarkan: **pengirim tamu**
dari halaman login tidak punya akun, jadi tidak ada layar tempat balasan admin
bisa muncul. Balasan untuk mereka masih dikirim admin dari emailnya sendiri —
layar percakapan memberitahu admin hal ini alih-alih membiarkannya membalas ke
ruang kosong. Kalau jalur tamu nanti ramai, ini alasan pertama untuk meninjau
ulang keputusan di atas.
