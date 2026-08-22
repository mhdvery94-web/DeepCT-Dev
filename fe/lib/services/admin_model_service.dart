import '../config/api_config.dart';
import '../models/model_info.dart';
import '../models/pagination.dart';
import 'api_client.dart';

/// Outcome of a manual health check.
class HealthCheckResult {
  final String status;
  final double? responseTimeMs;
  final DateTime? checkedAt;
  final String? error;

  const HealthCheckResult({
    required this.status,
    this.responseTimeMs,
    this.checkedAt,
    this.error,
  });

  factory HealthCheckResult.fromJson(Map<String, dynamic> json) {
    final rt = json['response_time_ms'];
    return HealthCheckResult(
      status: json['status']?.toString() ?? 'offline',
      responseTimeMs: rt is num
          ? rt.toDouble()
          : double.tryParse('${rt ?? ''}'),
      checkedAt: json['checked_at'] != null
          ? DateTime.tryParse(json['checked_at'].toString())
          : null,
      error: json['error']?.toString(),
    );
  }
}

/// Outcome of a sample prediction against a model endpoint.
class TestPredictionResult {
  final bool success;
  final double? responseTimeMs;
  final dynamic modelResponse;
  final String? error;

  const TestPredictionResult({
    required this.success,
    this.responseTimeMs,
    this.modelResponse,
    this.error,
  });
}

/// Wraps the 8 admin model-management endpoints.
class AdminModelService {
  final ApiClient _api = ApiClient.instance;

  /// GET /admin/models — [status] filters on `online`/`offline`/`trouble`.
  Future<PaginatedResult<ModelInfo>> list({
    int page = 1,
    int perPage = 15,
    String? status,
  }) async {
    final body = await _api.get(
      ApiConfig.adminModels,
      query: {'page': page, 'per_page': perPage, 'status': status},
    );

    final items = (body['data'] as List? ?? [])
        .map((e) => ModelInfo.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();

    return PaginatedResult(
      items: items,
      pagination: body['pagination'] != null
          ? Pagination.fromJson(
              Map<String, dynamic>.from(body['pagination'] as Map),
            )
          : const Pagination.empty(),
    );
  }

  /// POST /admin/models — the backend runs a health check straight after
  /// creating the record, so the returned model already has a live status.
  ///
  /// [kind] is `inference` for an endpoint that answers `POST /predict`, and
  /// `trainer` for one that answers `POST /train`. One registry serves both:
  /// a trainer is switched on and health-checked exactly like a model, and a
  /// second screen for it would have been the same screen twice.
  Future<ModelInfo> create({
    required String name,
    required String version,
    required String endpointUrl,
    String kind = 'inference',
    String? description,
  }) async {
    final body = await _api.post(
      ApiConfig.adminModels,
      data: {
        'name': name,
        'version': version,
        'kind': kind,
        'endpoint_url': endpointUrl,
        if (description != null && description.isNotEmpty)
          'description': description,
      },
    );

    return ModelInfo.fromJson(Map<String, dynamic>.from(body['data'] as Map));
  }

  /// GET /admin/models/{id}
  Future<ModelInfo> show(int id) async {
    final body = await _api.get('${ApiConfig.adminModels}/$id');
    return ModelInfo.fromJson(Map<String, dynamic>.from(body['data'] as Map));
  }

  /// PUT /admin/models/{id} — partial update; only send what changed.
  Future<ModelInfo> update({
    required int id,
    String? name,
    String? version,
    String? endpointUrl,
    String? description,
  }) async {
    // Build the payload explicitly so we only send fields the caller changed.
    final data = <String, dynamic>{};
    if (name != null) data['name'] = name;
    if (version != null) data['version'] = version;
    if (endpointUrl != null) data['endpoint_url'] = endpointUrl;
    if (description != null) data['description'] = description;

    final body = await _api.put('${ApiConfig.adminModels}/$id', data: data);

    return ModelInfo.fromJson(Map<String, dynamic>.from(body['data'] as Map));
  }

  /// DELETE /admin/models/{id} — 403 if the model still has running jobs.
  Future<void> delete(int id) async {
    await _api.delete('${ApiConfig.adminModels}/$id');
  }

  /// PATCH /admin/models/{id}/toggle
  ///
  /// This endpoint returns only `{id, is_active}`, so we surface the flag
  /// rather than pretending to rebuild a full [ModelInfo].
  Future<bool> toggleStatus(int id) async {
    final body = await _api.patch('${ApiConfig.adminModels}/$id/toggle');
    final data = Map<String, dynamic>.from(body['data'] as Map);
    final v = data['is_active'];
    return v == 1 || v == true || v == '1';
  }

  /// POST /admin/models/{id}/health-check
  ///
  /// The backend probe itself allows up to 15s, so keep a little headroom.
  Future<HealthCheckResult> healthCheck(int id) async {
    final body = await _api.post(
      '${ApiConfig.adminModels}/$id/health-check',
      receiveTimeout: const Duration(seconds: 45),
    );
    return HealthCheckResult.fromJson(
      Map<String, dynamic>.from(body['data'] as Map),
    );
  }

  /// POST /admin/models/{id}/test
  ///
  /// Returns a failed result instead of throwing when the model itself errors,
  /// so the UI can show the endpoint's message inline.
  ///
  /// A real run waits on a remote GPU (measured ~18s on Kaggle), well beyond
  /// the default 30s receive timeout once queueing is involved, so this call
  /// gets a much longer budget.
  Future<TestPredictionResult> testPrediction(int id) async {
    try {
      final body = await _api.post(
        '${ApiConfig.adminModels}/$id/test',
        receiveTimeout: const Duration(minutes: 3),
      );
      final data = Map<String, dynamic>.from(body['data'] as Map);
      final rt = data['response_time_ms'];

      return TestPredictionResult(
        success: true,
        responseTimeMs: rt is num
            ? rt.toDouble()
            : double.tryParse('${rt ?? ''}'),
        modelResponse: data['model_response'],
      );
    } on ApiException catch (e) {
      return TestPredictionResult(success: false, error: e.message);
    }
  }
}
