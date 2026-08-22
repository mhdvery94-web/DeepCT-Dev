import 'package:csv/csv.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/activity_log.dart';
import '../../models/pagination.dart';
import '../../models/user_model.dart';
import '../../services/activity_service.dart';
import '../../services/admin_user_service.dart';
import '../../services/api_client.dart';
import '../../theme/app_theme.dart';
import '../../utils/file_download.dart';
import '../../widgets/app_dialog.dart';
import '../../widgets/async_state_views.dart';
import '../../widgets/pagination_bar.dart';
import '../../widgets/user_avatar.dart';

/// Admin audit trail: who did what, when, and from which IP.
///
/// Supports the backend's user / type / date-range filters and pagination.
class ActivityLogsScreen extends StatefulWidget {
  const ActivityLogsScreen({super.key});

  @override
  State<ActivityLogsScreen> createState() => _ActivityLogsScreenState();
}

class _ActivityLogsScreenState extends State<ActivityLogsScreen> {
  final ActivityService _service = ActivityService();
  final AdminUserService _userService = AdminUserService();

  List<ActivityLog> _logs = [];
  Pagination _pagination = const Pagination.empty();

  /// Populated for the "filter by user" dropdown.
  List<UserModel> _users = [];
  List<String> _types = [];

  bool _isLoading = true;
  String? _error;

  int _page = 1;
  int? _userFilter;
  String? _typeFilter;
  DateTime? _dateFrom;
  DateTime? _dateTo;

  static final DateFormat _apiDate = DateFormat('yyyy-MM-dd');
  static final DateFormat _display = DateFormat('dd MMM yyyy, HH:mm:ss');

  @override
  void initState() {
    super.initState();
    _loadFilters();
    _load();
  }

  /// Loads dropdown options. Failures here are non-fatal: the log list still
  /// works, the user simply gets fewer filter choices.
  Future<void> _loadFilters() async {
    try {
      final results = await Future.wait([
        _service.types(),
        _userService.list(perPage: 100),
      ]);

      if (!mounted) return;
      setState(() {
        _types = results[0] as List<String>;
        _users = (results[1] as dynamic).items as List<UserModel>;
      });
    } on ApiException {
      // Ignore - filters are optional.
    }
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final result = await _service.list(
        page: _page,
        userId: _userFilter,
        type: _typeFilter,
        dateFrom: _dateFrom != null ? _apiDate.format(_dateFrom!) : null,
        dateTo: _dateTo != null ? _apiDate.format(_dateTo!) : null,
      );

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

  Future<void> _pickDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
      initialDateRange: _dateFrom != null && _dateTo != null
          ? DateTimeRange(start: _dateFrom!, end: _dateTo!)
          : null,
    );

    if (picked == null) return;
    setState(() {
      _dateFrom = picked.start;
      _dateTo = picked.end;
      _page = 1;
    });
    _load();
  }

  void _resetFilters() {
    setState(() {
      _userFilter = null;
      _typeFilter = null;
      _dateFrom = null;
      _dateTo = null;
      _page = 1;
    });
    _load();
  }

  bool get _hasFilters =>
      _userFilter != null ||
      _typeFilter != null ||
      _dateFrom != null ||
      _dateTo != null;

  /// Export current filtered activity logs to CSV file
  Future<void> _exportToCSV() async {
    if (_logs.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No data to export'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    try {
      // Prepare CSV data
      final List<List<dynamic>> rows = [];

      // Header row
      rows.add([
        'Timestamp',
        'User',
        'Activity Type',
        'Description',
        'IP Address',
        'User Agent',
      ]);

      // Data rows
      for (final log in _logs) {
        rows.add([
          log.createdAt != null
              ? _display.format(log.createdAt!.toLocal())
              : '-',
          log.actorLabel,
          log.typeLabel,
          log.description ?? '-',
          log.ipAddress ?? '-',
          log.userAgent ?? '-',
        ]);
      }

      // Convert to CSV string
      final csvData = const ListToCsvConverter().convert(rows);

      // Generate filename with timestamp
      final now = DateTime.now();
      final filename =
          'activity_logs_${DateFormat('yyyyMMdd_HHmmss').format(now)}.csv';

      // Browser download on web, a file on disk everywhere else.
      final location = await saveTextFile(filename: filename, content: csvData);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Exported ${_logs.length} records to $location'),
          duration: const Duration(seconds: 4),
          backgroundColor: AppTheme.success,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Export failed: $e'),
          duration: const Duration(seconds: 3),
          backgroundColor: AppTheme.error,
        ),
      );
    }
  }

  // ------------------------------------------------------------------- view

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildToolbar(),
          const SizedBox(height: 16),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: AppTheme.surface,
                border: Border.all(color: AppTheme.border),
              ),
              child: Column(
                children: [
                  Expanded(child: _buildContent()),
                  PaginationBar(
                    pagination: _pagination,
                    onPageChanged: (p) {
                      _page = p;
                      _load();
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToolbar() {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        // Filter by user
        _Dropdown<int?>(
          width: 200,
          hint: 'All users',
          value: _userFilter,
          items: [
            const DropdownMenuItem<int?>(value: null, child: Text('All users')),
            ..._users.map(
              (u) => DropdownMenuItem<int?>(
                value: u.id,
                child: Text(u.name, overflow: TextOverflow.ellipsis),
              ),
            ),
          ],
          onChanged: (v) {
            setState(() {
              _userFilter = v;
              _page = 1;
            });
            _load();
          },
        ),

        // Filter by activity type
        _Dropdown<String?>(
          width: 200,
          hint: 'All types',
          value: _typeFilter,
          items: [
            const DropdownMenuItem<String?>(
              value: null,
              child: Text('All types'),
            ),
            ..._types.map(
              (t) => DropdownMenuItem<String?>(
                value: t,
                child: Text(_titleCase(t), overflow: TextOverflow.ellipsis),
              ),
            ),
          ],
          onChanged: (v) {
            setState(() {
              _typeFilter = v;
              _page = 1;
            });
            _load();
          },
        ),

        OutlinedButton.icon(
          onPressed: _pickDateRange,
          icon: const Icon(Icons.date_range, size: 16),
          label: Text(
            _dateFrom != null && _dateTo != null
                ? '${_apiDate.format(_dateFrom!)} - ${_apiDate.format(_dateTo!)}'
                : 'DATE RANGE',
          ),
        ),

        if (_hasFilters)
          TextButton.icon(
            onPressed: _resetFilters,
            icon: const Icon(Icons.filter_alt_off, size: 16),
            label: const Text('CLEAR'),
          ),

        OutlinedButton.icon(
          onPressed: _isLoading ? null : _load,
          icon: const Icon(Icons.refresh, size: 16),
          label: const Text('REFRESH'),
        ),

        ElevatedButton.icon(
          onPressed: _isLoading || _logs.isEmpty ? null : _exportToCSV,
          icon: const Icon(Icons.download, size: 16),
          label: const Text('EXPORT CSV'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.success,
            foregroundColor: Colors.white,
          ),
        ),
      ],
    );
  }

  Widget _buildContent() {
    if (_isLoading) return const LoadingView(message: 'Loading activity...');
    if (_error != null) return ErrorView(message: _error!, onRetry: _load);
    if (_logs.isEmpty) {
      return const EmptyView(
        message: 'No activity recorded for the selected filters.',
        icon: Icons.history,
      );
    }

    return ListView.separated(
      padding: EdgeInsets.zero,
      itemCount: _logs.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (context, index) => _buildRow(_logs[index]),
    );
  }

  Widget _buildRow(ActivityLog log) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: _typeColor(log.activityType).withValues(alpha: 0.12),
              border: Border.all(
                color: _typeColor(log.activityType).withValues(alpha: 0.35),
              ),
            ),
            child: Icon(
              _typeIcon(log.activityType),
              size: 17,
              color: _typeColor(log.activityType),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    // The action icon on the left says *what* happened; this
                    // says *who*, which is the question an audit log gets
                    // asked most often.
                    UserAvatar(
                      avatarPath: log.userAvatarPath,
                      name: log.userName ?? log.actorLabel,
                      size: 22,
                      bordered: false,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      log.actorLabel,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      color: AppTheme.background,
                      child: Text(
                        log.typeLabel,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textMuted,
                        ),
                      ),
                    ),
                  ],
                ),
                if (log.description != null) ...[
                  const SizedBox(height: 3),
                  Text(log.description!, style: const TextStyle(fontSize: 13)),
                ],
                const SizedBox(height: 5),
                Wrap(
                  spacing: 14,
                  runSpacing: 4,
                  children: [
                    _meta(
                      Icons.schedule,
                      log.createdAt != null
                          ? _display.format(log.createdAt!.toLocal())
                          : '-',
                    ),
                    if (log.ipAddress != null)
                      _meta(Icons.lan_outlined, log.ipAddress!),
                    if (log.userAgent != null && log.userAgent!.isNotEmpty)
                      _meta(
                        Icons.devices_outlined,
                        _shortAgent(log.userAgent!),
                      ),
                  ],
                ),
              ],
            ),
          ),
          if (log.metadata != null && log.metadata!.isNotEmpty)
            IconButton(
              tooltip: 'View details',
              icon: const Icon(Icons.data_object, size: 16),
              onPressed: () => _showMetadata(log),
            ),
        ],
      ),
    );
  }

  Widget _meta(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: AppTheme.textMuted),
        const SizedBox(width: 4),
        Text(
          text,
          style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
        ),
      ],
    );
  }

  void _showMetadata(ActivityLog log) {
    showAppAlertDialog<void>(
      context: context,
      title: log.typeLabel,
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: log.metadata!.entries.map((e) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 140,
                  child: Text(
                    _titleCase(e.key),
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textMuted,
                    ),
                  ),
                ),
                Expanded(
                  child: SelectableText(
                    '${e.value}',
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
      actions: [
        ElevatedButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('CLOSE'),
        ),
      ],
    );
  }

  static String _titleCase(String raw) => raw
      .split('_')
      .where((w) => w.isNotEmpty)
      .map((w) => w[0].toUpperCase() + w.substring(1))
      .join(' ');

  /// User agents are long; show just the leading product token.
  static String _shortAgent(String agent) {
    final cut = agent.split(' ').first;
    return cut.length > 28 ? '${cut.substring(0, 28)}...' : cut;
  }

  static IconData _typeIcon(String type) {
    if (type.contains('login')) return Icons.login;
    if (type.contains('logout')) return Icons.logout;
    if (type.contains('delete')) return Icons.delete_outline;
    if (type.contains('create')) return Icons.add_circle_outline;
    if (type.contains('update')) return Icons.edit_outlined;
    if (type.contains('toggle')) return Icons.toggle_on_outlined;
    if (type.contains('password')) return Icons.key_outlined;
    if (type.contains('health')) return Icons.monitor_heart_outlined;
    if (type.contains('prediction')) return Icons.science_outlined;
    if (type.contains('download')) return Icons.download_outlined;
    return Icons.circle_outlined;
  }

  static Color _typeColor(String type) {
    if (type.contains('delete')) return AppTheme.error;
    if (type.contains('create')) return AppTheme.success;
    if (type.contains('login') || type.contains('logout')) {
      return AppTheme.accent;
    }
    if (type.contains('health') || type.contains('prediction')) {
      return AppTheme.warning;
    }
    return AppTheme.textMuted;
  }
}

/// Bordered dropdown matching the flat BRIN input styling.
class _Dropdown<T> extends StatelessWidget {
  final double width;
  final String hint;
  final T value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T> onChanged;

  const _Dropdown({
    required this.width,
    required this.hint,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        border: Border.all(color: AppTheme.textMuted),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          isExpanded: true,
          hint: Text(hint, style: const TextStyle(fontSize: 14)),
          borderRadius: BorderRadius.zero,
          items: items,
          onChanged: (v) => onChanged(v as T),
        ),
      ),
    );
  }
}
