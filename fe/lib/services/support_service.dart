import '../config/api_config.dart';
import '../models/pagination.dart';
import '../models/support_ticket.dart';
import 'api_client.dart';

/// In-app IT support.
///
/// One service for both sides: [myTickets] and [adminTickets] hit different
/// endpoints, but [show] and [reply] are shared — the server decides what the
/// caller may see and stamps replies with the right side.
class SupportService {
  final ApiClient _api = ApiClient.instance;

  /// Categories the ticket form offers; must match `SupportTicket::CATEGORIES`.
  static const List<String> categories = [
    'upload',
    'prediction',
    'download',
    'account',
    'other',
  ];

  PaginatedResult<SupportTicket> _parse(Map<String, dynamic> body) {
    final items = (body['data'] as List? ?? [])
        .map((e) => SupportTicket.fromJson(Map<String, dynamic>.from(e as Map)))
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

  /// GET /support/tickets — the caller's own.
  Future<PaginatedResult<SupportTicket>> myTickets({
    int page = 1,
    String? status,
  }) async {
    final body = await _api.get(
      ApiConfig.supportTickets,
      query: {'page': page, 'status': status},
    );

    return _parse(body);
  }

  /// POST /support/tickets
  Future<SupportTicket> open({
    required String subject,
    required String message,
    String category = 'other',
    String priority = 'normal',
    int? analysisRecordId,
  }) async {
    final body = await _api.post(
      ApiConfig.supportTickets,
      data: {
        'subject': subject,
        'message': message,
        'category': category,
        'priority': priority,
        'analysis_record_id': ?analysisRecordId,
      },
    );

    return SupportTicket.fromJson(
      Map<String, dynamic>.from(body['data'] as Map),
    );
  }

  /// POST /support/tickets/public — from the sign-in page, no token needed.
  ///
  /// For people who cannot sign in, which is the usual reason to press "IT
  /// Support" there. The reply arrives by email, not in the app, because
  /// there is no account session to show it in.
  Future<String> openPublic({
    required String name,
    required String email,
    required String subject,
    required String message,
    String category = 'account',
  }) async {
    final body = await _api.post(
      '${ApiConfig.supportTickets}/public',
      data: {
        'name': name,
        'email': email,
        'subject': subject,
        'message': message,
        'category': category,
      },
    );

    return body['message']?.toString() ??
        'Ticket submitted. An administrator will reply by email.';
  }

  /// GET /support/tickets/{id} — includes the conversation.
  Future<SupportTicket> show(int id) async {
    final body = await _api.get('${ApiConfig.supportTickets}/$id');
    return SupportTicket.fromJson(
      Map<String, dynamic>.from(body['data'] as Map),
    );
  }

  /// POST /support/tickets/{id}/reply — works for either side.
  Future<SupportTicket> reply(int id, String body) async {
    final response = await _api.post(
      '${ApiConfig.supportTickets}/$id/reply',
      data: {'body': body},
    );

    return SupportTicket.fromJson(
      Map<String, dynamic>.from(response['data'] as Map),
    );
  }

  /// GET /admin/support/tickets — every ticket, plus counters for the badge.
  Future<({
    PaginatedResult<SupportTicket> page,
    int openCount,
    int awaitingCount,
  })> adminTickets({
    int page = 1,
    String? status,
    bool awaitingOnly = false,
    String? search,
  }) async {
    final body = await _api.get(
      ApiConfig.adminSupportTickets,
      query: {
        'page': page,
        'status': status,
        if (awaitingOnly) 'awaiting': 1,
        'search': search,
      },
    );

    final meta = body['meta'];
    int metaInt(String key) =>
        meta is Map ? (meta[key] as num?)?.toInt() ?? 0 : 0;

    return (
      page: _parse(body),
      openCount: metaInt('open_count'),
      awaitingCount: metaInt('awaiting_admin_count'),
    );
  }

  /// PATCH /admin/support/tickets/{id}
  Future<SupportTicket> updateStatus(
    int id, {
    String? status,
    String? priority,
  }) async {
    final body = await _api.patch(
      '${ApiConfig.adminSupportTickets}/$id',
      data: {'status': ?status, 'priority': ?priority},
    );

    return SupportTicket.fromJson(
      Map<String, dynamic>.from(body['data'] as Map),
    );
  }

  /// DELETE /admin/support/tickets/{id}
  Future<void> delete(int id) async {
    await _api.delete('${ApiConfig.adminSupportTickets}/$id');
  }
}
