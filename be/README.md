# 🔬 Backend - Platform Analisis Citra Neutron CT

Backend API RESTful berbasis **Laravel 12 + Octane** untuk platform analisis citra Neutron CT.

---

## 🚀 Tech Stack

- **Framework:** Laravel 12.66.0
- **PHP:** 8.2.30
- **Web Server:** Laravel Octane + RoadRunner 2025.1.15
- **Database:** MySQL 8.x
- **Authentication:** Laravel Sanctum
- **Queue:** Database driver
- **Cache:** File driver

---

## 📦 Features

### API Endpoints (35 Total)

Plus an unauthenticated `GET /api/health` liveness probe, which is declared in
`routes/web.php` (not `routes/api.php`). Laravel's own health endpoint is at
`/up`. Verify the full list at any time with `php artisan route:list --path=api`.

#### Authentication (3)
- `POST /api/login` - Login with email & password
- `POST /api/logout` - Logout (revoke token)
- `GET /api/user` - Get authenticated user info

#### User Management (7) - Admin Only
- `GET /api/admin/users` - List users with pagination & filters
- `POST /api/admin/users` - Create new user
- `GET /api/admin/users/{id}` - Get user detail
- `PUT /api/admin/users/{id}` - Update user
- `DELETE /api/admin/users/{id}` - Delete user
- `PATCH /api/admin/users/{id}/toggle` - Toggle active status
- `POST /api/admin/users/{id}/reset-password` - Reset to default

#### Model Management (8) - Admin Only
- `GET /api/admin/models` - List models
- `POST /api/admin/models` - Add new model
- `GET /api/admin/models/{id}` - Get model detail
- `PUT /api/admin/models/{id}` - Update model
- `DELETE /api/admin/models/{id}` - Delete model
- `PATCH /api/admin/models/{id}/toggle` - Toggle active status
- `POST /api/admin/models/{id}/health-check` - Manual health check
- `POST /api/admin/models/{id}/test` - Test prediction

#### Self-service (3) - Any authenticated user
- `GET /api/me/stats` - Counters for the caller's own dashboard
- `GET /api/me/activities` - The caller's own audit trail, paginated
- `GET /api/me/models` - Models this user may submit work to

All three are scoped server-side, so there is no id to pass and no way to read
another account's data. Neither `me/stats` nor `me/models` ever exposes
`endpoint_url`: knowing it would let anyone bypass the platform and hit the GPU
worker directly.

Without these an ordinary researcher could reach nothing but `GET /user`,
since everything under `/admin` requires the admin role.

#### Predictions (6) - Any authenticated user (FASE 3)
- `POST /api/predictions` - Upload a ZIP of numbered `.tif` frames, queue a job
- `GET /api/predictions` - List the caller's own jobs, paginated
- `GET /api/predictions/{id}` - Job detail, including queue position while pending
- `DELETE /api/predictions/{id}` - Delete a job and its files
- `GET /api/predictions/{id}/frames` - What is on disk, inputs and outputs
- `GET /api/predictions/{id}/frames/{name}/preview` - That frame as a PNG
- `GET /api/predictions/{id}/download/results` - ZIP of generated frames only
- `GET /api/predictions/{id}/download/complete` - ZIP of input + output + `metadata.json`

Every action is scoped to `auth()->user()` inside `AnalysisController`, so
these need no admin role. Downloads stream and carry `X-Checksum-MD5`.

**Upload contract.** The ZIP must hold at least two `.tif`/`.tiff` files whose
names contain frame numbers, and those numbers must leave a **gap** — the job
interpolates what is missing between them. `frame_001.tif` + `frame_005.tif`
generates 002, 003 and 004. Consecutive frames are rejected with a clear
message, as is any job that would generate more than 200 frames.

**Frame preview.** Frames on disk are 16-bit TIFFs, which no browser or Flutter
build can decode. `TiffPreview` renders them to 8-bit greyscale PNG in plain
PHP — this machine has neither GD nor Imagick, and the input is narrow enough
(uncompressed, single channel) that hand-decoding is reasonable. Anything
outside that shape is refused with 422 rather than guessed at.

The 16→8 bit conversion windows to each frame's own min/max instead of dropping
the low byte; CT frames rarely span the full range and a naive shift renders
most of them nearly black. Renders are cached beside the job, so
`predictions:cleanup` disposes of them too. A 1024×1024 frame takes ~0.5s to
render and ~0.07s thereafter.

#### Chunked upload (5) - Any authenticated user

`POST /api/predictions` sends the whole archive in one request. This resumable
flow is the alternative, and the right choice for anything large:

- `POST /api/predictions/uploads` - open a session → `{ upload_id, chunk_size }`
- `PATCH /api/predictions/uploads/{id}` - append one chunk (`offset` + `chunk`)
- `GET /api/predictions/uploads/{id}` - how many bytes landed, for resuming
- `POST /api/predictions/uploads/{id}/finalize` - assemble and queue the job
- `DELETE /api/predictions/uploads/{id}` - abandon the session

Chunks must arrive in order; a gap returns **409** rather than silently
assembling a corrupt archive. Re-sending a chunk that already landed is
idempotent, so a client can retry safely. Session state lives beside the
partial file, so an upload survives a server restart. Ownership is enforced by
the storage path — another account's `upload_id` simply 404s.

**Chunk size is computed, not fixed.** `php.ini` here reads
`upload_max_filesize = 2M` / `post_max_size = 8M`, so the server derives a
chunk that actually fits (80% of the smaller limit — currently **1.6 MB**) and
returns it in the session response. The Flutter client uses whatever the server
advertises rather than hard-coding a size, so raising the ini settings is the
only change needed to speed uploads up.

> **Note on those PHP limits:** under Octane they mostly do not apply.
> RoadRunner parses the multipart body itself, so `upload_max_filesize` never
> gets a say — a 4 MB direct upload was verified to succeed against a 2 MB
> `upload_max_filesize`. The real ceiling is RoadRunner's own
> `max_request_size`, configurable in `.rr.yaml`.
>
> The chunked flow still earns its place: it resumes after a dropped
> connection, reports real progress, and keeps working if the app is ever
> deployed behind nginx + PHP-FPM, where `php.ini` *does* apply. The computed
> chunk size means it behaves correctly under either server.

#### Activity Logs (3) - Admin Only
- `GET /api/admin/activities` - List all activities with filters
- `GET /api/admin/activities/types` - Get activity types
- `GET /api/users/{id}/activities` - Get user activities

### Background Jobs
- `ProcessDeepLearningImage` - Fills frame gaps by recursive interpolation at
  t=0.5, calling the model once per generated frame
- `CheckModelsHealth` - Auto health check (scheduled every 5 minutes)

⚠️ **Predictions need a queue worker.** Without `php artisan queue:work` an
upload succeeds but the job stays `pending` forever.

### Scheduled Commands
Registered in `routes/console.php` (Laravel 12 has no `app/Console/Kernel.php`):

- `php artisan models:health-check` - Check all models health status (every 5 min)
- `php artisan tokens:cleanup` - Delete tokens older than 7 days (daily)
- `php artisan predictions:cleanup` - Enforce the 24-hour retention window on
  prediction output, and sweep abandoned uploads / orphaned download archives
  (hourly). Supports `--dry-run`.

⚠️ **These only run if a scheduler process is running.** Neither Laragon nor
Octane starts one. Without it, `models.status` in the database goes stale — it
keeps whatever value the last manual check wrote. Start one with:

```bash
npm run serve:all             # API + queue worker + scheduler, one command
```

Or individually: `npm run octane`, `npm run queue`, `npm run schedule`.

Run `php artisan models:health-check` by hand to refresh statuses on demand.

---

## 🛠️ Installation

### 1. Prerequisites
- PHP 8.2+
- Composer
- MySQL 8.x
- Node.js & npm (for Octane)

### 2. Install Dependencies
```bash
composer install
npm install
```

### 3. Environment Configuration
```bash
cp .env.example .env
php artisan key:generate
```

Configure `.env`:
```env
# Database
DB_CONNECTION=mysql
DB_HOST=127.0.0.1
DB_PORT=3306
DB_DATABASE=db_aict
DB_USERNAME=root
DB_PASSWORD=

# Server (Octane)
OCTANE_SERVER=roadrunner
CACHE_STORE=file

# Queue
QUEUE_CONNECTION=database

# Session — only the `/` welcome route uses it; the API is stateless.
SESSION_DRIVER=database
```

### 4. Database Setup
```bash
php artisan migrate
php artisan db:seed
php artisan storage:link
```

### 5. Start Server

**Production/Development (Recommended):**
```bash
npm run octane
```

Server running at: `http://127.0.0.1:8000`

**Development Alternative:**
```bash
php artisan serve
```

**Note:** Octane provides 84-86% faster response times.

---

## 🔧 Configuration

### Octane Configuration

**File:** `config/octane.php`
```php
'max_execution_time' => 300,  // 5 minutes (for long-running predictions)
'garbage' => 100,              // GC threshold
```

**Workers:** 4 workers, max 250 requests per worker

### Health Check Schedule

**File:** `routes/console.php`
```php
Schedule::command('models:health-check')->everyFiveMinutes();
Schedule::command('tokens:cleanup')->daily();
```

Requires a running `php artisan schedule:work` — see *Scheduled Commands* above.

---

## 📊 Database Structure

### Core Tables
- `users` - User accounts (admin & researcher)
- `personal_access_tokens` - API tokens (Sanctum)
- `models` - AI model registry
- `analysis_records` - Prediction jobs
- `user_activities` - Audit logs

### Queue Tables
- `jobs` - Pending queue jobs
- `job_batches` - Batch processing
- `failed_jobs` - Failed jobs log

### Cache Tables
- `cache` - Application cache
- `cache_locks` - Cache locking

### Legacy Tables
- `password_reset_tokens` - Not used (admin resets only), 0 rows
- `sessions` - Written to by the `/` welcome route, since `SESSION_DRIVER=database`.
  Not used for API auth. Safe to ignore; do **not** drop it without first
  switching `SESSION_DRIVER` to `array`.

13 tables total. The schema and the reasoning behind it are documented in
[../ARCHITECTURE.md](../ARCHITECTURE.md) §3.

---

## 👥 Default Users

### Admin Account
- **Email:** admin@brin.go.id
- **Password:** admin123
- **Role:** admin

### Sample Researcher
- **Email:** researcher@brin.go.id
- **Password:** user123
- **Role:** user

### Default Password (New Users)
- **Password:** BrinResearch2026

---

## 🧪 Testing

### API Testing
```bash
# Health check
curl http://127.0.0.1:8000/api/health

# Login
curl -X POST http://127.0.0.1:8000/api/login \
  -H "Content-Type: application/json" \
  -d '{"email":"admin@brin.go.id","password":"admin123"}'

# Get models (with token)
curl http://127.0.0.1:8000/api/admin/models \
  -H "Authorization: Bearer YOUR_TOKEN"
```

### Run Tests
```bash
php artisan test
```

**89 tests, 295 assertions, ~20s.** They run against MySQL, not sqlite: two
migrations use `ALTER TABLE ... MODIFY` and `activity_type` starts as an enum
the application long outgrew, so a sqlite suite would produce both false passes
and false failures. Create the database once:

```sql
CREATE DATABASE db_aict_test;
```

| Suite | Covers |
|---|---|
| `AuthTest` | login, logout, token revocation, single-session, audit trail |
| `AuthorizationTest` | every admin route refuses a researcher; `/me/*` is owner-scoped; `endpoint_url` never leaks |
| `PredictionPipelineTest` | recursive interpolation, worker contract, failure paths, counter release |
| `ChunkedUploadTest` | ordering, idempotency, ownership, session cleanup |
| `PredictionCleanupTest` | 24-hour retention and the temp sweeps |
| `TiffPreviewTest` (unit) | TIFF decoding, windowing, downscaling, PNG output, and the formats it must refuse |

Two things to know before adding tests:

- **Use `$this->apiAs($token)`**, never `withHeader('Authorization', ...)`.
  Laravel caches the resolved guard for the lifetime of a test method, so a
  second request skips token verification entirely -- a revoked token would keep
  answering 200 and the assertion would pass while proving nothing.
- **Call `Storage::fake('local')` in `setUp()`** if the test touches files.
  `RefreshDatabase` rolls back the database but leaves the filesystem alone.

The GPU worker is always faked. A real call costs ~20s and Kaggle quota, and
what is worth testing is our orchestration, not the model.

### Performance Testing
Benchmark figures are in [../README.md](../README.md).

---

## 📝 Common Commands

### Octane
```bash
# Start server
npm run octane

# Check status
php artisan octane:status

# Stop server
php artisan octane:stop

# Reload workers (after code changes)
php artisan octane:reload
```

### Database
```bash
# Run migrations
php artisan migrate

# Fresh migration with seed
php artisan migrate:fresh --seed

# Rollback
php artisan migrate:rollback
```

### Cache & Config
```bash
# Clear config cache
php artisan config:clear

# Clear application cache
php artisan cache:clear

# Clear route cache
php artisan route:clear
```

### Queue
```bash
# List jobs
php artisan queue:work

# Process failed jobs
php artisan queue:retry all
```

---

## 🔐 Security

### Authentication
- Laravel Sanctum for API token authentication
- Token stored in `personal_access_tokens` table
- Token expires after **7 days** (10080 minutes)
- Auto cleanup expired tokens (scheduled daily via `tokens:cleanup` command)

#### One session per account

A login while the account is already in use is **refused with HTTP 409**, so
two people cannot quietly share one set of credentials. The device already
holding the session keeps working; it is not kicked off.

"In use" means the token was exercised within the last **15 minutes**
(`AuthController::SESSION_IDLE_MINUTES`). Sanctum stamps `last_used_at` on
every authenticated request, so an app in normal use keeps its own session
alive. Anything idle past that window counts as abandoned and the new login
takes it over, clearing the stale token.

The idle window is not a detail to trim away. Without it, a force-closed app
or a dead phone would lock the account out until the token expired seven days
later — and an administrator locking themselves out that way would leave nobody
able to help.

### Authorization
- Role-based middleware (`role:admin`)
- Self-protection: Admin cannot delete/disable own account

### Rate Limiting
- Login endpoint: 5 attempts per minute per IP (`throttle:5,1`)

---

## 📄 API Documentation

Full API documentation available at: [../API.md](../API.md)

**Quick Reference:**
- Base URL: `http://127.0.0.1:8000/api`
- Authentication: Bearer token in `Authorization` header
- Content-Type: `application/json`
- All responses follow standard format:
  ```json
  {
    "success": true,
    "message": "Success message",
    "data": {}
  }
  ```

---

## 🐛 Troubleshooting

### Port 8000 Already in Use
```bash
# Windows
netstat -ano | findstr :8000
taskkill /PID <PID> /F

# Stop Octane properly
php artisan octane:stop
```

### SIGINT Error on Windows
Already patched in `vendor/laravel/octane/src/Commands/Concerns/InteractsWithServers.php`

### ⚠️ Octane cannot restart itself on Windows — read this before debugging a 404

**Symptom:** you add a route, `php artisan route:list` shows it, but the server
keeps returning 404. You run `npm run octane` again and nothing changes.

**Cause:** two Windows limitations stacking up.

1. Octane holds the booted application in memory, so a new route is invisible
   until the RoadRunner process is genuinely replaced. `octane:reload` cannot
   do it — it needs PCNTL signals.
2. `octane:start` and `octane:stop` both begin by asking
   `ServerProcessInspector::serverIsRunning()`, which reads
   `storage/logs/octane-server-state.json` and calls **`posix_kill()`** on the
   recorded PID. That function does not exist on Windows, so both commands die
   with:

   ```
   Call to undefined function Laravel\Octane\posix_kill()
     at vendor\laravel\octane\src\PosixExtension.php:14
   ```

   They crash *before* doing anything, leaving the old process running. This is
   why a restart appears to succeed but changes nothing.

**Fix — delete the state file, then start:**

```bash
# 1. Kill the running server by PID (octane:stop will not work)
netstat -ano | findstr :8000
taskkill /PID <PID> /F

# 2. Remove the stale state file, or the next start crashes on posix_kill
rm storage/logs/octane-server-state.json

# 3. Start fresh
npm run octane
```

**Verify you are on a new process** rather than trusting the restart — compare
its start time against the file you edited:

```bash
netstat -ano | findstr :8000
powershell "Get-Process -Id <PID> | Select-Object Id,StartTime"
```

Note that `php artisan route:list` runs in its own short-lived process, so it
will happily show a route the running server has never loaded. It proves the
route exists on disk, nothing more.

### Slow Response Times
- Use Octane instead of `php artisan serve`
- Check database queries (N+1 problem)
- Enable opcache in production

### Migration Errors
```bash
# Clear config cache first
php artisan config:clear
php artisan migrate
```

---

## 📚 Additional Documentation

- [../CLAUDE.md](../CLAUDE.md) - Working agreement and the traps that cost time
- [../ARCHITECTURE.md](../ARCHITECTURE.md) - Components, data flow, schema, decisions
- [../API.md](../API.md) - Complete API reference
- [../CHANGELOG.md](../CHANGELOG.md) - What changed and why

---

## 🚀 Deployment

### Production Checklist
- [ ] Set `APP_ENV=production`
- [ ] Set `APP_DEBUG=false`
- [ ] Configure proper `APP_URL`
- [ ] Use Redis for cache (`CACHE_DRIVER=redis`)
- [ ] Setup queue worker with Supervisor
- [ ] Enable opcache
- [ ] Configure database backup
- [ ] Setup monitoring (logs, errors)
- [ ] Configure CORS properly
- [ ] SSL certificate
- [ ] Rate limiting tuning

---

## 📞 Support

- **Documentation:** See `docs/` folder in root
- **Issues:** Report via project repository
- **Contact:** admin@brin.go.id

---

**Last Updated:** August 14, 2026  
**Laravel Version:** 12.66.0  
**Status:** Production Ready
