import 'package:flutter/material.dart';

import '../../models/activity_log.dart';
import '../../models/pagination.dart';
import '../../services/api_client.dart';
import '../../services/me_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/async_state_views.dart';
import '../../widgets/pagination_bar.dart';
import 'user_activity_tile.dart';

/// The researcher's own audit trail, paginated.
///
/// Backed by `GET /api/me/activities`, which is scoped server-side to the
/// caller — unlike the admin activity log, there is no user filter here
/// because there is nothing else to see.
class UserActivityScreen extends StatefulWidget {
  const UserActivityScreen({super.key});

  @override
  State<UserActivityScreen> createState() => _UserActivityScreenState();
}

class _UserActivityScreenState extends State<UserActivityScreen> {
  final MeService _service = MeService();

  List<ActivityLog> _logs = const [];
  Pagination _pagination = const Pagination.empty();

  bool _isLoading = true;
  String? _error;
  int _page = 1;

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
      final result = await _service.activities(page: _page);

      if (!mounted) return;
      setState(() {
        _logs = result.items;
        _pagination = result.pagination;
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

  void _goToPage(int page) {
    setState(() => _page = page);
    _load();
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
                child: Text(
                  'My Activity',
                  style: Theme.of(context).textTheme.titleLarge,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              IconButton(
                tooltip: 'Refresh',
                onPressed: _load,
                icon: const Icon(Icons.refresh, size: 20),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Every action recorded against your account.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 16),

          Expanded(child: _buildList()),
        ],
      ),
    );
  }

  Widget _buildList() {
    if (_isLoading) {
      return const LoadingView(message: 'Loading your activity...');
    }

    if (_error != null) {
      return ErrorView(message: _error!, onRetry: _load);
    }

    if (_logs.isEmpty) {
      return const EmptyView(message: 'No activity recorded yet');
    }

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface,
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        children: [
          Expanded(
            child: ListView.separated(
              itemCount: _logs.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, index) => UserActivityTile(
                activity: _logs[index],
                showAbsoluteTime: true,
              ),
            ),
          ),
          PaginationBar(pagination: _pagination, onPageChanged: _goToPage),
        ],
      ),
    );
  }
}
