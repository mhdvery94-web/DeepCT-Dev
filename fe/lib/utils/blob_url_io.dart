import 'dart:typed_data';

/// Blob URLs are a browser concept; nothing native has them.
const bool blobUrlsSupported = false;

/// Never reachable on a native target — callers gate on [blobUrlsSupported],
/// and a player there can stream from the network URL with real headers.
String createBlobUrl(
  Uint8List bytes, {
  String mimeType = 'application/octet-stream',
}) {
  throw UnsupportedError('Blob URLs exist only in a browser.');
}

void revokeBlobUrl(String url) {}
