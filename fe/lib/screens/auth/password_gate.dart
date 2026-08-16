import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/auth_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/change_password_dialog.dart';

/// Stands between a signed-in account and its console until the account is off
/// the default password.
///
/// Accounts are created by an administrator, or by approving a request from
/// the landing page, and every one starts on the same published default. An
/// account left on it is effectively public. Nothing but the platform can
/// insist otherwise, so this does.
///
/// A screen rather than a dialog: a dialog can be dismissed by the system back
/// gesture, and a "required" step that a swipe skips is not required at all.
class PasswordGate extends StatelessWidget {
  final Widget child;

  const PasswordGate({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;

    if (user == null || !user.mustChangePassword) return child;

    return const _ForcedPasswordChangeScreen();
  }
}

class _ForcedPasswordChangeScreen extends StatelessWidget {
  const _ForcedPasswordChangeScreen();

  @override
  Widget build(BuildContext context) {
    final auth = context.read<AuthProvider>();

    return PopScope(
      // There is nowhere to go back to: the console is on the other side of
      // this form, and the landing page is a sign-out away.
      canPop: false,
      child: Scaffold(
        backgroundColor: AppTheme.background,
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 460),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        color: AppTheme.surface,
                        border: Border.all(color: AppTheme.border),
                      ),
                      child: ChangePasswordForm(
                        mandatory: true,
                        onChanged: (message) {
                          // Clearing the flag is what swaps the console in:
                          // the gate watches the provider.
                          auth.clearMustChangePassword();

                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(message),
                              backgroundColor: AppTheme.success,
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextButton(
                      onPressed: () async {
                        await auth.logout();
                        if (!context.mounted) return;
                        Navigator.of(
                          context,
                        ).popUntil((route) => route.isFirst);
                      },
                      child: const Text('SIGN OUT INSTEAD'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
