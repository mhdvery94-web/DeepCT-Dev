import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fe/screens/user/training_screen.dart';
import 'dart:typed_data';

import 'package:fe/models/prediction_frame.dart';
import 'package:fe/services/upload_resume_store.dart';
import 'package:fe/utils/archive_source.dart';
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

/// The list result, with the queue counters defaulted.
///
/// They were added to the record after these tests were written, and every
/// case here is about something else — spelling them out at seven call sites
/// would bury what each test is actually checking.
({List<TrainingRun> runs, bool trainerAvailable, int queuedTotal, int runningTotal})
_result({
  required List<TrainingRun> runs,
  required bool trainerAvailable,
  int queuedTotal = 0,
  int runningTotal = 0,
}) => (
  runs: runs,
  trainerAvailable: trainerAvailable,
  queuedTotal: queuedTotal,
  runningTotal: runningTotal,
);

void main() {
  _regressions();
  tearDown(() {
    TrainingScreen.debugLoader = null;
    TrainingScreen.debugDatasetLoader = null;
    TrainingScreen.debugPendingLoader = null;
    TrainingScreen.debugStarter = null;
    TrainingScreen.debugSource = null;
  });

  testWidgets('an empty list says so rather than showing nothing', (
    tester,
  ) async {
    TrainingScreen.debugLoader = () async =>
        _result(runs: <TrainingRun>[], trainerAvailable: true);

    await _pump(tester);

    expect(find.textContaining('No training runs yet'), findsOneWidget);
  });

  /// A researcher should learn that nothing can start *before* uploading a
  /// dataset, not after waiting for a queue that cannot move.
  testWidgets('warns up front when no trainer is registered', (tester) async {
    TrainingScreen.debugLoader = () async =>
        _result(runs: <TrainingRun>[], trainerAvailable: false);

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
        _result(runs: <TrainingRun>[], trainerAvailable: true);

    await _pump(tester);

    expect(find.textContaining('No trainer endpoint is registered'), findsNothing);
  });

  /// The result view is the point of the feature: a run's numbers, epoch by
  /// epoch, with the columns taken from what was actually reported.
  testWidgets('an expanded run shows a row per epoch', (tester) async {
    TrainingScreen.debugLoader = () async => _result(
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
        _result(runs: [_run(status: 'queued', currentEpoch: 0)], trainerAvailable: true);

    await _pump(tester);

    await tester.tap(find.text('Balanced-t retrain'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Nothing reported yet'), findsOneWidget);
  });

  /// Cancelling something already finished is a request the server refuses,
  /// so the button should not be there to press.
  testWidgets('a finished run offers no cancel', (tester) async {
    TrainingScreen.debugLoader = () async => _result(
      runs: [_run(status: 'completed', currentEpoch: 10)],
      trainerAvailable: true,
    );

    await _pump(tester);

    expect(find.text('CANCEL'), findsNothing);
  });

  testWidgets('a running one does', (tester) async {
    TrainingScreen.debugLoader = () async =>
        _result(runs: [_run()], trainerAvailable: true);

    await _pump(tester);

    expect(find.text('CANCEL'), findsOneWidget);
  });
}

/// The shapes that used to hang the screen, and the numbers it must show.
///
/// These are separated from the tests above because they are not about the
/// screen's behaviour so much as about its refusal to lock up: MY RUNS spun for
/// ever, on web and on the phone, and nothing anywhere said why.
void _regressions() {
  test('metrics survive arriving as a JSON list', () {
    // PHP has one array type, and `json_encode` renders the empty one as `[]`.
    // A run that had reported nothing therefore arrived as a list where a map
    // was declared — and `as Map?` on a List *throws* in Dart rather than
    // yielding null. The throw escaped a catch that only covered
    // ApiException, so `_loading` was never put back.
    expect(asMetrics(const []), isEmpty);
    expect(asMetrics(null), isEmpty);
    expect(asMetrics('nonsense'), isEmpty);
    expect(asMetrics(const {'psnr': 39.06}), {'psnr': 39.06});
  });

  testWidgets('a malformed list stops the spinner and says so', (tester) async {
    TrainingScreen.debugLoader = () async => throw StateError('bad shape');
    addTearDown(() => TrainingScreen.debugLoader = null);

    await _pump(tester);

    // The point is the absence of a spinner: any failure has to end the
    // loading state, not only the ones we predicted.
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.textContaining('Could not read the training runs'), findsOneWidget);
  });

  testWidgets('a queued run says where it is in the line', (tester) async {
    TrainingScreen.debugLoader = () async => _result(
      runs: [
        TrainingRun(
          id: 4,
          name: 'Balanced-t retrain',
          status: 'queued',
          totalEpochs: 10,
          currentEpoch: 0,
          progressPercent: 0,
          queuePosition: 3,
        ),
      ],
      trainerAvailable: true,
      queuedTotal: 4,
      runningTotal: 1,
    );
    addTearDown(() => TrainingScreen.debugLoader = null);

    await _pump(tester);

    expect(find.textContaining('Number 3 in the queue'), findsOneWidget);
    expect(find.textContaining('2 run(s) ahead'), findsOneWidget);
    // The whole trainer's load, which the researcher's own list cannot show.
    expect(find.textContaining('1 running · 4 waiting'), findsOneWidget);
  });

  testWidgets('the latest epoch numbers show without opening the row', (
    tester,
  ) async {
    TrainingScreen.debugLoader = () async => _result(
      runs: [
        _run(
          status: 'running',
          currentEpoch: 2,
          history: const [
            TrainingPoint(epoch: 1, metrics: {'psnr': 38.21, 'ssim': 0.9860}),
            TrainingPoint(epoch: 2, metrics: {'psnr': 38.79, 'ssim': 0.9862}),
          ],
        ),
      ],
      trainerAvailable: true,
    );
    addTearDown(() => TrainingScreen.debugLoader = null);

    await _pump(tester);

    // A list that hides its results behind a tap is a list of names.
    expect(find.textContaining('epoch 2'), findsWidgets);
    expect(find.textContaining('PSNR 38.79'), findsOneWidget);
  });

  testWidgets('a swept archive says so instead of blaming the archive', (
    tester,
  ) async {
    // `training:cleanup` frees the archive after the retention window and
    // keeps the row, so `archiveFrames()` returns an empty list — which reads
    // exactly like an archive that never held a frame. The run's numbers are
    // still here; the frames behind them are not, and that is a different
    // sentence.
    TrainingScreen.debugLoader = () async =>
        _result(runs: [_run(status: 'completed')], trainerAvailable: true);

    TrainingScreen.debugDatasetLoader = (_) async =>
        (frames: <PredictionFrame>[], archiveDeleted: true);

    await _pump(tester);

    // The actions live inside the expanded tile.
    await tester.tap(find.text('Balanced-t retrain'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('PREVIEW DATASET'));
    await tester.pumpAndSettle();

    expect(
      find.textContaining('retention'),
      findsOneWidget,
      reason: 'the message must say the archive expired',
    );
    expect(
      find.textContaining('No .tif frames were found'),
      findsNothing,
      reason: 'that sentence blames the archive for something we did',
    );
  });

  testWidgets('an archive that is present but empty keeps its own message', (
    tester,
  ) async {
    TrainingScreen.debugLoader = () async =>
        _result(runs: [_run(status: 'completed')], trainerAvailable: true);

    TrainingScreen.debugDatasetLoader = (_) async =>
        (frames: <PredictionFrame>[], archiveDeleted: false);

    await _pump(tester);

    // The actions live inside the expanded tile.
    await tester.tap(find.text('Balanced-t retrain'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('PREVIEW DATASET'));
    await tester.pumpAndSettle();

    expect(find.textContaining('No .tif frames were found'), findsOneWidget);
  });

  testWidgets('an interrupted dataset upload is offered back', (tester) async {
    // Training uploads are the largest thing this app sends and the least
    // likely to arrive in one piece, and until now an interrupted one had to
    // be started again from zero — while the half of it the server already
    // held sat there until its own sweep.
    TrainingScreen.debugLoader = () async =>
        _result(runs: const [], trainerAvailable: true);

    TrainingScreen.debugPendingLoader = () async => PendingUpload(
      uploadId: 'abc',
      filename: 'neutron-set.zip',
      totalSize: 8 * 1024 * 1024,
      digest: 'cafebabe',
      savedAt: DateTime.now(),
      purpose: UploadPurpose.training,
      name: 'Balanced-t retrain',
      totalEpochs: 40,
    );

    await _pump(tester);

    expect(find.textContaining('neutron-set.zip'), findsOneWidget);
    expect(find.text('DISCARD IT'), findsOneWidget);
  });

  testWidgets('nothing pending draws no banner', (tester) async {
    TrainingScreen.debugLoader = () async =>
        _result(runs: const [], trainerAvailable: true);
    TrainingScreen.debugPendingLoader = () async => null;

    await _pump(tester);

    expect(find.text('DISCARD IT'), findsNothing);
  });

  testWidgets('a pending record sends the upload to resume, not to start', (
    tester,
  ) async {
    // Otherwise the banner is decoration: it would say the server still holds
    // half the archive, and then the upload would post it all again from zero.
    TrainingScreen.debugLoader = () async =>
        _result(runs: const [], trainerAvailable: true);

    TrainingScreen.debugPendingLoader = () async => PendingUpload(
      uploadId: 'abc',
      filename: 'neutron-set.zip',
      totalSize: 8,
      digest: 'cafebabe',
      savedAt: DateTime.now(),
      purpose: UploadPurpose.training,
      name: 'Balanced-t retrain',
      totalEpochs: 40,
    );

    final calls = <String>[];
    TrainingScreen.debugStarter =
        ({
          required String name,
          required int totalEpochs,
          required ArchiveSource source,
          PendingUpload? resuming,
          void Function(double)? onProgress,
        }) async {
          calls.add(resuming == null ? 'start' : 'resume');

          return (id: 1, message: 'queued', warning: null);
        };

    await _pump(tester);

    await tester.enterText(find.byType(TextFormField).first, 'Balanced-t retrain');
    TrainingScreen.debugSource = BytesArchiveSource(
      Uint8List.fromList(const [1, 2, 3, 4, 5, 6, 7, 8]),
      filename: 'neutron-set.zip',
    );

    await tester.tap(find.text('START TRAINING'));
    await tester.pumpAndSettle();

    expect(calls, ['resume']);
  });

  testWidgets('with nothing pending it starts a new session', (tester) async {
    TrainingScreen.debugLoader = () async =>
        _result(runs: const [], trainerAvailable: true);
    TrainingScreen.debugPendingLoader = () async => null;

    final calls = <String>[];
    TrainingScreen.debugStarter =
        ({
          required String name,
          required int totalEpochs,
          required ArchiveSource source,
          PendingUpload? resuming,
          void Function(double)? onProgress,
        }) async {
          calls.add(resuming == null ? 'start' : 'resume');

          return (id: 1, message: 'queued', warning: null);
        };

    await _pump(tester);

    await tester.enterText(find.byType(TextFormField).first, 'Fresh run');
    TrainingScreen.debugSource = BytesArchiveSource(
      Uint8List.fromList(const [1, 2, 3, 4]),
      filename: 'neutron-set.zip',
    );

    await tester.tap(find.text('START TRAINING'));
    await tester.pumpAndSettle();

    expect(calls, ['start']);
  });
}
