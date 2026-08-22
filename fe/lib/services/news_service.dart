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

  /// How many times one chunk is retried before the upload gives up.
  ///
  /// Matches ResearcherTrainingService: three attempts with a growing pause,
  /// and a re-sync with the server in between, because a request that failed
  /// may still have landed.
  static const int _chunkAttempts = 3;

  /// Attach a video to a post.
  ///
  /// Goes through the chunked uploader rather than a plain POST because
  /// post_max_size is 8 MB — a 25 MB multipart POST is refused with HTTP 413
  /// by Laravel's ValidatePostSize, which is what sent a 50 MB video down the
  /// same path as prediction archives.
  ///
  /// The loop is the third copy of this shape in the app, after
  /// PredictionService and ResearcherTrainingService. ROADMAP already records
  /// that the first two are worth unifying; this adds to that debt rather than
  /// paying it, deliberately, because unifying while adding a third caller
  /// would mix two changes in one commit range.
  ///
  /// Returns the post's relative video path, e.g. `/news/7/video`.
  Future<String> uploadVideo({
    required int postId,
    required Uint8List bytes,
    required String filename,
    void Function(double progress)? onProgress,
  }) async {
    final started = await _api.post(
      ApiConfig.predictionUploads,
      data: {
        'purpose': 'news_video',
        'news_post_id': postId,
        'total_size': bytes.length,
        'filename': filename,
      },
    );

    final session = Map<String, dynamic>.from(started['data'] as Map);
    final uploadId = session['upload_id'].toString();
    final chunkSize = (session['chunk_size'] as num?)?.toInt() ?? 1 << 20;

    var offset = 0;

    while (offset < bytes.length) {
      final end = (offset + chunkSize).clamp(0, bytes.length);
      final slice = Uint8List.sublistView(bytes, offset, end);

      // Whether the server took this chunk. On the other path — a retry that
      // found the server further along than we thought — `offset` has already
      // moved there, and assuming `end` would skip what sits in between.
      var accepted = false;

      for (var attempt = 1; ; attempt++) {
        try {
          await _api.sendMultipart(
            '${ApiConfig.predictionUploads}/$uploadId',
            method: 'PATCH',
            data: FormData.fromMap({
              'offset': offset,
              'chunk': MultipartFile.fromBytes(slice, filename: 'chunk'),
            }),
            onSendProgress: (sent, total) {
              if (total <= 0) return;
              final done = offset + (sent / total) * slice.length;
              onProgress?.call((done / bytes.length).clamp(0.0, 1.0));
            },
          );
          accepted = true;
          break;
        } on ApiException {
          if (attempt >= _chunkAttempts) rethrow;

          await Future<void>.delayed(Duration(seconds: attempt));

          // The failed request may have landed anyway. The server is the
          // authority on how much it holds, and re-sending from a stale
          // offset earns a 409.
          final synced = await _receivedSoFar(uploadId);
          if (synced != null && synced != offset) {
            offset = synced;
            break;
          }
        }
      }

      if (accepted) offset = end;
      onProgress?.call(offset / bytes.length);
    }

    final body = await _api.post(
      '${ApiConfig.predictionUploads}/$uploadId/finalize',
    );

    return ((body['data'] as Map)['video_url']).toString();
  }

  /// How many bytes the server has, or null if even that call failed.
  Future<int?> _receivedSoFar(String uploadId) async {
    try {
      final status = await _api.get('${ApiConfig.predictionUploads}/$uploadId');
      final received = (status['data'] as Map)['received'];
      return received is num ? received.toInt() : null;
    } catch (_) {
      return null;
    }
  }
}
