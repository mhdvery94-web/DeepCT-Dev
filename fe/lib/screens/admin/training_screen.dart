import 'dart:async';

import 'package:flutter/material.dart';

import '../../models/pagination.dart';
import '../../models/training.dart';
import '../../services/api_client.dart';
import '../../services/me_service.dart';
import '../../services/training_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_dialog.dart';
import '../../widgets/async_state_views.dart';
import '../../widgets/pagination_bar.dart';

/// Managed model training.
///
/// The platform never trains anything — it records what should be trained and
/// what came back. A GPU worker on Kaggle claims a job, reports progress, and
/// hands weights back. That split is forced: this machine has no GPU and a PHP
/// backend, and the machine that does have a GPU expires every 9–12 hours.
///
/// The screen is one column on a phone and two on a desktop, because an
/// administrator will genuinely check a running job from a phone — training
/// takes days.
class TrainingScreen extends StatefulWidget {
  const TrainingScreen({super.key});

  @override
  State<TrainingScreen> createState() => _TrainingScreenState();
}

class _TrainingScreenState extends State<TrainingScreen> {
  final TrainingService _service = TrainingService();

  List<TrainingDataset> _datasets = const [];
  List<TrainingJob> _jobs = const [];
  Pagination _pagination = const Pagination.empty();

  bool _isLoading = true;
  String? _error;
  int _page = 1;
  String? _statusFilter;

  int _queued = 0;
  int _running = 0;
  bool _workerConfigured = true;

  Timer? _poll;

  /// Slower than the model status light: a training epoch takes minutes, so
  /// anything faster would just re-read the same row.
  static const Duration _pollInterval = Duration(seconds: 20);

  @override
  void initState() {
    super.initState();
    _load();
    _poll = Timer.periodic(_pollInterval, (_) => _load(quiet: true));
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  /// [quiet] refreshes in place: a background poll must not blank the screen
  /// an administrator is reading.
  Future<void> _load({bool quiet = false}) async {
    if (!quiet) {
      setState(() {
        _isLoading = true;
        _error = null;
      });
    }

    try {
      final results = await Future.wait([
        _service.datasets(),
        _service.jobs(page: _page, status: _statusFilter),
      ]);

      if (!mounted) return;

      final jobs = results[1] as ({
        PaginatedResult<TrainingJob> page,
        int queuedCount,
        int runningCount,
        bool workerConfigured,
      });

      setState(() {
        _datasets = results[0] as List<TrainingDataset>;
        _jobs = jobs.page.items;
        _pagination = jobs.page.pagination;
        _queued = jobs.queuedCount;
        _running = jobs.runningCount;
        _workerConfigured = jobs.workerConfigured;
        _isLoading = false;
        _error = null;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      // A failed background poll leaves what is on screen alone.
      if (quiet) return;

      setState(() {
        _error = e.message;
        _isLoading = false;
      });
    }
  }

  void _report(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? AppTheme.error : AppTheme.success,
      ),
    );
  }

  Future<void> _addDataset() async {
    final added = await showAppDialog<bool>(
      context: context,
      maxWidth: 520,
      builder: (_) => const _DatasetForm(),
    );

    if (added == true) await _load();
  }

  Future<void> _deleteDataset(TrainingDataset dataset) async {
    final confirmed = await showAppAlertDialog<bool>(
      context: context,
      title: 'Delete dataset',
      content: Text('Delete "${dataset.name}"? This cannot be undone.'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('CANCEL'),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: AppTheme.error),
          onPressed: () => Navigator.pop(context, true),
          child: const Text('DELETE'),
        ),
      ],
    );

    if (confirmed != true) return;

    try {
      await _service.deleteDataset(dataset.id);
      _report('Dataset deleted.');
      await _load();
    } on ApiException catch (e) {
      _report(e.message, isError: true);
    }
  }

  Future<void> _queueJob() async {
    if (_datasets.isEmpty) {
      _report('Register a dataset first.', isError: true);
      return;
    }

    final queued = await showAppDialog<bool>(
      context: context,
      maxWidth: 520,
      builder: (_) => _JobForm(datasets: _datasets),
    );

    if (queued == true) await _load();
  }

  /// Push a queued job to the GPU host, the way a prediction is pushed to a
  /// model endpoint.
  Future<void> _dispatchJob(TrainingJob job) async {
    final url = await showAppDialog<String>(
      context: context,
      maxWidth: 480,
      builder: (_) => _DispatchForm(job: job),
    );

    if (url == null) return;

    try {
      final message = await _service.dispatchJob(
        job.id,
        trainerUrl: url.isEmpty ? null : url,
      );
      _report(message);
      await _load();
    } on ApiException catch (e) {
      _report(e.message, isError: true);
    }
  }

  Future<void> _cancelJob(TrainingJob job) async {
    final confirmed = await showAppAlertDialog<bool>(
      context: context,
      title: 'Cancel training',
      content: Text(
        'Stop "${job.name}" at ${job.epochLabel}? The worker finds out on its '
        'next heartbeat and stops there.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('KEEP TRAINING'),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: AppTheme.error),
          onPressed: () => Navigator.pop(context, true),
          child: const Text('CANCEL JOB'),
        ),
      ],
    );

    if (confirmed != true) return;

    try {
      await _service.cancelJob(job.id);
      _report('Job cancelled.');
      await _load();
    } on ApiException catch (e) {
      _report(e.message, isError: true);
    }
  }

  Future<void> _deleteJob(TrainingJob job) async {
    try {
      await _service.deleteJob(job.id);
      _report('Job deleted.');
      await _load();
    } on ApiException catch (e) {
      _report(e.message, isError: true);
    }
  }

  Future<void> _registerModel(TrainingJob job) async {
    final message = await showAppDialog<String>(
      context: context,
      maxWidth: 480,
      builder: (_) => _RegisterModelForm(job: job),
    );

    if (message == null) return;

    _report(message);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width >= 1100;
    final isNarrow = MediaQuery.of(context).size.width < 600;

    return Padding(
      padding: EdgeInsets.all(isNarrow ? 16 : 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(context),
          const SizedBox(height: 12),

          if (!_workerConfigured) ...[
            _WarningBar(
              title: 'No GPU worker is configured',
              detail: 'Jobs will sit in the queue until '
                  'TRAINING_WORKER_TOKEN is set on the server and a worker '
                  'notebook is running. Generate one with '
                  '`php artisan training:token`.',
            ),
            const SizedBox(height: 12),
          ],

          Expanded(child: _buildBody(isWide)),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Model Training',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              Text(
                '$_queued queued, $_running running · '
                '${_datasets.length} dataset${_datasets.length == 1 ? '' : 's'}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
        IconButton(
          tooltip: 'Refresh',
          onPressed: _load,
          icon: const Icon(Icons.refresh, size: 20),
        ),
        ElevatedButton.icon(
          onPressed: _queueJob,
          icon: const Icon(Icons.play_arrow, size: 16),
          label: const Text('NEW JOB'),
        ),
      ],
    );
  }

  Widget _buildBody(bool isWide) {
    if (_isLoading) return const LoadingView(message: 'Loading training...');
    if (_error != null) return ErrorView(message: _error!, onRetry: _load);

    final jobs = _buildJobList(context);
    final datasets = _buildDatasetList(context);

    if (!isWide) {
      return ListView(
        children: [
          jobs,
          const SizedBox(height: 24),
          datasets,
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(flex: 7, child: jobs),
        const SizedBox(width: 24),
        Expanded(flex: 4, child: SingleChildScrollView(child: datasets)),
      ],
    );
  }

  Widget _buildJobList(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final option in const [
              (null, 'ALL'),
              ('queued', 'QUEUED'),
              ('running', 'RUNNING'),
              ('completed', 'COMPLETED'),
              ('failed', 'FAILED'),
            ])
              _Chip(
                label: option.$2,
                selected: _statusFilter == option.$1,
                onTap: () {
                  setState(() {
                    _statusFilter = option.$1;
                    _page = 1;
                  });
                  _load();
                },
              ),
          ],
        ),
        const SizedBox(height: 12),

        if (_jobs.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 40),
            child: EmptyView(
              message: 'No training jobs yet',
              icon: Icons.model_training_outlined,
            ),
          )
        else ...[
          for (final job in _jobs) ...[
            _JobCard(
              job: job,
              onDispatch: () => _dispatchJob(job),
              onCancel: () => _cancelJob(job),
              onDelete: () => _deleteJob(job),
              onRegister: () => _registerModel(job),
            ),
            const SizedBox(height: 10),
          ],
          PaginationBar(
            pagination: _pagination,
            onPageChanged: (p) {
              setState(() => _page = p);
              _load();
            },
          ),
        ],
      ],
    );
  }

  Widget _buildDatasetList(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Datasets',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            TextButton.icon(
              onPressed: _addDataset,
              icon: const Icon(Icons.add, size: 16),
              label: const Text('ADD'),
            ),
          ],
        ),
        const SizedBox(height: 8),

        if (_datasets.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              border: Border.all(color: AppTheme.border),
            ),
            child: Text(
              'No datasets. Add one by URL for anything large — a dataset '
              'does not need to travel through this server to reach the GPU.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          )
        else
          for (final dataset in _datasets) ...[
            _DatasetCard(
              dataset: dataset,
              onDelete: () => _deleteDataset(dataset),
            ),
            const SizedBox(height: 8),
          ],
      ],
    );
  }
}

// --------------------------------------------------------------- pieces

class _WarningBar extends StatelessWidget {
  final String title;
  final String detail;

  const _WarningBar({required this.title, required this.detail});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.warningLight,
        border: Border.all(color: AppTheme.warning),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.warning_amber_outlined,
              size: 18, color: AppTheme.warning),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleMedium),
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

class _Chip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _Chip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? AppTheme.primary : AppTheme.surface,
          border: Border.all(
            color: selected ? AppTheme.primary : AppTheme.border,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: selected ? Colors.white : AppTheme.textMuted,
          ),
        ),
      ),
    );
  }
}

class _JobCard extends StatelessWidget {
  final TrainingJob job;
  final VoidCallback onDispatch;
  final VoidCallback onCancel;
  final VoidCallback onDelete;
  final VoidCallback onRegister;

  const _JobCard({
    required this.job,
    required this.onDispatch,
    required this.onCancel,
    required this.onDelete,
    required this.onRegister,
  });

  Color get _statusColor => switch (job.status) {
    'running' => AppTheme.success,
    'claimed' => AppTheme.accent,
    'queued' => AppTheme.warning,
    'completed' => AppTheme.primary,
    'failed' => AppTheme.error,
    _ => AppTheme.textMuted,
  };

  @override
  Widget build(BuildContext context) {
    final progress = job.progress;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  job.name,
                  style: Theme.of(context).textTheme.titleMedium,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 3,
                ),
                color: _statusColor.withValues(alpha: 0.12),
                child: Text(
                  job.statusLabel,
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                    color: _statusColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          if (progress != null) ...[
            LinearProgressIndicator(
              value: progress,
              minHeight: 6,
              backgroundColor: AppTheme.background,
              color: _statusColor,
            ),
            const SizedBox(height: 6),
          ],

          Wrap(
            spacing: 12,
            runSpacing: 4,
            children: [
              Text(job.epochLabel,
                  style: Theme.of(context).textTheme.bodySmall),
              if (job.datasetName != null)
                Text(job.datasetName!,
                    style: Theme.of(context).textTheme.bodySmall),
              if (job.workerLabel != null)
                Text('on ${job.workerLabel}',
                    style: Theme.of(context).textTheme.bodySmall),
              for (final entry in job.metrics.entries.take(3))
                Text('${entry.key} ${entry.value}',
                    style: Theme.of(context).textTheme.bodySmall),
            ],
          ),

          if (job.looksStalled) ...[
            const SizedBox(height: 8),
            Text(
              'The worker has gone quiet. Its Kaggle session has probably '
              'expired — the job returns to the queue automatically and the '
              'next worker resumes from the last checkpoint.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppTheme.warning,
              ),
            ),
          ],

          if (job.errorMessage != null) ...[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              color: AppTheme.errorLight,
              child: Text(
                job.errorMessage!,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ],

          if (job.isAwaitingTrainer) ...[
            const SizedBox(height: 8),
            Text(
              'Sent to the trainer. It stays queued until the first heartbeat '
              'arrives — accepting a job is not the same as starting it.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],

          const SizedBox(height: 6),
          Wrap(
            children: [
              if (job.isQueued)
                TextButton.icon(
                  onPressed: onDispatch,
                  icon: const Icon(Icons.send_outlined, size: 16),
                  label: Text(
                    job.isAwaitingTrainer ? 'SEND AGAIN' : 'SEND TO TRAINER',
                  ),
                ),
              if (!job.isFinished)
                TextButton.icon(
                  onPressed: onCancel,
                  icon: const Icon(Icons.stop_circle_outlined, size: 16),
                  label: const Text('CANCEL'),
                  style: TextButton.styleFrom(
                    foregroundColor: AppTheme.error,
                  ),
                ),
              if (job.status == 'completed' &&
                  job.hasWeights &&
                  job.resultingModelId == null)
                TextButton.icon(
                  onPressed: onRegister,
                  icon: const Icon(Icons.verified_outlined, size: 16),
                  label: const Text('REGISTER AS MODEL'),
                ),
              if (job.resultingModelId != null)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 12,
                  ),
                  child: Text(
                    'Registered as model #${job.resultingModelId}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              if (job.isFinished)
                TextButton.icon(
                  onPressed: onDelete,
                  icon: const Icon(Icons.delete_outline, size: 16),
                  label: const Text('DELETE'),
                  style: TextButton.styleFrom(
                    foregroundColor: AppTheme.error,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DatasetCard extends StatelessWidget {
  final TrainingDataset dataset;
  final VoidCallback onDelete;

  const _DatasetCard({required this.dataset, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                dataset.isHosted ? Icons.folder_zip_outlined : Icons.link,
                size: 16,
                color: AppTheme.textMuted,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  dataset.name,
                  style: Theme.of(context).textTheme.titleMedium,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              IconButton(
                tooltip: 'Delete',
                onPressed: onDelete,
                icon: const Icon(Icons.delete_outline, size: 16),
                color: AppTheme.error,
              ),
            ],
          ),
          Text(
            dataset.isHosted
                ? 'Hosted here · ${dataset.sizeLabel}'
                : 'Fetched by the worker',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          if (dataset.jobsCount > 0)
            Text(
              '${dataset.jobsCount} job${dataset.jobsCount == 1 ? '' : 's'}',
              style: Theme.of(context).textTheme.labelSmall,
            ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------- forms

class _DatasetForm extends StatefulWidget {
  const _DatasetForm();

  @override
  State<_DatasetForm> createState() => _DatasetFormState();
}

class _DatasetFormState extends State<_DatasetForm> {
  final TrainingService _service = TrainingService();
  final _formKey = GlobalKey<FormState>();

  final _name = TextEditingController();
  final _description = TextEditingController();
  final _url = TextEditingController();

  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    _url.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      await _service.addDataset(
        name: _name.text.trim(),
        description: _description.text.trim().isEmpty
            ? null
            : _description.text.trim(),
        sourceUrl: _url.text.trim(),
      );

      if (!mounted) return;
      Navigator.pop(context, true);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = e.message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Add dataset',
                  style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 16),

              TextFormField(
                controller: _name,
                decoration: const InputDecoration(labelText: 'Name'),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Name is required' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _description,
                minLines: 2,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Description (optional)',
                ),
              ),
              const SizedBox(height: 20),

              // Upload is gone from this form, and the backend refuses it now
              // too. An administrator registering a dataset is recording where
              // data already lives; carrying it through this server so the GPU
              // host can pull it back down wastes both trips. Researchers
              // upload — chunked, resumable, and on their own screen.
              TextFormField(
                controller: _url,
                decoration: const InputDecoration(
                  labelText: 'Archive URL',
                  hintText: 'https://…/frames.zip',
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'URL is required';
                  if (!v.startsWith('http')) return 'Enter a full URL';
                  return null;
                },
              ),
              const SizedBox(height: 8),
              Text(
                'The GPU worker fetches this itself, which is the right way '
                'round for a large dataset.',
                style: Theme.of(context).textTheme.labelSmall,
              ),

              if (_error != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.errorLight,
                    border: Border.all(color: AppTheme.error),
                  ),
                  child: Text(_error!,
                      style: Theme.of(context).textTheme.bodySmall),
                ),
              ],

              const SizedBox(height: 20),
              Row(
                children: [
                  TextButton(
                    onPressed: _busy ? null : () => Navigator.pop(context),
                    child: const Text('CANCEL'),
                  ),
                  const Spacer(),
                  ElevatedButton(
                    onPressed: _busy ? null : _submit,
                    child: _busy
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text('ADD'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _JobForm extends StatefulWidget {
  final List<TrainingDataset> datasets;

  const _JobForm({required this.datasets});

  @override
  State<_JobForm> createState() => _JobFormState();
}

class _JobFormState extends State<_JobForm> {
  final TrainingService _service = TrainingService();
  final MeService _meService = MeService();
  final _formKey = GlobalKey<FormState>();

  final _name = TextEditingController();
  final _epochs = TextEditingController(text: '100');
  final _learningRate = TextEditingController(text: '0.0002');
  final _batchSize = TextEditingController(text: '4');

  late int _datasetId = widget.datasets.first.id;
  int? _baseModelId;
  List<AvailableModel> _models = const [];

  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadModels();
  }

  @override
  void dispose() {
    _name.dispose();
    _epochs.dispose();
    _learningRate.dispose();
    _batchSize.dispose();
    super.dispose();
  }

  Future<void> _loadModels() async {
    try {
      final models = await _meService.models();
      if (!mounted) return;
      setState(() => _models = models);
    } on ApiException {
      // Fine-tuning is optional; training from scratch still works.
    }
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      await _service.queueJob(
        name: _name.text.trim(),
        datasetId: _datasetId,
        baseModelId: _baseModelId,
        totalEpochs: int.tryParse(_epochs.text.trim()) ?? 100,
        hyperparameters: {
          'learning_rate':
              double.tryParse(_learningRate.text.trim()) ?? 0.0002,
          'batch_size': int.tryParse(_batchSize.text.trim()) ?? 4,
        },
      );

      if (!mounted) return;
      Navigator.pop(context, true);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = e.message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('New training job',
                  style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 4),
              Text(
                'The job waits in the queue until a GPU worker claims it. '
                'Training runs on Kaggle, not here.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 20),

              TextFormField(
                controller: _name,
                decoration: const InputDecoration(
                  labelText: 'Name',
                  hintText: 'Retrain on balanced t',
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Name is required' : null,
              ),
              const SizedBox(height: 16),

              DropdownButtonFormField<int>(
                initialValue: _datasetId,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Dataset'),
                items: [
                  for (final d in widget.datasets)
                    DropdownMenuItem(value: d.id, child: Text(d.name)),
                ],
                onChanged: (v) => setState(() => _datasetId = v ?? _datasetId),
              ),
              const SizedBox(height: 16),

              DropdownButtonFormField<int?>(
                initialValue: _baseModelId,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Start from (optional)',
                  helperText: 'Fine-tune an existing version, or train fresh',
                ),
                items: [
                  const DropdownMenuItem<int?>(
                    value: null,
                    child: Text('From scratch'),
                  ),
                  for (final m in _models)
                    DropdownMenuItem<int?>(value: m.id, child: Text(m.label)),
                ],
                onChanged: (v) => setState(() => _baseModelId = v),
              ),
              const SizedBox(height: 16),

              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _epochs,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Epochs'),
                      validator: (v) {
                        final n = int.tryParse(v?.trim() ?? '');
                        if (n == null || n < 1) return 'At least 1';
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _batchSize,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Batch size'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _learningRate,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(labelText: 'Learning rate'),
              ),

              if (_error != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.errorLight,
                    border: Border.all(color: AppTheme.error),
                  ),
                  child: Text(_error!,
                      style: Theme.of(context).textTheme.bodySmall),
                ),
              ],

              const SizedBox(height: 20),
              Row(
                children: [
                  TextButton(
                    onPressed: _busy ? null : () => Navigator.pop(context),
                    child: const Text('CANCEL'),
                  ),
                  const Spacer(),
                  ElevatedButton(
                    onPressed: _busy ? null : _submit,
                    child: _busy
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text('QUEUE JOB'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RegisterModelForm extends StatefulWidget {
  final TrainingJob job;

  const _RegisterModelForm({required this.job});

  @override
  State<_RegisterModelForm> createState() => _RegisterModelFormState();
}

class _RegisterModelFormState extends State<_RegisterModelForm> {
  final TrainingService _service = TrainingService();
  final _formKey = GlobalKey<FormState>();

  final _name = TextEditingController(text: 'deepCT TC-D');
  final _version = TextEditingController();
  final _endpoint = TextEditingController();

  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _version.dispose();
    _endpoint.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      final message = await _service.registerModel(
        jobId: widget.job.id,
        name: _name.text.trim(),
        version: _version.text.trim(),
        endpointUrl: _endpoint.text.trim().isEmpty
            ? null
            : _endpoint.text.trim(),
      );

      if (!mounted) return;
      Navigator.pop(context, message);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = e.message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Register as a model',
                style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 8),
            Text(
              'This records the weights as a new version. It starts inactive '
              'and offline: weights are a file, and a model here is a running '
              'worker with a URL. Deploy them, set the endpoint, then activate '
              'it in Model Management.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 20),

            TextFormField(
              controller: _name,
              decoration: const InputDecoration(labelText: 'Model name'),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Name is required' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _version,
              decoration: const InputDecoration(
                labelText: 'Version',
                hintText: 'v2.0',
              ),
              validator: (v) => (v == null || v.trim().isEmpty)
                  ? 'Version is required'
                  : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _endpoint,
              decoration: const InputDecoration(
                labelText: 'Endpoint URL (optional)',
                hintText: 'Fill in once the weights are deployed',
              ),
            ),

            if (_error != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.errorLight,
                  border: Border.all(color: AppTheme.error),
                ),
                child: Text(_error!,
                    style: Theme.of(context).textTheme.bodySmall),
              ),
            ],

            const SizedBox(height: 20),
            Row(
              children: [
                TextButton(
                  onPressed: _busy ? null : () => Navigator.pop(context),
                  child: const Text('CANCEL'),
                ),
                const Spacer(),
                ElevatedButton(
                  onPressed: _busy ? null : _submit,
                  child: _busy
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('REGISTER'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}


/// Where a queued job is pushed to.
///
/// Empty means "use the server's configured trainer" — the common case once
/// `TRAINING_TRAINER_URL` is set, and the reason this is a text field rather
/// than a required one.
class _DispatchForm extends StatefulWidget {
  final TrainingJob job;

  const _DispatchForm({required this.job});

  @override
  State<_DispatchForm> createState() => _DispatchFormState();
}

class _DispatchFormState extends State<_DispatchForm> {
  late final TextEditingController _url = TextEditingController(
    text: widget.job.trainerUrl ?? '',
  );

  @override
  void dispose() {
    _url.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Send to trainer',
              style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 8),
          Text(
            'The platform posts this job to a URL on the GPU host, exactly the '
            'way a prediction is posted to a model endpoint. The notebook '
            'starts training and reports progress back here.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 20),

          TextFormField(
            controller: _url,
            decoration: const InputDecoration(
              labelText: 'Trainer URL',
              hintText: 'Leave empty to use the server default',
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'The job stays queued until the first heartbeat arrives. If the '
            'GPU session dies later, the job returns to the queue with its '
            'checkpoint and can be sent again.',
            style: Theme.of(context).textTheme.labelSmall,
          ),

          const SizedBox(height: 20),
          Row(
            children: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('CANCEL'),
              ),
              const Spacer(),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, _url.text.trim()),
                child: const Text('SEND'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
