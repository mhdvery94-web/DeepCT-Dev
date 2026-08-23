import 'package:flutter/foundation.dart';
import '../models/user_model.dart';
import 'auth_service.dart';

/// What to tell someone when signing in threw rather than answered.
///
/// A TypeError here means the server sent a shape this build cannot read,
/// which is what an app older than the API looks like from the inside: the
/// login itself succeeded and parsing the reply is what fell over.
///
/// It used to say only "An unexpected error occurred". That sentence sent
/// someone through the backend, the tunnel and the database looking for a
/// fault that was not there, when the answer was to install a newer build.
String loginFailureMessage(Object error) {
  if (error is TypeError) {
    return 'This version of the app cannot read what the server sent. '
        'Please install the latest build.';
  }

  return 'An unexpected error occurred';
}

class AuthProvider with ChangeNotifier {
  final AuthService _authService = AuthService();

  UserModel? _user;
  bool _isLoading = false;
  String? _errorMessage;

  UserModel? get user => _user;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isLoggedIn => _user != null;
  bool get isAdmin => _user?.isAdmin ?? false;
  bool get isUser => _user?.isUser ?? false;

  /// Login
  Future<bool> login(String email, String password) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final result = await _authService.login(email, password);

      if (result['success'] == true) {
        _user = result['user'];
        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        _errorMessage = result['message'];
        _isLoading = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      _errorMessage = loginFailureMessage(e);
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Logout
  Future<void> logout() async {
    await _authService.logout();
    _user = null;
    _errorMessage = null;
    notifyListeners();
  }

  /// Check auth status on app start
  Future<void> checkAuthStatus() async {
    final isLoggedIn = await _authService.isLoggedIn();

    if (isLoggedIn) {
      final user = await _authService.getCurrentUser();
      if (user != null) {
        _user = user;
        notifyListeners();
      } else {
        // Token invalid, logout
        await logout();
      }
    }
  }

  /// Record a new profile photo (or its removal) without refetching `/user`.
  ///
  /// The sidebar watches this provider, so the new picture appears the moment
  /// the upload returns.
  void setAvatarPath(String? path) {
    final current = _user;
    if (current == null) return;

    _user = current.withAvatarPath(path);
    notifyListeners();
  }

  /// Record that the account is off its default password.
  ///
  /// Called by the gate after `/me/password` succeeds, rather than refetching
  /// `/user`: the answer is already known and the console should appear at
  /// once.
  void clearMustChangePassword() {
    final current = _user;
    if (current == null) return;

    _user = current.withPasswordChanged();
    notifyListeners();
  }

  /// Clear error message
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}
