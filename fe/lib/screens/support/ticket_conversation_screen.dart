import 'package:flutter/material.dart';

import '../../models/support_ticket.dart';
import '../../services/api_client.dart';
import '../../services/support_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/async_state_views.dart';

/// The back-and-forth on one ticket.
///
/// Shared by both sides deliberately: the server decides who may open a ticket
/// and stamps each reply with the side that wrote it, so the only thing this
/// screen needs to know is whether to offer the administrator's controls.
class TicketConversationScreen extends StatefulWidget {
  final int ticketId;

  /// Shows the status controls. The endpoints refuse them anyway, but there is
  /// no reason to display a button that will fail.
  final bool asAdmin;

  const TicketConversationScreen({
    super.key,
    required this.ticketId,
    this.asAdmin = false,
  });

  @override
  State<TicketConversationScreen> createState() =>
      _TicketConversationScreenState();
}

class _TicketConversationScreenState extends State<TicketConversationScreen> {
  final SupportService _service = SupportService();
  final TextEditingController _replyController = TextEditingController();
  final ScrollController _scroll = ScrollController();

  SupportTicket? _ticket;
  bool _isLoading = true;
  bool _sending = false;
  String? _error;

  /// True once anything changed, so the list behind can refresh on pop.
  bool _dirty = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _replyController.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final ticket = await _service.show(widget.ticketId);
      if (!mounted) return;
      setState(() {
        _ticket = ticket;
        _isLoading = false;
      });
      _scrollToEnd();
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _isLoading = false;
      });
    }
  }

  void _scrollToEnd() {
    // After the frame, so the list has its final extent.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _send() async {
    final body = _replyController.text.trim();
    if (body.isEmpty || _sending) return;

    setState(() => _sending = true);

    try {
      final ticket = await _service.reply(widget.ticketId, body);
      if (!mounted) return;
      setState(() {
        _ticket = ticket;
        _sending = false;
        _dirty = true;
      });
      _replyController.clear();
      _scrollToEnd();
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _sending = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message), backgroundColor: AppTheme.error),
      );
    }
  }

  Future<void> _setStatus(String status) async {
    try {
      final ticket = await _service.updateStatus(widget.ticketId, status: status);
      if (!mounted) return;
      setState(() {
        _ticket = ticket;
        _dirty = true;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message), backgroundColor: AppTheme.error),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final ticket = _ticket;

    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, _) {},
      child: Scaffold(
        backgroundColor: AppTheme.background,
        appBar: AppBar(
          backgroundColor: AppTheme.surface,
          shape: const Border(bottom: BorderSide(color: AppTheme.border)),
          title: Text(
            ticket?.subject ?? 'Ticket',
            style: const TextStyle(fontSize: 16),
            overflow: TextOverflow.ellipsis,
          ),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.pop(context, _dirty),
          ),
          actions: [
            if (widget.asAdmin && ticket != null)
              PopupMenuButton<String>(
                tooltip: 'Change status',
                icon: const Icon(Icons.more_vert),
                onSelected: _setStatus,
                itemBuilder: (context) => const [
                  PopupMenuItem(value: 'in_progress', child: Text('Mark in progress')),
                  PopupMenuItem(value: 'resolved', child: Text('Mark resolved')),
                  PopupMenuItem(value: 'closed', child: Text('Close ticket')),
                  PopupMenuItem(value: 'open', child: Text('Reopen')),
                ],
              ),
          ],
        ),
        body: SafeArea(top: false, child: _buildBody()),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) return const LoadingView(message: 'Loading conversation...');
    if (_error != null) return ErrorView(message: _error!, onRetry: _load);

    final ticket = _ticket!;

    return Column(
      children: [
        _TicketHeader(ticket: ticket, showRaiser: widget.asAdmin),
        Expanded(
          child: ListView.builder(
            controller: _scroll,
            padding: const EdgeInsets.all(16),
            itemCount: ticket.messages.length,
            itemBuilder: (context, index) =>
                _MessageBubble(message: ticket.messages[index]),
          ),
        ),
        if (ticket.isClosed)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            color: AppTheme.background,
            child: Text(
              'This ticket is closed. Open a new one to continue.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          )
        else ...[
          // A ticket raised from the sign-in page has no account behind it, so
          // an in-app reply would never be read. Say so rather than let the
          // administrator answer into the void.
          if (ticket.isGuest && widget.asAdmin)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              color: AppTheme.accentLight,
              child: Text(
                'Raised without an account. Send your answer to '
                '${ticket.userEmail ?? 'the address given'} — a reply here is '
                'only kept as a record.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          _buildComposer(),
        ],
      ],
    );
  }

  Widget _buildComposer() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: const BoxDecoration(
        color: AppTheme.surface,
        border: Border(top: BorderSide(color: AppTheme.border)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: TextField(
              controller: _replyController,
              minLines: 1,
              maxLines: 5,
              textInputAction: TextInputAction.newline,
              decoration: const InputDecoration(
                hintText: 'Write a reply...',
                isDense: true,
              ),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            height: 44,
            child: ElevatedButton(
              onPressed: _sending ? null : _send,
              child: _sending
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.send, size: 18),
            ),
          ),
        ],
      ),
    );
  }
}

class _TicketHeader extends StatelessWidget {
  final SupportTicket ticket;
  final bool showRaiser;

  const _TicketHeader({required this.ticket, required this.showRaiser});

  Color get _statusColor => switch (ticket.status) {
    'open' => AppTheme.warning,
    'in_progress' => AppTheme.accent,
    'resolved' => AppTheme.success,
    _ => AppTheme.textMuted,
  };

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: AppTheme.surface,
        border: Border(bottom: BorderSide(color: AppTheme.border)),
      ),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          _Chip(label: ticket.statusLabel, color: _statusColor),
          _Chip(label: ticket.category.toUpperCase(), color: AppTheme.textMuted),
          if (ticket.priority == 'high')
            const _Chip(label: 'HIGH PRIORITY', color: AppTheme.error),
          if (ticket.isGuest)
            const _Chip(label: 'NO ACCOUNT', color: AppTheme.accent),
          if (showRaiser && ticket.userName != null)
            Text(
              'from ${ticket.userName}'
              '${ticket.userEmail != null ? ' · ${ticket.userEmail}' : ''}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          if (ticket.analysisRecordId != null)
            Text(
              'job #${ticket.analysisRecordId}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final Color color;

  const _Chip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
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
    );
  }
}

/// Staff replies sit on the left in the platform's red; the user's own on the
/// right — the arrangement people already read as "them" and "me".
class _MessageBubble extends StatelessWidget {
  final SupportMessage message;

  const _MessageBubble({required this.message});

  String get _time {
    final at = message.createdAt?.toLocal();
    if (at == null) return '';
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(at.day)}/${two(at.month)} ${two(at.hour)}:${two(at.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    final fromStaff = message.fromAdmin;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment:
            fromStaff ? CrossAxisAlignment.start : CrossAxisAlignment.end,
        children: [
          ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.78,
            ),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: fromStaff ? AppTheme.primaryLight : AppTheme.surface,
                border: Border.all(
                  color: fromStaff ? AppTheme.primary : AppTheme.border,
                ),
              ),
              child: Text(
                message.body,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${fromStaff ? 'Support' : message.author ?? 'You'} · $_time',
            style: Theme.of(context).textTheme.labelSmall,
          ),
        ],
      ),
    );
  }
}
