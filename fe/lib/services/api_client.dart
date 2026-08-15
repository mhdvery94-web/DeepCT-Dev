import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../config/api_config.dart';

/// Thrown when the API returns a non-2xx response or the request fails.
/// Carries a message already suitable for display in the UI.
class ApiException implements Exception {
  final String message;
  final int? statusCode;

  /// Field-level validation errors from a 422 response.
  final Map<String, List<String>> fieldErrors;

  const ApiException(
    this.message, {
    this.statusCode,
    this.fieldErrors = const {},
  });

  bool get isValidation => statusCode == 422;
  bool get isForbidden => statusCode == 403;
  bool get isUnauthorized => statusCode == 401;
  bool get isRateLimited => statusCode == 429;

  @override
  String toString() => message;
}

/// Shared, authenticated Dio client for every admin API service.
///
/// Centralises base URL, the bearer-token interceptor and error translation so
/// the individual services only deal with parsed payloads.
class ApiClient {
  ApiClient._internal() {
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await _storage.read(key: tokenKey);
          if (token != null) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          return handler.next(options);
        },
      ),
    );
  }

  /// Single shared instance so the interceptor is only registered once.
  static final ApiClient instance = ApiClient._internal();

  static const String tokenKey = 'auth_token';

  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  final Dio _dio = Dio(
    BaseOptions(
      baseUrl: ApiConfig.baseUrl,
      connectTimeout: const Duration(milliseconds: ApiConfig.connectTimeout),
      receiveTimeout: const Duration(milliseconds: ApiConfig.receiveTimeout),
      headers: {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        // The backend is reached through an ngrok tunnel. Without this header
        // ngrok serves its HTML interstitial to anything that looks like a
        // browser, which would break every request from Flutter web.
        'ngrok-skip-browser-warning': 'true',
      },
    ),
  );

  Future<Map<String, dynamic>> get(
    String path, {
    Map<String, dynamic>? query,
  }) async {
    return _send(() => _dio.get(path, queryParameters: _clean(query)));
  }

  /// [receiveTimeout] overrides the default for slow endpoints, such as a test
  /// prediction that waits on a remote GPU.
  Future<Map<String, dynamic>> post(
    String path, {
    Map<String, dynamic>? data,
    Duration? receiveTimeout,
  }) async {
    return _send(
      () => _dio.post(
        path,
        data: data,
        options: receiveTimeout != null
            ? Options(receiveTimeout: receiveTimeout)
            : null,
      ),
    );
  }

  Future<Map<String, dynamic>> put(
    String path, {
    Map<String, dynamic>? data,
  }) async {
    return _send(() => _dio.put(path, data: data));
  }

  Future<Map<String, dynamic>> patch(
    String path, {
    Map<String, dynamic>? data,
  }) async {
    return _send(() => _dio.patch(path, data: data));
  }

  Future<Map<String, dynamic>> delete(String path) async {
    return _send(() => _dio.delete(path));
  }

  /// Drops null/empty query values so we never send `?role=` and accidentally
  /// trigger a server-side filter.
  Map<String, dynamic>? _clean(Map<String, dynamic>? query) {
    if (query == null) return null;
    final cleaned = <String, dynamic>{};
    query.forEach((key, value) {
      if (value == null) return;
      if (value is String && value.trim().isEmpty) return;
      cleaned[key] = value;
    });
    return cleaned.isEmpty ? null : cleaned;
  }

  Future<Map<String, dynamic>> _send(
    Future<Response<dynamic>> Function() request,
  ) async {
    try {
      final response = await request();
      final data = response.data;

      if (data is Map) {
        return Map<String, dynamic>.from(data);
      }
      // 204 No Content and similar.
      return <String, dynamic>{'success': true};
    } on DioException catch (e) {
      throw _translate(e);
    }
  }

  ApiException _translate(DioException error) {
    if (error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.receiveTimeout ||
        error.type == DioExceptionType.sendTimeout) {
      return const ApiException(
        'Connection timeout. Please check your connection and try again.',
      );
    }

    if (error.type == DioExceptionType.connectionError) {
      return const ApiException(
        'Cannot reach the server. Make sure the backend is running.',
      );
    }

    final status = error.response?.statusCode;
    final data = error.response?.data;

    // Laravel validation payload: { errors: { field: [msg, ...] } }
    if (status == 422 && data is Map && data['errors'] is Map) {
      final raw = Map<String, dynamic>.from(data['errors'] as Map);
      final fieldErrors = <String, List<String>>{};
      raw.forEach((key, value) {
        if (value is List) {
          fieldErrors[key] = value.map((e) => e.toString()).toList();
        } else if (value != null) {
          fieldErrors[key] = [value.toString()];
        }
      });

      final first = fieldErrors.values
          .firstWhere((l) => l.isNotEmpty, orElse: () => const ['Validation failed'])
          .first;

      return ApiException(first, statusCode: 422, fieldErrors: fieldErrors);
    }

    if (status == 401) {
      return const ApiException(
        'Your session has expired. Please sign in again.',
        statusCode: 401,
      );
    }

    if (status == 429) {
      return const ApiException(
        'Too many attempts. Please wait a moment and try again.',
        statusCode: 429,
      );
    }

    // 403 and most others carry a useful server message.
    if (data is Map && data['message'] != null) {
      return ApiException(data['message'].toString(), statusCode: status);
    }

    if (status == 500) {
      return const ApiException(
        'Server error. Please try again later.',
        statusCode: 500,
      );
    }

    return ApiException(
      'Request failed${status != null ? ' (HTTP $status)' : ''}.',
      statusCode: status,
    );
  }
}
