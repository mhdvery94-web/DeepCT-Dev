import 'dart:typed_data';

import 'package:archive/archive.dart';

/// Wrap loose `.tif` frames into the ZIP the upload path already expects.
///
/// A researcher picking six frames out of a folder should not have to zip them
/// first, and the backend should not grow a second intake shape for the same
/// thing. So the archive is built here and travels the existing route.
///
/// **Names are kept exactly.** The numbering inside them is what tells the
/// backend where the gaps are; normalising it would destroy the one piece of
/// information the whole interpolation depends on.
Future<({Uint8List bytes, String filename})> bundleFrames(
  List<({String name, Uint8List bytes})> files,
) async {
  if (files.isEmpty) {
    throw ArgumentError('bundleFrames needs at least one file');
  }

  final archive = Archive();

  for (final file in files) {
    archive.addFile(ArchiveFile(file.name, file.bytes.length, file.bytes));
  }

  final encoded = ZipEncoder().encode(archive);

  return (bytes: Uint8List.fromList(encoded), filename: 'frames.zip');
}
