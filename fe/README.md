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

### User Dashboard (Coming Soon)
- ⏳ Upload CT images (T0 & T2)
- ⏳ View prediction results
- ⏳ Download results (2 options)
- ⏳ Prediction history

### Shared Features
- ✅ Responsive design (mobile, tablet, desktop) — covered by layout tests at
  360x640, 390x844, 768x1024, 1280x720 and 1440x1024
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
│   └── pagination.dart          # Pagination + PaginatedResult<T>
│
├── services/
│   ├── api_client.dart          # Dio HTTP client wrapper (ApiClient.instance)
│   ├── auth_service.dart        # Authentication service
│   ├── auth_provider.dart       # ChangeNotifier holding the signed-in user
│   ├── admin_user_service.dart  # AdminUserService  — user management API
│   ├── admin_model_service.dart # AdminModelService — model management API
│   └── activity_service.dart    # ActivityService   — activity logs API
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
│   │   └── activity_logs_screen.dart
│   └── user/
│       └── user_dashboard.dart  # Placeholder — FASE 3
│
├── widgets/
│   ├── status_badge.dart        # Status chip widget
│   ├── pagination_bar.dart      # Pagination controls
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

**Service conventions.** All four API services are instantiated (`AdminUserService()`),
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

See [test_auth.md](test_auth.md) for API contract tests.

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

- [test_auth.md](test_auth.md) - Authentication testing guide
- [../API_DOCS.md](../API_DOCS.md) - Backend API documentation
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
- ✅ `flutter test` — 6 tests, passing
- ✅ Landing page made responsive (was a fixed desktop layout)

### Not Started (FASE 3)
- ⏳ User dashboard (`screens/user/user_dashboard.dart` is a placeholder)
- ⏳ Upload screen
- ⏳ Prediction results
- ⏳ History screen

Blocked on the FASE 3 backend: the `predictions` routes are still commented out
in `be/routes/api.php`.

### Testing
`test/widget_test.dart` holds **6** tests: a boot smoke test plus a layout
check of the landing page at five viewports, which fails if any section
overflows. That is the entire automated suite — the file was Flutter's
counter-app scaffold until 15 Aug 2026, and it *failed*. The "23/23 contract
tests" in [test_auth.md](test_auth.md) are a manual `curl` checklist, not a
runnable suite.

```bash
flutter test
```

### Responsive breakpoints

`landing_page.dart` and `admin_shell.dart` both switch at **1000px**
(`_desktopBreakpoint` / `_mobileBreakpoint`); the landing page additionally
tightens its gutters below **600px**. Below 1000px the landing page stacks its
two-column sections and collapses the header navigation into a menu button.

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
