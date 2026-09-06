import 'dart:io';
import 'dart:typed_data';

import 'archive_source.dart';

/// An archive read from disk, one range at a time.
///
/// `RandomAccessFile` rather than `openRead`: the upload loop can be sent
/// backwards by a retry that finds the server further along than expected, and
/// a sequential stream cannot answer that. Seeking can.
class _FileArchiveSource implements ArchiveSource {
  _FileArchiveSource(this._handle, this._length, this.filename);

  final RandomAccessFile _handle;
  final int _length;
  var _closed = false;

  @override
  final String filename;

  @override
  int get length => _length;

  @override
  Future<Uint8List> read(int start, int end) async {
    final from = start.clamp(0, _length);
    final to = end.clamp(from, _length);

    if (to <= from) return Uint8List(0);

    await _handle.setPosition(from);

    return _handle.read(to - from);
  }

  @override
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    await _handle.close();
  }
}

/// Opens [path] for ranged reading. [filename] defaults to the file's own name.
Future<ArchiveSource> openFileArchive(String path, {String? filename}) async {
  final file = File(path);

  return _FileArchiveSource(
    await file.open(),
    await file.length(),
    // `uri.pathSegments` splits on either separator, so this is right on
    // Windows and on Android without a platform test.
    filename ?? file.uri.pathSegments.last,
  );
}
