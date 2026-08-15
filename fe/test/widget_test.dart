import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:fe/main.dart';
import 'package:fe/screens/landing/landing_page.dart';

/// Renders the whole app at [size] and returns once it has settled.
Future<void> _pumpAppAt(WidgetTester tester, Size size) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(const MyApp());

  // One extra frame lets the async auth check settle.
  await tester.pump();
}

void main() {
  setUpAll(() {
    // Tests have no network; fall back to bundled font metrics instead of
    // trying to fetch Lora / IBM Plex Sans at runtime.
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  setUp(() {
    // No stored credentials, so AuthProvider.checkAuthStatus() finds no token.
    // Without this the secure-storage plugin channel is missing under test.
    FlutterSecureStorage.setMockInitialValues({});
  });

  testWidgets('boots to the public landing page when no token is stored',
      (WidgetTester tester) async {
    await _pumpAppAt(tester, const Size(1440, 1024));

    expect(find.byType(LandingPage), findsOneWidget);
  });

  // The landing page was a fixed desktop layout: a hard-coded `height: 800`
  // hero and a footer Row that overflowed by ~579px at phone widths. Every
  // breakpoint gets rendered here so that cannot regress unnoticed.
  group('landing page lays out without overflow', () {
    const viewports = <String, Size>{
      'phone': Size(390, 844),
      'small phone': Size(360, 640),
      'tablet': Size(768, 1024),
      'desktop': Size(1440, 1024),
      'short desktop': Size(1280, 720),
    };

    for (final entry in viewports.entries) {
      testWidgets('at ${entry.key} (${entry.value.width.toInt()}x'
          '${entry.value.height.toInt()})', (WidgetTester tester) async {
        await _pumpAppAt(tester, entry.value);

        expect(find.byType(LandingPage), findsOneWidget);

        // A RenderFlex overflow is reported as a FlutterError during layout,
        // which the test binding records rather than throwing. Anything
        // recorded here means the page does not fit this viewport.
        expect(
          tester.takeException(),
          isNull,
          reason: 'layout overflowed at ${entry.key}',
        );
      });
    }
  });
}
