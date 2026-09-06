import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:fe/main.dart';
import 'package:fe/screens/landing/landing_page.dart';
import 'package:fe/theme/app_theme.dart';
import 'package:fe/widgets/news_section.dart';

/// Renders the whole app at [size] and returns once it has settled.
///
/// [statusBarHeight] simulates the system inset a phone reserves for the
/// clock and battery icons.
Future<void> _pumpAppAt(
  WidgetTester tester,
  Size size, {
  double statusBarHeight = 0,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  tester.view.padding = FakeViewPadding(top: statusBarHeight);
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPadding);

  await tester.pumpWidget(const MyApp());

  // One extra frame lets the async auth check settle.
  await tester.pump();
}

void main() {
  setUpAll(() {
    // Tests have no network; fall back to bundled font metrics instead of
    // trying to fetch Lora / IBM Plex Sans at runtime.
    GoogleFonts.config.allowRuntimeFetching = false;

    // For the same reason: the research-news carousel on the landing page
    // loads itself, and a real request leaves a pending timeout timer that
    // fails the test regardless of what it was asserting.
    NewsSection.debugLoader = () async => const [];
  });

  tearDownAll(() => NewsSection.debugLoader = null);

  setUp(() {
    // No stored credentials, so AuthProvider.checkAuthStatus() finds no token.
    // Without this the secure-storage plugin channel is missing under test.
    FlutterSecureStorage.setMockInitialValues({});
  });

  testWidgets('boots to the public landing page when no token is stored', (
    WidgetTester tester,
  ) async {
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
      // Exactly on _navBreakpoint: the tightest width that still shows the
      // four inline tabs beside the login button.
      'nav breakpoint': Size(760, 900),
      'just below nav breakpoint': Size(759, 900),
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

  // The landing page draws its own header inside a Stack rather than using an
  // AppBar, so nothing reserved room for the system status bar and the header
  // rendered underneath the clock and battery icons.
  testWidgets('landing header clears the system status bar', (tester) async {
    const statusBarHeight = 44.0;
    await _pumpAppAt(
      tester,
      const Size(390, 844),
      statusBarHeight: statusBarHeight,
    );

    final headerTop = tester.getTopLeft(find.byKey(LandingPage.headerKey)).dy;

    expect(
      headerTop,
      greaterThanOrEqualTo(statusBarHeight),
      reason: 'header must start below the status bar, not under it',
    );
  });

  // Targeting SDK 36 means the app cannot decline to draw behind the status
  // bar, so it paints that strip itself in a distinct colour. The header must
  // begin exactly at the bottom of that strip: any more and a SafeArea is
  // reserving the same inset a second time, leaving a double gap.
  testWidgets('the status bar strip is drawn and reserved exactly once', (
    tester,
  ) async {
    const statusBarHeight = 44.0;
    await _pumpAppAt(
      tester,
      const Size(390, 844),
      statusBarHeight: statusBarHeight,
    );

    final strip = find.byWidgetPredicate(
      (w) =>
          w is Container &&
          w.color == AppTheme.systemBar &&
          w.constraints?.maxHeight == statusBarHeight,
    );
    expect(strip, findsOneWidget, reason: 'status bar strip must be painted');

    final headerTop = tester.getTopLeft(find.byKey(LandingPage.headerKey)).dy;

    expect(
      headerTop,
      statusBarHeight,
      reason: 'header must sit flush under the strip, not one inset lower',
    );
  });

  group('landing header navigation', () {
    testWidgets('shows inline tabs on a laptop-width window', (tester) async {
      await _pumpAppAt(tester, const Size(900, 800));

      expect(find.text('HOME'), findsOneWidget);
      expect(find.text('RESEARCH'), findsOneWidget);
      expect(find.byIcon(Icons.menu), findsNothing);
    });

    testWidgets('shows one login button beside the tabs', (tester) async {
      await _pumpAppAt(tester, const Size(900, 800));

      expect(find.text('LOGIN'), findsOneWidget);
    });

    testWidgets('collapses to a hamburger on a phone', (tester) async {
      await _pumpAppAt(tester, const Size(390, 844));

      expect(find.byIcon(Icons.menu), findsOneWidget);
      // The tabs live in the closed drawer, so none are on screen.
      expect(find.text('RESEARCH'), findsNothing);
    });

    testWidgets('the phone header carries no login button of its own', (
      tester,
    ) async {
      // Sign-in belongs in the drawer on a phone. Having it in both places
      // gave two LOGIN buttons a few hundred pixels apart and cost the header
      // room it does not have.
      await _pumpAppAt(tester, const Size(390, 844));

      expect(find.text('LOGIN'), findsNothing);
    });

    testWidgets('the hamburger sits in the top-right corner', (tester) async {
      const width = 390.0;
      await _pumpAppAt(tester, const Size(width, 844));

      final button = find.ancestor(
        of: find.byIcon(Icons.menu),
        matching: find.byType(IconButton),
      );

      final gap = width - tester.getTopRight(button).dx;

      // 16 is the header's own horizontal padding on a phone, so that is all
      // the gap there should ever be. `Flexible` around the brand text and
      // `Spacer` both defaulted to flex: 1 and therefore split the free space
      // between them; the half the short word "BRIN" did not use was left
      // stranded *after* the hamburger, parking it ~80px shy of the corner.
      expect(
        gap,
        lessThanOrEqualTo(17.0),
        reason: 'hamburger must sit at the right edge, not float mid-header',
      );
    });

    testWidgets('hamburger opens a drawer holding the sections and login', (
      tester,
    ) async {
      await _pumpAppAt(tester, const Size(390, 844));

      await tester.tap(find.byIcon(Icons.menu));
      await tester.pumpAndSettle();

      expect(find.text('HOME'), findsOneWidget);
      expect(find.text('RESEARCH'), findsOneWidget);
      expect(find.text('LOGIN'), findsOneWidget);
    });
  });
}
