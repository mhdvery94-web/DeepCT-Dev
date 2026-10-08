class ApiConfig {
  /// Backend base URL, including the `/api` prefix.
  ///
  /// Points at the Raspberry Pi API's reserved ngrok tunnel.
  /// The intended production address is
  /// `https://api.brin.fajrianhost.my.id/api`, and it was briefly the default
  /// here — but that subdomain has no DNS record yet (the parent domain
  /// resolves; `api.brin` returns NXDOMAIN), so every build made without an
  /// override failed to connect, on web and Android alike. Switch back once
  /// the record exists and the backend is actually deployed behind it, not
  /// before: a default that does not resolve breaks the app for anyone who
  /// forgets the flag.
  ///
  /// This is a *reserved* ngrok domain, so it survives tunnel restarts. It
  /// only reaches a backend while someone is running `ngrok http 8000` on the
  /// machine hosting Octane.
  ///
  /// Every other target is supplied at build time:
  ///
  /// ```
  /// # Android emulator talking to the host machine
  /// flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000/api
  ///
  /// # Real device on the same Wi-Fi as the backend
  /// flutter build apk --dart-define=API_BASE_URL=http://192.168.1.10:8000/api
  ///
  /// # Web against a local backend (the backend must allow the origin)
  /// flutter run -d chrome --dart-define=API_BASE_URL=http://127.0.0.1:8000/api
  /// ```
  ///
  /// Plain-HTTP overrides only work on Android, where the manifest sets
  /// `android:usesCleartextTraffic="true"`.
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://zestfully-usable-pledge.ngrok-free.dev/api',
  );

  // Timeouts
  static const int connectTimeout = 30000; // 30 seconds
  static const int receiveTimeout = 30000; // 30 seconds

  // API Endpoints
  static const String login = '/login';
  static const String logout = '/logout';
  static const String user = '/user';

  // Public: request an account from the landing page
  static const String accessRequests = '/access-requests';

  // IT support, as messaging. The researcher's thread takes no id: they have
  // exactly one, so "mine" is the only thing it could mean.
  static const String messages = '/messages';

  // The bell
  static const String notifications = '/notifications';

  // Public: research news for the landing-page slideshow
  static const String news = '/news';

  // Admin endpoints
  static const String adminUsers = '/admin/users';
  static const String adminAccessRequests = '/admin/access-requests';
  static const String adminConversations = '/admin/conversations';
  static const String adminNews = '/admin/news';

  static const String adminModels = '/admin/models';
  static const String adminActivities = '/admin/activities';

  // Self-service endpoints (any signed-in user, not admin-only)
  static const String meAvatar = '/me/avatar';
  static const String meActivities = '/me/activities';
  static const String meStats = '/me/stats';
  static const String meModels = '/me/models';
  static const String meModelsRefresh = '/me/models/refresh';
  static const String mePassword = '/me/password';

  // Prediction pipeline (FASE 3)
  static const String predictions = '/predictions';
  static const String predictionUploads = '/predictions/uploads';
}
