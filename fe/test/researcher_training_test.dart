import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fe/screens/user/training_screen.dart';
import 'package:fe/services/researcher_training_service.dart';

Widget _host(Widget child) => MaterialApp(home: Scaffold(body: child));

/// A tall surface, because the finders do not scroll.
///
/// The screen is one long column — the start card, then the list — and on the
/// default 800x600 test viewport everything below the card is laid out but off
/// screen, so `find` reports nothing and the failure reads as "it did not
/// render" rather than "you cannot see it".
Future<void> _pump(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1200, 3000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(_host(const TrainingScreen()));
  await tester.pumpAndSettle();
}

TrainingRun _run({
  int id = 1,
  String name = 'Balanced-t retrain',
  String status = 'running',
  int currentEpoch = 2,
  int totalEpochs = 10,
  List<TrainingPoint> history = const [],
}) => TrainingRun(
  id: id,
  name: name,
  status: status,
  totalEpochs: totalEpochs,
  currentEpoch: currentEpoch,
  progressPercent: totalEpochs == 0 ? 0 : currentEpoch / totalEpochs * 100,
  history: history,
);

void main() {
  tearDown(() => TrainingScreen.debugLoader = null);

  testWidgets('an empty list says so rather than showing nothing', (
    tester,
  ) async {
    TrainingScreen.debugLoader = () async =>
        (runs: <TrainingRun>[], trainerAvailable: true);

    await _pump(tester);

    expect(find.textContaining('No training runs yet'), findsOneWidget);
  });

  /// A researcher should learn that nothing can start *before* uploading a
  /// dataset, not after waiting for a queue that cannot move.
  testWidgets('warns up front when no trainer is registered', (tester) async {
    TrainingScreen.debugLoader = () async =>
        (runs: <TrainingRun>[], trainerAvailable: false);

    await _pump(tester);

    expect(
      find.textContaining('No trainer endpoint is registered'),
      findsOneWidget,
    );
  });

  testWidgets('says nothing about trainers when one is available', (
    tester,
  ) async {
    TrainingScreen.debugLoader = () async =>
        (runs: <TrainingRun>[], trainerAvailable: true);

    await _pump(tester);

    expect(find.textContaining('No trainer endpoint is registered'), findsNothing);
  });

  /// The result view is the point of the feature: a run's numbers, epoch by
  /// epoch, with the columns taken from what was actually reported.
  testWidgets('an expanded run shows a row per epoch', (tester) async {
    TrainingScreen.debugLoader = () async => (
      runs: [
        _run(
          history: const [
            TrainingPoint(epoch: 1, metrics: {'loss': 0.42, 'psnr': 24.1}),
            TrainingPoint(epoch: 2, metrics: {'loss': 0.31, 'psnr': 26.8}),
          ],
        ),
      ],
      trainerAvailable: true,
    );

    await _pump(tester);

    await tester.tap(find.text('Balanced-t retrain'));
    await tester.pumpAndSettle();

    // Columns come from the data, so a notebook that starts reporting
    // something new needs no change in the client.
    expect(find.text('LOSS'), findsOneWidget);
    expect(find.text('PSNR'), findsOneWidget);
    expect(find.text('0.4200'), findsOneWidget);
    expect(find.text('26.8000'), findsOneWidget);
  });

  testWidgets('a run with nothing reported yet says so', (tester) async {
    TrainingScreen.debugLoader = () async =>
        (runs: [_run(status: 'queued', currentEpoch: 0)], trainerAvailable: true);

    await _pump(tester);

    await tester.tap(find.text('Balanced-t retrain'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Nothing reported yet'), findsOneWidget);
  });

  /// Cancelling something already finished is a request the server refuses,
  /// so the button should not be there to press.
  testWidgets('a finished run offers no cancel', (tester) async {
    TrainingScreen.debugLoader = () async => (
      runs: [_run(status: 'completed', currentEpoch: 10)],
      trainerAvailable: true,
    );

    await _pump(tester);

    expect(find.text('CANCEL'), findsNothing);
  });

  testWidgets('a running one does', (tester) async {
    TrainingScreen.debugLoader = () async =>
        (runs: [_run()], trainerAvailable: true);

    await _pump(tester);

    expect(find.text('CANCEL'), findsOneWidget);
  });
}
