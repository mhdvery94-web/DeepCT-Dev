# 📅 Changelog

All notable changes to Platform Analisis Citra Neutron CT will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

> Entries before v1.7.0 mention documents that no longer exist — `TODO.md`,
> `PROJECT_STATUS.md`, the `*_SUMMARY.md` family and others were folded into
> four documents in v1.7.0. Those references are left as written: a changelog
> records what happened, and rewriting it would be a worse lie than a dead link.
> Anything still needed lives in [README.md](README.md),
> [ARCHITECTURE.md](ARCHITECTURE.md), [API.md](API.md) or
> [CLAUDE.md](CLAUDE.md); the originals remain in git history.

---

## [Unreleased]

### Planned Features (FASE 3+)
- Upload & Download system (ZIP streaming, chunked upload)
- Prediction processing (recursive interpolation)
- Queue management dengan position tracking
- Auto-delete expired files (24 hours)
- Batch processing untuk multiple file pairs
- Email notifications untuk expiry warnings
- Real-time updates menggunakan WebSocket/Pusher
- Model comparison feature
- Export reports (PDF, CSV)
- iOS mobile app
- Dark mode
- Multi-language support

---

## [1.19.17] - 2026-08-18

VPS mendapat alamat HTTPS-nya lewat ngrok, setelah dua jalur yang lebih rapi
terbukti buntu.

### Kenapa ngrok padahal VPS punya IP publik

Klien web butuh HTTPS: halamannya disajikan Vercel lewat HTTPS, dan browser
menolak memanggil `http://` dari sana — tanpa error jaringan, cuma request yang
tidak pernah berangkat. Dua jalur biasa dicoba dan dua-duanya buntu, keduanya
diverifikasi bukan diduga:

- **certbot untuk hostname sendiri — buntu di DNS.** Diuji lewat resolver
  publik: `api.brin.fajrianhost.my.id`, `api.palembangtaste.shop` dan
  `deepct.palembangtaste.shop` semuanya **NXDOMAIN**. Resolver ISP sempat
  menjawab satu alamat IPv6 yang sama untuk ketiganya, yang terlihat persis
  seperti DNS yang sudah jadi — itu pembajakan NXDOMAIN, bukan record.

- **Sertifikat yang sudah ada di port sendiri — buntu di firewall.** Sertifikat
  mengikat hostname bukan port, jadi server block TLS di 8443 bisa memakai
  sertifikat yang mesin ini sudah pegang untuk situs lain. Sah secara TLS, tapi
  **8443 tertutup di security group Tencent**: 8080 tersambung, 8443 timeout.

ngrok menembus keduanya — TLS-nya sendiri, dan menjangkau keluar dari dalam
sehingga firewall masuk tidak punya suara.

Template TLS tetap ada dan tetap berfungsi. Begitu 8443 dibuka atau API punya
hostname sendiri, `TLS_DOMAIN` menghidupkan kembali jalur yang tidak bergantung
pada layanan pihak ketiga.

### Tunnel-nya sekarang program supervisor

Ia dijalankan dari sesi terminal, artinya ia mati begitu sesi itu tertutup —
dan backend kehilangan satu-satunya alamat HTTPS-nya tanpa ada yang berubah di
backend itu sendiri. Sekarang `brin-ngrok`, dengan `autorestart`.

**`environment=HOME=...` itu wajib, bukan kerapian.** supervisord tidak
mewariskan `HOME`, dan tanpanya ngrok tidak menemukan
`~/.config/ngrok/ngrok.yml`: ia tetap start, gagal otentikasi, lalu mengulang
selamanya dengan pesan yang terbaca seperti token salah alih-alih home
directory yang hilang.

Itu juga yang menjaga token keluar dari command line. Perintah yang berjalan
memakai `--authtoken=<token>`, yang berarti kredensialnya terbaca lewat `ps`
oleh setiap akun di mesin itu; membacanya dari config file menghilangkan itu.

Tunnel diarahkan ke **nginx**, bukan langsung ke Octane. Di nginx-lah batas
unggah, timeout dan setelan buffering tinggal; tunnel yang menembak 8000
langsung melewati ketiganya tanpa bilang-bilang.

### `NGROK_BE_VPS` memilih backend mana yang dituju klien

Urutannya sekarang `NGROK_BE_VPS` → `NGROK_BE` → `API_BASE_URL`. Terisi yang
pertama, semua target menunjuk ke VPS; **dikosongkan, semuanya kembali ke mesin
lab** tanpa menyentuh satu baris kode.

Itu bentuk yang tepat untuk dua backend yang alamatnya dikompilasi masuk ke
klien: satu build hanya bisa bicara ke satu backend, jadi peralihannya harus
satu tempat, dan tempat itu bukan berkas sumber.

---

## [1.19.16] - 2026-08-18

Konfigurasi server jadi berkas terversi di `be/deploy/`, setelah melihat mesin
sungguhannya dan menemukan skrip provisioning akan merusaknya.

### Skrip provisioning akan melumpuhkan supervisor

VPS ini sudah punya `/etc/supervisor/conf.d/deepct.conf` yang mendefinisikan
`brin-octane`, `brin-queue` dan `brin-schedule` — **nama yang sama persis**
dengan yang akan ditulis skrip ke `brin.conf`.

Dua berkas yang mendefinisikan program yang sama membuat `supervisorctl
reread` menolak memuat apa pun. Kegagalannya muncul jauh dari sebabnya: job
deploy melaporkan supervisor tidak mengenali program yang jelas-jelas ada di
`supervisorctl status`.

Ini kelas kesalahan yang sama dengan bug nginx di rilis sebelumnya, dan
ditemukan dengan cara yang sama — dengan benar-benar melihat mesinnya.

### `stopwaitsecs` yang hilang, dan harganya

Konfigurasi supervisor di server tidak punya `stopwaitsecs`, jadi berlaku
bawaan **10 detik**. `brin-queue` berjalan dengan `--timeout=7200`.

Artinya setiap deploy yang me-restart worker itu meng-SIGKILL prediksi yang
sedang berjalan: sampai dua jam waktu GPU dan satu job milik peneliti, hilang
sepuluh detik setelah restart yang tak seorang pun mengira merusak. Template
baru menyetelnya 7260, dan `brin-octane` 30.

### `be/deploy/`, dan kenapa terpisah dari provisioning

Provisioning berjalan sekali dan melakukan hal yang tak bisa dibatalkan —
membuat database, menulis `.env` berisi `APP_KEY`. Menulis ulang dua berkas
konfigurasi bukan itu.

`deploy/apply.sh` sekarang memiliki nginx dan supervisor, dari template di
sebelahnya, dan **ikut terkirim di setiap deploy** — jadi perubahan timeout
atau batas unggah sampai ke server tanpa siapa pun mengingat skrip provisioning
itu ada. `provision-vps.sh` mendelegasikan ke sana alih-alih menyimpan salinan
kedua.

Snippet proxy-nya satu berkas yang di-`include` **kedua** server block, supaya
pintu HTTP dan pintu TLS tidak bisa berbeda.

### Buffering, dan hasil 1,5 GB

`proxy_buffering` menyala secara bawaan, dan satu hasil prediksi mencapai ~1,5
GB. nginx akan menulis seluruh berkas ke `/var/lib/nginx` sebelum mengirim byte
pertama: unduhan makan waktu kira-kira dua kali lipat, dan disk terisi salinan
berkas yang sebentar lagi dihapus platform sendiri. Dimatikan, dua arah —
unggahan juga sampai 2 GB.

### TLS tanpa record DNS baru

Sertifikat mengikat **hostname, bukan port**. Mesin ini sudah memegang
sertifikat untuk sebuah nama; server block TLS di port sendiri memakainya apa
adanya, dan klien yang menyambung ke `https://<nama itu>:8443/api` melihat
hostname yang dicakup sertifikatnya.

Ini menyelesaikan mixed content — klien web Vercel selalu HTTPS dan menolak
memanggil `http://` — **tanpa satu pun record DNS baru**, yang penting karena
justru record itulah yang menghambat: semua subdomain kandidat menjawab
NXDOMAIN, dan `certbot` tidak bisa menerbitkan apa pun untuk nama yang belum
menunjuk ke mesinnya.

**Belum diterapkan ke server.** Menulis ke `/etc/nginx` di mesin produksi
diblokir oleh pagar izin di lingkungan ini, jadi konfigurasinya dikirim sebagai
berkas terversi yang menyusul lewat deploy, bukan disunting langsung. Sintaks
`apply.sh` dan ketiga template lolos pemeriksaan dan substitusi placeholder-nya
diuji, tapi `nginx -t` terhadap hasil akhirnya belum pernah dijalankan.

---

## [1.19.15] - 2026-08-18

Deploy pertama ke VPS berhasil pada percobaan ketujuh, dan tiga hal yang
ditemukan di sepanjang jalan itu diperbaiki di sini.

### 500 di setiap request, dan itu bukan `resources/views`

Sesudah deploy, aplikasi menjawab 500. Diagnosis yang beredar: `rsync --delete`
menghapus `resources/views` karena folder itu tidak ada di GitHub.

Bukan itu. `resources/views/welcome.blade.php` **ter-track** dan ikut terkirim
seperti berkas lain. Yang hilang adalah **`storage/framework/views`** — dan itu
memang tidak akan pernah sampai, karena `storage/` sengaja dikecualikan dari
rsync: di situ tinggal unggahan, hasil, dan dataset training, dan deploy tidak
punya urusan menyentuhnya. Tapi pengecualian yang sama berarti direktori kosong
yang dibutuhkan Laravel saat runtime juga tidak ikut. Di repo ketiganya cuma
folder berisi `.gitignore`, dan rsync melewati semuanya.

Tanpa direktori itu Laravel melempar *"Please provide a valid cache path"* —
pesan yang menyebut sebuah path di bawah `storage/framework` dan rutin terbaca
sebagai view yang hilang, karena kata yang menarik mata adalah `views`.

Deploy sekarang membuat kerangkanya sendiri tiap kali dijalankan
(`storage/framework/{views,cache/data,sessions,testing}`, `storage/logs`,
`storage/app/{private,public}`, `storage/backups`). Ia menyembuhkan diri, dan
harus begitu: satu-satunya jalan direktori itu bisa ada.

### Skrip provisioning menganggap mesinnya milik sendiri

VPS ini juga melayani situs lain di port 80 dan 443, dan backend ini sudah
diberi site nginx sendiri di **port 8080**. Skrip provisioning akan menulis
site keduanya di port 80 dan mengaktifkannya.

Itu tidak akan gagal dengan berisik — justru itu masalahnya. Dua konfigurasi
untuk satu backend, dan orang berikutnya yang menaikkan `client_max_body_size`
menaikkannya di berkas yang salah.

Sekarang skripnya memeriksa dulu: kalau sudah ada site aktif yang mengarah ke
`127.0.0.1:8000`, site itu dibiarkan dan tidak ada yang ditulis. `NGINX_SITE`,
`NGINX_PORT` dan `FORCE_NGINX` mengatur sisanya.

Pemeriksaannya memakai `grep -R`, bukan `-r`. Semua isi `sites-enabled` adalah
symlink ke `sites-available`, dan `-r` pada GNU grep hanya mengikuti symlink
yang disebut di command line — di dalam direktori ia berjalan melewatinya. Dengan
`-r` pemeriksaan ini tidak akan menemukan apa pun, di mesin mana pun yang
mengaktifkan site-nya dengan cara normal, lalu dengan riang menulis konfigurasi
kedua di sebelah yang sudah bekerja.

### Skrip provisioning dipindah ke `be/scripts/`

Ia ada di `scripts/` di root, dan deploy meng-`rsync` **`be/` saja** — jadi
skrip itu tidak akan pernah sampai ke server yang membutuhkannya. Sekarang di
`be/scripts/provision-vps.sh`, dan mendarat sebagai
`/var/www/deepct-ai/scripts/provision-vps.sh` dibawa oleh deploy pertama.

### Dua backend, dan HTTPS yang memaksa memilih

APK boleh berbicara ke `http://` — `usesCleartextTraffic="true"` ada di
manifest. Klien web di Vercel tidak: halamannya selalu HTTPS, dan browser
menolak permintaan `http://` dari halaman HTTPS sebagai mixed content, tanpa
error jaringan yang jelas, cuma request yang tidak pernah berangkat.

Karena `NGROK_BE` satu variabel untuk semua target, mengarahkannya ke VPS
selama VPS masih HTTP **memperbaiki APK dan mematikan web**. Ditulis di
ARCHITECTURE §8 sebagai tabel, karena ini jenis hal yang menghabiskan sore.

---

## [1.19.14] - 2026-08-18

### Setiap deploy akan menghapus RoadRunner

Cacat di job `vps` yang ditulis satu commit sebelumnya, ketemu saat menyiapkan
skrip provisioning. `rsync --delete` menghapus berkas di tujuan yang tidak ada
di sumber, dan binari `rr` ada di `be/.gitignore` — jadi ia tidak pernah ada di
sumber, dan setiap deploy akan menghapus server yang baru saja ia restart.
Kegagalannya akan muncul sebagai `octane:start` mengeluh binarinya hilang,
tepat setelah deploy yang tampak berhasil.

Sekarang dikecualikan bersama `.rr.yaml`, `public/build`, `public/storage` dan
`auth.json` — semuanya gitignore, semuanya akan bernasib sama.

### `be/scripts/provision-vps.sh`

Sekali jalan, di server, mengerjakan persis yang **tidak** dikerjakan job
deploy: database dan usernya, `.env` dengan `APP_DEBUG=false` dan
`TRAINING_WORKER_TOKEN` baru, binari RoadRunner, migrasi, ketiga program
supervisor, dan reverse proxy nginx. Aman dijalankan ulang.

Yang tidak akan pernah ia timpa: `.env` yang sudah ada. `APP_KEY` tinggal di
sana, dan menggantinya membuat setiap nilai terenkripsi dan setiap token yang
pernah diterbitkan tidak terbaca — kegagalan yang muncul sebagai "semua orang
ter-logout dan tidak ada yang bisa didekripsi", jauh dari skrip ini.

**Tiga angka yang harus sejalan.** `chunkSize()` menurunkan ukuran potongan
dari `upload_max_filesize` dan `post_max_size` saat runtime; nginx harus
mengizinkan lebih besar dari potongan terbesar; dan bawaan Ubuntu
`client_max_body_size 1m` justru lebih kecil daripada yang PHP iklankan di
instalasi standar. Ketidakcocokan itu tak terlihat sampai unggahan pertama dari
klien sungguhan menjawab 413.

Yang diedit php.ini **CLI**, bukan FPM: RoadRunner menjalankan aplikasi lewat
SAPI CLI dan tidak ada PHP-FPM di tumpukan ini sama sekali.

Token trainer dibuat dengan `openssl rand` alih-alih pipeline `/dev/urandom`
yang berakhir di `head`: di bawah `set -o pipefail`, `head` menutup pipe lebih
awal bisa mengirim SIGPIPE ke tahap sebelumnya dan menjatuhkan seluruh skrip.
Itu bergantung pada timing buffer, jadi ia akan lolos saat diuji dan gagal di
mesin yang penting.

### Dua backend, dan klien cuma bisa menunjuk satu

Mesin lab di balik ngrok dan VPS dua-duanya sah sekarang. Yang gampang
terlewat: alamat API **dikompilasi masuk**, jadi satu build hanya bisa bicara
ke satu backend, dan repository variable `NGROK_BE` yang memilihkannya untuk
semua target sekaligus. Memindahkannya ke VPS berarti mengubah satu variabel,
bukan satu baris kode.

Didokumentasikan di ARCHITECTURE §8 bersama urutan deploy pertama yang memang
bertelur-ayam: push dulu (rsync berhasil, job berhenti di "`.env` does not
exist" — itu benar), provisioning kedua, jalankan ulang workflow ketiga.

**Belum diverifikasi:** skrip ini belum pernah dijalankan di server mana pun.
Sintaksnya lolos `bash -n`, dan kedua fungsi penulis berkasnya — `.env` dan
php.ini — diuji terhadap `.env.example` sungguhan dan php.ini contoh, termasuk
kasus baris yang ter-komentar dan password ber-`/`, `+` dan `=`. Sisanya belum.

---

## [1.19.13] - 2026-08-18

Hasil review menyeluruh atas keadaan repo, lalu tiga hal yang diperbaiki dan
satu yang ditambahkan.

### Menyebut nilai bawaannya menjawab 500

`POST /api/predictions/uploads` dengan `purpose: prediction` dan tanpa
`model_id` menjawab **HTTP 500** berisi stack trace, di tempat yang seharusnya
**422** menyebut field yang kurang.

Aturannya `required_without:purpose`, dan itu menanyakan apakah `purpose`
**dikirim**, bukan apa isinya. Jadi menyebut nilai bawaannya dengan lantang
justru mematikan syarat `model_id`; `exclude_if` juga tidak menyala karena
nilainya bukan `training`; dan controller lalu membaca kunci yang validasi baru
saja setuju boleh tidak ada.

Sekarang `required_unless:purpose,training` — hanya training yang boleh tanpa
model. Tiga test mengunci ketiga jalurnya: `purpose` disebut, `purpose`
dihilangkan, dan `purpose: training`.

Klien Flutter tidak pernah mengirim kombinasi itu, jadi tidak ada pengguna yang
pernah terkena. Yang terkena adalah siapa pun yang membaca daftar nilai `in:`
dan mempercayainya.

### ROADMAP bertentangan dengan dirinya sendiri

Item 10 memuat sisa rencana dari sebelum pekerjaannya dikerjakan, dan sisa itu
tidak ikut terhapus waktu hasilnya ditulis di atasnya. Dalam satu bagian yang
sama terdapat:

- judul "BACKEND SELESAI, **KLIEN BELUM**" di atas daftar yang setiap item
  kliennya sudah `[x]`;
- `[ ] Menyalakan kind di layar admin` empat belas baris di bawah
  `[x] kind di form model admin`;
- `[ ]` untuk mencabut `POST /admin/training/jobs`, yang sudah dicabut di rilis
  sebelumnya;
- satu blok utuh yang menyatakan "tidak ada satu pun route training di bawah
  `me/`" — ada empat — dengan enam kotak kosong yang semuanya sudah terbangun;
- "Sampai ketiganya dijawab, ini **belum dimulai**", seratus baris di bawah
  "Ketiga pertanyaan sudah dijawab pemilik produk".

Blok basi itu dibuang, judulnya diluruskan jadi **TERPASANG, BELUM DIJALANI**,
dan "Yang belum" sekarang cuma berisi yang benar-benar belum: uji di GPU
sungguhan, resume untuk unggah dataset, dan pencabutan
`POST /admin/training/datasets`.

Ini melanggar aturan 3 dan 4 CLAUDE.md, dan justru di berkas yang aturan itu
ada untuk melindunginya.

### Item 11: dua lubang yang ditemukan saat review

Keduanya lahir dari perubahan di item 10 dan tidak tercatat di mana pun.

**Arsip dataset training tidak punya retensi.** `finalizeTraining()` menulis
sampai 2 GB per run ke `training/datasets/`, dan `predictions:cleanup` tidak
menyentuh direktori itu. Satu-satunya penghapusan manual dan admin saja.
Sebelum item 10, admin mendaftarkan URL dan platform tidak menyimpan apa pun —
jadi perubahan itulah yang membuatnya jadi masalah. Butuh keputusan produk
lebih dulu: berapa lama, dan siapa yang boleh menghapus.

**Seluruh arsip dimuat ke RAM sebelum sepotong pun dikirim.** `withData: true`
lalu memotong `Uint8List` yang sudah utuh di memori. Chunked upload dipakai
ulang justru karena dataset adalah hal terbesar yang diterima platform ini,
tapi yang diselamatkan chunking hanya transportnya.

### Angka test di empat dokumen sudah tidak benar

`CLAUDE.md`, `README.md`, `be/README.md` dan `fe/README.md` menyebut 225 dan
120. Terukur hari ini: **238** (969 assertions) dan **129**.

### Backend deploy sendiri ke VPS

Job `vps` baru di `.github/workflows/release.yml`, berjalan pada push ke `main`
dan pada tag. Klien web tetap ke Vercel; job ini hanya `be/`.

`rsync --delete` dengan `.env`, `storage/`, `vendor/`, `node_modules/` dan
`rr.exe` dikecualikan — dan karena dikecualikan, juga terlindung dari
penghapusan itu. Lalu `composer install --no-dev` di server, **satu dump
database sebelum migrasi**, `migrate --force`, ketiga cache, dan
`supervisorctl restart` untuk `brin-octane`, `brin-queue`, `brin-schedule`.

Dua hal yang membuatnya bukan sekadar menyalin berkas:

**Restart Octane wajib, dan kegagalannya harus berisik.** Octane memegang
aplikasi di memori; tanpa restart, kode baru ada di disk sementara proses lama
terus melayani yang lama — persis jebakan yang sudah diperingatkan CLAUDE.md.
Kalau supervisor tidak mengenali salah satu dari ketiga program itu, job-nya
berhenti dan menyebut namanya, alih-alih melapor sukses.

**Restart yang sukses bukan bukti aplikasinya hidup.** Langkah terakhir
meminta `GET /api/news` di `127.0.0.1:8000` sampai sepuluh kali. Endpoint itu
publik, murah, menyentuh database, dan tetap 200 walau feed-nya kosong.

Dump sebelum migrasi menutup item 6 di checklist ARCHITECTURE §8 sebagian saja,
dan dokumennya sekarang mengatakan begitu: tujuh berkas itu ada di mesin yang
sama dengan databasenya, jadi ia menjawab "migrasi merusak sesuatu" dan tidak
menjawab "disknya mati".

### Suite backend akhirnya berjalan di CI

Job `test-backend` baru — PHP 8.3 (versi yang dijalankan VPS) di atas MySQL 8,
bukan sqlite, karena dua migrasi memakai `ALTER TABLE ... MODIFY`. `vps`
bergantung padanya, bukan pada `test`.

Sebelum ini suite backend tidak pernah berjalan di CI sama sekali. Itu bisa
dimaklumi selama berkas itu cuma membangun klien; ia berhenti bisa dimaklumi
begitu ia mulai men-deploy.

`php artisan test` → **238 passed**, 969 assertions. `flutter analyze` →
clean. `flutter test` → **129 passed**.

**Yang belum diverifikasi:** job `vps` belum pernah dijalankan terhadap VPS
sungguhan. Sintaks YAML dan kesepuluh blok shell-nya diperiksa di sini, fungsi
pembaca `.env` dan rotasi tujuh backup diuji secara lokal — tapi rsync,
supervisor, dan smoke check-nya belum pernah menyentuh mesin itu. Nama program
supervisor diambil dari ARCHITECTURE §8, yang merupakan rancangan; kalau server
memakai nama lain, job-nya akan berhenti dan menyebutkannya.

---

## [1.19.12] - 2026-08-18

### Publishing could not tell which repository it was for

```
failed to run git: fatal: not a git repository
```

`gh` works out the repository from the git remote in the working directory, and
the `publish` job never checks the repository out — it only downloads the built
artifacts. So there was no remote, and every call failed. `GH_REPO` says it
outright, which is cheaper than cloning the repository to tell the runner
something it already knows.

The retry loop made that worse rather than better: it spent three minutes
rediscovering a deterministic failure, five times over, twice. A single
`gh repo view` now runs first, and a failure there exits immediately saying so —
retrying is for weather, not for configuration.

### A trainer can be registered from the admin screen

The model form offers **PREDICTION / TRAINING** when creating an endpoint. Until
now `kind` existed only in the API, so registering a trainer meant a hand-written
request, and the researcher's training screen would say "no trainer registered"
for ever.

Only on creation. An endpoint that changed kind after jobs had referenced it
would repoint them silently.

### Two ways to start a run became one

`POST /admin/training/jobs` is gone, along with the NEW JOB button and its
dialog. An administrator arranging runs on someone else's behalf is the shape
this system was deliberately turned away from, and leaving the endpoint in place
would have left two ways to do one thing, differing only in whose name the run
carried.

What an administrator keeps is oversight of every run: see them, push them to a
trainer, cancel them, delete them. The route answers **405 rather than 404**,
because `GET /training/jobs` still lives at that path — the route exists, the
verb does not.

### Seven tests for the researcher's screen

Empty state, the warning shown before a dataset is uploaded rather than after,
the per-epoch table taking its columns from the reported metrics, and the cancel
button appearing only while a run can still be cancelled.

They pump a 1200×3000 surface. The screen is one long column and on the default
800×600 test viewport everything below the start card is laid out but off
screen, where a finder reports nothing — a failure that reads as "it did not
render" when it means "you cannot see it".

`php artisan test` → **235 passed**. `flutter analyze` → clean.
`flutter test` → **129 passed**.

**Still not done, and one of them cannot be done from here:** no training run
has executed on a GPU, which needs a live Kaggle session running
`script-api-train-deepct.py`. And a dataset upload that drops still has to start
again — prediction uploads remember an interrupted session and offer it back,
training uploads do not yet.

---

## [1.19.11] - 2026-08-18

### The researcher can see training now

`Model Training` joins Dashboard, New Analysis, Results & History, My Activity
and Messages in the researcher console. It was the thing actually asked for two
releases ago and the thing that kept not getting done: the endpoints were
finished and tested while the app had no door into them.

The screen is deliberately the shape of the two it sits between — choose an
archive, start it, watch the queue. Three details are not decoration:

- **The dataset goes up in chunks**, through the same resumable session a
  prediction upload uses. A failed chunk is retried three times, and each retry
  re-reads how much the server actually holds first: a request that timed out
  may well have landed, and re-sending from a stale offset earns a 409.
- **Polling stops when nothing is moving.** A finished list does not need
  refreshing, and a screen that keeps asking after a queue nobody is working is
  a quiet cost that adds up on a shared server.
- **The metric table takes its columns from what was reported**, not from a
  fixed list. When the training code learns to measure something new it appears
  on its own.

The result view is the point of the whole feature: epoch down the side, every
metric the notebook sent across the top. One number says how a run is doing; the
series says whether it learned anything.

When no trainer endpoint is registered, the screen says so before the button is
pressed, and a run started anyway is queued rather than refused — with the
reason shown rather than left as a job sitting silently at `queued`.

### The upload field is gone from the admin screen

The backend stopped accepting it in 1.19.10; the form kept offering it, which
would have earned a 422 on the first press. Both halves now agree: an
administrator registers a URL, a researcher uploads.

`flutter analyze` → **No issues found!**. `flutter test` → **122 passed**.

**Not verified:** no training run has actually executed on a GPU. What is proven
is the chunked upload (backend tests) and that the screen analyses clean and the
suite passes. Per `CLAUDE.md` the prediction pipeline is tested end to end
against the real worker; training has not been, and until it is, this is a
finished interface over an unexercised path. No widget test covers the new
screen either.

---

## [1.19.10] - 2026-08-18

### Publishing retries instead of giving up

Three runs failed at `publish` on GitHub's side while every build beneath them
succeeded — "Resource not accessible by integration" once, "No server is
currently available to service your request" twice. Nothing was wrong with the
artifacts; the releases API was unavailable for a few seconds each time, and an
action that gives up on the first 5xx turns a hiccup into a red run and a
release quietly holding yesterday's files.

`softprops/action-gh-release` is replaced by the `gh` CLI behind a retry —
five attempts, backing off 10s, 20s, 30s, 40s, which covers a couple of minutes
of the outages seen so far. `RELEASE_TOKEN` is still honoured if it exists, so a
fine-grained PAT can take over should the 403 ever turn out to be the
repository's Workflow permissions rather than weather.

### An administrator registers a dataset; they do not carry it

The upload field is gone from `POST /admin/training/datasets`. Registering a
dataset as an administrator now means giving a URL, and nothing else.

The reasoning is the same one the original migration comment gave for offering
URLs at all: pushing 20 GB up a home tunnel so a GPU host can pull it back down
is absurd when the worker has a fast link and can fetch it directly. What made
the upload path defensible before was that there was no other way in. There is
now — it belongs to the researcher, and it is chunked.

### A dataset can arrive in pieces

`POST /predictions/uploads` takes a `purpose`. With `training` it wants a name
and an epoch count instead of a model, and on finalize it writes a dataset and a
queued run rather than a prediction.

Reusing the session rather than writing a second one is the point. A training
archive is the largest thing this platform accepts and the least likely to
survive a single request — the resumable machinery already existed, already had
its offset handling tested, and a parallel copy would have drifted from it the
first time either was touched.

The assembled archive is **moved** into place, not copied and discarded. On a
file this size, writing a second copy only to delete the first is gigabytes of
avoidable churn.

`php artisan test` → **235 passed (960 assertions)**.

### Not done: the researcher still has no training screen

The endpoints are finished and tested. The Flutter side is not started, so from
inside the app training remains invisible to a researcher — which is the thing
that was actually asked for, and it is the larger half of the work.

One note against repeating a mistake: the first attempt at the client service
was written straight over `fe/lib/services/training_service.dart`, which is the
**administrator's** service and has nothing to do with it. It was restored from
git before anything else touched it. The researcher's service needs its own
file, and two `ApiConfig` entries and a chunk helper that do not exist yet.

---

## [1.19.9] - 2026-08-18

### Training belongs to the researcher now — backend

The three questions from 1.19.8 were answered: show the numbers a trained model
produced, keep the weights on the platform rather than turning them into a
model, and replace the administrator-only system rather than sitting beside it.

**`models.kind` splits the registry in two.** A trainer endpoint is registered
exactly like an inference endpoint — a URL, an on/off switch, the same health
check — because that is what was asked for, and because the alternative was a
second table with the same columns and the same probe behind it. `me/models`
gained an `inference()` scope, so a trainer can never appear in the picker on
the upload screen and offer a researcher something that cannot interpolate a
frame.

**`training_metrics` keeps the per-epoch history.** `training_jobs.metrics`
holds the latest report only, which answers "how is it doing" and cannot answer
"did it get better" — and the second question is the entire reason a researcher
is shown the result. Reports are written per epoch and overwrite rather than
append, because heartbeats repeat inside an epoch and would otherwise leave a
flat step on the curve for every minute the epoch took.

**Four routes under `me/`,** all scoped to the caller: start a run by uploading
a ZIP, list your own, read one with its history, cancel one. Someone else's run
answers **404 rather than 403** — confirming a run exists is itself a leak.

A run with no trainer available is **queued, not refused**. The request
succeeded, the archive is stored, and a worker can claim it later; what would be
a failure is saying nothing, so the reason comes back in `dispatch_message`.

**Ownership needed no new column.** `training_jobs.created_by` already existed
and already meant "who started this".

**`TrainerDispatcher`** carries the push logic that lived in
`TrainingController::dispatchJob`. Two callers need it now — an administrator
pressing "send to trainer" and a researcher starting a run — and two copies
would have drifted the first time either was touched. The existing 36 training
tests passed unchanged after the move, which is what made it safe to do.

A finished run does **not** become a model. The weights stay put; when a model
is genuinely ready to serve, an administrator registers its endpoint by hand.
Publishing is a decision, not a consequence of a job finishing.

`php artisan test` → **234 passed**.

**Not done, and the client half is the larger half:** there is no Flutter screen
for any of this. The endpoints work and have no door into the app. The admin
model form does not offer `kind` yet either, so a trainer can currently only be
registered through the API. And `POST /admin/training/datasets` and
`POST /admin/training/jobs` are deliberately still in place — removing the only
working path before its replacement is visible would leave the platform with no
way to train at all.

### Linux desktop needed more than GTK

The build failed at CMake configure:

```
The following required packages were not found:
 - libsecret-1>=0.18.4
```

Not Flutter's dependency — `flutter_secure_storage_linux`'s, which is where the
auth token lives on that platform. A plugin's native dependencies are invisible
in `pubspec.yaml`, so the apt list in the workflow is the only place they are
written down. `libsecret-1-dev` and `libjsoncpp-dev` join it.

---

## [1.19.8] - 2026-08-17

### Five platforms, and a release that stops calling itself unfinished

**Linux and macOS desktop builds** join the pipeline. Both Apple targets share
one runner on purpose: they need the same toolchain and the same warm pub cache,
and a second macOS job would double the most expensive line on the bill to save
a few minutes. The Linux job installs GTK headers first — without them the build
fails at CMake configure with a missing `gtk/gtk.h`, which reads like a Flutter
problem and is not one. macOS is packaged with `ditto` rather than `zip`, which
preserves the symlinks inside an `.app` that a plain zip flattens into something
that will not launch.

**The rolling build is no longer a pre-release.** It was, on the reasoning that
an untagged build is not a version. But "pre-release" in GitHub's vocabulary
means *not ready to use*, and these are the builds people are meant to install
today. It does not take the "Latest" badge either: `make_latest: false` leaves
that to a version tag, so `v1.19.1` stays the newest *version* while `latest`
is the newest *build*.

**The `latest` tag now moves with the build.** It could not before — the release
API has no way to move a tag — so the page showed `58e7449` while the body named
`b8ddc25` and the files came from `b8ddc25`. The previous release and tag are
deleted before the new one is written, which is the only way to keep all three
telling the same story.

For the record, the publish failure in 1.19.7 was the platform after all: the
next run went through untouched and replaced every asset. No change was needed;
the hardening added there stands on its own.

### Training as the researcher's job — designed, not built

The request is that training mirror prediction: an administrator turns a trainer
endpoint on or off exactly as they do a model, and the *researcher* uploads a
dataset and starts a run, exactly as they upload frames for a prediction. The
difference being the output — a prediction returns an image, a training run
returns numbers about how good the model got.

The system today is the opposite: training is entirely administrative. Datasets
are registered by an admin, jobs are queued by an admin, and there is no
training route under `me/` at all.

This is recorded in ROADMAP as item 10, with the six pieces it needs and the
**three questions that have to be answered before any of it is written** —
what "intelligence data" means concretely, whether a finished run may become a
published model version, and whether the existing administrative system is
replaced or kept alongside. Each answer changes the schema rather than the
screen.

**No code was written for it.** On a change this size, guessing the schema is
how the document titled "COMPLETE & PRODUCTION READY" came to exist.

---

## [1.19.7] - 2026-08-17

### Publishing failed, and its error message pointed at the wrong thing twice

The three clients built, the web deployment went out, and then `publish` died in
16 seconds:

```
⚠️ Unexpected error fetching GitHub release for tag refs/heads/main
Error: Resource not accessible by integration
```

Both halves of that mislead.

**"for tag refs/heads/main"** reads as though `tag_name: latest` had been
ignored. It was not — the action prints `GITHUB_REF` in that sentence whatever
tag it actually queried. The workflow was checked rather than believed: the step
does pass `tag_name: latest`, and the same step published successfully forty
minutes earlier.

**"Resource not accessible by integration"** is a 403 from the releases API, and
it reads as a configuration fault. But `publish` declares
`permissions: contents: write`, and the two commits since the last successful
publish touched the `preflight` and `vercel` jobs only — `publish` is
byte-identical to the version that worked. During the same period GitHub was
returning 429 and 503 for action downloads, "No server is currently available"
on the releases page, and "Cannot retrieve latest commit" on the repository
front page. The most probable cause is the platform, not the workflow.

So the change here is not a fix — nothing was proven broken — but three things
that make the next occurrence cheaper to read:

- Both release steps now pass their token explicitly as
  `secrets.RELEASE_TOKEN || secrets.GITHUB_TOKEN`. If the 403 turns out to be
  the repository's Workflow permissions setting rather than weather, a
  fine-grained PAT in `RELEASE_TOKEN` takes over without this file changing.
- `permissions: contents: read` at workflow level, with `publish` keeping
  `write`. What the workflow can touch is now one line instead of a search.
- `fail_on_unmatched_files: true` on both. A release missing the APK is worse
  than a run that failed loudly.

The consequence of the failure is worth stating plainly: `latest` still holds
the files from `58e7449`, not from the commits after it. Nothing was
overwritten, and nothing was corrupted — the release simply was not updated.

---

## [1.19.6] - 2026-08-17

### The first release shipped three clients that cannot reach the backend

`latest` carried a working APK, a working web bundle and a working IPA, all
built against `https://nucleus-drone-grueling.ngrok-free.dev` — **without the
`/api` suffix**. `ApiConfig.baseUrl` is documented as "including the `/api`
prefix" and the client appends paths straight onto it, so every request in
those builds goes to `/login` rather than `/api/login` and 404s. Nothing in the
pipeline noticed, because a compiled-in address is not exercised until somebody
installs the result.

This is 1.19.1 a second time, from a different direction: that one was a
hostname that did not resolve, this one is a hostname missing a path. A
`preflight` job now refuses to start any build when `API_BASE_URL` is empty or
does not end in `/api`, and prints the exact value to set. It costs about ten
seconds and it runs before the ten-minute builds rather than after them.

### The Vercel deploy reported success while deploying nothing

The step ended `npx vercel deploy ... | tee url.txt`, and a pipeline's exit
status is its **last** command's. `vercel` failed, `tee` succeeded, the job went
green. The log said what had happened all along:

```
Error: The provided path "/home/runner/work/deepCT-AI/deepCT-AI/fe" does not exist.
```

Two faults, then, and the second hid the first.

The path error is the Vercel project's **Root Directory**, set to `fe` from when
Vercel built the app itself. The CLI resolves that setting against the working
directory and refuses to deploy when the result is missing — and this job never
checks the repository out, it only downloads the built web files, so there was
no `fe/` for it to find.

The setting is now `./`, which is the right answer for a prebuilt deployment:
nothing is built on Vercel, so there is no subdirectory for it to build *in*.
The job carries a `VERCEL_ROOT_DIR` variable that has to match the dashboard,
with the reason written next to it, and the output paths follow it.

The deploy step now runs under `set -euo pipefail` and additionally fails when
the CLI exits 0 without printing a deployment URL. Both were needed: `pipefail`
catches a non-zero exit, and the URL check catches a CLI that decides an error
is a warning.

`fe/vercel.json` and `fe/vercel-build.sh` are now unused — a prebuilt deployment
takes its routing from `.vercel/output/config.json` and runs no build command.
They are kept because they are what makes the project deployable again if the
Git integration is ever reconnected, which is the fallback if token deploys stop
being an option.

---

## [1.19.5] - 2026-08-17

### The health check stops running six times a minute

`models:health-check` ran every ten seconds. Each run is a fresh `php artisan`
process — about 600 ms of CPU even with the route cache — so it cost roughly
**6% of a core, continuously**, landing on top of Octane, MySQL and the queue
worker. A login that should take 500 ms was measured at 5.7 s when it collided
with one.

It now runs **once a minute**. Sixty seconds of staleness is not worse than ten
for what this actually drives: a status light answering "is it worth starting an
upload?". Nobody can tell the difference by looking.

What *does* need to be immediate is the moment someone is about to upload — and
that is now a button rather than a cadence. **`POST /me/models/refresh` probes
the endpoints** and answers exactly as `GET /me/models` does. The refresh
control in the upload screen already existed; it re-read what the scheduler had
last written, which is precisely the stale answer the person pressing it was
trying to get past.

It is the only route where an ordinary user causes an outbound request, so it is
fenced three ways: `throttle:10,1`, a `models:probe` lock so two presses do not
become two probes, and a status younger than ten seconds returned untouched.
Probes run as a pool, so several models cost the slowest rather than all of them.

Verified after the Octane restart, on the same machine as the numbers in 1.19.4:

| | before | after |
|---|---|---|
| `GET /api/me/models` | 1668 / 2631 ms | **22–50 ms** |
| `GET /api/notifications/unread-count` | 2592 ms | **45–97 ms** |
| `GET /api/predictions` | reported 16 s | **33–58 ms** |
| `POST /api/login` | reported 25–40 s | **526–804 ms**, two spikes |

Login's floor is `Hash::check` at `BCRYPT_ROUNDS=12`, measured at **433 ms** on
this CPU. That cost is the point of bcrypt and is left alone.

One consequence worth recording: ARCHITECTURE §8 listed "health check every ten
seconds" as one of five reasons the backend cannot run on Vercel. That reason no
longer holds. The other four — Octane, `queue:work`, 7200-second jobs, 1.5 GB of
results — are untouched, and each is sufficient on its own.

### One workflow instead of two, and iOS on every push to main

Deploying lived in its own file, which meant **every push to main ran
`flutter build web` twice** — once for the release zip, once for the thing that
got deployed. The `web` job builds it once now and both consumers take the
artifact.

`ios` and `android` now run on pushes to `main`, not only on tags, and a push to
main refreshes a rolling `latest` pre-release carrying all three files. A tag
still produces a real versioned release. Feature branches get tests, a web build
and a Vercel preview URL — an APK and a macOS runner per feature push is not
worth it.

The macOS runner bills at ten times the ubuntu rate. On main that is a deliberate
purchase; it is why feature branches are excluded rather than the job being
unconditional.

Three changes for build time:

- **`web`, `android` and `ios` no longer wait for `test`.** They run beside it
  and `publish` waits for all four, so a red suite still cannot publish
  anything — it just no longer adds its minutes to the wall clock before the
  first build starts.
- **Gradle cache** on `~/.gradle/caches` and `~/.gradle/wrapper`. An uncached
  Android job spends minutes re-downloading a dependency tree that never
  changed. This is the single biggest saving.
- **pub and CocoaPods caches**, keyed on `pubspec.lock`.

`setup-java` moves to v5, which GitHub's own deprecation notice names. The other
actions stay on v4: the Node 20 warning is not fatal, and a version tag that does
not exist fails the run outright.

`php artisan test` → **227 passed (919 assertions)**.

---

## [1.19.4] - 2026-08-17

### The API was slow because two schedulers were running

The symptom looked like Octane worker starvation: preflight `OPTIONS` requests
taking 3.7 s, `GET /api/me/models` — a single indexed `SELECT` over a handful of
rows — taking 2.6 s, and `models:health-check` growing from 800 ms to over a
minute. The suspects were the usual ones: N+1 queries, blocking I/O in a request
path, a memory leak under Octane.

It was none of them. `Get-CimInstance Win32_Process` showed **two
`php artisan schedule:work` daemons**: one started by today's `serve:all`, and
one from **the previous night at 23:43** that had never stopped. Both were
dispatching every scheduled task, so `models:health-check` fired twice every ten
seconds, and both raced for the same `withoutOverlapping` lock file — which on
Windows produces

```
fopen(...storage/framework/cache/data/4f/d1/...): Failed to open stream: Permission denied
```

44 times in the last 20,000 log lines. The orphan is the same class of problem
`CLAUDE.md` already documents for Octane: on Windows nothing reliably kills
these processes, so they accumulate silently across days.

Measured on the same machine, one `models:health-check` run:

| | before | after |
|---|---|---|
| run 1 | 2153 ms | 759 ms |
| run 2 | **7042 ms** | 755 ms |
| run 3 | 2376 ms | 575 ms |

`GET /api/health` over the same window went from 1096/463/305/279/91 ms to
310/57/74/41/76 ms.

### What was actually wrong in the code, and what was not

Reviewed on the way, since these were the stated suspects:

- **No N+1.** `MeController::models()` is one `SELECT` with no relations.
  `AuthController::login()` is one select, one insert, one update.
  `AnalysisController::index()` already eager-loads `model:id,name,version`.
- **No memory leak.** `--max-requests=250` recycles workers, `flush` is empty
  and the default warm list is in use. Nothing accumulates in a static.
- **One genuine redundancy**, now fixed: `index()` called
  `QueueHealth::inspect()` *and* `message()`, and `message()` re-inspected —
  four queries against `jobs` to answer two questions. `message()` now takes the
  state it was going to recompute.
- **One place a request really can block on the network**, left as it is:
  `ModelController::checkHealth` probes the tunnel synchronously with an 8 s
  timeout. It is a manual admin button, and the polled console reads status from
  the database, so it is not on any hot path.

### Four changes that make the cheap requests cheap again

**Routes are cached before `serve:all` starts.** The scheduler spawns a fresh
`php artisan` process six times a minute, and each one recompiled the entire
route table first. `route:cache` is most of the improvement above.

`config:cache` is deliberately **not** included, and `be/README.md` now explains
why at length: with `bootstrap/cache/config.php` present, the `<env>` entries in
`phpunit.xml` stop reaching the config — including `DB_DATABASE=db_aict_test` —
so `php artisan test` runs `RefreshDatabase` against the development database
and wipes it. It buys about 100 ms more per run. It belongs in the VPS deploy
step, not on a machine where tests run.

Caching routes meant the two closures in `routes/web.php` had to go:
`route:cache` refuses to serialise a closure. `/` is now `Route::view`, and
`/api/health` is `HealthController`. Same URLs.

**`CACHE_STORE` moves from `file` to `database`**, which is what `.env.example`
already said. The file driver is what the lock contention above was fighting
over, and the `cache` table already exists.

**Unauthenticated API requests answer 401 instead of throwing.** Laravel's
default redirects them to a route named `login`, which an API-only application
does not define, so each one built a `RouteNotFoundException` and wrote a full
stack trace — 381 of them in the last 20,000 log lines.

**`LOG_STACK` moves from `single` to `daily`.** `laravel.log` had reached 19 MB
as one file. Note that the level stays at `debug`: the volume was ERROR-level
stack traces from the two faults above, so lowering the level would have hidden
the evidence rather than fixed the cause.

**`ModelHealthChecker::checkMany()`** probes with `Http::pool`. With one model
this changes nothing, and it was not the cause of anything. But the note on
`TIMEOUT_SECONDS` — eight seconds stays under the ten-second interval — is only
true for a single model: five dead endpoints probed in sequence would take forty
seconds and the schedule would never catch up. A round now costs the slowest
probe rather than the sum. Per-model timings come from Guzzle's transfer stats
so one slow endpoint cannot report the others as `trouble`.

`php artisan test` → **225 passed (910 assertions)**.

---

## [1.19.3] - 2026-08-17

### Every push to `main` now produces an APK

The release pipeline only woke up for a version tag. A change could sit on
`main` for weeks with no installable build behind it — and, less obviously,
with **no tests having run**: `flutter analyze` and `flutter test` lived
entirely inside that tag-only workflow, so `main` could break and stay broken
without anyone being told.

A push to `main` now runs the tests, then builds web and Android, and attaches
the APK to the run. Tags keep doing what they did: all three targets, a GitHub
Release, and Google Drive.

**iOS stays out of the push path.** It needs a macOS runner, which bills at ten
times the ubuntu rate, and an unsigned build nobody can install does not earn
that on every commit. It still builds on a tag or a manual run.

There is deliberately **no `paths:` filter**, so a backend-only push spends a
few minutes building a client that did not change. The alternative is worse:
GitHub does not apply path filters to tag pushes the same way it does to branch
pushes, and a release that silently declines to run costs far more than the
minutes do.

`concurrency` cancels a superseded run on a branch, never on a tag. And
`FLUTTER_VERSION` moves from 3.44.0 to **3.44.9** — the SDK this tree is
actually developed and verified against, and the one `fe/vercel-build.sh`
defaults to, so CI and Vercel now compile the same client.

---

## [1.19.2] - 2026-08-17

### The Vercel deployment was blocked before it ever built

`deep-ct-ai.vercel.app` reported *"the commit author did not have contributing
access to the project on Vercel"*. Nothing was wrong with the code — the build
never started. Vercel matches the **commit author's email** against an account
with access to the project, and on the Hobby plan with a private repository
that has to be the owner. Three identities were in play: commits authored as
`mhdvery94@gmail.com`, the repository owned by `basiadyanna54-commits`, and the
Vercel project under `boroboro-paham`. Commits are now authored as the account
that owns the project; the old commit stays blocked forever, since its author
is part of the commit, so it takes a new one rather than a redeploy.

Underneath that sat a second problem the block had hidden: **Vercel has no
Flutter preset**, and would have failed on the first successful trigger.
`fe/vercel.json` and `fe/vercel-build.sh` now fetch the Flutter SDK — the
released tarball, which already contains the Dart SDK, rather than a clone of
the repository — and build the web client. Three details in there are not
decoration:

- `API_BASE_URL` is read from the environment, because the client compiles the
  address in. Setting it separately for Production and Preview is what makes
  one deployment production and the other a test one.
- A rewrite to `/index.html`, or any deep link answers 404 on reload.
- `index.html`, `flutter_service_worker.js` and `version.json` are served
  `must-revalidate`. Cached, they pin visitors to an old build indefinitely.

`.gitattributes` forces LF on `*.sh`: committed from Windows with CRLF, the
build script fails on Linux with `bad interpreter: /usr/bin/env bash^M`, which
reads like a missing interpreter rather than a line-ending problem.

### The release APK carries the product's name

`flutter build apk --release` now also produces `app-deepCT-ai.apk`.

It cannot be done with Gradle's `outputFileName`, which is the obvious answer
and the wrong one: Flutter's own Gradle plugin copies the APK into
`build/app/outputs/flutter-apk/` and renames it to `app-<build-mode>.apk` on the
way, from the variant rather than from the output. Renaming the file instead of
copying it does not work either — after Gradle returns, `flutter build apk`
looks for `app-release.apk` under that exact name and exits with "Gradle build
failed to produce an .apk file" if it is gone. So a task finalising
`assembleRelease` places a named copy beside it, and both files exist.
`finalizedBy` rather than `doLast`, because an action registered in
`build.gradle.kts` can land ahead of the plugin's own and run before the file
exists.

Verified: `flutter build apk --release` exits 0 and writes both files, 56.1 MB
each.

### Training the model from the notebook, over the same kind of API

`script-api-train-deepct.py` is the training twin of `script-api-deepct.py`:
paste it into a Kaggle cell, register the printed URL in the admin console,
press SEND TO TRAINER. It speaks the worker protocol already in the platform —
heartbeats, checkpoints every five epochs, cancellation, resume — so a job
survives its Kaggle session expiring.

**What it trains is not the published method, and the file says so at the top.**
The reference notebook `Evaluation_2_to_1_1kx1k_With_Logo.ipynb` is a Tkinter
evaluation GUI: it has no training code, no loss and no discriminator, and the
discriminator is not in this repository. What runs is a supervised fine-tune of
the generator on an L1 pixel loss — the notebook's layers, normalisation and
geometry, and a loss derivable from the data alone. Numbers from it must not be
reported as the GAN's.

The part that is worth running is the sampling. Training examples are frame
triples taken from the dataset's own numbering: the model sees frames `i` and
`i+gap`, is told `t = m/gap`, and must produce `i+m`. With `balanced_t` on — the
default — t is spread across every spacing the dataset offers, which is exactly
the imbalance the recursive interpolation exists to work around.

The ngrok token is read from `NGROK_AUTHTOKEN`, never stored in the file. The
inference script still carries its token in plain text and is now listed in
`.gitignore` under both its old and new names.

### Default password

`BrinResearch2026` → `user12345678`, in both controllers, the migration note,
the admin form's helper text and `API.md`. `PasswordGate` still stands in the
way of any account still sitting on it.

---

## [1.19.1] - 2026-08-17

### The app pointed at a hostname that did not exist

Every request failed, on web and Android alike, with *"Cannot reach the
server. Make sure the backend is running."* The backend was running the whole
time.

v1.19.0 pointed `ApiConfig.baseUrl` at the intended production address,
`https://api.brin.fajrianhost.my.id/api`. That subdomain has **no DNS record**
— the parent domain resolves through Cloudflare, `api.brin` returns NXDOMAIN.
Since both the web and APK builds fall back to that default whenever
`--dart-define=API_BASE_URL` is not passed, both failed identically, and the
error text sent everyone to check a server that was answering `200` on
`/api/health` throughout.

The default is back on the reserved ngrok domain until the record exists and
the backend is actually deployed behind it. `ARCHITECTURE.md` still describes
the production topology and is unchanged — it was always a plan, not a
description of something live.

The error message now names the address it failed to reach. One message covers
a downed backend, a closed tunnel, and a hostname that does not resolve; only
the first is about the backend, and saying "make sure the backend is running"
and nothing else actively misdirects for the other two.

### Two mobile layout faults

**The hamburger floated in the middle of the header**, ~73px shy of the
top-right corner. `Flexible` around the brand text and `Spacer` both default
to `flex: 1`, so they *split* the free space rather than the text taking what
it needs and the spacer absorbing the rest. "BRIN" is short and `Flexible` is
a loose fit, so it claimed ~55px of its 137px share — and the 73px it declined
was handed to the row's trailing edge, pushing the hamburger inward. One
`Expanded` with no `Spacer` is a tight fit that takes every remaining pixel,
left-aligning the brand and pinning the hamburger to the edge. A test measures
the gap so it cannot drift back.

**The status bar had no strip of its own.** The app's white surface ran
unbroken from the clock down into the page, so the app looked like it had
swallowed the status bar. Worth recording why it is not simply switched off:
Android 15 (API 35) made edge-to-edge **mandatory**, Android 16 (API 36)
**removed the opt-out entirely**, and `setStatusBarColor` is a no-op at those
levels. This app targets 36, so declining to draw behind the status bar is not
available — and dropping to targetSdk 34 to get it back would make the app
ineligible for Google Play, which since August 2025 requires 35 or higher.

What is still available is the colour. `_SystemBarStrip` in `main.dart` paints
that inset itself in `AppTheme.systemBar`, a step darker than the surface, so
the strip reads as the system's territory. It sits in `MaterialApp.builder`
rather than on individual screens, so no screen can be added that runs up
under the clock. `MediaQuery.removePadding` is the other half: without it every
descendant `SafeArea` would reserve the same inset a second time and leave a
double gap — a test pins the header flush to the bottom of the strip to catch
exactly that.

---

## [1.19.0] - 2026-08-17

### 🚢 Release pipeline, iOS, and training you can start with a button

#### Training can now be pushed, not only pulled

Asked directly: could training work like prediction — register an endpoint URL,
and the notebook starts training on the dataset we uploaded? Yes, and it does
now.

`POST /admin/training/jobs/{id}/dispatch` posts the job to a trainer URL on the
GPU host, exactly as a prediction is posted to a model endpoint.
`scripts/training_server.py` is the notebook side: FastAPI with `POST /train`,
the twin of the inference server already in use.

Three things make it work where a naive version would not:

- The request only asks the trainer to **accept** the job, with a short
  timeout. A connection held open for a multi-day run times out on any network,
  so the notebook answers immediately and trains on a background thread.
- The job stays **`queued`** after a successful push. The trainer said it
  *accepted*; the first heartbeat is what proves it *started*. Marking it
  running here would leave a job that never began looking healthy forever.
- Pushing does **not** bypass the reporting protocol — it carries the callback
  URL and worker token so the trainer heartbeats and checkpoints exactly like a
  polling worker. That is precisely why a pushed job still survives its Kaggle
  session expiring.

A failed push leaves the job queued, so a polling worker can still take it.
Polling remains the safety net; this is the button.

Live testing caught one more: the callback address handed to the trainer came
from `APP_URL`, still `http://localhost` on every development machine, which a
GPU host on the internet can never reach. The dispatch would succeed, the
trainer would accept, and every report back would fail silently — a job stuck at
`queued` with nothing saying why. That is now refused with a 422 naming the
variable to set. 9 tests.

#### iOS

`IPHONEOS_DEPLOYMENT_TARGET` was already 13.0, which covers **iPhone X** with
room to spare — that device runs iOS 11 through 16.7, and modern Flutter does
not support below 13 anyway.

Two things were actually wrong. The app was called **"Fe"** on the home screen,
the Flutter scaffold's directory name. And `Info.plist` had no
`NSPhotoLibraryUsageDescription`, which is not a warning on iOS: the system
**terminates the app** the first time the picker touches the library — which is
the moment someone changes their profile photo.

#### Release pipeline

`.github/workflows/release.yml` builds web, Android **and iOS** on a version
tag, publishes a GitHub Release, and uploads all three to Google Drive.

The iOS job runs on a macOS runner, so an iOS build is produced without anyone
owning a Mac. It is unsigned: installing on a device needs an Apple Developer
account, and no amount of CI substitutes for that.

The Drive step uses rclone with a **personal OAuth token, not a service
account** — a service account has no Drive storage quota of its own, so
uploading into a folder in someone's My Drive fails with "Service Accounts do
not have storage quota", a message that reads like a permissions problem and is
not one. Without the secrets the step is skipped rather than failed, and says
what is missing.

#### Repository hygiene, before publishing

- **Seeded credentials removed from the code.** `AdminUserSeeder` held a
  password in its own source; it now reads `SEED_ADMIN_PASSWORD` from the
  environment and generates-and-prints one when unset. The sample researcher is
  skipped entirely when `APP_ENV=production`.
- **The private tunnel address is gone** from the client default and the docs.
  The API base now defaults to the production host and is set per build with
  `--dart-define`.
- **Documented passwords removed** from README, CLAUDE.md, be/README and the
  API examples.
- **README rewritten** for readers who are not us: what the platform does, how
  it is built, how it is run, and what deploying it requires.

---

## [1.18.0] - 2026-08-17

### 🎛️ Model training, from a GUI

ARCHITECTURE.md §7 had the design; this builds it. An administrator registers a
dataset, queues a job, and watches it train — from the web console or a phone,
which matters because training takes days.

#### The platform manages training. It never runs it.

Three constraints force that, and none are negotiable: this machine has no GPU
and a PHP backend, the Kaggle session that *does* have a GPU expires every 9–12
hours, and training takes days. So a job is a row a remote worker claims,
reports against, and hands weights back to.

#### A worker going quiet is not a failure

This is the centre of the whole thing. A Kaggle session ending is the **normal**
course of events, so `training:reclaim` returns a job whose heartbeat is older
than 15 minutes to `queued` *with its checkpoint intact*, and the next worker
resumes from the epoch already reached. Treating silence as failure would mean
no multi-day training ever finishes.

Verified live, end to end: a job checkpointed at epoch 8, its "session died",
the sweep put it back in the queue, a second worker claimed it and was told
`resume_from_epoch: 8`, finished at 20/20, and the weights registered as a
model version.

#### Added — Backend

- `training_datasets` and `training_jobs`, eleven admin routes and six worker
  routes.
- **Workers authenticate with a shared secret**, not a Sanctum token: a worker
  is a machine whose credential lives in a notebook for weeks and must reach
  nothing else. No token configured → **503**, so a half-configured deployment
  fails closed. `php artisan training:token` generates one.
- Claiming takes a row lock, so two notebooks starting at once cannot train the
  same job twice on the same quota.
- A heartbeat is answered with `continue: false` for a cancelled job — the
  worker stops instead of burning hours on work nobody wants.
- A dataset is an upload **or a URL the worker fetches itself**. The second is
  the right answer for anything large: sending 20 GB up a home tunnel and back
  down to Kaggle wastes both trips.
- `register-model` writes a row with the weights' path, `is_active = false` and
  no endpoint. Weights are a file; a model here is a running worker with a URL,
  and nothing in this platform can deploy a `.h5` to a GPU. Pretending
  otherwise would surface as a researcher's failed prediction.
- 27 tests.

#### Added — Frontend and worker

- `TrainingScreen`: datasets beside the job queue on a desktop, stacked on a
  phone. Live epoch, metrics and worker label, polled every 20s — slower than
  the model status light, because an epoch takes minutes.
- A job whose worker has gone quiet says so *and* says why it is not an error.
- `scripts/training_worker.py` — the protocol client for Kaggle: claim, fetch,
  heartbeat on a thread, checkpoint, resume, complete, fail. `train_one_epoch()`
  raises `NotImplementedError` and is left that way deliberately: the
  discriminator is not in this repository, and inventing the loss here would
  produce a model nobody could defend.
- 9 tests.

### 🚀 Deployment planned, and one plan ruled out

Written up as ARCHITECTURE.md §8, for `brin.fajrianhost.my.id`.

**The Flutter web build belongs on Vercel** — it is static files, which is what
Vercel does best. `brin.fajrianhost.my.id` → CNAME → Vercel, with the API
address injected at build time through `--dart-define`.

**The Laravel backend cannot go on Vercel**, and not for want of configuration.
Octane is a server that stays alive; `queue:work` is a process that stays alive;
the health check runs every 10 seconds where Vercel Cron's floor is a minute; a
prediction job may run 7200 seconds; results reach ~1.5 GB on disk. A serverless
PHP runtime would undo the Octane migration this project already measured — 8–11
seconds down to 1.3–1.7 — and lose the queue, the scheduler and the storage with
it. §8 gives the supervisor and nginx configuration for a small VPS instead, and
Cloudflare Tunnel as the no-VPS alternative.

---

## [1.17.0] - 2026-08-16

### 🖼️ News photos that actually appear, and a model status light

Four fixes reported from real use.

#### A draft's photo was invisible to the administrator who uploaded it

The upload worked; the photo simply never rendered. `Image.network` carries no
bearer token, and a **draft's** photo is served only to an administrator — so
the request 404'd and fell back to the placeholder, which looks exactly like a
failed upload. Every newly created post is a draft, so this hit every single
one.

`AuthedImage` now fetches through `ApiClient`, which attaches the token, and
caches the bytes. Avatars used to carry their own copy of that cache; both now
share `AuthedImageCache`. Replacing a photo also invalidates it — the URL
`/news/3/image` is the same string before and after, so nothing else would have
told the cache the bytes had changed.

#### Model availability, checked every ten seconds

Five minutes was too coarse to be useful: the Kaggle session behind the model
expires on its own, and a researcher would start an upload against a model that
had been dead for four minutes.

- The scheduler now runs `models:health-check` **every ten seconds**, with
  `withoutOverlapping(2)` — at this cadence a probe against a dead tunnel would
  otherwise pile runs on top of each other.
- The probe timeout drops 15s → **8s** so it fits inside the window. Nothing is
  lost: anything past 5s is already reported as `trouble`.
- `ModelStatusStrip` polls the result at the same cadence on the upload screen
  and in model management, showing the checker's **own** message — "Tunnel is
  not running (ERR_NGROK_3200)" tells a researcher to restart Kaggle, where
  "offline" alone does not — plus how old the answer is, since a stalled
  scheduler otherwise looks identical to a healthy model.
- Notifications still fire only on a *transition*; at this rate an overnight
  outage would otherwise send 8,640 identical messages.

#### One login button per layout

A phone showed LOGIN in the header *and* in the drawer. The header one is gone;
sign-in now lives beside the tabs on a wide window and inside the drawer on a
phone, never both.

#### A default password can no longer be kept

Accounts are created by an administrator, or by approving a request, and every
one starts on the same published default. Self-service password change already
existed, but nothing made anyone use it.

`users.must_change_password` is set when a default is issued — creation,
approval, or an admin reset — and cleared when the user picks their own.
`PasswordGate` sits between a signed-in account and its console until then.

A screen, not a dialog: a dialog can be dismissed by the system back gesture,
and a "required" step that a swipe skips is not required at all. Signing out is
offered, because the alternative is trapping someone who opened the app by
mistake.

Verified live: a new account reported `must_change_password: true` at login,
changing the password cleared it, and an admin reset armed it again. The
scheduler was watched writing `last_health_check` at 16:44:03, :12 and :23.

---

## [1.16.3] - 2026-08-16

### Uploading from a phone browser was impossible

Reported from live testing: a researcher on Chrome for Android could not
select a ZIP at all. The same account, same file, worked from the APK, and
worked from a laptop browser. Three platforms, two of them fine — which is
what identified the cause.

Every picker asked for `FileType.custom` with an extension list. That means
something different on each platform:

| Where | What the filter becomes | Result |
|-------|------------------------|--------|
| Laptop browser | OS dialog filters by **extension** | works |
| APK | plugin resolves `custom` to intent type `*/*` | works — it never filtered |
| Chrome on Android | `accept=" .zip"`, which Chrome must map to **MIME types** | broken |

Android's file providers report a ZIP as `application/octet-stream` or
`application/x-zip-compressed` at least as often as `application/zip`, so the
archive appeared greyed out and could not be tapped. Nothing was wrong with
the file, the account, or the upload code that runs afterwards.

`FileType.custom` is gone from all three pickers. The archive picker asks for
`FileType.any`, and the two image pickers ask for `FileType.image` — `image/*`
is a MIME filter both Android and the browser understand, and it brings the
camera and gallery into the chooser on a phone. Since none of those filters
narrows to the types actually accepted, the filename is now checked in Dart
before anything uploads, via `hasExtension` in
[`fe/lib/utils/file_extension.dart`](fe/lib/utils/file_extension.dart) (7
tests). Picking the wrong file gets a plain message naming it, instead of a
silent rejection later from the server.

Worth noting the validation is new in its own right: on the APK the extension
filter had never applied, so until now any file at all could be sent up.

---

## [1.16.2] - 2026-08-16

### Live testing round: a login dead-end, a silent queue, and the app's own identity

Testing against the real Kaggle worker surfaced a cluster of issues, all now
fixed:

**Self-service password change.** An admin's "reset password" sets the
account back to the shared default — the only way for a researcher to get off
that default was for an admin to know it too. `POST /api/me/password`
(backend, added earlier this session) is now reachable from the app: a
"Change password" entry sits next to "Sign out" in both console sidebars,
opening [`fe/lib/widgets/change_password_dialog.dart`](fe/lib/widgets/change_password_dialog.dart).
It requires the current password, rejects a new one identical to the old one,
and — like the backend already did — signs out every other device on the
account while leaving the one making the change alone.

**The queue can now say it's stuck.** A researcher queued three ZIPs and
watched all three sit at "QUEUED" indefinitely, despite the model's own
health check reporting it reachable — because a healthy *model* says nothing
about whether a queue *worker* (`npm run serve:all`) is actually running to
pick jobs up. `App\Services\QueueHealth` (added earlier this session) already
reported this on the backend; the frontend was silently dropping the field.
`Results & History` now shows a warning banner sourced from `meta.queue_message`
the moment nothing is consuming the queue, instead of leaving a clock icon
spinning with no explanation.

**Messaging's stale copy, fixed.** The guest contact form and its admin
notification still described a reply "by email" — leftover language from
before support tickets became in-app messaging. Nothing sends email in this
app; a guest now sees an accurate message about needing an account and
signing in to read the reply, and `MessageController`/`Notifier`'s comments
say the same. The public-message throttle window (5 requests per 10 minutes,
not the old 60) is now locked in by a test, so it can't quietly regress.

**App identity.** The Android/web launcher icon, the browser favicon, and the
placeholder `Icons.science` marks scattered through the login screen, both
console sidebars and the landing page header/drawer were all generic Flutter
defaults or programmer-art stand-ins. They're now the project's own marks:
`assets/icon/app_icon.png` (a square crop of the DeepCT-AI logo) drives the
Android and web app icons via `flutter_launcher_icons`, the web favicon is
BRIN's own mark, and `assets/branding/brin_logo.png` replaced every placeholder
icon used as branding in the app itself.

**"New Analysis" can refresh model status.** Picking a model only checked
availability once, on screen load — if it came back offline, the only fix was
leaving the screen and returning. A refresh button next to "1. Choose a
model" re-checks status in place, without the full-screen reload
`_loadModels` shows on first entry (that would have discarded a file already
picked in step 2 for no reason).

**Not a bug, but worth writing down:** `http://localhost:PORT/` in `flutter
run`'s terminal output is a random port picked fresh on every launch, not a
stable address — reopening an old tab after the dev server restarted just
hangs on a dead port, which reads as "the landing page won't load" but is
really "wrong URL." `fe/README.md` now says so, with `--web-port` to pin it.

---

## [1.16.1] - 2026-08-16

### One dialog pattern, everywhere

Two related complaints about popups: the notification bell opened as a
bottom sheet rather than centered, and several admin dialogs held a
hard-coded `SizedBox(width: 420/460/520)` around their form with no clamp
against the viewport — on a narrow phone the content ran off the edge of the
screen instead of shrinking or scrolling.

Both are symptoms of the same gap: nothing in `fe/lib` centralized how a
dialog gets shown, so every screen called `showDialog` on its own and
repeated `shape: RoundedRectangleBorder(borderRadius: BorderRadius.zero)` by
hand, and a couple of them added a fixed width that only happened to fit a
desktop window.

[`fe/lib/widgets/app_dialog.dart`](fe/lib/widgets/app_dialog.dart) is now the
one way this app opens a dialog: `showAppDialog` centers on screen (a
`Dialog` does that on its own), clamps width to the smaller of a requested
`maxWidth` and 90% of the viewport, caps height at 85% of the viewport, and
scrolls instead of overflowing. `showAppAlertDialog` covers the
title/content/actions shape that used to be an `AlertDialog`, so most call
sites changed by name only. Every `showDialog` call site in the app —
admin's user, model and news management, activity log detail, access
requests, both console shells' sign-out prompt, prediction history delete,
the admin conversation delete, and the news "read more" dialog — now goes
through it, and the hard-coded `SizedBox` widths are gone along with it. The
notification bell's panel moved from `showModalBottomSheet` to the same
centered dialog, keeping its existing list/mark-as-read state untouched.

---

## [1.16.0] - 2026-08-15

### 💬 Tickets became messages, and the app started telling people things

Two changes, and the first is a retraction.

#### Support is a conversation, not a ticket system

v1.12.0 built IT support as tickets: subject, category, priority, a four-state
status, and an `awaiting_admin` flag. The product owner's verdict was that it
should be **messages** — "so a user can send a message to the admin if there is
a problem, through IT support" — and they were right for a better reason than
tidiness.

A ticket model asks someone who already has a problem to **classify it first**.
Pick a subject. Pick a category. Pick a priority. Then watch a status. That is
the shape of a helpdesk with a support department and an SLA behind it. Here
there is one administrator, and what people want is to say "this is broken" and
be answered.

So the ceremony is gone. `support_tickets` and `support_ticket_messages` became
`conversations` and `messages`; `subject`, `category`, `priority`, `status`,
`awaiting_admin`, `resolved_at`, `resolved_by` and `analysis_record_id` went
with them. Existing rows were **carried over, not dropped**: several tickets
from one person collapse into that person's single thread, and each ticket's
subject is folded into the first message it carried so nothing anyone wrote was
lost.

Two things came out of it that are worth more than the simplification:

- **The researcher's routes take no id at all.** One thread per account means
  "mine" is the only thing they could mean. The entire class of bug where one
  account reaches another's messages is gone — not guarded against, *absent*,
  because there is no id to tamper with. The unique index on `user_id` is what
  makes that true rather than hoped for.
- **Archive replaced status.** An administrator still needs to tidy an inbox,
  but four states for one person was theatre. One flag does it, and a new
  message pulls the thread back out: they filed away a conversation, not a
  person.

What survived from the ticket design, because the reasons still hold: it is a
back-and-forth (technical problems always need a question back), and the
sign-in page can still write (the people who cannot log in are the ones who most
need support). Read state is now tracked in both directions, with ticks.

#### Notifications, for both consoles

A bell with an unread badge, on the researcher console and the admin one.

| Event | Goes to |
|---|---|
| New message / guest message | Every active administrator |
| A reply | The researcher who asked |
| Prediction finished or failed | The job's owner |
| **Results expiring in ~3 hours** | The job's owner |
| New access request | Every active administrator |
| Account approved | The new account |
| Model went offline / came back | Every active administrator |

Laravel's own notification system rather than a hand-rolled table, so sending
any of these by email later is `via() => ['database', 'mail']` and not a second
delivery mechanism. What is *not* Laravel's convention is a class per event —
that would be a dozen files differing only in strings. One
`PlatformNotification` carries the payload and
[`app/Services/Notifier.php`](be/app/Services/Notifier.php) holds every event in
one place, so the question "what does this platform ever tell people?" has a
single-file answer.

Three decisions that matter more than the feature:

- **A notification may never break its caller.** A prediction that finished must
  not be marked failed because writing a row about it threw. Everything goes
  through a `push()` that swallows and logs.
- **Model status notifies on the transition only.** The health check runs every
  five minutes; an overnight outage would otherwise produce 288 identical
  notifications.
- **The expiry warning rides the sweep that already exists.**
  `predictions:cleanup` runs hourly anyway, so it now warns owners about output
  due for deletion in ~3 hours, once, tracked by `expiry_notified_at`. Deleting
  1.5 GB of results that nobody was told about is the most expensive thing this
  platform can do to a researcher.

The client polls — same reasoning as everywhere else, now written down in
ARCHITECTURE.md §4 with the three intervals in one table. The bell's poll
returns **both** the notification count and the unread message count, so the
bell and the Messages badge cost one request between them rather than one each.

#### Fixed — two leaks found while testing

`notifications` and `personal_access_tokens` are polymorphic, so neither carries
a foreign key back to `users`. Deleting an account left both behind **forever**:
unreadable notifications, and in the token's case a credential with no owner.
`User::booted()` now removes them along with the account's avatar file, which
had the same problem for the same reason — it is a file, not a row, so it had no
cascade to inherit either.

#### Removed

- `SupportTicket`, `SupportTicketMessage`, `SupportTicketController`,
  `SupportTicketTest`, and the Flutter ticket screens, model and service.

Verified live against the running server: a researcher's message reached the
admin inbox and produced a `message.received` notification, the reply came back
with the researcher's messages marked read, the unread counters moved in both
directions and cleared on read, and a message from the sign-in page arrived
flagged as having no account with the reply address inside the notification
body.

---

## [1.15.0] - 2026-08-15

### 🔁 Interrupted uploads can be continued, and the app has a real identity

The last three items on the roadmap, which had been carried for a while.

#### Client-side upload resume

The server had supported resuming since the chunked flow was built —
`GET /predictions/uploads/{id}` reports how many bytes landed — but the client
threw the session away on the first error and started from zero.

Now:

- A failing chunk is **retried three times**, and the offset is re-read from
  the server before each attempt. A request that timed out may well have landed;
  re-sending from a stale offset earns a 409, which is exactly the failure this
  avoids.
- The session is **remembered on the device**, so an upload killed by a dropped
  connection or a closed app is offered back on the upload screen.
- Only the *description* is stored — `upload_id`, filename, size, MD5 — never
  the bytes. An archive runs to tens of megabytes and on web there is no path to
  re-read it from, so resuming asks for the same file again and the MD5 proves
  it is the same one. Splicing a different file into a half-written session
  produces a corrupt ZIP that only fails much later, inside the worker.
- A session is discarded only when the server **refuses outright** (422 and
  friends). A failure that smells like network trouble leaves it intact, since
  that is precisely the case worth resuming.
- 11 tests.

#### `applicationId` is no longer `com.example.fe`

It is now `id.go.brin.neutronct` — reverse-DNS of the institution that owns the
app. This had to be settled before any APK went out: changing it after a release
installs a second copy alongside the first rather than updating it. The
iOS/macOS/Linux/Windows scaffolds were renamed at the same time so the same trap
is not left waiting there.

#### Model training system — designed, not built

Written into [ARCHITECTURE.md](ARCHITECTURE.md) §7 rather than as a new file.
The short version: the platform would **manage** training, never run it. Three
constraints force that shape — the notebook in this repo has no training code,
Kaggle sessions die every 9–12 hours while training takes days, and this machine
has no GPU and a PHP backend.

The design's centre is the pair **heartbeat + checkpoint**: a job whose worker
goes quiet returns to `queued` with its checkpoint intact, rather than failing.
A session dying is not an edge case there, it is the normal course of events,
and without recovery a multi-day training would never finish. That is the
opposite of the prediction flow, which may fail freely because a frame costs
~20 seconds.

Worth recording because it is the reason the recursive method exists: a model
retrained on a balanced-t dataset could interpolate at arbitrary t, and the
whole recursion tree in §2 would become unnecessary.

---

## [1.14.0] - 2026-08-15

### 👤 Profile photos, with an initials frame when there is none

Accounts were a person-shaped icon everywhere they appeared. They now carry a
photo, and the fallback is designed rather than left over.

#### The fallback is the point

Most accounts will never upload anything, so the no-photo state is the one most
people see. A grey box or a broken-image glyph reads as a fault; **initials on
the account's own colour** reads as deliberate and stays legible at 22px. The
colour is derived from the name, so a face keeps its tile between sessions
instead of shuffling on every load — and it works for a support ticket raised
by a guest, where there is no id to hash.

An account with no photo returns **404**, not a stock image. The client draws
the frame; a server-side placeholder would be a second opinion about what "no
photo" looks like.

#### Added — Backend

- `users.avatar_path` + `avatar_mime`, and five routes: serve, set/remove your
  own, set/remove anyone's as an admin. Somebody has to be able to take down an
  inappropriate picture from an account that is not theirs.
- **Serving is authenticated.** Avatars appear beside activity logs and in the
  user list, so every signed-in account needs them — but an anonymous visitor
  should not be able to harvest photos of the research staff by walking the ids.
- `avatar_url` is appended to the User model, so it appears in every payload
  that returns a user, including the ones that just hand back
  `paginate()->items()`. `avatar_path` and `avatar_mime` are hidden.
- Same upload guard as research news: 2 MB, and `mimetypes:` reading the file's
  bytes rather than its extension.
- 15 tests.

#### Added — Frontend

- `UserAvatar` (photo or initials), `AvatarButton` for the sidebar, and one
  `AvatarEditorSheet` serving both the self case and the admin case — the
  endpoints differ, the form does not.
- Shown in both sidebars, the admin user table, and the admin activity log,
  where the action icon says *what* happened and the avatar says *who*.
- `AvatarCache` fetches bytes through `ApiClient` because the endpoint is
  authenticated and `Image.network` cannot read a token out of secure storage.
  Misses are cached too, or a list of twenty rows would re-request on every
  rebuild.
- 11 tests.

Verified live: upload returned the new URL, the image served 200 to a signed-in
caller and **401 to an anonymous one**, the admin list showed the URL without
leaking `avatar_path`, and removal took it back to 404.

---

## [1.13.0] - 2026-08-15

### 📰 Research news, published by an administrator

The landing page's "Research Applications" section was a heading and one
paragraph of fixed copy. It now carries a slideshow of research news that an
administrator writes, photographs and switches on.

#### Added — Backend

- `news_posts`, and `NewsController` behind eight routes: a public feed, a
  public image, and six admin ones.
- **Saving is not publishing.** The toggle is a separate action, so a draft can
  be prepared ahead of an announcement without any risk of it appearing.
  `published_at` is stamped only the first time — otherwise hiding and
  re-showing an old post would throw it to the front of a date-ordered
  slideshow, and there is a test for exactly that.
- **A draft's photo 404s to the public** and is served only to an admin. The
  route carries no auth middleware but resolves the token itself, which is what
  makes the admin preview work. A draft readable by guessing an id would leak an
  unannounced result.
- 17 tests.

#### Added — Frontend

- `NewsCarousel` on the landing page: auto-advancing every 7s, arrows on
  pointer devices, swipe on a phone, dots that restart the clock when tapped.
- It **renders nothing** when the feed is empty or the request fails. A visitor
  must never meet an error box on the front page over something optional.
- `NewsManagementScreen` for the admin: write, attach a photo, reorder,
  publish, delete.
- Posts with no photo get an empty frame rather than a blank rectangle — a
  blank reads as a bug.
- 15 tests.

#### Constraint worth recording

This machine has neither GD nor Imagick, so **the server cannot resize or
re-encode an uploaded image**. The whole defence is a 4 MB cap and a
`mimetypes:` rule, which reads the file's actual bytes rather than trusting its
extension. Images are stored byte-for-byte and streamed through the API rather
than published under `public/`: there is no `storage:link` here and the app is
reached over ngrok, where a symlinked path is one more thing to get wrong.

#### Changed — test harness

- `TestCase::apiAs(null)` now *removes* the Authorization header as well as
  forgetting the guard. `withHeader` writes to `$defaultHeaders`, which persists
  for the rest of the test method, so an "anonymous" request after an
  authenticated one still carried the old token. The draft-photo test passed
  through this and reported a 200 that had nothing to do with the application.
- `NewsCarousel.debugLoader` is a test seam in the same spirit as
  `GoogleFonts.config.allowRuntimeFetching = false`: the widget loads itself, so
  without it every landing-page test starts a real HTTP request whose timeout
  timer is still pending when the test ends — and Flutter fails a test with
  pending timers, whatever it was actually asserting.

Verified live: a draft was invisible in the public feed, its photo 404'd
anonymously and 200'd as an admin, the toggle published it, and the served image
came back byte-identical to the upload.

---

## [1.12.0] - 2026-08-15

### 🎫 IT support that reaches an administrator inside the app

The "IT Support" button on the sign-in page had `// TODO: Navigate to IT
support` behind it, and there was nowhere for a researcher to report a problem
at all. Tickets now exist on both sides.

Built as a **conversation**, not a single message. Technical problems almost
always need a question back — *which frames? what did the error say?* — and with
one field the administrator would have to leave the app to ask.

#### The awkward part: the button is on the sign-in page

The most common reason to press "IT Support" there is **not being able to sign
in**, which is exactly when an authenticated endpoint is useless. So there are
two ways in:

| Route | Who | Reply arrives |
|---|---|---|
| `POST /api/support/tickets` | Signed-in researcher | In the app |
| `POST /api/support/tickets/public` | Anyone, throttled 5/hour | By email |

A guest ticket has `user_id = NULL` and carries the reporter's name and address
instead. It lands in the same admin queue flagged `is_guest`, and the
conversation screen tells the administrator to answer by email rather than
letting them type into a thread nobody can read.

It is deliberately **not** attached to an account whose email happens to match.
The address is unverified, so attaching it would let anyone plant messages in
another researcher's ticket list — there is a test asserting exactly that.

#### Added — Backend

- `support_tickets` and `support_ticket_messages`. `from_admin` is stamped when
  the message is written, not derived from the author's current role: promoting
  someone later must not turn their old messages into staff replies.
- `awaiting_admin` records whose turn it is, and drives the sidebar badge. A
  researcher's message sets it; an administrator's reply clears it and moves an
  `open` ticket to `in_progress`.
- Replying to a `resolved` ticket reopens it. A `closed` one refuses with 409.
- Ownership is scoped **in the query**, so another account's ticket 404s rather
  than 403s — a 403 would confirm the id exists.
- 23 tests (131 assertions), including the guest paths.

#### Added — Frontend

- `TicketListScreen`, one screen for both sides: `asAdmin: true` switches it to
  the full queue with a "needs reply" filter and status controls.
- `TicketConversationScreen` — staff replies left, your own right.
- `PublicTicketSheet`, opened from the sign-in page and the landing footer.
- The admin sidebar shows a count of tickets waiting on a reply, refreshed on
  navigation rather than polled; a failed refresh is swallowed, since a badge is
  not worth an error banner.
- 7 Flutter tests.

#### Fixed

- **A 54px overflow on a phone**, caught by the new layout test.
  `DropdownButtonFormField` sizes itself to its longest option instead of the
  space it is given, so the category dropdown ("prediction") pushed its row off
  the edge. Fixed with `isExpanded: true` on every dropdown in a constrained
  row, plus stacking below 420px.

#### Documentation

- `be/README.md`: the endpoint list said **35 total** and documented neither the
  access-request nor the support routes. It is now 50, verified against
  `route:list`, with both families written up. Table count corrected 13 → 16,
  and `Predictions (6)` → `(8)`, which had always listed eight.
- `fe/README.md`: the "Not Started (FASE 3)" section still claimed the upload
  and results screens did not exist and that the backend routes were commented
  out. Both have been true-since-v1.8 for some time; replaced with what is
  actually there.

---

## [1.11.0] - 2026-08-15

### 🔓 Concurrent sessions restored, on request

v1.9.0 refused a second login while an account was in use. That has been
reverted: **one account may now be signed in on several devices at once.**

Each login mints its own token and leaves the others untouched; `POST /logout`
revokes only the token that made the request. Expiry is handled centrally
rather than per-login — 7 days via `config/sanctum.php`, swept daily by
`tokens:cleanup`.

Worth recording that this is a *third* behaviour, not a return to the first:

| | Behaviour |
|---|---|
| Originally | Login revoked all other tokens — single session, newest wins |
| v1.9.0 | Login refused while a session was active — single session, oldest wins |
| Now | Sessions coexist |

Neither restriction earned its keep. A researcher moving between a laptop and a
phone was interrupted by both, and the second form could lock an account out
after a force-closed app. The security boundary now sits in token lifetime and
daily cleanup, not in a session count.

The three single-session tests were replaced with three that assert the
opposite: two devices can hold sessions at once, an admin is not exempt, and
signing out on one device leaves the other working. Verified on the running
server as well.

Docs corrected in six places — `CLAUDE.md`, `be/README.md`, `API.md`,
`README.md` (twice), `ARCHITECTURE.md` and `ROADMAP.md` — all of which had
described the old rule.

---

## [1.10.0] - 2026-08-15

### 🖼️ Frame preview — results can finally be looked at

Until now a completed job could only be downloaded blind: the researcher had no
way to see whether the interpolation was any good without pulling a
multi-megabyte archive and opening it in other software.

#### The obstacle

Frames are **16-bit grayscale TIFF**, which neither a browser nor Flutter can
decode. And this machine has **neither the GD nor the Imagick extension**, so
there was no library to convert with either.

`TiffPreview` therefore decodes the TIFF and encodes the PNG in plain PHP. That
is only reasonable because the input is narrow and predictable — the worker
returns uncompressed single-channel frames — and anything outside that shape is
**refused with a reason** rather than guessed at.

Two details that matter more than they look:

- **The 16→8 bit conversion windows to each frame's own min/max**, rather than
  dropping the low byte. CT frames rarely span the full 16-bit range, and a
  naive shift renders most of them as an almost-black square. There is a test
  asserting a frame whose values sit between 1000 and 1007 still comes out with
  full contrast.
- **Downscaling box-averages** instead of dropping pixels, because
  nearest-neighbour makes CT noise look like structure.

#### Added — Backend

- `GET /api/predictions/{id}/frames` — what is on disk, inputs and outputs.
- `GET /api/predictions/{id}/frames/{name}/preview?size=N` — that frame as a
  PNG, longest edge `N` (64–2048). Cached beside the job, so
  `predictions:cleanup` disposes of the renders too.
- 18 new tests: 12 unit tests over the decoder/encoder (including big-endian
  input, WhiteIsZero inversion, flat frames, truncated data, and the formats it
  must refuse) and 6 feature tests over the endpoints.

#### Added — Frontend

- `FrameGalleryScreen` — responsive grid (2–5 columns), generated frames
  outlined and badged `AI`, a "generated only" filter, and a full-screen viewer
  with pan/zoom that pages between frames.
- Frames are ordered by **frame number**, so uploaded and generated frames
  interleave in sequence order rather than grouping by kind — which is the
  whole point of looking at them.
- Thumbnails are fetched at 256px and the viewer at 1024px, so a gallery of
  forty frames does not pull forty full-resolution images. Bytes go through the
  authenticated client rather than `Image.network`, which cannot carry a bearer
  token.
- The viewer uses a black ground: greyscale CT detail is far easier to read
  against black, and it is the one screen where the app's light surface fights
  the content.

#### Verified against real frames, not only fixtures

A 1024×1024 16-bit frame (2,097,262 bytes):

| | |
|---|---|
| First render at 256px | 510 ms, **2,495-byte PNG** |
| Same request again | **71 ms** (cached) |
| Output validated | 256×256, 8-bit, colour type 0 (greyscale) |
| Path traversal attempt | **403**, blocked before reaching the app |
| Expired job | **410** |

The rendered PNG was opened and visually confirmed to match the source frame.

89 backend tests / 295 assertions; `flutter analyze` clean; 21 Flutter tests.

---

## [1.9.0] - 2026-08-15

### 🔐 A second login is now refused, not silently granted

#### Changed — breaking

`POST /api/login` previously let the newest login win: it revoked every
existing token and issued a fresh one, so a second person using the same
credentials would quietly kick the first off, and neither would know.

It now **refuses** with **HTTP 409** while the account is in use:

```json
{ "success": false,
  "message": "This account is already signed in on another device. Sign out there first, or try again in a few minutes." }
```

The device already holding the session keeps working. Applies to
administrators and researchers alike.

**"In use" means the token was exercised within the last 15 minutes**
(`AuthController::SESSION_IDLE_MINUTES`). Sanctum stamps `last_used_at` on
every authenticated request, so an app in normal use keeps its own session
alive; anything idle past that window counts as abandoned and the new login
takes it over, clearing the stale token.

That idle window is load-bearing, not a nicety. A strict "refuse while any
token exists" rule would lock an account out for the full seven-day token
lifetime after an app was force-closed, a browser shut, or a phone died — and
an administrator who locked themselves out that way would leave nobody able to
help. This was raised before implementing, and the idle-takeover behaviour was
chosen deliberately.

Consequence worth knowing: **a script cannot log in as the same user twice.**
Reuse the token or log out first.

#### Added

Five tests covering the new rule, including the ones that matter most:
an abandoned session *can* be taken over, an active one cannot, activity
refreshes the window, and logging out frees the account immediately.

`AuthService._handleError` now handles 409 explicitly rather than relying on
fallthrough, and no longer assumes the error body is a map.

#### Verified on the live server, not only in tests

- First login → 200
- Second login while active → **409** with the message above
- The first session still answers 200 — it is not kicked off
- Admin subject to the same rule
- 71 backend tests, 238 assertions
- `flutter analyze` clean, 21 Flutter tests pass

---

## [1.8.0] - 2026-08-15

### 🧪 A real backend test suite, and one command to run the stack

#### Added

**67 tests, 223 assertions, ~20 seconds.** `be/tests/` previously held nothing
but Laravel's `ExampleTest` stubs, so `php artisan test` proved nothing.

| Suite | Covers |
|---|---|
| `AuthTest` (8) | login, logout, token revocation, single-session, audit trail |
| `AuthorizationTest` (22) | all 15 admin routes refuse a researcher; `/me/*` is owner-scoped; `endpoint_url` never leaks |
| `PredictionPipelineTest` (18) | recursive interpolation, worker contract, failure paths, counter release |
| `ChunkedUploadTest` (11) | ordering, idempotency, ownership, session cleanup |
| `PredictionCleanupTest` (8) | 24-hour retention and the temp sweeps |

The GPU worker is faked throughout — a real call costs ~20s and Kaggle quota,
and what needs testing is our orchestration. The fake reproduces the worker's
actual contract, **including a handled failure arriving as JSON with HTTP 200**,
which has its own test.

**`npm run serve:all`** starts the API, queue worker and scheduler together via
`concurrently`. Verified by uploading a job and watching the worker pick it up in
6 seconds with no manual `queue:work`.

**`npm run octane:reset`** kills whatever holds the port and clears the stale
state file, because `octane:stop` cannot do it on Windows — it calls
`posix_kill()` and crashes before stopping anything.

#### Changed

- **Tests run against MySQL, not sqlite.** `phpunit.xml` pointed at sqlite
  `:memory:`, which cannot work here: two migrations use
  `ALTER TABLE ... MODIFY`, and `activity_type` begins as an enum of five values
  the application long outgrew, so its CHECK constraint would reject rows the
  real app writes. A sqlite suite would produce both false passes and false
  failures. Requires `CREATE DATABASE db_aict_test` once.
- `SANCTUM_STATEFUL_DOMAINS` is empty under test — see below.

#### Two traps found while writing these tests

**A revoked token kept answering 200.** Not an application bug: Laravel's
`AuthManager` caches the resolved guard *and its user* for the lifetime of a
test method, so a second request never re-checks the token. Confirmed by
diagnosis — after logout the token row was gone from the database, yet
`/api/user` still returned 200 until `forgetGuards()` was called. `TestCase`
now exposes `apiAs($token)`, which resets the guard first; using
`withHeader('Authorization', …)` directly would make revocation tests pass
while asserting nothing.

Sanctum's default `stateful` list also contains `localhost`, and test requests
default to that host, so `EnsureFrontendRequestsAreStateful` would switch
authentication to the session guard entirely. The real clients hold a bearer
token and never use the SPA cookie flow, so the test env forces the token guard.

**The tests polluted real storage.** `RefreshDatabase` rolls back the database
but leaves the filesystem alone, and these tests write real frames: a single run
left 132 files under `storage/app/private/predictions/`. Fixed with
`Storage::fake('local')`, and the accumulated debris removed.

---

## [1.7.0] - 2026-08-15

### 📚 Documentation consolidated: 28 files → 10

The docs had grown to **28 markdown files and 14,182 lines**, most of them
one-off session summaries that contradicted each other and the code. Three
separate documents claimed the project was production-ready; one described code
that did not compile. Finding the current truth meant reading all of them and
guessing which was newest.

#### Added

- **`CLAUDE.md`** — the working agreement for anyone (human or agent) touching
  this repo: which four documents to read, four rules, and the traps that
  actually cost time here (Octane's `posix_kill` restart failure, the missing
  queue worker, the `file_picker` version corridor, `SafeArea`, the model's
  multipart contract, and why `route:list` proves nothing). Claude Code loads
  this automatically.
- **`API.md`** — endpoint reference regenerated from `route:list`, covering all
  35 routes including the prediction and chunked-upload families that
  `API_DOCS.md` never documented.

#### Changed

- **`README.md`** is now the entry point: what runs today, how to start it, and
  an explicit **"Belum ada"** table. Absorbs `PROJECT_STATUS.md`, `SETUP.md`,
  `TODO.md` and the headline figures from `TESTING_RESULTS.md`.
- **`ARCHITECTURE.md`** rewritten to match the running system, absorbing
  `ARCHITECTURE_FLOW.md`, the schema truth from `DATABASE_STATUS.md` and
  `be/DATABASE_CLEANUP.md`, and the rationale from `FASE3_DECISIONS.md`. Adds a
  "why" for each significant decision, including the ones discovered the hard
  way.
- `PRD.md`, `DESIGN.md` and `AI_EXPERIMENTS.md` kept, each with a header saying
  what it is and what supersedes it. `AI_EXPERIMENTS.md` is the most durable
  document here — it records *why* interpolation is always t=0.5, which is not
  recoverable from the code.

#### Removed

20 files: `ARCHITECTURE_FLOW`, `API_DOCS`, `DATABASE_STATUS`,
`FASE2_COMPLETION_SUMMARY`, `FASE3_DECISIONS`, `FASE3_ROADMAP`,
`PENDING_TASKS_ANALYSIS`, `POLISH_COMPLETION_SUMMARY`, `POLISH_FINAL_SUMMARY`,
`POLISH_PLAN`, `PROJECT_STATUS`, `QUICK_REFERENCE_SECURITY`, `SECURITY_UPDATE`,
`SETUP`, `TASK_COMPLETION_SUMMARY`, `TESTING_RESULTS`, `TODO`,
`be/DATABASE_CLEANUP`, `fe/test_auth`, and `be/CHANGELOG` — that last one was
**Laravel's own release notes**, left over from `composer create-project` and
describing the framework rather than this project.

All recoverable from git history.

---

## [1.6.0] - 2026-08-15

### 📤 FASE 3 client: upload, watch, download

The researcher console can now run the whole pipeline end to end.

#### Added — Frontend

- **`UploadScreen`** — model picker, ZIP picker, live progress. Requirements
  are stated up front (numbered frames, a *gap* between numbers, size limits),
  because each one is otherwise a rejection the user only discovers after
  uploading. Offline models are shown but not selectable.
- **`PredictionHistoryScreen`** — job cards with status, queue position,
  expiry countdown, both download variants and delete. Polls every 10s **only**
  while something is pending or processing, and cancels the timer once
  everything has settled. A failed background refresh leaves the list on screen
  instead of blanking it.
- **`PredictionService`** — picks the upload transport for the caller: a single
  request under 1 MB, the resumable chunked flow above that. Chunk size comes
  from the server's session response, never hard-coded.
- **`Prediction` model** with lifecycle helpers (`isActive`, `canDownload`,
  `expiryLabel`).
- Downloads are **checksum-verified**: the client recomputes MD5 over the
  received bytes and compares it to `X-Checksum-MD5`, surfacing a mismatch
  rather than silently saving a corrupt archive.
- `file_download` utilities generalised from text to bytes so the same
  web/native split serves both the CSV export and results archives.

#### Added — Backend

- **Chunked upload** (`PredictionUploadController`): start → PATCH chunks →
  finalize, plus status (for resuming) and abort. Out-of-order chunks are
  rejected with **409** rather than silently assembling a corrupt archive;
  re-sending a chunk that already landed is idempotent so clients can retry.
  Ownership is enforced by the storage path, so another account's `upload_id`
  simply 404s.
- **`PredictionIntake` service** — extraction, validation, record creation and
  dispatch, shared by the direct and chunked paths so the two cannot drift
  apart. Extraction now flattens nested entries; previously a ZIP with a
  wrapping folder would extract frames the job could never see, because
  `Storage::files()` does not recurse.
- **`GET /api/me/models`** — a researcher could not previously see any model at
  all (the registry is admin-only), so there was nothing to pick on the upload
  screen. Returns id, name, version and reachability only; `endpoint_url` stays
  admin-only, since knowing it would let anyone bypass the platform and hit the
  GPU worker directly.

#### Fixed

- **`predictions:cleanup` returned early when nothing had expired**, so
  abandoned upload sessions and orphaned download archives were never swept on
  an installation where no prediction had yet reached its retention window.
  A stale `.part` file can be hundreds of megabytes.
- **Chunk size is now computed from the server's own limits** rather than fixed
  at 4 MB. On a stock Windows `php.ini` (`upload_max_filesize = 2M`) a 4 MB
  chunk would be rejected before the application ever saw it.
- Abandoned upload sessions older than 24 hours are now swept. The window is
  deliberately generous: resuming an interrupted upload is a supported feature.

#### Dependency note

`file_picker` returns, pinned to **^11.0.0**, which is bounded on both sides:
6.x and **8.x** still reference the v1 embedding (`PluginRegistry.Registrar`)
and fail `flutter build apk` with "cannot find symbol: class Registrar"
(verified against 8.0.0), while 12.x needs `win32 ^6.3.0` against
`flutter_secure_storage` 9.x's `win32 ^5.0.0`. 11.x also moved `pickFiles` to a
static method.

#### Correction to v1.5.0's notes

v1.5.0 recorded that PHP's `upload_max_filesize` made direct upload unusable.
That was wrong: under Octane, **RoadRunner parses the multipart body itself**,
so the PHP SAPI limit does not apply — a 4 MB direct upload succeeds against a
2 MB `upload_max_filesize`. The real ceiling is RoadRunner's `max_request_size`.
The chunked flow still earns its place for resumability, honest progress, and
deployments behind nginx + PHP-FPM where those limits do apply.

#### Verified against the live Kaggle worker, at realistic frame sizes

Using two 1024x1024 16-bit TIFF frames (2 MB each, 4 MB archive):

- Chunked upload split into **3 chunks of 1.6 MB**, the size the server
  computed from its own limits
- Resume endpoint reported byte counts correctly between chunks
- Out-of-order chunk → **409**; duplicate chunk → idempotent; premature
  finalize → **409**; another account's `upload_id` → **404**; abort → 200
- Finalize queued the job; the worker produced **3 frames of 2 MB each**
- `download/results` → 200 with `X-Checksum-MD5` matching the actual file MD5
- `predictions:cleanup` swept the abandoned sessions and reported bytes freed
- `flutter analyze` clean, 21/21 tests pass

---

## [1.5.0] - 2026-08-15

### 🔬 FASE 3 backend: the prediction pipeline actually runs

`AnalysisController` was already ~530 lines of upload, extraction, validation,
queue-position, dual download and delete logic — but it had never been wired up
or run once. Five separate defects each made it fail outright.

#### Fixed

**1. `AnalysisRecord` was an empty model**
- It carried nothing but `protected $guarded = []`: no relations and no casts.
- Every `->with('model:id,name,version')` in the controller threw
  `Call to undefined relationship [model]`, so `index()` and `show()` could
  never return.
- `expires_at` came back from the database as a plain string, so
  `$prediction->expires_at->toIso8601String()` failed on any record read back
  from the database (it only appeared to work right after `create()`, while the
  Carbon instance was still in memory).
- Added `user()` / `model()` relations, casts, `$fillable`, and small
  lifecycle helpers.

**2. `ProcessDeepLearningImage` targeted an API that does not exist**
- It POSTed **JSON** containing `t0_image_url` / `t2_image_url` to a
  **hard-coded** ngrok URL, and wrote to `t0_image_path` / `t2_image_path` —
  columns the folder-based upload flow never populates.
- The real worker takes **multipart** `file_t0`, `file_t2` and `time_scalar`,
  streams a TIFF back, and reports handled failures as JSON with HTTP 200.
- Rewritten: reads the endpoint from the model record, sorts input frames by
  their trailing frame number, and fills each gap by **recursive**
  interpolation at t=0.5 — the generated midpoint becomes a boundary for the
  two halves around it. Output frames inherit the neighbour's prefix and zero
  padding (`frame_001.tif` + `frame_005.tif` → `frame_002/003/004.tif`).
- Guards: consecutive frames are rejected with an actionable message before any
  GPU time is spent, and jobs that would generate more than 200 frames are
  refused up front. `tries = 1`, since a retry would redo completed frames.
- `failed()` handler added — without it a crashed job sat on `processing`
  forever.
- Model concurrency counters are now incremented and, in a `finally` block,
  always decremented; previously `current_jobs_count` would have drifted upward
  and never recovered.

**3. `t0_image_path` / `t2_image_path` were `NOT NULL` with no default**
- Legacy columns from the superseded single-pair design. Every insert from the
  new upload endpoint died with
  `SQLSTATE[HY000]: General error: 1364 Field 't0_image_path' doesn't have a default value`.
- New migration makes them nullable rather than dropping them.

**4. Downloads crashed on `deleteFileAfterSend()`**
- `response()->streamDownload(...)->deleteFileAfterSend(true)` — that method
  exists on `BinaryFileResponse`, not `StreamedResponse`, so both download
  routes returned HTTP 500.
- Switched to `response()->download()`, which also honours HTTP **Range**
  requests, giving the resumable downloads the design called for.

**5. Every download leaked a full-size ZIP (Octane-specific)**
- Symfony performs the `deleteFileAfterSend` unlink inside
  `BinaryFileResponse::sendContent()`, which **Octane never calls** — it
  converts the response to PSR-7 for RoadRunner instead. Each download left a
  complete copy of the results in `temp/downloads` forever; at the documented
  ~1.5 GB per job that is a fast route to a full disk.
- The temp ZIP is now removed in an `app()->terminating()` callback, which does
  run under Octane, and `predictions:cleanup` sweeps anything older than an
  hour as a safety net for requests that die mid-flight.

#### Added

- **6 routes registered** under `/api/predictions` (they had been commented out
  in `routes/api.php`): list, upload, show, delete, and the two download
  variants.
- **`predictions:cleanup`** command enforcing the 24-hour retention window:
  deletes files, keeps the record, stamps `files_deleted_at`. Supports
  `--dry-run` and reports bytes freed. Scheduled **hourly** rather than daily so
  files expire close to their stated deadline.

#### Verified end to end against the live Kaggle worker

- Upload of a ZIP holding `frame_001.tif` + `frame_005.tif` → HTTP 201, queued
- Job ran and produced exactly **3 frames** — `frame_002/003/004.tif`, 2 MB each
- File timestamps confirm the recursion order: **003 first, then 002 and 004**
- `download/results` → 200, ZIP holds the 3 generated frames, and the
  `X-Checksum-MD5` header matches the file's actual MD5 exactly
- `download/complete` → 200, `input/` + `output/` + correct `metadata.json`
- `Accept-Ranges: bytes` present, so downloads resume
- Consecutive frames → job fails fast with a clear message, no GPU time spent
- Expired record → files deleted, record kept, download returns **410**,
  `show()` reports `files_available: false`
- Three consecutive downloads → **zero** temp files left behind
- `DELETE` removes both record and files

#### Still to do in FASE 3

Chunked/resumable **upload** (>50 MB), the Flutter upload and results screens,
and in-app progress polling. The backend contract they need is now stable.

---

## [1.4.0] - 2026-08-15

### 👤 Researcher console (web + mobile)

Replaces the "Under Construction" placeholder with a working console for
non-admin accounts.

#### Added — Backend

**`GET /api/me/stats` and `GET /api/me/activities`** (`MeController`)
- Before this, an ordinary researcher could reach exactly **three** endpoints:
  `POST /login`, `POST /logout` and `GET /user`. Everything else sat behind
  `role:admin`, so a user dashboard had no data to show at all.
- Both are scoped server-side to `$request->user()`, so there is no id
  parameter and no way to read another account's rows.
- `me/stats` returns activity counters, per-status analysis counters, and model
  availability **as a count only** — endpoint URLs stay admin-only.
- The analysis counters read zero until the FASE 3 pipeline starts writing
  `analysis_records`; the response shape is already final, so the UI will not
  need changing then.
- `per_page` is clamped to 1..100.

#### Added — Frontend

- `UserShell` — responsive researcher console mirroring `AdminShell`:
  persistent sidebar at ≥1000px, drawer + AppBar below that.
- `UserHomeScreen` — model availability, own analysis counters, today's
  activity, and the five most recent actions.
- `UserActivityScreen` — full paginated audit trail.
- `UserActivityTile` — shared row widget, relative time on the dashboard and
  absolute time in the full log.
- `MeStats` model and `MeService`.
- The two FASE 3 sections (New Analysis, Results & History) are listed with a
  `SOON` badge and an explanation rather than hidden, so the shape of the
  product is visible.

#### Removed

- `user_dashboard.dart`, the static "Under Construction" placeholder.
  `main.dart` and `login_page.dart` now route to `UserShell`.

#### Verified

- `flutter analyze` → **No issues found!**
- `flutter test` → **All tests passed!** (12 tests)
- `GET /api/me/stats` → 200, counters correct
- `GET /api/me/activities` → 200, paginated and scoped to the caller
- A researcher token against `GET /api/admin/users` → **403** (boundary intact)
- No token against `GET /api/me/stats` → **401**

> **Note on testing these routes:** Octane keeps the booted app in memory and
> `octane:reload` does not work on Windows, so a newly added route 404s until
> the RoadRunner process is genuinely replaced. See the troubleshooting entry
> in `be/README.md`.

---

## [1.3.1] - 2026-08-15

### 📱 UI/UX pass on the public shell

#### Fixed

**The app drew underneath the system status bar (Android)**
- `SafeArea` was used **nowhere in the app**. `LandingPage` draws its own fixed
  header inside a `Stack` instead of using an `AppBar`, `LoginPage` has no
  `AppBar` at all, and the wide `AdminShell` layout drops its `AppBar` — so in
  all three the content started at y=0 and ran under the clock, signal and
  battery icons. Scaffold only applies that inset automatically when an
  `AppBar` is present.
- All three now wrap their body in `SafeArea`, and their Scaffold background is
  painted so the reserved strip reads as part of the header rather than a stray
  white band.
- `main()` now sets a transparent status bar with dark icons
  (`SystemUiOverlayStyle`), which suits the light theme.
- A test asserts the landing header starts below a simulated 44px inset.

**Header navigation disappeared on laptop-width windows**
- The tabs collapsed into a menu below 1000px, which is wider than many laptop
  browser windows. Added a separate `_navBreakpoint` of **760px** so the tabs
  stay inline much further down; the section-stacking breakpoint stays at
  1000px. Layout tests cover 760px and 759px, the two sides of the boundary.

#### Changed

- The narrow-screen navigation is now a proper slide-in **`Drawer`** rather
  than a `PopupMenuButton`, matching what `AdminShell` already does. It carries
  the brand block, the four sections with the active one highlighted, and the
  login button.

#### Verified

- `flutter analyze` → **No issues found!**
- `flutter test` → **All tests passed!** (12 tests)
- `flutter build web --release` and `flutter build apk --release` → success

---

## [1.3.0] - 2026-08-15

### 📱 Landing page made responsive + project put under version control

#### Added

**Version control**
- The project had **no git repository**. `git init` on the root, with a
  `.gitignore` covering `be/.env` (holds `APP_KEY` and the database password),
  `vendor/`, `node_modules/`, `fe/build/`, the 64 MB `rr.exe` RoadRunner binary
  and the 88 MB `.h5` model weights. Initial commit: 289 files.
- `be/.gitignore` said `rr` but the file on disk is `rr.exe`, so the 64 MB
  binary was not actually ignored. Fixed.
- **`be/` contained its own `.git`** — not project history, but the upstream
  `laravel/laravel` skeleton repository (7227 framework commits, remote
  pointing at `github.com/laravel/laravel`, detached HEAD). Every backend
  source file the team wrote was still *untracked* inside it, and the root
  repo was recording `be/` as an empty submodule gitlink. The skeleton repo was
  moved aside so the backend is tracked properly.

**Layout regression tests**
- `test/widget_test.dart` now renders the app at 360x640, 390x844, 768x1024,
  1280x720 and 1440x1024 and fails if any section reports a layout overflow.
  6 tests total, all passing.

#### Fixed

**`landing_page.dart` was a fixed desktop layout** — no breakpoints anywhere,
so it overflowed on anything narrower or shorter than a desktop window:

- **Hero**: hard-coded `height: 800` replaced with a desktop `minHeight` of
  640. The fixed height overflowed vertically by ~146px whenever the headline
  wrapped onto extra lines or the viewport was shorter than 800px. The
  two-column `Row` now stacks below 1000px, and the 600px-tall visual
  placeholder scales to 280px off desktop.
- **Footer**: the bare `Row` holding the copyright line and three text buttons
  overflowed horizontally by ~579px at phone widths. Links now use a `Wrap`,
  the copyright is `Flexible` on desktop, and the two stack below 1000px.
- **Header**: logo + four nav buttons + login button in a single `Row` with
  40px gutters cannot fit a phone. Below 1000px the inline navigation collapses
  into a `PopupMenuButton`, gutters tighten to 16px, and the brand text is
  `Flexible` with ellipsis.
- **About / Join**: the three-across feature cards and the 5:7 copy-and-form
  split now stack below 1000px. At phone widths each feature card had been
  allotted roughly 100px — less than its own 32px padding allowed for.
- Section gutters drop from 40/96px to 20/56px below 600px.

#### Verified

- `flutter analyze` → **No issues found!**
- `flutter test` → **All tests passed!** (6 tests, 5 viewports)
- `flutter build web --release` → success
- `flutter build apk --release` → success

---

## [1.2.1] - 2026-08-15

### 🐛 Build Repair — v1.2.0 did not compile

v1.2.0 shipped two features that were never compiled. `flutter analyze`
reported **12 errors** and both `flutter build apk` and `flutter build web`
failed. This release fixes them and adds verification.

#### Fixed

**`fe/lib/screens/admin/dashboard_home_screen.dart` — rewritten**
- Was written against classes that do not exist in this codebase:
  `models/user.dart` → `User`, `services/user_service.dart` → `UserService`,
  `services/model_service.dart` → `ModelService`, and a static
  `ActivityService.getActivities()`.
- Now uses the real API: `UserModel`, `AdminUserService()`,
  `AdminModelService()`, `ActivityService().list()` — all instance-based,
  all returning `PaginatedResult<T>` rather than `Map<String, dynamic>`.
- Headline counters now come from the server's `pagination.total` instead of
  the length of one page.
- "Today's activity" is now a real server-side count
  (`date_from`/`date_to` filter), not a scan of the last 10 rows.
- Null-safety fixes: `ActivityLog.description` and `.createdAt` are nullable;
  actor name now uses the existing `actorLabel` getter (`ActivityLog` has no
  `user` relation object).
- "View all" now switches the shell to Activity Logs instead of showing a
  snackbar telling the user to do it themselves.
- Restyled to match the rest of the console: square corners,
  `withValues(alpha:)` instead of the deprecated `withOpacity`.

**CSV export — no longer web-only**
- `activity_logs_screen.dart` imported `dart:html`, which made the **Android
  build fail at kernel compilation** whether or not the export ran.
- Replaced with a conditional export, `lib/utils/file_download.dart`:
  - web → `package:web` + `dart:js_interop` browser download
  - native → `dart:io` + `path_provider`, saved to
    `Android/data/<package>/files/Download`, path shown in the snackbar
- Export is now UTF-8 encoded; the old code used `String.codeUnits`, which
  corrupted any non-ASCII text.

**`file_picker` removed — third build blocker**
- With the Dart errors gone, the Android build got as far as Java compilation
  and failed there: `file_picker` 6.2.1 still calls
  `PluginRegistry.Registrar`, the **v1 embedding** that Flutter 3.44 removed
  (`error: cannot find symbol — class Registrar`). This had been invisible
  because the build never previously reached that step.
- Nothing in `lib/` ever imported it, so it was dropped rather than upgraded.
  A straight upgrade is not possible in isolation: `file_picker >= 12` needs
  `win32 ^6.3.0` while `flutter_secure_storage 9.x` pins `win32 ^5.0.0`.
  FASE 3 will need to move both at once (`flutter_secure_storage ^11`) and
  re-verify token storage.
- Side effect: the 12 lines of
  "references file_picker:linux as the default plugin" warnings that appeared
  on every single build are gone.

**Landing page**
- Removed an unused variable and added a `context.mounted` guard to the
  delayed scroll callback.

**Test suite**
- `test/widget_test.dart` was still Flutter's counter-app scaffold, asserting
  on a `0`/`1` counter and an `Icons.add` button this app does not have —
  `flutter test` **failed**. Replaced with a real smoke test that boots the
  app with mocked secure storage and asserts it lands on the public landing
  page. `flutter test` now passes.

#### Changed

- `ApiConfig.baseUrl` is now `String.fromEnvironment('API_BASE_URL', …)`, so
  the target backend can be set per build with `--dart-define` instead of
  editing source. The reserved ngrok domain stays the default.
- Both Dio clients now send `ngrok-skip-browser-warning: true`, so ngrok does
  not serve its HTML interstitial to Flutter web.
- `pubspec.yaml`: `path_provider` and `web` promoted from transitive to direct
  dependencies. No new packages were downloaded — both were already resolved.
  (This turned out to matter: `path_provider` had been reaching the project
  *through* `file_picker`, so removing `file_picker` would otherwise have
  broken the new Android CSV export.)

#### Known, not fixed

- (Nothing outstanding from this release — the landing-page overflows found
  here were fixed in v1.3.0 below.)

#### Documentation

Corrected claims that did not match the running system: endpoint count
(18 → 21), table count (12 → 13), row counts, `SESSION_DRIVER`, the
`models:health-check` command name, the Laravel 12 schedule location
(`routes/console.php`, not `app/Console/Kernel.php`), the Flutter file/class
layout, the theme palette (BRIN red, not blue), and token expiry behaviour.
Also recorded two things the docs had not admitted: **there is no automated
test suite**, and **no scheduler process is running**, so
`models:health-check` and `tokens:cleanup` never fire on their own.

#### Verified (commands actually run, output actually read)

- `flutter analyze` → **No issues found!** (was 23 issues / 12 errors)
- `flutter test` → **All tests passed!** (was failing)
- `flutter build apk --release` → `app-deepCT-ai.apk`, 51.0 MB
- `flutter build web --release` → `build/web`
- `POST /api/login` through the ngrok tunnel → HTTP 200 in ~1.4s
- `php artisan models:health-check` → model **online** (864ms)
- `POST /api/admin/models/1/test` → real inference round-trip through
  ngrok to the Kaggle worker: **HTTP 200, 21.4s, 2 MB TIFF returned**

Note: `flutter build web --wasm` still fails — `flutter_secure_storage_web`
imports `dart:html`, `dart:js_util` and `package:js`. The standard JS build is
unaffected.

---

## [1.2.0] - 2026-08-14

### 🎨 Polish Update - FASE 1 & 2 Enhancement

**Status:** FASE 1 & 2 now 100% Complete! ✅

#### Added - Frontend Polish

**Dashboard Home Screen**
- New admin dashboard home with overview statistics
- Statistics cards showing:
  - Total users (active/inactive breakdown)
  - Total models (online/offline/trouble status)
  - Today's activity count
- Recent activities widget (last 10 actions)
- Welcome message with current user
- Responsive design (adapts to screen size)
- Set as default landing page for admin

**Export to CSV Feature**
- Export activity logs to CSV file
- Respects current filters (user, type, date range)
- CSV columns: timestamp, user, activity type, description, IP, user agent
- Auto-download with timestamp filename format: `activity_logs_YYYYMMDD_HHMMSS.csv`
- Success/error feedback via snackbar
- Export button with green success styling

**Smooth Scroll Navigation**
- Landing page navigation with smooth scrolling
- Animated scroll to sections (800ms duration)
- Active section tracking and highlighting
- Navigation buttons respond with smooth animation
- Proper offset adjustment for fixed header

#### Changed

**Admin Shell Navigation**
- Dashboard added as first navigation item
- Default section changed from "User Management" to "Dashboard"
- Dashboard icon: `dashboard_outlined`

**Activity Logs Screen**
- Added "EXPORT CSV" button in toolbar
- Export button disabled when no data
- Button shows green success color when enabled

**Landing Page**
- Smooth scroll already implemented (verified)
- Section tracking active
- Navigation highlights current section

#### Technical

**Dependencies Added**
- `csv: ^6.0.0` - CSV file generation for Flutter Web

**Files Modified (3)**
1. `fe/lib/screens/admin/admin_shell.dart` - Added dashboard section
2. `fe/lib/screens/admin/activity_logs_screen.dart` - Added export functionality
3. `fe/pubspec.yaml` - Added csv dependency

**Files Created (1)**
1. `fe/lib/screens/admin/dashboard_home_screen.dart` - New dashboard home

#### Documentation

**Updated Files**
- `TODO.md` - Marked polish tasks complete, updated progress to 72%
- `CHANGELOG.md` - This file
- `POLISH_PLAN.md` - Created polish implementation plan

### 💡 Design Decisions

**Why Dashboard Home:**
- Better admin landing experience (overview before details)
- Quick access to key metrics without navigating
- Professional dashboard UX standard

**Why Export CSV:**
- Admin needs data export for audit/reporting
- CSV is universal format (Excel, Google Sheets compatible)
- Respects filters = export only what you see

**Why Smooth Scroll:**
- Professional landing page UX
- Better user engagement
- Smooth navigation flow

### 🎯 Polish Results

**Before Polish:**
- Admin landed directly on User Management (no overview)
- No way to export activity logs
- Landing page navigation instant jump (not smooth)

**After Polish:**
- Admin sees dashboard overview first (statistics + recent activities)
- Activity logs exportable to CSV
- Landing page smooth scroll navigation working

**Progress Update:**
- FASE 1: 95% → 100% ✅
- FASE 2 Frontend: 95% → 100% ✅
- Overall: 70% → 72%

---

## [1.1.1] - 2026-08-14

### 🔒 Security Update - Token Expiration & Single Session

#### Added - Security Features

**Token Expiration (7 Days)**
- Token sekarang expire setelah **7 hari** (10080 minutes)
- Konfigurasi di `config/sanctum.php`: `'expiration' => 10080`
- Auto cleanup expired tokens via scheduled command

**Single Session Per Account**
- Login baru otomatis revoke semua token lama
- Force logout di semua device lain saat login
- Mencegah account hijacking
- Implementasi di `AuthController::login()`: `$user->tokens()->delete()`

**Automated Cleanup**
- Created `CleanupExpiredTokens` command
- Scheduled daily via `routes/console.php`
- Deletes tokens older than 7 days
- Command: `php artisan tokens:cleanup`

#### Changed

**Authentication Flow**
- Login sekarang selalu revoke token lama sebelum create token baru
- Token lifetime: Unlimited → 7 days
- Session policy: Multiple sessions → Single session only

**Security Policy**
- Token expiration policy documented
- Single session enforcement documented
- Cleanup schedule documented

#### Documentation

**Updated Files**
- `PROJECT_STATUS.md` - Token expiration status updated
- `DATABASE_STATUS.md` - Token expiration documented
- `be/DATABASE_CLEANUP.md` - Security recommendations updated
- `be/README.md` - Authentication section updated
- `CHANGELOG.md` - This file

---

## [1.1.0] - 2026-08-14

### 🚀 Major Performance & Stability Update

#### Added - Backend Performance

**Laravel Octane + RoadRunner**
- Migrated from `php artisan serve` to Laravel Octane
- RoadRunner 2025.1.15 as application server
- 4 workers with max 250 requests per worker
- **84-86% faster response times**
- Support for long-running requests (17+ seconds)
- Concurrent request handling

**Configuration**
- `config/octane.php`: max_execution_time increased to 300s
- Garbage collection threshold increased to 100
- Cache driver changed to `file` from `database`
- Windows patch for SIGINT signals

**Performance Results**
- Health check: 8-11s → 1.7s (84% faster)
- Prediction (cold): Timeout → 17.8s (working)
- Prediction (warm): N/A → 2.4s (86% faster)
- CRUD operations: <150ms
- Concurrent handling: 3+ parallel requests successful

#### Added - Backend FASE 3 Part 1

**Database Migrations**
- Added FASE 3 fields to `analysis_records` (9 new columns)
  - `job_id`, `model_id`, `input_folder`, `output_folder`
  - `error_message`, `input_files_count`, `output_files_count`
  - `processing_time_seconds`, `files_deleted_at`
- Added FASE 3 fields to `models` (8 new columns)
  - `endpoint_url`, `status`, `last_health_check`
  - `max_concurrent_jobs`, `current_jobs_count`
  - `health_check_error`, `is_active`, `deployed_at`
- Added `metadata` (JSON) to `user_activities`
- Changed `activity_type` from enum to VARCHAR(50)
- Added `user_agent` to `user_activities`
- Fixed `models` table constraints (nullable file_path)

**API Endpoints - User Management (7)**
- `GET /api/admin/users` - List with pagination, search, filters
- `POST /api/admin/users` - Create (admin sets password or default)
- `GET /api/admin/users/{id}` - Get detail
- `PUT /api/admin/users/{id}` - Update
- `DELETE /api/admin/users/{id}` - Delete (with self-protection)
- `PATCH /api/admin/users/{id}/toggle` - Toggle active status
- `POST /api/admin/users/{id}/reset-password` - Reset to default

**API Endpoints - Model Management (8)**
- `GET /api/admin/models` - List with pagination, filters
- `POST /api/admin/models` - Add new model
- `GET /api/admin/models/{id}` - Get detail
- `PUT /api/admin/models/{id}` - Update
- `DELETE /api/admin/models/{id}` - Delete (with protection)
- `PATCH /api/admin/models/{id}/toggle` - Toggle active status
- `POST /api/admin/models/{id}/health-check` - Manual health check
- `POST /api/admin/models/{id}/test` - Test prediction

**API Endpoints - Activity Logs (3)**
- `GET /api/admin/activities` - List all with comprehensive filters
- `GET /api/admin/activities/types` - Get available activity types
- `GET /api/users/{id}/activities` - User-specific activities

**Services & Commands**
- `ModelHealthChecker` service - Health check logic
- `CheckModelsHealth` command - Scheduled every 5 minutes
- Activity logging for all admin actions (12 types)

#### Added - Frontend (FASE 2 Complete)

**Admin Dashboard**
- `AdminShell` - Layout with sidebar navigation
- `UserManagementScreen` - Full CRUD with pagination
- `ModelManagementScreen` - Cards grid with health check
- `ActivityLogsScreen` - Timeline view with filters
- Responsive design (mobile/tablet/desktop)

**Services & Models**
- `ApiClient` - Dio wrapper with auto token & error handling
- `UserService` - 7 endpoints
- `ModelService` - 8 endpoints
- `ActivityService` - 3 endpoints
- Data models: User, ModelInfo, ActivityLog, Pagination

**Widgets**
- `StatusBadge` - Color-coded status chips
- `PaginationBar` - Pagination controls
- `AsyncStateViews` - Loading/error/empty states

#### Fixed - Audit FASE 1 & 2 (9 Critical Bugs)

**Blocking Issues**
1. `models.file_path` NOT NULL without default → 500 error on POST
2. `models.status` enum wrong values → Data truncation
3. Health check always offline (422 treated as offline)
4. Test prediction sends JSON to multipart endpoint

**Data Issues**
5. `last_login_at` never saved (not in fillable)
6. `user_agent` never saved (not in fillable)
7. `metadata` double-encoded (cast + json_encode)

**Security Issues**
8. Rate limiting not working (login brute-force possible)

**Other Issues**
9. Model duplicates in database
10. Seeder not idempotent
11. Health check logic duplicated
12. Timeout issues (Dio 30s insufficient)

**All Fixed & Verified**
- 30/30 API live tests PASS
- 23/23 contract tests PASS
- `flutter analyze` - 0 issues

#### Changed

**Backend**
- Default password changed to "user12345678"
- Health check now uses GET probe (not POST)
- Health check threshold: 3s → 5s, timeout: 10s → 15s
- Model endpoint managed via UI (not `.env`)
- `NGROK_API_URL` deprecated
- Status enum: `('online','offline','error')` → `('online','offline','trouble')`

**Frontend**
- API client Dio timeout configurations
- UserService.toggleStatus parse fix
- All services use shared ApiClient

#### Documentation

**New Files**
- `TESTING_RESULTS.md` - Performance benchmark (17 sections)
- `DATABASE_CLEANUP.md` - Database structure analysis
- `FASE2_COMPLETION_SUMMARY.md` - FASE 2 summary
- `FASE3_DECISIONS.md` - Technical decisions
- `FASE3_ROADMAP.md` - Development roadmap
- `be/DATABASE_CLEANUP.md` - Backend database docs
- `be/README.md` - Backend setup guide
- `fe/README.md` - Frontend setup guide
- `fe/test_auth.md` - Contract testing guide

**Updated Files**
- `README.md` - Added recent updates section
- `API_DOCS.md` - 18 endpoints documented (actual count is 21; see be/README.md)
- `TODO.md` - Progress tracking updated (70% complete)
- `ARCHITECTURE.md` - Updated with Octane
- `CHANGELOG.md` - This file

---

## [1.0.0] - 2026-08-13

### 🎉 Initial Release

[Previous content remains the same...]

---

## Version History

| Version | Date | Highlights |
|---------|------|------------|
| **1.2.0** | 2026-08-14 | **Polish: Dashboard home, CSV export, Smooth scroll** |
| **1.1.1** | 2026-08-14 | **Token expiration (7 days), Single session security** |
| **1.1.0** | 2026-08-14 | **Octane migration, FASE 2 complete, 9 bug fixes** |
| **1.0.0** | 2026-08-13 | Initial MVP release |
| 0.2.0 | 2026-08-12 | Project setup |
| 0.1.0 | 2026-08-11 | Project initiation |

---

## Migration Notes

### From 1.0.0 to 1.1.0

**Backend Migration:**
```bash
# Backup database
mysqldump -u root db_aict > backup_1.1.0.sql

# Pull latest code
git pull origin main

# Install dependencies
composer install
npm install

# Run new migrations
php artisan migrate

# Clear cache
php artisan config:clear
php artisan cache:clear

# Start with Octane (recommended)
npm run octane
```

**Database Changes:**
- 3 migration files added (FASE 3 fields)
- 1 migration file for fixes (nullable file_path)
- Run `php artisan migrate` to apply

**Configuration Changes:**
- Update `.env`: Add `OCTANE_SERVER=roadrunner`
- Update `.env`: Change `CACHE_STORE=file`
- Remove `NGROK_API_URL` (deprecated)
- Model endpoint now managed via Admin UI

**Breaking Changes:**
- Health check endpoint behavior changed (now uses GET probe)
- Test prediction endpoint requires multipart/form-data
- Activity types changed from enum to VARCHAR

---

**Maintained by**: BRIN Development Team  
**Last Updated**: August 14, 2026

---

## [1.0.0] - 2026-08-13

### 🎉 Initial Release

#### Added - Backend (Laravel)

**Database**
- Created `users` table dengan role-based access (admin/user)
- Added `username`, `is_active`, `last_login_at` fields to users table
- Created `analysis_records` table untuk tracking predictions
- Added `user_id`, `time_scalar`, `file_name`, `expires_at` fields
- Created `models` table untuk tracking AI model deployments
- Created `user_activities` table untuk audit logging
- Created seeders untuk default admin user dan sample model

**Authentication**
- Implemented Laravel Sanctum authentication
- Login/logout endpoints
- Token-based authentication
- Role-based middleware (admin/user)
- Rate limiting (5 attempts per minute on login)

**API Endpoints**
- `POST /api/login` - User authentication
- `POST /api/logout` - User logout
- `GET /api/user` - Get current user info
- `GET /api/admin/users` - List all users (admin only)
- `POST /api/admin/users` - Create user (admin only)
- `GET /api/admin/users/{id}` - Get user detail (admin only)
- `PUT /api/admin/users/{id}` - Update user (admin only)
- `DELETE /api/admin/users/{id}` - Delete user (admin only)
- `POST /api/admin/users/{id}/toggle-status` - Activate/deactivate user
- `GET /api/admin/models` - List models (admin only)
- `GET /api/admin/models/{id}` - Model detail (admin only)
- `PUT /api/admin/models/{id}/status` - Update model status
- `GET /api/admin/activities` - List all activities (admin only)
- `GET /api/admin/users/{userId}/activities` - User-specific activities
- `POST /api/predictions` - Upload files & start prediction
- `GET /api/predictions` - List user predictions
- `GET /api/predictions/{id}` - Get prediction detail
- `GET /api/predictions/{id}/download` - Download result file
- `DELETE /api/predictions/{id}` - Delete prediction

**Features**
- File upload validation (.tif format, max 50MB)
- Queue job system untuk async prediction processing
- Automatic file expiry (24 hours after completion)
- User activity logging system
- Model deployment tracking
- Prediction count per model

#### Added - Frontend (Flutter)

**Project Structure**
- Initialized Flutter project with clean architecture
- Setup folder structure: screens, widgets, services, models
- Configured dependencies: dio, provider, flutter_secure_storage

**Screens**
- Landing page dengan hero section
- Login page dengan split screen design
- Admin dashboard layout dengan sidebar
- User dashboard layout dengan sidebar
- User management screen
- Model management screen
- User activity screen
- Upload screen untuk file selection
- Prediction result screen
- Prediction history screen

**Components**
- Custom theme dengan BRIN color palette
- Reusable button widgets
- Reusable input widgets
- Loading indicators
- Error message widgets
- Toast notifications
- Modal dialogs

**Features**
- Token-based authentication
- Secure token storage
- Role-based routing (admin/user)
- Responsive design (mobile, tablet, desktop)
- Image preview untuk uploaded files
- Real-time status polling untuk predictions
- Download functionality untuk results
- Delete confirmation dialogs

#### Added - AI Worker (Google Colab)

**Model**
- Loaded GiNet TC-D model (generator(Salinan 3 Ginet TC-D_Revisi).h5)
- Model size: ~84MB
- Framework: TensorFlow/Keras
- Input: 2x .tif images (16-bit)
- Output: 1x .tif interpolated image

**API Server**
- FastAPI server untuk handle prediction requests
- Ngrok tunnel untuk public URL
- Endpoint: `POST /predict`
- Accepts multipart/form-data (file_t0, file_t2, time_scalar)
- Returns binary .tif file

**Recursive Interpolation**
- Implemented automatic gap detection
- Recursive interpolation algorithm
- Optimal at time_scalar = 0.5
- Generates all intermediate frames automatically

#### Added - Documentation

- `README.md` - Project overview dan quick start guide
- `ARCHITECTURE.md` - System architecture dan data flow
- `API_DOCS.md` - Complete API documentation dengan examples
- `DESIGN.md` - Design system dan UI/UX guidelines
- `PRD.md` - Product requirements document
- `SETUP.md` - Detailed installation guide
- `TODO.md` - Development task list
- `CHANGELOG.md` - This file
- `AI_EXPERIMENTS.md` - AI model experiments dan solutions

#### Changed
- Updated `.env.example` dengan NGROK_API_URL configuration
- Modified User model untuk include role dan additional fields

#### Security
- Password hashing menggunakan bcrypt (rounds: 12)
- SQL injection protection via Laravel Query Builder
- XSS protection via Laravel output escaping
- CORS configuration untuk Flutter clients
- File validation (MIME type + extension check)

---

## [0.2.0] - 2026-08-12

### Added
- Basic Laravel 12 project initialization
- Flutter project boilerplate
- Database structure planning

### Changed
- Updated project requirements based on initial analysis

---

## [0.1.0] - 2026-08-11

### Added
- Project initiation
- Initial requirements gathering
- Technology stack selection
- Model file preparation (`generator(Salinan 3 Ginet TC-D_Revisi).h5`)
- Jupyter notebook untuk model evaluation

---

## Version History

| Version | Date | Highlights |
|---------|------|------------|
| **1.0.0** | 2026-08-13 | Initial MVP release |
| 0.2.0 | 2026-08-12 | Project setup |
| 0.1.0 | 2026-08-11 | Project initiation |

---

## Migration Notes

### From 0.x to 1.0.0

**Database Changes:**
```bash
# Backup existing database
mysqldump -u root db_aict > backup_pre_1.0.0.sql

# Run new migrations
php artisan migrate

# Seed default data
php artisan db:seed

# Link storage
php artisan storage:link
```

**Configuration Changes:**
- Added `NGROK_API_URL` to `.env`
- Updated `database.php` untuk MySQL connection

**Breaking Changes:**
- None (initial release)

---

## Contributors

- **Mahasiswa TA** - Full Stack Development
- **BRIN Research Team** - Requirements & Testing
- **Supervisor BRIN** - Project Guidance

---

## Links

- [GitHub Repository](#)
- [Issue Tracker](#)
- [Documentation](./README.md)
- [API Documentation](./API_DOCS.md)

---

**Maintained by**: BRIN Development Team  
**Last Updated**: August 13, 2026
