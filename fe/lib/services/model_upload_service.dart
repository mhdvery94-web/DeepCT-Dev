import 'dart:math';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import '../utils/archive_source.dart';
import 'api_client.dart';

typedef ModelControl =
    Future<Map<String, dynamic>> Function(
      String path,
      String method,
      Map<String, dynamic>? data,
    );
typedef ModelDirect =
    Future<int> Function(
      Uri url,
      String capability,
      int offset,
      Uint8List bytes,
      CancelToken? cancellation,
    );

class _DigestSink implements Sink<Digest> {
  Digest? value;
  @override
  void add(Digest data) {
    value = data;
  }

  @override
  void close() {}
}

/// The authenticated ApiClient carries JSON only. Byte transport is a fresh Dio
/// with no login interceptor/cookies and refuses redirects of the capability.
class ModelUploadService {
  ModelUploadService({ModelControl? control, ModelDirect? direct})
    : control = control ?? _control,
      direct = direct ?? _direct;
  static const chunkBytes = 4 * 1024 * 1024;
  static const maxBytes = 10 * 1024 * 1024 * 1024;
  final ModelControl control;
  final ModelDirect direct;

  static Future<Map<String, dynamic>> _control(
    String path,
    String method,
    Map<String, dynamic>? data,
  ) async {
    final response = method == 'GET'
        ? await ApiClient.instance.get(path)
        : await ApiClient.instance.post(path, data: data);
    return Map<String, dynamic>.from(response['data'] as Map);
  }

  Future<List<Map<String, dynamic>>> list() async {
    final response = await ApiClient.instance.get('/admin/model-uploads');
    return (response['data'] as List)
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
  }

  static Future<int> _direct(
    Uri url,
    String capability,
    int offset,
    Uint8List bytes,
    CancelToken? cancellation,
  ) async {
    final client = Dio(
      BaseOptions(
        followRedirects: false,
        connectTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(seconds: 60),
        sendTimeout: const Duration(seconds: 60),
      ),
    );
    try {
      final response = await client.putUri<Map<String, dynamic>>(
        url,
        data: Stream.value(bytes),
        cancelToken: cancellation,
        options: Options(
          headers: {
            'Authorization': 'Bearer $capability',
            'Upload-Offset': '$offset',
            'Content-Type': 'application/octet-stream',
            'Content-Length': bytes.length,
          },
        ),
      );
      return response.data!['offset'] as int;
    } finally {
      client.close();
    }
  }

  void _checkCancel(CancelToken? cancellation) {
    if (cancellation?.isCancelled ?? false) {
      throw StateError('Upload dijeda; pilih ulang file untuk resume.');
    }
  }

  Future<String> hash(
    ArchiveSource source,
    void Function(int) progress, {
    CancelToken? cancellation,
  }) async {
    final name = source.filename.toLowerCase();
    if (!name.endsWith('.h5') && !name.endsWith('.keras')) {
      throw StateError('Pilih file .h5 / .keras.');
    }
    if (source.length < 8 || source.length > maxBytes) {
      throw StateError('Ukuran model maksimum 10 GiB.');
    }
    final signature = await source.read(0, 8);
    final expected = name.endsWith('.h5')
        ? [137, 72, 68, 70, 13, 10, 26, 10]
        : [80, 75, 3, 4];
    if (signature.length < expected.length ||
        !List.generate(
          expected.length,
          (i) => signature[i] == expected[i],
        ).every((v) => v)) {
      throw StateError('Format file tidak sesuai.');
    }
    final output = _DigestSink();
    final sink = sha256.startChunkedConversion(output);
    try {
      for (var offset = 0; offset < source.length; offset += chunkBytes) {
        _checkCancel(cancellation);
        final end = min(offset + chunkBytes, source.length);
        final bytes = await source.read(offset, end);
        if (bytes.length != end - offset) {
          throw StateError('File changed during reading.');
        }
        sink.add(bytes);
        progress((end * 100 / source.length).round());
      }
    } finally {
      sink.close();
    }
    return output.value.toString();
  }

  Uri _url(dynamic value) {
    final uri = Uri.parse(value as String);
    if (uri.scheme != 'https' ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        uri.hasFragment) {
      throw StateError('HTTPS upload URL required.');
    }
    return uri;
  }

  Future<Map<String, dynamic>> upload(
    ArchiveSource source,
    Map<String, dynamic> original,
    void Function(int) hashing,
    void Function(int) progress, {
    CancelToken? cancellation,
  }) async {
    _url(original['upload_url']);
    final digest = await hash(source, hashing, cancellation: cancellation);
    final manifest = original['manifest'] as Map;
    if (manifest['sha256'] != digest ||
        manifest['size_bytes'] != source.length ||
        !source.filename.toLowerCase().endsWith(
          (manifest['weight_file'] as String).substring(5),
        )) {
      throw StateError('File identity/digest differs.');
    }
    final path = '/admin/model-uploads/${original['id']}';
    Map<String, dynamic> checked(Map<String, dynamic> session) {
      final current = session['manifest'] as Map;
      if (session['id'] != original['id'] ||
          current['sha256'] != digest ||
          current['size_bytes'] != source.length ||
          current['weight_file'] != manifest['weight_file']) {
        throw StateError('Session identity changed.');
      }
      final offset = session['offset'];
      if (offset is! int || offset < 0 || offset > source.length) {
        throw StateError('Invalid server offset.');
      }
      if (!['uploading', 'uploaded'].contains(session['state'])) {
        throw StateError('Sesi tidak menerima byte.');
      }
      return session;
    }

    var session = checked(await control(path, 'GET', null));
    if ((session['offset'] as int) < source.length) {
      session = checked(await control('$path/renew', 'POST', {}));
    }
    var retries = 0;
    while ((session['offset'] as int) < source.length) {
      _checkCancel(cancellation);
      final offset = session['offset'] as int;
      if (offset < 0) throw StateError('Invalid server offset.');
      final end = min(offset + chunkBytes, source.length);
      final bytes = await source.read(offset, end);
      if (bytes.length != end - offset) {
        throw StateError('File changed during upload.');
      }
      try {
        final received = await direct(
          _url(session['upload_url']),
          session['token'] as String,
          offset,
          bytes,
          cancellation,
        );
        if (received != end) throw StateError('Invalid server offset.');
        session = {...session, 'offset': received};
        retries = 0;
      } catch (_) {
        _checkCancel(cancellation);
        if (++retries > 3) rethrow;
        session = checked(await control(path, 'GET', null));
        if ((session['offset'] as int) < source.length) {
          session = checked(await control('$path/renew', 'POST', {}));
        }
      }
      progress(((session['offset'] as int) * 100 / source.length).round());
    }
    return {...session, 'state': 'uploaded'};
  }
}
