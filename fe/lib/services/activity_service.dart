import '../config/api_config.dart';
import '../models/activity_log.dart';
import '../models/pagination.dart';
import 'api_client.dart';

/// Wraps the 3 admin activity-log endpoints.
class ActivityService {
  final ApiClient _api = ApiClient.instance;

  /// GET /admin/activities
  ///
  /// [dateFrom] / [dateTo] are inclusive and must be `yyyy-MM-dd`.
  Future<PaginatedResult<ActivityLog>> list({
    int page = 1,
    int perPage = 20,
    int? userId,
    String? type,
    String? dateFrom,
    String? dateTo,
  }) async {
    final body = await _api.get(
      ApiConfig.adminActivities,
      query: {
        'page': page,
        'per_page': perPage,
        'user_id': userId,
        'type': type,
        'date_from': dateFrom,
        'date_to': dateTo,
      },
    );

    return _parse(body);
  }

  /// GET /admin/users/{id}/activities
  Future<PaginatedResult<ActivityLog>> forUser(
    int userId, {
    int page = 1,
    int perPage = 20,
    String? type,
  }) async {
    final body = await _api.get(
      '${ApiConfig.adminUsers}/$userId/activities',
      query: {'page': page, 'per_page': perPage, 'type': type},
    );

    return _parse(body);
  }

  /// GET /admin/activities/types — only types already present in the table.
  Future<List<String>> types() async {
    final body = await _api.get('${ApiConfig.adminActivities}/types');
    return (body['data'] as List? ?? []).map((e) => e.toString()).toList();
  }

  PaginatedResult<ActivityLog> _parse(Map<String, dynamic> body) {
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
