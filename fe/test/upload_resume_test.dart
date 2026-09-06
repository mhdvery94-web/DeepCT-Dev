import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

import 'dart:typed_data';

import 'package:crypto/crypto.dart';

import 'package:fe/services/upload_resume_store.dart';
import 'package:fe/utils/archive_source.dart';

PendingUpload _pending({
  String digest = 'abc123',
  int size = 4194304,
  DateTime? savedAt,
}) => PendingUpload(
  uploadId: 'ecda037c-1111-2222-3333-444455556666',
  filename: 'frames.zip',
  totalSize: size,
  digest: digest,
  modelId: 1,
  savedAt: savedAt ?? DateTime.now(),
);

PendingUpload _trainingPending() => PendingUpload(
  uploadId: '9f0e1d2c-5555-6666-7777-888899990000',
  filename: 'dataset.zip',
  totalSize: 8388608,
  digest: 'cafebabe',
  savedAt: DateTime.now(),
  purpose: UploadPurpose.training,
  name: 'Balanced-t retrain',
  totalEpochs: 40,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PendingUpload', () {
    test('matches the same file', () {
      expect(
        _pending().matches(size: 4194304, digest: 'abc123'),
        isTrue,
      );
    });

    test('rejects a file of the same size but different content', () {
      // The size check alone would pass here, and splicing this into a
      // half-written session produces a corrupt ZIP that only fails much
      // later, inside the queue worker.
      expect(
        _pending().matches(size: 4194304, digest: 'deadbeef'),
        isFalse,
      );
    });

    test('rejects a file of a different size', () {
      expect(
        _pending().matches(size: 999, digest: 'abc123'),
        isFalse,
      );
    });

    test('a record older than a day is stale', () {
      // The server sweeps abandoned sessions after 24 hours, so an older
      // record points at nothing.
      final old = _pending(
        savedAt: DateTime.now().subtract(const Duration(hours: 25)),
      );

      expect(old.isStale, isTrue);
      expect(_pending().isStale, isFalse);
    });

    test('survives a JSON round trip', () {
      final original = _pending();
      final restored = PendingUpload.fromJson(original.toJson());

      expect(restored, isNotNull);
      expect(restored!.uploadId, original.uploadId);
      expect(restored.filename, original.filename);
      expect(restored.totalSize, original.totalSize);
      expect(restored.digest, original.digest);
      expect(restored.modelId, original.modelId);
    });

    test('a payload without an upload id is not a record', () {
      expect(PendingUpload.fromJson(const {'filename': 'frames.zip'}), isNull);
    });
  });

  group('UploadResumeStore', () {
    setUp(() => FlutterSecureStorage.setMockInitialValues({}));

    test('reads back what it saved', () async {
      final store = UploadResumeStore();
      await store.save(_pending());

      final restored = await store.read();

      expect(restored, isNotNull);
      expect(restored!.filename, 'frames.zip');
      expect(restored.digest, 'abc123');
    });

    test('reports nothing when there is nothing', () async {
      expect(await UploadResumeStore().read(), isNull);
    });

    test('clear removes the record', () async {
      final store = UploadResumeStore();
      await store.save(_pending());
      await store.clear();

      expect(await store.read(), isNull);
    });

    test('drops a stale record instead of offering it', () async {
      final store = UploadResumeStore();
      await store.save(
        _pending(savedAt: DateTime.now().subtract(const Duration(days: 2))),
      );

      expect(await store.read(), isNull);
    });

    test('drops a corrupt record rather than throwing', () async {
      // A record worth less than the code to repair it.
      FlutterSecureStorage.setMockInitialValues({
        'pending_upload': 'not json at all',
      });

      expect(await UploadResumeStore().read(), isNull);
    });
  });
  group('a training session is remembered separately', () {
    setUp(() => FlutterSecureStorage.setMockInitialValues({}));

    /// Two purposes, two slots.
    ///
    /// A researcher can have a prediction half-uploaded and then start a
    /// training run; one slot would silently drop whichever came first, and
    /// the abandoned session would sit on the server until its sweep — with
    /// nothing on the device left to resume it from.
    test('a training record does not evict a prediction one', () async {
      final store = UploadResumeStore();

      await store.save(_pending());
      await store.save(_trainingPending());

      final prediction = await store.read();
      final training = await store.read(purpose: UploadPurpose.training);

      expect(prediction?.filename, 'frames.zip');
      expect(training?.filename, 'dataset.zip');
      expect(training?.name, 'Balanced-t retrain');
      expect(training?.totalEpochs, 40);
    });

    test('clearing one leaves the other', () async {
      final store = UploadResumeStore();

      await store.save(_pending());
      await store.save(_trainingPending());
      await store.clear(purpose: UploadPurpose.training);

      expect(await store.read(), isNotNull);
      expect(await store.read(purpose: UploadPurpose.training), isNull);
    });

    test('the training fields survive a JSON round trip', () {
      final restored = PendingUpload.fromJson(_trainingPending().toJson());

      expect(restored!.purpose, UploadPurpose.training);
      expect(restored.name, 'Balanced-t retrain');
      expect(restored.totalEpochs, 40);
    });

    /// An older record has no `purpose` at all. It must still read back as a
    /// prediction rather than as nothing, or the first launch after an update
    /// throws away an upload that was still resumable.
    test('a record written before purposes existed is a prediction', () {
      final restored = PendingUpload.fromJson({
        'upload_id': 'ecda037c-1111-2222-3333-444455556666',
        'filename': 'frames.zip',
        'total_size': 4194304,
        'digest': 'abc123',
        'model_id': 1,
        'saved_at': DateTime.now().toIso8601String(),
      });

      expect(restored!.purpose, UploadPurpose.prediction);
    });
  });

  group('digestOf', () {
    /// The digest is what proves a resumed upload is the same archive, and it
    /// used to be `md5.convert(bytes)` — which needs the whole archive in
    /// memory, the exact cost [ArchiveSource] exists to avoid. Walking the
    /// source must produce the same answer.
    test('streaming a source matches hashing the bytes whole', () async {
      final bytes = Uint8List.fromList(
        List.generate(300000, (i) => (i * 31) % 251),
      );

      final streamed = await digestOf(
        BytesArchiveSource(bytes, filename: 'set.zip'),
      );

      expect(streamed, md5.convert(bytes).toString());
    });

    test('an empty source still has a digest', () async {
      final streamed = await digestOf(
        BytesArchiveSource(Uint8List(0), filename: 'set.zip'),
      );

      expect(streamed, md5.convert(const []).toString());
    });
  });
}
