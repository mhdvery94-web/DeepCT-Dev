import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';

import '../config/api_config.dart';
import '../models/pagination.dart';
import '../models/prediction.dart';
import '../models/prediction_frame.dart';
import 'api_client.dart';

/// Result of a completed download, already verified against the checksum the
/// server sent.
class DownloadedArchive {
  final String filename;
  final Uint8List bytes;

  /// Null when the server did not send `X-Checksum-MD5`.
  final bool? checksumVerified;

  const DownloadedArchive({
    required this.filename,
    required this.bytes,
    this.checksumVerified,
  });
}

/// Wraps the FASE 3 prediction endpoints.
///
/// Uploads go through whichever path fits: a single request for small
/// archives, and the resumable chunked flow for anything larger. PHP caps a
/// single request at `upload_max_filesize` (2 MB on the current dev machine),
/// and one 1024x1024 16-bit TIFF frame is already ~2 MB, so in practice the
/// chunked path is the normal one.
class PredictionService {
  final ApiClient _api = ApiClient.instance;

  /// Anything at or above this goes through the chunked flow. Deliberately
  /// small: it must stay under the server's `upload_max_filesize`.
  static const int directUploadLimit = 1024 * 1024; // 1 MB

  /// GET /predictions
  Future<PaginatedResult<Prediction>> list({
    int page = 1,
    int perPage = 15,
    String? status,
  }) async {
    final body = await _api.get(
      ApiConfig.predictions,
      query: {'page': page, 'per_page': perPage, 'status': status},
    );

    final items = (body['data'] as List? ?? [])
        .map((e) => Prediction.fromJson(Map<String, dynamic>.from(e as Map)))
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

  /// GET /predictions/{id}
  Future<Prediction> show(int id) async {
    final body = await _api.get('${ApiConfig.predictions}/$id');
    return Prediction.fromJson(Map<String, dynamic>.from(body['data'] as Map));
  }

  /// DELETE /predictions/{id}
  Future<void> delete(int id) async {
    await _api.delete('${ApiConfig.predictions}/$id');
  }

  /// GET /predictions/{id}/frames — what is on disk, inputs and outputs.
  Future<List<PredictionFrame>> frames(int id) async {
    final body = await _api.get('${ApiConfig.predictions}/$id/frames');

    return (body['data'] as List? ?? [])
        .map(
          (e) => PredictionFrame.fromJson(Map<String, dynamic>.from(e as Map)),
        )
        .toList();
  }

  /// GET /predictions/{id}/frames/{name}/preview — the frame as a PNG.
  ///
  /// The frames themselves are 16-bit TIFFs, which neither a browser nor
  /// Flutter can decode, so the server renders them. Bytes are fetched through
  /// the authenticated client rather than handed to `Image.network`, which has
  /// no way to carry the bearer token.
  Future<Uint8List> framePreview({
    required int id,
    required String name,
    int size = 512,
  }) async {
    final result = await _api.getBytes(
      '${ApiConfig.predictions}/$id/frames/${Uri.encodeComponent(name)}/preview'
      '?size=$size',
    );

    return result.bytes;
  }

  /// Uploads [bytes] and queues a prediction, picking the transport that fits.
  ///
  /// [onProgress] reports 0.0-1.0 across the whole upload, whichever path is
  /// taken, so the UI does not need to know which one ran.
  Future<Prediction> upload({
    required Uint8List bytes,
    required String filename,
    required int modelId,
    void Function(double progress)? onProgress,
  }) async {
    if (bytes.length < directUploadLimit) {
      return _uploadDirect(
        bytes: bytes,
        filename: filename,
        modelId: modelId,
        onProgress: onProgress,
      );
    }

    return _uploadChunked(
      bytes: bytes,
      filename: filename,
      modelId: modelId,
      onProgress: onProgress,
    );
  }

  Future<Prediction> _uploadDirect({
    required Uint8List bytes,
    required String filename,
    required int modelId,
    void Function(double progress)? onProgress,
  }) async {
    final form = FormData.fromMap({
      'model_id': modelId,
      'file': MultipartFile.fromBytes(bytes, filename: filename),
    });

    final body = await _api.sendMultipart(
      ApiConfig.predictions,
      data: form,
      onSendProgress: (sent, total) {
        if (total > 0) onProgress?.call(sent / total);
      },
    );

    return Prediction.fromJson(Map<String, dynamic>.from(body['data'] as Map));
  }

  /// Start → repeated chunk → finalize.
  ///
  /// Chunks must arrive in order; the server rejects a gap with 409 rather
  /// than silently assembling a corrupt archive.
  Future<Prediction> _uploadChunked({
    required Uint8List bytes,
    required String filename,
    required int modelId,
    void Function(double progress)? onProgress,
  }) async {
    final start = await _api.post(
      ApiConfig.predictionUploads,
      data: {
        'model_id': modelId,
        'total_size': bytes.length,
        'filename': filename,
      },
    );

    final session = Map<String, dynamic>.from(start['data'] as Map);
    final uploadId = session['upload_id'].toString();
    final chunkSize = (session['chunk_size'] as num).toInt();

    try {
      var offset = 0;

      while (offset < bytes.length) {
        final end = (offset + chunkSize).clamp(0, bytes.length);
        final slice = Uint8List.sublistView(bytes, offset, end);

        await _api.sendMultipart(
          '${ApiConfig.predictionUploads}/$uploadId',
          method: 'PATCH',
          data: FormData.fromMap({
            'offset': offset,
            'chunk': MultipartFile.fromBytes(slice, filename: 'chunk'),
          }),
          onSendProgress: (sent, total) {
            if (total <= 0) return;
            // Blend this chunk's progress into the overall figure.
            final done = offset + (sent / total) * slice.length;
            onProgress?.call((done / bytes.length).clamp(0.0, 1.0));
          },
        );

        offset = end;
        onProgress?.call(offset / bytes.length);
      }

      final body = await _api.post(
        '${ApiConfig.predictionUploads}/$uploadId/finalize',
      );

      return Prediction.fromJson(
        Map<String, dynamic>.from(body['data'] as Map),
      );
    } on ApiException {
      // Do not leave a half-written archive on the server.
      try {
        await _api.delete('${ApiConfig.predictionUploads}/$uploadId');
      } on ApiException {
        // Best effort; the hourly cleanup sweeps abandoned sessions anyway.
      }
      rethrow;
    }
  }

  /// Downloads a results archive and verifies it against `X-Checksum-MD5`.
  ///
  /// [type] is `results` (generated frames only) or `complete` (inputs,
  /// outputs and metadata.json).
  Future<DownloadedArchive> download({
    required int id,
    required String jobId,
    String type = 'results',
    void Function(double progress)? onProgress,
  }) async {
    final result = await _api.getBytes(
      '${ApiConfig.predictions}/$id/download/$type',
      onReceiveProgress: (received, total) {
        if (total > 0) onProgress?.call(received / total);
      },
    );

    final expected = result.headers.value('x-checksum-md5');
    bool? verified;

    if (expected != null && expected.isNotEmpty) {
      verified = md5.convert(result.bytes).toString() == expected.toLowerCase();
    }

    final shortJob = jobId.split('-').first;

    return DownloadedArchive(
      filename: '${type}_$shortJob.zip',
      bytes: result.bytes,
      checksumVerified: verified,
    );
  }
}
