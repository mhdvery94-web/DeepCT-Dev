import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import '../config/api_config.dart';
import 'secure_store.dart';

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
          // Through SecureStore, never the plugin directly. A throw here fails
          // the request it is decorating, and this interceptor sits in front
          // of the public endpoints too — an unreadable keystore once emptied
          // the landing page's news carousel, which asks for no token at all.
          final token = await SecureStore.read(tokenKey);
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

  /// Multipart POST/PATCH with upload progress.
  ///
  /// Uploads get their own generous timeouts: the default 30s is fine for a
  /// JSON call but not for pushing megabytes over a tunnel.
  Future<Map<String, dynamic>> sendMultipart(
    String path, {
    required FormData data,
    String method = 'POST',
    ProgressCallback? onSendProgress,
    Duration sendTimeout = const Duration(minutes: 10),
    Duration receiveTimeout = const Duration(minutes: 5),
  }) async {
    return _send(
      () => _dio.request(
        path,
        data: data,
        onSendProgress: onSendProgress,
        options: Options(
          method: method,
          sendTimeout: sendTimeout,
          receiveTimeout: receiveTimeout,
          // FormData sets its own multipart boundary; leaving the JSON
          // content-type in place would make the server reject the body.
          contentType: 'multipart/form-data',
        ),
      ),
    );
  }

  /// Fetches a binary payload (a results ZIP) with download progress.
  ///
  /// Returns the bytes plus the response headers, so the caller can verify
  /// the `X-Checksum-MD5` the API sends alongside every download.
  Future<({Uint8List bytes, Headers headers})> getBytes(
    String path, {
    ProgressCallback? onReceiveProgress,
    Duration receiveTimeout = const Duration(minutes: 10),
  }) async {
    try {
      final response = await _dio.get<List<int>>(
        path,
        onReceiveProgress: onReceiveProgress,
        options: Options(
          responseType: ResponseType.bytes,
          receiveTimeout: receiveTimeout,
        ),
      );

      return (
        bytes: Uint8List.fromList(response.data ?? const []),
        headers: response.headers,
      );
    } on DioException catch (e) {
      throw _translateBinary(e);
    }
  }

  /// Keeps a large response as a stream so the caller can write and hash it
  /// without allocating the complete archive in the Dart heap.
  Future<({Stream<Uint8List> bytes, Headers headers})> getStream(
    String path, {
    Duration receiveTimeout = const Duration(minutes: 10),
  }) async {
    try {
      final response = await _dio.get<ResponseBody>(
        path,
        options: Options(
          responseType: ResponseType.stream,
          receiveTimeout: receiveTimeout,
        ),
      );

      return (bytes: response.data!.stream, headers: response.headers);
    } on DioException catch (e) {
      throw _translate(e);
    }
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

  /// A failed binary request still carries a JSON error body, but Dio hands it
  /// back as raw bytes because we asked for [ResponseType.bytes]. Decode it so
  /// the user sees the server's message instead of "Request failed".
  ApiException _translateBinary(DioException error) {
    final data = error.response?.data;

    if (data is List<int>) {
      try {
        final decoded = jsonDecode(utf8.decode(data));
        if (decoded is Map && decoded['message'] != null) {
          return ApiException(
            decoded['message'].toString(),
            statusCode: error.response?.statusCode,
          );
        }
      } catch (_) {
        // Not JSON after all; fall through to the generic translation.
      }
    }

    return _translate(error);
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
      // Name the address. This one message covers a backend that is down, a
      // closed tunnel, and a build pointing at a hostname that does not
      // resolve — and only the first is about the backend. Saying "make sure
      // the backend is running" and nothing else once sent someone checking a
      // server that was answering fine, while the app was asking a subdomain
      // that had never been created.
      return ApiException(
        'Cannot reach the server at ${ApiConfig.baseUrl} — check that this '
        'address is correct and that the backend is running.',
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
          .firstWhere(
            (l) => l.isNotEmpty,
            orElse: () => const ['Validation failed'],
          )
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
