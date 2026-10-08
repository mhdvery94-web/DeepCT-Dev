# 📅 Changelog

> Entri lama adalah catatan historis. Kontrak aplikasi 9 Oktober 2026 hanya prediksi;
> fitur training telah dipensiunkan. Kelanjutan agen: [checkpoint](handoff.md).

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

### Changed
- Make the application prediction only for administrators and researchers.
  Remove web/Flutter training UI, backend routes/controllers/models, scheduler
  commands, worker scripts and training upload branches.
- Remove legacy training schema/data and trainer registry entries through an
  upgrade migration. Keep inference models and predictions; run scoped retired
  file cleanup after the deployment database backup and migration.
- Separate Research news article editing from image and video management.
  Each media has its own picker, preview, upload, size guidance and removal.
  Videos continue to use resumable chunks.
- Soften web fields/buttons with rounded corners, spacing and focus/hover
  feedback. Preserve responsive portal scrolling and section fitting.
- Update Markdown contracts and agent checkpoint; remove obsolete implementation
  proposals. Historical experiment results remain research records.
- Verify 329 Laravel tests/1,381 assertions, five proxy tests, lint/TypeScript,
  Docker production build and production dependency audit (zero findings).
- Pass 51 browser checks against the running isolated Laravel API: five public
  viewport sizes, both role dashboards/modules, full articles, public forms,
  removed routes, independent news media and prediction upload/preview/start.

## [2026-10-08] — Portal implementation before prediction-only retirement

### Added
- Connect Next.js portal modules to Raspberry Pi Laravel APIs: account/model/news
  CRUD, access reviews, messaging, activity export, notifications, profile photos,
  prediction upload/preview/start/comparison, and training progress/metrics/samples.
  Restore role-scoped researcher training, optional model catalogue sync, and the
  administrator queue board with their regression suites.
- Add administrator disk management with volume totals, application breakdown,
  retention cleanup and explicit file removal for completed/failed predictions.
  Preserve history/evidence and reject active work, missing mounts and invalid
  directories. Exclude pending/processing predictions from scheduled retention.
- Add public full-article URLs, request-access and password-reset request pages.
  Password reset requests reach the admin inbox; issued-password replacement and
  identity review remain enforced. Remove public vendor credit and duplicate footer
  navigation as requested.
- Bound web upload chunks to 3 MiB and resume by server offset. Redirect large
  prediction/weight downloads to five-minute signed API URLs, with ownership and
  active-account checks, instead of proxying artifacts through Vercel.
- Add platform-wide admin statistics and a post-deploy read-only API smoke script;
  temporary test tokens are revoked even on failure. Public section minimum heights
  track the viewport/header and the portal scrolls inside a bounded main area.
- Validate proxy origins using the public Host and external scheme. Browser tests
  found that Next's internal URL hostname rejected legitimate form submissions;
  regression checks preserve rejection of foreign/malformed origins.
- Validate against isolated MySQL with 396 Laravel tests/1,593 assertions,
  5 proxy-origin tests, lint/TypeScript, a Docker production build, dependency
  audit and 30 running-API smoke checks. All 48 browser checks pass, covering
  five viewport sizes, full articles, public forms, admin modules, researcher
  modules, TIFF upload/preview/start, training submission/cancellation and roles.
- Deploy commit `998df0f` from `main` to production on 8 October 2026. Next.js
  workflow `37819384528` succeeded; release `37819384429` backed up the Pi database,
  refreshed caches and restarted its API. All 30 post-restart portal API/role
  checks and 20 public web/API HTTP checks passed. The live article contains
  13 paragraphs. Laptop SSH remains blocked by missing executor VPN/TCP setup;
  real GPU prediction/training acceptance is still pending.

### Changed
- Rebuild the Next.js landing around the supplied Bootslander template: compact
  two-column hero, layered waves, animated SVG CT panels, about/icon boxes,
  research news and access-request form. Preserve Home, About, Research, Join
  and Login; omit unrelated template sections. Adapt the supplied Freepik flat
  dashboard artwork into an icon rail, overview panels, four live statistic
  tiles and module/workflow lists using BRIN red/navy colors and existing BRIN
  assets. Keep template attributions and add `fajriansyah #bocahunpam` to both
  footers. Browser checks of landing and admin/user dashboards at 320, 390,
  600, 768, 820, 1,024 and 1,440 px found no horizontal overflow or JavaScript
  errors. Local fixture checks cover stable image/video framing, navigation,
  forms, login/logout, role guards, empty/unavailable stats and reduced motion;
  lint, TypeScript, production build and dependency audit pass.
- Validate existing tokens through Laravel before redirecting away from login,
  instead of using cookie presence alone, fixing the expired-session redirect
  loop between login and dashboard without weakening protected-route checks.
- Tighten the Next.js landing hero after mobile review: remove the viewport-height
  minimum that left a large empty band below navigation, keep the tablet hero in
  a compact two-column composition, and compress mobile actions, metrics and CT
  preview without horizontal overflow. Replace the old DeepCT-AI artwork with a
  CSS-rendered scanner animated by GSAP—rotating reconstruction slices, opposing
  orbital markers, a pulsing core, scan sweep and floating research panels—with
  a static reduced-motion fallback. Browser checks at 390, 820 and 1,440 px
  observed hero heights of 870, 641 and 750 px respectively; the earlier mobile
  and tablet layouts measured 1,331 and 1,259 px.
- Allow the staging Next.js deployment to reuse the configured Raspberry Pi API
  when a dedicated `STAGING_API_BASE_URL` is unavailable. This is an explicit
  temporary deployment choice: staging logins and admin mutations use the same
  production database until a separate staging backend is configured.
- Refresh the Next.js landing page and authenticated dashboard around the BRIN
  visual system, using the supplied gradient-landing and flat-dashboard files
  as compositional references. The new interface adds a CSS-rendered CT command
  console, stronger research-news and onboarding layouts, icon-led navigation,
  live API-backed dashboard KPIs, analysis distribution, model-readiness state,
  and responsive workflow panels. GSAP powers scoped, self-cleaning hero,
  scroll and route transitions with a reduced-motion fallback. Desktop, tablet
  and mobile browser checks found no horizontal overflow or console errors; the
  Freepik attribution required by the reference archives is retained in the
  landing footer.
- Let the Next.js deployment workflow resolve—or create—the dedicated
  `deepct-web` project when its project-ID secret has not been added yet, then
  enforce Vercel Root Directory `fe_web` and the Next.js framework through the
  authenticated Vercel API before building. Development previews may reuse the
  existing Raspberry Pi API variable until a separate development endpoint is
  configured; staging still requires its own API URL. Automatic Vercel Git
  builds are disabled inside `fe_web`, leaving GitHub Actions as the sole
  publisher and preventing duplicate deployments. Bootstrap run `37706342986`
  created the project, built the precompiled Next.js output and published
  `https://deepct-web.vercel.app`; the landing page and login returned 200, an
  anonymous dashboard request redirected to login, the session route returned
  401, and live research news from the Raspberry Pi API appeared on the page.
- Add the first Next.js 16 web-client slice under `fe_web`: a responsive BRIN
  landing page, a desktop/tablet research-news media stage that switches image
  and video without stacking oversized players, a Sanctum login held in an
  `HttpOnly` cookie, a same-origin Laravel BFF, secure server-side user/role
  checks, forced-password-change flow, portal shell and module routes. ESLint,
  TypeScript, a 21-route production build and local HTTP smoke checks pass.
- Establish the intended `develop` → `staging` → `main` promotion path and add
  an isolated Next.js Vercel workflow. The new web project reuses the Vercel
  account/token if desired but requires its own
  `DEEPCT_WEB_VERCEL_PROJECT_ID`; `main` remains the only branch allowed to
  deploy Laravel to the Raspberry Pi.
- Complete the application cutover to the new Vercel project and Raspberry Pi
  backend. Release run `36853332173` built every supported target, deployed the
  backend locally on the ARM64 runner, and published the prebuilt Flutter web
  output to `https://deep-ct-ai-prod.vercel.app`.
- Add an opt-in `bootstrap_users` workflow dispatch. It reads administrator and
  researcher passwords from repository secrets, seeds both roles without
  persisting credentials in Laravel's config cache, waits for Octane's health
  route after PM2 reload, and verifies each account through a real login.
- Allow the production seeder to create or update one explicit researcher from
  `SEED_USER_EMAIL`/`SEED_USER_PASSWORD`, require the pair atomically, and mark
  both bootstrap roles as verified. Add regression coverage for stale cached
  config, idempotent updates, production researcher creation and incomplete
  credentials.
- Record repeatable white-box and production black-box/UAT scenarios in
  `WHITE_BOX_TESTING.md` and `USER_ACCEPTANCE_TESTING.md`. On 1 October the
  backend suite passed 385 tests/1,536 assertions, Flutter passed 276 tests with
  clean analysis, and the live API passed 12/12 authentication/authorization
  checks.
- Disable Vercel's automatic Git deployments at the repository root. The
  connected Vercel project must use Root Directory `./`; GitHub Actions remains
  the only publisher and sends the already-built Flutter bundle with
  `vercel deploy --prebuilt`, preventing Vercel from misdetecting `be/` as a
  Vite application and looking for a nonexistent `dist/` directory.
- Run the Raspberry Pi backend and public tunnel under PM2. `deepct-app` owns
  `npm run serve:all` (Octane, the database queue worker and scheduler), while
  `deepct-ngrok` exposes port 8000. The saved PM2 process list is now owned by
  the enabled `pm2-jihyo.service`; the previous Supervisor programs were
  stopped and their configuration was retained only as a disabled rollback
  copy.
- Register the ARM64 `deepct-raspi` GitHub Actions runner as a system service
  and deploy the backend locally on the Pi. The release job installs production
  npm dependencies, reloads `deepct-app`, leaves the independent tunnel alive,
  saves the PM2 process list, and verifies the database-backed `/api/news`
  endpoint before reporting success.
- Publish the Raspberry Pi API at
  `https://zestfully-usable-pledge.ngrok-free.dev/api` and set it as the
  repository variable `RASPI_API_BASE_URL`. After a PM2/systemd handoff both
  `/api/health` and `/api/news` were observed returning HTTP 200 through the
  public HTTPS tunnel.
- Support one FastAPI/ngrok domain serving many inference models. Admin **Sync
  Models** checks the server root, imports `GET /models`, upserts by unique slug,
  preserves local activation/credentials, and records a separate prediction
  path and weights filename for every model. Prediction and test calls now use
  `full_endpoint_url`, require a TIFF response, and distinguish worker 404, 422,
  500, timeout and connection failures.
- Bootstrap the current local backend working tree on the Raspberry Pi at
  `/var/www/deepct-ai`: PHP 8.2, MariaDB 10.11, nginx, ARM64 RoadRunner and the
  Octane/queue/scheduler Supervisor programs are running. All migrations report
  `Ran`; `/api/health` and database-backed `/api/news` were observed returning
  200 through nginx and from the development machine over NetBird. At this
  initial bootstrap checkpoint the Pi database was empty and the runner,
  tunnel, Vercel project and account bootstrap were still outstanding; the
  later entries above record their completion.
- Prepare the release workflow for a `deepct-raspi` self-hosted ARM64 runner,
  remove the VPS SSH secrets and hard-coded old API fallback, and select the
  backend solely through `RASPI_API_BASE_URL`.
- Make fresh-server provisioning install Composer dependencies before the first
  Artisan command, resolve the PHP binary under `set -u`, protect `.env` with
  mode 600, and create Laravel's production caches.

### Fixed
- Coerce the new `worker_active` flag to a database-safe boolean when checking
  legacy model rows that were instantiated before their defaults were loaded.
- Enforce inactive-account and issued-password restrictions on every authenticated API request; revoke tokens on disable or reset.
- Reject oversized ZIP expansion, too many input frames, and duplicate flattened frame names before extracting; check direct training uploads against available storage.
- Clean prediction, evidence and temporary upload files when an account is deleted; refuse deletion while its jobs are active.
- Read native prediction uploads by range and verify streamed downloads before publishing them. Expose the checksum header to browser clients.
- Align the API, architecture, backend and frontend guides with the explicit prediction START step, current routes, account rules, ZIP limits and platform-specific streaming behavior.

### Planned Features (FASE 3+)
- Batch processing untuk multiple file pairs
- Email notifications untuk expiry warnings
- Real-time updates menggunakan WebSocket/Pusher
- Export reports (PDF, CSV)
- Dark mode
- Multi-language support

---

## [1.42.0] - 2026-09-08

### BAB IV dan BAB V naskah skripsi diperdalam

Naskah skripsi lima bab sebelumnya memperlakukan pengujian sebagai satu tabel
hasil dan satu tabel perintah. Itu memadai untuk seminar proposal, tetapi
menyembunyikan cara kasus ujinya dipilih dan tidak menunjukkan satu pun cabang
keputusan yang benar-benar diperiksa.

**Pengujian black box** kini menyatakan tekniknya. Partisi ekuivalensi memetakan
delapan masukan utama menjadi kelas sah dan tidak sah, kasus ujinya diambil satu
wakil per kelas sehingga tumbuh dari 14 menjadi 30 skenario, dan analisa nilai
batas menambah 11 pengujian tepat pada tepi setiap kelas. Tiga di antaranya
menyentuh mekanisme rekursi: celah selebar satu harus berhenti tanpa
membangkitkan apa pun dan bukan menjadi galat, celah selebar dua menghasilkan
satu frame bergenerasi 1, dan celah selebar empat menghasilkan tiga frame yang
tingkat kepercayaannya tidak sama.

**Pengujian white box** kini benar-benar membaca kodenya. `interpolateBetween()`
pada `ProcessDeepLearningImage` memuat tiga predikat, jadi V(G) = 4, dan keempat
jalur bebasnya dipetakan ke kasus uji yang melewatinya. Graf alirnya digambar
dari kode itu sendiri, bukan dari uraian perancangan (`Gambar 4.11`). Jalur P-4
adalah jalur yang menghasilkan frame yang kedua batasnya sintetis, yang galatnya
1.174,9 — melebihi 555 yang diperoleh dengan menyalin frame tetangga. Kode
menempuhnya dengan benar; yang dibuktikan pengujian ini bukan ketiadaan
kesalahan, melainkan bahwa keterangan asal-usulnya sampai ke pembacanya.

Dua kejadian selama pembangunan ikut dicatat karena keduanya mengubah cara
pengujian disusun: uji memori yang lulus terhadap implementasi yang sengaja
dibuat salah, dan delapan berkas sumber yang rusak penyandiannya tanpa
menggagalkan satu pun uji yang ada.

**BAB V** disusun ulang mengikuti ketiga rumusan masalah, masing-masing dengan
buktinya, ditambah subbab batas keberlakuan yang menyatakan apa yang belum
dibuktikan — jumlah sampel pengukuran mutu, kuesioner yang belum disebar,
pemasangan pada NAS institusi yang belum dilaksanakan, dan rekonstruksi
volumetrik yang belum diukur. Sarannya dipecah menjadi empat kelompok menurut
siapa yang mengerjakannya.

Naskah skripsi tumbuh dari 81 menjadi **95 halaman**, 47 tabel dan 23 gambar,
diukur dengan `Repaginate()` lewat Word, bukan diperkirakan. Seminar proposal
tetap 64 halaman sebagaimana diminta.

### Logo kampus dipasang pada kedua dokumen

Halaman sampul kedua naskah kini memuat logo Universitas Pamulang, dipotong dan
diperbesar ke 900 x 900 piksel agar tidak pecah pada cetakan. Pratinjau HTML
sempat tidak menampilkannya karena penanda `[GAMBAR ...]` pada halaman sampul
tertangkap lebih dahulu oleh cabang gambar bernomor; penjaga `mode_cover`
memisahkan keduanya.

### Tiga daftar bernomor yang terlipat dipulihkan

Identifikasi masalah, tujuan penelitian, dan alur sistem yang diusulkan
masing-masing kehilangan batas antarbutirnya: keenam butir identifikasi masalah
terbaca sebagai satu butir sepanjang tujuh belas baris, dengan "2." sampai "6."
terjepit di tengah kalimat. Penyebabnya adalah pembungkusan ulang baris ketika
naskah dipadatkan. `perbaiki_daftar.py` memecahnya kembali dan membungkusnya
ulang pada 76 kolom.

Pratinjau skripsi juga tidak lagi menyebut dirinya seminar proposal pada kepala
halaman.

---

## [1.41.0] - 2026-09-08

### Angka di dokumen diperiksa ulang terhadap kenyataannya

Tujuh klaim numerik di lima berkas tidak lagi sesuai keadaan, dan sebagiannya
saling bertentangan di dalam satu berkas yang sama.

`ARCHITECTURE.md` menyebut **13 tabel** pada diagramnya dan **18 tabel** pada
uraian skemanya. Hitungan sebenarnya, diambil dari `Schema::create` di seluruh
migrasi, adalah **23 tabel unik** — 15 milik aplikasi dan 8 bawaan kerangka.
`API.md` menyebut 103 endpoint sementara `route:list --path=api` melaporkan
**104**. `CLAUDE.md`, `README.md`, dan `fe/README.md` masih menyebut 269 uji di
32 berkas, padahal versi 1.40.0 menaikkannya menjadi **274 di 33 berkas**.

Naskah skripsi ikut membawa angka yang keliru: BAB IV menyatakan 41 migrasi
membentuk "22 tabel di luar tabel bawaan kerangka", dua kali. Yang benar 23
tabel dengan 15 di antaranya milik aplikasi.

### `handoff.md` ditulis ulang

Berkas itu masih dibuka dengan kalimat **"Belum ada satu commit pun"** dan
menyebut 124 berkas menunggu. Sejak 8 September seluruhnya sudah di-commit dan
di-push — 60 commit ke `deepCT-AI`, dan `main` sinkron dengan `origin/main`.

Isinya sekarang menyatakan tempat sistem ini benar-benar berjalan, yang tidak
sama dengan rancangan sasaran pada naskah proposal: orkestrasi di **VPS**,
inferensi dan pelatihan di **Kaggle**, klien web di **Vercel**, bangun dan
sebar oleh **GitHub Actions**. Penyiapan di BRIN belum dilakukan dan volume NAS
belum pernah ada, sehingga `StorageGuard` belum teruji terhadap perangkat yang
sebenarnya.

### Landing page kosong: sasarannya benar, datanya yang tidak ada

Klien di Vercel dikompilasi menunjuk VPS, dan itu memang sasaran yang benar.
Bundelnya pun mutakhir, tertanggal dua jam sesudah push. Yang kosong adalah
basis data VPS-nya: `/api/health` menjawab dengan benar sementara `/api/news`
mengembalikan nol baris, sehingga halaman itu menampilkan apa adanya.

Alamat API tidak berasal dari dasbor Vercel melainkan dari variabel repositori
GitHub, dengan urutan `NGROK_BE_VPS` → `NGROK_BE` → `API_BASE_URL` → bawaan,
dan ia dikompilasi ke dalam bundel sehingga mengubah variabelnya tidak
berpengaruh sampai ada build baru.

---

## [1.40.0] - 2026-09-07

### Unggahan yang tidak pernah dimulai, dan label yang membohonginya

Seorang peneliti mengunggah arsip, lalu berpindah tab sebelum menekan tombol
mulai. Berkasnya menggantung. Di layar hasil ia tampil dengan label **QUEUED**,
sehingga peneliti menunggu pekerja yang tidak akan pernah datang menjemputnya.

Penyebabnya dua hal yang berdiri sendiri.

**Pertama, tidak ada cara memulainya dari layar hasil.** `PredictionIntake`
mencatat unggahan dengan status `uploaded`, dan `POST /predictions/{id}/start`
sudah ada sejak lama beserta pasangannya di sisi klien,
`PredictionService.start()`. Yang memanggilnya hanya layar unggah. Begitu
peneliti meninggalkan layar itu, satu-satunya jalan menuju tombol tersebut ikut
hilang, padahal catatannya tetap terlihat di daftar hasil.

Layar hasil sekarang menawarkan **START ANALYSIS** pada catatan berstatus
`uploaded`. Endpoint-nya menjawab 409 bila sesuatu sudah memulainya — dua tab
pada catatan yang sama, atau ketukan ganda di telepon — dan 410 setelah
berkasnya kedaluwarsa. Keduanya ditampilkan apa adanya, sebab keduanya
menjelaskan mengapa tidak terjadi apa-apa.

**Kedua, lencananya menyebut keadaan yang salah.** Pemetaan status jatuh ke
`QUEUED` untuk apa pun yang bukan selesai, gagal, atau sedang berjalan. Sebuah
unggahan yang belum dimulai memenuhi syarat itu, sehingga ia mengaku antre
padahal tidak ada antrean yang memuatnya. Sekarang ia berbunyi **NOT STARTED**,
dan catatan yang benar-benar antre tetap berbunyi `QUEUED` — ada uji yang
menjaga kedua sisi pembedaan itu.

`PredictionHistoryScreen` menerima `PredictionService` lewat konstruktor agar
layarnya dapat diuji tanpa jaringan. Uji Flutter naik dari 269 menjadi **274**.

---

## [1.39.0] - 2026-09-04

### UTF-8 yang termakan tool, di delapan berkas

Dasbor admin menampilkan `by Administrator â€¢ 4d ago`. Bukan cacat rendering:
urutan bytenya ada di **kode sumbernya**. Sebuah berkas UTF-8 pernah dibaca
sebagai Windows-1252 lalu disimpan ulang, sehingga `•` (E2 80 A2) menjadi tiga
karakter `â€¢`.

Delapan berkas terdampak, dan `prediction.dart:160` sudah melewatinya **tiga
kali** (`ÃƒÂ¢Ã¢â€šÂ¬Ã¢â‚¬Â`). Lima di antaranya teks yang dilihat pengguna,
termasuk `SECRET WILL BE REMOVED ON SAVE` dan `No analyses yet`.

Dipulihkan dengan dekode berulang sampai stabil. Tujuh baris awalnya tidak
pulih karena mengandung `\u009d`, slot yang tidak terdefinisi pada cp1252;
setelah kelima slot kosong itu dipetakan ke nilai bytenya sendiri, seluruhnya
pulih.

**Penjaganya dipasang lebih dulu dan merah lebih dulu** — satu di suite Flutter
memindai `lib/` dan `test/`, satu di suite PHP memindai `app/`, `routes/`,
`config/`, `database/`, dan `tests/`. Keduanya menolak lima pola mojibake.
Kerusakan ini menyebar diam-diam lewat penyuntingan biasa; tanpa tripwire ia
akan kembali.

### Empat batas perilaku model, akhirnya diukur

> **Koreksi 6 September 2026.** Bagian ini semula menyebut keempatnya “cacat”.
> Itu menuduh terlalu jauh, dan tiga sumber membantahnya. Notebook evaluasi
> kolaborasi memaku `time_scalar = 0.5`, menamai keluarannya `2i + 1`, dan
> menghasilkan satu frame per pasangan berurutan tanpa rekursi sama sekali.
> `build_samples()` pada skrip pelatihan runtuh ke titik tengah kecuali ragam
> `t` seimbang dinyalakan, dan docstring-nya sendiri menyebut itu distribusi
> tempat bobot terkirim dilatih. Uji Sample Contrast pun sejalan: frame 0002,
> yang kedua batasnya hasil pindai, berhasil — yang gagal adalah 0004, 0005
> dan 0006, yang menuntut rekursi.
>
> Model **dirancang untuk menyisipkan satu frame pada titik tengah di antara
> dua frame pindai**. Angka-angka di bawah tetap berlaku; yang berubah adalah
> namanya. Keempatnya adalah batas rancangan beserta ongkos melampauinya, bukan
> kerusakan.

Model `STUNet_2to1_TimeCond` dipakai sejak awal proyek dengan keterangan yang
tidak pernah diverifikasi. Diukur terhadap berkas bobot dan layanan inferensi
yang berjalan, memakai arsip proyeksi BRIN yang sebenarnya:

| Cacat | Bukti |
|---|---|
| **A.** Tanggapan terhadap skalar waktu hanya 0,17% | `t = 0` lawan `t = 1` menggeser keluaran 3,3; kedua batasnya berjarak 918,4 |
| **B.** Galat berlipat tiap batas sintetis | Rentang ditahan sama: 359,7 → 623,6 (1,73×) → 1.174,9 (3,27×) |
| **C.** Galat naik tajam dengan lebar rentang | 359,7 / 586,1 / 1.039,3 pada rentang 2 / 4 / 8 |
| **D.** Celah ganjil bergeser setengah posisi | `intdiv` membulatkan; validasi hold-out justru melewati rentang ganjil |

Akibatnya, dari frame yang dihasilkan hanya yang **kedua batasnya hasil pindai**
yang layak: celah 2 memberi 1 dari 1, celah 4 memberi 1 dari 3, celah 8 memberi
**0 dari 7**. Ambangnya adalah menyalin frame pindai di sebelahnya, MAE ≈ 555.

Dua kendali memisahkan perilaku model dari kesalahan skrip. Menukar urutan gambar
masukan menggeser keluaran 63,94 melalui jalur kode yang sama, sehingga skrip
terbukti meneruskan masukan dengan benar. Dan `script-api-deepct.py` diperiksa
baris per baris: `time_scalar` diterima sebagai Form wajib, dibungkus menjadi
`np.array([[t]])` berbentuk (1,1), diteruskan ke `generator.predict`.

Arsitekturnya juga dibaca langsung dari `.h5`: **31 lapisan, 21.921.601
parameter** — bukan ~25,6 juta seperti yang beredar — dengan tiga `ConvLSTM2D`
sebagai unsur temporal dan pengondisi waktu `Dense 4096` → `Reshape 64×64` yang
disisipkan pada lapisan tersempit. Keluarannya `tanh`, yang menjelaskan mengapa
model bekerja pada rentang [−1, 1].

### Percobaan penyempurnaan: hasil negatif, dilaporkan

Job 19 dilatih dengan `balanced_t=true` dan `max_gap=8` — 112 contoh per epoch,
naik dari 40 — selama 20 epoch. MAE 0,022817 → 0,018316, PSNR +2,09 dB.

Tanggapan terhadap `t` naik dari 0,17% menjadi 27,87%, dan keragaman keluaran
dari rasio 0,001 menjadi 0,236. **Mekanismenya terbukti dapat diajarkan tanpa
mengubah satu lapisan pun** — arsitektur sebelum dan sesudah identik.

Tetapi belum berguna. Pada Sample Contrast — objek yang tidak pernah
dilatihkan — tiga frame yang dibangkitkan dari pasangan yang sama berjarak
37,4, yaitu 0,065% dari rentang citra dan **di bawah ambang yang dapat
dibedakan mata**. Pemeriksaan visual memang tidak memperlihatkan perbedaan.

Sebabnya: kurva latih masih menurun pada 76% laju awal ketika pelatihan
dihentikan, dan 10 frame berhadapan dengan 21,9 juta parameter. Bobotnya
disimpan sebagai `models-ai/generator(Revisi 4 STUNet balanced-t maxgap8).h5`
tetapi **tidak dipasang**; sistem tetap memakai bobot dasar.

### Terverifikasi

`php artisan test` **368 lulus**, `flutter analyze` bersih, `flutter test`
**269 lulus**. Uji model memakai TensorFlow 2.21 lokal, kedua bobot dimuat pada
proses yang sama dengan masukan dan kode yang sama.

---

## [1.38.0] - 2026-09-03

Tiga butir fitur, dikerjakan berurutan. Ketiganya saling mengunci: yang kedua
membuang byte arsip dari memori, dan yang ketiga langsung menagihnya kembali
lewat digest — sehingga digest itu harus ikut dialirkan.

### Arsip dataset training akhirnya punya retensi

`predictions:cleanup` menyapu hasil prediksi, `temp/downloads`, dan `.part`
yang ditinggalkan sejak awal, dan tidak pernah menyentuh `training/datasets` —
tempat setiap run terhosting meninggalkan sampai 512 MB. Satu-satunya
penghapusan adalah `DELETE /admin/training/datasets/{id}`: manual, admin saja,
dan tidak ada yang melakukannya. Empat belas dataset menumpuk **219 MB**.

`training:cleanup` menutupnya, dijadwalkan harian pukul 03:10.

**Jendelanya diukur dari pemakaian terakhir, bukan dari waktu unggah**, dan itu
inti rancangannya. Sebuah dataset diunggah ke platform ini — alih-alih diambil
sendiri oleh worker dari sebuah URL — justru supaya bisa dipakai ulang antar
run. Jam yang berjalan sejak unggah akan menghapus arsip yang dilatih orang
setiap minggu, tepat di bawah tangannya. Jadi jendelanya berjalan dari yang
terbaru di antara: pembuatan dataset, dan apa pun yang terakhir dilakukan
job-jobnya.

Dataset dengan job `queued` atau aktif **tidak pernah** disapu, seberapa tua
pun. Mengambil sumber dari run yang sedang berjalan menghabiskan jam GPU yang
tidak bisa diambil kembali; membiarkan arsip tua satu hari lagi tidak
merugikan siapa pun.

Yang dihapus: berkas arsip dan cache pratinjau yang diturunkan darinya. Yang
**tidak**: barisnya. Job training menunjuk ke dataset-nya, jadi membebaskan
disk dengan menghapus baris akan meninggalkan riwayat setiap run menunjuk ke
ketiadaan. Sama seperti `files_deleted_at` pada prediksi, dan karena alasan
yang sama.

Default 30 hari lewat `TRAINING_DATASET_RETENTION_DAYS`; nol mematikannya.
Retensi 24 jam ala prediksi jelas salah di sini — itu hasil yang diunduh
sekali, ini masukan yang didatangi lagi.

**Peneliti diberi tahu.** `archiveFrames()` mengembalikan koleksi kosong ketika
arsipnya tidak ada di disk, dan layar membacanya sebagai "No .tif frames were
found inside that archive" — menyalahkan unggahan peneliti untuk berkas yang
justru kami hapus. Sekarang endpoint-nya membawa `meta.archive_deleted` dan
layar memilih kalimatnya dari situ.

### Unggahan tidak lagi memuat seluruh arsip ke RAM

Chunked upload sudah ada sejak awal, dan sempat terlihat seperti sudah
menyelesaikan masalah yang melahirkannya. Belum. `withData: true` menyerahkan
seluruh berkas ke heap Dart, lalu loop chunk memotong `Uint8List` yang sudah
utuh di sana — jadi chunking menyelamatkan **transportnya** dan tidak lebih.
Dataset terhosting boleh 512 MB; ponsel atau tab browser sudah mati jauh
sebelum itu.

`ArchiveSource` adalah sambungan yang memperbaikinya: ia tahu panjangnya dan
bisa menghasilkan rentang mana pun sesuai permintaan, yang sebenarnya satu-satunya
hal yang pernah dibutuhkan loop unggah. Di native, rentangnya datang dari
`RandomAccessFile` — bukan `openRead`, karena loop bisa dimundurkan oleh retry
yang menemukan server lebih jauh dari dugaan, dan aliran sekuensial tidak bisa
menjawab itu; seek bisa.

**Di web tidak berubah, dan itu memang batasnya.** Browser tidak memberi path,
jadi byte-nya tetap di memori dan `BytesArchiveSource` jujur soal itu alih-alih
berpura-pura. Frame lepas yang di-zip aplikasi ini sendiri juga tetap di
memori — bundelnya dibangun di sana dan tidak punya tempat lain.

### Unggahan dataset yang terputus ditawarkan kembali

Unggah prediksi mengingat sesi yang terputus dan menawarkannya di perangkat
sejak lama; training tidak, jadi unggahan yang putus harus diulang dari nol —
sementara separuh yang sudah dipegang server duduk di sana sampai sapuannya
sendiri.

`UploadResumeStore` kini punya **satu slot per keperluan**. Seorang peneliti
bisa meninggalkan prediksi setengah terkirim lalu memulai run training; satu
slot akan menggusur salah satunya tanpa berkata apa-apa. Kunci lama
(`pending_upload`) tetap dipakai keperluan prediksi, jadi unggahan yang
terputus sebelum perubahan ini masih bisa dilanjutkan, dan rekaman tanpa
medan `purpose` terbaca sebagai prediksi — memang semuanya prediksi.

**Digest-nya dialirkan.** `md5.convert(bytes)` membutuhkan seluruh arsip
residen, persis biaya yang baru saja dibuang butir sebelumnya — memakainya di
sini akan membatalkan unggahan mengalir tepat pada langkah yang menjaganya.
`digestOf()` menyusuri `ArchiveSource` per megabyte lewat
`md5.startChunkedConversion`.

Banner-nya sengaja sebentuk dan sekata dengan milik layar prediksi: seorang
peneliti bertemu keduanya, dan unggahan terputus tidak boleh terbaca sebagai
dua jenis peristiwa berbeda tergantung tab mana ia terjadi. Dan ia benar-benar
melanjutkan, bukan hiasan — sebuah rekaman tertunda mengarahkan unggahan ke
`resume()`, yang memeriksa digest lebih dulu.

**Yang belum:** loop chunk-nya masih belum disatukan dengan
`prediction_service.dart`. Keduanya kini cukup mirip untuk itu, tapi refactor
itu menyentuh satu-satunya jalur unggah yang pernah terbukti ujung-ke-ujung
terhadap GPU sungguhan, dan pantas dapat putaran sendiri.

### Terverifikasi

`php artisan test` **367 lulus** (dari 359, 1.451 asersi) — delapan tes
retensi, semuanya merah lebih dulu.

`training:cleanup --dry-run` terhadap disk yang sungguhan, dua kali:

- dengan jendela **30 hari** yang sebenarnya: *0 archive(s) to consider* —
  benar, dataset tertua baru delapan hari;
- dengan jendela **1 hari**, untuk melihat ia memang bekerja: keempat belas
  dataset terdaftar dengan umur dan ukurannya, **would free 218.6 MB** —
  cocok dengan 219 MB yang diukur `du`.

`flutter analyze` bersih. Tes Flutter baru semuanya merah lebih dulu.

**Satu tes memori awalnya tidak membedakan, dan itu ketahuan karena diperiksa.**
`walking a large file does not pull it into memory` lulus melawan implementasi
sengaja-salah yang membaca seluruh berkas per potongan — karena helper penulis
fixture-nya membangun 64 MB sebagai satu `Uint8List` lebih dulu, sehingga heap
VM sudah sebesar itu sebelum pengukuran dimulai. Helper-nya kini menulis per
megabyte, dan implementasi salah yang sama menaikkan RSS **167 MB** dan gagal.

Sebuah tes yang lulus melawan kode yang salah tidak menguji apa pun, dan
satu-satunya cara mengetahuinya adalah menjalankannya melawan kode yang salah.

---

## [1.37.0] - 2026-09-02

### Pratinjau dataset 404 untuk setiap frame di dalam folder

Daftar frame mengembalikan nama beserta awalan foldernya —
`input/HONDA_Used_0051.tif` di dataset job 18, `Sample Contrast/Contrast_0001.tif`
di arsip lain — dan endpoint pratinjau tidak bisa menerimanya kembali.

Segmen `{name}` pada rute tidak boleh memuat garis miring. Klien menyusun
URL-nya dengan `Uri.encodeComponent`, menghasilkan `%2F`, dan **Symfony
mencocokkan rute pada path yang sudah didekode** — jadi `%2F` kembali jadi
pemisah, URL menyebut dua segmen di tempat rute mengharapkan satu, dan tidak
ada rute yang cocok sama sekali. Bukan `abort(404)` dari controller;
404 dari lapisan routing, yang tidak punya apa pun untuk dikatakan.

Dibuktikan dengan mencocokkan ketiga bentuk penulisan terhadap tabel rute
langsung, bukan dengan menebak dari gejalanya:

| Dikirim | Cocok rute? | `$name` yang sampai |
|---|---|---|
| `input%2F…` (yang klien kirim) | **tidak** | — |
| `input%252F…` | ya | `'input%2FHONDA_Used_0051.tif'`, harfiah |
| nama telanjang | ya | tidak ada di arsip |

Rutenya kini `->where('name', '.*')`. Aman karena controller memeriksa nama
terhadap **daftar isi arsip** alih-alih membersihkannya: nama yang bukan entri
ditolak apa pun bentuknya. Perbaikan sisi server saja — klien sudah mengirim
bentuk yang benar sejak awal.

Efek sampingnya bagus: `test_a_name_outside_the_archive_is_refused` selama ini
lolos karena rutenya kebetulan tidak cocok dengan `..%2F..%2F.env`, bukan
karena pemeriksaannya bekerja. Sekarang rutenya cocok, dan tes itu benar-benar
menguji apa yang tertulis di docblock-nya.

**Kenapa ini lolos sampai sekarang:** setiap arsip yang pernah dilihat suite
ini datar. Bagian E diverifikasi 23 Agustus terhadap fixture datar, dan arsip
BRIN yang nyata berfolder. Fixture baru `foldedJob()` menutup celah itu.

Kembarannya di jalur prediksi **tidak** punya masalah yang sama, dan itu
diperiksa, bukan diasumsikan: `PredictionIntake` mengekstrak dengan
`basename()` — komentarnya menyebut itu juga menetralkan `../` — sehingga nama
frame prediksi tidak pernah memuat garis miring.

### Perbaikan pertama tidak berhasil, dan alasannya layak dicatat

`->where()` ditambahkan, tesnya tetap merah. Penyebabnya bukan perbaikannya:
`bootstrap/cache/routes-v7.php` ada di disk sejak pukul 21:50, dan selama
berkas itu ada **`routes/api.php` tidak dibaca sama sekali** — tidak oleh
server, tidak oleh `route:list`, tidak oleh suite. Jebakan ini sudah tertulis
di CLAUDE.md dan tetap memakan satu putaran.

Artinya juga: setiap `php artisan test` sebelum ini pada sesi 2 September
berjalan terhadap tabel rute yang di-cache, bukan terhadap berkasnya. Tidak
ada hasil yang batal — tidak ada rute yang diubah sebelum putaran ini — tapi
itu fakta yang lebih baik dicatat daripada ditemukan lagi nanti.

Cache-nya dibersihkan dan **dibiarkan bersih**. `npm run preserve:all`
mengembalikannya kalau memang diinginkan.

### Terverifikasi

`php artisan test` **359 lulus** (dari 358, 1.428 asersi), dan ini kali pertama
pada sesi ini suite membaca `routes/api.php` yang sesungguhnya.

Tes barunya merah lebih dulu dengan gejala produksi yang sama persis: daftar
memberi `input/frame_001.tif`, pratinjaunya `Expected response status code
[200] but received 404`.

Terhadap server berjalan, dataset job 18 yang sungguhan:

| Yang diperiksa | Hasil |
|---|---|
| `input%2FHONDA_Used_0051.tif` | **200 image/png**, 125.284 byte, 0,87 dtk |
| Struktur PNG | signature sah, IHDR 512×512 depth 8 colorType 0, IEND ada |
| Cache tertulis | `…/preview/18/512_input/HONDA_Used_0051.tif.png` |
| `..%2F..%2F.env` | **403** — ditolak RoadRunner sebelum mencapai aplikasi |
| `../.env` mentah | 404 |
| Tanpa token | 401 |

Traversal menjawab 403 di server sungguhan dan 404 di suite: RoadRunner
menolak path itu lebih dulu, sementara di lingkungan uji pemeriksaan daftar
isi arsip yang menolaknya. Dua lapisan, dua jawaban, keduanya penolakan.

---

## [1.36.0] - 2026-09-02

### `TiffPreview` tidak lagi membangun satu entri array PHP per piksel

Ini yang membunuh queue worker pada 25 Agustus. Setiap piksel jadi satu entri
array — dua kali sekaligus, selagi hasil `unpack` disalin ke akumulator — dan
entri array PHP berharga puluhan byte untuk piksel yang di disk cuma dua.
`memory_limit` terlampaui di tengah job, prosesnya mati membawa run-nya, dan
layar tetap berkata "queued" tanpa satu pun penjelasan.

Yang dilakukan waktu itu adalah menurunkan `MAX_PIXELS` dari `8192×8192` ke
`2048×2048`. Itu memindahkan temboknya, bukan merobohkannya. Berapa jauh
temboknya, baru terukur sekarang:

| Frame | TIFF | `toPng` sebelum | `toPng` sesudah |
|---|---|---|---|
| 2048×2048 | 8 MB | **196 MB** | **11,7 MB** |
| dua frame (jalur `FrameMetrics`) | 16 MB | **262 MB** | **20 MB** |

Dua ratus enam puluh dua megabyte, di dalam worker yang saat itu dianggarkan
512 MB. Berkasnya sendiri 8 MB.

Sekarang piksel tinggal sebagai string biner dari awal sampai akhir:

- `decode()` menyambung strip sebagai **byte**, tidak menafsirkan apa pun, lalu
  menormalkannya ke 16-bit little-endian sekali jalan. Untuk frame yang memang
  sudah 16-bit LE — yaitu semua yang ditangani platform ini — string itu
  dikembalikan apa adanya, tanpa disalin ulang.
- `range()` mencari min/maks per blok, memakai `min()`/`max()` yang berjalan di
  kecepatan C. Ia publik, karena `FrameMetrics` mengutip rentang frame acuan di
  samping angka galatnya dan dua implementasi "rentang frame ini berapa" akan
  jadi dua jawaban.
- `downscale()` membuka hanya baris sumber yang dibutuhkan satu baris keluaran
  — empat baris untuk frame 2048 lebar menuju 512 — lalu mengemasnya kembali
  jadi string selagi dihasilkan.
- `windowTo8Bit()` menerima min dan maks sebagai argumen alih-alih menghitung
  ulang, karena itu lintasan yang sudah dijalani.

Kuncinya `unpack` per blok 8.192 piksel: kerja byte tetap di C, tapi tidak
pernah ada lebih dari satu blok yang berwujud array PHP. Ini bukan menukar
memori dengan kecepatan — 2048×2048 selesai dalam 0,69 detik.

`FrameMetrics` ikut, karena ia yang memegang dua frame sekaligus.

### `MAX_PIXELS` naik ke 4096×4096, dan tidak lebih

Plafonnya boleh naik lagi sekarang, tapi tidak kembali penuh ke `8192×8192`
seperti semula:

| Frame | TIFF | `toPng` | dua frame | waktu |
|---|---|---|---|---|
| 1024×1024 | 2 MB | 5,7 MB | 8 MB | 0,30 dtk |
| 2048×2048 | 8 MB | 11,7 MB | 20 MB | 0,69 dtk |
| 4096×4096 | 32 MB | 36,6 MB | 68 MB | 2,36 dtk |
| 8192×8192 | 128 MB | 142,8 MB | 260 MB | **10,24 dtk** |

**Yang membatasi sekarang waktu, bukan memori.** Endpoint pratinjau yang
menjawab dalam 2,4 detik itu lambat tapi bisa dipertanggungjawabkan; sepuluh
detik tidak. Itu perubahan yang berarti: batas memori mematikan prosesnya,
batas waktu hanya membuatnya lambat.

### Terverifikasi

`php artisan test` **358 lulus** (dari 355, 1.422 asersi). Tiga tes baru,
**semuanya merah lebih dulu**:

- `decoding 2048x2048 used 196.0 MB — Failed asserting that 205525064 is less
  than 33554432`
- `decoding two 2048x2048 frames used 262.0 MB`
- plafon 4096×4096 ditolak selagi konstantanya masih `2048×2048`

Dua belas tes perilaku `TiffPreview` yang sudah ada — 8-bit, big-endian,
WhiteIsZero, rentang sempit, frame datar, downscale, penolakan — **tidak satu
pun diubah**, dan semuanya tetap hijau. Itu jaring pengaman penulisan ulang
ini, dan alasannya bisa disebut penulisan ulang alih-alih penulisan baru.

Lalu terhadap frame BRIN sungguhan dari arsip dataset di disk
(`Sample Contrast/Contrast_0001.tif`, 1024×1024 16-bit, 2 MB):

| Yang diperiksa | Hasil |
|---|---|
| PNG keluaran | 512×512, depth 8, colorType 0, signature sah, 138.963 byte |
| Rentang frame | 290–58.633 — jauh dari penuh 16-bit, yang memang alasan windowing ada |
| Memori | **8,3 MB** |
| Waktu | 0,38 detik |

### Ditemukan, tidak diperbaiki: pratinjau dataset 404 untuk frame berfolder

Muncul saat mencari frame sungguhan untuk pengujian di atas.
`GET /me/training/jobs/{id}/dataset/frames` mengembalikan nama beserta awalan
foldernya, sementara segmen `{name}` pada rute pratinjau tidak bisa memuat
garis miring. Ketiga bentuk penulisan sama-sama 404.

Arsip BRIN yang nyata berfolder — job 18 memakai `input/`, arsip lain memakai
`Sample Contrast/`. Jadi bagian E terbukti pada arsip datar dan tidak pernah
bertemu yang berfolder. Dicatat di ROADMAP, tidak dikerjakan pada putaran ini.

---

## [1.35.0] - 2026-09-02

Empat hal yang sudah lama tercatat sebagai "diketahui, belum dikerjakan".
Tidak ada yang baru di sini — semuanya sudah dijelaskan di ROADMAP, dan yang
berubah adalah dari tertulis menjadi terpasang.

### Bobot training yang tersimpan dengan nama yang tidak bisa dimuat

`store()` menurunkan ekstensi dari **MIME type**, bukan dari nama yang dikirim
worker. Trainer mengunggah `.h5` sebagai `application/octet-stream`, dan
jawabannya tidak konsisten:

| Kapan | Mendarat sebagai |
|---|---|
| 17 Agustus | `.bin` |
| 29 Agustus, job 17 | `.hdf`, 87,8 MB |
| 2 September, job 18 | `.hdf`, 87,8 MB |

Keras 3 memilih loader dari sufiks dan tidak mengenal satu pun dari keduanya.
Jadi administrator yang menekan DOWNLOAD WEIGHTS menerima 87,8 MB hasil
training yang benar — dan tidak bisa memuatnya. Nama yang benar tidak tercatat
di mana pun, jadi tidak ada cara menebaknya kecuali membuka berkasnya.

`storeWeights()` sekarang memakai `storeAs()` dengan ekstensi dari nama klien,
dipilih dari daftar sufiks bobot yang dikenal. Nama berkas tetap
`Str::random(40)` seperti sebelumnya, jadi bentuk path tidak berubah selain
sufiksnya. Daftar itu ada karena namanya kini datang dari klien:
`../../../public/evil.php` harus tidak bisa ikut menentukan path, dan ekstensi
di luar daftar jatuh ke `bin` — persis yang dihasilkan tebakan MIME dulu.

Checkpoint mendapat perlakuan sama. Ia yang dipakai worker berikutnya untuk
melanjutkan, jadi checkpoint yang tidak bisa dimuat sama saja dengan tidak ada.

**Dua berkas yang sudah telanjur tersimpan diperbaiki namanya**, dan itu bukan
tebakan: delapan byte pertama keduanya adalah `89 48 44 46 0d 0a 1a 0a`, magic
number HDF5. Job 17 dan 18 kini terunduh sebagai `.h5` dari server yang
berjalan.

### `hyperparameters` sebagai `[]` — kali kelima keluarga bug ini

PHP hanya punya satu tipe array dan `json_encode` menulis yang kosong sebagai
list, jadi sebuah map yang belum berisi apa pun berangkat sebagai `[]`.
`TrainerDispatcher` sudah belajar ini di 1.29.0 dan `metrics` di 1.33.0; tiga
baris di sebelahnya tidak pernah ikut:

- `GET /me/training/jobs/{id}` — dibaca klien Dart;
- `POST /training/worker/claim` — dibaca **Pydantic**, yang mendeklarasikan
  dict dan menolak list mentah-mentah;
- `GET /admin/training/jobs/{id}` pada bentuk detailnya.

Yang kedua yang paling tajam: bentuk kawat yang salah di sana adalah 422 yang
sama persis dengan yang sudah punya komentar sendiri di `TrainerDispatcher`.

### Posisi antrean dihitung di tiga tempat, bukan dua

ROADMAP menyebut dua; ada tiga. `getQueuePosition()`, `start()` dan
`PredictionUploadController::queuePosition()` masing-masing menghitung
`created_at <` lalu tambah satu, sementara `QueueBoard` menomori urutan.

Keduanya setara sampai dua rekaman berbagi detik yang sama — dan unggahan
berpotong selesai dirakit dalam jauh di bawah satu detik. Saat itu terjadi,
hitungan `created_at <` memberi **keduanya** angka 1, sedangkan papan
administrator menampilkan 1 dan 2. Peneliti membaca "antrean ke-1" di
riwayatnya sementara admin melihatnya di urutan kedua.

`QueueBoard::positionOf()` kini menjawab pertanyaan satu-rekaman, dan
`positions()` memakai `id` sebagai pemecah seri supaya urutannya total, bukan
diserahkan ke apa pun yang kebetulan dikembalikan basis data.

Dua akibat yang ikut terbawa, keduanya lebih jujur daripada sebelumnya:

- `queue_position` menjadi `null` untuk rekaman yang tidak sedang antre.
  Berkas ber-status `uploaded` menunggu tombol START, bukan menunggu GPU; klien
  Dart sudah membacanya sebagai `int?` di semua tempat.
- `POST /api/predictions` berhenti mengumumkan `"status": "pending"` secara
  harfiah. Intake mendaratkan run sebagai `uploaded`, jadi respons itu
  menyebutkan antrean untuk pekerjaan yang belum masuk antrean.

### `script-api-deepct.py` tidak lagi diabaikan git

Alasannya dulu benar: berkas itu memuat authtoken ngrok polos. Sejak 1.34.0 ia
membaca kredensial dari environment atau Kaggle Secrets dan tidak memegang apa
pun. Alasannya habis, dan harganya terlihat: path bobot yang ditulis keras
bertahan berminggu-minggu di sana tanpa muncul di satu diff pun, sementara
kembarannya yang dilacak ketahuan di setiap commit.

`script-deepct.py` — nama lama yang memang menyimpan token — tetap di daftar
supaya salinan basi tidak bisa masuk.

### Terverifikasi

`php artisan test` **355 lulus** (dari 350, 1.411 asersi). Lima tes baru,
**empat di antaranya dijalankan merah lebih dulu** dan gagal dengan pesan yang
diharapkan: `.bin` bukan `.h5`, `"hyperparameters":[]` dua kali, dan "record 2
is in a different place on each screen — Failed asserting that 1 is identical
to 2". Yang kelima menjaga agar nama dari klien tidak bisa memilih path; ia
hijau sejak awal karena tebakan MIME memang mengabaikan nama, dan ditulis
sebelum kode yang bisa merusaknya.

Diverifikasi juga terhadap server yang **sedang berjalan**, bukan hanya suite:

| Yang diperiksa | Hasil |
|---|---|
| `GET /me/training/jobs/17` dan `/18` | `"hyperparameters":{}` |
| `GET /admin/queue` vs `GET /predictions/{id}` | dua baris berdetik sama: papan 1 dan 2, layar peneliti 1 dan 2 |
| `GET /admin/training/jobs/17/weights` | 200, `job-17-….h5`, 87.794.816 byte |
| `GET /admin/training/jobs/18/weights` | 200, `job-18-….h5`, 87.794.816 byte |

Dua baris antrean uji itu dibuat untuk pemeriksaan tersebut dan dihapus
setelahnya; tiga token debug dicabut.

**Catatan cara kerja:** Octane yang berjalan memuat kelas PHP saat proses
dimulai, jadi berkas yang diedit pukul 22:52 tidak terlihat oleh server yang
naik pukul 21:51. `php artisan octane:reload` **tidak menolong** — ia korban
ketiga `posix_kill()` di Windows dan mati di `serverIsRunning()` sebelum
sempat me-reset apa pun. `./rr.exe reset -o version=3 -o
rpc.listen=tcp://127.0.0.1:6001` bekerja, tidak mengganggu `serve:all`, dan
itulah yang dipakai sebelum tabel di atas diambil.

Flutter tidak disentuh pada putaran ini, jadi `flutter analyze` dan
`flutter test` tidak dijalankan ulang — angka terakhirnya ada di 1.34.0.

---

## [1.34.0] - 2026-08-26

### Path bobot yang ditulis keras di empat salinan, dan tiga di antaranya berbeda

Dua notebook Kaggle yang sedang berjalan diminta dan dibandingkan dengan skrip
di repo. Keduanya tidak sinkron, dan penyebabnya satu baris yang sama.

Kaggle menyusun path model yang dilampirkan dari slug, framework dan versi yang
dipilih **saat melampirkannya**. Jadi satu berkas yang sama punya tiga alamat:

| Salinan | Path | Nyata hari ini |
|---|---|---|
| Notebook prediksi | `deepct-ai/tensorflow2/default/1/` | ya — prediksi jalan |
| Notebook training | `deepct-unet/keras/v1/1/` | tidak — `[Errno 2]` |
| `script-api-train-deepct.py` | `train-deepct/tensorflow2/version-1/1/` | tidak pernah diuji |

Yang membuatnya mahal bukan salahnya, melainkan **kapan** salahnya terlihat.
Path itu baru dibuka setelah trainer menerima job, mengunduh dataset, dan mulai
memuat bobot — jadi peneliti melihat runnya berangkat, lalu jadi `failed`
karena sesuatu yang tidak bisa diperbaiki dari sisi mana pun di platform.

`1.30.0` mengumumkan `find_base_model()` sebagai perbaikannya. Fungsi itu tidak
pernah ditulis; yang benar-benar dikerjakan hanya mengganti konstantanya dengan
tebakan lain. Sekarang fungsinya ada, di **kedua** skrip dan identik, karena
dua salinan yang berbeda adalah keadaan yang baru saja menghabiskan satu sesi.

Ia mencari `*.h5` dan `*.keras` di bawah `/kaggle/input`, mendahulukan berkas
bernama `generator` — sebuah folder checkpoint bisa juga memuat discriminator,
dan memuat yang itu menghasilkan model yang jalan dan mengembalikan omong
kosong, satu-satunya dari tiga hasil yang tidak melempar apa pun.
`BASE_MODEL_PATH` tetap menang bila diisi, dan diisi-tapi-tidak-ada adalah
galat, bukan alasan untuk kembali mencari: diam-diam melewati path yang
diketik seseorang berarti melatih di atas bobot yang bukan pilihan mereka.

Skrip prediksi **menolak berdiri** tanpa bobot — tanpa itu ia tidak punya apa
pun untuk dilayani. Skrip training tetap membuka terowongannya dan melaporkan
`"base_model": null` di `GET /`, karena "worker terlihat offline tanpa
penjelasan" adalah keadaan yang lebih buruk daripada "worker terlihat online
dan mengatakan apa yang kurang".

Diperiksa dengan menjalankan fungsinya terhadap pohon direktori palsu, bukan
dengan membacanya: menemukan `generator` alih-alih `discriminator`,
mengembalikan `None` ketika tidak ada apa-apa, mengalah pada `BASE_MODEL_PATH`,
dan melempar ketika `BASE_MODEL_PATH` menunjuk berkas yang tidak ada — empat
pemeriksaan, di kedua skrip.

### Panel training yang memakan daftar model

`Training runs ready to register` adalah satu-satunya jalan keluar dari
pipeline training — mendaftarkan bobot *adalah* membuat versi model — jadi ia
memang milik layar Model Management. Yang keliru bukan tempatnya, melainkan
bahwa ia sebuah `Column` tanpa batas tinggi yang duduk **di sebelah**
`Expanded` milik grid model.

Artinya setiap run yang selesai mencuri sekitar delapan puluh piksel dari grid
di atasnya, permanen, tanpa cara mengembalikannya. Delapan run menyisakan satu
baris kartu model di jendela laptop dan tidak ada sama sekali di ponsel. Dan
satu-satunya tombol yang ditawarkan untuk membersihkan panelnya adalah DELETE —
yang menghapus bobotnya dari disk. Tata letaknya diam-diam mendorong orang ke
satu-satunya tombol tak-bisa-dibatalkan di layar itu, dan pada 26 Agustus
delapan run selesai terhapus dalam kurang dari dua menit.

Sekarang panelnya memakan jumlah tetap berapa pun yang menunggu: paling banyak
188 piksel baris, digulung di dalam batasnya sendiri, di bawah kepala yang
membawa hitungannya — `Training runs ready to register (8)`. Daftar yang
menggulung menyembunyikan panjangnya sendiri, dan angka itulah yang menentukan
apakah seseorang perlu menggulungnya.

Di ponsel tombolnya turun ke bawah judul dan boleh pecah dua baris. Itu bukan
kehati-hatian: `REGISTER AS MODEL` dan `DELETE` bersama-sama menuntut 374
piksel, sebuah ponsel 360 piksel menawarkan 329, dan selisihnya muncul sebagai
luapan 46 piksel yang terukur di tes.

Panelnya keluar dari `model_management_screen.dart` menjadi
`TrainingHandoffPanel`, karena sebuah `Column` privat di dalam sebuah layar
yang butuh klien jaringan tidak bisa diuji tata letaknya. Tujuh tes: dua belas
run tidak memakan lebih banyak ruang daripada enam, satu run tidak menahan
ruang untuk run yang tidak ada, run terakhir bisa dicapai dengan menggulung,
kepalanya menyebut hitungannya, kosong menggambar nol piksel, dan ponsel tidak
meluap.

### Dua notebook memperebutkan satu domain ngrok

Begitu skrip prediksi yang benar dijalankan di Kaggle, ia menolak berdiri:

```
ERR_NGROK_334: The endpoint 'https://fester-resend-envelope.ngrok-free.dev'
is already online.
```

Nama di pesan itu adalah URL **trainer**, untuk sebuah `ngrok.connect()` yang
tidak menyebut domain apa pun. Sebabnya: satu akun ngrok gratis punya satu
domain reserved, dan connect tanpa nama mengambil domain itu. Kedua notebook
membaca Kaggle secret yang sama — `ngrok-endpoint` — jadi keduanya adalah akun
yang sama, dan yang menyala belakangan kalah.

Ini tidak pernah terlihat karena notebook prediksi yang lama menempelkan
authtoken akun **lain** langsung di dalam sel. Itu menyelesaikan bentrokannya
secara kebetulan, dan membayarnya dengan kredensial polos di dalam kode —
kredensial yang sejak itu ikut tersalin ke mana-mana dan harus dicabut.

Kredensialnya kini punya urutan: `NGROK_AUTHTOKEN` menang, lalu secret milik
notebook itu sendiri (`ngrok-predict` / `ngrok-train`), baru secret bersama.
Notebook yang punya tokennya sendiri tidak pernah bertabrakan; yang belum punya
tetap jalan seperti sebelumnya. `NGROK_DOMAIN` menyematkan domain reserved bila
ada.

Dan pesannya diterjemahkan. pyngrok melempar bentrokan ini sebagai HTTP 502
dengan empat puluh baris traceback, dan satu-satunya kalimat yang bisa
ditindaklanjuti terkubur di dalam JSON di baris terakhir. Sekarang yang muncul
menyebut penyebabnya dan dua jalan keluarnya.

Tujuh pemeriksaan per skrip, dijalankan merah lebih dulu: variabel lingkungan
menang, secret sendiri mendahului yang bersama, jatuh ke yang bersama bila
tidak ada, melempar dan menyebut kedua nama bila tidak ada apa-apa,
ERR_NGROK_334 diterjemahkan, dan galat lain dibiarkan lewat apa adanya.

### Terverifikasi

`flutter analyze` bersih, `flutter test` **250 lulus** (dari 243),
`php artisan test` **350 lulus** (1.386 asersi), `flutter build apk --release`
**61,8 MB, exit 0**. Backend tidak disentuh pada putaran ini.

`find_base_model()` **terbukti di produksi**, bukan hanya di pemeriksaan: sesi
training melaporkan `train-deepct/tensorflow2/version-1/1/` dan sesi prediksi
memuat `deepct-ai/tensorflow2/default/1/` — dua path berbeda pada hari yang
sama, keduanya ditemukan tanpa ada yang mengetik apa pun.

Ketujuh tes panel dijalankan **merah lebih dulu**: lima gagal terhadap panel
yang lama, termasuk luapan 46 piksel di ponsel dan dua belas run yang memakan
dua kali lipat ruang enam run. `find_base_model()` diuji dengan menjalankannya
terhadap pohon direktori palsu, bukan dengan membacanya.

**Yang tidak bisa diverifikasi dari sini:** kedua notebook Kaggle masih
menjalankan salinan lama. Sesi prediksi masih memuat `/predict_png` dan
`/generate_gif` dan menjawab 404 di `GET /`; sesi training masih membuka
`deepct-unet/keras/v1/1/`. Perbaikan di berkas ini tidak berlaku sampai kedua
notebook dijalankan ulang dengan isi yang sekarang.

---

## [1.33.0] - 2026-08-25

### MY RUNS berputar selamanya, dan penyebabnya array kosong PHP — untuk keempat kalinya

Endpoint-nya sehat: 200 dalam 50 milidetik. Yang macet klien, dan bukti ada di
dalam jawabannya sendiri:

```json
"metrics":[]
```

PHP hanya punya satu tipe array dan `json_encode` menulis yang kosong sebagai
`[]`, jadi run yang belum melaporkan apa pun tiba sebagai **list** di tempat
sebuah map dideklarasikan. Di Dart, `as Map?` terhadap List tidak menghasilkan
null — ia **melempar**. Lemparan itu lolos dari `catch` yang hanya menangkap
`ApiException`, `_loading` tidak pernah dikembalikan ke `false`, dan daftarnya
berputar selamanya di web maupun di ponsel tanpa satu pun pesan di layar.

Diperbaiki di dua tempat, karena keduanya salah:

- **Backend** mengirim objek — `(object) ($job->metrics ?? [])` — di daftar
  peneliti, di riwayat per epoch, dan di konsol admin.
- **Frontend** berhenti bisa digantung: `asMetrics()` menerima bentuk apa pun
  dan `_load()` menangkap **semua** galat. Parsing adalah tempat yang salah
  untuk bersikap ketat — sebuah layar tidak boleh bisa mati karena bentuk kolom
  yang hanya ia tampilkan.

Empat tes regresi menjaganya, termasuk satu yang melempar galat sembarang dari
loader dan menuntut spinner-nya berhenti.

### Angka hasil training terlihat tanpa membuka baris

Tabel per epoch — EPOCH, MAE, MSE, PSNR, SSIM — sudah ada sejak lama, tapi
hanya muncul saat baris dibuka, dan tidak pernah terlihat karena layarnya tidak
pernah lewat dari spinner. Sekarang epoch terakhir ikut di baris ringkas:
`epoch 2 · PSNR 38.79 · SSIM 0.9862 · MAE 0.01469`. Daftar yang menyembunyikan
hasilnya di balik satu ketukan adalah daftar nama.

### Antrean training, dan antrean yang benar-benar bergerak

Run yang menunggu kini menyebut posisinya, dan kepala MY RUNS menyebut beban
seluruh trainer — `1 running · 6 waiting across everyone` — karena penantian
seseorang terbuat dari pekerjaan orang lain, yang tidak bisa ditunjukkan oleh
daftar miliknya sendiri.

**Tanpa perkiraan waktu, dan itu disengaja.** Antrean prediksi bisa memberikan
satu karena setiap run berbentuk sama; sebuah run training sebanyak epoch yang
diminta pemiliknya, jadi job di depan Anda bisa memakan empat menit atau empat
jam. Angka dengan sebaran seperti itu lebih buruk daripada tidak ada — orang
merencanakan sesuatu di atasnya, lalu ia meleset.

Menampilkan nomor antrean langsung memunculkan masalah kejujuran: **nomor
menjanjikan barisan yang bergerak, dan barisan ini tidak bisa.** Sebuah run
di-dispatch tepat sekali, saat ia dibuat; percobaan yang gagal meninggalkannya
di `queued` selamanya. Enam menumpuk begitu dalam satu sore.

Daripada melemahkan tampilannya, antreannya yang dibuat nyata:
`training:dispatch-queued`, dijadwalkan tiap menit, mengirim run tertua ketika
trainer bebas. Satu per satu — trainer memegang satu GPU dan menolak job kedua,
jadi mengirim lebih banyak hanya memanen penolakan. Urutannya `created_at`,
sama persis dengan yang ditampilkan sebagai posisi; dua definisi "berikutnya"
akan berselisih dan selisihnya muncul sebagai antrean yang melompat.

Run yang tidak bisa dikirim menuliskan alasannya di barisnya sendiri, bukan
hanya di log — kegagalan yang diam adalah justru yang ingin diakhiri perintah
ini. Dan gagal mengirim **bukan** kegagalan perintah: trainer yang mati adalah
keadaan biasa di sini, dan exit non-nol hanya akan memenuhi log penjadwal
dengan alarm tentang sesuatu yang tak bisa diperbaiki dari sisi ini.

Lima tes, salah satunya menangkap kekeliruan saya sendiri: `Http::fake()` yang
dipanggil dua kali **menambah** stub alih-alih menggantinya, jadi pola `*`
pertama tetap menang dan "pemulihan" yang hendak diuji tidak pernah terjadi.

---

## [1.32.0] - 2026-08-25

### Training peneliti: 422 yang bertahan karena ia hanya menyerang job baru

Perbaikan `hyperparameters` di `1.30.0` benar, tapi bukan penyebab terakhirnya.
Yang tersisa hanya terlihat setelah payload yang dikirim **Octane yang sedang
berjalan** ditangkap apa adanya — bukan dibangun ulang di proses baru:

```json
"resume_from_epoch": null
```

`current_epoch` di database `NOT NULL DEFAULT 0`. MySQL menerapkan default itu
saat INSERT dan **tidak pernah memberi tahu Eloquent**: objek yang dikembalikan
`create()` hanya memegang atribut yang dioper kepadanya, jadi kolom itu terbaca
`null` sampai ada yang memanggil `fresh()`. Trainer mendeklarasikan
`resume_from_epoch: int = 0`, yang bukan Optional, dan Pydantic menolaknya
dengan `"Input should be a valid integer"`.

Itulah sebabnya ia bertahan begitu lama. Job yang **baru dibuat** peneliti
selalu ditolak; job yang sama yang di-dispatch ulang belakangan — sudah
bolak-balik lewat database — selalu lolos. Menguji dengan tangan lewat tinker
hanya pernah menyentuh bentuk yang kedua. Jebakan yang sama menggigit
`verify_tls` sehari sebelumnya.

Diselesaikan di tepi tempat JSON-nya dibuat, seperti `hyperparameters`:
`(int) ($job->current_epoch ?? 0)`. Tesnya memeriksa **kawatnya**, bukan array
hasil decode — di PHP `null` dan `0` sama-sama falsy, dan yang dibaca trainer
adalah JSON-nya.

### Penolakan trainer kini menyebut alasannya

"The trainer refused the job (HTTP 422)" menyebut angka dan membuang
satu-satunya bagian yang bisa ditindaklanjuti. FastAPI selalu mengirim
`{"detail":[{"loc":[...],"msg":"..."}]}` yang menyebut persis kolom mana dan
apa yang salah dengannya — dan kami membuangnya, lalu menebak. Dua kali.

`whyRefused()` kini melampirkannya: `body.resume_from_epoch: Input should be a
valid integer`. Angka statusnya tetap, karena ia memisahkan "ditolak" dari
"tidak terjangkau"; kalimatnya yang menyebut apa yang harus diubah.

### `post_max_size` 8M memutus training tepat di garis akhir

Catatan lama di `CLAUDE.md` mengatakan batas `php.ini` "sebagian besar tidak
berlaku" di bawah Octane. Itu benar untuk `upload_max_filesize` — RoadRunner
mengurai multipart sendiri — dan **salah** untuk `post_max_size`, yang dipaksakan
middleware `ValidatePostSize` Laravel jauh sebelum RoadRunner ikut bicara.

Nilainya masih bawaan **8M**, dan gejalanya tidak terlihat seperti batas ukuran:

- run yang sudah melatih empat epoch dengan benar mati dengan
  `413 Client Error: Request Entity Too Large` ketika mengirim bobotnya pulang;
- dataset 19 MB yang dikirim utuh dijawab "The POST data is too large",
  sementara arsip yang sama lewat jalur berkeping naik tanpa keluhan, karena
  tiap kepingnya kecil.

Sekarang 256M, dan `upload_max_filesize` disamakan supaya keduanya tidak bisa
berselisih. `php.ini` dibaca sekali per proses, jadi Octane harus dilahirkan
ulang setelah mengubahnya.

`.rr.yaml` kosong dan itu bukan kekeliruan: Octane mengoper setelan RoadRunner
sebagai flag `-o`, jadi tidak ada apa pun untuk dicari di berkas itu.

### Terbukti ujung ke ujung

Bukan "diterima", melainkan selesai:

| Tahap | Hasil |
|---|---|
| Unggah dataset 19,5 MB | lolos (sebelumnya "POST data is too large") |
| Dispatch ke Kaggle | diterima (sebelumnya 422) |
| Training | MAE 0,014374 · PSNR 39,06 dB · SSIM 0,9863 |
| Unggah bobot 83,7 MB | tersimpan (sebelumnya 413) |
| Job | `completed` |

Run sebelumnya di sesi yang sama menunjukkan loss turun antar epoch: MAE
0,014994 → 0,014686, PSNR 38,21 → 38,79 dB.

---

## [1.31.0] - 2026-08-25

### Siapa yang sedang memakai model, tanpa ada yang perlu menyimpulkannya

Satu-satunya cara administrator menjawab "job siapa yang sedang dikerjakan GPU"
adalah membaca activity log dan mencari "memulai analisis" yang belum ada
penyelesaiannya. Itu penyimpulan, dan ia salah begitu dua run bertumpang
tindih atau sebuah worker mati di tengah jalan.

Sumber yang benar bukan log itu. `user_activities` adalah jejak audit: ia
mencatat peristiwa yang **sudah terjadi**, dan tidak mengatakan apa pun tentang
apakah run-nya masih berjalan. `analysis_records` menyatakannya langsung —
`processing` untuk yang sedang dikerjakan, `pending` untuk yang menunggu — dan
barisnya sudah membawa `user_id`, `model_id`, `input_files_count` dan
`created_at`. Tidak ada yang perlu diturunkan, dan tidak ada yang bisa
melenceng dari kenyataan, karena inilah kenyataan yang dikerjakan worker.

`GET /api/admin/queue`: yang berjalan di atas, lalu barisan antrean menurut
urutan kedatangan, masing-masing dengan pemilik, model, jumlah frame, sudah
berapa lama, nomor posisi, dan perkiraan tunggu.

**Satu definisi antrean, bukan dua.** Nomor posisi di layar administrator
berasal dari `App\Services\QueueBoard`, dan `AnalysisController` kini membaca
dari sana juga alih-alih menghitung sendiri. Dua implementasi "posisi ke
berapa" akan berselisih pada perubahan pertama, dan perselisihannya muncul
sebagai layar satu orang membantah layar orang lain. Sebuah tes memaksa
keduanya menjawab angka yang sama untuk job yang sama.

Job yang sedang berjalan **tidak** diberi nomor: ia tidak sedang menunggu apa
pun, dan menomorinya bersama antrean akan mengatakan ia masih di dalam barisan.

`meta` membawa keadaan `QueueHealth` dengan pesan versi administrator —
lengkap dengan perintahnya. Antrean panjang dan worker mati terlihat identik
dari daftar job yang menunggu, padahal yang satu menuntut kesabaran dan yang
lain menuntut `npm run serve:all`.

Hanya baca. Membatalkan run milik orang lain dari sini adalah fitur lain dengan
akibat lain, dan menyelipkannya ke layar yang tugasnya menjawab pertanyaan
mengundang orang melakukannya tanpa sengaja.

Delapan tes, termasuk dua yang mengoreksi asumsi yang salah: baris antrean
**tidak** bisa hidup lebih lama dari pemiliknya (`user_id` memakai `cascade`,
jadi menghapus akun ikut membersihkan pekerjaannya dan penomorannya merapat),
sementara model **memang** bisa dicabut sementara pekerjaannya masih mengantre
(`model_id` memakai `set null`).

### Layarnya

**Admin → Queue**, di sebelah Model Management karena ia menjawab pertanyaan
tentang model, bukan tentang jejak audit. Yang berjalan ada di atas dengan
spinner alih-alih nomor; barisan di bawahnya bernomor `#1`, `#2` — angka itulah
yang pertama ditemukan mata, dan ia adalah urutan seluruh halaman. Setiap baris
menyebut nama dan surel pemiliknya, modelnya, jumlah frame, sudah berapa lama,
dan "mulai kira-kira N menit lagi".

Polling sepuluh detik, secadans yang sama dengan strip status model. Papan yang
hanya berubah bila tombol ditekan adalah tangkapan layar, dan hal pertama yang
akan dilakukan orang dengannya adalah menekan tombol itu berulang-ulang.

Poll yang gagal **tidak** mengosongkan papan yang sudah tampil: angka yang agak
basi mengalahkan halaman kosong, dan tick berikutnya membereskannya tanpa siapa
pun menyentuh apa pun.

Rata-rata per run ikut di kepala halaman, karena setiap perkiraan di situ
dibangun darinya — layar yang menunjukkan cara kerjanya sendiri, bukan angka
yang muncul entah dari mana.

Dua kesalahan nyata sempat lolos ke `admin_queue_service.dart` dan tidak akan
pernah dikompilasi: `ApiClient()` — konstruktornya privat, yang ada hanya
`ApiClient.instance` — dan pembacaan `response.data`, padahal `get()` sudah
mengembalikan `Map` yang sudah di-decode. Keduanya diperbaiki.

Sembilan tes untuk lapisan di bawah layarnya, masing-masing memagari satu
perbedaan yang akan hilang diam-diam: job berjalan tanpa nomor, model yang
sudah dicabut terbaca "Model removed" alih-alih ruang kosong, dan antrean macet
dibedakan dari antrean yang sekadar panjang.

---

## [1.30.0] - 2026-08-25

Sesi pengujian di perangkat sungguhan, dengan sesi Kaggle hidup untuk prediksi
dan training. Enam keluhan, dan hampir semuanya berakhir di tempat yang bukan
tebakan pertama.

### Training tidak pernah berangkat, karena tiga hal berturut-turut

Peneliti mengunggah dataset, menekan start, dan layar kembali meminta unggahan
baru. Empat job menumpuk di `queued`, dan log trainer di Kaggle hanya berisi
`GET /` — tidak sekali pun `POST /train`.

Tiga penyebab, ditemukan satu demi satu karena masing-masing menyembunyikan
yang berikutnya:

1. **`callback_url` masih `http://localhost`.** `TrainerDispatcher` memang
   menolak berangkat dalam keadaan itu, dan penolakannya benar: host GPU di
   Kaggle tidak mungkin menjangkau alamat itu untuk melapor balik. Yang salah
   bukan penjaganya, melainkan tidak ada yang pernah menyetel
   `TRAINING_CALLBACK_URL`. Tailscale tidak bisa dipakai di sini — itu jaringan
   privat, dan Kaggle tidak ada di dalamnya.

2. **HTTP 405.** Notebook mencetak akar terowongannya dan berkata "daftarkan
   ini sebagai trainer URL", jadi itulah yang ditempelkan. Tapi route-nya
   `POST /train`, dan FastAPI menjawab POST ke akar dengan 405 — penolakan yang
   terbaca seperti trainer menolak pekerjaan, padahal platform sedang mengetuk
   pintu yang salah. Endpoint inferensi didaftarkan lengkap dengan path-nya
   (`…/predict`) karena notebook prediksi mencetaknya begitu, jadi dua konvensi
   hidup berdampingan di registry dan tidak ada yang keliru. `trainEndpoint()`
   menambahkan path hanya bila tidak ada.

3. **HTTP 422: `{"loc":["body","hyperparameters"],"msg":"Input should be a
   valid dictionary","input":[]}`.** PHP hanya punya satu tipe array, dan
   `json_encode` menulis yang kosong sebagai `[]`. Trainer mendeklarasikan
   `hyperparameters: dict`, jadi **setiap run yang dibiarkan pada nilai
   bawaannya ditolak**, sementara run yang satu saja hyperparameter-nya diisi
   lolos — kegagalan yang bergantung pada kolom yang tidak pernah disentuh
   siapa pun.

Setelah ketiganya: trainer menerima job, mengunduh dataset, mencoba memuat
bobot, gagal, **dan melaporkan kegagalannya kembali** — job jadi `failed`
dengan pesan nyata, bukan menggantung selamanya. Itu perbedaan yang dicari.

Tiga tes baru menjaganya. Yang lama memakai `Http::fake(['*' => …])`, yang
menerima URL apa pun dan tidak memeriksa badan permintaan, jadi ia tidak
mungkin menangkap dua bug terakhir.

### Path bobot di skrip training menunjuk dataset yang tidak ada

Kegagalan pertama setelah dispatch berhasil: errno 2 pada
`deepct-unet/keras/v1/1/…`, sementara bobot yang benar-benar terpasang ada di
`deepct-ai/tensorflow2/default/1/…` — path yang dipakai skrip inferensi dan
terbukti berhasil.

Kaggle menyusun path itu dari slug, framework dan versi yang dipilih saat model
dilampirkan, jadi ia berubah karena alasan yang tidak ada hubungannya dengan
kode ini. `find_base_model()` mencari berkasnya, mendahulukan yang bernama
`generator`, dan berkata apa yang harus dilakukan bila tidak menemukan apa pun.
`BASE_MODEL_PATH` tetap menang bila diisi.

### Bingkai model merah padahal online

Bukan soal data: API menjawab `"status":"online"`, dan `ModelHealthChecker`
memang sudah memperlakukan 404 di akar sebagai tanda hidup.

`AppTheme.primary` adalah **merah BRIN**, dan kartu model memakai
`selected ? AppTheme.primary : AppTheme.border`. Jadi memilih model yang sehat
menggambar bingkai merah di sekelilingnya — merah yang sama yang dipakai strip
di atasnya untuk "offline". Seleksi dan status diucapkan dalam satu bahasa, dan
status yang kalah.

Warna kini milik kesehatan; seleksi dibawa ketebalan bingkai dan tombol radio,
yang sejak awal tidak pernah ambigu.

### Slider frame yang patah-patah

`FrameStackViewer` memanggil `loader` dari dalam `itemBuilder` sebuah
`PageView`. Setiap langkah memulai pengambilan baru dan menaruh spinner di
layar sampai dijawab — jadi menarik slider menghasilkan rentetan lingkaran
abu-abu, bukan gerakan. Tidak ada yang lambat di widget itu; ia diminta
mengunduh justru selama gerakan yang harus mulus.

ImageJ terasa kontinu karena stack-nya sudah ada di RAM sebelum scrollbar
melakukan apa pun. Sekarang seluruh stack dimuat di muka — dari frame yang
sedang dilihat ke luar, empat sekaligus — dengan progress yang menyebut
angkanya. Setelah itu satu langkah berharga satu `setState` dan nol I/O.

Ditambah tombol putar dengan pilihan 4/8/15 fps, panah kiri-kanan, spasi untuk
putar-jeda, dan `divisions` dibuang dari `Slider` supaya ibu jari tidak
tersangkut di takik. Tombol **PLAY STACK** di halaman Frames, karena sebelumnya
scrubber itu hanya bisa ditemukan dengan mengetuk thumbnail — tidak ada yang
mengumumkan keberadaannya.

Tesnya menangkap penyebabnya, bukan gejalanya: menyusuri seluruh stack dua kali
tidak boleh menambah satu pun pemanggilan loader.

### Antrean yang tidak punya bentuk

`queue_position` sudah dihitung — **hanya di endpoint detail**, yang tidak
pernah dipanggil layar riwayat. Jadi satu-satunya tempat orang menunggu
menerima `null` dan tidak menggambar apa pun. Seseorang yang menatap spinner
tanpa angka tidak bisa membedakan antrean satu dari antrean sembilan, dan
setelah beberapa menit kesimpulan yang masuk akal adalah bahwa itu rusak.

Posisi kini ikut di daftar, satu kueri untuk seluruh halaman. Estimasinya
berhenti menebak: `position × 5 menit` ditulis sebelum satu run pun diukur, dan
run sungguhan memakan 50 detik sampai dua setengah menit — tebakannya
melebih-lebihkan tiga kali lipat, dan estimasi yang selalu salah ke arah yang
sama mengajari orang mengabaikannya. Sekarang rata-rata dua puluh run terakhir,
dari `processing_time_seconds` yang memang sudah dicatat.

### Peringatan yang benar, dibacakan kepada orang yang salah

"Nothing has picked this job up for 11 minute(s) … `npm run serve:all`" tepat
untuk administrator yang harus mengetiknya, dan tepat-tepat salah di layar
peneliti: terbaca sebagai kesalahan yang mereka buat, dalam kosakata yang tak
berguna bagi mereka, di atas pekerjaan yang tidak bisa mereka lanjutkan.

Diam bukan jawabannya — itu mengembalikan orang ke keadaan yang justru ingin
dihindari kelas ini. Jadi faktanya tetap disampaikan, penyebabnya disebut
sebagai urusan kami, dan perintahnya tidak.

Peringatan itu memang benar hari ini: `queue:work` sungguh tidak berjalan,
empat job menunggu, yang tertua 1714 detik.

### Queue worker mati kehabisan memori di tengah job

Ditemukan justru karena worker-nya dinyalakan: keempat job selesai (53 detik,
2m27s, 55 detik — panggilan GPU sungguhan), lalu prosesnya keluar.

Dua kesalahan bertumpuk. `npm run queue` tidak menyetel `--memory` sama sekali,
dan `--memory` sendiri **tidak menaikkan `memory_limit`** — ia hanya menentukan
kapan worker merestart dirinya. Batas sebenarnya 512 MB.

Yang menabraknya: `TiffPreview` menjadikan setiap piksel satu entri array PHP,
dua kali sekaligus selagi hasil `unpack` disalin ke akumulator, dan entri array
PHP berharga puluhan byte untuk piksel yang di disk hanya dua byte.

`MAX_PIXELS` adalah `8192 × 8192` — enam puluh tujuh juta piksel, yang tidak
pernah sanggup dikerjakan implementasinya. Penjaganya mengizinkan apa yang tak
bisa dilalui kodenya, jadi kegagalannya bukan penolakan melainkan fatal error
di dalam queue worker: proses mati di tengah job, membawa run-nya, dan
meninggalkan "queued" di layar tanpa apa pun yang menjelaskan.

Sekarang `2048 × 2048` — empat kali lipat frame 1024×1024 yang dipakai platform
ini — dan `php -d memory_limit=1G … --memory=768`, supaya worker mendaur ulang
dirinya sebelum menabrak batas keras. Frame yang melampauinya ditolak dengan
kata-kata; hanya *pratinjau*-nya yang ditolak, berkasnya tetap bisa diunduh.

Menulis ulang dekoder itu agar tidak membangun array sejuta integer adalah
perbaikan tersendiri, dan dicatat sebagai itu di ROADMAP — bukan dikerjakan
setengah jalan di akhir sesi.

### QUALITY CHECK keluar dari hasil prediksi

Ia menjawab "model ini bagus atau tidak", yang merupakan pertanyaan tentang
sebuah model, bukan tentang satu run milik peneliti — dan pada prediksi yang
sudah selesai ia terbaca sebagai nilai atas pekerjaan yang sudah mereka terima.

Angkanya **tidak dihapus**, dan perhitungannya tetap jalan: tabel perbandingan
model berdiri di atas `mae` dan `psnr` yang sama. Menghapus pengukurannya akan
mengosongkan fitur perbandingan itu.

### Endpoint worker yang tidak dipakai siapa pun

`/predict_png` dan `/generate_gif` dibuang dari skrip prediksi. Platform hanya
mem-POST ke `endpoint_url`; PNG pratinjau dirender Laravel sendiri di
`TiffPreview` (PHP murni, tanpa ekstensi imaging), dan GIF digantikan penampil
stack di dalam aplikasi. Endpoint yang tidak dipanggil hanya menambah permukaan
yang harus dijaga.

Sebagai gantinya skrip prediksi kini punya `GET /`, seperti kembarannya. Health
check memang sudah menerima 404 sebagai tanda hidup, tapi log notebook jadi
penuh 404 yang terlihat seperti kesalahan padahal bukan. Ia melaporkan
`protected`, jadi satu lirikan menjawab apakah rahasianya sudah berlaku.

---

## [1.29.2] - 2026-08-25

### Sisi worker dari rahasia bersama, yang membuat F7 baru separuh jadi

Diminta sebuah skrip training untuk Kaggle. Skripnya **sudah ada** —
`script-api-train-deepct.py`, 533 baris, lengkap dengan custom layer, sampling
`balanced_t`, checkpoint, heartbeat, satu PNG per epoch, dan pembuka terowongan.
Itulah yang dipanggil `TrainerDispatcher`. Menuliskan yang kedua hanya akan
menghasilkan dua skrip yang saling menyimpang pada sentuhan pertama.

Yang **tidak** ada adalah pemeriksaan rahasianya.

`1.28.0` membuat platform mengirim `Authorization: Bearer` pada setiap panggilan
ke worker. Tidak satu pun skrip worker memeriksanya. Fitur keamanannya baru
separuh: platform mengirim kredensial yang tidak ada yang memvalidasi, dan
`POST /train` menerima perintah dari siapa pun yang tahu URL terowongannya.
Begitu pula `/predict`, `/predict_png` dan `/generate_gif` di skrip inferensi.

Sekali lagi, di Kaggle di balik terowongan bernama acak itu bertahan — tidak
ada yang menebak namanya. Di workstation beralamat tetap di jaringan lab, ia
tidak menahan apa-apa: siapa pun di jaringan itu bisa memulai training
berjam-jam di kartu orang lain.

Keempat endpoint kerja kini memeriksanya. `hmac.compare_digest`, bukan `==`:
perbandingan string biasa berhenti pada byte pertama yang berbeda, dan selisih
waktunya cukup untuk memulihkan rahasia satu karakter demi satu karakter.

`GET /` **sengaja dibiarkan terbuka**. Ia tidak memulai apa pun dan tidak
menghabiskan apa pun, dan bisa memeriksa terowongan masih hidup dari peramban —
tanpa menempelkan kredensial ke bilah alamat — lebih berharga daripada
menyembunyikan keberadaan endpoint-nya. Ia kini melaporkan `protected`, supaya
satu lirikan menjawab "rahasianya sudah berlaku atau belum".

**Kosong berarti terbuka, dan itu tetap default-nya.** Sama seperti
`verify_tls`: menyalakannya diam-diam akan memutus sesi Kaggle yang sedang
berjalan, dan keputusan itu harus dibuat di tempat yang terlihat.

---

## [1.29.1] - 2026-08-25

### Analisis yang berhenti di "queued", dan aturan yang ditemukan keliru karenanya

#### Tidak ada yang mengonsumsi antreannya

Dilaporkan: analisis tidak pernah diproses. Buktinya tidak ambigu — dua job
duduk di tabel `jobs` dengan `attempts: 0`, **nol** job gagal, dan tidak ada
satu pun proses `queue:work`. Yang berjalan hanya Octane dan empat worker
RoadRunner. Jobnya masuk antrean dengan benar, payloadnya utuh, tidak ada yang
error. Tidak ada yang **mengambilnya**.

`README.md` proyek ini sudah menuliskannya sejak lama: tanpa `queue:work`,
"uploads succeed but predictions stay `pending` forever". Kegagalannya
sepenuhnya senyap — tidak ada error, tidak ada log, `failed_jobs` kosong.

Penyebabnya skrip `start.ps1` yang dibuat untuk pengujian Tailscale: ia
menyalakan MySQL, Octane, dan server web statis, dan **melewatkan queue worker
beserta scheduler**. Kini kelimanya dijaga, dengan pemeriksaan berbasis proses
karena keduanya tidak punya port untuk diuji, dan skripnya menutup dengan
kalimat yang menyebut gejala ini apa adanya.

Scheduler yang hilang punya kegagalan senyapnya sendiri, hanya lebih lambat
terasa: hasil kedaluwarsa tidak pernah dihapus, dan `models.status` menyimpan
apa pun yang ditulis health check manual terakhir — sehingga worker yang mati
tetap terbaca online.

#### Aturan hold-out ternyata menuntut keadaan yang tidak akan pernah ada

Begitu antreannya jalan, dua prediksi selesai terhadap GPU sungguhan dan
keduanya mengembalikan `validation: NULL`. Bukan kegagalan — syaratnya memang
tidak terpenuhi. Tetapi arsipnya menjelaskan kenapa syarat itu salah sejak
awal: framenya **51, 53, 55, … 69**, selang satu.

Aturan semula menuntut tiga frame **berurutan**. Peneliti, menurut definisinya,
mengunggah frame **dengan celah** — itu seluruh produknya. Menuntut tiga yang
berurutan berarti menuntut justru keadaan yang paling tidak mungkin ada.

Yang sebenarnya diperlukan: sebuah frame terunggah yang menjadi **titik tengah
persis** dari dua frame terunggah lainnya. "Tiga berurutan" hanyalah bentuk
khususnya dengan jarak 2. Pada arsip itu, 53 adalah titik tengah 51 dan 55 dan
bisa diperiksa sejak semula.

Rentang **tersempit** yang dipilih, disengaja: titik tengah antara 51 dan 69
membentang sembilan frame gerakan, sementara 51 dan 55 membentang dua — dan dua
itulah pekerjaan yang sebenarnya diminta dari model. Mengukur pada rentang
lebar akan melaporkan model lebih buruk daripada tugasnya.

#### Angka pertama yang diukur, bukan dikutip

Arsip yang sama, dijalankan ulang dengan aturan baru:

| | |
|---|---|
| Frame disembunyikan | `HONDA_Used_0053.tif`, digambar ulang dari 51 dan 55 |
| MAE | **359,7** hitungan 16-bit |
| RMSE | 688,1 |
| PSNR | **39,58 dB** |
| Rentang frame acuan | 108 – 56.487 |

Galat rata-rata **0,64% dari rentang dinamis frame**. Setiap angka kualitas
sebelum ini di repo berasal dari dokumentasi model yang sudah ada; ini yang
pertama diukur oleh platform terhadap data penggunanya sendiri.

Sepuluh frame masuk, sembilan dihasilkan, 36 detik. `CaptureResultEvidence`
berjalan setelahnya dalam satu detik — pemisahan di 1.29.0 bekerja seperti
rancangannya.

#### Terverifikasi

`php artisan test` **327 lulus** (dari 325, 1.296 asersi). Tiga test menutup
arsip berjarak tetap yang kini terukur, arsip yang memang tidak menawarkan
titik tengah, dan rentang ganjil yang tidak boleh dipilih — bertambah dua
bersih, karena yang kedua menggantikan test lama yang menguji aturan "tiga
berurutan" yang sudah tidak ada.

---

## [1.29.0] - 2026-08-25

### Empat hal yang dibutuhkan sebelum platform ini pindah ke Raspberry Pi

Rencananya: Pi sebagai server platform, workstation ber-GPU sebagai worker,
NAS sebagai tempat berkas. Semuanya lebih kecil, lebih lambat, dan lebih mudah
mati daripada laptop pengembangan — dan empat asumsi yang selama ini aman
berhenti aman di sana.

#### Disk penuh berhenti jadi kejutan

Tidak ada satu pun pemeriksaan ruang kosong sebelum menerima arsip. Unggahan
2 GB ke mesin bersisa 3 GB berhasil, menghasilkan frame lebih banyak daripada
yang diterimanya, lalu berhenti dengan disk di angka nol — dan di titik itu
MySQL tidak bisa menulis, antrean tidak bisa mencatat kegagalannya, dan log
yang akan menjelaskan semuanya juga tidak bisa ditulis.

Sebuah arsip menghabiskan disk **tiga kali lipat** sebelum selesai: frame yang
diekstrak darinya, frame yang dihasilkan model dari itu, dan arsip sementara
yang dibangun untuk mengembalikan hasilnya. Frame bangkitan rutin melebihi
jumlah yang diunggah — dua batas mengelilingi celah lima menghasilkan empat —
jadi tiga adalah lantai, bukan margin.

Ditolak dengan **507**, bukan 400: tidak ada yang salah dengan permintaannya,
dan berkas yang lebih kecil tidak akan mendapat jawaban berbeda.

#### NAS yang lepas berhenti jadi tak terlihat

Ini kegagalan yang lebih berbahaya dan seluruhnya senyap. Share yang tidak
ter-mount **bukan** kesalahan — ia direktori kosong biasa, dan `Storage::put()`
menulis ke dalamnya tanpa mengeluh. Frame-nya mendarat di disk milik host,
peneliti diberi tahu jobnya berhasil, dan berkasnya ada di tempat yang tidak
akan dicari siapa pun.

Jadi mount-nya membawa berkas sentinel yang hanya ada di sana. Hilang berarti
tidak ter-mount, dan tidak ter-mount berarti menolak alih-alih menulis ke
tempat yang keliru.

**Mati secara default.** Instalasi satu disk tidak punya apa pun untuk absen,
dan menyalakannya tanpa membuat sentinel lebih dulu akan menolak setiap
unggahan pada setiap deployment yang ada. `php artisan storage:mark`
membuatnya, dan perintahnya menolak melakukannya diam-diam: ia menunjukkan
ukuran volume lebih dulu, karena angka itulah pemeriksaannya — mount point yang
kosong melaporkan disk host, yang biasanya berukuran sangat berbeda.

#### Thumbnail berhenti menahan antrean

Merender TIFF 16-bit jadi PNG adalah PHP murni dan CPU-bound: sekitar setengah
detik per frame 1024×1024 di sini, dan beberapa kali lipat itu di Raspberry Pi.
Enam frame berarti sepuluh sampai lima belas detik satu inti — dihabiskan
**setelah** pekerjaan yang diminta peneliti selesai, sementara GPU menganggur
dan job berikutnya menunggu di belakangnya.

Sekarang `CaptureResultEvidence` adalah job tersendiri. Interpolasinya selesai
dan peneliti diberi tahu; gambarnya menyusul sesaat kemudian.

#### Worker yang tidur berhenti menghanguskan pekerjaan

`tries` naik dari 1 ke 3, tetapi hanya satu jenis kegagalan yang memakainya.

Model yang **menjawab** dan menolak akan menolak dengan cara yang sama dua
menit lagi; itu digagalkan di tempat, karena mengulangnya berarti mengerjakan
ulang frame yang sudah jadi untuk sampai ke jawaban yang sama. Worker yang
**tidak menjawab sama sekali** adalah hal yang benar-benar berbeda, dan itulah
yang terjadi ketika GPU tinggal di workstation alih-alih di pusat data.
Workstation tidur. Ia reboot untuk pembaruan. Seseorang mencabutnya untuk main
game. Menggagalkan job seorang peneliti karena sebuah mesin tertidur sembilan
puluh detik bukan laporan kesalahan — itu pekerjaan yang hilang.

Dibedakan lewat tipe exception, bukan lewat kata-kata dalam pesan:
`ConnectionException` adalah Guzzle mengatakan permintaannya tidak pernah
selesai, sementara setiap penolakan yang dilempar job ini sendiri adalah
`Exception` biasa yang membawa kata-kata worker.

Dan pesannya kini sama baiknya entah bisa diantrekan ulang atau tidak.
`cURL error 7: Failed to connect` adalah kalimat yang benar dan tidak berguna:
ia tidak memberi tahu peneliti apa pun yang bisa ditindaklanjuti, dan terbaca
seolah unggahan merekalah yang salah.

#### Ruang disk jadi sesuatu yang bisa dilihat

`GET /admin/storage` dan sebuah panel di dashboard admin. Yang penting bukan
totalnya: volume di 90% yang sebagian besar berisi keluaran prediksi baik-baik
saja, karena sapuan retensi mengembalikannya dalam sehari. Volume di 90% berisi
dataset training tidak, karena tidak ada yang mengambilnya kembali. Satu angka
"terpakai" tidak bisa membedakan keduanya, jadi rinciannya dipisah.

#### Terverifikasi

`php artisan test` **325 lulus** (dari 310, 1.288 asersi), `flutter analyze`
bersih, `flutter test` **228 lulus** (dari 220). Total **553**.

---

## [1.28.0] - 2026-08-25

### Worker-nya akhirnya punya kunci

Worker inferensi tidak pernah punya autentikasi apa pun. Di Kaggle, di balik
terowongan bernama acak, itu keamanan lewat ketidaktahuan — dan ia bertahan,
karena tidak ada yang menebak `reaffirm-bullwhip-subzero`. Di sebuah workstation
pada alamat tetap di jaringan lab, ia tidak menahan apa-apa: siapa pun di
jaringan itu bisa memakai GPU-nya, dan catatan keamanan proyek ini sendiri sudah
menuliskan bahwa mengetahui endpoint berarti melewati platform sepenuhnya.

Ini dikerjakan **sebelum** GPU-nya pindah ke LAN, bukan sesudah. Menutup pintu
setelah ia dibuka adalah pekerjaan yang berbeda.

#### Lima duplikasi jadi satu

Sebelum menambahkan apa pun, ada masalah yang lebih dulu: **lima tempat**
membangun panggilan keluar ke worker, masing-masing mengulang dua baris yang
sama dengan tangan — job interpolasi, health check (dua kali: tunggal dan
pooled), trainer dispatcher, dan test prediction milik admin.

Menambahkan kredensial ke lima titik panggil berarti lima tempat untuk lupa,
dan yang terlupa persis yang bocor. `WorkerRequest` sekarang membangun
semuanya. `withoutVerifying` kini hanya muncul di satu berkas.

#### Rahasianya

Dikirim sebagai `Authorization: Bearer` — konvensi yang sudah diketahui proxy
dan pembersih log untuk disunting, sementara `X-Worker-Token` buatan sendiri
akan melenggang ke dalam log dalam bentuk polos.

Disimpan **terenkripsi**: sebuah dump basis data tidak boleh menyerahkan kunci
ke GPU orang lain. Dan **tulis-saja** melalui API — administrator bisa
memasangnya atau menghapusnya, tidak pernah membacanya kembali. Yang dijawab
registry hanyalah `has_auth_token`.

`$hidden` pada modelnya, bukan penyaringan di controller: model mencapai klien
dari setengah lusin tempat — daftar registry, pemilih di layar unggah, metadata
sebuah baris aktivitas — dan melewatkan satu saja berarti menerbitkan kredensial
itu ke setiap peneliti yang login.

Satu perilaku yang sengaja dijaga: pada pembaruan, **field yang tidak dikirim
membiarkan rahasianya utuh**, dan string kosong yang menghapusnya. Form yang
selalu mengirim setiap field akan menghapus kredensial setiap kali ada yang
membetulkan salah ketik di deskripsi. Ada test untuk itu.

#### TLS jadi pilihan, bukan keputusan yang sudah diambil

`verify_tls` **default false** — persis yang dilakukan kode sebelum ini, karena
`withoutVerifying()` di-hardcode di kelima tempat itu untuk sertifikat ngrok dan
Colab. Membuatnya default true berarti menyalakan verifikasi TLS pada endpoint
hidup yang belum pernah diuji dengan itu.

Sebagai gantinya, form admin menawarkannya **tercentang saat membuat model
baru**. Endpoint baru mendapat jawaban yang aman; yang lama tidak berubah
perilakunya diam-diam. Keputusannya dibuat di tempat seseorang bisa melihatnya.

#### Terverifikasi

`php artisan test` **310 lulus** (dari 298, 1.241 asersi), `flutter analyze`
bersih, `flutter test` **220 lulus** (dari 215). Total **530**.

Dua belas test backend menutup rahasianya sampai ke worker, tidak pernah sampai
ke klien, terenkripsi saat disimpan, dan tidak terhapus tanpa sengaja.

---

## [1.27.1] - 2026-08-24

### Satu gangguan jaringan tidak lagi mengosongkan gambar selamanya

`AuthedImageCache` menyimpan **setiap** kegagalan sebagai `null` dan
menyimpannya untuk seumur hidup aplikasi. Satu koneksi yang putus sedetik
berarti gambar itu kosong sampai aplikasi ditutup, tanpa satu pun percobaan
ulang. Itu bug yang ikut terkirim sejak kelas ini ditulis, dan ia ditemukan
saat menelusuri halaman depan yang gambarnya hilang.

Cache-nya sendiri tidak opsional — tanpa itu daftar dua puluh baris memicu dua
puluh permintaan HTTP setiap kali widget-nya dibangun ulang. Yang keliru adalah
apa yang dianggap layak diingat.

Sebuah **"tidak ada"** layak diingat: 404 dan 410 adalah server yang berbicara,
dan akun tanpa foto besok pun tetap tanpa foto. Sebuah **kegagalan** tidak:
koneksi yang putus, timeout, 500, atau terowongan yang tertutup tidak
mengatakan apa pun tentang ada atau tidaknya gambar itu. Yang kedua kini tidak
dimasukkan ke cache sama sekali, sehingga pembangunan ulang berikutnya bertanya
lagi.

Kelas ini sebelumnya **tidak punya satu pun test**, padahal justru jalur inilah
yang terlihat rusak. Sekarang ada tujuh, dan yang terpenting menuntut sebuah
kegagalan **tidak meninggalkan apa pun** untuk dipercaya belakangan.

`flutter test` **215 lulus** (dari 208), `flutter analyze` bersih.

---

## [1.27.0] - 2026-08-24

### Sebuah hasil yang bisa dipertanggungjawabkan, bukan sekadar sekantong berkas

Sampai kemarin sebuah job selesai dengan mengembalikan folder TIFF, jumlah
berkas, dan lama proses. Peneliti yang menerimanya tidak punya dasar apa pun
untuk membela hasilnya: tidak ada angka kualitas, tidak ada cara membandingkan
model, dan setelah 24 jam tidak ada apa pun yang tersisa untuk dilihat lagi.
Empat perubahan berikut menutup keempat lubang itu.

#### Validasi hold-out: angka kualitas dari data peneliti sendiri

Frame yang ingin diisi seorang peneliti, menurut definisinya, adalah frame yang
tidak dimiliki siapa pun — jadi tidak ada ground truth untuknya dan tidak akan
pernah ada. Yang bisa dilakukan platform adalah menyembunyikan frame yang
**memang ada**: di mana pun arsip memuat tiga frame berurutan, yang tengah
disisihkan, digambar ulang dari kedua tetangganya, lalu diukur terhadap frame
yang sebenarnya ada di sana.

Hasilnya tersimpan di kolom `validation`: MAE dalam hitungan 16-bit mentah,
RMSE, PSNR dalam desibel, dan rentang frame acuannya sendiri. Yang terakhir itu
bukan hiasan — MAE 40 tidak berarti apa-apa tanpa tahu frame-nya membentang 300
hitungan atau 60.000.

Ongkosnya satu putaran tambahan ke worker. Ia dijalankan **setelah** hasilnya
selesai, dan setiap kegagalannya ditelan menjadi catatan alih-alih dilempar:
sebuah pengukuran yang gagal tidak boleh merenggut interpolasi yang sudah
ditunggu berjam-jam.

`null` ketika arsipnya tidak memuat tiga frame berurutan. Itu kasus biasa, bukan
kegagalan — unggahan berisi frame 1 dan 5 memang tidak menyisakan apa pun untuk
disembunyikan.

Aritmetikanya diuji terhadap angka yang dihitung tangan, bukan terhadap apa pun
yang kebetulan dikeluarkan kodenya: konstanta yang keliru atau kuadrat di tempat
yang salah tidak akan membuat apa pun crash, ia hanya diam-diam menaruh angka
salah ke dalam sebuah skripsi.

#### Manifes di dalam arsip

`manifest.csv` kini menemani `metadata.json`, satu baris per frame: hasil pindai
atau hasil bangkitan, dan untuk yang bangkitan, kedua frame asalnya beserta
generasinya. CSV karena orang yang membukanya sama mungkinnya meraih spreadsheet
seperti meraih pengurai.

#### Dua model pada frame yang sama

`POST /predictions/{id}/rerun` menjalankan frame yang sama lewat model lain.
Registry sejak dulu bisa menampung beberapa endpoint inferensi lengkap dengan
health check — tetapi tidak pernah ada cara menaruh dua di antaranya pada satu
set frame dan melihat mana yang lebih baik. Registry-nya pipa; ini yang
menjadikannya alat ukur.

Frame masukannya **disalin, bukan dibagi**. Menunjuk dua record ke satu folder
berarti menghapus salah satu job — atau membiarkannya kedaluwarsa — ikut
membawa masukan milik yang lain, dan perbandingan yang separuhnya bisa lenyap
sendiri-sendiri bukanlah perbandingan.

Endpoint detailnya kini mengembalikan `comparison`: seluruh run pada frame yang
sama, dengan MAE dan PSNR masing-masing. Kosong ketika hanya ada satu, karena
tabel berisi satu baris terbaca seolah ada yang gagal dimuat.

#### Bukti yang hidup lebih lama dari berkasnya

Hasil dihapus 24 jam setelah dibuat — 1,5 GB TIFF per job bukan sesuatu yang
bisa disimpan mesin lab — dan sampai kemarin itu menyisakan catatan yang
mengatakan sebuah job selesai tanpa bukti apa pun tentang apa yang dihasilkannya.

Enam thumbnail 256px kini disimpan permanen di `prediction-evidence/{id}`, di
luar folder job karena `predictions:cleanup` menghapus folder itu utuh — hidup
di luarnya justru intinya. Diambil menyebar sepanjang run, bukan enam yang
pertama: enam frame awal sebuah sekuens panjang semuanya duduk di sebelah
batas pindai yang sama dan tidak mengatakan banyak tentang sisanya.

Beberapa ratus kilobita membeli jawaban permanen atas "run itu tampak seperti
apa", yang tidak bisa diberikan angka: MAE 40 tidak mengatakan apakah modelnya
menggambar irisan yang masuk akal atau sebuah noda.

Selamat dari kedaluwarsa bukan berarti selamat dari penghapusan — menghapus
sebuah job ikut membawa thumbnail-nya, dan ada test untuk keduanya.

#### Terverifikasi

`php artisan test` **298 lulus** (dari 282, 1.207 asersi), `flutter analyze`
bersih, `flutter test` **208 lulus** (dari 202). Total **506**.

---

## [1.26.0] - 2026-08-24

### Setiap frame buatan kini menyebutkan asal-usulnya

Sampai hari ini sebuah job selesai dengan mengembalikan daftar:
`["frame_002.tif", "frame_003.tif", "frame_004.tif"]`. Daftar itu menyebut
frame mana saja yang dihasilkan, dan tidak lebih.

Yang tidak bisa dikatakannya justru yang paling penting. Untuk celah antara
frame 001 dan 005, titik tengahnya — 003 — digambar lebih dulu dari **dua frame
hasil pindai**. Baru sesudah itu 002 dan 004 digambar, dan keduanya memakai 003
sebagai salah satu batasnya: model sedang diberi makan keluarannya sendiri.
Ketiganya keluar sebagai berkas TIFF yang tampak setara di dalam satu folder,
padahal satu di antaranya berdiri di atas data sungguhan dan dua lainnya
berdiri di atas tebakan model.

Rekursi memang inti metode ini — ia ada untuk menyiasati model yang mengabaikan
`time_scalar` selain 0,5 — tetapi rekursi jugalah yang membuat sebagian
keluaran menjadi turunan keluaran. Sebuah platform riset yang tidak mencatat
bedanya meminta orang mempercayai hasilnya alih-alih memeriksanya.

#### Yang dicatat

Kolom `frame_provenance` pada `analysis_records`, satu entri per frame buatan:

```json
{ "frame": "frame_002.tif", "index": 2, "from": [1, 3],
  "generation": 2, "synthetic_parents": 1 }
```

`generation` bernilai 1 ketika kedua batasnya hasil pindai, 2 ketika salah
satunya sendiri frame buatan, dan naik terus. Itu hitungan berapa kali galat
berpeluang menumpuk, dan `interpolateBetween()` sudah mengetahuinya sepanjang
waktu — ia hanya tidak pernah diminta menyimpannya.

#### Kolom baru, bukan bentuk baru

`interpolated_frames` **tidak disentuh**. Menambahkan bidang ke sana, atau
mengubah tipenya, adalah persis yang mematikan setiap klien terpasang di
1.25.1: APK lama membaca `json['username']` ke `String` non-nullable dan
penguraiannya melempar pada respons 200 yang sehat. Pelajaran itu cukup mahal
untuk dipegang, jadi yang lama tetap apa adanya dan yang baru berdiri sendiri.

Nilainya `null` pada setiap job yang selesai sebelum ini ada. Klien
memperlakukannya sebagai opsional — dua test menuntut galeri tetap tergambar
untuk job lama, dan satu lagi menuntut entri yang cacat hanya merugikan
barisnya sendiri, bukan seluruh halaman.

#### Terlihat di tempat orang melihat frame

Di galeri, frame buatan dulu semuanya memakai lencana `AI` yang sama. Sekarang
frame generasi pertama tetap `AI`, sementara generasi kedua ke atas berbunyi
`AI G2` dalam warna peringatan, dengan tooltip yang menyebut kedua frame
asalnya. Perbedaan itulah intinya: keluaran model dan keluaran model yang
disuapkan kembali ke model bukan bukti yang sama.

#### Ikut di dalam arsip

`metadata.json` di dalam unduhan lengkap kini membawa array yang sama. Enam
bulan lagi arsip itu mungkin satu-satunya yang tersisa, dan satu folder berisi
TIFF tidak bisa menyebut mana yang keluar dari pemindai dan mana yang digambar
model — apalagi mana yang digambar di antara dua frame yang juga digambar.

#### Terverifikasi

`php artisan test` **282 lulus** (dari 279), `flutter analyze` bersih, dan
`flutter test` **202 lulus** (dari 197). Test barunya memeriksa angka, bukan
niat: untuk celah 001–005 ia menuntut 003 tercatat `from: [1,5]` generasi 1,
sementara 002 dan 004 tercatat generasi 2 dengan satu induk buatan.

---

## [1.25.6] - 2026-08-24

### Poster klip yang bukan foto post, dan satu kolom admin yang berhenti berarti

#### Video memuat frame pertamanya sendiri

Poster sebuah klip selama ini adalah **foto post itu sendiri**, diserahkan oleh
pemanggilnya. Di tampilan artikel hasilnya terlihat jelas: blok foto, lalu tepat
di bawahnya foto yang sama lagi dengan tombol putar merah di atasnya. Dua blok
yang seharusnya berbeda membawa satu gambar yang sama, dan tak satu pun dari
keduanya mengatakan apa pun tentang isi klipnya.

`NewsVideoPlayer` kini membuka klipnya sendiri saat dibangun dan berhenti di
frame pertama. Frame itulah posternya — satu-satunya poster yang memang tentang
videonya. Parameter `poster` dibuang seluruhnya, bukan sekadar tidak diisi:
tidak ada lagi yang boleh menyodorkan gambar lain ke sana.

Di platform native ini murah. `initialize()` membaca header kontainer dan satu
frame — beberapa ratus kilobita, bukan berkasnya. **Web sengaja dikecualikan**:
di sana tidak ada streaming sama sekali, `_downloadForWeb` menarik seluruh klip
ke memori, dan melakukan itu untuk sesuatu yang belum diminta siapa pun adalah
tagihan, bukan poster. Peramban tetap mendapat panel gelap dan tombol putar.

Frame yang diam perlu terlihat bisa ditekan, atau ia tak terbedakan dari sebuah
foto. Tombol putar besar karena itu tetap ada di atasnya sampai pemutaran mulai,
digambar oleh `ValueListenableBuilder` yang mendengarkan controller-nya langsung
— tidak ada hal lain di sana yang membangun ulang saat pemutaran dimulai.

#### "Slide order" hilang dari panel admin

Tidak ada slideshow lagi sejak 1.25.5: halaman depan menampilkan post terbaru
dan mendaftar sisanya. Sebuah angka yang menentukan slide mana lebih dulu
karena itu tidak lagi menentukan apa pun yang bisa dilihat seorang editor.
Urutannya kini tanggal terbit, yang memang arti sebuah kanal berita.

Kolomnya **tetap ada** di basis data dan API masih mengirimkannya, jadi nilai
yang sudah ada terus mengurutkan seperti sebelumnya. Yang berubah: tidak ada
lagi yang menuliskannya. `save()` menghilangkan field itu alih-alih mengirim 0,
karena mengirim 0 berarti menomori ulang sebuah post diam-diam setiap kali ada
yang menyunting judulnya.

#### Terverifikasi

`flutter analyze` bersih; Flutter 197 test. Satu test diperbarui: jaminan
"klipnya tidak diberi foto post" tidak bisa lagi diperiksa lewat properti
`poster` yang sudah tidak ada, jadi ia kini menuntut tidak ada `AuthedImage`
sama sekali di dalam subtree pemutarnya.

---

## [1.25.5] - 2026-08-24

### Bagian news di halaman depan, dirancang ulang

Keluhannya empat, dan yang pertama menjelaskan sisanya.

#### Video dan foto berhenti berebut satu tempat

Seluruh masalahnya ada pada satu baris. Ketika sebuah post punya klip,
`_buildMedia` mengembalikan `NewsVideoPlayer` **sebagai pengganti**
`AuthedImage`, dengan fotonya diserahkan sebagai poster di belakang tombol
putar. Satu slot dipakai berdua, dan yang kalah selalu fotonya: pada post yang
punya keduanya, gambarnya tidak pernah benar-benar terlihat.

`NewsArticleView` tidak pernah punya masalah ini karena ia menyusun keduanya
sebagai blok terpisah, atas-bawah. Itu sebabnya "read more" terasa benar
sementara slide-nya tidak.

`_MediaColumn` kini melakukan hal yang sama di halaman depan: foto dapat
bloknya, klip dapat bloknya, bertumpuk, dipisah garis rambut dua piksel yang
meneruskan warna kartunya. Pemutarnya **tidak lagi diberi poster** —
menyerahkan foto ke sana persis yang membuat klip terlihat seperti menelan
gambarnya.

Dua test mengunci ini, dan keduanya memeriksa geometri alih-alih niat: persegi
panjang foto dan persegi panjang klip tidak boleh beririsan, dan klipnya harus
duduk di bawah foto. Satu lagi memastikan `poster` tetap null.

#### Satu tata letak, bukan dua — dan itu yang membuat penumpukan berhasil

Percobaan pertama menumpuknya di dalam kolom media yang berdampingan dengan
teks, dan itu **gagal karena alasan baru**. Kolom itu hanya 5/11 lebar kartu,
sekitar 250 piksel, lalu tingginya harus dibagi dua lagi. Foto dapat 250×210,
klip dapat 250×210: terlalu kecil untuk membaca diagram, terlalu kecil untuk
memakai scrubber. Tumpang-tindihnya hilang dengan mengorbankan keduanya.

Tata letak kiri-kanan karena itu dibuang seluruhnya. Media kini pita
**selebar kartu**, satu susunan yang sama di setiap lebar layar — persis
sebabnya `NewsArticleView` selalu terbaca benar. Kodenya ikut menyusut:
tidak ada lagi cabang `isNarrow` untuk struktur, tidak ada `LayoutBuilder`
penghitung tinggi, tidak ada pasangan `bounded`/`sizesItself` yang hanya ada
karena `Flexible` menuntut batas pada sumbu utamanya.

Tinggi pitanya 16:9 dengan batas atas: 340 piksel untuk satu pita, 240 ketika
ada dua. Tanpa batas itu, 16:9 selebar kartu 1100 piksel berarti 619 piksel
foto yang mendorong judulnya keluar layar; dan sebuah post dengan foto sekaligus
klip akan jadi 880 piksel kartu sebelum judulnya sendiri. Di ponsel batas itu
tidak pernah mengikat, jadi pitanya memang 16:9.

#### `cover`, bukan `contain`

Teaser-nya sempat `contain` untuk menyelamatkan diagram potret 971×1620 —
tetapi itu **satu berkas uji**, dan harganya dibayar setiap foto lanskap biasa
yang lalu mengambang di antara dua pita hitam tebal. Memotong adalah tugas
sebuah cuplikan; menampilkan utuh adalah tugas artikelnya, dan justru itu yang
dijanjikan tombol READ MORE. `NewsArticleView` tetap `contain`, tidak berubah.

#### Carousel dibuang

Ia menampilkan satu berita pada satu waktu dan membuat pembaca menunggu tujuh
detik untuk berikutnya, di halaman yang muat memuat empat sekaligus. Untuk itu
ia harus memelihara `Timer.periodic`, sebuah `PageView` yang membuang slide di
belakang punggung pembaca, dan penghitung `_holds` supaya tidak berputar dari
bawah dialog yang terbuka — mesin yang persis membuat tombol CLOSE tampak mati
di 1.25.3.

Gantinya bentuk editorial: satu berita unggulan, lalu sisanya sebagai baris
berthumbnail. Semuanya terlihat sekaligus, dan tidak ada yang berputar — jadi
tidak ada lagi yang perlu ditahan. Seluruh kelas bug itu hilang bersama
mesinnya, bukan diperbaiki satu per satu.

Dibatasi enam di halaman depan: ini pintu masuk, bukan arsip.

#### Proporsi

Kartu setinggi 460 piksel mati itu ditala untuk satu ponsel dan keliru di layar
lain. Tingginya kini tidak dipatok sama sekali: pita medianya berukuran seperti
di atas, dan teksnya yang menentukan sisanya.

Thumbnail pada baris tetap `cover` dan tidak pernah dipertimbangkan lain: pada
lebar 96 piksel, potret yang di-*contain* hanya jadi seiris tinta di hamparan
hitam.

#### Karakter

Tetap kotak dan institusional sesuai DESIGN.md — tanpa bayangan, gradien, atau
sudut membulat, karena sistem ini memang tidak punya ketiganya. Yang
ditambahkan: garis merah 4 piksel di tepi kiri kartu unggulan sebagai
satu-satunya penanda, pemisah hairline antar baris, dan chip `▶ VIDEO · 18.2 MB`
yang punya barisnya sendiri di bawah judul — klipnya diumumkan, bukan
ditumpangkan ke thumbnail.

Header sempat membawa penghitung berita, ditaruh di sana untuk mengisi ruang
yang ditinggalkan titik indikator. Itu dibuang lagi: tidak ada yang perlu tahu
ada berapa berita, dan angka yang tidak dibaca siapa pun bukan hiasan.

Baris tidak memuat pemutar. Lima pemutar di halaman depan adalah lima elemen
video yang tidak diminta siapa pun; barisnya menyebut ada klip, artikelnya yang
memutarnya.

#### Berkas

`lib/widgets/news_carousel.dart` dihapus, digantikan
`lib/widgets/news_section.dart`. Nama lamanya jadi kebohongan begitu
carousel-nya tidak ada. Tiga komentar di berkas lain yang menyebut
`NewsCarousel` ikut diperbarui.

#### Terverifikasi

`flutter analyze` bersih; Flutter **197 test** (dari 191). Test rotasi otomatis
dan "CLOSE tetap bekerja setelah 25 detik" dihapus karena perilaku yang
diujinya sudah tidak ada; delapan test baru menggantikannya, termasuk ketiga
test geometri di atas dan satu yang menuntut `BoxFit.cover` di teaser.

Satu catatan tentang harness-nya: `_host` di `news_test.dart` sekarang
membungkus widget-nya dengan `SingleChildScrollView`. Sebelumnya ia menaruhnya
langsung di `Scaffold`, dan begitu kartunya melewati 600 piksel sembilan test
gagal karena overflow — kegagalan yang berasal dari harness, bukan dari widget:
tidak ada apa pun di halaman sungguhan yang diminta muat dalam 800×600.

---

## [1.25.4] - 2026-08-24

### Membuka sebuah berita kini menampilkan beritanya, dan videonya jalan di web

Dua keluhan lanjutan dari bagian news yang sama, dan keduanya soal hal yang
dipotong: satu memotong isi, satu lagi memotong web dari yang didapat mobile.

#### Slide adalah cuplikan; yang terbuka bukan

`READ MORE` dulu membuka dialog berisi **teks body dan tidak ada yang lain** —
tanpa tanggal, tanpa ringkasan, tanpa foto, tanpa klip. Padahal slide-nya
memang memotong dengan sengaja: judul dua baris, ringkasan dua baris di ponsel,
dan foto yang di-`cover` ke dalam kotak 200px.

Untuk foto lanskap pemotongan itu tidak terasa. Untuk diagram potret 971×1620
ia menghapus sekitar tiga perempat tingginya, dan tidak ada satu tempat pun di
produk ini untuk melihat sisanya.

`NewsArticleView` sekarang menampilkan seluruh isi post dalam satu gulungan,
dengan urutan yang disengaja: tanggal dan judul, lalu ringkasan, lalu isi, lalu
gambar, lalu video. Pembaca yang hanya ingin intinya sudah mendapatkannya
sebelum media mulai dimuat. Gambarnya `BoxFit.contain` di atas panel gelap —
utuh, dengan pita hitam bila perlu — dan ringkasannya tidak lagi ber-`maxLines`.

Karena foto yang terpotong kini punya tempat untuk dilihat utuh, tombolnya juga
muncul pada post yang **hanya** berisi foto, dengan label `VIEW POST`; "read
more" akan menjadi bohong pada post tanpa artikel. Post yang isinya cuma video
tetap tanpa tombol: klipnya sudah diputar di slide itu sendiri.

#### Video di web: peramban tidak boleh memasang header, maka Dio yang memasang

Yang tercatat di v1.25.3 masih berlaku — ngrok memutuskan menyajikan
interstitial berdasarkan User-Agent, menjawabnya dengan **HTTP 200 dan
`Content-Type: text/html`**, dan `video_player_web` hanya mengisi atribut `src`
sebuah elemen `<video>`, tempat peramban melarang halaman menempelkan header.
Jadi Android memutar, web tidak.

Jalan memutarnya memanfaatkan satu perbedaan: Dio di web memakai XHR, dan XHR
**boleh** membawa header kustom. Buktinya sudah berjalan sejak lama — `/api/news`
sendiri hanya berhasil di web karena `BaseOptions` mengirim
`ngrok-skip-browser-warning`. Maka di web klipnya kini diambil lewat
`ApiClient.getBytes()`, dibungkus jadi object URL oleh `lib/utils/blob_url.dart`,
dan `blob:` itulah yang diserahkan ke pemutar. Cincin kemajuannya determinate
dengan persentase, karena menatap spinner tak tentu selama 18 MB tidak bisa
dibedakan dari menatap sesuatu yang menggantung.

Biayanya harus dikatakan terang-terangan: **tidak ada streaming di web**. Tidak
ada yang diputar sampai bita terakhir tiba, dan berkasnya menetap di memori
sampai widget-nya dibuang. Itu tawar-menawar yang wajar untuk klip berita
pendek dan keliru untuk apa pun yang besar — karenanya ada
`NewsVideoPlayer.webDownloadLimitBytes`, 30 MB, dan di atasnya web jatuh ke
tombol `OPEN VIDEO` yang sudah ada (pengunjung bertemu interstitial ngrok di
sana, lalu menekan "Visit Site"). Jangan jadikan ini pola untuk media besar
lain di aplikasi ini.

Ini juga sementara. Perbaikan sebenarnya adalah menyajikan media dari alamat
tanpa interstitial — paket ngrok berbayar, atau `api.brin.fajrianhost.my.id`
begitu DNS-nya ada. Hari itu tiba, seluruh cabang blob ini boleh dibuang dan
`<video src>` biasa akan streaming dengan range request yang benar, yang justru
lebih baik daripada blob.

`dart:js_interop` dan `package:web` dipakai lewat conditional export, jebakan
yang sama dengan `dart:html`: mengimpornya tanpa syarat merusak build Android
di tahap kernel compilation walaupun jalurnya tidak pernah dieksekusi.

#### Yang tidak dikerjakan

Slide di halaman depan tidak berubah — ia memang cuplikan. Gambar di tampilan
terbuka tidak bisa di-zoom; `InteractiveViewer` akan berebut gestur dengan
gulungan dialognya. Dan sebuah post yang klipnya sedang diputar di slide akan
punya dua pemutar begitu artikelnya dibuka; pemutar kedua diam sampai ditekan,
tapi yang pertama tidak ikut berhenti sendiri.

Diverifikasi: `flutter analyze` bersih, `flutter test` 191 lolos (enam di
antaranya baru — untuk isi yang muncul, foto yang tidak terpotong, ringkasan
yang tidak dipendekkan, dan ukuran klip yang dibutuhkan web sebelum mengunduh),
`flutter build web --release` dan `flutter build apk --release` keduanya jadi.
`AuthedImageCache.seed()` ditambahkan khusus untuk pengujian: tanpa itu setiap
tes yang memuat foto membuka permintaan HTTP sungguhan yang timer-nya masih
menggantung saat tes berakhir.

---

## [1.25.3] - 2026-08-24

### Bagian news: klip yang tidak bisa diputar, tombol tutup yang tidak menutup

Tiga keluhan dari satu bagian halaman, dan dua di antaranya punya penyebab yang
sama sekali tidak terlihat dari gejalanya.

#### "This video could not be played here."

Pemutar video adalah **satu-satunya** hal di aplikasi ini yang mengambil data
dari API tanpa melewati `ApiClient`: pengurainya berjalan di kode native, dari
sebuah URL. Karena itu ia tidak pernah membawa `ngrok-skip-browser-warning`
yang dipasang `BaseOptions` untuk semua permintaan lain.

Diuji langsung ke terowongan: ngrok menjawab interstitial HTML-nya dengan
**HTTP 200 dan `Content-Type: text/html`** — bahkan untuk permintaan yang
membawa `Accept: video/*` dan `Sec-Fetch-Dest: video`, persis seperti yang
dikirim sebuah elemen `<video>`. Jadi pemutarnya menerima HTML di tempat ia
menunggu MP4, gagal inisialisasi, dan satu-satunya yang bisa ia laporkan adalah
bahwa videonya tidak dapat diputar. Berkasnya tidak pernah bermasalah.

`newsVideoHeaders()` sekarang mengirim header itu, berikut bearer token bila
ada — sehingga pratinjau draf oleh administrator ikut jalan, tawar-menawar yang
sama seperti `AuthedImage` untuk foto. **Ini tidak menjangkau build web**:
`video_player_web` mengisi `src` sebuah elemen `<video>`, dan peramban tidak
mengizinkan halaman menempelkan header di sana.

#### Tombol CLOSE yang tidak menutup apa pun

`onPressed` dialognya memanggil `Navigator.pop(context)` dengan context milik
**slide**, bukan milik dialog. Sementara itu carousel terus berputar setiap 7
detik di balik dialog yang terbuka, dan `PageView` membuang slide yang sudah
digeser menjauh. Begitu elemen itu mati, `Navigator.of` di atasnya melempar
alih-alih menutup — dan dari luar terlihat seperti tombol yang tidak berfungsi.
Semakin lama artikelnya dibaca, semakin pasti rusaknya.

Dua perbaikan, keduanya perlu. Tombolnya kini mengambil context dari sebuah
`Builder` **di dalam** dialog, jadi ia tidak lagi bergantung pada umur slide.
Dan carousel menahan diri selama ada yang menuntut perhatian — artikel terbuka,
atau klip sedang diputar — dihitung, bukan sekadar bendera, karena dialog yang
dibuka di atas video menahan dua kali dan harus dilepas dua kali.

#### Video sekarang ada di halamannya

Klip dulu duduk di balik tombol `READ MORE & WATCH` yang membuka dialog. Kini
ia menempati sisi media slide itu sendiri: poster foto dengan tombol putar,
lalu pemutar dengan scrubber, jam, dan tombol bisu di tempat yang sama.

Tidak ada yang diunduh sampai tombol putar ditekan — halaman depan tetap
berbiaya satu foto kecil untuk dilihat, bukan puluhan megabita klip yang belum
tentu ditonton. Karena itu pula post yang hanya berisi video tidak lagi
memerlukan tombol apa pun.

#### Tampilan

Panah navigasi pindah dari atas foto ke baris judul, bersama penghitung slide —
dua target 40px yang melintang di sebuah gambar adalah tempat yang keliru
ketika masih ada ruang kosong di sebelah judul. Judul bagian memakai garis
merah 40×3 yang sama dengan heading lain di landing page. Kartunya kini putih
berbingkai `borderDark` alih-alih nyaris menyatu dengan latar seksinya; panel
medianya gelap, sehingga foto, video berpita hitam, dan bingkai kosong sama-sama
terbaca sebagai bagian dari kartu yang sama. Titik indikator menjadi bilah
tipis, dan tinggi kartu dinaikkan karena bagian teks yang tetap sempat tinggal
dua piksel dari batasnya di 360×640.

#### Tombol CANCEL sheet dukungan, penyakit yang sama

Ditangkap dari perangkat sungguhan, lengkap dengan stack trace-nya:

```
Null check operator used on a null value
#1  Element.findAncestorStateOfType
#2  Navigator.of
#3  Navigator.pop
#4  _PublicMessageSheetState._buildForm.<anonymous closure>
    (package:fe/screens/messages/public_message_sheet.dart:190)
```

Persis penyakit tombol CLOSE di atas, di berkas yang berbeda:
`Navigator.pop(context)` mencari ancestor-nya **pada saat tombol ditekan**, dan
sheet yang sudah dalam perjalanan menutup punya elemen yang sudah mati saat itu.
Kedua tombolnya kini mengambil `NavigatorState` sewaktu build, ketika elemennya
pasti masih hidup. Menyimpan state itu aman: Navigator hidup lebih lama daripada
sheet mana pun yang ia tampilkan.

#### Gambar berita: apa yang sebenarnya ditemukan

Dilaporkan bahwa slide hanya menampilkan bingkai kosong. Seluruh rantainya
ditelusuri, dan **tidak ada satu pun lapisan yang cacat**:

- keempat berkas ada di disk, dan `is_published = 1` untuk keempat post, jadi
  cabang admin di `NewsController::image` tidak pernah dijalani;
- `/api/news/{1,2,3,4}/image` menjawab **200 `image/png`** dengan byte PNG yang
  sah — lokal maupun lewat terowongan, dengan dan tanpa header ngrok;
- sebuah probe Dart yang menirukan `ApiClient` persis, di atas `dart:io` yang
  sama dengan Android, mengambil keempatnya tanpa kesalahan;
- video 19 MB terunduh penuh dalam 11,8 detik tanpa mengganggu Octane —
  dugaan bahwa unduhan besar menjatuhkan worker terbantah.

Akhirnya dijalankan di **perangkat sungguhan** dengan instrumentasi sementara.
Hasilnya: `PROBE ok /news/4/image bytes=10010`, `/news/3/image bytes=877522`,
`/news/1/image bytes=594` — terambil **dan** terdekode, tanpa satu pun kegagalan.

Jadi gejalanya **tidak dapat direproduksi** pada kode ini. Yang berubah sejak
APK yang diuji: perbaikan `SecureStore` di 1.25.2 dan penulisan ulang carousel
di atas. Mana dari keduanya yang menyelesaikannya tidak dibuktikan, dan tidak
diklaim di sini.

Satu pelajaran yang tetap berlaku: probe pertama tidak menghasilkan apa-apa
karena aplikasinya berada di latar belakang, dan Flutter berhenti membangun
frame di sana — `AuthedImage` tidak pernah dibangun, sehingga permintaannya
tidak pernah terjadi. Diam bukan bukti kegagalan.

#### Terverifikasi

`flutter analyze` bersih; Flutter 185 test (dari 181). Empat test baru menutup
klip yang tampil di slide, tidak adanya unduhan sebelum tombol putar ditekan,
dan CLOSE yang tetap bekerja 25 detik setelah dialog dibuka — tiga kali masa
tayang slide, dengan empat post, karena `PageView` menahan satu halaman
bersebelahan dan dua post tidak cukup untuk membuang yang pertama.

Pengambilan gambar diverifikasi di perangkat sungguhan (Galaxy A32, Android),
bukan lewat test.

---

## [1.25.2] - 2026-08-24

### Satu penyimpanan token yang rusak, dua gejala yang tampak seperti backend mati

Aplikasi di ponsel tetap menjawab **"An unexpected error occurred"** saat masuk,
dan carousel berita di halaman depan tetap kosong — sesudah perbaikan 1.25.1.
Karena dua bagian yang tidak berhubungan gagal bersamaan, dugaannya adalah
backend belum tersambung ke frontend.

Rantai backend diperiksa lapis demi lapis dan **seluruhnya sehat**: MySQL
menyala dengan empat berita berstatus terbit, Octane menyala di port 8000,
ngrok menembus ke Octane, `GET /api/news` menjawab 200 `application/json`
berisi keempat berita itu, dan `GET /api/user` dengan bearer token menjawab 200
dengan payload yang **persis** cocok dengan `UserModel.fromJson` — tidak ada
lagi `username` di sana, jadi bukan pula kasus 1.25.1 yang berulang.

Penyebabnya satu, dan letaknya di klien.

#### Interceptor yang menjatuhkan permintaan yang tidak butuh token

Setiap permintaan di aplikasi ini melewati interceptor `onRequest` Dio yang
membaca bearer token dari `flutter_secure_storage`. Di Android pembacaan itu
bukan pencarian di map: plugin-nya mendekripsi nilai dengan kunci yang tinggal
di Android Keystore, dan kunci itu tidak selalu selamat. Memasang APK yang
dibangun berbeda di atas yang lama, atau membiarkan Android Auto Backup
memulihkan preferensi terenkripsinya ke perangkat yang keystore-nya tidak
pernah memegang kunci tersebut, meninggalkan byte yang tidak akan pernah bisa
didekripsi. Pembacaannya melempar, dan melempar setiap kali.

Lemparan di dalam interceptor menggagalkan **seluruh permintaan**, jadi
gejalanya tidak pernah berupa "Anda keluar dari sesi":

- `GET /api/news` bersifat publik dan tidak meminta token sama sekali, tetapi
  interceptor berjalan lebih dulu dan tidak pernah sampai ke sana.
  `NewsCarousel` sengaja diam ketika permintaannya gagal, jadi halaman depan
  terbaca seperti sebelum ada berita apa pun.
- `POST /api/login` gagal dengan `DioException` yang membungkus
  `PlatformException`. Exception seperti itu tidak membawa response, sehingga
  jatuh ke cabang terakhir `_handleError` — yang berbunyi persis
  "An unexpected error occurred".

Web tidak terpengaruh karena di sana plugin yang sama memakai penyimpanan
peramban, bukan Android Keystore. Itulah sebabnya web normal sementara ponsel
tidak, dan itu pula yang membuat backend terlihat sebagai tersangka.

#### Yang berubah

`lib/services/secure_store.dart` kini berdiri di depan plugin tersebut, dengan
tawar-menawar yang sengaja dibuat tidak simetris:

- **Baca** yang gagal menjawab `null` dan membuang data yang tak terbaca itu.
  Ongkosnya satu kali masuk ulang, dan perangkatnya pulih permanen —
  menyimpannya berarti setiap pembacaan berikutnya gagal selamanya.
- **Tulis** atau **hapus** yang gagal hanya merugikan token yang di-cache sesi
  ini. Tokennya sudah terbit; kehilangan cache tidak sebanding dengan
  menggagalkan login yang baru saja berhasil.

`ApiClient`, `AuthService` dan `UploadResumeStore` semuanya lewat sana sekarang;
tidak ada lagi yang menyentuh `FlutterSecureStorage` langsung.

`android:allowBackup="false"` mencegah kerusakan itu terjadi sejak awal —
`SecureStore` menahan lemparannya, manifest menghentikan sumbernya.

Dan pesan-pesan terakhir `_handleError` berhenti menyesatkan: sebuah kegagalan
tanpa response kini menyebut alamat yang dituju berikut error aslinya, dan body
non-JSON dari ngrok dikenali sebagai interstitial terowongan alih-alih dilaporkan
sebagai "An error occurred".

#### Terverifikasi

`flutter analyze` bersih; Flutter 181 test (dari 176), termasuk lima test
`SecureStore` yang ditulis lebih dulu dan gagal sampai implementasinya ada.
Rantai backend diverifikasi lewat terowongan sungguhan, bukan lewat test.

---

## [1.25.1] - 2026-08-23

### Dua bug yang ditemukan saat menguji di perangkat

Keduanya lahir dari pekerjaan sebelumnya di hari yang sama, dan keduanya
ditemukan dengan menelusuri rantainya lapis demi lapis alih-alih menebak.

#### "An unexpected error occurred" yang bukan tentang login sama sekali

Aplikasi di ponsel tidak bisa masuk sementara web normal. Seluruh rantai
backend diperiksa dan sehat: MySQL menyala, Octane menyala, ngrok menembus ke
Octane, dan `curl` memperoleh token dengan kredensial yang benar.

Login-nya memang **tidak pernah gagal**. Bagian B1 membuang `username` dari
payload user; APK yang terpasang dibangun sebelum itu, dan versi tersebut
membaca `json['username']` ke sebuah `String` yang tidak nullable. Server
menjawab 200 beserta token, penguraiannya yang melempar, dan
`auth_provider` melaporkannya sebagai "An unexpected error occurred".

Kalimat itu yang mengirim orang menyusuri backend, terowongan dan basis data
mencari kerusakan yang tidak ada. Sebuah `TypeError` kini berbunyi
**"This version of the app cannot read what the server sent. Please install
the latest build."**

Ini juga catatan untuk deploy berikutnya: membuang sebuah field dari payload
memutuskan setiap klien lama yang membacanya sebagai tipe non-nullable.

#### Video yang ada, tersaji, dan tak terjangkau

`GET /api/news/4/video` menjawab 200 dengan 19 MB `video/mp4` dan
`Accept-Ranges`. Videonya tidak hilang — ia tidak bisa dicapai.

Di bagian B2, label `WATCH VIDEO` hanya muncul ketika body post kosong. Sebuah
klip yang dilampirkan pada artikel yang **juga** punya tulisan karenanya duduk
di balik tombol berbunyi `READ MORE`, tanpa satu pun tanda di slide bahwa ada
video di sana.

Sekarang slide membawa badge dengan ikon putar dan ukuran videonya, dan
tombolnya berbunyi `READ MORE & WATCH` ketika post punya keduanya.

#### Terverifikasi

Flutter 176 test (dari 174), `flutter analyze` bersih. Kedua akun uji
diverifikasi masuk lewat terowongan sungguhan, bukan lewat test.

## [1.25.0] - 2026-08-23

### Bagian E dan F: preview yang terlewat, dan gestur yang tidak ada penanganannya

#### E menutup separuh poin 10

Audit terhadap sepuluh permintaan asli, dijalankan terhadap kode dan bukan
terhadap ingatan, menemukan sembilan selesai dan satu setengah. Poin 10 meminta
**dua** preview di tab training — satu untuk frame yang masuk, satu untuk hasil
yang keluar. Bagian D membangun yang kedua; yang pertama terlewat saat D
dirancang.

E jauh lebih kecil daripada bagian C. C harus memecah unggah dari analisis
karena `PredictionIntake` mengantrikan pekerjaan pada detik berkasnya selesai
naik. Training tidak begitu: job duduk sebagai `queued` sampai ada worker yang
mengklaimnya, jadi jendela untuk melihatnya sudah ada. **Tidak ada status baru
dan tidak ada alur yang dipecah.**

Arsipnya tidak pernah diekstrak. `ZipArchive` membaca satu entri dan
`TiffPreview` sudah menerima byte mentah, jadi sebuah dataset 2 GB tidak
digandakan hanya untuk dilihat.

Satu hal yang ditemukan saat mengerjakannya: `ownedJob()` memuat relasi dataset
dengan kolom terbatas — `id,name,size_bytes` — dan `archive_path` tidak
termasuk. Memperlebarnya akan membuat jalur penyimpanan ikut terbawa ke setiap
payload job, jadi path-nya diambil eksplisit di satu metode yang memang
membutuhkannya.

#### F, dan separuhnya adalah bug

Menggeser jari tidak melakukan apa pun sebelum ini. Sekarang ia berpindah tab,
berhenti di ujung alih-alih melingkar — melingkar berarti satu geseran dari
entri terakhir mendarat di Dashboard, yang terasa seperti kehilangan tempat.

Yang lebih penting: **tidak ada `PopScope`, `WillPopScope`, maupun penangan
gestur sama sekali di kedua shell.** Gestur kembali Android tidak dicegat oleh
apa pun, sehingga satu geseran yang meleset di Dashboard melempar orang ke
landing page tanpa peringatan. Sekarang gestur kembali pulang ke Dashboard dari
tab mana pun, dan dari Dashboard ia membuka dialog yang **sama persis** dengan
yang dibuka tombol Sign out — bukan dialog kedua yang bisa menyimpang.

`GestureDetector`, bukan `PageView`, dan itu keputusan yang menentukan. Tabel
metrik training dan beberapa tabel admin menggulung horizontal juga; `PageView`
akan merebut gestur sebelum anaknya sempat memintanya. Scrollable di dalam
menang melawan `GestureDetector` di arena gestur Flutter, sehingga geseran di
atas tabel menggulung tabelnya dan geseran di tempat lain sampai ke shell.

#### Terverifikasi, dan yang tidak

Backend **279 test** (dari 272), Flutter **174 test** (dari 168),
`flutter analyze` bersih.

**Yang tidak bisa diuji di sini:** gestur tepi layar Android sungguhan, dan
apakah `SelectionArea` dari bagian A masih bisa menyeleksi teks di sebelah
`GestureDetector` yang baru. Keduanya bekerja pada pohon widget yang sama dan
hanya terlihat di perangkat.

Test yang ada mengunci hal yang membuat gesturnya mendarat benar ketika ia
memang sampai: daftar seksinya berurutan dengan Dashboard di depan, melangkah
berhenti di ujung, dan tab Training admin yang dihapus di bagian D tetap
hilang — sehingga sebuah geseran tidak bisa berjalan kembali ke sana.

## [1.24.0] - 2026-08-23

### Bagian D: training jadi milik periset

Bagian terakhir dari sepuluh permintaan perubahan. Rancangan dan rencananya ada
di `docs/superpowers/specs/2026-08-23-d-researcher-training-design.md` dan
`docs/superpowers/plans/2026-08-23-d-researcher-training.md`.

#### Tab admin dihapus, kemampuannya tidak

Poin 6 benar bahwa layar itu mengulang apa yang ada di tempat lain — daftar job
dan daftar dataset. Tapi ia juga memegang `_registerModel()`, satu-satunya cara
bobot hasil training berubah jadi model yang bisa dipakai siapa pun, dan
satu-satunya penghapusan dataset dan job yang ada — yang menurut ROADMAP §11
juga satu-satunya rem terhadap disk yang terisi.

Menghapus layarnya tanpa memindahkan ketiganya akan membuat training jadi jalan
buntu: bobot ada di disk dan tidak ada yang bisa memakainya.

Ketiganya pindah ke Model Management, karena mendaftarkan bobot **adalah**
membuat versi model, dan model memang hidup di sana. Formulirnya dibawa utuh
alih-alih ditulis ulang — ia sudah bekerja, dan menulis ulang satu-satunya
jalan keluar dari pipeline training hanya menambah risiko.

Yang benar-benar dicabut cuma `dispatch`, beserta sembilan test-nya. Ia lahir
ketika admin yang memulai run; sekarang periset yang memulai, dan job antre
diklaim worker sendiri. Test-nya dihapus alih-alih ditulis ulang jadi tentang
`claim`: itu perilaku berbeda yang sudah punya testnya sendiri, dan memindahkan
asersi ke tempat yang salah menyembunyikan cakupan yang hilang.

#### MAE ternyata sudah ada sejak awal

Tiga dari empat metrik yang diminta tidak punya sumber — trainer hanya
mengirim `loss` dan `psnr`.

Tetapi `loss` di trainer adalah `tf.reduce_mean(tf.abs(prediction - target))`,
yang **adalah** mean absolute error menurut definisi. Ia sekarang dikirim
dengan dua nama, dan `loss` tetap ada supaya run yang sudah tercatat tidak
kehilangan grafiknya. SSIM dan MSE masing-masing satu baris, berdampingan
dengan PSNR yang sudah dihitung.

#### Tabel metrik butuh lebih sedikit daripada dugaan, dan hal yang berbeda

Tabelnya sudah membangun kolom dari gabungan setiap kunci yang pernah
dilaporkan — sehingga notebook yang mulai mengukur sesuatu yang baru tidak
menuntut perubahan kode — dan sudah merender `—` untuk nilai yang tidak ada.
Empat kolom tetap yang direncanakan justru akan jadi kemunduran.

Yang benar-benar kurang adalah urutan. Dengan trainer mengirim empat metrik, ia
juga akan menumbuhkan kolom `BATCHES` dan `SAMPLES` — yang mengatakan berapa
banyak kerja, bukan seberapa baik — dan `MAE` berdampingan dengan `LOSS`
membawa satu angka dua kali.

#### Satu frame per epoch

Generator dijalankan pada **satu triplet uji tetap** di akhir tiap epoch. Tetap,
bukan acak: membandingkan epoch 3 dengan epoch 9 pada triplet berbeda tidak
mengatakan apa pun tentang modelnya, hanya tentang tripletnya.

`FrameStackViewer` dari bagian C dipakai apa adanya, dengan epoch sebagai
sumbunya. Ia dibuka pada epoch terakhir: yang ingin dilihat orang adalah di mana
modelnya sekarang, bukan di mana ia bermula.

Satu jebakan yang layak dicatat: foreign key `cascadeOnDelete` menghapus baris
sampel dengan sempurna dan **tidak memicu event Eloquent sama sekali**,
sehingga setiap PNG akan tertinggal di disk tanpa ada yang menunjuknya.
`TrainingJob` menghapusnya lewat Eloquent lebih dulu, dan ada test yang
menegaskan berkasnya benar-benar hilang.

#### Terverifikasi, dan yang tidak

Backend **272 test**, Flutter **168 test** (dari 162), `flutter analyze` bersih.

Jumlah backend turun dari 281 ke 272 karena sembilan test dispatch dihapus
bersama rutenya, bukan karena ada yang rusak.

**Tidak satu pun dari bagian D pernah bertemu GPU.** Jalur training belum pernah
dijalankan sekali pun terhadap perangkat keras sungguhan — ROADMAP §10
mencatatnya sejak 18 Agustus — dan D menambahkan tiga hal baru di atasnya.
Perubahan pada `script-api-train-deepct.py` hanya lolos `python -m py_compile`,
yang membuktikan berkasnya terurai dan bukan bahwa `tf.image.ssim` dipanggil
dengan benar.

## [1.23.0] - 2026-08-23

### Bagian C: unggah, lihat, lalu analisis

Bagian keempat dari sepuluh permintaan perubahan. Rancangan dan rencananya ada
di `docs/superpowers/specs/2026-08-23-c-frame-viewer-design.md` dan
`docs/superpowers/plans/2026-08-23-c-frame-viewer.md`.

#### Tiga hal yang ternyata sudah ada

C jauh lebih kecil daripada bunyi permintaannya, dan itu baru terlihat setelah
kodenya dibaca.

`GET /predictions/{id}/frames` **sudah** menggabungkan folder input dan output.
Galeri **sudah** menampilkan gabungan itu — `_generatedOnly` default `false`,
jadi filternya ada tapi mati. Dan `_FrameViewer` **sudah** punya `PageView`,
`InteractiveViewer` untuk pan/zoom, pemuat per-frame, dan latar hitam.

Pernyataan sebelumnya dalam sesi ini bahwa galeri "sengaja memfilter hanya
frame hasil" salah.

Yang benar-benar baru: slider, tick penanda, badge, dan pengangkatan widget-nya
supaya bagian D bisa memakainya.

#### Yang tidak kecil: pipeline dipecah dua

Preview yang diminta harus muncul setelah berkas naik dan **sebelum** analisis
dimulai. Keduanya dulu satu tombol — `PredictionIntake` membuat record
berstatus `pending` dan memanggil `dispatch()` dalam napas yang sama.

Sekarang ada `uploaded` di depan `pending`, dan
`POST /predictions/{id}/start` yang mengantrikan. Ia menjawab 409 pada tekanan
kedua, karena ketukan ganda di ponsel akan menempatkan dua worker pada satu job
yang saling menimpa folder output yang sama; 404 untuk milik orang lain,
bentuk yang sama dengan seluruh rute prediksi; dan 410 untuk berkas
kedaluwarsa.

Alternatifnya — merender TIFF di klien sebelum berkas naik — ditolak dengan
sadar. Ia menuntut `TiffPreview.php` diporting ke Dart: 302 baris parsing IFD,
penurunan 16-bit, dan encoder PNG tulis tangan, menghasilkan dua dekoder yang
bisa saling berbeda tanpa ada yang tahu.

Lima belas test memerah karenanya, persis seperti yang diperkirakan.
Perbaikannya menambahkan panggilan `start`, bukan melemahkan asersinya. Satu
test berganti nama dari `..._queues_a_job` jadi `..._waits_to_be_started` dan
kini menguji **dua** fakta: `finalize` meninggalkan record menunggu, dan
`start` menghasilkan pekerjaan selesai yang dulu ia hasilkan sendiri.

Baris log aktivitas ikut berubah. *"Started prediction with N frames"* tidak
lagi benar saat unggah, dan log yang mengaku sebaliknya menyesatkan siapa pun
yang membacanya nanti.

#### Slider, dan tick yang membuatnya berguna

Slider tersambung **dua arah** dengan `PageController`: menggeser slider
memindah halaman, menggeser halaman memindah slider. Satu arah akan
meninggalkan slider yang berbohong begitu seseorang menyapu gambarnya.
`jumpToPage`, bukan `animateToPage` — menggeser adalah pencarian, dan animasi
300 ms di tiap langkah membuatnya lengket.

Tick di jalur slider itulah alasan ia mengalahkan tombol panah: sebaran
sisipan model terlihat sekaligus. Ia ditaruh sebagai `Row` berisi `Expanded`
di atas slider, bukan dilukis ke dalam track — perataan yang sama, tanpa
painter.

Badge pindah ke atas gambar. Mata sedang di gambar; keterangan yang jauh dari
sana tidak terbaca.

#### Beberapa `.tif` tanpa membungkusnya sendiri

Memilih enam frame dari sebuah folder tidak lagi menuntut periset membungkusnya
lebih dulu. Arsipnya dibuat di klien dan menempuh jalur yang sudah ada, jadi
backend tetap punya satu bentuk masukan.

Namanya dipertahankan persis. Penomoran di dalamnya itulah yang memberi tahu
backend di mana celahnya; menormalkannya akan menghancurkan satu-satunya
informasi yang dibutuhkan interpolasi.

#### Terverifikasi, dan yang belum

Backend **274 test** (dari 270), Flutter **162 test** (dari 153),
`flutter analyze` bersih.

**Belum terverifikasi, dan ini yang paling penting:** belum ada satu prediksi
pun yang dijalankan terhadap GPU sungguhan sejak pipeline-nya dipecah. Itu
satu-satunya jalur di proyek ini yang pernah dibuktikan ujung-ke-ujung
(18 Agustus), dan bagian C menyentuh `PredictionIntake` beserta enum
statusnya. Suite yang hijau tidak membuktikan jalurnya masih utuh.

Begitu juga seluruh pemeriksaan mata di perangkat. Aplikasi bisa dipasang ke
`SM A325F` yang tersambung, tetapi menelusuri alurnya menuntut mata dan jari.

## [1.22.0] - 2026-08-22

### Bagian B2: video di berita riset, emoji, dan pesan yang terlihat sedang dikirim

Bagian ketiga dari sepuluh permintaan perubahan. Rancangan dan rencananya ada di
`docs/superpowers/specs/2026-08-22-b2-video-and-messages-design.md` dan
`docs/superpowers/plans/2026-08-22-b2-video-and-messages.md`.

#### Video tidak bisa tiba dalam satu permintaan, dan itu diukur

`post_max_size` PHP adalah **8M**. Satu POST multipart 25 MB ditolak
**HTTP 413** oleh `ValidatePostSize` Laravel — bukan oleh RoadRunner, dan bukan
oleh `upload_max_filesize` yang catatan CLAUDE.md sebut tidak berlaku di bawah
Octane. Diuji langsung terhadap server yang berjalan sebelum satu baris kode
ditulis.

Jadi video 50 MB menempuh mesin unggah berpotongan yang sudah ada, sebagai
tujuan ketiga di samping `prediction` dan `training`. Komentar controller itu
sendiri yang memutuskan bentuknya: *"a second copy of it for training datasets
would drift from this one the first time either was touched"* — dan itu berlaku
sama untuk salinan ketiga.

Pemeriksaan peran ada di dalam cabangnya, bukan di rutenya. Mengunggah prediksi
memang pekerjaan periset dan rutenya terbuka untuk mereka; melampirkan video ke
berita bukan. Diperiksa saat `start` dan lagi saat `finalize`, karena keduanya
permintaan terpisah dan peran bisa berubah di antaranya.

#### Satu klaim yang salah, dan koreksinya

Dalam sesi ini sempat dinyatakan bahwa video tidak akan bisa digeser karena
`response()->file()` tidak mengirim `Accept-Ranges`. Itu keliru. Ia
mengembalikan `BinaryFileResponse` Symfony, yang menangani Range sendiri —
dibuktikan terhadap endpoint gambar: `Range: bytes=0-99` dijawab `206` dengan
`Content-Range: bytes 0-99/594`. Proyek ini bahkan sudah mengandalkannya untuk
unduhan ZIP yang bisa dilanjutkan. **Tidak ada satu baris pun kode Range yang
ditulis**; menggeser video bekerja karena kode yang sudah ada di sini.

#### Pemutar, dan tempat yang tidak bisa memutarnya

`video_player` tidak punya implementasi Windows maupun Linux. Di sana
pemutarnya diganti tautan yang menyerahkan URL ke sistem lewat `url_launcher`,
dideteksi dengan `defaultTargetPlatform` di awal alih-alih ditangkap sebagai
pengecualian — sebuah pengecualian yang tertangkap setelah layar dibangun sudah
terlambat untuk mengubah apa yang digambar.

Pemutarnya ada di dialog detail, bukan di dalam slide: slide punya tinggi tetap
dan ringkasan ber-`maxLines`, dan pemutar di sana akan bertengkar dengan
keduanya. Tombolnya kini juga muncul untuk post bervideo tanpa body — jika
tidak, klip pada berita satu baris tidak akan bisa dijangkau sama sekali.

#### Emoji, dan sebuah test yang lulus sejak awal

Tombol pemilih emoji di `MessageComposer`, yang sudah dipakai bersama oleh layar
periset dan kotak masuk admin. Emoji disisipkan di posisi kursor, bukan
ditempel di akhir.

Test round-trip emoji ditulis lebih dulu dan **lulus tanpa perbaikan apa pun**:
koleksi `utf8mb4` memang sudah benar. Ia tetap tinggal sebagai penjaga —
koleksi tabel bisa menyimpang dari koleksi koneksi, dan emoji yang diam-diam
jadi `?` adalah hal yang tidak ada yang menyadarinya sampai seorang periset
mengirimkannya.

#### Status pending, tanpa menyentuh basis data

Gelembung muncul seketika dengan ikon jam, diganti salinan server saat berhasil,
dan jadi merah saat gagal. "Terkirim" dan "terbaca" sudah bekerja sejak dulu
lewat `messages.read_at`. Tidak ada kolom baru.

Pesan optimistik dicocokkan dengan `identical`, bukan lewat `id`: ia ber-`id` 0,
dan dua bisa terbang bersamaan bila seseorang mengetik cepat.

#### Tiga hal yang rencana salah dan test menangkapnya

Potongan dikirim sebagai multipart POST dengan `_method: PATCH` dan byte sebagai
berkas, bukan PATCH dengan body mentah. Memberi array server eksplisit ke
`call()` menimpa header `Authorization` yang dipasang `apiAs()`, sehingga
permintaan tiba tanpa autentikasi. Dan `model_id` beraturan
`required_unless:purpose,training`, sehingga `news_video` — yang bukan
`training` — tetap dimintai model.

Satu lagi yang ditemukan dan bukan salah rencana: **rute baru tidak muncul sama
sekali** di `route:list` maupun di test sampai `php artisan route:clear`
dijalankan. `bootstrap/cache/routes-v7.php` basi, dan tabel rute yang di-cache
menyembunyikan rute baru sepenuhnya. Bentuknya sama dengan jebakan Octane yang
sudah dicatat CLAUDE.md.

#### Terverifikasi

Backend **270 test** (dari 256 sebelum B2), Flutter **153 test** (dari 147),
`flutter analyze` bersih, `flutter build apk --release` berhasil pada 60,5 MB —
naik dari 54,1 MB karena `video_player` dan `emoji_picker_flutter`, dan
keduanya lolos kompilasi Java yang CLAUDE.md catat sebagai tempat paket salah
versi biasanya patah.

**Belum terverifikasi:** memutar video sungguhan di aplikasi berjalan dan
menggesernya ke tengah. `curl` sudah membuktikan server menjawab `206`; itu
tidak membuktikan pemutarnya memintanya. Begitu juga panel emoji dan gelembung
pending di perangkat sentuh, dan migrasi belum dijalankan di VPS.

#### Dua hutang yang diambil dengan sadar

Loop unggah berpotongan kini ada di **tiga** layanan Flutter. ROADMAP §10 sudah
mencatat dua yang pertama layak disatukan; menyatukannya sambil menambah
pemakai ketiga akan mencampur dua perubahan dalam satu rangkaian commit, jadi
hutangnya dicatat alih-alih dibayar.

Dan unggah video mewarisi keterbatasan yang sama dengan dataset training:
sesi yang terputus harus diulang dari nol, dan seluruh berkas dimuat ke RAM
sebelum sepotong pun dikirim (ROADMAP §11). 50 MB jauh lebih kecil daripada
2 GB yang jadi kekhawatiran di sana, jadi B2 tidak memperbaikinya — tapi juga
tidak berpura-pura masalahnya tidak ada.

## [1.21.0] - 2026-08-22

### Bagian B1: `username` diganti nomor telepon, dan satu kolom yang tidak melakukan apa pun dihapus

Bagian kedua dari sepuluh permintaan perubahan. Rancangan dan rencananya ada di
`docs/superpowers/specs/2026-08-22-b1-schema-cleanup-design.md` dan
`docs/superpowers/plans/2026-08-22-b1-schema-cleanup.md`.

#### Kenapa `username` pergi

Login memakai email, dan setiap akun sudah punya `name`. `username` adalah
kolom ketiga yang tidak mengidentifikasi apa pun yang belum teridentifikasi —
tetapi ia `NOT NULL` dan `unique`, jadi setiap pembuatan akun harus mengarang
satu. `AccessRequestController` bahkan punya dua metode yang tugasnya cuma itu:
`suggestedUsername()` memotong bagian depan email, `uniqueUsername()` menempel
angka sampai bebas bentrok. Keduanya sekarang tidak ada.

Penggantinya, `phone`, **opsional dan tidak unik**. Dua periset yang berbagi
satu nomor kantor adalah kasus yang dulu ditolak mentah-mentah oleh batasan
`unique`. Tidak ada validasi format: nomor Indonesia ditulis dengan `+62`, `62`
dan `0` bergantian, dan menolak salah satunya hanya membuat admin bertengkar
dengan formulir.

#### Empat "fallback" yang ternyata tidak pernah berjalan

Empat tempat menulis `$user->name ?? $user->username`. Karena `users.name`
**tidak nullable**, cabang keduanya tidak pernah dieksekusi sekali pun.
Keempatnya dihapus, bukan diarahkan ke `phone` — mengganti fallback mati dengan
fallback mati yang lain hanya memindahkan kesalahpahamannya.
`Conversation.php` adalah pengecualian dan tetap punya fallback, karena di sana
akun-nya sendiri bisa null: percakapan tamu tidak punya akun.

#### Dikerjakan bertahap, bukan sekali tebas

Tiga migrasi, bukan satu. Menjatuhkan `username` di langkah pertama akan
merusak tiga belas berkas test berbarengan di commit yang sama dengan yang
menambahkan penggantinya, sehingga tidak ada satu titik pun di tengah pekerjaan
yang suite-nya hijau dan kegagalan menunjuk satu hal. Jadi: kolom baru muncul
dan yang lama dilonggarkan, penulis pindah, pembaca pindah, klien pindah, baru
kolomnya dijatuhkan.

Satu hal luput dari jaring: `AdminUserSeeder` masih menulis `username`, dan
grep verifikasi yang seharusnya menangkapnya berakhir dengan `grep -vi
userName` — `-i` membuatnya membuang setiap baris yang mengandung "username"
apa pun kapitalisasinya, jadi ia menyaring persis apa yang dicarinya. Suite yang
menangkapnya, dengan empat `QueryException`.

#### `max_concurrent_jobs` dihapus

Kolom itu tidak pernah dibandingkan dengan apa pun, di mana pun dalam `app/`.
Ia muncul di aturan validasi, `$fillable`, seeder dan test — dan hanya itu.
Niatnya terbaca jelas (jangan kirim lebih dari N pekerjaan serentak ke satu
worker) tetapi pembatasnya tidak pernah ditulis, sehingga yang benar-benar
dilakukan kolom itu adalah menjanjikan kendali yang tidak ada. Kartu admin dulu
menampilkan `Jobs: 2 / 5`, sebuah pecahan dari batas yang tidak eksis; sekarang
`Jobs running: 2`.

Saudaranya, `current_jobs_count`, tetap tinggal — ia bekerja sungguhan.

#### Lencana status ikut dibereskan

Bagian A mengganti jargon di kalimatnya tapi meninggalkan lencana yang merender
`status.toUpperCase()`, sehingga worker lambat berlabel **"TROUBLE"** persis di
sebelah kalimat "answering slowly". Sekarang `SLOW`.

#### Terverifikasi

Backend 256 test (dari 250), Flutter 147 test (dari 144), `flutter analyze`
bersih, APK release terbangun. Payload `/api/admin/users` diperiksa langsung
terhadap server yang berjalan: `phone` ada di setiap baris, `username` tidak ada
di mana pun.

Jumlah test backend naik 6, bukan 7: tujuh ditambahkan dan satu dihapus.
Yang dihapus menegaskan bahwa tabrakan username terselesaikan jadi
`siti.rahayu2` — dan tidak ada lagi yang mengarang username untuk bertabrakan.
Membuang asersinya sambil menyimpan test-nya akan meninggalkan test yang tidak
menguji apa pun.

**Rollback bersifat merusak.** Seluruh nilai `username` hilang; `down()` bisa
mengembalikan kolomnya tetapi mengisinya dengan `user{id}`, semata agar batasan
`unique` bisa dipasang kembali.

**Belum terverifikasi:** tampilan kolom telepon di aplikasi berjalan, dan
migrasi belum dijalankan di VPS.

---

## [1.20.0] - 2026-08-22

### Bagian A dari sepuluh permintaan perubahan: bersih-bersih UI

Sepuluh perubahan diajukan sekaligus dan dipecah jadi empat, karena satu
rencana yang memuat semuanya tidak akan bisa direview. Ini yang pertama —
dipilih lebih dulu justru karena ia satu-satunya yang bisa diverifikasi
sepenuhnya dari mesin pengembangan. Rancangan dan rencananya ada di
`docs/superpowers/specs/2026-08-22-ui-cleanup-design.md` dan
`docs/superpowers/plans/2026-08-22-ui-cleanup.md`; sisanya di ROADMAP.md §12.

#### Model yang lambat berhenti dilaporkan mati

Keluhan aslinya berbunyi "bar-nya merah padahal model online, jadi rancu".
Ternyata itu bukan soal pilihan warna melainkan bug.

`ModelHealthChecker` memasang **tiga** status, bukan dua. Yang ketiga,
`trouble`, dipasang ketika worker **menjawab tetapi lebih lambat** dari
`SLOW_THRESHOLD_MS` (5000 ms). `MeController::models()` menghitung
`is_available` sebagai `status === 'online'` persis, sehingga worker yang
jelas-jelas hidup dilaporkan tidak tersedia — dicat merah dengan judul
"Model offline", dan **tidak bisa dipilih sama sekali** di layar unggah,
karena `onTap` di sana bergantung pada `isAvailable`.

Untuk GPU Kaggle di balik terowongan ngrok, lambat adalah keadaan normal,
bukan pengecualian. Jadi selama ini kondisi paling biasa di platform ini
mengeluarkan model yang berfungsi dari daftar pilihan.

Sekarang `trouble` dihitung tersedia: kuning, bisa dipilih, dengan kalimat
yang mengatakan pekerjaannya akan lebih lama.

Urutannya harus ikut diperbaiki. `orderByDesc('status')` menempatkan
`online` di atas `offline` hanya karena kebetulan urutan abjad — dan begitu
`trouble` ikut dianggap tersedia, abjad terbalik justru melemparkannya ke
posisi teratas, sehingga pemilihan otomatis akan selalu jatuh ke worker
paling lambat. Sekarang `CASE` yang eksplisit; `CASE` dan bukan `FIELD()`
supaya tetap berjalan di SQLite.

#### Jargon diganti kalimat yang bisa ditindaklanjuti

`"Tunnel is not running (ERR_NGROK_3200)"` dulu ditampilkan apa adanya
kepada periset. Niatnya benar dan tertulis di test lama: seseorang perlu
diberi tahu **apa yang harus dilakukan**, bukan sekadar bahwa sesuatu mati.
Yang salah adalah sasarannya — periset tidak punya akses ke terowongan itu.
Admin yang punya.

Kolom baru `models.health_check_reason` menyimpan kode di samping pesan
mentah yang tidak berubah: `no_endpoint`, `tunnel_down`, `unreachable`,
`slow`. `no_endpoint` sengaja dipisah dari `unreachable` — model tanpa
alamat adalah pendaftaran yang belum selesai, bukan server yang mati, dan
menyuruh orang menyalakan ulang sesuatu yang belum pernah dikonfigurasi
mengirim mereka mencari mesin yang tidak ada.

Klien memetakannya lewat satu fungsi, `modelStatusMessage()`, sehingga strip
status dan layar unggah tidak bisa berbeda kata. Layar admin menampilkan
keduanya: kalimatnya, dengan kode mentah lebih kecil di bawahnya, karena
admin-lah yang menyalakan ulang sesi Kaggle dan `ERR_NGROK_3200` melawan
`HTTP 502` adalah bedanya terowongan mati dengan proses yang hidup tapi
gagal.

#### Sebuah kebocoran yang ditemukan di sepanjang jalan

`cleanMessage()` mengaku membuang URL dari pesan Guzzle; sebenarnya ia hanya
memotong panjangnya. Jadi `cURL error 7: Failed to connect to
abc123.ngrok-free.dev port 443` dikirim utuh ke `/api/me/models` — endpoint
yang **sengaja** menyembunyikan `endpoint_url` supaya tidak ada yang bisa
memanggil worker GPU langsung tanpa melewati platform.

`health_check_error` kini tidak dikirim ke periset sama sekali. Kode
alasannya tidak membawa alamat apa pun.

#### Teks bisa disalin, dan daftar aktivitas berhenti memanjangkan halaman

`SelectionArea` di empat tempat, bukan tiga: badan kedua shell, landing
page, dan `app_dialog.dart` — yang terakhir mudah terlewat karena
`showDialog` membuat route sendiri di overlay, sehingga tidak berada di
bawah shell mana pun. Dialog justru tempat nilai-nilai yang layak disalin
berada, seperti kata sandi hasil reset admin.

Daftar aktivitas terbaru di kedua dasbor dulu memakai `shrinkWrap` bersama
`NeverScrollableScrollPhysics`, jadi ia membentang setinggi seluruh isinya
dan ikut menggulung bersama halaman. `shrinkWrap` **dipertahankan** dan
hanya `physics` yang dibuang, di bawah batas 320px: tanpa `shrinkWrap`,
`ListView` yang diberi batas tinggi akan mengisi penuh 320px sekalipun
isinya dua baris.

#### Terverifikasi

Backend 250 test (dari 242), Flutter 144 test (dari 129), `flutter analyze`
bersih, `flutter build apk --release` berhasil (54,1 MB). Selain itu satu
probe sungguhan terhadap endpoint ngrok yang memang mati menulis
`health_check_reason: "tunnel_down"`, dan respons `/api/me/models`
terbukti tidak membawa nama host — diuji terhadap endpoint asli, bukan
`Http::fake`.

**Belum terverifikasi:** seleksi teks di ponsel fisik, dan tampilan kedua
perubahan tata letak di aplikasi berjalan. Tidak ada perangkat Android
tersambung saat ini. `REASON_SLOW` juga tidak punya test otomatis — ia
dipicu waktu berjalan yang melewati 5000 ms sementara `Http::fake` menjawab
seketika; perilaku yang benar-benar penting, worker lambat tetap ditawarkan,
diuji di tempat keputusannya diambil.

---

## [1.19.19] - 2026-08-18

### Pipeline prediksi dijalankan ujung-ke-ujung di VPS, terhadap GPU sungguhan

Aturan pertama CLAUDE.md: build yang lulus tidak mengatakan apa pun tentang
apakah interpolasinya bekerja. Sampai hari ini deployment VPS belum pernah
dibuktikan begitu. Sekarang sudah.

Dua frame batas 16-bit 1024x1024 dibuat sintetis dengan sebuah cakram yang
**berpindah** dari x=282 ke x=743, dinamai `frame_001.tif` dan `frame_005.tif`
— contoh yang sama persis dengan yang ada di README, dipilih karena celah 4
memaksa rekursi sungguhan: midpoint 3 dulu, lalu 3 menjadi batas untuk 2 dan 4.

Hasilnya, lewat tunnel ngrok ke backend VPS:

| | |
|---|---|
| Antrean | `pending` -> `processing` -> `completed` |
| Waktu | **27 detik**, tiga round-trip GPU |
| Keluaran | **3 frame** dari 2 masukan, persis n-1 |
| Arsip | `input/`, `output/`, `metadata.json` |
| Format | `I;16`, 1024x1024 — kedalaman bit dan dimensi terjaga |

**Bukti interpolasinya benar, bukan sekadar ada berkasnya.** MAE tiap frame
hasil terhadap kedua batas, skala 0-65535:

| frame | MAE vs 001 | MAE vs 005 | seharusnya |
|---|---|---|---|
| 002 | **1242** | 2194 | dekat 001 |
| 003 | 1581 | 1470 | di tengah |
| 004 | 2301 | **1135** | dekat 005 |

Monoton dan berurutan — 002 condong ke awal, 003 di tengah, 004 condong ke
akhir. Kelima SHA-256 berbeda, jadi tidak ada frame yang disalin dari
batasnya.

**Satu pengukuran sempat menyesatkan, dan itu layak dicatat.** Metrik pertama
yang dipakai — posisi kolom paling terang — melaporkan ketiga frame hasil ada
di kolom 0, yang terbaca seperti platform menyalin frame batas. Yang salah
metriknya: model tidak *memindahkan* cakram sintetis seperti fitur fisik
berpindah, ia memadukan keduanya, dan artefak tepi mendominasi jumlah kolom.
MAE terhadap kedua batas adalah ukuran yang tepat di sini.

**Yang TIDAK dibuktikan uji ini, dan tidak boleh diklaim:** mutu gambarnya.
Masukannya sintetis dan jauh di luar distribusi latih model — neutron CT
sungguhan. Uji ini membuktikan orkestrasinya: unggah, antre, tiga panggilan GPU
rekursif, TIFF kembali, arsip tersusun benar, unduhan utuh. Ia tidak
membuktikan hasilnya berguna secara ilmiah.

**Satu pengamatan untuk peneliti:** frame hasil punya artefak tepi yang kuat di
kedua sisi. Kolom 0 rata-rata 52.602 pada frame hasil, dibanding 13.407 pada
frame masukan — hampir empat kali lipat. Kemungkinan besar itu akibat masukan
sintetis, tapi kalau muncul juga pada data sungguhan, ia layak diperiksa
sebelum hasil dipakai.

Yang masih belum pernah dijalani: **training** ujung-ke-ujung. Itu endpoint dan
notebook yang berbeda.

---

## [1.19.18] - 2026-08-18

### Menyerahkan password ke seeder tidak berpengaruh apa-apa

```
SEED_ADMIN_PASSWORD='admin123' php artisan db:seed --force
  No SEED_ADMIN_PASSWORD was set, so one was generated.  pBTcup3r09aUy7ygRAZE
```

Terjadi di VPS, dan jawabannya paling membingungkan yang mungkin: seeder bilang
tidak ada password padahal baru saja diberi satu.

Sebabnya deploy menjalankan `php artisan config:cache`. Sejak saat itu
`config/*.php` adalah potret beku — apa pun yang `env()` kembalikan **saat
deploy** yang tersimpan, dan berkas `.env` tidak dibaca lagi sama sekali. Waktu
deploy itu `SEED_ADMIN_PASSWORD` memang belum ada, jadi `config(...)` bernilai
`null` selamanya, dan variabel yang diketik di terminal tidak pernah ditanya.

Direproduksi lokal sebelum diperbaiki, dengan mensimulasikan keadaan VPS —
config di-cache tanpa variabel itu, lalu dijalankan dengan variabel di command
line:

```
config(app.seed_admin_password) = NULL
env(SEED_ADMIN_PASSWORD)        = 'admin123'
```

`env()` **tetap** membaca environment proses sungguhan walau config di-cache;
yang berhenti dibaca hanya *berkas* `.env`. Jadi variabel yang baru diserahkan
terlihat oleh `env()` dan tak terlihat oleh `config()`.

`AdminUserSeeder` sekarang membaca `env(...) ?: config(...)` — urutan itu
memperbaiki kegagalan nyata, bukan menyatakan selera: nilai yang diketik
sekarang harus mengalahkan potret dari waktu deploy. Ini satu-satunya tempat di
aplikasi yang memanggil `env()` di luar `config/`, dan alasannya ditulis di
sana.

Empat test mengunci keempat jalurnya, dan yang kedua sempat gagal dengan cara
yang berguna: `unset($_SERVER[...])` saja tidak cukup, karena mesin
pengembangan punya variabel itu di `.env` dan Dotenv juga menerbitkannya lewat
`putenv` — `env()` terus menemukannya di sana. Helper testnya membersihkan
ketiga tempat.

Jebakannya masuk CLAUDE.md, termasuk akibat yang lebih luas: **setelah mengubah
`.env` di mesin ter-deploy, `config:cache` harus dijalankan lagi** atau tidak
ada yang berlaku.

### Peringatan yang salah di `apply.sh`

Tanpa `TLS_DOMAIN` ia memperingatkan bahwa browser akan menolak `http://` dari
klien web — padahal dengan tunnel aktif klien web justru punya alamat HTTPS.
Sekarang ia hanya memperingatkan kalau **tidak ada satupun** dari keduanya.

### Catatan dari eksekusi pertama `apply.sh`

Ia berjalan di server untuk pertama kalinya dan bekerja: mengganti site nginx
yang sudah ada alih-alih menambah yang kedua, mengganti berkas supervisor yang
sudah mendefinisikan ketiga program, mengambil alih program `ngrok` lama jadi
`brin-ngrok`, dan kedua smoke check lolos — 200 di `127.0.0.1:8080` dan 200
lewat tunnel.

`php artisan test`: **242 passed**, 976 assertions.

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
- [API Documentation](./API.md)

---

**Maintained by**: BRIN Development Team  
**Last Updated**: August 13, 2026
