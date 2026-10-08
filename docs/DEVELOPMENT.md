# Pengembangan dan verifikasi

Komponen: Next.js 16.4/React/Node 22, Laravel 12/PHP 8.2+/Composer/MySQL 8,
Flutter 3.44.9. Worker inference memerlukan environment TensorFlow/TIFF di host
GPU; tidak dijalankan dalam proses Laravel.

## Backend lokal

```bash
cd be
composer install
npm ci
cp .env.example .env
php artisan key:generate
```

Atur DB_CONNECTION=mysql, DB_HOST/PORT/DATABASE/USERNAME/PASSWORD,
QUEUE_CONNECTION=database dan CACHE_STORE sesuai environment.
Buat database aplikasi, lalu:

```bash
php artisan migrate
php artisan db:seed
php artisan octane:install --server=roadrunner
npm run serve:all
```

Seed administrator melalui SEED_ADMIN_EMAIL/SEED_ADMIN_PASSWORD untuk database
baru. Password kosong membuat password acak; jangan menjalankannya terhadap
database produksi tanpa tujuan bootstrap yang jelas.

## Website dan Flutter

```bash
cd fe_web
npm ci
cp .env.example .env.local
npm run dev
```

LARAVEL_API_BASE_URL menunjuk API lokal atau Pi. Untuk production build,
variable itu wajib dikonfigurasi. Next.js menggunakan docs versi terpasang
di node_modules/next/dist/docs. agentRules=false mencegah AGENTS.md dibuat lagi.

```bash
cd fe
flutter pub get
flutter run --dart-define=API_BASE_URL=http://127.0.0.1:8000/api
```

Emulator Android memakai host 10.0.2.2. Desktop/perangkat memakai alamat host
yang dapat dijangkau. Aset aplikasi berada di frontend masing-masing;
folder bahan proposal/desain/notebook tidak dibutuhkan saat build.

## Pemeriksaan sesuai perubahan

```bash
cd fe_web
npm run check
npm test
npm run build
npm audit --omit=dev
```

```bash
cd be
php artisan route:clear
php artisan test
php scripts/smoke-portal.php http://127.0.0.1:8000/api
```

Suite backend memerlukan database terisolasi db_aict_test di MySQL 8.
Jangan menggantinya dengan database produksi atau SQLite; beberapa migration
memakai DDL MySQL. Jalankan suite secara serial. Jika environment proses
menetapkan QUEUE_CONNECTION=database, override ke sync untuk PHPUnit.
Gunakan apiAs(token) pada test request dan Storage::fake untuk test file.

```bash
cd fe
flutter analyze
flutter test
flutter build apk --release --dart-define=API_BASE_URL=https://zestfully-usable-pledge.ngrok-free.dev/api
```

CI membuat build Web/Android/Linux/iOS/macOS. Uji browser perubahan UI memakai
API/database terisolasi, kedua role, desktop/mobile, fokus dan navigasi.
Bukti sebelumnya: backend 329 tes/1.381 asersi, Flutter 227 tes, browser 51,
Pi smoke 39 dan HTTPS publik 25; detail/commit ada di CHECKPOINT.md.
Jangan mengklaim UAT GPU nyata dari worker mock atau passing build.

## Konvensi

- Authorisasi kepemilikan/role dilakukan Laravel pada setiap request.
- Jangan memasukkan raw ZIP/TIFF ke log atau menyimpan secret di frontend.
- Upload memakai chunk resumable; file besar tidak diproxy utuh melalui Vercel.
- Preserve provenance/validation dan state failed/pending yang sebenarnya.
- Flutter memakai safe area, dropdown expanded, conditional export file API;
  tidak mengimpor dart:html untuk target native.
- Web mempertahankan kontrol responsif dan reduced motion.
- Riwayat perubahan ada di Git; dokumentasi aktif hanya README dan docs.
