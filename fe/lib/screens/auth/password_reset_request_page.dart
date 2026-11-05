import 'package:flutter/material.dart';

import '../../services/api_client.dart';
import '../../services/password_reset_request_service.dart';
import '../../theme/app_theme.dart';

class PasswordResetRequestPage extends StatefulWidget {
  const PasswordResetRequestPage({super.key});

  @override
  State<PasswordResetRequestPage> createState() =>
      _PasswordResetRequestPageState();
}

class _PasswordResetRequestPageState
    extends State<PasswordResetRequestPage> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _service = PasswordResetRequestService();
  bool _busy = false;
  String? _error;
  String? _message;

  @override
  void dispose() {
    _email.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final message = await _service.submit(
        email: _email.text,
        phone: _phone.text,
      );
      if (!mounted) return;
      setState(() {
        _busy = false;
        _message = message;
      });
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = error.message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        leading: IconButton(
          key: const Key('reset-back-button'),
          tooltip: 'Back to login',
          onPressed: () => Navigator.maybePop(context),
          icon: const Icon(Icons.arrow_back),
        ),
        title: const Text('Reset password'),
      ),
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Container(
                padding: const EdgeInsets.all(24),
                color: AppTheme.surface,
                child: _message != null
                    ? _buildSuccess(context)
                    : _buildForm(context),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSuccess(BuildContext context) => Column(
    children: [
      const Icon(Icons.mark_email_read_outlined,
          color: AppTheme.success, size: 48),
      const SizedBox(height: 16),
      Text('Request sent', style: Theme.of(context).textTheme.headlineSmall),
      const SizedBox(height: 8),
      Text(_message!, textAlign: TextAlign.center),
      const SizedBox(height: 24),
      OutlinedButton.icon(
        onPressed: () => Navigator.maybePop(context),
        icon: const Icon(Icons.arrow_back),
        label: const Text('BACK TO LOGIN'),
      ),
    ],
  );

  Widget _buildForm(BuildContext context) => Form(
    key: _formKey,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Request a password reset',
            style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 8),
        const Text(
          'Enter the email and phone number registered to the same active account. '
          'An administrator will verify the request before resetting your password.',
        ),
        const SizedBox(height: 24),
        TextFormField(
          key: const Key('reset-email-field'),
          controller: _email,
          keyboardType: TextInputType.emailAddress,
          autofillHints: const [AutofillHints.email],
          decoration: const InputDecoration(labelText: 'Registered email'),
          validator: (value) {
            final email = value?.trim() ?? '';
            if (email.isEmpty) return 'Email is required';
            if (!email.contains('@')) return 'Enter a valid email';
            return null;
          },
        ),
        const SizedBox(height: 18),
        TextFormField(
          key: const Key('reset-phone-field'),
          controller: _phone,
          keyboardType: TextInputType.phone,
          autofillHints: const [AutofillHints.telephoneNumber],
          decoration: const InputDecoration(
            labelText: 'Registered phone number',
            hintText: '+6281234567890',
          ),
          validator: (value) => (value?.trim().isEmpty ?? true)
              ? 'Phone number is required'
              : null,
        ),
        if (_error != null) ...[
          const SizedBox(height: 16),
          Text(_error!,
              key: const Key('reset-error'),
              style: const TextStyle(color: AppTheme.error)),
        ],
        const SizedBox(height: 24),
        ElevatedButton(
          key: const Key('reset-submit-button'),
          onPressed: _busy ? null : _submit,
          child: Text(_busy ? 'CHECKING ACCOUNT…' : 'REQUEST RESET'),
        ),
      ],
    ),
  );
}
