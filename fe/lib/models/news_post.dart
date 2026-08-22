import '../config/api_config.dart';

/// One research news item.
///
/// The public list omits the editing fields; the admin list adds them, which
/// is why [isPublished] defaults to true — a post the public can see is by
/// definition published.
class NewsPost {
  final int id;
  final String title;
  final String summary;
  final String? body;

  final bool hasImage;

  /// Path relative to the API root, e.g. `/news/3/image`. Null when the post
  /// carries no photo. Use [imageUrl] for something a widget can load.
  final String? imagePath;

  /// Whether a clip is attached. Independent of the photo: a post may have
  /// neither, either, or both.
  final bool hasVideo;

  /// Path relative to the API root, like [imagePath]. Use [videoUrl] to load
  /// it.
  final String? videoPath;

  /// Shown beside the play button — 50 MB on a slow connection is worth
  /// knowing about before you start it. The photo has no counterpart because
  /// 4 MB does not need announcing.
  final int? videoSizeBytes;

  final bool isPublished;
  final int sortOrder;
  final DateTime? publishedAt;
  final String? author;

  const NewsPost({
    required this.id,
    required this.title,
    required this.summary,
    this.body,
    this.hasImage = false,
    this.imagePath,
    this.hasVideo = false,
    this.videoPath,
    this.videoSizeBytes,
    this.isPublished = true,
    this.sortOrder = 0,
    this.publishedAt,
    this.author,
  });

  static int _int(dynamic v) => v is int
      ? v
      : (v is num ? v.toInt() : int.tryParse('${v ?? ''}') ?? 0);

  factory NewsPost.fromJson(Map<String, dynamic> json) {
    return NewsPost(
      id: _int(json['id']),
      title: json['title']?.toString() ?? '',
      summary: json['summary']?.toString() ?? '',
      body: json['body']?.toString(),
      hasImage: json['has_image'] == true,
      imagePath: json['image_url']?.toString(),
      hasVideo: json['has_video'] == true,
      videoPath: json['video_url']?.toString(),
      videoSizeBytes: json['video_size_bytes'] is num
          ? (json['video_size_bytes'] as num).toInt()
          : int.tryParse('${json['video_size_bytes'] ?? ''}'),
      // Absent on the public payload, where everything returned is published.
      isPublished: json['is_published'] == null
          ? true
          : json['is_published'] == true,
      sortOrder: _int(json['sort_order']),
      publishedAt: json['published_at'] == null
          ? null
          : DateTime.tryParse(json['published_at'].toString()),
      author: json['author']?.toString(),
    );
  }

  /// Absolute URL of the photo, or null.
  ///
  /// Built from the configured base URL rather than returned by the server:
  /// the API is reached through several hostnames (ngrok, localhost, a LAN
  /// address) and a URL baked server-side would be wrong on two of them.
  String? get imageUrl =>
      imagePath == null ? null : '${ApiConfig.baseUrl}$imagePath';

  /// Absolute URL of the clip, or null. Built the same way and for the same
  /// reason as [imageUrl].
  String? get videoUrl =>
      videoPath == null ? null : '${ApiConfig.baseUrl}$videoPath';

  /// Null when there is no video, so a caller can drop the label entirely
  /// rather than print "0 B".
  String? get videoSizeLabel {
    final bytes = videoSizeBytes;
    if (bytes == null) return null;
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1048576) return '${(bytes / 1024).toStringAsFixed(0)} KB';
    return '${(bytes / 1048576).toStringAsFixed(1)} MB';
  }
}
