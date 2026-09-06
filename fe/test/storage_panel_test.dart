import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fe/models/storage_report.dart';
import 'package:fe/widgets/storage_panel.dart';

Widget _host(Widget child) => MaterialApp(
  home: Scaffold(body: SingleChildScrollView(child: child)),
);

StorageReport _report({
  bool mounted = true,
  int? free = 40 * 1024 * 1024 * 1024,
  int? total = 100 * 1024 * 1024 * 1024,
  int predictions = 0,
  int datasets = 0,
  int evidence = 0,
  int temporary = 0,
}) => StorageReport(
  mounted: mounted,
  sentinelEnforced: true,
  freeBytes: free,
  totalBytes: total,
  predictionBytes: predictions,
  datasetBytes: datasets,
  evidenceBytes: evidence,
  temporaryBytes: temporary,
);

void main() {
  tearDown(() => StoragePanel.debugLoader = null);

  group('StorageReport', () {
    test('separates what retention reclaims from what it does not', () {
      // The number that decides whether a full volume is a problem or a
      // Tuesday. Datasets are reclaimed by nobody.
      final report = _report(
        predictions: 800,
        temporary: 200,
        datasets: 5000,
        evidence: 50,
      );

      expect(report.reclaimableBytes, 1000);
      expect(report.datasetBytes, 5000);
    });

    test('works out how full the volume is', () {
      final report = _report(
        free: 25 * 1024 * 1024 * 1024,
        total: 100 * 1024 * 1024 * 1024,
      );

      expect(report.usedFraction, closeTo(0.75, 0.001));
    });

    test('a volume that will not report its size yields no fraction', () {
      // Some filesystems do not answer, and a bar drawn from a guess is worse
      // than no bar.
      final report = _report(free: null, total: null);

      expect(report.usedFraction, isNull);
      expect(report.usedBytes, isNull);
    });

    test('reads the payload the server actually sends', () {
      final report = StorageReport.fromJson(const {
        'mounted': false,
        'sentinel_enforced': true,
        'free_bytes': 1024,
        'total_bytes': 4096,
        'breakdown': {
          'predictions': 100,
          'evidence': 20,
          'training_datasets': 900,
          'temporary': 5,
        },
      });

      expect(report.mounted, isFalse);
      expect(report.predictionBytes, 100);
      expect(report.datasetBytes, 900);
      expect(report.reclaimableBytes, 105);
    });

    test('formats sizes the way the panel reads them', () {
      expect(StorageReport.human(512), '512 B');
      expect(StorageReport.human(1536), '1.5 KB');
      expect(StorageReport.human(2 * 1024 * 1024 * 1024), '2.0 GB');
    });
  });

  group('StoragePanel', () {
    testWidgets('says plainly when the volume is not mounted', (tester) async {
      // The one state worth shouting about: writes into an absent share
      // succeed, so nothing else in the system reports it.
      StoragePanel.debugLoader = () async => _report(mounted: false);

      await tester.pumpWidget(_host(const StoragePanel()));
      await tester.pump();

      expect(find.textContaining('not mounted'), findsOneWidget);
    });

    testWidgets('shows the breakdown once it has an answer', (tester) async {
      StoragePanel.debugLoader = () async => _report(
        predictions: 3 * 1024 * 1024 * 1024,
        datasets: 1024 * 1024 * 1024,
      );

      await tester.pumpWidget(_host(const StoragePanel()));
      await tester.pump();

      expect(find.byKey(const Key('storage-panel')), findsOneWidget);
      expect(find.textContaining('Predictions 3.0 GB'), findsOneWidget);
      expect(find.textContaining('Datasets 1.0 GB'), findsOneWidget);
      expect(find.textContaining('reclaims within a day'), findsOneWidget);
    });

    testWidgets('draws nothing at all when it cannot reach the server', (
      tester,
    ) async {
      // A storage panel must not be able to take the dashboard with it.
      StoragePanel.debugLoader = () async => throw Exception('offline');

      await tester.pumpWidget(_host(const StoragePanel()));
      await tester.pump();

      expect(find.byKey(const Key('storage-panel')), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });
}
