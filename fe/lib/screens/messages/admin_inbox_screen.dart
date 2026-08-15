import 'package:flutter/material.dart';

import '../../models/chat_message.dart';
import '../../models/pagination.dart';
import '../../services/api_client.dart';
import '../../services/message_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/async_state_views.dart';
import '../../widgets/pagination_bar.dart';
import '../../widgets/user_avatar.dart';
import 'admin_conversation_screen.dart';

/// The administrator's inbox: every thread, newest first.
class AdminInboxScreen extends StatefulWidget {
  /// Lets the shell refresh its own badge after something is read here.
  final void Function(int unreadConversations)? onUnreadChanged;

  const AdminInboxScreen({super.key, this.onUnreadChanged});

  @override
  State<AdminInboxScreen> createState() => _AdminInboxScreenState();
}

class _AdminInboxScreenState extends State<AdminInboxScreen> {
  final MessageService _service = MessageService();

  List<Conversation> _items = const [];
  Pagination _pagination = const Pagination.empty();

  bool _isLoading = true;
  String? _error;
  int _page = 1;
  bool _unreadOnly = false;
  bool _archived = false;
  int _unreadConversations = 0;

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
      final result = await _service.inbox(
        page: _page,
        archived: _archived,
        unreadOnly: _unreadOnly,
      );

      if (!mounted) return;
      setState(() {
        _items = result.page.items;
        _pagination = result.page.pagination;
        _unreadConversations = result.unreadConversations;
        _isLoading = false;
      });

      widget.onUnreadChanged?.call(result.unreadConversations);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _isLoading = false;
      });
    }
  }

  Future<void> _open(Conversation conversation) async {
    final id = conversation.id;
    if (id == null) return;

    await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => AdminConversationScreen(conversationId: id),
      ),
    );

    // Always reload: opening a thread marks it read, so the counts behind it
    // are stale whatever the screen reports back.
    if (mounted) await _load();
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
                      'Messages',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    Text(
                      _unreadConversations == 0
                          ? 'Nothing waiting for a reply'
                          : '$_unreadConversations conversation'
                                '${_unreadConversations == 1 ? '' : 's'} '
                                'waiting for a reply',
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
            runSpacing: 8,
            children: [
              _FilterChip(
                label: 'INBOX',
                selected: !_archived && !_unreadOnly,
                onTap: () => _setFilter(archived: false, unread: false),
              ),
              _FilterChip(
                label: 'NEEDS REPLY',
                selected: _unreadOnly,
                onTap: () => _setFilter(archived: false, unread: true),
              ),
              _FilterChip(
                label: 'ARCHIVED',
                selected: _archived,
                onTap: () => _setFilter(archived: true, unread: false),
              ),
            ],
          ),
          const SizedBox(height: 16),

          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  void _setFilter({required bool archived, required bool unread}) {
    setState(() {
      _archived = archived;
      _unreadOnly = unread;
      _page = 1;
    });
    _load();
  }

  Widget _buildBody() {
    if (_isLoading) return const LoadingView(message: 'Loading messages...');
    if (_error != null) return ErrorView(message: _error!, onRetry: _load);

    if (_items.isEmpty) {
      return EmptyView(
        message: _archived
            ? 'Nothing archived'
            : (_unreadOnly ? 'Everything answered' : 'No messages yet'),
        icon: Icons.forum_outlined,
      );
    }

    return Column(
      children: [
        Expanded(
          child: ListView.separated(
            itemCount: _items.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, index) => _ConversationRow(
              conversation: _items[index],
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

class _ConversationRow extends StatelessWidget {
  final Conversation conversation;
  final VoidCallback onTap;

  const _ConversationRow({required this.conversation, required this.onTap});

  String get _age {
    final at = conversation.lastMessageAt?.toLocal();
    if (at == null) return '';

    final diff = DateTime.now().difference(at);

    if (diff.inMinutes < 1) return 'now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';

    return '${diff.inDays}d';
  }

  @override
  Widget build(BuildContext context) {
    final unread = conversation.unread > 0;

    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          border: Border.all(
            // A thread waiting on the administrator is the one they came for.
            color: unread ? AppTheme.primary : AppTheme.border,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            UserAvatar(
              avatarPath: conversation.userAvatarPath,
              name: conversation.name,
              size: 38,
              bordered: false,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          conversation.name,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: unread
                                ? FontWeight.w700
                                : FontWeight.w600,
                            color: AppTheme.textPrimary,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(_age, style: Theme.of(context).textTheme.labelSmall),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      if (conversation.lastFromAdmin == true) ...[
                        const Icon(
                          Icons.reply,
                          size: 12,
                          color: AppTheme.textMuted,
                        ),
                        const SizedBox(width: 4),
                      ],
                      Expanded(
                        child: Text(
                          conversation.preview,
                          style: Theme.of(context).textTheme.bodySmall,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  if (conversation.isGuest || unread) ...[
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      children: [
                        if (conversation.isGuest)
                          const _Tag(label: 'NO ACCOUNT', colour: AppTheme.accent),
                        if (unread)
                          _Tag(
                            label: '${conversation.unread} NEW',
                            colour: AppTheme.primary,
                          ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  final String label;
  final Color colour;

  const _Tag({required this.label, required this.colour});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      color: colour.withValues(alpha: 0.12),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w700,
          color: colour,
        ),
      ),
    );
  }
}
