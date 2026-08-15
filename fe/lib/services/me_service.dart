import '../config/api_config.dart';
import '../models/activity_log.dart';
import '../models/me_stats.dart';
import '../models/pagination.dart';
import 'api_client.dart';

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
