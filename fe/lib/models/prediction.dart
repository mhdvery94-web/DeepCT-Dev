/// One interpolation job belonging to the signed-in researcher.
///
/// Mirrors the payloads of `GET /api/predictions` and
/// `GET /api/predictions/{id}`; the detail endpoint returns a few extra
/// fields, which stay null on list rows.
class Prediction {
  final int id;
  final String jobId;

  /// One of `pending`, `processing`, `completed`, `failed`.
  final String status;

  final String? fileName;
  final int inputFilesCount;
  final int outputFilesCount;

  /// Names of the frames the model generated, once completed.
  final List<String> interpolatedFrames;

  final String? modelName;
  final String? modelVersion;

  final String? errorMessage;
  final int? queuePosition;
  final int? estimatedWaitMinutes;

  final DateTime? createdAt;
  final DateTime? expiresAt;
  final DateTime? filesDeletedAt;

  /// Only present on the detail endpoint; null means "not reported".
  final bool? filesAvailable;

  const Prediction({
    required this.id,
    required this.jobId,
    required this.status,
    this.fileName,
    required this.inputFilesCount,
    required this.outputFilesCount,
    this.interpolatedFrames = const [],
    this.modelName,
    this.modelVersion,
    this.errorMessage,
    this.queuePosition,
    this.estimatedWaitMinutes,
    this.createdAt,
    this.expiresAt,
    this.filesDeletedAt,
    this.filesAvailable,
  });

  static int _toInt(dynamic v, [int fallback = 0]) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v) ?? fallback;
    return fallback;
  }

  static int? _toIntOrNull(dynamic v) => v == null ? null : _toInt(v);

  static DateTime? _toDate(dynamic v) =>
      v == null ? null : DateTime.tryParse(v.toString());

  factory Prediction.fromJson(Map<String, dynamic> json) {
    // The list endpoint nests the model as an object; the detail endpoint
    // does the same, but either can be absent when the model was deleted.
    final model = json['model'];

    // `interpolated_frames` is cast to array server-side, but tolerate the
    // raw JSON string an older record might still hold.
    final rawFrames = json['interpolated_frames'];
    final frames = rawFrames is List
        ? rawFrames.map((e) => e.toString()).toList()
        : const <String>[];

    return Prediction(
      id: _toInt(json['id']),
      jobId: json['job_id']?.toString() ?? '',
      status: json['status']?.toString() ?? 'pending',
      fileName: json['file_name']?.toString(),
      inputFilesCount: _toInt(json['input_files_count']),
      outputFilesCount: _toInt(json['output_files_count']),
      interpolatedFrames: frames,
      modelName: model is Map ? model['name']?.toString() : null,
      modelVersion: model is Map ? model['version']?.toString() : null,
      errorMessage: json['error_message']?.toString(),
      queuePosition: _toIntOrNull(json['queue_position']),
      estimatedWaitMinutes: _toIntOrNull(json['estimated_wait_minutes']),
      createdAt: _toDate(json['created_at']),
      expiresAt: _toDate(json['expires_at']),
      filesDeletedAt: _toDate(json['files_deleted_at']),
      filesAvailable: json['files_available'] is bool
          ? json['files_available'] as bool
          : null,
    );
  }

  bool get isPending => status == 'pending';
  bool get isProcessing => status == 'processing';
  bool get isCompleted => status == 'completed';
  bool get isFailed => status == 'failed';

  /// Still moving, so the UI should keep polling.
  bool get isActive => isPending || isProcessing;

  /// True when the results can still be downloaded.
  bool get canDownload =>
      isCompleted && filesDeletedAt == null && (filesAvailable ?? true);

  /// How long until the 24-hour retention window closes, or null once gone.
  Duration? get timeUntilExpiry {
    if (expiresAt == null || filesDeletedAt != null) return null;
    final remaining = expiresAt!.difference(DateTime.now());
    return remaining.isNegative ? Duration.zero : remaining;
  }

  /// e.g. "23h left", "45m left", "expired"
  String get expiryLabel {
    if (filesDeletedAt != null) return 'expired';
    final remaining = timeUntilExpiry;
    if (remaining == null) return '-';
    if (remaining == Duration.zero) return 'expiring now';
    if (remaining.inHours >= 1) return '${remaining.inHours}h left';
    return '${remaining.inMinutes}m left';
  }

  String get displayName => fileName ?? 'Job ${jobId.split('-').first}';

  String get modelLabel {
    if (modelName == null) return 'Unknown model';
    return modelVersion == null ? modelName! : '$modelName $modelVersion';
  }
}
