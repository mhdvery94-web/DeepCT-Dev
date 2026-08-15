import 'package:flutter/material.dart';

import '../models/chat_message.dart';
import '../theme/app_theme.dart';
import 'user_avatar.dart';

/// The conversation itself.
///
/// One widget for both sides: whose message sits on the right is decided by
/// [viewerIsAdmin], so a researcher sees their own words on the right and an
/// administrator sees theirs there — the arrangement everyone already reads as
/// "me" and "them".
class MessageBubbleList extends StatelessWidget {
  final List<ChatMessage> messages;
  final bool viewerIsAdmin;
  final ScrollController? controller;

  /// Shown in place of the list when nothing has been said yet.
  final Widget? emptyState;

  const MessageBubbleList({
    super.key,
    required this.messages,
    required this.viewerIsAdmin,
    this.controller,
    this.emptyState,
  });

  @override
  Widget build(BuildContext context) {
    if (messages.isEmpty && emptyState != null) return emptyState!;

    return ListView.builder(
      controller: controller,
      padding: const EdgeInsets.all(16),
      itemCount: messages.length,
      itemBuilder: (context, index) {
        final message = messages[index];
        final previous = index > 0 ? messages[index - 1] : null;

        return _Bubble(
          message: message,
          mine: message.isMine(viewerIsAdmin: viewerIsAdmin),
          // Only the first of a run carries the name and the picture; a wall
          // of repeated headers is harder to read than the messages are.
          showHeader: previous == null || previous.fromAdmin != message.fromAdmin,
          showDayDivider: _startsNewDay(previous, message),
        );
      },
    );
  }

  static bool _startsNewDay(ChatMessage? previous, ChatMessage current) {
    final at = current.createdAt?.toLocal();
    if (at == null) return false;
    if (previous?.createdAt == null) return true;

    final before = previous!.createdAt!.toLocal();

    return before.year != at.year ||
        before.month != at.month ||
        before.day != at.day;
  }
}

class _Bubble extends StatelessWidget {
  final ChatMessage message;
  final bool mine;
  final bool showHeader;
  final bool showDayDivider;

  const _Bubble({
    required this.message,
    required this.mine,
    required this.showHeader,
    required this.showDayDivider,
  });

  String get _time {
    final at = message.createdAt?.toLocal();
    if (at == null) return '';

    String two(int n) => n.toString().padLeft(2, '0');

    return '${two(at.hour)}:${two(at.minute)}';
  }

  String get _day {
    final at = message.createdAt?.toLocal();
    if (at == null) return '';

    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];

    final today = DateTime.now();
    if (at.year == today.year && at.month == today.month && at.day == today.day) {
      return 'Today';
    }

    return '${at.day} ${months[at.month - 1]} ${at.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (showDayDivider)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                color: AppTheme.background,
                child: Text(
                  _day,
                  style: Theme.of(context).textTheme.labelSmall,
                ),
              ),
            ),
          ),
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(
            mainAxisAlignment:
                mine ? MainAxisAlignment.end : MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!mine) ...[
                SizedBox(
                  width: 28,
                  child: showHeader
                      ? UserAvatar(
                          avatarPath: message.authorAvatarPath,
                          name: message.author ?? 'Support',
                          size: 28,
                          bordered: false,
                        )
                      : null,
                ),
                const SizedBox(width: 8),
              ],
              Flexible(
                child: Column(
                  crossAxisAlignment:
                      mine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                  children: [
                    if (showHeader && !mine)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 3),
                        child: Text(
                          message.author ?? 'Support',
                          style: Theme.of(context).textTheme.labelSmall,
                        ),
                      ),
                    Container(
                      constraints: BoxConstraints(
                        maxWidth: MediaQuery.of(context).size.width * 0.72,
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: mine ? AppTheme.primaryLight : AppTheme.surface,
                        border: Border.all(
                          color: mine ? AppTheme.primary : AppTheme.border,
                        ),
                      ),
                      child: Text(
                        message.body,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _time,
                          style: Theme.of(context).textTheme.labelSmall,
                        ),
                        // Only on your own messages: whether *they* have read
                        // it is the question you actually have.
                        if (mine) ...[
                          const SizedBox(width: 4),
                          Icon(
                            message.isRead ? Icons.done_all : Icons.done,
                            size: 13,
                            color: message.isRead
                                ? AppTheme.accent
                                : AppTheme.textMuted,
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// The box you type into.
class MessageComposer extends StatefulWidget {
  final Future<void> Function(String body) onSend;
  final String hint;
  final bool enabled;

  const MessageComposer({
    super.key,
    required this.onSend,
    this.hint = 'Write a message...',
    this.enabled = true,
  });

  @override
  State<MessageComposer> createState() => _MessageComposerState();
}

class _MessageComposerState extends State<MessageComposer> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focus = FocusNode();
  bool _sending = false;

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final body = _controller.text.trim();
    if (body.isEmpty || _sending) return;

    setState(() => _sending = true);

    // Cleared before the round trip, so typing the next line does not wait on
    // the network; the screen puts it back if the send fails.
    _controller.clear();

    try {
      await widget.onSend(body);
    } catch (_) {
      if (mounted) _controller.text = body;
    } finally {
      if (mounted) {
        setState(() => _sending = false);
        _focus.requestFocus();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: const BoxDecoration(
        color: AppTheme.surface,
        border: Border(top: BorderSide(color: AppTheme.border)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: TextField(
                controller: _controller,
                focusNode: _focus,
                enabled: widget.enabled && !_sending,
                minLines: 1,
                maxLines: 5,
                textInputAction: TextInputAction.newline,
                decoration: InputDecoration(
                  hintText: widget.hint,
                  isDense: true,
                ),
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              height: 44,
              width: 52,
              child: ElevatedButton(
                onPressed: (widget.enabled && !_sending) ? _send : null,
                style: ElevatedButton.styleFrom(padding: EdgeInsets.zero),
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
      ),
    );
  }
}
