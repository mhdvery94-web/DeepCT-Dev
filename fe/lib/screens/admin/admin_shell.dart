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
import '../messages/admin_inbox_screen.dart';
import 'access_requests_screen.dart';
import 'activity_logs_screen.dart';
import 'dashboard_home_screen.dart';
import 'model_management_screen.dart';
import 'news_management_screen.dart';
import 'training_screen.dart';
import 'user_management_screen.dart';

/// Navigation destinations available to an administrator.
enum AdminSection {
  dashboard('Dashboard', Icons.dashboard_outlined),
  users('User Management', Icons.people_outline),
  accessRequests('Access Requests', Icons.how_to_reg_outlined),
  messages('Messages', Icons.forum_outlined),
  news('Research News', Icons.article_outlined),
  training('Model Training', Icons.model_training_outlined),
  models('Model Management', Icons.memory_outlined),
  activities('Activity Logs', Icons.history);

  const AdminSection(this.label, this.icon);

  final String label;
  final IconData icon;
}

/// Admin dashboard shell: persistent sidebar on desktop, drawer on mobile.
///
/// Replaces the previous placeholder screen and hosts the three FASE 2
/// management screens.
class AdminShell extends StatefulWidget {
  const AdminShell({super.key});

  @override
  State<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends State<AdminShell> {
  AdminSection _section = AdminSection.dashboard;

  /// Below this width the sidebar collapses into a drawer.
  static const double _mobileBreakpoint = 1000;

  /// Conversations waiting on a reply, shown beside the Messages entry.
  ///
  /// Comes from the bell's poll rather than a request of our own:
  /// `/notifications/unread-count` returns both counts precisely so the two
  /// badges cost one call between them.
  int _unreadConversations = 0;

  final GlobalKey<NotificationBellState> _bell =
      GlobalKey<NotificationBellState>();

  void _goTo(AdminSection section) {
    setState(() => _section = section);

    // Navigating away from a screen that may have read something is the
    // cheapest moment to re-check the counts.
    _bell.currentState?.refresh();
  }

  /// Where a tapped notification goes. The link vocabulary is the server's;
  /// the mapping to sections is ours.
  void _openLink(String link) {
    if (link.startsWith('messages')) {
      setState(() => _section = AdminSection.messages);
    } else if (link.startsWith('access-requests')) {
      setState(() => _section = AdminSection.accessRequests);
    } else if (link.startsWith('models')) {
      setState(() => _section = AdminSection.models);
    } else if (link.startsWith('dashboard')) {
      setState(() => _section = AdminSection.dashboard);
    }
  }

  Widget _buildBell() => NotificationBell(
    key: _bell,
    onCounts: (_, messages) {
      if (mounted && messages != _unreadConversations) {
        setState(() => _unreadConversations = messages);
      }
    },
    onOpenLink: _openLink,
  );

  Widget _buildBody() {
    switch (_section) {
      case AdminSection.dashboard:
        return DashboardHomeScreen(
          onViewAllActivities: () =>
              setState(() => _section = AdminSection.activities),
        );
      case AdminSection.users:
        return const UserManagementScreen();
      case AdminSection.accessRequests:
        return const AccessRequestsScreen();
      case AdminSection.messages:
        return AdminInboxScreen(
          onUnreadChanged: (unread) {
            if (mounted) setState(() => _unreadConversations = unread);
          },
        );
      case AdminSection.news:
        return const NewsManagementScreen();
      case AdminSection.training:
        return const TrainingScreen();
      case AdminSection.models:
        return const ModelManagementScreen();
      case AdminSection.activities:
        return const ActivityLogsScreen();
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
              'ADMINISTRATION',
              style: Theme.of(context).textTheme.labelMedium,
            ),
          ),

          for (final section in AdminSection.values)
            _NavItem(
              section: section,
              selected: _section == section,
              badge: section == AdminSection.messages
                  ? _unreadConversations
                  : 0,
              onTap: () {
                _goTo(section);
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
                        user?.name ?? 'admin',
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

    return Scaffold(
      backgroundColor: AppTheme.background,
      // On narrow screens the sidebar becomes a drawer reachable from the AppBar.
      drawer: isWide
          ? null
          : Drawer(
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.zero,
              ),
              child: _buildSidebar(isDrawer: true),
            ),
      appBar: isWide
          ? null
          : AppBar(
              title: Text(_section.label),
              backgroundColor: AppTheme.surface,
              shape: const Border(bottom: BorderSide(color: AppTheme.border)),
              actions: [_buildBell(), const SizedBox(width: 4)],
            ),
      // Wide layouts have no AppBar, so nothing reserves room for the system
      // status bar and the sidebar would run underneath it on a tablet. On
      // desktop and web the inset is zero and this changes nothing.
      body: SelectionArea(
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
                                    'Administrator console',
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
    );
  }
}

class _NavItem extends StatelessWidget {
  final AdminSection section;
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
