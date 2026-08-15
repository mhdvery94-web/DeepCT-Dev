import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/auth_provider.dart';
import '../../theme/app_theme.dart';
import '../landing/landing_page.dart';
import 'user_activity_screen.dart';
import 'user_home_screen.dart';

/// Navigation destinations available to a researcher.
///
/// [analysis] and [history] are placeholders: the prediction pipeline and its
/// endpoints arrive in FASE 3. They are listed rather than hidden so the shape
/// of the product is visible, and each explains what it will do.
enum UserSection {
  dashboard('Dashboard', Icons.dashboard_outlined, available: true),
  analysis('New Analysis', Icons.auto_awesome_outlined, available: false),
  history('Results & History', Icons.folder_outlined, available: false),
  activity('My Activity', Icons.history, available: true);

  const UserSection(this.label, this.icon, {required this.available});

  final String label;
  final IconData icon;

  /// False while the backing endpoints do not exist yet.
  final bool available;
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
        return const _ComingSoonView(
          icon: Icons.auto_awesome_outlined,
          title: 'New Analysis',
          description:
              'Upload two boundary frames (T0 and T2) and the platform will '
              'interpolate the frames between them using recursive '
              'interpolation at t=0.5.',
        );
      case UserSection.history:
        return const _ComingSoonView(
          icon: Icons.folder_outlined,
          title: 'Results & History',
          description:
              'Browse past analyses, preview the interpolated frames and '
              'download the results before they expire after 24 hours.',
        );
    }
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
                const CircleAvatar(
                  radius: 16,
                  backgroundColor: AppTheme.accentLight,
                  child: Icon(
                    Icons.person_outline,
                    size: 18,
                    color: AppTheme.accent,
                  ),
                ),
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
    final muted = !section.available;

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
              color: selected
                  ? AppTheme.primary
                  : (muted ? AppTheme.borderDark : AppTheme.textMuted),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                section.label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                  color: selected
                      ? AppTheme.primary
                      : (muted ? AppTheme.borderDark : AppTheme.textPrimary),
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (muted)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                color: AppTheme.background,
                child: Text(
                  'SOON',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textMuted,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Placeholder for a section whose backend does not exist yet.
class _ComingSoonView extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;

  const _ComingSoonView({
    required this.icon,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 520),
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            border: Border.all(color: AppTheme.border),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 48, color: AppTheme.borderDark),
              const SizedBox(height: 20),
              Text(title, style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 8),
              Container(width: 40, height: 4, color: AppTheme.primary),
              const SizedBox(height: 20),
              Text(
                description,
                textAlign: TextAlign.center,
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: AppTheme.textMuted),
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                color: AppTheme.warningLight,
                child: Text(
                  'ARRIVING IN FASE 3',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.warning,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
