import 'package:flutter/material.dart';

import '../../models/activity_log.dart';
import '../../theme/app_theme.dart';

/// One row of a researcher's own audit trail.
///
/// Shared by the dashboard's "Recent Activity" list and the full activity
/// screen so both read identically.
class UserActivityTile extends StatelessWidget {
  final ActivityLog activity;

  /// When true the absolute timestamp is shown instead of a relative age.
  final bool showAbsoluteTime;

  const UserActivityTile({
    super.key,
    required this.activity,
    this.showAbsoluteTime = false,
  });

  IconData get _icon {
    final type = activity.activityType;
    if (type == 'login') return Icons.login;
    if (type == 'logout') return Icons.logout;
    if (type.contains('model')) return Icons.memory_outlined;
    if (type.contains('analysis') || type.contains('predict')) {
      return Icons.auto_awesome_outlined;
    }
    return Icons.info_outline;
  }

  Color get _color {
    final type = activity.activityType;
    if (type.contains('delete') || type.contains('fail')) return AppTheme.error;
    if (type.contains('create') || type.contains('complete')) {
      return AppTheme.success;
    }
    if (type.contains('update') || type.contains('toggle')) {
      return AppTheme.warning;
    }
    return AppTheme.accent;
  }

  static String _two(int n) => n.toString().padLeft(2, '0');

  /// Relative age, e.g. "12m ago". Rows predating a schema change may carry no
  /// timestamp at all.
  String get _timeLabel {
    final createdAt = activity.createdAt;
    if (createdAt == null) return 'unknown time';

    final local = createdAt.toLocal();

    if (showAbsoluteTime) {
      return '${_two(local.day)}/${_two(local.month)}/${local.year} '
          '${_two(local.hour)}:${_two(local.minute)}';
    }

    final diff = DateTime.now().difference(local);
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
        activity.ipAddress != null
            ? '$_timeLabel • ${activity.ipAddress}'
            : _timeLabel,
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
