import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/auth_provider.dart';
import '../../widgets/app_dialog.dart';
import '../../widgets/avatar_editor_sheet.dart';
import '../../widgets/change_password_dialog.dart';
import '../../widgets/notification_bell.dart';
import '../../widgets/user_avatar.dart';
import '../../theme/app_theme.dart';
import '../landing/landing_page.dart';
import '../messages/message_thread_screen.dart';
import 'prediction_history_screen.dart';
import 'upload_screen.dart';
import 'user_activity_screen.dart';
import 'user_home_screen.dart';

/// Navigation destinations available to a researcher.
///
/// Every entry is backed by real endpoints. The `available` flag that used to
/// grey out unfinished sections is gone with the last of them.
enum UserSection {
  dashboard('Dashboard', Icons.dashboard_outlined),
  analysis('New Analysis', Icons.auto_awesome_outlined),
  history('Results & History', Icons.folder_outlined),
  activity('My Activity', Icons.history),
  messages('Messages', Icons.forum_outlined);

  const UserSection(this.label, this.icon);

  final String label;
  final IconData icon;
}

/// One step along the section list, clamped at both ends.
///
/// Clamped rather than wrapped: a swipe from the last entry landing on the
/// Dashboard reads as losing your place, not as moving.
UserSection nextSection(UserSection from, int step) {
  final index = UserSection.values.indexOf(from) + step;

  if (index < 0 || index >= UserSection.values.length) return from;

  return UserSection.values[index];
}

/// Researcher console shell: persistent sidebar on desktop, drawer on mobile.
///
/// Deliberately mirrors [AdminShell] so both halves of the app navigate the
/// same way.
class UserShell extends StatefulWidget {
  const UserShell({super.key});

  @override
  State<UserShell> createState() => _UserShellState();
}

class _UserShellState extends State<UserShell> {
  UserSection _section = UserSection.dashboard;

  /// Below this width the sidebar collapses into a drawer.
  static const double _mobileBreakpoint = 1000;

  /// Unread replies from support, shown beside the Messages entry.
  ///
  /// Supplied by the bell's poll rather than a second request of our own --
  /// `/notifications/unread-count` returns both counts precisely so the two
  /// badges cost one call between them.
  int _unreadMessages = 0;

  final GlobalKey<NotificationBellState> _bell =
      GlobalKey<NotificationBellState>();

  /// Where a tapped notification goes. The link vocabulary is the server's;
  /// the mapping to sections is ours.
  void _openLink(String link) {
    if (link.startsWith('messages')) {
      setState(() => _section = UserSection.messages);
    } else if (link.startsWith('predictions')) {
      setState(() => _section = UserSection.history);
    } else if (link.startsWith('dashboard')) {
      setState(() => _section = UserSection.dashboard);
    }
  }

  Widget _buildBell() => NotificationBell(
    key: _bell,
    onCounts: (_, messages) {
      if (mounted && messages != _unreadMessages) {
        setState(() => _unreadMessages = messages);
      }
    },
    onOpenLink: _openLink,
  );

  Widget _buildBody() {
    switch (_section) {
      case UserSection.dashboard:
        return UserHomeScreen(
          onViewAllActivity: () =>
              setState(() => _section = UserSection.activity),
        );
      case UserSection.activity:
        return const UserActivityScreen();
      case UserSection.analysis:
        return UploadScreen(
          // Jump straight to the queue so the user sees their job progressing.
          onQueued: (_) => setState(() => _section = UserSection.history),
        );
      case UserSection.history:
        // The key forces a fresh State when arriving from a new upload, so the
        // list reloads instead of showing the previous page's cached items.
        return PredictionHistoryScreen(key: UniqueKey());
      case UserSection.messages:
        return MessageThreadScreen(
          // Opening the thread reads it, so the badge should go with it
          // rather than waiting for the next poll.
          onUnreadChanged: (unread) {
            if (mounted) setState(() => _unreadMessages = unread);
          },
        );
    }
  }

  /// Change the signed-in account's own photo.
  ///
  /// The provider is updated straight from the response rather than refetching
  /// `/user`, so the sidebar shows the new picture immediately.
  Future<void> _changePhoto() async {
    final auth = context.read<AuthProvider>();
    final user = auth.user;
    if (user == null) return;

    final result = await showAvatarEditor(
      context,
      name: user.name,
      currentPath: user.avatarPath,
    );

    if (result != null && result.changed) auth.setAvatarPath(result.path);
  }

  Future<void> _changePassword() async {
    final message = await showChangePasswordDialog(context);
    if (message == null || !mounted) return;

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _confirmLogout() async {
    final authProvider = context.read<AuthProvider>();

    final confirmed = await showAppAlertDialog<bool>(
      context: context,
      title: 'Sign out',
      content: const Text('Are you sure you want to end this session?'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('CANCEL'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('SIGN OUT'),
        ),
      ],
    );

    if (confirmed != true) return;

    await authProvider.logout();

    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LandingPage()),
      (route) => false,
    );
  }

  Widget _buildSidebar({required bool isDrawer}) {
    final user = context.watch<AuthProvider>().user;

    return Container(
      width: 260,
      color: AppTheme.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Brand block
          Container(
            height: 88,
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: AppTheme.border)),
            ),
            child: Row(
              children: [
                Image.asset(
                  'assets/branding/brin_logo.png',
                  width: 36,
                  height: 36,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'BRIN',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      Text(
                        'Neutron CT Platform',
                        style: Theme.of(context).textTheme.labelSmall,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Text(
              'RESEARCH',
              style: Theme.of(context).textTheme.labelMedium,
            ),
          ),

          for (final section in UserSection.values)
            _NavItem(
              section: section,
              selected: _section == section,
              badge: section == UserSection.messages ? _unreadMessages : 0,
              onTap: () {
                setState(() => _section = section);
                if (isDrawer) Navigator.pop(context);
              },
            ),

          const Spacer(),
          const Divider(height: 1),

          // Signed-in user + logout
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                AvatarButton(user: user, onTap: _changePhoto),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user?.name ?? 'researcher',
                        style: Theme.of(context).textTheme.labelLarge,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        user?.email ?? '',
                        style: Theme.of(context).textTheme.labelSmall,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Change password',
                  onPressed: _changePassword,
                  icon: const Icon(Icons.lock_outline, size: 18),
                ),
                IconButton(
                  tooltip: 'Sign out',
                  onPressed: _confirmLogout,
                  icon: const Icon(Icons.logout, size: 18),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width >= _mobileBreakpoint;

    return PopScope(
      // Always false: both branches handle the gesture themselves.
      // Leaving it true on the Dashboard restores the bug this is
      // fixing — a mis-swipe dropping someone onto the landing page
      // with no warning at all.
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
    
        // From anywhere else, back means home — one step, the way
        // Android has always behaved.
        if (_section != UserSection.dashboard) {
          setState(() => _section = UserSection.dashboard);
          return;
        }
    
        // From home it means leaving, and leaving is worth asking
        // about. The same dialog the Sign out button opens, so the
        // two cannot drift apart.
        _confirmLogout();
      },
      child: Scaffold(
      backgroundColor: AppTheme.background,
      drawer: isWide
          ? null
          : Drawer(
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.zero,
              ),
              child: SafeArea(child: _buildSidebar(isDrawer: true)),
            ),
      appBar: isWide
          ? null
          : AppBar(
              title: Text(_section.label),
              backgroundColor: AppTheme.surface,
              shape: const Border(bottom: BorderSide(color: AppTheme.border)),
              actions: [_buildBell(), const SizedBox(width: 4)],
            ),
      // The wide layout has no AppBar, so nothing reserves room for the system
      // status bar. See fe/README.md.
      // One SelectionArea over the whole body rather than a SelectableText
      // per label: selection then runs across widgets, so a block spanning
      // several rows can be swept in one gesture. Text fields are unaffected
      // — SelectionArea skips EditableText — and there is no onLongPress
      // anywhere in the app for it to fight with.
      body: SelectionArea(
        // GestureDetector rather than a PageView: the metrics table and some
        child: GestureDetector(
          onHorizontalDragEnd: (details) {
            final velocity = details.primaryVelocity ?? 0;
      
            // Below this it was a tap that wandered, not a swipe.
            if (velocity.abs() < 200) return;
      
            // Dragging leftwards moves forward through the list.
            final next = nextSection(_section, velocity < 0 ? 1 : -1);
            if (next != _section) setState(() => _section = next);
          },
        child: SafeArea(
          bottom: false,
          child: Row(
            children: [
              if (isWide) ...[
                _buildSidebar(isDrawer: false),
                const VerticalDivider(width: 1),
              ],
              Expanded(
                child: Column(
                  children: [
                    if (isWide)
                      Container(
                        height: 88,
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 32),
                        decoration: const BoxDecoration(
                          color: AppTheme.surface,
                          border: Border(
                            bottom: BorderSide(color: AppTheme.border),
                          ),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    _section.label,
                                    style: Theme.of(
                                      context,
                                    ).textTheme.headlineLarge,
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Researcher console',
                                    style: Theme.of(
                                      context,
                                    ).textTheme.bodySmall,
                                  ),
                                ],
                              ),
                            ),
                            _buildBell(),
                          ],
                        ),
                      ),
                    Expanded(child: _buildBody()),
                  ],
                ),
              ),
            ],
          ),
        ),
        ),
      ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final UserSection section;
  final bool selected;
  final VoidCallback onTap;

  /// Shown as a count when above zero; hidden otherwise.
  final int badge;

  const _NavItem({
    required this.section,
    required this.selected,
    required this.onTap,
    this.badge = 0,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        decoration: BoxDecoration(
          color: selected ? AppTheme.primaryLight : Colors.transparent,
          border: Border(
            left: BorderSide(
              color: selected ? AppTheme.primary : Colors.transparent,
              width: 3,
            ),
          ),
        ),
        child: Row(
          children: [
            Icon(
              section.icon,
              size: 18,
              color: selected ? AppTheme.primary : AppTheme.textMuted,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                section.label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                  color: selected ? AppTheme.primary : AppTheme.textPrimary,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (badge > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                color: AppTheme.primary,
                child: Text(
                  badge > 99 ? '99+' : '$badge',
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
