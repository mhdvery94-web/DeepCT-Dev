import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/access_request.dart';
import '../../models/pagination.dart';
import '../../services/access_request_service.dart';
import '../../services/api_client.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_dialog.dart';
import '../../widgets/async_state_views.dart';
import '../../widgets/pagination_bar.dart';

/// The "Join Research" queue: who has asked for an account, and what came of it.
///
/// Approving here creates the account outright and returns its one-time
/// password. That password is shown once and stored nowhere readable, so the
/// dialog makes it copyable rather than expecting the admin to retype it.
class AccessRequestsScreen extends StatefulWidget {
  const AccessRequestsScreen({super.key});

  @override
  State<AccessRequestsScreen> createState() => _AccessRequestsScreenState();
}

class _AccessRequestsScreenState extends State<AccessRequestsScreen> {
  final AccessRequestService _service = AccessRequestService();

  List<AccessRequest> _items = const [];
  Pagination _pagination = const Pagination.empty();
  int _pendingCount = 0;

  bool _isLoading = true;
  String? _error;
  int _page = 1;
  String? _statusFilter;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final result = await _service.list(page: _page, status: _statusFilter);

      if (!mounted) return;
      setState(() {
        _items = result.page.items;
        _pagination = result.page.pagination;
        _pendingCount = result.pendingCount;
        _isLoading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _isLoading = false;
      });
    }
  }

  Future<void> _approve(AccessRequest request) async {
    final note = await _askForNote(
      title: 'Approve ${request.fullName}',
      body:
          'This creates an account for ${request.email} straight away and '
          'returns its one-time password.',
      confirmLabel: 'APPROVE & CREATE ACCOUNT',
    );

    if (note == null) return;

    try {
      final account = await _service.approve(request.id, note: note);
      if (!mounted) return;
      await _showCredentials(account);
      await _load();
    } on ApiException catch (e) {
      _toast(e.message, isError: true);
    }
  }

  Future<void> _reject(AccessRequest request) async {
    final note = await _askForNote(
      title: 'Reject ${request.fullName}',
      body: 'No account is created. The reason is kept on the record.',
      confirmLabel: 'REJECT',
      destructive: true,
    );

    if (note == null) return;

    try {
      await _service.reject(request.id, note: note);
      if (!mounted) return;
      await _load();
    } on ApiException catch (e) {
      _toast(e.message, isError: true);
    }
  }

  Future<void> _delete(AccessRequest request) async {
    final confirmed = await showAppAlertDialog<bool>(
      context: context,
      title: 'Delete request',
      content: Text(
        'Remove the record for ${request.email}? Any account already '
        'created from it is left alone.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('CANCEL'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, true),
          style: ElevatedButton.styleFrom(backgroundColor: AppTheme.error),
          child: const Text('DELETE'),
        ),
      ],
    );

    if (confirmed != true) return;

    try {
      await _service.delete(request.id);
      if (!mounted) return;
      await _load();
    } on ApiException catch (e) {
      _toast(e.message, isError: true);
    }
  }

  /// Returns the note, or null if the admin backed out. An empty string is a
  /// valid answer — it means "no note", not "cancel".
  Future<String?> _askForNote({
    required String title,
    required String body,
    required String confirmLabel,
    bool destructive = false,
  }) async {
    final controller = TextEditingController();

    final result = await showAppAlertDialog<String>(
      context: context,
      title: title,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(body, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 16),
          TextField(
            controller: controller,
            maxLines: 2,
            decoration: const InputDecoration(
              labelText: 'Note (optional)',
              hintText: 'Kept on the record',
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('CANCEL'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, controller.text),
          style: destructive
              ? ElevatedButton.styleFrom(backgroundColor: AppTheme.error)
              : null,
          child: Text(confirmLabel),
        ),
      ],
    );

    controller.dispose();
    return result;
  }

  /// The password exists in readable form exactly once, here.
  Future<void> _showCredentials(ApprovedAccount account) {
    return showAppAlertDialog<void>(
      context: context,
      title: 'Account created',
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Pass these to ${account.name}. The password is not stored in '
            'readable form and cannot be shown again.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 16),
          const SizedBox(height: 8),
          _CredentialRow(label: 'Email', value: account.email),
          const SizedBox(height: 8),
          _CredentialRow(label: 'Password', value: account.defaultPassword),
        ],
      ),
      actions: [
        ElevatedButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('DONE'),
        ),
      ],
    );
  }

  void _toast(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? AppTheme.error : AppTheme.success,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isNarrow = MediaQuery.of(context).size.width < 600;

    return Padding(
      padding: EdgeInsets.all(isNarrow ? 16 : 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Access Requests',
                      style: Theme.of(context).textTheme.titleLarge,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      _pendingCount == 0
                          ? 'Nothing awaiting review'
                          : '$_pendingCount awaiting review',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Refresh',
                onPressed: _load,
                icon: const Icon(Icons.refresh, size: 20),
              ),
            ],
          ),
          const SizedBox(height: 12),

          Wrap(
            spacing: 8,
            children: [
              for (final option in const [
                (null, 'ALL'),
                ('pending', 'PENDING'),
                ('approved', 'APPROVED'),
                ('rejected', 'REJECTED'),
              ])
                _FilterChip(
                  label: option.$2,
                  selected: _statusFilter == option.$1,
                  onTap: () {
                    setState(() {
                      _statusFilter = option.$1;
                      _page = 1;
                    });
                    _load();
                  },
                ),
            ],
          ),
          const SizedBox(height: 16),

          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const LoadingView(message: 'Loading requests...');
    }

    if (_error != null) {
      return ErrorView(message: _error!, onRetry: _load);
    }

    if (_items.isEmpty) {
      return const EmptyView(
        message: 'No access requests',
        icon: Icons.how_to_reg_outlined,
      );
    }

    return Column(
      children: [
        Expanded(
          child: ListView.separated(
            itemCount: _items.length,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (context, index) => _RequestCard(
              request: _items[index],
              onApprove: () => _approve(_items[index]),
              onReject: () => _reject(_items[index]),
              onDelete: () => _delete(_items[index]),
            ),
          ),
        ),
        PaginationBar(
          pagination: _pagination,
          onPageChanged: (p) {
            setState(() => _page = p);
            _load();
          },
        ),
      ],
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? AppTheme.primary : AppTheme.surface,
          border: Border.all(
            color: selected ? AppTheme.primary : AppTheme.border,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: selected ? Colors.white : AppTheme.textMuted,
          ),
        ),
      ),
    );
  }
}

class _CredentialRow extends StatelessWidget {
  final String label;
  final String value;

  const _CredentialRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 78,
          child: Text(label, style: Theme.of(context).textTheme.labelMedium),
        ),
        Expanded(
          child: SelectableText(
            value,
            style: const TextStyle(
              fontFamily: 'monospace',
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        IconButton(
          tooltip: 'Copy',
          visualDensity: VisualDensity.compact,
          onPressed: () {
            Clipboard.setData(ClipboardData(text: value));
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text('$label copied')));
          },
          icon: const Icon(Icons.copy, size: 15),
        ),
      ],
    );
  }
}

class _RequestCard extends StatelessWidget {
  final AccessRequest request;
  final VoidCallback onApprove;
  final VoidCallback onReject;
  final VoidCallback onDelete;

  const _RequestCard({
    required this.request,
    required this.onApprove,
    required this.onReject,
    required this.onDelete,
  });

  (Color, String) get _statusStyle {
    if (request.isApproved) return (AppTheme.success, 'APPROVED');
    if (request.isRejected) return (AppTheme.error, 'REJECTED');
    return (AppTheme.warning, 'PENDING');
  }

  @override
  Widget build(BuildContext context) {
    final (color, label) = _statusStyle;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      request.fullName,
                      style: Theme.of(context).textTheme.titleMedium,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      request.email,
                      style: Theme.of(context).textTheme.bodySmall,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                color: color.withValues(alpha: 0.1),
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            request.institution,
            style: Theme.of(context).textTheme.bodySmall,
          ),

          if (request.reason != null && request.reason!.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              color: AppTheme.background,
              child: Text(
                request.reason!,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ],

          if (request.reviewNote != null && request.reviewNote!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'Note: ${request.reviewNote}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],

          if (request.createdEmail != null) ...[
            const SizedBox(height: 8),
            Text(
              'Account created: ${request.createdEmail}',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: AppTheme.success),
            ),
          ],

          const SizedBox(height: 12),
          // Wrap, not Row: three actions do not fit a phone width.
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (request.isPending) ...[
                ElevatedButton.icon(
                  onPressed: onApprove,
                  icon: const Icon(Icons.check, size: 16),
                  label: const Text('APPROVE'),
                ),
                OutlinedButton.icon(
                  onPressed: onReject,
                  icon: const Icon(Icons.close, size: 16),
                  label: const Text('REJECT'),
                ),
              ],
              TextButton.icon(
                onPressed: onDelete,
                icon: const Icon(Icons.delete_outline, size: 16),
                label: const Text('DELETE'),
                style: TextButton.styleFrom(foregroundColor: AppTheme.error),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
