import '../config/api_config.dart';
import 'api_client.dart';

/// Public, administrator-reviewed password reset request.
///
/// Matching an email and phone number only locates the account. The backend
/// does not change credentials until an administrator verifies the request.
class PasswordResetRequestService {
  final ApiClient _api = ApiClient.instance;

  Future<String> submit({required String email, required String phone}) async {
    final body = await _api.post(
      ApiConfig.passwordResetRequests,
      data: {'email': email.trim(), 'phone': phone.trim()},
    );
    return body['message']?.toString() ??
        'Your reset request is awaiting administrator verification.';
  }
}
