import 'package:flutter/material.dart';

import '../models/training.dart';
import '../services/api_client.dart';
import '../services/training_service.dart';
import '../theme/app_theme.dart';

/// Turn a finished training run's weights into a model version.
///
/// Lifted out of the deleted admin Training tab. Registering weights *is*
/// creating a model version, so it belongs beside the models — and it was the
/// one thing that screen could do that nothing else could. Without it a
/// finished run has no way out of the training pipeline at all.
class RegisterModelForm extends StatefulWidget {
  final TrainingJob job;

  const RegisterModelForm({super.key, required this.job});

  @override
  State<RegisterModelForm> createState() => RegisterModelFormState();
}

class RegisterModelFormState extends State<RegisterModelForm> {
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
