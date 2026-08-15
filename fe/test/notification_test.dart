import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fe/models/app_notification.dart';
import 'package:fe/theme/app_theme.dart';
import 'package:fe/widgets/notification_bell.dart';

Widget _host(Widget child) => MaterialApp(home: Scaffold(body: child));

AppNotification _notification({
  String type = 'message.reply',
  bool read = false,
  DateTime? createdAt,
}) => AppNotification(
  id: 'abc',
  type: type,
  title: 'Support replied',
  body: 'Which browser?',
  link: 'messages',
  read: read,
  createdAt: createdAt,
);

void main() {
  group('AppNotification', () {
    test('reads the payload', () {
      final notification = AppNotification.fromJson(const {
        'id': '9f1c-...',
        'type': 'prediction.completed',
        'title': 'Interpolation finished',
        'body': '3 frames generated.',
        'link': 'predictions/12',
        'meta': {'analysis_record_id': 12},
        'read': false,
        'created_at': '2026-08-15T03:00:00+00:00',
      });

      expect(notification.id, '9f1c-...');
      expect(notification.type, 'prediction.completed');
      expect(notification.link, 'predictions/12');
      expect(notification.meta['analysis_record_id'], 12);
      expect(notification.read, isFalse);
      expect(notification.createdAt, isNotNull);
    });

    test('survives a payload with missing keys', () {
      final notification = AppNotification.fromJson(const {});

      expect(notification.type, 'general');
      expect(notification.title, '');
      expect(notification.link, isNull);
      expect(notification.meta, isEmpty);
    });

    test('an unknown type still gets an icon and a colour', () {
      // The server can add an event without waiting for a client release, so
      // the mapping has to fall back rather than throw.
      final notification = _notification(type: 'something.new');

      expect(notification.icon, Icons.notifications_none);
      expect(notification.colour, AppTheme.accent);
    });

    test('failures are red and completions are green', () {
      expect(_notification(type: 'prediction.failed').colour, AppTheme.error);
      expect(_notification(type: 'model.offline').colour, AppTheme.error);
      expect(_notification(type: 'prediction.completed').colour, AppTheme.success);
      expect(_notification(type: 'model.online').colour, AppTheme.success);
      expect(_notification(type: 'prediction.expiring').colour, AppTheme.warning);
    });

    test('every family has its own icon', () {
      expect(_notification(type: 'message.received').icon, Icons.forum_outlined);
      expect(
        _notification(type: 'prediction.completed').icon,
        Icons.check_circle_outline,
      );
      expect(_notification(type: 'prediction.failed').icon, Icons.error_outline);
      expect(_notification(type: 'prediction.expiring').icon, Icons.schedule);
      expect(
        _notification(type: 'access_request.submitted').icon,
        Icons.how_to_reg_outlined,
      );
      expect(_notification(type: 'model.offline').icon, Icons.memory_outlined);
    });

    group('age', () {
      test('is empty without a timestamp', () {
        expect(_notification().age, '');
      });

      test('counts in minutes, hours, days and weeks', () {
        final now = DateTime.now();

        expect(
          _notification(createdAt: now.subtract(const Duration(seconds: 20))).age,
          'just now',
        );
        expect(
          _notification(createdAt: now.subtract(const Duration(minutes: 12))).age,
          '12m',
        );
        expect(
          _notification(createdAt: now.subtract(const Duration(hours: 5))).age,
          '5h',
        );
        expect(
          _notification(createdAt: now.subtract(const Duration(days: 3))).age,
          '3d',
        );
        expect(
          _notification(createdAt: now.subtract(const Duration(days: 15))).age,
          '2w',
        );
      });
    });
  });

  group('NotificationBell', () {
    tearDown(() => NotificationBell.debugCounts = null);

    testWidgets('shows no badge when nothing is unread', (tester) async {
      NotificationBell.debugCounts = () async => (notifications: 0, messages: 0);

      await tester.pumpWidget(_host(const NotificationBell()));
      await tester.pump();

      expect(find.byIcon(Icons.notifications_none), findsOneWidget);
      expect(find.byIcon(Icons.notifications_active), findsNothing);
      expect(find.text('0'), findsNothing);
    });

    testWidgets('shows the count when something is waiting', (tester) async {
      NotificationBell.debugCounts = () async => (notifications: 3, messages: 1);

      await tester.pumpWidget(_host(const NotificationBell()));
      await tester.pump();

      expect(find.byIcon(Icons.notifications_active), findsOneWidget);
      expect(find.text('3'), findsOneWidget);
    });

    testWidgets('caps the badge at 99+', (tester) async {
      NotificationBell.debugCounts = () async =>
          (notifications: 240, messages: 0);

      await tester.pumpWidget(_host(const NotificationBell()));
      await tester.pump();

      expect(find.text('99+'), findsOneWidget);
    });

    testWidgets('hands both counts to the shell', (tester) async {
      // One request feeds the bell *and* the Messages badge; the shell needs
      // the second number and should not fetch it again.
      int? notifications;
      int? messages;

      NotificationBell.debugCounts = () async => (notifications: 2, messages: 5);

      await tester.pumpWidget(
        _host(
          NotificationBell(
            onCounts: (n, m) {
              notifications = n;
              messages = m;
            },
          ),
        ),
      );
      await tester.pump();

      expect(notifications, 2);
      expect(messages, 5);
    });

    testWidgets('a failed poll leaves the bell quiet', (tester) async {
      // A badge is never worth an error banner.
      NotificationBell.debugCounts = () async => throw Exception('offline');

      await tester.pumpWidget(_host(const NotificationBell()));
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(find.byIcon(Icons.notifications_none), findsOneWidget);
    });
  });
}
