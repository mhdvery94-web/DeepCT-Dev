/// Turns bytes already in memory into a URL a `<video>`, an `<img>` or a
/// download can be pointed at.
///
/// This exists for one platform and one reason. A browser does not let a page
/// attach headers to a request that a `src` attribute starts, so the web
/// build cannot send `ngrok-skip-browser-warning` with a clip — and ngrok
/// answers the interstitial instead of the file. Fetching the bytes through
/// Dio (an XHR, which *may* carry headers) and handing the player a
/// `blob:` URL is the way round it.
///
/// `dart:js_interop` and `package:web` are web-only, and importing either one
/// unconditionally breaks the Android build at kernel compilation — the same
/// trap `dart:html` sets. Hence the conditional export, exactly as
/// `file_download.dart` does it.
library;

export 'blob_url_web.dart' if (dart.library.io) 'blob_url_io.dart';
