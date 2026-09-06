import 'dart:async';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import '../../models/prediction_frame.dart';
import '../../models/training.dart';
import '../../services/api_client.dart';
import '../../services/researcher_training_service.dart';
import '../../services/upload_resume_store.dart';
import '../../theme/app_theme.dart';
import '../../utils/file_extension.dart';
import '../../utils/archive_source.dart';
import '../../utils/file_archive.dart';
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
  static Future<
    ({
      List<TrainingRun> runs,
      bool trainerAvailable,
      int queuedTotal,
      int runningTotal,
    })
  >
  Function()?
  debugLoader;

  /// Stands in for the dataset listing, for the same reason as [debugLoader].
  @visibleForTesting
  static Future<({List<PredictionFrame> frames, bool archiveDeleted})>
  Function(int id)?
  debugDatasetLoader;

  /// Stands in for the unfinished-upload lookup, same reason again.
  @visibleForTesting
  static Future<PendingUpload?> Function()? debugPendingLoader;

  /// Stands in for the upload itself. `resuming` is what distinguishes
  /// continuing a session from opening a new one, which is the branch worth
  /// pinning: a banner that promises to continue and then posts the archive
  /// again from zero is worse than no banner.
  @visibleForTesting
  static Future<({int id, String message, String? warning})> Function({
    required String name,
    required int totalEpochs,
    required ArchiveSource source,
    PendingUpload? resuming,
    void Function(double progress)? onProgress,
  })?
  debugStarter;

  /// Stands in for the file picker's result.
  @visibleForTesting
  static ArchiveSource? debugSource;

  @override
  State<TrainingScreen> createState() => _TrainingScreenState();
}

class _TrainingScreenState extends State<TrainingScreen> {
  final ResearcherTrainingService _service = ResearcherTrainingService();

  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _epochs = TextEditingController(text: '10');

  /// What will be uploaded, and where its bytes come from.
  ///
  /// Not a `Uint8List` any more: a hosted dataset may be 512 MB, and holding
  /// that in the heap so the chunk loop could slice it was the reason a large
  /// upload killed the tab. On a native target this is backed by the picked
  /// file itself and only the current chunk is ever resident.
  ArchiveSource? _source;

  /// Shown on the button. Kept beside [_source] because a native pick sets the
  /// name immediately and opens the file a moment later.
  String? _filename;

  /// A dataset upload started on this device and never finished.
  PendingUpload? _pending;

  bool _loading = true;
  bool _busy = false;
  double _progress = 0;
  String? _error;
  String? _notice;

  List<TrainingRun> _runs = const [];
  bool _trainerAvailable = false;

  /// How busy the trainer is overall — everyone's runs, not just this
  /// account's, because that is what a wait is actually made of.
  int _queuedTotal = 0;
  int _runningTotal = 0;

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
    _loadPending();
  }

  Future<void> _loadPending() async {
    final pending =
        await (TrainingScreen.debugPendingLoader ?? _service.pendingUpload)();

    if (!mounted) return;
    setState(() => _pending = pending);
  }

  Future<void> _discardPending() async {
    await _service.discardPending();
    if (!mounted) return;
    setState(() => _pending = null);
  }

  @override
  void dispose() {
    _poll?.cancel();
    // The source may hold an open file handle; the screen is going away and
    // nothing else knows about it.
    _source?.close();
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
        _queuedTotal = result.queuedTotal;
        _runningTotal = result.runningTotal;
        _loading = false;
      });

      _syncPolling();
    } catch (e) {
      if (!mounted) return;
      // Every failure, not only [ApiException]. A malformed field used to
      // throw a TypeError on the way out of the parser, which this catch did
      // not cover — so `_loading` was never put back and the list spun for
      // ever, on web and on the phone, with nothing on screen to say why.
      //
      // A failed background refresh must still not blank out a working list.
      setState(() {
        _loading = false;
        if (!quiet) {
          _error = e is ApiException
              ? e.message
              : 'Could not read the training runs. $e';
        }
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
      // The whole point. On a native target the picker hands back a path and
      // the archive stays on disk; only the web, which has no path to give,
      // still pays for the bytes.
      withData: kIsWeb,
    );

    final picked =
        result?.files.where((f) => f.bytes != null || f.path != null).toList() ??
        [];
    if (picked.isEmpty) return;
    if (!mounted) return;

    final tiffs = picked
        .where((f) => hasExtension(f.name, const ['tif', 'tiff']))
        .toList();

    if (picked.length == 1 && hasExtension(picked.single.name, const ['zip'])) {
      final single = picked.single;

      setState(() {
        _source = single.bytes != null
            // The web has no path to open, so the picker's bytes are all there
            // is. That path is unchanged and still costs the whole archive.
            ? BytesArchiveSource(single.bytes!, filename: single.name)
            : null;
        _filename = single.name;
        _error = null;
      });

      if (single.bytes == null && single.path != null) {
        final source = await openFileArchive(
          single.path!,
          filename: single.name,
        );

        if (!mounted) {
          await source.close();
          return;
        }

        setState(() => _source = source);
      }

      return;
    }

    if (tiffs.length == picked.length) {
      // Bundled here so the backend keeps one intake shape. The names travel
      // unchanged; their numbering is what the trainer builds triples from.
      final bundle = await bundleFrames([
        for (final f in tiffs) (name: f.name, bytes: await _bytesOf(f)),
      ]);

      if (!mounted) return;

      setState(() {
        // Zipped by this app a moment ago, so it has nowhere to live but
        // memory. Each frame is capped at 50 MB and this path is for a handful
        // of them, not for the 512 MB an archive may be.
        _source = BytesArchiveSource(bundle.bytes, filename: bundle.filename);
        _filename = bundle.filename;
        _error = null;
      });
      return;
    }

    setState(() {
      _source = null;
      _filename = null;
      _error = 'Choose one .zip archive, or one or more numbered .tif frames '
          '— not a mixture.';
    });
  }

  /// Loose frames have to be in memory to be zipped, whichever platform this
  /// is. The picker only fetched bytes on the web, so on a native target they
  /// are read here — one file at a time, each capped at 50 MB.
  Future<Uint8List> _bytesOf(PlatformFile file) async {
    if (file.bytes != null) return file.bytes!;

    final source = await openFileArchive(file.path!, filename: file.name);

    try {
      return await source.read(0, source.length);
    } finally {
      await source.close();
    }
  }

  Future<void> _start() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    if (TrainingScreen.debugSource != null) {
      _source = TrainingScreen.debugSource;
      _filename ??= TrainingScreen.debugSource!.filename;
    }

    if (_source == null) {
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
      final name = _name.text.trim();
      final epochs = int.parse(_epochs.text.trim());
      final source = _source!;
      void report(double p) {
        if (mounted) setState(() => _progress = p);
      }

      final resuming = _pending;
      final starter = TrainingScreen.debugStarter;

      final started = starter != null
          ? await starter(
              name: name,
              totalEpochs: epochs,
              source: source,
              resuming: resuming,
              onProgress: report,
            )
          // A session already half-sent continues from where the server got
          // to. `resume` checks the digest first, so choosing a different file
          // is refused in words rather than spliced into the old session.
          : resuming != null
          ? await _service.resume(
              pending: resuming,
              source: source,
              onProgress: report,
            )
          : await _service.start(
              name: name,
              totalEpochs: epochs,
              source: source,
              onProgress: report,
            );

      if (!mounted) return;

      setState(() {
        _busy = false;
        _source = null;
        _filename = null;
        _pending = null;
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
          if (_pending != null) ...[
            const SizedBox(height: 16),
            _resumeBanner(theme, _pending!),
          ],

          if (_error != null) ...[
            const SizedBox(height: 16),
            _banner(theme, _error!, AppTheme.errorLight, AppTheme.error),
          ],

          const SizedBox(height: 32),
          Row(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('MY RUNS', style: theme.textTheme.titleMedium),
                  // The whole trainer's load, not this account's. A researcher
                  // waiting behind four other people's runs is waiting for
                  // something the list below cannot show them.
                  if (!_loading && (_queuedTotal > 0 || _runningTotal > 0))
                    Text(
                      '$_runningTotal running · $_queuedTotal waiting '
                      'across everyone',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: AppTheme.textMuted,
                      ),
                    ),
                ],
              ),
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

  /// The most recent epoch's numbers, in one line.
  ///
  /// PSNR and SSIM first because they are the two a reader recognises, then
  /// MAE — "how well did it learn" answered without opening anything. Null
  /// when nothing has been reported, which is honest rather than a row of
  /// dashes.
  String? _latestLine(TrainingRun run) {
    final point = run.history.isNotEmpty
        ? run.history.last
        : (run.metrics.isEmpty
              ? null
              : TrainingPoint(epoch: run.currentEpoch, metrics: run.metrics));

    if (point == null) return null;

    final parts = <String>[];

    void add(String key, String label, int digits) {
      final v = point.value(key);
      if (v != null) parts.add('$label ${v.toStringAsFixed(digits)}');
    }

    add('psnr', 'PSNR', 2);
    add('ssim', 'SSIM', 4);
    add('mae', 'MAE', 5);
    add('mse', 'MSE', 6);

    if (parts.isEmpty) return null;

    return 'epoch ${point.epoch} · ${parts.join(' · ')}';
  }

  /// Where this run sits in the line.
  ///
  /// No time estimate on purpose. The prediction queue can offer one because
  /// every run is the same shape of work; a training run is however many
  /// epochs its owner asked for, so the job ahead might take four minutes or
  /// four hours. A number with that spread is worse than none — people plan
  /// around it and it is wrong.
  String _queueLine(int position) {
    final ahead = position - 1;

    if (position == 1) {
      return _runningTotal > 0
          ? 'Next in the queue · the trainer is busy with another run'
          : 'Next in the queue';
    }

    return 'Number $position in the queue · $ahead run(s) ahead';
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
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${run.status.toUpperCase()} · epoch ${run.currentEpoch} of '
                  '${run.totalEpochs}'
                  '${run.trainerName == null ? '' : ' · ${run.trainerName}'}',
                  style: theme.textTheme.labelSmall,
                ),
                // The numbers, without having to open the row first. They are
                // the result of a run, and a list that hides its results
                // behind a tap is a list of names.
                if (_latestLine(run) != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      _latestLine(run)!,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: AppTheme.success,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                if (run.queuePosition != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      _queueLine(run.queuePosition!),
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: AppTheme.textMuted,
                      ),
                    ),
                  ),
              ],
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
  /// Wrap, not Row: two full-width labels do not fit side by side on a phone,
  /// and a Row would overflow rather than fold.
  Widget _sampleButton(TrainingRun run) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
    child: Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        OutlinedButton.icon(
          onPressed: () => _openDataset(run),
          icon: const Icon(Icons.folder_open_outlined, size: 18),
          label: const Text('PREVIEW DATASET'),
        ),
        OutlinedButton.icon(
          onPressed: () => _openSamples(run),
          icon: const Icon(Icons.image_outlined, size: 18),
          label: const Text('VIEW EPOCH FRAMES'),
        ),
      ],
    ),
  );

  /// The frames going in, before a GPU spends hours on them.
  Future<void> _openDataset(TrainingRun run) async {
    ({List<PredictionFrame> frames, bool archiveDeleted}) result;

    try {
      result = await (TrainingScreen.debugDatasetLoader ??
          _service.datasetFrames)(run.id);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
      return;
    }

    if (!mounted) return;

    final frames = result.frames;

    if (frames.isEmpty) {
      setState(
        () => _error = result.archiveDeleted
            // The run itself is intact — its metrics and its weights are
            // still here. Saying the archive held no frames would blame the
            // researcher's upload for a file this platform deleted.
            ? 'The dataset archive has passed its retention window and been '
                  'deleted to free space. The run and its metrics are kept.'
            : 'No .tif frames were found inside that archive.',
      );
      return;
    }

    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => FrameStackViewer(
          frames: frames,
          initialIndex: 0,
          loader: (name) => _service.datasetFramePreview(run.id, name),
        ),
      ),
    );
  }

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

  /// What is waiting, and the one thing to do about it.
  ///
  /// Deliberately the same shape and wording as the prediction screen's: a
  /// researcher meets both, and an interrupted upload should not read as two
  /// different kinds of event depending on which tab it happened in.
  Widget _resumeBanner(ThemeData theme, PendingUpload pending) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: AppTheme.warningLight,
      border: Border.all(color: AppTheme.warning),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.restore, size: 20, color: AppTheme.warning),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Unfinished dataset upload',
                    style: theme.textTheme.titleMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${pending.filename} '
                    '(${(pending.totalSize / 1048576).toStringAsFixed(1)} MB) '
                    'for "${pending.name ?? 'a run'}" was interrupted. Choose '
                    'the same file below to continue from where it stopped — '
                    'the part already sent is still on the server.',
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: _discardPending,
            style: TextButton.styleFrom(foregroundColor: AppTheme.error),
            child: const Text('DISCARD IT'),
          ),
        ),
      ],
    ),
  );
}
