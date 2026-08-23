import 'dart:async';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../models/prediction_frame.dart';
import '../../models/training.dart';
import '../../services/api_client.dart';
import '../../services/researcher_training_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/file_extension.dart';
import '../../utils/frame_bundle.dart';
import '../../widgets/frame_stack_viewer.dart';

/// Training, from the researcher's side.
///
/// Deliberately the same shape as [UploadScreen] and
/// [PredictionHistoryScreen] side by side: choose an archive, start it, watch
/// the queue. The one real difference is the result — a prediction hands back
/// frames, a run hands back numbers, and the numbers are the point.
class TrainingScreen extends StatefulWidget {
  const TrainingScreen({super.key});

  /// Stands in for the list request under test.
  ///
  /// The same hook [ModelStatusStrip] uses, and for the same reason: the screen
  /// asks the server for something the moment it is built, and a widget test
  /// has no server.
  @visibleForTesting
  static Future<({List<TrainingRun> runs, bool trainerAvailable})> Function()?
  debugLoader;

  @override
  State<TrainingScreen> createState() => _TrainingScreenState();
}

class _TrainingScreenState extends State<TrainingScreen> {
  final ResearcherTrainingService _service = ResearcherTrainingService();

  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _epochs = TextEditingController(text: '10');

  Uint8List? _bytes;
  String? _filename;

  bool _loading = true;
  bool _busy = false;
  double _progress = 0;
  String? _error;
  String? _notice;

  List<TrainingRun> _runs = const [];
  bool _trainerAvailable = false;
  int? _expanded;

  /// Only while something is moving. A finished list does not need polling,
  /// and a screen that keeps asking for a queue nobody is working is the kind
  /// of quiet cost that adds up on a shared server.
  Timer? _poll;
  static const Duration _pollInterval = Duration(seconds: 15);

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _poll?.cancel();
    _name.dispose();
    _epochs.dispose();
    super.dispose();
  }

  Future<void> _load({bool quiet = false}) async {
    if (!quiet) setState(() => _loading = true);

    try {
      final result = await (TrainingScreen.debugLoader?.call() ??
          _service.list());
      if (!mounted) return;

      setState(() {
        _runs = result.runs;
        _trainerAvailable = result.trainerAvailable;
        _loading = false;
      });

      _syncPolling();
    } on ApiException catch (e) {
      if (!mounted) return;
      // A failed background refresh must not blank out a working list.
      setState(() {
        _loading = false;
        if (!quiet) _error = e.message;
      });
    }
  }

  void _syncPolling() {
    final moving = _runs.any((r) => !r.isFinished);

    if (moving && _poll == null) {
      _poll = Timer.periodic(_pollInterval, (_) => _load(quiet: true));
    } else if (!moving) {
      _poll?.cancel();
      _poll = null;
    }
  }

  Future<void> _pick() async {
    // FileType.any, then check the name ourselves: an extension list becomes an
    // `accept` attribute a mobile browser cannot turn into a working filter,
    // and the archive ends up greyed out and unselectable.
    final result = await FilePicker.pickFiles(
      type: FileType.any,
      // Several loose .tif frames are as valid a dataset as one archive, so a
      // researcher no longer has to zip them first.
      allowMultiple: true,
      withData: true,
    );

    final picked = result?.files.where((f) => f.bytes != null).toList() ?? [];
    if (picked.isEmpty) return;
    if (!mounted) return;

    final tiffs = picked
        .where((f) => hasExtension(f.name, const ['tif', 'tiff']))
        .toList();

    if (picked.length == 1 && hasExtension(picked.single.name, const ['zip'])) {
      setState(() {
        _bytes = picked.single.bytes;
        _filename = picked.single.name;
        _error = null;
      });
      return;
    }

    if (tiffs.length == picked.length) {
      // Bundled here so the backend keeps one intake shape. The names travel
      // unchanged; their numbering is what the trainer builds triples from.
      final bundle = await bundleFrames([
        for (final f in tiffs) (name: f.name, bytes: f.bytes!),
      ]);

      if (!mounted) return;

      setState(() {
        _bytes = bundle.bytes;
        _filename = bundle.filename;
        _error = null;
      });
      return;
    }

    setState(() {
      _bytes = null;
      _filename = null;
      _error = 'Choose one .zip archive, or one or more numbered .tif frames '
          '— not a mixture.';
    });
  }

  Future<void> _start() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    if (_bytes == null) {
      setState(() => _error = 'Choose a .zip of frames to train on.');
      return;
    }

    setState(() {
      _busy = true;
      _progress = 0;
      _error = null;
      _notice = null;
    });

    try {
      final started = await _service.start(
        name: _name.text.trim(),
        totalEpochs: int.parse(_epochs.text.trim()),
        bytes: _bytes!,
        filename: _filename ?? 'dataset.zip',
        onProgress: (p) {
          if (mounted) setState(() => _progress = p);
        },
      );

      if (!mounted) return;

      setState(() {
        _busy = false;
        _bytes = null;
        _filename = null;
        _name.clear();
        // The warning, when there is one, is the reason nothing has started —
        // usually that no trainer endpoint is registered yet. Showing it beats
        // a run that sits at `queued` explaining nothing.
        _notice = started.warning ?? started.message;
      });

      await _load(quiet: true);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = e.message;
      });
    }
  }

  Future<void> _cancel(TrainingRun run) async {
    try {
      await _service.cancel(run.id);
      await _load(quiet: true);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    }
  }

  Future<void> _toggle(TrainingRun run) async {
    if (_expanded == run.id) {
      setState(() => _expanded = null);
      return;
    }

    setState(() => _expanded = run.id);

    try {
      final full = await _service.show(run.id);
      if (!mounted) return;

      setState(() {
        _runs = _runs.map((r) => r.id == full.id ? full : r).toList();
      });
    } on ApiException {
      // The row stays open showing what the list already knew. A failed detail
      // fetch is not worth collapsing the thing the user just opened.
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return RefreshIndicator(
      onRefresh: () => _load(quiet: true),
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text('MODEL TRAINING', style: theme.textTheme.headlineSmall),
          const SizedBox(height: 4),
          Text(
            'Upload a set of frames and train a model on it. The result is not '
            'an image — it is how well the model learned, epoch by epoch.',
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: 24),

          _startCard(theme),

          if (_notice != null) ...[
            const SizedBox(height: 16),
            _banner(theme, _notice!, AppTheme.systemBar, AppTheme.border),
          ],
          if (_error != null) ...[
            const SizedBox(height: 16),
            _banner(theme, _error!, AppTheme.errorLight, AppTheme.error),
          ],

          const SizedBox(height: 32),
          Row(
            children: [
              Text('MY RUNS', style: theme.textTheme.titleMedium),
              const Spacer(),
              IconButton(
                tooltip: 'Refresh',
                onPressed: _loading ? null : () => _load(),
                icon: const Icon(Icons.refresh, size: 20),
              ),
            ],
          ),
          const SizedBox(height: 8),

          if (_loading)
            const Padding(
              padding: EdgeInsets.all(32),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_runs.isEmpty)
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                border: Border.all(color: AppTheme.border),
                borderRadius: BorderRadius.zero,
              ),
              child: Text(
                'No training runs yet. Start one above.',
                style: theme.textTheme.bodySmall,
              ),
            )
          else
            for (final run in _runs) _runTile(theme, run),
        ],
      ),
    );
  }

  Widget _startCard(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        border: Border.all(color: AppTheme.border),
        borderRadius: BorderRadius.zero,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('START A RUN', style: theme.textTheme.titleMedium),
            const SizedBox(height: 16),

            TextFormField(
              controller: _name,
              enabled: !_busy,
              decoration: const InputDecoration(labelText: 'RUN NAME'),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Give the run a name' : null,
            ),
            const SizedBox(height: 16),

            TextFormField(
              controller: _epochs,
              enabled: !_busy,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'EPOCHS'),
              validator: (v) {
                final n = int.tryParse((v ?? '').trim());
                if (n == null || n < 1) return 'Enter a whole number of epochs';
                if (n > 10000) return 'That is more epochs than the server allows';
                return null;
              },
            ),
            const SizedBox(height: 16),

            OutlinedButton.icon(
              onPressed: _busy ? null : _pick,
              icon: const Icon(Icons.folder_zip_outlined, size: 16),
              label: Text(_filename ?? 'CHOOSE A .ZIP OF FRAMES'),
            ),
            const SizedBox(height: 8),
            Text(
              'Sent in pieces, so a dropped connection costs seconds rather '
              'than the whole transfer.',
              style: theme.textTheme.labelSmall,
            ),

            if (_busy) ...[
              const SizedBox(height: 16),
              LinearProgressIndicator(value: _progress),
              const SizedBox(height: 4),
              Text(
                'Uploading ${(_progress * 100).toStringAsFixed(0)}%',
                style: theme.textTheme.labelSmall,
              ),
            ],

            if (!_trainerAvailable && !_loading) ...[
              const SizedBox(height: 16),
              Text(
                'No trainer endpoint is registered yet. A run started now is '
                'recorded and waits — an administrator registers one the same '
                'way a model is registered.',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: AppTheme.error,
                ),
              ),
            ],

            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _busy ? null : _start,
              child: Text(_busy ? 'UPLOADING…' : 'START TRAINING'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _runTile(ThemeData theme, TrainingRun run) {
    final open = _expanded == run.id;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        border: Border.all(color: AppTheme.border),
        borderRadius: BorderRadius.zero,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ListTile(
            shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
            title: Text(run.name, style: theme.textTheme.titleSmall),
            subtitle: Text(
              '${run.status.toUpperCase()} · epoch ${run.currentEpoch} of '
              '${run.totalEpochs}'
              '${run.trainerName == null ? '' : ' · ${run.trainerName}'}',
              style: theme.textTheme.labelSmall,
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (!run.isFinished)
                  TextButton(
                    onPressed: () => _cancel(run),
                    child: const Text('CANCEL'),
                  ),
                Icon(open ? Icons.expand_less : Icons.expand_more, size: 20),
              ],
            ),
            onTap: () => _toggle(run),
          ),

          if (run.totalEpochs > 0)
            LinearProgressIndicator(value: run.progressPercent / 100),

          if (open) ...[
            _sampleButton(run),
            _history(theme, run),
          ],
        ],
      ),
    );
  }

  /// The result, and the reason the history is kept at all: one number says how
  /// it is doing, a series says whether it learned anything.
  Widget _history(ThemeData theme, TrainingRun run) {
    if (run.errorMessage != null && run.errorMessage!.isNotEmpty) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Text(
          run.errorMessage!,
          style: theme.textTheme.bodySmall?.copyWith(color: AppTheme.error),
        ),
      );
    }

    if (run.history.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Text(
          'Nothing reported yet. Numbers appear as each epoch finishes.',
          style: theme.textTheme.bodySmall,
        ),
      );
    }

    // The union of every key reported, so a notebook that starts measuring
    // something new needs no change here — then ordered so the four that
    // matter lead and the bookkeeping is dropped.
    final reported = <String, dynamic>{
      for (final p in run.history) ...p.metrics,
    };
    final keys = orderedMetricKeys(reported)
        .where((k) => run.history.any((p) => p.value(k) != null))
        .toList();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      // Wide tables scroll inside their own box rather than pushing the page
      // sideways on a phone.
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          columnSpacing: 28,
          columns: [
            const DataColumn(label: Text('EPOCH')),
            for (final key in keys) DataColumn(label: Text(key.toUpperCase())),
          ],
          rows: [
            for (final point in run.history)
              DataRow(
                cells: [
                  DataCell(Text('${point.epoch}')),
                  for (final key in keys)
                    DataCell(
                      Text(point.value(key)?.toStringAsFixed(4) ?? '—'),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  /// Scrub the rendered frames, one per epoch.
  ///
  /// The axis here is the epoch, not the frame number: what it shows is the
  /// model getting better, which a single number in a table cannot.
  Widget _sampleButton(TrainingRun run) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
    child: Align(
      alignment: Alignment.centerLeft,
      child: OutlinedButton.icon(
        onPressed: () => _openSamples(run),
        icon: const Icon(Icons.image_outlined, size: 18),
        label: const Text('VIEW EPOCH FRAMES'),
      ),
    ),
  );

  Future<void> _openSamples(TrainingRun run) async {
    List<int> epochs;

    try {
      epochs = await _service.samples(run.id);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
      return;
    }

    if (!mounted) return;

    if (epochs.isEmpty) {
      setState(
        () => _error = 'No frames yet. One is recorded as each epoch finishes.',
      );
      return;
    }

    // FrameStackViewer takes PredictionFrame, and reusing it beats a twin
    // type differing by one field. This is the only place in the project
    // where a PredictionFrame is not a prediction frame.
    final frames = [
      for (final e in epochs)
        PredictionFrame(name: 'Epoch $e', kind: 'output', size: 0),
    ];

    if (!mounted) return;

    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => FrameStackViewer(
          frames: frames,
          // The last epoch first: what someone wants to see is where the
          // model is now, not where it started.
          initialIndex: frames.length - 1,
          loader: (name) => _service.sampleImage(
            run.id,
            int.parse(name.split(' ').last),
          ),
        ),
      ),
    );
  }

  Widget _banner(ThemeData theme, String text, Color fill, Color line) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: fill,
        border: Border.all(color: line),
        borderRadius: BorderRadius.zero,
      ),
      child: Text(text, style: theme.textTheme.bodySmall),
    );
  }
}
