/// A deep learning model registered in the platform.
///
/// Models are deployed remotely (Kaggle / Google Colab). Several rows may
/// share [baseUrl] while each keeps its own [endpoint] prediction path.
class ModelInfo {
  final int id;
  final String name;
  final String version;
  final String? slug;
  final String? baseUrl;
  final String? endpoint;
  final String? fullEndpointUrl;
  final String? endpointUrl;
  final String? description;
  final String? filePath;
  final String? modelFile;
  final bool workerActive;
  final DateTime? syncedAt;

  /// One of `online`, `offline`, `trouble`.
  final String status;
  final bool isActive;
  final DateTime? lastHealthCheck;
  final String? healthCheckError;

  /// The same failure as [healthCheckError], as a code the client can branch
  /// on. The admin screen shows both: the sentence, and the checker's own
  /// words underneath it.
  final String? healthCheckReason;

  final int currentJobsCount;
  final int totalPredictions;
  final double? accuracy;
  final DateTime? deployedAt;
  final DateTime? createdAt;

  /// Whether a shared secret is registered for this worker.
  ///
  /// The secret itself is never returned by any endpoint — this is the whole
  /// of what the registry will say about it. Replacing it is the only way to
  /// change it, which is how a credential should behave.
  final bool hasAuthToken;

  /// Whether the worker's TLS certificate is checked.
  ///
  /// False on every worker registered before this existed, which is exactly
  /// what the platform did then: verification was hardcoded off for tunnel
  /// and Colab certificates.
  final bool verifyTls;

  const ModelInfo({
    required this.id,
    required this.name,
    required this.version,
    this.slug,
    this.baseUrl,
    this.endpoint,
    this.fullEndpointUrl,
    this.endpointUrl,
    this.description,
    this.filePath,
    this.modelFile,
    this.workerActive = false,
    this.syncedAt,
    required this.status,
    required this.isActive,
    this.lastHealthCheck,
    this.healthCheckError,
    this.healthCheckReason,
    required this.currentJobsCount,
    required this.totalPredictions,
    this.accuracy,
    this.deployedAt,
    this.createdAt,
    this.hasAuthToken = false,
    this.verifyTls = false,
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
      slug: json['slug']?.toString(),
      baseUrl: json['base_url']?.toString(),
      endpoint: json['endpoint']?.toString(),
      fullEndpointUrl: json['full_endpoint_url']?.toString(),
      endpointUrl:
          json['full_endpoint_url']?.toString() ??
          json['endpoint_url']?.toString(),
      description: json['description']?.toString(),
      filePath: json['file_path']?.toString(),
      modelFile: json['model_file']?.toString(),
      workerActive: _toBool(json['worker_active']),
      syncedAt: _toDate(json['synced_at']),
      status: json['status']?.toString() ?? 'offline',
      isActive: _toBool(json['is_active']),
      lastHealthCheck: _toDate(json['last_health_check']),
      healthCheckError: json['health_check_error']?.toString(),
      healthCheckReason: json['health_check_reason']?.toString(),
      currentJobsCount: _toInt(json['current_jobs_count']),
      totalPredictions: _toInt(json['total_predictions']),
      accuracy: _toDouble(json['accuracy']),
      deployedAt: _toDate(json['deployed_at']),
      createdAt: _toDate(json['created_at']),
      hasAuthToken: _toBool(json['has_auth_token']),
      verifyTls: _toBool(json['verify_tls']),
    );
  }

  bool get isOnline => status == 'online';
  bool get isTrouble => status == 'trouble';
  bool get isOffline => status == 'offline';

  String get displayName => '$name $version';
}
