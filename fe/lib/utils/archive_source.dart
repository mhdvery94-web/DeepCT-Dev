import 'dart:typed_data';

/// Where the bytes of an upload come from, asked for a slice at a time.
///
/// The chunked upload existed from the start, and for a while it looked like
/// it had solved the problem it was built for. It had not. `withData: true`
/// handed the picker's whole file to the Dart heap, and the chunk loop then
/// sliced a `Uint8List` that was already sitting there in one piece — so
/// chunking saved the *transport* and nothing else. A hosted dataset is
/// allowed to be 512 MB; a phone or a browser tab is gone long before that.
///
/// This is the seam that fixes it. A source knows how long it is and can
/// produce any range on demand, which is all the upload loop ever needed. On
/// a native target the range comes off disk and nothing but the current chunk
/// is ever resident. On the web there is no file handle to open, so the bytes
/// are in memory and [BytesArchiveSource] is honest about that rather than
/// pretending otherwise.
abstract class ArchiveSource {
  /// Total bytes, known without reading any of them.
  int get length;

  /// The name the archive should be stored under.
  String get filename;

  /// Bytes in `[start, end)`, clamped to [length].
  Future<Uint8List> read(int start, int end);

  /// Releases whatever handle the source holds. Safe to call twice.
  Future<void> close();
}

/// An archive already in memory.
///
/// Used on the web, where the picker has no path to give, and for frames this
/// app zipped itself — that bundle is built in memory and has nowhere else to
/// be.
class BytesArchiveSource implements ArchiveSource {
  BytesArchiveSource(this._bytes, {required this.filename});

  final Uint8List _bytes;

  @override
  final String filename;

  @override
  int get length => _bytes.length;

  @override
  Future<Uint8List> read(int start, int end) async =>
      // A view, not a copy: the bytes are already here, and duplicating each
      // chunk would add a second copy of the archive over the upload's life.
      Uint8List.sublistView(
        _bytes,
        start.clamp(0, _bytes.length),
        end.clamp(0, _bytes.length),
      );

  @override
  Future<void> close() async {}
}
