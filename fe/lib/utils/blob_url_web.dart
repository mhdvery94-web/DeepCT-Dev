import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

const bool blobUrlsSupported = true;

/// Wraps [bytes] in an object URL. The browser holds the blob until
/// [revokeBlobUrl] is called, so every caller owes it one — for a video that
/// is tens of megabytes of memory that would otherwise sit there until the
/// tab closes.
String createBlobUrl(
  Uint8List bytes, {
  String mimeType = 'application/octet-stream',
}) {
  final blob = web.Blob(
    <JSAny>[bytes.toJS].toJS,
    web.BlobPropertyBag(type: mimeType),
  );
  return web.URL.createObjectURL(blob);
}

void revokeBlobUrl(String url) => web.URL.revokeObjectURL(url);
