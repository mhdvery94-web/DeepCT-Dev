import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Token storage that a broken keystore cannot take the whole app down with.
///
/// Every request in this app passes through a Dio `onRequest` interceptor that
/// reads the bearer token from here. On Android that read is not a map lookup:
/// the plugin decrypts the value with a key held in the Android Keystore, and
/// that key does not always survive. Installing a differently-built APK over
/// an existing one, or letting Android Auto Backup restore the encrypted
/// preferences onto a device whose keystore never held the key, leaves bytes
/// that can never be decrypted — the read throws, and it throws every time.
///
/// A throw inside an interceptor fails the *entire request*, which is why the
/// symptom was never "you are signed out". It was a landing page with no
/// research news — `/api/news` is public and needs no token at all, yet the
/// interceptor ran first and never got there — and a sign-in that answered
/// **"An unexpected error occurred"**, because a `DioException` wrapping a
/// `PlatformException` carries no response and lands in that fallback branch.
/// Both halves looked like a backend that was down. The backend was fine.
///
/// So the bargain here is asymmetric, and deliberately so:
///
/// * A **read** that fails answers `null` and throws the unreadable data away.
///   That costs one sign-in and repairs the device permanently; keeping the
///   bytes would fail every read forever.
/// * A **write** or **delete** that fails costs this session's cached token
///   and nothing else. The token was already issued — losing the cache is not
///   worth failing the login that earned it.
class SecureStore {
  const SecureStore._();

  static const FlutterSecureStorage _storage = FlutterSecureStorage();

  /// Replace the plugin. Tests only — production leaves every one of these
  /// null and talks to the real store.
  static Future<String?> Function(String key)? debugRead;
  static Future<void> Function(String key, String value)? debugWrite;
  static Future<void> Function(String key)? debugDelete;
  static Future<void> Function()? debugDeleteAll;

  static void resetForTests() {
    debugRead = null;
    debugWrite = null;
    debugDelete = null;
    debugDeleteAll = null;
  }

  /// The value, or `null` — never a throw.
  static Future<String?> read(String key) async {
    try {
      final reader = debugRead;
      return reader != null ? await reader(key) : await _storage.read(key: key);
    } catch (_) {
      // Unreadable data stays unreadable, so it has to go: every later read
      // would throw on exactly the same bytes.
      await _wipe();
      return null;
    }
  }

  static Future<void> write(String key, String value) async {
    try {
      final writer = debugWrite;
      if (writer != null) {
        await writer(key, value);
      } else {
        await _storage.write(key: key, value: value);
      }
    } catch (_) {
      // Caching the token is a convenience; the sign-in already succeeded.
    }
  }

  static Future<void> delete(String key) async {
    try {
      final deleter = debugDelete;
      if (deleter != null) {
        await deleter(key);
      } else {
        await _storage.delete(key: key);
      }
    } catch (_) {
      // Signing out locally is what matters, and the caller does that itself.
    }
  }

  static Future<void> _wipe() async {
    try {
      final wipe = debugDeleteAll;
      if (wipe != null) {
        await wipe();
      } else {
        await _storage.deleteAll();
      }
    } catch (_) {
      // Nothing further to try. The read has already answered `null`, which is
      // the answer that keeps the request alive.
    }
  }
}
