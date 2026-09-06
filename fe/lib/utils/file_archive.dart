/// Opens an archive that lives on disk.
///
/// `dart:io` exists only on native targets, so the conditional export below
/// resolves to the web stub when compiling for the browser. Importing the
/// native implementation directly would break `flutter build web` at kernel
/// compilation even on a path that never runs — the same trap documented for
/// `dart:html` in the other direction.
library;

export 'file_archive_web.dart' if (dart.library.io) 'file_archive_io.dart';
