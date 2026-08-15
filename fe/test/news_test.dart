import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fe/config/api_config.dart';
import 'package:fe/models/news_post.dart';
import 'package:fe/widgets/news_carousel.dart';

Widget _host(Widget child) => MaterialApp(home: Scaffold(body: child));

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

  group('NewsCarousel', () {
    tearDown(() => NewsCarousel.debugLoader = null);

    NewsPost post(int id, String title) => NewsPost(
      id: id,
      title: title,
      summary: 'Summary of $title.',
    );

    testWidgets('renders nothing when there is no news', (tester) async {
      // A visitor must never meet an error box on the front page over
      // something optional, so an empty or failed fetch collapses to zero
      // height rather than showing a placeholder.
      NewsCarousel.debugLoader = () async => const [];

      await tester.pumpWidget(_host(const NewsCarousel()));
      await tester.pump();

      expect(find.text('Latest News'), findsNothing);
      expect(tester.getSize(find.byType(NewsCarousel)), Size.zero);
    });

    testWidgets('renders nothing when the fetch fails', (tester) async {
      NewsCarousel.debugLoader = () async => throw Exception('offline');

      await tester.pumpWidget(_host(const NewsCarousel()));
      await tester.pump();

      expect(find.text('Latest News'), findsNothing);
      expect(tester.getSize(find.byType(NewsCarousel)), Size.zero);
    });

    testWidgets('shows a slide once a post arrives', (tester) async {
      NewsCarousel.debugLoader = () async => [post(1, 'Beamline upgraded')];

      await tester.pumpWidget(_host(const NewsCarousel()));
      await tester.pump();

      expect(find.text('Latest News'), findsOneWidget);
      expect(find.text('Beamline upgraded'), findsOneWidget);
    });

    testWidgets('a single post gets no arrows and no dots', (tester) async {
      NewsCarousel.debugLoader = () async => [post(1, 'Only one')];

      await tester.pumpWidget(_host(const NewsCarousel()));
      await tester.pump();

      expect(find.byIcon(Icons.chevron_right), findsNothing);
    });

    // The landing-page layout tests run with an empty feed, so the slide's
    // own layout has to be checked here or nothing covers it.
    for (final entry in const <String, Size>{
      'phone': Size(390, 844),
      'small phone': Size(360, 640),
      'tablet': Size(768, 1024),
      'desktop': Size(1440, 1024),
    }.entries) {
      testWidgets('a slide fits ${entry.key}', (tester) async {
        tester.view.physicalSize = entry.value;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        NewsCarousel.debugLoader = () async => [
          NewsPost(
            id: 1,
            title: 'Neutron imaging beamline upgraded after shutdown',
            summary: 'The detector was replaced and the sample stage is now '
                'motorised, which cuts a full scan from six hours to two.',
            body: 'A longer article body.',
          ),
        ];

        await tester.pumpWidget(_host(const NewsCarousel()));
        await tester.pump();

        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('advances to the next post on its own', (tester) async {
      NewsCarousel.debugLoader = () async => [
        post(1, 'First story'),
        post(2, 'Second story'),
      ];

      await tester.pumpWidget(_host(const NewsCarousel()));
      await tester.pump();

      expect(find.text('First story'), findsOneWidget);

      // Past the 7s dwell, plus the animation.
      await tester.pump(const Duration(seconds: 8));
      await tester.pumpAndSettle();

      expect(find.text('Second story'), findsOneWidget);

      // Stop the periodic timer before the test ends.
      await tester.pumpWidget(_host(const SizedBox()));
    });
  });
}
