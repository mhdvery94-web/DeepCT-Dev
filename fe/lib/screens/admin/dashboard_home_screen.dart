import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../models/activity_log.dart';
import '../../models/model_info.dart';
import '../../models/pagination.dart';
import '../../models/user_model.dart';
import '../../services/activity_service.dart';
import '../../services/admin_model_service.dart';
import '../../services/admin_user_service.dart';
import '../../services/api_client.dart';
import '../../services/auth_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/async_state_views.dart';

/// Landing section of the admin console.
///
/// Shows an at-a-glance overview:
/// - Users, with an active / inactive split
/// - Models, with an online / offline / trouble split
/// - How many activities were recorded today
/// - The 10 most recent activities
class DashboardHomeScreen extends StatefulWidget {
  /// Invoked by the "View all" button so the shell can switch sections.
  final VoidCallback? onViewAllActivities;

  const DashboardHomeScreen({super.key, this.onViewAllActivities});

  @override
  State<DashboardHomeScreen> createState() => _DashboardHomeScreenState();
}

class _DashboardHomeScreenState extends State<DashboardHomeScreen> {
  final AdminUserService _userService = AdminUserService();
  final AdminModelService _modelService = AdminModelService();
  final ActivityService _activityService = ActivityService();

  /// Headline totals come from the server's `pagination.total`; the status
  /// breakdown is derived from one page of rows. This page size comfortably
  /// covers the full registry at the platform's current scale.
  static const int _statsPageSize = 100;

  static final DateFormat _apiDate = DateFormat('yyyy-MM-dd');

  bool _isLoading = true;
  String? _error;

  int _totalUsers = 0;
  int _activeUsers = 0;
  int _inactiveUsers = 0;

  int _totalModels = 0;
  int _onlineModels = 0;
  int _offlineModels = 0;
  int _troubleModels = 0;

  List<ActivityLog> _recentActivities = [];
  int _todayActivityCount = 0;

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

    final today = _apiDate.format(DateTime.now());

    try {
      // Future.wait runs all four in parallel *and* attaches an error handler
      // to every one of them. Awaiting them one by one instead would leave the
      // later futures unobserved if the first threw, turning their failures
      // into unhandled async errors.
      final responses = await Future.wait([
        _userService.list(perPage: _statsPageSize),
        _modelService.list(perPage: _statsPageSize),
        _activityService.list(perPage: 10),
        // Only the total matters here, so ask for the smallest possible page.
        _activityService.list(perPage: 1, dateFrom: today, dateTo: today),
      ]);

      final users = responses[0] as PaginatedResult<UserModel>;
      final models = responses[1] as PaginatedResult<ModelInfo>;
      final recent = responses[2] as PaginatedResult<ActivityLog>;
      final todayActivities = responses[3] as PaginatedResult<ActivityLog>;

      if (!mounted) return;
      setState(() {
        _totalUsers = users.pagination.total;
        _activeUsers = users.items.where((UserModel u) => u.isActive).length;
        _inactiveUsers = users.items.where((UserModel u) => !u.isActive).length;

        _totalModels = models.pagination.total;
        _onlineModels = models.items.where((ModelInfo m) => m.isOnline).length;
        _offlineModels = models.items
            .where((ModelInfo m) => m.isOffline)
            .length;
        _troubleModels = models.items
            .where((ModelInfo m) => m.isTrouble)
            .length;

        _recentActivities = recent.items;
        _todayActivityCount = todayActivities.pagination.total;

        _isLoading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _isLoading = false;
      });
    }
  }

  String get _modelsSubtitle {
    final parts = <String>[
      '$_onlineModels online',
      '$_offlineModels offline',
      if (_troubleModels > 0) '$_troubleModels trouble',
    ];
    return parts.join(', ');
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;

    if (_isLoading) {
      return const LoadingView(message: 'Loading dashboard...');
    }

    if (_error != null) {
      return ErrorView(message: _error!, onRetry: _load);
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
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
                        'Welcome back, ${user?.name ?? 'Admin'}',
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "Here's what's happening on the platform today.",
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
            const SizedBox(height: 24),

            Wrap(
              spacing: 16,
              runSpacing: 16,
              children: [
                _StatCard(
                  title: 'Total Users',
                  value: '$_totalUsers',
                  icon: Icons.people_outline,
                  color: AppTheme.primary,
                  subtitle: '$_activeUsers active, $_inactiveUsers inactive',
                ),
                _StatCard(
                  title: 'AI Models',
                  value: '$_totalModels',
                  icon: Icons.memory_outlined,
                  color: AppTheme.accent,
                  subtitle: _modelsSubtitle,
                ),
                _StatCard(
                  title: "Today's Activity",
                  value: '$_todayActivityCount',
                  icon: Icons.timeline,
                  color: AppTheme.warning,
                  subtitle: 'Actions recorded today',
                ),
              ],
            ),
            const SizedBox(height: 32),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Recent Activities',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                if (widget.onViewAllActivities != null)
                  TextButton.icon(
                    onPressed: widget.onViewAllActivities,
                    icon: const Icon(Icons.arrow_forward, size: 16),
                    label: const Text('VIEW ALL'),
                  ),
              ],
            ),
            const SizedBox(height: 12),

            if (_recentActivities.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: EmptyView(message: 'No activity recorded yet'),
              )
            else
              Container(
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  border: Border.all(color: AppTheme.border),
                ),
                child: ConstrainedBox(
                  // Roughly four rows: long enough to read as a list, short
                  // enough that the dashboard stays one screen on a phone.
                  // Before this the list expanded to its full height and
                  // pushed everything under it off the page.
                  constraints: const BoxConstraints(maxHeight: 320),
                  child: ListView.separated(
                    // Kept deliberately. With a bounded height and no
                    // shrinkWrap the list fills all 320px even when it holds
                    // two rows; this makes it as tall as its content, up to
                    // the cap. What makes it scroll is the removal of
                    // NeverScrollableScrollPhysics, not of shrinkWrap.
                    shrinkWrap: true,
                    itemCount: _recentActivities.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (context, index) =>
                        _ActivityTile(activity: _recentActivities[index]),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// A single headline metric with an optional breakdown line.
class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final String? subtitle;

  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 280,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                color: color.withValues(alpha: 0.1),
                child: Icon(icon, color: color, size: 20),
              ),
              const Spacer(),
              Text(
                value,
                style: Theme.of(
                  context,
                ).textTheme.headlineLarge?.copyWith(color: color),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(subtitle!, style: Theme.of(context).textTheme.bodySmall),
          ],
        ],
      ),
    );
  }
}

/// One row of the "Recent Activities" list.
class _ActivityTile extends StatelessWidget {
  final ActivityLog activity;

  const _ActivityTile({required this.activity});

  IconData get _icon {
    final type = activity.activityType;
    if (type == 'login' || type == 'logout') return Icons.login;
    if (type.contains('model')) return Icons.memory_outlined;
    if (type.contains('user')) return Icons.person_outline;
    return Icons.info_outline;
  }

  Color get _color {
    final type = activity.activityType;
    if (type.contains('delete')) return AppTheme.error;
    if (type.contains('create')) return AppTheme.success;
    if (type.contains('update') || type.contains('toggle')) {
      return AppTheme.warning;
    }
    return AppTheme.primary;
  }

  /// Relative age, e.g. "12m ago". Activities predating a schema change may
  /// have no timestamp at all.
  String get _timeLabel {
    final createdAt = activity.createdAt;
    if (createdAt == null) return 'unknown time';

    final diff = DateTime.now().difference(createdAt.toLocal());
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  @override
  Widget build(BuildContext context) {
    final color = _color;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      leading: Container(
        width: 36,
        height: 36,
        alignment: Alignment.center,
        color: color.withValues(alpha: 0.1),
        child: Icon(_icon, color: color, size: 18),
      ),
      title: Text(
        activity.description ?? activity.typeLabel,
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
      ),
      subtitle: Text(
        'by ${activity.actorLabel} • $_timeLabel',
        style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
      ),
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        color: color.withValues(alpha: 0.1),
        child: Text(
          activity.activityType.replaceAll('_', ' ').toUpperCase(),
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ),
    );
  }
}
