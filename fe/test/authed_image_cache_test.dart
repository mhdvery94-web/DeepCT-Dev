import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:fe/services/api_client.dart';
import 'package:fe/services/authed_image_cache.dart';

/// This class had no tests at all, and the path it guards is the one that
/// visibly broke: a landing page whose pictures were blank. The distinction
/// below is the whole of the fix.
void main() {
  setUp(AuthedImageCache.clear);
  tearDown(AuthedImageCache.clear);

  final bytes = Uint8List.fromList([1, 2, 3, 4]);

  test('a fetched image is served from memory the second time', () {
    var calls = 0;
    AuthedImageCache.debugFetch = (path) async {
      calls++;
      return bytes;
    };

    return AuthedImageCache.load('/news/1/image').then((first) async {
      expect(first, bytes);
      expect(await AuthedImageCache.load('/news/1/image'), bytes);

      // Twenty rows rebuilding must not be twenty requests.
      expect(calls, 1);
    });
  });

  test('a 404 is remembered, because the answer will not change', () async {
    var calls = 0;
    AuthedImageCache.debugFetch = (path) async {
      calls++;
      throw const ApiException('Not found', statusCode: 404);
    };

    expect(await AuthedImageCache.load('/users/9/avatar'), isNull);
    expect(await AuthedImageCache.load('/users/9/avatar'), isNull);

    expect(calls, 1, reason: 'an account with no photo has none tomorrow too');
    expect(AuthedImageCache.holds('/users/9/avatar'), isTrue);
  });

  test('a dropped connection is not remembered', () async {
    // The bug this exists for. One bad moment used to blank an image for the
    // rest of the app's life, with no retry ever.
    var calls = 0;
    AuthedImageCache.debugFetch = (path) async {
      calls++;
      throw const ApiException('Cannot reach the server');
    };

    expect(await AuthedImageCache.load('/news/1/image'), isNull);
    expect(
      AuthedImageCache.holds('/news/1/image'),
      isFalse,
      reason: 'a failure must leave nothing behind to be believed later',
    );

    expect(await AuthedImageCache.load('/news/1/image'), isNull);
    expect(calls, 2, reason: 'the next rebuild has to ask again');
  });

  test('a server error is not remembered either', () async {
    AuthedImageCache.debugFetch = (path) async {
      throw const ApiException('Server error', statusCode: 500);
    };

    await AuthedImageCache.load('/news/1/image');

    expect(AuthedImageCache.holds('/news/1/image'), isFalse);
  });

  test('a retry after a failure succeeds and is then cached', () async {
    var calls = 0;
    AuthedImageCache.debugFetch = (path) async {
      calls++;
      if (calls == 1) throw const ApiException('Connection timeout.');
      return bytes;
    };

    expect(await AuthedImageCache.load('/news/1/image'), isNull);
    expect(await AuthedImageCache.load('/news/1/image'), bytes);
    expect(await AuthedImageCache.load('/news/1/image'), bytes);

    expect(calls, 2, reason: 'the success is cached, the failure was not');
  });

  test('two widgets asking at once share one request', () async {
    var calls = 0;
    AuthedImageCache.debugFetch = (path) async {
      calls++;
      await Future<void>.delayed(const Duration(milliseconds: 10));
      return bytes;
    };

    final results = await Future.wait([
      AuthedImageCache.load('/news/1/image'),
      AuthedImageCache.load('/news/1/image'),
    ]);

    expect(results, [bytes, bytes]);
    expect(calls, 1);
  });

  test('invalidate forces the next read to ask again', () async {
    var calls = 0;
    AuthedImageCache.debugFetch = (path) async {
      calls++;
      return bytes;
    };

    await AuthedImageCache.load('/news/3/image');
    // A replaced photo keeps its URL, so nothing else would say the bytes
    // behind it have changed.
    AuthedImageCache.invalidate('/news/3/image');
    await AuthedImageCache.load('/news/3/image');

    expect(calls, 2);
  });
}
