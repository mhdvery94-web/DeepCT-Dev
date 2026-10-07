# Roadmap

Satu-satunya daftar pekerjaan yang direncanakan. Diperbarui saat pekerjaan
berjalan — centang diisi hanya setelah **diverifikasi**, bukan setelah ditulis.

Ini bukan dokumen status. Jangan buat `*_PLAN.md` atau `*_SUMMARY.md` baru;
perbarui berkas ini, lalu catat hasilnya di [CHANGELOG.md](CHANGELOG.md).

**Terakhir diperbarui:** 7 Oktober 2026

---

## Diketahui, belum dikerjakan

- [ ] **Migrasikan frontend web ke Next.js di `fe_web`.** Fondasi pertama sudah
      dibuat pada cabang `develop`: landing page responsif, research news dengan
      satu media stage untuk foto/video, login Sanctum dalam cookie `HttpOnly`,
      BFF same-origin, guard admin/user, dashboard dan route seluruh modul.
      `npm run check`, production build 21 route, dan smoke test HTTP lokal sudah
      lulus. Yang belum boleh disebut selesai: tabel/form CRUD tiap modul,
      prediksi/training lengkap, URL unduhan besar bertanda tangan, staging API
      yang terpisah dari database produksi, proyek Vercel Next.js, dan UAT.

- [ ] **Terapkan promosi branch `develop` → `staging` → `main`.** Ketiga branch
      sudah dibuat lokal dan workflow `web-next.yml` memetakan preview/staging
      serta production. Setelah didorong, aktifkan branch protection dan wajibkan
      pull request/check sebelum promosi. `main` tetap satu-satunya branch yang
      boleh men-deploy backend ke Raspberry Pi.

- [ ] **Selesaikan perpindahan produksi dari VPS ke Raspberry Pi.** Source
      backend sudah berada di `/var/www/deepct-ai`; `deepct-app` dan
      `deepct-ngrok` hidup di bawah PM2/systemd; API publik, runner ARM64,
      deploy otomatis, dan proyek Vercel baru sudah terverifikasi. Workflow
      manual 1 Oktober juga membuat akun administrator dan researcher dari
      repository secrets, lalu membuktikan keduanya dapat login pada Octane
      yang benar-benar berjalan. Suite MySQL lulus 385 test/1.536 asersi,
      Flutter lulus 276 test, dan 12/12 pengujian black box produksi lulus.
      Yang tersisa sebelum VPS boleh dimatikan: putuskan apakah data historis
      dan `storage/` VPS perlu disalin, sinkronkan katalog model produksi,
      jalankan prediksi ujung-ke-ujung terhadap worker nyata, lakukan masa
      observasi, siapkan backup di luar Pi, lalu hentikan VPS.

- [x] **`hyperparameters` dikirim sebagai `[]`, bukan `{}`.** *(1.35.0)*
      Ternyata tiga tempat, bukan satu: `MeTrainingController`,
      `TrainingWorkerController` (payload claim, yang dibaca Pydantic dan
      **ditolak** kalau berupa list) dan bentuk detail `TrainingController`.
      Diverifikasi di kawat terhadap server berjalan, bukan pada array yang
      sudah didekode — keduanya terbaca sama setelah `json_decode`.

- [x] **Ekstensi bobot training ditebak, dan tebakannya tidak stabil.**
      *(1.35.0)* `storeAs()` dengan ekstensi dari nama klien, disaring lewat
      daftar sufiks bobot yang dikenal karena nama berkas adalah masukan
      klien. Checkpoint ikut, karena checkpoint yang tidak bisa dimuat sama
      saja dengan tidak ada. Job 18 (2 September) mendarat sebagai `.hdf`
      juga — tebakan yang sama, ketiga kalinya. Kedua berkas lama diganti
      namanya ke `.h5` setelah delapan byte pertamanya dibaca dan ternyata
      magic HDF5; keduanya kini terunduh sebagai `.h5`.

- [x] **Posisi antrean dihitung di ~~dua~~ tiga tempat.** *(1.35.0)*
      `PredictionUploadController::queuePosition()` adalah salinan ketiga yang
      tidak disebut di catatan ini. Dan angkanya **tidak** setara: dua rekaman
      berbagi detik yang sama membuat hitungan `created_at <` memberi keduanya
      angka 1 sementara papan menampilkan 1 dan 2 — dibuktikan dengan tes yang
      merah lebih dulu, lalu diulang terhadap server berjalan.

- [x] **`script-api-deepct.py` diabaikan git.** *(1.35.0)* Dicabut dari
      `.gitignore` setelah dipastikan tidak ada kredensial polos yang tersisa
      di dalamnya. `script-deepct.py`, nama lama yang memang menyimpan token,
      tetap diabaikan.

- [x] **`TiffPreview` membangun array PHP sebesar jumlah piksel.** *(1.36.0)*
      Piksel kini tinggal di string biner dan dibuka `unpack` per blok 8.192,
      jadi biayanya seukuran frame-nya sendiri alih-alih kelipatannya.
      Terukur: frame 2048×2048 turun dari **196 MB ke 11,7 MB**, dan dua frame
      sekaligus — yang dipegang `FrameMetrics` saat membandingkan hasil
      terhadap frame yang disembunyikan — dari **262 MB ke 20 MB**.

      `MAX_PIXELS` naik lagi ke `4096×4096`, bukan kembali penuh ke
      `8192×8192`: pada ukuran itu satu pratinjau makan 10,2 detik dan
      perbandingan dua frame 260 MB. **Yang membatasi sekarang waktu, bukan
      memori** — dan itu perubahan yang berarti, karena batas memori membunuh
      prosesnya sementara batas waktu hanya membuatnya lambat.

- [x] **Pratinjau dataset 404 untuk frame di dalam subfolder.** *(1.37.0)*
      Rute diberi `->where('name', '.*')` supaya segmen itu bisa merentang
      garis miring. Aman karena controller memeriksa nama terhadap daftar isi
      arsip, bukan membersihkannya — dan uji traversal yang sudah ada kini
      benar-benar menguji pemeriksaan itu, bukan lolos karena rutenya kebetulan
      tidak cocok.

      Ditemukan 2 September saat mencari frame sungguhan untuk menguji
      `TiffPreview`. Bagian E terbukti pada arsip datar dan tidak pernah
      bertemu yang berfolder, padahal arsip BRIN yang nyata berfolder.

- [x] **Model dirancang untuk satu sisipan titik tengah, dan batasnya sudah terukur.** Diukur 4 September
      terhadap arsip BRIN: hanya frame yang **kedua batasnya hasil pindai** yang
      layak dipakai. Celah 2 memberi 1 dari 1, celah 4 memberi 1 dari 3, celah 8
      memberi **0 dari 7** — ambangnya menyalin frame di sebelahnya, MAE 555.
      Penyebabnya model mengabaikan skalar waktu (tanggapan 0,17%), sehingga
      pengisian harus rekursif dan galat berlipat 1,73× per batas sintetis.

      Sistem **tetap mengisi** celah lebar, tetapi asal-usulnya disampaikan
      lewat `generation`. Yang belum ada: peringatan eksplisit di antarmuka
      bahwa frame bergenerasi dua ke atas berada di bawah ambang kelayakan.

- [ ] **Penyempurnaan bobot diserahkan ke BRIN.** Job 19 (`balanced_t`,
      `max_gap=8`, 20 epoch) menaikkan tanggapan `t` dari 0,17% ke 27,87%,
      tetapi masih di bawah ambang yang dapat dibedakan mata. Kurva latih
      **belum mendatar** — lima epoch terakhir masih menurun pada 76% laju awal.

      Dua arah lanjutan, urut biaya: melanjutkan pelatihan melewati epoch 20
      dengan laju belajar lebih besar, dan — yang sebenarnya menentukan —
      memperoleh barisan proyeksi lebih panjang dari satu objek yang sama.
      Sepuluh frame menghasilkan 112 contoh berhadapan dengan 21,9 juta
      parameter. Ambang lulus ditetapkan: rasio keragaman pada objek yang tidak
      dilatihkan ≥ 0,6, yaitu jarak antar-hasil ≥ 107 pada Sample Contrast.

      Bobotnya ada di `models-ai/generator(Revisi 4 STUNet balanced-t maxgap8).h5`
      dan **tidak dipasang**; sistem memakai bobot dasar.

- [ ] **`ApiConfig.baseUrl` sumber masih default ke tunnel worker lama.**
      Build produksi sudah aman karena workflow selalu menyuntikkan
      `RASPI_API_BASE_URL`, dan bundle Vercel telah diverifikasi memakai API
      Pi. Default sumber tetap perlu diganti agar build manual tanpa
      `--dart-define` tidak salah alamat.

---

## Putaran 24–25 Agustus: hasil yang bisa dipertanggungjawabkan

Sepuluh item, dikerjakan berurutan dan masing-masing diverifikasi sebelum yang
berikutnya dimulai. Latar belakangnya satu kalimat: sebuah job selesai dengan
mengembalikan folder TIFF, jumlah berkas, dan lama proses — dan peneliti yang
menerimanya tidak punya dasar apa pun untuk membela hasilnya.

### Rantai prediksi

- [x] **F2 — Jejak asal-usul frame.** Tiap frame bangkitan mencatat kedua frame
      batasnya dan generasinya. Generasi 1 berarti kedua batasnya hasil pindai;
      2 berarti model diberi makan keluarannya sendiri. `interpolateBetween()`
      sudah mengetahui angkanya sepanjang waktu — ia hanya tidak pernah diminta
      menyimpannya. Kolom baru, bukan perubahan bentuk `interpolated_frames`.
- [x] **F1 — Validasi hold-out.** Di mana pun arsip memuat tiga frame
      berurutan, yang tengah disisihkan, digambar ulang, dan diukur terhadap
      aslinya: MAE, RMSE, PSNR, plus rentang frame acuannya. Satu-satunya
      ground truth yang bisa dimiliki platform ini, karena frame yang ingin
      diisi peneliti menurut definisinya tidak dimiliki siapa pun.
- [x] **F3 — Manifes di dalam arsip.** `manifest.csv` menemani `metadata.json`:
      satu baris per frame, hasil pindai atau bangkitan, lengkap induk dan
      generasinya. Enam bulan lagi arsip itu mungkin satu-satunya yang tersisa.
- [x] **F4 — Bandingkan dua model.** `POST /predictions/{id}/rerun`. Frame
      masukannya disalin, bukan dibagi — perbandingan yang separuhnya bisa
      lenyap sendiri bukanlah perbandingan.
- [x] **F5 — Bukti setelah kedaluwarsa.** Enam thumbnail per run, permanen, di
      luar folder yang dihapus retensi. Beberapa ratus kilobita membeli jawaban
      atas "run itu tampak seperti apa", yang tidak bisa diberikan angka.

### Menyiapkan pindah ke Raspberry Pi + workstation GPU

- [x] **F7 — Autentikasi worker.** `auth_token` per model, dikirim
      `Authorization: Bearer`, terenkripsi, tulis-saja. Dikerjakan **sebelum**
      GPU pindah ke LAN: di Kaggle di balik terowongan bernama acak, ketiadaan
      autentikasi adalah keamanan lewat ketidaktahuan dan ia bertahan; di
      alamat tetap di jaringan lab ia tidak menahan apa-apa.
      Lima duplikasi panggilan keluar dilebur jadi `WorkerRequest`.
- [x] **F6 — Penjaga penyimpanan.** Kedua jalur unggah menolak **507** ketika
      tidak ada tempat, dan berkas sentinel membuktikan volume hasilnya benar
      ter-mount. Yang kedua lebih penting: share yang absen menerima tulisan
      tanpa mengeluh.
- [x] **F8 — Thumbnail keluar dari jalur kritis.** Enam frame adalah 10–15
      detik satu inti di Pi, dihabiskan setelah pekerjaan yang diminta selesai.
- [x] **F9 — Worker tak terjangkau diantrekan ulang.** Model yang *menjawab*
      dan menolak digagalkan; yang *tidak menjawab* dikembalikan ke antrean.
      Workstation tidur, reboot, dan dipakai main game.
- [x] **F10 — Ruang disk terlihat.** Panel di dashboard admin, dengan rincian
      yang memisahkan apa yang dikembalikan retensi dari apa yang tidak.

**Terverifikasi:** `php artisan test` 325 lulus (1.288 asersi),
`flutter test` 228 lulus, `flutter analyze` bersih.

### Yang tidak dikerjakan, dan alasannya

- **Default `ApiConfig.baseUrl` masih menunjuk terowongan ngrok pribadi.**
  Diketahui, dan sengaja dibiarkan selama masih tahap pengembangan. **Harus
  dibereskan sebelum deploy publik**: build produksi tanpa `--dart-define`
  akan diam-diam menunjuk laptop pengembang.
- **Uji ujung-ke-ujung terhadap worker sungguhan.** Menunggu endpoint-nya
  siap. Sekarang lebih penting daripada sebelumnya: validasi hold-out
  menambahkan satu putaran GPU yang belum pernah dijalani sungguhan.

---

## Sudah dikerjakan pada putaran sebelumnya

Enam item di bawah semuanya selesai dan terverifikasi; no. 5, 6 dan 7 ada di
"Sudah selesai" di bagian bawah. Catatan keputusannya sengaja dipertahankan:
alasan sebuah pilihan diambil jauh lebih mahal untuk ditemukan ulang daripada
kodenya.

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

### 10. Training dijalankan peneliti, bukan admin — TERPASANG, BELUM DIJALANI

**Ketiga pertanyaan sudah dijawab pemilik produk:**

1. Yang ditampilkan adalah **hasil dari model yang sudah dilatih** — angka per
   epoch (loss, PSNR, SSIM), bukan perbandingan antar model.
2. Hasil training **tetap di server** dan **tidak** menjadi model baru. Kalau
   suatu model sudah siap melayani, admin mendaftarkan URL endpoint-nya sendiri,
   persis seperti model biasa.
3. Sistem training khusus admin **diganti** oleh alur peneliti.

Backend dan klien dua-duanya sudah terpasang dan lulus test:

- [x] `models.kind` — trainer didaftarkan di registry yang sama dengan model
      inferensi, dengan sakelar on/off dan health check yang sama
- [x] `training_metrics` — riwayat per epoch, karena satu angka menjawab
      "sedang bagaimana" dan tidak bisa menjawab "jadi lebih pintar atau tidak"
- [x] `POST /me/training/jobs` — peneliti mengunggah ZIP dan menjalankan sendiri
- [x] `GET /me/training/jobs`, `GET /me/training/jobs/{id}` (dengan riwayat),
      `POST /me/training/jobs/{id}/cancel` — semuanya di-scope ke pemiliknya
- [x] `TrainerDispatcher` — dipakai bersama oleh admin dan peneliti
- [x] Unggah dataset **chunked** — `POST /predictions/uploads` menerima
      `purpose: training`, memakai ulang sesi resumable yang sudah ada
- [x] Kolom upload dicabut dari `POST /admin/training/datasets`; admin
      mendaftarkan URL saja
- [x] **Layar Flutter untuk peneliti** — `UserSection.training` di
      `user_shell.dart`, `training_screen.dart` (mulai run dengan unggah
      chunked, daftar run, tabel metrik per epoch), dan
      `researcher_training_service.dart`
- [x] **Kolom upload dicabut dari layar admin Flutter**, sejalan dengan backend
      yang sudah menolaknya
- [x] **`kind` di form model admin** — pilihan PREDICTION / TRAINING saat
      mendaftarkan endpoint, hanya saat membuat (mengubahnya belakangan akan
      diam-diam memindahkan job yang sudah merujuknya)
- [x] **Widget test layar training** — 7 test: keadaan kosong, peringatan
      trainer, tabel metrik per epoch, tombol batal yang hanya muncul saat
      relevan
- [x] **`POST /admin/training/jobs` dicabut** beserta tombol "NEW JOB" dan
      dialognya. Dua cara memulai run yang bedanya cuma atas nama siapa
      bukanlah pengawasan

Yang **belum**, dan ini yang menentukan judul di atas:

- [x] **Uji end-to-end terhadap trainer sungguhan.** *(1.34.0 / 1.35.0)*
      Sudah terjadi, dua kali. Job 17 selesai 29 Agustus dalam 2m29s
      (MAE 0,015464 · PSNR 37,5856 dB · SSIM 0,9856) dan job 18 selesai
      2 September, keduanya di GPU Kaggle lewat jalur peneliti dengan bobot
      87,8 MB dikembalikan ke platform. Itu **membuka gerbang** untuk butir
      "Membersihkan `POST /admin/training/datasets`" di bawah, yang sengaja
      ditahan sampai jalur peneliti terbukti.
- [x] **Resume untuk unggah dataset.** *(1.38.0)* `UploadResumeStore` kini
      punya satu slot per keperluan, jadi prediksi setengah terkirim dan
      training setengah terkirim tidak saling menggusur. Digest dihitung
      dengan menyusuri `ArchiveSource` per megabyte — `md5.convert(bytes)`
      akan mengembalikan biaya memori yang baru saja dibuang.

      Loop chunk-nya **belum** disatukan dengan `prediction_service.dart`.
      Keduanya kini cukup mirip untuk itu, tapi refactor itu menyentuh
      satu-satunya jalur unggah yang pernah terbukti ujung-ke-ujung terhadap
      GPU sungguhan, dan pantas dapat putaran sendiri alih-alih menumpang
      sebuah fitur.
- [ ] **Membersihkan `POST /admin/training/datasets`.** Ia masih ada dan masih
      berfungsi, dibiarkan sengaja sampai jalur peneliti terbukti bekerja di
      GPU sungguhan — mencabut satu-satunya jalur yang pernah dijalani sebelum
      penggantinya terbukti akan meninggalkan platform tanpa cara melatih sama
      sekali. Pasangannya, `POST /admin/training/jobs`, sudah dicabut.

### 11. Dua lubang yang ditemukan saat review 18 Agustus 2026

Keduanya lahir dari perubahan di no. 10 dan tidak tercakup di daftar mana pun
sebelum ini.

- [x] **Arsip dataset training tidak punya retensi.** *(1.38.0)*
      `training:cleanup`, dijadwalkan harian pukul 03:10. Arsip dan cache
      pratinjaunya dihapus; barisnya tetap dan distempel `archive_deleted_at`,
      seperti `files_deleted_at` pada prediksi dan karena alasan yang sama —
      job training menunjuk ke dataset-nya.

      **Jendelanya diukur dari pemakaian terakhir, bukan dari waktu unggah.**
      Itu inti rancangannya: dataset diunggah ke platform justru supaya bisa
      dipakai ulang, jadi jam yang berjalan sejak unggah akan menghapus arsip
      yang dilatih setiap minggu. Dataset dengan job `queued` atau aktif tidak
      pernah disapu, seberapa tua pun.

      Default 30 hari (`TRAINING_DATASET_RETENTION_DAYS`). Retensi 24 jam ala
      prediksi jelas salah di sini: itu hasil yang diunduh sekali, ini masukan
      yang didatangi lagi.

      Peneliti yang arsipnya sudah disapu **diberi tahu**, bukan disodori
      daftar frame kosong yang terbaca seperti arsip yang memang tidak berisi.

- [x] **Seluruh arsip dimuat ke RAM sebelum sepotong pun dikirim.**
      *(1.38.0)* `ArchiveSource` menjawab "berikan byte [start, end)". Di
      native ia membacanya dari `RandomAccessFile`, jadi hanya potongan
      berjalan yang pernah residen; picker diminta `withData: kIsWeb`.

      **Di web tidak berubah, dan itu memang batasnya:** browser tidak memberi
      path, jadi byte-nya tetap di memori dan `BytesArchiveSource` jujur soal
      itu alih-alih berpura-pura. Frame lepas yang di-zip aplikasi ini sendiri
      juga tetap di memori — ia dibangun di sana dan tidak punya tempat lain.

      `upload_screen.dart` masih `withData: true`. ZIP prediksi jauh lebih
      kecil, dan mengubahnya berarti menyentuh jalur yang sama.

### 12. Sepuluh permintaan perubahan, 22 Agustus 2026

Diajukan sekaligus, dipecah jadi empat karena tidak muat dalam satu rencana yang
bisa direview. Urutannya B → C → D setelah A; B lebih dulu karena migrasinya
menyentuh banyak test dan lebih baik mendarat saat pohon test masih stabil,
C sebelum D karena D memakai widget yang lahir di C.

- [x] **A — Bersih-bersih UI** — kode selesai, **tiga pemeriksaan mata belum**.
      Teks bisa disalin (`SelectionArea` di empat tempat, termasuk
      `app_dialog.dart` yang berada di luar pohon shell), recent activity punya
      area scroll sendiri berbatas 320px, model berstatus `trouble` diperlakukan
      sebagai tersedia alih-alih tampak mati, dan jargon `ERR_NGROK_3200`
      diganti kalimat yang bisa ditindaklanjuti bagi periset — dengan
      diagnostiknya tetap utuh untuk admin. Rancangan lengkapnya:
      [docs/superpowers/specs/2026-08-22-ui-cleanup-design.md](docs/superpowers/specs/2026-08-22-ui-cleanup-design.md).

      Terverifikasi 22 Agustus 2026: backend 250 test (dari 242), Flutter 144
      test (dari 129), `flutter analyze` bersih, APK release terbangun. Satu
      probe nyata terhadap endpoint ngrok yang mati menulis
      `health_check_reason: "tunnel_down"` dan responsnya tidak membawa nama
      host — diuji terhadap endpoint asli, bukan `Http::fake`.

      **Yang belum dilakukan, dan kenapa:**

      - **Seleksi teks di ponsel fisik.** Tidak ada perangkat Android
        tersambung. Perilaku tekan-lama tidak terlihat dari test widget, dan
        justru dari perangkat keluhan ini berasal. APK-nya sudah ada di
        `fe/build/app/outputs/flutter-apk/app-release.apk`.
      - **Tampilan dua perubahan tata letak di aplikasi berjalan** — kotak
        aktivitas di kedua dasbor, dan kotak error dua baris di Model
        Management.
      - **`REASON_SLOW` tidak punya test otomatis.** Ia dipicu waktu berjalan
        yang melewati `SLOW_THRESHOLD_MS`, sementara `Http::fake()` menjawab
        seketika; mengujinya menuntut penyuntik waktu di `ModelHealthChecker`
        demi satu asersi. Perilaku yang benar-benar penting — worker lambat
        tetap ditawarkan — diuji di `ModelAvailabilityTest`.
      - **Migrasi belum dijalankan di VPS.** `health_check_reason` baru ada di
        basis data pengembangan.

      Satu hal yang ditemukan tapi sengaja tidak diubah: lencana status di
      layar unggah menampilkan `model.status.toUpperCase()`, sehingga worker
      lambat berlabel **"TROUBLE"** tepat di sebelah kalimat "answering
      slowly". Itu jargon yang bentuknya sama dengan yang baru saja dibuang,
      tapi ia di luar cakupan yang disetujui — layak jadi satu baris di
      bagian B.
- [x] **B1 — Pembersihan skema** — kode selesai, **dua hal belum**.
      `username` diganti nomor telepon (opsional, tidak unik) dan
      `max_concurrent_jobs` dihapus — kolom yang tidak pernah dibandingkan
      dengan apa pun. Lencana status ikut dibereskan: worker lambat berlabel
      `SLOW`, bukan `TROUBLE`. Rancangan:
      [docs/superpowers/specs/2026-08-22-b1-schema-cleanup-design.md](docs/superpowers/specs/2026-08-22-b1-schema-cleanup-design.md).

      Terverifikasi 22 Agustus 2026: backend 256 test (dari 250), Flutter 147
      test (dari 144), `flutter analyze` bersih, APK release terbangun. Payload
      `/api/admin/users` diperiksa langsung terhadap server yang berjalan.

      Dikerjakan dengan tiga migrasi berurutan, bukan satu: tambah `phone` dan
      longgarkan `username`, pindahkan penulis, pindahkan pembaca, pindahkan
      klien, baru jatuhkan kolomnya. Setiap langkah berakhir hijau.

      **Yang belum dilakukan:**

      - **Tampilan kolom telepon di aplikasi berjalan.** Formulir dan kolom
        tabel belum dilihat mata; tidak ada perangkat Android tersambung, dan
        pemeriksaan tertunda dari bagian A juga masih berlaku.
      - **Migrasi belum dijalankan di VPS.** Ketiganya baru ada di basis data
        pengembangan. Ingat `php artisan config:cache` sesudahnya.

      **Rollback bersifat merusak:** seluruh nilai `username` hilang, dan
      `down()` mengisi ulang dengan `user{id}` semata agar batasan `unique`
      bisa dipasang kembali.
- [x] **B2 — Video News dan Messages** — kode selesai, **tiga hal belum**.
      Unggah video (maks 50 MB) lewat mesin unggah berpotongan yang sudah ada
      (`purpose` baru `news_video`), ditambah tombol pemilih emoji dan status
      *pending* saat pesan dikirim. Rancangan:
      [docs/superpowers/specs/2026-08-22-b2-video-and-messages-design.md](docs/superpowers/specs/2026-08-22-b2-video-and-messages-design.md).

      Terverifikasi 22 Agustus 2026: backend 270 test (dari 256), Flutter 153
      test (dari 147), `flutter analyze` bersih, APK release terbangun pada
      60,5 MB dengan dua paket baru.

      Tidak ada satu baris kode Range yang ditulis: `BinaryFileResponse` sudah
      menjawabnya, dibuktikan dengan `Range: bytes=0-99` yang dijawab `206`.

      **Yang belum dilakukan:**

      - **Memutar video sungguhan di aplikasi berjalan dan menggesernya.**
        `curl` membuktikan server menjawab `206`; itu tidak membuktikan
        pemutarnya memintanya. Begitu juga panel emoji dan gelembung pending
        di perangkat sentuh.
      - **Migrasi belum dijalankan di VPS.**
      - **Unggah video tidak bisa melanjutkan sesi yang terputus**, dan seluruh
        berkas dimuat ke RAM sebelum dikirim — keterbatasan yang sama dengan
        dataset training di no. 11. 50 MB jauh di bawah 2 GB yang jadi
        kekhawatiran di sana, jadi B2 tidak memperbaikinya.

      Loop unggah berpotongan kini ada di **tiga** layanan Flutter. No. 10
      sudah mencatat dua yang pertama layak disatukan; hutang ini bertambah
      dengan sadar, karena menyatukan sambil menambah pemakai ketiga akan
      mencampur dua perubahan dalam satu rangkaian commit.

      Kendalanya sudah diukur, bukan diduga: `post_max_size` PHP adalah **8M**,
      dan satu POST multipart 25 MB ditolak **HTTP 413** oleh
      `ValidatePostSize` Laravel — diuji langsung terhadap server yang berjalan,
      22 Agustus 2026. Karena itu video memakai unggah berpotongan alih-alih
      satu POST, sehingga tidak ada konfigurasi PHP yang harus disamakan antara
      mesin pengembangan dan VPS.

      Status *pending* tidak butuh migrasi: ia keadaan selama `send()` masih
      menunggu jawaban. "Terkirim" dan "terbaca" sudah bekerja hari ini
      (`messages.read_at`, `message_bubbles.dart:190`).
- [x] **C — Penelusur tumpukan frame, dan unggah dua langkah.** Satu widget
      dipakai di layar unggah dan di hasil/riwayat, menggabungkan frame input
      dan hasil prediksi dengan penanda. Termasuk unggah beberapa `.tif`
      sekaligus yang dibungkus ZIP di sisi klien. Rancangan:
      [docs/superpowers/specs/2026-08-23-c-frame-viewer-design.md](docs/superpowers/specs/2026-08-23-c-frame-viewer-design.md).

      Lebih kecil dari bunyinya: `frames()` sudah menggabungkan input dan
      output, galeri sudah menampilkan gabungan itu (`_generatedOnly` default
      `false`), dan `_FrameViewer` sudah punya pan/zoom serta perpindahan
      frame. Yang benar-benar baru cuma slider, tick penanda, badge, dan
      pengangkatannya jadi widget bersama.

      Yang **tidak** kecil: unggah dipecah dari analisis, dengan status baru
      `uploaded` sebelum `pending`, supaya preview bisa muncul sebelum
      pekerjaan diantrikan. Itu menyentuh `PredictionIntake` — satu-satunya
      jalur yang pernah dibuktikan ujung-ke-ujung terhadap GPU sungguhan (no. 2
      di "Sudah selesai").

      **Kode selesai 23 Agustus 2026, dan sengaja belum dicentang.** Backend
      274 test (dari 270), Flutter 162 test (dari 153), `flutter analyze`
      bersih.

      **Dua hal yang menahan centangnya:**

      - **Belum ada satu prediksi pun terhadap GPU sungguhan sejak pipeline
        dipecah.** Suite yang hijau tidak membuktikan jalurnya masih utuh;
        hanya satu run nyata yang bisa. Menunggu sesi Kaggle dinyalakan.
      - **Belum ada pemeriksaan mata di perangkat.** Yang **sudah** dibuktikan
        23 Agustus 2026: APK release 60,9 MB terpasang ke `SM A325F` dan
        **berjalan tanpa crash** — proses hidup, tidak ada `FATAL EXCEPTION`
        di logcat. Itu membuktikan build-nya benar, bukan alurnya.

        Yang masih menuntut mata dan jari: unggah beberapa `.tif` sekaligus,
        geser slider dengan jari, cubit untuk memperbesar, START ANALYSIS,
        lalu geser lagi hasilnya dan pastikan tick menandai frame sisipan —
        ditambah semua yang tertunda sejak bagian A, terutama **mengirim pesan
        dengan backend dimatikan**: gelembungnya harus merah dan teksnya harus
        kembali ke kolom ketik.
- [x] **D — Training periset.** Tab Training sisi admin dihapus; tab sisi
      periset dikembangkan dengan unggah, viewer dari C, metrik PSNR/SSIM/
      MAE/MSE, dan gambar contoh per epoch yang bisa digeser. Rancangan:
      [docs/superpowers/specs/2026-08-23-d-researcher-training-design.md](docs/superpowers/specs/2026-08-23-d-researcher-training-design.md).

      Menghapus tab admin **tidak** berarti membuang kemampuannya. Layar itu
      memegang `_registerModel()` — satu-satunya cara bobot hasil training jadi
      model yang bisa dipakai — beserta penghapusan dataset dan job, yang juga
      satu-satunya rem terhadap disk penuh (lihat no. 11). Ketiganya pindah ke
      Model Management, tempat model memang hidup. Yang benar-benar dicabut
      cuma `dispatch`, karena job antre diklaim worker sendiri.

      `script-api-train-deepct.py` ikut diubah: SSIM dan MSE ditambahkan di
      samping PSNR, dan `loss` diberi nama kedua `mae` — ia memang
      `tf.reduce_mean(tf.abs(...))`, yaitu MAE menurut definisi. `loss` tetap
      dikirim supaya job lama tidak kehilangan grafiknya.

      **Kode selesai 23 Agustus 2026, dan sengaja belum dicentang.** Backend
      272 test, Flutter 168 test (dari 162), `flutter analyze` bersih. Jumlah
      backend turun dari 281 karena sembilan test dispatch dihapus bersama
      rutenya, bukan karena ada yang rusak.

      **Tidak satu pun dari bagian D pernah bertemu GPU.** Jalur training belum
      pernah dijalankan sekali pun terhadap perangkat keras sungguhan (no. 10),
      dan D menambahkan tiga hal baru di atasnya: metrik, endpoint sampel, dan
      tabel `training_samples`. Perubahan pada `script-api-train-deepct.py`
      hanya lolos `python -m py_compile` — itu membuktikan berkasnya terurai,
      bukan bahwa `tf.image.ssim` dipanggil dengan benar.

      **Yang dibutuhkan untuk mencentangnya:** sesi Kaggle menjalankan
      `script-api-train-deepct.py` **versi baru**, sebuah dataset, dan satu
      training yang berjalan sampai selesai. Yang harus terlihat: empat metrik
      di tabel per epoch, dan gambar contoh yang bisa digeser dari epoch
      pertama sampai terakhir.

      Berbeda dari prediksi, ini tidak bisa dikerjakan dalam hitungan menit —
      training memakan berjam-jam.

- [x] **E — Preview dataset training** — selesai dan terbukti, 23 Agustus 2026.
      Backend 279 test (dari 272), Flutter 174 test, `flutter analyze` bersih.

      Menutup separuh poin 10 yang terlewat saat D dirancang: unggah dataset
      punya preview seperti unggah prediksi.
      Rancangan:
      [docs/superpowers/specs/2026-08-23-e-dataset-preview-design.md](docs/superpowers/specs/2026-08-23-e-dataset-preview-design.md).

      Audit 23 Agustus menemukan tiga dari empat tempat preview sudah ada;
      yang ini tidak. Bukan permintaan baru — kalimat aslinya meminta dua
      preview di tab training, dan D hanya membangun yang kedua.

      Jauh lebih kecil dari C: dataset duduk sebagai job `queued` sampai ada
      worker yang mengklaimnya, jadi jendela untuk melihatnya sudah ada dan
      tidak ada status baru yang perlu ditambahkan. Dibaca langsung dari dalam
      ZIP lewat `ZipArchive`, tanpa satu byte disk tambahan.

      **Satu-satunya bagian sejak C yang selesai penuh tanpa GPU**, karena ia
      membaca berkas yang sudah ada di disk dan merender dengan kode yang sudah
      diuji. Yang tetap belum dilihat mata: tampilannya di perangkat.

### 13. Perbaikan tambahan

Diajukan 22 Agustus 2026, di luar sepuluh permintaan di no. 12.

- [x] **F — Navigasi swipe di ponsel, dan konfirmasi sebelum keluar** — kode
      selesai 23 Agustus 2026, **gesturnya belum dicoba di perangkat**.
      Flutter 174 test, `flutter analyze` bersih.

      Dua hal yang berhubungan, keduanya soal gestur di perangkat sentuh.
      Rancangan:
      [docs/superpowers/specs/2026-08-23-f-swipe-navigation-design.md](docs/superpowers/specs/2026-08-23-f-swipe-navigation-design.md).

      **Yang pertama:** menggeser jari ke kiri atau kanan tidak melakukan apa
      pun hari ini. Ia seharusnya berpindah antar tab, dan dari tab mana pun
      satu geseran membawa kembali ke Dashboard.

      **Yang kedua, dan ini bug:** di Dashboard, gestur kembali langsung
      melempar pengguna ke landing page **tanpa bertanya apa pun** — yang
      berarti keluar dari konsol karena salah geser, tanpa peringatan. Sudah
      diperiksa: tidak ada `PopScope`, `WillPopScope`, maupun penangan gestur
      sama sekali di `user_shell.dart` atau `admin_shell.dart`, jadi gestur
      kembali Android tidak dicegat oleh apa pun. Di Dashboard ia harus
      memunculkan konfirmasi keluar yang sama dengan tombol Sign out, yang
      sudah ada sebagai `_confirmLogout()` di kedua shell.

      Keduanya menyentuh `user_shell.dart` dan `admin_shell.dart`, dan
      keduanya hanya bisa dibuktikan di perangkat sentuh sungguhan — test
      widget tidak menjangkau gestur tepi layar.

      **Yang masih harus dilihat di perangkat:** apakah gestur tepi layar
      Android sungguhan sampai ke `PopScope`, dan apakah `SelectionArea` dari
      bagian A masih bisa menyeleksi teks di sebelah `GestureDetector` yang
      baru. Keduanya bekerja pada pohon widget yang sama.

      Test yang ada mengunci apa yang membuat gesturnya mendarat benar ketika
      ia sampai: urutan seksi dengan Dashboard di depan, melangkah yang
      berhenti di ujung, dan tab Training admin yang dihapus di bagian D tetap
      hilang.

- [x] Pipeline prediksi FASE 3 (upload, interpolasi rekursif, unduh, retensi)
- [x] **Pipeline prediksi diuji ujung-ke-ujung di VPS terhadap GPU sungguhan**
      (18 Agustus 2026). Dua frame batas dengan celah 4 — jadi rekursinya
      betul-betul dipakai — menghasilkan 3 frame dalam 27 detik, dan MAE tiap
      hasil terhadap kedua batas naik monoton (002 dekat awal, 003 di tengah,
      004 dekat akhir), jadi urutannya benar dan tidak ada yang disalin.
      **Mutu gambarnya tidak diuji**: masukannya sintetis, di luar distribusi
      latih model. Lihat CHANGELOG 1.19.19, termasuk artefak tepi yang terlihat
      pada frame hasil.
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

Alasannya: notebook di repo ini nol kode training — modelnya generator GAN
**21,9 juta parameter** (21.921.601, dibaca langsung dari `.h5` pada
4 September 2026; angka 25,6 juta yang beredar sebelumnya tidak pernah
diverifikasi) yang **discriminator-nya tidak ada di sini**, dan loss,
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
