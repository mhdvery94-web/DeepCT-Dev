import 'dart:convert';

import 'package:crypto/crypto.dart';

import '../utils/archive_source.dart';
import 'secure_store.dart';

/// What an unfinished upload was going to become.
///
/// Two slots rather than one, because a researcher can leave a prediction
/// half-uploaded and then start a training run. Sharing a slot would drop
/// whichever came first without saying so, and the abandoned session would sit
/// on the server until its sweep with nothing on the device to resume it from.
enum UploadPurpose {
  prediction('pending_upload'),
  training('pending_training_upload');

  const UploadPurpose(this.storageKey);

  /// Where a record of this purpose is kept. `prediction` keeps the original
  /// key so an upload interrupted before this change is still resumable.
  final String storageKey;

  static UploadPurpose fromName(String? name) => values.firstWhere(
    (p) => p.name == name,
    // A record written before purposes existed has no field to read, and it
    // was a prediction — every one of them was.
    orElse: () => UploadPurpose.prediction,
  );
}

/// MD5 of an archive, read a chunk at a time.
///
/// `md5.convert(bytes)` needs the whole archive resident, which is precisely
/// the cost [ArchiveSource] exists to avoid — hashing it that way would undo
/// the streaming upload on the very step that guards it.
Future<String> digestOf(ArchiveSource source) async {
  // `ChunkedConversionSink.withCallback` from `dart:convert` rather than
  // `AccumulatorSink` from `package:convert`, which is not a dependency here
  // and would be one more package for one line.
  Digest? digest;
  final input = md5.startChunkedConversion(
    ChunkedConversionSink<Digest>.withCallback((all) => digest = all.single),
  );

  const block = 1 << 20;
  for (var at = 0; at < source.length; at += block) {
    input.add(await source.read(at, at + block));
  }

  input.close();

  return digest.toString();
}

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

  /// Which model the prediction was for. Zero on a training record — there is
  /// no model yet; producing one is the point of the run.
  final int modelId;

  final DateTime savedAt;

  final UploadPurpose purpose;

  /// The run's name and length, carried so a resumed training upload finishes
  /// as the run the researcher described rather than as an untitled one.
  /// Null on a prediction record.
  final String? name;
  final int? totalEpochs;

  const PendingUpload({
    required this.uploadId,
    required this.filename,
    required this.totalSize,
    required this.digest,
    required this.savedAt,
    this.modelId = 0,
    this.purpose = UploadPurpose.prediction,
    this.name,
    this.totalEpochs,
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
    'purpose': purpose.name,
    'name': name,
    'total_epochs': totalEpochs,
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
      purpose: UploadPurpose.fromName(json['purpose']?.toString()),
      name: json['name']?.toString(),
      totalEpochs: (json['total_epochs'] as num?)?.toInt(),
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
  Future<PendingUpload?> read({
    UploadPurpose purpose = UploadPurpose.prediction,
  }) async {
    try {
      final raw = await SecureStore.read(purpose.storageKey);
      if (raw == null) return null;

      final decoded = jsonDecode(raw);
      if (decoded is! Map) return null;

      final pending = PendingUpload.fromJson(
        Map<String, dynamic>.from(decoded),
      );

      if (pending == null || pending.isStale) {
        await clear(purpose: purpose);
        return null;
      }

      return pending;
    } catch (_) {
      // A corrupt record is worth less than the code to repair it.
      await clear(purpose: purpose);
      return null;
    }
  }

  Future<void> save(PendingUpload pending) =>
      SecureStore.write(pending.purpose.storageKey, jsonEncode(pending.toJson()));

  Future<void> clear({UploadPurpose purpose = UploadPurpose.prediction}) =>
      SecureStore.delete(purpose.storageKey);
}
