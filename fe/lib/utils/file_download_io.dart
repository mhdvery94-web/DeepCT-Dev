import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// Writes [content] to a file named [filename] in the platform's download
/// location and returns the full path, so the caller can show the user where
/// the export ended up.
///
/// On Android this is the app's own external "Download" directory
/// (`Android/data/<package>/files/Download`), which is readable by any file
/// manager and needs no runtime storage permission.
Future<String> saveTextFile({
  required String filename,
  required String content,
  String mimeType = 'text/csv',
}) async {
  final directory = await _downloadDirectory();
  final file = File('${directory.path}${Platform.pathSeparator}$filename');

  await file.writeAsBytes(utf8.encode(content), flush: true);

  return file.path;
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
