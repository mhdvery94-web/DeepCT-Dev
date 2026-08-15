import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../config/api_config.dart';
import 'api_client.dart';

/// Profile photos: upload, removal, and the byte cache the widget reads.
class AvatarService {
  final ApiClient _api = ApiClient.instance;

  /// POST /me/avatar — returns the new `avatar_url`.
  Future<String?> uploadOwn(Uint8List bytes, String filename) async {
    final body = await _api.sendMultipart(
      ApiConfig.meAvatar,
      data: FormData.fromMap({
        'avatar': MultipartFile.fromBytes(bytes, filename: filename),
      }),
    );

    return _pathFrom(body);
  }

  /// DELETE /me/avatar
  Future<void> removeOwn() async {
    await _api.delete(ApiConfig.meAvatar);
    AvatarCache.clear();
  }

  /// POST /admin/users/{id}/avatar — an administrator setting someone else's.
  Future<String?> uploadFor(int userId, Uint8List bytes, String filename) async {
    final body = await _api.sendMultipart(
      '${ApiConfig.adminUsers}/$userId/avatar',
      data: FormData.fromMap({
        'avatar': MultipartFile.fromBytes(bytes, filename: filename),
      }),
    );

    return _pathFrom(body);
  }

  /// DELETE /admin/users/{id}/avatar
  Future<void> removeFor(int userId) async {
    await _api.delete('${ApiConfig.adminUsers}/$userId/avatar');
    AvatarCache.clear();
  }

  String? _pathFrom(Map<String, dynamic> body) {
    final data = body['data'];
    final path = data is Map ? data['avatar_url']?.toString() : null;

    // The bytes behind the old path are gone, and a list on screen would keep
    // showing them from cache.
    AvatarCache.clear();

    return path;
  }
}

/// In-memory cache of fetched avatars, keyed by the path the API returned.
///
/// Photos are behind an authenticated endpoint, so `Image.network` cannot load
/// them — the bearer token lives in secure storage and is read asynchronously
/// by the Dio interceptor. Fetching bytes through [ApiClient] is what makes
/// that work, and without a cache a list of twenty rows would fetch twenty
/// times on every rebuild.
///
/// A miss is cached too: an account with no photo, or one whose file has gone,
/// must not be re-requested on every frame.
class AvatarCache {
  static final Map<String, Uint8List?> _cache = {};
  static final Map<String, Future<Uint8List?>> _inFlight = {};

  static Future<Uint8List?> load(String path) {
    if (_cache.containsKey(path)) return Future.value(_cache[path]);

    // Two rows showing the same person must not race each other.
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

  /// Called after any change, since a new upload writes a new path and the old
  /// entry would otherwise linger for the life of the session.
  static void clear() {
    _cache.clear();
    _inFlight.clear();
  }
}
