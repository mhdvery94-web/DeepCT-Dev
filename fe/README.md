# 🔬 Frontend - Platform Analisis Citra Neutron CT

> Kontrak aplikasi diperbarui 9 Oktober 2026: khusus prediksi; managed training telah dihapus.
> Status dan langkah kelanjutan agen: [checkpoint](../handoff.md).

## Prediction-only client — 9 October 2026

Both roles retain inference models and prediction upload/history. Training
models, services, handoff widgets and related tests have been removed. Upload
resume now stores only the existing prediction slot; storage reporting omits
retired datasets. The default API points at the Raspberry Pi reserved tunnel;
deployment can override it using `API_BASE_URL`.

Flutter validation runs in GitHub Actions because the local host has no Flutter
SDK. Historical test totals below remain dated observations; current workflow
results are recorded in the root checkpoint after verification.

Flutter application untuk platform analisis citra Neutron CT. Mendukung **Web** dan **Android**.

---

## 🚀 Tech Stack

- **Framework:** Flutter (Dart)
- **State Management:** Provider
- **HTTP Client:** Dio
- **Storage:** flutter_secure_storage
- **Platforms:** Web, Android

---

## 📦 Features

### Admin Dashboard
- ✅ **User Management**
  - List, create, edit, delete users
  - Toggle user active/inactive status
  - Reset user password to default
  - Search & filter by role/status
  - Self-protection: Cannot delete/disable own account

- ✅ **Model Management**
  - View deployed models in card grid
  - Model status indicator (online/offline/trouble)
  - Health check with response time
  - Test prediction
  - Toggle model active status
  - Update model endpoint URL

- ✅ **Dashboard Home**
  - User / model / today's-activity counters
  - Status breakdown (active-inactive, online-offline-trouble)
  - 10 most recent activities, with a jump to the full log

- ✅ **Activity Logs**
  - View all user activities
  - Filter by user, type, date range
  - Timeline view with icons
  - Metadata detail view
  - Export the filtered page to CSV (browser download on web; saved to
    `Android/data/<package>/files/Download` on Android)

- ✅ **Access Requests**
  - Landing-page Join submissions, filtered by status
  - Approving **creates the account** and shows the credentials once
  - Reject with a reviewer note, or delete

- ✅ **Messages** (replaced the ticket screens)
  - An inbox of conversations, newest first, filterable to unread or archived
  - Read ticks, unread counts, archive and delete
  - Sidebar carries a **count of conversations waiting on a reply**
  - A guest thread (written from the sign-in page) is flagged, and the screen
    says to answer by email — there is no account to show a reply in

- ✅ **Notifications**
  - A bell in the header with an unread badge, on both consoles
  - New messages, access requests and model outages for an administrator;
    finished and failed jobs, replies and expiring results for a researcher
  - Tapping one navigates to what it is about
  - Polls every 45s, and the same request feeds the Messages badge

- ✅ **Research News**
  - Write a post, attach a photo (JPEG/PNG/WebP, ≤4 MB), set its slide order
  - **Publish switch is separate from save**, so a draft is never put on the
    public site by accident
  - Filter by published/draft; drafts show their photo to an admin only

- ✅ **Profile photos**
  - Change or remove your own from the sidebar avatar
  - An admin can set or clear anyone's from the user list
  - Accounts with no photo show an **initials frame**, not a placeholder

### Researcher Console (`UserShell`)
- ✅ **Dashboard** — model availability, own analysis counters, activity today,
  and the 5 most recent actions
- ✅ **New Analysis** — pick a model and ZIP or numbered TIFF frames, upload
  with live progress, preview the uploaded frames, then explicitly start analysis
- ✅ **Results & History** — job status with polling, dual download, delete.
  A completed run also shows what it scored: a frame the archive already held
  was set aside, regenerated, and measured against the real one. Where the same
  frames were run through more than one model, their errors sit side by side
- ✅ **Frame gallery** — every frame, input and output, with generated ones
  badged `AI` and `AI G2` upward. The second badge is the point: a frame drawn
  between two scanned neighbours and a frame drawn against one the model had
  just invented are not the same evidence
- ✅ **Kept thumbnails** — a run stays something you can look at after its
  frames are deleted, rather than a row saying it once completed
- ✅ **My Activity** — full paginated audit trail of the signed-in account
- ✅ **Messages** — one conversation with the administrators. Nothing to
  classify first: type the problem and send it
- ✅ **Notifications** — the same bell, carrying finished jobs, failures,
  replies and an expiry warning before results are deleted

### Admin additions
- ✅ **Storage panel** on the dashboard — free space, and the breakdown that
  actually decides whether a full volume is a problem: prediction output comes
  back within a day; retained evidence remains. Shouts when the results volume
  is not mounted, because nothing else in the system reports that
- ✅ **Worker credentials** in the model form — a shared secret sent to the
  worker as `Authorization: Bearer`, write-only (typing a new one replaces it;
  blank leaves it alone), plus a per-model TLS verification switch

### Public Landing Page
- ✅ **Join form** — wired to `POST /api/access-requests`, with the server's own
  message shown on a duplicate or existing account
- ✅ **IT Support** — from the sign-in page and the footer, for people who
  cannot sign in; the reply comes by email
- ✅ **Research news slideshow** — auto-advancing every 7s, arrows on pointer
  devices, swipe on a phone. Renders **nothing** when the feed is empty or the
  request fails: a visitor must not meet an error box over something optional

Backed by `/api/me/*`, `/api/predictions/*` and `/api/support/*`; everything
under `/api/admin` requires the admin role and is unreachable from this console.

**Upload transport is automatic.** `PredictionService.upload()` sends archives
under 1 MB in a single request and switches to the resumable chunked flow above
that. The chunk size is whatever the server advertises in the session response,
never hard-coded, so the client adapts to the server's PHP/RoadRunner limits.
On native platforms, prediction ZIPs are read from disk by range for hashing,
upload and resume. Web file picking and bundles made from loose TIFFs still
hold the source bytes in memory.

**Polling, not push.** `PredictionHistoryScreen` refreshes every 10s *only*
while a job is pending or processing, and cancels the timer once everything has
settled. A failed background refresh leaves the existing list on screen rather
than blanking it.

**Downloads are checksum-verified.** Every archive arrives with an
`X-Checksum-MD5` header, which the client requires and recomputes locally.
Native downloads stream into a temporary file and are renamed only after the
checksum matches; the browser buffers Blob chunks until verification and then
starts its download. A mismatch is surfaced without saving a corrupt ZIP.

**Interrupted uploads can be continued.** A failing chunk is retried three
times, re-reading the server's `received` first — a request that timed out may
well have landed, and re-sending from a stale offset earns a 409. If the upload
dies anyway, the session is remembered on the device and the screen offers to
continue it: the bytes are gone (an archive is tens of megabytes, and on web
there is no path to re-read), so the user picks the same file again and an MD5
check proves it is the same one.

### Shared Features
- ✅ Responsive design (mobile, tablet, desktop) — covered by layout tests at
  360x640, 390x844, 759x900, 760x900, 768x1024, 1280x720 and 1440x1024
- ✅ Authentication with a Laravel Sanctum bearer token
- ✅ Secure token storage
- ✅ Role-based routing
- ✅ Error handling with user-friendly messages
- ✅ Loading states
- ✅ Pagination
- ✅ Search & filter

---

## 🛠️ Installation

### Prerequisites
- Flutter SDK 3.0+
- Dart SDK 3.0+
- Android Studio / VS Code
- Chrome (for web development)

### Setup

1. **Install Dependencies**
```bash
flutter pub get
```

2. **Configure API Endpoint**

`lib/config/api_config.dart` still carries a development fallback. Production
does **not** use that fallback: GitHub Actions compiles
`RASPI_API_BASE_URL=https://zestfully-usable-pledge.ngrok-free.dev/api` into all
release clients.

```dart
static const String baseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'https://nucleus-drone-grueling.ngrok-free.dev/api',
);
```

The source fallback is the model-worker tunnel and must not be confused with
the Raspberry Pi API tunnel. It remains a roadmap item because a manual build
without `--dart-define` can still point at the wrong service.

A custom address `https://api.brin.fajrianhost.my.id/api` was the intended
default for a while and had to be reverted because the subdomain has no DNS
record. Production therefore uses the verified Pi ngrok address through the
workflow override until a custom API domain is provisioned.

Point it somewhere else per build — **no file edit needed**:

```bash
# Android emulator → host machine
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000/api

# Real device on the same Wi-Fi as the backend
flutter build apk --dart-define=API_BASE_URL=http://192.168.1.10:8000/api

# Web against a local backend
flutter run -d chrome --dart-define=API_BASE_URL=http://127.0.0.1:8000/api
```

Plain-HTTP overrides only work on Android, where the manifest sets
`android:usesCleartextTraffic="true"`.

**If every request fails:** the backend is unreachable. Confirm it directly
with `curl <API_BASE_URL>/health` — that endpoint needs no token, so a failure
there is the network or the server, never authentication.

3. **Run Application**

**Web:**
```bash
flutter run -d chrome
```

`flutter run` binds the dev server to a **random free port** on every launch —
that is what `http://localhost:PORT/` in the terminal output actually is. It is
not a stable app URL: stop and restart `flutter run` (or let it crash) and the
next session gets a different port. Reopening the old tab/bookmark then just
hangs trying to reach a port nothing is listening on anymore, which looks like
the landing page stuck loading forever but is really "wrong address." Pin the
port if you want the same URL to survive restarts:

```bash
flutter run -d chrome --web-port=57193
```

**Android (Emulator):**
```bash
flutter run
```

**Android (Release APK):**
```bash
flutter build apk --release
```

---

## 📁 Project Structure

```
lib/
├── config/
│   └── api_config.dart           # API base URL, a build-time constant
│
├── models/
│   ├── user_model.dart           # UserModel
│   ├── model_info.dart           # ModelInfo (AI model registry entry)
│   ├── model_status_message.dart # What a researcher is told when a model is unusable
│   ├── activity_log.dart         # ActivityLog
│   ├── me_stats.dart             # MeStats (researcher dashboard counters)
│   ├── prediction.dart           # Prediction (one interpolation job)
│   ├── prediction_frame.dart     # One frame of a prediction, with its provenance
│   ├── storage_report.dart       # Room left on the results volume
│   ├── access_request.dart       # An account request from the landing page
│   ├── chat_message.dart         # Conversation + ChatMessage
│   ├── app_notification.dart     # AppNotification
│   ├── news_post.dart            # NewsPost (research news)
│   └── pagination.dart           # Pagination + PaginatedResult<T>
│
├── services/
│   ├── api_client.dart           # Dio HTTP client wrapper (ApiClient.instance)
│   ├── auth_service.dart         # Authentication
│   ├── auth_provider.dart        # ChangeNotifier holding the signed-in user
│   ├── secure_store.dart         # Token storage a broken keystore cannot kill the app with
│   ├── avatar_service.dart       # Profile photos + AvatarCache
│   ├── authed_image_cache.dart   # Bytes of images behind the authenticated API
│   ├── admin_user_service.dart   # User management API
│   ├── admin_model_service.dart  # Model management API
│   ├── admin_queue_service.dart  # The administrator's queue board
│   ├── activity_service.dart     # Activity logs API
│   ├── me_service.dart           # /api/me, the only non-admin data
│   ├── access_request_service.dart # Join form + admin review
│   ├── message_service.dart      # Thread, inbox, public channel
│   ├── notification_service.dart # The bell
│   ├── news_service.dart         # Public feed + admin CRUD
│   ├── prediction_service.dart   # Upload, list, download
│   └── upload_resume_store.dart  # What an unfinished upload was going to become
│
├── screens/
│   ├── landing/
│   │   └── landing_page.dart     # Public landing page
│   ├── auth/
│   │   ├── login_page.dart
│   │   └── password_gate.dart    # Blocks the console until an issued password is replaced
│   ├── admin/
│   │   ├── admin_shell.dart              # Admin layout with sidebar
│   │   ├── dashboard_home_screen.dart    # Stats + recent activities
│   │   ├── user_management_screen.dart
│   │   ├── model_management_screen.dart
│   │   ├── queue_monitor_screen.dart     # Who the model is working for, and who is behind them
│   │   ├── access_requests_screen.dart
│   │   ├── news_management_screen.dart
│   │   └── activity_logs_screen.dart
│   ├── messages/
│   │   ├── message_thread_screen.dart       # The researcher's one thread
│   │   ├── admin_inbox_screen.dart          # Every conversation
│   │   ├── admin_conversation_screen.dart   # One of them
│   │   └── public_message_sheet.dart        # From the sign-in page, no token
│   └── user/
│       ├── user_shell.dart                  # Researcher layout with sidebar
│       ├── user_home_screen.dart            # Stats + recent activity
│       ├── upload_screen.dart               # Start a new analysis
│       ├── prediction_history_screen.dart   # Job status, polling, download
│       ├── frame_gallery_screen.dart        # Frame previews for one job
│       ├── user_activity_screen.dart        # Full paginated activity log
│       └── user_activity_tile.dart          # Shared row widget
│
├── widgets/
│   ├── app_dialog.dart           # The one way this app opens a dialog
│   ├── status_badge.dart         # Status chip
│   ├── pagination_bar.dart       # Pagination controls
│   ├── async_state_views.dart    # LoadingView / ErrorView / EmptyView
│   ├── user_avatar.dart          # Photo or initials frame + AvatarButton
│   ├── avatar_editor_sheet.dart  # Change/remove a photo
│   ├── change_password_dialog.dart # Serves both consoles
│   ├── authed_image.dart         # An API image loaded with the caller's bearer token
│   ├── frame_stack_viewer.dart   # Scrub through a stack of frames the way ImageJ does
│   ├── model_status_strip.dart   # Live availability of the deep-learning workers
│   ├── storage_panel.dart        # Free space on the results volume
│   ├── register_model_form.dart  # Turn a run's weights into a model version
│   ├── message_bubbles.dart      # Bubble list + composer, both sides
│   ├── notification_bell.dart    # Bell, badge and panel
│   ├── news_section.dart         # Landing-page research news: one featured, then the rest
│   ├── news_article_view.dart    # Opens one post in full
│   └── news_video_player.dart    # Only where `video_player` has an implementation
│
├── utils/
│   ├── archive_source.dart       # Where an upload's bytes come from, a range at a time
│   ├── file_archive.dart         # Conditional export (web vs native)
│   ├── file_archive_io.dart      # Ranges read off disk; only the current chunk is resident
│   ├── file_archive_web.dart     # BytesArchiveSource — no file handle exists on the web
│   ├── file_download.dart        # Conditional export (web vs native)
│   ├── file_download_web.dart    # package:web browser download
│   ├── file_download_io.dart     # dart:io + path_provider file write
│   ├── blob_url.dart / _io / _web # Bytes in memory → a URL a `<video>` can play
│   ├── file_extension.dart       # hasExtension — the check file_picker cannot do portably
│   └── frame_bundle.dart         # Wrap loose `.tif` frames into the ZIP the upload path expects
│
├── theme/
│   └── app_theme.dart            # Colors & typography
│
└── main.dart                     # App entry point
```

**Service conventions.** Every API service is instantiated (`AdminUserService()`),
not static, and every list endpoint returns `PaginatedResult<T>` — use
`.items` for the rows and `.pagination.total` for the server-side count.

---

## 🎨 Design System

Defined in `lib/theme/app_theme.dart`.

### Colors
```dart
// Primary — BRIN red
static const Color primary   = Color(0xFFB91C1C);
static const Color primaryDark = Color(0xFF7F1D1D);

// Neutrals
static const Color background  = Color(0xFFF8FAFC);
static const Color surface     = Color(0xFFFFFFFF);
static const Color textPrimary = Color(0xFF0F172A);
static const Color textMuted   = Color(0xFF64748B);
static const Color border      = Color(0xFFE2E8F0);

// Status
static const Color success = Color(0xFF059669);
static const Color warning = Color(0xFFF59E0B);
static const Color error   = Color(0xFFDC2626);
static const Color accent  = Color(0xFF0369A1); // Academic blue
```

### Shape
Square corners throughout — use `BorderRadius.zero` / `Border.all(...)`, never
rounded cards. Use `color.withValues(alpha: …)`, not the deprecated
`withOpacity`.

### Typography
Google Fonts: **IBM Plex Sans** (UI) and **Lora** (display headings).

### Responsive Breakpoints
- **Mobile:** < 600px
- **Tablet:** 600px - 1000px
- **Desktop:** > 1000px

---

## 🔐 Authentication Flow

1. User enters email & password
2. Frontend sends `POST /api/login`
3. Backend validates & returns token
4. Token stored in **flutter_secure_storage**
5. Token included in all subsequent requests via `Authorization: Bearer {token}`
6. On logout, token deleted from storage & revoked on backend

**Token Security:**
- Stored in secure storage (encrypted)
- Automatically included in API requests
- No manual token management needed

---

## 🧪 Testing

### Manual Testing

**Admin Credentials:**
- Email: `admin@brin.go.id`
- Password: whatever the backend seeder printed

**Test Flow:**
1. Login as admin
2. Navigate to User Management
3. Create/Edit/Delete test user
4. Navigate to Model Management
5. Run health check
6. View activity logs

### Contract Testing

See [../API.md](../API.md) for the endpoint reference.

---

## 📝 Common Tasks

### Change API URL

Edit `lib/config/api_config.dart`:
```dart
static const String baseUrl = 'YOUR_API_URL/api';
```

### Add New Screen

1. Create file in `lib/screens/`
2. Add route in navigation
3. Update sidebar (if admin)

### Add New API Endpoint

1. Create/update service in `lib/services/`
2. Add method with Dio call
3. Handle response/error
4. Use in screen

### Handle New Error Type

Update `lib/services/api_client.dart`:
```dart
String _translateError(DioException e) {
  // Add new error handling
}
```

---

## 🐛 Troubleshooting

### API Connection Error

**Web (CORS):**
- Check backend CORS configuration
- Ensure `Access-Control-Allow-Origin` is set

**Android Emulator:**
- Use `http://10.0.2.2:8000` instead of `localhost`

**Real Device:**
- Backend and device must be on same network
- Use PC's local IP address

### Token Expired

Tokens expire after **7 days** (`config/sanctum.php` → `'expiration' => 10080`),
and the backend enforces **one active session per account** — logging in
elsewhere revokes this device's token immediately. In both cases:
- The API returns 401 Unauthorized
- `ApiClient` surfaces "Your session has expired. Please sign in again."
- Sign in again to get a fresh token

### Build Errors

```bash
# Clean project
flutter clean
flutter pub get

# Rebuild
flutter run
```

---

## 📱 Platform-Specific Notes

### Web
- Use Chrome DevTools for responsive testing
- CORS must be configured on backend
- `flutter build web --release` works. `--wasm` does **not**:
  `flutter_secure_storage_web` still imports `dart:html`, `dart:js_util` and
  `package:js`, which WebAssembly does not support. Upgrading
  `flutter_secure_storage` would be needed first.

### Android
- Min / target / compile SDK: inherited from the Flutter toolchain
  (`android/app/build.gradle.kts` uses `flutter.minSdkVersion` etc.)
- Uses Material Design 3
- `android:usesCleartextTraffic="true"` is set, so plain-HTTP backends work
- `applicationId` is **`id.go.brin.neutronct`** — reverse-DNS of the institution
  that owns the app. Changing it after a release installs a second copy
  alongside the first rather than updating it, which is why it was settled
  before distribution. The iOS/macOS/Linux/Windows scaffolds were renamed at the
  same time so the same trap is not waiting there.
- CSV exports land in `Android/data/<applicationId>/files/Download`
- APK size: **~53 MB** for the universal release APK. Use
  `flutter build apk --split-per-abi` to cut this to roughly a third per
  device architecture.

### iOS
- The iOS project is configured and CI builds an unsigned release on macOS.
- Installing it on a device or distributing it requires signing with an Apple
  Developer certificate and provisioning profile.

---

## 🚀 Deployment

### Web Deployment

```bash
# Build for production
flutter build web --release \
  --dart-define=API_BASE_URL=https://zestfully-usable-pledge.ngrok-free.dev/api

# Output: build/web/
```

The live site is `https://deep-ct-ai-prod.vercel.app`. Vercel does not run this
command itself: GitHub Actions uploads the already-built `web-dist` artifact,
forms `.vercel/output`, and calls `vercel deploy --prebuilt`. The project Root
Directory is `./`; root `vercel.json` disables Vercel's automatic Git build so
it cannot mistake the Laravel/Vite files for the web product.

### Android Release

```bash
# Generate APK
flutter build apk --release

# Output: build/app/outputs/flutter-apk/app-deepCT-ai.apk

# Generate App Bundle (for Play Store)
flutter build appbundle --release
```

**Note:** For production, configure signing keys.

---

## 📚 Additional Documentation

- [../CLAUDE.md](../CLAUDE.md) - Working agreement and the traps that cost time
- [../API.md](../API.md) - Backend API reference
- [../DESIGN.md](../DESIGN.md) - Design system & UI guidelines
- [../WHITE_BOX_TESTING.md](../WHITE_BOX_TESTING.md) - Unit/widget and release-build scenarios
- [../USER_ACCEPTANCE_TESTING.md](../USER_ACCEPTANCE_TESTING.md) - Production web acceptance scenarios

---

## 🎯 Development Status

### Completed (FASE 2)
- ✅ Project setup & dependencies
- ✅ API client with Dio
- ✅ Authentication service
- ✅ Landing page
- ✅ Login page
- ✅ Admin dashboard layout
- ✅ Dashboard home (stats + recent activities)
- ✅ User management screen (full CRUD)
- ✅ Model management screen
- ✅ Activity logs screen (+ CSV export)
- ✅ Error handling
- ✅ `flutter analyze` — 0 issues
- ✅ `flutter test` — passing (276 tests as of 1 October 2026)
- ✅ Landing page made responsive (was a fixed desktop layout)
- ✅ Status bar no longer covered on Android

### Completed (FASE 3)
- ✅ Researcher console shell with sidebar/drawer
- ✅ Dashboard, upload (direct + chunked), results & history with polling
- ✅ Frame gallery with server-rendered PNG previews
- ✅ Checksum-verified downloads on web and native platforms

### Completed since
- ✅ Join form wired to `POST /api/access-requests` + admin review screen
- ✅ IT support tickets, in-app for signed-in users and public from the
  sign-in page
- ✅ Research news: admin editor with photo upload and a publish switch, shown
  in the landing page's Research section as one featured post plus the rest

- ✅ Admin queue board and storage panel
- ✅ Native prediction ZIP uploads read a range at a time, so a
  512 MB archive does not sit in the Dart heap; web and loose TIFF bundles
  still hold source bytes in memory

### Testing
The suite is **276 tests across 33 files**, and `flutter analyze` is clean.
Both were last run on 1 October 2026 in release run `36853332173`; web,
Android, Linux and unsigned Apple builds also completed successfully.

The file was Flutter's counter-app scaffold until 15 August 2026, and it
*failed*. The "23/23 contract tests" quoted in older notes were a manual `curl`
checklist, not a runnable suite — if you find that number anywhere, it is not
evidence of anything.

| File | Covers |
|---|---|
| `widget_test.dart` | The landing page: a boot smoke test, a layout check at seven viewports that fails if any section overflows, a status-bar clearance check, and header navigation |
| `user_console_test.dart` | `MeStats` payload parsing and `UserActivityTile` rendering |
| `shell_navigation_test.dart` | Moving between tabs by swipe, and that leaving mid-work asks first |
| `messaging_test.dart` / `message_delivery_test.dart` | Thread payloads, which side a bubble sits on, read ticks, and the composer putting your text back when a send fails |
| `notification_test.dart` | The payload, the icon/colour fallback for a type the client has never seen, and the bell's badge |
| `avatar_test.dart` | The initials fallback (two-part names, one-word names, an empty name) and `UserModel`'s photo field |
| `news_test.dart` / `news_video_test.dart` | The news payload, the section's behaviour on an empty *or* failed feed, and a post's video not being hidden |
| `upload_resume_test.dart` | The interrupted-upload record and its store |
| `archive_source_test.dart` | That a large archive is walked a range at a time and never pulled into the heap whole |
| `frame_bundle_test.dart` / `file_extension_test.dart` | Zipping loose frames, and the extension check `file_picker` cannot do portably |
| `frame_provenance_test.dart` / `frame_stack_viewer_test.dart` | How a frame says where it came from, and scrubbing a stack |
| `model_status_test.dart` / `model_status_message_test.dart` / `upload_model_picker_test.dart` | Live worker availability, the wording a researcher gets when a model is unusable, and picking one |
| `queue_monitor_screen_test.dart` / `storage_panel_test.dart` / `recent_activity_scroll_test.dart` | The admin panels |
| `worker_auth_test.dart` | The per-model secret never reaching a client — including MySQL's integer booleans being read correctly |
| `password_gate_test.dart` / `secure_store_test.dart` / `login_failure_message_test.dart` | Getting in, staying in, and being told why when you cannot |
| `authed_image_cache_test.dart` / `selectable_text_test.dart` | Images behind a bearer token, and text a user can actually copy |
| `source_encoding_test.dart` | A tripwire, not a feature. It fails if any file under `lib/` or `test/` grows a mojibake sequence — UTF-8 read back as Windows-1252 corrupts text through ordinary editing, and it reached production text (`by Administrator • 4d ago` on the admin dashboard) before anyone noticed. Its twin guards the backend |

**A layout test earns its place.** The phone-width check on `PublicTicketSheet`
caught a real 54px overflow: `DropdownButtonFormField` sizes itself to its
longest option rather than the space it is given, so "prediction" pushed the row
off the edge. Pass `isExpanded: true` on every dropdown in a constrained row.

**A memory test has to be able to fail.** `archive_source_test.dart` asserts
that walking a large file does not pull it into memory, and it passed against a
deliberately wrong whole-file-read implementation — because the fixture helper
had already allocated 64 MB building the file. Writing the fixture 1 MB at a
time made the wrong implementation grow RSS by 167 MB and fail, which is what
the test was for.

```bash
flutter test
```

### Responsive breakpoints

| Constant | Width | What changes |
|---|---|---|
| `_desktopBreakpoint` (landing) / `_mobileBreakpoint` (admin shell) | **1000px** | Two-column sections stack; the admin sidebar becomes a drawer |
| `_navBreakpoint` (landing) | **760px** | The header's inline tabs collapse into a hamburger that opens a drawer |
| `_mobileBreakpoint` (landing) | **600px** | Section gutters tighten from 40/96px to 20/56px |

The nav breakpoint is deliberately lower than the layout one: the four tabs plus
the login button still fit at 760px, and collapsing them at 1000px hid the
navigation on ordinary laptop windows. Both boundaries (760px and 759px) are
covered by layout tests.

### Status bar / safe area

`LandingPage`, `LoginPage` and the wide `AdminShell` layout draw without an
`AppBar`, so nothing reserves room for the system status bar and content
rendered underneath the clock and battery icons on Android. All three now wrap
their body in `SafeArea`, and `main()` sets a transparent status bar with dark
icons to suit the light theme. A test asserts the landing header starts below a
simulated 44px inset.

**When adding a screen without an `AppBar`, wrap its body in `SafeArea`.**
Scaffold only applies the inset automatically when an `AppBar` is present.

### Planned
- ⏳ Real-time status updates (polling today — see ARCHITECTURE.md §4)
- ⏳ Push notifications
- ⏳ Dark mode

Image viewing and download progress are done: `FrameGalleryScreen` renders
server-side previews, and both upload and download report progress.

---

## 📞 Support

- **Documentation:** Root project documentation
- **Issues:** Report via project repository
- **Contact:** admin@brin.go.id

---

**Last Updated:** 1 October 2026  
**Flutter Version:** 3.44+  
**Status:** Active development. `flutter analyze` clean, 276 tests passing.
