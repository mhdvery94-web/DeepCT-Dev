/// True when [filename]'s final extension is one of [allowed].
///
/// [allowed] is given without dots, e.g. `['zip']` or `['jpg', 'jpeg']`.
/// Matching is case-insensitive: Android content providers and Windows both
/// hand back whatever case the file was created with.
///
/// This exists because the file picker's own filter cannot be trusted to do
/// it. On Android the plugin resolves `FileType.custom` to an intent type of
/// `*/*` (every file selectable), and on mobile browsers an extension-based
/// `accept` attribute is unreliable — see the comment on `_pickFile` in
/// `screens/user/upload_screen.dart`. Whatever the picker hands back, the
/// name is checked here before anything is uploaded.
bool hasExtension(String filename, List<String> allowed) {
  final dot = filename.lastIndexOf('.');

  // No dot, or nothing after it ("frames", "frames.").
  if (dot < 0 || dot == filename.length - 1) return false;

  final extension = filename.substring(dot + 1).toLowerCase();

  return allowed.any((e) => e.toLowerCase() == extension);
}
