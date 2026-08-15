import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../config/api_config.dart';
import '../models/user_model.dart';

class AuthService {
  final Dio _dio = Dio(
    BaseOptions(
      baseUrl: ApiConfig.baseUrl,
      connectTimeout: const Duration(milliseconds: ApiConfig.connectTimeout),
      receiveTimeout: const Duration(milliseconds: ApiConfig.receiveTimeout),
      headers: {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        // Skip ngrok's HTML interstitial; see ApiClient for the full note.
        'ngrok-skip-browser-warning': 'true',
      },
    ),
  );

  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  // Storage keys
  static const String _tokenKey = 'auth_token';
  static const String _userKey = 'user_data';

  AuthService() {
    // Add interceptor untuk auto-add token ke requests
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await getToken();
          if (token != null) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          return handler.next(options);
        },
        onError: (error, handler) {
          if (error.response?.statusCode == 401) {
            // Unauthorized - clear token
            logout();
          }
          return handler.next(error);
        },
      ),
    );
  }

  /// Login user
  Future<Map<String, dynamic>> login(String email, String password) async {
    try {
      final response = await _dio.post(
        ApiConfig.login,
        data: {'email': email, 'password': password},
      );

      if (response.data['success'] == true) {
        final token = response.data['data']['token'];
        final userData = response.data['data']['user'];

        // Save token dan user data
        await _storage.write(key: _tokenKey, value: token);
        await _storage.write(key: _userKey, value: jsonEncode(userData));

        return {
          'success': true,
          'user': UserModel.fromJson(userData),
          'token': token,
        };
      } else {
        return {
          'success': false,
          'message': response.data['message'] ?? 'Login failed',
        };
      }
    } on DioException catch (e) {
      return {'success': false, 'message': _handleError(e)};
    }
  }

  /// Logout user
  Future<void> logout() async {
    try {
      final token = await getToken();
      if (token != null) {
        await _dio.post(ApiConfig.logout);
      }
    } catch (e) {
      // Ignore error, just clear local data
    } finally {
      await _storage.delete(key: _tokenKey);
      await _storage.delete(key: _userKey);
    }
  }

  /// Get current user from API
  Future<UserModel?> getCurrentUser() async {
    try {
      final response = await _dio.get(ApiConfig.user);

      if (response.data['success'] == true) {
        return UserModel.fromJson(response.data['data']);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Check if user is logged in
  Future<bool> isLoggedIn() async {
    final token = await getToken();
    return token != null;
  }

  /// Get stored token
  Future<String?> getToken() async {
    return await _storage.read(key: _tokenKey);
  }

  /// Handle Dio errors
  String _handleError(DioException error) {
    if (error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.receiveTimeout) {
      return 'Connection timeout. Please check your internet connection.';
    }

    if (error.type == DioExceptionType.connectionError) {
      return 'Cannot connect to server. Please check your internet connection.';
    }

    if (error.response != null) {
      final statusCode = error.response?.statusCode;
      final data = error.response?.data;

      if (statusCode == 401) {
        return 'Invalid credentials. Please check your email and password.';
      }

      if (statusCode == 403) {
        return 'Access denied. You don\'t have permission.';
      }

      if (statusCode == 422) {
        // Validation error
        if (data is Map && data['errors'] != null) {
          final errors = data['errors'] as Map;
          return errors.values.first.first.toString();
        }
        return data['message'] ?? 'Validation error';
      }

      if (statusCode == 500) {
        return 'Server error. Please try again later.';
      }

      return data['message'] ?? 'An error occurred';
    }

    return 'An unexpected error occurred';
  }
}
