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
