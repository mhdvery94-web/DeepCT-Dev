import 'dart:convert';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

/// Hands [bytes] to the browser as a download named [filename].
///
/// Uses `package:web` rather than the deprecated `dart:html`: the latter is a
/// web-only library, and merely importing it breaks the Android/iOS build at
/// the kernel-compilation step.
Future<String> saveBytesFile({
  required String filename,
  required Uint8List bytes,
  String mimeType = 'application/octet-stream',
}) async {
  final blob = web.Blob(
    <JSAny>[bytes.toJS].toJS,
    web.BlobPropertyBag(type: mimeType),
  );
  final url = web.URL.createObjectURL(blob);

  final anchor = web.document.createElement('a') as web.HTMLAnchorElement
    ..href = url
    ..download = filename;
  anchor.style.display = 'none';

  web.document.body!.appendChild(anchor);
  anchor.click();
  web.document.body!.removeChild(anchor);

  web.URL.revokeObjectURL(url);

  return filename;
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
