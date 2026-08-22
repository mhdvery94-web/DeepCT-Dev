import 'dart:async';

import 'package:flutter/material.dart';

import '../../models/chat_message.dart';
import '../../services/api_client.dart';
import '../../services/message_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/async_state_views.dart';
import '../../widgets/message_bubbles.dart';

/// The researcher's side of IT support: one conversation with the admins.
///
/// There is nothing to choose before writing — no subject, no category, no
/// priority. Someone with a problem should be able to describe it in the first
/// thing they type.
class MessageThreadScreen extends StatefulWidget {
  /// Called after loading with the number of unread replies, so the shell can
  /// clear its badge without asking the server again.
  final void Function(int unread)? onUnreadChanged;

  const MessageThreadScreen({super.key, this.onUnreadChanged});

  @override
  State<MessageThreadScreen> createState() => _MessageThreadScreenState();
}

class _MessageThreadScreenState extends State<MessageThreadScreen> {
  final MessageService _service = MessageService();
  final ScrollController _scroll = ScrollController();

  List<ChatMessage> _messages = const [];
  bool _isLoading = true;
  String? _error;
  Timer? _poll;

  /// While the screen is open, replies should appear without a manual refresh.
  /// Faster than the bell's 45s because the reader is looking straight at it.
  static const Duration _pollInterval = Duration(seconds: 15);

  @override
  void initState() {
    super.initState();
    _load(initial: true);
    _poll = Timer.periodic(_pollInterval, (_) => _load(quiet: true));
  }

  @override
  void dispose() {
    _poll?.cancel();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _load({bool initial = false, bool quiet = false}) async {
    if (initial) setState(() => _isLoading = true);

    try {
      final thread = await _service.myThread();
      if (!mounted) return;

      final grew = thread.messages.length > _messages.length;

      setState(() {
        _messages = thread.messages;
        _isLoading = false;
        _error = null;
      });

      // Reading the thread *is* reading it; the badge should not survive
      // having the conversation open on screen.
      if (thread.unread > 0) {
        await _service.markRead();
        widget.onUnreadChanged?.call(0);
      }

      if (grew) _scrollToEnd();
    } on ApiException catch (e) {
      if (!mounted) return;

      // A failed background refresh leaves what is on screen alone; only the
      // first load has nothing to fall back to.
      if (quiet && _messages.isNotEmpty) return;

      setState(() {
        _error = e.message;
        _isLoading = false;
      });
    }
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;

      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _send(String body) async {
    // The bubble appears before the round trip, so the thread reacts to
    // typing rather than to the network.
    final optimistic = ChatMessage.pending(body: body, fromAdmin: false);

    setState(() => _messages = [..._messages, optimistic]);
    _scrollToEnd();

    try {
      final message = await _service.send(body);
      if (!mounted) return;

      // Replaced wholesale rather than patched: the server's copy carries the
      // id, the timestamp and the author this one only guessed at.
      //
      // `identical` and not an id comparison — a pending message has id 0,
      // and two of them can be in flight at once if someone types fast.
      setState(() {
        _messages = [
          for (final m in _messages)
            if (identical(m, optimistic)) message else m,
        ];
      });
      _scrollToEnd();
    } on ApiException catch (e) {
      if (!mounted) return;

      setState(() {
        _messages = [
          for (final m in _messages)
            if (identical(m, optimistic))
              m.copyWith(delivery: MessageDelivery.failed)
            else
              m,
        ];
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message), backgroundColor: AppTheme.error),
      );
      rethrow; // The composer puts the text back.
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const LoadingView(message: 'Loading messages...');

    if (_error != null && _messages.isEmpty) {
      return ErrorView(message: _error!, onRetry: () => _load(initial: true));
    }

    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: const BoxDecoration(
            color: AppTheme.surface,
            border: Border(bottom: BorderSide(color: AppTheme.border)),
          ),
          child: Row(
            children: [
              const Icon(Icons.support_agent_outlined, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Messages with the administrator. Replies appear here.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: MessageBubbleList(
            messages: _messages,
            viewerIsAdmin: false,
            controller: _scroll,
            emptyState: const _EmptyThread(),
          ),
        ),
        MessageComposer(
          onSend: _send,
          hint: 'Describe the problem...',
        ),
      ],
    );
  }
}

class _EmptyThread extends StatelessWidget {
  const _EmptyThread();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.forum_outlined,
              size: 48,
              color: AppTheme.borderDark,
            ),
            const SizedBox(height: 12),
            Text(
              'No messages yet',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 6),
            Text(
              'Something not working? Write below and an administrator will '
              'answer here. Say what you did, what happened, and any error '
              'message you saw.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}
