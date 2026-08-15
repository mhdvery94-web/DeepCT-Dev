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
- `flutter build apk --release` → `app-release.apk`, 51.0 MB
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
- Default password changed to "BrinResearch2026"
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
