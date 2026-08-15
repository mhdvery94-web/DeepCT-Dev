import 'package:flutter/material.dart';

import '../../models/pagination.dart';
import '../../models/support_ticket.dart';
import '../../services/api_client.dart';
import '../../services/support_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/async_state_views.dart';
import '../../widgets/pagination_bar.dart';
import 'ticket_conversation_screen.dart';

/// Support tickets, from either side.
///
/// A researcher sees their own and can raise new ones; an administrator sees
/// every ticket and gets an "awaiting reply" filter, which is the queue they
/// actually work from.
class TicketListScreen extends StatefulWidget {
  final bool asAdmin;

  const TicketListScreen({super.key, this.asAdmin = false});

  @override
  State<TicketListScreen> createState() => _TicketListScreenState();
}

class _TicketListScreenState extends State<TicketListScreen> {
  final SupportService _service = SupportService();

  List<SupportTicket> _items = const [];
  Pagination _pagination = const Pagination.empty();

  bool _isLoading = true;
  String? _error;
  int _page = 1;
  String? _statusFilter;
  bool _awaitingOnly = false;

  int _openCount = 0;
  int _awaitingCount = 0;

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
      if (widget.asAdmin) {
        final result = await _service.adminTickets(
          page: _page,
          status: _statusFilter,
          awaitingOnly: _awaitingOnly,
        );
        if (!mounted) return;
        setState(() {
          _items = result.page.items;
          _pagination = result.page.pagination;
          _openCount = result.openCount;
          _awaitingCount = result.awaitingCount;
          _isLoading = false;
        });
      } else {
        final result = await _service.myTickets(
          page: _page,
          status: _statusFilter,
        );
        if (!mounted) return;
        setState(() {
          _items = result.items;
          _pagination = result.pagination;
          _isLoading = false;
        });
      }
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _isLoading = false;
      });
    }
  }

  Future<void> _open(SupportTicket ticket) async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => TicketConversationScreen(
          ticketId: ticket.id,
          asAdmin: widget.asAdmin,
        ),
      ),
    );

    if (changed == true) await _load();
  }

  Future<void> _newTicket() async {
    final created = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      builder: (_) => const _NewTicketSheet(),
    );

    if (created == true) await _load();
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
                      widget.asAdmin ? 'Support Tickets' : 'IT Support',
                      style: Theme.of(context).textTheme.titleLarge,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      widget.asAdmin
                          ? '$_openCount open, $_awaitingCount awaiting a reply'
                          : 'Report a problem and we will answer here',
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
              if (!widget.asAdmin)
                ElevatedButton.icon(
                  onPressed: _newTicket,
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('NEW'),
                ),
            ],
          ),
          const SizedBox(height: 12),

          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final option in const [
                (null, 'ALL'),
                ('open', 'OPEN'),
                ('in_progress', 'IN PROGRESS'),
                ('resolved', 'RESOLVED'),
                ('closed', 'CLOSED'),
              ])
                _FilterChip(
                  label: option.$2,
                  selected: !_awaitingOnly && _statusFilter == option.$1,
                  onTap: () {
                    setState(() {
                      _statusFilter = option.$1;
                      _awaitingOnly = false;
                      _page = 1;
                    });
                    _load();
                  },
                ),
              if (widget.asAdmin)
                _FilterChip(
                  label: 'NEEDS REPLY',
                  selected: _awaitingOnly,
                  onTap: () {
                    setState(() {
                      _awaitingOnly = true;
                      _statusFilter = null;
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
    if (_isLoading) return const LoadingView(message: 'Loading tickets...');
    if (_error != null) return ErrorView(message: _error!, onRetry: _load);

    if (_items.isEmpty) {
      return EmptyView(
        message: widget.asAdmin
            ? 'No tickets'
            : 'No tickets yet — tap NEW if something is wrong',
        icon: Icons.support_agent_outlined,
      );
    }

    return Column(
      children: [
        Expanded(
          child: ListView.separated(
            itemCount: _items.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, index) => _TicketCard(
              ticket: _items[index],
              showRaiser: widget.asAdmin,
              onTap: () => _open(_items[index]),
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
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? AppTheme.primary : AppTheme.surface,
          border: Border.all(
            color: selected ? AppTheme.primary : AppTheme.border,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: selected ? Colors.white : AppTheme.textMuted,
          ),
        ),
      ),
    );
  }
}

class _TicketCard extends StatelessWidget {
  final SupportTicket ticket;
  final bool showRaiser;
  final VoidCallback onTap;

  const _TicketCard({
    required this.ticket,
    required this.showRaiser,
    required this.onTap,
  });

  Color get _statusColor => switch (ticket.status) {
    'open' => AppTheme.warning,
    'in_progress' => AppTheme.accent,
    'resolved' => AppTheme.success,
    _ => AppTheme.textMuted,
  };

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          border: Border.all(
            // A ticket waiting on staff is the one an admin needs to see.
            color: showRaiser && ticket.awaitingAdmin
                ? AppTheme.primary
                : AppTheme.border,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    ticket.subject,
                    style: Theme.of(context).textTheme.titleMedium,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  color: _statusColor.withValues(alpha: 0.1),
                  child: Text(
                    ticket.statusLabel,
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w600,
                      color: _statusColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 12,
              runSpacing: 4,
              children: [
                Text(
                  ticket.category,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                Text(
                  '${ticket.messageCount} message'
                  '${ticket.messageCount == 1 ? '' : 's'}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                if (showRaiser && ticket.userName != null)
                  Text(
                    ticket.userName!,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                if (ticket.priority == 'high')
                  Text(
                    'HIGH',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppTheme.error,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                if (showRaiser && ticket.awaitingAdmin && ticket.isOpen)
                  Text(
                    'NEEDS REPLY',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppTheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Raising a ticket. A sheet rather than a page: it is a short form, and
/// keeping the list behind it visible makes it obvious where the result lands.
class _NewTicketSheet extends StatefulWidget {
  const _NewTicketSheet();

  @override
  State<_NewTicketSheet> createState() => _NewTicketSheetState();
}

class _NewTicketSheetState extends State<_NewTicketSheet> {
  final SupportService _service = SupportService();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _subject = TextEditingController();
  final TextEditingController _message = TextEditingController();

  String _category = 'other';
  String _priority = 'normal';
  bool _sending = false;
  String? _error;

  @override
  void dispose() {
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
      await _service.open(
        subject: _subject.text.trim(),
        message: _message.text.trim(),
        category: _category,
        priority: _priority,
      );
      if (!mounted) return;
      Navigator.pop(context, true);
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
        // Clears the on-screen keyboard.
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Report a problem',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 4),
            Text(
              'An administrator replies inside the app — you do not need email.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 20),

            TextFormField(
              controller: _subject,
              decoration: const InputDecoration(labelText: 'Subject'),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Subject is required' : null,
            ),
            const SizedBox(height: 16),

            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _category,
                    // Without this the dropdown sizes to its longest option
                    // rather than the column it was given, and overflows on a
                    // phone. Same trap as in PublicTicketSheet.
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Category'),
                    items: [
                      for (final c in SupportService.categories)
                        DropdownMenuItem(value: c, child: Text(c)),
                    ],
                    onChanged: (v) => setState(() => _category = v ?? 'other'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _priority,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Priority'),
                    items: const [
                      DropdownMenuItem(value: 'low', child: Text('low')),
                      DropdownMenuItem(value: 'normal', child: Text('normal')),
                      DropdownMenuItem(value: 'high', child: Text('high')),
                    ],
                    onChanged: (v) => setState(() => _priority = v ?? 'normal'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            TextFormField(
              controller: _message,
              minLines: 3,
              maxLines: 6,
              decoration: const InputDecoration(
                labelText: 'What went wrong?',
                hintText: 'What you did, what happened, and any error message',
              ),
              validator: (v) => (v == null || v.trim().isEmpty)
                  ? 'Describe the problem'
                  : null,
            ),

            if (_error != null) ...[
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(12),
                color: AppTheme.errorLight,
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
                      : const Text('SUBMIT'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
