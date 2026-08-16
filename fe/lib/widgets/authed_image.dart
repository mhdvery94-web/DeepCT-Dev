import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../services/authed_image_cache.dart';

/// An image served by the API, loaded with the caller's bearer token.
///
/// Use this rather than `Image.network` for anything under `/api`. A draft
/// news photo, for instance, is served **only** to an administrator; a plain
/// network request carries no token, gets a 404, and silently shows the
/// placeholder — which looks exactly like "the upload did not work".
class AuthedImage extends StatelessWidget {
  /// Path relative to the API root, e.g. `/news/3/image`. Null renders
  /// [placeholder] straight away.
  final String? path;

  final BoxFit fit;
  final double? width;
  final double? height;

  /// Shown while loading, when [path] is null, and when the fetch fails —
  /// three states that all mean "there is no picture to show here".
  final Widget placeholder;

  const AuthedImage({
    super.key,
    required this.path,
    required this.placeholder,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
  });

  @override
  Widget build(BuildContext context) {
    final target = path;
    if (target == null) return placeholder;

    return FutureBuilder<Uint8List?>(
      future: AuthedImageCache.load(target),
      builder: (context, snapshot) {
        final bytes = snapshot.data;
        if (bytes == null) return placeholder;

        return Image.memory(
          bytes,
          fit: fit,
          width: width,
          height: height,
          errorBuilder: (_, _, _) => placeholder,
        );
      },
    );
  }
}
