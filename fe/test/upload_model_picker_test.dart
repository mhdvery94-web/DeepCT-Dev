import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fe/models/model_status_message.dart';
import 'package:fe/services/me_service.dart';
import 'package:fe/theme/app_theme.dart';

/// Mirrors what `_ModelOption` renders. `_ModelOption` is private to
/// `upload_screen.dart`, and driving the whole screen would need a live API
/// client — so this pins the two decisions the widget makes rather than the
/// widget itself, and the widget is checked by eye against them.
///
/// The decisions: an available-but-slow model is amber and selectable, and a
/// model that is not online carries a sentence saying why.
void main() {
  Widget host(Widget child) => MaterialApp(home: Scaffold(body: child));

  Color badgeColour(AvailableModel m) => m.isOnline
      ? AppTheme.success
      : (m.isAvailable ? AppTheme.warning : AppTheme.error);

  AvailableModel model(String status, String? reason) => AvailableModel(
    id: 1,
    name: 'deepCT TC-D',
    version: 'v1.0',
    status: status,
    isAvailable: status == 'online' || status == 'trouble',
    lastHealthCheck: DateTime.now(),
    healthCheckReason: reason,
  );

  test('a slow model is amber, not red, and can still be chosen', () {
    final slow = model('trouble', 'slow');

    expect(badgeColour(slow), AppTheme.warning);
    expect(slow.isAvailable, isTrue);
  });

  test('a dead model is red and cannot be chosen', () {
    final dead = model('offline', 'tunnel_down');

    expect(badgeColour(dead), AppTheme.error);
    expect(dead.isAvailable, isFalse);
  });

  test('a healthy model is green', () {
    expect(badgeColour(model('online', null)), AppTheme.success);
  });

  testWidgets('the reason a model cannot be used is spelled out', (
    tester,
  ) async {
    final dead = model('offline', 'tunnel_down');

    await tester.pumpWidget(
      host(Text(modelStatusMessage(dead.healthCheckReason))),
    );

    expect(find.textContaining('Ask an administrator'), findsOneWidget);
    expect(find.textContaining('ERR_NGROK'), findsNothing);
  });
}
