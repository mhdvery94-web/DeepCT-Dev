import 'package:flutter/material.dart';

import '../models/storage_report.dart';
import '../services/api_client.dart';
import '../theme/app_theme.dart';

/// Free space on the results volume, for the admin console.
///
/// With results on a NAS, "how much room is left" stops being a curiosity and
/// becomes a daily question — and the honest answer has two halves. A volume
/// at 90% mostly holding prediction output is fine: the retention sweep gives
/// it back within a day. A volume at 90% of training datasets is not, because
/// nothing reclaims those. The bar shows the first number; the line under it
/// shows the second.
///
/// Loads itself and stays quiet when it fails. A storage panel that cannot
/// reach the server should not take the dashboard with it.
class StoragePanel extends StatefulWidget {
  const StoragePanel({super.key});

  /// Replaces the network fetch. Tests only.
  static Future<StorageReport> Function()? debugLoader;

  @override
  State<StoragePanel> createState() => _StoragePanelState();
}

class _StoragePanelState extends State<StoragePanel> {
  StorageReport? _report;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final loader = StoragePanel.debugLoader;
      final report = loader != null
          ? await loader()
          : StorageReport.fromJson(
              Map<String, dynamic>.from(
                (await ApiClient.instance.get('/admin/storage'))['data'] as Map,
              ),
            );

      if (!mounted) return;
      setState(() => _report = report);
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final report = _report;
    if (report == null || _failed) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final fraction = report.usedFraction;

    return Container(
      key: const Key('storage-panel'),
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        border: Border.all(
          color: report.mounted ? AppTheme.border : AppTheme.error,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'STORAGE',
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                    color: AppTheme.textMuted,
                  ),
                ),
              ),
              if (report.freeBytes != null)
                Text(
                  '${StorageReport.human(report.freeBytes!)} free',
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
            ],
          ),

          // The one state worth shouting about. An unmounted volume is not an
          // error anything else reports: writes into an absent share succeed,
          // and the files land somewhere nobody will look.
          if (!report.mounted) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              color: AppTheme.errorLight,
              child: Text(
                'The results volume is not mounted. Uploads are being refused '
                'until it is back.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppTheme.error,
                ),
              ),
            ),
          ],

          if (fraction != null) ...[
            const SizedBox(height: 12),
            SizedBox(
              height: 8,
              child: LinearProgressIndicator(
                value: fraction,
                backgroundColor: AppTheme.border,
                valueColor: AlwaysStoppedAnimation(
                  fraction > 0.9
                      ? AppTheme.error
                      : (fraction > 0.75 ? AppTheme.warning : AppTheme.accent),
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '${StorageReport.human(report.usedBytes!)} of '
              '${StorageReport.human(report.totalBytes!)} used',
              style: theme.textTheme.labelSmall?.copyWith(
                color: AppTheme.textMuted,
              ),
            ),
          ],

          const SizedBox(height: 12),
          Wrap(
            spacing: 18,
            runSpacing: 4,
            children: [
              _fact(
                context,
                'Predictions ${StorageReport.human(report.predictionBytes)}',
              ),
              _fact(
                context,
                'Datasets ${StorageReport.human(report.datasetBytes)}',
              ),
              _fact(
                context,
                'Kept thumbnails ${StorageReport.human(report.evidenceBytes)}',
              ),
            ],
          ),

          if (report.reclaimableBytes > 0) ...[
            const SizedBox(height: 8),
            Text(
              // The number that decides whether a full disk is a problem or a
              // Tuesday.
              '${StorageReport.human(report.reclaimableBytes)} of that is '
              'prediction output and temporary files, which retention '
              'reclaims within a day. Training datasets are not reclaimed '
              'automatically.',
              style: theme.textTheme.labelSmall?.copyWith(
                color: AppTheme.textMuted,
                height: 1.4,
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
