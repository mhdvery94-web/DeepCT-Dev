import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:fe/main.dart';
import 'package:fe/screens/landing/landing_page.dart';

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
    // The default 800x600 test surface is shorter than any viewport this app
    // targets, and the landing page overflows in it. Use a desktop-sized
    // surface so the test exercises a layout the app actually supports.
    tester.view.physicalSize = const Size(1440, 1024);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const MyApp());

    // One extra frame lets the async auth check settle.
    await tester.pump();

    expect(find.byType(LandingPage), findsOneWidget);
  });
}
