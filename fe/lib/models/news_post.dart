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
}
