import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'theme/app_theme.dart';
import 'services/auth_provider.dart';
import 'screens/landing/landing_page.dart';
import 'screens/admin/admin_shell.dart';
import 'screens/user/user_shell.dart';
import 'screens/auth/password_gate.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // The whole app is light-themed, so the status bar needs dark icons to stay
  // readable.
  //
  // `statusBarColor` is set for iOS and older Android only: it is a no-op for
  // apps targeting SDK 35+, and this one targets 36. The strip's colour comes
  // from [_SystemBarStrip] in the widget tree instead -- see the note there.
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark, // Android
      statusBarBrightness: Brightness.light, // iOS
    ),
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AuthProvider(),
      child: MaterialApp(
        title: 'BRIN Neural Network Portal',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        // Applied here rather than per screen so no screen can be built that
        // runs up under the clock and battery.
        builder: (context, child) => _SystemBarStrip(child: child),
        home: const AppInitializer(),
      ),
    );
  }
}

/// Gives the system status bar a strip of its own, distinct from the screen
/// underneath it.
///
/// Android 15 (API 35) made edge-to-edge mandatory and Android 16 (API 36)
/// removed the opt-out entirely, so an app targeting 36 — as this one does —
/// **cannot decline to draw behind the status bar**, and `setStatusBarColor`
/// is a no-op there. What it can still do is paint that strip itself, which is
/// what this does: the band below is the app's own pixels, coloured to read as
/// the system's territory instead of as an extension of whatever header
/// follows it. Before this, the white surface ran unbroken from the clock down
/// into the page and the app looked like it had swallowed the status bar.
///
/// [MediaQuery.removePadding] is the other half: without it every descendant
/// `SafeArea` would reserve the same inset a second time and leave a double
/// gap.
///
/// Reads `MediaQuery.padding`, the same inset `SafeArea` consumes, rather than
/// `viewPadding` — the two differ once a keyboard is up, and taking the one
/// being replaced is what keeps the arithmetic honest.
///
/// On web `padding.top` is zero, so this collapses to nothing — browsers have
/// no status bar to make room for.
class _SystemBarStrip extends StatelessWidget {
  final Widget? child;

  const _SystemBarStrip({required this.child});

  @override
  Widget build(BuildContext context) {
    final inset = MediaQuery.paddingOf(context).top;

    if (inset <= 0 || child == null) return child ?? const SizedBox.shrink();

    return Column(
      children: [
        Container(height: inset, color: AppTheme.systemBar),
        Expanded(
          child: MediaQuery.removePadding(
            context: context,
            removeTop: true,
            child: child!,
          ),
        ),
      ],
    );
  }
}

class AppInitializer extends StatefulWidget {
  const AppInitializer({super.key});

  @override
  State<AppInitializer> createState() => _AppInitializerState();
}

class _AppInitializerState extends State<AppInitializer> {
  @override
  void initState() {
    super.initState();
    _checkAuthStatus();
  }

  Future<void> _checkAuthStatus() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    await authProvider.checkAuthStatus();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, authProvider, _) {
        // Show loading while checking auth
        if (authProvider.isLoading) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(color: AppTheme.primary),
            ),
          );
        }

        // If logged in, route to appropriate dashboard
        if (authProvider.isLoggedIn) {
          // Both consoles sit behind the gate, so a stored session belonging
          // to an account still on its default password lands on the password
          // form rather than the dashboard.
          return PasswordGate(
            child: authProvider.isAdmin ? const AdminShell() : const UserShell(),
          );
        }

        // Not logged in, show landing page
        return const LandingPage();
      },
    );
  }
}
