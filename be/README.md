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

### API Endpoints (104 Total, Including Health)

The count includes the unauthenticated `GET /api/health` liveness probe, declared in
`routes/web.php` (not `routes/api.php`). Laravel's own health endpoint is at
`/up`. Verify the full list at any time with `php artisan route:list --path=api`.

#### Authentication (3)
- `POST /api/login` - Login with email & password
- `POST /api/logout` - Logout (revoke token)
- `GET /api/user` - Get authenticated user info

#### Access Requests (5)
- `POST /api/access-requests` - **Public.** The landing-page Join form. Rate
  limited 5/minute, the same as login
- `GET /api/admin/access-requests` - List with status filter
- `POST /api/admin/access-requests/{id}/approve` - **Creates the user account**
  and returns the credentials once
- `POST /api/admin/access-requests/{id}/reject` - Reject with a reviewer note
- `DELETE /api/admin/access-requests/{id}` - Delete the request

Approving creates the account rather than just marking a row "approved" —
otherwise the admin still has to add the user by hand and the request becomes a
dead record. New accounts get the default password below.

#### IT Support — messaging (10)

**This replaced a ticket system.** Tickets asked a researcher with a problem to
classify it first — pick a subject, a category, a priority, then watch a status
— which is the shape of a helpdesk with a support department behind it. Here
there is one administrator, and what people want is to say "this is broken" and
get an answer. So the ceremony is gone and what is left is a conversation, one
per account, exactly like a chat.

- `POST /api/messages/public` - **Public.** From the sign-in page, for people
  who cannot get in. Throttled 5/hour
- `GET /api/messages` - The caller's own thread, with every message in it
- `POST /api/messages` - Say something. Creates the thread on first use
- `POST /api/messages/read` - The caller has seen the replies
- `GET /api/admin/conversations` - The inbox, with `unread_conversations` and
  `unread_messages` in `meta`
- `GET /api/admin/conversations/{id}` - One thread
- `POST /api/admin/conversations/{id}/reply` - Answer
- `POST /api/admin/conversations/{id}/read` - Mark it read without answering
- `PATCH /api/admin/conversations/{id}` - Archive or restore
- `DELETE /api/admin/conversations/{id}` - Delete the thread and its messages

**The researcher's routes take no id.** They have exactly one thread, so "mine"
is the only thing they could mean — which removes the entire class of bug where
one account reaches another's messages, because there is no id to tamper with.

**One thread per account, enforced by a unique index**, not by hope. Writing
again after an administrator archived a thread pulls it back into the inbox:
they filed away a conversation, not a person.

`messages.read_at` means "read by the other side". Every message has exactly one
recipient side, so one column serves both directions. Answering counts as
reading — nothing in a thread is still waiting on the administrator once they
have replied to it.

**Guest threads.** A message from `/public` has `user_id = NULL` and carries
`guest_name` + `guest_email` instead. It lands in the same inbox flagged
`is_guest`, and the admin answers by email — there is no account session to show
a reply in, and the screen says so rather than letting them type into the void.
Such a thread is deliberately **not** attached to an account whose email happens
to match: the address is unverified, so attaching it would let anyone plant
messages in another researcher's thread.

#### Notifications (6)

- `GET /api/notifications` - The caller's own, `?unread=1` to filter
- `GET /api/notifications/unread-count` - **What the client polls.** Returns
  `notifications` *and* `messages`, so the bell and the Messages badge cost one
  request between them
- `POST /api/notifications/{id}/read`
- `POST /api/notifications/read-all`
- `DELETE /api/notifications/{id}`
- `DELETE /api/notifications` - Clear the list

Laravel's own `notifications` table and `$user->notify()`, not a hand-rolled
one: sending the same event by email later becomes a one-word change to `via()`
rather than a second delivery system.

Everything is scoped through `$request->user()->notifications()`, so the
relation *is* the authorisation — another account's id 404s.

**What gets sent, and to whom** (all of it in `app/Services/Notifier.php`, one
file that answers "what does this platform ever tell people?"):

| Event | Goes to |
|---|---|
| `message.received` / `message.guest` | Every active administrator |
| `message.reply` | The researcher who asked |
| `prediction.completed` / `prediction.failed` | The job's owner |
| `prediction.expiring` | The owner, ~3h before the files are deleted |
| `access_request.submitted` | Every active administrator |
| `account.approved` | The new account |
| `model.offline` / `model.online` | Every active administrator |

Two rules hold the design together. **A notification may never break its
caller** — a prediction that finished must not be marked failed because writing
a row about it threw, so `Notifier` swallows and logs. And **model status is
notified on the transition only**: the health check runs every five minutes, so
an overnight outage would otherwise produce 288 identical notifications.

Distinct from `user_activities`, which is an audit trail: that records what
happened for an administrator to inspect afterwards; this tells one person
something they need to act on now. The same event can produce both.

#### Research News (8)

Posts shown as a slideshow on the landing page. Nothing is visible until an
administrator publishes it, so drafts can be prepared ahead of an announcement.

- `GET /api/news` - **Public.** Published posts only, in slide order
- `GET /api/news/{id}/image` - **Public for a published post.** A draft's photo
  404s unless the caller is an admin
- `GET /api/admin/news` - Everything, with `published_count` / `draft_count`
- `POST /api/admin/news` - Create
- `GET /api/admin/news/{id}` - Detail
- `POST /api/admin/news/{id}` - Update (POST, not PUT: see below)
- `PATCH /api/admin/news/{id}/toggle` - The publish switch
- `DELETE /api/admin/news/{id}` - Delete, photo included

**Update is POST, not PUT.** A photo arrives as multipart and PHP does not
populate `$_FILES` for a PUT body, so a PUT route could never receive one.

**Photos are stored byte-for-byte.** There is no GD and no Imagick here, so
nothing can resize or re-encode an upload — the whole defence is a 4 MB cap and
a `mimetypes:` rule, which reads the file's actual bytes rather than trusting
its extension. Images stream through the API instead of `public/`: there is no
`storage:link` on this machine and the app is reached over ngrok, where a
symlinked path is one more thing to get wrong.

**Saving is not publishing.** The toggle is a separate action, and
`published_at` is only stamped the first time — hiding and re-showing an old
post must not throw it to the front of a date-ordered slideshow.

#### Profile Photos (5)
- `GET /api/users/{id}/avatar` - The photo. **Authenticated**, any role
- `POST /api/me/avatar` - Set your own (multipart `avatar`)
- `DELETE /api/me/avatar` - Remove your own
- `POST /api/admin/users/{id}/avatar` - Set someone else's
- `DELETE /api/admin/users/{id}/avatar` - Remove someone else's

Serving is authenticated rather than public: avatars appear beside activity
logs and in the user list, so every signed-in account needs them, but an
anonymous visitor should not be able to harvest photos of the research staff by
walking the ids. An admin can change anyone's because somebody has to be able
to take down an inappropriate picture.

An account with no photo returns **404**, not a stock image — the client draws
an initials frame, and a server-side placeholder would be a second opinion
about what "no photo" looks like. Every payload carrying a user now carries
`avatar_url` (null when there is none); `avatar_path` and `avatar_mime` are
hidden, since where the file sits on disk is nobody's business.

#### Model Training (17)

Managed training. The platform **never trains anything** — it records what
should be trained and what came back. Three constraints force that: this
machine has no GPU and a PHP backend, the Kaggle session that does have a GPU
expires every 9–12 hours, and training takes days.

Admin (11):
- `GET|POST /api/admin/training/datasets`, `DELETE .../{id}`
- `GET|POST /api/admin/training/jobs`, `GET|DELETE .../{id}`
- `POST /api/admin/training/jobs/{id}/dispatch` — push the job to a trainer URL
- `POST /api/admin/training/jobs/{id}/cancel`
- `GET /api/admin/training/jobs/{id}/weights`
- `POST /api/admin/training/jobs/{id}/register-model`

Worker (7), under `/api/training/worker/*`: `claim`, `jobs/{id}/dataset`,
`heartbeat`, `checkpoint`, `sample`, `complete`, `fail`.

**The worker authenticates with a shared secret**, not a Sanctum token — it is
a machine, not a person, its credential lives in a notebook for weeks, and it
must reach nothing but these seven routes. Generate one with
`php artisan training:token`, put it in `TRAINING_WORKER_TOKEN`. With no token
set, every worker route answers **503**: a half-configured deployment fails
closed.

**`TRAINING_CALLBACK_URL` must be an address the GPU host can reach**, and on a
development machine it is not set, so it falls back to `APP_URL` — which is
`http://localhost` almost everywhere. `TrainerDispatcher` refuses to dispatch in
that state on purpose: without it the trainer would accept the job and then have
every callback fail silently, leaving the run at `queued` for ever with nothing
to say why.

A Tailscale address does not work here. That is a private network, and Kaggle is
not on it. Use the ngrok tunnel that already fronts the API:

```bash
TRAINING_CALLBACK_URL=https://<your-tunnel>.ngrok-free.dev
```

Then restart Octane — config is read once per process, so an edited `.env` does
nothing until it comes back (`npm run octane:reset && npm run octane`).

**Register the trainer URL with or without `/train`.** The notebook prints its
tunnel root and asks you to paste that; the inference notebook prints the full
`…/predict`. Both conventions therefore live in the registry, and
`TrainerDispatcher::trainEndpoint()` appends `/train` only when no path was
given. Before it did, a bare root produced **405 Method Not Allowed**, which
reads like the trainer refusing the job.

**A worker going quiet is not a failure.** A Kaggle session ending is the
normal course of events, so `training:reclaim` (scheduled every 5 minutes)
returns a job whose heartbeat is older than 15 minutes to `queued` **with its
checkpoint intact**, and the next worker resumes from the epoch already
reached. Without that, every expired session would strand a job forever and a
multi-day training could never finish.

**The queue moves on its own.** `training:dispatch-queued` (scheduled every
minute) sends the oldest waiting run whenever no run is in progress. Before it,
a job was dispatched exactly once — at creation — so a single failed attempt
left it at `queued` for ever, and the position shown to its owner was a promise
nothing could keep. One at a time, because the trainer holds a single GPU and
refuses a second job; `created_at` order, the same ordering the researcher is
shown, so the two can never disagree.

A run that cannot be sent records the reason on its own row rather than only in
the log, and the command still exits zero: a trainer that is down is an ordinary
state here, not something the scheduler should raise an alarm about.

**A job can be pushed as well as pulled.** `dispatch` posts the job to a URL on
the GPU host — the same shape as a prediction posted to a model endpoint — so an
administrator presses a button instead of going to start a poller. The payload
carries the callback base and worker token, so the trainer reports back through
the very same protocol; pushing changes who starts the work, not how it is
reported. That is why a pushed job still survives its session dying. A push that
fails leaves the job `queued`, so a polling worker can still take it.

**A dataset is an upload or a URL.** Uploads travel through this machine, so
they stay modest; anything large is registered as a URL the worker fetches for
itself. Sending 20 GB up a home tunnel and back down to Kaggle is the thing
that design avoids.

**Completion does not produce a usable model.** `register-model` writes a row
into `models` with the weights' path, `is_active = false` and no endpoint.
Weights are a file; a model here is a running FastAPI worker with a URL, and
nothing in this platform can deploy one to a GPU. Pretending otherwise would
only surface when a researcher's prediction failed.

#### User Management (7) - Admin Only
- `GET /api/admin/users` - List users with pagination & filters
- `POST /api/admin/users` - Create new user
- `GET /api/admin/users/{id}` - Get user detail
- `PUT /api/admin/users/{id}` - Update user
- `DELETE /api/admin/users/{id}` - Delete user
- `PATCH /api/admin/users/{id}/toggle` - Toggle active status
- `POST /api/admin/users/{id}/reset-password` - Reset to default

Disabling or resetting an account revokes all its existing tokens. Deletion
returns **409** while the account has a pending/processing prediction or a
queued/claimed/running training job. A successful deletion removes its
prediction files, kept evidence, and temporary upload/download files.

#### Model Management (9) - Admin Only
- `GET /api/admin/models` - List models
- `POST /api/admin/models` - Add new model
- `POST /api/admin/models/sync` - Sync every `/models` entry from one FastAPI server
- `GET /api/admin/models/{id}` - Get model detail
- `PUT /api/admin/models/{id}` - Update model
- `DELETE /api/admin/models/{id}` - Delete model
- `PATCH /api/admin/models/{id}/toggle` - Toggle active status
- `POST /api/admin/models/{id}/health-check` - Manual health check
- `POST /api/admin/models/{id}/test` - Test prediction

Set `AI_MODEL_SERVER_BASE_URL` once for the shared ngrok/FastAPI server. The
sync route checks `GET /`, fetches `GET /models`, and upserts by slug. Each row
stores its own `/predict/{model_name}` path; adding a model on the GPU server no
longer requires a Laravel source change.

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

#### Predictions (11) - Any authenticated user (FASE 3)
- `POST /api/predictions` - Upload a ZIP of numbered `.tif` frames for review (`uploaded`)
- `GET /api/predictions` - List the caller's own jobs, paginated
- `GET /api/predictions/{id}` - Job detail, including queue position while pending
- `DELETE /api/predictions/{id}` - Delete a job and its files
- `GET /api/predictions/{id}/frames` - What is on disk, inputs and outputs
- `POST /api/predictions/{id}/start` - Queue an uploaded job after reviewing its frames
- `POST /api/predictions/{id}/rerun` - Start a new run with the same frames and another model
- `GET /api/predictions/{id}/frames/{name}/preview` - That frame as a PNG
- `GET /api/predictions/{id}/evidence/{name}` - Kept thumbnail after frame expiry
- `GET /api/predictions/{id}/download/results` - ZIP of generated frames only
- `GET /api/predictions/{id}/download/complete` - ZIP of input + output + `metadata.json`

Every action is scoped to `auth()->user()` inside `AnalysisController`, so
these need no admin role. Downloads stream and carry `X-Checksum-MD5`.

**Upload contract.** The ZIP must hold at least two `.tif`/`.tiff` files whose
names contain frame numbers, and those numbers must leave a **gap** — the job
interpolates what is missing between them. `frame_001.tif` + `frame_005.tif`
generates 002, 003 and 004. Consecutive frames are rejected with a clear
message, as is any job that would generate more than 200 frames.
Intake also rejects frames over 50 MB, more than 1000 input frames, more than
2 GB of expanded TIFF data, and duplicate filenames after nested folders are
flattened. Disk space is checked against the expanded size before extraction.

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
- `POST /api/predictions/uploads/{id}/finalize` - assemble the archive for review (`uploaded`)
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

⚠️ **Predictions need a queue worker.** Without `php artisan queue:work`,
upload and preview still work, but a job stays `pending` after START.

⚠️ **Start it through `npm run queue`, not bare `queue:work`.** The script is

```
php -d memory_limit=1G artisan queue:work --tries=1 --timeout=7200 --memory=768
```

and both numbers matter. `--memory` does **not** raise PHP's limit — it only
decides when the worker restarts itself — so a bare `queue:work` runs at the
512 MB default. `-d memory_limit=1G` raises the real ceiling; `--memory=768`
recycles the worker before it reaches it, so a heavy job ends in a clean restart
rather than a fatal error.

**A frame is no longer what exhausts a worker, and it used to be.**
`TiffPreview` turned every pixel into a PHP array entry — twice, while
`unpack()`'s result was copied into the accumulator — so one 2048×2048 frame
cost **196 MB**, and the pair `FrameMetrics` holds at once cost **262 MB**. At
the 512 MB default the process died mid-job and took the run with it, while the
screen still read `pending` with nothing to explain it.

Pixels now live in a binary string, unpacked a block at a time: **11.7 MB** for
the same frame, **20 MB** for the pair. `MAX_PIXELS` went back up from 2048² to
**4096²**, and the measurements behind that ceiling — including why it did not
go all the way back to 8192² — are in the constant's docblock. Decoding *time*
is the limit now, not memory. Keep using `npm run queue` anyway: nothing else
about a job got smaller.

### Scheduled Commands
Registered in `routes/console.php` (Laravel 12 has no `app/Console/Kernel.php`):

- `php artisan models:health-check` - Check all models health status (every 5 min)
- `php artisan tokens:cleanup` - Delete tokens older than 7 days (daily)
- `php artisan predictions:cleanup` - Enforce the 24-hour retention window on
  prediction output, and sweep abandoned uploads / orphaned download archives
  (hourly). Supports `--dry-run`.
- `php artisan training:cleanup` - Free dataset archives nobody has come back
  to (daily, 03:10). Supports `--dry-run`, and start there: the window is
  measured from the dataset's **last use**, not from its upload, because a
  dataset is uploaded here precisely so it can be reused. One with a queued or
  running job is never swept. `TRAINING_DATASET_RETENTION_DAYS` (default 30)
  sets the window; 0 disables it. The archive and its rendered previews go;
  the row stays, stamped `archive_deleted_at`.

⚠️ **These only run if a scheduler process is running.** Neither Laragon nor
Octane starts one. Without it, `models.status` in the database goes stale — it
keeps whatever value the last manual check wrote. Start one with:

```bash
npm run serve:all             # API + queue worker + scheduler, one command
```

Or individually: `npm run octane`, `npm run queue`, `npm run schedule`.

### Storage on a mounted volume

When results live somewhere other than this machine's own disk — a NAS, an
external drive — there is one failure worth guarding against, and it is silent.
**An unmounted share is not an error.** It is an ordinary empty directory, and
`Storage::put()` writes into it without complaint: the frames land on the
host's own disk, the researcher is told the job worked, and nobody finds the
files again.

So the volume carries a file that only exists there:

```bash
# after mounting, once:
php artisan storage:mark
```

Then set `STORAGE_REQUIRE_SENTINEL=true` and run `php artisan config:cache`.

**The order matters.** Running `storage:mark` while the share is absent writes
the sentinel onto the empty mount point — which is exactly the state it exists
to detect. The command shows the volume's size before writing anything and asks
you to confirm, because that number is the check: an empty mount point reports
the host's disk, which is usually a very different size.

Two more settings, both with sensible defaults:

| Variable | Default | What it does |
|---|---|---|
| `STORAGE_HEADROOM_MULTIPLIER` | `3.0` | An archive costs disk three times over: frames extracted from it, frames generated from those, and the archive built to hand results back |
| `STORAGE_MINIMUM_FREE_BYTES` | 2 GB | A floor whatever the upload. A machine that runs to zero cannot write to MySQL, cannot record the failure, and cannot log why |

Prediction upload and direct researcher training upload answer **507** when
there is no room. Prediction intake checks the ZIP's expanded size before
extracting frames.
`GET /api/admin/storage` reports what is used and — more usefully — how much of
it retention will hand back on its own.

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
- `access_requests` - Landing-page Join submissions awaiting review
- `conversations` - One support thread per account (`user_id` is **unique**, and
  null for a thread written from the sign-in page)
- `messages` - One turn in a thread; `from_admin` is stamped at write time so
  promoting someone later does not rewrite history, and `read_at` means "read
  by the other side"
- `notifications` - Laravel's own schema. Polymorphic, so it carries **no
  foreign key** to `users` — `User::booted()` deletes them by hand, along with
  the account's tokens, avatar, prediction files, kept evidence and temporary files

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

There are **23 tables total**, counting `migrations`: 15 application tables and
8 framework tables. The authoritative schema and the reasoning behind it are
documented in [../ARCHITECTURE.md](../ARCHITECTURE.md) §3.

---

## 👥 First administrator

`php artisan db:seed` creates one account, from the environment:

```env
SEED_ADMIN_EMAIL=admin@example.org
SEED_ADMIN_PASSWORD=            # leave empty and one is generated, printed once
```

Nothing is hard-coded — this seeder runs on production too, and a password
written into a repository is a password everyone has. The sample researcher is
skipped when `APP_ENV=production`.

Production can deliberately bootstrap one researcher as well:

```env
SEED_USER_EMAIL=researcher@example.org
SEED_USER_PASSWORD=choose-a-secret
```

Both values are required together. The release workflow exposes this only
through a manual `bootstrap_users` dispatch; passwords come from repository
secrets, are not cached into Laravel configuration, and are followed by real
admin/user login smoke tests against the restarted Octane process. Ordinary
push deployments never seed or reset either account.

Accounts created afterwards (by an administrator, or by approving a landing-page
request) get `UserController::DEFAULT_PASSWORD` and **cannot reach the console
until they replace it**: `must_change_password` is set at issue and cleared only
by `POST /api/me/password`. An admin password reset arms it again.

---

## 🧪 Testing

### API Testing
```bash
# Health check
curl http://127.0.0.1:8000/api/health

# Login
curl -X POST http://127.0.0.1:8000/api/login \
  -H "Content-Type: application/json" \
  -d '{"email":"$ADMIN_EMAIL","password":"$ADMIN_PASSWORD"}'

# Get models (with token)
curl http://127.0.0.1:8000/api/admin/models \
  -H "Authorization: Bearer YOUR_TOKEN"
```

### Run Tests
```bash
php artisan test
```

**385 tests, 1,536 assertions** passed in GitHub Actions on 1 October 2026. They
run against MySQL, not sqlite: three
migrations use `ALTER TABLE ... MODIFY` and `activity_type` starts as an enum
the application long outgrew, so a sqlite suite would produce both false passes
and false failures. Create the database once:

```sql
CREATE DATABASE db_aict_test;
```

| Suite | Covers |
|---|---|
| `AuthTest` | login, logout, token revocation, concurrent sessions on several devices, audit trail |
| `AuthorizationTest` | every admin route refuses a researcher; `/me/*` is owner-scoped; `endpoint_url` never leaks |
| `AccessRequestTest` | public submission, duplicates, existing account, the approve/reject flow |
| `MessagingTest` | one thread per account, unread in both directions, archiving, guest messages |
| `NotificationTest` | who each event reaches, the unread counters, and that nobody can read another account's |
| `NewsPostTest` | the publish switch, slide order, the upload guard, a draft's photo staying private |
| `TrainingTest` | worker auth, the claim lock, resume-after-death, checkpoint rotation, registering weights |
| `AvatarTest` | own vs anyone else's, the upload guard, `avatar_url` in every payload, the 404 for no photo |
| `PredictionPipelineTest` | recursive interpolation, worker contract, failure paths, counter release, frame provenance, the hold-out measurement, re-runs, kept thumbnails |
| `ChunkedUploadTest` | ordering, idempotency, ownership, session cleanup |
| `PredictionCleanupTest` | 24-hour retention and the temp sweeps |
| `WorkerAuthTest` | the shared secret reaching the worker, never reaching a client, encrypted at rest, and surviving an unrelated edit |
| `StorageGuardTest` | refusing an upload with nowhere to put it, and noticing a results volume that is not mounted |
| `TiffPreviewTest` (unit) | TIFF decoding, windowing, downscaling, PNG output, and the formats it must refuse |
| `FrameMetricsTest` (unit) | MAE, RMSE and PSNR against numbers worked out by hand — a wrong constant here would quietly put wrong figures in a report |
| `TrainingDatasetPreviewTest` | listing an archive without extracting it, the entry-name check, and a frame inside a subfolder — the case a normal route placeholder 404s on |
| `TrainingDatasetRetentionTest` | the window measured from last use rather than upload, a dataset with live work never swept, and what the frame list says once the archive is gone |
| `QueueHealthTest` | a job available but never reserved, and that the admin wording naming a command is not the wording a researcher gets |
| `AdminQueueTest` | the board's ordering, and that a researcher's own position matches the number the admin sees on that same row |
| `SourceEncodingTest` (unit) | a tripwire, not a feature: it fails if any source file grows a mojibake sequence. UTF-8 read back as Windows-1252 corrupts text through ordinary editing, and without this it comes back |

Five things to know before adding tests. Each one produced a test that passed
while proving nothing, or failed for a reason that had nothing to do with the
application:

- **Use `$this->apiAs($token)`**, never `withHeader('Authorization', ...)`.
  Laravel caches the resolved guard for the lifetime of a test method, so a
  second request skips token verification entirely -- a revoked token would keep
  answering 200 and the assertion would pass while proving nothing.
- **Use `$this->apiAs(null)` for an anonymous request**, not a bare `get()`.
  `withHeader` writes to `$defaultHeaders`, which persists for the rest of the
  method, so a "logged out" call after a logged-in one still carries the token.
  This is why `apiAs(null)` also *removes* the header.
- **Call `Storage::fake('local')` in `setUp()`** if the test touches files.
  `RefreshDatabase` rolls back the database but leaves the filesystem alone.
- **Never hard-code a row id in a URL.** MySQL does not reset AUTO_INCREMENT
  when a transaction rolls back, so ids keep climbing across tests and
  `/access-requests/1/approve` starts 404ing part-way through a suite. Read the
  id back from the model.
- **Never run two suites at once.** They share `db_aict_test`, and
  `RefreshDatabase` starts each run with `migrate:fresh` — two runs racing that
  produce `SQLSTATE[42S01]: Table 'cache_locks' already exists` and dozens of
  unrelated-looking failures. The code is fine; the second run is the bug. This
  is easy to do by accident when one run has been backgrounded.
- **Uploading a file? `post()` with an explicit `Accept: application/json`.**
  `postJson` cannot carry a file, and a plain `post` makes Laravel answer a
  failed validation with a 302 redirect, so the failure reads as "expected 422,
  got 302". Related: `UploadedFile::fake()` reports its mime type from the
  *extension*, so it sails straight through a `mimetypes:` rule — build a real
  temp file when that rule is what you are testing. And
  `UploadedFile::fake()->image()` needs GD, which this machine does not have.

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

#### `serve:all` caches routes, and deliberately does not cache config

`preserve:all` runs `route:cache` before the three processes start. The reason
is the scheduler: `models:health-check` runs on a timer, each run is a fresh
`php artisan` process, and without the cache every one of them recompiles the
whole route table first. Measured on this machine, one run went from
**~2400 ms to ~700 ms**.

That measurement is also why the cadence is now once a minute rather than every
ten seconds: six runs a minute at 600 ms each is about 6% of a core, for ever.
Freshness at the moment it matters comes from `POST /api/me/models/refresh`
instead, which the upload screen's refresh button calls.

**`config:cache` is not in there, and adding it will eventually cost someone
their development database.** With `bootstrap/cache/config.php` present, the
`<env>` entries in `phpunit.xml` no longer reach the config — including
`DB_DATABASE=db_aict_test`. `php artisan test` then runs `RefreshDatabase`
against `db_aict`, the database you actually work in, and wipes it.

It is worth about 100 ms more per run. That is not worth the trap on a
development machine. **On the VPS it belongs in the deploy step**, where the
test suite never runs:

```bash
php artisan config:cache && php artisan route:cache
```

Either cache goes stale on its own: re-run the command after editing `.env`,
`config/*` or `routes/*`, or clear it.

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
- `account.access` checks active status on every authenticated request. An
  account with an issued password can only read `/api/user`, change its
  password, or log out until that password is replaced

#### Concurrent sessions

Several devices may hold sessions for the same account at once. Each login
mints its own token and leaves the others untouched; logging out revokes only
the token that made the request.

Expiry is handled centrally rather than per-login: tokens are valid for 7 days
(`config/sanctum.php` → `'expiration' => 10080`) and `tokens:cleanup` removes
the expired rows daily.

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
- [../WHITE_BOX_TESTING.md](../WHITE_BOX_TESTING.md) - Repeatable internal test scenarios and observed CI evidence
- [../USER_ACCEPTANCE_TESTING.md](../USER_ACCEPTANCE_TESTING.md) - Production API and web acceptance scenarios

---

## 🚀 Deployment

### Production Checklist
- [x] Set `APP_ENV=production`
- [x] Set `APP_DEBUG=false`
- [ ] Configure the final public `APP_URL`
- [ ] Use Redis for cache (`CACHE_DRIVER=redis`)
- [x] Run API, queue worker and scheduler through PM2 (`deepct-app`)
- [x] Run the port-8000 ngrok tunnel through PM2 (`deepct-ngrok`)
- [x] Enable `pm2-jihyo.service` and save the process list for reboot recovery
- [x] Bootstrap and verify administrator/researcher login from repository secrets
- [x] Deploy the prebuilt web client to the new Vercel project
- [ ] Enable opcache
- [x] Create a rotating database dump before every migration
- [ ] Copy backups off the Raspberry Pi
- [ ] Setup monitoring (logs, errors)
- [ ] Configure CORS properly
- [x] HTTPS through the reserved ngrok tunnel
- [ ] Rate limiting tuning

---

## 📞 Support

- **Documentation:** See `docs/` folder in root
- **Issues:** Report via project repository
- **Contact:** admin@brin.go.id

---

**Last Updated:** October 1, 2026  
**Laravel Version:** 12.66.0  
**Status:** Deployed on Raspberry Pi; model catalogue sync and real-worker acceptance remain open
