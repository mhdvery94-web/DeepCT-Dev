import '../config/api_config.dart';
import '../models/access_request.dart';
import '../models/pagination.dart';
import 'api_client.dart';

/// Outcome of approving a request: the new account, plus the one-time password
/// the administrator has to pass on.
class ApprovedAccount {
  final String username;
  final String name;
  final String email;
  final String defaultPassword;

  const ApprovedAccount({
    required this.username,
    required this.name,
    required this.email,
    required this.defaultPassword,
  });
}

/// The "Join Research" queue.
///
/// [submit] is the only call here that works without a token — an applicant by
/// definition has no account yet.
class AccessRequestService {
  final ApiClient _api = ApiClient.instance;

  /// POST /access-requests — public. Rate limited to 5/minute per IP.
  ///
  /// Throws [ApiException] with a 409 for an email that already has an account
  /// or a request still awaiting review; both messages are written to be shown
  /// to the applicant directly.
  Future<void> submit({
    required String firstName,
    required String lastName,
    required String email,
    required String institution,
    String? reason,
  }) async {
    await _api.post(
      ApiConfig.accessRequests,
      data: {
        'first_name': firstName,
        'last_name': lastName,
        'email': email,
        'institution': institution,
        if (reason != null && reason.trim().isNotEmpty) 'reason': reason.trim(),
      },
    );
  }

  /// GET /admin/access-requests
  ///
  /// Returns the page plus how many are still pending, which the shell shows
  /// as a badge.
  Future<({PaginatedResult<AccessRequest> page, int pendingCount})> list({
    int page = 1,
    int perPage = 15,
    String? status,
    String? search,
  }) async {
    final body = await _api.get(
      ApiConfig.adminAccessRequests,
      query: {
        'page': page,
        'per_page': perPage,
        'status': status,
        'search': search,
      },
    );

    final items = (body['data'] as List? ?? [])
        .map((e) => AccessRequest.fromJson(Map<String, dynamic>.from(e as Map)))
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
      pendingCount: meta is Map
          ? (meta['pending_count'] as num?)?.toInt() ?? 0
          : 0,
    );
  }

  /// POST /admin/access-requests/{id}/approve — creates the account too.
  Future<ApprovedAccount> approve(int id, {String? note, String? role}) async {
    final body = await _api.post(
      '${ApiConfig.adminAccessRequests}/$id/approve',
      data: {
        if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
        'role': ?role,
      },
    );

    final data = Map<String, dynamic>.from(body['data'] as Map);
    final user = Map<String, dynamic>.from(data['user'] as Map);

    return ApprovedAccount(
      username: user['username']?.toString() ?? '',
      name: user['name']?.toString() ?? '',
      email: user['email']?.toString() ?? '',
      defaultPassword: data['default_password']?.toString() ?? '',
    );
  }

  /// POST /admin/access-requests/{id}/reject
  Future<void> reject(int id, {String? note}) async {
    await _api.post(
      '${ApiConfig.adminAccessRequests}/$id/reject',
      data: {if (note != null && note.trim().isNotEmpty) 'note': note.trim()},
    );
  }

  /// DELETE /admin/access-requests/{id}
  Future<void> delete(int id) async {
    await _api.delete('${ApiConfig.adminAccessRequests}/$id');
  }
}
