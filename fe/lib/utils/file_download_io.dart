import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';

/// Writes [bytes] to a file named [filename] in the platform's download
/// location and returns the full path, so the caller can show the user where
/// it ended up.
///
/// On Android this is the app's own external "Download" directory
/// (`Android/data/<package>/files/Download`), which is readable by any file
/// manager and needs no runtime storage permission.
Future<String> saveBytesFile({
  required String filename,
  required Uint8List bytes,
  String mimeType = 'application/octet-stream',
}) async {
  final directory = await _downloadDirectory();
  final file = File('${directory.path}${Platform.pathSeparator}$filename');

  await file.writeAsBytes(bytes, flush: true);

  return file.path;
}

/// Convenience wrapper for text payloads such as the CSV export.
Future<String> saveTextFile({
  required String filename,
  required String content,
  String mimeType = 'text/csv',
}) {
  return saveBytesFile(
    filename: filename,
    bytes: Uint8List.fromList(utf8.encode(content)),
    mimeType: mimeType,
  );
}

Future<Directory> _downloadDirectory() async {
  if (Platform.isAndroid) {
    final dirs = await getExternalStorageDirectories(
      type: StorageDirectory.downloads,
    );
    if (dirs != null && dirs.isNotEmpty) return dirs.first;
    return getApplicationDocumentsDirectory();
  }

  if (Platform.isIOS) {
    return getApplicationDocumentsDirectory();
  }

  // Desktop: a real Downloads folder exists, but it is not guaranteed.
  return await getDownloadsDirectory() ??
      await getApplicationDocumentsDirectory();
}
