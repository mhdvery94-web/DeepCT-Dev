import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../config/api_config.dart';
import 'api_client.dart';
import 'authed_image_cache.dart';

/// Profile photos: upload and removal.
///
/// Reading them is [AuthedImageCache]'s job — the endpoint needs a bearer
/// token, so the bytes are fetched through [ApiClient] rather than by
/// `Image.network`.
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
    AuthedImageCache.clear();
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
    AuthedImageCache.clear();
  }

  String? _pathFrom(Map<String, dynamic> body) {
    final data = body['data'];
    final path = data is Map ? data['avatar_url']?.toString() : null;

    // The bytes behind the old path are gone, and a list on screen would keep
    // showing them from cache.
    AuthedImageCache.clear();

    return path;
  }
}
