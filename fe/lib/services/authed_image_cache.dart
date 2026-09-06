// Uint8List and @visibleForTesting both come from here.
import 'package:flutter/foundation.dart';

import 'api_client.dart';

/// Bytes of images that sit behind the authenticated API, kept in memory.
///
/// `Image.network` cannot load them: the bearer token lives in secure storage
/// and is attached asynchronously by the Dio interceptor, which a plain image
/// request never goes through. Fetching through [ApiClient] is what makes an
/// administrator able to see a draft's photo at all.
///
/// Without a cache a list of twenty rows would re-request twenty images on
/// every rebuild, so the cache itself is not optional.
///
/// **What is cached, and what is not.** A "no" is worth remembering: an
/// account with no photo, or a file that has gone, gives the same answer every
/// time and asking again on every frame is waste. A *failure* is not: a
/// dropped connection says nothing about whether the image exists, and
/// remembering it turned one bad moment into a blank picture for the rest of
/// the app's life, with no retry ever. That is a real bug this class shipped
/// with — the two cases are told apart by [_isDefinitivelyAbsent] now.
class AuthedImageCache {
  static final Map<String, Uint8List?> _cache = {};
  static final Map<String, Future<Uint8List?>> _inFlight = {};

  /// Replaces the network fetch. Tests only — production leaves it null.
  @visibleForTesting
  static Future<Uint8List> Function(String path)? debugFetch;

  static Future<Uint8List?> load(String path) {
    if (_cache.containsKey(path)) return Future.value(_cache[path]);

    // Two widgets showing the same image must not race each other.
    return _inFlight.putIfAbsent(path, () async {
      try {
        final fetch = debugFetch;
        final bytes = fetch != null
            ? await fetch(path)
            : (await ApiClient.instance.getBytes(path)).bytes;

        _cache[path] = bytes;
        return bytes;
      } catch (e) {
        // Only a settled answer is remembered. Anything else is left out of
        // the cache entirely, so the next rebuild asks again.
        if (_isDefinitivelyAbsent(e)) _cache[path] = null;
        return null;
      } finally {
        _inFlight.remove(path);
      }
    });
  }

  /// True when the server has said there is nothing at this path, rather than
  /// the request having failed to reach an answer.
  ///
  /// 404 and 410 are the server speaking. A timeout, a dropped connection, a
  /// 500 or a closed tunnel are not — they are the same request worth making
  /// again in a second.
  static bool _isDefinitivelyAbsent(Object error) =>
      error is ApiException &&
      (error.statusCode == 404 || error.statusCode == 410);

  /// Puts an answer in the cache without asking the server for it.
  ///
  /// Tests only, and the same bargain as `NewsSection.debugLoader`: any test
  /// that pumps a widget carrying a photo would otherwise open a real HTTP
  /// request whose timeout timer is still pending when the test ends, and
  /// Flutter fails a test with pending timers. Seed `null` for "there is no
  /// picture here" — the placeholder, and no request.
  @visibleForTesting
  static void seed(String path, Uint8List? bytes) => _cache[path] = bytes;

  /// Whether an answer for [path] is already held. Tests use it to prove a
  /// failure was *not* remembered.
  @visibleForTesting
  static bool holds(String path) => _cache.containsKey(path);

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
    debugFetch = null;
  }
}
