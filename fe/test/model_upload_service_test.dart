import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fe/services/model_upload_service.dart';
import 'package:fe/utils/archive_source.dart';

class RangedSource implements ArchiveSource {
  RangedSource(this.bytes);
  final Uint8List bytes;
  int maximumRead = 0;
  @override
  int get length => bytes.length;
  @override
  String get filename => 'weights.h5';
  @override
  Future<Uint8List> read(int start, int end) async {
    maximumRead = maximumRead > end - start ? maximumRead : end - start;
    return Uint8List.sublistView(bytes, start, end);
  }

  @override
  Future<void> close() async {}
}

void main() {
  test('native hash reads bounded ranges and verifies whole digest', () async {
    final bytes = Uint8List(4 * 1024 * 1024 + 33)
      ..setAll(0, [137, 72, 68, 70, 13, 10, 26, 10]);
    final source = RangedSource(bytes);
    final digest = await ModelUploadService().hash(source, (_) {});
    expect(digest, sha256.convert(bytes).toString());
    expect(source.maximumRead, lessThanOrEqualTo(4 * 1024 * 1024));
  });
  test(
    'direct upload resumes from reconciled offset and uses capability only',
    () async {
      final bytes = Uint8List(100)
        ..setAll(0, [137, 72, 68, 70, 13, 10, 26, 10]);
      final source = RangedSource(bytes);
      var offset = 40;
      final session = <String, dynamic>{
        'id': 2,
        'state': 'uploading',
        'upload_url': 'https://tuf.example/prefix/uploads/id',
        'token': 'upload-only',
        'manifest': {
          'sha256': sha256.convert(bytes).toString(),
          'size_bytes': 100,
          'weight_file': 'model.h5',
        },
      };
      final service = ModelUploadService(
        control: (path, method, data) async => {...session, 'offset': offset},
        direct: (url, token, at, chunk, cancellation) async {
          expect(url.toString(), session['upload_url']);
          expect(token, 'upload-only');
          expect(at, 40);
          expect(chunk.length, 60);
          offset = 100;
          throw StateError('response lost after commit');
        },
      );
      final result = await service.upload(source, session, (_) {}, (_) {});
      expect(result['offset'], 100);
      final changed = RangedSource(Uint8List.fromList(bytes)..[40] = 1);
      await expectLater(
        service.upload(changed, session, (_) {}, (_) {}),
        throwsStateError,
      );
    },
  );
  test('unsupported file rejected before control or byte transfer', () async {
    final source = BytesArchiveSource(
      Uint8List.fromList([1, 2, 3]),
      filename: 'evil.py',
    );
    await expectLater(
      ModelUploadService().hash(source, (_) {}),
      throwsStateError,
    );
  });
  test('out of range server offset cannot report upload complete', () async {
    final source = RangedSource(
      Uint8List(50)..setAll(0, [137, 72, 68, 70, 13, 10, 26, 10]),
    );
    final session = <String, dynamic>{
      'id': 1,
      'state': 'uploading',
      'offset': 51,
      'upload_url': 'https://tuf/uploads/id',
      'manifest': {
        'sha256': sha256.convert(source.bytes).toString(),
        'size_bytes': 50,
        'weight_file': 'model.h5',
      },
    };
    final service = ModelUploadService(control: (_, _, _) async => session);
    await expectLater(
      service.upload(source, session, (_) {}, (_) {}),
      throwsStateError,
    );
  });
}
