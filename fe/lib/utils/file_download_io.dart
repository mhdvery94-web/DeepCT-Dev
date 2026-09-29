import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';
import 'package:crypto/crypto.dart';

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

/// Write a response to a temporary file and publish it only after its digest
/// matches the server's header. A truncated download never replaces a good one.
Future<String> saveVerifiedStream({
  required String filename,
  required Stream<Uint8List> bytes,
  required String expectedMd5,
  void Function(int received)? onProgress,
}) async {
  final directory = await _downloadDirectory();
  var target = File('${directory.path}${Platform.pathSeparator}$filename');
  if (await target.exists()) {
    target = File(
      '${directory.path}${Platform.pathSeparator}'
      '${DateTime.now().microsecondsSinceEpoch}_$filename',
    );
  }
  final partial = File('${target.path}.part');
  RandomAccessFile? handle;
  Digest? digest;
  final hash = md5.startChunkedConversion(
    ChunkedConversionSink<Digest>.withCallback(
      (values) => digest = values.single,
    ),
  );
  var received = 0;

  try {
    handle = await partial.open(mode: FileMode.write);
    await for (final chunk in bytes) {
      await handle.writeFrom(chunk);
      hash.add(chunk);
      received += chunk.length;
      onProgress?.call(received);
    }
    hash.close();
    await handle.close();
    handle = null;

    if (digest?.toString() != expectedMd5.toLowerCase()) {
      throw StateError('Download checksum does not match the server response.');
    }

    await partial.rename(target.path);
    return target.path;
  } catch (_) {
    if (handle != null) await handle.close();
    if (await partial.exists()) await partial.delete();
    rethrow;
  }
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
