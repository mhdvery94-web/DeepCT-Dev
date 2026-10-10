# Operasi dan deployment

## Produksi

| Komponen | Lokasi |
|---|---|
| Next.js | https://deepct-web.vercel.app |
| API Pi | https://zestfully-usable-pledge.ngrok-free.dev/api |
| Backend | Raspberry Pi, /var/www/deepct-ai, Octane port 8000 |
| GPU inference | Host terpisah; registry model menyimpan endpoint |

GitHub `main` memicu `web-next.yml` (Next.js) dan `release.yml`
(Flutter/artifact/Pi). Deploy Pi memerlukan backend tests lulus. Next deploy
memerlukan lint/typecheck/test/build/audit lulus. Root Vercel auto-deploy
dinonaktifkan; workflow mengendalikan project dan domain.

Variable `RASPI_API_BASE_URL` harus menunjuk HTTPS publik berakhiran /api.
Vercel tidak bisa menghubungi IP NetBird privat. Web server memakai
`LARAVEL_API_BASE_URL`; Flutter menerima `API_BASE_URL` saat build.
Secret Vercel, password seed dan worker token berada di konfigurasi server/
repository secrets. Jangan commit .env, APP_KEY, password atau token.

## Develop dan staging

Deploy web `develop` hanya memakai `DEVELOP_API_BASE_URL`; `staging` hanya
memakai `STAGING_API_BASE_URL`. Keduanya tidak fallback ke API produksi
`RASPI_API_BASE_URL` atau `NGROK_RASPI`. URL kosong melewatkan deploy develop
dengan warning dan menggagalkan deploy staging. `main` tetap memakai
`RASPI_API_BASE_URL`, dengan fallback `NGROK_RASPI`.

Sebelum staging, siapkan API HTTPS publik berakhiran `/api`, database/storage
terisolasi, akun uji kedua role, serta queue dan scheduler staging. Endpoint
GPU/model staging harus disepakati dan dipisahkan dari pekerjaan produksi.
Atur `STAGING_API_BASE_URL` dan credential/project Vercel di repository settings;
jangan menunjuk staging ke database, storage atau API produksi. Build CI memakai
API loopback hanya untuk verifikasi build; itu bukan endpoint deployment.

Flutter `release.yml` mengikuti variable preview yang sama. Tanpa URL preview,
preflight gagal sebelum build/deploy client. Override manual `api_base_url`
hanya berlaku pada `main` atau tag versi `v*`; branch lain tidak fallback ke
produksi. Deploy backend Pi hanya diizinkan dari `main` atau tag versi `v*`,
termasuk workflow manual; manual `develop`/`staging` tidak dapat deploy Pi.

## Proses server

API, queue dan scheduler harus sama-sama hidup. `npm run serve:all` di be
menjalankan ketiganya untuk pengembangan. Produksi memakai PM2/systemd dan
workflow runner Pi. Tanpa queue, prediksi menetap pending; tanpa scheduler,
retensi/token cleanup/probe model tidak berjalan.

Queue supervisor menggunakan memory_limit PHP 1 GiB, worker memory 768 MiB,
timeout 7200 dan tries 1. Scheduler memprobe model tiap menit, membersihkan
token tiap hari serta output prediksi tiap jam. Host GPU memiliki timeout
dan masa sesi sendiri; model offline bukan kegagalan akun.

Queue CT memakai connection `database` / queue `default`. Lease `retry_after`
minimal 7260 detik, termasuk jika `DB_QUEUE_RETRY_AFTER` lama bernilai lebih
kecil; nilai lebih besar tetap dihormati. Job CT memiliki timeout 7200 detik,
sehingga worker lain tidak mengambil ulang job yang masih berjalan. Setelah
upgrade, bangun ulang config cache dan reload worker melalui prosedur server.

Connection `llm` memakai driver database dan queue `llm` terpisah, lease 360
detik untuk job/worker dengan timeout 300 detik. Worker khusus memakai
`php artisan queue:work llm --queue=llm --timeout=300 --tries=1`; jalankan saat
fitur LLM diaktifkan. Worker CT tetap hanya mengonsumsi queue `default`.

## Urutan rilis dan backup

1. Checkout/rsync source tanpa menimpa .env, storage, vendor dan binary server.
2. Install dependency, backup MySQL ke storage/backups sebelum migrasi.
3. Jalankan migrate --force dan app:cleanup-retired-data.
4. Bangun config/route cache; restart/reload API, queue dan scheduler.
5. Jalankan health dan be/scripts/smoke-portal.php terhadap API yang sudah restart.

Perintah smoke membuat token sementara untuk akun aktif kedua peran lalu
mencabutnya. Ia memeriksa endpoint nyata, hak akses, skema akhir dan route
yang dipensiunkan. Jangan seed/reset akun produksi untuk sekadar mengecek API.
Backup lokal Pi bukan pengganti backup terpisah di luar Pi.

Migration historis `2026_10_05_170847_purge_all_models` sekarang sengaja no-op
pada `up` dan `down`: upgrade tidak boleh menghapus registry model aktif atau
mengosongkan relasi prediksi/activity. Migration yang sudah tercatat tidak
dijalankan ulang; perubahan ini melindungi instalasi yang belum menjalankannya
dan replay. Data yang pernah dihapus hanya dapat dipulihkan dari backup yang
sesuai. Perubahan ini tidak mengembalikan managed training.

Penghapusan training bersifat irreversible melalui migration rollback.
Pemulihan membutuhkan SQL backup sebelum migrasi dan source rilis sebelumnya.
Pulihkan dalam maintenance window dengan queue dihentikan; jangan membuat tabel
kosong lalu menganggap data sudah pulih. Cleanup file lama tidak menghapus
prediksi, berita/evidence maupun upload aktif prediksi.

## Storage

File prediksi berakhir setelah 24 jam; rekaman/evidence dipertahankan.
Cleanup admin menolak pekerjaan aktif dan mount yang tidak tersedia.
`STORAGE_HEADROOM_MULTIPLIER` default 3 dan `STORAGE_MINIMUM_FREE_BYTES`
default 2 GiB. Jika memakai NAS, buat sentinel dengan `php artisan storage:mark`
lalu aktifkan `STORAGE_REQUIRE_SENTINEL`. Jangan menulis ke mount kosong.
Di portal, cleanup rutin mengikuti expiry dan stale temporary uploads/downloads.
Cleanup per-job hanya untuk completed/failed dan dapat menghapus file sebelum
expiry. Unduh hasil yang dibutuhkan lebih dahulu, periksa dataset/pemilik, lalu
centang konfirmasi. Rekaman, evidence, akun/database, news/media, backup, OS dan
bobot model TUF tidak dihapus. Angka disk mencakup volume, bukan hanya DeepCT.

## Telepon dan reset akun

Rilis form telepon memerlukan migration
`2026_10_09_040000_add_phone_to_access_requests`. Kolom nullable menjaga
kompatibilitas request Flutter lama. Akun lama tanpa telepon perlu dilengkapi
admin melalui pengelolaan akun sebelum memakai pencarian reset email+telepon.
Inbox menampilkan permintaan yang cocok, tetapi admin tetap harus memverifikasi
pemilik sebelum memakai aksi reset password. Tidak ada OTP/provider email baru.

## Diagnosis singkat

Probe pertama: `curl -fsS https://zestfully-usable-pledge.ngrok-free.dev/api/health`.

- Route tidak sesuai source: `php artisan route:clear`, lalu restart/reload
  worker Octane. route:list sendiri tidak membuktikan proses lama membaca kode baru.
- Environment tidak berubah: jalankan config:cache lagi dan reload proses.
- Windows: Octane stop/reload menggunakan POSIX dan bisa gagal. Gunakan
  `npm run octane:reset`; jangan menghapus/membunuh proses lain sembarangan.
- Login gagal: cek akun aktif, kewajiban ganti password, token expiry dan log.
- Unduhan ditolak: cek ownership, lifecycle, expiry dan checksum.
- Worker menolak: credential platform dan WORKER_TOKEN di worker harus cocok;
  jangan mematikan TLS untuk menyamarkan konfigurasi yang salah.
- Laptop NetBird: VPN laptop aktif belum membuktikan environment Codex punya
  route/TCP grant. Sinkronisasi laptop hanya dilakukan setelah SSH dapat diakses.

Bukti rilis terakhir dan pekerjaan terbuka: [CHECKPOINT.md](CHECKPOINT.md).
