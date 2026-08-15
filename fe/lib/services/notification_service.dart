import '../config/api_config.dart';
import '../models/app_notification.dart';
import '../models/pagination.dart';
import 'api_client.dart';

/// The bell.
class NotificationService {
  final ApiClient _api = ApiClient.instance;

  /// GET /notifications
  Future<({PaginatedResult<AppNotification> page, int unread})> list({
    int page = 1,
    bool unreadOnly = false,
  }) async {
    final body = await _api.get(
      ApiConfig.notifications,
      query: {'page': page, if (unreadOnly) 'unread': 1},
    );

    final items = (body['data'] as List? ?? [])
        .map((e) => AppNotification.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();

    final meta = body['meta'];

    return (
      page: PaginatedResult(
        items: items,
        pagination: body['pagination'] != null
            ? Pagination.fromJson(
                Map<String, dynamic>.from(body['pagination'] as Map),
              )
            : const Pagination.empty(),
      ),
      unread: meta is Map ? (meta['unread'] as num?)?.toInt() ?? 0 : 0,
    );
  }

  /// GET /notifications/unread-count — what the bell polls.
  ///
  /// Carries the unread message count as well, so the bell and the Messages
  /// badge cost one request between them rather than one each.
  Future<({int notifications, int messages})> unreadCounts() async {
    final body = await _api.get('${ApiConfig.notifications}/unread-count');
    final data = body['data'];

    int read(String key) =>
        data is Map ? (data[key] as num?)?.toInt() ?? 0 : 0;

    return (notifications: read('notifications'), messages: read('messages'));
  }

  /// POST /notifications/{id}/read
  Future<void> markRead(String id) async {
    await _api.post('${ApiConfig.notifications}/$id/read');
  }

  /// POST /notifications/read-all
  Future<void> markAllRead() async {
    await _api.post('${ApiConfig.notifications}/read-all');
  }

  /// DELETE /notifications/{id}
  Future<void> dismiss(String id) async {
    await _api.delete('${ApiConfig.notifications}/$id');
  }

  /// DELETE /notifications
  Future<void> clear() async {
    await _api.delete(ApiConfig.notifications);
  }
}
