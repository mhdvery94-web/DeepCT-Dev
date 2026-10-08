import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../models/pagination.dart';
import '../../models/prediction.dart';
import '../../services/api_client.dart';
import '../../services/prediction_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_dialog.dart';
import '../../widgets/async_state_views.dart';
import '../../widgets/pagination_bar.dart';
import 'frame_gallery_screen.dart';

/// The researcher's jobs: what is running, what finished, and what can still
/// be downloaded before the 24-hour window closes.
///
/// Polls while anything is pending or processing, and stops as soon as
/// everything has settled — there is no push channel, and a job takes ~20s per
/// generated frame.
class PredictionHistoryScreen extends StatefulWidget {
  /// Injectable so a widget test can drive the screen without a network
  /// client. Production builds pass nothing and get the real service.
  final PredictionService? service;

  const PredictionHistoryScreen({super.key, this.service});

  @override
  State<PredictionHistoryScreen> createState() =>
      _PredictionHistoryScreenState();
}

class _PredictionHistoryScreenState extends State<PredictionHistoryScreen> {
  late final PredictionService _service = widget.service ?? PredictionService();

  static const Duration _pollInterval = Duration(seconds: 10);

  List<Prediction> _items = const [];
  Pagination _pagination = const Pagination.empty();

  bool _isLoading = true;
  String? _error;
  int _page = 1;

  /// Set when nothing is consuming the queue at all -- see
  /// `App\Services\QueueHealth` on the backend. Null once a worker picks
  /// jobs up again, so this clears itself on the next poll.
  String? _queueMessage;

  Timer? _poll;

  /// Job id currently downloading, with its 0..1 progress.
  int? _downloadingId;
  double _downloadProgress = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  Future<void> _load({bool showSpinner = true}) async {
    if (showSpinner) {
      setState(() {
        _isLoading = true;
        _error = null;
      });
    }

    try {
      final result = await _service.list(page: _page);

      if (!mounted) return;
      setState(() {
        _items = result.items;
        _pagination = result.pagination;
        _queueMessage = result.queueMessage;
        _isLoading = false;
        _error = null;
      });

      _syncPolling();
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        // A failed background refresh should not blank out a working list.
        if (showSpinner) _error = e.message;
        _isLoading = false;
      });
    }
  }

  /// Runs the timer only while something can still change.
  void _syncPolling() {
    final hasActive = _items.any((p) => p.isActive);

    if (hasActive && _poll == null) {
      _poll = Timer.periodic(_pollInterval, (_) => _load(showSpinner: false));
    } else if (!hasActive) {
      _poll?.cancel();
      _poll = null;
    }
  }

  Future<void> _download(Prediction prediction, String type) async {
    setState(() {
      _downloadingId = prediction.id;
      _downloadProgress = 0;
    });

    try {
      final archive = await _service.download(
        id: prediction.id,
        jobId: prediction.jobId,
        type: type,
        onProgress: (p) {
          if (mounted) setState(() => _downloadProgress = p);
        },
      );

      if (!mounted) return;
      setState(() => _downloadingId = null);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Saved to ${archive.location}'),
          backgroundColor: AppTheme.success,
          duration: const Duration(seconds: 5),
        ),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _downloadingId = null);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message), backgroundColor: AppTheme.error),
      );
    }
  }

  Future<void> _confirmDelete(Prediction prediction) async {
    final confirmed = await showAppAlertDialog<bool>(
      context: context,
      title: 'Delete analysis',
      content: Text(
        'Delete "${prediction.displayName}" and its files? '
        'This cannot be undone.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('CANCEL'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, true),
          style: ElevatedButton.styleFrom(backgroundColor: AppTheme.error),
          child: const Text('DELETE'),
        ),
      ],
    );

    if (confirmed != true) return;

    try {
      await _service.delete(prediction.id);
      await _load(showSpinner: false);
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message), backgroundColor: AppTheme.error),
      );
    }
  }

  /// Queue an upload that was never started.
  ///
  /// The server answers 409 if something already started it — two tabs open on
  /// the same record, or a double tap — and 410 once the files have expired.
  /// Both are worth showing verbatim: they say why nothing happened.
  Future<void> _start(Prediction prediction) async {
    try {
      await _service.start(prediction.id);
      await _load(showSpinner: false);
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message), backgroundColor: AppTheme.error),
      );
      // Whatever the reason, the record is no longer what this screen drew.
      await _load(showSpinner: false);
    }
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Results & History',
                      style: Theme.of(context).textTheme.titleLarge,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (_poll != null)
                      Text(
                        'Refreshing every ${_pollInterval.inSeconds}s while jobs run',
                        style: Theme.of(context).textTheme.bodySmall,
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
          ),
          if (_queueMessage != null) ...[
            const SizedBox(height: 12),
            _QueueWarningBanner(message: _queueMessage!),
          ],
          const SizedBox(height: 16),
          Expanded(child: _buildBody(isNarrow)),
        ],
      ),
    );
  }

  Widget _buildBody(bool isNarrow) {
    if (_isLoading) {
      return const LoadingView(message: 'Loading your analyses...');
    }

    if (_error != null) {
      return ErrorView(message: _error!, onRetry: () => _load());
    }

    if (_items.isEmpty) {
      return const EmptyView(
        message: 'No analyses yet — start one from New Analysis',
        icon: Icons.auto_awesome_outlined,
      );
    }

    return Column(
      children: [
        Expanded(
          child: ListView.separated(
            itemCount: _items.length,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final prediction = _items[index];

              return _PredictionCard(
                prediction: prediction,
                isNarrow: isNarrow,
                downloadProgress: _downloadingId == prediction.id
                    ? _downloadProgress
                    : null,
                onPreview: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => FrameGalleryScreen(prediction: prediction),
                  ),
                ),
                onDownloadResults: () => _download(prediction, 'results'),
                onDownloadComplete: () => _download(prediction, 'complete'),
                onDelete: () => _confirmDelete(prediction),
                onStart: () => _start(prediction),
              );
            },
          ),
        ),
        PaginationBar(
          pagination: _pagination,
          onPageChanged: (p) {
            setState(() => _page = p);
            _load();
          },
        ),
      ],
    );
  }
}

class _PredictionCard extends StatelessWidget {
  final Prediction prediction;
  final bool isNarrow;

  /// Non-null while this card's archive is downloading.
  final double? downloadProgress;

  final VoidCallback onPreview;
  final VoidCallback onDownloadResults;
  final VoidCallback onDownloadComplete;
  final VoidCallback onDelete;
  final VoidCallback onStart;

  const _PredictionCard({
    required this.prediction,
    required this.isNarrow,
    this.downloadProgress,
    required this.onPreview,
    required this.onDownloadResults,
    required this.onDownloadComplete,
    required this.onDelete,
    required this.onStart,
  });

  (Color, IconData, String) get _statusStyle {
    if (prediction.isCompleted) {
      return (AppTheme.success, Icons.check_circle_outline, 'COMPLETED');
    }
    if (prediction.isFailed) {
      return (AppTheme.error, Icons.error_outline, 'FAILED');
    }
    if (prediction.isProcessing) {
      return (AppTheme.accent, Icons.autorenew, 'PROCESSING');
    }
    // An upload nobody started is not queued, and calling it queued sends the
    // researcher away to wait for a worker that will never come for it.
    if (prediction.isUploaded) {
      return (AppTheme.warning, Icons.pause_circle_outline, 'NOT STARTED');
    }
    return (AppTheme.warning, Icons.schedule, 'QUEUED');
  }

  @override
  Widget build(BuildContext context) {
    final (color, icon, label) = _statusStyle;
    final downloading = downloadProgress != null;

    return Container(
      padding: const EdgeInsets.all(16),
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
                child: Icon(icon, size: 18, color: color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      prediction.displayName,
                      style: Theme.of(context).textTheme.titleMedium,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      prediction.modelLabel,
                      style: Theme.of(context).textTheme.bodySmall,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                color: color.withValues(alpha: 0.1),
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          Wrap(
            spacing: 16,
            runSpacing: 4,
            children: [
              _fact(context, '${prediction.inputFilesCount} frames in'),
              // "Ready to analyse" rather than "Uploaded": what is useful is
              // what the researcher can do next, not what just happened.
              if (prediction.isUploaded) _fact(context, 'Ready to analyse'),
              if (prediction.isCompleted)
                _fact(context, '${prediction.outputFilesCount} generated'),
              if (prediction.isCompleted)
                _fact(context, prediction.expiryLabel),
            ],
          ),

          if (prediction.isPending) _queuePlace(context, prediction),

          // The hold-out measurement is no longer shown on its own here. It
          // answers "is this model any good", which is a question about a
          // model rather than about one researcher's run, and on a finished
          // prediction it read as a grade on work they had already accepted.
          //
          // The numbers themselves are not gone: `_comparison` still uses them
          // to rank two runs over the same frames, which is where an error
          // figure earns its place, and the prediction details report the same
          // family of metrics per epoch.
          _comparison(context, prediction),
          _evidence(context, prediction),

          if (prediction.isFailed && prediction.errorMessage != null) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              color: AppTheme.errorLight,
              child: Text(
                prediction.errorMessage!,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ],

          if (prediction.isActive) ...[
            const SizedBox(height: 12),
            const LinearProgressIndicator(minHeight: 3),
          ],

          if (downloading) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: LinearProgressIndicator(
                    value: downloadProgress == 0 ? null : downloadProgress,
                    minHeight: 4,
                    backgroundColor: AppTheme.border,
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  '${(downloadProgress! * 100).toStringAsFixed(0)}%',
                  style: Theme.of(context).textTheme.labelLarge,
                ),
              ],
            ),
          ],

          if (prediction.canDownload && !downloading) ...[
            const SizedBox(height: 12),
            // Wrap, not Row: three controls do not fit a phone width.
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ElevatedButton.icon(
                  onPressed: onPreview,
                  icon: const Icon(Icons.image_outlined, size: 16),
                  label: const Text('PREVIEW'),
                ),
                OutlinedButton.icon(
                  onPressed: onDownloadResults,
                  icon: const Icon(Icons.download, size: 16),
                  label: const Text('RESULTS'),
                ),
                OutlinedButton.icon(
                  onPressed: onDownloadComplete,
                  icon: const Icon(Icons.folder_zip_outlined, size: 16),
                  label: const Text('COMPLETE'),
                ),
                TextButton.icon(
                  onPressed: onDelete,
                  icon: const Icon(Icons.delete_outline, size: 16),
                  label: const Text('DELETE'),
                  style: TextButton.styleFrom(foregroundColor: AppTheme.error),
                ),
              ],
            ),
          ] else if (!prediction.isActive && !downloading) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                // An upload the researcher never started. `PredictionIntake`
                // files it as `uploaded` and no worker will ever claim it, so
                // without this the record sits here describing itself as
                // waiting and waits forever.
                if (prediction.isUploaded)
                  ElevatedButton.icon(
                    key: Key('prediction-start-${prediction.id}'),
                    onPressed: onStart,
                    icon: const Icon(Icons.play_arrow, size: 16),
                    label: const Text('START ANALYSIS'),
                  ),
                TextButton.icon(
                  onPressed: onDelete,
                  icon: const Icon(Icons.delete_outline, size: 16),
                  label: const Text('DELETE'),
                  style: TextButton.styleFrom(foregroundColor: AppTheme.error),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _fact(BuildContext context, String text) =>
      Text(text, style: Theme.of(context).textTheme.bodySmall);

  /// Where in the line this run is, and roughly how long that means.
  ///
  /// A waiting job used to say only "pending", and the position was computed
  /// on the detail endpoint the history screen never calls — so the wait had
  /// no shape at all. Someone watching a spinner with no number cannot tell a
  /// queue of one from a queue of nine, and after a few minutes the only
  /// reasonable conclusion is that it has broken.
  ///
  /// The estimate is deliberately vague in wording and specific in number: it
  /// is an average over recent runs, so it is a guide, not a promise.
  Widget _queuePlace(BuildContext context, Prediction prediction) {
    final place = prediction.queuePosition;
    final wait = prediction.estimatedWaitMinutes;
    final theme = Theme.of(context);

    return Container(
      key: const Key('prediction-queue-place'),
      width: double.infinity,
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.background,
        border: Border(left: BorderSide(color: AppTheme.accent, width: 3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.schedule, size: 16, color: AppTheme.accent),
              const SizedBox(width: 8),
              Text(
                place == null
                    ? 'Waiting to start'
                    : (place == 1
                          ? 'Next to run'
                          : 'Number $place in the queue'),
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          if (wait != null) ...[
            const SizedBox(height: 4),
            Text(
              place == 1
                  ? 'Usually about $wait minute(s) once it starts.'
                  : 'Usually about $wait minute(s) from now.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppTheme.textMuted,
              ),
            ),
          ],
          if (prediction.queueStalledMessage != null) ...[
            const SizedBox(height: 8),
            Text(
              prediction.queueStalledMessage!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppTheme.warning,
                height: 1.45,
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Every run made on these same frames, side by side.
  ///
  /// The registry could always hold several inference endpoints; until there
  /// was a way to put two of them on one set of frames it was plumbing rather
  /// than an instrument. Lower MAE is better, and the winner is marked so
  /// nobody has to squint at four decimal places to find it.
  Widget _comparison(BuildContext context, Prediction prediction) {
    final runs = prediction.comparison;
    if (runs.length < 2) return const SizedBox.shrink();

    final theme = Theme.of(context);

    final measured = runs.where((r) => r.isMeasured).toList()
      ..sort((a, b) => a.mae!.compareTo(b.mae!));
    final best = measured.isEmpty ? null : measured.first;

    return Container(
      key: const Key('prediction-comparison'),
      width: double.infinity,
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(border: Border.all(color: AppTheme.border)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'RUNS ON THESE FRAMES',
            style: theme.textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
              color: AppTheme.textMuted,
            ),
          ),
          const SizedBox(height: 8),
          for (final run in runs)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                children: [
                  if (run.isCurrent)
                    Container(width: 3, height: 14, color: AppTheme.primary)
                  else
                    const SizedBox(width: 3),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      run.modelLabel,
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontWeight: run.isCurrent
                            ? FontWeight.w700
                            : FontWeight.w400,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    // A run still going, or one whose archive offered nothing
                    // to hold out, has no number — and saying which is more
                    // use than printing a dash for both.
                    run.status != 'completed'
                        ? run.status
                        : (run.isMeasured
                              ? 'MAE ${run.mae!.toStringAsFixed(1)}'
                              : 'not measured'),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: best != null && run.id == best.id
                          ? AppTheme.success
                          : AppTheme.textMuted,
                      fontWeight: best != null && run.id == best.id
                          ? FontWeight.w700
                          : FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),
          if (best != null && measured.length > 1) ...[
            const SizedBox(height: 6),
            Text(
              'Lowest error: ${best.modelLabel}. One frame on one archive — '
              'a direction, not a verdict.',
              style: theme.textTheme.labelSmall?.copyWith(
                color: AppTheme.textMuted,
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Thumbnails kept after the frames themselves were deleted.
  ///
  /// Shown only once the files are gone. While they are still there the
  /// gallery is better in every way; this exists for the week afterwards,
  /// when the record used to say a job had completed and offer nothing at all
  /// to look at.
  Widget _evidence(BuildContext context, Prediction prediction) {
    if (prediction.evidence.isEmpty || prediction.canDownload) {
      return const SizedBox.shrink();
    }

    return Container(
      key: const Key('prediction-evidence'),
      width: double.infinity,
      margin: const EdgeInsets.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'KEPT AFTER EXPIRY',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
              color: AppTheme.textMuted,
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 84,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: prediction.evidence.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, i) => _EvidenceThumb(
                predictionId: prediction.id,
                name: prediction.evidence[i],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// One kept thumbnail. Loads its own bytes so the strip builds lazily.
class _EvidenceThumb extends StatelessWidget {
  final int predictionId;
  final String name;

  const _EvidenceThumb({required this.predictionId, required this.name});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 84,
      height: 84,
      child: ColoredBox(
        color: AppTheme.textPrimary,
        child: FutureBuilder<Uint8List>(
          future: PredictionService().evidence(id: predictionId, name: name),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return const Center(
                child: Icon(
                  Icons.broken_image_outlined,
                  size: 18,
                  color: AppTheme.borderDark,
                ),
              );
            }

            if (!snapshot.hasData) {
              return const Center(
                child: SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              );
            }

            return Image.memory(
              snapshot.data!,
              fit: BoxFit.cover,
              filterQuality: FilterQuality.medium,
            );
          },
        ),
      ),
    );
  }
}

/// Nothing is consuming the queue -- a stuck clock icon with no explanation
/// is the most confusing state this screen has, so say so plainly instead of
/// leaving a "QUEUED" job to sit there indefinitely.
class _QueueWarningBanner extends StatelessWidget {
  final String message;

  const _QueueWarningBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.warningLight,
        border: Border.all(color: AppTheme.warning),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.warning_amber_outlined,
            size: 18,
            color: AppTheme.warning,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(message, style: Theme.of(context).textTheme.bodySmall),
          ),
        ],
      ),
    );
  }
}
