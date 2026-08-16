import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../services/api_client.dart';
import '../services/avatar_service.dart';
import '../theme/app_theme.dart';
import '../utils/file_extension.dart';
import 'user_avatar.dart';

/// Change or remove a profile photo.
///
/// Serves both cases: a researcher editing their own ([userId] null) and an
/// administrator editing someone else's. The endpoints differ; the form does
/// not, so there is one of these rather than two.
///
/// Returns the new `avatar_url` on save, or null when the photo was removed.
/// The caller cannot distinguish "removed" from "cancelled" by the value
/// alone — it gets `true`/`false` via [changed] instead.
Future<({bool changed, String? path})?> showAvatarEditor(
  BuildContext context, {
  int? userId,
  required String name,
  required String? currentPath,
}) {
  return showModalBottomSheet<({bool changed, String? path})>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppTheme.surface,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
    builder: (_) => _AvatarEditorSheet(
      userId: userId,
      name: name,
      currentPath: currentPath,
    ),
  );
}

class _AvatarEditorSheet extends StatefulWidget {
  final int? userId;
  final String name;
  final String? currentPath;

  const _AvatarEditorSheet({
    this.userId,
    required this.name,
    required this.currentPath,
  });

  @override
  State<_AvatarEditorSheet> createState() => _AvatarEditorSheetState();
}

class _AvatarEditorSheetState extends State<_AvatarEditorSheet> {
  final AvatarService _service = AvatarService();

  Uint8List? _bytes;
  String? _filename;
  bool _busy = false;
  String? _error;

  bool get _isSelf => widget.userId == null;

  /// The four types the backend accepts.
  static const List<String> _allowed = ['jpg', 'jpeg', 'png', 'webp'];

  Future<void> _pick() async {
    // `FileType.image`, not a `FileType.custom` extension list: `custom`
    // becomes an extension-based `accept` attribute, which a mobile browser
    // cannot reliably turn into an Android file-chooser filter. `image/*` is
    // a MIME filter both Android and the browser understand, and it lets the
    // camera and gallery appear in the chooser. It is broader than the four
    // types below, so the name is still checked afterwards.
    final result = await FilePicker.pickFiles(
      type: FileType.image,
      withData: true,
    );

    final file = result?.files.firstOrNull;
    if (file?.bytes == null) return;

    if (!mounted) return;

    if (!hasExtension(file!.name, _allowed)) {
      setState(() => _error = 'Choose a JPEG, PNG or WebP image.');
      return;
    }

    setState(() {
      _bytes = file.bytes;
      _filename = file.name;
      _error = null;
    });
  }

  Future<void> _save() async {
    final bytes = _bytes;
    if (bytes == null || _busy) return;

    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      final path = _isSelf
          ? await _service.uploadOwn(bytes, _filename ?? 'photo.jpg')
          : await _service.uploadFor(
              widget.userId!,
              bytes,
              _filename ?? 'photo.jpg',
            );

      if (!mounted) return;
      Navigator.pop(context, (changed: true, path: path));
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = e.message;
      });
    }
  }

  Future<void> _remove() async {
    if (_busy) return;

    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      if (_isSelf) {
        await _service.removeOwn();
      } else {
        await _service.removeFor(widget.userId!);
      }

      if (!mounted) return;
      Navigator.pop(context, (changed: true, path: null));
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = e.message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasNew = _bytes != null;

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            _isSelf ? 'Your photo' : 'Photo for ${widget.name}',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 16),

          Row(
            children: [
              SizedBox(
                width: 84,
                height: 84,
                child: hasNew
                    ? Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: AppTheme.border),
                        ),
                        clipBehavior: Clip.hardEdge,
                        child: Image.memory(_bytes!, fit: BoxFit.cover),
                      )
                    : UserAvatar(
                        avatarPath: widget.currentPath,
                        name: widget.name,
                        size: 84,
                      ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    OutlinedButton.icon(
                      onPressed: _busy ? null : _pick,
                      icon: const Icon(Icons.image_outlined, size: 16),
                      label: Text(hasNew ? 'CHOOSE ANOTHER' : 'CHOOSE PHOTO'),
                    ),
                    if (hasNew)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          _filename ?? '',
                          style: Theme.of(context).textTheme.labelSmall,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    if (widget.currentPath != null && !hasNew)
                      TextButton(
                        onPressed: _busy ? null : _remove,
                        style: TextButton.styleFrom(
                          foregroundColor: AppTheme.error,
                        ),
                        child: const Text('REMOVE PHOTO'),
                      ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),
          Text(
            'JPEG, PNG or WebP, up to 2 MB. Without a photo the account shows '
            'its initials.',
            style: Theme.of(context).textTheme.labelSmall,
          ),

          if (_error != null) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.errorLight,
                border: Border.all(color: AppTheme.error),
              ),
              child: Text(
                _error!,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ],

          const SizedBox(height: 20),
          Row(
            children: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('CANCEL'),
              ),
              const Spacer(),
              ElevatedButton(
                onPressed: (!hasNew || _busy) ? null : _save,
                child: _busy
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('SAVE'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
