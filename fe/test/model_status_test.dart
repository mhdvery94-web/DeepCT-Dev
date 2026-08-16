import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fe/services/me_service.dart';
import 'package:fe/widgets/model_status_strip.dart';

Widget _host(Widget child) => MaterialApp(home: Scaffold(body: child));

AvailableModel _model({
  int id = 1,
  String status = 'online',
  String? error,
  DateTime? checkedAt,
}) => AvailableModel(
  id: id,
  name: 'deepCT TC-D',
  version: 'v1.0',
  status: status,
  isAvailable: status == 'online',
  lastHealthCheck: checkedAt ?? DateTime.now(),
  healthCheckError: error,
);

void main() {
  tearDown(() => ModelStatusStrip.debugLoader = null);

  testWidgets('says nothing until the first answer arrives', (tester) async {
    ModelStatusStrip.debugLoader = () async => [_model()];

    await tester.pumpWidget(_host(const ModelStatusStrip()));
    // No pump past the future: the strip must not flash an empty bar.
    expect(find.byType(Icon), findsNothing);

    await tester.pumpAndSettle();
    expect(find.text('Model online'), findsOneWidget);
  });

  testWidgets('reports an online model with how fresh the check is', (
    tester,
  ) async {
    ModelStatusStrip.debugLoader = () async => [_model()];

    await tester.pumpWidget(_host(const ModelStatusStrip()));
    await tester.pumpAndSettle();

    expect(find.text('Model online'), findsOneWidget);
    expect(find.textContaining('checked just now'), findsOneWidget);
  });

  testWidgets('shows the checker\'s own words when the model is down', (
    tester,
  ) async {
    // "Tunnel is not running" tells a researcher to restart the Kaggle
    // session. "Offline" alone does not.
    ModelStatusStrip.debugLoader = () async => [
      _model(
        status: 'offline',
        error: 'Tunnel is not running (ERR_NGROK_3200)',
      ),
    ];

    await tester.pumpWidget(_host(const ModelStatusStrip()));
    await tester.pumpAndSettle();

    expect(find.text('Model offline'), findsOneWidget);
    expect(
      find.textContaining('ERR_NGROK_3200'),
      findsOneWidget,
    );
  });

  testWidgets('distinguishes no registered model from an offline one', (
    tester,
  ) async {
    ModelStatusStrip.debugLoader = () async => const <AvailableModel>[];

    await tester.pumpWidget(_host(const ModelStatusStrip()));
    await tester.pumpAndSettle();

    expect(find.text('No active model'), findsOneWidget);
  });

  testWidgets('counts a partial outage', (tester) async {
    ModelStatusStrip.debugLoader = () async => [
      _model(id: 1),
      _model(id: 2, status: 'offline'),
    ];

    await tester.pumpWidget(_host(const ModelStatusStrip()));
    await tester.pumpAndSettle();

    expect(find.text('1 of 2 models online'), findsOneWidget);
  });

  testWidgets('an unreachable platform is not reported as an offline model', (
    tester,
  ) async {
    // Saying "model offline" when the platform itself could not be reached
    // would be a guess, and the wrong one to act on.
    ModelStatusStrip.debugLoader = () async => throw Exception('no network');

    await tester.pumpWidget(_host(const ModelStatusStrip()));
    await tester.pumpAndSettle();

    expect(find.text('Model offline'), findsNothing);
  });

  testWidgets('tells the screen when a status changes', (tester) async {
    var status = 'online';
    ModelStatusStrip.debugLoader = () async => [_model(status: status)];

    var notified = 0;
    await tester.pumpWidget(
      _host(ModelStatusStrip(onChanged: (_) => notified++)),
    );
    await tester.pumpAndSettle();

    expect(notified, 1); // the first answer counts as a change from nothing

    // A poll that finds the same status must not churn the screen behind it.
    await tester.pump(const Duration(seconds: 10));
    await tester.pumpAndSettle();
    expect(notified, 1);

    status = 'offline';
    await tester.pump(const Duration(seconds: 10));
    await tester.pumpAndSettle();
    expect(notified, 2);

    // Stop the periodic timer before the test ends.
    await tester.pumpWidget(_host(const SizedBox()));
  });
}
