import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:fe/utils/archive_source.dart';
import 'package:fe/utils/file_archive.dart';

/// Where the bytes of an upload come from.
///
/// `training_screen.dart` asked the picker for `withData: true`, which loads
/// the whole archive into the Dart heap, and then the chunk loop sliced a
/// `Uint8List` that was already there in one piece. Chunking saved the
/// *transport* and nothing else: a phone or a browser tab dies long before
/// the 512 MB a hosted dataset is allowed to be.
///
/// These pin the replacement — a source that answers "give me bytes
/// [start, end)" and, on a native target, answers it from disk.
void main() {
  group('BytesArchiveSource', () {
    final bytes = Uint8List.fromList(List.generate(256, (i) => i));

    test('reports its length and name without being read', () async {
      final source = BytesArchiveSource(bytes, filename: 'set.zip');

      expect(source.length, 256);
      expect(source.filename, 'set.zip');
    });

    test('returns exactly the requested range', () async {
      final source = BytesArchiveSource(bytes, filename: 'set.zip');

      expect(await source.read(0, 4), [0, 1, 2, 3]);
      expect(await source.read(10, 13), [10, 11, 12]);
      expect(await source.read(254, 256), [254, 255]);
    });

    test('clamps a range that runs past the end', () async {
      final source = BytesArchiveSource(bytes, filename: 'set.zip');

      expect((await source.read(250, 999)).length, 6);
    });
  });

  group('openFileArchive', () {
    late Directory dir;

    setUp(() async {
      dir = await Directory.systemTemp.createTemp('archive_source');
    });

    tearDown(() async {
      // Best effort: Windows refuses to delete a file while a handle is open,
      // and a failure to tidy up must not be reported as a failure of the
      // thing under test.
      try {
        if (dir.existsSync()) await dir.delete(recursive: true);
      } on FileSystemException {
        // ignored
      }
    });

    /// Written a megabyte at a time, deliberately.
    ///
    /// Building the whole thing as one `Uint8List` first would grow the VM's
    /// heap to the size of the file before the measurement below even starts,
    /// and the memory assertion would then pass against an implementation that
    /// reads the entire file per chunk — which is exactly what it is there to
    /// catch. It did, until this helper stopped doing that.
    Future<File> write(int size) async {
      final file = File('${dir.path}${Platform.pathSeparator}set.zip');
      final sink = file.openWrite();

      const block = 1 << 20;
      var written = 0;

      while (written < size) {
        final take = size - written < block ? size - written : block;
        sink.add(
          Uint8List.fromList(
            List.generate(take, (i) => (written + i) % 251),
          ),
        );
        written += take;
        await sink.flush();
      }

      await sink.close();

      return file;
    }

    test('reads a range from the middle without reading the rest', () async {
      final file = await write(4096);
      final source = await openFileArchive(file.path);

      expect(source.length, 4096);
      expect(source.filename, 'set.zip');
      expect(await source.read(1000, 1004), [
        1000 % 251,
        1001 % 251,
        1002 % 251,
        1003 % 251,
      ]);

      await source.close();
    });

    test('walked end to end it reproduces the file exactly', () async {
      final file = await write(9000);
      final expected = await file.readAsBytes();
      final source = await openFileArchive(file.path);

      final rebuilt = BytesBuilder();
      for (var at = 0; at < source.length; at += 1024) {
        rebuilt.add(await source.read(at, at + 1024));
      }

      await source.close();

      expect(rebuilt.toBytes(), expected);
    });

    /// The whole point. A 64 MB archive walked in 1 MB chunks must cost about
    /// one chunk, not sixty-four — that is the difference between an upload
    /// that works on a phone and one that kills the tab.
    test('walking a large file does not pull it into memory', () async {
      final file = await write(64 * 1024 * 1024);
      final source = await openFileArchive(file.path);

      final before = ProcessInfo.currentRss;
      var checksum = 0;

      for (var at = 0; at < source.length; at += 1 << 20) {
        final chunk = await source.read(at, at + (1 << 20));
        checksum = (checksum + chunk.first + chunk.last) % 0xffff;
      }

      final grew = ProcessInfo.currentRss - before;
      await source.close();

      expect(checksum, isNonNegative);
      expect(
        grew,
        lessThan(32 * 1024 * 1024),
        reason: 'reading 64 MB in chunks grew RSS by '
            '${(grew / 1048576).toStringAsFixed(1)} MB',
      );
    });
  });
}
