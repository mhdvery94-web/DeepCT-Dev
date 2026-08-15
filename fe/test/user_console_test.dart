import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fe/models/activity_log.dart';
import 'package:fe/models/me_stats.dart';
import 'package:fe/screens/user/user_activity_tile.dart';

/// Wraps a widget in the minimum needed to pump it.
Widget _host(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  group('MeStats.fromJson', () {
    test('reads the full payload', () {
      final stats = MeStats.fromJson(const {
        'activities_total': 19,
        'activities_today': 4,
        'analyses_total': 3,
        'analyses_by_status': {
          'pending': 1,
          'processing': 0,
          'completed': 2,
          'failed': 0,
        },
        'models_online': 1,
        'models_total': 2,
      });

      expect(stats.activitiesTotal, 19);
      expect(stats.activitiesToday, 4);
      expect(stats.analysesTotal, 3);
      expect(stats.analysesCompleted, 2);
      expect(stats.analysesPending, 1);
      expect(stats.modelsOnline, 1);
      expect(stats.modelsTotal, 2);
      expect(stats.canRunAnalysis, isTrue);
      expect(stats.modelStatusLabel, 'Online');
    });

    test('survives a payload with missing keys', () {
      final stats = MeStats.fromJson(const {});

      expect(stats.activitiesTotal, 0);
      expect(stats.analysesTotal, 0);
      expect(stats.analysesFailed, 0);
      expect(stats.canRunAnalysis, isFalse);
      // No models registered at all reads differently from "all offline".
      expect(stats.modelStatusLabel, 'No model registered');
    });

    test('distinguishes offline from unregistered', () {
      final stats = MeStats.fromJson(const {
        'models_online': 0,
        'models_total': 1,
      });

      expect(stats.canRunAnalysis, isFalse);
      expect(stats.modelStatusLabel, 'Offline');
    });

    test('coerces numeric strings, as MySQL/PDO can return them', () {
      final stats = MeStats.fromJson(const {
        'activities_total': '7',
        'models_online': '1',
      });

      expect(stats.activitiesTotal, 7);
      expect(stats.modelsOnline, 1);
    });
  });

  group('UserActivityTile', () {
    ActivityLog log({
      String type = 'login',
      String? description = 'User logged in',
      DateTime? createdAt,
      String? ip = '127.0.0.1',
    }) {
      return ActivityLog(
        id: 1,
        activityType: type,
        description: description,
        createdAt: createdAt,
        ipAddress: ip,
      );
    }

    testWidgets('shows the description and a relative time', (tester) async {
      await tester.pumpWidget(
        _host(
          UserActivityTile(
            activity: log(
              createdAt: DateTime.now().subtract(const Duration(minutes: 5)),
            ),
          ),
        ),
      );

      expect(find.text('User logged in'), findsOneWidget);
      expect(find.textContaining('5m ago'), findsOneWidget);
      expect(find.text('LOGIN'), findsOneWidget);
    });

    testWidgets('falls back to the type label when description is null', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          UserActivityTile(
            activity: log(type: 'create_user', description: null),
          ),
        ),
      );

      // ActivityLog.typeLabel turns create_user into "Create User".
      expect(find.text('Create User'), findsOneWidget);
    });

    testWidgets('does not crash when the timestamp is missing', (tester) async {
      await tester.pumpWidget(
        _host(UserActivityTile(activity: log(createdAt: null))),
      );

      expect(find.textContaining('unknown time'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('renders an absolute timestamp when asked', (tester) async {
      await tester.pumpWidget(
        _host(
          UserActivityTile(
            activity: log(createdAt: DateTime.utc(2026, 8, 15, 9, 5)),
            showAbsoluteTime: true,
          ),
        ),
      );

      // Rendered in local time, so assert on the zero-padded shape rather than
      // an exact clock value.
      expect(
        find.textContaining(RegExp(r'\d{2}/\d{2}/2026 \d{2}:\d{2}')),
        findsOneWidget,
      );
    });

    testWidgets('lays out on a phone-width row without overflow', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(360, 200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        _host(
          UserActivityTile(
            activity: log(
              type: 'analysis_completed',
              description:
                  'A deliberately long description that should wrap '
                  'rather than overflow the row on a narrow screen.',
              createdAt: DateTime.now(),
            ),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
    });
  });
}
