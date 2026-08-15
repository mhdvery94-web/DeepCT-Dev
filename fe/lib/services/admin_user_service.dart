import '../config/api_config.dart';
import '../models/pagination.dart';
import '../models/user_model.dart';
import 'api_client.dart';

/// Wraps the 7 admin user-management endpoints.
class AdminUserService {
  final ApiClient _api = ApiClient.instance;

  /// GET /admin/users
  ///
  /// [status] is `active` or `inactive`; [role] is `admin` or `user`.
  Future<PaginatedResult<UserModel>> list({
    int page = 1,
    int perPage = 15,
    String? search,
    String? role,
    String? status,
  }) async {
    final body = await _api.get(
      ApiConfig.adminUsers,
      query: {
        'page': page,
        'per_page': perPage,
        'search': search,
        'role': role,
        'status': status,
      },
    );

    final items = (body['data'] as List? ?? [])
        .map((e) => UserModel.fromJson(Map<String, dynamic>.from(e as Map)))
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

  /// POST /admin/users
  ///
  /// Omitting [password] makes the backend assign the shared default
  /// (`BrinResearch2026`), which it returns as `default_password`.
  Future<({UserModel user, String? defaultPassword})> create({
    required String name,
    required String username,
    required String email,
    required String role,
    String? password,
  }) async {
    final body = await _api.post(
      ApiConfig.adminUsers,
      data: {
        'name': name,
        'username': username,
        'email': email,
        'role': role,
        if (password != null && password.isNotEmpty) 'password': password,
      },
    );

    return (
      user: UserModel.fromJson(Map<String, dynamic>.from(body['data'] as Map)),
      defaultPassword: body['default_password']?.toString(),
    );
  }

  /// GET /admin/users/{id}
  Future<UserModel> show(int id) async {
    final body = await _api.get('${ApiConfig.adminUsers}/$id');
    return UserModel.fromJson(Map<String, dynamic>.from(body['data'] as Map));
  }

  /// PUT /admin/users/{id} — only name, username, email and role are editable.
  Future<UserModel> update({
    required int id,
    required String name,
    required String username,
    required String email,
    required String role,
  }) async {
    final body = await _api.put(
      '${ApiConfig.adminUsers}/$id',
      data: {'name': name, 'username': username, 'email': email, 'role': role},
    );

    return UserModel.fromJson(Map<String, dynamic>.from(body['data'] as Map));
  }

  /// DELETE /admin/users/{id} — permanent. Server blocks self-deletion (403).
  Future<void> delete(int id) async {
    await _api.delete('${ApiConfig.adminUsers}/$id');
  }

  /// PATCH /admin/users/{id}/toggle — server blocks self-toggle (403).
  ///
  /// This endpoint returns only `{id, is_active}`, so we surface the resulting
  /// flag rather than attempting to parse a full [UserModel].
  Future<bool> toggleStatus(int id) async {
    final body = await _api.patch('${ApiConfig.adminUsers}/$id/toggle');
    final data = Map<String, dynamic>.from(body['data'] as Map);
    final v = data['is_active'];
    return v == 1 || v == true || v == '1';
  }

  /// POST /admin/users/{id}/reset-password — returns the new default password.
  Future<String> resetPassword(int id) async {
    final body = await _api.post('${ApiConfig.adminUsers}/$id/reset-password');
    return body['default_password']?.toString() ?? 'BrinResearch2026';
  }
}
