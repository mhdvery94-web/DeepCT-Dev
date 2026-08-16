import 'dart:typed_data';

import 'api_client.dart';

/// Bytes of images that sit behind the authenticated API, kept in memory.
///
/// `Image.network` cannot load them: the bearer token lives in secure storage
/// and is attached asynchronously by the Dio interceptor, which a plain image
/// request never goes through. Fetching through [ApiClient] is what makes an
/// administrator able to see a draft's photo at all.
///
/// Without a cache a list of twenty rows would re-request twenty images on
/// every rebuild, so a miss is cached as well — an account with no photo, or a
/// file that has gone, must not be asked for again on every frame.
class AuthedImageCache {
  static final Map<String, Uint8List?> _cache = {};
  static final Map<String, Future<Uint8List?>> _inFlight = {};

  static Future<Uint8List?> load(String path) {
    if (_cache.containsKey(path)) return Future.value(_cache[path]);

    // Two widgets showing the same image must not race each other.
    return _inFlight.putIfAbsent(path, () async {
      try {
        final result = await ApiClient.instance.getBytes(path);
        _cache[path] = result.bytes;
        return result.bytes;
      } catch (_) {
        _cache[path] = null;
        return null;
      } finally {
        _inFlight.remove(path);
      }
    });
  }

  /// Forget one image.
  ///
  /// Needed because a replaced photo keeps its URL — `/news/3/image` is the
  /// same string before and after — so nothing else would tell the cache that
  /// the bytes behind it have changed.
  static void invalidate(String path) {
    _cache.remove(path);
    _inFlight.remove(path);
  }

  static void clear() {
    _cache.clear();
    _inFlight.clear();
  }
}
