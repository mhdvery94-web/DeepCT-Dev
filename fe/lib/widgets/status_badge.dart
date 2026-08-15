import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Flat, square status pill matching the BRIN design system.
class StatusBadge extends StatelessWidget {
  final String label;
  final Color color;
  final Color background;
  final IconData? icon;

  const StatusBadge({
    super.key,
    required this.label,
    required this.color,
    required this.background,
    this.icon,
  });

  /// Badge for a model health status (`online` / `offline` / `trouble`).
  factory StatusBadge.modelStatus(String status) {
    switch (status) {
      case 'online':
        return const StatusBadge(
          label: 'ONLINE',
          color: AppTheme.success,
          background: AppTheme.successLight,
          icon: Icons.check_circle,
        );
      case 'trouble':
        return const StatusBadge(
          label: 'TROUBLE',
          color: AppTheme.warning,
          background: AppTheme.warningLight,
          icon: Icons.warning_amber_rounded,
        );
      default:
        return const StatusBadge(
          label: 'OFFLINE',
          color: AppTheme.error,
          background: AppTheme.errorLight,
          icon: Icons.cancel,
        );
    }
  }

  /// Badge for an active/inactive flag.
  factory StatusBadge.active(bool isActive) {
    return isActive
        ? const StatusBadge(
            label: 'ACTIVE',
            color: AppTheme.success,
            background: AppTheme.successLight,
          )
        : const StatusBadge(
            label: 'INACTIVE',
            color: AppTheme.textMuted,
            background: Color(0xFFF1F5F9),
          );
  }

  /// Badge for a user role.
  factory StatusBadge.role(String role) {
    return role == 'admin'
        ? const StatusBadge(
            label: 'ADMIN',
            color: AppTheme.primary,
            background: AppTheme.primaryLight,
          )
        : const StatusBadge(
            label: 'USER',
            color: AppTheme.accent,
            background: AppTheme.accentLight,
          );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: background,
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: color),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: color,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}
