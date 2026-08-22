import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../models/model_status_message.dart';
import '../../models/prediction.dart';
import '../../services/api_client.dart';
import '../../services/me_service.dart';
import '../../services/prediction_service.dart';
import '../../services/upload_resume_store.dart';
import '../../theme/app_theme.dart';
import '../../utils/file_extension.dart';
import '../../utils/frame_bundle.dart';
import '../../widgets/async_state_views.dart';
import '../../widgets/model_status_strip.dart';

/// Start a new interpolation job: pick a model, pick a ZIP, upload.
///
/// Upload transport is chosen for the user by [PredictionService] — a single
/// request for small archives, the resumable chunked flow otherwise — so this
/// screen only tracks one 0..1 progress figure.
class UploadScreen extends StatefulWidget {
  /// Called once a job has been queued, so the shell can show the history.
  final void Function(Prediction queued)? onQueued;

  const UploadScreen({super.key, this.onQueued});

  @override
  State<UploadScreen> createState() => _UploadScreenState();
}

class _UploadScreenState extends State<UploadScreen> {
  final MeService _meService = MeService();
  final PredictionService _service = PredictionService();

  bool _loadingModels = true;
  bool _refreshingModels = false;
  String? _loadError;
  List<AvailableModel> _models = const [];
  AvailableModel? _selectedModel;

  Uint8List? _fileBytes;
  String? _fileName;

  bool _uploading = false;
  double _progress = 0;
  String? _uploadError;

  /// An upload from an earlier run that never finished. The bytes are gone —
  /// only the session is remembered — so resuming asks for the same file back.
  PendingUpload? _pending;

  @override
  void initState() {
    super.initState();
    _loadModels();
    _loadPending();
  }

  Future<void> _loadPending() async {
    final pending = await _service.pendingUpload();
    if (!mounted) return;
    setState(() => _pending = pending);
  }

  Future<void> _discardPending() async {
    await _service.discardPending();
    if (!mounted) return;
    setState(() => _pending = null);
  }

  Future<void> _loadModels() async {
    setState(() {
      _loadingModels = true;
      _loadError = null;
    });

    try {
      final models = await _meService.models();

      if (!mounted) return;
      setState(() {
        _models = models;
        // Preselect the first reachable model so the common case is one tap.
        _selectedModel =
            models.where((m) => m.isAvailable).firstOrNull ??
            models.firstOrNull;
        _loadingModels = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _loadError = e.message;
        _loadingModels = false;
      });
    }
  }

  /// Re-checks model status in place, without the full-screen loading state
  /// [_loadModels] shows on first entry -- a model reported offline is the
  /// whole reason to press this, and losing the file already picked in step 2
  /// while checking would defeat the point.
  ///
  /// This probes the endpoints rather than re-reading the scheduler's last
  /// answer, which is a minute old at worst. Pressing refresh and being told
  /// the same stale thing is not a refresh.
  Future<void> _refreshModels() async {
    setState(() => _refreshingModels = true);

    try {
      final models = await _meService.refreshModels();
      if (!mounted) return;

      final currentId = _selectedModel?.id;
      setState(() {
        _models = models;
        _selectedModel =
            models.where((m) => m.id == currentId).firstOrNull ??
            models.where((m) => m.isAvailable).firstOrNull ??
            models.firstOrNull;
        _refreshingModels = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _refreshingModels = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _pickFile() async {
    // file_picker 11 exposes this statically; the older `FilePicker.platform`
    // accessor is gone.
    //
    // `FileType.any` rather than a `.zip` filter, with the check done in Dart
    // below instead. A `FileType.custom` filter is not portable, and asking
    // for one actively broke mobile web:
    //
    //  - On Android the plugin resolves `custom` to an intent type of `*/*`
    //    regardless, so it never filtered anything there in the first place.
    //  - On a mobile browser it becomes `accept=" .zip"`, which Chrome must
    //    translate into MIME types to build the Android file-chooser intent.
    //    Providers report a ZIP as `application/octet-stream` or
    //    `application/x-zip-compressed` at least as often as
    //    `application/zip`, so the archive renders greyed out and cannot be
    //    selected at all. The same upload works from a laptop browser, where
    //    the OS dialog filters by extension rather than by MIME type.
    final result = await FilePicker.pickFiles(
      type: FileType.any,
      // Several loose .tif frames are as valid a choice as one archive, so a
      // researcher no longer has to zip them first.
      allowMultiple: true,
      // The chunked uploader needs the bytes in memory anyway, and on web
      // there is no path to read from.
      withData: true,
    );

    final picked = result?.files.where((f) => f.bytes != null).toList() ?? [];
    if (picked.isEmpty) return;

    if (!mounted) return;

    // Nothing filtered this for us on any platform, so it is checked here.
    final tiffs = picked
        .where((f) => hasExtension(f.name, const ['tif', 'tiff']))
        .toList();

    if (picked.length == 1 && hasExtension(picked.single.name, const ['zip'])) {
      setState(() {
        _fileBytes = picked.single.bytes;
        _fileName = picked.single.name;
        _uploadError = null;
      });
      return;
    }

    if (tiffs.length == picked.length) {
      // Bundled here so the backend keeps one intake shape. The names travel
      // unchanged; their numbering is what marks the gaps to fill.
      final bundle = await bundleFrames([
        for (final f in tiffs) (name: f.name, bytes: f.bytes!),
      ]);

      if (!mounted) return;

      setState(() {
        _fileBytes = bundle.bytes;
        _fileName = bundle.filename;
        _uploadError = null;
      });
      return;
    }

    setState(() {
      // Cleared, so a previously chosen archive cannot be uploaded by
      // accident while this error is on screen.
      _fileBytes = null;
      _fileName = null;
      _uploadError =
          'Choose one .zip archive, or one or more numbered .tif frames — '
          'not a mixture.';
    });
  }

  Future<void> _submit({bool resuming = false}) async {
    final bytes = _fileBytes;
    final model = _selectedModel;
    final pending = _pending;

    if (bytes == null) return;
    if (!resuming && model == null) return;

    setState(() {
      _uploading = true;
      _progress = 0;
      _uploadError = null;
    });

    try {
      final queued = resuming && pending != null
          ? await _service.resume(
              pending: pending,
              bytes: bytes,
              onProgress: (p) {
                if (mounted) setState(() => _progress = p);
              },
            )
          : await _service.upload(
              bytes: bytes,
              filename: _fileName ?? 'frames.zip',
              modelId: model!.id,
              onProgress: (p) {
                if (mounted) setState(() => _progress = p);
              },
            );

      if (!mounted) return;
      setState(() {
        _uploading = false;
        _fileBytes = null;
        _fileName = null;
        _progress = 0;
        _pending = null;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Queued: ${queued.inputFilesCount} frames, '
            'position ${queued.queuePosition ?? 1} in the queue.',
          ),
          backgroundColor: AppTheme.success,
          duration: const Duration(seconds: 4),
        ),
      );

      widget.onQueued?.call(queued);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _uploading = false;
        _uploadError = e.message;
      });

      // The service keeps the session when the failure looked like network
      // trouble, so re-reading it tells the user whether resuming is on offer.
      await _loadPending();
    }
  }

  /// True when the chosen file is the one the unfinished upload was carrying.
  ///
  /// Compared by size here and by MD5 inside the service — this only decides
  /// what the button says; the service refuses a mismatch outright.
  bool get _isResume =>
      _pending != null && _fileBytes?.length == _pending!.totalSize;

  bool get _canSubmit {
    if (_uploading || _fileBytes == null) return false;

    // Resuming needs no model: the session already carries the one chosen when
    // the upload was started.
    if (_isResume) return true;

    return _selectedModel != null && _selectedModel!.isAvailable;
  }

  static String _mb(int bytes) => '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';

  Widget _buildResumeBanner(BuildContext context, PendingUpload pending) {
    return Container(
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
                      'Unfinished upload',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${pending.filename} (${_mb(pending.totalSize)}) was '
                      'interrupted. Choose the same file below to continue '
                      'from where it stopped — the part already sent is still '
                      'on the server.',
                      style: Theme.of(context).textTheme.bodySmall,
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

  @override
  Widget build(BuildContext context) {
    if (_loadingModels) {
      return const LoadingView(message: 'Loading models...');
    }

    if (_loadError != null) {
      return ErrorView(message: _loadError!, onRetry: _loadModels);
    }

    final isNarrow = MediaQuery.of(context).size.width < 600;

    return SingleChildScrollView(
      padding: EdgeInsets.all(isNarrow ? 16 : 24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'New Analysis',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 4),
              Text(
                'Upload boundary frames and the platform fills the gaps '
                'between them by recursive interpolation at t=0.5.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 24),

              if (_pending != null && !_uploading) ...[
                _buildResumeBanner(context, _pending!),
                const SizedBox(height: 20),
              ],

              // Availability, polled every ten seconds. The Kaggle session
              // behind the model expires on its own, and starting an upload
              // against a model that died four minutes ago wastes the whole
              // archive.
              ModelStatusStrip(
                onChanged: (models) {
                  if (!mounted) return;
                  setState(() {
                    _models = models;
                    // Keep the selection, but re-read its availability so the
                    // START button reflects what the strip just said.
                    final selected = _selectedModel;
                    if (selected != null) {
                      _selectedModel = models
                          .where((m) => m.id == selected.id)
                          .firstOrNull;
                    }
                  });
                },
              ),
              const SizedBox(height: 20),

              const _RequirementsCard(),
              const SizedBox(height: 20),

              Row(
                children: [
                  Expanded(child: _section(context, '1. Choose a model')),
                  IconButton(
                    tooltip: 'Refresh model status',
                    onPressed: _refreshingModels ? null : _refreshModels,
                    icon: _refreshingModels
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.refresh, size: 20),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              _buildModelPicker(context),
              const SizedBox(height: 24),

              _section(context, '2. Choose your frames'),
              const SizedBox(height: 8),
              _buildFilePicker(context),
              const SizedBox(height: 24),

              if (_uploading) ...[
                _buildProgress(context),
                const SizedBox(height: 16),
              ],

              if (_uploadError != null) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.errorLight,
                    border: Border.all(color: AppTheme.error),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.error_outline,
                        color: AppTheme.error,
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      Expanded(child: Text(_uploadError!)),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _canSubmit ? () => _submit(resuming: _isResume) : null,
                  icon: Icon(
                    _isResume ? Icons.play_circle_outline : Icons.play_arrow,
                    size: 18,
                  ),
                  label: Text(
                    _uploading
                        ? 'UPLOADING...'
                        : (_isResume ? 'CONTINUE UPLOAD' : 'START ANALYSIS'),
                  ),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 18),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Results are deleted automatically 24 hours after they are '
                'generated. Download them before then.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _section(BuildContext context, String label) =>
      Text(label, style: Theme.of(context).textTheme.titleMedium);

  Widget _buildModelPicker(BuildContext context) {
    if (_models.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.warningLight,
          border: Border.all(color: AppTheme.warning),
        ),
        child: const Text(
          'No active model is registered. Ask an administrator to add one.',
        ),
      );
    }

    return Column(
      children: [
        for (final model in _models)
          _ModelOption(
            model: model,
            selected: _selectedModel?.id == model.id,
            onTap: model.isAvailable
                ? () => setState(() => _selectedModel = model)
                : null,
          ),
      ],
    );
  }

  Widget _buildFilePicker(BuildContext context) {
    final hasFile = _fileBytes != null;

    return InkWell(
      onTap: _uploading ? null : _pickFile,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: hasFile ? AppTheme.successLight : AppTheme.surface,
          border: Border.all(
            color: hasFile ? AppTheme.success : AppTheme.borderDark,
          ),
        ),
        child: Column(
          children: [
            Icon(
              hasFile ? Icons.check_circle_outline : Icons.upload_file_outlined,
              size: 36,
              color: hasFile ? AppTheme.success : AppTheme.textMuted,
            ),
            const SizedBox(height: 12),
            Text(
              hasFile ? _fileName! : 'Tap to choose your frames',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Text(
              hasFile
                  ? _formatBytes(_fileBytes!.length)
                  : 'A .zip archive, or several numbered .tif frames',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            if (hasFile && !_uploading) ...[
              const SizedBox(height: 8),
              TextButton(
                onPressed: _pickFile,
                child: const Text('CHOOSE A DIFFERENT FILE'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildProgress(BuildContext context) {
    final percent = (_progress * 100).clamp(0, 100).toStringAsFixed(0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Uploading', style: Theme.of(context).textTheme.bodySmall),
            Text('$percent%', style: Theme.of(context).textTheme.labelLarge),
          ],
        ),
        const SizedBox(height: 6),
        LinearProgressIndicator(
          value: _progress == 0 ? null : _progress,
          minHeight: 6,
          backgroundColor: AppTheme.border,
        ),
      ],
    );
  }

  static String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1048576) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1073741824) {
      return '${(bytes / 1048576).toStringAsFixed(1)} MB';
    }
    return '${(bytes / 1073741824).toStringAsFixed(2)} GB';
  }
}

/// What the archive has to contain. Stated up front, because every one of
/// these is a rejection the user would otherwise hit after uploading.
class _RequirementsCard extends StatelessWidget {
  const _RequirementsCard();

  @override
  Widget build(BuildContext context) {
    const rules = [
      'A .zip archive containing .tif or .tiff frames',
      'At least two frames',
      'Frame numbers in the filenames, e.g. frame_001.tif',
      'A gap between those numbers — 001 and 005 generates 002, 003 and 004',
      'Up to 50 MB per frame, and at most 200 generated frames per job',
    ];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.accentLight,
        border: Border.all(color: AppTheme.accent),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.checklist, size: 18, color: AppTheme.accent),
              const SizedBox(width: 8),
              Text(
                'Before you upload',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ],
          ),
          const SizedBox(height: 12),
          for (final rule in rules)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('•  '),
                  Expanded(
                    child: Text(
                      rule,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _ModelOption extends StatelessWidget {
  final AvailableModel model;
  final bool selected;
  final VoidCallback? onTap;

  const _ModelOption({required this.model, required this.selected, this.onTap});

  @override
  Widget build(BuildContext context) {
    final disabled = onTap == null;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: selected ? AppTheme.primaryLight : AppTheme.surface,
            border: Border.all(
              color: selected ? AppTheme.primary : AppTheme.border,
            ),
          ),
          child: Row(
            children: [
              Icon(
                selected
                    ? Icons.radio_button_checked
                    : Icons.radio_button_unchecked,
                size: 18,
                color: disabled
                    ? AppTheme.borderDark
                    : (selected ? AppTheme.primary : AppTheme.textMuted),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      model.label,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: disabled ? AppTheme.textMuted : null,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (model.accuracy != null)
                      Text(
                        'Accuracy ${model.accuracy!.toStringAsFixed(1)}%',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    // Anything short of healthy gets a sentence. For a slow
                    // worker that is not a refusal — it is selectable, and
                    // this says why it will feel sluggish before anyone
                    // presses the button and wonders.
                    if (!model.isOnline) ...[
                      const SizedBox(height: 4),
                      Text(
                        modelStatusMessage(model.healthCheckReason),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: model.isAvailable
                              ? AppTheme.warning
                              : AppTheme.error,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                color: model.isOnline
                    ? AppTheme.successLight
                    : (model.isAvailable
                          ? AppTheme.warningLight
                          : AppTheme.errorLight),
                child: Text(
                  modelStatusLabel(model.status),
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: model.isOnline
                        ? AppTheme.success
                        : (model.isAvailable
                              ? AppTheme.warning
                              : AppTheme.error),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
