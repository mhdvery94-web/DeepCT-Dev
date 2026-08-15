import '../config/api_config.dart';
import '../models/activity_log.dart';
import '../models/me_stats.dart';
import '../models/pagination.dart';
import 'api_client.dart';

/// A model a researcher may submit work to, as returned by `/api/me/models`.
///
/// Deliberately thinner than [ModelInfo]: no endpoint URL, no job counters.
class AvailableModel {
  final int id;
  final String name;
  final String version;
  final String status;
  final String? description;
  final double? accuracy;
  final bool isAvailable;

  const AvailableModel({
    required this.id,
    required this.name,
    required this.version,
    required this.status,
    this.description,
    this.accuracy,
    required this.isAvailable,
  });

  factory AvailableModel.fromJson(Map<String, dynamic> json) {
    final acc = json['accuracy'];

    return AvailableModel(
      id: json['id'] is int
          ? json['id'] as int
          : int.tryParse('${json['id']}') ?? 0,
      name: json['name']?.toString() ?? '-',
      version: json['version']?.toString() ?? '',
      status: json['status']?.toString() ?? 'offline',
      description: json['description']?.toString(),
      // MySQL DECIMAL arrives as a string through PDO.
      accuracy: acc is num ? acc.toDouble() : double.tryParse('${acc ?? ''}'),
      isAvailable: json['is_available'] == true,
    );
  }

  String get label => version.isEmpty ? name : '$name $version';
}

/// Wraps the self-service endpoints under `/api/me`.
///
/// These are the only data endpoints an ordinary researcher can reach:
/// everything under `/api/admin` is gated behind the admin role. Each call is
/// scoped server-side to the authenticated user, so there is no user id to
/// pass in.
class MeService {
  final ApiClient _api = ApiClient.instance;

  /// GET /me/stats
  Future<MeStats> stats() async {
    final body = await _api.get(ApiConfig.meStats);
    return MeStats.fromJson(Map<String, dynamic>.from(body['data'] as Map));
  }

  /// GET /me/models — active models the researcher may submit work to.
  ///
  /// Returns the narrow view: no endpoint URLs, which stay admin-only.
  Future<List<AvailableModel>> models() async {
    final body = await _api.get(ApiConfig.meModels);

    return (body['data'] as List? ?? [])
        .map(
          (e) => AvailableModel.fromJson(Map<String, dynamic>.from(e as Map)),
        )
        .toList();
  }

  /// GET /me/activities — the caller's own audit trail, newest first.
  Future<PaginatedResult<ActivityLog>> activities({
    int page = 1,
    int perPage = 20,
    String? type,
  }) async {
    final body = await _api.get(
      ApiConfig.meActivities,
      query: {'page': page, 'per_page': perPage, 'type': type},
    );

    final items = (body['data'] as List? ?? [])
        .map((e) => ActivityLog.fromJson(Map<String, dynamic>.from(e as Map)))
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
}
