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

### 2. ✅ Tiket dukungan IT — SELESAI

Tombol IT Support harus membuat tiket yang masuk ke admin **di dalam aplikasi**,
bukan membuka email.

- [x] Tabel `support_tickets` — user, subjek, kategori, status, prioritas
- [x] Tabel `support_ticket_messages` — percakapan bolak-balik
- [x] User: buat tiket, lihat miliknya, balas
- [x] Admin: lihat semua, balas, ubah status, hapus
- [x] Penanda jumlah tiket menunggu balasan di sidebar admin
- [x] Tiket tamu dari halaman login — untuk yang **tidak bisa masuk**
- [x] Test: 23 test backend (scoping, alur status, balasan, tamu) + 7 Flutter

**Keputusan 1 — percakapan, bukan satu pesan.** Masalah teknis hampir selalu
butuh pertanyaan balik ("frame-nya berapa?", "pesan errornya apa?"), dan tanpa
balasan admin harus keluar aplikasi untuk bertanya.

**Keputusan 2 — tombol IT Support ada di halaman login, dan alasan paling umum
menekannya adalah tidak bisa login.** Endpoint yang butuh token jadi tidak
berguna persis di saat paling dibutuhkan, jadi ada `POST
/api/support/tickets/public` (throttle 5/jam): tiket masuk antrean admin yang
sama, hanya `user_id`-nya null dan diganti nama + email pelapor. Balasannya
lewat email, karena tidak ada akun untuk menampilkannya — layar percakapan
memberitahu admin hal ini alih-alih membiarkannya membalas ke ruang kosong.

**Keputusan 3 — tiket tamu tidak ditempelkan ke akun yang emailnya cocok.**
Email itu belum terverifikasi, jadi menempelkannya berarti siapa pun bisa
menaruh pesan di daftar tiket peneliti lain.

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

## Berikutnya

Kosong. Tujuh item terakhir sudah selesai; lihat "Sudah selesai" di bawah.

---

## Sudah selesai

- [x] Pipeline prediksi FASE 3 (upload, interpolasi rekursif, unduh, retensi)
- [x] Chunked upload resumable di sisi server
- [x] Konsol peneliti (dashboard, unggah, hasil, riwayat, aktivitas)
- [x] Pratinjau frame — TIFF 16-bit dirender jadi PNG di server
- [x] Sesi paralel — satu akun bisa aktif di beberapa perangkat
- [x] Suite test backend (156 test) dan Flutter (54 test)
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
- [x] **7.** Rancangan sistem pelatihan model — ditulis di
      [ARCHITECTURE.md](ARCHITECTURE.md) §7, bukan sebagai berkas baru.

---

## Tidak dikerjakan, dan alasannya

**Melatih model dari dalam aplikasi.** Bisa secara teknis, tapi itu sistem lain:
notebook di repo ini nol kode training, modelnya generator GAN 25,6 juta
parameter yang discriminator-nya tidak ada di sini, dan sesi Kaggle putus tiap
~9–12 jam sementara training butuh berhari-hari.

Yang realistis adalah platform **mengelola** training, bukan menjalankannya —
mengunggah dataset, mencatat job, menerima bobot + metrik, mendaftarkannya
sebagai versi model baru. Tabel `models` sudah punya `version`, `accuracy`,
`deployed_at`, jadi separuh jalan sudah ada.

Nilainya besar: kalau model dilatih ulang dengan dataset t seimbang,
**metode rekursif tidak lagi diperlukan** — ia ada justru untuk menyiasati bias
yang hanya bisa dihilangkan lewat retrain. Lihat
[AI_EXPERIMENTS.md](AI_EXPERIMENTS.md).

Skalanya setara seluruh FASE 3. Ditunda sampai hal-hal di atas selesai.
