import 'dart:async';

import 'package:flutter/material.dart';

import '../../services/admin_queue_service.dart';
import '../../services/api_client.dart';
import '../../theme/app_theme.dart';
import '../../widgets/async_state_views.dart';
import '../../widgets/user_avatar.dart';

/// Who the model is working for right now, and who is behind them.
///
/// This question used to be answered by reading the activity log and working
/// out which "started an analysis" had no completion after it. That is
/// inference, and it is wrong the moment two runs overlap or a worker dies
/// mid-job — so an administrator asking "whose job is the GPU on" was
/// guessing. `analysis_records` states it outright, which is what the backend
/// reads; see `App\Services\QueueBoard` for why the records and not the log.
///
/// Deliberately live state, not history. "Who has ever used this model" is a
/// different question, already answered by the audit trail and the prediction
/// history, and folding both into one list would bury the urgent one.
class QueueMonitorScreen extends StatefulWidget {
  const QueueMonitorScreen({super.key});

  @override
  State<QueueMonitorScreen> createState() => _QueueMonitorScreenState();
}

class _QueueMonitorScreenState extends State<QueueMonitorScreen> {
  final AdminQueueService _service = AdminQueueService();

  /// The same cadence as the researcher-facing model strip. A board that
  /// updates only when someone presses refresh is a screenshot, and the first
  /// thing anyone would do with it is press refresh repeatedly.
  static const Duration _interval = Duration(seconds: 10);

  QueueBoard _board = const QueueBoard();
  Timer? _timer;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
    _timer = Timer.periodic(_interval, (_) => _load(quiet: true));
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _load({bool quiet = false}) async {
    if (!quiet) setState(() => _loading = true);

    try {
      final board = await _service.board();
      if (!mounted) return;
      setState(() {
        _board = board;
        _loading = false;
        _error = null;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        // A failed poll must not blank a board that is already on screen:
        // slightly stale numbers beat an empty page, and the next tick fixes
        // it without anyone touching anything.
        if (!quiet) _error = e.message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const LoadingView(message: 'Reading the queue...');

    if (_error != null) {
      return ErrorView(message: _error!, onRetry: _load);
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          _header(context),
          const SizedBox(height: 20),

          if (_board.queueMessage != null) ...[
            _stalledBanner(context, _board.queueMessage!),
            const SizedBox(height: 20),
          ],

          if (_board.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 48),
              child: EmptyView(
                message: 'Nothing is running and nothing is waiting.',
                icon: Icons.done_all,
              ),
            )
          else ...[
            if (_board.running.isNotEmpty) ...[
              _sectionTitle(context, 'RUNNING NOW', AppTheme.success),
              const SizedBox(height: 8),
              for (final entry in _board.running)
                _EntryCard(key: Key('queue-running-${entry.id}'), entry: entry),
              const SizedBox(height: 24),
            ],

            if (_board.waiting.isNotEmpty) ...[
              _sectionTitle(context, 'WAITING', AppTheme.textMuted),
              const SizedBox(height: 8),
              for (final entry in _board.waiting)
                _EntryCard(key: Key('queue-waiting-${entry.id}'), entry: entry),
            ],
          ],
        ],
      ),
    );
  }

  Widget _header(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Queue', style: theme.textTheme.headlineSmall),
              const SizedBox(height: 4),
              Text(
                _board.isEmpty
                    ? 'The model is idle.'
                    // The per-run average is shown because every estimate on
                    // this page is built from it, and it is measured rather
                    // than assumed.
                    : '${_board.running.length} running · '
                          '${_board.waiting.length} waiting · '
                          'about ${_board.minutesPerJob} min per run',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppTheme.textMuted,
                ),
              ),
            ],
          ),
        ),
        IconButton(
          tooltip: 'Refresh',
          onPressed: () => _load(),
          icon: const Icon(Icons.refresh, size: 20),
        ),
      ],
    );
  }

  Widget _sectionTitle(BuildContext context, String text, Color color) => Text(
    text,
    style: Theme.of(context).textTheme.labelSmall?.copyWith(
      fontWeight: FontWeight.w700,
      letterSpacing: 0.8,
      color: color,
    ),
  );

  Widget _stalledBanner(BuildContext context, String message) {
    return Container(
      key: const Key('queue-stalled-banner'),
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.errorLight,
        border: Border.all(color: AppTheme.error),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.warning_amber, color: AppTheme.error, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(height: 1.45),
            ),
          ),
        ],
      ),
    );
  }
}

class _EntryCard extends StatelessWidget {
  const _EntryCard({super.key, required this.entry});

  final QueueEntry entry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final running = entry.isRunning;
    final accent = running ? AppTheme.success : AppTheme.textMuted;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        border: Border(
          left: BorderSide(color: accent, width: 3),
          top: const BorderSide(color: AppTheme.border),
          right: const BorderSide(color: AppTheme.border),
          bottom: const BorderSide(color: AppTheme.border),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // The place in line, or a spinner for the one in hand. This is what
          // the eye lands on first, and it is the ordering of the whole page.
          SizedBox(
            width: 44,
            child: running
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppTheme.success,
                    ),
                  )
                : Text(
                    '#${entry.queuePosition ?? '-'}',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textMuted,
                    ),
                  ),
          ),
          UserAvatar(avatarPath: null, name: entry.who, size: 32, bordered: false),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.who,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                if (entry.userEmail != null)
                  Text(
                    entry.userEmail!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppTheme.textMuted,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 14,
                  runSpacing: 2,
                  children: [
                    _fact(context, '${entry.inputFilesCount} frames'),
                    _fact(context, entry.model),
                    _fact(
                      context,
                      running
                          ? 'running ${entry.elapsedLabel}'
                          : 'waiting ${entry.elapsedLabel}',
                    ),
                    if (!running && entry.estimatedWaitMinutes != null)
                      _fact(
                        context,
                        'starts in about ${entry.estimatedWaitMinutes} min',
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _fact(BuildContext context, String text) => Text(
    text,
    style: Theme.of(
      context,
    ).textTheme.bodySmall?.copyWith(color: AppTheme.textMuted),
  );
}
