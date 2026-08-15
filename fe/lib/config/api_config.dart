class ApiConfig {
  /// Backend base URL, including the `/api` prefix.
  ///
  /// The default is the reserved ngrok domain that fronts the local Octane
  /// server. It is a *reserved* domain, so it survives ngrok restarts, and it
  /// works unchanged for Flutter web and for a real Android device on any
  /// network — which is why it is the default rather than `localhost`.
  ///
  /// Override it per build without editing this file:
  ///
  /// ```
  /// # Android emulator talking to the host machine
  /// flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000/api
  ///
  /// # Real device on the same Wi-Fi as the backend
  /// flutter build apk --dart-define=API_BASE_URL=http://192.168.1.10:8000/api
  ///
  /// # Web against a local backend (backend must allow the origin)
  /// flutter run -d chrome --dart-define=API_BASE_URL=http://127.0.0.1:8000/api
  /// ```
  ///
  /// Note: plain-HTTP overrides only work on Android because the manifest sets
  /// `android:usesCleartextTraffic="true"`.
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://nucleus-drone-grueling.ngrok-free.dev/api',
  );

  // Timeouts
  static const int connectTimeout = 30000; // 30 seconds
  static const int receiveTimeout = 30000; // 30 seconds

  // API Endpoints
  static const String login = '/login';
  static const String logout = '/logout';
  static const String user = '/user';

  // Admin endpoints
  static const String adminUsers = '/admin/users';
  static const String adminModels = '/admin/models';
  static const String adminActivities = '/admin/activities';

  // User endpoints
  static const String predictions = '/predictions';
}
