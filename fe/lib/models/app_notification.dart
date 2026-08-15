import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// One entry in the bell.
///
/// [link] is where tapping it should go, in the client's own vocabulary:
/// `messages`, `predictions/12`, `access-requests`, `models`, `dashboard`.
/// The shells interpret it; nothing here knows about navigation.
class AppNotification {
  final String id;

  /// Dotted event name, e.g. `prediction.completed`. Drives the icon.
  final String type;

  final String title;
  final String body;
  final String? link;
  final Map<String, dynamic> meta;
  final bool read;
  final DateTime? createdAt;

  const AppNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    this.link,
    this.meta = const {},
    this.read = false,
    this.createdAt,
  });

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    final meta = json['meta'];

    return AppNotification(
      id: json['id']?.toString() ?? '',
      type: json['type']?.toString() ?? 'general',
      title: json['title']?.toString() ?? '',
      body: json['body']?.toString() ?? '',
      link: json['link']?.toString(),
      meta: meta is Map ? Map<String, dynamic>.from(meta) : const {},
      read: json['read'] == true,
      createdAt: json['created_at'] == null
          ? null
          : DateTime.tryParse(json['created_at'].toString()),
    );
  }

  /// Grouped by what the event is about rather than one icon per type, so a
  /// new event on the server does not need a client release to look right.
  IconData get icon {
    if (type.startsWith('message')) return Icons.forum_outlined;
    if (type.startsWith('prediction.completed')) return Icons.check_circle_outline;
    if (type.startsWith('prediction.failed')) return Icons.error_outline;
    if (type.startsWith('prediction.expiring')) return Icons.schedule;
    if (type.startsWith('prediction')) return Icons.auto_awesome_outlined;
    if (type.startsWith('access_request')) return Icons.how_to_reg_outlined;
    if (type.startsWith('account')) return Icons.person_outline;
    if (type.startsWith('model')) return Icons.memory_outlined;
    return Icons.notifications_none;
  }

  Color get colour {
    if (type.endsWith('.failed') || type == 'model.offline') return AppTheme.error;
    if (type.endsWith('.expiring')) return AppTheme.warning;
    if (type.endsWith('.completed') ||
        type == 'model.online' ||
        type == 'account.approved') {
      return AppTheme.success;
    }
    if (type.startsWith('message')) return AppTheme.primary;
    return AppTheme.accent;
  }

  /// "just now", "12m", "3h", "2d" — a bell has no room for a date.
  String get age {
    final at = createdAt;
    if (at == null) return '';

    final diff = DateTime.now().difference(at.toLocal());

    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    if (diff.inDays < 7) return '${diff.inDays}d';

    return '${(diff.inDays / 7).floor()}w';
  }
}
