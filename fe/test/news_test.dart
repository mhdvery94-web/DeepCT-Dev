import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:video_player/video_player.dart';

import 'package:fe/config/api_config.dart';
import 'package:fe/models/news_post.dart';
import 'package:fe/services/authed_image_cache.dart';
import 'package:fe/widgets/authed_image.dart';
import 'package:fe/widgets/news_article_view.dart';
import 'package:fe/widgets/news_section.dart';
import 'package:fe/widgets/news_video_player.dart';

/// Scrollable, because the landing page is. Without it a section taller than
/// the test surface overflows and the failure is the harness, not the widget:
/// nothing on a real page is asked to fit inside 800x600.
Widget _host(Widget child) => MaterialApp(
  home: Scaffold(body: SingleChildScrollView(child: child)),
);

void main() {
  group('NewsPost.fromJson', () {
    test('reads the public payload', () {
      final post = NewsPost.fromJson(const {
        'id': 3,
        'title': 'Beamline upgraded',
        'summary': 'The detector was replaced.',
        'body': 'A longer article.',
        'has_image': true,
        'image_url': '/news/3/image',
        'published_at': '2026-08-10T02:00:00+00:00',
        'sort_order': 2,
      });

      expect(post.id, 3);
      expect(post.title, 'Beamline upgraded');
      expect(post.hasImage, isTrue);
      expect(post.sortOrder, 2);
      expect(post.publishedAt, isNotNull);
    });

    test('treats a post without the admin flag as published', () {
      // The public list omits `is_published`; everything it returns is live.
      final post = NewsPost.fromJson(const {'id': 1, 'title': 'Live'});

      expect(post.isPublished, isTrue);
    });

    test('reads the draft flag when the admin list sends it', () {
      final post = NewsPost.fromJson(const {
        'id': 1,
        'title': 'Draft',
        'is_published': false,
      });

      expect(post.isPublished, isFalse);
    });

    test('builds the image URL from the configured base URL', () {
      // Not from a server-side absolute URL: the API answers on ngrok,
      // localhost and a LAN address, and a baked URL is wrong on two of them.
      final post = NewsPost.fromJson(const {
        'id': 3,
        'image_url': '/news/3/image',
      });

      expect(post.imageUrl, '${ApiConfig.baseUrl}/news/3/image');
    });

    test('has no image URL when there is no photo', () {
      final post = NewsPost.fromJson(const {'id': 4, 'has_image': false});

      expect(post.imageUrl, isNull);
      expect(post.hasImage, isFalse);
    });

    test('survives a payload with missing keys', () {
      final post = NewsPost.fromJson(const {});

      expect(post.id, 0);
      expect(post.title, '');
      expect(post.summary, '');
      expect(post.body, isNull);
    });
  });

  group('NewsSection', () {
    tearDown(() {
      NewsSection.debugLoader = null;
      AuthedImageCache.clear();
    });

    /// Renders at [size] so a multi-post section has somewhere to go. The
    /// default 800x600 surface is shorter than a featured card plus two rows,
    /// and the overflow it causes is the test failing, not the widget.
    void surface(WidgetTester tester, Size size) {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
    }

    NewsPost post(int id, String title) => NewsPost(
      id: id,
      title: title,
      summary: 'Summary of $title.',
    );

    testWidgets('renders nothing when there is no news', (tester) async {
      // A visitor must never meet an error box on the front page over
      // something optional, so an empty or failed fetch collapses to zero
      // height rather than showing a placeholder.
      NewsSection.debugLoader = () async => const [];

      await tester.pumpWidget(_host(const NewsSection()));
      await tester.pump();

      expect(find.text('Latest News'), findsNothing);
      expect(tester.getSize(find.byType(NewsSection)), Size.zero);
    });

    testWidgets('renders nothing when the fetch fails', (tester) async {
      NewsSection.debugLoader = () async => throw Exception('offline');

      await tester.pumpWidget(_host(const NewsSection()));
      await tester.pump();

      expect(find.text('Latest News'), findsNothing);
      expect(tester.getSize(find.byType(NewsSection)), Size.zero);
    });

    testWidgets('shows the post once it arrives', (tester) async {
      NewsSection.debugLoader = () async => [post(1, 'Beamline upgraded')];

      await tester.pumpWidget(_host(const NewsSection()));
      await tester.pump();

      expect(find.text('Latest News'), findsOneWidget);
      expect(find.text('Beamline upgraded'), findsOneWidget);
    });

    testWidgets('shows every post at once, with nothing to wait for', (
      tester,
    ) async {
      // The carousel this replaced showed one at a time and made a reader
      // wait seven seconds for the next. Nothing rotates now, so there are no
      // arrows, no dots, and no timer left running at the end of a test.
      surface(tester, const Size(1440, 1024));

      NewsSection.debugLoader = () async => [
        post(1, 'First story'),
        post(2, 'Second story'),
        post(3, 'Third story'),
      ];

      await tester.pumpWidget(_host(const NewsSection()));
      await tester.pump();

      expect(find.text('First story'), findsOneWidget);
      expect(find.text('Second story'), findsOneWidget);
      expect(find.text('Third story'), findsOneWidget);

      expect(find.byIcon(Icons.chevron_right), findsNothing);
      expect(find.byIcon(Icons.chevron_left), findsNothing);
    });

    testWidgets('shows at most six, however many the feed returns', (
      tester,
    ) async {
      surface(tester, const Size(1440, 2400));

      NewsSection.debugLoader = () async => [
        for (var i = 1; i <= 12; i++) post(i, 'Story $i'),
      ];

      await tester.pumpWidget(_host(const NewsSection()));
      await tester.pump();

      expect(find.text('Story 6'), findsOneWidget);
      expect(find.text('Story 7'), findsNothing);
    });

    // The landing-page layout tests run with an empty feed, so this section's
    // own layout has to be checked here or nothing covers it.
    for (final entry in const <String, Size>{
      'phone': Size(390, 844),
      'small phone': Size(360, 640),
      'tablet': Size(768, 1024),
      'desktop': Size(1440, 1024),
    }.entries) {
      testWidgets('the section fits ${entry.key}', (tester) async {
        surface(tester, entry.value);

        NewsSection.debugLoader = () async => [
          NewsPost(
            id: 1,
            title: 'Neutron imaging beamline upgraded after shutdown',
            summary: 'The detector was replaced and the sample stage is now '
                'motorised, which cuts a full scan from six hours to two.',
            body: 'A longer article body.',
          ),
        ];

        await tester.pumpWidget(_host(const NewsSection()));
        await tester.pump();

        expect(tester.takeException(), isNull);
      });
    }

    NewsPost withClip({String? body, bool photo = false}) => NewsPost(
      id: 1,
      title: 'Beamline in motion',
      summary: 'A short summary.',
      body: body,
      hasImage: photo,
      imagePath: photo ? '/news/1/image' : null,
      hasVideo: true,
      videoPath: '/news/1/video',
      videoSizeBytes: 19049369,
    );

    testWidgets('the photograph and the clip get blocks of their own', (
      tester,
    ) async {
      // This is the redesign's whole point. The clip used to be handed the
      // photograph as its poster and drawn in the photograph's place, so a
      // post with both showed only the video and the picture was nowhere.
      surface(tester, const Size(1440, 1024));

      // Seeded null: "there is no picture", which draws the placeholder and
      // keeps the test off the network.
      AuthedImageCache.seed('/news/1/image', null);
      NewsSection.debugLoader = () async => [withClip(photo: true)];

      await tester.pumpWidget(_host(const NewsSection()));
      await tester.pump();

      final photo = tester.getRect(find.byType(AuthedImage));
      final clip = tester.getRect(
        find.byKey(const Key('news-featured-video')),
      );

      expect(
        photo.overlaps(clip),
        isFalse,
        reason: 'the clip must not be drawn over the photograph',
      );
      expect(
        clip.top,
        greaterThanOrEqualTo(photo.bottom),
        reason: 'stacked, in that order — the arrangement of the open article',
      );
    });

    testWidgets('media runs the full width of the card', (tester) async {
      // The reason both fit. A media column beside the text was 5/11 of the
      // card, and splitting that between a photograph and a clip left each
      // about 250x210 — too small to read a diagram in, too small to work a
      // scrubber in. Full width is what makes stacking them worth doing.
      surface(tester, const Size(1440, 1024));

      AuthedImageCache.seed('/news/1/image', null);
      NewsSection.debugLoader = () async => [withClip(photo: true)];

      await tester.pumpWidget(_host(const NewsSection()));
      await tester.pump();

      final section = tester.getRect(find.byType(NewsSection));
      final photo = tester.getRect(find.byType(AuthedImage));
      final clip = tester.getRect(
        find.byKey(const Key('news-featured-video')),
      );

      // Less the card's 4px red edge and its 1px right border.
      expect(photo.width, greaterThan(section.width - 10));
      expect(clip.width, greaterThan(section.width - 10));

      // And capped, or 16:9 across 1440px would be 810px of photograph.
      expect(photo.height, lessThanOrEqualTo(340));
    });

    testWidgets('the teaser crops the photograph; the article does not', (
      tester,
    ) async {
      // `contain` was tried here and it was wrong: it rescued one portrait
      // test diagram and made every ordinary landscape photograph float
      // between two thick black bars. Cropping is what a teaser is for.
      AuthedImageCache.seed('/news/1/image', null);
      NewsSection.debugLoader = () async => [withClip(photo: true)];

      await tester.pumpWidget(_host(const NewsSection()));
      await tester.pump();

      expect(tester.widget<AuthedImage>(find.byType(AuthedImage)).fit,
          BoxFit.cover);
    });

    testWidgets('the clip is not given the photograph as a backdrop', (
      tester,
    ) async {
      // Belt to the previous test's braces: even in its own block, a poster
      // drawn from the post's photo puts the same picture behind a play
      // button. The player carries no photograph of its own at all now — it
      // opens the clip and shows its first frame instead.
      AuthedImageCache.seed('/news/1/image', null);
      NewsSection.debugLoader = () async => [withClip(photo: true)];

      await tester.pumpWidget(_host(const NewsSection()));
      await tester.pump();

      expect(
        find.descendant(
          of: find.byKey(const Key('news-featured-video')),
          matching: find.byType(AuthedImage),
        ),
        findsNothing,
      );
    });

    testWidgets('a clip plays on the featured card, not behind a button', (
      tester,
    ) async {
      // It used to sit inside a dialog reached through READ MORE & WATCH. A
      // video on a landing page should be where the eye already is.
      NewsSection.debugLoader = () async => [withClip()];

      await tester.pumpWidget(_host(const NewsSection()));
      await tester.pump();

      expect(find.byType(NewsVideoPlayer), findsOneWidget);
      expect(find.byKey(const Key('news-video-badge')), findsOneWidget);
      expect(find.text('18.2 MB'), findsOneWidget);

      // Nothing to press to reach it, and nothing to press for an article
      // that was never written.
      expect(find.text('READ MORE'), findsNothing);
    });

    testWidgets('a clip with an article keeps both', (tester) async {
      NewsSection.debugLoader = () async => [withClip(body: 'The article.')];

      await tester.pumpWidget(_host(const NewsSection()));
      await tester.pump();

      expect(find.byType(NewsVideoPlayer), findsOneWidget);
      expect(find.text('READ MORE'), findsOneWidget);
    });

    testWidgets('the whole clip is not pulled down before play', (tester) async {
      // The player opens the file by itself now, to take a first frame off it,
      // but that reads a header and one frame — not the file. The landing page
      // must still cost a photograph to look at, not tens of megabytes of
      // video nobody has asked for. (In a test the plugin is absent, so
      // opening fails at once and the idle panel is what remains.)
      NewsSection.debugLoader = () async => [withClip()];

      await tester.pumpWidget(_host(const NewsSection()));
      await tester.pump();

      expect(find.byIcon(Icons.play_arrow), findsOneWidget);
      expect(find.byType(VideoPlayer), findsNothing);
    });

    testWidgets('a post below the featured one names its clip, not plays it', (
      tester,
    ) async {
      // Five players on a front page is five video elements nobody asked for.
      // The row says a clip is there and the article plays it.
      surface(tester, const Size(1440, 1024));

      NewsSection.debugLoader = () async => [
        post(1, 'Featured story'),
        NewsPost(
          id: 2,
          title: 'Second story',
          summary: 'S',
          hasVideo: true,
          videoPath: '/news/2/video',
          videoSizeBytes: 19049369,
        ),
      ];

      await tester.pumpWidget(_host(const NewsSection()));
      await tester.pump();

      expect(find.byKey(const Key('news-row-video')), findsOneWidget);
      expect(find.text('VIDEO · 18.2 MB'), findsOneWidget);

      // The featured post has no clip, so nothing on the page should be a
      // player.
      expect(find.byType(NewsVideoPlayer), findsNothing);
    });

    testWidgets('a row opens the post it belongs to', (tester) async {
      surface(tester, const Size(1440, 1024));

      NewsSection.debugLoader = () async => [
        post(1, 'Featured story'),
        NewsPost(
          id: 2,
          title: 'Second story',
          summary: 'S',
          body: 'The second article.',
        ),
      ];

      await tester.pumpWidget(_host(const NewsSection()));
      await tester.pump();

      await tester.tap(find.text('Second story'));
      await tester.pumpAndSettle();

      expect(find.text('The second article.'), findsOneWidget);
    });

    testWidgets('CLOSE shuts the article', (tester) async {
      // The regression this exists for: the carousel rotated on behind the
      // open dialog, `PageView` disposed the slide, and CLOSE — whose
      // `onPressed` had captured that slide's context — threw instead of
      // closing. Nothing rotates any more, but the guard is worth keeping.
      surface(tester, const Size(1440, 1024));

      NewsSection.debugLoader = () async => [
        NewsPost(
          id: 1,
          title: 'Story 1',
          summary: 'S',
          body: 'The article.',
        ),
      ];

      await tester.pumpWidget(_host(const NewsSection()));
      await tester.pump();

      await tester.tap(find.text('READ MORE'));
      await tester.pumpAndSettle();
      expect(find.text('The article.'), findsOneWidget);

      await tester.tap(find.text('CLOSE'));
      await tester.pumpAndSettle();

      expect(find.text('The article.'), findsNothing);
      expect(tester.takeException(), isNull);
      expect(find.text('Story 1'), findsOneWidget);
    });
  });

  group('the opened post', () {
    tearDown(() {
      NewsSection.debugLoader = null;
      AuthedImageCache.clear();
    });

    // Local rather than UTC on purpose: the date is formatted through
    // `toLocal()`, and a UTC midnight is the previous day west of Greenwich.
    NewsPost full() => NewsPost(
      id: 1,
      title: 'Beamline in motion',
      summary: 'The detector was replaced and the sample stage is now '
          'motorised, which cuts a full scan from six hours to two.',
      body: 'A much longer article than the slide has room for.',
      hasImage: true,
      imagePath: '/news/1/image',
      hasVideo: true,
      videoPath: '/news/1/video',
      videoSizeBytes: 19049369,
      publishedAt: DateTime(2026, 8, 10),
    );

    Future<void> open(WidgetTester tester, NewsPost post) async {
      // Seeding the cache is what keeps this test off the network: an
      // unseeded photo starts a real request whose timeout timer outlives the
      // test. Null means "no picture", which draws the placeholder.
      AuthedImageCache.seed(post.imagePath ?? '', null);
      NewsSection.debugLoader = () async => [post];

      await tester.pumpWidget(_host(const NewsSection()));
      await tester.pump();

      // Scrolled to first: the featured card leads with a full-width media
      // band now, so its button sits below the fold of a default test surface.
      final button = find.textContaining(RegExp('READ MORE|VIEW POST'));
      await tester.ensureVisible(button);
      await tester.pumpAndSettle();

      await tester.tap(button);
      await tester.pumpAndSettle();
    }

    testWidgets('shows the whole post rather than one paragraph of it', (
      tester,
    ) async {
      // It used to be the body text and nothing else — no date, no summary,
      // no photograph, no clip. Opening a post should show the post.
      await open(tester, full());

      final article = find.byType(NewsArticleView);
      expect(article, findsOneWidget);

      Finder inside(Finder matching) =>
          find.descendant(of: article, matching: matching);

      expect(inside(find.text('10 AUG 2026')), findsOneWidget);
      expect(inside(find.text('Beamline in motion')), findsOneWidget);
      expect(inside(find.byKey(const Key('news-article-summary'))), findsOneWidget);
      expect(
        inside(find.text('A much longer article than the slide has room for.')),
        findsOneWidget,
      );
      expect(inside(find.byType(AuthedImage)), findsWidgets);
      expect(inside(find.byType(NewsVideoPlayer)), findsOneWidget);
    });

    testWidgets('shows the photograph whole instead of cropping it', (
      tester,
    ) async {
      // The teaser's 200px letterbox took roughly three quarters off a
      // portrait diagram. `contain` is the reason opening the post is worth
      // doing at all for an image-only item.
      await open(tester, full());

      final images = tester.widgetList<AuthedImage>(
        find.descendant(
          of: find.byType(NewsArticleView),
          matching: find.byType(AuthedImage),
        ),
      );

      // The image block comes first; the one after it is the clip's poster,
      // which stays `cover` because it sits behind a scrim.
      expect(images.first.fit, BoxFit.contain);
    });

    testWidgets('does not clip the summary the way the slide does', (
      tester,
    ) async {
      await open(tester, full());

      final summary = tester.widget<Text>(
        find.byKey(const Key('news-article-summary')),
      );

      expect(summary.maxLines, isNull);
    });

    testWidgets('hands the clip its size, which web needs before it starts', (
      tester,
    ) async {
      // A browser cannot stream this file — it downloads it whole — so the
      // player has to be able to refuse one that is too large to hold.
      await open(tester, full());

      final player = tester.widget<NewsVideoPlayer>(
        find.descendant(
          of: find.byType(NewsArticleView),
          matching: find.byType(NewsVideoPlayer),
        ),
      );

      expect(player.sizeBytes, 19049369);
      expect(NewsVideoPlayer.webDownloadLimitBytes, greaterThan(19049369));
    });

    NewsPost photoOnly() => const NewsPost(
      id: 1,
      title: 'One picture',
      summary: 'A short summary.',
      hasImage: true,
      imagePath: '/news/1/image',
    );

    testWidgets('offers a post with no article as VIEW POST', (tester) async {
      // "Read more" would be a lie, but there is still something to see: the
      // slide cropped the photograph.
      AuthedImageCache.seed('/news/1/image', null);
      NewsSection.debugLoader = () async => [photoOnly()];

      await tester.pumpWidget(_host(const NewsSection()));
      await tester.pump();

      expect(find.text('VIEW POST'), findsOneWidget);
      expect(find.text('READ MORE'), findsNothing);
    });

    testWidgets('opens a post that is only a photograph', (tester) async {
      await open(tester, photoOnly());

      expect(find.byType(NewsArticleView), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(NewsArticleView),
          matching: find.byType(NewsVideoPlayer),
        ),
        findsNothing,
      );
    });
  });
}
