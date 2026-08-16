/// Frames a model is trained on.
///
/// Either an archive hosted by the platform, or a URL the GPU worker fetches
/// for itself — a 20 GB dataset has no business travelling up a home tunnel
/// and back down to Kaggle.
class TrainingDataset {
  final int id;
  final String name;
  final String? description;

  /// `upload` or `url`.
  final String sourceType;
  final String? sourceUrl;

  final int? sizeBytes;
  final int? frameCount;
  final int jobsCount;
  final String? uploadedBy;
  final DateTime? createdAt;

  const TrainingDataset({
    required this.id,
    required this.name,
    this.description,
    required this.sourceType,
    this.sourceUrl,
    this.sizeBytes,
    this.frameCount,
    this.jobsCount = 0,
    this.uploadedBy,
    this.createdAt,
  });

  static int _int(dynamic v) => v is int
      ? v
      : (v is num ? v.toInt() : int.tryParse('${v ?? ''}') ?? 0);

  factory TrainingDataset.fromJson(Map<String, dynamic> json) {
    return TrainingDataset(
      id: _int(json['id']),
      name: json['name']?.toString() ?? '',
      description: json['description']?.toString(),
      sourceType: json['source_type']?.toString() ?? 'upload',
      sourceUrl: json['source_url']?.toString(),
      sizeBytes: json['size_bytes'] == null ? null : _int(json['size_bytes']),
      frameCount: json['frame_count'] == null
          ? null
          : _int(json['frame_count']),
      jobsCount: _int(json['jobs_count']),
      uploadedBy: json['uploaded_by']?.toString(),
      createdAt: json['created_at'] == null
          ? null
          : DateTime.tryParse(json['created_at'].toString()),
    );
  }

  bool get isHosted => sourceType == 'upload';

  String get sizeLabel {
    final bytes = sizeBytes;
    if (bytes == null) return '—';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(0)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }
}

/// One training run.
class TrainingJob {
  final int id;
  final String name;

  /// `queued`, `claimed`, `running`, `completed`, `failed`, `cancelled`.
  final String status;

  final int currentEpoch;
  final int totalEpochs;

  /// 0.0–1.0, or null when the job never said how long it would be.
  final double? progress;

  final Map<String, dynamic> metrics;
  final Map<String, dynamic> hyperparameters;

  /// Which GPU holds it, in the worker's own words.
  final String? workerLabel;

  /// The trainer this job was pushed to, if it was pushed rather than polled.
  final String? trainerUrl;
  final DateTime? dispatchedAt;

  final String? errorMessage;
  final bool hasWeights;
  final bool hasCheckpoint;

  final int? datasetId;
  final String? datasetName;
  final String? baseModelLabel;
  final int? resultingModelId;

  final DateTime? heartbeatAt;
  final DateTime? startedAt;
  final DateTime? finishedAt;
  final DateTime? createdAt;

  const TrainingJob({
    required this.id,
    required this.name,
    required this.status,
    required this.currentEpoch,
    required this.totalEpochs,
    this.progress,
    this.metrics = const {},
    this.hyperparameters = const {},
    this.workerLabel,
    this.trainerUrl,
    this.dispatchedAt,
    this.errorMessage,
    this.hasWeights = false,
    this.hasCheckpoint = false,
    this.datasetId,
    this.datasetName,
    this.baseModelLabel,
    this.resultingModelId,
    this.heartbeatAt,
    this.startedAt,
    this.finishedAt,
    this.createdAt,
  });

  static int _int(dynamic v) => v is int
      ? v
      : (v is num ? v.toInt() : int.tryParse('${v ?? ''}') ?? 0);

  static DateTime? _date(dynamic v) =>
      v == null ? null : DateTime.tryParse(v.toString());

  static Map<String, dynamic> _map(dynamic v) =>
      v is Map ? Map<String, dynamic>.from(v) : const {};

  factory TrainingJob.fromJson(Map<String, dynamic> json) {
    final dataset = json['dataset'];
    final base = json['base_model'];
    final rawProgress = json['progress'];

    return TrainingJob(
      id: _int(json['id']),
      name: json['name']?.toString() ?? '',
      status: json['status']?.toString() ?? 'queued',
      currentEpoch: _int(json['current_epoch']),
      totalEpochs: _int(json['total_epochs']),
      progress: rawProgress is num ? rawProgress.toDouble() : null,
      metrics: _map(json['metrics']),
      hyperparameters: _map(json['hyperparameters']),
      workerLabel: json['worker_label']?.toString(),
      trainerUrl: json['trainer_url']?.toString(),
      dispatchedAt: _date(json['dispatched_at']),
      errorMessage: json['error_message']?.toString(),
      hasWeights: json['has_weights'] == true,
      hasCheckpoint: json['has_checkpoint'] == true,
      datasetId: dataset is Map ? _int(dataset['id']) : null,
      datasetName: dataset is Map ? dataset['name']?.toString() : null,
      baseModelLabel: base is Map
          ? '${base['name']} ${base['version']}'.trim()
          : null,
      resultingModelId: json['resulting_model_id'] == null
          ? null
          : _int(json['resulting_model_id']),
      heartbeatAt: _date(json['heartbeat_at']),
      startedAt: _date(json['started_at']),
      finishedAt: _date(json['finished_at']),
      createdAt: _date(json['created_at']),
    );
  }

  bool get isQueued => status == 'queued';

  /// Sent to a trainer, but no worker has reported on it yet.
  ///
  /// Accepting is not starting: the trainer said it took the job, and only a
  /// heartbeat proves it began.
  bool get isAwaitingTrainer => isQueued && dispatchedAt != null;
  bool get isActive => status == 'claimed' || status == 'running';
  bool get isFinished =>
      status == 'completed' || status == 'failed' || status == 'cancelled';

  String get statusLabel => switch (status) {
    'queued' => 'QUEUED',
    'claimed' => 'CLAIMED',
    'running' => 'RUNNING',
    'completed' => 'COMPLETED',
    'failed' => 'FAILED',
    'cancelled' => 'CANCELLED',
    _ => status.toUpperCase(),
  };

  String get epochLabel =>
      totalEpochs > 0 ? 'epoch $currentEpoch / $totalEpochs' : 'epoch $currentEpoch';

  /// True when a worker holds the job but has not reported recently.
  ///
  /// Not an error: a Kaggle session ending is the normal course of events, and
  /// the platform will hand the job back to the queue with its checkpoint.
  bool get looksStalled {
    if (!isActive) return false;
    final beat = heartbeatAt;
    if (beat == null) return true;

    return DateTime.now().difference(beat.toLocal()).inMinutes >= 3;
  }
}
