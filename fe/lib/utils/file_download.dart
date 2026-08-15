/// Saves a generated text file (CSV export) to wherever the current platform
/// puts user-visible downloads.
///
/// The web implementation triggers a browser download; the native one writes to
/// disk and returns the path so the UI can tell the user where it landed.
/// [saveTextFile] returns a short, human-readable location for that message.
///
/// `dart:io` is only available on native targets, so the conditional export
/// below resolves to the web implementation when compiling for the web.
library;

export 'file_download_web.dart' if (dart.library.io) 'file_download_io.dart';
