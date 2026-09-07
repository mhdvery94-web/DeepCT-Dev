import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fe/models/pagination.dart';
import 'package:fe/models/prediction.dart';
import 'package:fe/screens/user/prediction_history_screen.dart';
import 'package:fe/services/prediction_service.dart';

/// An upload that was never started must be startable from the results list.
///
/// The gap this pins: `PredictionIntake` files a record as `uploaded`, and the
/// upload screen is the only thing that ever called `start()`. A researcher who
/// uploaded and then switched tabs left a record no worker would ever claim —
/// visible in the list, describing itself as waiting, and waiting forever.
class _FakePredictionService extends PredictionService {
  _FakePredictionService(this.items);

  List<Prediction> items;
  final List<int> started = [];

  @override
  Future<PaginatedResult<Prediction>> list({
    int page = 1,
    int perPage = 15,
    String? status,
  }) async => PaginatedResult<Prediction>(
    items: items,
    pagination: Pagination(
      currentPage: 1,
      lastPage: 1,
      perPage: perPage,
      total: items.length,
    ),
  );

  @override
  Future<void> start(int id) async {
    started.add(id);
    // What the server does: `uploaded` becomes `pending` and a job is queued.
    items = items
        .map((p) => p.id == id ? _record(id: p.id, status: 'pending') : p)
        .toList();
  }
}

Prediction _record({required int id, required String status}) =>
    Prediction.fromJson({
      'id': id,
      'job_id': 'job-$id',
      'status': status,
      'input_files_count': 12,
      'output_files_count': 0,
      'created_at': '2026-09-07T08:00:00.000000Z',
      'model': {'id': 1, 'name': 'deepCT', 'version': 'v1.0'},
    });

void main() {
  // Not pumpAndSettle: the screen polls every 10s while anything is pending or
  // processing, so a tree holding one of those never settles.
  Future<void> pump(WidgetTester tester, _FakePredictionService service) async {
    await tester.pumpWidget(
      MaterialApp(home: PredictionHistoryScreen(service: service)),
    );
    await tester.pump();
    await tester.pump();
  }

  /// Unmounts the screen so its poll timer is cancelled before the test ends.
  Future<void> tutup(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  }

  testWidgets('an uploaded record offers a way to start it', (tester) async {
    final service = _FakePredictionService([
      _record(id: 7, status: 'uploaded'),
    ]);

    await pump(tester, service);

    expect(
      find.byKey(const Key('prediction-start-7')),
      findsOneWidget,
      reason: 'an upload nobody started is the whole reason this button exists',
    );
  });

  testWidgets('tapping it asks the server to queue that record', (
    tester,
  ) async {
    final service = _FakePredictionService([
      _record(id: 7, status: 'uploaded'),
    ]);

    await pump(tester, service);
    await tester.tap(find.byKey(const Key('prediction-start-7')));
    await tester.pump();
    await tester.pump();

    expect(service.started, [7]);
    await tutup(tester);
  });

  testWidgets('an unstarted upload is not labelled as queued', (tester) async {
    final service = _FakePredictionService([
      _record(id: 7, status: 'uploaded'),
    ]);

    await pump(tester, service);

    // The badge fell through to QUEUED for anything not completed, failed or
    // processing. Nothing had queued this record, and saying so sent the
    // researcher away to wait for a worker that was never coming.
    expect(find.text('QUEUED'), findsNothing);
    expect(find.text('NOT STARTED'), findsOneWidget);
  });

  testWidgets('a record that really is queued still says so', (tester) async {
    final service = _FakePredictionService([
      _record(id: 11, status: 'pending'),
    ]);

    await pump(tester, service);

    expect(find.text('QUEUED'), findsOneWidget);
    await tutup(tester);
  });

  testWidgets('a record already running offers no start button', (
    tester,
  ) async {
    final service = _FakePredictionService([
      _record(id: 8, status: 'processing'),
      _record(id: 9, status: 'completed'),
      _record(id: 10, status: 'pending'),
    ]);

    await pump(tester, service);

    for (final id in [8, 9, 10]) {
      expect(
        find.byKey(Key('prediction-start-$id')),
        findsNothing,
        reason: 'starting a job twice would put two workers on one folder',
      );
    }
    await tutup(tester);
  });
}
