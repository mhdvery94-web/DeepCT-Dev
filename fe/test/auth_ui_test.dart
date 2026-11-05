import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import 'package:fe/screens/auth/login_page.dart';
import 'package:fe/screens/auth/password_reset_request_page.dart';
import 'package:fe/services/auth_provider.dart';
import 'package:fe/theme/app_theme.dart';

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  testWidgets('mobile login exposes the administrator-reviewed reset flow', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => AuthProvider(),
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          home: const LoginPage(),
        ),
      ),
    );

    expect(find.byKey(const Key('reset-password-link')), findsOneWidget);
    await tester.tap(find.byKey(const Key('reset-password-link')));
    await tester.pumpAndSettle();

    expect(find.byType(PasswordResetRequestPage), findsOneWidget);
    expect(find.byKey(const Key('reset-email-field')), findsOneWidget);
    expect(find.byKey(const Key('reset-phone-field')), findsOneWidget);
    expect(find.byKey(const Key('reset-back-button')), findsOneWidget);
  });
}
