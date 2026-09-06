import 'dart:async';

import 'package:flutter/material.dart';

import '../models/app_notification.dart';
import '../services/api_client.dart';
import '../services/notification_service.dart';
import '../theme/app_theme.dart';
import 'app_dialog.dart';

/// The bell, with its unread badge and the panel behind it.
///
/// It polls rather than holding a socket open, for the reason in
/// ARCHITECTURE.md §4: one reader, events measured in minutes, and a poll that
/// costs a single indexed count. The same request carries the unread *message*
/// count, so the shell's Messages badge comes free — [onCounts] hands both back.
class NotificationBell extends StatefulWidget {
  /// Called after each poll with (unread notifications, unread messages).
  final void Function(int notifications, int messages)? onCounts;

  /// Where a tapped notification wants to go: `messages`, `predictions/12`,
  /// `access-requests`, `models`, `dashboard`. The shell decides what that
  /// means; this widget only carries it.
  final void Function(String link)? onOpenLink;

  const NotificationBell({super.key, this.onCounts, this.onOpenLink});

  /// Replaces the poll. Tests only — production leaves it null.
  ///
  /// Same bargain as `NewsSection.debugLoader`: the widget calls the server
  /// the moment it is built, and a real request leaves a pending timeout timer
  /// that fails whatever test happened to pump it.
  static Future<({int notifications, int messages})> Function()? debugCounts;

  @override
  State<NotificationBell> createState() => NotificationBellState();
}

class NotificationBellState extends State<NotificationBell> {
  final NotificationService _service = NotificationService();

  int _unread = 0;
  Timer? _poll;

  /// Slow enough to be invisible on the server, fast enough that an answer to
  /// a message shows up while you are still wondering about it.
  static const Duration _interval = Duration(seconds: 45);

  @override
  void initState() {
    super.initState();
    refresh();
    _poll = Timer.periodic(_interval, (_) => refresh());
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  /// Public so a shell can force a refresh after it changes something itself.
  Future<void> refresh() async {
    try {
      final probe = NotificationBell.debugCounts;
      final counts = probe != null ? await probe() : await _service.unreadCounts();
      if (!mounted) return;

      setState(() => _unread = counts.notifications);
      widget.onCounts?.call(counts.notifications, counts.messages);
    } catch (_) {
      // A badge is never worth an error banner. The panel reports failures
      // when it is actually opened.
    }
  }

  Future<void> _openPanel() async {
    final link = await showAppDialog<String>(
      context: context,
      maxWidth: 440,
      builder: (_) => const _NotificationPanel(),
    );

    await refresh();

    if (link != null && link.isNotEmpty) widget.onOpenLink?.call(link);
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        IconButton(
          tooltip: 'Notifications',
          onPressed: _openPanel,
          icon: Icon(
            _unread > 0 ? Icons.notifications_active : Icons.notifications_none,
            size: 22,
          ),
        ),
        if (_unread > 0)
          Positioned(
            right: 4,
            top: 4,
            child: IgnorePointer(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                constraints: const BoxConstraints(minWidth: 16),
                color: AppTheme.primary,
                alignment: Alignment.center,
                child: Text(
                  _unread > 99 ? '99+' : '$_unread',
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// The list behind the bell. Pops with a link when one is tapped.
class _NotificationPanel extends StatefulWidget {
  const _NotificationPanel();

  @override
  State<_NotificationPanel> createState() => _NotificationPanelState();
}

class _NotificationPanelState extends State<_NotificationPanel> {
  final NotificationService _service = NotificationService();

  List<AppNotification> _items = const [];
  bool _isLoading = true;
  String? _error;
  int _unread = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);

    try {
      final result = await _service.list();
      if (!mounted) return;

      setState(() {
        _items = result.page.items;
        _unread = result.unread;
        _isLoading = false;
        _error = null;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _isLoading = false;
      });
    }
  }

  Future<void> _markAllRead() async {
    try {
      await _service.markAllRead();
      if (!mounted) return;
      await _load();
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message), backgroundColor: AppTheme.error),
      );
    }
  }

  Future<void> _open(AppNotification notification) async {
    // Marked read on the way out rather than awaited first: the navigation is
    // what the tap was for, and a failed mark-read would only strand the user.
    if (!notification.read) {
      unawaited(_service.markRead(notification.id));
    }

    if (!mounted) return;
    Navigator.pop(context, notification.link ?? '');
  }

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.of(context).size.height;

    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: height * 0.75),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 8, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Notifications',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                ),
                if (_unread > 0)
                  TextButton(
                    onPressed: _markAllRead,
                    child: const Text('MARK ALL READ'),
                  ),
                IconButton(
                  tooltip: 'Close',
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close, size: 20),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Flexible(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Padding(
        padding: EdgeInsets.all(40),
        child: Center(
          child: SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }

    if (_error != null) {
      return Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            OutlinedButton(onPressed: _load, child: const Text('RETRY')),
          ],
        ),
      );
    }

    if (_items.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.notifications_none,
              size: 44,
              color: AppTheme.borderDark,
            ),
            const SizedBox(height: 12),
            Text(
              'Nothing yet',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Text(
              'Finished jobs, replies from support and anything that needs '
              'your attention will appear here.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      padding: EdgeInsets.zero,
      itemCount: _items.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (context, index) => _NotificationRow(
        notification: _items[index],
        onTap: () => _open(_items[index]),
      ),
    );
  }
}

class _NotificationRow extends StatelessWidget {
  final AppNotification notification;
  final VoidCallback onTap;

  const _NotificationRow({required this.notification, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        // Unread rows are tinted rather than badged: at a glance the panel
        // should show how much is new without counting anything.
        color: notification.read
            ? Colors.transparent
            : AppTheme.primary.withValues(alpha: 0.04),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 32,
              height: 32,
              color: notification.colour.withValues(alpha: 0.12),
              alignment: Alignment.center,
              child: Icon(
                notification.icon,
                size: 17,
                color: notification.colour,
              ),
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
                          notification.title,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: notification.read
                                ? FontWeight.w500
                                : FontWeight.w700,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        notification.age,
                        style: Theme.of(context).textTheme.labelSmall,
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    notification.body,
                    style: Theme.of(context).textTheme.bodySmall,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
