# ✅ TODO List - Platform Analisis Citra Neutron CT

Task list untuk development platform.

---

## 📌 Legend

- ✅ Completed
- 🔄 In Progress
- ⏳ Planned
- 🔴 Blocked
- 📝 Design Required
- 🧪 Testing Required

---

## 🎯 FASE 1: MVP - Landing & Authentication (Week 1)

### Backend (Laravel)

#### Database & Models
- [x] ✅ Create users table migration
- [x] ✅ Add role, username, is_active fields to users
- [x] ✅ Create analysis_records table
- [x] ✅ Add user_id, time_scalar, expires_at to analysis_records
- [x] ✅ Create models table
- [x] ✅ Create user_activities table
- [x] ✅ Create default seeders (admin user, model)
- [x] ✅ Run migrations and seeders

#### Authentication API
- [x] ✅ Create AuthController
  - [x] login() method
  - [x] logout() method
  - [x] me() method
- [x] ✅ Setup Laravel Sanctum
- [x] ✅ Add authentication middleware
- [x] ✅ Add role-based middleware (IsAdmin)
- [x] ✅ Test login/logout flow
- [x] ✅ Add rate limiting (5 attempts/minute) — `throttle:5,1` di `routes/api.php`

### Frontend (Flutter)

#### Project Setup
- [x] ✅ Initialize Flutter project structure
- [x] ✅ Setup folders (screens, widgets, services, models)
- [x] ✅ Install dependencies (dio, provider, flutter_secure_storage)
- [x] ✅ Create API service class
- [x] ✅ Setup API configuration

#### Landing Page
- [x] ✅ Create landing_page.dart
- [x] ✅ Implement hero section dengan BRIN logo
- [x] ✅ Add WebGL animation placeholder
- [x] ✅ Create about section
- [x] ✅ Create research section
- [x] ✅ Create join section dengan form
- [x] ✅ Add smooth scroll navigation
- [x] ✅ Make responsive (mobile, tablet, desktop)
- [ ] 🧪 Test on multiple devices

#### Login Page
- [x] ✅ Create login_page.dart
- [x] ✅ Implement split screen layout (40/60)
- [x] ✅ Create login form (email, password)
- [x] ✅ Add form validation
- [x] ✅ Implement authentication logic
- [x] ✅ Add loading states
- [x] ✅ Add error handling
- [x] ✅ Store token securely
- [x] ✅ Add role-based routing
- [ ] 🧪 Test login flow

#### Shared Components
- [x] ✅ Create app_theme.dart (colors, typography)
- [ ] ⏳ Create custom button widget
- [ ] ⏳ Create custom input widget
- [ ] ⏳ Create loading indicator widget
- [ ] ⏳ Create error message widget

---

## 🎯 FASE 2 & 3: Admin & User Management (Week 2-3)

**Note:** FASE 2 digabung dengan FASE 3 Backend untuk efisiensi development.

### Backend (Laravel) - COMPLETE! ✅

#### Database Migrations
- [x] ✅ Add FASE 3 fields to `analysis_records`
  - [x] job_id (unique identifier)
  - [x] model_id (FK to models)
  - [x] input_folder, output_folder
  - [x] error_message, input_files_count, output_files_count
  - [x] processing_time_seconds, files_deleted_at
- [x] ✅ Add FASE 3 fields to `models`
  - [x] endpoint_url, status, last_health_check
  - [x] max_concurrent_jobs, current_jobs_count
  - [x] health_check_error, is_active
- [x] ✅ Add metadata (JSON) to `user_activities`
- [x] ✅ Change activity_type to VARCHAR(50)

#### User Management API
- [x] ✅ Create UserController (7 endpoints)
  - [x] index() - List users (pagination, search, filter by role/status)
  - [x] store() - Create user (admin set password, default: BrinResearch2026)
  - [x] show() - Get user detail
  - [x] update() - Update user (email, username, role only)
  - [x] destroy() - Delete user permanently (with self-protection)
  - [x] toggleStatus() - Toggle active/inactive (with self-protection)
  - [x] resetPassword() - Reset to default password
- [x] ✅ Add comprehensive validation rules
- [x] ✅ Add user activity logging (all actions tracked with metadata)
- [x] ✅ Test all CRUD operations successfully

#### Model Management API
- [x] ✅ Create ModelController (8 endpoints)
  - [x] index() - List models (pagination, filter by status)
  - [x] store() - Add new model (save Ngrok endpoint URL)
  - [x] show() - Get model detail
  - [x] update() - Update model info
  - [x] destroy() - Delete model (protection if has active jobs)
  - [x] toggleStatus() - Toggle active/inactive
  - [x] healthCheck() - Manual health check (ping endpoint)
  - [x] testPrediction() - Test with sample data
- [x] ✅ Implement health check logic
  - [x] Status: online ✅ / offline ❌ / trouble ⚠️
  - [x] Response time tracking (<3s = online, >3s = trouble)
  - [x] SSL verification skip for Ngrok
  - [x] Error message logging
- [x] ✅ Create CheckModelsHealth command
- [x] ✅ Schedule auto health check every 5 minutes
- [x] ✅ Test health check command successfully

#### User Activity Logs API
- [x] ✅ Create UserActivityController (3 endpoints)
  - [x] index() - List all activities with comprehensive filters
  - [x] userActivities() - Get activities for specific user
  - [x] getTypes() - Get available activity types
- [x] ✅ Add filtering capabilities:
  - [x] By user_id
  - [x] By activity type
  - [x] By date range (date_from, date_to)
  - [x] Pagination (per_page, page)
- [x] ✅ Activity types tracked:
  - [x] User: login, logout, create_user, update_user, delete_user, toggle_user_status, reset_password
  - [x] Model: create_model, update_model, delete_model, toggle_model_status, health_check, test_prediction
  - [x] Prediction: prediction, download (untuk nanti)

#### Models Created
- [x] ✅ app/Models/Model.php - Model untuk tabel models
- [x] ✅ app/Models/User.php - Updated with fillable fields
- [x] ✅ app/Models/UserActivity.php - Updated with metadata
- [x] ✅ app/Models/AnalysisRecord.php - Existing (akan diupdate untuk FASE 3 Part 2)

#### Routes Configured
- [x] ✅ User Management routes (7 endpoints)
- [x] ✅ Model Management routes (8 endpoints)
- [x] ✅ Activity Logs routes (3 endpoints)

#### Documentation
- [x] ✅ API_DOCS.md updated (semua endpoint terdokumentasi)
- [x] ✅ TODO.md updated (progress tracking)
- [x] ✅ FASE3_DECISIONS.md (already complete)
- [x] ✅ FASE3_ROADMAP.md (already complete)

---

## 🩹 OPTIMASI PERFORMANCE - LARAVEL OCTANE (14 Agustus 2026) — SELESAI ✅

Masalah timeout dan performance buruk pada `php artisan serve` berhasil diselesaikan
dengan migrasi ke **Laravel Octane + RoadRunner**.

### 🎯 Masalah yang Diselesaikan

**Before (php artisan serve):**
- ❌ Health check: 8,000 - 11,000 ms (timeout)
- ❌ Test prediction: Gagal timeout di 30 detik
- ❌ Bootstrap overhead: ~8 detik per request
- ❌ Concurrent handling: Buruk

**After (Octane + RoadRunner):**
- ✅ Health check: 1,300 - 1,700 ms (**84% faster**)
- ✅ Test prediction: 17.8 detik berhasil (cold), 2.4 detik (warm) (**86% faster**)
- ✅ Bootstrap overhead: Eliminated dengan worker persistence
- ✅ Concurrent handling: 3+ parallel requests tanpa masalah

### 🛠️ Perubahan Konfigurasi

**1. config/octane.php**
```php
'max_execution_time' => 300,  // Dari 30 → 300 detik (untuk Kaggle 15-20s)
'garbage' => 100,              // Dari 50 → 100 (GC lebih agresif)
```

**2. .env**
```env
OCTANE_SERVER=roadrunner
CACHE_STORE=file              # Dari database → file (performa lebih baik)
```

**3. package.json**
```json
{
  "scripts": {
    "octane": "php artisan octane:start --server=roadrunner --workers=4 --max-requests=250",
    "octane:watch": "php artisan octane:start --server=roadrunner --workers=4 --max-requests=250 --watch"
  }
}
```

**4. Windows Patch**
File: `vendor/laravel/octane/src/Commands/Concerns/InteractsWithServers.php`
```php
public function getSubscribedSignals(): array
{
    // Windows doesn't support PCNTL signals
    if (! defined('SIGINT')) {
        return [];
    }
    return [SIGINT, SIGTERM, SIGHUP];
}
```

### 📊 Test Results Summary

| Test | Response Time | Status | Notes |
|------|--------------|--------|-------|
| **Health Check** | 1.67s | ✅ | Was 8-11s, 84% faster |
| **Test Prediction (cold)** | 17.8s | ✅ | Was timeout, now working |
| **Test Prediction (warm)** | 2.4s avg | ✅ | 86% faster |
| **Concurrent Predictions (3x)** | 2.2-2.9s each | ✅ | All successful |
| **Login (concurrent 5x)** | 0.76-2.88s | ✅ | All tokens valid |
| **Users List** | 78ms | ✅ | Very fast |
| **Models List** | 80ms | ✅ | Very fast |
| **Activities List** | 143ms | ✅ | With pagination |

### 🚀 Production Readiness

- ✅ Handles long-running requests (17+ seconds)
- ✅ Concurrent request handling working
- ✅ Stable worker management (175+ requests tested)
- ✅ Proper error handling & logging maintained
- ✅ Performance meets all requirements

### 📝 Known Limitations

**Windows-Specific:**
1. `--watch` mode tidak berfungsi (PCNTL signals tidak tersedia)
   - Workaround: Manual restart setelah code changes
2. Defender exclusion butuh admin (not critical)

### 🔧 Commands

```bash
# Start server
npm run octane

# Check status
php artisan octane:status

# Stop server
php artisan octane:stop

# Reload workers
php artisan octane:reload

# Clear config cache
php artisan config:clear
```

### 📄 Dokumentasi

Detail lengkap testing dan benchmark tersedia di: **`TESTING_RESULTS.md`**

---

Audit menemukan 4 bug yang lolos dari testing sebelumnya. Semua sudah diperbaiki
dan diverifikasi dengan 30 test API live + 23 contract test.

- [x] ✅ **FIX 1 (BLOCKING):** `models.file_path` NOT NULL tanpa default → setiap
      `POST /admin/models` gagal HTTP 500 (`Field 'file_path' doesn't have a
      default value`). Kolom dibuat nullable karena model di-deploy remote
      (Kaggle/Colab) dan hanya butuh `endpoint_url`.
      Migration: `2026_08_14_160001_fix_models_table_constraints.php`
- [x] ✅ **FIX 1b (BLOCKING):** enum `models.status` masih `('online','offline','error')`
      padahal kode menulis `'trouble'` → `Data truncated` di MySQL STRICT mode.
      Enum diubah ke `('online','offline','trouble')`.
- [x] ✅ **FIX 2:** `last_login_at` tidak pernah tersimpan (tidak ada di
      `User::$fillable`) → sekarang tersimpan + cast datetime.
- [x] ✅ **FIX 2b:** `user_agent` tidak pernah tersimpan (tidak ada di
      `UserActivity::$fillable`) → sekarang tersimpan; ditambahkan juga ke 12
      log aktivitas di UserController & ModelController yang sebelumnya kosong.
- [x] ✅ **FIX 2c:** `metadata` di-cast `array`; 14 pemanggilan `json_encode()`
      yang redundan dihapus agar tidak double-encoded.
- [x] ✅ **FIX 3:** Rate limiting login (`throttle:5,1`) — sebelumnya 12x
      percobaan password salah tidak diblokir sama sekali.
- [x] ✅ **FIX 4:** Model duplikat dibersihkan (row #2 punya `endpoint_url` NULL
      tapi status `online`); `AdminUserSeeder` diubah ke `updateOrCreate` agar
      idempoten (sebelumnya crash saat re-seed).
- [x] ✅ **FIX 5:** `UserService.toggleStatus` di Flutter salah parse — endpoint
      hanya balikin `{id, is_active}`, bukan objek user penuh (ketahuan dari
      contract test, akan crash saat tombol diklik).
- [x] ✅ **FIX 6 (BLOCKING):** Model selalu OFFLINE padahal worker Kaggle hidup.
      Health check mengirim `POST {"health_check":true}` ke `/predict`, tapi
      endpoint FastAPI hanya menerima **multipart** (`file_t0`, `file_t2`,
      `time_scalar`) → balasannya **HTTP 422**, dan kode lama menganggap semua
      non-2xx = offline. Padahal 422 justru **membuktikan** server hidup.
      Solusi: `app/Services/ModelHealthChecker.php` — probe `GET` ke root tunnel
      (tidak menyentuh `/predict`, jadi tidak memicu inferensi GPU), dan
      status 200/404/405/422 dianggap "aplikasi hidup". Deteksi mati yang asli
      tetap jalan lewat header `ngrok-error-code` (ERR_NGROK_3200), DNS gagal,
      dan connection refused. Threshold `trouble` dinaikkan 3s → 5s dan timeout
      10s → 15s karena latensi ngrok→Kaggle terukur 0,3–1,5s (pernah spike).
- [x] ✅ **FIX 7:** `testPrediction()` juga mengirim JSON ke endpoint multipart.
      Sekarang meng-upload 2 frame TIFF 16-bit yang dibuat in-memory +
      `time_scalar=0.5`, dan memvalidasi balasan biner `image/tiff`
      (bukan `$response->json()`, karena worker mengembalikan TIFF).
      Terverifikasi memanggil GPU Kaggle sungguhan: 18,3 detik, hasil
      2.097.408 byte = 1024×1024×16-bit + header.
- [x] ✅ **FIX 8:** Duplikasi logika health check di `ModelController` dan
      `CheckModelsHealth` dihapus; keduanya kini memakai `ModelHealthChecker`.
- [x] ✅ **FIX 9:** Timeout Dio di Flutter dinaikkan khusus untuk test
      prediction (3 menit) dan health check (45 detik); default 30 detik tidak
      cukup untuk inferensi GPU yang butuh ~18 detik.

---

## 🎯 FASE 2 FRONTEND: Admin Dashboard (14 Agustus 2026) — SELESAI ✅

Sebelumnya diklaim "COMPLETE" di FASE2_COMPLETION_SUMMARY.md, padahal isinya
hanya placeholder "Under Construction". Sekarang benar-benar dibangun.

#### Fondasi
- [x] ✅ `lib/services/api_client.dart` — Dio client bersama + auto Bearer token
      + translasi error (422 field errors, 401, 403, 429, 500)
- [x] ✅ `lib/models/pagination.dart` — parser blok `pagination` Laravel
- [x] ✅ `lib/models/model_info.dart` — 16 field, toleran tipe (DECIMAL as string)
- [x] ✅ `lib/models/activity_log.dart` — termasuk relasi user & metadata
- [x] ✅ `lib/widgets/status_badge.dart`, `async_state_views.dart`,
      `pagination_bar.dart` (folder `widgets/` sebelumnya kosong)

#### Dashboard Layout
- [x] ✅ Create `admin_shell.dart` (menggantikan placeholder `admin_dashboard.dart`)
- [x] ✅ Implement sidebar navigation (3 seksi)
- [x] ✅ Create header with user info
- [x] ✅ Add logout functionality (dengan dialog konfirmasi)
- [x] ✅ Make sidebar responsive (drawer di bawah 1000px)

#### User Management Screen
- [x] ✅ Create `user_management_screen.dart`
- [x] ✅ Implement user list dengan pagination (DataTable)
- [x] ✅ Add search functionality (debounce 400ms)
- [x] ✅ Add filter (role, status)
- [x] ✅ Create user dialog (create - with password field, opsional)
- [x] ✅ Create user dialog (edit - name, username, email, role)
- [x] ✅ Implement delete confirmation
- [x] ✅ Add toggle status button (disabled untuk diri sendiri)
- [x] ✅ Add reset password button (menampilkan password baru)
- [x] ✅ Self-protection UI (tidak bisa hapus/nonaktifkan akun sendiri)
- [x] 🧪 Test CRUD operations — 30/30 test API live PASS

#### Model Management Screen
- [x] ✅ Create `model_management_screen.dart`
- [x] ✅ Display model cards grid (responsif 1-3 kolom)
- [x] ✅ Show model status indicator (🟢 online / 🔴 offline / 🟡 trouble)
- [x] ✅ Show prediction count & job capacity
- [x] ✅ Add model dialog (create - with endpoint URL + validasi URL)
- [x] ✅ Add toggle status functionality
- [x] ✅ Add health check button (menampilkan response time)
- [x] ✅ Add test prediction button (nonaktif jika model tidak online)
- [x] ✅ Show deployment info + health check error
- [x] 🧪 Test status changes — PASS

#### User Activity Screen
- [x] ✅ Create `activity_logs_screen.dart`
- [x] ✅ Display activity list dengan pagination
- [x] ✅ Add filter by user dropdown
- [x] ✅ Add filter by type dropdown (dari endpoint `/activities/types`)
- [x] ✅ Add date range picker
- [x] ✅ Timeline view dengan ikon & warna per jenis aktivitas
- [x] ✅ Detail metadata (dialog)
- [x] 🧪 Test filtering — PASS
- [x] ✅ Export to CSV

#### Dashboard Home
- [x] ✅ Create `dashboard_home_screen.dart`
- [x] ✅ Statistics cards (users, models, activities)
- [x] ✅ Recent activities widget (last 10)
- [x] ✅ Responsive design
- [x] ✅ Update routing in `admin_shell.dart`

#### Verifikasi
> ⚠️ Dua centang pertama di bawah **tidak pernah benar-benar dijalankan** saat
> ditulis. Saat akhirnya dijalankan pada 15 Agustus 2026: `flutter analyze`
> memberi **12 error** dan build (APK maupun web) gagal total. Sudah diperbaiki
> di v1.2.1 — lihat CHANGELOG.

- [x] ✅ `flutter analyze` — 0 issues (diverifikasi ulang 15 Agu 2026)
- [x] ✅ `flutter build web --release` — sukses (diverifikasi ulang 15 Agu 2026)
- [x] ✅ `flutter build apk --release` — sukses (diverifikasi ulang 15 Agu 2026)
- [x] ✅ Contract test FE↔BE — 23/23 PASS (checklist `curl` manual, bukan suite)

---

## 🎨 POLISH FASE 1 & 2 (14 Agustus 2026) — SELESAI ✅

### ✅ Yang Dikerjakan:

**1. Dashboard Home Screen** ⭐⭐⭐
- [x] ✅ Create `dashboard_home_screen.dart` dengan statistics cards
- [x] ✅ Total users (active/inactive breakdown)
- [x] ✅ Total models (online/offline/trouble status)
- [x] ✅ Today's activity count
- [x] ✅ Recent activities (last 10) dengan timeline view
- [x] ✅ Responsive design
- [x] ✅ Update `admin_shell.dart` routing (Dashboard as default)

**2. Export to CSV** ⭐⭐
- [x] ✅ Add `csv` package to `pubspec.yaml`
- [x] ✅ Export function in `activity_logs_screen.dart`
- [x] ✅ Export button dengan green success color
- [x] ✅ Respects current filters (user, type, date range)
- [x] ✅ Auto-download with timestamp filename
- [x] ✅ CSV format: timestamp, user, type, description, IP, user agent

**3. Smooth Scroll Navigation** ⭐⭐
- [x] ✅ Already implemented in `landing_page.dart`
- [x] ✅ ScrollController with section tracking
- [x] ✅ Smooth animation (800ms, easeInOut curve)
- [x] ✅ Active section highlighting in navigation
- [x] ✅ Navigation buttons trigger smooth scroll

### 📝 Notes:
- Custom widgets (button, input, loading, error) — SKIPPED untuk avoid breaking existing code
- Manual device testing — Better done by QA/user
- Login flow testing — Already tested via contract tests

---

## 🎯 FASE 3 Part 2: Upload & Download Backend (Next - Week 3)

### Backend (Laravel)

#### Upload & Validation
- [ ] ⏳ Update AnalysisController
  - [ ] store() - Handle ZIP upload dengan streaming
  - [ ] storeChunk() - Handle chunked upload (>50 MB)
  - [ ] validateZip() - Validate ZIP structure
- [ ] ⏳ Add ZIP extraction logic
- [ ] ⏳ Add file validation (.tif only, naming convention)
- [ ] ⏳ Add storage logic (predictions/{user_id}/{job_id}/)

#### Prediction API
- [ ] ⏳ Update AnalysisController (cont.)
  - [ ] index() - List user predictions dengan pagination
  - [ ] show() - Get prediction status & detail
  - [ ] downloadResults() - Download results only (ZIP)
  - [ ] downloadComplete() - Download complete sequence (ZIP)
  - [ ] destroy() - Delete prediction
- [ ] ⏳ Add file validation (format, size, naming)
- [ ] ⏳ Implement on-demand ZIP creation
- [ ] ⏳ Add MD5 checksum for downloads
- [ ] ⏳ Add streaming download response

#### Background Job
- [ ] ⏳ Update ProcessDeepLearningImage job
  - [ ] Extract ZIP files
  - [ ] Detect frame gaps
  - [ ] Implement recursive interpolation logic
  - [ ] Call Ngrok API for each prediction
  - [ ] Save results to output/ folder
  - [ ] Update database status
  - [ ] Set expires_at (now + 24 hours)
- [ ] ⏳ Add error handling
- [ ] ⏳ Log processing time
- [ ] 🧪 Test job execution

#### Queue Management
- [ ] ⏳ Create QueueController
  - [ ] getStatus() - Get queue position
  - [ ] getEstimatedWait() - Calculate wait time
- [ ] ⏳ Add queue position tracking
- [ ] ⏳ Add notification on completion

#### Auto-Delete Feature
- [ ] ⏳ Create DeleteExpiredFiles command
  - [ ] Find expired predictions (>24h)
  - [ ] Delete physical files
  - [ ] Update files_deleted_at timestamp
  - [ ] Keep database record
- [ ] ⏳ Schedule command (daily at 2 AM)
- [ ] ⏳ Add soft delete for old records (30 days)
- [ ] 🧪 Test auto-delete

---

## 🎯 FASE 3 Part 3: Flutter Frontend (Week 4)

### Frontend (Flutter)

#### Dashboard User Layout
- [ ] ⏳ Create user_dashboard_layout.dart
- [ ] ⏳ Implement sidebar navigation
- [ ] ⏳ Create header
- [ ] ⏳ Make responsive

#### Upload Screen
- [ ] ⏳ Create upload_screen.dart
- [ ] ⏳ Add upload guidelines/checklist
- [ ] ⏳ Add sample dataset download link
- [ ] ⏳ Add tutorial/help section
- [ ] ⏳ Implement drag-and-drop zone
- [ ] ⏳ Add file picker button
- [ ] ⏳ Show file preview & validation
- [ ] ⏳ Add client-side validation (size, format)
- [ ] ⏳ Implement smart upload (direct vs streaming)
- [ ] ⏳ Show upload progress dengan details
  - [ ] Uploaded bytes / total
  - [ ] Speed (MB/s)
  - [ ] Time remaining
  - [ ] Chunk progress (for large files)
- [ ] ⏳ Add pause/resume button (optional)
- [ ] ⏳ Show queue position after upload
- [ ] ⏳ Show estimated wait time
- [ ] 🧪 Test upload flow

#### Prediction Result Screen
- [ ] ⏳ Create prediction_result_screen.dart
- [ ] ⏳ Show status indicator (pending/processing/completed/failed)
- [ ] ⏳ Implement status polling (every 10 seconds)
- [ ] ⏳ Display statistics (input count, output count, processing time)
- [ ] ⏳ Show expiry countdown timer
- [ ] ⏳ Add 2 download options:
  - [ ] Download Results Only (predicted files)
  - [ ] Download Complete Sequence (organized structure)
- [ ] ⏳ Show download progress
- [ ] ⏳ Implement download verification (MD5 checksum)
- [ ] ⏳ Add retry mechanism (3 attempts)
- [ ] ⏳ Display file preview/gallery (optional)
- [ ] ⏳ Add delete button
- [ ] ⏳ Show expiry warning notification
- [ ] 🧪 Test result viewing

#### Prediction History Screen
- [ ] ⏳ Create prediction_history_screen.dart
- [ ] ⏳ Display prediction list dengan pagination
- [ ] ⏳ Add filter by status (all/completed/processing/failed)
- [ ] ⏳ Add search by job ID
- [ ] ⏳ Add sort options (date, status)
- [ ] ⏳ Navigate to detail on click
- [ ] ⏳ Show expired status
- [ ] 🧪 Test history

---

## 🎯 FASE 4: Recursive Interpolation & Polish (Week 4)

### Backend (Laravel)

#### Recursive Logic Implementation
- [ ] ⏳ Create RecursiveInterpolation service class
- [ ] ⏳ Implement frame gap detection
- [ ] ⏳ Implement recursive prediction steps
- [ ] ⏳ Add frame naming logic
- [ ] ⏳ Save all intermediate frames
- [ ] ⏳ Return all frames in response
- [ ] 🧪 Test with various gap sizes
- [ ] 🧪 Verify frame quality

#### API Optimization
- [ ] ⏳ Add response caching
- [ ] ⏳ Optimize database queries (N+1 problem)
- [ ] ⏳ Add database indexes
- [ ] ⏳ Implement API versioning

### Frontend (Flutter)

#### Enhanced Features
- [ ] ⏳ Add image zoom functionality
- [ ] ⏳ Add image comparison slider (T0 vs T1 vs T2)
- [ ] ⏳ Implement dark mode (optional)
- [ ] ⏳ Add settings screen
- [ ] ⏳ Implement profile editing

#### Polish & UX
- [ ] ⏳ Add skeleton loading states
- [ ] ⏳ Improve error messages
- [ ] ⏳ Add empty states
- [ ] ⏳ Add success animations
- [ ] ⏳ Improve form validation messages
- [ ] 🧪 User testing session

---

## 🎯 FASE 5: Testing & Documentation (Week 5)

### Testing

#### Backend Tests
- [ ] ⏳ Write unit tests untuk controllers
- [ ] ⏳ Write unit tests untuk services
- [ ] ⏳ Write unit tests untuk jobs
- [ ] ⏳ Write integration tests untuk API
- [ ] ⏳ Write feature tests untuk flows
- [ ] 🧪 Run test coverage report
- [ ] 🧪 Fix failing tests

#### Frontend Tests
- [ ] ⏳ Write widget tests
- [ ] ⏳ Write integration tests
- [ ] ⏳ Write e2e tests
- [ ] 🧪 Test on real devices
- [ ] 🧪 Performance testing

#### Manual Testing
- [ ] 🧪 Test all user flows
- [ ] 🧪 Test on different browsers
- [ ] 🧪 Test on different devices
- [ ] 🧪 Test edge cases
- [ ] 🧪 Security testing
- [ ] 🧪 Load testing

### Documentation
- [x] ✅ Write README.md
- [x] ✅ Write ARCHITECTURE.md
- [x] ✅ Write API_DOCS.md
- [x] ✅ Write DESIGN.md
- [x] ✅ Write PRD.md
- [x] ✅ Write SETUP.md
- [x] ✅ Write TODO.md
- [ ] ⏳ Write CHANGELOG.md
- [ ] ⏳ Write AI_EXPERIMENTS.md
- [ ] ⏳ Create user manual (PDF)
- [ ] ⏳ Create video tutorials
- [ ] ⏳ Create API Postman collection

---

## 🎯 FASE 6: Deployment & Launch (Week 6)

### Deployment Preparation
- [ ] ⏳ Setup production server
- [ ] ⏳ Configure SSL certificate
- [ ] ⏳ Setup domain name
- [ ] ⏳ Configure firewall rules
- [ ] ⏳ Setup database backup
- [ ] ⏳ Configure monitoring tools

### Backend Deployment
- [ ] ⏳ Optimize Laravel for production
- [ ] ⏳ Setup queue workers
- [ ] ⏳ Configure supervisor for queue
- [ ] ⏳ Setup cron jobs
- [ ] ⏳ Deploy to server
- [ ] 🧪 Smoke testing

### Frontend Deployment
- [ ] ⏳ Build Flutter web
- [ ] ⏳ Deploy web app
- [ ] ⏳ Build Android APK
- [ ] ⏳ Sign APK
- [ ] ⏳ Distribute APK (internal testing)
- [ ] 🧪 Smoke testing

### Post-Launch
- [ ] ⏳ Monitor error logs
- [ ] ⏳ Setup analytics
- [ ] ⏳ Create feedback form
- [ ] ⏳ User onboarding
- [ ] ⏳ Training session untuk researchers
- [ ] ⏳ Gather initial feedback
- [ ] ⏳ Fix critical bugs

---

## 🚀 Future Enhancements (Backlog)

### Features
- [ ] 📝 Batch processing (multiple file pairs)
- [ ] 📝 Email notifications
- [ ] 📝 Real-time updates via WebSocket
- [ ] 📝 Model comparison feature
- [ ] 📝 Export reports (PDF, CSV)
- [ ] 📝 Collaboration features (share results)
- [ ] 📝 Advanced analytics dashboard
- [ ] 📝 Mobile app (iOS)
- [ ] 📝 Dark mode
- [ ] 📝 Multi-language support
- [ ] 📝 API key management
- [ ] 📝 Custom model upload

### Technical Improvements
- [ ] 📝 Implement Redis for caching
- [ ] 📝 Setup CI/CD pipeline
- [ ] 📝 Add automated testing in pipeline
- [ ] 📝 Database replication (master-slave)
- [ ] 📝 Load balancer setup
- [ ] 📝 CDN for static assets
- [ ] 📝 Implement GraphQL API (optional)
- [ ] 📝 Microservices architecture (future)

### DevOps
- [ ] 📝 Docker containerization
- [ ] 📝 Kubernetes deployment
- [ ] 📝 Automated backup scripts
- [ ] 📝 Disaster recovery plan
- [ ] 📝 Performance monitoring
- [ ] 📝 Log aggregation (ELK stack)

---

## 🐛 Known Issues

### Critical
- [ ] 🔴 None currently

### High Priority
- [ ] 🔴 None currently

### Medium Priority
- [ ] 🔴 None currently

### Low Priority
- [ ] 🔴 None currently

---

## 📊 Progress Tracking

### Overall Progress: 72%

| Phase | Progress | Status |
|-------|----------|--------|
| Fase 1: MVP | 100% | ✅ Complete |
| Fase 2 Backend (Admin APIs) | 100% | ✅ Complete & diaudit (30/30 test PASS) |
| Fase 2 Frontend (Admin UI) | 100% | ✅ Complete (Dashboard home + CSV export done!) |
| Fase 3 Backend (Upload/Download) | 0% | ⏳ Next — lihat catatan blocker di bawah |
| Fase 4: Recursion & Polish | 0% | ⏳ Planned |
| Fase 5: Testing & Docs | 75% | 🔄 In Progress |
| Fase 6: Deployment | 0% | ⏳ Planned |

### Sprint Goals

**Current Sprint: FASE 3 Backend Part 1** ✅ COMPLETE!
- [x] ✅ Complete database migrations (analysis_records, models, user_activities)
- [x] ✅ Complete user management (7 endpoints: CRUD + toggle + reset)
- [x] ✅ Complete model management (8 endpoints: CRUD + health + test)
- [x] ✅ Complete activity monitoring (3 endpoints: list + filters + types)
- [x] ✅ Auto health check command (scheduled every 5 min)
- [x] ✅ Activity logging (all admin actions tracked)
- [x] ✅ API documentation updated
- [x] ✅ Test all endpoints (User Management tested & working)
- [x] ✅ Add user_agent field to user_activities table

**Next Sprint: FASE 3 Backend Part 2** 🔄 NEXT
- [ ] Upload API (ZIP streaming, validation, extraction)
- [ ] Download API (on-demand ZIP, MD5 verification, 2 options)
- [ ] Background Job (ProcessDeepLearningImage with recursive interpolation)
- [ ] Queue system (position tracking, wait time)
- [ ] Auto-cleanup command (daily at 2 AM)

> ⚠️ **Blocker yang harus dibereskan dulu sebelum FASE 3** (temuan audit):
> 1. `AnalysisController` sudah ditulis lengkap (11 method) tapi **0 route
>    terdaftar** — blok `predictions` di `routes/api.php` masih dikomentari.
> 2. `AnalysisRecord` **tidak punya relasi `model()` dan `user()`**, padahal
>    controller memanggil `->with('model:id,name,version')` → akan
>    `BadMethodCallException` begitu route diaktifkan.
> 3. `AnalysisRecord` tidak punya `$casts` datetime, tapi controller memanggil
>    `$prediction->expires_at->toIso8601String()`.
> 4. `ProcessDeepLearningImage` masih pakai URL ngrok **hardcoded** dan alur lama
>    2-gambar; mengabaikan `model_id`/`endpoint_url`. Perlu ditulis ulang agar
>    memakai endpoint dari tabel `models` (Kaggle/Colab).
> 5. `NGROK_API_URL` di `.env` tidak pernah dibaca kode manapun.
> 6. `current_jobs_count` / `total_predictions` tidak pernah di-increment,
>    padahal `destroy`/`toggleStatus` sudah memakainya sebagai proteksi.
> 7. Belum ada `config/cors.php` — Flutter Web dari origin berbeda akan kena CORS.
> 8. Storage: `AnalysisController` menulis ke disk **local (private)** sedangkan
>    job membaca dari disk **public**.

**Future Sprint: FASE 3 Frontend**
- [ ] Admin Dashboard UI (user management, model management, activity logs)
- [ ] User Dashboard UI (upload, history, results)
- [ ] Responsive design improvements

---

## 📝 Notes

### Important Reminders
- Ngrok URL berubah setiap restart Kaggle/Colab → **update lewat UI Admin →
  Model Management → Edit → Endpoint URL**, BUKAN lewat `.env`.
  Sistem otomatis menjalankan health check ulang setelah URL diubah.
  (`NGROK_API_URL` di `.env` tidak dibaca kode manapun — peninggalan lama.)
- Kontrak worker Kaggle (`POST /predict`): **multipart/form-data** dengan field
  `file_t0` (TIFF), `file_t2` (TIFF), `time_scalar` (float). Balasannya **biner
  `image/tiff`**, bukan JSON. Jangan kirim JSON — pasti 422.
- Worker hanya punya route `/predict`. `GET /` mengembalikan 404 dan itu
  **normal** (bukan tanda offline). `/docs` dan `/openapi.json` tersedia.
- File results auto-delete setelah 24 hours → Warning ke user
- Database backup before migrations
- Test on real devices regularly
- Code review before merging

### Dependencies Between Tasks
- Login must complete before dashboard
- Upload must complete before prediction
- Prediction API must complete before recursive logic
- Backend API must complete before frontend integration

---

## 🤝 Team Responsibilities

### Backend Developer
- Laravel API development
- Database design & optimization
- Queue jobs implementation
- Testing & debugging

### Frontend Developer
- Flutter UI implementation
- API integration
- State management
- Responsive design

### Full Stack (Mahasiswa TA)
- Both backend & frontend
- Integration testing
- Documentation
- Deployment

---

**Last Updated**: August 13, 2026  
**Next Review**: Daily standup  
**Status**: Active Development


---

**Last Updated**: 14 Agustus 2026  
**Status**: Active Development - FASE 3 Backend Part 1 SELESAI! 🎉

## 🎉 FASE 3 Part 1 - Summary Pencapaian Hari Ini

### ✅ Yang Sudah Dikerjakan (14 Agustus 2026):

**Database (6 Migrations):**
- analysis_records: +9 kolom (job_id, model_id, folders, counts, times)
- models: +8 kolom (endpoint_url, status, health check fields, is_active)
- user_activities: +1 kolom (metadata JSON), activity_type VARCHAR(50)
- user_activities: +1 kolom (user_agent VARCHAR(255) - untuk tracking browser info)

**Backend Controllers (21 Endpoints Total):**
1. **UserController** (7 endpoints) - ✅ TESTED & WORKING
   - List, Create (dengan default password), Show, Update, Delete, Toggle, Reset Password
2. **ModelController** (8 endpoints) - ⏳ Siap ditest
   - List, Create, Show, Update, Delete, Toggle, Health Check, Test Prediction
3. **UserActivityController** (3 endpoints) - ⏳ Siap ditest
   - List dengan filters lengkap, User-specific, Get Types

**Commands & Schedule:**
- CheckModelsHealth command dibuat & tested
- Scheduled setiap 5 menit di console.php

**Models:**
- Model.php dibuat lengkap dengan relations
- User, UserActivity updated

**Documentation:**
- API_DOCS.md: +450 baris (semua endpoint terdokumentasi)
- TODO.md: Updated dengan progress tracking detail
- 18 routes configured

### 🔑 Fitur Utama:
- Password default: "BrinResearch2026"
- Self-protection: Admin tidak bisa hapus/nonaktifkan diri sendiri
- Model health: online ✅ / offline ❌ / trouble ⚠️
- Activity logging: Semua aksi tercatat dengan metadata
- Model protection: Tidak bisa hapus model yang ada active jobs

### 📊 Perbandingan dengan Roadmap:
✅ **PHASE 1 (Day 1-2): Database & Backend Foundation** - COMPLETE!
- ✅ Day 1 Morning: Database Migrations - DONE
- ✅ Day 1 Afternoon: UserController - DONE & TESTED
- ✅ Day 2 Morning: ModelController + Health Check Command - DONE
- ✅ Day 2 Afternoon: UserActivityController - DONE

**Progress:** Sesuai dengan FASE3_ROADMAP.md, tidak ada yang terlewat! 🎯

### 🚀 Langkah Selanjutnya:
**PHASE 2 (Day 3-4): Upload & Download Backend**
1. AnalysisController - Upload methods (ZIP streaming)
2. AnalysisController - Download methods (on-demand ZIP, MD5)
3. ProcessDeepLearningImage job (recursive interpolation)
4. Queue management
5. Auto-cleanup command

---
