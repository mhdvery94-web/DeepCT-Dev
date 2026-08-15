import 'package:flutter/material.dart';

import '../../services/api_client.dart';
import '../../services/support_service.dart';
import '../../theme/app_theme.dart';

/// Opens the sign-in-page support form.
///
/// Kept separate from the in-app ticket form because the reporter here is by
/// definition not signed in: they have to say who they are, and the answer
/// comes back by email rather than in the app.
Future<void> showPublicTicketSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppTheme.surface,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
    builder: (_) => const PublicTicketSheet(),
  );
}

class PublicTicketSheet extends StatefulWidget {
  const PublicTicketSheet({super.key});

  @override
  State<PublicTicketSheet> createState() => _PublicTicketSheetState();
}

class _PublicTicketSheetState extends State<PublicTicketSheet> {
  final SupportService _service = SupportService();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  final TextEditingController _name = TextEditingController();
  final TextEditingController _email = TextEditingController();
  final TextEditingController _subject = TextEditingController();
  final TextEditingController _message = TextEditingController();

  String _category = 'account';
  bool _sending = false;
  String? _error;
  String? _done;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _subject.dispose();
    _message.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() {
      _sending = true;
      _error = null;
    });

    try {
      final message = await _service.openPublic(
        name: _name.text.trim(),
        email: _email.text.trim(),
        subject: _subject.text.trim(),
        message: _message.text.trim(),
        category: _category,
      );

      if (!mounted) return;
      setState(() {
        _sending = false;
        _done = message;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _sending = false;
        _error = e.message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: SingleChildScrollView(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: _done != null ? _buildDone(context) : _buildForm(context),
        ),
      ),
    );
  }

  Widget _buildDone(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 12),
        const Icon(Icons.check_circle_outline, size: 44, color: AppTheme.success),
        const SizedBox(height: 16),
        Text('Sent', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 8),
        Text(
          _done!,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 20),
        ElevatedButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('CLOSE'),
        ),
      ],
    );
  }

  Widget _buildForm(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('IT Support', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 4),
          Text(
            'Cannot sign in, or something is broken? Describe it here and an '
            'administrator will answer by email.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 20),

          TextFormField(
            controller: _name,
            decoration: const InputDecoration(labelText: 'Your name'),
            validator: (v) =>
                (v == null || v.trim().isEmpty) ? 'Name is required' : null,
          ),
          const SizedBox(height: 16),

          TextFormField(
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(
              labelText: 'Email we should reply to',
            ),
            validator: (v) {
              if (v == null || v.trim().isEmpty) return 'Email is required';
              if (!v.contains('@') || !v.contains('.')) {
                return 'Enter a valid email address';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),

          // Side by side where there is room. On a phone the category dropdown
          // is narrower than its own longest option ("prediction") and pushes
          // the row 54px past the edge, so below 420px the two stack.
          LayoutBuilder(
            builder: (context, constraints) {
              final subject = TextFormField(
                controller: _subject,
                decoration: const InputDecoration(labelText: 'Subject'),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Subject is required'
                    : null,
              );

              final category = DropdownButtonFormField<String>(
                initialValue: _category,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Category'),
                items: [
                  for (final c in SupportService.categories)
                    DropdownMenuItem(value: c, child: Text(c)),
                ],
                onChanged: (v) => setState(() => _category = v ?? 'account'),
              );

              if (constraints.maxWidth < 420) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [subject, const SizedBox(height: 16), category],
                );
              }

              return Row(
                children: [
                  Expanded(flex: 3, child: subject),
                  const SizedBox(width: 12),
                  Expanded(flex: 2, child: category),
                ],
              );
            },
          ),
          const SizedBox(height: 16),

          TextFormField(
            controller: _message,
            minLines: 3,
            maxLines: 6,
            decoration: const InputDecoration(
              labelText: 'What is happening?',
              hintText: 'What you did, what happened, and any error message',
            ),
            validator: (v) =>
                (v == null || v.trim().isEmpty) ? 'Describe the problem' : null,
          ),

          if (_error != null) ...[
            const SizedBox(height: 14),
            Container(
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
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('CANCEL'),
              ),
              const Spacer(),
              ElevatedButton(
                onPressed: _sending ? null : _submit,
                child: _sending
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('SEND'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
