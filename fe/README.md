# 🔬 Frontend - Platform Analisis Citra Neutron CT

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

- ✅ **Support Tickets**
  - Every ticket, filterable by status or "needs reply"
  - Reply in the conversation, change status and priority, delete
  - Sidebar shows a **count of tickets waiting on an administrator**, refreshed
    on each navigation rather than polled
  - A guest ticket (raised from the sign-in page) is flagged, and the screen
    says to answer by email — there is no account to show a reply in

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
- ✅ **New Analysis** — pick a model, pick a ZIP, upload with live progress
- ✅ **Results & History** — job status with polling, dual download, delete
- ✅ **My Activity** — full paginated audit trail of the signed-in account
- ✅ **IT Support** — raise a ticket and talk to an administrator in the app

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

**Polling, not push.** `PredictionHistoryScreen` refreshes every 10s *only*
while a job is pending or processing, and cancels the timer once everything has
settled. A failed background refresh leaves the existing list on screen rather
than blanking it.

**Downloads are checksum-verified.** Every archive arrives with an
`X-Checksum-MD5` header, which the client recomputes locally; a mismatch is
surfaced to the user rather than silently saving a corrupt ZIP.

### Shared Features
- ✅ Responsive design (mobile, tablet, desktop) — covered by layout tests at
  360x640, 390x844, 759x900, 760x900, 768x1024, 1280x720 and 1440x1024
- ✅ Authentication with JWT token
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

The default in `lib/config/api_config.dart` is the reserved ngrok domain that
fronts the local Octane server:

```dart
static const String baseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'https://nucleus-drone-grueling.ngrok-free.dev/api',
);
```

It is a *reserved* ngrok domain, so it survives tunnel restarts and works
unchanged for web and for a real Android device on any network. Point it
somewhere else per build — **no file edit needed**:

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

**If every request fails:** the ngrok tunnel is probably down. Start it with
`ngrok http 8000` on the backend machine and confirm with
`curl https://nucleus-drone-grueling.ngrok-free.dev/api/health`.

3. **Run Application**

**Web:**
```bash
flutter run -d chrome
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
│   └── api_config.dart          # API base URL configuration
│
├── models/
│   ├── user_model.dart          # UserModel
│   ├── model_info.dart          # ModelInfo (AI model registry entry)
│   ├── activity_log.dart        # ActivityLog
│   ├── me_stats.dart            # MeStats (researcher dashboard counters)
│   ├── prediction.dart          # Prediction (one interpolation job)
│   ├── support_ticket.dart      # SupportTicket + SupportMessage
│   ├── news_post.dart           # NewsPost (research news)
│   └── pagination.dart          # Pagination + PaginatedResult<T>
│
├── services/
│   ├── api_client.dart          # Dio HTTP client wrapper (ApiClient.instance)
│   ├── avatar_service.dart      # Profile photos + AvatarCache
│   ├── auth_service.dart        # Authentication service
│   ├── auth_provider.dart       # ChangeNotifier holding the signed-in user
│   ├── admin_user_service.dart  # AdminUserService  — user management API
│   ├── admin_model_service.dart # AdminModelService — model management API
│   ├── activity_service.dart    # ActivityService   — activity logs API
│   ├── me_service.dart          # MeService — /api/me, the only non-admin data
│   ├── access_request_service.dart # Join form + admin review
│   ├── support_service.dart     # SupportService — tickets, both sides
│   ├── news_service.dart        # NewsService — public feed + admin CRUD
│   └── prediction_service.dart  # PredictionService — upload, list, download
│
├── screens/
│   ├── landing/
│   │   └── landing_page.dart    # Public landing page
│   ├── auth/
│   │   └── login_page.dart      # Login screen
│   ├── admin/
│   │   ├── admin_shell.dart             # Admin layout with sidebar
│   │   ├── dashboard_home_screen.dart   # Stats + recent activities
│   │   ├── user_management_screen.dart
│   │   ├── model_management_screen.dart
│   │   ├── access_requests_screen.dart
│   │   ├── news_management_screen.dart
│   │   └── activity_logs_screen.dart
│   ├── support/                             # Shared by both roles
│   │   ├── ticket_list_screen.dart          # asAdmin: true → the queue
│   │   ├── ticket_conversation_screen.dart  # The back-and-forth
│   │   └── public_ticket_sheet.dart         # From the sign-in page, no token
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
│   ├── status_badge.dart        # Status chip widget
│   ├── pagination_bar.dart      # Pagination controls
│   ├── news_carousel.dart       # Landing-page research-news slideshow
│   ├── user_avatar.dart         # Photo or initials frame + AvatarButton
│   ├── avatar_editor_sheet.dart # Change/remove a photo (self or, as admin, anyone)
│   └── async_state_views.dart   # LoadingView / ErrorView / EmptyView
│
├── utils/
│   ├── file_download.dart       # Conditional export (web vs native)
│   ├── file_download_web.dart   # package:web browser download
│   └── file_download_io.dart    # dart:io + path_provider file write
│
├── theme/
│   └── app_theme.dart           # App colors & typography
│
└── main.dart                    # App entry point
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
- Password: `admin123`

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
- ⚠️ `applicationId` is still the scaffold default **`com.example.fe`** —
  must be changed before any real distribution
- CSV exports land in `Android/data/<applicationId>/files/Download`
- APK size: **~51 MB** for the universal release APK. Use
  `flutter build apk --split-per-abi` to cut this to roughly a third per
  device architecture.

### iOS (Future)
- Not yet configured
- Will require Xcode & Apple Developer account

---

## 🚀 Deployment

### Web Deployment

```bash
# Build for production
flutter build web --release

# Output: build/web/
# Deploy to any static hosting (Netlify, Vercel, etc.)
```

### Android Release

```bash
# Generate APK
flutter build apk --release

# Output: build/app/outputs/flutter-apk/app-release.apk

# Generate App Bundle (for Play Store)
flutter build appbundle --release
```

**Note:** For production, configure signing keys.

---

## 📚 Additional Documentation

- [../CLAUDE.md](../CLAUDE.md) - Working agreement and the traps that cost time
- [../API.md](../API.md) - Backend API reference
- [../DESIGN.md](../DESIGN.md) - Design system & UI guidelines

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
- ✅ `flutter test` — 54 tests, passing
- ✅ Landing page made responsive (was a fixed desktop layout)
- ✅ Status bar no longer covered on Android

### Completed (FASE 3)
- ✅ Researcher console shell with sidebar/drawer
- ✅ Dashboard, upload (direct + chunked), results & history with polling
- ✅ Frame gallery with server-rendered PNG previews
- ✅ Checksum-verified downloads on web and Android

### Completed since
- ✅ Join form wired to `POST /api/access-requests` + admin review screen
- ✅ IT support tickets, in-app for signed-in users and public from the
  sign-in page
- ✅ Research news: admin editor with photo upload and a publish switch, shown
  as a slideshow in the landing page's Research section

### Testing
The suite is **54** tests across five files.
`widget_test.dart` covers the landing page: a boot smoke test, a layout check at
seven viewports (fails if any section overflows), a status-bar clearance check,
and three header-navigation checks. `user_console_test.dart` covers the
researcher console: `MeStats` payload parsing and `UserActivityTile` rendering.
`support_test.dart` covers ticket parsing (including the guest fallback) and the
public ticket sheet's validation and phone layout. `avatar_test.dart` covers the initials fallback (two-part names, one-word
names, an empty name) and `UserModel`'s photo field. `news_test.dart` covers the
news payload and the carousel: that it collapses to nothing when the feed is
empty *or* fails, that it advances on its own, and that a slide fits four
viewports — the landing-page layout tests run with an empty feed, so the slide's
own layout is only covered here.

That is the entire automated suite — the file was Flutter's counter-app scaffold
until 15 Aug 2026, and it *failed*. The "23/23 contract tests" quoted in older
notes were a manual `curl` checklist, not a runnable suite.

**A layout test earns its place.** The phone-width check on `PublicTicketSheet`
caught a real 54px overflow: `DropdownButtonFormField` sizes itself to its
longest option rather than the space it is given, so "prediction" pushed the row
off the edge. Pass `isExpanded: true` on every dropdown in a constrained row.

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
- ⏳ Image viewer/gallery
- ⏳ Download progress
- ⏳ Real-time status updates
- ⏳ Push notifications
- ⏳ Dark mode

---

## 📞 Support

- **Documentation:** Root project documentation
- **Issues:** Report via project repository
- **Contact:** admin@brin.go.id

---

**Last Updated:** August 14, 2026  
**Flutter Version:** Latest Stable  
**Status:** Active Development - FASE 2 Complete
