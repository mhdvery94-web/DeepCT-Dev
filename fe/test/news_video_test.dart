import 'package:flutter_test/flutter_test.dart';

import 'package:fe/models/news_post.dart';

void main() {
  NewsPost parse(Map<String, dynamic> json) => NewsPost.fromJson(json);

  test('a post reports the video it has', () {
    final post = parse({
      'id': 7,
      'title': 'Field trip',
      'summary': 'A day at the reactor',
      'has_video': true,
      'video_url': '/news/7/video',
      'video_size_bytes': 12582912,
    });

    expect(post.hasVideo, isTrue);
    expect(post.videoPath, '/news/7/video');
    expect(post.videoSizeBytes, 12582912);
    // Absolute, like imageUrl: the API answers on several hostnames and a URL
    // baked server-side would be wrong on most of them.
    expect(post.videoUrl, endsWith('/news/7/video'));
  });

  test('a post with no video says so rather than throwing', () {
    // Older payloads and text-only posts both arrive without these keys.
    final post = parse({
      'id': 8,
      'title': 'Text only',
      'summary': 'No media',
    });

    expect(post.hasVideo, isFalse);
    expect(post.videoPath, isNull);
    expect(post.videoUrl, isNull);
    expect(post.videoSizeBytes, isNull);
  });

  test('the size is shown in units a person reads', () {
    // 50 MB on a slow connection is worth knowing about before you start it.
    expect(
      parse({'id': 1, 'title': 't', 'summary': 's', 'video_size_bytes': 12582912})
          .videoSizeLabel,
      '12.0 MB',
    );
    expect(
      parse({'id': 1, 'title': 't', 'summary': 's', 'video_size_bytes': 524288})
          .videoSizeLabel,
      '512 KB',
    );
    // Null rather than "0 B", so a caller can drop the label entirely.
    expect(
      parse({'id': 1, 'title': 't', 'summary': 's'}).videoSizeLabel,
      isNull,
    );
  });
}
