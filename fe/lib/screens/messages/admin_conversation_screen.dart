import 'dart:async';

import 'package:flutter/material.dart';

import '../../models/chat_message.dart';
import '../../services/api_client.dart';
import '../../services/message_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_dialog.dart';
import '../../widgets/async_state_views.dart';
import '../../widgets/message_bubbles.dart';
import '../../widgets/user_avatar.dart';

/// One thread, from the administrator's side.
class AdminConversationScreen extends StatefulWidget {
  final int conversationId;

  const AdminConversationScreen({super.key, required this.conversationId});

  @override
  State<AdminConversationScreen> createState() =>
      _AdminConversationScreenState();
}

class _AdminConversationScreenState extends State<AdminConversationScreen> {
  final MessageService _service = MessageService();
  final ScrollController _scroll = ScrollController();

  Conversation? _conversation;
  bool _isLoading = true;
  String? _error;
  Timer? _poll;

  /// True once anything changed, so the inbox behind reloads on the way out.
  bool _dirty = false;

  @override
  void initState() {
    super.initState();
    _load(initial: true);
    _poll = Timer.periodic(const Duration(seconds: 15), (_) => _load(quiet: true));
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
      final thread = await _service.thread(widget.conversationId);
      if (!mounted) return;

      final grew = thread.messages.length > (_conversation?.messages.length ?? 0);

      setState(() {
        _conversation = thread;
        _isLoading = false;
        _error = null;
      });

      // Opening a thread is reading it, so the inbox count drops as soon as
      // the administrator actually looks.
      if (thread.unread > 0) {
        await _service.markThreadRead(widget.conversationId);
        _dirty = true;
      }

      if (grew || initial) _scrollToEnd();
    } on ApiException catch (e) {
      if (!mounted) return;
      if (quiet && _conversation != null) return;

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
    try {
      final message = await _service.reply(widget.conversationId, body);
      if (!mounted) return;

      final current = _conversation;
      if (current == null) return;

      setState(() {
        _conversation = Conversation(
          id: current.id,
          name: current.name,
          isGuest: current.isGuest,
          guestEmail: current.guestEmail,
          isArchived: current.isArchived,
          unread: 0,
          lastMessageAt: DateTime.now(),
          userAvatarPath: current.userAvatarPath,
          userEmail: current.userEmail,
          messages: [...current.messages, message],
        );
        _dirty = true;
      });

      _scrollToEnd();
    } on ApiException catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message), backgroundColor: AppTheme.error),
      );
      rethrow;
    }
  }

  Future<void> _toggleArchive() async {
    final current = _conversation;
    if (current == null) return;

    try {
      await _service.setArchived(widget.conversationId, !current.isArchived);
      if (!mounted) return;

      _dirty = true;
      Navigator.pop(context, true);
    } on ApiException catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message), backgroundColor: AppTheme.error),
      );
    }
  }

  Future<void> _delete() async {
    final confirmed = await showAppAlertDialog<bool>(
      context: context,
      title: 'Delete conversation',
      content: const Text(
        'This removes the whole thread and every message in it. '
        'Archiving keeps it out of the inbox without destroying anything.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('CANCEL'),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: AppTheme.error),
          onPressed: () => Navigator.pop(context, true),
          child: const Text('DELETE'),
        ),
      ],
    );

    if (confirmed != true) return;

    try {
      await _service.delete(widget.conversationId);
      if (!mounted) return;

      Navigator.pop(context, true);
    } on ApiException catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message), backgroundColor: AppTheme.error),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final conversation = _conversation;

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.surface,
        shape: const Border(bottom: BorderSide(color: AppTheme.border)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context, _dirty),
        ),
        title: Row(
          children: [
            if (conversation != null)
              UserAvatar(
                avatarPath: conversation.userAvatarPath,
                name: conversation.name,
                size: 30,
                bordered: false,
              ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    conversation?.name ?? 'Conversation',
                    style: const TextStyle(fontSize: 15),
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (conversation?.userEmail != null)
                    Text(
                      conversation!.userEmail!,
                      style: Theme.of(context).textTheme.labelSmall,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          if (conversation != null)
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert),
              onSelected: (value) {
                if (value == 'archive') _toggleArchive();
                if (value == 'delete') _delete();
              },
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: 'archive',
                  child: Text(
                    conversation.isArchived
                        ? 'Restore to inbox'
                        : 'Archive conversation',
                  ),
                ),
                const PopupMenuItem(value: 'delete', child: Text('Delete')),
              ],
            ),
        ],
      ),
      body: SafeArea(top: false, child: _buildBody()),
    );
  }

  Widget _buildBody() {
    if (_isLoading) return const LoadingView(message: 'Loading conversation...');

    final conversation = _conversation;

    if (conversation == null) {
      return ErrorView(
        message: _error ?? 'Conversation not found.',
        onRetry: () => _load(initial: true),
      );
    }

    return Column(
      children: [
        if (conversation.isGuest)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            color: AppTheme.accentLight,
            child: Text(
              'Written from the sign-in page, with no account behind it. Send '
              'your answer to ${conversation.guestEmail ?? 'the address given'} '
              '— a reply here is only kept as a record.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        Expanded(
          child: MessageBubbleList(
            messages: conversation.messages,
            viewerIsAdmin: true,
            controller: _scroll,
          ),
        ),
        MessageComposer(onSend: _send, hint: 'Write a reply...'),
      ],
    );
  }
}
