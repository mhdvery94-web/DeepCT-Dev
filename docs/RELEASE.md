# Rilis registry/upload dan assistant

## Gate dan status

Task 7 menyiapkan konfigurasi yang dapat ditinjau; perubahan source Tasks 1–7
belum merupakan bukti deployment publik. Controller melakukan operasi Pi/TUF,
review seluruh branch, promosi Git dan Vercel. Jangan membuat worktree baru;
gunakan checkout yang sudah disiapkan. Commit base Task 7:
`fcd6af9db02e10637d30d65155c7e6dbcc6fd700`.

`release.yml` menjalankan Flutter dan Laravel tanpa path filter; deploy Flutter,
Pi dan publikasi artifact menunggu `test-model-cpu` selain gate sebelumnya.
`web-next.yml` berjalan pada setiap push/PR develop, staging dan main, termasuk
model-only changes; deploy Next menunggu verify dan CPU. Penghapusan path filter
menambah biaya CI untuk perubahan docs/backend. Required branch checks harus
menunjuk kedua workflow dan job Python 3.11 CPU, Laravel, Flutter, Next. GitHub
branch protection/environment approval adalah konfigurasi eksternal yang masih
harus diperiksa controller. CI hijau bukan persetujuan scientific GPU atau UAT.

Preview develop/staging hanya memakai variable API branch sendiri. Jangan
menambah fallback ke produksi atau override manual untuk preview. Release
backend produksi tetap hanya main/tag v*. Develop -> staging setelah CI/review;
staging -> main hanya setelah UAT, backup/restore dan rollback diterima.

Assistant produksi tetap `AI_ASSISTANT_ENABLED=false`: kelima quality cases nyata
DeepSeek 1.5b gagal. Latency/health dan synthetic-provider tests tidak menggantikan
quality gate. Pi belum mendeteksi Hailo; Hailo 8/8L bukan dukungan LLM resmi.
Runtime GPU compiled versus legacy memiliki maxabs 1 dan 126 piksel berbeda dari
1.048.576; belum ada toleransi scientific yang disetujui.

## Dependensi Python yang dibekukan

Dari `deepct-model-server/`, Python 3.11 CPU CI menjalankan:

```sh
python -m pip install --require-hashes -r requirements-cpu.lock
python -m pip check
python -m pytest -q
```

Job juga menolak package TensorFlow/NVIDIA. Tidak ada GPU, weights atau download
model. `requirements-cpu.lock` diekspor dari `uv.lock`, dengan dev dependencies:

```sh
uv export --locked --no-emit-project --format requirements-txt --no-header --output-file requirements-cpu.lock --quiet
```

Lock privat lama hanya referensi; lock repository mempertahankan TIFF
`2025.5.10` sesuai project. `requirements.lock` tetap profil inference dasar.
Untuk GPU Linux x86_64/Python 3.11, `requirements-cuda.in` menggunakan extras
resmi `tensorflow[and-cuda]==2.17.0`. Seluruh 52 core pins tetap sama; 12 package
NVIDIA ditambahkan. Reproduksi resolver tanpa mengubah core lock:

```sh
uv pip compile --python-version 3.11 --python-platform x86_64-manylinux_2_17 --generate-hashes --constraint requirements.lock requirements-cuda.in --output-file requirements-cuda.lock
```

Di TUF, hanya venv staging baru `/home/jihyo-yue/deepct-model-staging/.venv`:

```sh
cd /home/jihyo-yue/deepct-model-staging
.venv/bin/python -m pip install --require-hashes -r requirements-cuda.lock
.venv/bin/python -m pip check
.venv/bin/python -c 'import tensorflow as tf; devices=tf.config.list_physical_devices("GPU"); print(tf.__version__, devices); assert devices, "CUDA unavailable"'
```

Jalankan melalui containment staging, lalu uji compatibility child dengan budget
GPU 5 GiB, RLIMIT_AS 24 GiB, cgroup MemoryMax 4 GiB, MemorySwapMax 0 dan TasksMax
128. Base TensorFlow di venv ini sebelumnya melaporkan GPU `[]`; `pip check`
tidak membuktikan CUDA. Jangan install ke Conda lama atau mengganti driver.
Kegagalan device/loader/containment adalah gate tertutup, bukan alasan fallback
CPU. Bukti instalasi dan parity nyata dicatat controller secara terpisah.
Sumber extras: https://www.tensorflow.org/install/pip.

## Pi staging terisolasi

Aplikasi `/home/jihyo/deepct-staging/app`, database `deepct_staging`, user DB baru
hanya untuk database itu, APP_KEY baru, storage/cache/session/log/backup sendiri,
dan dua akun uji aktif (admin/researcher). Salin source terpilih dari checkout
reviewed; jangan salin `.env`, akun, SQL atau storage produksi. Jangan seed/reset
akun produksi. Saat memperbarui staging, rsync harus melindungi `.env`, `.env.*`,
`storage/`, `vendor/`, `node_modules/`, `rr`, `.rr.yaml`, `public/storage`,
`public/build` dan `auth.json` dari overwrite/delete.

Buat `.env` staging dari `be/.env.example` dengan credential baru melalui kanal
operator privat, permission 0600. Set APP_ENV=staging, APP_DEBUG=false,
DB_DATABASE=deepct_staging, CACHE_PREFIX=deepct_staging, cookie name sendiri,
APP_URL URL prefix staging, QUEUE_CONNECTION=database dan
AI_ASSISTANT_ENABLED=false. Cache file/storage dan database queue dipisah oleh
app root/DB sendiri. Token TUF inference/management berbeda dan hanya milik
staging. Set `TUF_INTERNAL_URL=http://100.85.210.125:8001` (root tanpa prefix),
`TUF_PUBLIC_UPLOAD_URL=https://<domain-TUF-existing>/registry`, dan browser upload
origins tepat ke origin Vercel staging (tanpa wildcard).

Setelah backup staging (bukan produksi), dari direktori app:

```sh
composer install --no-dev --optimize-autoloader --no-interaction --no-progress
mkdir -p storage/app/private storage/app/public storage/framework/cache/data storage/framework/sessions storage/framework/views storage/logs storage/backups
php artisan migrate --force
php artisan app:cleanup-retired-data
php artisan config:cache
php artisan route:cache
```

Gunakan RoadRunner yang disiapkan untuk staging, bukan binary/config yang dicopy
dengan credential produksi. Unit terpisah di `be/deploy/staging/`:
`deepct-staging-api` (private 100.85.94.74:8001), `deepct-staging-queue` (CT/default)
dan `deepct-staging-scheduler`. Install sebagai system units, verify di Pi,
lalu daemon-reload/restart hanya tiga unit ini. Tidak ada LLM worker baru selama
fitur tetap disabled. Queue staging memakai DB sendiri; jangan memakai Redis/
queue produksi. Unit gateway keempat hanya ditambah untuk cutover prefix.

## TUF staging dan gateway

Source/venv berada di `/home/jihyo-yue/deepct-model-staging`; `models/`, `state/`,
`.incoming` dan tokens staging terpisah dari original workers. Upload/publish
weights melalui alur authorized; tidak ada weights di Git. `deploy/staging.env.example`
memiliki budget yang diuji dan token kosong; operator membuat `staging.env`
0600 dengan token baru yang berbeda. Buat `models/` dan `state/` 0700, awal
activation `{"active":[]}`. Jangan menimpa activation/state saat refresh source.

Install `deepct-model-staging.service` dan `deepct-model-gateway.service` sebagai
user units **jihyo-yue**; keduanya pengguna yang sama, UMask 0077. Worker satu
process/no reload mendengar Unix socket `state/worker.sock`. Private gateway
mendengar hanya 100.85.210.125:8001; public gateway hanya 127.0.0.1:8003.
Tidak ada local hop ke self-100IP dan tidak ada perubahan firewall: Pi -> TUF
private health 200 sudah terbukti; kegagalan TUF self-100IP adalah urutan chain
Tailscale/UFW, bukan kegagalan peer path.

Sediakan binary Caddy resmi yang checksum-nya diverifikasi sebagai
`bin/caddy`; gunakan `deploy/Caddyfile.staging` sebagai `Caddyfile`. Caddy private
meneruskan semua route via UDS; bearer/ownership aplikasi tetap berlaku. Public
`/registry/uploads/*` saja diteruskan (strip `/registry`, limit **4MiB**); management,
models dan prediction di bawah prefix menjawab 404. Default tetap worker legacy
127.0.0.1:8000. Existing worker/notebook/Conda tetap berjalan.

Pi `be/deploy/staging/Caddyfile.staging` meneruskan `/staging/*` ke API private
100.85.94.74:8001 dan route biasa ke legacy 127.0.0.1:8000. Tunnel TLS existing
baru boleh diubah upstream ke loopback 8003 setelah semua local/peer checks
berikut lulus. Public URL/domain baru tidak diasumsikan tersedia.

## Pemeriksaan dan cutover controller

Sebelum perubahan, catat exact source commit, hashes lock/Caddy/unit, versi binary,
status unit lama/baru, ingress upstream sebelumnya, env/DB/storage path (tanpa
nilai credential), dan baseline HTTP. Backup DB staging sebelum migrate dan
simpan backup off-host terlindungi; jangan commit SQL/env/token/state/weights.
Snapshot source rilis sebelumnya, config gateway/unit, activation dan upload state
staging secara konsisten setelah drain job. State backup mengandung capability,
jadi perlakukan sebagai credential. Uji restore DB/storage/state di lingkungan
terisolasi sebelum menyebut rollback tervalidasi.

```sh
# TUF, sebagai user staging; jalankan sebelum cutover tunnel
bin/caddy adapt --config Caddyfile --adapter caddyfile --validate
systemd-analyze --user verify ~/.config/systemd/user/deepct-model-staging.service ~/.config/systemd/user/deepct-model-gateway.service
systemctl --user daemon-reload
systemctl --user restart deepct-model-staging deepct-model-gateway
curl --fail --unix-socket state/worker.sock http://localhost/
# Pi peer, tanpa credential di command/log
curl --fail http://100.85.210.125:8001/
# Pi local gateway dan default legacy harus keduanya health 200
curl --fail http://127.0.0.1:8003/staging/api/health
curl --fail http://127.0.0.1:8003/api/health
```

Authenticated checks memakai client/operator credential file privat, tanpa print
bearer di log. Pastikan inference bearer menolak management dan sebaliknya;
public `/registry/management/...` 404; invalid/revoked upload capability ditolak;
4MiB chunk diterima, 4MiB+1 ditolak 413; origin/CORS PUT/OPTIONS benar. Uji browser
staging kedua role: login, upload/resume/finalize/compatibility/inactive publish,
activation hanya setelah authorization/acceptance, CT queue/result TIFF/download,
revocation/outage dan rollback. UAT client fisik Flutter belum dilakukan.

Setelah local + private checks, catat backup konfigurasi tunnel, ubah upstream
existing ke 127.0.0.1:8003, dan periksa HTTPS legacy `/api/health` serta staging
`/staging/api/health` dan TUF upload prefix. Set STAGING_API_BASE_URL dan
DEVELOP_API_BASE_URL ke endpoint preview yang tepat berakhiran `/api`; jangan
pakai endpoint produksi untuk preview. Promosi tidak dilakukan oleh dokumen ini.

ngrok Free: dokumentasi yang diperiksa 11 Oktober 2026 menyebut 1 GB transfer out/
bulan, 20.000 HTTP request/bulan, satu dev domain, hingga tiga online endpoints.
URL statis tetap memiliki quota. Periksa plan/usage akun aktual sebelum klaim
beban berkelanjutan. Sumber: https://ngrok.com/docs/pricing-limits/free-plan-limits.

## Rollback

1. Tutup admission staging/fitur baru dan drain/hentikan hanya worker staging.
   Tetapkan AI_ASSISTANT_ENABLED=false, rebuild config cache, reload API staging.
2. Jika ingress/prefix gagal, kembalikan **upstream tunnel lama** terlebih dahulu,
   lalu konfirmasi HTTPS health legacy. Original API/worker tidak dihentikan.
3. Kembalikan source/lock/unit/Caddy yang tercatat; verifikasi dependency hashes,
   socket ownership dan health sebelum membuka staging lagi. Untuk CUDA yang gagal,
   kembali ke venv staging sebelumnya atau biarkan compatibility unavailable;
   jangan menyentuh Conda/driver produksi.
4. Kembalikan activation/registry staging hanya ke snapshot tuple immutable yang
   diketahui; jangan otomatis mengaktifkan candidate. Simpan artifacts/uploads
   untuk diagnosis, jangan menghapus weights original.
5. Jika migrasi data perlu dibatalkan, restore backup DB/storage/state staging
   yang konsisten dengan source sebelumnya. Migration training yang retired tidak
   dapat memulihkan data; jangan mengandalkan `migrate:rollback` untuk pemulihan.
6. Catat commit, HTTP checks, backup/restore dan status gate. Promosi main tetap
   tertutup sampai UAT scientific, upload arbitrary model dan quality LLM diterima.

Minor yang ditriase: Node MODULE_TYPELESS_PACKAGE_JSON muncul saat direct
TypeScript imports; test/lint/typecheck/build lulus. Perubahan module type global
berisiko ke config CJS, sehingga ditunda. Flutter Wasm dry-run memiliki batas plugin/web
dan bukan verifikasi device. GSAP portal-target warnings belum mengubah hasil
browser assertions; ditunda tanpa mengklaim output bersih. Tidak ada perubahan
BRIN layout atau replay retired-training cleanup di Task 7.

Pemeriksaan lokal konfigurasi menggunakan Python/PyYAML 6.0.3, actionlint 1.7.9
dan Caddy 2.11.7: `actionlint .github/workflows/*.yml` lalu
`CADDY_BIN=/path/to/caddy python -m unittest discover -s .github/tests -v`.
Gateway tests memakai controlled upstream fixtures; bukan bukti live-host GPU,
authenticated UAT atau public TLS. Sistem host harus memverifikasi unit/path
executable-nya sendiri sebelum restart.
