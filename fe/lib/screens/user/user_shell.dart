import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/auth_provider.dart';
import '../../widgets/avatar_editor_sheet.dart';
import '../../widgets/user_avatar.dart';
import '../../theme/app_theme.dart';
import '../landing/landing_page.dart';
import '../support/ticket_list_screen.dart';
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
  support('IT Support', Icons.support_agent_outlined);

  const UserSection(this.label, this.icon);

  final String label;
  final IconData icon;
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
      case UserSection.support:
        return const TicketListScreen();
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

  Future<void> _confirmLogout() async {
    final authProvider = context.read<AuthProvider>();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
        title: const Text('Sign out'),
        content: const Text('Are you sure you want to end this session?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('CANCEL'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('SIGN OUT'),
          ),
        ],
      ),
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
                Container(
                  width: 36,
                  height: 36,
                  color: AppTheme.primary,
                  alignment: Alignment.center,
                  child: const Text(
                    'B',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 18,
                    ),
                  ),
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
                        user?.username ?? 'researcher',
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
            ),
      // The wide layout has no AppBar, so nothing reserves room for the system
      // status bar. See fe/README.md.
      body: SafeArea(
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
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            _section.label,
                            style: Theme.of(context).textTheme.headlineLarge,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Researcher console',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
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
    );
  }
}

class _NavItem extends StatelessWidget {
  final UserSection section;
  final bool selected;
  final VoidCallback onTap;

  const _NavItem({
    required this.section,
    required this.selected,
    required this.onTap,
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
          ],
        ),
      ),
    );
  }
}
