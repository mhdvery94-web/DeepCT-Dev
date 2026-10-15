import 'api_client.dart';
import 'package:dio/dio.dart';

class AiService {
  final CancelToken _cancel = CancelToken();

  /// Both roles use the shared authenticated, owner-scoped Laravel routes.
  Future<Map<String, dynamic>> get(String path, {int page = 1}) async =>
      Map<String, dynamic>.from(
        (await ApiClient.instance.get(
              '/ai/$path',
              query: {'page': page},
              cancelToken: _cancel,
            ))['data']
            as Map,
      );

  /// Owner-scoped analyses, including retained metadata after file expiry.
  Future<Map<String, dynamic>> analyses({int page = 1}) =>
      ApiClient.instance.get(
        '/predictions',
        query: {'page': page, 'per_page': 20},
        cancelToken: _cancel,
      );

  Future<Map<String, dynamic>> post(
    String path,
    Map<String, dynamic> data,
  ) async => Map<String, dynamic>.from(
    (await ApiClient.instance.post(
          '/ai/$path',
          data: data,
          cancelToken: _cancel,
        ))['data']
        as Map,
  );

  void dispose() => _cancel.cancel('Assistant screen disposed');
}
