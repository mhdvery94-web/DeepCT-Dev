import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fe/models/prediction_frame.dart';
import 'package:fe/widgets/frame_stack_viewer.dart';

/// A 1x1 transparent PNG — enough for Image.memory to decode without
/// reaching for a real frame.
final _png = Uint8List.fromList(const [
  137, 80, 78, 71, 13, 10, 26, 10, 0, 0, 0, 13, 73, 72, 68, 82,
  0, 0, 0, 1, 0, 0, 0, 1, 8, 6, 0, 0, 0, 31, 21, 196, 137,
  0, 0, 0, 10, 73, 68, 65, 84, 120, 156, 99, 0, 1, 0, 0, 5, 0,
  1, 13, 10, 45, 180, 0, 0, 0, 0, 73, 69, 78, 68, 174, 66, 96, 130,
]);

List<PredictionFrame> _frames() => const [
  PredictionFrame(name: 'frame_001.tif', kind: 'input', size: 100),
  PredictionFrame(name: 'frame_002.tif', kind: 'output', size: 100),
  PredictionFrame(name: 'frame_003.tif', kind: 'output', size: 100),
  PredictionFrame(name: 'frame_004.tif', kind: 'input', size: 100),
];

Widget _host(List<PredictionFrame> frames) => MaterialApp(
  home: FrameStackViewer(
    frames: frames,
    initialIndex: 0,
    loader: (_) async => _png,
  ),
);

void main() {
  testWidgets('a slider stands in for stepping through the stack', (
    tester,
  ) async {
    await tester.pumpWidget(_host(_frames()));
    await tester.pumpAndSettle();

    expect(find.byType(Slider), findsOneWidget);
  });

  testWidgets('the badge names what the current frame is', (tester) async {
    await tester.pumpWidget(_host(_frames()));
    await tester.pumpAndSettle();

    // Frame one is an uploaded boundary.
    expect(find.text('INPUT'), findsOneWidget);
    expect(find.text('MODEL OUTPUT'), findsNothing);
  });

  testWidgets('moving the slider moves the frame', (tester) async {
    await tester.pumpWidget(_host(_frames()));
    await tester.pumpAndSettle();

    // Frame two is generated, so the badge has to change with it.
    final slider = tester.widget<Slider>(find.byType(Slider));
    slider.onChanged!(1);
    await tester.pumpAndSettle();

    expect(find.text('MODEL OUTPUT'), findsOneWidget);
  });

  testWidgets('generated frames are marked on the slider track', (
    tester,
  ) async {
    await tester.pumpWidget(_host(_frames()));
    await tester.pumpAndSettle();

    // Two of the four frames are output, so two ticks. Seeing where the
    // model's work landed is the whole reason the slider beats arrow keys.
    expect(find.byKey(const Key('frame-tick-1')), findsOneWidget);
    expect(find.byKey(const Key('frame-tick-2')), findsOneWidget);
    expect(find.byKey(const Key('frame-tick-0')), findsNothing);
  });

  testWidgets('every frame is fetched once, not once per step', (tester) async {
    // The regression this widget was rewritten for. It used to call the loader
    // from inside a PageView's itemBuilder, so scrubbing re-fetched a frame
    // every time it came back on screen and put a spinner in between — which
    // is what made the slider feel notched rather than continuous.
    final calls = <String>[];

    await tester.pumpWidget(
      MaterialApp(
        home: FrameStackViewer(
          frames: _frames(),
          initialIndex: 0,
          loader: (name) async {
            calls.add(name);
            return _png;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(calls.length, 4);

    // Walk the whole stack twice. Not one further fetch may happen.
    final slider = tester.widget<Slider>(find.byType(Slider));
    for (var pass = 0; pass < 2; pass++) {
      for (var i = 0; i < 4; i++) {
        slider.onChanged!(i.toDouble());
        await tester.pumpAndSettle();
      }
    }

    expect(calls.length, 4);
    expect(calls.toSet().length, 4);
  });

  testWidgets('playback is held back until the stack is all in memory', (
    tester,
  ) async {
    // Animating while frames are still arriving would show the very stutter
    // the prefetch exists to remove.
    final stuck = Completer<Uint8List>();

    await tester.pumpWidget(
      MaterialApp(
        home: FrameStackViewer(
          frames: _frames(),
          initialIndex: 0,
          loader: (name) =>
              name == 'frame_004.tif' ? stuck.future : Future.value(_png),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    final play = tester.widget<IconButton>(
      find.byKey(const Key('frame-play')),
    );
    expect(play.onPressed, isNull);
    expect(find.byKey(const Key('frame-stack-loading')), findsOneWidget);

    stuck.complete(_png);
    await tester.pumpAndSettle();

    final ready = tester.widget<IconButton>(
      find.byKey(const Key('frame-play')),
    );
    expect(ready.onPressed, isNotNull);
    expect(find.byKey(const Key('frame-stack-loading')), findsNothing);
  });

  testWidgets('a stack with no generated frames shows no ticks', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(const [
        PredictionFrame(name: 'frame_001.tif', kind: 'input', size: 100),
        PredictionFrame(name: 'frame_002.tif', kind: 'input', size: 100),
      ]),
    );
    await tester.pumpAndSettle();

    // This is the state right after upload, before anything has been
    // interpolated.
    expect(find.byKey(const Key('frame-tick-0')), findsNothing);
    expect(find.byKey(const Key('frame-tick-1')), findsNothing);
  });
}
