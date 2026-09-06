import 'archive_source.dart';

/// There is no file handle to open in a browser.
///
/// The picker on the web hands over bytes, never a path, so this is never
/// reached — it exists so the import in `file_archive.dart` resolves when
/// compiling for the web. Callers choose [BytesArchiveSource] there.
Future<ArchiveSource> openFileArchive(String path, {String? filename}) async {
  throw UnsupportedError(
    'A browser has no file path to open; use BytesArchiveSource.',
  );
}
