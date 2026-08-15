import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/activity_log.dart';
import '../../models/me_stats.dart';
import '../../models/pagination.dart';
import '../../services/api_client.dart';
import '../../services/auth_provider.dart';
import '../../services/me_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/async_state_views.dart';
import 'user_activity_tile.dart';

/// Landing section of the researcher console.
///
/// Everything here comes from `/api/me/*`, the only data endpoints a
/// non-admin account can reach. The analysis counters read zero until the
/// FASE 3 pipeline starts writing `analysis_records`.
class UserHomeScreen extends StatefulWidget {
  /// Invoked by the "View all" button so the shell can switch sections.
  final VoidCallback? onViewAllActivity;

  const UserHomeScreen({super.key, this.onViewAllActivity});

  @override
  State<UserHomeScreen> createState() => _UserHomeScreenState();
}

class _UserHomeScreenState extends State<UserHomeScreen> {
  final MeService _service = MeService();

  bool _isLoading = true;
  String? _error;

  MeStats _stats = const MeStats.empty();
  List<ActivityLog> _recent = const [];

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
      // Future.wait runs both in parallel and attaches an error handler to
      // each, so a failure in one never leaves the other unobserved.
      final responses = await Future.wait([
        _service.stats(),
        _service.activities(perPage: 5),
      ]);

      final stats = responses[0] as MeStats;
      final recent = responses[1] as PaginatedResult<ActivityLog>;

      if (!mounted) return;
      setState(() {
        _stats = stats;
        _recent = recent.items;
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

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    final isNarrow = MediaQuery.of(context).size.width < 600;

    if (_isLoading) {
      return const LoadingView(message: 'Loading your dashboard...');
    }

    if (_error != null) {
      return ErrorView(message: _error!, onRetry: _load);
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
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
                        'Welcome back, ${user?.name ?? 'Researcher'}',
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        user?.email ?? '',
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

            // Counters
            Wrap(
              spacing: 16,
              runSpacing: 16,
              children: [
                _StatCard(
                  title: 'Model Availability',
                  value: _stats.modelStatusLabel,
                  icon: _stats.canRunAnalysis
                      ? Icons.check_circle_outline
                      : Icons.error_outline,
                  color: _stats.canRunAnalysis
                      ? AppTheme.success
                      : AppTheme.error,
                  subtitle:
                      '${_stats.modelsOnline} of ${_stats.modelsTotal} reachable',
                  isNarrow: isNarrow,
                ),
                _StatCard(
                  title: 'My Analyses',
                  value: '${_stats.analysesTotal}',
                  icon: Icons.auto_awesome_outlined,
                  color: AppTheme.accent,
                  subtitle: _stats.analysesTotal == 0
                      ? 'None yet — arriving in FASE 3'
                      : '${_stats.analysesCompleted} completed, '
                            '${_stats.analysesProcessing} running',
                  isNarrow: isNarrow,
                ),
                _StatCard(
                  title: "Today's Activity",
                  value: '${_stats.activitiesToday}',
                  icon: Icons.timeline,
                  color: AppTheme.warning,
                  subtitle: '${_stats.activitiesTotal} recorded in total',
                  isNarrow: isNarrow,
                ),
              ],
            ),
            const SizedBox(height: 32),

            // What is coming
            Text(
              'Your Workspace',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            _PlannedFeatures(isNarrow: isNarrow),
            const SizedBox(height: 32),

            // Recent activity
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Text(
                    'Recent Activity',
                    style: Theme.of(context).textTheme.titleLarge,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (widget.onViewAllActivity != null)
                  TextButton.icon(
                    onPressed: widget.onViewAllActivity,
                    icon: const Icon(Icons.arrow_forward, size: 16),
                    label: const Text('VIEW ALL'),
                  ),
              ],
            ),
            const SizedBox(height: 12),

            if (_recent.isEmpty)
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
                child: ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _recent.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, index) =>
                      UserActivityTile(activity: _recent[index]),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// A single headline metric with a breakdown line.
class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final String subtitle;
  final bool isNarrow;

  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    required this.subtitle,
    required this.isNarrow,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      // Full width on a phone so three cards do not become unreadable slivers.
      width: isNarrow ? double.infinity : 280,
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
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  value,
                  textAlign: TextAlign.right,
                  style: Theme.of(
                    context,
                  ).textTheme.headlineMedium?.copyWith(color: color),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}

/// The two FASE 3 features, shown so the researcher can see what is coming.
class _PlannedFeatures extends StatelessWidget {
  final bool isNarrow;

  const _PlannedFeatures({required this.isNarrow});

  static const _upload = _PlannedCard(
    icon: Icons.upload_file_outlined,
    title: 'New Analysis',
    description:
        'Upload two boundary frames (T0 and T2); the platform interpolates '
        'the frames between them at t=0.5.',
  );

  static const _results = _PlannedCard(
    icon: Icons.download_outlined,
    title: 'Results & History',
    description:
        'Preview interpolated frames and download results before they '
        'expire after 24 hours.',
  );

  @override
  Widget build(BuildContext context) {
    if (isNarrow) {
      return const Column(children: [_upload, SizedBox(height: 16), _results]);
    }

    return const Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: _upload),
        SizedBox(width: 16),
        Expanded(child: _results),
      ],
    );
  }
}

class _PlannedCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;

  const _PlannedCard({
    required this.icon,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
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
              Icon(icon, size: 20, color: AppTheme.borderDark),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                color: AppTheme.warningLight,
                child: Text(
                  'FASE 3',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.warning,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            description,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: AppTheme.textMuted),
          ),
        ],
      ),
    );
  }
}
