import 'package:flutter/material.dart';

import '../services/api_client.dart';
import '../services/me_service.dart';
import '../theme/app_theme.dart';
import 'app_dialog.dart';

/// Change your own password. Serves both consoles -- `/api/me/password`
/// works for any signed-in role -- so there is one of these rather than an
/// admin copy and a researcher copy.
///
/// Returns the backend's confirmation message on success (worth showing: it
/// says other devices were signed out), or null if the dialog was cancelled.
Future<String?> showChangePasswordDialog(BuildContext context) {
  return showAppDialog<String>(
    context: context,
    barrierDismissible: false,
    maxWidth: 420,
    builder: (_) => const ChangePasswordForm(),
  );
}

/// The form itself, so the mandatory first-sign-in screen can reuse it rather
/// than growing a second copy that drifts.
class ChangePasswordForm extends StatefulWidget {
  /// Drops CANCEL and changes the copy: this is the screen a user meets when
  /// their account is still on the published default password, and there is
  /// nowhere else for them to go.
  final bool mandatory;

  /// Called instead of `Navigator.pop` when [mandatory]. The gate above swaps
  /// the console in once the provider learns the flag is cleared.
  final void Function(String message)? onChanged;

  const ChangePasswordForm({
    super.key,
    this.mandatory = false,
    this.onChanged,
  });

  @override
  State<ChangePasswordForm> createState() => _ChangePasswordFormState();
}

class _ChangePasswordFormState extends State<ChangePasswordForm> {
  final MeService _service = MeService();
  final _formKey = GlobalKey<FormState>();

  final _currentController = TextEditingController();
  final _newController = TextEditingController();
  final _confirmController = TextEditingController();

  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _currentController.dispose();
    _newController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      final message = await _service.changePassword(
        currentPassword: _currentController.text,
        newPassword: _newController.text,
        newPasswordConfirmation: _confirmController.text,
      );

      if (!mounted) return;

      if (widget.mandatory) {
        widget.onChanged?.call(message);
        return;
      }

      Navigator.pop(context, message);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = e.message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.mandatory ? 'Choose your password' : 'Change password',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              widget.mandatory
                  ? 'This account is still on the password an administrator '
                        'issued, which is the same for everyone and written '
                        'down in the handbook. Pick your own to continue.'
                  : 'Signing other devices out is part of the point, so this '
                        'ends every other session on the account.',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: AppTheme.textMuted),
            ),
            const SizedBox(height: 20),

            _field(
              context,
              label: widget.mandatory
                  ? 'PASSWORD YOU WERE GIVEN'
                  : 'CURRENT PASSWORD',
              controller: _currentController,
              validator: (v) => (v == null || v.isEmpty)
                  ? 'Enter your current password'
                  : null,
            ),
            const SizedBox(height: 16),
            _field(
              context,
              label: 'NEW PASSWORD',
              controller: _newController,
              validator: (v) {
                if (v == null || v.isEmpty) return 'Enter a new password';
                if (v.length < 8) return 'At least 8 characters';
                return null;
              },
            ),
            const SizedBox(height: 16),
            _field(
              context,
              label: 'CONFIRM NEW PASSWORD',
              controller: _confirmController,
              validator: (v) {
                if (v != _newController.text) return 'Passwords do not match';
                return null;
              },
            ),

            if (_error != null) ...[
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.errorLight,
                  border: Border.all(color: AppTheme.error),
                ),
                child: Text(
                  _error!,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ],

            const SizedBox(height: 20),
            Row(
              children: [
                if (!widget.mandatory)
                  TextButton(
                    onPressed: _busy ? null : () => Navigator.pop(context),
                    child: const Text('CANCEL'),
                  ),
                const Spacer(),
                ElevatedButton(
                  onPressed: _busy ? null : _submit,
                  child: _busy
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(widget.mandatory ? 'SET PASSWORD' : 'SAVE'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _field(
    BuildContext context, {
    required String label,
    required TextEditingController controller,
    required String? Function(String?) validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.labelMedium),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          obscureText: true,
          validator: validator,
          decoration: const InputDecoration(
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.zero,
              borderSide: BorderSide(color: AppTheme.error, width: 2),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.zero,
              borderSide: BorderSide(color: AppTheme.error, width: 2),
            ),
          ),
        ),
      ],
    );
  }
}
