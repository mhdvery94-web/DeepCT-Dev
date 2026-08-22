import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:video_player/video_player.dart';

import '../theme/app_theme.dart';

/// True where `video_player` actually has an implementation.
///
/// Android, iOS/macOS and web. There is no Windows or Linux plugin, and the
/// project carries `windows/` and `linux/` folders only because `flutter
/// create` made them — the product ships to web and Android.
///
/// Checked up front rather than caught: an exception thrown after the screen
/// is built is too late to change what was drawn.
bool get videoPlaybackSupported =>
    kIsWeb ||
    defaultTargetPlatform == TargetPlatform.android ||
    defaultTargetPlatform == TargetPlatform.iOS ||
    defaultTargetPlatform == TargetPlatform.macOS;

/// Plays a post's clip, or hands it to the system where it cannot be played.
class NewsVideoPlayer extends StatefulWidget {
  /// Absolute, as [NewsPost.videoUrl] gives it.
  final String url;

  /// Shown beside the controls; null hides the label.
  final String? sizeLabel;

  const NewsVideoPlayer({super.key, required this.url, this.sizeLabel});

  @override
  State<NewsVideoPlayer> createState() => _NewsVideoPlayerState();
}

class _NewsVideoPlayerState extends State<NewsVideoPlayer> {
  VideoPlayerController? _controller;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    if (videoPlaybackSupported) _open();
  }

  Future<void> _open() async {
    final controller = VideoPlayerController.networkUrl(Uri.parse(widget.url));

    try {
      await controller.initialize();
      if (!mounted) {
        await controller.dispose();
        return;
      }
      setState(() => _controller = controller);
    } catch (_) {
      await controller.dispose();
      if (mounted) setState(() => _failed = true);
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!videoPlaybackSupported || _failed) return _fallback(context);

    final controller = _controller;
    if (controller == null) {
      return const SizedBox(
        height: 180,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AspectRatio(
          aspectRatio: controller.value.aspectRatio,
          child: VideoPlayer(controller),
        ),
        // Scrubbing works because the server answers Range requests — a
        // BinaryFileResponse does that on its own, so nothing here had to be
        // written for it.
        VideoProgressIndicator(controller, allowScrubbing: true),
        Row(
          children: [
            IconButton(
              icon: Icon(
                controller.value.isPlaying ? Icons.pause : Icons.play_arrow,
              ),
              onPressed: () => setState(() {
                if (controller.value.isPlaying) {
                  controller.pause();
                } else {
                  controller.play();
                }
              }),
            ),
            if (widget.sizeLabel != null)
              Text(
                widget.sizeLabel!,
                style: Theme.of(context).textTheme.bodySmall,
              ),
          ],
        ),
      ],
    );
  }

  /// Shown where playback is unavailable — on desktop, or when the file will
  /// not open. Drawing nothing at all would read as a broken page.
  ///
  /// Hands the URL to the system rather than fetching it: the file may be
  /// 50 MB, and pulling that into memory only to write it back out is the
  /// wrong way round when the OS already knows how to download.
  Widget _fallback(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: AppTheme.surface,
      border: Border.all(color: AppTheme.border),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(
              Icons.movie_outlined,
              size: 20,
              color: AppTheme.textMuted,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                _failed
                    ? 'This video could not be played here.'
                    : 'Video playback is not available on this platform.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        TextButton.icon(
          onPressed: () => launchUrl(
            Uri.parse(widget.url),
            mode: LaunchMode.externalApplication,
          ),
          icon: const Icon(Icons.open_in_new, size: 18),
          label: Text(
            widget.sizeLabel == null
                ? 'OPEN VIDEO'
                : 'OPEN VIDEO (${widget.sizeLabel})',
          ),
        ),
      ],
    ),
  );
}
