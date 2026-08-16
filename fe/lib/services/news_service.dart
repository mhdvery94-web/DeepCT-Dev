import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../config/api_config.dart';
import '../models/news_post.dart';
import '../models/pagination.dart';
import 'api_client.dart';
import 'authed_image_cache.dart';

/// Research news: the public slideshow feed and the admin editor behind it.
class NewsService {
  final ApiClient _api = ApiClient.instance;

  /// GET /news — published posts only, in slideshow order. No token needed.
  Future<List<NewsPost>> publicFeed({int limit = 20}) async {
    final body = await _api.get(ApiConfig.news, query: {'limit': limit});

    return (body['data'] as List? ?? [])
        .map((e) => NewsPost.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  /// GET /admin/news — drafts included.
  Future<({PaginatedResult<NewsPost> page, int publishedCount, int draftCount})>
  adminList({int page = 1, String? status, String? search}) async {
    final body = await _api.get(
      ApiConfig.adminNews,
      query: {'page': page, 'status': status, 'search': search},
    );

    final items = (body['data'] as List? ?? [])
        .map((e) => NewsPost.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();

    final meta = body['meta'];
    int metaInt(String key) =>
        meta is Map ? (meta[key] as num?)?.toInt() ?? 0 : 0;

    return (
      page: PaginatedResult(
        items: items,
        pagination: body['pagination'] != null
            ? Pagination.fromJson(
                Map<String, dynamic>.from(body['pagination'] as Map),
              )
            : const Pagination.empty(),
      ),
      publishedCount: metaInt('published_count'),
      draftCount: metaInt('draft_count'),
    );
  }

  /// POST /admin/news, or POST /admin/news/{id} to update.
  ///
  /// Always multipart, because a photo may be attached — and always POST for
  /// the same reason: PHP does not populate `$_FILES` on a PUT.
  Future<NewsPost> save({
    int? id,
    String? title,
    String? summary,
    String? body,
    bool? isPublished,
    int? sortOrder,
    Uint8List? imageBytes,
    String? imageName,
    bool removeImage = false,
  }) async {
    final form = FormData.fromMap({
      'title': ?title,
      'summary': ?summary,
      'body': ?body,
      if (isPublished != null) 'is_published': isPublished ? '1' : '0',
      if (sortOrder != null) 'sort_order': '$sortOrder',
      if (removeImage) 'remove_image': '1',
      if (imageBytes != null)
        'image': MultipartFile.fromBytes(
          imageBytes,
          filename: imageName ?? 'photo.jpg',
        ),
    });

    final response = await _api.sendMultipart(
      id == null ? ApiConfig.adminNews : '${ApiConfig.adminNews}/$id',
      data: form,
    );

    final saved = NewsPost.fromJson(
      Map<String, dynamic>.from(response['data'] as Map),
    );

    // A replaced photo keeps its URL — `/news/3/image` before and after — so
    // nothing else would tell the cache that the bytes have changed.
    final path = saved.imagePath;
    if (path != null) AuthedImageCache.invalidate(path);

    return saved;
  }

  /// PATCH /admin/news/{id}/toggle — the publish switch.
  Future<NewsPost> toggle(int id) async {
    final body = await _api.patch('${ApiConfig.adminNews}/$id/toggle');

    return NewsPost.fromJson(
      Map<String, dynamic>.from(body['data'] as Map),
    );
  }

  /// DELETE /admin/news/{id}
  Future<void> delete(int id) async {
    await _api.delete('${ApiConfig.adminNews}/$id');
    AuthedImageCache.invalidate('${ApiConfig.news}/$id/image');
  }
}
