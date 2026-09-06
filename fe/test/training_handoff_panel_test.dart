import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fe/models/training.dart';
import 'package:fe/widgets/training_handoff_panel.dart';

/// The panel of finished training runs, on the Model Management screen.
///
/// It is the only way out of the training pipeline — registering weights *is*
/// creating a model version — so it has to stay on that screen. What it must
/// not do is take the screen over.
///
/// It used to be an unbounded `Column` sitting beside the model grid's
/// `Expanded`, so every finished run stole about 57px from the grid,
/// permanently and with no way to get it back. Eight runs cost roughly 450px:
/// on a laptop the grid was down to a single row, on a phone there was no grid
/// left. The one control offered for clearing the panel is DELETE, and DELETE
/// destroys the weights — which is how eight completed runs came to be deleted
/// in under two minutes.
///
/// So the rule these tests hold: the panel announces itself, and it scrolls
/// inside its own bounds. What it costs the grid does not depend on how many
/// runs are waiting.
void main() {
  /// The panel must never cost the model grid more than this.
  ///
  /// Two rows plus the heading. Enough that the panel is unmistakably there
  /// and its first entry is actionable without scrolling; little enough that
  /// the grid above it stays a grid.
  const maxPanelHeight = 260.0;

  TrainingJob job(int id) => TrainingJob(
        id: id,
        name: 'run-$id',
        status: 'completed',
        currentEpoch: 10,
        totalEpochs: 10,
        hasWeights: true,
      );

  List<TrainingJob> jobs(int n) => [for (var i = 1; i <= n; i++) job(i)];

  /// Mirrors the screen: the grid takes what is left, the panel takes its
  /// natural height beneath it.
  Future<Size> pump(WidgetTester tester, List<TrainingJob> list,
      {Size surface = const Size(1440, 900)}) async {
    await tester.binding.setSurfaceSize(surface);
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Column(
          children: [
            const Expanded(child: SizedBox.shrink()),
            TrainingHandoffPanel(
              jobs: list,
              onRegister: (_) {},
              onDelete: (_) {},
            ),
          ],
        ),
      ),
    ));

    return tester.getSize(find.byType(TrainingHandoffPanel));
  }

  testWidgets('a pile of finished runs stops costing the grid more space',
      (tester) async {
    final six = await pump(tester, jobs(6));
    final twelve = await pump(tester, jobs(12));

    expect(twelve.height, six.height,
        reason: 'twelve waiting runs must not take more room than six');
  });

  testWidgets('the panel never takes more than its share of the screen',
      (tester) async {
    final size = await pump(tester, jobs(12));

    expect(size.height, lessThanOrEqualTo(maxPanelHeight));
  });

  testWidgets('one waiting run does not reserve the whole allowance',
      (tester) async {
    final size = await pump(tester, jobs(1));

    expect(size.height, lessThan(maxPanelHeight),
        reason: 'a single run should not hold space open for runs that are '
            'not there');
  });

  testWidgets('runs past the fold are scrolled to, not cut off', (tester) async {
    await pump(tester, jobs(12));

    final scroller = find.descendant(
      of: find.byType(TrainingHandoffPanel),
      matching: find.byType(Scrollable),
    );
    expect(scroller, findsOneWidget);

    await tester.scrollUntilVisible(find.text('run-12'), 200,
        scrollable: scroller);

    expect(find.text('run-12'), findsOneWidget,
        reason: 'the last run must be reachable');
  });

  testWidgets('the heading says how many are waiting', (tester) async {
    await pump(tester, jobs(8));

    expect(
      find.text('Training runs ready to register (8)'),
      findsOneWidget,
      reason: 'a panel that scrolls hides its own length unless it says it',
    );
  });

  testWidgets('no runs draws nothing at all', (tester) async {
    final size = await pump(tester, const []);

    expect(size.height, 0);
    expect(find.textContaining('ready to register'), findsNothing);
  });

  testWidgets('it lays out on a phone without overflowing', (tester) async {
    await pump(tester, jobs(6), surface: const Size(360, 780));

    expect(tester.takeException(), isNull);
  });
}
