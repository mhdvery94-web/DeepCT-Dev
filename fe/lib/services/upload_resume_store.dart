import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// An upload that was started and never finished.
///
/// Only the *description* of the upload is kept, never its bytes: an archive
/// runs to tens of megabytes, and on web there is no path to re-read it from.
/// Resuming therefore asks the user for the same file again, and [digest]
/// proves it is the same one.
class PendingUpload {
  final String uploadId;
  final String filename;
  final int totalSize;

  /// MD5 of the whole archive, so a different file cannot be spliced into a
  /// half-written session — the result would be a corrupt ZIP that only fails
  /// much later, inside the queue worker.
  final String digest;

  final int modelId;
  final DateTime savedAt;

  const PendingUpload({
    required this.uploadId,
    required this.filename,
    required this.totalSize,
    required this.digest,
    required this.modelId,
    required this.savedAt,
  });

  /// The server sweeps abandoned sessions after a day, so an older record
  /// points at nothing and is dropped on read.
  bool get isStale => DateTime.now().difference(savedAt) > const Duration(hours: 24);

  Map<String, dynamic> toJson() => {
    'upload_id': uploadId,
    'filename': filename,
    'total_size': totalSize,
    'digest': digest,
    'model_id': modelId,
    'saved_at': savedAt.toIso8601String(),
  };

  static PendingUpload? fromJson(Map<String, dynamic> json) {
    final id = json['upload_id']?.toString();
    if (id == null || id.isEmpty) return null;

    return PendingUpload(
      uploadId: id,
      filename: json['filename']?.toString() ?? 'archive.zip',
      totalSize: (json['total_size'] as num?)?.toInt() ?? 0,
      digest: json['digest']?.toString() ?? '',
      modelId: (json['model_id'] as num?)?.toInt() ?? 0,
      savedAt:
          DateTime.tryParse(json['saved_at']?.toString() ?? '') ??
          DateTime.now(),
    );
  }

  /// Matches the file the user has just chosen.
  bool matches({required int size, required String digest}) =>
      size == totalSize && digest == this.digest;
}

/// Where the unfinished upload is remembered between app launches.
///
/// Secure storage rather than a preferences file only because it is already a
/// dependency — nothing here is secret. One slot: a second concurrent upload
/// from the same device is not a case worth carrying state for.
class UploadResumeStore {
  static const String _key = 'pending_upload';

  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  Future<PendingUpload?> read() async {
    try {
      final raw = await _storage.read(key: _key);
      if (raw == null) return null;

      final decoded = jsonDecode(raw);
      if (decoded is! Map) return null;

      final pending = PendingUpload.fromJson(
        Map<String, dynamic>.from(decoded),
      );

      if (pending == null || pending.isStale) {
        await clear();
        return null;
      }

      return pending;
    } catch (_) {
      // A corrupt record is worth less than the code to repair it.
      await clear();
      return null;
    }
  }

  Future<void> save(PendingUpload pending) =>
      _storage.write(key: _key, value: jsonEncode(pending.toJson()));

  Future<void> clear() => _storage.delete(key: _key);
}
