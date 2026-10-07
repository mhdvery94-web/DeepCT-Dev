import 'dart:async';

import 'package:flutter/material.dart';

import '../models/model_status_message.dart';
import '../services/me_service.dart';
import '../theme/app_theme.dart';

/// Live availability of the deep-learning workers.
///
/// The model runs in a session that expires on its own, usually without
/// anyone noticing until an upload fails. The server now probes it every ten
/// seconds; this polls that result at the same cadence so the console reads as
/// a status light rather than a page you have to reload.
///
/// Polling, not push: the payload is a handful of rows straight out of the
/// database, and a WebSocket for one number would be infrastructure to
/// maintain forever. The timer stops with the widget.
class ModelStatusStrip extends StatefulWidget {
  /// Called when the poll finds a change, so a screen holding its own copy of
  /// the model list can refresh in step.
  final void Function(List<AvailableModel> models)? onChanged;

  /// Replaces the network fetch. Tests only.
  static Future<List<AvailableModel>> Function()? debugLoader;

  const ModelStatusStrip({super.key, this.onChanged});

  @override
  State<ModelStatusStrip> createState() => _ModelStatusStripState();
}

class _ModelStatusStripState extends State<ModelStatusStrip> {
  final MeService _service = MeService();

  /// Matches the server's health-check schedule. Polling faster would only
  /// re-read the same row.
  static const Duration _interval = Duration(seconds: 10);

  List<AvailableModel> _models = const [];
  Timer? _timer;
  bool _loaded = false;
  bool _unreachable = false;

  @override
  void initState() {
    super.initState();
    _poll();
    _timer = Timer.periodic(_interval, (_) => _poll());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _poll() async {
    try {
      final loader = ModelStatusStrip.debugLoader;
      final models = loader != null ? await loader() : await _service.models();
      if (!mounted) return;

      final changed = !_sameStatuses(_models, models);

      setState(() {
        _models = models;
        _loaded = true;
        _unreachable = false;
      });

      if (changed) widget.onChanged?.call(models);
    } catch (_) {
      if (!mounted) return;
      // Distinguished from "model offline": the platform itself is what we
      // could not reach, and saying "model offline" then would be a guess.
      //
      // Every failure, not just [ApiException]: this decorates other screens,
      // and an ornament that can take the page down with it is a bad trade.
      setState(() {
        _loaded = true;
        _unreachable = true;
      });
    }
  }

  static bool _sameStatuses(List<AvailableModel> a, List<AvailableModel> b) {
    if (a.length != b.length) return false;

    for (var i = 0; i < a.length; i++) {
      if (a[i].id != b[i].id || a[i].status != b[i].status) return false;
    }

    return true;
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) return const SizedBox.shrink();

    if (_unreachable) {
      return _Bar(
        color: AppTheme.textMuted,
        icon: Icons.cloud_off_outlined,
        title: 'Cannot reach the platform',
        detail: 'Model availability is unknown until the connection is back.',
      );
    }

    if (_models.isEmpty) {
      return _Bar(
        color: AppTheme.warning,
        icon: Icons.memory_outlined,
        title: 'No active model',
        detail: 'An administrator has to register one before analysis can run.',
      );
    }

    // Split three ways, not two. `isAvailable` also covers a worker that
    // answers slowly, and summarising that as "online" would hide the only
    // thing worth saying about it.
    final healthy = _models.where((m) => m.isOnline).toList();
    final usable = _models.where((m) => m.isAvailable).toList();

    if (healthy.isNotEmpty) {
      return _Bar(
        color: AppTheme.success,
        icon: Icons.check_circle_outline,
        title: healthy.length == _models.length
            ? 'Model online'
            : '${healthy.length} of ${_models.length} models online',
        detail: '${healthy.first.label} · checked '
            '${_ago(healthy.first.lastHealthCheck)}',
      );
    }

    // Nothing is fully healthy, but something still answers. Amber rather
    // than red, because the work can go ahead — it will just take longer,
    // which is what the message says.
    if (usable.isNotEmpty) {
      final slow = usable.first;

      return _Bar(
        color: AppTheme.warning,
        icon: Icons.hourglass_empty,
        title: 'Model slow',
        detail: '${modelStatusMessage(slow.healthCheckReason)} · checked '
            '${_ago(slow.lastHealthCheck)}',
      );
    }

    final first = _models.first;

    return _Bar(
      color: AppTheme.error,
      icon: Icons.error_outline,
      title: 'Model offline',
      // The reason code turned into words. The checker's own message names
      // the tunnel and the HTTP status; that belongs to the administrator who
      // restarts the worker, and stays on the model management screen.
      detail: '${modelStatusMessage(first.healthCheckReason)} · '
          'checked ${_ago(first.lastHealthCheck)}',
    );
  }

  static String _ago(DateTime? at) {
    if (at == null) return 'never';

    final seconds = DateTime.now().difference(at.toLocal()).inSeconds;
    if (seconds < 15) return 'just now';
    if (seconds < 90) return '${seconds}s ago';

    final minutes = seconds ~/ 60;
    if (minutes < 60) return '${minutes}m ago';

    return '${minutes ~/ 60}h ago';
  }
}

class _Bar extends StatelessWidget {
  final Color color;
  final IconData icon;
  final String title;
  final String detail;

  const _Bar({
    required this.color,
    required this.icon,
    required this.title,
    required this.detail,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: color,
                  ),
                ),
                const SizedBox(height: 2),
                Text(detail, style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
