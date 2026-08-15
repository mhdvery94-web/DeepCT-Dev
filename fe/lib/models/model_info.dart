/// A deep learning model registered in the platform.
///
/// Models are deployed remotely (Kaggle / Google Colab) and reached through
/// [endpointUrl]; there is no local weights file, so [filePath] is optional.
class ModelInfo {
  final int id;
  final String name;
  final String version;
  final String? endpointUrl;
  final String? description;
  final String? filePath;

  /// One of `online`, `offline`, `trouble`.
  final String status;
  final bool isActive;
  final DateTime? lastHealthCheck;
  final String? healthCheckError;
  final int maxConcurrentJobs;
  final int currentJobsCount;
  final int totalPredictions;
  final double? accuracy;
  final DateTime? deployedAt;
  final DateTime? createdAt;

  const ModelInfo({
    required this.id,
    required this.name,
    required this.version,
    this.endpointUrl,
    this.description,
    this.filePath,
    required this.status,
    required this.isActive,
    this.lastHealthCheck,
    this.healthCheckError,
    required this.maxConcurrentJobs,
    required this.currentJobsCount,
    required this.totalPredictions,
    this.accuracy,
    this.deployedAt,
    this.createdAt,
  });

  static bool _toBool(dynamic v) => v == 1 || v == true || v == '1';

  static int _toInt(dynamic v, [int fallback = 0]) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v) ?? fallback;
    return fallback;
  }

  static double? _toDouble(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    // MySQL DECIMAL is serialised as a string by PDO.
    if (v is String) return double.tryParse(v);
    return null;
  }

  static DateTime? _toDate(dynamic v) {
    if (v == null) return null;
    return DateTime.tryParse(v.toString());
  }

  factory ModelInfo.fromJson(Map<String, dynamic> json) {
    return ModelInfo(
      id: _toInt(json['id']),
      name: json['name']?.toString() ?? '-',
      version: json['version']?.toString() ?? '-',
      endpointUrl: json['endpoint_url']?.toString(),
      description: json['description']?.toString(),
      filePath: json['file_path']?.toString(),
      status: json['status']?.toString() ?? 'offline',
      isActive: _toBool(json['is_active']),
      lastHealthCheck: _toDate(json['last_health_check']),
      healthCheckError: json['health_check_error']?.toString(),
      maxConcurrentJobs: _toInt(json['max_concurrent_jobs'], 1),
      currentJobsCount: _toInt(json['current_jobs_count']),
      totalPredictions: _toInt(json['total_predictions']),
      accuracy: _toDouble(json['accuracy']),
      deployedAt: _toDate(json['deployed_at']),
      createdAt: _toDate(json['created_at']),
    );
  }

  bool get isOnline => status == 'online';
  bool get isTrouble => status == 'trouble';
  bool get isOffline => status == 'offline';

  /// True when the model is busy at its configured concurrency limit.
  bool get isAtCapacity => currentJobsCount >= maxConcurrentJobs;

  String get displayName => '$name $version';
}
