import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/model_info.dart';
import '../../models/pagination.dart';
import '../../services/admin_model_service.dart';
import '../../services/api_client.dart';
import '../../theme/app_theme.dart';
import '../../widgets/async_state_views.dart';
import '../../widgets/pagination_bar.dart';
import '../../widgets/status_badge.dart';

/// Admin screen for managing remotely deployed inference models.
///
/// Models run on Kaggle / Google Colab and are registered here by their
/// endpoint URL; the platform tracks their health rather than their weights.
class ModelManagementScreen extends StatefulWidget {
  const ModelManagementScreen({super.key});

  @override
  State<ModelManagementScreen> createState() => _ModelManagementScreenState();
}

class _ModelManagementScreenState extends State<ModelManagementScreen> {
  final AdminModelService _service = AdminModelService();

  List<ModelInfo> _models = [];
  Pagination _pagination = const Pagination.empty();

  bool _isLoading = true;
  String? _error;
  int _page = 1;
  String? _statusFilter;

  /// IDs currently running a health check, so we can show a per-card spinner.
  final Set<int> _checking = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final result = await _service.list(page: _page, status: _statusFilter);
      if (!mounted) return;
      setState(() {
        _models = result.items;
        _pagination = result.pagination;
        _isLoading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _isLoading = false;
      });
    }
  }

  void _showMessage(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? AppTheme.error : AppTheme.success,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // ---------------------------------------------------------------- actions

  Future<void> _openModelDialog({ModelInfo? existing}) async {
    final saved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _ModelFormDialog(service: _service, existing: existing),
    );

    if (saved == true) {
      if (existing == null) _page = 1;
      _load();
    }
  }

  Future<void> _healthCheck(ModelInfo model) async {
    setState(() => _checking.add(model.id));

    try {
      final result = await _service.healthCheck(model.id);
      if (!mounted) return;

      final rt = result.responseTimeMs;
      _showMessage(
        'Health check: ${result.status.toUpperCase()}'
        '${rt != null ? ' (${rt.toStringAsFixed(0)} ms)' : ''}'
        '${result.error != null ? ' - ${result.error}' : ''}',
        isError: result.status != 'online',
      );

      await _load();
    } on ApiException catch (e) {
      _showMessage(e.message, isError: true);
    } finally {
      if (mounted) setState(() => _checking.remove(model.id));
    }
  }

  Future<void> _testPrediction(ModelInfo model) async {
    setState(() => _checking.add(model.id));

    try {
      final result = await _service.testPrediction(model.id);
      if (!mounted) return;

      if (result.success) {
        _showMessage(
          'Test prediction succeeded'
          '${result.responseTimeMs != null ? ' in ${result.responseTimeMs!.toStringAsFixed(0)} ms' : ''}',
        );
      } else {
        _showMessage(result.error ?? 'Test prediction failed', isError: true);
      }
    } finally {
      if (mounted) setState(() => _checking.remove(model.id));
    }
  }

  Future<void> _toggle(ModelInfo model) async {
    try {
      final isActive = await _service.toggleStatus(model.id);
      _showMessage(
        isActive
            ? '${model.name} is now active'
            : '${model.name} is now inactive',
      );
      _load();
    } on ApiException catch (e) {
      _showMessage(e.message, isError: true);
    }
  }

  Future<void> _delete(ModelInfo model) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
        title: const Text('Delete model'),
        content: Text(
          'Permanently delete "${model.displayName}"? '
          'This does not affect the remote deployment.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('CANCEL'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.error),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('DELETE'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await _service.delete(model.id);
      _showMessage('${model.name} deleted');
      if (_models.length == 1 && _page > 1) _page--;
      _load();
    } on ApiException catch (e) {
      _showMessage(e.message, isError: true);
    }
  }

  // ------------------------------------------------------------------- view

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildToolbar(),
          const SizedBox(height: 16),
          Expanded(child: _buildContent()),
          PaginationBar(
            pagination: _pagination,
            onPageChanged: (p) {
              _page = p;
              _load();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildToolbar() {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Container(
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            border: Border.all(color: AppTheme.textMuted),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String?>(
              value: _statusFilter,
              hint: const Text('All statuses', style: TextStyle(fontSize: 14)),
              borderRadius: BorderRadius.zero,
              items: const [
                DropdownMenuItem(value: null, child: Text('All statuses')),
                DropdownMenuItem(value: 'online', child: Text('Online')),
                DropdownMenuItem(value: 'trouble', child: Text('Trouble')),
                DropdownMenuItem(value: 'offline', child: Text('Offline')),
              ],
              onChanged: (v) {
                setState(() {
                  _statusFilter = v;
                  _page = 1;
                });
                _load();
              },
            ),
          ),
        ),
        OutlinedButton.icon(
          onPressed: _isLoading ? null : _load,
          icon: const Icon(Icons.refresh, size: 16),
          label: const Text('REFRESH'),
        ),
        ElevatedButton.icon(
          onPressed: () => _openModelDialog(),
          icon: const Icon(Icons.add, size: 16),
          label: const Text('ADD MODEL'),
        ),
      ],
    );
  }

  Widget _buildContent() {
    if (_isLoading) return const LoadingView(message: 'Loading models...');
    if (_error != null) return ErrorView(message: _error!, onRetry: _load);
    if (_models.isEmpty) {
      return const EmptyView(
        message: 'No models registered yet. Add your deployment endpoint.',
        icon: Icons.memory_outlined,
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        // Responsive card grid: 1 column on narrow screens, up to 3 on wide.
        final columns = constraints.maxWidth > 1250
            ? 3
            : constraints.maxWidth > 780
                ? 2
                : 1;

        return GridView.builder(
          padding: EdgeInsets.zero,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            mainAxisExtent: 340,
          ),
          itemCount: _models.length,
          itemBuilder: (context, index) {
            final model = _models[index];
            return _ModelCard(
              model: model,
              isBusy: _checking.contains(model.id),
              onHealthCheck: () => _healthCheck(model),
              onTestPrediction: () => _testPrediction(model),
              onToggle: () => _toggle(model),
              onEdit: () => _openModelDialog(existing: model),
              onDelete: () => _delete(model),
            );
          },
        );
      },
    );
  }
}

class _ModelCard extends StatelessWidget {
  final ModelInfo model;
  final bool isBusy;
  final VoidCallback onHealthCheck;
  final VoidCallback onTestPrediction;
  final VoidCallback onToggle;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _ModelCard({
    required this.model,
    required this.isBusy,
    required this.onHealthCheck,
    required this.onTestPrediction,
    required this.onToggle,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd MMM, HH:mm');

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface,
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: AppTheme.border)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        model.name,
                        style: Theme.of(context).textTheme.headlineSmall,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Version ${model.version}',
                        style: Theme.of(context).textTheme.labelSmall,
                      ),
                    ],
                  ),
                ),
                StatusBadge.modelStatus(model.status),
              ],
            ),
          ),

          // Body
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      StatusBadge.active(model.isActive),
                      const SizedBox(width: 8),
                      if (model.accuracy != null)
                        Text(
                          '${model.accuracy!.toStringAsFixed(2)}% acc',
                          style: Theme.of(context).textTheme.labelSmall,
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _kv(context, 'Endpoint', model.endpointUrl ?? 'Not set'),
                  _kv(
                    context,
                    'Jobs',
                    '${model.currentJobsCount} / ${model.maxConcurrentJobs}',
                  ),
                  _kv(context, 'Predictions', '${model.totalPredictions}'),
                  _kv(
                    context,
                    'Last check',
                    model.lastHealthCheck != null
                        ? dateFormat.format(model.lastHealthCheck!.toLocal())
                        : 'Never',
                  ),
                  if (model.healthCheckError != null &&
                      model.healthCheckError!.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(8),
                      color: AppTheme.errorLight,
                      child: Text(
                        model.healthCheckError!,
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppTheme.error,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),

          // Actions
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: AppTheme.border)),
            ),
            child: Row(
              children: [
                if (isBusy)
                  const Padding(
                    padding: EdgeInsets.all(12),
                    child: SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                else ...[
                  IconButton(
                    tooltip: 'Health check',
                    icon: const Icon(Icons.monitor_heart_outlined, size: 18),
                    onPressed: onHealthCheck,
                  ),
                  IconButton(
                    tooltip: model.isOnline
                        ? 'Run test prediction'
                        : 'Model must be online to test',
                    icon: const Icon(Icons.science_outlined, size: 18),
                    onPressed: model.isOnline && model.isActive
                        ? onTestPrediction
                        : null,
                  ),
                ],
                const Spacer(),
                IconButton(
                  tooltip: model.isActive ? 'Deactivate' : 'Activate',
                  icon: Icon(
                    model.isActive ? Icons.toggle_on : Icons.toggle_off_outlined,
                    size: 22,
                    color:
                        model.isActive ? AppTheme.success : AppTheme.textMuted,
                  ),
                  onPressed: onToggle,
                ),
                IconButton(
                  tooltip: 'Edit',
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  onPressed: onEdit,
                ),
                IconButton(
                  tooltip: 'Delete',
                  icon: const Icon(
                    Icons.delete_outline,
                    size: 18,
                    color: AppTheme.error,
                  ),
                  onPressed: onDelete,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _kv(BuildContext context, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 84,
            child: Text(
              label,
              style: Theme.of(context).textTheme.labelSmall,
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 12),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

/// Create / edit dialog for a model deployment.
class _ModelFormDialog extends StatefulWidget {
  final AdminModelService service;
  final ModelInfo? existing;

  const _ModelFormDialog({required this.service, this.existing});

  @override
  State<_ModelFormDialog> createState() => _ModelFormDialogState();
}

class _ModelFormDialogState extends State<_ModelFormDialog> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _name;
  late final TextEditingController _version;
  late final TextEditingController _endpoint;
  late final TextEditingController _description;
  late final TextEditingController _maxJobs;

  bool _isSaving = false;
  String? _error;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final m = widget.existing;
    _name = TextEditingController(text: m?.name ?? '');
    _version = TextEditingController(text: m?.version ?? '');
    _endpoint = TextEditingController(text: m?.endpointUrl ?? '');
    _description = TextEditingController(text: m?.description ?? '');
    _maxJobs = TextEditingController(text: '${m?.maxConcurrentJobs ?? 1}');
  }

  @override
  void dispose() {
    _name.dispose();
    _version.dispose();
    _endpoint.dispose();
    _description.dispose();
    _maxJobs.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSaving = true;
      _error = null;
    });

    try {
      if (_isEdit) {
        await widget.service.update(
          id: widget.existing!.id,
          name: _name.text.trim(),
          version: _version.text.trim(),
          endpointUrl: _endpoint.text.trim(),
          description: _description.text.trim(),
          maxConcurrentJobs: int.tryParse(_maxJobs.text.trim()) ?? 1,
        );
      } else {
        await widget.service.create(
          name: _name.text.trim(),
          version: _version.text.trim(),
          endpointUrl: _endpoint.text.trim(),
          description: _description.text.trim(),
          maxConcurrentJobs: int.tryParse(_maxJobs.text.trim()) ?? 1,
        );
      }

      if (!mounted) return;
      Navigator.pop(context, true);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _isSaving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      title: Text(_isEdit ? 'Edit model' : 'Add model'),
      content: SizedBox(
        width: 460,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_error != null) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.errorLight,
                      border: Border.all(color: AppTheme.error),
                    ),
                    child: Text(
                      _error!,
                      style: const TextStyle(
                        color: AppTheme.error,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                TextFormField(
                  controller: _name,
                  decoration: const InputDecoration(labelText: 'MODEL NAME'),
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Model name is required'
                      : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _version,
                  decoration: const InputDecoration(
                    labelText: 'VERSION',
                    hintText: 'e.g. v3.0',
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Version is required'
                      : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _endpoint,
                  decoration: const InputDecoration(
                    labelText: 'ENDPOINT URL',
                    helperText: 'Kaggle / Colab inference URL, e.g. .../predict',
                  ),
                  validator: (v) {
                    final value = v?.trim() ?? '';
                    if (value.isEmpty) return 'Endpoint URL is required';
                    final uri = Uri.tryParse(value);
                    if (uri == null || !uri.hasScheme || !uri.hasAuthority) {
                      return 'Enter a full URL including https://';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _maxJobs,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'MAX CONCURRENT JOBS',
                  ),
                  validator: (v) {
                    final n = int.tryParse(v?.trim() ?? '');
                    if (n == null || n < 1 || n > 10) {
                      return 'Enter a number between 1 and 10';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _description,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'DESCRIPTION (OPTIONAL)',
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.pop(context, false),
          child: const Text('CANCEL'),
        ),
        ElevatedButton(
          onPressed: _isSaving ? null : _submit,
          child: _isSaving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : Text(_isEdit ? 'SAVE' : 'CREATE'),
        ),
      ],
    );
  }
}
