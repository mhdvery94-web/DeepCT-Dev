import 'dart:async';

import 'package:flutter/material.dart';

import '../../models/pagination.dart';
import '../../models/prediction.dart';
import '../../services/api_client.dart';
import '../../services/prediction_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/file_download.dart';
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
  const PredictionHistoryScreen({super.key});

  @override
  State<PredictionHistoryScreen> createState() =>
      _PredictionHistoryScreenState();
}

class _PredictionHistoryScreenState extends State<PredictionHistoryScreen> {
  final PredictionService _service = PredictionService();

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

      final location = await saveBytesFile(
        filename: archive.filename,
        bytes: archive.bytes,
        mimeType: 'application/zip',
      );

      if (!mounted) return;
      setState(() => _downloadingId = null);

      final verified = archive.checksumVerified;
      final warning = verified == false
          ? ' — WARNING: checksum mismatch, please retry'
          : '';

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Saved to $location$warning'),
          backgroundColor: verified == false
              ? AppTheme.error
              : AppTheme.success,
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

  const _PredictionCard({
    required this.prediction,
    required this.isNarrow,
    this.downloadProgress,
    required this.onPreview,
    required this.onDownloadResults,
    required this.onDownloadComplete,
    required this.onDelete,
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
              if (prediction.isCompleted)
                _fact(context, '${prediction.outputFilesCount} generated'),
              if (prediction.isPending && prediction.queuePosition != null)
                _fact(context, 'position ${prediction.queuePosition}'),
              if (prediction.isCompleted)
                _fact(context, prediction.expiryLabel),
            ],
          ),

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
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: onDelete,
                icon: const Icon(Icons.delete_outline, size: 16),
                label: const Text('DELETE'),
                style: TextButton.styleFrom(foregroundColor: AppTheme.error),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _fact(BuildContext context, String text) =>
      Text(text, style: Theme.of(context).textTheme.bodySmall);
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
          const Icon(Icons.warning_amber_outlined, size: 18, color: AppTheme.warning),
          const SizedBox(width: 10),
          Expanded(
            child: Text(message, style: Theme.of(context).textTheme.bodySmall),
          ),
        ],
      ),
    );
  }
}
